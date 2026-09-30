"""Vegetation v2 for the low-poly tropical kit: the square's banyan, palms in
three sizes, shrubs, flower beds and planters.

Foliage is faceted: jittered low-subdivision ico-spheres and folded leaf
blades, flat-shaded, each facet painted by the way it faces (dark greens
underneath, mid greens on the flanks, light greens and a little yellow on the
sunlit tops), as the style-11 sheets paint it.

Conventions (shared with props.py): Blender Z-up, pieces face +Y; the origin
is the centre of the footprint on the ground. Each asset is an empty named
after the asset that parents one merged mesh, `body`, plus the parts the pack
switches or animates by name (the banyan's `canopy` and emissive `lanterns`).
"""
import math
import random
import sys
from pathlib import Path

from mathutils import Vector

import lib
from lib import Mesh

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import usables  # noqa: E402  (tools/styles/shared: the meadow's clumps, as every kit draws them)

lib.PALETTE.update({
    "lantern": "#F4A62A",   # paper lanterns: amber that stays yellow when lit
    "palm_bark": "#9A6E48",  # palm trunks (ringed in wood)
})
lib.EMISSIVE.setdefault("lantern", 0.7)

# The side the painted light comes from: high, and toward the viewer of the
# usual diagonal camera (Blender -Y is Godot +Z, the south).
SUN = Vector((0.3, -0.45, 0.84)).normalized()


# ---- Low-level helpers (props.py reuses them) ----

def add(m, verts, faces, mats):
    """Adds raw faces to a Mesh; `mats` is one palette name per face (or one
    name for all)."""
    if isinstance(mats, str):
        mats = [mats] * len(faces)
    vs = [m.bm.verts.new(v) for v in verts]
    for f, mat in zip(faces, mats):
        try:
            nf = m.bm.faces.new([vs[i] for i in f])
        except ValueError:
            continue
        nf.material_index = m.slot(mat)


def mark(m):
    """The index the next faces added to `m` will start at."""
    return len(m.bm.faces)


def paint(m, start, seed=0, yellow=0.14, dark="leaf_dark", mid="leaf", light="leaf_light",
          sun="leaf_yellow", bias=0.0):
    """Repaints the faces added since `start` by how they face: undersides
    dark, flanks mid, tops light with a few sunlit yellow facets."""
    rng = random.Random(seed)
    m.bm.faces.ensure_lookup_table()
    for f in list(m.bm.faces)[start:]:
        f.normal_update()
        lit = 0.5 * f.normal.z + 0.5 * f.normal.dot(SUN) + bias + rng.uniform(-0.15, 0.15)
        if lit < -0.25:
            g = dark
        elif lit < 0.2:
            g = mid if rng.random() > 0.3 else dark
        elif lit < 0.55:
            g = light if rng.random() > 0.65 else mid
        else:
            g = light if rng.random() > 0.45 else mid
        if sun and lit > 0.62 and rng.random() < yellow:
            g = sun
        f.material_index = m.slot(g)


def lobe(m, radius, at, scale=(1, 1, 1), seed=0, sub=2, jitter=0.16, **kw):
    """A faceted foliage lobe painted by facing."""
    s = mark(m)
    m.sphere(radius, at, "leaf", subdivisions=sub, scale=scale, jitter=jitter, seed=seed)
    paint(m, s, seed=seed, **kw)


def _frames(pts):
    """Parallel-transported (tangent, normal, binormal) frames along a polyline."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tans = []
    for i in range(n):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, n - 1)]
        tans.append((b - a).normalized())
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    nor = (ref - tans[0] * ref.dot(tans[0])).normalized()
    out = []
    for t in tans:
        nor = (nor - t * nor.dot(t)).normalized()
        out.append((t, nor, t.cross(nor)))
    return pts, out


def tube(m, pts, radii, mat, sides=6, shape=None, cap_end=True, cap_start=False, twist=0.0,
         mats=None):
    """A faceted tube along `pts` with a radius per point. `shape(k, i)`
    scales ring vertex k of ring i (for buttresses); `mats(i)` names the
    material of segment i."""
    pts, frames = _frames(pts)
    verts, faces, fm = [], [], []
    for i, (p, (t, nor, bi)) in enumerate(zip(pts, frames)):
        for k in range(sides):
            a = 2 * math.pi * k / sides + twist * i
            r = radii[i] * (shape(k, i) if shape else 1.0)
            verts.append(p + (nor * math.cos(a) + bi * math.sin(a)) * r)
    for i in range(len(pts) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
            fm.append(mats(i) if mats else mat)
    last = len(pts) - 1
    if cap_end:
        faces.append(tuple(last * sides + k for k in range(sides)))
        fm.append(mats(last - 1) if mats else mat)
    if cap_start:
        faces.append(tuple(reversed(range(sides))))
        fm.append(mats(0) if mats else mat)
    s = mark(m)
    add(m, verts, faces, fm)
    _outward(m, s, pts)


def _outward(m, start, pts):
    """Turns the faces added since `start` to face away from the polyline."""
    m.bm.faces.ensure_lookup_table()
    for f in list(m.bm.faces)[start:]:
        f.normal_update()
        c = f.calc_center_median()
        best = min(pts, key=lambda p: (p - c).length)
        if f.normal.dot(c - best) < 0:
            f.normal_flip()


def blade(m, base, direction, length, width, droop, fold=0.35, stations=4, serrate=0.0, mat="leaf",
          lift=0.0):
    """A folded leaf blade from `base` along `direction` (xy heading, with
    `lift` as the initial rise), bending down by `droop` at the tip. Its two
    halves fold down from the midrib by `fold`×width; `serrate` notches
    the edge into leaflets (palm fronds)."""
    base = Vector(base)
    d = Vector((direction[0], direction[1], 0)).normalized()
    side = Vector((-d.y, d.x, 0))
    spine = []
    n = stations * (2 if serrate else 1)
    for i in range(n + 1):
        t = i / n
        spine.append(base + d * length * t + Vector((0, 0, lift * length * t - droop * t * t)))
    verts, faces = [], []
    for i, p in enumerate(spine):
        t = i / n
        w = width * math.sin(math.pi * min(t * 1.15, 1.0)) ** 0.8
        if serrate and i % 2 == 1:
            w *= 1 - serrate
        fwd = d * (0.12 * width if serrate and i % 2 == 0 and 0 < i < n else 0)
        drop = Vector((0, 0, -w * fold))
        verts += [p, p + side * w + drop + fwd, p - side * w + drop + fwd]
    for i in range(n):
        a, b = 3 * i, 3 * (i + 1)
        faces.append((a, b, b + 1, a + 1))
        faces.append((a, a + 2, b + 2, b))
    add(m, verts, faces, mat)


def finish(name, parts):
    """An empty named `name` parenting the given {node: Mesh} parts."""
    r = lib.root(name)
    for node, mesh in parts.items():
        mesh.build(node, r)
    return r


# ---- Banyan ----

def square_roots(m, ring, half, mat, step=0.3):
    """Surface roots filling the square round a great tree to its edges
    (`half` m either way of its trunk), where people walk: from under its
    planter ring (`ring` m out) each arches out over the paving, at knee
    height, and dives into the ground at the square's edge. They stand
    every `step` m along the edge, but where the ring itself runs to it,
    so no ground the tree's footprint takes is left bare; seen from above
    the tree is its footprint."""
    edge = half - 0.1
    count = int(math.ceil(2 * edge / step))
    targets = []
    for k in range(count + 1):
        t = -edge + 2 * edge * k / count
        for x, y in ((edge, t), (-edge, t), (t, edge), (t, -edge)):
            if (x, y) not in targets and math.hypot(x, y) > ring - 0.15:
                targets.append((x, y))
    # Each root a little different: how high it arches, how it bends and
    # how thick it is (its tip is the same, so the edge stays covered).
    rng = random.Random(29)
    for x, y in targets:
        d = Vector((x, y, 0)).normalized()
        side = Vector((-d.y, d.x, 0)) * rng.uniform(-0.06, 0.06)
        foot = Vector((x, y, 0))
        root = d * (ring - 0.15)
        thick = rng.uniform(0.85, 1.2)
        tube(m, [root + Vector((0, 0, 0.42)), root.lerp(foot, rng.uniform(0.45, 0.6)) + side
                 + Vector((0, 0, rng.uniform(0.44, 0.62))), foot + Vector((0, 0, 0.32)), foot],
             [0.15 * thick, 0.12 * thick, 0.09, 0.07], mat, sides=5)


def tree_banyan():
    """The square's hero: a flared, fluted trunk in a low stone planter ring,
    five great limbs, aerial roots, a wide layered canopy of faceted lobes and
    yellow paper lanterns hanging beneath it."""
    rng = random.Random(11)
    body, canopy, lanterns = Mesh(), Mesh(), Mesh()
    # Planter ring: limewash wall, sandstone coping, a lawn of leafy tufts.
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
    add(body, verts, faces, "limewash_shade")
    verts, faces = [], []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        c, s = math.cos(a), math.sin(a)
        verts += [((ro + 0.06) * c, (ro + 0.06) * s, h), ((ro + 0.06) * c, (ro + 0.06) * s, h + 0.09),
                  ((ri - 0.04) * c, (ri - 0.04) * s, h + 0.09), ((ri - 0.04) * c, (ri - 0.04) * s, h)]
    for k in range(seg):
        a, b = 4 * k, 4 * ((k + 1) % seg)
        faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2), (a + 2, b + 2, b + 3, a + 3)]
    add(body, verts, faces, "sandstone")
    body.cylinder(ri, 0.1, (0, 0, 0.36), "grass_dark", sides=seg)
    for k in range(9):
        a = 2 * math.pi * (k + 0.5) / 9
        rr = 1.3 + 0.12 * (k % 2)
        lobe(body, 0.3, (rr * math.cos(a), rr * math.sin(a), 0.5), (1.2, 1.2, 0.8), seed=k, sub=1,
             jitter=0.25)
    # Trunk: a massive buttressed, twisted column flaring into the soil.
    zs = [0.36, 0.9, 1.6, 2.4, 3.1, 3.7]
    rs = [1.28, 1.0, 0.88, 0.84, 0.9, 1.0]
    pts = [(0.05 * math.sin(i), 0.04 * math.cos(i), z) for i, z in enumerate(zs)]
    fl = [0.26, 0.2, 0.14, 0.12, 0.1, 0.08]
    tube(body, pts, rs, "wood", sides=14, twist=0.09,
         shape=lambda k, i: 1 + fl[i] * math.cos(5 * 2 * math.pi * k / 14) + 0.04 * ((k * 7 + i) % 3),
         cap_end=False)
    # Surface roots spreading over the soil.
    for k in range(6):
        a = 2 * math.pi * (k + 0.3) / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(body, [d * 1.0 + Vector((0, 0, 0.6)), d * 1.35 + Vector((0, 0, 0.44)), d * 1.58 + Vector((0, 0, 0.4))],
             [0.24, 0.15, 0.07], "wood", sides=4)
    # Limbs: five great ones reaching out and up under the canopy, and one
    # up the middle.
    tips = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        reach = 3.3 + 0.5 * (k % 2)
        p0 = Vector((0, 0, 3.2)) + d * 0.35
        p1 = Vector((0, 0, 4.3)) + d * 1.35
        p2 = Vector((0, 0, 5.2)) + d * (reach * 0.72)
        p3 = Vector((0, 0, 6.0 + 0.2 * (k % 2))) + d * reach
        tube(body, [p0, p1, p2, p3], [0.62, 0.44, 0.28, 0.14], "wood", sides=8)
        tips.append((d, p2, p3, a))
    tube(body, [(0, 0, 3.4), (0.2, -0.1, 5.2), (0.1, 0.1, 7.0)], [0.6, 0.38, 0.16], "wood", sides=8)
    # Roots out to the edges of the square the tree takes.
    square_roots(body, ro + 0.06, 2.53, "wood")
    # Aerial roots: flutes hugging the trunk, props dropping from the limbs
    # into the planter, and short curtains dangling well above head height.
    for k in range(7):
        a = 2 * math.pi * (k + 0.5) / 7
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(body, [Vector((0, 0, 3.6)) + d * 0.98, Vector((0, 0, 2.2)) + d * 0.95, Vector((0, 0, 1.0)) + d * 1.12,
                    Vector((0, 0, 0.44)) + d * 1.4], [0.09, 0.1, 0.11, 0.14], "wood_dark", sides=5)
    for k, (d, p2, p3, a) in enumerate(tips):
        drop = d * 1.55 + Vector((0, 0, 0.42))
        start = Vector((0, 0, 4.6)) + d * 1.7
        tube(body, [start, (start + drop) / 2 + Vector((0.05, 0.04, 0)), drop], [0.07, 0.08, 0.11],
             "wood_dark", sides=4)
        for j in range(2):
            q = p2.lerp(p3, 0.3 + 0.4 * j) + Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), -0.1))
            end = q + Vector((rng.uniform(-0.1, 0.1), rng.uniform(-0.1, 0.1), -(q.z - 2.7 - rng.uniform(0, 0.6))))
            tube(body, [q, (q + end) / 2 + Vector((0.04, 0, 0)), end], [0.05, 0.045, 0.035], "wood_dark",
                 sides=4, cap_end=False)
    # Canopy: a broad, layered dome of leaf clumps. A wide skirt of clumps at
    # varied heights, a second tier, and a rounded crown; small fringe clumps
    # break the outline.
    for k in range(10):
        a = 2 * math.pi * k / 10 + 0.2
        rr = 4.15 + 0.35 * ((k * 3) % 3 - 1)
        z = 6.1 + 0.35 * ((k * 7) % 3)
        lobe(canopy, 1.45, (rr * math.cos(a), rr * math.sin(a), z), (1.35, 1.3, 0.85), seed=100 + k,
             jitter=0.2)
    for k in range(7):
        a = 2 * math.pi * k / 7 + 0.5
        rr = 2.25 + 0.2 * (k % 2)
        lobe(canopy, 1.5, (rr * math.cos(a), rr * math.sin(a), 7.5 + 0.25 * (k % 3)), (1.3, 1.3, 0.85),
             seed=200 + k, bias=0.05, jitter=0.2)
    lobe(canopy, 1.6, (0.2, -0.3, 8.55), (1.3, 1.25, 0.72), seed=300, bias=0.1)
    lobe(canopy, 1.2, (-0.9, 0.8, 8.35), (1.2, 1.2, 0.75), seed=301, bias=0.1)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10
        rr = 5.3 + 0.2 * (k % 2)
        lobe(canopy, 0.8, (rr * math.cos(a), rr * math.sin(a), 5.9 + 0.35 * (k % 3)), (1.1, 1.1, 0.8),
             seed=400 + k, sub=1, jitter=0.22)
    # Paper lanterns hanging on cords beneath the canopy.
    for k in range(11):
        a = 2 * math.pi * k / 11 + 0.15
        rr = 2.2 + 1.8 * ((k * 3) % 4) / 3
        x, y, z = rr * math.cos(a), rr * math.sin(a), 3.9 + 0.3 * ((k * 2) % 3)
        _lantern(lanterns, (x, y, z))
        body.beam((x, y, z + 0.26), (x, y, 5.4), 0.025, "wood_dark")
    finish("tree_banyan", {"body": body, "canopy": canopy, "lanterns": lanterns})


def _lantern(m, at):
    """A six-sided paper lantern, 0.55 m tall, centred on `at`."""
    x, y, z = at
    rings = [(-0.27, 0.07), (-0.15, 0.19), (0.13, 0.19), (0.27, 0.07)]
    verts, faces = [], []
    for dz, r in rings:
        for k in range(6):
            a = 2 * math.pi * k / 6
            verts.append((x + r * math.cos(a), y + r * math.sin(a), z + dz))
    for i in range(3):
        for k in range(6):
            k2 = (k + 1) % 6
            faces.append((i * 6 + k, i * 6 + k2, (i + 1) * 6 + k2, (i + 1) * 6 + k))
    faces.append(tuple(18 + k for k in range(6)))
    faces.append(tuple(reversed(range(6))))
    add(m, verts, faces, "lantern")


# How high a trunk stands upright: above the walking band (1.9 m) at the
# largest the pack plants a tree (1.2x) on a raised sidewalk.
UPRIGHT = 2.4


# ---- Palms ----

def palm(name, height, lean, frond_len, fronds, seed):
    """A palm: a leaning, ringed trunk that curves upright, a dense crown of
    broad, folded, serrated fronds arching out and down, and coconuts."""
    rng = random.Random(seed)
    m = Mesh()
    n = 10
    pts = []
    for i in range(n + 1):
        t = i / n
        # Upright through the walking band, leaning only above it, so the
        # trunk stands over its placement point where people pass.
        u = max(0.0, height * t - UPRIGHT) / (height - UPRIGHT)
        pts.append(Vector((lean * (1.6 * u - 0.6 * u * u), 0.15 * lean * math.sin(2.5 * u), height * t)))
    top = pts[-1]
    base_r = 0.17 + 0.012 * height
    radii = [base_r * (1.1 if i == 0 else 1.0) * (1 - 0.3 * i / n) * (1.06 if i % 2 else 1.0)
             for i in range(n + 1)]
    tube(m, pts, radii, "palm_bark", sides=7, cap_end=True,
         mats=lambda i: "wood" if i % 2 else "palm_bark", twist=0.2)
    m.sphere(radii[-1] * 1.9, top + Vector((0, 0, 0.02)), "palm_bark", subdivisions=1, scale=(1, 1, 0.9),
             jitter=0.1, seed=seed)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        m.sphere(0.1 + 0.012 * height, top + Vector((0.2 * math.cos(a), 0.2 * math.sin(a), -0.2)),
                 "wood_dark", subdivisions=1, jitter=0.08, seed=seed + k)
    s = mark(m)
    crown = top + Vector((0, 0, 0.12))
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.12, 0.12)
        length = frond_len * rng.uniform(0.9, 1.05)
        upper = k % 2 == 0
        blade(m, crown, (math.cos(a), math.sin(a)), length, width=0.23 * length,
              droop=length * (0.45 if upper else 0.62), lift=0.38 if upper else 0.1, fold=0.28, stations=5,
              serrate=0.42)
    # Young fronds standing up from the crown.
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.8
        blade(m, crown, (math.cos(a), math.sin(a)), frond_len * 0.5, width=0.12 * frond_len,
              droop=frond_len * 0.12, lift=0.8, fold=0.35, stations=4, serrate=0.42)
    paint(m, s, seed=seed, yellow=0.2, bias=0.0)
    finish(name, {"body": m})


# ---- Shrubs, beds and planters ----

def round_shrub(m, at, size=1.0, seed=0):
    """A clipped, faceted shrub of three lobes, `size` metres across."""
    x, y, z = at
    s = size / 1.1
    lobe(m, 0.36 * s, (x, y, z + 0.4 * s), (1.2, 1.2, 1.05), seed=seed)
    lobe(m, 0.29 * s, (x + 0.24 * s, y - 0.17 * s, z + 0.29 * s), (1.1, 1.1, 1.0), seed=seed + 1, sub=2)
    lobe(m, 0.28 * s, (x - 0.22 * s, y + 0.18 * s, z + 0.28 * s), (1.1, 1.1, 1.0), seed=seed + 2, sub=2)


def leafy_plant(m, at, size=1.0, leaves=11, seed=0, colours=("leaf", "leaf_light", "leaf_dark")):
    """A tropical rosette of big pointed, folded leaves, `size` metres
    across."""
    rng = random.Random(seed)
    x, y, z = at
    for k in range(leaves):
        a = 2 * math.pi * k / leaves + rng.uniform(-0.2, 0.2)
        inner = k % 3 == 0
        length = size * (0.42 if inner else 0.55) * rng.uniform(0.9, 1.1)
        blade(m, (x, y, z), (math.cos(a), math.sin(a)), length, width=length * 0.3,
              droop=length * (0.4 if inner else 0.9), lift=2.0 if inner else 1.2, fold=0.3, stations=3,
              mat=colours[k % len(colours)])


# How wide a planted bush stands where people walk, and how high its
# clipped sides rise before it rounds over. The city draws it as wide as
# the shrub kind's footprint, so its outline there must be a circle.
BUSH_R = 0.55
BUSH_SIDE = 0.4


def bush_mass(m, mat="leaf_dark", sides=32):
    """A clipped bush's mass: upright sides BUSH_SIDE m high on a circle
    BUSH_R m round, rounding over to a low dome, so that seen from above
    it is a circle wherever people walk. What grows on it stays inside
    that circle."""
    m.cylinder(BUSH_R, BUSH_SIDE, (0, 0, BUSH_SIDE / 2), mat, sides=sides)
    m.cylinder(BUSH_R, 0.14, (0, 0, BUSH_SIDE + 0.07), mat, sides=sides, radius_top=BUSH_R * 0.8)
    m.cylinder(BUSH_R * 0.8, 0.1, (0, 0, BUSH_SIDE + 0.19), mat, sides=sides, radius_top=BUSH_R * 0.45)


def shrub_round():
    """A clipped round bush: its mass, crowned with three leafy lobes."""
    m = Mesh()
    bush_mass(m)
    round_shrub(m, (0, 0, BUSH_SIDE - 0.12), 0.85, seed=5)
    finish("shrub_round", {"body": m})


def shrub_leafy():
    """A clipped bush crowned with a rosette of big tropical leaves."""
    m = Mesh()
    bush_mass(m)
    leafy_plant(m, (0, 0, BUSH_SIDE + 0.2), 0.85, leaves=13, seed=7)
    finish("shrub_leafy", {"body": m})


def flower(m, at, colour, r=0.075, seed=0):
    """A faceted, flattened blossom."""
    x, y, z = at
    m.sphere(r, (x, y, z), colour, subdivisions=1, scale=(1.3, 1.3, 0.6), jitter=0.15, seed=seed)


def flowerbed():
    """A 3 m × 1 m bed: a sandstone kerb brimming with leafy mounds and
    clusters of pink, yellow and white blossoms."""
    rng = random.Random(21)
    m = Mesh()
    w, d, h = 3.0, 1.0, 0.26
    t = 0.1
    for sx in (-1, 1):
        m.box((t, d, h), (sx * (w - t) / 2, 0, h / 2), "sandstone", bevel=0.02)
    for sy in (-1, 1):
        m.box((w - 2 * t, t, h), (0, sy * (d - t) / 2, h / 2), "sandstone", bevel=0.02)
    m.box((w - 2 * t, d - 2 * t, 0.2), (0, 0, 0.12), "soil")
    for k in range(8):
        x = -1.12 + k * 0.32
        y = 0.1 * (1 if k % 2 else -1)
        lobe(m, 0.3, (x, y, 0.25), (1.2, 1.05, 0.75), seed=30 + k, sub=2, jitter=0.18)
    colours = ["pink", "jackfruit", "white", "coral", "jackfruit", "pink", "white", "jackfruit"]
    for c in range(8):
        cx = -1.12 + c * 0.32 + 0.1
        cy = 0.2 * (-1 if c % 2 else 1)
        for j in range(3):
            a = 2 * math.pi * j / 3 + c
            x = cx + 0.13 * math.cos(a) + rng.uniform(-0.03, 0.03)
            y = cy + 0.13 * math.sin(a) + rng.uniform(-0.03, 0.03)
            flower(m, (x, y, 0.46 + rng.uniform(0.0, 0.07)), colours[c], r=0.1, seed=c * 3 + j)
    finish("flowerbed", {"body": m})


def planter_square():
    """A 1.2 m limewash planter box with a coping and a clipped shrub."""
    m = Mesh()
    s, h = 1.2, 0.6
    m.box((s - 0.06, s - 0.06, h - 0.06), (0, 0, (h - 0.06) / 2), "limewash", bevel=0.03)
    m.box((s, s, 0.07), (0, 0, h - 0.035), "limewash_shade", bevel=0.02)
    m.box((s - 0.16, s - 0.16, 0.04), (0, 0, h - 0.01), "soil")
    round_shrub(m, (0, 0, h - 0.05), 1.05, seed=41)
    leafy_plant(m, (0.0, 0.0, h + 0.1), 1.1, leaves=8, seed=43, colours=("leaf_light", "leaf"))
    finish("planter_square", {"body": m})


def planter_pot():
    """A terracotta pot with a rim and a leafy tropical plant."""
    m = Mesh()
    m.cylinder(0.2, 0.42, (0, 0, 0.21), "terracotta", sides=10, radius_top=0.26)
    m.cylinder(0.29, 0.08, (0, 0, 0.44), "terracotta_light", sides=10)
    m.cylinder(0.25, 0.02, (0, 0, 0.47), "soil", sides=10)
    leafy_plant(m, (0, 0, 0.45), 0.8, leaves=10, seed=51)
    finish("planter_pot", {"body": m})


def tree_round(name, height, spread, lobes, seed):
    """A street tree: a slightly leaning trunk that forks into a rounded,
    faceted crown of `lobes` lobes, as the sheets scatter through every
    garden and verge."""
    rng = random.Random(seed)
    m = Mesh()
    # The trunk stands upright through the walking band and forks above
    # it, so nothing but the trunk stands where people pass.
    trunk_top = max(height * 0.45, UPRIGHT + 0.4)
    lean = rng.uniform(-0.25, 0.25)
    tube(m, [(0, 0, 0), (0, 0, UPRIGHT), (lean, 0.1, trunk_top)], [0.24, 0.18, 0.14], "wood", sides=6)
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
        tip = (lean + math.cos(a) * spread * 0.22, math.sin(a) * spread * 0.22, trunk_top + height * 0.18)
        tube(m, [(lean, 0.1, trunk_top - 0.05), tip], [0.11, 0.06], "wood", sides=5)
    crown_z = height - spread * 0.42
    lobe(m, spread * 0.36, (lean, 0, crown_z), scale=(1, 1, 0.82), seed=seed)
    for k in range(lobes):
        a = 2 * math.pi * k / lobes + rng.uniform(-0.25, 0.25)
        r = spread * rng.uniform(0.2, 0.3)
        d = spread * rng.uniform(0.2, 0.3)
        z = crown_z + rng.uniform(-0.25, 0.35) * spread * 0.4
        lobe(m, r, (lean + math.cos(a) * d, math.sin(a) * d, z), scale=(1, 1, 0.85), seed=seed + k + 1,
             sub=1 if r < 0.9 else 2)
    finish(name, {"body": m})


# ---- The meadow ----

# Tall grass in the lawn's greens, and flowers in the kit's accents.
MEADOW_LOOK = {"grass": "grass", "grass_dark": "leaf", "grass_light": "leaf_light", "stem": "leaf_dark",
               "flowers": ["pink", "jackfruit", "white", "coral"], "flower_centre": "jackfruit_dark"}



ASSETS = {
    "meadow_grass": usables.meadow("meadow_grass", 81, 0, MEADOW_LOOK, finish),
    "meadow_flowers": usables.meadow("meadow_flowers", 82, 4, MEADOW_LOOK, finish),
    "tree_banyan": tree_banyan,
    "tree_round_a": lambda: tree_round("tree_round_a", 6.0, 4.8, 6, 71),
    "tree_round_b": lambda: tree_round("tree_round_b", 4.6, 3.6, 5, 72),
    "palm_a": lambda: palm("palm_a", 7.6, 1.1, 2.75, 9, 61),
    "palm_b": lambda: palm("palm_b", 5.7, 0.8, 2.3, 8, 62),
    "palm_c": lambda: palm("palm_c", 3.8, 0.45, 1.8, 7, 63),
    "shrub_round": shrub_round,
    "shrub_leafy": shrub_leafy,
    "flowerbed": flowerbed,
    "planter_square": planter_square,
    "planter_pot": planter_pot,
}
