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
listed; 0 draws one blip per entry). Use
`perStation = { [index] = { enabled = false, label = "..." } }` (index into
`Config.stations`) to hide or restyle individual blips. Blips are removed when
the resource stops.

## EV charging stations

`Config.charging.stations` lists the charging stations (`label`, `coords`, optional
`radius`). The defaults are ten car parks and street spots around the map: Legion
Square, Alta Street, Sandy Shores, Rockford Plaza, Vespucci Canals, Del Perro Pier,
the airport, Chumash, Grapeseed and Paleto Bay. GTA V has no vanilla EV charger
prop, so each station is a kora_target sphere zone (with a world icon while you are
nearby, `Config.charging.worldIcon`) and a map blip: hold Alt and aim at a
spot within the station's `radius` (default `zoneRadius`, 4.0 m) while an electric
vehicle is parked beside you (or you are in it) to get **Charge vehicle**. The
option never shows for petrol vehicles. List custom charger props in
`Config.charging.propModels` to offer the same option on them (default empty).
Zones and targets only: nothing polls, and the option check is cached for half a
second while aiming.

Charging reuses the normal service flow: the same amount/payment menu, progress
bar and server-side payment as a petrol pump, but priced and timed by the charging
config. The server decides the price and duration from the vehicle level and the
station list, and only takes payment within `Config.charging.serviceRadius` (15 m)
of a station. A vehicle the server does not list in `Config.electricVehicles` is
billed at the petrol price even at a station, so the client cannot buy cheaper
energy by mislabelling it. This also covers models that are only recognised through
`Config.electric.useNative`: add those to the list so they get charging prices.

### Petrol pumps and EVs

While charging stations are enabled, an EV used at a petrol pump is not offered a
charge. It gets `Config.charging.pumpMessage` plus the nearest station and its
distance, and the server refuses a pump purchase for it. Set
`Config.charging.allowAtPumps = true` to let pumps charge EVs as well (at
`Config.pricePerUnit.charge`). With `Config.charging.enabled = false`, or no
stations listed, pumps charge EVs exactly as before.

### Options (`Config.charging`)

| Option | Default | Meaning |
| --- | --- | --- |
| `enabled` | `true` | Master switch for the charging network |
| `allowAtPumps` | `false` | Let petrol pumps charge EVs too |
| `pumpMessage` | "Electric vehicles cannot use petrol pumps. Use an EV charging station." | Shown to EVs at a pump |
| `pricePerPercent` | `1.25` | Price of 1% charge at a station |
| `secondsPerPercent` | `0.25` | Progress time per 1% (`Config.minimumProgressMs` still applies) |
| `serviceRadius` | `15.0` | Server-side distance from a station for a paid charge |
| `zoneRadius` | `4.0` | Target zone radius for stations without their own `radius` |
| `interactDistance` | `5.0` | Maximum aim distance to the zone |
| `propModels` | `{}` | Optional charger prop models |
| `stations` | ten defaults | `{ label, coords, radius }` entries |
| `worldIcon` | `true` | Show kora_target's world icon at each station when nearby |
| `blips` | see below | Station map blips |

Station blips (`Config.charging.blips`, created through `Kora.blips`, so players can
hide them with `/blips`): `enabled` (`true`), `sprite` (354), `colour` (46), `scale`
(0.8), `shortRange` (`true`: shown on the minimap only when in range, always on the pause map; set `false` to show them on the minimap at any distance), `label`
("EV Charging Station"), `showStationName` (`true`: the legend reads "EV Charging
Station - Legion Square Parking") and `category` (`Fuel`, a fixed kora_lib pause-map
category). Blips are created for every station and removed when the resource stops.
Stations and blips are also editable in the kora_lib config editor.

The Legion Square Parking station is centred on the middle bay of the kora_garages
Legion Square bay row (radius 8), so an EV parked in any of the bays there can charge.
The petrol-pump message names the station nearest the player at that moment, so it
always matches a listed station and its blip.

## Tests

`test/run.sh` runs the shared, client, blips and server smoke tests with plain Lua.
