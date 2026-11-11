---
title: Configuration
sidebar_position: 5
---

# Configuration

All options are in `config.lua`, which is shared by client and server. Most options are registered with the kora_lib config schema (`Kora.config.adopt`), so they can also be changed in the kora_lib config editor. Saved overrides are applied on top of the file values. Exceptions are noted in the tables below.

## General service

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.maxLevel` | number (1-100) | `100.0` | Full tank/battery level on GTA's native 0-100 fuel scale. Keep it at or below 100 |
| `Config.serviceRadius` | number | `45.0` | Server and client range in metres from a `Config.stations` entry to the **player** within which pump service is allowed |
| `Config.vehicleSearchDistance` | number | `6.0` | Radius around the player used to find the vehicle to service. The server allows this value + 1 m |
| `Config.progressMsPerUnit` | integer | `125` | Progress time per unit at pumps (ms) |
| `Config.minimumProgressMs` | integer | `1500` | Minimum progress duration (ms) for every service |
| `Config.serviceSessionGraceMs` | integer | `15000` | Registered in the schema but **not used by the current code** |
| `Config.serviceRateLimit` | `{ max, window }` | `{ max = 5, window = 10000 }` | Registered in the schema but **not used by the current code** |
| `Config.paymentAccounts` | list of `cash`/`bank`/`crypto` | `{ 'cash', 'bank' }` | Accounts offered in the menu, in order. The first is the default. The server rejects other accounts |
| `Config.pricePerUnit.fuel` | number | `2.0` | Petrol price per unit |
| `Config.pricePerUnit.charge` | number | `1.25` | Price per unit for listed EVs charged at a petrol pump |
| `Config.priceRounding` | `up`/`nearest`/`down` | `'up'` | How the total is rounded to whole dollars. With `down`, a total under $1 is free |

## Consumption

See [Fuel consumption](./consumption.md) for the formula.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.consumeInterval` | integer (min 100) | `1000` | Drain tick interval (ms). Drain is time-scaled, so changing this does not change the overall rate |
| `Config.idleConsumptionMultiplier` | number (0-1) | `0.08` | Minimum speed multiplier (idle drain) |
| `Config.speedReference` | number | `45.0` | Speed (m/s) at which the class rate applies unscaled |
| `Config.maxSpeedConsumptionMultiplier` | number (min 1) | `2.0` | Cap on the speed multiplier |
| `Config.consumePerSecond` | map class ID to number | see [Fuel consumption](./consumption.md) | Per-class drain per second at reference speed. A `default` key is required |

## Vehicles, pumps and stations

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.electricVehicles` | list of spawn names | 32 vanilla EVs | Authoritative EV list for server pricing/validation, the client price type, the HUD (`isElectricVehicle`) and menu wording. Add addon EVs here |
| `Config.electric.useNative` | boolean | `true` | Client also asks `GetIsVehicleElectric(model)`, once per model. Affects only wording, charger access and the HUD, not pricing. Ignored on builds without the native |
| `Config.pumpModels` | list of model names | 7 vanilla pump models | Props that get the **Service nearby vehicle** interaction |
| `Config.stations` | list of `vector3` | 23 vanilla forecourts | Pump service points (authorization boundary) and gas station blip positions |

Default electric vehicles: `airtug`, `buffalo5`, `caddy`, `caddy2`, `caddy3`, `coureur`, `cyclone`, `cyclone2`, `dilettante`, `dilettante2`, `envisage`, `estride`, `imorgon`, `inductor`, `inductor2`, `iwagen`, `khamelion`, `neon`, `omnisegt`, `pipistrello`, `powersurge`, `raiden`, `rcbandito`, `surge`, `suzume`, `tezeract`, `virtue`, `vivanite`, `vivanite2`, `voltic`, `voltic2`, `xtreme`.

Default pump models: `prop_gas_pump_1a`, `prop_gas_pump_1b`, `prop_gas_pump_1c`, `prop_gas_pump_1d`, `prop_vintage_pump`, `prop_gas_pump_old2`, `prop_gas_pump_old3`.

```lua
Config.electricVehicles = {
    'voltic', 'neon', 'tezeract',
    'my_addon_ev', -- addon spawn name
}
```

## Map blips (`Config.blips`)

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Show gas station blips |
| `sprite` | integer | `361` | GTA blip sprite (petrol pump) |
| `colour` | integer | `1` | GTA blip colour (red) |
| `scale` | number | `0.6` | Blip scale |
| `shortRange` | boolean | `true` | Show on the minimap only when nearby |
| `label` | string | `'Gas Station'` | Legend text |
| `mergeRadius` | number | `30.0` | Stations closer than this (metres) share one blip. `0` disables merging |
| `nearestOnly` | boolean | `false` | Show only the nearest gas station |
| `perStation` | table | `{}` | Per-index overrides (`enabled`, `sprite`, `colour`, `scale`, `shortRange`, `label`, `category`). Not in the config-editor schema |

## EV charging (`Config.charging`)

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Master switch for the charging network |
| `allowAtPumps` | boolean | `false` | Let petrol pumps charge EVs (at `Config.pricePerUnit.charge`) |
| `pumpMessage` | string | `'Electric vehicles cannot use petrol pumps. Use an EV charging station.'` | Shown to an EV at a pump. The nearest station and its distance are appended |
| `waypointToNearest` | boolean | `true` | Also set the GPS waypoint to the nearest station |
| `pricePerPercent` | number | `1.25` | Price per 1% at a charging station |
| `secondsPerPercent` | number | `0.25` | Progress seconds per 1% (`Config.minimumProgressMs` still applies) |
| `serviceRadius` | number | `15.0` | Range in metres from a charger to the player for a paid charge |
| `zoneRadius` | number | `1.25` | Target radius for stations without their own `radius` |
| `interactDistance` | number | `5.0` | Maximum aim distance to the charger target (also used for `propModels`) |
| `prop.enabled` | boolean | `true` | Spawn charger props. If `false`, stations have target zones only |
| `prop.model` | string | `'prop_parkingpay'` | Charger prop model |
| `prop.headingOffset` | number | `0.0` | Degrees added to every station heading |
| `prop.spawnDistance` | number (min 10) | `75.0` | Spawn/despawn distance in metres |
| `prop.snapToGround` | boolean | `true` | Place the prop on the ground after spawning |
| `prop.targetHeight` | number | `1.0` | Height of the target zone above the charger position |
| `propModels` | list of model names | `{}` | Extra (custom map) charger props that offer **Charge vehicle** |
| `worldIcon` | boolean | `false` | Draw kora_target's floating icon at each charger |
| `stations` | list | 13 stations | See [Station fields](./refuelling-and-charging.md) |

### Charging blips (`Config.charging.blips`)

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `enabled` | boolean | `true` | Show charging station blips |
| `sprite` | integer | `354` | GTA blip sprite |
| `colour` | integer | `46` | GTA blip colour |
| `scale` | number | `0.8` | Blip scale |
| `shortRange` | boolean | `true` | Show on the minimap only when nearby (always shown on the pause map) |
| `label` | string | `'EV Charging Station'` | Legend text |
| `showStationName` | boolean | `true` | Append the station name to the label |
| `category` | string | `'Fuel'` | kora_lib pause-map blip category |
| `nearestOnly` | boolean | `false` | Show only the nearest charging station |

## Locales

`locales/en.lua` contains the notification titles (`title.fuel`, `title.charging`) and the client error/info messages, which are read through `Kora.lang`. Server result messages (for example "Insufficient funds.", "Vehicle refuelled for $40.") and the menu labels are hard-coded in English in `server/main.lua` and `client/main.lua`.
