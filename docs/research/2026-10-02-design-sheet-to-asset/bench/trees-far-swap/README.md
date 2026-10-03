# Frame time, the low-poly trees with the game's own far swap (2026-10-03, 05:16 to 05:20)

Written by Claude (an AI) from the run's own files.

The game draws a planted piece as its far twin (`<piece>_far.glb`) beyond 90 m wherever the twin's file sits
beside the piece, in any pack (`city/godot/styles/pack_3d.gd`, `_plant`). The low-poly kit has no twins, and the
build places a twin only where the kit has one, so the new low-poly trees had been measured drawn in full at
every distance (`../trees-only/`). This run switches the swap on: `work/bench_far_swap.sh` places the five twins
built for low-poly beside the new trees and palms (`work/far_swap.py`; 774 to 776 triangles, textures a quarter
the size), with the order and the warming of `bench_pairs.sh` (card steady at 73 C, 73 to 76 C over the four
runs), on a machine doing nothing else. "New" is the kit's town with only the street trees and palms built from
their design sheets, drawn in full within 90 m and as twins beyond. Median frame time in ms:

| Scene | kit 1 | new 1 | new 2 | kit 2 | kit | new | difference | 99th percentile, kit | new |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Low-poly, diagonal | 4.084 | 4.143 | 4.165 | 4.151 | 4.12 | 4.15 | +0.04 | 7.43 | 6.45 |
| Low-poly, street | 3.235 | 3.541 | 3.553 | 3.282 | 3.26 | 3.55 | +0.29 | 5.66 | 5.15 |

What it says:

- The pairs agree within 0.07 ms.
- With the swap the new trees and palms cost +0.04 ms on the diagonal and +0.29 ms from the street, against
  +1.08 and +1.21 ms drawn in full at every distance (`../trees-only/`, the evening before). From the street
  many copies stand within 90 m and are drawn in full; from above most are farther.
- The 99th percentile is lower with the new trees than with the kit's in both scenes.
- Nothing in the game's code was changed: switching the swap on is placing five files.

An earlier run of this (05:08 to 05:13) is not kept as a result: switching the twins off again left their import
files behind, the game then took the twins to be there, failed to load them and drew the kit's trees only within
90 m in its last kit run (its log says so). `far_swap.py --remove` now takes the import files out too.
