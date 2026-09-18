Config = {}

Config.Debug = false

Config.CopsRequired = 0
Config.PoliceJobName = 'police'
Config.AlertCops = false
Config.AlertAllPlayers = true
Config.PoliceBlipDurationSeconds = 120

Config.CooldownMinutes = 0
Config.PlaneArrivalSeconds = 10
Config.PlaneTimeoutSeconds = 60
Config.FlareZoneDistance = 250.0

Config.CrateGroundDistance = 0.05
Config.LootDistance = 5.0
Config.LootDuration = 10000
Config.CrateFreeFallSeconds = 1.5
Config.CrateDescentSpeed = 5.5
Config.CrateLandingTimeoutSeconds = 90

Config.AircraftModel = 'cuban800'
Config.PilotModel = 's_m_m_pilot_02'
Config.PlaneSpawnDistance = 400.0
Config.PlaneSpeed = 60.0
Config.PlaneAltitude = 500.0

Config.CrateModel = 'prop_box_wood02a_pu'
Config.ParachuteModel = 'p_cargo_chute_s'
Config.PickupModel = 'prop_box_wood02a_pu'

Config.LootItemsCount = 6
Config.Loot = {
    { item = 'water', count = 5 },
    { item = 'bread', count = 5 },
}

Config.WeaponLootEnabled = true
Config.WeaponGetChance = 10
Config.WeaponLoot = {
    { weapon = 'WEAPON_PISTOL', ammo = 12 },
    { weapon = 'WEAPON_REVOLVER', ammo = 12 },
    { weapon = 'WEAPON_MICROSMG', ammo = 30 },
}

Config.FlareItem = 'drop_flare'

Config.Notifications = {
    planeIncoming = 'Emergency flare detected. A supply aircraft is inbound.',
    planeArriving = 'The aircraft is approaching the drop zone.',
    planeCrashed = 'The supply aircraft failed to complete the drop.',
    flareOutsideZone = 'You must be inside the active drop zone to signal the aircraft.',
    cooldown = 'The airdrop system is currently unavailable.',
    alreadyActive = 'An airdrop is already active.',
    notEnoughCops = 'There is not enough security personnel available.',
    dropUnavailable = 'No active airdrop zone is currently available.',
    crateReady = 'The supply crate has landed. Secure the area and search it.',
    crateAlreadyLooted = 'The supply crate has already been looted.',
    crateEmpty = 'The supply crate is empty.',
    inventoryFull = 'You do not have enough space to carry the recovered supplies.',
    lootSuccess = 'You recovered supplies from the airdrop.',
    lootCancelled = 'You stopped searching the supply crate.',
    policeAlert = 'Emergency alert: an airdrop has been detected.',
}

Config.Blips = {
    zone = { enabled = true, sprite = 9, colour = 1, alpha = 85 },
    drop = { enabled = true, sprite = 478, colour = 5, scale = 0.9, name = 'SURVIVAL SUPPLY DROP', route = true },
    police = { sprite = 161, colour = 1, scale = 1.2, name = 'AIRDROP ALERT' }
}

Config.ZoneRotationSeconds = 180

Config.Zones = {
    { coords = vector3(1611.04, 3225.52, 40.41), radius = 250.0, color = 1, name = 'Sandy Shores Airfield' },
    { coords = vector3(-1833.11, -1214.88, 13.02), radius = 200.0, color = 1, name = 'Los Santos Coast' },
    { coords = vector3(73.29, 6536.86, 31.68), radius = 150.0, color = 1, name = 'Paleto Forest' },
    { coords = vector3(2395.22, 2323.22, 71.68), radius = 150.0, color = 1, name = 'Harmony Wasteland' },
    { coords = vector3(-1084.37, 4912.69, 214.4), radius = 150.0, color = 1, name = 'Mountains' },
}
