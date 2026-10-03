# Contract: the square's fountain

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

What the game and the kits expect of `fountain.glb` in the five 3D styles, so that a model generated from the `A-fountain` design sheet can take its place.

Read on 2026-10-02 from the checkout `agentnagar` (branch `docs/asset-to-sheet-pilot`, HEAD `1ec8f61`): the client's code, the kit builders, specs and tests, and the five kit GLBs (JSON chunk and vertex data, parsed with Python). Godot and Blender were not run and nothing in the checkout was changed. "Inferred" marks what I concluded; everything else was read at the reference given.

Paths are from the checkout's root. Seven files are cited by name alone:

| Short name | File |
| --- | --- |
| `pack_3d.gd` | `city/godot/styles/pack_3d.gd` |
| `kit_town.gd` | `city/godot/styles/kit_town.gd` |
| `lit_pack.gd` | `city/godot/styles/lit/lit_pack.gd` |
| `toon.gd` | `city/godot/styles/anime_cel/toon.gd` |
| `audit.gd` | `city/godot/tools/collision_audit/audit.gd` |
| `solids_3d.gd` | `city/godot/tools/collision_audit/solids_3d.gd` |
| `usables.py` | `city/tools/styles/shared/usables.py` |

Lengths are metres. A piece's own coordinates are the GLB's: y up, the origin on the ground at the basin's centre, its front toward -z. In the world x is east and z is south, and facings are degrees clockwise from north (`city/godot/core/city_geometry.gd:126-129`).

## Summary

1. The district has one fountain: `placement:square-fountain`, of the catalogue kind `fountain-rim`, at (10.0, -5.0) m in the tree square. Every 3D style draws its `fountain.glb` there as it was built: scale 1, turned 0 degrees, not fitted to a footprint. Nothing in the game corrects a piece of the wrong size.
2. The game looks up nothing in the piece by name. The parts `body` and `water` (in voxel the one part `basin`) are required by the kit's spec and tests only. The water is ordinary still geometry with its own glossy material. No style has a water shader, an animated material, particles or a sound for it, and the kit pieces have no falling water and no jet (voxel has one lighter cube on top).
3. Nobody sits on the rim. The catalogue gives eight places to sit 1.80 m from the centre, 30 cm outside the basin, facing out. The game stands a perch seat at each, reaching back 40 cm so that its last 10 cm are inside the basin's wall, and draws the sitter on that seat at ground level. The rim has only to meet those seats: outer face at 1.50 m, top at 0.45 m (0.50 m in voxel), solid in to 1.40 m.
4. What holds the piece to its footprint is the game's collision audit, a test with a budget of zero in every style. Between 0.25 and 1.9 m up, what the piece draws has to cover the 1.5 m disc and not reach past it. By my arithmetic the basin's outer radius there has to lie between 1.42 and 1.52 m (see 7).
5. The placed fountain is a scene instance, but `placement_nodes` holds a plain node above it. The pilot's capture tool, as written, finds no fountain for any needle (see 8).
6. Some of what I was given as known needs correcting or adding to for this piece (the section after 8).

## The five styles

Kit files are under `city/godot/styles/<style>/`. Every spec is the key `fountain` of the file named.

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/fountain.glb` | `assets/fountain.glb` | `assets/fountain.glb` | `assets/fountain.glb` | `assets/v2/fountain.glb` |
| Spec file and line | `city/tools/styles/lowpoly/specs/props.json:28` | `city/tools/styles/neon/specs/props.json:24` | `city/tools/styles/anime/specs/props.json:24` | `city/tools/styles/solarpunk/specs/props.json:24` | `city/tools/styles/voxel/specs/props.json:26` |
| Spec size x, y, z | 3.0, 1.86, 3.0 | 3.0, 1.86, 3.0 | 3.0, 1.86, 3.0 | 3.0, 1.86, 3.0 | 3.0, 2.0, 3.0 |
| Triangle limit (kit piece has) | 1,500 (1,292) | 1,500 (1,292) | 1,500 (1,292) | 1,500 (1,292) | 600 (456) |
| Nodes the spec names | `fountain`, `body`, `water` | the same | the same | the same | `basin` |
| Nodes in the GLB | root `fountain`; children `body`, `water` (a mesh each) | the same | the same | the same | root `fountain`; child `basin` (one mesh) |
| Materials | `sandstone`, `stone` (body); `water` | `baked_r75_m0` (body); `baked_r0_m0` (water) | `baked_r75_m0` (body); `baked_r0_m0` (water) | `baked_r25_m0`, `baked_r75_m0` (body); `baked_r0_m0` (water) | `stone`, `stone+`, `stone-`, `stone_dark`, `water`, `water+`, `water-`, `water_light` |
| Colour carried by | the materials' base colour | vertex colours (`COLOR_0`) | vertex colours | vertex colours | the materials' base colour |
| Textures, UVs | none | none | none | none | none |
| Faces | flat | smooth under 40 degrees | smooth under 40 degrees | smooth under 40 degrees | flat |
| Placed | once; scale 1; turn 0; no fitting | the same | the same | the same | the same |
| A value of `placement_nodes` | no: the node above it is (see 8) | no | no | no | no |
| Needle | `fountain` (or `=fountain.glb`) | the same | the same | the same | the same |

- No node in any of the five GLBs has a translation, rotation or scale. None has an animation, a skin, a texture or an image.
- Triangle counts: `body` 1,204 and `water` 88 in the four Blender-built pieces; the voxel piece's 456 are one mesh of eight material groups.
- The materials are double-sided in the four Blender-built pieces and single-sided in voxel, and opaque in all five.
- Material values. Low-poly: `sandstone` roughness 0.85, `stone` 0.85, `water` 0.08. Neon and anime: body 0.75, water 0. Solarpunk: `baked_r25_m0` 0.25 (the basin), `baked_r75_m0` 0.75 (the rim stone), water 0. Voxel: stone 0.85, water 0.25. The `baked_*` names are roughness and metal classes, not colours (`city/tools/styles/shared/bake.py:7-8, 40-42`).
- Colours, from the GLBs (they agree with the kit palettes). Low-poly: basin `#DCC6A0`, rim `#BFAE92`, water `#2D93A6` (`city/tools/styles/lowpoly/lib.py:24, 25, 72`). Neon: basin `#5C616C`, rim `#6E7280`, water `#173F73` (`city/tools/styles/neon/palette.py:26, 24, 58`). Anime: basin `#D9D3C7`, rim `#ADA598`, water `#2F80CB` (`city/tools/styles/anime/palette.py:15, 16, 44`). Solarpunk: basin `#F4F0E6`, rim `#E2D8C6`, water `#2B8ACB` (`city/tools/styles/solarpunk/palette.py:13, 23, 57`). Voxel: stone `#A9A8A0`, dark stone `#8A8983`, water `#2F7FD8`, light water `#5C9FEA` (`city/tools/styles/voxel/palette.py:15, 38, 22, 23`). Which role takes which colour: `basin`, `rim`, `water` in each kit's `USE_LOOK` (`city/tools/styles/lowpoly/props.py:496`, `city/tools/styles/neon/props.py:247`, `city/tools/styles/anime/props.py:523`, `city/tools/styles/solarpunk/props.py:183`).
- Flat or smooth: read from the GLBs' normals. The builders say the same: the low-poly kit finishes the piece as built (`city/tools/styles/lowpoly/props.py:501-509`); the other three smooth every part under 40 degrees (`city/tools/styles/anime/props.py:57, 528-541`; neon and solarpunk call the same function, `city/tools/styles/neon/props.py:39, 291`, `city/tools/styles/solarpunk/props.py:224`).
- Import settings beside the files (line 25 of each `fountain.glb.import`, for instance `city/godot/styles/lowpoly_tropical/assets/fountain.glb.import:25`): `meshes/generate_lods=true` in the four Blender-built styles, `false` in voxel.

## The kit piece in its own coordinates

### Low-poly, neon, anime, solarpunk

One builder makes all four: `fountain()` in `usables.py:188-207`, which the kits call with their own colours (`city/tools/styles/lowpoly/props.py:541`, `city/tools/styles/neon/props.py:291`, `city/tools/styles/anime/props.py:590`, `city/tools/styles/solarpunk/props.py:224`). The four GLBs' vertices agree with it to the millimetre. Radii are to the corners of many-sided rings and cylinders.

Part `body`:

| What | Radius | Height | Notes |
| --- | --- | --- | --- |
| Basin wall | 1.28 inner, 1.50 outer | 0 to 0.40 | 48 sides; outer wall, inner wall and top; the basin has no floor |
| Rim stone | 1.26 inner, 1.50 outer | 0.40 to 0.45 | 48 sides; so the rim's top is 0.24 broad at 0.45 |
| Foot of the centre piece | 0.32 | 0 to 0.36 | |
| Pedestal | 0.14 | 0.30 to 1.00 | |
| Lower bowl | 0.12 at 0.91, widening to 0.55 at 1.09 | | its rim ring 0.50 to 0.56, heights 1.09 to 1.15 |
| Shaft | 0.07 | 1.10 to 1.50 | |
| Upper bowl | 0.06 at 1.45, widening to 0.26 at 1.55 | | its rim ring 0.23 to 0.27, heights 1.55 to 1.59 |
| Spout | 0.04 | 1.58 to 1.78 | |
| Ball | 0.06 | 1.74 to 1.86 | the top of the piece |

Part `water`: three flat discs facing straight up (every normal is 0, 1, 0), with no thickness:

| Disc | Radius | Height | Sides |
| --- | --- | --- | --- |
| In the basin | 1.28 | 0.32 (13 cm under the rim's top) | 48 |
| In the lower bowl | 0.50 | 1.12 | 24 |
| In the upper bowl | 0.23 | 1.57 | 16 |

There is no falling water and no jet in these four pieces.

### Voxel

`fountain()` in `city/tools/styles/voxel/things.py:124-144`. The basin is a smooth drum, not cubes ("a disc a 10 cm voxel cannot follow", `:125-127`); the centre piece is 10 cm cubes. One mesh, `basin`.

| What | Extent | Height | Material |
| --- | --- | --- | --- |
| Stone drum | radius 1.50, 48 sides, capped | 0 to 0.50 | `stone`, `stone+`, `stone-` |
| Water drum | radius 1.30, 48 sides, capped | 0.50 to 0.51 | `water`, `water+`, `water-` |
| Pedestal | 0.4 by 0.4 | 0.5 to 1.4 | `stone` |
| Lower bowl | a disc of cubes, radius 0.5 | 1.0 to 1.2 | `stone_dark`; water in its middle (radius 0.4), top at 1.2 |
| Upper bowl | a disc of cubes, radius 0.2 | 1.5 to 1.7 | `stone_dark` |
| Shaft | 0.2 by 0.2 | 1.7 to 1.9 | `stone` |
| Top cube | 0.1 by 0.1, at x 0 to 0.1, z 0 to 0.1 | 1.9 to 2.0 | `water_light` |

So the voxel rim is the stone drum's top, 0.20 broad (radius 1.30 to 1.50) at 0.50, and the water brims a centimetre over it. The one `water_light` cube is the only thing in any of the five pieces that stands for a jet.

### The perch seat that stands against it

Each style's `perch` piece, in its own coordinates (origin on the ground at the sitter's place, front toward -z; read from the GLBs):

| Style | File | Block | Seat board | Top |
| --- | --- | --- | --- | --- |
| low-poly, neon, solarpunk | `assets/perch_seat.glb` | x -0.13 to 0.13, y 0 to 0.40, z -0.10 to 0.40 | x -0.15 to 0.15, y 0.40 to 0.46, z -0.15 to 0.40 | 0.46 |
| anime | `assets/perch_seat.glb` | the same | the same, and a cushion on it to 0.49 (`city/tools/styles/anime/props.py:559-561`) | 0.49 |
| voxel | `assets/v2/perch_seat.glb` | x -0.12 to 0.12, y 0 to 0.45, z -0.10 to 0.40 | planks x -0.15 to 0.15, y 0.45 to 0.51, z -0.15 to 0.40 | 0.51 |

The builder is `perch_seat()` in `usables.py:210-219` (voxel: `city/tools/styles/voxel/things.py:147-158`). Neon adds a `neon_cyan` strip under the front edge (`city/tools/styles/neon/props.py:292-293`).

Stood at a fountain's sit place (1.80 m from the centre, facing out), a seat reaches from 1.40 m to 1.95 m from the centre. Its back 10 cm lies inside the kit's basin wall (1.26 to 1.50), and its board's top is a centimetre over the kit's rim (0.46 over 0.45; voxel 0.51 over 0.50).

## 3. How the game uses the piece

**Where and how many.** One. The game loads the district fixture unless a test gives it another (`city/godot/main.gd:214`; `city/godot/core/paths.gd:35-40`). That fixture has one placement of the kind: `placement:square-fountain`, kind `fountain-rim`, at x 1000, z -500 cm, with no facing (`city/fixtures/district/manifest.json:8005-8010`; written by `city/fixtures/district/generate.py:407`, whose comment at `:400-405` puts it "in the north-east quarter of the square, clear of every way across it"). A placement with no facing faces 0 (`city/godot/core/city_geometry.gd:137`). The other fixture, `city/fixtures/two-room/`, has none.

**The kind.** `city/catalogue/catalogue.json:264-283`: the footprint is one disc of radius 150 cm at the origin (`:268`); eight `sit` anchors (`:271-280`); capabilities `sit` and `inspect` (`:281`); `height` 45 cm (`:282`). The client reads the kinds from the core (`city/godot/styles/style_pack.gd:126-131`), which has that file compiled in (`city/crates/city-contracts/src/catalogue.rs:180`).

**The skin.** In all five `style.json` files `props.fountain-rim` is a `scene` and a `perch` and nothing else: `city/godot/styles/lowpoly_tropical/style.json:282-285`, `city/godot/styles/neon_noir/style.json:305-308`, `city/godot/styles/anime_cel/style.json:294-297`, `city/godot/styles/solarpunk/style.json:308-311`, `city/godot/styles/voxel/style.json:276-279`. There is no `fill`, `fit`, `turn`, `tiled` or `scenes`. (The steps and the low wall, next to it in each file, do have `fill`.)

**Drawing.** `Pack3D._placements` (`pack_3d.gd:274-303`) calls `_placement` (`:400-428`) for it:

- the GLB is instanced (`:420`; `_scene`, `:150-156`). If it cannot be loaded the game draws a magenta box and records the path in `missing_scenes` (`:152-155, 159-162`);
- it is put at the placement's point with y 0 (`:401, 421`) and turned by minus (facing + `turn`), which is 0 (`:422, 169-170`): the piece's -z faces north;
- `_fill_footprint` is called only for a skin with `fill` (`:423-424`), so the fountain is never scaled and never measured: scale 1, 1, 1;
- its materials are registered by name (`:425`; see 6);
- because the skin has `perch`, the piece is then put under a new plain node together with eight perch seats (`:426-427`, `_perch` at `:437-458`; see 5 and 8).

**The walking band.** The measure the pack takes of filled pieces, 0.15 to 2.2 m up (`kit_town.gd:214`, used by `band_box` and `band_reach`, `:224-246`), is not taken of the fountain. The band reaches it another way. The core blocks every 25 cm cell of the walk grid whose centre is less than 150 + 10 cm from the fountain's point, whatever is drawn (`city/crates/city-core/src/footprint.rs:12, 437-442`; cells at `city/crates/city-core/src/nav.rs:21, 595-596`). The piece has to agree with that by itself, and the collision audit checks that it does, between 0.25 and 1.9 m up (`audit.gd:52`; see 7).

**Aiming at it in first person.** The crosshair rests on a box 3 by 3 m and 0.45 m high, taken from the catalogue's disc and `height`, not from the piece (`city/godot/core/interact.gd:116-128, 327-330`).

## 4. Water

**The game does nothing with the `water` part, in any of the five styles.** It is drawn as the GLB gives it: a mesh with a material.

- Nothing looks for a node or a material called `water`. In a placed piece the 3D packs look for these node names only: `light` (`pack_3d.gd:768`; `kit_town.gd:69`), `display` (`pack_3d.gd:671`, for kinds that show a panel), `screen` and `display` on workstations (`pack_3d.gd:302-303, 1212-1213`), `terminal_mount` on desks (`pack_3d.gd:1174`), and `lights` in the two lit packs (`lit_pack.gd:95`). The material names acted on are those in 6. A search for `water` in `city/godot` outside pixel art and the tests finds only the river: `make_scenery` (`pack_3d.gd:2543-2544`), the townscapes' `water()` (`city/godot/styles/lowpoly_tropical/townscape.gd:173-194`, `city/godot/styles/voxel/townscape.gd:213-232`), `water_y` and the moored boats.
- There is no water shader. The client's shaders are `city/godot/styles/shaders/sway.gdshader` (the meadow), `city/godot/styles/lit/face.gdshader` and `robot_eyes.gdshader`, `city/godot/styles/anime_cel/shaders/face.gdshader`, `lines.gdshader` and `outline.gdshader`, `city/godot/styles/pixel_art/palette_swap.gdshader` and `city/godot/core/ui/focus_glow.gdshader`. Even the river is still: copies of the kit piece `water_tile`.
- The only particles in the client are the rain (`pack_3d.gd:2244-2273`).
- Nothing is animated in the pieces (no animation in any of the five GLBs) or by the game.

What draws the water in each style:

| Style | The water as drawn |
| --- | --- |
| low-poly | The material `water` as imported: `#2D93A6`, roughness 0.08, lit by the pack's default light (`pack_3d.gd:1029-1073`), which takes reflections from the sky (`:1040`). |
| neon | `baked_r0_m0`: vertex colour `#173F73`, roughness 0. Lit as built; the lit pack changes nothing on it (`lit_pack.gd:47-59` touches leaf cards and the glazing of hall and library pieces only). In heavy rain neon turns on screen-space reflections (`lit_pack.gd:240-244`). |
| anime | `baked_r0_m0`, vertex colour `#2F80CB`, turned toon in place like every material under `anime_cel/`: toon diffuse and specular, roughness set to 0.32, a rim (`toon.gd:79-84, 93-101`; applied to the whole world at `pack_3d.gd:220` through `city/godot/styles/anime_cel/pack.gd:44-45`). The ink pass draws a line where depth steps or where neighbouring normals differ by 1 - cosine of 0.35 or more, about 49 degrees (`city/godot/styles/anime_cel/shaders/lines.gdshader:12-14, 45`). |
| solarpunk | `baked_r0_m0`: vertex colour `#2B8ACB`, roughness 0. Lit as built. |
| voxel | The material groups `water`, `water+`, `water-` and `water_light` of the mesh `basin`: `#2F7FD8` and two shades of it, `#5C9FEA` for the top cube, roughness 0.25. |

**What the game needs from the mesh.** Nothing: no UVs, no vertex colours, no particular shape or height. The kit's water has no UVs; it has vertex colours in three styles because that is how those kits carry all colour.

**A replacement with no `water` part, or with its water in the body's texture.** The game draws it without complaint. Three things follow all the same:

- the kit's spec is missed in the four Blender-built styles: the tests and the pilot's own `check.py` require a node named `water` (see 7; `../.asset-pilot/2026-10-02-sheet-to-asset/work/check.py:65-67`). The rule reads node names only, so an empty node would pass it;
- the water takes the body's one material. The pilot's settings give a piece roughness 0.85 (low-poly, anime, solarpunk), 0.6 (neon) or 0.9 (voxel) (`../.asset-pilot/2026-10-02-sheet-to-asset/work/assets.json:504-534`), where the kit's water is 0.08, 0, 0 and 0.25: the water stops being the glossy thing in the piece. In anime every roughness becomes 0.32, so there only the colour is at stake;
- the generator's water is lumps and sheets, and anime inks every sharp crease of them.

## 5. Seats

**Where people sit, and how the places are defined.** In the catalogue, as data: the kind's eight `sit` anchors (`city/catalogue/catalogue.json:271-280`), in centimetres from the placement's point:

| Index | At (x, z) | Faces |
| --- | --- | --- |
| 0 | 0, -180 | 0 (north) |
| 1 | 127, -127 | 45 |
| 2 | 180, 0 | 90 |
| 3 | 127, 127 | 135 |
| 4 | 0, 180 | 180 |
| 5 | -127, 127 | 225 |
| 6 | -180, 0 | 270 |
| 7 | -127, -127 | 315 |

All are 1.80 m from the centre, 30 cm outside the 1.50 m disc, facing out. Nothing is computed from the piece's size, and no node in the GLB is looked for. The client places the anchors from the catalogue for its prompts (`city/godot/core/interact.gd:109-115`), and the pack does the same to draw (`pack_3d.gd:441-453`). In the world the eight places are (10.00, -6.80), (11.27, -6.27), (11.80, -5.00), (11.27, -3.73), (10.00, -3.20), (8.73, -3.73), (8.20, -5.00) and (8.73, -6.27).

**Perch seats are drawn at the fountain.** `_perch` (`pack_3d.gd:437-458`) instances the skin's `perch` piece once for each `sit` anchor, puts it at the anchor on the ground (`:450-452`) and turns it the way the sitter faces (`:453`). It is not scaled. That is eight seats round the fountain, in the anchors' order. The game's own test holds it: the placement's node has the body and then one seat per anchor (`city/godot/tests/test_things_to_use.gd:86-104`). The committed captures show them: `city/godot/evidence/interact-<style>-sit-fountain-rim.png`.

**Where the sitter is drawn.** On the seat, not on the rim: at the seat's origin, at the height of the ground there, facing as the seat faces (`pack_3d.gd:468-478, 1821-1832`; ground height from `deck_at`, which is 0 off the bridge, `city/godot/styles/style_pack.gd:319-322`). The figure plays its `sit` clip (`pack_3d.gd:1897-1909`), which holds the hips 0.45 to 0.60 m up and within 12 cm of the origin (`city/tools/styles/lowpoly/test_assets.py:248, 311-323`). So the sitter's height never depends on the fountain; a sitter cannot float over or sink into the rim. The test `city/godot/tests/test_things_to_use.gd:117-161` holds the sitter within 3 cm of the seat.

**So what the rim has to be.** It has to meet the seats, which reach from 1.40 to 1.95 m from the centre at each of the eight bearings and are 0.30 wide:

- its outer face at 1.50 m, and nowhere under 1.40 m at a seat, or a gap shows between the seat's back and the wall;
- its top at 0.45 m (voxel 0.50). Between 0.40 and 0.46 m (voxel 0.45 and 0.51) the seat's board lies on it as on the kit's. Higher, the rim comes through the board; lower than 0.40 m, the seat's stone block stands up over the rim;
- stone from the outer face in to 1.40 m or less, up to that height (the kit's rim reaches in to 1.26): a thinner wall leaves the seat's back end standing in the water;
- flat and plain between 1.40 and 1.50 m: anything standing higher than the board's top there comes through the board;
- nothing of the piece outside 1.50 m above the ground: the sitter's hips are at 1.80 m and the back a little inside that.

How broad the rim is beyond that does not matter to sitting. These numbers are for the kit's perch seats; a perch seat replaced by a generated one changes them.

**Who sits there.** Perches are sat on through the `Use` command only (`city/crates/city-core/src/interact.rs:222-232`); the simulated crowd has no code that uses anchors (inferred: `city/crates/city-core/src/crowd.rs` and `synth.rs` name neither anchors nor capabilities). So in a tool capture started with `--as=none` the fountain's seats are empty.

## 6. Sound, light, and what else is done to the piece

**Sound.** None. The client has no `AudioStreamPlayer` and no sound file (searched `city/godot`); `city/README.md:1071` lists audio under what comes next.

**Light.** None at the fountain.

- `_light` gives a placement a lamp only if a node named `light` is found under it (`pack_3d.gd:300-301, 765-777`). Neither the kit fountains nor the perch seats have one. If a replacement had one, it would get one lamp of range 8 m at that part's middle (`kit_town.gd:66-77`), lit from dusk (`pack_3d.gd:2044-2055`); in neon and solarpunk a lamp lower than 1.5 m is cut to 0.3 of its strength and 3.5 m (`lit_pack.gd:113-115`).
- The lit packs light a `lights` part only for pieces in the style's `glow_lights` (`lit_pack.gd:93-105`), which is `["tree_banyan"]` in neon (`city/godot/styles/neon_noir/style.json:528-530`) and absent in solarpunk.
- No material of the kit fountains is one the game lights (below).
- The nearest street lamp is `placement:plaza-lamp-2` at (9, -9), 4.1 m from the fountain's centre (`city/fixtures/district/generate.py:395`).

**Neon's glow.** The neon fountain has none: it is built with no ornament (`city/tools/styles/neon/props.py:291`), unlike neon's steps, low wall and perch seat (`:287-293`). What glows at the fountain in neon is the cyan strip on each of the eight perch seats, in `perch_seat.glb`: the material `neon_cyan`, registered by `kit_town.gd:176` and lit from dusk, dark by day (`lit_pack.gd:229-237`).

**Material names the game acts on** (`kit_town.gd:157-177`; the kits' own list is `city/tools/styles/shared/bake.py:22-25`):

| Name | What the game does |
| --- | --- |
| begins `glass` | made emissive in the style's `glass_glow` colour, lit after dark (`kit_town.gd:169-173`; `pack_3d.gd:2060-2062`) |
| exactly `lamp_glow`, `window_glow`, `fairy_glow` or `light` | emission strength set by the hour (`kit_town.gd:174-175`; `pack_3d.gd:2063-2064`; `lit_pack.gd:226-228`) |
| begins `neon` | in the lit packs, emits its own colour from dusk and is darkened by day (`kit_town.gd:176-177`; `lit_pack.gd:229-237`) |
| begins `paving`, `asphalt`, `kerb`, `road`, `path` or `street` | darkened and made glossy by rain where the style has `wet_ground` (neon, anime, solarpunk) (`pack_3d.gd:115, 2174-2183`) |
| ends `_leaves`, alpha-scissored | leaf-card handling (`toon.gd:109-112`; `lit_pack.gd:53-57`) |

The kit fountains' material names match none of these.

**After loading, by style.**

- Low-poly and voxel: nothing (`_style_node` does nothing, `city/godot/styles/style_pack.gd:327-328`; neither pack overrides it).
- Anime: every material becomes toon in place, as in 4 (`toon.gd:30-54, 79-113`). A game test holds that no lit material in the city is left un-toon (`city/godot/tests/test_anime_pack.gd:32-45`). The ink pass reads the screen's depth and normals (`city/godot/styles/anime_cel/shaders/lines.gdshader:8-9`).
- Neon and solarpunk: nothing for this piece (`lit_pack.gd:47-59`).
- No recolouring by palette: the pack recolours people only (`_paint`, `pack_3d.gd:1745-1754`).
- Shadows: the piece casts and takes them as any mesh does; nothing sets it otherwise for placements.
- The map's picture is drawn from straight above (`pack_3d.gd:2314-2345`), so it shows the piece's top view.

## 7. What the tests require

**The kit tests** (`python3 -m unittest city/tools/styles/<kit>/test_assets.py`). The four Blender-built kits share one set of rules: low-poly's in `city/tools/styles/lowpoly/test_assets.py`, anime's in `city/tools/styles/anime/test_assets.py`, neon's and solarpunk's in `city/tools/styles/shared/kittests.py`.

- Spec: each axis of the bounding box within 10% + 2 cm of the spec's size, the triangle count within the limit, every named node present (`city/tools/styles/lowpoly/test_assets.py:218-232`; `city/tools/styles/anime/test_assets.py:65-80`; `city/tools/styles/shared/kittests.py:92-107`). For the fountain: x and z 2.68 to 3.32, y 1.654 to 2.066 (voxel 1.78 to 2.22). The box and the count are taken over every mesh in the file, the water included (`city/tools/styles/lowpoly/test_assets.py:64-97`). The node rule reads names alone (`:40-41, 228`).
- Every GLB in the folder has a spec (`city/tools/styles/lowpoly/test_assets.py:234-237`; `city/tools/styles/shared/kittests.py:109-112`), and every `assets/` path in `style.json` exists (`city/tools/styles/shared/kittests.py:83-90`).
- Every GLB passes the pinned Khronos validator with no error and no warning (`city/tools/styles/lowpoly/validate.sh:19-25`; `city/tools/styles/shared/kittests.py:57-66, 122-126`).
- The committed GLBs are byte for byte what the generator builds (anime, neon, solarpunk: `city/tools/styles/anime/test_assets.py:101-116`; `city/tools/styles/shared/kittests.py:128-144`). Any replacement fails this by being one.
- Voxel, besides the spec (`city/tools/styles/voxel/test_assets.py:215-230`): no part may carry the root's name, `fountain`, because Godot renames it (`:226-229`); the committed GLBs are what the generator builds (`:236-247`); the validator (`:249-251`); and every GLB has an `.import` file beside it containing `meshes/generate_lods=false` (`:253-257`).

Nothing in the kit tests is about the fountain alone.

**The game's tests that bear on the piece.**

- The collision audit, with a budget of zero for all six counts in every style (`city/godot/tests/test_collision_audit.gd:23-45`; `city/godot/evidence/placement-budget.json`). It reads every mesh under the placement, the eight perch seats included, cuts it to 0.25 to 1.9 m, flattens it and takes what its outline encloses as solid (`solids_3d.gd:82-125, 337-384, 409-439`; band at `audit.gd:52`). Then:
  - no walkable cell's centre may lie in the solid or within 10 cm of it (`audit.gd:386-399`), except, for the fountain's own solids, within the 25 cm squares round its sit anchors (`audit.gd:204-212, 247-253, 359`);
  - no blocked cell in a room may be without something drawn within 10 cm (`audit.gd:406-446`).
  
  What the audit last measured of the kit pieces is in `city/godot/evidence/placement-kind-sizes.json` under `fountain-rim`: the body's outline in a box of -155 to 155 cm, the water's in -135 to 130, the seats out to 195.
- By my arithmetic from those rules, the fixture's grid and the kit's seats (not a run of the audit): a round basin passes the three counts that need no simulated day for an outer radius in the band from 1.42 to 1.52 m. The nearest walkable cell centres are 1.623 m from the fountain's centre; the farthest blocked ones that no seat covers are 1.517 m. With no perch seats drawn the range would be 1.50 to 1.52 m.
- The fountain is drawn and no kit piece is missing (`city/godot/tests/test_things_to_use.gd:48-59`; `city/godot/tests/test_anime_pack.gd:140-143`; `city/godot/tests/lit_pack_suite.gd:136-139`); each placement is drawn once and tagged with its ID (`city/godot/tests/test_style_pack.gd:80-108`).
- The perch tests in 5.

## 8. Finding it and seeing it

**As a scene instance.** The body is one: it comes from `packed.instantiate()` (`pack_3d.gd:156`), so its `scene_file_path` ends in `fountain.glb` (inferred from how Godot instances a scene; `lit_pack.gd:97` and the pilot's tool rely on the same). But it is not a value of `placement_nodes`. `_perch` makes a new plain `Node3D` (`pack_3d.gd:438-440`), and that node is what is tagged and stored under `placement:square-fountain` (`pack_3d.gd:298-300`; `city/godot/styles/style_pack.gd:228-230`). Its `scene_file_path` is empty, as for any node made with `new()` (inferred; not run). The body is its first child and the eight `perch_seat.glb` instances are its other children (`city/godot/tests/test_things_to_use.gd:95-96`).

**The pilot's capture tool.** `../.asset-pilot/2026-10-02-sheet-to-asset/work/asset_views.gd:86-91` tests only the values of `placement_nodes`. For the fountain it will report 0 placed whatever the needle. It has to look at the children of a placement's node as well. The same holds for the other three perch kinds (steps, low wall, tram shelter) and for the perch seats themselves, which are only ever children of such nodes (inferred: the `perch-seat` entry in `assets.json`, needle `perch_seat`, finds none either).

**Needle.** `fountain`, or `=fountain.glb` for the whole name. In each of the five asset folders `fountain.glb` is the only file whose name contains `fountain`, and `fountain-rim` is the only skin that names it.

**Once found.** There is one, turned 0, scale 1. Its bounds are 3 m across, so the tool's `prop` frame (a camera 2.8 m away) is too close: it needs `frame: "auto"` and `count: 1`. The auto frame stands to the piece's front and right (the same file, `:122-132`), which is about 32 degrees east of north of it, looking south-west across the square.

**The game's own ways to see it**, with no needle:

- `city/godot/tools/probes/capture_interact.gd`, shot `sit-fountain-rim`: the player sits at anchor 4, the south place, and is shot from 3.2 m (`:24-25, 141-144`). This made the committed `city/godot/evidence/interact-<style>-sit-fountain-rim.png`.
- `city/godot/tools/probes/capture_views.gd` aims the orbit camera at a ground point given on the command line (`:1-9`); the fountain is at 10, -5.

**In the standard views** (`city/godot/tools/sheet_views.gd:83-101`; presets in `city/godot/core/orbit_rig.gd:68-93, 175-190`):

| View | The fountain |
| --- | --- |
| `street`, and `gathering` and `night-rain`, which use it | In frame, right of the tree. The camera stands at about (-2.9, 16.7) at eye height looking 10 degrees east of north; the fountain is 25 m off and 21 degrees right of the view's middle, about 120 pixels wide at 1920 by 1080 (inferred from `city/godot/core/orbit_rig.gd:81-91, 179-189` and `pack_3d.gd:1553-1562`). Seen so in the pilot's capture `../.asset-pilot/2026-10-02-sheet-to-asset/game/captures/new/anime_cel/street.png`. This view sees its south-west side. |
| `diagonal` | In frame and unhidden, a few tens of pixels across: mostly its water disc and the ring of seats (seen in `.../game/captures/new/anime_cel/diagonal.png`). |
| `topdown` | In frame, about 30 pixels across: a disc of water (seen in `.../game/captures/new/anime_cel/topdown.png`). |
| `park`, `workshop`, `a1` | Not aimed at the square; not checked. |

So from the two overhead views, and on the map, the fountain is its water's colour seen from above.

## Where this differs from, or adds to, what was taken as known

1. "Solarpunk and anime extend a lit pack": neon and solarpunk do (`city/godot/styles/neon_noir/pack.gd:6`, `city/godot/styles/solarpunk/pack.gd:6`, `lit_pack.gd:8`). Anime extends `Pack3D` directly (`city/godot/styles/anime_cel/pack.gd:7`). What the lit styles take from anime is the townscape (`city/godot/styles/lit/townscape.gd:6`).
2. The perch seat is drawn at the fountain too, eight times, not only on walls, steps and shelters. The design brief's "people sit on the rim" is, in the game, people sitting on eight seats built out from the rim.
3. The squeeze of a filled piece is real (`pack_3d.gd:719-734`) but does not apply here: the fountain's skin has no `fill`. The same footprint is enforced by a test instead, and nothing shows it in a capture.
4. Finding pieces as values of `placement_nodes` does not work for a perch kind (8).

The other points given hold as stated: the lamp material names are matched exactly (`kit_town.gd:174`); a part named `light` gets a lamp (`pack_3d.gd:765-777`); `lights` parts are lit only for pieces in `glow_lights` (`lit_pack.gd:93-105`); the figure sits at one height whatever the seat (`pack_3d.gd:1830`).

## What a generated replacement must keep or put back by rule

**Size and place.**

1. The origin on the ground at the basin's centre, y up, no transform on any node. The game uses the piece's own coordinates at scale 1.
2. The basin's outer wall at radius 1.50 m from the ground to the rim, all the way round. Held by the audit to about 1.42 to 1.52 m between 0.25 m and the rim. Filling the kit's box on x and z puts the widest points at 1.50 but does not make the basin round; a generated basin that bulges more than about 2 cm past 1.50 m, or falls more than about 8 cm short of it, on any bearing fails. The sure way is the one the tree's bed already takes (`--bed-box`): rebuild the wall and the rim's top by rule as a plain ring on the footprint, coloured from the generated stone.
3. Nothing above 0.25 m beyond 1.52 m from the centre on any bearing: falling water, a jet's arc, light strips standing proud of the wall, ornament on the rim. Below 0.25 m the audit does not look.
4. The whole within the kit's box: 3.0 by 1.86 by 3.0 (voxel 3.0 by 2.0 by 3.0), each axis within 10% + 2 cm. The game sets no height.
5. The game gives this piece no scale, so the scale recorded in `asset-views.json` will read 1, 1, 1 and says nothing about fit. The fit has to be checked on the piece: its greatest and least outer radius in the band, round the circle, not a box.

**The rim.**

6. Top at 0.45 m (voxel 0.50), flat and plain from radius 1.40 to 1.50 m; stone in to radius 1.40 m or less. See 5 for the limits.
7. The fitting tool's `--seat` rule does not do this: it finds the seat by dropping rays on the piece's middle, which here is the centre piece. The rim's top has to be found at radius 1.40 to 1.50 m round the ring, and the piece scaled below and above it separately, as `--seat` does for a seat. Filling the box does not put a design's rim at 0.45 m.

**Water.**

8. Tell water from stone by the colour the generator painted, as the tree's parts are told apart. The sheets give a water swatch.
9. In the basin: take out the generated water surface inside the rim's inner wall, with its splash and foam (the centre piece stays), and lay one flat disc facing up, from wall to wall. The kit's level is 0.32 m, 13 cm under the rim's top; in voxel the water brims at 0.50 to 0.51 m out to radius 1.30. The game does not depend on the level.
10. In each bowl of the centre piece: the same, a flat disc (the kit's are at 1.12 and 1.57 m).
11. These discs are the part `water`: a mesh node of that name under the root, with a material of its own. No UVs and no texture are needed. Its colour is the sheet's water swatch (the kit's are in the table above). Its roughness is what makes it water: the kit's is 0.08 in low-poly, 0 in neon and solarpunk, 0.25 in voxel; in anime the game sets 0.32 whatever is given. Opaque, as the kit's.
12. In voxel there is no `water` part: the water is material groups of the one mesh `basin`.
13. Falling water and the jet are not in the kit and the game will never move, light or sound them. Either leave them out, as the kit does, or keep them as still geometry. If kept: in the `water` part with the water's material, inside the basin, inside the triangle limit, and expect anime to ink their creases and neon and solarpunk to show them as glossy solids. Which of the two is a decision on the look; the contract allows both.
14. Do not leave the water in the body's texture. An empty node named `water` would pass the kit's rule and leave the piece with no water part; if that is done, say so.

**Names.**

15. Root `fountain`; parts `body` and `water` (voxel: root `fountain`, one part `basin`, and no part named `fountain`). These are the kit's rule, not the game's.
16. No part named `light` or `lights` unless a lamp is wanted (6).
17. Material names unique in the file, and none from the table in 6 unless that treatment is wanted. For the neon sheet's amber strips that treatment is wanted: a material named exactly `lamp_glow` has its emission turned up from dusk and down to 0.35 by day (`pack_3d.gd:2063-2064`). The fitting tool's `--glow lamp_glow --glow-warm` gives the piece's material that name and makes what is painted warm yellow emit. A part named `light` would also light the paving, dimly at that height.

**Triangles.**

18. The kit's limit is 1,500 for everything in the file, water included (the kit's piece: 1,292). Voxel: 600 (the kit's: 456). The pilot reports against these limits and does not hold a piece to them (`_triangles` in `assets.json`). The kit meets 600 only because its basin is a 48-sided drum and not cubes; a basin rebuilt from 0.1 m cubes would also break rule 2, its steps standing up to 7 cm either side of the circle (inferred; not built). In voxel keep the basin a drum and make only the centre piece from cubes.

**By style.**

19. Low-poly: flat faces. Anime, neon, solarpunk: smooth under 40 degrees, as the kits'.
20. Anime: a relief map and lumpy water both reach the ink pass through the normals (inferred for the relief map). Plain water and no relief map on the water keep its lines to the rim's edge.
21. Neon: the fountain needs no light of its own to match the kit. The cyan glow round it is the perch seats'.
22. A non-symmetrical design: the game turns the piece 0, so its front (-z) faces north, away from the tree, from the `street` view and from the `diagonal` view. The pilot's close views look at that front. The fitting tool's choice of quarter turn against the kit piece is arbitrary here, since the kit piece is all but the same at every quarter turn (inferred).

**Checks worth adding** (none exists for this piece in the pilot's tools: `check.py` checks a footprint for trees only, `:31, 71-79`).

23. Outer radius in the band on every bearing, greatest and least; the rim's top height and inner radius at the eight bearings; the node names; one material for water.
24. The game's own audit can be run by hand on the working copy, without a display: `godot --headless --path city/godot --script res://tools/collision_audit.gd -- --audit-style=<style> --audit-ticks=0 --audit-out=<folder>` (`city/godot/tools/collision_audit.gd:1-19`). It writes `<folder>/<style>/report.json`, which names each offending cell and the placement it belongs to, and `overlay.png` (`:58-73`). `through`, `within_10cm` and `reverse_blocked` should stay at 0. Leave out `--measure-kinds` and `--write-budget`: they write into the project's `evidence/` folder. The swapped piece has to be imported first, as for any start of the game.

## Not determined

- The audit's exact margins. The 1.42 to 1.52 m range is my arithmetic for a perfectly round basin. The audit itself traces outlines on a 2.5 cm raster and counts anything within 1 cm as touching (`solids_3d.gd:24`; `city/godot/tools/collision_audit/solid.gd:70`), so the true limits may differ by a centimetre or so. It was not run.
- Whether the Khronos validator, which the kit tests fail on any warning, passes the pilot's files (a texture, WebP inside). Not run.
- The node tree Godot builds from the GLB (that the root is `fountain` with `body` and `water` as mesh children), and the name of the node `_perch` makes (`pack_3d.gd:439`). Nothing in the game depends on either.
- Whether the levels of detail Godot makes on import in the four Blender-built styles (`generate_lods=true`) coarsen a replacement visibly at the `street` view's 25 m.
- How the ink pass treats a baked relief map: I take it that it reads the map through the screen's normals, from the shader's inputs. Not tried.
- The fountain's size in pixels in the `diagonal` and `topdown` views beyond the rough figures read off two captures; and the `park`, `workshop` and `a1` views were not checked.
- Which object number the cutting tool gives the large view on an `A-fountain` sheet.
- Design sheets: at the time of reading the checkout holds `docs/vision/asset-studies/sheets/<style>/A-fountain/r001/image.png` for `lowpoly_tropical`, `anime_cel` and `neon_noir`, and none yet for `solarpunk` and `voxel`. All three draw falling water and splashes, and the low-poly and anime ones a jet on top; the neon one also draws amber light strips round the basin's wall and on the centre piece.
