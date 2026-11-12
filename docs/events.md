---
title: Events
sidebar_position: 9
---

# Events

kora_fuel has no public events for other resources. All events and callbacks below are **internal** to the service flow and are listed only for reference. Do not trigger them from other resources. To read or change fuel, use the [exports](./api/client-exports.md).

## Server events

| Event | Payload | Notes |
| --- | --- | --- |
| `kora_fuel:server:purchase` | `netId, account, quantity, currentLevel, site` | Internal. Sent by the service menu. `site` is `'pump'` or `'charger'`. The server fully re-validates the request (account, amount, distance, routing bucket, engine, EV rules, balance) before and after the progress bar. It ignores a request while the same player already has one in progress. See [Server-side checks](./refuelling-and-charging.md). |

## Client events

| Event | Payload | Notes |
| --- | --- | --- |
| `kora_fuel:client:fillVehicle` | `netId, quantity` | Internal. Adds `quantity` to the vehicle's level after payment. It is ignored unless it was sent by the server. |
| `kora_fuel:client:serviceResult` | `ok, message, electric` | Internal. Shows the result notification, titled Charging if `electric` is true and Fuel otherwise. |

## Callbacks

| Callback | Side | Args | Returns |
| --- | --- | --- | --- |
| `kora_fuel:runProgress` | client (`Kora.callback.register`) | `netId, duration, electric` | `true` if the progress bar finished. `false` if it was cancelled, the vehicle disappeared or the engine was started. |

## Events handled

| Event | Side | Effect |
| --- | --- | --- |
| `playerDropped` | server | Clears the player's in-progress purchase lock |
| `QBCore:Server:OnPlayerUnload` | server | Clears the player's in-progress purchase lock |
| `onClientResourceStart` (kora_lib) | client | Registers the cache listeners again for consumption and nearest-blip updates |
| `onResourceStop` (kora_fuel) | client | Removes blips and charger props, and restores hidden air pumps |
