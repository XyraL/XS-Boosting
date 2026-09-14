-- Every call the client is allowed to make lives here. Nothing in this file
-- trusts its arguments: the job is looked up from the caller, the stage order
-- is enforced, and anything that happens at a place is distance-checked
-- against the server's own copy of that place.

local function jobOf(src)
    local job = Jobs.Get(src)
    if not job or job.finished then return nil end
    return job
end

local function nearEntity(src, entity, range)
    if not entity or not DoesEntityExist(entity) then return false end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end

    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= (range or 8.0)
end

local function nearCoords(src, coords, range)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (range or 10.0)
end

lib.callback.register('XS-Boosting:bootstrap', function(src, force)
    -- The only way past the item is an admin testing with /boostopen.
    if not (force and Framework.IsAdmin(src)) and not Players.HasUnit(src) then
        return false
    end

    local job = Jobs.Get(src)

    return {
        stats     = Stats.For(src),
        board     = Contracts.For(src),
        market    = Market.All(),
        marketIn  = Market.NextShiftIn(),
        refreshIn = Contracts.NextRefreshIn(src),
        job       = job and (job.heist and Heist.StateFor(job) or Jobs.StateFor(job)) or nil,
        locations = Store.Public(),
        event     = Event.Describe(Event.Active()),
        joinedEvent = Event.Joined(src),
        discovered = Store.DiscoveredBy(Framework.GetCitizenId(src)),
        admin     = Framework.IsAdmin(src),
        ui        = Config.UI,
        settings  = Players.Settings(Framework.GetCitizenId(src)),
        version   = ('v%s'):format(GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or '0.3.0'),
        hack      = Config.Theft.tracker.hack,
        heist     = {
            enabled   = Config.Heist.enabled,
            repNeeded = Config.Heist.repNeeded,
            crewMin   = Config.Heist.crewSize.min,
            crewMax   = Config.Heist.crewSize.max,
        },
        duo       = { enabled = Config.Duo.enabled, radius = Config.Duo.inviteRadius },
        crew      = Crew.State(src),
        crewRules = {
            enabled  = Config.Crew.enabled,
            maxSize  = Config.Crew.maxSize,
            radius   = Config.Crew.inviteRadius,
            autoJoin = Config.Crew.autoJoin,
        },
    }
end)

RegisterNetEvent('XS-Boosting:server:discovered', function(ids)
    local src = source
    if type(ids) ~= 'table' or #ids == 0 or #ids > 50 then return end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return end

    for _, id in ipairs(ids) do
        id = tonumber(id)
        local place = id and Store.Get(id)

        -- Only a place they could actually have reached counts, and only a
        -- kind that is meant to be findable at all.
        if place and Store.IsPublic(place.kind) then
            local ped = GetPlayerPed(src)
            if ped and ped ~= 0 and #(GetEntityCoords(ped) - place.coords) <= math.max(place.radius, 30.0) then
                MySQL.insert('INSERT IGNORE INTO xs_boosting_discovered (citizenid, location_id) VALUES (?, ?)',
                    { citizenid, id })
            end
        end
    end
end)

lib.callback.register('XS-Boosting:board', function(src)
    if not Players.HasUnit(src) then return {} end
    return Contracts.For(src)
end)

lib.callback.register('XS-Boosting:hasItem', function(src, item)
    if type(item) ~= 'string' then return false end
    return Inv.Has(src, item, 1)
end)

-- Wearing a tool out is a server decision, so the client only reports that it
-- used one. Which tool, and whether it is consumed at all, is config.
RegisterNetEvent('XS-Boosting:server:toolUsed', function(kind)
    local src = source
    local job = jobOf(src)
    if not job then return end

    if kind == 'lockpick' then
        local settings = Config.Theft.entry.methods.lockpick
        if not settings.enabled or not settings.item or settings.item == '' then return end

        if settings.consume then
            Inv.Remove(src, settings.item, 1)
        else
            Inv.Damage(src, settings.item, settings.durability)
        end
    elseif kind == 'tracker' then
        local settings = Config.Theft.tracker
        if not settings.item or settings.item == '' then return end
        if settings.consume then Inv.Remove(src, settings.item, 1) end
    end
end)

lib.callback.register('XS-Boosting:stats', function(src)
    if not Players.HasUnit(src) then return nil end
    return Stats.For(src)
end)

lib.callback.register('XS-Boosting:leaderboard', function()
    return Stats.Leaderboard()
end)

lib.callback.register('XS-Boosting:setHandle', function(src, handle)
    if type(handle) ~= 'string' then return false, 'Bad request.' end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    return Players.SetHandle(citizenid, handle)
end)

lib.callback.register('XS-Boosting:accept', function(src, contractId)
    if type(contractId) ~= 'string' then return false, 'Bad request.' end
    return Jobs.Accept(src, contractId)
end)

lib.callback.register('XS-Boosting:abandon', function(src)
    return Jobs.Abandon(src)
end)

lib.callback.register('XS-Boosting:nearby', function(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return {} end

    local origin = GetEntityCoords(ped)

    -- The same list serves both kinds of invite, so it reaches as far as
    -- whichever of the two goes furthest.
    local radius = Config.Duo.inviteRadius
    if Config.Crew.enabled then radius = math.max(radius, Config.Crew.inviteRadius) end

    local out = {}

    for _, other in ipairs(GetPlayers()) do
        other = tonumber(other)

        if other ~= src then
            local otherPed = GetPlayerPed(other)
            if otherPed and otherPed ~= 0 and #(GetEntityCoords(otherPed) - origin) <= radius then
                out[#out + 1] = { src = other, name = Framework.GetName(other) }
            end
        end
    end

    return out
end)

lib.callback.register('XS-Boosting:invite', function(src, targetSrc)
    targetSrc = tonumber(targetSrc)
    if not targetSrc then return false, 'Bad request.' end
    return Crew.Invite(src, targetSrc)
end)

lib.callback.register('XS-Boosting:inviteRespond', function(src, jobId, accepted)
    if type(jobId) ~= 'string' then return false end
    if accepted then return Crew.Accept(src, jobId) end
    return Crew.Decline(src, jobId)
end)

-- The standing crew: no job involved, so no job id to answer about.
lib.callback.register('XS-Boosting:crewRespond', function(src, accepted)
    if accepted then return Crew.Take(src) end
    return Crew.Refuse(src)
end)

lib.callback.register('XS-Boosting:crew', function(src)
    return Crew.State(src)
end)

lib.callback.register('XS-Boosting:crewLeave', function(src)
    return Crew.Quit(src)
end)

lib.callback.register('XS-Boosting:setSetting', function(src, key, value)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    local ok, reason, settings = Players.SetSetting(citizenid, key, value)
    if ok then TriggerClientEvent('XS-Boosting:client:settings', src, settings) end

    return ok, reason, settings
end)

-- Places this character has already stood at. Without this the blips they
-- earned last session stay hidden until they walk past them all over again.
lib.callback.register('XS-Boosting:discovered', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return {} end
    return Store.DiscoveredBy(citizenid)
end)

lib.callback.register('XS-Boosting:settings', function(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end
    return Players.Settings(citizenid)
end)

lib.callback.register('XS-Boosting:setAvatar', function(src, avatar)
    if type(avatar) ~= 'string' then return false, 'Bad request.' end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    return Players.SetAvatar(citizenid, avatar)
end)

lib.callback.register('XS-Boosting:setTagline', function(src, tagline)
    if type(tagline) ~= 'string' then return false, 'Bad request.' end

    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false, 'No character loaded.' end

    return Players.SetTagline(citizenid, tagline)
end)

lib.callback.register('XS-Boosting:heistStart', function(src)
    return Heist.Start(src)
end)

lib.callback.register('XS-Boosting:heistBegin', function(src)
    local job = jobOf(src)
    if not job or not job.heist then return false, 'Nothing to start.' end
    if job.holder ~= src then return false, 'Only the person who called it can start it.' end
    return Heist.Begin(job)
end)

-- The theft chain. Each step checks the one before it, so a client cannot
-- report a started engine on a car it never opened.

RegisterNetEvent('XS-Boosting:server:entered', function(method)
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if job.driving then return end
    if job.stage ~= 'search' then return end
    if not nearEntity(src, job.entity, 6.0) then return end

    if job.sting then
        job.stage = 'sting'
        Jobs.PushState(job)
        Jobs.Alert(job, 'theft')

        if Config.Sting.disableVehicle and job.entity and DoesEntityExist(job.entity) then
            Entity(job.entity).state:set('xsBoostDisabled', true, true)
        end

        if Config.Sting.repPenalty > 0 then
            Players.AddRep(job.citizenid, -Config.Sting.repPenalty)
        end

        Jobs.Fail(job, 'It was a setup.')
        return
    end

    if method == 'smash' and Config.Theft.entry.methods.smash.enabled then
        Jobs.Penalise(job, Config.Theft.entry.methods.smash.conditionCost)
        if job.fitted.alarm then job.alarmSounding = true end
    end

    Jobs.Stage(job, 'entry')
end)

RegisterNetEvent('XS-Boosting:server:alarm', function(sounding)
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if not job.fitted.alarm then return end

    job.alarmSounding = sounding and true or false

    if not job.alarmSounding then
        job.alarmSilencedAt = os.time()
        return
    end

    job.alarmStartedAt = os.time()

    local grace = Config.Theft.alarm.graceSeconds + Unlocks.BuffFor(job.citizenid, 'alarm_grace')

    SetTimeout(grace * 1000, function()
        if job.finished or not job.alarmSounding then return end
        Jobs.Alert(job, 'alarm')
    end)
end)

RegisterNetEvent('XS-Boosting:server:started', function()
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if job.stage ~= 'entry' then return end
    if not nearEntity(src, job.entity, 8.0) then return end

    Jobs.Stage(job, 'transit')

    if Config.Vehicles.giveKeys and job.netId then
        for _, member in ipairs(Jobs.Members(job)) do
            Keys.Give(member, job.netId, job.plate)
        end
    end

    local delay = Config.Police.alerts.theft.delaySeconds or 0
    if delay > 0 then
        SetTimeout(delay * 1000, function()
            if not job.finished then Jobs.Alert(job, 'theft') end
        end)
    else
        Jobs.Alert(job, 'theft')
    end

    if job.fitted.tracker and job.tracker.alive then
        local grace = Config.Theft.tracker.graceSeconds
            + Unlocks.BuffFor(job.citizenid, 'tracker_grace')

        SetTimeout(grace * 1000, function()
            if job.finished or not job.tracker.alive then return end
            Jobs.StartTracker(job)
        end)
    end
end)

RegisterNetEvent('XS-Boosting:server:killTracker', function(atDeadZone)
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if not job.fitted.tracker or not job.tracker.alive then return end

    if not Crew.Has(job, src) then return end

    -- The car itself only has to be within reach when the tracker is pulled at
    -- the car. A partner working it remotely, or anyone at a dead zone, does
    -- not need to be standing next to it.
    if atDeadZone then
        local zone = Store.Nearest('deadzone', GetEntityCoords(GetPlayerPed(src)))
        if not zone or not Config.Theft.tracker.deadZonesAllowed then return end
        if not nearCoords(src, zone.coords, zone.radius) then return end
    else
        -- Remote work is a crew perk, and the one person who cannot do it is
        -- whoever is behind the wheel of the car in question.
        local crewed = Crew.Size(job) > 1
        local driving = false

        if job.entity and DoesEntityExist(job.entity) then
            local ped = GetPlayerPed(src)
            driving = ped ~= 0 and GetPedInVehicleSeat(job.entity, -1) == ped
        end

        local remote = Config.Duo.remoteTracker and crewed and not driving
        if not remote and not nearEntity(src, job.entity, 8.0) then return end
    end

    Jobs.KillTracker(job)
    Jobs.Notify(job, 'Tracker is dead.', 'success')
end)

RegisterNetEvent('XS-Boosting:server:rollover', function()
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if not nearEntity(src, job.entity, 12.0) then return end

    Jobs.Penalise(job, Config.Condition.rolloverCost)
end)

RegisterNetEvent('XS-Boosting:server:partTaken', function(partId)
    local src = source
    local job = jobOf(src)
    if not job or job.heist then return end
    if type(partId) ~= 'string' then return end
    if not nearEntity(src, job.entity, 8.0) then return end

    for _, taken in ipairs(job.parts) do
        if taken == partId then return end
    end

    local part
    for _, entry in ipairs(Config.Chop.parts) do
        if entry.id == partId then part = entry break end
    end

    if not part then return end

    job.parts[#job.parts + 1] = partId
    Jobs.Penalise(job, Config.Chop.conditionCostPerPart)

    Inv.Add(src, part.item, 1)
    Inv.Damage(src, Config.Chop.tool.item, Config.Chop.tool.durability)

    if #job.parts == 1 then Jobs.Alert(job, 'chop') end

    Jobs.PushState(job)
end)

lib.callback.register('XS-Boosting:eventJoin', function(src)
    return Event.Join(src)
end)

lib.callback.register('XS-Boosting:eventDeliver', function(src)
    return Event.Deliver(src)
end)

lib.callback.register('XS-Boosting:event', function(src)
    return Event.Describe(Event.Active())
end)

lib.callback.register('XS-Boosting:stored', function(src, locationId)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return {} end

    if locationId then return Storage.AtLockup(citizenid, tonumber(locationId) or 0) end
    return Storage.List(citizenid)
end)

lib.callback.register('XS-Boosting:stash', function(src)
    local job = jobOf(src)
    if not job then return false, 'Nothing to park.' end
    if job.holder ~= src then return false, 'Only the person holding it can park it.' end

    local place = Store.Nearest('lockup', GetEntityCoords(GetPlayerPed(src)))
    if not place or not nearCoords(src, place.coords, place.radius) then
        return false, 'You are not at a lockup.'
    end

    if not nearEntity(src, job.entity, 25.0) then return false, 'The car is not here.' end

    return Storage.Stash(src, job, place)
end)

lib.callback.register('XS-Boosting:retrieve', function(src, storedId)
    local place = Store.Nearest('lockup', GetEntityCoords(GetPlayerPed(src)))
    if not place or not nearCoords(src, place.coords, place.radius) then
        return false, 'You are not at a lockup.'
    end

    return Storage.Retrieve(src, storedId)
end)

lib.callback.register('XS-Boosting:keep', function(src)
    local job = jobOf(src)
    if not job then return false, 'Nothing to keep.' end
    if job.holder ~= src then return false, 'Only the person holding it can do that.' end

    local place = Store.Nearest('lockup', GetEntityCoords(GetPlayerPed(src)))
    if not place or not nearCoords(src, place.coords, place.radius) then
        return false, 'You are not at a lockup.'
    end

    if not nearEntity(src, job.entity, 25.0) then return false, 'The car is not here.' end

    return Storage.Keep(src, job)
end)

lib.callback.register('XS-Boosting:deliver', function(src, route)
    local job = jobOf(src)
    if not job or job.heist then return false, 'Nothing to hand over.' end
    if job.stage ~= 'transit' then return false, 'Start it first.' end
    if not Crew.Has(job, src) then return false, 'Not your job.' end

    route = (route == 'chop' or route == 'fence' or route == 'buyer') and route or 'buyer'

    if route == 'buyer' then
        if not Config.Disposal.buyer.enabled then return false, 'That route is closed.' end
        if not nearCoords(src, job.buyer.coords, Config.Disposal.buyer.radius) then
            return false, 'Not close enough to the handover.'
        end
    else
        local kind = route == 'chop' and 'chop' or 'fence'
        local enabled = route == 'chop' and Config.Disposal.chopShop.enabled or Config.Disposal.fence.enabled
        if not enabled then return false, 'That route is closed.' end

        local place = Store.Nearest(kind, GetEntityCoords(GetPlayerPed(src)))
        if not place or not nearCoords(src, place.coords, place.radius) then
            return false, 'You are not at one.'
        end
    end

    if not nearEntity(src, job.entity, 25.0) then
        return false, 'The car is not here.'
    end

    local condition = Jobs.ReadCondition(job)

    if route == 'buyer' and condition < Config.Condition.refuseBelow then
        return false, 'They will not take it in that state.'
    end

    local specMatched = true
    if job.contract.type == 'spec' then
        specMatched = condition >= (job.contract.minCondition or 0)
    end

    local extra = 0
    if job.contract.type == 'chop' then
        extra = Payout.Parts(src, job.parts)
    end

    local amount = Jobs.Complete(job, route, { specMatched = specMatched, extra = extra })
    return true, nil, amount, specMatched
end)

lib.callback.register('XS-Boosting:heistDeliver', function(src)
    local job = jobOf(src)
    if not job or not job.heist then return false end
    if job.stage ~= 'running' then return false end
    if not Crew.Has(job, src) then return false end

    local ped = GetPlayerPed(src)
    local vehicle = GetVehiclePedIsIn(ped)
    if not vehicle or vehicle == 0 then return false, 'You are not in one of them.' end

    local tag = Entity(vehicle).state.xsBoostHeist
    if not tag or tag.job ~= job.id then return false, 'That is not one of the cars.' end

    if not nearCoords(src, job.exit.coords, Config.Heist.exitRadius) then
        return false, 'Not at the exit.'
    end

    local body = 1000.0
    pcall(function() body = GetVehicleBodyHealth(vehicle) or 1000.0 end)

    local ok, amount = Heist.Deliver(job, tag.index, math.floor((body / 1000) * 100))
    if not ok then return false, 'Already counted.' end

    if DoesEntityExist(vehicle) then DeleteEntity(vehicle) end

    return true, nil, amount
end)
