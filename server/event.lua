Event = { current = nil }

-- One car, everybody at once, first one home keeps it. There is no per-player
-- job here: the event is a single shared thing and players attach themselves
-- to it. That is why it does not live in the Jobs table.

local nextAt = 0

local function playersOnline()
    return #GetPlayers()
end

local function countdown()
    local base = Config.Events.everyMinutes
    if base <= 0 then return math.huge end

    local spread = Config.Events.varianceMinutes or 0
    local offset = spread > 0 and math.random(-spread, spread) or 0

    return os.time() + math.max(60, (base + offset) * 60)
end

function Event.Active()
    local event = Event.current
    if not event or event.finished then return nil end
    return event
end

function Event.CanStart()
    if not Config.Events.enabled then return false, 'Contested contracts are switched off.' end
    if Event.Active() then return false, 'One is already running.' end

    if playersOnline() < (Config.Events.minPlayers or 0) then
        return false, 'Not enough people online for it to be a contest.'
    end

    if Config.Events.policeRequired > 0 and Framework.PoliceCount() < Config.Events.policeRequired then
        return false, 'Not enough police on duty.'
    end

    local spawns = Store.Enabled('spawn', Config.Events.spawnTier)
    if #spawns == 0 then
        return false, ('No spawn points tagged "%s" to put it on.'):format(Config.Events.spawnTier)
    end

    if #Store.Enabled('buyer') == 0 then
        return false, 'No handover point to take it to.'
    end

    if #(Config.Events.vehicles or {}) == 0 then
        return false, 'No vehicles configured for it.'
    end

    return true
end

function Event.Start()
    local ok, reason = Event.CanStart()
    if not ok then return false, reason end

    local spawns = Store.Enabled('spawn', Config.Events.spawnTier)
    local spawn = spawns[math.random(#spawns)]
    local buyers = Store.Enabled('buyer')
    local buyer = buyers[math.random(#buyers)]
    local vehicle = Config.Events.vehicles[math.random(#Config.Events.vehicles)]

    local event = {
        id       = ('E%04d'):format(math.random(1000, 9999)),
        model    = vehicle.model,
        label    = vehicle.label,
        payout   = vehicle.payout,
        spawn    = spawn,
        buyer    = buyer,
        plate    = ('HOT%04d'):format(math.random(0, 9999)),
        joined   = {},
        deadline = os.time() + Config.Events.windowSeconds,
        started  = os.time(),
    }

    Event.current = event
    Event.Spawn(event)
    Event.Push()

    -- Everybody hears about it, whether their unit is open or not.
    TriggerClientEvent('XS-Boosting:client:event', -1, Event.Describe(event), 'started')

    nextAt = countdown()
    return true, nil, Event.Describe(event)
end

function Event.Spawn(event)
    local coords = event.spawn.coords
    local entity = CreateVehicle(joaat(event.model), coords.x, coords.y, coords.z + 1.5,
        event.spawn.heading or 0.0, true, true)

    local waited = 0
    while not DoesEntityExist(entity) and waited < 3000 do
        Wait(50)
        waited = waited + 50
    end

    if not DoesEntityExist(entity) then
        Event.current = nil
        return nil
    end

    event.entity = entity
    event.netId = NetworkGetNetworkIdFromEntity(entity)

    pcall(SetVehicleNumberPlateText, entity, event.plate)

    Entity(entity).state:set('xsBoostEvent', event.id, true)
    Entity(entity).state:set('xsBoostSetup', {
        plate = event.plate,
        fuel = math.random(60, 95),
    }, true)

    if Config.Events.guards.enabled then
        Event.SpawnGuards(event)
    end

    return entity
end

-- Guards belong to the event rather than to whoever turns up first, so they
-- are hostile to everybody and stay put until somebody deals with them.
function Event.SpawnGuards(event)
    local guards = Config.Events.guards
    local centre = event.spawn.coords
    event.guards = {}

    for index = 1, guards.count do
        local angle = (index / guards.count) * math.pi * 2
        local x = centre.x + math.cos(angle) * guards.radius
        local y = centre.y + math.sin(angle) * guards.radius

        local ped = CreatePed(4, joaat(guards.model), x, y, centre.z, 0.0, true, true)

        local waited = 0
        while not DoesEntityExist(ped) and waited < 1500 do
            Wait(50)
            waited = waited + 50
        end

        if DoesEntityExist(ped) then
            event.guards[#event.guards + 1] = ped

            Entity(ped).state:set('xsBoostGuard', {
                event = event.id,
                weapon = guards.weapon,
                accuracy = guards.accuracy,
                armour = guards.armour,
            }, true)
        end
    end
end

function Event.Describe(event)
    if not event then return nil end

    return {
        id        = event.id,
        model     = event.model,
        label     = event.label,
        plate     = event.plate,
        payout    = event.payout,
        coords    = Store.Plain(event.spawn.coords),
        buyer     = Store.Plain(event.buyer.coords),
        buyerRadius = Config.Disposal.buyer.radius,
        remaining = math.max(0, event.deadline - os.time()),
        window    = Config.Events.windowSeconds,
        joined    = #event.joined,
        guards    = Config.Events.guards.enabled and Config.Events.guards.count or 0,
        taken     = event.takenBy ~= nil,
    }
end

function Event.Push(target)
    TriggerClientEvent('XS-Boosting:client:eventState', target or -1, Event.Describe(Event.Active()))
end

function Event.Join(src)
    local event = Event.Active()
    if not event then return false, 'There is nothing running.' end

    if not Players.HasUnit(src) then return false, 'You need a unit to do that.' end
    if Jobs.Get(src) then return false, 'Finish what you are doing first.' end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    for _, entry in ipairs(event.joined) do
        if entry == citizenid then return true, nil, Event.Describe(event) end
    end

    event.joined[#event.joined + 1] = citizenid
    Event.Push()

    return true, nil, Event.Describe(event)
end

function Event.Joined(src)
    local event = Event.Active()
    if not event then return false end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false end

    for _, entry in ipairs(event.joined) do
        if entry == citizenid then return true end
    end

    return false
end

-- First one to bring it in wins, and that closes the whole thing for
-- everybody else.
function Event.Deliver(src)
    local event = Event.Active()
    if not event then return false, 'There is nothing running.' end
    if event.takenBy then return false, 'Somebody already took it.' end
    if not Event.Joined(src) then return false, 'You are not in on this one.' end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'No.' end

    if not event.entity or not DoesEntityExist(event.entity) then
        return false, 'The car is gone.'
    end

    local buyer = event.buyer.coords
    if #(GetEntityCoords(ped) - buyer) > Config.Disposal.buyer.radius then
        return false, 'Not close enough to the handover.'
    end

    if #(GetEntityCoords(event.entity) - buyer) > Config.Disposal.buyer.radius then
        return false, 'The car is not here.'
    end

    local body = 1000.0
    pcall(function() body = GetVehicleBodyHealth(event.entity) or 1000.0 end)
    local condition = math.floor(math.max(0, math.min(100, (body / 1000) * 100)))

    if condition < Config.Events.refuseBelow then
        return false, 'There is not enough of it left to sell.'
    end

    local citizenid = Framework.GetCitizenId(src)
    event.takenBy = citizenid

    local amount = math.floor(event.payout * (Payout.ConditionPct(condition) / 100))
    amount = amount + math.floor(amount * (Unlocks.BuffFor(citizenid, 'payout_pct') / 100))

    Payout.Pay(src, amount, 'contested contract')
    Players.AddRep(citizenid, Config.Events.repReward)

    local record = Players.Get(citizenid)
    if record then
        record.completed = record.completed + 1
        record.earned = record.earned + amount
        Players.Save(citizenid)
    end

    Players.Record(citizenid, {
        type = 'event', tier = Config.Events.spawnTier,
        model = event.model, label = event.label,
        outcome = 'event', payout = amount, condition = condition,
    })

    TriggerClientEvent('XS-Boosting:client:event', -1, {
        winner = Players.DisplayName(Players.Get(citizenid)),
        label = event.label,
        amount = amount,
    }, 'won')

    Event.Finish()
    return true, nil, amount
end

-- The police are told when it actually moves, not when it goes up. Nobody
-- reports a parked car.
function Event.CheckMoved(event)
    if event.reported or not Config.Events.alertsPolice then return end
    if not event.entity or not DoesEntityExist(event.entity) then return end

    local moved = #(GetEntityCoords(event.entity) - event.spawn.coords)
    if moved < 25.0 then return end

    event.reported = true

    Dispatch.Alert({
        code = '10-31',
        title = 'High Value Vehicle Theft',
        description = ('A %s has been taken. Plate %s. Expect company.'):format(event.label, event.plate),
        coords = GetEntityCoords(event.entity),
        priority = 1,
        sprite = 225,
        colour = 1,
    })
end

function Event.Finish(reason)
    local event = Event.current
    if not event then return end

    event.finished = true

    if event.entity and DoesEntityExist(event.entity) then
        local entity = event.entity
        SetTimeout(Config.Vehicles.cleanupSeconds * 1000, function()
            if DoesEntityExist(entity) then DeleteEntity(entity) end
        end)
    end

    for _, ped in ipairs(event.guards or {}) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end

    if reason then
        TriggerClientEvent('XS-Boosting:client:event', -1, { reason = reason }, 'ended')
    end

    Event.current = nil
    Event.Push()

    nextAt = countdown()
end

CreateThread(function()
    while not Store.Ready() do Wait(500) end

    nextAt = countdown()

    while true do
        Wait(10000)

        local event = Event.Active()

        if event then
            if os.time() >= event.deadline then
                Event.Finish('Nobody came for it.')
            elseif event.entity and not DoesEntityExist(event.entity) then
                Event.Finish('The car is gone.')
            else
                Event.CheckMoved(event)
                Event.Push()
            end
        elseif Config.Events.enabled and Config.Events.everyMinutes > 0 and os.time() >= nextAt then
            local ok = Event.Start()
            if not ok then nextAt = os.time() + 300 end
        end
    end
end)
