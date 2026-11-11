-- Charging station loading: every vector shape, per-station skipping, and the
-- real config.lua going through kora_lib's own config consumer.
local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

-- A CfxLua-like vector3: type() reports 'vector3' (what kora_lib's schema
-- checks), and vec3 is the same constructor.
local rawType = type
local Vector = {}
Vector.__index = function(v, key) return rawget(v, '_' .. key) end
Vector.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
function vector3(x, y, z) return setmetatable({ _x = x + 0.0, _y = y + 0.0, _z = z + 0.0 }, Vector) end
vec3 = vector3
function type(value)
    if rawType(value) == 'table' and getmetatable(value) == Vector then return 'vector3' end
    return rawType(value)
end
joaat = function(model) return 'hash:' .. model end

local warnings = {}
local realPrint = print
print = function(message)
    message = tostring(message)
    if message:find('[kora_fuel]', 1, true) then warnings[#warnings + 1] = message else realPrint(message) end
end

local function isVector(value, x, y, z)
    return type(value) == 'vector3' and value.x == x and value.y == y and value.z == z
end

dofile(repoRoot .. 'shared/stations.lua')

harness.test('every accepted vector shape becomes a vector3', function()
    local shapes = {
        vector3 = vector3(1, 2, 3),
        vec3 = vec3(1, 2, 3),
        xyz = { x = 1, y = 2, z = 3 },
        array = { 1, 2, 3 },
        saved = { __koraLibConfigType = 'vector3', x = 1.0, y = 2.0, z = 3.0 },
    }
    for name, shape in pairs(shapes) do
        harness.assertTrue(isVector(Fuel.toVector3(shape), 1.0, 2.0, 3.0), name .. ' should convert')
    end
    harness.assertTrue(Fuel.toVector3(shapes.vector3) == shapes.vector3, 'a vector3 is passed through')
    for name, bad in pairs({ number = 0.0, text = '1,2,3', short = { 1, 2 }, words = { x = 'a', y = 2, z = 3 },
        nan = { 0 / 0, 0, 0 }, inf = { x = math.huge, y = 0, z = 0 }, empty = {} }) do
        harness.assertEqual(Fuel.toVector3(bad), nil, name .. ' should be refused')
    end
end)

harness.test('coords and offset in every shape load as vector3', function()
    warnings = {}
    local stations = Fuel.normalizeChargingStations({
        { label = 'A', coords = vector3(1, 2, 3), offset = vector3(0, 0, 1) },
        { label = 'B', coords = vec3(1, 2, 3), offset = vec3(0, 0, 1) },
        { label = 'C', coords = { x = 1, y = 2, z = 3 }, offset = { x = 0, y = 0, z = 1 } },
        { label = 'D', coords = { 1, 2, 3 }, offset = { 0, 0, 1 }, heading = 90 },
        { label = 'E', coords = { 1, 2, 3 } },
    })
    harness.assertEqual(#stations, 5)
    harness.assertEqual(#warnings, 0, 'no warnings for valid shapes')
    for _, station in ipairs(stations) do
        harness.assertTrue(isVector(station.coords, 1.0, 2.0, 3.0), station.label .. ' coords')
        if station.label ~= 'E' then
            harness.assertTrue(isVector(station.offset, 0.0, 0.0, 1.0), station.label .. ' offset')
        end
    end
    harness.assertEqual(stations[5].offset, nil, 'a missing offset stays missing')
    harness.assertEqual(stations[5].heading, 0.0, 'a missing heading is 0')
    harness.assertEqual(stations[4].heading, 90.0)
end)

harness.test('an invalid station is skipped with one warning and the others load', function()
    warnings = {}
    local stations = Fuel.normalizeChargingStations({
        { label = 'Good 1', coords = vector3(1, 2, 3) },
        { label = 'Bad offset', coords = vector3(4, 5, 6), offset = 0.0 },
        { label = 'No coords', heading = 0.0 },
        'not a station',
        { label = 'Good 2', coords = { 7, 8, 9 }, radius = -1 },
        { label = 'Good 3', coords = { 7, 8, 9 }, hideModel = 'prop_gas_airunit01' },
    })
    harness.assertEqual(#stations, 2)
    harness.assertEqual(stations[1].label, 'Good 1')
    harness.assertEqual(stations[2].label, 'Good 3')
    harness.assertEqual(#warnings, 4, 'one warning per skipped station')
    harness.assertTrue(warnings[1]:find('#2 "Bad offset": offset must be', 1, true) ~= nil, warnings[1])
    harness.assertTrue(warnings[2]:find('#3 "No coords": coords must be', 1, true) ~= nil, warnings[2])
    harness.assertTrue(warnings[3]:find('#4 without a label: entry must be a table', 1, true) ~= nil, warnings[3])
    harness.assertTrue(warnings[4]:find('#5 "Good 2": radius must be', 1, true) ~= nil, warnings[4])
end)

-- config.lua through kora_lib's real config consumer, as the server and client
-- load it (Kora.config.adopt + config.local.lua overrides).
local consumerPath = repoRoot .. '../kora_lib/modules/config/consumer.lua'
local consumerSource = io.open(consumerPath, 'r')
consumerSource = assert(consumerSource, 'kora_lib must sit next to kora_fuel'):read('a')
local configSource = assert(io.open(repoRoot .. 'config.lua', 'r')):read('a')

local files, netEvents, snapshotRequest = {}, {}, nil
local server = true
GetCurrentResourceName = function() return 'kora_fuel' end
IsDuplicityVersion = function() return server end
LoadResourceFile = function(_, path) return files[path] end
SaveResourceFile = function(_, path, contents) files[path] = contents return true end
RegisterNetEvent = function(name, handler) netEvents[name] = handler end
TriggerServerEvent = function(_, _, requestId) snapshotRequest = requestId end

local function loadConfig(source, override, isServer)
    Config, warnings, netEvents, server = nil, {}, {}, isServer ~= false
    files = { ['config.local.lua'] = override }
    local factory = assert(load(consumerSource, '@kora_lib/modules/config/consumer.lua'))()
    Kora = { config = factory({ config_register = function() return true end }) }
    local chunk = assert(load(source or configSource, '@kora_fuel/config.lua'))
    return pcall(chunk)
end

local function allVectors(stations)
    for _, station in ipairs(stations) do
        if type(station.coords) ~= 'vector3' then return false end
        if station.offset ~= nil and type(station.offset) ~= 'vector3' then return false end
    end
    return true
end

harness.test('the default config loads through kora_lib\'s config consumer', function()
    local ok, err = loadConfig()
    harness.assertTrue(ok, tostring(err))
    harness.assertEqual(#Config.charging.stations, 13)
    harness.assertEqual(#warnings, 0, 'every default station is valid')
    harness.assertTrue(allVectors(Config.charging.stations), 'default stations are vector3')
    harness.assertEqual(Config.charging.stations[1].label, 'Murrieta Heights')
    harness.assertEqual(Config.charging.stations[1].offset, nil)
end)

harness.test('the 09:36 failure: a required offset schema is what threw', function()
    local schema = configSource:gsub('offset = Kora%.config%.optional%(nil, (Kora%.config%.vector3%b())%)', 'offset = %1')
    harness.assertTrue(schema ~= configSource, 'test setup: schema line found')
    local ok, err = loadConfig(schema)
    harness.assertFalse(ok)
    harness.assertTrue(tostring(err):find('charging stations item 1 offset must be a vector3', 1, true) ~= nil, tostring(err))
end)

harness.test('authored array/table vectors and a bad station no longer fail the config', function()
    local source, first = configSource:gsub("(label = 'Murrieta Heights', )coords = vector3%(([^)]*)%)",
        '%1coords = { %2 }, offset = { 0.0, 0.0, 0.0 }', 1)
    local _, second
    source, second = source:gsub("(label = 'La Puerta', )coords = vector3%(([^)]*)%)", '%1coords = { x = 1.0 }', 1)
    harness.assertEqual(first + second, 2, 'test setup: stations found')
    local ok, err = loadConfig(source)
    harness.assertTrue(ok, tostring(err))
    harness.assertEqual(#Config.charging.stations, 12)
    harness.assertEqual(#warnings, 1)
    harness.assertTrue(warnings[1]:find('#2 "La Puerta": coords', 1, true) ~= nil, warnings[1])
    harness.assertTrue(isVector(Config.charging.stations[1].coords, 1194.54, -1391.44, 34.40), 'array coords converted')
    harness.assertTrue(allVectors(Config.charging.stations))
    harness.assertEqual(Config.blips.label ~= nil, true, 'the rest of the config loaded')
end)

harness.test('saved overrides with plain {x, y, z} tables load as vector3', function()
    local override = [[return { charging = { stations = {
        { label = 'Saved', coords = { x = 10.0, y = 20.0, z = 30.0 }, heading = 0.0, offset = { x = 0.0, y = 1.0, z = 0.0 } },
        { label = 'Marked', coords = { __koraLibConfigType = 'vector3', x = 1.0, y = 2.0, z = 3.0 }, heading = 45.0 },
    } } }]]
    local ok, err = loadConfig(nil, override)
    harness.assertTrue(ok, tostring(err))
    harness.assertEqual(#Config.charging.stations, 2)
    harness.assertTrue(isVector(Config.charging.stations[1].coords, 10.0, 20.0, 30.0))
    harness.assertTrue(isVector(Config.charging.stations[1].offset, 0.0, 1.0, 0.0))
    harness.assertTrue(isVector(Config.charging.stations[2].coords, 1.0, 2.0, 3.0))
end)

harness.test('the client snapshot (JSON round trip) is normalised too', function()
    local ok, err = loadConfig(nil, nil, false)
    harness.assertTrue(ok, tostring(err))
    local onSnapshot = netEvents['kora_lib:client:configSnapshot']
    harness.assertTrue(rawType(onSnapshot) == 'function', 'consumer listens for snapshots')
    onSnapshot('kora_fuel', { charging = { stations = {
        { label = 'From server', coords = { x = 5.0, y = 6.0, z = 7.0 }, heading = 10.0, offset = { x = 0.0, y = 0.0, z = 0.5 } },
    } } }, 2, snapshotRequest)
    harness.assertEqual(#Config.charging.stations, 1)
    harness.assertEqual(Config.charging.stations[1].label, 'From server')
    harness.assertTrue(isVector(Config.charging.stations[1].coords, 5.0, 6.0, 7.0))
    harness.assertTrue(isVector(Config.charging.stations[1].offset, 0.0, 0.0, 0.5))
end)

print = realPrint
harness.report('stations')
