-- Map blips for Config.stations (Config.blips) and Config.charging.stations (Config.charging.blips).
local created = {}

local function removeBlips()
    for i = #created, 1, -1 do
        Kora.blips.remove(created[i])
        created[i] = nil
    end
end

-- Blips go through Kora.blips: tracked per resource, listed under a pause-map
-- category and hideable by the player with /blips.
local function placeBlip(coords, pick, name)
    local options = {
        sprite = pick('sprite'),
        color = pick('colour'),
        scale = pick('scale') + 0.0,
        shortRange = pick('shortRange') == true,
        category = pick('category') or 'Fuel',
        name = name or pick('label'),
    }
    -- A bad category in config must not stop the other blips: retry in Fuel.
    local ok, blip = pcall(Kora.blips.create, coords, options)
    if not ok then
        options.category = 'Fuel'
        ok, blip = pcall(Kora.blips.create, coords, options)
    end
    if ok and blip then created[#created + 1] = blip end
end

local function createChargingBlips()
    local settings = Config.charging and Config.charging.blips
    if not settings or not settings.enabled or not Fuel.chargingEnabled() then return end

    local function pick(key) return settings[key] end
    for _, station in ipairs(Config.charging.stations) do
        local name = settings.label
        if settings.showStationName and station.label then name = ('%s - %s'):format(settings.label, station.label) end
        placeBlip(station.coords, pick, name)
    end
end

local function createBlips()
    removeBlips()
    createChargingBlips()

    local settings = Config.blips
    if not settings or not settings.enabled then return end

    local placed = {}
    local mergeRadius = (settings.mergeRadius or 0.0) + 0.0

    for index, station in ipairs(Config.stations) do
        local override = settings.perStation and settings.perStation[index] or {}
        local function pick(key)
            if override[key] ~= nil then return override[key] end
            return settings[key]
        end

        local duplicate = false
        for _, other in ipairs(placed) do
            local dx, dy = station.x - other.x, station.y - other.y
            if dx * dx + dy * dy < mergeRadius * mergeRadius then
                duplicate = true
                break
            end
        end

        if override.enabled ~= false and not duplicate then
            placed[#placed + 1] = station
            placeBlip(station, pick)
        end
    end
end

CreateThread(createBlips)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removeBlips() end
end)
