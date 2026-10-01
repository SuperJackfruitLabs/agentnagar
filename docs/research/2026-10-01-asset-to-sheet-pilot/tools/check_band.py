"""check_band.py FILE.glb [...] [--footprint x0,z0,x1,z1]: what a GLB draws where people walk, by the game's own
measure (band.py: its faces cut to 0.15-2.2 m up), per node, against a footprint in metres about the origin
(default: the great tree's, 5.2 m by 5.1 m).

A pack that `fill`s the piece stretches it so this box fills the footprint as the walking grid draws it. A box
wider than the footprint means the game will squeeze the whole piece: one leaf or limb in the band outside it
is enough. (Up to and including the banyan's round 2 this script used the spec's band, 0.25-1.9 m, and counted
whole triangles; the game measures over 0.15-2.2 m and cuts faces at those heights.)
"""
import sys
import band

args = sys.argv[1:]
fp = [-2.6, -2.55, 2.6, 2.55]
if '--footprint' in args:
    i = args.index('--footprint'); fp = [float(v) for v in args[i + 1].split(',')]; del args[i:i + 2]
bad = False
for path in args:
    box, per = band.band_box(path)
    print('/'.join(path.split('/')[-2:]))
    for name, b in per.items():
        print(f"   {name:10s} " + ("nothing in the band" if b is None else f"x {b[0]:.2f}..{b[2]:.2f}  z {b[1]:.2f}..{b[3]:.2f}"))
    if box is None:
        continue
    over = max(fp[0] - box[0], fp[1] - box[1], box[2] - fp[2], box[3] - fp[3])
    sx, sz = (fp[2] - fp[0]) / (box[2] - box[0]), (fp[3] - fp[1]) / (box[3] - box[1])
    print(f"   whole      x {box[0]:.2f}..{box[2]:.2f}  z {box[1]:.2f}..{box[3]:.2f}: "
          + (f"reaches {over:.2f} m outside the footprint; filled to it, the piece is scaled {sx:.2f} by {sz:.2f}" if over > 0.03
             else f"within the footprint; filled to it, the piece is scaled {sx:.3f} by {sz:.3f} (the grid adds a little)"))
    bad = bad or over > 0.03
sys.exit(1 if bad else 0)
