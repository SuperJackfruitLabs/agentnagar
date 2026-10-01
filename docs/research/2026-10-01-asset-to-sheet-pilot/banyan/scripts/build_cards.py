"""Blender pass 2 for the leaf-card kits (anime, solarpunk, neon): the pack's
`tree_banyan.glb` built by the kit's own banyan builder, with three things
swapped for a generated tree's:

  * the trunk and limbs (the kit's tubes are skipped; the generated wood is
    added in the kit's bark colours);
  * the crown's layout (leaf-card lobes stand where the generated crown has
    its masses, instead of the kit's ring of five);
  * the crown's fit (left at the generated tree's own size).

Everything else is the kit's: the planter ring and its bed, the surface roots
that fill the tree's square, the leaf cards and their soft normals, the lights.

    blender --background --factory-startup --python build_cards.py -- KIT PARTS_DIR NAME OUT.glb

KIT is anime, solarpunk or neon.
"""
import json
import math
import os
import sys
from pathlib import Path

from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
kit, parts, name, out = argv[0], Path(argv[1]), argv[2], Path(argv[3])
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / kit))
import lib  # noqa: E402  (this kit's palette and exporter)
import vegetation as veg  # noqa: E402
import foliage  # noqa: E402

wood = json.loads((parts / f"{name}-wood.json").read_text())
lobes = json.loads((parts / f"{name}-lobes.json").read_text())
drops = json.loads((parts / f"{name}-drops.json").read_text())
report = json.loads((parts / f"{name}-report.json").read_text())

LIFT = 2.3   # leaves stay clear of the walking band (0.25 to 1.9 m)
crown_lobes = []
REACH, FULL = 1.1, 1.15   # lobe centres sit inside the crown: push them out and fill them out a little
for centre, radii in lobes:
    rx, ry, rz = max(radii[0] * FULL, 1.0), max(radii[1] * FULL, 1.0), max(radii[2] * FULL, 0.8)
    # Leaf cards reach about 0.45 m past their lobe and must clear the walking band's 1.9 m.
    z = max(centre[2], 2.05 + rz + 0.5)
    crown_lobes.append(((centre[0] * REACH, centre[1] * REACH, z), (rx, ry, rz)))
# The generator leaves the crown open on top: cap it over the trunk's axis.
top = max(c[2] + r[2] for c, r in crown_lobes)
cc = report["crown_centre"]
for dx, dy, dz, r in ((0.0, 0.0, -1.0, 1.9), (1.3, 0.6, -1.25, 1.6), (-1.2, 0.9, -1.3, 1.6), (0.2, -1.4, -1.25, 1.5)):
    crown_lobes.append(((cc[0] * 0.4 + dx, cc[1] * 0.4 + dy, top + dz), (r, r, r * 0.68)))
half = report["crown_half"]
whole = ((cc[0], cc[1], cc[2]), (half[0] + 0.3, half[1] + 0.3, half[2] + 0.5))

# Where the kit's helpers really live: the anime kit's vegetation module, which
# solarpunk and neon load by path under their own names.
A = next((m for k, m in sys.modules.items() if k.endswith("anime_vegetation")), veg)
real_tube, real_fit, real_finish, real_crown = A.tube, A.fit, veg.finish, foliage.crown
real_roots = A.square_roots
state = {"skip": True, "added": False}


def tube(m, pts, radii, mat, *a, **kw):
    """The kit's own trunk, limbs and aerial roots are left out."""
    if state["skip"]:
        return None
    return real_tube(m, pts, radii, mat, *a, **kw)


def square_roots(m, ring, half_, mat, *a, **kw):
    state["skip"] = False
    try:
        return real_roots(m, ring, half_, mat, *a, **kw)
    finally:
        state["skip"] = True


def crown(m, its_lobes, card, seed, *a, **kw):
    if card >= 1.0:   # the great crown (the planter's bed uses small cards)
        kw["whole"] = whole
        return real_crown(m, crown_lobes, card, seed, *a, **kw)
    return real_crown(m, its_lobes, card, seed, *a, **kw)


def fit(m, first, width, depth, *a, **kw):
    if width > 10:   # the crown: keep the generated tree's own size
        return None
    return real_fit(m, first, width, depth, *a, **kw)


def finish(asset, meshes, *a, **kw):
    body = meshes["body"]
    if not state["added"]:
        state["added"] = True
        start = A.mark(body)
        A.add(body, wood["verts"], wood["faces"], "trunk_light")
        body.bm.faces.ensure_lookup_table()
        shade = body.slot("trunk")
        for f in list(body.bm.faces)[start:]:
            f.normal_update()
            if f.normal.z < -0.3:
                f.material_index = shade
        state["skip"] = False
        for k, (x, y, z) in enumerate(drops):
            d = Vector((x, y, 0)).normalized()
            foot = d * (1.3 + 0.2 * (k % 2)) + Vector((0, 0, 0.36))
            topv = Vector((x, y, z))
            real_tube(body, [topv, topv.lerp(foot, 0.5) + d * 0.05, foot], [0.07, 0.06, 0.09], "trunk", sides=5)
        state["skip"] = True
    return real_finish(asset, meshes, *a, **kw)


# The kit's builder looks these names up in its own module (and the anime
# kit's helpers in theirs), so swap them in both places.
for mod in {veg, A}:
    if hasattr(mod, "tube"):
        mod.tube = tube
    if hasattr(mod, "fit"):
        mod.fit = fit
    if hasattr(mod, "square_roots"):
        mod.square_roots = square_roots
veg.finish = finish
foliage.crown = crown

sys.modules["lib"] = lib
lib.reset()
veg.tree_banyan()
import bake  # noqa: E402  (tools/styles/shared: palette colours into vertex colours, as the kit's build does)
bake.bake_scene()
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
print(f"BUILD {kit}: wrote {out} ({lib.triangles()} triangles, {len(crown_lobes)} lobes, {len(drops)} aerial roots)")
