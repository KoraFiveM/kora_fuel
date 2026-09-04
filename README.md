# qbfuel

Native vehicle fuel consumption, petrol-station refuelling, and EV charging.

Fuel and charge share GTA's 0–100 native vehicle fuel level. This is deliberate:
the HUD, qbgarages, and vehicle streaming all see the same level, and a stored
vehicle already persists that level through the existing `player_vehicles.fuel`
column. At the default vanilla station pumps, EVs offer a charging flow instead
of refuelling. Add addon EV spawn names to `Config.electricVehicles`.

Client exports: `GetFuel(vehicle)`, `SetFuel(vehicle, level)`, and
`isElectricVehicle(vehicle)`.

## Install

Start `qbfuel` after `qblib`, `qbcore`, and `qbtarget`, and before `qbhud`.
The HUD uses qbfuel's EV classifier to render Charge rather than Fuel.
