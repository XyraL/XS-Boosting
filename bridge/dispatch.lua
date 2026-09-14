Dispatch = { name = nil }

if not Config then return end

local IS_SERVER = IsDuplicityVersion()

local CANDIDATES = {
    'XS-Dispatch',
    'ps-dispatch',
    'qs-dispatch',
    'cd_dispatch',
    'core_dispatch',
    'rcore_dispatch',
    'origen_police',
}

do
    local forced = Config.Bridges and Config.Bridges.dispatch or 'auto'
    if forced == 'none' then
        Dispatch.name = nil
    elseif forced ~= 'auto' then
        Dispatch.name = forced
    else
        for _, resource in ipairs(CANDIDATES) do
            if GetResourceState(resource) == 'started' then Dispatch.name = resource break end
        end
    end
end

if IS_SERVER then
    function Dispatch.Alert(payload)
        TriggerClientEvent('XS-Boosting:client:alert', -1, payload)
    end

    -- A live tracker is its own thing. Dispatch resources broadcast a fixed
    -- point and forget it, so the moving blip is drawn by this resource on
    -- every police client instead, and only the first ping goes out through
    -- whichever dispatch resource is installed.
    function Dispatch.Track(id, coords, label)
        TriggerClientEvent('XS-Boosting:client:track', -1, id, coords, label)
    end

    function Dispatch.Untrack(id)
        TriggerClientEvent('XS-Boosting:client:untrack', -1, id)
    end
else
    local tracked = {}

    -- The police-facing alert: { coords, code, title, description }. Not to be
    -- confused with XS-Boosting:client:jobAlert, which is the HUD's and has no
    -- coords on it at all.
    RegisterNetEvent('XS-Boosting:client:alert', function(data)
        if not Framework.IsPolice() then return end

        -- A dispatch alert without somewhere to put the blip is not an alert.
        -- Guarded rather than assumed: this handler is on a public event name
        -- and has no say in what else might fire it.
        if not data or not data.coords then return end

        local coords = vector3(data.coords.x, data.coords.y, data.coords.z)
        local code = data.code or '10-16'
        local title = data.title or 'Vehicle Theft'
        local description = data.description or 'A vehicle has been reported stolen.'
        local sprite = data.sprite or 225
        local colour = data.colour or 47
        local radius = data.radius or 0

        if Dispatch.name == 'XS-Dispatch' then
            exports['XS-Dispatch']:CustomAlert({
                code = code,
                title = title,
                description = description,
                coords = coords,
                priority = data.priority or 2,
                jobs = Config.Police.jobs,
                blip = { sprite = sprite, colour = colour, scale = 1.0, time = data.blipTime or 300 },
            })
            return
        end

        if Dispatch.name == 'ps-dispatch' then
            exports['ps-dispatch']:CustomAlert({
                coords = coords,
                message = title,
                dispatchCode = code,
                description = description,
                radius = radius,
                sprite = sprite,
                color = colour,
                scale = 1.0,
                length = 5,
            })
            return
        end

        if Dispatch.name == 'qs-dispatch' then
            exports['qs-dispatch']:VehicleTheft({
                displayCode = code,
                description = title,
                radius = radius,
                coords = coords,
            })
            return
        end

        if Dispatch.name == 'cd_dispatch' then
            TriggerEvent('cd_dispatch:AddNotification', {
                job_table = Config.Police.jobs,
                coords = coords,
                title = code .. ' - ' .. title,
                message = description,
                flash = 0,
                unique_id = tostring(math.random(0000000, 9999999)),
                blip = {
                    sprite = sprite,
                    scale = 1.0,
                    colour = colour,
                    flashes = false,
                    text = code .. ' - ' .. title,
                    time = 5,
                    radius = radius,
                },
            })
            return
        end

        if Dispatch.name == 'core_dispatch' then
            TriggerEvent('core_dispatch:addCall', code, title, {
                { icon = 'fa-circle-info', info = description },
            }, { coords.x, coords.y, coords.z }, Config.Police.jobs, 15000, sprite, colour)
            return
        end

        Framework.Notify(('%s — %s'):format(code, title), 'warning')

        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(blip, sprite)
        SetBlipColour(blip, colour)
        SetBlipScale(blip, 1.0)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(title)
        EndTextCommandSetBlipName(blip)
        SetTimeout((data.blipTime or 300) * 1000, function()
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end)
    end)

    RegisterNetEvent('XS-Boosting:client:track', function(id, coords, label)
        if not Framework.IsPolice() then return end

        local blip = tracked[id]

        if not blip or not DoesBlipExist(blip) then
            blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, 225)
            SetBlipColour(blip, 1)
            SetBlipScale(blip, 0.9)
            SetBlipAsShortRange(blip, false)
            SetBlipFlashes(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(label or 'Tracked Vehicle')
            EndTextCommandSetBlipName(blip)
            tracked[id] = blip
        else
            SetBlipCoords(blip, coords.x, coords.y, coords.z)
        end
    end)

    RegisterNetEvent('XS-Boosting:client:untrack', function(id)
        local blip = tracked[id]
        if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
        tracked[id] = nil
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end
        for _, blip in pairs(tracked) do
            if DoesBlipExist(blip) then RemoveBlip(blip) end
        end
    end)
end

if Config.Debug then
    print(('^2[XS-Boosting]^0 dispatch bridge loaded (%s) on %s'):format(
        Dispatch.name or 'notifications', IS_SERVER and 'server' or 'client'))
end
