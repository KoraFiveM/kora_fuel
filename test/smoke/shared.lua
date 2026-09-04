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

harness.test('fuel level is clamped to the native 0-100 range', function()
    harness.assertEqual(Fuel.clampLevel(-5), 0)
    harness.assertEqual(Fuel.clampLevel(150), Config.maxLevel)
    harness.assertEqual(Fuel.clampLevel(42.5), 42.5)
end)

harness.test('only configured payment accounts are accepted', function()
    harness.assertTrue(Fuel.isPaymentAccount('cash'))
    harness.assertTrue(Fuel.isPaymentAccount('bank'))
    harness.assertFalse(Fuel.isPaymentAccount('crypto'))
end)

harness.report('qbfuel shared')
