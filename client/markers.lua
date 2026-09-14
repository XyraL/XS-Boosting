Markers = {}

local zoneBlip, zoneRadius, buyerBlip
local placeBlips = {}
local discovered = {}

local BLIP_FOR = {
    chop = 'chopShop',
    lockup = 'lockup',
}

local function clearBlip(blip)
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    return nil
end

function Markers.Clear()
    zoneBlip = clearBlip(zoneBlip)
    zoneRadius = clearBlip(zoneRadius)
    buyerBlip = clearBlip(buyerBlip)

    for id, blip in pairs(placeBlips) do
        clearBlip(blip)
        placeBlips[id] = nil
    end
end

RegisterNetEvent('XS-Boosting:client:discovered', function(ids)
    for _, id in ipairs(ids or {}) do discovered[id] = true end
    Markers.Rebuild()
end)

-- Places the player is allowed to see on the map. A place set to
-- discoveredOnly stays off the map until they have physically stood at it.
function Markers.Rebuild()
    for id, blip in pairs(placeBlips) do
        clearBlip(blip)
        placeBlips[id] = nil
    end

    for _, place in ipairs(Boost.locations) do
        local key = BLIP_FOR[place.kind]
        local settings = key and Config.Blips[key]

        if settings and settings.enabled then
            if not settings.discoveredOnly or discovered[place.id] then
                local blip = AddBlipForCoord(place.coords.x, place.coords.y, place.coords.z)
                SetBlipSprite(blip, settings.sprite)
                SetBlipColour(blip, settings.colour)
                SetBlipScale(blip, settings.scale or 0.8)
                SetBlipAsShortRange(blip, true)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(place.label ~= '' and place.label or settings.label)
                EndTextCommandSetBlipName(blip)
                placeBlips[place.id] = blip
            end
        end
    end
end

function Markers.Job(state)
    zoneBlip = clearBlip(zoneBlip)
    zoneRadius = clearBlip(zoneRadius)
    buyerBlip = clearBlip(buyerBlip)

    if not state then return end

    if state.heist then
        if state.site then
            zoneBlip = AddBlipForCoord(state.site.x, state.site.y, state.site.z)
            SetBlipSprite(zoneBlip, 225)
            SetBlipColour(zoneBlip, 47)
            SetBlipScale(zoneBlip, 1.0)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Heist Site')
            EndTextCommandSetBlipName(zoneBlip)
        end

        if state.exit and state.stage == 'running' then
            buyerBlip = AddBlipForCoord(state.exit.x, state.exit.y, state.exit.z)
            SetBlipSprite(buyerBlip, Config.Blips.dropoff.sprite)
            SetBlipColour(buyerBlip, Config.Blips.dropoff.colour)
            SetBlipScale(buyerBlip, Config.Blips.dropoff.scale)
            SetBlipRoute(buyerBlip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('Exit')
            EndTextCommandSetBlipName(buyerBlip)
        end

        return
    end

    -- The search zone is a circle and nothing else. There is no pin on the
    -- car, and the circle is not centred on it either.
    if state.centre and (state.stage == 'search' or state.stage == 'entry') then
        local settings = Config.Blips.searchZone

        zoneRadius = AddBlipForRadius(state.centre.x, state.centre.y, state.centre.z, state.radius + 0.0)
        SetBlipColour(zoneRadius, settings.colour)
        SetBlipAlpha(zoneRadius, settings.alpha)

        zoneBlip = AddBlipForCoord(state.centre.x, state.centre.y, state.centre.z)
        SetBlipSprite(zoneBlip, settings.sprite)
        SetBlipColour(zoneBlip, settings.colour)
        SetBlipScale(zoneBlip, 0.9)
        SetBlipAsShortRange(zoneBlip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Search Area')
        EndTextCommandSetBlipName(zoneBlip)
    end

    if state.buyer and state.stage == 'transit' then
        local settings = Config.Blips.dropoff

        buyerBlip = AddBlipForCoord(state.buyer.x, state.buyer.y, state.buyer.z)
        SetBlipSprite(buyerBlip, settings.sprite)
        SetBlipColour(buyerBlip, settings.colour)
        SetBlipScale(buyerBlip, settings.scale)
        SetBlipRoute(buyerBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(settings.label)
        EndTextCommandSetBlipName(buyerBlip)
    end
end

-- Standing at a place is what reveals it. Nothing else does.
CreateThread(function()
    while true do
        Wait(3000)

        if #Boost.locations > 0 then
            local position = GetEntityCoords(cache.ped)
            local found = {}

            for _, place in ipairs(Boost.locations) do
                if not discovered[place.id] and #(position - vector3(place.coords.x, place.coords.y, place.coords.z)) <= math.max(place.radius, 20.0) then
                    discovered[place.id] = true
                    found[#found + 1] = place.id
                end
            end

            if #found > 0 then
                TriggerServerEvent('XS-Boosting:server:discovered', found)
                Markers.Rebuild()
            end
        end
    end
end)
