"""Vegetation for the solarpunk kit, after the 09 sheets: the tree square's
great banyan, round broadleaf street trees, palms in three sizes, shrubs,
a colourful flowerbed and planters.

The anime kit (tools/styles/anime/vegetation.py) fixes every piece's name,
pivot, extent and nodes, and its foliage (clumped, puffy broadleaf crowns,
darker underneath and sunlit on top; arching palm fronds) already fits the
sheets: its palms and shrubs build here in the solarpunk palette, and its
street trees are kept here in their committed design, so this kit's look
holds while that kit's foliage changes. Lit and physically based, the sun
paints each crown's sunlit top itself, so each leaf clump is one green
(`leaves`; the anime kit paints a lighter cap on each), smooth-shaded, its
normals leaning toward the whole crown's so the crown reads as one soft
form.

Rebuilt here: the banyan, with aerial roots hanging from its limbs, a
timber seat ring on a pale stone base, and a `lights` node of fairy_glow
bulbs strung through its crown, which the pack lights at night; the
flowerbed in a white ceramic kerb with pink, coral, yellow and white
flowers; a timber crate planter; and a white ceramic pot.

Conventions as the anime kit's: Blender Z-up, pieces face +Y (Godot -Z);
the origin is the centre of the footprint on the ground; each asset is an
empty named after it parenting one merged mesh, `body`, and the banyan's
`canopy` and `lights` besides. The banyan's seat ring is 0.5 m high, a
sitting height.
"""
import contextlib
import importlib.util
import math
import random
import sys
from pathlib import Path

from mathutils import Vector

from lib import Mesh

import foliage  # noqa: E402  (tools/styles/shared: the kits' leaf-card crowns)
import usables  # noqa: E402  (tools/styles/shared: the meadow's clumps)

# How densely the great tree's crown is leaved (foliage.crown's cover),
# leaving room in its budget for the fairy lights.
CROWN_COVER = 4.2

_ANIME = Path(__file__).resolve().parents[1] / "anime"


def _anime(name):
    """The anime kit's module `name`, loaded by path under `anime_<name>`
    (its `import lib` is this kit's lib, so it builds in this palette)."""
    key = "anime_" + name
    if key not in sys.modules:
        spec = importlib.util.spec_from_file_location(key, _ANIME / f"{name}.py")
        mod = importlib.util.module_from_spec(spec)
        sys.modules[key] = mod
        spec.loader.exec_module(mod)
    return sys.modules[key]


A = _anime("vegetation")
add, puff, tube, fit, finish, tone, leafy, flower, ring_wall = (
    A.add, A.puff, A.tube, A.fit, A.finish, A.tone, A.leafy, A.flower, A.ring_wall)


@contextlib.contextmanager
def swapped(mapping):
    """While active, every palette colour a Mesh takes is swapped by
    `mapping` ({old: new}), so a reused builder paints in new materials."""
    slot = Mesh.slot

    def swap(self, mat):
        return slot(self, mapping.get(mat, mat))

    Mesh.slot = swap
    try:
        yield
    finally:
        Mesh.slot = slot


def restyled(build, mapping):
    """`build` (a reused builder) with its colours swapped by `mapping`."""
    def run():
        with swapped(mapping):
            build()
    run.__doc__ = build.__doc__
    return run


def leaves(m, centre, radii, n, clump, seed, lo=-0.3, seg=8, rings=5, lump=0.08, crown=None, caps=False):
    """The anime kit's leaf mass (`n` clumps over an ellipsoid round a
    dark core), each clump in one green by where it sits on the crown;
    `caps` paints each clump's sunlit top a lighter green as the anime
    kit does. Lit, the sun paints that top itself, so caps are off."""
    rng = random.Random(seed)
    centre = Vector(centre)
    puff(m, centre, min(radii) * 0.95, "leaf_dark", scale=(radii[0] / min(radii), radii[1] / min(radii), 0.8),
         seed=seed, seg=5, rings=4, crown=crown)
    for k, d in enumerate(A._spread(n, lo)):
        p = centre + Vector((d.x * radii[0], d.y * radii[1], d.z * radii[2])) * rng.uniform(0.84, 1.0)
        mat, cap = tone(d.z, rng)
        puff(m, p, clump * rng.uniform(0.85, 1.15), mat, cap=cap if caps else None, scale=(1.1, 1.1, 0.9),
             seed=seed * 50 + k, seg=seg, rings=rings, lump=lump, crown=crown)


def bulb(m, at, r, mat="fairy_glow"):
    """A tiny glowing bulb: a tetrahedron of radius `r` (4 triangles),
    which the glow blooms into a point of light."""
    x, y, z = at
    k = r / math.sqrt(3)
    add(m, [(x + k, y + k, z + k), (x - k, y - k, z + k), (x - k, y + k, z - k), (x + k, y - k, z - k)],
        [(0, 2, 1), (0, 1, 3), (0, 3, 2), (1, 2, 3)], mat)


@contextlib.contextmanager
def _capless():
    """While active, the anime builders draw their leaf masses with
    `leaves`."""
    saved = A.mass
    A.mass = leaves
    try:
        yield
    finally:
        A.mass = saved


def capless(build):
    """`build` (a reused anime builder) with its crowns' leaf masses drawn
    by `leaves`, one green per clump."""
    def run():
        with _capless():
            build()
    run.__doc__ = build.__doc__
    return run


# ---- The great tree ----

SEAT = 0.5  # the seat ring's top: a sitting height


def tree_banyan():
    """The tree square's great banyan: a massive, fluted trunk flaring into
    buttress roots, forking at 3 m into great limbs that spread under a huge
    rounded crown of overlapping leaf clumps, darker underneath and sunlit
    on top; aerial roots hang from the limbs, the nearer ones grown down
    into the bed as slim pillars. Round it, a pale stone ring under a
    timber seat 0.5 m high holds a bed of leafy plants and flowers. Small
    fairy_glow bulbs strung through the crown (`lights`) twinkle at
    night."""
    rng = random.Random(3)
    body, canopy, lights = Mesh(), Mesh(), Mesh()
    # The seat ring: a pale stone wall under a timber seat, the bed inside.
    seg = 18
    ring_wall(body, 2.45, 2.12, 0.0, SEAT - 0.08, "stone", seg=seg)
    ring_wall(body, 2.56, 2.06, SEAT - 0.08, SEAT, "timber", seg=seg)
    add(body, [(2.12 * math.cos(2 * math.pi * k / seg), 2.12 * math.sin(2 * math.pi * k / seg), 0.36)
               for k in range(seg)], [tuple(range(seg))], "soil")
    for k in range(8):
        a = 2 * math.pi * (k + 0.3) / 8
        rr = 1.72 + 0.1 * (k % 2)
        puff(body, (rr * math.cos(a), rr * math.sin(a), 0.42), 0.36, ("leaf", "leaf_light")[k % 2],
             scale=(1.2, 1.2, 0.8), seed=500 + k, seg=6, rings=4, flat=0.6)
    for k in range(10):
        a = 2 * math.pi * (k + 0.5) / 10 + rng.uniform(-0.1, 0.1)
        rr = 1.9 + rng.uniform(-0.12, 0.08)
        flower(body, (rr * math.cos(a), rr * math.sin(a), 0.66 + rng.uniform(-0.04, 0.04)),
               ("flower_pink", "flower_yellow", "flower_coral", "flower_white")[k % 4], 0.1, seed=600 + k,
               petals=5)
    # Trunk: a buttressed, fluted column flaring into the bed.
    zs = [0.3, 0.8, 1.5, 2.3, 3.0, 3.5]
    rs = [1.26, 0.92, 0.78, 0.74, 0.76, 0.78]
    flare = [0.28, 0.16, 0.08, 0.05, 0.03, 0.0]
    pts = [(0.04 * math.sin(i), 0.03 * math.cos(i), z) for i, z in enumerate(zs)]
    tube(body, pts, rs, "trunk_light", sides=12, cap_end=False,
         shape=lambda k, i: 1 + flare[i] * math.cos(5 * 2 * math.pi * k / 12 + 0.4))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(body, [d * 0.8 + Vector((0, 0, 0.6)), d * 1.35 + Vector((0, 0, 0.42)), d * 1.75 + Vector((0, 0, 0.36))],
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
        # Aerial roots: one grown down into the bed as a slim pillar, two
        # hanging free from further out, clear of heads.
        top = p[1].lerp(p[2], 0.35)
        foot = Vector((top.x * 1.02, top.y * 1.02, 0.36))
        tube(body, [top, top.lerp(foot, 0.5) + d * 0.05, foot], [0.07, 0.06, 0.09], "trunk", sides=5)
        for t, drop in ((0.55, 2.2), (0.9, 1.6)):
            h = p[2].lerp(p[3], t - 0.5) if t > 0.5 else p[1].lerp(p[2], t * 2)
            h = h + s * 0.25 * (1 if t > 0.6 else -1)
            tube(body, [h, h + Vector((0.03, 0.02, -drop))], [0.035, 0.02], "trunk", sides=4)
        tips.append((a, reach, p, s))
    tube(body, [(0, 0, 3.2), (0.25, -0.1, 5.2), (0.1, 0.1, 7.0)], [0.5, 0.32, 0.12], "trunk_light", sides=8)
    # Roots out to the edges of the square the tree takes.
    A.square_roots(body, 2.56, 2.56, "trunk_light")
    # Crown: a leafy mass over each limb, a lower one hanging between each
    # pair, and rounded masses on top — leaf cards round dark cores
    # (tools/styles/shared/foliage.py), shaded as one great dome.
    lobes = []
    for k, (a, reach, _, _) in enumerate(tips):
        rr = 3.1 + 0.15 * (k % 2)
        lobes.append(((rr * math.cos(a), rr * math.sin(a), 5.6 + 0.3 * (k % 2)), (2.0, 2.0, 1.6)))
        b = a + math.pi / 5
        lobes.append(((3.6 * math.cos(b), 3.6 * math.sin(b), 5.0), (1.5, 1.5, 1.15)))
    for x, y, z in ((0.9, -0.8, 7.4), (-0.9, 0.9, 7.25), (0.2, 0.1, 8.0)):
        lobes.append(((x, y, z), (1.9, 1.9, 1.3)))
    foliage.crown(canopy, lobes, 1.25, seed=10, whole=((0, 0, 5.2), (5.6, 5.6, 3.8)), weight=0.4,
                  cover=CROWN_COVER, core_mat="leaf_dark")
    pad = 1.25 * foliage.MARGIN
    fit(canopy, 0, 11.9 + 2 * pad, 11.9 + 2 * pad, span=(4.5, 9.5 + pad), centre=(0, 0))
    _fairy_lights(lights, canopy, tips)
    finish("tree_banyan", {"body": body, "canopy": canopy, "lights": lights},
           smooth={"body": 50, "canopy": 50})


def _fairy_lights(lights, canopy, tips):
    """Bulbs over the crown's outer leaves, a few centimetres proud of
    them (chosen evenly round the crown, deterministically), and strings
    of them looped along each limb under the leaves."""
    centre = Vector((0, 0, 6.6))
    radii = Vector((5.95, 5.95, 2.9))
    canopy.bm.verts.ensure_lookup_table()
    best = {}
    for v in canopy.bm.verts:
        d = v.co - centre
        e = Vector((d.x / radii.x, d.y / radii.y, d.z / radii.z))
        if e.length < 0.7:
            continue
        # A cell on the crown by azimuth and height: its outermost vertex.
        az = int((math.atan2(d.y, d.x) + math.pi) / (2 * math.pi) * 18) % 18
        band = min(3, int((e.z + 1.0) * 2))
        key = (az, band)
        if key not in best or e.length > best[key][0]:
            best[key] = (e.length, v.co.copy(), e.normalized())
    for key in sorted(best):
        _, p, n = best[key]
        out = Vector((n.x / radii.x, n.y / radii.y, n.z / radii.z)).normalized()
        bulb(lights, p + out * 0.04, 0.05)
    for a, reach, p, s in tips:
        for k in range(5):
            t = (k + 0.5) / 5
            q = p[1].lerp(p[3], t)
            sag = 0.25 * math.sin(math.pi * ((k % 3) + 0.5) / 3)
            bulb(lights, q + s * (0.35 if k % 2 else -0.35) - Vector((0, 0, 0.3 + sag)), 0.05)


# ---- Street trees ----

def tree_round(name, height, spread, depth, clumps, seed):
    """A lush broadleaf street tree, as the anime kit's (its committed
    design, kept here so this kit's look holds while that kit's foliage
    changes): a slightly leaning trunk forking into three branches under a
    rounded crown of `clumps` leaf clumps, `spread` m across (x) and
    `depth` m deep (y), each clump in one green."""
    rng = random.Random(seed)
    m = Mesh()
    clump = min(spread, depth) * 0.125
    rx, ry = (spread / 2 - clump * 1.2) / 0.94, (depth / 2 - clump * 1.2) / 0.94
    rz = min(rx, ry) * 0.78
    cz = height - rz * 0.95 - clump * 0.95
    lean = rng.uniform(-0.12, 0.12)
    fork = cz - rz * 0.75
    r0 = 0.09 + 0.025 * height
    tube(m, [(0, 0, 0), (lean * 0.4, 0.02, fork * 0.55), (lean, 0.0, fork)], [r0, r0 * 0.78, r0 * 0.7],
         "trunk_light", sides=8, shape=lambda k, i: 1 + (0.2 * math.cos(3 * 2 * math.pi * k / 8) if i == 0 else 0))
    for k in range(3):
        a = 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
        tip = (lean + math.cos(a) * rx * 0.6, math.sin(a) * ry * 0.6, cz + rz * 0.2)
        tube(m, [(lean, 0, fork - 0.25), (lean + math.cos(a) * rx * 0.3, math.sin(a) * ry * 0.3, fork + 0.4), tip],
             [r0 * 0.6, r0 * 0.45, r0 * 0.2], "trunk_light", sides=6)
    crown = ((lean, 0, cz - rz * 0.3), (rx + clump, ry + clump, rz + clump), 0.4)
    first = len(m.bm.verts)
    leaves(m, (lean, 0, cz), (rx, ry, rz), clumps, clump, seed=seed, lo=-0.5, seg=9, rings=5, lump=0.06,
           crown=crown)
    fit(m, first, spread, depth, centre=(lean, 0))
    finish(name, {"body": m}, smooth={"body": 50})


# ---- Beds and planters ----

def flowerbed():
    """A 3 m x 1 m bed in a white ceramic kerb under a warm white coping,
    brimming with leafy mounds and pink, coral, yellow and white
    blossoms, as along the waterfront park's paths."""
    rng = random.Random(21)
    m = Mesh()
    w, d, h = 3.0, 1.0, 0.28
    with swapped({"stone_dark": "ceramic", "stone": "warm_white"}):
        A.kerb(m, w, d, h)
    m.box((w - 0.2, d - 0.2, 0.2), (0, 0, 0.12), "soil")
    mounds = []
    for k in range(7):
        x = -1.08 + k * 0.36
        y = 0.1 * (1 if k % 2 else -1)
        puff(m, (x, y, 0.22), 0.32, ("leaf", "leaf_light", "leaf_dark")[k % 3], scale=(1.2, 1.05, 0.85), seed=30 + k,
             seg=8, rings=4, flat=0.6, crown=((x, y, 0.1), (0.4, 0.35, 0.35), 0.3))
        mounds.append((x, y))
    colours = ["flower_pink", "flower_white", "flower_coral", "flower_yellow", "flower_pink", "flower_white"]
    for c in range(36):
        x, y = mounds[c % 7]
        a = rng.uniform(0, 2 * math.pi)
        rr = rng.uniform(0.06, 0.28)
        x, y = x + rr * math.cos(a) * 1.2, y + rr * math.sin(a) * 0.9
        colour = colours[c % len(colours)]
        top = 0.22 + 0.32 * 0.85 * math.sqrt(max(0.0, 1 - (rr / 0.38) ** 2))
        flower(m, (x, y, top + 0.02), colour, 0.13 if colour != "flower_white" else 0.15, seed=c,
               petals=6 if colour == "flower_white" else 5,
               centre="flower_coral" if colour == "flower_yellow" else "flower_yellow")
    finish("flowerbed", {"body": m}, smooth={"body": 50})


def planter_square():
    """A 1.2 m timber crate planter, as round the tree square: blonde
    boards between corner posts under a timber coping, a clipped shrub
    swelling over its rim, dotted with blossoms."""
    m = Mesh()
    s, h = 1.2, 0.6
    m.box((s - 0.1, s - 0.1, h - 0.06), (0, 0, (h - 0.06) / 2), "timber_dark")
    boards = 3
    bh = (h - 0.08) / boards
    for k in range(boards):
        z = 0.02 + bh * (k + 0.5)
        mat = "timber" if k % 2 else "timber_light"
        for sx in (-1, 1):
            m.box((0.03, s - 0.14, bh - 0.012), (sx * (s / 2 - 0.05), 0, z), mat)
        for sy in (-1, 1):
            m.box((s - 0.14, 0.03, bh - 0.012), (0, sy * (s / 2 - 0.05), z), mat)
    for sx in (-1, 1):
        for sy in (-1, 1):
            m.box((0.09, 0.09, h - 0.04), (sx * (s / 2 - 0.045), sy * (s / 2 - 0.045), (h - 0.04) / 2), "timber",
                  bevel=0.012)
    for sx in (-1, 1):
        m.box((0.1, s, 0.05), (sx * (s / 2 - 0.05), 0, h - 0.025), "timber_light")
    for sy in (-1, 1):
        m.box((s - 0.2, 0.1, 0.05), (0, sy * (s / 2 - 0.05), h - 0.025), "timber_light")
    m.box((s - 0.2, s - 0.2, 0.04), (0, 0, h - 0.03), "soil")
    # The shrub: a ring of clumps swelling over the rim under a rounded top.
    rng = random.Random(41)
    crown = ((0, 0, h + 0.3), (0.6, 0.6, 0.55), 0.45)
    first = len(m.bm.verts)
    for k in range(7):
        a = 2 * math.pi * k / 7
        mat, _ = tone(-0.1, rng)
        puff(m, (0.4 * math.cos(a), 0.4 * math.sin(a), h + 0.14), 0.24, mat, scale=(1.1, 1.1, 0.9),
             seed=410 + k, seg=8, rings=5, lump=0.05, crown=crown)
    leaves(m, (0, 0, h + 0.48), (0.3, 0.3, 0.24), 6, 0.26, seed=41, lo=-0.2, seg=8, rings=5, lump=0.05, crown=crown)
    fit(m, first, 1.18, 1.18, span=(h - 0.04, 1.4))
    for k in range(16):
        a = 2 * math.pi * k / 16 + 0.3
        rr = 0.18 + 0.14 * (k % 3)
        z = h + 0.24 + 0.52 * math.sqrt(max(0.0, 1 - (rr / 0.62) ** 2))
        flower(m, (rr * math.cos(a), rr * math.sin(a), z), ("flower_pink", "flower_yellow", "flower_white",
                                                            "flower_coral")[k % 4], 0.1, seed=420 + k)
    finish("planter_square", {"body": m}, smooth={"body": 50})


def _lathe(m, profile, mat, sides=16):
    """A surface of revolution about Z through `profile` [(r, z), ...],
    bottom to top, open at both ends (normals turned outward)."""
    verts, faces = [], []
    for r, z in profile:
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(len(profile) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append((i * sides + k, i * sides + k2, (i + 1) * sides + k2, (i + 1) * sides + k))
    add(m, verts, faces, mat)


def planter_pot():
    """A glazed white ceramic pot, bellied and rolled at the rim over a
    brass foot ring, with a leafy tropical plant."""
    m = Mesh()
    m.cylinder(0.19, 0.04, (0, 0, 0.02), "brass", sides=16)
    _lathe(m, [(0.2, 0.04), (0.25, 0.12), (0.285, 0.26), (0.285, 0.38), (0.27, 0.44), (0.3, 0.47), (0.3, 0.5)],
           "ceramic")
    _lathe(m, [(0.3, 0.5), (0.26, 0.5), (0.26, 0.47)], "ceramic")
    m.cylinder(0.26, 0.02, (0, 0, 0.47), "soil", sides=16)
    leafy(m, (0, 0, 0.48), 0.8, leaves=10, seed=51, lift=1.3)
    finish("planter_pot", {"body": m}, smooth={"body": 50})


# The meadow's tall grass and flowers (the anime kit builds the clumps).
MEADOW_LOOK = {"grass": "grass", "grass_dark": "grass_dark", "grass_light": "leaf_light", "stem": "leaf",
               "flowers": ["flower_coral", "flower_yellow", "flower_white", "flower_pink"], "flower_centre": "yellow"}


ASSETS = {
    "meadow_grass": usables.meadow("meadow_grass", 81, 0, MEADOW_LOOK, A.finish),
    "meadow_flowers": usables.meadow("meadow_flowers", 82, 4, MEADOW_LOOK, A.finish),
    "tree_banyan": tree_banyan,
    "tree_round_a": lambda: A.tree_round("tree_round_a", 5.5, 4.6, 5.2, 20, 71),
    "tree_round_b": lambda: A.tree_round("tree_round_b", 4.4, 3.4, 3.6, 17, 72),
    "tree_round_a_far": lambda: A.tree_round("tree_round_a_far", 5.5, 4.6, 5.2, 20, 71, far=True),
    "palm_a_far": lambda: A.palm("palm_a_far", 7.6, 1.1, 2.75, 12, 61, far=True),
    "palm_b_far": lambda: A.palm("palm_b_far", 5.7, 0.8, 2.3, 11, 62, far=True),
    "palm_c_far": lambda: A.palm("palm_c_far", 3.8, 0.45, 1.8, 10, 63, far=True),
    "tree_round_b_far": lambda: A.tree_round("tree_round_b_far", 4.4, 3.4, 3.6, 17, 72, far=True),
    "palm_a": lambda: A.palm("palm_a", 7.6, 1.1, 2.75, 12, 61),
    "palm_b": lambda: A.palm("palm_b", 5.7, 0.8, 2.3, 11, 62),
    "palm_c": lambda: A.palm("palm_c", 3.8, 0.45, 1.8, 10, 63),
    "shrub_round": A.shrub_round,
    "shrub_leafy": A.shrub_leafy,
    "flowerbed": flowerbed,
    "planter_square": planter_square,
    "planter_pot": planter_pot,
}

