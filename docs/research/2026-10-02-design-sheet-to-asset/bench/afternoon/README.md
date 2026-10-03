# Frame time, kit against every piece built so far (2026-10-02, 16:20 to 16:43)

Written by Claude (an AI). Superseded by `../evening/`, the same run on a quiet machine with the final pieces.
Kept for what it shows about a busy machine: where it disagrees with the evening's run, the evening's is right.

`work/bench_pairs.sh` with its defaults: each style warmed until the card stops warming (75 to 78 C here), then
kit, new, new, kit. "New" is every built piece placed (`build.py place STYLE`): the first set and the square's
props as they stood at the time. Median frame time in ms (p50) of each run:

| Style | Scene | kit 1 | new 1 | new 2 | kit 2 | kit | new | difference |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| low-poly | diagonal | 4.800 | 5.652 | 5.646 | 4.551 | 4.68 | 5.65 | +0.97 |
| low-poly | street | 3.907 | 4.783 | 4.740 | 3.470 | 3.69 | 4.76 | +1.07 |
| neon | diagonal | 3.170 | 3.571 | 3.570 | 3.175 | 3.17 | 3.57 | +0.40 |
| neon | street | 2.504 | 2.879 | 2.892 | 2.501 | 2.50 | 2.89 | +0.38 |
| anime | diagonal | 2.811 | 3.492 | 3.338 | 5.013 | (2.81) | 3.42 | about +0.6 |
| anime | street | 2.408 | 2.647 | 2.694 | 2.446 | 2.43 | 2.67 | +0.24 |
| solarpunk | diagonal | 3.744 | 4.973 | 4.168 | 3.735 | 3.74 | (4.17 to 4.97) | +0.4 to +1.2 |
| solarpunk | street | 3.019 | 3.851 | 3.519 | 2.978 | 3.00 | (3.52 to 3.85) | +0.5 to +0.9 |
| voxel | diagonal | 4.484 | 4.931 | 4.358 | 4.477 | 4.48 | (4.36 to 4.93) | not shown |
| voxel | street | 4.631 | 3.802 | 3.735 | 3.626 | (3.63 to 4.63) | 3.77 | not shown |

What can be said, and what cannot:

- The machine was not quiet. Three build agents and my own work ran Blender during the measurement, and some of
  that renders on the same card. The runs in brackets disagree with their twins by 0.3 to 2.2 ms: anime's second
  kit run on the diagonal, both of solarpunk's new runs, voxel's. Low-poly's and neon's pairs agree within 0.45
  and 0.013 ms.
- In neon, whose pairs agree within 0.013 ms, every built piece together costs 0.4 ms a frame; in low-poly,
  whose kit pairs differ by up to 0.44 ms, about 1.0 ms.
  With them a frame takes 2.9 to 5.7 ms at the median, against the 8.33 ms of the 120 frames a second that is
  the gate.
- Voxel shows no difference that stands clear of its runs' disagreement, and its street trees were being rebuilt
  while it ran, so its "new" is not the present pieces.
- Which pieces cost the time is not measured: this run has no "only the trees" and "all but the trees" columns.
  The planted pieces (trees, palms, shrubs, railing) are drawn by the hundred and are the first to suspect.
