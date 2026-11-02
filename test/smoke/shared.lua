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

harness.report('qbfuel shared')
