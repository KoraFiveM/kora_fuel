---
title: "Configuration"
sidebar_position: 4
---


# Configuration

All options live in the global `Config` table (`config.lua`), loaded on both realms. When `Kora.config.adopt` exists, every field is also registered with Kora Lib’s live config/override system (`Kora.config.number/integer/object/list/enum/...`), so a server operator can override values without editing the file; the file’s own values are simply the defaults passed into that registration.

Namespace: `Config` · Source: `config.lua, shared/fuel.lua, shared/stations.lua`

## Core options

| Option | Type | Default | Meaning |
| --- | --- | --- | --- |
| Config.maxLevel | number | 100.0 | Full-tank/battery level on GTA’s native 0-100 scale. Keep at or below 100 so other resources (HUD, garages) agree on the stored state. |
| Config.serviceRadius | number (metres) | 45.0 | Maximum distance from a `Config.stations` entry the server allows a paid pump refuel/charge. |
| Config.vehicleSearchDistance | number (metres) | 6.0 | How far the client/server search for the vehicle being serviced from the interaction point. |
| Config.progressMsPerUnit | integer (ms) | 125 | Milliseconds added to the pump progress bar per missing fuel unit. |
| Config.minimumProgressMs | integer (ms) | 1500 | Floor on the progress bar duration even for a tiny top-up. |
| Config.serviceSessionGraceMs | integer (ms) | 15000 | Registered with Kora Lib’s config system as extra grace time for an authorized session; not read anywhere else in this resource’s source (see note below). |
| Config.serviceRateLimit | &#123; max, window &#125; | &#123; max = 5, window = 10000 &#125; | Declared and schema-registered but not read by any code in this resource — confirmed by searching the whole source tree for `serviceRateLimit` (only the two definitions in `config.lua` exist). Present for future use or compatibility; it currently has no effect. |
| Config.paymentAccounts | string[] | &#123; 'cash', 'bank' &#125; | kora_core accounts offered at the pay form, in display order. Must be accounts kora_core understands (`cash`, `bank`, `crypto`). |
| Config.pricePerUnit.fuel / .charge | number | 2.0 / 1.25 | Dollars per native fuel unit, for petrol and (non-charging-station) electric service respectively. |
| Config.priceRounding | 'up' \| 'nearest' \| 'down' | 'up' | Whole-dollar rounding of the exact units × price total. `down` can make a sub-$1 total free. |
| Config.consumeInterval | integer (ms) | 1000 | Tick interval for the driving-consumption loop. |
| Config.idleConsumptionMultiplier | number | 0.08 | Multiplier floor applied while the vehicle is idling (not moving). |
| Config.speedReference | number (m/s) | 45.0 | Speed at which the class’s authored consumption rate applies with no extra scaling (~162 km/h). |
| Config.maxSpeedConsumptionMultiplier | number | 2.0 | Cap on the speed-based consumption multiplier. |
| Config.consumePerSecond | map: GTA class id (or `default`) -> number | see source | Fuel/charge used per second at the reference speed, per vehicle class; `default` covers any class without an explicit entry. |
| Config.electricVehicles | string[] (model names) | see source | The single source of truth for which models are electric — drives pricing, pump wording and the `isElectricVehicle` export. |
| Config.electric.useNative | boolean | true | Also asks `GetIsVehicleElectric` per model (cosmetic only: HUD icon and pump wording, never pricing/validation). |
| Config.pumpModels | string[] (prop models) | see source | World props that offer the refuel/charge interaction (via kora_target). |
| Config.stations | vector3[] | the vanilla map’s petrol stations | Authorization boundary for pump sales — the server only takes payment within `serviceRadius` of one of these points. |
| Config.blips | object | enabled, sprite 361, colour 1, … | Map blips for `Config.stations`. `perStation[index]` overrides one entry; `mergeRadius` collapses nearby duplicates into one blip; `nearestOnly` shows a single, re-picked, nearest blip instead of all of them. |

## Config.charging (EV charging stations)

A separate, optional network of dedicated EV chargers, distinct from petrol pumps.

| Option | Type | Description |
| --- | --- | --- |
| `enabled` | boolean | Master switch. Off (or an empty `stations` list) removes the charging network entirely; EVs then charge at petrol pumps as before charging stations existed. |
| `allowAtPumps` | boolean | When true, petrol pumps also charge EVs (at `pricePerUnit.charge`) instead of refusing them. Only meaningful while `enabled` is true. |
| `pumpMessage / waypointToNearest` | string / boolean | Message shown (and optional GPS waypoint set) to an EV driver refused at a pump. |
| `pricePerPercent / secondsPerPercent` | number | Price and fill time per 1% of charge at a charging station (separate from the pump’s per-unit pricing). |
| `serviceRadius` | number (metres) | Authorization boundary for charging-station sales, mirroring `Config.serviceRadius` for pumps. |
| `zoneRadius / interactDistance` | number (metres) | Default target-zone radius around a charger (per-station `radius` overrides it when > 0) and the maximum aim distance. |
| `prop` | object | `enabled`, `model` (default `prop_parkingpay`), `headingOffset`, `spawnDistance`, `snapToGround`, `targetHeight` — controls the local charger prop spawned near each station. |
| `propModels` | string[] | Extra, already-placed prop models (custom map assets) that also offer the charge interaction within a station’s radius, in addition to the spawned prop. |
| `worldIcon` | boolean | Draws kora_target’s floating world icon at the charger. Off by default since the prop itself marks the spot. |
| `stations` | array of &#123; label, coords, heading, offset?, radius?, hideModel? &#125; | The charger list itself. Validated by `shared/stations.lua`: an entry with a bad field is dropped with a console warning naming the index/label/field; the rest still load. `coords`/`offset` accept `vector3`, `{x=,y=,z=}` or `{x,y,z}`. |
| `blips` | object | Same shape as `Config.blips` (sprite, colour, scale, label, `showStationName`, `category`, `nearestOnly`, …) but for charging stations; defaults to sprite 354 / colour 46 so they are visually distinct from petrol blips. |

## Unused field: Config.serviceRateLimit

Present in `config.lua` and registered with the Kora Lib config schema, but grepping the whole resource for `serviceRateLimit` finds no code that reads it — there is no actual rate limiter keyed on it. Purchase attempts are only throttled by the per-player `busy` flag and the progress-bar duration (see Events).

## Unclear: Config.serviceSessionGraceMs

Also schema-registered, with a description implying it extends how long an authorized session stays valid, but the source in `server/main.lua` does not reference `serviceSessionGraceMs` either — the revalidate-after-progress-bar logic uses no grace window. Marked unclear rather than guessed at.

## Limits and related APIs

Every numeric/list option above takes effect after a restart of `kora_fuel` unless Kora Lib’s live-override system (`Kora.config.onChange`) is wired for it — only `charging.stations` registers an `onChange` listener in this source, re-normalizing a changed list on the fly.

## Defaults and details from the code

The sections below were added from `config.lua` and list the defaults and ranges that the tables above leave as "see source".

### Consumption

See [Fuel consumption](../consumption.md) for the formula.

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `Config.consumeInterval` | integer (min 100) | `1000` | Drain tick interval (ms). Drain is time-scaled, so changing this does not change the overall rate |
| `Config.idleConsumptionMultiplier` | number (0-1) | `0.08` | Minimum speed multiplier (idle drain) |
| `Config.speedReference` | number | `45.0` | Speed (m/s) at which the class rate applies unscaled |
| `Config.maxSpeedConsumptionMultiplier` | number (min 1) | `2.0` | Cap on the speed multiplier |
| `Config.consumePerSecond` | map class ID to number | see [Fuel consumption](../consumption.md) | Per-class drain per second at reference speed. A `default` key is required |

### Vehicles, pumps and stations

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

### Map blips (`Config.blips`)

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

### EV charging (`Config.charging`)

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
| `stations` | list | 13 stations | See [Station fields](../refuelling-and-charging.md) |

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

### Locales

`locales/en.lua` contains the notification titles (`title.fuel`, `title.charging`) and the client error/info messages, which are read through `Kora.lang`. Server result messages (for example "Insufficient funds.", "Vehicle refuelled for $40.") and the menu labels are hard-coded in English in `server/main.lua` and `client/main.lua`.
