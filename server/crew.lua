-- Crew.
--
-- Two separate things share this file, and it is worth keeping them apart in
-- your head:
--
--   the standing crew   people you have grouped up with, job or no job. It
--                       outlives contracts. When one of you takes something
--                       on, the rest are pulled into it.
--
--   job.crew            who is actually on a live contract right now. A duo
--                       is two, a heist is up to four.
--
-- The unit shows one button for both. Whether asking somebody adds them to
-- your standing crew or drops them straight into a running job depends on
-- whether you have a job — the player never picks.

Crew = {}

local invites = {}      -- job invites,      keyed "src:jobId"
local asks = {}         -- standing invites, keyed src
local crews = {}        -- [leader src] = { leader = src, members = { src, ... } }
local memberOf = {}     -- [src] = leader src

local function key(src, jobId)
    return ('%s:%s'):format(src, jobId)
end

-- A heist does not use the same state shape as a contract, so pushing the
-- wrong one strips the cars and the exit out of the page.
local function push(job)
    if job.heist then
        Heist.Push(job)
    else
        Jobs.PushState(job)
    end
end

-- ── The live job ─────────────────────────────────────────────────────────────

function Crew.Citizens(job)
    local out = {}

    for _, src in ipairs(job.crew or {}) do
        local citizenid = Framework.GetCitizenId(src)
        if citizenid then out[#out + 1] = citizenid end
    end

    return out
end

function Crew.Describe(job)
    local out = {
        { src = job.holder, name = Framework.GetName(job.holder), role = 'holder' },
    }

    for _, src in ipairs(job.crew or {}) do
        out[#out + 1] = { src = src, name = Framework.GetName(src), role = 'crew' }
    end

    return out
end

function Crew.Size(job)
    return 1 + #(job.crew or {})
end

function Crew.Has(job, src)
    if job.holder == src then return true end

    for _, member in ipairs(job.crew or {}) do
        if member == src then return true end
    end

    return false
end

function Crew.MaxFor(job)
    if job.heist then return Config.Heist.crewSize.max end
    return Config.Duo.enabled and 2 or 1
end

function Crew.Join(job, src)
    job.crew[#job.crew + 1] = src
    Jobs.Bind(src, job.id)

    if not job.heist and Config.Duo.timeBonusSeconds ~= 0 then
        job.deadline = job.deadline + Config.Duo.timeBonusSeconds
    end

    Jobs.Notify(job, ('%s is in.'):format(Framework.GetName(src)), 'success')
    push(job)
end

function Crew.Leave(job, src)
    for index, member in ipairs(job.crew or {}) do
        if member == src then
            table.remove(job.crew, index)
            break
        end
    end

    Jobs.Unbind(src)
    TriggerClientEvent('XS-Boosting:client:jobEnded', src, 'left')

    if not job.finished then
        Jobs.Notify(job, ('%s dropped out.'):format(Framework.GetName(src)), 'inform')
        push(job)
    end
end

-- ── The standing crew ────────────────────────────────────────────────────────

function Crew.Of(src)
    local leader = memberOf[src]
    return leader and crews[leader] or nil
end

function Crew.Roster(src)
    local crew = Crew.Of(src)
    if not crew then return {} end

    local out = { crew.leader }
    for _, member in ipairs(crew.members) do out[#out + 1] = member end
    return out
end

function Crew.State(src)
    local crew = Crew.Of(src)
    if not crew then return nil end

    local members = {}

    for _, member in ipairs(Crew.Roster(src)) do
        local job = Jobs.Get(member)

        members[#members + 1] = {
            src    = member,
            name   = Framework.GetName(member),
            leader = member == crew.leader,
            busy   = job ~= nil and not job.finished,
        }
    end

    return {
        leader  = crew.leader,
        max     = Config.Crew.maxSize,
        members = members,
    }
end

function Crew.Push(crew)
    if not crew then return end

    for _, src in ipairs({ crew.leader, table.unpack(crew.members) }) do
        TriggerClientEvent('XS-Boosting:client:crew', src, Crew.State(src))
    end
end

local function disband(crew, reason)
    if not crew then return end

    local everyone = { crew.leader, table.unpack(crew.members) }

    crews[crew.leader] = nil
    for _, src in ipairs(everyone) do memberOf[src] = nil end

    for _, src in ipairs(everyone) do
        TriggerClientEvent('XS-Boosting:client:crew', src, nil)
        if reason then Framework.Notify(src, reason, 'inform') end
    end
end

-- Leaving does not end it for everybody else. The next person down takes it
-- over, and it only falls apart when there is nobody left to hand it to —
-- one person on their own is not a crew.
function Crew.Quit(src)
    local crew = Crew.Of(src)
    asks[src] = nil

    if not crew then return false, 'You are not in one.' end

    local wasLeader = crew.leader == src

    memberOf[src] = nil
    crews[crew.leader] = nil
    TriggerClientEvent('XS-Boosting:client:crew', src, nil)

    local left = {}
    for _, member in ipairs({ crew.leader, table.unpack(crew.members) }) do
        if member ~= src then left[#left + 1] = member end
    end

    if #left < 2 then
        for _, member in ipairs(left) do
            memberOf[member] = nil
            TriggerClientEvent('XS-Boosting:client:crew', member, nil)
            Framework.Notify(member, 'The crew broke up.', 'inform')
        end

        return true
    end

    crew.leader = left[1]
    crew.members = { table.unpack(left, 2) }
    crews[crew.leader] = crew

    for _, member in ipairs(left) do memberOf[member] = crew.leader end

    local note = wasLeader
        and ('%s left. %s runs the crew now.'):format(Framework.GetName(src), Framework.GetName(crew.leader))
        or ('%s left the crew.'):format(Framework.GetName(src))

    for _, member in ipairs(left) do Framework.Notify(member, note, 'inform') end

    Crew.Push(crew)
    return true
end

function Crew.Ask(src, targetSrc)
    if not Config.Crew.enabled then return false, 'Crews are switched off here.' end
    if src == targetSrc then return false, 'You are already with yourself.' end

    if not Players.HasUnit(src) then return false, 'You need a unit to do that.' end
    if not Players.HasUnit(targetSrc) then return false, 'They have no unit on them.' end

    local crew = Crew.Of(src)
    if crew and crew.leader ~= src then
        return false, 'Only whoever started the crew can bring people in.'
    end

    if crew and #Crew.Roster(src) >= Config.Crew.maxSize then
        return false, 'There is no room for anyone else.'
    end

    if Crew.Of(targetSrc) then return false, 'They are already with somebody.' end
    if Jobs.Get(targetSrc) then return false, 'They are busy with something else.' end

    local ask = asks[targetSrc]
    if ask and os.time() <= ask.expires then
        return false, 'Somebody has already asked them. Give it a moment.'
    end

    local ped = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)

    if not ped or not targetPed or ped == 0 or targetPed == 0 then
        return false, 'They are not here.'
    end

    if #(GetEntityCoords(ped) - GetEntityCoords(targetPed)) > Config.Crew.inviteRadius then
        return false, 'They need to be standing with you.'
    end

    asks[targetSrc] = { leader = src, expires = os.time() + Config.Crew.inviteTimeout }

    TriggerClientEvent('XS-Boosting:client:invite', targetSrc, {
        crew    = true,
        from    = Framework.GetName(src),
        size    = crew and #Crew.Roster(src) or 1,
        max     = Config.Crew.maxSize,
        seconds = Config.Crew.inviteTimeout,
    })

    return true
end

function Crew.Take(src)
    local ask = asks[src]
    asks[src] = nil

    if not ask then return false, 'That invite is gone.' end
    if os.time() > ask.expires then return false, 'That invite lapsed.' end

    local leader = ask.leader
    if Crew.Of(src) then return false, 'You are already with somebody.' end
    if Jobs.Get(src) then return false, 'You are already on something.' end
    if not Players.HasUnit(src) then return false, 'You need a unit of your own.' end

    local crew = Crew.Of(leader)

    if crew then
        if crew.leader ~= leader then return false, 'That crew moved on.' end
        if #Crew.Roster(leader) >= Config.Crew.maxSize then return false, 'They filled the spot.' end
    else
        if Jobs.Get(leader) then return false, 'They started without you.' end

        crew = { leader = leader, members = {} }
        crews[leader] = crew
        memberOf[leader] = leader
    end

    crew.members[#crew.members + 1] = src
    memberOf[src] = leader

    for _, member in ipairs({ crew.leader, table.unpack(crew.members) }) do
        if member ~= src then
            Framework.Notify(member, ('%s joined the crew.'):format(Framework.GetName(src)), 'success')
        end
    end

    Crew.Push(crew)
    return true
end

function Crew.Refuse(src)
    local ask = asks[src]
    asks[src] = nil

    if ask then
        Framework.Notify(ask.leader, ('%s turned it down.'):format(Framework.GetName(src)), 'inform')
    end

    return true
end

-- Somebody took a contract. Everyone standing with them comes along, without
-- another round of invites while the clock is already running.
function Crew.Pull(job)
    if not Config.Crew.enabled or not Config.Crew.autoJoin then return end

    local crew = Crew.Of(job.holder)
    if not crew then return end

    local max = Crew.MaxFor(job)
    if max <= 1 then return end

    local origin
    if Config.Crew.joinRadius > 0 then
        local ped = GetPlayerPed(job.holder)
        if ped and ped ~= 0 then origin = GetEntityCoords(ped) end
    end

    -- They never saw an invite, so say what they have just been put on.
    local what = job.heist and 'called a heist' or ('took a %s'):format(job.contract.label)
    local word = ('%s %s. You are on it.'):format(Framework.GetName(job.holder), what)

    for _, src in ipairs(Crew.Roster(job.holder)) do
        if src ~= job.holder and not Crew.Has(job, src) then
            local ped = GetPlayerPed(src)

            if Crew.Size(job) >= max then
                Framework.Notify(src, 'No room on that one — sit it out.', 'inform')
            elseif Jobs.Get(src) then
                Framework.Notify(src, 'You are on something else already.', 'inform')
            elseif not Players.HasUnit(src) then
                Framework.Notify(src, 'You needed a unit of your own for that.', 'error')
            elseif origin and (not ped or ped == 0 or #(GetEntityCoords(ped) - origin) > Config.Crew.joinRadius) then
                Framework.Notify(src, 'You were too far away to be picked up.', 'inform')
            else
                Crew.Join(job, src)
                Framework.Notify(src, word, 'success')
            end
        end
    end

    Crew.Push(crew)
end

-- Called once a job has finished being cleaned up, so the crew list shows
-- everyone as free again — or breaks up, if the server wants it that way.
function Crew.AfterJob(job)
    local seen = {}

    -- Everyone who was on it, not just whoever held the contract: the holder
    -- may have walked out of the crew while it was running.
    for _, src in ipairs(Jobs.Members(job)) do
        local crew = Crew.Of(src)

        if crew and not seen[crew.leader] then
            seen[crew.leader] = true

            if Config.Crew.keepAfterJob then
                Crew.Push(crew)
            else
                disband(crew, 'The crew broke up.')
            end
        end
    end
end

-- ── Inviting ─────────────────────────────────────────────────────────────────

-- One button, two meanings. With a job running this puts somebody into it; on
-- foot with nothing on, it builds the crew for whatever comes next.
function Crew.Invite(src, targetSrc)
    local job = Jobs.Get(src)
    if not job or job.finished then return Crew.Ask(src, targetSrc) end

    if job.holder ~= src then return false, 'Only the person holding the contract can invite.' end

    if not job.heist and not Config.Duo.enabled then
        return false, 'Duo work is switched off here.'
    end

    if Crew.Size(job) >= Crew.MaxFor(job) then
        return false, 'There is no room for anyone else.'
    end

    if Crew.Has(job, targetSrc) then return false, 'They are already on it.' end
    if Jobs.Get(targetSrc) then return false, 'They are busy with something else.' end

    if not Players.HasUnit(targetSrc) then
        return false, 'They have no unit on them.'
    end

    local holderPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetSrc)

    if not holderPed or not targetPed or holderPed == 0 or targetPed == 0 then
        return false, 'They are not here.'
    end

    local radius = job.heist and 10.0 or Config.Duo.inviteRadius
    if #(GetEntityCoords(holderPed) - GetEntityCoords(targetPed)) > radius then
        return false, 'They need to be standing with you.'
    end

    invites[key(targetSrc, job.id)] = {
        jobId = job.id,
        from = src,
        expires = os.time() + Config.Duo.inviteTimeout,
    }

    TriggerClientEvent('XS-Boosting:client:invite', targetSrc, {
        jobId = job.id,
        from = Framework.GetName(src),
        label = job.contract.label,
        tier = job.tier,
        heist = job.heist and true or false,
        seconds = Config.Duo.inviteTimeout,
    })

    return true
end

function Crew.Accept(src, jobId)
    local invite = invites[key(src, jobId)]
    if not invite then return false, 'That invite is gone.' end

    invites[key(src, jobId)] = nil

    if os.time() > invite.expires then return false, 'That invite lapsed.' end

    local job = Jobs.ById(jobId)
    if not job or job.finished then return false, 'That contract is over.' end
    if Crew.Size(job) >= Crew.MaxFor(job) then return false, 'They filled the spot.' end
    if Jobs.Get(src) then return false, 'You are already on something.' end
    if not Players.HasUnit(src) then return false, 'You need a unit of your own.' end

    Crew.Join(job, src)
    return true
end

function Crew.Decline(src, jobId)
    local invite = invites[key(src, jobId)]
    invites[key(src, jobId)] = nil

    if invite then
        Framework.Notify(invite.from, ('%s turned it down.'):format(Framework.GetName(src)), 'inform')
    end

    return true
end

AddEventHandler('playerDropped', function()
    Crew.Quit(source)
end)

CreateThread(function()
    while true do
        Wait(5000)
        local now = os.time()

        for id, invite in pairs(invites) do
            if now > invite.expires then invites[id] = nil end
        end

        for src, ask in pairs(asks) do
            if now > ask.expires then asks[src] = nil end
        end
    end
end)
