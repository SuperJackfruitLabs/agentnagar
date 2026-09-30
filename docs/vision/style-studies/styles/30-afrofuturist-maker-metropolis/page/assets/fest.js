// 30 Afrofuturist maker metropolis: broadcast content, programme and visual rhythm (no audio).
(function () {
  const S = Kit.style(document.documentElement.dataset.style);
  const A = window.AGENTNAGAR;
  const el = Kit.el;
  const $ = (id) => document.getElementById(id);
  const root = document.documentElement;

  const NOTES = {
    intent: 'A dense riverfront metropolis of copper lattice towers, patterned facades and shaded civic plazas. Deep plum, copper, teal, ochre and indigo form the palette, with geometric textile patterns repeated on walls, seats and clothing. Large views should read as a skyline of patterned spires with the river and tram as clear lines; street and gathering scenes depend on canopy shade, patterned planters and the tree; close-ups keep textile pattern on the kiosk, phone and tabletop.',
    principles: [
      'Silhouette first: tall tapered, patterned spires make the skyline legible at any size.',
      'Pattern on key surfaces: geometric textile pattern on walls, seats, planters and clothing.',
      'Shade is civic architecture: tree-shaped canopies and the great tree organise the plazas.',
      'Making in plain sight: 3D printers, solar panels, brass filigree and a brass solar sphere show the maker district at work.',
      'Copper and teal hold at every device tier.'
    ],
    palette: [
      { name: 'Deep plum', hex: '#2A1F37' },
      { name: 'Copper', hex: '#8B562F' },
      { name: 'Burnt copper', hex: '#6A3613' },
      { name: 'Ochre', hex: '#B28A53' },
      { name: 'Brass gold', hex: '#EFC993' },
      { name: 'Deep teal', hex: '#13546A' },
      { name: 'Dome teal', hex: '#51A7AB' },
      { name: 'Indigo', hex: '#252D3D' }
    ],
    materials: 'Copper lattice and brass filigree, patterned tower cladding, solar panels, glass-and-lattice domes, cable-stayed bridges, woven textiles layered over low furniture, patterned planters and paving. The brief simplifies lattice and drops reflections on lower tiers, and could add metal specular and pattern density on higher ones.',
    type: 'The sheets label panels in clean white geometric capitals. This page sets display text in Unbounded, broadcast labels in Big Shoulders Display and reading text in Space Grotesk, all open-licence faces.',
    agents: 'In Living community / Conversation, City Agent A1 is a near-human figure with visibly synthetic cues: a mechanical neck with stacked gold collar rings, glowing blue ear-ring hardware, mechanical shoulders and hands, a white jacket with a geometric panel, and a translucent tablet. The review stresses that these cues are real, so "indistinguishable from residents" overstates it. They do not carry to Interfaces / Mobile, where the "Your City Agent" card shows a human portrait in a headwrap. A leaf badge is not identifiable on the figure. Residents wear headwraps, printed jackets and gold jewellery. No sheet depicts individual Guild residents.',
    tradeoffs: [
      { label: 'Map vs street', text: 'Map and top-down are clear and labelled: River West, Workshop West with solar roofs, Tree Square with star-shaped paths around one great tree, the domed Library East and Tram Boulevard South. The diagonal becomes a generic glass skyline with the maker district reduced to the foreground. Street holds the tree, the canopies and the library dome well.' },
      { label: 'Device and production cost', text: 'The brief proposes keeping tower silhouettes, the copper-and-teal palette and geometric pattern on key surfaces at every tier. Lower tiers would simplify lattice detail and drop reflections; higher tiers could add metal specular and pattern density. A specific creative partnership and regional reference are a precondition for any production use.' },
      { label: 'Realism drift', text: 'The brief calls this the strongest realism drift of the set: characters and lighting are near photographic. That moves the study away from a stylised look and makes the sheets a weaker guide to what a stylised pipeline would produce.' },
      { label: 'UI legibility', text: 'Kiosk (Browse, Book, Ask) and phone are readable, and pattern stays on the kiosk frame. But 03 has a concrete colour conflict: the phone uses purple for tools, while the AR legend uses orange for Makerspaces and purple for Transit.' },
      { label: 'Continuity', text: '00 has a distinct tree-square layout; 03 turns into intertwined waterways and elevated routes, so the atlas arrangement is lost. Agent identity does not carry from conversation to phone. Corrections to 30 are still listed as pending.' }
    ]
  };

  const FEEDS = [
    'Map and top-down: River West with boats, Workshop West with solar roofs and a domed sphere, Tree Square with star-shaped paths, the domed Library East, Tram Boulevard South with trams; a bridge crosses at the north. Diagonal turns into a glass skyline. Street: the great tree between Workshop West and Library East, with patterned planters and a tram stop.',
    'Workshop with a brass solar sphere and a 3D printer; Home with layered textiles and a river skyline; Conversation between a resident and the near-human agent with gold collar and glowing ear ring; Gathering under tree-shaped canopies by the river.',
    'Build mode with a cyan wireframe block and colour-coded axes; Transit inside a tram with patterned seats; Night and rain under a lit patterned canopy; Waterfront park with patterned benches and a cable-stayed bridge.',
    'Facility kiosk with Browse, Book and Ask; Mobile map with the "Your City Agent" card; Rooftop at dusk over the river; AR tabletop with a colour legend, where the district becomes intertwined waterways.'
  ];

  // Stage art and rhythm bars
  $('stageArt').innerHTML = Art30.skyline();
  const eq = $('eq');
  for (let i = 0; i < 24; i++) eq.append(el('i', { style: `animation-delay: calc(var(--beat) * ${((i * 7) % 8) / 4})` }));

  // Ticker (decorative duplicate of facts present elsewhere on the page)
  const tickerItems = [`${S.name}`, 'Seven sets · one district', ...NOTES.palette.map((p) => `${p.name} ${p.hex}`), 'Concept studies, not game captures', 'Visual rhythm only · no sound'];
  const ticker = $('ticker');
  [...tickerItems, ...tickerItems].forEach((t) => ticker.append(el('span', { text: t })));

  // Rhythm controls
  const beatBtn = $('beatBtn');
  const setPlaying = (on) => {
    root.classList.toggle('paused', !on);
    beatBtn.setAttribute('aria-pressed', String(on));
    beatBtn.textContent = on ? 'Pause rhythm' : 'Play rhythm';
  };
  setPlaying(!Kit.reducedMotion());
  beatBtn.addEventListener('click', () => setPlaying(beatBtn.getAttribute('aria-pressed') !== 'true'));
  const bpm = $('bpm');
  bpm.addEventListener('input', () => {
    $('bpmOut').textContent = bpm.value;
    root.style.setProperty('--beat', `${(60 / Number(bpm.value)).toFixed(3)}s`);
  });

  // Set 01: project
  const facts = el('div', { class: 'facts' }, A.facts.map((f) => el('div', { class: 'fact' }, [el('b', { text: f.label }), f.text])));
  $('projectBody').append(
    el('div', { class: 'kit-project' }, [el('p', { class: 'kit-tagline', text: A.tagline })]),
    ...A.summary.map((t) => el('p', { text: t })),
    facts,
    el('p', { class: 'kit-small', text: `${A.status} ${A.nameNote}` })
  );

  // Set 02: style
  $('styleBody').append(
    el('p', { class: 'lede', text: NOTES.intent }),
    el('div', { class: 'cols' }, [
      el('div', {}, [el('h3', { text: 'Principles' }), el('ol', { class: 'principles' }, NOTES.principles.map((p, i) => el('li', { 'data-n': String(i + 1) }, el('span', { text: p }))))]),
      el('div', {}, [
        el('h3', { text: 'Materials and texture' }), el('p', { text: NOTES.materials }),
        el('h3', { text: 'Typography' }), el('p', { text: NOTES.type })
      ])
    ]),
    el('h3', { text: 'Palette' }),
    el('ul', { class: 'palette', 'aria-label': 'Palette sampled from the selected sheets' }, NOTES.palette.map((p) => {
      const light = ['#EFC993', '#B28A53', '#51A7AB'].includes(p.hex);
      return el('li', { style: `background:${p.hex};color:${light ? '#1b1426' : '#f4ebdd'}` }, [el('b', { text: p.name }), el('code', { text: p.hex })]);
    })),
    el('p', { class: 'small', text: 'Hex values sampled from the four selected sheets.' })
  );

  // Set 03: views
  const feeds = el('div', { class: 'feeds' });
  S.sheets.forEach((sheet, i) => {
    feeds.append(el('figure', { class: 'feed' }, [
      el('a', { class: 'screen', href: Kit.href(sheet.image), 'aria-label': `Open the ${sheet.title} sheet full size` }, [
        Kit.sheetImg(S, i, null, { alt: `${S.name} concept study: ${sheet.title} (${sheet.revision}). ${FEEDS[i]}` }),
        el('span', { class: 'tag', 'aria-hidden': 'true' }, [el('span', { text: `Feed ${i + 1}` }), el('span', { text: sheet.title })])
      ]),
      el('figcaption', {}, [el('b', { text: `${sheet.title} · ${sheet.revision} · concept study. ` }), `${Kit.PANEL_NAMES[i].join(', ')}. ${FEEDS[i]}`])
    ]));
  });
  $('viewsBody').append(
    el('p', { class: 'concept', text: A.conceptNote }),
    el('h3', { text: 'Reference landmarks' }),
    el('ul', { class: 'lm' }, A.district.map((d) => el('li', {}, [el('b', { text: d.name }), d.note]))),
    feeds
  );

  // Set 04: agents
  const a1 = el('div', { class: 'a1' });
  a1.innerHTML = Art30.a1;
  $('agentsBody').append(
    el('div', { class: 'agent-grid' }, [
      el('div', {}, [a1, el('p', { class: 'small', text: 'Illustrative drawing for this page, based on the Conversation panel; not a concept sheet.' })]),
      el('div', {}, [
        el('h3', { text: 'City Agent A1' }),
        el('p', { text: NOTES.agents }),
        el('p', { class: 'small', text: A.agentA1 }),
        el('div', { class: 'crops' }, [
          el('figure', {}, [Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): a resident talks with a near-human agent who has a gold collar and a glowing blue ear ring.` }), el('figcaption', { text: 'Conversation: synthetic cues are visible.' })]),
          el('figure', {}, [Kit.sheetImg(S, 3, 'tr', { alt: `${S.name} concept study, Interfaces perspectives, Mobile panel (${S.sheets[3].revision}): a phone map of the riverfront with a "Your City Agent" card showing a human portrait.` }), el('figcaption', { text: 'Mobile: the agent card shows a human portrait.' })])
        ])
      ])
    ]),
    el('h3', { text: 'The Guild line-up' }),
    el('p', { text: `Fourteen proposed residents. ${A.guildNote} None are drawn in these sheets.` }),
    el('ul', { class: 'lineup' }, A.guild.map((g) => el('li', {}, [el('b', { text: g.name }), el('span', { text: g.role })])))
  );

  // Set 05: trade-offs
  $('tradeBody').append(el('dl', { class: 'trade' }, NOTES.tradeoffs.map((t) => el('div', {}, [el('dt', { text: t.label }), el('dd', { text: t.text })]))));

  // Set 06: status
  const status = Kit.statusBlock(S);
  status.removeAttribute('data-core');
  $('set-status').dataset.core = 'status';
  $('statusBody').append(el('p', { class: 'small', text: 'Review summary, verbatim from the manifest:' }), status);

  // Set 07: nav
  const navHost = $('navBody');
  Kit.mountNav(navHost, S);
  $('footNote').textContent = `${A.conceptNote} Skyline, pattern and A1 drawing are illustrative art for this page.`;

  // Notes
  Kit.notesDialog(S, NOTES, $('notesBtn'));

  // Programme with a "now" marker
  const sets = [...document.querySelectorAll('.set')];
  const list = $('progList');
  const links = sets.map((s, i) => {
    const a = el('a', { href: `#${s.id}` }, [el('span', { class: 'p-no', text: `Set 0${i + 1}` }), el('span', { class: 'p-name', text: s.querySelector('h2').textContent })]);
    list.append(el('li', {}, a));
    return a;
  });
  if ('IntersectionObserver' in window) {
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (!e.isIntersecting) return;
        const idx = sets.indexOf(e.target);
        links.forEach((l, i) => (i === idx ? l.setAttribute('aria-current', 'true') : l.removeAttribute('aria-current')));
      });
    }, { rootMargin: '-45% 0px -50% 0px' });
    sets.forEach((s) => io.observe(s));
  }
})();
