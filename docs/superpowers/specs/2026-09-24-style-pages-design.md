# Style showcase pages — design

Date: 2026-09-24 · Status: awaiting user review · Branch: `design/style-pages`

## Purpose

One HTML page for each of the thirty [city style studies](../../vision/style-studies/README.md).
Each page describes the style and Agentnagar and is itself built in that style.
The primary audience is **internal**: Rakesh and the team comparing styles.
Each page should also be a showcase of its style, and the format varies by style:
a game, a publication, a simulated interface, a poster or a story.

Voxel (`02-voxel`) is already selected for first-scene assets
([decision](../../planning/VISION_DECISIONS.md)). The pages do not reopen or
change that decision; they make the thirty studies easier to compare and
remember.

## Honesty rules (inherited)

- Concept sheets are illustrations, not game captures or implementation evidence.
  Every page says so where it shows them.
- Selection does not imply review approval. Pages show each style's
  `review_summary` verbatim and link its review sources.
- Pages use fictional or already-documented facts only. They introduce no new
  product decisions, prices, dates or Guild character designs. A page may
  illustrate a character, prop or UI in its style; if the source sheets do not
  depict it, the page labels it as illustrative.
- Voxel's page may say it is the selected style for first-scene assets and link
  the [work-bay prototype](../../../prototypes/voxel-work-bay/README.md). No other
  page implies selection.
- *Amended 2026-09-26:* after RD18 (2026-09-24), 08 and 11 are the style-agnostic
  proof styles and Voxel is the third city style pack. Those roles come from
  `styleRoles` in `project.js`, so each page states them in one consistent sentence.
- Culturally derived styles (28 Ukiyo-e-inspired, 29 Madhubani-inspired,
  30 Afrofuturist) keep the collection's "-inspired" framing and make no claim of
  cultural authenticity.

## Core content (every page)

However the format presents it, all of the following is reachable on every page,
by keyboard, without winning a game:

1. **Agentnagar**: the shared project summary (see *Shared project text*).
2. **The style**: intent from `brief.md`, three to five design principles,
   palette (swatches with hex values), materials/texture and typography.
3. **One district, four views**: the four selected sheets, with the reference
   district landmarks named (River, North bridge, Workshop, Tree Square, Library,
   tram boulevard).
4. **Agents in this style**: how City Agent A1 and Guild residents appear.
5. **Strengths and trade-offs**: readability at map vs street scale, device and
   production cost (from the brief's device adaptation), UI legibility, and
   risks noted in reviews.
6. **Status**: selected revision per sheet, review summary, review-source links,
   links to the style README, brief and manifest.
7. **Navigation**: previous style, next style, and the index.

Game and interactive formats also provide a visible **"Read the notes"** control
that opens all core content as a plain document view.

## Formats

| # | Style | Format |
| --- | --- | --- |
| 01 | Graphic minimalist | Swiss wayfinding poster; scroll reads as a transit diagram |
| 02 | Voxel | Playable isometric block district; click the Workshop to watch the robot Guild at work |
| 03 | Ink and watercolor | Travel sketchbook; washes bleed in on scroll |
| 04 | Architectural realism | Design-competition monograph: plates, sections, specification tables |
| 05 | Claymation | Stop-motion making-of: film strips, stepped frame-rate animation |
| 06 | Cel-shaded anime | Visual novel; A1 guides the reader through the city in dialogue |
| 07 | Paper craft | Pop-up book with layered paper parallax |
| 08 | Pixel art | Top-down RPG; walk a sprite and talk to NPCs, each holding a section |
| 09 | Solarpunk retro-futurism | 1970s settlement-study report / world's-fair brochure |
| 10 | Neon noir | Rainy detective case file; investigate the city at night |
| 11 | Low-poly tropical diorama | Rotating 3D diorama with a day/night slider |
| 12 | Gouache storybook | Picture book, "A Day in Agentnagar", with page turns |
| 13 | Risograph print | Fold-out zine with misregistered two-colour layers |
| 14 | Linocut and relief print | Broadsheet newspaper, *The Agentnagar Gazette* |
| 15 | Stained-glass mosaic | Window whose panes light up to reveal sections |
| 16 | Chalk pastel mural | Sidewalk mural the reader can draw on |
| 17 | Art Nouveau botanical | Herbarium: botanical plates cataloguing districts |
| 18 | Art Deco civic futurism | Civic prospectus navigated by elevator, one floor per section |
| 19 | Bauhaus primary-form | Composition playground; drag primary shapes to build the district |
| 20 | Memphis playful geometry | Maximalist 1980s TV-channel page |
| 21 | Brutalist tropical modernism | Raw web-brutalist manifesto |
| 22 | Streamline retro future | 1950s airline brochure, "Fly to Agentnagar" |
| 23 | Cassette futurism | CRT operating system; boot, then insert tapes to open sections |
| 24 | Dieselpunk civic works | Public-works control room with gauges and levers |
| 25 | Biomorphic eco-fantasy | Field guide whose content grows like mycelium |
| 26 | Soft 3D plush miniature | Toy-box unboxing with squishy interactions |
| 27 | Ceramic tile city | Tile puzzle; arrange tiles to complete the district |
| 28 | Ukiyo-e-inspired woodblock city | Horizontal handscroll journey |
| 29 | Madhubani-inspired contemporary city | Bordered narrative wall of story panels |
| 30 | Afrofuturist maker metropolis | Maker-festival broadcast site: bold pattern and rhythm |

Each format is an interpretation, drawn from the style's brief and sheets. Where
the brief and a format idea conflict, the brief wins.

## Architecture

Approach A: one self-contained page per style, plus a small shared kit.

```text
docs/vision/style-studies/
  pages.html                      # index: 30 tiles, each styled as its page
  shared/page-kit/
    project.js                    # window.AGENTNAGAR: shared project text
    styles-data.js                # GENERATED: window.STYLE_DATA from manifests
    kit.js                        # tiny helpers: nav, notes view, sheet panel crop
    vendor/                       # vendored libraries with LICENSE files
    fonts/                        # vendored OFL/Apache fonts with LICENSE files
  styles/NN-slug/page/
    index.html                    # the page: its own HTML, CSS and JS
    assets/                       # optional page-specific SVG/sprites/audio
```

- **No build step, no network.** Pages work opened from disk (`file://`) and
  over `python3 -m http.server`. They load scripts via `<script src>` (not
  `fetch`, which fails on `file://`). No CDN, analytics or remote fonts.
- **Libraries** (for example three.js for 02 and 11) are vendored once under
  `page-kit/vendor/` with their licences. Fonts are open-licence woff2 files
  under `page-kit/fonts/` with licences. System fonts are acceptable where they
  suit the style.
- **Artwork** is the existing selected sheet PNGs, referenced by relative path;
  no copies. The four panels of a sheet sit in a known 2 × 2 grid, so `kit.js`
  can crop a single panel with CSS (`object-view-box` or a background-position
  fallback). Pages may add original SVG/CSS/canvas illustration in the style;
  it is labelled illustrative, not a concept sheet.
- **Size budget:** each page's own files ≤ 400 KB excluding sheets and shared
  vendor/fonts.

### Data flow

`python3 scripts/style_studies.py --write` additionally writes
`shared/page-kit/styles-data.js` from all thirty manifests: id, name, selected
revision per sheet with image path, review summary, review sources, and
previous/next ids. `--check` fails if that file is stale, like the galleries.
Pages read revisions, image paths, review text and navigation from
`STYLE_DATA`, so a later manifest change updates every page without editing
HTML.

Style-specific prose (principles, palette, trade-offs, format copy) lives in
each page, written from its `brief.md`, sheets and reviews.

### Shared project text

`project.js` holds one factual summary drawn from the repository README and
decision register: an open maker village that can grow into a city, shared by
people and agents; the first slice is walking the city and watching the fourteen
Guild agents at their real work; the public observes and registered users
interact by tier; residency, city credits (name pending) and public facilities;
personal agents stay private unless shared. Pages may restyle its presentation
but not change its facts.

## Quality bar

- Distinctive and polished: each page should be unmistakably its style at first
  glance, in layout, type, motion and interaction, not a themed template.
- Works at 375 px and 1440 px wide, with no horizontal page scroll (deliberate
  horizontal formats such as 28's handscroll scroll inside their own region).
- Keyboard operable; visible focus; games have keyboard controls.
- `prefers-reduced-motion` respected: heavy motion is replaced by static states.
- Text contrast meets WCAG AA for body text, including over artwork.
- Images have alt text; the sheets' alt text names the panel and landmarks.
- Loads without console errors.

## Verification

For every page, with Playwright:

1. Load from `file://` and from a local server; record console errors (must be
   zero).
2. Screenshot at 1440 × 900 and 375 × 812.
3. Confirm all seven core-content items are present in the DOM (or notes view),
   and that prev/next/index links resolve.
4. Confirm no network request leaves the local origin.
5. Reduced-motion screenshot for motion-heavy formats.

Repository checks: `python3 scripts/style_studies.py --check` and
`python3 -m unittest discover -s tests -v` pass, including new tests for
`styles-data.js` generation and staleness.

Screenshots are review evidence; they do not certify design quality. Rakesh
reviews pages.

## Rollout

1. **Kit and data**: `project.js`, generated `styles-data.js` with tests,
   `kit.js`, index page skeleton.
2. **Pilot**: 02 Voxel (game), 14 Linocut (publication), 23 Cassette futurism
   (simulated interface). Rakesh reviews these to set the bar; feedback updates
   this spec.
3. **Remaining 27** in parallel batches, only with Rakesh's explicit opt-in to a
   multi-agent workflow. Each page goes through the verification above.
4. **Index page** finished with all thirty tiles; gallery README links to it.
5. One pull request per stage, each with screenshots.

## Out of scope

- Changing manifests, sheets, briefs or the Voxel selection.
- Generating new concept artwork.
- Public hosting, analytics or publication; these pages stay repository-local.
- Engine, gameplay or economy decisions; any game mechanics on a page are
  presentation only.
