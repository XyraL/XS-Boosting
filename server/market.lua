Market = {}

local prices = {}
local nextShift = 0

local function clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

function Market.Get(tier)
    if not Config.Market.enabled then return 1.0 end
    return prices[tier] or 1.0
end

function Market.All()
    local out = {}

    for _, tier in ipairs(Tiers.All()) do
        out[#out + 1] = {
            id         = tier.id,
            label      = tier.label,
            multiplier = Market.Get(tier.id),
        }
    end

    return out
end

function Market.NextShiftIn()
    if not Config.Market.enabled then return 0 end
    return math.max(0, math.floor((nextShift - os.time()) / 60))
end

function Market.Shift()
    if not Config.Market.enabled then return end

    local range = Config.Market.range
    local step = Config.Market.maxStep

    for _, tier in ipairs(Tiers.All()) do
        local current = prices[tier.id] or 1.0
        local drift = (math.random() * 2 - 1) * step
        prices[tier.id] = clamp(current + drift, range.min, range.max)
    end

    Market.Save()
    nextShift = os.time() + (Config.Market.shiftMinutes * 60)

    TriggerClientEvent('XS-Boosting:client:market', -1, Market.All())
end

function Market.Save()
    for tier, multiplier in pairs(prices) do
        MySQL.query.await([[
            INSERT INTO xs_boosting_market (tier, multiplier) VALUES (?, ?)
            ON DUPLICATE KEY UPDATE multiplier = VALUES(multiplier)
        ]], { tier, multiplier })
    end
end

function Market.Load()
    local rows = MySQL.query.await('SELECT tier, multiplier FROM xs_boosting_market') or {}

    for _, row in ipairs(rows) do
        prices[row.tier] = row.multiplier
    end

    for _, tier in ipairs(Tiers.All()) do
        if not prices[tier.id] then prices[tier.id] = 1.0 end
    end
end

CreateThread(function()
    while not Db.ready do Wait(200) end

    Market.Load()
    nextShift = os.time() + (Config.Market.shiftMinutes * 60)

    while true do
        Wait(60000)
        if Config.Market.enabled and os.time() >= nextShift then
            Market.Shift()
        end
    end
end)
