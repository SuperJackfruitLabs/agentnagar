# Round 2: the great tree's surface, colour and light

Pilot of 2026-10-01 for Agentnagar's art rework, run by an AI coding agent (Claude) on the project laptop. It follows [round 1](../README.md), which swapped a generated shape into all six style packs and moved the look very little. None of it is in the style packs. The trees in `out/` are AI-generated material: they are built on AI-generated models (TRELLIS.2; the generator, inputs and seed are in [round 1's README](../README.md)), kept here reduced to `parts/`, and painted from colours measured in the AI-generated concept sheets. The scripts named below are in [`../../tools/`](../../tools/).

**Correction, 2026-10-02.** The footprint check used here (`check_band.py`) measured the spec's walking band, 0.25 to 1.9 m. The game measures a piece over 0.15 to 2.2 m and stretches it so that slice fills its footprint. Re-checked by the game's own rule and in the game itself: every round 2 tree is stretched 2 to 6%, as the kits' own trees are, so round 2's results stand. Round 1's anime tree, though, was being squeezed by the game to 0.76 by 0.61 (leaf cards between 1.9 and 2.2 m lay outside its square). The "Round 1" figures for anime in the tables below, and the round 1 anime image on the comparison sheets, are of that squeezed tree. `check_band.py` now applies the game's rule.

## The question

Round 1 changed the tree's shape and left its surface and light alone, and the trees still looked much like today's. Round 2 asks what does bring the tree closer to its concept sheet: the colours on the mesh, the size and shape of the leaf masses, shading baked into the model, or the pack's light.

## What was changed

1. **Colours from the sheet, not the kit palette** (`ramps.py`, `ramps.json`). Each sheet's crown and trunk were measured as a ramp from shadow to highlight. In every style the kit's greens are a different family from the sheet's:

   | Style | Kit's leaf greens | Sheet's crown, shadow to highlight |
   | --- | --- | --- |
   | Low-poly tropical | `#2F7A34 #3F8F3A #6DB33F #A7C94A` | `#233019 #3B4A21 #586C27 #939B2D #C5C44A` |
   | Voxel | `#2E8A2E #4CAF3C #86CF45` | `#18330B #2B5C11 #448114 #69A715 #A1D026` |
   | Anime cel | `#3B7B3B #5C9F40 #8DC555 #BCDC6E` | `#3A4634 #546040 #757C49 #A9A550 #D0C870` |
   | Solarpunk | `#3D6E2C #5A9233 #86BA4A #BFD66A` | `#342F14 #4C4C1F #6A6A29 #979139 #C5BE5C` |
   | Neon noir | `#18402A #265E36 #3D7E45 #5B9650` | `#171A12 #2B291A #4A3D1F #846127 #DAA854` |
   | Pixel art | `#285C34 #3E8C3E #78BE50` (fixed palette) | `#0A3832 #11573A #3F8030 #7CA721 #A6C225` |

2. **Painting and shading baked into vertex colours** (`shade.py`, run after the kits' own `bake.py`). Every leaf and bark face is given a place on the sheet's ramp by rank, from how it faces the painted light, how much sky it sees (rays cast against the model), its cluster, the generated model's local light and dark, and a little chance. Faces that look up and the rest are ranked separately, so the view from above and the view from the street both show the whole ramp. Then the game's own light at the hour the sheets are drawn (13:00; 21:48 for neon) is partly divided back out per colour channel, so a face the sun will hit gets a darker colour and a face in shade a lighter one. Other faces keep their kit colour, darkened where they see little sky.

3. **Leaf masses drawn the way each sheet draws them.**
   - Low-poly (`build_lowpoly2.py`): about 260 lobed, domed leaf pads, most with a smaller lighter pad laid over them, on a dark core, with small blossoms. Round 1 had 26 large lobes; the kit has 17. Faceted balls were tried first and read as rocks.
   - Anime, solarpunk, neon (`build_cards2.py`): 51 to 60 small lobes of the kits' leaf cards in place of round 1's 30; limb ends that stuck out of the crown are left off; the anime tree has no aerial roots, as its sheet has none; in neon, leaves take the ramp's warm end by how near the tree's lamp they are.
   - Voxel (`build_voxel2.py`): every leaf block keeps its own faces (the kit's writer merges them into slabs), a few blocks are cut out of the surface and a few set proud, each face runs lighter toward the painted light, and the limbs' flat spread under the crown is cut back to a trunk with stubs.
   - Pixel art (`pixel_pre2.py`): the model behind the sprite is about 280 small lobed clumps (470 pads) standing apart on a dark core; the kit's renderer, 32-colour palette, dither and outline are untouched.

4. **Fitting** (`calibrate.py`). For the five 3D packs the painting's gains were fitted in a few rounds of build, capture in the game, and measure, against the sheet's five tone bands from the street and from above.

5. **The pack's light** was tested three ways on low-poly and left as it is (see below).

## Results

`compare/overview-six-styles.png` and `compare/<style>.png` show the sheet, the game today, round 1 and round 2. Captures are from a scratch copy of the client with only the tree's asset swapped; a view without the tree (`park`) differs from today's by under 0.01 of 255 on average in every pack. The captures themselves are not kept in the repository; `banyan_captures.sh` takes them again.

How the crown looks from the street, by five measures that the colours were *not* fitted to (`metrics.txt`: contrast, fine detail, colour variety, share of deep shadow, share of highlight), as distance from the sheet (mean absolute log ratio; 0 is identical):

| Style | Today | Round 1 | Round 2 |
| --- | --- | --- | --- |
| Low-poly tropical | 1.40 | 1.10 | 0.31 |
| Voxel | 1.52 | 1.68 | 1.04 |
| Anime cel | 0.62 | 1.48 | 0.35 |
| Solarpunk | 0.96 | 0.69 | 0.39 |
| Neon noir | 0.61 | 0.56 | 0.47 |

The crown's colour against the sheet's five tone bands (mean colour difference, CIE76; this *is* what was fitted, so it shows the fit worked, not an independent gain; `colour-distance.json`):

| Style | Street: today | Street: round 2 | Above: today | Above: round 2 |
| --- | --- | --- | --- | --- |
| Low-poly tropical | 24.7 | 4.5 | 30.0 | 5.4 |
| Voxel | 17.9 | 5.5 | 35.6 | 6.4 |
| Anime cel | 22.3 | 4.6 | 29.2 | 3.6 |
| Solarpunk | 17.7 | 7.1 | 28.3 | 4.5 |
| Neon noir | 19.4 | 8.2 | 27.0 | 7.6 |

Pixel art has no such measures (a 2D sprite, another camera). In its crown the palette's light green went from 6% of the pixels (today and round 1: mid green 50%, dark green 42%, light green 6%, outline colour 2%) to 32% (dark green 45%, light green 32%, mid green 20%, outline colour 3%). The sheet's own bands, taken to the nearest palette colour, would be about 35% light green, 30% mid green, 25% dark green and 10% the outline colour.

Triangles: low-poly 17,851 (today 6,045; kit budget 6,500), voxel 10,434 (7,306; 7,500), anime 9,916 (7,326; 7,500), solarpunk 13,050 (6,475; 7,500), neon 13,174 (5,942; 7,500). Frame cost was not measured.

## What the light tests showed

Three changes to the low-poly pack's light were captured and measured against the sheet (the pack code they needed is `light-tests/pack_3d-light-block.diff`, inactive unless a style asks for it, and still applying to the pack on 2026-10-02; the tests' captures are not kept):

- **Ambient light from the sky** in place of one colour: the crown's underside went darker (mid-tone lightness 0.19 against 0.29), because the sky lights from above and little comes from below.
- **A gentler tone curve with a warmer, stronger ambient**: the whole frame went lighter and paler; roofs, lawn and water moved away from the sheet (lawn lightness 0.75 against the sheet's 0.53, where today's is 0.72).
- **A softer sun with stronger ambient and haze from 12 m**: a lamp post's shadow on the paving went from lightness 0.76 to 0.80 (lit paving 0.91). The sheet's ground shadow is 0.57 against 0.70 lit, a ratio of 0.81, which the pack's own light (0.84) is nearer to than the softer one (0.88). A far building's contrast fell slightly (0.24 to 0.22), and the fitted tree went too light.

None brought the frame closer by these measures, so every result above is under the pack's own light. The light was not what kept the tree from its sheet; the colours given to that light were.

## Limits

- One asset, one generated shape (two for voxel), one seed. The kits' tests were not run on these assets; all five 3D trees are over their kits' triangle budgets.
- The colours are fitted to the hour the sheets are drawn. At other hours the tree keeps its painted tones: at dusk every pack's tree still looked plausible; in the evening rain the solarpunk tree reads lighter than its surroundings.
- Neon stays darker than its sheet (highlight band 0.54 against 0.68): at night the leaves are lit by one lamp, and their colours are already as light as a surface can be.
- Voxel moved least from the street: an eye-level camera sees the cubes' sides and undersides, the sheet's camera sees their lit tops.
- Anime's leaf cards carry the pack's ink lines, so its crown has about twice the sheet's fine detail (it had that before, too).
- Pixel art is held by its fixed 32-colour palette: three greens, where the sheet uses a teal-black shadow and a yellow-green highlight that are not in it.
- The frame round the tree was not changed. In the sheets the square is full of planters, flower beds, people and palms; in the game it is bare paving and benches.

## Re-running

[`../../WORKFLOW.md`](../../WORKFLOW.md) is the step-by-step procedure, with what changes by style and by kind of asset. In short:

```sh
export AGENTNAGAR=/path/to/agentnagar                        # the checkout; every script reads it
../../tools/setup.sh /path/to/work                           # scripts, data, a copy of the client, a Python environment
cd /path/to/work
blender --background --factory-startup --python build_lowpoly2.py -- parts lowpoly_tropical out2/lowpoly_tropical/tree_banyan.glb params/lowpoly_tropical.json
blender --background --factory-startup --python build_cards2.py -- anime parts lowpoly_tropical out2/anime_cel/tree_banyan.glb params/anime_cel.json
blender --background --factory-startup --python build_voxel2.py -- parts voxel out2/voxel/v2/tree_large.glb params/voxel.json
./pixel_run.sh params/pixel_art.json                         # render, post-process, palette shares
./banyan_captures.sh                                         # the game today, with round 1's trees and with round 2's
cvenv/bin/python calibrate.py lowpoly_tropical 3              # build, capture in the game, measure, adjust
python3 check_band.py out2/*/tree_banyan.glb                 # nothing where people walk outside the tree's square (the game's rule)
cvenv/bin/python metrics.py; cvenv/bin/python compare2.py
```

Checked on 2026-10-01 from a clean working folder made by `setup.sh`, and again on 2026-10-02 after the scripts were extended for the bench test: all five 3D trees rebuild byte for byte, `ramps.json` and `metrics.txt` reproduce exactly from the recorded frames, and one round of the capture-and-measure loop for low-poly gives the recorded band errors (street 0.011, trunk 0.017, above 0.011).

Checked once more on 2026-10-02 from this repository copy, which does not hold the recorded frames: the five trees and the sprite rebuild byte for byte, as do round 1's trees with round 1's builders, and `ramps.json` reproduces exactly. The frames taken again by `banyan_captures.sh` came out 1904 by 1064 where the recorded ones are 1920 by 1080 (the nested desktop decides the game's window size), so they are not the recorded frames pixel for pixel. From them `metrics.py` gives every distance within 0.02 of `metrics.txt` (the largest difference is voxel's round 2, 1.056 against 1.036), the comparison sheets come out a few pixels wider, and the fit round for low-poly gives band errors of 0.012, 0.017 and 0.011. The scripts are pilot code, not project code.
