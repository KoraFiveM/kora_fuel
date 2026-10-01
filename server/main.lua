local busy = {}

local function getBalance(src, account)
    return exports.qbcore:getMoney(src, account)
end

local function askClient(src, name, ...)
    return QB.callback.trigger(src, name, ...)
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function nearServicePoint(coords)
    for _, station in ipairs(Config.stations) do
        if distance(coords, station) <= Config.serviceRadius then return true end
    end
    return false
end

local function sendResult(src, ok, message)
    TriggerClientEvent('qbfuel:client:serviceResult', src, ok, message)
end

local function vehicleFor(src, netId)
    local vehicle, reason = QB.world.resolveNetworkEntity(src, netId, {
        entityType = 'vehicle',
        maxDistance = Config.vehicleSearchDistance + 1.0,
    })
    if not vehicle then
        if reason == 'invalid_network_id' then return nil, 'Invalid service request.' end
        if reason == 'routing_bucket_mismatch' then return nil, 'Vehicle is in another instance.' end
        if reason == 'too_far' then return nil, 'Move closer to the service point and vehicle.' end
        return nil, 'Vehicle is no longer available.'
    end

    if not nearServicePoint(GetEntityCoords(GetPlayerPed(src))) then
        return nil, 'Move closer to the service point and vehicle.'
    end
    if GetIsVehicleEngineRunning(vehicle) then return nil, 'Switch the engine off before servicing.' end
    return vehicle
end

local function validate(src, netId, account, quantity, currentLevel)
    if not Fuel.isPaymentAccount(account) then return nil, 'Invalid payment account.' end

    currentLevel = tonumber(currentLevel)
    quantity = tonumber(quantity)
    if not currentLevel or not quantity or quantity ~= math.floor(quantity) then
        return nil, 'Invalid service request.'
    end
    currentLevel = math.floor(currentLevel)

    local capacity = math.floor(Config.maxLevel) - currentLevel
    if capacity < 1 then return nil, 'Vehicle is already full.' end
    if quantity < 1 or quantity > capacity then return nil, 'Invalid fill amount.' end

    local vehicle, vehicleErr = vehicleFor(src, netId)
    if not vehicle then return nil, vehicleErr end

    local electric = Fuel.isElectricModel(GetEntityModel(vehicle))
    local kind = electric and 'charge' or 'fuel'
    local price = Fuel.price(kind, quantity)

    local balance = tonumber(getBalance(src, account)) or 0
    if balance < price then return nil, 'Insufficient funds.' end

    return { electric = electric, kind = kind, price = price }
end

RegisterNetEvent('qbfuel:server:purchase', function(netId, account, quantity, currentLevel)
    local src = source
    if busy[src] then return end
    busy[src] = true

    local ok, err = pcall(function()
        local info, reason = validate(src, netId, account, quantity, currentLevel)
        if not info then return sendResult(src, false, reason) end

        local completed = askClient(src, 'qbfuel:runProgress', netId, Fuel.progressDuration(quantity), info.electric)
        if completed ~= true then return end

        info, reason = validate(src, netId, account, quantity, currentLevel)
        if not info then return sendResult(src, false, reason) end
        QB.print.debug(netId, account, quantity, currentLevel, info)
        local paid, payErr = exports.qbcore:removeMoney(src, account, info.price, ('%s vehicle %s'):format(info.kind, netId))
        if not paid then
            return sendResult(src, false, payErr == 'insufficient funds' and 'Insufficient funds.' or 'Payment could not be processed.')
        end

        TriggerClientEvent('qbfuel:client:fillVehicle', src, netId, quantity)
        sendResult(src, true, ('Vehicle %s for $%d.'):format(info.electric and 'charged' or 'refuelled', info.price))
    end)

    busy[src] = nil
    if not ok then
        print(('[qbfuel] purchase error for %s: %s'):format(src, tostring(err)))
        sendResult(src, false, 'Payment could not be processed.')
    end
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) busy[src] = nil end)
