"""Semi-realistic people for the lit styles (09 Solarpunk, 10 Neon noir), on
the low-poly kit's human rig and motion (imported by path, not copied):
build_rig("human"), rigidly skinned parts (one bone each) and the walk,
idle, sit and typing actions.

Proportions are an adult's, about 7.5 heads tall (the crown at 1.73 m): a
head 23 cm from chin to crown with the eyes half way, a real neck,
sloping shoulders (the arms hang ARM_IN nearer the body than the rig's
joints), a waist, hands with a thumb. The head is modelled from an
implicit surface (skull, jaw, brow ridge, cheekbones, eye sockets, nose,
lips and chin blended smoothly), so light shows the face's form; the face
plate over it draws the eyes, brows, nostrils and lips (faces_real.py).

build(look) builds a person in the current scene: rig, parts, far body
and actions. Parts (node names; each carries role materials named as
shown, which the pack repaints per person):

    skin      head, ears, neck, forearms (and upper arms below short
              sleeves), hands
    face      a plate just proud of the face, UV-mapped to the top-left
              cell of face_atlas.png (below)
    top       the shirt: look "sleeves" short (a linen camp-collar shirt,
              the throat open) or long (a crew-neck top, cuffs)
    bottom    trousers (look "cuffs": rolled at the ankle)
    shoes     low canvas sneakers (the uppers)
    details   the shoes' soles ("sole")
    hair_0    tied up: pulled back into a messy bun, loose strands at the
              temples
    hair_1    short and tousled, a fringe swept to the person's left
    hair_2    pulled back into a ponytail to the shoulders
    hair_3    curly, full (the ears covered)
    hat_sun   a straw sun hat ("straw", "hat_band"), over any hair
    backpack  a canvas rucksack ("backpack", leather "strap")
    umbrella  held in the right hand, the canopy over the head
    far       one merged, simplified body for the distant crowd, its
              surfaces named by role: skin, top, bottom, shoes, hair

and the look's "extras" (the pack shows them per outfit):

    apron     a bib apron over the shirt, straps crossed behind; below the
              hips the skirt rides the thighs, half each, so it opens in
              the stride and lies in the lap when seated (solarpunk)
    jacket    an open zip jacket with a collar, over long sleeves (neon)
    hood      a hood lying down behind the neck ("jacket"; with the jacket
              it is a hoodie)
    scarf     a knitted scarf wound round the neck, the ends down the front

The face plate: a copy of the head's front faces 1.2 mm proud, u = 0 at
the viewer's left (the person's right, +X) and v = 0 at FACE_TOP, from a
straight front projection of the box FACE_HW either side of the midline
between FACE_BOTTOM and FACE_TOP (metres, rest pose). faces_real.py draws
the features in the same frame (its FACE_* constants must match these).

Axes, origin, bones and actions: see the low-poly characters module.
"""
import importlib.util
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import lib

_LOW = Path(__file__).resolve().parents[1] / "lowpoly" / "characters.py"


def _load_low():
    tables = [lib.PALETTE, lib.ROUGHNESS, lib.EMISSIVE, lib.METALLIC]
    saved = [dict(t) for t in tables]
    spec = importlib.util.spec_from_file_location("people_lowpoly_characters", _LOW)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    # The low-poly module sets its own role colours; the kit's stand.
    for table, before in zip(tables, saved):
        table.clear()
        table.update(before)
    return m


low = _load_low()
J = low.JOINTS["human"]

# The face frame (faces_real.py draws in it): a front projection.
FACE_TOP, FACE_BOTTOM, FACE_HW = 1.668, 1.494, 0.087
ATLAS_COLS, ATLAS_ROWS = 5, 4
# The arms hang this much nearer the body than the rig's joints (narrower
# shoulders; the swing is about the joints, so the offset holds).
ARM_IN = 0.016

# Role colours the kit palettes may not define (the pack repaints most).
ROLES = {
    "skin": "#D9A887", "top": "#E8E0CF", "bottom": "#5E6650", "shoes": "#7E705F", "sole": "#EEE9DF",
    "hair": "#3A2A22", "face": "#D9A887", "straw": "#DCC08A", "hat_band": "#5E4432", "backpack": "#556046",
    "strap": "#6A4630", "umbrella": "#E4513B", "iron": "#3A3B3D", "apron": "#4F5D4A", "jacket": "#1E2027",
    "scarf": "#B8862E",
}
ROUGH = {"skin": 0.6, "face": 0.6, "hair": 0.55, "sole": 0.7, "strap": 0.5, "jacket": 0.62}


# ---- The head: an implicit surface ----

# (z, rx, front, back, cy, nf): cross-sections chin to crown: half-width,
# the midline's front and back, the y of the widest point, and the front
# half's superellipse exponent (above 2: a flatter face).
_RINGS = [
    (1.502, 0.014, 0.088, 0.072, 0.080, 2.0),
    (1.508, 0.031, 0.094, 0.036, 0.066, 1.9),
    (1.518, 0.044, 0.095, -0.004, 0.046, 1.9),
    (1.532, 0.054, 0.093, -0.040, 0.012, 2.0),
    (1.546, 0.061, 0.094, -0.066, -0.002, 2.1),
    (1.562, 0.066, 0.095, -0.082, -0.006, 2.2),
    (1.582, 0.069, 0.094, -0.092, -0.010, 2.2),
    (1.600, 0.072, 0.091, -0.098, -0.012, 2.3),
    (1.625, 0.074, 0.089, -0.101, -0.014, 2.4),
    (1.650, 0.075, 0.089, -0.102, -0.016, 2.3),
    (1.675, 0.073, 0.084, -0.099, -0.017, 2.2),
    (1.700, 0.064, 0.070, -0.088, -0.018, 2.1),
    (1.715, 0.051, 0.054, -0.072, -0.018, 2.0),
    (1.726, 0.031, 0.031, -0.051, -0.018, 2.0),
    (1.731, 0.002, -0.014, -0.022, -0.018, 2.0),
]


def _dense(rings, step=0.0005):
    """(z, rx, ryf, ryb, cy, nf) rows every `step` in z, through the rings
    on a Catmull-Rom spline."""
    t = np.array([(z, rx, max(f - cy, 1e-3), max(cy - b, 1e-3), cy, n) for z, rx, f, b, cy, n in rings])
    zs = np.arange(t[0, 0], t[-1, 0] + 1e-9, step)
    out = np.zeros((len(zs), t.shape[1]))
    out[:, 0] = zs
    last = len(t) - 1
    for i, z in enumerate(zs):
        k = min(max(int(np.searchsorted(t[:, 0], z, side="right")) - 1, 0), last - 1)
        p0, p1, p2, p3 = t[max(k - 1, 0)], t[k], t[k + 1], t[min(k + 2, last)]
        f = (z - p1[0]) / (p2[0] - p1[0])
        m1 = (p2 - p0) / max(p2[0] - p0[0], 1e-6) * (p2[0] - p1[0])
        m2 = (p3 - p1) / max(p3[0] - p1[0], 1e-6) * (p2[0] - p1[0])
        h = (2 * f ** 3 - 3 * f ** 2 + 1, f ** 3 - 2 * f ** 2 + f, -2 * f ** 3 + 3 * f ** 2, f ** 3 - f ** 2)
        out[i, 1:] = (h[0] * p1 + h[1] * m1 + h[2] * p2 + h[3] * m2)[1:]
    out[:, 1:4] = np.maximum(out[:, 1:4], 1e-4)
    return out


_TABLE = _dense(_RINGS)


def _base(x, y, z):
    t = _TABLE
    zc = np.clip(z, t[0, 0], t[-1, 0])
    rx, ryf, ryb, cy, nf = (np.interp(zc, t[:, 0], t[:, k]) for k in range(1, 6))
    dy = y - cy
    front = dy >= 0
    ry = np.where(front, ryf, ryb)
    n = np.where(front, nf, 2.0)
    rho = ((np.abs(x) / rx) ** n + (np.abs(dy) / ry) ** n) ** (1.0 / n)
    d = (rho - 1.0) * np.minimum(rx, ry)
    return np.maximum(np.maximum(d, t[0, 0] - z), z - t[-1, 0])


def _ell(x, y, z, c, r):
    qx, qy, qz = (x - c[0]) / r[0], (y - c[1]) / r[1], (z - c[2]) / r[2]
    k0 = np.sqrt(qx * qx + qy * qy + qz * qz)
    k1 = np.sqrt((qx / r[0]) ** 2 + (qy / r[1]) ** 2 + (qz / r[2]) ** 2)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def _cone(x, y, z, a, b, ra, rb):
    ab = np.subtract(b, a)
    t = np.clip(((x - a[0]) * ab[0] + (y - a[1]) * ab[1] + (z - a[2]) * ab[2]) / ab.dot(ab), 0.0, 1.0)
    d = np.sqrt((x - a[0] - ab[0] * t) ** 2 + (y - a[1] - ab[1] * t) ** 2 + (z - a[2] - ab[2] * t) ** 2)
    return d - (ra + (rb - ra) * t)


def _smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def _smax(a, b, k):
    return -_smin(-a, -b, k)


def head_sdf(x, y, z):
    """Negative inside the head (arrays of metres, rest pose)."""
    ax = np.abs(x)
    d = _base(x, y, z)
    # Brow ridge and cheekbones.
    d = _smin(d, _ell(ax, y, z, (0.018, 0.08, 1.636), (0.03, 0.012, 0.011)), 0.014)
    d = _smin(d, _ell(ax, y, z, (0.04, 0.058, 1.597), (0.018, 0.018, 0.012)), 0.018)
    # Eye sockets, then the eyeballs under the lids.
    d = _smax(d, -_ell(ax, y, z, (0.031, 0.098, 1.61), (0.018, 0.015, 0.011)), 0.01)
    d = _smin(d, _ell(ax, y, z, (0.031, 0.071, 1.609), (0.0135, 0.0135, 0.0105)), 0.006)
    # The nose: bridge to tip, and the wings.
    nose = _cone(ax, y, z, (0.0, 0.083, 1.625), (0.0, 0.113, 1.579), 0.008, 0.0098)
    nose = _smin(nose, _ell(ax, y, z, (0.0125, 0.097, 1.5715), (0.009, 0.009, 0.0072)), 0.006)
    d = _smin(d, nose, 0.02)
    # Lips and chin.
    d = _smin(d, _ell(ax, y, z, (0.0, 0.094, 1.553), (0.02, 0.0095, 0.0066)), 0.007)
    d = _smin(d, _ell(ax, y, z, (0.0, 0.092, 1.541), (0.017, 0.0095, 0.0072)), 0.007)
    d = _smin(d, _ell(ax, y, z, (0.0, 0.083, 1.519), (0.02, 0.013, 0.013)), 0.01)
    return d


HEAD_C = np.array([0.0, -0.005, 1.605])


def _dirs(az_el):
    a = np.radians(np.array([p[0] for p in az_el]))
    e = np.radians(np.array([p[1] for p in az_el]))
    return np.stack([np.cos(e) * np.cos(a), np.cos(e) * np.sin(a), np.sin(e)], axis=1)


def head_radius(dirs):
    """Distance from HEAD_C to the head's surface along each unit direction
    (its outermost crossing)."""
    n = len(dirs)
    lo, hi = np.zeros(n), np.full(n, 0.17)
    found = np.zeros(n, bool)
    prev = 0.17
    for t in np.arange(0.168, 0.0, -0.002):
        p = HEAD_C + dirs * t
        inside = head_sdf(p[:, 0], p[:, 1], p[:, 2]) < 0
        new = inside & ~found
        lo[new], hi[new] = t, prev
        found |= inside
        prev = t
    for _ in range(22):
        mid = (lo + hi) / 2
        p = HEAD_C + dirs * mid[:, None]
        inside = head_sdf(p[:, 0], p[:, 1], p[:, 2]) < 0
        lo, hi = np.where(inside, mid, lo), np.where(inside, hi, mid)
    return (lo + hi) / 2


# Rows (elevation from HEAD_C, degrees) and columns (azimuth about Z, 90 is
# the front): fine over the face, coarse behind and at the poles.
ROWS = [-72, -60, -52, -46, -40, -35, -31, -28.5, -26, -23.5, -21, -18, -15, -12, -8.5, -5, -1, 3, 7,
        11.5, 17, 23, 29, 37, 47, 60, 75]
FINE_ROWS = (-53.0, 30.0)
FINE_COLS = [0, 5, 10, 16, 23, 32, 44, 60, 84, 120, 180]
COARSE_COLS = [0, 22, 46, 72, 100, 130, 160, 180]


def _cols(offsets):
    """Azimuths 90 +- each offset, as keys from the back (0) round through
    the character's right (90), the front (180) and left (270)."""
    keys = sorted({round((90.0 + s * o - 270.0) % 360.0, 6) for o in offsets for s in (-1, 1)})
    return keys


def _zip(bm, ra, rb):
    """Triangles joining two closed rings of (key, vert), keys ascending
    from 0."""
    i = j = 0
    na, nb = len(ra), len(rb)
    while i < na or j < nb:
        an = ra[i + 1][0] if i + 1 < na else 360.0
        bn = rb[j + 1][0] if j + 1 < nb else 360.0
        if i < na and (j >= nb or an <= bn):
            bm.faces.new([ra[i][1], ra[(i + 1) % na][1], rb[j % nb][1]])
            i += 1
        else:
            bm.faces.new([ra[i % na][1], rb[(j + 1) % nb][1], rb[j][1]])
            j += 1


def _orient(bm, centre):
    """Turns every face of a star-shaped shell outwards from `centre`."""
    bm.normal_update()
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median() - Vector(centre)) < 0:
            f.normal_flip()
    bm.normal_update()


def _head_bm():
    """The head as a bmesh (triangles), and per vertex (position, normal)."""
    rings = []
    for el in ROWS:
        keys = _cols(FINE_COLS if FINE_ROWS[0] <= el <= FINE_ROWS[1] else COARSE_COLS)
        rings.append([(k, (k + 270.0) % 360.0, el) for k in keys])
    flat = [(az, el) for ring in rings for _, az, el in ring] + [(0.0, -90.0), (0.0, 90.0)]
    d = _dirs(flat)
    pts = HEAD_C + d * head_radius(d)[:, None]
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(p)) for p in pts]
    k = 0
    vrings = []
    for ring in rings:
        vrings.append([(key, vs[k + i]) for i, (key, _, _) in enumerate(ring)])
        k += len(ring)
    bottom, top = vs[k], vs[k + 1]
    for ra, rb in zip(vrings, vrings[1:]):
        _zip(bm, ra, rb)
    for ring, pole in ((vrings[0], bottom), (vrings[-1], top)):
        n = len(ring)
        for i in range(n):
            bm.faces.new([ring[i][1], ring[(i + 1) % n][1], pole])
    _orient(bm, HEAD_C)
    return bm


def _face_plate(bm, arm):
    """The face plate: the head's front faces 1.2 mm proud, UV-mapped by a
    front projection to the atlas's top-left cell."""
    off = {v: v.co + v.normal * 0.0012 for v in bm.verts}

    def ok(v):
        p = off[v]
        return (FACE_BOTTOM + 1e-4 <= p.z <= FACE_TOP - 1e-4 and abs(p.x) <= 0.072
                and v.normal.y > 0.15 and p.y > 0.02)

    pb = bmesh.new()
    uv = pb.loops.layers.uv.new()
    vmap = {}
    for f in bm.faces:
        if not all(ok(v) for v in f.verts):
            continue
        nv = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = pb.verts.new(off[v])
            nv.append(vmap[v])
        face = pb.faces.new(nv)
        for loop in face.loops:
            p = loop.vert.co
            u = 0.5 - p.x / (2 * FACE_HW)
            v = (FACE_TOP - p.z) / (FACE_TOP - FACE_BOTTOM)
            loop[uv].uv = (u / ATLAS_COLS, 1.0 - v / ATLAS_ROWS)
    me = bpy.data.meshes.new("face")
    pb.normal_update()
    pb.to_mesh(me)
    pb.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(lib.material("face"))
    obj = bpy.data.objects.new("face", me)
    bpy.context.scene.collection.objects.link(obj)
    for bone in low.BONES:
        obj.vertex_groups.new(name=bone)
    obj.vertex_groups["head"].add(list(range(len(me.vertices))), 1.0, "REPLACE")
    low.bind(obj, arm)
    return obj


def _merge_bm(mesh, bm, mat):
    """Merges a bmesh into a lib.Mesh with material `mat` (frees it)."""
    idx = mesh.slot(mat)
    vmap = {v: mesh.bm.verts.new(v.co) for v in bm.verts}
    for f in bm.faces:
        nf = mesh.bm.faces.new([vmap[v] for v in f.verts])
        nf.material_index = idx
    bm.free()


# ---- Hair: shells over the skull ----

def _interp_periodic(points, a):
    """Smooth (smoothstep) interpolation in a periodic table
    [(azimuth_deg, value)]."""
    pts = sorted((p % 360.0, v) for p, v in points)
    a = a % 360.0
    ext = [(pts[-1][0] - 360.0, pts[-1][1])] + pts + [(pts[0][0] + 360.0, pts[0][1])]
    for (a0, v0), (a1, v1) in zip(ext, ext[1:]):
        if a0 <= a <= a1:
            f = (a - a0) / (a1 - a0) if a1 > a0 else 0.0
            f = f * f * (3 - 2 * f)
            return v0 + (v1 - v0) * f
    return pts[0][1]


def _hair_shell(mesh, hairline, thick, cols=24, rows=7, lip=0.0015, bump=None):
    """A shell of hair over the skull: from the hairline (elevation in
    degrees from HEAD_C, a function of azimuth) up to the crown, `thick(az,
    s, el)` metres proud of the skin (s from 0 at the hairline to 1 at the
    crown), its edge turned in to the skin; `bump(column, row)` adds
    texture (curls, tufts)."""
    azs = [360.0 * k / cols - 90.0 for k in range(cols)]
    grid = []
    for az in azs:
        e0 = hairline(az)
        col = []
        for r in range(rows):
            s = r / rows
            col.append((az, e0 + (89.0 - e0) * s, s))
        grid.append(col)
    flat = [(az, el) for col in grid for az, el, _ in col] + [(az, hairline(az) + 1.5) for az in azs] + [(0.0, 90.0)]
    d = _dirs(flat)
    radius = head_radius(d)
    bm = bmesh.new()
    verts = []
    k = 0
    for c, col in enumerate(grid):
        vc = []
        for r, (az, el, s) in enumerate(col):
            t = thick(az, s, el) + (bump(c, r) if bump else 0.0)
            vc.append(bm.verts.new(tuple(HEAD_C + d[k] * (radius[k] + t))))
            k += 1
        verts.append(vc)
    inner = []
    for c in range(cols):
        inner.append(bm.verts.new(tuple(HEAD_C + d[k] * (radius[k] + lip))))
        k += 1
    crown = bm.verts.new(tuple(HEAD_C + d[k] * (radius[k] + thick(0.0, 1.0, 90.0))))
    for c in range(cols):
        c1 = (c + 1) % cols
        for r in range(rows - 1):
            bm.faces.new([verts[c][r], verts[c1][r], verts[c1][r + 1], verts[c][r + 1]])
        bm.faces.new([verts[c][rows - 1], verts[c1][rows - 1], crown])
        bm.faces.new([inner[c], inner[c1], verts[c1][0], verts[c][0]])
    _orient(bm, HEAD_C)
    _merge_bm(mesh, bm, "hair")


def _noise(seed, terms=5, scale=1.0):
    """A smooth pseudo-random function of (azimuth_deg, s), deterministic."""
    rng = random.Random(seed)
    waves = [(rng.randint(3, 9) * scale, rng.uniform(1.5, 5.0), rng.uniform(0, 2 * math.pi),
              rng.uniform(0, 2 * math.pi)) for _ in range(terms)]

    def f(az, s):
        a = math.radians(az)
        return sum(math.sin(m * a + p) * math.cos(q * math.pi * s + r) for m, q, p, r in waves) / terms
    return f


def _point_on_head(az, el, out):
    d = _dirs([(az, el)])
    return Vector(tuple(HEAD_C + d[0] * (head_radius(d)[0] + out)))


def _hairline(front, temple, side, ear, nape):
    """A hairline (azimuth -> elevation, degrees from HEAD_C): the front of
    the forehead, the temples, in front of the ear, above and behind it,
    and the nape."""
    pts = [(90.0, front), (74.0, front - 1.0), (106.0, front - 1.0), (58.0, temple), (122.0, temple),
           (22.0, side), (158.0, side), (-8.0, ear), (188.0, ear), (-40.0, (ear + nape) / 2),
           (220.0, (ear + nape) / 2), (-90.0, nape)]
    return lambda az: _interp_periodic(pts, az)


def _smooth01(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def _lock(mesh, pts, r0, flat=0.45, sides=5, hint=(0, 1, 0)):
    """A tapered lock of hair through `pts`, flattened (a ribbon `flat` of
    its width deep)."""
    n = len(pts)
    radii = [(max(r0 * (1 - k / (n - 1)) ** 0.8, 0.0012), max(r0 * flat * (1 - k / (n - 1)) ** 0.8, 0.001))
             for k in range(n)]
    low.sweep(mesh, pts, radii, "hair", sides=sides, hint=hint)


def _hair_bun(b):
    h = b.on("hair_0", "head")
    line = _hairline(47.0, 40.0, 14.0, 22.0, -30.0)
    wisp = _noise(3, 4)

    def thick(az, s, el=0.0):
        return 0.004 + 0.007 * _smooth01(s / 0.35) + 0.0015 * wisp(az, s)
    _hair_shell(h, line, thick, cols=22, rows=6)
    # The bun, high at the back, in two lumps.
    h.sphere(0.04, (0.0, -0.074, 1.73), "hair", subdivisions=2, scale=(1.0, 0.92, 0.84), jitter=0.05, seed=31)
    h.sphere(0.026, (0.02, -0.052, 1.754), "hair", subdivisions=1, scale=(1.0, 1.0, 0.9), jitter=0.06, seed=32)
    # Loose strands falling at the temples.
    for s in (-1, 1):
        pts = [_point_on_head(90 - s * 42, 40, 0.004), _point_on_head(90 - s * 50, 20, 0.007),
               _point_on_head(90 - s * 53, 0, 0.007), _point_on_head(90 - s * 52, -18, 0.005)]
        _lock(h, pts, 0.0065, hint=(s, 0.4, 0))


def _hair_short(b):
    h = b.on("hair_1", "head")
    line = _hairline(45.0, 36.0, 6.0, 18.0, -26.0)

    def thick(az, s, el=0.0):
        a = math.radians(az)
        front = max(0.0, math.sin(a))
        # Fuller on top, lifting off the forehead in a fringe.
        return 0.005 + 0.015 * _smooth01(s / 0.45) + 0.008 * front ** 2 * (1.0 - s) ** 0.5
    _hair_shell(h, line, thick, cols=24, rows=7, lip=0.003, bump=_curls(5, 0.005, 2, 5))
    # A fringe of locks swept to the person's left.
    for k in range(5):
        az = 62 + 14 * k
        root = _point_on_head(az, 64, 0.019)
        mid = _point_on_head(az + 12, 54, 0.021)
        tip = _point_on_head(az + 22, 45, 0.013)
        _lock(h, [root, mid, tip], 0.014, hint=(0, 0, 1))


def _hair_ponytail(b):
    h = b.on("hair_2", "head")
    line = _hairline(47.0, 39.0, 8.0, 14.0, -30.0)
    sheen = _noise(7, 4)

    def thick(az, s, el=0.0):
        return 0.005 + 0.007 * _smooth01(s / 0.4) + 0.001 * sheen(az, s)
    _hair_shell(h, line, thick, cols=22, rows=6)
    tie = Vector((0.0, -0.104, 1.64))
    h.cylinder(0.02, 0.022, tie + Vector((0, -0.008, 0)), "hair", sides=10, rot=lib.rotx(62))
    tail = [(-0.01, 0.004), (-0.03, -0.01), (-0.04, -0.06), (-0.036, -0.12), (-0.026, -0.18), (-0.018, -0.215)]
    low.sweep(h, [tie + Vector((0, y, z)) for y, z in tail],
              [(0.02, 0.016), (0.028, 0.022), (0.03, 0.022), (0.026, 0.019), (0.016, 0.012), (0.004, 0.004)],
              "hair", sides=8, hint=(0, -1, 0))


def _curls(seed, amp, start=1, stop=99):
    """Bumps on alternate vertices of a shell's grid rows start..stop:
    curls or tufts."""
    rng = random.Random(seed)
    table = {}

    def f(c, r):
        if (c, r) not in table:
            table[(c, r)] = rng.uniform(0.55, 1.0)
        return amp * table[(c, r)] if (c + r) % 2 == 0 and start <= r <= stop else 0.0
    return f


def _hair_curly(b):
    h = b.on("hair_3", "head")
    line = _hairline(41.0, 31.0, 2.0, -6.0, -30.0)

    def thick(az, s, el=0.0):
        return 0.018 + 0.022 * _smooth01(s / 0.45)
    _hair_shell(h, line, thick, cols=30, rows=9, lip=0.008, bump=_curls(9, 0.012, 1, 5))


# ---- Body ----

def _ring(rx, ryf, ryb, cy, n, sides, z, tilt=0.0):
    """Points of a cross-section: a superellipse of exponent n (the front
    half ryf deep, the back ryb), a vertex at the front centre; `tilt`
    raises the front and lowers the back (metres)."""
    e = 2.0 / n
    out = []
    for k in range(sides):
        a = math.pi / 2 + 2 * math.pi * k / sides
        c, s = math.cos(a), math.sin(a)
        ry = ryf if s > 0 else ryb
        out.append((rx * math.copysign(abs(c) ** e, c), cy + ry * math.copysign(abs(s) ** e, s), z + tilt * s))
    return out


def _at(rings, z):
    """(rx, ryf, ryb, cy, n) of a loft's rings at height z."""
    rs = sorted(rings)
    z = min(max(z, rs[0][0]), rs[-1][0])
    for r0, r1 in zip(rs, rs[1:]):
        if r0[0] <= z <= r1[0]:
            f = (z - r0[0]) / (r1[0] - r0[0]) if r1[0] > r0[0] else 0.0
            return tuple(a + (b_ - a) * f for a, b_ in zip(_full(r0)[1:], _full(r1)[1:]))
    return _full(rs[-1])[1:]


def _full(r):
    """(z, rx, ryf, ryb, cy, n) of a ring given as (z, rx, ryf, ryb[, cy[,
    n[, tilt]]])."""
    z, rx, ryf, ryb = r[:4]
    return (z, rx, ryf, ryb, r[4] if len(r) > 4 else 0.0, r[5] if len(r) > 5 else 2.0)


def _on(rings, z, a_deg, out=0.0):
    """The point on a loft's surface at height z and angle a (90 = front,
    0 = the person's right), pushed `out` along the section's normal."""
    rx, ryf, ryb, cy, n = _at(rings, z)
    a = math.radians(a_deg)
    c, s = math.cos(a), math.sin(a)
    e = 2.0 / n
    ry = ryf if s > 0 else ryb
    x, y = rx * math.copysign(abs(c) ** e, c), ry * math.copysign(abs(s) ** e, s)
    # The superellipse's normal there.
    nx = (abs(x) / rx) ** (n - 1) / rx * math.copysign(1, x) if x else 0.0
    ny = (abs(y) / ry) ** (n - 1) / ry * math.copysign(1, y) if y else 0.0
    ln = math.hypot(nx, ny) or 1.0
    return Vector((x + out * nx / ln, cy + y + out * ny / ln, z))


def loft(mesh, rings, mat, sides=20, caps=(True, True)):
    """A smooth body of revolution: rings (z, rx, ryf, ryb[, cy[, n]])
    bottom to top."""
    tmp = bmesh.new()
    loops = []
    for r in rings:
        z, rx, ryf, ryb, cy, n = _full(r)
        tilt = r[6] if len(r) > 6 else 0.0
        loops.append([tmp.verts.new(p) for p in _ring(rx, ryf, ryb, cy, n, sides, z, tilt)])
    low._bridge(tmp, loops, caps)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def limb(mesh, a, b, profile, mat, sides=12, caps=(True, True), hint=(0, 1, 0)):
    """A smooth tapered limb along a->b: profile [(t, rx[, ry])], t the
    fraction of the way from a to b (may run past either end); `caps`
    closes the ends (an open end tucked under another part shades clean)."""
    a, b = Vector(a), Vector(b)
    x, y, _ = low._frame(b - a, hint)
    phase = math.pi / 2 - math.pi / sides
    tmp = bmesh.new()
    loops = []
    for p in profile:
        c = a.lerp(b, p[0])
        rx, ry = p[1], p[2] if len(p) > 2 else p[1]
        loops.append([tmp.verts.new(c + x * u + y * w) for u, w, _ in low._ring(rx, ry, sides, phase)])
    low._bridge(tmp, loops, caps)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def patch(mesh, rings, mat, centre=90.0, columns=8, thickness=0.008, grow=0.0, inner=True):
    """A curved panel `grow` proud of a loft's surface: rings (z, half-angle
    degrees) over `rings`' sections, centred on `centre` (90 = front),
    `thickness` deep (inwards). Without `inner` it is the outer surface and
    its turned-in edges only (a panel lying on the body, never seen from
    inside)."""
    tmp = bmesh.new()
    outer, back = [], []
    for z, half, body in mesh_rings(rings):
        o_row, i_row = [], []
        for k in range(columns + 1):
            a = centre - half + 2 * half * k / columns
            o_row.append(tmp.verts.new(_on(body, z, a, grow)))
            i_row.append(tmp.verts.new(_on(body, z, a, grow - thickness)))
        outer.append(o_row)
        back.append(i_row)
    n = len(outer)
    # Wound so the outer surface faces out (angle anticlockwise, z up).
    for i in range(n - 1):
        for k in range(columns):
            tmp.faces.new([outer[i][k], outer[i][k + 1], outer[i + 1][k + 1], outer[i + 1][k]])
            if inner:
                tmp.faces.new([back[i][k], back[i + 1][k], back[i + 1][k + 1], back[i][k + 1]])
        tmp.faces.new([outer[i][0], outer[i + 1][0], back[i + 1][0], back[i][0]])
        tmp.faces.new([outer[i][columns], back[i][columns], back[i + 1][columns], outer[i + 1][columns]])
    for k in range(columns):
        tmp.faces.new([outer[0][k], back[0][k], back[0][k + 1], outer[0][k + 1]])
        tmp.faces.new([outer[n - 1][k], outer[n - 1][k + 1], back[n - 1][k + 1], back[n - 1][k]])
    if not inner:
        for v in [v for v in tmp.verts if not v.link_faces]:
            tmp.verts.remove(v)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def mesh_rings(spec):
    """(z, half, body_rings) triples, bottom to top, from (body_rings,
    [(z, half), ...])."""
    body, rows = spec
    return [(z, half, body) for z, half in sorted(rows)]


def _grow(rings, d, dy=None):
    return [(r[0], r[1] + d, r[2] + (d if dy is None else dy), r[3] + (d if dy is None else dy)) + tuple(r[4:])
            for r in rings]


# The shirt over the chest (chest bone) and the belly (spine bone), the
# trousers over the hips, the neck: (z, rx, ryf, ryb, cy, n[, tilt]).
CHEST = [
    (1.07, 0.152, 0.106, 0.098, 0.0, 2.2),
    (1.14, 0.155, 0.112, 0.099, 0.0, 2.2),
    (1.21, 0.159, 0.12, 0.1, 0.0, 2.2),
    (1.27, 0.161, 0.123, 0.101, 0.0, 2.2),
    (1.315, 0.163, 0.116, 0.1, 0.0, 2.2),
    (1.345, 0.178, 0.106, 0.097, -0.002, 2.3),
    (1.375, 0.198, 0.096, 0.092, -0.004, 2.3),
    (1.395, 0.188, 0.086, 0.086, -0.006, 2.3),
    (1.412, 0.155, 0.076, 0.08, -0.007, 2.2),
    (1.428, 0.1, 0.066, 0.072, -0.008, 2.0, -0.004),
    (1.446, 0.072, 0.058, 0.066, -0.009, 2.0, -0.008),
    (1.456, 0.063, 0.055, 0.064, -0.009, 2.0, -0.01),
]
BELLY = [
    (0.845, 0.178, 0.12, 0.132, 0.0, 2.2),
    (0.9, 0.172, 0.115, 0.124, 0.0, 2.2),
    (0.98, 0.16, 0.107, 0.104, 0.0, 2.2),
    (1.05, 0.151, 0.103, 0.095, 0.0, 2.2),
    (1.1, 0.146, 0.101, 0.093, 0.0, 2.2),
    (1.15, 0.14, 0.098, 0.09, 0.0, 2.2),
]
HIPS = [
    (0.762, 0.02, 0.03, 0.04, -0.004),
    (0.775, 0.1, 0.075, 0.085, -0.005, 2.0),
    (0.79, 0.14, 0.096, 0.106, -0.005, 2.2),
    (0.84, 0.16, 0.103, 0.113, -0.008, 2.2),
    (0.9, 0.154, 0.1, 0.104, -0.004, 2.2),
    (0.96, 0.148, 0.097, 0.097, 0.0, 2.2),
    (1.0, 0.145, 0.095, 0.093, 0.0, 2.2),
]
NECK = [(1.37, 0.062, 0.056, 0.062, -0.01), (1.43, 0.059, 0.053, 0.06, -0.008), (1.49, 0.056, 0.05, 0.058, -0.006),
        (1.54, 0.052, 0.048, 0.054, -0.008), (1.585, 0.044, 0.042, 0.044, -0.012)]


def _arm(sd):
    """The arm's joints (shoulder, elbow, wrist, tip), moved ARM_IN in."""
    s = 1 if sd == "r" else -1
    sh, el = J[f"upper_arm_{sd}"]
    _, wr = J[f"forearm_{sd}"]
    _, tip = J[f"hand_{sd}"]
    d = Vector((-s * ARM_IN, 0, 0))
    return [Vector(p) + d for p in (sh, el, wr, tip)]


def _body(b, look):
    long_sleeves = look.get("sleeves") == "long"
    skin = b.on("skin", "head")
    for s in (-1, 1):
        # Ears: a curved rim, the lobe below.
        pts = [(s * 0.071, -0.019, 1.633), (s * 0.077, -0.022, 1.623), (s * 0.08, -0.019, 1.605),
               (s * 0.078, -0.012, 1.587), (s * 0.074, -0.006, 1.574), (s * 0.071, -0.004, 1.567)]
        low.sweep(skin, pts, [(0.003, 0.007), (0.006, 0.014), (0.0068, 0.016), (0.0062, 0.013), (0.005, 0.008),
                              (0.003, 0.004)], "skin", sides=7, hint=(0, 1, 0))
    loft(b.on("skin", "neck"), NECK, "skin", sides=14, caps=(False, True))

    # The shirt.
    loft(b.on("top", "chest"), CHEST, "top", sides=18, caps=(False, True))
    loft(b.on("top", "spine"), BELLY, "top", sides=18, caps=(True, False))
    c = b.on("top", "chest")
    if long_sleeves:
        # A ribbed crew collar hugging the neck.
        loft(c, [(1.428, 0.078, 0.066, 0.076, -0.009, 2.0, -0.007), (1.446, 0.07, 0.061, 0.071, -0.009, 2.0, -0.009),
                 (1.462, 0.063, 0.057, 0.066, -0.009, 2.0, -0.01)], "top", sides=18, caps=(False, False))
    else:
        # A camp collar lying open round the neck, the throat bare.
        body = [(1.415, 0.125, 0.08, 0.088, -0.008), (1.466, 0.068, 0.058, 0.07, -0.009)]
        patch(c, (body, [(1.415, 150.0), (1.466, 146.0)]), "top", centre=270.0, columns=12, thickness=0.004,
              grow=0.004)
        for s in (-1, 1):
            p0 = _on(CHEST, 1.445, 90 - s * 32, 0.004)
            p1 = _on(CHEST, 1.42, 90 - s * 38, 0.005)
            p2 = _on(CHEST, 1.384, 90 - s * 7, 0.004)
            low.sweep(c, [p0, (p1 + p2) / 2, p2], [(0.01, 0.003), (0.02, 0.003), (0.006, 0.002)], "top", sides=6,
                      hint=(0, 1, 0))
        patch(b.on("skin", "chest"), (CHEST, [(1.384, 0.5), (1.405, 8.0), (1.425, 16.0), (1.446, 24.0)]), "skin",
              columns=4, thickness=0.001, grow=0.0012)

    # Trousers.
    loft(b.on("bottom", "hips"), HIPS, "bottom", sides=20)

    def side(sd, s):
        sh, el, wr, tip = _arm(sd)
        hip, knee = (Vector(p) for p in J[f"thigh_{sd}"])
        _, ankle = (Vector(p) for p in J[f"shin_{sd}"])
        up = b.on("top", f"upper_arm_{sd}")
        if long_sleeves:
            limb(up, sh, el, [(-0.21, 0.016), (-0.13, 0.034), (-0.05, 0.046), (0.06, 0.05), (0.4, 0.048),
                              (0.8, 0.047), (1.0, 0.047), (1.1, 0.046)], "top", sides=10, caps=(True, True))
            limb(b.on("top", f"forearm_{sd}"), el, wr, [(-0.1, 0.043), (0.05, 0.046), (0.4, 0.043), (0.8, 0.037),
                                                        (0.9, 0.036), (0.95, 0.031)], "top", sides=10,
                 caps=(True, True))
            limb(b.on("skin", f"forearm_{sd}"), el, wr, [(0.86, 0.024, 0.028), (1.06, 0.02, 0.025)], "skin",
                 sides=10, caps=(True, True))
        else:
            limb(up, sh, el, [(-0.21, 0.016), (-0.13, 0.034), (-0.05, 0.046), (0.06, 0.05), (0.3, 0.05),
                              (0.44, 0.052), (0.5, 0.053), (0.52, 0.047)], "top")
            limb(b.on("skin", f"upper_arm_{sd}"), sh, el, [(0.3, 0.046), (0.7, 0.043), (0.95, 0.039),
                                                           (1.06, 0.033)], "skin", sides=10, caps=(True, True))
            limb(b.on("skin", f"forearm_{sd}"), el, wr, [(-0.06, 0.037), (0.04, 0.042), (0.3, 0.04, 0.039),
                                                         (0.7, 0.032, 0.03), (0.97, 0.021, 0.027),
                                                         (1.06, 0.02, 0.025)], "skin", sides=10, caps=(True, True))
        # The hand: palm and fingers together, curled towards the palm, and a
        # thumb set apart in front.
        hand = b.on("skin", f"hand_{sd}")
        w = wr + Vector((0, 0.004, 0))
        low.sweep(hand, [w + Vector((0, 0, 0.01)), w + Vector((0, 0.005, -0.045)),
                         w + Vector((-s * 0.002, 0.008, -0.088)), w + Vector((-s * 0.01, 0.008, -0.125)),
                         w + Vector((-s * 0.024, 0.005, -0.15))],
                  [(0.019, 0.027), (0.019, 0.042), (0.016, 0.043), (0.012, 0.036), (0.007, 0.024)], "skin", sides=8,
                  hint=(0, 1, 0))
        low.sweep(hand, [w + Vector((-s * 0.006, 0.02, -0.02)), w + Vector((-s * 0.014, 0.044, -0.052)),
                         w + Vector((-s * 0.021, 0.05, -0.08))],
                  [(0.012, 0.012), (0.01, 0.01), (0.007, 0.007)], "skin", sides=6, hint=(0, 1, 0))
        # Trouser legs: the thigh's hem lies over the shin's top.
        limb(b.on("bottom", f"thigh_{sd}"), hip, knee, [(-0.17, 0.062, 0.07), (-0.06, 0.08, 0.086), (0.05, 0.086, 0.09),
                                                         (0.3, 0.08),
                                                         (0.6, 0.071), (0.9, 0.063), (1.0, 0.061), (1.08, 0.059)],
             "bottom", caps=(True, True))
        hem = [(0.86, 0.05), (0.88, 0.055), (0.93, 0.055), (0.95, 0.049)] if look.get("cuffs") else \
            [(0.86, 0.049), (0.93, 0.048), (0.95, 0.043)]
        limb(b.on("bottom", f"shin_{sd}"), knee, ankle, [(-0.1, 0.053), (0.05, 0.058), (0.32, 0.057),
                                                          (0.6, 0.052)] + hem, "bottom", caps=(True, True))
        # A low sneaker on a rubber sole.
        x = hip.x - s * 0.002
        shoe = b.on("shoes", f"foot_{sd}")
        low.sweep(shoe, [(x, -0.084, 0.05), (x, -0.066, 0.066), (x, -0.02, 0.07), (x, 0.04, 0.06), (x, 0.1, 0.048),
                         (x, 0.15, 0.039), (x, 0.176, 0.032), (x, 0.186, 0.028)],
                  [(0.034, 0.028), (0.042, 0.04), (0.046, 0.046), (0.047, 0.038), (0.047, 0.028), (0.043, 0.02),
                   (0.032, 0.014), (0.014, 0.008)], "shoes", sides=10, hint=(0, 0, 1))
        low.sweep(b.on("details", f"foot_{sd}"), [(x, -0.094, 0.013), (x, -0.07, 0.012), (x, 0.03, 0.012),
                                                    (x, 0.15, 0.012), (x, 0.184, 0.013), (x, 0.196, 0.016)],
                  [(0.026, 0.012), (0.042, 0.012), (0.05, 0.012), (0.048, 0.012), (0.034, 0.012), (0.012, 0.008)],
                  "sole", sides=8, hint=(0, 0, 1))

    low._mirror(side)


# ---- Accessories ----

def _hat(b):
    """A straw sun hat: a pinched crown and a wide brim, over any hair."""
    hat = b.on("hat_sun", "head")
    cy, z0 = -0.012, 1.672
    loft(hat, [(z0 - 0.004, 0.112, 0.128, 0.128, cy), (z0 + 0.04, 0.108, 0.124, 0.124, cy),
               (z0 + 0.09, 0.1, 0.114, 0.114, cy), (z0 + 0.118, 0.084, 0.094, 0.094, cy, 2.4),
               (z0 + 0.126, 0.05, 0.05, 0.05, cy)], "straw", sides=16, caps=(False, True))
    loft(hat, [(z0 + 0.002, 0.1146, 0.1306, 0.1306, cy), (z0 + 0.026, 0.1122, 0.1282, 0.1282, cy)], "hat_band",
         sides=16, caps=(False, False))
    brim = [(z0 - 0.022, 0.2, 0.21, 0.21, cy), (z0 - 0.01, 0.19, 0.2, 0.2, cy), (z0, 0.12, 0.136, 0.136, cy)]
    # The brim: a thin, gently drooping ring, top and underside.
    tmp = bmesh.new()
    top_l, bot_l = [], []
    for z, rx, ryf, ryb, c in brim:
        top_l.append([tmp.verts.new(p) for p in _ring(rx, ryf, ryb, c, 2.0, 16, z)])
        bot_l.append([tmp.verts.new(p) for p in _ring(rx - 0.004, ryf - 0.004, ryb - 0.004, c, 2.0, 16, z - 0.006)])
    low._bridge(tmp, [bot_l[2], bot_l[1], bot_l[0], top_l[0], top_l[1], top_l[2]], caps=(False, False))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    hat._merge(tmp, "straw", None, (0, 0, 0))


def _backpack(b):
    pack = b.on("backpack", "chest")
    loft(pack, [(1.02, 0.13, 0.062, 0.07, -0.172, 4.0), (1.06, 0.14, 0.068, 0.076, -0.172, 4.0),
                (1.3, 0.136, 0.066, 0.074, -0.172, 4.0), (1.37, 0.12, 0.058, 0.064, -0.17, 3.0),
                (1.395, 0.09, 0.04, 0.046, -0.168, 2.4)], "backpack", sides=12)
    # The flap and a front pocket.
    loft(pack, [(1.24, 0.136, 0.07, 0.08, -0.172, 4.0), (1.345, 0.126, 0.066, 0.074, -0.17, 3.6),
                (1.382, 0.1, 0.05, 0.056, -0.168, 2.6)], "backpack", sides=12, caps=(False, True))
    loft(pack, [(1.05, 0.1, 0.02, 0.04, -0.23, 3.5), (1.19, 0.098, 0.02, 0.04, -0.232, 3.5)], "backpack", sides=12)
    for s in (-1, 1):
        pts = [_on(CHEST, 1.31, 270 + s * 30, 0.004) + Vector((0, 0.01, 0.0)),
               _on(CHEST, 1.395, 270 + s * 64, 0.006),
               _on(CHEST, 1.405, 90 - s * 58, 0.006),
               _on(CHEST, 1.34, 90 - s * 52, 0.007),
               _on(CHEST, 1.26, 90 - s * 36, 0.007),
               _on(CHEST, 1.2, 90 - s * 30, 0.007)]
        low.sweep(pack, pts, [(0.021, 0.004)] * len(pts), "strap", sides=4, hint=(0, 0, 1))
        low.sweep(pack, [_on(CHEST, 1.2, 90 - s * 30, 0.006), _on(CHEST, 1.14, 90 - s * 60, 0.006),
                         _on(CHEST, 1.1, 90 - s * 90, 0.006), Vector((s * 0.12, -0.11, 1.06))],
                  [(0.012, 0.003)] * 4, "strap", sides=4, hint=(0, 0, 1))


def _umbrella(b):
    """Held in the right hand and leaning in over the head; the pack opens
    it in the rain."""
    _, _, wr, tip = _arm("r")
    hand_at = wr.lerp(tip, 0.45) + Vector((-0.004, 0.012, 0.0))
    top_at = Vector((0.06, 0.03, 1.98))
    u = b.on("umbrella", "hand_r")
    low.sweep(u, [hand_at + Vector((0, 0, -0.02)), top_at], [(0.008, 0.008), (0.008, 0.008)], "iron", sides=6)
    low.sweep(u, [hand_at + Vector((0, 0, -0.02)), hand_at + Vector((0, 0, -0.07)),
                  hand_at + Vector((0, 0.03, -0.09)), hand_at + Vector((0, 0.05, -0.07))],
              [(0.011, 0.011)] * 4, "iron", sides=6)
    axis = (top_at - hand_at).normalized()
    turn = Vector((0, 0, 1)).rotation_difference(axis).to_matrix()
    # A canopy of eight panels, gently domed, closed underneath.
    tmp = bmesh.new()

    def rim(r, h):
        return [tmp.verts.new(turn @ Vector((r * math.cos(math.pi * k / 4), r * math.sin(math.pi * k / 4), h)))
                for k in range(8)]
    ring = [rim(r, h) for r, h in ((0.5, -0.1), (0.36, 0.0), (0.2, 0.06), (0.03, 0.09))]
    under = rim(0.46, -0.08)
    low._bridge(tmp, [under] + ring, caps=(True, True))
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    u._merge(tmp, "umbrella", None, top_at - axis * 0.09)
    u.sphere(0.016, top_at + axis * 0.012, "iron", subdivisions=1)


# ---- Extras ----

def _apron(b, look):
    """A maker's bib apron: the bib over the chest, the skirt to above the
    knee (on the hips, then half on each thigh), straps crossed behind, a
    pocket."""
    chest, belly = CHEST, BELLY
    patch(b.on("apron", "chest"), (chest, [(1.08, 44.0), (1.18, 42.0), (1.26, 40.0), (1.31, 38.0)]), "apron",
          columns=8, thickness=0.006, grow=0.007, inner=False)
    patch(b.on("apron", "spine"), (belly, [(0.95, 58.0), (1.02, 52.0), (1.1, 47.0), (1.14, 45.0)]), "apron",
          columns=8, thickness=0.006, grow=0.009, inner=False)
    skirt = [(1.0, 0.162, 0.118, 0.11, 0.0, 2.2), (0.93, 0.176, 0.124, 0.12, 0.0, 2.2),
             (0.86, 0.184, 0.13, 0.12, 0.0, 2.2), (0.78, 0.19, 0.14, 0.12, 0.006, 2.2),
             (0.7, 0.194, 0.148, 0.12, 0.01, 2.2), (0.56, 0.2, 0.16, 0.12, 0.016, 2.2)]
    a = b.on("apron", "hips")
    patch(a, (skirt, [(1.0, 76.0), (0.93, 76.0), (0.86, 75.0), (0.79, 73.0), (0.73, 72.0)]), "apron", columns=10,
          thickness=0.006)
    # Below the hips the skirt rides the thighs, half on each: it opens in
    # the stride and lies in the lap when seated.
    for sd, s in (("l", -1), ("r", 1)):
        patch(b.on("apron", f"thigh_{sd}"), (skirt, [(0.56, 36.0), (0.63, 36.5), (0.71, 37.0), (0.8, 37.5)]),
              "apron", centre=90 - s * 34.0, columns=5, thickness=0.006, grow=-0.003)
    patch(a, (skirt, [(0.78, 24.0), (0.83, 24.0), (0.88, 24.0)]), "apron", columns=5, thickness=0.004, grow=0.004,
          inner=False)
    # Waist ties round the back.
    patch(a, (_grow(HIPS, 0.028), [(0.975, 104.0), (0.995, 104.0)]), "apron", centre=270.0, columns=10,
          thickness=0.004, inner=False)
    for s in (-1, 1):
        pts = [_on(chest, 1.305, 90 - s * 36, 0.008), _on(chest, 1.39, 90 - s * 40, 0.006),
               _on(chest, 1.412, 90 - s * 70, 0.005), _on(chest, 1.395, 270 + s * 50, 0.005),
               _on(chest, 1.3, 270 + s * 20, 0.005), _on(chest, 1.15, 270 - s * 18, 0.005),
               _on(chest, 1.09, 270 - s * 38, 0.005)]
        low.sweep(b.on("apron", "chest"), pts, [(0.011, 0.003)] * len(pts), "apron", sides=4, hint=(0, 0, 1))


def _jacket(b, look):
    """An open zip jacket over the top: panels round the torso, open at the
    front, a stand collar, sleeves over the top's, a hem band."""
    chest = _grow(CHEST[:-2], 0.013)
    belly = _grow(BELLY, 0.014)
    j = b.on("jacket", "chest")
    patch(j, (chest, [(r[0], 160.0) for r in chest]), "jacket", centre=270.0, columns=16, thickness=0.01,
          inner=False)
    patch(b.on("jacket", "spine"), (belly, [(r[0], 160.0) for r in belly]), "jacket", centre=270.0, columns=16,
          thickness=0.01, inner=False)
    collar = [(1.38, 0.112, 0.094, 0.1, -0.008), (1.47, 0.076, 0.07, 0.078, -0.01)]
    patch(j, (collar, [(1.4, 146.0), (1.47, 142.0)]), "jacket", centre=270.0, columns=14, thickness=0.006)

    def side(sd, s):
        sh, el, wr, _ = _arm(sd)
        low.limb(b.on("jacket", f"upper_arm_{sd}"), sh, el, [(-0.22, 0.026), (-0.13, 0.05), (-0.04, 0.061),
                                                              (0.06, 0.064), (0.5, 0.061), (1.0, 0.057),
                                                              (1.1, 0.054)], "jacket", sides=10)
        low.limb(b.on("jacket", f"forearm_{sd}"), el, wr, [(-0.1, 0.056), (0.05, 0.057), (0.5, 0.053),
                                                            (0.8, 0.047), (0.86, 0.046), (0.9, 0.04)],
                 "jacket", sides=10)

    low._mirror(side)


def _hood(b, look):
    """The hood lying down: a thick roll round the back of the neck and the
    hood's body slumped on the upper back."""
    h = b.on("hood", "chest")
    pts = []
    radii = []
    for k in range(11):
        t = k / 10
        a = math.radians(50 - 280 * t)  # from the front right, round the back, to the front left
        back = math.sin(math.pi * t)
        r = 0.076 + 0.042 * back
        pts.append(Vector((r * math.cos(a), -0.012 + r * math.sin(a), 1.436 + 0.018 * back)))
        radii.append((0.018 + 0.02 * back, 0.016 + 0.014 * back))
    low.sweep(h, pts, radii, "jacket", sides=8, hint=(0, 0, 1))
    h.sphere(1.0, (0.0, -0.134, 1.325), "jacket", subdivisions=2, scale=(0.096, 0.034, 0.1))


def _scarf(b, look):
    """A knitted scarf wound round the neck, both ends down the front."""
    s_ = b.on("scarf", "chest")
    loft(s_, [(1.4, 0.064, 0.058, 0.068, -0.006), (1.41, 0.092, 0.09, 0.094, -0.004),
              (1.435, 0.1, 0.098, 0.1, -0.002), (1.46, 0.095, 0.092, 0.096, -0.002),
              (1.478, 0.077, 0.072, 0.078, -0.004), (1.486, 0.06, 0.056, 0.064, -0.006)], "scarf", sides=14,
         caps=(False, False))
    for dx, end, wide in ((-0.03, 1.15, 0.036), (0.022, 1.21, 0.033)):
        a = 90 - math.degrees(math.asin(max(-1, min(1, dx / 0.16))))
        pts = [_on(CHEST, 1.41, a, 0.034), _on(CHEST, 1.36, a, 0.026), _on(CHEST, 1.29, a - 2, 0.024),
               _on(CHEST, end, a - 4, 0.022)]
        low.sweep(s_, pts, [(wide * 0.85, 0.014), (wide, 0.011), (wide, 0.011), (wide * 1.05, 0.011)], "scarf",
                  sides=8, hint=(0, 1, 0))


EXTRAS = {"apron": _apron, "jacket": _jacket, "hood": _hood, "scarf": _scarf}


# ---- Far body ----

def far_body(arm, look):
    """One merged, simplified body for the distant crowd, surfaces named by
    role (skin, top, bottom, shoes, hair) as the near parts."""
    b = low.Body()
    f = "far"
    loft(b.on(f, "head"), [(1.505, 0.03, 0.09, 0.02, 0.05), (1.54, 0.06, 0.1, 0.06, 0.0),
                           (1.61, 0.073, 0.094, 0.1, -0.01), (1.67, 0.072, 0.086, 0.1, -0.016)], "skin", sides=8)
    loft(b.on(f, "head"), [(1.63, 0.082, 0.07, 0.112, -0.016), (1.7, 0.074, 0.084, 0.1, -0.016),
                           (1.748, 0.012, 0.012, 0.012, -0.016)], "hair", sides=8, caps=(False, True))
    loft(b.on(f, "neck"), [(1.38, 0.058, 0.054, 0.06, -0.008), (1.54, 0.052, 0.048, 0.054, -0.008)], "skin",
         sides=6, caps=(False, False))
    loft(b.on(f, "chest"), [(1.08, 0.153, 0.107, 0.098), (1.27, 0.162, 0.123, 0.101), (1.375, 0.196, 0.096, 0.092),
                            (1.45, 0.064, 0.056, 0.064)], "top", sides=8)
    loft(b.on(f, "spine"), [(0.86, 0.174, 0.116, 0.11), (1.12, 0.146, 0.1, 0.093)], "top", sides=8)
    loft(b.on(f, "hips"), [(0.77, 0.07, 0.06, 0.06), (0.86, 0.162, 0.104, 0.112)], "bottom", sides=8)
    long_sleeves = look.get("sleeves") == "long"

    def side(sd, s):
        sh, el, wr, _ = _arm(sd)
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        low.limb(b.on(f, f"upper_arm_{sd}"), sh, el, [(-0.12, 0.04), (0.1, 0.05), (1.05, 0.045)], "top", sides=5)
        low.limb(b.on(f, f"forearm_{sd}"), el, wr, [(0.0, 0.042), (1.0, 0.03), (1.6, 0.022)],
                 "top" if long_sleeves else "skin", sides=5)
        low.limb(b.on(f, f"thigh_{sd}"), hip, knee, [(-0.12, 0.08), (1.05, 0.06)], "bottom", sides=6)
        low.limb(b.on(f, f"shin_{sd}"), knee, ankle, [(0.0, 0.058), (1.0, 0.05)], "bottom", sides=6)
        b.on(f, f"foot_{sd}").box((0.098, 0.27, 0.07), (hip[0], 0.05, 0.035), "shoes")

    low._mirror(side)
    objs = b.build(arm)
    lib.smooth(objs[f], angle=70.0)
    return objs


# ---- The whole person ----

SMOOTH = {"shoes": 55.0, "details": 55.0, "backpack": 50.0, "umbrella": 40.0}


def build(look=None):
    """The complete person in the current scene: rig, parts (with the
    look's extras), far body and actions. `look`: {"sleeves": "short" |
    "long", "cuffs": bool, "extras": [...], "colours": {role: "#hex"}}."""
    look = dict(look or {})
    for role, colour in {**ROLES, **look.get("colours", {})}.items():
        if role in look.get("colours", {}):
            lib.PALETTE[role] = colour
        else:
            lib.PALETTE.setdefault(role, colour)
    for role, rough in ROUGH.items():
        lib.ROUGHNESS.setdefault(role, rough)
    arm = low.build_rig("human")
    b = low.Body()
    head = _head_bm()
    plate_src = head.copy()
    _merge_bm(b.on("skin", "head"), head, "skin")
    _body(b, look)
    _hair_bun(b)
    _hair_short(b)
    _hair_ponytail(b)
    _hair_curly(b)
    _hat(b)
    _backpack(b)
    _umbrella(b)
    for name in look.get("extras", []):
        EXTRAS[name](b, look)
    objs = b.build(arm)
    for name, o in objs.items():
        lib.smooth(o, angle=SMOOTH.get(name, 75.0))
    plate_src.normal_update()
    objs["face"] = _face_plate(plate_src, arm)
    plate_src.free()
    far_body(arm, look)
    low.add_actions(arm, "human")
    return arm, objs
