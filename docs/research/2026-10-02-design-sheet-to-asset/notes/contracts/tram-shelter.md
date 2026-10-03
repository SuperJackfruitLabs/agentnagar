# The tram shelter: what the game expects of the piece

Written by Claude (an AI agent) from the game's code; nothing was run and nothing changed. It was the brief for the build of this family. Paths beginning `work/` are the record's `tools/`.

Contract note for replacing the kit's `tram_shelter` with a model generated from the `A-tram-shelter` design sheet, in `lowpoly_tropical`, `neon_noir`, `anime_cel`, `solarpunk` and `voxel`. Written 2026-10-02 from the code, the data and the kit files. Nothing was run: no game, no Blender, no capture.

Conventions:

- Paths are relative to the checkout (`agentnagar/`) unless they begin with `.asset-pilot/`. After a file's first mention its path is shortened to its name (with its kit's folder where two kits have a file of that name).
- **Piece frame**: the GLB's own axes, in metres: x along the shelter's length, y up, z across it. The open front faces −z.
- **Kind frame**: the catalogue's, with the placement's point at the origin and +z towards the track. Every style turns the piece half a turn, so kind x = −piece x and kind z = −piece z (before the game's stretch, about 1%).
- *Computed* marks a number I got by applying the code's arithmetic to the fixture by hand. *Inferred* marks a conclusion the code does not state outright.

## Summary

- **One contract in all five styles.** `props.tram-shelter` is `{scene, turn: 180, fill: true, perch}` everywhere. The game instantiates the GLB five times, turns it, scales its x and z so that what it draws between 0.15 and 2.2 m up fills the kind's footprint box (4.30 by 1.15 m), and adds three perch seats in front of the bench.
- **The sizing rule is the main risk.** Only the band slice (posts, back screen, bench, end screen) is measured. The canopy is 4.75 by about 2.2 m and overhangs that slice by 0.8 m at the front. Anything else below 2.2 m (a front post, a low eave, a hanging sign) enlarges the measured box and the game rescales the whole piece. The three design sheets filed so far (low-poly, anime, neon) all draw posts at the canopy's front corners.
- **People do not sit on the shelter's bench.** They sit on perch seats the game draws at three sit anchors 0.30 m in front of the bench's front edge. The bench must still be drawn, in its place, or the collision audit fails.
- **The game draws nothing on the sign.** The kits model their timetable; a blank panel stays blank.
- **Glass is an opaque material named `glass…`**, which the game makes glow at night (not in neon). The kits' lamp strips and lit timetable faces are faces of the one mesh with the materials `lamp_glow` or `window_glow`. No kit shelter has a `light` part, so no lamp is cast.
- **The kit tests hold the shelter to its spec only.** The shared tram checks test `tram.glb` and nothing else.
- **The capture tool will not find a shelter as it is written**: the GLB instance is a child of the node the pack records, not that node.

Found different from what the brief took as known:

1. Shelters are not placed from `styles/tram_layout.json`. That file is the tram vehicle's inside (length, doors, floor, seats: `city/godot/styles/style_pack.gd:1250-1261`). Shelters are catalogue placements in the district manifest.
2. `neon_noir` and `solarpunk` extend the lit pack (`city/godot/styles/neon_noir/pack.gd:6`, `city/godot/styles/solarpunk/pack.gd:6`). `anime_cel` extends `Pack3D` directly (`city/godot/styles/anime_cel/pack.gd:7`), as low-poly and voxel do. Only the lit packs' townscape descends from the anime one (`city/godot/styles/lit/townscape.gd:6`).
3. "The sign panel is blank: the game draws its content" (`docs/vision/asset-studies/SUBJECTS.md:68`) is not what the code does. See "The sign panel".
4. Perch seats are scene instances, one per sit anchor (`city/godot/styles/pack_3d.gd:451`), not instances of one mesh as `.asset-pilot/2026-10-02-sheet-to-asset/work/build.py:274` says.

## The five styles

| | lowpoly_tropical | neon_noir | anime_cel | solarpunk | voxel |
| --- | --- | --- | --- | --- | --- |
| Kit file (under `city/godot/styles/<style>/`) | `assets/tram_shelter.glb` | `assets/tram_shelter.glb` | `assets/tram_shelter.glb` | `assets/tram_shelter.glb` | `assets/v2/tram_shelter.glb` |
| Spec, key `tram_shelter` | `city/tools/styles/lowpoly/specs/buildings.json:13` | `…/neon/specs/buildings.json:19` | `…/anime/specs/buildings.json:19` | `…/solarpunk/specs/buildings.json:19` | `…/voxel/specs/scenery.json:19` |
| Spec size x, y, z (m) | 4.75, 2.95, 2.2 | 4.75, 2.97, 2.32 | 4.75, 2.97, 2.32 | 4.75, 3.17, 2.26 | 4.6, 3.3, 1.6 |
| Allowed (10% + 2 cm) | 4.26–5.24, 2.64–3.26, 1.96–2.44 | 4.26–5.24, 2.66–3.28, 2.07–2.57 | as neon | 4.26–5.24, 2.84–3.50, 2.02–2.50 | 4.12–5.08, 2.95–3.65, 1.42–1.78 |
| Triangle limit (kit piece has) | 800 (328) | 1000 (648) | 1000 (636) | 1400 (984) | 550 (526) |
| Spec nodes | `shelter` | `shelter` | `shelter` | `shelter` | `shelter` |
| GLB nodes | root `tram_shelter`, one mesh child `shelter` | same | same | same | same |
| Materials (one primitive each) | `teal_dark`, `glass_light`, `teal`, `wood_light`, `iron`, `white`, `paving_dark` | `paving_dark`, `baked_r75_m0`, `glass`, `baked_r25_m75`, `lamp_glow`, `window_glow` | `baked_r75_m0`, `baked_r50_m50`, `glass_light`, `baked_r25_m50`, `lamp_glow` | `paving_light`, `baked_r50_m0`, `baked_r25_m75`, `baked_r25_m0`, `baked_r75_m50`, `baked_r75_m0`, `lamp_glow`, `glass_light` | `charcoal`, `glass_light`, `navy`, `orange`, `steel`, `white`, `wood`, `wood_dark` |
| Colour | material colours; no vertex colours | vertex colours (`COLOR_0`): the `baked_*` materials are white and take their colour from them | as neon | as neon | material colours; no vertex colours |
| Textures, UVs, alpha | none; every material opaque, double-sided | none; opaque, double-sided | as neon | as neon | none; opaque, single-sided |
| Whole box, piece frame | x ±2.375, y 0–2.95, z −1.17…1.02 | x ±2.375, y 0–2.97, z −1.195…1.10 | as neon | x ±2.375, y 0–3.168, z −1.185…1.041 | x ±2.3, y 0–3.3, z −0.7…0.9 |
| Band box (0.15–2.2 m), piece frame | x ±2.13, z −0.40…0.75 | same | same | x ±2.15, z −0.41…0.76 | x ±2.2, z −0.4…0.8 |
| Scale the game gives, x by z (*computed*) | 1.011 by 1.000 (north platforms), 1.004 (south) | same | same | 1.001 by 0.983, 0.987 | 0.978 by 0.958, 0.963 |
| Placed (lines of `city/godot/styles/<style>/style.json`) | turned 180°, filled, three perch seats (207-212) | same (231-236) | same (221-226) | same (231-236) | same, perch `assets/v2/perch_seat.glb` (203-208) |
| Scene instance | yes, as child 0 of the placement's node | same | same | same | same |
| Needle | `tram_shelter` | `tram_shelter` | `tram_shelter` | `tram_shelter` | `tram_shelter` |

The whole boxes, band boxes, triangle counts and materials were read from each GLB's JSON chunk and vertex data with Python; the band boxes agree with the pilot's own `docs/research/2026-10-01-asset-to-sheet-pilot/tools/band.py`. In each style `tram_shelter.glb` is the only GLB with `shelter` in its name; `=tram_shelter.glb` is the exact form.

## The kit piece in its own coordinates

All five kits use one layout. Length along x (4.75 m; voxel 4.6), depth along z, origin on the ground at the placement's point, which is not the middle of the piece: the canopy reaches 1.17 m in front of the origin and 1.02 m behind it (low-poly).

- **Open front: −z.** The builders say "open to +Y" in Blender, which the exporter writes as −z (`city/tools/styles/lowpoly/buildings.py:337-341`, `neon/buildings.py:1020-1023`, `anime/buildings.py:974-976`, `solarpunk/buildings.py:1432-1436`; voxel "open toward -z", `voxel/scenery.py:348-349`).
- **Back screen at z ≈ +0.69**, with the posts' back faces at z = +0.75.
- **End screen at the −x end**, a glass end wall from the back to z = −0.40.
- **Timetable at the +x end**, a board against the back screen facing the front.
- **Bench between x = −1.73 and +0.63**, nearer the end-screen end.
- Seen from the track, the end screen is on the right and the timetable on the left (*inferred* from the axes; `city/godot/evidence/placement-lowpoly_tropical-street.png` shows it so).

| Part | low-poly | neon, anime | solarpunk | voxel |
| --- | --- | --- | --- | --- |
| Back posts | 2, at x ±2.03…2.13, z 0.63…0.75, y 0…2.80 | 3, at x ±2.03…2.13 and −0.05…0.05, z 0.63…0.75, y 0.08…2.62 | 2, at x ±2.01…2.15, z 0.62…0.76, y 0.08…2.60 | 3, at x −2.2…−2.1, −0.1…0, 2.1…2.2, z 0.6…0.8, y 0…2.7 |
| Back screen (glass) | x ±2.05, y 0.305…2.255, z 0.675…0.705; rails at y 0.27–0.33 and 2.23–2.29 | same | same; rails 0.265–0.335 and 2.225–2.295 | glass panes in a steel frame, x ±2.1, y 0.2…2.5, z 0.7…0.8 |
| End screen (glass) | x −2.095…−2.065, z −0.36…0.64, y 0.305…2.255; its front post x −2.11…−2.05, z −0.40…−0.34, y 0…2.60 | same glass; post y 0.28…2.28 | same glass; post x −2.12…−2.04, z −0.41…−0.33, y 0.28…2.28 | x −2.2…−2.1, z −0.3…0.6, y 0.2…2.5; post z −0.4…−0.3, y 0…2.7 |
| Bench seat | x −1.73…0.63, z 0.15…0.57, top 0.49 | top 0.505 | top 0.505 | x −1.8…0.7, z 0.2…0.6, top 0.50 |
| Bench back rail | x −1.73…0.63, y 0.63…0.93, z 0.56…0.62 | same | same | x −1.8…0.7, y 0.5…0.8, z 0.6…0.7 |
| Bench legs | x −1.63…−1.57 and 0.47…0.53, z 0.18…0.54, y 0…0.44 | y 0.08…0.52 | y 0.08…0.52 | x −1.7…−1.6 and 0.5…0.6, z 0.3…0.5, y 0…0.4 |
| Timetable | board x 1.20…1.90, y 0.70…1.90, z 0.54…0.64; four white bars on its face at z 0.52…0.54 | board x 1.20…1.90, y 0.605…1.955, z 0.54…0.64; lit face x 1.27…1.83, y 0.75…1.85, z 0.515…0.545; five bars and a header at z 0.50…0.52 | as neon | board x 1.2…1.9, y 0.3…1.8, z 0.6…0.7; white face x 1.3…1.8, y 0.8…1.6 |
| Canopy | glass slab x ±2.35, z −1.15…1.00, y 2.60 at the front to 2.95 at the back; beams at the front (z −1.17…−1.03, y 2.61…2.75) and back (z 0.88…1.02) | glass slab x ±2.35, z −1.07…1.04, y 2.74…2.89; three cross beams y 2.578…2.872; edge beams to z −1.14 and 1.10 | timber slab x ±2.35, z −1.05…1.04, y 2.70…2.90; two cross beams y 2.514…2.846; solar panels and a planted strip on top, to y 3.168 | white roof x ±2.3, z −0.5…0.9, y 2.7…2.9; orange fascia z −0.6…−0.5, y 2.4…3.3, lettered TRAM in white |
| Lamp strips (`lamp_glow`) | none | x ±2.05, y 2.695…2.745, z −1.03…−0.97; neon also y 2.66…2.70, z 0.565…0.615 | x ±2.05, y 2.695…2.745, z −1.01…−0.95 | none |
| Roundel on the front edge | none | disc x 1.56…1.94, y 2.59…2.97, z −1.195…−1.14, with a T | disc x 1.55…1.95, y 2.66…3.06, z −1.185…−1.11 | none |
| Base slab | x ±2.0, z −0.15…0.15, y 0…0.10 | x ±2.25, z −1.07…0.83, y 0…0.08 | as neon | none |
| Lowest point over open ground | 2.60 | 2.578 | 2.514 | 2.40 |

## How the game places and scales it

**Where shelters come from.** The catalogue kind `tram-shelter` (`city/catalogue/catalogue.json:157-172`): a footprint of four rectangles, one `stand` anchor, three `sit` anchors, capabilities `sit` and `inspect`, height 250. The district fixture places five (`city/fixtures/district/manifest.json:7938-7979`, written by `city/fixtures/district/generate.py:475-506`); the game reads that fixture (`city/godot/core/paths.gd:21-40`).

| Placement | Point (m) | Facing | Opens towards |
| --- | --- | --- | --- |
| `placement:shelter-square-north-1` | −12.0, 16.0 | 0 | south, the eastbound track at z = 19.0 |
| `placement:shelter-square-north-2` | 12.0, 16.0 | 0 | south |
| `placement:shelter-square-south-1` | −12.0, 25.0 | 180 | north, the westbound track at z = 22.0 |
| `placement:shelter-avenue-north-1` | 63.0, 16.0 | 0 | south |
| `placement:shelter-avenue-south-1` | 63.0, 25.0 | 180 | north |

Two stops, four platforms, five shelters. The line runs at z = 20.5 m with tracks 1.5 m either side (`generate.py:175-177`). Each shelter's point is 3.0 m from its track's centre and 1.5 m inside its platform's edge (`generate.py:467-471`, `485-506`). A shelter "faces" 0 when it opens south: the kind's open front is its +z.

**The footprint and anchors, in both frames** (`catalogue.json:161-169`):

| | Kind frame (m) | Piece frame (m) |
| --- | --- | --- |
| Back strip | x −2.15…2.15, z −0.75…−0.55 | x −2.15…2.15, z 0.55…0.75 |
| Bench | x −0.65…1.75, z −0.55…−0.15 | x −1.75…0.65, z 0.15…0.55 |
| Timetable | x −1.90…−1.20, z −0.55…−0.50 | x 1.20…1.90, z 0.50…0.55 |
| End screen | x 2.00…2.15, z −0.55…0.40 | x −2.15…−2.00, z −0.40…0.55 |
| Bounding box | x −2.15…2.15, z −0.75…0.40 | x −2.15…2.15, z −0.40…0.75 |
| `stand` anchor | 0, 1.10, facing the shelter | 0, −1.10 |
| `sit` anchors | −0.25, 0.15; 0.55, 0.15; 1.35, 0.15; facing the track | 0.25, −0.15; −0.55, −0.15; −1.35, −0.15 |

**How a shelter is drawn.**

1. `_placements` resolves `props.tram-shelter`, makes the node, adds it to the world, tags it and looks for a `light` part (`city/godot/styles/pack_3d.gd:274-303`).
2. `_placement` instantiates the scene, puts it at the point and turns it by −(facing + `turn`) (`pack_3d.gd:419-422`). With `turn: 180` the piece's −z ends up pointing at the track.
3. `fill: true` calls `_fill_footprint` (`pack_3d.gd:423-424`, `719-734`).
4. `town._collect(piece)` registers its glass, lamp and neon materials (`pack_3d.gd:425`).
5. `perch` wraps it: `_perch` makes a new `Node3D`, adds the piece as its first child and a perch seat for each sit anchor (`pack_3d.gd:426-427`, `437-458`).

**The fill, exactly.** `town.band_box(path)` is the (x, z) bounding box, in the piece's frame, of every visible face cut to 0.15–2.2 m: every vertex in that range and every point where an edge crosses either height (`city/godot/styles/kit_town.gd:214`, `224-229`, `251-256`, `262-281`, `299-315`). `_fill_footprint` turns that box by the piece's turn, sets `scale = (footprint width / box width, 1, footprint depth / box depth)` and moves the piece so the box's centre lies on the footprint's centre (`pack_3d.gd:730-734`). Consequences:

- Height is never scaled.
- x and z are scaled separately, up or down. It is a fit, not only a squeeze.
- The piece's own origin does not anchor it in x and z; the band box does.
- The footprint used is the bounding box of the four rectangles, drawn to the grid (`_drawn_local`, `pack_3d.gd:746-762`; `CityGeometry.drawn_rect`, `city/godot/core/city_geometry.gd:186-197`). For the five placements that is 4.305 m wide and 1.15 m deep (1.155 m on the south platforms) (*computed*, grid origin −72.00, −66.50 m from the rooms' least corner, `city/crates/city-core/src/nav.rs:132-136`).
- A client test fills this very file at each right-angle turn and asserts the band slice then equals the footprint (`city/godot/tests/test_anime_pack.gd:246-266`). It passes for any piece with something in the band.

**What the walking band means here.** Three heights are in play:

- 0.25–1.9 m: the spec's walking band and the collision audit's (`city/godot/tools/collision_audit/audit.gd:52`; `docs/superpowers/specs/2026-09-27-city-placement-grid-design.md:237`).
- 0.15–2.2 m: what the game measures to scale a filled piece (`kit_town.gd:214`).
- 1.6 m: the first-person eye, standing (`city/godot/core/fpv_camera.gd:10`).

The footprint "covers only the posts, the back glass and the bench, and leaves the front walkable" (`…placement-grid-design.md:333`). The core blocks a cell when its centre lies within 10 cm of a footprint rectangle (`city/crates/city-core/src/footprint.rs:12`, `425-436`). For `placement:shelter-square-north-1` that is 42 cells of 25 cm (*computed*; `#` blocked, `.` walkable, `S` the cells holding the sit anchors, kind x from −2.13 on the left to 2.12 on the right):

```
kind z −0.63   ##################    the back: 18 cells
kind z −0.38   ......##########.#    the bench (x −0.63…1.62) and the end screen (x 2.12)
kind z −0.13   ......##########.#
kind z +0.12   ........S..S..S..#
kind z +0.37   .................#
```

Everything else under the canopy is walked on and stood on: the stand anchor is at kind z = +1.10, under the canopy's front edge in every style but voxel, whose roof is shallower. The timetable's rectangle blocks no cell of its own; the cells in front of it are walkable.

The collision audit holds every style to zero offences (`city/godot/evidence/placement-budget.json`; `city/godot/tests/test_collision_audit.gd:23-45`). It reads each mesh's slice between 0.25 and 1.9 m (`city/godot/tools/collision_audit/solids_3d.gd:82-92`, `228-289`, `337-384`) and fails when:

- anything drawn comes within 10 cm of a walkable cell's centre (`audit.gd:386-399`), except the placement's own geometry inside the 0.5 m square round each sit anchor (`audit.gd:204-212`, `237-253`, `335-361`);
- a blocked cell inside a room has nothing drawn within 10 cm of its centre (`audit.gd:406-446`).

So the bench, the back and the end screen must be there as well as stay in place.

**Clearance from the tram.** No code or test checks it. As placed, the kits' canopy front edge is 1.16–1.20 m in front of the point (voxel 0.69 m), the platform's edge 1.5 m, the tram's side 1.75 m (the tram is drawn 2.5 m wide, `kit_town.gd:377-382`, `catalogue.json:456`) (*computed*).

## Seats

- **Where people sit is data.** The three `sit` anchors of the kind (`catalogue.json:166-168`), read from the layout and the catalogue (`city/godot/core/interact.gd:82-128`). Not named nodes in the GLB, not computed from the piece's size. The design decision: "three `sit` anchors along the front of its bench (x = −25, 55, 135 cm; z = 15 cm, 30 cm clear of the bench's face …), sat facing the platform" (`docs/superpowers/specs/2026-09-27-city-interactions-design.md:387-393`).
- **The game draws a perch seat at each anchor**, turned the way the sitter faces (`pack_3d.gd:446-456`). The seat is 0.30 m wide and reaches from 0.15 m in front of the anchor to 0.40 m behind it, top at 0.46 m (`city/tools/styles/shared/usables.py:47-53`, `210-219`; specs: 0.46 m in low-poly, neon and solarpunk, 0.49 m in anime, 0.50 m in voxel). In the piece frame each seat covers x = anchor ± 0.15, z −0.30…+0.25: it overlaps the front 10 cm of the bench and stands 0.45 m out in front of it.
- **The figure is put on the perch seat**, at the seat's origin, at ground height, facing the seat's front (`pack_3d.gd:473-478`, `1821-1832`). The sit clip holds the hips 0.45–0.60 m up over the origin (`city/tools/styles/lowpoly/test_assets.py:248`, `311-323`). So a sitter's hips are at piece (0.25 or −0.55 or −1.35, −0.15), 0.30 m in front of the bench's front edge, facing −z.
- **Tests**: every shelter's node has exactly its body and three seats, each at its anchor and facing the sitter's way (`city/godot/tests/test_things_to_use.gd:20-21`, `86-103`); a sitter is drawn on its seat (`test_things_to_use.gd:108-109`, `117-161`).

So the replacement's own bench is scenery behind the sitters. It may not be left out (the audit's blocked cells need it), and it should meet the perch seats: front edge at piece z ≈ +0.15, top at 0.46–0.51 m.

## The sign panel

- The game draws text only for kinds with a `display` anchor (`city/godot/styles/surfaces.gd:36-52`): workstation, bookshelf, noticeboard, plaque, kiosk. `tram-shelter` has none (`catalogue.json:164-169`). No surface is made for a shelter, so `display_face` (`pack_3d.gd:667-674`) is never asked about one, and a `display` node in the piece would do nothing.
- Tram times go to the HUD and the map (`city/godot/core/tram_times.gd:1`), not to the shelter.
- No code looks up a node or a material of a shelter's sign in any style.
- What the kits show is modelled: a board with bars (low-poly, not lit), a lit face with bars and a header (neon `window_glow`; anime and solarpunk `lamp_glow`), a white panel on a navy board (voxel), a roundel with a T (neon, anime, solarpunk), TRAM in cut letters (voxel).

## Glass, light and what else is looked up by name

**Glass.** Each kit's screen is an opaque material: `glass_light` (low-poly, anime, solarpunk, voxel) or `glass` (neon), roughness 0.05–0.18, alpha 1. In low-poly, neon and anime the canopy is the same material. The game never makes a shelter's glass see-through: that is done only for the tram (`pack_3d.gd:2737-2748`) and for the hall's and library's pieces (`city/godot/styles/lit/lit_pack.gd:58-59`, `city/godot/styles/anime_cel/toon.gd:17`, `102-104`). Any material whose name begins `glass` gets an emission in the style's palette colour `glass_glow` (`kit_town.gd:169-173`), raised to 1.5 at night (`pack_3d.gd:2057-2062`). Neon turns that off (`city/godot/styles/neon_noir/style.json:525`).

**Lamp materials.** Names exactly `lamp_glow`, `window_glow`, `fairy_glow`, `light` (`kit_town.gd:174-175`). The game sets only their emission energy: the style's `window_energy` when lamps are lit (2.5 by default; neon 1.1, solarpunk 1.4), 0.35 by day (`pack_3d.gd:2063-2064`). The material must already emit in the file. The kits' strips and lit faces are such materials (table above); low-poly and voxel have none.

**Lamps.** No kit shelter has a part named `light` or `lights`, so the game casts no light at a shelter. A part named `light` anywhere under the placement would get one lamp at its middle (`pack_3d.gd:301`, `767-777`; `kit_town.gd:68-77`). In the lit styles a lamp below 1.5 m is dimmed to 0.3 and its reach cut to 3.5 m (`lit_pack.gd:113-115`). In anime a test requires every lamp to be above 1.5 m (`city/godot/tests/test_anime_pack.gd:270-275`). A part named `lights` gets nothing: `glow_lights` exists only in neon and lists only `tree_banyan` (`neon_noir/style.json:528-530`, `lit_pack.gd:93-105`).

**Other names.**

- `neon…`: lit at `neon_energy` from dusk and darkened by day, in neon and solarpunk (`kit_town.gd:176-177`, `lit_pack.gd:230-237`).
- `paving…`, `asphalt…`, `kerb…`, `road…`, `path…`, `street…`: darkened and made glossy in rain, in neon, anime and solarpunk (`pack_3d.gd:115`, `2174-2183`). The neon and solarpunk shelters' base slabs are `paving_dark` and `paving_light`.
- The kits' bake keeps exactly these names apart from the merged `baked_*` materials (`city/tools/styles/shared/bake.py:22-25`).

**After loading.**

- Anime: every lit material under the world is turned toon in place (toon diffuse and specular, roughness 0.32, a rim) (`anime_cel/pack.gd:44-45`, `pack_3d.gd:220`, `toon.gd:30-54`, `79-113`). One full-screen pass inks where depth steps by 6% of the distance or normals differ by 1 − cos ≥ 0.35 (`city/godot/styles/anime_cel/shaders/lines.gdshader:12-14`, `45`). A test requires every lit material to be toon (`test_anime_pack.gd:32-43`).
- Neon, solarpunk: nothing shelter-specific (`lit_pack.gd:47-59`).
- No palette recolouring of a placed piece in any style. Shadows: default casting; nothing shelter-specific.
- The pack's record of placed nodes is used for nothing but displays (`pack_3d.gd:668`).

## What the kit's tests require

- **Spec**: size within 10% + 2 cm on each axis (from the POSITION accessors' min and max), triangles within the limit, the node `shelter` present: `city/tools/styles/lowpoly/test_assets.py:218-232`; `city/tools/styles/shared/kittests.py:92-107` (neon, solarpunk); `city/tools/styles/anime/test_assets.py:65-80`; `city/tools/styles/voxel/test_assets.py:215-230`.
- **Every GLB has a spec, every style.json reference exists** (`kittests.py:83-90`, `109-112`).
- **Khronos validator with no error and no warning** (`kittests.py:48-69`, `122-126`; `city/tools/styles/lowpoly/validate.sh`).
- **The committed file is byte for byte what the generator builds** in neon, solarpunk, anime and voxel (`kittests.py:128-144`, `anime/test_assets.py:101-116`, `voxel/test_assets.py:236-247`). A generated piece fails this by its nature if it is ever committed into a kit.
- **Voxel only**: no part named as the root (`voxel/test_assets.py:226-229`); every primitive indexed (`voxel/test_assets.py:82`); an import sidecar with `meshes/generate_lods=false` (`voxel/test_assets.py:253-257`).
- **The shared tram checks hold the shelter to nothing.** Every test in `city/tools/styles/shared/tram_checks.py:145-200` reads `tram.glb` (each kit: `Tram = tram_checks.tram_case(… / "tram.glb")`), and `test_tram_layout.py` reads the layout file. No kit test names the shelter; no clearance against the tram or the track is tested.

## Finding it in the game and seeing it

- `placement_nodes[id]` for a shelter is the wrapper `_perch` makes with `Node3D.new()` (`pack_3d.gd:438-440`; tagged at `pack_3d.gd:300`, `style_pack.gd:228-230`). Its `scene_file_path` is empty (*inferred*). Child 0 is the GLB instance, with `scene_file_path` `res://styles/<style>/<kit file>`; children 1 to 3 are the perch seats (`test_things_to_use.gd:95-98`).
- `.asset-pilot/2026-10-02-sheet-to-asset/work/asset_views.gd:86-91` tests only the recorded nodes' own `scene_file_path`. As written it will report 0 placed for the shelter, and for the perch seats, which hang under the same wrappers (*inferred*, not run). It has to look at the wrapper's children too.
- The wrapper sits at the world's origin; position, turn and scale are on child 0. The tool's camera and its recorded scale are right only if it works from child 0.
- A shelter is 4.75 m long: it needs `"frame": "auto"`. The tool calls a piece in use when someone is within 0.8 m of its point (`asset_views.gd:100-103`); two of the three sit anchors are.
- Standard views (`city/godot/core/orbit_rig.gd:8`, `68-93`, `175-190`):
  - `street`: the camera stands on the north platform at about (−2.9, 1.7, 16.7) looking north. The two north shelters stand 9 m to its left and 15 m to its right, outside the frame (*computed*; an earlier street capture shows none).
  - `diagonal`: the Square's three shelters are in frame, small (an earlier capture, `.asset-pilot/2026-10-01-local-3d-banyan/captures/before/lowpoly_tropical/diagonal.png`, shows them).
  - `topdown`: canopy tops only.
- `city/godot/tools/sheet_views.gd:338`: the `tram-board` view stands at (13.0, 1.7, 25.2) looking west along the south platform; the south shelter is ahead, about 25 m off (*inferred*).
- `city/godot/tools/probes/capture_views.gd:6` gives the view the placement evidence used, which shows a north shelter from its open front: `street:4,12,-40,-10,16`.

## What a generated replacement must keep or put back by rule

**File and nodes**

1. Copy over `assets/tram_shelter.glb` (voxel `assets/v2/tram_shelter.glb`). Root node `tram_shelter`, one mesh node named `shelter`. The fitting tool names its mesh `body` (`.asset-pilot/…/work/fit_generated.py:806`), which fails the spec's node check in every kit; it needs the name set (voxelise.py already takes `--mesh`).
2. No part named `light`, `lights` or `display` unless its effect above is wanted.

**Which way round**

3. Open front to −z, the end panel at the −x end, the bench's length from x ≈ −1.75 to +0.65. Seen from above a shelter is its canopy, so the fitting tool's height-map rule (`fit_generated.py:359-379`) has little to tell front from back or one end from the other (*inferred*): set `--yaw` and check.

**Size**

4. The whole piece inside the spec's range (table above). Height is not changed by the game.
5. The band box is what the game fits. Between 0.15 and 2.2 m up, the piece's bounding box must be x −2.15…2.15, z −0.40…0.75 in the piece frame, with the origin where the kit's is (the kits': ±2.13, −0.40…0.75), or the game rescales the whole piece, canopy included. Filling the kit's whole box, as the fit does now (`fit_generated.py:386`), does not give this: the box to match is the band slice's. The kits' canopies overhang it by 0.77–0.80 m at the front and 0.27–0.35 m at the back (voxel 0.3 and 0.1 m).
6. Everything outside that box stays above 2.2 m: canopy underside, beams, brackets, lamp strips, hanging signs, across the full length and at both front corners. An edge that only crosses 2.2 m on its way up counts. The kits keep 2.40 m (voxel) to 2.60 m (low-poly).
7. Below 0.15 m anything is free (a slab, a kerb).

**What stands where, 0.25 to 1.9 m up, piece frame**

8. Back: across the full length, between z 0.55 and 0.75; its front face no further forward than z 0.48 where there is no bench (*computed* from the audit's rule).
9. End panel: at x −2.15…−2.00, from the back to z = −0.40. Its inner face no nearer the middle than x = −1.96; its front end between z −0.28 and −0.52 (*computed*).
10. Bench: x −1.75…0.65, z 0.15…0.55. Ends within x −1.75…−1.51 and 0.52…0.76; front edge between z −0.02 and 0.22 (*computed*). It must be present.
11. A board at the +x end only against the back: nothing in front of z 0.48 there.
12. Nothing else: no post, plinth, arm rest or bin on the open ground, including the front corner at the +x end.

**The three filed sheets against rules 5 to 12** (`docs/vision/asset-studies/sheets/<style>/A-tram-shelter/r001/image.png` for `lowpoly_tropical`, `anime_cel` and `neon_noir`, looked at by eye; solarpunk and voxel were not filed when this was written):

- All three draw posts at the canopy's two front corners. Fitted to the kit's whole box, the band slice would be the whole plan, about 4.75 by 2.2 m, and the game would draw the shelter about 0.91 wide and 0.53 deep (*inferred*). The front post at the open end would also stand on walkable ground.
- All three put the sign panel at the right-hand end seen from the front, which is the kit's end-screen end. The anime panel spans the canopy's full depth; the low-poly and neon ones stand at the front corner (low-poly on a stone plinth). The footprint allows an end wall 0.15 m thick reaching 0.95 m forward of the back strip.
- The low-poly bench is centred and has arms; the anime and neon benches run most of the length, with arm rests. The footprint's bench is 2.4 m long, off-centre towards the panel end.
- The neon sheet draws its light: amber strips under the canopy's edges and on the posts, a magenta strip beside the sign, and the sign's face lit. A generated texture only paints these. To be lit they are put back by name: `lamp_glow` for the amber strips, `window_glow` for the sign's face, a material whose name begins `neon` for the magenta strip (lit from dusk in the neon pack in its own base colour, `lit_pack.gd:230-237`; the kit's perch seat has one, `neon_cyan`). The strips on the front posts go with the posts.
- So either the fit drops or cuts what stands in front of z = −0.40 below 2.2 m and resizes the band slice on its own, or the brief is changed to say: posts and panel within 1.15 m of the back, no posts at the front, canopy cantilevered.

**Seats**

13. The game adds the three perch seats; do not model them. Keep the bench's top at 0.46–0.51 m and its front edge at z ≈ +0.15 so the seats, which reach back to z = +0.25, join it. `--seat` cannot be used as it is: it finds the seat by rays dropped from above the piece (`fit_generated.py:222-244`), and here they stop on the canopy.
14. Nothing on the bench may reach in front of its front edge at x ≈ 0.25, −0.55, −1.35, where the sitters are.

**Sign**

15. Nothing is drawn on it. If content is wanted it is put back by rule: the kit's bars and header on the design's panel, or the kit's timetable board at x 1.20…1.90 against the back. For a lit face use the material `window_glow` (neon) or `lamp_glow` (anime, solarpunk), emissive in the file.

**Glass and light**

16. For the night glow, the screen's faces need a material of their own whose name begins `glass`; a single generated material gets none. It stays opaque either way.
17. Lamp strips are faces of the kit's one mesh, so `--kit-lights` carries nothing (it copies parts named `light` and `lights`, `fit_generated.py:1406-1414`). Put back by rule, above 2.2 m, material exactly `lamp_glow`: under the front edge at x ±2.05, y 2.70…2.75, z ≈ −1.0 (neon, anime, solarpunk); neon also at the back, y 2.66…2.70, z ≈ 0.59. Two materials must not share a name.
18. No `light` part, as the kits. If one is added: one lamp a shelter, five in the district; above 1.5 m in anime.
19. Anime: no relief map (`--no-normal`); every bump in the normals is an ink line.

**Cost and tools**

20. Five instances, each drawn on its own; every material is a draw a copy a pass.
21. Voxel: cubes of 0.1 m; the spec's depth is 1.6 m (at most 1.78 m).
22. `check.py` has no footprint for the shelter (`.asset-pilot/…/work/check.py:31`). The entry is `"tram_shelter": [-2.15, -0.40, 2.15, 0.75]`, and the band box should also reach those limits, not only stay inside them.

## Not determined

- The scale the game really gives each shelter: the figures above are computed, not read from a run.
- What the solarpunk and voxel design sheets draw: not filed when this was written. The three filed sheets were read by eye, not measured.
- Whether the fitting tool turns a generated shelter the right way round; it depends on the model.
- Whether an imported material's `resource_path` contains the pack's folder, which `toon.gd:82` relies on to convert the anime kit's materials in place. Read from the code's reliance, not checked.
- How a dense textured mesh looks under the anime ink pass, and whether see-through glass would be wanted: not answerable from the code.
- Whether the Khronos validator accepts the fitted pieces' WebP textures without a warning.
- Whether the avenue's two shelters are in the diagonal or top-down frame; which shelters the `tram-night` view shows behind the tram.
- The wrapper node's exact name; nothing looks it up.
- How the perch seats look against a replacement's bench: needs a capture.
