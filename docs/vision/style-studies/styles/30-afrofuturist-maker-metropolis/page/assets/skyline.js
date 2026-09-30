// Illustrative skyline for the 30 page (original art, not a concept sheet): patterned tapered spires,
// a great tree and tree-shaped shade canopies, a domed library with lattice, a cable-stayed bridge,
// the river and the tram as clear lines, and a solar-panelled maker district in the foreground.
window.Art30 = (function () {
  const C = { plum: '#2a1f37', copper: '#8b562f', burnt: '#6a3613', ochre: '#b28a53', gold: '#efc993', teal: '#13546a', dome: '#51a7ab', indigo: '#252d3d', leaf: '#3f6b3a' };

  const defs = `<defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1b1426"/><stop offset=".55" stop-color="#3a2745"/><stop offset=".85" stop-color="#8b562f"/><stop offset="1" stop-color="#d49a5c"/></linearGradient>
    <linearGradient id="water" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#2d718c"/><stop offset="1" stop-color="#13546a"/></linearGradient>
    <pattern id="pA" width="24" height="24" patternUnits="userSpaceOnUse"><rect width="24" height="24" fill="${C.copper}"/><path d="M0 12 L12 0 L24 12 L12 24Z" fill="${C.ochre}"/><path d="M6 12 L12 6 L18 12 L12 18Z" fill="${C.indigo}"/><path d="M0 0h24" stroke="${C.gold}" stroke-width="1.4"/></pattern>
    <pattern id="pB" width="20" height="20" patternUnits="userSpaceOnUse"><rect width="20" height="20" fill="${C.teal}"/><path d="M0 20 L10 6 L20 20Z" fill="${C.burnt}"/><path d="M5 20 L10 13 L15 20Z" fill="${C.gold}"/></pattern>
    <pattern id="pC" width="16" height="16" patternUnits="userSpaceOnUse"><rect width="16" height="16" fill="${C.indigo}"/><path d="M0 4 L4 0 L8 4 L12 0 L16 4 M0 12 L4 8 L8 12 L12 8 L16 12" fill="none" stroke="${C.ochre}" stroke-width="2"/></pattern>
    <pattern id="pD" width="18" height="18" patternUnits="userSpaceOnUse"><rect width="18" height="18" fill="${C.burnt}"/><rect x="3" y="3" width="12" height="12" fill="none" stroke="${C.gold}" stroke-width="1.6"/><rect x="7" y="7" width="4" height="4" fill="${C.dome}"/></pattern>
    <pattern id="lat" width="10" height="10" patternUnits="userSpaceOnUse"><path d="M0 0 L10 10 M10 0 L0 10" stroke="${C.gold}" stroke-width="1" opacity=".75"/></pattern>
  </defs>`;

  // A tapered patterned spire: base width w at y=base, top width w*0.3, with a needle.
  function tower(x, base, w, h, pat, i) {
    const t = w * 0.3;
    const d = `M${x - w / 2} ${base} L${x - t / 2} ${base - h} L${x + t / 2} ${base - h} L${x + w / 2} ${base}Z`;
    const wins = [];
    for (let k = 1; k < 6; k++) {
      const y = base - (h * k) / 6;
      const half = (w / 2 - ((w - t) / 2) * (k / 6)) * 0.55;
      wins.push(`<rect class="win" style="animation-delay:calc(var(--beat) * ${(i + k) % 4})" x="${x - half}" y="${y - 3}" width="${half * 2}" height="4" fill="${C.gold}"/>`);
    }
    return `<g><path d="${d}" fill="url(#${pat})" stroke="${C.gold}" stroke-width="2"/>${wins.join('')}
      <path d="M${x} ${base - h} V${base - h - h * 0.18}" stroke="${C.gold}" stroke-width="2.4"/><circle cx="${x}" cy="${base - h - h * 0.18}" r="3" fill="${C.dome}" class="blink" style="animation-delay:calc(var(--beat) * ${i % 2})"/></g>`;
  }
  function canopy(x, y, r) {
    return `<g><path d="M${x - 5} ${y + 70} L${x - 3} ${y} L${x + 3} ${y} L${x + 5} ${y + 70}Z" fill="${C.copper}" stroke="${C.gold}" stroke-width="1.5"/>
      <path d="M${x - r} ${y + 6} Q${x} ${y - r * 0.55} ${x + r} ${y + 6} Q${x} ${y - 4} ${x - r} ${y + 6}Z" fill="url(#pB)" stroke="${C.gold}" stroke-width="2"/></g>`;
  }

  function skyline() {
    const towers = [
      [150, 360, 58, 200, 'pA'], [236, 360, 46, 250, 'pC'], [318, 360, 64, 170, 'pD'], [410, 360, 52, 290, 'pB'],
      [760, 360, 56, 270, 'pA'], [846, 360, 44, 210, 'pD'], [930, 360, 66, 320, 'pC'], [1026, 360, 50, 230, 'pB'], [1110, 360, 58, 180, 'pA']
    ].map((t, i) => tower(...t, i)).join('');
    return `<svg viewBox="0 0 1200 520" preserveAspectRatio="xMinYMax slice" aria-hidden="true" focusable="false" class="sky-svg">${defs}
      <rect width="1200" height="520" fill="url(#sky)"/>
      <g class="sun"><circle cx="600" cy="170" r="92" fill="${C.copper}" opacity=".55"/><circle cx="600" cy="170" r="92" fill="url(#lat)" opacity=".7"/><circle cx="600" cy="170" r="70" fill="none" stroke="${C.gold}" stroke-width="2"/></g>
      ${towers}
      <g><path d="M470 360 Q600 240 730 360Z" fill="url(#lat)" stroke="${C.gold}" stroke-width="2"/></g>
      <rect x="0" y="356" width="1200" height="10" fill="${C.indigo}"/>
      <g>
        <path d="M578 470 C584 430 580 380 566 350 L588 346 C600 372 602 392 602 404 C606 386 616 366 630 350 L646 358 C628 384 622 430 628 470Z" fill="#5a3322" stroke="${C.gold}" stroke-width="2"/>
        <ellipse cx="604" cy="318" rx="130" ry="58" fill="${C.leaf}" stroke="${C.gold}" stroke-width="2"/>
        <ellipse cx="540" cy="300" rx="66" ry="36" fill="#4d7d44" stroke="${C.gold}" stroke-width="1.6"/>
        <ellipse cx="672" cy="296" rx="70" ry="38" fill="#4d7d44" stroke="${C.gold}" stroke-width="1.6"/>
        <ellipse cx="606" cy="276" rx="60" ry="32" fill="#5a8e4e" stroke="${C.gold}" stroke-width="1.6"/>
      </g>
      ${canopy(430, 392, 70)}${canopy(780, 392, 76)}
      <g><path d="M880 470 V420 Q960 330 1040 420 V470Z" fill="${C.dome}" stroke="${C.gold}" stroke-width="2.4"/><path d="M880 470 V420 Q960 330 1040 420 V470Z" fill="url(#lat)"/>
        <path d="M870 470 H1050 V480 H870Z" fill="${C.copper}"/></g>
      <g><path d="M40 470 V420 L90 440 V420 L140 440 V420 L190 440 V470Z" fill="${C.burnt}" stroke="${C.gold}" stroke-width="2"/>
        <path d="M44 418 L88 436 M94 418 L138 436 M144 418 L188 436" stroke="${C.dome}" stroke-width="5"/>
        <circle cx="236" cy="448" r="20" fill="${C.gold}" stroke="${C.copper}" stroke-width="3"/><circle cx="236" cy="448" r="20" fill="url(#lat)"/></g>
      <path d="M0 470 H1200 V520 H0Z" fill="url(#water)"/>
      <g stroke="${C.gold}" stroke-width="1.5" fill="none" opacity=".7"><path d="M20 492 h60 M160 506 h90 M340 494 h50 M520 508 h80 M700 494 h60 M900 506 h90 M1080 494 h70"/></g>
      <g><path d="M300 486 H1200" stroke="${C.gold}" stroke-width="5"/><path d="M340 486 V396" stroke="${C.gold}" stroke-width="7"/>
        ${[300, 260, 220].map((dx) => `<path d="M340 400 L${340 - dx * 0.25} 486 M340 400 L${340 + dx * 0.4} 486" stroke="${C.gold}" stroke-width="1.4"/>`).join('')}</g>
      <path d="M0 462 H1200" stroke="${C.ochre}" stroke-width="3" stroke-dasharray="14 8"/>
      <g class="tram"><rect x="0" y="446" width="130" height="16" rx="6" fill="${C.gold}" stroke="${C.indigo}" stroke-width="2"/><path d="M8 452 H122" stroke="${C.indigo}" stroke-width="5" stroke-dasharray="14 6"/></g>
    </svg>`;
  }

  const a1 = `<svg viewBox="0 0 220 240" role="img" aria-label="Illustrative drawing of City Agent A1 in this style: a near-human figure with stacked gold collar rings and a glowing blue ear ring, in a white jacket with a geometric panel.">
    <rect width="220" height="240" fill="${C.indigo}"/>
    <rect width="220" height="240" fill="url(#pC)" opacity=".35"/>
    <path d="M30 240 Q36 176 110 164 Q184 176 190 240Z" fill="#efe7da" stroke="${C.gold}" stroke-width="2"/>
    <path d="M96 170 L110 240 L124 170Z" fill="url(#pA)" stroke="${C.gold}" stroke-width="1.5"/>
    <path d="M40 212 Q50 186 76 176" fill="none" stroke="${C.dome}" stroke-width="3" class="glow"/>
    <rect x="90" y="120" width="40" height="50" fill="#5c3a26"/>
    ${[128, 138, 148, 158].map((y) => `<rect x="86" y="${y}" width="48" height="7" rx="3" fill="${C.gold}" stroke="${C.burnt}" stroke-width="1"/>`).join('')}
    <path d="M72 70 Q72 26 110 26 Q148 26 148 70 Q148 110 110 124 Q72 110 72 70Z" fill="#6b4630"/>
    <path d="M78 52 Q110 34 142 52" fill="none" stroke="#4a2f20" stroke-width="3"/>
    <circle cx="94" cy="74" r="3.5" fill="#1b1426"/><circle cx="126" cy="74" r="3.5" fill="#1b1426"/>
    <path d="M100 98 Q110 104 120 98" fill="none" stroke="#1b1426" stroke-width="2.4"/>
    <circle cx="148" cy="80" r="12" fill="none" stroke="${C.dome}" stroke-width="5" class="glow"/>
    <circle cx="148" cy="80" r="4" fill="#bff3f2"/>
  </svg>`;

  return { skyline, a1, defs };
})();
