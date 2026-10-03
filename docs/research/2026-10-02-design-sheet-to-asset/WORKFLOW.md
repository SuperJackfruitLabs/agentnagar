# From a design sheet to a piece in the game

The steps for one more piece, as they were run on 2026-10-02 for the seats, the great tree and the tree square's props in five styles. Written by Claude (an AI). The report is `README.md`; this file is the how.

Everything runs from a working folder made by `tools/setup.sh` (the checkout is not written to). In that folder the tools are in `work/`, and `AGENTNAGAR` names the checkout.

## Before you start

- The piece has a design sheet in `docs/vision/asset-studies/sheets/<style>/<item>/r001/image.png`: the object whole, on the plain grey backdrop, lit neutrally. A night scene will not do (see the traps).
- You know the kit file it replaces (`city/godot/styles/<style>/assets/<file>.glb`; the voxel kit keeps its own under `assets/v2/` with other names) and that the kit has a spec for it (`city/tools/styles/<kit>/specs/*.json`: size, triangle limit, named parts).
- You know what the game does with that piece beyond drawing it. This decides more than the spec does. Read the code before fitting, or read the note for the nearest kind in `notes/contracts/`:
  - **Does it block the walking grid?** Then its catalogue footprint (`city/catalogue/catalogue.json`) has a shape, and the piece must have that shape seen from above (`notes/collision-audit.md`).
  - **Does the game stretch it to its footprint?** It stretches the box of what the piece draws between 0.15 and 2.2 m up; anything drawn outside the footprint in that band shrinks the whole piece.
  - **Do people sit on it, or at it?** Seat tops, knee room and sit anchors are fixed by the game, not by the piece.
  - **Is it planted by the hundred?** Then only the file's first mesh is drawn, and the rules under "Planted pieces" hold.
  - **Does it light up?** Lamps go by material and part names (below).

## Steps

1. **List it.** Add the sheet to `sheets` in `work/assets.json` (with `cells`, columns by rows, if the sheet is a grid) and the piece to `assets`:

   ```json
   "bench": {"sheet": "A-seating", "obj": 0, "file": "assets/seat_bench_v2.glb", "needle": "seat_bench_v2", "max_tris": 6000, "tex": 1024,
             "flags": ["--seat", "--plan-pull", "all", "--plan-rows", "--own-normals", "--weighted-normals"],
             "style": {"voxel": {"file": "assets/v2/bench.glb", "needle": "=bench.glb", "mesh": "seat"}}}
   ```

   `obj` is the object's number on the sheet (step 2 shows them). `needle` is the text the capture tool finds the piece by in its scene file's name; write `=` before it when it must be the whole name (`=bench.glb`, or the voxel kit's `workbench.glb` is taken too). `flags` are the fitting options (below). `style.<style>` holds what differs in one style: another file and other names, its own flags (they come before the piece's, and the first occurrence of an option wins), `"flags_replace": true` where the style's piece goes another way altogether, `"file": null` where the style's kit has no such piece. `only` lists the styles a piece is built for. A size the piece keeps from its sheet against the kit's spec is declared with its reason (`departs`, `size_as_drawn`), and `check.py` then reports it instead of failing it. `sets` names groups of pieces (`@first`, `@props`, `@trees`).

2. **Cut.** `python3 work/build.py cut <style> [<sheet>]` writes `crops/<style>/<sheet>/obj-<k>.png`, `obj-<k>-clean.png`, `obj-<k>-matte.png` and `found.png`, which outlines what it found. Look at `found.png`: each object should be boxed once, in green, and each swatch in magenta. The clean crop has the swatches and the neighbours painted out; a piece with `"crop": "clean"` is generated from it. The matte is a cut-out with its own transparency, for an object with grey glass in it (`"crop": "matte"`).

3. **Generate.** `python3 work/build.py gen <style> <piece>` runs the image-to-3D model: `raw/<style>/<piece>.glb`, one to eight minutes, longer when anything else is using the graphics card. Look at it before going on: `blender --background --python work/look.py -- raw/<style>/<piece>.glb previews/<piece>.png` renders it from five places in its own colours (`--lit` shades it, which is what shows a crumpled surface). `work/gen_queue.sh <batch>` does this for a whole batch of sheets as they arrive, one object at a time. A model that came out wrong (falling water as dark slabs, a crown as a hollow ring) is worth one more seed before any rule is written for it.

4. **Fit.** `python3 work/build.py fit <style> <piece>` writes `out/<style>/<file>.glb` and a report beside it. The line it prints says how many triangles it kept, how far the piece stands off the generated model, and how far its colours are from the design. In the voxel style the fitted piece goes to `out-mid/` and `voxelise.py` rebuilds it from cubes into `out/`.

5. **Check.** `python3 work/check.py` (with the game's development environment loaded) holds every built piece to its kit's spec for size and named parts, to the rules of its kind where there are any (`rules`, `piece_rules`, `contract` or `planted` in its entry), and reports the kit's triangle limit. For the seats, `blender --background --python work/seat_top.py -- $(python3 work/build.py seats <style>)` prints each kit seat's top and each new one's; they should agree.

6. **Put it in the game and run the game's audit.** `python3 work/build.py place <style> <piece>` puts the piece in the working copy; `work/audit.sh <style>` runs the game's collision audit on the copy as it stands, in under half a minute, and lists the offenders by piece. It measures the three counts that need no simulated day (through, within 10 cm, blocked and bare), and all three must be zero; the other three (walkers, the player and the tram passing pieces) need a day of the game, which its own test of the audit simulates (`work/game_tests.sh collision`, a few minutes). When a count is not zero:

   ```sh
   godot --headless --path game/city/godot --script work/audit_cells.gd -- <style> out.json <kind>[,<kind>]
   venv/bin/python work/audit_kind.py out.json picture.png <kind>     # every placement of the kind, laid over one another
   ```

   The picture shows, in the piece's own frame, what it draws in the band and each cell's centre: blocked and bare (blue), walkable and touched (red).

7. **See it.** `python3 work/build.py try <style> today` captures the kit's pieces (all of them in one start of the game); `try <style> new` captures the new ones. `venv/bin/python work/compare.py <style> previews/compare.png <piece>` sets design, today and new side by side (`--clear` passes over a placement that is hidden in either capture, `--show PIECE=eye-2,above-0` picks one by hand). `work/props_run.sh <style>` does steps 6 and 7 for every prop on top of the first set, with the town's standard views before and after; `work/three_ways.py` lays those side by side. `python3 work/build.py restore <style> <piece>` puts the kit's piece back. `work/run_game.sh <style>` opens the copy. Look at the piece in the game before believing a render: the anime toon step, the neon night and the game's stretch all change it.

8. **Run the game's own tests.** `work/game_tests.sh` runs the whole suite on the working copy (about a quarter of an hour on this laptop); `work/game_tests.sh collision pack plant frame_cost` runs only the tests that read the pieces, in a few minutes.

9. **Cost.** `work/bench_pairs.sh` runs the game's frame-time bench one style at a time: first with the kit's pieces until the graphics card stops warming, then kit, new, new, kit. `PIECES=@trees` makes "new" one family alone. `work/bench_far_swap.sh` switches on the game's own far swap for a style's trees and palms (their twins placed beside them by `far_swap.py`, and taken out again with their import files afterwards), and `work/bench_far_as_near.sh` draws them as their twins at every distance; the second changes triangles, vertices and texture size at once, so it shows only that the full files cost. The bench wants the card and the processor to itself: stop the generator queue first (`touch scratch/gen.pause`), run no agent and render nothing else meanwhile. The two runs of a pair should agree within about a tenth of a millisecond; if they do not, the machine was not quiet or the card was still warming, and a run that logs an error is not a measurement.

`work/run_all.sh` does steps 2 to 7 for the first set (`PIECES`, `STYLES`, `STEPS` narrow it), `work/props_run.sh` and `work/sheets_all.sh` do steps 6 and 7 for the props, and `python3 work/report_tables.py` writes the report's tables from the result files (`--fill README.md` writes them into the report; `--check README.md` says whether a report still agrees with them).

Before a piece is called done, three more things, each one command:

- `node work/validate.cjs out/*/*.glb` runs the kits' pinned glTF validator (installed once into `scratch/validator/` with `npm ci` from the checkout's `prototypes/voxel-work-bay/tools/package*.json`); the kit tests fail a file on any error or warning. `build.py fit` mends the zero tangents the exporter writes (`mend_tangents.py`), and the fit cuts faces of five corners or more into triangles so that tangents are written at all.
- `work/replay.sh /some/empty/dir` builds every piece again from the generator's output in an empty folder and compares the files byte for byte with the ones kept (twelve minutes for the 179 files of this record, the five styles side by side, on a machine doing nothing else). Run it after any change to a tool that other pieces share. `STYLES=neon_noir work/replay.sh DIR` rebuilds one style, one fit at a time (see trap 29).
- `venv/bin/python work/check_docs.py RECORD` holds a record's pages to the options, scripts and files they name.

## Triangles

The triangle count is the shape's to decide (the owner's decision, 2026-10-02). A seat takes the fewest of 1,500, 2,000, 3,000, 4,000 and 6,000 that keep 95% of the generated surface within 0.16% of the piece's size and all of it within 0.8%; a tall thin piece is given the two distances in millimetres instead (`--within`), because a share of 4 m lets a finial crumple. A tree takes the counts given part by part (`--parts`). The kits' limits are reported against. Three kinds of piece are held near their limits all the same, because the game draws many of each: the perch seat, the railing panel and its post (my choice, not the owner's). For the planted pieces I propose the measured frame time as the gate; their counts are an open decision. To build a piece inside its kit's limit as well, give it a `budget` for the style and run `fit <style> --budget`: the result goes to `out-budget/`.

## Fitting options that mattered

`fit_generated.py` documents all of them at its top (and `check_options.py` holds that list to the options the code reads). The ones a new piece is likely to need, set per piece or per style in `assets.json`:

| Need | Option |
| --- | --- |
| A seat whose sitter must not float or sink | `--seat` (the seat's top goes to the kit's height) |
| A bench whose back must stand on its rear edge, legs that splay past the box | `--plan-pull SIDES` (what stands out past a side's main edge is pressed onto it), `--plan-cols`, `--plan-rows` |
| An armchair whose footprint is a U | `--plan-notch HALF,SHARE` (the seat pressed back between its arms) |
| Boards that shade as if dished | `--own-normals --weighted-normals` |
| Triangles spent inside the piece | `--remesh M` then `--drop-hidden`, for a piece cut from the generated model; not for one cut from a rebuilt surface |
| Blotches or specks where a material has two tones | `--materials N`, with N the number of swatches the sheet shows under the object; `"materials": "swatches"` counts them for you |
| A top on a stem on a foot (table, umbrella) | `--stem`: the top scaled evenly, the stem alone stretched; `--stem-edge`, `--stem-foot`, `--stem-across` |
| A planting box | `--planter W,D,RIM` with `--planter-parts`: the box plain, the plants cut on their own |
| A planting bed | `--bed KERB[,OVERHANG]`: sized by its kerb, the kerb a plain box, the plants cut on their own |
| A shrub | `--shrub R --skin N`: a closed skin drawn over the generated ball, its widest ring on the kit's reach; `--leaves N,LENGTH,WIDTH` makes the skin a dark inside and sets leaves on it, `--flowers M,SIZE,#HEX` its flowers |
| A lamp post | `--axis --aspect-by height`, `--glow-part light`: its own axis on the origin, the glass a part of its own |
| A railing | `--panel`, `--panel-post FILE`: far post cut off, ends closed, set from -1 to +1, the post as a second file |
| A shelter | `--shelter`: sized zone by zone, the bench cut free and set to the footprint's |
| A fountain | `--fountain`, `--water`: wall and rim a ring built by rule, the water told by colour and made a part of its own |
| A tree in a bed, sized part by part | `--tree W,D,BED,CROWN,HEIGHT`, `--parts WOOD,LANTERNS,LEAVES[,BED]` |
| A crown that is a ring of leaf seen from above | `--crown-fill SHARE,TURN[,SHARE,TURN]`, `--core S`, `core_plan` |
| A style that draws an ink line at every crease (anime) | `--leaf-smooth`, `--no-normal` |
| Leaves that come out dark in the game (anime, neon, solarpunk) | `--leaf-round 0.85 --leaf-lift 1.0`: leaf normals lean up, as those kits' own do. Keep such a leaf matt (`"rough": 0.85` in the piece's entry for a style built glossier): at 0.6 the lifted tops took neon's night light as a pale sheen |
| A flowering tree | `"blossoms": 2` in its entry: the sheet's blossom swatches go to `--leaf-blossoms`, and each flower is drawn two texels wider |
| Leaves too dark or the wrong green | `leaf_ramp: "swatches"` (the sheet's leaf swatches, dark to light), or a list of colours (the kit's greens) |
| The reduction stalls or wrecks thin parts | nothing: a piece whose reduction stalls is rebuilt from small cells and cut again. `--remesh M` forces it, with `--inflate M` for a thin shell |
| Lanterns and lamps that should glow | `--glow NAME --glow-warm`; `--glow-part NAME` makes them a part of their own; `--glow-part-least N` keeps stray glowing faces out of it |
| A lit strip the generator did not paint | `--under-glow Z0,Z1,INSET`, `--band-glow Z0,Z1[,OUT]`, or carry the kit's (`kit_lights`) |
| Flat faces (low-poly) | `--flat` |
| A style built from cubes | `"voxel": {"grid": 0.1}`: the fitted piece is rebuilt from cubes. `"solid": H` for a bed, `"light": NODE` for a lamp's glass, `"upper": G` and `"jumble": F` for a great tree's crown, `"trunk": "N,F"` for a street tree, `"sheets": F` for panes and panels thinner than half a cube, `"hollows": true` for bowls and tiers; and in `"flags"` the cube step's own options: `--symmetric`, `--column`, `--round`, `--sectors` (a table, an umbrella), `--heap` (a planter), `--drum` (a shrub), `--tones` with `--tone-cubes` (flat swatch greens) |

## Planted pieces

Street trees, palms, shrubs, railings and meadow clumps are drawn as copies of the file's first mesh; nothing else in the file is looked at (`notes/contracts/trees.md`, `low-planting.md`).

- **A tree or palm** (`"planted": true`, `--planted CROWN,HEIGHT` with `--parts`): one mesh, two materials named `trunk` and `leaf` (`planted_three_ways.sh` sets the kit's trees, the new ones in the sheet's greens and in the kit's greens side by side). The game scales each copy's width by 0.25 m over the trunk's reach, so the trunk is set upright over the origin, slimmed to that reach, and nothing but trunk stands between 0.15 and 2.2 m (`--planted-clear M` raises a low fork). `--far N` writes the far twin, which the game draws beyond 90 m wherever its file sits beside the piece: `build.py place` puts it there only where the kit has twins of its own (neon, anime, solarpunk), and `far_swap.py STYLE` in any style. `--planted-leaf-from 0.5` takes out leaf lying at the foot (a patch of drawn ground the leaf rules took for leaf). `planted_rules.py` checks all of it.
- **A voxel tree** is not built that way. Its design is a cube tree already: it takes a plain fit to the kit's box with many triangles (`"flags_replace": true`, `"tris": 40000`), and the cube step builds the crown in the kit's large cubes, one flat swatch green each, and the trunk as the kit's own column (`"voxel": {"trunk": "4,0.5", "upper": 0.5, "upper_solid": true}`).
- **A shrub** is scaled by its reach about its origin in the same way; its widest ring must be a whole circle, 0.40 m up or higher.
- The capture tool does not find planted copies as scene instances; `asset_views.gd` finds them through the pack's planting chunks.

## Material and part names the game acts on

`lamp_glow` (lit at night, dim by day), `window_glow`, `fairy_glow` (lit at night; the solarpunk test wants it on the great tree). A mesh part named `light` gets a lamp at its middle; a part named `lights` gets one at its origin, for the pieces a style lists under `glow_lights`. A material whose name begins `glass` or `neon` is lit by name. Names beginning street, path, road, kerb, paving or asphalt turn wet in rain: do not use them on a piece. Leaf is told from trunk by a material name containing leaf, leaves, foliage or frond. Two materials given one name come out as `name` and `name.001`, and the game does not know the second.

## Building a family with a parallel agent

What worked for the third batch, in order:

1. Have the game's contract for the family read out of the code first, by an agent that changes nothing, into a note with file and line references.
2. Give a build agent the note, a copy of `work/` (and an untouched copy beside it to compare against), the generated models, and a folder of its own. Tell it what it may not run (the game, the generator) and that every change to the tools must sit behind an option of its own.
3. Ask it for a check that reads a built file, a preview sheet a piece, a report, and a byte-for-byte rebuild of an existing piece as proof that nothing else changed.
4. Merge one fork at a time. Merge `assets.json` as data, not as text. Prove each merge by rebuilding the agent's pieces and comparing bytes. Better, hand the agent a snapshot of the merged tools and have it merge its own fork onto it.
5. Place its pieces, run the game's audit, capture them, and send what the game shows back to it.

An agent took one and a half to three hours for a family of three pieces in up to five styles.

## Traps, each met once

1. **Metal.** The generator's metal map makes the colour bake dark or black, most of all for night images. The fit ignores it; if a texture comes out dark, check the report says `metal_map_ignored`.
2. **The footprint band.** Anything a filled piece draws between 0.15 and 2.2 m up and outside its footprint makes the game shrink the whole piece. That includes an edge that only crosses 2.2 m out there on its way up, and a bed swollen a few centimetres by the rebuild. `check.py` fails a piece that reaches more than 1.1 cm out.
3. **The footprint's shape.** The game fits a piece's box, and the grid blocks its footprint's shape. A seat cushion flush with the arms' fronts stands on two walkable cells; a back that stops short of the frames leaves blocked cells bare. Run the audit (step 6).
4. **The audit's band is not the fill's band.** The fill measures 0.15 to 2.2 m and the audit reads 0.25 to 1.9 m above the ground drawn under the piece. A foot that splays below 0.25 m sets the box and leaves the body drawn inside it.
5. **A face exactly on a footprint's edge** measures 10.0 cm from the next walkable cell, where 10 is the limit. Leave a centimetre or two.
6. **Stalled reduction.** A generated mesh has edges shared by three faces, and Blender's reduction stops on them. The fit notices and cuts again from a rebuilt surface. That rebuild destroys a thin shell (an umbrella's canopy came back as ribs with rags of cloth): swell it first (`--inflate`).
7. **A limit against shape.** Thin legs become spikes when cut too far, and a tree cut as one mesh loses its trunk and lanterns before its leaves (use `--parts`). A planter of plants held to a railing's 1,000 triangles breaks up.
8. **Blotches.** Lifting a flat dark texture amplifies its grain. The match treats materials within three lightness steps of each other as one; if blotches return, raise `flatten`, or match fewer colours (a table top matched to two came out clean where five gave brown patches).
9. **The cached import.** The engine keeps its import of a piece beside the project. `build.py place` and `restore` delete it. A capture showing magenta means a piece failed to load.
10. **Frame sizes.** The hidden desktop decides the capture's size. Today's and the new captures must be taken at the same size or the comparison crops do not line up.
11. **What else is in the crop.** The generator turns the swatches under an object into slabs and the edge of a neighbour into a lump. Generate from the clean crop. The cutter can take two objects standing close for one (`design_object`, `--object shortest` keep one of them), and it clears grey glass with the grey backdrop (use the matte).
12. **Invented ground.** A model can come standing on a slab of one piece with it (`--drop-plate`).
13. **Seat heights.** The game seats a figure at one height whatever the piece: use `--seat`.
14. **The kit's light strip.** Carried across at the kit's coordinates it can end up on top of the new seat or inside it. Look at the piece from the front.
15. **A measure can mislead.** "Colour off the design" is taken on the finished texture, each design colour against the texels nearest it, so read it with "design colours found". Matched to two colours, it is met by construction and says nothing.
16. **The design's light is in the texture.** Lit tops and shaded sides are baked in, and the game lights the piece again. For cubes and facets, give each one flat colour of the sheet's swatches by rank (`voxelise.py --tones` for cubes, `fit_generated.py --tones-by-rank` for facets).
17. **Do not edit the tools while a run is going.** A run reads them as it goes. Replace a tool in one step (write beside it, then rename), and keep a script's executable bit when you do.
18. **A piece that looks the same from two sides.** The turn is chosen by how well the turned model fills the kit's box; a plain block scores alike at two turns. Among turns within half a percent of the best the fit takes the one that stretches the piece least.
19. **Leaves, wood and lanterns are told apart by colour, and colour misleads.** Sunlit leaves at the top of a crown are as warm and bright as a lantern; a violet blossom swatch was taken for bark; a low-poly banner is as yellow as a lamp; brass passes for glass. Each rule that reads colour needs a place as well (`--glow-from Z`, lanterns only in the lower half of a crown).
20. **An unlit preview hides a bad surface**, and Blender's default studio light darkens a pale colour by a third. Look at a new piece shaded and unlit both.
21. **Cubes.** A member thinner than a cube covers no cell by half and vanishes; the cube step gives it the one cell that holds most of it. A piece an odd number of cubes wide needs the grid set half a cube off. A crown rebuilt at one small cube size is a smooth ball. A fitted file's faces do not share their corners, so an open tube in it cannot be closed until they are joined.
22. **Names inside names.** The capture finds a piece by text in its file's name, and `bench.glb` is in `workbench.glb`.
23. **A warm graphics card.** A frame-time bench over five styles in one go left the card at 79 to 82 degrees after its runs, and its later runs were up to four times slower than its first. Cooling the card before each style measured the warming and nothing else. Run each style until the card is steady, then kit, new, new, kit, with nothing else rendering.
24. **A build held to a limit must drop what adds triangles.** The crown fill copies leaf masses; left on, it took a tree held to 7,500 triangles to 9,161.
25. **Unordered sets.** A fit that walks a Python set gives the same piece in a different byte order each run, and so does a mesh operation that makes its faces in a different order from run to run (Blender's edge extrusion did, on a fountain's skirt). A merge can then not be proved by comparing bytes.
26. **A check written from the audit's code is not the audit.** It cannot see the ground drawn under a placement, the real facings or the grid's phase. Use it while fitting; run the audit before believing it.
27. **A long background job is stopped after two hours**, and a clock in one's head runs ahead of the real one: read `date`.
28. **A capture can miss its piece or hide it.** The capture tool passes over a planted copy that fills too little of the frame from every side, to skip the ones behind buildings; at a fiftieth of the frame it passed over every one of the kits' palms, which are a thin trunk under a few fronds and fill about a hundredth in plain view (the limit is now a 250th). And a new piece can stand in front of another's camera: a new street tree's crown hid a shrub from above, a palm's frond a street tree. Look at every frame of a comparison sheet before it is shown (`compare.py --clear`, `--show`).
29. **Five fits side by side need about 12 GB of memory.** Run that way while a game capture, 5 GB of scratch files in a `/tmp` held in memory and the owner's own programs were also on the laptop (31 GB), the rebuild exhausted memory: nothing moved for an hour and the kernel killed a browser process. One heavy process at a time on a machine that is in use, and look at the free memory first. A job that has made no progress for minutes is not slow, it is stuck.
