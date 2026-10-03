# Bringing an asset toward its concept sheet: the workflow

Written on 2026-10-01 from the banyan pilot ([round 1](banyan/README.md), [round 2](banyan/round2/README.md)) and revised on 2026-10-02 after testing it on a second asset, the [park bench](bench-test/README.md), and timing a third, the [planter](planter-benchmark/README.md). It records the steps in the order that worked, so they can be repeated on another asset. Paths are from this folder; [README.md](README.md) is the pilot's report.

**Status.** Proven on three assets, each in six style packs: the great tree (one piece, mostly leaves, standing at one facing), the park bench (a prop of flat faces in two materials, eighteen copies at several facings) and the planter (a box with plants, eleven copies, in three styles the kit's own piece repainted). The steps and the measuring are general and are driven by one config file an asset. The builders are written per asset. The later sections say what changes by style and by kind of asset, and list the traps met so far. The scripts (`tools/`) are pilot code, kept as a record: they are not part of the project's tooling, and nothing they build is in the style packs. They rebuild every tree, bench and planter byte for byte from these folders and replay the capture-and-measure loop unattended from a clean working folder (checked on 2026-10-02).

## What you need

- An Agentnagar checkout with the built extension (`city/godot/bin/`, from `city/scripts/build-godot.sh`) and two untracked local files that the scripts read: `.local/dev-env.sh`, a shell file that puts Godot 4.6.3 on the path as `godot` and points fontconfig at the monospace font CI uses, and `.local/venv`, a Python 3.12 environment with Pillow 10.2 and numpy (the versions CI pins).
- Blender 5.2 as `blender`, `uv`, `rsync`, KDE's `kwin_wayland` (for windowless captures).
- For generating shapes only: trellis.cpp's `trellis-cli` and its weights (`banyan/README.md`).

## The steps

### 0. Make a working folder

```sh
export AGENTNAGAR=/path/to/agentnagar          # the checkout; every script reads it
tools/setup.sh --bare /path/to/work [ASSET_DIR ...]
cd /path/to/work
```

It holds the scripts, a copy of the client (`city/`) that assets are swapped into so the checkout is never touched, a Python environment for measuring (`cvenv/`) and every concept-sheet panel the game has a matching view for (`panels/<style>-<view>.png`). An ASSET_DIR (an earlier asset's folder, such as `bench-test/bench`) is copied in. Without `--bare` the banyan's data comes too. Everything below runs from it.

### 1. Fix the target and write the asset's config

Find the asset in a panel of each style's sheet. Enlarge it with a grid labelled in fractions of the whole panel, and read boxes off it:

```sh
cvenv/bin/python grid.py panels/lowpoly_tropical-park.png previews/grid.png 1100 0.80,0.74,1.0,1.0 0.02
```

Then write `myasset/asset.json`. The bench's is the model (`bench-test/bench/asset.json`):

```json
{
 "asset": "bench",
 "panel": "park",
 "kinds": ["timber", "frame"],
 "stops": {"timber": 5, "frame": 3},
 "sheet_rule": {"timber": "warm", "frame": "any"},
 "unmarked": {"timber": "warm"},
 "footprint": [-0.8, -0.25, 0.8, 0.35],
 "fit": {"stops": false},
 "styles": {
  "lowpoly_tropical": {
   "needle": "seat_bench_v2", "asset_file": "assets/seat_bench_v2.glb",
   "build": ["blender", "--background", "--factory-startup", "--python-exit-code", "1", "--python", "{asset}/build_bench.py", "--", "lowpoly", "{out}", "{params}"],
   "look": [0.825, 0.755, 0.985, 1.0],
   "sheet": {"timber": [[0.85, 0.85, 0.895, 0.90], [0.875, 0.90, 0.925, 0.96]], "frame": [[0.962, 0.88, 0.976, 0.95]]}
  }
 }
}
```

- `kinds`: the materials that get a ramp of their own; `stops`: five tone bands for a material with plenty of pixels, three for a small one.
- `sheet`: boxes in the panel that lie on each kind. Use several small ones wholly on the material, on its body and not on its lit edges (the painting gives every stop of a ramp a share of the faces, so a box on a highlight makes the whole material light). `sheet_rule` drops stray pixels inside a box: `warm` keeps wood colours, `grey` colourless ones.
- `needle`, `asset_file`, `build`: part of the placed scene's file name, where the file lives in the pack, and the command that builds it.
- `footprint`: the catalogue's footprint about the piece's origin, for a piece the pack fits to it (step 7). `look`: the part of the panel shown on comparison sheets. `fit`: see step 8. `unmarked`: how to tell the kinds apart on the kit's own piece, which carries no marks. `frame`: `auto` for a piece larger than a bench (step 2). `ramp_override`: a stop set by hand where no box can avoid something else.
- A style may name its own `panel` (the asset may be clearer in another panel of that style's sheets) and its own `sheet_rule`. The rules: `warm` keeps wood colours, `grey` colourless ones, `green` leaves (blossoms fall out), `pale` stone and plaster.
- A style drawn as sprites has no `build`; it names `run` (a script in the asset's folder that renders its sprites and puts them into the client copy) and `sprites` (their files).

The asset has to be large enough in the sheet to measure. The banyan is 200 to 345 px wide and the benches 50 to 110 px tall: enough for colours.

### 2. Capture the game today and measure the gap

```sh
./asset_try.sh lowpoly_tropical seat_bench_v2 captures/bench-before        # [COUNT] [prop|auto]
cvenv/bin/python asset_bands.py myasset/asset.json lowpoly_tropical captures/bench-before
cvenv/bin/python asset_look.py myasset/asset.json lowpoly_tropical captures/bench-before previews/look.png
```

`asset_try.sh` finds the placed copies of the piece, takes up to three at different facings (unoccupied seats first) and captures each from eye height and from above, at the hour the style's sheets are drawn. Beside each view it saves a mask pass (which pixels are the piece), a material pass (which kind each pixel is, on a build that marked them) and an unlit pass, and it records the scale the game gave the piece. `auto` stands the cameras back by the piece's size, for a lamp post or a tree (tried on both). `asset_bands.py` gives each material's tone bands in the sheet and in the game, pooled over every view.

Read both before building anything. For the tree the numbers showed the shape was not the gap (round 1 changed the shape and they barely moved); colour and detail were. For the bench the eye showed it at once: thin slats on a thin frame where the sheets draw chunky planks.

### 3. Measure the sheet's colours

```sh
cvenv/bin/python asset_ramps.py myasset/asset.json      # -> myasset/ramps.json, ramps.png
```

For each material, a ramp from shadow to highlight: the mean colour of each lightness band of its boxes. Look at `ramps.png` beside the kit's palette and check each ramp by eye. In both assets the kits' colours were a different family from the sheets'.

### 4. Only for an organic shape that is wrong: generate one

```sh
B=/path/to/trellis.cpp; M=/path/to/trellis2-gguf/q8        # the unpacked release, and the 8-bit weights
LD_LIBRARY_PATH=$B $B/trellis-cli inputs/NAME.png raw/NAME.glb --models $M --res 512 --seed 42 --require-gpu --webp off
blender --background --factory-startup --python analyse.py -- raw/NAME.glb parts NAME
```

This gave a real tree from sheets that look like 3D renders (low-poly, voxel) and flat cards from painterly ones. For the bench it gave nothing usable from three crops (a flat slab, a card, no output): a prop is seconds of scripted boxes, and it is too small in the sheets for the generator to see. `analyse.py` is written for a tree. Steps 5 to 10 do not need a generated shape.

### 5. Build with the kit's own code, in the shapes the sheet draws

One builder a kit family: the four Blender kits can share a file (low-poly, anime, and solarpunk and neon which build on the anime kit's helpers), the voxel kit has its own (blocks that keep their own faces), and the pixel kit's is a model swapped in before the kit's renderer runs. The bench's builders are the model.

Where the kit's piece already has the sheet's shape, do not rebuild it. Call the kit's own builder, bake, and sort the faces into kinds by their baked colours (`marks.by_colour`, with `P["fix_winding"] = True` because the kit's boxes are wound inside out); only the colours change. Three of the six planters were done this way (`build_planter_kit.py`).

Otherwise, use each kit's own helpers and keep its conventions: the origin, the facing, the node names, the seat height, and the materials and nodes the game drives by name (glass, lamps, glow, `light`, `lights`). What changed the look in both assets was drawing the masses the way that sheet draws them: look at the sheet enlarged beside the game and choose the primitive from what you see.

In the builder, after adding each part, tell the painting what it is:

```python
P = marks.settings(STYLE)                      # then the asset's `weights` and `ranges`, then params/<style>.json
marked = marks.Marks(mesh, P)
frame.box((1.6, 0.22, 0.10), (0, 0.14, 0.42), "wood", bevel=0.012); marked.mark("timber", "seat-front")
```

A part takes one tone; tops fall in the ramp's lighter stops and undersides in its darkest; a kind may have ranges of its own (iron and stone stay in the dark half). `mark(..., turn="up")` is for open leaves and blades, `turn=None` for leaf cards.

### 6. Bake, paint, shade

After the kit's own `bake.bake_scene()`:

```python
stats = marks.paint({"body": marked.entries}, ramps, STYLE, P, CONFIG["kinds"])
```

`shade.py` gives every marked face a place on the sheet's ramp by rank (how it faces the painted light, how much sky it sees, its part, a little chance), ranks faces that look up apart from the rest so both cameras see the whole ramp, and divides part of the game's light at the sheet's hour back out of the colour. For a piece placed at several facings the sun is averaged over a full turn. Unmarked faces keep their kit colour, darkened where they see little sky. The pack's light comes from its `style.json`.

### 7. Check the contracts

```sh
cvenv/bin/python asset_contracts.py myasset/asset.json captures/myasset-fit-2
python3 check_band.py out2/STYLE/tree_banyan.glb          # one file against a footprint
python3 glbinfo.py FILE.glb                               # triangles, node names, materials
```

`asset_contracts.py` checks each built piece against its kit's spec by the kit tests' own rule (size within 10%, triangle budget, node names) and, for a piece the pack `fill`s, against its footprint by the game's own measure (`band.py`): the game takes what the piece draws from 0.15 to 2.2 m up, leaves included, and stretches the piece so that fills its footprint as the walking grid draws it. A piece inside its footprint is stretched a few per cent; one leaf or limb in that band outside the footprint squeezes the whole piece. With a captures folder it also reports the scale the game really gave.

Also to do before adopting anything, and not done in either pilot: the kit's own tests on the files in place (`city/tools/styles/<kit>/test_assets.py`) and a frame-time run (`city/godot/tools/bench.gd`, on the real display).

### 8. Fit the colours in the game

```sh
cvenv/bin/python asset_fit.py myasset/asset.json lowpoly_tropical 3
```

Each round builds the asset, puts it into the client copy, captures it, measures each material's bands over every view against the sheet's, and adjusts that material's gains. Two or three rounds settle. Settings are kept per style in `myasset/params/<style>.json`.

For foliage, where hundreds of small parts carry the ramp, each ramp stop is fitted. For a piece of a few large flat faces the bands are which face the light falls on, and fitting stops flattens them: set `"fit": {"stops": false}` and only level and hue are fitted, or say it per kind (`{"stops": {"leaf": true, "box": false}}`). The pixel pack's sprites are fitted by hand against their palette shares.

### 9. Judge it

```sh
cvenv/bin/python asset_compare.py myasset/asset.json captures/before after.json compare/
```

The bands match by construction after step 8, so they show only that the fit worked. Judge by eye from the comparison sheets, from eye height and from above, with people using the piece, and at dusk and at night: painted tones are tuned to one hour. The tree also has measures the fit did not use (`metrics.py`); a prop does not yet.

### 10. Record it, and prove the record

Keep the config, builders, settings, assets, captures and comparison sheets together. Then replay every machine step from a fresh working folder:

```sh
tools/setup.sh --bare /path/to/fresh myasset
cd /path/to/fresh && ./asset_replay.sh myasset/asset.json
```

It proves the record is complete, and it is the timing. An adopted asset needs its AI labelling (the generator, input image and seed if a shape was generated) and the sheet revision its colours came from.

## The great tree's own scripts

The banyan was done before the config existed. Its scripts carry its boxes and file names as constants: `ramps.py`, `bands.py`, `metrics.py`, `calibrate.py`, `round.sh`, `compare2.py`, `look.py`, `analyse.py` and the builders `build_lowpoly2.py`, `build_cards2.py`, `build_voxel2.py`, `pixel_pre2.py`. They still run; `banyan/round2/README.md` has the commands, and `banyan_captures.sh` takes again the game's frames that they read. A new asset should take the config path above.

## What stays the same for every asset

1. Measure before building: the sheet's tone bands and the game's, from eye height and from above.
2. Take colours from the sheet, not the kit palette, as a ramp per material.
3. Draw masses the way that sheet draws them, with the kit's own code.
4. Bake colour and shade into vertex colours; fit against captures in the game; leave the pack's light alone (three light changes were measured on the tree and none helped).
5. Check the piece by the game's own rules, and read the scale the game really gave it.
6. Judge with measures the fit did not use where there are any, and by eye from both cameras.
7. Work in a copy of the client; nothing touches the checkout. Replay from a clean folder before calling it done.

## What changes with the style

Each pack lights and draws differently, and the painting has to know how. A seventh style needs its own row.

| Style | What the painting is told | What only this style needed |
| --- | --- | --- |
| Low-poly tropical | plain diffuse light; faces shadow each other | tree: lobed pads, blossoms; bench: chunky planks |
| Voxel | plain diffuse light | every block its own faces and tone, vertex colours on one material (the kit writes one material a palette colour and merges like faces); the kit's spec sizes are not the catalogue's footprints |
| Anime cel | the pack's two-tone (toon) light; leaf cards take no shadows; ink lines over everything | tree: larger, softer cards, no aerial roots; bench: iron ends as bent flat bars |
| Solarpunk | plain diffuse light; leaf cards take no shadows | builds on the anime kit's helpers with its own palette names |
| Neon noir | the sheets' hour is night (21:48): nothing of the day's light is taken out; the fit runs to its limits, since a surface colour can do little at night | tree: leaves take the ramp's warm end near the tree's lamp; bench: the kit's glowing strip kept as its `lights` node |
| Pixel art | not painted by `shade.py` at all: the kit's renderer lights the model and snaps it to 32 fixed colours | fitted by palette shares; a seat is sixteen sprites, one a facing; cannot reach colours the palette lacks |

## What changes with the kind of asset

| Kind | Proven? | What it needs |
| --- | --- | --- |
| Trees, shrubs, planted beds | the great tree | the leaf primitive that sheet draws; nothing leafy below 2.2 m outside the footprint; every ramp stop fitted; smaller plants are placed many times, so triangles count for more than they did for one tree |
| Props of flat faces (benches; by extension tables, stalls) | the bench | parts marked by material; the sun averaged over a full turn; dark ranges for iron and stone; level and hue fitted, not stops; the footprint for a piece the pack fills; six small boxes a style read off the sheet |
| Planted boxes and beds | the planter | both of the above in one piece: the box as a prop, the plants as foliage with their stops fitted; nothing leafy past the footprint; where the kit's piece is already the sheet's, repaint it instead of rebuilding |
| Lamp posts and other pieces with parts the game drives | views only (`auto` framing tried on a lamp post) | glass, glow and the `light` node stay as the kit has them |
| Buildings | no | the painting now takes any kinds and several facings; glass and lit windows are driven by name and must stay; a block is assembled from many modules, not placed as one scene, so the capture does not find it yet and modules are stretched along their footprint; "as the sheet draws it" means bevels, trim and window depth |
| Paving, roads, water | no | found by name by the game (rain wets paving), so their colour is a palette change, not a bake |
| People and robots | no | animated and painted part by part at run time, not baked; movement is a separate piece of work |
| Trams and other moving things | no | they turn as they move, so the sun is averaged as for a prop |
| Pieces drawn as instances of one mesh (a meadow's clumps) | no | `asset_views.gd` finds pieces by their scene file and does not find these |

## Traps

Each cost time once and is now handled in the scripts.

- **The kits' boxes are wound inside out.** `box()` and `beam()` in the kits' `lib.py` give inward normals; the game shows them right because the kits' materials are two-sided. The painting reads normals. `marks.py` turns new faces outward.
- **Blender's glTF exporter drops the alpha of vertex colours.** Material marks go in a UV layer (`kinds.py`).
- **The game's walking band is not the spec's.** The spec says 0.25 to 1.9 m; the game measures a piece over 0.15 to 2.2 m, cuts faces at those heights, counts leaves, and grows the footprint to the cells its walking grid blocks. An early check used the spec's band and missed that round 1's anime tree was being squeezed to 0.76 by 0.61. `band.py` is the game's rule.
- **A box on a highlight lightens the whole material**, and **fitting ramp stops flattens a flat-faced piece** (steps 1 and 8).
- **Telling kinds apart by colour misleads the fit.** Without marks the capture takes everything that is not leaf for the box, soil included, and the box's fit drifts. Marks reach every built piece, leaf cards included (a second UV layer); only the kit's own unbuilt piece is read by colour, and that only for the "today" figures.
- **The nested desktop decides the frame's size.** The game asks for 1920 by 1080 and gets what the desktop gives: 2544 by 1424 on the default nested desktop of 2560 by 1440, which the bench and the planter were measured on. The tree's recorded frames are 1920 by 1080, and taken again on a 1920 by 1080 desktop they came out 1904 by 1064. Boxes are fractions of the frame, so measures carry across sizes only roughly (the tree's distances moved by up to 0.02). Compare frames taken at one size; `CAP_DESKTOP` sets the desktop.
- **A capture can find nothing and say nothing.** One unattended run captured a fresh copy with nothing imported; the cause was not found and it did not recur. The import is checked, a capture that finds no piece is retried once and then fails, and the logs are kept.
- **The generator needs a clean, single, render-like object drawn large.** Painterly crops come back as cards; small props as nothing.
- **Tones are tuned to one hour.** Look at dusk and at night before adopting.

## How long it takes

Measured on the bench (`bench-test/README.md`), on the project laptop:

- **The machine.** Building one 3D piece takes under a second. Each look at it in the game (import, start, run to the sheet's hour, six views with their passes, measure) takes 14 to 19 s a style, and a fit of three rounds about 50 s a style. Every machine step for the bench in six styles, from the concept sheets to the comparison sheets, ran unattended from a fresh folder in 190 and 198 s.
- **The agent.** The bench took 68 minutes from first reading the kits' code to a complete six-style result replayed from a clean folder, and 88 with the follow-up checks: the first prop, with the generic tools built along the way. The planter, made with those tools, took 30 minutes, about 14 of them the machine working.
- **The generator.** One to two minutes an attempt, and useful only for organic shapes.

The tree was not timed.

## Known gaps

- No building, person or moving thing has been tried, and the two timed assets are both small props.
- Only the tree has measures the fit did not use. A prop is judged by eye and by its fitted bands.
- The boxes in the sheets are read off by eye: about ten minutes for six styles, and the step most open to error.
- `asset_fit.py` covers GLB pieces; pixel sprites are fitted by hand.
- The kits' own tests and a frame-time run are not part of the loop.
- Colours are fitted at the sheet's hour only.
- `shade.auto_paint`, which reads a kit-built leaf-card piece's kinds off its baked colours, knows leaf and wood only.
- The capture finds a piece by its placed scene file. It does not find pieces drawn as instances of one mesh, or a block of buildings assembled from modules.

## Files

`tools/`:

- Setting up: `setup.sh`, `requirements.txt`, `cut_panels.py`, `grid.py`, `mark.sh` (timing).
- Capturing: `asset_try.sh` and `asset_views.gd` (a placed asset, close up), `try.sh` (the project's sheet views), `cap-copy.sh`, `import-copy.sh`.
- Measuring: `asset_ramps.py`, `asset_bands.py`, `kinds.py`; `band.py`, `asset_contracts.py`, `check_band.py`, `glbinfo.py`.
- Building and painting: `marks.py`, `shade.py`; `preview.py` (a built file's baked colours, four views).
- Fitting and judging: `asset_fit.py`, `asset_look.py`, `asset_compare.py`. Replaying: `asset_replay.sh`.
- The great tree's own: `analyse.py`, `ramps.py`, `bands.py`, `metrics.py`, `calibrate.py`, `round.sh`, `compare2.py`, `look.py`, `build_lowpoly2.py`, `build_cards2.py`, `build_voxel2.py`, `pixel_pre2.py`, `pixel_run.sh`, `pixel_look.py`, `banyan_captures.sh`, and the hand tools `tones.py`, `patch.py`, `scene.py`.

Assets so far: the great tree (`banyan/round2/`: `params/`, `ramps.json`, `parts/`, `out/`, `compare/`; round 1 in `banyan/`: `inputs/`, `out/`, its builders in `scripts/`), the park bench (`bench-test/`: `bench/` with its config, builders, settings and its own `run_all.sh`; `out/`, `compare/`, timings) and the planter (`planter-benchmark/`: `planter/` with its config, builders and settings; `out/`, `compare/`, timings). The game's frames (`captures/`) and the generator's raw output are not kept in the repository: [README.md](README.md#what-is-not-in-the-repository) says what is left out and how to make it again.
