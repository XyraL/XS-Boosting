/* Built-in avatars. Drawn here rather than fetched, so a fresh server has a
   full set with nothing to host and nothing to moderate.

   An avatar value is either "bi:N" for one of these, or a URL when the server
   has allowed custom images. Anything unrecognised falls back to initials. */

XS.Avatars = {};

const HUES = [152, 190, 44, 12, 280, 320, 96, 210, 0, 258, 168, 32];

/* Twelve marks. Each is a glyph on a tinted field — abstract on purpose, so
   nobody's avatar is a recognisable badge of anything. */
const GLYPHS = [
  '<path d="M10 30 L20 10 L30 30 Z" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linejoin="round"/>',
  '<circle cx="20" cy="20" r="9" fill="none" stroke="currentColor" stroke-width="2.6"/><circle cx="20" cy="20" r="3" fill="currentColor"/>',
  '<path d="M11 11h18v18h-18z" fill="none" stroke="currentColor" stroke-width="2.6"/><path d="M11 20h18M20 11v18" stroke="currentColor" stroke-width="1.4"/>',
  '<path d="M20 9 L30 20 L20 31 L10 20 Z" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linejoin="round"/>',
  '<path d="M10 26 L16 14 L24 24 L30 12" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/>',
  '<path d="M12 12 L28 28M28 12 L12 28" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/>',
  '<path d="M20 10v20M12 15l8-5 8 5M12 25l8 5 8-5" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
  '<circle cx="15" cy="15" r="5" fill="none" stroke="currentColor" stroke-width="2.4"/><circle cx="25" cy="25" r="5" fill="none" stroke="currentColor" stroke-width="2.4"/><path d="M18.5 18.5l3 3" stroke="currentColor" stroke-width="2.4"/>',
  '<path d="M10 20h20M20 10v20" stroke="currentColor" stroke-width="2.8" stroke-linecap="round"/><circle cx="20" cy="20" r="8" fill="none" stroke="currentColor" stroke-width="1.4"/>',
  '<path d="M11 29 L20 11 L29 29" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/><path d="M15 23h10" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"/>',
  '<rect x="11" y="15" width="18" height="12" fill="none" stroke="currentColor" stroke-width="2.4"/><path d="M15 15v-3a5 5 0 0 1 10 0v3" fill="none" stroke="currentColor" stroke-width="2.4"/>',
  '<path d="M20 30s-9-5.5-9-12a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 6.5-9 12-9 12z" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linejoin="round"/>',
];

XS.Avatars.ids = () => GLYPHS.map((_, i) => `bi:${i}`);

XS.Avatars.isBuiltin = (value) => typeof value === 'string' && /^bi:\d+$/.test(value);

XS.Avatars.svg = function (id) {
  const index = Number(String(id).split(':')[1]) % GLYPHS.length;
  const hue = HUES[index % HUES.length];

  return `
    <svg viewBox="0 0 40 40" aria-hidden="true">
      <rect width="40" height="40" fill="hsl(${hue} 45% 12%)"/>
      <g color="hsl(${hue} 80% 62%)">${GLYPHS[index]}</g>
    </svg>
  `;
};

XS.Avatars.initials = function (name) {
  return String(name || '?')
    .replace(/[^A-Za-z0-9 ]/g, '')
    .split(' ')
    .filter(Boolean)
    .map((p) => p[0])
    .join('')
    .slice(0, 2)
    .toUpperCase() || '??';
};

/* What goes inside an .avatar / .lbface box. */
XS.Avatars.render = function (avatar, name) {
  if (XS.Avatars.isBuiltin(avatar)) return XS.Avatars.svg(avatar);

  if (typeof avatar === 'string' && /^https?:\/\//i.test(avatar)) {
    // A broken link must not leave a hole, so it swaps itself for initials.
    return `<img src="${XS.esc(avatar)}" alt="" referrerpolicy="no-referrer"
      onerror="this.parentNode.textContent='${XS.esc(XS.Avatars.initials(name))}'">`;
  }

  return XS.esc(XS.Avatars.initials(name));
};
