-- The board.
--
-- Every player gets their own. Two people opening a unit at the same moment
-- see two different sets of work, so nobody is racing anybody for a listing
-- and a quiet server does not look empty just because one person took the
-- only good contract. The server event is the deliberate exception: that one
-- is shared, contested, and lives in server/event.lua.
--
-- Set Config.Contracts.sharedBoard and every player is keyed to the same
-- board instead, which is the older behaviour.

Contracts = {}

local boards = {}
local nextId = 1

local function uid()
    local id = ('C%04d'):format(nextId)
    nextId = nextId + 1
    return id
end

local function keyFor(src)
    if Config.Contracts.sharedBoard then return '*' end
    return Framework.GetCitizenId(src)
end

local function enabledTypes()
    local out = {}
    for name, entry in pairs(Config.Contracts.types) do
        if entry.enabled then out[#out + 1] = { name = name, weight = entry.weight or 1 } end
    end
    return out
end

local function rollType()
    local pool = enabledTypes()
    if #pool == 0 then return nil end

    local total = 0
    for _, entry in ipairs(pool) do total = total + entry.weight end
    if total <= 0 then return pool[1].name end

    local roll = math.random() * total
    for _, entry in ipairs(pool) do
        roll = roll - entry.weight
        if roll <= 0 then return entry.name end
    end

    return pool[#pool].name
end

-- Only tiers that actually have somewhere for a car to appear. A tier with no
-- spawn points placed in the builder simply never comes up.
local function tiersWithSpawns()
    local out = {}
    for _, tier in ipairs(Tiers.All()) do
        if Store.Count('spawn', tier.id) > 0 and #(tier.vehicles or {}) > 0 then
            out[#out + 1] = tier
        end
    end
    return out
end

local function rollSpec(tier)
    local colours = Config.Contracts.types.spec.colours
    if not colours or #colours == 0 then return nil end
    return colours[math.random(#colours)]
end

local function rollParts()
    local range = Config.Contracts.types.chop.partsRequired
    local count = math.random(range.min, range.max)
    local pool = {}

    for _, part in ipairs(Config.Chop.parts) do pool[#pool + 1] = part end

    for index = #pool, 2, -1 do
        local swap = math.random(index)
        pool[index], pool[swap] = pool[swap], pool[index]
    end

    local out = {}
    for index = 1, math.min(count, #pool) do
        out[#out + 1] = { id = pool[index].id, label = pool[index].label }
    end

    return out
end

-- Spawn points with a car sitting on them right now. Per-player boards mean
-- two people can be pointed at the same corner, so anywhere already in play is
-- kept off both of their boards.
function Contracts.BusySpawns()
    local out = {}

    for _, job in pairs(Jobs.Active()) do
        if not job.finished and job.spawn then out[#out + 1] = job.spawn.id end
    end

    return out
end

function Contracts.SpawnBusy(id)
    for _, busy in ipairs(Contracts.BusySpawns()) do
        if busy == id then return true end
    end
    return false
end

function Contracts.Generate(exclude)
    local tiers = tiersWithSpawns()
    if #tiers == 0 then return nil end

    local buyers = Store.Enabled('buyer')
    if #buyers == 0 then return nil end

    local kind = rollType()
    if not kind then return nil end

    local tier = tiers[math.random(#tiers)]
    local vehicle = Tiers.RandomVehicle(tier.id)
    if not vehicle then return nil end

    local spawn = Store.RandomSpawn(tier.id, exclude)
    if not spawn then return nil end

    local contract = {
        id       = uid(),
        type     = kind,
        tier     = tier.id,
        model    = vehicle.model,
        label    = vehicle.label,
        basePay  = vehicle.payout,
        spawnId  = spawn.id,
        buyerId  = buyers[math.random(#buyers)].id,
        radius   = tier.searchRadius,
        listedAt = os.time(),
        market   = Market.Get(tier.id),
    }

    if Config.Contracts.expiryMinutes > 0 then
        contract.expiresAt = contract.listedAt + (Config.Contracts.expiryMinutes * 60)
    end

    if kind == 'spec' then
        contract.colour = rollSpec(tier)
        contract.minCondition = Config.Contracts.types.spec.minCondition
        contract.bonusPct = Config.Contracts.types.spec.bonusPct
    elseif kind == 'chop' then
        contract.parts = rollParts()
    end

    return contract
end

-- Cull what has rotted or lost its place, then fill back up to boardSize.
local function topUp(board)
    local now = os.time()

    for index = #board.contracts, 1, -1 do
        local contract = board.contracts[index]
        local spawn = Store.Get(contract.spawnId)
        local buyer = Store.Get(contract.buyerId)

        local gone = not spawn or not spawn.enabled or not buyer or not buyer.enabled
        local expired = contract.expiresAt and now >= contract.expiresAt

        if (gone or expired) and not contract.takenBy then
            table.remove(board.contracts, index)
        end
    end

    -- Nowhere on this board points at a spot another contract on it already
    -- uses, or at a car somebody is out collecting.
    local exclude = Contracts.BusySpawns()

    local available = 0
    for _, contract in ipairs(board.contracts) do
        if not contract.takenBy then
            available = available + 1
            exclude[#exclude + 1] = contract.spawnId
        end
    end

    local attempts = 0
    while available < Config.Contracts.boardSize and attempts < 40 do
        attempts = attempts + 1

        local contract = Contracts.Generate(exclude)
        if not contract then break end

        board.contracts[#board.contracts + 1] = contract
        exclude[#exclude + 1] = contract.spawnId
        available = available + 1
    end

    board.touchedAt = now
end

-- refreshedAt is only moved on by the timer, never by a top-up, or the
-- countdown the unit shows would reset every time somebody took a contract.
function Contracts.BoardFor(src)
    local key = keyFor(src)
    if not key then return nil end

    local board = boards[key]

    if not board then
        board = { contracts = {}, refreshedAt = 0, touchedAt = os.time() }
        boards[key] = board
    end

    board.touchedAt = os.time()

    local due = board.refreshedAt + (Config.Contracts.refreshMinutes * 60)
    if board.refreshedAt == 0 or os.time() >= due then
        board.refreshedAt = os.time()
        topUp(board)
    end

    return board
end

-- One board, filled and sent. Use this when only that player has taken
-- something and nobody else has any reason to be told about it.
function Contracts.Fill(src)
    local board = Contracts.BoardFor(src)
    if not board then return end

    topUp(board)
    Contracts.Push(src)
end

function Contracts.Refresh()
    for _, src in ipairs(GetPlayers()) do
        Contracts.Fill(tonumber(src))
    end
end

-- The admin button. Everything untaken is thrown away and rolled again, which
-- is what "refresh the board" reads as to the person pressing it.
function Contracts.Reroll()
    for key, board in pairs(boards) do
        local kept = {}

        for _, contract in ipairs(board.contracts) do
            if contract.takenBy then kept[#kept + 1] = contract end
        end

        board.contracts = kept
        board.refreshedAt = 0
        boards[key] = board
    end

    Contracts.Refresh()
end

function Contracts.Find(src, id)
    local board = Contracts.BoardFor(src)
    if not board then return nil end

    for _, contract in ipairs(board.contracts) do
        if contract.id == id then return contract end
    end

    return nil
end

function Contracts.Remove(src, id)
    local key = keyFor(src)
    local board = key and boards[key]
    if not board then return false end

    for index, contract in ipairs(board.contracts) do
        if contract.id == id then
            table.remove(board.contracts, index)
            return true
        end
    end

    return false
end

-- The board a player is allowed to see. Spawn and buyer ids never go to the
-- client — the whole point of the search zone is that the car is not pinned.
function Contracts.For(src)
    local record = Players.Of(src)
    if not record then return {} end

    local board = Contracts.BoardFor(src)
    if not board then return {} end

    local rep = record.rep or 0
    local out = {}

    for _, contract in ipairs(board.contracts) do
        if not contract.takenBy then
            local unlocked = Tiers.Unlocked(contract.tier, rep)

            if unlocked or Config.Contracts.showLockedTiers then
                local tier = Tiers.Get(contract.tier)

                out[#out + 1] = {
                    id       = contract.id,
                    type     = contract.type,
                    tier     = contract.tier,
                    tierLabel = tier and tier.label or contract.tier,
                    label    = contract.label,
                    model    = contract.model,
                    payout   = Payout.Estimate(contract),
                    locked   = not unlocked,
                    repNeeded = tier and tier.repNeeded or 0,
                    market   = contract.market,
                    colour   = contract.colour and contract.colour.name or nil,
                    minCondition = contract.minCondition,
                    parts    = contract.parts,
                    expiresIn = contract.expiresAt and math.max(0, contract.expiresAt - os.time()) or nil,
                }
            end
        end
    end

    table.sort(out, function(a, b)
        local at = Tiers.Get(a.tier)
        local bt = Tiers.Get(b.tier)
        if (at and at.index or 0) ~= (bt and bt.index or 0) then
            return (at and at.index or 0) < (bt and bt.index or 0)
        end
        return a.id < b.id
    end)

    return out
end

function Contracts.Push(src)
    TriggerClientEvent('XS-Boosting:client:board', src, Contracts.For(src))
end

function Contracts.PushAll()
    for _, src in ipairs(GetPlayers()) do
        Contracts.Push(tonumber(src))
    end
end

function Contracts.NextRefreshIn(src)
    local key = keyFor(src)
    local board = key and boards[key]
    if not board then return 0 end

    local due = board.refreshedAt + (Config.Contracts.refreshMinutes * 60)
    return math.max(0, due - os.time())
end

CreateThread(function()
    while not Store.Ready() do Wait(250) end

    Contracts.Refresh()

    while true do
        Wait(30000)
        Contracts.Refresh()

        -- A board is kept after its owner logs off, so relogging is not a way
        -- to reroll a board you did not like. Dropped once it is well past
        -- being worth anything.
        local stale = os.time() - math.max(600, Config.Contracts.refreshMinutes * 120)

        for key, board in pairs(boards) do
            if key ~= '*' and board.touchedAt < stale then boards[key] = nil end
        end
    end
end)
