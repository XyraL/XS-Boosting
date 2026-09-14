Players = {}

local records = {}
local cooldowns = {}

local function blank(citizenid)
    return {
        citizenid = citizenid,
        rep = 0, completed = 0, failed = 0, chopped = 0,
        earned = 0, heists = 0,
    }
end

function Players.Get(citizenid)
    if not citizenid then return nil end
    if records[citizenid] then return records[citizenid] end

    local row = MySQL.single.await([[
        SELECT citizenid, handle, avatar, tagline, settings, rep, completed, failed, chopped, earned, heists
        FROM xs_boosting_players WHERE citizenid = ?
    ]], { citizenid })

    if not row then
        row = blank(citizenid)
        MySQL.insert.await('INSERT IGNORE INTO xs_boosting_players (citizenid) VALUES (?)', { citizenid })
    end

    records[citizenid] = row
    return row
end

function Players.Of(src)
    local citizenid = Framework.GetCitizenId(src)
    if not citizenid then return nil end
    return Players.Get(citizenid)
end

function Players.Save(citizenid)
    local record = records[citizenid]
    if not record then return end

    MySQL.update.await([[
        UPDATE xs_boosting_players
        SET rep = ?, completed = ?, failed = ?, chopped = ?, earned = ?, heists = ?, last_job = NOW()
        WHERE citizenid = ?
    ]], {
        record.rep, record.completed, record.failed,
        record.chopped, record.earned, record.heists, citizenid,
    })
end

function Players.AddRep(citizenid, amount)
    local record = Players.Get(citizenid)
    if not record then return 0 end

    local before = record.rep
    record.rep = math.max(Config.Rep.floor, record.rep + amount)
    Players.Save(citizenid)

    if record.rep ~= before then
        local src = Players.SourceOf(citizenid)
        if src then
            TriggerClientEvent('XS-Boosting:client:rep', src, record.rep, record.rep - before)
        end
    end

    return record.rep
end

-- A stable, meaningless tag for anyone who has not picked a handle. Derived
-- from the character id so it never changes, and gives nothing away.
function Players.Anonymous(citizenid)
    local hash = 5381

    for index = 1, #citizenid do
        hash = ((hash * 33) + citizenid:byte(index)) % 0xFFFFFF
    end

    return ('Unknown %04X'):format(hash % 0xFFFF)
end

function Players.DisplayName(record)
    if not Config.Stats.handles.enabled then
        return Framework.GetNameByCitizenId(record.citizenid)
    end

    if record.handle and record.handle ~= '' then return record.handle end
    return Players.Anonymous(record.citizenid)
end

function Players.SetHandle(citizenid, handle)
    local rules = Config.Stats.handles
    if not rules.enabled then return false, 'Handles are switched off here.' end

    handle = tostring(handle or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if #handle < rules.minLength or #handle > rules.maxLength then
        return false, ('Between %d and %d characters.'):format(rules.minLength, rules.maxLength)
    end

    if handle:find('[^%w%s%._%-]') then
        return false, 'Letters, numbers, spaces and . _ - only.'
    end

    if rules.unique then
        local taken = MySQL.scalar.await(
            'SELECT 1 FROM xs_boosting_players WHERE handle = ? AND citizenid != ? LIMIT 1',
            { handle, citizenid })

        if taken then return false, 'Somebody already goes by that.' end
    end

    local record = Players.Get(citizenid)
    if not record then return false, 'No character loaded.' end

    record.handle = handle
    MySQL.update.await('UPDATE xs_boosting_players SET handle = ? WHERE citizenid = ?', { handle, citizenid })

    return true, nil, handle
end

-- An avatar is either one of the drawn-in set ("bi:N") or, when the server
-- allows it, a link. Nothing else is stored, so a bad value can never become
-- markup on somebody else's screen.
function Players.SetAvatar(citizenid, avatar)
    avatar = tostring(avatar or ''):gsub('^%s+', ''):gsub('%s+$', '')

    local builtin = avatar:match('^bi:(%d+)$')
    if builtin then
        local index = tonumber(builtin)
        if not index or index < 0 or index >= Config.Profile.builtinCount then
            return false, 'No such picture.'
        end
    else
        if not Config.Profile.allowCustomImages then
            return false, 'Links are switched off here. Pick one of the set.'
        end

        if #avatar > Config.Profile.maxUrlLength then
            return false, 'That link is too long.'
        end

        local host = avatar:match('^https?://([^/]+)')
        if not host then return false, 'That is not a link.' end

        -- No credentials, no ports, no tricks in the authority.
        if host:find('[@:]') then return false, 'That link will not do.' end

        local allowed = Config.Profile.allowedHosts or {}
        if #allowed > 0 then
            local ok = false
            for _, entry in ipairs(allowed) do
                if host:lower() == entry:lower() then ok = true break end
            end
            if not ok then return false, 'That host is not allowed here.' end
        end
    end

    local record = Players.Get(citizenid)
    if not record then return false, 'No character loaded.' end

    record.avatar = avatar
    MySQL.update.await('UPDATE xs_boosting_players SET avatar = ? WHERE citizenid = ?', { avatar, citizenid })

    return true, nil, avatar
end

function Players.SetTagline(citizenid, tagline)
    if Config.Profile.taglineMax <= 0 then return false, 'Taglines are switched off here.' end

    tagline = tostring(tagline or ''):gsub('^%s+', ''):gsub('%s+$', '')

    if #tagline > Config.Profile.taglineMax then
        return false, ('Keep it under %d characters.'):format(Config.Profile.taglineMax)
    end

    -- Same character rule as handles, plus ordinary punctuation.
    if tagline ~= '' and tagline:find('[^%w%s%._%-%,%!%?%\'%/%&]') then
        return false, 'Letters, numbers and basic punctuation only.'
    end

    local record = Players.Get(citizenid)
    if not record then return false, 'No character loaded.' end

    record.tagline = tagline
    MySQL.update.await('UPDATE xs_boosting_players SET tagline = ? WHERE citizenid = ?', { tagline, citizenid })

    return true, nil, tagline
end

-- Settings are stored as one JSON blob rather than a column each, so adding
-- a new one is a config change and not a migration.
function Players.Settings(citizenid)
    local record = Players.Get(citizenid)
    if not record then return Config.Settings.defaults end

    if not record.parsedSettings then
        local parsed = {}

        if record.settings and record.settings ~= '' then
            local ok, decoded = pcall(json.decode, record.settings)
            if ok and type(decoded) == 'table' then parsed = decoded end
        end

        local merged = {}
        for key, value in pairs(Config.Settings.defaults) do merged[key] = value end
        for key, value in pairs(parsed) do
            if Config.Settings.defaults[key] ~= nil then merged[key] = value end
        end

        record.parsedSettings = merged
    end

    return record.parsedSettings
end

local function settingAllowed(key, value)
    local rule = Config.Settings.allowed[key]
    if not rule then return false end

    if rule == 'boolean' then return type(value) == 'boolean' end

    if type(rule) == 'table' then
        for _, entry in ipairs(rule) do
            if value == entry then return true end
        end
    end

    return false
end

function Players.SetSetting(citizenid, key, value)
    if type(key) ~= 'string' then return false, 'Bad request.' end
    if not settingAllowed(key, value) then return false, 'That is not a setting you can change.' end

    local settings = Players.Settings(citizenid)
    settings[key] = value

    MySQL.update.await('UPDATE xs_boosting_players SET settings = ? WHERE citizenid = ?',
        { json.encode(settings), citizenid })

    return true, nil, settings
end

function Players.SourceOf(citizenid)
    for _, src in ipairs(GetPlayers()) do
        src = tonumber(src)
        if Framework.GetCitizenId(src) == citizenid then return src end
    end
    return nil
end

function Players.HasUnit(src)
    return Inv.Has(src, Config.Access.item, 1)
end

function Players.Cooldown(citizenid)
    local until_ = cooldowns[citizenid]
    if not until_ then return 0 end

    local left = until_ - os.time()
    if left <= 0 then
        cooldowns[citizenid] = nil
        return 0
    end

    return left
end

function Players.SetCooldown(citizenid, seconds)
    if seconds <= 0 then return end
    cooldowns[citizenid] = os.time() + seconds
end

function Players.History(citizenid)
    return MySQL.query.await([[
        SELECT type, tier, model, label, outcome, payout, `condition`, created_at
        FROM xs_boosting_history
        WHERE citizenid = ?
        ORDER BY id DESC LIMIT ?
    ]], { citizenid, Config.Stats.historyLimit }) or {}
end

function Players.Record(citizenid, entry)
    MySQL.insert.await([[
        INSERT INTO xs_boosting_history (citizenid, type, tier, model, label, outcome, payout, `condition`, crew)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        citizenid,
        entry.type or 'standard',
        entry.tier or '',
        entry.model or '',
        entry.label or '',
        entry.outcome or 'failed',
        entry.payout or 0,
        entry.condition or 0,
        entry.crew and json.encode(entry.crew) or nil,
    })
end

AddEventHandler('playerDropped', function()
    local citizenid = Framework.GetCitizenId(source)
    if citizenid then Players.Save(citizenid) end
end)

-- Nothing in this resource works without its item existing, and the failure
-- is silent otherwise: the player just cannot open anything. Say so.
CreateThread(function()
    while not Db.ready do Wait(500) end
    Wait(3000)

    local missing = {}

    if not Inv.Exists(Config.Access.item) then
        missing[#missing + 1] = Config.Access.item
    end

    for _, item in ipairs({
        Config.Theft.entry.methods.lockpick.item,
        Config.Theft.tracker.item,
        Config.Chop.tool.item,
    }) do
        if item and item ~= '' and not Inv.Exists(item) then
            missing[#missing + 1] = item
        end
    end

    if #missing > 0 then
        print(('^3[XS-Boosting]^0 these items are not registered in your inventory yet: ^3%s^0')
            :format(table.concat(missing, ', ')))
        print('^3[XS-Boosting]^0 add them before anyone can use the resource. The unit is the important one — without it there is no way in.')
    end

    if #Store.Enabled('spawn') == 0 or #Store.Enabled('buyer') == 0 then
        print('^3[XS-Boosting]^0 nothing is placed yet. Run ^3/boosting^0 and put down at least one vehicle spawn and one handover point, or the board stays empty.')
    end
end)

-- Using the item is the only way in. Both frameworks route a used item the
-- same way, and ox_inventory honours whichever one is registered.
CreateThread(function()
    while not Framework.name do Wait(250) end

    local function onUse(src)
        if not Players.HasUnit(src) then return end
        TriggerClientEvent('XS-Boosting:client:open', src)
    end

    -- qb-style inventories route a used item through the framework. Harmless
    -- to register even on ox_inventory, which ignores it.
    if Framework.name == 'qbox' then
        pcall(function()
            exports.qbx_core:CreateUseableItem(Config.Access.item, function(src) onUse(src) end)
        end)
    elseif Framework.core then
        pcall(function()
            Framework.core.Functions.CreateUseableItem(Config.Access.item, function(src) onUse(src) end)
        end)
    end

    -- ox_inventory does not use CreateUseableItem at all. It calls an export
    -- named in its own items.lua, which is why the item does nothing until
    -- that entry exists. See the README for the block to paste in.
    if Inv.name == 'ox_inventory' then
        print('^2[XS-Boosting]^0 ox_inventory detected. The unit only works once its items.lua entry points at ^2XS-Boosting.openUnit^0 — see the README.')
    end
end)

-- The server-side half of the ox_inventory contract, for anyone who would
-- rather use server.export than client.export.
exports('useUnit', function(event, item, inventory, slot, data)
    if event ~= 'usingItem' then return end

    local src = inventory and inventory.id
    if not src then return end

    if not Players.HasUnit(src) then return false end

    TriggerClientEvent('XS-Boosting:client:open', src)
    return false
end)
