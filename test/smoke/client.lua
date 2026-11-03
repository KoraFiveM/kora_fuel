local scriptDir = debug.getinfo(1, 'S').source:match('@?(.*/)') or './'
local testDir = scriptDir .. '../'
local repoRoot = testDir .. '../'
package.path = testDir .. '?.lua;' .. package.path
local harness = require('harness')

vector3 = function(x, y, z) return { x = x, y = y, z = z } end
joaat = function(model) return model end
local nativeExports, legacyEvents = {}, {}
local zones = {}
exports = setmetatable({
    kora_target = { addSphereZone = function(_, zone) zones[#zones + 1] = zone end },
}, { __call = function(_, name, fn) nativeExports[name] = fn end })
AddEventHandler = function(name, fn) legacyEvents[name] = fn end
local netEvents = {}
RegisterNetEvent = function(name, fn) netEvents[name] = fn end
-- Minimal scheduler: each thread is a coroutine, Wait yields, advance() resumes them once.
local threads, cacheState, cacheHandlers = {}, { vehicle = false, seat = false }, {}
CreateThread = function(fn) threads[#threads + 1] = coroutine.create(fn) end
Wait = function() coroutine.yield() end
local function advance()
    for i = #threads, 1, -1 do
        local ok, err = coroutine.resume(threads[i])
        if not ok then error(err, 0) end
        if coroutine.status(threads[i]) == 'dead' then table.remove(threads, i) end
    end
end
local function setCache(key, value)
    local old = cacheState[key]
    cacheState[key] = value
    for _, fn in ipairs(cacheHandlers[key] or {}) do fn(value, old) end
end
PlayerPedId = function() return 1 end
-- Stand in for FiveM vector subtraction; the vehicle is parked at the pump.
local pedPos = { x = 0.0, y = 0.0, z = 0.0 }
GetEntityCoords = function()
    return setmetatable({ x = pedPos.x, y = pedPos.y, z = pedPos.z }, { __sub = function() return '' end })
end
local clock = 0
GetGameTimer = function() return clock end
DoesEntityExist = function() return true end
local engineOn, engineOff = false, 0
GetIsVehicleEngineRunning = function() return engineOn end
local fuelLevel, controlRequested = 60, nil
GetVehicleClass = function() return 1 end
GetEntitySpeed = function() return 20.0 end
SetVehicleEngineOn = function() engineOff = engineOff + 1 end
GetVehicleFuelLevel = function() return fuelLevel end
SetVehicleFuelLevel = function(_, level) fuelLevel = level end
NetworkRequestControlOfEntity = function(vehicle) controlRequested = vehicle end
IsEntityAVehicle = function(vehicle) return vehicle == 2 end
NetworkGetNetworkIdFromEntity = function() return 12 end
local model = 'adder'
GetEntityModel = function() return model end
local waypoint
SetNewWaypoint = function(x, y) waypoint = { x = x, y = y } end

local openMenu, app, openData, purchase
local notices, vehicleScans = {}, 0
Kora = {
    notify = { send = function(notice) notices[#notices + 1] = notice end },
    closest = { vehicle = function() vehicleScans = vehicleScans + 1 return { id = 2 } end },
    interact = { addModel = function(_, options) openMenu = options[1].action end },
    callback = { register = function() end },
    cache = {
        ped = function() return 1 end,
        vehicle = function() return cacheState.vehicle end,
        seat = function() return cacheState.seat end,
        onChange = function(key, fn)
            cacheHandlers[key] = cacheHandlers[key] or {}
            table.insert(cacheHandlers[key], fn)
        end,
    },
    nui = {
        registerApp = function(definition) app = definition end,
        openApp = function(_, options) openData = options.data end,
    },
}
TriggerServerEvent = function(...) purchase = { ... } end

-- Kora.lang stand-in that reads the resource's own English locale.
local english = dofile(repoRoot .. 'locales/en.lua')
Kora.lang = function(key)
    local value = english
    for part in key:gmatch('[^.]+') do value = type(value) == 'table' and value[part] or nil end
    return value or key
end

Kora.compat = dofile(repoRoot .. '../kora_lib/compat/provider.lua')()

dofile(repoRoot .. 'shared/stations.lua')
dofile(repoRoot .. 'config.lua')
dofile(repoRoot .. 'shared/fuel.lua')
dofile(repoRoot .. 'client/main.lua')

local stationOne = Config.charging.stations[1].coords
local function standAtCharger() pedPos = { x = stationOne.x, y = stationOne.y, z = stationOne.z } end

local function openCharger() zones[1].options[1].onSelect() end

harness.test('fuel and charging totals track the selected amount without purchasing', function()
    local cases = {
        { kind = 'fuel', site = 'pump', model = 'adder' },
        { kind = 'charge', site = 'charger', model = 'neon' },
        { kind = 'charge', site = 'pump', model = 'neon', allowAtPumps = true },
    }
    for _, case in ipairs(cases) do
        local kind, site = case.kind, case.site
        model = case.model
        Config.charging.allowAtPumps = case.allowAtPumps == true
        standAtCharger()
        if site == 'charger' then openCharger() else openMenu() end
        harness.assertEqual(openData.site, site)
        local total = app.navigation[1].content.blocks[2].items[2]
        harness.assertEqual(total.label, 'Total Price')
        harness.assertEqual(total.value, ('$%d'):format(Fuel.price(kind, 40, site)))
        local update = app.onChange('fuel-submit', { value = { quantity = 7, account = 'bank' } })
        harness.assertEqual(update.navigation[1].content.blocks[2].items[2].value,
            ('$%d'):format(Fuel.price(kind, 7, site)))
        local exact = Fuel.exactPrice(kind, 7, site)
        local units = exact % 1 == 0 and '7 units' or ('7 units ($%.2f rounded up)'):format(exact)
        harness.assertEqual(total.description, units)
        harness.assertEqual(purchase, nil, 'an edit must not trigger a purchase')
        for _, invalid in ipairs({ '', 0, 41, 1.5, math.huge, 0 / 0 }) do
            harness.assertEqual(app.onChange('fuel-submit', { value = { quantity = invalid } }), nil)
        end
        harness.assertEqual(total.description, units, 'invalid edits must leave the total alone')
    end
    harness.assertEqual(#notices, 0, 'no refusal or error is shown for valid services')
    Config.charging.allowAtPumps = false
end)

harness.test('submitting still sends the quantity and account to the existing purchase event', function()
    local result = app.onAction('fuel-submit', { data = openData, value = { quantity = 7, account = 'bank' } })
    harness.assertTrue(result.close)
    harness.assertEqual(purchase[1], 'qbfuel:server:purchase')
    harness.assertEqual(purchase[2], 12)
    harness.assertEqual(purchase[3], 'bank')
    harness.assertEqual(purchase[4], 7)
    harness.assertEqual(purchase[5], 60)
    harness.assertEqual(purchase[6], 'pump')
end)

harness.test('the charging menu shows the station, uses station pricing and sends the charger site', function()
    local saved = Config.charging.pricePerPercent
    Config.charging.pricePerPercent = 3.0
    model = 'neon'
    standAtCharger()
    openCharger()
    harness.assertEqual(app.title, 'Charge vehicle')
    harness.assertEqual(app.description, 'Battery charge - ' .. Config.charging.stations[1].label)
    harness.assertEqual(app.navigation[1].content.blocks[2].items[1].value, '$3.00')
    harness.assertEqual(app.navigation[1].content.blocks[2].items[2].value, '$120')
    app.onAction('fuel-submit', { data = openData, value = { quantity = 7, account = 'cash' } })
    harness.assertEqual(purchase[6], 'charger')
    Config.charging.pricePerPercent = saved
end)

harness.test('petrol pumps send EVs to the nearest charging station instead of opening a menu', function()
    model = 'neon'
    app, notices = nil, {}
    local at = Config.charging.stations[2].coords
    pedPos = { x = at.x + 100.0, y = at.y, z = at.z }
    openMenu()
    harness.assertEqual(app, nil, 'no charge menu at a petrol pump')
    harness.assertEqual(#notices, 1)
    harness.assertEqual(notices[1].message, Config.charging.pumpMessage .. ' Nearest: ' ..
        Config.charging.stations[2].label .. ' (100 m). A GPS waypoint has been set to it.')

    Config.charging.pumpMessage = 'Use a charger.'
    -- Out at sea south of the port: every station is kilometres away.
    pedPos = { x = 0.0, y = -5000.0, z = 0.0 }
    local nearest, distance = Fuel.nearestCharger(pedPos)
    notices = {}
    openMenu()
    harness.assertTrue(notices[1].message:find('Use a charger. Nearest: ' .. nearest.label, 1, true) ~= nil)
    harness.assertTrue(notices[1].message:find(('(%.1f km)'):format(distance / 1000.0), 1, true) ~= nil)
    Config.charging.pumpMessage = 'Electric vehicles cannot use petrol pumps. Use an EV charging station.'

    notices, model = {}, 'adder'
    openMenu()
    harness.assertTrue(app ~= nil, 'petrol vehicles are still serviced at pumps')
    harness.assertEqual(#notices, 0)
end)

harness.test('the pump refusal sets the GPS to the nearest charger unless switched off', function()
    model, notices, waypoint = 'neon', {}, nil
    local station = Config.charging.stations[2]
    pedPos = { x = station.coords.x + 100.0, y = station.coords.y, z = station.coords.z }
    openMenu()
    local at = Fuel.chargerPosition(station)
    harness.assertEqual(waypoint.x, at.x)
    harness.assertEqual(waypoint.y, at.y)

    Config.charging.waypointToNearest = false
    notices, waypoint = {}, nil
    openMenu()
    harness.assertEqual(waypoint, nil, 'no waypoint when the option is off')
    harness.assertEqual(notices[1].message, Config.charging.pumpMessage .. ' Nearest: ' .. station.label .. ' (100 m).')
    Config.charging.waypointToNearest = true

    notices, waypoint, model = {}, nil, 'adder'
    openMenu()
    harness.assertEqual(waypoint, nil, 'petrol vehicles never get a waypoint')
    standAtCharger()
end)

harness.test('a 1% top-up explains its whole-dollar total and uses singular units', function()
    model, notices, fuelLevel = 'neon', {}, 99
    standAtCharger()
    openCharger()
    local blocks = app.navigation[1].content.blocks
    harness.assertEqual(blocks[2].items[1].value, '$1.25')
    harness.assertEqual(blocks[2].items[2].value, '$2')
    harness.assertEqual(blocks[2].items[2].description, '1 unit ($1.25 rounded up)')
    harness.assertEqual(blocks[3].fields[1].description, '$1.25 per unit, up to 1 unit. Totals are whole dollars.')

    Config.priceRounding = 'nearest'
    openCharger()
    blocks = app.navigation[1].content.blocks
    harness.assertEqual(blocks[2].items[2].value, '$1')
    harness.assertEqual(blocks[2].items[2].description, '1 unit ($1.25 rounded)')
    Config.priceRounding = 'up'
    fuelLevel = 60
end)

harness.test('charging stations refuse petrol vehicles and far-away players', function()
    app, notices = nil, {}
    model = 'adder'
    standAtCharger()
    openCharger()
    harness.assertEqual(app, nil)
    harness.assertEqual(notices[1].message, 'Charging stations are for electric vehicles only.')

    notices, model = {}, 'neon'
    pedPos = { x = stationOne.x + 500.0, y = stationOne.y, z = stationOne.z }
    openCharger()
    harness.assertEqual(app, nil)
    harness.assertEqual(notices[1].message, 'Move to an EV charging station first.')
    standAtCharger()
end)

harness.test('every charger gets one target zone on the prop with its own or the default radius', function()
    harness.assertEqual(#zones, #Config.charging.stations)
    local lift = Config.charging.prop.targetHeight
    for i, station in ipairs(Config.charging.stations) do
        harness.assertEqual(zones[i].coords.x, station.coords.x)
        harness.assertEqual(zones[i].coords.y, station.coords.y)
        harness.assertEqual(zones[i].coords.z, station.coords.z + lift, 'the zone is centred on the prop body')
        harness.assertEqual(zones[i].radius, (station.radius or 0) > 0 and station.radius or Config.charging.zoneRadius)
        harness.assertEqual(zones[i].distance, Config.charging.interactDistance)
    end
    harness.assertEqual(zones[1].options[1].label, 'Charge vehicle')
    harness.assertEqual(zones[1].drawSprite, false, 'no floating world icon: the charger prop marks the spot')
end)

harness.test('the isElectricVehicle export asks the native with the model hash and falls back to the list', function()
    local isElectric = nativeExports.isElectricVehicle
    harness.assertTrue(isElectric ~= nil, 'export registered')
    local asked
    GetIsVehicleElectric = function(arg) asked = arg return arg == 'future_ev' end
    model = 'future_ev'
    harness.assertTrue(isElectric(2), 'a model only the game knows as electric counts')
    harness.assertEqual(asked, 'future_ev', 'the native takes the model hash, not the entity')
    model = 'adder'
    harness.assertFalse(isElectric(2))
    GetIsVehicleElectric = nil
    model = 'envisage'
    harness.assertTrue(isElectric(2), 'listed EVs count without the native')
end)

harness.test('the pump message names whichever station is nearest the player, wherever they are', function()
    model = 'neon'
    for _, station in ipairs(Config.charging.stations) do
        app, notices = nil, {}
        pedPos = { x = station.coords.x + 30.4, y = station.coords.y, z = station.coords.z }
        openMenu()
        harness.assertTrue(notices[1].message:find('Nearest: ' .. station.label .. ' (30 m).', 1, true) ~= nil,
            'pump near ' .. station.label .. ' should name it')
    end
    standAtCharger()
end)

harness.test('the charge option only shows near an electric vehicle and is memoised', function()
    local canInteract = zones[1].options[1].canInteract
    clock, vehicleScans = 1000, 0
    model = 'neon'
    harness.assertTrue(canInteract(), 'on foot beside an EV')
    harness.assertEqual(vehicleScans, 1)
    canInteract(); canInteract()
    harness.assertEqual(vehicleScans, 1, 'repeated resolver ticks reuse the last answer')

    clock, model = 1600, 'adder'
    harness.assertFalse(canInteract(), 'a petrol car does not offer a charge')

    clock, vehicleScans = 2200, 0
    model = 'neon'
    setCache('vehicle', 2)
    harness.assertTrue(canInteract(), 'sitting in an EV')
    harness.assertEqual(vehicleScans, 0, 'the cached vehicle replaces the world scan')
    clock, model = 2800, 'adder'
    harness.assertFalse(canInteract())
    setCache('vehicle', false)
end)

harness.test('a full battery hides the charge option, so a second aim cannot toast "already full"', function()
    local canInteract = zones[1].options[1].canInteract
    model, fuelLevel = 'neon', 100
    clock = 10000
    harness.assertFalse(canInteract(), 'nothing to charge')
    clock = 10200
    fuelLevel = 95
    harness.assertFalse(canInteract(), 'memoised for half a second')
    clock = 10600
    harness.assertTrue(canInteract(), 'room for charge shows the option again')
    fuelLevel = 60
end)

harness.test('EV and charger toasts are titled Charging, petrol toasts Fuel', function()
    model, notices = 'neon', {}
    standAtCharger()
    fuelLevel = 100
    openCharger()
    harness.assertEqual(notices[1].title, 'Charging')
    harness.assertEqual(notices[1].message, 'Battery is already fully charged.')

    notices, model = {}, 'adder'
    openCharger()
    harness.assertEqual(notices[1].title, 'Charging')
    openMenu()
    harness.assertEqual(notices[2].title, 'Fuel')
    harness.assertEqual(notices[2].message, 'Vehicle is already full.')

    notices, model = {}, 'neon'
    openMenu()
    harness.assertEqual(notices[1].title, 'Charging', 'the petrol-pump refusal for an EV')
    fuelLevel = 60

    notices = {}
    netEvents['qbfuel:client:serviceResult'](true, 'Vehicle charged for $7.', true)
    netEvents['qbfuel:client:serviceResult'](false, 'Vehicle is already full.', false)
    harness.assertEqual(notices[1].title, 'Charging')
    harness.assertEqual(notices[1].type, 'success')
    harness.assertEqual(notices[2].title, 'Fuel')
    harness.assertEqual(notices[2].type, 'error')
    model = 'adder'
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

harness.test('qb-fuel, ps-fuel and cdn-fuel share the LegacyFuel behaviour', function()
    fuelLevel = 33.5
    for _, res in ipairs({ 'qb-fuel', 'ps-fuel', 'cdn-fuel' }) do
        local getFuel, setFuel
        legacyEvents['__cfx_export_' .. res .. '_GetFuel'](function(fn) getFuel = fn end)
        legacyEvents['__cfx_export_' .. res .. '_SetFuel'](function(fn) setFuel = fn end)
        harness.assertEqual(getFuel(2), 33.5)
        harness.assertEqual(setFuel(2, 12.5), nil)
        harness.assertEqual(fuelLevel, 12.5)
        harness.assertEqual(setFuel(2, 'bad'), nil)
        harness.assertEqual(fuelLevel, 12.5)
        harness.assertEqual(getFuel(0), nil)
        fuelLevel = 33.5
    end
end)

harness.test('fuel consumption only runs while driving and starts and stops on cache changes', function()
    harness.assertEqual(#threads, 0, 'no worker may exist on foot')
    setCache('vehicle', 2)
    harness.assertEqual(#threads, 0, 'a vehicle without the driver seat must not start the worker')
    setCache('seat', 0)
    harness.assertEqual(#threads, 0)
    setCache('seat', -1)
    harness.assertEqual(#threads, 1, 'driving starts exactly one worker')
    setCache('vehicle', 3)
    setCache('seat', -1)
    harness.assertEqual(#threads, 1, 'repeated changes must not stack workers')

    advance() -- run the new worker up to its first Wait
    fuelLevel, engineOn = 60, false
    advance()
    harness.assertEqual(fuelLevel, 60, 'engine off consumes nothing')
    engineOn = true
    advance()
    harness.assertTrue(fuelLevel < 60, 'engine running consumes fuel')

    fuelLevel = 0
    advance()
    harness.assertEqual(engineOff, 1, 'empty tank cuts the engine')

    setCache('seat', 1)
    advance()
    harness.assertEqual(#threads, 0, 'worker exits once the player is no longer the driver')
    fuelLevel = 60
    advance()
    harness.assertEqual(fuelLevel, 60, 'no consumption after leaving the driver seat')

    setCache('seat', -1)
    harness.assertEqual(#threads, 1, 'worker restarts when driving again')
    setCache('vehicle', false)
    advance() -- first Wait
    advance()
    harness.assertEqual(#threads, 0, 'worker exits when leaving the vehicle')
end)

harness.test('kora_lib restart re-registers listeners, re-seeds and never duplicates workers', function()
    for _, key in ipairs({ 'vehicle', 'seat', 'ped' }) do
        harness.assertEqual(#cacheHandlers[key], 1, 'normal load registers exactly one ' .. key .. ' handler')
    end
    harness.assertEqual(#threads, 0)
    setCache('vehicle', 2); setCache('seat', -1)
    harness.assertEqual(#threads, 1)

    -- kora_lib restarts: its registrations are gone, the cached values persist.
    cacheHandlers = {}
    legacyEvents.onClientResourceStart('other_resource')
    harness.assertEqual(next(cacheHandlers), nil, 'unrelated resource starts change nothing')
    legacyEvents.onClientResourceStart('kora_lib')
    for _, key in ipairs({ 'vehicle', 'seat', 'ped' }) do
        harness.assertEqual(#cacheHandlers[key], 1, 'restart re-registers one ' .. key .. ' handler')
    end
    harness.assertEqual(#threads, 1, 're-seeding while the worker runs must not start another')

    -- Worker ends, then kora_lib restarts while the player is still driving: seeding restarts it.
    setCache('vehicle', false); setCache('seat', false)
    advance(); advance()
    harness.assertEqual(#threads, 0)
    cacheState.vehicle, cacheState.seat = 2, -1
    cacheHandlers = {}
    legacyEvents.onClientResourceStart('kora_lib')
    harness.assertEqual(#threads, 1, 'seeding from the current cache starts the worker')
    setCache('seat', false)
    advance(); advance()
    harness.assertEqual(#threads, 0)
    setCache('vehicle', false)
end)

harness.report('qbfuel client')
