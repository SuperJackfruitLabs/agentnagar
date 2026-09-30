# Pixel art (08) against the sheets — pack v2

Captures: `evidence/stage3/pixel-{topdown,diagonal,street}.png` (tick 120, day)
and `pixel-night-{diagonal,street}.png` (tick 330), taken with
`--style=pixel_art --camera=<preset> --no-hud --as=none`. Side by side with
sheet 00 (Top-down, Diagonal, Street) and sheet 02 (Night and rain):
`evidence/pixel-vs-sheet.png`.

## What now matches

- **Art.** Every building, prop, tree, tile, the tram and the bridge come from
  the pre-rendered kit (`city/tools/styles/pixel`): navy outlines, the 32-colour
  palette, dithered clustered canopies, brick hall with navy sawtooth and lit
  clerestories, sandstone library with a navy glass dome, glazed towers with
  rooftop gardens, peach and brick houses, a cream-and-red tram.
- **Assembly.** Façades are laid a metre at a time (people pass in front of and
  behind them), with corners, doors where the manifest has them, banners
  beside the library's door, low twins for the cut-away; roofs and the dome
  come off when a building opens.
- **Ground.** Paved square and terraces, a lawn park with paths from its
  doors, streets with kerbs, centre dashes, zebra crossings at junctions and
  the tram track, a river with stone quays in two shimmer frames; all baked
  into 16 m chunks (whole city under 1 ms a frame at the Top-down framing).
- **Greenery.** Street trees and palms along the rows, a grove on every open
  lawn (palms by the river), the square's big tree in its raised bed ringed by
  benches, as on the sheet.
- **People.** The shared rig rendered through the same pipeline: 32 px
  figures in eight directions (walk, sit, idle, typing), eight outfits, a
  muted citizen and the three robots, seated facing their seats.
- **Night.** Every sprite and the ground swap to their palette twins; windows,
  the tram and the shelters light up; lamps throw amber pools.

## Remaining gaps, and why they stay

| Gap | Why |
| --- | --- |
| The sheet's Top-down is a plan view; ours is the same isometric view at half scale. | The pack is true 2D isometric (spec: integer zoom, one projection); a plan view would need a second sprite set. The half-scale framing is the one non-pixel-exact preset. |
| The sheet's Street panel is eye level; ours is the square close up at 2:1. | A 2D isometric pack has no eye-level camera (the pixel style declines first person). The plan asked for 3:1; 2:1 keeps the square and its surroundings in frame at 1280 x 720 (the preset's existing ruling). |
| The sheet's square is full of trees and planters. | The square is walkable; the pack draws only the manifest's props there (one big tree, planters, flower beds, lamps, bollards). Trees are added only on open lawn nobody walks on. |
| The library's entrance and banners face the viewer on the sheet. | The fixture puts the library's door on its west face, toward the square, which this fixed south-east view never sees; the pack draws doors only where the manifest has them. Its door shows from inside when the building is open. |
| The sheet's workshop reads as three slate gables. | Our hall follows the plan's sawtooth (teeth along x, clerestories facing east), which from this angle reads as glass bands with brick gables on the south front. Turning the teeth is a model change in `models.py` if preferred. |
| People are small next to the sheet's close-ups (32 px, readable outfits, no faces). | The plan fixes the figures at 32 px to the top of the hair, to match the 16 px metre; faces are a pixel or two at that size. |
| No cars, boats or text on signs; the sheet's golden-hour warmth and rain reflections. | Not modelled (cars, boats), not legible at this scale (text), or outside the fixed 32-colour palette and its night map (warm grading, wet reflections). |
| Walkers on the bridge are not raised to its 1.6 m deck. | Occupant heights come from the core's positions; the bridge sorts its back and front halves so walkers pass between the parapets. |

The concept-sheet panels in `pixel-vs-sheet.png` are crops of AI-generated concept art
(CC0 1.0); see [the evidence README](README.md).
