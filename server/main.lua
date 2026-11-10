local busy = {}

local function nearServicePoint(coords)
    for _, station in ipairs(Config.stations) do
        if Kora.distance.coords(coords, station, Config.serviceRadius) then return true end
    end
    return false
end

-- Charging stations have their own range and list; 'pump' covers Config.stations.
local function nearSite(coords, site)
    if site == 'charger' then
        return Fuel.chargingEnabled() and Fuel.nearestCharger(coords, Config.charging.serviceRadius) ~= nil
    end
    return nearServicePoint(coords)
end

-- `electric` picks the client toast title ('Charging' rather than 'Fuel').
local function sendResult(src, ok, message, electric)
    TriggerClientEvent('kora_fuel:client:serviceResult', src, ok, message, electric == true)
end

local function vehicleFor(src, netId, site)
    local vehicle, reason = Kora.world.resolveNetworkEntity(src, netId, {
        entityType = 'vehicle',
        maxDistance = Config.vehicleSearchDistance + 1.0,
    })
    if not vehicle then
        if reason == 'invalid_network_id' then return nil, 'Invalid service request.' end
        if reason == 'routing_bucket_mismatch' then return nil, 'Vehicle is in another instance.' end
        if reason == 'too_far' then return nil, 'Move closer to the service point and vehicle.' end
        return nil, 'Vehicle is no longer available.'
    end

    if not nearSite(GetEntityCoords(GetPlayerPed(src)), site) then
        return nil, 'Move closer to the service point and vehicle.'
    end
    if GetIsVehicleEngineRunning(vehicle) then return nil, 'Switch the engine off before servicing.' end
    return vehicle
end

local function validate(src, netId, account, quantity, currentLevel, site)
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

    local vehicle, vehicleErr = vehicleFor(src, netId, site)
    if not vehicle then return nil, vehicleErr end

    local electric = Fuel.isElectricModel(GetEntityModel(vehicle))
    if site == 'pump' and electric and not Fuel.pumpsAcceptElectric() then
        return nil, 'Electric vehicles must use a charging station.'
    end
    -- A model the server does not list as electric is billed as petrol even at a
    -- charging station, so the client cannot buy cheaper energy by mislabelling.
    local kind = electric and 'charge' or 'fuel'
    local price = Fuel.price(kind, quantity, site)

    local balance = tonumber(exports.kora_core:getMoney(src, account)) or 0
    if balance < price then return nil, 'Insufficient funds.' end

    return { electric = electric, kind = kind, price = price, site = site }
end

RegisterNetEvent('kora_fuel:server:purchase', function(netId, account, quantity, currentLevel, site)
    local src = source
    if busy[src] then return end
    busy[src] = true
    site = site == 'charger' and 'charger' or 'pump'
    local atCharger = site == 'charger'

    local ok, err = pcall(function()
        local info, reason = validate(src, netId, account, quantity, currentLevel, site)
        if not info then return sendResult(src, false, reason, atCharger) end

        local completed = Kora.callback.trigger(src, 'kora_fuel:runProgress', netId, Fuel.progressDuration(quantity, info.kind, info.site), info.electric)
        if completed ~= true then return end

        info, reason = validate(src, netId, account, quantity, currentLevel, site)
        if not info then return sendResult(src, false, reason, atCharger) end
        Kora.print.debug(netId, account, quantity, currentLevel, info)
        -- A free total (price 0, or rounded down to 0) has nothing to take:
        -- kora_core refuses a zero removal, which would fail the service.
        if info.price > 0 then
            local paid, payErr = exports.kora_core:removeMoney(src, account, info.price, ('%s vehicle %s'):format(info.kind, netId))
            if not paid then
                return sendResult(src, false, payErr == 'insufficient funds' and 'Insufficient funds.' or 'Payment could not be processed.',
                    info.electric)
            end
        end

        TriggerClientEvent('kora_fuel:client:fillVehicle', src, netId, quantity)
        sendResult(src, true, ('Vehicle %s for $%d.'):format(info.electric and 'charged' or 'refuelled', info.price), info.electric)
    end)

    busy[src] = nil
    if not ok then
        print(('[kora_fuel] purchase error for %s: %s'):format(src, tostring(err)))
        sendResult(src, false, 'Payment could not be processed.', site == 'charger')
    end
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src) busy[src] = nil end)
