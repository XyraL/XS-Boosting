Tracker = {}

function Tracker.Kill(atDeadZone)
    local job = Boost.job
    if not job or not job.fitted or not job.fitted.tracker then return end
    if not job.tracker or not job.tracker.alive then return end

    local settings = Config.Theft.tracker

    if settings.item and settings.item ~= '' then
        local has = lib.callback.await('XS-Boosting:hasItem', false, settings.item)
        if not has then
            Boost.Notify('You need something to talk to the ECU with.', 'error')
            return
        end
    end

    Contract.SetBusy(true)

    local started = lib.progressBar({
        duration = settings.seconds * 1000,
        label = atDeadZone and 'Wiping the unit' or 'Cutting the tracker',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })

    if not started then
        Contract.SetBusy(false)
        return
    end

    local won = UI.Hack(Tiers.Difficulty(job.tier, 'ecu'))
    Sound.Play(won and 'hackWin' or 'hackFail')

    if won then
        TriggerServerEvent('XS-Boosting:server:killTracker', atDeadZone and true or false)
        TriggerServerEvent('XS-Boosting:server:toolUsed', 'tracker')
        UI.Alert('Tracker dead', 'They have lost your position.', 'good')
    else
        Boost.Notify('It rejected you.', 'error')
        UI.Alert('Handshake failed', 'The ECU rejected you. Try again.', 'warn')
    end

    Contract.SetBusy(false)
end

-- A passenger can work the tracker while somebody else drives. That is the
-- one thing a second person buys you that a second person cannot otherwise do.
function Tracker.Remote()
    local job = Boost.job
    if not job then return end

    if not Config.Duo.remoteTracker then
        Boost.Notify('That has to be done at the car.', 'error')
        return
    end

    Tracker.Kill(false)
end

RegisterNUICallback('killTracker', function(data, cb)
    local remote = data and data.remote

    CreateThread(function()
        if remote then Tracker.Remote() else Tracker.Kill(false) end
    end)

    cb(true)
end)
