# City placement grid: design

Date: 2026-09-27. This spec comes from two spikes on branch `spike/collision-audit` (commits 5e23ca7 and c1c5708):

- **The door investigation:** about 3,600 probe walks, finding why entering buildings fails.
- **The collision audit:** every style's drawn world measured against the walkable grid.

Their reports are git-excluded working notes. The numbers they found are repeated here where a decision rests on them.

The user's choices, 2026-09-27:

- **Approach:** a placement grid. One catalogue of kinds with footprints. Placements of those kinds are the only solid things. The core derives the walkable grid from them.
- **Style extras:** planting, lamps and poles become world content in the manifest, skinned by each style. Styles keep their freedom above head height and in ornament.
- **Scale:** the model must scale to the vision. That means rooms and portals, districts, plots and build mode, rooftops and storeys, and a world that changes while people are in it. §9 shows how. Four things are built in from the start:
  - a grid per district;
  - exact placements, from which the walking grid is derived;
  - a level on every placement and floor;
  - placement changes as validated commands.
- **Interactions (added the same day):** the catalogue takes the shape of the vision's asset definition (`docs/gameplay/asset-catalogue/CHARACTERISTICS.md`), and placements are its instances. Each kind carries typed anchors, named capabilities and soft footprints, and each instance carries reserved state and binding fields. What those capabilities do (sit anywhere, read a noticeboard, use a workstation, plants that sway) is the next spec, `2026-09-27-city-interactions-design.md`. This spec only fixes the data's shape, so interactions add behaviour without a second migration.

## 1. Goal and success

Today three sources of truth disagree:

- **The core** walks people on 25 cm cells cut from room rectangles minus obstacle rectangles.
- **The manifest** also places props, seats, tree rows, parapets and blocks, which the core never sees.
- **Each style pack** draws its own shells, furniture and extras at its own sizes.

The result, measured in every style:

- **Walking through solids:** 1.4–2.1% of walkable floor (135–211 m²) lies inside something solid. Walkers end 1.1–8.3% of their cell visits there, and the scripted player passes through solids 145–345 times a day.
- **Blocked ground that looks open:** up to 3,939 cells, mostly sidewalk inside block obstacles.
- **Doors that refuse entry:**
  - approaches more than 35° off the door's axis slide along the wall;
  - the drawn doorway is 2.0–2.4 m wide, but the walkable one is 1.0 m;
  - full rooms silently queue the player or send them to another room;
  - "Go in" picks the wrong room.

After this spec there is one source of truth. **The catalogue** says how much ground each kind of thing takes. **Placements** say where each thing stands. **The core** derives the walkable grid from rooms and placements. **Every pack** draws each thing inside its footprint.

**Success is judged in five ways.**

1. **Nothing walks through anything.** The collision audit, run as a test in every style, reports zero for each of these:
   - cells whose centre lies inside a drawn solid in the walking band (0.25–1.9 m above the ground);
   - cells whose centre lies within 10 cm of such a solid. Seat cells (§3) are excluded, because only their own occupant enters them;
   - walker and player pass-throughs over the recorded day;
   - walkers inside a drawn tram but outside the core's tram footprint;
   - blocked cells that look open because of an obstacle, block or footprint. Open-looking ground outside every room is still reported, but not gated (§10).
2. **Doors work the way they look.** In every style, the door probes enter every building door:
   - **100% of straight-in approaches** anywhere across the drawn opening;
   - **100% of approaches up to 80° off the door's axis,** by stick, keys (pixel art's diagonal keys included) and first person;
   - **"Go in" enters the room behind the door being faced.**

   Walking into a full room is refused with a notice. It never silently queues the player or moves them to another room.
3. **Determinism holds.** The same manifest, feed and seed give a byte-identical event log. A placement change applied during play replays identically. The incremental grid after any sequence of changes equals a grid rebuilt from scratch.
4. **One grid, not two.** The client loads the core's walkable grid through the bridge. It no longer rasterises its own copy from the layout, so the two cannot drift.
5. **It scales.** A synthetic district of 400 × 400 m (2.56 million cells) with 5,000 placements builds in 200 ms or less. A single placement change updates in 1 ms or less, in a native release build on the development laptop. The frame-rate bench stays within noise of v0.0.3 in every style.

## 2. The catalogue

The catalogue is versioned data: `city/catalogue/catalogue.json`, embedded into `city-core` at build time.

- A manifest names the catalogue version it was written against (`"catalogue": 1`). Validation refuses a version the core does not carry.
- A later reviewed asset, such as one from the asset forge (F23), is a new kind in a new catalogue version. It needs no new code.

Each **kind** has these fields:

| Field | Meaning |
| --- | --- |
| `id` | Kebab-case name, such as `desk`, `street-lamp`, `guild-hall` or `tram`. Style packs map this key to their art. |
| `class` | One of `furniture`, `seat`, `fixture`, `planting`, `block`, `building` or `vehicle`. It decides which rules apply (below). |
| `footprint` | A list of shapes, in centimetres in the kind's own frame: the origin is the placement point, and facing 0 means north. A shape is a rect `{x, z, w, d}` or a disc `{x, z, r}`. It is the ground the thing takes in the walking band. |
| `soft` | Shapes in the same form that do not block walking: tall grass, flowers, low shrubs, curtains, bead strings. The grid ignores them. Clients may animate them when someone moves through (the interactions spec). A shape is either in `footprint` or in `soft`, never both. |
| `sized` | When true, the placement gives its own `size: {w, d}`, which replaces the footprint with one rect centred on the point. Used for blocks, planters and beds. |
| `snap` | The step, in centimetres, that a placement's point must lie on. Architecture uses 200, buildings 100, street furniture 25 and seats 1. Authored content is checked against it, and build mode will snap to it. |
| `anchors` | Typed connection points in the kind's frame, each `{type, at: {x, z}, facing, height?}`. The types are `enter` (where one steps in or on), `sit` (a seat's point, facing the way the sitter faces), `use` (where one stands or sits to use it), `display` (a surface that shows content: its centre, facing and size `{w, h}`) and `stand` (a place to wait or watch). Every `enter`, `sit`, `use` and `stand` anchor must be walkable and reachable. A `display` anchor is a surface, not a place to stand. |
| `capabilities` | The actions a kind offers, named from the vision's reusable capabilities: `inspect`, `sit`, `use`, `read`, `open`, `board`, and later `carry`, `store`, `write` and others. Each names the anchor type it happens at. In this spec the list is validated against the known names and otherwise inert, except `sit` and `board`, which already work. |
| `state` | The state fields an instance of this kind may hold, with their types and defaults, such as a lamp's `lit: bool` or a board's `panel: ref`. Empty for most kinds. Declared here, used by the interactions spec. |
| `height` | The top of the solid part, in centimetres. Packs are told it; it has no effect on the grid. |

Class rules:

- **`seat`:** kinds are the furniture around one or more `sit` anchors, such as a desk in front of the chair or a bench's ends and back. A sit anchor's own cell is never blocked (§3).
- **`building`:** kinds also give `wall` (the shell thickness, 25 cm by default) and `door_width` (the width of an exterior opening). The first building kinds use 200 cm; interior doors use 100 cm.
- **`vehicle`:** kinds give `width`. A tram is 250 cm, and its length and doors stay on the line's `VehicleSpec`.

**The first catalogue** covers everything the district draws today:

- **Seat furniture:** `desk`, `bench`, `cafe-table`, `reading-chair`.
- **Furniture:** `bookshelf`, `workbench`, `cafe-table-top`, which is the table the café chairs ring.
- **Fixtures:**
  - `street-lamp` and `bollard`;
  - `umbrella`, whose pole counts and whose canopy is above the band;
  - `tram-shelter`, with its posts, glass and bench;
  - `catenary-pole`.
- **Planting:** `street-tree`, `palm`, `great-tree` (with its roots), `shrub`, `planter`, `flowerbed` and `path`. The last two are below the band and have an empty footprint.
- **Blocks:** `block-house`, `block-shop`, `block-tower`, all sized.
- **Buildings:** `guild-hall`, `library`, `cafe`.
- **Vehicles:** `tram`.

**How footprint values are set.** The plan measures each kind's kit in all six styles, using the audit's walking-band slice. The footprint covers the widest style's silhouette, rounded up to 5 cm. Packs whose kit is well outside the common size are trimmed to fit, rather than the footprint growing to fit them.

## 3. Placements and the walkable grid

### Placements

A placement is an instance of a kind: `{id, kind, at, facing, level, size?, state?, binding?}`:

- `id` is `placement:<slug>`, stable, so later commands and undo can name it.
- `at` is a point in integer centimetres.
- `facing` is in whole degrees clockwise from north. Any whole degree is allowed, because the café and great-tree seats ring at 36° steps.
- `level` is described below.
- `state` holds values for the kind's declared state fields. Omitted fields take the kind's defaults, and validation refuses an undeclared field or a wrong type.
- `binding` is reserved for a display that shows an outside record: `{source, ref}`, for example a published Superpipeline board. Validation accepts only kinds with a `display` anchor. Nothing reads it until the interactions spec.

Where placements live:

- **District placements:** `district.placements`, in district coordinates. With one district these are the same as today's coordinates.
- **Seats** stay in their rooms, because they carry rules (pods, reservations). A seat's `kind` names a `seat`-class kind whose `sit` anchor is at the kind's origin, so each seat is a placement of its furniture at its own position and facing. A bench with several sit anchors becomes one bench placement, and each of its seats records which anchor it is (`anchor: <index>`).
- **Buildings:** a facility gains `kind`, naming a `building`-class kind. It replaces `exterior`, which packs used for the same purpose.

What is removed from the contract:

- `Room.obstacles` and `Room.props`: everything solid is now a placement.
- The `TreeRow` and `Block` scenery variants: the generator expands tree rows into `street-tree` placements, and blocks become sized block placements.

What stays: `Water`, `Street`, `Bridge` and `Fence`. They describe surfaces and edges, not solids on walkable ground. The bridge's walkable deck is its room, and its parapets are drawn outside the deck (§7).

The manifest `schema_version` becomes 2. The fixture generator writes version 2, and the core refuses version 1 with a message naming the generator.

### Levels

Every placement and every room carries a `level`, defaulting to 0. A level is a storey index; later it may also be an elevation. The grid is built per level. In this spec, validation refuses any level other than 0 with "levels above the ground arrive with rooftops". This fixes the shape of the data now, so rooftops, storeys and bridges with clearance below slot in without a second migration (§9).

### Deriving the grid

The grid keeps today's cells (25 cm, centre at the corner plus 12 cm) and today's step rules (eight neighbours, no corner-cutting, rooms joined only by door spans unless both are outdoor). A cell of level L in district D is **walkable** when both of these hold:

1. its centre lies inside a room of D at level L (minimum edges in, maximum edges out; a later room ID wins an overlap), as today;
2. its centre lies more than 10 cm outside every footprint of every placement of D at level L. **The 10 cm margin is the body clearance.** A pack that draws inside the footprint can never be within 10 cm of a walker's cell centre, which is the audit's second gate.

Footprints are exact integer geometry. A rect at any facing is tested by rotating the cell centre into the placement's frame, using a fixed table of sine and cosine for whole degrees, scaled to 2¹⁶ and rounded once in the table. That makes the result the same on every platform. Discs compare squared distances in `i64`.

Three kinds of cell are carved back or kept:

- **Seat cells.** The cell holding a seat's point is always walkable, and its furniture footprint surrounds it. Walks enter a seat cell only when that seat is their destination. That makes an empty bench a bench, not a path. A Steer onto a seat cell is refused (`seat`). Sitting is done by Go.
- **Door spans.** A building's shell never blocks the span cells of its own doors.
- **Track cells.** They stay as today. A vehicle's footprint is dynamic, and the core blocks those cells tick by tick, using `HALF_WIDTH` = the vehicle kind's width / 2 (125 cm, was 100). Platforms stand 150 cm from their track, so a 2.5 m tram clears them by 25 cm.

**Building shells** are footprints too. A building's shell is the union of its rooms' rects, grown outward by the kind's `wall`, less an opening of `door_width` at each exterior door and of 100 cm at each interior door. Interior partitions are part of the shell, centred on the edge the rooms share. Walls therefore stand outside the rooms' floors, not inside them. That removes the audit's largest kind (shell walls, 568–1,386 through cells a style) without shrinking any interior.

**Door spans** take their width from the door. `Door.width` is optional; its default is the owning building kind's `door_width` for exterior doors and 100 cm otherwise. The span is a cross that width along the wall and two cells deep either side, as today at 100 cm. Queue slots and admission keep their rules at the new widths.

**Validation** adds these checks, each with its placement's ID and a message:

- the kind is known;
- the level is 0;
- the point lies on the kind's snap;
- a sized kind has a size, and an unsized kind has none;
- the footprint does not cover a seat cell, a door span, a track cell, a platform edge's clearance, or another placement's anchor;
- every `enter`, `sit`, `use` and `stand` anchor is walkable and reachable from the district's entrances;
- capabilities, state values and bindings are well formed, as above;
- every room keeps at least one walkable cell per seat and per unit of capacity. That catches a footprint that eats a room.

### Changes over time

A placement change is a deterministic command, `Place`, `Move` or `Remove`, handled by one function: `World::apply_placement`.

- **The manifest is loaded through it.** Every authored placement goes through the same validation, in ID order. Authored and runtime placements therefore obey one set of rules.
- **At runtime it runs between ticks** as an operator input. It is recorded in the input log and replays identically. It is refused, with a reason, when it would:
  - fail validation;
  - cover a cell someone stands on or holds;
  - cut the last walkable route between two rooms that had one.
- **The grid updates incrementally.** Only cells within the changed footprints' bounds, plus the margin, are recomputed.
  - Walkers whose remaining path crosses a newly blocked cell re-plan on the next tick.
  - Queue slots are recomputed for rooms whose cells changed.
  - The viewers' projections carry `grid_changes`, the cells whose state changed, so clients stay in step.
- **Only operators and tools send it here.** No in-game build mode exists yet (§10). Edit rights for residents and cooperative rooms arrive with plots.

## 4. What viewers and tools receive

- **The bridge's `layout_json`** gains `grid`: the origin, columns and rows, each level's cell states as run-length-encoded room indices, and the door spans. `NavQuery.from_layout` loads it instead of rasterising the layout. The GDScript rasteriser and its duplicated constants are deleted. The client keeps its prediction logic (held cells, closed rooms, steps), now reading the core's cells.
- **Projections** carry `grid_changes` after a placement command.
- **The catalogue** is exposed as `catalogue_json` on the bridge. Packs and the map read kinds and heights from it.
- **The CLI:**
  - `city-cli catalogue` lists kinds;
  - `city-cli grid <manifest> [--png <out>]` prints grid statistics or renders the walkable grid;
  - `city-cli place <manifest> --kind <k> --at <x,z> [--facing <deg>] [--size <w,d>]` validates and writes one placement into a manifest file, refusing with the same reasons as the core;
  - `city-cli validate` reports the new checks.
- **The MCP server:**
  - `catalogue`;
  - `check_placement`, which validates a proposed placement against a manifest without writing it;
  - the existing `validate`, extended.

  Agents can therefore reason about layout the way the CLI does.

## 5. Migrating the district fixture

`city/fixtures/district/generate.py` writes schema 2. Here is how each old item maps to the new model:

| Today | Becomes |
| --- | --- |
| Workshop desk obstacles, and seats of kind `desk` | Seats of kind `desk`; their footprints replace the obstacles. |
| Workbench obstacle and prop | A `workbench` placement. |
| Commons bookshelf prop and benches | A `bookshelf` placement, and `bench` seats. |
| Reading-room shelves | `bookshelf` placements. The floor between them stays walkable. |
| Café table obstacles | `cafe-table-top` placements; the chairs are `cafe-table` seats. |
| Plaza great tree and its 4 × 4 m obstacle | A `great-tree` placement whose footprint includes the roots. |
| Palms and their obstacles | `palm` placements. |
| Tram shelters | `tram-shelter` placements, with a `stand` anchor on the platform side. |
| Lamps, bollards, umbrellas, planters, flowerbeds, path | Placements of their kinds. |
| Blocks (scenery, carved from ground rooms as obstacles) | Sized block placements. The size is the drawn lot, porches and steps included, and nothing reaches past the lot onto the sidewalk. |
| Tree rows | `street-tree` placements at the row's spacing, set back from walkable cells or on verges. |
| Planting drawn by each pack (`_plant`, `_grove`) | `street-tree`, `shrub` and `planter` placements the generator lays out on verges and lawns. It uses one arrangement, which each style skins. |
| Street lamps drawn only in solarpunk and neon | `street-lamp` placements, drawn in every style. |
| Catenary poles drawn by packs | `catenary-pole` placements along the line, outside the tram footprint. |
| Facility `exterior` | Facility `kind`. |

The generator grows each building's shell outward and checks the result with the core's validation. It moves any neighbouring outdoor room or placement the shell would cover, and says in a comment what moved and why. The fixture test still checks that the generator's output is the committed manifest.

The core's replay and scenario fixtures change because the grid changes. They are regenerated in the same commit as the grid change, and the invariants still hold on every tick.

## 6. Doors

- **Stepping in at an angle.** When the line's preferred step is refused, `Player._next_cell` takes an allowed step that crosses into the next room before any step along the wall. It still respects closed rooms and held cells. In the spike's pure-logic check, this took 45–50° approaches from 28/140 to 140/140, and exactly-45° pixel-art keys from 28/70 to 70/70. The core already accepts these steps, so no Steer that is accepted today is refused.
- **Wide doors.** Exterior doors are 200 cm walkable, matching the drawn openings (§3). Every pack draws each opening from the door's width: 3D bays, pixel-art door sprites and interior partitions alike. The library entrance is redrawn open in anime, neon and solarpunk: no lit panel across it, and leaves drawn open.
- **Full rooms.**
  - A steered entry tries only the room it walks into. It never overflows to another room. When the room is full, the step onto its span is refused, with the notice "The workshop is full — choose Go in to queue."
  - Go and Room keep queueing and overflow, and now raise the notices "You're next in line for the workshop" and "The workshop is full; you've been let into the commons".
  - A door whose room is closed to the player shows it on the context prompt ("Full").
  - The rule change applies to Steer only. Agents, and anything Superpipeline sees, keep their admission rules.
- **Go in and Walk here.** In first person, "Go in" enters the room behind the door being faced, not the building's first room. Inside a building, "Walk here" snaps to the building's own floor, never to ground beyond its walls.

## 7. Style packs

- **Kinds, not guesses.** `StylePack.REQUIRED["props"]` becomes the catalogue's kinds. Every pack maps each kind in `style.json` or declares it a placeholder, as today.
- **Fit to footprint.** In the walking band, everything a pack draws for a placement stays inside its footprint. Above 1.9 m (foliage, canopies, awnings, signs, eaves) and below 0.25 m (kerbs, beds, paths, steps no higher than 25 cm), packs are free. The audit enforces this.
- **Shells** draw their walls outside the room rects, at the kind's `wall` thickness, with openings at each door's width.
- **Trams** are drawn 250 cm wide in every style: voxel narrows from 2.6 m, and pixel art widens from 2.4 m.
- **The bridge** draws its parapets outside the deck.
- **Blocks** draw their buildings, porches and steps inside the block's size.
- **Extras** that belong to a pack alone, such as moored boats, clutter or decals, may stand only where every cell within 10 cm is not walkable, or entirely above or below the band. `CityGeometry` gains `clear_of_walkable(rect)`, answered from the core's grid, and `_plant`, `_grove` and any future scatter use it. The old `drawn_rooms` exclusion, which missed walkable `ground` rooms, is removed.
- **Pixel art** fits each sprite's ground footprint (the model it was rendered from) to its kind's footprint, and regenerates the sprites that change.

**Evidence** is committed under `city/godot/evidence/placement-*`, per style:

- the audit overlay before and after;
- the door captures, with each opening's walkable span shown;
- the new planting and lamp arrangement.

## 8. Structure

- `city/catalogue/catalogue.json`: the kinds.
- `city-contracts`:
  - `catalogue.rs`: the `Kind`, `Shape`, `Class`, `Anchor`, `Capability`, `StateField` and `Catalogue` types, with JSON Schema;
  - `manifest.rs`: `Placement` (with `state` and `binding`), `District.placements`, `Facility.kind`, `Door.width`, `Seat.anchor`, `level`, schema 2.
- `city-core`:
  - `footprint.rs`: the shapes, the fixed trigonometry table and rasterisation;
  - `nav.rs`: the grid built from rooms minus footprints, per district and level, with seat cells and door widths;
  - `placement.rs`: validation, `apply_placement` and the incremental update;
  - `transit.rs`: the vehicle width taken from the kind.
- `city-godot`: `grid` in `layout_json`, `catalogue_json`, and `grid_changes` in projections.
- `city-cli`, `city-mcp`: the commands and tools in §4.
- The client:
  - `core/nav_query.gd` loads the core's grid;
  - `core/player.gd` gets the door step;
  - `main.gd` gets the notices, Go in and Walk here;
  - `core/city_geometry.gd` gets `clear_of_walkable`;
  - every `styles/*` pack is refitted;
  - `tools/collision_audit.gd` and its helpers become `tests/test_collision_audit.gd`, and the door probes become `tests/test_door_entry.gd`.

## 9. How this scales to the vision

| The vision needs | How this model carries it | Built now | Later |
| --- | --- | --- | --- |
| **10 districts and 25 facilities, as rooms joined by portals, one authority per room or plot** (MULTIPLAYER, sub-project 4) | Placements and grids belong to a district, in its own coordinates. Nothing is city-wide except the catalogue. | One district, per-district build | Portals and handoff between district servers |
| **Plots and build mode** (RESIDENCY, `{cell, rotation}` placement) | A placement is a kind at a point with a facing, checked against the kind's snap. A plot is a bounded region with edit rights over it. | `apply_placement` with validation and the input log; CLI and MCP | The in-game build UI, plot bounds, edit rights, undo as a command reversing an accepted change |
| **Rooftops, storeys, stairs and lifts, bridges with clearance below** (ARC-05/06/07, BLD-10, INF-03) | `level` on rooms and placements, with one grid per level. Stairs and lifts become connector kinds joining levels, as doors join rooms. | The field and the per-level grid; level 0 only | Rooftops spec: levels above 0 and connector kinds |
| **A changing world: public works, gardens growing into wings, events** (GM02, READING_GARDEN) | Every change is a placement command, validated, logged and replayed. The grid updates in place, and walkers re-plan. | Commands, incremental update, `grid_changes` | Blueprint approval, scheduled works |
| **Things you can use: sit, read, use a workstation, open, carry** (CHARACTERISTICS capabilities; the SJL integration plan's panels) | A kind declares anchors, capabilities and state, and an instance holds state and an optional binding to an outside record. | The fields, validated; `sit` and `board` as today | The interactions spec: one generic use command, and the first capabilities |
| **Community assets** (F23 asset forge) | A reviewed asset is a new kind in a new catalogue version: data, not code. A style variant that changes a footprint needs a migration check (CHARACTERISTICS). | Versioned catalogue | The review pipeline, and per-plot kits |
| **30 styles on one place model** (CONSISTENCY-CONTRACT) | Every style draws the same things with the same footprints and doors. Styles stay free above and below the band and in ornament. | The six styles, audited | Each new style passes the same audit |
| **Occupancy of 100, 1,000 and 10,000, at 60 fps on desktop and 30 on phones** | The grid is derived once and updated locally. Pathfinding is unchanged. A large city plans room to room first, then within a district's grid. | The 400 m synthetic scale test | Hierarchical routing across districts |

The civic simulation's road and utility networks stay separate graphs, as the docs specify. They are not part of this grid.

## 10. Not in this spec

- What capabilities do beyond `sit` and `board`, instance state changes, and bindings: the interactions spec.
- The in-game build mode, plots, edit rights and undo UI.
- Several districts, portals and the multi-room server (sub-project 4).
- Levels above 0: rooftops is the next follow-on, and it builds on `level`.
- The look of ground outside every room. Lawn and verge that look walkable but are not (8,800–26,000 cells in the audit) need edge treatment such as hedges or kerbs per style. The audit keeps reporting them.
- A navmesh. The grid stays, for determinism.
- Moving obstacles other than vehicles.

## 11. Risks

- **Refitting six packs is the largest part of the work.** Shells move outward, kits are trimmed to footprints, and planting moves into the manifest. Mitigation: the audit test names every offending mesh with its kind and position, so each fix is local, and packs can land one by one behind the gate.
- **Growing shells outward changes the plaza and street edges.** Seats, queue slots and tram platforms near buildings may move. Mitigation: the generator validates through the core, and the scenario gates and invariants run on the regenerated fixture.
- **Steered entry into a full room changes behaviour players know.** It is limited to Steer. Go keeps queueing and overflow, and both paths now say what happened.
- **The trigonometry table and rasterisation must be identical everywhere.** There is only one implementation, in Rust. The client loads its result, and the wasm32 build runs the same tests.
- **Larger door spans change where people may stand without admission.** Queue-slot and admission tests run at the new widths, and the invariants suite runs on every tick of the scenario gates.

## 12. Amendments

### 2026-09-28: decided during the build

The build settled these points, which the sections above leave open or say differently. Where they differ, these hold.

**Scale (§1, success 5).**

- **The 1 ms target is for a change settled locally.** The local proof settles a change when every walkable cell beside it is still joined to the others within 4 m. Such a change updates the grid in 1 ms or less. Some changes need the whole grid compared instead: one beside an entrance, one that takes a room's last cells nearby, or one that seals a pocket. Those complete within the full-build budget of 200 ms. `scale_district` times both kinds.
- **Mending the walking fields may take longer than 1 ms.** The target covers the grid update (`placement::apply`). `World::apply_placement` also mends each room's distance field and the exit field. On the district, a planter standing alone took 0.6–16 ms to mend. One that extended a wall across the plaza took about 70 ms. Placement changes are rare operator commands, and a lazy or amortised mend can remove the hitch later.

**Validation (§3).**

- **`room-too-small` fires only for rooms a footprint shrank.** A room authored smaller than its capacity, with no footprint in it, is not refused for it.
- **Placements outside the grid are valid.** World content on verges and lawns beyond every room carves only the cells that exist. `placement-off-grid` is only an overflow guard, for points more than 10 km from the grid's origin.
- **The disconnect check covers more than rooms.** A change is refused when two rooms, or a room and an entrance, that were joined are no longer joined. It is also refused when the entrances stop reaching a seat, a standing anchor, or a cell someone stands on or is walking to.
- **Lines follow the tram's width.** Tracks must be at least the vehicle's width plus 50 cm apart (300 cm for the tram), so a walker stepped aside always has somewhere to stand. §3 fixes platforms 150 cm from their track. Instead, each platform's edge is measured, and must lie at least the vehicle's half width plus the body clearance (135 cm) from its track.

**Seats.**

- **Seat furniture leaves open the side the sitter comes from:** behind for furniture faced across (`desk`, `cafe-table`), and in front for `bench` and `reading-chair`. The footprint surrounds the sit anchor on the other sides.
- **Seat cells are destinations only.** Paths and walking fields treat a seat cell as a sink: a walk enters one only as its last cell, and a walk that starts on a seat may leave it. A Steer onto any seat cell, taken or not, is refused with `Seat`.
- **Seat furniture always carves the grid** under schema 2.

**The catalogue (§2).**

- **`flowerbed` has a footprint:** its bed, 310 × 110 cm. Every style draws beds into the walking band, and people walk round them. `path` alone stays empty.
- **Trunks are discs of 25 cm radius** for `palm` and `street-tree`. Every style fits its trunks to them; the foliage is above the band. Trees and shrubs stand in no raised beds. A shrub fills its own footprint, and the great tree's roots fill its footprint.
- **Tram shelters are open.** They have no lean rails. The footprint covers only the posts, the back glass and the bench, and leaves the front walkable, so the bench can be used. The `stand` anchor is at (0, 110). The district's shelters stand 50 cm farther from the tracks than before.
- **Only enclosed buildings have a kind.** The guild hall and the library have one. The café terrace is open ground and has none.
- **Benches and café chairs are measured to their whole kits,** so they are drawn at their own size round the sitter, not stretched round the protected square. The `bench` is the 3D kits' 1.6 m bench: its ends from 25 to 80 cm either side of the sitter and its back from 25 to 35 cm behind, the seat running from the square's front edge, so the sitter sits in the middle of its length with the backrest 25–30 cm behind. The `cafe-table` chair is its two sides, 23 to 25 cm either side of the sitter, 21 cm ahead to 26 cm behind: a chair its sitter's own width, open front and back. Packs fit each kit to its footprint, within a few centimetres; the voxel bench is trimmed from 1.8 m.

**The fixture (§5).**

- **Tree rows are `palm` placements.** `street-tree` is each style's round lawn tree.
- **Planting placements may stand on walkable ground rooms** (lawns, the park, the garden, verges) and block their footprints. §7's rule for extras, clear of every walkable cell, applies only to pack-only extras.
- **Street lamps face the street they light.**
- **Block lots are filled in every style.** A block's buildings fill its lot in the walking band. Where a style's houses are smaller than the lot, a garden wall encloses the rest, with a closed gate facing its street. Blocks are not entered.
- **The ring's benches** round the great tree face along 36° steps. They are placed by rule within 15 cm of their ring points, where the grid agrees with their outline in every style.

**The audit (§1, success 1; §7).**

- **A seat's own furniture is exempt inside its protected square.** The square reaches 25 cm either way of the seat point and turns with the seat. There, the seat's own furniture counts for neither the through gate nor the 10 cm gate, so chairs are drawn whole. Every other solid counts at seat cells as anywhere.
- **Fills may reach past a footprint's edge** by up to 2.5 cm beyond the last blocked cell centre, which is at most 12.5 cm past the edge. The grid blocks those cells anyway. §7's "inside its footprint" reads "within the cells the grid blocks for its footprint".
- **Low steps and plinths count as ground.** A surface whose riser is 25 cm or less, such as a sidewalk, quay, platform or plinth, is the ground stood on, and the walking band is measured from it.
- **Untagged geometry is an offender only when it is solid in the walking band.** Occupants and vehicles are not offenders; the tram gate checks vehicles.

**Doors and full rooms (§6).**

- **Steered entries are refused with `RoomFull`,** on the step from outside into the room: onto its span, or, for an open-air room that joins along any edge, over that edge. That happens when the room is full, and also when others are on its waitlist, so a steered player never jumps the queue.
- **A steered player is admitted on the step** onto an open room's span. A same-tick arrival can then never waitlist or overflow them.
- **The client raises the Full notice itself** when its prediction refuses the step, since the core never sees a step the prediction refused. It does so whenever a step the walk prefers to the one it takes, or the step through a doorway, is refused only because the room is closed, so a 45° approach to a full room's door says so rather than sliding silently.
- **The jamb guide.** A steered walk pushed straight into a wall, with a doorway one cell to the side, side-steps in front of the doorway, never back. A step onto a door's threshold from which walking straight on crosses through ranks before a slide along the wall.
- **The door-entry test starts each walk from a clear run-up.** The spike's remaining misses at 35° or less started boxed in by the commons desk; they were not steering failures.

**Contracts and tools (§4, §8).**

- **`MANIFEST_SCHEMA_VERSION` is 2.** It is separate from `SCHEMA_VERSION`, which stays 1 for feeds, snapshots, projections and reports. A schema-2 manifest must name its `catalogue`.
- **The commands are `Place`, `MovePlacement` and `RemovePlacement`,** since `Command::Move` already moves an occupant. Each carries an optional `by`. A command with `by`, sent from a player's session, is refused with `NotOperator`. The other new refusals are `UnknownPlacement`, `PlacementInvalid { code, place }`, `PlacementCoversOccupant` and `PlacementDisconnects`.
- **`city-cli place --write` writes the manifest in canonical form:** fields in contract order, re-serialised from the `Manifest` type. A hand-edited manifest therefore shows a reformatting diff. Manifests are generated by `generate.py`, and serde_json's `preserve_order` stays off, because it would reorder every `serde_json::Value` in the CLI's build and risk the byte-identical event logs.
