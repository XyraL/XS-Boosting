fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'XS-Boosting'
author 'XyraL'
description 'Standalone vehicle boosting for QBox/QBCore. Tiers, duo runs, a four-man heist, chop shops and an in-game builder.'
version '0.5.7'

-- Works on QBox (qbx_core) OR QBCore (qb-core). The bridge auto-detects.
-- Inventory, target, dispatch and vehicle keys are all auto-detected too and
-- every one of them is optional. See Config.Bridges.
dependencies {
    'ox_lib',
    'oxmysql',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/tiers.lua',
}

client_scripts {
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/target.lua',
    'bridge/dispatch.lua',
    'bridge/keys.lua',
    'bridge/fuel.lua',
    'client/main.lua',
    'client/sound.lua',
    'client/ui.lua',
    -- After main.lua: these read the contract state it owns.
    'client/markers.lua',
    'client/contract.lua',
    'client/theft.lua',
    'client/driver.lua',
    'client/event.lua',
    'client/tracker.lua',
    'client/chop.lua',
    'client/crew.lua',
    'client/telemetry.lua',
    'client/placement.lua',
    'client/builder.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'bridge/framework.lua',
    'bridge/inventory.lua',
    'bridge/dispatch.lua',
    'bridge/keys.lua',
    'server/db.lua',
    'server/store.lua',
    'server/market.lua',
    'server/main.lua',
    'server/unlocks.lua',
    'server/payout.lua',
    'server/contracts.lua',
    'server/jobs.lua',
    'server/crew.lua',
    'server/heist.lua',
    'server/storage.lua',
    'server/event.lua',
    'server/stats.lua',
    'server/net.lua',
    'server/admin.lua',
    'server/commands.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/js/core.js',
    'html/js/mock.js',
    'html/js/avatars.js',
    'html/js/hud.js',
    'html/js/minigames.js',
    'html/js/hack.js',
    'html/js/panels/home.js',
    'html/js/panels/board.js',
    'html/js/panels/job.js',
    'html/js/panels/crew.js',
    'html/js/panels/market.js',
    'html/js/panels/stats.js',
    'html/js/panels/profile.js',
    'html/js/panels/settings.js',
    'html/js/panels/builder.js',
    'html/js/panels/admin.js',
}
