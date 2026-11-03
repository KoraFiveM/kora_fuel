local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local events, payments, pushes, progressCalls = {}, {}, {}, {}
local balance, completed, paymentAccepted, atStation = 100, true, true, true
local atCharger, model = false, 'adder'

_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.joaat = function(model)
    local hash = 0
    for i = 1, #model do hash = hash * 31 + model:byte(i) end
    return hash
end
_G.Kora = {
    distance = { coords = function(a, b, distance)
        local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
        return dx * dx + dy * dy + dz * dz <= distance * distance
    end },
    callback = { trigger = function(src, name, netId, duration, electric)
        progressCalls[#progressCalls + 1] = { src, name, netId, duration, electric }
        return completed
    end },
    print = { debug = function() end },
    util = { isFiniteNumber = function(value)
        return type(value) == 'number' and value == value and value > -math.huge and value < math.huge
    end },
    world = {
        resolveNetworkEntity = function(src, netId)
            local entity = NetworkGetEntityFromNetworkId(netId)
            if entity == 0 or not DoesEntityExist(entity) then return nil, 'entity_unavailable' end
            if GetEntityType(entity) ~= 2 then return nil, 'wrong_entity_type' end
            if GetPlayerRoutingBucket(src) ~= GetEntityRoutingBucket(entity) then
                return nil, 'routing_bucket_mismatch'
            end
            return entity
        end,
    },
}
_G.exports = {
    kora_core = {
        getMoney = function() return balance end,
        removeMoney = function(_, src, account, amount)
            payments[#payments + 1] = { src = src, account = account, amount = amount }
            return paymentAccepted
        end,
    },
}
_G.RegisterNetEvent = function(name, handler) events[name] = handler end
_G.AddEventHandler = function() end
_G.TriggerClientEvent = function(name, src, ...)
    pushes[#pushes + 1] = { name = name, src = src, args = { ... } }
end
_G.NetworkGetEntityFromNetworkId = function(netId) return netId == 7 and 70 or 0 end
_G.GetPlayerPed = function(src) return src == 1 and 10 or 0 end
_G.DoesEntityExist = function(entity) return entity == 10 or entity == 70 end
_G.GetEntityType = function(entity) return entity == 70 and 2 or 1 end
_G.GetEntityCoords = function(entity)
    if atCharger and (entity == 10 or entity == 70) then return Config.charging.stations[1].coords end
    if atStation and (entity == 10 or entity == 70) then return Config.stations[1] end
    return vector3(9999, 9999, 9999)
end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.GetEntityRoutingBucket = function() return 0 end
_G.GetIsVehicleEngineRunning = function() return false end
_G.GetEntityModel = function() return joaat(model) end

dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')
dofile(repoRoot .. 'server/main.lua')

local function purchase(account, quantity, level, site)
    payments, pushes, progressCalls = {}, {}, {}
    _G.source = 1
    events['qbfuel:server:purchase'](7, account or 'cash', quantity or 20, level or 80, site)
end

harness.test('a completed purchase charges the configured price and fills the requested amount', function()
    purchase()
    harness.assertEqual(progressCalls[1][2], 'qbfuel:runProgress')
    harness.assertEqual(progressCalls[1][4], 2500)
    harness.assertEqual(#payments, 1)
    harness.assertEqual(payments[1].amount, 40)
    harness.assertEqual(pushes[1].name, 'qbfuel:client:fillVehicle')
    harness.assertEqual(pushes[1].args[1], 7)
    harness.assertEqual(pushes[1].args[2], 20)
    harness.assertTrue(pushes[#pushes].args[1])
end)

harness.test('invalid accounts and fill amounts are rejected before progress or payment', function()
    for _, request in ipairs({ { 'invalid', 20, 80 }, { 'cash', 21, 80 }, { 'cash', -1, 80 }, { 'cash', 1.5, 80 } }) do
        purchase(table.unpack(request))
        harness.assertEqual(#progressCalls, 0)
        harness.assertEqual(#payments, 0)
        harness.assertFalse(pushes[#pushes].args[1])
    end
end)

harness.test('insufficient funds or a remote service point cannot start a purchase', function()
    balance = 0
    purchase()
    harness.assertEqual(#payments, 0)
    harness.assertEqual(#progressCalls, 0)
    harness.assertFalse(pushes[#pushes].args[1])
    balance, atStation = 100, false
    purchase()
    harness.assertEqual(#payments, 0)
    harness.assertEqual(#progressCalls, 0)
    harness.assertFalse(pushes[#pushes].args[1])
    atStation = true
end)

harness.test('cancelled progress does not charge or fill and releases the purchase lock', function()
    completed = false
    purchase()
    harness.assertEqual(#payments, 0)
    harness.assertEqual(#pushes, 0)
    completed = true
    purchase()
    harness.assertEqual(#payments, 1)
    harness.assertTrue(pushes[#pushes].args[1])
end)

harness.test('a failed payment never fills the vehicle', function()
    paymentAccepted = false
    purchase()
    harness.assertEqual(#payments, 1)
    harness.assertEqual(#pushes, 1)
    harness.assertEqual(pushes[1].name, 'qbfuel:client:serviceResult')
    harness.assertFalse(pushes[1].args[1])
    paymentAccepted = true
end)

local function refused(message)
    harness.assertEqual(#progressCalls, 0)
    harness.assertEqual(#payments, 0)
    harness.assertFalse(pushes[#pushes].args[1])
    if message then harness.assertEqual(pushes[#pushes].args[2], message) end
end

harness.test('electric vehicles are refused at petrol pumps while charging stations exist', function()
    model = 'neon'
    purchase()
    refused('Electric vehicles must use a charging station.')
    purchase('cash', 20, 80, 'bogus')
    refused('Electric vehicles must use a charging station.')
end)

harness.test('pumps charge electric vehicles when allowed or when there is no charging network', function()
    Config.charging.allowAtPumps = true
    purchase()
    harness.assertEqual(payments[1].amount, Fuel.price('charge', 20))
    Config.charging.allowAtPumps = false

    Config.charging.enabled = false
    purchase()
    harness.assertEqual(payments[1].amount, Fuel.price('charge', 20))
    purchase('cash', 20, 80, 'charger')
    refused('Move closer to the service point and vehicle.')
    Config.charging.enabled = true
end)

harness.test('charging stations bill and time electric vehicles from the charging config', function()
    atStation, atCharger = false, true
    Config.charging.pricePerPercent = 2.0
    Config.charging.secondsPerPercent = 0.5
    purchase('bank', 20, 80, 'charger')
    harness.assertEqual(progressCalls[1][4], 10000)
    harness.assertTrue(progressCalls[1][5], 'the progress callback is told it is a charge')
    harness.assertEqual(#payments, 1)
    harness.assertEqual(payments[1].amount, 40)
    harness.assertEqual(payments[1].account, 'bank')
    harness.assertTrue(pushes[#pushes].args[1])
    harness.assertEqual(Fuel.price('charge', 20), 25, 'pump charge pricing is unchanged')
end)

harness.test('a charging-station request must be made at a charging station', function()
    atStation, atCharger = true, false
    purchase('cash', 20, 80, 'charger')
    refused('Move closer to the service point and vehicle.')
    -- Chargers stand on petrol forecourts, so a pump request made there is in
    -- range but still refused for an EV.
    atCharger = true
    purchase('cash', 20, 80, 'pump')
    refused('Electric vehicles must use a charging station.')
    atStation, atCharger = false, false
    purchase('cash', 20, 80, 'pump')
    refused('Move closer to the service point and vehicle.')
    atStation, atCharger = true, true
end)

harness.test('a vehicle the server does not list as electric is billed as petrol at a charger', function()
    model = 'adder'
    Config.charging.pricePerPercent = 1.0
    purchase('cash', 20, 80, 'charger')
    harness.assertEqual(progressCalls[1][4], 2500, 'petrol keeps the pump timing')
    harness.assertEqual(payments[1].amount, Fuel.price('fuel', 20))
    harness.assertFalse(progressCalls[1][5])
end)

harness.test('quantity and funds are still validated at charging stations', function()
    model = 'neon'
    purchase('cash', 21, 80, 'charger')
    refused('Invalid fill amount.')
    balance = 0
    purchase('cash', 20, 80, 'charger')
    refused('Insufficient funds.')
    balance = 100
end)

harness.report('qbfuel server')
