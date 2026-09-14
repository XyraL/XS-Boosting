/* The board. Every listing is one click; the whole card is the target. */

XS.Board = {};

XS.Board.draw = function () {
  const s = XS.state;
  const tiers = s.stats?.tiers || [];

  const filters = ['all', ...tiers.map((t) => t.id)]
    .map((id) => {
      const tier = tiers.find((t) => t.id === id);
      const label = id === 'all' ? 'All' : (tier?.label || id);
      return `<button class="chip ${s.filter === id ? 'is-on' : ''}" data-filter="${XS.esc(id)}">${XS.esc(label)}</button>`;
    })
    .join('');

  const list = s.board.filter((c) => s.filter === 'all' || c.tier === s.filter);

  const body = list.length
    ? `<div class="cards">${list.map((c, i) => XS.Board.card(c, i)).join('')}</div>`
    : XS.Board.empty();

  XS.render('board', `
    ${XS.Board.event()}
    <div class="head">
      <div>
        <div class="head__title">Board</div>
        <div class="head__sub">${list.length} listing${list.length === 1 ? '' : 's'}${
          s.refreshIn ? ` · rotates in ${Math.ceil(s.refreshIn / 60)} min` : ''
        }</div>
      </div>
      <div class="head__tools">
        <button class="btn btn--sm" id="boardRefresh">Refresh</button>
      </div>
    </div>
    <div class="chipbar" style="margin-bottom:14px">${filters}</div>
    ${body}
  `);

  XS.els('[data-filter]').forEach((btn) => {
    btn.onclick = () => { XS.state.filter = btn.dataset.filter; XS.Board.draw(); };
  });

  const refresh = XS.el('#boardRefresh');
  if (refresh) {
    refresh.onclick = async () => {
      refresh.disabled = true;
      const board = await XS.post('board');
      if (Array.isArray(board)) XS.state.board = board;
      refresh.disabled = false;
      XS.Board.draw();
    };
  }

  XS.els('[data-take]').forEach((el) => {
    el.onclick = () => XS.Board.take(el.dataset.take, el);
  });

  const join = XS.el('#eventJoin');
  if (join) {
    join.onclick = async () => {
      join.disabled = true;
      const res = await XS.post('eventJoin');
      join.disabled = false;

      if (res && res.ok) {
        XS.state.eventJoined = true;
        XS.state.event = res.event || XS.state.event;
        XS.Board.draw();
      }
    };
  }
};

/* A contested car is one shared thing everybody can see, so it gets its own
   banner above the board rather than a card among the listings. */
XS.Board.event = function () {
  const e = XS.state.event;
  if (!e) return '';

  const joined = XS.state.eventJoined;
  const pct = e.window ? Math.max(0, Math.min(100, (e.remaining / e.window) * 100)) : 100;

  return `
    <div class="eventcard ${joined ? 'is-in' : ''}">
      <div class="eventcard__top">
        <span class="eventcard__tag">Contested · everyone can see this</span>
        <span class="eventcard__clock num">${XS.clock(e.remaining)}</span>
      </div>
      <div class="eventcard__body">
        <div>
          <div class="eventcard__name">${XS.esc(e.label)}</div>
          <div class="eventcard__meta">
            <span class="tag tag--bad">${e.guards} armed</span>
            <span class="tag">${e.joined} going for it</span>
            <span class="tag">${XS.esc(e.plate)}</span>
          </div>
        </div>
        <div class="eventcard__right">
          <div class="card__pay"><small>Pays</small><b>${XS.money(e.payout)}</b></div>
          ${joined
            ? '<span class="eventcard__in">You are in</span>'
            : '<button class="btn btn--acc" id="eventJoin">Go for it</button>'}
        </div>
      </div>
      <div class="eventcard__prog"><i style="width:${pct.toFixed(1)}%"></i></div>
    </div>
  `;
};

XS.Board.card = function (c, index) {
  const colour = XS.tierColour(c.tier);
  const locked = c.locked;
  const meta = [];

  if (c.colour) {
    meta.push(`<span class="tag"><i class="swatch" style="background:${XS.Board.swatch(c.colour)}"></i>${XS.esc(c.colour)}</span>`);
  }

  if (c.minCondition) meta.push(`<span class="tag tag--warn">${c.minCondition}%+ condition</span>`);
  if (c.parts?.length) meta.push(`<span class="tag">${c.parts.length} part${c.parts.length === 1 ? '' : 's'}</span>`);

  if (c.market && Math.abs(c.market - 1) > 0.02) {
    const up = c.market > 1;
    meta.push(`<span class="tag ${up ? 'tag--acc' : 'tag--bad'}">${up ? '▲' : '▼'} ${c.market.toFixed(2)}×</span>`);
  }

  if (c.expiresIn) meta.push(`<span class="tag">${XS.clock(c.expiresIn)} left</span>`);

  const foot = locked
    ? `<span class="card__lock">${XS.icon.lock}<span>${c.repNeeded} rep</span></span>`
    : `<span class="card__take">Take<svg viewBox="0 0 24 24" style="width:13px;height:13px"><path d="M5 12h13M13 6l6 6-6 6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg></span>`;

  return `
    <article class="card ${locked ? 'is-locked' : ''}" style="--tier:${colour}"
             ${locked ? '' : `data-take="${XS.esc(c.id)}"`}>
      <div class="card__bar">
        <span class="card__path">${XS.esc(c.tierLabel || c.tier)}</span>
        <span class="card__index">#${String(index + 1).padStart(2, '0')}</span>
      </div>
      <div class="card__inner">
        <div class="card__top">
          <span class="card__type ${c.type === 'spec' ? 'is-spec' : ''}">${XS.esc(XS.typeLabel(c.type))}</span>
        </div>
        <div class="card__name">${XS.esc(c.label)}</div>
        ${meta.length ? `<div class="card__meta">${meta.join('')}</div>` : ''}
        <div class="card__foot">
          <span class="card__pay">
            <small>pays</small>
            <b>${XS.money(c.payout)}</b>
          </span>
          ${foot}
        </div>
      </div>
    </article>
  `;
};

/* Rough visual for the colour a spec order asks for. The exact GTA index is
   the server's business; this only has to be recognisable on a card. */
XS.Board.swatch = function (name) {
  return {
    Black: '#15181c', White: '#e8ebef', Red: '#c2211f', Blue: '#1f4fa8',
    Silver: '#9aa3ad', Green: '#1f7a43', Orange: '#d9711d', Yellow: '#e0c020',
  }[name] || '#7d8590';
};

XS.Board.take = async function (id, el) {
  if (el.dataset.busy === '1') return;
  el.dataset.busy = '1';

  const res = await XS.post('accept', { id });
  el.dataset.busy = '0';

  if (!res || !res.ok) {
    XS.toast(res?.reason || 'That did not work.', 'bad');
    const board = await XS.post('board');
    if (Array.isArray(board)) XS.state.board = board;
    XS.Board.draw();
    return;
  }

  el.classList.add('is-taken');

  XS.state.job = res.job || XS.state.job;
  XS.state.jobAt = Date.now();

  setTimeout(() => XS.go('job'), 260);
};

XS.Board.empty = function () {
  const built = XS.state.stats?.tiers?.length;

  return `
    <div class="empty">
      <div class="empty__mark">${XS.icon.car}</div>
      <h4>Nothing on the board</h4>
      <p>${built
        ? 'Everything has been taken or has rotted. Give it a few minutes.'
        : 'No spawn points or handover points have been placed yet, so there is nothing to list.'}</p>
    </div>
  `;
};
