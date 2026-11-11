---
title: Exports
sidebar_position: 6
---

# Exports

All exports are **client-side**. kora_fuel has no server exports.

## GetFuel

```lua
local level = exports.kora_fuel:GetFuel(vehicle)
```

| Param | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle |

**Returns** `integer`: the native fuel level clamped to the range 0 to `Config.maxLevel` and rounded down to a whole number. The vehicle is not validated, so pass an existing entity.

## SetFuel

```lua
local ok = exports.kora_fuel:SetFuel(vehicle, 50.0)
```

| Param | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle |
| `level` | number | New level. It is clamped to the range 0 to `Config.maxLevel`, and non-numbers are treated as 0 |

**Returns** `boolean`: `false` if the entity does not exist, otherwise `true`. The value is set with `SetVehicleFuelLevel` on the local client. Network control is not requested, unlike the [legacy alias](./compatibility.md).

## isElectricVehicle

```lua
if exports.kora_fuel:isElectricVehicle(vehicle) then
    -- show a battery icon
end
```

| Param | Type | Description |
| --- | --- | --- |
| `vehicle` | integer | Vehicle entity handle |

**Returns** `boolean`: `true` if the model is in `Config.electricVehicles`, or if `Config.electric.useNative` is on and `GetIsVehicleElectric(model)` returns true. Native results are cached per model. Missing, zero or non-existent entities return `false`. kora_hud uses this export to show Charge instead of Fuel.

## Legacy aliases

`GetFuel` and `SetFuel` are also available under the `LegacyFuel`, `qb-fuel`, `ps-fuel` and `cdn-fuel` resource names, with slightly different semantics. See [Compatibility](./compatibility.md).
