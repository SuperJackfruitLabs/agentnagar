"""Pass 2, voxel: the pack's `tree_large.glb` written by the voxel kit's own
grid and GLB writer (plain Python, no Blender), from the blocks a generated
tree fills.

    python3 build_voxel.py PARTS_DIR NAME OUT.glb

Kept from the kit: the 0.1 m voxel grid, the palette, greedy meshing, the root
skirt that fills the great tree's square, the way canopy blocks are shaded
(lighter on top and toward the sun, darker underneath, a stable hash for the
rest) and the 0.7 m canopy block.
Taken from the generated model: which blocks are trunk and limbs (0.2 m) and
which are leaves (0.7 m).
Touch-ups: leaf blocks kept above the walking band; wood kept inside the
tree's square where people walk.
"""
import json
import os
import sys
from pathlib import Path

parts, name, out = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles" / "voxel"
sys.path.insert(0, str(KIT))
import palette  # noqa: E402
import props  # noqa: E402
import voxel  # noqa: E402
from shapes import new  # noqa: E402
from voxel import Asset, unit  # noqa: E402

occ = json.loads((parts / f"{name}-blocks.json").read_text())
W, L = round(occ["wood_step"] / voxel.VOXEL), round(occ["leaf_step"] / voxel.VOXEL)   # 2 and 7 cells
SEED = "tree_large"
BAND = (0.25, 1.9)                      # metres: where people walk
HALF = props.ROOT_HALF                  # the great tree's square, half a side in cells

g = new()
wood = {tuple(b) for b in occ["wood"]}
# How wide the trunk stands at the ground, for the kit's root skirt.
foot = [max(abs(i * W), abs(i * W + W), abs(k * W), abs(k * W + W)) for (i, j, k) in wood if j * W < 6]
trunk_half = max(4, min(12, sorted(foot)[len(foot) // 2] if foot else 4))
props._root_skirt(g, HALF, trunk_half, SEED)

kept = 0
for (i, j, k) in sorted(wood):
    lo, hi = j * W * voxel.VOXEL, (j * W + W) * voxel.VOXEL
    in_band = hi > BAND[0] and lo < BAND[1]
    reach = max(abs(i * W), abs(i * W + W), abs(k * W), abs(k * W + W))
    if in_band and reach > HALF:
        continue   # would stand in people's way outside the tree's square
    key = "trunk_dark" if (i + k + j // 2) % 5 == 0 else "trunk"
    g.box(i * W, j * W, k * W, i * W + W, j * W + W, k * W + W, key)
    kept += 1

# The sheets' voxel tree shows a third of its trunk under a round crown: the
# crown starts at 3.5 m, which also keeps every leaf block well above the band.
leaf = {tuple(b) for b in occ["leaf"] if b[1] * L * voxel.VOXEL >= 3.5}
top = max(j for _, j, _ in leaf)
bottom = min(j for _, j, _ in leaf)
dark, mid, light = props.GREENS
for (i, j, k) in sorted(leaf):
    exposed_up = (i, j + 1, k) not in leaf
    h = (j - bottom) / max(1, top - bottom)
    u = unit(SEED, "shade", i, j, k)
    if not exposed_up and (i, j - 1, k) not in leaf:
        key = dark
    elif exposed_up and h > 0.35 and u < 0.75:
        key = light
    elif h < 0.35 and u < 0.6:
        key = dark
    elif u < 0.2:
        key = dark
    elif u > 0.85:
        key = light
    else:
        key = mid
    g.box(i * L, j * L, k * L, i * L + L, j * L + L, k * L + L, key)

a = Asset("tree_large")
a.part("tree", g)
meshes = a.meshes()
data = voxel.glb_bytes("tree_large", meshes, palette.PALETTE, palette.PROPS)
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(data)
tris = sum(voxel.triangles(part[1]) for part in meshes)
print(f"BUILD voxel: wrote {out} ({tris} triangles, {kept} wood blocks of {len(wood)}, {len(leaf)} leaf blocks, "
      f"trunk half {trunk_half} cells)")
