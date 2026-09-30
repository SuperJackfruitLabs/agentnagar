# The placement grid: evidence

This is what the
[placement-grid design](../../../docs/superpowers/specs/2026-09-27-city-placement-grid-design.md)
set out to fix, measured before and after. The earlier figures come from the
two spikes on `spike/collision-audit`, at main 05b5b90:

- the collision audit;
- the door investigation.

The later figures were measured on 2026-09-28 at 818201d, the last build
commit, on the development laptop (12th Gen Intel Core i9-12900H).

## Nothing walks through anything

The collision audit measures every style's drawn world against the core's
walkable grid, over the spike's day: seed 7, a crowd of 60, 600 ticks, and a
scripted player. `tests/test_collision_audit.gd` runs it in every style and
holds each count to [`placement-budget.json`](placement-budget.json).
`tools/collision_audit.gd` runs it by hand and writes each overlay.

**Before** (the spike's audit, at 05b5b90):

| Style | Through cells (m²) | Within 10 cm | Walker pass-throughs (share of visits) | Player pass-throughs | Walkers inside a drawn tram | Blocked, open-looking |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| anime_cel | 3,022 (188.9) | 6,119 | 715 (6.7%) | 324 | 188 | 3,408 |
| solarpunk | 3,065 (191.6) | 6,296 | 887 (8.3%) | 338 | 188 | 3,534 |
| neon_noir | 3,034 (189.6) | 6,219 | 767 (7.2%) | 279 | 188 | 3,395 |
| lowpoly_tropical | 3,382 (211.4) | 6,159 | 811 (7.6%) | 345 | 188 | 3,939 |
| voxel | 2,156 (134.8) | 5,002 | 120 (1.1%) | 145 | 188 | 736 |
| pixel_art | 2,572 (160.8) | 5,070 | 285 (2.7%) | 170 | 188 | 290 |

**Now:** zero on every gate in every style. The budget file holds 0 for
`through`, `within_10cm`, `walker_pass`, `player_pass`, `tram_overlap` and
`reverse_blocked` in all six styles. The audit run on 2026-09-28 reports
the same:

| Style | through | within_10cm | walker_pass | player_pass | tram_overlap | reverse_blocked | Run |
| --- | --: | --: | --: | --: | --: | --: | --: |
| anime_cel | 0 | 0 | 0 | 0 | 0 | 0 | 10.0 s |
| solarpunk | 0 | 0 | 0 | 0 | 0 | 0 | 6.8 s |
| neon_noir | 0 | 0 | 0 | 0 | 0 | 0 | 6.8 s |
| lowpoly_tropical | 0 | 0 | 0 | 0 | 0 | 0 | 6.1 s |
| voxel | 0 | 0 | 0 | 0 | 0 | 0 | 5.2 s |
| pixel_art | 0 | 0 | 0 | 0 | 0 | 0 | 1.5 s |

Two notes on reading the tables:

- **The rules were sharpened between the spike and the gate.** They now
  follow the design's amendments (§12). The walking band is measured from
  drawn ground, where low steps and plinths count as ground. A seat's own
  furniture is exempt only inside its protected square. The reverse gate
  counts blocked-looking-open cells inside rooms.
- **The first measurement with the gating tool** (Task 10, at cd70571)
  was taken with the catalogue's footprints but before any style was
  refitted. It stood at 984–1,629 through cells, 3,357–3,885 within 10 cm,
  12–306 walker pass-throughs, 119–153 player pass-throughs, no tram
  overlaps, and 9,825–22,265 blocked cells that looked open. The refits
  brought every count to zero.

Pixel art also reports 302 open-looking cells outside every room. These are
lawn and verge the design leaves ungated (§10) and draws light blue. The 3D
styles and voxel report none.

**The overlays** draw each cell at 4 px:

- walkable floor green;
- blocked grey;
- seat cells yellow;
- within 10 cm orange;
- through red;
- blocked cells that look open blue.

| Style | Before | After |
| --- | --- | --- |
| anime_cel | [before](placement-anime_cel-overlay-before.png) (cd70571) | [after](placement-anime_cel-overlay-after.png) |
| solarpunk | [before](placement-solarpunk-overlay-before.png) (cd70571) | [after](placement-solarpunk-overlay-after.png) |
| neon_noir | [before](placement-neon_noir-overlay-before.png) (cd70571) | [after](placement-neon_noir-overlay-after.png) |
| lowpoly_tropical | [before](placement-lowpoly_tropical-overlay-before.png) (cd70571) | [after](placement-lowpoly_tropical-overlay-after.png) |
| voxel | [before](placement-voxel-overlay-before.png) (f038695) | [after](placement-voxel-overlay-after.png) |
| pixel_art | [before](placement-pixel_art-overlay-before.png) (56d3f12) | [after](placement-pixel_art-overlay-after.png) |

Each before image is from the commit before that style's refit:

- red through cells on both building shells and along the bridge;
- an orange rim along the fences;
- blue round every block lot, the shelters, the planting, the benches and
  the great tree.

The five after images for the 3D styles and voxel were recaptured at
818201d, after the ring's benches moved (Task 13). Against the images they
replace, only the ring round the great tree changed. By pixel count they
hold only green, greys and seat yellow: no red, orange or blue. Pixel
art's after image, taken at 4d97a8e, is identical to a capture made now.
It adds the light blue outside the rooms.

## Doors work the way they look

`tests/test_door_entry.gd` boots each style under the door study's
conditions: seed 7, no crowd, tick 300, with the rooms open. It tries every
building door with real input.

**Before** (the door investigation, production at 05b5b90). The figures
are entries that ended inside, over attempts. Low-poly and anime were
identical, row for row.

| Approach | Result |
| --- | --- |
| Stick, straight in across the drawn opening (−100…+100 cm), each building door | 6/11 (only −37…+50 cm got in) |
| Stick, within 35° of the door's axis (4 doors) | 419/420 |
| Stick, 40° | 48/56 |
| Stick, 45–50° | 28/112 (25%) |
| Stick, 55–80° | 196/336 (58%) |
| Pixel art keys, each lined up on the guild-hall doors | 4/16 (W and A 0/8) |
| First person "Go in" at the commons door | 0/1 (walked to the workshop) |
| First person "Walk here" at the commons–workshop doorway, from inside | 0/1 (walked out to the park) |

The drawn openings were 2.0–2.4 m wide, and the walkable ones 1.0 m.

**Now** (818201d): 100% in every style, every door and every family. The
same table printed for each of the six styles:

```
door                     straight in  sweep        keys 45°     first person
door:workshop-plaza      9/9          462/462      (pixel 28/28) 1/1
door:workshop-commons    5/5          231/231      (pixel 14/14) 1/1
door:commons-plaza       9/9          462/462      (pixel 28/28) 1/1
door:commons-workshop    5/5          231/231      (pixel 14/14) 1/1
door:reading-plaza       9/9          462/462      (pixel 28/28) 1/1
```

- **Straight in** starts every 25 cm across the opening: −100…+100 cm at
  the 200 cm outside doors, and −50…+50 cm at the 100 cm interior door.
- **The sweep** runs from −80° to +80° off the door's axis in 5° steps,
  crossing the opening at points no more than 15 cm apart.
- **Keys** are pixel art's movement keys, each at exactly 45° to the door.
- **First person** is a Go in (or Walk here, from inside) at each door.
  Pixel art has no first person.

The six styles took 1.7–2.1 s each.

**The door captures** show each opening with its walkable span in red
(`tools/probes/capture_doors.gd`, 1280 × 800):

| Style | Guild hall, workshop door | Library entrance |
| --- | --- | --- |
| anime_cel | [workshop](placement-anime_cel-door-workshop-plaza.png) | [library](placement-anime_cel-door-reading-plaza.png) |
| solarpunk | [workshop](placement-solarpunk-door-workshop-plaza.png) | [library](placement-solarpunk-door-reading-plaza.png) |
| neon_noir | [workshop](placement-neon_noir-door-workshop-plaza.png) | [library](placement-neon_noir-door-reading-plaza.png) |
| lowpoly_tropical | [workshop](placement-lowpoly_tropical-door-workshop-plaza.png) | [library](placement-lowpoly_tropical-door-reading-plaza.png) |
| voxel | [workshop](placement-voxel-door-workshop-plaza.png) | [library](placement-voxel-door-reading-plaza.png) |
| pixel_art | [workshop](placement-pixel_art-door-workshop-plaza.png) | [library](placement-pixel_art-door-reading-plaza.png) |

## Planting, lamps and seats

The street and diagonal views (`tools/probes/capture_views.gd`, from the
north platform) show:

- the fitted planting, lamps, poles and shelters;
- the ring of benches round the great tree;
- the block lots behind their garden walls and gates.

| Style | Street | Diagonal |
| --- | --- | --- |
| anime_cel | [street](placement-anime_cel-street.png) | [diagonal](placement-anime_cel-diagonal.png) |
| solarpunk | [street](placement-solarpunk-street.png) | [diagonal](placement-solarpunk-diagonal.png) |
| neon_noir | [street](placement-neon_noir-street.png) | [diagonal](placement-neon_noir-diagonal.png) |
| lowpoly_tropical | [street](placement-lowpoly_tropical-street.png) | [diagonal](placement-lowpoly_tropical-diagonal.png) |
| voxel | [street](placement-voxel-street.png) | [diagonal](placement-voxel-diagonal.png) |
| pixel_art | [street](placement-pixel_art-street.png) | [diagonal](placement-pixel_art-diagonal.png) |

**Seated occupants.** Task 11 drew the seats whole again, stretched to
their footprints plus the seat's square: benches came out about 1.2 times
as wide and 1.5 times as deep as modelled, and Task 16's captures showed
sitters perching on the front edge, about 0.3 m of empty slats behind them.
The final fix wave re-measured the `bench` and `cafe-table` footprints to
the whole kits (the 3D kits' 1.6 m bench, its back 25–35 cm behind the
sitter; a café chair its sitter's width), so each is drawn within a few
centimetres of its own size, and moved the right-angle benches' points to
their cells' centres, where the core seats the sitter (they were on cell
corners, 12 cm off in both directions). These captures are at tick 150,
when every desk in the workshop and every bench in the commons is taken.

- [`placement-anime_cel-seated-desk.png`](placement-anime_cel-seated-desk.png):
  **desks read well.** Each sitter is in the desk chair, pulled up to the
  desk and facing the screen, with the chair's back behind them.
- [`placement-anime_cel-seated-bench.png`](placement-anime_cel-seated-bench.png):
  **benches read as seated.** Each sitter is in the middle of a bench of
  its own size, the backrest directly behind their back, knees over the
  front edge. The earlier band of empty slats behind them is gone; from
  overhead the sitters' heads are over the backrest line.
- [`placement-pixel_art-seated.png`](placement-pixel_art-seated.png),
  with the workshop and commons opened: **both read as seated.** Desk
  sitters sit in their chairs at the desks, facing their monitors. On the
  commons benches (redrawn at the kits' 1.6 m) each sitter is in the middle
  of the seat with the backrest close behind.

## Scale

`cargo test --release -p city-core -- --ignored scale_district` builds a
400 × 400 m district (2.56 million cells) in 16 open 100 m grounds. It holds
5,000 placements: 8 blocks of 40 × 30 m, and 4,992 other placements on a 5 m
lattice. The test then times:

- the build;
- 100 moves: a scattered placement by up to a metre and a turn, and every
  tenth move a block shifted 2 m;
- 5 changes that need the whole grid compared: a bollard beside each
  entrance, and a planter filling a 1 m passage 40 m long.

Each change is timed by the path it took, as the design's amendments
set the budgets. A move the local proof settles must take 1 ms or less. A
change compared against the whole grid must take 200 ms or less, whether it
is one of the five or a move that needed it. The test also requires at
least 90 of the 100 moves to settle locally.

Three runs on 2026-09-28 at 775f161, after the final fix wave trimmed the
whole-grid path (71777ec: one labelling of the grid's walks gives both the
links and the entrances' reach, where a separate reach flood ran too):

| Measure | Result | Target |
| --- | --- | --- |
| Load (5,000 placements validated, the grid built, reach checked) | 86–91 ms | ≤ 200 ms |
| Grid build (`NavGrid::build`) | 28–30 ms | ≤ 200 ms |
| Reach (breadth-first from the entrances) | 36–38 ms | — |
| Moves settled locally | 98 of 100 | ≥ 90 |
| Those moves, mean | 0.071–0.073 ms | — |
| Those moves, slowest | 0.46–0.49 ms | ≤ 1 ms |
| Moves compared against the whole grid | 2 of 100, 121–127 ms | ≤ 200 ms |
| The 5 whole-grid changes, each | 119–123 ms | ≤ 200 ms |
| The whole-grid labelling alone (walks, links and reach) | 61–68 ms | — |

At dcd3392, before the trim, the same session measured the whole-grid
changes at 147–154 ms (and Task 16's four runs 156–185 ms).

**Why two moves need the whole grid.** Both are `tram-shelter`
placements, turned to 108° and 21°. Task 11 re-measured the shelter's
footprint as a back, a bench and one end, open at the front. At those angles
the outline seals one walkable cell into a pocket. The local proof sees a
cell beside the change that nothing nearby joins to the rest, so it
compares the whole grid. That comparison finds nothing that matters cut
off, and accepts the move.

**The test's history.** Until the paths were timed apart, the test counted
every move against 1 ms, so these two failed it from Task 11 (bb0a7be)
on. The test is ignored by default, and no task ran it between Task 4 and
Task 16. Task 10's re-measure (ed50bd5 to 05a80bf) left the scene unable to
load: validation refused shelters whose `stand` anchors could not be reached
(`anchor-unreachable`).

**The margin.** Before the trim the slowest whole-grid change came within
15 ms of its budget once in four runs (185 ms). After it, the slowest of
three runs is 127 ms, 73 ms inside.

**Kept by plain `cargo test`.** `ordinary_moves_settle_locally` makes 300
moves, each turned any way, in a 100 × 100 m ground of 300 placements, in
0.15 s. Every accepted move but six pocket-sealing tram shelters settles
locally (slowest 0.08 ms in the test profile); any other kind needing the
whole grid, or more shelters doing so, fails it.

First measured in Task 4, before the catalogue was re-measured:

- load 86–91 ms;
- build 28–30 ms;
- local moves 0.066 ms on average, 0.52 ms at slowest;
- the whole-grid comparison 93–98 ms.

## The frame bench against v0.0.3

Measured on 2026-09-28 after a desktop restart. The empty scene reached 360 fps with vsync, so the desktop was healthy. The laptop was on the performance power profile, fullscreen at native 1920×1080.

Each style ran first on this branch (at 647720d) and then on v0.0.3 (79e3758), and every run started from a GPU at or below 45 °C. The fps column is the vsync frame rate on the 360 Hz panel.

| Style | Scene | CPU p50 ms (v0.0.3 → branch) | GPU p99 ms | fps |
| --- | --- | --- | --- | --- |
| anime_cel | diagonal | 2.43 → 2.27 | 2.35 → 2.18 | 347.8 → 348.4 |
| anime_cel | fpv | 2.19 → 2.10 | 2.13 → 2.03 | 348.0 → 348.2 |
| anime_cel | map | 0.76 → 0.75 | 0.10 → 0.10 | 349.0 → 349.4 |
| anime_cel | menu | 2.52 → 2.37 | 2.45 → 2.29 | 348.0 → 348.0 |
| anime_cel | street | 2.06 → 1.96 | 1.95 → 1.84 | 348.0 → 348.2 |
| anime_cel | street-night-rain-300 | 2.50 → 2.42 | 2.44 → 2.38 | 344.6 → 344.6 |
| anime_cel | title | 2.47 → 2.31 | 2.44 → 2.28 | 347.8 → 348.2 |
| anime_cel | topdown | 2.25 → 2.05 | 2.17 → 1.97 | 348.0 → 348.2 |
| anime_cel | tram | 2.78 → 2.68 | 2.75 → 2.30 | 328.0 → 329.0 |
| lowpoly_tropical | diagonal | 3.57 → 3.39 | 3.67 → 3.23 | 267.2 → 285.8 |
| lowpoly_tropical | fpv | 3.46 → 3.19 | 2.94 → 2.99 | 278.2 → 301.2 |
| lowpoly_tropical | map | 0.75 → 0.75 | 0.11 → 0.11 | 348.4 → 349.0 |
| lowpoly_tropical | menu | 3.72 → 3.37 | 3.61 → 3.24 | 266.2 → 284.4 |
| lowpoly_tropical | street | 2.82 → 2.63 | 2.93 → 2.53 | 336.8 → 346.6 |
| lowpoly_tropical | street-night-rain-300 | 4.46 → 4.16 | 2.91 → 2.78 | 211.8 → 230.0 |
| lowpoly_tropical | title | 3.42 → 3.33 | 3.69 → 3.25 | 281.8 → 301.0 |
| lowpoly_tropical | topdown | 3.38 → 3.11 | 2.69 → 2.53 | 273.4 → 296.6 |
| lowpoly_tropical | tram | 5.29 → 4.82 | 3.56 → 3.38 | 177.8 → 193.0 |
| neon_noir | diagonal | 2.55 → 2.42 | 2.48 → 2.34 | 347.8 → 348.2 |
| neon_noir | fpv | 2.16 → 2.10 | 2.07 → 2.02 | 348.0 → 348.4 |
| neon_noir | map | 0.76 → 0.76 | 0.11 → 0.11 | 348.8 → 348.6 |
| neon_noir | menu | 2.63 → 2.51 | 2.58 → 2.45 | 347.6 → 347.4 |
| neon_noir | street | 2.05 → 1.98 | 1.95 → 1.88 | 348.0 → 348.4 |
| neon_noir | street-night-rain-300 | 3.08 → 2.90 | 3.08 → 2.95 | 303.2 → 320.4 |
| neon_noir | title | 2.63 → 2.49 | 2.67 → 2.49 | 345.4 → 348.2 |
| neon_noir | topdown | 2.37 → 2.08 | 2.31 → 1.97 | 348.0 → 348.6 |
| neon_noir | tram | 2.89 → 2.75 | 2.92 → 2.53 | 308.4 → 333.2 |
| pixel_art | diagonal | 0.84 → 1.24 | 0.28 → 0.27 | 349.0 → 349.0 |
| pixel_art | map | 0.96 → 1.39 | 0.27 → 0.33 | 348.8 → 348.8 |
| pixel_art | menu | 0.89 → 1.33 | 0.33 → 0.39 | 348.4 → 348.8 |
| pixel_art | street | 0.79 → 0.88 | 0.32 → 0.31 | 348.4 → 349.0 |
| pixel_art | street-night-rain-300 | 1.49 → 1.68 | 0.36 → 0.57 | 348.6 → 348.4 |
| pixel_art | title | 0.87 → 1.28 | 0.28 → 0.28 | 349.0 → 348.8 |
| pixel_art | topdown | 1.02 → 1.88 | 0.20 → 0.37 | 349.0 → 349.0 |
| pixel_art | tram | 0.84 → 1.21 | 0.18 → 0.41 | 348.8 → 348.4 |
| solarpunk | diagonal | 3.06 → 2.92 | 2.98 → 2.87 | 323.8 → 334.2 |
| solarpunk | fpv | 2.48 → 2.41 | 2.42 → 2.36 | 348.4 → 348.2 |
| solarpunk | map | 0.75 → 0.76 | 0.10 → 0.10 | 348.8 → 348.8 |
| solarpunk | menu | 3.14 → 2.95 | 3.32 → 2.97 | 311.6 → 332.8 |
| solarpunk | street | 2.37 → 2.30 | 2.31 → 2.23 | 348.0 → 348.2 |
| solarpunk | street-night-rain-300 | 2.61 → 2.51 | 2.62 → 2.50 | 342.2 → 345.8 |
| solarpunk | title | 3.04 → 2.89 | 3.11 → 2.98 | 306.4 → 340.8 |
| solarpunk | topdown | 2.69 → 2.46 | 2.66 → 2.40 | 347.6 → 348.6 |
| solarpunk | tram | 3.47 → 3.15 | 3.75 → 3.15 | 258.8 → 279.6 |
| voxel | diagonal | 3.57 → 3.04 | 3.28 → 3.60 | 277.0 → 318.6 |
| voxel | fpv | 3.25 → 2.68 | 2.59 → 2.37 | 292.0 → 343.4 |
| voxel | map | 0.74 → 0.75 | 0.11 → 0.11 | 348.6 → 348.6 |
| voxel | menu | 3.42 → 3.34 | 4.07 → 3.44 | 272.6 → 308.6 |
| voxel | street | 2.57 → 2.31 | 2.41 → 2.23 | 343.2 → 348.8 |
| voxel | street-night-rain-300 | 4.11 → 3.50 | 2.64 → 2.43 | 226.8 → 269.6 |
| voxel | title | 3.48 → 2.98 | 3.58 → 3.18 | 282.2 → 322.0 |
| voxel | topdown | 3.16 → 2.65 | 2.86 → 2.55 | 290.6 → 342.0 |
| voxel | tram | 5.29 → 4.33 | 3.50 → 3.15 | 178.8 → 215.2 |

- **The 3D styles** are as fast or faster in every scene. The gain has not been profiled. The likely source is Task 8's planting, which now draws as batched instances instead of scattered single nodes. The largest gains are in voxel (tram 179 → 215 fps, top-down 291 → 342) and low-poly (tram 178 → 193, diagonal 267 → 286). Solarpunk's title scene rises from 306 to 341 fps.
- **Pixel art** stays pinned at the panel's frame rate in every scene. Its CPU p50 rose by 0.1–0.9 ms, most in the top-down view, from the walls, gates and planting it now draws as sprites.
- **Scenes over budget:** anime's tram and neon's tram are over their style budgets on both builds, and solarpunk's diagonal, menu and tram too. The branch leaves each one at or above its v0.0.3 figure.
