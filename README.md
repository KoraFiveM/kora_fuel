# kora_fuel

Native vehicle fuel consumption, petrol-station refuelling, and EV charging stations.

Fuel and charge share GTA's 0–100 native vehicle fuel level. This is deliberate:
the HUD, kora_garages, and vehicle streaming all see the same level, and a stored
vehicle already persists that level through the existing `player_vehicles.fuel`
column. Electric vehicles charge at dedicated EV charging stations (see below). Add addon EV spawn names to `Config.electricVehicles` (the single source of truth, also read by kora_hud through the `isElectricVehicle` export). `Config.electric.useNative` (default true) additionally asks the game via `GetIsVehicleElectric` (called with the model hash) on the client, once per model, for the HUD icon and pump wording; pricing stays on the list.

Client exports: `GetFuel(vehicle)`, `SetFuel(vehicle, level)`, and
`isElectricVehicle(vehicle)`.

## Install

Start `kora_fuel` after `kora_lib`, `kora_core`, and `kora_target`, and before `kora_hud`.
The HUD uses kora_fuel's EV classifier to render Charge rather than Fuel.

## LegacyFuel compatibility

`LegacyFuel`, `qb-fuel`, `ps-fuel` and `cdn-fuel` are provided with the same
`GetFuel(vehicle)` and `SetFuel(vehicle, level)` exports, which use the
same native vehicle fuel state. The legacy getter keeps fractional levels and
the setter returns nil, while kora_fuel's existing exports keep their own return
values. Invalid entities and non-finite legacy writes are ignored. The alias
covers these exports; it does not reproduce qb-fuel's UI or optional state-bag
synchronization configuration.

## Map blips

Every coordinate in `Config.stations` gets a map blip, configured by
`Config.blips`: `enabled` (default `true`), `sprite` (361), `colour` (1),
`scale` (0.6), `shortRange` (`true`), `label` ("Gas Station") and
`mergeRadius` (30.0 metres: stations closer than this share one blip, the first
listed; 0 draws one blip per entry) and `nearestOnly` (`false`, see below). Use
`perStation = { [index] = { enabled = false, label = "..." } }` (index into
`Config.stations`) to hide or restyle individual blips. Blips are removed when
the resource stops.

## EV charging stations

`Config.charging.stations` lists the charging stations. The 13 defaults are at real
petrol stations (Murrieta Heights, La Puerta, Little Seoul, Little Seoul South,
Elysian Island, Pacific Bluffs, Downtown Vinewood, Tataviam Mountains, Route 68
West/East, Senora Freeway, Grapeseed and Paleto Bay). Each one stands exactly where
GTA places that station's forecourt air pump (`prop_gas_airunit01`), at its heading,
so a charger is always on the station's own ground, clear of buildings and reachable
by car. The air pump is hidden while the charger is shown.

Station fields: `label`, `coords` (the ground point the charger stands on),
`heading`, and optionally `offset` (world-space metres added to `coords`), `radius`
(target radius around the charger, default `zoneRadius`) and `hideModel` (a world
prop at `coords` to hide while the charger is spawned).

`coords` and `offset` accept `vector3(x, y, z)`, `vec3(x, y, z)`, `{ x = , y = , z = }`
and `{ x, y, z }`; all are turned into a `vector3` (`shared/stations.lua`), including
saved overrides and the client snapshot, where vectors arrive as plain tables. Each
station is validated on its own: one with a bad field is skipped with a single
console warning such as
`[kora_fuel] Skipping EV charging station #3 "Paleto Bay": offset must be ...`, and
the other stations and the rest of the config still load.

### Charger props

Every station gets a charger prop (`Config.charging.prop`). It is a local,
non-networked entity created through `Kora.entities` when the player comes within
`spawnDistance` metres (a `Kora.zones` sphere) and deleted when they leave or the
resource stops. GTA V ships no EV charger model, so the default `model` is
`prop_parkingpay` (the free-standing pay-and-display machine); set it to any
streamed charger prop for a real charger, and use `headingOffset` if that model
faces another way.

The **Charge vehicle** option is a kora_target zone on the charger (centred
`targetHeight` metres up, radius `zoneRadius`): hold Alt and aim at the charger
while an electric vehicle that is not fully charged is parked beside you (or you
sit in it). The option never shows for petrol vehicles or a full battery. The
floating kora_target world icon is off by default (`worldIcon = false`), because
the prop marks the spot. List custom charger props in `Config.charging.propModels`
to offer the same option on them (default empty). Zones and targets only: nothing
polls, and the option check is cached for half a second while aiming.

Charging reuses the normal service flow: the same amount/payment menu, progress
bar and server-side payment as a petrol pump, but priced and timed by the charging
config. The server decides the price and duration from the vehicle level and the
station list, and only takes payment within `Config.charging.serviceRadius` (15 m)
of a station. A vehicle the server does not list in `Config.electricVehicles` is
billed at the petrol price even at a station, so the client cannot buy cheaper
energy by mislabelling it. This also covers models that are only recognised through
`Config.electric.useNative`: add those to the list so they get charging prices.

Payments are whole dollars (physical cash cannot take cents), so units x price
is rounded by `Config.priceRounding`: `'up'` (default, never below the advertised
unit price), `'nearest'` or `'down'` (a total under $1 is then free). When the
total is not exact the menu shows what it was rounded from, for example
"1 unit ($1.25 rounded up)".

Notifications about an electric vehicle or a charging station are titled
**Charging**, petrol ones **Fuel** (`locales/en.lua`).

### Petrol pumps and EVs

While charging stations are enabled, an EV used at a petrol pump is not offered a
charge. It gets `Config.charging.pumpMessage` plus the nearest station and its
distance, and the server refuses a pump purchase for it. With
`Config.charging.waypointToNearest` (default `true`) the GPS waypoint is also set
to that station and the message says so. Set
`Config.charging.allowAtPumps = true` to let pumps charge EVs as well (at
`Config.pricePerUnit.charge`). With `Config.charging.enabled = false`, or no
stations listed, pumps charge EVs exactly as before.

### Options (`Config.charging`)

| Option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Master switch for the charging network |
| `allowAtPumps` | `false` | Let petrol pumps charge EVs too |
| `pumpMessage` | "Electric vehicles cannot use petrol pumps. Use an EV charging station." | Shown to EVs at a pump |
| `waypointToNearest` | `true` | Also set the GPS waypoint to the nearest station when an EV uses a pump |
| `pricePerPercent` | `1.25` | Price of 1% charge at a station |
| `secondsPerPercent` | `0.25` | Progress time per 1% (`Config.minimumProgressMs` still applies) |
| `serviceRadius` | `15.0` | Server-side distance from a station for a paid charge |
| `zoneRadius` | `1.25` | Target radius around a charger without its own `radius` |
| `interactDistance` | `5.0` | Maximum aim distance to the charger |
| `prop.enabled` | `true` | Spawn charger props (false: target zones only) |
| `prop.model` | `prop_parkingpay` | Charger prop model |
| `prop.headingOffset` | `0.0` | Degrees added to every station heading |
| `prop.spawnDistance` | `75.0` | Distance at which a charger is spawned |
| `prop.snapToGround` | `true` | Settle the prop onto the ground after spawning |
| `prop.targetHeight` | `1.0` | Height of the target zone above `coords` |
| `propModels` | `{}` | Extra charger prop models (custom maps) |
| `stations` | 13 defaults | See above |
| `worldIcon` | `false` | Show kora_target's floating icon at each charger |
| `blips` | see below | Station map blips |

Station blips (`Config.charging.blips`, created through `Kora.blips`, so players can
hide them with `/blips`): `enabled` (`true`), `sprite` (354), `colour` (46), `scale`
(0.8), `shortRange` (`true`: shown on the minimap only when in range, always on the pause map; set `false` to show them on the minimap at any distance), `label`
("EV Charging Station"), `showStationName` (`true`: the legend reads "EV Charging
Station - Little Seoul"), `category` (`Fuel`, a fixed kora_lib pause-map
category) and `nearestOnly` (`false`). Blips are removed when the resource stops.
Stations and blips are also editable in the kora_lib config editor.

### Nearest station only

`Config.blips.nearestOnly` (gas stations) and `Config.charging.blips.nearestOnly`
(charging stations), both `false` by default, replace the full set of blips with a
single one for the station nearest the player. It is re-picked from kora_lib's
cached player coords, and only after the player has moved 50 m since the last pick,
so there is no polling thread and walking around a forecourt does no work.

## Tests

`test/run.sh` runs the shared, client, blips, chargers, stations and server smoke tests with plain Lua.
