Stats = {}

local COLUMNS = {
    completed = 'completed',
    earned    = 'earned',
    rep       = 'rep',
}

function Stats.Leaderboard()
    local column = COLUMNS[Config.Stats.leaderboardBy] or 'completed'

    local rows = MySQL.query.await(([[
        SELECT citizenid, handle, avatar, rep, completed, chopped, earned, heists
        FROM xs_boosting_players
        WHERE completed > 0 OR chopped > 0 OR heists > 0
        ORDER BY `%s` DESC
        LIMIT ?
    ]]):format(column), { Config.Stats.leaderboardSize }) or {}

    local out = {}

    for index, row in ipairs(rows) do
        out[index] = {
            rank      = index,
            name      = Players.DisplayName(row),
            named     = row.handle ~= nil and row.handle ~= '',
            avatar    = row.avatar,
            rep       = row.rep,
            completed = row.completed,
            chopped   = row.chopped,
            earned    = row.earned,
            heists    = row.heists,
        }
    end

    return out
end

function Stats.For(src)
    local record = Players.Of(src)
    if not record then return nil end

    local tier = Tiers.HighestUnlocked(record.rep)
    local next_ = Tiers.Next(record.rep)

    return {
        handle    = record.handle,
        avatar    = record.avatar,
        tagline   = record.tagline,
        display   = Players.DisplayName(record),
        handles   = Config.Stats.handles,
        profile   = {
            allowCustomImages = Config.Profile.allowCustomImages,
            taglineMax = Config.Profile.taglineMax,
        },
        rep       = record.rep,
        completed = record.completed,
        failed    = record.failed,
        chopped   = record.chopped,
        heists    = record.heists,
        earned    = record.earned,
        tier      = tier and { id = tier.id, label = tier.label, index = tier.index } or nil,
        nextTier  = next_ and {
            id = next_.id,
            label = next_.label,
            repNeeded = next_.repNeeded,
            remaining = math.max(0, next_.repNeeded - record.rep),
        } or nil,
        tiers     = Stats.Tiers(record.rep),
        unlocks   = Unlocks.For(record),
        cooldown  = Players.Cooldown(record.citizenid),
        history   = Players.History(record.citizenid),
    }
end

function Stats.Tiers(rep)
    local out = {}

    for _, tier in ipairs(Tiers.All()) do
        out[#out + 1] = {
            id        = tier.id,
            label     = tier.label,
            description = tier.description,
            repNeeded = tier.repNeeded,
            unlocked  = rep >= tier.repNeeded,
            market    = Market.Get(tier.id),
            vehicles  = #(tier.vehicles or {}),
        }
    end

    return out
end
