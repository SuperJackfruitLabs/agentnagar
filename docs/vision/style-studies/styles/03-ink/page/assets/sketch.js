// Hand-drawn ink and watercolour primitives for the 03-ink sketchbook page.
// Every drawing here is original, illustrative SVG made at runtime; none is a concept sheet.
(function () {
  const NS = 'http://www.w3.org/2000/svg';
  const f = (n) => Math.round(n * 10) / 10;

  function rng(seed) {
    let a = seed >>> 0;
    return function () {
      a |= 0; a = (a + 0x6d2b79f5) | 0;
      let t = Math.imul(a ^ (a >>> 15), 1 | a);
      t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
      return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
  }

  function Pen(svg, seed) {
    const R = rng(seed || 7);
    const J = (a) => (R() - 0.5) * 2 * a;
    let clock = 0;
    const pen = { svg, R, J, delayStep: 0.012, base: 0, maxDelay: Infinity };

    function node(tag, attrs, parent) {
      const n = document.createElementNS(NS, tag);
      for (const [k, v] of Object.entries(attrs || {})) n.setAttribute(k, v);
      (parent || svg).append(n);
      return n;
    }
    pen.node = node;
    pen.group = (attrs, parent) => node('g', attrs, parent);

    // A wobbly polyline through points, each segment a gentle curve.
    function wl(pts, j) {
      const w = j == null ? 1.3 : j;
      let d = `M${f(pts[0][0] + J(w))} ${f(pts[0][1] + J(w))}`;
      for (let i = 1; i < pts.length; i++) {
        const [x0, y0] = pts[i - 1];
        const [x1, y1] = pts[i];
        d += ` Q${f((x0 + x1) / 2 + J(w * 1.6))} ${f((y0 + y1) / 2 + J(w * 1.6))} ${f(x1 + J(w))} ${f(y1 + J(w))}`;
      }
      return d;
    }
    pen.wl = wl;

    // Draw an ink stroke that writes itself on when its section is reached.
    function stroke(d, opts, parent) {
      const o = opts || {};
      const delay = Math.min(pen.base + clock, pen.maxDelay);
      clock += o.step == null ? pen.delayStep : o.step;
      return node('path', {
        d, class: `ink${o.cls ? ' ' + o.cls : ''}`, fill: 'none',
        stroke: o.color || 'var(--ink)', 'stroke-width': o.w || 1.6,
        'stroke-linecap': 'round', 'stroke-linejoin': 'round', pathLength: 1,
        'stroke-opacity': o.op == null ? 1 : o.op,
        style: `--d:${f(delay * 100) / 100}s;--dur:${o.dur || 0.7}s`
      }, parent);
    }
    pen.stroke = stroke;

    // A sketchy line with overshoot and an optional second, lighter pass.
    pen.line = function (x1, y1, x2, y2, opts, parent) {
      const o = opts || {};
      const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy) || 1;
      const ov = o.over == null ? Math.min(4, L * 0.06) : o.over;
      const ux = (dx / L) * ov, uy = (dy / L) * ov;
      const p = [[x1 - ux, y1 - uy], [x2 + ux, y2 + uy]];
      stroke(wl(p, o.j), o, parent);
      if (o.double) stroke(wl(p, (o.j || 1.3) * 1.4), { ...o, w: (o.w || 1.6) * 0.55, op: 0.55, step: 0 }, parent);
    };
    pen.poly = function (pts, opts, parent) {
      const o = opts || {};
      stroke(wl(pts, o.j), o, parent);
      if (o.double) stroke(wl(pts, (o.j || 1.3) * 1.5), { ...o, w: (o.w || 1.6) * 0.55, op: 0.5, step: 0 }, parent);
    };
    pen.rect = function (x, y, w, h, opts, parent) {
      pen.poly([[x, y], [x + w, y], [x + w, y + h], [x, y + h], [x, y - 1]], opts, parent);
    };

    // Scalloped cloud outline for tree canopies.
    pen.cloudPath = function (cx, cy, rx, ry, n, bump) {
      const pts = [];
      const k = n || 14;
      for (let i = 0; i <= k; i++) {
        const a = (i / k) * Math.PI * 2 + 0.2;
        const r = 1 + J(0.08);
        pts.push([cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r]);
      }
      let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
      const b = bump || 0.45;
      for (let i = 1; i < pts.length; i++) {
        const [x0, y0] = pts[i - 1];
        const [x1, y1] = pts[i];
        const mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
        const ox = mx - cx, oy = my - cy, ol = Math.hypot(ox, oy) || 1;
        const seg = Math.hypot(x1 - x0, y1 - y0);
        d += ` Q${f(mx + (ox / ol) * seg * b)} ${f(my + (oy / ol) * seg * b)} ${f(x1)} ${f(y1)}`;
      }
      return d;
    };
    pen.cloud = function (cx, cy, rx, ry, opts, parent) {
      const o = opts || {};
      stroke(pen.cloudPath(cx, cy, rx, ry, o.n, o.bump), o, parent);
    };

    // Clip a segment to a rectangle (Liang-Barsky).
    function clip(x1, y1, x2, y2, [xmin, ymin, xmax, ymax]) {
      let t0 = 0, t1 = 1;
      const dx = x2 - x1, dy = y2 - y1;
      const p = [-dx, dx, -dy, dy], q = [x1 - xmin, xmax - x1, y1 - ymin, ymax - y1];
      for (let i = 0; i < 4; i++) {
        if (p[i] === 0) { if (q[i] < 0) return null; continue; }
        const t = q[i] / p[i];
        if (p[i] < 0) { if (t > t1) return null; if (t > t0) t0 = t; } else { if (t < t0) return null; if (t < t1) t1 = t; }
      }
      return [x1 + t0 * dx, y1 + t0 * dy, x1 + t1 * dx, y1 + t1 * dy];
    }
    // Diagonal hatching inside a rectangle.
    pen.hatch = function (x, y, w, h, spacing, opts, parent) {
      const o = { w: 0.8, step: 0.004, dur: 0.35, j: 0.5, over: 0, ...(opts || {}) };
      const dir = o.dir || 1; // 1: up to the right, -1: up to the left
      const box = [x, y, x + w, y + h];
      for (let t = -h; t < w + h; t += spacing * (0.85 + R() * 0.3)) {
        const x1 = x + t, y1 = y + h, x2 = x + t + dir * h, y2 = y;
        const c = clip(x1, y1, x2, y2, box);
        if (c && Math.hypot(c[2] - c[0], c[3] - c[1]) > 3) {
          const s = 0.06 + R() * 0.12; // hatch strokes rarely reach both edges
          const cx1 = c[0] + (c[2] - c[0]) * s, cy1 = c[1] + (c[3] - c[1]) * s;
          stroke(wl([[cx1, cy1], [c[2], c[3]]], o.j), o, parent);
        }
      }
    };

    // Watercolour wash: pigment pooled at the edge, granulated, bled by the shared filter.
    pen.wash = function (d, color, opts, parent) {
      const o = opts || {};
      return node('path', {
        d, class: `wash${o.cls ? ' ' + o.cls : ''}`, fill: color, 'fill-opacity': o.op == null ? 0.5 : o.op,
        stroke: color, 'stroke-opacity': (o.op == null ? 0.5 : o.op) * 0.9, 'stroke-width': o.edge == null ? 3 : o.edge,
        filter: o.nofilter ? null : 'url(#bleed)', style: `--wd:${o.wd || 0}s`
      }, parent);
    };
    // An irregular blob for a wash.
    pen.blob = function (cx, cy, rx, ry, n) {
      const k = n || 10;
      const pts = [];
      for (let i = 0; i < k; i++) {
        const a = (i / k) * Math.PI * 2;
        const r = 1 + J(0.16);
        pts.push([cx + Math.cos(a) * rx * r, cy + Math.sin(a) * ry * r]);
      }
      let d = '';
      for (let i = 0; i < k; i++) {
        const p0 = pts[i], p1 = pts[(i + 1) % k];
        const m = [(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2];
        d += i === 0 ? `M${f(m[0])} ${f(m[1])}` : '';
        const p2 = pts[(i + 2) % k];
        const m2 = [(p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2];
        d += ` Q${f(p1[0])} ${f(p1[1])} ${f(m2[0])} ${f(m2[1])}`;
      }
      return d + 'Z';
    };
    // A loose polygon wash that slightly misses the ink, as washes do.
    pen.fillPoly = function (pts, jit) {
      const j = jit == null ? 5 : jit;
      return wl(pts.map(([x, y]) => [x + J(j), y + J(j)]), j * 0.6) + 'Z';
    };
    pen.text = function (x, y, str, cls, parent, extra) {
      const t = node('text', { x, y, class: cls || 'lbl', ...(extra || {}) }, parent);
      t.textContent = str;
      return t;
    };
    pen.resetClock = (base) => { clock = 0; pen.base = base || 0; };
    return pen;
  }

  window.Sketch = { Pen, rng, NS };
})();
