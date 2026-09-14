/* Settings. Everything here is per-character and saved on the server, so it
   follows the player rather than the machine they happen to be sat at. */

XS.Settings = {};

const THEMES = [
  { id: 'blue',    label: 'Blue',    a: '#4d8dff', b: '#2c63cc' },
  { id: 'ice',     label: 'Ice',     a: '#38bdf8', b: '#1d84b5' },
  { id: 'violet',  label: 'Violet',  a: '#a78bfa', b: '#6d4fd1' },
  { id: 'emerald', label: 'Emerald', a: '#3dd68c', b: '#1f9c63' },
  { id: 'amber',   label: 'Amber',   a: '#f5b94a', b: '#c08320' },
  { id: 'crimson', label: 'Crimson', a: '#ff5c72', b: '#c32c43' },
];

XS.Settings.draw = function () {
  const s = XS.state.settings;

  XS.render('settings', `
    <div class="head">
      <div>
        <div class="head__title">Settings</div>
        <div class="head__sub">Saved to your character, not this machine</div>
      </div>
    </div>

    <div class="settings">

      <div class="setgroup">
        <div class="setgroup__head">
          <b>Appearance</b>
          <small>Applies to every screen in here, and to the HUD.</small>
        </div>
        <div class="setrow">
          <div>
            <b>Accent colour</b>
            <small>Picks the colour used for actions, the active tab and the HUD rail.</small>
          </div>
          <div class="themes">
            ${THEMES.map((t) => `
              <button class="themeopt ${s.theme === t.id ? 'is-on' : ''}" data-theme-opt="${t.id}" title="${t.label}">
                <span style="background:linear-gradient(145deg, ${t.a}, ${t.b})"></span>
              </button>
            `).join('')}
          </div>
        </div>
        <div class="setrow">
          <div>
            <b>Start-up animation</b>
            <small>The short loading sequence when the unit is opened.</small>
          </div>
          <button class="sw ${s.boot !== false ? 'is-on' : ''}" data-toggle="boot" aria-label="Start-up animation"></button>
        </div>
      </div>

      <div class="setgroup">
        <div class="setgroup__head">
          <b>On-screen display</b>
          <small>The panel that sits at the edge of your screen while a contract is running.</small>
        </div>
        <div class="setrow">
          <div>
            <b>Show the HUD</b>
            <small>Plate, model, stage, condition and live alerts, without opening anything.</small>
          </div>
          <button class="sw ${s.hud !== false ? 'is-on' : ''}" data-toggle="hud" aria-label="Show the HUD"></button>
        </div>
        <div class="setrow">
          <div>
            <b>Which side</b>
            <small>Move it out of the way of whatever else you run.</small>
          </div>
          <div class="seg">
            <button class="${s.hudSide !== 'right' ? 'is-on' : ''}" data-side-opt="left">Left</button>
            <button class="${s.hudSide === 'right' ? 'is-on' : ''}" data-side-opt="right">Right</button>
          </div>
        </div>
      </div>

      <div class="setgroup">
        <div class="setgroup__head">
          <b>Notifications</b>
          <small>What gets your attention, and how loudly.</small>
        </div>
        <div class="setrow">
          <div>
            <b>Job alerts</b>
            <small>Alarms, trackers going live, police being called. Shown on the HUD.</small>
          </div>
          <button class="sw ${s.alerts !== false ? 'is-on' : ''}" data-toggle="alerts" aria-label="Job alerts"></button>
        </div>
        <div class="setrow">
          <div>
            <b>Game notifications</b>
            <small>The pop-ups your framework shows in the corner of the screen.</small>
          </div>
          <button class="sw ${s.notify !== false ? 'is-on' : ''}" data-toggle="notify" aria-label="Game notifications"></button>
        </div>
        <div class="setrow">
          <div>
            <b>In-app messages</b>
            <small>The small confirmations inside this interface.</small>
          </div>
          <button class="sw ${s.toasts !== false ? 'is-on' : ''}" data-toggle="toasts" aria-label="In-app messages"></button>
        </div>
        <div class="setrow">
          <div>
            <b>Sound</b>
            <small>Cues while working a car, and clicks in here.</small>
          </div>
          <button class="sw ${s.sounds !== false ? 'is-on' : ''}" data-toggle="sounds" aria-label="Sound"></button>
        </div>
      </div>

      <div class="setgroup">
        <div class="setgroup__head">
          <b>Profile</b>
          <small>Your handle, picture and the line under your name.</small>
        </div>
        <div class="setrow">
          <div>
            <b>${XS.esc(XS.state.stats?.display || 'Not set')}</b>
            <small>${XS.esc(XS.state.stats?.tagline || 'No line set yet.')}</small>
          </div>
          <button class="btn btn--sm" data-go-panel="profile">Edit profile</button>
        </div>
      </div>

    </div>
  `);

  XS.els('[data-theme-opt]').forEach((btn) => {
    btn.onclick = () => XS.Settings.set('theme', btn.dataset.themeOpt);
  });

  XS.els('[data-side-opt]').forEach((btn) => {
    btn.onclick = () => XS.Settings.set('hudSide', btn.dataset.sideOpt);
  });

  XS.els('[data-toggle]').forEach((btn) => {
    btn.onclick = () => XS.Settings.set(btn.dataset.toggle, !btn.classList.contains('is-on'));
  });

  XS.els('[data-go-panel]').forEach((btn) => {
    btn.onclick = () => XS.go(btn.dataset.goPanel);
  });
};

XS.Settings.set = async function (key, value) {
  const before = XS.state.settings[key];
  XS.state.settings[key] = value;

  // Apply first so it feels instant, then persist. If the server refuses it
  // we put it back rather than leaving the screen lying.
  XS.Settings.apply();
  XS.Settings.draw();

  const res = await XS.post('setSetting', { key, value });

  if (!res || !res.ok) {
    XS.state.settings[key] = before;
    XS.Settings.apply();
    XS.Settings.draw();
    XS.toast(res?.reason || 'That setting would not save.', 'bad');
  }
};

/* Anything that has to happen the moment a setting changes. */
XS.Settings.apply = function () {
  XS.theme(XS.state.settings.theme);
  XS.Hud.sync();
};
