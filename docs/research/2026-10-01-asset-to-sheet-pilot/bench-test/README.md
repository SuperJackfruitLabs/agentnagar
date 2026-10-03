# The workflow tested on a second asset: the park bench in six styles

Test of 2026-10-01/02 for Agentnagar's art rework, run by an AI coding agent (Claude) on the project laptop. It follows the banyan pilot ([`../banyan/`](../banyan/README.md)); the procedure under test is [`../WORKFLOW.md`](../WORKFLOW.md). None of it is in the style packs. The benches in `out/` are scripted geometry (no generated models), painted from colours measured in the AI-generated concept sheets.

## Why

The workflow was written from one asset, a tree that stands once and is mostly leaves. The question was whether it can be reused for other assets or needs changes by style and by kind of asset; the test was to put a bench through it and time it. A bench is the opposite case: small, a few flat faces, two materials, eighteen copies at several facings, sat on by people, fitted by the game to a footprint.

## Result

The procedure held: fix the target in the sheet, measure the gap, take the colours from the sheet, draw the piece as the sheet draws it with the kit's own code, paint and shade, check the contracts, fit in the game, judge. The tooling did not: most of it knew only the tree. It was extended during the test and is now driven by one config file an asset (`bench/asset.json`), so the next asset needs a config, its builders and its boxes, not new tools. `compare/overview.png` and `compare/<style>.png` show the sheet, the game today and the new bench.

What each sheet draws, and what was built:

| Style | The kit's bench today | The sheet's bench, as built |
| --- | --- | --- |
| Low-poly tropical | thin slats on thin black iron | a chunky bench: two broad seat boards 10 cm thick, two broad back planks, timber arm blocks, dark posts |
| Voxel | striped slats, charcoal frame and arms | a slab of orange blocks on grey stone legs with a low block back; every block its own faces and tone |
| Anime cel | thin slats on thin black iron | broad planks on iron ends, each a flat bar bent into leg, arm and back post |
| Solarpunk | blonde slats between white end frames | all timber: slats between solid timber ends under a timber arm, a thick top rail |
| Neon noir | dark slats, a warm strip under the seat | the same strip; slats under a thick top rail whose top catches the light |
| Pixel art | mid-brown slats that run together into a dithered panel | two broad dark back planks with lit top edges and a gap between, three seat planks |

Colour against the sheet's tone bands, over three benches at different facings from eye height and from above (mean colour difference, CIE76; `results.json`):

| Style | Timber: today | Timber: new | Frame: today | Frame: new |
| --- | --- | --- | --- | --- |
| Low-poly tropical | 8.6 | 4.9 | 12.6 | 2.8 |
| Voxel | 18.6 | 9.7 | 18.3 | 7.7 |
| Anime cel | 12.9 | 9.5 | 20.5 | 7.8 |
| Solarpunk | 19.3 | 7.4 | no frame in the sheet | |
| Neon noir | 16.7 | 10.3 | not measurable in the sheet | |

Two cautions on that table. It is the quantity the fit adjusts (level and hue), so it shows the fit worked, not an independent gain; the bench has no independent measure, and its shape is judged by eye from the comparison sheets. And today's pieces carry no marks, so their timber is told from their frame by colour, the new ones' by the build's own marks.

Pixel art: the sixteen sprites' palette shares went from mid brown 29%, outline 29%, dark 26%, dark brown 17% to mid brown 31%, outline 25%, dark brown 23%, dark 22%. The visible change is that the planks read as planks; it is small.

Contracts (`contracts.txt`): the four Blender-kit benches meet their kits' specs (size within 10%, 512 to 724 triangles against budgets of 1,500; today's are 428 to 704). The voxel bench has 214 triangles (budget 300; today 280) and is 1.6 m by 0.6 m, the catalogue's bench footprint, where the kit's spec says 1.8 m by 0.7 m: over the spec's 10% in depth and at its edge in width. The kit's own bench reaches 15 cm outside the footprint and the game squeezes it by a ninth. Adopting this one means changing the spec's size, or building to 1.8 m by 0.7 m and accepting the squeeze.

In the game every new bench is stretched 4 to 7% in depth and not at all in width (`captures/new/<style>/asset-views.json`); the kits' own are stretched 6 to 10%, the voxel kit's squeezed 11% both ways. People sit on the new benches at the same seat height (checked by eye in two packs' street views, `previews/sitters.png`).

## How long it takes

**The machine.** Every machine step for all six styles, from the concept sheets to the comparison sheets, with the settings already fitted, unattended from a fresh working folder (`bench/run_all.sh`; RTX 3070 Ti laptop, Blender 5.2.2, Godot 4.6.3). Three runs, each from its own fresh folder, in seconds (`benchmark-run1.tsv` to `benchmark-run3.tsv`):

| Step | Run 1 | Run 2 | Run 3 |
| --- | --- | --- | --- |
| Assemble the working folder (copy the client, Python environment, cut the sheets' panels) | 7.1 | 7.0 | 6.9 |
| Cut every sheet panel for six styles | 6.7 | 6.3 | 6.3 |
| Measure the sheets' ramps | 0.3 | 0.3 | 0.3 |
| Capture the game today, five 3D packs (the first includes the copy's first import, about 5 s) | 83.9 | 79.1 | 79.7 |
| Build, put in the game, capture and measure, five 3D packs | 88.6 | 86.9 | 87.4 |
| Pixel sprites: render and post-process sixteen facings and their night twins | 1.1 | 1.0 | 1.0 |
| Pixel pack: capture the sheet views | 13.6 | 13.3 | 13.1 |
| Check the kits' specs and the footprint | 0.05 | 0.05 | 0.05 |
| Compose seven comparison sheets | 3.8 | 3.4 | 3.4 |
| **Total without the first row** | **198.0** | **190.3** | **191.2** |

A fourth run, with the scripts as they stood after the planter benchmark, took 193.3 s and gave the same files and the same measurements (`benchmark-run4.tsv`).

Building one 3D bench takes 0.5 to 0.7 s. Nearly all the rest is the game: 14 to 19 s a style to import, start, run to 13:00 and capture six views with their mask, material and unlit passes. A fitting round costs the same 15 to 19 s a style, and three rounds settle. The runs gave the same built files byte for byte, and the two whose measurements were compared gave the same to the last digit (the captures themselves differ by a few dozen pixels of far background).

**The agent.** Wall-clock from first reading the kits' bench code to a complete six-style result replayed from a clean folder: 67.7 minutes (`timeline.tsv`). Then 19.9 minutes of follow-up checks that found and fixed three things (below), with a second clean replay of the bench and a re-check of the banyan. 87.6 minutes in all. This write-up, the capture's `auto` framing and the third replay came after and are not counted.

| Minutes | Step |
| --- | --- |
| 4.4 | read the kits' bench code; find the bench in the sheets; plan the views |
| 7.9 | capture today's benches close up; cut the sheets' benches and set them beside today's |
| 4.8 | measure today's benches against the sheets (the boxes, read off by eye) |
| 6.5 | toolkit: painting for any kind of face and several facings; a capture that knows which pixels are the piece and of what material; material marks |
| 8.6 | write the builders: four Blender kits, voxel, pixel |
| 18.8 | first look in the game; fit; second pass (keeping the frames dark, fitting level and hue only) |
| 5.8 | contract check; three attempts with the 3D generator |
| 12.2 | save the record; first unattended replay, which failed once (below); second, clean |
| 19.9 | follow-up: the game's real band rule, the checked import, the shared marks module, a second clean replay of the bench, a re-check of the banyan |

(The rows before the follow-up add to 69.0: the first fit ran in the background while the voxel and pixel builders were written.)

This is the cost of the first prop, not of the next. Generic scripts were written inside most of those steps (the capture, the measuring, the fit loop, the comparison sheets, the replay), and four faults in them were found and fixed. My estimate at the time was that about half would not recur. It was then measured: the planter, made with the finished tools, took 29.8 minutes (`../planter-benchmark/README.md`).

**The 3D generator** (TRELLIS.2, as in the banyan pilot) was tried on three sheet crops of benches, 51 to 112 px tall in the sheets and enlarged four times (the crops and the outputs are not kept in the repository): 64 s for a flat slab with a bush on it, 98 s for the picture on a flat card, and "no voxels produced" after 33 s. Nothing usable. A bench is seconds of scripted boxes; the generator is for organic shapes it can see whole.

## What the test changed in the toolkit

All in `../tools/`, and described in `../WORKFLOW.md`:

- `asset.json`: one config an asset. Its kinds of face, the boxes in each style's sheet panel that lie on each kind, how to find the placed piece, where its file lives, how to build it, its footprint, what to fit.
- `asset_views.gd`, `asset_try.sh`: close views of any placed piece, at up to three facings, from eye height and from above, each with a mask pass (which pixels are the piece), a material pass (which kind each pixel is) and an unlit pass, and a record of the scale the game gave the piece.
- `asset_ramps.py`, `asset_bands.py`, `asset_fit.py`, `asset_look.py`, `asset_compare.py`: the sheet's ramps, the tone bands by material over every view, the fit loop, the review sheet and the comparison sheets, all from the config.
- `band.py`, `asset_contracts.py`, `check_band.py`: the game's own measure of what a piece draws where people walk, and the checks built on it.
- `marks.py`: how a builder marks its faces (kind, part, where on the ramp tops, sides and undersides may fall) and the one call that paints a placed prop.
- `shade.py`: any kind of face, not only leaf and wood; the sun averaged over a full turn for pieces placed at several facings; each face's kind marked for the capture.
- `setup.sh --bare WORK ASSET_DIR`, `import-copy.sh`, `grid.py` with an enlarged region, `mark.sh` for timing, and an `auto` framing for the capture so it also suits a lamp post or a tree (tried on both, not used for the bench).

The banyan's five trees still rebuild byte for byte with the extended scripts.

## What went wrong on the way

Each is now handled in the toolkit, and each would have cost the next asset the same time.

1. **The kits' boxes are wound inside out.** `box()` and `beam()` in the kits' `lib.py` give faces whose normals point inward; the game shows them right because the kits' materials are two-sided. The painting reads normals, so the first build saw no sky from any face. `marks.py` turns new faces outward.
2. **Blender's glTF exporter drops the alpha of vertex colours.** The material marks were first written there and never reached the game. They are now a UV layer, which flat-coloured kit pieces do not otherwise have.
3. **Fitting each ramp stop flattens a piece of flat faces.** On foliage, hundreds of small parts carry the ramp. On a bench the bands are which face the light falls on, and per-stop gains flattened them. A flat-faced asset fits level and hue only (`"fit": {"stops": false}`).
4. **A frame's boxes must lie on its body, not on its lit edges.** The painting gives every stop of a ramp a share of the faces, so a box that takes in a highlight makes the whole frame light. Kinds also take their own ranges: iron and stone stay in the dark half.
5. **The first unattended replay captured nothing for its first style and did not notice.** The copy had not been imported, the game drew placeholders, and the capture found no bench. It did not recur in ten later fresh copies and the cause was not found. The import is now checked (every GLB must come through as a scene, one retry), a capture that finds no piece is retried once and then fails loudly, and the logs are kept.
6. **The footprint check used the wrong band.** The spec's walking band is 0.25 to 1.9 m; the game measures a piece over 0.15 to 2.2 m, cuts faces at those heights, and then grows the footprint to the cells its walking grid blocks. `band.py` is now the game's rule, and its predictions match the scales seen in the game. Checked back on the banyan, in the game: round 2's trees are stretched 2 to 6% like the kits' own, and so are four of round 1's, but **round 1's anime tree had been squeezed by the game to 0.76 by 0.61**, by leaf cards between 1.9 and 2.2 m outside its square. That was not noticed at the time and is now noted in the banyan's READMEs.

## Limits

- One prop, in six styles. Buildings, people and moving things are untested.
- The anime bench's iron reads greyer than the sheet's.
- Neon's fit ran to its limits (timber gain 8.9, blue at its floor): at night a surface colour can do no more, as with the tree.
- The solarpunk and neon benches are closer in colour than in build: their sheets draw a heavier bench than slats can give.
- The kits' own test suites were not run (they test the files in the repository); the contract check applies the kits' spec rule to the built files. Frame time was not measured; triangle counts are within budget and close to today's.
- The kits' other bench files, which the packs do not place (`bench_park.glb`, the pixel kit's `scenery/bench_x.png`), were left alone.

## Re-running

```sh
export AGENTNAGAR=/path/to/agentnagar            # the checkout; every script reads it
../tools/setup.sh --bare /path/to/work bench
cd /path/to/work
bench/run_all.sh                 # every machine step, timed -> bench/benchmark.tsv, compare-bench/
cvenv/bin/python asset_fit.py bench/asset.json lowpoly_tropical 3      # fit one style again
```

Checked on 2026-10-02 from four fresh working folders, the last with the scripts as they then stood: every bench and sprite identical to `out/`, no failed logs. Checked again the same day from this repository copy: 188.7 s, all 38 files in `out/` identical, the contract report identical, no failed logs.

## Files

- `bench/`: `asset.json` (the config, with every box), `build_bench.py` (four Blender kits), `build_bench_voxel.py`, `pixel_bench_pre.py` and `pixel_bench_run.sh`, `params/` (each style's fitted settings), `ramps.json` and `ramps.png` (the sheets' ramps), `run_all.sh`, `normals_check.py` (the inside-out test).
- `out/`: the benches and sprites. `captures/today`, `captures/new`: where each captured piece stood and the scale the game gave it (`asset-views.json`; the frames themselves are not kept in the repository). `compare/`: the comparison sheets. `previews/`: the sitters, the pixel sprites, today's benches beside the sheets'.
- `results.json`, `contracts.txt`, `benchmark-run1.tsv` to `benchmark-run4.tsv`, `setup-seconds.txt`, `timeline.tsv`, `fit-1.log` to `fit-3.log`.
