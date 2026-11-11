-- Charger props for Config.charging.stations (Config.charging.prop). Every
-- station gets a Kora.zones sphere of prop.spawnDistance metres. Entering it
-- spawns a frozen local prop through Kora.entities (each client draws its own
-- copy; nothing is networked) and hides the world model the charger stands in
-- for (station.hideModel). Leaving deletes the prop and shows that model again.
-- Nothing runs between those two edges.
local HIDE_RADIUS = 1.0

local sites = {}
local stopped = false

local function setWorldModelHidden(site, hidden)
    if not site.hideModel or site.hidden == hidden then return end
    local at = site.coords
    if hidden then
        CreateModelHideExcludingScriptObjects(at.x, at.y, at.z, HIDE_RADIUS, site.hideModel, true)
    else
        RemoveModelHide(at.x, at.y, at.z, HIDE_RADIUS, site.hideModel, false)
    end
    site.hidden = hidden
end

local function removeProp(site)
    local entity = site.entity
    site.entity = nil
    if entity then
        -- Guarded: during a resource stop the air pump must still come back.
        local ok, removed = pcall(Kora.entities.remove, entity)
        if not (ok and removed) and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
    setWorldModelHidden(site, false)
end

local function spawnProp(site, prop)
    if site.entity or site.spawning then return end
    site.spawning = true
    -- Zone callbacks run on kora_lib's shared zone tick and model streaming
    -- yields, so the spawn gets its own thread.
    CreateThread(function()
        local entity, err = Kora.entities.create(prop.model, site.position, {
            heading = site.heading,
            freeze = true,
            invincible = true,
        })
        site.spawning = false
        if not entity then
            print(('[kora_fuel] charger prop %s at %s was not spawned: %s'):format(prop.model, site.label, tostring(err)))
            return
        end
        site.entity = entity
        -- The player left (or the resource stopped) while the model streamed.
        if stopped or not site.inside then return removeProp(site) end
        -- Hide the air pump before the ground snap, so the snap cannot settle
        -- the charger on top of the pump it stands in for. The hide applies on
        -- the next frame, and the player may leave during it.
        setWorldModelHidden(site, true)
        if prop.snapToGround then
            Wait(0)
            if stopped or site.entity ~= entity then return end
            PlaceObjectOnGroundProperly(entity)
            FreezeEntityPosition(entity, true)
        end
    end)
end

local function start()
    local prop = Config.charging and Config.charging.prop
    if not Fuel.chargingEnabled() or type(prop) ~= 'table' or prop.enabled == false then return end
    if type(prop.model) ~= 'string' or prop.model == '' then return end

    local spawnDistance = math.max(tonumber(prop.spawnDistance) or 0.0, 10.0)
    local headingOffset = tonumber(prop.headingOffset) or 0.0
    for _, station in ipairs(Config.charging.stations) do
        local hideModel = type(station.hideModel) == 'string' and station.hideModel ~= '' and joaat(station.hideModel) or nil
        local site = {
            label = station.label,
            coords = station.coords,
            position = Fuel.chargerPosition(station),
            heading = ((tonumber(station.heading) or 0.0) + headingOffset) % 360.0,
            hideModel = hideModel,
            inside = false,
        }
        site.zone = Kora.zones.sphere({
            coords = site.position,
            radius = spawnDistance,
            onEnter = function()
                site.inside = true
                spawnProp(site, prop)
            end,
            onExit = function()
                site.inside = false
                removeProp(site)
            end,
        })
        sites[#sites + 1] = site
    end
end

start()

-- Zones and tracked entities are cleaned up by kora_lib on stop; the model
-- hides are not, so every hidden air pump is shown again here.
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopped = true
    for _, site in ipairs(sites) do removeProp(site) end
end)
