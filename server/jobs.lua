Jobs = {}

local active = {}
local bySource = {}
local nextJob = 1

local function jobId()
    local id = ('J%05d'):format(nextJob)
    nextJob = nextJob + 1
    return id
end

local function plate()
    local format = Config.Vehicles.plateFormat or '##???###'
    local out = {}

    for index = 1, #format do
        local char = format:sub(index, index)
        if char == '#' then
            out[#out + 1] = tostring(math.random(0, 9))
        elseif char == '?' then
            out[#out + 1] = string.char(math.random(65, 90))
        else
            out[#out + 1] = char
        end
    end

    return table.concat(out)
end

local function uniquePlate()
    for _ = 1, 12 do
        local candidate = plate()
        local taken = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE plate = ? LIMIT 1', { candidate })
        if not taken then return candidate end
    end
    return plate()
end

-- The zone is never centred on the car. It is pushed off by up to 40% of the
-- radius so that driving to the middle of the circle finds you nothing.
local function searchCentre(coords, radius)
    local angle = math.random() * math.pi * 2
    local distance = radius * 0.4 * math.sqrt(math.random())
    return vec3(coords.x + math.cos(angle) * distance, coords.y + math.sin(angle) * distance, coords.z)
end

local function rollSting(tier)
    if not Config.Sting.enabled then return false end
    local chance = Config.Sting.tierChance[tier] or Config.Sting.chance
    return math.random(100) <= chance
end

function Jobs.Get(src)
    local id = bySource[src]
    return id and active[id] or nil
end

function Jobs.ById(id)
    return active[id]
end

function Jobs.Register(job)
    active[job.id] = job
    bySource[job.holder] = job.id
    return job
end

function Jobs.NewId()
    return jobId()
end

function Jobs.Bind(src, id)
    bySource[src] = id
end

function Jobs.Unbind(src)
    bySource[src] = nil
end

function Jobs.Members(job)
    local out = { job.holder }
    for _, src in ipairs(job.crew or {}) do out[#out + 1] = src end
    return out
end

function Jobs.Broadcast(job, event, ...)
    for _, src in ipairs(Jobs.Members(job)) do
        TriggerClientEvent(event, src, ...)
    end
end

function Jobs.Notify(job, message, kind)
    for _, src in ipairs(Jobs.Members(job)) do
        Framework.Notify(src, message, kind)
    end
end

local function activeCountFor(citizenid)
    local count = 0
    for _, job in pairs(active) do
        if job.citizenid == citizenid then count = count + 1 end
    end
    return count
end

function Jobs.CanAccept(src, contract)
    if not Players.HasUnit(src) then
        return false, 'You need a unit to do that.'
    end

    local record = Players.Of(src)
    if not record then return false, 'No character loaded.' end

    if not Tiers.Unlocked(contract.tier, record.rep) then
        local tier = Tiers.Get(contract.tier)
        return false, ('%s work needs %d rep.'):format(tier and tier.label or contract.tier, tier and tier.repNeeded or 0)
    end

    if Config.Contracts.maxActive > 0 and activeCountFor(record.citizenid) >= Config.Contracts.maxActive then
        return false, 'You already have a contract running.'
    end

    local cooldown = Players.Cooldown(record.citizenid)
    if cooldown > 0 then
        return false, ('Wait %d more second%s.'):format(cooldown, cooldown == 1 and '' or 's')
    end

    if Config.Police.required > 0 and Framework.PoliceCount() < Config.Police.required then
        return false, 'Nobody is listening to the radio right now.'
    end

    if Config.Contracts.dailyLimit > 0 then
        local today = MySQL.scalar.await([[
            SELECT COUNT(*) FROM xs_boosting_history
            WHERE citizenid = ? AND created_at >= CURDATE()
        ]], { record.citizenid }) or 0

        if today >= Config.Contracts.dailyLimit then
            return false, 'That is enough for one day.'
        end
    end

    return true
end

function Jobs.Accept(src, contractId)
    local contract = Contracts.Find(src, contractId)
    if not contract then return false, 'That contract is gone.' end
    if contract.takenBy then return false, 'Somebody already took that one.' end

    local ok, reason = Jobs.CanAccept(src, contract)
    if not ok then return false, reason end

    -- Boards are per player, so two people can be holding a listing that
    -- points at the same corner. Whoever gets there second is quietly sent
    -- somewhere else instead of turning up to find the car already gone.
    if Contracts.SpawnBusy(contract.spawnId) then
        local elsewhere = Store.RandomSpawn(contract.tier, Contracts.BusySpawns())
        if elsewhere then contract.spawnId = elsewhere.id end
    end

    local spawn = Store.Get(contract.spawnId)
    local buyer = Store.Get(contract.buyerId)
    if not spawn or not buyer then return false, 'That contract cannot be run right now.' end

    local record = Players.Of(src)
    local tier = Tiers.Get(contract.tier)
    local id = jobId()

    local job = {
        id        = id,
        contract  = contract,
        holder    = src,
        citizenid = record.citizenid,
        crew      = {},
        tier      = contract.tier,
        stage     = 'search',
        startedAt = os.time(),
        deadline  = os.time() + (tier and tier.timeLimitSeconds or 900)
            + Unlocks.Buff(record, 'time_bonus'),
        spawn     = spawn,
        buyer     = buyer,
        centre    = searchCentre(spawn.coords, contract.radius),
        plate     = uniquePlate(),
        condition = 100,
        parts     = {},
        fitted    = {
            alarm   = Tiers.Fitted(contract.tier, 'alarm'),
            tracker = Config.Theft.tracker.enabled and Tiers.Fitted(contract.tier, 'tracker') or false,
        },
        sting     = rollSting(contract.tier),
        tracker   = { alive = true, broadcasting = false },
    }

    -- A driving car has somebody at the wheel. No alarm to set off, and the
    -- lock is irrelevant once they are out of it.
    local driving = Config.Vehicles.driving
    if driving.enabled then
        local chance = tier and tier.drivingChance or driving.chance
        job.driving = math.random(100) <= (chance or 0)
    end

    if job.driving then
        job.fitted.alarm = false
    end

    contract.takenBy = record.citizenid
    active[id] = job
    bySource[src] = id

    -- The spot sits out now that it is actually being used, rather than when
    -- it was listed. Six listings a player, and resting at listing time would
    -- retire every spawn point on the map before anybody drove anywhere.
    Store.Rest(spawn.id, Config.Contracts.spawnCooldownMinutes)

    Contracts.Remove(src, contract.id)

    -- Only this board lost a listing. Everybody else is told nothing, unless
    -- the whole server is sharing one.
    if Config.Contracts.sharedBoard then
        Contracts.Refresh()
    else
        Contracts.Fill(src)
    end

    -- Anyone already crewed up with them comes along without being asked.
    Crew.Pull(job)

    Jobs.PushState(job)
    return true, nil, Jobs.StateFor(job)
end

-- What a client is allowed to know. The exact spawn point is never in here.
function Jobs.StateFor(job)
    local tier = Tiers.Get(job.tier)

    return {
        id        = job.id,
        type      = job.contract.type,
        tier      = job.tier,
        tierLabel = tier and tier.label or job.tier,
        model     = job.contract.model,
        label     = job.contract.label,
        plate     = job.plate,
        colour    = job.contract.colour and job.contract.colour.name or nil,
        minCondition = job.contract.minCondition,
        parts     = job.contract.parts,
        collected = job.parts,
        stage     = job.stage,
        centre    = Store.Plain(job.centre),
        radius    = job.contract.radius,
        buyer     = (job.stage == 'transit' or job.stage == 'chop') and Store.Plain(job.buyer.coords) or nil,
        buyerRadius = Config.Disposal.buyer.radius,
        deadline  = job.deadline,
        remaining = math.max(0, job.deadline - os.time()),
        limit     = tier and tier.timeLimitSeconds or 900,
        condition = job.condition,
        fitted    = job.fitted,
        driving   = job.driving and true or false,
        stopped   = job.stopped and true or false,
        tracker   = { alive = job.tracker.alive, broadcasting = job.tracker.broadcasting },
        payout    = Payout.Estimate(job.contract),
        crew      = Crew.Describe(job),
        holderId  = job.holder,
        remoteTracker = Config.Duo.remoteTracker and true or false,
        netId     = job.netId,
    }
end

function Jobs.PushState(job)
    local state = Jobs.StateFor(job)
    Jobs.Broadcast(job, 'XS-Boosting:client:job', state)
end

local function alertCoords(job)
    if job.entity and DoesEntityExist(job.entity) then
        return GetEntityCoords(job.entity)
    end
    return job.spawn.coords
end

function Jobs.Alert(job, kind)
    local entry = Config.Police.alerts[kind]
    if not entry or not entry.enabled then return end

    if kind == 'chop' and math.random(100) > (entry.chance or 100) then return end

    local info = ({
        theft = { code = '10-16', title = 'Vehicle Theft', text = ('A %s was taken.'):format(job.contract.label) },
        alarm = { code = '10-16', title = 'Vehicle Alarm', text = ('An alarm is sounding on a %s.'):format(job.contract.label) },
        chop  = { code = '10-51', title = 'Chop Shop', text = 'Someone is stripping a vehicle.' },
    })[kind]

    if not info then return end

    Dispatch.Alert({
        code = info.code,
        title = info.title,
        description = ('%s Plate %s.'):format(info.text, job.plate),
        coords = alertCoords(job),
        priority = 2,
        sprite = 225,
        colour = 47,
    })

    -- Whoever is on the job should know the police were told, and what for.
    local heard = {
        theft = { title = 'Reported stolen', text = 'The theft has gone out over the radio.', kind = 'warn' },
        alarm = { title = 'Alarm called in', text = 'Somebody phoned the noise in.', kind = 'warn' },
        chop  = { title = 'Chop shop reported', text = 'Someone saw you stripping it.', kind = 'bad' },
    }

    local note = heard[kind]
    if note then
        Jobs.Broadcast(job, 'XS-Boosting:client:jobAlert', note)
    end
end

function Jobs.SpawnVehicle(job)
    if job.entity and DoesEntityExist(job.entity) then return job.entity end

    -- Spawn points are saved at road height, but a vehicle's origin is the
    -- middle of its chassis. Put that on the road and half the car is inside
    -- it, and the physics engine throws it out — which is why they flipped.
    -- Drop it in from just above instead and let it settle.
    local coords = job.spawn.coords
    local entity = CreateVehicle(joaat(job.contract.model), coords.x, coords.y, coords.z + 1.5,
        job.spawn.heading or 0.0, true, true)

    local waited = 0
    while not DoesEntityExist(entity) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end

    if not DoesEntityExist(entity) then return nil end

    job.entity = entity
    job.netId = NetworkGetNetworkIdFromEntity(entity)

    pcall(SetVehicleNumberPlateText, entity, job.plate)

    -- Cosmetics and the lock are applied by whichever client owns the entity.
    -- The state bag is the handover, so it survives the owner changing.
    local state = Entity(entity).state
    state:set('xsBoostJob', job.id, true)
    state:set('xsBoostSetup', {
        plate  = job.plate,
        colour = job.contract.colour and job.contract.colour.index or nil,
        dirt   = math.random(math.floor(Config.Vehicles.dirtLevel.min * 10), math.floor(Config.Vehicles.dirtLevel.max * 10)) / 10,
        fuel   = math.random(Config.Vehicles.fuel.min, Config.Vehicles.fuel.max),
    }, true)

    if job.driving then Jobs.SpawnDriver(job) end

    Jobs.PushState(job)
    return entity
end

-- The driver is spawned by the server so it exists for everyone, but the
-- actual driving task is given by whichever client owns the ped. The state
-- bag is how that gets handed over.
function Jobs.SpawnDriver(job)
    if job.driver and DoesEntityExist(job.driver) then return job.driver end
    if not job.entity or not DoesEntityExist(job.entity) then return nil end

    local models = Config.Vehicles.driving.drivers
    local model = models[math.random(#models)]
    local coords = GetEntityCoords(job.entity)

    local ped = CreatePed(4, joaat(model), coords.x, coords.y, coords.z, 0.0, true, true)

    local waited = 0
    while not DoesEntityExist(ped) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end

    if not DoesEntityExist(ped) then return nil end

    SetPedIntoVehicle(ped, job.entity, -1)

    job.driver = ped
    job.driverNet = NetworkGetNetworkIdFromEntity(ped)

    Entity(ped).state:set('xsBoostDriver', {
        job = job.id,
        speed = Config.Vehicles.driving.speed,
        style = Config.Vehicles.driving.style,
        bailAtDamage = Config.Vehicles.driving.bailAtDamage,
        stoppedSeconds = Config.Vehicles.driving.stoppedSeconds,
    }, true)

    return ped
end

-- The car is takeable the moment the seat is empty, however that happened.
function Jobs.CheckDriver(job)
    if not job.driving or job.stopped then return end
    if not job.entity or not DoesEntityExist(job.entity) then return end

    local seat = GetPedInVehicleSeat(job.entity, -1)
    if seat and seat ~= 0 and DoesEntityExist(seat) then return end

    job.stopped = true

    -- The lock never mattered on this one, so it goes straight to hotwiring.
    if job.stage == 'search' then
        job.stage = 'entry'
    end

    Jobs.PushState(job)
    Jobs.Notify(job, 'The driver is out. Take it.', 'success')

    Jobs.Broadcast(job, 'XS-Boosting:client:jobAlert', {
        title = 'Driver is out',
        text = 'Get in and hotwire it before they come back with help.',
        kind = 'good',
    })
end

function Jobs.ReadCondition(job)
    if not job.entity or not DoesEntityExist(job.entity) then return job.condition end

    local body, engine = 1000.0, 1000.0
    pcall(function()
        body = GetVehicleBodyHealth(job.entity) or 1000.0
        engine = GetVehicleEngineHealth(job.entity) or 1000.0
    end)

    local weights = Config.Condition.weights
    local total = (weights.body or 1) + (weights.engine or 1)
    if total <= 0 then return job.condition end

    local bodyPct = math.max(0, math.min(100, (body / 1000) * 100))
    local enginePct = math.max(0, math.min(100, (engine / 1000) * 100))
    local score = ((bodyPct * (weights.body or 1)) + (enginePct * (weights.engine or 1))) / total

    -- A condition buffer forgives the first few percent of damage, so a
    -- careful driver is not punished for a kerb.
    local buffer = Unlocks.BuffFor(job.citizenid, 'condition_buffer')
    local final = score - (job.conditionPenalty or 0) + buffer

    job.condition = math.floor(math.max(0, math.min(100, final)))
    return job.condition
end

function Jobs.Penalise(job, amount)
    job.conditionPenalty = (job.conditionPenalty or 0) + amount
    Jobs.ReadCondition(job)
    Jobs.PushState(job)
end

function Jobs.Stage(job, stage)
    job.stage = stage
    Jobs.PushState(job)
end

function Jobs.StartTracker(job)
    if not job.fitted.tracker or not job.tracker.alive then return end
    if job.tracker.broadcasting then return end

    job.tracker.broadcasting = true
    job.tracker.startedAt = os.time()
    Jobs.PushState(job)
    Jobs.Notify(job, 'The tracker is live. They can see you.', 'error')

    Jobs.Broadcast(job, 'XS-Boosting:client:jobAlert', {
        title = 'Tracker is live',
        text = 'It is feeding your position. Kill it at the car or reach a dead zone.',
        kind = 'bad',
        hold = 9000,
    })
end

function Jobs.KillTracker(job)
    job.tracker.alive = false

    if job.tracker.broadcasting then
        job.tracker.broadcasting = false
        Dispatch.Untrack(job.id)
    end

    Jobs.PushState(job)
end

function Jobs.Cleanup(job, keepVehicle, afterSeconds)
    if job.tracker.broadcasting then Dispatch.Untrack(job.id) end

    if job.driver and DoesEntityExist(job.driver) then
        DeleteEntity(job.driver)
        job.driver = nil
    end

    if job.entity and DoesEntityExist(job.entity) and not keepVehicle then
        local entity = job.entity
        local delay = afterSeconds or Config.Vehicles.cleanupSeconds

        SetTimeout(delay * 1000, function()
            if DoesEntityExist(entity) then DeleteEntity(entity) end
        end)
    end

    for _, src in ipairs(Jobs.Members(job)) do
        if bySource[src] == job.id then bySource[src] = nil end
    end

    active[job.id] = nil
    Crew.AfterJob(job)
end

local function applyCooldown(job)
    local tier = Tiers.Get(job.tier)
    local seconds = math.max(
        (tier and tier.cooldownMinutes or 5) * 60,
        Config.Contracts.globalCooldownMinutes * 60)

    local cut = Unlocks.BuffFor(job.citizenid, 'cooldown_pct')
    if cut > 0 then seconds = seconds * (1 - math.min(90, cut) / 100) end

    Players.SetCooldown(job.citizenid, math.floor(seconds))
end

function Jobs.Fail(job, reason, silent)
    if job.finished then return end
    job.finished = true

    applyCooldown(job)

    local record = Players.Get(job.citizenid)
    if record then
        record.failed = record.failed + 1
        Players.Save(job.citizenid)
    end

    if Config.Rep.failPenalty > 0 then
        Players.AddRep(job.citizenid, -Config.Rep.failPenalty)
    end

    Players.Record(job.citizenid, {
        type = job.contract.type, tier = job.tier,
        model = job.contract.model, label = job.contract.label,
        outcome = 'failed', payout = 0, condition = job.condition,
        crew = Crew.Citizens(job),
    })

    if not silent then
        Jobs.Notify(job, reason or 'The contract is dead.', 'error')
    end

    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', 'failed', reason)
    Jobs.Cleanup(job)
end

function Jobs.Complete(job, route, opts)
    if job.finished then return 0 end
    job.finished = true
    opts = opts or {}

    local condition = Jobs.ReadCondition(job)
    local members = Jobs.Members(job)
    local isDuo = #members > 1

    local amount = Payout.Settle(job.contract, {
        condition = condition,
        route = route,
        specMatched = opts.specMatched,
        duo = isDuo,
        citizenid = job.citizenid,
    })

    if opts.extra and opts.extra > 0 then
        amount = amount + opts.extra
    end

    local mode = isDuo and Config.Duo.payoutMode or 'holder'
    for _, share in ipairs(Payout.Split(amount, members, mode)) do
        Payout.Pay(share.src, share.amount, 'boosting')
    end

    local tier = Tiers.Get(job.tier)
    local repReward = tier and tier.repReward or 0

    if route == 'fence' then
        repReward = -(Config.Disposal.fence.repPenalty or 0)
    end

    local citizens = { job.citizenid }
    if isDuo and Config.Duo.repBoth then
        for _, citizenid in ipairs(Crew.Citizens(job)) do citizens[#citizens + 1] = citizenid end
    end

    -- Taken before the counters move, so Unlocks.Check can tell what is new.
    local snapshots = {}
    for _, citizenid in ipairs(citizens) do
        snapshots[citizenid] = Unlocks.Snapshot(Players.Get(citizenid))
    end

    for _, citizenid in ipairs(citizens) do
        if repReward ~= 0 then Players.AddRep(citizenid, repReward) end

        local record = Players.Get(citizenid)
        if record then
            if route == 'chop' then
                record.chopped = record.chopped + 1
            else
                record.completed = record.completed + 1
            end
            record.earned = record.earned + amount
            Players.Save(citizenid)
        end
    end

    applyCooldown(job)

    for _, citizenid in ipairs(citizens) do
        Unlocks.Check(citizenid, snapshots[citizenid])
    end

    Players.Record(job.citizenid, {
        type = job.contract.type, tier = job.tier,
        model = job.contract.model, label = job.contract.label,
        outcome = route, payout = amount, condition = condition,
        crew = Crew.Citizens(job),
    })

    -- What is left of a chopped car. A burnt-out shell is the point of a
    -- chop shop; leaving it is the option for servers that want the mess.
    local keep = false

    if route == 'chop' and job.entity and DoesEntityExist(job.entity) then
        if Config.Chop.shell == 'burn' then
            Entity(job.entity).state:set('xsBoostBurn', true, true)
        elseif Config.Chop.shell == 'leave' then
            keep = true
        end
    end

    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', route, nil, amount)

    -- A car that has been handed over should leave, not sit at the drop for a
    -- minute while everyone stands around it.
    Jobs.Cleanup(job, keep, route == 'buyer' and Config.Disposal.buyer.despawnSeconds or nil)

    return amount
end

function Jobs.Abandon(src)
    local job = Jobs.Get(src)
    if not job then return false end

    if job.holder ~= src then
        Crew.Leave(job, src)
        return true
    end

    Jobs.Fail(job, 'You walked away from it.')
    return true
end

function Jobs.Active()
    return active
end

AddEventHandler('playerDropped', function()
    local job = Jobs.Get(source)
    if not job then return end

    if job.holder == source then
        Jobs.Fail(job, nil, true)
    else
        Crew.Leave(job, source)
    end
end)

-- One thread runs every live job: the clock, spawning the car in once somebody
-- is close enough to see it appear, the tracker feed, and losing the car.
CreateThread(function()
    local tick = 0

    while true do
        Wait(1000)
        tick = tick + 1
        local now = os.time()

        for _, job in pairs(active) do
            if not job.finished then
                if now >= job.deadline then
                    if job.heist then
                        Heist.Fail(job, 'Out of time.')
                    else
                        Jobs.Fail(job, 'Out of time.')
                    end
                    goto continue
                end

                if job.heist then
                    Heist.Tick(job, tick)
                    goto continue
                end

                if not job.entity then
                    for _, src in ipairs(Jobs.Members(job)) do
                        local ped = GetPlayerPed(src)
                        if ped and ped ~= 0 then
                            local distance = #(GetEntityCoords(ped) - job.spawn.coords)
                            if distance <= Config.Vehicles.spawnDistance then
                                Jobs.SpawnVehicle(job)
                                break
                            end
                        end
                    end
                elseif not DoesEntityExist(job.entity) then
                    Jobs.Fail(job, 'The car is gone.')
                    goto continue
                end

                if job.tracker.broadcasting then
                    local limit = Config.Police.alerts.tracker.maxMinutes
                    if limit > 0 and now - (job.tracker.startedAt or now) >= limit * 60 then
                        job.tracker.broadcasting = false
                        Dispatch.Untrack(job.id)
                        Jobs.PushState(job)
                    elseif tick % math.max(1, Config.Police.alerts.tracker.updateSeconds) == 0 then
                        Dispatch.Track(job.id, alertCoords(job), ('Stolen %s'):format(job.contract.label))
                    end
                end

                if job.driving and job.entity and tick % 2 == 0 then
                    Jobs.CheckDriver(job)
                end

                if job.entity and tick % 5 == 0 then
                    local before = job.condition
                    if Jobs.ReadCondition(job) ~= before then
                        Jobs.PushState(job)
                    end
                end

                -- Lose the unit and you lose the job with it. Checked on the
                -- server so handing it off mid-contract cannot be hidden.
                local every = Config.Access.checkSeconds or 0
                if every > 0 and tick % every == 0 then
                    if not Players.HasUnit(job.holder) then
                        Jobs.Fail(job, 'You lost the unit.')
                        goto continue
                    end
                end
            end

            ::continue::
        end
    end
end)
