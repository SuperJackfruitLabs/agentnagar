"""Vegetation for the neon noir kit, after the 10 sheets: the square's great
tree, up-lit and strung with warm lights through its crown; round street
trees; many dark palms; shrubs; a flower bed of violet and white blossoms;
dark planters, each with a warm uplight.

The shapes are the anime kit's, built here on the neon palette (deep
greens a shade darker than its sunlit ones, dark trunks, dark planters):
its street trees, palms, shrubs, bed and planters are its own builders,
live, so they follow its foliage; the great tree is drawn here, on the
anime kit's trunk and limbs and the kits' shared leaf-card crowns
(tools/styles/shared/foliage.py), to leave room in its budget for the
lights. Names, sizes, pivots and nodes match the anime
kit's, so the townscape plants this kit the same way: Blender Z-up, pieces
face +Y (Godot -Z), the origin is the centre of the footprint on the
ground, each asset an empty parenting `body` (the great tree's `canopy`
besides). The great tree's planter ring is 0.5 m high, a sitting height.

Glowing nodes (lamp_glow, which the pack scales by night):
    light   a lamp the pack may light (an OmniLight at the node's origin,
            which sits at the lamp): the planters' uplights
    lights  many small lamps, emission only: the great tree's bulbs,
            lanterns and uplights, the flower bed's spots

This module also holds the helpers the kit's scenery and props share:
`anime()` loads an anime kit module on this kit's lib and palette,
`recolour()` repaints built parts (leaf cards too), `pivot()` moves a
node's origin onto its lamp, `part()` adds a node to a built asset,
`bulb()` is a small glowing octahedron or tetrahedron.
"""
import importlib.util
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

import lib
from lib import Mesh

ANIME = Path(__file__).resolve().parents[1] / "anime"


def anime(name):
    """The anime kit's module `name`, run on this kit's lib (so its colours
    are the neon palette's, which shares the anime key names)."""
    key = f"neon_anime_{name}"
    if key not in sys.modules:
        spec = importlib.util.spec_from_file_location(key, ANIME / f"{name}.py")
        module = importlib.util.module_from_spec(spec)
        sys.modules[key] = module
        spec.loader.exec_module(module)
    return sys.modules[key]


A = anime("vegetation")
import foliage  # noqa: E402  (tools/styles/shared: the kits' leaf-card crowns)
import usables  # noqa: E402  (tools/styles/shared: the meadow's clumps)

# How many times over the great tree's crown lobes are covered in leaf
# cards: sets its leaves' share of the triangle budget.
CROWN_COVER = 2.7
# Leaves a shade darker than the anime kit's sunlit ones: deep greens.
DARKER = {"leaf_sun": "leaf_light", "leaf_light": "leaf"}
# The anime helpers used here, and those the anime props import from
# `vegetation` (which is this module in the neon build): add, finish,
# frond, puff.
add, puff, tube, frond, fit, finish, ring_wall = A.add, A.puff, A.tube, A.frond, A.fit, A.finish, A.ring_wall


# ---- Shared helpers ----

def _repaint(name, mapping):
    """The material for slot `name` under `mapping`: a palette colour, or
    a leaf card's `<colour>_leaves` (tools/styles/shared/foliage.py)."""
    if name.endswith("_leaves") and name[:-7] in mapping:
        return foliage.leaf_material(mapping[name[:-7]])
    return mapping.get(name, name)


def recolour(mapping, nodes=None):
    """Repaints the scene's meshes (or only those named in `nodes`): each
    palette colour in `mapping` becomes its value (leaf cards of that
    colour too); slots that end up the same colour merge."""
    for o in sorted(bpy.context.scene.objects, key=lambda o: o.name):
        if o.type != "MESH" or (nodes is not None and o.name not in nodes):
            continue
        me = o.data
        names = [m.name for m in me.materials]
        new = [_repaint(n, mapping) for n in names]
        if new == names:
            continue
        # Slots are repainted in place (clearing them would zero every
        # face's index); a slot repeating an earlier colour hands its faces
        # to that one and goes (popping shifts the later indices down).
        first, remap = {}, []
        for i, n in enumerate(new):
            me.materials[i] = bpy.data.materials[n] if n in bpy.data.materials else lib.material(n)
            remap.append(first.setdefault(n, i))
        for p in me.polygons:
            p.material_index = remap[p.material_index]
        for i in reversed(range(len(new))):
            if remap[i] != i:
                me.materials.pop(index=i)


def pivot(obj, at):
    """Moves `obj`'s origin to `at` (in its parent's frame) and leaves its
    geometry where it is, so the pack's lamp lands in the lamp."""
    at = Vector(at)
    obj.data.transform(Matrix.Translation(-at))
    obj.location = at
    return obj


def part(root_name, node, mesh, at=None, smooth=None):
    """Builds `mesh` as node `node` under the asset root `root_name`, its
    origin at `at`, smooth-shaded to `smooth` degrees if given."""
    o = mesh.build(node, bpy.data.objects[root_name])
    if smooth:
        lib.smooth(o, smooth)
    if at is not None:
        pivot(o, at)
    return o


def bulb(m, at, r, mat="lamp_glow", tetra=False):
    """A small glowing octahedron (or, cheaper, a tetrahedron) of radius
    `r` at `at`."""
    x, y, z = at
    if tetra:
        verts = [(x, y, z + r)] + [(x + 0.94 * r * math.cos(a), y + 0.94 * r * math.sin(a), z - r / 3)
                                   for a in (0, 2 * math.pi / 3, 4 * math.pi / 3)]
        add(m, verts, [(0, 1, 2), (0, 2, 3), (0, 3, 1), (3, 2, 1)], mat)
        return
    verts = [(x + r, y, z), (x - r, y, z), (x, y + r, z), (x, y - r, z), (x, y, z + r), (x, y, z - r)]
    faces = [(0, 2, 4), (2, 1, 4), (1, 3, 4), (3, 0, 4), (2, 0, 5), (1, 2, 5), (3, 1, 5), (0, 3, 5)]
    add(m, verts, faces, mat)


def rim_lights(m, verts_from, centre, bins, pick, rng, lift=0.07, r=0.075, zmax=None, down=0.35, tetra=False):
    """Bulbs on the outside of a crown: the canopy's vertices (from Mesh
    `verts_from`) binned by direction from `centre`, the outermost of each
    bin being on the crown's surface; `pick` bins are lit, chosen by `rng`
    among those whose direction's z is at most `down` (1 takes them all)."""
    c = Vector(centre)
    best = {}
    for v in verts_from.bm.verts:
        d = v.co - c
        if d.length < 1e-6:
            continue
        n = d.normalized()
        if n.z > down or (zmax is not None and v.co.z > zmax):
            continue
        key = (int((math.atan2(n.y, n.x) + math.pi) / (2 * math.pi) * bins[0]) % bins[0],
               min(int((n.z + 1) / 2 * bins[1]), bins[1] - 1))
        if key not in best or d.length > best[key][0]:
            best[key] = (d.length, v.co.copy(), n)
    keys = sorted(best)
    for key in rng.sample(keys, min(pick, len(keys))):
        _, p, n = best[key]
        bulb(m, p + n * lift, r, tetra=tetra)


# ---- The great tree ----

def tree_banyan():
    """The square's great tree, as the sheets light it: the anime kit's
    massive buttressed trunk and great limbs in its stone planter ring,
    under a huge leafy crown (leaf cards round dark cores, a lobe over each
    limb and two on top), strung with warm bulbs all over the crown and
    along the limbs, a lantern hanging from each limb, and uplights in the
    ring washing the trunk. The lights are one node, `lights`, its origin
    under the crown in front of the trunk, where one lamp would light the
    trunk, the crown's underside and the paving round it."""
    rng = random.Random(3)
    body, canopy, lights = Mesh(), Mesh(), Mesh()
    ring_wall(body, 2.45, 2.12, 0.0, 0.42, "stone", seg=24)
    ring_wall(body, 2.53, 2.05, 0.42, 0.5, "paving_light", seg=24)
    add(body, [(2.12 * math.cos(2 * math.pi * k / 24), 2.12 * math.sin(2 * math.pi * k / 24), 0.34)
               for k in range(24)], [tuple(range(24))], "grass")
    bed = []
    for k in range(10):
        a = 2 * math.pi * (k + 0.3) / 10
        rr = 1.75 + 0.1 * (k % 2)
        bed.append(((rr * math.cos(a), rr * math.sin(a), 0.42), (0.42, 0.42, 0.28)))
    foliage.crown(body, bed, 0.36, 500, whole=((0, 0, 0.2), (2.3, 2.3, 0.5)), weight=0.3, lo=-0.1, cover=1.1,
                  cores=False)
    zs = [0.3, 0.8, 1.5, 2.3, 3.0, 3.5]
    rs = [1.26, 0.92, 0.78, 0.74, 0.76, 0.78]
    flare = [0.28, 0.16, 0.06, 0.03, 0.02, 0.0]
    pts = [(0.04 * math.sin(i), 0.03 * math.cos(i), z) for i, z in enumerate(zs)]
    tube(body, pts, rs, "trunk_light", sides=12, cap_end=False,
         shape=lambda k, i: 1 + flare[i] * math.cos(5 * 2 * math.pi * k / 12 + 0.4))
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.4
        d = Vector((math.cos(a), math.sin(a), 0))
        tube(body, [d * 0.8 + Vector((0, 0, 0.6)), d * 1.35 + Vector((0, 0, 0.36)), d * 1.8 + Vector((0, 0, 0.3))],
             [0.3, 0.16, 0.06], "trunk_light", sides=6)
    tips, limbs = [], []
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
        limbs.append((p, d))
    tube(body, [(0, 0, 3.2), (0.25, -0.1, 5.2), (0.1, 0.1, 7.0)], [0.5, 0.32, 0.12], "trunk_light", sides=8)
    # Roots out to the edges of the square the tree takes.
    A.square_roots(body, 2.53, 2.53, "trunk_light")
    # The crown, as the anime kit's: a leafy mass over each limb, a lower
    # one hanging between each pair, and rounded masses on top, leaf cards
    # round dark cores shaded as one great dome; a little less densely
    # leaved, to leave room for the lights.
    lobes = []
    for k, (a, reach) in enumerate(tips):
        rr = 3.1 + 0.15 * (k % 2)
        lobes.append(((rr * math.cos(a), rr * math.sin(a), 5.7 + 0.3 * (k % 2)), (2.1, 2.1, 1.6)))
        b = a + math.pi / 5
        lobes.append(((3.7 * math.cos(b), 3.7 * math.sin(b), 5.1), (1.5, 1.5, 1.15)))
    for x, y, z in ((0.9, -0.8, 7.5), (-0.9, 0.9, 7.35), (0.2, 0.1, 8.1)):
        lobes.append(((x, y, z), (1.9, 1.9, 1.3)))
    foliage.crown(canopy, lobes, 1.25, seed=10, whole=((0, 0, 5.2), (5.6, 5.6, 3.8)), weight=0.4, cover=CROWN_COVER,
                  core_mat="leaf_dark")
    pad = 1.25 * foliage.MARGIN
    fit(canopy, 0, 11.9 + 2 * pad, 11.9 + 2 * pad, span=(4.5, 9.5 + pad), centre=(0, 0))
    # Bulbs all over the crown, one to a patch of it, set in among the
    # outermost leaves.
    rim_lights(lights, canopy, (0, 0, 6.6), (20, 6), 110, random.Random(31), lift=-0.3, r=0.12, down=1.0,
               tetra=True)
    # Bulbs strung along each great limb, just proud of its bark, and a
    # lantern hanging from each.
    for p, d in limbs:
        side = Vector((-d.y, d.x, 0))
        # (segment from p[s - 1] to p[s], how far along, the limb's radius there)
        for j, (s, t, r) in enumerate(((2, 0.2, 0.38), (2, 0.8, 0.29), (3, 0.45, 0.2))):
            at = p[s - 1].lerp(p[s], t)
            bulb(lights, at + side * (r + 0.07) * (1 if j % 2 else -1) - Vector((0, 0, r * 0.4)), 0.1, tetra=True)
        hang = p[2].lerp(p[3], 0.35)
        lights.box((0.22, 0.22, 0.05), hang - Vector((0, 0, 0.5)), "iron")
        lights.box((0.16, 0.16, 0.2), hang - Vector((0, 0, 0.625)), "lamp_glow")
    # Uplights in the ring's grass, turned in to wash the trunk.
    for k in range(3):
        a = 2 * math.pi * (k + 0.25) / 3
        at = Vector((1.55 * math.cos(a), 1.55 * math.sin(a), 0.42))
        lights.box((0.2, 0.2, 0.12), at - Vector((0, 0, 0.04)), "steel_dark", rot=lib.rotz(math.degrees(a)))
        lights.box((0.03, 0.14, 0.08), at + Vector((-0.1 * math.cos(a), -0.1 * math.sin(a), 0.0)), "lamp_glow",
                   rot=lib.rotz(math.degrees(a)))
    finish("tree_banyan", {"body": body, "canopy": canopy}, smooth={"body": 50, "canopy": 50})
    recolour(DARKER)
    part("tree_banyan", "lights", lights, at=(1.2, -1.4, 2.8))


# ---- Street trees, palms and shrubs: the anime kit's, in the neon greens ----


def tree_round(name, height, spread, depth, clumps, seed, far=False):
    def build():
        A.tree_round(name, height, spread, depth, clumps, seed, far=far)
        recolour(DARKER)
    build.__doc__ = A.tree_round.__doc__
    return build


def palm(name, height, lean, frond_len, fronds, seed, far=False):
    return lambda: A.palm(name, height, lean, frond_len, fronds, seed, far=far)


def shrub_round():
    """The anime kit's clipped round shrub, in the darker greens."""
    A.shrub_round()
    recolour(DARKER)


# ---- Beds and planters, with their lights ----

def flowerbed():
    """The anime kit's 3 m bed in its stone kerb, its blossoms the sheets'
    violet and white, and a little warm lamp on each corner of the kerb
    (`lights`), as on the waterfront park's planters."""
    A.flowerbed()
    recolour({**DARKER, "flower_pink": "flower_violet"})
    lights = Mesh()
    for x in (-1.45, 1.45):
        for y in (-0.45, 0.45):
            lights.box((0.08, 0.08, 0.1), (x, y, 0.33), "lamp_glow")
    part("flowerbed", "lights", lights, at=(0, 0, 0.33))


def planter_square():
    """The anime kit's stone planter box and clipped shrub, dark, with the
    sheets' warm light: a glowing strip in the shadow gap at its foot, and
    an uplight on the coping's front corner turned up into the shrub. The
    strip and the uplight are `light`, its origin at the uplight."""
    A.planter_square()
    recolour({**DARKER, "stone_dark": "concrete", "stone": "stone_dark"})
    glow = Mesh()
    s, h = 1.2, 0.6
    for sx, sy, w, d in ((0, 1, s - 0.14, 0.02), (0, -1, s - 0.14, 0.02), (1, 0, 0.02, s - 0.14),
                         (-1, 0, 0.02, s - 0.14)):
        glow.box((w, d, 0.03), (sx * (s - 0.1) / 2, sy * (s - 0.1) / 2, 0.035), "lamp_glow")
    x = y = s / 2 - 0.1
    glow.box((0.12, 0.12, 0.05), (x, y, h + 0.025), "steel_dark", bevel=0.01)
    # The lamp's head, tipped 20 degrees in toward the shrub.
    tilt = lib.rotz(-45) @ lib.rotx(20)
    head = Vector((x, y, h + 0.08))
    glow.cylinder(0.04, 0.08, head, "steel_dark", sides=8, rot=tilt)
    lens = head + tilt @ Vector((0, 0, 0.046))
    glow.cylinder(0.034, 0.012, lens, "lamp_glow", sides=8, rot=tilt)
    part("planter_square", "light", glow, at=lens)


def planter_pot():
    """The anime kit's pot and leafy tropical plant, the pot dark charcoal
    with a slate rim, and a little uplight clipped to the rim, glowing up
    into the leaves (`light`, its origin at the lamp)."""
    A.planter_pot()
    recolour({"terracotta": "charcoal", "terracotta_dark": "slate_dark"})
    glow = Mesh()
    a = math.radians(75)
    x, y = 0.27 * math.cos(a), 0.27 * math.sin(a)
    glow.box((0.06, 0.04, 0.1), (x, y, 0.47), "steel_dark", rot=lib.rotz(75 + 90))
    glow.cylinder(0.04, 0.07, (x, y, 0.55), "steel_dark", sides=8)
    glow.cylinder(0.035, 0.014, (x, y, 0.591), "lamp_glow", sides=8)
    part("planter_pot", "light", glow, at=(x, y, 0.6))


# The meadow's tall grass and flowers, in the night park's greens (the
# anime kit builds the clumps).
MEADOW_LOOK = {"grass": "grass", "grass_dark": "grass_dark", "grass_light": "leaf_light", "stem": "leaf_dark",
               "flowers": ["flower_violet", "flower_pink", "flower_yellow"], "flower_centre": "yellow"}


ASSETS = {
    "meadow_grass": usables.meadow("meadow_grass", 81, 0, MEADOW_LOOK, A.finish),
    "meadow_flowers": usables.meadow("meadow_flowers", 82, 4, MEADOW_LOOK, A.finish),
    "tree_banyan": tree_banyan,
    "tree_round_a": tree_round("tree_round_a", 5.5, 4.6, 5.2, 20, 71),
    "tree_round_b": tree_round("tree_round_b", 4.4, 3.4, 3.6, 17, 72),
    "tree_round_a_far": tree_round("tree_round_a_far", 5.5, 4.6, 5.2, 20, 71, far=True),
    "palm_a_far": palm("palm_a_far", 7.6, 1.1, 2.75, 12, 61, far=True),
    "palm_b_far": palm("palm_b_far", 5.7, 0.8, 2.3, 11, 62, far=True),
    "palm_c_far": palm("palm_c_far", 3.8, 0.45, 1.8, 10, 63, far=True),
    "tree_round_b_far": tree_round("tree_round_b_far", 4.4, 3.4, 3.6, 17, 72, far=True),
    "palm_a": palm("palm_a", 7.6, 1.1, 2.75, 12, 61),
    "palm_b": palm("palm_b", 5.7, 0.8, 2.3, 11, 62),
    "palm_c": palm("palm_c", 3.8, 0.45, 1.8, 10, 63),
    "shrub_round": shrub_round,
    "shrub_leafy": A.shrub_leafy,
    "flowerbed": flowerbed,
    "planter_square": planter_square,
    "planter_pot": planter_pot,
}

