-- Charging station loading, shared by both realms. Loaded before config.lua so
-- the authored list is cleaned before kora_lib's schema sees it: one bad entry
-- is skipped with a warning instead of failing the whole resource config.
Fuel = Fuel or {}

local function finite(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

---Converts a vector3 (vec3), an {x =, y =, z =} table (what JSON, msgpack and
---kora_lib's saved overrides turn vectors into) or an {x, y, z} array into a
---vector3.
---@param value any
---@return vector3|nil vector nil when the value is not a finite 3D position
function Fuel.toVector3(value)
    local kind = type(value)
    if kind == 'vector3' then return value end
    if kind ~= 'table' then return nil end
    local x, y, z = rawget(value, 'x'), rawget(value, 'y'), rawget(value, 'z')
    if x == nil and y == nil and z == nil then x, y, z = value[1], value[2], value[3] end
    if not (finite(x) and finite(y) and finite(z)) then return nil end
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

local VECTOR_SHAPES = 'a vector3, {x = , y = , z = } or {x, y, z}'

-- Returns the cleaned station, or nil plus the offending field and the reason.
local function normalizeStation(station)
    if type(station) ~= 'table' then return nil, 'entry', 'must be a table' end
    if type(station.label) ~= 'string' or station.label:match('^%s*$') then
        return nil, 'label', 'must be non-empty text'
    end
    local coords = Fuel.toVector3(station.coords)
    if not coords then return nil, 'coords', 'must be ' .. VECTOR_SHAPES end
    local offset
    if station.offset ~= nil then
        offset = Fuel.toVector3(station.offset)
        if not offset then return nil, 'offset', 'must be ' .. VECTOR_SHAPES .. ' (or left out)' end
    end
    if station.heading ~= nil and not finite(station.heading) then
        return nil, 'heading', 'must be a number of degrees (or left out)'
    end
    if station.radius ~= nil and not (finite(station.radius) and station.radius >= 0) then
        return nil, 'radius', 'must be a number of metres, 0 or more (or left out)'
    end
    if station.hideModel ~= nil and type(station.hideModel) ~= 'string' then
        return nil, 'hideModel', 'must be a model name (or left out)'
    end

    local out = {}
    for key, value in pairs(station) do out[key] = value end
    out.coords, out.offset = coords, offset
    out.heading = (station.heading or 0.0) + 0.0
    return out
end

---Validates Config.charging.stations one entry at a time. Valid stations come
---back with coords/offset as vector3; an invalid one is left out with a single
---warning naming its index, label and the field at fault.
---@param stations any the authored or overridden station list
---@return table stations
function Fuel.normalizeChargingStations(stations)
    local out = {}
    if type(stations) ~= 'table' then return out end
    for index, station in ipairs(stations) do
        local clean, field, reason = normalizeStation(station)
        if clean then
            out[#out + 1] = clean
        else
            local label = type(station) == 'table' and type(station.label) == 'string' and station.label ~= ''
                and ('%q'):format(station.label) or 'without a label'
            print(('^3[kora_fuel] Skipping EV charging station #%d %s: %s %s.^7'):format(index, label, field, reason))
        end
    end
    return out
end
