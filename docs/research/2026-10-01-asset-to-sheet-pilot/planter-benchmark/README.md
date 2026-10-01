# The benchmark: a third asset with the finished tools (the planter in six styles)

Run on 2026-10-02 for Agentnagar's art rework by an AI coding agent (Claude) on the project laptop. It follows the bench test ([`../bench-test/`](../bench-test/README.md)), whose 68 minutes included building the generic tools. This run times an asset made with those tools as they stood, following [`../WORKFLOW.md`](../WORKFLOW.md) step by step. None of it is in the style packs. The planters in `out/` are scripted geometry (no generated models), painted from colours measured in the AI-generated concept sheets.

## The asset

The square planter (catalogue kind `planter`, 1.3 m square, eleven placed, a piece the packs fit to its footprint). It mixes the two kinds already proven: a box of flat faces, as the bench, and plants, as the tree.

| Style | The kit's planter today | What the sheet draws, and what was done |
| --- | --- | --- |
| Low-poly tropical | a limewash box, one clipped ball of a shrub | a pale stone box brimming with broad-leaved plants and yellow and pink blossoms: rebuilt with eleven of the kit's own leafy rosettes and sixteen of its blossoms |
| Voxel | a grey box under a few large stepped slabs | a grey block box under a heap of small green cubes with white blossom cubes: rebuilt in 0.2 m blocks that keep their own faces |
| Anime cel | a stone box, a clipped leafy shrub | the same: the kit's own planter, repainted |
| Solarpunk | a timber crate, a flowering shrub | the same: the kit's own planter, repainted |
| Neon noir | a dark box lit at its foot, a dark shrub | the same: the kit's own planter, repainted |
| Pixel art | a smooth sand-coloured box, a ring of shrub balls | a box of grey stone blocks full of flowering plants: the model behind the sprite swapped |

`compare/overview.png` and `compare/<style>.png` show the sheet, the game today and the new planter.

## How long it took

**The agent: 29.8 minutes** of wall-clock from the first look at the kits' code to the record replayed from a fresh folder (`timeline.tsv`), against 67.7 for the bench. About 14 of the 29.8 were the machine working: captures, 28 fitting rounds, the replay.

| Minutes | Step |
| --- | --- |
| 0.5 | read the kits' planter code and how the packs place it |
| 4.1 | find the planter in six sheets, read the boxes, write the config |
| 4.4 | capture today's planters, measure the gap and the sheets' ramps |
| 3.4 | write the builders (low-poly, the three repainted kits, voxel, pixel) |
| 11.6 | first look in the game and fit, twice over (see below) |
| 0.6 | bring the low-poly planter under its triangle budget; a last fit round |
| 3.8 | save the record and replay it from a fresh folder |
| 1.1 | three additions to the tools (below) |

The split between steps is approximate: time spent writing a command is counted in whichever step was open before it ran. The total is exact.

**The machine**: every machine step for six styles, from the concept sheets to the comparison sheets, unattended from a fresh folder with the config-driven `asset_replay.sh` (`benchmark.tsv`): 197.8 s, plus 7.1 s to assemble the folder. The same as the bench (190 to 198 s): the time is the game's, not the asset's.

So, on this evidence: about half an hour of agent time for an asset in six styles once the tools exist, and about three and a half minutes of machine time to rebuild, capture, measure and compare it. Two assets are a small sample, and both are small props.

## Result

Colour against the sheet's tone bands, over three planters from eye height and from above (mean colour difference, CIE76; `results.json`). As for the bench, this is the quantity the fit adjusts, and today's pieces are told apart by colour where the new ones carry marks.

| Style | Leaves: today | Leaves: new | Box: today | Box: new |
| --- | --- | --- | --- | --- |
| Low-poly tropical | 25.0 | 6.9 | 19.0 | 6.8 |
| Voxel | 29.4 | 8.9 | 11.2 | 6.7 |
| Anime cel | 32.3 | 10.5 | 14.2 | 7.3 |
| Solarpunk | 25.9 | 7.5 | 16.6 | 12.8 |
| Neon noir | 9.6 | 5.3 | 23.8 | 17.1 |

Contracts (`contracts.txt`): all five meet their kits' specs; the low-poly planter has 1,488 triangles against a budget of 1,500 (today's has 436), the voxel one 226 against 300. The low-poly planter is built to the footprint and the game places it at 1.004; the others keep their kits' sizes and are stretched 4 to 9%, as today.

Pixel art: the sprite's palette shares went from light stone 24%, leaf 20%, sand 26% to stone 22%, grey 20%, leaf 19%: a grey stone box where the kit's is sand.

## What the workflow needed that it did not have

The procedure held again. Three things were added to the tools, all for pieces the kit's own builder makes:

1. **Painting a kit-built piece.** Three styles needed no new shape, only the sheet's colours on the kit's planter. `marks.by_colour` sorts a built piece's faces into kinds by their baked colours, and `shade.py` detects the kit's inside-out boxes (`fix_winding`) and reads them the way the game shows them.
2. **Marks on pieces with leaf cards.** A leaf card's texture uses the first UV layer, where the material marks went. Without marks the capture told leaf from box by colour, soil counted as box, and the box fit drifted away over three rounds (anime's colour distance went from 11.2 to 14.4). The marks now go in a second layer on such pieces, and the same fit settled at 7.3.
3. **A replay script driven by the config** (`asset_replay.sh`), so an asset no longer needs a replay script of its own.

The banyan's trees and the benches still rebuild byte for byte with the extended scripts.

Smaller: a style can name its own sheet panel (the anime and solarpunk planters are clearer in other panels); colour rules for leaves and pale stone; each kind chooses whether its ramp stops are fitted (leaves yes, a box no); the capture takes several copies of a piece that always stands one way; open leaves are turned to face up for the painting.

## Limits

- Neon's box came out brown where the sheet's concrete is grey under warm light: the fit pushes against the blue night light, as with the neon tree and bench.
- Solarpunk's shrub is a yellower olive than its sheet's larger plants: its leaf ramp was measured from the small flowering plants on the square's timber planters.
- The low-poly plants stand lower and thinner than the sheet's: nothing may reach past the footprint, or the game squeezes the whole planter.
- The anime sheet shows no boxed planter in the park panel; its boxes were read from the street panel, where they are blurred.
- No measure the fit did not use; the kits' own tests and frame time were not run.

## Re-running

```sh
export AGENTNAGAR=/path/to/agentnagar            # the checkout; every script reads it
../tools/setup.sh --bare /path/to/work planter
cd /path/to/work
./asset_replay.sh planter/asset.json       # every machine step, timed -> planter/benchmark.tsv, compare-planter/
```

Checked on 2026-10-02 from this repository copy, twice, each from a fresh working folder: 198.7 and 200.3 s, all 8 files in `out/` identical, the contract report identical, no failed logs.

## Files

- `planter/`: `asset.json` (the config, with every box), `build_planter_lowpoly.py`, `build_planter_kit.py` (anime, solarpunk, neon), `build_planter_voxel.py`, `pixel_planter_pre.py` and `pixel_planter_run.sh`, `params/`, `ramps.json` and `ramps.png`.
- `out/`, `compare/`, `previews/` (today's planters beside the sheets', the boxes drawn on the sheets, the pixel sprite), and `captures/today`, `captures/new`: where each captured piece stood and the scale the game gave it (`asset-views.json`; the frames themselves are not kept in the repository).
- `results.json`, `contracts.txt`, `benchmark.tsv`, `setup-seconds.txt`, `timeline.tsv`, `fit-1.log`, `fit-2.log`.
