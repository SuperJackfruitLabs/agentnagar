"""Blender pass 2, low-poly tropical: the pack's `tree_banyan.glb` built from a
generated tree, using the low-poly kit's own helpers so the result follows the
pack's conventions (palette materials, node names, flat facets).

    blender --background --factory-startup --python build_lowpoly.py -- PARTS_DIR NAME OUT.glb

Kept from the kit: the stone planter ring with its lawn, the surface roots that
fill the great tree's square, the paper lanterns and the painted leaf tones.
Taken from the generated model: the trunk and limbs, and the crown's shape.
Touch-ups: leaves lifted clear of the walking band, the crown's open top
capped with leaf lobes, undersides of the wood darkened.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
parts, name, out = Path(argv[0]), argv[1], Path(argv[2])
KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(KIT / "shared"))
sys.path.insert(0, str(KIT / "lowpoly"))
import lib  # noqa: E402
import vegetation as veg  # noqa: E402
from lib import Mesh  # noqa: E402

wood = json.loads((parts / f"{name}-wood.json").read_text())
leaf = json.loads((parts / f"{name}-leaf.json").read_text())
lobes = json.loads((parts / f"{name}-lobes.json").read_text())

lib.reset()
rng = random.Random(11)
body, canopy, lanterns = Mesh(), Mesh(), Mesh()

# ---- Planter ring and lawn, as the kit's banyan has them ----
seg = 18
ro, ri, h = 2.0, 1.62, 0.48
verts, faces = [], []
for k in range(seg):
    a = 2 * math.pi * k / seg
    c, s = math.cos(a), math.sin(a)
    verts += [(ro * c, ro * s, 0), (ro * c, ro * s, h), (ri * c, ri * s, h), (ri * c, ri * s, 0.3)]
for k in range(seg):
    a, b = 4 * k, 4 * ((k + 1) % seg)
    faces.append((a, b, b + 1, a + 1))
    faces.append((a + 2, b + 2, b + 3, a + 3))
veg.add(body, verts, faces, "limewash_shade")
verts, faces = [], []
for k in range(seg):
    a = 2 * math.pi * k / seg
    c, s = math.cos(a), math.sin(a)
    verts += [((ro + 0.06) * c, (ro + 0.06) * s, h), ((ro + 0.06) * c, (ro + 0.06) * s, h + 0.09),
              ((ri - 0.04) * c, (ri - 0.04) * s, h + 0.09), ((ri - 0.04) * c, (ri - 0.04) * s, h)]
for k in range(seg):
    a, b = 4 * k, 4 * ((k + 1) % seg)
    faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2), (a + 2, b + 2, b + 3, a + 3)]
veg.add(body, verts, faces, "sandstone")
body.cylinder(ri, 0.1, (0, 0, 0.36), "grass_dark", sides=seg)
for k in range(9):
    a = 2 * math.pi * (k + 0.5) / 9
    rr = 1.3 + 0.12 * (k % 2)
    veg.lobe(body, 0.3, (rr * math.cos(a), rr * math.sin(a), 0.5), (1.2, 1.2, 0.8), seed=k, sub=1, jitter=0.25)

# ---- Trunk and limbs: the generated wood ----
start = veg.mark(body)
veg.add(body, wood["verts"], wood["faces"], "wood")
body.bm.faces.ensure_lookup_table()
dark = body.slot("wood_dark")
for f in list(body.bm.faces)[start:]:
    f.normal_update()
    # Undersides and a scatter of facets in the darker bark.
    if f.normal.z < -0.35 or rng.random() < 0.12:
        f.material_index = dark
veg.square_roots(body, ro + 0.06, 2.53, "wood")

# ---- Aerial roots: props dropping from the generated limbs into the planter ----
drops = json.loads((parts / f"{name}-drops.json").read_text())
for k, (x, y, z) in enumerate(drops):
    d = Vector((x, y, 0)).normalized()
    foot = d * (1.25 + 0.2 * (k % 2)) + Vector((0, 0, 0.42))
    top = Vector((x, y, z))
    mid = top.lerp(foot, 0.5) + Vector((0.05 * (k % 3 - 1), 0.04, 0))
    veg.tube(body, [top, mid, foot], [0.07, 0.08, 0.11], "wood_dark", sides=4)

# ---- Crown: faceted leaf lobes where the generated crown has its masses ----
LIFT = 2.3   # nothing leafy hangs into the walking band (0.25 to 1.9 m)
lv = [[x, y, max(z, LIFT)] for x, y, z in leaf["verts"]]
SURFACE = "--surface" in argv   # the generated surface itself, faceted, instead of lobes
if SURFACE:
    start = veg.mark(canopy)
    veg.add(canopy, lv, leaf["faces"], "leaf")
    veg.paint(canopy, start, seed=11)
else:
    REACH, FULL = 1.1, 1.15   # lobe centres sit inside the crown: push them out and fill them out a little
    for k, (centre, radii) in enumerate(lobes):
        rx, ry, rz = radii[0] * FULL, radii[1] * FULL, radii[2] * FULL
        r = (rx + ry) / 2
        # A lobe's lowest facet (0.85 squash, 0.2 jitter) must clear the walking band's 1.9 m.
        z = max(centre[2], 2.05 + 0.85 * rz * 1.22)
        veg.lobe(canopy, r, (centre[0] * REACH, centre[1] * REACH, z), (rx / r, ry / r, 0.85 * rz / r),
                 seed=100 + k, jitter=0.2, sub=2 if r > 1.25 else 1)
# The generator saw the tree from one side and left the crown open on top:
# cap it with lobes over the trunk's axis, at the crown's own height.
top = max(v[2] for v in lv)
cx = sum(v[0] for v in lv) / len(lv)
cy = sum(v[1] for v in lv) / len(lv)
for k, (dx, dy, dz, r) in enumerate(((0.0, 0.0, -0.75, 1.9), (1.3, 0.6, -1.0, 1.5), (-1.2, 0.9, -1.05, 1.5),
                                     (0.2, -1.4, -1.0, 1.45))):
    veg.lobe(canopy, r, (cx * 0.4 + dx, cy * 0.4 + dy, top + dz), (1.3, 1.3, 0.62), seed=300 + k, bias=0.1,
             jitter=0.2)

# ---- Paper lanterns on cords beneath the crown, clear of people's heads ----
hang = [lobe for lobe in lobes if 1.6 < math.hypot(lobe[0][0], lobe[0][1]) < 4.8]
hang.sort(key=lambda lobe: math.atan2(lobe[0][1], lobe[0][0]))
for k, (centre, radii) in enumerate(hang[:11]):
    x, y = centre[0] * 0.85, centre[1] * 0.85
    z = max(2.75, min(3.5, centre[2] - radii[2] - 0.9)) + 0.18 * (k % 3)
    veg._lantern(lanterns, (x, y, z))
    body.beam((x, y, z + 0.26), (x, y, max(z + 0.6, centre[2] - 0.3)), 0.025, "wood_dark")

veg.finish("tree_banyan", {"body": body, "canopy": canopy, "lanterns": lanterns})
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
print(f"BUILD lowpoly: wrote {out} ({lib.triangles()} triangles, {len(hang[:11])} lanterns)")
