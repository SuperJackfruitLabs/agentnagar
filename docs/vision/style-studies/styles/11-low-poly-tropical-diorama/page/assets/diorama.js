/* The turntable: an original low-poly model of the reference district in three.js. Illustrative only. */
(function () {
  const D = window.Diorama;
  const reduced = Kit.reducedMotion();
  const stage = document.querySelector('.stage');
  const canvas = document.getElementById('scene');
  const pinsLayer = document.querySelector('.pins');
  const slider = document.getElementById('time');
  const out = document.getElementById('time-out');
  const spinBtn = document.getElementById('spin-btn');

  function fallback() {
    canvas.hidden = true;
    const fb = document.querySelector('.fallback');
    fb.hidden = false;
    fb.append(Kit.sheetImg(D.S, 0, 'bl', { eager: true, alt: `${D.S.name} concept study, City perspectives, Diagonal panel (${D.S.sheets[0].revision}): the stone bridge, the terracotta Workshop, the central tree, the green-roofed Library and the tram boulevard.` }));
    fb.append(Kit.el('p', { text: 'Static view: the 3D model needs WebGL. This is the Diagonal panel from the City perspectives concept sheet; use the landmark list to open each card.' }));
    spinBtn.hidden = true;
    slider.disabled = true;
  }

  let T = window.THREE;
  let renderer;
  try {
    if (!T) throw new Error('three missing');
    renderer = new T.WebGLRenderer({ canvas, antialias: true, alpha: true, preserveDrawingBuffer: true });
  } catch (e) { fallback(); return; }

  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = T.PCFSoftShadowMap;
  const scene = new T.Scene();
  const camera = new T.PerspectiveCamera(32, 1, 0.5, 400);
  camera.position.set(55, 47, 62);
  const narrow = window.matchMedia('(max-width: 900px)').matches;
  const TY = narrow ? 0 : -3, TZ = narrow ? 2 : 5;
  const controls = new T.OrbitControls(camera, canvas);
  controls.target.set(1, TY, TZ);
  controls.enableDamping = !reduced;
  controls.dampingFactor = 0.08;
  controls.enablePan = false;
  controls.minDistance = 30;
  controls.maxDistance = 110;
  controls.maxPolarAngle = Math.PI * 0.44;
  controls.minPolarAngle = Math.PI * 0.12;
  controls.autoRotate = !reduced;
  controls.autoRotateSpeed = 0.55;

  // ---------- Materials ----------
  const mats = {};
  const M = (hex, extra) => {
    const key = hex + JSON.stringify(extra || {});
    if (!mats[key]) mats[key] = new T.MeshStandardMaterial(Object.assign({ color: hex, flatShading: true, roughness: 0.85, metalness: 0 }, extra || {}));
    return mats[key];
  };
  const C = {
    lime: '#f7e4cf', paving: '#efd9bc', path: '#e6cda9', grass: '#8fb35a', grass2: '#79a24a', roof: '#c67c60', roof2: '#d98e62',
    copper: '#4d837d', river: '#1ba1b0', yellow: '#fdd657', leaf: '#608a3e', leaf2: '#4f7a33', leaf3: '#7ba34a', trunk: '#8a5a36',
    wood: '#a8703f', plinth: '#9b6a42', stone: '#efe2cc', coral: '#e0694a', dark: '#2b3b3a', cream: '#f6ecd8'
  };
  const windowMat = new T.MeshStandardMaterial({ color: '#2d4a55', emissive: '#ffcc66', emissiveIntensity: 0, flatShading: true, roughness: 0.4 });
  const lampMat = new T.MeshStandardMaterial({ color: '#fff3c4', emissive: '#ffc85a', emissiveIntensity: 0, flatShading: true });
  const lanternMat = new T.MeshStandardMaterial({ color: '#f6c35a', emissive: '#ffb640', emissiveIntensity: 0, flatShading: true });

  // Deterministic random and a crack-free vertex jitter (shared corners move together).
  let seed = 11;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return (seed - 1) / 2147483646; };
  function jitter(geo, amt) {
    const pos = geo.attributes.position;
    const map = new Map();
    for (let i = 0; i < pos.count; i++) {
      const k = `${pos.getX(i).toFixed(3)},${pos.getY(i).toFixed(3)},${pos.getZ(i).toFixed(3)}`;
      if (!map.has(k)) map.set(k, [(rnd() - 0.5) * amt, (rnd() - 0.5) * amt, (rnd() - 0.5) * amt]);
      const o = map.get(k);
      pos.setXYZ(i, pos.getX(i) + o[0], pos.getY(i) + o[1], pos.getZ(i) + o[2]);
    }
    geo.computeVertexNormals();
    return geo;
  }
  function mesh(geo, mat, x, y, z, parent) {
    const m = new T.Mesh(geo, mat);
    m.position.set(x || 0, y || 0, z || 0);
    m.castShadow = true; m.receiveShadow = true;
    (parent || scene).add(m);
    return m;
  }
  const box = (w, h, d) => new T.BoxGeometry(w, h, d);

  const world = new T.Group();
  scene.add(world);
  const landmarkGroups = {};
  function landmark(key) { const g = new T.Group(); g.userData.key = key; world.add(g); landmarkGroups[key] = g; return g; }

  // ---------- Plinth and ground (x east, z south) ----------
  const HALF = 22;
  mesh(box(HALF * 2 + 2, 4, HALF * 2 + 2), M(C.plinth), 0, -2.2, 0, world);
  mesh(box(HALF * 2 + 2.6, 0.6, HALF * 2 + 2.6), M('#7e5434'), 0, -4.3, 0, world);
  const ground = mesh(box(HALF * 2 - 10, 0.4, HALF * 2), M(C.paving), 5, 0, 0, world);
  ground.castShadow = false;
  // River along the west edge, with banks
  const riverGeo = new T.PlaneGeometry(9.4, HALF * 2, 6, 24); riverGeo.rotateX(-Math.PI / 2); jitter(riverGeo, 0.25);
  const river = mesh(riverGeo, M(C.river, { roughness: 0.25, metalness: 0.05 }), -HALF + 4.7, -0.15, 0, world);
  river.castShadow = false;
  mesh(box(9.4, 1.4, HALF * 2), M('#15808c'), -HALF + 4.7, -1.0, 0, world).castShadow = false;
  mesh(box(1.2, 0.8, HALF * 2), M(C.stone), -HALF + 9.9, 0, 0, world);
  const bankLandmark = landmark('river');
  bankLandmark.add(river);

  // Grass beds and paths
  [[-8.5, 8, 8, 8], [16, -3, 7, 10], [16, 14, 7, 6], [-8, -16, 6, 6], [4, 15.5, 16, 3.5]].forEach(([x, z, w, d]) => {
    const g = mesh(box(w, 0.5, d), M(C.grass), x, 0.1, z, world); g.castShadow = false;
  });
  const sq = new T.CylinderGeometry(6.2, 6.2, 0.46, 8); mesh(sq, M(C.path), 3, 0.05, 0, world).castShadow = false;
  // Tram boulevard strip
  mesh(box(HALF * 2 - 10, 0.46, 3.6), M('#d9c3a3'), 5, 0.04, 10.5, world).castShadow = false;

  // ---------- North bridge: low, three spans ----------
  const bridge = landmark('bridge');
  const bz = -12;
  mesh(box(12.4, 0.7, 2.6), M(C.stone), -HALF + 4.5, 1.1, bz, bridge);
  [-HALF + 1.6, -HALF + 4.7, -HALF + 7.8].forEach((x) => {
    const arch = new T.CylinderGeometry(1.45, 1.45, 2.6, 7, 1, true, Math.PI / 2, Math.PI);
    arch.rotateX(Math.PI / 2);
    const a = mesh(arch, M('#d9c7aa', { side: T.DoubleSide }), x, 0.75, bz, bridge);
    a.rotation.z = 0;
  });
  [-HALF + 3.15, -HALF + 6.25].forEach((x) => mesh(box(0.6, 1.8, 2.6), M(C.stone), x, 0.1, bz, bridge));
  for (let i = 0; i < 7; i++) {
    mesh(box(0.25, 0.7, 0.25), M(C.stone), -HALF - 1.2 + i * 2.05, 1.8, bz - 1.2, bridge);
    mesh(box(0.25, 0.7, 0.25), M(C.stone), -HALF - 1.2 + i * 2.05, 1.8, bz + 1.2, bridge);
  }
  mesh(box(12.4, 0.2, 0.2), M(C.stone), -HALF + 4.5, 2.15, bz - 1.2, bridge);
  mesh(box(12.4, 0.2, 0.2), M(C.stone), -HALF + 4.5, 2.15, bz + 1.2, bridge);

  // Boats and docks
  function boat(x, z, r) {
    const g = new T.Group();
    const hull = new T.CylinderGeometry(0.5, 0.25, 2.2, 5); hull.rotateX(Math.PI / 2); hull.scale(1, 0.5, 1);
    mesh(hull, M(C.cream), 0, 0.2, 0, g);
    const sail = new T.ConeGeometry(0.8, 2.4, 3); sail.scale(0.15, 1, 1);
    mesh(sail, M('#fffaf0'), 0, 1.5, 0.2, g);
    g.position.set(x, 0, z); g.rotation.y = r; world.add(g); return g;
  }
  const boats = [boat(-18, 2, 0.2), boat(-15.5, 9, -0.3), boat(-17.5, -4, 0.1)];
  mesh(box(3, 0.3, 1.2), M(C.wood), -13.6, 0.35, 3.5, world);
  mesh(box(3, 0.3, 1.2), M(C.wood), -13.6, 0.35, -2, world);

  // ---------- Workshop W1: low hall, three sawtooth bays, entrance east ----------
  const ws = landmark('workshop');
  const wx = -5, wz = 0;
  mesh(box(7.5, 2.2, 6), M(C.lime), wx, 1.3, wz, ws);
  const bayShape = new T.Shape(); bayShape.moveTo(0, 0); bayShape.lineTo(2.5, 0); bayShape.lineTo(0, 1.7); bayShape.lineTo(0, 0);
  for (let i = 0; i < 3; i++) {
    const g = new T.ExtrudeGeometry(bayShape, { depth: 6, bevelEnabled: false });
    g.translate(0, 0, -3);
    const m = mesh(g, M(C.roof), wx - 3.75 + i * 2.5, 2.4, wz, ws);
    mesh(box(0.08, 1.4, 5.6), windowMat, wx - 3.75 + i * 2.5 + 0.02, 3.05, wz, ws).castShadow = false;
    m.userData.bay = true;
  }
  mesh(box(0.1, 1.5, 3.2), windowMat, wx + 3.8, 1.2, wz, ws); // east entrance glazing
  mesh(box(0.1, 1.2, 1.4), windowMat, wx - 3.8, 1.3, wz + 1.5, ws);
  // Yellow awning and umbrellas east of the entrance
  mesh(box(1.4, 0.15, 3.6), M(C.yellow), wx + 4.4, 2.2, wz, ws);
  [[wx + 5.4, wz - 2.6], [wx + 5.8, wz + 2.8]].forEach(([x, z]) => {
    mesh(new T.CylinderGeometry(0.06, 0.06, 1.8, 4), M(C.dark), x, 1.1, z, ws);
    mesh(new T.ConeGeometry(1.1, 0.5, 6), M(C.yellow), x, 2.1, z, ws);
  });

  // ---------- Tree Square T1: one large living tree ----------
  const tree = landmark('tree');
  const tx = 3, tz = 0;
  const trunk = new T.CylinderGeometry(0.55, 0.95, 4.2, 6); jitter(trunk, 0.15);
  mesh(trunk, M(C.trunk), tx, 2.3, tz, tree);
  [[-1.6, 0.4, 0.3], [1.4, 0.6, -0.5], [0.3, 0.8, 1.4]].forEach(([dx, , dz]) => {
    const br = new T.CylinderGeometry(0.2, 0.35, 2.4, 5);
    const b = mesh(br, M(C.trunk), tx + dx * 0.6, 4.2, tz + dz * 0.6, tree);
    b.rotation.z = -dx * 0.35; b.rotation.x = dz * 0.35;
  });
  const blobs = [[0, 6.3, 0, 3.2, C.leaf], [-2.4, 5.4, 0.6, 2.3, C.leaf2], [2.3, 5.6, -0.4, 2.4, C.leaf3], [0.4, 5.3, 2.3, 2.2, C.leaf2], [-0.6, 5.5, -2.3, 2.2, C.leaf], [1.2, 7.4, 0.8, 1.8, C.leaf3], [-1.4, 7.1, -0.8, 1.7, C.leaf3]];
  blobs.forEach(([x, y, z, r, c]) => { const g = new T.IcosahedronGeometry(r, 0); jitter(g, r * 0.35); mesh(g, M(c), tx + x, y, tz + z, tree); });
  const lanterns = [];
  for (let i = 0; i < 9; i++) {
    const a = (i / 9) * Math.PI * 2;
    const l = mesh(new T.OctahedronGeometry(0.22, 0), lanternMat, tx + Math.cos(a) * 3.4, 4.4 + (i % 3) * 0.3, tz + Math.sin(a) * 3.4, tree);
    l.castShadow = false; lanterns.push(l);
  }
  // benches ring
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 + 0.3;
    const b = mesh(box(1.6, 0.4, 0.5), M(C.wood), tx + Math.cos(a) * 5, 0.45, tz + Math.sin(a) * 5, tree);
    b.rotation.y = -a + Math.PI / 2;
  }

  // ---------- Library L1: broad two-storey, rounded reading-room roof ----------
  const lib = landmark('library');
  const lx = 12, lz = 0;
  mesh(box(7.6, 3.8, 6.4), M(C.lime), lx, 2.0, lz, lib);
  mesh(box(7.9, 0.3, 6.7), M('#e9d2b2'), lx, 3.95, lz, lib);
  const vault = new T.CylinderGeometry(2.7, 2.7, 7.2, 10, 1, false, 0, Math.PI);
  vault.rotateZ(Math.PI / 2);
  mesh(vault, M(C.copper, { side: T.DoubleSide }), lx, 4.05, lz, lib);
  const dome = new T.SphereGeometry(1.5, 8, 4, 0, Math.PI * 2, 0, Math.PI / 2);
  mesh(dome, M(C.copper), lx + 2.6, 4.1, lz + 2.4, lib);
  for (let i = 0; i < 5; i++) {
    mesh(box(0.8, 1.1, 0.1), windowMat, lx - 3 + i * 1.5, 1.4, lz + 3.22, lib).castShadow = false;
    mesh(box(0.8, 1.1, 0.1), windowMat, lx - 3 + i * 1.5, 3.0, lz + 3.22, lib).castShadow = false;
    mesh(box(0.1, 1.1, 0.8), windowMat, lx - 3.82, 1.4 + (i % 2) * 1.6, lz - 2.2 + i * 1.1, lib).castShadow = false;
  }
  [[lx - 1.4], [lx + 1.4]].forEach(([x]) => mesh(box(0.7, 2.2, 0.08), M(C.yellow), x, 2.4, lz + 3.3, lib));

  // ---------- Downtown D1: three towers to the north ----------
  const dt = landmark('downtown');
  [[-2.5, -14, 7.5], [5, -15, 9], [12.5, -14, 7.5]].forEach(([x, z, h]) => {
    mesh(box(4.2, h, 4.2), M(C.lime), x, h / 2 + 0.2, z, dt);
    mesh(box(4.6, 0.4, 4.6), M('#e3c9a6'), x, h + 0.4, z, dt);
    mesh(new T.ConeGeometry(0.5, 1.4, 4), M('#d9a441'), x, h + 1.3, z, dt);
    for (let r = 1; r < h - 1; r += 1.4) {
      for (let c = -1; c <= 1; c++) {
        mesh(box(0.7, 0.7, 0.08), windowMat, x + c * 1.2, r + 0.4, z + 2.13, dt).castShadow = false;
        mesh(box(0.08, 0.7, 0.7), windowMat, x - 2.13, r + 0.4, z + c * 1.2, dt).castShadow = false;
      }
    }
  });

  // ---------- Tram boulevard S1: two tracks, cream tram with coral stripe ----------
  const tramGroup = landmark('tram');
  [9.8, 11.2].forEach((z) => mesh(box(HALF * 2 - 10, 0.12, 0.18), M('#6d6155'), 5, 0.32, z, tramGroup).castShadow = false);
  const tram = new T.Group(); tramGroup.add(tram);
  mesh(box(7.2, 1.7, 1.5), M(C.cream), 0, 1.25, 0, tram);
  mesh(box(7.25, 0.35, 1.55), M(C.coral), 0, 0.65, 0, tram);
  mesh(box(7.3, 0.6, 1.56), windowMat, 0, 1.55, 0, tram).castShadow = false;
  mesh(box(6.6, 0.18, 1.3), M('#e8dcc2'), 0, 2.2, 0, tram);
  tram.position.set(3, 0, 10.5);
  // Stop south of the square
  mesh(box(3.2, 0.12, 1.2), M(C.yellow), 3, 2.1, 12.8, tramGroup);
  [1.7, 4.3].forEach((x) => mesh(box(0.12, 1.8, 0.12), M(C.dark), x, 1.1, 12.8, tramGroup));

  // ---------- Houses, palms, lamps, park ----------
  function house(x, z, s, rot) {
    const g = new T.Group();
    const h = 1.6 + rnd() * 1.4;
    mesh(box(2.4 * s, h, 2.2 * s), M(rnd() > 0.5 ? C.lime : '#f3d9bf'), 0, h / 2 + 0.2, 0, g);
    const roof = new T.ConeGeometry(1.9 * s, 1.2, 4); roof.rotateY(Math.PI / 4);
    mesh(roof, M(rnd() > 0.4 ? C.roof : C.roof2), 0, h + 0.8, 0, g);
    mesh(box(0.5, 0.6, 0.06), windowMat, 0.4, h * 0.55, 1.12 * s, g).castShadow = false;
    g.position.set(x, 0, z); g.rotation.y = rot || 0; world.add(g);
  }
  [[16, -8], [19.5, -8.5], [16.5, 5.5], [20, 4.5], [20, -1.5], [-9, 15.5], [-5, 16], [-1, 16.5], [9, 17], [13, 16.5], [17.5, 17.5], [20.5, 13], [-9, -8.5], [-6, -19], [18, -18.5], [20.5, -14]].forEach(([x, z], i) => house(x, z, 0.8 + rnd() * 0.3, (i % 3) * 0.2));

  function palm(x, z, h) {
    const g = new T.Group();
    const tr = new T.CylinderGeometry(0.12, 0.2, h, 5);
    const t1 = mesh(tr, M('#9a7048'), 0, h / 2, 0, g); t1.rotation.z = 0.08;
    for (let i = 0; i < 6; i++) {
      const lf = new T.ConeGeometry(0.45, 2.4, 3); lf.translate(0, 1.2, 0); lf.scale(1, 1, 0.3);
      const m = mesh(lf, M(i % 2 ? C.leaf : C.leaf3), 0.1, h, 0, g);
      m.rotation.y = (i / 6) * Math.PI * 2; m.rotation.z = 1.25;
    }
    g.position.set(x, 0, z); g.rotation.y = rnd() * 6; world.add(g);
  }
  for (let x = -9; x <= 20; x += 3.6) { palm(x, 8.3, 3.6 + rnd()); palm(x + 1.8, 13.3, 3.4 + rnd()); }
  for (let z = -18; z <= 18; z += 4.5) palm(-11.2, z + rnd(), 3.4 + rnd());
  [[-8, 5], [-10, 10], [-6, 11]].forEach(([x, z]) => {
    const g = new T.IcosahedronGeometry(1.3, 0); jitter(g, 0.4);
    mesh(g, M(C.leaf2), x, 2.2, z, world);
    mesh(new T.CylinderGeometry(0.15, 0.2, 1.6, 5), M(C.trunk), x, 0.9, z, world);
  });

  const lamps = [];
  [[-1, 7.6], [7, 7.6], [15, 7.6], [-1, -6.5], [7, -6.5], [-10.5, -6], [-10.5, 6]].forEach(([x, z]) => {
    mesh(new T.CylinderGeometry(0.07, 0.09, 2.6, 4), M(C.dark), x, 1.5, z, world);
    const hd = mesh(new T.OctahedronGeometry(0.28, 0), lampMat, x, 2.9, z, world); hd.castShadow = false; lamps.push(hd);
  });

  // Clouds and stars
  const clouds = [];
  [[-10, 20, -14], [14, 22, 6], [2, 24, -24]].forEach(([x, y, z]) => {
    const g = new T.Group();
    [[0, 0, 0, 2], [1.8, -0.3, 0.4, 1.5], [-1.7, -0.4, -0.2, 1.4]].forEach(([a, b, c, r]) => {
      const geo = new T.IcosahedronGeometry(r, 0); jitter(geo, 0.4);
      const m = new T.Mesh(geo, M('#ffffff', { transparent: true, opacity: 0.95, emissive: '#ffffff', emissiveIntensity: 0.5 })); m.position.set(a, b, c); g.add(m);
    });
    g.position.set(x, y, z); scene.add(g); clouds.push(g);
  });
  const starGeo = new T.BufferGeometry();
  const sp = [];
  for (let i = 0; i < 300; i++) { const a = rnd() * Math.PI * 2; const e = 0.15 + rnd() * 1.2; const r = 160; sp.push(Math.cos(a) * Math.cos(e) * r, Math.sin(e) * r, Math.sin(a) * Math.cos(e) * r); }
  starGeo.setAttribute('position', new T.Float32BufferAttribute(sp, 3));
  const starMat = new T.PointsMaterial({ color: '#fff6d8', size: 1.1, transparent: true, opacity: 0, sizeAttenuation: true });
  scene.add(new T.Points(starGeo, starMat));

  // Selection ring
  const ring = new T.Mesh(new T.TorusGeometry(1, 0.12, 4, 12), new T.MeshBasicMaterial({ color: '#fdd657' }));
  ring.rotation.x = -Math.PI / 2;
  scene.add(ring);

  // ---------- Lights ----------
  const hemi = new T.HemisphereLight('#fff4e0', '#8a6a4a', 1.2);
  scene.add(hemi);
  const sun = new T.DirectionalLight('#fff1d6', 2.6);
  sun.castShadow = true;
  sun.shadow.mapSize.set(1536, 1536);
  Object.assign(sun.shadow.camera, { left: -32, right: 32, top: 32, bottom: -32, near: 1, far: 140 });
  sun.shadow.bias = -0.0006;
  scene.add(sun);
  const warm = [new T.PointLight('#ffb74a', 0, 26, 1.6), new T.PointLight('#ffcf70', 0, 22, 1.6), new T.PointLight('#ffb74a', 0, 22, 1.6)];
  warm[0].position.set(tx, 4.5, tz); warm[1].position.set(lx, 3, lz + 5); warm[2].position.set(wx + 5, 3, wz);
  warm.forEach((l) => scene.add(l));

  // ---------- Day and night ----------
  const lerp = (a, b, t) => a + (b - a) * t;
  const col = (a, b, t) => new T.Color(a).lerp(new T.Color(b), t);
  const skyTop = ['#7fcbe8', '#f2a86b', '#0f1d3d'];
  const skyBot = ['#e9f5f2', '#fbd9a8', '#2d3a64'];
  // Day holds until 0.35, golden hour peaks at 0.55, full night from 0.85.
  function mix3(arr, t) {
    if (t < 0.35) return new T.Color(arr[0]);
    if (t < 0.55) return col(arr[0], arr[1], (t - 0.35) / 0.2);
    return col(arr[1], arr[2], Math.min(1, (t - 0.55) / 0.3));
  }
  function phase(v) { return v < 20 ? 'Morning' : v < 42 ? 'Afternoon' : v < 60 ? 'Golden hour' : v < 78 ? 'Dusk' : 'Night'; }
  function setTime(v) {
    const t = v / 100;
    const night = Math.max(0, (t - 0.5) / 0.5);
    const dusk = Math.min(1, t * 1.6);
    const a = lerp(-0.3, Math.PI * 0.95, t);
    sun.position.set(Math.cos(a) * 40, lerp(46, 10, t) + 4, Math.sin(a) * 30 - 10);
    sun.intensity = lerp(2.8, 0.35, Math.min(1, t * 1.15));
    sun.color = col('#fff1d6', t > 0.6 ? '#9fb4ff' : '#ffb070', Math.min(1, dusk));
    hemi.intensity = lerp(1.25, 0.45, t);
    hemi.color = mix3(['#fff4e0', '#ffd8b0', '#6d7fb8'], t);
    hemi.groundColor = col('#8a6a4a', '#1d2238', t);
    windowMat.emissiveIntensity = Math.max(0, (t - 0.45) / 0.55) * 1.6;
    lampMat.emissiveIntensity = Math.max(0, (t - 0.5) / 0.5) * 3;
    lanternMat.emissiveIntensity = Math.max(0, (t - 0.45) / 0.55) * 2.4;
    warm.forEach((l) => { l.intensity = night * 55; });
    starMat.opacity = Math.max(0, (t - 0.65) / 0.35);
    clouds.forEach((c) => c.children.forEach((m) => { m.material.opacity = lerp(0.95, 0.25, night); m.material.color = col('#ffffff', '#6a76a8', night); m.material.emissiveIntensity = lerp(0.5, 0.05, Math.min(1, t * 1.4)); }));
    const top = mix3(skyTop, t), bot = mix3(skyBot, t);
    stage.style.setProperty('--sky-top', `#${top.getHexString()}`);
    stage.style.setProperty('--sky-bot', `#${bot.getHexString()}`);
    stage.classList.toggle('is-night', t > 0.62);
    const p = phase(v);
    out.textContent = p;
    slider.setAttribute('aria-valuetext', p);
    requestRender();
  }
  slider.addEventListener('input', () => setTime(+slider.value));

  // ---------- Landmarks, pins and picking ----------
  const PIN_POS = { tree: [tx, 9.4, tz], library: [lx, 7.6, lz], bridge: [-HALF + 4.5, 3.6, bz], workshop: [wx, 5.2, wz], tram: [tram.position.x, 3.6, 10.5], downtown: [5, 11.5, -15] };
  const coreToKey = {}; const keyToLm = {};
  D.LANDMARKS.forEach((lm) => { coreToKey[lm.core] = lm.key; keyToLm[lm.key] = lm; });
  const pins = {};
  D.LANDMARKS.forEach((lm) => {
    const b = Kit.el('button', { type: 'button', class: 'pin', tabindex: '-1', style: `--accent:${lm.color}` });
    b.innerHTML = `<span class="ico">${D.svgIcon(lm.icon)}</span><span class="pin-label">${lm.name}</span>`;
    b.addEventListener('click', () => D.open(lm.core, { fly: true, focus: false }));
    pinsLayer.append(b);
    pins[lm.key] = b;
  });
  const v3 = new T.Vector3();
  function placePins() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    Object.entries(pins).forEach(([k, b]) => {
      const p = k === 'tram' ? [tram.position.x, 3.6, 10.5] : PIN_POS[k];
      v3.set(p[0], p[1], p[2]).project(camera);
      const vis = v3.z < 1 && Math.abs(v3.x) < 1.1 && Math.abs(v3.y) < 1.1;
      b.style.transform = `translate(${((v3.x + 1) / 2) * w}px, ${((1 - v3.y) / 2) * h}px) translate(-50%, -100%)`;
      b.style.visibility = vis ? 'visible' : 'hidden';
      b.classList.toggle('on', D.current && keyToLm[k].core === D.current);
    });
  }

  const ray = new T.Raycaster();
  const ndc = new T.Vector2();
  let down = null;
  canvas.addEventListener('pointerdown', (e) => { down = [e.clientX, e.clientY]; pauseSpin(true); });
  canvas.addEventListener('pointerup', (e) => {
    if (!down || Math.hypot(e.clientX - down[0], e.clientY - down[1]) > 6) return;
    const r = canvas.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    const hit = ray.intersectObjects(world.children, true)[0];
    let o = hit && hit.object;
    while (o && !(o.userData && o.userData.key)) o = o.parent;
    if (o && keyToLm[o.userData.key]) D.open(keyToLm[o.userData.key].core, { fly: true });
  });
  canvas.addEventListener('pointermove', (e) => {
    const r = canvas.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    ray.setFromCamera(ndc, camera);
    const hit = ray.intersectObjects(world.children, true)[0];
    let o = hit && hit.object;
    while (o && !(o.userData && o.userData.key)) o = o.parent;
    canvas.style.cursor = o && keyToLm[o.userData.key] ? 'pointer' : 'grab';
  });

  // Camera fly to a landmark
  let fly = null;
  D.onOpen((core, o) => {
    const key = coreToKey[core];
    const p = key === 'tram' ? [tram.position.x, 0, 10.5] : PIN_POS[key];
    ring.position.set(p[0], 0.5, p[2]);
    const s = key === 'downtown' ? 9 : key === 'tram' ? 5 : key === 'bridge' ? 7 : 5.5;
    ring.scale.set(s, s, 1);
    if (o.fly) {
      const to = new T.Vector3(p[0] * 0.5 + 1, TY, p[2] * 0.5 + TZ);
      if (reduced) { controls.target.copy(to); controls.update(); }
      else fly = { from: controls.target.clone(), to, t0: performance.now() };
    }
    requestRender();
  });
  const cur = D.current && coreToKey[D.current];
  if (cur) { const p = PIN_POS[cur]; ring.position.set(p[0], 0.5, p[2]); ring.scale.set(5.5, 5.5, 1); }

  // Turntable control
  let spinning = !reduced;
  let idleTimer = 0;
  function syncSpin() {
    controls.autoRotate = spinning;
    spinBtn.setAttribute('aria-pressed', String(spinning));
    spinBtn.textContent = spinning ? 'Pause turntable' : 'Spin turntable';
    requestRender();
  }
  function pauseSpin(temporary) {
    if (!spinning) return;
    controls.autoRotate = false;
    clearTimeout(idleTimer);
    if (temporary) idleTimer = setTimeout(() => { controls.autoRotate = spinning; }, 5000);
  }
  spinBtn.addEventListener('click', () => { spinning = !spinning; clearTimeout(idleTimer); syncSpin(); if (spinning) kick(); });
  syncSpin();

  // ---------- Render loop ----------
  function resize() {
    const w = canvas.clientWidth, h = canvas.clientHeight;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camera.aspect = w / h;
    // Pull back on narrow screens so the whole plinth fits.
    camera.fov = w / h < 0.9 ? 44 : w / h < 1.3 ? 36 : 30;
    camera.updateProjectionMatrix();
    requestRender();
  }
  var needsRender = true;
  var looping = false;
  function requestRender() { needsRender = true; if (!looping) requestAnimationFrame(frameOnce); }
  function frameOnce() { if (!looping) draw(performance.now()); }
  var visible = true;
  function draw(now) {
    if (fly) {
      const k = Math.min(1, (now - fly.t0) / 900);
      const e = 1 - Math.pow(1 - k, 3);
      controls.target.lerpVectors(fly.from, fly.to, e);
      if (k >= 1) fly = null;
    }
    if (!reduced) {
      const tt = now / 1000;
      tram.position.x = 5 + Math.sin(tt * 0.25) * 12;
      boats.forEach((b, i) => { b.position.y = Math.sin(tt * 1.3 + i) * 0.08; b.rotation.z = Math.sin(tt + i) * 0.05; });
      clouds.forEach((c, i) => { c.position.x += 0.01 * (i + 1); if (c.position.x > 34) c.position.x = -34; });
      ring.position.y = 0.5 + Math.sin(tt * 3) * 0.15;
      if (D.current === 'tradeoffs') ring.position.x = tram.position.x;
    }
    controls.update();
    renderer.render(scene, camera);
    placePins();
    needsRender = false;
  }
  function loop(now) {
    if (!looping) return;
    draw(now);
    requestAnimationFrame(loop);
  }
  function kick() { if (!reduced && visible && !looping) { looping = true; requestAnimationFrame(loop); } }
  if (reduced) controls.addEventListener('change', requestRender);
  new IntersectionObserver(([e]) => { visible = e.isIntersecting; if (visible) kick(); else looping = false; }).observe(stage);
  document.addEventListener('visibilitychange', () => { if (document.hidden) looping = false; else kick(); });
  window.addEventListener('resize', resize);
  new ResizeObserver(resize).observe(canvas);
  resize();
  setTime(+slider.value);
  draw(performance.now());
  kick();
})();
