/* Record: who you are on the board, what you have unlocked, and who is ahead. */

XS.Stats = {};

XS.Stats.tab = 'you';

XS.Stats.draw = async function (refresh) {
  if (refresh !== false) {
    const fresh = await XS.post('stats');
    if (fresh) XS.state.stats = fresh;
  }

  const stats = XS.state.stats;

  if (!stats) {
    XS.render('record', `<div class="empty"><p>Nothing to show yet.</p></div>`);
    return;
  }

  let body = '';
  if (XS.Stats.tab === 'board') body = await XS.Stats.leaderboard();
  else if (XS.Stats.tab === 'unlocks') body = XS.Stats.unlocks(stats);
  else body = XS.Stats.you(stats);

  XS.render('record', `
    <div class="head">
      <div>
        <div class="head__title">Record</div>
        <div class="head__sub">${stats.completed} done · ${stats.failed} lost · ${XS.money(stats.earned)} through your hands</div>
      </div>
      <div class="head__tools">
        <div class="chipbar">
          <button class="chip ${XS.Stats.tab === 'you' ? 'is-on' : ''}" data-tab="you">you</button>
          <button class="chip ${XS.Stats.tab === 'unlocks' ? 'is-on' : ''}" data-tab="unlocks">unlocks</button>
          <button class="chip ${XS.Stats.tab === 'board' ? 'is-on' : ''}" data-tab="board">top of the city</button>
        </div>
      </div>
    </div>
    ${body}
  `);

  XS.els('[data-tab]').forEach((btn) => {
    btn.onclick = () => { XS.Stats.tab = btn.dataset.tab; XS.Stats.draw(false); };
  });

};

/* ── You ────────────────────────────────────────────────────────────────── */

XS.Stats.you = function (stats) {
  const next = stats.nextTier;
  const earned = (stats.unlocks || []).filter((u) => u.earned).length;
  const total = (stats.unlocks || []).length;

  const ladder = (stats.tiers || []).map((t) => {
    const on = stats.tier && stats.tier.id === t.id;

    return `
      <div class="rung ${on ? 'is-on' : ''} ${t.unlocked ? '' : 'is-locked'}" style="--tier:${XS.tierColour(t.id)}">
        <div class="rung__mark">${t.unlocked ? XS.icon.tick : XS.icon.lock}</div>
        <div>
          <b>${XS.esc(t.label)}</b>
          <small>${XS.esc(t.description || `${t.vehicles} vehicle${t.vehicles === 1 ? '' : 's'}`)}</small>
        </div>
        <div class="rung__need">${t.unlocked ? `${t.market.toFixed(2)}×` : `${t.repNeeded} rep`}</div>
      </div>
    `;
  }).join('');

  const history = (stats.history || []).map((h) => `
    <tr>
      <td>${XS.esc(h.label || h.model)}</td>
      <td>${XS.esc(XS.typeLabel(h.type))}</td>
      <td class="${h.outcome === 'failed' ? 'lose' : 'win'}">${XS.esc(XS.Stats.outcome(h.outcome))}</td>
      <td class="num">${h.condition ? `${h.condition}%` : '—'}</td>
      <td class="num">${h.payout ? XS.money(h.payout) : '—'}</td>
      <td class="num">${XS.esc(XS.ago(h.created_at))}</td>
    </tr>
  `).join('');

  return `
    <div class="grid4">
      <div class="stat"><b>${stats.rep}</b><small>REP</small></div>
      <div class="stat"><b>${stats.completed}</b><small>DELIVERED</small></div>
      <div class="stat"><b>${stats.chopped}</b><small>CHOPPED</small></div>
      <div class="stat"><b>${earned}<span style="font-size:15px;color:var(--ink-4)">/${total}</span></b><small>UNLOCKS</small></div>
    </div>

    ${next ? `<div class="note"><b>${XS.esc(next.label)}</b> opens up in ${next.remaining} more rep.</div>` : ''}

    <div class="ladder">${ladder}</div>

    <div class="slab">
      <div class="slab__title">what you have been doing</div>
      ${history ? `
        <table class="table">
          <thead><tr><th>Car</th><th>Job</th><th>Outcome</th><th>Cond.</th><th>Paid</th><th>When</th></tr></thead>
          <tbody>${history}</tbody>
        </table>` : `<div class="empty" style="padding:26px"><p>Nothing yet.</p></div>`}
    </div>
  `;
};

/* ── Unlocks ────────────────────────────────────────────────────────────── */

const UNLOCK_KIND = {
  completed: 'delivered',
  chopped: 'chopped',
  heists: 'heists',
  rep: 'rep',
  earned: 'earned',
};

XS.Stats.unlocks = function (stats) {
  const list = stats.unlocks || [];

  if (!list.length) {
    return `<div class="empty"><h4>no unlocks</h4><p>This server has them switched off.</p></div>`;
  }

  const earned = list.filter((u) => u.earned);
  const locked = list.filter((u) => !u.earned);

  const card = (u) => {
    const pct = u.need > 0 ? Math.min(100, (u.have / u.need) * 100) : 100;
    const value = u.kind === 'earned' ? XS.money(u.have) : u.have;
    const goal = u.kind === 'earned' ? XS.money(u.need) : u.need;

    return `
      <div class="unlock ${u.earned ? 'is-got' : ''}">
        <div class="unlock__mark">${u.earned ? XS.icon.tick : XS.icon.lock}</div>
        <div class="unlock__body">
          <b>${XS.esc(u.label)}</b>
          <small>${XS.esc(u.description)}</small>
          <div class="unlock__effect">${XS.esc(u.effect || '')}</div>
        </div>
        <div class="unlock__meter">
          ${u.earned
            ? `<span class="unlock__done">EARNED</span>`
            : `<div class="unlock__bar"><i style="width:${pct.toFixed(1)}%"></i></div>
               <span class="num">${value} / ${goal} ${XS.esc(UNLOCK_KIND[u.kind] || u.kind)}</span>`}
        </div>
      </div>
    `;
  };

  return `
    <div class="note">
      Nothing here is bought. Cross the line and it is yours, permanently, and
      everything of the same kind stacks.
    </div>

    ${earned.length ? `
      <div class="slab__title" style="margin:18px 0 10px">YOURS — ${earned.length}</div>
      <div class="unlocks">${earned.map(card).join('')}</div>` : ''}

    ${locked.length ? `
      <div class="slab__title" style="margin:22px 0 10px">STILL TO COME</div>
      <div class="unlocks">${locked.map(card).join('')}</div>` : ''}
  `;
};

XS.Stats.outcome = function (outcome) {
  return {
    buyer: 'Handed over', chop: 'Chopped', fence: 'Fenced', failed: 'Lost',
    heist: 'Heist', partial: 'Part paid', kept: 'Kept it', event: 'Won it',
  }[outcome] || outcome;
};

/* ── Leaderboard ────────────────────────────────────────────────────────── */

XS.Stats.leaderboard = async function () {
  const rows = await XS.post('leaderboard');

  if (!Array.isArray(rows) || !rows.length) {
    return `<div class="empty"><p>Nobody has finished anything yet.</p></div>`;
  }

  const body = rows.map((r) => `
    <tr>
      <td><span class="rank ${r.rank <= 3 ? 'is-top' : ''}">${r.rank}</span></td>
      <td>
        <span class="lbname">
          <span class="lbface">${XS.Avatars.render(r.avatar, r.name)}</span>
          <span class="${r.named === false ? 'anon' : ''}">${XS.esc(r.name)}</span>
        </span>
      </td>
      <td class="num">${r.rep}</td>
      <td class="num">${r.completed}</td>
      <td class="num">${r.chopped}</td>
      <td class="num">${r.heists}</td>
      <td class="num">${XS.money(r.earned)}</td>
    </tr>
  `).join('');

  return `
    <div class="note">
      Nobody's character name is on this. People are known by whatever they
      chose to be known by, which you set on your <b>profile</b>.
    </div>
    <div class="slab">
      <table class="table">
        <thead><tr><th></th><th>Known as</th><th>Rep</th><th>Done</th><th>Chopped</th><th>Heists</th><th>Earned</th></tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
  `;
};
