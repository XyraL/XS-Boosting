-- Patching the registrar rather than each call site gives every NUI callback in
-- the resource two guarantees, including any added later:
--
-- 1. Each handler runs in its own thread. FiveM will not dispatch the next NUI
--    callback while the current one is still yielding, and most handlers here
--    yield on a server round-trip.
-- 2. A nil payload is sent as `false`. cb(nil) sends no response body at all,
--    leaving the page's fetch pending forever. Several callbacks return nil
--    legitimately, and every consumer tests for truthiness, so `false` reads
--    the same to the page and actually resolves.
if not IsDuplicityVersion() and type(RegisterNUICallback) == 'function' then
    local _registerNUI = RegisterNUICallback

    RegisterNUICallback = function(name, handler)
        return _registerNUI(name, function(data, cb)
            CreateThread(function()
                handler(data, function(payload, ...)
                    if payload == nil then payload = false end
                    cb(payload, ...)
                end)
            end)
        end)
    end
end

Framework = { name = nil, core = nil }

local function detect()
    local forced = Config.Bridges.framework
    if forced == 'qbox' or forced == 'qbcore' then return forced end
    if GetResourceState('qbx_core') == 'started' then return 'qbox' end
    if GetResourceState('qb-core') == 'started' then return 'qbcore' end
    return nil
end

Framework.name = detect()

if Framework.name == 'qbcore' then
    Framework.core = exports['qb-core']:GetCoreObject()
elseif not Framework.name then
    print('^1[XS-Boosting]^0 No supported framework found. Start qbx_core or qb-core before XS-Boosting.')
end

if IsDuplicityVersion() then
    function Framework.GetPlayer(src)
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayer(src) end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayer(src) end
        return nil
    end

    function Framework.GetCitizenId(src)
        local player = Framework.GetPlayer(src)
        return player and player.PlayerData and player.PlayerData.citizenid or nil
    end

    function Framework.GetJob(src)
        local player = Framework.GetPlayer(src)
        local job = player and player.PlayerData and player.PlayerData.job
        if not job then return nil, false end
        return job.name, job.onduty and true or false
    end

    function Framework.GetName(src)
        local player = Framework.GetPlayer(src)
        local info = player and player.PlayerData and player.PlayerData.charinfo
        if not info then return GetPlayerName(src) or 'Unknown' end
        return ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end

    function Framework.GetNameByCitizenId(citizenid)
        local row = MySQL.single.await('SELECT charinfo FROM players WHERE citizenid = ?', { citizenid })
        if not row or not row.charinfo then return citizenid end
        local ok, info = pcall(json.decode, row.charinfo)
        if not ok or not info then return citizenid end
        return ('%s %s'):format(info.firstname or '', info.lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
    end

    function Framework.AddMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account or 'cash', math.floor(amount), reason or 'XS-Boosting')
    end

    function Framework.RemoveMoney(src, account, amount, reason)
        local player = Framework.GetPlayer(src)
        if not player then return false end
        return player.Functions.RemoveMoney(account or 'cash', math.floor(amount), reason or 'XS-Boosting')
    end

    function Framework.PoliceCount()
        local count = 0
        local players = Framework.name == 'qbox'
            and exports.qbx_core:GetQBPlayers()
            or (Framework.core and Framework.core.Functions.GetQBPlayers()) or {}

        for _, player in pairs(players) do
            local job = player.PlayerData and player.PlayerData.job
            if job and job.onduty then
                for _, name in ipairs(Config.Police.jobs) do
                    if job.name == name then
                        count = count + 1
                        break
                    end
                end
            end
        end

        return count
    end

    function Framework.IsAdmin(src)
        local admin = Config.Admin

        if admin.acePermission and admin.acePermission ~= '' then
            if IsPlayerAceAllowed(src, admin.acePermission) then return true end
        end

        for _, group in ipairs(admin.groups or {}) do
            if Framework.name == 'qbox' then
                if exports.qbx_core:HasPermission(src, group) then return true end
            elseif Framework.core and Framework.core.Functions.HasPermission(src, group) then
                return true
            end
        end

        if #(admin.licenses or {}) > 0 then
            for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
                local license = identifier:match('^license2?:(.+)$')
                if license then
                    for _, allowed in ipairs(admin.licenses) do
                        if license == allowed then return true end
                    end
                end
            end
        end

        return false
    end

    -- Both frameworks keep owned vehicles in player_vehicles, with the same
    -- columns for everything this needs. Anything optional is left to the
    -- table's own defaults rather than guessed at.
    function Framework.GiveVehicle(src, model, plate, garage)
        local player = Framework.GetPlayer(src)
        if not player then return false end

        local data = player.PlayerData
        local citizenid = data and data.citizenid
        if not citizenid then return false end

        local license
        for _, identifier in ipairs(GetPlayerIdentifiers(src) or {}) do
            license = identifier:match('^license2?:.+$') or license
        end

        local ok, err = pcall(function()
            MySQL.insert.await([[
                INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ]], {
                license or '',
                citizenid,
                model,
                joaat(model),
                json.encode({ plate = plate }),
                plate,
                garage or 'legion',
                1,
            })
        end)

        if not ok then
            print(('^1[XS-Boosting]^0 could not hand a vehicle over: %s'):format(err))
            return false
        end

        return true
    end

    -- Whatever the framework has in its shared vehicle list. Used only by the
    -- builder, so a server that keeps no such list simply gets a shorter
    -- dropdown rather than an error.
    function Framework.Vehicles()
        local out = {}
        local seen = {}

        local function add(model, label)
            model = tostring(model or ''):lower()
            if model == '' or seen[model] then return end
            seen[model] = true
            out[#out + 1] = { model = model, label = tostring(label or model) }
        end

        local ok = pcall(function()
            if Framework.name == 'qbox' then
                for model, data in pairs(exports.qbx_core:GetVehiclesByName() or {}) do
                    add(model, type(data) == 'table' and (data.name or data.model) or model)
                end
            elseif Framework.core and Framework.core.Shared and Framework.core.Shared.Vehicles then
                for model, data in pairs(Framework.core.Shared.Vehicles) do
                    add(model, type(data) == 'table' and (data.name or data.model) or model)
                end
            end
        end)

        if not ok or #out == 0 then return {} end

        table.sort(out, function(a, b) return a.label < b.label end)
        return out
    end

    function Framework.Notify(src, message, kind)
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Boosting',
            description = message,
            type = kind or 'inform',
        })
    end
else
    function Framework.GetPlayerData()
        if Framework.name == 'qbox' then return exports.qbx_core:GetPlayerData() end
        if Framework.name == 'qbcore' then return Framework.core.Functions.GetPlayerData() end
        return nil
    end

    function Framework.GetJob()
        local data = Framework.GetPlayerData()
        local job = data and data.job
        if not job then return nil, false end
        return job.name, job.onduty and true or false
    end

    function Framework.IsPolice()
        local name = Framework.GetJob()
        if not name then return false end
        for _, allowed in ipairs(Config.Police.jobs) do
            if name == allowed then return true end
        end
        return false
    end

    function Framework.Notify(message, kind)
        lib.notify({ title = 'Boosting', description = message, type = kind or 'inform' })
    end
end
