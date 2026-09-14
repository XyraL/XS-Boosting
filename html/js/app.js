/* Wiring: messages in, boot, visibility, the one-second tick. */

const BOOT_LINES = [
  'Connecting',
  'Loading your profile',
  'Pulling listings',
  'Checking rates',
];

let ticker = null;

/* The page has two independent reasons to be on screen: the unit, which takes
   focus, and the HUD, which never does. Anything that changes either one ends
   up here, so the body is only ever hidden when there is genuinely nothing to
   show. */
function syncVisibility() {
  const anything =
    XS.state.open ||
    !XS.el('#boot').classList.contains('hidden') ||
    !XS.el('#builder').classList.contains('hidden') ||
    !XS.el('#minigame').classList.contains('hidden') ||
    XS.Hud.visible();

  document.body.classList.toggle('hidden', !anything);
  XS.el('#app').classList.toggle('hidden', !(
    XS.state.open ||
    !XS.el('#boot').classList.contains('hidden') ||
    !XS.el('#builder').classList.contains('hidden') ||
    !XS.el('#minigame').classList.contains('hidden')
  ));
}

function showUnit(which) {
  XS.el('#boot').classList.toggle('hidden', which !== 'boot');
  XS.el('#unit').classList.toggle('hidden', which !== 'unit');
  syncVisibility();
}

function hideChrome() {
  XS.el('#boot').classList.add('hidden');
  XS.el('#unit').classList.add('hidden');
  XS.el('#builder').classList.add('hidden');
  XS.el('#minigame').classList.add('hidden');
}

async function boot() {
  showUnit('boot');

  const lines = XS.el('#bootLines');
  const bar = XS.el('.boot__bar i');

  for (let i = 0; i < BOOT_LINES.length; i += 1) {
    lines.innerHTML = `${BOOT_LINES[i]}<span class="ok">…</span>`;
    bar.style.width = `${((i + 1) / BOOT_LINES.length) * 100}%`;
    await new Promise((r) => setTimeout(r, 130 + Math.random() * 70));
  }

  await new Promise((r) => setTimeout(r, 160));
}

function applyPayload(payload) {
  const s = XS.state;

  s.stats = payload.stats || s.stats;
  s.rep = payload.stats?.rep ?? s.rep;
  s.board = payload.board || [];
  s.marketPrev = {};
  s.market = payload.market || [];
  s.marketIn = payload.marketIn;
  s.refreshIn = payload.refreshIn;
  s.admin = !!payload.admin;
  s.duo = payload.duo || s.duo;
  s.heist = payload.heist || s.heist;
  s.crew = payload.crew || null;
  s.crewRules = payload.crewRules || s.crewRules;
  s.ui = payload.ui || s.ui;
  s.hack = payload.hack || s.hack;

  if (payload.settings) s.settings = { ...s.settings, ...payload.settings };

  s.event = payload.event || null;
  s.eventJoined = !!payload.joinedEvent;

  if (payload.job) {
    s.job = payload.job;
    s.jobAt = Date.now();
  }

  XS.theme(s.settings.theme);

  const build = XS.el('#statusBuild');
  if (build) build.textContent = s.admin ? 'Admin' : (payload.version || 'v0.3.0');

  paintStatus();
  XS.paintMe();
  XS.Market.ticker();
}

function paintStatus() {
  const s = XS.state;
  const job = s.job;

  const rep = XS.el('#statusRep');
  const tier = XS.el('#statusTier');
  const flag = XS.el('#dockJobFlag');

  if (rep) rep.textContent = String(s.rep ?? 0);
  if (tier) tier.textContent = s.stats?.tier?.label || '—';
  if (flag) flag.classList.toggle('hidden', !job);

  const unit = XS.el('#unit');
  if (unit) {
    unit.classList.toggle('is-live', !!job);
    unit.classList.toggle('is-hot', !!job?.tracker?.broadcasting);
  }

  const mode = XS.el('#slMode');
  const info = XS.el('#slInfo');
  const slJob = XS.el('#slJob');

  if (mode) {
    const hot = !!job?.tracker?.broadcasting;
    mode.textContent = hot ? 'Being tracked' : job ? 'On a job' : 'Connected';
    mode.classList.toggle('is-hot', hot);
    mode.classList.toggle('is-acc', !hot);
  }

  if (info) {
    if (s.event) {
      info.textContent = `${s.event.label} is up for grabs`;
    } else {
      const open = (s.board || []).filter((c) => !c.locked).length;
      info.textContent = `${open} listing${open === 1 ? '' : 's'} open`;
    }
  }

  if (slJob) {
    slJob.textContent = job
      ? `${job.heist ? 'Showroom job' : job.label} · ${XS.Job.stageLabel(job.stage)}`
      : 'No contract';
  }
}

async function openUnit(payload) {
  applyPayload(payload || {});

  const wantsBoot = XS.state.settings.boot !== false && XS.state.ui.bootSequence;

  if (wantsBoot && !XS.state.booted) {
    await boot();
    XS.state.booted = true;
  }

  XS.state.open = true;
  showUnit('unit');
  XS.Hud.sync();
  XS.go(XS.state.job ? 'job' : 'home');
  startTick();
}

function closeUnit() {
  XS.state.open = false;
  hideChrome();
  XS.Hud.sync();
  syncVisibility();

  // The tick keeps running while a contract does, because the HUD needs it.
  if (!XS.state.job) stopTick();
}

function startTick() {
  if (ticker) return;

  ticker = setInterval(() => {
    const clock = XS.el('#statusClock');
    if (clock) {
      const now = new Date();
      clock.textContent = `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`;
    }

    if (!XS.state.job) return;

    if (XS.state.open && XS.state.panel === 'job') XS.Job.tick();

    const home = XS.el('#homeClock');
    if (home) home.textContent = XS.clock(XS.Job.seconds());

    XS.Hud.tick();
  }, 1000);
}

function stopTick() {
  if (!ticker) return;
  clearInterval(ticker);
  ticker = null;
}

/* ── Messages from the client script ────────────────────────────────────── */

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};

  switch (action) {
    case 'open':
      openUnit(data);
      break;

    case 'close':
      closeUnit();
      break;

    case 'settings':
      XS.state.settings = { ...XS.state.settings, ...(data || {}) };
      XS.theme(XS.state.settings.theme);
      XS.Hud.sync();
      if (XS.state.open && XS.state.panel === 'settings') XS.Settings.draw();
      break;

    case 'board':
      XS.state.board = data || [];
      paintStatus();
      if (!XS.state.open) break;
      if (XS.state.panel === 'board') XS.Board.draw();
      if (XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'crew':
      XS.state.crew = data || null;
      paintStatus();
      if (!XS.state.open) break;
      if (XS.state.panel === 'crew') XS.Crew.draw();
      if (XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'market':
      XS.Market.update(data);
      if (XS.state.open && XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'rep':
      XS.state.rep = data?.rep ?? XS.state.rep;
      if (XS.state.stats) XS.state.stats.rep = XS.state.rep;
      paintStatus();
      XS.paintMe();
      XS.bump(XS.el('#statusRep'));
      break;

    case 'job':
      XS.state.job = data;
      XS.state.jobAt = Date.now();
      paintStatus();
      XS.Hud.sync();
      startTick();
      if (!XS.state.open) break;
      if (XS.state.panel === 'job') XS.Job.draw();
      if (XS.state.panel === 'crew') XS.Crew.draw();
      if (XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'jobEnded':
      XS.state.job = null;
      paintStatus();
      XS.Hud.sync();
      syncVisibility();
      if (!XS.state.open) { stopTick(); break; }
      if (XS.state.panel === 'job') XS.Job.draw();
      if (XS.state.panel === 'crew') XS.Crew.draw();
      if (XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'event':
      XS.state.event = data || null;
      if (!data) XS.state.eventJoined = false;
      paintStatus();
      if (XS.state.open && XS.state.panel === 'board') XS.Board.draw();
      if (XS.state.open && XS.state.panel === 'home') XS.Home.draw();
      break;

    case 'alert':
      XS.Hud.alert(data);
      break;

    case 'telemetry':
      if (XS.state.open && XS.state.panel === 'job') XS.Job.telemetry(data);
      break;

    case 'minigame':
      XS.el('#minigame').classList.remove('hidden');
      syncVisibility();
      XS.Mini.start(data?.stage, data?.difficulty);
      break;

    case 'hack':
      XS.el('#minigame').classList.remove('hidden');
      syncVisibility();
      XS.Hack.start(data?.difficulty);
      break;

    case 'builder':
      XS.Builder.open(data);
      syncVisibility();
      break;

    case 'builderClose':
      XS.Builder.close();
      syncVisibility();
      break;

    case 'builderPlacing':
      XS.el('#placing').classList.toggle('hidden', !data);
      XS.el('#builder').style.visibility = data ? 'hidden' : '';
      break;

    default:
      break;
  }
});

/* ── Page wiring ────────────────────────────────────────────────────────── */

document.addEventListener('DOMContentLoaded', () => {
  XS.els('[data-go]').forEach((btn) => {
    btn.onclick = () => XS.go(btn.dataset.go);
  });

  XS.el('#btnClose').onclick = () => XS.post('close');

  window.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    if (XS.Mini.running || XS.Hack.running) return;

    if (!XS.el('#builder').classList.contains('hidden')) {
      XS.post('builderClose');
      return;
    }

    if (XS.state.open && XS.state.ui.escToClose) XS.post('close');
  });

  if (!XS.inGame && window.XSMock) window.XSMock.boot();
});
