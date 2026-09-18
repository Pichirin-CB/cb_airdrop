# CB Airdrop

Apocalyptic survival airdrop system for FiveM.

CB Airdrop provides a configurable survival supply-drop system designed for zombie and apocalypse servers. Players can use a survival flare to request an incoming aircraft, which delivers a supply crate containing randomized survival loot and a chance of receiving a weapon.

## Features

* Apocalyptic survival-oriented air drops.
* Randomized drop zones.
* Aircraft delivery sequence.
* Survival flare item.
* Randomized supply loot.
* Optional weapon loot.
* Configurable weapon chance.
* Configurable police requirements.
* Police emergency alerts.
* Optional alerts for all players.
* Zone radius blip.
* Airdrop map blip.
* Police alert blip.
* ox_target crate interaction.
* ox_inventory item and loot integration.
* ox_lib notifications.
* ox_lib progress bar.
* ox_lib callbacks.
* Server-side loot validation.
* Server-side distance validation.
* Server-side cooldown validation.
* Server-side anti-duplicate loot protection.
* No Mythic Progressbar dependency.
* No ESX inventory dependency.
* No ESX client callbacks.
* No SQL item registration.
* Configurable loot tables.
* Configurable weapon tables.
* Configurable survival zones.
* Clean resource state management.

## Requirements

The resource requires:

* FiveM
* ESX Legacy
* ox_lib
* ox_inventory
* ox_target

OneSync is strongly recommended for networked entity synchronization.

## Resource Structure

```text
cb_airdrop/
├── fxmanifest.lua
├── config.lua
├── client.lua
├── server.lua
└── README.md
```

## Installation

### 1. Install the resource

Place the resource inside your server resources directory:

```text
resources/
└── [local]/
    └── cb_airdrop/
```

### 2. Add the resource to server.cfg

Start the dependencies before CB Airdrop:

```cfg
ensure ox_lib
ensure es_extended
ensure ox_target
ensure ox_inventory

ensure cb_airdrop
```

If your server already starts these resources through another category, do not start them twice.

### 3. Add the flare item

Open:

```text
ox_inventory/data/items.lua
```

Add:

```lua
['drop_flare'] = {
    label = 'Survival Flare',
    weight = 150,
    stack = true,
    close = true,
    consume = 1,

    description = 'A signal flare used to request an emergency survival airdrop.',

    server = {
        export = 'cb_airdrop.useFlare'
    }
},
```

Restart ox_inventory and CB Airdrop after adding the item.

## Important

CB Airdrop no longer uses the old ESX SQL item:

```text
drop_flareV2
```

The old SQL entry is not required.

The new item is:

```text
drop_flare
```

## How the Airdrop Works

1. A player obtains a Survival Flare.
2. The player enters the active airdrop zone.
3. The player uses the flare through ox_inventory.
4. The server validates the request.
5. The flare is consumed.
6. The airdrop becomes active.
7. Police/all-player alerts are optionally sent.
8. The aircraft arrives.
9. The aircraft releases the supply crate.
10. The crate descends with the parachute.
11. The crate lands.
12. Players can target the crate using ox_target.
13. The player searches the crate using the ox_lib progress bar.
14. The server validates the loot request.
15. Random survival supplies are awarded.
16. A weapon may be awarded depending on the configured chance.
17. The crate is consumed.
18. The cooldown begins.

## Configuration

The main configuration file is:

```text
config.lua
```

### Police

```lua
Config.CopsRequired = 0
Config.PoliceJobName = 'police'
Config.AlertCops = false
Config.AlertAllPlayers = false
```

Set `CopsRequired` to a number greater than zero if the airdrop should require active police/security personnel.

### Cooldown

```lua
Config.CooldownMinutes = 0
```

For example:

```lua
Config.CooldownMinutes = 30
```

This means the system will wait 30 minutes after an airdrop has been successfully looted before another flare can activate one.

### Plane Arrival

```lua
Config.PlaneArrivalSeconds = 10
```

Increase this value if you want the aircraft to take longer to arrive.

### Loot

Loot is configured through:

```lua
Config.Loot = {
    { item = 'water', count = 5 },
    { item = 'bread', count = 5 },
}
```

The item names must exist in ox_inventory.

The number of randomized selections is controlled by:

```lua
Config.LootItemsCount = 6
```

For example:

```lua
Config.LootItemsCount = 3
```

means the crate will select three random loot entries.

The same item can potentially be selected more than once because each selection is randomized independently.

## Weapon Loot

Weapon rewards can be enabled with:

```lua
Config.WeaponLootEnabled = true
```

The chance is controlled by:

```lua
Config.WeaponGetChance = 10
```

This represents a 10% chance.

Weapons are configured as ox_inventory weapon items:

```lua
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
    }
}
```

Ammo is stored using weapon metadata.

Make sure the weapon items exist and are configured correctly in your ox_inventory installation.

## Drop Zones

Zones are configured in:

```lua
Config.Zones
```

Example:

```lua
{
    coords = vector3(1611.04, 3225.52, 40.41),
    radius = 250.0,
    color = 1,
    name = 'Sandy Shores Airfield'
},
```

Each zone contains:

* `coords`
* `radius`
* `color`
* `name`

The server randomly selects one of the configured zones.

## Zone Rotation

The active zone changes according to:

```lua
Config.ZoneRotationSeconds = 180
```

The value is in seconds.

For example:

```lua
Config.ZoneRotationSeconds = 300
```

changes the zone every five minutes.

The system does not rotate the zone while an airdrop is actively being delivered or looted.

## ox_target

The supply crate is registered as an ox_target model interaction.

Players will see:

```text
Search supply crate
```

when looking at the active airdrop crate.

The old manual `E` interaction has been removed.

## ox_lib

CB Airdrop uses ox_lib for:

* Notifications
* Server callbacks
* Loot progress bar

No Mythic Progressbar resource is required.

## Security

The loot system is server validated.

The client cannot directly decide:

* Which items are awarded.
* How much loot is awarded.
* Whether the crate is available.
* Whether another player already claimed the crate.
* Whether the player is close enough.
* Whether the cooldown has expired.
* Whether the player can carry the item.
* Whether the airdrop can be requested.

The server validates the important actions before rewarding loot.

## Inventory Compatibility

CB Airdrop is designed for:

```text
ox_inventory
```

It does not use:

```lua
xPlayer.addInventoryItem()
xPlayer.removeInventoryItem()
xPlayer.addWeapon()
```

Loot is delivered using ox_inventory server exports.

## Old Resource Compatibility

The following old event names are no longer used:

```text
AirV2:flare
AirV2:isActive
AirV2:anycops
AirV2:atimti
AirV2:loot
AirV2:alertcops
AirV2:stopalertcops
AirV2:get_zone
AirV2:registerActivity
Dropas:TakeDrop
Dropas:registerTakeDrop
```

The old `mythic_progbar` dependency has also been removed.

## Custom Loot

For a zombie survival server, recommended loot categories include:

* Water
* Food
* Bandages
* Medical supplies
* Ammunition
* Scrap
* Cloth
* Electronics
* Tools
* Fuel-related items
* Rare survival equipment
* Weapons

Use the actual item names registered by your server's ox_inventory installation.

## Recommended Survival Balance

For a difficult apocalypse environment, keep weapon rewards relatively uncommon.

Example:

```lua
Config.WeaponLootEnabled = true
Config.WeaponGetChance = 10
```

The majority of airdrops should provide survival resources rather than guaranteed firearms.

## Credits

CB Airdrop

Author:

Pichirin_CB

CB Studios

## License

See the license terms distributed with the resource.

Do not redistribute, resell, leak, or repackage the resource without authorization.
