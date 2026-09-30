(function () {
  'use strict';
  const K = window.Kit;
  const A = window.AGENTNAGAR;
  const S = K.style(document.documentElement.dataset.style);
  const $ = (s, r) => (r || document).querySelector(s);
  const $$ = (s, r) => Array.from((r || document).querySelectorAll(s));
  const el = K.el;
  const reduced = K.reducedMotion();
  const body = document.body;
  const sprite = $('#sprite');
  if (reduced) document.documentElement.classList.add('still');
  $$('[data-num]').forEach((n) => { n.textContent = S.number; });
  $('#title-note').textContent = A.conceptNote;

  // ---------------- Content ----------------
  const palette = [
    { name: 'Warm white', hex: '#efece8' },
    { name: 'Daylight sky', hex: '#57adfd' },
    { name: 'River blue', hex: '#2c86c7' },
    { name: 'Indigo (A1 hair)', hex: '#2e3757' },
    { name: 'Uniform blue', hex: '#283f75' },
    { name: 'Vermilion', hex: '#d9593a' },
    { name: 'Tram coral', hex: '#ec725d' },
    { name: 'Brick', hex: '#d5967c' },
    { name: 'Lamp gold', hex: '#f4ab5a' }
  ];
  const tradeoffs = [
    { label: 'Map scale', text: 'Silhouette and colour blocks organise the district well from above. But the Map panel keeps shaded tree and roof glyphs and an elevation-style bridge, and the Top-down still shows facades and tilt; a true map would need its own flat treatment.' },
    { label: 'Street scale', text: 'The strongest scale: Street, Gathering, Night and rain and Waterfront park are lively and readable, and conversations bring faces and pose forward as the brief intends.' },
    { label: 'Consistency', text: 'Seven overview attempts alternated roof regressions before pass 7 showed three Workshop bays in all four overview panels; Workshop roof slopes and heights still vary across scenes. A production version would need locked model sheets.' },
    { label: 'Device and production cost', text: 'Proposed adaptation: keep character silhouettes, palette and shadow design at all tiers; lower tiers simplify outlines, background props and lighting; higher tiers add secondary motion and environmental detail. Outline stability, face readability and animation must be prototyped together.' },
    { label: 'Painterly boundary', text: 'The generated sheets include painterly foliage, skies and reflections. A production style guide would need to decide where cel shading stops and painting begins.' },
    { label: 'UI legibility', text: 'Flat UI cards sit naturally in this style (kiosk Browse, Book and Ask; the phone\'s Workshop card and Ask button). The small badge text in the Conversation panel is less legible than the explicit A1 marker on the phone.' },
    { label: 'Review limits', text: 'Not full contract compliance. Generated margins and caption typography are not pixel-exact. No measured accessibility, usability or runtime performance claim.' }
  ];
  const agentsText = 'City Agent A1 is an original design: indigo hair in a messy bun, blue eyes, a white jacket over a blue shirt, a backpack, a leaf sleeve patch and a "City Agent A1" badge; the phone portrait carries an explicit leaf A1 marker. Guild residents are not depicted in the sheets.';
  const sheetNotes = [
    ['Map: River R1 west, North bridge B1, Workshop W1 (tools pin), Tree Square T1, Library L1 (book pin), waterfront park and the tram stop on S1.',
      'Top-down: three sawtooth bays, the living tree, the silver vault and a tram on the boulevard.',
      'Diagonal: bridge arches over the river, three planted towers, Workshop, square and Library in a row.',
      'Street: the cream tram with its vermilion stripe in front of Workshop, tree and Library; palms and lamps.'],
    ['Workshop: A1 fixes a small wheeled robot at the bench beside a bearded resident; pegboards and task lamps.',
      'Home: a resident with a mug and a sleeping cat; the Workshop sawtooth and the river through the window.',
      'Conversation: A1 (badge on the chest, leaf patch on the sleeve) talks with a bearded resident on Tree Square.',
      'Gathering: a sunset concert under the shade tree between Workshop and Library, towers beyond.'],
    ['Build mode: the Workshop selected with red X, green Y and blue Z axes; river, bridge, Library and tram.',
      'Transit: inside the tram, passengers look out at Workshop, tree and Library past the stop.',
      'Night and rain: wet paving streaked with lamp light, a red umbrella, the lit Library and a tram, still cel-shaded.',
      'Waterfront park: cyclists and a couple on a bench by the river; the bridge, Workshop and tram beyond.'],
    ['Facility: A1 helps a resident at a Library kiosk with Browse, Book and Ask.',
      'Mobile: phone map with four categories, a Workshop card with A1\'s portrait and leaf marker, "Ask about availability" and Ask.',
      'Rooftop: A1 points out the Workshop across the trees and river.',
      'AR tabletop: the district model on a table, Workshop selected, a four-category legend and an "External viewer" label.']
  ];

  // Chapters: each is a choice that plays lines, then opens its core section.
  const chapters = [
    { core: 'project', label: 'Tell me about Agentnagar', mood: 'day', lines: [
      ['happy', 'Agentnagar is an open maker village that can grow into a city, shared by people and agents.'],
      ['talk', 'The first slice is simple: walk the city and watch the fourteen Guild agents at their real work.'],
      ['talk', 'It is still being planned, so no playable release yet. Here is the whole brief.']] },
    { core: 'style', label: 'What makes this style?', mood: 'day', lines: [
      ['talk', 'Cel shading! Flat colour, only a few shadow steps, and outlines where silhouettes matter.'],
      ['happy', 'Warm whites and blues by day, indigo like my hair, and vermilion for accents, like the tram stripe.'],
      ['talk', 'Here are the rules, the palette and the type.']] },
    { core: 'views', label: 'Show me the district', mood: 'day', lines: [
      ['talk', 'The river runs along the west edge, with one low three-span bridge to the north.'],
      ['talk', 'Then the Workshop with three sawtooth bays, Tree Square with its big shade tree, and the Library with the rounded roof.'],
      ['happy', 'The tram boulevard runs along the south. These four sheets are concept studies, not game captures.']] },
    { core: 'agents', label: 'Who lives here?', mood: 'dusk', lines: [
      ['happy', 'Well, me! In these sheets I have indigo hair in a bun, blue eyes and a white-and-blue jacket with my leaf badge.'],
      ['talk', 'The Guild residents are not drawn in this study yet. Their roles are proposals, pending review.']] },
    { core: 'tradeoffs', label: 'What is the catch?', mood: 'night', lines: [
      ['talk', 'Honestly? Clean outlines and faces are hard to keep stable once things move.'],
      ['talk', 'Even the roofs drifted: it took seven tries to keep three Workshop bays in every overview.'],
      ['talk', 'And night and rain must keep this same shading language. Here is the candid list.']] },
    { core: 'status', label: 'Where does the study stand?', mood: 'dusk', lines: [
      ['talk', 'The sheets were revised and inspected. Being selected for this gallery does not mean they were approved.'],
      ['talk', 'Every revision and review source is listed here.']] },
    { core: 'nav', label: 'Take me to another style', mood: 'day', lines: [
      ['happy', 'Next door is Paper craft; back the way we came is Claymation. Or see all thirty!']] }
  ];

  // ---------------- Fill the core sections ----------------
  const proj = K.projectBlock(); proj.removeAttribute('data-core');
  $('#slot-project').append(proj);
  palette.forEach((p) => $('#palette').append(el('li', {}, [el('span', { class: 'sw', style: `background:${p.hex}`, 'aria-hidden': 'true' }), el('b', { text: p.name }), el('code', { text: p.hex })])));
  $('#a1-shared').textContent = A.agentA1;
  $('#guild-note').textContent = A.guildNote;
  A.guild.forEach((g) => $('#guild').append(el('li', {}, [el('b', { text: g.name }), el('span', { text: g.role })])));
  tradeoffs.forEach((t) => $('#trade').append(el('div', {}, [el('dt', { text: t.label }), el('dd', { text: t.text })])));
  $('#slot-status').append(K.statusBlock(S));
  K.mountNav($('#slot-nav'), S);
  K.mountNav($('#title-nav'), S);
  $('#concept-note').textContent = A.conceptNote;
  (function crop() {
    const sheet = S.sheets[1];
    const [x, y, w, h] = [20, 526, 400, 450];
    const box = el('div', { class: 'crop', role: 'img', 'aria-label': `City Agent A1 in the ${S.name} concept study, ${sheet.title} ${sheet.revision}, Conversation panel: indigo hair in a bun, blue eyes, white jacket over a blue shirt, City Agent A1 badge.` });
    box.style.aspectRatio = `${w} / ${h}`;
    const img = el('img', { src: K.href(sheet.image), alt: '', loading: 'lazy', decoding: 'async' });
    Object.assign(img.style, { width: `${(1536 / w) * 100}%`, left: `${(-x / w) * 100}%`, top: `${(-y / h) * 100}%` });
    box.append(img, el('span', { class: 'crop-tag', text: `Concept study crop · ${sheet.revision}` }));
    $('#a1-crop').append(box);
  })();

  // Gallery tabs
  const tabs = $('#sheet-tabs'); const panels = $('#sheet-panels');
  S.sheets.forEach((sheet, i) => {
    const tab = el('button', { type: 'button', role: 'tab', id: `tab-${i}`, 'aria-controls': `tp-${i}`, 'aria-selected': String(i === 0), tabindex: i === 0 ? '0' : '-1' }, [el('span', { class: 'tab-no', text: `0${i + 1}` }), sheet.title]);
    const img = K.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sheet.title} (${sheet.revision}): ${K.PANEL_NAMES[i].join(', ')}. ${sheetNotes[i].join(' ')}` });
    const panel = el('div', { role: 'tabpanel', id: `tp-${i}`, 'aria-labelledby': `tab-${i}`, class: 'tp' }, [
      el('figure', { class: 'cg' }, [el('a', { href: K.href(sheet.image), class: 'cg-frame' }, img), el('figcaption', {}, [`${sheet.title} · `, el('a', { href: K.href(sheet.image), text: sheet.revision }), ' · ', el('a', { href: K.href(sheet.review), text: 'review' }), '. Concept study.'])]),
      el('ol', { class: 'cg-notes' }, K.PANEL_NAMES[i].map((n, j) => el('li', {}, [el('b', { text: n }), el('span', { text: sheetNotes[i][j] })])))
    ]);
    if (i) panel.hidden = true;
    tab.addEventListener('click', () => selectTab(i));
    tabs.append(tab); panels.append(panel);
  });
  function selectTab(i, focus) {
    $$('[role=tab]', tabs).forEach((t, k) => { t.setAttribute('aria-selected', String(k === i)); t.tabIndex = k === i ? 0 : -1; });
    $$('.tp', panels).forEach((p, k) => { p.hidden = k !== i; });
    if (focus) $(`#tab-${i}`).focus();
  }
  tabs.addEventListener('keydown', (e) => {
    const i = $$('[role=tab]', tabs).indexOf(document.activeElement);
    const n = S.sheets.length;
    if (e.key === 'ArrowRight') { e.preventDefault(); selectTab((i + 1) % n, true); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); selectTab((i - 1 + n) % n, true); }
    if (e.key === 'Home') { e.preventDefault(); selectTab(0, true); }
    if (e.key === 'End') { e.preventDefault(); selectTab(n - 1, true); }
  });

  // Notes dialog (all core content as a plain document)
  const notes = K.notesDialog(S, {
    intent: $('#style-intent').textContent,
    principles: $$('#principles li').map((li) => li.textContent.trim()),
    palette,
    materials: 'Flat-painted brick and zinc with crisp shadow shapes, glass as a highlight stripe, three-tone foliage, streaked reflections at night.',
    type: 'Zen Old Mincho for titles, Nunito for dialogue and UI; the sheets use a clean rounded sans in UI.',
    agents: agentsText,
    tradeoffs
  });
  const openNotes = () => notes.showModal();

  // ---------------- Visual novel engine ----------------
  let mode = 'title';
  let queue = []; let after = null; let typing = null; let full = ''; let auto = false; let autoT = null; let flap = null;
  const visited = new Set();
  const dlg = $('#dialogue'); const box = $('#box'); const lineEl = $('#line');
  const choices = $('#choices'); const list = $('#choice-list');
  const log = $('#log');

  function setMood(m) { body.classList.remove('mood-day', 'mood-dusk', 'mood-night'); body.classList.add(`mood-${m}`); }
  function setExpr(x) { sprite.classList.toggle('happy', x === 'happy'); }

  function showTitle() {
    mode = 'title'; body.classList.add('at-title'); dlg.hidden = true; choices.hidden = true;
    $('#title').hidden = false; $('#btn-start').focus();
  }
  function hideTitle() { $('#title').hidden = true; body.classList.remove('at-title'); }

  function say(lines, then) {
    hideTitle(); choices.hidden = true; dlg.hidden = false; mode = 'talk';
    queue = lines.slice(); after = then; nextLine();
    box.focus({ preventScroll: true });
  }
  function nextLine() {
    clearTimeout(autoT);
    if (!queue.length) { const f = after; after = null; dlg.hidden = true; if (f) f(); return; }
    const [expr, text] = queue.shift();
    setExpr(expr); full = text;
    log.append(el('li', {}, [el('b', { text: 'A1' }), text]));
    if (reduced) { lineEl.textContent = text; done(); return; }
    let i = 0; lineEl.textContent = '';
    box.classList.add('typing'); startFlap();
    typing = setInterval(() => { i += 1; lineEl.textContent = text.slice(0, i); if (i >= text.length) finishTyping(); }, 24);
  }
  function startFlap() { stopFlap(); flap = setInterval(() => sprite.classList.toggle('open'), 120); }
  function stopFlap() { clearInterval(flap); flap = null; sprite.classList.remove('open'); }
  function finishTyping() { clearInterval(typing); typing = null; lineEl.textContent = full; done(); }
  function done() { box.classList.remove('typing'); stopFlap(); if (auto) autoT = setTimeout(nextLine, 1800 + full.length * 18); }
  function advance() { if (typing) finishTyping(); else nextLine(); }
  box.addEventListener('click', advance);

  function hub(focusCore) {
    mode = 'hub'; hideTitle(); dlg.hidden = true; choices.hidden = false; setMood('day'); setExpr('happy');
    $('#choice-q').textContent = visited.size >= chapters.length ? 'That is the whole tour. Anything you want to see again?' : 'Where shall we go?';
    list.replaceChildren(...chapters.map((c, i) => el('li', {}, el('button', { type: 'button', class: `choice${visited.has(c.core) ? ' seen' : ''}`, 'data-core-target': c.core, 'aria-keyshortcuts': String(i + 1) }, [
      el('span', { class: 'cn', text: String(i + 1) }), el('span', { class: 'ct', text: c.label }), el('span', { class: 'cv', text: visited.has(c.core) ? 'seen' : '' })
    ]))));
    list.append(el('li', {}, el('button', { type: 'button', class: 'choice notes-choice', 'data-notes': '1', 'aria-keyshortcuts': 'N' }, [el('span', { class: 'cn', text: 'N' }), el('span', { class: 'ct', text: 'Read the notes as one document' })])));
    $$('.choice', list).forEach((b) => b.addEventListener('click', () => (b.dataset.notes ? openNotes() : pick(b.dataset.coreTarget))));
    const target = focusCore ? $(`[data-core-target="${focusCore}"]`, list) : ($('.choice:not(.seen)', list) || $('.choice', list));
    target.focus({ preventScroll: true });
  }
  function pick(core) {
    const c = chapters.find((x) => x.core === core);
    setMood(c.mood);
    say(c.lines, () => openDoc(core));
  }
  function openDoc(core) {
    visited.add(core);
    const d = $(`#doc-${core}`);
    d.showModal();
    d.scrollTop = 0;
    const b = $('.doc-body', d); if (b) b.scrollTop = 0;
  }
  $$('dialog.doc').forEach((d) => {
    $('.doc-close', d).addEventListener('click', () => d.close());
    d.addEventListener('close', () => {
      if (d.id === 'doc-log') return;
      const core = d.id.replace('doc-', '');
      if (mode === 'title') { $('#btn-gallery').focus(); return; }
      hub(core);
    });
    d.addEventListener('click', (e) => { if (e.target === d) d.close(); });
  });

  const intro = [
    ['happy', 'Oh, hello! I am City Agent A1, the guide you meet in every Agentnagar study.'],
    ['talk', 'Today I am drawn cel-shaded: flat colour, a couple of shadow steps and clean outlines.'],
    ['talk', 'This stage and I are illustrations made for this page. The real concept sheets are in the gallery.'],
    ['happy', 'Pick anywhere you like. Every stop opens its full notes.']
  ];
  $('#btn-start').addEventListener('click', () => say(intro, () => hub()));
  $('#btn-chapters').addEventListener('click', () => hub());
  $('#btn-gallery').addEventListener('click', () => openDoc('views'));
  $('#btn-notes').addEventListener('click', openNotes);
  $('#hud-notes').addEventListener('click', openNotes);
  $('#hud-chapters').addEventListener('click', () => { clearTimeout(autoT); if (typing) finishTyping(); hub(); });
  $('#hud-log').addEventListener('click', () => { $('#doc-log').showModal(); const lb = $('#doc-log .doc-body'); lb.scrollTop = lb.scrollHeight; });
  const autoBtn = $('#hud-auto');
  function toggleAuto() {
    auto = !auto; autoBtn.setAttribute('aria-pressed', String(auto));
    if (auto && mode === 'talk' && !typing) autoT = setTimeout(nextLine, 1200); else clearTimeout(autoT);
  }
  autoBtn.addEventListener('click', toggleAuto);

  document.addEventListener('keydown', (e) => {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if ($('dialog[open]')) return;
    const k = e.key.toLowerCase();
    if (k === 'n') { e.preventDefault(); openNotes(); return; }
    if (k === 'l') { e.preventDefault(); $('#hud-log').click(); return; }
    if (k === 'a' && mode !== 'title') { e.preventDefault(); toggleAuto(); return; }
    if (k === 'c') { e.preventDefault(); $('#hud-chapters').click(); return; }
    if (mode === 'talk') {
      if ((e.key === 'Enter' || e.key === ' ') && e.target === box) return; // native button click
      if (['Enter', ' ', 'ArrowRight', 'ArrowDown', 'PageDown'].includes(e.key) && !(e.target.closest && e.target.closest('button, a') && e.target !== box)) { e.preventDefault(); advance(); }
      return;
    }
    const group = mode === 'hub' ? $$('.choice', list) : mode === 'title' ? $$('.menu-btn') : [];
    if (mode === 'hub' && /^[1-7]$/.test(e.key)) { e.preventDefault(); pick(chapters[+e.key - 1].core); return; }
    if (group.length && (e.key === 'ArrowDown' || e.key === 'ArrowUp')) {
      e.preventDefault();
      const i = group.indexOf(document.activeElement);
      const n = e.key === 'ArrowDown' ? (i + 1) % group.length : (i - 1 + group.length) % group.length;
      group[n].focus();
    }
  });

  showTitle();
})();
