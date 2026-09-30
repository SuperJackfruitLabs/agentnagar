(function () {
  'use strict';
  const K = window.Kit;
  const A = window.AGENTNAGAR;
  const S = K.style(document.documentElement.dataset.style);
  const $ = (sel, root) => (root || document).querySelector(sel);
  const $$ = (sel, root) => Array.from((root || document).querySelectorAll(sel));
  const el = K.el;
  const ROMAN = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

  $$('[data-num]').forEach((n) => { n.textContent = S.number; });

  // ---- Page content (also feeds the notes dialog) ----
  const palette = [
    { ref: 'M-01', name: 'Fired brick', hex: '#80564a', where: 'Workshop sawtooth walls, street and night views' },
    { ref: 'M-02', name: 'Brick in plan', hex: '#b18372', where: 'Workshop roof on the Map and Top-down panels' },
    { ref: 'M-03', name: 'Zinc vault', hex: '#9b9fab', where: 'Library barrel roof, standing seam' },
    { ref: 'M-04', name: 'Limestone paving', hex: '#e8e4da', where: 'Tree Square and boulevard paving' },
    { ref: 'M-05', name: 'River water', hex: '#4787b1', where: 'West river, bridge and waterfront' },
    { ref: 'M-06', name: 'Canopy green', hex: '#5d632f', where: 'Shade tree and street trees' },
    { ref: 'M-07', name: 'Daylight sky', hex: '#a6cdf6', where: 'Street, gathering and park skies' },
    { ref: 'M-08', name: 'Olive field jacket', hex: '#574c36', where: 'City Agent A1 in every close view' },
    { ref: 'M-09', name: 'Interface navy', hex: '#2c4155', where: 'Ask button on the phone and kiosk' }
  ];
  const principles = $$('.principles li').map((li) => li.textContent.trim());
  const tradeoffs = [
    { label: 'Map scale', text: 'Realism does not survive at the map. The brief itself says map views still require abstraction, and the selected overview still carries shaded tree and roof glyphs and an elevation-drawn bridge rather than flat cartography; the Top-down panel keeps some facade perspective. A production map would be a separate, drawn layer.' },
    { label: 'Street scale', text: 'This is the style\'s strongest scale. Brick, zinc, glass and planting make the Workshop, Tree Square and Library instantly distinct in the Street, Gathering and Night-and-rain panels, and the district reads as a real, occupied place.' },
    { label: 'Device and production cost', text: 'The most expensive of the studies to build and to run. The proposed adaptation keeps building scale, layout and material categories on every device while varying texture resolution, reflections, shadows, decorative density and distant geometry; mobile and browser would emphasise exploration with reduced detail. The brief asks for a representative playable scene to establish achievable fidelity and latency before this direction could be chosen.' },
    { label: 'Characters', text: 'The sheets set an atmosphere, not a target for facial animation or material accuracy. Photoreal faces and hands are where real-time realism most often breaks, and agent identity rests on a small badge.' },
    { label: 'UI legibility', text: 'In the sheets, the kiosk, phone and AR legend work because they are flat, high-contrast cards laid over busy photographic scenes. Any in-world UI needs solid panels; text directly over the imagery would not hold. The phone view\'s A1 badge is tiny and sits beside the portrait.' },
    { label: 'Review residuals', text: 'From the repair record: the overview map lost its Workshop and Library category pins (labels remain; phone and AR restore all four categories); later corrections reduced the street, gathering and night Workshop to three peaks; the Home view\'s bridge is hidden by foliage; margins and captions were not measured. No accessibility or performance claim is made.' }
  ];
  const agentsText = 'City Agent A1 appears as a human-presenting woman with her hair in a bun, an olive field jacket, a lanyard and a white badge with a green leaf reading "A1 · City Agent A1". The same identity carries into the rooftop, the library kiosk and the phone card. Guild residents are not depicted in these sheets; the people shown are unnamed residents.';
  const notesContent = {
    intent: $('.intent .lede').textContent + ' ' + $('.intent p:nth-child(2)').textContent,
    principles,
    palette: palette.map((p) => ({ name: p.name, hex: p.hex })),
    materials: 'Fired brick, board-marked concrete, oiled timber, zinc standing seam, glazing and powder-coated steel, with subtle everyday wear.',
    type: 'Cormorant Garamond titles, EB Garamond text, Inter labels; the sheets use a plain humanist sans for signage and UI.',
    agents: agentsText,
    tradeoffs
  };

  // ---- Register (contents) ----
  const register = $('#register');
  const regItems = [
    ['plate-1', 'I', 'The brief'], ['plate-2', 'II', 'Design statement'], ['plate-3', 'III', 'South elevation'],
    ...S.sheets.map((sh, i) => [`plate-${4 + i}`, ROMAN[3 + i], sh.title]),
    ['plate-8', 'VIII', 'Occupants'], ['plate-9', 'IX', 'Appraisal'], ['plate-10', 'X', 'Revision schedule'], ['colophon', '', 'Colophon and other studies']
  ];
  regItems.forEach(([id, no, title]) => register.append(el('li', {}, el('a', { href: `#${id}` }, [el('span', { class: 'r-no', text: no || '·' }), el('span', { class: 'r-t', text: title })]))));

  // ---- Plate I: project ----
  const project = K.projectBlock();
  project.removeAttribute('data-core');
  $('#project-slot').append(project);

  // ---- Plate II: palette schedule ----
  const tbody = $('#palette-table tbody');
  palette.forEach((p) => tbody.append(el('tr', {}, [
    el('td', { class: 'mono', text: p.ref }),
    el('td', {}, el('span', { class: 'chip', style: `background:${p.hex}`, role: 'img', 'aria-label': `${p.name} sample` })),
    el('td', { text: p.name }),
    el('td', { class: 'muted', text: p.where }),
    el('td', { class: 'mono', text: p.hex })
  ])));

  // ---- Plate III: landmark key ----
  const keyList = $('#key-list');
  const keyItems = A.district.map((d) => ({ id: d.id, name: d.name, note: d.note }));
  keyItems.push({ id: 'towers', name: 'Stepped towers', note: 'Three planted residential towers north of the square, recurring in every overview.' });
  let pinned = null;
  function highlight(id) {
    document.body.classList.toggle('keyed', !!id);
    $$('[data-key]').forEach((n) => n.classList.toggle('on', n.dataset.key === id));
    $$('#key-list button').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.id === pinned)));
  }
  keyItems.forEach((k) => {
    const b = el('button', { type: 'button', 'data-id': k.id, 'aria-pressed': 'false' }, [
      el('span', { class: 'kt', text: k.id === 'towers' ? '—' : k.id }), el('span', { class: 'kn' }, [el('b', { text: k.name }), el('span', { text: k.note })])
    ]);
    b.addEventListener('click', () => { pinned = pinned === k.id ? null : k.id; highlight(pinned); });
    b.addEventListener('mouseenter', () => highlight(k.id));
    b.addEventListener('mouseleave', () => highlight(pinned));
    b.addEventListener('focus', () => highlight(k.id));
    b.addEventListener('blur', () => highlight(pinned));
    keyList.append(el('li', {}, b));
  });

  // ---- Plates IV–VII: the four sheets ----
  const notesBySheet = [
    [
      'Cartographic plan: River R1 west, North bridge B1, Workshop W1, Tree Square T1, Library L1, waterfront park and the tram stop on S1.',
      'Orthographic roofscape: the three sawtooth bays, the living tree, the zinc vault and a tram on the boulevard.',
      'Aerial from the south-west: bridge arches, three planted towers, Workshop, square and Library in a row.',
      'Eye level on the tram boulevard: the tram with its stripe in front of Workshop, tree and Library.'
    ],
    [
      'Inside the Workshop: pegboards, bench vices, task lamps and clerestory glazing; residents at work.',
      'A riverside home with personal possessions and a dog; the Workshop\'s sawtooth seen through the window.',
      'City Agent A1 (leaf badge) in conversation with a resident on Tree Square, Workshop behind.',
      'Tree Square as a gathering place between Workshop and Library, towers beyond.'
    ],
    [
      'Build mode: the Workshop selected with red X, green Y and blue Z axes; river, bridge, Library, tram.',
      'From inside the tram: "Next stop Riverside Square", with Workshop, tree and Library through the glass.',
      'Night and rain: wet paving reflects the lit Workshop, tree lights and Library glazing; tram at the stop.',
      'Waterfront park along the river, the North bridge upstream and the Workshop behind the planting.'
    ],
    [
      'Library facility: a touchscreen kiosk with Browse, Book and Ask; signage names a public library and maker space.',
      'Phone: map with Workshop selected, City Agent A1 card, "Ask about availability" and an Ask button.',
      'Rooftop over the river and bridge toward the Workshop, A1 and a resident at a table.',
      'AR tabletop model: Workshop selected, a four-category legend and an "External viewer" label.'
    ]
  ];
  const views = $('#views');
  $('#concept-note').textContent = A.conceptNote;
  S.sheets.forEach((sheet, i) => {
    const plateNo = ROMAN[3 + i];
    const img = K.sheetImg(S, i, null, {
      alt: `${S.name} concept study, ${sheet.title} (${sheet.revision}): four panels, ${K.PANEL_NAMES[i].join(', ')}. ${notesBySheet[i].join(' ')}`
    });
    const frame = el('a', { class: 'sheet-frame', href: K.href(sheet.image), title: 'Open the full-resolution sheet' }, [img, el('div', { class: 'loupe', 'aria-hidden': 'true' })]);
    const legend = el('ol', { class: 'panel-notes' }, K.PANEL_NAMES[i].map((name, j) => el('li', {}, [
      el('span', { class: 'label', text: `${String.fromCharCode(97 + j)} · ${name}` }), el('p', { text: notesBySheet[i][j] })
    ])));
    const section = el('section', { class: 'plate sheet-plate', id: `plate-${4 + i}`, 'data-plate': plateNo, 'data-title': sheet.title, 'data-rev': sheet.revision, 'aria-labelledby': `h-${4 + i}` }, [
      el('header', { class: 'plate-head' }, [
        el('span', { class: 'pl-no', text: `Pl. ${plateNo}` }),
        el('h2', { id: `h-${4 + i}`, text: sheet.title }),
        el('span', { class: 'pl-meta' }, [`Concept study · rev `, el('a', { href: K.href(sheet.image), text: sheet.revision }), ' · ', el('a', { href: K.href(sheet.review), text: 'review' })])
      ]),
      el('div', { class: 'plate-body sheet-body' }, [
        el('figure', { class: 'sheet-fig' }, [frame, el('figcaption', { class: 'small', text: `${sheet.title}, ${sheet.revision}. ${A.conceptNote}` })]),
        legend
      ])
    ]);
    views.append(section);
    attachLoupe(frame, img);
  });

  function attachLoupe(frame, img) {
    if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return;
    const loupe = $('.loupe', frame);
    const Z = 2.6;
    frame.addEventListener('pointermove', (e) => {
      const r = img.getBoundingClientRect();
      const x = e.clientX - r.left; const y = e.clientY - r.top;
      if (x < 0 || y < 0 || x > r.width || y > r.height) { loupe.hidden = true; return; }
      loupe.hidden = false;
      loupe.style.backgroundImage = `url("${img.currentSrc || img.src}")`;
      loupe.style.backgroundSize = `${r.width * Z}px ${r.height * Z}px`;
      loupe.style.backgroundPosition = `${-(x * Z - 90)}px ${-(y * Z - 90)}px`;
      loupe.style.transform = `translate(${x - 90}px, ${y - 90}px)`;
    });
    frame.addEventListener('pointerleave', () => { loupe.hidden = true; });
    loupe.hidden = true;
    frame.classList.add('has-loupe');
  }

  // ---- Plate VIII: agents ----
  $('#a1-shared').textContent = A.agentA1;
  $('#guild-note').textContent = A.guildNote;
  const guildRows = $('#guild-rows');
  A.guild.forEach((g, i) => guildRows.append(el('tr', {}, [
    el('td', { class: 'mono', text: `G-${String(i + 1).padStart(2, '0')}` }), el('td', { text: g.name }), el('td', { class: 'muted', text: g.role })
  ])));
  // Portrait crop of A1 from the Living community sheet, conversation panel.
  (function portrait() {
    const sheet = S.sheets[1];
    const [x, y, w, h] = [16, 530, 410, 440];
    const box = el('div', { class: 'crop', role: 'img', 'aria-label': `City Agent A1 in the ${S.name} concept study, ${sheet.title} ${sheet.revision}, Conversation panel: a bun-haired woman in an olive jacket with a leaf "A1 City Agent A1" badge, mid-gesture.` });
    const img = el('img', { src: K.href(sheet.image), alt: '', loading: 'lazy', decoding: 'async' });
    Object.assign(box.style, { aspectRatio: `${w} / ${h}` });
    Object.assign(img.style, { width: `${(1536 / w) * 100}%`, left: `${(-x / w) * 100}%`, top: `${(-y / h) * 100}%` });
    box.append(img);
    $('#a1-portrait').append(box);
  })();

  // ---- Plate IX: appraisal ----
  const ap = $('#appraisal');
  tradeoffs.forEach((t, i) => ap.append(el('div', { class: 'ap-row' }, [el('dt', {}, [el('span', { class: 'mono', text: `A.${i + 1}` }), ' ', t.label]), el('dd', { text: t.text })])));

  // ---- Plate X: status, nav ----
  $('#status-slot').append(K.statusBlock(S));
  K.mountNav($('#nav-slot'), S);
  K.notesDialog(S, notesContent, $('#open-notes'));

  // ---- Title block scroll spy ----
  const tbTitle = $('#tb-title'); const tbPlate = $('#tb-plate');
  const plates = $$('.plate');
  const io = new IntersectionObserver((entries) => {
    entries.forEach((en) => {
      if (!en.isIntersecting) return;
      const p = en.target;
      tbPlate.textContent = p.dataset.plate;
      tbTitle.textContent = p.dataset.rev ? `${p.dataset.title} · ${p.dataset.rev}` : p.dataset.title;
    });
  }, { rootMargin: '-45% 0px -50% 0px' });
  plates.forEach((p) => io.observe(p));

  // ---- Draw-in of line drawings ----
  const drawings = $$('svg.drawing');
  if (K.reducedMotion() || !('IntersectionObserver' in window)) {
    drawings.forEach((d) => d.classList.add('drawn'));
  } else {
    document.documentElement.classList.add('will-draw');
    const dio = new IntersectionObserver((entries) => entries.forEach((en) => {
      if (en.isIntersecting) { en.target.classList.add('drawn'); dio.unobserve(en.target); }
    }), { threshold: 0.2 });
    drawings.forEach((d) => {
      $$('.ln', d).forEach((p, i) => p.style.setProperty('--d', `${Math.min(i * 30, 900)}ms`));
      dio.observe(d);
    });
  }
})();
