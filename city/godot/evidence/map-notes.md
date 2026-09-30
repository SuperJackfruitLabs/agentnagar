# The map against the sheets

`map-vs-sheets.png` holds one row per style. Each row shows:

- the style's sheet-00 MAP panel (top left), at the revision its study's
  README selects: anime r008, solarpunk r005, neon r006, pixel art r005,
  low-poly r002 and voxel r004;
- the game's map at 1920 × 1080, watching at 13:00 with the Workshop
  (Guild hall) selected, scaled whole to the panel's height and not
  cropped.

The tools:

- `tools/sheet_views.gd -- <style> map` captures the Map and List tabs at
  1920 × 1080, 1280 × 720 and 800 × 900 into
  `~/.cache/agentnagar-sheets/<style>/` (`map.png`, `map-720.png`,
  `map-narrow.png`, `list.png`, `list-720.png`, `list-narrow.png`). Each
  is rendered at its exact size whatever window the desktop gives: all 36
  captures are the size named.
- `tools/sheet_compare.py --maps` composes the sheet. The per-style
  `sheet_compare.py` also gains the pair, so a style's own composite shows
  its map beside the MAP panel.

I looked at every capture at full size, and at the composite, where the
game's map is about 40% of its size.

## Every style

What is common to all six, and differs from every sheet:

- **The framing.** Each MAP panel is a close crop of the plaza and the
  blocks round it, its labels large. The map now opens the same way:
  framed on the named places (the workshop, the tree square, the
  library, the park, the tram stop and the café terrace), their pins and
  labels, with a margin and clear of the compass and scale bar, within
  the 1–2× zoom. At 1920 × 1080 that is 2× in every style, and the crop
  is close to the panels'. Zooming out to 1× shows the whole district.
  With a place selected (`--place`, or the capture's Workshop) the view
  moves toward it only as far as keeps every place in view. The tabs,
  the legend, the card and the hints still sit round the map, which the
  panels do not have. At 800 × 900 the map area left under the legend
  and the card is short (about 406 px, and less in pixel art's larger
  type), so the places do not fit any closer and the map opens at 1×.
- **The names.** The sheets name places by what they are ("Workshop",
  "Waterfront Park", low-poly's "W1") and add district labels
  ("DOWNTOWN", "RIVER", "TRAM"). The game names the fixture's facilities
  (Guild hall, Library, Tram stop, Park, Tree square, Café terrace) and
  has no district labels: the district has no Downtown place to name.
- **The tram.** Every sheet draws a tram on its track. The game draws the
  track and the stop, but no tram: that is the tram spec's.
- **The pins.** The four category colours and icons are the same in
  every style, as the contract asks. Only anime draws them on its sheet.
  Solarpunk, neon, pixel art and voxel label their places without pins,
  and low-poly uses codes, so there the game's pins are an addition the
  map needs to be findable.
- **The compass.** Anime, low-poly and voxel draw a four-way rose, and
  neon and solarpunk an N arrow. The game draws an N over an arrow on a
  round plate in every style.

## Anime (06)

Matches:

- Round category badges, white-rimmed, over the places, and captions under
  them in title case ("Guild Hall", "Tree Square").
- A light letterbox (`#F4F6FA`) round a bright noon picture: orange roofs,
  green parks, the blue river and the bridge.

Differs:

- The sheet's captions are dark text with a white outline and no plate.
  The game puts them on white plates, which read better over the busy
  roofs.
- The sheet's roofs are soft, painterly shapes and its trees round
  crowns. The render shows the live world: palms and sawtooth roofs, and
  more detail than the sheet.

## Solarpunk (09)

Matches:

- White plates with dark teal (`#123C3A`) upper-case names, like the
  sheet's.
- Solar-panel roofs, the round library with its glass dome in green
  grounds, the tree square, the canal-side trees.

Differs:

- The sheet has no pins. The game uses teardrop pins, their points on
  the places.
- The sheet's streets have zebra crossings and its water white sailboats;
  the game's have neither at this size.

## Neon noir (10)

Matches:

- A lit night (21:00): streets lined with warm lamps, dark blocks and
  magenta-edged rooftops. The map is drawn at twice neon's exposure
  (`map.exposure` 2.2, applied only to the render's frame): at the
  world's own exposure the picture read murky, the square and streets
  only just visible. Now the paved square, the streets and their
  markings, the grass and the lamps read as the sheet's do. The blocks
  stay dark, as the sheet's are.
- Dark navy plates (`#0E1A2E`) with pale upper-case names and a soft
  halo, and glowing teardrop pins.
- A scale bar at the bottom left, as the sheet has.

Differs:

- The sheet's water is a bright cyan. The render's river is dark navy.
- The sheet's scale bar has ticks at 0, 25, 50 and 100 m. The game's is
  one 50 m bar on a plate, drawn long at this zoom.
- The sheet's workshop has glowing gold roof lights; the render's is
  dark.

## Pixel art (08)

Matches:

- Dark navy plates (`#141B33`) with pale upper-case names in pixel type.
- A top-down plan in the style's palette: the river, streets, the brick
  workshop, the navy library, the sand-coloured square and its round
  tree crown, the park and the bridge.
- Square pixel badges for the pins.
- Hard pixel edges: the plan is now drawn with nearest filtering (it was
  smoothed before this task).

Differs:

- The sheet is much richer: trees in rows along every street, cars, a
  dome on the library, crossings and red roofs. The game's plan has
  plain grey blocks, dotted tree rows at the kerbs only, and a flat
  library.
- The plan is scaled to the window by a fraction, so with nearest
  filtering its pixels are one or two screen pixels wide rather than
  all the same.

## Low-poly tropical (11)

Matches:

- A warm sand letterbox (`#F6EBD2`), orange roofs, palms, turquoise water
  and the bridge, as the sheet has.
- Round badges.

Differs:

- The sheet labels places with short codes (W1, L1, T1, P1, S1, D1) in
  plain dark text. The game writes the names in upper case on cream plates
  (`#FFF8EA`): the spec's "plain captions" would not read over the roofs.
- The sheet's jetties and moored boats are missing, and its teal glass
  library is a green hip roof with a round teal wing in the render.

## Voxel (02)

Matches:

- White plates with dark navy upper-case names.
- Blocky trees, a yellow workshop and an orange library, blue and orange
  roofs, a stone-paved square: close to the sheet's palette.
- Round badges.

Differs:

- The sheet's river is a flat bright blue with "RIVER" written on it; the
  game's has a ripple texture and no label.
- The sheet's plaza buildings are large, simple blocks; the render shows
  the live world's detail.

## Fixes from this task's captures and reviews

- **Drop pins mark the spot.** A teardrop's point was drawn 20 px south of
  its place. It now stands on the place (`MapModel.pin_rect`), and the
  labels keep clear of the pin above it.
- **Pixel art's plan is sharp.** The map showed it smoothed; a pixel skin
  now shows its base with nearest filtering.
- **The List shows several rows.** At 1280 × 720 the card under the list
  left room for one or two rows in every skin (pixel art: about one and a
  half). When fewer than four rows fit under it, the card now goes beside
  the list. Opening the List on a selected place scrolls to it whole: it
  had been left half out of view.
- **The mouse in first person.** Closing the map (M, Esc or B), its Go as
  a player, and Resume on the game menu now take the mouse back in first
  person.
- **The picture is kept.** The map asked the pack for a new picture on
  every opening. It is now kept until the style or the quality changes
  or the window grows past it (map spec section 4), so opening the map again costs a few
  milliseconds (see below).

## Fixes from the final review

- **An unknown `--place` is told on the map.** The notice went to the
  HUD, which is under the map's backdrop (and hidden on the title). It
  now shows as a chip at the top of the map for four seconds.
- **A click on a List row always lands.** A projection arrives every
  tick and rebuilt the rows, so a press and its release could land on
  different rows. The counts now change in place; the rows are rebuilt
  only when the filter or search changes, while the List shows.
- **The search is the List's.** It no longer hides pins and labels on
  the Map tab. The legend's filter still applies to both, and the labels
  are laid out for the places it shows (pixel art at 800 × 900, filtered
  to Transit, had left the tram stop unnamed).
- **A spectator's first arrow** starts from the point the view is over
  (the district's middle for pixel art, which has none), not from (0, 0).
- **The picture is kept only when drawn, and reused when smaller.** A
  stand-in (an empty image from the renderer) is no longer kept, and a
  kept picture at least as large as asked answers a smaller request.
- **The opening framing** and **neon's exposure**, above.

## Performance

Measured by `scripts/bench.sh` on the development laptop, as in
`interface-notes.md`: RTX 3070 Ti Laptop GPU, a 1920 × 1080 panel at
360 Hz, COSMIC, `system76-power profile performance`, fullscreen at the
native resolution (every scene below rendered at 1920 × 1080). The
empty-scene baseline was 341.3–342.7 fps with 1.75–2.34% of refreshes
missed, so the normal-play gate is about 331–332 fps.

The bench's new `map` scene opens the map over the diagonal view (a
crowd of 60, 13:00) and samples it like the others. Before sampling it
opens the map, closes it and opens it again, and reports for each
opening the time until the picture shows and the longest frame from the
opening until two frames after. A second opening with a frame over
50 ms fails the run in any style (`Bench.reopen_breaches`); the first
is reported, not gated, as the spec allows.

### The map against the diagonal view, each from a cool GPU

Each style's diagonal view and map scene were run alone
(`BENCH_STYLES=<style> BENCH_SCENES=<scene>`), each starting at 53–59 °C.
For each: the frame rate at vsync and the share of refreshes missed, the
uncapped median frame time, the game's GPU time per frame (99th
percentile), and the scene's peak GPU temperature and median graphics
clock.

| Style | diagonal | map | map: first opening | map: again |
| --- | --- | --- | --- | --- |
| anime_cel | 340.6 fps, 1.94%; 2.39 ms, GPU 2.32 ms; 72 °C, 1620 MHz | 341.4 fps, 1.99%; 0.77 ms, GPU 0.14 ms; 64 °C, 1635 MHz | 236.6 ms | 9.0 ms |
| solarpunk | **319.8** fps, 2.06%; 2.98 ms, GPU 3.02 ms; 78 °C, 1522 MHz | 341.6 fps, 1.93%; 0.77 ms, GPU 0.14 ms; 64 °C, 1635 MHz | 205.4 ms | 9.0 ms |
| neon_noir | 340.4 fps, 1.88%; 2.52 ms, GPU 2.45 ms; 78 °C, 1620 MHz | 341.4 fps, 2.05%; 0.77 ms, GPU 0.14 ms; 64 °C, 1635 MHz | 200.5 ms | 10.8 ms |
| pixel_art (no budget) | 341.0 fps, 1.99%; 0.82 ms, GPU 0.26 ms; 66 °C, 1635 MHz | 341.4 fps, 1.99%; 0.84 ms, GPU 0.34 ms; 66 °C, 1635 MHz | 100.6 ms | 8.8 ms |
| lowpoly_tropical (no budget) | 278.8 fps, 4.02%; 3.29 ms, GPU 3.23 ms; 79 °C, 1620 MHz | 341.4 fps, 1.93%; 0.76 ms, GPU 0.14 ms; 64 °C, 1635 MHz | 212.4 ms | 9.3 ms |
| voxel (no budget) | 293.6 fps, 3.27%; 3.25 ms, GPU 3.93 ms; 79 °C, 1620 MHz | 341.6 fps, 1.93%; 0.77 ms, GPU 0.13 ms; 64 °C, 1635 MHz | 225.0 ms | 8.5 ms |

Bold marks a scene under the gate. For the openings, the time until the
picture showed and the longest frame were the same in every row: the
whole opening fits in one frame.

- **The map is the cheapest scene in every style.** With the map open
  the main view draws no 3D, so a 3D style's GPU time falls from
  2.3–3.9 ms to 0.13–0.14 ms and its frame rate is the empty scene's
  (341.4–341.6 fps, 1.93–2.05% missed). Pixel art, which is cheap
  already, stays where it was. Every style passes the normal-play gate
  with the map open, including the three with no budget and solarpunk,
  whose diagonal view is below the gate.
- **The clocks are equal at the start, not during.** Both scenes started
  below 60 °C at 1635 MHz; the diagonal view heats the GPU to 72–79 °C
  and its median clock to 1522–1620 MHz, and the map scene barely warms
  it (64–66 °C). The map's advantage is not heat: its GPU time per frame
  is a sixteenth to a twenty-eighth of the diagonal view's.
- **Opening again: 8.5–10.8 ms, in every style,** well within the spec's
  50 ms. The picture is kept, so a second opening only builds the
  screen. Before the picture was kept, each opening drew it again and
  took 30–42 ms (pixel art, which paints its plan on the CPU, 42 ms).
- **The first opening in a style takes 100–237 ms,** in one frame: the
  3D styles render their top view once (with the shaders it needs
  compiled on the way), and pixel art paints its plan. The spec allows
  the first opening; it is a visible hitch. Later in a session it is
  shorter: in the full runs below, where the style had already drawn
  six scenes, it took 62–76 ms.

### Each budgeted style through every scene

Anime, solarpunk and neon were also run through all eight scenes
(`BENCH_STYLES=<style>`), each from 59 °C. The map runs seventh, by
which time the GPU is at 85–87 °C.

| Style | map | first opening | again | Over (all pre-existing) |
| --- | --- | --- | --- | --- |
| anime_cel | 341.4 fps, 2.11%; GPU 0.13 ms; 86 °C, 1635 MHz | 62.9 ms | 9.0 ms | menu 326.6, title 315.8 |
| solarpunk | 341.8 fps, 2.11%; GPU 0.13 ms; 85 °C, 1635 MHz | 62.4 ms | 9.2 ms | diagonal 318.8, menu 252.4, title 240.4 |
| neon_noir | 341.6 fps, 2.05%; GPU 0.14 ms; 85 °C, 1635 MHz | 75.5 ms | 10.8 ms | menu 296.4, title 283.6 |

The map passes even hot: it asks so little of the GPU that its clock is
back at 1635 MHz while it runs. The scenes over the gate are the menu and
the title (fifth and sixth, at 87 °C and 1110–1260 MHz) and solarpunk's
diagonal view, as `interface-notes.md` found and explained: heat, and
solarpunk's diagonal view at native resolution. So a full run still
cannot pass on this laptop; that is not the map's doing.

### Pre-existing, and not fixed here

- Solarpunk's diagonal view is below the gate at native resolution
  (318.8–319.8 fps against about 332).
- Low-poly, voxel and pixel art declare no budget, so the gate is not
  enforced for them; low-poly's and voxel's diagonal views are below it
  (278.8 and 293.6 fps). With the map open all three are at the empty
  scene's rate.
- Sustained heat slows every 3D style after 30–40 s at native
  resolution.

The concept-sheet panels in `map-vs-sheets.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
