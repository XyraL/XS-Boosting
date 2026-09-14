Storage = {}

-- A stashed car is a paused contract. The row carries everything needed to
-- put the job back exactly as it was, including how long was left on it, so
-- parking one costs you nothing but the trip back.

local function serialise(job)
    return json.encode({
        contract  = job.contract,
        tier      = job.tier,
        spawnId   = job.spawn and job.spawn.id or nil,
        buyerId   = job.buyer and job.buyer.id or nil,
        plate     = job.plate,
        centre    = { x = job.centre.x, y = job.centre.y, z = job.centre.z },
        fitted    = job.fitted,
        tracker   = { alive = job.tracker.alive, broadcasting = false },
        parts     = job.parts,
        driving   = job.driving,
        stopped   = job.stopped,
        conditionPenalty = job.conditionPenalty or 0,
    })
end

function Storage.Count(citizenid)
    return tonumber(MySQL.scalar.await(
        'SELECT COUNT(*) FROM xs_boosting_stored WHERE citizenid = ?', { citizenid })) or 0
end

function Storage.List(citizenid)
    local rows = MySQL.query.await([[
        SELECT id, location_id, job, remaining, `condition`, stored_at
        FROM xs_boosting_stored WHERE citizenid = ? ORDER BY id DESC
    ]], { citizenid }) or {}

    local out = {}

    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.job)
        if ok and data then
            out[#out + 1] = {
                id = row.id,
                locationId = row.location_id,
                label = data.contract and data.contract.label or 'Vehicle',
                tier = data.tier,
                plate = data.plate,
                remaining = row.remaining,
                condition = row.condition,
            }
        end
    end

    return out
end

function Storage.AtLockup(citizenid, locationId)
    local out = {}
    for _, entry in ipairs(Storage.List(citizenid)) do
        if entry.locationId == locationId then out[#out + 1] = entry end
    end
    return out
end

function Storage.Stash(src, job, place)
    local settings = Config.Disposal.lockup
    if not settings.enabled or not settings.stash.enabled then
        return false, 'That is not something you can do here.'
    end

    if job.heist then return false, 'Not with a heist car.' end
    if job.stage ~= 'transit' then return false, 'Get it running first.' end

    local slots = settings.stash.slots or 0
    if slots > 0 and Storage.Count(job.citizenid) >= slots then
        return false, ('You already have %d parked.'):format(slots)
    end

    local condition = Jobs.ReadCondition(job)
    local remaining = math.max(0, job.deadline - os.time())

    if remaining <= 0 then return false, 'There is no time left on it anyway.' end

    local id = MySQL.insert.await([[
        INSERT INTO xs_boosting_stored (citizenid, location_id, job, remaining, `condition`)
        VALUES (?, ?, ?, ?, ?)
    ]], { job.citizenid, place.id, serialise(job), remaining, condition })

    if not id then return false, 'It would not fit.' end

    -- The job leaves the active list without counting as a failure, and
    -- without a cooldown: it is not over, it is parked.
    job.finished = true
    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', 'stashed')
    Jobs.Cleanup(job)

    return true, nil, { id = id, remaining = remaining, condition = condition }
end

function Storage.Retrieve(src, storedId)
    local settings = Config.Disposal.lockup
    if not settings.enabled or not settings.stash.enabled then
        return false, 'That is not something you can do here.'
    end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    if Jobs.Get(src) then return false, 'Finish what you are doing first.' end

    local row = MySQL.single.await([[
        SELECT id, location_id, job, remaining, `condition`
        FROM xs_boosting_stored WHERE id = ? AND citizenid = ?
    ]], { tonumber(storedId) or 0, citizenid })

    if not row then return false, 'That one is gone.' end

    local ok, data = pcall(json.decode, row.job)
    if not ok or not data then
        MySQL.query.await('DELETE FROM xs_boosting_stored WHERE id = ?', { row.id })
        return false, 'That one is gone.'
    end

    local place = Store.Get(row.location_id)
    if not place then return false, 'That lockup no longer exists.' end

    local job = {
        id        = Jobs.NewId(),
        contract  = data.contract,
        holder    = src,
        citizenid = citizenid,
        crew      = {},
        tier      = data.tier,
        stage     = 'transit',
        startedAt = os.time(),
        deadline  = os.time() + row.remaining,
        spawn     = { id = place.id, coords = place.coords, heading = place.heading },
        buyer     = Store.Get(data.buyerId) or Store.Nearest('buyer', place.coords),
        centre    = vec3(data.centre.x, data.centre.y, data.centre.z),
        plate     = data.plate,
        condition = row.condition,
        conditionPenalty = data.conditionPenalty or 0,
        parts     = data.parts or {},
        fitted    = data.fitted or { alarm = false, tracker = false },
        tracker   = data.tracker or { alive = false, broadcasting = false },
        driving   = false,
        stopped   = true,
    }

    if not job.buyer then return false, 'There is nowhere to take it any more.' end

    MySQL.query.await('DELETE FROM xs_boosting_stored WHERE id = ?', { row.id })

    Jobs.Register(job)

    local entity = Jobs.SpawnVehicle(job)
    if not entity then
        Jobs.Cleanup(job)
        return false, 'It would not come out.'
    end

    -- It comes out running and already yours; the theft happened days ago.
    Entity(entity).state:set('xsBoostSetup', {
        plate = job.plate,
        started = true,
        damage = 100 - row.condition,
    }, true)

    if Config.Vehicles.giveKeys and job.netId then
        Keys.Give(src, job.netId, job.plate)
    end

    Jobs.PushState(job)

    return true, nil, Jobs.StateFor(job)
end

-- Keeping it is permanent and costs real money. The car goes into the
-- player's own garage and nobody who ordered it sees a thing.
function Storage.Keep(src, job)
    local settings = Config.Disposal.lockup
    if not settings.enabled or not settings.keep.enabled then
        return false, 'That is not something you can do here.'
    end

    if job.heist then return false, 'Not with a heist car.' end
    if job.stage ~= 'transit' then return false, 'Get it running first.' end

    local keep = settings.keep
    local condition = Jobs.ReadCondition(job)

    if condition < (keep.minCondition or 0) then
        return false, ('Nobody will touch a VIN on a car in that state. Needs %d%%.'):format(keep.minCondition)
    end

    if keep.fee > 0 then
        local paid = Framework.RemoveMoney(src, keep.account or 'bank', keep.fee, 'boosting vin clean')
        if not paid then
            return false, ('You need %s to clean it.'):format(keep.fee)
        end
    end

    local given = Framework.GiveVehicle(src, job.contract.model, job.plate, keep.garage)

    if not given then
        if keep.fee > 0 then
            Framework.AddMoney(src, keep.account or 'bank', keep.fee, 'boosting refund')
        end
        return false, 'The paperwork would not go through.'
    end

    if keep.repPenalty > 0 then
        Players.AddRep(job.citizenid, -keep.repPenalty)
    end

    local record = Players.Get(job.citizenid)
    if record then
        record.completed = record.completed + 1
        Players.Save(job.citizenid)
    end

    Players.Record(job.citizenid, {
        type = job.contract.type, tier = job.tier,
        model = job.contract.model, label = job.contract.label,
        outcome = 'kept', payout = 0, condition = condition,
    })

    job.finished = true
    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', 'kept')
    Jobs.Cleanup(job, true)

    return true, nil, { plate = job.plate, garage = keep.garage }
end

-- Cars nobody came back for.
CreateThread(function()
    while not Db.ready do Wait(500) end

    while true do
        Wait(300000)

        local hold = Config.Disposal.lockup.stash.holdMinutes or 0
        if hold > 0 then
            MySQL.query.await(
                'DELETE FROM xs_boosting_stored WHERE stored_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)',
                { hold })
        end
    end
end)
