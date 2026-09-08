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
