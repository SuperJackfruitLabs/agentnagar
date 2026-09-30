# Neon noir against sheet 10

`neon-vs-sheet.png` pairs the client's views with the study's panels. The
sheets are night-first, so the city views are taken on a dry night:
Top-down, Diagonal and Street at tick 370 (21:48; `"sheet_night"` in
`style.json`). Night and rain is at 20:12.

## What now matches

- **Night light.**
  - A navy sky and a low, cool moon.
  - Warm lamps along the streets and round the square that cast no
    shadow and fade with distance.
  - Glow from emissive windows (a lit and dark mix on the towers) and
    magenta neon crowns.
  - The great tree hung with bulbs and lanterns, lit gold from below.
- **Rain.** Wet paving mirrors the lights with screen-space reflections,
  and umbrellas open outdoors.
- **Architecture.**
  - Dark sawtooth halls with warm glazing.
  - A slate library with a lit drum and a ribbed glass dome.
  - Stepped towers.
  - Flat-roofed houses.
  - A shop with neon glyph signs.
- **Agents.** They are glossy black robots with white side plates, a cyan
  ring eye and side lights, a dark hoodie over white limb plates, and the
  ID card, as the sheets draw A1.
- **People.** Semi-realistic, in night clothes: dark jackets, hoods and
  scarves by outfit.
- **Day.** By day the neon is dark glass and the city is cool slate and
  glass under an overcast blue sky.

## What still differs, and why

- **Lamp density.** The sheets light every path and park edge. Ours lights
  the streets, the square's lamps and the tree. More would cost frame
  time.
- **The library.** The sheet's Street panel draws a round glazed rotunda.
  The townscape builds a square base, as the Diagonal panel shows.
- **Reflections.** They appear only while it rains (at night the sheets
  also show dew), to stay inside the frame budget.
- **Crowds.** As in the other styles.

## Performance

Measured by `scripts/bench.sh` at 1920 × 1080 on the development laptop (RTX 3070 Ti Laptop GPU, 360 Hz panel, COSMIC), with vsync at the display's rate as players run it, the laptop in its performance profile and starting cool:

- **Normal play** (the overhead presets and first person, crowd 60): 347–354 fps in every view. An empty scene on the same desktop reaches 354 fps and misses about 1.8% of refreshes; the styles match it.
- **Heaviest scene** (street at night in rain, crowd 300): 286–300 fps, against the 240 fps floor.
- **GPU time** per frame: 1.1–2.1 ms.

The balanced and battery profiles pass too, except neon's diagonal view once the GPU has heated past 85 °C (it runs last in the bench). See `docs/superpowers/specs/2026-09-25-city-anime-style-design.md` §1 for how the budget is measured.

The concept-sheet panels in `neon-vs-sheet.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
