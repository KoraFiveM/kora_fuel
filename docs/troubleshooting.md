---
title: Troubleshooting
sidebar_position: 9
---

# Troubleshooting

**`[kora_fuel] Skipping EV charging station #N ...` in the console**
A station in `Config.charging.stations` (or a saved config-editor override) has an invalid field. The warning names the station and the field. Fix that entry. The other stations still load.

**`[kora_fuel] charger prop ... was not spawned: ...`**
`Config.charging.prop.model` could not be created, which usually means the model name is wrong or the model is not streamed. The target zone still works.

**The air pump stays hidden or overlaps the charger**
The hide only applies while the charger prop exists, and only to `hideModel` within 1 m of the station `coords`. Check that `hideModel` and `coords` match the world prop.

**An electric vehicle is billed at the petrol price**
The model is detected as electric only through `GetIsVehicleElectric`, but pricing uses `Config.electricVehicles`. Add the spawn name to that list.

**The HUD shows Fuel for an addon EV**
Add its spawn name to `Config.electricVehicles`. kora_hud reads the `isElectricVehicle` export.

**"Electric vehicles cannot use petrol pumps..."**
Charging stations are enabled and `Config.charging.allowAtPumps` is `false`. Drive to the station named in the message, or set `allowAtPumps = true`.

**"Move closer to the service point and vehicle." after confirming**
The server checks the player position against `Config.serviceRadius` (pumps) or `Config.charging.serviceRadius` (chargers), and checks that the vehicle is within `Config.vehicleSearchDistance + 1` m. Stay near the pump or charger until the service finishes.

**No Charge vehicle option at a charger**
The option is hidden when the nearest vehicle (or the one the player is in) is not electric or is already full. It also does not appear if `Config.charging.enabled` is `false` or no valid stations are listed.

**Fuel never drops**
Consumption runs only for the driver with the engine running. Check `Config.consumePerSecond` and `Config.idleConsumptionMultiplier`. Consumption values from the config editor take effect after kora_fuel restarts.
