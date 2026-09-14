/* Shared plumbing: state, the NUI bridge, routing, formatting. */

const XS = {
  state: {
    open: false,
    booted: false,
    panel: 'home',
    rep: 0,
    stats: null,
    board: [],
    filter: 'all',
    market: [],
    marketPrev: {},
    job: null,
    telemetry: null,
    nearby: [],
    duo: { enabled: true, radius: 6 },
    heist: { enabled: true, repNeeded: 0, crewMin: 2, crewMax: 4 },
    crew: null,
    crewRules: { enabled: true, maxSize: 4, radius: 8, autoJoin: true },
    admin: false,
    event: null,
    eventJoined: false,
    ui: { theme: 'blue', bootSequence: true, telemetry: true, units: 'metric', escToClose: true },
    hack: {},
    // Per-character, saved on the server. Defaults match Config.Settings.
    settings: {
      theme: 'blue',
      hud: true,
      hudSide: 'left',
      alerts: true,
      notify: true,
      toasts: true,
      boot: true,
      sounds: true,
    },
    builder: null,
  },
};

XS.inGame = typeof GetParentResourceName === 'function';
XS.resource = XS.inGame ? GetParentResourceName() : 'XS-Boosting';

/* Every call out of the page goes through here. Outside FiveM it falls
   through to the mock so the whole interface can be worked on in a browser. */
XS.post = async function (name, data = {}) {
  if (!XS.inGame) {
    return window.XSMock ? window.XSMock.handle(name, data) : null;
  }

  try {
    const res = await fetch(`https://${XS.resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data),
    });
    return await res.json();
  } catch (err) {
    console.error(`[XS-Boosting] ${name} failed`, err);
    return null;
  }
};

/* ── DOM ────────────────────────────────────────────────────────────────── */

XS.el = (sel, root = document) => root.querySelector(sel);
XS.els = (sel, root = document) => Array.from(root.querySelectorAll(sel));

XS.esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
}[c]));

XS.panel = (name) => XS.el(`.panel[data-panel="${name}"]`);

XS.render = (name, html) => {
  const node = XS.panel(name);
  if (node) node.innerHTML = html;
  return node;
};

/* ── Formatting ─────────────────────────────────────────────────────────── */

XS.money = (amount) => '$' + Math.round(Number(amount) || 0).toLocaleString('en-US');

XS.clock = (seconds) => {
  const total = Math.max(0, Math.floor(Number(seconds) || 0));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
};

XS.ago = (stamp) => {
  if (!stamp) return '';
  const then = new Date(String(stamp).replace(' ', 'T'));
  if (Number.isNaN(then.getTime())) return '';

  const mins = Math.floor((Date.now() - then.getTime()) / 60000);
  if (mins < 1) return 'just now';
  if (mins < 60) return `${mins}m ago`;
  if (mins < 1440) return `${Math.floor(mins / 60)}h ago`;
  return `${Math.floor(mins / 1440)}d ago`;
};

/* Tier colour is derived from its position in the ladder, so adding a tier in
   config never needs a matching colour added here. */
XS.tierColour = (tierId) => {
  const tiers = XS.state.stats?.tiers || [];
  const index = Math.max(0, tiers.findIndex((t) => t.id === tierId));
  const hues = [188, 152, 42, 6, 280, 320];
  return `hsl(${hues[index % hues.length]} 85% 62%)`;
};

XS.typeLabel = (type) => ({
  standard: 'BOOST',
  spec: 'SPEC ORDER',
  chop: 'CHOP LIST',
  heist: 'HEIST',
}[type] || String(type || '').toUpperCase());

/* ── Routing ────────────────────────────────────────────────────────────── */

const PANELS = {
  home:    () => XS.Home,
  board:   () => XS.Board,
  market:  () => XS.Market,
  job:     () => XS.Job,
  crew:    () => XS.Crew,
  record:  () => XS.Stats,
  profile: () => XS.Profile,
  settings: () => XS.Settings,
};

let enterTimer = null;

XS.go = function (name) {
  if (!PANELS[name]) name = 'home';
  XS.state.panel = name;
  XS.entering = name;

  XS.els('.panel').forEach((p) => {
    p.classList.toggle('is-active', p.dataset.panel === name);
    p.classList.remove('is-entering');
  });

  XS.els('.dock__item').forEach((b) => b.classList.toggle('is-active', b.dataset.go === name));

  const panel = PANELS[name]();
  if (panel && panel.draw) panel.draw();

  // The stagger only runs on an actual panel change. Live data redrawing the
  // same panel underneath you must never re-animate it.
  const node = XS.panel(name);
  if (node) {
    node.classList.add('is-entering');
    clearTimeout(enterTimer);
    enterTimer = setTimeout(() => {
      node.classList.remove('is-entering');
      XS.entering = null;
    }, 700);
  }
};

/* Flash a value that has just changed rather than swapping it silently. */
XS.bump = function (el) {
  if (!el) return;
  el.classList.remove('is-bumped');
  void el.offsetWidth;
  el.classList.add('is-bumped');
};

/* The signed-in block in the sidebar, and anywhere else "you" is shown. */
XS.paintMe = function () {
  const stats = XS.state.stats;
  const face = XS.el('#dockFace');
  const name = XS.el('#dockName');
  const sub = XS.el('#dockSub');

  if (face) face.innerHTML = XS.Avatars.render(stats?.avatar, stats?.display);
  if (name) name.textContent = stats?.display || '—';
  if (sub) sub.textContent = stats?.tagline || `${stats?.rep ?? 0} rep`;
};

/* ── Toasts ─────────────────────────────────────────────────────────────── */

XS.toast = function (message, kind) {
  const host = XS.el('#toasts');
  if (!host) return;
  if (XS.state.settings.toasts === false) return;

  const node = document.createElement('div');
  node.className = `toast ${kind === 'good' ? 'is-good' : kind === 'bad' ? 'is-bad' : ''}`;
  node.innerHTML = `<i></i><span>${XS.esc(message)}</span>`;
  host.appendChild(node);

  setTimeout(() => {
    node.classList.add('is-out');
    setTimeout(() => node.remove(), 260);
  }, 3400);
};

/* ── Theme ──────────────────────────────────────────────────────────────── */

const THEME_IDS = ['blue', 'ice', 'violet', 'emerald', 'amber', 'crimson'];

XS.theme = function (name) {
  const app = XS.el('#app');
  const theme = THEME_IDS.includes(name) ? name : 'blue';

  if (app) app.dataset.theme = theme;

  // The HUD lives outside #app so it can show with the unit shut.
  const hud = XS.el('#hud');
  if (hud) hud.dataset.theme = theme;
};

/* ── Small SVG set, kept inline so nothing is ever fetched ──────────────── */

XS.icon = {
  lock: '<svg viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="10" rx="2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3" fill="none" stroke="currentColor" stroke-width="2"/></svg>',
  bell: '<svg viewBox="0 0 24 24"><path d="M6 16V11a6 6 0 0 1 12 0v5l1.5 2.5h-15L6 16z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M10 19a2 2 0 0 0 4 0" fill="none" stroke="currentColor" stroke-width="2"/></svg>',
  sat: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="2.5" fill="currentColor"/><path d="M7.5 16.5a6.4 6.4 0 0 1 0-9M16.5 7.5a6.4 6.4 0 0 1 0 9M4.6 19.4a10.5 10.5 0 0 1 0-14.8M19.4 4.6a10.5 10.5 0 0 1 0 14.8" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
  tick: '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7" fill="none" stroke="currentColor" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  car: '<svg viewBox="0 0 24 24"><path d="M3 14l1.6-4.8A3 3 0 0 1 7.4 7h9.2a3 3 0 0 1 2.8 2.2L21 14v4h-3v-2H6v2H3v-4z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><circle cx="7.5" cy="14" r="1.2" fill="currentColor"/><circle cx="16.5" cy="14" r="1.2" fill="currentColor"/></svg>',
  ghost: '<svg viewBox="0 0 24 24"><path d="M4 19V10a8 8 0 0 1 16 0v9l-2.7-2-2.6 2-2.7-2-2.6 2L6.7 17 4 19z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/></svg>',
  chart: '<svg viewBox="0 0 24 24"><path d="M4 17l5-6 4 3 7-9" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  users: '<svg viewBox="0 0 24 24"><circle cx="9" cy="9" r="3.2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="17" cy="10" r="2.6" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3.5 19c0-3 2.5-5 5.5-5s5.5 2 5.5 5M15 19c0-2.2 1.4-3.7 3.3-3.7 1.3 0 2.2.5 2.2.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/></svg>',
  user:  '<svg viewBox="0 0 24 24"><circle cx="12" cy="9" r="3.6" fill="none" stroke="currentColor" stroke-width="2"/><path d="M5 20c0-4 3.2-6.4 7-6.4s7 2.4 7 6.4" fill="none" stroke="currentColor" stroke-width="2"/></svg>',
};
