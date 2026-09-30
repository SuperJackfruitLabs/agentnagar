// 02 Voxel: page copy and the non-3D guide. Facts come from STYLE_DATA and AGENTNAGAR;
// style prose is written from brief.md, the four selected sheets and REPAIR.md.
(function () {
  const S = Kit.style('02-voxel');
  const A = window.AGENTNAGAR;
  const el = Kit.el;
  const REPO = Kit.REPO;

  const content = {
    intent: 'A city assembled from chunky cubes and stepped forms, with a playful, tangible construction language. Emerald, cobalt and orange distinguish buildings and activities. Trees, furniture, vehicles and residents share the block-based aesthetic.',
    principles: [
      'Designed within the grid: terraces, window rhythms, roof profiles and entrances give each building its own character.',
      'One building, three readings: a landmark on the map, a roof pattern from above and a facade at street level.',
      'Everything is blocks: trees, benches, trams, people and robots share one construction language.',
      'Colour carries place: yellow Workshop, orange Library, emerald trees, cobalt river.',
      'Faces and gestures carry character: conversation views frame eyes and hands so blocky residents stay expressive.'
    ],
    palette: [
      { name: 'River cobalt', hex: '#0182E5' },
      { name: 'Lawn emerald', hex: '#50AD41' },
      { name: 'Canopy green', hex: '#329F2E' },
      { name: 'Workshop yellow', hex: '#EFC332' },
      { name: 'Library orange', hex: '#FD8D2D' },
      { name: 'Jacket cobalt', hex: '#0E4099' },
      { name: 'Road slate', hex: '#6A717F' },
      { name: 'Robot shell', hex: '#DED3D1' },
      { name: 'Screen black', hex: '#131614' },
      { name: 'Chevron green', hex: '#0EF69F' },
      { name: 'Tram coral', hex: '#E69C79' },
      { name: 'Caption navy', hex: '#2A365C' },
      { name: 'Matte cream', hex: '#EAE6DB' }
    ],
    materials: 'Matte, softly lit cubes with gentle occlusion in the corners; stepped white towers with blue glass bands and roof gardens; foliage built from two greens of cube; pale square paving; warm interior timber and pegboards. Sheets sit on a cream matte with navy caption strips.',
    type: 'The sheets caption each panel in a heavy, square-shouldered uppercase sans in navy on a cream strip, and interface tiles use chunky rounded labels. This page uses Bungee for signage and Nunito for reading text.',
    agents: 'On the sheets, City Agent A1 is a white cube-headed robot: a black display with green chevron eyes and a green smile, a green-and-white chequered torso marked A1 with a leaf badge, and dark block hands. People are square-headed voxel figures with blocky hair and cobalt, orange and green clothes. The Guild residents are not drawn on the sheets; the local work-bay prototype gives all fourteen the same robot family (white shell, dark display, green chevrons, segmented limbs) with a role accent and chest motif each. Only Kai’s and Lyra’s appearances are user-approved; the other twelve await review.',
    tradeoffs: [
      { label: 'Map and street readability', text: 'Strong. The yellow sawtooth Workshop, orange vaulted Library and the single big tree stay recognisable from the map panel to the street panel, and cube trees read at every distance. The white stepped towers are near-identical, so north of the square the map relies on labels.' },
      { label: 'Device and production cost', text: 'The brief proposes grouping distant blocks into simplified shapes, reducing hidden detail and keeping nearby interactive objects legible, with contact shadows and material variation on high tiers. It also warns that a blocky look is not a performance guarantee: geometry, visibility and scene density need measuring. This page’s box scene measures nothing.' },
      { label: 'UI legibility', text: 'The interface panels use flat, high-contrast icon tiles (Workshop orange tools, Library blue book, Transit purple tram, Park green leaf) that sit well beside blocks. Small text on the phone and tabletop panels needs the full-size image to read.' },
      { label: 'Expression', text: 'The brief asks conversation views to take care over eyes, gestures and framing. A1 and the robots express themselves through a display face and block hands, which is a narrow range; the human residents carry more of the emotion on the sheets.' },
      { label: 'Agent versus human reading', text: 'Humans and robots share one block language on the sheets. The prototype’s first Kai was built as a human after misreading the living sheet’s residents as the agent reference; the 2026-09-22 correction moved agents to the robot appearance.' },
      { label: 'Limits noted in review', text: 'The map keeps some pictorial roof shading; the top-down panel is not a calibrated orthographic render; bridge spans are clearest only in the overview and park panels; road widths, roof orientations, tram-stop details and nearby low-rise masses vary between panels; door directions cannot be certified from the images.' }
    ]
  };
  window.VOXEL_CONTENT = content;

  // Where each landmark appears on each sheet (from looking at the selected images).
  const sheetNotes = [
    'Map and top-down label the River, Park, Workshop, Tree Square, Library, Tram and Downtown, with the north bridge at top left. The diagonal shows the bridge, yellow Workshop, big tree, orange Library and a cream tram; the street view stands on the boulevard.',
    'Workshop: A1 at a bench with residents, the tree through the door. Home: looks west over the sawtooth roofs to the river and bridge. Conversation: A1 labelled. Gathering: Workshop, tree, Library and tram, bridge behind.',
    'Build mode: an X/Y/Z gizmo on the Workshop. Transit: A1 on the tram, next stop Tree Square. Night and rain: Workshop, tree, Library and tram under umbrellas. Waterfront park: river, bridge, Workshop and A1 on a bench.',
    'Facility: A1 at a Library kiosk with Browse, Book and Ask. Mobile: a phone map with the Workshop selected and A1. Rooftop: west over tree and Workshop to the river and bridge. AR tabletop: the Workshop selected, with an external viewer.'
  ];

  // ---- selected callout links
  document.getElementById('proto-link').href = REPO + 'prototypes/voxel-work-bay/README.md';
  document.getElementById('decision-link').href = REPO + 'docs/planning/VISION_DECISIONS.md';

  // ---- project
  const pb = document.getElementById('project-body');
  const project = Kit.projectBlock();
  project.removeAttribute('data-core');
  pb.append(project);

  // ---- style
  document.getElementById('style-intent').textContent = content.intent;
  const pr = document.getElementById('style-principles');
  content.principles.forEach((p) => pr.append(el('li', { text: p })));
  const pal = document.getElementById('style-palette');
  const shade = (hex, f) => {
    const n = parseInt(hex.slice(1), 16);
    const c = [n >> 16, (n >> 8) & 255, n & 255].map((v) => Math.max(0, Math.min(255, Math.round(f > 0 ? v + (255 - v) * f : v * (1 + f)))));
    return '#' + c.map((v) => v.toString(16).padStart(2, '0')).join('');
  };
  content.palette.forEach((p) => {
    const svg = `<svg viewBox="0 0 40 40" aria-hidden="true"><polygon points="20,3 37,12 20,21 3,12" fill="${shade(p.hex, 0.18)}"/><polygon points="3,12 20,21 20,38 3,29" fill="${p.hex}"/><polygon points="37,12 20,21 20,38 37,29" fill="${shade(p.hex, -0.22)}"/></svg>`;
    const li = el('li', {});
    li.innerHTML = svg;
    li.append(el('span', { class: 'sw-name', text: p.name }), el('code', { text: p.hex }));
    pal.append(li);
  });
  document.getElementById('style-materials').textContent = content.materials;
  document.getElementById('style-type').textContent = content.type;

  // ---- views
  document.getElementById('views-note').textContent = A.conceptNote;
  const lm = document.getElementById('views-landmarks');
  A.district.forEach((d) => lm.append(el('li', {}, [el('b', { text: d.name }), ` ${d.note}`])));
  const sheets = document.getElementById('views-sheets');
  S.sheets.forEach((sheet, i) => {
    const img = Kit.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sheet.title} (${sheet.revision}): four panels, ${Kit.PANEL_NAMES[i].join(', ')}. ${sheetNotes[i]}` });
    const link = el('a', { class: 'sheet-link', href: Kit.href(sheet.image), 'aria-label': `Open ${sheet.title} full size` }, img);
    sheets.append(el('figure', { class: 'sheet' }, [
      link,
      el('figcaption', {}, [
        el('span', { class: 'sheet-title', text: `${sheet.title} · ${sheet.revision}` }),
        el('span', { class: 'chips' }, Kit.PANEL_NAMES[i].map((n) => el('span', { class: 'chip', text: n }))),
        el('span', { class: 'sheet-note', text: sheetNotes[i] }),
        el('span', { class: 'sheet-concept', text: 'Concept study, not a game capture.' })
      ])
    ]));
  });

  // ---- agents
  const ab = document.getElementById('agents-body');
  const crop = (i, p) => Kit.sheetImg(S, i, p);
  ab.append(
    el('div', { class: 'agents-a1' }, [
      el('figure', { class: 'crop' }, [crop(1, 'bl'), el('figcaption', { text: 'Conversation panel, Living community sheet: City Agent A1. Concept study.' })]),
      el('div', {}, [
        el('h3', { text: 'City Agent A1' }),
        el('p', { text: content.agents }),
        el('p', { class: 'small', text: A.agentA1 }),
        el('figure', { class: 'crop crop-small' }, [crop(1, 'tl'), el('figcaption', { text: 'Workshop panel: A1 at a bench between two residents. Concept study.' })])
      ])
    ]),
    el('h3', { text: 'The fourteen Guild residents' }),
    el('p', { class: 'small', text: `${A.guildNote} The chips below are illustrative page art using the prototype’s accent names; they are not approved designs.` })
  );
  // Accent names from prototypes/voxel-work-bay/evidence/FULL-CAST-VERIFICATION.md (roster order), approximate colours.
  const accents = ['#8fdcc0', '#f39a3a', '#26345f', '#1f5fd6', '#8a6fd1', '#3f9e45', '#d8a45a', '#2aa39a', '#8cc3f0', '#c8641c', '#9aa3ad', '#ef7a66', '#23d18b', '#a6d86a'];
  window.VOXEL_ACCENTS = accents;
  const ul = el('ul', { class: 'guild' });
  A.guild.forEach((g, i) => {
    const li = el('li', { class: 'guild-card' });
    li.innerHTML = `<svg viewBox="0 0 32 40" aria-hidden="true"><rect x="5" y="2" width="22" height="16" rx="1" fill="#eeeae6"/><rect x="8" y="5" width="16" height="10" fill="#131614"/><path d="M10 10l2-2 2 2M18 10l2-2 2 2M13 13h6" stroke="#0ef69f" stroke-width="1.4" fill="none"/><rect x="3" y="8" width="2" height="5" fill="${accents[i]}"/><rect x="27" y="8" width="2" height="5" fill="${accents[i]}"/><rect x="8" y="20" width="16" height="12" fill="#eeeae6"/><rect x="12" y="23" width="8" height="6" fill="${accents[i]}"/><rect x="9" y="33" width="5" height="6" fill="#dcd7d2"/><rect x="18" y="33" width="5" height="6" fill="#dcd7d2"/></svg>`;
    li.append(el('span', { class: 'g-name', text: g.name }), el('span', { class: 'g-role', text: g.role }));
    ul.append(li);
  });
  ab.append(ul);
  const proto = (file, alt, cap) => el('figure', { class: 'proto' }, [
    el('img', { src: REPO + 'prototypes/voxel-work-bay/evidence/' + file, alt, loading: 'lazy', decoding: 'async' }),
    el('figcaption', { text: cap })
  ]);
  ab.append(el('div', { class: 'protos' }, [
    proto('full-cast-overview-r004.png', 'Work-bay prototype render: a shared workshop hall seen from above, with fourteen small white robots seated at desks in two rows and a courtyard with one voxel tree.', 'Work-bay prototype, full-cast overview (r004). Local render with sample data only; nothing in this milestone is accepted.'),
    proto('full-cast-lineup-r004.png', 'Work-bay prototype render: fourteen white robots in a row, each with a dark display showing green chevron eyes and smile, and a different chest motif.', 'Full-cast line-up (r004). Kai and Lyra approved; twelve appearances pending review.')
  ]));

  // ---- trade-offs
  const tl = document.getElementById('trade-list');
  content.tradeoffs.forEach((t) => tl.append(el('div', { class: 'trade-row' }, [el('dt', { text: t.label }), el('dd', { text: t.text })])));

  // ---- status
  const sb = document.getElementById('status-body');
  sb.append(Kit.statusBlock(S));
  sb.append(el('p', { class: 'small' }, [
    'Selection for first-scene assets covers the local work-bay experiment only. ',
    el('a', { href: REPO + 'prototypes/voxel-work-bay/README.md', text: 'Prototype README' }), '.'
  ]));

  // ---- nav
  Kit.mountNav(document.getElementById('nav-body'), S);

  // ---- notes dialog
  const dialog = Kit.notesDialog(S, content, document.getElementById('notes-btn'));
  dialog.querySelector('.kit-notes h1').insertAdjacentElement('afterend', el('p', { class: 'kit-selected' }, [
    'Voxel is the selected style for first-scene assets (local experiment only). ',
    el('a', { href: REPO + 'prototypes/voxel-work-bay/README.md', text: 'Work-bay prototype' })
  ]));
})();
