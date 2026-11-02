Fuel = Fuel or {}

local function hash(model)
    if type(model) == 'number' then return model end
    return joaat(model)
end

local electricModels = {}
for _, model in ipairs(Config.electricVehicles or {}) do
    electricModels[hash(model)] = true
end

---@param model number|string
---@return boolean
function Fuel.isElectricModel(model)
    return electricModels[hash(model)] == true
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

---@param coords table|vector3 anything with x/y/z
---@param maxDistance? number only stations within this many metres count
---@return table|nil station nearest charging station
---@return number|nil distance metres to that station
function Fuel.nearestCharger(coords, maxDistance)
    local charging = Config.charging
    if not charging or not coords then return nil end
    local best, bestDistance
    for _, station in ipairs(charging.stations or {}) do
        local at = station.coords
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

---@param kind string 'fuel'|'charge'
---@param quantity number
---@param site? string 'pump' (default) or 'charger'
---@return number
function Fuel.price(kind, quantity, site)
    return math.ceil((tonumber(quantity) or 0) * Fuel.unitPrice(kind, site))
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
