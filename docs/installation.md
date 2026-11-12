---
title: "Installation"
sidebar_position: 2
---


# Installation

Kora Fuel drains and refills GTA’s native 0-100 vehicle fuel level, sells refuels and EV charges at server-validated locations, and spawns EV charger props with their own target zones. It has no database table and no inventory item: the fuel level lives entirely on the vehicle entity.

## Install Kora Fuel

1. **Add the folder** — Place `kora_fuel` in your resources directory (on the Kora recipe it is `resources/[kora]/kora_fuel`). Keep the folder name: other resources call `exports.kora_fuel`.

2. **Check the dependencies** — The manifest declares `kora_lib`, `kora_core` and `kora_target`. `kora_core` is used for `getMoney`/`removeMoney` on the server; `kora_target` is used by the petrol pump interaction (`Kora.interact.addModel`, which goes through kora_target) and by the charging-station sphere zones (`exports.kora_target:addSphereZone`).

3. **Start it after its dependencies** — Start it after Kora Lib, Kora Core and Kora Target.

   ```bash title="server.cfg"
   ensure kora_lib
   ensure kora_core
   ensure kora_target
   ensure kora_fuel
   ```

4. **Check the manifest** — Shared scripts load `shared/stations.lua` (validates `Config.charging.stations`) before `config.lua`, then `shared/fuel.lua` (the `Fuel.*` helpers used by both realms).

   ```lua title="fxmanifest.lua" {20}
   fx_version 'cerulean'
   game 'gta5'
   lua54 'yes'

   name 'kora_fuel'
   provide 'LegacyFuel'
   provide 'qb-fuel'
   provide 'ps-fuel'
   provide 'cdn-fuel'
   version '0.2.0'

   dependency 'kora_lib'
   dependency 'kora_core'
   dependency 'kora_target'

   shared_script '@kora_lib/init.lua'
   shared_scripts {
       'shared/stations.lua',
       'config.lua',
       'shared/fuel.lua',
   }

   client_scripts {
       'client/main.lua',
       'client/blips.lua',
       'client/chargers.lua',
   }

   files { 'locales/*.lua' }
   server_script 'server/main.lua'
   ```

5. **Legacy export names keep working** — The manifest `provide`s `LegacyFuel`, `qb-fuel`, `ps-fuel` and `cdn-fuel`. Resources calling `exports.LegacyFuel:GetFuel(vehicle)` / `SetFuel(vehicle, level)` (or the `qb-fuel`/`ps-fuel`/`cdn-fuel` equivalents) keep working unchanged: Kora Fuel registers those export names itself through `Kora.compat.provideExport` and answers with the native fuel level.

6. **Edit the config** — Edit `config.lua` for pricing, consumption rates, electric vehicle models and station coordinates, and `shared/stations.lua`-validated `Config.charging.stations` for EV chargers. No SQL import or database setup is needed.

## Start order and startup behavior

- There is no readiness gate: config is normalized at load time (`Fuel.normalizeChargingStations` cleans `Config.charging.stations` once in `config.lua`, and again through a `Kora.config.onChange` listener if `Kora.config.onChange` exists, so a live-reloaded override is re-validated).
- A charging station with a bad `coords`, missing `label`, or invalid `offset`/`radius`/`hideModel` is dropped with a console warning (`[kora_fuel] Skipping EV charging station #<n> "<label>": <field> <reason>.`); the rest still load.
- Petrol pump interaction is registered once at client load via `Kora.interact.addModel(Config.pumpModels, ...)`. Charging-station target zones and charger props are created once at client load by `registerChargingStations()` (client/main.lua) and `start()` (client/chargers.lua); neither re-runs automatically if `Config.charging.stations` changes at runtime.
- Map blips (client/blips.lua) do re-run: they are created once at client load, and the coordinate watcher that keeps a `nearestOnly` blip re-picked is registered again on `onClientResourceStart` of `kora_lib` (client/blips.lua:158).

## Optional consumers and tests

- [kora_hud](https://github.com/KoraFiveM/kora_hud) reads the `isElectricVehicle` export to show Charge instead of Fuel. Start it after kora_fuel.
- [kora_garages](https://github.com/KoraFiveM/kora_garages) saves the native fuel level in `player_vehicles.fuel`. kora_fuel adds no tables of its own.
- `test/run.sh` runs plain-Lua smoke tests (shared, client, blips, chargers, stations, server). `tests/*.feature` contains kora_qa Gherkin scenarios, which the manifest registers through `qa_feature`.
