---
title: Fuel consumption
sidebar_position: 3
---

# Fuel consumption

Consumption runs on the client and only while the local player is in the driver seat (seat `-1`). Its worker thread starts when kora_lib's cached `vehicle`/`seat` values say the player is driving, and stops when that is no longer true. On foot or as a passenger, no consumption code runs. The listeners are registered again whenever kora_lib restarts.

Every `Config.consumeInterval` ms (default 1000), while the engine is running:

```text
rate       = Config.consumePerSecond[vehicleClass] or Config.consumePerSecond.default
multiplier = clamp(speed / Config.speedReference,
                   Config.idleConsumptionMultiplier,
                   Config.maxSpeedConsumptionMultiplier)
used       = rate * multiplier * (Config.consumeInterval / 1000)
```

`speed` is `GetEntitySpeed` in metres per second. At `Config.speedReference` (45 m/s, about 162 km/h) the class rate is used unchanged. When idle, the rate is multiplied by `Config.idleConsumptionMultiplier` (0.08). The speed multiplier is capped at `Config.maxSpeedConsumptionMultiplier` (2.0).

The new level is clamped to the range 0 to `Config.maxLevel` and written with `SetVehicleFuelLevel`. When the level reaches 0 the engine is switched off. Electric vehicles drain in exactly the same way: the battery is the same native fuel level.

## Default class rates (units per second at reference speed)

| Class | ID | Rate |
| --- | --- | --- |
| default (unlisted classes) | - | 0.035 |
| Compacts | 0 | 0.018 |
| Sedans | 1 | 0.024 |
| SUVs | 2 | 0.032 |
| Coupes | 3 | 0.030 |
| Muscle | 4 | 0.040 |
| Sports | 5 | 0.046 |
| Sports classics | 6 | 0.050 |
| Super | 7 | 0.060 |
| Motorcycles | 8 | 0.012 |
| Off-road | 9 | 0.045 |
| Industrial | 10 | 0.075 |
| Utility | 11 | 0.065 |
| Vans | 12 | 0.060 |
| Service | 17 | 0.055 |
| Emergency | 18 | 0.058 |
| Military | 19 | 0.085 |
| Commercial | 20 | 0.080 |

Classes 13 to 16 (cycles, boats, helicopters, planes) and 21 and above use `default`.
