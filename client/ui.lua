UI = {}

local open = false

-- Always sent, open or not: the HUD is drawn by this same page while the unit
-- is shut, so gating messages on `open` would freeze it.
function UI.Send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- A job alert, shown on the HUD rather than as a notification. Silent if the
-- player has turned alerts off.
function UI.Alert(title, text, kind)
    if Boost.settings.alerts == false then return end
    UI.Send('alert', { title = title, text = text, kind = kind or 'info' })
end

function UI.IsOpen()
    return open
end

function UI.Open(force)
    if open then return end

    local payload = lib.callback.await('XS-Boosting:bootstrap', false, force)
    if not payload then
        Boost.Notify('The unit will not turn on. Are you still holding it?', 'error')
        return
    end

    Boost.rep = payload.stats and payload.stats.rep or 0
    Boost.market = payload.market or {}
    Boost.locations = payload.locations or Boost.locations
    Boost.job = payload.job or Boost.job

    -- Only this client knows which player it is, so whether the crew is
    -- yours to run is worked out here rather than sent.
    if payload.crew then
        local me = GetPlayerServerId(PlayerId())
        payload.crew.me = me
        payload.crew.isLeader = payload.crew.leader == me
    end

    Boost.crew = payload.crew

    open = true
    Sound.Play('open')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'open', data = payload })

    Markers.Rebuild()
    Contract.BindPlaces()
end

function UI.Close()
    if not open then return end

    open = false
    Sound.Play('close')
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local pending

-- The builtin minigames are drawn by the same page as the unit, shown as an
-- overlay. Focus is taken without a cursor so they stay keyboard-driven and
-- work whether the unit itself is open or not.
function UI.Minigame(stage, difficulty)
    if pending then return false end

    pending = promise.new()
    SetNuiFocus(true, false)
    SendNUIMessage({ action = 'minigame', data = { stage = stage, difficulty = difficulty } })

    local result = Citizen.Await(pending)
    pending = nil

    SetNuiFocus(open, open)
    return result == true
end

RegisterNUICallback('minigameResult', function(data, cb)
    if pending then pending:resolve(data and data.success == true) end
    cb(true)
end)

-- The handshake needs a cursor, unlike the keyboard minigames, so it takes
-- full focus. You are standing still for it either way.
function UI.Hack(difficulty)
    if pending then return false end

    pending = promise.new()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'hack', data = { difficulty = difficulty } })

    local result = Citizen.Await(pending)
    pending = nil

    SetNuiFocus(open, open)
    return result == true
end

RegisterNUICallback('hackResult', function(data, cb)
    if pending then pending:resolve(data and data.success == true) end
    cb(true)
end)

-- ox_inventory calls this when the item is used, if its items.lua entry
-- points here. Nothing else in the resource opens the unit.
exports('openUnit', function()
    UI.Open()
end)

RegisterNUICallback('close', function(_, cb)
    UI.Close()
    cb(true)
end)

RegisterNUICallback('board', function(_, cb)
    cb(lib.callback.await('XS-Boosting:board', false))
end)

RegisterNUICallback('stats', function(_, cb)
    cb(lib.callback.await('XS-Boosting:stats', false))
end)

RegisterNUICallback('leaderboard', function(_, cb)
    cb(lib.callback.await('XS-Boosting:leaderboard', false))
end)

RegisterNUICallback('setSetting', function(data, cb)
    local ok, reason, settings = lib.callback.await('XS-Boosting:setSetting', false, data.key, data.value)
    if ok and settings then Boost.settings = settings end
    cb({ ok = ok, reason = reason })
end)

RegisterNUICallback('setAvatar', function(data, cb)
    local ok, reason, avatar = lib.callback.await('XS-Boosting:setAvatar', false, data.avatar)
    cb({ ok = ok, reason = reason, avatar = avatar })
end)

RegisterNUICallback('setTagline', function(data, cb)
    local ok, reason, tagline = lib.callback.await('XS-Boosting:setTagline', false, data.tagline)
    cb({ ok = ok, reason = reason, tagline = tagline })
end)

RegisterNUICallback('setHandle', function(data, cb)
    local ok, reason, handle = lib.callback.await('XS-Boosting:setHandle', false, data.handle)
    if not ok then Boost.Notify(reason or 'That name will not do.', 'error') end
    cb({ ok = ok, reason = reason, handle = handle })
end)

RegisterNUICallback('accept', function(data, cb)
    local ok, reason, state = lib.callback.await('XS-Boosting:accept', false, data.id)

    if not ok then
        Boost.Notify(reason or 'That did not work.', 'error')
        cb({ ok = false, reason = reason })
        return
    end

    UI.Close()
    Sound.Play('accept')
    Boost.Notify('Contract taken. Go and find it.', 'success')
    cb({ ok = true, job = state })
end)

RegisterNUICallback('abandon', function(_, cb)
    local ok = lib.callback.await('XS-Boosting:abandon', false)
    cb({ ok = ok })
end)

RegisterNUICallback('nearby', function(_, cb)
    cb(lib.callback.await('XS-Boosting:nearby', false))
end)

RegisterNUICallback('invite', function(data, cb)
    local ok, reason = lib.callback.await('XS-Boosting:invite', false, data.src)
    if not ok then Boost.Notify(reason or 'They did not get it.', 'error') end
    cb({ ok = ok, reason = reason })
end)

RegisterNUICallback('crewLeave', function(_, cb)
    local ok, reason = lib.callback.await('XS-Boosting:crewLeave', false)
    if not ok and reason then Boost.Notify(reason, 'error') end
    cb({ ok = ok, reason = reason })
end)

RegisterNUICallback('heistStart', function(_, cb)
    local ok, reason, state = lib.callback.await('XS-Boosting:heistStart', false)

    if not ok then
        Boost.Notify(reason or 'Not right now.', 'error')
        cb({ ok = false, reason = reason })
        return
    end

    Boost.Notify('Get your crew together.', 'success')
    cb({ ok = true, job = state })
end)

