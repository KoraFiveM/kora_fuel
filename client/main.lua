local function notify(message, kind)
    Kora.notify.send({ title = 'Fuel', message = message, type = kind or 'info' })
end

-- GetIsVehicleElectric is missing on older game builds, so every call is
-- guarded. It takes a vehicle model hash, not an entity handle. Results are
-- memoised per model: the answer never changes for a model.
local nativeElectric = {}

local function isNativeElectric(vehicle)
    if not Config.electric or not Config.electric.useNative then return false end
    local model = GetEntityModel(vehicle)
    local known = nativeElectric[model]
    if known == nil then
        local ok, result = pcall(GetIsVehicleElectric, model)
        known = ok and result == true
        nativeElectric[model] = known
    end
    return known
end

---@param vehicle integer
---@return boolean
local function isElectricVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    return Fuel.isElectricModel(GetEntityModel(vehicle)) or isNativeElectric(vehicle)
end

-- Resolve the native once when the player gets in, so the HUD's first sample
-- and the pump menu never pay for it.
Kora.cache.onChange('vehicle', function(vehicle)
    if vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) then isNativeElectric(vehicle) end
end)

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

local function legacyGetFuel(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    return GetVehicleFuelLevel(vehicle)
end
local function legacySetFuel(vehicle, level)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not IsEntityAVehicle(vehicle) then return end
    if type(level) ~= 'number' or level ~= level or math.abs(level) == math.huge then return end
    NetworkRequestControlOfEntity(vehicle)
    setFuel(vehicle, level)
end

-- Keep LegacyFuel's fractional reads and nil return while using native fuel state.
for _, name in ipairs({ 'LegacyFuel', 'qb-fuel', 'ps-fuel', 'cdn-fuel' }) do
    Kora.compat.provideExport(name, 'GetFuel', legacyGetFuel)
    Kora.compat.provideExport(name, 'SetFuel', legacySetFuel)
end

local function nearServicePoint(coords)
    for _, station in ipairs(Config.stations) do
        if #(coords - station) <= Config.serviceRadius then return true end
    end
    return false
end

-- 'pump' services are authorised near Config.stations and 'charger' services
-- near a Config.charging station; the server repeats the same check.
local function closestServiceVehicle(site)
    local pedCoords = GetEntityCoords(PlayerPedId())
    if site == 'charger' then
        if not Fuel.nearestCharger(pedCoords, Config.charging.serviceRadius) then
            notify('Move to an EV charging station first.', 'error')
            return nil
        end
    elseif not nearServicePoint(pedCoords) then
        notify('Move to a fuel station or charging point first.', 'error')
        return nil
    end

    local closest = Kora.closest.vehicle(pedCoords, Config.vehicleSearchDistance)
    if not closest.id or not DoesEntityExist(closest.id) then
        notify('Park a vehicle next to the pump or charger.', 'error')
        return nil
    end
    return closest.id, pedCoords
end

-- Tells an EV driver at a petrol pump where to go instead, naming the nearest station.
local function pumpRefusal(coords)
    local message = Config.charging.pumpMessage
    local station, distance = Fuel.nearestCharger(coords)
    if not station then return message end
    local away = distance >= 1000.0 and ('%.1f km'):format(distance / 1000.0) or ('%d m'):format(math.floor(distance))
    return ('%s Nearest: %s (%s).'):format(message, station.label, away)
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

    TriggerServerEvent('qbfuel:server:purchase', data.netId, value.account, quantity, data.level, data.site)
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
        description = spec.description or (spec.electric and 'Battery charge' or 'Petrol pump'),
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

local function openServiceMenu(site)
    local vehicle, pedCoords = closestServiceVehicle(site)
    if not vehicle then return end

    local electric = isElectricVehicle(vehicle)
    if site == 'pump' and electric and not Fuel.pumpsAcceptElectric() then
        return notify(pumpRefusal(pedCoords), 'info')
    end
    if site == 'charger' and not electric then
        return notify('Charging stations are for electric vehicles only.', 'error')
    end
    if GetIsVehicleEngineRunning(vehicle) then
        return notify('Switch the engine off before servicing the vehicle.', 'error')
    end

    local level = currentLevel(vehicle)
    local capacity = math.floor(Config.maxLevel) - level
    if capacity < 1 then return notify('Vehicle is already full.', 'info') end

    -- Price kind follows the server-side model list so the quote matches the charge.
    local kind = Fuel.isElectricModel(GetEntityModel(vehicle)) and 'charge' or 'fuel'
    local netId = NetworkGetNetworkIdFromEntity(vehicle)

    Kora.nui.registerApp(buildApp({
        title = electric and 'Charge vehicle' or 'Refuel vehicle',
        description = site == 'charger' and ('Battery charge - %s'):format(
            Fuel.nearestCharger(pedCoords, Config.charging.serviceRadius).label) or nil,
        electric = electric,
        level = level,
        capacity = capacity,
        accounts = Config.paymentAccounts,
        unitPrice = Fuel.unitPrice(kind, site),
        priceFor = function(quantity) return Fuel.price(kind, quantity, site) end,
    }))

    Kora.nui.openApp(appId, {
        data = { netId = netId, level = level, capacity = capacity, site = site },
    })
end

Kora.interact.addModel(Config.pumpModels, {
    { label = 'Service nearby vehicle', icon = 'fuel', action = function() openServiceMenu('pump') end },
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

-- Consumption only matters while the local player drives a vehicle, so the
-- worker starts when the cached vehicle/seat make that true and exits as soon
-- as they stop doing so. On foot (or as a passenger) nothing runs at all.
local drivenVehicle, drivenSeat = Kora.cache.vehicle(), Kora.cache.seat()
local consuming = false

local function consumeTick(vehicle)
    if not GetIsVehicleEngineRunning(vehicle) then return end

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

local function startConsuming()
    if consuming or not drivenVehicle or drivenSeat ~= -1 then return end
    consuming = true
    CreateThread(function()
        while true do
            Wait(Config.consumeInterval)
            if not drivenVehicle or drivenSeat ~= -1 then break end
            consumeTick(drivenVehicle)
        end
        consuming = false
    end)
end

Kora.cache.onChange('vehicle', function(vehicle)
    drivenVehicle = vehicle
    startConsuming()
end)

Kora.cache.onChange('seat', function(seat)
    drivenSeat = seat
    startConsuming()
end)

startConsuming()

-- EV charging stations. Zones and models only: nothing runs until the player
-- aims at one, and the option check below is memoised so a held aim does not
-- rescan vehicles every resolver tick.
local playerPed = Kora.cache.ped()
Kora.cache.onChange('ped', function(ped) playerPed = ped end)

local CHARGE_CHECK_MS = 500
local chargeCheck = { at = -CHARGE_CHECK_MS, ready = false }

local function electricVehicleNearby()
    local now = GetGameTimer()
    if now - chargeCheck.at < CHARGE_CHECK_MS then return chargeCheck.ready end
    chargeCheck.at = now

    local vehicle = drivenVehicle
    if not vehicle then
        vehicle = Kora.closest.vehicle(GetEntityCoords(playerPed), Config.vehicleSearchDistance).id
    end
    chargeCheck.ready = vehicle and isElectricVehicle(vehicle) or false
    return chargeCheck.ready
end

local function registerChargingStations()
    if not Fuel.chargingEnabled() then return end
    local charging = Config.charging

    local zoneOptions = {
        {
            label = 'Charge vehicle',
            icon = 'Zap',
            canInteract = electricVehicleNearby,
            onSelect = function() openServiceMenu('charger') end,
        },
    }
    for _, station in ipairs(charging.stations) do
        local radius = (tonumber(station.radius) or 0.0) > 0.0 and station.radius or charging.zoneRadius
        exports.kora_target:addSphereZone({
            coords = station.coords,
            radius = radius + 0.0,
            distance = charging.interactDistance + 0.0,
            options = zoneOptions,
            drawSprite = charging.worldIcon == true,
        })
    end

    if #charging.propModels > 0 then
        Kora.interact.addModel(charging.propModels, {
            {
                label = 'Charge vehicle',
                icon = 'zap',
                canInteract = electricVehicleNearby,
                action = function() openServiceMenu('charger') end,
            },
        }, charging.interactDistance)
    end
end

registerChargingStations()
