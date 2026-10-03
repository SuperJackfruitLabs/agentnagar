# Low planting: what the game expects of each kit piece

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

Written 2026-10-02 from the checkout at `agentnagar` (branch `docs/asset-to-sheet-pilot`), by reading code, specs, tests, the district fixture and the kit files. Nothing was run in Godot or Blender and nothing in the checkout was changed.

How to read the references. Client files are under `city/godot/` (`styles/pack_3d.gd`, `styles/kit_town.gd`, `tests/…`, `tools/…`, `core/…`). Kit builders, specs and kit tests are under `city/tools/styles/` (`lowpoly/…`, `anime/…`, `neon/…`, `solarpunk/…`, `voxel/…`, `shared/…`). `file:line` follows each claim.

Four kinds of statement are kept apart:

- **read**: stated by the code or data at the reference;
- **measured**: read out of a kit GLB (its JSON chunk and vertex data) or out of the engine's own cached import of it (`city/godot/.godot/imported/*.scn`, Godot 4.6), with a short Python script;
- **computed**: worked out by me from the code's rule and the fixture's numbers;
- **inferred**: my conclusion, not something a file says.

## Summary

1. The family is three catalogue kinds drawn three different ways. A **shrub** is one instance in a MultiMesh of its kit piece's first mesh. A **flowerbed** is the whole kit scene, placed under a holder node and stretched to its footprint. A **meadow** is a MultiMesh of two clump meshes drawn with the sway shader in place of their own materials.
2. For shrubs and meadow clumps the game takes **one mesh out of the file: the first `MeshInstance3D` in the scene tree**, with all of its surfaces and their materials, and drops every node transform (`kit_town.gd:81-91`, `133`). A second mesh in the file is never drawn, yet it still counts when the game measures the piece.
3. **Every shrub is drawn 2.1 m across**, whatever its file's width. The game scales it across by `1.05 m / reach`, where reach is the farthest anything in the file stands from the origin between 0.15 and 2.2 m up (`pack_3d.gd:388-393`, `kit_town.gd:237-246`). The four Blender kits build shrubs 1.1 m across, so they are drawn 1.91 times wider than built and 0.85 to 1.19 times their height. The design sheet's proportions (1.1 m across, 0.9 or 1.2 m high) are not what the game shows.
4. **The loose leafy shrub is drawn only in low-poly and solarpunk.** Neon and anime list only `shrub_round` for the shrub kind; their `shrub_leafy.glb` exists, has a spec and is tested, and no placement uses it. Voxel has one shrub file for both design objects.
5. There are **116 shrubs, 3 flowerbeds and 3 meadows** in the district. The meadows hold **192 clumps** in all (48, 96 and 48), about 30% of them the flowering clump. That is 16 clumps a square metre, not thousands.
6. **The sway shader has no texture input.** A meadow clump's colours must be vertex colours or flat material colours; a clump that carries its colour in a texture is drawn in its material's plain colour (white, for a generated model). It also needs a bend weight in the second UV layer and its root at height zero (`styles/shaders/sway.gdshader:4-6`, `56-82`).
7. **The flowerbed is drawn 3.30 by 1.30 m** (computed), whatever the file's size: about 10% longer and 24 to 30% deeper than the Blender kits build it. Voxel draws **two** 2 m beds end to end for each placement, each squeezed to 0.825 of its length.
8. **None of these pieces is found by `asset_views.gd` as it is written.** Shrubs and clumps are MultiMesh instances. A flowerbed's scene instance is a child of the node recorded for the placement, and the tool looks only at that node's own `scene_file_path`.
9. **The collision audit's budget is zero in every style**, held exactly by a client test. A shrub whose outline where people walk is not a full circle, or a flowerbed whose outline is not a full rectangle standing higher than 0.25 m, adds blocked-but-bare cells (inferred from the audit's rules).
10. **The standard views barely show this family.** No shrub stands within 49 m of the square's centre and none is in the park. The meadows are not drawn beyond 60 m, which rules out the diagonal and top-down presets, and they are behind the camera in the street view. Two flowerbeds are in the street view's frame, 30 m away.

Three points of the brief's background need correcting:

- Anime does not extend the lit pack. Neon and solarpunk extend `LitPack` (`styles/neon_noir/pack.gd:6`, `styles/solarpunk/pack.gd:6`); anime extends `Pack3D` and shades with `Toon` (`styles/anime_cel/pack.gd:7`, `44-45`). The lit packs' townscape does extend anime's (`styles/lit/townscape.gd:6`).
- "Filled to its footprint" is a fit both ways, not only a squeeze, and there are three routines. A `fill` scene is stretched or squeezed on x and z separately until its 0.15 to 2.2 m slice equals the drawn footprint, and moved so the slice is centred on it (`pack_3d.gd:719-734`). A `fit` prop (the flowerbed) is treated the same way module by module (`pack_3d.gd:1298-1317`). Tiled planting with `fill` (the shrub) is scaled evenly across about its origin, with no re-centring (`pack_3d.gd:292-295`, `388-393`).
- The meadow clumps' low triangle limits do not come from a large count. The limits (100 and 200) sit just above what the shared builder makes (70 and 146 triangles).

## Object 0: `shrub-round` (round clipped shrub)

| Style | Kit file | Spec size x, y, z (m) | Triangle limit (kit's piece) | Nodes the spec names | Materials in the kit's file | How placed and scaled | Instances | Scene instance | Needle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `assets/shrub_round.glb` | 1.1, 0.9, 1.1 | 1,500 (612) | `shrub_round`, `body` | `leaf_dark`, `leaf`, `leaf_yellow`, `leaf_light`: flat colours, two-sided, no texture, no vertex colours | MultiMesh; across x 1.909, height x 0.85 to 1.19, turned at random | part of 116 (shared with `shrub_leafy` by a hash of position) | no | `shrub_round` |
| `neon_noir` | `assets/shrub_round.glb` | 1.10, 0.82, 1.10 | 1,500 (670) | `shrub_round`, `body` | `baked_r75_m0` (vertex colours, two-sided), `foliage_leaves` (leaf cards: texture with alpha cut at 0.35, times vertex colour, one-sided) | as above | 116 | no | `shrub_round` |
| `anime_cel` | `assets/shrub_round.glb` | 1.10, 0.82, 1.10 | 1,500 (670) | `shrub_round`, `body` | as neon | as above | 116 | no | `shrub_round` |
| `solarpunk` | `assets/shrub_round.glb` | 1.10, 0.82, 1.10 | 1,500 (670) | `shrub_round`, `body` | as neon | as above | part of 116 (shared with `shrub_leafy`) | no | `shrub_round` |
| `voxel` | `assets/v2/shrub.glb` | 2.1, 0.8, 2.1 | 500 (410) | `bush` | `leaf`, `leaf_dark`, `leaf_dark+`, `leaf_dark-`, `leaf_light`: flat colours, one-sided | MultiMesh; across x 1.000, height x 0.85 to 1.19, turned at random | 116 (the one shrub for both design objects) | no | `=shrub.glb` |

Spec sources: `lowpoly/specs/vegetation.json:52-63` (`shrub_round`); `neon/specs/vegetation.json:8`; `anime/specs/vegetation.json:8`; `solarpunk/specs/vegetation.json:8`; `voxel/specs/props.json:14` (`shrub`).

Each needle matches one GLB file name in its style and no other (checked against every `.glb` under the style's `assets/`). It finds nothing in the game, because no shrub is a scene instance.

The kit's files as built (measured):

| Style | Hierarchy | Surfaces of the mesh (triangles) | Vertex data | Bounds (m) |
| --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `shrub_round` > `body` (mesh `body`) | `leaf_dark` 474, `leaf` 92, `leaf_yellow` 12, `leaf_light` 34 | position, normal | 1.100 x 0.897 x 1.100 |
| `neon_noir`, `anime_cel`, `solarpunk` | `shrub_round` > `body` (mesh `body`) | `baked_r75_m0` 436 (the solid mass and core), `foliage_leaves` 234 (the cards) | position, normal, `COLOR_0`, `TEXCOORD_0`; one embedded PNG, `foliage_leaves` | 1.100 x 0.820 x 1.100 |
| `voxel` | `shrub` > `bush` (mesh `bush`) | `leaf` 26, `leaf_dark` 146, `leaf_dark+` 22, `leaf_dark-` 8, `leaf_light` 208 | position, normal | 2.100 x 0.800 x 2.100 |

No file has node transforms, extras, animations or skins. In every file the reach between 0.15 and 2.2 m is exactly the half-width: 0.550 m in the four Blender kits, 1.050 m in voxel.

As the engine imports them (measured from the cached imports): the scene root is a new `Node3D` named `<file>2` (`shrub_round2`), the GLB's own root node is its child and keeps its name (`shrub_round`), and the mesh node is below that (`body`). The mesh resource is named `<file>_<mesh>` (`shrub_round_body`, `shrub_bush`). A material used by a surface with `COLOR_0` comes in with `vertex_color_use_as_albedo` on; a `doubleSided` material with culling off; `alphaMode: MASK` as alpha scissor with its cutoff. The leaf texture is pulled out beside the GLB as `shrub_round_foliage_leaves.png` (`gltf/embedded_image_handling=1` in every `.import`).

### How the game uses it

- **Skin.** `props.shrub` is `{"scenes": [...], "tiled": true, "fill": true}` in every style: `styles/lowpoly_tropical/style.json:238-245`, `styles/neon_noir/style.json:262-268`, `styles/anime_cel/style.json:251-257`, `styles/solarpunk/style.json:264-271`, `styles/voxel/style.json:233-239`. Low-poly and solarpunk list `shrub_round` and `shrub_leafy`; neon and anime list `shrub_round` alone; voxel lists `assets/v2/shrub.glb` alone.
- **Which file a shrub gets.** `_variant` picks from `scenes` by a hash of the shrub's position rounded to 10 cm (`pack_3d.gd:1287-1291`), so a given shrub is always the same variant.
- **Where they are.** The fixture scatters planting on a jittered 4.8 m lattice over the lawns and verges and 24 m beyond the district, a shrub being two of every ten plants (`city/fixtures/district/generate.py:817-822`, `867-908`). There are no hedges or rows of shrubs. Computed from `city/fixtures/district/manifest.json`: 116 shrubs, all facing 0; 105 stand outside every room, 10 in `room:uptown`, 1 in `room:south-streets`; none in the park or the square; the nearest to the square's centre is 49 m away.
- **How each is drawn.** `_placements` gathers every tiled placement by kit path and builds, for each, a transform: turned by its facing plus `hash(id) % 628 / 100` radians, height scaled by `0.85 + (hash(id) / 11 % 35) / 100` (0.85 to 1.19), width and depth scaled by `_planted_across` (`pack_3d.gd:285-297`). With `fill` and a footprint of one disc, `_planted_across` returns the disc's radius divided by the piece's reach (`pack_3d.gd:388-393`). The shrub kind's footprint is one disc of radius 105 cm (`city/catalogue/catalogue.json:317-327`). There is no per-instance colour: the MultiMesh is made with transforms only (`kit_town.gd:128-136`).
- **What the reach is.** `band_reach` loads the scene and takes the largest distance from the origin, in plan, of every vertex between 0.15 and 2.2 m and every point where an edge crosses those two heights, over **every visible mesh in the file**, with node transforms applied below the scene root (`kit_town.gd:214`, `237-246`, `262-281`, `299-315`). Leaves are left out only for `fill: "trunk"` (trees); a shrub counts whole.
- **What is drawn.** `_plant` calls `town.tiles(path, xforms, "Planting", true, ids)` (`pack_3d.gd:806-809`). `tiles` splits the copies into chunks of 32 m and makes one `MultiMeshInstance3D` a chunk, named `Planting` or `Planting_<i>_<j>` (`kit_town.gd:94-125`). Its mesh is `mesh_of(path)`: the scene root if it is a mesh, else the first `MeshInstance3D` found depth-first, and that node's mesh as it is (`kit_town.gd:81-91`). The instance transform is the only transform. Computed: the 116 shrubs stand in 33 of the 32 m cells, 1 to 10 to a cell; a style with two shrub files has a chunk for each file in each cell that file stands in.
- **Sizes as drawn (computed).** 2.10 m across in every style. Height 0.76 to 1.07 m in low-poly, 0.70 to 0.98 m in neon, anime and solarpunk, 0.68 to 0.95 m in voxel.
- **Shadows.** The chunks cast shadows (`tiles(..., true, ...)`, `kit_town.gd:151`). In neon, anime and solarpunk only chunks within `plant_shadow_m` (70 m) of the camera's ground point cast them (`pack_3d.gd:953-963`; `styles/neon_noir/style.json:533`, `styles/anime_cel/style.json:468`, `styles/solarpunk/style.json:511`). Low-poly and voxel set no such limit.
- **Distance.** A tiled piece with a `<piece>_far.glb` beside it swaps to that beyond 90 m (`pack_3d.gd:104-106`, `810-825`). No kit has a far shrub, so shrubs are drawn at every distance with no range set.
- **How to reach the placed copies.** `placement_nodes[id]` is the chunk holding the shrub (`style_pack.gd:39-42`, `235-238`; `pack_3d.gd:815-817`). Each chunk carries `placement_ids` and `instance_xforms` in instance order and `centre` (`kit_town.gd:140-150`). `pack._planted[path]`, keyed by the path as `style.json` writes it, is the node `tiles` returned (`pack_3d.gd:119-120`, `809`).

### Looked up by name, or done to it after loading

- **Nodes.** Nothing is looked up by name in a shrub. The lamp lookup (`find_child("light")`, `pack_3d.gd:767-777`) runs only for placements drawn as their own node (`pack_3d.gd:298-301`), which tiled planting is not.
- **Materials by name.** `mesh_of` passes every mesh of the file to `_collect` (`kit_town.gd:88-89`), which registers materials named `glass*`, `lamp_glow`, `window_glow`, `fairy_glow`, `light` and `neon*` for night lighting (`kit_town.gd:157-177`). In the styles with `wet_ground` (`styles/neon_noir/style.json:470`, `styles/anime_cel/style.json:469`, `styles/solarpunk/style.json:473`) any material whose name begins `paving`, `asphalt`, `kerb`, `road`, `path` or `street` turns dark and glossy in rain (`pack_3d.gd:115`, `2167-2183`).
- **Leaf cards.** A material whose name ends `_leaves` and is alpha-scissored gets alpha to coverage and receives no shadows: in the lit packs by `LitPack._style_node` (`styles/lit/lit_pack.gd:47-57`), in anime by `Toon.to_toon` (`styles/anime_cel/toon.gd:105-112`). The kits' `foliage_leaves` is the only such material here.
- **Anime.** `_style_node(world)` runs after the placements are built (`pack_3d.gd:216-220`). `Toon.apply` reaches a MultiMesh's mesh and turns each kit material toon in place when its resource path contains `anime_cel/`: toon diffuse and specular, roughness 0.32, rim 0.25 (`styles/anime_cel/toon.gd:30-54`, `79-101`). Textures are left alone. A replacement copied over the kit's file has the same path, so it is treated the same (inferred).
- **Anime's ink.** One full-screen pass inks every pixel whose neighbour's depth differs by more than 6% of the distance or whose normal differs by more than `1 - cos = 0.35` (about 49 degrees), fading out between 60 and 140 m (`styles/anime_cel/shaders/lines.gdshader:11-16`, `33-48`).
- **Nothing else.** No sway or wind shader (the only one is the meadow's), no recolouring by palette, no tint, no metadata read.
- **Import settings stay with the path.** The pilot's `place` step copies the GLB alone over the kit's (`work/build.py`, `place`), so the kit piece's committed `.import` file stays beside it and the replacement is imported with its settings. `shrub_round.glb.import` says `meshes/generate_lods=true`, `ensure_tangents=true` in low-poly, and `generate_lods=false`, `ensure_tangents=false`, `force_disable_compression=true` in neon, anime and solarpunk. Voxel's says `generate_lods=false`, which its kit test requires.

### What the builders do

- **Low-poly** (`lowpoly/vegetation.py:422-444`). `bush_mass`: a 32-sided drum of radius 0.55 m with upright sides to 0.4 m, rounding over to a low dome, "so that seen from above it is a circle wherever people walk. What grows on it stays inside that circle". On it, three jittered ico-sphere lobes (`round_shrub`, `399-405`). Every facet is then given one of four greens by the way it faces a fixed sun (`paint`, `59-78`): the shading is in the choice of material, flat-faced.
- **Anime** (`anime/vegetation.py:537-559`). The same drum, under a mound of leaf cards from the shared `foliage.py`: lobes, each a dark opaque core wrapped in square cards that carry a cluster of leaves from a shared alpha-masked atlas, tipped off the surface so that the outline is fringed with leaves; every vertex normal comes from a smooth field over the whole crown, "so a line pass that inks normal creases draws the crown's lobes, not every card" (`shared/foliage.py:5-20`, `393-449`). The piece is smooth-shaded at 50 degrees and its colours baked into vertex colours, leaving two materials (`shared/bake.py:1-16`, `86-116`; `anime/build.py:44-47`).
- **Neon.** Anime's builder, then leaves a shade darker (`neon/vegetation.py:65`, `276-279`).
- **Solarpunk.** Anime's builder in the solarpunk palette (`solarpunk/vegetation.py:418`).
- **Voxel** (`voxel/props.py:89-105`). A 32-sided drum of radius 1.05 m and 0.4 m high, "drawn as a 32-sided prism so its edge follows the disc", under a mound of 0.2 m bush blocks kept inside 0.99 of that radius, merged into one mesh because "the pack plants shrubs by the hundred from it". `voxel/voxel.py:261-264` says why one mesh: "a piece planted by the hundred is drawn from its first mesh alone".

### What the tests require beyond the spec

Kit tests:

- **Low-poly** (`lowpoly/test_assets.py`): size, triangles, nodes (`218-232`); every GLB has a spec (`234-237`); the pinned Khronos validator reports no error and no warning (`239-241`). It has no test that the files match a rebuild.
- **Anime, neon, solarpunk** (`anime/test_assets.py`; `shared/kittests.py` for the other two): the same, and `shrub_round` and `shrub_leafy` may have **two materials at most** (`anime/test_assets.py:87-93`; `shared/kittests.py:27`, `114-120`), and every committed GLB must be **byte for byte what the generator builds** (`anime/test_assets.py:101-116`; `shared/kittests.py:128-144`; skipped without Blender).
- **Voxel** (`voxel/test_assets.py`): the same size, triangle and node rule; no node other than the root may carry the asset's name (`226-229`); every spec has a recipe and every recipe a spec (`210-213`); no GLB without a spec (`232-234`); a rebuild must match the committed files (`236-247`, not skipped); the validator (`249-251`); and an `.import` beside every GLB with `meshes/generate_lods=false` (`253-257`).

All kit tests read the bounds from each `POSITION` accessor's `min` and `max` and count triangles from `indices`; the four Blender kits' reader falls back to the vertex count for a primitive without indices (`lowpoly/test_assets.py:64-97`), voxel's does not (`voxel/test_assets.py:82`).

Client tests that bear on a shrub:

- `tests/test_anime_pack.gd:146-172`: every shrub is drawn 1.05 m round where people walk (reach times scale), and shrubs grow to more than five different heights.
- `tests/test_collision_audit.gd:23-45`: each style's counts must **equal** `evidence/placement-budget.json`, which is zero for every gate in every style. The audit reads what each copy draws between 0.25 and 1.9 m, flattened, with whatever its faces enclose (`tools/collision_audit/solids_3d.gd:1-18`, `44`, `337-384`); "shrubs count whole" (`solids_3d.gd:13`). `reverse_blocked` counts cells inside a room that the grid blocks with nothing solid drawn within 10 cm (`tools/collision_audit/audit.gd:16-19`, `406-437`). The core blocks every cell whose centre is within 10 cm of a footprint (`city/crates/city-core/src/footprint.rs:10-12`).
- `tests/test_style_pack.gd:80-108`: every placement is drawn once and keyed by its ID.
- `tests/test_plant_shadows.gd:11-32`: planting chunks named `Planting*` cast shadows only near the view.

## Object 1: `shrub-leafy` (loose leafy shrub)

| Style | Kit file | Spec size x, y, z (m) | Triangle limit (kit's piece) | Nodes the spec names | Materials in the kit's file | How placed and scaled | Instances | Scene instance | Needle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `assets/shrub_leafy.glb` | 1.1, 1.2, 1.1 | 1,500 (528) | `shrub_leafy`, `body` | `leaf_dark`, `leaf`, `leaf_light`: flat colours, two-sided | MultiMesh; across x 1.909, height x 0.85 to 1.19, turned at random | the rest of the 116 | no | `shrub_leafy` |
| `neon_noir` | `assets/shrub_leafy.glb` | 1.10, 1.24, 1.10 | 1,500 (684) | `shrub_leafy`, `body` | `baked_r75_m0` (vertex colours, two-sided) | **not placed**: no skin names it | 0 | no | `shrub_leafy` |
| `anime_cel` | `assets/shrub_leafy.glb` | 1.10, 1.24, 1.10 | 1,500 (684) | `shrub_leafy`, `body` | `baked_r75_m0` | **not placed** | 0 | no | `shrub_leafy` |
| `solarpunk` | `assets/shrub_leafy.glb` | 1.10, 1.24, 1.10 | 1,500 (684) | `shrub_leafy`, `body` | `baked_r75_m0` | as low-poly | the rest of the 116 | no | `shrub_leafy` |
| `voxel` | none (the one `assets/v2/shrub.glb`, object 0) | | | | | | | | |

Spec sources: `lowpoly/specs/vegetation.json:64-75`; `neon/specs/vegetation.json:9`; `anime/specs/vegetation.json:9`; `solarpunk/specs/vegetation.json:9`.

The kit's files as built (measured): low-poly `shrub_leafy` > `body`: `leaf_dark` 420, `leaf` 60, `leaf_light` 48 triangles; position and normal only; 1.100 x 1.209 x 1.100 m. Neon, anime and solarpunk `shrub_leafy` > `body`: one surface, `baked_r75_m0`, 684 triangles; position, normal, `COLOR_0`; no texture and no leaf cards; 1.100 x 1.241 x 1.100 m. Reach 0.550 m in all four.

### How the game uses it

Everything under object 0 holds, with these differences.

- **Where it is drawn.** Only where `props.shrub.scenes` names it: low-poly (`styles/lowpoly_tropical/style.json:239-242`) and solarpunk (`styles/solarpunk/style.json:265-268`). In neon and anime the list holds `shrub_round` alone (`styles/neon_noir/style.json:263-265`, `styles/anime_cel/style.json:252-254`), and no script of the 3D packs names the file (`shrub` does not occur in `main.gd`, `styles/*.gd`, `styles/lit/` or any 3D style's `pack.gd`, `townscape.gd`, `look.gd` or `toon.gd`). Replacing `shrub_leafy.glb` in neon or anime changes nothing on screen unless the working copy's `style.json` gains the second entry.
- **How many.** The 116 shrubs are split between the two files by `hash(Vector2i(...)) % 2` (`pack_3d.gd:1291`). The split was not computed; about half each is to be expected.
- **Sizes as drawn (computed).** 2.10 m across; 1.03 to 1.44 m high in low-poly, 1.05 to 1.48 m in solarpunk.
- **Import settings.** `shrub_leafy.glb.import` says `generate_lods=true`, `ensure_tangents=true` in all four styles.

### Looked up by name, or done to it after loading

As object 0. It has no leaf-card material, so the alpha-to-coverage rule touches nothing in it.

### What the builders do

- **Low-poly** (`lowpoly/vegetation.py:408-419`, `447-452`): the same drum, crowned with a rosette of 13 big folded blades in three greens.
- **Anime, and through it neon and solarpunk** (`anime/vegetation.py:524-534`, `562-567`; `neon/vegetation.py:356`; `solarpunk/vegetation.py:419`): the drum and a rosette of 13 arching fronds, smooth-shaded at 50 degrees, baked to vertex colours.
- **Voxel:** no leafy shrub is built.

### What the tests require beyond the spec

As object 0. The two-materials rule names `shrub_leafy` as well. In neon and anime the kit tests still hold the unused file to its spec, to the validator and to the rebuild.

## Object 2: `flowerbed` (kerbed flowerbed)

| Style | Kit file | Spec size x, y, z (m) | Triangle limit (kit's piece) | Nodes the spec names | Materials in the kit's file | How placed and scaled | Instances | Scene instance | Needle |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `assets/flowerbed.glb` | 3.0, 0.6, 1.0 | 1,500 (1,308) | `flowerbed`, `body` | ten flat colours, two-sided: `sandstone`, `soil`, `leaf`, `leaf_dark`, `leaf_yellow`, `leaf_light`, `pink`, `jackfruit`, `white`, `coral` | whole scene under a holder; x 1.100 long, x 1.300 deep, height as built | 3 | yes, one level below the placement's node | `flowerbed` |
| `neon_noir` | `assets/flowerbed.glb` | 3.04, 0.6, 1.02 | 1,500 (1,264) | `flowerbed`, `body`, `lights` | `baked_r75_m0` (vertex colours), `foliage_leaves` (leaf cards), `lamp_glow` (emissive, strength 3.2) | x 1.087 long, x 1.275 deep | 3 | as above | `flowerbed` |
| `anime_cel` | `assets/flowerbed.glb` | 3.02, 0.58, 1.05 | 1,500 (1,216) | `flowerbed`, `body` | `baked_r75_m0`, `foliage_leaves` | x 1.087 long, x 1.275 deep | 3 | as above | `flowerbed` |
| `solarpunk` | `assets/flowerbed.glb` | 3.02, 0.58, 1.05 | 1,500 (1,192) | `flowerbed`, `body` | `baked_r25_m0`, `baked_r50_m0`, `baked_r75_m0` (vertex colours, no leaf cards) | x 1.093 long, x 1.240 deep | 3 | as above | `flowerbed` |
| `voxel` | `assets/v2/flowerbed.glb` | 2.0, 0.5, 1.0 | 650 (474) | `bed` | seven flat colours, one-sided: `flower_pink`, `flower_white`, `flower_yellow`, `kerb`, `leaf`, `leaf_light`, `soil` | **two copies end to end**, each x 0.825 long, x 1.300 deep | 6 (two a placement) | as above | `flowerbed` |

Spec sources: `lowpoly/specs/vegetation.json:76-87`; `neon/specs/vegetation.json:10`; `anime/specs/vegetation.json:10`; `solarpunk/specs/vegetation.json:10`; `voxel/specs/props.json:9`.

The scales are computed: the drawn rectangle (3.30 by 1.30 m, below) over each kit file's slice between 0.15 and 2.2 m (measured, and the same by the earlier pilot's `band.py`: 3.000 x 1.000 in low-poly, 3.037 x 1.020 in neon and anime, 3.020 x 1.049 in solarpunk, 2.000 x 1.000 in voxel).

The kit's files as built (measured):

| Style | Hierarchy | Surfaces (triangles) | Vertex data | Bounds (m) |
| --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `flowerbed` > `body` | `sandstone` 176, `soil` 12, `leaf` 213, `leaf_dark` 279, `leaf_yellow` 23, `leaf_light` 125, `pink` 120, `jackfruit` 180, `white` 120, `coral` 60 | position, normal | 3.000 x 0.617 x 1.000 (from 0.026 m below the ground) |
| `neon_noir` | `flowerbed` > `body`, `lights` (`lights` moved up 0.33 m) | `body`: `baked_r75_m0` 722, `foliage_leaves` 494; `lights`: `lamp_glow` 48 | `body`: position, normal, `COLOR_0`, `TEXCOORD_0`; `lights`: position, normal; one embedded PNG | 3.037 x 0.600 x 1.020 |
| `anime_cel` | `flowerbed` > `body` | `baked_r75_m0` 722, `foliage_leaves` 494 | as neon's `body` | 3.037 x 0.600 x 1.020 |
| `solarpunk` | `flowerbed` > `body` | `baked_r25_m0` 176, `baked_r50_m0` 176, `baked_r75_m0` 840 | position, normal, `COLOR_0` | 3.020 x 0.584 x 1.049 |
| `voxel` | `flowerbed` > `bed` | `flower_pink` 38, `flower_white` 88, `flower_yellow` 54, `kerb` 80, `leaf` 22, `leaf_light` 120, `soil` 72 | position, normal | 2.000 x 0.500 x 1.000 |

The kerbs stand 0.26 m high in low-poly (`lowpoly/vegetation.py:466`), 0.28 m in anime, neon and solarpunk (`anime/vegetation.py:606`, `solarpunk/vegetation.py:301`) and 0.30 m in voxel (`voxel/props.py:158-159`).

### How the game uses it

- **Skin.** `props.flowerbed` is `{"scene": ..., "fit": [length, depth]}`: `[3.0, 1.0]` in the four Blender kits (`styles/lowpoly_tropical/style.json:250-256`, `styles/neon_noir/style.json:273-279`, `styles/anime_cel/style.json:262-268`, `styles/solarpunk/style.json:276-282`) and `[2.0, 1.0]` in voxel (`styles/voxel/style.json:244-250`). It has no `fill` and no `tiled`.
- **Where they are.** Three placements, all facing 0 and all inside rooms: `placement:plaza-bed-1` and `-2` at (-11.0, -12.25) and (11.0, -12.25) m in the square, `placement:park-bed` at (-26.5, 23.75) m in the park (`city/fixtures/district/generate.py:412`, `453`; the manifest). The kind's footprint is one rectangle, 3.10 by 1.10 m about its point (`city/catalogue/catalogue.json:339-349`).
- **How each is drawn.** For a skin with `fit`, `_placement` makes an empty `Node3D` named `Flowerbed`, takes the footprint's rectangle, widens it to the cells the walking grid blocks (`CityGeometry.drawn_rect`), and hands it to `_fit_prop` (`pack_3d.gd:409-418`). `_fit_prop` lays `n = max(1, round(length / fit[0]))` copies of the scene along the long side. Each copy is scaled by `(length / n / box.x, 1, depth / box.z)`, where the box is the bounds of what the whole scene draws between 0.15 and 2.2 m, and is placed so that the box's middle, not the piece's origin, sits on the middle of its share (`pack_3d.gd:1298-1317`; `kit_town.gd:224-229`, `251-256`). Height is never scaled. Every mesh in the file counts toward the box, neon's `lights` included.
- **The drawn rectangle (computed).** `drawn_rect` moves each edge out to 2.5 cm past the centres of the blocked cells (`core/city_geometry.gd:186-197`); the grid's origin is the rooms' least corner (`city/crates/city-core/src/nav.rs:132-136`), which in the fixture is (-7200, -6650) cm. For all three beds this gives 3.30 by 1.30 m. `evidence/placement-kind-sizes.json:1902` records 330 to 335 by 130 to 135 cm as measured in each style, on a 5 cm raster, which agrees.
- **Voxel draws two.** With `fit[0] = 2.0`, `round(3.30 / 2.0)` is 2: two copies of the 2 m bed, each 1.65 m long as drawn, each with its own kerb at both ends. The evidence file shows the two halves (`"-170,-70,0,65"` and `"-5,-70,165,65"`).
- **The whole scene is used.** Each copy is `packed.instantiate()` of the GLB (`pack_3d.gd:150-156`, `1312`): every node, mesh, surface, material and texture in the file is drawn, with node transforms.
- **No randomness.** No turn, growth or tint. Three copies of one piece look identical.
- **Shadows and distance.** Nothing sets either: it casts and receives shadows as any mesh and is drawn at every distance.
- **How to reach the placed copies.** `placement_nodes[id]` is the holder (`pack_3d.gd:298-300`; `style_pack.gd:228-230`), whose own `scene_file_path` is empty. Its children are the scene instances, one a module: each child's `scene_file_path` names the GLB (as the pilot's captures of seats and trees already rely on) and its `scale` is the stretch the game gave. `asset_views.gd` tests only the recorded node's own `scene_file_path` (`.asset-pilot/2026-10-02-sheet-to-asset/work/asset_views.gd:86-91`), so it finds no flowerbed until it also looks at that node's children. The same holds for every skin drawn through a holder: `fit` props and perches (`pack_3d.gd:409-418`, `437-458`).

### Looked up by name, or done to it after loading

- **`light`.** After a placement is drawn, `_light` looks under it for a node named exactly `light` and, if there is one, adds a warm lamp of 8 m range at the middle of its mesh, lit from dusk (`pack_3d.gd:298-301`, `767-777`; `kit_town.gd:68-77`). No kit flowerbed has one.
- **`lights`.** The lit packs add a lamp at a node named `lights` only for the pieces a style lists under `glow_lights` (`styles/lit/lit_pack.gd:93-105`). Neon lists `tree_banyan` alone (`styles/neon_noir/style.json:528-530`), so the neon bed's `lights` only glows: it lights no ground. The node is there because neon's spec names it (`neon/specs/vegetation.json:10`).
- **`lamp_glow`.** `_fit_prop` passes each copy to `_collect` (`pack_3d.gd:1317`), which keeps materials named `lamp_glow`, `window_glow`, `fairy_glow` or `light` (`kit_town.gd:174-175`). Their emission strength is set to the style's `window_energy` while the lamps are on and to 0.35 by day, in place of the strength the file gives (`pack_3d.gd:2056-2064`; neon's is 1.1, `styles/neon_noir/style.json:523`). `_collect` does not switch emission on for these: the material must already be emissive in the file.
- **Rain.** In neon, anime and solarpunk a material whose name begins `kerb`, `path`, `paving`, `road`, `street` or `asphalt` darkens and turns glossy as it rains (`pack_3d.gd:115`, `2167-2183`). The Blender kits' beds have no such name. Voxel's bed has a `kerb` material, and voxel has no `wet_ground`.
- **Leaf cards, anime's toon and ink.** As object 0: `foliage_leaves` gets alpha to coverage and no received shadows in neon and anime; anime turns every kit material toon in place and inks sharp changes of depth and normal.
- **Import settings.** `flowerbed.glb.import` says `generate_lods=true`, `ensure_tangents=true` in low-poly and solarpunk; `generate_lods=false`, `ensure_tangents=false` in neon and anime; `generate_lods=false`, `ensure_tangents=true` in voxel.

### What the builders do

- **Low-poly** (`lowpoly/vegetation.py:461-486`): four bevelled sandstone kerb boxes on the 3.0 by 1.0 m outline, a soil box, eight faceted leaf mounds painted by facing, and eight clusters of three faceted blossoms in pink, yellow, white and coral.
- **Anime** (`anime/vegetation.py:590-630`): a stone kerb with a paler coping, soil, seven lobes of leaf cards round one long core fitted to 3.0 by 1.0 m between 0.14 and 0.55 m, and 22 star-shaped flowers with yellow eyes. Baked to vertex colours.
- **Neon** (`neon/vegetation.py:284-294`): anime's bed with darker leaves and violet for pink, plus `lights`: four lamp boxes of 0.08 by 0.08 by 0.1 m on the kerb's corners at (+-1.45, +-0.45) m and 0.33 m up, in `lamp_glow`, the node's origin moved to that height.
- **Solarpunk** (`solarpunk/vegetation.py:295-323`): a white ceramic kerb under a warm white coping, seven smooth leaf puffs (no cards), 36 flowers in four colours.
- **Voxel** (`voxel/props.py:108-130`, `153-163`): a kerb one voxel thick and 0.3 m high on the 2.0 by 1.0 m outline ("so the bed's edge is drawn where people walk"), soil, a mound of 0.2 m bush blocks, and single-voxel flowers on about a fifth of the mound's top cells.

### What the tests require beyond the spec

- **Kit tests.** As object 0, without the two-materials rule (it names only trees, palms and shrubs). In neon the spec's nodes include `lights`.
- **Collision audit.** The three beds stand in rooms, so every gate applies to them (`tests/test_collision_audit.gd:23-45`; `tools/collision_audit/audit.gd:16-19`). The audit sees only what is drawn between 0.25 and 1.9 m.
- **Placement.** `tests/test_style_pack.gd:80-108`: each bed drawn once, the holder keyed by its ID.

## Object 3: `meadow` (two clumps: tall grass, and grass with flowers)

One design-sheet cell holds two kit pieces. Both are needed: a client test requires two different clump meshes (`tests/test_things_to_use.gd:263`).

| Style | Kit files | Spec size x, y, z (m): grass; flowers | Triangle limit (kit's piece): grass; flowers | Nodes the spec names | Materials in the kit's files | How placed and scaled | Instances | Scene instance | Needles |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `assets/meadow_grass.glb`, `assets/meadow_flowers.glb` | 0.33, 0.88, 0.31; 0.33, 0.89, 0.3 | 100 (70); 200 (146) | `meadow_grass`, `body`; `meadow_flowers`, `body` | flat colours, two-sided. Grass: `grass`, `leaf`, `leaf_light`. Flowers: those and `leaf_dark`, `pink`, `jackfruit_dark`, `jackfruit`, `white`, `coral` | MultiMesh with the sway shader; every clump x 0.80 to 1.15 evenly, turned and nudged at random | 192 clumps, about 30% flowers | no | `meadow_grass`, `meadow_flowers` |
| `neon_noir` | as above | as above | as above | as above | one material each, `baked_r75_m0` (vertex colours, two-sided) | as above | 192 | no | as above |
| `anime_cel` | as above | as above | as above | as above | `baked_r75_m0` | as above | 192 | no | as above |
| `solarpunk` | as above | as above | as above | as above | `baked_r75_m0` | as above | 192 | no | as above |
| `voxel` | `assets/v2/meadow_grass.glb`, `assets/v2/meadow_flowers.glb` | 0.33, 0.89, 0.29; 0.31, 0.88, 0.27 | 200 (180); 200 (174) | `grass`; `grass` | flat colours, one-sided. Grass: `lawn`, `lawn_dark`, `leaf_light`. Flowers: those and `leaf_dark`, `flower_pink`, `flower_white`, `flower_yellow` | as above | 192 | no | as above |

Spec sources: `lowpoly/specs/vegetation.json:134-145` and `146-157`; `neon/specs/vegetation.json:18-19`; `anime/specs/vegetation.json:18-19`; `solarpunk/specs/vegetation.json:18-19`; `voxel/specs/props.json:28-29`.

The kit's files as built (measured):

| Style | Hierarchy | Surfaces (triangles) | Vertex data | Bounds (m) |
| --- | --- | --- | --- | --- |
| `lowpoly_tropical` | `meadow_grass` > `body`; `meadow_flowers` > `body` | grass: `grass` 25, `leaf` 25, `leaf_light` 20. Flowers: `grass` 25, `leaf` 25, `leaf_light` 20, `leaf_dark` 20, `pink` 10, `jackfruit_dark` 16, `jackfruit` 10, `white` 10, `coral` 10 | position, normal, `TEXCOORD_0`, `TEXCOORD_1` | 0.332 x 0.883 x 0.310; 0.330 x 0.888 x 0.297 |
| `neon_noir`, `anime_cel`, `solarpunk` | the same nodes | one surface each, `baked_r75_m0`: 70; 146 | the same and `COLOR_0` | the same |
| `voxel` | `meadow_grass` > `grass`; `meadow_flowers` > `grass` | grass: `lawn` 60, `lawn_dark` 60, `leaf_light` 60. Flowers: `flower_pink` 10, `flower_white` 10, `flower_yellow` 10, `lawn` 40, `lawn_dark` 40, `leaf_dark` 24, `leaf_light` 40 | position, normal, `TEXCOORD_0` (all zero), `TEXCOORD_1` | 0.335 x 0.891 x 0.296; 0.319 x 0.875 x 0.276 |

In every file `TEXCOORD_1`'s first component runs from 0 to 1. No file has a texture. Every clump stands on height 0, its blades rooted within a few centimetres of the origin.

### How the game uses it

- **Skin.** `props.meadow` is `{"meadow": [grass, flowers]}` in every style, with no `spacing` and no `flowers` key, so the defaults hold: `styles/lowpoly_tropical/style.json:286-291`, `styles/neon_noir/style.json:309-314`, `styles/anime_cel/style.json:298-303`, `styles/solarpunk/style.json:312-317`, `styles/voxel/style.json:280-285`.
- **Where they are.** Three sized placements in the park's south half: `placement:park-meadow-1` 2.0 by 1.5 m at (-32.5, 25.5), `-2` 3.0 by 2.0 m at (-26.0, 28.5), `-3` 2.0 by 1.5 m at (-22.5, 29.0) (`city/fixtures/district/generate.py:446-456`; the manifest). The kind has no footprint and one soft shape, and is sized (`city/catalogue/catalogue.json:361-372`).
- **How many.** `_meadow` plants `floor(width / 0.25)` by `floor(depth / 0.25)` clumps on each lot (`pack_3d.gd:322-327`, `347-353`): 8 x 6, 12 x 8 and 8 x 6, **192 in all** (computed). A clump is the flowering one when `hash % 100 < 30` (`pack_3d.gd:325`, `361-362`), so about 58 flower and 134 grass clumps; the exact split was not computed. At the kit's triangle counts that is about 18,000 triangles for all three meadows; at the limits, 25,000.
- **How each is placed.** The clumps are counted over the whole lot but planted over the lot less a margin, the larger clump's reach times 1.15, so every clump stays wholly inside (`pack_3d.gd:354-358`). The reach here is the mesh's bounding box corner seen from above, `sqrt(max|x|^2 + max|z|^2)` (`pack_3d.gd:376-380`): 0.247 m for the kit's grass clump, a margin of 0.284 m (computed). Each clump is nudged by up to 30% of a step, turned by `hash / 1587600 % 628 / 100` radians, and scaled evenly on all three axes by `0.8 + (hash / 100 % 36) / 100`, 0.80 to 1.15 (`pack_3d.gd:359-371`). With the kit's clumps the steps come to 0.16 to 0.20 m (computed). A larger clump means a larger margin and clumps packed closer.
- **What is drawn.** For each of the two paths, `town.tiles(path, xforms, "Meadow", false, ids, true)` (`pack_3d.gd:308-312`): chunked MultiMeshes of the file's **first mesh** (`kit_town.gd:81-91`), casting **no shadows**, with per-instance custom data for the push (`kit_town.gd:128-134`, `151`). Each chunk is given `visibility_range_end = 60` m with a 4 m margin (`pack_3d.gd:315-318`, `328-330`).
- **The materials are replaced.** After the style's finishing pass, `_sway_materials` gives every meadow chunk a copy of its mesh, rebuilt from its arrays (which drops any LODs), on which each surface whose material is a `BaseMaterial3D` draws with a sway `ShaderMaterial` instead (`pack_3d.gd:216-221`, `515-538`). The sway material copies from the kit material its colour, whether vertex colours are used as the colour, roughness, metallic, specular, rim, its culling and whether it is toon; it keeps the material's name and keeps the kit material as meta `sway` (`pack_3d.gd:548-593`). Nothing else is carried over.
- **The shader.** `sway.gdshader` declares no sampler. Its colour is `albedo`, times the vertex colour when `use_vertex_colour` is set, mixed up to 35% toward the style's `tint` while bent (`styles/shaders/sway.gdshader:14-20`, `25-28`, `71-82`). Its own header says the kit material it stands in for is "a StandardMaterial3D with a colour, perhaps vertex colours, and no textures" (`sway.gdshader:4-6`). In the vertex stage each vertex moves sideways by push x lean x `UV2.x` x `max(VERTEX.y, 0)` and sinks a little (`sway.gdshader:56-69`). The styles' `sway` blocks set stiffness and tint (`styles/lowpoly_tropical/style.json:467`, `styles/neon_noir/style.json:514`, `styles/anime_cel/style.json:484`, `styles/solarpunk/style.json:499`, `styles/voxel/style.json:454`).
- **Contacts.** `SoftContacts` pushes the clumps whose root lies within 0.25 m plus the clump's reach of a body, for people within 15 m of the view's focus (`core/soft_contacts.gd:25-37`, `175-192`, `386-434`; `core/style_host.gd:164-165`). The reach it uses is the same bounding-box reach times 1.15 (`pack_3d.gd:314-319`).
- **How to reach the placed copies.** `placement_nodes[id]` is one of the chunks (`pack_3d.gd:315-316`). The chunks are found by name (`find_children("*Meadow*", "MultiMeshInstance3D")`, as `tests/test_sway.gd:151` does) or through `pack._soft_chunks` (`pack_3d.gd:333-334`). Each carries `placement_ids`, `instance_xforms` and `centre`. Nothing records which GLB a chunk draws; the copy keeps the kit mesh's `resource_name` (`pack_3d.gd:532`), which the engine set to `<file>_<mesh>` (measured: `meadow_grass_body`, `meadow_flowers_grass`).

### Looked up by name, or done to it after loading

- **By name:** nothing. No node, surface or material name is read, except that `mesh_of` passes the file's materials to `_collect` (`kit_town.gd:88-89`).
- **Anime.** The toon pass runs before the sway materials are made (`pack_3d.gd:220-221`), so the sway shader's toon variant is used, with the toon roughness and rim (`pack_3d.gd:573-593`; `tests/test_sway.gd:167`).
- **Culling** follows the kit material: two-sided in the Blender kits, back faces culled in voxel (`pack_3d.gd:575-581`).
- **Import settings.** Every meadow `.import` says `generate_lods=false`, `ensure_tangents=true`.

### What the builders do

- **The four Blender kits** share `shared/usables.py:224-358`. A grass clump is 14 blades about 0.2 m round the origin and 0.5 to 0.9 m high. Each blade is a strip of three segments, one face thick, tapering to a point. The flowering clump adds four stems, each with a flat five-petal head and a centre. Each vertex records a bend weight, its height fraction along the blade (0 at the root, 1 at the tip and over the whole flower head), written into a second UV map as `(weight, 0)` (`bend_uv`, `331-347`). Each vertex's normal comes from a smooth field, "mostly up, leaning out from its middle", so that "a clump is lit as one soft tuft, and a line pass that inks normal creases does not ink every blade" (`254-284`). The kits differ only in the palette names they pass (`lowpoly/vegetation.py:541-548`, `anime/vegetation.py:667-674`, `neon/vegetation.py:337-343`, `solarpunk/vegetation.py:400-406`); low-poly keeps one material a colour, the others bake to vertex colours.
- **Voxel** (`voxel/things.py:163-205`; `voxel/voxel.py:276-308`, `436-439`): nine blades (six with three flowers), each two stacked boxes 3.5 cm thick, the upper stepping out and narrowing; a flower is a thin stem with a 7 cm blossom block. Each box's bottom and top carry the bend weights, written as `TEXCOORD_1`'s first component.

### What the tests require beyond the spec

- **Kit tests.** As object 0, without the two-materials rule.
- **`tests/test_things_to_use.gd:228-285`**, in all five styles: every meadow chunk has `visibility_range_end` 60; every clump stands wholly inside its lot; each meadow has at least 90% of one clump per 0.0625 m2; no two clumps of a meadow stand closer than 4.5 cm; there are exactly two clump meshes; **every surface carries UV2**; UV2's first component runs from 0 to 1 over the mesh, is below 0.01 on some vertex below 1 cm, and above 0.99 on some vertex above 0.4 m.
- **`tests/test_sway.gd:145-171`**: every surface of every meadow chunk draws with a `ShaderMaterial` that has meta `sway`, the style's stiffness and tint, the kit material's colour and its vertex-colour setting; no other MultiMesh carries custom data. A surface whose material is not a `BaseMaterial3D` is left as it is (`pack_3d.gd:537`) and fails this.
- **`tests/test_sway.gd:59-94`**: clumps on a walker's path bend, clumps a metre off stay still, all settle within a second.
- **`tests/test_frame_cost.gd:131-184`**: sixty walkers crossing the three meadows must cost 0.3 ms a frame or less in the contact step.
- **Collision audit.** A clump drawn wholly inside its lot is no solid; one reaching past it counts (`tools/collision_audit/solids_3d.gd:15-16`, `296-298`). The planting margin keeps the kit's clumps inside.

## Where the standard views show them (computed from the code and the fixture; nothing was captured)

The presets are `topdown`, `diagonal` and `street` (`core/orbit_rig.gd:8`, `68-93`, `175-190`). `tools/sheet_views.gd:83-101` adds an eye view named `park`, and `gathering` and `night-rain`, which are the street preset at other hours.

- **`street`:** the camera stands at about (-2.9, 1.7, 16.7) m looking north across the square. The two plaza beds are in the frame, 30 and 32 m away, about 110 pixels long at 1920 by 1080, beyond the great tree. The park bed and the meadows are behind the camera. Thirty-six shrubs lie inside the frustum, the nearest 63 m away.
- **`diagonal`:** the camera is about 66 m from its target, to the south-east and 39 m up. All three beds are in the frame at 75 to 88 m. The meadows are in the frame's area at 70 to 79 m, beyond their 60 m range, so they are not drawn. Twenty-five shrubs lie inside the frustum, the nearest 103 m away.
- **`topdown`:** the camera is about 143 m up. Meadows are not drawn. A shrub is about 19 pixels across.
- **`park` eye view** (from (-41.5, 1.7, 33.0), looking north along the waterfront): none of the park's meadows or its bed is in the frame.
- **The map's picture** is taken from 200 m up (`pack_3d.gd:2293-2295`, `2327-2335`), beyond the meadows' range.
- **The one existing close view of a meadow** is `tools/probes/capture_interact.gd`'s `sway` shot (`34`, `199-239`): the orbit camera 4.5 m from the middle of `placement:park-meadow-2`.

Whether anything stands in front of a piece in these views was not worked out.

## What a generated replacement must keep or put back by rule

### All four objects

1. **Names.** The root node carries the kit's root name and the mesh node the kit's part name: `body` in the four Blender kits; `bush`, `bed` and `grass` in voxel. The specs name them, and the fit tool's `--kit` and `--name` already carry the root name. In voxel no part may share the root's name.
2. **Material names the game acts on.** Do not use `light`, `lamp_glow`, `window_glow`, `fairy_glow`, anything beginning `glass` or `neon`, or anything beginning `paving`, `asphalt`, `kerb`, `road`, `path` or `street`, unless that behaviour is wanted. The fit tool's `sheet_albedo` is safe.
3. **The kit's own suites cannot pass a swapped file.** In anime, neon, solarpunk and voxel every committed GLB must be byte for byte what the generator builds. A replacement can meet the size, triangle, node and material rules, but it fails the rebuild test for as long as it is not made by the kit's generator. Low-poly has no such test.
4. **The capture tool.** `asset_views.gd` as written finds none of these pieces (see each object for where the copies are). A shrub or a clump has no scene to find, so its entry in `assets.json` takes no needle; the flowerbed's needle works once the tool looks at the children of the placement's node.

### `shrub-round` and `shrub-leafy`

1. **One mesh, and it is the first.** All that is to be drawn must be in the first mesh node, in final coordinates: y up, the origin on the ground at the middle of the bush, no node transform. Any number of surfaces is drawn, but anime, neon and solarpunk hold the file to two materials. A part put back by rule (a drum, a core) has to be joined into that mesh, not added as a second node: a second mesh is not drawn and still changes the measured reach.
2. **The game sets the width.** Width as drawn is always 2.10 m: scale across = 1.05 / (largest distance from the origin of anything between 0.15 and 2.2 m). To be drawn as the kit's piece is, keep that reach at 0.55 m in the four Blender kits and 1.05 m in voxel, measured about the origin. A piece that is off-centre, or has one long leaf in that band, is drawn smaller and lopsided; a piece that is widest below 0.15 m is drawn too large there. The spec's width (1.1 m, or 2.1 m in voxel, within 10% and 2 cm) is on the whole file, so the two agree only if the widest part lies between 0.15 and 2.2 m.
3. **Expect the squash.** In the four Blender kits the shrub is drawn 1.91 times wider than built and 0.85 to 1.19 times as high. A model built to the design sheet's 1.1 by 0.9 m comes out about 2.1 by 0.77 to 1.07 m. Texture detail is stretched the same way. (Voxel builds at 2.1 m and is not stretched across.)
4. **Put back the circle.** Seen from above, everything the piece draws between 0.25 and 1.9 m as placed must fill a circle about the origin, of the reach's radius. It is enough that what the model draws between 0.30 and 1.59 m of its own height fills that circle: those heights are inside the audit's band at every growth factor from 0.85 to 1.19. The kits do it with a drum: 32 sides, radius 0.55 m (1.05 m in voxel), upright from the ground to 0.4 m, with everything that grows on it kept inside. A round clipped shrub generated as a ball and centred on its origin already has a round outline; a loose leafy one does not, and a voxelised one cannot follow a disc on a 10 cm grid. This is inferred from the audit's rules and the zero budget; it bites at the 11 shrubs that stand inside a room.
5. **Triangles.** 1,500 a shrub in the four Blender kits and 500 in voxel, for 116 copies spread over 33 chunk cells. The kits use 410 to 684.
6. **Colour.** A texture works here: the MultiMesh draws the mesh's own materials. All copies share it; none is tinted.
7. **What is given up.** In low-poly, the facet-by-facet greens painted against a fixed sun. In anime, neon and solarpunk's round shrub, the leaf cards' fringed outline, the dark core, the crown-wide smooth normals and the alpha-to-coverage edge. In all, the rosette of 13 large leaves on the leafy shrub. For anime, give the leaf masses smooth, rounded normals (the fit tool's `--leaf-smooth` and `--leaf-round` were made for this on the tree) or the ink pass will line every facet.
8. **`shrub-leafy` needs a place to be seen.** In neon and anime, add `assets/shrub_leafy.glb` to `props.shrub.scenes` in the working copy's `style.json`, or nothing draws it. In voxel there is no second file: either one shrub is chosen for `assets/v2/shrub.glb`, or the working copy gains a second file and a second `scenes` entry (the checkout's voxel kit would also need a spec and a recipe for it).

### `flowerbed`

1. **The whole file is drawn**, so several meshes and materials are fine and a texture works.
2. **The game sets length and depth.** The slice between 0.15 and 2.2 m is stretched to 3.30 by 1.30 m and centred by its own box. Build to the kit's box and expect about 10% more length and 24 to 30% more depth; nothing is scaled in height. Everything in that slice counts, lamps included, and nothing may reach outside the intended outline in it.
3. **Put back the kerb as a full rectangle, higher than 0.25 m.** The outermost thing the piece draws between 0.25 and 1.9 m must be the whole rectangle, corners included. The kits' kerbs stand 0.26 to 0.30 m. A kerb of 0.15 to 0.25 m would set the stretch and then be invisible to the audit; a bed with rounded ends or a broken edge leaves blocked cells bare. By my arithmetic a corner rounded by more than about 30 cm as drawn does so. All three beds stand in rooms, so this is gated. Inferred, as for the shrub.
4. **Neon.** The spec requires a node `lights`. Carrying the kit's across (`--kit-lights`) keeps its four lamp boxes at the kit's coordinates, on the kit's kerb corners; they need to sit on the new kerb. Their material must be named `lamp_glow` and be emissive in the file. Do not name the part `light` unless a lamp lighting the ground is wanted.
5. **Voxel.** As the skin stands, the game draws two 2 m modules, each squeezed to 0.825 of its length, with kerbs meeting in the middle of the bed. A bed generated from the sheet's single 3 m bed and fitted to the 2.0 by 0.5 by 1.0 m spec box is drawn twice. To draw one bed, the working copy's `fit` must become `[3.0, 1.0]`, and the file then no longer matches the voxel spec's 2.0 m.
6. **Triangles.** 1,500 (650 in voxel), for three copies (six in voxel).
7. **What is given up.** The kits' leaf mounds (cards in anime and neon), the separate star or faceted blossoms, and the bevelled kerb exactly on the footprint.

### `meadow` (both clumps)

1. **Two files from one cell.** The sheet's fourth cell has to be cut into two objects, one for `meadow_grass.glb` and one for `meadow_flowers.glb`.
2. **One mesh, the first, in final coordinates**, the root of the clump at the origin on the ground. The shader bends by height above the origin.
3. **No texture.** Colour must be in `COLOR_0` (the importer then sets the material to use it) or in flat material colours, one surface a colour. A normal map is dropped as well. A piece that comes out of the fit with one textured material would be drawn as white clumps (inferred from the shader; not run).
4. **A second UV layer** whose first component is the bend weight: 0 at the root, rising to 1 at the tips, with a vertex below 1 cm under 0.01 and a vertex above 0.4 m over 0.99. Every surface must carry it. Without it the tests fail and the clump would not bend.
5. **Standard materials**, so that the sway material can replace them. `doubleSided` decides whether the blades are drawn from both sides.
6. **Size.** The spec's box (0.33 by 0.88 by 0.31 m, within 10% and 2 cm). The reach of its bounding box corner sets the planting margin and the contact radius: the kit's is 0.247 m. By my arithmetic it must stay under 0.36 m for the clumps on the 1.5 m deep lots to keep 4.5 cm apart.
7. **Triangles.** 100 and 200 (200 and 200 in voxel), for 192 copies that are drawn only within 60 m and cast no shadow.
8. **What is given up, and what that implies.** The game needs blades one face thick, weights that rise along each blade, and the smooth tuft normals that keep a clump reading as one form and keep anime's ink off every blade. A dense generated tuft cut to 100 triangles keeps none of these. What a design sheet can supply to a clump is its colours, its height and spread, and the number and colours of its flowers; the blades themselves are rebuilt by rule, as `shared/usables.py` and `voxel/things.py` build them. This is my inference from the contract, not something tried.

## Not determined

- **The split of the 116 shrubs** between `shrub_round` and `shrub_leafy` in low-poly and solarpunk, and of the 192 clumps between grass and flowers. Both follow the engine's `hash()`, which was not reproduced.
- **Whether a replacement passes the collision audit.** The rules about the circle and the rectangle are inferred from the audit's code and its zero budget; the audit was not run on any replacement.
- **Whether a textured clump is drawn white**, and whether a clump without UV2 simply stands still. Both follow from the shader and the engine's default for a missing vertex attribute; neither was run.
- **Engine behaviour taken from memory, not from this checkout:** that `visibility_range_end` is measured to the middle of a chunk's bounds; that a normal map needs tangents the importer adds only when `meshes/ensure_tangents` is on (it is off for `shrub_round` in neon, anime and solarpunk and for `flowerbed` in neon and anime; the fit tool's files carry their own `TANGENT`, as `out/lowpoly_tropical/seat_bench_v2.glb` does).
- **Whether the engine uses the importer's LODs** for a MultiMesh's instances. The `.import` files ask for LODs for `shrub_round` in low-poly, `shrub_leafy` in all four Blender kits and `flowerbed` in low-poly and solarpunk, and for none of the other pieces here.
- **Frame cost** of 116 textured shrubs at 1,500 triangles, or of heavier clumps. Not measured.
- **Whether the pinned Khronos validator accepts** a fitted file (WebP textures, tangents) without a warning. The kit tests fail on any warning.
- **What is actually visible** of this family in each view once buildings, trees and people are drawn.
- **Design sheets.** `A-low-planting` exists for low-poly, neon and anime (`docs/vision/asset-studies/sheets/<style>/A-low-planting/r001/`). Solarpunk and voxel have none yet. The neon sheet's review says its bed is drawn with a lit strip, where the kit has four corner lamps; how the cut tool separates the two tufts in the fourth cell was not looked at.
- **`lawn_tile.glb`** (voxel) is not part of this family: it is the park's and the outer lawn's ground tile (`styles/voxel/style.json:450-453`; `pack_3d.gd:1109-1112`; `styles/voxel/townscape.gd:203`).
