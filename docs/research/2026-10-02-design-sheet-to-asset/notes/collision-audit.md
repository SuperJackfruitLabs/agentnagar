# What the game's collision audit holds a piece to

Written by Claude (an AI), 2026-10-02. Every statement is from the game's code as it stands in the checkout (`city/`), from running its audit on the working copy, or from `work/audit_cells.gd`, which asks the audit itself. File and line references are to `city/godot/` unless they say otherwise.

## Why this note exists

The first 23 pieces (seats and great trees in five styles) were checked against the kits' specs and one of the game's rules, the footprint squeeze. The game's own test suite was not run on them. When it was, 17 counts of its collision audit failed in every style, and the kits' own pieces passed at zero in the same working copy. A piece can keep its kit's size, parts and seat height and still be the wrong shape for the walking grid.

## The audit

`tools/collision_audit/audit.gd` boots the client on the district fixture in one style, reads every solid the style draws between 0.25 and 1.9 m above the ground it stands on (`BAND`, line 52), and sets them against the core's walkable grid of 25 cm cells (`crates/city-core/src/nav.rs:21`). It counts six things; the game's test (`tests/test_collision_audit.gd`) holds each to the number in `evidence/placement-budget.json`, which is zero for every style.

| Count | What it is |
| --- | --- |
| `through` | walkable cells whose centre lies in a drawn solid |
| `within_10cm` | walkable cells whose centre a solid comes within 10 cm of (the body clearance) |
| `walker_pass`, `player_pass` | visits to `through` cells over a recorded day |
| `tram_overlap` | walkers inside a drawn tram |
| `reverse_blocked` | cells inside a room that the grid blocks although nothing solid is drawn within 10 cm of them |

A solid is what a piece's triangles cut to the band enclose, seen from above (`tools/collision_audit/solid.gd`): what the faces close in counts as inside.

## Which cells a piece blocks

The core blocks a cell when its centre lies inside one of the kind's footprint shapes grown by 10 cm on every side, in the shape's own frame (`crates/city-core/src/footprint.rs:12`, `:425-446`; rectangles include their lower edges and exclude their upper ones). A seat's own cell stays walkable (`nav.rs`, test `seat_furniture_carves_its_kinds_footprint`). The footprints are in `city/catalogue/catalogue.json`, in centimetres about the piece's point, +z towards a seat's back:

| Kind | Footprint |
| --- | --- |
| `bench` | two rectangles 55 by 60 either side of the sitter (x -80 to -25 and 25 to 80, z -25 to 35) and a strip behind the sitter (x -25 to 25, z 25 to 35) |
| `reading-chair` | two arms (x -45 to -25 and 25 to 45, z -40 to 50) and a back (x -25 to 25, z 25 to 50) |
| `cafe-table` (the chair at a table) | two strips 2 cm wide at x -25 and 23, z -21 to 26 |
| `great-tree` | one rectangle, 520 by 510 |

So a bench's footprint with the sitter's square is a full rectangle, and a reading chair's is a U: the strip in front of the seat, between the arms, is floor.

## What the audit lets a seat do

A seat's own furniture is exempt from `through` and `within_10cm` at the cells whose centres lie within its protected square, 25 cm either way of its point (`audit.gd:20-29`, `SEAT_SQUARE`). Everything it draws outside that square has to fit its footprint.

## How the game draws a seat

`styles/pack_3d.gd:719-734` (`_fill_footprint`) stretches the piece so that the box of what it draws between 0.15 and 2.2 m (`kit_town.gd` `band_box`) fills the bounds of the footprint, merged with the protected square. It fits the box, not the shape. For a facing that is a multiple of 90 degrees the target rectangle is first grown to 2.5 cm past the centres of the cells the grid blocks (`core/city_geometry.gd:186-197`, `drawn_rect`); for any other facing it is the footprint's bounds as they are.

Two things follow.

- The band the fill measures (0.15 to 2.2 m) is wider than the band the audit reads (0.25 to 1.9 m). A foot that splays out below 0.25 m sets the box and leaves the body drawn that much inside it.
- The shape inside the box is the piece's own. The kits' pieces are drawn to the footprints' shapes: the kits' reading chairs have arms that reach 12 to 20 cm further forward than the seat between them, and the kits' benches are full rectangles from above, their backs on the rear edge along the whole length.

## What the first pieces got wrong

Measured with `work/audit_cells.gd` (each placement's cells in its own frame, with what the audit counted) and drawn by `work/audit_kind.py` (`previews/audit-first-seats.jpg`: a low-poly reading chair and two benches as first built, red a walkable cell touched, blue a blocked cell left bare; `previews/audit-reading-chair-kit-and-first.jpg`: in each style the kit's reading chair, the chair as first built, and the kit's bench with all its placements laid over one another):

- **Reading chair, all five styles.** The generated armchairs have a seat cushion flush with the arms' fronts. Filled to the box it stood on the two walkable cells in front of the sitter (centres 12.5 cm either side of the middle, 37.5 cm in front of the point): 16 cells `through` in four styles, 16 `within_10cm` in all five.
- **Bench, four styles.** The back rest did not stand on the box's rear edge along its length: back legs splayed 6.5 cm behind it (low-poly), side frames ran 3 cm behind it (anime), the back was shorter than the frames it stands between (solarpunk), or the arms were only at the front (voxel). The cells the grid blocks behind the bench, whose centres lie up to 10 cm beyond the footprint, then had nothing within 10 cm: 4 to 15 cells `reverse_blocked`, at the benches that stand at an angle round the tree.
- **Voxel great tree.** Its bed's upper layer of cubes was missing along its edges, so between 0.25 and 0.5 m nothing was drawn there: 112 cells.

## What the fit does about it

On the generated model, before it is cut down (`fit_generated.py`, "The piece from above"); the piece is then put back on the kit's box:

- `--plan-pull SIDES`: on a side, whatever stands out past the side's main edge (the middle value of how far the piece reaches along that side, in the audit's band) is pressed onto it. Splayed legs and long frames no longer set the box.
- `--plan-cols`: strips that stop short of the piece's depth are drawn out to it (the solarpunk bench's side frames, to the rear face of its back).
- `--plan-rows`: rows narrower than the piece are drawn out to its width (the voxel bench's rear half).
- `--plan-notch HALF,SHARE`: an armchair's seat is pressed back between its arms until it stands SHARE of the depth behind the arms' fronts (0.16; 0.23 before a rebuild in 10 cm cubes, which needs two whole cubes). The arms' inner faces are read off the model above the seat. The change from moving to still is put in the first centimetre of the arm, so the faces bared along the arm's inner side are the arm's own timber, and they are given the arm's colour.
- `voxelise.py --solid H`: below H the piece's foot is a solid block of cubes (a bed, to its rim).

With these the five styles pass the audit at zero with all 23 pieces in place, and the game's own collision, style-pack, planting and frame-cost tests pass (106 of 106).

## How to check a new piece

`work/audit.sh STYLE` runs the game's audit on the working copy as it stands, in about 12 seconds a style, and lists the offenders by piece. `run_all.sh` runs it with the kit's pieces and with the new ones. When a count is not zero:

```sh
godot --headless --path game/city/godot --script work/audit_cells.gd -- STYLE out.json KIND[,KIND]
venv/bin/python work/audit_kind.py out.json picture.png KIND     # every placement of the kind, laid over one another
venv/bin/python work/audit_plot.py out.json picture.png ID       # one placement
```

The pictures show, in the piece's own frame, what it draws in the band and each cell's centre: blocked and bare (blue), walkable and touched (red).

## What a file alone cannot show

The four build agents each wrote a check that follows the audit's code on the built file (`terrace_rules.py`, `fixture_rules.py`, `planting_rules.py`, `piece_rules.py`). They are useful while fitting, and all 54 of their pieces (15 of the terrace, 10 fountains and shelters, 15 street fixtures, 14 of the low planting) then passed the game's own audit when placed. They do not replace it: the audit reads the ground drawn under each placement, the placements' real facings and the grid's phase at each point.
