/* Crew.
 *
 * Two things live on this panel. The standing crew is who you are grouped up
 * with right now, job or no job — it survives contracts, and when one of you
 * takes something on the rest are pulled in. The seats are who is actually on
 * the live job: two on a contract, up to four on the heist.
 *
 * One button covers both. With a contract running it puts somebody into it;
 * standing around with nothing on, it builds the crew for whatever is next. */

XS.Crew = {};

XS.Crew.draw = async function () {
  const s = XS.state;
  const job = s.job;
  const heist = s.heist || {};
  const rules = s.crewRules || {};
  const crew = s.crew;

  const onJob = job?.crew || [];
  const max = job?.heist ? (job.crewMax || heist.crewMax || 4) : 2;

  const standing = crew?.members || [];
  const crewMax = crew?.max || rules.maxSize || 4;

  const seats = Array.from({ length: max }, (_, i) => {
    const member = onJob[i];
    return member
      ? `<div class="seat is-filled">${XS.icon.car}<span>${XS.esc(member.name)}</span></div>`
      : `<div class="seat"><span>empty</span></div>`;
  }).join('');

  // A heist only takes people while it is staging. A duo can pick somebody up
  // at any point, which is what makes it useful when a job goes wrong. With
  // nothing running you are building the crew instead, and only whoever
  // started it brings people in.
  const canInvite = job
    ? (!job.finished && (job.heist
      ? job.stage === 'staging' && onJob.length < max
      : (s.duo?.enabled !== false) && onJob.length < 2))
    : (rules.enabled !== false && (!crew || crew.isLeader) && standing.length < crewMax);

  let sub = 'nobody with you yet';
  if (job) sub = `${onJob.length}/${max} on this one`;
  else if (crew) sub = `${standing.length} of you, nothing running yet`;

  XS.render('crew', `
    <div class="head">
      <div>
        <div class="head__title">Crew</div>
        <div class="head__sub">${sub}</div>
      </div>
      <div class="head__tools">
        ${heist.enabled ? `<button class="btn btn--sm" id="crewHeist">call a heist</button>` : ''}
        ${canInvite ? `<button class="btn btn--acc btn--sm" id="crewFind">who is nearby</button>` : ''}
      </div>
    </div>

    ${job ? `<div class="seats" style="margin-bottom:18px">${seats}</div>` : ''}

    ${crew ? `
      <div class="slab" style="margin-bottom:16px">
        <div class="slab__head">
          <div class="slab__title">your crew</div>
          <button class="btn btn--bad btn--sm" id="crewLeave">leave</button>
        </div>
        <div class="crewlist">${standing.map(XS.Crew.standing).join('')}</div>
        ${rules.autoJoin === false ? '' : `
          <div class="note" style="margin-top:12px">
            <b>Nobody has to ask twice.</b> The moment one of you takes a
            contract, everybody here goes with it.
          </div>`}
      </div>` : ''}

    ${!job && !crew ? XS.Crew.idle() : ''}

    <div class="slab" id="crewNearbyBox" style="${canInvite ? '' : 'display:none'}">
      <div class="slab__title">standing with you</div>
      <div class="crewlist" id="crewNearbyList">
        <div class="empty" style="padding:22px"><p>press <b>who is nearby</b> to look.</p></div>
      </div>
    </div>

    ${job ? `
      <div class="slab" style="margin-top:16px">
        <div class="slab__title">on the job</div>
        <div class="crewlist">${onJob.map(XS.Crew.member).join('')}</div>
      </div>` : ''}
  `);

  const find = XS.el('#crewFind');
  if (find) find.onclick = () => XS.Crew.find();

  const call = XS.el('#crewHeist');
  if (call) call.onclick = () => XS.Crew.heist(call);

  const quit = XS.el('#crewLeave');
  if (quit) quit.onclick = () => XS.Crew.leave(quit);
};

XS.Crew.idle = function () {
  const heist = XS.state.heist || {};
  const rules = XS.state.crewRules || {};
  const rep = XS.state.rep || 0;
  const short = Math.max(0, (heist.repNeeded || 0) - rep);

  return `
    <div class="note">
      <b>Crew up first.</b> Nothing has to be running. Find somebody standing
      with you, put them on the list, and the next contract either of you takes
      pulls the rest of you into it${rules.maxSize ? ` — up to ${rules.maxSize} of you` : ''}.
      <br><br>
      <b>Two sets of hands.</b> On a normal contract a partner can work the
      tracker from the passenger seat, or from anywhere in the city, while you
      drive. On your own you have to stop and do it yourself.
      ${heist.enabled ? `<br><br><b>The heist.</b> ${heist.crewMin}–${heist.crewMax} of you,
      several cars out of one place, one window.${short > 0
    ? ` You need ${short} more rep before anyone will set one up.`
    : ' You have the rep for it.'}` : ''}
    </div>
  `;
};

XS.Crew.initials = function (name) {
  return String(name || '?').split(' ').map((p) => p[0]).join('').slice(0, 2).toUpperCase();
};

XS.Crew.standing = function (m) {
  return `
    <div class="member">
      <div class="avatar">${XS.esc(XS.Crew.initials(m.name))}</div>
      <div>
        <b>${XS.esc(m.name)}</b>
        <small>${m.leader ? 'Started the crew' : 'Crew'}</small>
      </div>
      ${m.busy ? `<span class="tag tag--warn member__role">out on one</span>` : ''}
    </div>
  `;
};

XS.Crew.member = function (m) {
  return `
    <div class="member">
      <div class="avatar">${XS.esc(XS.Crew.initials(m.name))}</div>
      <div>
        <b>${XS.esc(m.name)}</b>
        <small>${m.role === 'holder' ? 'Took the contract' : 'Crew'}</small>
      </div>
    </div>
  `;
};

XS.Crew.find = async function () {
  const box = XS.el('#crewNearbyBox');
  const list = XS.el('#crewNearbyList');
  if (box) box.style.display = '';
  if (list) list.innerHTML = `<div class="empty" style="padding:22px"><p>Looking…</p></div>`;

  const people = await XS.post('nearby');

  // No point offering somebody you are already stood with.
  const already = new Set([
    ...(XS.state.crew?.members || []).map((m) => m.src),
    ...(XS.state.job?.crew || []).map((m) => m.src),
  ]);

  XS.state.nearby = (Array.isArray(people) ? people : []).filter((p) => !already.has(p.src));

  if (!list) return;

  if (!XS.state.nearby.length) {
    list.innerHTML = `<div class="empty" style="padding:22px"><p>Nobody close enough.</p></div>`;
    return;
  }

  list.innerHTML = XS.state.nearby.map((p) => `
    <div class="member">
      <div class="avatar">${XS.esc(XS.Crew.initials(p.name))}</div>
      <div><b>${XS.esc(p.name)}</b><small>#${XS.esc(p.src)}</small></div>
      <button class="btn btn--acc btn--sm member__role" data-invite="${XS.esc(p.src)}">Ask them</button>
    </div>
  `).join('');

  XS.els('[data-invite]').forEach((btn) => {
    btn.onclick = async () => {
      btn.disabled = true;
      const res = await XS.post('invite', { src: Number(btn.dataset.invite) });
      if (res && res.ok) {
        XS.toast('Asked them.', 'good');
        btn.textContent = 'Asked';
      } else {
        XS.toast(res?.reason || 'They did not get it.', 'bad');
        btn.disabled = false;
      }
    };
  });
};

XS.Crew.leave = async function (btn) {
  btn.disabled = true;
  const res = await XS.post('crewLeave');

  if (res && res.ok) {
    XS.state.crew = null;
    XS.toast('Left the crew.', 'good');
    XS.Crew.draw();
    return;
  }

  btn.disabled = false;
  XS.toast(res?.reason || 'That did not work.', 'bad');
};

XS.Crew.heist = async function (btn) {
  btn.disabled = true;
  const res = await XS.post('heistStart');
  btn.disabled = false;

  if (!res || !res.ok) {
    XS.toast(res?.reason || 'Not right now.', 'bad');
    return;
  }

  XS.state.job = res.job || XS.state.job;
  XS.state.jobAt = Date.now();
  XS.go('job');
};
