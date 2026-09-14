Config = {}

-- Force a bridge instead of auto-detecting. 'auto' is almost always right.
Config.Bridges = {
    framework = 'auto',   -- auto | qbox | qbcore
    inventory = 'auto',   -- auto | ox_inventory | qb-inventory | qs-inventory | codem-inventory | core_inventory | ps-inventory
    target    = 'auto',   -- auto | ox_target | qb-target | builtin
    dispatch  = 'auto',   -- auto | XS-Dispatch | ps-dispatch | qs-dispatch | cd_dispatch | core_dispatch | none
    keys      = 'auto',   -- auto | qbx | qb-vehiclekeys | qs-vehiclekeys | custom | none
}

-- No coordinates live in this file. Every chop shop, drop point, dead zone
-- and vehicle spawn is placed in-game with /boosting and stored in the
-- database. This file is the rules those places play by.
--
-- The resource ships empty. Nothing works until you build it.

Config.Debug = false

-- ── Getting in ───────────────────────────────────────────────────────────────
-- The unit is an item and nothing else. There is no command and no key bind
-- for players, by design — if you want boosting on your server, you decide who
-- gets to hold one. Sell it at a black market, drop it as loot, hand it out
-- yourself. Without the item in their pocket a player cannot open the UI,
-- cannot take a contract, and cannot progress one that is already running.
--
-- Admins still have /boosting for the builder. That is the only command in the
-- resource.
Config.Access = {
    item = 'boosting_unit',

    -- Re-check the item is still on the player every this many seconds while
    -- a contract is running. Lose the unit mid-job and the job stops with it.
    -- 0 checks only when the UI is opened.
    checkSeconds = 30,
}

-- Who can open the in-game builder. Any one of these passing is enough.
Config.Admin = {
    acePermission = 'xs.boosting',
    groups        = { 'admin', 'god' },
    licenses      = {},
}

-- ── The builder ──────────────────────────────────────────────────────────────
-- Everything on your map is placed here. Non-admins never get the command or
-- the key registered.
Config.Builder = {
    command = 'boosting',

    -- Metres. How far from yourself you can place a point.
    placementRange = 60.0,

    -- Snap a placed point down to ground height. Off is right almost always:
    -- the placement ray already lands on the surface you are looking at, and
    -- ground height ignores interior floors, so snapping indoors drops the
    -- point through the floor. G toggles it while placing.
    snapToGround = false,

    -- Nudge step in metres when adjusting a placed point with the arrow keys.
    nudgeStep = 0.05,
}

-- ── Tiers ────────────────────────────────────────────────────────────────────
-- The progression spine. A player's rep unlocks tiers in order, and a tier
-- decides what gets boosted, what it pays, how hard the car fights back and
-- how long the clock runs.
--
-- Vehicle models live here because models are the same on every server.
-- WHERE they spawn does not, so spawn points are placed in the builder and
-- tagged with a tier id. Any spawn point tagged 'street' can host any vehicle
-- listed under the 'street' tier.
--
-- Add, remove or rename tiers freely. Order in this table is the unlock order.
Config.Tiers = {
    {
        id    = 'street',
        label = 'Street',
        description = 'Daily drivers. Nobody looks twice.',
        repNeeded = 0,
        repReward = 10,

        -- Multiplies the vehicle payout below. Raise a whole tier without
        -- touching every car in it.
        payoutMultiplier = 1.0,

        cooldownMinutes  = 5,
        timeLimitSeconds = 1200,

        -- Metres. How big the search zone drawn on the map is. Bigger zone,
        -- longer hunt. Nothing points at the car — you get the zone and a
        -- description, and you go look.
        searchRadius = 300.0,

        -- Chance out of 100 that the car has each of these fitted. A car with
        -- no alarm skips the alarm stage entirely, and so on.
        fitted = {
            alarm   = 25,
            tracker = 10,
        },

        -- Feeds the minigame adapter. What the number means depends on which
        -- minigame you run — see Config.Minigames.
        difficulty = {
            lock = 1,
            ecu  = 1,
        },

        vehicles = {
            { model = 'blista',       label = 'Blista',       payout = 900 },
            { model = 'asea',         label = 'Asea',         payout = 850 },
            { model = 'premier',      label = 'Premier',      payout = 1000 },
            { model = 'washington',   label = 'Washington',   payout = 1100 },
            { model = 'regina',       label = 'Regina',       payout = 820 },
            { model = 'ingot',        label = 'Ingot',        payout = 860 },
            { model = 'stanier',      label = 'Stanier',      payout = 980 },
            { model = 'radi',         label = 'Radius',       payout = 1150 },
            { model = 'minivan',      label = 'Minivan',      payout = 890 },
            { model = 'dilettante',   label = 'Dilettante',   payout = 940 },
            { model = 'issi2',        label = 'Issi',         payout = 1050 },
            { model = 'prairie',      label = 'Prairie',      payout = 1080 },
        },
    },
    {
        id    = 'clean',
        label = 'Clean',
        description = 'Cared-for cars with owners who notice.',
        repNeeded = 250,
        repReward = 25,
        payoutMultiplier = 1.0,
        cooldownMinutes  = 8,
        timeLimitSeconds = 1080,
        searchRadius = 350.0,
        fitted = {
            alarm   = 60,
            tracker = 35,
        },
        difficulty = {
            lock = 2,
            ecu  = 2,
        },
        vehicles = {
            { model = 'sultan',       label = 'Sultan',       payout = 2400 },
            { model = 'buffalo',      label = 'Buffalo',      payout = 2600 },
            { model = 'schafter2',    label = 'Schafter',     payout = 2900 },
            { model = 'kuruma',       label = 'Kuruma',       payout = 3100 },
            { model = 'fugitive',     label = 'Fugitive',     payout = 2300 },
            { model = 'tailgater',    label = 'Tailgater',    payout = 2700 },
            { model = 'oracle2',      label = 'Oracle',       payout = 2550 },
            { model = 'jackal',       label = 'Jackal',       payout = 2650 },
            { model = 'sentinel2',    label = 'Sentinel',     payout = 2800 },
            { model = 'baller2',      label = 'Baller',       payout = 3000 },
            { model = 'dominator',    label = 'Dominator',    payout = 3200 },
            { model = 'gauntlet',     label = 'Gauntlet',     payout = 3150 },
            { model = 'sultan2',      label = 'Sultan Custom',payout = 3400 },
            { model = 'rebla',        label = 'Rebla GTS',    payout = 3050 },
        },
    },
    {
        id    = 'exotic',
        label = 'Exotic',
        description = 'Tracked, alarmed, and worth the trouble.',
        repNeeded = 1200,
        repReward = 45,
        payoutMultiplier = 1.0,
        cooldownMinutes  = 12,
        timeLimitSeconds = 900,
        searchRadius = 400.0,
        fitted = {
            alarm   = 85,
            tracker = 70,
        },
        difficulty = {
            lock = 3,
            ecu  = 3,
        },
        vehicles = {
            { model = 'comet2',       label = 'Comet',        payout = 6500 },
            { model = 'sultanrs',     label = 'Sultan RS',    payout = 7200 },
            { model = 'elegy2',       label = 'Elegy',        payout = 6800 },
            { model = 'italigtb',     label = 'Itali GTB',    payout = 9000 },
            { model = 'ninef',        label = 'Nine F',       payout = 6300 },
            { model = 'carbonizzare', label = 'Carbonizzare', payout = 7000 },
            { model = 'feltzer2',     label = 'Feltzer',      payout = 6700 },
            { model = 'jester',       label = 'Jester',       payout = 7400 },
            { model = 'massacro',     label = 'Massacro',     payout = 7600 },
            { model = 'buffalo3',     label = 'Buffalo STX',  payout = 7100 },
            { model = 'schafter3',    label = 'Schafter V12', payout = 7800 },
            { model = 'verlierer2',   label = 'Verlierer',    payout = 8200 },
            { model = 'seven70',      label = 'Seven-70',     payout = 8400 },
            { model = 'specter',      label = 'Specter',      payout = 8800 },
        },
    },
    {
        id    = 'blacklist',
        label = 'Blacklist',
        -- Cars this expensive are rarely left sitting on a kerb.
        drivingChance = 45,
        description = 'Cars that get people killed. Priced accordingly.',
        repNeeded = 4000,
        repReward = 80,
        payoutMultiplier = 1.0,
        cooldownMinutes  = 20,
        timeLimitSeconds = 780,
        searchRadius = 450.0,
        fitted = {
            alarm   = 100,
            tracker = 100,
        },
        difficulty = {
            lock = 4,
            ecu  = 4,
        },
        vehicles = {
            { model = 'zentorno',     label = 'Zentorno',     payout = 14000 },
            { model = 'osiris',       label = 'Osiris',       payout = 15500 },
            { model = 't20',          label = 'T20',          payout = 17000 },
            { model = 'adder',        label = 'Adder',        payout = 18500 },
            { model = 'entityxf',     label = 'Entity XF',    payout = 13500 },
            { model = 'turismor',     label = 'Turismo R',    payout = 14500 },
            { model = 'reaper',       label = 'Reaper',       payout = 15000 },
            { model = 'nero',         label = 'Nero',         payout = 16000 },
            { model = 'vagner',       label = 'Vagner',       payout = 17500 },
            { model = 'tyrant',       label = 'Tyrant',       payout = 18000 },
            { model = 'italirsx',     label = 'Itali RSX',    payout = 16500 },
            { model = 'krieger',      label = 'Krieger',      payout = 19000 },
            { model = 'emerus',       label = 'Emerus',       payout = 19500 },
            { model = 'deveste',      label = 'Deveste Eight',payout = 20000 },
        },
    },
}

-- ── The board ────────────────────────────────────────────────────────────────
-- Contracts are generated by the server and shared by everyone. Two players
-- cannot take the same contract.
Config.Contracts = {
    -- Every player gets their own board. Two people opening a unit at the same
    -- moment see two different sets of work, so nobody is racing anybody for a
    -- listing and a quiet server never looks empty just because one person
    -- took the only good one.
    --
    -- The server event is the deliberate exception and stays shared: that one
    -- is meant to be fought over. See Config.Events.
    --
    -- Switch this on and everybody shares a single board instead, first come
    -- first served, which is how most boosting scripts do it.
    sharedBoard   = false,

    -- How many sit on a board at once, and how often it tops itself back up to
    -- that number.
    boardSize     = 6,
    refreshMinutes = 15,

    -- Minutes a contract stays on the board before it rots away. 0 never
    -- expires.
    expiryMinutes = 45,

    -- Contracts above the player's tier still show on the board, greyed out,
    -- so there is something to work toward. Off hides them completely.
    showLockedTiers = true,

    -- Per player. 0 is unlimited.
    maxActive   = 1,
    dailyLimit  = 0,

    -- Minutes before the same player can take another contract of any tier.
    -- The tier's own cooldownMinutes is applied on top of this.
    globalCooldownMinutes = 2,

    -- Minutes a spawn point sits out after a contract has used it. Without
    -- this, a server with a handful of spawn points ends up serving the same
    -- street corner over and over and players just park next to it.
    --
    -- The clock starts when somebody takes the contract, not when it is
    -- listed. Boards are per player, so resting a spot the moment it appeared
    -- on one would retire the whole map before anybody drove anywhere.
    --
    -- If every spawn for a tier is resting, one gets used anyway rather than
    -- the board going empty — so this never breaks a small server, it just
    -- spreads the work out on a big one. 0 switches it off.
    spawnCooldownMinutes = 25,

    -- Contract types on the board. Every one of these can be switched off and
    -- the rest keep working.
    types = {
        -- Take the car. The whole job.
        standard = {
            enabled = true,
            weight  = 60,       -- relative chance of being rolled onto the board
        },

        -- A named car, a named colour, delivered above a minimum condition.
        --
        -- The colour is how you find it. The buyer tells you the car is black
        -- and the car that spawns is black, so a spec order is the one job
        -- where you can pick your target out of a street full of traffic
        -- instead of checking plates. The bonus is not paid for the colour —
        -- it is paid for bringing it in above minCondition, which is the
        -- whole difficulty of a spec order.
        spec = {
            enabled = true,
            weight  = 25,
            bonusPct = 35,

            -- Condition percent the vehicle must arrive at for the bonus.
            -- Below it the car is still bought, just at the normal rate.
            minCondition = 80,

            -- Colours a spec order can ask for. Name is what the player is
            -- told; index is the GTA colour the vehicle actually spawns in.
            colours = {
                { name = 'Black',   index = 0 },
                { name = 'White',   index = 111 },
                { name = 'Red',     index = 27 },
                { name = 'Blue',    index = 64 },
                { name = 'Silver',  index = 4 },
                { name = 'Green',   index = 55 },
                { name = 'Orange',  index = 38 },
                { name = 'Yellow',  index = 88 },
            },
        },

        -- Bring parts, not a car. Strip the vehicle where it stands and carry
        -- the pieces back. See Config.Chop.
        chop = {
            enabled = true,
            weight  = 15,

            -- How many distinct parts a chop contract asks for.
            partsRequired = { min = 2, max = 4 },
        },
    },
}

-- ── Taking the car ───────────────────────────────────────────────────────────
-- The theft chain. Each stage runs in order, and each one can be switched off
-- on its own — turn them all off and the car is simply unlocked and drivable.
Config.Theft = {
    -- Stage 1. Getting the door open.
    entry = {
        enabled = true,

        -- Which methods players may use. At least one must stay enabled.
        methods = {
            -- Quiet, slow, needs a tool, the tool wears out.
            lockpick = {
                enabled  = true,
                item     = 'lockpick',
                consume  = false,        -- true removes the item on use
                durability = 12,         -- percent lost per use, ox_inventory only
                seconds  = 8,
                -- Failing the minigame costs this much time before a retry.
                failPenaltySeconds = 4,
                -- Chance out of 100 that a failure sets the alarm off, if the
                -- car has one fitted.
                failAlarmChance = 40,
            },

            -- Fast, loud, damages the car, needs nothing.
            smash = {
                enabled = true,
                seconds = 2,
                -- Condition percent removed for breaking the window. Spec
                -- orders usually cannot afford this.
                conditionCost = 15,
                -- A smashed window always wakes the alarm if one is fitted.
                alwaysAlarms = true,
            },
        },
    },

    -- Stage 2. The alarm, if the car has one and something set it off.
    -- Silencing it is a race; letting it run tells the police where you are.
    alarm = {
        enabled = true,
        seconds = 6,
        -- Seconds the alarm may sound before dispatch is notified. Silence it
        -- inside this window and nobody hears about it.
        graceSeconds = 12,
        -- Radius in metres that nearby NPC peds react and flee.
        pedReactRadius = 30.0,
    },

    -- Stage 3. Starting it.
    --
    -- Done from the driver's seat, not stood at the window: get in, hold E,
    -- and work through it. Succeed and the keys are yours.
    hotwire = {
        enabled = true,
        seconds = 10,
        failPenaltySeconds = 5,

        -- How many times you have to get it right. One is a coin flip, which
        -- is why it was not one. Every round has to land; miss any of them and
        -- the whole attempt is lost.
        rounds = 3,

        -- Attempts before the contract fails outright. 0 is unlimited.
        maxAttempts = 0,
    },

    -- Stage 4. The tracker, if fitted. This is the only thing in the resource
    -- that changes what the police get. See Config.Police.
    tracker = {
        enabled = true,
        seconds = 12,
        -- Item needed to attempt it at all. Empty string needs nothing.
        item    = 'boosting_laptop',
        consume = false,
        -- Seconds after the engine starts before the tracker begins
        -- broadcasting. Kill it inside this window and the police only ever
        -- get the one-off theft alert.
        graceSeconds = 45,
        -- The tracker can also be killed later, on the move, at a dead zone
        -- placed in the builder. Off means it is now or never.
        deadZonesAllowed = true,

        -- Killing a tracker is not a skill check. It is a handshake with the
        -- ECU: the unit dumps its address space, you enter the addresses it
        -- asks for in the order it asks for them, and a trace runs the whole
        -- time. Same sequence at the car and at a dead zone.
        --
        -- Difficulty is the tier's `ecu` number.
        hack = {
            -- Grid is gridBase + difficulty per side, capped at 6.
            gridBase = 3,
            -- Addresses to enter is codesBase + difficulty, capped at 6.
            codesBase = 1,
            -- Seconds before the trace lands, at difficulty 1.
            seconds = 22,
            -- Added per difficulty level above 1. Negative tightens it.
            secondsPerLevel = -3,
            -- Seconds of trace a wrong address costs.
            penaltySeconds = 3,
        },
    },
}

-- ── Minigames ────────────────────────────────────────────────────────────────
-- Which minigame each stage runs. 'builtin' uses the ones drawn by this
-- resource's own UI, which is the only option that needs nothing installed.
--
-- 'custom' calls your own export. It is handed (difficulty, stage) and must
-- return true or false. Anything that returns a boolean works.
-- The tracker is not listed here. It always runs the ECU handshake above,
-- because that is the mechanic rather than a difficulty dial.
Config.Minigames = {
    entry   = 'builtin',   -- builtin | ox_lib | ps-ui | custom
    hotwire = 'builtin',
    chop    = 'builtin',

    -- Only read when a stage above is set to 'custom'.
    custom = function(difficulty, stage)
        return exports['my-minigames']:Run(stage, difficulty)
    end,

    -- Only read when a stage above is set to 'ox_lib'. Difficulty is the
    -- number from the tier. Return whatever lib.skillCheck accepts.
    oxLib = function(difficulty, stage)
        local levels = {
            [1] = { 'easy', 'easy' },
            [2] = { 'easy', 'medium' },
            [3] = { 'medium', 'medium', 'hard' },
            [4] = { 'medium', 'hard', 'hard' },
        }
        return levels[difficulty] or levels[1]
    end,
}

-- ── Condition ────────────────────────────────────────────────────────────────
-- What the car arrives in decides a chunk of what it pays. This is the reason
-- to drive well instead of hammering it across the city.
Config.Condition = {
    enabled = true,

    -- Condition starts at 100 and comes off as the car takes damage. These
    -- weights decide how much each kind of damage matters.
    weights = {
        body   = 1.0,
        engine = 1.0,
    },

    -- Payout scale. Condition at or above `at` pays `pct` of the base. Between
    -- two entries the value is interpolated, so a car at 85 pays somewhere
    -- between the 90 and 75 rows. Keep it sorted high to low.
    scale = {
        { at = 100, pct = 115 },
        { at = 90,  pct = 100 },
        { at = 75,  pct = 88 },
        { at = 50,  pct = 65 },
        { at = 25,  pct = 40 },
        { at = 0,   pct = 20 },
    },

    -- Below this the buyer refuses it outright and the contract fails.
    refuseBelow = 15,

    -- Condition percent lost when the vehicle is flipped onto its roof.
    rolloverCost = 10,
}

-- ── Selling it ───────────────────────────────────────────────────────────────
-- Where a finished car goes. Every route is a point you place in the builder,
-- and every route can be switched off here.
Config.Disposal = {
    -- The contract's own buyer. Pays what the contract said it would.
    -- This is the default route and the only one a spec order accepts.
    buyer = {
        enabled = true,
        -- Metres the vehicle must be brought within.
        radius = 12.0,
        -- Seconds the player must stand clear before the handover completes.
        handoverSeconds = 5,

        -- Somebody has to actually take it off you. The buyer turns up at the
        -- handover point while you are on your way, and goes home with the car
        -- afterwards. You talk to them, not to a marker on the floor.
        ped = {
            enabled = true,
            model = 'g_m_y_lost_01',
            -- An idle animation so they are not stood to attention. Leave it
            -- empty for nothing.
            scenario = 'WORLD_HUMAN_SMOKING',
        },

        -- Seconds before the handed-over car disappears. The buyer walks off
        -- the moment the job ends, so anything longer than about a second
        -- leaves the car parked there with nobody stood next to it, which
        -- reads as the handover not having worked.
        --
        -- Not 0: whoever is still sat in it is put out first, and that needs a
        -- moment to reach them. Raise it if you want to watch it drive off.
        despawnSeconds = 1,
    },

    -- Strip it for parts instead of selling it whole. Always available on a
    -- chop contract; on any other contract this is the bail-out option.
    chopShop = {
        enabled = true,
        radius  = 10.0,
        -- Percent of the contract payout you get for chopping a car that was
        -- meant to be sold whole. Deliberately worse than the buyer.
        bailoutPct = 55,
    },

    -- A lockup does two things, and both are switchable on their own.
    --
    -- Stashing parks a car mid-contract and stops the clock. Come back for it
    -- later and you pick up exactly where you left off, with the same time on
    -- it. It is how you survive a chase you were not going to win.
    --
    -- Keeping is permanent: pay the fee and the car goes into your own garage
    -- instead of being sold. You get no payout and it costs you rep, because
    -- nobody who ordered it is getting paid either.
    lockup = {
        enabled = true,
        radius  = 10.0,

        stash = {
            enabled = true,
            -- Cars one player may have parked at once. 0 is unlimited.
            slots = 2,
            -- Minutes a stashed car is held before it is gone for good.
            -- 0 holds it forever.
            holdMinutes = 0,
            seconds = 5,
        },

        keep = {
            enabled = true,
            -- What cleaning it costs. Taken from the account below.
            fee = 25000,
            account = 'bank',
            -- Rep this costs you. The buyer is not getting their car.
            repPenalty = 60,
            -- Condition it has to be in before anyone will touch the VIN.
            minCondition = 50,
            -- Which garage it lands in.
            garage = 'legion',
            seconds = 12,
        },
    },

    -- A no-questions fence. Instant, bad rate, takes anything at any
    -- condition, ignores the contract entirely. The way out of a job gone
    -- wrong.
    fence = {
        enabled = true,
        radius  = 8.0,
        payPct  = 35,
        -- No rep for selling to the fence, and optionally lose some.
        repPenalty = 5,
    },
}

-- ── Chopping ─────────────────────────────────────────────────────────────────
-- Stripping a car for parts, either as the contract itself or as a bail-out.
Config.Chop = {
    -- Seconds to pull one part off.
    partSeconds = 9,

    -- Condition the car loses per part removed. A half-stripped car is worth
    -- very little to anyone else.
    conditionCostPerPart = 18,

    -- Parts a car can give up. `item` must exist in your inventory resource.
    --
    -- Pulling a part puts the item in your pocket. Handing the job in at a
    -- chop shop takes those items back and pays `value` for each one you
    -- actually still have, on top of the contract itself. Walk away with them
    -- instead and you keep the parts but not the money.
    parts = {
        { id = 'wheels',   label = 'Wheels',        item = 'veh_wheels',   value = 220 },
        { id = 'doors',    label = 'Doors',         item = 'veh_door',     value = 180 },
        { id = 'bonnet',   label = 'Bonnet',        item = 'veh_bonnet',   value = 150 },
        { id = 'ecu',      label = 'ECU',           item = 'veh_ecu',      value = 400 },
        { id = 'catalyst', label = 'Catalytic',     item = 'veh_catalyst', value = 320 },
        { id = 'seats',    label = 'Seats',         item = 'veh_seats',    value = 140 },
        { id = 'stereo',   label = 'Head Unit',     item = 'veh_stereo',   value = 120 },
        { id = 'airbags',  label = 'Airbags',       item = 'veh_airbag',   value = 260 },
    },

    -- Tool needed to strip anything.
    tool = {
        item    = 'boosting_toolkit',
        consume = false,
        durability = 8,
    },

    -- What happens to the shell once it is stripped. 'delete' cleans it up,
    -- 'burn' sets it on fire first, 'leave' leaves it sitting there.
    shell = 'burn',
}

-- ── Standing crew ────────────────────────────────────────────────────────────
-- A crew you put together before anybody takes anything on. Nobody has to be
-- on a job to form one, and when one of you takes a contract the rest are
-- pulled straight into it — no second round of invites while the clock runs.
--
-- The crew outlives the job. Finish one, take the next, same people.
Config.Crew = {
    enabled = true,

    -- The most people in one crew, you included. A normal contract still only
    -- takes as many as Config.Duo allows into the job itself, so on a crew of
    -- four the other two sit that one out. The heist takes the lot, up to
    -- Config.Heist.crewSize.max.
    maxSize = 4,

    -- Metres. How close somebody has to be standing to be asked.
    inviteRadius = 8.0,

    -- Seconds an invite waits before it lapses.
    inviteTimeout = 30,

    -- Pull the crew into a contract the moment one of you takes it. Off, and a
    -- crew is only a list of people to invite quickly once a job is running.
    autoJoin = true,

    -- Metres a crew member may be from whoever took the contract and still be
    -- pulled in. 0 lets them join from anywhere in the city, which is usually
    -- what you want — the partner is meant to be able to work remotely.
    joinRadius = 0,

    -- Keep the crew together once a job ends. Off breaks it up every time and
    -- makes it a per-job thing.
    keepAfterJob = true,
}

-- ── Duo ──────────────────────────────────────────────────────────────────────
-- Two players on one contract. The holder of the contract invites someone
-- standing near them; both need a unit of their own.
--
-- Duo is not just a second pair of hands. The passenger works the unit while
-- the driver drives — the tracker stage can be run from the passenger seat, or
-- from anywhere in the city, while the car is already moving. Solo, you have
-- to stop and do it yourself.
Config.Duo = {
    enabled = true,

    -- Metres. How close the invite target has to be standing.
    inviteRadius = 6.0,

    -- Seconds an invite waits before it lapses.
    inviteTimeout = 30,

    -- Percent added to the payout before it is split. Set to 0 and a duo is
    -- purely a convenience.
    payoutBonusPct = 20,

    -- How the money lands. 'split' divides it, 'full' pays both the whole
    -- amount, 'holder' pays only the player who took the contract.
    payoutMode = 'split',

    -- Rep is never split. Both players get the tier's full repReward.
    -- Set false to give rep only to the contract holder.
    repBoth = true,

    -- Let the partner run the tracker stage remotely, away from the vehicle.
    -- This is the main reason to bring someone.
    remoteTracker = true,

    -- Seconds added to the tier time limit when a contract is run as a duo.
    -- Negative values take time away instead.
    timeBonusSeconds = 0,
}

-- ── The heist ────────────────────────────────────────────────────────────────
-- One big job, up to four people, several cars out of one place in a single
-- window. Switch it off and the rest of the resource is untouched.
Config.Heist = {
    enabled = true,

    crewSize = { min = 2, max = 4 },

    -- Rep the player starting it needs. Crew members are not checked.
    repNeeded = 2000,

    -- Minutes before the same crew leader can start another one.
    cooldownMinutes = 90,

    -- Server-wide. Only this many heists may run at once across everyone.
    -- 0 is unlimited.
    concurrent = 1,

    -- Cars to take, and how long the whole crew has to take them.
    vehicleCount = { min = 3, max = 4 },
    timeLimitSeconds = 1500,

    -- Which tier the heist pulls its vehicles from.
    tier = 'exotic',

    -- Percent on top of the combined vehicle payouts, paid once the last car
    -- lands. Bail out early and nobody sees this.
    completionBonusPct = 60,

    payoutMode = 'split',    -- split | full

    -- Rep for each crew member on a completed heist.
    repReward = 150,

    -- Police are always told about a heist the moment the first car moves,
    -- whatever the tracker situation is. Teamwork does not get to be quiet.
    alwaysAlertsPolice = true,

    -- Minimum police on duty before a heist can be started. 0 disables the
    -- check. Solo contracts use Config.Police.required instead.
    policeRequired = 2,

    -- Every car has to leave through the same exit point, placed in the
    -- builder alongside the heist location.
    exitRadius = 15.0,
}

-- ── Police ───────────────────────────────────────────────────────────────────
-- The only thing this resource tells the police is that something happened
-- and roughly where. There is no heat, no wanted level and no hidden timer.
-- Everything below goes out through the dispatch bridge to whatever PD
-- resource you already run.
Config.Police = {
    -- Minimum officers on duty before a contract can be taken at all.
    -- 0 disables the check.
    required = 0,

    -- Jobs that count as police for that check.
    jobs = { 'police', 'sheriff', 'sasp' },

    -- Each alert can be switched off on its own.
    alerts = {
        -- The car was taken. Fires once, at the location of the theft.
        theft = {
            enabled = true,
            -- Seconds after the engine starts before it goes out.
            delaySeconds = 0,
        },

        -- An alarm was left sounding past its grace window.
        alarm = {
            enabled = true,
        },

        -- A live tracker. This is the expensive one — the police get the
        -- vehicle's position updated continuously until the tracker is
        -- killed at a dead zone or the contract ends.
        tracker = {
            enabled = true,
            updateSeconds = 20,
            -- Minutes the live feed runs before it gives up on its own.
            -- 0 runs until the contract ends.
            maxMinutes = 10,
        },

        -- Someone is stripping a car. Fires when the first part comes off.
        chop = {
            enabled = true,
            -- Chance out of 100 that it is reported at all. Chop shops are
            -- meant to be somewhere quiet.
            chance = 35,
        },
    },
}

-- ── Getting paid ─────────────────────────────────────────────────────────────
Config.Payment = {
    -- 'cash', 'bank', or 'item' to pay in something you have to launder.
    method  = 'cash',
    account = 'cash',

    -- Only read when method is 'item'.
    item = {
        name = 'marked_bills',
        -- Money per one item handed over. The payout is divided by this and
        -- rounded down, so a 6500 payout at 500 each is 13 items.
        worth = 500,
    },

    -- Rounds every payout to the nearest this. 1 pays exact amounts.
    roundTo = 10,
}

-- ── Rep ──────────────────────────────────────────────────────────────────────
-- The one number that matters. Rep unlocks tiers, the heist, and nothing else.
-- It is per-character and never resets on its own.
Config.Rep = {
    -- Rep lost when a contract fails. A failed contract is one that ran out
    -- of time, had its vehicle destroyed, or was abandoned.
    failPenalty = 15,

    -- Rep lost when a player is arrested while holding an active contract.
    -- Needs your PD resource to fire the export; see the README. 0 ignores it.
    arrestPenalty = 40,

    -- Rep can never go below this.
    floor = 0,
}

-- ── The market ───────────────────────────────────────────────────────────────
-- Fence prices move. Every tier has a multiplier that drifts on a timer, so
-- what is worth taking changes through the day. The board shows it live.
Config.Market = {
    enabled = true,

    -- Minutes between shifts.
    shiftMinutes = 45,

    -- The multiplier stays inside this range.
    range = { min = 0.75, max = 1.4 },

    -- Most a single shift can move a tier, up or down.
    maxStep = 0.15,

    -- A contract keeps the rate it was listed at for its whole life, so a
    -- shift only changes what appears on the board afterwards.
}

-- ── Setups ───────────────────────────────────────────────────────────────────
-- A share of contracts are police stings. The board cannot tell you which.
-- You find out when you touch the car.
Config.Sting = {
    enabled = false,

    -- Chance out of 100 per contract taken.
    chance = 8,

    -- Higher tiers are worth setting a trap for.
    tierChance = {
        street    = 2,
        clean     = 6,
        exotic    = 10,
        blacklist = 18,
    },

    -- What happens when it springs. The contract fails, the police are told
    -- immediately, and the car is unusable.
    disableVehicle = true,

    -- Rep lost for walking into one. Set 0 to make stings cost nothing but
    -- the time.
    repPenalty = 0,
}

-- ── The cars ─────────────────────────────────────────────────────────────────
Config.Vehicles = {
    -- Some cars are not parked. A driving target has somebody at the wheel
    -- and is moving around the city, so finding it is a chase rather than a
    -- search — you have to stop it before you can take it.
    --
    -- A driving car skips the lock, because the door is open the moment the
    -- driver gets out, and it never has an alarm. The engine dies with the
    -- driver, so you still have to hotwire it.
    driving = {
        enabled = true,

        -- Chance out of 100 that any given contract is a driving one. A tier
        -- can override this with its own `drivingChance`.
        chance = 20,

        -- Who is behind the wheel. One is picked at random.
        drivers = { 'a_m_m_business_01', 'a_m_y_business_02', 'a_f_y_business_02', 'a_m_m_eastsa_02' },

        -- The driver gives up and runs when the car has taken this much
        -- damage, or when it has been stopped for `stoppedSeconds`.
        bailAtDamage = 250,
        stoppedSeconds = 4,

        -- How fast they drive, and how carefully. See the driving style flags
        -- for GTA's TaskVehicleDriveWander; 786603 is normal traffic.
        speed = 18.0,
        style = 786603,
    },

    -- Metres from any player before a target vehicle is spawned in. Below
    -- this it waits, so nobody watches a car appear out of nothing.
    spawnDistance = 180.0,

    -- Seconds a target vehicle survives after its contract ends.
    cleanupSeconds = 60,

    -- Plate format. # is a digit, ? is a letter. Plates are checked for
    -- collisions against owned vehicles before use.
    plateFormat = '##???###',

    -- Fuel level target vehicles spawn with, as a percent. Supports
    -- ox_fuel, LegacyFuel, ps-fuel and cdn-fuel; ignored if none are running.
    fuel = { min = 25, max = 70 },

    -- Give the player keys to the vehicle once it is started, through the
    -- keys bridge. Off leaves it to your own keys resource.
    giveKeys = true,

    -- Dirt, and a little wear, so a target car does not look showroom fresh.
    dirtLevel = { min = 2.0, max = 8.0 },
}

-- ── Blips and markers ────────────────────────────────────────────────────────
Config.Blips = {
    -- The search zone. This is a radius blip, not a pin — it tells you the
    -- area, never the car.
    searchZone = {
        sprite = 1,
        colour = 47,
        alpha  = 90,
    },

    -- Where the car goes.
    dropoff = {
        sprite = 225,
        colour = 5,
        scale  = 0.9,
        label  = 'Handover',
    },

    chopShop = {
        enabled = true,
        sprite  = 380,
        colour  = 49,
        scale   = 0.8,
        label   = 'Chop Shop',
        -- Only show it to players who have found it once already.
        discoveredOnly = true,
    },

    lockup = {
        enabled = true,
        sprite  = 357,
        colour  = 40,
        scale   = 0.8,
        label   = 'Lockup',
        discoveredOnly = true,
    },
}

-- ── Stats ────────────────────────────────────────────────────────────────────
Config.Stats = {
    -- Nobody's character name goes on the leaderboard. A player picks a handle
    -- from the unit, and until they do they show as an anonymous tag worked
    -- out from their character id — stable, but not traceable to a name.
    --
    -- Set enabled = false to put real character names back on it.
    handles = {
        enabled   = true,
        minLength = 3,
        maxLength = 18,
        -- Letters, numbers, spaces and . _ - only. Anything else is refused.
        -- Two players cannot hold the same handle.
        unique    = true,
    },

    -- Rows on the leaderboard.
    leaderboardSize = 15,

    -- What the leaderboard ranks by. 'completed', 'earned', or 'rep'.
    leaderboardBy = 'completed',

    -- Entries kept in a player's own history.
    historyLimit = 25,
}

-- ── The unit ─────────────────────────────────────────────────────────────────
-- Look and feel of the NUI itself.
Config.UI = {
    -- The accent colour is a player setting, not a server one. Set what new
    -- players start with in Config.Settings.defaults.theme.

    -- Server-wide kill switch for the start-up animation. Players can also
    -- turn it off for themselves; off here wins either way.
    bootSequence = true,

    -- Show the live speed and condition readout while a contract is running.
    telemetry = true,

    -- 'metric' or 'imperial' for the speed readout.
    units = 'metric',

    -- Let the player close the unit with ESC as well as the close button.
    escToClose = true,
}

-- ── Unlocks ──────────────────────────────────────────────────────────────────
-- Passive buffs you earn by doing the work, not by spending anything. There is
-- no shop and no second currency: cross the line and it is yours for good.
--
-- `requires.type` is one of: completed, chopped, heists, rep, earned.
--
-- `buff.type` is one of:
--   payout_pct       +value% on every payout
--   time_bonus       +value seconds on the contract clock
--   tracker_grace    +value seconds before a tracker starts broadcasting
--   alarm_grace      +value seconds before a sounding alarm is reported
--   cooldown_pct     -value% off the cooldown between contracts
--   condition_buffer the first value% of damage is ignored at settlement
--   duo_pct          +value% more on top when the job was run as a duo
--   fence_pct        +value% on what the street fence pays
--
-- Buffs of the same type stack. Add, remove or retune freely — the list is
-- read live, so a player who already qualifies gets a new one immediately.
Config.Unlocks = {
    enabled = true,

    list = {
        { id = 'steady_hands', label = 'Steady Hands',
          description = 'Ten jobs in and you stop rushing.',
          effect = '+60s on every contract',
          requires = { type = 'completed', value = 10 },
          buff = { type = 'time_bonus', value = 60 } },

        { id = 'known_face', label = 'A Known Face',
          description = 'People have started asking for you.',
          effect = '+8% on every payout',
          requires = { type = 'completed', value = 25 },
          buff = { type = 'payout_pct', value = 8 } },

        { id = 'light_touch', label = 'Light Touch',
          description = 'Fifty deliveries teaches you where the kerbs are.',
          effect = 'First 10% of damage ignored',
          requires = { type = 'completed', value = 50 },
          buff = { type = 'condition_buffer', value = 10 } },

        { id = 'quiet_type', label = 'The Quiet Type',
          description = 'You know which wire goes first.',
          effect = '+15s before an alarm is called in',
          requires = { type = 'completed', value = 75 },
          buff = { type = 'alarm_grace', value = 15 } },

        { id = 'old_hand', label = 'Old Hand',
          description = 'A hundred cars. Nobody teaches that.',
          effect = '+12% on every payout',
          requires = { type = 'completed', value = 100 },
          buff = { type = 'payout_pct', value = 12 } },

        { id = 'grease', label = 'Grease Under The Nails',
          description = 'You have taken enough of them apart.',
          effect = '-20% cooldown between contracts',
          requires = { type = 'chopped', value = 20 },
          buff = { type = 'cooldown_pct', value = 20 } },

        { id = 'no_questions', label = 'No Questions',
          description = 'The fence stopped haggling with you.',
          effect = '+15% on street fence sales',
          requires = { type = 'chopped', value = 40 },
          buff = { type = 'fence_pct', value = 15 } },

        { id = 'signal_sense', label = 'Signal Sense',
          description = 'You can hear a tracker before you see it.',
          effect = '+20s before a tracker goes live',
          requires = { type = 'rep', value = 800 },
          buff = { type = 'tracker_grace', value = 20 } },

        { id = 'ghost_line', label = 'Ghost Line',
          description = 'Whatever it is you do, it works.',
          effect = '+25s before a tracker goes live',
          requires = { type = 'rep', value = 2500 },
          buff = { type = 'tracker_grace', value = 25 } },

        { id = 'crew_cut', label = 'Crew Cut',
          description = 'You are worth bringing along.',
          effect = '+10% more when you run it as a duo',
          requires = { type = 'heists', value = 3 },
          buff = { type = 'duo_pct', value = 10 } },

        { id = 'the_name', label = 'The Name',
          description = 'Half a million through your hands.',
          effect = '+15% on every payout',
          requires = { type = 'earned', value = 500000 },
          buff = { type = 'payout_pct', value = 15 } },
    },
}

-- ── Profiles ─────────────────────────────────────────────────────────────────
-- A player's profile is the only thing about them anybody else sees. Their
-- character name never appears on the board, the leaderboard or a crew list.
Config.Profile = {
    -- Characters allowed under a handle, shown beneath it on the profile.
    -- 0 switches taglines off entirely.
    taglineMax = 48,

    -- The unit ships with a set of drawn-in avatars that need no hosting and
    -- nothing to moderate. This is how many of them there are; only raise it
    -- if you have added more to html/js/avatars.js.
    builtinCount = 12,

    -- Let players point their avatar at an image of their own.
    --
    -- Worth knowing what you are turning on: whatever a player pastes here is
    -- shown to everybody who opens a leaderboard, and nothing about it is
    -- checked beyond the rules below — not what it is a picture of, and not
    -- how big the file is. Switch it off and they pick from the built-in set,
    -- and there is nothing to police.
    --
    -- Links must be http(s), must carry no username or port, and are dropped
    -- back to the player's initials if they fail to load.
    allowCustomImages = true,

    -- Only used when allowCustomImages is on. Empty allows any host; listing
    -- hosts restricts it to those, which is the sane way to run a public
    -- server — point it at an image host you control or one you trust.
    allowedHosts = {
        -- 'i.imgur.com',
        -- 'cdn.discordapp.com',
    },

    -- Longest a custom image link may be.
    maxUrlLength = 250,
}

-- ── Player settings ──────────────────────────────────────────────────────────
-- Each player gets their own copy of these, changed from the Settings screen
-- and saved against their character. What you set here is what a brand new
-- player starts with.
Config.Settings = {
    defaults = {
        -- blue | ice | violet | emerald | amber | crimson
        theme = 'blue',

        -- The panel at the edge of the screen while a contract runs.
        hud = true,
        hudSide = 'left',   -- left | right

        -- Alarms, trackers going live, police being called. Shown on the HUD.
        alerts = true,

        -- Your framework's own corner notifications.
        notify = true,

        -- The small confirmations inside the interface itself.
        toasts = true,

        -- The short loading sequence when the unit is opened.
        boot = true,

        -- Cues while working a car, and clicks in the interface.
        sounds = true,
    },

    -- Players may not change anything that is not listed here, and a value
    -- outside its allowed set is refused rather than stored.
    allowed = {
        theme   = { 'blue', 'ice', 'violet', 'emerald', 'amber', 'crimson' },
        hudSide = { 'left', 'right' },
        hud     = 'boolean',
        alerts  = 'boolean',
        notify  = 'boolean',
        toasts  = 'boolean',
        boot    = 'boolean',
        sounds  = 'boolean',
    },
}

-- ── Sound ────────────────────────────────────────────────────────────────────
-- Every cue is a sound GTA already ships, so there is nothing to stream and
-- nothing to add to your server. Set a cue to false to silence just that one,
-- or turn `enabled` off for the lot. Players can also mute it for themselves.
--
-- `set` is the sound set and `name` is the sound inside it. If you want to
-- swap one, any pair that works with PlaySoundFrontend works here.
Config.Sound = {
    enabled = true,

    cues = {
        open        = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'SELECT' },
        close       = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'BACK' },
        accept      = { set = 'HUD_FRONTEND_DEFAULT_SOUNDSET', name = 'SELECT' },

        -- Working the car
        stage       = { set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS', name = 'Hacking_Click' },
        win         = { set = 'HUD_MINI_GAME_SOUNDSET',         name = 'CHECKPOINT_PERFECT' },
        fail        = { set = 'HUD_MINI_GAME_SOUNDSET',         name = 'CHECKPOINT_MISSED' },
        hackWin     = { set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS', name = 'Hacking_Success' },
        hackFail    = { set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS', name = 'Hacking_Failed' },

        -- Things going wrong
        alarm       = { set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', name = 'Beep_Red' },
        tracker     = { set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', name = 'Beep_Red' },
        police      = { set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS', name = 'Beep_Red' },

        -- The clock running out from under you
        timeLow     = { set = 'HUD_MINI_GAME_SOUNDSET', name = '5_SEC_WARNING' },

        -- Finishing
        paid        = { set = 'HUD_AWARDS',                          name = 'RANK_UP' },
        lost        = { set = 'DLC_HEISTS_GENERAL_FRONTEND_SOUNDS',  name = 'Mission_Fail' },
        unlock      = { set = 'HUD_AWARDS',                          name = 'RANK_UP' },
        part        = { set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS',      name = 'Hacking_Click' },

        -- A contested contract going up for grabs
        event       = { set = 'GTAO_FM_Events_Soundset', name = 'OOB_Start' },
    },

    -- Seconds left when the clock starts warning you. 0 never warns.
    timeWarningAt = 60,
}

-- ── Contested contracts ──────────────────────────────────────────────────────
-- Every so often one car goes up for everybody at once. Anyone holding a unit
-- is told about it, anyone can go for it, and the first one to get it to the
-- drop keeps the money. Nobody else gets anything.
--
-- There is no search zone on these. Everyone is given the exact spot, because
-- the difficulty is the other players, not the finding. Armed guards sit on it
-- until somebody moves them.
Config.Events = {
    enabled = true,

    -- Minutes between them, give or take `variance`. Set everyMinutes to 0
    -- and they only happen when an admin calls one with /boostevent.
    everyMinutes = 90,
    varianceMinutes = 20,

    -- Not worth contesting with nobody around.
    minPlayers = 4,

    -- Officers on duty before one can start. 0 disables the check.
    policeRequired = 0,

    -- How long the whole thing stays up for before it is written off.
    windowSeconds = 1500,

    -- Which tier's spawn points it uses for somewhere to put the car.
    spawnTier = 'blacklist',

    -- What goes up. One is picked at random.
    vehicles = {
        { model = 'zentorno', label = 'Zentorno', payout = 42000 },
        { model = 't20',      label = 'T20',      payout = 48000 },
        { model = 'adder',    label = 'Adder',    payout = 45000 },
        { model = 'osiris',   label = 'Osiris',   payout = 40000 },
    },

    -- Rep for whoever gets it home.
    repReward = 140,

    -- The car is worth guarding. These are hostile the moment you get close.
    guards = {
        enabled = true,
        count = 4,
        radius = 8.0,
        model = 'g_m_m_armboss_01',
        weapon = 'WEAPON_CARBINERIFLE',
        -- 0 to 100. Anything above 60 is unpleasant.
        accuracy = 45,
        armour = 100,
    },

    -- The police are always told when one of these moves. It is not the kind
    -- of thing that goes unnoticed.
    alertsPolice = true,

    -- Condition still matters, but the fight usually costs you some.
    refuseBelow = 10,
}
