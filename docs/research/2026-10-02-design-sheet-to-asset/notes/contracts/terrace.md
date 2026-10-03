# Contract: the café terrace (table, umbrella, square planter, planter pot)

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

Read on 2026-10-02 from the checkout `agentnagar` (branch `docs/asset-to-sheet-pilot`, HEAD `1ec8f61`, nothing under `city/` changed in the working tree). Nothing was run in Godot or Blender, and nothing in the checkout was written.

Paths: `G/` is `city/godot/`, `K/` is `city/tools/styles/`, both in the checkout. `W/` is `.asset-pilot/2026-10-02-sheet-to-asset/work/`, outside it. Kit files are given relative to `G/styles/<style>/`.

How each statement is known:

- a `file:line` reference: read in the code or the data;
- **GLB**: parsed from the kit's GLB (its JSON chunk; where an extent at a height is given, its vertex positions, read with the pilot's `docs/research/2026-10-01-asset-to-sheet-pilot/tools/band.py`);
- **computed**: my arithmetic from the code and the data, not run in the game;
- **measured**: from an `asset-views.json` an earlier pilot took in the game (`.asset-pilot/2026-10-02-planter-benchmark/captures/today/<style>/`);
- **seen**: looked at in an existing capture of today's game (`.asset-pilot/2026-10-02-sheet-to-asset/game/captures/before/lowpoly_tropical/{street,diagonal,topdown,park}.png` and `before/neon_noir/park.png`);
- **inferred**: a conclusion the code does not state.

## Summary

1. **Three of the four objects are drawn by the game; the pot is not.** The table is the catalogue kind `cafe-table-top` (4 placed), the umbrella is `umbrella` (4 placed, on the same four points as the tables), the square planter is `planter` (11 placed). `planter_pot.glb` exists in four kits with a spec and is loaded by nothing: no entry of any `style.json` names it and no script does. The same is true of `cafe_table_set.glb` (four kits) and of voxel's `planter_long.glb`. Voxel has no pot and no table set.
2. **The files are not the same in every style.** Umbrella: `assets/umbrella_yellow.glb` in low-poly only; `assets/umbrella_cafe.glb` in neon, anime and solarpunk; `assets/v2/umbrella.glb` in voxel. Table: `assets/cafe_table.glb`, voxel `assets/v2/cafe_table.glb`. Planter: `assets/planter_square.glb`, voxel `assets/v2/planter.glb`. This corrects the brief, which gave `umbrella_yellow.glb` for all four non-voxel styles.
3. **The game changes widths, never heights.** The table (not voxel's) and the planter are filled to their footprints: whatever the piece draws between 0.15 and 2.2 m up is mapped onto the footprint as the walking grid draws it. A kit table 0.80 m across is drawn 1.00 m across (scale 1.25); a planter is drawn 1.305 m square. The umbrella is never scaled.
4. **The umbrella's pole comes up through the middle of the table.** Both stand on one point. Two chairs are placed separately by the game 0.70 m either side; sitters' knees go under the top.
5. **Only neon has parts the game acts on by name.** Its planter's `light` part gets a small lamp; the table's and umbrella's `lights` parts only glow. Material `lamp_glow` is driven by the time of day. In the other four styles the game looks up nothing in these pieces.
6. **Beyond the kit specs**, the kit tests want zero validator errors and warnings and (anime, neon, solarpunk, voxel) a kit that is byte for byte what its generator builds; the client's own collision audit is gated at zero offenders in every style, which constrains the table's and the planter's outline.

### Common to the three placed objects

These hold for the table, the umbrella and the planter in all five styles, unless a section says otherwise.

- **Where the entry is.** `props.<kind>` in `G/styles/<style>/style.json`: a `scene` path and, for some, `fill: true`. None of the three has `tiled`, `fit`, `perch`, `turn` or `scenes`.
- **How it is loaded and placed.** `Pack3D._placements` walks the layout's placements (`G/styles/pack_3d.gd:274-303`). For each, `_placement` instantiates the scene (`:419-420`, `_scene` at `:150-156`), sets its position to the placement's point (`:421`), turns it by the placement's `facing` (`:422`), fills it when the entry says `fill` (`:423-424`) and registers its materials (`:425`). The node is added to the world, tagged with the placement's ID and looked at for a `light` part (`:299-301`). Each copy is its own scene instance; none is a MultiMesh instance.
- **The places are fixed data.** They are the layout's placements, written by `city/fixtures/district/generate.py` into `city/fixtures/district/manifest.json`; the client reads them through the core's layout (`G/main.gd:228`). Every placement of these three kinds has no `facing`, so facing is 0 and the piece stands as authored, its -Z to the north (`G/core/city_geometry.gd:130-142`, `G/styles/pack_3d.gd:169-170`).
- **Fill.** `_fill_footprint` (`G/styles/pack_3d.gd:719-734`) takes the piece's band box: the x and z bounds, in the piece's own frame, of every face cut to heights 0.15 to 2.2 m, all meshes and all materials counted (`G/styles/kit_town.gd:214`, `:224-229`, `:262-281`, `:299-315`). It scales x by footprint width over band width and z likewise, leaves y at 1 (`:733`), and shifts the piece so the band box's centre lands on the footprint's centre (`:732`, `:734`). The footprint is the kind's, grown to the grid's cells by `CityGeometry.drawn_rect` (`G/styles/pack_3d.gd:746-762`, `G/core/city_geometry.gd:186-197`). A piece with nothing in the band is left as it is (`:724-725`).
- **The root's own transform is overwritten.** Position and, for a filled piece, scale are assigned to the instantiated root (`G/styles/pack_3d.gd:421`, `:733`), and the band box leaves the root's transform out (`G/styles/kit_town.gd:271-275`). The kit pieces' roots carry no transform (**GLB**). **Inferred:** a replacement's root must be an identity node with its geometry in child parts.
- **Names the game acts on in any placed piece.** A part named `light`: a lamp (`G/styles/pack_3d.gd:767-777`), placed at the middle of that part's mesh bounds (`G/styles/kit_town.gd:68-77`), not at the node's origin. Materials named exactly `lamp_glow`, `window_glow`, `fairy_glow` or `light`: lamp materials, their emission energy set to the style's `window_energy` (2.5 unless the style says) while the lamps are lit and to 0.35 by day (`G/styles/kit_town.gd:174-175`, `G/styles/pack_3d.gd:2057-2064`). Materials beginning `glass`: emission switched on (`G/styles/kit_town.gd:169-173`); beginning `neon`: neon (`:176-177`). In the styles with `wet_ground` (neon, anime, solarpunk), materials beginning `paving`, `asphalt`, `kerb`, `road`, `path` or `street` darken in rain (`G/styles/pack_3d.gd:115`, `:2167-2168`, `:2174-2183`). The kits' own list of such names is `K/shared/bake.py:22-25`.
- **What the files hold.** In every kit GLB of this family a part's mesh has the part's name, and no node or material carries `extras` (**GLB**). The game reads no metadata from a piece; the metas it uses (`placement_id`, `piece`) are ones it sets itself (`G/styles/style_pack.gd:228-230`).
- **What the game does not do to them.** No recolouring by palette (`_paint` is called only on people, `G/styles/pack_3d.gd:1661-1702`). No sway (only meadow chunks, `:515-523`). No sign or display (none of the three kinds has a display anchor, `city/catalogue/catalogue.json:111-121`, `:145-155`, `:328-338`). No shadow switched off on the piece. No collision shape and no walk area is read from the piece: walkability is the core's grid from the catalogue footprint, and the things a player can point at are boxes made from the catalogue footprint and the kind's `height` (`G/core/interact.gd:109-128`, `:327-330`).
- **Style-wide treatment after loading.** Anime: every material that comes from a file under `anime_cel/` is turned toon in place (toon diffuse and specular, roughness set to 0.32, a rim) (`G/styles/anime_cel/pack.gd:44-45`, `G/styles/anime_cel/toon.gd:30-54`, `:79-113`), and one full-screen pass inks every pixel where the depth of its four neighbours departs from its own by more than 6% of its distance in sum, or where a neighbour's normal differs from its own by more than 0.35 in 1 minus cosine, about 49 degrees; the ink fades out from 60 to 140 m (`G/styles/anime_cel/shaders/lines.gdshader:12-16`, `:39-46`). Neon and solarpunk (the lit pack): materials named `*_leaves` with alpha scissor get smoothed edges and take no shadows (`G/styles/lit/lit_pack.gd:47-57`); every lamp casts no shadow, and a lamp below 1.5 m is dimmed to 0.3 of the style's lamp energy and limited to 3.5 m (`:106-119`). Low-poly and voxel: nothing (`G/styles/style_pack.gd:327-328`).
- **Found by the capture tool.** The tool walks `pack.placement_nodes` and compares each node's `scene_file_path` file name with the needle: contained, or equal when the needle starts with `=` (`W/asset_views.gd:84-91`; the first pilot's script only has contains, `docs/research/2026-10-01-asset-to-sheet-pilot/tools/asset_views.gd:56-58`). The three placed kinds are tagged scene instances (`G/styles/style_pack.gd:228-230`), so they are found. **Measured** for the planter: 11 placed in each of the five styles. **Computed** for the table and the umbrella: 4 each, by the same code path; no capture of them exists.
- **Import settings stay with the file name.** Each kit GLB has an `.import` beside it, which a file swap leaves in place. LOD generation is on for every terrace piece except neon's and anime's `planter_square.glb` and all of voxel's (`G/styles/<style>/assets/*.glb.import`, key `meshes/generate_lods`); embedded images are pulled out beside the file (`gltf/embedded_image_handling=1`).

## Object 0: `cafe-table`

Kind `cafe-table-top`: "The table a ring of café chairs sits around", footprint a 1.00 m square about its point, height 75, capability `inspect` only, no anchors (`city/catalogue/catalogue.json:111-121`).

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/cafe_table.glb` | `assets/cafe_table.glb` | `assets/cafe_table.glb` | `assets/cafe_table.glb` | `assets/v2/cafe_table.glb` |
| Spec (file:line, key) | `K/lowpoly/specs/props.json:7` `cafe_table` | `K/neon/specs/props.json:7` `cafe_table` | `K/anime/specs/props.json:7` `cafe_table` | `K/solarpunk/specs/props.json:7` `cafe_table` | `K/voxel/specs/props.json:8` `cafe_table` |
| Spec size x, y, z (m) | 0.8, 0.75, 0.8 | 0.8, 0.81, 0.79 | 0.80, 0.75, 0.79 | 0.80, 0.75, 0.79 | 1.0, 0.8, 1.0 |
| Triangle limit | 1,500 | 1,500 | 1,500 | 1,500 | 150 |
| Spec nodes | `cafe_table`, `body` | `cafe_table`, `body`, `lights` | `cafe_table`, `body` | `cafe_table`, `body` | `table` |
| GLB nodes (**GLB**) | `cafe_table` > `body` | `cafe_table` > `body`, `lights` (origin 0, 0.8, 0) | `cafe_table` > `body` | `cafe_table` > `body` | `cafe_table` > `table` |
| GLB size, triangles (**GLB**) | 0.80 x 0.75 x 0.80, 132 | 0.80 x 0.81 x 0.788, 360 (`body` 304, `lights` 56) | 0.80 x 0.75 x 0.788, 304 | 0.80 x 0.75 x 0.788, 304 | 1.0 x 0.8 x 1.0, 112 |
| Materials (**GLB**) | `wood_light`, `wood`, `iron`: plain colours | `body`: `baked_r50_m0`, `baked_r75_m0` (vertex colours). `lights`: `baked_r75_m0`, `lamp_glow` (emissive) | `baked_r75_m0` (vertex colours) | `baked_r50_m0` (vertex colours) | `charcoal`, `white`: plain colours |
| Textures | none | none | none | none | none |
| `style.json` | `:194-197`, `fill` | `:218-221`, `fill` | `:208-211`, `fill` | `:218-221`, `fill` | `:191-193`, no `fill` |
| Scale the game gives (**computed**) | 1.250, 1, 1.250 | 1.250, 1, 1.269 | 1.250, 1, 1.269 | 1.250, 1, 1.269 | 1, 1, 1 |
| Scene instance | yes, 4 | yes, 4 | yes, 4 | yes, 4 | yes, 4 |
| Needle | `=cafe_table.glb` | `=cafe_table.glb` | `=cafe_table.glb` | `=cafe_table.glb` | `=cafe_table.glb` |

The table's materials are double-sided in the four Blender-built kits and single-sided in voxel (**GLB**).

**3. Placing.** Four fixed places on the café terrace, each a scene instance: `placement:cafe-table-1` to `-4` at (-30.5, 11.75), (-24.5, 11.75), (-30.5, 14.25), (-24.5, 14.25) m (`city/fixtures/district/generate.py:229-231`, `city/fixtures/district/manifest.json:1160`, `:1168`, `:1176`, `:1184`). Facing 0. In the four non-voxel styles it is filled: the drawn footprint of each of the four is exactly 1.00 by 1.00 m, centred (**computed** from `G/core/city_geometry.gd:186-197` with the grid's origin at the least room corner, -7200, -6650 cm, `city/crates/city-core/src/nav.rs:132-136`), so the kit's 0.80 m top becomes 1.00 m and its pedestal a quarter thicker, at unchanged height. The committed evidence agrees: every 3D style's table measures 100 by 100 cm in the band (`G/evidence/placement-kind-sizes.json:1600` on). Voxel's entry has no `fill`: the piece is drawn at its own size by its origin.

**4. Looked up or done after loading.** Nothing by name in low-poly, anime, solarpunk and voxel. Neon: `lamp_glow` on the candle is a lamp material (energy 1.1 lit, 0.35 by day; `G/styles/neon_noir/style.json:523`). The part is `lights`, not `light`, so it gets no lamp; `lights` parts get one only for pieces in `glow_lights`, which holds `tree_banyan` alone (`G/styles/lit/lit_pack.gd:93-105`, `G/styles/neon_noir/style.json:528-530`). The kit says the same: `lights` is "emission only" (`K/neon/props.py:21-28`, the candle at `:124-129`). Anime: toon and ink as above.

**5. What stands with it.**

- **The umbrella, on the same point.** `placement:cafe-umbrella-N` is placed at the table's own coordinates (`city/fixtures/district/generate.py:230-232`). The umbrella's pole therefore rises through the table's vertical axis: in a filled style the axis of the table's band box, since the fill centres that on the point (`G/styles/pack_3d.gd:732-734`); in voxel the table's origin. **Seen** in `park.png`: the pole comes out of the middle of the top. The kit tables have one central column on that axis: radius 0.04 m in low-poly, 0.035 m in the other three, 0.2 m square in voxel (**GLB**; `K/lowpoly/props.py:157-163`, `K/anime/props.py:183-191`, `K/voxel/props.py:260-269`). After the fill the non-voxel columns are 0.044 to 0.05 m in radius against poles of 0.028 to 0.035 m, so the pole is hidden inside the column below the top (**computed**). The umbrella's base (0.3 m radius in low-poly, 0.5 m square in the anime family, 0.4 m square in voxel, at most 0.1 m high) sits at the table's foot (**GLB**).
- **Neon's candle sits on that axis too.** The candle is at the top's centre, 0.75 to 0.81 m up, radius 0.05 m (**GLB**), and the umbrella's pole passes through it (**inferred** from the two positions).
- **Chairs are placed separately, not by a set piece.** Each table has two room seats of kind `cafe-table` 0.70 m either side along x, facing it (`city/fixtures/district/generate.py:233-235`); the game draws each as its own `seat_cafe-table_v2.glb` (voxel `cafe_chair.glb`) (`G/styles/pack_3d.gd:1138-1157`). `cafe_table_set.glb`, a table and two chairs in one mesh (`K/lowpoly/props.py:183-190`, `K/anime/props.py:216-223`), is placed nowhere. It exists in the four non-voxel kits with a spec at `K/<kit>/specs/props.json:8` (low-poly 1.9 x 0.9 x 0.8 m, the other three 1.92 x 0.91 x 0.79 m; 1,500 triangles; nodes `cafe_table_set`, `body`, and `lights` in neon) and has 540, 864, 808 and 808 triangles in the low-poly, neon, anime and solarpunk files (**GLB**).
- **Sitters.** Nothing in the code positions a figure by the table. By geometry (**inferred**): a sitter's hips are over the seat point, 0.70 m from the table's middle, and the low-poly kit's characters, as their test holds them, have their knees at least 0.3 m forward at hip height, 0.45 to 0.60 m (`K/lowpoly/test_assets.py:311-323`), so knees and shins reach to about 0.3 to 0.4 m from the middle, under the drawn top's rim at 0.5 m. **Seen** in `park.png`: a sitter's knees under the top. A seated figure whose headline is Working plays the typing clip (`G/styles/pack_3d.gd:1905-1909`), hands 0.6 to 0.9 m up and more than 0.2 m ahead of the chest (`K/lowpoly/test_assets.py:324-328`), which is at and over the rim of a top 0.75 m high.

**6. Tests beyond the spec.** See "Tests" at the end. For the table in particular (**computed** from `G/tools/collision_audit/audit.gd:386-446`): the grid blocks the sixteen cells whose centres lie at -38, -13, 12 and 37 cm from the table's point on each axis; each must have something drawn within 10 cm of it between 0.25 and 1.9 m up, and the next centres out (-63, 62 cm) must have nothing within 10 cm. A round top 1.00 m across meets both: the corner centres are 53.7 cm out, 3.7 cm beyond its rim. A top that does not come within 10 cm of those corners (a diamond, a cross) would not.

**7. Needle.** `=cafe_table.glb` in every style. Plain `cafe_table` also finds only the table today, because `cafe_table_set.glb` is never placed and the chair's file is `seat_cafe-table_v2.glb`, with a hyphen.

**8. Views.**

- `street` (and the `gathering` and `night-rain` captures, taken from it): not in view. The camera stands about (-2.9, 1.7, 16.7) looking 10 degrees east of north with a horizontal half-angle of about 43 degrees (`G/core/orbit_rig.gd:81-91`, `:175-190`); the tables lie 77 degrees or more west of north from it (**computed**; **seen**: none in `street.png`).
- `diagonal`: in view, small, beside the guild hall's south wall. The tables show below their umbrellas (**seen**); a palm trunk crosses one of the four in the low-poly capture.
- `topdown` and the map's picture (`G/styles/pack_3d.gd:2314-2345`): hidden under the umbrellas' canopies (**seen**).
- `park` (`G/tools/sheet_views.gd:86`): the westmost tables at the right edge, about 20 m off (**seen**).
- First person: wherever the player walks; a seated eye is 1.2 m up, a standing one 1.6 m (`G/core/fpv_camera.gd:10-12`), so the top's upper face is the nearest surface.

## Object 1: `umbrella`

Kind `umbrella`: "A café umbrella; its pole stands on the ground, its canopy above head height", footprint a disc of 0.40 m radius, height 220, capability `inspect` only (`city/catalogue/catalogue.json:145-155`).

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/umbrella_yellow.glb` | `assets/umbrella_cafe.glb` | `assets/umbrella_cafe.glb` | `assets/umbrella_cafe.glb` | `assets/v2/umbrella.glb` |
| Spec (file:line, key) | `K/lowpoly/specs/props.json:6` `umbrella_yellow` | `K/neon/specs/props.json:6` `umbrella_cafe` | `K/anime/specs/props.json:6` `umbrella_cafe` | `K/solarpunk/specs/props.json:6` `umbrella_cafe` | `K/voxel/specs/props.json:20` `umbrella` |
| Spec size x, y, z (m) | 2.3, 2.5, 2.3 | 2.33, 2.52, 2.33 | 2.30, 2.52, 2.30 | 2.30, 2.52, 2.30 | 2.4, 2.7, 2.4 |
| Triangle limit | 1,500 | 1,500 | 1,500 | 1,500 | 650 |
| Spec nodes | `umbrella_yellow`, `body` | `umbrella_cafe`, `body`, `lights` | `umbrella_cafe`, `body` | `umbrella_cafe`, `body` | `canopy` |
| GLB nodes (**GLB**) | `umbrella_yellow` > `body` | `umbrella_cafe` > `body`, `lights` (origin 0, 1.75, 0) | `umbrella_cafe` > `body` | `umbrella_cafe` > `body` | `umbrella` > `canopy` |
| GLB size, triangles (**GLB**) | 2.31 x 2.52 x 2.31, 196 | 2.33 x 2.515 x 2.33, 600 (`body` 472, `lights` 128) | 2.30 x 2.515 x 2.30, 472 | 2.30 x 2.515 x 2.30, 472 | 2.4 x 2.7 x 2.4, 498 |
| Materials (**GLB**) | `charcoal`, `white`, `jackfruit`, `jackfruit_dark`: plain colours | `body`: `baked_r75_m0`, `baked_r25_m75`, `baked_r50_m0` (vertex colours). `lights`: `lamp_glow` (emissive) | `baked_r75_m0` (vertex colours) | `baked_r50_m0`, `baked_r25_m75`, `baked_r75_m0` (vertex colours) | `charcoal`, `orange`, `orange_dark`, `white`: plain colours |
| Textures | none | none | none | none | none |
| Pole (**GLB**) | radius 0.035 m on the origin's axis | radius 0.03 m, on axis | radius 0.03 m, on axis | radius 0.028 m, on axis | 0.1 m square at x -0.1 to 0, z -0.1 to 0: 5 cm off the axis |
| Base (**GLB**) | disc, radius 0.30 m, 0.08 m high | 0.5 m square, 0.07 m high, a collar to 0.23 m | as neon | 0.5 m square, 0.08 m high, a collar to 0.24 m | 0.4 m square, 0.1 m high |
| Lowest point beyond 0.5 m from the axis (**GLB**) | 1.78 m (valance) | 1.655 m (bulbs); canopy 1.78 m | 1.78 m | 1.78 m | 2.10 m |
| `style.json` | `:204-206`, no `fill` | `:228-230`, no `fill` | `:218-220`, no `fill` | `:228-230`, no `fill` | `:200-202`, no `fill` |
| Scale the game gives | 1, 1, 1 | 1, 1, 1 | 1, 1, 1 | 1, 1, 1 | 1, 1, 1 |
| Scene instance | yes, 4 | yes, 4 | yes, 4 | yes, 4 | yes, 4 |
| Needle | `umbrella_yellow` | `umbrella_cafe` | `umbrella_cafe` | `umbrella_cafe` | `=umbrella.glb` |

**3. Placing.** Four fixed places, `placement:cafe-umbrella-1` to `-4`, at the four tables' points (`city/fixtures/district/generate.py:232`, `city/fixtures/district/manifest.json:1192`, `:1200`, `:1208`, `:1216`). Scene instances, facing 0, never scaled: what the file holds is what is drawn, by the file's origin. The same file is also named under `exteriors.cafe` (low-poly `G/styles/lowpoly_tropical/style.json:159-162`; the others alike), which no 3D pack reads: `exteriors` is resolved only by pixel art (`G/styles/pixel_art/townscape.gd:106`, `G/styles/pixel_art/pack.gd:995`), and the café has no building kind in the layout (`city/fixtures/district/generate.py:1032-1040`). That entry only makes the kit tests require the file to exist.

**4. Looked up or done after loading.** Nothing by name in low-poly, anime, solarpunk and voxel. Neon: the `lights` part (sixteen bulbs looped under the valance, `K/neon/props.py:106-118`) glows through `lamp_glow` and gets no lamp, for the reason given for the table. The part named `umbrella` that the game shows in rain is a part of each person's model (`G/styles/pack_3d.gd:1697-1702`, `:1799-1807`); it has nothing to do with this piece.

**5. What stands with it.**

- **The table, on the same point.** The pole must come up where the table's axis is; see the table. In voxel the kit's pole is 5 cm off the axis and inside the table's 0.2 m square column (**GLB**, `K/voxel/props.py:291-292`, `:265-266`).
- **People walk and sit under the canopy.** The canopy (1.15 m radius) covers the two chairs and walkable ground round the table. The collision audit counts an umbrella only within 0.3 m of its axis (`G/tools/collision_audit/solids_3d.gd:28`, `:356`), so nothing checks the canopy's height. The kit figures are 1.55 to 1.8 m tall (`K/lowpoly/test_assets.py:247`); the four non-voxel kits' valances hang to 1.78 m. **Inferred:** a canopy edge lower than the kit's cuts through walkers' heads, and no test will say so.
- **Seen from below.** A player seated at a chair looks up into the canopy from 1.2 m (`G/core/fpv_camera.gd:12`); the kits draw ribs and stretchers there (`K/lowpoly/props.py:150-152`, `K/anime/props.py:174-177`).

**6. Tests beyond the spec.** See "Tests". Nothing particular to the umbrella: its footprint disc lies inside the table's square, so the audit's cells round it are the table's (**computed**).

**7. Needle.** As in the table. Plain `umbrella` also works in all five styles: no other scene file of any pack has it in its name (**computed** from the packs' file lists).

**8. Views.**

- `street`: not in view (as the table).
- `diagonal`: four canopies beside the guild hall, each about 40 px across in a 1904 px frame (**seen**).
- `topdown` and the map: four discs; the canopy's top is all that shows of the terrace (**seen**).
- `park`: two canopies and their poles at the right edge (**seen**); in neon the bulbs show there too (**seen**, `neon_noir/park.png`).
- The title's drift circles the square at the diagonal's pitch and distance (`G/styles/pack_3d.gd:1935-1943`), so the terrace passes through it.

## Object 2: `planter`

Kind `planter`: "A raised planting box", footprint a 1.30 m square about its point, height 45, capability `inspect` only (`city/catalogue/catalogue.json:328-338`).

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/planter_square.glb` | `assets/planter_square.glb` | `assets/planter_square.glb` | `assets/planter_square.glb` | `assets/v2/planter.glb` |
| Spec (file:line, key) | `K/lowpoly/specs/vegetation.json:88-99` `planter_square` | `K/neon/specs/vegetation.json:11` `planter_square` | `K/anime/specs/vegetation.json:11` `planter_square` | `K/solarpunk/specs/vegetation.json:11` `planter_square` | `K/voxel/specs/props.json:12` `planter` |
| Spec size x, y, z (m) | 1.2, 1.4, 1.2 | 1.25, 1.42, 1.25 | 1.20, 1.40, 1.20 | 1.20, 1.40, 1.20 | 1.2, 1.0, 1.2 |
| Triangle limit | 1,500 | 1,500 | 1,500 | 1,500 | 300 |
| Spec nodes | `planter_square`, `body` | `planter_square`, `body`, `light` | `planter_square`, `body` | `planter_square`, `body` | `box` |
| GLB nodes (**GLB**) | `planter_square` > `body` | `planter_square` > `body`, `light` (origin 0.489, 0.723, -0.489) | `planter_square` > `body` | `planter_square` > `body` | `planter` > `box` |
| GLB size, triangles (**GLB**) | 1.20 x 1.477 x 1.239, 436 | 1.251 x 1.42 x 1.251, 1,104 (`body` 956, `light` 148) | 1.251 x 1.42 x 1.251, 956 | 1.201 x 1.40 x 1.20, 1,462 | 1.2 x 1.0 x 1.2, 216 |
| Materials (**GLB**) | `limewash`, `limewash_shade`, `soil`, `leaf`, `leaf_dark`, `leaf_yellow`, `leaf_light`: plain colours | `body`: `baked_r75_m0` (vertex colours), `foliage_leaves` (texture, alpha mask at 0.35). `light`: `lamp_glow` (emissive), `baked_r25_m75` | `baked_r75_m0` (vertex colours), `foliage_leaves` (texture, alpha mask at 0.35) | `baked_r75_m0`, `baked_r50_m0` (vertex colours) | `kerb`, `leaf`, `leaf_dark`, `leaf_light`, `soil`, `stone`: plain colours |
| Textures | none | one PNG, `foliage_leaves`, inside the file; the engine's copy beside it is `assets/planter_square_foliage_leaves.png` | as neon | none | none |
| Band box, 0.15 to 2.2 m (**GLB**) | 1.200 x 1.239, z from -0.639 to 0.600 | 1.251 x 1.251 | 1.251 x 1.251 | 1.201 x 1.200 | 1.200 x 1.200 |
| `style.json` | `:246-249`, `fill` | `:269-272`, `fill` | `:258-261`, `fill` | `:272-275`, `fill` | `:240-243`, `fill` |
| Scale the game gives (**measured**) | 1.0875, 1, 1.0533 | 1.0433, 1, 1.0433 | 1.0433, 1, 1.0433 | 1.0864, 1, 1.0875 | 1.0875, 1, 1.0875 |
| Scene instance (**measured**) | yes, 11 | yes, 11 | yes, 11 | yes, 11 | yes, 11 |
| Needle | `planter_square` | `planter_square` | `planter_square` | `planter_square` | `=planter.glb` |

**3. Placing.** Eleven fixed places, all scene instances at facing 0. Four at the square's corners, `placement:plaza-planter-1` to `-4` at (-14.5, -10.5), (14.5, -10.5), (-14.5, 10.5), (14.5, 10.5) m (`city/fixtures/district/generate.py:390`, `:410-411`, `city/fixtures/district/manifest.json:7344`, `:7352`, `:7360`, `:7368`). Seven on the quay, `placement:planting-345`, `-346`, `-355`, `-367`, `-377`, `-385`, `-405`, where the fixture's planting scatter puts a planter in place of a tree (`city/fixtures/district/generate.py:817-819`, `:909-910`, the same manifest `:4691`, `:4699`, `:4771`, `:4867`, `:4947`, `:5011`, `:5171`); they are plain placements at run time. Every one is filled to a drawn footprint of 1.305 by 1.305 m, its middle 0.25 cm north-west of the point (**computed**; **measured**: every style's planter is drawn 1.305 m wide and deep). A planter built 1.30 m square was placed at scale 1.004 (**measured**, `.asset-pilot/2026-10-02-planter-benchmark/contracts.txt`).

**4. Looked up or done after loading.**

- Low-poly, solarpunk, voxel: nothing by name. Voxel's material `kerb` begins with a rain-wetted prefix, but voxel has no `wet_ground` (`G/styles/voxel/style.json`, no such key), so nothing happens.
- Neon: the `light` part gets an OmniLight (`G/styles/pack_3d.gd:767-777`). The part holds a glowing strip round the foot of the box and an uplight on the coping's front right corner (`K/neon/vegetation.py:297-317`); its bounds' middle, where the lamp goes, is the middle of the box 0.38 m up (**computed** from the GLB and `G/styles/kit_town.gd:68-77`), not the node's origin at the uplight's lens, which is where the kit's own note says the lamp goes (`K/neon/vegetation.py:18-20`). The lamp takes the palette's `lamp_glow` colour, casts no shadow and, being under 1.5 m, is dimmed to 0.3 and limited to 3.5 m (`G/styles/lit/lit_pack.gd:87-89`, `:106-119`). `lamp_glow` on the strip and the lens is a lamp material. **Seen** in `neon_noir/park.png`: the lit line at each planter's foot.
- Neon and anime: `foliage_leaves` ends in `_leaves` and is alpha-scissored, so it gets alpha-to-coverage edges and takes no shadows (`G/styles/lit/lit_pack.gd:53-57`, `G/styles/anime_cel/toon.gd:109-112`).
- A planter's leaves are not left out of anything. The leaf-name rule (`leaf|leaves|foliage|frond`) applies only to a `fill: "trunk"` entry (`G/styles/kit_town.gd:219`, `:237-246`, `G/styles/pack_3d.gd:388-393`) and, in the audit, to street trees, palms and the great tree (`G/tools/collision_audit/solids_3d.gd:30`, `:246`). The planter's entry is `fill: true`: its plants count in the band box and as solid.

**5. What stands with it.** Nothing. The plants are part of the piece (one mesh with the box in every kit: `K/lowpoly/vegetation.py:489-498`, `K/anime/vegetation.py:633-651`, `K/solarpunk/vegetation.py:326-368`, `K/voxel/props.py:133-140`); the game adds none. Nobody is positioned by a planter. In neon the game adds the lamp above. The kit boxes are 0.6 m high (voxel 0.5 m) with a shrub to 1.4 m (voxel 1.0 m); the catalogue's 45 cm is used only for the box a first-person player points at (`G/core/interact.gd:128`, `:330`).

**6. Tests beyond the spec.** See "Tests". For the planter in particular (**computed**): the grid blocks the 36 cells whose centres lie within 63 cm of the point on each axis; each needs something drawn within 10 cm between 0.25 and 1.9 m up. A square box drawn 1.305 m wide covers them, corners included; a round or heavily chamfered outline would leave the corner cells bare (a corner radius above about 0.3 m).

**7. Needle.** `planter_square` in the four non-voxel styles: plain `planter` would also match `planter_pot.glb` if that were ever placed. Voxel: `=planter.glb`; plain `planter` would also match `planter_long.glb` if that were placed. Voxel also keeps an unused `assets/kit/planter.glb` from the first voxel pilot; it has the same file name and is placed nowhere.

**8. Views.**

- `street`: the two northern corner planters, about 30 m away, one either side of the great tree (**computed**; **seen** in `street.png`). The southern two and the quay's are outside the frame.
- `diagonal`: the square's four in frame, small (**seen**: at least the two southern ones).
- `topdown` and the map: small squares (**seen**).
- `park`: the clearest standard view of a planter. The eye stands at (-41.5, 1.7, 33.0) looking north along the quay (`G/tools/sheet_views.gd:86`); the nearest quay planter is 5.5 m ahead and the other six lie within the frame behind it (**computed**; **seen** in low-poly: the nearest fills about 250 px of a 1904 px frame, and four more show behind it).

## Object 3: `planter-pot`

No catalogue kind is drawn with it. `planter_pot.glb` is named by no `style.json` and by no script under `G/` outside pixel art's 2D sprite tables (search of `city/godot` for `planter_pot`: only `G/tools/collision_audit/solids_2d.gd:36` and pixel art's files). The kits build it and test it; the game never loads it.

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/planter_pot.glb` | `assets/planter_pot.glb` | `assets/planter_pot.glb` | `assets/planter_pot.glb` | none |
| Spec (file:line, key) | `K/lowpoly/specs/vegetation.json:100-111` `planter_pot` | `K/neon/specs/vegetation.json:12` `planter_pot` | `K/anime/specs/vegetation.json:12` `planter_pot` | `K/solarpunk/specs/vegetation.json:12` `planter_pot` | no spec |
| Spec size x, y, z (m) | 0.8, 1.1, 0.8 | 0.86, 1.14, 0.83 | 0.86, 1.14, 0.83 | 0.86, 1.14, 0.83 | |
| Triangle limit | 1,500 | 1,500 | 1,500 | 1,500 | |
| Spec nodes | `planter_pot`, `body` | `planter_pot`, `body`, `light` | `planter_pot`, `body` | `planter_pot`, `body` | |
| GLB nodes (**GLB**) | `planter_pot` > `body` | `planter_pot` > `body`, `light` (origin 0.070, 0.6, -0.261) | `planter_pot` > `body` | `planter_pot` > `body` | |
| GLB size, triangles (**GLB**) | 0.864 x 0.988 x 0.834, 228 | 0.864 x 1.142 x 0.834, 464 (`body` 396, `light` 68) | 0.864 x 1.142 x 0.834, 396 | 0.864 x 1.142 x 0.834, 616 | |
| Materials (**GLB**) | `terracotta`, `terracotta_light`, `soil`, `leaf`, `leaf_light`, `leaf_dark`: plain colours | `body`: `baked_r50_m0`, `baked_r75_m0`. `light`: `baked_r25_m75`, `lamp_glow` (emissive) | `baked_r75_m0` | `baked_r25_m75`, `baked_r25_m0`, `baked_r75_m0` | |
| Textures | none | none | none | none | |
| Placed, scaled | not placed | not placed | not placed | not placed | no piece |
| Scene instance | none to find | none to find | none to find | none to find | |
| Needle | `planter_pot` matches nothing placed | the same | the same | the same | |

**3 to 5.** Nothing: no placement, no scale, no facing, nothing looked up, nothing beside it. Builders: `K/lowpoly/vegetation.py:501-508`, `K/anime/vegetation.py:654-661`, `K/solarpunk/vegetation.py:386-396`, `K/neon/vegetation.py:320-332` (a pot with a small uplight clipped to its rim, the `light`).

**6. Tests.** The kit tests hold it to its spec like any other file in the kit's folder ("Tests").

**7 and 8.** It cannot be found as a scene instance and is in no view of the game. The one client tool that can draw it is `G/tools/asset_preview.gd:1-8`, which renders any kit GLB by file-name prefix on a stage of its own.

**Voxel.** The voxel kit has no pot. Its other planter, `assets/v2/planter_long.glb` (`K/voxel/specs/props.json:13`: 2.4 x 1.0 x 0.8 m, 350 triangles, node `box`; 246 triangles in the file), is 2.4 by 0.8 m, corresponds to no object on the sheet and is also placed nowhere: it appears only in the kit's own preview scene (`K/voxel/compose.py:253-254`).

## Tests

What the kits' suites require of a file in a kit's folder, beyond size, triangles and nodes:

| Kit | Requirement | Where |
| --- | --- | --- |
| all five | Size is the whole file's bounds, every node counted (`light` and `lights` too), each axis within 10% + 2 cm | `K/lowpoly/test_assets.py:64-97`, `:218-232`; `K/shared/kittests.py:92-107`; `K/anime/test_assets.py:65-80`; `K/voxel/test_assets.py:67-99`, `:215-230` |
| all five | Every GLB in the folder has a spec | `K/lowpoly/test_assets.py:234-237`; `K/shared/kittests.py:109-112`; `K/anime/test_assets.py:82-85`; `K/voxel/test_assets.py:232-234` |
| low-poly, anime, neon, solarpunk | Every path `style.json` names exists (the voxel suite has no such test) | `K/lowpoly/test_assets.py:172-190`; `K/shared/kittests.py:83-90`; `K/anime/test_assets.py:56-63` |
| all five | The pinned Khronos validator reports no error and no warning for any GLB in the folder | `K/lowpoly/validate.sh:18-28`; `K/shared/kittests.py:48-75`, `:122-126`; `K/anime/validate.sh`; `K/voxel/validate.sh` |
| anime, neon, solarpunk, voxel | Every GLB the generator builds matches the committed file byte for byte | `K/anime/test_assets.py:101-116`; `K/shared/kittests.py:128-144`; `K/voxel/test_assets.py:236-247` |
| voxel | No part shares the asset's (root's) name; primitives are indexed (the reader takes `prim["indices"]` without a fallback) | `K/voxel/test_assets.py:226-229`, `:82` |
| voxel | Every GLB has an `.import` beside it with `meshes/generate_lods=false` | `K/voxel/test_assets.py:253-257` |
| voxel | Specs and recipes name the same assets | `K/voxel/test_assets.py:210-213` |

The low-poly kit has no rebuild test. The "two materials at most" test names seven planted pieces and none of this family (`K/shared/kittests.py:27`, `:114-120`).

The byte-for-byte test means a generated piece committed into a kit's folder fails by construction until the kit's generator makes it. The pilot avoids this by placing pieces only in a working copy, where these suites are not run on them (`docs/research/2026-10-02-design-sheet-to-asset/README.md:178`).

The size each spec allows (**computed** from the rule):

| Piece | lowpoly_tropical | neon_noir | anime_cel, solarpunk | voxel |
| --- | --- | --- | --- | --- |
| Table across; high | 0.70-0.90; 0.655-0.845 | 0.70-0.90 (z 0.69-0.89); 0.709-0.911 | 0.70-0.90 (z 0.69-0.89); 0.655-0.845 | 0.88-1.12; 0.70-0.90 |
| Umbrella across; high | 2.05-2.55; 2.23-2.77 | 2.08-2.58; 2.25-2.79 | 2.05-2.55; 2.25-2.79 | 2.14-2.66; 2.41-2.99 |
| Planter across; high | 1.06-1.34; 1.24-1.56 | 1.105-1.395; 1.26-1.58 | 1.06-1.34; 1.24-1.56 | 1.06-1.34; 0.88-1.12 |
| Pot across; high | 0.70-0.90; 0.97-1.23 | 0.75-0.97 (z 0.73-0.93); 1.01-1.27 | as neon | no spec |

The game's own gate that touches these pieces: the collision audit runs in every style and every count must equal its budget, which is zero for all six gates in all styles (`G/tests/test_collision_audit.gd:23-45`, `G/evidence/placement-budget.json`). It reads what each piece draws between 0.25 and 1.9 m (`G/tools/collision_audit/audit.gd:52`), counts walkable cells inside a solid or within 10 cm of one (`:386-399`) and blocked cells in a room with nothing drawn within 10 cm (`:406-446`). Note the two bands differ: the fill measures 0.15 to 2.2 m, the audit 0.25 to 1.9 m.

## What a generated replacement must keep or put back by rule

### All of them

- **One root, identity transform, named as the kit's; geometry in a child part named as the kit's.** `cafe_table` > `body`; `umbrella_yellow` or `umbrella_cafe` > `body`; `planter_square` > `body`; voxel `cafe_table` > `table`, `umbrella` > `canopy`, `planter` > `box`. For the tools: `file`, `needle`, `name` and `mesh` are the per-style settings (`W/build.py:61-65`).
- **Stand on y = 0 with a flat, closed bottom.** The ground drawn under a piece is a few centimetres above or below 0 depending on where it stands (`G/styles/kit_town.gd:211-213`); the quay planters stand on lawn and are seen from 5 m in `park`.
- **Material names.** One textured material with a name of its own is safe. Do not use `lamp_glow`, `window_glow`, `fairy_glow` or `light` for anything that should not glow, nor a name beginning `glass`, `neon`, `paving`, `asphalt`, `kerb`, `road`, `path` or `street`. Names must be unique: a second `lamp_glow` becomes `lamp_glow.001`, which the game does not know.
- **Anime.** Roughness will be overwritten with 0.32 and a rim added, in place. Ink is drawn wherever neighbouring pixels' normals differ by about 49 degrees or more: a relief map or a mass of small leaf facets will be inked all over. **Inferred:** bake no relief map for anime and smooth the normals of planted masses.
- **Triangles.** 1,500 a piece in the four Blender-built kits. Voxel: 150 (table), 650 (umbrella), 300 (planter); the kit's own pieces use 112, 498 and 216.
- **What the pilot's check does not cover.** `W/check.py` measures a footprint only for the two tree files (`:31`, `:71-79`). Nothing in it measures a table's or a planter's band box, a planter's overhang, where an umbrella's pole stands or how low its canopy hangs.

### Café table

1. **The top is the widest thing between 0.15 and 2.2 m, and also between 0.25 and 1.9 m.** The game makes that width exactly 1.00 m in both directions in the four filled styles, so everything is widened by 1.00 over the piece's width (1.25 for a 0.80 m table) while heights stay. A foot wider than the top must stay below 0.15 m, or the fill fits the foot and the top comes out narrow, leaving blocked cells bare.
2. **The top's upper face at the kit's height: 0.75 m (voxel 0.8 m).** The game does not scale heights; sitters' hands in the typing clip are 0.6 to 0.9 m up at the rim.
3. **The top round or square.** After the fill, something of it must lie within 10 cm of the blocked cells' centres at the corners, 53.7 cm out on the diagonals. A round top 1.00 m across does (**computed**).
4. **Voxel is not filled: the piece must itself be 0.88 to 1.04 m across**, its top reaching at least 0.44 m from the middle in every direction (the spec's lower bound, and 10 cm short of the first walkable centres at 62 cm) (**computed**).
5. **One central column, concentric with the top's bounding box, or legs that leave the middle free.** The umbrella's pole stands on that axis from the ground to 2.4 m. A column hides it only if, after the widening, it is thicker than the pole (0.06 to 0.07 m across; voxel 0.1 m, 5 cm off the axis). With three legs, the pole and the umbrella's base (up to 0.6 m across, 0.1 m high) show between them.
6. **Nothing standing on the middle of the top** except neon's candle: the pole passes through it.
7. **Room for knees on the piece's two x sides.** Between about 0.1 and 0.65 m up, nothing beyond about 0.12 m from the axis as built (0.15 m after the widening) towards +x and -x, where the chairs stand. These figures are **inferred** from where the sitters are; the kits' own shapes are the measure: a slender column, a collar 0.1 m in radius just under the top and a foot at most 0.30 m in radius and 0.1 m high. With three legs, turn the piece so that no leg points along x.
8. **Neon: a part named `lights` holding the candle, material `lamp_glow`**, standing on the new top at its middle. Two traps in the tools as they are (read in the tool's code; what comes out is **inferred**, not run): the kit's box, which sizes the new piece, is taken over every kit mesh, `lights` included (`W/fit_generated.py:178-188`, `:257-258`), so the neon table would be stretched to 0.81 m instead of 0.75 m; and the rule that carries the kit's light part across moves it to hang 4 mm under whatever of the new piece its rays meet from the ground up (`W/fit_generated.py:1417-1437`), which is right for a strip under a seat and leaves a candle under the table top or inside it.

### Umbrella

1. **Built at its real size**: about 2.3 m across and 2.5 m high. The game does not scale it. Do not give the entry `fill`: the canopy's edge is inside the 0.15 to 2.2 m band and the footprint is a disc of 0.40 m radius.
2. **The pole on the origin's vertical axis**, within a centimetre or two, from the ground into the canopy. Centre the piece by its pole, not by its bounding box: a canopy that is not symmetric about its pole would otherwise move the pole off the table's middle. Voxel on a 0.1 m grid cannot centre a pole one cube thick; the kit puts it in the cube at x -0.1 to 0, z -0.1 to 0, inside the table's column.
3. **A thin pole**: 0.06 to 0.07 m across in the kits, so the table's column hides it.
4. **A low base inside the footprint's disc of 0.40 m radius**: the kits' reach 0.30 to 0.35 m from the axis and are at most 0.1 m high. It stands at the table's foot between the sitters' feet.
5. **The canopy's lowest edge no lower than the kit's**: 1.78 m in the four Blender-built kits, 2.10 m in voxel. The design's 2.2 m is better. Nothing in the game or its tests checks this.
6. **An underside that can be looked at**: it is seen from a seat beneath it.
7. **Neon: a part named `lights` with the bulbs under the canopy's edge, material `lamp_glow`.** The same two traps: the kit's box is 2.33 m wide because of the bulbs (the body is 2.30 m), and the carry rule would lift the whole ring by the height it finds under the canopy along the part's middle line, which is higher than the canopy's edge where the bulbs hang.

### Square planter

1. **Square to its corners, and built 1.30 m across.** The game draws the band box 1.305 m square whatever the piece's size; built 1.30 m it is hardly stretched (1.004) and still meets every kit's spec. Built to the kit's 1.20 or 1.25 m it is stretched 4 to 9%, as the kit's is.
2. **The plants inside the box's outline at every height.** Whatever the plants reach past the rim between 0.15 and 2.2 m is fitted to the footprint in the box's place, and the box is drawn that much smaller. Low-poly's kit planter overhangs 3.9 cm on one side: its box is drawn 1.305 m wide and 1.264 m deep.
3. **Total height inside the spec's range**: 1.24 to 1.56 m (neon 1.26 to 1.58 m, voxel 0.88 to 1.12 m). The design's box is 0.45 m high; planted to about 0.8 to 1.1 m above the rim it passes (voxel: 0.43 to 0.67 m), and with lower planting it fails the kit's size check. The kit boxes are 0.6 m high (voxel 0.5 m).
4. **Neon: a mesh part named `light`, material `lamp_glow`**, holding the strip round the foot and the uplight on the coping's front right corner (+x, -z). The game puts its lamp at the middle of that part's bounds, so keep the part's bounds centred on the planter and low. Traps in the tools (read in their code; the outcome **inferred**): the neon style's default setting `kit_lights: "lights"` (`W/assets.json`, `styles.neon_noir`) renames a carried part to `lights` (`W/build.py:143-144`, `W/fit_generated.py:1414`); the planter then has no `light`, its spec's nodes are not met and the game adds no lamp. Set `kit_lights` to `light` for this piece. The carry rule's move (`W/fit_generated.py:1417-1437`) applies here too and would lift the foot strip with the uplight. The strip sits against the wall of the kit's 1.20 m box, 0.55 m from the middle: on a 1.30 m box it must be laid out again, or it is buried in the wall.
5. **No leaf cards needed.** Neon's and anime's kit planters use `foliage_leaves` with a texture file kept beside the GLB (`planter_square_foliage_leaves.png`); `W/build.py:254-255` puts that file back beside whatever is placed, where it is unused and harmless. A cut-out leaf material in a replacement must end in `_leaves` to be treated as the kits' are.
6. **Eleven copies** in the district, seven of them along the quay in the `park` view: its triangles are drawn that many times.

### Planter pot

Nothing in the game holds it to anything. To be seen in the game at all, a kind's entry in each `style.json` has to name it, which is a change to the game and not a file swap. Fitted as a kit piece only, it needs: root `planter_pot`, part `body`, the spec's size, and in neon a part `light` with `lamp_glow` (the same `kit_lights` trap as the planter). Voxel has nothing to replace.

## Not determined

- **How the table and the umbrella look to the capture tool.** No capture of either exists. The count of 4 and the scales in the tables above are computed; only the planter's are measured.
- **Whether the validator passes a generated piece.** The suites fail on any warning; a file with WebP textures, tangents and its own UV layout was not put through it.
- **What LOD generation does to a dense generated mesh.** The kit pieces' `.import` files keep LODs on for most of this family; the kit meshes are too small for it to matter.
- **Frame time.** Nothing here measures 4 tables, 4 umbrellas and 11 planters at generated-mesh triangle counts and texture sizes.
- **Ink in anime.** The thresholds are read from the shader; how a particular generated surface comes out was not seen.
- **Occlusion in the other four styles' standard views.** The views were looked at in low-poly (and the park in neon). The layout is the same in every style, but trees and palms differ in size.
- **Whether anyone sitting at a café chair ever has the Working headline** in the fixture's day, and so types on the table.
- **Whether the pole inside the table's column, or the umbrella's base over the table's foot, flickers** where surfaces nearly coincide.
- **Whether the design sheets draw the table's middle clear and the planter's plants inside its rim.** The sheets were not looked at for this note.
