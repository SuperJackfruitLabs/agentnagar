"""Runs before the pixel kit's render.py in the same Blender session:

    PARTS=DIR NAME=lowpoly_tropical blender --background --factory-startup --python-exit-code 1 \
        --python pixel_pre.py --python city/tools/styles/pixel/render.py -- RAW_DIR tree_square

It swaps the model behind the great tree's sprite (`tree_square`) for one built
from a generated tree, and leaves the rest of the kit (camera, squash, passes,
palette, outline, night twin) exactly as it is.

Taken from the generated model: the trunk and limbs, and where the crown is.
Kept from the kit: its way of drawing a crown (small leaf clusters over a dark
core, each cluster's lightness set by where it sits on the crown toward the
sun), its trunk colour and bark.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(KIT / "pixel"))
sys.path.insert(0, str(KIT / "lowpoly"))
import models  # noqa: E402

parts, name = Path(os.environ["PARTS"]), os.environ["NAME"]
wood = json.loads((parts / f"{name}-wood.json").read_text())
leaf = json.loads((parts / f"{name}-leaf.json").read_text())
report = json.loads((parts / f"{name}-report.json").read_text())
# The isometric camera looks down at 30 degrees. A crown 6 m out that hangs to
# 2.3 m hides its own trunk, and the sprite reads as a green mass. So for this
# style the crown's skirt is lifted and drawn in a little, which shows the
# trunk and the limbs spreading under it.
LIFT = 5.0
DRAW_IN = 0.74
# ... and the whole tree stands a little taller, as the kit's own great tree does.
STRETCH = 1.04


def build():
    m = models.Model()
    mesh = m.m   # the low-poly kit's Mesh; its coordinates are Blender's, as the parts are
    # Trunk and limbs.
    def limb(x, y, z):
        # Limbs are drawn in with the crown, so none reaches out bare beyond it;
        # the trunk itself (within 1.5 m of its axis) keeps its girth.
        r = math.hypot(x, y)
        f = 1.0 if r < 1.5 else (DRAW_IN - 0.06 if r > 3.0 else 1.0 + (DRAW_IN - 0.06 - 1.0) * (r - 1.5) / 1.5)
        return [x * f, y * f, z * STRETCH]
    mesh._faces([limb(x, y, z) for x, y, z in wood["verts"]], wood["faces"], "trunk")
    # Crown: a dark core (the generated crown, drawn in a little), then leaf
    # clusters over its surface.
    cx, cy, cz = report["crown_centre"]
    hx, hy, hz = report["crown_half"]
    cz *= STRETCH
    hz *= STRETCH
    lv = [[cx + (x - cx) * DRAW_IN, cy + (y - cy) * DRAW_IN, max(z * STRETCH, LIFT)] for x, y, z in leaf["verts"]]
    core = [[cx + (x - cx) * 0.9, cy + (y - cy) * 0.9, cz + (z - cz) * 0.9] for x, y, z in lv]
    mesh._faces(core, leaf["faces"], "leaf_dark")
    rng = random.Random(78)
    # Spread clusters evenly: one per cell of a coarse grid over the surface.
    cell, seen, spots = 0.95, set(), []
    for x, y, z in lv:
        key = (round(x / cell), round(y / cell), round(z / cell))
        if key not in seen:
            seen.add(key)
            spots.append((x, y, z))
    # The open top the generator left: a few clusters over the trunk's axis.
    top = max(z for _, _, z in lv)
    for k in range(9):
        a = 2 * math.pi * k / 9
        r = 0.0 if k == 0 else (1.1 if k < 5 else 2.0)
        spots.append((cx * 0.4 + r * math.cos(a), cy * 0.4 + r * math.sin(a), top - 0.5 - 0.25 * (r > 1.5)))
    for k, (x, y, z) in enumerate(spots):
        d = ((x - cx) / hx, (y - cy) / hy, (z - cz) / hz)
        ln = math.sqrt(sum(c * c for c in d)) or 1.0
        d = tuple(c / ln for c in d)
        # As the kit's crown(): the cluster's place toward the sun sets its lightness.
        # (Blender axes here: -y is south, toward the usual camera.)
        lit = (-0.42 * d[0] - 0.62 * d[1] + 1.0 * d[2]) / 1.27
        var = 128 + 127 * max(-1.0, min(0.0, lit - 0.35)) + rng.uniform(-12, 12)
        rr = 0.62 * rng.uniform(0.8, 1.2)
        mesh.sphere(rr, (x, y, z), models.mv("leaf", var), subdivisions=2, scale=(1, 1, 0.85), jitter=0.24,
                    seed=78 * 97 + k)
    print(f"PIXEL model: {len(wood['faces'])} wood faces, {len(spots)} leaf clusters")
    return m.build("tree_square")


for spec in models.KIT:
    if spec["name"] == "tree_square":
        spec["build"] = build
