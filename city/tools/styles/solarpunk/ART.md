# Solarpunk kit: art guide

This kit draws Agentnagar in the style of study 09, Solarpunk
retro-futurism. The sheets are the reference:

- `docs/vision/style-studies/styles/09-solarpunk/sheets/00-city-perspectives/r005/image.png`
- `docs/vision/style-studies/styles/09-solarpunk/sheets/01-living-community/r004/image.png`
- `docs/vision/style-studies/styles/09-solarpunk/sheets/02-creating-exploring/r003/image.png`
- `docs/vision/style-studies/styles/09-solarpunk/sheets/03-interfaces-perspectives/r003/image.png`

The pack renders the kit **lit and physically based**: a warm golden sun
with soft shadows, sky light, subtle ambient occlusion, filmic tone
mapping and glow. There is no toon step and no ink line, so form reads
through light, shadow and material: model real bevels and depth (recessed
windows, projecting slabs, reveals), and let roughness and metallic from
`palette.py` separate ceramic, timber, brass, glass and solar panels. Flat
palette colours, no textures.

## Design language

- **Architecture:** curved white ceramic (`ceramic`, `warm_white`) and
  blonde timber (`timber*`), brass details (`brass`), turquoise glass
  (`glass*`) and deep blue solar panels (`solar`, `solar_cell` in
  `solar_frame`).
  - Workshop: blonde timber sawtooth bays, each steep face a blue solar
    panel; warm glazing; vines and planters.
  - Library: a white ceramic drum: two storeys of warm glazing between
    white bands, a planted rim, a glass-and-solar dome.
  - Towers: rounded white towers with curved balconies, planted terraces,
    roof gardens and solar crowns.
  - Houses and shops: white and cream with solar roofs, pergolas and
    awnings (`jade`, `coral` accents).
- **Nature everywhere:** lush broadleaf crowns in sunlit greens (`leaf*`),
  palms, vines (`vine`), flowerbeds (`flower_*`), planted terraces.
- **Ground:** warm sand paving (`paving*`), light grey streets, a tram
  track in a grass bed, bright blue water.
- **Curves:** smooth-shade curved forms with `lib.smooth(obj)` or
  `lib.finish(..., smooth_parts=...)`; keep boxes flat with small bevels.
- **Detail that reads at 20–60 m;** nothing under about 3 cm.

## Conventions

The low-poly kit's conventions, so the townscape assembles this kit the
same way:

- Blender is Z-up; metres. A module faces Blender +Y, which is Godot −Z,
  the front. Wall modules span x in [−W/2, W/2], with the outer face on
  y = 0 and the body at y < 0. z = 0 is the ground, or the wall top for
  roofs.
- Each asset is an empty named after the asset, parenting mesh objects
  whose names match the node names in its spec.
- Glowing parts use `window_glow`, `lamp_glow` or `fairy_glow`. Glass
  materials are named `glass*`, so night lights them.
- Keep each asset within its spec's triangle budget.
