# Street fixtures from design sheets: lamp post, bollard, railing

> In this record the pieces are in `out/<style>/`, the agent's own preview sheets are in `previews/fixtures/` (as JPEG) and its tools are merged into `tools/`. Where the report names `work/`, `base/`, `logs/`, `scratch/`, `out/` or `previews/`, it means the agent's own folder in the working folder (`agents/fixtures/`), of which only the pieces and the previews are kept here. The report is as the agent gave it; what happened afterwards is at the end.

Report of the street-fixtures agent, 2026-10-02. Written by Claude (an AI build agent), and saved here by the coordinating session from the agent's final message (the agent could not write this file itself). Everything it describes is in `agents/fixtures/`; nothing was written in the checkout, in the main working folder, in `raw/` or in `crops/`. The game, Godot, the captures, the bench and the image-to-3D model were not run. The pieces have been looked at in Blender renders only.

## Summary the agent gave first

All 15 pieces are built (lamp post, bollard, railing in five styles; 20 files with the four-plus-one railing posts) and pass `check.py` and the kits' Khronos validator. None has been seen in the game.

- **Good**: the five lamp posts; bollards in anime, low-poly, neon, voxel; railings in anime and low-poly.
- **Usable with a gap**: neon railing (its light strips are missing); solarpunk bollard (taken out of a model that held the bollard and the catenary pole; nothing on it glows); voxel railing (0.4 m post, with dark bands the design lacks).
- **Weak**: solarpunk railing. It is a planter with plants; at the kit's 1,000 triangles it breaks up (95% within 59 mm). It holds at about 4,000.
- **Sizes**: 14 of the 20 files are off the kit's spec on one or two axes, each declared in `assets.json` with its reason: lamps are narrower than the kit's ornament, railings as deep as drawn. Fences would stand 11 to 21 cm off the floor's edge (kits: 6 to 11).
- **Findings that reach the seats and trees already built**:
  1. The generator's shading normals stay on a cut-down piece and point wrong: 54 to 92% of the seats' larger-face area has a corner leaning over 20 degrees (kits: 0 to 19%; these fixtures now 0 to 20%).
  2. A generated model has a second skin inside it: 295 of the anime bench's 1,499 triangles are loose parts inside it.
  3. The Khronos validator gives the anime bench 18 errors (zero tangents).
  4. The bakes look 2 to 8 cm off the surface, further than a rail is from its neighbour.
  5. The cutter joined the bollard and the catenary pole on the solarpunk sheet.
- **Tools**: 22 new options in `fit_generated.py` (93 documented and read), `voxelise.py --light`, `check.py` with a new `fixture_rules.py`, and four small new scripts. All new behaviour is behind options.
- **Existing pieces unchanged**: the untouched `base/` tools and the final tools give the same bytes for the anime bench (sha256 `353f9446…`) and the voxel bench. The main folder's `seat_bench_v2.glb` was rebuilt by other tools at 14:30 and no longer matches either; before that `build.py fit anime_cel bench` matched it five times.
- **The check was itself checked**: the kits' own 20 pieces all pass; of built pieces spoiled in 19 ways, every fault that is one in the style is named.
- **Time**: about three hours, not the 45 minutes asked; the normals and the inner skin were found late and everything was built again after each.

## What is ready

Fifteen pieces in five styles, twenty files in `out/<style>/`: the lamp post, the bollard and the railing panel in anime, low-poly, neon, solarpunk and voxel, and with each railing its post as a second file. The catenary pole was left out, as asked.

| Piece | Anime | Low-poly | Neon | Solarpunk | Voxel |
| --- | --- | --- | --- | --- | --- |
| Lamp post | good | good; its banner drawn up to hang clear of walkers | good; the strip on its shaft is faint | good; twice its kit's triangles | good; its glass is small |
| Bollard | good | good | good; its band recoloured by rule | usable: taken out of a model that held two objects; nothing on it glows | a plain block, as drawn |
| Railing | good | good; stone piers 31 cm square | usable: its light strips are missing | weak: a planter with plants, broken up at 1,000 triangles | usable: a 0.4 m post with dark bands the design lacks |

All twenty pass `check.py` (exit 0) and the Khronos validator the kits' tests use (0 errors, 0 warnings). Fourteen keep the size their design drew on an axis where the kit's spec says otherwise; each such axis is declared in `assets.json` with its reason, and `check.py` prints it instead of failing it.

## Look first

`previews/<style>-<piece>.png`, fifteen sheets. Each shows the design cut-out, the kit's piece and the new piece from the same places at one scale, shaded and in colour, the new piece once more unlit (its texture's own colours), and the close views a whole-piece view hides: a lamp's lantern and foot, a railing's post and its second file from along and across the run. The shaded views use Blender's `paint` studio light; its default light darkens a pale colour by about a third (a beige pier read as brown), which is why the unlit tile is there.

## The pieces in numbers

Written from `out/results.json` and each piece's own report by `scratch/report_table.py` (`logs/tables.txt`).

| Style | Piece | File | Triangles | Kit's limit | Kit's piece | Size x, y, z (m) | Kit's spec (m) | On disk | Parts | Material |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Anime | lamp post | `lamp_post.glb` | 1,500 | 1,500 | 456 | 0.47 by 4.20 by 0.49 | 0.74 by 4.22 by 0.5 | 145 kB | `body`, `light` | `lamp_glow` |
| Anime | bollard | `bollard.glb` | 1,500 | 1,500 | 278 | 0.24 by 0.90 by 0.24 | 0.24 by 0.9 by 0.23 | 71 kB | `body` | `sheet_albedo` |
| Anime | railing | `railing.glb` | 960 | 1,000 | 336 | 2.00 by 1.16 by 0.20 | 2.0 by 1.12 by 0.14 | 147 kB | `body` | `sheet_albedo` |
| Anime | railing post | `railing_post.glb` | 628 | 1,000 | 212 | 0.19 by 1.16 by 0.20 | 0.14 by 1.12 by 0.14 | 123 kB | `body` | `sheet_albedo` |
| Low-poly | lamp post | `lamp_post.glb` | 1,999 | 1,500 (over) | 418 | 0.93 by 4.20 by 0.41 | 0.75 by 4.2 by 0.5 | 309 kB | `body`, `light` | `lamp_glow` |
| Low-poly | bollard | `bollard.glb` | 1,500 | 1,500 | 152 | 0.24 by 0.90 by 0.24 | 0.24 by 0.9 by 0.24 | 99 kB | `body` | `sheet_albedo` |
| Low-poly | railing | `railing.glb` | 860 | 900 | 328 | 2.00 by 1.23 by 0.31 | 2.0 by 1.1 by 0.14 | 234 kB | `body` | `sheet_albedo` |
| Low-poly | railing post | `railing_post.glb` | 178 | 300 | 120 | 0.30 by 1.23 by 0.31 | 0.14 by 1.12 by 0.14 | 177 kB | `body` | `sheet_albedo` |
| Neon | lamp post | `lamp_post.glb` | 1,499 | 1,500 | 392 | 0.40 by 4.20 by 0.40 | 0.74 by 4.22 by 0.5 | 267 kB | `body`, `light` | `lamp_glow` |
| Neon | bollard | `bollard.glb` | 1,500 | 1,500 | 204 | 0.27 by 0.90 by 0.27 | 0.24 by 0.9 by 0.23 | 115 kB | `body`, `light` | `lamp_glow` |
| Neon | railing | `railing.glb` | 969 | 1,000 | 336 | 2.00 by 1.17 by 0.21 | 2.0 by 1.12 by 0.14 | 169 kB | `body` | `sheet_albedo` |
| Neon | railing post | `railing_post.glb` | 394 | 1,000 | 212 | 0.21 by 1.17 by 0.21 | 0.14 by 1.12 by 0.14 | 125 kB | `body` | `sheet_albedo` |
| Solarpunk | lamp post | `lamp_post.glb` | 2,999 | 1,500 (over) | 664 | 0.80 by 4.20 by 0.79 | 0.74 by 4.21 by 0.5 | 381 kB | `body`, `light` | `lamp_glow` |
| Solarpunk | bollard | `bollard.glb` | 1,500 | 1,500 | 380 | 0.24 by 0.90 by 0.24 | 0.24 by 0.9 by 0.24 | 117 kB | `body` | `sheet_albedo` |
| Solarpunk | railing | `railing.glb` | 952 | 1,000 | 272 | 2.00 by 1.23 by 0.37 | 2.0 by 1.12 by 0.16 | 465 kB | `body` | `sheet_albedo` |
| Solarpunk | railing post | `railing_post.glb` | 60 | 1,000 | 176 | 0.39 by 1.23 by 0.36 | 0.16 by 1.12 by 0.16 | 365 kB | `body` | `sheet_albedo` |
| Voxel | lamp post | `lamp.glb` | 188 | 250 | 196 | 0.60 by 4.50 by 0.60 | 0.6 by 4.5 by 0.6 | 27 kB | `post`, `light` | `cubes`, `lamp_glow` |
| Voxel | bollard | `bollard.glb` | 10 | 50 | 28 | 0.20 by 0.80 by 0.20 | 0.2 by 0.8 by 0.2 | 3 kB | `post` | `cubes` |
| Voxel | railing | `railing.glb` | 128 | 400 | 112 | 2.00 by 1.10 by 0.40 | 2.0 by 1.1 by 0.2 | 15 kB | `rail` | `cubes` |
| Voxel | railing post | `railing_post.glb` | 10 | 60 | 28 | 0.40 by 1.10 by 0.40 | 0.2 by 1.1 by 0.2 | 4 kB | `post` | `cubes` |

| Style | Piece | Off the rebuilt surface, 95% within | Worst | Colour off the design | Design colours found | Hidden faces dropped |
| --- | --- | --- | --- | --- | --- | --- |
| Anime | lamp post | 2.8 mm | 5.4 mm | 3.1 | 100% | 0 of 9,000 |
| Anime | bollard | 0.45 mm | 0.9 mm | 1.7 | 100% | 0 of 9,000 |
| Anime | railing | 1.76 mm | 4.3 mm | 1.8 | 100% | 241 of 2,790 |
| Low-poly | lamp post | 1.87 mm | 4.0 mm | 0.4 | 100% | 3,478 of 12,000 |
| Low-poly | bollard | 0.28 mm | 0.7 mm | 1.0 | 100% | 0 of 9,000 |
| Low-poly | railing | 3.69 mm | 6.6 mm | 1.1 | 100% | 138 of 2,490 |
| Neon | lamp post | 2.04 mm | 3.3 mm | 2.9 | 89% | 3,856 of 9,000 |
| Neon | bollard | 0.55 mm | 1.3 mm | 3.0 | 100% | 0 of 9,000 |
| Neon | railing | 1.39 mm | 3.0 mm | 6.5 | 96% | 1 of 2,790 |
| Solarpunk | lamp post | 2.24 mm | 4.4 mm | 2.1 | 100% | 3,928 of 18,000 |
| Solarpunk | bollard | 0.93 mm | 1.6 mm | 0.6 | 100% | 0 of 9,000 |
| Solarpunk | railing | 59.15 mm | 114.3 mm | 3.3 | 100% | 351 of 5,580 |
| Voxel (the fitted piece the cubes were made from) | lamp post | 1.54 mm | 2.8 mm | 0.4 | 100% | 0 of 9,000 |
| Voxel (fitted) | bollard | 0.17 mm | 0.4 mm | 2.0 | 100% | 0 of 9,000 |
| Voxel (fitted) | railing | 0.32 mm | 0.8 mm | 1.6 | 100% | 0 of 24,000 |

| Style | Piece | What the check found (every file: validator 0 errors, 0 warnings) |
| --- | --- | --- |
| Anime | lamp post | every blocked cell's centre within 2.5 cm of the piece (under 10 wanted), still so with 25 cm of ground under it; reaches 17.5 cm from its axis in the band; lamp at 3.64 m; as drawn: x 0.47 m against 0.74 |
| Anime | bollard | blocked centres within 6.7 cm; reaches 11.9 cm |
| Anime | railing | half depth 10.1 cm, the fence 11.1 cm off the floor; as drawn: z 0.20 m against 0.14 |
| Anime | railing post | its faces and the panel's 1.0 to 1.5 cm off the floor; as drawn: x 0.19, z 0.20 against 0.14 |
| Low-poly | lamp post | blocked centres within 4.6 cm; reaches 19.1 cm; lamp at 3.72 m; as drawn: x 0.93 against 0.75, z 0.41 against 0.5 |
| Low-poly | bollard | blocked centres within 6.6 cm; reaches 12.8 cm |
| Low-poly | railing | half depth 15.5 cm, the fence 16.5 cm off the floor; as drawn: z 0.31 against 0.14 |
| Low-poly | railing post | faces 1.0 to 1.4 cm off the floor; as drawn: x 0.30, z 0.31 against 0.14 |
| Neon | lamp post | blocked centres within 1.8 cm; reaches 20.6 cm; lamp at 3.75 m; as drawn: x 0.40 against 0.74, z 0.40 against 0.5 |
| Neon | bollard | blocked centres within 7.5 cm; reaches 11.1 cm |
| Neon | railing | half depth 10.7 cm, the fence 11.7 cm off the floor; as drawn: z 0.21 against 0.14 |
| Neon | railing post | faces 1.0 to 1.2 cm off the floor; as drawn: x 0.21, z 0.21 against 0.14 |
| Solarpunk | lamp post | blocked centres within 0.1 cm; reaches 18.8 cm; lamp at 3.61 m; as drawn: z 0.79 against 0.5 |
| Solarpunk | bollard | blocked centres within 8.4 cm; reaches 10.4 cm |
| Solarpunk | railing | half depth 18.0 cm, the fence 19.0 cm off the floor; as drawn: z 0.37 against 0.16 |
| Solarpunk | railing post | faces 0.6 to 1.9 cm off the floor; as drawn: x 0.39, z 0.36 against 0.16 |
| Voxel | lamp post | blocked centres within 2.7 cm; reaches 28.3 cm (the audit's limit is 28.9; its disc is 20); lamp at 3.90 m |
| Voxel | bollard | blocked centres within 8.4 cm; reaches 14.1 cm |
| Voxel | railing | half depth 20.0 cm, the fence 21.0 cm off the floor; as drawn: z 0.40 against 0.2 |
| Voxel | railing post | faces 1.0 cm off the floor; as drawn: x 0.40, z 0.40 against 0.2 |

- **Kit's limit**: the lamp post and the bollard are not held to it (the shape decides, by the owner's rule); the railing and its post are, because the game draws them 226 and 6 times.
- **Off the rebuilt surface**: 95% of up to 6,000 points on the surface the piece was cut from lie within this distance of the piece.
- **Colour off the design / design colours found**: as in the main record.
- **Hidden faces dropped**: see "A generated model is a shell" below.

## Piece by piece

### Lamp post

Built one way in all five styles: scaled evenly to the sheet's 4.2 m (4.5 m in voxel, its kit's), its own axis on the origin, the lantern's glass split off as the mesh part `light`, one material named `lamp_glow` on both parts with the glass alone in its emission texture.

- **Anime.** 1,500 triangles hold the finial ball, the collars and the lantern's bars. The glass is near white where the sheet's swatch is cream (it keeps the generator's colour). The roof's texture is grainy.
- **Low-poly.** The sheet draws a banner on an arm. The arm is turned to +x, where the kit carries its banner, and the banner is drawn up towards the arm so that it hangs no lower than 2.2 m. As drawn it hung from 1.98 m, eight centimetres above the collision audit's band, and the audit lifts its band by whatever ground is drawn under the lamp. The banner is 17% shorter for it. 2,000 triangles: at 1,500 the rule of 3 mm and 9 mm was not met.
- **Neon.** The lantern, the lit panel on the foot and the strip on the shaft all glow; the lantern alone is the `light` part, so the game's lamp hangs at 3.75 m. The strip on the shaft is faint: the generator made little of it. The glass is tan where the design's is a brighter amber.
- **Solarpunk.** A caged lantern on a dark shaft with brass bands and a stone foot. 3,000 triangles: the cage's bars need them. Its brim is 80 cm across as generated (the sheet draws about 68). Its brass would have passed for glass by colour, so here the glass is found as what is pale alone.
- **Voxel.** 739 cubes, 188 triangles. Post two cells square, foot four, lantern six, as the kit's grid wants. The glass is two cells wide on each side where the sheet's pane fills most of the side: a cube face takes the colour most of it has, and the frame wins the cells it shares. The foot's corners reach 28.3 cm from the axis in the audit's band; the limit is 28.9.

Not known for any of them: how the glass glows at the game's strengths, and how the anime ink lines sit on the mesh.

### Bollard

- **Anime, low-poly.** Filled to the kit's 0.24 by 0.9 m. The anime bollard is 27% stouter for its height than the generator made it (it made it slimmer than the sheet draws it); the low-poly one 3%. No `light` part.
- **Neon.** The generator painted the lit band white. It takes the sheet's amber (`#FEBE5E`) by rule, glows, and is the `light` part the neon spec names. 0.27 m across: the sheet draws 0.29 m at the foot, and 0.27 is the most the spec allows on z.
- **Solarpunk.** The cutter took the bollard and the catenary pole for one object on this sheet, so the generated model holds both. The fit keeps the shorter object and matches its colours to the bollard's own part of the cut-out. It has less detail than the others (it was a small part of what the generator saw), its brass is duller than the design's, and its lit slots came out as brass ribs, so nothing glows; the kit's has a glowing band. It should be generated again from a cut-out of its own.
- **Voxel.** The generator stood it on a slab a metre square and made it 18 by 12 cm in plan. The slab is cut off and the post fills the kit's 0.2 m square: 32 cubes, 10 triangles, a plain dark block. The kit's has a pale band; the sheet draws none.

### Railing and its post

Each panel runs from x = -1 to +1 with its own post at -x. The post the sheet draws at the far end is cut off and the rails are closed there. The rails are carried through the post to the panel's -x end as short plain stubs, because the post's foot or cap is wider than its shaft and the next panel's rails would otherwise stop two centimetres short of it. The panel is centred across on what it draws where people walk. `railing_post.glb` is the outer half of the panel's own post and its mirror image, so it is the same on both sides along the run and carries no rail.

- **Anime.** 960 triangles (930 and 30 of stubs). Eight balusters, three rails, a post with a cap and a ball. The ball is a little faceted.
- **Low-poly.** Stone piers 31 cm square with iron rails between, so the fence will stand 16.5 cm off the floor's edge where the kit's stands 7. Sized evenly it came out 1.29 m high, over what the spec allows; its height alone was brought down 4.6% to 1.23 m.
- **Neon.** A low wall under two thin rails and a timber top rail. Its light strips are missing: the generator painted the strip on the post as a dark red slot and did not make the line along the wall's top. Nothing on it glows. The post reads grey where the design's is near black.
- **Solarpunk.** A planter: boxes of plants between a stone post and iron posts under a brass handrail. At 1,000 triangles it does not hold: the plants are shards, the stone post is cut to some 30 triangles (its file has 60), and 95% of the surface is only within 59 mm. At 4,000 it is within 7 mm. It is 37 cm deep. Kept at 952, as told to keep railings near their limits; it is not fit to use as it is.
- **Voxel.** The sheet's cubes are twice the kit's when the panel is 2 m long. The box is filled (2 by 1.1 by 0.4 m) so that the post is four cells square: 326 cubes, 128 triangles, the post file a block of 10. The post carries two dark bands the design does not have (the generator painted some of its rows dark). The fence would stand 21 cm off the floor.

Not checked for any railing, because only the game shows it: the joints where a run turns a corner, and a fence's two ends, where the game stands `railing_post` on the first panel's own post (a centimetre off it, as it does the kit's) and through the last panel's rail ends.

## The contract's rules, and how each was checked

"Check" means a rule in `fixture_rules.py`, run on the file by `check.py`. The rules were also run on the kits' own twenty pieces: all pass, and the reach figures agree with the contract note's (17.2, 13.1, 16.4, 15.0 cm for the four Blender kits' lamps). And on built pieces spoiled in memory in nineteen ways (a post at the wrong end, a panel 3 cm short, a slim foot, a lamp without its `light`, a material named `lamp_glow.001`, and so on): every fault that is one in the style is named (`logs/control-kits.txt`, `logs/faults-<style>.txt`).

| Rule | Met | How checked |
| --- | --- | --- |
| Root named after the file; parts as the spec names them; names unique; in voxel no part carries the file's name | yes | check |
| Stands on y = 0 | yes | check |
| `lamp_glow` exact and used once; no name beginning glass or neon, nor (where the ground turns wet) paving, asphalt, kerb, road, path, street | yes | check |
| `lamp_glow` brings its emission in the file | yes | check |
| Lamp and bollard: something within 10 cm of every blocked cell's centre between 0.25 and 1.9 m at any facing; nothing past 28.9 cm | yes by the file | check: computed as the audit cuts a piece, every 5 degrees round, and with the band lifted by up to 25 cm of ground. The audit itself was not run |
| Lamp: one mesh part `light`, its middle 3.0 m up or more, on the axis | yes: 3.61 to 3.90 m | check |
| Lamp: nothing wider than the footprint below 1.9 m (2.2 m to be safe) | yes | check; the low-poly banner drawn up to 2.2 m |
| Bollard: no `light` in low-poly, anime, solarpunk, voxel; a `light` in `lamp_glow` in neon; a glowing surface in solarpunk | all but the last | check |
| Railing: one mesh, no transform on a node | yes | check |
| Railing: from x = -1 to +1, its post at -x, nothing closing +x | yes | check, to 2 mm |
| Railing: alike on both sides of z = 0 where people walk | yes, to under a millimetre | check, by the game's own measure |
| Railing post: centred, as high as the panel | yes | check |
| Railing post: each face within 2 cm of the floor (the anime test) | yes in anime: 1.0 to 1.5 cm | check: a miss in anime, reported elsewhere (solarpunk 0.6 to 1.9 cm) |
| Railing "thin: half depth 5 to 10 cm" | no | 10.1 cm anime, 10.7 neon, 15.5 low-poly, 18.0 solarpunk, 20.0 voxel: the sheets draw stout posts, piers, planters and large cubes |
| Railing and post inside their kit's triangle limit | yes | check holds these two to it |
| Size within 10% and 2 cm of the spec | on the axes not declared | check |
| The Khronos validator: no error, no warning | yes, all twenty | check runs it (`validate.cjs`, the kits' pinned version, installed into `scratch/validator/`) |
| Anime: smooth normals, no relief map | yes | built with `--no-normal`; the shader was read, the game not run |
| Byte-for-byte with a fresh kit build; the voxel import sidecar | cannot be met by a replaced file | not checked |

## What the work found about the route

The first two change every piece the route has built.

**The generated model's normals stay on the cut-down piece, and they are wrong there.** Blender keeps the generator's shading normals through the reduction, stored relative to faces that no longer exist. On the seats in the main folder, 54% (anime bench), 92% (anime café chair) and 89% (low-poly bench) of the area of their larger faces has a corner whose normal leans more than 20 degrees off its face; on the kits' pieces it is 0 to 19%, on these fixtures now 0 to 20% (`logs/normals.txt`). With those normals in place the step that marks sharp edges finds few of them (160 of 565 on the anime railing), so boxes shade as if dished: what was first taken for a dent in a post's cap. `--own-normals` drops them before the edges are marked; `--weighted-normals` then weights the smooth normals by face area. The seats and trees were built without either.

**A generated model is a shell with a second skin inside it.** Cut at any height, the low-poly and neon lamp posts showed two outlines, one 1.5 cm inside the other. Of the anime bench's 1,499 triangles, 295 are loose parts inside it; the first anime railing had 229 of 967 there. They cost triangles and texture, and show at any open end (cut rails looked like hollow tubes). Rebuilding the surface first (`--remesh`) removes the skin only where the hollow is sealed; `--drop-hidden` then drops every face from which no ray leaves the piece (3,478 of 12,000 on the low-poly lamp, 3,856 of 9,000 on the neon one, none on the anime one). With its triangles all on the outside, the anime lamp holds at 1,500 where it had needed 3,000.

**The bakes look too far.** They look 1 to 2% of the piece's diagonal off its surface for the generated model: 4 to 8 cm on a lamp post, 2 to 5 cm on a railing, further than a rail is from the rail beside it. `--bake-reach` sets the distance (1.2 cm here).

**The validator fails a piece with a relief map.** The anime bench in the main folder has 18 errors: zero tangents. The kit tests fail a file on any. `--mend-tangents` replaces them in the written file; none of these twenty needed it, by luck of their layout. A face with five or more corners also costs a mesh all its tangents (the first rail stubs did that).

**The colour match can take a pale pane for iron.** The low-poly lantern's glass came out grey in patches: its palest texels were nearer, by hue, to the design's dark iron than to any colour the match had gathered. The lamps' glass now keeps the generator's colour. The match is also unsteady: the solarpunk railing came out with orange timber at 2,000 triangles and grey-pink timber at 4,000.

**The triangle rule by share of the diagonal fails a tall thin piece.** At 0.16% of 4.2 m the anime lamp passed at 1,500 with its finial crumpled. `--within` gives the two distances in millimetres.

**The cutter joined two objects on the solarpunk street-fixtures sheet** (the bollard and the catenary pole are its object 1) and took a swatch for object 2. On the voxel sheet it clipped the railing's pale post, which lies on a pale backdrop.

**The generator invents ground.** The voxel bollard came on a slab a metre square, of one piece with it.

**A fit repeats byte for byte only if its code walks nothing unordered.** The first panel code walked Python sets and gave the same piece in a different byte order each run. Fixed: sixteen files were built twice and compared, and again unchanged on the last build (`logs/hashes.txt`).

## Tool changes

`base/` is untouched. Against it, in `work/`:

| File | Change | Why |
| --- | --- | --- |
| `fit_generated.py` | 22 new options, documented at its top (`check_options.py`: 93 documented and read) | below |
| `build.py` | a style's entry may give `size`, `kit`, `post_file`, `post_mesh`; `materials: swatches` on an entry; `--panel-post` for a `post_file`; the post put through the cubes in voxel; `design_object`; `light` and extra options for the cube step | to describe these pieces |
| `voxelise.py` | `--light NODE`: the cell faces lit in the fitted piece's glow texture become a part of their own in `lamp_glow`, the rest takes `cubes`; the fitted piece's materials are renamed first | the voxel lamp's spec wants `post` and `light` and its test wants every material on `light` to emit; a second material of one name came out `lamp_glow.001` |
| `check.py` | street fixtures (an entry with `contract`) are held to `fixture_rules.py`; a railing and its post are held to their triangle limit; a `post_file` is checked as a piece; `size_as_drawn`; the validator | deliverable 3 |
| `fixture_rules.py` (new) | the rules, each with the game code it was read from | |
| `validate.cjs` (new) | runs the kits' pinned validator on files | |
| `cut_object.py` (new) | keeps one object of a cut-out that holds two | the solarpunk bollard's colours |
| `preview.py` (new) | the preview sheets | deliverable 4 |
| `look.py` | a kit piece is shown in its own colours (they are on its corners, not in a texture); `--span`, `--views`, `--heights`, `--light` | the kits' pieces rendered grey |
| `strip.py` | a cut-out is laid on the sheets' grey and trimmed | a dark object was lost on black |

| Option of `fit_generated.py` | What it does | Why |
| --- | --- | --- |
| `--axis` | the post's own axis goes on the origin | a lamp with an arm is not centred by its box |
| `--aspect-by height` | the even scale is taken from the box's height | a lamp is 4.2 m high and as wide as drawn |
| `--arm-at-x` | what reaches furthest in the upper half is turned to +x | where the kit's lamp carries its banner |
| `--hang-above R,Z` | what hangs further than R from the axis is drawn up to Z | the audit's band |
| `--panel`, `--panel-no-stubs` | the railing: turned, far post cut, ends closed, set from -1 to +1, centred across, rails carried through the post | how the game draws a fence |
| `--panel-post FILE`, `--panel-post-tris N` | the post alone as a second file | `railing_post.glb` |
| `--planar DEG`, `--planar-from N` | faces lying in one plane are joined between two cuts | flat bars held more triangles than they need and the ball too few |
| `--own-normals`, `--weighted-normals` | see above | |
| `--drop-hidden`, `--drop-hidden-from N` | see above | |
| `--bake-reach M`, `--mend-tangents`, `--within P95,MAX` | see above | |
| `--glow-from Z`, `--glow-part-from Z`, `--glow-part-least N` | only what is high enough glows, or goes into the part | a low-poly banner is as yellow as a lantern; a neon lamp glows low down too |
| `--object shortest` | keeps one object of a model that holds two | the solarpunk bollard |
| `--drop-plate` | cuts off a plate the generator stood the object on | the voxel bollard |

Existing pieces come out unchanged. `base/fit_generated.py` and the final `work/fit_generated.py` give the same bytes for the anime bench (sha256 `353f9446…`, which `build.py fit anime_cel bench` also gives), and the base and work fit and cube steps give the same bytes for the voxel bench (`scratch/regress/`). `build.py fit anime_cel bench` matched the main folder's `seat_bench_v2.glb` five times during the work; at 14:30 that file was built again by other tools (it is now `d1484f65…`) and matches neither.

Needed besides the tools: `scratch/validator/` (npm ci from the checkout's `prototypes/voxel-work-bay/tools/package*.json`) for the validator, and `scratch/designs/` where `build.py` writes the solarpunk bollard's own cut-out.

## The check

Implemented in `fixture_rules.py`, from the file alone: every rule in the table above marked "check".

Not implemented, because a file does not show it: the collision audit itself (it reads the ground the game draws under each piece; the file-side rule is taken with the band lifted to stand in for that); how lights, glow and ink look; the fence's joints at corners and ends; the kits' byte-for-byte test and the voxel import sidecar.

One rule is softer than the contract's wording: "the post as deep as the panel" is a miss in anime only, whose test it is, because a planter is deeper than the post beside it.

## Decisions the agent made

All can be undone in `work/assets.json`.

1. A lamp post is scaled evenly to its height on its own axis and is not fitted into the kit's box, so it misses the spec's width in four styles and its depth in three. Declared in `size_as_drawn`.
2. A lamp's body and glass share one material, `lamp_glow`, with the glass alone in the emission texture, as the pilot's trees have it; the kits give the glass a material of its own. In voxel the glass has its own, as the kit.
3. The lantern's glass keeps the generator's colour instead of being matched to the sheet; in voxel it takes the sheet's swatch.
4. The low-poly banner is drawn up to 2.2 m.
5. Bollards are filled to the kit's size; neon's to 0.27 m across.
6. The neon bollard's band takes the sheet's amber.
7. A railing is sized evenly by its length, so its post is square and its ball round, and it is as deep as drawn: deeper than any kit's. In voxel the box is filled instead, to put the post on the grid.
8. The low-poly railing's height alone is brought down 4.6% to what its spec allows.
9. Railings are held to 930 triangles before the stubs (830 in low-poly); the post file to its kit's limit.
10. Every piece is cut from a rebuilt surface (4 mm cells; 5 mm for railings) with its hidden faces dropped, its own weighted normals, and the bakes looking 1.2 cm. Anime pieces carry no relief map.
11. A lamp's triangles are chosen by 3 mm (95%) and 9 mm (all).
12. The solarpunk railing is delivered at its limit although it does not hold there.

## What remains

- **The neon railing's light strips**, and its post's. They need a rule that paints the glow by place (a band along the wall's top, the slot on the post): not built.
- **The solarpunk railing.** Give it about 4,000 triangles, or have the sheet drawn again with a plainer panel. Its post file should then be built again too.
- **The solarpunk bollard.** Cut the sheet again so that the bollard is its own object, and generate it again.
- **The voxel railing's post** has bands the design lacks; and whether a 0.4 m post is wanted where the kit's is 0.2 m is a decision.
- **Proportions against the kits' specs**, the open decision of the main record: fourteen of these twenty files stand on the design's side of it.
- **Everything the game shows**: the audit, the lamps lit, the ink lines, the fence's joints and stubs, the pieces under each style's light. None was run.
- **The seats and trees** were built with the generator's normals and its inner skin. Whether to build them again with the new options is to be decided.

## Running it again

```sh
cd .asset-pilot/2026-10-02-sheet-to-asset/agents/fixtures
export AGENTNAGAR=/path/to/agentnagar
python3 work/build.py fit anime_cel lamp-post bollard railing      # and lowpoly_tropical, neon_noir, solarpunk, voxel
( source $AGENTNAGAR/.local/dev-env.sh; python3 work/check.py )   # out/results.json; logs/check.txt holds the last run
python3 work/preview.py anime_cel                                  # previews/anime_cel-<piece>.png
python3 work/check_options.py
```

A fit takes 10 to 60 seconds a piece; all fifteen, about nine minutes. `logs/` holds the last run of everything: `fit-all.txt`, `check.txt`, `validator.txt`, `control-kits.txt`, `faults-<style>.txt`, `hashes.txt`, `normals.txt`, `parts.txt`, `tables.txt`.

The agent's own time on this was about three hours, against the 45 minutes asked for: the normals and the inner skin were found late, and the pieces were built again after each.

## Afterwards: what the game showed

Added by the coordinating session (Claude, an AI), which placed the pieces in the working copy of the game, ran its collision audit and captured them. The agent had seen none of this.

- **The audit.** With all twenty files placed the game's collision audit counted zero in every style, as the agent's file-side rules had said.
- **Lamp posts and bollards read well in all five styles** (`compare/fixtures-<style>.jpg`): the neon lantern and its lit foot, the neon bollard's amber band, the solarpunk lantern's brass, the low-poly banner. The solarpunk bollard, taken out of a model of two objects, is not visibly worse than the others in the game.
- **The voxel lamp is nearly black** in daylight beside the kit's slate one. Its cubes are the sheet's own swatch (`#3A393C`); it is the design, not a fault of the build, and it belongs with the open decision on palette.
- **Railings** have no close view: the game draws them as copies of one mesh along each fence, and the capture tool, which finds a planted tree's or shrub's copies, does not find a railing's. They show in each town's park view (`compare/town-<style>.jpg`). The anime and low-poly railings read well there. The neon railing has no lit strip, as the agent said. The solarpunk railing, a row of planter boxes, is the weakest: at 952 triangles its plants are shards.
- **The agent's two findings about the route were applied to the first set.** The seats were built again with their own normals, weighted by face area: flat boards shade flat, and their textures are as before but for the anime café chair's, which was baked again and differs in places (`previews/seats-normals-before-after.jpg`). Dropping hidden faces was tried on them and not adopted as a rule: on the anime reading chair, which is cut from a rebuilt surface, it took 14,414 of 14,859 faces.
- **The validator** the agent ran on its twenty files was then run on every built piece: seven had zero tangents (the anime bench it named among them), which are now mended, and all pass.
- **The merge.** This agent merged its own tools onto a snapshot of the tools as merged from the other forks, and proved it by rebuilding the anime bench, a bollard and a planter byte for byte. It was the quickest and safest of the merges.
