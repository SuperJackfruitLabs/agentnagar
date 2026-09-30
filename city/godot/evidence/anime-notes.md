# Cel-shaded anime against sheet 06

`anime-vs-sheet.png` puts the running client beside the study's panels, one
pair per row, via `tools/sheet_views.gd` and `tools/sheet_compare.py`:
- Top-down, Diagonal and Street (tick 150, 13:00);
- Night and rain (tick 330, 20:12, raining);
- Park (the waterfront) and Workshop (inside, at eye level);
- Gathering (tick 285, dusk);
- A1 (City Agent A1 close up).

## What now matches

- **Shading.** Toon light with a warm sun and lavender shadows, soft rim
  light, and ink lines from a screen-space pass on the city. Characters
  also get inverted-hull outlines.
- **Buildings.** A red-brick sawtooth workshop and a cream arcaded
  library under a silver glazed vault. Glass towers step back to planted
  terraces, and houses have terracotta roofs. The workshop and library
  glazing shows their rooms from outside and the day from inside.
- **Trees.** Leafy crowns built from leaf cards: the banyan, street trees
  and shrubs. The ink traces leaf edges rather than facets.
- **River.** It runs 2 m below the quays, so the three-arch bridge's
  arches stand clear of the water.
- **Weather and light.** Rain with umbrellas outdoors, wet ground and lamp
  streaks. Lamps light the paving from their lanterns. The dusk is
  golden.
- **People.** They have anime faces that blink. A1 has navy tied-up hair,
  the white uniform jacket and the leaf badge.

## What still differs, and why

- **Density and life.** The sheets' square is packed with people, parasols
  and a stage. The fixture's crowd is 60, and the district's rooms decide
  what stands where.
- **Ground.** From above, the sheet is mostly warm paving and trees. Ours
  shows the district's lawns, where the manifest has lawn.
- **The library's west front.** The sheet draws one continuous two-storey
  glass arch. The townscape lays 2 m wall modules along the footprint.
- **Close-ups.** Hands and clothing folds are simple. Conversation
  close-ups are a later spec.

## Performance

Measured by `scripts/bench.sh` at 1920 × 1080 on the development laptop (RTX 3070 Ti Laptop GPU, 360 Hz panel, COSMIC), with vsync at the display's rate as players run it, the laptop in its performance profile and starting cool:

- **Normal play** (the overhead presets and first person, crowd 60): 347–354 fps in every view. An empty scene on the same desktop reaches 354 fps and misses about 1.8% of refreshes; the styles match it.
- **Heaviest scene** (street at night in rain, crowd 300): 286–300 fps, against the 240 fps floor.
- **GPU time** per frame: 1.1–2.1 ms.

The balanced and battery profiles pass too, except neon's diagonal view once the GPU has heated past 85 °C (it runs last in the bench). See `docs/superpowers/specs/2026-09-25-city-anime-style-design.md` §1 for how the budget is measured.

The concept-sheet panels in `anime-vs-sheet.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
