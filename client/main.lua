local function notify(message, kind)
    Kora.notify.send({ title = 'Fuel', message = message, type = kind or 'info' })
end

---@param vehicle integer
---@return boolean
local function isElectricVehicle(vehicle)
    return vehicle and vehicle ~= 0 and DoesEntityExist(vehicle)
        and Fuel.isElectricModel(GetEntityModel(vehicle)) or false
end

exports('isElectricVehicle', isElectricVehicle)

-- Display/service level: whole numbers only.
local function currentLevel(vehicle)
    return math.floor(Fuel.clampLevel(GetVehicleFuelLevel(vehicle)))
end

-- Drain needs the unrounded value, otherwise every tick would cost a full unit.
local function rawLevel(vehicle)
    return Fuel.clampLevel(GetVehicleFuelLevel(vehicle))
end

local serviceAnimation = {
    dict = 'weapon@w_sp_jerrycan',
    clip = 'fire',
    flag = 49,
}

local fuelNozzle = {
    model = 'prop_cs_fuel_nozle',
    bone = 57005,
    offset = vector3(0.13, 0.04, -0.03),
    rotation = vector3(-42.0, -115.0, -15.0),
}

exports('GetFuel', currentLevel)
local function setFuel(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    SetVehicleFuelLevel(vehicle, Fuel.clampLevel(level) + 0.0)
    return true
end
exports('SetFuel', setFuel)

-- Keep LegacyFuel's fractional reads and nil return while using native fuel state.
Kora.compat.provideExport('LegacyFuel', 'GetFuel', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    return GetVehicleFuelLevel(vehicle)
end)
Kora.compat.provideExport('LegacyFuel', 'SetFuel', function(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    if type(level) ~= 'number' or level ~= level or math.abs(level) == math.huge then return end
    NetworkRequestControlOfEntity(vehicle)
    setFuel(vehicle, level)
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

    local closest = Kora.closest.vehicle(pedCoords, Config.vehicleSearchDistance)
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

local appId = 'qbfuel:pump'

local function titleCase(text)
    return (tostring(text):gsub('^%l', string.upper))
end

-- Static for the lifetime of the shell. Per-open values (netId, level, capacity)
-- travel in openApp's private `data` and come back as `context.data`.
local function onAppAction(actionId, context)
    if actionId ~= 'fuel-submit' then return end

    local data, value = context.data, context.value
    if type(data) ~= 'table' or type(value) ~= 'table' then return end

    local quantity = math.floor(tonumber(value.quantity) or 0)
    if quantity < 1 or quantity > data.capacity then
        return { notice = { tone = 'destructive', message = 'Invalid fill amount.' } }
    end

    TriggerServerEvent('qbfuel:server:purchase', data.netId, value.account, quantity, data.level)
    return { close = true }
end

local function buildApp(spec)
    local accountOptions = {}
    for _, account in ipairs(spec.accounts) do
        accountOptions[#accountOptions + 1] = { value = account, label = titleCase(account) }
    end

    local unitLabel = spec.electric and 'charge' or 'fuel'

    local definition = {
        id = appId,
        title = spec.title,
        description = spec.electric and 'Battery charge' or 'Petrol pump',
        icon = spec.electric and 'Zap' or 'Fuel',
        layout = 'compact',
        placement = 'right',
        width = 420,
        defaultView = 'service',
        navigation = {
            {
                id = 'service',
                label = spec.title,
                content = {
                    blocks = {
                        {
                            type = 'progress',
                            items = {
                                {
                                    label = titleCase(unitLabel) .. ' level',
                                    value = spec.level,
                                    max = Config.maxLevel,
                                    detail = ('%d / %d'):format(spec.level, math.floor(Config.maxLevel)),
                                    tone = spec.level <= 15 and 'destructive' or 'primary',
                                },
                            },
                        },
                        {
                            type = 'stats',
                            items = {
                                { label = 'Price per unit', value = ('$%.2f'):format(spec.unitPrice) },
                                {
                                    label = 'Total Price',
                                    value = ('$%d'):format(spec.priceFor(spec.capacity)),
                                    description = ('%d units'):format(spec.capacity),
                                },
                            },
                        },
                        {
                            type = 'form',
                            id = 'fuel-form',
                            submitLabel = spec.electric and 'Charge' or 'Fill up',
                            action = { id = 'fuel-submit', label = 'Confirm', closeBeforeAction = true },
                            fields = {
                                {
                                    id = 'quantity',
                                    label = 'Amount to add',
                                    description = ('$%.2f per unit, up to %d units.'):format(spec.unitPrice, spec.capacity),
                                    type = 'range',
                                    min = 1,
                                    max = spec.capacity,
                                    step = 1,
                                    wholeNumber = true,
                                    default = spec.capacity,
                                    required = true,
                                },
                                {
                                    id = 'account',
                                    label = 'Pay with',
                                    type = 'select',
                                    options = accountOptions,
                                    default = spec.accounts[1],
                                    required = true,
                                },
                            },
                        },
                    },
                },
            },
        },
        onAction = onAppAction,
    }
    definition.onChange = function(actionId, context)
        if actionId ~= 'fuel-submit' then return end
        local quantity = tonumber(context.value.quantity)
        if not quantity or quantity % 1 ~= 0 or quantity < 1 or quantity > spec.capacity then return end

        local total = definition.navigation[1].content.blocks[2].items[2]
        total.value = ('$%d'):format(spec.priceFor(quantity))
        total.description = ('%d units'):format(quantity)
        return { navigation = definition.navigation }
    end
    return definition
end

local function openFuelMenu()
    local vehicle = closestServiceVehicle()
    if not vehicle then return end

    local level = currentLevel(vehicle)
    local capacity = math.floor(Config.maxLevel) - level
    if capacity < 1 then return notify('Vehicle is already full.', 'info') end

    local electric = isElectricVehicle(vehicle)
    local kind = electric and 'charge' or 'fuel'
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    Kora.nui.registerApp(buildApp({
        title = electric and 'Charge vehicle' or 'Refuel vehicle',
        electric = electric,
        level = level,
        capacity = capacity,
        accounts = Config.paymentAccounts,
        unitPrice = Config.pricePerUnit[kind],
        priceFor = function(quantity) return Fuel.price(kind, quantity) end,
    }))

    Kora.nui.openApp(appId, {
        data = { netId = netId, level = level, capacity = capacity },
    })
end

Kora.interact.addModel(Config.pumpModels, {
    { label = 'Service nearby vehicle', icon = 'fuel', action = openFuelMenu },
}, 2.5)

Kora.callback.register('qbfuel:runProgress', function(netId, duration, electric)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    if GetIsVehicleEngineRunning(vehicle) then return false end

    local ped = PlayerPedId()
    TaskTurnPedToFaceEntity(ped, vehicle, 750)
    Wait(750)
    if not DoesEntityExist(vehicle) or GetIsVehicleEngineRunning(vehicle) then return false end

    local label = electric and 'Charging vehicle' or 'Refuelling vehicle'
    local completed = Kora.progressbar.start({
        label = label,
        duration = duration,
        canCancel = true,
        disable = { move = true, combat = true },
        anim = serviceAnimation,
        props = { fuelNozzle },
    })
    if not completed then notify(label .. ' cancelled.', 'info') end
    return completed == true
end)

RegisterNetEvent('qbfuel:client:fillVehicle', function(netId, quantity)
    if source ~= 65535 then return end
    local vehicle = type(netId) == 'number' and NetworkGetEntityFromNetworkId(netId) or 0
    if vehicle == 0 or not DoesEntityExist(vehicle) or type(quantity) ~= 'number' then return end
    SetVehicleFuelLevel(vehicle, Fuel.clampLevel(currentLevel(vehicle) + quantity) + 0.0)
end)

RegisterNetEvent('qbfuel:client:serviceResult', function(ok, message)
    notify(message or 'Unable to service that vehicle.', ok and 'success' or 'error')
end)

CreateThread(function()
    while true do
        Wait(Config.consumeInterval)

        local vehicle = Kora.cache.vehicle()
        if vehicle and Kora.cache.seat() == -1 and GetIsVehicleEngineRunning(vehicle) then
            local level = rawLevel(vehicle)
            if level <= 0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            else
                local used = Fuel.calculateConsumption(GetVehicleClass(vehicle), GetEntitySpeed(vehicle), Config.consumeInterval)
                local nextLevel = Fuel.clampLevel(level - used)
                SetVehicleFuelLevel(vehicle, nextLevel)
                if nextLevel <= 0 then SetVehicleEngineOn(vehicle, false, true, true) end
            end
        end
    end
end)
