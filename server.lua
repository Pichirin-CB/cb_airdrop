local ESX = exports['es_extended']:getSharedObject()
local oxInventory = exports.ox_inventory

-- ============================================================================
-- STATE
-- ============================================================================

local currentZone = nil

local dropState = 'idle'

local dropCoords = nil

local cooldownUntil = 0

local lootClaimer = nil

local policeAlertActive = false

-- ============================================================================
-- HELPERS
-- ============================================================================

local function debugPrint(message)
    if Config.Debug then
        print(
            ('[cb_airdrop] %s'):format(message)
        )
    end
end


local function notifyPlayer(
    source,
    message,
    type
)
    TriggerClientEvent(
        'cb_airdrop:client:notify',
        source,
        message,
        type
    )
end


local function getPoliceCount()
    local count = 0

    local players = ESX.GetPlayers()

    for i = 1, #players do
        local playerId = players[i]

        local xPlayer =
            ESX.GetPlayerFromId(playerId)

        if xPlayer
            and xPlayer.job
            and xPlayer.job.name ==
                Config.PoliceJobName then

            count = count + 1
        end
    end

    return count
end


local function getPlayerCoords(source)
    local ped =
        GetPlayerPed(source)

    if not ped or ped == 0 then
        return nil
    end

    local coords =
        GetEntityCoords(ped)

    if not coords then
        return nil
    end

    return coords
end


local function isPlayerInDropZone(source)
    if not currentZone then
        return false
    end

    local coords =
        getPlayerCoords(source)

    if not coords then
        return false
    end

    local distance =
        #(coords - currentZone.coords)

    return distance <=
        (
            currentZone.radius +
            Config.FlareZoneDistance
        )
end


local function isPlayerNearDrop(source)
    if not dropCoords then
        return false
    end

    local coords =
        getPlayerCoords(source)

    if not coords then
        return false
    end

    local distance =
        #(coords - dropCoords)

    return distance <=
        Config.LootDistance
end


local function isValidDropPosition(coords)
    if not currentZone then
        return false
    end

    if not coords then
        return false
    end

    local distance =
        #(coords - currentZone.coords)

    -- The crate must remain inside the configured active zone.
    return distance <=
        (
            currentZone.radius +
            100.0
        )
end


local function broadcastState()
    TriggerClientEvent(
        'cb_airdrop:client:setDropState',
        -1,
        dropState
    )
end


local function removePoliceAlerts()
    if not policeAlertActive then
        return
    end

    policeAlertActive = false

    local players = ESX.GetPlayers()

    for i = 1, #players do
        local playerId = players[i]

        local xPlayer =
            ESX.GetPlayerFromId(playerId)

        if xPlayer
            and xPlayer.job
            and xPlayer.job.name ==
                Config.PoliceJobName then

            TriggerClientEvent(
                'cb_airdrop:client:removePoliceBlip',
                playerId
            )
        end

        if Config.AlertAllPlayers then
            TriggerClientEvent(
                'cb_airdrop:client:removePoliceBlip',
                playerId
            )
        end
    end
end


local function sendPoliceAlert()
    if policeAlertActive then
        return
    end

    if not currentZone then
        return
    end

    if not Config.AlertCops
        and not Config.AlertAllPlayers then

        return
    end

    policeAlertActive = true

    local coords = currentZone.coords

    local players = ESX.GetPlayers()

    for i = 1, #players do
        local playerId = players[i]

        local xPlayer =
            ESX.GetPlayerFromId(playerId)

        if xPlayer
            and xPlayer.job then

            if Config.AlertCops
                and xPlayer.job.name ==
                    Config.PoliceJobName then

                TriggerClientEvent(
                    'cb_airdrop:client:setPoliceBlip',
                    playerId,
                    coords
                )

                notifyPlayer(
                    playerId,
                    Config.Notifications.policeAlert,
                    'warning'
                )
            end
        end

        if Config.AlertAllPlayers then
            TriggerClientEvent(
                'cb_airdrop:client:setPoliceBlip',
                playerId,
                coords
            )

            notifyPlayer(
                playerId,
                Config.Notifications.policeAlert,
                'warning'
            )
        end
    end

    CreateThread(function()
        Wait(
            Config.PoliceBlipDurationSeconds *
            1000
        )

        if policeAlertActive then
            removePoliceAlerts()
        end
    end)
end


local function setDropState(state)
    dropState = state

    broadcastState()
end


-- ============================================================================
-- ZONE MANAGEMENT
-- ============================================================================

local function selectRandomZone()
    if not Config.Zones
        or #Config.Zones == 0 then

        print(
            '^1[cb_airdrop] ERROR:^7 No zones configured.'
        )

        currentZone = nil

        return
    end

    local index =
        math.random(
            1,
            #Config.Zones
        )

    currentZone =
        Config.Zones[index]

    TriggerClientEvent(
        'cb_airdrop:client:setZone',
        -1,
        currentZone
    )

    debugPrint(
        ('New zone selected: %s'):format(
            currentZone.name or index
        )
    )
end


-- ============================================================================
-- STARTUP
-- ============================================================================

CreateThread(function()
    Wait(1000)

    math.randomseed(
        os.time()
    )

    selectRandomZone()
end)


-- ============================================================================
-- ZONE REQUEST
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:server:requestZone',
    function()
        local source = source

        if currentZone then
            TriggerClientEvent(
                'cb_airdrop:client:setZone',
                source,
                currentZone
            )
        end

        TriggerClientEvent(
            'cb_airdrop:client:setDropState',
            source,
            dropState
        )

        if dropState == 'ready'
            and dropCoords then

            TriggerClientEvent(
                'cb_airdrop:client:setDropBlip',
                source,
                dropCoords
            )
        end
    end
)


-- ============================================================================
-- ZONE ROTATION
-- ============================================================================

CreateThread(function()
    while true do
        Wait(
            Config.ZoneRotationSeconds *
            1000
        )

        if dropState == 'idle'
            or dropState == 'claimed'
            or dropState == 'failed' then

            selectRandomZone()
        end
    end
end)


-- ============================================================================
-- OX INVENTORY FLARE
-- ============================================================================

exports('useFlare', function(
    event,
    item,
    inventory,
    slot,
    data
)
    if event ~= 'usingItem' then
        return
    end

    local source =
        inventory.id

    local xPlayer =
        ESX.GetPlayerFromId(source)

    if not xPlayer then
        return false
    end

    -- ------------------------------------------------------------------------
    -- ZONE CHECK
    -- ------------------------------------------------------------------------

    if not currentZone then
        notifyPlayer(
            source,
            Config.Notifications.dropUnavailable,
            'error'
        )

        return false
    end

    -- ------------------------------------------------------------------------
    -- ACTIVE DROP CHECK
    -- ------------------------------------------------------------------------

    if dropState ~= 'idle'
        and dropState ~= 'claimed'
        and dropState ~= 'failed' then

        notifyPlayer(
            source,
            Config.Notifications.alreadyActive,
            'error'
        )

        return false
    end

    -- ------------------------------------------------------------------------
    -- COOLDOWN CHECK
    -- ------------------------------------------------------------------------

    local now =
        GetGameTimer()

    if now < cooldownUntil then
        local remaining =
            math.ceil(
                (
                    cooldownUntil -
                    now
                ) / 1000
            )

        notifyPlayer(
            source,
            ('%s %s seconds.'):format(
                Config.Notifications.cooldown,
                remaining
            ),
            'error'
        )

        return false
    end

    -- ------------------------------------------------------------------------
    -- ZONE DISTANCE CHECK
    -- ------------------------------------------------------------------------

    if not isPlayerInDropZone(source) then
        notifyPlayer(
            source,
            Config.Notifications.flareOutsideZone,
            'error'
        )

        return false
    end

    -- ------------------------------------------------------------------------
    -- POLICE CHECK
    -- ------------------------------------------------------------------------

    if Config.CopsRequired > 0 then
        local police =
            getPoliceCount()

        if police < Config.CopsRequired then
            notifyPlayer(
                source,
                Config.Notifications.notEnoughCops,
                'error'
            )

            return false
        end
    end

    -- ------------------------------------------------------------------------
    -- LOCK DROP
    -- ------------------------------------------------------------------------

    dropCoords =
        vector3(
            currentZone.coords.x,
            currentZone.coords.y,
            currentZone.coords.z
        )

    lootClaimer = nil

    setDropState('incoming')

    sendPoliceAlert()

    TriggerClientEvent(
        'cb_airdrop:client:startFlare',
        source
    )

    debugPrint(
        ('Airdrop requested by %s'):format(
            source
        )
    )

    return true
end)


-- ============================================================================
-- DROP READY
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:server:dropReady',
    function(coords)
        local source = source

        if dropState ~= 'incoming' then
            return
        end

        if not coords
            or not coords.x
            or not coords.y
            or not coords.z then

            return
        end

        local finalCoords =
            vector3(
                tonumber(coords.x),
                tonumber(coords.y),
                tonumber(coords.z)
            )

        if not isValidDropPosition(
            finalCoords
        ) then

            debugPrint(
                (
                    'Rejected invalid drop position from player %s.'
                ):format(source)
            )

            return
        end

        dropCoords =
            finalCoords

        setDropState('ready')

        TriggerClientEvent(
            'cb_airdrop:client:setDropBlip',
            -1,
            dropCoords
        )

        debugPrint(
            (
                'Airdrop ready at %.2f %.2f %.2f.'
            ):format(
                dropCoords.x,
                dropCoords.y,
                dropCoords.z
            )
        )
    end
)


-- ============================================================================
-- DROP FAILED
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:server:dropFailed',
    function()
        if dropState ~= 'incoming' then
            return
        end

        lootClaimer = nil
        dropCoords = nil

        setDropState('failed')

        removePoliceAlerts()

        debugPrint(
            'Airdrop failed.'
        )

        CreateThread(function()
            Wait(5000)

            if dropState == 'failed' then
                setDropState('idle')
            end
        end)
    end
)


-- ============================================================================
-- BEGIN LOOT
-- ============================================================================

lib.callback.register(
    'cb_airdrop:server:beginLoot',
    function(source)
        if dropState ~= 'ready' then
            return false
        end

        if lootClaimer then
            return false
        end

        if not dropCoords then
            return false
        end

        if not isPlayerNearDrop(source) then
            return false
        end

        lootClaimer = source

        debugPrint(
            (
                'Player %s started looting the airdrop.'
            ):format(source)
        )

        return true
    end
)


-- ============================================================================
-- CANCEL LOOT
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:server:cancelLoot',
    function()
        local source = source

        if lootClaimer ~= source then
            return
        end

        lootClaimer = nil

        debugPrint(
            (
                'Player %s cancelled looting.'
            ):format(source)
        )
    end
)


-- ============================================================================
-- COMPLETE LOOT
-- ============================================================================

RegisterNetEvent(
    'cb_airdrop:server:completeLoot',
    function()
        local source = source

        if lootClaimer ~= source then
            return
        end

        if dropState ~= 'ready' then
            lootClaimer = nil

            return
        end

        if not isPlayerNearDrop(source) then
            lootClaimer = nil

            notifyPlayer(
                source,
                Config.Notifications.crateEmpty,
                'error'
            )

            return
        end

        -- Lock the drop before giving anything.
        lootClaimer = nil

        setDropState('claimed')

        removePoliceAlerts()

        -- --------------------------------------------------------------------
        -- RANDOM ITEM LOOT
        -- --------------------------------------------------------------------

        local itemsToGive =
            Config.LootItemsCount

        for i = 1, itemsToGive do
            if #Config.Loot > 0 then
                local index =
                    math.random(
                        1,
                        #Config.Loot
                    )

                local loot =
                    Config.Loot[index]

                if loot
                    and loot.item
                    and loot.count
                    and loot.count > 0 then

                    if oxInventory:CanCarryItem(
                        source,
                        loot.item,
                        loot.count
                    ) then

                        oxInventory:AddItem(
                            source,
                            loot.item,
                            loot.count
                        )
                    end
                end
            end
        end

        -- --------------------------------------------------------------------
        -- WEAPON LOOT
        -- --------------------------------------------------------------------

        if Config.WeaponLootEnabled
            and #Config.WeaponLoot > 0 then

            local chance =
                math.random(
                    1,
                    100
                )

            if chance <=
                Config.WeaponGetChance then

                local index =
                    math.random(
                        1,
                        #Config.WeaponLoot
                    )

                local weapon =
                    Config.WeaponLoot[index]

                if weapon
                    and weapon.weapon then

                    local metadata = {
                        ammo =
                            weapon.ammo or 0
                    }

                    if oxInventory:CanCarryItem(
                        source,
                        weapon.weapon,
                        1,
                        metadata
                    ) then

                        oxInventory:AddItem(
                            source,
                            weapon.weapon,
                            1,
                            metadata
                        )
                    else
                        notifyPlayer(
                            source,
                            Config.Notifications.inventoryFull,
                            'error'
                        )
                    end
                end
            end
        end

        -- --------------------------------------------------------------------
        -- COOLDOWN
        -- --------------------------------------------------------------------

        cooldownUntil =
            GetGameTimer() +
            (
                Config.CooldownMinutes *
                60000
            )

        -- --------------------------------------------------------------------
        -- REMOVE CLIENT DROP
        -- --------------------------------------------------------------------

        TriggerClientEvent(
            'cb_airdrop:client:removeDrop',
            -1
        )

        notifyPlayer(
            source,
            Config.Notifications.lootSuccess,
            'success'
        )

        debugPrint(
            (
                'Player %s looted the airdrop.'
            ):format(source)
        )

        -- --------------------------------------------------------------------
        -- RETURN TO IDLE
        -- --------------------------------------------------------------------

        CreateThread(function()
            Wait(3000)

            dropCoords = nil

            if dropState == 'claimed' then
                setDropState('idle')
            end
        end)
    end
)


-- ============================================================================
-- PLAYER DISCONNECT
-- ============================================================================

AddEventHandler(
    'playerDropped',
    function()
        local source = source

        if lootClaimer == source then
            lootClaimer = nil

            if dropState == 'ready' then
                debugPrint(
                    (
                        'Airdrop loot claim released after player %s disconnected.'
                    ):format(source)
                )
            end
        end
    end
)


-- ============================================================================
-- RESOURCE STOP
-- ============================================================================

AddEventHandler(
    'onResourceStop',
    function(resourceName)
        if resourceName ~=
            GetCurrentResourceName() then

            return
        end

        removePoliceAlerts()
    end
)
