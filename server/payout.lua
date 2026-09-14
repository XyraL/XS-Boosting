Payout = {}

local function round(amount)
    local step = math.max(1, Config.Payment.roundTo or 1)
    return math.floor((amount / step) + 0.5) * step
end

-- Condition sits on a curve, not a table of steps. A car at 85 pays between
-- the 90 row and the 75 row rather than snapping down to 75.
function Payout.ConditionPct(condition)
    if not Config.Condition.enabled then return 100 end

    local scale = Config.Condition.scale
    condition = math.max(0, math.min(100, condition or 100))

    if condition >= scale[1].at then return scale[1].pct end

    for index = 1, #scale - 1 do
        local high, low = scale[index], scale[index + 1]

        if condition <= high.at and condition >= low.at then
            local span = high.at - low.at
            if span <= 0 then return low.pct end

            local ratio = (condition - low.at) / span
            return low.pct + ((high.pct - low.pct) * ratio)
        end
    end

    return scale[#scale].pct
end

function Payout.Base(contract)
    local tier = Tiers.Get(contract.tier)
    local multiplier = tier and tier.payoutMultiplier or 1.0
    local market = contract.market or 1.0

    return (contract.basePay or 0) * multiplier * market
end

-- What the board advertises: a clean car, delivered as asked, before any
-- condition bonus or penalty.
function Payout.Estimate(contract)
    local amount = Payout.Base(contract)

    if contract.type == 'spec' and contract.bonusPct then
        amount = amount * (1 + (contract.bonusPct / 100))
    end

    return round(amount)
end

-- Cashing parts in takes them off the player. Anything they no longer have
-- is not paid for, so pulling a part and dropping the item is not a way to
-- get paid for it twice.
function Payout.Parts(src, partIds)
    local total = 0

    for _, id in ipairs(partIds or {}) do
        for _, part in ipairs(Config.Chop.parts) do
            if part.id == id then
                if Inv.Has(src, part.item, 1) and Inv.Remove(src, part.item, 1) then
                    total = total + (part.value or 0)
                end
                break
            end
        end
    end

    return round(total)
end

-- opts: condition, route ('buyer' | 'chop' | 'fence'), specMatched, duo, heist
function Payout.Settle(contract, opts)
    opts = opts or {}

    local amount = Payout.Base(contract)
    local route = opts.route or 'buyer'

    if route == 'buyer' then
        amount = amount * (Payout.ConditionPct(opts.condition) / 100)

        if contract.type == 'spec' then
            if opts.specMatched then
                amount = amount * (1 + ((contract.bonusPct or 0) / 100))
            end
        end
    elseif route == 'chop' then
        amount = amount * (Config.Disposal.chopShop.bailoutPct / 100)
        amount = amount * (Payout.ConditionPct(opts.condition) / 100)
    elseif route == 'fence' then
        local better = Unlocks.BuffFor(opts.citizenid, 'fence_pct')
        amount = amount * ((Config.Disposal.fence.payPct + better) / 100)
    end

    if opts.duo and Config.Duo.enabled then
        local extra = Unlocks.BuffFor(opts.citizenid, 'duo_pct')
        amount = amount * (1 + ((Config.Duo.payoutBonusPct + extra) / 100))
    end

    local bonus = Unlocks.BuffFor(opts.citizenid, 'payout_pct')
    if bonus > 0 then amount = amount * (1 + (bonus / 100)) end

    if opts.heist and Config.Heist.enabled then
        amount = amount * (1 + (Config.Heist.completionBonusPct / 100))
    end

    return round(math.max(0, amount))
end

function Payout.Pay(src, amount, reason)
    if amount <= 0 then return true end

    if Config.Payment.method == 'item' then
        local worth = math.max(1, Config.Payment.item.worth)
        local count = math.floor(amount / worth)
        if count < 1 then count = 1 end
        return Inv.Add(src, Config.Payment.item.name, count)
    end

    return Framework.AddMoney(src, Config.Payment.account, amount, reason or 'boosting') and true or false
end

-- How a payout is divided across everyone on the job. Returns a list of
-- { src, amount } so the caller never has to know the mode.
function Payout.Split(amount, members, mode)
    local out = {}
    if #members == 0 then return out end

    if mode == 'full' then
        for _, src in ipairs(members) do out[#out + 1] = { src = src, amount = amount } end
        return out
    end

    if mode == 'holder' then
        out[#out + 1] = { src = members[1], amount = amount }
        return out
    end

    local share = round(amount / #members)
    for _, src in ipairs(members) do out[#out + 1] = { src = src, amount = share } end
    return out
end
