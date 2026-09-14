-- XS-Boosting — items for ox_inventory
--
-- Paste into ox_inventory/data/items.lua, inside the table it returns.
--
-- Two lines on the unit are doing real work:
--
--   client.export   ox_inventory does not use the framework's useable-item
--                   system. Without this the unit is a dead object that does
--                   nothing at all when used.
--
--   consume = 0     Without it, using the unit eats it the first time
--                   somebody opens the board.
--
-- This is the same block printed in the README. If you change one, change both.

['boosting_unit'] = {
    label = 'Boosting Unit',
    weight = 1000,
    stack = false,
    close = true,
    consume = 0,
    client = {
        export = 'XS-Boosting.openUnit',
    },
    description = 'Somebody else\'s contracts, somebody else\'s cars.',
},

['boosting_laptop'] = {
    label = 'Signal Laptop',
    weight = 2000,
    stack = false,
    consume = 0,
    description = 'Finds the tracker. Kills the tracker.',
},

['boosting_toolkit'] = {
    label = 'Strip Kit',
    weight = 3000,
    stack = false,
    consume = 0,
    description = 'Everything you need to take a car apart.',
},

['lockpick'] = {
    label = 'Lockpick',
    weight = 200,
    stack = true,
    description = 'Bends. Snaps. Works about as often as not.',
},

-- What a stripped car gives up. Heavy on purpose: you cannot carry a whole
-- car home in one trip.
['veh_wheels']   = { label = 'Wheels',     weight = 8000, stack = true },
['veh_door']     = { label = 'Door',       weight = 6000, stack = true },
['veh_bonnet']   = { label = 'Bonnet',     weight = 5000, stack = true },
['veh_ecu']      = { label = 'ECU',        weight = 800,  stack = true },
['veh_catalyst'] = { label = 'Catalytic Converter', weight = 2500, stack = true },
['veh_seats']    = { label = 'Seats',      weight = 4000, stack = true },
['veh_stereo']   = { label = 'Head Unit',  weight = 1500, stack = true },
['veh_airbag']   = { label = 'Airbag',     weight = 1000, stack = true },
