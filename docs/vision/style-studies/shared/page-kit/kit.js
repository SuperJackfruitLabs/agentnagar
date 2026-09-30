// Shared helpers for the style showcase pages. Requires styles-data.js and project.js.
// Pages live at styles/<id>/page/index.html, so the collection root is three levels up.
// Elements carry `kit-` classes and no styling; each page styles them in its own idiom.
(function () {
  const ROOT = '../../../';
  const REPO = '../../../../../../';
  // Scene areas of the four panels on a 1536 x 1024 sheet, inset to avoid captions and gutters.
  const PANELS = {
    tl: [18, 44, 736, 440], tr: [784, 44, 736, 440],
    bl: [18, 544, 736, 426], br: [784, 544, 736, 426]
  };
  const PANEL_NAMES = [
    ['Map', 'Top-down', 'Diagonal', 'Street'],
    ['Workshop', 'Home', 'Conversation', 'Gathering'],
    ['Build mode', 'Transit', 'Night and rain', 'Waterfront park'],
    ['Facility', 'Mobile', 'Rooftop', 'AR tabletop']
  ];
  const ORDER = ['tl', 'tr', 'bl', 'br'];

  function el(tag, attrs, children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (key === 'text') node.textContent = value;
      else if (key === 'class') node.className = value;
      else node.setAttribute(key, value);
    }
    for (const child of [].concat(children || [])) node.append(child);
    return node;
  }

  function style(id) {
    const found = window.STYLE_DATA.styles.find((s) => s.id === id);
    if (!found) throw new Error(`Unknown style ${id}`);
    return found;
  }

  const href = (path) => ROOT + path;

  // One sheet, or one panel of it ('tl' | 'tr' | 'bl' | 'br'). Returns a <figure>-free wrapper.
  function sheetImg(s, sheetIndex, panel, options) {
    const sheet = s.sheets[sheetIndex];
    const opts = options || {};
    const label = panel ? PANEL_NAMES[sheetIndex][ORDER.indexOf(panel)] : sheet.title;
    const alt = opts.alt || `${s.name} concept study: ${sheet.title}${panel ? `, ${label} panel` : ''} (${sheet.revision}).`;
    const img = el('img', { src: href(sheet.image), alt, loading: opts.eager ? 'eager' : 'lazy', decoding: 'async' });
    if (!panel) {
      img.className = 'kit-sheet';
      return img;
    }
    const [x, y, w, h] = PANELS[panel];
    const box = el('div', { class: 'kit-panel', role: 'img', 'aria-label': alt });
    Object.assign(box.style, { position: 'relative', overflow: 'hidden', aspectRatio: `${w} / ${h}` });
    img.alt = '';
    Object.assign(img.style, {
      position: 'absolute', maxWidth: 'none',
      width: `${(1536 / w) * 100}%`, height: `${(1024 / h) * 100}%`,
      left: `${(-x / w) * 100}%`, top: `${(-y / h) * 100}%`
    });
    box.append(img);
    return box;
  }

  function navLinks(s) {
    return {
      prev: `../../${s.prev}/page/index.html`,
      next: `../../${s.next}/page/index.html`,
      index: href('pages.html'),
      prevName: style(s.prev).name,
      nextName: style(s.next).name
    };
  }

  function mountNav(container, s) {
    const n = navLinks(s);
    const nav = el('nav', { class: 'kit-nav', 'data-core': 'nav', 'aria-label': 'Style pages' }, [
      el('a', { class: 'kit-prev', href: n.prev, rel: 'prev', text: `← ${n.prevName}` }),
      el('a', { class: 'kit-index', href: n.index, text: 'All 30 styles' }),
      el('a', { class: 'kit-next', href: n.next, rel: 'next', text: `${n.nextName} →` })
    ]);
    container.append(nav);
    return nav;
  }

  // Revisions, verbatim review summary and source links.
  function statusBlock(s) {
    const rows = s.sheets.map((sheet) => el('li', {}, [
      `${sheet.title}: `,
      el('a', { href: href(sheet.image), text: sheet.revision }),
      ' · ',
      el('a', { href: href(sheet.review), text: 'review' })
    ]));
    const sources = s.review_sources.map((src) => el('li', {}, el('a', { href: href(src), text: src.split('/').pop() })));
    const role = (window.AGENTNAGAR.styleRoles || {})[s.id];
    return el('div', { class: 'kit-status', 'data-core': 'status' }, [
      el('p', { class: 'kit-summary', text: s.review_summary }),
      role ? el('p', { class: 'kit-role', text: role }) : '',
      el('p', { class: 'kit-concept', text: window.AGENTNAGAR.conceptNote }),
      el('ul', { class: 'kit-revisions' }, rows),
      sources.length ? el('ul', { class: 'kit-sources' }, sources) : '',
      el('p', { class: 'kit-links' }, [
        el('a', { href: href(s.readme), text: 'Gallery' }), ' · ',
        el('a', { href: href(s.brief), text: 'Brief' }), ' · ',
        el('a', { href: href(s.manifest), text: 'Manifest' })
      ])
    ]);
  }

  function projectBlock() {
    const a = window.AGENTNAGAR;
    return el('div', { class: 'kit-project', 'data-core': 'project' }, [
      el('p', { class: 'kit-tagline', text: a.tagline }),
      ...a.summary.map((t) => el('p', { text: t })),
      el('dl', {}, a.facts.flatMap((f) => [el('dt', { text: f.label }), el('dd', { text: f.text })])),
      el('p', { class: 'kit-small', text: `${a.status} ${a.nameNote}` })
    ]);
  }

  // A plain document containing every core item. `content` is the page's own:
  // {intent, principles[], palette[{name, hex}], materials, type, agents, tradeoffs[{label, text}]}
  function notesDocument(s, content) {
    const c = content;
    const section = (core, heading, children) =>
      el('section', { class: `kit-notes-${core}`, 'data-core': core }, [el('h2', { text: heading }), ...children]);
    const project = projectBlock();
    project.removeAttribute('data-core');
    const status = statusBlock(s);
    status.removeAttribute('data-core');
    const doc = el('article', { class: 'kit-notes' }, [
      el('h1', { text: `${s.number} ${s.name}` }),
      section('project', 'Agentnagar', [project]),
      section('style', 'The style', [
        el('p', { text: c.intent }),
        el('ul', {}, c.principles.map((p) => el('li', { text: p }))),
        el('ul', { class: 'kit-palette' }, c.palette.map((p) => el('li', {}, [
          el('span', { class: 'kit-swatch', style: `background:${p.hex}`, 'aria-hidden': 'true' }), ` ${p.name} ${p.hex}`]))),
        el('p', { text: `Materials: ${c.materials}` }),
        el('p', { text: `Type: ${c.type}` })
      ]),
      section('views', 'One district, four views', s.sheets.map((sheet, i) => el('figure', {}, [
        sheetImg(s, i), el('figcaption', { text: `${sheet.title} (${sheet.revision}). ${window.AGENTNAGAR.conceptNote}` })]))),
      section('agents', 'Agents in this style', [el('p', { text: c.agents }), el('p', { text: window.AGENTNAGAR.agentA1 })]),
      section('tradeoffs', 'Strengths and trade-offs', [el('dl', {}, c.tradeoffs.flatMap((t) => [el('dt', { text: t.label }), el('dd', { text: t.text })]))]),
      section('status', 'Status', [status])
    ]);
    const navHolder = el('div');
    mountNav(navHolder, s).removeAttribute('data-core');
    doc.append(el('section', { class: 'kit-notes-nav', 'data-core': 'nav' }, [el('h2', { text: 'More styles' }), navHolder]));
    return doc;
  }

  // A <dialog> holding the notes document, opened by `trigger`. Returns the dialog.
  function notesDialog(s, content, trigger) {
    const close = el('button', { class: 'kit-close', type: 'button', text: 'Close notes' });
    const dialog = el('dialog', { class: 'kit-dialog', 'aria-label': `${s.name} notes` }, [close, notesDocument(s, content)]);
    close.addEventListener('click', () => dialog.close());
    document.body.append(dialog);
    if (trigger) trigger.addEventListener('click', () => dialog.showModal());
    return dialog;
  }

  const reducedMotion = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  window.Kit = { ROOT, REPO, PANEL_NAMES, style, href, el, sheetImg, navLinks, mountNav, statusBlock, projectBlock, notesDocument, notesDialog, reducedMotion };
})();
