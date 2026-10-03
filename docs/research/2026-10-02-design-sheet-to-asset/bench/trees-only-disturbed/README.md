# Trees only, on a loaded machine (2026-10-02, 17:17 to 17:26): not usable

Written by Claude (an AI). The run on a quiet machine is `../trees-only/`.

`PIECES=@trees work/bench_pairs.sh lowpoly_tropical neon_noir`: "new" was the kit's town with only the street trees
and palms replaced. Three build agents were running Blender at the time (a load average of 5 to 7 as watched at the time; it was not kept in a file), and I ran the
validator over 115 files during the low-poly runs. Median frame time (ms):

| Scene | kit 1 | new 1 | new 2 | kit 2 |
| --- | --- | --- | --- | --- |
| Low-poly, diagonal | 5.382 | 5.250 | 8.653 | 5.087 |
| Low-poly, street | 4.550 | 5.545 | 5.691 | 3.931 |
| Neon, diagonal | 4.524 | 4.337 | 4.450 | 4.517 |
| Neon, street | 3.179 | 3.499 | 3.522 | 3.488 |

The kit's runs here are 0.46 to 1.35 ms slower than the same runs an hour earlier (`../afternoon/`), and twins
disagree by up to 3.4 ms. Nothing about the trees can be read from it. It is kept as a warning: the bench needs
the processor to itself as well as the graphics card.
