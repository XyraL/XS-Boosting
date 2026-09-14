Admin = {}

local KINDS = {
    spawn = true, buyer = true, chop = true, lockup = true,
    fence = true, deadzone = true, heist = true, heist_exit = true,
}

local function guard(src)
    return Framework.IsAdmin(src)
end

local function sanitise(payload)
    if type(payload) ~= 'table' then return nil end
    if not KINDS[payload.kind] then return nil end

    local coords = payload.coords
    if type(coords) ~= 'table' then return nil end

    local x, y, z = tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)
    if not x or not y or not z then return nil end

    local tier = payload.tier
    if payload.kind == 'spawn' then
        if not tier or not Tiers.Get(tier) then return nil end
    else
        tier = nil
    end

    return {
        kind    = payload.kind,
        label   = tostring(payload.label or ''):sub(1, 96),
        tier    = tier,
        coords  = vec3(x, y, z),
        heading = tonumber(payload.heading) or 0.0,
        radius  = math.max(1.0, math.min(200.0, tonumber(payload.radius) or 10.0)),
        enabled = payload.enabled ~= false,
        data    = type(payload.data) == 'table' and payload.data or {},
    }
end

lib.callback.register('XS-Boosting:admin:bootstrap', function(src)
    if not guard(src) then return false end

    local tiers = {}
    for _, tier in ipairs(Tiers.All()) do
        local cars = {}

        for _, vehicle in ipairs(tier.vehicles or {}) do
            cars[#cars + 1] = { model = vehicle.model, label = vehicle.label }
        end

        tiers[#tiers + 1] = { id = tier.id, label = tier.label, vehicles = cars }
    end

    -- Flattened for the page: a vector3 arrives there as null.
    local places = {}

    for _, entry in ipairs(Store.All()) do
        places[#places + 1] = {
            id      = entry.id,
            kind    = entry.kind,
            label   = entry.label,
            tier    = entry.tier,
            coords  = Store.Plain(entry.coords),
            heading = entry.heading,
            radius  = entry.radius,
            enabled = entry.enabled,
            data    = entry.data,
        }
    end

    return {
        locations = places,
        resting   = Store.Resting(),
        tiers     = tiers,
        kinds     = {
            { id = 'spawn',      label = 'Vehicle Spawn',  tiered = true },
            { id = 'buyer',      label = 'Handover Point', tiered = false },
            { id = 'chop',       label = 'Chop Shop',      tiered = false },
            { id = 'lockup',     label = 'Lockup',         tiered = false },
            { id = 'fence',      label = 'Street Fence',   tiered = false },
            { id = 'deadzone',   label = 'Dead Zone',      tiered = false },
            { id = 'heist',      label = 'Heist Site',     tiered = false },
            { id = 'heist_exit', label = 'Heist Exit',     tiered = false },
        },
        items     = Inv.Items(),
        allCars   = Framework.Vehicles(),
    }
end)

lib.callback.register('XS-Boosting:admin:save', function(src, payload)
    if not guard(src) then return false, 'Not allowed.' end

    local entry = sanitise(payload)
    if not entry then return false, 'That point is not valid.' end

    if payload.id then
        local ok = Store.Update(payload.id, entry)
        return ok, ok and nil or 'That point is gone.'
    end

    local created = Store.Add(entry, Framework.GetCitizenId(src))
    if not created then return false, 'Could not save it.' end

    Contracts.Refresh()
    return true, nil, created
end)

lib.callback.register('XS-Boosting:admin:delete', function(src, id)
    if not guard(src) then return false end
    local ok = Store.Delete(id)
    if ok then Contracts.Refresh() end
    return ok
end)

lib.callback.register('XS-Boosting:admin:toggle', function(src, id, enabled)
    if not guard(src) then return false end

    local entry = Store.Get(id)
    if not entry then return false end

    local ok = Store.Update(id, { enabled = enabled and true or false })
    if ok then Contracts.Refresh() end
    return ok
end)

lib.callback.register('XS-Boosting:admin:event', function(src)
    if not guard(src) then return false end

    local active = Event.Active()
    local ok, reason = Event.CanStart()

    return {
        active   = Event.Describe(active),
        joined   = active and #active.joined or 0,
        winner   = active and active.takenBy or nil,
        canStart = ok,
        reason   = reason,
        auto     = Config.Events.everyMinutes > 0,
        every    = Config.Events.everyMinutes,
        online   = #GetPlayers(),
        needed   = Config.Events.minPlayers,
    }
end)

lib.callback.register('XS-Boosting:admin:eventStart', function(src)
    if not guard(src) then return false, 'Not allowed.' end
    return Event.Start()
end)

lib.callback.register('XS-Boosting:admin:eventStop', function(src)
    if not guard(src) then return false, 'Not allowed.' end
    if not Event.Active() then return false, 'Nothing is running.' end

    Event.Finish('An admin called it off.')
    return true
end)

lib.callback.register('XS-Boosting:admin:stored', function(src)
    if not guard(src) then return {} end

    local rows = MySQL.query.await([[
        SELECT s.id, s.citizenid, s.location_id, s.job, s.remaining, s.`condition`, s.stored_at,
               p.handle
        FROM xs_boosting_stored s
        LEFT JOIN xs_boosting_players p ON p.citizenid = s.citizenid
        ORDER BY s.id DESC LIMIT 100
    ]]) or {}

    local out = {}

    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.job)
        local place = Store.Get(row.location_id)

        out[#out + 1] = {
            id        = row.id,
            who       = Players.DisplayName({ citizenid = row.citizenid, handle = row.handle }),
            label     = ok and data.contract and data.contract.label or 'Vehicle',
            plate     = ok and data.plate or '—',
            tier      = ok and data.tier or '—',
            lockup    = place and (place.label ~= '' and place.label or ('#' .. place.id)) or 'gone',
            remaining = row.remaining,
            condition = row.condition,
            storedAt  = row.stored_at,
        }
    end

    return out
end)

lib.callback.register('XS-Boosting:admin:releaseStored', function(src, id)
    if not guard(src) then return false end

    MySQL.query.await('DELETE FROM xs_boosting_stored WHERE id = ?', { tonumber(id) or 0 })
    return true
end)

lib.callback.register('XS-Boosting:admin:jobs', function(src)
    if not guard(src) then return {} end

    local out = {}

    for id, job in pairs(Jobs.Active()) do
        out[#out + 1] = {
            id        = id,
            holder    = Framework.GetName(job.holder),
            heist     = job.heist and true or false,
            tier      = job.tier,
            label     = job.contract and job.contract.label or 'Heist',
            stage     = job.stage,
            crew      = Crew.Size(job),
            remaining = math.max(0, job.deadline - os.time()),
            condition = job.condition,
        }
    end

    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)

lib.callback.register('XS-Boosting:admin:cancel', function(src, jobId)
    if not guard(src) then return false end

    local job = Jobs.ById(jobId)
    if not job then return false end

    if job.heist then
        Heist.Fail(job, 'An admin stopped it.')
    else
        Jobs.Fail(job, 'An admin stopped it.')
    end

    return true
end)

lib.callback.register('XS-Boosting:admin:setRep', function(src, target, amount)
    if not guard(src) then return false end

    target = tonumber(target)
    amount = tonumber(amount)
    if not target or not amount then return false end

    local citizenid = Framework.GetCitizenId(target)
    if not citizenid then return false end

    local record = Players.Get(citizenid)
    if not record then return false end

    record.rep = math.max(Config.Rep.floor, math.floor(amount))
    Players.Save(citizenid)
    TriggerClientEvent('XS-Boosting:client:rep', target, record.rep, 0)

    return true, nil, record.rep
end)

-- Everybody's board at once. Boards are per player, so this is a reroll for
-- the whole server rather than a nudge to one shared list.
lib.callback.register('XS-Boosting:admin:refreshBoard', function(src)
    if not guard(src) then return false end
    Contracts.Reroll()
    return true
end)

lib.callback.register('XS-Boosting:admin:shiftMarket', function(src)
    if not guard(src) then return false end
    Market.Shift()
    return true, nil, Market.All()
end)
