---
title: kora_fuel
sidebar_position: 1
---

# kora_fuel

kora_fuel handles vehicle fuel consumption, refuelling at petrol pumps and charging at EV charging stations. Petrol and battery charge use the same GTA native vehicle fuel level (0 to 100). The HUD, [kora_garages](https://github.com/KoraFiveM/kora_garages) and vehicle streaming all read that same value, and stored vehicles keep it in the existing `player_vehicles.fuel` column. kora_fuel adds no tables of its own. Players pay from a kora_core money account. The server validates the price, distance and vehicle before it takes payment.

## Features

- **Fuel consumption**: while the local player drives a vehicle with the engine running, the fuel level drops at a per-vehicle-class rate scaled by speed. At 0 the engine switches off. See [Fuel consumption](./consumption.md).
- **Petrol pump refuelling**: target a pump model (`Config.pumpModels`) and choose **Service nearby vehicle**. A menu shows the current level, the unit price and the total. The player picks an amount and a payment account, a progress bar runs, and then the server takes payment and fills the vehicle. See [Refuelling and charging](./refuelling-and-charging.md).
- **EV charging stations**: 13 default stations, each with a locally spawned charger prop and a **Charge vehicle** target zone. Each station has its own price and charge time. See [Refuelling and charging](./refuelling-and-charging.md).
- **EV routing at petrol pumps**: if charging stations are enabled, an electric vehicle at a petrol pump is refused. The player is told which charging station is nearest and how far away it is, and can optionally get a GPS waypoint to it.
- **Electric vehicle detection**: `Config.electricVehicles` is the authoritative list. On the client, the game native `GetIsVehicleElectric` can also be checked (`Config.electric.useNative`). The `isElectricVehicle` export shares this classification with kora_hud.
- **Whole-dollar pricing**: totals are rounded up, to the nearest dollar, or down (`Config.priceRounding`). If a total was rounded, the menu shows the exact amount it came from.
- **Map blips**: gas station blips (stations that are close together are merged) and EV charging station blips. Either set can show only the station nearest the player. See [Map blips](./blips.md).
- **Legacy compatibility**: provides `LegacyFuel`, `qb-fuel`, `ps-fuel` and `cdn-fuel` `GetFuel`/`SetFuel` exports. See [Compatibility](./compatibility.md).
- **Config editor support**: all main options are registered with the kora_lib config schema, so they can be edited in the kora_lib config editor.

## Requirements

From `fxmanifest.lua`:

- [kora_lib](https://github.com/KoraFiveM/kora_lib) (`@kora_lib/init.lua`; uses `Kora.config`, `Kora.callback`, `Kora.nui`, `Kora.progressbar`, `Kora.zones`, `Kora.entities`, `Kora.blips`, `Kora.interact`, `Kora.cache`, `Kora.notify`, `Kora.world`, `Kora.compat`)
- [kora_core](https://github.com/KoraFiveM/kora_core) (server exports `getMoney` and `removeMoney`)
- [kora_target](https://github.com/KoraFiveM/kora_target) (`addSphereZone` for the charger targets)

Optional consumers:

- [kora_hud](https://github.com/KoraFiveM/kora_hud) reads the `isElectricVehicle` export to show Charge instead of Fuel.
- [kora_garages](https://github.com/KoraFiveM/kora_garages) saves the native fuel level in `player_vehicles.fuel`.

## Installation

1. Put `kora_fuel` in your resources folder.
2. Start it after its dependencies and before kora_hud:

```cfg
ensure kora_lib
ensure kora_core
ensure kora_target
ensure kora_fuel
ensure kora_hud
```

3. There is no SQL to import and there are no inventory items to add.
4. Optionally adjust `config.lua` (see [Configuration](./configuration.md)). For example, you can add addon EV spawn names to `Config.electricVehicles`.

## Pages

- [Refuelling and charging](./refuelling-and-charging.md): player flow, EV charging stations, charger props, pricing and server checks
- [Fuel consumption](./consumption.md): how fuel drains while driving
- [Map blips](./blips.md): gas station and charging station blips
- [Configuration](./configuration.md): every option in `config.lua`
- [Exports](./exports.md): client exports
- [Events](./events.md): network events and callbacks (internal)
- [Compatibility](./compatibility.md): LegacyFuel / qb-fuel / ps-fuel / cdn-fuel aliases
- [Troubleshooting](./troubleshooting.md)

## Tests

`test/run.sh` runs plain-Lua smoke tests (shared, client, blips, chargers, stations, server). `tests/*.feature` contains kora_qa Gherkin scenarios, which the manifest registers through `qa_feature`.
