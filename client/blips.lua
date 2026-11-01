-- Map blips for Config.stations, driven by Config.blips.
local created = {}

local function removeBlips()
    for i = #created, 1, -1 do
        if DoesBlipExist(created[i]) then RemoveBlip(created[i]) end
        created[i] = nil
    end
end

local function createBlips()
    removeBlips()
    local settings = Config.blips
    if not settings or not settings.enabled then return end

    for index, station in ipairs(Config.stations) do
        local override = settings.perStation and settings.perStation[index] or {}
        local function pick(key)
            if override[key] ~= nil then return override[key] end
            return settings[key]
        end

        if override.enabled ~= false then
            local blip = AddBlipForCoord(station.x, station.y, station.z)
            SetBlipSprite(blip, pick('sprite'))
            SetBlipColour(blip, pick('colour'))
            SetBlipScale(blip, pick('scale') + 0.0)
            SetBlipAsShortRange(blip, pick('shortRange') == true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(pick('label'))
            EndTextCommandSetBlipName(blip)
            created[#created + 1] = blip
        end
    end
end

CreateThread(createBlips)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then removeBlips() end
end)
