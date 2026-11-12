local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')

_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.joaat = function(model)
    local hash = 0
    for i = 1, #model do hash = hash * 31 + model:byte(i) end
    return hash
end

dofile(repoRoot .. 'shared/stations.lua')
dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')

harness.test('electric-model classification includes stock EVs and excludes petrol cars', function()
    harness.assertTrue(Fuel.isElectricModel('neon'), 'neon should be electric')
    harness.assertFalse(Fuel.isElectricModel('adder'), 'adder should not be electric')
    harness.assertTrue(Fuel.isElectricModel(joaat('raiden')), 'hashed electric models should work')
end)

harness.test('electric list covers newer EVs and has no duplicates', function()
    for _, m in ipairs({ 'envisage', 'virtue', 'coureur', 'buffalo5', 'inductor2', 'estride', 'cyclone2' }) do
        harness.assertTrue(Fuel.isElectricModel(m), m .. ' should be electric')
    end
    local seen = {}
    for _, m in ipairs(Config.electricVehicles) do
        harness.assertFalse(seen[m] == true, m .. ' listed twice')
        seen[m] = true
    end
    harness.assertTrue(Config.electric.useNative, 'native detection defaults on')
end)

harness.test('replacing the electric list (late client config) is picked up', function()
    local authored = Config.electricVehicles
    harness.assertFalse(Fuel.isElectricModel('adder'))
    Config.electricVehicles = { 'adder', ' Neon ' }
    harness.assertTrue(Fuel.isElectricModel('adder'), 'an owner-added model should count')
    harness.assertFalse(Fuel.isElectricModel('envisage'), 'a removed model should stop counting')
    Config.electricVehicles = authored
    harness.assertTrue(Fuel.isElectricModel('envisage'))
    harness.assertFalse(Fuel.isElectricModel('adder'))
end)

harness.test('every vehicle on the requested EV list is electric', function()
    for _, m in ipairs({ 'voltic', 'voltic2', 'caddy', 'caddy2', 'caddy3', 'surge', 'iwagen', 'raiden', 'airtug', 'neon',
        'omnisegt', 'cyclone', 'tezeract', 'rcbandito', 'imorgon', 'dilettante', 'dilettante2', 'khamelion', 'suzume',
        'inductor', 'inductor2', 'powersurge', 'buffalo5', 'envisage', 'coureur', 'pipistrello', 'virtue', 'xtreme',
        'vivanite2', 'estride' }) do
        harness.assertTrue(Fuel.isElectricModel(m), m .. ' should be electric')
    end
end)

harness.test('fuel level is clamped to the native 0-100 range', function()
    harness.assertEqual(Fuel.clampLevel(-5), 0)
    harness.assertEqual(Fuel.clampLevel(150), Config.maxLevel)
    harness.assertEqual(Fuel.clampLevel(42.5), 42.5)
end)

harness.test('engine idle use is lower than moving use for the same vehicle class', function()
    local idleUse = Fuel.calculateConsumption(7, 0, 1000)
    local movingUse = Fuel.calculateConsumption(7, Config.speedReference, 1000)

    harness.assertTrue(idleUse > 0, 'an idling engine should consume fuel')
    harness.assertTrue(movingUse > idleUse, 'moving should consume more than idling')
    harness.assertEqual(movingUse, Config.consumePerSecond[7])
end)

harness.test('vehicle classes retain independent consumption rates', function()
    local compactUse = Fuel.calculateConsumption(0, Config.speedReference, 1000)
    local superUse = Fuel.calculateConsumption(7, Config.speedReference, 1000)

    harness.assertEqual(compactUse, Config.consumePerSecond[0])
    harness.assertEqual(superUse, Config.consumePerSecond[7])
    harness.assertTrue(superUse > compactUse)
end)

harness.test('only configured payment accounts are accepted', function()
    harness.assertTrue(Fuel.isPaymentAccount('cash'))
    harness.assertTrue(Fuel.isPaymentAccount('bank'))
    harness.assertFalse(Fuel.isPaymentAccount('crypto'))
end)

harness.test('default charging stations are labelled, unique and carry usable coordinates', function()
    harness.assertTrue(Fuel.chargingEnabled())
    harness.assertTrue(#Config.charging.stations >= 5, 'a handful of stations is expected')
    local seen = {}
    for _, station in ipairs(Config.charging.stations) do
        harness.assertTrue(type(station.label) == 'string' and #station.label > 0, 'station needs a label')
        harness.assertFalse(seen[station.label] == true, station.label .. ' listed twice')
        seen[station.label] = true
        for _, axis in ipairs({ 'x', 'y', 'z' }) do
            harness.assertTrue(type(station.coords[axis]) == 'number', station.label .. ' needs numeric ' .. axis)
        end
    end
end)

harness.test('default chargers carry a heading and replace the forecourt air pump', function()
    for _, station in ipairs(Config.charging.stations) do
        harness.assertTrue(type(station.heading) == 'number', station.label .. ' needs a heading')
        harness.assertEqual(station.hideModel, 'prop_gas_airunit01', station.label .. ' stands where the air pump was')
        harness.assertFalse(station.label:find('Parking', 1, true) ~= nil, 'chargers are at petrol stations, not car parks')
    end
end)

harness.test('chargerPosition applies the optional world-space offset everywhere', function()
    local station = { label = 'T', coords = vector3(10.0, 20.0, 30.0) }
    harness.assertEqual(Fuel.chargerPosition(station), station.coords, 'no offset keeps the coords')
    station.offset = vector3(0.0, 0.0, 0.0)
    harness.assertEqual(Fuel.chargerPosition(station), station.coords)
    station.offset = vector3(1.5, -2.0, 0.25)
    local at = Fuel.chargerPosition(station)
    harness.assertEqual(at.x, 11.5)
    harness.assertEqual(at.y, 18.0)
    harness.assertEqual(at.z, 30.25)

    local saved = Config.charging.stations
    Config.charging.stations = { station }
    local found, distance = Fuel.nearestCharger({ x = 11.5, y = 18.0, z = 30.25 }, 0.1)
    harness.assertEqual(found, station, 'nearestCharger measures from the offset position')
    harness.assertEqual(distance, 0.0)
    Config.charging.stations = saved
end)

harness.test('nearestCharger honours the maximum distance', function()
    local first = Config.charging.stations[1]
    local at = { x = first.coords.x + 3.0, y = first.coords.y, z = first.coords.z }
    local station, distance = Fuel.nearestCharger(at, Config.charging.serviceRadius)
    harness.assertEqual(station, first)
    harness.assertTrue(math.abs(distance - 3.0) < 1e-6)
    local far = { x = 99999.0, y = 99999.0, z = 0.0 }
    harness.assertEqual(Fuel.nearestCharger(far, Config.charging.serviceRadius), nil)
    harness.assertTrue(Fuel.nearestCharger(far) ~= nil, 'without a limit the nearest station is still reported')
end)

harness.test('pumps refuse EVs only while a charging network is enabled and pumps are not allowed', function()
    harness.assertFalse(Fuel.pumpsAcceptElectric(), 'default: EVs are sent to charging stations')
    Config.charging.allowAtPumps = true
    harness.assertTrue(Fuel.pumpsAcceptElectric())
    Config.charging.allowAtPumps = false
    Config.charging.enabled = false
    harness.assertTrue(Fuel.pumpsAcceptElectric(), 'no network, pumps keep charging')
    Config.charging.enabled = true
    local stations = Config.charging.stations
    Config.charging.stations = {}
    harness.assertTrue(Fuel.pumpsAcceptElectric(), 'no stations listed, pumps keep charging')
    Config.charging.stations = stations
end)

harness.test('charging stations use their own price and rate; pumps and petrol are unchanged', function()
    local saved = { Config.charging.pricePerPercent, Config.charging.secondsPerPercent }
    Config.charging.pricePerPercent, Config.charging.secondsPerPercent = 2.0, 0.5
    harness.assertEqual(Fuel.price('charge', 40, 'charger'), 80)
    harness.assertEqual(Fuel.price('charge', 40, 'pump'), math.ceil(40 * Config.pricePerUnit.charge))
    harness.assertEqual(Fuel.price('charge', 40), math.ceil(40 * Config.pricePerUnit.charge))
    harness.assertEqual(Fuel.price('fuel', 40, 'charger'), math.ceil(40 * Config.pricePerUnit.fuel))
    harness.assertEqual(Fuel.unitPrice('charge', 'charger'), 2.0)
    harness.assertEqual(Fuel.progressDuration(40, 'charge', 'charger'), 20000)
    harness.assertEqual(Fuel.progressDuration(40, 'charge', 'pump'), 40 * Config.progressMsPerUnit)
    harness.assertEqual(Fuel.progressDuration(40), 40 * Config.progressMsPerUnit)
    harness.assertEqual(Fuel.progressDuration(1, 'charge', 'charger'), Config.minimumProgressMs, 'minimum duration still applies')
    Config.charging.pricePerPercent, Config.charging.secondsPerPercent = saved[1], saved[2]
end)

harness.test('totals round to whole dollars by Config.priceRounding without float noise', function()
    local saved = { Config.charging.pricePerPercent, Config.pricePerUnit.fuel }
    Config.charging.pricePerPercent = 1.25
    harness.assertEqual(Fuel.exactPrice('charge', 1, 'charger'), 1.25)
    harness.assertEqual(Fuel.price('charge', 1, 'charger'), 2, 'default rounds up')
    harness.assertEqual(Fuel.price('charge', 4, 'charger'), 5, 'whole totals are unchanged')
    Config.priceRounding = 'nearest'
    harness.assertEqual(Fuel.price('charge', 1, 'charger'), 1)
    harness.assertEqual(Fuel.price('charge', 2, 'charger'), 3)
    Config.priceRounding = 'down'
    harness.assertEqual(Fuel.price('charge', 3, 'charger'), 3)
    Config.priceRounding = 'bogus'
    harness.assertEqual(Fuel.price('charge', 1, 'charger'), 2, 'an unknown mode rounds up')
    Config.priceRounding = 'up'
    Config.pricePerUnit.fuel = 1.1
    harness.assertEqual(Fuel.price('fuel', 100), 110, '100 x 1.1 must not round up to 111')
    harness.assertEqual(math.type(Fuel.price('fuel', 3)), 'integer')
    Config.charging.pricePerPercent, Config.pricePerUnit.fuel = saved[1], saved[2]
end)

harness.test('Grapeseed pumps (prop_gas_pump_old3) are serviceable', function()
    local listed = false
    for _, name in ipairs(Config.pumpModels) do listed = listed or name == 'prop_gas_pump_old3' end
    harness.assertTrue(listed)
end)

harness.report('kora_fuel shared')
