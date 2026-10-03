# Low planting: round shrub, leafy shrub, flowerbed

> In this record the pieces are in `out/<style>/`, the agent's own preview sheets are in `previews/planting/` (as JPEG) and its tools are merged into `tools/`. Where the report names `work/`, `base/`, `logs/`, `scratch/`, `out/` or `previews/`, it means the agent's own folder in the working folder (`agents/planting/`), of which only the pieces and the previews are kept here. The report is as the agent gave it; what happened afterwards is at the end.

Written by Claude (an AI build agent), 2026-10-02, 12:27 to 15:32, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). Everything is in `agents/planting/`. Nothing was written in the checkout, the main working folder, `raw/` or `crops/`. The game, Godot, the collision audit, the kits' test suites and the image-to-3D model were not run. Every picture named here was looked at by the agent.

## Summary the agent gave first

1. **Built** (`out/<style>/`): round shrub, leafy shrub and flowerbed in low-poly, neon, anime and solarpunk, plus the voxel shrub and voxel bed (the voxel kit has one shrub file). `check.py` exits 0 on all 14.
2. **Shrubs** are a closed skin drawn over the generated ball; cut down straight they came out as shards. One mesh `body`, no transforms, one material, reach 0.550 m as the kit's, so the game draws them 2.1 m across. Their widest ring lies on the footprint circle at 0.40 m or higher.
3. **Shrub triangles:** 1,500 in neon, anime and solarpunk, 800 in low-poly, 202 in voxel. In anime 800, 1,500 and 3,000 are hard to tell apart (`previews/shrub-triangle-counts.png`); 800 would halve the cost of 116 copies.
4. **Beds** are sized by their kerb: a plain box on the kit's sides, 0.30 m high, with the generated stone baked on. Plants are cut separately: 8,000 triangles, 4,000 in low-poly, 200 in voxel. Neon's bed has `lights` in an emitting `lamp_glow`, as the design's lit strip.
5. **Weakest: the loose leafy shrub, in every style.** The skin bridges its gaps, so it is a solid mound with its flowers lost. Low-poly and solarpunk draw it for about half the 116 shrubs.
6. **Also weak:** the voxel bed (plants flat and dark, 72% of the design's colours found, corner posts lost); no shrub has a leafy outline; bed plants are pressed to 0.34 to 0.62 of their height; the solarpunk planter's rounded ends are gone.
7. **Not checkable from a file:** the collision audit, the kits' rebuild test (any swapped file fails it), the Khronos validator, frame cost, and the look under toon, ink and night.
8. **Tools:** 14 new options in `work/fit_generated.py` (`check_options.py` passes, 85); `voxelise.py` gained `--drum`, `--close`, `--on-lines`; `check.py` plus new `planting_rules.py`; new `drawn.py` and `preview.py`.
9. **Bench proof:** identical byte for byte between `base/` tools and `work/` tools (`logs/bench-cmp.txt`). The main folder's `seat_bench_v2.glb` was rebuilt at 14:30 by the changed main tools, so `cmp` against it now differs; the agent's matched it at 12:37 and 13:52.
10. **Merge:** the main `fit_generated.py` gained `--reach` meanwhile with another meaning; the agent's is named `--shrub`. Ten base lines changed, the rest is added.
11. **Decisions left open:** plants may hang 3 cm over a kerb (the note says none; `--bed 0.30,0` is strict); the anime 12% lift is off for shrubs; neon's bed has a strip, not four lamps.
12. **Meadow (not built):** the sheets give colours, height (0.89 to 0.99 m, near the kits' 0.88) and flower counts. Their width (0.72 to 0.84 m) cannot be used: the kits' clumps are 0.33 m and the spacing test depends on it.
13. **Time:** about three hours, not 45 minutes.

## What is built

Fourteen pieces: the three objects of sheet `A-low-planting` in low-poly, neon, anime and solarpunk, and the voxel shrub and bed. `check.py` passes on all of them (`logs/check.txt`).

| Style | Piece | File | Triangles | Kit's limit (kit's piece) | Size x, y, z (m) | Spec (m) | Materials | File size | Colour off the design | Design colours found |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Low-poly | round shrub | `shrub_round.glb` | 800 | 1,500 (612) | 1.10, 0.91, 1.10 | 1.1, 0.9, 1.1 | `sheet_albedo` | 0.17 MB | 3.2 | 100% |
| Low-poly | leafy shrub | `shrub_leafy.glb` | 800 | 1,500 (528) | 1.10, 1.22, 1.10 | 1.1, 1.2, 1.1 | `sheet_albedo` | 0.19 MB | 5.7 | 100% |
| Low-poly | flowerbed | `flowerbed.glb` | 3,998 | 1,500 (1,308) | 3.00, 0.59, 1.05 | 3.0, 0.6, 1.0 | `sheet_albedo` | 0.61 MB | 4.0 | 100% |
| Neon | round shrub | `shrub_round.glb` | 1,500 | 1,500 (670) | 1.10, 0.82, 1.10 | 1.1, 0.82, 1.1 | `sheet_albedo` | 0.21 MB | 1.8 | 100% |
| Neon | leafy shrub | `shrub_leafy.glb` | 1,500 | 1,500 (684) | 1.10, 1.26, 1.10 | 1.1, 1.24, 1.1 | `sheet_albedo` | 0.23 MB | 9.7 | 90% |
| Neon | flowerbed | `flowerbed.glb` | 8,012 | 1,500 (1,264) | 3.07, 0.60, 1.08 | 3.04, 0.6, 1.02 | `sheet_albedo`, `lamp_glow` | 1.26 MB | 7.2 | 94% |
| Anime | round shrub | `shrub_round.glb` | 1,500 | 1,500 (670) | 1.10, 0.83, 1.10 | 1.1, 0.82, 1.1 | `sheet_albedo` | 0.17 MB | 1.5 | 100% |
| Anime | leafy shrub | `shrub_leafy.glb` | 1,500 | 1,500 (684) | 1.10, 1.29, 1.10 | 1.1, 1.24, 1.1 | `sheet_albedo` | 0.25 MB | 1.9 | 100% |
| Anime | flowerbed | `flowerbed.glb` | 7,992 | 1,500 (1,216) | 3.10, 0.60, 1.08 | 3.02, 0.58, 1.05 | `sheet_albedo` | 0.73 MB | 7.0 | 100% |
| Solarpunk | round shrub | `shrub_round.glb` | 1,500 | 1,500 (670) | 1.10, 0.82, 1.10 | 1.1, 0.82, 1.1 | `sheet_albedo` | 0.24 MB | 3.5 | 100% |
| Solarpunk | leafy shrub | `shrub_leafy.glb` | 1,500 | 1,500 (684) | 1.10, 1.26, 1.10 | 1.1, 1.24, 1.1 | `sheet_albedo` | 0.23 MB | 5.9 | 95% |
| Solarpunk | flowerbed | `flowerbed.glb` | 7,999 | 1,500 (1,192) | 3.05, 0.58, 1.11 | 3.02, 0.58, 1.05 | `sheet_albedo` | 1.21 MB | 5.7 | 100% |
| Voxel | shrub | `shrub.glb` | 202 | 500 (410) | 2.10, 0.80, 2.10 | 2.1, 0.8, 2.1 | `cubes` | 19 kB | 0.8 | 100% |
| Voxel | flowerbed | `flowerbed.glb` | 200 | 650 (474) | 2.00, 0.50, 1.00 | 2.0, 0.5, 1.0 | `cubes` | 19 kB | 1.6 | 72% |

- The figures are from `out/results.json` and each piece's report, `out/<style>/<file>.json`.
- The two colour columns are the route's own measures. For the voxel pieces they are those of the fitted piece the cubes were coloured from.
- **Parts.** A shrub is a root node with the kit's name and one mesh, `body` (`bush` in voxel), with no node transform. A bed is root `flowerbed` and mesh `body` (`bed` in voxel); neon's also has `lights`. A bed's mesh is a kerb of 10 triangles and plants that take the rest.
- **Textures.** One colour texture a piece, 1,024 pixels square, WebP; the voxel pieces' are 256 pixels, PNG. The neon and solarpunk beds also carry a relief map; the others have none.
- **Shrub reach.** Every shrub's reach is the kit's: 0.550 m, and 1.050 m in voxel. So the game scales them across by 1.909 (1.000 in voxel), as it scales the kit's.

## Look first

- `previews/<style>/<piece>.png`, fourteen sheets. Each has the design cut-out, then the kit's piece and the new piece from a walker's eye, from a quarter above and from straight above, shaded and in colour. They are shown first as their files have them and then as the game draws them. The red line on the lawn is the footprint.
- `previews/shrub-triangle-counts.png`: the round shrub at 800, 1,500 and 3,000 triangles in anime, and at 400, 800 and 1,500 in low-poly, as drawn.
- `previews/raw/*-strip.png`: the generated models as they came (anime and low-poly).

These are Blender renders made by `work/drawn.py`, with a sun, the sky and shadows. They show form and colour, not the game's shading: there is no toon step, no ink line, no night and no rain.

## How each is built

**A shrub is a skin, not a cut-down mesh.**
- A generated shrub is about 147,000 triangles of thin leaves. Asked for 1,452, the reduction stopped at 9,364 and gave shards. Rebuilt from cells it came out as a lumpy shell with a second wall inside, and at finer cells its outline broke.
- So the outside alone is taken. From a point on the shrub's axis, in about 750 evenly spread directions, the skin stands as far out as the model does there.
- Forty-eight of those directions lie level, at the height where the shrub is widest. That ring of corners is put exactly on the circle of the kit's reach, and the rest of the shrub is scaled across with it.
- That ring is the full circle the collision audit wants. It is the shrub's own surface: no drum and no added part.
- Under the ring the skin is held out so the shrub stands on the lawn, and it meets the ground in a second ring of 48 corners.
- **Colours.** Each texel takes what lies within 6 cm behind the skin, looking straight in; failing that, the nearest leaf.
- **Tones.** Lightness and colour are then matched to the design by rank: the darkest tenth of the texture takes the darkest tenth of the design, and so on. Matched material by material, a shrub came out one flat green.

**A bed is sized by its kerb and cut in two parts.**
- Filling the kit's box, as the route does for a seat, put the plants on the box's sides and the kerb inside them at 0.18 m. That is under the audit's band.
- So the kerb's top and walls are found in the generated model. The walls go to the sides of the kit's box, the top to 0.30 m, and the plants to the rest of the box's height.
- The kerb is then a plain box of ten triangles, with the generated kerb's stone and joints baked on.
- The plants are everything above the kerb or outside its walls, rebuilt from 12 mm cells and cut down on their own.
- Cut as one mesh at 6,000 triangles, the flowers melted into a carpet and the walls came out dented.

**A fault found late and fixed.** The first rule for finding a kerb's end walls took the place where a quarter of the upright area lay.
- On the voxel model, whose kerb is separate cubes, it took a joint inside the kerb for the end wall.
- On the low-poly model it put the ends 5 cm inside the real ones. The pull-in of overhanging plants had hidden this (3,035 vertices pulled then, 79 now).
- The rule is now the outermost place where upright faces stand in number. All five beds were rebuilt and looked at again.

**Voxel.**
- The shrub is the fitted skin rebuilt from 249 cubes of 0.2 m, on a 32-sided drum 1.05 m in radius and 0.4 m high, as the kit builds its own. Cubes cannot follow a disc.
- The bed is a 2 m module of 625 cubes of 0.1 m. The game draws two to a bed.

## The contract's rules

The checks are in `work/check.py` and `work/planting_rules.py` and read the built file alone. The same rules run on the kits' own fourteen files with `check.py --kits`; all pass (`logs/check-kits.txt`). That is the check on the rules themselves.

### Shrubs (nine files)

| Rule | Met | How it was checked |
| --- | --- | --- |
| One mesh, the first | yes | counts the mesh nodes in the order the engine meets them |
| No node transform | yes | no node has a translation, rotation, scale or matrix |
| Origin at the middle; reach the kit's | yes: 0.550 m, 1.050 m in voxel | the game's own measure (vertices between 0.15 and 2.2 m and where edges cross those heights), against the same measure of the kit's file |
| Nothing wider below 0.15 m than in the band | yes | the fit pulls every vertex inside the circle at any height; the spec's size rule passes |
| The outline where people walk is a whole circle | yes: at least 0.998 of the reach in each of 360 directions; 0.995 for the voxel drum, as the kits' | what the first mesh draws between 0.30 and 1.59 m, flattened as the audit flattens it, along 360 rays |
| Spec size and named nodes | yes | the kit tests' own rule |
| At most two materials (anime, neon, solarpunk) | yes: one | counted |
| No material named as the game names what it lights or wets | yes | names checked against the note's list |
| Voxel: no node below the root shares its name | yes | checked |
| Anime: no ink line on every facet | by construction only | smooth leaf masses, no relief map, rounded normals on the leafy shrub; the ink pass was not seen |

**The ring's height is the agent's reading, not the note's.** The note says a circle from 0.30 m is enough. The audit's band starts 0.25 m above the ground drawn under the piece, and the game can squash a shrub to 0.85 of its height. A ring at 0.30 m leaves half a centimetre for raised ground; the kits' drum, 0.4 m high, leaves nine. So each shrub's ring is at 0.40 m or higher (neon leafy 0.61, anime leafy 0.65).

### Flowerbeds (five files)

| Rule | Met | How it was checked |
| --- | --- | --- |
| The spec's nodes | yes; neon has `lights` | the kit tests' rule |
| The kerb is a whole rectangle higher than 0.25 m | yes: a box, 0.30 m | along the edge of the slice (304 to 418 points) something is drawn between 0.255 and 1.9 m within 10 cm as the game draws it |
| Nothing reaches outside the outline in the slice | partly | plants may hang 3 cm over the kerb, and do; see Decisions |
| Neon: `lights` with an emitting `lamp_glow` | yes | read from the file |
| No acted-on material names | yes | checked |

As the game will stretch them, by its rule:

| Style | Slice (m) | Drawn longer by | Drawn deeper by |
| --- | --- | --- | --- |
| Low-poly | 3.000 by 1.050 | 1.100 | 1.238 |
| Neon | 3.067 by 1.080 | 1.076 | 1.204 |
| Anime | 3.097 by 1.080 | 1.066 | 1.204 |
| Solarpunk | 3.053 by 1.109 | 1.081 | 1.173 |
| Voxel, two copies | 2.000 by 1.000 | 0.825 | 1.300 |

The kits' own beds are drawn 1.087 to 1.100 times longer and 1.24 to 1.30 times deeper.

### Could not be checked from a file

- **The collision audit.** Its counts must stay zero. The checks follow the audit's code, but it reads placed copies on the walking grid inside the engine.
- **The kits' rebuild test.** Any swapped file fails it, as the note says.
- **The pinned Khronos validator.** Not run.
- **Frame cost** of 116 textured shrubs and of beds at 4,000 to 8,000 triangles.
- **Importer LODs.** Whether the LODs the importer makes for `shrub_round` in low-poly harm a skin.
- **The look in the game:** toon and ink in anime, neon's lamps at night, rain.
- **Hard-coded in the check:** the drawn rectangle (3.30 by 1.30 m) and the skins' module lengths, from the note; they are not read from `style.json`.

## What is wrong or weak

1. **The loose leafy shrub, in every style.** A skin bridges the gaps between its branches, so it is a solid mound with no stems or loose outline.
   - Its flowers are lost as shapes: mauve specks in neon, pale streaks in solarpunk, salmon facets in low-poly.
   - In neon its colours are 9.7 off the design.
   - It is stretched 1.5 to 1.6 times in height to fill the kit's box.
   - It matters most in low-poly and solarpunk, where the game draws it. In neon and anime no skin names the file.
2. **The voxel bed.** Its plants are one or two cubes high, dark and flat. Only 72% of the design's colours are found: the bright greens and most white flowers are gone, and so are the corner posts.
3. **No shrub has a leafy outline.** The kits fringe theirs with leaf cards. These are closed skins, and their leaves are texture only.
4. **The game's stretch smears the leaves.** A shrub is drawn 1.91 times wider than built, so leaf shapes on its sides are about twice as wide as tall.
5. **The round shrubs are reshaped below the ring.** The generated balls are widest at 0.25 to 0.35 m. That ring is moved to 0.40 m, and under it the skin is held out by up to 3.5 cm (low-poly), 6.7 cm (neon), 17 cm (anime) and 34 cm (solarpunk). Without this, a ball drawn twice as wide was a saucer hovering over the lawn.
6. **Bed plants are low.** The kit's box is 0.60 m and the kerb takes 0.30 m. The plants are pressed to 0.34 to 0.62 of their height in proportion to their spread. The designs' kerbs would be 0.40 to 0.57 m high at this length.
7. **The kerb is a plain box.** Its joints are texture, so anime's ink will not draw them. Bevels and copings are gone. The solarpunk planter's rounded ends are lost; its ceramic, timber and brass are baked on squarely.
8. **Bed colours.** Anime's foliage reads darker than its design and its daisies have no yellow centres. Neon's plants are greener than the design's olive.
9. **Shrubs carry the drawing's light.** Each shrub's texture has the design's lit top and shaded sides, and the game shades it again. Taking the light out of the texture gave two-tone camouflage, so it was kept in. Only the game can settle this.
10. **File size.** A shrub is 0.17 to 0.25 MB against the kits' 27 to 120 kB. A bed is 0.6 to 1.26 MB against 72 to 181 kB.
11. **The anime leafy shrub** is 1.29 m high against the spec's 1.24. That is inside the spec's tolerance.

## Triangles

- **Shrubs.** 1,500 in neon, anime and solarpunk; 800 in low-poly; 202 in voxel.
  - In anime 800, 1,500 and 3,000 are hard to tell apart from a walker's eye, because the texture carries the leaves. The kit's limit was built. 800 would look the same and halve the cost of 116 copies.
  - In low-poly each facet is one colour, so the count is the look. 400 is coarse, 800 has facets about the size of the design's leaves, and 1,500 reads less as low-poly.
  - Nothing needed more than the kit's limit.
- **Beds.** 8,000, and 4,000 in low-poly, against the kits' 1,500. How low the two-part cut can go was not tried.

## Tool changes

`python3 work/check_options.py` passes: 85 options documented and read.

**The bench proof.** The file the brief names, the main folder's `out/anime_cel/seat_bench_v2.glb`, was rebuilt at 14:30 by the main tools, which had changed by then. The agent's bench matched it byte for byte at 12:37 and at 13:52, and cannot since. So the proof is now this: `base/` copied to `scratch/basecopy/work` and run on the same model gives the same file as `work/` (SHA-256 `353f9446…` for both; `logs/bench-cmp.txt`).

**For the merge.** The main `fit_generated.py` gained `--reach` with another meaning, so the agent's is `--shrub`. Ten of the base's lines are changed in `fit_generated.py`, eight in `voxelise.py`, one in `check.py` and none in `build.py`. The rest is added.

`work/fit_generated.py`, fourteen new options:

| Option | What it does | Why |
| --- | --- | --- |
| `--shrub R\|kit`, `--ring-least M` | origin to the middle; reach set to R; everything pulled inside that circle; the widest ring moved up to at least M (0.4) | the game scales a shrub by its reach about its origin |
| `--round F`, `--round-most` | the outline drawn to the circle, on the model and again on the piece after the bakes | the audit wants the whole circle |
| `--skin N`, `--skin-wide F` | the piece is a skin of N triangles drawn from outside; wider gives fewer, rounder masses | shards and inner walls from the other two cuts |
| `--skin-tuck T` | under the ring the skin is held out and meets the ground in a ring | the hovering saucer |
| `--skin-colour rays\|nearest`, `--skin-look M` | where the skin's colours come from | a ray cast in where the skin is held out brings back bare stems |
| `--all-leaf` | the whole piece is leaf for `--leaf-smooth` and `--leaf-round` | those were for trees cut by `--parts` |
| `--tones-by-rank TOP` | lightness and colour matched to the design by rank | flat green foliage |
| `--facet-colour` | one colour a triangle | low-poly |
| `--bed KERB[,OVERHANG]` | a bed sized by its kerb and cut in two parts | above |
| `--kerb-tones UP,DOWN` | the kerb walls held within a range of lightness | the generator's painted edge light showed as a pale frame; off for solarpunk's three materials |

Changed without a new option:
- `--under-glow` with `--bed` runs round the kerb, not round the overhanging plants.
- `--bed-colour` with `--bed` recolours all of the walls' texels and those just outside them. A kerb moved from cream to sandstone had kept a cream line along every corner.

Tried and removed: a flat disc joined into the mesh to make the circle (it showed as a ring round the shrub), and taking the generator's top light out of the colours.

Other files:
- `work/voxelise.py`: `--drum R,H[,SIDES]`, `--close` (a skin and a kerb box have no underside and filled no cell), `--on-lines` (the kerb on the grid's lines whatever the plants do).
- `work/build.py`: passes `voxel.drum`, `close`, `on_lines` and `cover`.
- `work/check.py`: the planting rules, and `--kits`.
- `work/planting_rules.py` (new): the rules, their sources, and what a file cannot show.
- `work/drawn.py` (new): a piece as the game draws it.
- `work/preview.py` (new): the fourteen sheets.
- `work/assets.json`: the three entries, complete for five styles.

## Decisions the agent made

All are settings in `work/assets.json`.

1. Shrubs are skins with their own widest ring as the circle. The kits' way, a drum under the generated shape, is the alternative.
2. The ring is at 0.40 m or higher.
3. The skin is held out under the ring: 12% in at the ground for the round shrub, 40% for the leafy one.
4. Shrubs are 1,500 triangles, and 800 in low-poly.
5. Tones go by rank, and the anime 12% lift is off for shrubs.
6. One colour a facet in low-poly, for shrubs and the bed's plants.
7. The loose shrub outside low-poly has a wider skin, colours as seen from outside, and rounded normals. Three other ways were looked at; this one keeps leaf shapes.
8. **A bed's plants may hang 3 cm over its kerb.** The note says nothing may reach outside the outline.
   - With none allowed, the trailing plants the designs draw vanish into the stone.
   - With 3 cm, the kerb is drawn up to 3.6 cm inside the footprint.
   - The audit's rule leaves about 12 cm: something solid must lie within 10 cm of each blocked cell's centre, and those centres lie 2.5 cm inside the rectangle.
   - `--bed 0.30,0` is the strict setting.
9. Kerbs are 0.30 m high in every style.
10. The kit's box heights are kept, as the seats keep theirs.
11. Neon's bed has the design's lit strip, not the kit's four lamps. It is a slab 14 mm high under the coping, 6 mm proud at the ends and 2 mm at the sides. It glows and lights no ground, like the kit's.
12. Solarpunk's bed is a square box with the planter's materials on it.
13. The leafy shrub is built in neon and anime though nothing draws it there.
14. Shrubs take `"capture": false`. Nothing in the game is a scene instance of a shrub.
15. Voxel: shrub cubes of 0.2 m on a drum; bed cells filled at three tenths. At a half the plants were one flat layer.

## The meadow clumps (object 3, not built)

The sway shader takes no texture, so a clump is built by rule. What the sheets can still give it:

| Style | Grass clump's swatches | Flowering clump's swatches | Grass clump, width by height (m) | Flowering clump (m) |
| --- | --- | --- | --- | --- |
| Low-poly | `#495529` `#70822C` `#B5B530` | the same and `#EFDABB` | 0.73 by 0.96 | 0.75 by 0.89 |
| Neon | `#28291D` `#534C29` `#8C6B3D` | `#2E2F20` `#534C29` `#5C408B` | 0.84 by 0.98 | 0.84 by 0.92 |
| Anime | `#415138` `#738155` `#99A55B` `#C6C764` | `#435337` `#768456` `#A3AE60` `#D3828D` `#F1EEEC` | 0.79 by 0.93 | 0.72 by 0.93 |
| Solarpunk (the two touch; one row of swatches) | `#515129` `#767335` `#A0953F` `#E0C097` | `#846AA3` `#F2E8DC` `#87843C` | about 0.80 by 0.93 | about 0.80 by 0.89 |
| Voxel | `#274922` `#4D8E1C` `#92C717` | the same and `#F4EEE9` | 0.82 by 0.99 | 0.83 by 0.96 |

Sizes are at the sheet's scale, taking the round shrub as 1.1 m.

- **Colours:** three or four greens a clump, dark to light, usable as vertex colours along a blade, plus the flower colours for the heads.
- **Height** agrees with the kits (0.88 to 0.89 m).
- **Width does not.** The sheets draw fans 0.72 to 0.84 m across and the kits' clumps are 0.33 m. The planting margin and the 4.5 cm spacing test depend on that; the note puts the limit at a reach of 0.36 m. The spread can set how far the blades lean, not the clump's width.
- **Flowers:** about five daisies and three pink spikes in anime, four cream flowers in low-poly, about nine purple spikes in neon. Neon's and solarpunk's grass clumps have tan plumes the kits have no part for.
- The cutter found the pair as one object. They would need cutting apart.

## What remains

1. **The game.** Place the pieces, run the collision audit, and look at them under each style's light.
   - For neon and anime, `props.shrub.scenes` needs `assets/shrub_leafy.glb` before the leafy shrub is drawn.
   - The capture tool finds no shrub, and finds a bed only once it looks at the children of the placement's node.
2. **A better loose shrub.** Next to try: a dark inner mass with the model's own leaf clusters cut as separate masses on it, as the great tree's crown is built.
3. **The voxel bed's plants.** A taller module, or plants built in the kit's 0.2 m blocks.
4. **A lighter shrub:** 800 triangles in the three smooth styles and a 512-pixel texture.
5. **Taller kerbs and plants.** The specs' tolerance allows 0.66 to 0.68 m.
6. **The Khronos validator** on one of these files.

## Files

In `agents/planting/`:

- `out/<style>/`: the fourteen pieces with their reports and textures; `out/results.json`.
- `out-mid/voxel/`: the fitted pieces the cubes were made from.
- `work/`: the tools. `base/` is untouched.
- `previews/`: the sheets named above.
- `logs/`: `check.txt`, `check-kits.txt`, `check-options.txt`, `bench-cmp.txt`, `fit.txt`, `built-sha256.txt`.
- `scratch/`: trials and the base tools' copy used for the bench proof (223 MB; it can go).

## Afterwards: what the game showed

Added by the coordinating session (Claude, an AI), which placed the pieces in the working copy of the game, ran its collision audit and captured them. The agent had seen none of this.

- **The audit.** With the pieces placed the game's collision audit counted zero in every style, as the agent's file-side rules had said (the leafy shrub is not drawn in neon and anime, where nothing in the style names its file). That includes the plants hanging 3 cm over a kerb, which the agent had left as an open decision.
- **The shrubs are the weakest pieces of the batch in the game.** In low-poly and solarpunk both shrubs read as mossy rocks: a patchwork of dark and light olive, the flowers gone (`compare/planting-<style>.jpg`). The cause is the one the agent named as its ninth weak point: each texture carries the drawing's lit top and shaded sides, and the game shades it again. The kit's shrubs are a clean green drum with a tuft of leaves.
- **Anime planting came out dark and muddy** for the reason the anime trees did: the toon step draws a face turned from the sun in shadow.
- **The low-poly flowerbed's kerb is dark taupe** where its design draws cream stone. The sheet has two stone swatches, the stone's face and its shade, and the rule that recolours a kerb took the darker.
- **The voxel shrub's drum is nearly black-green**, and the voxel bed's plants are dark and flat, as the agent said.
- **Neon** reads well: its bed's lit strip shows, and its plants are as dark at night as the kit's.
- **The solarpunk flowerbed** is the best of the family.

The second pass below is the same agent's, on these findings.

## Low planting, second pass

Written by Claude (an AI build agent, the same one that built the first fourteen pieces), 2026-10-02, 15:35 to 18:38, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). It worked in `agents/planting/`, on what the coordinating session had seen of its pieces in the game, and merged its own tools onto the main tools as copied at 18:27. None of what follows had been seen in the game by the agent.

### 1. Merged tools

- **Where:** `merged/work/` is the main `work/` (copy and hashes in `main-snapshot/`) plus the agent's changes.
- **What to take, seven files:** `fit_generated.py`, `voxelise.py`, `check.py`, `assets.json` (changed); `planting_rules.py`, `drawn.py`, `preview.py` (new). `build.py` is the main tool's, untouched.
- **If the main tools move again:** `merge/remerge.sh` takes a fresh copy, merges three ways and stops on a conflict. It ran three times today; twice it stopped on lines both sides had edited (five places), settled by keeping both changes.
- **Pieces:** `out/<style>/` and `out-leaves/<style>/`, the same bytes as `merged/out/`, built by the merged tools.

### 2. Proof (`logs/final-run-2.txt`)

- **`check_options.py`:** 183 options documented and read (the main tools' 164 and the agent's 19).
- **The agent's pieces:** the 16 planting files (14 and two variants) were built three times with the merged tools and are byte for byte the same each time.
  - 14 of them are also byte for byte what the agent's own tools built before the merge; the two voxel files differ on purpose.
  - The three it did not mean to change are byte for byte the accepted files: the neon round shrub, the neon bed, the solarpunk bed.
- **The main folder's pieces:** each was built with the main tools and with the merged tools and compared with the main `out/`. All are identical three ways:

| Piece | Triangles |
| --- | --- |
| anime bench | 1,499 |
| voxel bench | 72 |
| voxel `street-tree-a` | 470 |
| solarpunk planter | 9,187 |
| voxel café table | 106 |
| solarpunk `street-tree-a` | 3,772 (far twin 775) |

  `merge/prove.py` does this for any STYLE:PIECE.
- **Checks:** `check.py`, `check.py --variant leaves` and `check.py --kits` pass.

### 3. What changed in each piece since the first report

Look at `previews/since-first-report-eye.png` and `since-first-report-quarter.png` (each changed piece as first accepted and now, at the game's scale, rendered in Blender) and `previews/anime-toon-step.png`. The per-style sheets in `previews/<style>/` are still the first report's.

- **Low-poly round shrub:** was a faceted skin (the "mossy rock"). Now 390 leaf blades on a dark inside in the sheet's three greens, with 14 cream flowers: 1,436 triangles.
- **Low-poly leafy shrub:** the same route, 380 leaves of 18 by 9 cm and 10 coral flowers with the yellow eye: 1,376.
- **Low-poly bed:** the kerb is the sheet's cream `#E0C7AB` (`auto` had given `#9A8675`); geometry unchanged.
- **Solarpunk round shrub:** leaves on an inside, 480 leaves, 24 pink and white blossoms: 1,479.
- **Solarpunk leafy shrub:** 465 leaves, 30 purple and white blossoms: 1,497.
- **Anime round shrub and bed:** the same triangles as accepted, with leaf normals leaning up (`--leaf-round 0.85 --leaf-lift 1.0`; the bed's plants only). The ring and kerb rules are not disturbed: positions are identical, the kerb keeps its own normals, and the check passes.
- **Anime leafy shrub:** leaves on an inside, 532 leaves, no flowers (its sheet draws none), the same normals: 1,492.
- **Neon leafy shrub:** leaves on an inside, 432 leaves, 36 purple blossoms: 1,494.
- **Voxel shrub:** the same cubes and drum (202 triangles). Each cube that shows is one of the sheet's three greens by rank (17, 30, 20), with 3 white; the drum is the middle green `#4E8F1C` (was `#205019`).
- **Voxel bed:** 150 triangles (was 200).
  - Kerb: a clean ring to 0.3 m in the sheet's lighter stone `#8B8389` (a swatch the cutter missed), one tone a cube.
  - Plants: heaped inside it by the main tools' `--solid` and `--heap 0.3,1,1`, in the three greens by rank (34, 62, 41) with 7 white.
- **Offered, not placed:** the round shrub built as leaves for anime (1,486) and neon (1,492), in `out-leaves/` (entry `shrub-round-leaves`).

### Still weak

- **Solarpunk shrubs:** the dark inside shows as a dark band at the foot of the round one, and as a dark ledge on the thin side of the leafy one.
- **Neon leafy shrub:** by day it reads as a near-black lens with leaves; it has not been looked at by night.
- **Anime shrubs:** the leafy one shows some dark inside on top. The round one's lower half is still dark from the painted texture; the normals only light it evenly.
- **All leaf-built shrubs:** the hoop of leaves across the ring is evenly spaced.
- **Voxel shrub:** a flat cap of two levels. Dark cubes stacked read as bars, and the blossoms are whole 0.2 m blocks. Ranking each cube against its neighbours was tried and looked no better, so the main tools' `flat_tones()` stands.
- **Voxel bed:** the plants stand only one or two cubes above the kerb (the kit's box is 0.5 m and the kerb must be 0.3 m). The design's corner posts are lost.

### Tool changes by option

**`fit_generated.py`**

- Unchanged from the first report: `--shrub`, `--ring-least`, `--round`, `--round-most`, `--skin`, `--skin-wide`, `--skin-tuck`, `--skin-colour`, `--skin-look`, `--all-leaf`, `--tones-by-rank`, `--facet-colour`, `--bed`, `--kerb-tones`.
- New since:
  - `--leaves N,LENGTH,WIDTH[,CORE[,SPACE]]`: with `--skin` and `--shrub`, the skin becomes a dark inside, with its ring kept on the circle. Up to N two-triangle leaves are set where the model's own leaves show outside it, each in the colour the generator painted. A hoop of leaves across the ring and leaves on bare shoulders are added.
  - `--leaves-under`: leaves hidden under the ring are brought out onto the inside (ball shrubs).
  - `--flowers M,SIZE,#HEX[,...]`: flowers found by hue against the sheet's swatches are rebuilt as five-petal stars in the swatch colour.
  - `--flower-centre`: each flower keeps the centre colour the generator painted.
  - `--leaf-swatches #HEX,...`: each leaf snaps to the nearest sheet green.
- `--leaf-lift` is one option, the main tools' code and text. `--leaf-round`, `--leaf-lift` and `--leaf-smooth` now also act on `--all-leaf` and on a `--bed`'s plants. `--core-dark` is also read by `--leaves`, and `--under-glow` works with `--bed`.
- Four of the main tools' code lines carry a change of the agent's, inert without `--skin`: the UV default, two bake ray lengths, and the albedo bake.
- Two renames to avoid collisions with the main tools: the report key `shrub` (was `planted`) and the helper `band_from_above` (the main tools have their own `band_points`).

**`voxelise.py`**

- `--drum`, `--close`, `--on-lines` are as before.
- New `--tone-cubes`: with the main tools' `--tones` on a piece that is not a planted tree, it calls their `flat_tones()` and `shown_points()` unchanged.
  - Only cubes that show are ranked.
  - With `--drum`, the drum takes the middle green.
  - With `--heap`, the heap takes the tones and each rim cube takes its outer wall's colour.
- `mesh_of()` takes an optional list of extra faces (the drum's); it is empty for every other piece.

**`build.py`**: no change. The first report's `voxel` keys are gone; the entries use the main tools' `voxel.flags` and `voxel.solid`.

**`check.py`**: the planting rules run for entries with `--shrub` or `--bed`; `--kits` runs them on the kits' own pieces. Both are as in the first report.

**`drawn.py`**: `--toon EL,AZ` is new.

**`assets.json`**

- `shrub-round`, `shrub-leafy` and `flowerbed` are replaced; the main file's `needle`, `frame`, `_capture` and `batch` are kept. `shrub-round-leaves` is added.
- The solarpunk shrubs now name `--materials 5` and `6`: the main `build.py` lets a piece's own `--materials` stand, and their base flags say 4.

## Afterwards: the second pass in the game

Added by the coordinating session (Claude, an AI).

- **The merge.** The agent merged its own tools onto a snapshot of the tools as merged from the other three families, and proved it there; the seven files went in as it left them. Its preview script is kept as `tools/planting_preview.py`, beside `fixtures_preview.py` and `fountain_preview.py`.
- **The audit.** With the pieces placed the game's collision audit counts zero in all five styles.
- **The validator** passes every one of them.
- **How they look** (`compare/planting-<style>.jpg`). The low-poly shrubs are the most changed: leaves and flowers where there was a mottled lump, and the round one reads as a bush. The low-poly bed's kerb is cream stone, as drawn. The solarpunk shrubs are leafy with their blossoms, and dark: the inside between the leaves is the darkest of the leaf colours, and the game shades it again; a lighter inside was tried in the game and made little difference. The anime round shrub is still a closed skin, evenly lit now, and the anime bed's plants show their flowers. The voxel shrub's drum is the middle green and its cubes the sheet's three greens with white blossoms; the voxel bed is a grey stone kerb planted full.
- **Not placed:** the round shrub built as leaves for anime and neon (`out-leaves/`), which the agent offers beside the skin. It stays an offer.
