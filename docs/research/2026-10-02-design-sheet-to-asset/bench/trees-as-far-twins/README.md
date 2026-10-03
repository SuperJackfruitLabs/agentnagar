# Frame time, the low-poly trees as their far twins (2026-10-02, 20:17 to 20:23)

Written by Claude (an AI) from the run's own files.

A trial, to find what the low-poly trees' frame cost is made of. `work/bench_far_as_near.sh`: the order and the
warming of `bench_pairs.sh` (card at 71 to 75 C), on a machine doing nothing else. "New" is the kit's town with
each street tree and palm replaced by its own far twin (`<piece>_far.glb`: 771 to 776 triangles, textures a
quarter the size), so that every one of the 608 copies is drawn as its far twin at every distance. The far twins
are built for every style outside voxel. The game would draw the low-poly ones beyond 90 m if they sat beside
the pieces, but the build places a twin only where the kit has one, and the low-poly kit has none (switching the
swap on is measured in `../trees-far-swap/`).
Median frame time in ms:

| Scene | kit 1 | new 1 | new 2 | kit 2 | kit | new | difference |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Low-poly, diagonal | 3.994 | 4.080 | 4.074 | 4.099 | 4.05 | 4.08 | +0.03 |
| Low-poly, street | 3.208 | 3.334 | 3.331 | 3.244 | 3.23 | 3.33 | +0.11 |

What it says:

- At about 775 triangles a copy the new trees and palms cost 0.03 and 0.11 ms a frame against the kit's, where
  in full (2,250 to 3,680 triangles) they cost 1.08 and 1.21 ms (`../trees-only/`). The kit runs of each
  pair differ by 0.11 and 0.04 ms, so on the diagonal the difference is inside the runs' own spread.
- On the diagonal the +0.03 ms is inside the kit pair's own spread (3.994 and 4.099 ms).
- So what the low-poly trees cost goes with their size as files, drawn 608 times with no far swap. The trial does
  not tell triangles from texture size, since a far twin has both smaller. Triangles are the likelier: counting
  every placement, the new trees and palms are 1.7 to 1.9 million triangles in the district where the kit's are
  0.3 to 0.4 million, and the two materials are the same in both.
- This is a frame-time trial. How the far twins look from near is in the record's pictures
  (`previews/lowpoly-trees-full-and-far.jpg`, `previews/lowpoly-far-twins-close.jpg`): the palms lose little, the
  street trees' crowns turn into a few coarse lumps.
