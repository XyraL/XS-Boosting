/* Home. What is happening, what is worth doing next, and one click to it. */

XS.Home = {};

XS.Home.draw = function () {
  const s = XS.state;
  const job = s.job;
  const stats = s.stats;

  XS.render('home', `
    ${XS.Home.hello(s, job)}
    ${job ? XS.Home.live(job) : ''}
    ${XS.Home.tiles(s, job)}
    <div class="home__split">
      <div>
        <div class="slab__title">Recent activity</div>
        ${XS.Home.feed(stats)}
      </div>
      <div>
        <div class="slab__title">Fence rates</div>
        ${XS.Home.rates(s)}
      </div>
    </div>
  `);

  XS.els('[data-go-panel]').forEach((el) => {
    el.onclick = () => XS.go(el.dataset.goPanel);
  });

  const heist = XS.el('#homeHeist');
  if (heist) heist.onclick = () => XS.Crew.heist(heist);

};

XS.Home.hello = function (s, job) {
  const open = (s.board || []).filter((c) => !c.locked).length;
  const locked = (s.board || []).length - open;

  let line;
  if (job && job.heist) {
    line = `A heist is <em>running</em>. ${job.delivered}/${job.total} away.`;
  } else if (job) {
    line = `You are holding a <em>${XS.esc(job.label)}</em>. Finish it.`;
  } else if (open > 0) {
    line = `<em>${open}</em> listing${open === 1 ? '' : 's'} you can take${locked ? `, ${locked} you cannot` : ''}.`;
  } else {
    line = `Nothing on the board worth your time.`;
  }

  return `
    <div class="home__hello">
      <div class="home__line">Overview</div>
      <div class="home__big">${line}</div>
    </div>
  `;
};

XS.Home.live = function (job) {
  const seconds = XS.Job.seconds();
  const pct = job.limit ? Math.max(0, Math.min(100, (seconds / job.limit) * 100)) : 100;

  const meta = [];
  meta.push(`<span class="tag">${XS.esc(job.tierLabel || job.tier)}</span>`);
  meta.push(`<span class="tag">${XS.esc(XS.typeLabel(job.type))}</span>`);
  if (job.plate) meta.push(`<span class="tag">${XS.esc(job.plate)}</span>`);
  if (job.tracker?.broadcasting) meta.push(`<span class="tag tag--bad">tracker live</span>`);

  return `
    <div class="livecard" data-go-panel="job">
      <div class="livecard__top">
        <span class="livecard__tag">${job.heist ? 'HEIST' : 'CONTRACT'} ACTIVE</span>
        <span class="livecard__clock num" id="homeClock">${XS.clock(seconds)}</span>
      </div>
      <div class="livecard__name">${XS.esc(job.heist ? 'Showroom job' : job.label)}</div>
      <div class="livecard__meta">${meta.join('')}</div>
      <div class="livecard__prog"><i style="width:${pct.toFixed(1)}%"></i></div>
    </div>
  `;
};

XS.Home.tiles = function (s, job) {
  const heist = s.heist || {};
  const canHeist = heist.enabled && !job && (s.rep || 0) >= (heist.repNeeded || 0);

  const tiles = [
    {
      go: 'board',
      icon: XS.icon.car,
      title: 'The board',
      sub: `${(s.board || []).filter((c) => !c.locked).length} you can take right now`,
      cta: 'browse',
    },
    {
      go: job ? 'job' : 'market',
      icon: job ? XS.icon.sat : XS.icon.chart,
      title: job ? 'Your contract' : 'Fence rates',
      sub: job ? 'Where it is and what is left' : 'What each tier is paying today',
      cta: job ? 'open' : 'check',
    },
    {
      go: 'crew',
      icon: XS.icon.users,
      title: job ? 'Bring someone' : 'Crew up',
      sub: job ? 'A second pair of hands on this one' : 'Duo work and the heist',
      cta: 'find',
    },
    {
      go: 'profile',
      icon: XS.icon.user,
      title: 'Your profile',
      sub: s.stats?.handle ? `Known as ${s.stats.handle}` : 'Nobody knows who you are',
      cta: s.stats?.handle ? 'edit' : 'set up',
    },
  ];

  const cards = tiles.map((t) => `
    <button class="tile" data-go-panel="${t.go}">
      <span class="tile__icon">${t.icon}</span>
      <span>
        <b>${XS.esc(t.title)}</b>
        <small>${XS.esc(t.sub)}</small>
      </span>
      <span class="tile__go">${XS.esc(t.cta)}</span>
    </button>
  `);

  if (canHeist) {
    cards.push(`
      <button class="tile" id="homeHeist">
        <span class="tile__icon">${XS.icon.ghost}</span>
        <span>
          <b>Call a heist</b>
          <small>${heist.crewMin}–${heist.crewMax} of you, one showroom</small>
        </span>
        <span class="tile__go">call it</span>
      </button>
    `);
  }

  return `<div class="tiles">${cards.join('')}</div>`;
};

XS.Home.feed = function (stats) {
  const rows = (stats?.history || []).slice(0, 6);

  if (!rows.length) {
    return `<div class="empty" style="padding:32px"><p>Nothing logged yet.</p></div>`;
  }

  return `<div class="feed">${rows.map((h) => {
    const lost = h.outcome === 'failed';
    return `
      <div class="feed__row ${lost ? 'lose' : 'win'}">
        <span class="feed__when">${XS.esc(XS.ago(h.created_at) || '—')}</span>
        <span class="feed__what"><b>${XS.esc(h.label || h.model || '—')}</b> · ${XS.esc(XS.Stats.outcome(h.outcome))}</span>
        <span class="feed__amt ${h.payout ? '' : 'zero'}">${h.payout ? XS.money(h.payout) : '—'}</span>
      </div>
    `;
  }).join('')}</div>`;
};

XS.Home.rates = function (s) {
  const rows = s.market || [];

  if (!rows.length) {
    return `<div class="empty" style="padding:32px"><p>Rates are flat.</p></div>`;
  }

  return `<div class="feed">${rows.map((r) => {
    const prev = s.marketPrev[r.id];
    const delta = typeof prev === 'number' ? r.multiplier - prev : 0;
    const dir = Math.abs(delta) < 0.005 ? '' : delta > 0 ? 'win' : 'lose';
    const arrow = Math.abs(delta) < 0.005 ? '·' : delta > 0 ? '▲' : '▼';

    return `
      <div class="feed__row is-tiered ${dir}" data-go-panel="market" style="cursor:pointer;--tier:${XS.tierColour(r.id)}">
        <span class="feed__when">${arrow}</span>
        <span class="feed__what"><b>${XS.esc(r.label)}</b></span>
        <span class="feed__amt ${dir ? '' : 'zero'}">${r.multiplier.toFixed(2)}×</span>
      </div>
    `;
  }).join('')}</div>`;
};
