Boost = {
    job = nil,
    locations = {},
    market = {},
    rep = 0,
    open = false,
    builder = false,
    settings = {},
    event = nil,
    eventJoined = false,
    crew = nil,
}

function Boost.Notify(message, kind)
    if Boost.settings.notify == false then return end
    Framework.Notify(message, kind)
end

RegisterNetEvent('XS-Boosting:client:settings', function(settings)
    Boost.settings = settings or {}
    UI.Send('settings', Boost.settings)
end)

-- Pulled once when the character is ready, so the HUD and its side are right
-- before the first contract rather than after the unit is first opened.
CreateThread(function()
    while not Framework.name do Wait(250) end
    Wait(2000)

    local settings = lib.callback.await('XS-Boosting:settings', false)
    if settings then
        Boost.settings = settings
        UI.Send('settings', settings)
    end

    -- Everywhere this character already knows about, so their blips come back
    -- instead of having to be re-found every session.
    local found = lib.callback.await('XS-Boosting:discovered', false)
    if found and #found > 0 then
        TriggerEvent('XS-Boosting:client:discovered', found)
    end
end)

function Boost.HasJob()
    return Boost.job ~= nil and not Boost.job.ended
end

function Boost.Vehicle()
    if not Boost.job or not Boost.job.netId then return nil end
    if not NetworkDoesNetworkIdExist(Boost.job.netId) then return nil end

    local entity = NetworkGetEntityFromNetworkId(Boost.job.netId)
    if not DoesEntityExist(entity) then return nil end

    return entity
end

RegisterNetEvent('XS-Boosting:client:locations', function(locations)
    Boost.locations = locations or {}
    Markers.Rebuild()
    Contract.BindPlaces()
end)

RegisterNetEvent('XS-Boosting:client:market', function(market)
    Boost.market = market or {}
    UI.Send('market', market)
end)

RegisterNetEvent('XS-Boosting:client:board', function(board)
    UI.Send('board', board)
end)

RegisterNetEvent('XS-Boosting:client:rep', function(rep, change)
    Boost.rep = rep

    if change and change ~= 0 then
        Boost.Notify(('%s%d rep'):format(change > 0 and '+' or '', change), change > 0 and 'success' or 'error')
    end

    UI.Send('rep', { rep = rep, change = change })
end)

-- A job alert for the HUD: { title, text, kind }. Deliberately NOT the same
-- event as the police dispatch alert in bridge/dispatch.lua, which carries
-- coords and a code and is read by a completely different handler.
RegisterNetEvent('XS-Boosting:client:jobAlert', function(alert)
    if not alert then return end

    UI.Alert(alert.title, alert.text, alert.kind)

    if alert.kind == 'bad' then
        Sound.Play(alert.sound or 'tracker')
    elseif alert.kind == 'warn' then
        Sound.Play(alert.sound or 'police')
    end
end)

RegisterNetEvent('XS-Boosting:client:unlocked', function(unlock)
    if not unlock then return end

    Sound.Play('unlock')
    Boost.Notify(('Unlocked: %s — %s'):format(unlock.label, unlock.effect or ''), 'success')
    UI.Send('unlocked', unlock)
end)

RegisterNetEvent('XS-Boosting:client:job', function(state)
    local previous = Boost.job

    -- Whether you are the one holding the contract decides what the unit
    -- offers you, and only the client knows which player it is.
    if state then
        state.isHolder = state.holderId == nil or state.holderId == GetPlayerServerId(PlayerId())
    end

    Boost.job = state

    Markers.Job(state)
    Contract.Sync(state)
    Telemetry.Sync(state)
    UI.Send('job', state)

    if state and (not previous or previous.stage ~= state.stage) then
        Contract.OnStage(state.stage)
    end
end)

RegisterNetEvent('XS-Boosting:client:jobEnded', function(outcome, reason, amount)
    local ended = Boost.job
    Boost.job = nil

    Markers.Job(nil)
    Contract.Sync(nil)
    Telemetry.Stop()
    Theft.Reset()

    Sound.ResetClock()

    if outcome == 'stashed' then
        Sound.Play('stage')
    else
        Sound.Play(outcome == 'failed' and 'lost' or 'paid')
    end

    UI.Send('jobEnded', { outcome = outcome, reason = reason, amount = amount })

    if outcome == 'failed' and reason then
        Boost.Notify(reason, 'error')
    elseif amount and amount > 0 then
        Boost.Notify(('Paid out $%s.'):format(amount), 'success')
    end

    if ended and ended.netId then
        Contract.ClearVehicle(ended.netId)
    end
end)

-- The unit is checked on the server before this ever fires, so reaching here
-- means the player is holding one.
RegisterNetEvent('XS-Boosting:client:open', function(force)
    UI.Open(force)
end)

-- Cosmetics for a spawned target car are applied by whichever client owns the
-- entity. The state bag is watched rather than handed to one player, so a car
-- that changes owner mid-job still ends up looking right.
AddStateBagChangeHandler('xsBoostSetup', nil, function(bagName, _, value)
    if not value then return end

    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end

    CreateThread(function()
        local waited = 0
        while not NetworkHasControlOfEntity(entity) and waited < 3000 do
            NetworkRequestControlOfEntity(entity)
            Wait(100)
            waited = waited + 100
        end

        if not DoesEntityExist(entity) then return end

        if value.plate then SetVehicleNumberPlateText(entity, value.plate) end
        if value.colour then SetVehicleColours(entity, value.colour, value.colour) end
        if value.dirt then SetVehicleDirtLevel(entity, value.dirt + 0.0) end
        if value.fuel then Fuel.Set(entity, value.fuel + 0.0) end

        if value.damage and value.damage > 0 then
            local left = math.max(150.0, 1000.0 - (value.damage * 10.0))
            SetVehicleBodyHealth(entity, left)
            SetVehicleEngineHealth(entity, left)
        end

        -- Whatever Z the point was saved at, the car sits flat on the road.
        -- Done twice with a beat between: the first call can land before the
        -- collision around it has finished streaming, and then does nothing.
        SetVehicleOnGroundProperly(entity)
        SetEntityRotation(entity, 0.0, 0.0, GetEntityHeading(entity), 2, true)
        Wait(250)

        if DoesEntityExist(entity) then
            SetVehicleOnGroundProperly(entity)
        end

        if value.started then
            -- Came back out of a lockup: already yours, already running.
            SetVehicleDoorsLocked(entity, 1)
            SetVehicleNeedsToBeHotwired(entity, false)
            SetVehicleEngineOn(entity, true, true, false)
        else
            SetVehicleDoorsLocked(entity, 2)
            SetVehicleNeedsToBeHotwired(entity, true)
            SetVehicleEngineOn(entity, false, true, true)
        end
    end)
end)

AddStateBagChangeHandler('xsBoostDisabled', nil, function(bagName, _, value)
    if not value then return end

    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end

    CreateThread(function()
        NetworkRequestControlOfEntity(entity)
        Wait(200)
        if not DoesEntityExist(entity) then return end

        SetVehicleUndriveable(entity, true)
        SetVehicleEngineHealth(entity, 0.0)
        SetVehicleDoorsLocked(entity, 4)
    end)
end)

AddStateBagChangeHandler('xsBoostBurn', nil, function(bagName, _, value)
    if not value then return end

    local entity = GetEntityFromStateBagName(bagName)
    if not entity or entity == 0 then return end

    CreateThread(function()
        NetworkRequestControlOfEntity(entity)
        Wait(200)
        if not DoesEntityExist(entity) then return end

        SetVehicleEngineHealth(entity, 0.0)
        SetVehiclePetrolTankHealth(entity, 0.0)
        NetworkExplodeVehicle(entity, true, false, false)
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetNuiFocus(false, false)
    Markers.Clear()
    Target.RemoveAll()
end)

CreateThread(function()
    while true do
        Wait(2000)

        if Boost.HasJob() then
            local vehicle = Boost.Vehicle()

            if vehicle and IsEntityInAir(vehicle) == false then
                local roll = math.abs(GetEntityRoll(vehicle))
                if roll > 75.0 and not Boost.rolled then
                    Boost.rolled = true
                    TriggerServerEvent('XS-Boosting:server:rollover')
                elseif roll < 40.0 then
                    Boost.rolled = false
                end
            end
        end
    end
end)
