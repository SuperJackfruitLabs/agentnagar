# Style page kit

Shared pieces for the thirty style showcase pages
([design](../../../../superpowers/specs/2026-09-24-style-pages-design.md)).
Each page is `styles/<id>/page/index.html`; the collection root is `../../../`.

| File | Purpose |
| --- | --- |
| `styles-data.js` | **Generated** by `python3 scripts/style_studies.py --write` from the manifests. Do not edit. Sets `window.STYLE_DATA`. |
| `project.js` | Shared Agentnagar facts (`window.AGENTNAGAR`). Pages restyle; they do not change facts. `styleRoles` holds a style's current role from the decision register; `Kit.statusBlock` shows it as `.kit-role`. |
| `kit.js` | `window.Kit`: `style(id)`, `sheetImg(style, sheetIndex, panel?)`, `mountNav`, `statusBlock`, `projectBlock`, `notesDocument`, `notesDialog`, `href`, `el`, `reducedMotion`. |
| `fonts/fonts.css` | Open-licence fonts (latin subset), licences beside each family: the Fontsource 5.3.0 packages pinned in `scripts/style_pages/package-lock.json`, redistributed unchanged. All are under the SIL Open Font License 1.1 except Special Elite (Apache-2.0); they are not in the game's packages. |
| `vendor/three/three.global.min.js` | three.js r180 plus `THREE.OrbitControls` as a classic script (browsers block ES modules on `file://`). Built from `scripts/style_pages/vendor-three.entry.js` with esbuild. MIT, with its `LICENSE` beside it. |

A page:

- sets `<html data-style="<id>">` and loads, as classic scripts,
  `styles-data.js`, `project.js`, `kit.js` (and three.js if needed);
- marks its sections with `data-core="project|style|views|agents|tradeoffs|status|nav"`;
- shows the style's `review_summary` verbatim (`Kit.statusBlock` does this);
- makes no network requests.

Panels: `Kit.sheetImg(style, sheetIndex, 'tl'|'tr'|'bl'|'br')` crops one scene
from a sheet with CSS, excluding its caption strip. Panel names are in
`Kit.PANEL_NAMES[sheetIndex]`.

Verify from the repository root after `npm ci` in `scripts/style_pages/`:

```sh
node scripts/style_pages/check_pages.mjs 02-voxel     # one page
node scripts/style_pages/check_pages.mjs --strict     # all pages and the index
node scripts/style_pages/contrast_audit.mjs           # WCAG AA text contrast, all pages
```

`contrast_audit.mjs` runs axe-core's colour-contrast rule on each page as loaded
and with its notes dialog open. For text axe cannot compute (over images,
gradients or textures) it hides all text, screenshots each element's own line
boxes and compares the text colour with the median pixel behind it. Elements it
still cannot see (for example, clipped inside a scroller) are counted as
unmeasured, never as passing.

Screenshots land in `.local/style-pages/` for review; they certify nothing.
