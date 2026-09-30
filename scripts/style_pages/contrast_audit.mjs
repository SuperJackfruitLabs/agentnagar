// Measure text contrast on the style pages with axe-core's color-contrast rule (WCAG AA).
// node contrast_audit.mjs [--json] [style-id|index ...]
// Audits the page as loaded and, where present, with its notes dialog open. Text over
// images or gradients cannot be computed and is reported as "unmeasured", not as a pass.
// Text that is aria-hidden, or lettering inside a role="img" illustration (whose label
// carries its meaning), is counted as "not judged" rather than failed; the pixel sampler
// also strips text-stroke and text-shadow, so it cannot fairly measure outlined numerals.
import { chromium } from 'playwright';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const COLLECTION = resolve(HERE, '../../docs/vision/style-studies');
const AXE = readFileSync(resolve(HERE, 'node_modules/axe-core/axe.min.js'), 'utf8');

const args = process.argv.slice(2);
const asJson = args.includes('--json');
const ids = args.filter((a) => !a.startsWith('--'));
const all = readdirSync(resolve(COLLECTION, 'styles')).filter((d) => existsSync(resolve(COLLECTION, 'styles', d, 'page/index.html'))).sort();
const targets = ids.length ? ids : [...all, 'index'];
const path = (id) => (id === 'index' ? resolve(COLLECTION, 'pages.html') : resolve(COLLECTION, 'styles', id, 'page/index.html'));

async function audit(page) {
  if (!(await page.evaluate(() => !!window.axe))) await page.addScriptTag({ content: AXE });
  const result = await page.evaluate(async () => {
    const r = await window.axe.run(document, { runOnly: { type: 'rule', values: ['color-contrast'] }, resultTypes: ['violations', 'incomplete'] });
    const nodes = (list) => list.flatMap((v) => v.nodes).map((n) => ({
      target: n.target.join(' '),
      text: (document.querySelector(n.target[0])?.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 60),
      data: n.any[0]?.data || {}
    }));
    return { violations: nodes(r.violations), incomplete: nodes(r.incomplete) };
  });
  const sampled = await sampleIncomplete(page, result.incomplete);
  return { violations: [...result.violations, ...sampled.violations], decorative: sampled.decorative, unmeasured: sampled.unmeasured };
}

// For text axe could not measure (over images, gradients, textures): hide all text, then
// for each element scroll it into view, confirm it is the topmost element at its own text,
// screenshot just its line boxes and compare its text colour (fill for SVG text) with those
// pixels. Fails when the median background misses the AA ratio (3:1 for large text).
async function sampleIncomplete(page, incomplete) {
  if (!incomplete.length) return { violations: [], decorative: 0, unmeasured: 0 };
  // Load every lazy image first, so scrolling an element into view cannot shift layout mid-measure.
  await page.evaluate(async () => {
    const imgs = [...document.images];
    imgs.forEach((i) => { i.loading = 'eager'; });
    await Promise.all(imgs.map((i) => (i.complete ? null : new Promise((r) => { i.onload = i.onerror = r; }))));
  });
  await page.addStyleTag({ content: '* { color: transparent !important; fill-opacity: 1; text-shadow: none !important; -webkit-text-stroke: 0 !important; caret-color: transparent !important; } svg text, svg tspan { fill: transparent !important; }' });
  const originals = await page.evaluate((targets) => {
    // Read colours with the hiding sheet disabled.
    const sheet = [...document.styleSheets].find((x) => x.ownerNode.textContent.startsWith('* { color: transparent'));
    sheet.disabled = true;
    const out = targets.map((t) => {
      const node = document.querySelector(t.target);
      if (!node) return null;
      if (node.closest('[aria-hidden="true"], [role="img"]')) return { decorative: true };
      const cs = getComputedStyle(node);
      const svg = node instanceof SVGElement;
      const paint = svg ? cs.fill : cs.color;
      const m = (paint.match(/[\d.]+/g) || []).map(Number);
      if (m.length < 3 || (m.length > 3 && m[3] === 0)) return null;
      const size = parseFloat(cs.fontSize);
      const bold = parseInt(cs.fontWeight, 10) >= 700;
      return { fg: m.slice(0, 3), alpha: (m.length > 3 ? m[3] : 1) * (svg ? parseFloat(cs.fillOpacity) : 1), large: size >= 24 || (bold && size >= 18.66) };
    });
    sheet.disabled = false;
    return out;
  }, incomplete);
  await page.waitForTimeout(120);
  const violations = [];
  let measured = 0;
  const decorative = originals.filter((o) => o && o.decorative).length;
  for (let i = 0; i < incomplete.length; i++) {
    const t = incomplete[i], o = originals[i];
    if (!o || o.decorative) continue;
    const seen = await page.evaluate((sel) => {
      const node = document.querySelector(sel);
      node.scrollIntoView({ block: 'center', inline: 'center' });
      // Re-read the colour now: scrolling can change state (e.g. a current-step marker).
      const sheet = [...document.styleSheets].find((x) => x.ownerNode.textContent.startsWith('* { color: transparent'));
      sheet.disabled = true;
      const cs = getComputedStyle(node);
      const svg = node instanceof SVGElement;
      const m = ((svg ? cs.fill : cs.color).match(/[\d.]+/g) || []).map(Number);
      sheet.disabled = false;
      const colour = m.length >= 3 ? { fg: m.slice(0, 3), alpha: (m.length > 3 ? m[3] : 1) * (svg ? parseFloat(cs.fillOpacity) : 1) } : null;
      const range = document.createRange();
      const rects = [];
      const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
      for (let n = walker.nextNode(); n; n = walker.nextNode()) {
        if (!n.textContent.trim() || n.parentElement.closest('[aria-hidden="true"]') !== node.closest('[aria-hidden="true"]')) continue;
        range.selectNodeContents(n);
        for (const r of range.getClientRects()) {
          if (r.width < 3 || r.height < 3 || r.right < 0 || r.bottom < 0 || r.left > innerWidth || r.top > innerHeight) continue;
          const hit = document.elementFromPoint(r.left + r.width / 2, r.top + r.height / 2);
          if (hit && (hit === n.parentElement || n.parentElement.contains(hit) || hit.contains(n.parentElement))) rects.push([r.left, r.top, r.width, r.height]);
        }
        if (rects.length >= 6) break;
      }
      return { rects, colour };
    }, t.target).catch(() => ({ rects: [], colour: null }));
    const rects = seen.rects;
    if (!rects.length || !seen.colour || seen.colour.alpha === 0) continue;
    Object.assign(o, seen.colour);
    await page.waitForTimeout(60);
    const clip = {
      x: Math.max(0, Math.min(...rects.map((r) => r[0]))), y: Math.max(0, Math.min(...rects.map((r) => r[1])))
    };
    clip.width = Math.max(...rects.map((r) => r[0] + r[2])) - clip.x;
    clip.height = Math.max(...rects.map((r) => r[1] + r[3])) - clip.y;
    if (clip.width < 2 || clip.height < 2) continue;
    const shot = (await page.screenshot({ clip, animations: 'disabled' })).toString('base64');
    const median = await page.evaluate(async ({ shot, rects, clip, o }) => {
      const img = new Image();
      img.src = `data:image/png;base64,${shot}`;
      await img.decode();
      const c = document.createElement('canvas');
      c.width = img.width; c.height = img.height;
      const ctx = c.getContext('2d', { willReadFrequently: true });
      ctx.drawImage(img, 0, 0);
      const k = img.width / clip.width;
      const lin = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
      const lum = (r, g, b) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
      const ratios = [];
      for (const [x, y, w, h] of rects) {
        const x0 = Math.max(0, Math.floor((x - clip.x) * k)), y0 = Math.max(0, Math.floor((y - clip.y) * k));
        const x1 = Math.min(c.width, Math.ceil((x - clip.x + w) * k)), y1 = Math.min(c.height, Math.ceil((y - clip.y + h) * k));
        if (x1 <= x0 || y1 <= y0) continue;
        const d = ctx.getImageData(x0, y0, x1 - x0, y1 - y0).data;
        for (let i = 0; i < d.length; i += 4 * 3) {
          const p = [d[i], d[i + 1], d[i + 2]];
          const fg = o.fg.map((v, j) => v * o.alpha + p[j] * (1 - o.alpha));
          const a = lum(...fg), b = lum(...p);
          ratios.push((Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05));
        }
      }
      ratios.sort((x, y) => x - y);
      return ratios.length ? ratios[Math.floor(ratios.length / 2)] : null;
    }, { shot, rects, clip, o });
    if (median == null) continue;
    measured++;
    const need = o.large ? 3 : 4.5;
    if (median < need) violations.push({ target: t.target, text: t.text, data: { contrastRatio: median.toFixed(2), expectedContrastRatio: `${need}:1`, fgColor: `rgb(${o.fg.join(',')})`, bgColor: 'pixels' } });
  }
  await page.evaluate(() => { window.scrollTo(0, 0); document.querySelectorAll('style').forEach((s) => { if (s.textContent.startsWith('* { color: transparent')) s.remove(); }); });
  return { violations, decorative, unmeasured: incomplete.length - measured - decorative };
}

const browser = await chromium.launch(process.env.STYLE_PAGES_BUNDLED ? {} : { channel: 'chrome' });
const report = {};
for (const id of targets) {
  const context = await browser.newContext({ viewport: { width: 1440, height: 900 }, reducedMotion: 'reduce' });
  const page = await context.newPage();
  await page.goto(pathToFileURL(path(id)).href, { waitUntil: 'load' });
  await page.waitForTimeout(800);
  const loaded = await audit(page);
  let notes = null;
  const opened = await page.evaluate(() => {
    const d = document.querySelector('dialog.kit-dialog');
    if (!d) return false;
    d.showModal();
    return true;
  });
  if (opened) {
    await page.waitForTimeout(300);
    notes = await audit(page);
  }
  report[id] = { loaded, notes };
  await context.close();
}
await browser.close();

if (asJson) {
  console.log(JSON.stringify(report, null, 1));
} else {
  for (const [id, r] of Object.entries(report)) {
    const failing = r.loaded.violations.length + (r.notes?.violations.length || 0);
    console.log(`${failing ? 'FAIL' : 'ok  '} ${id}: ${r.loaded.violations.length} page, ${r.notes ? r.notes.violations.length : '-'} notes, ${r.loaded.unmeasured} unmeasured, ${r.loaded.decorative} not judged (aria-hidden, or inside role=img)`);
    for (const [where, v] of [['page', r.loaded.violations], ['notes', r.notes?.violations || []]]) {
      for (const n of v.slice(0, 6)) console.log(`     ${where} ${n.data.contrastRatio}:1 need ${n.data.expectedContrastRatio} ${n.data.fgColor}/${n.data.bgColor} ${n.target} "${n.text}"`);
      if (v.length > 6) console.log(`     ${where} ... ${v.length - 6} more`);
    }
  }
}
process.exit(Object.values(report).some((r) => r.loaded.violations.length || r.notes?.violations.length) ? 1 : 0);
