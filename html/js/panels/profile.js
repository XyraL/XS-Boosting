/* Profile. The only thing about you anybody else can see, so it is the only
   thing you get to choose. Character names never appear anywhere. */

XS.Profile = {};

XS.Profile.draw = async function (refresh) {
  if (refresh !== false) {
    const fresh = await XS.post('stats');
    if (fresh) XS.state.stats = fresh;
  }

  const stats = XS.state.stats;

  if (!stats) {
    XS.render('profile', `<div class="empty"><p>Nothing to show yet.</p></div>`);
    return;
  }

  const rules = stats.handles || {};
  const allowUrl = !!stats.profile?.allowCustomImages;

  XS.render('profile', `
    <div class="head">
      <div>
        <div class="head__title">Profile</div>
        <div class="head__sub">What the rest of the city sees</div>
      </div>
    </div>

    <div class="profile">
      <div class="identity">
        <div class="avatar avatar--lg" id="pfFace">${XS.Avatars.render(stats.avatar, stats.display)}</div>
        <div>
          <div class="identity__label">known as</div>
          <div class="identity__name" id="pfName">${XS.esc(stats.display)}</div>
          <div class="identity__hint">${stats.tagline
            ? XS.esc(stats.tagline)
            : (stats.handle ? 'No line under your name yet.' : 'Nobody knows who you are yet.')}</div>
        </div>
        <div class="identity__edit">
          <input id="pfHandle" type="text" maxlength="${rules.maxLength || 18}"
                 placeholder="${stats.handle ? 'change handle' : 'pick a handle'}"
                 value="${XS.esc(stats.handle || '')}">
          <button class="btn btn--acc btn--sm" id="pfSaveHandle">set</button>
        </div>
      </div>

      <div class="slab">
        <div class="slab__title">your line</div>
        <div class="identity__edit" style="width:100%">
          <input id="pfTagline" type="text" maxlength="${stats.profile?.taglineMax || 48}"
                 style="flex:1;width:auto"
                 placeholder="something short under your name"
                 value="${XS.esc(stats.tagline || '')}">
          <button class="btn btn--sm" id="pfSaveTagline">save</button>
        </div>
      </div>

      <div class="slab">
        <div class="slab__title">picture</div>
        <div class="avatars" id="pfAvatars">
          ${XS.Avatars.ids().map((id) => `
            <button class="avopt ${stats.avatar === id ? 'is-on' : ''}" data-av="${id}">
              ${XS.Avatars.svg(id)}
            </button>
          `).join('')}
        </div>

        ${allowUrl ? `
          <div style="margin-top:14px">
            <div class="slab__title">or a link</div>
            <div class="identity__edit" style="width:100%">
              <input id="pfUrl" type="text" style="flex:1;width:auto"
                     placeholder="https://..."
                     value="${XS.Avatars.isBuiltin(stats.avatar) ? '' : XS.esc(stats.avatar || '')}">
              <button class="btn btn--sm" id="pfSaveUrl">use</button>
            </div>
          </div>` : `
          <div class="note" style="margin:14px 0 0">
            Custom image links are switched off on this server. Pick one above.
          </div>`}
      </div>

      <div class="grid4">
        <div class="stat"><b>${stats.rep}</b><small>REP</small></div>
        <div class="stat"><b>${stats.completed}</b><small>DELIVERED</small></div>
        <div class="stat"><b>${stats.chopped}</b><small>CHOPPED</small></div>
        <div class="stat"><b>${stats.heists}</b><small>HEISTS</small></div>
      </div>
    </div>
  `);

  XS.Profile.bind();
};

XS.Profile.bind = function () {
  const handle = XS.el('#pfHandle');
  const saveHandle = XS.el('#pfSaveHandle');

  const submitHandle = async () => {
    const value = handle.value.trim();
    if (!value) return;

    saveHandle.disabled = true;
    const res = await XS.post('setHandle', { handle: value });
    saveHandle.disabled = false;

    if (!res || !res.ok) { XS.toast(res?.reason || 'That name will not do.', 'bad'); return; }

    XS.state.stats.handle = res.handle;
    XS.state.stats.display = res.handle;
    XS.toast('That is you now.', 'good');
    XS.Profile.draw(false);
    XS.paintMe();
  };

  saveHandle.onclick = submitHandle;
  handle.onkeydown = (e) => { if (e.key === 'Enter') submitHandle(); };

  const tagline = XS.el('#pfTagline');
  const saveTagline = XS.el('#pfSaveTagline');

  const submitTagline = async () => {
    saveTagline.disabled = true;
    const res = await XS.post('setTagline', { tagline: tagline.value.trim() });
    saveTagline.disabled = false;

    if (!res || !res.ok) { XS.toast(res?.reason || 'That will not do.', 'bad'); return; }

    XS.state.stats.tagline = res.tagline;
    XS.toast('Saved.', 'good');
    XS.Profile.draw(false);
    XS.paintMe();
  };

  saveTagline.onclick = submitTagline;
  tagline.onkeydown = (e) => { if (e.key === 'Enter') submitTagline(); };

  XS.els('[data-av]').forEach((btn) => {
    btn.onclick = () => XS.Profile.setAvatar(btn.dataset.av);
  });

  const url = XS.el('#pfUrl');
  const saveUrl = XS.el('#pfSaveUrl');

  if (url && saveUrl) {
    const submitUrl = () => XS.Profile.setAvatar(url.value.trim());
    saveUrl.onclick = submitUrl;
    url.onkeydown = (e) => { if (e.key === 'Enter') submitUrl(); };
  }
};

XS.Profile.setAvatar = async function (value) {
  if (!value) return;

  const res = await XS.post('setAvatar', { avatar: value });

  if (!res || !res.ok) { XS.toast(res?.reason || 'That picture will not do.', 'bad'); return; }

  XS.state.stats.avatar = res.avatar;
  XS.toast('Picture set.', 'good');
  XS.Profile.draw(false);
  XS.paintMe();
};
