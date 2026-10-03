# Frame time, the kit's pieces against every piece built (2026-10-02, 19:45 to 20:07)

Written by Claude (an AI) from the run's own files.

`work/bench_pairs.sh` with its defaults: each style is run with the kit's pieces until the card stops warming
(72 to 76 C here), then kit, new, new, kit. "New" is every built piece placed (`build.py place STYLE`): the seats,
the great tree and the square's props as this record keeps them. In neon the street trees and palms placed for this
run are the ones in their sheet's greens; the ones left in the game afterwards are the same meshes in the kit's
greens. Nothing else
ran on the machine: its load average was 1.3 to 1.7, which is the game. After the run the neon trees' and palms'
leaf roughness was changed from 0.6 to 0.85 (one number in each file's material; no geometry and no texture
changed), so the neon files kept are not byte for byte the ones measured.

Median frame time in ms (p50) of each run, the mean of each pair, and the larger 99th percentile of each pair:

| Style | Scene | kit 1 | new 1 | new 2 | kit 2 | kit | new | difference | 99th percentile, kit | new |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| low-poly | diagonal | 4.048 | 5.654 | 5.666 | 4.101 | 4.07 | 5.66 | +1.59 | 7.13 | 6.57 |
| low-poly | street | 3.209 | 4.699 | 4.700 | 3.222 | 3.22 | 4.70 | +1.48 | 5.10 | 5.37 |
| neon | diagonal | 3.209 | 3.571 | 3.615 | 3.151 | 3.18 | 3.59 | +0.41 | 5.52 | 5.42 |
| neon | street | 2.531 | 2.877 | 2.881 | 2.497 | 2.51 | 2.88 | +0.36 | 3.94 | 4.43 |
| anime | diagonal | 2.799 | 3.200 | 3.197 | 2.806 | 2.80 | 3.20 | +0.40 | 4.08 | 4.63 |
| anime | street | 2.368 | 2.635 | 2.629 | 2.375 | 2.37 | 2.63 | +0.26 | 3.62 | 3.64 |
| solarpunk | diagonal | 3.713 | 4.265 | 4.260 | 3.703 | 3.71 | 4.26 | +0.55 | 4.70 | 4.85 |
| solarpunk | street | 2.935 | 3.409 | 3.406 | 2.931 | 2.93 | 3.41 | +0.47 | 3.67 | 3.98 |
| voxel | diagonal | 3.762 | 3.730 | 3.741 | 3.816 | 3.79 | 3.74 | -0.05 | 6.31 | 5.89 |
| voxel | street | 2.797 | 2.828 | 2.843 | 2.806 | 2.80 | 2.84 | +0.03 | 4.52 | 4.21 |

What it says:

- The two runs of a pair agree within 0.06 ms in every scene, so each difference stands clear of the runs' own
  spread. (In the afternoon's run, with build agents working on the same machine, pairs disagreed by up to 2.2 ms.)
- Every built piece together costs 1.5 to 1.6 ms a frame in low-poly, 0.4 ms in neon, 0.3 to 0.4 ms in anime and
  about 0.5 ms in solarpunk. In voxel there is no difference to measure (-0.05 and +0.03 ms).
- With every piece in place a frame takes 2.6 to 5.7 ms at the median and at most 6.6 ms at the 99th percentile,
  against the 8.33 ms of 120 frames a second. (The bench's own count of missed refreshes is zero in every run,
  but the hidden desktop refreshes at 60 Hz, so that says little.)
- `../trees-only/` splits the low-poly and neon figures into the street trees and palms and the rest.

This is the game's bench in a hidden desktop at 1920 by 1080, a comparison of two sets of pieces in the same
minutes on the same card. It is not the project's frame-rate gate, which needs the real display.
