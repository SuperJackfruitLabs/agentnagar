/* Low-poly tropical diorama: landmark cards. Revisions, images, review text and nav come from STYLE_DATA via Kit. */
(function () {
  const { el } = Kit;
  const S = Kit.style('11-low-poly-tropical-diorama');
  const A = window.AGENTNAGAR;
  document.querySelectorAll('[data-num]').forEach((n) => { n.textContent = S.number; });

  const content = {
    intent: 'A warm riverfront city presented as a faceted model set. Limewash walls, terracotta roofs, green copper domes and jackfruit-yellow awnings, trams and umbrellas sit against a teal river. The facets show most clearly in foliage, hair and props; buildings read as smooth painted volumes. Plazas, arched bridges and one large central tree organise the district, and workshops and homes are open, plant-filled rooms with wooden furniture and a river view.',
    principles: [
      'Facet the living things. Leaves, palms, hair and clothing are cut into planes; walls and roofs stay smooth and painted.',
      'One layout at every scale. Map, top-down and diagonal views share the same plan, so landmarks carry across zoom levels.',
      'Yellow is the pointer. Awnings, umbrellas, trams and the Ask button carry jackfruit yellow, so the eye lands on places to go.',
      'The central tree anchors everything. Street and park scenes frame it, and it survives every device tier.',
      'Open rooms, river light. Interiors are airy, plant-filled and wooden, with the water in view.'
    ],
    palette: [
      { name: 'Limewash cream', hex: '#f9e0ce' },
      { name: 'Terracotta roof', hex: '#c67c60' },
      { name: 'Copper-dome green', hex: '#4d837d' },
      { name: 'River teal', hex: '#1ba1b0' },
      { name: 'Jackfruit yellow', hex: '#fdd657' },
      { name: 'Canopy green', hex: '#608a3e' },
      { name: 'Panel coral', hex: '#ca683d' },
      { name: 'Panel green', hex: '#417249' }
    ],
    materials: 'Smooth limewash plaster, terracotta tile, green copper, pale stone paving and timber furniture, with faceted foliage, faceted hair and faceted fabric. Interfaces are flat green, coral and yellow panels with rounded corners and icon labels.',
    type: 'The sheets use bold condensed sans labels on dark green plaques and a light sans footer. This page uses Baloo 2 for plaques and headings and Nunito for reading. Page choices only.',
    agents: 'City Agent A1 appears as a white and yellow robot with faceted panels, a dark visor with cyan crescent eyes and yellow ear discs, and a green leaf "A1" mark on the chest. It carries a tablet in the Conversation panel, where a "City Agent A1" tag names it, and it is the helper portrait on the phone card ("Check availability", Ask). People have faceted hair and clothing but smoothly shaded faces. The Guild residents are not depicted in these sheets.',
    tradeoffs: [
      { label: 'Map vs street readability', text: 'Strong at both ends: the MAP and TOP-DOWN panels carry W1, T1, L1, P1, S1 and D1 labels on a clean plan, and street scenes anchor on the tree and yellow accents. The review found that the stone-arch bridge and bell-tower skyline of the overview turn into a cable-stayed bridge and modern towers in the original interface sheet, so landmark identity did not carry across every view. The current interface revision was corrected, but final cross-sheet proportions are still pending.' },
      { label: 'Device and production cost', text: 'The brief proposes keeping roof and awning colours, the central tree and faceted plant silhouettes at every tier. Lower tiers would flatten leaf clusters and thin crowds; higher tiers could keep the soft lighting. Flat-shaded volumes are cheap to author and to render, which is this style\'s best argument.' },
      { label: 'UI legibility', text: 'Green, coral and yellow panels with icon labels read clearly: Browse, Book and Ask on the kiosk, a Workshop W1 card with Ask on the phone, and an AR legend for Workshop, Library, Transit and Park.' },
      { label: 'Is it really low-poly?', text: 'Not quite. The review notes that faceting is strongest in foliage and people and weaker in buildings, and the brief admits the sheets drift toward painted illustration rather than a true low-poly kit. Do not infer polygon counts from the illustrations.' },
      { label: 'Sheet template', text: 'Footer captions on three sheets are clipped by the frame, and the Creating and exploring sheet uses a different label treatment from the others.' }
    ]
  };

  const SHEET_NOTES = [
    'MAP and TOP-DOWN show the River (R1) on the west with boats and docks, the stone North bridge (B1), the terracotta Workshop (W1), Tree Square (T1), the green-roofed Library (L1), downtown blocks (D1), the park (P1) and the tram boulevard (S1). DIAGONAL and STREET put the cream tram in front of the tree.',
    'A timber Workshop open to the trees, a home with a faceted green bedspread and a cat, A1 in conversation holding a tablet, and a gathering under the tree between the Workshop and the Library as the tram passes.',
    'Build mode draws a glass volume with X, Y and Z axes on the square; Transit looks out of the tram at the Workshop and tree; Night and rain lights the square with lamps and umbrellas; the Waterfront park looks back to the arched bridge.',
    'A kiosk with Browse, Book and Ask; a phone map selecting Workshop W1 with A1 and an Ask button; a rooftop above the canopy and the Workshop roofs; and an AR tabletop with Workshop, Library, Transit and Park markers.'
  ];

  // Landmark → core section.
  const LANDMARKS = [
    { key: 'tree', core: 'project', name: 'Tree Square', code: 'T1', label: 'Agentnagar', color: '#417249', icon: 'M12 3c-4 0-7 3-7 6.5 0 2.6 1.8 4.6 4.3 5.3V21h5.4v-6.2C17.2 14.1 19 12.1 19 9.5 19 6 16 3 12 3z' },
    { key: 'library', core: 'style', name: 'Library', code: 'L1', label: 'The style', color: '#2f6ea3', icon: 'M4 5c3-1 6-1 8 1 2-2 5-2 8-1v14c-3-1-6-1-8 1-2-2-5-2-8-1zM12 6v14' },
    { key: 'bridge', core: 'views', name: 'North bridge', code: 'B1', label: 'Four views', color: '#9a6a00', icon: 'M2 15h20M4 15v-3a4 4 0 0 1 4 0v3M10 15v-3a4 4 0 0 1 4 0v3M16 15v-3a4 4 0 0 1 4 0v3M2 10h20' },
    { key: 'workshop', core: 'agents', name: 'Workshop', code: 'W1', label: 'Agents', color: '#b4532a', icon: 'M14.5 6.5l3-3 3 3-3 3M17.5 6.5L7 17M4 20l3-3M6.5 4.5a3 3 0 0 0 4 4L20 18l-2 2-9.5-9.5a3 3 0 0 0-4-4z' },
    { key: 'tram', core: 'tradeoffs', name: 'Tram boulevard', code: 'S1', label: 'Trade-offs', color: '#7d4a92', icon: 'M6 4h12a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2zM4 10h16M8 21l2-4M16 21l-2-4' },
    { key: 'downtown', core: 'status', name: 'Downtown', code: 'D1', label: 'Status', color: '#2b4a41', icon: 'M4 21V9l5-3v15M9 21V4l6 3v14M15 21v-9l5 2v7M3 21h18' }
  ];

  const svgIcon = (d) => `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${d}" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>`;
  const t = (tag, cls, text) => el(tag, Object.assign({}, cls ? { class: cls } : {}, text != null ? { text } : {}));

  function card(lm, title) {
    const sec = el('section', { class: 'card', 'data-core': lm.core, id: `card-${lm.core}`, 'aria-labelledby': `h-${lm.core}`, style: `--accent:${lm.color}` });
    const head = el('div', { class: 'card-head' });
    head.innerHTML = `<span class="ico">${svgIcon(lm.icon)}</span>`;
    head.append(el('div', {}, [el('p', { class: 'where', text: `${lm.code} · ${lm.name}` }), el('h2', { id: `h-${lm.core}`, text: title })]));
    sec.append(head);
    return sec;
  }

  const builders = {
    project(lm) {
      const sec = card(lm, 'Agentnagar, under the big tree');
      const b = Kit.projectBlock(); b.removeAttribute('data-core');
      sec.append(b);
      sec.append(t('h3', null, 'The reference district'));
      sec.append(el('ul', { class: 'district' }, A.district.map((d) => el('li', {}, [el('b', { text: `${d.id} ${d.name}` }), el('span', { text: d.note })]))));
      return sec;
    },
    style(lm) {
      const sec = card(lm, 'How the model is made');
      sec.append(el('p', { class: 'intent', text: content.intent }));
      sec.append(t('h3', null, 'Principles'));
      sec.append(el('ol', { class: 'principles' }, content.principles.map((p) => el('li', { text: p }))));
      sec.append(t('h3', null, 'Palette'));
      sec.append(el('p', { class: 'small', text: 'Averaged from small pixel areas of the selected sheets; approximate.' }));
      sec.append(el('ul', { class: 'gems' }, content.palette.map((p) => el('li', {}, [el('span', { class: 'gem', style: `--c:${p.hex}`, 'aria-hidden': 'true' }), el('span', { class: 'gem-name', text: p.name }), el('code', { text: p.hex })]))));
      sec.append(t('h3', null, 'Materials and texture'), t('p', null, content.materials));
      sec.append(t('h3', null, 'Typography'), t('p', null, content.type));
      return sec;
    },
    views(lm) {
      const sec = card(lm, 'One district, four views');
      sec.append(el('p', { class: 'note', text: A.conceptNote }));
      S.sheets.forEach((sheet, i) => {
        sec.append(el('figure', { class: 'sheet' }, [
          el('a', { href: Kit.href(sheet.image), 'aria-label': `Open full-size sheet: ${sheet.title}, ${sheet.revision}` }, Kit.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sheet.title} (${sheet.revision}), four panels: ${Kit.PANEL_NAMES[i].join(', ')}.` })),
          el('figcaption', {}, [el('b', { text: `${sheet.title} · ${sheet.revision}` }), el('span', { class: 'panels', text: Kit.PANEL_NAMES[i].join(' · ') }), t('span', null, SHEET_NOTES[i])])
        ]));
      });
      return sec;
    },
    agents(lm) {
      const sec = card(lm, 'A1 and the Guild');
      sec.append(el('div', { class: 'duo' }, [
        el('figure', {}, [Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): a woman with a yellow and white shirt talks with City Agent A1, a faceted white and yellow robot with a dark visor, cyan eyes and a leaf A1 mark, holding a tablet.` }), el('figcaption', { text: 'Conversation' })]),
        el('figure', {}, [Kit.sheetImg(S, 3, 'tr', { alt: `${S.name} concept study, Interfaces, Mobile panel (${S.sheets[3].revision}): a phone map selecting Workshop W1, with A1 offering to check availability and a yellow Ask button.` }), el('figcaption', { text: 'Mobile card' })])
      ]));
      sec.append(t('p', null, content.agents));
      sec.append(el('p', { class: 'small', text: A.agentA1 }));
      sec.append(t('h3', null, 'Guild residents'));
      sec.append(el('p', { class: 'small', text: `Not depicted in these sheets, so not drawn here. ${A.guildNote}` }));
      sec.append(el('ul', { class: 'guild' }, A.guild.map((g) => el('li', {}, [el('b', { text: g.name }), el('span', { text: g.role })]))));
      return sec;
    },
    tradeoffs(lm) {
      const sec = card(lm, 'Strengths and trade-offs');
      sec.append(el('dl', { class: 'trade' }, content.tradeoffs.flatMap((x) => [el('dt', { text: x.label }), el('dd', { text: x.text })])));
      return sec;
    },
    status(lm) {
      const sec = card(lm, 'Status');
      const st = Kit.statusBlock(S); st.removeAttribute('data-core');
      sec.append(st);
      return sec;
    }
  };

  const panel = document.getElementById('panel');
  const legend = document.getElementById('legend');
  const cards = {};
  const buttons = {};
  LANDMARKS.forEach((lm, i) => {
    const sec = builders[lm.core](lm);
    const next = LANDMARKS[(i + 1) % LANDMARKS.length];
    const nb = el('button', { type: 'button', class: 'next', text: `Next landmark: ${next.name} →` });
    nb.addEventListener('click', () => api.open(next.core, { focus: true, fly: true }));
    sec.append(nb);
    sec.hidden = true;
    panel.append(sec);
    cards[lm.core] = sec;
    const b = el('button', { type: 'button', class: 'lm', style: `--accent:${lm.color}`, 'aria-controls': `card-${lm.core}`, 'aria-pressed': 'false' });
    b.innerHTML = `<span class="ico">${svgIcon(lm.icon)}</span><span class="lm-text"><b>${lm.name}</b><small>${lm.label}</small></span>`;
    b.addEventListener('click', () => api.open(lm.core, { focus: true, fly: true }));
    legend.append(b);
    buttons[lm.core] = b;
  });

  const listeners = [];
  const api = {
    S, content, LANDMARKS, svgIcon,
    current: null,
    onOpen(fn) { listeners.push(fn); },
    open(core, opts) {
      const o = opts || {};
      Object.entries(cards).forEach(([k, c]) => { c.hidden = k !== core; });
      Object.entries(buttons).forEach(([k, b]) => b.setAttribute('aria-pressed', String(k === core)));
      api.current = core;
      panel.scrollTop = 0;
      listeners.forEach((fn) => fn(core, o));
      if (o.focus) {
        if (window.matchMedia('(max-width: 900px)').matches) panel.scrollIntoView({ behavior: Kit.reducedMotion() ? 'auto' : 'smooth', block: 'start' });
        panel.focus({ preventScroll: true });
      }
    }
  };
  window.Diorama = api;

  Kit.mountNav(document.getElementById('nav-slot'), S);
  Kit.notesDialog(S, content, document.getElementById('notes-btn'));
  api.open('project');
})();
