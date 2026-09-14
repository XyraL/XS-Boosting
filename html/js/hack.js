/* The ECU handshake.
   Killing a tracker is not a skill check. The unit dumps the ECU's address
   space, you enter the addresses it wants in the order it wants them, and a
   trace runs the whole time. Wrong address, the trace jumps.

   Used at the car and at a dead zone alike — same job, same sequence. */

XS.Hack = { running: false };

const HEX = '0123456789ABCDEF';

function address() {
  return HEX[Math.floor(Math.random() * 16)] + HEX[Math.floor(Math.random() * 16)];
}

XS.Hack.start = function (difficulty) {
  if (XS.Hack.running) return;

  const cfg = XS.state.hack || {};
  const level = Math.max(1, Math.min(5, Number(difficulty) || 1));

  const size = Math.min(6, (cfg.gridBase ?? 3) + level);
  const wanted = Math.min(6, (cfg.codesBase ?? 1) + level);
  const seconds = Math.max(6, (cfg.seconds ?? 22) + (cfg.secondsPerLevel ?? -3) * (level - 1));
  const penalty = cfg.penaltySeconds ?? 3;

  // Unique addresses, so a target can never appear in two cells.
  const cells = [];
  const seen = new Set();
  while (cells.length < size * size) {
    const code = address();
    if (seen.has(code)) continue;
    seen.add(code);
    cells.push(code);
  }

  const pool = [...cells];
  const targets = [];
  for (let i = 0; i < wanted; i += 1) {
    const pick = Math.floor(Math.random() * pool.length);
    targets.push(pool.splice(pick, 1)[0]);
  }

  const host = XS.el('#minigame');
  host.classList.remove('hidden');
  host.innerHTML = `
    <div class="hack">
      <div class="hack__top">
        <div>
          <div class="hack__title">ECU HANDSHAKE</div>
          <div class="hack__sub" id="hackStatus">Enter the sequence in order</div>
        </div>
        <div class="hack__trace">
          <span>TRACE</span>
          <div class="hack__tracebar"><i id="hackTrace"></i></div>
          <b class="num" id="hackClock">${seconds.toFixed(0)}s</b>
        </div>
      </div>

      <div class="hack__seq" id="hackSeq">
        ${targets.map((t, i) => `<span class="seqchip ${i === 0 ? 'is-now' : ''}" data-seq="${i}">${t}</span>`).join('')}
      </div>

      <div class="hack__grid" style="grid-template-columns:repeat(${size},1fr)">
        ${cells.map((c) => `<button class="addr" data-addr="${c}">${c}</button>`).join('')}
      </div>

      <div class="hack__foot">Wrong address costs you ${penalty}s of trace</div>
    </div>
  `;

  XS.Hack.running = true;

  const traceBar = XS.el('#hackTrace');
  const clock = XS.el('#hackClock');
  const status = XS.el('#hackStatus');

  let step = 0;
  let elapsed = 0;
  let settled = false;
  let last = performance.now();
  let frame = null;

  function finish(success) {
    if (settled) return;
    settled = true;

    if (frame) cancelAnimationFrame(frame);
    XS.els('.addr').forEach((b) => { b.disabled = true; });

    const panel = XS.el('.hack');
    panel.classList.add(success ? 'is-win' : 'is-fail');
    status.textContent = success ? 'Tracker is dead.' : 'Traced. It stayed up.';

    setTimeout(() => {
      host.classList.add('hidden');
      host.innerHTML = '';
      XS.Hack.running = false;
      XS.post('hackResult', { success });
    }, success ? 500 : 700);
  }

  function loop(now) {
    elapsed += (now - last) / 1000;
    last = now;

    const ratio = Math.min(1, elapsed / seconds);
    traceBar.style.width = `${ratio * 100}%`;
    clock.textContent = `${Math.max(0, seconds - elapsed).toFixed(0)}s`;

    if (ratio > 0.7) traceBar.classList.add('is-hot');

    if (ratio >= 1) { finish(false); return; }
    frame = requestAnimationFrame(loop);
  }

  XS.els('.addr').forEach((btn) => {
    btn.onclick = () => {
      if (settled) return;

      if (btn.dataset.addr === targets[step]) {
        btn.classList.add('is-got');
        btn.disabled = true;

        const chip = XS.el(`[data-seq="${step}"]`);
        if (chip) { chip.classList.remove('is-now'); chip.classList.add('is-done'); }

        step += 1;

        if (step >= targets.length) { finish(true); return; }

        const next = XS.el(`[data-seq="${step}"]`);
        if (next) next.classList.add('is-now');
        status.textContent = `${targets.length - step} to go`;
        return;
      }

      btn.classList.add('is-wrong');
      setTimeout(() => btn.classList.remove('is-wrong'), 320);
      elapsed += penalty;
      status.textContent = 'Wrong address.';
    };
  });

  frame = requestAnimationFrame(loop);
};
