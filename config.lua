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
    'tezeract', 'virtue', 'vivanite2', 'voltic', 'voltic2', 'xtreme',
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
-- The default list is the vanilla map's petrol-station network. EVs can charge
-- at these service points as well, avoiding a map dependency for charger props.
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
-- of them; set it to 0 to draw one blip per entry. Example perStation:
--   perStation = { [3] = { enabled = false }, [5] = { label = "Airfield Fuel" } }
Config.blips = {
    enabled = true,
    sprite = 361,
    colour = 1,
    scale = 0.6,
    shortRange = true,
    label = 'Gas Station',
    mergeRadius = 30.0,
    perStation = {},
}

-- Dedicated EV charging stations. Each entry is a spot where an electric
-- vehicle can park and charge: the "Charge vehicle" target option appears when
-- aiming (hold Alt) at a point within `radius` metres of `coords`, and only
-- while an electric vehicle is within Config.vehicleSearchDistance of the
-- player. The server also checks the player is within `serviceRadius` of a
-- station before taking payment, so this list is an authorization boundary.
-- Coordinates are road and car-park positions already used elsewhere on this
-- server (kora_garages parking bays, kora_taxi road stops); `coords` sits about
-- half a metre above the ground. Add, move or remove entries freely; `radius`
-- is optional (0 or omitted uses `zoneRadius`).
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
    -- Default target zone radius and the maximum aim distance (metres).
    zoneRadius = 4.0,
    interactDistance = 5.0,
    -- Optional charger prop models (custom map assets) that also offer the
    -- charge option within a station's service radius. Empty by default: GTA V
    -- has no vanilla EV charger prop, so the default stations are zone-only.
    propModels = {},
    stations = {
        { label = 'Legion Square Parking', coords = vector3(210.64, -791.31, 30.4), radius = 4.0 },
        { label = 'Alta Street Parking', coords = vector3(270.94, -322.96, 44.4), radius = 4.0 },
        { label = 'Sandy Shores Parking', coords = vector3(1735.0, 3714.3, 34.6), radius = 4.0 },
        { label = 'Rockford Plaza', coords = vector3(-586.48, -255.96, 36.4), radius = 5.0 },
        { label = 'Vespucci Canals', coords = vector3(-1184.3, -1304.16, 5.7), radius = 5.0 },
        { label = 'Del Perro Pier', coords = vector3(-1613.99, -1015.82, 13.6), radius = 5.0 },
        { label = 'Los Santos Airport', coords = vector3(-1053.23, -2716.2, 14.2), radius = 5.0 },
        { label = 'Chumash Plaza', coords = vector3(-3232.7, 1013.16, 12.6), radius = 5.0 },
        { label = 'Grapeseed Main Street', coords = vector3(1662.55, 4876.71, 42.5), radius = 5.0 },
        { label = 'Paleto Bay', coords = vector3(-9.51, 6529.67, 31.9), radius = 5.0 },
    },
    -- Map blips, one per station. Blip colours are GTA palette ids.
    blips = {
        enabled = true,
        sprite = 361,
        colour = 2,
        scale = 0.6,
        shortRange = true,
        label = 'EV Charging Station',
    },
}

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
        step = 0.5,
        label = 'Default charging zone radius',
        description = 'Sets the radius in metres of a charging station’s target zone when the station does not set its own. Players aim at a point inside this sphere to see the charge option.',
    })
    Config.charging.interactDistance = Kora.config.number(Config.charging.interactDistance, {
        min = 0.5,
        step = 0.5,
        label = 'Charging station interaction distance',
        description = 'Sets how close in metres the player must be to the aimed point for the charge option to appear.',
    })
    Config.charging.propModels = Kora.config.list(Config.charging.propModels,
        Kora.config.string('', { minLength = 1 }), {
            label = 'Charger prop models',
            description = 'Lists optional world prop model names, such as custom map EV chargers, that offer the charge option when they are inside a charging station’s service radius. Leave empty to use the station target zones only.',
        })
    Config.charging.stations = Kora.config.list(Config.charging.stations,
        Kora.config.object({
            label = Kora.config.string('Charging station', { minLength = 1 }),
            coords = Kora.config.vector3(vector3(0.0, 0.0, 0.0)),
            radius = Kora.config.number(0.0, { min = 0.0, step = 0.5 }),
        }), {
            label = 'EV charging stations',
            description = 'Lists the charging stations: a name shown on the map and in messages, the world position about half a metre above the ground, and an optional target zone radius in metres (0 uses the default zone radius). The server only takes payment for charging near these positions.',
        })
    Config.charging.blips.enabled = Kora.config.boolean(Config.charging.blips.enabled, {
        label = 'Show charging station blips',
        description = 'Shows a map blip at every charging station. Turn this off if another resource already draws them.',
    })
    Config.charging.blips.sprite = Kora.config.integer(Config.charging.blips.sprite, {
        min = 0,
        label = 'Charging station blip sprite',
        description = 'Sets the GTA blip sprite ID used for charging stations. The default 361 is the fuel icon; the colour tells them apart from gas stations.',
    })
    Config.charging.blips.colour = Kora.config.integer(Config.charging.blips.colour, {
        min = 0,
        label = 'Charging station blip colour',
        description = 'Sets the GTA blip colour ID used for charging stations. The default 2 is green.',
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
end
