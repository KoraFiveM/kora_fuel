local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
joaat = function(model) return 'hash:' .. model end
local threads, stopHandler = {}, nil
CreateThread = function(fn) threads[#threads + 1] = fn end
local function runThreads()
    local pending = threads
    threads = {}
    for _, fn in ipairs(pending) do fn() end
end
AddEventHandler = function(name, fn) if name == 'onResourceStop' then stopHandler = fn end end
GetCurrentResourceName = function() return 'kora_fuel' end

local zones, entities, hides, snapped, nextEntity = {}, {}, {}, {}, 100
local failModel = false
CreateModelHideExcludingScriptObjects = function(x, y, z, radius, model) hides[x .. ',' .. y] = model end
RemoveModelHide = function(x, y) hides[x .. ',' .. y] = nil end
PlaceObjectOnGroundProperly = function(entity) snapped[entity] = true end
FreezeEntityPosition = function() end
DoesEntityExist = function(entity) return entities[entity] ~= nil end
DeleteEntity = function(entity) entities[entity] = nil end

Kora = {
    zones = { sphere = function(opts) zones[#zones + 1] = opts return { remove = function() end } end },
    entities = {
        create = function(model, coords, options)
            if failModel then return false, 'model not found' end
            nextEntity = nextEntity + 1
            entities[nextEntity] = { model = model, coords = coords, heading = options.heading, freeze = options.freeze }
            return nextEntity
        end,
        remove = function(entity)
            if not entities[entity] then return false, 'untracked' end
            entities[entity] = nil
            return true
        end,
    },
}

local function count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')
dofile(repoRoot .. 'client/chargers.lua')

local first = Config.charging.stations[1]
local key = first.coords.x .. ',' .. first.coords.y

harness.test('every station gets one spawn zone and nothing spawns until the player is near', function()
    harness.assertEqual(#zones, #Config.charging.stations)
    harness.assertEqual(zones[1].radius, Config.charging.prop.spawnDistance)
    harness.assertEqual(zones[1].coords, first.coords)
    harness.assertEqual(count(entities), 0)
    harness.assertEqual(count(hides), 0)
end)

harness.test('entering spawns the configured prop at the station heading and hides the air pump', function()
    zones[1].onEnter()
    zones[1].onEnter() -- a repeated enter while spawning must not spawn twice
    runThreads()
    harness.assertEqual(count(entities), 1)
    local entity = entities[nextEntity]
    harness.assertEqual(entity.model, Config.charging.prop.model)
    harness.assertEqual(entity.coords, first.coords)
    harness.assertEqual(entity.heading, first.heading % 360.0)
    harness.assertTrue(entity.freeze)
    harness.assertTrue(snapped[nextEntity] == true, 'snapToGround settles the prop')
    harness.assertEqual(hides[key], 'hash:prop_gas_airunit01')
end)

harness.test('leaving deletes the prop and shows the air pump again', function()
    zones[1].onExit()
    harness.assertEqual(count(entities), 0)
    harness.assertEqual(count(hides), 0)
end)

harness.test('leaving before the model finished streaming leaves nothing behind', function()
    zones[1].onEnter()
    zones[1].onExit()
    runThreads()
    harness.assertEqual(count(entities), 0)
    harness.assertEqual(count(hides), 0)
end)

harness.test('a model that cannot spawn keeps the world air pump visible', function()
    failModel = true
    zones[2].onEnter()
    runThreads()
    harness.assertEqual(count(entities), 0)
    harness.assertEqual(count(hides), 0)
    zones[2].onExit()
    failModel = false
end)

harness.test('resource stop removes every prop and model hide', function()
    zones[1].onEnter(); zones[3].onEnter()
    runThreads()
    harness.assertEqual(count(entities), 2)
    harness.assertEqual(count(hides), 2)
    stopHandler('other_resource')
    harness.assertEqual(count(entities), 2)
    stopHandler('kora_fuel')
    harness.assertEqual(count(entities), 0)
    harness.assertEqual(count(hides), 0)
end)

harness.report('chargers')
