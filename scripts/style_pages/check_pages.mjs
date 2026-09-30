// Verify style showcase pages in Chrome: node check_pages.mjs [--strict] [style-id|index ...]
// Without --strict, links to sibling pages not built yet are notes, not failures.
// Loads each page from file://, then checks console errors, off-origin requests,
// the seven data-core markers, local link targets and 375 px overflow.
// Screenshots go to .local/style-pages/ for human review; they certify nothing.
import { chromium } from 'playwright';
import { existsSync, mkdirSync, readdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const COLLECTION = resolve(REPO, 'docs/vision/style-studies');
const SHOTS = resolve(REPO, '.local/style-pages');
const CORE = ['project', 'style', 'views', 'agents', 'tradeoffs', 'status', 'nav'];

const allIds = readdirSync(resolve(COLLECTION, 'styles')).filter((d) => /^\d\d-/.test(d)).sort();
const strict = process.argv.includes('--strict');
const requested = process.argv.slice(2).filter((a) => a !== '--strict');
const targets = (requested.length ? requested : [...allIds.filter((id) => existsSync(pagePath(id))), 'index']);

function pagePath(id) {
  return id === 'index' ? resolve(COLLECTION, 'pages.html') : resolve(COLLECTION, 'styles', id, 'page/index.html');
}

mkdirSync(SHOTS, { recursive: true });
// Prefers the installed Google Chrome; set STYLE_PAGES_BUNDLED=1 to use Playwright's own Chromium.
const browser = await chromium.launch(process.env.STYLE_PAGES_BUNDLED ? {} : { channel: 'chrome' });
let failed = 0;

for (const id of targets) {
  const file = pagePath(id);
  const problems = [];
  if (!existsSync(file)) {
    console.log(`FAIL ${id}: missing ${file}`);
    failed++;
    continue;
  }
  const url = pathToFileURL(file).href;

  for (const [label, viewport, reduced] of [['desktop', { width: 1440, height: 900 }, false], ['mobile', { width: 375, height: 812 }, false], ['reduced', { width: 1440, height: 900 }, true]]) {
    const context = await browser.newContext({ viewport, reducedMotion: reduced ? 'reduce' : 'no-preference' });
    const page = await context.newPage();
    page.on('console', (msg) => { if (msg.type() === 'error') problems.push(`${label} console: ${msg.text()}`); });
    page.on('pageerror', (err) => problems.push(`${label} pageerror: ${err.message}`));
    page.on('request', (req) => { if (!req.url().startsWith('file:') && !req.url().startsWith('data:') && !req.url().startsWith('blob:')) problems.push(`${label} off-origin request: ${req.url()}`); });
    page.on('requestfailed', (req) => problems.push(`${label} failed request: ${req.url()}`));
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(1500);

    if (label === 'desktop' && id !== 'index') {
      const present = await page.evaluate((core) => core.filter((c) => !document.querySelector(`[data-core="${c}"]`)), CORE);
      if (present.length) problems.push(`missing data-core: ${present.join(', ')}`);
      const summary = await page.evaluate(() => {
        const s = window.STYLE_DATA && window.Kit && document.documentElement.dataset.style;
        return s ? window.Kit.style(document.documentElement.dataset.style).review_summary : null;
      });
      if (!summary) problems.push('html[data-style] must name the style and load styles-data.js + kit.js');
      else if (!(await page.evaluate((t) => document.body.textContent.includes(t), summary))) problems.push('review_summary not shown verbatim');
    }
    if (label === 'desktop') {
      const links = await page.evaluate(() => [...document.querySelectorAll('a[href]')].map((a) => a.href).filter((h) => h.startsWith('file:')));
      for (const link of new Set(links)) {
        const path = decodeURIComponent(new URL(link).pathname);
        if (existsSync(path)) continue;
        const sibling = path.endsWith('/page/index.html') || path.endsWith('/style-studies/pages.html');
        if (sibling && !strict) console.log(`  note ${id}: not built yet: ${path.replace(REPO + '/', '')}`);
        else problems.push(`broken link: ${path.replace(REPO + '/', '')}`);
      }
      const imgs = await page.evaluate(() => [...document.images].filter((i) => i.complete && i.naturalWidth === 0 && i.src).map((i) => i.src));
      imgs.forEach((src) => problems.push(`broken image: ${src}`));
    }
    if (label === 'mobile') {
      const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
      if (overflow > 1) problems.push(`mobile horizontal overflow: ${overflow}px`);
    }
    await page.screenshot({ path: resolve(SHOTS, `${id}-${label}.png`) });
    await context.close();
  }

  if (problems.length) {
    failed++;
    console.log(`FAIL ${id}`);
    [...new Set(problems)].forEach((p) => console.log(`  - ${p}`));
  } else {
    console.log(`ok   ${id}`);
  }
}

await browser.close();
console.log(`${targets.length - failed}/${targets.length} pages passed. Screenshots: ${SHOTS}`);
process.exit(failed ? 1 : 0);
