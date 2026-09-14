CrewClient = {}

local pendingInvite

-- Who you are crewed up with right now, job or no job. Pushed from the server
-- whenever it changes, and nil once the crew breaks up.
RegisterNetEvent('XS-Boosting:client:crew', function(state)
    if state then
        local me = GetPlayerServerId(PlayerId())
        state.isLeader = state.leader == me
        state.me = me
    end

    Boost.crew = state
    UI.Send('crew', state)
end)

local function askCrew(invite)
    local body = ('**%s** wants you in their crew. Nothing is running yet — whoever takes a contract first takes the rest of you with them.')
        :format(invite.from)

    local answer = lib.alertDialog({
        header = 'Crew Up',
        content = body,
        centered = true,
        cancel = true,
        labels = { confirm = 'I am in', cancel = 'Not now' },
    })

    local accepted = answer == 'confirm'
    local ok, reason = lib.callback.await('XS-Boosting:crewRespond', false, accepted)

    if not accepted then return end

    if ok then
        Sound.Play('accept')
        Boost.Notify('Crewed up.', 'success')
    else
        Boost.Notify(reason or 'That did not work.', 'error')
    end
end

local function askJob(invite)
    pendingInvite = invite.jobId

    local body = invite.heist
        and ('**%s** wants you on a job. Four of you, several cars, one window.'):format(invite.from)
        or ('**%s** is going after a %s and wants a second pair of hands.'):format(invite.from, invite.label)

    local answer = lib.alertDialog({
        header = invite.heist and 'Crew Up' or 'Ride Along',
        content = body,
        centered = true,
        cancel = true,
        labels = { confirm = 'I am in', cancel = 'Not now' },
    })

    if pendingInvite ~= invite.jobId then return end
    pendingInvite = nil

    local accepted = answer == 'confirm'
    local ok, reason = lib.callback.await('XS-Boosting:inviteRespond', false, invite.jobId, accepted)

    if not accepted then return end

    if ok then
        Boost.Notify('You are on it.', 'success')
    else
        Boost.Notify(reason or 'That did not work.', 'error')
    end
end

-- One event, two kinds of ask: into a crew that has nothing running, or
-- straight into somebody's live contract.
RegisterNetEvent('XS-Boosting:client:invite', function(invite)
    if not invite then return end

    if invite.crew then
        askCrew(invite)
        return
    end

    if not invite.jobId then return end
    askJob(invite)
end)
