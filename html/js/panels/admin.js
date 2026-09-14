/* Live jobs and the blunt instruments, inside the builder. */

XS.Admin = {};

XS.Admin.jobs = async function () {
  const rows = await XS.post('builderJobs');

  if (!Array.isArray(rows) || !rows.length) {
    return `<div class="empty"><h4>Nothing running</h4><p>No contracts are live right now.</p></div>`;
  }

  const body = rows.map((j) => `
    <tr>
      <td class="num">${XS.esc(j.id)}</td>
      <td>${XS.esc(j.holder)}</td>
      <td>${XS.esc(j.label)}${j.heist ? ' <span class="tag tag--warn">heist</span>' : ''}</td>
      <td>${XS.esc(j.tier)}</td>
      <td>${XS.esc(j.stage)}</td>
      <td class="num">${j.crew}</td>
      <td class="num">${j.condition}%</td>
      <td class="num">${XS.clock(j.remaining)}</td>
      <td><button class="btn btn--sm btn--bad" data-kill="${XS.esc(j.id)}">Stop</button></td>
    </tr>
  `).join('');

  return `
    <table class="table">
      <thead><tr><th>ID</th><th>Who</th><th>Job</th><th>Tier</th><th>Stage</th><th>Crew</th><th>Cond.</th><th>Left</th><th></th></tr></thead>
      <tbody>${body}</tbody>
    </table>
  `;
};

XS.Admin.bindJobs = function () {
  XS.els('[data-kill]').forEach((b) => {
    b.onclick = async () => {
      b.disabled = true;
      await XS.post('builderCancelJob', { id: b.dataset.kill });
      XS.Builder.draw();
    };
  });
};

XS.Admin.tools = function () {
  const market = (XS.state.market || []).map((r) =>
    `<span class="tag">${XS.esc(r.label)} · ${r.multiplier.toFixed(2)}×</span>`
  ).join('');

  return `
    <div class="note">
      These act immediately and affect everyone on the server. There is no undo.
    </div>

    <div class="slab" style="margin-bottom:14px">
      <div class="slab__title">THE BOARD</div>
      <p style="font-size:12.5px;color:var(--ink-3);margin-bottom:12px">
        Rebuild the listings now instead of waiting for the timer. Contracts
        already taken are left alone.
      </p>
      <button class="btn" id="tRefresh">Rebuild the board</button>
    </div>

    <div class="slab" style="margin-bottom:14px">
      <div class="slab__title">THE MARKET</div>
      <div class="card__meta" style="margin-bottom:12px">${market || '<span class="tag">flat</span>'}</div>
      <button class="btn" id="tMarket">Force a shift</button>
    </div>

    <div class="slab">
      <div class="slab__title">REP</div>
      <div class="formgrid">
        <div class="field">
          <label>SERVER ID</label>
          <input id="tRepId" type="number" placeholder="e.g. 12">
        </div>
        <div class="field">
          <label>SET REP TO</label>
          <input id="tRepVal" type="number" placeholder="e.g. 1200">
        </div>
      </div>
      <button class="btn" id="tRep">Set it</button>
    </div>
  `;
};

XS.Admin.bindTools = function () {
  XS.el('#tRefresh').onclick = async () => {
    const res = await XS.post('builderRefreshBoard');
    XS.toast(res?.ok ? 'Board rebuilt.' : 'That did not work.', res?.ok ? 'good' : 'bad');
  };

  XS.el('#tMarket').onclick = async () => {
    const res = await XS.post('builderShiftMarket');
    if (res?.ok) {
      XS.Market.update(res.market);
      XS.toast('Prices moved.', 'good');
      XS.Builder.draw();
    } else {
      XS.toast('That did not work.', 'bad');
    }
  };

  XS.el('#tRep').onclick = async () => {
    const src = Number(XS.el('#tRepId').value);
    const amount = Number(XS.el('#tRepVal').value);

    if (!src || Number.isNaN(amount)) { XS.toast('Both fields, please.', 'bad'); return; }

    const res = await XS.post('builderSetRep', { src, amount });
    XS.toast(res?.ok ? `Set to ${res.rep}.` : 'No such player.', res?.ok ? 'good' : 'bad');
  };
};

/* ── Contested contracts ─────────────────────────────────────────────────── */

XS.Admin.event = async function () {
  const e = await XS.post('builderEvent');

  if (!e) return `<div class="empty"><p>Could not read the event state.</p></div>`;

  const active = e.active;

  const status = active
    ? `
      <div class="eventcard ${active.taken ? 'is-in' : ''}" style="margin-bottom:0">
        <div class="eventcard__top">
          <span class="eventcard__tag">${active.taken ? 'Taken' : 'Running'}</span>
          <span class="eventcard__clock num">${XS.clock(active.remaining)}</span>
        </div>
        <div class="eventcard__body">
          <div>
            <div class="eventcard__name">${XS.esc(active.label)}</div>
            <div class="eventcard__meta">
              <span class="tag">${XS.esc(active.plate)}</span>
              <span class="tag">${e.joined} in on it</span>
              <span class="tag tag--bad">${active.guards} armed</span>
            </div>
          </div>
          <div class="eventcard__right">
            <div class="card__pay"><small>Pays</small><b>${XS.money(active.payout)}</b></div>
          </div>
        </div>
      </div>`
    : `<div class="empty" style="margin-bottom:14px"><h4>Nothing running</h4><p>${
        e.canStart ? 'One can be started right now.' : XS.esc(e.reason || 'Cannot start one at the moment.')
      }</p></div>`;

  return `
    <div class="note">
      Starting one puts a car up for <b>everybody on the server</b> at once.
      Stopping one removes the car and the guards and tells everyone it is off.
    </div>

    ${status}

    <div class="slab" style="margin-top:14px">
      <div class="slab__title">Controls</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button class="btn btn--acc" id="evStart" ${active || !e.canStart ? 'disabled' : ''}>Start one now</button>
        <button class="btn btn--bad" id="evStop" ${active ? '' : 'disabled'}>Call it off</button>
        <button class="btn" id="evRefresh">Refresh</button>
      </div>
      <div style="margin-top:12px;font-size:12px;color:var(--ink4)">
        ${e.auto ? `Runs automatically about every ${e.every} minutes.` : 'Automatic events are switched off — admin only.'}
        · ${e.online} online, needs ${e.needed}.
      </div>
    </div>
  `;
};

XS.Admin.bindEvent = function () {
  const refresh = () => XS.Builder.draw();

  const start = XS.el('#evStart');
  if (start) {
    start.onclick = async () => {
      start.disabled = true;
      const res = await XS.post('builderEventStart');
      if (res?.ok) XS.toast('It is up.', 'good');
      refresh();
    };
  }

  const stop = XS.el('#evStop');
  if (stop) {
    stop.onclick = async () => {
      stop.disabled = true;
      const res = await XS.post('builderEventStop');
      if (res?.ok) XS.toast('Called it off.', 'good');
      refresh();
    };
  }

  const again = XS.el('#evRefresh');
  if (again) again.onclick = refresh;
};

/* ── Lockups ─────────────────────────────────────────────────────────────── */

XS.Admin.stored = async function () {
  const rows = await XS.post('builderStored');

  if (!Array.isArray(rows) || !rows.length) {
    return `<div class="empty"><h4>Nothing parked</h4><p>No cars are sitting in a lockup right now.</p></div>`;
  }

  const body = rows.map((r) => `
    <tr>
      <td class="num">${r.id}</td>
      <td>${XS.esc(r.who)}</td>
      <td>${XS.esc(r.label)}</td>
      <td class="num">${XS.esc(r.plate)}</td>
      <td>${XS.esc(r.lockup)}</td>
      <td class="num">${r.condition}%</td>
      <td class="num">${XS.clock(r.remaining)}</td>
      <td><button class="btn btn--sm btn--bad" data-release="${r.id}">Release</button></td>
    </tr>
  `).join('');

  return `
    <div class="note">
      A parked car is a <b>paused contract</b>, not a finished one. Releasing
      one throws the car away and the player loses the job with it.
    </div>
    <table class="table">
      <thead><tr><th>ID</th><th>Who</th><th>Car</th><th>Plate</th><th>Lockup</th><th>Cond.</th><th>Left</th><th></th></tr></thead>
      <tbody>${body}</tbody>
    </table>
  `;
};

XS.Admin.bindStored = function () {
  XS.els('[data-release]').forEach((b) => {
    b.onclick = async () => {
      if (b.dataset.armed !== '1') {
        b.dataset.armed = '1';
        b.textContent = 'Sure?';
        setTimeout(() => { b.dataset.armed = '0'; b.textContent = 'Release'; }, 3000);
        return;
      }

      await XS.post('builderReleaseStored', { id: Number(b.dataset.release) });
      XS.Builder.draw();
    };
  });
};
