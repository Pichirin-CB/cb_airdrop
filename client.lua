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
local pickupZone = nil

local requiredModels = {
    Config.CrateModel,
    Config.ParachuteModel,
    Config.AircraftModel,
    Config.PilotModel,
    Config.PickupModel
}

-- ============================================================================
-- HELPERS
-- ============================================================================

local function notify(description, type)
    lib.notify({
        title = 'AIR DROP',
        description = description,
        type = type or 'inform',
        duration = 5000,
        position = 'top-right'
    })
end


local function requestModel(model)
    local hash = type(model) == 'number' and model or joaat(model)

    if HasModelLoaded(hash) then
        return hash
    end

    RequestModel(hash)

    local timeout = GetGameTimer() + 10000

    while not HasModelLoaded(hash) do
        Wait(10)

        if GetGameTimer() > timeout then
            print(
                ('[cb_airdrop] Failed to load model: %s'):format(
                    tostring(model)
                )
            )

            return nil
        end
    end

    return hash
end


local function releaseModels()
    for i = 1, #requiredModels do
        local model = requiredModels[i]

        if model then
            local hash = type(model) == 'number'
                and model
                or joaat(model)

            SetModelAsNoLongerNeeded(hash)
        end
    end
end


local function removeBlip(blip)
    if blip and DoesBlipExist(blip) then
        RemoveBlip(blip)
    end

    return nil
end


-- ============================================================================
-- GROUND / MODEL HELPERS
-- ============================================================================

local function getGroundHeight(coords, ignoreEntity)
    local startZ = coords.z + 100.0
    local endZ = coords.z - 1000.0

    -- Only test world geometry.
    -- This prevents the raycast from detecting the parachute,
    -- crate or other dynamic entities as the "ground".
    local ray = StartShapeTestRay(
        coords.x,
        coords.y,
        startZ,
        coords.x,
        coords.y,
        endZ,
        1,
        ignoreEntity or 0,
        7
    )

    local timeout = GetGameTimer() + 1000

    while GetGameTimer() < timeout do
        local result, hit, endCoords =
            GetShapeTestResult(ray)

        if result == 2 then
            if hit then
                return true, endCoords.z, 0
            end

            break
        end

        Wait(0)
    end

    local foundGround, groundZ =
        GetGroundZFor_3dCoord(
            coords.x,
            coords.y,
            coords.z + 100.0,
            false
        )

    if foundGround then
        return true, groundZ, 0
    end

    return false, nil, 0
end


local function getModelGroundOffset(model)
    local hash = type(model) == 'number'
        and model
        or joaat(model)

    local minDim, maxDim =
        GetModelDimensions(hash)

    if not minDim or not maxDim then
        return 0.05
    end

    local offset = -minDim.z

    if offset < 0.0 then
        offset = 0.0
    end

    return offset + 0.03
end


local function getDropHeight()
    return Config.PlaneAltitude or 500.0
end


local function getPlaneSpeed()
    return Config.PlaneSpeed or 60.0
end


local function getPlaneSpawnDistance()
    return Config.PlaneSpawnDistance or 400.0
end


local function getPlaneTimeout()
    return Config.PlaneTimeoutSeconds or 60
end


local function getGroundDistance()
    return Config.CrateGroundDistance or 0.05
end


-- ============================================================================
-- ZONE BLIP
-- ============================================================================

local function createZoneBlip()
    zoneBlip = removeBlip(zoneBlip)

    if not Config.Blips.zone.enabled then
        return
    end

    if not currentZone then
        return
    end

    zoneBlip = AddBlipForRadius(
        currentZone.coords.x,
        currentZone.coords.y,
        currentZone.coords.z,
        currentZone.radius
    )

    SetBlipSprite(
        zoneBlip,
        Config.Blips.zone.sprite
    )

    SetBlipColour(
        zoneBlip,
        currentZone.color or Config.Blips.zone.colour
    )

    SetBlipAlpha(
        zoneBlip,
        Config.Blips.zone.alpha
    )
end


-- ============================================================================
-- DROP BLIP
-- ============================================================================

local function createDropBlip(coords)
    dropBlip = removeBlip(dropBlip)

    if not Config.Blips.drop.enabled then
        return
    end

    if not coords then
        return
    end

    dropBlip = AddBlipForCoord(
        coords.x,
        coords.y,
        coords.z
    )

    SetBlipSprite(
        dropBlip,
        Config.Blips.drop.sprite
    )

    SetBlipColour(
        dropBlip,
        Config.Blips.drop.colour
    )

    SetBlipScale(
        dropBlip,
        Config.Blips.drop.scale
    )

    if Config.Blips.drop.route then
        SetBlipRoute(
            dropBlip,
            true
        )

        SetBlipRouteColour(
            dropBlip,
            Config.Blips.drop.colour
        )
    end

    BeginTextCommandSetBlipName('STRING')

    AddTextComponentString(
        Config.Blips.drop.name
    )

    EndTextCommandSetBlipName(dropBlip)
end


-- ============================================================================
-- POLICE BLIP
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:setPoliceBlip',
    function(coords)
        policeBlip = removeBlip(policeBlip)

        if not coords then
            return
        end

        policeBlip = AddBlipForCoord(
            coords.x,
            coords.y,
            coords.z
        )

        SetBlipSprite(
            policeBlip,
            Config.Blips.police.sprite
        )

        SetBlipColour(
            policeBlip,
            Config.Blips.police.colour
        )

        SetBlipScale(
            policeBlip,
            Config.Blips.police.scale
        )

        SetBlipAsShortRange(false)

        PulseBlip(policeBlip)

        BeginTextCommandSetBlipName('STRING')

        AddTextComponentString(
            Config.Blips.police.name
        )

        EndTextCommandSetBlipName(policeBlip)
    end
)


RegisterNetEvent(
    'cb_airdrop:client:removePoliceBlip',
    function()
        policeBlip = removeBlip(policeBlip)
    end
)


-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:notify',
    function(message, type)
        notify(
            message,
            type
        )
    end
)


-- ============================================================================
-- ZONE
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:setZone',
    function(zone)
        currentZone = zone

        createZoneBlip()
    end
)


CreateThread(function()
    Wait(1500)

    TriggerServerEvent(
        'cb_airdrop:server:requestZone'
    )
end)


-- ============================================================================
-- DROP STATE
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:setDropState',
    function(state)
        dropState = state

        if state == 'idle' then
            dropBlip = removeBlip(dropBlip)

        elseif state == 'incoming' then

        elseif state == 'ready' then
            notify(
                Config.Notifications.crateReady,
                'success'
            )

        elseif state == 'claimed' then
            dropBlip = removeBlip(dropBlip)

        elseif state == 'failed' then
            dropBlip = removeBlip(dropBlip)

            notify(
                Config.Notifications.planeCrashed,
                'error'
            )
        end
    end
)


RegisterNetEvent(
    'cb_airdrop:client:setDropBlip',
    function(coords)
        if not coords then
            return
        end

        createDropBlip(coords)
    end
)


-- ============================================================================
-- OX INVENTORY ITEM
-- ============================================================================

exports('useFlare', function(data, slot)
    exports.ox_inventory:useItem(
        data,
        function(usedData)
            if not usedData then
                return
            end

            TriggerEvent(
                'cb_airdrop:client:startFlare'
            )
        end
    )
end)


-- ============================================================================
-- FLARE ITEM
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:startFlare',
    function()
        if dropState ~= 'incoming' then
            dropState = 'incoming'
        end

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local flareWeapon =
            joaat('WEAPON_FLARE')

        RequestWeaponAsset(
            flareWeapon,
            31,
            0
        )

        local timeout =
            GetGameTimer() + 5000

        while not HasWeaponAssetLoaded(flareWeapon) do
            Wait(10)

            if GetGameTimer() >= timeout then
                print(
                    '[cb_airdrop] Failed to load flare weapon asset.'
                )

                return
            end
        end

        ShootSingleBulletBetweenCoords(
            coords,
            coords - vector3(
                0.0,
                0.0,
                0.1
            ),
            0,
            true,
            flareWeapon,
            ped,
            true,
            false,
            1.0
        )

        RemoveWeaponAsset(
            flareWeapon
        )

        notify(
            Config.Notifications.planeIncoming,
            'warning'
        )

        CreateThread(function()
            local finishTime =
                GetGameTimer() +
                (
                    Config.PlaneArrivalSeconds or 10
                ) * 1000

            while GetGameTimer() < finishTime do
                Wait(0)

                local remaining =
                    math.ceil(
                        (
                            finishTime -
                            GetGameTimer()
                        ) / 1000
                    )

                SetTextFont(4)
                SetTextProportional(0)
                SetTextScale(
                    0.45,
                    0.45
                )

                SetTextColour(
                    255,
                    255,
                    255,
                    255
                )

                SetTextCentre(true)
                SetTextOutline()

                BeginTextCommandDisplayText(
                    'STRING'
                )

                AddTextComponentSubstringPlayerName(
                    (
                        '~r~AIR DROP~s~ | Aircraft arrival: ~y~%s~s~'
                    ):format(
                        remaining
                    )
                )

                EndTextCommandDisplayText(
                    0.5,
                    0.82
                )
            end

            if dropState == 'incoming' then
                CrateDrop()
            end
        end)
    end
)


-- ============================================================================
-- AIRCRAFT / CRATE DROP
-- ============================================================================

function CrateDrop()
    if not currentZone then
        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        return
    end

    if dropState ~= 'incoming' then
        return
    end

    local aircraftModel =
        requestModel(
            Config.AircraftModel
        )

    local pilotModel =
        requestModel(
            Config.PilotModel
        )

    local crateModel =
        requestModel(
            Config.CrateModel
        )

    local parachuteModel =
        requestModel(
            Config.ParachuteModel
        )

    local pickupModel =
        requestModel(
            Config.PickupModel
        )

    if not aircraftModel
        or not pilotModel
        or not crateModel
        or not parachuteModel
        or not pickupModel then

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    local dropCoords =
        currentZone.coords

    -- ========================================================================
    -- FLIGHT DIRECTION
    -- ========================================================================

    local heading =
        math.random(0, 359) + 0.0

    local angle =
        math.rad(heading)

    local direction = vector3(
        math.cos(angle),
        math.sin(angle),
        0.0
    )

    local spawnDistance =
        getPlaneSpawnDistance()

    local altitude =
        getDropHeight()

    local spawnCoords = vector3(
        dropCoords.x -
            direction.x *
            spawnDistance,

        dropCoords.y -
            direction.y *
            spawnDistance,

        dropCoords.z +
            altitude
    )

    -- ========================================================================
    -- AIRCRAFT
    -- ========================================================================

    aircraft = CreateVehicle(
        aircraftModel,
        spawnCoords.x,
        spawnCoords.y,
        spawnCoords.z,
        heading,
        true,
        true
    )

    if not DoesEntityExist(aircraft) then
        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    SetEntityAsMissionEntity(
        aircraft,
        true,
        true
    )

    SetVehicleDoorsLocked(
        aircraft,
        2
    )

    SetEntityInvincible(
        aircraft,
        true
    )

    SetVehicleEngineOn(
        aircraft,
        true,
        true,
        false
    )

    SetEntityHeading(
        aircraft,
        heading
    )

    SetVehicleForwardSpeed(
        aircraft,
        getPlaneSpeed()
    )

    -- ========================================================================
    -- PILOT
    -- ========================================================================

    pilot = CreatePedInsideVehicle(
        aircraft,
        4,
        pilotModel,
        -1,
        true,
        true
    )

    if not DoesEntityExist(pilot) then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    SetEntityAsMissionEntity(
        pilot,
        true,
        true
    )

    SetBlockingOfNonTemporaryEvents(
        pilot,
        true
    )

    SetPedKeepTask(
        pilot,
        true
    )

    SetPedCanRagdoll(
        pilot,
        false
    )

    SetEntityInvincible(
        pilot,
        true
    )

    -- ========================================================================
    -- AIRCRAFT APPROACH
    -- ========================================================================

    TaskVehicleDriveToCoord(
        pilot,
        aircraft,
        dropCoords.x,
        dropCoords.y,
        dropCoords.z + altitude,
        getPlaneSpeed(),
        0,
        aircraftModel,
        262144,
        20.0,
        -1.0
    )

    local timeout =
        GetGameTimer() +
        (getPlaneTimeout() * 1000)

    local planeReachedDrop = false

    while DoesEntityExist(aircraft)
        and DoesEntityExist(pilot)
        and not IsEntityDead(pilot) do

        Wait(100)

        local planeCoords =
            GetEntityCoords(aircraft)

        local horizontalDistance =
            #(vector2(
                planeCoords.x,
                planeCoords.y
            ) - vector2(
                dropCoords.x,
                dropCoords.y
            ))

        local altitudeDifference =
            math.abs(
                planeCoords.z -
                (
                    dropCoords.z +
                    altitude
                )
            )

        if horizontalDistance <= 25.0
            and altitudeDifference <= 80.0 then

            planeReachedDrop = true

            break
        end

        if GetGameTimer() >= timeout then
            CleanupDropEntities()

            TriggerServerEvent(
                'cb_airdrop:server:dropFailed'
            )

            releaseModels()

            return
        end
    end

    if not planeReachedDrop then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    -- ========================================================================
    -- RELEASE POINT
    -- ========================================================================

    local releaseCoords =
        GetEntityCoords(aircraft)

    local releaseHeight =
        releaseCoords.z - 6.0

    local crateCoords = vector3(
        releaseCoords.x,
        releaseCoords.y,
        releaseHeight
    )

    local releaseDistance =
        #(vector2(
            crateCoords.x,
            crateCoords.y
        ) - vector2(
            dropCoords.x,
            dropCoords.y
        ))

    if releaseDistance > 35.0 then
        crateCoords = vector3(
            dropCoords.x,
            dropCoords.y,
            releaseHeight
        )
    end

    -- ========================================================================
    -- CRATE
    -- ========================================================================

    crate = CreateObject(
        crateModel,
        crateCoords.x,
        crateCoords.y,
        crateCoords.z,
        true,
        true,
        true
    )

    if not DoesEntityExist(crate) then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    SetEntityAsMissionEntity(
        crate,
        true,
        true
    )

    FreezeEntityPosition(
        crate,
        false
    )

    SetEntityCollision(
        crate,
        true,
        true
    )

    ActivatePhysics(
        crate
    )

    -- ========================================================================
    -- AIRCRAFT LEAVES
    -- ========================================================================

    local exitDistance = 2500.0

    local exitCoords = vector3(
        dropCoords.x +
            direction.x *
            exitDistance,

        dropCoords.y +
            direction.y *
            exitDistance,

        dropCoords.z +
            altitude +
            500.0
    )

    TaskVehicleDriveToCoord(
        pilot,
        aircraft,
        exitCoords.x,
        exitCoords.y,
        exitCoords.z,
        getPlaneSpeed() * 1.15,
        0,
        aircraftModel,
        262144,
        30.0,
        -1.0
    )

    -- ========================================================================
    -- FREE FALL
    -- ========================================================================

    local freeFallSeconds =
        Config.CrateFreeFallSeconds or 1.5

    local freeFallEnd =
        GetGameTimer() +
        (
            freeFallSeconds *
            1000
        )

    SetEntityVelocity(
        crate,
        0.0,
        0.0,
        -8.0
    )

    while DoesEntityExist(crate)
        and GetGameTimer() < freeFallEnd do

        Wait(50)

        local coords =
            GetEntityCoords(crate)

        local foundGround, groundZ =
            getGroundHeight(
                coords,
                crate
            )

        if foundGround
            and coords.z <= groundZ + 25.0 then

            break
        end
    end

    if not DoesEntityExist(crate) then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    -- ========================================================================
    -- PARACHUTE
    -- ========================================================================

    local crateCurrentCoords =
        GetEntityCoords(crate)

    parachute = CreateObject(
        parachuteModel,
        crateCurrentCoords.x,
        crateCurrentCoords.y,
        crateCurrentCoords.z + 5.0,
        true,
        true,
        true
    )

    if not DoesEntityExist(parachute) then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    SetEntityAsMissionEntity(
        parachute,
        true,
        true
    )

    SetEntityCollision(
        parachute,
        false,
        false
    )

    AttachEntityToEntity(
        parachute,
        crate,
        0,
        0.0,
        0.0,
        5.0,
        0.0,
        0.0,
        0.0,
        false,
        false,
        false,
        false,
        2,
        true
    )

    -- ========================================================================
    -- CONTROLLED DESCENT
    -- ========================================================================

    local descentSpeed =
        Config.CrateDescentSpeed or 5.5

    local landingTimeout =
        GetGameTimer() +
        (
            Config.CrateLandingTimeoutSeconds or 90
        ) * 1000

    local landed = false
    local landingCoords = nil

    while DoesEntityExist(crate) do
        Wait(50)

        local coords =
            GetEntityCoords(crate)

        local foundGround, groundZ =
            getGroundHeight(
                coords,
                crate
            )

        if foundGround then
            local targetZ =
                groundZ +
                getModelGroundOffset(
                    Config.CrateModel
                ) +
                getGroundDistance()

            local distanceToGround =
                coords.z - targetZ

            if distanceToGround <= 1.0 then
                SetEntityCoords(
                    crate,
                    coords.x,
                    coords.y,
                    targetZ,
                    false,
                    false,
                    false,
                    false
                )

                SetEntityVelocity(
                    crate,
                    0.0,
                    0.0,
                    0.0
                )

                FreezeEntityPosition(
                    crate,
                    true
                )

                landingCoords =
                    vector3(
                        coords.x,
                        coords.y,
                        targetZ
                    )

                landed = true

                break
            end

            local delta =
                math.min(
                    descentSpeed * 0.05,
                    distanceToGround
                )

            local nextZ =
                coords.z - delta

            SetEntityCoordsNoOffset(
                crate,
                coords.x,
                coords.y,
                nextZ,
                false,
                false,
                false
            )

            SetEntityVelocity(
                crate,
                0.0,
                0.0,
                0.0
            )
        else
            local nextZ =
                coords.z -
                (
                    descentSpeed *
                    0.05
                )

            SetEntityCoordsNoOffset(
                crate,
                coords.x,
                coords.y,
                nextZ,
                false,
                false,
                false
            )

            SetEntityVelocity(
                crate,
                0.0,
                0.0,
                0.0
            )
        end

        if GetGameTimer() >= landingTimeout then
            break
        end
    end

    -- =========================================================================
    -- FINAL LANDING VALIDATION
    -- =========================================================================

    if not landed and DoesEntityExist(crate) then
        local coords =
            GetEntityCoords(crate)

        local foundGround, groundZ =
            getGroundHeight(
                coords,
                crate
            )

        if foundGround then
            local targetZ =
                groundZ +
                getModelGroundOffset(
                    Config.CrateModel
                ) +
                getGroundDistance()

            SetEntityCoords(
                crate,
                coords.x,
                coords.y,
                targetZ,
                false,
                false,
                false,
                false
            )

            SetEntityVelocity(
                crate,
                0.0,
                0.0,
                0.0
            )

            FreezeEntityPosition(
                crate,
                true
            )

            landingCoords =
                vector3(
                    coords.x,
                    coords.y,
                    targetZ
                )

            landed = true
        end
    end

    if not landed or not landingCoords then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    -- ========================================================================
    -- PARACHUTE DETACH
    -- ========================================================================

    if DoesEntityExist(parachute) then
        DetachEntity(
            parachute,
            true,
            true
        )

        DeleteEntity(
            parachute
        )

        parachute = nil
    end

    -- ========================================================================
    -- FINAL CRATE POSITION
    -- ========================================================================

    if DoesEntityExist(crate) then
        local coords =
            GetEntityCoords(crate)

        local foundGround, groundZ =
            getGroundHeight(
                coords,
                crate
            )

        if foundGround then
            local finalZ =
                groundZ +
                getModelGroundOffset(
                    Config.CrateModel
                ) +
                getGroundDistance()

            SetEntityCoords(
                crate,
                coords.x,
                coords.y,
                finalZ,
                false,
                false,
                false,
                false
            )

            landingCoords =
                vector3(
                    coords.x,
                    coords.y,
                    finalZ
                )
        end

        FreezeEntityPosition(
            crate,
            true
        )
    end

    -- ========================================================================
    -- REMOVE PHYSICAL CRATE
    -- ========================================================================

    if DoesEntityExist(crate) then
        DeleteEntity(crate)
        crate = nil
    end

    -- ========================================================================
    -- CREATE FINAL PICKUP
    -- ========================================================================

    pickup = CreateObject(
        pickupModel,
        landingCoords.x,
        landingCoords.y,
        landingCoords.z,
        true,
        true,
        true
    )

    if not DoesEntityExist(pickup) then
        CleanupDropEntities()

        TriggerServerEvent(
            'cb_airdrop:server:dropFailed'
        )

        releaseModels()

        return
    end

    SetEntityAsMissionEntity(
        pickup,
        true,
        true
    )

    -- Position the visual pickup against the actual ground.
    local foundPickupGround, pickupGroundZ =
        getGroundHeight(
            landingCoords,
            pickup
        )

    if foundPickupGround then
        local pickupZ =
            pickupGroundZ +
            getModelGroundOffset(
                Config.PickupModel
            )

        SetEntityCoords(
            pickup,
            landingCoords.x,
            landingCoords.y,
            pickupZ,
            false,
            false,
            false,
            false
        )
    else
        SetEntityCoords(
            pickup,
            landingCoords.x,
            landingCoords.y,
            landingCoords.z,
            false,
            false,
            false,
            false
        )
    end

    SetEntityCollision(
        pickup,
        true,
        true
    )

    FreezeEntityPosition(
        pickup,
        true
    )

    -- =========================================================================
    -- OX TARGET - SPHERE ZONE
    -- =========================================================================
    --
    -- The visual pickup remains the object.
    -- Interaction is handled by an ox_target sphere positioned exactly
    -- at the final landing coordinates. This avoids depending on the
    -- pickup model being hit by the target raycast.
    --
    -- ox_target officially supports addSphereZone and returns a zone id
    -- which can later be removed with removeZone.
    --

    pickupZone = exports.ox_target:addSphereZone({
        name = 'cb_airdrop_loot_zone',
        coords = vector3(
            landingCoords.x,
            landingCoords.y,
            landingCoords.z
        ),
        radius = 2.0,
        debug = Config.Debug,
        drawSprite = Config.Debug,

        options = {
            {
                name = 'cb_airdrop_loot',
                icon = 'fa-solid fa-box-open',
                iconColor = '#c9a227',
                label = 'Search supply crate',
                distance = Config.LootDistance,

                canInteract = function()
                    return dropState == 'ready'
                end,

                onSelect = function()
                    StartLoot()
                end
            }
        }
    })

    -- =========================================================================
    -- DROP READY
    -- =========================================================================

    TriggerServerEvent(
        'cb_airdrop:server:dropReady',
        {
            x = landingCoords.x,
            y = landingCoords.y,
            z = landingCoords.z
        }
    )

    TriggerEvent(
        'cb_airdrop:client:setDropBlip',
        landingCoords
    )

    -- =========================================================================
    -- AIRCRAFT CLEANUP
    -- =========================================================================

    local aircraftToCleanup = aircraft
    local pilotToCleanup = pilot

    aircraft = nil
    pilot = nil

    CreateThread(function()
        local cleanupTimeout =
            GetGameTimer() + 90000

        while GetGameTimer() < cleanupTimeout do
            Wait(1000)

            if not DoesEntityExist(
                aircraftToCleanup
            ) then
                break
            end

            local planeCoords =
                GetEntityCoords(
                    aircraftToCleanup
                )

            local distance =
                #(vector2(
                    planeCoords.x,
                    planeCoords.y
                ) - vector2(
                    dropCoords.x,
                    dropCoords.y
                ))

            if distance >= 1800.0 then
                break
            end
        end

        if DoesEntityExist(
            pilotToCleanup
        ) then
            DeleteEntity(
                pilotToCleanup
            )
        end

        if DoesEntityExist(
            aircraftToCleanup
        ) then
            DeleteEntity(
                aircraftToCleanup
            )
        end
    end)

    releaseModels()
end


-- ============================================================================
-- LOOT
-- ============================================================================

function StartLoot()
    if dropState ~= 'ready' then
        return
    end

    if not DoesEntityExist(pickup) then
        return
    end

    local accepted =
        lib.callback.await(
            'cb_airdrop:server:beginLoot',
            false
        )

    if not accepted then
        notify(
            Config.Notifications.crateAlreadyLooted,
            'error'
        )

        return
    end

    local completed =
        lib.progressBar({
            duration = Config.LootDuration,
            label = 'Searching survival supplies...',
            useWhileDead = false,
            canCancel = true,

            disable = {
                move = true,
                car = true,
                combat = true,
                sprint = true
            },

            anim = {
                dict =
                    'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',

                clip =
                    'machinic_loop_mechandplayer',

                flag = 49
            }
        })

    if not completed then
        TriggerServerEvent(
            'cb_airdrop:server:cancelLoot'
        )

        notify(
            Config.Notifications.lootCancelled,
            'error'
        )

        return
    end

    TriggerServerEvent(
        'cb_airdrop:server:completeLoot'
    )
end


-- ============================================================================
-- DROP REMOVED
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:client:removeDrop',
    function()
        dropState = 'claimed'

        dropBlip = removeBlip(
            dropBlip
        )

        -- Remove the ox_target interaction zone first.
        if pickupZone then
            exports.ox_target:removeZone(
                pickupZone
            )

            pickupZone = nil
        end

        if DoesEntityExist(pickup) then
            DeleteEntity(
                pickup
            )
        end

        pickup = nil

        notify(
            Config.Notifications.lootSuccess,
            'success'
        )
    end
)


-- ============================================================================
-- CLEANUP
-- ============================================================================

function CleanupDropEntities()
    if pickupZone then
        exports.ox_target:removeZone(
            pickupZone
        )

        pickupZone = nil
    end

    if DoesEntityExist(parachute) then
        DetachEntity(
            parachute,
            true,
            true
        )

        DeleteEntity(
            parachute
        )
    end

    parachute = nil

    if DoesEntityExist(pickup) then
        DetachEntity(
            pickup,
            true,
            true
        )

        DeleteEntity(
            pickup
        )
    end

    pickup = nil

    if DoesEntityExist(crate) then
        DeleteEntity(
            crate
        )
    end

    crate = nil

    if DoesEntityExist(pilot) then
        DeleteEntity(
            pilot
        )
    end

    pilot = nil

    if DoesEntityExist(aircraft) then
        DeleteEntity(
            aircraft
        )
    end

    aircraft = nil
end


-- ============================================================================
-- RESOURCE STOP
-- ============================================================================

AddEventHandler(
    'onResourceStop',
    function(resourceName)
        if resourceName ~= GetCurrentResourceName() then
            return
        end

        CleanupDropEntities()

        zoneBlip = removeBlip(
            zoneBlip
        )

        dropBlip = removeBlip(
            dropBlip
        )

        policeBlip = removeBlip(
            policeBlip
        )
    end
)