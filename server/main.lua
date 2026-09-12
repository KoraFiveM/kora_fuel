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

local sessions = {}

math.randomseed(GetGameTimer() + math.floor(os.clock() * 1000000))

local function token()
    local chars, result = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', {}
    for i = 1, 32 do
        local index = math.random(1, #chars)
        result[i] = chars:sub(index, index)
    end
    return table.concat(result)
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

    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)
    if not nearServicePoint(playerCoords) then
        return nil, 'Move closer to the service point and vehicle.'
    end
    if GetIsVehicleEngineRunning(vehicle) then return nil, 'Switch the engine off before servicing.' end
    return vehicle
end

local function serverLevel(vehicle)
    if type(GetVehicleFuelLevel) ~= 'function' then return nil end
    local level = tonumber(GetVehicleFuelLevel(vehicle))
    if not QB.util.isFiniteNumber(level) then return nil end
    return Fuel.clampLevel(level)
end

QB.callback.register('qbfuel:beginService', function(src, netId, account)
    if not Fuel.isPaymentAccount(account) then return { ok = false, message = 'Invalid payment account.' } end
    local vehicle, vehicleErr = vehicleFor(src, netId)
    if not vehicle then return { ok = false, message = vehicleErr } end

    local level = serverLevel(vehicle)
    if not level then return { ok = false, message = 'Fuel state is unavailable.' } end

    local missing = Config.maxLevel - level
    if missing < 0.5 then return { ok = false, message = 'Vehicle is already full.' } end

    local electric = Fuel.isElectricModel(GetEntityModel(vehicle))
    local duration = math.max(Config.minimumProgressMs, math.floor(missing * Config.progressMsPerUnit))
    local current = GetGameTimer()
    local id = token()
    sessions[src] = {
        token = id,
        netId = netId,
        account = account,
        electric = electric,
        readyAt = current + duration,
        expiresAt = current + duration + Config.serviceSessionGraceMs,
    }
    return { ok = true, token = id, duration = duration, electric = electric }
end, { rateLimit = Config.serviceRateLimit })

RegisterNetEvent('qbfuel:server:serviceVehicle', function(serviceToken)
    local src = source
    local session = sessions[src]
    if not session or type(serviceToken) ~= 'string' or session.token ~= serviceToken then
        return sendResult(src, false, 'Invalid or expired service session.')
    end
    local current = GetGameTimer()
    if current < session.readyAt then return sendResult(src, false, 'Finish servicing the vehicle first.') end
    sessions[src] = nil
    if current > session.expiresAt then return sendResult(src, false, 'Service session expired.') end

    local vehicle, vehicleErr = vehicleFor(src, session.netId)
    if not vehicle then return sendResult(src, false, vehicleErr) end
    local level = serverLevel(vehicle)
    if not level then return sendResult(src, false, 'Fuel state is unavailable.') end
    local missing = Config.maxLevel - level
    if missing < 0.5 then return sendResult(src, false, 'Vehicle is already full.') end

    local kind = session.electric and 'charge' or 'fuel'
    local price = math.ceil(missing * Config.pricePerUnit[kind])
    local paid, err = exports.qbcore:removeMoney(src, session.account, price, ('%s vehicle %s'):format(kind, session.netId))
    if not paid then return sendResult(src, false, err == 'insufficient funds' and 'Insufficient funds.' or 'Payment could not be processed.') end

    if type(SetVehicleFuelLevel) == 'function' then SetVehicleFuelLevel(vehicle, Config.maxLevel + 0.0) end
    local noun = session.electric and 'charged' or 'refuelled'
    sendResult(src, true, ('Vehicle %s for $%d.'):format(noun, price), Config.maxLevel, session.netId)
end)

RegisterNetEvent('qbfuel:server:cancelService', function(serviceToken)
    local session = sessions[source]
    if session and type(serviceToken) == 'string' and session.token == serviceToken then sessions[source] = nil end
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) sessions[src] = nil end)
