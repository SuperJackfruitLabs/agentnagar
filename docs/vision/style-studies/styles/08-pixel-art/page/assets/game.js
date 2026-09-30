// 08 Pixel art: a small top-down walkable district. Presentation only; no product mechanics.
// Every townsperson holds one core section; the codex below the game holds the same text.
(function () {
  'use strict';
  // Roster initials sit on sampled palette fills; pick night or cream ink, whichever reads.
  function chipInk(hex) {
    const lin = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
    const lum = (h) => { const n = parseInt(h.slice(1), 16); return 0.2126 * lin(n >> 16) + 0.7152 * lin((n >> 8) & 255) + 0.0722 * lin(n & 255); };
    const L = lum(hex), ratio = (a, b) => (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05);
    return ratio(L, lum('#061937')) >= ratio(L, lum('#f3e9d2')) ? '#061937' : '#f3e9d2';
  }
  const S = Kit.style('08-pixel-art');
  const A = window.AGENTNAGAR;
  const C = window.PIXEL_CONTENT;
  const el = Kit.el;
  const RM = Kit.reducedMotion();

  const T = 16, W = 48, H = 28;
  const P = {
    outline: '#0b1426', water: '#016aab', water2: '#0a5b96', waterHi: '#56a6fd', foam: '#cfe8ff',
    grass: '#76bb37', grass2: '#68a82f', grassDk: '#4f8a22', flowerA: '#f6a6c8', flowerB: '#fff4d6',
    path: '#f5d9a8', path2: '#e6c690', plaza: '#ecd8b4', plaza2: '#dcc39b', road: '#59627a', road2: '#4c546b', line: '#efe6c8',
    stone: '#c9c1ae', stone2: '#9a927f', brick: '#97453b', brick2: '#7a3530', brickHi: '#b0584a',
    slate: '#667595', slate2: '#4f5b78', slate3: '#8492b3', glass: '#9fd0f5', glass2: '#5f93c8', amber: '#f8ba77', amber2: '#e98f3f',
    cream: '#f4ead2', cream2: '#d9cdb0', coral: '#e0674f', tramRed: '#c81c2b', trunk: '#6b4428', trunk2: '#4d2f1c',
    leaf1: '#2f6a2a', leaf2: '#3f8f2c', leaf3: '#5fae33', leaf4: '#9ed65a', roofPeach: '#d9825e', roofPeach2: '#b86649',
    ballast: '#7c7f8c', ballast2: '#6a6d7a', rail: '#2a2f40', sleeper: '#5a4636', banner: '#1d53a7', navy: '#0b243d', white: '#f7f3e3'
  };

  // ---------- Map ----------
  const G = 0, WA = 1, PR = 2, RD = 3, PZ = 4, TR = 5, PF = 6, BR = 7, PA = 8, FL = 9;
  const tile = new Uint8Array(W * H);
  const solid = new Uint8Array(W * H);
  const idx = (x, y) => y * W + x;
  const set = (x0, y0, x1, y1, t) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) tile[idx(x, y)] = t; };
  const block = (x0, y0, x1, y1) => { for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) solid[idx(x, y)] = 1; };
  const hash = (x, y) => { let h = (x * 374761393 + y * 668265263) ^ 0x5bd1e995; h = (h ^ (h >>> 13)) * 1274126177; return ((h ^ (h >>> 16)) >>> 0) / 4294967296; };

  set(0, 0, W - 1, H - 1, G);
  set(0, 0, 3, H - 1, WA);               // River R1, west edge
  set(4, 0, 4, H - 1, PR);               // stone promenade
  set(4, 5, W - 1, 6, RD);               // north road
  set(0, 5, 3, 6, BR);                   // North bridge B1
  set(5, 4, 44, 4, PA); set(5, 7, 44, 7, PA);
  set(45, 0, 46, H - 1, RD);             // east road
  set(19, 8, 32, 18, PZ);                // Tree Square T1
  set(16, 13, 18, 13, PA);               // workshop door path
  set(25, 7, 26, 8, PA);
  set(5, 18, 18, 18, PA);                // park path to the stop
  set(19, 19, 32, 19, PF);               // tram platform, south of the square
  set(4, 20, W - 1, 21, TR);             // tram boulevard S1: two tracks
  set(5, 22, 44, 22, PA);
  set(33, 16, 44, 16, PA);
  // park flowerbeds
  [[7, 16], [8, 16], [13, 17], [14, 17], [6, 17]].forEach(([x, y]) => { tile[idx(x, y)] = FL; });

  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (tile[idx(x, y)] === WA) solid[idx(x, y)] = 1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (tile[idx(x, y)] === FL) solid[idx(x, y)] = 1;

  const buildings = [
    { kind: 'tower', x: 10, y: 0, w: 6, h: 4 }, { kind: 'tower', x: 19, y: 0, w: 6, h: 4 }, { kind: 'tower', x: 28, y: 0, w: 6, h: 4 },
    { kind: 'house', x: 36, y: 0, w: 4, h: 3 }, { kind: 'house', x: 41, y: 1, w: 3, h: 3 },
    { kind: 'workshop', x: 7, y: 9, w: 9, h: 6 },
    { kind: 'library', x: 33, y: 8, w: 10, h: 8 },
    { kind: 'house', x: 6, y: 23, w: 5, h: 4 }, { kind: 'house', x: 12, y: 23, w: 4, h: 4 }, { kind: 'house', x: 18, y: 23, w: 5, h: 4 },
    { kind: 'house', x: 25, y: 23, w: 4, h: 4 }, { kind: 'house', x: 31, y: 23, w: 5, h: 4 }, { kind: 'house', x: 38, y: 23, w: 5, h: 4 }
  ];
  buildings.forEach((b) => block(b.x, b.y, b.x + b.w - 1, b.y + b.h - 1));

  const trees = [];
  const addTree = (x, y, kind) => { trees.push({ x, y, kind: kind || 'round' }); solid[idx(x, y)] = 1; };
  [[6, 0], [8, 1], [6, 2], [17, 1], [26, 2], [35, 3], [44, 3]].forEach(([x, y]) => addTree(x, y));
  for (let y = 9; y < 19; y += 3) addTree(5, y, 'palm');
  [[5, 24], [5, 26], [11, 24], [17, 25], [24, 26], [30, 24], [37, 26], [44, 24], [44, 26]].forEach(([x, y]) => addTree(x, y));
  [[6, 8], [9, 8], [12, 8], [15, 8], [17, 10], [17, 16], [9, 17], [11, 16], [16, 17], [43, 9], [44, 11], [43, 13], [44, 15]].forEach(([x, y]) => addTree(x, y));
  const lamps = [[19, 8], [32, 8], [19, 18], [32, 18], [21, 19], [30, 19], [10, 18]];
  const benches = [[20, 11], [31, 11], [21, 16], [30, 16], [12, 18]];
  benches.forEach(([x, y]) => { solid[idx(x, y)] = 1; });
  // Tree Square's living shade tree: trunk is solid, canopy is drawn above walkers.
  block(25, 12, 26, 13);
  const CANOPY = { cx: 26 * T, cy: 12 * T + 2, r: 46 };

  // ---------- Characters ----------
  const TPL = {
    down: ['...kkkkkk...', '..khhhhHHk..', '.khhhhhhHhk.', '.khhhhhhhhk.', '.khsssssshk.', '.kssesssessk', '.kssssssssk.', '..kssssssk..', '.kjjjccjjjk.', 'kjjjjccjjjjk', 'kjjjjjjjbjjk', 'ksjjjjjjjjsk', '.kjjjjjjjjk.', '.kppppppppk.', '.kppk..kppk.', '.kkkk..kkkk.'],
    up: ['...kkkkkk...', '..khhhhHHk..', '.khhhhhhHhk.', '.khhhhhhhhk.', '.khhhhhhhhk.', '.khhhhhhhhk.', '.kshhhhhhsk.', '..kssssssk..', '.kjjjjjjjjk.', 'kjjjjjjjjjjk', 'kjjjjjjjjjjk', 'ksjjjjjjjjsk', '.kjjjjjjjjk.', '.kppppppppk.', '.kppk..kppk.', '.kkkk..kkkk.'],
    right: ['...kkkkkk...', '..khhhhHHk..', '.khhhhhhHhk.', '.khhhhhhhhk.', '.khhhhsssk..', '.khhhsssesk.', '.khhssssssk.', '..kkssssk...', '...kjjcck...', '..kjjjjcck..', '..kjjjjjjk..', '..kjjsjjjk..', '..kjjjjjjk..', '..kppppppk..', '..kppkkppk..', '..kkk..kkk..']
  };
  const WALK = {
    down: [['.kppk...kpk.', '.kkkk...kk..'], ['.kpk...kppk.', '..kk...kkkk.']],
    up: [['.kppk...kpk.', '.kkkk...kk..'], ['.kpk...kppk.', '..kk...kkkk.']],
    right: [['..kppk.kpk..', '.kkkk..kk...'], ['...kpkkppk..', '...kk..kkkk.']]
  };
  const PEOPLE = {
    you: { name: 'You (visitor)', k: P.outline, h: '#4a2e22', H: '#4a2e22', s: '#d9a37a', e: '#1a1020', j: '#4f6b3a', c: '#4f6b3a', b: '#4f6b3a', p: '#26314f' },
    a1: { name: 'City Agent A1', k: P.outline, h: '#eef2f8', H: '#3f7fe0', s: '#f1c7a3', e: '#1f4fa8', j: '#2b2e3d', c: '#1d53a7', b: '#7bd36b', p: '#23324f' },
    olivia: { name: 'Olivia · welcome guide', k: P.outline, h: '#2a1a14', H: '#2a1a14', s: '#b87a55', e: '#1a1020', j: '#e7824c', c: '#f8ba77', b: '#e7824c', p: '#3b2a4a' },
    ray: { name: 'Ray · research librarian', k: P.outline, h: '#15151f', H: '#15151f', s: '#8d5a3b', e: '#15151f', j: '#2f7a78', c: '#f4ead2', b: '#2f7a78', p: '#1e2c44' },
    kai: { name: 'Kai · workshop engineer', k: P.outline, h: '#6b3a22', H: '#6b3a22', s: '#e0b08a', e: '#1a1020', j: '#6f7482', c: '#3a3f4c', b: '#f8ba77', p: '#2d3a5c' },
    casey: { name: 'Casey · resource and cost adviser', k: P.outline, h: '#a8472a', H: '#a8472a', s: '#f0c9a5', e: '#1a1020', j: '#6b3d7a', c: '#f5d9a8', b: '#6b3d7a', p: '#22283d' },
    conductor: { name: 'Tram conductor', k: P.outline, h: '#1c2e5c', H: '#f8ba77', s: '#c98d64', e: '#1a1020', j: '#1c2e5c', c: '#c81c2b', b: '#f8ba77', p: '#1c2e5c' }
  };

  function spriteCanvas(rows, pal, flip) {
    const c = document.createElement('canvas');
    c.width = 12; c.height = 16;
    const x = c.getContext('2d');
    rows.forEach((row, r) => {
      for (let i = 0; i < 12; i++) {
        const ch = row[flip ? 11 - i : i];
        if (ch === '.' || !pal[ch]) continue;
        x.fillStyle = pal[ch];
        x.fillRect(i, r, 1, 1);
      }
    });
    return c;
  }
  const spriteCache = {};
  function sprite(who, dir, frame) {
    const key = `${who}-${dir}-${frame}`;
    if (spriteCache[key]) return spriteCache[key];
    const base = dir === 'left' ? 'right' : dir;
    const rows = TPL[base].slice();
    if (frame) { const w = WALK[base][frame - 1]; rows[14] = w[0]; rows[15] = w[1]; }
    return (spriteCache[key] = spriteCanvas(rows, PEOPLE[who], dir === 'left'));
  }

  // ---------- Dialogue content ----------
  const sheetList = S.sheets.map((s) => `${s.title} (${s.revision})`).join(', ');
  const npcs = [
    { id: 'olivia', who: 'olivia', x: 7, y: 7, dir: 'right', core: 'status', title: 'Status of this study',
      pages: [
        'Welcome to the district! I\'m Olivia. Each of us here holds one part of this study. I keep the paperwork.',
        `The review so far, word for word: "${S.review_summary}"`,
        `Selected sheets: ${sheetList}. Selection is not approval.`,
        A.conceptNote
      ] },
    { id: 'a1', who: 'a1', x: 27, y: 15, dir: 'down', core: 'project', title: 'Agentnagar',
      pages: [
        'Hello! I\'m City Agent A1, the guide who turns up in every style study, leaf badge and all.',
        `${A.name}: ${A.tagline}`,
        A.summary[0],
        A.summary[1],
        `${A.status}`
      ] },
    { id: 'ray', who: 'ray', x: 32, y: 13, dir: 'left', core: 'style', title: 'The style',
      pages: [
        'Ray, research librarian (a proposed Guild role). The pixel art style file is on this shelf.',
        C.intent,
        'House rules: ' + C.principles.slice(0, 3).join(' '),
        `Palette: ${C.palette.map((p) => p.name).join(', ')}.`,
        C.type
      ] },
    { id: 'conductor', who: 'conductor', x: 26, y: 19, dir: 'down', core: 'views', title: 'One district, four views',
      pages: [
        'All aboard! This line runs one district through four concept sheets.',
        `The sheets: ${S.sheets.map((s) => s.title).join(', ')}.`,
        'Every sheet shows the same places: the River on the west edge, the low North bridge, the Workshop, Tree Square, the Library, and this tram boulevard south of the square.',
        'They are concept studies, not game captures. The game you are walking is a sketch drawn for this page.'
      ] },
    { id: 'kai', who: 'kai', x: 17, y: 12, dir: 'left', core: 'agents', title: 'Agents in this style',
      pages: [
        'Kai here, from the Workshop (proposed role: workshop engineer). You want to know how agents look in pixels?',
        'On the sheets, City Agent A1 has white hair with blue streaks, a blue scarf, a dark jacket and a leaf badge. The robot on our bench is a separate helper, not A1.',
        `The Guild is ${A.guild.length} residents. The sheets don't draw us, so my sprite is a placeholder. ${A.guildNote}`
      ] },
    { id: 'casey', who: 'casey', x: 11, y: 17, dir: 'right', core: 'tradeoffs', title: 'Strengths and trade-offs',
      pages: [
        'Casey, resource and cost adviser (proposed). I keep a candid ledger for this style.',
        C.tradeoffs[0].text,
        C.tradeoffs[1].text,
        C.tradeoffs[2].text
      ] },
    { id: 'sign', who: null, x: 44, y: 7, dir: 'down', core: 'nav', title: 'More styles',
      pages: [
        { text: `The signpost points to the other style studies. West: ${Kit.style(S.prev).name}. East: ${Kit.style(S.next).name}.`, nav: true }
      ] }
  ];
  npcs.forEach((n) => { solid[idx(n.x, n.y)] = 1; });

  // ---------- Canvas setup ----------
  const canvas = document.getElementById('world');
  const ctx = canvas.getContext('2d');
  const screen = document.getElementById('screen');
  const world = document.createElement('canvas');
  world.width = W * T; world.height = H * T;
  const canopy = document.createElement('canvas');
  canopy.width = 112; canopy.height = 104;
  let viewW = 320, viewH = 192, scale = 3;

  function resize() {
    const shell = screen.parentElement.parentElement;
    const cs = getComputedStyle(shell);
    const avail = Math.min(shell.clientWidth - parseFloat(cs.paddingLeft) - parseFloat(cs.paddingRight) - 18, 1100);
    scale = Math.max(2, Math.min(3, Math.floor(avail / 330)));
    viewW = Math.floor(avail / scale);
    viewH = Math.max(160, Math.min(Math.floor((window.innerHeight * 0.62) / scale), 13 * T));
    canvas.width = viewW; canvas.height = viewH;
    canvas.style.width = `${viewW * scale}px`;
    canvas.style.height = `${viewH * scale}px`;
    ctx.imageSmoothingEnabled = false;
    draw(performance.now());
  }

  // ---------- World painting ----------
  function rect(c, x, y, w, h, col) { c.fillStyle = col; c.fillRect(x, y, w, h); }
  function dither(c, x, y, w, h, a, b) {
    rect(c, x, y, w, h, a);
    c.fillStyle = b;
    for (let j = 0; j < h; j++) for (let i = (j % 2); i < w; i += 2) c.fillRect(x + i, y + j, 1, 1);
  }
  function paintTile(c, t, tx, ty) {
    const x = tx * T, y = ty * T, r = hash(tx, ty);
    switch (t) {
      case G: case FL:
        rect(c, x, y, T, T, P.grass);
        for (let i = 0; i < 5; i++) { const px = Math.floor(hash(tx * 7 + i, ty) * 15), py = Math.floor(hash(tx, ty * 5 + i) * 15); rect(c, x + px, y + py, 1, 2, i % 2 ? P.grass2 : P.grassDk); }
        if (t === FL) {
          rect(c, x + 1, y + 1, 14, 14, P.grassDk);
          for (let i = 0; i < 9; i++) rect(c, x + 2 + ((i * 5) % 12), y + 2 + ((i * 7) % 12), 2, 2, i % 3 ? P.flowerA : P.flowerB);
        }
        break;
      case WA:
        rect(c, x, y, T, T, P.water);
        for (let j = 0; j < 4; j++) rect(c, x + ((j * 5 + ty * 3) % 12), y + 2 + j * 4, 4, 1, P.water2);
        break;
      case PR:
        dither(c, x, y, T, T, P.stone, P.stone2);
        rect(c, x, y, 2, T, P.stone2); rect(c, x, y, 1, T, P.outline);
        break;
      case RD:
        rect(c, x, y, T, T, P.road);
        if (r > .7) rect(c, x + 4, y + 9, 2, 1, P.road2);
        break;
      case PZ:
        rect(c, x, y, T, T, (tx + ty) % 2 ? P.plaza : P.plaza2);
        rect(c, x, y + 15, T, 1, P.path2); rect(c, x + 15, y, 1, T, P.path2);
        break;
      case PA:
        rect(c, x, y, T, T, P.path);
        if (r > .5) rect(c, x + Math.floor(r * 12), y + 6, 2, 1, P.path2);
        break;
      case PF:
        dither(c, x, y, T, T, '#d7d4cb', '#c9c5ba');
        rect(c, x, y + 13, T, 3, '#f2c94c'); rect(c, x, y + 15, T, 1, P.outline);
        break;
      case TR:
        dither(c, x, y, T, T, P.ballast, P.ballast2);
        for (let i = 1; i < T; i += 4) rect(c, x + i, y + 3, 2, 10, P.sleeper);
        rect(c, x, y + 4, T, 1, P.rail); rect(c, x, y + 11, T, 1, P.rail);
        rect(c, x, y + 5, T, 1, '#9aa0b2'); rect(c, x, y + 12, T, 1, '#9aa0b2');
        break;
      case BR:
        dither(c, x, y, T, T, P.stone, '#bfb7a3');
        break;
    }
  }
  function roundTree(c, x, y) {
    rect(c, x + 3, y + 13, 10, 3, 'rgba(0,0,0,.25)');
    rect(c, x + 7, y + 10, 2, 5, P.trunk);
    const rows = ['....kkkk....', '..kk3344kk..', '.k22334443k.', 'k2222334443k', 'k1222233344k', 'k1122223334k', '.k11222233k.', '..kk1122kk..', '....kkkk....'];
    const map = { k: P.outline, 1: P.leaf1, 2: P.leaf2, 3: P.leaf3, 4: P.leaf4 };
    rows.forEach((row, j) => { for (let i = 0; i < 12; i++) { const ch = row[i]; if (ch !== '.') rect(c, x + 2 + i, y + 1 + j, 1, 1, map[ch]); } });
  }
  function palm(c, x, y) {
    rect(c, x + 7, y + 5, 2, 10, P.trunk); rect(c, x + 7, y + 7, 2, 1, P.trunk2); rect(c, x + 7, y + 11, 2, 1, P.trunk2);
    const f = [[0, 4, 7, 2], [9, 4, 7, 2], [2, 2, 5, 2], [9, 2, 5, 2], [5, 0, 6, 3], [1, 6, 3, 2], [12, 6, 3, 2]];
    f.forEach(([a, b, w, h]) => rect(c, x + a, y + b, w, h, P.leaf2));
    rect(c, x + 6, y + 3, 4, 2, P.leaf4);
  }
  function lamp(c, x, y) {
    rect(c, x + 7, y + 5, 2, 10, '#2b2f3f'); rect(c, x + 5, y + 14, 6, 2, '#2b2f3f');
    rect(c, x + 5, y + 1, 6, 5, '#2b2f3f'); rect(c, x + 6, y + 2, 4, 3, P.amber);
  }
  function bench(c, x, y) {
    rect(c, x + 1, y + 6, 14, 3, '#8a5a36'); rect(c, x + 1, y + 10, 14, 2, '#8a5a36');
    rect(c, x + 2, y + 12, 2, 3, '#3a2a20'); rect(c, x + 12, y + 12, 2, 3, '#3a2a20');
    rect(c, x + 1, y + 9, 14, 1, '#5b3a22');
  }
  function outlineRect(c, x, y, w, h, fill) { rect(c, x, y, w, h, P.outline); rect(c, x + 1, y + 1, w - 2, h - 2, fill); }
  function label(c, text, cx, cy) {
    c.font = '8px "Press Start 2P", monospace';
    const w = Math.ceil(c.measureText(text).width) + 8;
    const x = Math.round(cx - w / 2), y = Math.round(cy);
    rect(c, x - 1, y - 1, w + 2, 14, P.white);
    rect(c, x, y, w, 12, P.navy);
    c.fillStyle = P.white; c.textBaseline = 'top';
    c.fillText(text, x + 4, y + 2);
  }
  function tower(c, b) {
    const x = b.x * T, y = b.y * T, w = b.w * T, h = b.h * T;
    outlineRect(c, x, y, w, h - 18, '#c8ccd6');
    rect(c, x + 3, y + 3, w - 6, h - 26, '#aeb4c2');
    dither(c, x + 5, y + 5, 26, 18, P.leaf2, P.leaf3);
    for (let i = 0; i < 3; i++) outlineRect(c, x + 36 + i * 18, y + 5, 16, 22, P.glass2), rect(c, x + 38 + i * 18, y + 7, 12, 1, P.glass);
    dither(c, x + 5, y + 26, 28, 10, P.leaf2, P.leaf4);
    // glass façade
    outlineRect(c, x, y + h - 19, w, 19, P.glass2);
    for (let i = 3; i < w - 4; i += 6) { rect(c, x + i, y + h - 16, 4, 5, hash(i, b.x) > .55 ? P.amber : P.glass); rect(c, x + i, y + h - 9, 4, 5, hash(b.x, i) > .6 ? P.amber : P.glass); }
  }
  function house(c, b) {
    const x = b.x * T, y = b.y * T, w = b.w * T, h = b.h * T;
    const roof = hash(b.x, b.y) > .5 ? [P.roofPeach, P.roofPeach2] : ['#b9a38a', '#9a8670'];
    outlineRect(c, x, y, w, h - 16, roof[0]);
    rect(c, x + 1, y + Math.floor((h - 16) / 2), w - 2, 1, roof[1]);
    for (let i = x + 4; i < x + w - 4; i += 8) rect(c, i, y + 2, 1, h - 20, roof[1]);
    if (hash(b.y, b.x) > .4) dither(c, x + 6, y + 5, 14, 10, P.leaf2, P.leaf4);
    outlineRect(c, x, y + h - 17, w, 17, '#e9d6b4');
    for (let i = x + 5; i < x + w - 8; i += 11) outlineRect(c, i, y + h - 13, 6, 7, hash(i, y) > .5 ? P.amber : P.glass2);
    outlineRect(c, x + w - 10, y + h - 12, 6, 12, '#6b4428');
  }
  function workshop(c, b) {
    const x = b.x * T, y = b.y * T, w = b.w * T, h = b.h * T;
    const roofH = h - 30;
    // three sawtooth bays: slope planes with glazing strips
    for (let i = 0; i < 3; i++) {
      const bx = x + i * (w / 3);
      outlineRect(c, bx, y, w / 3, roofH, P.slate);
      for (let j = 0; j < roofH - 12; j += 3) rect(c, bx + 1, y + 11 + j, w / 3 - 2, 1, j % 6 ? P.slate2 : P.slate3);
      rect(c, bx + 1, y + 1, w / 3 - 2, 9, P.glass2);
      for (let k = 3; k < w / 3 - 2; k += 6) rect(c, bx + k, y + 2, 3, 7, P.glass);
      rect(c, bx + 1, y + 10, w / 3 - 2, 1, P.outline);
      // small solar strip
      for (let k = 6; k < w / 3 - 8; k += 9) outlineRect(c, bx + k, y + 20, 8, 12, '#2c4f8f');
    }
    // brick façade (south) and east wall with the entrance
    outlineRect(c, x, y + roofH, w, 30, P.brick);
    for (let j = y + roofH + 3; j < y + h - 2; j += 4) for (let i = x + ((j / 4) % 2 ? 2 : 5); i < x + w - 3; i += 7) rect(c, i, j, 4, 1, P.brick2);
    for (let i = x + 8; i < x + w - 20; i += 18) { outlineRect(c, i, y + roofH + 8, 12, 14, P.amber); rect(c, i + 6, y + roofH + 8, 1, 14, P.amber2); rect(c, i + 1, y + roofH + 15, 10, 1, P.amber2); }
    outlineRect(c, x + w - 10, y + roofH + 4, 10, 26, P.brickHi);
    rect(c, x + w - 8, y + roofH + 10, 7, 20, '#3a2230'); rect(c, x + w - 7, y + roofH + 11, 5, 18, P.amber);
  }
  function library(c, b) {
    const x = b.x * T, y = b.y * T, w = b.w * T, h = b.h * T;
    const roofH = h - 44;
    // broad base and rounded reading-room roof
    outlineRect(c, x, y + 6, w, roofH, '#d9cdb0');
    const cx = x + w / 2, cy = y + 6 + roofH / 2, rx = w / 2 - 10, ry = roofH / 2 - 2;
    for (let j = -ry; j <= ry; j++) {
      const half = Math.floor(rx * Math.sqrt(1 - (j * j) / (ry * ry)));
      rect(c, cx - half - 1, cy + j, half * 2 + 2, 1, P.outline);
      rect(c, cx - half, cy + j, half * 2, 1, j < -ry / 3 ? '#4a5a86' : j < ry / 3 ? '#3a4870' : '#2c3858');
    }
    for (let k = -3; k <= 3; k++) { for (let j = -ry + 3; j <= ry - 3; j += 1) { const half = Math.floor(rx * Math.sqrt(1 - (j * j) / (ry * ry))); rect(c, Math.round(cx + (k / 3.6) * half), cy + j, 1, 1, '#66779f'); } }
    rect(c, cx - 5, cy - ry + 4, 10, 3, P.glass);
    // two-storey cream façade
    outlineRect(c, x, y + h - 44, w, 44, P.cream);
    rect(c, x + 1, y + h - 23, w - 2, 2, P.cream2);
    for (let i = x + 10; i < x + w - 12; i += 14) { outlineRect(c, i, y + h - 40, 8, 12, P.amber); outlineRect(c, i, y + h - 19, 8, 14, P.amber); }
    // banners and the west entrance
    [x + 4, x + w - 8].forEach((bx) => { rect(c, bx, y + h - 42, 4, 16, P.banner); rect(c, bx + 1, y + h - 38, 2, 2, P.white); });
    outlineRect(c, x - 1, y + h - 22, 10, 22, '#6a5436'); rect(c, x + 1, y + h - 20, 6, 20, P.amber);
  }
  function bridgeDetail(c) {
    // rails along the deck and the three arches of the low crossing
    rect(c, 0, 5 * T, 4 * T, 2, '#8a826f'); rect(c, 0, 7 * T - 2, 4 * T, 2, '#8a826f');
    for (let i = 0; i < 4 * T; i += 4) { rect(c, i, 5 * T + 2, 1, 1, P.outline); rect(c, i, 7 * T - 3, 1, 1, P.outline); }
    const span = (4 * T) / 3;
    for (let s = 0; s < 3; s++) {
      const x0 = Math.round(s * span);
      rect(c, x0, 7 * T, Math.round(span), 5, P.stone2);
      for (let i = 2; i < span - 2; i++) { const d = Math.round(4 * Math.sin((i / span) * Math.PI)); rect(c, x0 + i, 7 * T + 5 - d, 1, d + 1, '#0b4f80'); }
      rect(c, x0, 7 * T, 2, 7, P.stone);
    }
    rect(c, 0, 5 * T - 4, 4 * T, 4, 'rgba(0,0,0,.18)');
  }
  function platformDetail(c) {
    const x = 24 * T, y = 19 * T;
    outlineRect(c, x, y - 2, 5 * T, 7, '#3a4468'); rect(c, x + 2, y - 1, 5 * T - 4, 2, '#56a6fd');
    rect(c, x + 6, y + 5, 2, 8, '#2b2f3f'); rect(c, x + 5 * T - 8, y + 5, 2, 8, '#2b2f3f');
  }
  function paintCanopy() {
    const c = canopy.getContext('2d');
    c.clearRect(0, 0, canopy.width, canopy.height);
    const blobs = [[56, 52, 46, P.outline], [56, 52, 45, P.leaf1], [50, 46, 38, P.leaf2], [44, 40, 26, P.leaf3], [38, 32, 12, P.leaf4], [72, 34, 10, P.leaf3], [30, 62, 12, P.leaf2], [76, 64, 14, P.leaf1]];
    blobs.forEach(([cx, cy, r, col], n) => {
      for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
        const d = x * x + y * y;
        if (d > r * r) continue;
        // leaf-cluster edge: skip scattered edge pixels for a clumpy outline
        if (n > 0 && d > (r - 3) * (r - 3) && hash(x + cx, y + cy) > .55) continue;
        if (n > 1 && ((x + y) & 1) && d > (r * .7) * (r * .7)) continue;
        c.fillStyle = col; c.fillRect(cx + x, cy + y, 1, 1);
      }
    });
    for (let i = 0; i < 70; i++) { c.fillStyle = hash(i, 3) > .5 ? P.leaf4 : P.leaf1; c.fillRect(14 + Math.floor(hash(i, 9) * 84), 10 + Math.floor(hash(9, i) * 80), 2, 1); }
  }
  function paintWorld() {
    const c = world.getContext('2d');
    c.imageSmoothingEnabled = false;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) paintTile(c, tile[idx(x, y)], x, y);
    // road markings
    for (let x = 5 * T; x < 45 * T; x += 12) rect(c, x, 6 * T - 1, 6, 2, P.line);
    for (let y = 0; y < H * T; y += 12) if (y < 5 * T || y > 7 * T) rect(c, 46 * T - 1, y, 2, 6, P.line);
    for (let i = 0; i < 5; i++) rect(c, 44 * T + 2, 5 * T + 3 + i * 6, 12, 3, P.line);
    bridgeDetail(c);
    // tree trunk and roots under the canopy
    rect(c, 24 * T + 4, 12 * T, 2 * T + 8, 2 * T, 'rgba(0,0,0,.18)');
    outlineRect(c, 25 * T + 4, 11 * T + 6, 24, 26, P.trunk);
    rect(c, 25 * T + 10, 11 * T + 8, 3, 22, P.trunk2); rect(c, 25 * T + 20, 11 * T + 10, 2, 20, P.trunk2);
    dither(c, 23 * T, 14 * T + 2, 5 * T, 4, P.leaf2, P.plaza2);
    buildings.forEach((b) => ({ tower, house, workshop, library })[b.kind](c, b));
    platformDetail(c);
    trees.forEach((t) => (t.kind === 'palm' ? palm : roundTree)(c, t.x * T, t.y * T));
    lamps.forEach(([x, y]) => lamp(c, x * T, y * T));
    benches.forEach(([x, y]) => bench(c, x * T, y * T));
    // signpost
    const sx = 44 * T, sy = 7 * T;
    rect(c, sx + 7, sy + 4, 2, 12, '#5b3a22'); outlineRect(c, sx + 1, sy + 1, 14, 6, '#c08a52'); rect(c, sx + 12, sy + 2, 3, 4, '#c08a52');
    label(c, 'NORTH BRIDGE', 56, 7 * T + 9);
    label(c, 'WORKSHOP', 11.5 * T, 15 * T + 4);
    label(c, 'TREE SQUARE', 26 * T, 9 * T - 6);
    label(c, 'LIBRARY', 38 * T, 16 * T + 2);
    label(c, 'PARK', 8 * T, 18 * T + 2);
    label(c, 'TRAM STOP', 26.5 * T, 22 * T + 2);
    paintCanopy();
  }

  // ---------- State ----------
  const player = { x: 8, y: 7, fx: 8, fy: 7, t: 1, dir: 'left', step: 0, moving: false };
  const held = [];
  let path = [], pathTarget = null;
  const found = new Set();
  let dialog = null;
  const tram = { x: RM ? 23 * T : W * T + 40, state: RM ? 'parked' : 'run', wait: 0 };

  const npcAt = (x, y) => npcs.find((n) => n.x === x && n.y === y);
  const walkable = (x, y) => x >= 0 && y >= 0 && x < W && y < H && !solid[idx(x, y)];
  const DIRS = { up: [0, -1], down: [0, 1], left: [-1, 0], right: [1, 0] };

  function tryStep(dir) {
    player.dir = dir;
    const [dx, dy] = DIRS[dir];
    const nx = player.x + dx, ny = player.y + dy;
    if (!walkable(nx, ny)) return false;
    player.fx = player.x; player.fy = player.y;
    player.x = nx; player.y = ny; player.t = 0; player.moving = true;
    return true;
  }

  function findPath(tx, ty) {
    const start = idx(player.x, player.y);
    const prev = new Int32Array(W * H).fill(-1);
    prev[start] = start;
    const q = [start];
    const goals = new Set();
    if (walkable(tx, ty)) goals.add(idx(tx, ty));
    else [[0, 1], [0, -1], [1, 0], [-1, 0]].forEach(([dx, dy]) => { if (walkable(tx + dx, ty + dy) || (tx + dx === player.x && ty + dy === player.y)) goals.add(idx(tx + dx, ty + dy)); });
    if (goals.has(start)) return [];
    while (q.length) {
      const cur = q.shift();
      if (goals.has(cur)) {
        const out = [];
        for (let n = cur; n !== start; n = prev[n]) out.unshift(n);
        return out.map((n) => [n % W, Math.floor(n / W)]);
      }
      const cx = cur % W, cy = Math.floor(cur / W);
      for (const [dx, dy] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) {
        const nx = cx + dx, ny = cy + dy;
        if (!walkable(nx, ny)) continue;
        const n = idx(nx, ny);
        if (prev[n] !== -1) continue;
        prev[n] = cur; q.push(n);
      }
    }
    return null;
  }

  function facing() { const [dx, dy] = DIRS[player.dir]; return npcAt(player.x + dx, player.y + dy); }
  function adjacentNpc() {
    const f = facing();
    if (f) return f;
    for (const [dx, dy] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) { const n = npcAt(player.x + dx, player.y + dy); if (n) return n; }
    return null;
  }
  function faceToward(n) {
    const dx = n.x - player.x, dy = n.y - player.y;
    player.dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up');
    if (n.who) n.face = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'left' : 'right') : (dy > 0 ? 'up' : 'down');
  }

  // ---------- Dialog ----------
  const dlg = document.getElementById('dlg');
  const dlgName = document.getElementById('dlg-name');
  const dlgText = document.getElementById('dlg-text');
  const dlgActions = document.getElementById('dlg-actions');
  const dlgFace = document.getElementById('dlg-face');
  let typing = null;

  function drawFace(canvasEl, who) {
    const c = canvasEl.getContext('2d');
    c.imageSmoothingEnabled = false;
    c.clearRect(0, 0, canvasEl.width, canvasEl.height);
    const k = canvasEl.width / 48;
    if (!who) {
      c.fillStyle = '#5b3a22'; c.fillRect(21 * k, 16 * k, 6 * k, 30 * k);
      c.fillStyle = '#c08a52'; c.fillRect(6 * k, 8 * k, 32 * k, 12 * k); c.fillRect(38 * k, 10 * k, 6 * k, 8 * k);
      c.fillStyle = '#0b1426'; c.fillRect(10 * k, 13 * k, 20 * k, 2 * k);
      return;
    }
    const sp = sprite(who, 'down', 0);
    c.drawImage(sp, 0, 0, 12, 12, 6 * k, 6 * k, 36 * k, 36 * k);
    c.drawImage(sp, 0, 12, 12, 4, 6 * k, 42 * k, 36 * k, 12 * k);
  }

  function openDialog(n) {
    dialog = { n, i: 0 };
    path = []; pathTarget = null;
    faceToward(n);
    found.add(n.core);
    updateFound();
    dlgName.textContent = n.who ? PEOPLE[n.who].name : n.title;
    drawFace(dlgFace, n.who);
    dlg.classList.add('open');
    showPage();
  }
  function closeDialog() {
    if (!dialog) return;
    const n = dialog.n;
    dialog = null;
    if (typing) { clearInterval(typing); typing = null; }
    dlg.classList.remove('open');
    if (n) n.face = null;
    screen.focus({ preventScroll: true });
  }
  function showPage() {
    const n = dialog.n, page = n.pages[dialog.i];
    const text = typeof page === 'string' ? page : page.text;
    const last = dialog.i === n.pages.length - 1;
    dlgActions.replaceChildren();
    if (typing) clearInterval(typing);
    if (RM) { dlgText.textContent = text; typing = null; }
    else {
      let k = 0;
      dlgText.textContent = '';
      typing = setInterval(() => {
        k += 3;
        dlgText.textContent = text.slice(0, k);
        if (k >= text.length) { clearInterval(typing); typing = null; }
      }, 16);
      dlgText.dataset.full = text;
    }
    if (page.nav) {
      const nl = Kit.navLinks(S);
      dlgActions.append(
        el('a', { class: 'btn', href: nl.prev, text: `◀ ${nl.prevName}` }),
        el('a', { class: 'btn', href: nl.index, text: 'All 30' }),
        el('a', { class: 'btn', href: nl.next, text: `${nl.nextName} ▶` })
      );
    }
    let primary;
    if (!last) {
      primary = el('button', { class: 'btn', type: 'button', text: `Next ▶ ${dialog.i + 1}/${n.pages.length}` });
      primary.addEventListener('click', advance);
      dlgActions.append(primary);
    } else if (!page.nav) {
      primary = el('a', { class: 'btn', href: `#codex-${n.core}`, text: 'Read the full entry ↓' });
      primary.addEventListener('click', () => { closeDialog(); });
      dlgActions.append(primary);
    }
    const close = el('button', { class: 'btn ghost', type: 'button', text: 'Close ✕' });
    close.addEventListener('click', closeDialog);
    dlgActions.append(close);
    (primary || dlgActions.querySelector('a, button')).focus({ preventScroll: true });
  }
  function advance() {
    if (!dialog) return;
    if (typing) { clearInterval(typing); typing = null; dlgText.textContent = dlgText.dataset.full; return; }
    if (dialog.i < dialog.n.pages.length - 1) { dialog.i++; showPage(); }
  }
  dlg.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') { e.preventDefault(); closeDialog(); }
    else if ((e.key === 'e' || e.key === 'E') && dialog) { e.preventDefault(); advance(); }
  });

  function interact() {
    if (dialog) { advance(); return; }
    const n = adjacentNpc();
    if (n) openDialog(n);
  }

  // ---------- Input ----------
  const KEYMAP = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right', w: 'up', s: 'down', a: 'left', d: 'right', W: 'up', S: 'down', A: 'left', D: 'right' };
  screen.addEventListener('keydown', (e) => {
    if (e.target !== screen) return;
    const dir = KEYMAP[e.key];
    if (dir) { e.preventDefault(); if (!held.includes(dir)) held.push(dir); path = []; return; }
    if (e.key === 'e' || e.key === 'E' || e.key === 'Enter' || e.key === ' ') { e.preventDefault(); interact(); }
    if (e.key === 'Escape') closeDialog();
  });
  window.addEventListener('keyup', (e) => { const dir = KEYMAP[e.key]; if (dir) { const i = held.indexOf(dir); if (i >= 0) held.splice(i, 1); } });
  screen.addEventListener('blur', () => { held.length = 0; });

  canvas.addEventListener('pointerdown', (e) => {
    if (dialog) return;
    screen.focus({ preventScroll: true });
    const r = canvas.getBoundingClientRect();
    const wx = Math.floor(((e.clientX - r.left) / scale + cam.x) / T);
    const wy = Math.floor(((e.clientY - r.top) / scale + cam.y) / T);
    const n = npcAt(wx, wy);
    const route = findPath(wx, wy);
    if (route) { path = route; pathTarget = n || null; if (!route.length && n) openDialog(n); }
  });

  document.querySelectorAll('.dpad button').forEach((b) => {
    const dir = b.dataset.dir;
    const release = () => { b.classList.remove('held'); const i = held.indexOf(dir); if (i >= 0) held.splice(i, 1); };
    b.addEventListener('pointerdown', (e) => { e.preventDefault(); if (dialog) return; b.setPointerCapture(e.pointerId); b.classList.add('held'); path = []; if (!held.includes(dir)) held.push(dir); });
    b.addEventListener('pointerup', release);
    b.addEventListener('pointercancel', release);
    b.addEventListener('lostpointercapture', release);
    b.addEventListener('click', (e) => { if (e.detail === 0 && !dialog && !player.moving) tryStep(dir); });
  });
  document.getElementById('btn-a').addEventListener('click', interact);
  document.getElementById('btn-b').addEventListener('click', closeDialog);

  // Direct talk list: keyboard and screen-reader route to every section.
  const travel = document.getElementById('travel');
  npcs.forEach((n) => {
    const who = n.who ? PEOPLE[n.who].name.split(' · ')[0] : 'Signpost';
    const b = el('button', { type: 'button', 'data-core-link': n.core, text: `${who}: ${n.title}` });
    b.addEventListener('click', () => {
      // step the visitor next to them, then talk
      const spots = [[0, 1], [0, -1], [-1, 0], [1, 0]].map(([dx, dy]) => [n.x + dx, n.y + dy]).filter(([x, y]) => walkable(x, y));
      if (spots.length) { player.x = player.fx = spots[0][0]; player.y = player.fy = spots[0][1]; player.t = 1; player.moving = false; }
      screen.scrollIntoView({ block: 'nearest', behavior: RM ? 'auto' : 'smooth' });
      openDialog(n);
    });
    travel.append(b);
  });

  function updateFound() {
    document.getElementById('found').textContent = `★ ${found.size}/7`;
    travel.querySelectorAll('button').forEach((b) => b.classList.toggle('done', found.has(b.dataset.coreLink)));
    document.querySelectorAll('.entry').forEach((e) => e.classList.toggle('found', found.has(e.dataset.core)));
  }

  // ---------- Loop ----------
  const cam = { x: 0, y: 0 };
  const PLACES = [
    [(x, y) => x <= 3 && (y === 5 || y === 6), 'NORTH BRIDGE'], [(x) => x <= 4, 'RIVER'],
    [(x, y) => y >= 20 && y <= 21, 'TRAM BOULEVARD'], [(x, y) => y === 19 && x >= 19 && x <= 32, 'TRAM STOP'],
    [(x, y) => x >= 19 && x <= 32 && y >= 8 && y <= 18, 'TREE SQUARE'], [(x, y) => x >= 5 && x <= 18 && y >= 8 && y <= 15, 'WORKSHOP'],
    [(x, y) => x >= 5 && x <= 18 && y >= 16 && y <= 19, 'PARK'], [(x, y) => x >= 33 && x <= 44 && y >= 8 && y <= 19, 'LIBRARY'],
    [(x, y) => y <= 4, 'TOWER ROW'], [(x, y) => y <= 7, 'NORTH ROAD'], [(x, y) => y >= 22, 'HOMES'], [() => true, 'EAST ROAD']
  ];
  const placeEl = document.getElementById('place');
  let lastPlace = '';
  let last = performance.now();

  function update(dt, now) {
    if (player.moving) {
      player.t += dt * 6;
      if (player.t >= 1) { player.t = 1; player.moving = false; player.step++; }
    }
    if (!player.moving && !dialog) {
      if (path.length) {
        const [nx, ny] = path[0];
        const dir = nx > player.x ? 'right' : nx < player.x ? 'left' : ny > player.y ? 'down' : 'up';
        if (tryStep(dir)) path.shift(); else path = [];
        if (!path.length && pathTarget && !player.moving) { openDialog(pathTarget); pathTarget = null; }
      } else if (pathTarget) {
        openDialog(pathTarget); pathTarget = null;
      } else if (held.length) {
        tryStep(held[held.length - 1]);
      }
    }
    const place = PLACES.find(([f]) => f(player.x, player.y))[1];
    if (place !== lastPlace) { placeEl.textContent = place; lastPlace = place; }
    // tram: runs east to west, pauses at the stop south of the square
    if (tram.state === 'run') {
      const before = tram.x;
      tram.x -= dt * 42;
      if (before > 23 * T && tram.x <= 23 * T) { tram.x = 23 * T; tram.state = 'wait'; tram.wait = now + 3200; }
      if (tram.x < -10 * T) tram.x = W * T + 60;
    } else if (tram.state === 'wait' && now > tram.wait) tram.state = 'run';
  }

  function drawTram(c) {
    const y = 20 * T - 5 - cam.y;
    for (let car = 0; car < 2; car++) {
      const x = Math.round(tram.x + car * 66 - cam.x);
      rect(c, x + 2, y + 17, 62, 3, 'rgba(0,0,0,.3)');
      rect(c, x, y, 64, 18, P.outline);
      rect(c, x + 1, y + 1, 62, 9, P.cream);
      rect(c, x + 1, y + 3, 62, 1, P.cream2);
      rect(c, x + 1, y + 10, 62, 7, P.cream);
      rect(c, x + 1, y + 14, 62, 2, P.coral);
      for (let i = 4; i < 60; i += 8) rect(c, x + i, y + 10, 6, 4, i === 28 ? '#3a2230' : P.glass2);
      if (car === 0) { rect(c, x + 1, y + 1, 4, 16, P.coral); rect(c, x + 1, y + 9, 3, 3, P.amber); }
    }
  }

  function drawPerson(c, who, x, y, dir, frame, bob) {
    const px = Math.round(x - cam.x + 2), py = Math.round(y - cam.y - 3 - bob);
    rect(c, px + 1, Math.round(y - cam.y) + 12, 10, 3, 'rgba(0,0,0,.28)');
    c.drawImage(sprite(who, dir, frame), px, py);
  }

  function draw(now) {
    if (!canvas.width) return;
    const ppx = (player.fx + (player.x - player.fx) * player.t) * T;
    const ppy = (player.fy + (player.y - player.fy) * player.t) * T;
    cam.x = Math.round(Math.max(0, Math.min(W * T - viewW, ppx + 8 - viewW / 2)));
    cam.y = Math.round(Math.max(0, Math.min(H * T - viewH, ppy + 8 - viewH / 2)));
    ctx.fillStyle = '#000'; ctx.fillRect(0, 0, viewW, viewH);
    ctx.drawImage(world, cam.x, cam.y, viewW, viewH, 0, 0, viewW, viewH);
    if (!RM) {
      const f = Math.floor(now / 380);
      for (let ty = Math.floor(cam.y / T); ty <= Math.min(H - 1, Math.floor((cam.y + viewH) / T)); ty++) {
        if (ty === 5 || ty === 6) continue;
        for (let tx = 0; tx < 4; tx++) {
          const o = (f + tx * 3 + ty * 5) % 8;
          rect(ctx, tx * T + (o * 2) % 14 - cam.x, ty * T + 3 + (o % 3) * 4 - cam.y, 3, 1, P.waterHi);
          if (o === 2) rect(ctx, tx * T + 9 - cam.x, ty * T + 12 - cam.y, 2, 1, P.foam);
        }
      }
    }
    drawTram(ctx);
    const actors = npcs.filter((n) => n.who).map((n) => ({ y: n.y * T, fn: () => {
      const bob = RM ? 0 : (Math.floor(now / 500 + n.x) % 2);
      drawPerson(ctx, n.who, n.x * T, n.y * T, n.face || n.dir, 0, bob);
      if (!found.has(n.core) && !dialog) {
        const bx = n.x * T - cam.x + 6, by = n.y * T - cam.y - 14 - (RM ? 0 : Math.floor(now / 300) % 2);
        rect(ctx, bx - 1, by - 1, 6, 10, P.outline); rect(ctx, bx, by, 4, 5, P.amber); rect(ctx, bx, by + 6, 4, 2, P.amber);
      }
    } }));
    const frame = player.moving ? (player.step % 2) + 1 : 0;
    actors.push({ y: ppy, fn: () => drawPerson(ctx, 'you', ppx, ppy, player.dir, frame, 0) });
    actors.sort((a, b) => a.y - b.y).forEach((a) => a.fn());
    // sign bubble
    if (!found.has('nav') && !dialog) { const bx = 44 * T - cam.x + 6, by = 7 * T - cam.y - 12; rect(ctx, bx - 1, by - 1, 6, 10, P.outline); rect(ctx, bx, by, 4, 5, P.amber); rect(ctx, bx, by + 6, 4, 2, P.amber); }
    // canopy above walkers; see-through when the visitor stands beneath
    const under = Math.hypot(ppx + 8 - CANOPY.cx, ppy + 8 - CANOPY.cy) < CANOPY.r;
    ctx.globalAlpha = under ? 0.45 : 1;
    ctx.drawImage(canopy, Math.round(CANOPY.cx - 56 - cam.x), Math.round(CANOPY.cy - 52 - cam.y));
    ctx.globalAlpha = 1;
    // talk prompt
    const near = !dialog && adjacentNpc();
    if (near) {
      const bx = Math.round(ppx - cam.x + 3), by = Math.round(ppy - cam.y - 16);
      rect(ctx, bx - 1, by - 1, 12, 11, P.outline); rect(ctx, bx, by, 10, 9, P.tramRed);
      ctx.font = '8px "Press Start 2P", monospace'; ctx.fillStyle = P.white; ctx.textBaseline = 'top'; ctx.fillText('A', bx + 1, by + 1);
    }
  }

  function loop(now) {
    const dt = Math.min(0.05, (now - last) / 1000);
    last = now;
    update(dt, now);
    draw(now);
    requestAnimationFrame(loop);
  }

  // ---------- Codex (DOM, always readable) ----------
  function face(who) {
    const c = el('canvas', { width: 48, height: 48, 'aria-hidden': 'true' });
    drawFace(c, who);
    return c;
  }
  function entry(core, title, npc, children, half) {
    const n = npcs.find((m) => m.core === core);
    const who = n && n.who ? PEOPLE[n.who].name : 'Signpost by the east road';
    return el('section', { class: `entry pix${half ? ' half' : ''}`, id: `codex-${core}`, 'data-core': core, 'aria-labelledby': `h-${core}` }, [
      el('div', { class: 'entry-top' }, [face(n && n.who), el('div', {}, [el('h3', { id: `h-${core}`, text: title }), el('span', { class: 'who', text: `Told by ${who}` })])]),
      ...children
    ]);
  }
  function buildCodex() {
    const grid = document.getElementById('codex-grid');
    const project = Kit.projectBlock();
    project.removeAttribute('data-core');

    const style = [
      el('p', { text: C.intent }),
      el('h4', { text: 'PRINCIPLES' }),
      el('ul', {}, C.principles.map((p) => el('li', { text: p }))),
      el('h4', { text: 'PALETTE · SAMPLED FROM THE SHEETS' }),
      el('div', { class: 'swatches' }, C.palette.map((p) => el('div', { class: 'swatch' }, [el('i', { style: `background:${p.hex}`, 'aria-hidden': 'true' }), p.name, el('code', { text: p.hex })]))),
      el('h4', { text: 'MATERIALS AND TEXTURE' }), el('p', { text: C.materials }),
      el('h4', { text: 'TYPOGRAPHY' }), el('p', { text: C.type })
    ];

    const landmarks = el('ul', { class: 'landmarks' }, A.district.map((d) => el('li', {}, [el('b', { text: d.id }), `${d.name}: ${d.note}`])));
    const sheets = el('div', { class: 'sheets' }, S.sheets.map((sh, i) => el('figure', {}, [
      Kit.sheetImg(S, i, null, { alt: `${S.name} concept study, ${sh.title} (${sh.revision}): four panels, ${Kit.PANEL_NAMES[i].join(', ')}, showing the River, North bridge, Workshop, Tree Square, Library and tram boulevard.` }),
      el('figcaption', {}, [el('b', { text: `${sh.title.toUpperCase()} · ${sh.revision}` }), `Panels: ${Kit.PANEL_NAMES[i].join(', ')}.`])
    ])));
    const views = [
      el('p', { text: 'The same reference district drawn four ways. Look for these six landmarks on every sheet:' }),
      landmarks, sheets,
      el('p', { class: 'concept', text: A.conceptNote })
    ];

    const agents = [
      el('div', { class: 'agents-grid' }, [
        el('figure', { style: 'margin:0' }, [
          Kit.sheetImg(S, 0 + 1, 'bl', { alt: `${S.name} concept study, Living community, Conversation panel: City Agent A1 with white and blue hair, blue scarf and leaf badge talks with a visitor under the trees.` }),
          el('figcaption', { class: 'kit-small', style: 'margin-top:12px', text: 'Conversation panel, Living community sheet. Concept study.' })
        ]),
        el('div', {}, [el('p', { text: C.agents }), el('p', { text: A.agentA1 })])
      ]),
      el('h4', { text: `THE GUILD · ${A.guild.length} RESIDENTS` }),
      el('ul', { class: 'roster' }, A.guild.map((g, i) => el('li', {}, [
        el('i', { style: `background:${C.palette[(i % 8) + 1].hex};color:${chipInk(C.palette[(i % 8) + 1].hex)}`, 'aria-hidden': 'true', text: g.name[0] }),
        el('div', {}, [el('b', { text: g.name }), el('span', { text: g.role })])
      ]))),
      el('p', { class: 'kit-small', style: 'margin-top:14px', text: `${A.guildNote} Not depicted on the sheets.` })
    ];

    const trade = [el('dl', { class: 'trade' }, C.tradeoffs.flatMap((t) => [el('dt', { text: t.label.toUpperCase() }), el('dd', { text: t.text })]))];

    const status = Kit.statusBlock(S);
    status.removeAttribute('data-core');

    const navHolder = el('div', { class: 'nav-slot' });
    const navEl = Kit.mountNav(navHolder, S);
    navEl.removeAttribute('data-core');

    grid.append(
      entry('project', 'AGENTNAGAR', 'a1', [project], true),
      entry('style', 'THE STYLE', 'ray', style, true),
      entry('views', 'ONE DISTRICT, FOUR VIEWS', 'conductor', views),
      entry('agents', 'AGENTS IN THIS STYLE', 'kai', agents),
      entry('tradeoffs', 'STRENGTHS AND TRADE-OFFS', 'casey', trade, true),
      entry('status', 'STATUS', 'olivia', [status], true),
      entry('nav', 'MORE STYLES', 'sign', [navHolder])
    );
    // The project block uses the kit's own class for styling.
    project.classList.add('kit-project');
  }

  // ---------- Boot ----------
  buildCodex();
  document.getElementById('cart').textContent = `STYLE ${S.number} / ${window.STYLE_DATA.styles.length}`;
  Kit.notesDialog(S, C, document.getElementById('notes-btn'));
  document.getElementById('foot').textContent = `${A.name} · ${A.by}. ${A.nameNote}`;
  const start = () => { paintWorld(); resize(); window.addEventListener('resize', resize); requestAnimationFrame((t) => { last = t; loop(t); }); };
  const fontReady = document.fonts && document.fonts.load ? document.fonts.load('8px "Press Start 2P"') : Promise.resolve();
  Promise.race([fontReady, new Promise((r) => setTimeout(r, 1200))]).then(start, start);
})();
