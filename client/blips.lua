-- Map blips for Config.stations (Config.blips) and Config.charging.stations (Config.charging.blips).
-- Each set is a group. A group with nearestOnly shows one blip, for the
-- station nearest the player; it is re-picked from Kora.cache coords changes,
-- and only once the player has moved NEAREST_RECHECK metres since the last
-- pick, so walking around a forecourt does no work.
local NEAREST_RECHECK = 50.0

local groups = {
    charging = { blips = {}, entries = {} },
    gas = { blips = {}, entries = {} },
}

local function clearGroup(group)
    for i = #group.blips, 1, -1 do
        Kora.blips.remove(group.blips[i])
        group.blips[i] = nil
    end
    group.shown = nil
end

local function removeBlips()
    clearGroup(groups.charging)
    clearGroup(groups.gas)
end

-- Blips go through Kora.blips: tracked per resource, listed under a pause-map
-- category and hideable by the player with /blips.
local function placeBlip(group, entry)
    local pick = entry.pick
    local options = {
        sprite = pick('sprite'),
        color = pick('colour'),
        scale = pick('scale') + 0.0,
        shortRange = pick('shortRange') == true,
        category = pick('category') or 'Fuel',
        name = entry.name or pick('label'),
    }
    -- A bad category in config must not stop the other blips: retry in Fuel.
    local ok, blip = pcall(Kora.blips.create, entry.coords, options)
    if not ok then
        options.category = 'Fuel'
        ok, blip = pcall(Kora.blips.create, entry.coords, options)
    end
    if ok and blip then group.blips[#group.blips + 1] = blip end
end

local function nearestEntry(entries, coords)
    local best, bestDistance
    for _, entry in ipairs(entries) do
        local dx, dy = entry.coords.x - coords.x, entry.coords.y - coords.y
        local distance = dx * dx + dy * dy
        if not bestDistance or distance < bestDistance then best, bestDistance = entry, distance end
    end
    return best
end

local function showNearest(group, coords)
    local entry = coords and nearestEntry(group.entries, coords)
    if not entry or entry == group.shown then return end
    clearGroup(group)
    placeBlip(group, entry)
    group.shown = entry
end

local function playerCoords()
    local coords = Kora.cache.coords and Kora.cache.coords()
    if coords then return coords end
    return GetEntityCoords(PlayerPedId())
end

local lastPick
local function onCoords(coords)
    if not coords then return end
    if lastPick then
        local dx, dy = coords.x - lastPick.x, coords.y - lastPick.y
        if dx * dx + dy * dy < NEAREST_RECHECK * NEAREST_RECHECK then return end
    end
    lastPick = { x = coords.x, y = coords.y }
    for _, group in pairs(groups) do
        if group.nearestOnly then showNearest(group, coords) end
    end
end

-- kora_lib drops onChange listeners when it restarts, so the listener is
-- registered again then (see the onClientResourceStart handler below).
local watching = false
local function watchCoords()
    if watching or not (groups.gas.nearestOnly or groups.charging.nearestOnly) then return end
    watching = true
    Kora.cache.onChange('coords', onCoords)
end

local function showGroup(group, entries, nearestOnly)
    clearGroup(group)
    group.entries, group.nearestOnly = entries, nearestOnly == true
    if group.nearestOnly then
        local coords = playerCoords()
        lastPick = { x = coords.x, y = coords.y }
        showNearest(group, coords)
        return
    end
    for _, entry in ipairs(entries) do placeBlip(group, entry) end
end

local function chargingEntries()
    local settings = Config.charging and Config.charging.blips
    if not settings or not settings.enabled or not Fuel.chargingEnabled() then return {}, false end

    local function pick(key) return settings[key] end
    local entries = {}
    for _, station in ipairs(Config.charging.stations) do
        local name = settings.label
        if settings.showStationName and station.label then name = ('%s - %s'):format(settings.label, station.label) end
        entries[#entries + 1] = { coords = Fuel.chargerPosition(station), pick = pick, name = name }
    end
    return entries, settings.nearestOnly
end

local function gasEntries()
    local settings = Config.blips
    if not settings or not settings.enabled then return {}, false end

    local entries = {}
    local mergeRadius = (settings.mergeRadius or 0.0) + 0.0

    for index, station in ipairs(Config.stations) do
        local override = settings.perStation and settings.perStation[index] or {}
        local function pick(key)
            if override[key] ~= nil then return override[key] end
            return settings[key]
        end

        local duplicate = false
        for _, other in ipairs(entries) do
            local dx, dy = station.x - other.coords.x, station.y - other.coords.y
            if dx * dx + dy * dy < mergeRadius * mergeRadius then
                duplicate = true
                break
            end
        end

        if override.enabled ~= false and not duplicate then
            entries[#entries + 1] = { coords = station, pick = pick }
        end
    end
    return entries, settings.nearestOnly
end

local function createBlips()
    removeBlips()
    showGroup(groups.charging, chargingEntries())
    showGroup(groups.gas, gasEntries())
    watchCoords()
end

CreateThread(createBlips)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'kora_lib' then return end
    watching = false
    watchCoords()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removeBlips() end
end)
