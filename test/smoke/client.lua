local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
joaat = function(model) return model end
local nativeExports, legacyEvents = {}, {}
exports = function(name, fn) nativeExports[name] = fn end
AddEventHandler = function(name, fn) legacyEvents[name] = fn end
RegisterNetEvent = function() end
CreateThread = function() end
PlayerPedId = function() return 1 end
-- Stand in for FiveM vector subtraction; the vehicle is parked at the pump.
GetEntityCoords = function() return setmetatable({}, { __sub = function() return '' end }) end
DoesEntityExist = function() return true end
GetIsVehicleEngineRunning = function() return false end
local fuelLevel, controlRequested = 60, nil
GetVehicleFuelLevel = function() return fuelLevel end
SetVehicleFuelLevel = function(_, level) fuelLevel = level end
NetworkRequestControlOfEntity = function(vehicle) controlRequested = vehicle end
IsEntityAVehicle = function(vehicle) return vehicle == 2 end
NetworkGetNetworkIdFromEntity = function() return 12 end
local model = 'adder'
GetEntityModel = function() return model end

local openMenu, app, openData, purchase
Kora = {
    notify = { send = function() error('Unexpected notification') end },
    closest = { vehicle = function() return { id = 2 } end },
    interact = { addModel = function(_, options) openMenu = options[1].action end },
    callback = { register = function() end },
    nui = {
        registerApp = function(definition) app = definition end,
        openApp = function(_, options) openData = options.data end,
    },
}
TriggerServerEvent = function(...) purchase = { ... } end

Kora.compat = dofile(repoRoot .. '../kora_lib/compat/provider.lua')()

dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')
dofile(repoRoot .. 'client/main.lua')

harness.test('fuel and charging totals track the selected amount without purchasing', function()
    for _, kind in ipairs({ 'fuel', 'charge' }) do
        model = kind == 'charge' and 'neon' or 'adder'
        openMenu()
        local total = app.navigation[1].content.blocks[2].items[2]
        harness.assertEqual(total.label, 'Total Price')
        harness.assertEqual(total.value, ('$%d'):format(Fuel.price(kind, 40)))
        local update = app.onChange('fuel-submit', { value = { quantity = 7, account = 'bank' } })
        harness.assertEqual(update.navigation[1].content.blocks[2].items[2].value,
            ('$%d'):format(Fuel.price(kind, 7)))
        harness.assertEqual(total.description, '7 units')
        harness.assertEqual(purchase, nil, 'an edit must not trigger a purchase')
        for _, invalid in ipairs({ '', 0, 41, 1.5, math.huge, 0 / 0 }) do
            harness.assertEqual(app.onChange('fuel-submit', { value = { quantity = invalid } }), nil)
        end
        harness.assertEqual(total.description, '7 units', 'invalid edits must leave the total alone')
    end
end)

harness.test('submitting still sends the quantity and account to the existing purchase event', function()
    local result = app.onAction('fuel-submit', { data = openData, value = { quantity = 7, account = 'bank' } })
    harness.assertTrue(result.close)
    harness.assertEqual(purchase[1], 'qbfuel:server:purchase')
    harness.assertEqual(purchase[2], 12)
    harness.assertEqual(purchase[3], 'bank')
    harness.assertEqual(purchase[4], 7)
    harness.assertEqual(purchase[5], 60)
end)

harness.test('LegacyFuel aliases preserve fractional reads and nil writes without changing native exports', function()
    local getFuel, setFuel
    legacyEvents.__cfx_export_LegacyFuel_GetFuel(function(fn) getFuel = fn end)
    legacyEvents.__cfx_export_LegacyFuel_SetFuel(function(fn) setFuel = fn end)
    fuelLevel = 60.75
    harness.assertEqual(getFuel(2), 60.75)
    harness.assertEqual(nativeExports.GetFuel(2), 60)
    harness.assertEqual(setFuel(2, 110), nil)
    harness.assertEqual(fuelLevel, 100)
    harness.assertEqual(controlRequested, 2)
    harness.assertEqual(setFuel(2, -10), nil)
    harness.assertEqual(fuelLevel, 0)
    harness.assertEqual(setFuel(2, 50.5), nil)
    harness.assertEqual(fuelLevel, 50.5)
    harness.assertTrue(nativeExports.SetFuel(2, 60))
    for _, invalid in ipairs({ 'bad', math.huge, -math.huge, 0 / 0 }) do
        harness.assertEqual(setFuel(2, invalid), nil)
        harness.assertEqual(fuelLevel, 60)
    end
    for _, invalid in ipairs({ 0, 3 }) do
        harness.assertEqual(getFuel(invalid), nil)
        harness.assertEqual(setFuel(invalid, 25), nil)
        harness.assertEqual(fuelLevel, 60)
    end
end)

harness.report('qbfuel client')
