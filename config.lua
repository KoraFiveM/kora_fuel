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

-- GTA's electric models. Add addon EV spawn names here; the model check is
-- shared by the server, fuel drain, and HUD, so every part stays in agreement.
Config.electricVehicles = {
    'airtug', 'caddy', 'caddy2', 'caddy3', 'cyclone', 'cyclone2',
    'dilettante', 'dilettante2', 'imorgon', 'iwagen', 'khamelion',
    'neon', 'omnisegt', 'powersurge', 'raiden', 'rcbandito', 'surge',
    'tezeract', 'voltic', 'voltic2',
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
-- `sprite`, `colour`, `scale`, `shortRange` or `label` overrides, e.g.
--   perStation = { [3] = { enabled = false }, [5] = { label = "Airfield Fuel" } }
Config.blips = {
    enabled = true,
    sprite = 361,
    colour = 1,
    scale = 0.6,
    shortRange = true,
    label = 'Gas Station',
    perStation = {},
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
    Config = Kora.config.adopt(Config)
end
