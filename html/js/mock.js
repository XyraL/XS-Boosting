/* Browser preview only. Never loaded in game — the client script never sends
   these, and XS.post routes here purely because GetParentResourceName is
   missing outside FiveM. Keep the shapes identical to the server's. */

(function () {
  const tiers = [
    { id: 'street', label: 'Street', description: 'Daily drivers. Nobody looks twice.', repNeeded: 0, unlocked: true, market: 1.08, vehicles: 4 },
    { id: 'clean', label: 'Clean', description: 'Cared-for cars with owners who notice.', repNeeded: 250, unlocked: true, market: 0.94, vehicles: 4 },
    { id: 'exotic', label: 'Exotic', description: 'Tracked, alarmed, and worth the trouble.', repNeeded: 1200, unlocked: false, market: 1.22, vehicles: 4 },
    { id: 'blacklist', label: 'Blacklist', description: 'Cars that get people killed.', repNeeded: 4000, unlocked: false, market: 0.81, vehicles: 4 },
  ];

  const board = [
    { id: 'C0001', type: 'standard', tier: 'street', tierLabel: 'Street', label: 'Premier', model: 'premier', payout: 1080, locked: false, repNeeded: 0, market: 1.08, expiresIn: 1420 },
    { id: 'C0002', type: 'spec', tier: 'clean', tierLabel: 'Clean', label: 'Kuruma', model: 'kuruma', payout: 3930, locked: false, repNeeded: 250, market: 0.94, colour: 'Black', minCondition: 80, expiresIn: 2100 },
    { id: 'C0003', type: 'chop', tier: 'street', tierLabel: 'Street', label: 'Asea', model: 'asea', payout: 918, locked: false, repNeeded: 0, market: 1.08, parts: [{ id: 'wheels', label: 'Wheels' }, { id: 'ecu', label: 'ECU' }, { id: 'seats', label: 'Seats' }] },
    { id: 'C0004', type: 'standard', tier: 'clean', tierLabel: 'Clean', label: 'Schafter', model: 'schafter2', payout: 2726, locked: false, repNeeded: 250, market: 0.94 },
    { id: 'C0005', type: 'standard', tier: 'exotic', tierLabel: 'Exotic', label: 'Itali GTB', model: 'italigtb', payout: 10980, locked: true, repNeeded: 1200, market: 1.22 },
    { id: 'C0006', type: 'spec', tier: 'blacklist', tierLabel: 'Blacklist', label: 'T20', model: 't20', payout: 18590, locked: true, repNeeded: 4000, market: 0.81, colour: 'Silver', minCondition: 80 },
  ];

  const unlocks = [
    { id: 'steady_hands', label: 'Steady Hands', description: 'Ten jobs in and you stop rushing.', effect: '+60s on every contract', earned: true, have: 10, need: 10, kind: 'completed' },
    { id: 'known_face', label: 'A Known Face', description: 'People have started asking for you.', effect: '+8% on every payout', earned: false, have: 23, need: 25, kind: 'completed' },
    { id: 'light_touch', label: 'Light Touch', description: 'Fifty deliveries teaches you where the kerbs are.', effect: 'First 10% of damage ignored', earned: false, have: 23, need: 50, kind: 'completed' },
    { id: 'grease', label: 'Grease Under The Nails', description: 'You have taken enough of them apart.', effect: '-20% cooldown between contracts', earned: false, have: 7, need: 20, kind: 'chopped' },
    { id: 'signal_sense', label: 'Signal Sense', description: 'You can hear a tracker before you see it.', effect: '+20s before a tracker goes live', earned: false, have: 640, need: 800, kind: 'rep' },
    { id: 'the_name', label: 'The Name', description: 'Half a million through your hands.', effect: '+15% on every payout', earned: false, have: 84320, need: 500000, kind: 'earned' },
  ];

  const stats = {
    handle: null,
    display: 'Unknown 3F2A',
    avatar: 'bi:4',
    tagline: '',
    handles: { enabled: true, minLength: 3, maxLength: 18, unique: true },
    profile: { allowCustomImages: true, taglineMax: 48 },
    unlocks,
    rep: 640,
    completed: 23,
    failed: 4,
    chopped: 7,
    heists: 1,
    earned: 84320,
    tier: { id: 'clean', label: 'Clean', index: 2 },
    nextTier: { id: 'exotic', label: 'Exotic', repNeeded: 1200, remaining: 560 },
    tiers,
    cooldown: 0,
    history: [
      { type: 'spec', tier: 'clean', model: 'kuruma', label: 'Kuruma', outcome: 'buyer', payout: 4120, condition: 94, created_at: stamp(18) },
      { type: 'standard', tier: 'clean', model: 'sultan', label: 'Sultan', outcome: 'buyer', payout: 2380, condition: 71, created_at: stamp(96) },
      { type: 'chop', tier: 'street', model: 'blista', label: 'Blista', outcome: 'chop', payout: 860, condition: 40, created_at: stamp(180) },
      { type: 'standard', tier: 'clean', model: 'buffalo', label: 'Buffalo', outcome: 'failed', payout: 0, condition: 0, created_at: stamp(320) },
      { type: 'standard', tier: 'street', model: 'asea', label: 'Asea', outcome: 'fence', payout: 300, condition: 22, created_at: stamp(1500) },
    ],
  };

  const job = {
    id: 'J00042',
    type: 'spec',
    tier: 'clean',
    tierLabel: 'Clean',
    model: 'kuruma',
    label: 'Kuruma',
    plate: '42KLM887',
    colour: 'Black',
    minCondition: 80,
    stage: 'transit',
    remaining: 742,
    limit: 1080,
    condition: 91,
    payout: 3930,
    fitted: { alarm: true, tracker: true },
    tracker: { alive: true, broadcasting: true },
    buyer: { x: 0, y: 0, z: 0 },
    buyerRadius: 12,
    crew: [
      { src: 1, name: 'Vincent Valentine', role: 'holder' },
      { src: 7, name: 'Marta Quinn', role: 'crew' },
    ],
    netId: 1,
  };

  function stamp(minutesAgo) {
    const d = new Date(Date.now() - minutesAgo * 60000);
    return d.toISOString().slice(0, 19).replace('T', ' ');
  }

  const market = tiers.map((t) => ({ id: t.id, label: t.label, multiplier: t.market }));

  const locations = [
    { id: 1, kind: 'spawn', label: 'Mirror Park kerb', tier: 'street', coords: { x: -12.4, y: -1502.2, z: 29.6 }, heading: 210, radius: 5, enabled: true, data: {} },
    { id: 2, kind: 'spawn', label: 'Vinewood drive', tier: 'clean', coords: { x: 122.7, y: 560.1, z: 183.9 }, heading: 88, radius: 5, enabled: true, data: {} },
    { id: 3, kind: 'buyer', label: 'Docks handover', coords: { x: 718.0, y: -1084.7, z: 22.3 }, heading: 93, radius: 12, enabled: true, data: {} },
    { id: 4, kind: 'chop', label: 'Sandy lockup', coords: { x: 1728.3, y: 3712.4, z: 34.1 }, heading: 0, radius: 10, enabled: true, data: {} },
    { id: 5, kind: 'deadzone', label: 'LS tunnel', coords: { x: 84.1, y: -720.9, z: 32.1 }, heading: 0, radius: 25, enabled: true, data: {} },
    { id: 6, kind: 'heist', label: 'Premium Deluxe', coords: { x: -33.8, y: -1102.4, z: 26.4 }, heading: 250, radius: 22, enabled: false, data: { spawns: [{ x: 0, y: 0, z: 0, h: 0 }, { x: 1, y: 0, z: 0, h: 0 }, { x: 2, y: 0, z: 0, h: 0 }] } },
    { id: 7, kind: 'heist_exit', label: 'Showroom doors', coords: { x: -47.2, y: -1096.1, z: 26.4 }, heading: 70, radius: 15, enabled: true, data: {} },
  ];

  const leaderboard = [
    { rank: 1, name: 'nightshift', named: true, avatar: 'bi:0', rep: 4820, completed: 141, chopped: 38, heists: 9, earned: 612400 },
    { rank: 2, name: 'Unknown 9C14', named: false, avatar: null, rep: 3110, completed: 96, chopped: 21, heists: 5, earned: 388200 },
    { rank: 3, name: 'the_dutchman', named: true, avatar: 'bi:7', rep: 2640, completed: 88, chopped: 44, heists: 4, earned: 301750 },
    { rank: 4, name: 'Unknown 44B0', named: false, avatar: null, rep: 1290, completed: 51, chopped: 12, heists: 1, earned: 158900 },
    { rank: 5, name: 'clutch', named: true, avatar: 'bi:11', rep: 720, completed: 29, chopped: 8, heists: 0, earned: 74300 },
  ];

  const payload = {
    stats,
    board,
    market,
    marketIn: 24,
    refreshIn: 540,
    job: null,
    locations,
    discovered: [4, 5],
    admin: true,
    ui: { theme: 'acid', bootSequence: true, telemetry: true, units: 'metric', escToClose: true },
    hack: { gridBase: 3, codesBase: 1, seconds: 22, secondsPerLevel: -3, penaltySeconds: 3 },
    version: 'v0.4.0',
    event: {
      id: 'E4821', model: 't20', label: 'T20', plate: 'HOT4821',
      payout: 48000, coords: { x: 0, y: 0, z: 0 }, buyer: { x: 0, y: 0, z: 0 },
      buyerRadius: 12, remaining: 900, window: 1500, joined: 3, guards: 4, taken: false,
    },
    joinedEvent: false,
    settings: { theme: 'blue', hud: true, hudSide: 'left', alerts: true, notify: true, toasts: true, boot: true, sounds: true },
    heist: { enabled: true, repNeeded: 2000, crewMin: 2, crewMax: 4 },
    duo: { enabled: true, radius: 6 },
    crew: null,
    crewRules: { enabled: true, maxSize: 4, radius: 8, autoJoin: true },
  };

  const nearby = [{ src: 7, name: 'Marta Quinn' }, { src: 9, name: 'Desmond Rowe' }];

  /* Built up by the invite handler below, the same way the server does it. */
  const crew = {
    leader: 1,
    me: 1,
    isLeader: true,
    max: 4,
    members: [{ src: 1, name: 'Vincent Valentine', leader: true, busy: false }],
  };

  const builder = {
    locations,
    resting: { 1: 900, 2: 240 },
    allCars: [
      { model: 'adder', label: 'Adder' }, { model: 'bati', label: 'Bati 801' },
      { model: 'dubsta', label: 'Dubsta' }, { model: 'futo', label: 'Futo' },
      { model: 'sultan', label: 'Sultan' }, { model: 'zentorno', label: 'Zentorno' },
      { model: 'sanchez', label: 'Sanchez' }, { model: 'youga', label: 'Youga' },
    ],
    tiers: [
      { id: 'street', label: 'Street', vehicles: [{ model: 'blista', label: 'Blista' }, { model: 'asea', label: 'Asea' }, { model: 'premier', label: 'Premier' }] },
      { id: 'clean', label: 'Clean', vehicles: [{ model: 'sultan', label: 'Sultan' }, { model: 'kuruma', label: 'Kuruma' }] },
      { id: 'exotic', label: 'Exotic', vehicles: [{ model: 'comet2', label: 'Comet' }, { model: 'italigtb', label: 'Itali GTB' }] },
      { id: 'blacklist', label: 'Blacklist', vehicles: [{ model: 'zentorno', label: 'Zentorno' }, { model: 't20', label: 'T20' }] },
    ],
    kinds: [
      { id: 'spawn', label: 'Vehicle Spawn', tiered: true },
      { id: 'buyer', label: 'Handover Point', tiered: false },
      { id: 'chop', label: 'Chop Shop', tiered: false },
      { id: 'fence', label: 'Street Fence', tiered: false },
      { id: 'deadzone', label: 'Dead Zone', tiered: false },
      { id: 'heist', label: 'Heist Site', tiered: false },
      { id: 'heist_exit', label: 'Heist Exit', tiered: false },
    ],
    items: [],
  };

  const liveJobs = [
    { id: 'J00042', holder: 'Vincent Valentine', heist: false, tier: 'clean', label: 'Kuruma', stage: 'transit', crew: 2, remaining: 742, condition: 91 },
    { id: 'J00043', holder: 'Otto Brandt', heist: true, tier: 'exotic', label: 'Showroom', stage: 'running', crew: 3, remaining: 1120, condition: 100 },
  ];

  window.XSMock = {
    boot() {
      window.postMessage({ action: 'open', data: payload }, '*');
      setTimeout(() => window.postMessage({ action: 'job', data: job }, '*'), 900);

      setInterval(() => {
        window.postMessage({
          action: 'telemetry',
          data: { speed: 40 + Math.floor(Math.random() * 70), units: 'km/h', condition: job.condition, inVehicle: true },
        }, '*');
      }, 1200);
    },

    handle(name, data) {
      switch (name) {
        case 'board': return board;
        case 'stats': return stats;
        case 'leaderboard': return leaderboard;
        case 'nearby': return nearby;
        case 'accept': {
          const taken = board.find((c) => c.id === data.id);
          if (!taken || taken.locked) return { ok: false, reason: 'Not for you.' };
          const next = { ...job, label: taken.label, model: taken.model, type: taken.type, tier: taken.tier, tierLabel: taken.tierLabel, payout: taken.payout, stage: 'search', remaining: 1080, crew: [job.crew[0]] };
          setTimeout(() => window.postMessage({ action: 'job', data: next }, '*'), 60);
          return { ok: true, job: next };
        }
        case 'abandon':
          setTimeout(() => window.postMessage({ action: 'jobEnded', data: { outcome: 'failed' } }, '*'), 60);
          return { ok: true };
        case 'invite': {
          const who = nearby.find((p) => p.src === data.src);
          if (who && !crew.members.some((m) => m.src === who.src)) {
            crew.members.push({ src: who.src, name: who.name, leader: false, busy: false });
          }
          setTimeout(() => window.postMessage({ action: 'crew', data: crew }, '*'), 400);
          return { ok: true };
        }
        case 'crewLeave':
          crew.members = [{ src: 1, name: 'Vincent Valentine', leader: true, busy: false }];
          setTimeout(() => window.postMessage({ action: 'crew', data: null }, '*'), 60);
          return { ok: true };
        case 'heistStart': return { ok: false, reason: 'Preview only.' };
        case 'heistBegin': return { ok: false, reason: 'Preview only.' };
        case 'deliver': return { ok: true, amount: 3930 };
        case 'close':
          window.postMessage({ action: 'close' }, '*');
          return true;
        case 'minigameResult':
          console.log('[mock] minigame', data);
          return true;
        case 'hackResult':
          console.log('[mock] hack', data);
          return true;
        case 'killTracker':
          console.log('[mock] killTracker', data);
          return true;
        case 'eventJoin':
          payload.joinedEvent = true;
          return { ok: true, event: payload.event };
        case 'setSetting': {
          payload.settings[data.key] = data.value;
          return { ok: true };
        }
        case 'setAvatar': {
          const value = String(data.avatar || '');
          const builtin = value.startsWith('bi:') && Number.isFinite(Number(value.slice(3)));
          const link = value.toLowerCase().startsWith('http');
          if (!builtin && !link) {
            return { ok: false, reason: 'Not a picture.' };
          }
          stats.avatar = value;
          return { ok: true, avatar: value };
        }
        case 'setTagline': {
          const value = String(data.tagline || '').trim();
          if (value.length > 48) return { ok: false, reason: 'Too long.' };
          stats.tagline = value;
          return { ok: true, tagline: value };
        }
        case 'setHandle': {
          const value = String(data.handle || '').trim();
          if (value.length < 3) return { ok: false, reason: 'Between 3 and 18 characters.' };
          if (!/^[A-Za-z0-9 ._-]+$/.test(value)) return { ok: false, reason: 'Letters, numbers, spaces and . _ - only.' };
          stats.handle = value;
          stats.display = value;
          return { ok: true, handle: value };
        }

        case 'builderList': return builder;
        case 'builderJobs': return liveJobs;
        case 'builderEvent': return {
          active: payload.event,
          joined: 3,
          canStart: false,
          reason: 'One is already running.',
          auto: true, every: 90, online: 12, needed: 4,
        };
        case 'builderEventStart': return { ok: true };
        case 'builderEventStop': return { ok: true };
        case 'builderStored': return [
          { id: 1, who: 'nightshift', label: 'Kuruma', plate: '42KLM887', tier: 'clean', lockup: 'Sandy lockup', remaining: 640, condition: 88 },
          { id: 2, who: 'Unknown 9C14', label: 'Sultan RS', plate: '88XCV221', tier: 'exotic', lockup: 'Sandy lockup', remaining: 210, condition: 54 },
        ];
        case 'builderReleaseStored': return { ok: true };
        case 'builderPlace': return { coords: { x: 101.2, y: -204.8, z: 54.1 }, heading: 145.5, radius: data.radius || 10 };
        case 'builderHeistSpawns': return { spawns: [{ x: 1, y: 2, z: 3, h: 0 }, { x: 4, y: 5, z: 6, h: 0 }] };
        case 'builderSave': return { ok: true };
        case 'builderDelete': return { ok: true };
        case 'builderToggle': return { ok: true };
        case 'builderGoto': return true;
        case 'builderCancelJob': return { ok: true };
        case 'builderRefreshBoard': return { ok: true };
        case 'builderShiftMarket': return { ok: true, market };
        case 'builderSetRep': return { ok: true, rep: data.amount };
        case 'builderClose':
          window.postMessage({ action: 'builderClose' }, '*');
          return true;

        default: return null;
      }
    },

    openBuilder() {
      window.postMessage({ action: 'builder', data: builder }, '*');
    },

    minigame(stage, difficulty) {
      window.postMessage({ action: 'minigame', data: { stage: stage || 'entry', difficulty: difficulty || 2 } }, '*');
    },

    hack(difficulty) {
      window.postMessage({ action: 'hack', data: { difficulty: difficulty || 2 } }, '*');
    },

    alert(kind) {
      const samples = {
        warn: { title: 'Alarm going off', text: 'Silence it at the car before somebody calls it in.', kind: 'warn' },
        bad: { title: 'Tracker is live', text: 'It is feeding your position. Kill it at the car or reach a dead zone.', kind: 'bad' },
        good: { title: 'Tracker dead', text: 'They have lost your position.', kind: 'good' },
        info: { title: 'Reported stolen', text: 'The theft has gone out over the radio.', kind: 'info' },
      };
      window.postMessage({ action: 'alert', data: samples[kind] || samples.info }, '*');
    },

    hud() {
      window.postMessage({ action: 'close' }, '*');
    },
  };
}());
