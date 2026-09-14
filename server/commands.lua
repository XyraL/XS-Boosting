-- The builder is the only command in the resource. Players get nothing
-- registered at all; the unit item is their whole interface.
RegisterCommand(Config.Builder.command, function(source)
    if source == 0 then
        print('^1[XS-Boosting]^0 that command only works in game.')
        return
    end

    if not Framework.IsAdmin(source) then
        Framework.Notify(source, 'You are not allowed to do that.', 'error')
        return
    end

    TriggerClientEvent('XS-Boosting:client:openBuilder', source)
end, false)

-- The unit is an item and there is no command to open it, which is the whole
-- point. This hands one over so an admin can test, or hand one out.
RegisterCommand('boostunit', function(source, args)
    if source == 0 then
        print('^1[XS-Boosting]^0 that command only works in game.')
        return
    end

    if not Framework.IsAdmin(source) then
        Framework.Notify(source, 'You are not allowed to do that.', 'error')
        return
    end

    local target = tonumber(args[1]) or source
    local item = Config.Access.item

    if not Inv.Exists(item) then
        Framework.Notify(source, ('"%s" is not an item on this server yet. Add it to your inventory first.'):format(item), 'error')
        return
    end

    if Inv.Add(target, item, 1) then
        Framework.Notify(source, target == source and 'Have a unit. Use it from your inventory.' or 'Sent them one.', 'success')
        if target ~= source then
            Framework.Notify(target, 'Somebody put a unit in your pocket.', 'inform')
        end
    else
        Framework.Notify(source, 'Could not hand it over. No room?', 'error')
    end
end, false)

-- For testing while the item is being wired up. Opens the unit regardless of
-- whether one is in the player's pocket.
RegisterCommand('boostopen', function(source)
    if source == 0 then
        print('^1[XS-Boosting]^0 that command only works in game.')
        return
    end

    if not Framework.IsAdmin(source) then
        Framework.Notify(source, 'You are not allowed to do that.', 'error')
        return
    end

    TriggerClientEvent('XS-Boosting:client:open', source, true)
end, false)

-- What is placed, and how much of it is switched on. `/boostplaces on` puts
-- everything back on in one go — worth having, because a place that was saved
-- while it read as disabled stays disabled in the table. Runs from the server
-- console too, so it works when nobody is on.
RegisterCommand('boostplaces', function(source, args)
    if source ~= 0 and not Framework.IsAdmin(source) then
        Framework.Notify(source, 'You are not allowed to do that.', 'error')
        return
    end

    local function say(message)
        if source == 0 then
            print(('^2[XS-Boosting]^0 %s'):format(message))
        else
            Framework.Notify(source, message, 'inform')
        end
    end

    local off = 0
    for _, entry in ipairs(Store.All()) do
        if not entry.enabled then off = off + 1 end
    end

    if args[1] == 'on' then
        if off == 0 then
            say('They are all on already.')
            return
        end

        MySQL.query.await('UPDATE xs_boosting_locations SET enabled = 1 WHERE enabled = 0')
        Store.Load()
        Store.Push()
        Contracts.Refresh()

        say(('Turned %d place%s back on.'):format(off, off == 1 and '' or 's'))
        return
    end

    local counts, kinds = {}, {}

    for _, entry in ipairs(Store.All()) do
        if not counts[entry.kind] then
            counts[entry.kind] = { on = 0, off = 0 }
            kinds[#kinds + 1] = entry.kind
        end

        local bucket = counts[entry.kind]
        if entry.enabled then bucket.on = bucket.on + 1 else bucket.off = bucket.off + 1 end
    end

    table.sort(kinds)

    if #kinds == 0 then
        say('Nothing is placed yet. Run /' .. Config.Builder.command .. '.')
        return
    end

    for _, kind in ipairs(kinds) do
        local bucket = counts[kind]
        say(('%s — %d on, %d off'):format(kind, bucket.on, bucket.off))
    end

    if off > 0 then
        say('Run /boostplaces on to switch the rest back on.')
    end
end, false)

RegisterCommand('boostevent', function(source, args)
    if source == 0 then
        print('^1[XS-Boosting]^0 that command only works in game.')
        return
    end

    if not Framework.IsAdmin(source) then
        Framework.Notify(source, 'You are not allowed to do that.', 'error')
        return
    end

    if args[1] == 'stop' then
        if not Event.Active() then
            Framework.Notify(source, 'Nothing is running.', 'inform')
            return
        end

        Event.Finish('An admin called it off.')
        Framework.Notify(source, 'Called it off.', 'success')
        return
    end

    local ok, reason = Event.Start()
    Framework.Notify(source, ok and 'It is up.' or (reason or 'Could not start one.'), ok and 'success' or 'error')
end, false)

exports('GetRep', function(src)
    local record = Players.Of(src)
    return record and record.rep or 0
end)

exports('AddRep', function(src, amount)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return false end
    Players.AddRep(citizenid, tonumber(amount) or 0)
    return true
end)

exports('IsBoosting', function(src)
    return Jobs.Get(src) ~= nil
end)

-- Call this from your police resource when somebody is booked, so a contract
-- taken and then lost to a cell costs what it should. See the README.
exports('OnArrested', function(src)
    local job = Jobs.Get(src)
    if not job then return false end

    if Config.Rep.arrestPenalty > 0 then
        Players.AddRep(job.citizenid, -Config.Rep.arrestPenalty)
    end

    if job.heist then
        Heist.Fail(job, 'The crew got picked up.')
    else
        Jobs.Fail(job, 'You got picked up.')
    end

    return true
end)
