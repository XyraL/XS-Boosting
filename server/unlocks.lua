Unlocks = {}

-- Nothing is bought and nothing is spent. An unlock is earned the moment the
-- record behind it crosses its threshold, and it stays earned. Every buff of
-- the same type stacks, so two payout unlocks are simply added together.

local function progress(record, requires)
    if not record or not requires then return 0 end

    local value = ({
        completed = record.completed,
        chopped   = record.chopped,
        heists    = record.heists,
        rep       = record.rep,
        earned    = record.earned,
    })[requires.type]

    return value or 0
end

function Unlocks.Earned(record, entry)
    if not Config.Unlocks.enabled then return false end
    return progress(record, entry.requires) >= (entry.requires.value or 0)
end

function Unlocks.For(record)
    local out = {}

    for _, entry in ipairs(Config.Unlocks.list) do
        local have = progress(record, entry.requires)
        local need = entry.requires.value or 0

        out[#out + 1] = {
            id          = entry.id,
            label       = entry.label,
            description = entry.description,
            effect      = entry.effect,
            earned      = Unlocks.Earned(record, entry),
            have        = math.min(have, need),
            need        = need,
            kind        = entry.requires.type,
        }
    end

    return out
end

-- The total value of every earned buff of one type. Everything that reads a
-- buff goes through here, so an unlock only has to be listed in config.
function Unlocks.Buff(record, buffType)
    if not Config.Unlocks.enabled or not record then return 0 end

    local total = 0

    for _, entry in ipairs(Config.Unlocks.list) do
        if entry.buff and entry.buff.type == buffType and Unlocks.Earned(record, entry) then
            total = total + (entry.buff.value or 0)
        end
    end

    return total
end

function Unlocks.BuffFor(citizenid, buffType)
    return Unlocks.Buff(Players.Get(citizenid), buffType)
end

-- Called after anything that could push a counter over a line, so the player
-- is told the moment they earn something rather than the next time they look.
function Unlocks.Check(citizenid, before)
    if not Config.Unlocks.enabled then return end

    local record = Players.Get(citizenid)
    if not record then return end

    local src = Players.SourceOf(citizenid)
    if not src then return end

    for _, entry in ipairs(Config.Unlocks.list) do
        local had = before and progress(before, entry.requires) >= (entry.requires.value or 0)
        if not had and Unlocks.Earned(record, entry) then
            TriggerClientEvent('XS-Boosting:client:unlocked', src, {
                id = entry.id,
                label = entry.label,
                effect = entry.effect,
            })
        end
    end
end

function Unlocks.Snapshot(record)
    if not record then return nil end

    return {
        completed = record.completed,
        chopped   = record.chopped,
        heists    = record.heists,
        rep       = record.rep,
        earned    = record.earned,
    }
end
