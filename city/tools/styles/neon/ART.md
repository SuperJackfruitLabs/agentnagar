# Neon noir kit: art guide

This kit draws Agentnagar in the style of study 10, Neon noir. The sheets
are the reference:

- `docs/vision/style-studies/styles/10-neon-noir/sheets/00-city-perspectives/r006/image.png`
- `docs/vision/style-studies/styles/10-neon-noir/sheets/01-living-community/r002/image.png`
- `docs/vision/style-studies/styles/10-neon-noir/sheets/02-creating-exploring/r003/image.png`
- `docs/vision/style-studies/styles/10-neon-noir/sheets/03-interfaces-perspectives/r004/image.png`

The pack renders the kit **lit and night-first**: a navy sky and a cool,
low moon; many warm lamp lights without shadows; emissive windows and
neon with glow; wet, reflective paving. By day it is a cool, clean city
of slate and glass with the neon off, the tubes reading as dark glass.
There is no toon step and no ink line: form reads through light. Model
real depth (recessed windows, reveals, projecting slabs, frames) and let
the palette's roughness separate matte slate, glossy glass and metal.
Flat palette colours, no textures.

## Design language

- **Architecture:** dark slate, charcoal and navy (`slate*`, `charcoal`,
  `navy`), dark glass (`glass*`), black frames (`frame`), steel.
  - **Warm light is the subject:** many lit windows (`window_glow`),
    glowing interiors, amber lamps (`lamp_glow`).
  - **Neon:** separate mesh objects named `neon`, `neon_2`, ... in
    `neon_magenta`, `neon_cyan`, `neon_amber` or `neon_violet`, so the
    pack can switch them by time of day. Magenta edge strips crown the
    towers; shop signs are abstract glyph shapes, never text.
  - Workshop: dark metal and glass sawtooth bays, warm interior light,
    tall glazed gables.
  - Library: a glowing drum with a lit dome ring.
  - Towers: dark glass with warm lit windows and magenta neon crowns.
  - Houses and shops: slate and charcoal, neon signs.
- **Nature:** deep greens (`leaf*`), palms; planters with uplights.
- **Ground:** dark stone paving and asphalt (the pack makes them wet and
  glossy), deep blue water that mirrors lights.
- **Curves:** smooth-shade curved forms with `lib.smooth(obj)` or
  `lib.finish(..., smooth_parts=...)`; keep boxes flat with small bevels.
- **Detail that reads at 20–60 m at night;** nothing under about 3 cm.

## Conventions

The low-poly kit's conventions, so the townscape assembles this kit the
same way:

- Blender is Z-up; metres. A module faces Blender +Y, which is Godot −Z,
  the front. Wall modules span x in [−W/2, W/2], with the outer face on
  y = 0 and the body at y < 0. z = 0 is the ground, or the wall top for
  roofs.
- Each asset is an empty named after the asset, parenting mesh objects
  whose names match the node names in its spec.
- Glowing parts use `window_glow` or `lamp_glow`; neon uses `neon_*` on
  objects named `neon*`. Glass materials are named `glass*`.
- Keep each asset within its spec's triangle budget.
