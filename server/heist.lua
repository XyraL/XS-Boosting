Heist = {}

local running = 0

local function concurrentOk()
    if Config.Heist.concurrent <= 0 then return true end
    return running < Config.Heist.concurrent
end

local function pickCars(tier, count)
    local out = {}
    local pool = {}

    for _, vehicle in ipairs(tier.vehicles or {}) do pool[#pool + 1] = vehicle end
    if #pool == 0 then return out end

    for index = 1, count do
        local vehicle = pool[math.random(#pool)]
        out[index] = {
            index = index,
            model = vehicle.model,
            label = vehicle.label,
            basePay = vehicle.payout,
            taken = false,
            delivered = false,
        }
    end

    return out
end

function Heist.CanStart(src)
    if not Config.Heist.enabled then return false, 'That is switched off here.' end
    if not Players.HasUnit(src) then return false, 'You need a unit to do that.' end

    local record = Players.Of(src)
    if not record then return false, 'No character loaded.' end

    if record.rep < Config.Heist.repNeeded then
        return false, ('You need %d rep before anyone trusts you with that.'):format(Config.Heist.repNeeded)
    end

    if Jobs.Get(src) then return false, 'Finish what you are doing first.' end

    if not concurrentOk() then
        return false, 'Somebody else is already running one.'
    end

    local cooldown = Players.Cooldown(record.citizenid)
    if cooldown > 0 then
        return false, ('Wait %d more second%s.'):format(cooldown, cooldown == 1 and '' or 's')
    end

    if Config.Heist.policeRequired > 0 and Framework.PoliceCount() < Config.Heist.policeRequired then
        return false, 'Not enough police on duty for a job that size.'
    end

    if #Store.Enabled('heist') == 0 or #Store.Enabled('heist_exit') == 0 then
        return false, 'Nowhere has been set up for that yet.'
    end

    local tier = Tiers.Get(Config.Heist.tier)
    if not tier or #(tier.vehicles or {}) == 0 then
        return false, 'The heist tier has no vehicles configured.'
    end

    return true
end

function Heist.Start(src)
    local ok, reason = Heist.CanStart(src)
    if not ok then return false, reason end

    local sites = Store.Enabled('heist')
    local site = sites[math.random(#sites)]
    local exit = Store.Nearest('heist_exit', site.coords)

    if not exit then return false, 'That location has no exit point.' end

    local tier = Tiers.Get(Config.Heist.tier)
    local count = math.random(Config.Heist.vehicleCount.min, Config.Heist.vehicleCount.max)
    local record = Players.Of(src)

    local job = {
        id        = Jobs.NewId(),
        heist     = true,
        holder    = src,
        citizenid = record.citizenid,
        crew      = {},
        tier      = tier.id,
        stage     = 'staging',
        startedAt = os.time(),
        deadline  = os.time() + Config.Heist.timeLimitSeconds,
        site      = site,
        exit      = exit,
        cars      = pickCars(tier, count),
        delivered = 0,
        earned    = 0,
        contract  = { type = 'heist', tier = tier.id, model = '', label = 'Showroom', basePay = 0, market = Market.Get(tier.id) },
        tracker   = { alive = false, broadcasting = false },
        condition = 100,
    }

    running = running + 1
    Jobs.Register(job)

    -- Whoever is already crewed up with them is on it from the start, so a
    -- heist does not open with three more invites to send.
    Crew.Pull(job)
    Heist.Push(job)

    return true, nil, Heist.StateFor(job)
end

function Heist.StateFor(job)
    local cars = {}

    for _, car in ipairs(job.cars) do
        cars[#cars + 1] = {
            index = car.index,
            label = car.label,
            model = car.model,
            taken = car.taken,
            delivered = car.delivered,
            plate = car.plate,
        }
    end

    return {
        id        = job.id,
        heist     = true,
        type      = 'heist',
        tier      = job.tier,
        tierLabel = (Tiers.Get(job.tier) or {}).label or job.tier,
        stage     = job.stage,
        site      = Store.Plain(job.site.coords),
        siteRadius = job.site.radius,
        exit      = Store.Plain(job.exit.coords),
        exitRadius = Config.Heist.exitRadius,
        deadline  = job.deadline,
        remaining = math.max(0, job.deadline - os.time()),
        limit     = Config.Heist.timeLimitSeconds,
        cars      = cars,
        delivered = job.delivered,
        total     = #job.cars,
        crew      = Crew.Describe(job),
        crewMin   = Config.Heist.crewSize.min,
        crewMax   = Config.Heist.crewSize.max,
        payout    = Heist.Estimate(job),
    }
end

function Heist.Estimate(job)
    local total = 0

    for _, car in ipairs(job.cars) do
        total = total + Payout.Estimate({
            basePay = car.basePay,
            tier = job.tier,
            market = job.contract.market,
        })
    end

    return math.floor(total * (1 + (Config.Heist.completionBonusPct / 100)))
end

function Heist.Push(job)
    Jobs.Broadcast(job, 'XS-Boosting:client:job', Heist.StateFor(job))
end

function Heist.Begin(job)
    if job.stage ~= 'staging' then return false, 'Already running.' end

    if Crew.Size(job) < Config.Heist.crewSize.min then
        return false, ('You need at least %d of you.'):format(Config.Heist.crewSize.min)
    end

    local spawned = Heist.SpawnCars(job)
    if spawned == 0 then
        return false, 'That location has no car spawns on it.'
    end

    job.stage = 'running'
    job.spawned = true
    Heist.Push(job)

    if Config.Heist.alwaysAlertsPolice then
        Dispatch.Alert({
            code = '10-31',
            title = 'Vehicle Theft In Progress',
            description = 'Multiple vehicles being taken from one location.',
            coords = job.site.coords,
            priority = 1,
            sprite = 225,
            colour = 1,
        })
    end

    return true
end

-- Car spawns are placed on the heist site itself in the builder, so a
-- showroom with three bays runs a three-car job and never tries for four.
function Heist.SpawnCars(job)
    local spawns = job.site.data and job.site.data.spawns or {}
    if #spawns == 0 then return 0 end

    while #job.cars > #spawns do table.remove(job.cars) end

    local made = 0

    for index, car in ipairs(job.cars) do
        local point = spawns[index]
        -- Dropped in from just above the bay: see the note in Jobs.SpawnVehicle.
        local entity = CreateVehicle(joaat(car.model), point.x, point.y, point.z + 1.5, point.h or 0.0, true, true)

        local waited = 0
        while not DoesEntityExist(entity) and waited < 2000 do
            Wait(50)
            waited = waited + 50
        end

        if DoesEntityExist(entity) then
            car.entity = entity
            car.netId = NetworkGetNetworkIdFromEntity(entity)
            car.plate = ('H%s%03d'):format(job.id:sub(-3), index)

            pcall(SetVehicleNumberPlateText, entity, car.plate)

            local state = Entity(entity).state
            state:set('xsBoostHeist', { job = job.id, index = car.index }, true)
            state:set('xsBoostSetup', { plate = car.plate, fuel = math.random(40, 80) }, true)

            made = made + 1
        end
    end

    return made
end

function Heist.CarFor(job, index)
    for _, car in ipairs(job.cars) do
        if car.index == index then return car end
    end
    return nil
end

function Heist.Deliver(job, index, condition)
    local car = Heist.CarFor(job, index)
    if not car or car.delivered then return false end

    car.delivered = true
    job.delivered = job.delivered + 1

    local amount = Payout.Settle({
        basePay = car.basePay,
        tier = job.tier,
        market = job.contract.market,
        type = 'standard',
    }, { condition = condition or 100, route = 'buyer' })

    job.earned = job.earned + amount

    Jobs.Notify(job, ('%s away. %d of %d.'):format(car.label, job.delivered, #job.cars), 'success')
    Heist.Push(job)

    if job.delivered >= #job.cars then
        Heist.Finish(job)
    end

    return true, amount
end

function Heist.Finish(job)
    if job.finished then return end
    job.finished = true
    running = math.max(0, running - 1)

    local bonus = math.floor(job.earned * (Config.Heist.completionBonusPct / 100))
    local total = job.earned + bonus
    local members = Jobs.Members(job)

    for _, share in ipairs(Payout.Split(total, members, Config.Heist.payoutMode)) do
        Payout.Pay(share.src, share.amount, 'boosting heist')
    end

    local citizens = { job.citizenid }
    for _, citizenid in ipairs(Crew.Citizens(job)) do citizens[#citizens + 1] = citizenid end

    for _, citizenid in ipairs(citizens) do
        Players.AddRep(citizenid, Config.Heist.repReward)

        local record = Players.Get(citizenid)
        if record then
            record.heists = record.heists + 1
            record.earned = record.earned + total
            Players.Save(citizenid)
        end
    end

    Players.SetCooldown(job.citizenid, Config.Heist.cooldownMinutes * 60)

    Players.Record(job.citizenid, {
        type = 'heist', tier = job.tier, model = '', label = 'Showroom',
        outcome = 'heist', payout = total, condition = 100,
        crew = Crew.Citizens(job),
    })

    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', 'heist', nil, total)
    Heist.Cleanup(job)
end

function Heist.Fail(job, reason)
    if job.finished then return end
    job.finished = true
    running = math.max(0, running - 1)

    -- Cars already delivered still pay, just without the completion bonus.
    if job.earned > 0 then
        for _, share in ipairs(Payout.Split(job.earned, Jobs.Members(job), Config.Heist.payoutMode)) do
            Payout.Pay(share.src, share.amount, 'boosting heist')
        end
    end

    Players.SetCooldown(job.citizenid, Config.Heist.cooldownMinutes * 60)

    Players.Record(job.citizenid, {
        type = 'heist', tier = job.tier, model = '', label = 'Showroom',
        outcome = job.earned > 0 and 'partial' or 'failed',
        payout = job.earned, condition = 100,
        crew = Crew.Citizens(job),
    })

    Jobs.Notify(job, reason or 'The job fell apart.', 'error')
    Jobs.Broadcast(job, 'XS-Boosting:client:jobEnded', 'failed', reason, job.earned)
    Heist.Cleanup(job)
end

function Heist.Cleanup(job)
    for _, car in ipairs(job.cars) do
        if car.entity and DoesEntityExist(car.entity) then
            local entity = car.entity
            SetTimeout(Config.Vehicles.cleanupSeconds * 1000, function()
                if DoesEntityExist(entity) then DeleteEntity(entity) end
            end)
        end
    end

    for _, src in ipairs(Jobs.Members(job)) do Jobs.Unbind(src) end
    Jobs.Active()[job.id] = nil
    Crew.AfterJob(job)
end

function Heist.Tick(job, tick)
    if job.stage ~= 'running' then return end
    if tick % 5 ~= 0 then return end

    local alive = false

    for _, car in ipairs(job.cars) do
        if car.entity and DoesEntityExist(car.entity) then alive = true end
    end

    if job.delivered == 0 and job.spawned and not alive then
        Heist.Fail(job, 'Every car is gone.')
    end
end
