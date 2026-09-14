/* What the fences are paying today. */

XS.Market = {};

const RANGE = { min: 0.75, max: 1.4 };

XS.Market.draw = function () {
  const rows = XS.state.market || [];

  if (!rows.length) {
    XS.render('market', `
      <div class="empty">
        <div class="empty__mark">${XS.icon.car}</div>
        <h4>rates are flat</h4>
        <p>Prices are switched off, so every tier pays exactly what it says on the board.</p>
      </div>
    `);
    return;
  }

  const list = rows.map((r) => {
    const prev = XS.state.marketPrev[r.id];
    const delta = typeof prev === 'number' ? r.multiplier - prev : 0;
    const dir = Math.abs(delta) < 0.005 ? 'flat' : delta > 0 ? 'up' : 'down';
    const span = RANGE.max - RANGE.min;
    const width = Math.max(2, Math.min(100, ((r.multiplier - RANGE.min) / span) * 100));

    return `
      <div class="rate" style="--tier:${XS.tierColour(r.id)}">
        <div class="rate__name">
          <b>${XS.esc(r.label)}</b>
          <small>${dir === 'flat' ? 'holding' : dir === 'up' ? 'climbing' : 'sliding'}</small>
        </div>
        <div class="rate__bar"><i style="width:${width.toFixed(1)}%"></i></div>
        <div class="rate__val">
          <b>${r.multiplier.toFixed(2)}×</b>
          <small class="${dir}">${dir === 'flat' ? '—' : `${delta > 0 ? '▲' : '▼'} ${Math.abs(delta).toFixed(2)}`}</small>
        </div>
      </div>
    `;
  }).join('');

  const shift = XS.state.marketIn;

  XS.render('market', `
    <div class="head">
      <div>
        <div class="head__title">Fence rates</div>
        <div class="head__sub">what the fences are paying${
          shift ? ` · moves again in about ${shift}m` : ''
        }</div>
      </div>
    </div>

    <div class="note">
      A contract keeps the rate it was listed at. If a tier is climbing, the
      listings that appear <b>after</b> the shift are the ones worth waiting for.
    </div>

    <div class="market">${list}</div>
  `);
};

XS.Market.update = function (rows) {
  const previous = {};
  (XS.state.market || []).forEach((r) => { previous[r.id] = r.multiplier; });

  XS.state.marketPrev = previous;
  XS.state.market = rows || [];

  XS.Market.ticker();
  if (XS.state.panel === 'market') XS.Market.draw();
};

/* The strip along the top of the unit. */
XS.Market.ticker = function () {
  const host = XS.el('#ticker');
  if (!host) return;

  const rows = XS.state.market || [];

  if (!rows.length) {
    host.innerHTML = '';
    return;
  }

  const segments = rows.map((r) => {
    const prev = XS.state.marketPrev[r.id];
    const delta = typeof prev === 'number' ? r.multiplier - prev : 0;
    const cls = Math.abs(delta) < 0.005 ? '' : delta > 0 ? 'up' : 'down';
    const arrow = Math.abs(delta) < 0.005 ? '·' : delta > 0 ? '▲' : '▼';

    return `<span><b>${XS.esc(r.label)}</b> ${r.multiplier.toFixed(2)}× <i class="${cls}">${arrow}</i></span>`;
  }).join('');

  const track = `<div class="track">${segments}</div>`;
  host.innerHTML = track + track;
};
