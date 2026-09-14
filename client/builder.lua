Builder = {}

local open = false
local preview = {}

local COLOURS = {
    spawn      = { 90, 210, 255 },
    buyer      = { 120, 255, 170 },
    chop       = { 255, 170, 90 },
    lockup     = { 190, 160, 255 },
    fence      = { 255, 120, 160 },
    deadzone   = { 150, 150, 160 },
    heist      = { 255, 90, 90 },
    heist_exit = { 255, 230, 120 },
}

local function clearPreview()
    for _, blip in ipairs(preview) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end
    preview = {}
end

-- Everything the admin has placed, shown at once, colour-coded by kind. This
-- is the only place spawn points are ever visible.
local function drawPreview(locations)
    clearPreview()

    for _, place in ipairs(locations or {}) do
        local blip = AddBlipForCoord(place.coords.x, place.coords.y, place.coords.z)
        SetBlipSprite(blip, 1)
        SetBlipScale(blip, 0.7)
        SetBlipColour(blip, place.kind == 'spawn' and 3 or 5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(('[%s] %s'):format(place.kind, place.label ~= '' and place.label or place.id))
        EndTextCommandSetBlipName(blip)
        preview[#preview + 1] = blip
    end
end

function Builder.Open()
    if open then return end

    local payload = lib.callback.await('XS-Boosting:admin:bootstrap', false)
    if not payload then
        Boost.Notify('You are not allowed to do that.', 'error')
        return
    end

    open = true
    Boost.builder = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'builder', data = payload })
    drawPreview(payload.locations)
end

function Builder.Close()
    if not open then return end

    open = false
    Boost.builder = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'builderClose' })
    clearPreview()
end

RegisterNetEvent('XS-Boosting:client:openBuilder', function()
    Builder.Open()
end)

RegisterNUICallback('builderClose', function(_, cb)
    Builder.Close()
    cb(true)
end)

-- Placing hands control back to the game. The page stays loaded and comes
-- back with whatever was picked, so the admin never loses their place.
RegisterNUICallback('builderPlace', function(data, cb)
    local kind = data and data.kind or 'buyer'
    local colour = COLOURS[kind] or COLOURS.buyer

    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'builderPlacing', data = true })

    local result

    if kind == 'spawn' then
        result = Placement.Vehicle(data.model)
    else
        result = Placement.Run({
            radius = data.radius,
            r = colour[1], g = colour[2], b = colour[3],
        })
    end

    if open then SetNuiFocus(true, true) end
    SendNUIMessage({ action = 'builderPlacing', data = false })

    if not result then
        cb(false)
        return
    end

    cb({
        coords = { x = result.coords.x, y = result.coords.y, z = result.coords.z },
        heading = result.heading,
        radius = result.radius,
    })
end)

-- A heist site holds its own car spawns, placed one after another, because a
-- three-bay showroom should run a three-car job.
RegisterNUICallback('builderHeistSpawns', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'builderPlacing', data = true })

    local spawns = {}
    local limit = Config.Heist.crewSize.max + 2

    while #spawns < limit do
        local result = Placement.Vehicle(data and data.model)
        if not result then break end

        spawns[#spawns + 1] = {
            x = result.coords.x,
            y = result.coords.y,
            z = result.coords.z,
            h = result.heading,
        }

        Boost.Notify(('%d placed. Place another, or Backspace to stop.'):format(#spawns), 'inform')
        Wait(250)
    end

    if open then SetNuiFocus(true, true) end
    SendNUIMessage({ action = 'builderPlacing', data = false })

    cb({ spawns = spawns })
end)

RegisterNUICallback('builderSave', function(data, cb)
    local ok, reason, created = lib.callback.await('XS-Boosting:admin:save', false, data)

    if ok then
        local locations = lib.callback.await('XS-Boosting:admin:bootstrap', false)
        if locations then drawPreview(locations.locations) end
    else
        Boost.Notify(reason or 'That did not save.', 'error')
    end

    cb({ ok = ok, reason = reason, created = created })
end)

RegisterNUICallback('builderDelete', function(data, cb)
    local ok = lib.callback.await('XS-Boosting:admin:delete', false, data.id)

    if ok then
        local payload = lib.callback.await('XS-Boosting:admin:bootstrap', false)
        if payload then drawPreview(payload.locations) end
    end

    cb({ ok = ok })
end)

RegisterNUICallback('builderToggle', function(data, cb)
    cb({ ok = lib.callback.await('XS-Boosting:admin:toggle', false, data.id, data.enabled) })
end)

RegisterNUICallback('builderList', function(_, cb)
    local payload = lib.callback.await('XS-Boosting:admin:bootstrap', false)
    if payload then drawPreview(payload.locations) end
    cb(payload)
end)

RegisterNUICallback('builderGoto', function(data, cb)
    local coords = data and data.coords
    if not coords then cb(false) return end

    Builder.Close()

    local ped = cache.ped
    SetEntityCoords(ped, coords.x + 0.0, coords.y + 0.0, coords.z + 1.0, false, false, false, false)

    cb(true)
end)

RegisterNUICallback('builderEvent', function(_, cb)
    cb(lib.callback.await('XS-Boosting:admin:event', false))
end)

RegisterNUICallback('builderEventStart', function(_, cb)
    local ok, reason = lib.callback.await('XS-Boosting:admin:eventStart', false)
    if not ok then Boost.Notify(reason or 'Could not start one.', 'error') end
    cb({ ok = ok, reason = reason })
end)

RegisterNUICallback('builderEventStop', function(_, cb)
    local ok, reason = lib.callback.await('XS-Boosting:admin:eventStop', false)
    if not ok then Boost.Notify(reason or 'Nothing to stop.', 'error') end
    cb({ ok = ok, reason = reason })
end)

RegisterNUICallback('builderStored', function(_, cb)
    cb(lib.callback.await('XS-Boosting:admin:stored', false))
end)

RegisterNUICallback('builderReleaseStored', function(data, cb)
    cb({ ok = lib.callback.await('XS-Boosting:admin:releaseStored', false, data.id) })
end)

RegisterNUICallback('builderJobs', function(_, cb)
    cb(lib.callback.await('XS-Boosting:admin:jobs', false))
end)

RegisterNUICallback('builderCancelJob', function(data, cb)
    cb({ ok = lib.callback.await('XS-Boosting:admin:cancel', false, data.id) })
end)

RegisterNUICallback('builderRefreshBoard', function(_, cb)
    cb({ ok = lib.callback.await('XS-Boosting:admin:refreshBoard', false) })
end)

RegisterNUICallback('builderShiftMarket', function(_, cb)
    local ok, _, market = lib.callback.await('XS-Boosting:admin:shiftMarket', false)
    cb({ ok = ok, market = market })
end)

RegisterNUICallback('builderSetRep', function(data, cb)
    local ok, _, rep = lib.callback.await('XS-Boosting:admin:setRep', false, data.src, data.amount)
    cb({ ok = ok, rep = rep })
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then clearPreview() end
end)
