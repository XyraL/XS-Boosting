-- XS-Boosting — items for qb-core style inventories
--
-- Paste into qb-core/shared/items.lua, inside QBShared.Items.
--
-- Same list for qb-inventory, qs-inventory, ps-inventory, core_inventory and
-- codem-inventory — they all read this table.
--
-- `useable = true` on the unit is the important one: these inventories route a
-- used item through the framework, which this resource already listens for.
-- The other items are carried, not used, so they are all `useable = false`.
--
-- If you run ox_inventory instead, use items/ox_inventory.lua. The two are not
-- interchangeable.
--
-- This is the same block printed in the README. If you change one, change both.

['boosting_unit']    = { name = 'boosting_unit',    label = 'Boosting Unit',       weight = 1000, type = 'item', image = 'boosting_unit.png',    unique = true,  useable = true,  shouldClose = true,  combinable = nil, description = 'Somebody else\'s contracts, somebody else\'s cars.' },
['boosting_laptop']  = { name = 'boosting_laptop',  label = 'Signal Laptop',       weight = 2000, type = 'item', image = 'boosting_laptop.png',  unique = true,  useable = false, shouldClose = false, combinable = nil, description = 'Finds the tracker. Kills the tracker.' },
['boosting_toolkit'] = { name = 'boosting_toolkit', label = 'Strip Kit',           weight = 3000, type = 'item', image = 'boosting_toolkit.png', unique = true,  useable = false, shouldClose = false, combinable = nil, description = 'Everything you need to take a car apart.' },
['lockpick']         = { name = 'lockpick',         label = 'Lockpick',            weight = 200,  type = 'item', image = 'lockpick.png',         unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Bends. Snaps. Works about as often as not.' },

['veh_wheels']   = { name = 'veh_wheels',   label = 'Wheels',              weight = 8000, type = 'item', image = 'veh_wheels.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_door']     = { name = 'veh_door',     label = 'Door',                weight = 6000, type = 'item', image = 'veh_door.png',     unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_bonnet']   = { name = 'veh_bonnet',   label = 'Bonnet',              weight = 5000, type = 'item', image = 'veh_bonnet.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_ecu']      = { name = 'veh_ecu',      label = 'ECU',                 weight = 800,  type = 'item', image = 'veh_ecu.png',      unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_catalyst'] = { name = 'veh_catalyst', label = 'Catalytic Converter', weight = 2500, type = 'item', image = 'veh_catalyst.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_seats']    = { name = 'veh_seats',    label = 'Seats',               weight = 4000, type = 'item', image = 'veh_seats.png',    unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_stereo']   = { name = 'veh_stereo',   label = 'Head Unit',           weight = 1500, type = 'item', image = 'veh_stereo.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_airbag']   = { name = 'veh_airbag',   label = 'Airbag',              weight = 1000, type = 'item', image = 'veh_airbag.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
