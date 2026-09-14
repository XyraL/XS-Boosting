Store = {}

local cache = {}
local loaded = false

-- A Lua vector3 does not survive the trip into the NUI page: json turns it
-- into null, not { x, y, z }. Anything crossing that boundary goes through
-- here first. Server-side code keeps the real vector, because it needs the
-- maths.
function Store.Plain(v)
    if not v then return nil end
    return { x = v.x + 0.0, y = v.y + 0.0, z = v.z + 0.0 }
end

-- A TINYINT(1) does not come back the same way everywhere. oxmysql hands it
-- over as a boolean on most builds and as a number on others, so `== 1` is a
-- coin toss — and when it lost, every place placed in the builder came back
-- switched off on the next restart. Take any of the three.
local function truthy(value)
    return value == true or value == 1 or value == '1'
end

local function decode(row)
    local data = {}
    if row.data and row.data ~= '' then
        local ok, parsed = pcall(json.decode, row.data)
        if ok and type(parsed) == 'table' then data = parsed end
    end

    return {
        id      = row.id,
        kind    = row.kind,
        label   = row.label or '',
        tier    = row.tier,
        coords  = vec3(row.x, row.y, row.z),
        heading = row.heading or 0.0,
        radius  = row.radius or 10.0,
        enabled = truthy(row.enabled),
        data    = data,
    }
end

function Store.Load()
    local rows = MySQL.query.await('SELECT * FROM xs_boosting_locations') or {}

    cache = {}
    for _, row in ipairs(rows) do
        cache[row.id] = decode(row)
    end

    loaded = true
    return cache
end

function Store.Ready()
    return loaded
end

function Store.Get(id)
    return cache[tonumber(id) or 0]
end

function Store.All(kind, tier)
    local out = {}

    for _, entry in pairs(cache) do
        local kindOk = not kind or entry.kind == kind
        local tierOk = not tier or entry.tier == tier
        if kindOk and tierOk then out[#out + 1] = entry end
    end

    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Store.Enabled(kind, tier)
    local out = {}
    for _, entry in ipairs(Store.All(kind, tier)) do
        if entry.enabled then out[#out + 1] = entry end
    end
    return out
end

function Store.Count(kind, tier)
    return #Store.Enabled(kind, tier)
end

function Store.Add(entry, citizenid)
    local id = MySQL.insert.await([[
        INSERT INTO xs_boosting_locations (kind, label, tier, x, y, z, heading, radius, enabled, data, created_by)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        entry.kind,
        entry.label or '',
        entry.tier,
        entry.coords.x, entry.coords.y, entry.coords.z,
        entry.heading or 0.0,
        entry.radius or 10.0,
        entry.enabled == false and 0 or 1,
        json.encode(entry.data or {}),
        citizenid,
    })

    if not id then return nil end

    cache[id] = {
        id      = id,
        kind    = entry.kind,
        label   = entry.label or '',
        tier    = entry.tier,
        coords  = entry.coords,
        heading = entry.heading or 0.0,
        radius  = entry.radius or 10.0,
        enabled = entry.enabled ~= false,
        data    = entry.data or {},
    }

    Store.Push()
    return cache[id]
end

function Store.Update(id, patch)
    id = tonumber(id)
    local entry = cache[id]
    if not entry then return false end

    for key, value in pairs(patch) do
        if key ~= 'id' then entry[key] = value end
    end

    MySQL.update.await([[
        UPDATE xs_boosting_locations
        SET kind = ?, label = ?, tier = ?, x = ?, y = ?, z = ?, heading = ?, radius = ?, enabled = ?, data = ?
        WHERE id = ?
    ]], {
        entry.kind,
        entry.label or '',
        entry.tier,
        entry.coords.x, entry.coords.y, entry.coords.z,
        entry.heading or 0.0,
        entry.radius or 10.0,
        entry.enabled and 1 or 0,
        json.encode(entry.data or {}),
        id,
    })

    Store.Push()
    return true
end

function Store.Delete(id)
    id = tonumber(id)
    if not cache[id] then return false end

    MySQL.query.await('DELETE FROM xs_boosting_locations WHERE id = ?', { id })
    MySQL.query.await('DELETE FROM xs_boosting_discovered WHERE location_id = ?', { id })

    cache[id] = nil
    Store.Wake(id)
    Store.Push()
    return true
end

-- Spawn points rest after they are used, so the same corner does not come up
-- every time on a server with only a few of them placed.
local resting = {}

function Store.Rest(id, minutes)
    if not id or (minutes or 0) <= 0 then return end
    resting[id] = os.time() + (minutes * 60)
end

function Store.Wake(id)
    if id then resting[id] = nil end
end

function Store.Resting()
    local out = {}
    for id in pairs(resting) do
        local left = Store.RestingFor(id)
        if left > 0 then out[id] = left end
    end
    return out
end

function Store.RestingFor(id)
    local until_ = resting[id]
    if not until_ then return 0 end

    local left = until_ - os.time()
    if left <= 0 then
        resting[id] = nil
        return 0
    end

    return left
end

function Store.RandomSpawn(tier, excludeIds)
    local free, any = {}, {}
    local skip = {}

    for _, id in ipairs(excludeIds or {}) do skip[id] = true end

    for _, entry in ipairs(Store.Enabled('spawn', tier)) do
        if not skip[entry.id] then
            any[#any + 1] = entry
            if Store.RestingFor(entry.id) == 0 then free[#free + 1] = entry end
        end
    end

    -- Prefer one that has had a break. If they have all been used recently,
    -- take one anyway rather than leaving the board short.
    local pool = #free > 0 and free or any

    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

function Store.Nearest(kind, coords)
    local best, bestDistance

    for _, entry in ipairs(Store.Enabled(kind)) do
        local distance = #(entry.coords - coords)
        if not bestDistance or distance < bestDistance then
            best, bestDistance = entry, distance
        end
    end

    return best, bestDistance
end

-- Only the places players are allowed to see. Spawn points and heist
-- locations never leave the server, or the search zone would be pointless.
local PUBLIC_KINDS = { chop = true, fence = true, deadzone = true, lockup = true }

function Store.Public()
    local out = {}

    for _, entry in pairs(cache) do
        if entry.enabled and PUBLIC_KINDS[entry.kind] then
            out[#out + 1] = {
                id     = entry.id,
                kind   = entry.kind,
                label  = entry.label,
                coords = Store.Plain(entry.coords),
                radius = entry.radius,
            }
        end
    end

    return out
end

function Store.IsPublic(kind)
    return PUBLIC_KINDS[kind] == true
end

function Store.DiscoveredBy(citizenid)
    if not citizenid then return {} end

    local rows = MySQL.query.await('SELECT location_id FROM xs_boosting_discovered WHERE citizenid = ?',
        { citizenid }) or {}

    local out = {}
    for _, row in ipairs(rows) do out[#out + 1] = row.location_id end
    return out
end

function Store.Push(target)
    TriggerClientEvent('XS-Boosting:client:locations', target or -1, Store.Public())
end

CreateThread(function()
    while not Db.ready do Wait(200) end
    Store.Load()

    if Config.Debug then
        print(('^2[XS-Boosting]^0 loaded %d locations'):format(#Store.All()))
    end
end)
