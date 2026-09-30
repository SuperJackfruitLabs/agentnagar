"""Vegetation for the cel-shaded anime kit, after the 06 sheets: the square's
great shade tree in its stone planter ring, round street trees, palms in
three sizes, shrubs, a flower bed and planters.

Foliage is drawn as the sheets draw it: fluffy broadleaf crowns of leaf
clusters with a leaf-edged outline, sunlit on top and dark underneath. The
trees', shrub's, planter's and bed's crowns are leaf cards (the shared
foliage.py): overlapping lobes, each a dark heart wrapped in alpha-masked
cards of pointed-leaf clusters (leaf_dark underneath, leaf on the flanks,
leaf_light and leaf_sun on top), whose normals come from the whole crown,
so the pack's toon step shades it as one soft form and its ink line runs
round the leaves. Their GLBs import without LODs (Godot's simplifier
deletes whole cards). Palms have long, arching, serrated fronds in palm
and palm_light. `puff` and `mass`, the earlier clumped blobs, remain for
the kits that build on them.

Conventions (as the low-poly kit's vegetation, shared with props.py):
Blender Z-up, pieces face +Y (Godot -Z); the origin is the centre of the
footprint on the ground. Each asset is an empty named after the asset that
parents one merged mesh, `body`, and the great tree's `canopy` besides.
The great tree's planter ring is 0.5 m high, a sitting height.
"""
import math
import random
import sys
from pathlib import Path

from mathutils import Vector

import lib
from lib import Mesh

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import foliage  # noqa: E402  (leaf-card crowns, shared by the kits)
import usables  # noqa: E402  (the meadow's clumps, as every kit draws them)

# The painted light: high, and toward the viewer of the usual diagonal
# camera (Blender -Y is Godot +Z, the south), as the low-poly kit paints it.
SUN = Vector((0.3, -0.45, 0.84)).normalized()
# The heart of a leaf-card crown: mid green on top, where it shows through
# the sunlit leaves, and dark green under them.
DEEP = ("leaf", "leaf_dark")


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


def _new_faces(m, start):
    m.bm.faces.ensure_lookup_table()
    return list(m.bm.faces)[start:]


def puff(m, at, radius, mat, cap=None, scale=(1, 1, 1), seed=0, seg=10, rings=6, flat=0.35, lump=0.12,
         cap_at=0.55, crown=None):
    """A leaf clump: a lumpy ball of `radius` (times `scale`), flatter
    underneath, in `mat` with its sunlit top in `cap`. Its surface wobbles
    smoothly, deterministically by `seed`, so neighbouring clumps differ.
    With `crown` (centre, radii, weight) its normals lean that far toward
    the whole crown's, so the toon light shades the crown as one soft form
    and each clump as a bulge on it (see `finish`)."""
    rng = random.Random(seed)
    waves = []
    for _ in range(3):
        c = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        waves.append((lump * rng.uniform(0.6, 1.2), rng.uniform(2.6, 4.2), c, rng.uniform(0, 2 * math.pi)))
    twist = rng.uniform(0, 2 * math.pi)
    centre = Vector(at)
    dirs = [Vector((0, 0, -1))]
    for i in range(1, rings):
        lat = -math.pi / 2 + math.pi * i / rings
        for k in range(seg):
            lon = 2 * math.pi * (k + 0.5 * (i % 2)) / seg + twist
            dirs.append(Vector((math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat))))
    dirs.append(Vector((0, 0, 1)))
    verts = []
    for d in dirs:
        r = radius * (1 + sum(a * math.sin(f * d.dot(c) + ph) for a, f, c, ph in waves))
        p = d * r
        if p.z < 0:
            p.z *= 1 - flat
        verts.append(centre + Vector((p.x * scale[0], p.y * scale[1], p.z * scale[2])))
    top = len(dirs) - 1
    faces = []
    for k in range(seg):
        faces.append((0, 1 + (k + 1) % seg, 1 + k))
    for i in range(rings - 2):
        a, b = 1 + i * seg, 1 + (i + 1) * seg
        for k in range(seg):
            k2 = (k + 1) % seg
            # Rings are staggered by half a step, so each quad is two
            # triangles.
            if i % 2 == 0:
                faces.append((a + k, a + k2, b + k2))
                faces.append((a + k, b + k2, b + k))
            else:
                faces.append((a + k, a + k2, b + k))
                faces.append((a + k2, b + k2, b + k))
    last = 1 + (rings - 2) * seg
    for k in range(seg):
        faces.append((last + k, last + (k + 1) % seg, top))
    mats = []
    for f in faces:
        d = sum((dirs[i] for i in f), Vector()).normalized()
        lit = 0.65 * d.z + 0.35 * d.dot(SUN) + rng.uniform(-0.12, 0.12)
        mats.append(cap if cap and lit > cap_at else mat)
    s = mark(m)
    first = len(m.bm.verts)
    add(m, verts, faces, mats)
    for f in _new_faces(m, s):
        f.normal_update()
        if f.normal.dot(f.calc_center_median() - centre) < 0:
            f.normal_flip()
    if crown:
        c, radii, w = crown
        normals = m.__dict__.setdefault("normals", {})
        for j, v in enumerate(verts):
            own = Vector(((v[0] - centre.x) / scale[0], (v[1] - centre.y) / scale[1],
                          (v[2] - centre.z) / scale[2])).normalized()
            whole = Vector(((v[0] - c[0]) / radii[0] ** 2, (v[1] - c[1]) / radii[1] ** 2,
                            (v[2] - c[2]) / radii[2] ** 2)).normalized()
            normals[first + j] = own.lerp(whole, w).normalized()


def _frames(pts):
    """Parallel-transported (tangent, normal, binormal) frames along a polyline."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tans = [(pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(n)]
    ref = Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))
    nor = (ref - tans[0] * ref.dot(tans[0])).normalized()
    out = []
    for t in tans:
        nor = (nor - t * nor.dot(t)).normalized()
        out.append((t, nor, t.cross(nor)))
    return pts, out


def tube(m, pts, radii, mat, sides=8, shape=None, cap_end=True, cap_start=False, mats=None):
    """A round tube along `pts` with a radius per point. `shape(k, i)`
    scales ring vertex k of ring i (a trunk's flare); `mats(i)` names the
    material of segment i (a palm's rings)."""
    pts, frames = _frames(pts)
    verts, faces, fm = [], [], []
    for i, (p, (t, nor, bi)) in enumerate(zip(pts, frames)):
        for k in range(sides):
            a = 2 * math.pi * k / sides
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
    body = (len(pts) - 1) * sides
    for j, f in enumerate(_new_faces(m, s)):
        f.normal_update()
        c = f.calc_center_median()
        if j < body:
            out = c - pts[j // sides].lerp(pts[j // sides + 1], 0.5)
        else:
            end = last if cap_end and j == body else 0
            out = frames[end][0] * (1 if end == last else -1)
        if f.normal.dot(out) < 0:
            f.normal_flip()


def frond(m, base, heading, length, width, lift, droop, mat, stations=7, fold=0.6, notch=0.55):
    """A palm frond from `base` along `heading` (an xy angle in radians):
    its midrib rises by `lift`×length and arches down by `droop` at the
    tip; leaflets hang either side, folded down by `fold`×width, their
    edge notched by `notch` into a feathery saw."""
    d = Vector((math.cos(heading), math.sin(heading), 0))
    side = Vector((-d.y, d.x, 0))
    n = stations * 2
    verts, faces = [], []
    for i in range(n + 1):
        t = i / n
        p = Vector(base) + d * length * t + Vector((0, 0, lift * length * t - droop * t * t))
        w = width * math.sin(math.pi * min(t * 1.1, 1.0)) ** 0.7
        if i % 2 == 1:
            w *= 1 - notch
        tip = d * (0.5 * w if i % 2 == 0 else 0.0)
        drop = Vector((0, 0, -w * fold))
        verts += [p, p + side * w + drop + tip, p - side * w + drop + tip]
    for i in range(n):
        a, b = 3 * i, 3 * (i + 1)
        faces.append((a, b, b + 1, a + 1))
        faces.append((a, a + 2, b + 2, b))
    add(m, verts, faces, mat)


def fit(m, first, width, depth, span=None, centre=None):
    """Stretches the vertices added to `m` since vertex `first` to `width`
    (x) by `depth` (y) about their centre, or moved onto `centre` (x, y),
    and, given `span` (z0, z1), from z0 to z1. Custom normals are kept: the
    stretch barely skews them."""
    m.bm.verts.ensure_lookup_table()
    vs = list(m.bm.verts)[first:]
    for axis, want in ((0, width), (1, depth)):
        lo = min(v.co[axis] for v in vs)
        hi = max(v.co[axis] for v in vs)
        to = (lo + hi) / 2 if centre is None else centre[axis]
        for v in vs:
            v.co[axis] = to + (v.co[axis] - (lo + hi) / 2) * want / (hi - lo)
    if span:
        lo = min(v.co.z for v in vs)
        k = (span[1] - span[0]) / (max(v.co.z for v in vs) - lo)
        for v in vs:
            v.co.z = span[0] + (v.co.z - lo) * k


def finish(name, parts, smooth=None):
    """An empty named `name` parenting {node: Mesh} parts; `smooth` maps
    the nodes to smooth-shade to the angle (degrees) kept hard."""
    r = lib.root(name)
    smooth = smooth or {}
    for node, mesh in parts.items():
        custom = getattr(mesh, "normals", None)
        o = mesh.build(node, r)
        if node in smooth:
            lib.smooth(o, smooth[node])
        if custom:
            me = o.data
            normals = [tuple(c.vector) for c in me.corner_normals]
            for loop in me.loops:
                if loop.vertex_index in custom:
                    normals[loop.index] = tuple(custom[loop.vertex_index])
            me.normals_split_custom_set(normals)
    return r


def ring_wall(m, r_out, r_in, z0, z1, mat, seg=24):
    """A round wall from radius r_in to r_out, z0 to z1: its outer and
    inner faces and its top."""
    verts, faces = [], []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        c, s = math.cos(a), math.sin(a)
        verts += [(r_out * c, r_out * s, z0), (r_out * c, r_out * s, z1),
                  (r_in * c, r_in * s, z1), (r_in * c, r_in * s, z0)]
    for k in range(seg):
        a, b = 4 * k, 4 * ((k + 1) % seg)
        faces += [(a, b, b + 1, a + 1), (a + 1, b + 1, b + 2, a + 2), (a + 2, b + 2, b + 3, a + 3)]
    add(m, verts, faces, mat)


# ---- Crowns ----

def _spread(n, lo=-0.3):
    """`n` directions spread evenly over the sphere above z = `lo`."""
    out = []
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - (1 - lo) * (i + 0.5) / n
        r = math.sqrt(max(0.0, 1 - z * z))
        out.append(Vector((r * math.cos(golden * i), r * math.sin(golden * i), z)))
    return out


def tone(up, rng):
    """A clump's greens by where it sits on its crown (`up` from -1 under
    to 1 on top): sunlit crown, mid flanks, dark underside."""
    up += rng.uniform(-0.2, 0.2)
    if up > 0.8:
        return "leaf_light", "leaf_sun"
    if up > -0.1:
        return "leaf", "leaf_light"
    return "leaf_dark", "leaf"


def mass(m, centre, radii, n, clump, seed, lo=-0.3, seg=8, rings=5, lump=0.08, crown=None):
    """A mass of `n` leaf clumps of about `clump` m radius, spread over an
    ellipsoid of `radii` about `centre` above z = `lo` (of its unit
    sphere), round a dark core."""
    rng = random.Random(seed)
    centre = Vector(centre)
    puff(m, centre, min(radii) * 0.95, "leaf_dark", scale=(radii[0] / min(radii), radii[1] / min(radii), 0.8),
         seed=seed, seg=5, rings=4, crown=crown)
    for k, d in enumerate(_spread(n, lo)):
        p = centre + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * rng.uniform(0.84, 1.0)
        mat, cap = tone(d.z, rng)
        puff(m, p, clump * rng.uniform(0.85, 1.15), mat, cap=cap, scale=(1.1, 1.1, 0.9), seed=seed * 50 + k,
             seg=seg, rings=rings, lump=lump, crown=crown)


# ---- The great tree ----

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
             [0.15 * thick, 0.12 * thick, 0.09, 0.07], mat, sides=6)


def tree_banyan():
    """The square's great shade tree, the city's landmark: a massive, flared
    trunk with buttress roots rising from a low stone planter ring of grass,
    forking at 3 m into great limbs that spread under a huge rounded crown
    of overlapping leaf clumps, darker underneath and sunlit on top."""
    rng = random.Random(3)
    body, canopy = Mesh(), Mesh()
    # Planter ring: a stone wall at sitting height with a pale coping.
    ring_wall(body, 2.45, 2.12, 0.0, 0.42, "stone", seg=24)
    ring_wall(body, 2.53, 2.05, 0.42, 0.5, "paving_light", seg=24)
    add(body, [(2.12 * math.cos(2 * math.pi * k / 24), 2.12 * math.sin(2 * math.pi * k / 24), 0.34)
               for k in range(24)], [tuple(range(24))], "grass")
    bed = []
    for k in range(10):
        a = 2 * math.pi * (k + 0.3) / 10
        rr = 1.75 + 0.1 * (k % 2)
        bed.append(((rr * math.cos(a), rr * math.sin(a), 0.42), (0.42, 0.42, 0.28)))
    foliage.crown(body, bed, 0.36, 500, whole=((0, 0, 0.2), (2.3, 2.3, 0.5)), weight=0.3, lo=-0.1, cover=1.45,
                  cores=False)
    # Trunk: a buttressed column flaring into the soil.
    zs = [0.3, 0.8, 1.5, 2.3, 3.0, 3.5]
    rs = [1.26, 0.92, 0.78, 0.74, 0.76, 0.78]
    flare = [0.28, 0.16, 0.06, 0.03, 0.02, 0.0]
    pts = [(0.04 * math.sin(i), 0.03 * math.cos(i), z) for i, z in enumerate(zs)]
    tube(body, pts, rs, "trunk_light", sides=12, cap_end=False,
         shape=lambda k, i: 1 + flare[i] * math.cos(5 * 2 * math.pi * k / 12 + 0.4))
    # Surface roots running out over the grass.
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(body, [d * 0.8 + Vector((0, 0, 0.6)), d * 1.35 + Vector((0, 0, 0.36)), d * 1.8 + Vector((0, 0, 0.3))],
             [0.3, 0.16, 0.06], "trunk_light", sides=6)
    # Limbs: five great ones reaching out and up into the crown's masses,
    # each with a side branch, and a leader up the middle.
    tips = []
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.15 + rng.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), 0))
        reach = 3.2 + 0.3 * (k % 2)
        p = [Vector((0, 0, 2.9)) + d * 0.2, Vector((0, 0, 3.9)) + d * 1.0, Vector((0, 0, 4.9)) + d * (reach * 0.62),
             Vector((0, 0, 5.9)) + d * reach]
        tube(body, p, [0.5, 0.4, 0.26, 0.12], "trunk_light", sides=8)
        s = Vector((-d.y, d.x, 0)) * (1 if k % 2 else -1)
        q = p[1].lerp(p[2], 0.5)
        tube(body, [q, q + d * 0.6 + s * 0.8 + Vector((0, 0, 0.9)), q + d * 1.0 + s * 1.5 + Vector((0, 0, 1.7))],
             [0.18, 0.12, 0.06], "trunk_light", sides=6)
        tips.append((a, reach))
    tube(body, [(0, 0, 3.2), (0.25, -0.1, 5.2), (0.1, 0.1, 7.0)], [0.5, 0.32, 0.12], "trunk_light", sides=8)
    # Roots out to the edges of the square the tree takes.
    square_roots(body, 2.53, 2.53, "trunk_light")
    # Crown: a leafy mass over each limb, a lower one hanging between each
    # pair, wrapping down the flanks, and rounded masses on top, shaded as
    # one great dome.
    lobes = []
    for k, (a, reach) in enumerate(tips):
        rr = 3.1 + 0.15 * (k % 2)
        lobes.append(((rr * math.cos(a), rr * math.sin(a), 5.7 + 0.3 * (k % 2)), (2.1, 2.1, 1.6)))
        b = a + math.pi / 5
        lobes.append(((3.7 * math.cos(b), 3.7 * math.sin(b), 5.1), (1.5, 1.5, 1.15)))
    for x, y, z in ((0.9, -0.8, 7.5), (-0.9, 0.9, 7.35), (0.2, 0.1, 8.1)):
        lobes.append(((x, y, z), (1.9, 1.9, 1.3)))
    foliage.crown(canopy, lobes, 1.25, seed=10, whole=((0, 0, 5.2), (5.6, 5.6, 3.8)), weight=0.4, cover=7.5,
                  lo=-0.85, core_mat=DEEP)
    across = foliage.padded(11.9, 1.25)
    fit(canopy, 0, across, across, span=(4.5, 9.5 + (across - 11.9) / 2), centre=(0, 0))
    finish("tree_banyan", {"body": body, "canopy": canopy}, smooth={"body": 50, "canopy": 50})


# ---- Street trees ----

# How high a trunk stands upright: above the walking band (1.9 m) at the
# largest the pack plants a tree (1.2x) on a raised sidewalk.
UPRIGHT = 2.4


def tree_round(name, height, spread, depth, clumps, seed, far=False):
    """A street tree: a slightly leaning trunk forking into three branches
    under a rounded crown of `clumps` leaf clumps, `spread` m across (x)
    and `depth` m deep (y), as the sheets line every street and verge.
    `far`: the version for a distance, its crown the same lobes as solid
    two-tone forms with no leaf cards (the pack swaps it in far off)."""
    rng = random.Random(seed)
    m = Mesh()
    clump = min(spread, depth) * 0.125
    rx, ry = (spread / 2 - clump * 1.2) / 0.94, (depth / 2 - clump * 1.2) / 0.94
    rz = min(rx, ry) * 0.78
    cz = height - rz * 0.95 - clump * 0.95
    lean = rng.uniform(-0.12, 0.12)
    # Upright through the walking band and forking above it, so nothing
    # but the trunk stands where people pass.
    fork = max(cz - rz * 0.75, UPRIGHT + 0.4)
    r0 = 0.09 + 0.025 * height
    tube(m, [(0, 0, 0), (0.0, 0.0, UPRIGHT), (lean, 0.0, fork)], [r0, r0 * 0.78, r0 * 0.7],
         "trunk_light", sides=8, shape=lambda k, i: 1 + (0.2 * math.cos(3 * 2 * math.pi * k / 8) if i == 0 else 0))
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
        tip = (lean + math.cos(a) * rx * 0.6, math.sin(a) * ry * 0.6, cz + rz * 0.2)
        tube(m, [(lean, 0, fork - 0.25), (lean + math.cos(a) * rx * 0.3, math.sin(a) * ry * 0.3, fork + 0.4), tip],
             [r0 * 0.6, r0 * 0.45, r0 * 0.2], "trunk_light", sides=6)
    first = len(m.bm.verts)
    card = min(spread, depth) * 0.23
    big = (rx + clump * 0.6, ry + clump * 0.6, rz + clump * 0.6)
    lobes = foliage.round_lobes((lean, 0, cz), big, max(6, clumps // 3), seed)
    foliage.crown(m, lobes, card, seed, whole=((lean, 0, cz - rz * 0.3), (big[0] * 1.15, big[1] * 1.15, big[2] * 1.2)),
                  lo=-0.75, cover=5.5, core_mat=("leaf_light", "leaf") if far else DEEP, cards=not far, core_scale=0.92 if far else 0.6,
                  core_seg=9 if far else 7, core_rings=5 if far else 4)
    m.bm.verts.ensure_lookup_table()
    zlo = min(v.co.z for v in list(m.bm.verts)[first:])
    if far:
        fit(m, first, spread * 0.84, depth * 0.84, span=(zlo + clump * 0.5, height - clump * 0.6), centre=(lean, 0))
    else:
        fit(m, first, foliage.padded(spread, card), foliage.padded(depth, card), span=(zlo, height), centre=(lean, 0))
    finish(name, {"body": m}, smooth={"body": 50})


# ---- Palms ----

def palm(name, height, lean, frond_len, fronds, seed, far=False):
    """A palm: a slender, ringed trunk leaning out and curving upright, a
    tuft of frond bases and three coconuts, and a crown of long, feathery
    fronds arching out and down, lighter above, darker below. `far`: the
    version for a distance, the same silhouette with plain fronds of few
    segments, fewer trunk rings and no coconuts."""
    rng = random.Random(seed)
    m = Mesh()
    n = 6 if far else 12
    pts, radii = [], []
    base_r = 0.13 + 0.012 * height
    for i in range(n + 1):
        for f in ((0.0, 0.82) if i < n else (0.0,)):
            t = (i + f) / n
            # Upright through the walking band, leaning only above it.
            u = max(0.0, height * t - UPRIGHT) / (height - UPRIGHT)
            pts.append(Vector((lean * (1.6 * u - 0.6 * u * u), 0.12 * lean * math.sin(2.5 * u), height * t)))
            r = base_r * (1.2 - 0.2 * min(t * 4, 1)) * (1 - 0.22 * t)
            radii.append(r * (1.08 if f else 1.0))
    tube(m, pts, radii, "trunk_light", sides=8, mats=lambda i: "trunk" if i % 2 else "trunk_light")
    m.bm.verts.ensure_lookup_table()
    for v in list(m.bm.verts)[:8]:
        v.co.z = 0.0  # the leaning base ring, set flat on the ground
    top = pts[-1]
    puff(m, top + Vector((0, 0, 0.1)), radii[-1] * 2.1, "palm", scale=(1, 1, 0.9), seed=seed, seg=8, rings=5)
    for k in range(0 if far else 3):
        a = 2 * math.pi * k / 3 + 0.4
        puff(m, top + Vector((0.22 * math.cos(a), 0.22 * math.sin(a), -0.18)), 0.08 + 0.01 * height, "trunk",
             seed=seed + k, seg=6, rings=4, lump=0.05, flat=0.0)
    crown = top + Vector((0, 0, 0.16))
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.12, 0.12)
        length = frond_len * rng.uniform(0.92, 1.04)
        upper = k % 2 == 0
        frond(m, crown, a, length, 0.23 * length, lift=0.45 if upper else 0.15,
              droop=length * (0.55 if upper else 0.68), mat="palm_light" if upper else "palm",
              stations=4 if far else 10, fold=0.4, notch=0.0 if far else 0.55)
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.8
        frond(m, crown, a, frond_len * 0.5, 0.09 * frond_len, lift=1.0, droop=frond_len * 0.18,
              mat="palm_light", stations=3 if far else 6, notch=0.0 if far else 0.55)
    finish(name, {"body": m}, smooth={"body": 50})


# ---- Shrubs, beds and planters ----

def shrub(m, at, width, height, seed, clumps=7, lo=-0.3):
    """A clipped, rounded shrub `width` m across and `height` m tall: a low
    mound of leafy lobes (about one per two of `clumps`) round one heart,
    shaded as one mound."""
    x, y, z = at
    first = len(m.bm.verts)
    r = (width * 0.5, width * 0.46, height * 0.62)
    lobes = foliage.round_lobes((x, y, z + height * 0.45), r, max(5, clumps // 2 + 2), seed, lo=-0.4, hi=0.35,
                                size=0.66, reach=0.42)
    heart = ((x, y, z + height * 0.42), (width * 0.46, width * 0.43, height * 0.55))
    foliage.crown(m, lobes, width * 0.3, seed, whole=((x, y, z + height * 0.3), (width * 0.55, width * 0.52, height)),
                  weight=0.5, lo=lo, cover=6.0, core_mat=DEEP, cores=[heart], core_scale=0.85, core_seg=8,
                  core_rings=5)
    fit(m, first, foliage.padded(width, width * 0.3), foliage.padded(width * 0.92, width * 0.3), span=(z, z + height))


def leafy(m, at, size, leaves, seed, colours=("leaf", "leaf_light", "leaf_dark"), lift=1.0):
    """A tropical rosette of big pointed leaves, `size` m across, arching
    out from `at`."""
    rng = random.Random(seed)
    for k in range(leaves):
        a = 2 * math.pi * k / leaves + rng.uniform(-0.2, 0.2)
        inner = k % 3 == 0
        length = size * (0.42 if inner else 0.55) * rng.uniform(0.9, 1.1)
        frond(m, at, a, length, length * 0.3, lift=(1.9 if inner else 1.15) * lift,
              droop=length * (0.5 if inner else 1.05), mat=colours[k % len(colours)], stations=3, fold=0.6,
              notch=0.0)


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
    """A clipped round bush: its mass under a mound of leaf clumps."""
    m = Mesh()
    bush_mass(m)
    shrub(m, (0, 0, BUSH_SIDE - 0.2), 0.9, 0.62, seed=5, clumps=7)
    finish("shrub_round", {"body": m}, smooth={"body": 50})


def shrub_leafy():
    """A clipped bush crowned with a rosette of big tropical leaves."""
    m = Mesh()
    bush_mass(m)
    leafy(m, (0, 0, BUSH_SIDE + 0.2), 0.85, leaves=13, seed=7, lift=1.15)
    finish("shrub_leafy", {"body": m}, smooth={"body": 50})


def flower(m, at, colour, r, seed, petals=5, centre="flower_yellow"):
    """A star-shaped blossom with petals `r` m long, facing up and a
    little tilted, with a yellow eye."""
    rng = random.Random(seed)
    x, y, z = at
    turn = rng.uniform(0, 2 * math.pi)
    tilt = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 0))
    verts = [(x, y, z + 0.01)]
    for k in range(petals * 2):
        a = turn + math.pi * k / petals
        rr = r if k % 2 == 0 else r * 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        verts.append(Vector((x, y, z)) + d * rr + Vector((0, 0, (0.3 * rr if k % 2 == 0 else 0.0) + d.dot(tilt) * rr)))
    faces = [(0, 1 + k, 1 + (k + 1) % (petals * 2)) for k in range(petals * 2)]
    add(m, verts, faces, colour)
    eye = [(x + r * 0.2 * math.cos(turn + 2 * math.pi * k / 5), y + r * 0.2 * math.sin(turn + 2 * math.pi * k / 5),
            z + 0.022) for k in range(5)]
    add(m, eye, [(0, 1, 2, 3, 4)], centre)


def kerb(m, w, d, h, t=0.1):
    """A rectangular stone kerb `w` x `d`, `h` high and `t` thick, with a
    paler coping."""
    for sx in (-1, 1):
        m.box((t, d, h - 0.05), (sx * (w - t) / 2, 0, (h - 0.05) / 2), "stone_dark", bevel=0.015)
        m.box((t + 0.02, d + 0.02, 0.05), (sx * (w - t) / 2, 0, h - 0.025), "stone", bevel=0.012)
    for sy in (-1, 1):
        m.box((w - 2 * t, t, h - 0.05), (0, sy * (d - t) / 2, (h - 0.05) / 2), "stone_dark", bevel=0.015)
        m.box((w - 2 * t, t + 0.02, 0.05), (0, sy * (d - t) / 2, h - 0.025), "stone", bevel=0.012)


def flowerbed():
    """A 3 m x 1 m bed: a stone kerb brimming with leafy mounds, white
    star lilies and pink blossoms, as along the waterfront park's paths."""
    rng = random.Random(21)
    m = Mesh()
    w, d, h = 3.0, 1.0, 0.28
    kerb(m, w, d, h)
    m.box((w - 0.2, d - 0.2, 0.2), (0, 0, 0.12), "soil")
    mounds = []
    lobes = []
    for k in range(7):
        x = -1.08 + k * 0.36
        y = 0.1 * (1 if k % 2 else -1)
        lobes.append(((x, y, 0.22), (0.4, 0.34, 0.28)))
        mounds.append((x, y))
    first = len(m.bm.verts)
    foliage.crown(m, lobes, 0.3, 30, whole=((0, 0, 0.1), (1.6, 0.55, 0.42)), weight=0.35, lo=-0.3, cover=5.5,
                  core_mat=DEEP, cores=[((0, 0, 0.22), (1.45, 0.42, 0.34))], core_scale=0.85)
    # Brimming just over the kerb, under the blossoms.
    fit(m, first, 3.0, 1.0, span=(0.14, 0.55))
    for c in range(22):
        x, y = mounds[c % 7]
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.12, 0.26)
        x, y = x + rr * math.cos(a) * 1.2, y + rr * math.sin(a) * 0.9
        pink = c % 3 == 1
        top = 0.22 + 0.32 * 0.85 * math.sqrt(max(0.0, 1 - (rr / 0.38) ** 2))
        flower(m, (x, y, top + 0.04), "flower_pink" if pink else "flower_white", 0.11 if pink else 0.14,
               seed=c, petals=5 if pink else 6)
    finish("flowerbed", {"body": m}, smooth={"body": 50})


def planter_square():
    """A 1.2 m stone planter box with a pale coping and a clipped shrub
    swelling over its rim, as along the square's edges."""
    m = Mesh()
    s, h = 1.2, 0.6
    m.box((s - 0.08, s - 0.08, h - 0.07), (0, 0, (h - 0.07) / 2), "stone_dark", bevel=0.02)
    m.box((s, s, 0.08), (0, 0, h - 0.04), "stone", bevel=0.02)
    m.box((s - 0.18, s - 0.18, 0.04), (0, 0, h - 0.01), "soil")
    # The shrub: a ring of leafy lobes swelling over the rim under a
    # rounded top.
    first = len(m.bm.verts)
    lobes = [((0.4 * math.cos(2 * math.pi * k / 6), 0.4 * math.sin(2 * math.pi * k / 6), h + 0.16), (0.27, 0.27, 0.22))
             for k in range(6)]
    lobes.append(((0, 0, h + 0.42), (0.36, 0.36, 0.3)))
    foliage.crown(m, lobes, 0.3, 41, whole=((0, 0, h + 0.25), (0.62, 0.62, 0.5)), weight=0.5, lo=-0.35,
                  cover=8.0, core_mat=DEEP)
    across = foliage.padded(1.18, 0.3)
    fit(m, first, across, across, span=(h - 0.04, 1.42))
    finish("planter_square", {"body": m}, smooth={"body": 50})


def planter_pot():
    """A terracotta pot with a rolled rim and a leafy tropical plant."""
    m = Mesh()
    m.cylinder(0.2, 0.44, (0, 0, 0.22), "terracotta", sides=14, radius_top=0.27)
    m.cylinder(0.3, 0.08, (0, 0, 0.46), "terracotta_dark", sides=14)
    m.cylinder(0.26, 0.02, (0, 0, 0.5), "soil", sides=14)
    leafy(m, (0, 0, 0.48), 0.8, leaves=10, seed=51, lift=1.3)
    finish("planter_pot", {"body": m}, smooth={"body": 50})


# ---- The meadow ----

# Tall grass in the lawn's greens, and the flower beds' flowers.
MEADOW_LOOK = {"grass": "grass", "grass_dark": "grass_dark", "grass_light": "leaf_light", "stem": "leaf",
               "flowers": ["flower_pink", "flower_white", "flower_yellow"], "flower_centre": "yellow"}



ASSETS = {
    "meadow_grass": usables.meadow("meadow_grass", 81, 0, MEADOW_LOOK, finish),
    "meadow_flowers": usables.meadow("meadow_flowers", 82, 4, MEADOW_LOOK, finish),
    "tree_banyan": tree_banyan,
    "tree_round_a": lambda: tree_round("tree_round_a", 5.5, 4.6, 5.2, 20, 71),
    "tree_round_b": lambda: tree_round("tree_round_b", 4.4, 3.4, 3.6, 17, 72),
    "tree_round_a_far": lambda: tree_round("tree_round_a_far", 5.5, 4.6, 5.2, 20, 71, far=True),
    "palm_a_far": lambda: palm("palm_a_far", 7.6, 1.1, 2.75, 12, 61, far=True),
    "palm_b_far": lambda: palm("palm_b_far", 5.7, 0.8, 2.3, 11, 62, far=True),
    "palm_c_far": lambda: palm("palm_c_far", 3.8, 0.45, 1.8, 10, 63, far=True),
    "tree_round_b_far": lambda: tree_round("tree_round_b_far", 4.4, 3.4, 3.6, 17, 72, far=True),
    "palm_a": lambda: palm("palm_a", 7.6, 1.1, 2.75, 12, 61),
    "palm_b": lambda: palm("palm_b", 5.7, 0.8, 2.3, 11, 62),
    "palm_c": lambda: palm("palm_c", 3.8, 0.45, 1.8, 10, 63),
    "shrub_round": shrub_round,
    "shrub_leafy": shrub_leafy,
    "flowerbed": flowerbed,
    "planter_square": planter_square,
    "planter_pot": planter_pot,
}

