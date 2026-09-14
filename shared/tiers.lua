Tiers = {}

local byId = {}
local order = {}

for index, tier in ipairs(Config.Tiers) do
    tier.index = index
    byId[tier.id] = tier
    order[#order + 1] = tier
end

function Tiers.Get(id)
    return byId[id]
end

function Tiers.All()
    return order
end

function Tiers.Count()
    return #order
end

function Tiers.Unlocked(id, rep)
    local tier = byId[id]
    if not tier then return false end
    return (rep or 0) >= (tier.repNeeded or 0)
end

function Tiers.HighestUnlocked(rep)
    local best = order[1]
    for _, tier in ipairs(order) do
        if (rep or 0) >= (tier.repNeeded or 0) then best = tier end
    end
    return best
end

function Tiers.UnlockedList(rep)
    local out = {}
    for _, tier in ipairs(order) do
        if (rep or 0) >= (tier.repNeeded or 0) then out[#out + 1] = tier end
    end
    return out
end

function Tiers.Next(rep)
    for _, tier in ipairs(order) do
        if (rep or 0) < (tier.repNeeded or 0) then return tier end
    end
    return nil
end

function Tiers.RandomVehicle(id)
    local tier = byId[id]
    if not tier or not tier.vehicles or #tier.vehicles == 0 then return nil end
    return tier.vehicles[math.random(#tier.vehicles)]
end

function Tiers.FindVehicle(id, model)
    local tier = byId[id]
    if not tier then return nil end
    for _, vehicle in ipairs(tier.vehicles or {}) do
        if vehicle.model == model then return vehicle end
    end
    return nil
end

function Tiers.Fitted(id, what)
    local tier = byId[id]
    if not tier or not tier.fitted then return false end
    return math.random(100) <= (tier.fitted[what] or 0)
end

function Tiers.Difficulty(id, stage)
    local tier = byId[id]
    if not tier or not tier.difficulty then return 1 end
    return tier.difficulty[stage] or 1
end
