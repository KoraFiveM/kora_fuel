---
title: Compatibility
sidebar_position: 8
---

# Compatibility

`fxmanifest.lua` declares:

```lua
provide 'LegacyFuel'
provide 'qb-fuel'
provide 'ps-fuel'
provide 'cdn-fuel'
```

On the client, `Kora.compat.provideExport` registers `GetFuel` and `SetFuel` under each of these names, so existing scripts keep working:

```lua
local level = exports['LegacyFuel']:GetFuel(vehicle)
exports['qb-fuel']:SetFuel(vehicle, 100.0)
```

The aliases use the same native fuel level as the kora_fuel exports, but behave slightly differently:

| | kora_fuel `GetFuel` / `SetFuel` | Legacy alias `GetFuel` / `SetFuel` |
| --- | --- | --- |
| Getter value | Whole number, clamped | Raw fractional `GetVehicleFuelLevel` |
| Invalid entity (getter) | Not checked | Returns `nil` (also for non-vehicles) |
| Setter return | `true` / `false` | `nil` |
| Setter input | Non-numbers become 0 | Non-numbers, NaN and infinity are ignored |
| Network control | Not requested | Calls `NetworkRequestControlOfEntity` before setting |

Both setters clamp the level to the range 0 to `Config.maxLevel`.

Only these two exports are aliased. kora_fuel does not reproduce qb-fuel/ps-fuel/cdn-fuel UIs, jerry cans, events, or state-bag synchronization options. Server-side exports from those resources are not provided either.
