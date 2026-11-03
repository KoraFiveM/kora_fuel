local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local testDir = scriptDir .. "../"
local repoRoot = testDir .. "../"
package.path = testDir .. "?.lua;" .. package.path
local harness = require("harness")

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
joaat = function(model) return model end
local thread, stopHandler
CreateThread = function(fn) thread = fn end
AddEventHandler = function(name, fn) if name == "onResourceStop" then stopHandler = fn end end
GetCurrentResourceName = function() return "kora_fuel" end

local blips, nextId = {}, 0
Kora = {
    blips = {
        create = function(coords, options)
            nextId = nextId + 1
            blips[nextId] = {
                x = coords.x, y = coords.y, z = coords.z, sprite = options.sprite, colour = options.color,
                scale = options.scale, shortRange = options.shortRange, category = options.category,
                label = options.name,
            }
            return nextId
        end,
        remove = function(id) blips[id] = nil return true end,
    },
}

-- Blip ids keep rising across rebuilds, so find the first charging blip by its sprite.
local function firstCharger()
    local best
    for id, b in pairs(blips) do
        if b.sprite == Config.charging.blips.sprite and (not best or id < best) then best = id end
    end
    return blips[best]
end

local function count()
    local n = 0
    for _ in pairs(blips) do n = n + 1 end
    return n
end

dofile(repoRoot .. "config.lua")
dofile(repoRoot .. "shared/fuel.lua")
dofile(repoRoot .. "client/blips.lua")

local chargers = #Config.charging.stations

-- Charging station blips are created first, so gas station blips follow them.
harness.test("defaults create one configured blip per gas station and charging station", function()
    thread()
    harness.assertEqual(count(), #Config.stations - 2 + chargers)
    local gas = blips[chargers + 1]
    harness.assertEqual(gas.sprite, 361)
    harness.assertEqual(gas.colour, 1)
    harness.assertEqual(gas.scale, 0.6)
    harness.assertTrue(gas.shortRange)
    harness.assertEqual(gas.label, "Gas Station")
    harness.assertEqual(gas.x, Config.stations[1].x)
end)

harness.test("charging station blips use Config.charging.blips and can be turned off", function()
    local ev = blips[1]
    harness.assertEqual(ev.label, "EV Charging Station - " .. Config.charging.stations[1].label)
    harness.assertEqual(ev.sprite, 354)
    harness.assertEqual(ev.colour, 46)
    harness.assertEqual(ev.category, "Fuel")
    harness.assertFalse(ev.shortRange)
    harness.assertEqual(ev.colour, Config.charging.blips.colour)
    harness.assertEqual(ev.sprite, Config.charging.blips.sprite)
    harness.assertEqual(ev.x, Config.charging.stations[1].coords.x)
    Config.charging.blips.enabled = false
    thread()
    harness.assertEqual(count(), #Config.stations - 2)
    Config.charging.blips.enabled = true
    Config.charging.enabled = false
    thread()
    harness.assertEqual(count(), #Config.stations - 2, "no charging network, no charging blips")
    Config.charging.enabled = true
    thread()
    harness.assertEqual(count(), #Config.stations - 2 + chargers)
end)

harness.test("station names can be left off the charging blip label", function()
    Config.charging.blips.showStationName = false
    thread()
    harness.assertEqual(firstCharger().label, "EV Charging Station")
    Config.charging.blips.showStationName = true
    thread()
end)

harness.test("a bad blip category falls back to Fuel instead of stopping the other blips", function()
    local create = Kora.blips.create
    Kora.blips.create = function(coords, options)
        if options.category == "Nope" then error("unknown category") end
        return create(coords, options)
    end
    Config.charging.blips.category = "Nope"
    thread()
    harness.assertEqual(count(), #Config.stations - 2 + chargers)
    harness.assertEqual(firstCharger().category, "Fuel")
    Config.charging.blips.category = "Fuel"
    Kora.blips.create = create
    thread()
end)

harness.test("resource stop removes every blip", function()
    stopHandler("other_resource")
    harness.assertEqual(count(), #Config.stations - 2 + chargers)
    stopHandler("kora_fuel")
    harness.assertEqual(count(), 0)
end)

harness.test("per-station overrides apply and disable", function()
    Config.blips.perStation = { [2] = { enabled = false }, [3] = { label = "Custom", colour = 5 } }
    Config.charging.blips.enabled = false
    thread()
    harness.assertEqual(count(), #Config.stations - 3)
    local custom
    for _, b in pairs(blips) do
        if b.label == "Custom" then custom = b end
    end
    harness.assertEqual(custom.colour, 5)
    harness.assertEqual(custom.sprite, 361)
    stopHandler("kora_fuel")
end)

harness.test("mergeRadius 0 draws a blip for every station", function()
    Config.blips.perStation = {}
    Config.blips.mergeRadius = 0
    Config.charging.blips.enabled = false
    thread()
    harness.assertEqual(count(), #Config.stations)
    Config.blips.mergeRadius = 30.0
    stopHandler("kora_fuel")
end)

harness.test("disabled config creates nothing", function()
    Config.blips.enabled = false
    thread()
    harness.assertEqual(count(), 0)
end)

harness.report("blips")
