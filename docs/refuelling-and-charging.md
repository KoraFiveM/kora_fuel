---
title: Refuelling and charging
sidebar_position: 6
---

# Refuelling and charging

Petrol pumps and EV charging stations use the same service flow: menu, progress bar, server-side payment, then fill. They differ in where the service is allowed and in the price and timing.

## Petrol pumps

All models in `Config.pumpModels` (the vanilla `prop_gas_pump_*` and `prop_vintage_pump` models) get a **Service nearby vehicle** interaction through `Kora.interact.addModel`, with an interaction distance of 2.5 m. The label is the same for petrol and electric vehicles. The menu title changes to **Refuel vehicle** or **Charge vehicle**.

When the option is selected, the client checks the following in order:

1. The player is within `Config.serviceRadius` (45 m) of an entry in `Config.stations`. If not, the player sees "Move to a fuel station or charging point first."
2. A vehicle is within `Config.vehicleSearchDistance` (6 m) of the player. If not, the player sees "Park a vehicle next to the pump or charger."
3. If the vehicle is electric and pumps do not accept EVs (see below), the player sees `Config.charging.pumpMessage` followed by the nearest charging station and its distance. With `waypointToNearest` the GPS waypoint is also set, for example: "Electric vehicles cannot use petrol pumps. Use an EV charging station. Nearest: Little Seoul (1.2 km). A GPS waypoint has been set to it."
4. The engine must be off ("Switch the engine off before servicing the vehicle.").
5. The vehicle must not already be full ("Vehicle is already full." / "Battery is already fully charged.").

### EVs at petrol pumps

Petrol pumps accept electric vehicles when either:

- charging stations are disabled (`Config.charging.enabled = false` or `Config.charging.stations` is empty), or
- `Config.charging.allowAtPumps = true`.

In both cases the pump charges EVs at `Config.pricePerUnit.charge`, with petrol timing (`Config.progressMsPerUnit`). Otherwise the client shows the refusal message described above, and the server also rejects a pump purchase for a listed EV ("Electric vehicles must use a charging station.").

## Service menu

The menu is a kora_lib NUI app (`kora_fuel:pump`, compact layout on the right). It shows:

- a progress bar with the current level (shown in red at 15 or below)
- **Price per unit** and **Total Price** for the selected amount. The total updates as the slider moves. If the total was rounded, the description shows the exact amount, for example "1 unit ($1.25 rounded up)".
- **Amount to add**: a slider from 1 to the missing amount (`floor(Config.maxLevel) - level`). The default is a full fill.
- **Pay with**: one option per entry in `Config.paymentAccounts`, with the first entry as the default.

After confirmation, the client sends the purchase to the server. The server validates it, then asks the client to play the progress bar: the ped turns to the vehicle, then plays the jerrycan animation with a fuel nozzle prop. Movement and combat are disabled, and the player can cancel. If the progress bar finishes, the server validates the request again, takes the money and fills the vehicle. A notification reports the result, for example "Vehicle refuelled for $40.".

Notifications about an electric vehicle or a charging station have the title **Charging**. Petrol notifications have the title **Fuel** (`locales/en.lua`).

## EV charging stations

`Config.charging.stations` lists the charging stations. The 13 defaults are at real petrol stations: Murrieta Heights, La Puerta, Little Seoul, Little Seoul South, Elysian Island, Pacific Bluffs, Downtown Vinewood, Tataviam Mountains, Route 68 West, Route 68 East, Senora Freeway, Grapeseed and Paleto Bay. Each default is placed exactly where GTA puts that forecourt's air pump (`prop_gas_airunit01`), with the same heading, and hides that air pump while the charger is shown.

The network is active only when `Config.charging.enabled` is true and at least one valid station is listed.

### Station fields

| Field | Required | Description |
| --- | --- | --- |
| `label` | yes | Non-empty name, used on the map and in messages |
| `coords` | yes | Ground point the charger stands on |
| `heading` | no | Degrees (default 0) |
| `offset` | no | World-space metres added to `coords` to move the charger |
| `radius` | no | Target zone radius; missing or 0 uses `Config.charging.zoneRadius` |
| `hideModel` | no | World prop model at `coords` that is hidden while the charger is spawned |

`coords` and `offset` accept `vector3(x, y, z)`, `vec3(x, y, z)`, `{ x = , y = , z = }` and `{ x, y, z }`. All of these are converted to `vector3` by `shared/stations.lua`, including saved config-editor overrides and the client config snapshot. Each station is validated separately. If a station has an invalid field, it is skipped and a single console warning is printed, and the other stations still load:

```text
[kora_fuel] Skipping EV charging station #3 "Paleto Bay": offset must be a vector3, {x = , y = , z = } or {x, y, z} (or left out).
```

```lua
Config.charging.stations = {
    { label = 'Murrieta Heights', coords = vector3(1194.54, -1391.44, 34.40), heading = 90.0, hideModel = 'prop_gas_airunit01' },
    { label = 'My Garage', coords = { x = 100.0, y = 200.0, z = 30.0 }, offset = { 0.0, 0.5, 0.0 }, radius = 2.0 },
}
```

### Charger props

If `Config.charging.prop.enabled` is true, each station gets a charger prop. This is a frozen, invincible, local (non-networked) entity created through `Kora.entities`:

- A `Kora.zones` sphere of `prop.spawnDistance` metres (at least 10) around the charger position spawns the prop when the player enters it and deletes it when the player leaves.
- The prop heading is the station `heading` plus `prop.headingOffset`.
- When the prop spawns, the station's `hideModel` is hidden with `CreateModelHideExcludingScriptObjects` (radius 1 m). The model is shown again when the prop is removed or the resource stops.
- If `prop.snapToGround` is set, the prop is placed on the ground on the next frame.

GTA V has no EV charger model, so the default `prop.model` is `prop_parkingpay` (the pay-and-display machine). You can set it to any streamed charger prop.

### Charge vehicle option

Each station gets a kora_target sphere zone at the charger position, raised by `prop.targetHeight` metres. Its radius is the station `radius` or `zoneRadius`, and its interaction distance is `interactDistance`. Hold the target key and aim at the charger to see **Charge vehicle**. The option only appears when the vehicle the player is in, or the closest vehicle within `Config.vehicleSearchDistance`, is electric and not full. This check is cached for 500 ms while aiming. The kora_target floating world icon is drawn only if `Config.charging.worldIcon` is true.

To offer the same option on custom map charger props, list their models in `Config.charging.propModels` (registered through `Kora.interact.addModel`).

When the option is selected, the player must be within `Config.charging.serviceRadius` (15 m) of a station ("Move to an EV charging station first."), and the vehicle must be electric ("Charging stations are for electric vehicles only."). After that, the same engine-off and not-full checks as at a pump apply. The menu description shows the station name, for example "Battery charge - Little Seoul".

## Pricing and timing

| Situation | Unit price | Time per unit |
| --- | --- | --- |
| Petrol vehicle (anywhere) | `Config.pricePerUnit.fuel` | `Config.progressMsPerUnit` ms |
| Listed EV at a pump (if allowed) | `Config.pricePerUnit.charge` | `Config.progressMsPerUnit` ms |
| Listed EV at a charging station | `Config.charging.pricePerPercent` | `Config.charging.secondsPerPercent` s |

The progress bar always lasts at least `Config.minimumProgressMs`.

Price type is decided by `Config.electricVehicles` on both client and server. A vehicle that is detected as electric only through the native (`Config.electric.useNative`) shows charging wording and can use a charger, but it is billed at the petrol price. Add such models to `Config.electricVehicles` so they get charging prices.

Payments are whole dollars. The total is units x unit price, rounded to cents, then rounded to a whole dollar according to `Config.priceRounding`:

- `up` (default): never below the advertised unit price
- `nearest`
- `down`: a total under $1 is free

A total of $0 is not charged at all.

## Server-side checks

`kora_fuel:server:purchase` re-validates the purchase twice: before the progress bar and again after it.

- The payment account is in `Config.paymentAccounts`.
- The amount is a whole number from 1 to the missing amount, based on the level the client reported.
- The vehicle network ID resolves through `Kora.world.resolveNetworkEntity`: it is a vehicle, in the same routing bucket, and within `Config.vehicleSearchDistance + 1` m of the player.
- The player is within `Config.serviceRadius` of a `Config.stations` entry for a pump, or within `Config.charging.serviceRadius` of a charging station for a charger.
- The engine is off.
- A listed EV at a pump is rejected unless pumps accept EVs.
- The account balance (kora_core `getMoney`) covers the price.

Each player can have only one purchase in progress at a time. The lock is cleared on `playerDropped` and `QBCore:Server:OnPlayerUnload`. Money is removed with kora_core `removeMoney`, using the reason text `fuel vehicle <netId>` or `charge vehicle <netId>`.
