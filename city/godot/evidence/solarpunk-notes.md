# Solarpunk retro-futurism against sheet 09

`solarpunk-vs-sheet.png` pairs the client's views with the study's panels,
at the same ticks as the other styles (see `anime-notes.md`).

## What now matches

- **Light.** Warm, physically based light with no ink: a golden sun with
  soft shadows, subtle ambient occlusion, filmic tone and glow on lamps
  and windows.
- **Architecture.**
  - The workshop has blonde timber and solar arrays on its sawtooth roof.
  - The library is white ceramic under a planted rim and a solar-and-glass
    dome.
  - Rounded white towers have planted terraces and solar crowns.
  - Houses and the shop have solar roofs, pergolas and jade and coral
    awnings.
- **Greenery.** The great banyan and the street trees have leaf-card
  crowns. There are palms, flowerbeds and planters. At night the banyan
  carries fairy lights.
- **Street details.** A cream-and-red tram on a grass-bed track, white-and-
  brass solar lamps, glowing bollards and a jade parasol.
- **Agents.** They are white ceramic robots with brass ear discs, big cyan
  eyes on a dark visor, the green scarf and the leaf-badge ID card, as the
  interfaces sheet draws A1.
- **People.** Semi-realistic, in linen shirts and aprons.
- **Night.** Warm lamp pools, lit interiors behind clear glass, and lamp
  streaks on wet paving in rain.

## What still differs, and why

- **The library's shape.** The sheet's library is round. The district's
  footprint is a rectangle, so only its rim and dome are round.
- **Crowds and café life.** As in the other styles, the fixture's crowd
  is small.
- **Faces up close.** Faces read at game distance. Close up they are long
  and plain, so conversation close-ups need a pass.
- **Wet ground.** Reflections are lamp streaks and glossier paving, not
  screen-space reflections, to stay inside the frame budget.

## Performance

Measured by `scripts/bench.sh` at 1920 × 1080 on the development laptop (RTX 3070 Ti Laptop GPU, 360 Hz panel, COSMIC), with vsync at the display's rate as players run it, the laptop in its performance profile and starting cool:

- **Normal play** (the overhead presets and first person, crowd 60): 347–354 fps in every view. An empty scene on the same desktop reaches 354 fps and misses about 1.8% of refreshes; the styles match it.
- **Heaviest scene** (street at night in rain, crowd 300): 286–300 fps, against the 240 fps floor.
- **GPU time** per frame: 1.1–2.1 ms.

The balanced and battery profiles pass too, except neon's diagonal view once the GPU has heated past 85 °C (it runs last in the bench). See `docs/superpowers/specs/2026-09-25-city-anime-style-design.md` §1 for how the budget is measured.

The concept-sheet panels in `solarpunk-vs-sheet.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
