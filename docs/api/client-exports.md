---
title: "Client exports"
sidebar_position: 2
---


# Client exports

Three exports read or set the native fuel level and detect electric vehicles. There are no server exports: every change to a vehicle’s fuel is local to the client that owns it (set through the fill/consumption events and loops below), and GTA’s native fuel value itself is what travels over the network via entity state, not through kora_fuel.

Namespace: `exports.kora_fuel` · Source: `client/main.lua`

## How it works

All three call the same native wrappers used internally (`Fuel.clampLevel`, `GetVehicleFuelLevel`, `SetVehicleFuelLevel`). `isElectricVehicle` additionally memoizes the native `GetIsVehicleElectric` result per vehicle model the first time it is asked (also warmed once when a vehicle becomes the player’s cached vehicle), so repeated calls for the same model cost nothing extra.

## Functions

Call these from any client script once `kora_fuel` has started.

### `exports.kora_fuel:isElectricVehicle(vehicle) -> boolean`

True when the vehicle is treated as electric: either its model is in `Config.electricVehicles`, or (with `Config.electric.useNative`) the game native `GetIsVehicleElectric` says so. Public client export.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | A vehicle entity handle. `0`, a non-existent handle, or `nil` returns `false`. |

**Returns**

boolean

**Example**

```lua
if exports.kora_fuel:isElectricVehicle(veh) then
    print('this vehicle charges, it does not refuel')
end
```

**Representative console output**

```text
true
```

### `exports.kora_fuel:GetFuel(vehicle) -> integer`

Current fuel/charge level, floored to a whole number on GTA’s native 0-100 scale. This is the Kora-native export (compare to the legacy `GetFuel` below, which returns the raw fractional value).

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle. |

**Returns**

integer, 0-100 (clamped by `Config.maxLevel`).

**Example**

```lua
local level = exports.kora_fuel:GetFuel(vehicle)
```

**Representative console output**

```text
87
```

### `exports.kora_fuel:SetFuel(vehicle, level) -> boolean`

Sets the native fuel/charge level directly, clamped to `[0, Config.maxLevel]`. Public client export.

**Parameters**

| Name | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle; `0`/invalid/non-existent returns `false`. |
| `level` | number | Target level. Non-numeric values are coerced with `tonumber` and default to the clamped minimum. |

**Returns**

boolean — `false` only when the vehicle handle is invalid.

**Example**

```lua
exports.kora_fuel:SetFuel(vehicle, 100)
```

**Representative console output**

```text
true
```

## Limits and related APIs

Client-only: there is no server-side equivalent, so another resource cannot read or set a vehicle’s fuel level unless it is near that vehicle’s owning client. `SetFuel` does not call `NetworkRequestControlOfEntity` itself (the legacy `SetFuel` compat wrapper does, see below) — set fuel only on a vehicle you already have control of, or the native call may silently do nothing.

## Related guides

- [Legacy export compatibility](./compat.md)

## Behaviour details (from the code)

- `GetFuel` clamps the native level to 0 to `Config.maxLevel` and rounds down; the vehicle is not validated, so pass an existing entity.
- `SetFuel` treats non-numbers as 0 and sets the value with `SetVehicleFuelLevel` on the local client.
- `isElectricVehicle` returns `true` if the model is in `Config.electricVehicles`, or if `Config.electric.useNative` is on and `GetIsVehicleElectric(model)` is true. kora_hud uses it to show Charge instead of Fuel.
- `GetFuel` and `SetFuel` are also available under the legacy resource names with slightly different semantics, see [Legacy export compatibility](./compat.md).
