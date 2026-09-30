(function () {
  'use strict';
  const K = window.Kit;
  const A = window.AGENTNAGAR;
  const S = K.style(document.documentElement.dataset.style);
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const el = K.el;
  const reduced = K.reducedMotion();
  if (reduced) {
    document.documentElement.classList.add('still');
    $$('animate.boil').forEach((a) => a.remove());
  }

  $$('[data-num]').forEach((n) => { n.textContent = S.number; });
  $('#slate-take').textContent = S.sheets[0].revision;

  // ---------- Content ----------
  const palette = [
    { name: 'Turquoise knit', hex: '#395259', where: 'A1\'s pompom hat' },
    { name: 'Mustard scarf', hex: '#c56d21', where: 'A1\'s scarf' },
    { name: 'Cream paving', hex: '#f4dec7', where: 'Square and street paving' },
    { name: 'Brick clay', hex: '#d68161', where: 'Workshop on the map' },
    { name: 'Tram coral', hex: '#b75239', where: 'Tram stripe' },
    { name: 'River blue', hex: '#2288ba', where: 'West river' },
    { name: 'Olive canopy', hex: '#899347', where: 'Shade tree, street trees' },
    { name: 'Bench wood', hex: '#d58945', where: 'Benches and tables' }
  ];
  const tradeoffs = [
    { label: 'Map scale', text: 'Reads as a big tabletop model and stays legible: the Map panel has clear category pins for Workshop, Library, park and tram stop. But the map mixes flat footprints with volumetric tree and roof glyphs and an elevation-drawn bridge, and the Top-down keeps some facade tilt. The brief asks to test how the miniature-set look holds at full city scale.' },
    { label: 'Street scale', text: 'The warmest, most intimate views in the collection. Workshop, Home and Conversation feel handmade and inviting; night and rain gain lovely practical lights.' },
    { label: 'Depth of field', text: 'Miniature photography invites heavy blur. The brief warns against depth-of-field that hides navigable spaces; the Mobile panel already blurs its background.' },
    { label: 'Device and production cost', text: 'Proposed adaptation: keep rounded silhouettes and material colours on every tier; simplify surface texture, decorative objects and lighting on lower tiers; enrich tactile detail and soft shadows on higher tiers. Sculpted, textured characters are costly to produce and animate consistently.' },
    { label: 'UI legibility', text: 'Kiosk and phone UI are clean rounded cards (Browse, Book, Ask) and read well. The repair record notes the small A1 badge text in the Conversation panel is imperfect, and the mobile category legend overlays part of the map.' },
    { label: 'Motion', text: 'Stop-motion suggests a low frame rate, but the brief separates look from cadence. A choppy cadence can hurt responsiveness and comfort; see the frame-rate test above.' },
    { label: 'Review residuals', text: 'Not exact contract compliance: projection and top-down tilt as above; independent review restored the asymmetric sawtooth northlights and an actively used kiosk. Margins and typography are not pixel-exact; no measured usability, accessibility or performance claim.' }
  ];
  const agentsText = 'City Agent A1 wears a teal knit pompom hat over dark curls, a chunky mustard scarf and a blue jacket with a leaf badge, with large eyes and rosy cheeks; the phone portrait matches. Guild residents are not depicted in the sheets; the other clay figures are unnamed residents.';

  // ---------- Story (project) ----------
  const p = K.projectBlock();
  p.removeAttribute('data-core');
  const cards = [];
  cards.push(el('div', { class: 'sb-card sb-lead' }, [el('span', { class: 'sb-no', text: 'Shot 1' }), el('p', { class: 'sb-tag', text: A.tagline })]));
  A.summary.forEach((t, i) => cards.push(el('div', { class: 'sb-card' }, [el('span', { class: 'sb-no', text: `Shot ${i + 2}` }), el('p', { text: t })])));
  const facts = el('dl', { class: 'sb-facts' }, A.facts.flatMap((f) => [el('dt', { text: f.label }), el('dd', { text: f.text })]));
  cards.push(el('div', { class: 'sb-card sb-wide' }, [el('span', { class: 'sb-no', text: 'Continuity notes' }), facts]));
  cards.push(el('div', { class: 'sb-card sb-status' }, [el('span', { class: 'sb-no', text: 'Where we are' }), el('p', { text: `${A.status} ${A.nameNote}` })]));
  $('#project-slot').append(...cards);

  // ---------- Palette ----------
  const ul = $('#palette');
  palette.forEach((c, i) => ul.append(el('li', { class: 'jar' }, [
    el('span', { class: 'blob', style: `--c:${c.hex};--r:${(i % 3) - 1}deg`, 'aria-hidden': 'true' }),
    el('span', { class: 'jar-tape' }, [el('b', { text: c.name }), el('code', { text: c.hex })]),
    el('span', { class: 'jar-where', text: c.where })
  ])));

  // ---------- Projector ----------
  const PANELS = ['tl', 'tr', 'bl', 'br'];
  const notes = [
    ['Cartographic plan: River R1 west, North bridge B1, Workshop W1 (tools pin), Tree Square T1, Library L1 (book pin), waterfront park and the tram stop on S1.',
      'Straight down on the model: three sawtooth bays, the lumpy shade tree, the silver vault and the tram on the boulevard.',
      'Diagonal over the set: bridge arches, three planted towers, Workshop, Tree Square and Library, the tram below.',
      'At street level: the cream tram with its coral stripe passes Workshop, tree and Library; clay residents wait on the paving.'],
    ['In the Workshop: A1 in the teal hat sculpts a little brick Workshop while residents build a bridge model.',
      'Home: A1 reads with a sleeping cat and a leaf mug; the Workshop sawtooth shows through the window.',
      'Conversation: A1, badge on the jacket, talks with a grey-curled resident holding a leaf mug under the shade tree.',
      'Gathering: musicians and neighbours on Tree Square between Workshop and Library; tram in front, towers behind.'],
    ['Build mode: the Workshop selected with red X, green Y and blue Z axes; river, bridge, Library and tram around it.',
      'Transit: clay passengers look out from the tram at the Workshop, tree and Library.',
      'Night and rain: umbrellas, glowing lamps, the lit Library and a tram at the stop, same clay language.',
      'Waterfront park: benches, a dog and a straw hat by the river; the bridge and the tram beyond.'],
    ['Facility: A1 and a resident at the library kiosk tablet with Browse, Book and Ask.',
      'Mobile: phone map with a four-category legend, a Workshop card, City Agent A1, "Ask about availability" and Ask.',
      'Rooftop: A1 and a resident look over Tree Square to the Workshop and the river.',
      'AR tabletop: the district model on a table, Workshop selected, a four-category legend and an "External viewer" label.']
  ];
  const frames = [];
  S.sheets.forEach((sheet, i) => PANELS.forEach((pn, j) => frames.push({ i, pn, name: K.PANEL_NAMES[i][j], sheet, note: notes[i][j] })));
  const screen = $('#screen'); const strip = $('#filmstrip');
  let cur = 0; let timer = null;
  frames.forEach((f, n) => {
    const opt = el('div', { class: 'cell', role: 'option', id: `cell-${n}`, 'aria-selected': 'false', 'aria-label': `Frame ${n + 1}: ${f.sheet.title}, ${f.name}` }, [
      K.sheetImg(S, f.i, f.pn, { alt: '' }), el('span', { class: 'cell-no', text: String(n + 1).padStart(2, '0') })
    ]);
    opt.firstChild.removeAttribute('role'); opt.firstChild.removeAttribute('aria-label');
    opt.addEventListener('click', () => { stop(); show(n); strip.focus({ preventScroll: true }); });
    strip.append(opt);
  });
  function show(n) {
    cur = (n + frames.length) % frames.length;
    const f = frames[cur];
    screen.replaceChildren(K.sheetImg(S, f.i, f.pn, { eager: true, alt: `${S.name} concept study, ${f.sheet.title} (${f.sheet.revision}), ${f.name} panel. ${f.note}` }));
    $('#frame-no').textContent = String(cur + 1).padStart(2, '0');
    $('#frame-title').replaceChildren(`${f.sheet.title} · ${f.name} · `, el('a', { href: K.href(f.sheet.image), text: f.sheet.revision }));
    $('#frame-note').textContent = f.note;
    $$('.cell', strip).forEach((c, k) => c.setAttribute('aria-selected', String(k === cur)));
    strip.setAttribute('aria-activedescendant', `cell-${cur}`);
    const cell = $(`#cell-${cur}`);
    const left = cell.offsetLeft - strip.clientWidth / 2 + cell.clientWidth / 2;
    strip.scrollTo({ left, behavior: reduced ? 'auto' : 'smooth' });
  }
  function stop() { clearInterval(timer); timer = null; $('#play').setAttribute('aria-pressed', 'false'); $('#play').textContent = 'Play'; }
  function play() {
    if (timer) return stop();
    $('#play').setAttribute('aria-pressed', 'true'); $('#play').textContent = 'Pause';
    timer = setInterval(() => show(cur + 1), 500);
  }
  $('#prev').addEventListener('click', () => { stop(); show(cur - 1); });
  $('#next').addEventListener('click', () => { stop(); show(cur + 1); });
  $('#play').addEventListener('click', play);
  strip.addEventListener('keydown', (e) => {
    const map = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };
    if (e.key in map) { e.preventDefault(); stop(); show(cur + map[e.key]); }
    else if (e.key === 'Home') { e.preventDefault(); stop(); show(0); }
    else if (e.key === 'End') { e.preventDefault(); stop(); show(frames.length - 1); }
    else if (e.key === ' ' || e.key === 'Enter') { e.preventDefault(); play(); }
  });
  show(0);
  $('#concept-note').textContent = A.conceptNote;
  const links = $('#sheet-links');
  S.sheets.forEach((sh) => links.append(el('li', {}, [el('a', { href: K.href(sh.image), text: `${sh.title} full sheet` }), ` · ${sh.revision}`])));

  // ---------- Puppets ----------
  $('#a1-shared').textContent = A.agentA1;
  $('#guild-note').textContent = A.guildNote;
  A.guild.forEach((g) => $('#guild').append(el('li', {}, [el('b', { text: g.name }), el('span', { text: g.role })])));
  (function crop() {
    const sheet = S.sheets[1];
    const [x, y, w, h] = [16, 504, 440, 300];
    const box = el('div', { class: 'crop', role: 'img', 'aria-label': `City Agent A1 in the ${S.name} concept study, ${sheet.title} ${sheet.revision}, Conversation panel: teal pompom hat, mustard scarf, blue jacket and an A1 badge.` });
    box.style.aspectRatio = `${w} / ${h}`;
    const img = el('img', { src: K.href(sheet.image), alt: '', loading: 'lazy', decoding: 'async' });
    Object.assign(img.style, { width: `${(1536 / w) * 100}%`, left: `${(-x / w) * 100}%`, top: `${(-y / h) * 100}%` });
    box.append(img); $('#a1-crop').append(box);
  })();

  // ---------- Frame-rate test ----------
  const walker = $('#walker');
  let fps = 12; let running = !reduced; let t0 = performance.now(); let tPaused = 0;
  const status = $('#cad-status');
  function pose(t) {
    const x = 80 + ((t * 110) % 760);
    const bob = Math.abs(Math.sin(t * Math.PI * 2.2)) * -10;
    const tilt = Math.sin(t * Math.PI * 2.2) * 4;
    walker.setAttribute('transform', `translate(${x.toFixed(1)} ${bob.toFixed(1)}) rotate(${tilt.toFixed(1)} 0 200)`);
  }
  function tick(now) {
    if (running) {
      const t = (now - t0) / 1000;
      pose(fps >= 60 ? t : Math.floor(t * fps) / fps);
    }
    requestAnimationFrame(tick);
  }
  function setStatus() {
    status.textContent = reduced
      ? 'Reduced motion is on, so the test starts paused. Press Play to run it.'
      : `Showing ${fps >= 60 ? 'smooth motion at the display rate' : `${fps} new poses a second`}.`;
  }
  $$('.cad-controls [data-fps]').forEach((b) => b.addEventListener('click', () => {
    fps = +b.dataset.fps;
    $$('.cad-controls [data-fps]').forEach((o) => o.setAttribute('aria-checked', String(o === b)));
    setStatus();
  }));
  $('.cad-controls').addEventListener('keydown', (e) => {
    const radios = $$('.cad-controls [data-fps]'); const i = radios.indexOf(document.activeElement);
    if (i < 0) return;
    if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); const n = radios[(i + (e.key === 'ArrowRight' ? 1 : -1) + radios.length) % radios.length]; n.focus(); n.click(); }
  });
  const tog = $('#cad-toggle');
  function syncToggle() { tog.textContent = running ? 'Pause' : 'Play'; tog.setAttribute('aria-pressed', String(!running)); }
  tog.addEventListener('click', () => {
    if (running) { tPaused = performance.now(); } else { t0 += performance.now() - (tPaused || performance.now()); }
    running = !running; syncToggle();
  });
  if (reduced) tPaused = performance.now();
  pose(0.35); syncToggle(); setStatus();
  requestAnimationFrame(tick);

  // ---------- Director's notes, log, credits ----------
  const pad = $('#tradeoffs');
  pad.append(el('dl', {}, tradeoffs.flatMap((t) => [el('dt', { text: t.label }), el('dd', { text: t.text })])));
  $('#status-slot').append(el('p', { class: 'clip-head', text: `Roll ${S.number} · ${S.name}` }), K.statusBlock(S));
  K.mountNav($('#nav-slot'), S);

  K.notesDialog(S, {
    intent: $('.intent-card .lede').textContent + ' ' + $('.intent-card p:nth-of-type(2)').textContent,
    principles: $$('#principles li').map((li) => li.textContent.trim()),
    palette: palette.map((c) => ({ name: c.name, hex: c.hex })),
    materials: 'Modelling clay with tool marks and thumbprints, knit and crochet, textile cushions, wooden props, glossy sculpted water, warm practical lights.',
    type: 'Fredoka display, Nunito text, Patrick Hand for crew notes; the sheets use a plain bold sans for captions and a rounded sans in UI.',
    agents: agentsText,
    tradeoffs
  }, $('#notes-btn'));
})();
