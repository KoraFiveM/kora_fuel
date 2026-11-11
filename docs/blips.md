---
title: Map blips
sidebar_position: 4
---

# Map blips

All blips are created through `Kora.blips`. kora_lib tracks them per resource and lists them under a pause-map category, and players can hide them with kora_lib's `/blips`. They are created when the resource starts and removed when it stops.

## Gas station blips (`Config.blips`)

Every coordinate in `Config.stations` gets a blip, with these exceptions:

- Stations closer together than `mergeRadius` metres (2D distance, default 30) share one blip, drawn for the first station in the list. The default list includes some forecourts twice. Set `mergeRadius` to `0` to draw one blip per entry.
- `perStation[index].enabled = false` hides the blip for that entry. `index` is the 1-based position in `Config.stations`.

`perStation` entries can override `sprite`, `colour`, `scale`, `shortRange`, `label` and `category` for a single station:

```lua
Config.blips.perStation = {
    [3] = { enabled = false },
    [5] = { label = 'Airfield Fuel' },
}
```

The category is always `Fuel` unless a `perStation` entry overrides it. `Config.blips` itself has no `category` key.

## Charging station blips (`Config.charging.blips`)

Each valid charging station gets a blip at its charger position. These blips are only created while the charging network is active. If `showStationName` is true, the legend shows the label followed by the station name, for example "EV Charging Station - Little Seoul". `category` sets the kora_lib pause-map category. If that category is invalid, the blip is created under `Fuel` instead.

## Nearest station only

Set `Config.blips.nearestOnly` or `Config.charging.blips.nearestOnly` to `true` to show a single blip for the station of that type nearest the player, instead of one blip per station. The nearest station is chosen again from kora_lib's cached player coords, but only after the player has moved 50 m since the last choice. There is no polling thread.

## Options

See [Configuration](./configuration.md) for the full key list.
