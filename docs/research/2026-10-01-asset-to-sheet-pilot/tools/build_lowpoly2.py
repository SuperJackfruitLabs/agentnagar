"""Round 2, low-poly tropical: the same generated tree as round 1, with the
surface, colour and shading reworked.

    blender --background --factory-startup --python build_lowpoly2.py -- PARTS_DIR NAME OUT.glb [PARAMS.json]

Round 1 changed the shape only. This build changes what round 1 left alone:

  * the crown is some three hundred lobed leaf plates, most with a smaller
    lighter plate laid over them, on a dark core, as the sheet draws its
    clumps; round 1 had 26 large lobes and the kit has 17;
  * leaves and bark are painted from the concept sheet's own colours
    (ramps.json), not the kit's four palette greens, and the game's light is
    partly taken back out of them (shade.py);
  * faces that see little sky are darkened;
  * the planter's lawn carries blossoms.

The kit's planter ring, surface roots, lanterns and node names stay.
"""
import json
import os
import math
import random
import sys
from pathlib import Path

import numpy as np
from mathutils import Vector
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:]
parts, name, out = Path(argv[0]), argv[1], Path(argv[2])
HERE = Path(__file__).resolve().parent
P = {"clusters": 300, "gain_leaf": 1.0, "gain_wood": 1.0, "take_out": 0.75, "floor": 0.55,
     "ambient": ["#D6E2EA", 0.55], "sun": ["#FFE7C4", 1.2], "e_ref": 0.8, "ao_share": 0.25, "weights": {}, "channel": {}, "curve": {}, "class_gain": {}, "stop_gain": {},
     "core": [0.0, 0.2, 0.5], "wider": 1.1, "layered": 0.7, "blossoms": 34, "painted": [-0.2, -0.3, 0.93]}
if len(argv) > 3:
    P.update(json.loads(Path(argv[3]).read_text()))
KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(KIT / "shared"))
sys.path.insert(0, str(KIT / "lowpoly"))
import lib  # noqa: E402
import vegetation as veg  # noqa: E402
from lib import Mesh  # noqa: E402
import bake  # noqa: E402
import shade  # noqa: E402

load = lambda suffix: json.loads((parts / f"{name}-{suffix}.json").read_text())  # noqa: E731
wood, core, lobes, drops, colours, report = (load(s) for s in ("wood", "leaf-core", "lobes", "drops", "colours", "report"))
ramps = json.loads((HERE / "ramps.json").read_text())["lowpoly_tropical"]

lib.reset()
rng = random.Random(11)
body, canopy, lanterns = Mesh(), Mesh(), Mesh()
paint = {"body": [], "canopy": []}      # one entry per face, in the order the faces are added


def fill(m, key, entry=None):
    """Entries for the faces added to `m` since the list was last filled."""
    paint[key] += [entry] * (veg.mark(m) - len(paint[key]))


def local_variation(kind, k_near, k_wide):
    """For each sample of the generated model's colour: how much lighter (+) or
    darker (-) it is than the model round it, -1..1. The model's own broad
    light and dark (its lit side and its shaded side) drops out; what is left
    is its local detail."""
    pts = colours[kind]["points"]
    cols = np.asarray(colours[kind]["colours"], dtype=np.float64)
    lum = np.log(np.maximum(1e-4, 0.2126 * cols[:, 0] + 0.7152 * cols[:, 1] + 0.0722 * cols[:, 2]))
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(Vector(p), i)
    kd.balance()

    def at(p):
        near = [i for _c, i, _d in kd.find_n(Vector(p), k_near)]
        wide = [i for _c, i, _d in kd.find_n(Vector(p), k_wide)]
        return float(max(-1.0, min(1.0, (lum[near].mean() - lum[wide].mean()) / 0.3)))
    return at


leaf_var = local_variation("leaf", 10, 300)
wood_var = local_variation("wood", 6, 120)

# ---- Planter ring and lawn, as the kit's banyan has them, with blossoms ----
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
for k in range(16):
    a = 2 * math.pi * (k + 0.2) / 16 + rng.uniform(-0.1, 0.1)
    rr = 1.42 + rng.uniform(-0.12, 0.1)
    veg.flower(body, (rr * math.cos(a), rr * math.sin(a), 0.6 + rng.uniform(-0.03, 0.05)),
               ("pink", "jackfruit", "coral", "cream")[k % 4], r=0.085, seed=600 + k)
fill(body, "body")

# ---- Trunk and limbs: the generated wood, painted from the sheet's bark ----
start = veg.mark(body)
veg.add(body, wood["verts"], wood["faces"], "wood")
body.bm.faces.ensure_lookup_table()
for f in list(body.bm.faces)[start:]:
    c = f.calc_center_median()
    limb = (round(c.z / 0.9), round(math.atan2(c.y, c.x) / 0.7))
    paint["body"].append(("wood", limb, wood_var(c), 0.0, 1.0, 1.0))
veg.square_roots(body, ro + 0.06, 2.53, "wood")
fill(body, "body", ("wood", "roots", 0.0, 0.1, 0.8, 1.0))
for k, (x, y, z) in enumerate(drops):
    d = Vector((x, y, 0)).normalized()
    foot = d * (1.25 + 0.2 * (k % 2)) + Vector((0, 0, 0.42))
    top = Vector((x, y, z))
    veg.tube(body, [top, top.lerp(foot, 0.5) + Vector((0.05 * (k % 3 - 1), 0.04, 0)), foot], [0.07, 0.08, 0.11],
             "wood_dark", sides=4)
    fill(body, "body", ("wood", ("drop", k), 0.0, 0.0, 0.55, 1.0))

# ---- Crown: a dark core, then many small faceted clusters over the generated crown ----
cx, cy, cz = report["crown_centre"]
hx, hy, hz = report["crown_half"]
FLOOR = 2.05          # nothing leafy below this: the walking band ends at 1.9 m
pts = colours["leaf"]["points"]

core_v = [[cx + (x - cx) * 0.82 * P["wider"], cy + (y - cy) * 0.82 * P["wider"], max(cz + (z - cz) * 0.8, FLOOR + 0.35)]
          for x, y, z in core["verts"]]
veg.add(canopy, core_v, core["faces"], "leaf_dark")
# The inside of the crown: the ramp's darkest colours, and left dark.
fill(canopy, "canopy", ("leaf", "core", 0.0, P["core"][0], P["core"][1], P["core"][2]))


def spread(points, cell):
    seen, picked = set(), []
    for x, y, z in points:
        key = (round(x / cell), round(y / cell), round(z / cell))
        if key not in seen:
            seen.add(key)
            picked.append((x, y, z))
    return picked


# Pick the cell size that gives about the number of clusters asked for.
lo_c, hi_c = 0.4, 2.5
for _ in range(18):
    mid = (lo_c + hi_c) / 2
    if len(spread(pts, mid)) > P["clusters"]:
        lo_c = mid
    else:
        hi_c = mid
spots = [Vector(p).lerp(Vector((cx, cy, cz)), 0.04) for p in spread(pts, hi_c)]
# The generator saw the tree from the side and left the crown thin on top: fill
# every gap seen from above, so the crown is whole from the city-builder camera.
reach = {}
for x, y, _z in pts:
    b = round(math.degrees(math.atan2(y - cy, x - cx)) / 20.0)
    reach.setdefault(b, []).append(math.hypot(x - cx, y - cy))
reach = {b: float(np.percentile(v, 92)) for b, v in reach.items()}
step = hi_c * 0.8
added = 0
nx, ny = int(hx / step) + 2, int(hy / step) + 2
for i in range(-nx, nx + 1):
    for j in range(-ny, ny + 1):
        x = cx + (i + 0.5 * (j % 2)) * step
        y = cy + j * step
        b = round(math.degrees(math.atan2(y - cy, x - cx)) / 20.0)
        if math.hypot(x - cx, y - cy) > 0.9 * reach.get(b, 0.0):
            continue
        near = sorted(spots, key=lambda s: (s.x - x) ** 2 + (s.y - y) ** 2)[:6]
        above = [s for s in near if math.hypot(s.x - x, s.y - y) < step * 0.75 and s.z > cz]
        if above:
            continue
        z = max(s.z for s in near) + rng.uniform(-0.15, 0.2)
        spots.append(Vector((x + rng.uniform(-0.2, 0.2), y + rng.uniform(-0.2, 0.2), z)))
        added += 1
def plate(m, centre, normal, r, seed, lobes=5, dome=0.4, under=0.3):
    """A leaf clump as the sheet draws them: a domed pad with a lobed outline.
    4 x `lobes` triangles."""
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
        rad = r * (rr.uniform(0.94, 1.12) if tip else rr.uniform(0.68, 0.82))
        rim.append(centre + u * (rad * math.cos(a)) + v * (rad * math.sin(a)) - n * (r * rr.uniform(0.0, 0.12) if tip else 0.0))
    verts = [centre + n * (dome * r)] + rim + [centre - n * (under * r)]
    faces = [(0, 1 + i, 1 + (i + 1) % count) for i in range(count)]
    faces += [(count + 1, 1 + (i + 1) % count, 1 + i) for i in range(count)]
    veg.add(m, [tuple(p) for p in verts], faces, "leaf")


top_z = max(s.z for s in spots)
low_z = min(s.z for s in spots)
blossoms = []
for k, p in enumerate(spots):
    # The crown a little wider than the generator made it, as round 1 and the kit have it.
    p.x, p.y = cx + (p.x - cx) * P["wider"], cy + (p.y - cy) * P["wider"]
    r = rng.uniform(0.62, 1.05)
    rim = math.hypot((p.x - cx) / hx, (p.y - cy) / hy)
    if rim > 0.85:
        r *= 0.88          # smaller at the rim, as the sheet's outline breaks into small clumps
    # Plates lean outward, more so low on the crown, so the street sees their lit tops.
    hf = (p.z - low_z) / max(0.1, top_z - low_z)
    lean = math.radians((62.0 - 52.0 * hf) * min(1.0, rim * 1.6) + rng.uniform(-10.0, 10.0))
    outward = Vector((p.x - cx, p.y - cy, 0.0))
    outward = outward.normalized() if outward.length > 0.05 else Vector((1.0, 0.0, 0.0))
    side = Vector((-outward.y, outward.x, 0.0))
    normal = Vector((0, 0, 1)) * math.cos(lean) + outward * math.sin(lean) + side * rng.uniform(-0.15, 0.15)
    p.z = max(p.z, FLOOR + r * (abs(math.sin(lean)) * 1.2 + 0.4))
    var = leaf_var(p)
    plate(canopy, p, normal, r, 900 + k, lobes=5 + k % 2)
    fill(canopy, "canopy", ("leaf", k, var - 0.15, 0.0, 1.0, 1.0))
    # A smaller, lighter plate laid over it, off to one side: the sheet's clumps are layered.
    if rng.random() < P["layered"]:
        up = normal.normalized()
        q2 = p + up * (0.42 * r) + (outward * rng.uniform(-0.3, 0.3) + side * rng.uniform(-0.3, 0.3)) * r
        plate(canopy, q2, normal + side * rng.uniform(-0.2, 0.2), r * rng.uniform(0.55, 0.7), 5000 + k)
        fill(canopy, "canopy", ("leaf", ("top", k), min(1.0, var + 0.55), 0.0, 1.0, 1.0))
        if hf > 0.25:
            blossoms.append(q2 + up * (0.3 * r))
# The sheet dots the crown with small pale blossoms.
rng.shuffle(blossoms)
for k, b in enumerate(blossoms[:P["blossoms"]]):
    veg.flower(canopy, tuple(b), "cream", r=0.11, seed=700 + k)
fill(canopy, "canopy")

# ---- Paper lanterns on cords beneath the crown, clear of people's heads ----
hang = [lobe for lobe in lobes if 1.6 < math.hypot(lobe[0][0], lobe[0][1]) < 4.8]
hang.sort(key=lambda lobe: math.atan2(lobe[0][1], lobe[0][0]))
for k, (centre, radii) in enumerate(hang[:11]):
    x, y = centre[0] * 0.85, centre[1] * 0.85
    z = max(2.75, min(3.5, centre[2] - radii[2] - 0.9)) + 0.18 * (k % 3)
    veg._lantern(lanterns, (x, y, z))
    body.beam((x, y, z + 0.26), (x, y, max(z + 0.6, centre[2] - 0.3)), 0.025, "wood_dark")
fill(body, "body")

assert len(paint["body"]) == veg.mark(body) and len(paint["canopy"]) == veg.mark(canopy)
veg.finish("tree_banyan", {"body": body, "canopy": canopy, "lanterns": lanterns})
bake.bake_scene()
light = lambda pair: [c * pair[1] for c in shade.hex_lin(pair[0])]  # noqa: E731
stats = shade.shade_scene(paint=paint, ramps=ramps, floor=P["floor"], ambient=light(P["ambient"]),
                          sun_energy=light(P["sun"]), ao_share=P["ao_share"],
                          take_out=P["take_out"], e_ref=P["e_ref"], weights=P["weights"],
                          gain={"leaf": P["gain_leaf"], "wood": P["gain_wood"]}, channel=P["channel"],
                          curve=P["curve"], class_gain=P["class_gain"], stop_gain=P["stop_gain"],
                          painted=P["painted"])
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
print(f"BUILD lowpoly2: wrote {out} ({lib.triangles()} triangles, {len(spots)} clusters of which {added} fill the top, "
      f"cell {hi_c:.2f} m) {json.dumps(stats)}")
