// Illustrative art for the 29 page, drawn in the study's line grammar: double outlines, flat fills,
// hatching and fish / bird / lotus / tree motifs. Original drawing for this page; not a concept sheet.
window.Art29 = (function () {
  const INK = '#11100f', PAPER = '#f6f4ec', RED = '#af3726', DEEP = '#8d2f21', GREEN = '#4f7547', RIVER = '#1a6482', GROUND = '#e8ceb1', TURMERIC = '#d38a50';

  // Double-line grammar: fill, then a wide ink stroke, then a thin paper stroke on top.
  const dl = (d, fill, cls) => `<g class="${cls || ''}"><path d="${d}" fill="${fill}"/><path d="${d}" class="o1"/><path d="${d}" class="o2"/></g>`;
  const one = (d, fill, w) => `<path d="${d}" fill="${fill || 'none'}" stroke="${INK}" stroke-width="${w || 2}" stroke-linejoin="round" stroke-linecap="round"/>`;

  function fish(x, y, s, fill) {
    const k = s || 1;
    const t = `translate(${x} ${y}) scale(${k})`;
    return `<g transform="${t}">${dl('M-20 0 Q0 -13 16 0 Q0 13 -20 0Z', fill || TURMERIC)}${dl('M14 0 L27 -10 L27 10Z', fill || TURMERIC)}
      <circle cx="-11" cy="-1.5" r="3.2" fill="${PAPER}" stroke="${INK}" stroke-width="1.5"/><circle cx="-11" cy="-1.5" r="1.2" fill="${INK}"/>
      <path d="M-4 -6 q3 6 0 12 M2 -6 q3 6 0 12 M8 -4 q2 4 0 8" fill="none" stroke="${INK}" stroke-width="1.2"/></g>`;
  }
  function leaf(x, y, rot, fill, k) {
    return `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${k || 1})"><path d="M0 0 Q7 -8 16 0 Q7 8 0 0Z" fill="${fill}" stroke="${INK}" stroke-width="1.4"/><path d="M1 0 H14" stroke="${INK}" stroke-width="1"/></g>`;
  }
  function lotus(cx, cy, r) {
    const k = r / 30;
    const petal = 'M0 0 Q-9 -16 0 -30 Q9 -16 0 0Z';
    const petals = [-64, -32, 0, 32, 64].map((a) => `<path d="${petal}" transform="rotate(${a})" fill="${a === 0 ? RED : '#d9674a'}" stroke="${INK}" stroke-width="1.6"/>`).join('');
    return `<g transform="translate(${cx} ${cy + 10 * k}) scale(${k})">${petals}<path d="M-16 2 Q0 12 16 2" fill="none" stroke="${INK}" stroke-width="1.6"/></g>`;
  }
  function bird(x, y, k, flip) {
    return `<g transform="translate(${x} ${y}) scale(${flip ? -k : k} ${k})">
      ${dl('M-18 4 Q-4 -12 14 -4 Q18 8 2 12 Q-12 14 -18 4Z', RED)}
      ${dl('M10 -6 Q14 -16 22 -10 Q24 -4 18 -2Z', RED)}
      <path d="M22 -10 L30 -8 L22 -6Z" fill="${TURMERIC}" stroke="${INK}" stroke-width="1.2"/>
      <circle cx="18" cy="-9" r="2.2" fill="${PAPER}" stroke="${INK}" stroke-width="1"/>
      <path d="M-18 4 L-30 -4 L-28 8Z" fill="${INK}"/>
      <path d="M-6 0 q6 4 12 0 M-8 5 q7 4 14 0" fill="none" stroke="${PAPER}" stroke-width="1.2"/></g>`;
  }
  function person(x, y, sari) {
    return `<g transform="translate(${x} ${y})">
      <path d="M-9 0 L9 0 L13 34 L-13 34Z" fill="${sari}" stroke="${INK}" stroke-width="1.8" stroke-linejoin="round"/>
      <path d="M-11 18 H11 M-12 26 H12" stroke="${INK}" stroke-width="1" class="d-hatch"/>
      <circle cx="0" cy="-9" r="8" fill="${TURMERIC}" stroke="${INK}" stroke-width="1.8"/>
      <path d="M-8 -12 Q0 -20 8 -10 Q2 -16 -6 -8Z" fill="${INK}"/>
      <path d="M2 -10 q3 -2 5 0 q-3 2 -5 0Z" fill="${PAPER}" stroke="${INK}" stroke-width="1"/></g>`;
  }

  function city() {
    const riverD = 'M0 0 H112 C96 110 132 220 106 330 C98 380 112 420 106 440 H0Z';
    const out = [];
    out.push(`<svg viewBox="0 0 640 440" role="img" aria-labelledby="cityTitle" class="city">
      <title id="cityTitle">Illustrative drawing of the reference district: River on the west with fish, the North bridge across it, the Workshop with a sawtooth roof, Tree Square with one large tree, the Library with a lotus roundel, and the tram boulevard along the south with a cream tram.</title>
      <defs>
        <pattern id="hx" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><path d="M0 0V6" stroke="${INK}" stroke-width="1.1"/></pattern>
        <pattern id="hy" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(-45)"><path d="M0 0V7" stroke="${INK}" stroke-width=".9"/></pattern>
        <pattern id="dots" width="10" height="10" patternUnits="userSpaceOnUse"><circle cx="5" cy="5" r="1.4" fill="${INK}"/></pattern>
        <clipPath id="riverClip"><path d="${riverD}"/></clipPath>
      </defs>
      <rect width="640" height="440" fill="${PAPER}"/>
      <g class="d-hatch"><rect x="0" y="392" width="640" height="48" fill="url(#dots)" opacity=".5"/></g>
      <circle cx="584" cy="54" r="26" fill="${RED}" stroke="${INK}" stroke-width="2.4"/>
      <g class="d-motif">${[0, 45, 90, 135, 180, 225, 270, 315].map((a) => `<path d="M584 54 m0 -34 v-10" stroke="${RED}" stroke-width="3" transform="rotate(${a} 584 54)"/>`).join('')}</g>`);

    // Neighbourhood blocks and street trees: colour blocks first, as the brief asks at map scale
    const house = (x, y, w) => `${dl(`M${x} ${y} L${x + w / 2} ${y - 12} L${x + w} ${y}Z`, RED)}${dl(`M${x} ${y} H${x + w} V${y + 18} H${x}Z`, GROUND)}<path d="M${x + w / 2 - 3} ${y + 18} v-8 q3 -4 6 0 v8" fill="${INK}"/>`;
    const tree = (x, y) => `<path d="M${x} ${y + 12} V${y + 2}" stroke="${INK}" stroke-width="2"/><circle cx="${x}" cy="${y - 2}" r="8" fill="${GREEN}" stroke="${INK}" stroke-width="1.8"/><circle cx="${x + 2}" cy="${y - 4}" r="1.8" fill="${RED}" class="d-motif"/>`;
    const blocks = [[196, 108, 34], [240, 108, 30], [468, 112, 30], [506, 104, 28], [140, 296, 36], [186, 296, 30], [228, 300, 34], [482, 300, 34], [528, 300, 30], [572, 300, 36]].map(([x, y, w]) => house(x, y, w)).join('');
    const trees = [[134, 126], [160, 134], [276, 140], [478, 144], [620, 110], [126, 280], [270, 290], [470, 286], [620, 292], [300, 104], [460, 104]].map(([x, y]) => tree(x, y)).join('');
    out.push(`<g class="blocks">
      <g class="d-hatch"><path d="M120 276 H640 M120 304 V340 M640 276" stroke="${INK}" stroke-width="1" stroke-dasharray="3 5" fill="none"/></g>
      <path d="M118 102 H640 M118 336 H640" stroke="${INK}" stroke-width="2.2" fill="none"/><path d="M118 108 H640 M118 330 H640" stroke="${INK}" stroke-width="1" fill="none"/>
      ${blocks}${trees}</g>`);

    // River
    out.push(`<g data-lm="river">${dl(riverD, RIVER)}
      <g clip-path="url(#riverClip)" class="d-hatch">${[40, 80, 120, 160, 200, 240, 280, 320, 360, 400].map((y) => `<path d="M-10 ${y} q14 -8 28 0 t28 0 t28 0 t28 0 t28 0" fill="none" stroke="${PAPER}" stroke-width="1.6"/>`).join('')}</g>
      ${fish(52, 190, 1)}
      <g class="d-motif">${fish(58, 290, 0.8, '#d9674a')}${fish(46, 380, 0.9)}${lotus(78, 130, 12)}</g></g>`);

    // North bridge across the river
    out.push(`<g data-lm="bridge">${dl('M-4 58 H176 V96 H150 Q140 76 124 96 H96 Q84 74 70 96 H44 Q32 76 18 96 H-4Z', RED)}
      <g class="d-hatch"><path d="M-4 66 H176" stroke="${PAPER}" stroke-width="1.4"/><path d="M8 58 V66 M28 58 V66 M48 58 V66 M68 58 V66 M88 58 V66 M108 58 V66 M128 58 V66 M148 58 V66 M168 58 V66" stroke="${INK}" stroke-width="1.2"/></g>
      <g class="d-motif">${leaf(20, 78, 0, GREEN, .7)}${leaf(100, 80, 0, GREEN, .7)}${leaf(156, 80, 0, GREEN, .7)}</g></g>`);

    // Workshop: three sawtooth roof bays, entrance to the east
    out.push(`<g data-lm="workshop">
      ${dl('M236 120 H250 V168 H236Z', DEEP)}
      ${dl('M140 196 V160 L178 196 V160 L216 196 V160 L262 196Z', RED)}
      <g class="d-hatch"><path d="M140 196 V160 L178 196 V160 L216 196 V160 L262 196Z" fill="url(#hx)" opacity=".7"/></g>
      ${dl('M136 196 H266 V262 H136Z', GROUND)}
      ${one('M150 262 V232 Q160 216 170 232 V262 M184 262 V232 Q194 216 204 232 V262', PAPER)}
      ${dl('M232 262 V228 Q244 212 256 228 V262Z', INK)}
      <g class="d-motif">${fish(196, 208, .55, RED)}${leaf(142, 250, -30, GREEN, .6)}</g></g>`);

    // Tree Square: one large tree at the centre of an open square
    const leaves = [];
    for (let i = 0; i < 26; i++) {
      const a = (i / 26) * Math.PI * 2;
      const r = 52 + (i % 3) * 7;
      leaves.push(leaf(380 + Math.cos(a) * r, 176 + Math.sin(a) * r * 0.82, (a * 180) / Math.PI, i % 4 === 0 ? RED : GREEN, .9));
    }
    out.push(`<g data-lm="tree">
      <rect x="296" y="112" width="168" height="186" fill="none" class="sq1"/><rect x="302" y="118" width="156" height="174" fill="none" class="sq2"/>
      ${dl('M370 290 C372 260 368 236 356 218 L368 212 C378 228 380 240 382 250 C386 232 394 220 404 212 L412 220 C398 236 392 262 394 290Z', '#6b3b22')}
      ${dl('M380 110 C430 110 446 150 438 184 C432 222 404 236 380 234 C352 236 326 222 322 186 C316 146 334 110 380 110Z', GREEN)}
      <g class="d-hatch"><path d="M380 110 C430 110 446 150 438 184 C432 222 404 236 380 234 C352 236 326 222 322 186 C316 146 334 110 380 110Z" fill="url(#hy)" opacity=".45"/></g>
      ${[[352, 150], [398, 140], [372, 196], [414, 184], [344, 196], [388, 166]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="5" fill="${RED}" stroke="${INK}" stroke-width="1.5"/>`).join('')}
      <g class="d-motif">${leaves.join('')}${bird(430, 118, .8, true)}</g>
      ${person(318, 250, RED)}${person(446, 252, TURMERIC)}</g>`);

    // Library: broad two-storey building, rounded reading-room roof, lotus roundel
    out.push(`<g data-lm="library">
      ${dl('M498 168 Q556 110 614 168Z', RED)}
      <g class="d-hatch"><path d="M498 168 Q556 110 614 168Z" fill="url(#hx)" opacity=".6"/></g>
      ${dl('M488 168 H624 V272 H488Z', GROUND)}
      ${one('M488 220 H624')}
      ${one('M500 232 V262 M518 232 V262 M596 232 V262 M612 232 V262')}
      <circle cx="556" cy="198" r="22" fill="${PAPER}" class="sq1"/><circle cx="556" cy="198" r="22" fill="none" class="sq2"/>
      ${lotus(556, 198, 17)}
      ${dl('M540 272 V244 Q556 226 572 244 V272Z', INK)}
      <g class="d-motif">${leaf(494, 180, 0, GREEN, .7)}${leaf(598, 180, 0, GREEN, .7)}${fish(514, 250, .4, RED)}${fish(598, 250, .4, RED)}</g></g>`);

    // Tram boulevard: two tracks, cream tram with a coral stripe
    out.push(`<g data-lm="tram">
      ${one('M112 364 H640', 'none', 2.4)}${one('M110 378 H640', 'none', 2.4)}
      <g class="d-hatch">${Array.from({ length: 26 }, (_, i) => `<path d="M${122 + i * 20} 360 v22" stroke="${INK}" stroke-width="1.4"/>`).join('')}</g>
      ${one('M346 308 L358 292 L370 308 M340 292 H376', 'none', 1.6)}
      ${dl('M290 316 Q290 306 302 306 H420 Q432 306 432 316 V360 H290Z', '#f3e6cc')}
      ${dl('M290 340 H432 V350 H290Z', '#e0664a')}
      ${one('M302 314 H326 V334 H302Z M336 314 H360 V334 H336Z M370 314 H394 V334 H370Z M404 314 H424 V334 H404Z', RIVER, 1.8)}
      <circle cx="316" cy="364" r="7" fill="${INK}"/><circle cx="406" cy="364" r="7" fill="${INK}"/>
      <g class="d-motif">${fish(360, 355, .4, PAPER)}</g></g>`);

    out.push(`${bird(520, 72, .7)}</svg>`);
    return out.join('');
  }

  // Small motif roundels for panel heads
  const icon = (inner) => `<svg viewBox="-30 -30 60 60" aria-hidden="true" focusable="false"><circle r="27" fill="${PAPER}" stroke="${INK}" stroke-width="2"/><circle r="23" fill="none" stroke="${INK}" stroke-width="1.2"/>${inner}</svg>`;
  const motifs = {
    sun: icon(`<circle r="10" fill="${RED}" stroke="${INK}" stroke-width="1.6"/>${[0, 45, 90, 135, 180, 225, 270, 315].map((a) => `<path d="M0 -13 V-19" stroke="${INK}" stroke-width="2" transform="rotate(${a})"/>`).join('')}`),
    lotus: icon(lotus(0, -2, 17)),
    fish: icon(fish(-3, 0, .75)),
    bird: icon(bird(-2, 3, .7)),
    leaf: icon(`${leaf(-12, 6, -35, GREEN, 1.3)}${leaf(-2, 2, -60, RED, 1.1)}`),
    tree: icon(`<path d="M-3 18 V2 M3 18 V2" stroke="${INK}" stroke-width="2"/><circle cy="-6" r="13" fill="${GREEN}" stroke="${INK}" stroke-width="1.8"/><circle cx="-4" cy="-8" r="2.5" fill="${RED}"/><circle cx="5" cy="-3" r="2.5" fill="${RED}"/>`)
  };

  // City Agent A1 as the Conversation panel describes it: white robot in profile, large outlined eye,
  // an ear disc with a flower, red botanical motifs on the body.
  const a1 = `<svg viewBox="0 0 200 230" role="img" aria-label="Illustrative drawing of City Agent A1 in this style: a white robot in profile with a large outlined eye, an ear disc and red botanical motifs.">
    <rect width="200" height="230" fill="${PAPER}"/>
    ${dl('M40 230 Q44 170 100 158 Q156 170 164 230Z', PAPER)}
    <g>${leaf(62, 196, -60, RED, 1.3)}${leaf(78, 186, -100, GREEN, 1.1)}${leaf(128, 190, -80, RED, 1.2)}${leaf(142, 200, -40, GREEN, 1.1)}</g>
    ${one('M100 170 V226', 'none', 1.6)}
    ${dl('M86 128 H116 V162 H86Z', '#2b2a27')}
    ${dl('M70 64 Q70 22 112 20 Q150 22 154 60 L166 82 L154 88 Q156 104 146 112 L150 122 Q124 136 94 126 Q70 112 70 64Z', PAPER)}
    <path d="M110 58 Q128 44 150 58 Q128 70 110 58Z" fill="${PAPER}" stroke="${INK}" stroke-width="2.4"/>
    <circle cx="132" cy="58" r="6" fill="${INK}"/>
    <path d="M108 46 Q128 34 152 48" fill="none" stroke="${INK}" stroke-width="2.6"/>
    <circle cx="94" cy="78" r="17" fill="${RED}" stroke="${INK}" stroke-width="2.4"/><circle cx="94" cy="78" r="11" fill="${PAPER}" stroke="${INK}" stroke-width="1.6"/>
    ${lotus(94, 76, 8)}
    ${one('M146 104 Q138 108 130 104', 'none', 2)}
    <g>${leaf(80, 38, 20, RED, .9)}${leaf(96, 30, 0, GREEN, .8)}</g>
  </svg>`;

  return { city, motifs, a1 };
})();
