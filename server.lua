local ESX = exports['es_extended']:getSharedObject()
local oxInventory = exports.ox_inventory

local currentZone = nil
local dropState = 'idle'
local dropCoords = nil
local dropNetId = nil
local cooldownUntil = 0
local lootClaimer = nil
local policeAlertActive = false

local function debugPrint(message)
    if Config.Debug then print(('[cb_airdrop] %s'):format(message)) end
end

local function notifyPlayer(source, message, type)
    TriggerClientEvent('cb_airdrop:client:notify', source, message, type or 'inform')
end

local function getPoliceCount()
    local count = 0
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer and xPlayer.job and xPlayer.job.name == Config.PoliceJobName then count = count + 1 end
    end
    return count
end

local function getPlayerCoords(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function isPlayerInDropZone(source)
    if not currentZone then return false end
    local coords = getPlayerCoords(source)
    if not coords then return false end
    return #(coords - currentZone.coords) <= currentZone.radius + Config.FlareZoneDistance
end

local function isPlayerNearDrop(source)
    if not dropCoords then return false end
    local coords = getPlayerCoords(source)
    if not coords then return false end
    return #(coords - dropCoords) <= Config.LootDistance
end

local function isValidDropPosition(coords)
    if not currentZone or not coords then return false end
    return #(coords - currentZone.coords) <= currentZone.radius + 100.0
end

local function setDropState(state)
    dropState = state
    TriggerClientEvent('cb_airdrop:client:setDropState', -1, state)
end

local function removePoliceAlerts()
    if not policeAlertActive then return end
    policeAlertActive = false
    for _, playerId in ipairs(ESX.GetPlayers()) do
        TriggerClientEvent('cb_airdrop:client:removePoliceBlip', playerId)
    end
end

local function sendPoliceAlert()
    if policeAlertActive or not currentZone then return end
    if not Config.AlertCops and not Config.AlertAllPlayers then return end

    policeAlertActive = true
    for _, playerId in ipairs(ESX.GetPlayers()) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        local send = Config.AlertAllPlayers
        if not send and Config.AlertCops then
            send = xPlayer and xPlayer.job and xPlayer.job.name == Config.PoliceJobName
        end
        if send then
            TriggerClientEvent('cb_airdrop:client:setPoliceBlip', playerId, currentZone.coords)
            notifyPlayer(playerId, Config.Notifications.policeAlert, 'warning')
        end
    end

    CreateThread(function()
        Wait(Config.PoliceBlipDurationSeconds * 1000)
        if policeAlertActive then removePoliceAlerts() end
    end)
end

local function selectRandomZone()
    if not Config.Zones or #Config.Zones == 0 then
        print('^1[cb_airdrop] ERROR:^7 No zones configured.')
        return
    end
    currentZone = Config.Zones[math.random(1, #Config.Zones)]
    TriggerClientEvent('cb_airdrop:client:setZone', -1, currentZone)
    debugPrint(('New zone selected: %s'):format(currentZone.name or 'unknown'))
end

CreateThread(function()
    Wait(1000)
    math.randomseed(os.time())
    selectRandomZone()
end)

RegisterNetEvent('cb_airdrop:server:requestZone', function()
    local source = source
    if currentZone then TriggerClientEvent('cb_airdrop:client:setZone', source, currentZone) end
    TriggerClientEvent('cb_airdrop:client:setDropState', source, dropState)
    if dropState == 'ready' and dropCoords then
        TriggerClientEvent('cb_airdrop:client:setDropBlip', source, dropCoords)
        if dropNetId then TriggerClientEvent('cb_airdrop:client:registerDropEntity', source, dropNetId) end
    end
end)

CreateThread(function()
    while true do
        Wait(Config.ZoneRotationSeconds * 1000)
        if dropState == 'idle' or dropState == 'claimed' or dropState == 'failed' then selectRandomZone() end
    end
end)

exports('useFlare', function(event, item, inventory, slot, data)
    if event ~= 'usingItem' then return end
    local source = inventory.id
    if not ESX.GetPlayerFromId(source) then return false end

    if not currentZone then
        notifyPlayer(source, Config.Notifications.dropUnavailable, 'error')
        return false
    end

    if dropState ~= 'idle' and dropState ~= 'claimed' and dropState ~= 'failed' then
        notifyPlayer(source, Config.Notifications.alreadyActive, 'error')
        return false
    end

    local now = GetGameTimer()
    if now < cooldownUntil then
        notifyPlayer(source, ('%s %s seconds.'):format(Config.Notifications.cooldown, math.ceil((cooldownUntil - now) / 1000)), 'error')
        return false
    end

    if not isPlayerInDropZone(source) then
        notifyPlayer(source, Config.Notifications.flareOutsideZone, 'error')
        return false
    end

    if Config.CopsRequired > 0 and getPoliceCount() < Config.CopsRequired then
        notifyPlayer(source, Config.Notifications.notEnoughCops, 'error')
        return false
    end

    dropCoords = vector3(currentZone.coords.x, currentZone.coords.y, currentZone.coords.z)
    dropNetId = nil
    lootClaimer = nil
    setDropState('incoming')
    sendPoliceAlert()
    TriggerClientEvent('cb_airdrop:client:startFlare', source)
    debugPrint(('Airdrop requested by %s'):format(source))
    return true
end)

RegisterNetEvent('cb_airdrop:server:dropReady', function(coords, netId)
    local source = source
    if dropState ~= 'incoming' then return end
    if not coords or not coords.x or not coords.y or not coords.z then return end

    netId = tonumber(netId)
    if not netId or netId <= 0 then
        debugPrint(('Rejected invalid crate NetID from %s.'):format(source))
        return
    end

    local finalCoords = vector3(tonumber(coords.x), tonumber(coords.y), tonumber(coords.z))
    if not isValidDropPosition(finalCoords) then
        debugPrint(('Rejected invalid drop position from %s.'):format(source))
        return
    end

    dropCoords = finalCoords
    dropNetId = netId
    setDropState('ready')
    TriggerClientEvent('cb_airdrop:client:setDropBlip', -1, dropCoords)
    TriggerClientEvent('cb_airdrop:client:registerDropEntity', -1, dropNetId)
    debugPrint(('Airdrop ready at %.2f %.2f %.2f, crate NetID %s.'):format(dropCoords.x, dropCoords.y, dropCoords.z, dropNetId))
end)

RegisterNetEvent('cb_airdrop:server:dropFailed', function()
    if dropState ~= 'incoming' then return end
    lootClaimer = nil
    dropCoords = nil
    dropNetId = nil
    setDropState('failed')
    removePoliceAlerts()
    CreateThread(function()
        Wait(5000)
        if dropState == 'failed' then setDropState('idle') end
    end)
end)

lib.callback.register('cb_airdrop:server:beginLoot', function(source)
    if dropState ~= 'ready' or lootClaimer or not dropCoords or not dropNetId then return false end
    if not isPlayerNearDrop(source) then return false end
    lootClaimer = source
    return true
end)

RegisterNetEvent('cb_airdrop:server:cancelLoot', function()
    if lootClaimer == source then lootClaimer = nil end
end)

RegisterNetEvent('cb_airdrop:server:completeLoot', function()
    local source = source
    if lootClaimer ~= source or dropState ~= 'ready' then return end

    if not isPlayerNearDrop(source) then
        lootClaimer = nil
        notifyPlayer(source, Config.Notifications.crateEmpty, 'error')
        return
    end

    lootClaimer = nil
    setDropState('claimed')
    removePoliceAlerts()

    for i = 1, Config.LootItemsCount do
        if #Config.Loot > 0 then
            local loot = Config.Loot[math.random(1, #Config.Loot)]
            if loot and loot.item and loot.count > 0 and oxInventory:CanCarryItem(source, loot.item, loot.count) then
                oxInventory:AddItem(source, loot.item, loot.count)
            end
        end
    end

    if Config.WeaponLootEnabled and #Config.WeaponLoot > 0 and math.random(1, 100) <= Config.WeaponGetChance then
        local weapon = Config.WeaponLoot[math.random(1, #Config.WeaponLoot)]
        if weapon and weapon.weapon then
            local metadata = { ammo = weapon.ammo or 0 }
            if oxInventory:CanCarryItem(source, weapon.weapon, 1, metadata) then
                oxInventory:AddItem(source, weapon.weapon, 1, metadata)
            else
                notifyPlayer(source, Config.Notifications.inventoryFull, 'error')
            end
        end
    end

    cooldownUntil = GetGameTimer() + Config.CooldownMinutes * 60000
    TriggerClientEvent('cb_airdrop:client:removeDrop', -1)
    notifyPlayer(source, Config.Notifications.lootSuccess, 'success')

    CreateThread(function()
        Wait(3000)
        dropCoords = nil
        dropNetId = nil
        if dropState == 'claimed' then setDropState('idle') end
    end)
end)

AddEventHandler('playerDropped', function()
    if lootClaimer == source then lootClaimer = nil end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removePoliceAlerts() end
end)
