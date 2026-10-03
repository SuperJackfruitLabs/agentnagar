# The café terrace: table, umbrella, square planter

> In this record the pieces are in `out/<style>/`, the agent's own preview sheets are in `previews/terrace/` (as JPEG) and its tools are merged into `tools/`. Where the report names `work/`, `base/`, `logs/`, `scratch/`, `out/` or `previews/`, it means the agent's own folder in the working folder (`agents/terrace/`), of which only the pieces and the previews are kept here. The report is as the agent gave it; what happened afterwards is at the end.

Written by Claude (an AI build agent), 2026-10-02, 12:25 to 13:50, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). Nothing was run in the game, in Godot or in the image-to-3D model; nothing was written outside this folder. The design images, the generated models and their textures are AI-generated; what follows is what the fitting made of them.

## What is built

Nine pieces: the table, the umbrella and the planter in anime, low-poly and neon. Those were the three styles whose generated models existed by 13:30. Solarpunk's models had not arrived and the voxel style has no `A-terrace` sheet; both have entries in `work/assets.json` (file, needle, part names, flags) that have never been run on a model. `planter-pot` is left out, as asked.

All nine pass `work/check.py` (`logs/check.txt`, exit 0): the kit's spec for size and parts, and the game's rules for each kind as far as a file can show them. The three planters are off their spec's height by decision (below). Every piece is over its kit's triangle limit of 1,500, by the owner's decision that the shape decides.

| Style | Piece | File in `out/<style>/` | Size x, y, z (m) | Spec (m) | Triangles (kit's piece) | File | Materials | Parts under the root |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Anime | table | `cafe_table.glb` | 0.80, 0.75, 0.80 | 0.80, 0.75, 0.79 | 3,000 (304) | 0.39 MB | `sheet_albedo` (colour, relief) | `cafe_table` > `body` |
| Anime | umbrella | `umbrella_cafe.glb` | 2.30, 2.55, 2.29 | 2.30, 2.52, 2.30 | 5,997 (472) | 1.04 MB | `sheet_albedo` (colour, relief) | `umbrella_cafe` > `body` |
| Anime | planter | `planter_square.glb` | 1.30, 1.03, 1.30 | 1.20, 1.40, 1.20 | 9,022 (956) | 0.82 MB | `sheet_albedo` (colour only) | `planter_square` > `body` |
| Low-poly | table | `cafe_table.glb` | 0.80, 0.75, 0.80 | 0.8, 0.75, 0.8 | 2,999 (132) | 0.44 MB | `sheet_albedo` (colour, relief) | `cafe_table` > `body` |
| Low-poly | umbrella | `umbrella_yellow.glb` | 2.31, 2.60, 2.31 | 2.3, 2.5, 2.3 | 6,000 (196) | 1.09 MB | `sheet_albedo` (colour, relief) | `umbrella_yellow` > `body` |
| Low-poly | planter | `planter_square.glb` | 1.30, 1.06, 1.30 | 1.2, 1.4, 1.2 | 9,018 (436) | 1.38 MB | `sheet_albedo` (colour, relief) | `planter_square` > `body` |
| Neon | table | `cafe_table.glb` | 0.80, 0.75, 0.81 | 0.8, 0.81, 0.79 | 3,115 (360): body 2,999, lights 116 | 0.39 MB | `sheet_albedo`; `lamp_glow` (emits) | `cafe_table` > `body`, `lights` |
| Neon | umbrella | `umbrella_cafe.glb` | 2.31, 2.52, 2.31 | 2.33, 2.52, 2.33 | 6,072 (600): body 6,000, lights 72 | 0.65 MB | `lamp_glow` (colour, relief, emission texture); `light` (emits) | `umbrella_cafe` > `body`, `lights` |
| Neon | planter | `planter_square.glb` | 1.31, 0.97, 1.31 | 1.25, 1.42, 1.25 | 9,036 (1,104): body 9,024, light 12 | 1.49 MB | `sheet_albedo`; `lamp_glow` (emits) | `planter_square` > `body`, `light` |

Textures are WebP inside the files, 1024 px. The kit's pieces are 9 to 159 kB; these are 0.4 to 1.5 MB.

## Look first

In `previews/`, all looked at:

- `<style>-cafe-table.png`, `-umbrella.png`, `-planter.png`: the design cut-out and the generated model, then the kit's piece and the built piece from the same four places, in colour and shaded.
- `<style>-pair.png`: the built table and umbrella on one point, the table widened as the game widens it (from above, from a seat, from low down, the foot). `<style>-pair.txt` holds what was measured.
- `anime_cel-pair-base-as-drawn.png`: the umbrella's base as drawn against the base as built (decision 2).
- `raw/`: the generated models as they came.

Two cautions about these pictures. They are Blender's plain viewport, not the game: no toon step, no ink, no lamps, and the relief maps do not show (the shaded views show the mesh's own form). And the anime and neon kit planters come out white: their box is vertex-coloured and their leaves a cut-out texture, and the viewport shows one or the other.

## What each piece is

**Table.** Round top, one column, a foot of four arms, in all three styles. The top is scaled evenly to the kit's 0.80 m and keeps its drawn thickness (5 to 7 cm with its collar); the column alone is lengthened (1.3 to 1.5 times) to put the top's upper face at 0.75 m. The unchanged route stretched the whole anime model 1.31 times upward. The feet are turned to the diagonals, between the two chairs. Neon has a lit band round the rim of its top.

**Umbrella.** Eight gores, ribs and stretchers underneath, a finial. The canopy is scaled evenly to 2.30 m and keeps its drawn pitch; the pole alone is lengthened (about twice). The unchanged route stretched the anime one 1.5 times upward, which made the canopy a steep cone and left its edge at 1.54 m. The canopy's edge is now 1.90 m up in anime and low-poly and 2.01 m in neon (the kits': 1.78 m). The pole's axis is on the origin, within 2.4 mm. Neon's rib strips glow and a lit band runs round its base.

**Planter.** A plain box 1.30 m square and 0.45 m high with a rim 7.5 to 12 cm wide (read off each model), soil 3 to 4.5 cm below the rim, a closed bottom, and the plants as leafy facets above it. Total height 0.97 to 1.06 m. Neon has a lit strip round the foot in a part named `light`.

## Contract rules, and how each was checked

"Check" means `work/check.py` with `work/terrace_rules.py`, from the GLB alone. "Pair" means `work/pair.py`, in Blender. "Eye" means the agent looked at the preview.

| Rule (from `notes/contracts/terrace.md`) | Met | How checked |
| --- | --- | --- |
| One root, named as the kit's, no transform, geometry in the kit's named parts | yes, 9 of 9 | Check |
| Stands on y = 0 | yes | Check (lowest point within 2 mm) |
| Material names: none the game acts on unless it emits, no wet-ground prefix, no `.001` | yes | Check |
| Spec size, each axis within 10% and 2 cm | 6 of 9; the 3 planters are 0.97 to 1.06 m high against 1.40 (1.42) m, by decision | Check |
| Spec's named nodes, including neon's `lights`, `lights`, `light` | yes | Check |
| Table: the top is the widest thing between 0.15 and 2.2 m | yes | Check |
| Table: the game's fill | widened 1.250 by 1.252 (anime), 1.252 by 1.250 (low-poly), 1.245 by 1.242 (neon), computed as `_fill_footprint` does | Check. The same code gives the scales the note records as measured in the game for the five kit planters, to four figures (`logs/rules-on-the-kits-own-pieces.txt`) |
| Table: top's upper face at the kit's 0.75 m | yes (neon: the kit's body, not its candle at 0.81 m) | Check |
| Table: collision audit, 16 blocked cells within 10 cm of something drawn, the 20 round them clear | yes: farthest blocked centre 3.3 to 3.9 cm from the top, nearest walkable 12.9 to 13.2 cm | Check, with the audit's own band, cell centres and clearance |
| Table: column on the middle of the top | 0.4 to 0.7 mm off once widened | Check |
| Table: knee room on the two x sides | nothing between 0.12 and 0.65 m up beyond 12 cm from the axis within 20 cm of the x axis | Check. The note's figures are "about"; 2 cm allowed on the lower one. No figure was sat at it |
| Table: nothing on the middle of the top | yes; neon's candle is not carried | Eye |
| Umbrella: pole on the origin's axis | 1.8 to 2.4 mm off | Check |
| Umbrella: pole hidden in the table's column below the top | yes: the pole reaches 3.4 to 3.7 cm from the point at most, the columns' narrowest 4.4 to 5.2 cm; 0.8 cm to spare at the tightest (neon) | Check, against the same style's built table, every 2 cm of height; Pair; Eye |
| Umbrella: base inside the 0.40 m disc, at most 0.10 m high | reach 0.26 to 0.38 m; 1 to 3 cm high | Check |
| Umbrella: canopy's edge no lower than the kit's 1.78 m | 1.90, 1.90, 2.01 m | Check |
| Umbrella: an underside that can be looked at | ribs, stretchers and hub are there; neon's strips are on it | Eye |
| Umbrella: built at its real size, not filled | 2.30 to 2.31 m across, 2.52 to 2.60 m high | Check |
| Planter: square to its corners, built 1.30 m | widened 1.004 by 1.004; all 36 blocked cells covered, the 28 round them 22 cm clear | Check |
| Planter: plants inside the box's outline at every height | 0.0 cm past it on all four sides | Check |
| Planter, neon: a `light` part with `lamp_glow`, its middle low and on the planter's middle | lamp hangs at 0, 0.08, 0 m | Check |
| Anime: no relief map on planted masses, smooth leaf normals | planter: no relief map, no sharp edge between leaf faces | file contents |

### Rules that could not be checked from a file

- The pinned glTF validator: not installed in the checkout (`npm ci` would write there). Not run.
- The kits' byte-for-byte rebuild test: any generated piece fails it by construction.
- How the anime ink and toon step draw the pieces, whether the pole inside the column or the plate under the feet flickers, what LOD generation does to these meshes, the frame cost of 4 + 4 + 11 copies. All need the game.
- Sitters: no figure was set at a table. Knee room is a geometric rule only.
- The voxel suite's own rules (indexed primitives, no part named as the root, `generate_lods=false`): not written, there is no voxel piece.
- "A flat, closed bottom": the check is that the piece stands on the ground; the planters have a bottom face; closedness in general was not tested.

## What is wrong or weak

- **The planters' plants are the weakest part.** They are jagged leaf facets, not the designs' rounded clusters of leaves. The anime planter reads olive, and has a few flowers where its design draws about ten. Its middle, which the generator left bare, is planted with two smaller copies of its own plants, so the same leaves repeat. The neon planter has one such copy.
- **Table tops carry no plank lines in colour.** The designs draw dark joints between planks; the generator painted streaks instead, and the joints survive only as relief. The anime top is paler than its design (the style's 12% lift) and plainer. The low-poly top has faint pale scuffs near one edge.
- **Low-poly planter:** the generator painted the middle block of each wall darker; it shows as a rectangle on every side.
- **Umbrella poles are thinner than drawn below 0.72 m** (about 6 cm against 8 to 14 cm with the sleeve). Inside a table's column this cannot be seen; an umbrella standing without a table would show it.
- **Umbrella bases are plates, not the drawn blocks** (decision 2). The low-poly plate is 1.5 cm: paving drawn 2 cm above a piece's foot would bury it.
- **Neon umbrella:** canopy and ribs are 1.2 cm thicker than generated (it had to be cut from a swollen, rebuilt surface). The generator painted about sixteen strips where the design has eight. Its design cut-out still holds one grey swatch under the base, which the crop cleaner missed; it is in the image the colours are matched to.
- **Above the table the poles are 7.1 to 8.9 cm across**, the kits' 6 to 7. That is the design's.
- **"Colour off the design by 0.0"** for the low-poly table means nothing: matched to two colours, the measure is met by construction. Colour figures elsewhere: 3.7 to 6.5, with 88% to 100% of the design's colours found (the anime planter lowest).
- **The planter with its own box kept** (`--planter-parts 9000,600`, set for solarpunk's rounded box) was run once, on the anime model. It holds the rules; its walls shade unevenly.

## Decisions the agent made

All are one setting in `work/assets.json`.

1. **Umbrella height.** The kit's height, unless that leaves the canopy's edge under 1.9 m, the top of the game's walking band; then the pole is lengthened until it is. Result: 2.55 m (anime), 2.60 m (low-poly), 2.52 m (neon), all inside the spec. The pack's brief asks for an edge at 2.2 m; with the drawn canopies that makes 2.85, 2.90 and 2.70 m, beyond the spec in two styles. `--stem-edge 2.2` does it.
2. **The umbrella's base is a low plate under the table's feet**: 3 cm in anime, 2.5 cm in neon, 1.5 cm in low-poly (where it is also turned a corner along x, to lie between the table's bars). As drawn, pressed only to the contract's 10 cm, a table's feet pass through it: in anime at 793 of 2,988 points tried, up to 8.7 cm deep, with the four pads sticking out of its side. As built: at none, in all three styles. The kit's own pair overlaps in the same way. `previews/anime_cel-pair-base-as-drawn.png` shows both; `--stem-foot 0.10` puts the drawn base back.
3. **The pole is thinned below the table's top** so the column hides it, and left as drawn above.
4. **Table at 3,000 triangles.** The shape rule passes 1,500; at 1,500 the round top's rim shows its sides to a seated eye.
5. **Table matched to two colours** (timber, iron) in anime and low-poly. With three to five, the generator's grain came out as brown patches on the top.
6. **Planter box 0.45 m high**, the pack's and the catalogue's figure. The generated boxes are 0.31 to 0.37 m at this width; `--planter 1.3,1.3,keep` keeps those. The plants keep their drawn height above the rim, so the pieces are 18 to 29 cm under their specs' lower bounds (1.24 m; neon 1.26 m). `check.py` reports it as a departure, not a miss (`departs` in the entry).
7. **Planter built 1.30 m square**, not the kit's 1.20 or 1.25 m, so the game hardly stretches it.
8. **Planter box rebuilt as a plain box**, painted from the generated one. Cut down with the plants, a box's walls come out ragged.
9. **Leaves take the greens of the sheet's swatches** under the planter, their mean halfway between the lit and the shaded one.
10. **Neon lights are the design's, not the kit's.** A band round the table's rim (the generator painted none), the painted rib strips and a band round the umbrella's base, a strip round the planter's foot. The kit's candle, sixteen bulbs and coping uplight are not carried; the umbrella's pole would pass through the candle.
11. **Anime:** the planter has no relief map and smooth leaves, as the note infers it needs. The table and umbrella keep relief maps, as the anime seats already in the game do. `--no-normal` drops them.

## Tool changes

`work/` against `base/`. Existing pieces come out unchanged: the anime bench, the neon bench, the neon reading chair and the anime great tree are byte for byte the main folder's (`logs/bench-unchanged.txt`). `check_options.py`: 89 options documented and read (71 before).

**`fit_generated.py`** (543 lines added, 2 changed), every new path behind a new option:

| Option | Why |
| --- | --- |
| `--stem` | A top on a stem on a foot is sized part by part: scaled evenly to the box's width, the stem alone stretched to the box's height, the stem's axis on the origin, the top moved onto that axis. Filling the kit's box stretched a canopy's pitch and a table top's thickness. A knuckle or handle of a few slices on the pole is bridged |
| `--stem-edge M` | The canopy's edge at least M metres up |
| `--stem-foot M[,ACROSS]` | The foot pressed and drawn in, so a table's feet pass over an umbrella's base |
| `--stem-across M[,UPTO]` | The stem thinned, optionally only below a height |
| `--top-sharp DEG` | A canopy's gores meet at 20 degrees; under the 40-degree rule they were smoothed over and shaded as blotches |
| `--feet-off-x`, `--feet-on-x` | The feet are found (strongest harmonic of the foot's reach, 2 to 6) and turned between the chairs, or a square base's corner onto x |
| `--kit-body-box` | The kit's box without its `light` and `lights` parts: neon's candle made the box 6 cm taller, its bulbs 3 cm wider |
| `--planter W,D,RIM`, `--planter-inset` | A planting box sized part by part: the box to its outline and rim height, the plants evenly, drawn inside the outline |
| `--planter-parts PLANTS[,BOX]`, `--planter-cell`, `--planter-swell`, `--planter-least` | The planter cut part by part: plain box (or its own), plants rebuilt from fine cells. Cut as one mesh, thin leaves came out as shards with holes |
| `--planter-fill SHARE,TURN[,…]` | The generated model's plants copied inward before the cut, for a bare middle |
| `--band-glow Z0,Z1[,OUT]`, `--band-glow-as`, `--band-glow-material` | A lit band following the piece's outline at a height: a rim strip the generator does not paint |

Also: a piece on a stem that a swell pushed under the ground is put back on it; `--leaf-smooth` now also serves `--planter-parts`.

Where the additions sit, for the merge: two helpers after `seat_top_of`; the kit's box; the turn, after the quarter turn is chosen; two sizing branches before the kit-box branch; `cut_planter` before `cut` and one line in the dispatch; three blocks after the cut; `--top-sharp` beside `--leaf-smooth`; the planter's bottom face before the names; `--band-glow` before `--glow-light`.

**`build.py`** (30 lines): `leaf_colour: "cell"` takes the green swatches under the object in its own cell of a grid sheet (helper `swatches_under`).

**`check.py`** (35 lines): an entry's `rules` runs `terrace_rules.py`; an entry's `departs.<axis>` turns a size miss on that axis into a reported departure.

**`look.py`** (6 lines): a model with no colour texture is drawn in its vertex colours or material colours. Kit pieces came out white.

**New:** `terrace_rules.py` (the rules above, listed at its top), `pair.py` (the pair as the game stands them, with the reach of each at every height and where a foot passes through the base), `terrace_previews.sh` (the comparison sheets).

**`assets.json`**: the three entries, a note on `planter-pot`, one sentence added to `_about`. A style's flags come before the piece's and the first occurrence wins, which is how a style overrides `--stem-foot` or `--stem-across`.

## Traps met

1. The stalled-reduction fallback destroys a thin shell. Neon's umbrella stalled at every count, was rebuilt from 2.3 cm cells, and came back as ribs with rags of cloth. `--inflate 0.006 --remesh 0.009` keeps the canopy. The next umbrella may need the same.
2. The kits' own pieces do not meet two of these rules (`logs/rules-on-the-kits-own-pieces.txt`): three kit planters' plants or copings reach 3 to 8 cm past their walls, and three kit umbrellas' collars are wider than the kit table's column from 0.16 to 0.24 m up.
3. The walking grid's cell centres are 12 cm, not 12.5, from a grid line (an integer division in `drawn_rect`), which is why a planter is drawn 1.305 m and 2.5 mm off its point.
4. A square base's corners are a weak signal (0.076 against a cross's 0.8); the threshold for "has feet" is 0.05.
5. A joint line across a rim thins one step of the rim's measured width; the wall's thickness is taken where three steps running are empty.

## What remains

- **Solarpunk and voxel.** Run `python3 work/build.py fit <style> cafe-table umbrella planter`, then `work/terrace_previews.sh <style>` and `work/check.py`, and look. Solarpunk's umbrella needs its `--stem-foot` set from the pair render; its planter is set to keep its own box. Voxel needs a sheet first.
- **The game.** Nothing here was placed or captured. The fill scales, the lamp and the audit are computed, not measured.
- **The validator**, once it is installed somewhere the checkout is not written.
- **Merging.** Changed: `fit_generated.py`, `build.py`, `check.py`, `look.py`, `assets.json`. Added: `terrace_rules.py`, `pair.py`, `terrace_previews.sh`.

This took about 85 minutes, not the 45 aimed for.

## Afterwards: what the game showed

Added by the coordinating session (Claude, an AI), which placed the pieces in the working copy of the game, ran its collision audit and captured them. The agent had seen none of this.

- **The audit.** With the nine pieces placed the game's collision audit counted zero in anime, low-poly and neon. The agent's own reading of the audit on the files had said so.
- **The pair reads well.** In all three styles the umbrella's pole runs down through the table's column and nothing shows of the base (`compare/terrace-<style>.jpg`).
- **Captures.** The first captures of a terrace were taken from inside a wall: the tool set its camera by the piece's box, and a table stands against a shopfront. The camera is now put on the side from which most of the piece shows.
- **The anime planter's plants came out dark**, at well under half their painted brightness: the anime pack's toon step draws a face turned from the sun in shadow, and the plants' normals pointed every way. They take the trees' cure, normals leaning up (`--leaf-round 0.85 --leaf-lift 1.0`).
- **Zero tangents.** The kits' pinned validator found one or two zero tangents in the tables of all three styles and in two planters. They are mended in the written files (`tools/mend_tangents.py`), and every piece now passes the validator.
- **Solarpunk**, whose models arrived after the agent had finished, was built from its entries as they stood. The table and the umbrella pass the audit and are in the game; the table's top is streaked dark. The planter failed twice: with its own box kept its walls came out torn, white and black, and with the plain box its cream upper tier above the brass plinth was taken for plants and left floating.
- **Voxel**, whose models also came later, was run once through the untested entries: the table lost its foot, the umbrella's canopy came out ragged with its pole broken, and the planter had a handful of plant cubes. None was placed.

The second pass below is the same agent's, on the merged tools; it cured all of this.

## The terrace, second pass: solarpunk and voxel

Written by Claude (an AI build agent, the same one that built the terrace), 2026-10-02, 16:15 to 17:55, and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). It worked in `agents/terrace2/` on a copy of the merged tools. The game, its audit and its tests were not run by the agent.

All four things asked are done. Fifteen terrace pieces (five styles) plus the anime bench are built; `check_options.py` and `check.py` pass.

### What is built, where to look

Sheets: `previews/<style>-{cafe-table,umbrella,planter,pair}.png` (20, all rendered from the final files and looked at). Files: `out/<style>/`. Numbers: `logs/check.txt`, `logs/hashes-final.txt`.

1. **Solarpunk planter**: a plain cream box on its own rounded outline (24 corners), the rim found through the plinth's step, the walls clean; 9,188 triangles (box 166). The plinth is one tier with the brass band painted on. `--planter-tiers 0.003` gives two plain tiers instead (tried in `scratch/tiers2/`, passes the planter rule).
2. **Solarpunk table**: the top is plain blonde, no streaks (two colours, flatten 0.9). **Solarpunk umbrella**: its base is now a 3 cm plate 0.50 m across; the table's legs pass through it at 0 of 2,288 points (was 396 of 2,750, up to 6.5 cm deep).
3. **Voxel**, on the 0.1 m grid with the kit's names:
   - `cafe_table` > `table`: 1.0 by 0.8 by 1.0 m, 106 triangles (limit 150). A round top of 80 cubes, a 2 by 2 column in one dark colour, a cross foot 0.6 m across.
   - `umbrella` > `canopy`: 2.4 by 2.8 by 2.4 m, 648 triangles (limit 650). A stepped dome in eight clean sectors, its edge at 2.1 m, a 2 by 2 pole, a 4 by 4 base, a finial.
   - `planter` > `box`: 1.3 by 0.9 by 1.3 m, 238 triangles (limit 300). A solid block to a 0.5 m rim, all 121 columns inside the rim planted 1 to 4 cubes high.
   - All three meet the voxel kit's own spec test (`scratch/voxel_kit_rules.py` runs its logic) and the Khronos validator with 0 errors and 0 warnings.
4. **Normals**: `--own-normals --weighted-normals` are on for tables in every style: tops shade flat with crisp plank joints in anime, low-poly and neon, no change on solarpunk. Umbrellas showed no difference in shaded renders and are left alone (`scratch/nc/<style>.png`). `--drop-hidden` is not used.

### What is weak

- **Voxel umbrella**: two triangles under the limit; 2.8 m against the kit's 2.7 (inside the spec's 10%); the base is dark like the pole, where the design draws pale stone.
- **Voxel table**: the foot's arms are two cubes wide and reach 0.3 m; the design's are one wide and reach about 0.4 m.
- **Voxel planter**: 0.9 m high, 2 cm above the spec's lower bound; three groups of white blossom against about nine on the sheet.
- **Solarpunk table**: no slats, brass rim or brass leg tips; four legs as generated, where the sheet draws three.
- **Solarpunk umbrella base**: the collar and band are squashed into marks on the plate, visible only from low down.
- **Solarpunk planter**: the plinth line is slightly uneven. The rounded corners leave the corner cells' centres 2 cm outside the box, inside the 10 cm the agent's rule allows; the game's audit will tell.

### Changes against the tools it started from

Four files; `build.py`, `check.py`, `look.py`, `pair.py` and `terrace_previews.sh` are unchanged.

`fit_generated.py` (267 lines added, 34 changed; the old paths build the same bytes):

- `--planter-tiers STEP`: new `planter_through_steps()` and `convex_outline()`; the old rim finder is now the `else` of the `--planter` sizing branch, only indented; a new `elif planter_tiers:` branch in `cut_planter` builds the box tier by tier; the bottom face follows `planter_foot` when set.
- `--planter-wall M`: the wall's thickness given, in `cut_planter`.
- `--planter-tones F`: a new block before `--leaf-colour`; the stone keeps the share F of its variation about its middle colour.
- `--stem-grid G`: in the `--stem` branch; foot and top are whole cubes high, what `--stem-edge` adds is whole cubes, and the top fills the box in x and z separately.

`voxelise.py` (240 lines, purely added):

- `--symmetric`: cover averaged over the mirror images.
- `--column N[,Z0,Z1]`: a ruled column about the axis, painted one colour.
- `--round [Z]`: each level a disc as wide as the fitted piece there.
- `--sectors N`: large rounds painted in N sectors in their two main colours.
- `--heap Z[,RIM[,LEAST]]`: columns filled as high as the fitted plants stand, coloured from the leaves and blossoms in them.
- `--tuck Z[,F]`: corners below Z drawn in by F.
- `borders_again()`: pads repainted texture blocks again.

`terrace_rules.py` (33 lines): for voxel, `common()` now misses a part named as the root or a primitive without indices, and a new `voxel_kit()` holds the piece to the kit's triangle limit.

`assets.json` (80 lines added, 11 changed, the three terrace entries only):

- Table: `--own-normals --weighted-normals` added to the asset's flags; `--feet-off-x` moved from the asset's flags into each filled style's flags, because the voxel foot must stay on the grid. Any filled style added later needs it in its own flags.
- Solarpunk: table `flatten 0.9`, `--materials 2`; umbrella `--stem-foot 0.03,0.50`; planter `--planter-tiers 0.012`.
- Voxel: full entries for all three, with notes. The planter also uses the existing `--bed-colour auto`.

### Proof

- `check_options.py`: 155 options documented and read, exit 0. `check.py`: exit 0, no misses.
- Three clean builds of all 16 files gave identical bytes.
- Against a build by the untouched starting tools (`scratch/basecopy/out/`): the six umbrellas and planters of anime, low-poly and neon and the anime bench are identical.
- Changed on purpose: the three tables of anime, low-poly and neon (the two normals options). Without those two options the agent's tools build them identical to the starting tools' (`scratch/proof/out/`).
- The voxel bench, lamp and large street tree come out identical from the starting cube step and the agent's.
- The starting tools are untouched; nothing was written outside the agent's folder.

### For the coordinating session to know

- The main folder's copies of the three tables, the low-poly and neon planters and the anime bench were rewritten at 17:24:10, not by the agent, and no longer equal what the starting tools build. At 17:11 the agent's six umbrellas and planters equalled the main folder's byte for byte.
- The Khronos validator on non-voxel pieces reports zero-length tangents from the shared export, the same in the starting tools' builds: anime bench 30, low-poly planter 2, neon planter 1, anime table 1 (the starting tools' has 2). The solarpunk planter carries no tangents (its soil and bottom are many-sided faces), so the validator warns that they will be generated at import.

## Afterwards: the second pass in the game

Added by the coordinating session (Claude, an AI).

- **The merge.** The agent's changes were carried into the tools as they stood by then. Its additions to the cube rebuild fell inside a block the coordinating session had re-indented meanwhile, so they were carried over hunk by hunk. The merge was proved by building all fifteen terrace pieces again with the merged tools: each is byte for byte the agent's own (once the agent's files have their zero tangents mended, as the merged build does), and eight pieces of other families came out unchanged.
- **The audit.** With the fifteen pieces placed the game's collision audit counts zero in all five styles. The solarpunk planter's rounded corners, which the agent could not judge from the file, are inside it.
- **The validator.** The solarpunk planter's soil and bottom were each one many-sided face, which cost the file its tangents and drew a warning from the kits' validator. The fit now cuts faces of five corners or more into triangles before it writes a file; the planter passes, and no other piece changed.
- **How they look** (`compare/terrace-solarpunk.jpg`, `compare/terrace-voxel.jpg`). The solarpunk planter is a clean cream box with its flowers; the solarpunk table's top is plain blonde. The voxel table, umbrella and planter read as their designs: a round orange top on a dark column, a canopy in eight orange and white sectors, a grey stone box planted full.
- **Sizes in the agent's tables.** They are of its first pass. The café tables kept here, rebuilt with their own normals, are 0.40 MB (low-poly), 0.35 MB (neon) and 0.38 MB (anime); the solarpunk planter has 9,187 triangles, not 9,188 (the README's tables are written from the files).
