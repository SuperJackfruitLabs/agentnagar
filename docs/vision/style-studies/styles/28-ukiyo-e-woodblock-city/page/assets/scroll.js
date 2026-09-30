// 28 Ukiyo-e-inspired woodblock city: content and handscroll behaviour.
(function () {
  const S = Kit.style(document.documentElement.dataset.style);
  const A = window.AGENTNAGAR;
  const el = Kit.el;

  const NOTES = {
    intent: 'A riverfront city drawn as a woodblock print: carved contour lines, flat perspective planes, patterned wave and cloud bands, and visible wood grain. Large views hold flat planes and stylised water so the map and the diagonal read as one print. Street and night scenes keep lantern light as flat red and orange shapes. Close-ups, including kiosks and phones, stay linework on paper texture rather than shaded rendering.',
    principles: [
      'Keyblock first: every form is closed by a carved contour line before any pigment goes down.',
      'Flat pigment planes: depth comes from overlap and graded bokashi bands, not from modelled shading.',
      'Pattern carries water and air: wave and cloud bands stylise the river and sky at every scale.',
      'Lantern light stays flat: night and street scenes keep light as red and orange shapes.',
      'Paper shows through: close-ups, kiosks and phones stay linework on grain.'
    ],
    palette: [
      { name: 'Rice paper', hex: '#F1E3C7' },
      { name: 'Keyblock ink', hex: '#2E2E31' },
      { name: 'Indigo', hex: '#192D47' },
      { name: 'Prussian water', hex: '#265975' },
      { name: 'Wave blue', hex: '#366A84' },
      { name: 'Vermilion', hex: '#AE5243' },
      { name: 'Blossom', hex: '#EBB2A6' },
      { name: 'Muted pine', hex: '#60655D' }
    ],
    materials: 'Rice-paper cream ground with visible wood grain; carved contour lines; flat pigment planes graded by bokashi; patterned wave and cloud bands; timber halls with tiled roofs; tatami, low tables and sliding screens indoors. The brief proposes registration offset and ink bleed only at higher device tiers.',
    type: 'The sheets letter their panel names in serif capitals on cream cartouches. This page uses Zen Old Mincho, an open-licence serif, for everything: horizontal cartouches for labels and vertical tanzaku slips for station titles. All text stays in English; no kana or kanji are added.',
    agents: 'City Agent A1 appears once as a figure, in Living community / Conversation: a white-faced robot with a dark mechanical neck and articulated white hands, wearing a blue printed robe with a wave band and a crest roundel. The shared leaf badge cannot be made out at sheet resolution. In Interfaces / Mobile the phone\'s agent card shows a human-looking portrait instead, and the review lists this style among those where the robot and the phone portrait are not clearly the same agent. Residents wear patterned robes with wave motifs and carry parasols. No sheet depicts individual Guild residents.',
    tradeoffs: [
      { label: 'Map vs street', text: 'Map and top-down read well: flat planes, a blue patterned river on the west, the tree square at the centre, the east complex with its pond and red trams along the southern boulevard. The diagonal keeps them in one print. At street scale, timber detail, banners and crowds crowd the frame, and across sheets 01 to 03 the setting broadens into a historical, fantastical city rather than the reference district.' },
      { label: 'Device and production cost', text: 'The brief proposes keeping contour lines, flat pigment planes and patterned water at every tier. Lower tiers would drop paper grain and secondary pattern; higher tiers could add registration offset and ink bleed. Specialist review and collaboration with artists from the tradition are a precondition for any production use.' },
      { label: 'UI legibility', text: 'The facility kiosk (Browse, Book, Ask) and the phone card stay flat and readable, which suits linework on paper. The AR tabletop\'s vertical labels come out garbled, and environmental signs that look Japanese in 00 to 02 become English-heavy in 03.' },
      { label: 'Borrowed motifs', text: 'The generated sheets lean on a snow-capped conical mountain, cherry blossom and period dress, so the city reads as a historical place rather than an original riverfront. The review warns against inferring an exact historical place or period from the imagery.' },
      { label: 'Review defects', text: 'The 00 map compass inset is not a coherent four-direction compass. 03 / AR tabletop becomes a water-surrounded settlement rather than the atlas district. Corrections to 28 are still listed as pending in the repair status.' }
    ]
  };

  // Landmarks as each sheet shows them; used in captions and alt text.
  const SHEET_NOTES = [
    'Map and top-down: River along the west edge with sailing boats; an arched stone crossing at the north; the Workshop halls on the west bank with chimney smoke; Tree Square at the centre; an east complex with a pond where the Library would sit; red trams on the tram boulevard to the south. Diagonal keeps the same layout; Street looks down the square past the tree toward a red tram.',
    'Workshop drafting table and models; Home looking over the river and an arched bridge; Conversation between a resident and the robot agent in a blue printed robe; Gathering with musicians under a stage roof by the river.',
    'Build mode with a wireframe hall and colour-coded axes on a timber deck; Transit from inside a tram across the river; Night and rain with flat lantern light and parasols; Waterfront park by the river and bridge.',
    'Facility kiosk with Browse, Book and Ask; Mobile phone with an agent card; Rooftop café over the river; AR tabletop model, which becomes a water-surrounded settlement.'
  ];

  const $ = (id) => document.getElementById(id);

  // Project
  $('projectBody').append(Kit.projectBlock());
  $('projectBody').querySelector('.kit-project').removeAttribute('data-core');

  // Style
  const styleBody = $('styleBody');
  styleBody.append(
    el('h3', { text: 'Intent' }),
    el('p', { text: NOTES.intent }),
    el('div', { class: 'cols-2' }, [
      el('div', {}, [el('h3', { text: 'Principles' }), el('ol', { class: 'principles' }, NOTES.principles.map((p) => el('li', { text: p })))]),
      el('div', {}, [
        el('h3', { text: 'Pigments' }),
        el('ul', { class: 'palette', 'aria-label': 'Palette, sampled from the selected sheets' }, NOTES.palette.map((p) =>
          el('li', {}, [el('span', { class: 'chip', style: `background-color:${p.hex}`, 'aria-hidden': 'true' }), el('b', { text: p.name }), el('code', { text: p.hex })]))),
        el('p', { class: 'tiny', text: 'Hex values sampled from the four selected sheets.' })
      ])
    ]),
    el('h3', { text: 'Materials and texture' }),
    el('p', { text: NOTES.materials }),
    el('h3', { text: 'Typography' }),
    el('p', { text: NOTES.type })
  );

  // Views: intro column, then one print per sheet
  const views = $('viewsBody');
  const intro = el('div', { class: 'views-intro' }, [
    el('h3', { text: 'One district, four views' }),
    el('p', { text: 'The same reference district drawn four ways. Every sheet is a concept study:' }),
    el('p', { class: 'note', text: A.conceptNote }),
    el('h3', { text: 'Reference landmarks' }),
    el('ul', { class: 'landmarks' }, A.district.map((d) => el('li', {}, [el('b', { text: d.name }), ` · ${d.note}`]))),
    el('figure', { class: 'lens' }, [
      Kit.sheetImg(S, 0, 'tl', { alt: `${S.name} concept study, City perspectives, Map panel (${S.sheets[0].revision}): river on the west, arched crossing to the north, workshop halls with smoke, tree square at the centre, east complex with a pond, red trams on the southern boulevard.` }),
      el('figcaption', { class: 'tiny', text: 'Map panel, cropped from City perspectives. Note the compass inset at lower right, which the review flags as incoherent.' })
    ])
  ]);
  views.append(intro);
  S.sheets.forEach((sheet, i) => {
    const alt = `${S.name} concept study: ${sheet.title} (${sheet.revision}). ${SHEET_NOTES[i]}`;
    views.append(el('figure', { class: 'print' }, [
      el('a', { class: 'frame', href: Kit.href(sheet.image), 'aria-label': `Open ${sheet.title} sheet full size` }, Kit.sheetImg(S, i, null, { alt })),
      el('figcaption', {}, [
        el('b', { text: `${i + 1}. ${sheet.title}` }), ` · ${sheet.revision} · concept study`, el('br'),
        Kit.PANEL_NAMES[i].join(', ') + '. ', SHEET_NOTES[i]
      ])
    ]));
  });

  // Agents
  const a1Art = `<svg viewBox="0 0 130 170" role="img" aria-label="Illustrative drawing of City Agent A1 in this style: a white-faced robot in a blue printed robe with a wave band.">
    <g stroke="#2e2e31" stroke-width="2" stroke-linejoin="round" stroke-linecap="round">
      <rect width="130" height="170" fill="#ebb2a6" opacity=".35" stroke="none"/>
      <path d="M18 170 Q22 112 65 104 Q108 112 112 170 Z" fill="#192d47"/>
      <path d="M22 150 Q65 138 108 150 L112 170 H18 Z" fill="#265975"/>
      <path d="M28 160 q6 -8 12 0 q6 -8 12 0 q6 -8 12 0 q6 -8 12 0 q6 -8 12 0 q6 -8 12 0" fill="none" stroke="#f1e3c7" stroke-width="1.5"/>
      <path d="M50 104 L65 132 L80 104" fill="#f7eedb"/>
      <circle cx="92" cy="128" r="8" fill="#f7eedb"/><circle cx="92" cy="128" r="3" fill="#192d47" stroke="none"/>
      <path d="M56 86 H74 V106 H56 Z" fill="#2e2e31"/>
      <path d="M59 92 H71 M59 98 H71" stroke="#8e8e92" stroke-width="1.2" fill="none"/>
      <circle cx="40" cy="52" r="8" fill="#2e2e31"/><circle cx="40" cy="52" r="3.5" fill="#f7eedb"/>
      <circle cx="90" cy="52" r="8" fill="#2e2e31"/><circle cx="90" cy="52" r="3.5" fill="#f7eedb"/>
      <path d="M42 50 Q42 18 65 18 Q88 18 88 50 Q88 80 65 88 Q42 80 42 50 Z" fill="#f7eedb"/>
      <path d="M52 52 q5 -4 10 0 M68 52 q5 -4 10 0" fill="none" stroke-width="1.8"/>
      <path d="M60 70 q5 2 10 0" fill="none" stroke-width="1.5"/>
      <path d="M50 30 q15 -8 30 0" fill="none" stroke="#c9c2b4" stroke-width="1.4"/>
    </g></svg>`;
  const agentArt = el('div', { class: 'agent-art' });
  agentArt.innerHTML = a1Art;
  const agents = $('agentsBody');
  agents.append(el('div', { class: 'agents-grid' }, [
    el('div', {}, [
      el('h3', { text: 'City Agent A1' }),
      el('div', { class: 'agent-row' }, [agentArt, el('div', {}, [el('p', { text: NOTES.agents }), el('p', { class: 'tiny', text: 'Drawing at left: illustrative, made for this page from the Conversation panel\'s description; not a concept sheet.' })])]),
      el('p', { text: A.agentA1 }),
      el('div', { class: 'crops' }, [
        el('figure', { class: 'agent-crop' }, [Kit.sheetImg(S, 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel (${S.sheets[1].revision}): a resident talks with a white-faced robot agent in a blue printed robe, river and arched bridge behind.` }), el('figcaption', { text: 'Conversation: the robot agent.' })]),
        el('figure', { class: 'agent-crop' }, [Kit.sheetImg(S, 3, 'tr', { alt: `${S.name} concept study, Interfaces perspectives, Mobile panel (${S.sheets[3].revision}): a phone over the river shows an agent card with a human-looking portrait.` }), el('figcaption', { text: 'Mobile: a human-looking portrait on the agent card.' })])
      ])
    ]),
    el('div', {}, [
      el('h3', { text: 'Guild residents' }),
      el('p', { text: `The fourteen proposed Guild residents. ${A.guildNote} None are drawn in these sheets; in this style they would presumably share the residents' patterned robes, which is an inference, not a design.` }),
      el('ul', { class: 'guild' }, A.guild.map((g) => el('li', {}, [el('b', { text: g.name }), g.role])))
    ])
  ]));

  // Trade-offs
  $('tradeoffsBody').append(
    el('p', { class: 'big', text: 'Strong as a map. Harder at street scale, and heavily borrowed.' }),
    el('dl', { class: 'trade' }, NOTES.tradeoffs.flatMap((t) => [el('dt', { text: t.label }), el('dd', { text: t.text })]))
  );

  // Status
  const statusStation = $('st-status');
  const status = Kit.statusBlock(S);
  $('statusBody').append(el('h3', { text: 'Review summary (verbatim)' }), status);
  statusStation.dataset.core = 'status';
  status.removeAttribute('data-core');

  // Footer: nav + concept note
  $('conceptNote').textContent = `Sheets on this page: ${A.conceptNote} Landscape vignettes between stations are illustrative art for this page.`;
  Kit.mountNav($('foot'), S);

  // Notes dialog (plain document view of every core item)
  const dialog = Kit.notesDialog(S, NOTES, $('notesBtn'));
  $('notesBtn2').addEventListener('click', () => dialog.showModal());

  // ---------- Handscroll behaviour ----------
  const scroll = $('scroll');
  const stations = [...document.querySelectorAll('.station')];
  const labels = ['Start', 'Agentnagar', 'Style', 'Views', 'Agents', 'Trade-offs', 'Status', 'End'];
  const list = $('stations');
  const buttons = stations.map((st, i) => {
    const b = el('button', { type: 'button', 'aria-controls': st.id }, [el('span', { class: 'n', 'aria-hidden': 'true', text: String(i) }), el('span', { class: 'lbl', text: labels[i] })]);
    b.addEventListener('click', () => goTo(i, true));
    list.append(el('li', {}, b));
    return b;
  });
  const reduced = Kit.reducedMotion();
  const behave = () => (reduced ? 'auto' : 'smooth');

  function goTo(i, focus) {
    const st = stations[Math.max(0, Math.min(stations.length - 1, i))];
    scroll.scrollTo({ left: st.offsetLeft - 28, behavior: behave() });
    if (focus) st.querySelector('.tanzaku').setAttribute('tabindex', '-1');
    if (focus) setTimeout(() => st.querySelector('.tanzaku').focus({ preventScroll: true }), reduced ? 0 : 450);
  }
  function current() {
    const mid = scroll.scrollLeft + scroll.clientWidth * 0.35;
    let idx = 0;
    stations.forEach((st, i) => { if (st.offsetLeft <= mid) idx = i; });
    if (scroll.scrollLeft >= scroll.scrollWidth - scroll.clientWidth - 2) idx = stations.length - 1;
    return idx;
  }
  const boat = $('boat');
  let raf = 0;
  function update() {
    raf = 0;
    const idx = current();
    buttons.forEach((b, i) => (i === idx ? b.setAttribute('aria-current', 'step') : b.removeAttribute('aria-current')));
    const max = scroll.scrollWidth - scroll.clientWidth;
    const pct = max > 0 ? scroll.scrollLeft / max : 0;
    boat.style.left = `calc(${(pct * 100).toFixed(2)}% - ${(pct * 26).toFixed(1)}px)`;
  }
  scroll.addEventListener('scroll', () => { if (!raf) raf = requestAnimationFrame(update); }, { passive: true });
  window.addEventListener('resize', update);
  update();

  $('prevStep').addEventListener('click', () => goTo(current() - 1));
  $('nextStep').addEventListener('click', () => goTo(current() + 1));
  $('begin').addEventListener('click', () => goTo(1, true));
  $('rollBack').addEventListener('click', () => goTo(0, true));

  // Keys: arrows unroll, Home/End jump, PageUp/PageDown step stations.
  scroll.addEventListener('keydown', (e) => {
    if (e.target.closest('input, textarea, select')) return;
    const step = Math.max(160, scroll.clientWidth * 0.45);
    const map = {
      ArrowRight: () => scroll.scrollBy({ left: step, behavior: behave() }),
      ArrowLeft: () => scroll.scrollBy({ left: -step, behavior: behave() }),
      Home: () => goTo(0),
      End: () => goTo(stations.length - 1),
      PageDown: () => goTo(current() + 1),
      PageUp: () => goTo(current() - 1)
    };
    if (map[e.key]) { e.preventDefault(); map[e.key](); }
  });

  // Wheel: vertical wheel unrolls sideways unless a station body can still scroll that way.
  scroll.addEventListener('wheel', (e) => {
    if (Math.abs(e.deltaX) > Math.abs(e.deltaY) || e.ctrlKey) return;
    const inner = e.target.closest('.body, .views-intro, figcaption');
    if (inner && inner.scrollHeight > inner.clientHeight + 1) {
      const atTop = inner.scrollTop <= 0;
      const atBottom = inner.scrollTop + inner.clientHeight >= inner.scrollHeight - 1;
      if ((e.deltaY < 0 && !atTop) || (e.deltaY > 0 && !atBottom)) return;
    }
    const max = scroll.scrollWidth - scroll.clientWidth;
    if ((e.deltaY < 0 && scroll.scrollLeft <= 0) || (e.deltaY > 0 && scroll.scrollLeft >= max - 1)) return;
    e.preventDefault();
    const unit = e.deltaMode === 1 ? 32 : e.deltaMode === 2 ? scroll.clientWidth : 1;
    scroll.style.scrollBehavior = 'auto';
    scroll.scrollLeft += e.deltaY * unit;
    scroll.style.scrollBehavior = '';
  }, { passive: false });

  // Drag with a mouse (touch uses native swipe).
  let drag = null;
  scroll.addEventListener('pointerdown', (e) => {
    if (e.pointerType !== 'mouse' || e.button !== 0 || e.target.closest('a, button, input, select, textarea, dialog')) return;
    drag = { x: e.clientX, left: scroll.scrollLeft, moved: false, id: e.pointerId };
  });
  window.addEventListener('pointermove', (e) => {
    if (!drag || e.pointerId !== drag.id) return;
    const dx = e.clientX - drag.x;
    if (!drag.moved && Math.abs(dx) > 5) { drag.moved = true; scroll.classList.add('dragging'); scroll.setPointerCapture?.(drag.id); }
    if (drag.moved) { scroll.scrollLeft = drag.left - dx; e.preventDefault(); }
  });
  const endDrag = () => {
    if (!drag) return;
    if (drag.moved) {
      scroll.classList.remove('dragging');
      const eat = (ev) => { ev.stopPropagation(); ev.preventDefault(); };
      scroll.addEventListener('click', eat, { capture: true, once: true });
      setTimeout(() => scroll.removeEventListener('click', eat, { capture: true }), 0);
    }
    drag = null;
  };
  window.addEventListener('pointerup', endDrag);
  window.addEventListener('pointercancel', endDrag);
})();
