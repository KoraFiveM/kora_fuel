local function notify(message, kind)
    QB.notify.send({ title = 'Fuel', message = message, type = kind or 'inform' })
end

---@param vehicle integer
---@return boolean
local function isElectricVehicle(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
        and Fuel.isElectricModel(GetEntityModel(vehicle)) or false
end

exports('isElectricVehicle', isElectricVehicle)

local function currentLevel(vehicle)
    return Fuel.clampLevel(GetVehicleFuelLevel(vehicle))
end

local SERVICE_ANIMATION = {
    dict = 'weapon@w_sp_jerrycan',
    clip = 'fire',
    flag = 49,
}

local FUEL_NOZZLE = {
    model = 'prop_cs_fuel_nozle',
    bone = 57005,
    offset = vector3(0.13, 0.04, -0.03),
    rotation = vector3(-42.0, -115.0, -15.0),
}

-- Small public API for garages, admin tools, and third-party vehicle scripts.
-- EVs intentionally return their battery percentage through GetFuel too: it
-- is the shared native level, while isElectricVehicle supplies the meaning.
exports('GetFuel', currentLevel)
exports('SetFuel', function(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    SetVehicleFuelLevel(vehicle, Fuel.clampLevel(level) + 0.0)
    return true
end)

local function nearServicePoint(coords)
    for _, station in ipairs(Config.stations) do
        if #(coords - station) <= Config.serviceRadius then return true end
    end
    return false
end

local function closestServiceVehicle()
    local pedCoords = GetEntityCoords(PlayerPedId())
    if not nearServicePoint(pedCoords) then
        notify('Move to a fuel station or charging point first.', 'error')
        return nil
    end

    local closest = QB.closest.vehicle(pedCoords, Config.vehicleSearchDistance)
    if not closest.id or not DoesEntityExist(closest.id) then
        notify('Park a vehicle next to the pump or charger.', 'error')
        return nil
    end
    if GetIsVehicleEngineRunning(closest.id) then
        notify('Switch the engine off before servicing the vehicle.', 'error')
        return nil
    end
    return closest.id
end

local function serviceVehicle(vehicle, account)
    if not DoesEntityExist(vehicle) then return notify('That vehicle is no longer available.', 'error') end
    if GetIsVehicleEngineRunning(vehicle) then return notify('Switch the engine off before servicing the vehicle.', 'error') end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    local session = QB.callback.trigger('qbfuel:beginService', netId, account)
    if not session or not session.ok then
        return notify(session and session.message or 'Service could not be authorised.', 'error')
    end

    local label = session.electric and 'Charging vehicle' or 'Refuelling vehicle'
    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 750)
    Wait(750)
    if not DoesEntityExist(vehicle) then return notify('That vehicle is no longer available.', 'error') end
    if GetIsVehicleEngineRunning(vehicle) then return notify('Switch the engine off before servicing the vehicle.', 'error') end

    local completed = QB.progressbar.start({
        label = label,
        duration = session.duration,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = SERVICE_ANIMATION,
        props = { FUEL_NOZZLE },
    })
    if not completed then
        TriggerServerEvent('qbfuel:server:cancelService', session.token)
        return notify(label .. ' cancelled.', 'inform')
    end

    TriggerServerEvent('qbfuel:server:serviceVehicle', session.token)
end

local function openPaymentMenu()
    local vehicle = closestServiceVehicle()
    if not vehicle then return end

    local electric = isElectricVehicle(vehicle)
    local kind = electric and 'charge' or 'fuel'
    local unitPrice = Config.pricePerUnit[kind]
    local action = electric and 'Charge vehicle' or 'Refuel vehicle'
    local options = {}

    for _, account in ipairs(Config.paymentAccounts) do
        local selectedAccount = account
        options[#options + 1] = {
            label = ('%s — pay with %s ($%.2f/unit)'):format(action, selectedAccount, unitPrice),
            action = function() serviceVehicle(vehicle, selectedAccount) end,
        }
    end
    QB.interact.open(options)
end

-- Pump interactions work wherever vanilla pumps stream in. The service-area
-- gate remains server-authoritative; EVs use those same service points as
-- charging points, so this needs no custom map or charger-prop dependency.
QB.interact.addModel(Config.pumpModels, {
    { label = 'Service nearby vehicle', icon = 'fuel', action = openPaymentMenu },
}, 2.5)

RegisterNetEvent('qbfuel:client:serviceResult', function(ok, message, level, netId)
    if ok then
        local vehicle = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
        if type(level) == 'number' and vehicle ~= 0 and DoesEntityExist(vehicle) then
            if NetworkHasControlOfEntity(vehicle) then
                SetVehicleFuelLevel(vehicle, Fuel.clampLevel(level) + 0.0)
            end
        end
        notify(message, 'success')
        return
    end
    notify(message or 'Unable to service that vehicle.', 'error')
end)

CreateThread(function()
    while true do
        Wait(Config.consumeInterval)

        local vehicle = QB.cache.vehicle()
        if vehicle and QB.cache.seat() == -1 and GetIsVehicleEngineRunning(vehicle) then
            local level = currentLevel(vehicle)
            if level <= 0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            else
                local class = GetVehicleClass(vehicle)
                local used = Fuel.calculateConsumption(class, GetEntitySpeed(vehicle), Config.consumeInterval)
                local nextLevel = Fuel.clampLevel(level - used)
                SetVehicleFuelLevel(vehicle, nextLevel)
                if nextLevel <= 0 then SetVehicleEngineOn(vehicle, false, true, true) end
            end
        end
    end
end)
