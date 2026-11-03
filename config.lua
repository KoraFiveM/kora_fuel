Config = Config or {}

-- Both petrol and battery charge use GTA's native 0-100 vehicle fuel level.
-- That makes charge survive vehicle streaming and lets kora_garages persist it
-- through its existing fuel snapshot without a second database column.
Config.maxLevel = 100.0
Config.serviceRadius = 45.0
Config.vehicleSearchDistance = 6.0
Config.progressMsPerUnit = 125
Config.minimumProgressMs = 1500
Config.serviceSessionGraceMs = 15000
Config.serviceRateLimit = { max = 5, window = 10000 }

Config.paymentAccounts = { 'cash', 'bank' }
Config.pricePerUnit = {
    fuel = 2.0,
    charge = 1.25,
}

-- One second at the configured reference speed consumes this amount. Every
-- class has its own rate; omitted classes use `default`.
Config.consumeInterval = 1000
Config.idleConsumptionMultiplier = 0.08
Config.speedReference = 45.0 -- metres/second (162 km/h)
Config.maxSpeedConsumptionMultiplier = 2.0
Config.consumePerSecond = {
    default = 0.035,
    [0] = 0.018, -- compacts
    [1] = 0.024, -- sedans
    [2] = 0.032, -- SUVs
    [3] = 0.030, -- coupes
    [4] = 0.040, -- muscle
    [5] = 0.046, -- sports
    [6] = 0.050, -- sports classics
    [7] = 0.060, -- super
    [8] = 0.012, -- motorcycles
    [9] = 0.045, -- off-road
    [10] = 0.075, -- industrial
    [11] = 0.065, -- utility
    [12] = 0.060, -- vans
    [17] = 0.055, -- service
    [18] = 0.058, -- emergency
    [19] = 0.085, -- military
    [20] = 0.080, -- commercial
}

-- GTA's electric models. This is the single source of truth: the server
-- (pricing/validation), pump wording and the HUD (via the isElectricVehicle
-- export) all read it. Add addon EV spawn names here. Models released in
-- newer GTA builds are also picked up by Config.electric.useNative below, so
-- this list only has to cover addons and older game builds.
Config.electricVehicles = {
    'airtug', 'buffalo5', 'caddy', 'caddy2', 'caddy3', 'coureur', 'cyclone',
    'cyclone2', 'dilettante', 'dilettante2', 'envisage', 'estride', 'imorgon',
    'inductor', 'inductor2', 'iwagen', 'khamelion', 'neon', 'omnisegt',
    'pipistrello', 'powersurge', 'raiden', 'rcbandito', 'surge', 'suzume',
    'tezeract', 'virtue', 'vivanite', 'vivanite2', 'voltic', 'voltic2', 'xtreme',
}

Config.electric = {
    -- Also ask the game (GetIsVehicleElectric) whether a vehicle is electric,
    -- on the client, once per vehicle model. Affects the HUD icon and the
    -- "Charge vehicle" pump wording only; server pricing and validation stay
    -- on Config.electricVehicles. Ignored on game builds without the native.
    useNative = true,
}

-- Pump models cover the standard GTA petrol forecourts. Their interaction
-- adapts automatically: an EV shows "Charge vehicle", every other vehicle
-- shows "Refuel vehicle".
Config.pumpModels = {
    'prop_gas_pump_1a', 'prop_gas_pump_1b', 'prop_gas_pump_1c',
    'prop_gas_pump_1d', 'prop_vintage_pump', 'prop_gas_pump_old2'
}

-- Service areas are deliberately server-side too: the client may choose an
-- interaction, but the server will only take payment and fill a vehicle here.
-- The default list is the vanilla map's petrol-station network. EVs charge at
-- Config.charging.stations instead unless Config.charging.allowAtPumps is on.
Config.stations = {
    vector3(49.4187, 2778.793, 58.043), vector3(263.894, 2606.463, 44.983),
    vector3(1039.958, 2671.134, 39.550), vector3(1207.260, 2660.175, 37.899),
    vector3(2539.685, 2594.192, 37.944), vector3(2679.858, 3263.946, 55.240),
    vector3(2005.055, 3773.887, 32.403), vector3(1687.156, 4929.392, 42.078),
    vector3(1701.314, 6416.028, 32.763), vector3(179.857, -1562.329, 29.263),
    vector3(-94.461, -1761.405, 29.534), vector3(-723.145, -935.051, 19.213),
    vector3(-526.019, -1211.003, 18.184), vector3(-70.2148, -1761.792, 29.534),
    vector3(265.648, -1261.309, 29.292), vector3(819.653, -1028.846, 26.403),
    vector3(1208.951, -1402.567, 35.224), vector3(1181.381, -330.847, 69.316),
    vector3(620.843, 269.100, 103.089), vector3(2581.321, 362.039, 108.468),
    vector3(176.631, -1562.026, 29.263), vector3(-319.292, -1471.715, 30.549),
    vector3(1784.324, 3330.550, 41.253),
}

-- Map blips for every entry in Config.stations (the list above is the only
-- source of coordinates). Set enabled = false to hide them all. perStation is
-- keyed by the 1-based index in Config.stations and may hold `enabled`,
-- `sprite`, `colour`, `scale`, `shortRange` or `label` overrides. Stations
-- closer together than `mergeRadius` metres (the default list has forecourts
-- listed twice for each side of a road) share one blip, drawn for the first
-- of them; set it to 0 to draw one blip per entry. nearestOnly = true shows a
-- single blip, for the gas station nearest the player, re-picked as they
-- travel. Example perStation:
--   perStation = { [3] = { enabled = false }, [5] = { label = "Airfield Fuel" } }
Config.blips = {
    enabled = true,
    sprite = 361,
    colour = 1,
    scale = 0.6,
    shortRange = true,
    label = 'Gas Station',
    mergeRadius = 30.0,
    nearestOnly = false,
    perStation = {},
}

-- EV charging stations at real petrol stations. Each one spawns a charger prop
-- (Config.charging.prop) on the client while the player is nearby, and the
-- "Charge vehicle" target sits on that prop: hold Alt and aim at the charger
-- while an electric vehicle that is not fully charged is within
-- Config.vehicleSearchDistance of the player (or the player sits in it). The
-- server also checks the player is within `serviceRadius` of a station before
-- taking payment, so this list is an authorization boundary.
--
-- Station fields: `label` (map and message name), `coords` (the ground point
-- the charger stands on), `heading` (degrees), optional `offset` (world-space
-- metres added to coords, to nudge a charger without retyping it), optional
-- `radius` (target zone radius around the prop; 0 uses `zoneRadius`) and
-- optional `hideModel` (a world prop at `coords` that is hidden while the
-- charger is spawned, so the two never overlap). `coords` and `offset` may be
-- written as vector3(x, y, z), vec3(x, y, z), { x = , y = , z = } or
-- { x, y, z }. Each station is checked on its own (shared/stations.lua): one
-- with a bad field is skipped with a console warning naming it, and the rest
-- still load.
--
-- The defaults stand exactly where GTA places the forecourt air pump
-- (prop_gas_airunit01) at each station, with its heading, so every charger is
-- on the station's own ground, clear of buildings and reachable by car. That
-- air pump is hidden while the charger is shown.
Config.charging = {
    -- Master switch. When false (or when no stations are listed) there is no
    -- charging network and petrol pumps keep servicing EVs as before.
    enabled = true,
    -- false: an EV used at a petrol pump gets `pumpMessage` and the nearest
    -- station instead of a charge menu. true: pumps charge EVs at
    -- Config.pricePerUnit.charge as well.
    allowAtPumps = false,
    pumpMessage = 'Electric vehicles cannot use petrol pumps. Use an EV charging station.',
    -- Station price per 1% of charge, and how long 1% takes to charge. The
    -- server prices and times the purchase itself; the client only displays it.
    pricePerPercent = 1.25,
    secondsPerPercent = 0.25,
    -- Server-side range (metres) from a station within which charging is paid.
    serviceRadius = 15.0,
    -- Default target zone radius around the charger prop and the maximum aim
    -- distance (metres).
    zoneRadius = 1.25,
    interactDistance = 5.0,
    -- The charger prop spawned at every station. It is a local entity created
    -- through kora_lib when the player comes within `spawnDistance` metres and
    -- deleted again when they leave or the resource stops. GTA V has no
    -- vanilla EV charger, so the default model is the free-standing
    -- pay-and-display machine; set `model` to a streamed charger prop to use a
    -- real one. `headingOffset` turns every charger (for models whose front is
    -- not their +Y axis), `snapToGround` settles the prop onto the ground
    -- after spawning, and the target zone sits `targetHeight` metres above
    -- the station coords. enabled = false keeps stations target-zone only.
    prop = {
        enabled = true,
        model = 'prop_parkingpay',
        headingOffset = 0.0,
        spawnDistance = 75.0,
        snapToGround = true,
        targetHeight = 1.0,
    },
    -- Optional extra charger prop models (custom map assets) that also offer
    -- the charge option within a station's service radius.
    propModels = {},
    -- Draw kora_target's world icon (the floating square) at each station.
    -- Off by default: the charger prop marks the spot.
    worldIcon = false,
    stations = {
        { label = 'Murrieta Heights', coords = vector3(1194.54, -1391.44, 34.40), heading = 90.0, hideModel = 'prop_gas_airunit01' },
        { label = 'La Puerta', coords = vector3(-334.59, -1455.46, 29.54), heading = 0.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Little Seoul', coords = vector3(-727.31, -906.89, 18.05), heading = 0.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Little Seoul South', coords = vector3(-546.88, -1221.65, 17.31), heading = 65.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Elysian Island', coords = vector3(-60.77, -2536.23, 5.19), heading = 235.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Pacific Bluffs', coords = vector3(-2078.15, -298.24, 12.29), heading = 354.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Downtown Vinewood', coords = vector3(625.68, 247.43, 102.06), heading = 150.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Tataviam Mountains', coords = vector3(2555.33, 347.47, 107.65), heading = 0.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Route 68 West', coords = vector3(62.59, 2788.68, 56.92), heading = 53.0, hideModel = 'prop_gas_airunit01' },
        { label = 'Route 68 East', coords = vector3(1017.87, 2654.75, 38.74), heading = 90.7, hideModel = 'prop_gas_airunit01' },
        { label = 'Senora Freeway', coords = vector3(2691.46, 3267.82, 54.28), heading = 239.6, hideModel = 'prop_gas_airunit01' },
        { label = 'Grapeseed', coords = vector3(1697.68, 4918.80, 41.11), heading = 325.5, hideModel = 'prop_gas_airunit01' },
        { label = 'Paleto Bay', coords = vector3(-91.02, 6391.60, 30.68), heading = 225.3, hideModel = 'prop_gas_airunit01' },
    },
    -- Map blips, one per station, created through Kora.blips so players can
    -- also hide them with /blips. `sprite` and `colour` are GTA blip ids
    -- (354 / 46 by default). The legend entry reads `label`, followed by the
    -- station name when `showStationName` is true. `category` is a fixed
    -- Kora.blips pause-map category. shortRange = true (default) shows a blip on the
    -- minimap only when in range, like fuel station blips (it always shows on
    -- the pause map); set it to false to keep them on the minimap at any
    -- distance. nearestOnly = true shows a single blip, for the station
    -- nearest the player, re-picked as they travel.
    blips = {
        enabled = true,
        sprite = 354,
        colour = 46,
        scale = 0.8,
        shortRange = true,
        label = 'EV Charging Station',
        showStationName = true,
        category = 'Fuel',
        nearestOnly = false,
    },
}

-- Before kora_lib's schema sees the list: every coords/offset becomes a vector3
-- and an invalid station is dropped with one warning, so it cannot fail the
-- whole resource config.
Config.charging.stations = Fuel.normalizeChargingStations(Config.charging.stations)

-- Registers this resource-owned configuration with kora_lib without changing its public Config table.
if Kora and Kora.config and Kora.config.adopt then
    Config.maxLevel = Kora.config.number(Config.maxLevel, {
        min = 1.0,
        max = 100.0,
        step = 1.0,
        label = 'Maximum fuel level',
        description = 'Sets the full-tank fuel or battery level on GTA’s native 0–100 vehicle fuel scale. Keep this at or below 100 so qbfuel, qbgarages, and the HUD agree on the stored vehicle state.',
    })
    Config.serviceRadius = Kora.config.number(Config.serviceRadius, {
        advanced = true,
        min = 1.0,
        step = 0.5,
        label = 'Fuel-station service radius',
        description = 'Sets the maximum distance in metres between a vehicle and a configured station coordinate before the server refuses a paid refuel or charge request. This server-side check must cover the intended forecourt without reaching unrelated nearby roads.',
    })
    Config.vehicleSearchDistance = Kora.config.number(Config.vehicleSearchDistance, {
        advanced = true,
        min = 1.0,
        step = 0.5,
        label = 'Nearby vehicle search distance',
        description = 'Sets how many metres the client searches from a pump interaction to find the vehicle being serviced. Keep this comfortably below the station service radius so the client interaction and server authorization boundaries remain consistent.',
    })
    Config.progressMsPerUnit = Kora.config.integer(Config.progressMsPerUnit, {
        min = 1,
        label = 'Service time per fuel unit (milliseconds)',
        description = 'Sets the number of milliseconds added to the refuelling or charging progress action for each missing fuel-level unit. Larger values make filling an emptier vehicle take proportionally longer.',
    })
    Config.minimumProgressMs = Kora.config.integer(Config.minimumProgressMs, {
        min = 0,
        label = 'Minimum service duration (milliseconds)',
        description = 'Sets the minimum refuelling or charging action duration in milliseconds, even when the vehicle needs only a small amount. Use zero only if near-full top-ups may complete immediately.',
    })
    Config.serviceSessionGraceMs = Kora.config.integer(Config.serviceSessionGraceMs, {
        advanced = true,
        min = 0,
        label = 'Service completion grace period',
        description = 'Sets how many extra milliseconds the server keeps an authorized refuelling session valid after its expected progress duration. This absorbs normal client and network delay without leaving payment tokens reusable indefinitely.',
    })
    Config.serviceRateLimit = Kora.config.object({
        max = Kora.config.integer(Config.serviceRateLimit.max, {
            min = 1,
            label = 'Service requests per window',
            description = 'Sets the maximum number of refuel or charge session requests one player may make during the configured rate-limit window. Requests over this limit are rejected before session work is allocated.',
        }),
        window = Kora.config.integer(Config.serviceRateLimit.window, {
            min = 1,
            label = 'Service rate-limit window',
            description = 'Sets the rolling rate-limit window in milliseconds used to count one player’s refuel or charge session requests.',
        }),
    }, { advanced = true })
    Config.paymentAccounts = Kora.config.list(Config.paymentAccounts,
        Kora.config.enum('cash', { options = { 'cash', 'bank', 'crypto' } }), {
            advanced = false,
            label = 'Accepted payment accounts',
            description = 'Lists the player money accounts accepted for fuel and charging purchases, in display priority order. Every entry must be a supported qbcore account; removing an account prevents players from selecting it at the pump.',
        })
    Config.pricePerUnit = Kora.config.object({
        fuel = Kora.config.number(Config.pricePerUnit.fuel, {
            min = 0,
            step = 0.01,
            label = 'Petrol price per unit',
            description = 'Sets the amount charged from the selected player account for each native fuel-level unit added to a petrol vehicle. The server calculates the final price from the vehicle’s authoritative current level.',
        }),
        charge = Kora.config.number(Config.pricePerUnit.charge, {
            min = 0,
            step = 0.01,
            label = 'Electric charge price per unit',
            description = 'Sets the amount charged from the selected player account for each native fuel-level unit added to an electric vehicle’s battery. The server calculates the final price from the authoritative vehicle level.',
        }),
    })
    Config.consumeInterval = Kora.config.integer(Config.consumeInterval, {
        advanced = true,
        min = 100,
        label = 'Fuel-consumption update interval',
        description = 'Sets how often the client calculates and applies fuel or battery drain, in milliseconds. Lower values make the gauge update more frequently but increase client work; consumption is time-scaled so changing this interval does not change the overall drain rate.',
    })
    Config.idleConsumptionMultiplier = Kora.config.number(Config.idleConsumptionMultiplier, {
        min = 0,
        max = 1,
        step = 0.01,
        label = 'Idle consumption multiplier',
        description = 'Scales the configured vehicle-class consumption rate while the engine is running at idle. A value of 0 disables idle drain, 1 uses the full reference-speed rate, and values between them apply a proportional fraction.',
    })
    Config.speedReference = Kora.config.number(Config.speedReference, {
        advanced = true,
        min = 0.1,
        step = 0.5,
        label = 'Consumption reference speed',
        description = 'Defines the vehicle speed, in metres per second, at which the authored class consumption rate is used without additional speed scaling. The default 45 m/s is approximately 162 km/h or 101 mph.',
    })
    Config.maxSpeedConsumptionMultiplier = Kora.config.number(Config.maxSpeedConsumptionMultiplier, {
        min = 1,
        step = 0.1,
        label = 'Maximum speed consumption multiplier',
        description = 'Caps the amount by which speed can multiply the base vehicle-class consumption rate. This prevents unusually fast or modified vehicles from producing unbounded fuel drain.',
    })
    Config.consumePerSecond = Kora.config.map(Config.consumePerSecond, Kora.config.number(0.0, {
        min = 0.0,
        step = 0.001,
    }), {
        keyType = 'mixed',
        requiredKeys = { 'default' },
        label = 'Fuel consumption by vehicle class',
        description = 'Sets the fuel or battery charge consumed each second at the reference speed for every GTA vehicle class. Numeric keys are GTA class IDs; the “default” row is used when a class has no explicit rate. Values must be zero or greater, and changes take effect after qbfuel restarts.',
    })
    Config.electricVehicles = Kora.config.list(Config.electricVehicles,
        Kora.config.string('', { minLength = 1 }), {
            label = 'Electric vehicle models',
            description = 'Lists GTA and add-on vehicle spawn names that use battery charge rather than petrol. The same list controls pump wording, server-side service validation, fuel drain, and the HUD fuel presentation.',
        })
    Config.electric.useNative = Kora.config.boolean(Config.electric.useNative, {
        label = 'Detect electric vehicles with the game native',
        description = 'Also asks the game whether a vehicle is electric, so new GTA electric models show the charge icon and Charge vehicle pump wording without being listed. Pricing and server validation still use the electric vehicle model list. Has no effect on game builds without the native.',
    })
    Config.pumpModels = Kora.config.list(Config.pumpModels,
        Kora.config.string('', { minLength = 1 }), {
            label = 'Fuel pump models',
            description = 'Lists world prop model names that players can target to refuel or charge a nearby vehicle. Add compatible pump or charger props here when using custom map assets.',
        })
    Config.stations = Kora.config.list(Config.stations,
        Kora.config.vector3(vector3(0.0, 0.0, 0.0)), {
            label = 'Fuel station coordinates',
            description = 'Lists the world positions where the server permits paid refuelling or charging. The server checks these coordinates before taking payment, so this list is an authorization boundary as well as interaction data.',
        })
    Config.blips.enabled = Kora.config.boolean(Config.blips.enabled, {
        label = 'Show gas station blips',
        description = 'Shows a map blip at every coordinate in the fuel station list. Turn this off if another resource already draws fuel station blips.',
    })
    Config.blips.nearestOnly = Kora.config.boolean(Config.blips.nearestOnly, {
        label = 'Show only the nearest gas station blip',
        description = 'Shows a single gas station blip, for the station nearest the player, instead of one for every station. The blip moves to the new nearest station as the player travels.',
    })
    Config.blips.mergeRadius = Kora.config.number(Config.blips.mergeRadius, {
        min = 0.0,
        step = 1.0,
        label = 'Gas station blip merge radius',
        description = 'Stations closer together than this many metres share a single map blip, so forecourts listed twice are not drawn as pairs. Set to 0 to draw a blip for every listed station.',
    })
    Config.blips.sprite = Kora.config.integer(Config.blips.sprite, {
        min = 0,
        label = 'Gas station blip sprite',
        description = 'Sets the GTA blip sprite ID used for gas stations. The default 361 is the petrol pump icon.',
    })
    Config.blips.colour = Kora.config.integer(Config.blips.colour, {
        min = 0,
        label = 'Gas station blip colour',
        description = 'Sets the GTA blip colour ID used for gas stations. The default 1 is red.',
    })
    Config.blips.scale = Kora.config.number(Config.blips.scale, {
        min = 0.1,
        step = 0.1,
        label = 'Gas station blip scale',
        description = 'Sets the size of gas station blips on the map. Values around 0.6 keep them unobtrusive.',
    })
    Config.blips.shortRange = Kora.config.boolean(Config.blips.shortRange, {
        label = 'Short-range gas station blips',
        description = 'When enabled, blips only show near the player or on the full map instead of across the whole minimap.',
    })
    Config.blips.label = Kora.config.string(Config.blips.label, {
        minLength = 1,
        label = 'Gas station blip label',
        description = 'Sets the text shown for gas station blips on the map legend.',
    })
    Config.charging.enabled = Kora.config.boolean(Config.charging.enabled, {
        label = 'Enable EV charging stations',
        description = 'Turns on the dedicated electric vehicle charging stations. When off, or when no stations are listed, petrol pumps keep charging electric vehicles as they did before charging stations existed.',
    })
    Config.charging.allowAtPumps = Kora.config.boolean(Config.charging.allowAtPumps, {
        label = 'Charge EVs at petrol pumps',
        description = 'When off, an electric vehicle at a petrol pump is told to use a charging station instead of being offered a charge. Turn this on to let pumps charge electric vehicles at the standard electric charge price as well. Only applies while charging stations are enabled.',
    })
    Config.charging.pumpMessage = Kora.config.string(Config.charging.pumpMessage, {
        minLength = 1,
        label = 'Petrol pump message for electric vehicles',
        description = 'Sets the notification shown to a player who uses a petrol pump with an electric vehicle when pumps do not charge EVs. The nearest charging station and its distance are appended automatically.',
    })
    Config.charging.pricePerPercent = Kora.config.number(Config.charging.pricePerPercent, {
        min = 0,
        step = 0.01,
        label = 'Charging station price per percent',
        description = 'Sets the amount charged from the selected player account for each percent of battery charge added at a charging station. The server calculates the price from the vehicle’s authoritative current level.',
    })
    Config.charging.secondsPerPercent = Kora.config.number(Config.charging.secondsPerPercent, {
        min = 0,
        step = 0.01,
        label = 'Charging time per percent (seconds)',
        description = 'Sets how many seconds each percent of missing charge adds to the charging progress at a charging station. The minimum service duration still applies.',
    })
    Config.charging.serviceRadius = Kora.config.number(Config.charging.serviceRadius, {
        advanced = true,
        min = 1.0,
        step = 0.5,
        label = 'Charging station service radius',
        description = 'Sets the maximum distance in metres between the player and a charging station before the server refuses a paid charge. Keep it larger than the station target zones so the whole parking area is covered.',
    })
    Config.charging.zoneRadius = Kora.config.number(Config.charging.zoneRadius, {
        min = 0.5,
        step = 0.25,
        label = 'Default charger target radius',
        description = 'Sets the radius in metres of the target zone around a charging station’s charger when the station does not set its own. Players aim at a point inside this sphere to see the charge option.',
    })
    Config.charging.interactDistance = Kora.config.number(Config.charging.interactDistance, {
        min = 0.5,
        step = 0.5,
        label = 'Charging station interaction distance',
        description = 'Sets how close in metres the player must be to the charger for the charge option to appear.',
    })
    Config.charging.prop = Kora.config.object({
        enabled = Kora.config.boolean(Config.charging.prop.enabled, {
            label = 'Spawn charger props',
            description = 'Spawns a charger prop at every charging station while the player is nearby. Turn this off to keep stations as target zones only.',
        }),
        model = Kora.config.string(Config.charging.prop.model, {
            minLength = 1,
            label = 'Charger prop model',
            description = 'Sets the prop model spawned at each charging station. GTA V has no vanilla EV charger, so the default is the pay-and-display machine; use a streamed charger model name for a real charger.',
        }),
        headingOffset = Kora.config.number(Config.charging.prop.headingOffset, {
            min = -360.0,
            max = 360.0,
            step = 1.0,
            label = 'Charger prop heading offset',
            description = 'Adds this many degrees to every station heading, for charger models whose front does not face the station heading.',
        }),
        spawnDistance = Kora.config.number(Config.charging.prop.spawnDistance, {
            min = 10.0,
            step = 5.0,
            label = 'Charger prop spawn distance',
            description = 'Sets how close in metres the player must be to a charging station before its charger prop is spawned. The prop is deleted again when the player moves further away.',
        }),
        snapToGround = Kora.config.boolean(Config.charging.prop.snapToGround, {
            label = 'Snap charger props to the ground',
            description = 'Settles each charger prop onto the ground after it spawns, so a station whose height is slightly off still stands on the ground.',
        }),
        targetHeight = Kora.config.number(Config.charging.prop.targetHeight, {
            min = 0.0,
            step = 0.1,
            label = 'Charger target height',
            description = 'Sets how many metres above the station coordinates the charge target zone is centred, normally around the middle of the charger prop.',
        }),
    }, { advanced = true })
    Config.charging.propModels = Kora.config.list(Config.charging.propModels,
        Kora.config.string('', { minLength = 1 }), {
            label = 'Extra charger prop models',
            description = 'Lists optional world prop model names, such as custom map EV chargers, that also offer the charge option when they are inside a charging station’s service radius.',
        })
    Config.charging.stations = Kora.config.list(Config.charging.stations,
        Kora.config.object({
            label = Kora.config.string('Charging station', { minLength = 1 }),
            coords = Kora.config.vector3(vector3(0.0, 0.0, 0.0)),
            heading = Kora.config.number(0.0, { min = -360.0, max = 360.0, step = 0.5 }),
            offset = Kora.config.optional(nil, Kora.config.vector3(vector3(0.0, 0.0, 0.0))),
            radius = Kora.config.optional(nil, Kora.config.number(0.0, { min = 0.0, step = 0.25 })),
            hideModel = Kora.config.optional(nil, Kora.config.string('')),
        }), {
            label = 'EV charging stations',
            description = 'Lists the charging stations: a name shown on the map and in messages, the ground position and heading of the charger, an optional world-space offset in metres, an optional target radius (0 uses the default) and an optional world prop model to hide where the charger stands. The server only takes payment for charging near these positions. A station with an invalid field is skipped with a console warning; the others still load.',
        })
    Config.charging.blips.enabled = Kora.config.boolean(Config.charging.blips.enabled, {
        label = 'Show charging station blips',
        description = 'Shows a map blip at every charging station. Turn this off if another resource already draws them.',
    })
    Config.charging.blips.sprite = Kora.config.integer(Config.charging.blips.sprite, {
        min = 0,
        label = 'Charging station blip sprite',
        description = 'Sets the GTA blip sprite ID used for charging stations. The default 354 is the EV charging icon, which keeps them distinct from the petrol pump blips.',
    })
    Config.charging.blips.colour = Kora.config.integer(Config.charging.blips.colour, {
        min = 0,
        label = 'Charging station blip colour',
        description = 'Sets the GTA blip colour ID used for charging stations. The default is 46.',
    })
    Config.charging.blips.showStationName = Kora.config.boolean(Config.charging.blips.showStationName, {
        label = 'Name charging stations on the map',
        description = 'Adds the station name, such as Little Seoul, after the blip label in the pause-map legend. Turn this off to show only the blip label.',
    })
    Config.charging.blips.category = Kora.config.string(Config.charging.blips.category, {
        minLength = 1,
        advanced = true,
        label = 'Charging station blip category',
        description = 'Sets the fixed kora_lib pause-map category the charging station blips are listed under, for example Fuel or Garage. Players can hide the whole category with /blips.',
    })
    Config.charging.worldIcon = Kora.config.boolean(Config.charging.worldIcon, {
        label = 'Show world icon at charging stations',
        description = 'Draws the kora_target interaction icon at each charger when the player is nearby. Off by default because the charger prop marks the spot; the interaction works the same either way.',
    })
    Config.charging.blips.nearestOnly = Kora.config.boolean(Config.charging.blips.nearestOnly, {
        label = 'Show only the nearest charging station blip',
        description = 'Shows a single charging station blip, for the station nearest the player, instead of one for every station. The blip moves to the new nearest station as the player travels.',
    })
    Config.charging.blips.scale = Kora.config.number(Config.charging.blips.scale, {
        min = 0.1,
        step = 0.1,
        label = 'Charging station blip scale',
        description = 'Sets the size of charging station blips on the map.',
    })
    Config.charging.blips.shortRange = Kora.config.boolean(Config.charging.blips.shortRange, {
        label = 'Short-range charging station blips',
        description = 'When enabled, charging station blips only show near the player or on the full map instead of across the whole minimap.',
    })
    Config.charging.blips.label = Kora.config.string(Config.charging.blips.label, {
        minLength = 1,
        label = 'Charging station blip label',
        description = 'Sets the text shown for charging station blips on the map legend.',
    })
    Config = Kora.config.adopt(Config)

    -- Saved overrides and the client's server snapshot can carry vectors as
    -- plain {x, y, z} tables (JSON/msgpack); clean those the same way.
    Config.charging.stations = Fuel.normalizeChargingStations(Config.charging.stations)
    if Kora.config.onChange then
        Kora.config.onChange('charging.stations', function(stations)
            Config.charging.stations = Fuel.normalizeChargingStations(stations)
        end)
    end
end
