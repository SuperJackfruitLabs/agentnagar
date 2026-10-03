# Frame time, the street trees and palms alone (2026-10-02, 20:07 to 20:14)

Written by Claude (an AI) from the run's own files.

`PIECES=@trees work/bench_pairs.sh lowpoly_tropical neon_noir`, straight after `../evening/` on the same quiet
machine with the card at 76 to 78 C: "new" is the two street trees and the three palms built from their design
sheets, with every other piece the kit's. The district has 309 street-tree and 299 palm placements.

| Style | Scene | kit 1 | new 1 | new 2 | kit 2 | kit | new | difference | 99th percentile, kit | new |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| low-poly | diagonal | 4.146 | 5.236 | 5.238 | 4.162 | 4.15 | 5.24 | +1.08 | 7.28 | 7.05 |
| low-poly | street | 3.297 | 4.525 | 4.515 | 3.328 | 3.31 | 4.52 | +1.21 | 5.72 | 6.16 |
| neon | diagonal | 3.161 | 3.262 | 3.255 | 3.160 | 3.16 | 3.26 | +0.10 | 4.72 | 4.51 |
| neon | street | 2.511 | 2.636 | 2.629 | 2.504 | 2.51 | 2.63 | +0.12 | 3.41 | 3.48 |

What it says:

- In low-poly the new trees and palms cost 1.1 to 1.2 ms a frame, most of the 1.5 to 1.6 ms that every built
  piece costs together (`../evening/`). The low-poly kit has no far twins, so no twin is placed beside the new
  pieces and the game draws every copy in full at every distance: 2,250 to 3,680 triangles where the kit's trees
  and palms have 370 to 680.
- In neon they cost 0.1 ms, of 0.4 ms for every piece. In neon, anime and solarpunk the twins (about 775
  triangles) are placed beside the pieces, and the game swaps to them beyond 90 m.
- `../trees-far-swap/` switches the swap on for the low-poly trees (+0.04 and +0.29 ms), and
  `../trees-as-far-twins/` draws them as their twins at every distance.
