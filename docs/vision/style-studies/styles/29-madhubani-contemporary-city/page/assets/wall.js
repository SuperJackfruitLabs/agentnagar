// 29 Madhubani-inspired contemporary city: story-panel content and interactions.
(function () {
  document.documentElement.classList.add('js');
  const S = Kit.style(document.documentElement.dataset.style);
  const A = window.AGENTNAGAR;
  const el = Kit.el;
  const $ = (id) => document.getElementById(id);

  const NOTES = {
    intent: 'A riverfront city rendered in dense hand-drawn pattern: flat colour, double-line borders, hatching, and fish, bird, lotus and tree motifs. Large views let colour blocks and the river separate districts before pattern is added. Street and gathering scenes hold a plain ground so figures stand out. Close-ups, including kiosk and phone, keep the line grammar while leaving interface panels plain.',
    principles: [
      'Double line, then fill: every shape is closed by a double outline before colour or pattern goes in.',
      'Colour blocks before pattern: vermilion roofs, cream ground, leaf green and the cobalt river separate districts at map scale.',
      'Motif carries meaning: fish for the river, lotus for the library, the tree for the square.',
      'A plain ground for people: figures and interface panels stand on quiet cream so they stay legible.',
      'Borders frame the story: each scene sits inside a patterned border band.'
    ],
    palette: [
      { name: 'Deep vermilion', hex: '#8D2F21' },
      { name: 'Vermilion', hex: '#AF3726' },
      { name: 'Black ink', hex: '#11100F' },
      { name: 'Cream ground', hex: '#E8CEB1' },
      { name: 'Paper white', hex: '#F6F4EC' },
      { name: 'Leaf green', hex: '#4F7547' },
      { name: 'Cobalt river', hex: '#1A6482' },
      { name: 'Turmeric', hex: '#D38A50' }
    ],
    materials: 'Black ink line on a cream ground; flat colour blocks; fill hatching; fish, bird, lotus and tree motifs on facades, paving and tram sides; red-roofed blocks with arched openings; patterned sofas, framed fish and bird panels and tiled floors indoors. The brief reduces hatching to flat colour on lower device tiers and allows full motif density on facades at higher tiers.',
    type: 'The sheets hand-letter district names onto the map and panel names in bold capitals. This page pairs Kalam, an open-licence handwritten face, for headings with Nunito for body text, so reading text stays plain while headings keep a drawn line.',
    agents: 'City Agent A1 appears in Living community / Conversation as a white robot drawn in profile with the same large outlined eye as the residents, round ear discs, red botanical motifs on its arms and body, and a tablet with a leaf design. The leaf badge itself is not singled out on the figure. In Interfaces / Mobile the "Your City Agent" card shows a human woman\'s portrait instead; the review lists this style among those where the robot and the phone portrait are not clearly the same agent. Residents are drawn in profile with large outlined eyes and patterned saris and kurtas. No sheet depicts individual Guild residents.',
    tradeoffs: [
      { label: 'Map vs street', text: 'The map is the strongest view: district names are drawn onto it (Bridge North, River West, Workshop West, Tree Square, Library East with its lotus roundel, Tram Boulevard South) and colour blocks separate them. At street and interior scale, pattern covers floors, clothing and furniture at once, which lowers figure legibility.' },
      { label: 'Device and production cost', text: 'The brief proposes keeping the black contour, the red-cream-black palette and the border grammar at every tier. Lower tiers would reduce fill hatching to flat colour; higher tiers could add full motif density on facades. Collaboration with artists knowledgeable in the Mithila tradition is a precondition for any production treatment.' },
      { label: 'UI legibility', text: 'Where the sheets follow the brief, interfaces are clear: the kiosk\'s Browse, Book and Ask and the phone\'s agent card sit on plain panels. The risk is elsewhere: the review names 29 among styles where pattern covers both subjects and backgrounds.' },
      { label: 'Review defects', text: 'Top-row labels clip on 00, and panel labels and footer are cropped on three of the four sheets. 03 / AR tabletop rearranges the district into a river-through model. 02 / Night and rain adds much smoother, reflective shading than the flatter panels. Corrections to 29 are still listed as pending.' }
    ]
  };

  const SHEETS = [
    { story: 'The district as a drawn map', text: 'Map and top-down label the district in hand lettering: River West with fish and lotus, Bridge North, Workshop West with red sawtooth halls, Tree Square around one great tree, Library East with a lotus roundel, and Tram Boulevard South. Diagonal keeps the layout; Street looks across the square past the tree to a red tram and the Library East sign. Top-row labels clip.' },
    { story: 'Living together', text: 'Workshop with people painting fish and bird panels; Home with a patterned sofa and a river view; Conversation between a resident and the robot agent drawn in profile; Gathering with dance and drums under patterned canopies by the river.' },
    { story: 'Making and moving', text: 'Build mode with a red wireframe block and colour-coded axes on a rooftop; Transit inside a patterned tram crossing the river bridge; Night and rain with lamp light, umbrellas and smoother reflective shading; Waterfront park with fish-patterned paving and a bench by the river.' },
    { story: 'Screens and tables', text: 'Facility kiosk with Browse, Book and Ask on a plain panel; Mobile map with the "Your City Agent" card; Rooftop evening over the river; AR tabletop, where the district becomes a river-through model.' }
  ];

  // Hero drawing, legend and density control
  $('cityArt').innerHTML = Art29.city();
  const city = document.querySelector('.city');
  const legend = $('legend');
  const LM = [['river', 'River'], ['bridge', 'North bridge'], ['workshop', 'Workshop'], ['tree', 'Tree Square'], ['library', 'Library'], ['tram', 'Tram boulevard']];
  const lmButtons = LM.map(([key, name]) => {
    const b = el('button', { type: 'button', 'aria-pressed': 'false', text: name });
    const show = () => city.setAttribute('data-hl', key);
    const clear = () => { if (b.getAttribute('aria-pressed') !== 'true') restore(); };
    b.addEventListener('mouseenter', show);
    b.addEventListener('focus', show);
    b.addEventListener('mouseleave', clear);
    b.addEventListener('blur', clear);
    b.addEventListener('click', () => {
      const on = b.getAttribute('aria-pressed') !== 'true';
      lmButtons.forEach((o) => o.setAttribute('aria-pressed', 'false'));
      b.setAttribute('aria-pressed', String(on));
      on ? show() : city.removeAttribute('data-hl');
    });
    legend.append(b);
    return b;
  });
  function restore() {
    const pressed = lmButtons.findIndex((o) => o.getAttribute('aria-pressed') === 'true');
    pressed >= 0 ? city.setAttribute('data-hl', LM[pressed][0]) : city.removeAttribute('data-hl');
  }
  const densityText = {
    flat: 'Flat colour: contour and colour blocks only, as the brief proposes for lower device tiers.',
    hatched: 'Hatched: fill hatching on roofs, river and ground.',
    full: 'Full motif: fish, leaves and birds on every surface, as higher tiers could allow. Notice how the people start to compete.'
  };
  document.querySelectorAll('input[name="density"]').forEach((r) => r.addEventListener('change', () => {
    document.documentElement.dataset.density = r.value;
    $('densityNote').textContent = densityText[r.value];
  }));
  if (!Kit.reducedMotion()) city.classList.add('trace');

  // Motif roundels
  document.querySelectorAll('.motif[data-motif]').forEach((m) => { m.innerHTML = Art29.motifs[m.dataset.motif]; });

  // 1 Project
  const project = Kit.projectBlock();
  project.removeAttribute('data-core');
  $('projectBody').append(project);

  // 2 Style
  $('styleBody').append(
    el('p', { class: 'lede-sm', text: NOTES.intent }),
    el('h3', { text: 'Principles' }),
    el('ol', { class: 'principles' }, NOTES.principles.map((p) => el('li', { text: p }))),
    el('h3', { text: 'Palette' }),
    el('ul', { class: 'palette', 'aria-label': 'Palette sampled from the selected sheets' }, NOTES.palette.map((p) =>
      el('li', {}, [el('span', { class: 'chip', style: `background:${p.hex}`, 'aria-hidden': 'true' }), el('b', { text: p.name }), el('code', { text: p.hex })]))),
    el('p', { class: 'tiny', text: 'Hex values sampled from the four selected sheets.' }),
    el('div', { class: 'two' }, [
      el('div', {}, [el('h3', { text: 'Materials and texture' }), el('p', { text: NOTES.materials })]),
      el('div', {}, [el('h3', { text: 'Typography' }), el('p', { text: NOTES.type })])
    ])
  );

  // 3 Views
  const grid = el('div', { class: 'views-grid' });
  S.sheets.forEach((sheet, i) => {
    const alt = `${S.name} concept study: ${sheet.title} (${sheet.revision}). ${SHEETS[i].text}`;
    grid.append(el('figure', { class: 'story' }, [
      el('a', { class: 'frame', href: Kit.href(sheet.image), 'aria-label': `Open the ${sheet.title} sheet full size` }, Kit.sheetImg(S, i, null, { alt })),
      el('figcaption', {}, [el('b', { text: `${String.fromCharCode(97 + i)}. ${SHEETS[i].story}` }), `${sheet.title} · ${sheet.revision} · concept study. ${SHEETS[i].text}`])
    ]));
  });
  $('viewsBody').append(
    el('p', { class: 'concept', text: A.conceptNote }),
    grid,
    el('div', { class: 'closer' }, [
      el('figure', { class: 'story' }, [
        Kit.sheetImg(S, 0, 'tl', { alt: `${S.name} concept study, City perspectives, Map panel (${S.sheets[0].revision}): hand-lettered labels for River West, Bridge North, Workshop West, Tree Square, Library East and Tram Boulevard South.` }),
        el('figcaption', { class: 'tiny', text: 'Closer: the Map panel, where the district names are drawn onto the city.' })
      ]),
      el('div', {}, [
        el('h3', { text: 'The six reference landmarks' }),
        el('ul', { class: 'lm-list' }, A.district.map((d) => el('li', {}, el('span', {}, [el('b', { text: d.name }), ` · ${d.note}`]))))
      ])
    ])
  );

  // 4 Agents
  const art = el('div', { class: 'agent-art' });
  art.innerHTML = Art29.a1;
  $('agentsBody').append(
    el('div', { class: 'agent-top' }, [art, el('div', {}, [
      el('h3', { text: 'City Agent A1' }),
      el('p', { text: NOTES.agents }),
      el('p', { class: 'tiny', text: 'Drawing at left: illustrative, made for this page from the Conversation panel; not a concept sheet. ' + A.agentA1 })
    ])]),
    el('div', { class: 'crops' }, [
      el('figure', {}, [Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): a resident and a white robot agent drawn in profile with red botanical motifs, the river and a bridge behind.` }), el('figcaption', { text: 'Conversation: the robot agent in profile.' })]),
      el('figure', {}, [Kit.sheetImg(S, 3, 'tr', { alt: `${S.name} concept study, Interfaces perspectives, Mobile panel (${S.sheets[3].revision}): a phone map with a "Your City Agent" card showing a human portrait.` }), el('figcaption', { text: 'Mobile: the agent card shows a human portrait.' })])
    ]),
    el('h3', { text: 'Guild residents' }),
    el('p', { text: `Fourteen proposed residents. ${A.guildNote} None are drawn in these sheets.` }),
    el('ul', { class: 'guild' }, A.guild.map((g) => el('li', {}, [el('b', { text: g.name }), g.role])))
  );

  // 5 Trade-offs
  $('tradeBody').append(el('dl', { class: 'trade' }, NOTES.tradeoffs.map((t) => el('div', {}, [el('dt', { text: t.label }), el('dd', { text: t.text })]))));

  // 6 Status
  const status = Kit.statusBlock(S);
  status.removeAttribute('data-core');
  $('p-status').dataset.core = 'status';
  $('statusBody').append(el('p', { class: 'tiny', text: 'Review summary, verbatim from the manifest:' }), status);

  // 7 Nav
  Kit.mountNav($('navBody'), S);

  // Notes dialog
  Kit.notesDialog(S, NOTES, $('notesBtn'));

  // Bands draw in as panels enter the view
  const panels = document.querySelectorAll('.panel');
  if (Kit.reducedMotion() || !('IntersectionObserver' in window)) {
    panels.forEach((p) => p.classList.add('seen'));
  } else {
    const io = new IntersectionObserver((entries) => entries.forEach((e) => { if (e.isIntersecting) { e.target.classList.add('seen'); io.unobserve(e.target); } }), { threshold: 0.12 });
    panels.forEach((p) => io.observe(p));
  }
})();
