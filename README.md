# kora_fuel

Native vehicle fuel consumption, petrol-station refuelling, and EV charging.

Fuel and charge share GTA's 0–100 native vehicle fuel level. This is deliberate:
the HUD, kora_garages, and vehicle streaming all see the same level, and a stored
vehicle already persists that level through the existing `player_vehicles.fuel`
column. At the default vanilla station pumps, EVs offer a charging flow instead
of refuelling. Add addon EV spawn names to `Config.electricVehicles`.

Client exports: `GetFuel(vehicle)`, `SetFuel(vehicle, level)`, and
`isElectricVehicle(vehicle)`.

## Install

Start `kora_fuel` after `kora_lib`, `kora_core`, and `kora_target`, and before `kora_hud`.
The HUD uses kora_fuel's EV classifier to render Charge rather than Fuel.

## LegacyFuel compatibility

`LegacyFuel:GetFuel(vehicle)` and `LegacyFuel:SetFuel(vehicle, level)` use the
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
