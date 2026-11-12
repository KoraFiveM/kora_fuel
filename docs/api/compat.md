---
title: "Legacy export compatibility"
sidebar_position: 3
---


# Legacy export compatibility

kora_fuel registers `GetFuel`/`SetFuel` under four legacy resource names through Kora Lib’s `Kora.compat.provideExport`, so resources written against any of the original fuel scripts call `exports.LegacyFuel`/`exports['qb-fuel']`/`exports['ps-fuel']`/`exports['cdn-fuel']` without changes, even though only `kora_fuel` is actually running.

Namespace: `exports.LegacyFuel · exports['qb-fuel'] · exports['ps-fuel'] · exports['cdn-fuel']` · Source: `client/main.lua (`Kora.compat.provideExport`)`

## How it works

These wrappers intentionally differ from the Kora-native `GetFuel`/`SetFuel` exports above: they keep the old fractional return value and nil-on-invalid behavior, and `SetFuel` requests entity control first.

## Functions

Use these only for compatibility with code you have not migrated; new code should prefer the Kora-native exports.

### `exports.LegacyFuel:GetFuel(vehicle) / exports['qb-fuel']:GetFuel(vehicle) / exports['ps-fuel']:GetFuel(vehicle) / exports['cdn-fuel']:GetFuel(vehicle)`

Returns the raw, unrounded native fuel level — matching the original LegacyFuel/qb-fuel/ps-fuel/cdn-fuel contract, which is fractional, unlike the Kora-native `GetFuel` export above.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle. |

**Returns**

number (fractional, 0-100), or `nil` when the handle is invalid, non-existent or not a vehicle.

**Example**

```lua
local level = exports.LegacyFuel:GetFuel(vehicle)
```

**Representative console output**

```text
86.42
```

### `exports.LegacyFuel:SetFuel(vehicle, level) / exports['qb-fuel']:SetFuel(...) / exports['ps-fuel']:SetFuel(...) / exports['cdn-fuel']:SetFuel(...)`

Sets the native fuel level, matching the legacy contract. Requests network control of the vehicle first (`NetworkRequestControlOfEntity`) so a resource compiled against the old resources keeps working if it never did this itself.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle; invalid/non-existent/non-vehicle is a no-op. |
| `level` | number | Target level. `NaN` or `±inf` is rejected silently (the call does nothing). |

**Returns**

No value.

**Example**

```lua
exports['qb-fuel']:SetFuel(vehicle, 50.0)
```

**Representative console output**

```text
-- vehicle fuel level set to 50.0, clamped to Config.maxLevel
```

## Limits and related APIs

Only `GetFuel`/`SetFuel` are provided under the legacy names — there is no legacy equivalent registered for `isElectricVehicle` or any pump/charging feature.

## Related guides

- [Client exports](./client-exports.md)

## Manifest and differences from the Kora exports

`fxmanifest.lua` declares:

```lua title="fxmanifest.lua"
provide 'LegacyFuel'
provide 'qb-fuel'
provide 'ps-fuel'
provide 'cdn-fuel'
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
