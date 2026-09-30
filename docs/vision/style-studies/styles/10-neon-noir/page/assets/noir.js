/* Neon noir case file. Style prose lives here; revisions, images, review text and nav come from STYLE_DATA via Kit. */
(function () {
  const { el } = Kit;
  const S = Kit.style('10-neon-noir');
  const A = window.AGENTNAGAR;
  const reduced = Kit.reducedMotion();

  // ---- Page content (also feeds the plain notes dialog) ----
  const content = {
    intent: 'A dense vertical city shaped by dark architecture and selective pools of light: charcoal and navy against cyan, amber and magenta, with luminous windows and rain-darkened pavement. Occupied interiors (workshops, homes, libraries, gathering spaces) feel warm and useful. People and agents wear everyday clothing and keep approachable expressions. The atmosphere is urban and communal, with no combat or dystopian mechanics.',
    principles: [
      'Light is the wayfinding. Amber lamps trace routes, the tram line and the square; the dark between them is rest, not threat.',
      'Keep interiors warm. Workshops, homes and the Library glow amber so every destination reads as inviting.',
      'Neon is an accent, not a wash. Magenta sits on tower edges and cyan on the dome and the agent\'s eye ring; most surfaces stay navy.',
      'Faces get light. Conversation scenes carry enough warm key light for expressions to read.',
      'Wet ground doubles the city. Reflections on paving repeat the light plan, and they are the first thing to cut on small devices.'
    ],
    palette: [
      { name: 'Night navy', hex: '#05141f' },
      { name: 'Harbour navy', hex: '#0d2949' },
      { name: 'River cyan', hex: '#0285b9' },
      { name: 'Downtown magenta', hex: '#9d2a72' },
      { name: 'Tram red', hex: '#a9171a' },
      { name: 'Lamp amber', hex: '#d68633' },
      { name: 'Window cream', hex: '#e3c29b' }
    ],
    materials: 'Charcoal and navy masonry, dark glass towers with magenta edge light, rain-wet stone paving that mirrors lamps and windows, warm timber and amber task lighting indoors, a cream tram with a red stripe, blue-glass kiosk screens.',
    type: 'The sheets use a heavy condensed sans on dark caption strips and a light serif footer. This page pairs Monoton (neon signage), Big Shoulders Display (labels) and Special Elite with IBM Plex Mono (the case file voice). These are page choices, not a type system for the city.',
    agents: 'City Agent A1 appears in every sheet as an angular robot in dark and silver panels, with a glowing cyan ring for an eye and cyan vertical slits, dressed in an ordinary dark hoodie, scarf and backpack. A lanyard badge carries a leaf and "City Agent A1" (in some panels just "A1"). A1 works at the Workshop bench, talks under the square\'s lights, holds a tablet in build mode, stands beside a library kiosk and appears as the helper portrait on the mobile card. The Guild residents are not depicted in these sheets; residents in the scenes are everyday people in coats, hoodies and scarves.',
    tradeoffs: [
      { label: 'Map vs street readability', text: 'Street scale is the strength: lamps, lit windows and the red-striped tram make routes and destinations obvious. At map scale the dark palette flattens most blocks into similar navy shapes, so the district leans on the bright river, labelled plates and magenta downtown roofs. MAP and TOP-DOWN keep stylised pictorial projections rather than flat cartography.' },
      { label: 'Device and production cost', text: 'The look depends on many light sources, reflections, rain and glow, all costly. The brief\'s proposed adaptation keeps key light accents and readable silhouettes on every tier and drops reflection complexity, volumetrics, particles and distant animated signage on lower tiers; higher tiers add atmosphere.' },
      { label: 'UI legibility', text: 'The blue-glass kiosk (Browse, Book, Ask) and the mobile card read clearly in the sheets. The review notes that small category symbols, text and the A1 badge need enlarging. Contrast, glare and route visibility on small screens are untested, and bright effects must not hide interaction cues.' },
      { label: 'Daylight gap', text: 'The brief asks for a deliberate daytime interpretation. All four selected sheets are dusk or night, so there is no evidence yet for how the city reads at noon.' },
      { label: 'Known residuals', text: 'From the repair record: the mobile map is pictorial and oblique, and the single phone is landscape. The rooftop view hides much of the west river. Some close views show two towers where the overview shows three. Library proportions and bridge spans vary between views, and caption weight and margins vary between sheets. No accessibility or usability measurements were made.' }
    ]
  };

  const SHEET_NOTES = [
    'The district at night from four cameras. MAP and TOP-DOWN show the River on the west edge, the low North bridge, the three-bay Workshop, Tree Square and the domed Library in a row, with downtown blocks north and the tram boulevard south. DIAGONAL and STREET show the cream tram with its red stripe passing the square.',
    'Life inside the lights: the Workshop bench with A1, a riverside home looking out to the bridge, A1 in conversation under the square\'s trees, and an evening gathering at Tree Square between the Workshop and the Library.',
    'Build mode places a glass volume on the square with red X, green Y and blue Z axes. Transit rides the ground-level tram past the Library; night and rain turn the square\'s paving into a mirror; the waterfront park looks back to the low bridge.',
    'A Riverside Library kiosk with Browse, Book and Ask; a phone map selecting the Workshop with A1 offering to check availability; a rooftop over the lit district; and an AR tabletop model with Workshop, Library, Transit and Park markers.'
  ];

  const LANDMARKS = [
    { id: 'R1', x: 17, y: 57 }, { id: 'B1', x: 20, y: 23.5 }, { id: 'W1', x: 47, y: 47 },
    { id: 'T1', x: 61.5, y: 47 }, { id: 'L1', x: 75.5, y: 47 }, { id: 'S1', x: 70, y: 76 }
  ];

  // ---- Helpers ----
  const h = (tag, cls, text) => el(tag, Object.assign({}, cls ? { class: cls } : {}, text != null ? { text } : {}));
  document.querySelectorAll('[data-num]').forEach((n) => { n.textContent = S.number; });

  // ---- Files ----
  function fileShell(core, letter, title, kicker) {
    const sec = el('section', { class: 'file', 'data-core': core, id: `file-${core}`, 'aria-labelledby': `fh-${core}`, tabindex: '-1' });
    sec.append(el('div', { class: 'file-tab', 'aria-hidden': 'true', text: `Exhibit ${letter}` }));
    sec.append(el('p', { class: 'overline', text: kicker }));
    sec.append(el('h2', { id: `fh-${core}`, text: title }));
    return sec;
  }

  function projectFile() {
    const sec = fileShell('project', 'A', 'The city in question', 'Exhibit A · Background');
    sec.append(el('p', { class: 'voice', text: 'Before you judge the lighting, know the place. This part isn\'t noir; it\'s the facts, as the lab wrote them down.' }));
    const block = Kit.projectBlock();
    block.removeAttribute('data-core');
    block.classList.add('dossier');
    sec.append(el('p', { class: 'city-name' }, [el('span', { text: A.name }), el('small', { text: `by ${A.by}` })]));
    sec.append(block);
    const dist = el('ol', { class: 'district' }, A.district.map((d) => el('li', {}, [el('b', { text: `${d.id} ${d.name}` }), ` ${d.note}`])));
    sec.append(el('h3', { text: 'The reference district, the same block in every study' }), dist);
    return sec;
  }

  function styleFile() {
    const sec = fileShell('style', 'B', 'How the city looks after dark', 'Exhibit B · The look');
    sec.append(el('blockquote', { class: 'intent' }, [el('p', { text: content.intent }), el('cite', { text: 'From the style brief' })]));
    sec.append(h('h3', null, 'Five leads'));
    sec.append(el('ol', { class: 'leads' }, content.principles.map((p) => el('li', { text: p }))));
    sec.append(h('h3', null, 'Colour, lifted from the sheets'));
    sec.append(el('p', { class: 'small', text: 'Averaged from small pixel areas of the selected sheets; approximate.' }));
    sec.append(el('ul', { class: 'tubes' }, content.palette.map((p) => {
      const li = el('li', { style: `--c:${p.hex}` });
      li.append(el('span', { class: 'tube', 'aria-hidden': 'true' }), el('span', { class: 'tube-name', text: p.name }), el('code', { text: p.hex }));
      return li;
    })));
    const grid = el('div', { class: 'two' });
    grid.append(el('div', {}, [h('h3', null, 'Materials and texture'), h('p', null, content.materials)]));
    grid.append(el('div', {}, [h('h3', null, 'Typography'), h('p', null, content.type),
      el('p', { class: 'specimen' }, [el('span', { class: 'sp-neon', text: 'Library' }), el('span', { class: 'sp-label', text: 'TRAM · S1' }), el('span', { class: 'sp-type', text: 'Case notes, 11:48 p.m.' })])]));
    sec.append(grid);
    return sec;
  }

  function viewsFile() {
    const sec = fileShell('views', 'C', 'One district, four photographs', 'Exhibit C · The evidence');
    sec.append(el('p', { class: 'voice', text: 'Kill the lights and sweep a torch over the map. Every study draws the same block, so the landmarks should be where I say they are.' }));
    // Flashlight map
    const wrap = el('div', { class: 'torch', style: '--x:61%;--y:47%' });
    const map = Kit.sheetImg(S, 0, 'tl', { alt: `${S.name} concept study, City perspectives MAP panel (${S.sheets[0].revision}): the River on the west edge, North bridge, Workshop, Tree Square, Library, downtown blocks and the tram boulevard.` });
    const dark = el('div', { class: 'torch-dark', 'aria-hidden': 'true' });
    const caption = el('p', { class: 'torch-cap', 'aria-live': 'polite' });
    wrap.append(map, dark);
    const pins = el('ul', { class: 'torch-pins', 'aria-label': 'Landmarks on the map' });
    const setLight = (x, y) => { wrap.style.setProperty('--x', `${x}%`); wrap.style.setProperty('--y', `${y}%`); };
    LANDMARKS.forEach((lm) => {
      const d = A.district.find((x) => x.id === lm.id);
      const b = el('button', { type: 'button', class: 'pin', style: `left:${lm.x}%;top:${lm.y}%`, 'aria-label': `${d.name}: ${d.note}` }, [el('span', { text: d.id })]);
      const show = () => { setLight(lm.x, lm.y); caption.textContent = `${d.id} · ${d.name}. ${d.note}`; pins.querySelectorAll('.pin').forEach((p) => p.classList.toggle('on', p === b)); };
      b.addEventListener('focus', show); b.addEventListener('mouseenter', show); b.addEventListener('click', show);
      pins.append(el('li', {}, b));
    });
    wrap.append(pins);
    wrap.addEventListener('pointermove', (e) => {
      const r = wrap.getBoundingClientRect();
      setLight(((e.clientX - r.left) / r.width) * 100, ((e.clientY - r.top) / r.height) * 100);
    });
    caption.textContent = 'T1 · Tree Square. One large living shade tree at the centre of an open square.';
    sec.append(el('figure', { class: 'torch-fig' }, [wrap, el('figcaption', {}, [caption, el('span', { class: 'small', text: 'Map panel cropped from the City perspectives sheet. Hover, tap or tab through the pins.' })])]));

    // The four photographs
    sec.append(h('h3', null, 'The four photographs'));
    sec.append(el('p', { class: 'stamp-note' }, [el('span', { class: 'stamp', text: 'Concept study' }), ` ${A.conceptNote}`]));
    const grid = el('div', { class: 'photos' });
    S.sheets.forEach((sheet, i) => {
      const img = Kit.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sheet.title} (${sheet.revision}), four panels: ${Kit.PANEL_NAMES[i].join(', ')}.` });
      const fig = el('figure', { class: 'photo', style: `--r:${[-1.4, 1.1, 0.8, -0.9][i]}deg` }, [
        el('a', { href: Kit.href(sheet.image), class: 'photo-link', 'aria-label': `Open full-size sheet: ${sheet.title}, ${sheet.revision}` }, img),
        el('figcaption', {}, [
          el('b', { text: `Photo ${i + 1} · ${sheet.title} · ${sheet.revision}` }),
          el('span', { class: 'panels', text: Kit.PANEL_NAMES[i].join(' · ') }),
          h('span', null, SHEET_NOTES[i])
        ])
      ]);
      grid.append(fig);
    });
    sec.append(grid);
    return sec;
  }

  function agentsFile() {
    const sec = fileShell('agents', 'D', 'Persons of interest', 'Exhibit D · Who turned up');
    const a1 = el('div', { class: 'subject' });
    const shots = el('div', { class: 'mugs' }, [
      el('figure', {}, [Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): City Agent A1, an angular dark and silver robot with a cyan eye ring and a leaf badge, talking with a smiling man in a mustard scarf.` }), el('figcaption', { text: 'Conversation · Living community' })]),
      el('figure', {}, [Kit.sheetImg(S, 3, 'tl', { alt: `${S.name} concept study, Interfaces, Facility panel (${S.sheets[3].revision}): A1 with an A1 lanyard badge beside a visitor using the Riverside Library kiosk.` }), el('figcaption', { text: 'Facility · Interfaces' })])
    ]);
    a1.append(shots, el('div', { class: 'subject-card' }, [
      el('p', { class: 'overline', text: 'Subject' }),
      el('h3', { text: 'City Agent A1' }),
      el('dl', { class: 'traits' }, [
        el('dt', { text: 'Build' }), el('dd', { text: 'Angular robot, dark and silver panels' }),
        el('dt', { text: 'Eyes' }), el('dd', { text: 'Glowing cyan ring and vertical slits' }),
        el('dt', { text: 'Clothes' }), el('dd', { text: 'Dark hoodie, scarf, backpack' }),
        el('dt', { text: 'Marks' }), el('dd', { text: 'Leaf lanyard badge: "City Agent A1" or "A1"' })
      ]),
      h('p', null, content.agents),
      el('p', { class: 'small', text: A.agentA1 })
    ]));
    sec.append(a1);
    sec.append(h('h3', null, 'The Guild: fourteen names on file'));
    sec.append(el('p', { class: 'voice', text: 'No photographs of these fourteen. The sheets don\'t show them, so I won\'t draw them. The roster stands as the lab filed it.' }));
    sec.append(el('ul', { class: 'roster' }, A.guild.map((g, i) => el('li', {}, [
      el('span', { class: 'rno', text: String(i + 1).padStart(2, '0') }), el('b', { text: g.name }), el('span', { text: g.role })
    ]))));
    sec.append(el('p', { class: 'small', text: A.guildNote }));
    return sec;
  }

  function tradeoffsFile() {
    const sec = fileShell('tradeoffs', 'E', 'What holds up, and what doesn\'t', 'Exhibit E · Strengths and trade-offs');
    sec.append(el('p', { class: 'voice', text: 'Every city has an alibi. This one\'s is good at street level and thin in daylight.' }));
    sec.append(el('dl', { class: 'leads-dl' }, content.tradeoffs.flatMap((t, i) => [
      el('dt', {}, [el('span', { class: 'rno', text: `E${i + 1}` }), ` ${t.label}`]), el('dd', { text: t.text })
    ])));
    return sec;
  }

  function statusFile() {
    const sec = fileShell('status', 'F', 'Case status', 'Exhibit F · Where things stand');
    sec.append(el('p', { class: 'stamp big', text: 'Open file' }));
    const st = Kit.statusBlock(S);
    st.removeAttribute('data-core');
    sec.append(el('p', { class: 'voice', text: 'Selected revisions, the review summary word for word, and where the paperwork lives.' }), st);
    return sec;
  }

  const FILES = [
    { core: 'project', letter: 'A', title: 'The city', hint: 'Background', make: projectFile, art: 'city' },
    { core: 'style', letter: 'B', title: 'The look', hint: 'Palette, leads, type', make: styleFile, art: 'palette' },
    { core: 'views', letter: 'C', title: 'Four photographs', hint: 'Sheets and landmarks', make: viewsFile, art: 'photo' },
    { core: 'agents', letter: 'D', title: 'Persons of interest', hint: 'A1 and the Guild', make: agentsFile, art: 'agent' },
    { core: 'tradeoffs', letter: 'E', title: 'The alibi', hint: 'Strengths, trade-offs', make: tradeoffsFile, art: 'scale' },
    { core: 'status', letter: 'F', title: 'Case status', hint: 'Revisions, reviews', make: statusFile, art: 'stamp' }
  ];

  const ART = {
    city: '<svg viewBox="0 0 120 70" aria-hidden="true"><path d="M8 62V30h14V20h16v10h10v32M58 62V36l12-8v8l12-8v8l12-8v34M100 62V40h12v22" fill="none" stroke="#5fe3ff" stroke-width="2.5"/><path d="M4 62h112" stroke="#f0b25f" stroke-width="2.5"/></svg>',
    palette: '<svg viewBox="0 0 120 70" aria-hidden="true"><path d="M14 20h92" stroke="#ff4fae" stroke-width="5" stroke-linecap="round"/><path d="M14 36h70" stroke="#5fe3ff" stroke-width="5" stroke-linecap="round"/><path d="M14 52h84" stroke="#f0b25f" stroke-width="5" stroke-linecap="round"/></svg>',
    photo: '<svg viewBox="0 0 120 70" aria-hidden="true"><rect x="18" y="8" width="84" height="54" fill="none" stroke="#e3c29b" stroke-width="2.5"/><path d="M30 50l18-18 14 12 10-8 18 14" fill="none" stroke="#5fe3ff" stroke-width="2.5"/><circle cx="80" cy="24" r="5" fill="#f0b25f"/></svg>',
    agent: '<svg viewBox="0 0 120 70" aria-hidden="true"><path d="M44 62c0-14 6-22 16-22s16 8 16 22" fill="none" stroke="#c9d3de" stroke-width="2.5"/><path d="M46 22c0-10 6-16 14-16s14 6 14 16-6 16-14 16-14-6-14-16z" fill="none" stroke="#c9d3de" stroke-width="2.5"/><circle cx="56" cy="22" r="5" fill="none" stroke="#5fe3ff" stroke-width="2.5"/><path d="M66 18v8" stroke="#5fe3ff" stroke-width="2.5"/></svg>',
    scale: '<svg viewBox="0 0 120 70" aria-hidden="true"><path d="M60 10v50M36 60h48M24 22h72" stroke="#e3c29b" stroke-width="2.5" fill="none"/><path d="M24 22l-12 22h24zM96 22l-12 18h24z" fill="none" stroke="#f0b25f" stroke-width="2.5"/></svg>',
    stamp: '<svg viewBox="0 0 120 70" aria-hidden="true"><rect x="14" y="16" width="92" height="38" rx="4" fill="none" stroke="#ff4fae" stroke-width="3" transform="rotate(-6 60 35)"/><text x="60" y="41" text-anchor="middle" font-size="15" fill="#ff4fae" font-family="Special Elite, monospace" transform="rotate(-6 60 35)">OPEN</text></svg>'
  };

  // ---- Build board and drawer ----
  const board = document.getElementById('board-cards');
  const drawer = document.getElementById('drawer');
  const cards = [];
  const files = {};
  const tilt = [-2.2, 1.6, -0.8, 2.4, -1.8, 1.2];

  FILES.forEach((f, i) => {
    const sec = f.make();
    const next = FILES[i + 1];
    const foot = el('div', { class: 'file-foot' });
    if (next) {
      const nb = el('button', { type: 'button', class: 'next-btn', text: `Next: Exhibit ${next.letter}, ${next.title} →` });
      nb.addEventListener('click', () => open(next.core, true));
      foot.append(nb);
    } else {
      foot.append(el('a', { class: 'next-btn', href: '#board', text: 'Back to the board ↑' }));
    }
    sec.append(foot);
    sec.hidden = true;
    drawer.append(sec);
    files[f.core] = sec;

    const card = el('button', { type: 'button', class: 'card', style: `--t:${tilt[i]}deg`, 'aria-controls': `file-${f.core}`, 'aria-expanded': 'false' });
    card.innerHTML = `<span class="pinhead" aria-hidden="true"></span><span class="ex">Exhibit ${f.letter}</span>${ART[f.art]}<span class="ct">${f.title}</span><span class="ch">${f.hint}</span><span class="opened" aria-hidden="true">Opened</span>`;
    card.addEventListener('click', () => open(f.core, true));
    board.append(card);
    cards.push({ core: f.core, card });
  });

  let current = null;
  function open(core, scroll) {
    if (current === core && !files[core].hidden) { if (scroll) focusFile(core); return; }
    Object.entries(files).forEach(([k, sec]) => { sec.hidden = k !== core; });
    cards.forEach(({ core: c, card }) => {
      card.setAttribute('aria-expanded', String(c === core));
      card.classList.toggle('active', c === core);
      if (c === core) card.classList.add('seen');
    });
    current = core;
    drawer.classList.remove('slide');
    if (!reduced) { void drawer.offsetWidth; drawer.classList.add('slide'); }
    if (scroll) focusFile(core);
  }
  function focusFile(core) {
    const sec = files[core];
    sec.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
    sec.focus({ preventScroll: true });
  }
  open('project', false);
  cards[0].card.classList.remove('seen');

  // ---- Red string between the pins ----
  const string = board.querySelector('.string');
  function drawString() {
    const br = board.getBoundingClientRect();
    string.setAttribute('viewBox', `0 0 ${br.width} ${br.height}`);
    const raw = cards.map(({ card }) => {
      const p = card.querySelector('.pinhead').getBoundingClientRect();
      return [p.left + p.width / 2 - br.left, p.top + p.height / 2 - br.top, card.offsetTop];
    });
    // Snake through the rows so the string never cuts back across a card.
    const rows = [...new Set(raw.map((r) => r[2]))].sort((a, b) => a - b);
    const pts = rows.flatMap((top, i) => {
      const row = raw.filter((r) => r[2] === top).sort((a, b) => a[0] - b[0]);
      return i % 2 ? row.reverse() : row;
    });
    let d = '';
    for (let i = 0; i < pts.length; i++) {
      const [x, y] = pts[i];
      if (i === 0) { d += `M${x} ${y}`; continue; }
      const [px, py] = pts[i - 1];
      const sag = Math.min(16, Math.hypot(x - px, y - py) * 0.05);
      d += ` Q${(x + px) / 2} ${(y + py) / 2 + sag} ${x} ${y}`;
    }
    string.innerHTML = `<path d="${d}" fill="none" stroke="#c4152f" stroke-width="3.2" stroke-linecap="round" opacity=".95"/>`;
  }
  drawString();
  window.addEventListener('resize', drawString);
  if (document.fonts) document.fonts.ready.then(drawString);

  // ---- Nav and notes ----
  const nav = Kit.mountNav(document.getElementById('nav-slot'), S);
  nav.querySelectorAll('a').forEach((a) => a.classList.add('neon-link'));
  Kit.notesDialog(S, content, document.getElementById('notes-btn'));

  // ---- Rain ----
  const hero = document.querySelector('.hero');
  const canvas = hero.querySelector('.rain');
  const ctx = canvas.getContext('2d');
  let drops = [];
  let W = 0; let H = 0; let running = false; let raf = 0;
  function size() {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    W = hero.clientWidth; H = hero.clientHeight;
    canvas.width = W * dpr; canvas.height = H * dpr;
    canvas.style.width = `${W}px`; canvas.style.height = `${H}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    const n = Math.round((W * H) / (reduced ? 9000 : 5200));
    drops = Array.from({ length: n }, () => newDrop(true));
    if (reduced) frame();
  }
  function newDrop(any) {
    const z = Math.random();
    return { x: Math.random() * (W + 200) - 100, y: any ? Math.random() * H : -20 - Math.random() * 100, len: 10 + z * 22, v: 7 + z * 11, a: 0.12 + z * 0.3, w: z > 0.8 ? 1.4 : 1 };
  }
  const splashes = [];
  function frame() {
    ctx.clearRect(0, 0, W, H);
    ctx.lineCap = 'round';
    for (const d of drops) {
      ctx.strokeStyle = `rgba(170,205,240,${d.a})`;
      ctx.lineWidth = d.w;
      ctx.beginPath(); ctx.moveTo(d.x, d.y); ctx.lineTo(d.x - d.len * 0.18, d.y + d.len); ctx.stroke();
      if (!reduced) {
        d.y += d.v; d.x -= d.v * 0.18;
        if (d.y > H * (0.82 + Math.random() * 0.18)) {
          if (Math.random() < 0.3) splashes.push({ x: d.x, y: d.y, r: 1, a: 0.35 });
          Object.assign(d, newDrop(false));
        }
      }
    }
    for (let i = splashes.length - 1; i >= 0; i--) {
      const s = splashes[i];
      ctx.strokeStyle = `rgba(240,178,95,${s.a})`;
      ctx.beginPath(); ctx.ellipse(s.x, s.y, s.r * 2.2, s.r * 0.6, 0, 0, Math.PI * 2); ctx.stroke();
      s.r += 0.5; s.a -= 0.025;
      if (s.a <= 0) splashes.splice(i, 1);
    }
  }
  function loop() { frame(); if (running) raf = requestAnimationFrame(loop); }
  size();
  window.addEventListener('resize', size);
  if (!reduced) {
    const io = new IntersectionObserver(([e]) => {
      if (e.isIntersecting && !running) { running = true; loop(); }
      else if (!e.isIntersecting) { running = false; cancelAnimationFrame(raf); }
    });
    io.observe(hero);
    document.addEventListener('visibilitychange', () => { if (document.hidden) { running = false; cancelAnimationFrame(raf); } else if (!running) { running = true; loop(); } });
  }
})();
