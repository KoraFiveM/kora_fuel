---
title: "How to use"
sidebar_position: 3
---


# How to use

Players refuel or charge at a prop (a petrol pump model or an EV charger) through kora_target. The server is the only place that decides a vehicle is close enough, the player paid enough, and the fill amount is valid — the client only drives the menu and the progress bar.

## Petrol vs electric, and where each can be serviced

- A vehicle is electric if its model hash is in `Config.electricVehicles`, or (when `Config.electric.useNative` is true) the game itself reports `GetIsVehicleElectric(model)` true. Pricing and server-side validation always use `Config.electricVehicles` — the native check only changes client wording and the HUD icon, so a model missing from the list is billed as petrol even if the game calls it electric.
- Petrol pumps (`Config.pumpModels`, found within `Config.stations`) refuse electric vehicles unless `Config.charging.allowAtPumps` is true or no charging network exists at all (`Fuel.pumpsAcceptElectric()`). A refused EV gets a message naming the nearest charger and, if `Config.charging.waypointToNearest` is true, a GPS waypoint to it.
- EV chargers (`Config.charging.stations`) refuse non-electric vehicles with `Charging stations are for electric vehicles only.`
- Both site kinds require the engine switched off and a nearby vehicle within `Config.vehicleSearchDistance` (client pre-check) / `+1.0` m (server resolve). The server independently checks the player is within `Config.serviceRadius` of a `Config.stations` entry (pump) or `Config.charging.serviceRadius` of a `Config.charging.stations` entry (charger) — client proximity alone never authorizes a sale.

## A purchase end to end

```text title="purchase flow"
-- 1. Player aims at a pump (or a charger prop) and selects the interaction.
--    client/main.lua opens an AppShell app ('kora_fuel:pump') showing level,
--    price per unit and a quantity/account form.

-- 2. Submitting the form fires:
TriggerServerEvent('kora_fuel:server:purchase', netId, account, quantity, currentLevel, site)
-- site is 'pump' or 'charger'.

-- 3. Server validates (account, quantity vs capacity, vehicle resolve + distance,
--    engine off, electric-vs-site rules, price, balance), then asks the client
--    to run the progress bar:
Kora.callback.trigger(src, 'kora_fuel:runProgress', netId, durationMs, electric)

-- 4. If the player does not cancel, the server re-validates (price/capacity may
--    have changed), takes payment through exports.kora_core:removeMoney, then:
TriggerClientEvent('kora_fuel:client:fillVehicle', src, netId, quantity)
TriggerClientEvent('kora_fuel:client:serviceResult', src, true, 'Vehicle refuelled for $45.', false)
```

- Price is computed from the authoritative vehicle kind and the configured `Config.pricePerUnit` (pump) or `Config.charging.pricePerPercent` (charger), rounded to a whole dollar per `Config.priceRounding` (`up`, `nearest` or `down`).
- The server tracks one in-flight purchase per player (`busy[src]`) so a second `kora_fuel:server:purchase` while one is running is dropped.
- Validation runs twice: once before the progress bar (so an obviously invalid request fails fast) and again right after it completes (so a vehicle that moved, filled, or had its engine started during the progress bar is re-checked before money changes hands).
- A fully free total (price rounds to $0, which can happen with `priceRounding = 'down'` on less than one dollar) skips the payment call entirely, because `kora_core`’s `removeMoney` refuses a zero-amount removal.

## Fuel consumption while driving

Only the local driver's own client ticks consumption (a passenger or an unoccupied vehicle never drains). `client/main.lua` watches `Kora.cache.vehicle`/`Kora.cache.seat` and runs a loop every `Config.consumeInterval` ms while the player is the driver (`seat == -1`) of a vehicle with its engine on.

- Consumption is `Config.consumePerSecond[vehicleClass] (or .default) × multiplier × (interval ÷ 1000)`, where the multiplier is `max(idleConsumptionMultiplier, speed / Config.speedReference)` capped at `Config.maxSpeedConsumptionMultiplier`.
- When the level reaches 0 the engine is switched off (`SetVehicleEngineOn(vehicle, false, true, true)`).
- Consumption is purely a client-side cosmetic/gameplay effect: nothing is persisted here. A separate resource (for example `kora_garages`, mentioned in `config.lua` comments) is expected to read/write the native fuel level for saving.

## EV charging stations and chargers

Distinct from petrol pumps. Each entry in `Config.charging.stations` gets, on the client, a kora_target sphere zone (the interaction) and, separately, a `Kora.zones.sphere` that spawns/despawns a local charger prop as the player enters/leaves `Config.charging.prop.spawnDistance` metres.

- The charger prop (default `prop_parkingpay`) is a frozen, invincible, unnetworked local entity created through `Kora.entities.create`; it is deleted again when the player leaves or the resource stops.
- A station may set `hideModel` (for example `prop_gas_airunit01`, the vanilla air-pump prop) so the real map prop is hidden while the charger stands in for it, and shown again when the charger despawns.
- The "Charge vehicle" target option only appears for an electric vehicle below `Config.maxLevel`; it is re-evaluated at most every 500 ms (`CHARGE_CHECK_MS`), not every aim-resolver tick.
- Set `Config.charging.enabled = false` (or leave `Config.charging.stations` empty) to turn off the whole charging network; pumps then service EVs as if no network existed.
