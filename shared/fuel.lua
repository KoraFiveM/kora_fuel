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

---@param account string
---@return boolean
function Fuel.isPaymentAccount(account)
    for _, allowed in ipairs(Config.paymentAccounts or {}) do
        if account == allowed then return true end
    end
    return false
end
