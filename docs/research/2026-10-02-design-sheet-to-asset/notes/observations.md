# Figures from runs whose files were replaced

Written by Claude (an AI), 2026-10-02.

The report quotes a few figures from runs of the night and the day whose output was later overwritten by a better run. They are set down here as the tools printed them, with the time (to a few minutes where it says "about"), so that the report does not rest on memory alone. Everything else in the report can be read off the files in `out/` and `bench/`.

| When | What was run | What it printed | Quoted in the report as |
| --- | --- | --- | --- |
| 04:33 | the first fit of the low-poly tree, asked for 14,000 triangles, without a rebuilt surface | `42244 tris`, `texels used 0.01` | "asked for 14,000 it stopped at 42,244" |
| about 05:03 | the capture of the first neon tree placed in the game (`asset-views.json`) | `scale [0.576, 1.0, 0.672]`, `size [6.939, 9.527, 7.867]`; the game's measure of the piece in the walking band: 9.2 by 7.89 m | "the game shrank the whole tree to 58% of its width" |
| 05:54 | the contract check of a low-poly tree cut as one mesh and asked for 6,280 triangles | `7411 tris (budget 6500 ...) MISSES` | "asked for 6,500 it stalled near 7,400" |
| about 04:55 | the metal map read out of each generated model (mean of the texture's metal channel) | neon tree 0.99, neon café chair 0.93, neon reading chair 0.96, neon bench 0.70, low-poly reading chair 0.57, low-poly bench 0.38, low-poly café chair and both low-poly and plain trees 0.00 | the metal figures |
| 06:24 | the tree's measures with two lighter colourings of the low-poly tree | `0.603`, `0.610`, against `0.534` for the colouring kept, on the tree as it then was | the two lighter colourings |
| by 06:46 | the contract check and the capture before the footprint rule was enforced on crossing edges | neon tree `in the walking band 5.44 by 5.16 m`, placed by the game at `0.973` of its width | "the neon tree was still squeezed a little" |
| about 07:05 | the seats' tops before `--seat`, kit against new, in metres | low-poly bench 0.47, 0.42; low-poly café chair 0.48, 0.48; low-poly reading chair 0.42, 0.47; neon bench 0.47, 0.40; neon café chair 0.47, 0.45; neon reading chair 0.42, 0.51 | "2 to 9 cm off" |
| about 13:30 | the anime street tree's crown as the game drew it against its own texture, before its leaf normals were lifted | the shadow tone at 0.38 of the painted colour in red and green (the printed lines were not kept; the figure is from the ledger's entry of that hour) | "38% of its painted colour" |
| about 14:40 | every hidden face dropped (`--drop-hidden`) on the first seats, as a trial | `seat_reading-chair_v2 317 {'hidden_faces_dropped': {'of': 14859, 'dropped': 14414}, ...}` for the anime reading chair | "it took 14,414 of 14,859 faces" |
| 16:54 to 17:10 | the game's whole suite with every piece built by then in place, three build agents working on the machine | `PASS 919, FAIL 1`; `FAIL test_work_app.gd:test_board_events_stay_cheap_with_many_cards: the worst event took 4.14 ms (budget 4 ms)`. That test alone passed three times of three (`out/game-tests-work_app.txt`) | "one failure, a timing test" |
| 20:30 to 20:45 | the same suite with every piece in place, before the neon trees' leaf roughness was changed | `PASS 920, FAIL 0`; kept as `out/game-tests-2030.txt` | the earlier of the evening's two runs |

The working folder on the laptop (`.asset-pilot/2026-10-02-sheet-to-asset/`) keeps the logs of the later runs (`logs/`), the earlier sets of frame-time runs (`bench/first`, `second`, `third`) and a ledger of the night.
