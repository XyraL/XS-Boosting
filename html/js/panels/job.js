/* The active contract. The cluster is the hero: time on the outer ring,
   condition on the inner one, both driven by live telemetry. */

XS.Job = {};

const R_TIME = 92;
const R_COND = 74;
const C_TIME = 2 * Math.PI * R_TIME;
const C_COND = 2 * Math.PI * R_COND;

const STAGES = [
  { id: 'search', label: 'Find it' },
  { id: 'entry', label: 'Get in' },
  { id: 'transit', label: 'Move it' },
  { id: 'done', label: 'Hand over' },
];

XS.Job.draw = function () {
  const job = XS.state.job;

  if (!job) {
    XS.render('job', `
      <div class="empty">
        <div class="empty__mark">${XS.icon.ghost}</div>
        <h4>nothing running</h4>
        <p>Take something off the board and it shows up here.</p>
      </div>
    `);
    return;
  }

  if (job.heist) { XS.Job.drawHeist(job); return; }

  XS.render('job', `
    <div class="head">
      <div>
        <div class="head__title">${XS.esc(job.label)}</div>
        <div class="head__sub">${XS.esc(job.tierLabel || job.tier)} · ${XS.esc(XS.typeLabel(job.type))}</div>
      </div>
      <div class="head__tools">
        <button class="btn btn--sm btn--bad" id="jobDrop">walk away</button>
      </div>
    </div>

    <div class="job">
      ${XS.Job.cluster(job)}
      <div class="jobmain">
        ${XS.Job.bolo(job)}
        ${XS.Job.steps(job)}
        ${job.tracker?.broadcasting ? XS.Job.broadcast() : ''}
        ${XS.Job.remote(job)}
        ${XS.Job.hardware(job)}
        ${job.parts?.length ? XS.Job.parts(job) : ''}
      </div>
    </div>
  `);

  const drop = XS.el('#jobDrop');
  if (drop) {
    drop.onclick = async () => {
      drop.disabled = true;
      await XS.post('abandon');
      drop.disabled = false;
    };
  }

  const remote = XS.el('#jobRemote');
  if (remote) {
    remote.onclick = () => {
      remote.disabled = true;
      XS.post('killTracker', { remote: true });
      XS.post('close');
    };
  }

  XS.Job.tick();
};

XS.Job.cluster = function (job) {
  return `
    <div class="cluster">
      <svg class="cluster__ring" viewBox="0 0 200 200">
        <circle class="cluster__track" cx="100" cy="100" r="${R_TIME}" stroke-width="7"/>
        <circle class="cluster__track" cx="100" cy="100" r="${R_COND}" stroke-width="5"/>
        <circle class="cluster__time" id="ringTime" cx="100" cy="100" r="${R_TIME}" stroke-width="7"
                stroke-dasharray="${C_TIME}" stroke-dashoffset="0"/>
        <circle class="cluster__cond" id="ringCond" cx="100" cy="100" r="${R_COND}" stroke-width="5"
                stroke-dasharray="${C_COND}" stroke-dashoffset="0"/>
      </svg>

      <div class="cluster__core">
        <div class="cluster__clock" id="jobClock">--:--</div>
        <div class="cluster__label" id="jobStageLabel">${XS.esc(XS.Job.stageLabel(job.stage))}</div>
      </div>

      <div class="cluster__readout">
        <div class="readout"><b id="jobSpeed">0</b><small id="jobSpeedUnit">KM/H</small></div>
        <div class="readout"><b id="jobCond">${job.condition ?? 100}%</b><small>CONDITION</small></div>
        <div class="readout"><b>${XS.money(job.payout)}</b><small>ON OFFER</small></div>
      </div>
    </div>
  `;
};

XS.Job.bolo = function (job) {
  const tags = [];

  if (job.colour) {
    tags.push(`<span class="tag"><i class="swatch" style="background:${XS.Board.swatch(job.colour)}"></i>${XS.esc(job.colour)}</span>`);
  }

  if (job.minCondition) {
    tags.push(`<span class="tag tag--warn">needs ${job.minCondition}%+</span>`);
  }

  tags.push(`<span class="tag">${XS.esc(job.model)}</span>`);

  if (job.driving) {
    tags.push(job.stopped
      ? `<span class="tag tag--acc">Driver is out</span>`
      : `<span class="tag tag--bad">Somebody is driving it</span>`);
  }

  return `
    <div class="slab">
      <div class="slab__title">what you are looking for</div>
      <div class="bolo">
        <div>
          <div class="bolo__name">${XS.esc(job.label)}</div>
          <div class="bolo__sub">${tags.join('')}</div>
        </div>
        <div class="plate">
          <small>SAN ANDREAS</small>
          <b>${XS.esc(job.plate || '—')}</b>
        </div>
      </div>
    </div>
  `;
};

XS.Job.steps = function (job) {
  const stages = job.driving
    ? [{ id: 'search', label: 'Chase it' }, { id: 'entry', label: 'Stop it' },
       { id: 'transit', label: 'Move it' }, { id: 'done', label: 'Hand over' }]
    : STAGES;

  const order = stages.map((s) => s.id);
  const current = job.stage === 'sting' ? 'entry' : job.stage;
  const at = Math.max(0, order.indexOf(current));

  const items = stages.map((s, i) => {
    const cls = i < at ? 'is-done' : i === at ? 'is-now' : '';
    return `<div class="step ${cls}"><i class="step__dot"></i><span>${XS.esc(s.label)}</span></div>`;
  }).join('');

  return `<div class="slab"><div class="steps">${items}</div></div>`;
};

XS.Job.hardware = function (job) {
  const fitted = job.fitted || {};
  const tracker = job.tracker || {};

  const alarmState = !fitted.alarm ? 'is-dead' : 'is-ok';
  const alarmText = !fitted.alarm ? 'Not fitted' : 'Fitted — keep it quiet';

  let trackerState = 'is-dead';
  let trackerText = 'Not fitted';

  if (fitted.tracker) {
    if (!tracker.alive) { trackerState = 'is-ok'; trackerText = 'Dead'; }
    else if (tracker.broadcasting) { trackerState = 'is-hot'; trackerText = 'Broadcasting'; }
    else { trackerState = ''; trackerText = 'Live — kill it'; }
  }

  return `
    <div class="hw">
      <div class="hwitem ${alarmState}">
        <div class="hwitem__icon">${XS.icon.bell}</div>
        <div><b>Alarm</b><small>${alarmText}</small></div>
      </div>
      <div class="hwitem ${trackerState}">
        <div class="hwitem__icon">${XS.icon.sat}</div>
        <div><b>Tracker</b><small>${trackerText}</small></div>
      </div>
    </div>
  `;
};

XS.Job.broadcast = function () {
  return `
    <div class="broadcast">
      <div class="wave"><i></i><i></i><i></i><i></i></div>
      <div>
        <b>They can see you</b>
        <small>The tracker is feeding your position. Kill it at the car or reach a dead zone.</small>
      </div>
    </div>
  `;
};

/* The one thing a passenger can do that a driver cannot: work the tracker
   without being at the car. Only ever shown to somebody who is not holding
   the contract, because the holder can just reach over and pull it. */
XS.Job.remote = function (job) {
  if (!job.remoteTracker) return '';
  if ((job.crew || []).length < 2) return '';
  if (!job.fitted?.tracker || !job.tracker?.alive) return '';

  return `
    <div class="slab">
      <div class="slab__title">your end of it</div>
      <div class="bolo">
        <div>
          <div style="font-size:15px;font-weight:650">Work the tracker from here</div>
          <div style="font-size:12.5px;color:var(--ink-3);margin-top:4px">
            You do not need to be at the car. Keep them driving.
          </div>
        </div>
        <button class="btn btn--acc" id="jobRemote">Get into it</button>
      </div>
    </div>
  `;
};

XS.Job.parts = function (job) {
  const got = new Set(job.collected || []);

  const rows = job.parts.map((p) => `
    <div class="part ${got.has(p.id) ? 'is-got' : ''}">
      <i class="part__box">${got.has(p.id) ? XS.icon.tick : ''}</i>
      <span>${XS.esc(p.label)}</span>
    </div>
  `).join('');

  return `
    <div class="slab">
      <div class="slab__title">PARTS WANTED — ${got.size}/${job.parts.length}</div>
      <div class="parts">${rows}</div>
    </div>
  `;
};

/* Sentence case at the source. Anywhere that wants it shouted uppercases it
   in CSS, so the same string works in the status line and on the dial. */
XS.Job.stageLabel = function (stage) {
  return {
    search: 'Searching', entry: 'Breaking in', transit: 'In transit',
    sting: 'Setup', staging: 'Staging', running: 'Running', done: 'Handing over',
  }[stage] || String(stage || '');
};

/* Live numbers. The server sends how long is left at the moment it sends the
   state; the page counts down from there rather than comparing clocks, so a
   player whose machine is a few seconds out still sees the right number. */
XS.Job.seconds = function () {
  const job = XS.state.job;
  if (!job) return 0;

  const elapsed = (Date.now() - (XS.state.jobAt || Date.now())) / 1000;
  return Math.max(0, Math.round((job.remaining || 0) - elapsed));
};

XS.Job.tick = function () {
  const job = XS.state.job;
  if (!job) return;

  const clock = XS.el('#jobClock');
  if (!clock) return;

  const seconds = XS.Job.seconds();
  clock.textContent = XS.clock(seconds);

  const ring = XS.el('#ringTime');
  if (ring) {
    const limit = Math.max(1, job.limit || job.remaining || 1);
    const ratio = Math.max(0, Math.min(1, seconds / limit));
    ring.style.strokeDashoffset = String(C_TIME * (1 - ratio));
    ring.style.stroke = ratio < 0.15 ? 'var(--bad)' : ratio < 0.35 ? 'var(--warn)' : 'var(--acc)';
  }

  XS.Job.condition(job.condition ?? 100);
};

XS.Job.condition = function (value) {
  const ring = XS.el('#ringCond');
  const label = XS.el('#jobCond');
  const pct = Math.max(0, Math.min(100, value));

  if (ring) {
    ring.style.strokeDashoffset = String(C_COND * (1 - pct / 100));
    ring.style.stroke = pct < 40 ? 'var(--bad)' : pct < 70 ? 'var(--warn)' : 'var(--good)';
  }

  if (label) label.textContent = `${Math.round(pct)}%`;
};

XS.Job.telemetry = function (data) {
  if (!data) return;
  XS.state.telemetry = data;

  const speed = XS.el('#jobSpeed');
  const unit = XS.el('#jobSpeedUnit');

  if (speed) speed.textContent = String(data.speed ?? 0);
  if (unit) unit.textContent = String(data.units || 'km/h').toUpperCase();

  if (typeof data.condition === 'number') XS.Job.condition(data.condition);
};

/* ── Heist ──────────────────────────────────────────────────────────────── */

XS.Job.drawHeist = function (job) {
  const cars = (job.cars || []).map((c) => `
    <div class="part ${c.delivered ? 'is-got' : ''}">
      <i class="part__box">${c.delivered ? XS.icon.tick : ''}</i>
      <span>${XS.esc(c.label)}</span>
      ${c.plate ? `<span class="tag" style="margin-left:auto">${XS.esc(c.plate)}</span>` : ''}
    </div>
  `).join('');

  const staging = job.stage === 'staging';

  XS.render('job', `
    <div class="head">
      <div>
        <div class="head__title">heist</div>
        <div class="head__sub">${job.delivered}/${job.total} away · ${XS.esc(job.tierLabel || job.tier)}</div>
      </div>
      <div class="head__tools">
        <button class="btn btn--sm btn--bad" id="jobDrop">call it off</button>
      </div>
    </div>

    <div class="job">
      ${XS.Job.cluster({ ...job, payout: job.payout, condition: 100 })}
      <div class="jobmain">
        ${staging ? `
          <div class="note">
            <b>Staging.</b> Get your crew on the unit, then start it at the site.
            You need at least ${job.crewMin} of you. Nobody can join once it is running.
          </div>` : ''}
        <div class="slab">
          <div class="slab__title">the cars</div>
          <div class="parts">${cars}</div>
        </div>
        <div class="slab">
          <div class="slab__title">CREW — ${(job.crew || []).length}/${job.crewMax}</div>
          <div class="crewlist">
            ${(job.crew || []).map(XS.Crew.member).join('')}
          </div>
        </div>
      </div>
    </div>
  `);

  const drop = XS.el('#jobDrop');
  if (drop) drop.onclick = () => XS.post('abandon');

  XS.Job.tick();
};
