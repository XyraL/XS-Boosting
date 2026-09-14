Target = { name = nil }

if not Config then return end

do
    local forced = Config.Bridges and Config.Bridges.target or 'auto'
    if forced ~= 'auto' then
        Target.name = forced
    elseif GetResourceState('ox_target') == 'started' then
        Target.name = 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        Target.name = 'qb-target'
    else
        Target.name = 'builtin'
    end
end

-- Zones the builtin fallback has to draw and watch itself. A zone is either
-- fixed to coords or attached to an entity, and the entity kind is resolved
-- every frame so it follows a car that is being driven.
local builtin = {}
local entities = {}

local function optionNames(options)
    local names = {}
    for index, option in ipairs(options) do
        names[index] = option.label
    end
    return names
end

function Target.AddSphere(id, coords, radius, options)
    Target.Remove(id)

    if Target.name == 'ox_target' then
        exports.ox_target:addSphereZone({
            name = id,
            coords = coords,
            radius = radius,
            options = options,
        })
        return
    end

    if Target.name == 'qb-target' then
        local converted = {}
        for index, option in ipairs(options) do
            converted[index] = {
                label = option.label,
                icon = option.icon,
                action = option.onSelect,
                canInteract = option.canInteract,
            }
        end

        exports['qb-target']:AddCircleZone(id, coords, radius, {
            name = id,
            useZ = true,
        }, { options = converted, distance = radius })
        return
    end

    builtin[id] = { coords = coords, radius = radius, options = options }
end

function Target.AddEntity(id, entity, options, radius)
    Target.Remove(id)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    if Target.name == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, options)
        entities[id] = { entity = entity, options = options }
        return
    end

    if Target.name == 'qb-target' then
        local converted = {}
        for index, option in ipairs(options) do
            converted[index] = {
                label = option.label,
                icon = option.icon,
                action = option.onSelect,
                canInteract = option.canInteract,
            }
        end

        exports['qb-target']:AddTargetEntity(entity, { options = converted, distance = radius or 3.0 })
        entities[id] = { entity = entity, options = options }
        return
    end

    builtin[id] = { entity = entity, radius = radius or 3.0, options = options }
    entities[id] = { entity = entity, options = options }
end

function Target.Remove(id)
    local tracked = entities[id]

    if Target.name == 'ox_target' then
        if tracked and DoesEntityExist(tracked.entity) then
            exports.ox_target:removeLocalEntity(tracked.entity, optionNames(tracked.options))
        else
            exports.ox_target:removeZone(id)
        end
    elseif Target.name == 'qb-target' then
        if tracked and DoesEntityExist(tracked.entity) then
            exports['qb-target']:RemoveTargetEntity(tracked.entity, optionNames(tracked.options))
        else
            exports['qb-target']:RemoveZone(id)
        end
    end

    builtin[id] = nil
    entities[id] = nil
end

function Target.RemoveAll()
    local ids = {}
    for id in pairs(builtin) do ids[#ids + 1] = id end
    for id in pairs(entities) do ids[#ids + 1] = id end
    for _, id in ipairs(ids) do Target.Remove(id) end
end

if Target.name ~= 'builtin' then return end

-- A marker and an E prompt, for servers running no target resource at all.
-- This is the only place in the resource that binds a key to an interaction.
CreateThread(function()
    local prompt

    local function show(text)
        if prompt == text then return end
        prompt = text

        if text then
            lib.showTextUI(text, { position = 'left-center' })
        else
            lib.hideTextUI()
        end
    end

    while true do
        local wait = 750
        local nearest, nearestDistance

        if next(builtin) then
            local position = GetEntityCoords(cache and cache.ped or PlayerPedId())

            for id, zone in pairs(builtin) do
                local coords = zone.coords

                if zone.entity then
                    if DoesEntityExist(zone.entity) then
                        coords = GetEntityCoords(zone.entity)
                    else
                        coords = nil
                    end
                end

                if coords then
                    local distance = #(position - coords)

                    if distance < zone.radius + 8.0 then
                        wait = 0
                        DrawMarker(21, coords.x, coords.y, coords.z + 0.9,
                            0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.35, 0.35, 0.35,
                            120, 220, 255, 110, true, false, 2, false)

                        if distance < zone.radius and (not nearestDistance or distance < nearestDistance) then
                            nearest, nearestDistance = id, distance
                        end
                    end
                end
            end
        end

        if nearest then
            local zone = builtin[nearest]
            local option

            for _, candidate in ipairs(zone.options) do
                if not candidate.canInteract or candidate.canInteract() then
                    option = candidate
                    break
                end
            end

            if option then
                show(('[E] %s'):format(option.label))

                if IsControlJustReleased(0, 38) then
                    show(nil)
                    option.onSelect()
                    Wait(400)
                end
            else
                show(nil)
            end
        else
            show(nil)
        end

        Wait(wait)
    end
end)
