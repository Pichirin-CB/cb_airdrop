local currentZone = nil
local zoneBlip = nil
local dropBlip = nil
local policeBlip = nil
local dropState = 'idle'
local aircraft = nil
local pilot = nil
local crate = nil
local parachute = nil
local pickup = nil
local pickupNetId = nil
local targetNetId = nil

local function notify(message, type)
    lib.notify({ title = 'AIR DROP', description = message, type = type or 'inform', duration = 5000, position = 'top-right' })
end

local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        Wait(10)
        if GetGameTimer() > timeout then
            print(('[cb_airdrop] Failed to load model: %s'):format(tostring(model)))
            return nil
        end
    end
    return hash
end

local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    return nil
end

local function removeCrateTarget()
    if targetNetId and targetNetId > 0 then
        if pickup and DoesEntityExist(pickup) then
        exports.ox_target:removeLocalEntity(pickup, 'cb_airdrop_loot')
    end
    end
    targetNetId = nil
end

local function registerCrateTarget(netId)
    netId = tonumber(netId)
    if not netId or netId <= 0 then return end
    if targetNetId == netId then return end

    removeCrateTarget()

    local timeout = GetGameTimer() + 10000
    local entity = 0

    while GetGameTimer() < timeout do
        if NetworkDoesEntityExistWithNetworkId(netId) then
            entity = NetworkGetEntityFromNetworkId(netId)
            if entity and entity ~= 0 and DoesEntityExist(entity) then break end
        end
        Wait(100)
    end

    if entity == 0 or not DoesEntityExist(entity) then
        print(('[cb_airdrop] Could not resolve crate NetID %s.'):format(netId))
        return
    end

    pickup = entity
    pickupNetId = netId

    -- Register the ACTUAL crate entity as a local ox_target target.
    -- No zone, marker or replacement prop is created.
    exports.ox_target:addLocalEntity(entity, {
        {
            name = 'cb_airdrop_loot',
            icon = 'fa-solid fa-box-open',
            iconColor = '#c9a227',
            label = 'Search supply crate',
            distance = Config.LootDistance,
            onSelect = function(data)
                if data and data.entity and DoesEntityExist(data.entity) then
                    pickup = data.entity
                end
                StartLoot()
            end
        }
    })

    targetNetId = netId
end

local function getGroundZ(coords)
    local found, z = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 100.0, false)
    if found then return true, z end

    local ray = StartShapeTestRay(coords.x, coords.y, coords.z + 100.0, coords.x, coords.y, coords.z - 1000.0, 1, 0, 7)
    local timeout = GetGameTimer() + 1000
    while GetGameTimer() < timeout do
        local result, hit, endCoords = GetShapeTestResult(ray)
        if result == 2 then
            if hit then return true, endCoords.z end
            break
        end
        Wait(0)
    end
    return false, nil
end

local function getNetworkId(entity)
    if not DoesEntityExist(entity) then return 0 end
    local timeout = GetGameTimer() + 5000
    while GetGameTimer() < timeout do
        if not NetworkGetEntityIsNetworked(entity) then NetworkRegisterEntityAsNetworked(entity) end
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId and netId > 0 then
            SetNetworkIdCanMigrate(netId, true)
            return netId
        end
        Wait(50)
    end
    return 0
end

local function createZoneBlip()
    zoneBlip = removeBlip(zoneBlip)
    if not Config.Blips.zone.enabled or not currentZone then return end
    zoneBlip = AddBlipForRadius(currentZone.coords.x, currentZone.coords.y, currentZone.coords.z, currentZone.radius)
    SetBlipSprite(zoneBlip, Config.Blips.zone.sprite)
    SetBlipColour(zoneBlip, currentZone.color or Config.Blips.zone.colour)
    SetBlipAlpha(zoneBlip, Config.Blips.zone.alpha)
end

local function createDropBlip(coords)
    dropBlip = removeBlip(dropBlip)
    if not Config.Blips.drop.enabled or not coords then return end
    dropBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(dropBlip, Config.Blips.drop.sprite)
    SetBlipColour(dropBlip, Config.Blips.drop.colour)
    SetBlipScale(dropBlip, Config.Blips.drop.scale)
    if Config.Blips.drop.route then
        SetBlipRoute(dropBlip, true)
        SetBlipRouteColour(dropBlip, Config.Blips.drop.colour)
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blips.drop.name)
    EndTextCommandSetBlipName(dropBlip)
end

RegisterNetEvent('cb_airdrop:client:setZone', function(zone)
    currentZone = zone
    createZoneBlip()
end)

RegisterNetEvent('cb_airdrop:client:setDropState', function(state)
    dropState = state
    if state == 'idle' or state == 'claimed' or state == 'failed' then
        dropBlip = removeBlip(dropBlip)
    end
    if state == 'ready' then
        notify(Config.Notifications.crateReady, 'success')
    elseif state == 'failed' then
        notify(Config.Notifications.planeCrashed, 'error')
    end
end)

RegisterNetEvent('cb_airdrop:client:setDropBlip', function(coords)
    createDropBlip(coords)
end)

RegisterNetEvent('cb_airdrop:client:registerDropEntity', function(netId)
    registerCrateTarget(netId)
end)

RegisterNetEvent('cb_airdrop:client:notify', function(message, type)
    notify(message, type)
end)

RegisterNetEvent('cb_airdrop:client:setPoliceBlip', function(coords)
    policeBlip = removeBlip(policeBlip)
    if not coords then return end
    policeBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(policeBlip, Config.Blips.police.sprite)
    SetBlipColour(policeBlip, Config.Blips.police.colour)
    SetBlipScale(policeBlip, Config.Blips.police.scale)
    SetBlipAsShortRange(false)
    PulseBlip(policeBlip)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(Config.Blips.police.name)
    EndTextCommandSetBlipName(policeBlip)
end)

RegisterNetEvent('cb_airdrop:client:removePoliceBlip', function()
    policeBlip = removeBlip(policeBlip)
end)

function StartLoot()
    if dropState ~= 'ready' or not pickupNetId then return end
    if not pickup or not DoesEntityExist(pickup) then return end

    local accepted = lib.callback.await('cb_airdrop:server:beginLoot', false)
    if not accepted then
        notify(Config.Notifications.crateAlreadyLooted, 'error')
        return
    end

    local completed = lib.progressBar({
        duration = Config.LootDuration,
        label = 'Searching survival supplies...',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true, sprint = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 49 }
    })

    if not completed then
        TriggerServerEvent('cb_airdrop:server:cancelLoot')
        notify(Config.Notifications.lootCancelled, 'error')
        return
    end

    TriggerServerEvent('cb_airdrop:server:completeLoot')
end

RegisterNetEvent('cb_airdrop:client:removeDrop', function()
    removeCrateTarget()
    if DoesEntityExist(pickup) then DeleteEntity(pickup) end
    if DoesEntityExist(crate) then DeleteEntity(crate) end
    if DoesEntityExist(parachute) then DeleteEntity(parachute) end
    pickup = nil
    pickupNetId = nil
    crate = nil
    parachute = nil
    dropBlip = removeBlip(dropBlip)
end)

RegisterNetEvent('cb_airdrop:client:startFlare', function()
    if dropState ~= 'incoming' or not currentZone then return end

    notify(Config.Notifications.planeIncoming, 'inform')

    CreateThread(function()
        local aircraftModel = requestModel(Config.AircraftModel)
        local pilotModel = requestModel(Config.PilotModel)
        local crateModel = requestModel(Config.CrateModel)
        local parachuteModel = requestModel(Config.ParachuteModel)

        if not aircraftModel or not pilotModel or not crateModel or not parachuteModel then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        local zone = currentZone
        local heading = math.random(0, 359)
        local rad = math.rad(heading)
        local spawnDistance = Config.PlaneSpawnDistance
        local spawn = vector3(zone.coords.x - math.cos(rad) * spawnDistance, zone.coords.y - math.sin(rad) * spawnDistance, zone.coords.z + Config.PlaneAltitude)

        aircraft = CreateVehicle(aircraftModel, spawn.x, spawn.y, spawn.z, heading, true, true)
        if aircraft == 0 then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        SetEntityAsMissionEntity(aircraft, true, true)
        SetVehicleEngineOn(aircraft, true, true, false)
        SetEntityInvincible(aircraft, true)
        SetVehicleForwardSpeed(aircraft, Config.PlaneSpeed)

        pilot = CreatePedInsideVehicle(aircraft, 4, pilotModel, -1, true, true)
        if pilot and pilot ~= 0 then
            SetEntityInvincible(pilot, true)
            SetBlockingOfNonTemporaryEvents(pilot, true)
        end

        notify(Config.Notifications.planeArriving, 'inform')

        local timeout = GetGameTimer() + Config.PlaneTimeoutSeconds * 1000
        while DoesEntityExist(aircraft) and GetGameTimer() < timeout do
            local coords = GetEntityCoords(aircraft)
            if #(coords - zone.coords) <= 70.0 then break end
            SetVehicleForwardSpeed(aircraft, Config.PlaneSpeed)
            Wait(250)
        end

        if not DoesEntityExist(aircraft) then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        local releaseCoords = GetOffsetFromEntityInWorldCoords(aircraft, 0.0, -2.0, -2.0)
        crate = CreateObject(crateModel, releaseCoords.x, releaseCoords.y, releaseCoords.z, true, true, true)
        if crate == 0 then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        SetEntityAsMissionEntity(crate, true, true)
        ActivatePhysics(crate)

        local freeFallEnd = GetGameTimer() + Config.CrateFreeFallSeconds * 1000
        while DoesEntityExist(crate) and GetGameTimer() < freeFallEnd do
            SetEntityVelocity(crate, 0.0, 0.0, -2.0)
            Wait(0)
        end

        parachute = CreateObject(parachuteModel, releaseCoords.x, releaseCoords.y, releaseCoords.z, true, true, true)
        if parachute and parachute ~= 0 then
            AttachEntityToEntity(parachute, crate, 0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            ActivatePhysics(parachute)
        else
            parachute = nil
        end

        local landed = false
        local landingTimeout = GetGameTimer() + Config.CrateLandingTimeoutSeconds * 1000

        while DoesEntityExist(crate) and GetGameTimer() < landingTimeout do
            local coords = GetEntityCoords(crate)
            local found, groundZ = getGroundZ(coords)
            if found then
                local targetZ = groundZ + Config.CrateGroundDistance
                if coords.z <= targetZ + 0.75 then
                    SetEntityCoords(crate, coords.x, coords.y, targetZ, false, false, false, false)
                    SetEntityVelocity(crate, 0.0, 0.0, 0.0)
                    FreezeEntityPosition(crate, true)
                    landed = true
                    break
                end
            end

            local velocity = GetEntityVelocity(crate)
            SetEntityVelocity(crate, velocity.x * 0.90, velocity.y * 0.90, -Config.CrateDescentSpeed)
            Wait(50)
        end

        if not landed or not DoesEntityExist(crate) then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        if DoesEntityExist(parachute) then
            DetachEntity(parachute, true, true)
            DeleteEntity(parachute)
            parachute = nil
        end

        -- CRITICAL: no replacement prop. This exact crate becomes the target.
        pickup = crate
        crate = nil

        pickupNetId = getNetworkId(pickup)
        if pickupNetId <= 0 then
            TriggerServerEvent('cb_airdrop:server:dropFailed')
            return
        end

        local finalCoords = GetEntityCoords(pickup)
        TriggerServerEvent('cb_airdrop:server:dropReady', {
            x = finalCoords.x,
            y = finalCoords.y,
            z = finalCoords.z
        }, pickupNetId)

        if DoesEntityExist(aircraft) then DeleteEntity(aircraft) end
        if DoesEntityExist(pilot) then DeleteEntity(pilot) end
        aircraft = nil
        pilot = nil

        SetModelAsNoLongerNeeded(aircraftModel)
        SetModelAsNoLongerNeeded(pilotModel)
        SetModelAsNoLongerNeeded(crateModel)
        SetModelAsNoLongerNeeded(parachuteModel)
    end)
end)

exports('useFlare', function(data, slot)
    exports.ox_inventory:useItem(data, function(usedData)
        if usedData then TriggerEvent('cb_airdrop:client:startFlare') end
    end)
end)

CreateThread(function()
    Wait(1500)
    TriggerServerEvent('cb_airdrop:server:requestZone')
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeCrateTarget()
    if DoesEntityExist(pickup) then DeleteEntity(pickup) end
    if DoesEntityExist(crate) then DeleteEntity(crate) end
    if DoesEntityExist(parachute) then DeleteEntity(parachute) end
    if DoesEntityExist(aircraft) then DeleteEntity(aircraft) end
    if DoesEntityExist(pilot) then DeleteEntity(pilot) end
end)
