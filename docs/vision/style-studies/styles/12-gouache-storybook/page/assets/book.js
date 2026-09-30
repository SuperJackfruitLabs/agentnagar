/* A Day in Agentnagar: the gouache storybook. Revisions, images, review text and nav come from STYLE_DATA via Kit. */
(function () {
  const { el } = Kit;
  const S = Kit.style('12-gouache-storybook');
  const A = window.AGENTNAGAR;
  const reduced = Kit.reducedMotion();
  document.querySelectorAll('[data-num]').forEach((n) => { n.textContent = S.number; });

  const content = {
    intent: 'Opaque brushwork and saturated colour give the city the density of a painted picture book. Terracotta roofs, deep blue water, teal domes, red trams and ochre interiors dominate. Edges are soft and surfaces carry visible strokes rather than clean fills. Interiors are crowded with textiles, books, plants and pets; people have natural proportions and expressive faces.',
    principles: [
      'Paint, don\'t fill. Every surface carries a visible stroke, and edges stay soft.',
      'Warm light tells the story. Lanterns, window glow and wet reflections make street, rain and rooftop scenes the strongest pages.',
      'Rooms are full. Textiles, books, plants and pets make interiors feel lived in.',
      'Keep the plan readable. Map and top-down views hold the district layout even when fine strokes blur at distance.',
      'Interfaces are painted cards on paper, not glass.'
    ],
    palette: [
      { name: 'Paper cream', hex: '#f0ddc1' },
      { name: 'Terracotta roof', hex: '#b56841' },
      { name: 'Deep river blue', hex: '#287fa2' },
      { name: 'Tram vermilion', hex: '#bf5e39' },
      { name: 'Banner teal', hex: '#36535b' },
      { name: 'Ochre lamplight', hex: '#ad7338' },
      { name: 'Leaf green', hex: '#6f924c' },
      { name: 'Rain-night indigo', hex: '#3d5988' }
    ],
    materials: 'Opaque gouache on warm paper: chalky flat passages, dry-brush edges and visible strokes. In the scenes: stone arch bridges, terracotta tile, teal copper domes, timber workshops, woven rugs, blankets and wet cobbles.',
    type: 'The sheets letter panel names in a bookish serif and paint slogans onto walls, chalkboards and banners by hand. This page uses Fraunces for titles, EB Garamond for reading and Caveat for painted captions. Page choices only.',
    agents: 'City Agent A1 appears in the Conversation panel as a white robot with olive-green panels, a dark visor with two cyan eyes, a leaf emblem on a green disc at the side of its head, a patterned scarf and a leather strap, sitting at a café table by the river. It is not labelled "A1" in legible text. It does not appear in the other panels, and the helper portrait on the Mobile panel is a person rather than this robot. People elsewhere have natural proportions and expressive faces: makers in aprons, a woman with a cat, crowds with umbrellas. The Guild residents are not depicted in these sheets.',
    tradeoffs: [
      { label: 'Map vs street readability', text: 'Map and top-down views keep the district plan legible, but fine strokes blur at distance. Street, rain and rooftop scenes are the strongest, with lanterns, wet reflections and warm window light.' },
      { label: 'Device and production cost', text: 'The brief proposes keeping the district colours, the central tree and the brush edge on silhouettes at every tier. Lower tiers would simplify stroke texture and crowd counts; higher tiers could keep the layered lighting. Hand-painted texture is expensive to produce consistently across many assets.' },
      { label: 'UI legibility', text: 'Interfaces read as painted cards on paper; the kiosk\'s Browse, Book and Ask are clear. Many painted wall slogans contain garbled lettering, so in-world text needs an asset system rather than painted-in words.' },
      { label: 'Consistency across sheets', text: 'The review found the low-rise town of the overview becomes a denser tower skyline in the other three sheets, and the tram moves from red in the overview to yellow and blue later. The Living community sheet puts labels below panels while the others use top labels. The correction log still lists all four sheets as pending.' },
      { label: 'Drift from the brief', text: 'The architecture leans temperate and old European: stone arch bridges, spires, a domed library and blue-roofed dock sheds with chimneys. The brief itself notes the sheets drift away from the tropical direction.' }
    ]
  };

  const SHEET_NOTES = [
    'The River bends along the west edge under a stone arch North bridge. Blue-roofed Workshop sheds and docks sit by the water, the great tree fills Tree Square, and the domed Library stands to the east. Red trams run along the tram boulevard to the south.',
    'Inside the Workshop, makers build a model house. A woman and her cat look out over the river and bridge from home. A1 talks with a young woman at a riverside table, and a crowd gathers under the tree with the tram and the Library behind.',
    'A glass house outline is placed on the square with axes in build mode. Inside a wooden tram, riders watch the bridge. Lanterns hang in the tree on a rainy night, and the waterfront park looks across to the bridge.',
    'A library kiosk offers Browse, Book and Ask. A phone map with a helper card, a rooftop café over the river, and an AR tabletop model with a stack of books labelled for each part of the district.'
  ];

  // ---------- Helpers ----------
  const t = (tag, cls, text) => el(tag, Object.assign({}, cls ? { class: cls } : {}, text != null ? { text } : {}));
  const page = (side, kids) => el('div', { class: `page ${side}` }, [el('div', { class: 'page-inner' }, kids)]);
  const folio = (n) => el('p', { class: 'folio', 'aria-hidden': 'true', text: String(n) });
  function plate(node, caption, tilt) {
    return el('figure', { class: 'plate', style: `--tilt:${tilt || 0}deg` }, [el('div', { class: 'plate-art' }, node), el('figcaption', { text: caption })]);
  }
  const partTitle = (time, title) => [t('p', 'time', time), t('h2', null, title)];

  // ---------- Original cover painting (illustrative) ----------
  const COVER = `<svg viewBox="0 0 600 700" role="img" aria-label="Original page illustration in a gouache manner: a river curving under a stone arch bridge, a great tree above terracotta roofs, a teal-domed library and a red tram. Illustrative, not a concept sheet." class="cover-art">
  <defs>
    <linearGradient id="csky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8fc0d8"/><stop offset=".6" stop-color="#f3d6a8"/><stop offset="1" stop-color="#f0c78e"/></linearGradient>
    <linearGradient id="criver" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3b8fb5"/><stop offset="1" stop-color="#1f5f86"/></linearGradient>
  </defs>
  <g filter="url(#gouache)">
    <rect width="600" height="700" fill="url(#csky)"/>
    <path d="M0 300c80-40 160-50 240-30s170 10 230-20 130-10 130-10v160H0z" fill="#9fb07a"/>
    <path d="M0 330c90-25 180-20 260 0s200 5 340-20v200H0z" fill="#7f9a5c"/>
    <g fill="#c9b79b"><rect x="300" y="190" width="26" height="110"/><path d="M296 190l17-44 17 44z" fill="#b56841"/><rect x="420" y="220" width="20" height="80"/><path d="M416 220l14-34 14 34z" fill="#b56841"/></g>
    <path d="M0 440c60-20 120-10 180 20s110 60 190 50 150-40 230-30v90c-90-10-150 30-240 40s-150-30-210-60S40 520 0 530z" fill="url(#criver)"/>
    <g stroke="#e6f1f5" stroke-width="3" stroke-linecap="round" opacity=".7"><path d="M40 490h40M120 500h50M260 540h60M420 540h50M500 550h40"/></g>
    <path d="M60 430h260v26H60z" fill="#e0cfb0"/>
    <path d="M70 456a26 26 0 0 1 52 0zM140 456a26 26 0 0 1 52 0zM210 456a26 26 0 0 1 52 0z" fill="#2c6d92"/>
    <path d="M60 430h260" stroke="#b8a283" stroke-width="4"/>
    <g><rect x="380" y="330" width="170" height="90" fill="#e8d8bb"/><path d="M395 330a70 50 0 0 1 140 0z" fill="#36747a"/><path d="M460 280v-12" stroke="#36535b" stroke-width="4"/>
      <g fill="#ad7338"><rect x="395" y="352" width="18" height="34" rx="9"/><rect x="425" y="352" width="18" height="34" rx="9"/><rect x="455" y="352" width="18" height="34" rx="9"/><rect x="485" y="352" width="18" height="34" rx="9"/><rect x="515" y="352" width="18" height="34" rx="9"/></g></g>
    <g fill="#b56841"><path d="M40 380l40-30 40 30z"/><path d="M120 392l34-26 34 26z"/><path d="M300 400l40-28 40 28z"/></g>
    <g fill="#ecdcc0"><rect x="48" y="380" width="64" height="44"/><rect x="126" y="392" width="56" height="36"/><rect x="306" y="400" width="68" height="34"/></g>
    <path d="M232 470c-4-60 0-110 12-150h24c12 40 16 90 10 150z" fill="#6b4428"/>
    <g fill="#4f7a3a"><circle cx="256" cy="250" r="96"/><circle cx="180" cy="290" r="62"/><circle cx="330" cy="286" r="66"/><circle cx="220" cy="200" r="58"/><circle cx="300" cy="206" r="60"/></g>
    <g fill="#6f924c"><circle cx="236" cy="236" r="52"/><circle cx="306" cy="250" r="44"/><circle cx="190" cy="276" r="36"/><circle cx="272" cy="190" r="36"/></g>
    <g fill="#9ab86a"><circle cx="228" cy="214" r="18"/><circle cx="296" cy="226" r="16"/><circle cx="186" cy="262" r="12"/></g>
    <g><rect x="60" y="600" width="250" height="56" rx="12" fill="#bf5e39"/><rect x="60" y="640" width="250" height="16" fill="#8f3f24"/>
      <g fill="#f6d9a0"><rect x="76" y="610" width="40" height="24" rx="4"/><rect x="126" y="610" width="40" height="24" rx="4"/><rect x="176" y="610" width="40" height="24" rx="4"/><rect x="226" y="610" width="40" height="24" rx="4"/></g>
      <path d="M0 668h600" stroke="#6b5a48" stroke-width="5"/></g>
    <path d="M0 682h600v18H0z" fill="#8a6a4a"/>
  </g>
</svg>`;

  const PAINT_BLOB = (c, i) => {
    const shapes = ['M50 6c24 0 42 16 42 40s-14 46-44 46S6 72 8 46 26 6 50 6z', 'M46 8c28-4 46 20 44 42s-22 42-46 40S4 70 8 44 20 12 46 8z', 'M52 4c20 2 42 22 40 46s-24 40-46 42S6 68 10 42 30 2 52 4z'];
    return `<svg viewBox="0 0 100 100" aria-hidden="true" class="blob"><path d="${shapes[i % 3]}" fill="${c}" filter="url(#gouache)"/><path d="M30 30c10-8 26-10 36-4" stroke="#fff" stroke-opacity=".35" stroke-width="6" fill="none" stroke-linecap="round"/></svg>`;
  };

  // ---------- Spreads ----------
  const spreads = [];
  function spread(label, core, left, right) {
    const s = el('section', { class: 'spread', 'aria-label': label });
    if (core) s.setAttribute('data-core', core);
    s.append(left, right);
    spreads.push({ label, node: s });
    return s;
  }

  // 0. Cover
  (function () {
    const art = el('div', { class: 'cover-frame' }); art.innerHTML = COVER;
    const open = el('button', { type: 'button', class: 'pill big', text: 'Open the book' });
    open.addEventListener('click', () => go(1));
    const notes = el('button', { type: 'button', class: 'pill ghost', text: 'Read it as plain notes' });
    notes.addEventListener('click', () => dialog.showModal());
    spread('Cover', null,
      page('left cover-left', [art, t('p', 'art-note', 'Original page painting, not a concept sheet.')]),
      page('right cover-right', [
        t('p', 'kicker', `Style study ${S.number} of 30`),
        el('p', { class: 'cover-title' }, [t('span', 'a', 'A Day in'), t('span', 'b', 'Agentnagar')]),
        t('p', 'cover-sub', 'Told in gouache: opaque brushwork, saturated colour and soft edges'),
        t('p', 'cover-blurb', 'Follow the city from dawn to night. Each spread holds a piece of the study: the place, how it is painted, the four concept sheets, who lives there, what is hard, and where things stand.'),
        el('div', { class: 'cover-actions' }, [open, notes])
      ]));
  })();

  // 1. Dawn: the project
  (function () {
    const p = Kit.projectBlock(); p.removeAttribute('data-core');
    const facts = p.querySelector('dl');
    p.querySelector('.kit-small').remove();
    facts.remove();
    spread('Dawn: the city wakes', 'project',
      page('left', [...partTitle('Dawn', 'The city wakes by the river'),
        t('p', 'story', 'Before the first tram, the river runs north to south along the west edge of town, and a bridge crosses it to the north. Every study in the collection paints this same block: River, North bridge, Workshop, Tree Square with its one great tree, the Library and the tram boulevard. In this book the bridge is stone arches, the Workshop is a cluster of blue-roofed sheds by the docks, and the Library wears a dome.'),
        plate(Kit.sheetImg(S, 0, 'tl', { alt: `${S.name} concept study, City perspectives MAP panel (${S.sheets[0].revision}): the river on the west, the stone arch bridge, the Workshop sheds and docks, the great tree in Tree Square, the domed Library and red trams on the boulevard.` }), `The map, from the City perspectives sheet (${S.sheets[0].revision}).`, -1.5),
        folio(1)]),
      page('right', [p, t('h3', null, 'Things to know'), facts, t('p', 'small', `${A.status} ${A.nameNote}`), folio(2)]));
  })();

  // 2. Morning: the style
  spread('Morning: how the city is painted', 'style',
    page('left', [...partTitle('Morning', 'How the city is painted'),
      el('p', { class: 'story dropcap', text: content.intent }),
      t('h3', null, 'The painter\'s rules'),
      el('ol', { class: 'rules' }, content.principles.map((x) => el('li', { text: x }))),
      folio(3)]),
    page('right', [t('h3', 'first', 'The paint box'),
      t('p', 'small', 'Colours averaged from small areas of the selected sheets; approximate.'),
      el('ul', { class: 'paints' }, content.palette.map((c, i) => {
        const li = el('li', {});
        li.innerHTML = PAINT_BLOB(c.hex, i);
        li.append(t('span', 'pname', c.name), el('code', { text: c.hex }));
        return li;
      })),
      t('h3', null, 'Materials and texture'), t('p', null, content.materials),
      t('h3', null, 'Lettering'), t('p', null, content.type),
      folio(4)]));

  // 3. Midday: four views
  (function () {
    const sheetFig = (i, tilt) => {
      const sh = S.sheets[i];
      return el('figure', { class: 'plate sheet', style: `--tilt:${tilt}deg` }, [
        el('a', { class: 'plate-art', href: Kit.href(sh.image), 'aria-label': `Open full-size sheet: ${sh.title}, ${sh.revision}` }, Kit.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sh.title} (${sh.revision}), four panels: ${Kit.PANEL_NAMES[i].join(', ')}.` })),
        el('figcaption', {}, [t('b', null, `${sh.title} · ${sh.revision}`), t('span', 'panels', Kit.PANEL_NAMES[i].join(' · ')), t('span', null, SHEET_NOTES[i])])
      ]);
    };
    spread('Midday: four ways of looking', 'views',
      page('left', [...partTitle('Midday', 'Four ways of looking'),
        t('p', 'story', 'At noon the painter sets up four easels. Each sheet shows the same district in four panels: from above, from the street, indoors and on a screen.'),
        el('p', { class: 'concept' }, [t('b', null, 'Concept studies. '), A.conceptNote]),
        sheetFig(0, -1), sheetFig(1, 1), folio(5)]),
      page('right', [sheetFig(2, 1.2), sheetFig(3, -0.8), folio(6)]));
  })();

  // 4. Afternoon: agents
  spread('Afternoon: who you will meet', 'agents',
    page('left', [...partTitle('Afternoon', 'Who you will meet'),
      plate(Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): a white robot with olive-green panels, a dark visor with cyan eyes and a patterned scarf talks with a young woman in a red scarf at a riverside table.` }), 'A1 at a riverside table, from the Living community sheet.', 1.2),
      t('p', 'story', content.agents),
      t('p', 'small', A.agentA1), folio(7)]),
    page('right', [t('h3', 'first', 'The Guild: fourteen residents'),
      t('p', null, 'The Guild do not appear in these sheets, so this book does not paint them. Here are their names and proposed roles, as the lab lists them.'),
      el('ul', { class: 'guild' }, A.guild.map((g, i) => el('li', { style: `--dot:${content.palette[(i % 7) + 1].hex}` }, [t('b', null, g.name), t('span', null, g.role)]))),
      t('p', 'small', A.guildNote), folio(8)]));

  // 5. Evening: trade-offs
  spread('Evening: what is tricky', 'tradeoffs',
    page('left', [...partTitle('Evening', 'What is tricky'),
      t('p', 'story', 'When the lamps come on, this style is at its best: rain on the cobbles, lanterns in the tree, warm windows. Up close it glows. Further away, and in the small print, the brush starts to fight the reader.'),
      plate(Kit.sheetImg(S, 2, 'bl', { alt: `${S.name} concept study, Creating and exploring, Night and rain panel (${S.sheets[2].revision}): lanterns in the great tree, a blue tram, umbrellas and wet reflections on the square beside the Library.` }), 'Night and rain, from the Creating and exploring sheet.', -1.2),
      folio(9)]),
    page('right', [el('dl', { class: 'tricky' }, content.tradeoffs.flatMap((x) => [el('dt', { text: x.label }), el('dd', { text: x.text })])), folio(10)]));

  // 6. Night: status and navigation
  (function () {
    const status = Kit.statusBlock(S);
    const navBox = el('div', { class: 'endnav' });
    const toCover = el('button', { type: 'button', class: 'pill ghost', text: 'Back to the cover' });
    toCover.addEventListener('click', () => go(0));
    spread('Night: where the story stands', null,
      page('left', [...partTitle('Night', 'Where the story stands'),
        t('p', 'story', 'The lanterns go out one by one. Here is the record of what was painted and reviewed.'),
        status, folio(11)]),
      page('right', [el('p', { class: 'the-end', text: 'The end, for now' }),
        t('p', 'story', 'Gouache is one of thirty ways the city has been imagined. Turn to a neighbouring book, or return to the shelf of all thirty.'),
        navBox, toCover, folio(12)]));
    Kit.mountNav(navBox, S);
  })();

  // ---------- Book mechanics ----------
  const book = document.getElementById('book');
  spreads.forEach(({ node }, i) => { node.hidden = i !== 0; book.append(node); });
  const dots = document.getElementById('dots');
  const where = document.getElementById('where');
  const prevBtn = document.getElementById('prev');
  const nextBtn = document.getElementById('next');
  spreads.forEach(({ label }, i) => {
    const b = el('button', { type: 'button', class: 'dot', 'aria-label': `Go to ${label}` }, [el('span', { 'aria-hidden': 'true', text: String(i === 0 ? '✦' : i) })]);
    b.addEventListener('click', () => go(i));
    dots.append(el('li', {}, b));
  });

  let cur = 0;
  let busy = false;
  const narrow = () => window.matchMedia('(max-width: 860px)').matches;

  function sync() {
    prevBtn.disabled = cur === 0;
    nextBtn.disabled = cur === spreads.length - 1;
    dots.querySelectorAll('.dot').forEach((d, i) => { if (i === cur) d.setAttribute('aria-current', 'step'); else d.removeAttribute('aria-current'); });
    where.textContent = `${spreads[cur].label} · spread ${cur + 1} of ${spreads.length}`;
    try { history.replaceState(null, '', cur ? `#p${cur}` : location.pathname + location.search); } catch (e) { /* file:// may refuse */ }
  }

  function finish(oldS, newS) {
    oldS.hidden = true;
    oldS.className = 'spread';
    newS.className = 'spread';
    busy = false;
  }

  function go(n) {
    if (busy || n === cur || n < 0 || n >= spreads.length) return;
    const oldS = spreads[cur].node;
    const newS = spreads[n].node;
    const fwd = n > cur;
    cur = n;
    sync();
    if (reduced) { oldS.hidden = true; newS.hidden = false; return; }
    busy = true;
    newS.hidden = false;
    if (narrow()) {
      oldS.classList.add('fade-out');
      newS.classList.add(fwd ? 'slide-in-next' : 'slide-in-prev');
      setTimeout(() => finish(oldS, newS), 420);
      if (book.getBoundingClientRect().top < 0) book.scrollIntoView({ block: 'start' });
      return;
    }
    // Phase one: the old page lifts and turns to its edge over the new spread.
    oldS.classList.add('on-top', fwd ? 'lift-right' : 'lift-left');
    newS.classList.add('under');
    setTimeout(() => {
      // Phase two: the new page lands on the other side, over the old spread.
      oldS.classList.remove('on-top');
      oldS.classList.add('under', fwd ? 'hide-right' : 'hide-left');
      newS.classList.remove('under');
      newS.classList.add('on-top', fwd ? 'land-left' : 'land-right');
      setTimeout(() => finish(oldS, newS), 430);
    }, 430);
  }

  prevBtn.addEventListener('click', () => go(cur - 1));
  nextBtn.addEventListener('click', () => go(cur + 1));
  document.addEventListener('keydown', (e) => {
    if (e.defaultPrevented || e.altKey || e.ctrlKey || e.metaKey) return;
    if (document.querySelector('dialog[open]')) return;
    const tag = (e.target.tagName || '').toLowerCase();
    if (tag === 'input' || tag === 'textarea') return;
    if (e.key === 'ArrowRight' || e.key === 'PageDown') { go(cur + 1); e.preventDefault(); }
    else if (e.key === 'ArrowLeft' || e.key === 'PageUp') { go(cur - 1); e.preventDefault(); }
    else if (e.key === 'Home' && tag !== 'a') { go(0); }
    else if (e.key === 'End' && tag !== 'a') { go(spreads.length - 1); }
  });
  // Swipe on touch screens.
  let sx = null;
  book.addEventListener('touchstart', (e) => { sx = e.touches[0].clientX; }, { passive: true });
  book.addEventListener('touchend', (e) => {
    if (sx == null) return;
    const dx = e.changedTouches[0].clientX - sx;
    if (Math.abs(dx) > 60) go(cur + (dx < 0 ? 1 : -1));
    sx = null;
  });

  const dialog = Kit.notesDialog(S, content, document.getElementById('notes-btn'));
  const m = /^#p(\d+)$/.exec(location.hash);
  if (m && +m[1] < spreads.length) { spreads[0].node.hidden = true; cur = +m[1]; spreads[cur].node.hidden = false; }
  sync();
})();
