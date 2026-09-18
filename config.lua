Config = {}

-- ============================================================================
-- CB AIRDROP
-- APOCALYPTIC SURVIVAL CONFIGURATION
-- ============================================================================

-- ============================================================================
-- RESOURCE
-- ============================================================================

Config.Debug = false

-- ============================================================================
-- POLICE / SECURITY
-- ============================================================================

-- Number of police players required before a flare can call an airdrop.
-- Set to 0 to disable the requirement.
Config.CopsRequired = 0

-- ESX job name used for police checks and alerts.
Config.PoliceJobName = 'police'

-- Send the airdrop location to police.
Config.AlertCops = false

-- Send the airdrop location to every player.
Config.AlertAllPlayers = false

-- How long the police blip remains visible.
Config.PoliceBlipDurationSeconds = 120

-- ============================================================================
-- AIRDROP
-- ============================================================================

-- Cooldown after an airdrop has been looted.
Config.CooldownMinutes = 0

-- Time before the aircraft reaches the drop zone after the flare is fired.
Config.PlaneArrivalSeconds = 10

-- Maximum time the aircraft has to reach the drop point.
Config.PlaneTimeoutSeconds = 60

-- Distance from the zone center required to use a flare.
Config.FlareZoneDistance = 250.0

-- ============================================================================
-- DROP CRATE
-- ============================================================================

-- Distance above the ground at which the crate is considered landed.
Config.CrateGroundDistance = 0.05

-- Maximum distance from the crate allowed when claiming it.
Config.LootDistance = 5.0

-- Time required to loot the crate.
Config.LootDuration = 10000

-- ============================================================================
-- CRATE PHYSICS / DESCENT
-- ============================================================================

-- How long the crate remains in free fall after being released
-- from the aircraft before the parachute opens.
--
-- This makes the drop look like an actual cargo release instead
-- of the parachute appearing immediately.
Config.CrateFreeFallSeconds = 1.5

-- Controlled vertical descent speed while the parachute is deployed.
--
-- Lower value = slower descent.
-- Higher value = faster descent.
--
-- Recommended RP range:
-- 4.5 - 7.0
Config.CrateDescentSpeed = 5.5

-- Maximum amount of time allowed for the crate to reach the ground.
--
-- This prevents a broken terrain/ground detection from leaving
-- the airdrop permanently suspended.
Config.CrateLandingTimeoutSeconds = 90

-- ============================================================================
-- AIRCRAFT
-- ============================================================================

Config.AircraftModel = 'cuban800'
Config.PilotModel = 's_m_m_pilot_02'

-- Distance from the drop point where the aircraft initially spawns.
Config.PlaneSpawnDistance = 400.0

-- Aircraft speed.
Config.PlaneSpeed = 60.0

-- Height above the active zone used for the aircraft flight path.
Config.PlaneAltitude = 500.0

-- ============================================================================
-- DROP OBJECTS
-- ============================================================================

-- Physical supply crate.
Config.CrateModel = 'prop_box_wood02a_pu'

-- Cargo parachute.
Config.ParachuteModel = 'p_cargo_chute_s'

-- Object used by ox_target for searching the crate.
Config.PickupModel = 'ex_prop_adv_case_sm'

-- ============================================================================
-- LOOT
-- ============================================================================

-- Number of random loot entries selected from Config.Loot.
Config.LootItemsCount = 6

-- Random survival loot.
--
-- IMPORTANT:
-- These item names must exist in your ox_inventory.
--
-- Adjust these to the actual items installed on your zombie server.
Config.Loot = {
    {
        item = 'water',
        count = 5
    },

    {
        item = 'bread',
        count = 5
    },

    -- Examples:
    -- {
    --     item = 'bandage',
    --     count = 3
    -- },

    -- {
    --     item = 'medikit',
    --     count = 1
    -- },

    -- {
    --     item = 'ammo-9',
    --     count = 20
    -- },

    -- {
    --     item = 'ammo-45',
    --     count = 20
    -- },

    -- {
    --     item = 'ammo-rifle',
    --     count = 30
    -- },

    -- {
    --     item = 'scrapmetal',
    --     count = 5
    -- },

    -- {
    --     item = 'cloth',
    --     count = 5
    -- },

    -- {
    --     item = 'electronics',
    --     count = 2
    -- },
}

-- ============================================================================
-- WEAPON LOOT
-- ============================================================================

Config.WeaponLootEnabled = true

-- Chance of receiving a weapon.
--
-- 10 = 10%
-- 25 = 25%
-- 50 = 50%
Config.WeaponGetChance = 10

-- Weapon loot.
--
-- Ammo is stored in the weapon metadata by the server.
Config.WeaponLoot = {
    {
        weapon = 'WEAPON_PISTOL',
        ammo = 12
    },

    {
        weapon = 'WEAPON_REVOLVER',
        ammo = 12
    },

    {
        weapon = 'WEAPON_MICROSMG',
        ammo = 30
    },

    -- Add more weapons here.
}

-- ============================================================================
-- FLARE ITEM
-- ============================================================================

Config.FlareItem = 'drop_flare'

-- ============================================================================
-- NOTIFICATIONS
-- ============================================================================

Config.Notifications = {
    planeIncoming =
        'Emergency flare detected. A supply aircraft is inbound.',

    planeArriving =
        'The aircraft is approaching the drop zone.',

    planeCrashed =
        'The supply aircraft failed to complete the drop.',

    flareOutsideZone =
        'You must be inside the active drop zone to signal the aircraft.',

    cooldown =
        'The airdrop system is currently unavailable.',

    alreadyActive =
        'An airdrop is already active.',

    notEnoughCops =
        'There is not enough security personnel available.',

    dropUnavailable =
        'No active airdrop zone is currently available.',

    crateReady =
        'The supply crate has landed. Secure the area and search it.',

    crateAlreadyLooted =
        'The supply crate has already been looted.',

    crateEmpty =
        'The supply crate is empty.',

    inventoryFull =
        'You do not have enough space to carry the recovered supplies.',

    lootSuccess =
        'You recovered supplies from the airdrop.',

    lootCancelled =
        'You stopped searching the supply crate.',

    policeAlert =
        'Emergency alert: an airdrop has been detected.',
}

-- ============================================================================
-- BLIPS
-- ============================================================================

Config.Blips = {
    zone = {
        enabled = true,
        sprite = 9,
        colour = 1,
        alpha = 85
    },

    drop = {
        enabled = true,
        sprite = 478,
        colour = 5,
        scale = 0.9,
        name = 'SURVIVAL SUPPLY DROP',
        route = true
    },

    police = {
        sprite = 161,
        colour = 1,
        scale = 1.2,
        name = 'AIRDROP ALERT'
    }
}

-- ============================================================================
-- ZONE ROTATION
-- ============================================================================

-- Time before the active survival zone changes.
Config.ZoneRotationSeconds = 180

-- ============================================================================
-- AIRDROP ZONES
-- ============================================================================

Config.Zones = {
    {
        coords = vector3(
            1611.04,
            3225.52,
            40.41
        ),
        radius = 250.0,
        color = 1,
        name = 'Sandy Shores Airfield'
    },

    {
        coords = vector3(
            -1833.11,
            -1214.88,
            13.02
        ),
        radius = 200.0,
        color = 1,
        name = 'Los Santos Coast'
    },

    {
        coords = vector3(
            73.29,
            6536.86,
            31.68
        ),
        radius = 150.0,
        color = 1,
        name = 'Paleto Forest'
    },

    {
        coords = vector3(
            2395.22,
            2323.22,
            71.68
        ),
        radius = 150.0,
        color = 1,
        name = 'Harmony Wasteland'
    },

    {
        coords = vector3(
            -1084.37,
            4912.69,
            214.4
        ),
        radius = 150.0,
        color = 1,
        name = 'Mountains'
    },

    -- Add more survival zones here.
}