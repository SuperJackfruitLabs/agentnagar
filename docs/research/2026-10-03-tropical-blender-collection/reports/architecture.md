# Architecture completion report

23 original Blender candidates, each with editable `.blend`, vertex-colour GLB and metadata JSON. No prior geometry/builders imported. New reference sheets were visually inspected through view_image: library, cafe, houses, shop, towers, bridge; existing guild-hall sheet also inspected. Source repository stayed read-only.

Authoring: Z up, fronts face negative Y; glTF exports Y up. Mesh transforms baked by shared original assetkit. Required module mesh names retained: wall, pier, roof, gable, leaves, column, entrance, dome, banner; scenery house, shop, tower, cafe.001 (asset root is cafe), span, pier, wall.

## Runtime decisions

- Hall uses 4m bay, 5.2m walls and north-south sawtooth ridges; triangle end closures expose slender iron glazing. Window shade brackets are thin, not chunky blocks.
- Both entrance modules have actual empty 2m aperture. Hall clear height 3.2m, library 2.8m. Folded leaf pairs fit 0.3m reveal rather than closing the opening; runtime places two narrow leaves meshes beside the clear aperture. Static folded leaves require no animation or hinge nodes in current contract.
- Library dome starts at roof datum: runtime puts it at 7.8m. Its local drum is 1.9m and dome/lantern rises to 6.445m. It does not duplicate ground-storey walls. A fully assembled illustrative library demonstrates the reference's arcade/drum/cap silhouette.
- Bridge walking deck local +0.9m matches runtime translation -0.9m; clear parapet inner half-width 1.8m. Arch voussoirs are real open geometry beneath deck. Current quay runtime builds its own wall; quay candidate is delivered as requested.

## Commands

`blender -b -t 2 --python scripts/build_architecture.py`

`blender -b -t 2 --python scripts/architecture_contract_names.py` (one-time mesh-group naming correction, already incorporated into main builder)

`blender -b -t 2 --python scripts/build_architecture_assemblies.py`

No GPU rendering performed by this worker. Parent owns render and runtime visual validation. Blender emitted thumbnail-cache permissions warnings, but source saves and GLB exports succeeded. The first assembly run was early and lacked bridge files; rerun completed all three.

## Review risks

Detailed architecture exceeds historical budgets for houses, dome, towers and span. Primary increase is explicit bevelled trim, window framing and cut roof ribs. Towers are roughly 22k triangles each; use instancing/LOD if broad adoption occurs. Roof tile courses intentionally simplified and use geometry rather than texture. Glass is opaque dark teal in game palette for robust distant reading; no transparent interior effect implied. House C now has a real small pitched terracotta front gable cap over a limestone dormer rather than a flat triangular applique. Library assembly is an illustrative 12m by 10m composition, while runtime retains its own larger hip roof and roof-relative dome placement. No production integration or performance claim made.

## Assets

| Name | Triangles | Editable meshes |
|---|---:|---:|
| hall_wall | 152 | 10 |
| hall_window_wall | 416 | 16 |
| hall_door_wall | 220 | 5 |
| hall_corner | 44 | 1 |
| hall_sawtooth_bay | 306 | 15 |
| hall_sawtooth_gable | 128 | 7 |
| hall_door_leaves | 116 | 3 |
| lib_wall_arch | 756 | 50 |
| lib_column | 264 | 6 |
| lib_entrance | 644 | 38 |
| lib_dome | 5802 | 223 |
| lib_banner | 92 | 6 |
| lib_door_leaves | 116 | 3 |
| house_a | 6356 | 198 |
| house_b | 6624 | 211 |
| house_c | 6424 | 202 |
| shop_a | 3248 | 123 |
| tower_a | 22274 | 836 |
| tower_b | 22260 | 835 |
| cafe | 3492 | 170 |
| bridge_span | 3060 | 159 |
| bridge_pier | 348 | 10 |
| quay_wall | 388 | 27 |

Assemblies: `assemblies/hall_assembly`, `library_assembly`, `bridge_assembly`, each `.blend`, `.glb`, `.json`.

Verification: all 23 GLB headers, length fields, JSON chunks and mesh arrays parsed successfully; all editable source files nonempty; all three assembly triplets present. No render/runtime verification performed by worker.

## Render and collision review repairs

Actual hero images of all 23 components reviewed. Houses/shop/cafe right faces were missing windows; matching original side openings now added. House C triangular applique replaced with a genuine terracotta pitched gable roof. Tower right/rear frame offsets corrected to face outside glazing. These candidates require fresh renders, coordinated with parent. Banner/quay/bridge studio renders hid negative-height geometry behind a floor at zero; parent informed to render at minimum asset height, preserving top-attachment and deck datums.

Bridge audit reported six approach cells near endpoint post caps. Caps formerly extended to +/-4.11m along an 8m nominal span. End posts, rail ends and spindles physically moved inward 0.25m; caps now +/-3.86m. No navigation, collision proxy, hidden filler or runtime layout changed. `scripts/check_architecture_bridge.py` independently parses exported GLB triangles and repeats runtime walking-band clipping; actual inner half width1.67999995m, cross fitting yields2.01m, no above-deck geometry exceeds nominal half-span4m. Curb remains exactly at endpoint but sits farther outside walking width than caps. Report `reports/architecture-bridge-clearance.json`. Parent reruns full game collision audit to verify six-cell regression.

## Assembly loader repair

Initial review assemblies were visually wrong because Blender appended objects were detached before dependency-graph world matrices had been evaluated. Repaired `build_architecture_assemblies.py`: link every loaded object, update the view layer, cache all mesh world matrices, detach meshes, apply placement to cached matrices, then remove loaded non-mesh roots. Rebuilt all three assemblies only. Every component instance now asserts its cached local bounds against corresponding individual GLB metadata within0.0001m and asserts placed bounds after parent mutation against expected transformed geometry. Detailed per-instance records are included in each assembly JSON. Hall28, library49 and bridge5 component instances verified. Individual GLBs unchanged by this repair. Parent rerenders corrected assembled scenes.
