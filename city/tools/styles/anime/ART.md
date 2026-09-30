# Cel-shaded anime kit: art guide

This kit draws Agentnagar in the style of study 06, Cel-shaded anime. The
sheets are the reference:

- `docs/vision/style-studies/styles/06-anime/sheets/00-city-perspectives/r008/image.png`
- `docs/vision/style-studies/styles/06-anime/sheets/01-living-community/r003/image.png`
- `docs/vision/style-studies/styles/06-anime/sheets/02-creating-exploring/r002/image.png`
- `docs/vision/style-studies/styles/06-anime/sheets/03-interfaces-perspectives/r004/image.png`

The pack shades everything toon at runtime:

- a two-tone light and shadow step, with cool lavender-indigo shadows;
- a soft rim light;
- ink lines from a screen-space pass on silhouettes and creases;
- inverted-hull outlines on characters.

So model **clean, readable forms in flat palette colours**: no textures
(except the foliage's leaf mask, below), and no baked shading. Every colour comes from `palette.py`. Add a colour there
only when the sheets need one the palette lacks.

## Design language

- **Crisp, simple silhouettes, generously bevelled at human scale.** Use
  `bevel=` on boxes at 0.01–0.03 m, so the line pass draws clean edges.
- **Detail that reads at 20–60 m.** Window mullions, stone sills and lintels,
  standing seams, balconies, awnings, roof gardens. Skip anything smaller than
  about 3 cm.
- **Architecture:**
  - Workshop: bright red-orange brick (`brick`), black steel windows
    (`frame`), stone trim.
  - Library: silver standing-seam barrel vault (`steel*`), warm glass
    arcade, cream stone.
  - Towers: pale glass (`glass_tower`) in white frames, stepping back to
    planted terraces.
  - Houses and shops: cream, peach, sky and mint render, with terracotta
    roofs.
- **Nature:** leafy, clumped canopies as the sheets draw them, built by
  `tools/styles/shared/foliage.py`: overlapping lobes wrapped in leaf cards
  that show clusters from one deterministic, alpha-masked leaf texture
  (`foliage_leaves.png`, the kit's one texture), their normals leaning to
  the whole crown so the toon step shades it as one soft form, in two or
  three greens (`leaf_dark`, `leaf`, `leaf_light`, with `leaf_sun`
  highlights). Palms have long arching fronds. Shade curved forms smooth
  with `lib.smooth(obj)` or `lib.finish(..., smooth_parts=...)`; keep boxes
  flat. Card assets import without generated LODs (they would drop cards).
- **Water:** bright blue (`water`) with lighter bands. The pack animates
  sparkle.

## Conventions

These are the low-poly kit's conventions, so the anime townscape assembles
the kit the same way.

- Blender is Z-up; metres. A module faces Blender +Y, which is Godot −Z, the
  front. Wall modules span x in [−W/2, W/2], with the outer face on y = 0 and
  the body at y < 0. z = 0 is the ground, or the wall top for roofs.
- Each asset is an empty named after the asset, parenting mesh objects whose
  names match the node names in its spec.
- Glowing parts use palette `window_glow` or `lamp_glow` materials. Glass
  materials are named `glass*`, so night lights them.
- Keep each asset's triangles within its spec. Toon shading needs no dense
  geometry.

## Workflow

1. Write the builder in your family's module and add it to `ASSETS`.
2. Build it:

   ```
   blender --background --factory-startup --python-exit-code 1 \
       --python city/tools/styles/anime/build.py -- NAME
   ```

3. Preview it as the game shows it. This needs no import, and writes
   `~/.cache/agentnagar-anime-preview/NAME.png`:

   ```
   godot --path city/godot --resolution 1280x960 \
       --script res://tools/asset_preview.gd -- NAME [--yaw 210] [--pitch -22] [--night] [--outline]
   ```

4. Compare the preview with the sheets, and iterate until it reads as the
   sheets' object.
5. Add its measured size, triangle budget and node names to your family's
   `specs/*.json`, then run
   `python3 -m unittest city/tools/styles/anime/test_assets.py`.
