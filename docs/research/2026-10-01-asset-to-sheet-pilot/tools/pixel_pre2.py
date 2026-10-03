"""Round 2, pixel art. Runs before the pixel kit's render.py in the same Blender
session:

    PARTS=DIR NAME=lowpoly_tropical [PARAMS=FILE.json] blender --background --factory-startup \
        --python-exit-code 1 --python pixel_pre2.py --python city/tools/styles/pixel/render.py -- RAW_DIR tree_square

It swaps the model behind the great tree's sprite (`tree_square`), as round 1
did, and leaves the rest of the kit (camera, squash, passes, the 32-colour
palette, outline, dither, night twin) exactly as it is.

Round 1 drew the crown as the kit does, in round leaf clusters, on the
generated trunk. The sheet draws it as many small lobed clumps, each bright in
the middle and dark at its edge, with dark gaps between. This build draws it
that way:

  * each clump is a domed pad with a lobed outline (the kit shades leaves
    smoothly, so a pad comes out light in the middle and darker toward its
    rim), most with a smaller, lighter pad laid over them;
  * the pads stand a little apart over a smaller dark core, so the core's
    darkest palette colours show between them;
  * how light a pad is follows where it sits on the crown toward the light and
    a little chance, ranked so the shares of the palette's greens come near the
    sheet's.

Taken from the generated model: the trunk and limbs, and where the crown is.
The palette is the kit's: three greens and the outline colour.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

from mathutils import Vector

KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(KIT / "pixel"))
sys.path.insert(0, str(KIT / "lowpoly"))
import models  # noqa: E402

parts, name = Path(os.environ["PARTS"]), os.environ["NAME"]
P = {"cell": 0.9, "radius": [0.45, 0.72], "layered": 0.75, "core": 0.84, "base_var": [70, 225], "cap_var": [200, 255],
     "lift": 5.0, "draw_in": 0.74, "stretch": 1.04, "dome": 0.5, "under": 0.3}
if os.environ.get("PARAMS") and Path(os.environ["PARAMS"]).exists():
    P.update(json.loads(Path(os.environ["PARAMS"]).read_text()))
wood = json.loads((parts / f"{name}-wood.json").read_text())
leaf = json.loads((parts / f"{name}-leaf.json").read_text())
report = json.loads((parts / f"{name}-report.json").read_text())
# The isometric camera looks down at 30 degrees. A crown 6 m out that hangs to
# 2.3 m hides its own trunk, and the sprite reads as a green mass. So for this
# style the crown's skirt is lifted and drawn in a little, which shows the
# trunk and the limbs spreading under it (as round 1).
LIFT, DRAW_IN, STRETCH = P["lift"], P["draw_in"], P["stretch"]
SUN = Vector((-0.42, -0.62, 1.0)).normalized()     # post.py's light, Blender axes


def pad(mesh, centre, normal, r, mat, seed, lobes=5):
    """A leaf clump: a domed pad with a lobed outline, its faces sharing their
    corners so the kit's smooth shading runs from its middle to its rim."""
    rr = random.Random(seed)
    n = normal.normalized()
    u = n.orthogonal().normalized()
    v = n.cross(u)
    spin = rr.uniform(0.0, 2 * math.pi)
    count = lobes * 2
    rim = []
    for i in range(count):
        a = spin + 2 * math.pi * (i + rr.uniform(-0.2, 0.2)) / count
        tip = i % 2 == 0
        rad = r * (rr.uniform(0.95, 1.15) if tip else rr.uniform(0.6, 0.76))
        rim.append(centre + u * (rad * math.cos(a)) + v * (rad * math.sin(a)) - n * (r * rr.uniform(0.0, 0.12) if tip else 0.0))
    # The top in the leaf greens; the underside in the kit's dark leaf material, whose
    # shade runs down to the outline colour, as the sheet's gaps do.
    mesh._faces([tuple(p) for p in [centre + n * (P["dome"] * r)] + rim],
                [(0, 1 + i, 1 + (i + 1) % count) for i in range(count)], mat)
    mesh._faces([tuple(p) for p in [centre - n * (P["under"] * r)] + rim],
                [(0, 1 + (i + 1) % count, 1 + i) for i in range(count)], "leaf_dark")


def build():
    m = models.Model()
    mesh = m.m   # the low-poly kit's Mesh; its coordinates are Blender's, as the parts are

    def limb(x, y, z):
        # Limbs are drawn in with the crown, so none reaches out bare beyond it;
        # the trunk itself (within 1.5 m of its axis) keeps its girth.
        r = math.hypot(x, y)
        f = 1.0 if r < 1.5 else (DRAW_IN - 0.06 if r > 3.0 else 1.0 + (DRAW_IN - 0.06 - 1.0) * (r - 1.5) / 1.5)
        return [x * f, y * f, z * STRETCH]
    mesh._faces([limb(x, y, z) for x, y, z in wood["verts"]], wood["faces"], "trunk")
    cx, cy, cz = report["crown_centre"]
    hx, hy, hz = report["crown_half"]
    cz *= STRETCH
    hz *= STRETCH
    lv = [[cx + (x - cx) * DRAW_IN, cy + (y - cy) * DRAW_IN, max(z * STRETCH, LIFT)] for x, y, z in leaf["verts"]]
    # A dark core, smaller than round 1's, so it shows between the clumps.
    k_ = P["core"]
    mesh._faces([[cx + (x - cx) * k_, cy + (y - cy) * k_, cz + (z - cz) * k_] for x, y, z in lv], leaf["faces"], "leaf_dark")
    rng = random.Random(78)
    seen, spots = set(), []
    for x, y, z in lv:
        key = (round(x / P["cell"]), round(y / P["cell"]), round(z / P["cell"]))
        if key not in seen:
            seen.add(key)
            spots.append(Vector((x, y, z)))
    # The open top the generator left: clumps over the trunk's axis.
    top = max(z for _, _, z in lv)
    for k in range(13):
        a = 2 * math.pi * k / 6
        r = 0.0 if k == 0 else (1.2 if k < 7 else 2.3)
        spots.append(Vector((cx * 0.4 + r * math.cos(a + 0.3 * (k > 6)), cy * 0.4 + r * math.sin(a + 0.3 * (k > 6)),
                             top - 0.4 - 0.3 * (r > 1.5))))
    low = min(s.z for s in spots)
    # How light each clump is: where it sits on the crown toward the light, and chance;
    # ranked, so the palette's greens come in the sheet's shares.
    score = []
    for s in spots:
        d = Vector(((s.x - cx) / hx, (s.y - cy) / hy, (s.z - cz) / hz))
        d = d.normalized() if d.length > 1e-6 else Vector((0, 0, 1))
        score.append(0.6 * d.dot(SUN) + 0.4 * rng.uniform(-1.0, 1.0))
    order = sorted(range(len(spots)), key=lambda i: score[i])
    rank = {i: r / max(1, len(order) - 1) for r, i in enumerate(order)}
    pads = 0
    for k, s in enumerate(spots):
        r = rng.uniform(*P["radius"])
        rim = math.hypot((s.x - cx) / (hx * DRAW_IN), (s.y - cy) / (hy * DRAW_IN))
        hf = (s.z - low) / max(0.1, top - low)
        lean = math.radians((55.0 - 45.0 * hf) * min(1.0, rim * 1.5) + rng.uniform(-10.0, 10.0))
        outward = Vector((s.x - cx, s.y - cy, 0.0))
        outward = outward.normalized() if outward.length > 0.05 else Vector((1.0, 0.0, 0.0))
        side = Vector((-outward.y, outward.x, 0.0))
        normal = Vector((0, 0, 1)) * math.cos(lean) + outward * math.sin(lean) + side * rng.uniform(-0.15, 0.15)
        var = P["base_var"][0] + (P["base_var"][1] - P["base_var"][0]) * rank[k]
        pad(mesh, s, normal, r, models.mv("leaf", var), 900 + k, lobes=5 + k % 2)
        pads += 1
        if rng.random() < P["layered"]:
            up = normal.normalized()
            at = s + up * (0.45 * r) + (outward * rng.uniform(-0.3, 0.3) + side * rng.uniform(-0.3, 0.3)) * r
            cap = P["cap_var"][0] + (P["cap_var"][1] - P["cap_var"][0]) * rank[k]
            pad(mesh, at, normal + side * rng.uniform(-0.2, 0.2), r * rng.uniform(0.5, 0.66), models.mv("leaf", cap), 5000 + k)
            pads += 1
    print(f"PIXEL model 2: {len(wood['faces'])} wood faces, {len(spots)} clumps, {pads} pads")
    return m.build("tree_square")


for spec in models.KIT:
    if spec["name"] == "tree_square":
        spec["build"] = build
