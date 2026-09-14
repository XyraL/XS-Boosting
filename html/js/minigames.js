/* Built-in minigames. Keyboard only, so the page can take focus without a
   cursor and the player keeps looking at the world behind it.

   One shape, scaled by difficulty: a head sweeps the bar, you stop it inside
   the zone. Higher tiers mean more passes, a tighter zone, and a faster sweep.
   Config.Minigames swaps these out for ox_lib, ps-ui or your own. */

XS.Mini = { running: false };

const MG_TITLE = {
  entry: 'FORCING THE LOCK',
  hotwire: 'HOTWIRING',
  tracker: 'TRACKER',
  chop: 'STRIPPING',
};

XS.Mini.start = function (stage, difficulty) {
  if (XS.Mini.running) return;

  const level = Math.max(1, Math.min(5, Number(difficulty) || 1));
  const rounds = level;
  const zone = Math.max(8, 30 - level * 4);
  const speed = 0.55 + level * 0.22;

  const host = XS.el('#minigame');
  host.classList.remove('hidden');
  host.innerHTML = `
    <div class="mg">
      <div class="mg__title">${XS.esc(MG_TITLE[stage] || 'WORKING')}</div>
      <div class="mgpips" id="mgPips">
        ${Array.from({ length: rounds }, (_, i) => `<i class="mgpip ${i === 0 ? 'is-now' : ''}"></i>`).join('')}
      </div>
      <div class="mgbar" id="mgBar">
        <div class="mgbar__zone" id="mgZone"></div>
        <div class="mgbar__head" id="mgHead"></div>
      </div>
      <div class="mg__hint">Press <b>SPACE</b> inside the band</div>
    </div>
  `;

  XS.Mini.running = true;

  const bar = XS.el('#mgBar');
  const zoneEl = XS.el('#mgZone');
  const head = XS.el('#mgHead');
  const pips = XS.els('.mgpip');

  let round = 0;
  let position = 0;
  let direction = 1;
  let zoneStart = 0;
  let frame = null;
  let last = performance.now();
  let settled = false;

  function placeZone() {
    zoneStart = 10 + Math.random() * (80 - zone);
    zoneEl.style.left = `${zoneStart}%`;
    zoneEl.style.width = `${zone}%`;
  }

  function loop(now) {
    const dt = Math.min(48, now - last);
    last = now;

    position += direction * speed * (dt / 16);

    if (position >= 100) { position = 100; direction = -1; }
    if (position <= 0) { position = 0; direction = 1; }

    head.style.left = `${position}%`;
    frame = requestAnimationFrame(loop);
  }

  function stop() {
    if (frame) cancelAnimationFrame(frame);
    frame = null;
    window.removeEventListener('keydown', onKey);
  }

  function finish(success) {
    if (settled) return;
    settled = true;

    stop();
    bar.classList.add(success ? 'is-win' : 'is-fail');

    setTimeout(() => {
      host.classList.add('hidden');
      host.innerHTML = '';
      XS.Mini.running = false;
      XS.post('minigameResult', { success });
    }, success ? 260 : 420);
  }

  function onKey(event) {
    if (event.code !== 'Space' && event.code !== 'Enter' && event.key !== 'e' && event.key !== 'E') return;
    event.preventDefault();
    if (settled) return;

    const hit = position >= zoneStart && position <= zoneStart + zone;

    if (!hit) { finish(false); return; }

    pips[round]?.classList.remove('is-now');
    pips[round]?.classList.add('is-done');
    round += 1;

    if (round >= rounds) { finish(true); return; }

    pips[round]?.classList.add('is-now');
    placeZone();
  }

  placeZone();
  window.addEventListener('keydown', onKey);
  frame = requestAnimationFrame(loop);

  // Nobody gets to sit on it forever.
  setTimeout(() => finish(false), 4000 + rounds * 3500);
};
