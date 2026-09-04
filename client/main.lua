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
    if IsVehicleEngineRunning(closest.id) then
        notify('Switch the engine off before servicing the vehicle.', 'error')
        return nil
    end
    return closest.id
end

local function serviceVehicle(vehicle, account)
    if not DoesEntityExist(vehicle) then return notify('That vehicle is no longer available.', 'error') end
    if IsVehicleEngineRunning(vehicle) then return notify('Switch the engine off before servicing the vehicle.', 'error') end

    local electric = isElectricVehicle(vehicle)
    local level = currentLevel(vehicle)
    local missing = Config.maxLevel - level
    if missing < 0.5 then
        return notify(electric and 'Battery is already fully charged.' or 'Fuel tank is already full.', 'inform')
    end

    local label = electric and 'Charging vehicle' or 'Refuelling vehicle'
    local completed = QB.progressbar.start({
        label = label,
        duration = math.max(Config.minimumProgressMs, math.floor(missing * Config.progressMsPerUnit)),
        canCancel = true,
        disable = { move = true, combat = true },
        scenario = { name = electric and 'WORLD_HUMAN_STAND_MOBILE' or 'WORLD_HUMAN_GARDENER_PLANT' },
    })
    if not completed then return notify(label .. ' cancelled.', 'inform') end

    TriggerServerEvent('qbfuel:server:serviceVehicle', NetworkGetNetworkIdFromEntity(vehicle), account)
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

RegisterNetEvent('qbfuel:client:serviceResult', function(ok, message, level)
    if ok then
        notify(message, 'success')
        return
    end
    notify(message or 'Unable to service that vehicle.', 'error')
end)

CreateThread(function()
    while true do
        Wait(Config.consumeInterval)

        local vehicle = QB.cache.vehicle()
        if vehicle and QB.cache.seat() == -1 and IsVehicleEngineRunning(vehicle) and GetEntitySpeed(vehicle) >= 0.5 then
            local level = currentLevel(vehicle)
            if level <= 0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            else
                local class = GetVehicleClass(vehicle)
                local rate = Config.consumePerSecond[class] or Config.consumePerSecond.default
                local rpm = math.max(0.15, GetVehicleCurrentRpm(vehicle))
                local used = rate * (rpm * rpm) * (Config.consumeInterval / 1000)
                local nextLevel = Fuel.clampLevel(level - used)
                SetVehicleFuelLevel(vehicle, nextLevel)
                if nextLevel <= 0 then SetVehicleEngineOn(vehicle, false, true, true) end
            end
        end
    end
end)
