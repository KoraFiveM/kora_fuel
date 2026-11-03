Fuel = Fuel or {}

local function hash(model)
    if type(model) == 'number' then return model end
    return joaat(model)
end

-- The hash set is derived from Config.electricVehicles and rebuilt whenever that
-- table is replaced. On the client kora_lib applies saved overrides after this
-- script has loaded, so a set built once at load time would keep the authored
-- list and misclassify models an owner added.
local electricModels, electricSource = {}, nil

local function electricSet()
    local list = Config.electricVehicles
    if list ~= electricSource then
        electricModels, electricSource = {}, list
        for _, model in ipairs(list or {}) do
            if type(model) == 'string' then model = model:match('^%s*(.-)%s*$') end
            if model ~= '' then electricModels[hash(model)] = true end
        end
    end
    return electricModels
end

---@param model number|string
---@return boolean
function Fuel.isElectricModel(model)
    return electricSet()[hash(model)] == true
end

---@param value number|nil
---@return number
function Fuel.clampLevel(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > Config.maxLevel then return Config.maxLevel end
    return value
end

---@param vehicleClass number
---@param speed number metres per second
---@param intervalMs number
---@return number usedFuel
function Fuel.calculateConsumption(vehicleClass, speed, intervalMs)
    local rate = Config.consumePerSecond[vehicleClass] or Config.consumePerSecond.default
    local speedMultiplier = (tonumber(speed) or 0) / Config.speedReference
    local multiplier = math.max(Config.idleConsumptionMultiplier, speedMultiplier)
    multiplier = math.min(multiplier, Config.maxSpeedConsumptionMultiplier)

    return rate * multiplier * ((tonumber(intervalMs) or Config.consumeInterval) / 1000)
end

---@param account string
---@return boolean
function Fuel.isPaymentAccount(account)
    for _, allowed in ipairs(Config.paymentAccounts or {}) do
        if account == allowed then return true end
    end
    return false
end

---Where a charging station's charger stands: its ground `coords` plus the
---optional world-space `offset` in metres.
---@param station table a Config.charging.stations entry
---@return table|vector3 position
function Fuel.chargerPosition(station)
    local at, offset = station.coords, station.offset
    if type(offset) ~= 'table' and type(offset) ~= 'vector3' then return at end
    local dx, dy, dz = tonumber(offset.x) or 0.0, tonumber(offset.y) or 0.0, tonumber(offset.z) or 0.0
    if dx == 0.0 and dy == 0.0 and dz == 0.0 then return at end
    return vector3(at.x + dx, at.y + dy, at.z + dz)
end

---@param coords table|vector3 anything with x/y/z
---@param maxDistance? number only stations within this many metres count
---@return table|nil station nearest charging station
---@return number|nil distance metres to that station
function Fuel.nearestCharger(coords, maxDistance)
    local charging = Config.charging
    if not charging or not coords then return nil end
    local best, bestDistance
    for _, station in ipairs(charging.stations or {}) do
        local at = Fuel.chargerPosition(station)
        local dx, dy, dz = coords.x - at.x, coords.y - at.y, coords.z - at.z
        local distance = math.sqrt(dx * dx + dy * dy + dz * dz)
        if not bestDistance or distance < bestDistance then best, bestDistance = station, distance end
    end
    if best and (not maxDistance or bestDistance <= maxDistance) then return best, bestDistance end
end

---True when dedicated EV charging stations are configured and switched on.
---@return boolean
function Fuel.chargingEnabled()
    local charging = Config.charging
    return charging ~= nil and charging.enabled == true and type(charging.stations) == 'table' and #charging.stations > 0
end

---Whether petrol pumps may service electric vehicles. They always may when
---there is no charging network to send EV drivers to.
---@return boolean
function Fuel.pumpsAcceptElectric()
    return not Fuel.chargingEnabled() or Config.charging.allowAtPumps == true
end

local function chargerRates(kind, site)
    return kind == 'charge' and site == 'charger' and Config.charging or nil
end

---@param kind string 'fuel'|'charge'
---@param site? string 'pump' (default) or 'charger'
---@return number
function Fuel.unitPrice(kind, site)
    local charging = chargerRates(kind, site)
    return charging and tonumber(charging.pricePerPercent) or (Config.pricePerUnit[kind] or 0)
end

---Units times the unit price in cents, before rounding to whole dollars. The
---cent rounding keeps float noise (100 x 1.1 = 110.00000000000001) from
---tipping a whole total up a dollar.
---@param kind string 'fuel'|'charge'
---@param quantity number
---@param site? string 'pump' (default) or 'charger'
---@return number
function Fuel.exactPrice(kind, quantity, site)
    local exact = (tonumber(quantity) or 0) * Fuel.unitPrice(kind, site)
    return math.floor(exact * 100 + 0.5) / 100
end

local rounders = {
    up = math.ceil,
    nearest = function(value) return math.floor(value + 0.5) end,
    down = math.floor,
}

---The whole-dollar amount actually charged (Config.priceRounding).
---@param kind string 'fuel'|'charge'
---@param quantity number
---@param site? string 'pump' (default) or 'charger'
---@return integer
function Fuel.price(kind, quantity, site)
    local round = rounders[Config.priceRounding] or rounders.up
    return math.tointeger(round(Fuel.exactPrice(kind, quantity, site))) or 0
end

---@param quantity number
---@param kind? string 'fuel'|'charge'
---@param site? string 'pump' (default) or 'charger'
---@return number
function Fuel.progressDuration(quantity, kind, site)
    local charging = chargerRates(kind, site)
    local msPerUnit = charging and (tonumber(charging.secondsPerPercent) or 0) * 1000 or Config.progressMsPerUnit
    return math.max(Config.minimumProgressMs, math.floor(quantity * msPerUnit))
end
