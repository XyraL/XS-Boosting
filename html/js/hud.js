/* The HUD. Shown in the world while a contract runs and the unit is shut.
   It never takes focus and nothing in it is clickable — it only tells you
   the two things you cannot see any other way: which car, and how it is
   going. Alerts stack underneath and fade themselves out. */

XS.Hud = {};

const HUD_STAGES = ['search', 'entry', 'transit', 'done'];

const HUD_STAGE_LABEL = {
  search: 'Find it',
  entry: 'Get in',
  transit: 'Deliver it',
  sting: 'Setup',
  staging: 'Staging',
  running: 'Running',
  done: 'Handing over',
};

const ALERT_ICON = {
  info: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 11v5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="7.6" r="1.2" fill="currentColor"/></svg>',
  warn: '<svg viewBox="0 0 24 24"><path d="M12 4l9 16H3z" fill="none" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/><path d="M12 10v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="17" r="1.1" fill="currentColor"/></svg>',
  bad: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M9 9l6 6M15 9l-6 6" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>',
  good: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="currentColor" stroke-width="2"/><path d="M8 12.5l2.6 2.6L16 9.8" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
};

XS.Hud.visible = function () {
  return !XS.el('#hud').classList.contains('hidden');
};

/* Shown only when there is a contract, the unit is shut, and the player has
   not switched it off in settings. */
XS.Hud.sync = function () {
  const host = XS.el('#hud');
  const on = !!XS.state.job
    && !XS.state.open
    && XS.state.settings.hud !== false;

  host.dataset.side = XS.state.settings.hudSide === 'right' ? 'right' : 'left';

  if (!on) {
    if (!host.classList.contains('hidden')) {
      host.classList.add('hidden');
      host.innerHTML = '';
    }
    return;
  }

  host.classList.remove('hidden');
  XS.Hud.draw();
};

XS.Hud.draw = function () {
  const job = XS.state.job;
  const host = XS.el('#hud');
  if (!job) return;

  const seconds = XS.Job.seconds();
  const hot = !!job.tracker?.broadcasting;

  // Keep the alert stack across redraws rather than wiping it.
  const keep = XS.el('#hudAlerts');
  const kept = keep ? keep.innerHTML : '';

  host.innerHTML = `
    <div class="hudcard ${hot ? 'is-hot' : ''}">
      <div class="hud__top">
        <span class="hud__label">${job.heist ? 'Heist' : 'Contract'}</span>
        <span class="hud__clock ${seconds < 60 ? 'is-low' : ''}" id="hudClock">${XS.clock(seconds)}</span>
      </div>
      <div class="hud__body">
        ${job.heist ? XS.Hud.heist(job) : XS.Hud.contract(job)}
      </div>
    </div>
    <div class="hud__alerts" id="hudAlerts">${kept}</div>
  `;
};

XS.Hud.contract = function (job) {
  const stage = job.stage === 'sting' ? 'entry' : job.stage;
  const at = Math.max(0, HUD_STAGES.indexOf(stage));

  const pips = HUD_STAGES.map((_, i) =>
    `<i class="hud__pip ${i < at ? 'is-done' : i === at ? 'is-now' : ''}"></i>`
  ).join('');

  const condition = job.condition ?? 100;
  const condClass = condition < 40 ? 'is-bad' : condition < 70 ? 'is-warn' : 'is-good';

  const chips = [];

  if (job.driving) {
    chips.push(job.stopped
      ? `<span class="hud__chip on">Driver out</span>`
      : `<span class="hud__chip bad">Being driven</span>`);
  }

  if (job.fitted?.alarm) chips.push(`<span class="hud__chip warn">Alarm fitted</span>`);

  if (job.fitted?.tracker) {
    if (job.tracker?.broadcasting) chips.push(`<span class="hud__chip bad">Tracker live</span>`);
    else if (job.tracker?.alive) chips.push(`<span class="hud__chip warn">Tracker armed</span>`);
    else chips.push(`<span class="hud__chip on">Tracker dead</span>`);
  }

  if (job.colour) chips.push(`<span class="hud__chip">${XS.esc(job.colour)}</span>`);
  if (job.minCondition) chips.push(`<span class="hud__chip warn">${job.minCondition}%+ needed</span>`);

  return `
    <div class="hud__car">
      <div class="hud__name">${XS.esc(job.label)}</div>
      <div class="hud__model">${XS.esc(job.tierLabel || job.tier || '')} · ${XS.esc(XS.typeLabel(job.type))}</div>
    </div>

    <div class="hud__plate">
      <small>SAN ANDREAS</small>
      <b>${XS.esc(job.plate || '—')}</b>
    </div>

    <div>
      <div class="hud__stage">${pips}</div>
      <div class="hud__stagelabel" style="margin-top:7px">${XS.esc(HUD_STAGE_LABEL[job.stage] || job.stage || '')}</div>
    </div>

    <div class="hud__meters">
      <div class="hud__meter">
        <span>Condition</span>
        <div class="hud__bar"><i class="${condClass}" style="width:${condition}%"></i></div>
        <b>${Math.round(condition)}%</b>
      </div>
    </div>

    ${chips.length ? `<div class="hud__chips">${chips.join('')}</div>` : ''}
  `;
};

XS.Hud.heist = function (job) {
  const done = job.delivered || 0;
  const total = job.total || 1;
  const pct = (done / total) * 100;

  return `
    <div class="hud__car">
      <div class="hud__name">Showroom job</div>
      <div class="hud__model">${XS.esc(job.tierLabel || job.tier || '')}</div>
    </div>

    <div class="hud__meters">
      <div class="hud__meter">
        <span>Cars out</span>
        <div class="hud__bar"><i style="width:${pct}%"></i></div>
        <b>${done}/${total}</b>
      </div>
    </div>

    <div class="hud__chips">
      <span class="hud__chip ${job.stage === 'running' ? 'on' : 'warn'}">
        ${job.stage === 'running' ? 'In progress' : 'Staging'}
      </span>
      <span class="hud__chip">${(job.crew || []).length} on the crew</span>
    </div>
  `;
};

XS.Hud.tick = function () {
  const clock = XS.el('#hudClock');
  if (!clock || !XS.state.job) return;

  const seconds = XS.Job.seconds();
  clock.textContent = XS.clock(seconds);
  clock.classList.toggle('is-low', seconds < 60);
};

/* Alerts come from the client script at the moments that matter. They live
   in the HUD rather than the toast stack, because they are about the job
   rather than about the interface. */
XS.Hud.alert = function (data) {
  if (!data || !data.text) return;
  if (XS.state.settings.hud === false) return;

  // Nothing to attach to yet — make sure the card exists first.
  if (XS.el('#hud').classList.contains('hidden')) XS.Hud.sync();

  const host = XS.el('#hudAlerts');
  if (!host) return;

  const kind = ['warn', 'bad', 'good'].includes(data.kind) ? data.kind : 'info';

  const node = document.createElement('div');
  node.className = `hudalert ${kind}`;
  node.innerHTML = `
    <span class="hudalert__icon">${ALERT_ICON[kind]}</span>
    <span>${data.title ? `<b>${XS.esc(data.title)}</b>` : ''}${XS.esc(data.text)}</span>
  `;

  host.appendChild(node);

  // Three at a time, oldest first.
  while (host.children.length > 3) host.removeChild(host.firstChild);

  setTimeout(() => {
    node.classList.add('is-out');
    setTimeout(() => node.remove(), 240);
  }, data.hold || 6000);
};
