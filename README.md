<h1 align="center">XS-Boosting</h1>

<p align="center">Standalone vehicle boosting for <strong>QBox</strong> and <strong>QBCore</strong>.</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-Boosting/releases"><img src="https://img.shields.io/github/v/release/XyraL/XS-Boosting?style=flat-square&color=55e2ad&label=release" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/framework-QBox%20%7C%20QBCore-55dcff?style=flat-square" alt="framework">
  <img src="https://img.shields.io/badge/status-beta-f5a524?style=flat-square" alt="status: beta">
  <img src="https://img.shields.io/badge/price-free-30d158?style=flat-square" alt="price">
  <a href="https://discord.gg/XRURAw4TM2"><img src="https://img.shields.io/badge/support-discord-5865F2?style=flat-square" alt="support"></a>
</p>

<p align="center">
  <a href="https://github.com/XyraL/XS-Boosting/releases">Releases</a> &nbsp;·&nbsp;
  <a href="https://discord.gg/XRURAw4TM2">Support</a>
</p>

---

> **Beta.** Still being worked on, so expect rough edges. If you hit one, tell
> me on [Discord](https://discord.gg/XRURAw4TM2) and I will get it sorted.

The car is the job.

You get a search area and a description, not a waypoint. You find it, get into
it, deal with whatever is fitted to it, and drive it somewhere. What it is worth
when you get there depends on how you drove.

It ships **empty**. No coordinates from someone else's map, no chop shops of
mine to delete. Every place on your server is one you put there.

The interface is a proper app: a sidebar, an overview page, cards you click,
and six accent colours players pick for themselves. There is a HUD at the edge
of the screen while a contract runs, so the plate and the state of the car are
there without opening anything.



## What it is

**No heat, no hidden timers.** The only thing this resource does with the police
is tell them something happened, through whatever dispatch resource you already
run. Everything else is between you and the car.

**The unit is an item.** There is no `/boost`. If you want boosting on your
server you decide who gets to hold one — sell it at a black market, drop it as
loot, hand it out yourself. Without it in their pocket a player cannot open the
UI, take a contract, or carry on with one they already have.

**Tiers.** Four out of the box, and you can add or rename as many as you like.
Rep unlocks them in order. A tier decides what gets boosted, what it pays, how
hard the car fights back, and how long the clock runs.

**The search.** A contract gives you a zone and a BOLO — model, colour, plate.
The zone is deliberately not centred on the car, so driving to the middle of the
circle finds you nothing. Bigger tiers, bigger zones.

**The theft chain.** Lock, alarm, immobilizer, tracker. Each stage is separately
switchable and separately configurable. Force the lock quietly, or break the
window in two seconds and take the damage and the noise.

Hotwiring is done from the driver's seat, over several rounds, and until it
lands the engine is held off. That hold matters: GTA's own hotwire only delays
the start by a few seconds before the engine catches by itself, and most keys
resources hand an unowned car to whoever sits in it — either way you would
drive off without hotwiring anything. Keys are granted by whichever keys
resource you run, on success, and never before.

Minigames come from whatever you already run — built in, `ox_lib`, `ps-ui`, or
your own export.

**The tracker.** If one is fitted you have a grace window to kill it. Miss it and
the police stop getting one alert and start getting your live position, until
you deal with it.

Killing one is not a skill check. The unit dumps the ECU's address space and you
enter the addresses it asks for, in order, while a trace runs against you. Wrong
address, the trace jumps. Same handshake at the car and at a dead zone — the
only difference is that a dead zone lets you do it without stopping at the car.

**Condition.** Body and engine damage follow the car from the moment you touch
it. Deliver it clean and it pays more than it advertised; wreck it and the buyer
knocks you down, or refuses it.

**Where it goes.** Hand it to the buyer, strip it at a chop shop for parts, or
sell it to a street fence for a bad rate and no rep when a job has gone wrong.

**Crew up first.** You do not have to be on a job to get a crew together. Put
people on the list while you are stood around, and the moment any of you takes
a contract the rest are pulled straight into it — no second round of invites
while the clock is running. The crew survives the job, so the next one needs no
setting up. Up to four, and it feeds the heist as well.

**Duo.** Bring one other person. A passenger can work the tracker while you
drive — from the seat next to you, or from anywhere in the city. On your own you
have to stop and do it yourself.

**The heist.** Two to four of you, several cars out of one showroom, one window.
The police are always told. Switch it off and nothing else changes.

**A live market.** Fence prices drift per tier on a timer. A contract keeps the
rate it was listed at, so a tier that is climbing makes the *next* batch of
listings the ones worth waiting for.

**Unlocks.** Permanent passive buffs earned by doing the work — more time on the
clock, a better cut, a longer fuse on the tracker, a damage buffer, shorter
cooldowns. Nothing is bought and there is no second currency: cross the line and
it is yours. Buffs of the same kind stack, and the whole list is config.

**Profiles.** A handle, a picture and a line under your name — the only things
anybody else sees. Players can point their picture at an image of their own, or
take one of the twelve drawn by the unit itself, so a fresh server has a full
set with nothing to host. A link that fails to load falls back to initials
rather than leaving a hole.

Custom links can be limited to hosts you trust, or switched off entirely, in
`Config.Profile` — worth doing on a public server, since a picture somebody
pastes is shown to everybody who opens a leaderboard.

Character names never appear on the board, the leaderboard or a crew list.
Until somebody picks a handle they show as a stable anonymous tag.

**Some cars are not parked.** A driving target has somebody at the wheel and
is moving around the city, so finding it is a chase rather than a search. Stop
it — ram it, block it, or persuade the driver — and they get out and run. No
alarm, no lock, but the engine dies with them.

**Park it and come back.** A lockup stops the clock mid-contract. Stash a car
you were never going to get away with, come back later, and pick up with the
same time on it.

**Or keep it.** Pay to clean the VIN at a lockup and the car goes into your own
garage instead of being sold. No payout, and it costs you rep, because the
person who ordered it is not getting it.

**Contested contracts.** Every so often one car goes up for everybody at once.
Anyone holding a unit is told, anyone can go for it, armed guards are sitting on
it, and the first one to the drop keeps the money. Nobody else gets anything.
Admins can call one with `/boostevent`, or stop one with `/boostevent stop`.

**Sound.** Cues for every stage, alarm, tracker, payout and near-miss, using
sounds the game already ships — nothing to stream. Players can mute it.

**A HUD while you work.** The plate, the model, the stage, the condition, and
what is fitted to the car — at the edge of the screen, without opening
anything. Alarms going off, trackers going live and the police being called
show up there as they happen. Players choose the side, or turn it off.

**Settings that follow the character.** Accent colour, HUD on or off and which
side, job alerts, framework notifications, in-app messages, and the start-up
animation. All per-character and saved on the server, so it follows a player
between machines.

**Everybody sees a different board.** Boards are per player, so two people
opening a unit at the same moment are not looking at the same six cars and
nobody is racing anybody for a listing. A quiet server never looks empty
because one person took the only good one. The contested server event is the
deliberate exception — that one is shared and meant to be fought over. Set
`Config.Contracts.sharedBoard` for one board for the whole server instead.

**Spawn points rest between jobs.** A spot that has just been used sits out for
a while, so a server with a handful of them does not serve the same street
corner all night and players cannot park next to one and farm it. If every spot
for a tier is resting, one gets used anyway — it never leaves the board empty.

**Everything is built in game.** `/boosting` opens a builder. Walk the map, place
your spawn points, handover points, chop shops, fences, dead zones and heist
sites. Nothing is in the config file.



## Installing

1. Drop `XS-Boosting` in your resources folder.
2. `ensure XS-Boosting` in your server.cfg, after `ox_lib` and `oxmysql`.
3. Start the server once. The tables create themselves — `sql/xs_boosting.sql`
   is there if you would rather import it yourself.
4. Add the items — there is a copy/paste block for ox_inventory and one
   for QBCore below.
5. `/boosting` in game, and start placing.

### Requirements

`ox_lib` and `oxmysql`, plus QBox or QBCore. Everything else is optional and
auto-detected: your inventory, target, dispatch, vehicle keys and fuel resource.

### Items

**Add these to your inventory resource before starting.** Nothing works without
the unit, and the failure is quiet — a player without one simply cannot open
anything. The server prints a warning at start listing any that are missing.

The same blocks are in **`items/ox_inventory.lua`** and **`items/qb_core.lua`**
if you would rather copy from a file than from here.

Once the item exists, `/boostunit` puts one in your pocket so you can test it,
and `/boostunit 12` sends one to that player id.

Only `boosting_unit` is required. The rest are tools the config asks for, and
you can point those at items you already have, or switch them off.

| Item | What it is |
|---|---|
| `boosting_unit` | The unit. Nothing works without it. |
| `lockpick` | Quiet entry. Wears out on `ox_inventory`. Most servers already have one. |
| `boosting_laptop` | Killing trackers. |
| `boosting_toolkit` | Stripping parts. |
| `veh_wheels`, `veh_door`, `veh_bonnet`, `veh_ecu`, `veh_catalyst`, `veh_seats`, `veh_stereo`, `veh_airbag` | What a stripped car gives up. |
| `marked_bills` | Only if you set `Config.Payment.method` to `item`. Point it at whatever your server launders. |

#### ox_inventory

Paste into `ox_inventory/data/items.lua`.

Two lines on the unit are doing real work, and both are easy to leave out:

- **`client.export`** is what makes the item open anything. ox_inventory does
  not use the framework's useable-item system, so without this line the unit is
  a dead object that does nothing at all when used.
- **`consume = 0`** stops the unit being eaten the first time somebody opens
  the board.

```lua
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

['veh_wheels']   = { label = 'Wheels',     weight = 8000, stack = true },
['veh_door']     = { label = 'Door',       weight = 6000, stack = true },
['veh_bonnet']   = { label = 'Bonnet',     weight = 5000, stack = true },
['veh_ecu']      = { label = 'ECU',        weight = 800,  stack = true },
['veh_catalyst'] = { label = 'Catalytic Converter', weight = 2500, stack = true },
['veh_seats']    = { label = 'Seats',      weight = 4000, stack = true },
['veh_stereo']   = { label = 'Head Unit',  weight = 1500, stack = true },
['veh_airbag']   = { label = 'Airbag',     weight = 1000, stack = true },
```

#### QBCore and everything else

Paste into `qb-core/shared/items.lua`. Same list for `qb-inventory`,
`qs-inventory`, `ps-inventory`, `core_inventory` and `codem-inventory` —
they all read this table.

```lua
['boosting_unit']   = { name = 'boosting_unit',   label = 'Boosting Unit',  weight = 1000, type = 'item', image = 'boosting_unit.png',   unique = true,  useable = true,  shouldClose = true,  combinable = nil, description = 'Somebody else\'s contracts, somebody else\'s cars.' },
['boosting_laptop'] = { name = 'boosting_laptop', label = 'Signal Laptop',  weight = 2000, type = 'item', image = 'boosting_laptop.png', unique = true,  useable = false, shouldClose = false, combinable = nil, description = 'Finds the tracker. Kills the tracker.' },
['boosting_toolkit']= { name = 'boosting_toolkit',label = 'Strip Kit',      weight = 3000, type = 'item', image = 'boosting_toolkit.png',unique = true,  useable = false, shouldClose = false, combinable = nil, description = 'Everything you need to take a car apart.' },
['lockpick']        = { name = 'lockpick',        label = 'Lockpick',       weight = 200,  type = 'item', image = 'lockpick.png',        unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Bends. Snaps. Works about as often as not.' },

['veh_wheels']   = { name = 'veh_wheels',   label = 'Wheels',    weight = 8000, type = 'item', image = 'veh_wheels.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_door']     = { name = 'veh_door',     label = 'Door',      weight = 6000, type = 'item', image = 'veh_door.png',     unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_bonnet']   = { name = 'veh_bonnet',   label = 'Bonnet',    weight = 5000, type = 'item', image = 'veh_bonnet.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_ecu']      = { name = 'veh_ecu',      label = 'ECU',       weight = 800,  type = 'item', image = 'veh_ecu.png',      unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_catalyst'] = { name = 'veh_catalyst', label = 'Catalytic Converter', weight = 2500, type = 'item', image = 'veh_catalyst.png', unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_seats']    = { name = 'veh_seats',    label = 'Seats',     weight = 4000, type = 'item', image = 'veh_seats.png',    unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_stereo']   = { name = 'veh_stereo',   label = 'Head Unit', weight = 1500, type = 'item', image = 'veh_stereo.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
['veh_airbag']   = { name = 'veh_airbag',   label = 'Airbag',    weight = 1000, type = 'item', image = 'veh_airbag.png',   unique = false, useable = false, shouldClose = false, combinable = nil, description = 'Off somebody else\'s car.' },
```

No images ship with this. Without a matching PNG in your inventory's image
folder the items still work, they just show a blank square.

Already have a lockpick, or want different names? Every one of these is a config
value — change `Config.Access.item`, `Config.Theft.entry.methods.lockpick.item`,
`Config.Theft.tracker.item`, `Config.Chop.tool.item` and the `item` field on each
`Config.Chop.parts` row instead of adding a duplicate.

### The shortest path to a working server

One **vehicle spawn** tagged with your first tier, and one **handover point**.
That is enough for the board to start listing contracts. Add chop shops, fences,
dead zones and heist sites when you want them.

Place plenty of spawn points. The search is only interesting when the zone has
lots of cars in it.



## Interacting

Everything uses your target resource — `ox_target` or `qb-target`. The car
itself carries the options for forcing the lock, breaking the window, hotwiring,
silencing the alarm, pulling the tracker and stripping parts, and each one only
appears when it actually applies. Chop shops, fences and dead zones are target
zones too.

If you run no target resource at all, the built-in fallback draws a marker and
an `E` prompt instead. That is the only key this resource binds.



## Police

Set `Config.Bridges.dispatch` or leave it on `auto`. It finds `XS-Dispatch`,
`ps-dispatch`, `qs-dispatch`, `cd_dispatch`, `core_dispatch`, `rcore_dispatch`
and `origen_police`. With none of them it falls back to a notification and a blip
for anyone on a police job.

Four alerts, each switchable on its own: the theft, an alarm left sounding, a
live tracker, and someone stripping a car. The live tracker is drawn by this
resource on every police client, because dispatch resources broadcast a fixed
point and forget it.

To make an arrest cost a contract, call this from your police resource when
somebody is booked:

```lua
exports['XS-Boosting']:OnArrested(playerId)
```



## Exports

| Export | Does |
|---|---|
| `GetRep(src)` | That player's rep. |
| `AddRep(src, amount)` | Adds (or removes) rep. |
| `IsBoosting(src)` | Whether they have a contract running. |
| `OnArrested(src)` | Ends their contract and takes the arrest penalty. |

### Commands

| Command | Who | Does |
|---|---|---|
| `/boosting` | Admin | Opens the builder. |
| `/boostevent` | Admin | Starts a contested contract now. `stop` calls one off. |
| `/boostunit` | Admin | Puts a unit in your pocket. `/boostunit 12` sends one to that id. |
| `/boostopen` | Admin | Opens the interface without needing the item, for testing. |
| `/boostplaces` | Admin | Counts what is placed and how much of it is on. `on` switches the lot back on. Works from the server console. |



## Config

`config.lua` is commented throughout. The parts you will touch first:

| Section | For |
|---|---|
| `Config.Tiers` | The ladder. Vehicles, payouts, timers, search radius, difficulty. |
| `Config.Contracts` | Board size, refresh, expiry, cooldowns, daily caps, contract types. |
| `Config.Theft` | The lock, alarm, immobilizer and tracker stages. |
| `Config.Minigames` | Built-in, `ox_lib`, `ps-ui`, or your own export. |
| `Config.Condition` | How damage turns into money. |
| `Config.Disposal` | Buyer, chop shop, street fence. |
| `Config.Crew` / `Config.Duo` / `Config.Heist` | Crewing up, duo work, the heist. All three switch off cleanly. |
| `Config.Police` | Which alerts go out, and whether police must be on duty. |
| `Config.Market` | Price drift, or off for flat rates. |
| `Config.Unlocks` | The buff list. Thresholds, effects, and what each one does. |
| `Config.Stats` | Handles, leaderboard size and what it ranks by. |
| `Config.Profile` | Avatars, taglines, and how far custom picture links are trusted. |
| `Config.Settings` | What a new player starts with, and what they may change. |
| `Config.Events` | Contested contracts: how often, what goes up, and the guards on it. |
| `Config.Contracts.spawnCooldownMinutes` | How long a spawn point rests after being used. |
| `Config.Sound` | Every cue, and which sound plays for it. |
| `Config.Vehicles.driving` | How often a target is being driven, and who is driving it. |
| `Config.Payment` | Cash, bank, or an item you have to launder. |
| `Config.UI` | Accent colour, boot animation, telemetry, units. |



## Licence

See [LICENSE](LICENSE). Use it on your own server, modify it for your own
server, do not redistribute or sell it.
