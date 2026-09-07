Config = Config or {}

-- Both petrol and battery charge use GTA's native 0-100 vehicle fuel level.
-- That makes charge survive vehicle streaming and lets qbgarages persist it
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

-- One second of driving consumes this amount at full RPM. The class table is
-- intentionally easy to tune; omitted classes use `default`.
Config.consumeInterval = 1000
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
    'prop_gas_pump_1d', 'prop_vintage_pump',
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

-- Registers this resource-owned configuration with qblib without changing its public Config table.
if QB and QB.config and QB.config.adopt then Config = QB.config.adopt(Config) end
