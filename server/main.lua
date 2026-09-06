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

local function sendResult(src, ok, message, level, netId)
    TriggerClientEvent('qbfuel:client:serviceResult', src, ok, message, level, netId)
end

RegisterNetEvent('qbfuel:server:serviceVehicle', function(netId, account, level)
    local src = source
    if type(netId) ~= 'number' or netId < 1 or not Fuel.isPaymentAccount(account)
        or type(level) ~= 'number' or level ~= level or level < 0 or level > Config.maxLevel then
        return sendResult(src, false, 'Invalid service request.')
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local ped = GetPlayerPed(src)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2
        or not ped or ped == 0 or not DoesEntityExist(ped) then
        return sendResult(src, false, 'Vehicle is no longer available.')
    end

    local playerCoords, vehicleCoords = GetEntityCoords(ped), GetEntityCoords(vehicle)
    if distance(playerCoords, vehicleCoords) > Config.vehicleSearchDistance + 1.0 or not nearServicePoint(playerCoords) then
        return sendResult(src, false, 'Move closer to the service point and vehicle.')
    end
    if GetIsVehicleEngineRunning(vehicle) then return sendResult(src, false, 'Switch the engine off before servicing.') end

    level = Fuel.clampLevel(level)
    local missing = Config.maxLevel - level
    if missing < 0.5 then return sendResult(src, false, 'Vehicle is already full.') end

    local electric = Fuel.isElectricModel(GetEntityModel(vehicle))
    local kind = electric and 'charge' or 'fuel'
    local price = math.ceil(missing * Config.pricePerUnit[kind])
    local paid, err = exports.qbcore:removeMoney(src, account, price, ('%s vehicle %s'):format(kind, netId))
    if not paid then return sendResult(src, false, err == 'insufficient funds' and 'Insufficient funds.' or 'Payment could not be processed.') end

    local noun = electric and 'charged' or 'refuelled'
    sendResult(src, true, ('Vehicle %s for $%d.'):format(noun, price), Config.maxLevel, netId)
end)
