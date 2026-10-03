# Local 3D generation pilot: the banyan in six styles

Pilot of 2026-10-01 for Agentnagar's art rework, run by an AI coding agent (Claude) on the project laptop. None of it is in the style packs. The trees in `out/` are AI-generated material: each is built on a shape made by an image-to-3D model, whose generator, inputs and seed are recorded below. The generator's raw output is not kept in the repository ([what is left out](../README.md#what-is-not-in-the-repository)).

**Round 2** ([round2/README.md](round2/README.md)) followed on the same day: the same generated shapes with the surface, colour and shading reworked, which is what moved the look. This file is round 1.

**Correction, 2026-10-02.** Step 3 below says `check_band.py` confirmed nothing was drawn in the walking band outside the tree's footprint. That check measured the spec's band (0.25 to 1.9 m); the game measures 0.15 to 2.2 m. By the game's rule the anime tree of this round reached 2.2 m outside its square, and the game squeezed it to 0.76 by 0.61: the anime "after" capture shows that squeezed tree. The other four trees of this round were not squeezed. Round 2's trees are not either.

## What was tested

Whether an open image-to-3D model that runs on this laptop can replace hand-scripted geometry for one organic asset, the great tree of the tree square, in all six style packs, with touch-ups scripted in Blender.

- **Generator:** TRELLIS.2-4B (Microsoft, MIT) through `trellis.cpp` v0.8.1 (MIT), the prebuilt CUDA build, with the 8-bit quantised weights from `ilintar/trellis2-gguf` (512 path). Seed 42, 12 steps. The pipeline also loads DINOv3 (image encoder) and BiRefNet (background removal). Their licences were not reviewed during the pilot. As read on 2026-10-02: BiRefNet is MIT; DINOv3 is under Meta's DINOv3 License of 14 August 2025, a custom licence that restricts some uses of the model, says what must accompany a redistributed copy of it, and makes no claim on what is produced with it; the weights' repository states no licence of its own and points to the source model. That is a reading of the licence pages, not a legal review.
- **Inputs:** the banyan cut from each style's concept sheet (`docs/vision/style-studies/styles/<style>/sheets/00-city-perspectives/`, STREET panel), 208 to 345 px wide, enlarged three times. `inputs/` has the six crops (`crops-contact.png` shows them together); the matted variants tried for solarpunk and neon are not kept.
- **Machine:** RTX 3070 Ti Laptop GPU, 8 GB. Blender 5.2.2, Godot 4.6.3.

## What happened

| Style | Background removal | What the model returned | Time | Used for the final asset |
| --- | --- | --- | --- | --- |
| Low-poly tropical | clean | a real 3D tree: buttressed trunk, forking limbs, broad crown | 124 s | yes |
| Voxel | clean | a real 3D blocky tree (and a stray bush, dropped) | 49 s | yes |
| Anime cel | acceptable | a flat card with the picture on it | 142 s | no |
| Pixel art | clean | a flat card | 70 s | no |
| Solarpunk | only with a colour-guided matte | two crossed flat cards | 60 s | no |
| Neon noir | poor, even with a hand-trimmed matte | a flat card | 56 s | no |

The model turned the two crops that look like 3D renders into 3D, and the four painterly ones into pictures on cards (`previews/lowpoly_tropical-tex.png` is the low-poly crop's tree from four sides; `previews/raw3-contact.png` shows voxel, pixel art and anime, `previews/raw2-contact.png` solarpunk and neon). The highest GPU memory seen was 3.6 GB (sampled every two seconds) and the GPU reached 81 to 86 °C. Geometry alone took 75 s.

So two shapes serve six styles. The low-poly shape is used for low-poly, anime, solarpunk, neon and pixel art; the voxel shape for voxel.

## Touch-ups (all scripted)

1. `analyse.py` (Blender; kept in `../tools/` as round 2 left it, where it also writes the generated model's colours): drops stray pieces, sorts faces into wood and leaf by the generated colour, stands the tree on its trunk's foot, scales it to the pack's size (12 m across; up to a quarter taller, to 9.46 m), keeps everything outside the tree's square out of the walking band (0.25 to 1.9 m), and writes the wood mesh, the crown as 26 ellipsoid lobes, limb points for aerial roots and block occupancy.
2. Per style, the pack's own kit code does the styling (the builders in `scripts/`), with only the trunk, limbs and crown layout taken from the generated tree:
   - `build_lowpoly.py`: the kit's planter ring, lawn, surface roots and lanterns; the generated trunk and limbs; faceted lobes painted by facing; aerial roots; lobes over the crown's open top.
   - `build_cards.py` (anime, solarpunk, neon): each kit's own banyan builder runs with its trunk tubes skipped, its crown lobes replaced and its crown fit switched off, so the ring, bed, leaf cards and lights are the kit's.
   - `build_voxel.py`: the voxel kit's grid, palette, greedy meshing, root skirt and canopy shading, over the blocks the generated tree fills (0.2 m wood, 0.7 m leaves); crown lifted to 3.5 m.
   - `pixel_pre.py`: swaps the model behind the `tree_square` sprite and runs the pixel kit's renderer and post-processing unchanged; crown lifted and drawn in, because the isometric camera otherwise hides the trunk.
3. `check_band.py` confirms nothing is drawn in the walking band outside the great tree's footprint. An earlier build failed this and the pack squeezed the tree to fit. (That check was wrong for one tree: see the correction above. `../tools/check_band.py` now applies the game's rule.)

## Results in the game

Round 2's comparison sheets (`round2/compare/`) show the concept sheet, the game today and the game with this round's tree, beside round 2's, captured offscreen from a scratch copy of the client with the assets in `out/` swapped in. Round 1's own sheets are not kept.

- **Anime, solarpunk, neon:** clearly better. A forked trunk with spreading limbs and aerial roots shows under the leaf-card crown, as the sheets draw it.
- **Voxel:** closer to the sheet: a full round crown on a thick trunk, where today's is a flat disc on a stick.
- **Low-poly:** the trunk and limbs are better; the crown's lobes are larger and coarser than today's and not clearly better.
- **Pixel art:** little visible difference at game scale.

## Limits

- Triangle counts are over the kits' budgets: low-poly 8,789 (budget 6,500), anime 13,752, solarpunk 11,038, neon 10,140, voxel 10,376 (today's are 5,942 to 7,326).
- The generator leaves the crown open on top (it saw one side); the touch-up caps it.
- In solarpunk and neon the kit's lights still follow the kit's own limb layout, not the generated limbs.
- One seed, one asset, one run each. No frame-rate measurement, no kit tests run against these assets.
- Painterly concept crops did not become 3D. A clean, single-object image that looks like a 3D render is what this model needs.

## Re-running

```sh
export AGENTNAGAR=/path/to/agentnagar                       # the checkout; the builders use its kit code
B=/path/to/trellis.cpp; M=/path/to/trellis2-gguf/q8         # the unpacked release, and the 8-bit weights
LD_LIBRARY_PATH=$B $B/trellis-cli inputs/lowpoly_tropical-banyan.png raw/lowpoly_tropical.glb --models $M --res 512 --seed 42 --require-gpu --webp off
blender --background --factory-startup --python ../tools/analyse.py -- raw/lowpoly_tropical.glb parts lowpoly_tropical
blender --background --factory-startup --python scripts/build_lowpoly.py -- round2/parts lowpoly_tropical out/lowpoly_tropical/tree_banyan.glb
blender --background --factory-startup --python scripts/build_cards.py -- anime round2/parts lowpoly_tropical out/anime_cel/tree_banyan.glb
python3 scripts/build_voxel.py round2/parts voxel out/voxel/v2/tree_large.glb
python3 ../tools/check_band.py out/*/tree_banyan.glb
```

The first two commands make the shape again and reduce it to parts (`scripts/ensure_weights.sh` fetches the weights). The parts they gave in the pilot are kept in `round2/parts/`, and the builders above read those.

The builders reach the checkout's kit tools through `AGENTNAGAR`; they are pilot code, not project code.
