# Contract: street trees and palms (sheet `A-trees`, objects 0 to 3)

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

Read on 2026-10-02 from the checkout at `1ec8f61` (branch `docs/asset-to-sheet-pilot`; nothing under `city/` is changed in the working tree). Code, specs, tests and the kit GLBs were read. Nothing was run in Godot or Blender, and nothing in the checkout was written.

Paths are from `city/` unless they begin `docs/` or `work/` (`work/` is `.asset-pilot/2026-10-02-sheet-to-asset/work/`). A file is given in full where it is first cited and by its last parts after that: `pack_3d.gd`, `kit_town.gd`, `style_pack.gd`, `lit_pack.gd`, `toon.gd` and `<style>/pack.gd`, `<style>/style.json` are under `godot/styles/`; `<kit>/vegetation.py`, `<kit>/test_assets.py`, `foliage.py` and `kittests.py` are under `tools/styles/` (the last two in `shared/`); `generate.py` is `fixtures/district/generate.py`. A reference that is only `:line` is in the file cited just before it.

"The anime family" means neon_noir, anime_cel and solarpunk: their trees and palms are built by one builder and have the same geometry.

Three marks are used:

- **computed**: worked out in Python from the GLBs' own vertex data or from `fixtures/district/manifest.json`, by the game's rule as its code states it. Not taken from a run of the game. The scripts were throwaway and are not kept: a GLB reader that applies `KitTown.band_points_of` surface by surface, and a count of placements inside each camera's frustum.
- **inferred**: follows from code that was read; the thing itself was not read.
- **engine**: how Godot behaves; not in this repository.

## Summary

1. Which kit piece each object stands for:

   | Object | lowpoly_tropical, neon_noir, anime_cel, solarpunk | voxel |
   | --- | --- | --- |
   | 0 `street-tree-a` | `assets/tree_round_a.glb` | `assets/v2/tree_medium.glb` |
   | 1 `street-tree-b` | `assets/tree_round_b.glb` | `assets/v2/tree_small.glb` |
   | 2 `palm-tall` | `assets/palm_a.glb` | none |
   | 3 `palm-short` | `assets/palm_c.glb` | none |
   | no object | `assets/palm_b.glb` (the middle palm, 6.5 m) | |

   The anime family also has a far twin of each of the five (`<piece>_far.glb`). Voxel has no palm: its `palm` kind draws the same two tree files as its `street-tree` kind.
2. These pieces are not placed as scenes. Each is drawn as instances of one mesh in MultiMeshes: the game loads the GLB, takes the mesh of its **first mesh node** and throws the rest away. No node, part or light in the file is looked up. A second mesh node (a `canopy` core, `lanterns`, `lights`) is never drawn.
3. The game does not fit them to a box. Each copy is turned to any angle and its height scaled 0.85 to 1.19. Its width is scaled by **0.25 m divided by the trunk's reach**: the farthest point from the origin, between 0.15 and 2.2 m up, of everything whose material is not named as leaf. A thin trunk makes the whole tree wider; a low branch, an unnamed leaf mass or a trunk that is off the origin makes it narrower. The kits' own pieces come out 0.79 to 1.17 times as wide as built.
4. "Leaf" is told by material name only: a name containing `leaf`, `leaves`, `foliage` or `frond`. The fitting tool's default material name, `sheet_albedo`, is not one.
5. In the anime family the near piece is drawn to 90 m and the far twin beyond. By the cameras' distances, the top-down view and the map draw only far twins, and in the diagonal view most trees are far twins (distances computed; the swap itself is the engine's). A replaced near piece without a replaced far twin shows the kit's old tree there.
6. They carry much of the town: 309 `street-tree` and 299 `palm` placements of 843. None is nearer the square's centre than 15 m (palms) and 30 m (street trees).
7. Beyond the spec, the kit tests hold the anime family's five pieces to two materials at most, give every far twin a spec of its own, and (voxel) forbid a part named after the file. The client's own tests hold the trunk to its footprint and count the collision audit at zero.
8. The pilot's tools do not cover this family as they stand: `asset_views.gd` finds pieces by scene file and finds none of these; `check.py`'s footprint rule is the great tree's; `band.py` leaves parts out by node name, not by material; an `assets.json` entry names one file a style, and these need two or three.
9. Two things in the brief do not hold. Solarpunk and **neon noir** extend the lit pack; anime extends `Pack3D` directly (`godot/styles/solarpunk/pack.gd:6`, `godot/styles/neon_noir/pack.gd:6`, `godot/styles/anime_cel/pack.gd:7`). And the great tree's rule (squeezed until nothing in the band lies outside a footprint box, leaves counted) is not the rule here: see 3.

## Object 0: `street-tree-a` (crown 4.6 m across, 5.5 m tall, clear trunk to 2.2 m)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/tree_round_a.glb` | `assets/tree_round_a.glb`; far twin `assets/tree_round_a_far.glb` | as neon | as neon | `assets/v2/tree_medium.glb` (also drawn for the `palm` kind) |
| Spec: file, key | `tools/styles/lowpoly/specs/vegetation.json:112-122`, `tree_round_a` | `tools/styles/neon/specs/vegetation.json:3`, `tree_round_a`; far `:13`, `tree_round_a_far` | `tools/styles/anime/specs/vegetation.json:3`; far `:13` | `tools/styles/solarpunk/specs/vegetation.json:3`; far `:13` | `tools/styles/voxel/specs/props.json:17`, `tree_medium` |
| Spec size x, y, z (m) | 4.59, 5.46, 5.2 | 4.88, 5.5, 5.51; far 3.86, 5.16, 4.37 | 4.60, 5.48, 5.20; far 3.86, 5.16, 4.37 | 4.60, 5.48, 5.20; far 3.86, 5.16, 4.37 | 5.0, 5.5, 4.5 |
| Triangle limit | 1,500 | 2,000; far 800 | 2,000; far 800 | 2,000; far 800 | 850 |
| Nodes the spec names | `body` | `tree_round_a`, `body`; far `body` | as neon | as neon | `tree` |
| Materials in the kit's file | `wood`, `leaf`, `leaf_dark`, `leaf_light`, `leaf_yellow` | `baked_r75_m0`, `foliage_leaves`; far `baked_r75_m0` | as neon | as neon | `leaf`, `leaf_dark`, `leaf_light`, `trunk`, `trunk_dark` |
| Placed and scaled | F2, F3 below. Kit trunk reach 0.236 m: drawn 1.058 times as wide as built (computed) | reach 0.267 m: 0.936 (computed) | as neon | as neon | reach 0.316 m: 0.791 (computed) |
| Instances | 2 of the 3 entries of a list drawn for 309 placements: about 206 | about 206 | 1 of 2: about 155 | 3 of 5: about 185 | 1 of 2, for both kinds (608 placements): about 304 |
| Found as a scene instance | no (F12) | no | no | no | no |
| Needle | `tree_round_a` | `=tree_round_a.glb` | `=tree_round_a.glb` | `=tree_round_a.glb` | `tree_medium` |

The counts are expected shares; the split is not determined (see "Not determined"). `tree_round_a` without the `=` also matches `tree_round_a_far.glb` in the anime family; lowpoly has no far files. The needle is a file name to match against; it finds nothing with today's `asset_views.gd` (F12).

The kit's files as built (JSON chunk of each GLB; sizes, reaches and heights computed from the vertex data):

| | lowpoly_tropical | neon_noir, anime_cel, solarpunk | voxel |
| --- | --- | --- | --- |
| Nodes | `tree_round_a` (empty) > `body` (mesh `body`) | `tree_round_a` > `body` (mesh `body`); far: `tree_round_a_far` > `body` | `tree_medium` > `tree` (mesh `tree`) |
| Surfaces: triangles | `wood` 67, `leaf` 187, `leaf_dark` 248, `leaf_light` 98, `leaf_yellow` 27 | `baked_r75_m0` 374 (trunk and three branches 122, six solid cores 252), `foliage_leaves` 448 (224 leaf cards); far: `baked_r75_m0` 554 | `leaf` 60, `leaf_dark` 126, `leaf_light` 194, `trunk` 78, `trunk_dark` 86 |
| Triangles | 627 | 822; far 554 | 544 |
| Vertex data | position, normal | position, normal, UV, vertex colour; far has no UV | position, normal |
| Colour | one flat base colour a material; no texture | vertex colours; the cards multiply them by a 512 px atlas of four leaf clusters (`foliage_leaves`, a PNG inside the file), alpha cut at 0.35 | one flat base colour a material; no texture |
| Two-sided | every material | `baked_r75_m0` yes, `foliage_leaves` no (back faces culled) | none |
| Size x, y, z (m) | 4.587, 5.456, 5.197 | 4.876, 5.500, 5.512; far 3.864, 5.155, 4.368 | 5.0, 5.5, 4.5 |
| Trunk reach in the band | 0.236 m | 0.267 m | 0.316 m (set by the four foot cubes, 0.2 m high) |
| Lowest leaf | 2.30 m | cards 2.02 m, cores 2.78 m | 2.5 m |
| Middle of the box, from the origin (x, z) | 0.13, -0.04 | -0.04, 0.00 | 0.00, 0.25 |

No file has node transforms, animations, skins or metadata (`extras`). The four Blender-built kits' files were written by Blender's glTF exporter; voxel's by the kit's own writer.

### Findings, points 3 to 8 (F1 to F13 hold for all four objects)

**How the game uses it (point 3)**

F1. Where they come from. Every tree and palm is a placement of kind `street-tree` or `palm` in the district manifest. Both kinds are planting with a footprint that is a disc of radius 25 cm, on a 25 cm snap, with the one capability `inspect` (`catalogue/catalogue.json:284-305`). The game loads `fixtures/district/manifest.json` (`godot/main.gd:214`, `godot/core/paths.gd:39-40`), which `fixtures/district/generate.py` writes. It holds 309 `street-tree` and 299 `palm` among 843 placements (computed; the total is held at `godot/tests/test_style_pack.gd:83`). No placement of either kind has a facing, a size or a level (computed).
   - Street trees: all 309 are `planting-NNN`, laid on a jittered 4.8 m lattice over the district and 24 m beyond, clear of water, blocks, streets, tracks, doors, seats and every drawn room but the park's lawn (`generate.py:820-824, 868-915`).
   - Palms: 6 at fixed points in the park (`generate.py:433, 451`); 66 in twelve straight rows, 6 m apart (`generate.py:660-662, 682-692, 757-762`): the square's north edge (z = -15 m, x from -17 to 13 m), south of the tram street, the quay, both sides of the avenue and in front of downtown; and 227 in the same scatter as the street trees.
   - None stands on a roof or terrace. No townscape places trees of its own (searched `godot/styles/*/townscape.gd`), and a test holds every planting MultiMesh to placements only (`godot/tests/test_style_pack.gd:114-132`).
   - 284 of the street trees and 210 of the palms stand outside every room; 25 and 89 stand in a room, 8 of them in the park (computed). Trunks are as near as 1.5 m to one another, 4.1 m at the median (computed), so crowns of 3.4 to 4.6 m overlap into groves.

F2. Which piece a placement draws. `Pack3D._placements` takes the kind's entry from the style's `props` (`godot/styles/pack_3d.gd:278-280`); an entry with `tiled` goes the planting way (`:285-297`). The piece is `scenes[hash(Vector2i(round(10 x), round(10 z))) % scenes.size()]`, a hash of where the placement stands (`:1287-1291`). The same placement always draws the same piece; a piece listed twice is drawn about twice as often; changing a list's length changes which placements get which piece. The lists: lowpoly_tropical `[a, b, a]` and `[palm_a, palm_b, palm_c]` (`godot/styles/lowpoly_tropical/style.json:216-233`); neon_noir the same (`neon_noir/style.json:240-257`); anime_cel `[a, b]` (`anime_cel/style.json:230-246`); solarpunk `[a, b, a, b, a]` (`solarpunk/style.json:240-259`); voxel `[tree_small, tree_medium]` for both kinds (`voxel/style.json:213-228`). All ten entries say `"tiled": true, "fill": "trunk"`. In voxel the two kinds share their MultiMeshes, since those are keyed by file (`pack_3d.gd:286-288`).

F3. How each copy is turned and scaled (`pack_3d.gd:289-295`). With `h = |hash(id)|`:
   - turned about the vertical through the piece's origin by the placement's facing (none has one, F1) plus `(h % 628) / 100` radians, so any angle;
   - height scaled by `0.85 + ((h / 11) % 35) / 100`, so 0.85 to 1.19;
   - width scaled by `across`, the same in x and z. Because the entry has `fill`, `across` is not the height scale: it is the footprint's radius, 0.25 m, divided by `KitTown.band_reach(path, true)` (`pack_3d.gd:388-393`).
   - `band_reach` (`godot/styles/kit_town.gd:237-246`) is the distance from the piece's origin, in plan, of the farthest thing it draws between 0.15 and 2.2 m up (`BAND_MEASURE`, `:214`): every vertex in that band and every point where an edge crosses one of the two heights (`:299-315`), of every mesh in the file with its node transforms applied (`:265-281`), **leaving out each surface whose material name, in lower case, contains `leaf`, `leaves`, `foliage` or `frond`** (`LEAF`, `:219`; `:277-279`).
   - The copy stands at the placement's point on y = 0 (`pack_3d.gd:281, 295`).

   So every copy of a piece has one width whatever its height, and the trunk alone decides it. `_fill_footprint`, which stretches a piece to a footprint box and which the great tree goes through, is only for pieces placed as scenes (`pack_3d.gd:423-424, 719-734`).

F4. What follows from F3 (computed on the kit's own files):
   - A trunk with reach R is drawn 0.25/R times as wide as built, crown and all. R = 0.125 m doubles the tree's width and leaves its height alone.
   - Anything not leaf-named in the band and away from the trunk narrows the tree. The kits' small tree hangs leaves into the band: were those surfaces not leaf-named, lowpoly's `tree_round_b` would have a reach of 1.58 m and be drawn 0.16 times as wide; the anime family's 1.68 m and 0.15; voxel's `tree_small` 1.70 m and 0.15.
   - A trunk that does not stand on the origin adds its offset to the reach.
   - A root flare, soil mound, tree guard or ground slab that rises above 0.15 m counts as trunk.
   - With nothing in the band (every surface leaf-named, or a reach under 1 mm) `across` falls back to the height scale (`pack_3d.gd:391-392`).

F5. How they are drawn. `_plant` (`pack_3d.gd:806-825`) gives each piece's transforms to `KitTown.tiles` (`kit_town.gd:107-125`): one `MultiMeshInstance3D` for each 32 m cell of ground the piece stands in (`CHUNK_M`, `:97`), with 3D transforms and no colour or custom data an instance (`:128-136`). Its mesh is `mesh_of(path)`: the scene is loaded once, **the mesh of its first `MeshInstance3D` is kept, and the scene is freed** (`:81-91`). Other mesh nodes, empties and lights in the file are not drawn, though a second mesh node is still measured by `band_reach` (F3) and its material names still read (F9). The mesh node's own transform is not applied to what is drawn, although `band_reach` does apply it: a file whose mesh node is moved, turned or scaled would be measured in one place and drawn in another.

F6. The far twin. If `<piece>_far.<ext>` exists beside the piece, a second set of MultiMeshes is made from it with the same transforms and no shadows; the near set is drawn to 90 m and the far set from 90 m, each with a 4 m margin (`FAR_TREE_M`, `pack_3d.gd:104-106, 810-825`). The far file's own trunk is never measured: it takes the near piece's `across`. Far files exist for all five pieces in the anime family and for none in lowpoly_tropical and voxel (the `assets` folders).

F7. The walking band. The spec's band is 0.25 to 1.9 m above the ground (`godot/tools/collision_audit/audit.gd:52`); the game measures 0.15 to 2.2 m (`kit_town.gd:211-214`). For these kinds the band rule is F3: what is not leaf is scaled to the 0.25 m disc. A crown lower than 2.2 m is neither squeezed nor refused, so long as its material is leaf-named. The kits' own small trees hang into it: leaves from 1.89 m (anime family), 1.97 m (lowpoly) and 1.2 m (voxel), which on the smallest copies is 1.6, 1.7 and 1.0 m above the ground (computed). The collision audit reads the same way: for `street-tree` and `palm` it drops leaf-named surfaces and counts only triangles whose middle is within 1 m of the axis in the piece's own scale (`godot/tools/collision_audit/solids_3d.gd:25-32, 246, 340-357`), over 0.25 to 1.9 m above the ground as drawn (`:259-261`), which for a copy scaled 0.85 is up to 2.24 m in the piece's own frame (computed): 4 cm above what the game measures. The kits build their trunks upright to 2.4 m for this reason (`tools/styles/anime/vegetation.py:415-417, 433-435, 476-478`; `tools/styles/lowpoly/vegetation.py:347-349, 363-365, 517-519`).

**What the game looks up or does after loading (point 4)**

F8. Nodes, parts and metadata: nothing is looked up. A `light` part gets a lamp only on a piece placed as a scene (`pack_3d.gd:298-301, 767-777`); the lit packs' lamps for `lights` parts are found as nodes of the world (`godot/styles/lit/lit_pack.gd:93-105`), and a MultiMesh has none. A `light` or `lights` part in one of these files does nothing. What a player aims at to inspect a tree is a box from the catalogue, 0.5 m square and 5 m (street tree) or 8 m (palm) high (`godot/core/interact.gd:116-128, 327-330`), not the mesh.

F9. Material names are read, on every mesh in the file (`kit_town.gd:88-89, 157-177`):
   - containing `leaf`, `leaves`, `foliage` or `frond`: not trunk (F3, F7). This is the only thing that tells a crown from a trunk.
   - ending `_leaves` and alpha-cut: the lit packs and the toon conversion set alpha-to-coverage with an edge of 0.3 and stop the surface receiving shadows (`lit_pack.gd:53-57`; `godot/styles/anime_cel/toon.gd:109-112`). An opaque surface is left alone whatever it is called.
   - exactly `lamp_glow`, `window_glow`, `fairy_glow` or `light`: a lamp material; its emission energy is set to the style's `window_energy` when the lamps are lit and 0.35 by day (`kit_town.gd:174-175`; `pack_3d.gd:2063-2064`), and `fairy_glow` to 0 by day in the lit packs (`lit_pack.gd:226-228`). No light is cast (F8).
   - beginning `glass`: emission is switched on and it glows after dark (`kit_town.gd:169-173`; `pack_3d.gd:2060-2062`).
   - beginning `neon`: the lit packs light it at night and darken it by day (`kit_town.gd:176-177`; `lit_pack.gd:229-237`).
   - beginning `paving`, `asphalt`, `kerb`, `road`, `path` or `street`: in a style with `wet_ground` (`neon_noir/style.json:470`, `anime_cel/style.json:469`, `solarpunk/style.json:473`) rain darkens it by up to 30% and takes its roughness to 0.1 (`pack_3d.gd:115, 2167-2183`). A material named `street_tree...` would be wetted.

F10. What is done to it:
   - No sway and no wind. The sway shader goes on the meadows' chunks only (`pack_3d.gd:310-319, 515-523`). Nothing reads a tree's vertex colours, second UV layer or heights.
   - No recolouring at run time, by palette or by season (searched the 3D packs and `godot/core` for it: there is none). A kit tree's colours are fixed when it is built.
   - Shadows. Near chunks cast (`pack_3d.gd:807`; `kit_town.gd:151`). Where the style sets `plant_shadow_m` (70 m in the anime family: `neon_noir/style.json:533`, `anime_cel/style.json:468`, `solarpunk/style.json:511`; not set in lowpoly_tropical or voxel) only chunks within that distance of the camera's ground point cast (`pack_3d.gd:950-963, 1997-2001`). Far twins never cast (`:813`).
   - anime_cel. `Toon.apply` runs on the whole world (`pack_3d.gd:220`; `anime_cel/pack.gd:44-45`). For a MultiMesh it takes the mesh's surface materials and, as they come from a file under `anime_cel/`, converts them in place: toon diffuse and specular, roughness 0.32, a rim of 0.25 (`toon.gd:40-50, 79-84, 93-101`); a texture stays. The camera then draws one full-screen ink pass: a line where depth steps by more than 6% of the distance or neighbouring normals differ by more than 0.35 (1 minus their cosine, about 49 degrees), fading out between 60 and 140 m (`anime_cel/shaders/lines.gdshader:12-16, 33-48`; `anime_cel/pack.gd:33-34, 50-51`).
   - neon_noir and solarpunk: only the `_leaves` rule of F9 (`lit_pack.gd:47-59`).
   - lowpoly_tropical and voxel: nothing (`lowpoly_tropical/pack.gd:4`, `voxel/pack.gd:4`).
   - Two-sided drawing, alpha cut and textures are as the file's materials say; nothing overrides them.

F11. Level of detail. Apart from the far twin (F6), the import file beside each GLB says whether Godot makes its automatic mesh LODs, and it stays in place when a new GLB is copied over the kit's:

   | `meshes/generate_lods` | lowpoly_tropical | anime family | voxel |
   | --- | --- | --- | --- |
   | `tree_round_a`, `tree_round_b` (voxel: `tree_medium`, `tree_small`) | true | false | false |
   | `palm_a`, `palm_b`, `palm_c` | true | true | |
   | far twins | | true | |

   (the `.glb.import` files under `godot/styles/<style>/assets/`). The kits turned LODs off for leaf-card pieces because the simplifier deletes whole cards (`tools/styles/shared/foliage.py:28-30`); voxel's test requires them off (`tools/styles/voxel/test_assets.py:253-257`). All of them have `gltf/embedded_image_handling=1`: a texture inside the GLB is written out beside it at import, as `<piece>_<image name>`.

**What the kit's builders make (point 5)**

- **lowpoly_tropical** (`tools/styles/lowpoly/vegetation.py:511-535`). A six-sided trunk, upright to 2.4 m and then leaning to a fork at 2.8 m or higher, radii 0.24, 0.18, 0.14 m; three five-sided branches; a crown of one large faceted lobe and six more (five for `b`), each a jittered ico-sphere (`:81-85`). Every facet is painted by the way it faces: dark underneath, mid on the flanks, light on top, a few yellow (`:59-78`). Flat-shaded, one colour a facet, no texture; the pieces are not baked, so each colour is a material (`tools/styles/lowpoly/build.py:35-42`).
- **anime family** (`tools/styles/anime/vegetation.py:420-457`; neon calls it and shifts the greens a step darker, `tools/styles/neon/vegetation.py:65, 264-269, 345-347`; solarpunk calls it on its own palette, `tools/styles/solarpunk/vegetation.py:408-410`). An eight-sided trunk with a fluted foot, upright to 2.4 m, fork at 2.8 m or higher, three branches. The crown is six lobes (`foliage.round_lobes`); each is a small dark closed core (`tools/styles/shared/foliage.py:300-340`) wrapped in single-sided square cards about 1.06 m across (0.78 m for `b`), enough to cover the lobe 5.5 times, each showing one of four leaf clusters from a shared alpha atlas and tinted one of four greens by how high it sits (`foliage.py:343-376, 393-449`). Every vertex normal comes from a smooth field over the whole crown, not from its card, so the toon step shades the crown as one form and the ink pass draws lobes, not cards (`foliage.py:10-15, 171-182`; applied at `vegetation.py:239-256`). The crown is fitted to the spec size plus the cards' empty corners (`vegetation.py:455-456`; `foliage.py:61-65`). The build then bakes the colours into vertex colours and merges the materials into `baked_r75_m0` and `foliage_leaves` (`tools/styles/shared/bake.py:21-42, 86-116`; `tools/styles/anime/build.py:44-48`; `tools/styles/shared/kitbuild.py:36-38`).
- **the far twin** is the same lobes as solid two-tone cores at 0.92 of each lobe, with no cards, fitted to 0.84 of the spread (`vegetation.py:448-454`): that is why its spec is smaller than the near piece's.
- **voxel** (`tools/styles/voxel/props.py:13-17, 31-39`; `tools/styles/voxel/shapes.py:55-95`). On a 0.1 m grid: a square trunk 0.4 m across and 2.6 m tall with every fifth cell darker and four foot cubes; a canopy of 0.5 m blocks filling three ellipsoid tiers, ragged at the surface, light on top and dark beneath. Hidden faces are dropped and flat faces of one colour merged; one material a palette colour.

A replacement gives up: the leafy outline the cards give (with alpha-to-coverage under the anime family's 2x MSAA: `neon_noir/style.json:532`, `anime_cel/style.json:462`, `solarpunk/style.json:510`); normals made for the toon step and the ink pass; colours taken from each kit's palette, which the town's other planting shares (leaf greens: lowpoly `#2F7A34 #3F8F3A #6DB33F #A7C94A`; anime `#3B7B3B #5C9F40 #8DC555 #BCDC6E`; neon street trees `#18402A #265E36 #3D7E45`; solarpunk `#3D6E2C #5A9233 #86BA4A #BFD66A`; voxel `#2E8A2E #4CAF3C #86CF45`: read from the files' colours); files of 23 to 137 kB with no texture but the shared 75 kB atlas; and a build that is the same bytes every time.

**What the tests require beyond the spec (point 6)**

- Two materials at most in `tree_round_a`, `tree_round_b`, `palm_a`, `palm_b`, `palm_c`: anime (`tools/styles/anime/test_assets.py:87-93`), neon and solarpunk (`tools/styles/shared/kittests.py:27, 114-120`). Lowpoly and voxel have no such rule (lowpoly's trees have five materials and its palms seven; voxel's trees five).
- Every GLB in the assets folder has a spec, far twins included (`anime/test_assets.py:82-85`; `kittests.py:109-112`; `lowpoly/test_assets.py:234-237`; `voxel/test_assets.py:232-234`). Voxel also holds its specs equal to its recipes (`voxel/test_assets.py:210-213`), so a new voxel file needs both.
- Voxel: no node other than the root may carry the file's name (`voxel/test_assets.py:226-229`), and every GLB needs an import file with LODs off (`:253-257`).
- The pinned Khronos validator must pass with no error and no warning (`lowpoly/validate.sh:3-4`; `kittests.py:122-126`; `anime/test_assets.py:95-99`; `voxel/test_assets.py:249-251`).
- The committed file must be, byte for byte, what the generator builds (`anime/test_assets.py:101-116`; `kittests.py:128-144`; `voxel/test_assets.py:236-247`; lowpoly has no such test). A generated piece cannot meet this; it is the same for the great tree.
- The client's tests, which read the game and so would read a working copy: planting is drawn exactly its footprint's radius where people walk (width scale times trunk reach within 1 mm of 0.25 m) and grows to more than five heights (`godot/tests/test_anime_pack.gd:146-172`); each near chunk has its far twin, at 90 m, with no shadows (`godot/tests/test_plant_shadows.gd:44-59`); no placeholder is drawn (`test_anime_pack.gd:140-143`); and the collision audit's six counts equal the budget, which is zero in every style (`godot/tests/test_collision_audit.gd:23-43`; `godot/evidence/placement-budget.json`). The first holds by construction unless the file has nothing in the band (F4).

**Finding the placed copies (point 7)**

F12. They are not scene instances. `placement_nodes[id]` for a tree is the chunk's `MultiMeshInstance3D` (`godot/styles/style_pack.gd:39-42, 235-238`; `pack_3d.gd:815-817`), made with `MultiMeshInstance3D.new()` (`kit_town.gd:137`), so its `scene_file_path` is empty (engine). `work/asset_views.gd:86-91` matches the needle against that path and finds none; its header says so (`:33-34`). What there is to find them by:
   - `pack._planted[path]`, keyed by the style.json path (`assets/tree_round_a.glb`): the MultiMesh, or a node of chunk MultiMeshes (`pack_3d.gd:119-120, 809`; `Pack3D._chunks`, `:967-968`). Far twins are not in it; they carry the meta `far_of`, the near piece's base name (`:823`).
   - On each chunk: the metas `placement_ids` and `instance_xforms`, in instance order, and `centre` (`kit_town.gd:140-150`). `instance_xforms[k]` is copy k's transform in the world; the lengths of its basis are the scale the game gave it.
   - The mesh's `resource_path` should contain the GLB's path (inferred: the game relies on this for materials, `toon.gd:82`, `lit_pack.gd:58`).
   - `asset_views.gd`'s measuring passes set surface overrides on mesh nodes (`work/asset_views.gd:220-253`); a MultiMesh chunk has only one override for all its copies.

**Views, and how much they carry (point 8)**

F13. The standard views are the three camera presets `topdown`, `diagonal`, `street` (`godot/core/orbit_rig.gd:8, 68-93`), first person in every 3D style (`godot/styles/style_pack.gd:769-770`; eye 1.6 m, `godot/core/fpv_camera.gd:10`), the sheet tool's `park` eye (`godot/tools/sheet_views.gd:83-86`) and the bench's scenes (`godot/core/bench.gd:22-31`). Counted from the manifest and the camera code at 16:9, testing each tree at its foot, middle and top; buildings in the way are not accounted for (computed):

   | View | Camera at (x, y, z) m | Street trees in the frustum: within 90 m, beyond | Palms: within 90 m, beyond | Nearest |
   | --- | --- | --- | --- | --- |
   | topdown | -1.5, 142.8, -4.0 | 0, 140 | 0, 186 | 140 m |
   | diagonal | 29.4, 38.9, 55.5 | 9, 97 | 27, 91 | palm 46 m, street tree 55 m |
   | street | -2.9, 1.7, 16.7 | 16, 77 | 38, 50 | palm 32 m (the square's north row), street tree 43 m |
   | park | -41.5, 1.7, 33.0 | 33, 75 | 43, 41 | palm 18 m (the quay's row), street tree 41 m |

   - In the anime family "beyond 90 m" is the far twin (F6; the swap is by 32 m chunk, so the split is approximate) (inferred from the distances; engine). The top-down view, and the map, whose camera stands 200 m up (`pack_3d.gd:2293-2295, 2327-2336`), draw far twins only.
   - No street tree is within 30 m of the square's centre and 8 are within 45 m; 5 palms are within 20 m and 15 within 30 m (computed). No standard view shows a street tree close. In first person a player can stand under any of the 114 that stand in rooms (open-ground rooms are walked: `godot/core/city_geometry.gd:238-240`).
   - If every copy were in view at once, today's kit pieces would be about 167,000 triangles of street trees and 192,000 of palms in lowpoly, 253,000 and 474,000 in the anime family, 272,000 for both kinds in voxel; at the specs' limits, 464,000 and 449,000, 618,000 and 598,000, and 426,000 (computed from the expected shares).

## Object 1: `street-tree-b` (crown 3.4 m across, 4.4 m tall, clear trunk to 2.2 m)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/tree_round_b.glb` | `assets/tree_round_b.glb`; far twin `assets/tree_round_b_far.glb` | as neon | as neon | `assets/v2/tree_small.glb` (also drawn for the `palm` kind) |
| Spec: file, key | `tools/styles/lowpoly/specs/vegetation.json:123-133`, `tree_round_b` | `tools/styles/neon/specs/vegetation.json:4`; far `:14`, `tree_round_b_far` | `tools/styles/anime/specs/vegetation.json:4`; far `:14` | `tools/styles/solarpunk/specs/vegetation.json:4`; far `:14` | `tools/styles/voxel/specs/props.json:18`, `tree_small` |
| Spec size x, y, z (m) | 3.38, 4.36, 3.6 | 3.6, 4.41, 3.82; far 2.86, 4.15, 3.02 | 3.40, 4.33, 3.60; far 2.86, 4.15, 3.02 | 3.40, 4.33, 3.60; far 2.86, 4.15, 3.02 | 3.2, 3.6, 2.8 |
| Triangle limit | 1,500 | 2,000; far 800 | 2,000; far 800 | 2,000; far 800 | 550 |
| Nodes the spec names | `body` | `tree_round_b`, `body`; far `body` | as neon | as neon | `tree` |
| Materials in the kit's file | `wood`, `leaf`, `leaf_dark`, `leaf_light`, `leaf_yellow` | `baked_r75_m0`, `foliage_leaves`; far `baked_r75_m0` | as neon | as neon | `leaf`, `leaf_dark`, `leaf_light`, `trunk`, `trunk_dark` |
| Placed and scaled | F2, F3. Kit trunk reach 0.236 m: 1.058 times as wide as built (computed) | reach 0.235 m: 1.065 (computed) | as neon | as neon | reach 0.224 m: 1.118 (computed) |
| Instances | 1 of 3 entries, of 309: about 103 | about 103 | 1 of 2: about 155 | 2 of 5: about 124 | 1 of 2, for both kinds (608): about 304 |
| Found as a scene instance | no (F12) | no | no | no | no |
| Needle | `tree_round_b` | `=tree_round_b.glb` | `=tree_round_b.glb` | `=tree_round_b.glb` | `tree_small` |

The kit's files as built:

| | lowpoly_tropical | neon_noir, anime_cel, solarpunk | voxel |
| --- | --- | --- | --- |
| Nodes | `tree_round_b` > `body` (mesh `body`) | `tree_round_b` > `body`; far: `tree_round_b_far` > `body` | `tree_small` > `tree` (mesh `tree`) |
| Surfaces: triangles | `wood` 67, `leaf` 100, `leaf_dark` 135, `leaf_light` 53, `leaf_yellow` 12 | `baked_r75_m0` 374 (trunk and branches 122, six cores 252), `foliage_leaves` 440 (220 cards); far: `baked_r75_m0` 554 | `leaf` 36, `leaf_dark` 88, `leaf_light` 134, `trunk` 34, `trunk_dark` 58 |
| Triangles | 367 | 814; far 554 | 350 |
| Vertex data, colour, two-sided | as object 0 | as object 0 | as object 0 |
| Size x, y, z (m) | 3.379, 4.339, 3.598 | 3.604, 4.400, 3.816; far 2.856, 4.145, 3.024 | 3.2, 3.6, 2.8 |
| Trunk reach in the band | 0.236 m | 0.235 m | 0.224 m (the four foot cubes) |
| Lowest leaf | 1.97 m (`leaf_dark`), reaching 1.58 m out below 2.2 m | cards 1.89 m, reaching 1.68 m out below 2.2 m; cores 2.37 m | 1.2 m, reaching 1.70 m out below 2.2 m |
| Middle of the box, from the origin (x, z) | -0.21, -0.29 | -0.10, 0.00 | 0.00, 0.20 |

### Findings, points 3 to 8

F1 to F13 apply unchanged: the same kind, lists, code path, tests and views as object 0. What is this piece's own:

- It is the piece whose crown hangs into the band in every kit, so it is the one that shows what the leaf names are for (F4): without them each kit's small tree would be drawn 0.15 to 0.16 times as wide.
- Builders: lowpoly `tree_round("tree_round_b", 4.6, 3.6, 5, 72)` (`tools/styles/lowpoly/vegetation.py:551`), five lobes round the central one; the anime family `tree_round("tree_round_b", 4.4, 3.4, 3.6, 17, 72)` (`tools/styles/anime/vegetation.py:677`; `neon/vegetation.py:346`; `solarpunk/vegetation.py:409`), six lobes, cards 0.78 m; voxel `tree_small`, a trunk 0.2 m across and 1.6 m tall under two tiers of 0.4 m blocks (`tools/styles/voxel/props.py:20-28`).
- Voxel's spec is not the design's size: 3.6 m tall against the design's 4.4 m, and 2.8 m deep against 3.4 m. The kit tests allow 3.98 m and 3.10 m.

## Object 2: `palm-tall` (8.5 m high, fronds 5.2 m across, slender ringed trunk with a slight lean)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/palm_a.glb` | `assets/palm_a.glb`; far twin `assets/palm_a_far.glb` | as neon | as neon | none. The `palm` kind draws `assets/v2/tree_small.glb` and `assets/v2/tree_medium.glb` (`godot/styles/voxel/style.json:221-228`) |
| Spec: file, key | `tools/styles/lowpoly/specs/vegetation.json:16-27`, `palm_a` | `tools/styles/neon/specs/vegetation.json:5`; far `:15`, `palm_a_far` | `tools/styles/anime/specs/vegetation.json:5`; far `:15` | `tools/styles/solarpunk/specs/vegetation.json:5`; far `:15` | none |
| Spec size x, y, z (m) | 5.2, 8.5, 5.2 | 5.46, 8.64, 5.27; far the same | as neon | as neon | |
| Triangle limit | 1,500 | 2,000; far 900 | 2,000; far 900 | 2,000; far 900 | |
| Nodes the spec names | `palm_a`, `body` | `palm_a`, `body`; far `body` | as neon | as neon | |
| Materials in the kit's file | `palm_bark`, `wood`, `wood_dark`, `leaf`, `leaf_light`, `leaf_yellow`, `leaf_dark` | `baked_r75_m0` only; far the same | as neon | as neon | |
| Placed and scaled | F2, F3. Kit trunk reach 0.283 m: 0.884 times as wide as built (computed) | reach 0.270 m: 0.928 (computed) | as neon | as neon | as its trees (objects 0 and 1) |
| Instances | 1 of 3 entries, of 299: about 100 | about 100 | about 100 | about 100 | the 299 palm placements are among the 608 its two trees draw |
| Found as a scene instance | no (F12) | no | no | no | no |
| Needle | `palm_a` | `=palm_a.glb` | `=palm_a.glb` | `=palm_a.glb` | none |

The kit's files as built:

| | lowpoly_tropical | neon_noir, anime_cel, solarpunk |
| --- | --- | --- |
| Nodes | `palm_a` > `body` (mesh `body`) | `palm_a` > `body`; far: `palm_a_far` > `body` |
| Surfaces: triangles | `palm_bark` 90, `wood` 75, `wood_dark` 60, `leaf` 192, `leaf_light` 176, `leaf_yellow` 76, `leaf_dark` 12 | `baked_r75_m0` 1,666 (trunk, rings and coconuts 498; tuft and fronds 1,168, told apart only by vertex colour); far 718 |
| Triangles | 681 | 1,666; far 718 |
| Vertex data | position, normal | position, normal, vertex colour; no UV, no texture |
| Two-sided | every material | yes |
| Size x, y, z (m) | 5.342, 8.490, 5.254 | 5.459, 8.640, 5.272; far the same |
| Trunk reach in the band | 0.283 m | 0.270 m (far 0.264 m) |
| Lowest frond | 6.30 m | 6.25 m |
| Middle of the box, from the origin (x, z) | 1.13, -0.17 | 1.08, -0.09 |

### Findings, points 3 to 8

F2 to F13 apply unchanged, with the `palm` kind for `street-tree` (its catalogue height is 8 m, `catalogue/catalogue.json:295-305`). What is the palms' own:

P1. Where they stand (F1): 6 in the park, 66 in rows, 227 scattered. The rows and the park are where palms are seen close: the square's north row is 32 to 35 m from the street view's camera, straight behind the great tree, and the quay's row is 18 to 36 m from the `park` view's (F13, computed).

P2. The kit's palm leans, but not where people walk. Its trunk stands upright over the origin to 2.4 m and leans only above, by 1.1 m for `palm_a`, 0.8 m for `palm_b` and 0.45 m for `palm_c` (`tools/styles/anime/vegetation.py:474-478, 683-685`; `tools/styles/lowpoly/vegetation.py:361-366, 552-554`; the fixture's comment, `fixtures/district/generate.py:442-444`). So the crown sits beside the origin and **the piece's box is not centred on it**: the box's middle is 1.1 m from the trunk's foot for `palm_a`, 0.7 to 0.8 m for `palm_b`, 0.4 to 0.5 m for `palm_c` (computed).

P3. In the anime family a palm is one surface, `baked_r75_m0`, with no leaf name anywhere. Its width comes out right only because its fronds stay above 2.2 m (they start at 6.25, 4.63 and 2.98 m: computed). In lowpoly the fronds are leaf-named.

P4. Builders. Lowpoly (`tools/styles/lowpoly/vegetation.py:354-394`): a seven-sided trunk of ten segments in alternate `palm_bark` and `wood` with a 6% swell on every other ring, base radius `0.17 + 0.012 x height` m; a tuft; three coconuts in `wood_dark`; nine fronds (eight, seven) as folded, notched blades drawn two-sided, and three young upright ones; painted by facing. The anime family (`tools/styles/anime/vegetation.py:462-503`): an eight-sided trunk of twelve ringed segments, base radius `0.13 + 0.012 x height` m swollen 1.2 times at the foot; a tuft; three coconuts; twelve fronds (eleven, ten), alternately raised and light or drooping and dark, each a folded strip of ten stations with a saw edge (`:194-216`), and three short upright ones. The far twin: six trunk segments, plain fronds of four stations, no coconuts, the same outline and so the same spec size. Neon and solarpunk call the same builder on their palettes (`neon/vegetation.py:272-273, 348-354`; `solarpunk/vegetation.py:411-417`).

P5. Tests: as object 0. The two-material rule is met by one material.

P6. Voxel has no palm piece and no palm spec. Putting a palm into voxel means new files and a change to `godot/styles/voxel/style.json:221-228`, and for the kit's tests a spec and a recipe (`tools/styles/voxel/test_assets.py:210-213, 232-234`).

### The third palm, `palm_b`, which has no design object

| | lowpoly_tropical | neon_noir, anime_cel, solarpunk |
| --- | --- | --- |
| Kit file | `assets/palm_b.glb` | `assets/palm_b.glb`; far twin `assets/palm_b_far.glb` |
| Spec: file, key | `tools/styles/lowpoly/specs/vegetation.json:28-39`, `palm_b` | line 6 of each kit's `specs/vegetation.json`; far line 16, `palm_b_far` |
| Spec size x, y, z (m) | 4.4, 6.5, 4.4 | 4.36, 6.6, 4.48; far the same |
| Triangle limit; nodes | 1,500; `palm_b`, `body` | 2,000; `palm_b`, `body`; far 900; `body` |
| As built | 641 triangles; 4.512, 6.464, 4.604 m; trunk reach 0.257 m, drawn 0.974 times as wide; fronds from 4.61 m; box middle 0.66, -0.15 | 1,586 triangles (far 686); 4.356, 6.596, 4.485 m; reach 0.242 m, drawn 1.034; fronds from 4.63 m; box middle 0.77, -0.06 |
| Instances | 1 of 3 entries: about 100 | about 100 |
| Needle | `palm_b` | `=palm_b.glb` |

It is drawn for about a third of the palms. With each copy's height scaled 0.85 to 1.19, `palm_c` runs from 3.8 to 5.4 m, `palm_b` from 5.5 to 7.9 m and `palm_a` from 7.2 to 10.3 m (computed from the kits' heights): `palm_b` fills the gap between the other two.

## Object 3: `palm-short` (4.5 m high, fronds 3.4 m across)

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file | `assets/palm_c.glb` | `assets/palm_c.glb`; far twin `assets/palm_c_far.glb` | as neon | as neon | none (see object 2) |
| Spec: file, key | `tools/styles/lowpoly/specs/vegetation.json:40-51`, `palm_c` | `tools/styles/neon/specs/vegetation.json:7`; far `:17`, `palm_c_far` | `tools/styles/anime/specs/vegetation.json:7`; far `:17` | `tools/styles/solarpunk/specs/vegetation.json:7`; far `:17` | none |
| Spec size x, y, z (m) | 3.4, 4.5, 3.4 | 3.5, 4.54, 3.41; far the same | as neon | as neon | |
| Triangle limit | 1,500 | 2,000; far 900 | 2,000; far 900 | 2,000; far 900 | |
| Nodes the spec names | `palm_c`, `body` | `palm_c`, `body`; far `body` | as neon | as neon | |
| Materials in the kit's file | `palm_bark`, `wood`, `wood_dark`, `leaf`, `leaf_yellow`, `leaf_light`, `leaf_dark` | `baked_r75_m0` only; far the same | as neon | as neon | |
| Placed and scaled | F2, F3. Kit trunk reach 0.230 m: 1.087 times as wide as built (computed) | reach 0.214 m: 1.169 (computed) | as neon | as neon | as its trees |
| Instances | 1 of 3 entries, of 299: about 100 | about 100 | about 100 | about 100 | see object 2 |
| Found as a scene instance | no (F12) | no | no | no | no |
| Needle | `palm_c` | `=palm_c.glb` | `=palm_c.glb` | `=palm_c.glb` | none |

The kit's files as built:

| | lowpoly_tropical | neon_noir, anime_cel, solarpunk |
| --- | --- | --- |
| Nodes | `palm_c` > `body` (mesh `body`) | `palm_c` > `body`; far: `palm_c_far` > `body` |
| Surfaces: triangles | `palm_bark` 90, `wood` 75, `wood_dark` 60, `leaf` 170, `leaf_yellow` 68, `leaf_light` 130, `leaf_dark` 8 | `baked_r75_m0` 1,506 (trunk, rings and coconuts 498; tuft and fronds 1,008); far 654 |
| Triangles | 601 | 1,506; far 654 |
| Vertex data, two-sided | as `palm_a` | as `palm_a` |
| Size x, y, z (m) | 3.382, 4.424, 3.575 | 3.501, 4.536, 3.406; far the same |
| Trunk reach in the band | 0.230 m | 0.214 m (far 0.208 m) |
| Lowest frond | 2.99 m | 2.98 m |
| Middle of the box, from the origin (x, z) | 0.46, -0.06 | 0.42, 0.01 |

### Findings, points 3 to 8

F2 to F13 and P1 to P6 apply unchanged. What is this piece's own:

- Its fronds come nearest the band of any palm: 2.98 m in the kit, which is 2.53 m above the ground on the smallest copy (computed). In the anime family they are not leaf-named (P3), so a frond of a replacement that droops below 2.2 m on a surface that is not leaf-named counts as trunk: a tip 1.7 m out would have the whole palm drawn 0.15 times as wide (F4).
- Builders: lowpoly `palm("palm_c", 3.8, 0.45, 1.8, 7, 63)` (`tools/styles/lowpoly/vegetation.py:554`); the anime family `palm("palm_c", 3.8, 0.45, 1.8, 10, 63)` (`tools/styles/anime/vegetation.py:685`): a trunk 3.8 m to the tuft, leaning 0.45 m above 2.4 m, fronds 1.8 m long.

## What a generated replacement must keep or put back by rule

### For all four objects

R1. **One mesh, in the first mesh node.** Everything to be drawn is one mesh in one node (`body`; `tree` in voxel), with no translation, rotation or scale on that node or its parents (F5). The fitting tool's separate parts, the `canopy` core (`work/fit_generated.py:1469`), `lanterns`, `lights` and `light`, are not drawn for these pieces, though whatever of them lies in the band on a surface that is not leaf-named would still be measured as trunk: what they add has to be joined into the one mesh as geometry of its surfaces.

R2. **The origin is the trunk's foot.** x = z = 0 is the middle of the trunk where it meets the ground, y = 0 is the ground, y is up, units are metres. Size the piece by its extents to the kit's box, then put the trunk's foot on the origin. Do not centre the box: the kits' boxes are not centred on the origin (a street tree's middle is 0.04 to 0.36 m from it, a palm's 0.4 to 1.1 m: computed; P2).

R3. **Nothing but trunk in the band.** From 0.15 m to 2.4 m up, whatever is not on a leaf-named surface must be the trunk and nothing else: no branch, fork, leaf mass, wide root flare, soil, tree guard or ground slab (F3, F4, F7). The game measures to 2.2 m; the audit reads the smallest copies to 2.24 m; the kits build to 2.4 m. The design's "clear trunk to 2.2 m" is the game's measure exactly, with no margin.

R4. **The trunk's reach sets the width.** Let R be the farthest point of the trunk from the axis in that band. The game draws the piece 0.25/R times as wide as built, and the far twin by the same factor. Make R 0.25 m (the kits' are 0.21 to 0.32 m) by scaling the trunk's cross-section about the axis, or by a swollen foot that rises into the band, and report 0.25/R with each piece. To leave R as generated is to let the trunk's thickness resize the tree.

R5. **Names.** Two materials at most (the anime family's kit rule; in every style each surface of each chunk is a draw of its own: engine). One for the wood, not leaf-named (`trunk` or `wood`); one for the crown or fronds, with `leaf`, `leaves`, `foliage` or `frond` in its name (`leaf`, `fronds`). They may share one texture. Not both leaf-named (F4). The fitting tool's default, `sheet_albedo` (`work/fit_generated.py:889`), is not leaf-named. No name may begin `street`, `path`, `road`, `kerb`, `asphalt`, `paving`, `glass` or `neon`, or be `lamp_glow`, `window_glow`, `fairy_glow` or `light` (F9). Do not end the crown's name in `_leaves` unless it is alpha-cut cards.

R6. **Nodes for the kit's spec.** A root named as the file and the mesh node `body` in the four non-voxel styles; in voxel the root named as the file and the mesh node `tree`, with no other node named as the file (`tools/styles/voxel/test_assets.py:226-229`).

R7. **No lights, no extra parts.** A lamp or lantern part does nothing here (F8).

R8. **A far twin in neon_noir, anime_cel and solarpunk.** Write `<piece>_far.glb` as well: root `<piece>_far`, mesh node `body`, the same origin and outline as the near piece, 800 triangles at most for a tree and 900 for a palm. It casts no shadow and its own trunk is not measured (F6). Without it the top-down view, the map and most of the diagonal view show the kit's old piece, scaled by the new piece's 0.25/R. The kit's far twins have no texture (vertex colours only); a far twin with its own copy of the texture doubles the piece's texture memory (inferred).

R9. **Closed from above and from below.** The crown is seen from straight above (top-down, map), from the diagonal, and from underneath in first person. The generator's crown is a shell with a hole in the top (`docs/research/2026-10-02-design-sheet-to-asset/README.md:133`): fill it inside the one mesh (R1), on the leaf surface.

R10. **Triangles are a count for each copy.** The limit is 1,500 (lowpoly), 2,000 (anime family) or 850 and 550 (voxel) and each piece is drawn about 100 to 300 times (F13). The great tree needed 6,500 to 31,000 for one copy.

R11. **anime_cel: no creases in the crown.** Faceted leaf masses are inked at every facet (F10). The crown's normals have to vary smoothly across it, as the kit's do (the fitting tool has `--leaf-smooth`, `--leaf-round` and `--core-smooth`).

R12. **What stays the kit's.** The import file beside the GLB stays when the GLB is copied over (F11): Godot will make automatic LODs of a generated lowpoly tree or palm and of a generated palm or far twin in the anime family, and none of the anime family's street trees or voxel's trees.

### Object 0, `street-tree-a`

| Style | File to write | Root, mesh node | Box x, y, z (m) | Triangles |
| --- | --- | --- | --- | --- |
| lowpoly_tropical | `assets/tree_round_a.glb` | `tree_round_a`, `body` | 4.59, 5.46, 5.2 | 1,500 |
| neon_noir | `assets/tree_round_a.glb` | `tree_round_a`, `body` | 4.88, 5.5, 5.51 | 2,000 |
| | `assets/tree_round_a_far.glb` | `tree_round_a_far`, `body` | 3.86, 5.16, 4.37 | 800 |
| anime_cel, solarpunk | `assets/tree_round_a.glb` | `tree_round_a`, `body` | 4.60, 5.48, 5.20 | 2,000 |
| | `assets/tree_round_a_far.glb` | `tree_round_a_far`, `body` | 3.86, 5.16, 4.37 | 800 |
| voxel | `assets/v2/tree_medium.glb` | `tree_medium`, `tree` | 5.0, 5.5, 4.5 | 850 |

- The kit's box is deeper than it is wide; the design's crown is round. Filled to the box, the crown is stretched 13% in depth; built round at 4.6 m it misses the spec's depth in the four non-voxel styles (by 0.60 m against 0.54 m allowed in lowpoly, anime and solarpunk; 0.91 m against 0.57 m in neon) and meets voxel's. The game turns every copy to a different angle, so the stretch has no fixed direction in the town.
- Put back: the trunk's reach (R4); a clear trunk to 2.4 m, by lifting the crown's underside, with the crown leaf-named as well (R3, R5); the crown's inside and top (R9).
- The far twin: the kit's far spec is 16 to 21% narrower and shallower than the near piece's, because the kit's far crown is its lobes without the cards' fringe. A far twin cut from the generated tree has the near piece's outline: at 4.6 to 4.9 m wide it is 0.3 to 0.6 m over what the far spec allows (4.27 m). Either it keeps the outline and misses the far spec, or it meets the spec and the tree shrinks at 90 m. A decision.
- Voxel: this file is drawn for palms too, so replacing it changes 608 placements. The game turns each copy to any angle, scales its height 0.85 to 1.19 and its width by 0.25/R (0.79 for the kit's piece): no planted voxel tree is on the world's grid or made of true cubes today. Only R = 0.25 m keeps the cubes square in plan. The kit's canopy block is 0.5 m and its limit 850 triangles.

### Object 1, `street-tree-b`

| Style | File to write | Root, mesh node | Box x, y, z (m) | Triangles |
| --- | --- | --- | --- | --- |
| lowpoly_tropical | `assets/tree_round_b.glb` | `tree_round_b`, `body` | 3.38, 4.36, 3.6 | 1,500 |
| neon_noir | `assets/tree_round_b.glb` | `tree_round_b`, `body` | 3.6, 4.41, 3.82 | 2,000 |
| | `assets/tree_round_b_far.glb` | `tree_round_b_far`, `body` | 2.86, 4.15, 3.02 | 800 |
| anime_cel, solarpunk | `assets/tree_round_b.glb` | `tree_round_b`, `body` | 3.40, 4.33, 3.60 | 2,000 |
| | `assets/tree_round_b_far.glb` | `tree_round_b_far`, `body` | 2.86, 4.15, 3.02 | 800 |
| voxel | `assets/v2/tree_small.glb` | `tree_small`, `tree` | 3.2, 3.6, 2.8 | 550 |

- Built round at the design's size it meets the spec in lowpoly, anime and solarpunk, and misses neon's depth by 2 cm (3.4 m against 3.82 m, 0.40 m allowed).
- Put back: as object 0. A tree 4.4 m tall with a trunk clear to 2.2 m has 2.2 m left for its crown, and 2.0 m if the trunk is cleared to 2.4 m; the kit's small tree does not keep that clearance (its leaves start at 1.9 to 2.0 m).
- The far twin: the same choice as object 0 (the far spec allows 3.17 m of width; the near piece is 3.4 to 3.6 m).
- Voxel: fitted to `tree_small`'s box the design is squashed to 82% of its height and of its depth. The kit's canopy block is 0.4 m and its limit 550 triangles. Drawn for palms too.

### Object 2, `palm-tall`

| Style | File to write | Root, mesh node | Box x, y, z (m) | Triangles |
| --- | --- | --- | --- | --- |
| lowpoly_tropical | `assets/palm_a.glb` | `palm_a`, `body` | 5.2, 8.5, 5.2 | 1,500 |
| neon_noir, anime_cel, solarpunk | `assets/palm_a.glb` | `palm_a`, `body` | 5.46, 8.64, 5.27 | 2,000 |
| | `assets/palm_a_far.glb` | `palm_a_far`, `body` | 5.46, 8.64, 5.27 | 900 |
| voxel | none | | | |

- The design's size is lowpoly's spec exactly and inside the anime family's.
- **Upright through the band.** The trunk must stand over the origin from the ground to 2.4 m and lean only above (P2). For a generated trunk that leans from the ground: move each cross-section below 2.4 m onto the axis, and everything above by the offset at 2.4 m. Left leaning, the lean adds to the reach: 5 degrees is 0.19 m at 2.2 m.
- **A slender trunk makes a wide palm.** The kits' palm trunks are 0.43 to 0.57 m thick at the foot. A trunk 0.24 m thick would be drawn 2.1 times as wide: fronds 5.2 m across become 10.8 m (R4). A swollen foot reaching 0.25 m between 0.15 m and about 0.5 m up keeps the trunk above it slender.
- **Fronds.** On their own leaf-named surface (`fronds`). The kit's are thin sheets drawn two-sided; the generator's thin leaves vanish in the rebuild unless swollen first (`docs/research/2026-10-02-design-sheet-to-asset/README.md:126`).
- **Rings.** The kits model them as alternate colours and swells; in a replacement they are in the texture.
- Size it about the trunk's foot, not the box (R2).

### Object 3, `palm-short`

| Style | File to write | Root, mesh node | Box x, y, z (m) | Triangles |
| --- | --- | --- | --- | --- |
| lowpoly_tropical | `assets/palm_c.glb` | `palm_c`, `body` | 3.4, 4.5, 3.4 | 1,500 |
| neon_noir, anime_cel, solarpunk | `assets/palm_c.glb` | `palm_c`, `body` | 3.5, 4.54, 3.41 | 2,000 |
| | `assets/palm_c_far.glb` | `palm_c_far`, `body` | 3.5, 4.54, 3.41 | 900 |
| voxel | none | | | |

- The design's size is lowpoly's spec exactly and inside the anime family's.
- As object 2. In addition, on a palm this short the frond tips are the risk: keep them above 2.4 m, and put them on a leaf-named surface as well (R3, R5).

### `palm_b`, and voxel's palms: decisions, with what the code allows

- `palm_b` left as the kit's: about a third of the palms stay in the old style, in every row and in the park.
- `palm_b` built from the tall palm's generated model, fitted to `palm_b`'s own box (4.4 by 6.5 by 4.4 m, or 4.36 by 6.6 by 4.48 m) with its own far twin: every palm is new, the heights still run without a gap, and each placement keeps the piece it has today, so "today" and "new" captures compare like for like. From the tall palm the model is scaled 0.76 in height and 0.85 across; from the short one, 1.44 and 1.29. This is what I would do.
- `palm_b` taken out of `scenes` in a working copy's style.json: the hash then picks from two entries and most palms change piece (F2).
- A third palm object added to the image pack: the route's own answer, at the cost of an image.
- Voxel: either its palms stay trees (and change with objects 0 and 1), or two or three palm files are added under `assets/v2/` and `godot/styles/voxel/style.json:221-228` is pointed at them in the working copy. There is no voxel spec to size them by; the other kits' are above.

### What the pilot's tools need before this family

- `work/check.py:31, 71-79` applies its footprint rule to `tree_banyan` and `tree_large` only. These pieces need: the reach of the non-leaf surfaces in the band from the origin, with 0.25/R reported; one mesh node; two materials at most and their names; the far twin present with the same origin.
- `docs/research/2026-10-01-asset-to-sheet-pilot/tools/band.py:85-96` counts leaves and leaves parts out by node name. The game's rule here is by material name, and a radius, not a box.
- `work/asset_views.gd` has to find copies through `pack._planted` and the chunks' metas (F12).
- `work/build.py:233-259` copies one file for a piece; these need the far twin as well, and `palm_b`.
- `--tree W,D,BED,CROWN,HEIGHT` sizes a tree standing in a raised bed and lifts what lies outside the bed above 2.45 m. These trees have no bed; their "bed" is the 0.5 m the trunk's disc spans. Whether the option takes that was not tried.

## Not determined

- **How many copies each piece has.** The totals for a kind are counted; the split between pieces depends on Godot's `hash` of each position, which was not run. The table gives expected shares. A re-implementation of that hash written from memory of the engine's source, not checked against the engine, gives: `tree_round_a` 192 and `tree_round_b` 117 in lowpoly and neon, 144 and 165 in anime, 176 and 133 in solarpunk; `palm_a` 114, `palm_b` 92, `palm_c` 93 in all four; voxel `tree_medium` 323 and `tree_small` 285. Treat these as an estimate. The game can say: the chunks of `pack._planted[path]` list their `placement_ids`.
- **What is hidden behind buildings** in each view, and so how many trees a view really shows.
- **How the far swap behaves** at 90 m: which point of a chunk the engine measures to, and what the 4 m margins do. The code sets the ranges; the rest is the engine's.
- **Whether a working copy with a far file removed** falls back cleanly to the near piece at every distance. The code tests `ResourceLoader.exists` (`pack_3d.gd:812`); what that returns with the import file left behind was not tried.
- **What Godot's automatic LODs do** to a generated, textured tree or palm (F11).
- **The frame cost** of textured trees of 1,500 to 2,000 triangles, or more, at 100 to 300 copies each with shadows. Only the bench can say.
- **Whether a generated GLB passes the pinned Khronos validator** with no warning (WebP textures use an extension). Not run.
- **How any of this looks**: nothing was rendered.
- **Whether the fitting tool's `--tree`, `--parts` and `--core` can be made to give one mesh node and two named surfaces**, and whether its sizing can work about the trunk's foot instead of the box. Its options were read (`work/fit_generated.py:1-134`); its code was not.
