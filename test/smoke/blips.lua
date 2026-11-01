local scriptDir = debug.getinfo(1, "S").source:match("@?(.*/)") or "./"
local testDir = scriptDir .. "../"
local repoRoot = testDir .. "../"
package.path = testDir .. "?.lua;" .. package.path
local harness = require("harness")

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
local thread, stopHandler
CreateThread = function(fn) thread = fn end
AddEventHandler = function(name, fn) if name == "onResourceStop" then stopHandler = fn end end
GetCurrentResourceName = function() return "kora_fuel" end

local blips, nextId, pending = {}, 0, nil
DoesBlipExist = function(id) return blips[id] ~= nil end
AddBlipForCoord = function(x, y, z)
    nextId = nextId + 1
    blips[nextId] = { x = x, y = y, z = z }
    return nextId
end
SetBlipSprite = function(id, v) blips[id].sprite = v end
SetBlipColour = function(id, v) blips[id].colour = v end
SetBlipScale = function(id, v) blips[id].scale = v end
SetBlipAsShortRange = function(id, v) blips[id].shortRange = v end
BeginTextCommandSetBlipName = function() end
AddTextComponentSubstringPlayerName = function(label) pending = label end
EndTextCommandSetBlipName = function(id) blips[id].label = pending end
RemoveBlip = function(id) blips[id] = nil end

local function count()
    local n = 0
    for _ in pairs(blips) do n = n + 1 end
    return n
end

dofile(repoRoot .. "config.lua")
dofile(repoRoot .. "client/blips.lua")

harness.test("defaults create one configured blip per station", function()
    thread()
    harness.assertEqual(count(), #Config.stations)
    harness.assertEqual(blips[1].sprite, 361)
    harness.assertEqual(blips[1].colour, 1)
    harness.assertEqual(blips[1].scale, 0.6)
    harness.assertTrue(blips[1].shortRange)
    harness.assertEqual(blips[1].label, "Gas Station")
    harness.assertEqual(blips[1].x, Config.stations[1].x)
end)

harness.test("resource stop removes every blip", function()
    stopHandler("other_resource")
    harness.assertEqual(count(), #Config.stations)
    stopHandler("kora_fuel")
    harness.assertEqual(count(), 0)
end)

harness.test("per-station overrides apply and disable", function()
    Config.blips.perStation = { [2] = { enabled = false }, [3] = { label = "Custom", colour = 5 } }
    thread()
    harness.assertEqual(count(), #Config.stations - 1)
    local custom
    for _, b in pairs(blips) do
        if b.label == "Custom" then custom = b end
    end
    harness.assertEqual(custom.colour, 5)
    harness.assertEqual(custom.sprite, 361)
    stopHandler("kora_fuel")
end)

harness.test("disabled config creates nothing", function()
    Config.blips.enabled = false
    thread()
    harness.assertEqual(count(), 0)
end)

harness.report("blips")
