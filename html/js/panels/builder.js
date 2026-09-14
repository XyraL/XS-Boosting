/* The builder. Admin only, and a different mode rather than another tab —
   nothing in here is something a player ever sees. */

XS.Builder = { tab: 'places', draft: null };

XS.Builder.open = function (payload) {
  XS.state.builder = payload;
  XS.Builder.draft = null;
  XS.el('#unit').classList.add('hidden');
  XS.el('#builder').classList.remove('hidden');
  XS.Builder.draw();
};

XS.Builder.close = function () {
  XS.el('#builder').classList.add('hidden');
  XS.el('#builder').innerHTML = '';

  // The builder hid the unit to take the screen. Give it back if the player
  // had it open, rather than leaving them looking at nothing.
  if (XS.state.open) XS.el('#unit').classList.remove('hidden');
};

XS.Builder.draw = async function () {
  const data = XS.state.builder || { locations: [], kinds: [], tiers: [] };

  const tabs = [
    ['places', 'Places'],
    ['add', XS.Builder.draft?.id ? 'Edit' : 'Add'],
    ['jobs', 'Live jobs'],
    ['event', 'Contested'],
    ['stored', 'Lockups'],
    ['tools', 'Tools'],
  ].map(([id, label]) =>
    `<button class="btab ${XS.Builder.tab === id ? 'is-on' : ''}" data-btab="${id}">${label}</button>`
  ).join('');

  let body = '';
  if (XS.Builder.tab === 'places') body = XS.Builder.places(data);
  else if (XS.Builder.tab === 'add') body = XS.Builder.form(data);
  else if (XS.Builder.tab === 'jobs') body = await XS.Admin.jobs();
  else if (XS.Builder.tab === 'event') body = await XS.Admin.event();
  else if (XS.Builder.tab === 'stored') body = await XS.Admin.stored();
  else body = XS.Admin.tools();

  XS.el('#builder').innerHTML = `
    <div class="bhead">
      <h2>Boosting — Builder</h2>
      <span class="bhead__tag">ADMIN</span>
      <div class="bhead__tools">
        <button class="btn btn--sm" id="bRefresh">Reload</button>
        <button class="btn btn--sm" id="bClose">Close</button>
      </div>
    </div>
    <div class="btabs">${tabs}</div>
    <div class="bbody">${body}</div>
  `;

  XS.els('[data-btab]').forEach((btn) => {
    btn.onclick = () => { XS.Builder.tab = btn.dataset.btab; XS.Builder.draw(); };
  });

  XS.el('#bClose').onclick = () => XS.post('builderClose');
  XS.el('#bRefresh').onclick = async () => {
    const fresh = await XS.post('builderList');
    if (fresh) XS.state.builder = fresh;
    XS.Builder.draw();
  };

  if (XS.Builder.tab === 'places') XS.Builder.bindPlaces();
  if (XS.Builder.tab === 'add') XS.Builder.bindForm();
  if (XS.Builder.tab === 'jobs') XS.Admin.bindJobs();
  if (XS.Builder.tab === 'event') XS.Admin.bindEvent();
  if (XS.Builder.tab === 'stored') XS.Admin.bindStored();
  if (XS.Builder.tab === 'tools') XS.Admin.bindTools();
};

XS.Builder.places = function (data) {
  const list = data.locations || [];

  if (!list.length) {
    return `
      <div class="note">
        <b>Nothing placed yet.</b> This resource ships empty on purpose — there
        are no coordinates from somebody else's map to delete.
        <br><br>
        The shortest path to a working server: one <b>vehicle spawn</b> for the
        first tier, and one <b>handover point</b>. That is enough for the board
        to start listing contracts. Everything else is optional.
      </div>
      <div class="empty"><h4>No places</h4><p>Use the Add tab.</p></div>
    `;
  }

  const resting = data.resting || {};

  const rows = list.map((p) => `
    <div class="place ${p.enabled ? '' : 'is-off'}">
      <span class="place__kind">${XS.esc(p.kind)}</span>
      <div>
        <b>${XS.esc(p.label || `#${p.id}`)}${p.tier ? ` · ${XS.esc(p.tier)}` : ''}${
          resting[p.id] ? ` <span class="tag tag--warn">resting ${XS.clock(resting[p.id])}</span>` : ''
        }</b>
        <small>${p.coords.x.toFixed(1)}, ${p.coords.y.toFixed(1)}, ${p.coords.z.toFixed(1)} · r${p.radius}${
          p.data?.spawns?.length ? ` · ${p.data.spawns.length} bays` : ''
        }</small>
      </div>
      <div class="place__acts">
        <button class="btn btn--sm" data-goto="${p.id}">Go</button>
        <button class="btn btn--sm" data-edit="${p.id}">Edit</button>
        <button class="btn btn--sm" data-toggle="${p.id}" data-on="${p.enabled ? 1 : 0}">${p.enabled ? 'On' : 'Off'}</button>
        <button class="btn btn--sm btn--bad" data-del="${p.id}">Delete</button>
      </div>
    </div>
  `).join('');

  const counts = {};
  list.forEach((p) => { counts[p.kind] = (counts[p.kind] || 0) + 1; });

  const summary = Object.entries(counts)
    .map(([kind, n]) => `<span class="tag">${XS.esc(kind)} · ${n}</span>`)
    .join('');

  return `<div class="card__meta" style="margin-bottom:14px">${summary}</div><div class="places">${rows}</div>`;
};

XS.Builder.bindPlaces = function () {
  const find = (id) => (XS.state.builder.locations || []).find((p) => String(p.id) === String(id));

  XS.els('[data-goto]').forEach((b) => {
    b.onclick = () => XS.post('builderGoto', { coords: find(b.dataset.goto)?.coords });
  });

  XS.els('[data-edit]').forEach((b) => {
    b.onclick = () => {
      const place = find(b.dataset.edit);
      if (!place) return;

      XS.Builder.draft = {
        id: place.id,
        kind: place.kind,
        label: place.label,
        tier: place.tier,
        radius: place.radius,
        coords: place.coords,
        heading: place.heading,
        data: place.data || {},
      };

      XS.Builder.tab = 'add';
      XS.Builder.draw();
    };
  });

  XS.els('[data-toggle]').forEach((b) => {
    b.onclick = async () => {
      const on = b.dataset.on === '1';
      await XS.post('builderToggle', { id: Number(b.dataset.toggle), enabled: !on });
      const fresh = await XS.post('builderList');
      if (fresh) XS.state.builder = fresh;
      XS.Builder.draw();
    };
  });

  XS.els('[data-del]').forEach((b) => {
    b.onclick = async () => {
      if (b.dataset.armed !== '1') {
        b.dataset.armed = '1';
        b.textContent = 'Sure?';
        setTimeout(() => { b.dataset.armed = '0'; b.textContent = 'Delete'; }, 3000);
        return;
      }

      await XS.post('builderDelete', { id: Number(b.dataset.del) });
      const fresh = await XS.post('builderList');
      if (fresh) XS.state.builder = fresh;
      XS.Builder.draw();
    };
  });
};

XS.Builder.form = function (data) {
  const draft = XS.Builder.draft || { kind: 'spawn', label: '', radius: 10, data: {} };
  const kind = data.kinds.find((k) => k.id === draft.kind) || data.kinds[0];

  const kinds = data.kinds.map((k) =>
    `<option value="${k.id}" ${draft.kind === k.id ? 'selected' : ''}>${XS.esc(k.label)}</option>`
  ).join('');

  const tiers = data.tiers.map((t) =>
    `<option value="${t.id}" ${draft.tier === t.id ? 'selected' : ''}>${XS.esc(t.label)}</option>`
  ).join('');

  const placed = draft.coords
    ? `${draft.coords.x.toFixed(2)}, ${draft.coords.y.toFixed(2)}, ${draft.coords.z.toFixed(2)}`
    : 'not placed yet';

  return `
    <div class="note">
      ${XS.Builder.hint(draft.kind)}
    </div>

    <div class="formgrid">
      <div class="field">
        <label>WHAT IS IT</label>
        <select id="fKind">${kinds}</select>
      </div>
      <div class="field">
        <label>NAME</label>
        <input id="fLabel" type="text" value="${XS.esc(draft.label || '')}" placeholder="Anything you like">
      </div>
      ${kind?.tiered ? `
        <div class="field">
          <label>TIER</label>
          <select id="fTier">${tiers}</select>
        </div>
        <div class="field">
          <label>PREVIEW CAR</label>
          <select id="fCar">${XS.Builder.cars(data, draft)}</select>
        </div>` : ''}
      <div class="field">
        <label>RADIUS (M)</label>
        <input id="fRadius" type="number" min="1" max="200" value="${draft.radius || 10}">
      </div>
    </div>

    <div class="field">
      <label>POSITION</label>
      <div style="display:flex;gap:8px;align-items:center">
        <button class="btn" id="fPlace">${draft.coords ? 'Move it' : 'Place it'}</button>
        <span class="num" style="color:var(--ink-3);font-size:12px">${XS.esc(placed)}</span>
      </div>
    </div>

    ${draft.kind === 'heist' ? `
      <div class="field">
        <label>CAR BAYS</label>
        <div style="display:flex;gap:8px;align-items:center">
          <button class="btn" id="fBays">Place the bays</button>
          <span class="num" style="color:var(--ink-3);font-size:12px">${
            draft.data?.spawns?.length ? `${draft.data.spawns.length} placed` : 'none yet'
          }</span>
        </div>
      </div>` : ''}

    <div style="display:flex;gap:8px;margin-top:20px">
      <button class="btn btn--acc" id="fSave">${draft.id ? 'Save changes' : 'Add it'}</button>
      ${draft.id ? `<button class="btn" id="fNew">Start a new one</button>` : ''}
    </div>
  `;
};

XS.Builder.hint = function (kind) {
  return {
    spawn: '<b>Vehicle spawn.</b> Somewhere a target car can appear. Tag it with a tier — a spawn tagged Street can host any Street car. Place these where a car would actually be parked, and place plenty: the search zone is only interesting when there are lots of candidates.',
    buyer: '<b>Handover point.</b> Where a finished car is handed over. The board cannot list anything until at least one of these exists.',
    chop: '<b>Chop shop.</b> Strip a car for parts, or bail out of a job gone wrong at a worse rate. Put it somewhere quiet.',
    lockup: '<b>Lockup.</b> Park a car mid-contract to stop the clock and come back for it, or pay to keep it for good. Somewhere off the street.',
    fence: '<b>Street fence.</b> Takes anything, in any state, at a bad rate and for no rep.',
    deadzone: '<b>Dead zone.</b> Somewhere a live tracker can be killed on the move — a tunnel, an underground car park, a basement.',
    heist: '<b>Heist site.</b> The showroom. Place the site itself, then place a bay for each car it should hold.',
    heist_exit: '<b>Heist exit.</b> Every car has to be driven out through here. One per site is plenty; the nearest one to a site is the one it uses.',
  }[kind] || '';
};

XS.Builder.bindForm = function () {
  const draft = XS.Builder.draft || { kind: 'spawn', label: '', radius: 10, data: {} };
  XS.Builder.draft = draft;

  const read = () => {
    draft.label = XS.el('#fLabel')?.value || '';
    draft.radius = Number(XS.el('#fRadius')?.value) || 10;

    const tier = XS.el('#fTier');
    if (tier) draft.tier = tier.value;

    const car = XS.el('#fCar');
    if (car) draft.car = car.value;
  };

  XS.el('#fKind').onchange = (e) => {
    read();
    draft.kind = e.target.value;
    XS.Builder.draw();
  };

  const tierPick = XS.el('#fTier');
  if (tierPick) {
    tierPick.onchange = (e) => {
      read();
      draft.tier = e.target.value;
      // The car list belongs to the tier, so it has to be rebuilt with it.
      draft.car = null;
      XS.Builder.draw();
    };
  }

  XS.el('#fPlace').onclick = async () => {
    read();
    const res = await XS.post('builderPlace', {
      kind: draft.kind,
      radius: draft.radius,
      model: draft.kind === 'spawn' ? XS.Builder.sampleModel(XS.state.builder, draft) : null,
    });

    if (!res) return;

    draft.coords = res.coords;
    draft.heading = res.heading;
    draft.radius = res.radius || draft.radius;
    XS.Builder.draw();
  };

  const bays = XS.el('#fBays');
  if (bays) {
    bays.onclick = async () => {
      read();
      const res = await XS.post('builderHeistSpawns', { model: XS.Builder.sampleModel(XS.state.builder, draft) });
      if (!res || !res.spawns?.length) return;

      draft.data = draft.data || {};
      draft.data.spawns = res.spawns;
      XS.Builder.draw();
    };
  }

  const fresh = XS.el('#fNew');
  if (fresh) {
    fresh.onclick = () => { XS.Builder.draft = null; XS.Builder.draw(); };
  }

  XS.el('#fSave').onclick = async () => {
    read();

    if (!draft.coords) { XS.toast('Place it somewhere first.', 'bad'); return; }
    if (draft.kind === 'spawn' && !draft.tier) {
      draft.tier = XS.state.builder.tiers?.[0]?.id;
    }

    const res = await XS.post('builderSave', draft);

    if (!res || !res.ok) { XS.toast(res?.reason || 'That did not save.', 'bad'); return; }

    XS.toast('Saved.', 'good');
    XS.Builder.draft = null;

    const list = await XS.post('builderList');
    if (list) XS.state.builder = list;

    XS.Builder.tab = 'places';
    XS.Builder.draw();
  };
};

/* The cars this tier can actually spawn, so the ghost you aim with is one of
   the ones that will really turn up here. */
XS.Builder.cars = function (data, draft) {
  const tier = (data.tiers || []).find((t) => t.id === draft.tier) || (data.tiers || [])[0];
  const mine = tier?.vehicles || [];
  const all = data.allCars || [];

  const opt = (v) =>
    `<option value="${XS.esc(v.model)}" ${draft.car === v.model ? 'selected' : ''}>${XS.esc(v.label)} — ${XS.esc(v.model)}</option>`;

  if (!mine.length && !all.length) {
    return '<option value="">No vehicles on this tier</option>';
  }

  // The tier's own cars first, because those are the ones that will really
  // turn up here. Everything else is below for checking whether a big one fits.
  const groups = [];

  if (mine.length) {
    groups.push(`<optgroup label="This tier (${mine.length})">${mine.map(opt).join('')}</optgroup>`);
  }

  if (all.length) {
    const own = new Set(mine.map((v) => v.model));
    const rest = all.filter((v) => !own.has(v.model));

    if (rest.length) {
      groups.push(`<optgroup label="Everything on the server (${rest.length})">${rest.map(opt).join('')}</optgroup>`);
    }
  }

  return groups.join('');
};

XS.Builder.sampleModel = function (data, draft) {
  if (draft.car) return draft.car;

  const tier = (data.tiers || []).find((t) => t.id === draft.tier) || (data.tiers || [])[0];
  return tier?.vehicles?.[0]?.model || 'sultan';
};
