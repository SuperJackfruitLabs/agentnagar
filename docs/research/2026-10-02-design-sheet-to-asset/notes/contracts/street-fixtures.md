# Street fixtures: what the game expects of the lamp post, bollard, catenary pole and railing

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

Read on 2026-10-02 from the checkout at commit `1ec8f61` (branch `docs/asset-to-sheet-pilot`). Nothing was run in Godot or Blender and nothing in the checkout was changed. Styles covered: `lowpoly_tropical`, `neon_noir`, `anime_cel`, `solarpunk`, `voxel`.

How to read the references:

- `G/` is `city/godot/`, `T/` is `city/tools/styles/`, `W/` is the pilot's working folder `.asset-pilot/2026-10-02-sheet-to-asset/`. A reference is `file:line`.
- Kit file paths in the tables are relative to `G/styles/<style>/`.
- Parts, materials, triangle counts and sizes of the kit pieces were read from each GLB's JSON chunk. Figures for the walking band were computed in Python from the kit files' vertex data with the game's own cutting rule (`G/styles/kit_town.gd:299-315`).
- "Cached import" is the engine's own import of the current kit file under `G/.godot/imported/` (each cache's recorded source hash matches the kit file). It shows what the game holds after import.
- A statement marked *inferred* or *computed* was not read from a line of this repository.
- *Seen* marks something looked at in a capture of today's game that the pilot had already taken, with the kits' own pieces: `W/game/captures/before/<style>/<view>.png`.

## Summary

- **Lamp post and bollard** are drawn as one scene instance for each placement in the layout (28 lamps, 8 bollards), at the file's own size, turned to the placement's facing. Nothing scales, fills or fits them, so nothing in the game corrects a wrong size. Both are found through `placement_nodes` by their scene file's name.
- **A lamp is lit through two names.** A part named `light` puts a lamp at the middle of that part's bounding box. A material named exactly `lamp_glow` is driven by the clock, and it must bring its own emission in the file: the game sets only its strength. Lamp colour, energy and range differ by style (table in the lamp post section).
- **The railing is not a placement.** Fences in the layout's scenery are laid as MultiMeshes of the first mesh in `railing.glb` (226 panels in this district) and `railing_post.glb` (6 posts). Transforms on the file's nodes are ignored, a panel is taken to be exactly 2 m long along x with its post at the −x end, and the whole fence is set off the floor by the pieces' half depth. There is no scene instance, so no needle finds either piece.
- **There is no kit piece for the catenary pole in any style.** Mast and arm are built in code in a palette colour; the wire is a 3 cm box at 5.7 m built with the track, and voxel draws no wire at all. A generated pole cannot go in by copying a file over a kit file.
- **The collision audit is the rule that bites.** A client test holds every style to zero offenders: between 0.25 and 1.9 m above the ground a lamp, bollard or pole must stay within about 29 cm of its point (its footprint disc of 20, 15 or 15 cm is the safe bound) and must also reach at least 8.4 cm from its point all round. A post that is slim right down to the ground fails.
- **The kit lamp's spec size is its ornaments.** The spec's 0.74 to 0.75 m width is the kit's banner arm, cross-bar or solar canopy, and the low-poly lamp's box is off-centre (x from −0.24 to +0.50). Filling the kit's box stretches a plain lamp and, in low-poly, moves its post 13 cm off its footprint.
- **Corrections to what was taken as known.** `anime_cel` extends `Pack3D`, not the lit pack; only `neon_noir` and `solarpunk` extend `LitPack`. A `light` part gets a lamp only on a piece drawn as its own placement, and in the three `Pack3D` styles that lamp is not small (8 m reach, energy 2.4).

## 0. Lamp post (`lamp-post`)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/lamp_post.glb` | `assets/lamp_post.glb` | `assets/lamp_post.glb` | `assets/lamp_post.glb` | `assets/v2/lamp.glb` |
| Spec file and key | `T/lowpoly/specs/props.json:5` `lamp_post` | `T/neon/specs/props.json:2` `lamp_post` | `T/anime/specs/props.json:2` `lamp_post` | `T/solarpunk/specs/props.json:2` `lamp_post` | `T/voxel/specs/props.json:10` `lamp` |
| Spec size x, y, z (m) | 0.75, 4.2, 0.5 | 0.74, 4.22, 0.5 | 0.74, 4.22, 0.50 | 0.74, 4.21, 0.50 | 0.6, 4.5, 0.6 |
| Triangle limit | 1500 | 1500 | 1500 | 1500 | 250 |
| Spec nodes | `lamp_post`, `body`, `light` | `lamp_post`, `body`, `light` | `lamp_post`, `body`, `light` | `lamp_post`, `body`, `light` | `post`, `light` |
| Parts in the GLB | root `lamp_post`; meshes `body`, `light` | root `lamp_post`; meshes `body`, `light` (the `light` node moved to y = 4.0) | root `lamp_post`; meshes `body`, `light` | root `lamp_post`; meshes `body`, `light` | root `lamp`; meshes `post`, `light` |
| Size of the GLB (m) | 0.740 by 4.190 by 0.480, x from −0.24 to +0.50 | 0.744 by 4.220 by 0.500 | 0.744 by 4.220 by 0.500 | 0.740 by 4.213 by 0.500 | 0.600 by 4.500 by 0.600 |
| Triangles (body + light) | 418 (406 + 12) | 392 (312 + 80) | 456 (444 + 12) | 664 (620 + 44) | 196 (160 + 36) |
| Materials | body: `iron`, `jackfruit`, `jackfruit_dark`, `leaf_dark`; light: `lamp_glow` | body: `baked_r75_m0`; light: `lamp_glow` | body: `baked_r75_m0`; light: `lamp_glow` | body: `baked_r50_m0`, `baked_r25_m75`, `baked_r25_m0`; light: `lamp_glow` | post: `charcoal`; light: `lamp_glow` |
| Textures, vertex colours | none, none | none, on `body` | none, on `body` | none, on `body` | none, none |
| How placed | one scene instance a placement, facing from the layout | same | same | same | same |
| Scaled by the game | no | no | no | no | no |
| Found as a scene instance | yes | yes | yes | yes | yes |
| Needle | `lamp_post` or `=lamp_post.glb` | `lamp_post` or `=lamp_post.glb` | `lamp_post` or `=lamp_post.glb` | `lamp_post` or `=lamp_post.glb` | `=lamp.glb` |

Each kit file is the builder's "empty named after it parenting one merged mesh, `body`, plus the parts the pack drives by name" (`T/lowpoly/props.py:7-11`). The builders: `T/lowpoly/props.py:98-126`, `T/neon/props.py:51-68`, `T/anime/props.py:62-90`, `T/solarpunk/props.py:50-77`, `T/voxel/props.py:191-214`.

### Where it stands and how it is drawn

- Each style's `style.json` maps the catalogue kind `street-lamp` to the kit file with `scene` and nothing else (`G/styles/lowpoly_tropical/style.json:198-200`, `neon_noir/style.json:222-224`, `anime_cel/style.json:212-214`, `solarpunk/style.json:222-224`, `voxel/style.json:194-196`). The kind's footprint is a disc of 20 cm radius; it snaps to 25 cm; its height is 350 cm (`city/catalogue/catalogue.json:122-133`).
- `Pack3D._placements` takes the layout's placements in ID order (`G/styles/pack_3d.gd:274-303`, `G/core/city_geometry.gd:130-142`). An entry with only `scene` goes through `_placement` (`pack_3d.gd:400-428`): the GLB is instantiated (`_scene`, `:150-156`), `position` is the placement's point at y = 0 (`:421`) and `rotation.y` is `-deg_to_rad(facing)` (`:422`, `:169-170`). No scale is set, because the entry has none of `fill` (`:423-424`), `fit` (`:409-418`), `tiled` (`:285-297`) or `perch` (`:426-427`). The node is added to `world`, tagged with its placement ID and handed to `_light` (`:298-301`).
- A file that fails to load is drawn as a magenta 0.6 m cube (`pack_3d.gd:150-162`).
- Facing is the layout's `facing`, degrees clockwise from north; the piece's −Z (the kits' front: "pieces face +Y (Godot -Z)", `T/lowpoly/props.py:4`) points that way.
- The district has 28 (`city/fixtures/district/manifest.json`, written by `generate.py`): 22 along the streets, one every 22 m, 70 cm beyond the carriageway's edge, sides alternating, "each facing the street it lights" (facings 0, 90, 180, 270; `city/fixtures/district/generate.py:788-814`), and six round the great tree in the square, facing it (facings 45, 135, 225, 315, 180, 0; `generate.py:395`, `:413-415`).
- Facing matters only where a lamp is not the same all round. The kits': low-poly has a banner on an arm to +x; neon and anime a cross-bar along x; solarpunk a canopy 0.74 m along x by 0.48 m, tilted 12 degrees about x; voxel is the same from all four sides.
- All 28 stand on the 25 cm snap, which puts them on corners of the walkable grid's cells (*computed*: the grid's origin is the least corner of the rooms, (−7200, −6650) cm, a multiple of 25; `city/crates/city-core/src/nav.rs:126-138`).

### How the lantern is found and lit

1. **The lamp.** `_light` looks for the first node named `light` anywhere under the placement's node (`find_child("light", true, false)`, `pack_3d.gd:767-770`). If there is one it adds an `OmniLight3D` to `world` with meta `lamp_of` = the placement's ID, reach 8.0 m and colour `Color(1.0, 0.85, 0.55)` (`:771-777`).
2. **Its position** is `KitTown.light_point` (`G/styles/kit_town.gd:68-77`): where `light` is a mesh instance, the centre of that mesh's bounding box, carried through the part's own transform, its parents' and the piece's (`:71-77`). Where `light` is some other kind of node, the lamp goes 3.0 m above the piece's origin (`:70`). In the kits that is 3.70 m (low-poly), 4.00 m (neon), 3.75 m (anime), 3.68 m (solarpunk) and 3.95 m (voxel), on the axis.
3. **Only placements get one.** `_light` is called from one place (`pack_3d.gd:301`). Seats (`:1138-1159`), tiled planting (`:285-297`, `:806-825`), fences and buildings never reach it.
4. **The glowing material.** `KitTown._collect` runs on the piece (`pack_3d.gd:425`) and keeps every surface material whose `resource_name` is exactly `lamp_glow`, `window_glow`, `fairy_glow` or `light` in `lamp_materials` (`kit_town.gd:157-177`, the test at `:174-175`). It reads the mesh's own surface materials (`:165`), not overrides, and it does not switch emission on: that it does only for names beginning `glass` (`:169-173`).
5. **By the clock.** `set_time_of_day` (`pack_3d.gd:2024-2067`) takes `lit` as minutes at or after `lamps_on_from` or before `lamps_off_at` (`:2043-2044`). Every lamp gets `light_energy = lamp_energy` (times its `energy_scale`) when lit, else 0, and `visible = lit` (`:2051-2055`). Every lamp material gets `emission_energy_multiplier = window_energy` when lit, else 0.35 (`:2056-2064`). So the strength written in the file is overwritten; the emission's colour, and whether emission is on at all, come from the file.
6. **The lit packs** (`neon_noir`, `solarpunk`) change the lamps after the scenery is built (`G/styles/lit/lit_pack.gd:83-121`): placement lamps take the palette's `lamp_glow` colour (`:87-89`); every lamp has shadows off and its reach raised to `lamp_range` (`:107-109`); a lamp lower than 1.5 m is dimmed to 0.3 of the energy and its reach cut to 3.5 m (`:113-115`); with `lamp_fade_m` the lamp fades out with distance over 20 m (`:116-119`). In the lit packs a material named `fairy_glow` is dark by day (`:225-228`); `lamp_glow` is not.
7. **Rain.** In a style with `rain_streaks`, the first rain makes one flat quad of 0.5 by 3.0 m for every lamp, unshaded and additive, in the palette's `lamp_glow` colour with a radial fade, 3 cm above the ground under the lamp (`pack_3d.gd:2163-2166`, `:2196-2221`). Each frame it is turned toward the camera and moved 1.5 m toward it (`:2224-2233`); it shows when rain is over 0.1 and calm mode is off, stronger after dark (`:2187-2191`). This is the only thing the game draws on the ground for a lamp; the pool of light is the lamp's own light.
8. **Nothing else is done to the piece.** No material override, no shadow setting and no scale are applied to it. The catalogue's `lit` state (`catalogue.json:130`) is not read by the 3D packs (no reference to it in `G/styles/` or `G/core/`).

The same by style. In this table `pack.gd`, `style.json` and `look.gd` are each column's own, under `G/styles/<style>/`; the other references are those given above.

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Pack | `Pack3D` (`pack.gd:4`) | `LitPack` (`pack.gd:6`) | `Pack3D`, toon (`pack.gd:7`) | `LitPack` (`pack.gd:6`) | `Pack3D` (`pack.gd:4`) |
| Lamp colour | `Color(1.0, 0.85, 0.55)` | palette `lamp_glow` `#FFC470` (`style.json:44`) | `Color(1.0, 0.85, 0.55)` | palette `lamp_glow` `#FFE0A0` (`style.json:44`) | `Color(1.0, 0.85, 0.55)` |
| Lamp energy when lit | 2.4 (the default, `pack_3d.gd:2051`) | 3.6 (`style.json:522`) | 2.4 | 4.0 (`style.json:505`) | 2.4 |
| Lamp reach | 8 m | 12 m (`style.json:527`) | 8 m | 12 m (`style.json:508`) | 8 m |
| Lamp shadows | not set (the engine's default, off: *inferred*) | off | not set | off | not set |
| Fades with distance | no | from 160 m (`style.json:499`) | no | from 80 m (`style.json:506`) | no |
| Lit | 18:30 to 06:30 (`style.json:361-362`) | 18:00 to 06:40 (`style.json:384-385`) | 18:30 to 06:30 (`style.json:373-374`) | 18:30 to 06:30 (`style.json:387-388`) | 18:30 to 06:30 (`style.json:355-356`) |
| `lamp_glow` strength, lit and unlit | 2.5 (the default, `pack_3d.gd:2057`) and 0.35 | 1.1 (`style.json:523`) and 0.35 | 2.5 and 0.35 | 1.4 (`style.json:507`) and 0.35 | 2.5 and 0.35 |
| Glow pass | always on, threshold 1.1 (`pack_3d.gd:1048-1052`) | only while lit (`style.json:538`, `pack_3d.gd:2049-2050`), threshold 1.0 (`look.gd:17-22`) | only while lit (`style.json:463`), threshold 1.2 (`look.gd:26-30`) | only while lit (`style.json:515`), threshold 1.05 (`look.gd:17-21`) | always on, threshold 1.1 |
| Streak on wet ground | none | yes, `#FFC470` (`style.json:497`) | yes, `#FFE3A6` (`style.json:460`, `:29`) | yes, `#FFE0A0` (`style.json:484`) | none |
| The kit's lantern glass | box 0.22 by 0.38 by 0.22 m, 3.51 to 3.89 m | sphere 0.44 m across, 3.78 to 4.22 m | four-sided, 0.17 widening to 0.28 m, 3.54 to 3.96 m | twelve-sided, 0.24 widening to 0.28 m, 3.48 to 3.88 m | panes 0.6 by 0.5 by 0.6 m, 3.70 to 4.20 m |
| Its emission after import | `#FFD27A`, strength 3 | `#FFC470`, strength 3.2 | `#FFE3A6`, strength 3 | `#FFE0A0`, strength 3 | `#FFE3A0`, no strength (1) |

In every kit the lantern glass is its own mesh part, `light`, with one material, `lamp_glow`: opaque, no texture, no vertex colours, base colour equal to the emission colour, roughness 0.85 (0.4 in voxel), double-sided in the four Blender kits. The cached imports show `emission_enabled` true, `emission` the colours above and `emission_energy_multiplier` 3.0 or 3.2; the voxel file gives `emissiveFactor` only, so the multiplier stays at the engine's 1.

### What else is looked up or changed by name

- **Names never looked up on a lamp.** `lights` is searched across the whole world, but only by the lit packs and only for a piece whose scene file or parent node is named in the style's `glow_lights` (`lit_pack.gd:93-105`; only neon has the key, `["tree_banyan"]`, `G/styles/neon_noir/style.json:528`). `display`, `screen` and `terminal_mount` are looked up only on displays, workstations and desks (`pack_3d.gd:671`, `:1212-1213`, `:1174`).
- **No metadata is read from the file.** Every `get_meta` in the 3D packs reads a key the game itself set.
- **Material names that have an effect, in any piece** (so they must be avoided unless meant):
  - beginning `glass`: emission is switched on in the palette's `glass_glow` and driven as window glass (`kit_town.gd:169-173`, `pack_3d.gd:2058-2062`);
  - beginning `neon`: lit as neon tube in the lit packs (`kit_town.gd:176-177`, `lit_pack.gd:229-237`);
  - beginning `paving`, `asphalt`, `kerb`, `road`, `path` or `street`: in a style with `wet_ground` (anime, neon, solarpunk) rain turns the material glossy and 30% darker (`pack_3d.gd:115`, `:2174-2183`). A material called `street_lamp` would be treated as wet ground.
- **Anime.** `Toon.apply` runs over the whole world after the placements (`pack_3d.gd:220`, `G/styles/anime_cel/pack.gd:44-45`). A material whose resource path contains `anime_cel/` is converted in place: toon diffuse and specular, roughness set to 0.32, rim on (`G/styles/anime_cel/toon.gd:79-84`, `:93-113`); emission is left as it is, so the lamp material stays the one the clock drives. The ink pass draws a line where the depth steps by 6% of the distance or where neighbouring normals differ by more than 1 − cosine = 0.35, fading between 60 and 140 m (`G/styles/anime_cel/shaders/lines.gdshader:12-16`, `:45-46`). It reads the screen's normal buffer, so a relief map on a piece feeds the lines (*inferred* from the buffer it samples, `:9`).
- **Lit packs.** `LitPack._style_node` touches only leaf cards and the glazing of hall and library pieces (`lit_pack.gd:47-59`).
- **First person.** The crosshair aims at a box made from the catalogue's footprint and height, 40 by 40 cm up to 3.5 m for a lamp, not at the mesh (`G/core/interact.gd:116-128`, `:328-330`).
- **After import.** The cached imports show the scene's root is a `Node3D` named `lamp_post2` (voxel: `lamp2`), holding a `Node3D` `lamp_post` (the GLB's root), holding the mesh instances `body` and `light`. The engine keeps node names unique within a file.

### What stands with it

Nothing is hung on or attached to a lamp post by the game. The banner on the low-poly lamp is part of the kit file: an arm at 2.92 m reaching x = +0.5 and a banner 0.38 by 0.84 m between 2.05 and 2.89 m, in the materials `jackfruit`, `jackfruit_dark` and `leaf_dark` (`T/lowpoly/props.py:110-116`). The game adds the lamp at the lantern and, in rain, the streak on the ground.

### What the tests require beyond the spec

These kit tests apply to every kit piece, so to all four pieces of this family.

| Kit | Spec (size within 10% + 2 cm an axis, triangles, nodes) | Every GLB has a spec | Validator: no error and no warning | Committed file equals a fresh build, byte for byte | Other |
| --- | --- | --- | --- | --- | --- |
| lowpoly | `T/lowpoly/test_assets.py:218-232` | `:234-237` | `:239-241`, `T/lowpoly/validate.sh:21` | none | `railing` and `railing-post` must be mapped in `style.json` (`T/lowpoly/test_assets.py:198-208`) |
| neon, solarpunk | `T/shared/kittests.py:92-107` | `:109-112` | `:122-126`, `:60` | `:128-144` | |
| anime | `T/anime/test_assets.py:65-80` | `:82-85` | `:95-99` | `:101-116` | |
| voxel | `T/voxel/test_assets.py:215-230` | `:232-234` | `:249-251` | `:236-247` | no part may carry the file's name (`:226-229`); every GLB has an import sidecar with `meshes/generate_lods=false` (`:253-257`); every material on the lamp's `light` node has a non-zero `emissiveFactor` (`:265-270`) |

A file copied over a kit file fails the byte-for-byte test by design. The size is the box round every mesh in the file, the lantern included (`T/lowpoly/test_assets.py:64-97`).

Client tests that touch a lamp:

- **The collision audit, held to zero in every style** (`G/tests/test_collision_audit.gd:23-45`, `G/evidence/placement-budget.json`). It reads what every placement draws between 0.25 and 1.9 m above the ground drawn under it (`G/tools/collision_audit/audit.gd:52`, `G/tools/collision_audit/solids_3d.gd:226-289`) and counts walkable cells whose centre is inside it or within 10 cm of it (`audit.gd:386-399`), and blocked cells inside a room with nothing drawn within 10 cm (`audit.gd:406-446`). The core blocks a cell whose centre is less than the footprint's radius plus 10 cm from the lamp's point (`city/crates/city-core/src/footprint.rs:437-442`, `:12`). *Computed* for this layout: every lamp blocks the same four cells, their centres 17.0 to 18.4 cm from its point on the diagonals; the nearest centre it leaves unblocked is 38.9 cm away. So between 0.25 and 1.9 m a lamp must reach more than 8.4 cm from its point toward each of those four centres, whichever of the eight facings it stands at, and nothing may reach past 28.9 cm. The four Blender kits do it with a plinth that tapers past 0.25 m: what they draw in that band reaches 17.2 cm (low-poly), 13.1 (neon), 16.4 (anime) and 15.0 (solarpunk), while their poles above about 0.6 m are only 5 to 8.5 cm in radius. Voxel's post is 0.2 m square all the way up. The same measure, taken once for all styles, is in `G/evidence/placement-kind-sizes.json` (`street-lamp`: 15 to 20 cm).
- **Anime**: every lamp must stand higher than 1.5 m (`G/tests/test_anime_pack.gd:270-275`), and no scene may be missing (`:140-143`).
- **Neon**: more than 10 lamps, none casting a shadow, all fading with distance (`G/tests/test_neon_pack.gd:21-27`); a lamp below 1.5 m must be dimmer than half of a lamp at 3.0 m or higher and reach no more than 4 m (`:84-91`), so the lamp posts' lamps must stay at 3.0 m or above for the test to have its "high" lamps.
- **Neon, off by day**: every lamp invisible at noon and visible at 22:00 (`G/tests/test_frame_cost.gd:19-24`).
- **Lit packs**: no material in the world may be toon (`G/tests/lit_pack_suite.gd:34-47`).

### Finding it, and where it shows

- The placement's node is the scene instance itself, so `placement_nodes[id]` has `scene_file_path` ending `lamp_post.glb` (`G/styles/style_pack.gd:228-230`; the pilot's capture tool reads exactly that, `W/work/asset_views.gd:86-91`).
- `lamp_post` matches only `lamp_post.glb` in the four styles (`pendant_lamp.glb` does not contain it). In voxel use `=lamp.glb`: as a plain needle `lamp.glb` would also match `pendant_lamp.glb` in the other styles, though voxel has no such file.
- The piece capture tool shoots at tick 150, or 370 in neon (`W/work/asset_views.gd:64-65`): 13:00 and 21:48, the clock starting at 07:00 with 2.4 minutes a tick (`city/fixtures/district/manifest.json:8096-8099`, `city/crates/city-core/src/project.rs:139-143`). At 13:00 the lamps are unlit in four styles: the glass shows at strength 0.35 and there is no lamp.

The views below are *computed* from the cameras' numbers (`G/core/orbit_rig.gd:68-93`, `:175-190`; `G/tools/sheet_views.gd:83-101`) and the layout, for a 16:9 frame. They say what falls inside the frame, not what is hidden behind something.

| View | Lamps in frame | Nearest |
| --- | --- | --- |
| `topdown` | 26 of 28 | about 138 m, 11 to 13 px tall at 1080 lines |
| `diagonal` | 19 | from 39 m, about 75 px |
| `street` | 14 | `plaza-lamp-6` at 6.3 m, about 710 px tall; the next at 24 m, 180 px |
| sheet view `park` | 6 | 45 m |
| sheet view `tram-board` | 5 | `plaza-lamp-6` at 15.8 m |

The sheet views `gathering` and `night-rain` are the `street` view at ticks 285 and 330, 18:24 and 20:12 (`G/tools/sheet_views.gd:91-96`). At 18:24 only neon's lamps are on. At 20:12 all are, and it rains (the layout's rain runs from 19:00 to 21:30, `city/fixtures/district/manifest.json:8452-8460`), so the streaks show in anime, neon and solarpunk.

*Seen*: in low-poly's and voxel's `street.png`, `plaza-lamp-6` stands right of centre, about 700 px tall (low-poly's with its banner to its right); in anime's and solarpunk's `night-rain.png` that lamp is lit and a streak lies on the wet paving under it; in neon's `street.png` its globe is lit and the paving round it is lit warm.

## 1. Bollard (`bollard`)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/bollard.glb` | `assets/bollard.glb` | `assets/bollard.glb` | `assets/bollard.glb` | `assets/v2/bollard.glb` |
| Spec file and key | `T/lowpoly/specs/props.json:4` `bollard` | `T/neon/specs/props.json:3` `bollard` | `T/anime/specs/props.json:3` `bollard` | `T/solarpunk/specs/props.json:3` `bollard` | `T/voxel/specs/props.json:3` `bollard` |
| Spec size x, y, z (m) | 0.24, 0.9, 0.24 | 0.24, 0.9, 0.23 | 0.24, 0.90, 0.23 | 0.24, 0.90, 0.24 | 0.2, 0.8, 0.2 |
| Triangle limit | 1500 | 1500 | 1500 | 1500 | 50 |
| Spec nodes | `bollard`, `body` | `bollard`, `body`, `light` | `bollard`, `body` | `bollard`, `body` | `post` |
| Parts in the GLB | root `bollard`; mesh `body` | root `bollard`; meshes `body`, `light` (moved to y = 0.755) | root `bollard`; mesh `body` | root `bollard`; mesh `body` | root `bollard`; mesh `post` |
| Size of the GLB (m) | 0.240 by 0.902 by 0.240 | 0.240 by 0.900 by 0.230 | 0.240 by 0.898 by 0.234 | 0.240 by 0.899 by 0.240 | 0.200 by 0.800 by 0.200 |
| Triangles | 152 | 204 (192 + 12) | 278 | 380 | 28 |
| Materials | `iron`, `steel` | body: `baked_r75_m0`, `baked_r50_m0`; light: `lamp_glow` | `baked_r75_m0` | `baked_r25_m75`, `baked_r50_m0`, `lamp_glow` (all in `body`) | `charcoal`, `kerb` |
| Textures, vertex colours | none, none | none, on `body` | none, on `body` | none, on `body` (the glowing band too) | none, none |
| Shape | round, 8 sides | square, 0.17 m post, 0.20 m cap | round, 14 sides | round, 16 sides | square, 0.2 m |
| How placed | one scene instance a placement, facing 0 | same | same | same | same |
| Scaled by the game | no | no | no | no | no |
| Found as a scene instance | yes | yes | yes | yes | yes |
| Needle | `bollard` | `bollard` | `bollard` | `bollard` | `bollard` |

Builders: `T/lowpoly/props.py:87-95`, `T/neon/props.py:71-85`, `T/anime/props.py:93-102`, `T/solarpunk/props.py:80-90`, `T/voxel/props.py:217-224`.

### Where it stands and how it is drawn

- `style.json` maps the kind `bollard` to the file with `scene` only (`lowpoly_tropical/style.json:201-203`, `neon_noir/style.json:225-227`, `anime_cel/style.json:215-217`, `solarpunk/style.json:225-227`, `voxel/style.json:197-199`), so it is drawn exactly as the lamp post is: an instance at the placement's point, turned to its facing, at the file's own size (`pack_3d.gd:400-428`).
- The kind's footprint is a disc of 15 cm radius, its height 90 cm (`catalogue.json:134-144`).
- The district has eight, along the square's south edge at z = 13.25 m, x = −15, −12, −9, −3, 3, 9, 12 and 15 m, none with a facing, so all at 0 (`generate.py:396-399`, `:416-417`).

### What is looked up in it or done to it

- **Neon is the one style whose bollard is lit.** Its spec names a `light` part, so the game gives it a lamp at 0.755 m (`pack_3d.gd:767-777`), which the lit pack dims to 0.3 of the energy (1.08) and cuts to 3.5 m reach because it is below 1.5 m (`lit_pack.gd:113-115`). Its lit band is the `light` part in `lamp_glow`.
- **Solarpunk's bollard glows without a lamp.** Its band is a `lamp_glow` surface inside `body`, with no `light` part: "it glows at night; no OmniLight" (`T/solarpunk/props.py:23-24`).
- **A `light` part would be wrong in the other three.** In anime it fails the test that every lamp is above 1.5 m (`test_anime_pack.gd:270-275`). In low-poly and voxel, which have no rule for low lamps, it would get a full lamp of 8 m reach and energy 2.4 at knee height (`pack_3d.gd:771-774`, `:2051-2053`).
- The material names with effects, the toon conversion in anime, and the first-person aim box (30 by 30 cm, 0.9 m high) are as for the lamp post.
- Cached imports: root `bollard2` holding `bollard` holding `body` (and `light` in neon).

### What stands with it

Nothing.

### What the tests require beyond the spec

- The kit tests in the lamp post's table.
- The collision audit, as for the lamp post, with the 15 cm disc: the same four blocked cells and the same distances (*computed*), so between 0.25 and 0.9 m a bollard must reach more than 8.4 cm from its point and nothing may reach past 28.9 cm. The kits' reach in the band: 10.5 cm (low-poly), a 10 cm half-width square (neon's cap; its post is 8.5), 10.5 (anime), 10.0 (solarpunk), a 10 cm half-width square (voxel).
- Neon's test of low lamps needs at least one lamp below 1.5 m in the district (`test_neon_pack.gd:84-91`); the bollards' are among them (the neon planters carry a `light` part too).

### Finding it, and where it shows

- A scene instance in `placement_nodes`, as the lamp post. `bollard` is in no other file's name in any of the five styles.
- All eight stand at one facing, so the capture tool's "one per facing" picks one and then others elsewhere (`W/work/asset_views.gd:105-117`).
- Views, *computed* as above: all eight in `topdown` (about 1 px tall) and `diagonal` (from 58 m, about 15 px); in `street` only `plaza-bollard-04`, 3.3 m from the camera, its top in the frame and its foot below it; five in the sheet view `tram-board`, the nearest at 12.6 m (66 px).
- *Seen*: that one bollard stands at the bottom centre of the frame, its foot out of it, in the five captures looked at (low-poly's, neon's and voxel's `street.png`, anime's and solarpunk's `night-rain.png`). It is dark in anime's; its band is lit in neon's and in solarpunk's.

## 2. Catenary pole (`catenary-pole`)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | none | none | none | none | none |
| Spec | none | none | none | none | none |
| `style.json` entry | `{"pole": "iron"}` (`style.json:213-215`) | `{"pole": "iron"}` (`style.json:237-239`) | `{"pole": "iron"}` (`style.json:227-229`) | `{"pole": "iron"}` (`style.json:237-239`) | `{"pole": "rail", "square": true}` (`style.json:209-212`) |
| Mast | 8 sides, radius 0.12 m, 6 m high | same | same | same | square, 0.2 m, 6 m high |
| Arm | box 2.0 by 0.1 by 0.1 m, its middle 5.8 m up, toward the nearest track | same | same | same | same |
| Colour | palette `iron` `#3B3A3C` (`style.json:30`) | palette `iron` `#1E2026` (`style.json:39`) | palette `iron` `#33343D` (`style.json:24`) | palette `iron` `#3A3B3D` (`style.json:39`) | palette `rail` `#56585D` (`style.json:30`) |
| Material | made in code, roughness 0.6, no name | same | same, swapped for a toon copy | same | same |
| Wire | box 3 by 3 cm at 5.7 m along each track | same code | same code | same code | not drawn |
| Triangles | not from a file | | | | |
| How placed | built at each `catenary-pole` placement | same | same | same | same |
| Found as a scene instance | no | no | no | no | no |
| Needle | none possible | none | none | none | none |

In this table `style.json` is each column's own, under `G/styles/<style>/`.

### How the game draws it

- **The pole is built in code.** `_placement` sends any entry with a `pole` key to `_pole` before it looks for a scene (`pack_3d.gd:407-408`). `_pole` (`:784-799`) takes the colour from the style's palette under the entry's `pole` name (`:786`), makes a material of roughness 0.6 (`:787`), reads `height` (6.0 unless given, `:788`), and adds a box of 0.2 m for `square` or else an 8-sided cylinder of radius 0.12 m (`:789-792`). It then asks which way the nearest track lies (`CityGeometry.toward_track`, `G/core/city_geometry.gd:389-401`) and adds an arm of `arm` metres (2.0 unless given), 0.1 by 0.1 m, centred 0.2 m below the top (`pack_3d.gd:793-798`). No style gives `height` or `arm`.
- **The node** is `MeshBatch.build("CatenaryPole")`: a `Node3D` holding one `MeshInstance3D` with a `material_override` (`G/core/mesh_batch.gd:171-181`). Its vertices are in world space and the node sits at the world's origin (`pack_3d.gd:790-798`). It is tagged with its placement ID like any placement (`:298-300`), so it is in `placement_nodes`, with an empty `scene_file_path`.
- **The wire is built with the track.** The low-poly townscape's `tram_line` adds, for each straight of a track, a box as long as the straight and 3 by 3 cm, at y = 5.7 m on the track's centre line, in the palette's `iron`, in a node named `Catenary` under the track's node: "its poles are the layout's catenary-pole placements, their arms reaching out over it" (`G/styles/lowpoly_tropical/townscape.gd:296-318`, the wire at `:312-317`). Anime uses that code unchanged (`G/styles/anime_cel/townscape.gd:6`), and the lit packs use anime's (`G/styles/lit/townscape.gd:6`, `lit_pack.gd:28-29`).
- **Voxel draws poles and no wire.** Its `tram_line` only tiles the track piece (`G/styles/voxel/townscape.gd:311-327`).
- **The track piece holds neither.** `tram_track.glb` is one mesh, `track`, 12 to 30 cm high, tiled every 2 m (`G/styles/lowpoly_tropical/townscape.gd:307-316`; spec `tram_track` in `T/lowpoly/specs/scenery.json`, 2.0 by 0.12 by 2.8 m). No GLB in any of the five kits has a node, mesh or material whose name contains `caten`, `pole`, `wire`, `mast` or `pantograph`.
- **Where.** Twelve placements, none with a facing: "a pole every 14 m along each track, 2 m out from it ... the eastbound's to the north and the westbound's to the south" (`generate.py:765-785`). Six at z = 17.0 m and six at z = 24.0 m; the tracks' centre lines are at z = 19.0 and 22.0 m (line at z = 20.5, tracks at −150 and +150 cm, `manifest.json:8100-8147`; `city_geometry.gd:480-513`). So each 2 m arm ends over its track's centre line, its underside at 5.75 m; the wire's top is at 5.715 m. Nothing joins arm and wire.
- The kind's footprint is a disc of 15 cm radius and its height 600 cm (`catalogue.json:173-183`). The audit reads the built pole like any placement; its radius of 12 cm (or the 0.2 m square) passes.
- In anime the pole's material, made at run time and shared with other styles, is swapped for a toon copy (`toon.gd:85-90`).

### What a file-based pole would meet

- An entry with `scene` in place of `pole` would be drawn by the ordinary path: an instance at the placement's point turned to the placement's facing (`pack_3d.gd:419-422`). All twelve facings are 0, so every arm would point the same way; the turn toward the track exists only in `_pole` (`:793-797`).
- There is no spec, so the kit tests would fail a new `catenary_pole.glb` until one is written (`kittests.py:109-112` and the same test in the other kits).
- Both are changes to the checkout's code or data, not a file copied over a kit file.
- Room to leave beside the track: a tram is drawn 2.5 m wide in the walking band, centred on its track (`G/styles/kit_town.gd:377-382`), so its side passes 0.75 m from a pole's axis; the kits' trams are 4.39 to 4.50 m high (spec `tram` in each kit's `specs/scenery.json`), under the arm at 5.75 m.

### Views

*Computed* as above: all twelve in `topdown`, nine in `diagonal` (from 37 m, about 115 px), none in `street` (the camera stands at z = 16.7 m looking north, with the poles and both wires level with it or behind it), four in the sheet view `tram-board` (`sheet_views.gd:338`), the nearest 2.8 m from the camera with only its foot in frame and the next at 16 m. The tram captures (`sheet_views.gd:310-349`) are the views made for the line.

*Seen*: low-poly's `diagonal.png` shows the poles, their arms and a thin wire over each track; voxel's `diagonal.png` shows the poles and their arms and no wire.

## 3. Railing (`railing`) and its post

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Panel file | `assets/railing.glb` | `assets/railing.glb` | `assets/railing.glb` | `assets/railing.glb` | `assets/v2/railing.glb` |
| Panel spec file and key | `T/lowpoly/specs/props.json:21` `railing` | `T/neon/specs/scenery.json:16` `railing` | `T/anime/specs/scenery.json:16` `railing` | `T/solarpunk/specs/scenery.json:16` `railing` | `T/voxel/specs/props.json:4` `railing` |
| Panel spec size x, y, z (m) | 2.0, 1.1, 0.14 | 2.0, 1.12, 0.14 | 2.0, 1.12, 0.14 | 2.00, 1.12, 0.16 | 2.0, 1.1, 0.2 |
| Panel triangle limit | 900 | 1000 | 1000 | 1000 | 400 |
| Panel spec nodes | `railing`, `body` | `railing`, `body` | `railing`, `body` | `railing`, `body` | `rail` |
| Panel GLB | root `railing`; one mesh `body`; 328 triangles; 2.000 by 1.134 by 0.140 | root `railing`; one mesh `body`; 336; 2.000 by 1.122 by 0.140 | root `railing`; one mesh `body`; 336; 2.000 by 1.122 by 0.140 | root `railing`; one mesh `body`; 272; 2.000 by 1.120 by 0.160 | root `railing`; one mesh `rail`; 112; 2.000 by 1.100 by 0.200 |
| Panel materials | `stone`, `teal_dark`, `teal`, `iron` | `baked_r75_m0`, `baked_r25_m75` | `baked_r75_m0` | `baked_r75_m0`, `baked_r25_m75` | `charcoal`, `kerb`, `white`, `yellow` |
| Textures, vertex colours | none, none | none, yes | none, yes | none, yes | none, none |
| The panel's own post | at x = −0.93, footing from −1.00 to −0.86 | at x = −0.93, plate from −1.00 to −0.86 | at x = −0.93, plate from −1.00 to −0.86 | at x = −0.92, plinth from −1.00 to −0.84 | from x = −1.0 to −0.8 |
| Half depth between 0.15 and 2.2 m | 0.060 | 0.050 | 0.050 | 0.075 | 0.100 |
| Post file | `assets/railing_post.glb` | `assets/railing_post.glb` | `assets/railing_post.glb` | `assets/railing_post.glb` | `assets/v2/railing_post.glb` |
| Post spec file and key | `T/lowpoly/specs/props.json:22` `railing_post` | `T/neon/specs/scenery.json:17` `railing_post` | `T/anime/specs/scenery.json:17` `railing_post` | `T/solarpunk/specs/scenery.json:17` `railing_post` | `T/voxel/specs/props.json:5` `railing_post` |
| Post spec size, limit, nodes | 0.14, 1.12, 0.14; 300; `railing_post`, `body` | 0.14, 1.12, 0.14; 1000; `railing_post`, `body` | 0.14, 1.12, 0.14; 1000; `railing_post`, `body` | 0.16, 1.12, 0.16; 1000; `railing_post`, `body` | 0.2, 1.1, 0.2; 60; `post` |
| Post GLB | one mesh `body`; 120 triangles; 0.140 by 1.134 by 0.140; `stone`, `teal_dark` | one mesh `body`; 212; 0.140 by 1.122 by 0.140; `baked_r75_m0` | one mesh `body`; 212; 0.140 by 1.122 by 0.140; `baked_r75_m0` | one mesh `body`; 176; 0.160 by 1.120 by 0.160; `baked_r75_m0`, `baked_r25_m75` | one mesh `post`; 28; 0.200 by 1.100 by 0.200; `kerb`, `white`, `yellow` |
| How placed | instances of one mesh in MultiMeshes, along the layout's fences | same | same | same | same |
| Scaled by the game | panel: by its run's length over 2 m; post: no | same | same | same | same |
| Found as a scene instance | no | no | no | no | no |
| Needle | none works | none | none | none | none |

Builders: `T/lowpoly/props.py:449-482`, `T/anime/scenery.py:756-789`, `T/neon/scenery.py:152-158` and `:176-177` (the anime panel with its handrail recoloured, and the anime post), `T/solarpunk/scenery.py:133-165`, `T/voxel/props.py:227-257`. Each says the same of the panel: it runs along x from −1 to 1 with "a post at the -x end (the next module's post, or a `railing_post`, closes the +x end)".

### Where railings stand

- `railing` and `railing-post` are not catalogue kinds and no placement has them. They are two extra `props` keys in each `style.json` (`lowpoly_tropical/style.json:313-318`, `neon_noir/style.json:336-341`, `anime_cel/style.json:325-330`, `solarpunk/style.json:339-344`, `voxel/style.json:307-312`) that `Pack3D._fence` reads (`pack_3d.gd:2578-2579`).
- A fence is a scenery item of kind `fence`, a line of points (`style_pack.gd:185-197`, `pack_3d.gd:2539-2555`). The district has three: "Railings wherever the ground ends: round the land (open where the bridge meets the quay, and where the tracks leave at the east edge) and across the bridge's far end" (`generate.py:569-583`; `manifest.json:8395`, `:8416`, `:8437`).

### How panels and posts are laid along a run

1. **Modules.** `CityGeometry.fence(pts, 2.0)` gives each straight run a whole number of modules, `max(1, round(run / 2))`, each `run / n` long, with its centre and the run's direction, and a post position at each end of a line that is not closed (`G/core/city_geometry.gd:352-367`). A panel's own post stands at its start, "so corners need nothing more".
2. **Depth.** `_fence` measures both pieces between 0.15 and 2.2 m (`town.band_box`, `kit_town.gd:214`, `:224-229`) and takes `depth` as the larger half depth of the two, measured from z = 0 (`pack_3d.gd:2580-2583`).
3. **Panels.** Each module is turned so that its +x runs along the run (`pack_3d.gd:2590`), scaled by `length / 2.0` on x, moved off the floor by `depth` + 1 cm toward the side no room covers (`:2587-2589`, `:2608`, `:2613-2619`) and set at the bridge deck's height there (`:2591`).
4. **End posts.** Each stands at the end point, moved off the floor like the panel beside it and `depth` + 1 cm inward along the run, not turned and not scaled (`pack_3d.gd:2594-2599`).
5. **Drawing.** Panels and posts become `town.tiles(rail, rails, "Railing", true)` and `town.tiles(post, posts, "Posts", true)`: MultiMeshes with shadows on, split into chunks of 32 m (`pack_3d.gd:2600-2603`, `kit_town.gd:97`, `:107-152`). The node holding them is named `Scenery_fence`, carries meta `scenery` = `fence` and is kept in `scenery_nodes`, not `placement_nodes` (`style_pack.gd:191-197`, `pack_3d.gd:2554`).

What follows from that:

- **Only the first mesh in the file is drawn.** `KitTown.mesh_of` instantiates the scene and keeps `mi[0].mesh`, the first `MeshInstance3D` in tree order (`kit_town.gd:81-91`). A second mesh in `railing.glb` would not be drawn. Its materials would still be collected (`:88-89`) and it would still count in the depth measure (`:262-281`).
- **Transforms on the file's nodes are ignored when drawing.** The MultiMesh draws the mesh's own vertices under each instance's transform (`kit_town.gd:128-136`); the depth measure does apply them (`:271-275`). The kits' nodes carry none.
- **A panel is taken to be 2 m long, centred on its origin.** Modules are spaced `run / n` apart and scaled by `run / n / 2`. In this district (*computed*) there are 226 modules, of lengths 1.976, 1.989, 2.000 and 2.038 m, and 6 posts.
- **The stretch goes across the panel on north-south runs.** `Basis.scaled` scales along the parent's axes, not the piece's own (Godot's class reference; `pack_3d.gd:2590` uses `scaled`, where the streets use `scaled_local`, `G/styles/lowpoly_tropical/townscape.gd:266`). On an east-west run the factor stretches the panel's length; on a north-south run it scales the thickness instead and the panel stays 2.0 m long. Here the east-west runs are 112 m in 56 modules, factor exactly 1, and the factors 0.988, 0.994 and 1.019 fall on north-south runs (*computed*). Read from the code and the class reference; not seen in a capture.
- **Which face of a panel is toward the floor differs from fence to fence.** The panel's +z lies along `across` (`pack_3d.gd:2590`, `:2614`), and the floor may be on either side of the run (`:2615-2619`). *Computed* for this district: +z faces the floor on the two fences round the land (224 panels) and −z on the one across the bridge's far end (2 panels).
- **The end post at a fence's start stands on the first panel's own post.** The panel's post is 7 to 10 cm inside the run's start; the end post is `depth` + 1 cm inside it: 7, 6, 6, 8.5 and 11 cm in the five styles (*computed* from the figures above). The post at the far end closes the last panel.
- **End posts are not turned** (`Basis()`, `pack_3d.gd:2599`): a post that is not the same from all four sides faces one way in every fence.

### What is looked up in it or done to it

- No node or part is looked up by name: the mesh is found by type and order (`kit_town.gd:84-87`).
- Materials are collected by name as for any piece (`kit_town.gd:88-89`, `:157-177`), and the names with effects listed for the lamp post apply. The voxel kit's `kerb` material would be wetted by rain if voxel had `wet_ground`; it does not.
- In anime the MultiMesh's mesh materials are converted to toon in place (`toon.gd:40-54`).
- Cached imports: root `railing2` holding `railing` holding `body` (voxel: `rail`); root `railing_post2` holding `railing_post` holding `body` (voxel: `post`).

### What stands with it

The end posts. Nothing else is attached or laid along a fence.

### What the tests require beyond the spec

- The kit tests in the lamp post's table. In low-poly, `railing` and `railing-post` must stay mapped in `style.json` (`T/lowpoly/test_assets.py:198-208`).
- **Every pack**: each fence in the layout is drawn, each with at least two pieces, more than 100 pieces in all (`G/tests/test_pack_contract.gd:132-147`).
- **Anime**: every panel's two faces across the run, at the middle of its length, and every end post's four corners, as measured between 0.15 and 2.2 m, must stand off every room's floor, and the nearest of them within 2 cm of it (`G/tests/test_anime_pack.gd:212-243`). With the offset of `depth` + 1 cm this holds only if the panel's two faces are equally far from z = 0, to within a centimetre, and the post is as deep as the panel.
- The collision audit reads fences as scenery (`solids_3d.gd:221-222`); they stand outside the floor.

### Finding it, and where it shows

- Neither piece can be found as a scene instance: its instances are entries of a MultiMesh under a scenery node. The pilot's capture tool looks only at `placement_nodes` and says of such pieces that they "have no scene of their own and are not found" (`W/work/asset_views.gd:33-34`, `:86-91`); `build.py` leaves out an asset with no needle (`W/work/build.py:274-286`).
- They can be reached through `scenery_nodes`: the nodes with meta `scenery` = `fence`, their children named `Railing...` and `Posts...`, and each MultiMesh's meta `instance_xforms` (`kit_town.gd:146-148`), as the anime test does (`test_anime_pack.gd:220-225`).
- If a tool did match by file name: `railing` matches both `railing.glb` and `railing_post.glb`; `=railing.glb` and `railing_post` tell them apart.
- Views, *computed* as above, by panel: 170 of 226 in `topdown` (141 m and more), 92 in `diagonal` (42 m and more), 81 in `street` (56 m and more). The sheet view `park` (`G/tools/sheet_views.gd:86`) is the close one: its eye stands 2.5 m from the west fence, with 78 panels in frame, the nearest 3.6 m away. *Seen*: low-poly's and voxel's `park.png` have the railing across the lower left of the frame, a post every 2 m, ending at the bridge.
- The client's audit captures have two orbit views made for the railing, run there in low-poly and voxel only: `edge`, the rig at (8.0, 0.8, −63.0) with yaw 180, pitch −30 and distance 16, and `quay`, the rig at (−43.0, 0.8, −8.0) with yaw 250, pitch −28 and distance 16 (`G/tools/audit.gd:92-110`).

## What a generated replacement must keep or put back by rule

### Every piece

1. **Names.** The root node carries the spec's first name and the mesh parts the others: `lamp_post` with `body` and `light`; `bollard` with `body` (and `light` in neon); `railing` with `body`; `railing_post` with `body`. In voxel the root is the file's name and the parts are `post` and `light` (lamp), `post` (bollard), `rail` (railing), `post` (railing post), and no part may carry the file's name. Node names must be unique within the file.
2. **Frame.** y up, front toward −Z, metres, standing on y = 0. The origin is the point the layout places: the post's axis for a lamp and a bollard, the middle of the panel's length for a railing.
3. **Material names.** A lit surface is named exactly `lamp_glow` and each name is used once: a second copy becomes `lamp_glow.001`, which the game does not know. No material name may begin with `glass`, `neon`, `paving`, `asphalt`, `kerb`, `road`, `path` or `street` unless that treatment is wanted.
4. **Emission is in the file.** A `lamp_glow` material needs an `emissiveFactor` above zero, as every kit piece of this family has, or an emission texture, as the pilot's trees have. The game sets its strength and nothing else.
5. **Size.** Lamp and bollard are drawn at the file's size. The kit tests want each axis within 10% + 2 cm of the spec, measured over every mesh in the file.
6. **Copying a file over a kit file** breaks the byte-for-byte test in neon, anime, solarpunk and voxel, and the file must pass the Khronos validator without a warning. In voxel the sidecar `.import` beside the file must keep `meshes/generate_lods=false`.
7. **Anime.** Materials turn toon in place, and the ink pass draws a line wherever neighbouring normals differ by more than about 49 degrees or the depth steps. A dense mesh needs smooth normals and no relief map to avoid a scribble of lines (*inferred* from the shader).

### Lamp post

1. **The post's axis on the origin.** The kit's low-poly box is off-centre (x from −0.24 to +0.50) because of its banner arm. A piece fitted into that box has its middle at x = +0.13 and misses its own footprint.
2. **A part named `light` that is a mesh**, at the lantern. The lamp goes to the middle of its bounding box: 3.68 to 4.00 m in the kits; the design sheet's lantern is at about 3.5 m. Keep it at 3.0 m or above (neon's test) and in any case above 1.5 m (anime's test). One per file: only the first is used.
3. **The lantern's glass in `lamp_glow` with emission.** In voxel every material on the `light` part must emit. The simplest form is the kits': the glass is the `light` part and its one material is `lamp_glow`.
4. **A foot that the audit can see.** Between 0.25 and 1.9 m above the ground the piece must reach more than 8.4 cm from the axis all round, and it should stay inside the 20 cm disc (the audit's own limit here is 28.9 cm). A foot at least 18 cm across that carries on to about 0.5 m does it, as the kits' plinths do; a post under 17 cm across with a base that ends below 0.25 m does not. The audit lifts its band by the height of any ground drawn under the piece, so a foot that stops just above 0.25 m is not safe.
5. **Nothing wider than the footprint inside that band.** An arm, a banner or a hanging lantern must stay above 1.9 m over the ground under the lamp; 2.2 m is a safe figure. The kit's low-poly banner starts at 2.02 m.
6. **The front.** −Z faces the street, or the great tree for the six lamps in the square. A lamp that is not the same all round is seen at eight facings.
7. **The spec's width is the kit's ornament.** x must be 0.65 to 0.84 m and z 0.43 to 0.57 m to meet the spec (0.52 to 0.68 m both ways in voxel); the kits reach that with a banner arm (low-poly), a cross-bar with ball ends (neon, anime), a solar canopy (solarpunk) and the lantern itself (voxel). A lamp that is only a post and a lantern is narrower. It then either misses the spec on x, or is stretched, or carries such a part put back by rule.
8. **The low-poly banner** is not added by the game. If the new lamp is to have one it must be on the piece.
9. **Height.** The sheet's 4.2 m is inside every spec: 3.78 to 4.64 m holds in all four Blender kits, 4.03 to 4.97 m in voxel.
10. **Voxel.** In the band the post must be two cells (0.2 m) square, or a wider base must rise past 0.25 m: a post one 0.1 m cell square leaves a blocked cell more than 10 cm from anything drawn (*computed*).

### Bollard

1. **Axis on the origin; inside the 15 cm disc; at least 17 cm across** somewhere between 0.25 m and its top (the audit's rule, as for the lamp). The sheet's 24 cm fits.
2. **Neon: a mesh part `light` in `lamp_glow`** for the lit band (the spec names it). It gets a dim lamp of 3.5 m reach.
3. **Solarpunk: the band as a `lamp_glow` surface with no `light` part**, as the kit has it.
4. **Low-poly, anime, voxel: no part named `light`.**
5. **Size.** 0.24 by 0.9 m meets the four specs. Voxel's spec is 0.2 by 0.8 by 0.2 m with limits of 0.16 to 0.24 and 0.70 to 0.90 m, so 0.24 across and 0.9 high sit exactly on the limits; on the kit's 0.1 m grid the piece is 0.2 by 0.8 or 0.9.

### Railing and railing post

1. **One mesh in each file**, with no transform on any node. Several materials on that mesh are fine.
2. **The panel is exactly 2.0 m long**, from x = −1 to x = +1, its origin at the middle of its length on the ground. The spec allows 1.78 to 2.22 m, but the game lays panels 2 m apart.
3. **Its own post at the −x end and nothing closing the +x end.** The rails must end at x = +1 so that the next panel's post takes them.
4. **The same on both sides of z = 0**, between 0.15 and 2.2 m, to within a centimetre, and thin: the kits' half depth is 5 to 10 cm, and the fence is moved out by that much plus 1 cm.
5. **`railing_post.glb` is the panel's own post**, centred on the origin, the same height and the same depth as the panel, and the same from all four sides. A post generated on its own would show as a second, different post beside the first panel's, and would face one way in every fence.
6. **Triangles count 226 times** for the panel, with shadows. The kits' panels are 112 to 336 triangles; their limits are 900 (low-poly), 1000 (neon, anime, solarpunk) and 400 (voxel).
7. **No lit parts are expected**: a `light` part in a railing gets no lamp, because fences are not placements.

### Catenary pole

1. Nothing can be copied in: there is no kit file and no spec. A generated pole needs a new kit piece with a spec, a `scene` entry in `style.json`, and either code that turns each pole toward its track or facings in the layout.
2. If one is made, the game's own pole gives its measures: 6.0 m high, an arm reaching 2.0 m to end over the track's centre line with its underside above the wire's 5.7 m, inside a 15 cm disc and at least 17 cm across between 0.25 and 1.9 m.
3. In voxel a wire would have to be added too, or the arm reaches over nothing.

### Where the pilot's tools stand against these rules

Read in `W/work/` as the files stood at 12:15 on 2026-10-02. That folder is being edited, so these line numbers may have moved since.

- **The entries.** `assets.json` has `lamp-post`, `bollard` and `railing` on sheet `A-street-fixtures` (objects 0, 1 and 3) with no `file` yet (`W/work/assets.json:557-577`), and nothing for the catenary pole. What this note gives for them:
  - lamp post: `file` `assets/lamp_post.glb`, `needle` `lamp_post`, `frame` `auto` (the frame for a tall piece, `W/work/asset_views.gd:21-23`); in voxel `file` `assets/v2/lamp.glb`, `needle` `=lamp.glb`, `mesh` `post`;
  - bollard: `file` `assets/bollard.glb`, `needle` `bollard`; in voxel `file` `assets/v2/bollard.glb`, `mesh` `post`;
  - railing: `file` `assets/railing.glb` and no needle; in voxel `file` `assets/v2/railing.glb`, `mesh` `rail`. `railing_post.glb` (`mesh` `post` in voxel) has no object on the sheet.
- **Names and lights.** The fitting tool names its mesh `body` (`W/work/fit_generated.py:806-807`) and the root after the kit's (`:259-261`). It can name the material `lamp_glow` and give it an emission texture (`--glow`, `:1356-1366`), split the glowing faces into a part of their own (`--glow-part light`, `:1371-1396`), or add a 12 mm cube named `light` (`--glow-light`, `:1598-1608`).
- **Neon's default carries the kit's lights the wrong way for a lamp.** The neon style's `"kit_lights": "lights"` (`W/work/assets.json:652`) makes every neon fit that is given the kit piece copy the kit's `light` part across under the name `lights` (`W/work/build.py:153-154`, `W/work/fit_generated.py:1406-1414`) and then move it to hang 4 mm under the first surface above 0.2 m that a ray cast up from the ground meets (`:1417-1436`). That suits a bench's strip. For the lamp post and the neon bollard it leaves no part named `light`, and it would move the lantern's glass down to the foot of the post (*inferred* from that code). An entry switches it off with `"kit_lights": null`, as the great tree's does (`W/work/assets.json:309`).
- **The kit's box.** `build.py` passes `--kit` unless the entry says `"kit": false` (`W/work/build.py:141-142`). With it the tool fills the kit's box on each axis, or with `--keep-aspect` scales evenly and centres in that box (`W/work/fit_generated.py:448-458`). Either way the piece's middle lands on the kit box's middle: 13 cm off the origin for the low-poly lamp, and a lamp is stretched to 0.74 by 0.5 m in plan when filled. `--size` gives a box centred on the origin (`:265-267`, passed from an entry's `size` at `W/work/build.py:143-144`).
- **Voxel.** The voxel step joins every part but `light`, `lights` and `canopy` (`W/work/voxelise.py:63`) and writes one mesh under the root, deleting every other object (`:399`, `:436-445`). As it stands a voxel lamp comes out with no `light` part: it misses its spec, gets no lamp, and the voxel test of the lamp's `light` cannot find the node.
- **The check.** `check.py` holds a piece to its spec's size and nodes and, for trees only, to a footprint (`W/work/check.py:31`, `:59-81`). It does not check the audit's rule for a lamp or a bollard, nor a railing's single mesh, length or symmetry.
- **Captures.** `build.py try` captures only pieces with a needle (`W/work/build.py:274-286`), so railings and posts are not captured by it.

## Not determined

- **Whether a generated file passes the Khronos validator.** It was not run; the kit tests fail on any warning.
- **The cost of denser pieces.** No bench was run. The counts are 28 lamps, 8 bollards, 226 panels and 6 posts.
- **How high the ground is drawn under each lamp** (a sidewalk, a platform), which lifts the audit's band there. The audit was not run.
- **The grid cells.** The blocked and walkable cells round each fixture were computed from the manifest with the core's rule, not read from a run of the core.
- **Occlusion in the views.** The view tables say what falls inside each camera's frame, not what is hidden behind buildings or trees.
- **How a generated piece looks**: under each style's light, with anime's ink on a dense mesh, or with an emission texture in each style's glow pass. Nothing was captured for this note; the captures looked at show the kits' own pieces.
- **Whether the north-south fence joints show.** The overlaps and gaps computed are 1.1 to 3.8 cm.
- **What the engine's automatic levels of detail do to a dense generated lamp or bollard** in the four styles whose sidecars have `meshes/generate_lods=true`.
- **The design sheet itself.** It was not looked at, so the proportions drawn for each object against each spec are not known.
- **How a catenary pole should be added**, if at all: that is a decision, and needs a change to the checkout.
