// Illustrative landmark vignettes for the handscroll gutters (original art for this page, not concept sheets).
// Keyblock grammar: a closed ink contour around every shape, flat pigment fills, bokashi gradients.
(function () {
  const K = 'stroke="#2e2e31" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"';
  const svg = (body, h) => `<svg viewBox="0 0 250 ${h || 300}" preserveAspectRatio="xMidYMax meet" aria-hidden="true" focusable="false">${body}</svg>`;
  const parasol = (x, y, c) => `<g ${K}><path d="M${x - 11} ${y} Q${x} ${y - 13} ${x + 11} ${y}Z" fill="${c}"/><path d="M${x} ${y}V${y + 18}" fill="none"/><path d="M${x - 4} ${y + 4}h8l3 16h-14z" fill="#192d47"/></g>`;
  const birds = (x, y) => `<g fill="none" ${K} stroke-width="1.6"><path d="M${x} ${y}q5 -5 10 0q5 -5 10 0"/><path d="M${x + 26} ${y - 10}q4 -4 8 0q4 -4 8 0"/><path d="M${x + 14} ${y - 20}q3 -3 6 0q3 -3 6 0"/></g>`;
  const hills = `<path d="M-10 250 Q40 190 90 222 Q130 170 190 214 Q225 196 260 222 V300 H-10Z" fill="url(#bk-hill)" stroke="#2e2e31" stroke-width="1.6"/>`;

  const art = {
    river: svg(`${hills}${birds(40, 110)}
      <g class="bob"><g ${K}>
        <path d="M58 272 H196 L180 292 H74 Z" fill="#8e5037"/>
        <path d="M74 272 V270" />
        <path d="M122 272 V150" fill="none"/>
        <path d="M86 160 H160 V250 H86 Z" fill="#f7eedb"/>
        <path d="M86 184 H160 M86 208 H160 M86 232 H160" fill="none" stroke-width="1.2"/>
        <circle cx="150" cy="264" r="5" fill="#f7eedb"/>
      </g></g>
      <g fill="none" ${K} stroke-width="1.5"><path d="M18 298 q8 -10 16 0 q8 -10 16 0"/><path d="M200 296 q8 -10 16 0 q8 -10 16 0"/></g>`),

    bridge: svg(`${birds(150, 70)}
      <g ${K}>
        <path d="M0 214 H250 V300 H0 Z" fill="#c9b594"/>
        <path d="M12 300 V262 Q42 226 72 262 V300 Z M96 300 V258 Q125 220 154 258 V300 Z M178 300 V262 Q208 226 238 262 V300 Z" fill="url(#bk-water)"/>
        <path d="M0 214 H250" fill="none" stroke-width="3"/>
        <path d="M0 196 H250 M0 206 H250" fill="none"/>
        <path d="M20 196 V214 M60 196 V214 M100 196 V214 M140 196 V214 M180 196 V214 M220 196 V214" fill="none"/>
        <path d="M0 232 H12 M72 238 H96 M154 238 H178 M238 232 H250" fill="none" stroke-width="1.2"/>
      </g>
      <g fill="none" stroke="#2e2e31" stroke-width="1" opacity=".55"><path d="M4 224h8M30 280h10M82 250h8M84 276h6M160 272h10M166 252h6M242 280h6"/></g>
      ${parasol(118, 170, '#ae5243')}${parasol(150, 174, '#ebb2a6')}`),

    workshop: svg(`
      <g class="smoke"><g ${K} fill="#f7eedb" stroke-width="1.6"><path d="M196 88 q-14 -2 -12 -14 q2 -12 16 -8 q10 -12 22 -2 q12 0 8 12 q-4 10 -16 8 q-8 8 -18 4z"/><path d="M204 76 q4 -6 10 -2" fill="none"/></g></g>
      <g class="smoke"><g ${K} fill="#f7eedb" stroke-width="1.6"><path d="M204 60 q-10 -2 -8 -11 q3 -9 13 -6 q8 -8 16 0 q8 2 4 10 q-5 8 -14 5 q-6 5 -11 2z"/></g></g>
      <g class="smoke"><g ${K} fill="#f7eedb" stroke-width="1.6"><path d="M212 36 q-8 -1 -6 -8 q2 -7 10 -4 q6 -6 12 0 q5 3 1 8 q-4 5 -10 3z"/></g></g>
      <g ${K}>
        <path d="M190 106 H212 V190 H190 Z" fill="#ae5243"/>
        <path d="M186 100 H216 V108 H186 Z" fill="#2e2e31"/>
        <path d="M14 190 V140 L14 138 L80 170 V138 L146 170 V138 L212 170 V190 Z" fill="url(#tiles)"/>
        <path d="M14 140 V170 H80 M80 140 V170 H146 M146 140 V170" fill="none"/>
        <path d="M17 145 L77 173 M83 145 L143 173 M149 145 L209 173" fill="none" stroke="#f1e3c7" stroke-width="1.2" opacity=".6"/>
        <path d="M14 140 L20 142 V168 H14 Z M80 140 L86 143 V168 H80 Z M146 140 L152 143 V168 H146 Z" fill="#9fb8c0"/>
        <path d="M10 190 H240 V272 H10 Z" fill="#8e5037"/>
        <path d="M10 214 H240" fill="none" stroke-width="1.4"/>
        <path d="M34 190 V272 M70 190 V272 M106 190 V272 M142 190 V272 M178 190 V272" fill="none" stroke-width="1.2"/>
        <path d="M196 214 H238 V272 H196 Z" fill="#192d47"/>
        <path d="M200 214 H234 V244 H200 Z" fill="#ae5243"/>
        <circle cx="217" cy="229" r="8" fill="#f7eedb"/>
        <path d="M44 226 H96 V250 H44 Z M118 226 H170 V250 H118 Z" fill="#f7eedb"/>
        <path d="M70 226 V250 M144 226 V250" fill="none" stroke-width="1.2"/>
        <path d="M0 272 H250 V300 H0 Z" fill="#d7c6a6"/>
      </g>
      <g fill="none" stroke="#2e2e31" stroke-width="1" opacity=".5"><path d="M16 286h20M60 292h24M130 284h16M190 290h30"/></g>`),

    tree: svg(`
      <g ${K}>
        <path d="M0 262 H250 V300 H0 Z" fill="#d7c6a6"/>
        <path d="M0 280 H250 M40 262 L20 300 M100 262 L94 300 M150 262 L156 300 M210 262 L230 300" fill="none" stroke-width="1.1"/>
        <path d="M112 262 C116 222 110 196 100 176 L112 172 C122 194 124 212 126 226 C130 206 140 190 152 178 L160 186 C144 204 136 226 138 262 Z" fill="#5a3322"/>
        <path d="M100 262 Q125 250 150 262" fill="#5a3322"/>
        <circle cx="70" cy="150" r="42" fill="url(#bk-green)"/>
        <circle cx="180" cy="148" r="44" fill="url(#bk-green)"/>
        <circle cx="126" cy="96" r="54" fill="url(#bk-green)"/>
        <circle cx="96" cy="176" r="30" fill="#60655d"/>
        <circle cx="160" cy="180" r="28" fill="#60655d"/>
        <circle cx="128" cy="150" r="36" fill="#6d7a62"/>
      </g>
      <g fill="none" stroke="#2e2e31" stroke-width="1.3" opacity=".75">
        <path d="M58 132 q6 -6 12 0 M78 158 q6 -6 12 0 M170 128 q6 -6 12 0 M190 158 q6 -6 12 0 M112 70 q6 -6 12 0 M134 96 q6 -6 12 0 M118 138 q6 -6 12 0 M138 160 q6 -6 12 0 M96 104 q6 -6 12 0 M150 70 q6 -6 12 0"/>
      </g>
      <g fill="#ebb2a6" stroke="#2e2e31" stroke-width="1"><circle cx="46" cy="140" r="3.5"/><circle cx="206" cy="132" r="3.5"/><circle cx="160" cy="62" r="3.5"/><circle cx="90" cy="82" r="3.5"/></g>
      ${parasol(40, 250, '#ae5243')}${parasol(214, 248, '#366a84')}`),

    library: svg(`
      <g ${K}>
        <path d="M34 150 Q125 70 216 150 Z" fill="url(#bk-indigo)"/>
        <path d="M60 150 Q125 88 190 150 M88 150 Q125 106 162 150 M125 84 V150" fill="none" stroke="#f1e3c7" stroke-width="1.3" opacity=".7"/>
        <path d="M34 150 Q125 70 216 150" fill="none" stroke-width="2.5"/>
        <path d="M14 150 H236 V272 H14 Z" fill="#efe2c2"/>
        <path d="M8 150 H242 L236 160 H14 Z M8 208 H242 L236 216 H14 Z" fill="url(#tiles)"/>
        <path d="M30 170 H56 V200 H30 Z M74 170 H100 V200 H74 Z M150 170 H176 V200 H150 Z M194 170 H220 V200 H194 Z" fill="#366a84"/>
        <path d="M30 228 H56 V262 H30 Z M194 228 H220 V262 H194 Z" fill="#366a84"/>
        <path d="M104 226 H146 V272 H104 Z" fill="#192d47"/>
        <path d="M112 176 H138 V200 H112 Z" fill="#ae5243"/>
        <path d="M117 181 H133 M117 187 H133 M117 193 H128" fill="none" stroke="#f1e3c7" stroke-width="1.4"/>
        <path d="M0 272 H250 V300 H0 Z" fill="#d7c6a6"/>
        <path d="M84 272 H166 V280 H84 Z" fill="#c9b594"/>
      </g>
      ${birds(24, 60)}`),

    tram: svg(`
      <g ${K}>
        <path d="M0 262 H250 V300 H0 Z" fill="#d7c6a6"/>
        <path d="M0 274 H250 M0 282 H250 M0 290 H250 M0 298 H250" fill="none" stroke-width="1.6"/>
        <path d="M112 128 L126 106 L140 128 M116 122 H136" fill="none" stroke-width="1.6"/>
        <path d="M0 106 H250" fill="none" stroke-width="1.2"/>
        <path d="M28 138 Q28 128 40 128 H212 Q224 128 224 138 V262 H28 Z" fill="#efe2c2"/>
        <path d="M28 214 H224 V232 H28 Z" fill="#d97a62"/>
        <path d="M42 146 H74 V194 H42 Z M86 146 H118 V194 H86 Z M130 146 H162 V194 H130 Z M174 146 H208 V194 H174 Z" fill="#366a84"/>
        <path d="M50 160 q6 -8 12 0 v18 h-12z M138 162 q6 -8 12 0 v16 h-12z" fill="#192d47" stroke-width="1.3"/>
        <circle cx="64" cy="268" r="10" fill="#2e2e31"/><circle cx="188" cy="268" r="10" fill="#2e2e31"/>
      </g>
      <g fill="none" stroke="#2e2e31" stroke-width="1" opacity=".5"><path d="M34 244h180M34 252h180"/></g>`),

    end: svg(`${hills}${birds(150, 96)}
      <g ${K}>
        <circle cx="190" cy="150" r="30" fill="url(#bk-red)"/>
      </g>
      <g class="bob"><g ${K}>
        <path d="M40 280 H130 L120 294 H50 Z" fill="#8e5037"/>
        <path d="M84 280 V214" fill="none"/>
        <path d="M60 220 H108 V272 H60 Z" fill="#f7eedb"/>
      </g></g>
      <g fill="none" ${K} stroke-width="1.5"><path d="M150 296 q8 -10 16 0 q8 -10 16 0 q8 -10 16 0"/></g>`)
  };

  document.querySelectorAll('.gutter[data-landmark]').forEach((g) => {
    const drawing = art[g.dataset.landmark];
    if (drawing) g.innerHTML = drawing;
  });
})();
