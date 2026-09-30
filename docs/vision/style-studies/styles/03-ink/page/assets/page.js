// 03 Ink and watercolor: page content, illustrations and interactions.
(function () {
  const S = Kit.style('03-ink');
  const A = window.AGENTNAGAR;
  const { el } = Kit;
  const $ = (sel) => document.querySelector(sel);
  const reduced = Kit.reducedMotion();
  const PAPER = '#f9f1e4';

  // ---------- Page copy (from brief.md, the sheets and the repair record) ----------
  const content = {
    intent: 'An illustrated city that feels drawn in an architectural sketchbook. Black ink contours, selective crosshatching, ivory paper, and watercolor washes create warmth and visible human authorship. Ochre, rust, sage, and teal support a quieter atmosphere.',
    principles: [
      'Ink carries the structure. Black contours and selective crosshatching describe form; nothing is fully rendered.',
      'Wash carries the mood. Ochre, rust, sage and teal over ivory paper give a quieter, warmer atmosphere.',
      'One hand for everyone. People and agents share the illustrated linework instead of appearing as realistic figures placed in a drawing.',
      'Detail goes where attention should. At street and conversation distance, line weight and selective detail lead to faces, doors and interactive objects.',
      'Night keeps its paths. Light washes and clear silhouettes keep routes readable after dark.'
    ],
    palette: [
      { name: 'Ivory paper', hex: '#F9F1E4' },
      { name: 'Sepia ink', hex: '#34261E' },
      { name: 'River teal', hex: '#3195BA' },
      { name: 'Workshop brick', hex: '#CC8D61' },
      { name: 'Scarf rust', hex: '#A04A2D' },
      { name: 'Tram red', hex: '#B45545' },
      { name: 'Canopy sage', hex: '#99965B' },
      { name: 'Ochre timber', hex: '#9D7D51' },
      { name: 'Library roof grey', hex: '#9CA1A7' },
      { name: 'Warm stone', hex: '#D0AF93' }
    ],
    materials: 'Ivory paper, black ink contours, selective crosshatching and granulating watercolour washes. In the sheets: a red-brick Workshop with steel-framed glazing, a stone Library under a grey metal vault with a glazed strip, timber benches and planted squares; interiors are layered with books, tools, fabrics and personal belongings.',
    type: 'The sheets letter their panel captions in a bold old-style serif set in capitals (MAP, WORKSHOP) with a small serif footer, and use a plain serif inside the interface panels. This page pairs EB Garamond for reading with Caveat handwriting for annotations; the handwriting is this page’s addition, not something the sheets show.',
    agents: 'Where the sheets show her, City Agent A1 is drawn in the same hand as everyone around her: a woman with a curly dark bob, a rust scarf and a sage-olive field jacket, with backpack straps and a round leaf badge marked A1. Nothing in her line or wash marks her as an agent rather than a person; the label and badge do that work. The sheets show no Guild residents, so this page proposes no designs for them.',
    tradeoffs: [
      { mark: '✓', label: 'Map scale', text: 'The guide-map views read well: the straight teal river, brick sawtooth hall, round canopy and grey vault stay distinct by colour and silhouette. The repair record notes that MAP keeps some pictorial roof shading rather than flat footprints, and the dense tree stippling competes with paths.' },
      { mark: '✓', label: 'Street scale', text: 'Strongest at street and conversation distance, where line weight and selective detail can lead the eye to faces, doors and objects. Crowded gatherings get busy: hatching, texture and many small figures compete for attention.' },
      { mark: '?', label: 'Movement and zoom', text: 'The brief’s main prototype question is whether linework stays stable while the view moves and zooms. These stills cannot answer it; shimmering or crawling hatch lines are the obvious risk.' },
      { mark: '~', label: 'Device and production cost', text: 'Proposed adaptation: stable outlines and economical surface treatments, with less hatching and fewer small marks on smaller screens; higher tiers could enrich texture and atmospheric layering. Keeping one consistent hand across every asset and view is an authoring question the sheets do not settle.' },
      { mark: '~', label: 'UI legibility', text: 'The sheets pair the drawing with clean flat tiles (Browse, Book, Ask; Workshop, Library, Transit, Park) and a serif card, which read clearly. Tiny phone text and badge lettering need the full-size image. Handwriting like this page’s should stay decorative, not carry controls.' },
      { mark: '✓', label: 'Night', text: 'Night and rain keeps routes readable with warm windows, lamps and wet reflections; the washes darken but the silhouettes hold.' }
    ],
    residuals: [
      'Independent review found a fourth Workshop roof peak in the overview STREET, living GATHERING and creating TRANSIT panels. Local edits reduced each to three visible peaks; pixel identity outside the edited roofs is not claimed.',
      'MAP keeps some pictorial roof shading; TOP-DOWN is not a calibrated orthographic render.',
      'Road widths, roof orientations, tram-stop details and neighbouring low-rise masses vary between panels.',
      'Door-facing directions and exact landmark coordinates cannot be certified from these illustrations.',
      'Bridge spans are clearest in the overview and park views; cropped home and rooftop views do not show the full bridge.'
    ],
    sheetNotes: [
      'MAP and TOP-DOWN label all six landmarks; DIAGONAL adds the stepped towers to the north; STREET looks across the square at the brick Workshop, the tree and the Library, with a red and cream tram in front.',
      'WORKSHOP opens its doors toward the tree; HOME looks west over the sawtooth roofs to the river and bridge; A1 is labelled in CONVERSATION; the GATHERING fills Tree Square between Workshop and Library.',
      'BUILD MODE lifts the Workshop on red, green and blue axes; TRANSIT looks from the tram at Workshop, tree and Library; NIGHT AND RAIN keeps the square readable by lamplight; the WATERFRONT PARK follows the bank toward the bridge.',
      'FACILITY is the Library kiosk (Browse, Book, Ask); MOBILE has the Workshop selected with A1; ROOFTOP looks west over the trees and Workshop to the river; AR TABLETOP points at the Workshop.'
    ]
  };

  // ---------- Fill the text ----------
  document.querySelectorAll('[data-fill="number"]').forEach((n) => { n.textContent = S.number; });
  $('[data-fill="intent-short"]').textContent = 'An illustrated city that feels drawn in an architectural sketchbook: ink contours, selective crosshatching and watercolour washes on ivory paper, in ochre, rust, sage and teal.';
  $('[data-fill="intent"]').textContent = content.intent;
  $('#it-f').textContent = `${S.sheets.length} sheets · ${S.sheets.length * 4} panels · concept studies`;

  const project = Kit.projectBlock();
  project.removeAttribute('data-core');
  $('#project-slot').append(project);

  content.principles.forEach((p) => {
    const [head, ...rest] = p.split('. ');
    $('#principles').append(el('li', {}, [el('b', { text: head + '.' }), ' ' + rest.join('. ')]));
  });
  $('#materials').textContent = content.materials;
  $('#typeface').textContent = content.type;

  // ---------- Views ----------
  $('#concept-note').textContent = `These four sheets are concept studies. ${A.conceptNote}`;
  S.sheets.forEach((sheet, i) => {
    const link = el('a', { class: 'sheet-link', href: Kit.href(sheet.image), 'aria-label': `Open the full-size ${sheet.title} sheet (${sheet.revision})` }, Kit.sheetImg(S, i));
    link.querySelector('img').alt = `${S.name} concept study: ${sheet.title} (${sheet.revision}), panels ${Kit.PANEL_NAMES[i].join(', ')}. ${content.sheetNotes[i]}`;
    const fig = el('figure', { class: 'taped bleed-in', style: `--wd:${i * 0.15}s` }, [
      link,
      el('figcaption', {}, [
        el('span', { class: 'cap-t', text: sheet.title }),
        el('span', { class: 'cap-r', text: ` · ${sheet.revision} · concept study` }),
        el('p', { class: 'cap-l', text: content.sheetNotes[i] })
      ])
    ]);
    $('#sheets').append(fig);
  });
  [
    [0, 'br', 'Street, after the repair: three roof peaks on the brick Workshop, the shade tree, the Library vault and a red and cream tram.'],
    [2, 'bl', 'Night and rain: warm windows and wet reflections keep the paths across the square legible, as the brief asks.']
  ].forEach(([i, p, note], k) => {
    $('#details').append(el('figure', { class: 'detail bleed-in', style: `--wd:${k * 0.2}s` }, [
      Kit.sheetImg(S, i, p),
      el('figcaption', {}, [el('span', { class: 'hand', text: note }), el('span', { class: 'small', text: ` (${S.sheets[i].title}, ${S.sheets[i].revision}, concept study)` })])
    ]));
  });

  // ---------- Agents ----------
  $('#a1-text').textContent = content.agents;
  $('#a1-shared').textContent = A.agentA1;
  [[1, 'bl', 'Conversation: labelled “City Agent A1”'], [2, 'tr', 'Transit: scarf and badge'], [3, 'tr', 'Mobile: A1 on the Workshop card']].forEach(([i, p, cap]) => {
    $('#a1-crops').append(el('figure', { class: 'bleed-in' }, [Kit.sheetImg(S, i, p), el('figcaption', { text: cap })]));
  });
  $('#guild-intro').textContent = 'The brief asks that agents share the illustrated linework rather than look like realistic figures pasted into a drawing. The sheets do not depict the Guild, so their look in this style is unexplored. The fourteen residents and their proposed public roles:';
  A.guild.forEach((g) => $('#roster').append(el('li', {}, [el('span', { class: 'rn', text: g.name }), el('span', { class: 'rr', text: g.role })])));
  $('#guild-note').textContent = A.guildNote;

  // ---------- Trade-offs ----------
  content.tradeoffs.forEach((t) => {
    $('#ledger').append(el('dt', {}, [el('span', { class: 'mk', 'aria-hidden': 'true', text: t.mark }), t.label]), el('dd', { text: t.text }));
  });
  content.residuals.forEach((r) => $('#residuals').append(el('li', { text: r })));

  // ---------- Status and navigation ----------
  $('#status-slot').append(Kit.statusBlock(S));
  Kit.mountNav($('#nav-slot'), S);

  // ---------- Notes dialog ----------
  Kit.notesDialog(S, content, $('#notes-btn'));

  // ---------- Illustrations ----------
  const { Pen } = window.Sketch;
  const W = { sky: '#8fc3d6', night: '#2b3552', teal: '#3195ba', brick: '#cc8d61', brickDeep: '#ad7750', rust: '#a04a2d', tram: '#b45545', cream: '#efe2c4', sage: '#99965b', olive: '#797f44', ochre: '#e1b784', ochreDeep: '#9d7d51', grey: '#9ca1a7', stone: '#d0af93' };

  function bez(p0, p1, p2, p3, n) {
    const pts = [];
    for (let i = 0; i <= n; i++) {
      const t = i / n, u = 1 - t;
      pts.push([u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0], u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]]);
    }
    return pts;
  }
  function ellipsePts(cx, cy, rx, ry, n, turns, jit, R) {
    const pts = [];
    const k = n || 24, T = turns || 1;
    for (let i = 0; i <= k * T; i++) {
      const a = (i / k) * Math.PI * 2 - 0.6;
      const r = 1 + (R ? (R() - 0.5) * (jit || 0.06) : 0);
      pts.push([cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r]);
    }
    return pts;
  }
  function paperFill(pen, d, parent) { pen.node('path', { d, fill: PAPER, stroke: 'none' }, parent); }
  function figure(pen, x, y, colour, s) {
    const k = s || 1;
    pen.wash(pen.blob(x, y - 24 * k, 6 * k, 10 * k, 7), colour, { op: 0.65 });
    pen.cloud(x, y - 38 * k, 4.5 * k, 5 * k, { n: 6, bump: 0.2, w: 1.1 });
    pen.poly([[x, y - 33 * k], [x + 0.5, y - 15 * k]], { w: 1.3 });
    pen.poly([[x, y - 15 * k], [x - 4 * k, y]], { w: 1.1 });
    pen.poly([[x, y - 15 * k], [x + 4 * k, y]], { w: 1.1 });
    pen.poly([[x, y - 29 * k], [x - 6 * k, y - 18 * k]], { w: 1 });
  }

  function drawHero(svg) {
    const pen = Pen(svg, 21);
    pen.delayStep = 0.003; pen.maxDelay = 0.75;
    const defs = pen.node('defs');
    const cc = pen.node('clipPath', { id: 'hero-canopy' }, defs);
    const canopyD = pen.cloudPath(605, 232, 165, 108, 16, 0.42);
    pen.node('path', { d: canopyD }, cc);

    // Sky, day and dusk.
    const skyPts = [[40, 78], [620, 66], [1165, 80], [1172, 320], [860, 334], [30, 336]];
    pen.wash(pen.fillPoly(skyPts, 10), W.sky, { op: 0.34, cls: 'sky-day', edge: 6 });
    pen.wash(pen.fillPoly(skyPts, 10), W.night, { op: 0.8, cls: 'sky-night', edge: 6 });

    // Distant bank trees and the north bridge.
    for (let x = 6; x < 175; x += 22) pen.cloud(x, 300 + pen.J(3), 13, 9, { n: 7, w: 0.9, op: 0.8 });
    pen.wash(pen.blob(90, 300, 90, 14, 9), W.olive, { op: 0.35 });
    pen.poly([[0, 312], [176, 317]], { w: 1.5, double: true });
    pen.poly([[0, 321], [176, 325]], { w: 1.2 });
    [44, 90, 136].forEach((x) => { pen.line(x, 322, x + 1, 340, { w: 1.2 }); });
    [[0, 44], [44, 90], [90, 136], [136, 176]].forEach(([a, b]) => pen.poly(bez([a, 340], [a + 6, 326], [b - 6, 326], [b, 340], 6), { w: 0.9 }));
    for (let x = 4; x < 176; x += 9) pen.line(x, 305 + x * 0.028, x, 312 + x * 0.028, { w: 0.6, over: 0, step: 0.001 });

    // River.
    pen.wash(pen.fillPoly([[0, 338], [160, 340], [162, 452], [72, 560], [0, 560]], 4), W.teal, { op: 0.5, wd: 0.2 });
    pen.line(160, 341, 162, 452, { w: 1.4, double: true });
    pen.line(162, 452, 72, 560, { w: 1.4 });
    for (let i = 0; i < 16; i++) {
      const y = 355 + i * 12.5, maxX = y < 452 ? 150 : 150 - (y - 452) * 0.83;
      const x = 8 + pen.R() * Math.max(10, maxX - 40);
      pen.poly([[x, y], [x + 8, y - 3], [x + 16, y], [x + 24, y - 2]], { w: 0.8, j: 0.4, op: 0.75 });
    }

    // Background stepped towers with planted terraces.
    [[318, 96, 150], [505, 86, 100], [790, 96, 128], [1040, 90, 170]].forEach(([x, w, top], i) => {
      const body = [[x, 336], [x, top + 36], [x + 12, top + 36], [x + 12, top], [x + w - 12, top], [x + w - 12, top + 36], [x + w, top + 36], [x + w, 336]];
      paperFill(pen, pen.wl(body, 0) + 'Z');
      pen.wash(pen.fillPoly(body, 3), W.grey, { op: 0.28, wd: 0.3 + i * 0.1 });
      pen.poly(body, { w: 1.1, op: 0.85 });
      for (let y = top + 48; y < 330; y += 17) pen.line(x + 5, y, x + w - 5, y, { w: 0.55, op: 0.7, over: 0, step: 0.001 });
      for (let xx = x + 16; xx < x + w - 6; xx += 16) pen.line(xx, top + 42, xx, 334, { w: 0.5, op: 0.55, over: 0, step: 0.001 });
      pen.cloud(x + 20, top + 30, 12, 7, { n: 6, w: 0.8 });
      pen.cloud(x + w - 22, top + 30, 12, 7, { n: 6, w: 0.8 });
      pen.cloud(x + w / 2, top - 5, 16, 7, { n: 7, w: 0.8 });
      pen.wash(pen.blob(x + w / 2, top - 2, 26, 8, 7), W.sage, { op: 0.45 });
    });

    // Workshop: brick hall, three sawtooth bays.
    const ws = [[180, 452], [180, 248], [280, 335], [280, 248], [380, 335], [380, 248], [480, 335], [480, 452]];
    paperFill(pen, pen.wl(ws, 0) + 'Z');
    pen.wash(pen.fillPoly(ws, 4), W.brick, { op: 0.6, wd: 0.25 });
    pen.wash(pen.fillPoly([[180, 250], [280, 335], [180, 335]], 3), W.brickDeep, { op: 0.3, wd: 0.4 });
    pen.wash(pen.fillPoly([[280, 250], [380, 335], [280, 335]], 3), W.brickDeep, { op: 0.3, wd: 0.45 });
    pen.wash(pen.fillPoly([[380, 250], [480, 335], [380, 335]], 3), W.brickDeep, { op: 0.3, wd: 0.5 });
    pen.poly(ws, { w: 2.1, double: true });
    pen.line(176, 338, 484, 338, { w: 1.3 });
    [180, 280, 380].forEach((x) => {
      for (let k = 1; k < 4; k++) pen.poly([[x + 4, 248 + k * 20], [x + 100 - k * 23, 335 - 2]], { w: 0.6, op: 0.7, step: 0.001 });
    });
    [0, 1, 2].forEach((b) => {
      const x0 = 180 + b * 100;
      if (b === 1) {
        pen.node('path', { d: pen.wl([[305, 452], [305, 372], [355, 372], [355, 452]], 0), class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.9, filter: 'url(#bleed)' });
        pen.poly([[305, 452], [305, 372], [355, 372], [355, 452]], { w: 1.6 });
        pen.line(330, 374, 330, 452, { w: 0.9 });
        pen.poly(bez([300, 372], [305, 352], [355, 352], [360, 372], 5), { w: 1 });
      } else {
        pen.node('path', { d: pen.wl([[x0 + 18, 360], [x0 + 82, 360], [x0 + 82, 440], [x0 + 18, 440]], 0) + 'Z', class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.9, filter: 'url(#bleed)' });
        pen.rect(x0 + 18, 360, 64, 80, { w: 1.5 });
        pen.line(x0 + 39, 360, x0 + 39, 440, { w: 0.8, over: 0 });
        pen.line(x0 + 61, 360, x0 + 61, 440, { w: 0.8, over: 0 });
        pen.line(x0 + 18, 387, x0 + 82, 387, { w: 0.8, over: 0 });
        pen.line(x0 + 18, 413, x0 + 82, 413, { w: 0.8, over: 0 });
      }
    });
    for (let y = 346; y < 450; y += 7) {
      for (let n = 0; n < 2; n++) {
        const x = 184 + pen.R() * 286, len = 8 + pen.R() * 10;
        const inWin = [[198, 262], [298, 362], [398, 462]].some(([a, b]) => x + len > a && x < b && y > 354);
        if (!inWin) pen.line(x, y, x + len, y, { w: 0.7, op: 0.75, over: 0, step: 0.001 });
      }
    }

    // Library: stone walls under a rounded reading-room roof.
    const vault = bez([730, 335], [760, 238], [1050, 238], [1080, 335], 14);
    const lib = [[730, 452], ...vault, [1080, 452]];
    paperFill(pen, pen.wl(lib, 0) + 'Z');
    pen.wash(pen.fillPoly([[730, 452], [730, 338], [1080, 338], [1080, 452]], 4), W.stone, { op: 0.55, wd: 0.3 });
    pen.wash(pen.fillPoly(vault, 3), W.grey, { op: 0.6, wd: 0.35 });
    pen.poly(vault, { w: 2, double: true });
    pen.poly(bez([760, 336], [785, 262], [1025, 262], [1050, 336], 12), { w: 0.8, op: 0.8 });
    pen.poly(bez([800, 336], [820, 282], [990, 282], [1010, 336], 10), { w: 0.7, op: 0.7 });
    pen.wash(pen.fillPoly([[860, 262], [950, 262], [950, 276], [860, 276]], 2), W.sky, { op: 0.8, wd: 0.5 });
    pen.rect(860, 262, 90, 14, { w: 0.9 });
    for (let x = 872; x < 950; x += 12) pen.line(x, 262, x, 276, { w: 0.5, over: 0, step: 0.001 });
    pen.line(722, 336, 1088, 336, { w: 1.6, double: true });
    pen.line(726, 347, 1084, 347, { w: 0.9 });
    pen.line(730, 336, 730, 452, { w: 1.6 });
    pen.line(1080, 336, 1080, 452, { w: 1.6 });
    for (let i = 0; i < 7; i++) {
      const x = 750 + i * 46;
      if (i === 3) {
        pen.node('path', { d: pen.wl([[886, 372], [926, 372], [926, 452], [886, 452]], 0) + 'Z', class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.9, filter: 'url(#bleed)' });
        pen.poly([[886, 452], [886, 372], [926, 372], [926, 452]], { w: 1.5 });
        pen.line(906, 374, 906, 452, { w: 0.8 });
        continue;
      }
      pen.node('path', { d: pen.wl([[x, 362], [x + 30, 362], [x + 30, 440], [x, 440]], 0) + 'Z', class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.9, filter: 'url(#bleed)' });
      pen.rect(x, 362, 30, 78, { w: 1.2 });
      pen.line(x, 380, x + 30, 380, { w: 0.7, over: 0 });
      pen.line(x + 15, 380, x + 15, 440, { w: 0.6, over: 0 });
    }

    // Ground, paving and tracks.
    pen.wash(pen.fillPoly([[165, 452], [1200, 452], [1200, 492], [150, 492]], 3), W.ochre, { op: 0.28, wd: 0.5 });
    pen.line(162, 452, 1200, 452, { w: 1.5, double: true });
    for (let x = 200; x < 1200; x += 70) pen.line(x, 454, x - 16, 490, { w: 0.5, op: 0.6, over: 0, step: 0.001 });
    [500, 512, 532, 544].forEach((y, i) => pen.line(i < 2 ? 140 : 110, y, 1200, y, { w: i % 2 ? 1 : 1.4, over: 0 }));
    for (let x = 150; x < 1200; x += 20) {
      pen.line(x, 498, x - 3, 514, { w: 0.6, op: 0.7, over: 0, step: 0.0005 });
      pen.line(x - 10, 530, x - 13, 546, { w: 0.6, op: 0.7, over: 0, step: 0.0005 });
    }

    // Tree Square: one big shade tree over a planter ring.
    pen.poly(ellipsePts(610, 452, 80, 11, 20, 1), { w: 1.2 });
    pen.wash(pen.blob(610, 452, 82, 12, 9), W.ochreDeep, { op: 0.35 });
    paperFill(pen, canopyD);
    pen.wash(canopyD, W.sage, { op: 0.62, wd: 0.35 });
    pen.wash(pen.blob(655, 285, 110, 45, 9), W.olive, { op: 0.45, wd: 0.6 });
    pen.stroke(canopyD, { w: 1.8 });
    pen.stroke(pen.cloudPath(606, 233, 160, 104, 16, 0.4), { w: 0.8, op: 0.55, step: 0 });
    [[545, 200, 55, 36], [655, 190, 60, 38], [610, 262, 66, 30], [520, 268, 42, 26], [705, 262, 44, 26], [600, 170, 50, 30]].forEach(([x, y, rx, ry]) => pen.cloud(x, y, rx, ry, { n: 9, w: 0.8, op: 0.75, bump: 0.35 }));
    const hg = pen.group({ 'clip-path': 'url(#hero-canopy)' });
    pen.hatch(560, 240, 220, 110, 7, { w: 0.6, op: 0.75 }, hg);
    pen.poly([[598, 452], [602, 400], [600, 352], [594, 322]], { w: 1.8 });
    pen.poly([[622, 452], [618, 402], [621, 354], [628, 324]], { w: 1.8 });
    pen.poly([[602, 350], [570, 312], [548, 290]], { w: 1.2 });
    pen.poly([[618, 346], [648, 310], [676, 292]], { w: 1.2 });
    for (let y = 360; y < 448; y += 11) pen.line(606 + pen.J(4), y, 608 + pen.J(4), y + 8, { w: 0.6, over: 0, step: 0.001 });
    pen.wash(pen.fillPoly([[598, 452], [602, 360], [620, 360], [622, 452]], 2), W.ochreDeep, { op: 0.55 });
    [[548, 450], [666, 450]].forEach(([x, y]) => pen.rect(x - 14, y - 10, 28, 6, { w: 1 }));

    // Lamps.
    [[520, 452], [700, 452], [150, 452]].forEach(([x, y]) => {
      pen.line(x, y, x, 386, { w: 1.3 });
      pen.poly([[x - 6, 386], [x + 6, 386], [x + 4, 376], [x - 4, 376], [x - 6, 386]], { w: 1 });
      pen.node('path', { d: pen.blob(x, 381, 16, 14, 8), class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.8, filter: 'url(#bleed)' });
    });

    // Figures in the square.
    [[470, 452, W.teal], [500, 452, W.rust], [560, 452, W.sage], [672, 452, W.teal], [236, 452, W.rust], [420, 452, W.ochreDeep]].forEach(([x, y, c]) => figure(pen, x, y, c, 1));

    // Tram on the boulevard, cream with a red stripe.
    const tram = [[716, 400], [1150, 400], [1150, 492], [706, 492], [698, 468], [701, 422], [716, 400]];
    paperFill(pen, pen.wl(tram, 0) + 'Z');
    pen.wash(pen.fillPoly(tram, 3), W.cream, { op: 0.75, wd: 0.55 });
    pen.wash(pen.fillPoly([[700, 456], [1150, 456], [1150, 474], [699, 474]], 2), W.tram, { op: 0.85, wd: 0.65 });
    pen.wash(pen.fillPoly([[704, 482], [1150, 482], [1150, 492], [706, 492]], 2), W.tram, { op: 0.7, wd: 0.7 });
    pen.poly(tram, { w: 2, double: true });
    pen.line(700, 456, 1150, 456, { w: 1 });
    pen.line(699, 474, 1150, 474, { w: 1 });
    for (let i = 0; i < 8; i++) {
      const x = 726 + i * 52;
      pen.node('path', { d: pen.wl([[x, 412], [x + 40, 412], [x + 40, 446], [x, 446]], 0) + 'Z', class: 'wash glow', fill: W.ochre, 'fill-opacity': 0.9, filter: 'url(#bleed)' });
      pen.rect(x, 412, 40, 34, { w: 1.2 });
      if (i % 2 === 0) pen.cloud(x + 20, 434, 6, 7, { n: 6, w: 0.8, bump: 0.2 });
    }
    [836, 1044].forEach((x) => { pen.line(x, 404, x, 490, { w: 1 }); pen.line(x + 6, 404, x + 6, 490, { w: 0.7 }); });
    [760, 800, 1060, 1100].forEach((x) => pen.poly(bez([x - 12, 494], [x - 10, 504], [x + 10, 504], [x + 12, 494], 5), { w: 1.2 }));

    // Labels (hidden on phones, where the list below replaces them).
    const lab = pen.group({ class: 'labels' });
    const label = (x, y, t, ax, ay, bx, by, rust) => {
      pen.text(x, y, t, rust ? 'lbl rust' : 'lbl', lab);
      const g = pen.group({ class: 'lbl-arrow' }, lab);
      pen.poly([[ax, ay], [(ax + bx) / 2 + 14, (ay + by) / 2], [bx, by]], { w: 1.1, color: 'var(--rust-deep)' }, g);
      const ang = Math.atan2(by - (ay + by) / 2, bx - ((ax + bx) / 2 + 14));
      [0.5, -0.5].forEach((o) => pen.line(bx, by, bx - Math.cos(ang + o) * 10, by - Math.sin(ang + o) * 10, { w: 1.1, color: 'var(--rust-deep)', over: 0 }, g));
    };
    label(12, 40, 'North bridge', 60, 50, 70, 300);
    label(210, 40, 'Workshop: three sawtooth bays', 300, 52, 318, 248);
    label(560, 40, 'Tree Square: one shade tree', 640, 52, 650, 128);
    label(880, 40, 'Library: rounded roof', 960, 52, 950, 250);
    pen.text(12, 552, 'River, west edge', 'lbl', lab);
    pen.text(880, 552, 'Tram boulevard: two tracks', 'lbl rust', lab);

    // Phone legend and itinerary.
    A.district.forEach((d) => { $('.hero-key').append(el('li', { text: d.name })); $('#itinerary').append(el('li', { text: d.name })); });
  }

  function drawGuide(svg) {
    const pen = Pen(svg, 5);
    pen.delayStep = 0.004; pen.maxDelay = 1.1;
    pen.rect(12, 12, 576, 416, { w: 1.8, double: true });
    const groups = {};
    const g = (id) => (groups[id] = pen.group({ 'data-lm': id }));

    // Roads.
    [[120, 20, 120, 420], [140, 20, 140, 420], [548, 20, 548, 420], [566, 20, 566, 420]].forEach(([a, b, c, d]) => pen.line(a, b, c, d, { w: 0.8, op: 0.7, over: 0 }));
    [[140, 92, 548], [140, 104, 548], [140, 168, 548], [140, 180, 548], [140, 356, 548]].forEach(([a, y, c]) => pen.line(a, y, c, y, { w: 0.8, op: 0.7, over: 0 }));
    // Downtown blocks with stepped towers.
    [[150, 235], [250, 335], [350, 435], [450, 538]].forEach(([a, b], i) => {
      pen.wash(pen.fillPoly([[a, 114], [b, 114], [b, 160], [a, 160]], 2), i % 2 ? W.brick : W.grey, { op: 0.35 });
      pen.rect(a, 114, b - a, 46, { w: 1 });
      if (i > 0) pen.rect(a + 18, 122, b - a - 36, 30, { w: 0.8 });
      if (i > 0) pen.cloud((a + b) / 2, 137, 10, 7, { n: 6, w: 0.7 });
    });
    pen.text(300, 88, 'Downtown', 'lbl', null, { 'font-size': 20 });
    // South blocks.
    [[150, 232], [246, 330], [346, 440], [456, 540]].forEach(([a, b], i) => {
      pen.wash(pen.fillPoly([[a, 366], [b, 366], [b, 412], [a, 412]], 2), i % 2 ? W.grey : W.brick, { op: 0.3 });
      pen.rect(a, 366, b - a, 46, { w: 1 });
    });
    // Street trees.
    for (let x = 156; x < 540; x += 24) { pen.cloud(x, 186, 6, 5, { n: 6, w: 0.7, bump: 0.3 }); pen.cloud(x + 10, 298, 6, 5, { n: 6, w: 0.7, bump: 0.3 }); }
    pen.wash(pen.fillPoly([[150, 180], [540, 180], [540, 192], [150, 192]], 2), W.sage, { op: 0.4 });
    pen.wash(pen.fillPoly([[156, 292], [546, 292], [546, 304], [156, 304]], 2), W.sage, { op: 0.4 });

    // R1 River.
    const r = g('R1');
    pen.wash(pen.fillPoly([[28, 20], [102, 20], [102, 420], [28, 420]], 3), W.teal, { op: 0.5, cls: 'lm-wash' }, r);
    pen.poly([[28, 16], [30, 150], [27, 300], [29, 424]], { w: 1.3 }, r);
    pen.poly([[102, 16], [100, 150], [103, 300], [101, 424]], { w: 1.3 }, r);
    for (let i = 0; i < 14; i++) { const y = 110 + i * 22, x = 40 + pen.R() * 34; pen.poly([[x, y], [x + 7, y - 3], [x + 14, y], [x + 20, y - 2]], { w: 0.7, j: 0.3 }, r); }
    // B1 North bridge.
    const b = g('B1');
    pen.wash(pen.fillPoly([[16, 66], [124, 66], [124, 80], [16, 80]], 1), W.stone, { op: 0.8, cls: 'lm-wash' }, b);
    pen.line(14, 66, 126, 66, { w: 1.5 }, b);
    pen.line(14, 80, 126, 80, { w: 1.5 }, b);
    [52, 78].forEach((x) => pen.rect(x - 3, 62, 6, 22, { w: 0.9 }, b));
    // W1 Workshop.
    const w = g('W1');
    pen.wash(pen.fillPoly([[156, 196], [260, 196], [260, 288], [156, 288]], 2), W.brick, { op: 0.6, cls: 'lm-wash' }, w);
    pen.rect(156, 196, 104, 92, { w: 1.6, double: true }, w);
    [190.7, 225.3].forEach((x) => pen.line(x, 196, x, 288, { w: 1.1, over: 0 }, w));
    [156, 190.7, 225.3].forEach((x, i) => pen.hatch(x + 2, 198, 30, 88, 6, { w: 0.55, dir: i % 2 ? -1 : 1 }, w));
    // T1 Tree Square.
    const t = g('T1');
    pen.wash(pen.fillPoly([[282, 196], [394, 196], [394, 288], [282, 288]], 2), W.ochre, { op: 0.35, cls: 'lm-wash' }, t);
    pen.rect(282, 196, 112, 92, { w: 0.9 }, t);
    pen.poly(ellipsePts(338, 242, 42, 38, 20, 1), { w: 0.9 }, t);
    const cd = pen.cloudPath(338, 240, 30, 27, 11, 0.4);
    pen.wash(cd, W.sage, { op: 0.7, cls: 'lm-wash' }, t);
    pen.stroke(cd, { w: 1.4 }, t);
    pen.cloud(332, 236, 14, 12, { n: 7, w: 0.7 }, t);
    // L1 Library.
    const l = g('L1');
    const arc = [];
    for (let i = 0; i <= 10; i++) { const a = -Math.PI / 2 + (i / 10) * Math.PI; arc.push([496 + Math.cos(a) * 46, 242 + Math.sin(a) * 46]); }
    const dshape = [[412, 196], [496, 196], ...arc, [412, 288], [412, 195]];
    pen.wash(pen.fillPoly(dshape, 2), W.grey, { op: 0.55, cls: 'lm-wash' }, l);
    pen.poly(dshape, { w: 1.6, double: true }, l);
    pen.wash(pen.fillPoly([[438, 230], [496, 230], [496, 254], [438, 254]], 1), W.sky, { op: 0.9 }, l);
    pen.rect(438, 230, 58, 24, { w: 0.8 }, l);
    for (let x = 422; x < 506; x += 12) { pen.line(x, 200, x, 226, { w: 0.5, op: 0.8, over: 0 }, l); pen.line(x, 258, x, 284, { w: 0.5, op: 0.8, over: 0 }, l); }
    // S1 Tram boulevard.
    const s = g('S1');
    pen.wash(pen.fillPoly([[140, 310], [548, 310], [548, 350], [140, 350]], 2), W.ochre, { op: 0.25, cls: 'lm-wash' }, s);
    [316, 322, 336, 342].forEach((y) => pen.line(140, y, 548, y, { w: 1, over: 0 }, s));
    for (let x = 146; x < 548; x += 12) { pen.line(x, 314, x, 324, { w: 0.5, over: 0, step: 0.001 }, s); pen.line(x + 6, 334, x + 6, 344, { w: 0.5, over: 0, step: 0.001 }, s); }
    pen.wash(pen.fillPoly([[300, 313], [376, 313], [376, 325], [300, 325]], 1), W.cream, { op: 0.95, nofilter: true }, s);
    pen.wash(pen.fillPoly([[300, 321], [376, 321], [376, 325], [300, 325]], 1), W.tram, { op: 0.9, nofilter: true }, s);
    pen.rect(300, 313, 76, 12, { w: 1.3 }, s);

    // Compass.
    pen.line(556, 76, 556, 36, { w: 1.2 });
    pen.poly([[550, 46], [556, 34], [562, 46]], { w: 1.2 });
    pen.text(551, 30, 'N', 'lbl', null, { 'font-size': 18 });

    // Pencil rings and numerals.
    const rings = { R1: [65, 220, 52, 206], B1: [70, 73, 70, 24], W1: [208, 242, 70, 60], T1: [338, 242, 70, 62], L1: [470, 242, 84, 62], S1: [344, 330, 222, 32] };
    const nums = { R1: [65, 176], B1: [140, 56], W1: [208, 242], T1: [374, 280], L1: [456, 242], S1: [256, 330] };
    const R = window.Sketch.rng(99);
    A.district.forEach((d, i) => {
      const [cx, cy, rx, ry] = rings[d.id];
      const pts = ellipsePts(cx, cy, rx, ry, 26, 1.12, 0.08, R);
      pen.node('path', { d: pen.wl(pts, 1), class: 'ring', fill: 'none', stroke: 'var(--rust)', 'stroke-width': 2.6, 'stroke-linecap': 'round', pathLength: 1 }, groups[d.id]);
      const [nx, ny] = nums[d.id];
      pen.node('circle', { cx: nx, cy: ny, r: 12, fill: PAPER, stroke: 'var(--ink)', 'stroke-width': 1.3 }, groups[d.id]);
      pen.text(nx - 5, ny + 7, String(i + 1), 'lbl rust', groups[d.id], { 'font-size': 21, 'font-weight': 700 });
    });
    return groups;
  }

  function drawVillage(svg) {
    const pen = Pen(svg, 33);
    pen.delayStep = 0.008; pen.maxDelay = 1;
    pen.wash(pen.blob(160, 120, 150, 95, 10), W.sky, { op: 0.25, edge: 8 });
    const ws = [[30, 200], [30, 120], [80, 160], [80, 120], [130, 160], [130, 120], [180, 160], [180, 200]];
    pen.wash(pen.fillPoly(ws, 3), W.brick, { op: 0.6 });
    pen.poly(ws, { w: 1.7, double: true });
    [42, 92, 142].forEach((x) => { pen.wash(pen.fillPoly([[x, 170], [x + 26, 170], [x + 26, 196], [x, 196]], 1), W.ochre, { op: 0.8 }); pen.rect(x, 170, 26, 26, { w: 1 }); });
    const cd = pen.cloudPath(240, 110, 58, 44, 11, 0.42);
    pen.wash(cd, W.sage, { op: 0.6 });
    pen.stroke(cd, { w: 1.5 });
    pen.poly([[236, 200], [238, 150]], { w: 1.6 }); pen.poly([[246, 200], [244, 150]], { w: 1.6 });
    pen.line(8, 200, 312, 200, { w: 1.4 });
    pen.line(296, 200, 296, 140, { w: 1.1 });
    pen.poly([[290, 140], [302, 140], [300, 132], [292, 132], [290, 140]], { w: 1 });
    figure(pen, 200, 200, W.rust, 0.9);
    figure(pen, 275, 200, W.teal, 0.9);
    pen.text(20, 228, 'hall · tree · lamp', 'lbl', null, { 'font-size': 20 });
  }

  function drawHatch(svg, tier) {
    svg.textContent = '';
    svg.classList.remove('bled');
    const pen = Pen(svg, 8);
    pen.delayStep = 0.002; pen.maxDelay = 0.6;
    const spacing = { low: 20, mid: 9, high: 5 }[tier];
    const ws = [[40, 190], [40, 50], [133, 110], [133, 50], [226, 110], [226, 50], [320, 110], [320, 190]];
    const defs = pen.node('defs');
    const cp = pen.node('clipPath', { id: 'hatch-clip' }, defs);
    pen.node('path', { d: `M${ws.map((p) => p.join(' ')).join(' L')}Z` }, cp);
    pen.wash(pen.fillPoly(ws, 3), W.brick, { op: tier === 'low' ? 0.45 : 0.55 });
    const hg = pen.group({ 'clip-path': 'url(#hatch-clip)' });
    pen.hatch(40, 50, 280, 140, spacing, { w: 0.6, op: 0.85 }, hg);
    if (tier === 'high') {
      pen.hatch(40, 110, 280, 80, 8, { w: 0.5, op: 0.6, dir: -1 }, hg);
      for (let y = 116; y < 188; y += 6) { const x = 44 + pen.R() * 260; pen.line(x, y, x + 10, y, { w: 0.5, over: 0 }, hg); }
    }
    [60, 153, 246].forEach((x) => {
      pen.node('path', { d: `M${x} 128 H${x + 54} V186 H${x} Z`, fill: PAPER });
      pen.wash(pen.fillPoly([[x, 128], [x + 54, 128], [x + 54, 186], [x, 186]], 1), W.ochre, { op: 0.6 });
      pen.rect(x, 128, 54, 58, { w: 1.2 });
      if (tier !== 'low') { pen.line(x + 27, 128, x + 27, 186, { w: 0.7, over: 0 }); pen.line(x, 150, x + 54, 150, { w: 0.7, over: 0 }); }
    });
    pen.poly(ws, { w: tier === 'low' ? 2.2 : 1.8, double: tier !== 'low' });
    pen.line(20, 190, 340, 190, { w: 1.3 });
    const n = svg.querySelectorAll('.ink').length;
    pen.text(24, 215, `${n} ink strokes in this sketch`, 'lbl', null, { 'font-size': 15 });
    requestAnimationFrame(() => requestAnimationFrame(() => svg.classList.add('bled')));
  }

  function swashes() {
    const colours = { ochre: ['#e1b784', 0.55], teal: ['#8fc3d6', 0.55], sage: ['#c9c68e', 0.65], rust: ['#e0a58a', 0.5] };
    document.querySelectorAll('.swash').forEach((span, i) => {
      const svg = document.createElementNS(window.Sketch.NS, 'svg');
      svg.setAttribute('viewBox', '0 0 200 60');
      svg.setAttribute('preserveAspectRatio', 'none');
      svg.setAttribute('aria-hidden', 'true');
      span.append(svg);
      const pen = Pen(svg, 40 + i);
      const [c, op] = colours[span.dataset.wash] || colours.ochre;
      pen.wash(pen.fillPoly([[4, 18], [80, 10], [196, 16], [192, 50], [100, 56], [8, 48]], 5), c, { op, edge: 5, wd: 0.1 });
    });
  }

  function paintbox() {
    content.palette.forEach((p, i) => {
      const svg = document.createElementNS(window.Sketch.NS, 'svg');
      svg.setAttribute('viewBox', '0 0 70 56');
      svg.setAttribute('aria-hidden', 'true');
      const pen = Pen(svg, 60 + i);
      const d = pen.blob(35, 28, 28, 21, 9);
      pen.wash(d, p.hex, { op: 0.9, edge: 3, wd: i * 0.08 });
      if (i === 0) pen.stroke(d, { w: 0.9, op: 0.6 });
      $('#paintbox').append(el('li', { class: 'pan' }, [svg, el('span', { class: 'nm', text: p.name }), el('code', { text: p.hex })]));
    });
  }

  drawHero($('#hero-svg'));
  const guideGroups = drawGuide($('#guide-svg'));
  drawVillage($('#doodle-village'));
  swashes();
  paintbox();

  // ---------- Landmark picker ----------
  const note = $('#lm-note');
  const buttons = [];
  function light(id, on) {
    Object.entries(guideGroups).forEach(([k, grp]) => grp.classList.toggle('lit', on && k === id));
    buttons.forEach((b) => b.setAttribute('aria-pressed', String(on && b.dataset.id === id)));
    const d = A.district.find((x) => x.id === id);
    note.textContent = on && d ? `${d.name}: ${d.note}` : '';
  }
  A.district.forEach((d, i) => {
    const b = el('button', { type: 'button', 'data-id': d.id, 'aria-pressed': 'false' }, [el('span', { class: 'num', 'aria-hidden': 'true', text: String(i + 1) }), el('span', { text: d.name })]);
    b.addEventListener('click', () => light(d.id, b.getAttribute('aria-pressed') !== 'true'));
    b.addEventListener('mouseenter', () => light(d.id, true));
    b.addEventListener('focus', () => light(d.id, true));
    buttons.push(b);
    $('#landmarks').append(el('li', {}, b));
  });

  // ---------- Hatching tiers ----------
  const hatchSvg = $('#hatch-svg');
  const tierBtns = document.querySelectorAll('[data-tier]');
  tierBtns.forEach((b) => b.addEventListener('click', () => {
    tierBtns.forEach((x) => x.setAttribute('aria-pressed', String(x === b)));
    drawHatch(hatchSvg, b.dataset.tier);
  }));
  drawHatch(hatchSvg, 'mid');

  // ---------- Dusk wash ----------
  const dusk = $('#dusk');
  dusk.addEventListener('click', () => {
    const on = dusk.getAttribute('aria-pressed') !== 'true';
    dusk.setAttribute('aria-pressed', String(on));
    $('#hero').dataset.dusk = String(on);
    dusk.textContent = on ? 'Back to daylight' : 'Wash it for dusk';
  });

  // ---------- Washes bleed in as each spread is reached ----------
  const spreads = document.querySelectorAll('.cover, .spread');
  if (reduced || !('IntersectionObserver' in window)) {
    spreads.forEach((s) => s.classList.add('bled'));
  } else {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('bled'); io.unobserve(e.target); } });
    }, { threshold: 0.08, rootMargin: '0px 0px -8% 0px' });
    spreads.forEach((s) => io.observe(s));
    requestAnimationFrame(() => requestAnimationFrame(() => document.querySelector('.cover').classList.add('bled')));
  }
})();
