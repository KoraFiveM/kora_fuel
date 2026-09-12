local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path

local harness = require('harness')
local callbacks, events, payments, pushes = {}, {}, {}, {}
local clock, fuelLevel, setLevel = 1000, 80, nil

_G.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
_G.joaat = function(model)
    local hash = 0
    for i = 1, #model do hash = hash * 31 + model:byte(i) end
    return hash
end
_G.QB = {
    callback = { register = function(name, handler, opts) callbacks[name] = { handler = handler, opts = opts } end },
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
    qbcore = {
        removeMoney = function(_, src, account, amount)
            payments[#payments + 1] = { src = src, account = account, amount = amount }
            return true
        end,
    },
}
_G.RegisterNetEvent = function(name, handler) events[name] = handler end
_G.AddEventHandler = function() end
_G.TriggerClientEvent = function(name, src, ok, message, level, netId)
    pushes[#pushes + 1] = { name = name, src = src, ok = ok, message = message, level = level, netId = netId }
end
_G.GetGameTimer = function() return clock end
_G.NetworkGetEntityFromNetworkId = function(netId) return netId == 7 and 70 or 0 end
_G.GetPlayerPed = function(src) return src == 1 and 10 or 0 end
_G.DoesEntityExist = function(entity) return entity == 10 or entity == 70 end
_G.GetEntityType = function(entity) return entity == 70 and 2 or 1 end
_G.GetEntityCoords = function(entity)
    if entity == 10 or entity == 70 then return Config.stations[1] end
    return vector3(9999, 9999, 9999)
end
_G.GetPlayerRoutingBucket = function() return 0 end
_G.GetEntityRoutingBucket = function() return 0 end
_G.GetIsVehicleEngineRunning = function() return false end
_G.GetVehicleFuelLevel = function() return fuelLevel end
_G.GetEntityModel = function() return joaat('adder') end
_G.SetVehicleFuelLevel = function(_, level) setLevel = level end

dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')
dofile(repoRoot .. 'server/main.lua')

local function begin()
    return callbacks['qbfuel:beginService'].handler(1, 7, 'cash')
end

harness.test('service price is derived from the server vehicle state', function()
    payments, pushes, setLevel = {}, {}, nil
    fuelLevel = 80
    local session = begin()
    harness.assertTrue(session.ok)
    harness.assertEqual(session.duration, 2500)

    clock = clock + session.duration
    _G.source = 1
    events['qbfuel:server:serviceVehicle'](session.token)

    harness.assertEqual(#payments, 1)
    harness.assertEqual(payments[1].amount, 40)
    harness.assertEqual(setLevel, Config.maxLevel)
    harness.assertTrue(pushes[#pushes].ok)
end)

harness.test('the raw completion event cannot buy fuel without a session token', function()
    payments, pushes = {}, {}
    _G.source = 2
    events['qbfuel:server:serviceVehicle']('forged')
    harness.assertEqual(#payments, 0)
    harness.assertFalse(pushes[#pushes].ok)
end)

harness.test('cancelling consumes the matching pending service session', function()
    payments, pushes = {}, {}
    clock = clock + 100
    local session = begin()
    _G.source = 1
    events['qbfuel:server:cancelService'](session.token)
    clock = clock + session.duration
    events['qbfuel:server:serviceVehicle'](session.token)
    harness.assertEqual(#payments, 0)
    harness.assertFalse(pushes[#pushes].ok)
end)

harness.report('qbfuel server')
