Db = { ready = false }

-- The schema file is the only place the tables are described. Reading it back
-- at start and running it means a fresh install needs no manual import, and an
-- existing one is untouched because every statement is CREATE TABLE IF NOT
-- EXISTS.
local function statements()
    local sql = LoadResourceFile(GetCurrentResourceName(), 'sql/xs_boosting.sql')
    if not sql then return nil end

    -- Comments come out before the split, not after. A semicolon inside a
    -- comment would otherwise cut a statement in half.
    local stripped = {}
    for line in (sql .. '\n'):gmatch('([^\n]*)\n') do
        if not line:match('^%s*%-%-') then stripped[#stripped + 1] = line end
    end

    local out = {}
    for chunk in table.concat(stripped, '\n'):gmatch('[^;]+') do
        local trimmed = chunk:gsub('^%s+', ''):gsub('%s+$', '')
        if trimmed ~= '' then out[#out + 1] = trimmed end
    end

    return out
end

-- Columns added after the first release. CREATE TABLE IF NOT EXISTS leaves an
-- existing table alone, so anything new has to be added on its own.
local LATER = {
    { table = 'xs_boosting_players', column = 'handle', definition = 'VARCHAR(24) NULL DEFAULT NULL' },
    { table = 'xs_boosting_players', column = 'avatar', definition = 'VARCHAR(255) NULL DEFAULT NULL' },
    { table = 'xs_boosting_players', column = 'tagline', definition = 'VARCHAR(64) NULL DEFAULT NULL' },
    { table = 'xs_boosting_players', column = 'settings', definition = 'TEXT NULL DEFAULT NULL' },
}

local function hasColumn(tableName, column)
    local count = MySQL.scalar.await([[
        SELECT COUNT(*) FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?
    ]], { tableName, column })

    return (tonumber(count) or 0) > 0
end

function Db.Migrate()
    for _, entry in ipairs(LATER) do
        if not hasColumn(entry.table, entry.column) then
            local ok = pcall(function()
                MySQL.query.await(('ALTER TABLE `%s` ADD COLUMN `%s` %s')
                    :format(entry.table, entry.column, entry.definition))
            end)

            if not ok then
                print(('^1[XS-Boosting]^0 could not add %s.%s — add it by hand.')
                    :format(entry.table, entry.column))
            end
        end
    end
end

function Db.Install()
    local queries = statements()

    if not queries then
        print('^1[XS-Boosting]^0 sql/xs_boosting.sql is missing. Import it by hand or nothing will save.')
        return false
    end

    for _, query in ipairs(queries) do
        local ok, err = pcall(function() MySQL.query.await(query) end)
        if not ok then
            print(('^1[XS-Boosting]^0 schema failed: %s'):format(err))
            return false
        end
    end

    Db.Migrate()

    Db.ready = true
    return true
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do Wait(250) end

    if Db.Install() and Config.Debug then
        print('^2[XS-Boosting]^0 schema ready')
    end
end)
