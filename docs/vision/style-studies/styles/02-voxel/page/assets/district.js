// 02 Voxel: the playable block district (three.js, classic script, global THREE).
// Illustrative page art built from boxes; the layout follows the reference district:
// river west, north bridge, sawtooth Workshop west of Tree Square, vaulted Library east,
// tram boulevard south with a stop below the square, stepped towers north.
(function () {
  const $ = (id) => document.getElementById(id);
  const A = window.AGENTNAGAR;
  const reduced = Kit.reducedMotion();
  let motionOn = !reduced;

  const LANDMARKS = [
    { id: 'workshop', did: 'W1', label: 'Workshop', section: 'agents', sectionName: 'Agents in this style', anchor: [26.5, 7, 27.5], focus: [26.5, 0, 27.5], zoom: 2.1 },
    { id: 'square', did: 'T1', label: 'Tree Square', section: 'project', sectionName: 'Agentnagar', anchor: [40, 11, 28], focus: [40, 0, 28], zoom: 2.2 },
    { id: 'library', did: 'L1', label: 'Library', section: 'style', sectionName: 'The style', anchor: [53, 8, 28], focus: [53, 0, 28], zoom: 2.2 },
    { id: 'river', did: 'R1', label: 'River', section: 'views', sectionName: 'One district, four views', anchor: [4.5, 2, 30], focus: [5, 0, 24], zoom: 1.6 },
    { id: 'bridge', did: 'B1', label: 'North bridge', section: 'status', sectionName: 'Status', anchor: [4.5, 3, 7], focus: [6, 0, 8], zoom: 2.4 },
    { id: 'tram', did: 'S1', label: 'Tram boulevard', section: 'tradeoffs', sectionName: 'Strengths and trade-offs', anchor: [40, 4, 37], focus: [38, 0, 37], zoom: 2.0 }
  ];
  LANDMARKS.forEach((l) => { l.info = A.district.find((d) => d.id === l.did); });
  const byId = Object.fromEntries(LANDMARKS.map((l) => [l.id, l]));

  // ---------------- DOM: toolbar, counter ----------------
  const toolbar = $('toolbar');
  LANDMARKS.forEach((l) => {
    const b = Kit.el('button', { type: 'button', class: `lm-btn lm-${l.id}`, 'data-lm': l.id }, [
      Kit.el('span', { class: 'lm-dot', 'aria-hidden': 'true' }), l.label
    ]);
    b.addEventListener('click', () => select(l.id, true));
    toolbar.append(b);
  });
  const visited = new Set();
  const counterCubes = $('counter-cubes');
  function updateCounter() {
    counterCubes.innerHTML = LANDMARKS.map((l) => `<i class="${visited.has(l.id) ? 'on' : ''}"></i>`).join('');
    $('counter-text').textContent = visited.size === LANDMARKS.length
      ? 'All 6 landmarks visited'
      : `${visited.size} of 6 landmarks visited`;
  }
  updateCounter();

  // ---------------- HUD card ----------------
  function showCard(kicker, title, text, actions) {
    $('hud-card').hidden = false;
    $('hud-kicker').textContent = kicker;
    $('hud-title').textContent = title;
    $('hud-text').textContent = text;
    const act = $('hud-actions');
    act.replaceChildren(...actions);
    $('hero-card').classList.add('tucked');
    $('stage').classList.add('has-card');
  }
  function sectionLink(l) {
    const a = Kit.el('a', { class: 'btn btn-go', href: `#${l.section}`, text: `Read: ${l.sectionName} ↓` });
    a.addEventListener('click', (e) => {
      e.preventDefault();
      const target = $(l.section);
      target.scrollIntoView({ behavior: reduced ? 'auto' : 'smooth', block: 'start' });
      target.setAttribute('tabindex', '-1');
      target.focus({ preventScroll: true });
      target.classList.add('flash');
      setTimeout(() => target.classList.remove('flash'), 1400);
    });
    return a;
  }

  // ---------------- WebGL setup ----------------
  const host = $('stage-canvas');
  let renderer;
  try {
    const probe = document.createElement('canvas');
    if (!(probe.getContext('webgl2') || probe.getContext('webgl'))) throw new Error('no webgl');
    renderer = new THREE.WebGLRenderer({ antialias: true });
  } catch (e) {
    fallback();
    return;
  }
  function fallback() {
    const f = $('fallback');
    f.hidden = false;
    f.textContent = 'WebGL is not available here, so the playable district cannot run. The landmark buttons still lead to each section, and the diagonal concept view is shown instead.';
    const img = Kit.sheetImg(Kit.style('02-voxel'), 0, 'bl', { eager: true });
    img.classList.add('fallback-img');
    host.append(img);
    document.querySelectorAll('.lm-btn').forEach((b) => b.addEventListener('click', () => {
      const l = byId[b.dataset.lm];
      showCard(`${l.did} · landmark`, l.label, l.info.note, [sectionLink(l)]);
    }));
  }

  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  host.append(renderer.domElement);
  renderer.domElement.setAttribute('aria-hidden', 'true');

  const scene = new THREE.Scene();
  scene.background = new THREE.Color('#bfe3f7');

  const camera = new THREE.OrthographicCamera(-10, 10, 10, -10, -200, 400);
  const CENTER = new THREE.Vector3(33, 0, 23);
  const HOME_OFFSET = new THREE.Vector3(-34, 52, 60);
  camera.position.copy(CENTER).add(HOME_OFFSET);
  camera.lookAt(CENTER);

  const controls = new THREE.OrbitControls(camera, renderer.domElement);
  controls.target.copy(CENTER);
  controls.enableDamping = !reduced;
  controls.dampingFactor = 0.12;
  controls.minPolarAngle = 0.35;
  controls.maxPolarAngle = 1.15;
  controls.minZoom = 0.7;
  controls.maxZoom = 6;
  controls.screenSpacePanning = false;
  controls.zoomToCursor = false;
  controls.update();

  scene.add(new THREE.HemisphereLight('#fff7e8', '#8aa27a', 1.35));
  const sun = new THREE.DirectionalLight('#fff3dc', 2.1);
  sun.position.set(-30, 60, 20);
  sun.target.position.set(33, 0, 23);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  Object.assign(sun.shadow.camera, { left: -48, right: 48, top: 40, bottom: -40, near: 1, far: 160 });
  sun.shadow.bias = -0.0008;
  sun.shadow.normalBias = 0.04;
  scene.add(sun, sun.target);

  // ---------------- voxel builder ----------------
  const unit = new THREE.BoxGeometry(1, 1, 1);
  const tmpM = new THREE.Matrix4();
  const tmpC = new THREE.Color();
  function hash(x, y, z) { const s = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453; return s - Math.floor(s); }

  function Batch() { this.items = []; }
  Batch.prototype.box = function (x, y, z, sx, sy, sz, color, lm, jitter) {
    this.items.push([x, y, z, sx, sy, sz, color, lm || null, jitter == null ? 0.05 : jitter]);
  };
  Batch.prototype.build = function (opts) {
    const o = opts || {};
    const mat = o.material || new THREE.MeshLambertMaterial();
    const mesh = new THREE.InstancedMesh(unit, mat, this.items.length);
    mesh.userData.lm = [];
    this.items.forEach((it, i) => {
      const [x, y, z, sx, sy, sz, color, lm, j] = it;
      tmpM.makeScale(sx, sy, sz).setPosition(x + sx / 2, y + sy / 2, z + sz / 2);
      mesh.setMatrixAt(i, tmpM);
      tmpC.set(color);
      if (j) tmpC.offsetHSL(0, 0, (hash(x, y, z) - 0.5) * j);
      mesh.setColorAt(i, tmpC);
      mesh.userData.lm[i] = lm;
    });
    mesh.castShadow = o.cast !== false;
    mesh.receiveShadow = true;
    mesh.instanceMatrix.needsUpdate = true;
    return mesh;
  };

  const C = {
    river: '#0182e5', riverDeep: '#0a6fc8', lawn: '#50ad41', canopy: '#329f2e', canopy2: '#46b33a', trunk: '#7a4a24',
    yellow: '#efc332', yellowDark: '#d6a622', glass: '#8fc6ee', orange: '#fd8d2d', orangeDark: '#e0701a',
    road: '#6a717f', paving: '#e9e4d8', paving2: '#d9d3c6', white: '#f1eeea', blueBand: '#3f7fd6',
    stone: '#b8b4ab', rail: '#4a4f58', cream: '#f3ede0', coral: '#e69c79', navy: '#2a365c', timber: '#e2a857',
    dark: '#2f343b', skin1: '#c68a5a', skin2: '#8a5a38', hair: '#3b2616'
  };

  const W = 66, D = 46;
  const city = new Batch();
  const water = new Batch();

  // ground grid
  for (let x = 0; x < W; x++) {
    for (let z = 0; z < D; z++) {
      let col = C.lawn, y = -0.5, h = 0.5, lm = null;
      if (x < 9) { water.box(x, -0.9, z, 1, 0.6, 1, (x + z) % 5 === 0 ? C.riverDeep : C.river, 'river', 0.04); continue; }
      if (x === 9) { col = C.stone; h = 0.8; lm = 'river'; }
      else if (z >= 35 && z <= 39) { col = (z === 36 || z === 38) ? C.rail : C.road; lm = 'tram'; if (z === 35 || z === 39) col = C.paving2; }
      else if ((z === 8 || z === 9) || (z === 20 || z === 21) || x === 16 || x === 17 || x === 62 || x === 63) col = C.road;
      else if (x >= 35 && x <= 45 && z >= 22 && z <= 34) { col = (x + z) % 2 ? C.paving : C.paving2; lm = 'square'; }
      else if (z >= 22 && z <= 34 && x >= 18) col = (x + z) % 2 ? C.paving : C.paving2;
      else if (z > 39) col = (x + z) % 2 ? C.paving : C.paving2;
      city.box(x, y, z, 1, h, 1, col, lm, 0.06);
    }
  }
  // road dashes
  for (let x = 18; x < W; x += 3) { city.box(x, 0, 8.9, 1.4, 0.03, 0.2, '#f5f1e4', null, 0); city.box(x, 0, 20.9, 1.4, 0.03, 0.2, '#f5f1e4', null, 0); }

  // bridge (north): deck across the river at z 7..9, three spans
  city.box(-2, 0.4, 7.4, 12, 0.5, 2.2, '#c9c5bb', 'bridge', 0.03);
  city.box(-2, 0.9, 7.4, 12, 0.35, 0.25, '#9a968e', 'bridge', 0.02);
  city.box(-2, 0.9, 9.35, 12, 0.35, 0.25, '#9a968e', 'bridge', 0.02);
  [1, 4, 7].forEach((px) => city.box(px, -0.9, 7.7, 0.9, 1.4, 1.6, '#a8a49b', 'bridge', 0.02));

  // trees
  function tree(x, z, r, lm, trunkH) {
    const th = trunkH || 1.2;
    city.box(x - 0.25, 0, z - 0.25, 0.5, th, 0.5, C.trunk, lm, 0.05);
    const cy = th + r * 0.7;
    const step = r > 2 ? 0.9 : 0.6;
    for (let dx = -r; dx <= r; dx += step) for (let dy = -r; dy <= r; dy += step) for (let dz = -r; dz <= r; dz += step) {
      const d = Math.sqrt(dx * dx + dy * dy * 1.2 + dz * dz);
      if (d > r || d < r - step * 1.6) continue;
      const h = hash(x + dx, dy, z + dz);
      if (h < 0.12) continue;
      city.box(x + dx - step / 2, cy + dy - step / 2, z + dz - step / 2, step, step, step, h > 0.55 ? C.canopy : C.canopy2, lm, 0.12);
    }
  }
  // park strip
  for (let z = 11; z < 34; z += 3) { tree(11.5, z, 0.9, null); tree(14.5, z + 1.5, 0.8, null); }
  for (let z = 11; z < 34; z++) city.box(12.6 + Math.sin(z / 3) * 0.6, 0, z, 1, 0.04, 1, '#e7dcc0', null, 0.03);
  // street trees
  for (let x = 19; x < 62; x += 4) { tree(x, 18.8, 0.7, null); tree(x + 1, 40.8, 0.7, null); }
  for (let z = 23; z < 34; z += 3) { tree(35.8, z, 0.6, 'square'); tree(44.2, z, 0.6, 'square'); }

  // the big tree in Tree Square
  tree(40, 28, 3.8, 'square', 3.4);
  city.box(38.5, 0, 26.5, 3, 0.4, 3, '#8b6a45', 'square', 0.05);
  [[37, 31.8], [42, 31.8], [37, 24], [42, 24]].forEach(([bx, bz]) => city.box(bx, 0, bz, 1.4, 0.35, 0.5, C.timber, 'square', 0.04));

  // stepped towers (north) with window bands and roof gardens
  function tower(x0, z0) {
    const tiers = [[7, 5], [5, 4], [3, 3]];
    let y = 0, off = 0;
    tiers.forEach(([s, h], ti) => {
      for (let k = 0; k < h; k++) {
        const band = k % 2 === 1;
        city.box(x0 + off, y + k, z0 + off, s, 1, s, band ? C.blueBand : (ti === 0 && k === 0 ? C.orange : C.white), null, 0.04);
      }
      y += h;
      // roof garden rim
      if (ti < 2) for (let i = 0; i < s; i++) {
        if (hash(x0 + i, y, z0) > 0.35) city.box(x0 + off + i, y, z0 + off, 1, 0.6, 1, C.canopy2, null, 0.15);
        if (hash(x0, y, z0 + i) > 0.35) city.box(x0 + off, y, z0 + off + i, 1, 0.6, 1, C.canopy2, null, 0.15);
      }
      off += 1;
    });
    city.box(x0 + 2.5, y, z0 + 2.5, 2, 0.8, 2, C.canopy, null, 0.12);
  }
  tower(21, 11); tower(32, 11); tower(43, 11);
  // downtown low blocks (north of the bridge road) and east / south blocks
  function block(x, z, w, d, h, col) {
    for (let k = 0; k < h; k++) city.box(x, k, z, w, 1, d, k % 2 ? C.blueBand : col, null, 0.05);
    city.box(x + 0.5, h, z + 0.5, w - 1, 0.25, d - 1, '#cfcac0', null, 0.03);
  }
  block(19, 1, 6, 5, 3, C.white); block(27, 2, 5, 4, 2, C.orange); block(34, 1, 6, 5, 4, C.white); block(43, 2, 5, 4, 2, C.white); block(51, 1, 6, 5, 3, C.orange); block(59, 2, 3, 4, 2, C.white);
  block(53, 11, 7, 7, 3, C.white);
  block(19, 41, 5, 4, 2, C.orange); block(27, 42, 6, 4, 3, C.white); block(36, 42, 4, 3, 1, C.white); block(45, 41, 6, 4, 2, C.white); block(54, 42, 5, 3, 2, C.orange);
  block(64, 12, 2, 6, 2, C.white); block(64, 24, 2, 8, 3, C.orange);

  // Library: broad two-storey hall with a vaulted roof and a rounded east end
  (function library() {
    const x0 = 47, z0 = 23, w = 12, d = 10, h = 2, mid = (d - 1) / 2;
    const inside = (x, z) => {
      if (x < 0 || z < 0 || x >= w || z >= d) return false;
      const ex = x - (w - 6);
      return ex <= 0 || Math.hypot(ex, z - mid) <= 5.3;
    };
    for (let x = 0; x < w; x++) for (let z = 0; z < d; z++) {
      if (!inside(x, z)) continue;
      const edge = !inside(x - 1, z) || !inside(x + 1, z) || !inside(x, z - 1) || !inside(x, z + 1);
      if (edge) {
        city.box(x0 + x, 0, z0 + z, 1, 1, 1, (x + z) % 3 === 0 ? C.orangeDark : C.orange, 'library', 0.05);
        city.box(x0 + x, 1, z0 + z, 1, 1, 1, (x + z) % 2 ? C.blueBand : C.orange, 'library', 0.05);
      }
      const ex = Math.max(0, x - (w - 6));
      const R = 5.1;
      const rr = R * R - (z - mid) * (z - mid) - ex * ex * 0.9;
      if (rr <= 0) continue;
      const layers = Math.max(1, Math.round(Math.sqrt(rr) * 0.95));
      for (let k = 0; k < layers; k++) {
        const top = k === layers - 1;
        const col = top && (z === Math.floor(mid) || z === Math.ceil(mid)) ? '#f4f1ea' : (top ? (x % 2 ? C.orange : '#ff9d45') : C.orangeDark);
        city.box(x0 + x, h + k, z0 + z, 1, 1, 1, col, 'library', 0.06);
      }
    }
    city.box(46.2, 0, 26.5, 0.8, 1.6, 3, C.blueBand, 'library', 0.02);
  })();

  // tram stop shelter south of the square
  city.box(38, 0, 34.1, 4, 0.1, 0.8, '#d0d3d6', 'tram', 0);
  city.box(38, 1.7, 34, 4, 0.15, 1, C.navy, 'tram', 0);
  city.box(38.1, 0, 34.1, 0.15, 1.7, 0.15, C.navy, 'tram', 0);
  city.box(41.75, 0, 34.1, 0.15, 1.7, 0.15, C.navy, 'tram', 0);
  // lamps along the boulevard
  for (let x = 20; x < 62; x += 6) { city.box(x, 0, 34.5, 0.2, 2.2, 0.2, C.dark, null, 0); city.box(x - 0.15, 2.2, 34.35, 0.5, 0.35, 0.5, '#ffe6a3', null, 0); }

  const cityMesh = city.build();
  scene.add(cityMesh);
  const waterMesh = water.build({ cast: false });
  scene.add(waterMesh);

  // ---------------- Workshop: walls, interior and a liftable sawtooth roof ----------------
  const WS = { x0: 19, z0: 23, w: 15, d: 10 };
  const walls = new Batch();
  const floor = new Batch();
  for (let x = 0; x < WS.w; x++) for (let z = 0; z < WS.d; z++) {
    const onEdge = x === 0 || z === 0 || x === WS.w - 1 || z === WS.d - 1;
    if (!onEdge) { floor.box(WS.x0 + x, 0, WS.z0 + z, 1, 0.08, 1, (x + z) % 2 ? C.timber : '#d99a4a', 'workshop', 0.05); continue; }
    const door = x === WS.w - 1 && z >= 4 && z <= 5;
    for (let k = 0; k < 3; k++) {
      if (door && k < 2) continue;
      const glass = k === 1 && ((z === WS.d - 1 && x % 3 !== 0) || (x === WS.w - 1 && z % 3 !== 0));
      walls.box(WS.x0 + x, k, WS.z0 + z, 1, 1, 1, glass ? C.glass : (k === 2 ? C.yellowDark : C.yellow), 'workshop', 0.05);
    }
  }
  const wallMesh = walls.build();
  const wallGroup = new THREE.Group();
  wallGroup.add(wallMesh);
  scene.add(wallGroup, floor.build({ cast: false }));

  const roof = new Batch();
  for (let b = 0; b < 3; b++) for (let dx = 0; dx < 5; dx++) {
    const x = WS.x0 + b * 5 + dx;
    const layers = [4, 3, 2, 2, 1][dx];
    for (let z = WS.z0; z < WS.z0 + WS.d; z++) for (let k = 0; k < layers; k++) {
      const top = k === layers - 1;
      const col = dx === 0 && !top && k > 0 ? C.glass : (top ? C.yellow : C.yellowDark);
      roof.box(x, 3 + k, z, 1, 1, 1, col, 'workshop', 0.05);
    }
  }
  const roofMat = new THREE.MeshLambertMaterial({ transparent: true, opacity: 1 });
  const roofMesh = roof.build({ material: roofMat });
  scene.add(roofMesh);

  // ---------------- Robots ----------------
  const geoCache = {};
  const g = (w, h, d) => geoCache[`${w}|${h}|${d}`] || (geoCache[`${w}|${h}|${d}`] = new THREE.BoxGeometry(w, h, d));
  const M = {
    shell: new THREE.MeshLambertMaterial({ color: '#f2efeb' }),
    joint: new THREE.MeshLambertMaterial({ color: '#c9c4bf' }),
    dark: new THREE.MeshLambertMaterial({ color: '#2f343b' }),
    screenBody: new THREE.MeshLambertMaterial({ color: '#131614' }),
    desk: new THREE.MeshLambertMaterial({ color: '#e2a857' }),
    deskLeg: new THREE.MeshLambertMaterial({ color: '#3b4250' }),
    laptop: new THREE.MeshLambertMaterial({ color: '#8f97a3' })
  };
  function faceTexture(closed) {
    const c = document.createElement('canvas');
    c.width = 24; c.height = 16;
    const x = c.getContext('2d');
    x.fillStyle = '#131614'; x.fillRect(0, 0, 24, 16);
    x.fillStyle = '#0ef69f';
    const px = (a, b) => x.fillRect(a, b, 1, 1);
    if (closed) { for (let i = 4; i < 9; i++) px(i, 6); for (let i = 15; i < 20; i++) px(i, 6); }
    else { [[4, 7], [5, 6], [6, 5], [7, 6], [8, 7]].forEach(([a, b]) => px(a, b)); [[15, 7], [16, 6], [17, 5], [18, 6], [19, 7]].forEach(([a, b]) => px(a, b)); }
    [[9, 10], [10, 11], [11, 11], [12, 11], [13, 11], [14, 10]].forEach(([a, b]) => px(a, b));
    const t = new THREE.CanvasTexture(c);
    t.magFilter = THREE.NearestFilter; t.minFilter = THREE.NearestFilter;
    t.colorSpace = THREE.SRGBColorSpace;
    return t;
  }
  const FACE_OPEN = new THREE.MeshBasicMaterial({ map: faceTexture(false) });
  const FACE_SHUT = new THREE.MeshBasicMaterial({ map: faceTexture(true) });
  const pickables = [];

  function part(parent, geo, mat, x, y, z, tag) {
    const m = new THREE.Mesh(geo, mat);
    m.position.set(x, y, z);
    m.castShadow = true;
    m.receiveShadow = true;
    if (tag) { m.userData = tag; pickables.push(m); }
    parent.add(m);
    return m;
  }

  // A robot built in local units, facing +z. seated=true bends the legs over a chair.
  function makeRobot(accent, tag, opts) {
    const o = opts || {};
    const accentMat = new THREE.MeshLambertMaterial({ color: accent });
    const root = new THREE.Group();
    const body = new THREE.Group();
    root.add(body);
    const seated = !!o.seated;
    const hipY = seated ? 0.52 : 0.78;
    if (seated) {
      [-0.12, 0.12].forEach((sx) => {
        part(body, g(0.17, 0.15, 0.42), M.shell, sx, hipY, 0.14, tag);
        part(body, g(0.15, 0.42, 0.15), M.shell, sx, 0.28, 0.33, tag);
        part(body, g(0.17, 0.07, 0.22), M.dark, sx, 0.04, 0.37, tag);
      });
    } else {
      [-0.12, 0.12].forEach((sx) => {
        part(body, g(0.16, 0.7, 0.16), M.shell, sx, 0.4, 0, tag);
        part(body, g(0.18, 0.08, 0.24), M.dark, sx, 0.04, 0.03, tag);
      });
    }
    part(body, g(0.48, 0.5, 0.3), M.shell, 0, hipY + 0.3, 0, tag);
    part(body, g(0.28, 0.22, 0.04), accentMat, 0, hipY + 0.33, 0.16, tag);
    if (o.badge) part(body, g(0.1, 0.1, 0.02), new THREE.MeshLambertMaterial({ color: '#107a24' }), 0.12, hipY + 0.45, 0.185, tag);
    part(body, g(0.16, 0.08, 0.16), M.joint, 0, hipY + 0.59, 0, tag);
    const head = new THREE.Group();
    head.position.set(0, hipY + 0.84, 0);
    body.add(head);
    part(head, g(0.56, 0.42, 0.44), M.shell, 0, 0, 0, tag);
    const face = part(head, g(0.44, 0.3, 0.02), FACE_OPEN, 0, 0, 0.225, tag);
    part(head, g(0.05, 0.14, 0.14), accentMat, -0.3, 0, 0, tag);
    part(head, g(0.05, 0.14, 0.14), accentMat, 0.3, 0, 0, tag);
    const arms = [-1, 1].map((side) => {
      const shoulder = new THREE.Group();
      shoulder.position.set(side * 0.31, hipY + 0.5, 0);
      body.add(shoulder);
      part(shoulder, g(0.12, 0.3, 0.12), M.shell, 0, -0.15, 0, tag);
      const elbow = new THREE.Group();
      elbow.position.set(0, -0.3, 0);
      shoulder.add(elbow);
      part(elbow, g(0.11, 0.11, 0.3), M.shell, 0, 0, 0.15, tag);
      part(elbow, g(0.13, 0.12, 0.1), M.dark, 0, 0, 0.33, tag);
      if (seated) { shoulder.rotation.x = -0.35; elbow.rotation.x = 0.25; }
      else { elbow.rotation.x = 1.2; }
      return { shoulder, elbow };
    });
    return { root, body, head, face, arms, accentMat, phase: Math.random() * 6.28, blinkAt: 1 + Math.random() * 4 };
  }

  // Guild at desks: two rows of seven, facing south, inside the Workshop.
  const guildGroup = new THREE.Group();
  scene.add(guildGroup);
  const robots = [];
  const accents = window.VOXEL_ACCENTS;
  const lampMats = [];
  A.guild.forEach((gr, i) => {
    const row = i < 7 ? 0 : 1;
    const col = i % 7;
    const x = WS.x0 + 1.9 + col * 1.85;
    const z = WS.z0 + (row === 0 ? 2.1 : 6.1);
    const r = makeRobot(accents[i], { robot: i }, { seated: true });
    r.root.position.set(x, 0.08, z);
    // chair
    part(r.root, g(0.56, 0.08, 0.5), M.dark, 0, 0.42, 0.05);
    part(r.root, g(0.56, 0.55, 0.08), M.dark, 0, 0.72, -0.24);
    part(r.root, g(0.08, 0.38, 0.08), M.dark, 0, 0.2, 0.05);
    // desk in front
    part(r.root, g(1.4, 0.08, 0.6), M.desk, 0, 0.74, 0.78);
    [[-0.62, 0.55], [0.62, 0.55], [-0.62, 1.0], [0.62, 1.0]].forEach(([dx, dz]) => part(r.root, g(0.06, 0.7, 0.06), M.deskLeg, dx, 0.37, dz));
    part(r.root, g(0.42, 0.03, 0.28), M.laptop, 0, 0.8, 0.7);
    const lid = part(r.root, g(0.42, 0.28, 0.025), M.laptop, 0, 0.94, 0.85);
    lid.rotation.x = -0.25;
    const lampMat = new THREE.MeshBasicMaterial({ color: '#0ef69f' });
    lampMats.push(lampMat);
    part(r.root, g(0.08, 0.08, 0.08), lampMat, 0.5, 0.82, 0.95);
    // a block on the desk in the resident's accent colour
    part(r.root, g(0.16, 0.16, 0.16), r.accentMat, -0.45, 0.86, 0.72);
    guildGroup.add(r.root);
    r.data = gr;
    r.index = i;
    robots.push(r);
  });

  // City Agent A1 in Tree Square (sheets: white robot, green chequered torso, leaf badge).
  const a1 = makeRobot('#2f9a3a', { a1: true }, { badge: true });
  a1.root.position.set(41.9, 0.4, 30.4);
  a1.root.rotation.y = -0.5;
  a1.root.scale.setScalar(1.5);
  scene.add(a1.root);

  // ---------------- Tram ----------------
  const tram = new THREE.Group();
  const tramBody = new THREE.MeshLambertMaterial({ color: C.cream });
  const tramStripe = new THREE.MeshLambertMaterial({ color: C.coral });
  const tramWin = new THREE.MeshLambertMaterial({ color: '#2d4a66' });
  for (let k = 0; k < 3; k++) {
    const cx = k * 3.3;
    part(tram, g(3.1, 1.3, 1.3), tramBody, cx, 0.95, 0, { lm: 'tram' });
    part(tram, g(3.12, 0.22, 1.32), tramStripe, cx, 0.55, 0, { lm: 'tram' });
    part(tram, g(2.6, 0.42, 1.34), tramWin, cx, 1.15, 0, { lm: 'tram' });
    part(tram, g(3.0, 0.12, 1.2), tramStripe, cx, 1.66, 0, { lm: 'tram' });
  }
  tram.position.set(20, 0, 37);
  scene.add(tram);

  // ---------------- Walkers (human residents: square heads, cobalt/orange/green clothes) ----------------
  const walkers = [];
  const shirt = ['#0e4099', '#fd8d2d', '#3f9e45', '#1f5fd6', '#e0701a'];
  for (let i = 0; i < 18; i++) {
    const w = new THREE.Group();
    const skin = new THREE.MeshLambertMaterial({ color: i % 2 ? C.skin1 : C.skin2 });
    const cloth = new THREE.MeshLambertMaterial({ color: shirt[i % shirt.length] });
    part(w, g(0.3, 0.45, 0.2), M.dark, 0, 0.23, 0);
    part(w, g(0.42, 0.5, 0.26), cloth, 0, 0.7, 0);
    part(w, g(0.36, 0.36, 0.36), skin, 0, 1.13, 0);
    part(w, g(0.38, 0.12, 0.38), new THREE.MeshLambertMaterial({ color: C.hair }), 0, 1.33, 0);
    w.scale.setScalar(0.9);
    const inSquare = i < 11;
    const path = inSquare
      ? { cx: 40, cz: 28, r: 4.4 + (i % 3) * 0.8, speed: 0.12 + (i % 4) * 0.03, a: i * 0.9 }
      : { line: true, x0: 20 + (i * 7) % 40, z: i % 2 ? 34.6 : 22.3, speed: 0.6 + (i % 3) * 0.2, span: 10 };
    walkers.push({ g: w, p: path });
    scene.add(w);
  }

  // ---------------- Landmark pins (visual labels, mirrors of the toolbar) ----------------
  const pins = $('pins');
  const pinEls = {};
  LANDMARKS.forEach((l) => {
    const p = Kit.el('button', { class: `pin pin-${l.id}`, type: 'button', tabindex: '-1', text: l.label });
    p.addEventListener('click', () => select(l.id, true));
    pins.append(p);
    pinEls[l.id] = p;
  });
  const robotTag = Kit.el('div', { class: 'robot-tag', hidden: '' });
  pins.append(robotTag);

  // ---------------- sizing ----------------
  let viewW = 1, viewH = 1;
  function resize() {
    const r = host.getBoundingClientRect();
    viewW = Math.max(1, r.width); viewH = Math.max(1, r.height);
    renderer.setSize(viewW, viewH, false);
    const aspect = viewW / viewH;
    const half = aspect < 0.9 ? Math.max(21, 27 / aspect) : Math.max(21, 36 / aspect);
    camera.left = -half * aspect; camera.right = half * aspect;
    camera.top = half; camera.bottom = -half;
    camera.updateProjectionMatrix();
    requestRender();
  }
  new ResizeObserver(resize).observe(host);

  // ---------------- state: select / inside ----------------
  let current = null;
  let inside = false;
  let focusRobot = -1;
  const anim = { active: false, t: 0, dur: 0.9, fromT: new THREE.Vector3(), toT: new THREE.Vector3(), fromZ: 1, toZ: 1 };
  const roofState = { v: 0, to: 0 }; // 0 = roof on, 1 = lifted

  function flyTo(target, zoom) {
    anim.fromT.copy(controls.target);
    anim.toT.set(target[0], target[1], target[2]);
    anim.fromZ = camera.zoom;
    anim.toZ = zoom;
    anim.t = 0;
    anim.active = true;
    if (!motionOn) finishAnim();
    requestRender();
  }
  function applyAnim(k) {
    const e = k < 0.5 ? 4 * k * k * k : 1 - Math.pow(-2 * k + 2, 3) / 2;
    const next = new THREE.Vector3().lerpVectors(anim.fromT, anim.toT, e);
    const delta = next.clone().sub(controls.target);
    controls.target.copy(next);
    camera.position.add(delta);
    camera.zoom = anim.fromZ + (anim.toZ - anim.fromZ) * e;
    camera.updateProjectionMatrix();
  }
  function finishAnim() { applyAnim(1); anim.active = false; controls.update(); }

  function select(id, fromUser) {
    const l = byId[id];
    if (!l) return;
    current = id;
    visited.add(id);
    updateCounter();
    document.querySelectorAll('.lm-btn').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.lm === id)));
    Object.entries(pinEls).forEach(([k, p]) => p.classList.toggle('active', k === id));
    if (id === 'workshop') { enterWorkshop(); return; }
    if (inside) leaveWorkshop(true);
    flyTo(l.focus, l.zoom);
    showCard(`${l.did} · landmark`, l.label, l.info.note, [sectionLink(l)]);
  }

  function enterWorkshop() {
    const l = byId.workshop;
    inside = true;
    roofState.to = 1;
    $('inside').hidden = false;
    $('stage').classList.add('is-inside');
    flyTo([26.5, 0.8, 28], window.innerWidth < 700 ? 2.6 : 2.9);
    showCard('W1 · landmark · open', 'Workshop', `${l.info.note} Roof lifted: the fourteen Guild residents are at their desks.`, [sectionLink(l)]);
    if (!motionOn) { roofState.v = 1; applyRoof(); }
    requestRender();
  }
  function leaveWorkshop(silent) {
    inside = false;
    focusRobot = -1;
    roofState.to = 0;
    $('inside').hidden = true;
    $('stage').classList.remove('is-inside');
    robotTag.hidden = true;
    document.querySelectorAll('.roster button').forEach((b) => b.setAttribute('aria-pressed', 'false'));
    if (!motionOn) { roofState.v = 0; applyRoof(); }
    if (!silent) {
      flyTo([CENTER.x, 0, CENTER.z], 1);
      current = null;
      document.querySelectorAll('.lm-btn').forEach((b) => b.setAttribute('aria-pressed', 'false'));
      Object.values(pinEls).forEach((p) => p.classList.remove('active'));
      $('hud-card').hidden = true;
      $('hero-card').classList.remove('tucked');
      host.focus({ preventScroll: true });
    }
    requestRender();
  }
  $('leave-btn').addEventListener('click', () => leaveWorkshop(false));

  function applyRoof() {
    const v = roofState.v;
    roofMesh.position.y = v * 9;
    roofMat.opacity = 1 - v;
    roofMesh.visible = v < 0.99;
    roofMesh.castShadow = v < 0.05;
    wallGroup.scale.y = 1 - v * 0.62;
  }

  // roster
  const roster = $('roster');
  robots.forEach((r) => {
    const b = Kit.el('button', { type: 'button', 'aria-pressed': 'false', 'data-robot': String(r.index) }, [
      Kit.el('span', { class: 'r-dot', style: `background:${accents[r.index]}`, 'aria-hidden': 'true' }), r.data.name
    ]);
    b.addEventListener('click', () => focusOn(r.index));
    roster.append(b);
  });
  roster.addEventListener('keydown', (e) => {
    const btns = [...roster.querySelectorAll('button')];
    const i = btns.indexOf(document.activeElement);
    if (i < 0) return;
    let n = -1;
    if (e.key === 'ArrowRight' || e.key === 'ArrowDown') n = (i + 1) % btns.length;
    if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') n = (i - 1 + btns.length) % btns.length;
    if (n >= 0) { e.preventDefault(); btns[n].focus(); focusOn(n); }
  });

  function focusOn(i) {
    if (!inside) enterWorkshop();
    focusRobot = i;
    const r = robots[i];
    document.querySelectorAll('.roster button').forEach((b) => b.setAttribute('aria-pressed', String(Number(b.dataset.robot) === i)));
    const p = r.root.position;
    flyTo([p.x, 0.8, p.z + 0.4], window.innerWidth < 700 ? 4.4 : 5);
    showCard(`Guild resident ${i + 1} of 14`, r.data.name, `${r.data.role}. Proposed public role, pending review. Shown seated and working at a desk; illustrative animation, not live data.`, [sectionLink(byId.workshop)]);
    robotTag.hidden = false;
    robotTag.textContent = r.data.name;
    requestRender();
  }

  function showA1() {
    visited.add('square'); updateCounter();
    flyTo([41.9, 0.5, 30.4], 3.6);
    showCard('City Agent A1', 'A1 in Tree Square', A.agentA1 + ' In this style: a white cube-headed robot with a dark display, green chevron eyes and a leaf badge.', [sectionLink(byId.workshop)]);
  }

  // ---------------- pointer picking ----------------
  const ray = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const pickTargets = () => [cityMesh, waterMesh, wallMesh, roofMesh, ...pickables].filter(Boolean);
  function pick(ev) {
    const r = renderer.domElement.getBoundingClientRect();
    ndc.set(((ev.clientX - r.left) / r.width) * 2 - 1, -((ev.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    const hits = ray.intersectObjects(pickTargets(), false);
    for (const h of hits) {
      if (h.object === roofMesh && !roofMesh.visible) continue;
      if (h.object.userData.robot != null) return { robot: h.object.userData.robot };
      if (h.object.userData.a1) return { a1: true };
      if (h.object.userData.lm && typeof h.object.userData.lm === 'string') return { lm: h.object.userData.lm };
      if (h.instanceId != null && h.object.userData.lm) { const lm = h.object.userData.lm[h.instanceId]; if (lm) return { lm }; }
      return null;
    }
    return null;
  }
  let down = null;
  renderer.domElement.addEventListener('pointerdown', (e) => { down = { x: e.clientX, y: e.clientY }; });
  renderer.domElement.addEventListener('pointerup', (e) => {
    if (!down) return;
    const moved = Math.hypot(e.clientX - down.x, e.clientY - down.y);
    down = null;
    if (moved > 6) return;
    const hit = pick(e);
    if (!hit) return;
    if (hit.robot != null) focusOn(hit.robot);
    else if (hit.a1) showA1();
    else if (hit.lm === 'workshop' && inside) { /* already inside */ }
    else select(hit.lm, true);
  });
  let hoverT = 0;
  renderer.domElement.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse' || down) return;
    const now = performance.now();
    if (now - hoverT < 60) return;
    hoverT = now;
    const hit = pick(e);
    renderer.domElement.style.cursor = hit ? 'pointer' : 'grab';
    Object.entries(pinEls).forEach(([k, p]) => p.classList.toggle('hover', !!hit && hit.lm === k));
  });

  // ---------------- keyboard on the canvas ----------------
  function orbit(dAz, dPol) {
    const off = camera.position.clone().sub(controls.target);
    const sph = new THREE.Spherical().setFromVector3(off);
    sph.theta += dAz;
    sph.phi = Math.min(controls.maxPolarAngle, Math.max(controls.minPolarAngle, sph.phi + dPol));
    off.setFromSpherical(sph);
    camera.position.copy(controls.target).add(off);
    camera.lookAt(controls.target);
    controls.update();
    requestRender();
  }
  host.addEventListener('keydown', (e) => {
    const k = e.key;
    if (k === 'ArrowLeft') orbit(-0.2, 0);
    else if (k === 'ArrowRight') orbit(0.2, 0);
    else if (k === 'ArrowUp') orbit(0, -0.1);
    else if (k === 'ArrowDown') orbit(0, 0.1);
    else if (k === '+' || k === '=') { camera.zoom = Math.min(controls.maxZoom, camera.zoom * 1.2); camera.updateProjectionMatrix(); requestRender(); }
    else if (k === '-' || k === '_') { camera.zoom = Math.max(controls.minZoom, camera.zoom / 1.2); camera.updateProjectionMatrix(); requestRender(); }
    else if (k === '0') resetView();
    else if (k === 'Enter' || k === ' ') { select('workshop', true); }
    else return;
    e.preventDefault();
  });
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && inside && !document.querySelector('dialog[open]')) { e.preventDefault(); leaveWorkshop(false); }
  });
  function resetView() {
    if (inside) leaveWorkshop(true);
    camera.position.copy(controls.target).add(HOME_OFFSET);
    flyTo([CENTER.x, 0, CENTER.z], 1);
  }

  // toolbar arrow keys
  toolbar.addEventListener('keydown', (e) => {
    const btns = [...toolbar.querySelectorAll('button')];
    const i = btns.indexOf(document.activeElement);
    if (i < 0) return;
    if (e.key === 'ArrowRight') { e.preventDefault(); btns[(i + 1) % btns.length].focus(); }
    if (e.key === 'ArrowLeft') { e.preventDefault(); btns[(i - 1 + btns.length) % btns.length].focus(); }
  });

  // motion toggle
  const motionBtn = $('motion-btn');
  function syncMotionBtn() { motionBtn.textContent = motionOn ? 'Pause motion' : 'Play motion'; motionBtn.setAttribute('aria-pressed', String(!motionOn)); }
  syncMotionBtn();
  motionBtn.addEventListener('click', () => {
    motionOn = !motionOn;
    controls.enableDamping = motionOn;
    syncMotionBtn();
    if (!motionOn && anim.active) finishAnim();
    if (!motionOn) { roofState.v = roofState.to; applyRoof(); }
    requestRender();
  });

  // ---------------- loop ----------------
  const clock = new THREE.Clock();
  let time = 0;
  let needs = true;
  let visible = true;
  function requestRender() { needs = true; if (!looping) loopOnce(); }
  let looping = false;
  controls.addEventListener('change', () => { needs = true; if (!looping) loopOnce(); });
  new IntersectionObserver((ents) => { visible = ents[0].isIntersecting; if (visible) kick(); }, { threshold: 0.01 }).observe(host);
  document.addEventListener('visibilitychange', kick);

  const tmpV = new THREE.Vector3();
  function placePins() {
    LANDMARKS.forEach((l) => {
      tmpV.set(l.anchor[0], l.anchor[1] + (l.id === 'workshop' ? roofState.v * 6 : 0), l.anchor[2]).project(camera);
      const p = pinEls[l.id];
      const x = (tmpV.x * 0.5 + 0.5) * viewW, y = (-tmpV.y * 0.5 + 0.5) * viewH;
      const off = x < -40 || x > viewW + 40 || y < -20 || y > viewH + 20;
      p.style.transform = `translate(${x}px, ${y}px) translate(-50%, -100%)`;
      p.style.visibility = off || (inside && l.id !== 'workshop') ? 'hidden' : 'visible';
    });
    if (focusRobot >= 0) {
      const r = robots[focusRobot];
      tmpV.set(r.root.position.x, 2.2, r.root.position.z).project(camera);
      robotTag.style.transform = `translate(${(tmpV.x * 0.5 + 0.5) * viewW}px, ${(-tmpV.y * 0.5 + 0.5) * viewH}px) translate(-50%, -100%)`;
    }
  }

  function step(dt) {
    time += dt;
    if (anim.active) { anim.t += dt / anim.dur; if (anim.t >= 1) finishAnim(); else applyAnim(anim.t); }
    if (roofState.v !== roofState.to) {
      const dir = Math.sign(roofState.to - roofState.v);
      roofState.v = Math.min(1, Math.max(0, roofState.v + dir * dt * 1.6));
      if ((dir > 0 && roofState.v >= roofState.to) || (dir < 0 && roofState.v <= roofState.to)) roofState.v = roofState.to;
      applyRoof();
    }
    // Guild typing, head bob, blinking, desk lamps
    robots.forEach((r, i) => {
      const t = time * 9 + r.phase;
      r.arms[0].elbow.rotation.x = 0.25 + Math.sin(t) * 0.12;
      r.arms[1].elbow.rotation.x = 0.25 + Math.sin(t + 2.1) * 0.12;
      r.head.rotation.x = Math.sin(time * 1.3 + r.phase) * 0.05;
      r.head.rotation.y = Math.sin(time * 0.5 + r.phase) * 0.12;
      const blink = (time + r.phase) % r.blinkAt < 0.14;
      r.face.material = blink ? FACE_SHUT : FACE_OPEN;
      lampMats[i].color.set(Math.sin(time * 3 + r.phase * 3) > 0.2 ? '#0ef69f' : '#0a7a50');
    });
    // A1 waves
    a1.arms[1].shoulder.rotation.z = 2.5 + Math.sin(time * 4) * 0.25;
    a1.head.rotation.y = Math.sin(time * 0.8) * 0.25;
    // tram: runs west to east, dwells at the stop south of the square
    const cyc = (time * 5) % 70;
    let tx;
    if (cyc < 18) tx = 12 + cyc;
    else if (cyc < 24) tx = 30;
    else tx = 30 + (cyc - 24);
    tram.position.x = tx + 4.3;
    tram.visible = tram.position.x < 70;
    // walkers
    walkers.forEach((w) => {
      const p = w.p;
      if (p.line) {
        const s = ((time * p.speed) % (p.span * 2));
        const d = s < p.span ? s : p.span * 2 - s;
        w.g.position.set(p.x0 + d, 0, p.z);
        w.g.rotation.y = s < p.span ? Math.PI / 2 : -Math.PI / 2;
      } else {
        const a = p.a + time * p.speed;
        w.g.position.set(p.cx + Math.cos(a) * p.r, 0, p.cz + Math.sin(a) * p.r * 0.9);
        w.g.rotation.y = -a;
      }
      w.g.position.y = Math.abs(Math.sin(time * 8 + p.r * 3)) * 0.06;
    });
    waterMesh.position.y = Math.sin(time * 1.2) * 0.04;
  }

  function frame() {
    const dt = Math.min(0.05, clock.getDelta());
    const animating = motionOn && visible && !document.hidden;
    if (animating) step(dt);
    else if (anim.active) finishAnim();
    if (controls.enableDamping) controls.update();
    placePins();
    renderer.render(scene, camera);
    needs = false;
    if (animating) requestAnimationFrame(frame);
    else looping = false;
  }
  function loopOnce() {
    looping = true;
    requestAnimationFrame(() => {
      if (motionOn && visible && !document.hidden) { clock.getDelta(); frame(); }
      else { if (controls.enableDamping) controls.update(); placePins(); renderer.render(scene, camera); looping = false; }
    });
  }
  function kick() { if (!looping) { clock.getDelta(); loopOnce(); } }

  // A static but lively first frame for reduced motion: pose once at a pleasant time.
  step(0.0001);
  if (!motionOn) { time = 3.2; step(0.0001); }
  applyRoof();
  resize();
  kick();
})();
