"""Cel-shaded anime characters: skinned, animated people and agents on the
low-poly kit's shared rig, moving with its generated walk, idle, sit and
typing (imported, not copied), so they behave as in every style.

    character_anime   a resident: skin, top, bottom, shoes, details (belt),
                      hair_0 (tied-up bun with loose strands), hair_1 (short,
                      tousled), hair_2 (ponytail), hair_3 (curly), hat_sun,
                      backpack, face, and far (one merged, simplified body
                      for the distant crowd, its surfaces named by role)
    agent_anime       an agent guide: the same body in the uniform, a white
                      open jacket (jacket) over a blue shirt (top), the leaf
                      badge and an ID card (badge), the same hair and face

Anime proportions on the shared skeleton: a larger head with a small,
pointed chin, slimmer limbs, smooth shading (the pack draws toon light and
ink outlines). Parts are rigidly skinned, one bone each, as in the low-poly
kit; sleeves and trouser legs overlap the joints so bends stay closed.

The face is a plate just proud of the head's front, UV-mapped to one cell
(the top-left) of face_atlas.png (faces.py: expressions across, variants
down). u runs across the face as the viewer sees it, v from brow to chin;
the pack's face shader picks the cell per person and blinks.

Axes, origin, bones and actions: see the low-poly characters module.
"""
import importlib.util
import math
from pathlib import Path

import bpy
from mathutils import Vector

import lib

_LOW = Path(__file__).resolve().parents[1] / "lowpoly" / "characters.py"
_spec = importlib.util.spec_from_file_location("lowpoly_characters", _LOW)
low = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(low)

J = low.JOINTS["human"]
SIDES = 16

lib.PALETTE.update({
    "top": "#3E6FCF", "bottom": "#3A4466", "shoes": "#F4F1EA", "belt": "#2E2B3A",
    "straw": "#E8CD8C", "hat_band": "#C9573A", "backpack": "#3F6A55",
    "jacket": "#F7F4EE", "jacket_lining": "#2F5FC0", "badge": "#2F64C9", "badge_leaf": "#F7F4EE",
    "card": "#F7F4EE", "face": "#F1C9A8", "sole": "#D9D3C7", "hair_tie": "#E4513B", "umbrella": "#E4513B",
})

# (z, rx, ry, cy): the anime head, chin to crown; bigger cranium, small
# pointed chin, the face flatter than the skull.
HEAD = [
    (1.41, 0.03, 0.024, 0.074),
    (1.432, 0.07, 0.06, 0.056),
    (1.465, 0.106, 0.098, 0.034),
    (1.51, 0.13, 0.124, 0.016),
    (1.57, 0.142, 0.139, 0.003),
    (1.632, 0.147, 0.147, -0.007),
    (1.686, 0.132, 0.138, -0.014),
    (1.722, 0.09, 0.1, -0.014),
    (1.743, 0.026, 0.032, -0.012),
]
# The face plate spans this much of the head's front, and these heights.
FACE_HALF = 62.0
FACE_TOP, FACE_BOTTOM = 1.662, 1.44
ATLAS_COLS, ATLAS_ROWS = 5, 4


def _head_at(z):
    """(rx, ry, cy) of the head surface at height z."""
    for r0, r1 in zip(HEAD, HEAD[1:]):
        if r0[0] <= z <= r1[0]:
            f = (z - r0[0]) / (r1[0] - r0[0])
            return tuple(r0[k] + (r1[k] - r0[k]) * f for k in (1, 2, 3))
    raise ValueError(z)


def face_plate(arm):
    """The face plate: a curved grid just proud of the head, UV-mapped to
    the atlas's top-left cell, skinned to the head."""
    import bmesh
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rows, cols = 14, 16
    grid = []
    for i in range(rows + 1):
        v = i / rows
        z = FACE_TOP + (FACE_BOTTOM - FACE_TOP) * v
        rx, ry, cy = _head_at(z)
        row = []
        for k in range(cols + 1):
            u = k / cols
            # u = 0 is the viewer's left: the character's right (+X).
            a = math.radians(90.0 - FACE_HALF + 2 * FACE_HALF * u)
            row.append((bm.verts.new(((rx + 0.0022) * math.cos(a), cy + (ry + 0.0022) * math.sin(a), z)), u, v))
        grid.append(row)
    for i in range(rows):
        for k in range(cols):
            a, b, c, d = grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]
            f = bm.faces.new([a[0], d[0], c[0], b[0]])
            for loop, (_, u, v) in zip(f.loops, [a, d, c, b]):
                loop[uv].uv = (u / ATLAS_COLS, 1.0 - v / ATLAS_ROWS)
    me = bpy.data.meshes.new("face")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
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


def _lock(mesh, points, r0, r1=0.0, sides=6, mat="hair", hint=(0, 1, 0), flat=0.45):
    """A tapered lock of hair along `points`, from radius r0 to a point,
    flattened to a ribbon (`flat` of its width deep, toward `hint`)."""
    n = len(points)
    radii = []
    for k in range(n):
        t = k / (n - 1)
        r = r0 + (r1 - r0) * t ** 1.2
        radii.append((max(r, 0.0015), max(r * flat, 0.0012)))
    low.sweep(mesh, points, radii, mat, sides=sides, hint=hint)


def _cap_rings(z0, grow, top=0.03, crown=0.034):
    """Rings over the skull from a hairline at z0: `grow` proud there,
    swelling to `crown` at the top, anime hair's volume."""
    rings = []
    zs = [r[0] for r in HEAD if r[0] >= z0]
    for z, rx, ry, cy in HEAD:
        if z >= z0:
            f = (z - z0) / max(HEAD[-1][0] - z0, 1e-3)
            g = grow + (crown - grow) * f
            rings.append((z, rx + g, ry + g, cy - 0.008))
    rings.append((HEAD[-1][0] + top, 0.05, 0.058, -0.014))
    del zs
    return rings


def _on_head(a_deg, z, out=0.02):
    """A point `out` proud of the head at angle a (90 = front) and height z."""
    rx, ry, cy = _head_at(min(max(z, HEAD[0][0] + 0.001), HEAD[-1][0] - 0.001))
    a = math.radians(a_deg)
    return Vector(((rx + out) * math.cos(a), cy + (ry + out) * math.sin(a), z))


def _bangs(h, count=7, reach=1.605, spread=55.0, part=None, seed=1):
    """Pointed locks swept from the crown down over the forehead, fanning
    across the front; `part` (degrees) leaves a parting there."""
    import random
    rng = random.Random(seed)
    for k in range(count):
        a = 90.0 - spread + 2 * spread * k / (count - 1)
        if part is not None and abs(a - part) < 6:
            continue
        start = _on_head(a + (a - 90) * 0.1, 1.735, 0.03)
        mid = _on_head(a, 1.678, 0.038)
        tip_z = reach + 0.02 * rng.random() + 0.0004 * abs(a - 90)
        tip = _on_head(a + (a - 90) * 0.12, tip_z, 0.026)
        _lock(h, [start, mid, tip], 0.036 + 0.008 * rng.random(), hint=(tip - Vector((0, -0.01, tip.z))))


def _side_locks(h, down_to=1.47, angle=74.0):
    """Two long locks framing the face, from the temples to the jaw."""
    for s in (-1, 1):
        a = 90 + s * angle
        pts = [_on_head(a, 1.7, 0.03), _on_head(a, 1.62, 0.03), _on_head(a + s * 4, 1.54, 0.024),
               _on_head(a + s * 2, down_to, 0.02)]
        _lock(h, pts, 0.032, hint=(math.cos(math.radians(a)), math.sin(math.radians(a)), 0))


def build_anime(arm, uniform=False):
    """The anime person's parts on `arm` (a build_rig('human') armature)."""
    b = low.Body()
    skin = b.on("skin", "head")
    low.loft(skin, HEAD, "skin", sides=SIDES)
    for s in (-1, 1):
        skin.sphere(0.024, (s * 0.14, 0.0, 1.565), "skin", subdivisions=2, scale=(0.5, 0.8, 1.2))
    b.on("skin", "neck").cylinder(0.045, 0.13, (0, 0.006, 1.415), "skin", sides=12)
    # Torso: a shirt, slimmer than the low-poly tee.
    chest = [(1.06, 0.158, 0.106, 0.0), (1.15, 0.165, 0.112, 0.006), (1.25, 0.18, 0.12, 0.012),
             (1.315, 0.19, 0.112, 0.006), (1.352, 0.174, 0.098, -0.002), (1.384, 0.13, 0.082, -0.004),
             (1.408, 0.066, 0.058, 0.0)]
    low.loft(b.on("top", "chest"), chest, "top", sides=SIDES)
    low.loft(b.on("top", "spine"), [(0.972, 0.162, 0.108, 0.0), (1.04, 0.156, 0.104, 0.0),
                                   (1.12, 0.16, 0.108, 0.0)], "top", sides=SIDES, caps=(True, False))
    # A collar.
    low.loft(b.on("top", "chest"), [(1.378, 0.1, 0.078, 0.004), (1.418, 0.074, 0.066, 0.008)], "top", sides=SIDES)
    low.loft(b.on("details", "hips"), [(0.94, 0.166, 0.112, 0.0), (0.975, 0.163, 0.11, 0.0)], "belt", sides=SIDES)
    low.loft(b.on("bottom", "hips"), [(0.745, 0.092, 0.07, -0.005), (0.80, 0.162, 0.106, -0.012),
                                      (0.88, 0.167, 0.11, -0.008), (0.96, 0.16, 0.106, 0.0)], "bottom", sides=SIDES)
    if uniform:
        # The agent's white open jacket: panels over the shirt, open at the
        # front, lined blue, with the leaf badge and an ID card.
        jacket = [(1.0, 0.176, 0.124, 0.0), (1.15, 0.18, 0.126, 0.006), (1.25, 0.194, 0.134, 0.012),
                  (1.315, 0.204, 0.126, 0.006), (1.352, 0.188, 0.112, -0.002), (1.39, 0.142, 0.094, -0.004)]
        low.patch(b.on("jacket", "chest"), [(z, rx, ry, cy, 146) for z, rx, ry, cy in jacket], "jacket",
                  centre=270, columns=18, thickness=0.014)
        # Lapels: the lining showing where the jacket folds back.
        for s_ in (-1, 1):
            low.patch(b.on("jacket", "chest"), [(z, rx + 0.002, ry + 0.002, cy, 5) for z, rx, ry, cy in jacket[1:]],
                      "jacket_lining", centre=90 + s_ * 40, columns=2, thickness=0.004)
        low.loft(b.on("jacket", "spine"), [(0.93, 0.18, 0.126, 0.0), (1.02, 0.174, 0.122, 0.0),
                                           (1.12, 0.176, 0.124, 0.0)], "jacket", sides=SIDES, caps=(False, False))
        badge = b.on("badge", "chest")
        badge.cylinder(0.026, 0.006, (-0.12, 0.118, 1.29), "badge", sides=14, rot=lib.rotx(90))
        badge.box((0.022, 0.004, 0.012), (-0.12, 0.123, 1.292), "badge_leaf", rot=lib.roty(35))
        badge.box((0.05, 0.004, 0.064), (0.11, 0.122, 1.19), "card", bevel=0.004)

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        _, tip = J[f"hand_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        sleeve = "jacket" if uniform else "top"
        low.limb(b.on(sleeve, f"upper_arm_{sd}"), sh, el, [(-0.12, 0.032), (-0.03, 0.058), (0.1, 0.066),
                                                            (0.5, 0.062), (1.02, 0.058), (1.08, 0.05)],
                 sleeve, sides=12)
        low.limb(b.on(sleeve, f"forearm_{sd}"), el, wr, [(-0.06, 0.056), (0.3, 0.054), (0.72, 0.05), (0.76, 0.044)],
                 sleeve, sides=12)
        low.limb(b.on("skin", f"forearm_{sd}"), el, wr, [(0.6, 0.036), (1.0, 0.03)], "skin", sides=10)
        hand = b.on("skin", f"hand_{sd}")
        mid = Vector(wr).lerp(Vector(tip), 0.42)
        hand.sphere(0.036, mid, "skin", subdivisions=2, scale=(0.62, 1.05, 1.55))
        hand.sphere(0.014, mid + Vector((-s * 0.014, 0.034, 0.012)), "skin", subdivisions=1, scale=(1, 1, 1.8))
        low.limb(b.on("bottom", f"thigh_{sd}"), hip, knee, [(-0.14, 0.082), (0.05, 0.088), (0.5, 0.076),
                                                             (1.0, 0.062), (1.1, 0.058)], "bottom", sides=12)
        low.limb(b.on("bottom", f"shin_{sd}"), knee, ankle, [(-0.1, 0.058), (0.05, 0.061), (0.4, 0.056),
                                                              (0.86, 0.052), (0.92, 0.056), (0.95, 0.05)],
                 "bottom", sides=12)
        x = hip[0] - s * 0.002
        shoe = b.on("shoes", f"foot_{sd}")
        low.sweep(shoe, [(x, -0.078, 0.05), (x, -0.05, 0.062), (x, 0.04, 0.06), (x, 0.13, 0.046), (x, 0.172, 0.032)],
                  [(0.04, 0.036), (0.049, 0.046), (0.052, 0.046), (0.049, 0.034), (0.03, 0.018)], "shoes",
                  sides=12, hint=(0, 0, 1))
        shoe.box((0.104, 0.262, 0.022), (x, 0.047, 0.011), "sole", bevel=0.008)
        shoe.cylinder(0.05, 0.08, (x, -0.012, 0.098), "shoes", sides=12, radius_top=0.047)

    low._mirror(side)

    # Hair: a cap and pointed locks; the four styles every pack draws.
    import random
    h0 = b.on("hair_0", "head")  # tied up: a round messy bun, loose strands
    low.loft(h0, _cap_rings(1.605, 0.02, crown=0.03), "hair", sides=SIDES, caps=(False, True))
    _bangs(h0, count=6, reach=1.6, spread=52, seed=3)
    _side_locks(h0, 1.48)
    h0.sphere(0.07, (0, -0.118, 1.728), "hair", subdivisions=2, scale=(1.0, 0.9, 0.86))
    rng = random.Random(4)
    for k in range(6):
        a = math.radians(20 + 28 * k)
        c = Vector((0.05 * math.cos(a), -0.118 - 0.035 * math.sin(a), 1.735 + 0.03 * math.sin(a)))
        d = Vector((math.cos(a), -0.6 * math.sin(a), 0.5 + 0.4 * rng.random())).normalized()
        _lock(h0, [c, c + d * 0.05, c + d * 0.08 + Vector((0, 0, -0.02))], 0.024)
    h0.cylinder(0.04, 0.022, (0, -0.088, 1.7), "hair_tie", sides=12, rot=lib.rotx(-50))
    for s_ in (-1, 1):
        _lock(h0, [_on_head(-90 + s_ * 30, 1.6, 0.02), _on_head(-90 + s_ * 34, 1.52, 0.016),
                   _on_head(-90 + s_ * 36, 1.46, 0.012)], 0.016)
    h1 = b.on("hair_1", "head")  # short, tousled
    low.loft(h1, _cap_rings(1.58, 0.024, crown=0.045), "hair", sides=SIDES, caps=(False, True))
    _bangs(h1, count=7, reach=1.62, spread=58, seed=5)
    for k in range(10):
        a = -80 + 36 * k
        if 60 < a < 120:
            continue
        top_ = _on_head(a, 1.69, 0.04)
        tip = _on_head(a, 1.59, 0.03) + Vector((0, 0, 0))
        _lock(h1, [top_, _on_head(a, 1.64, 0.045), tip], 0.036)
    h2 = b.on("hair_2", "head")  # sleek, a high ponytail
    low.loft(h2, _cap_rings(1.585, 0.015, crown=0.022), "hair", sides=SIDES, caps=(False, True))
    _bangs(h2, count=7, reach=1.605, spread=55, part=75, seed=7)
    _side_locks(h2, 1.46)
    h2.cylinder(0.026, 0.03, (0, -0.15, 1.69), "hair_tie", sides=12, rot=lib.rotx(70))
    _lock(h2, [Vector((0, -0.155, 1.7)), Vector((0, -0.205, 1.66)), Vector((0, -0.225, 1.56)),
               Vector((0, -0.21, 1.44)), Vector((0, -0.18, 1.33))], 0.052, 0.0, sides=10, flat=0.7)
    h3 = b.on("hair_3", "head")  # fluffy curls
    low.loft(h3, _cap_rings(1.58, 0.03, crown=0.04), "hair", sides=SIDES, caps=(False, True))
    rng = random.Random(9)
    for k in range(22):
        a = 360.0 * k / 22
        z = 1.6 + 0.12 * ((k * 7) % 5) / 4
        if 55 < a < 125 and z < 1.7:
            continue
        h3.sphere(0.042 + 0.012 * rng.random(), _on_head(a, z, 0.03), "hair", subdivisions=2)
    _bangs(h3, count=5, reach=1.63, spread=45, seed=11)

    # Accessories. The umbrella, held in the right hand and leaning in over
    # the head, opens in the rain (the pack shows it).
    hand_at = Vector(J["hand_r"][0]).lerp(Vector(J["hand_r"][1]), 0.45)
    top_at = Vector((0.06, 0.03, 1.98))
    shaft = b.on("umbrella", "hand_r")
    low.sweep(shaft, [hand_at, top_at + (hand_at - top_at) * 0.02], [(0.009, 0.009), (0.009, 0.009)], "iron", sides=6)
    shaft.sphere(0.02, hand_at + Vector((0, 0, -0.02)), "iron", subdivisions=1)
    axis = (top_at - hand_at).normalized()
    turn = Vector((0, 0, 1)).rotation_difference(axis).to_matrix()
    # A shallow cone of ten panels, closed underneath.
    shaft.cylinder(0.5, 0.2, top_at - axis * 0.09, "umbrella", sides=10, radius_top=0.02, rot=turn)
    shaft.sphere(0.018, top_at + axis * 0.05, "iron", subdivisions=1)
    hat = b.on("hat_sun", "head")
    hat.cylinder(0.27, 0.025, (0, -0.004, 1.672), "straw", sides=24, radius_top=0.17)
    hat.cylinder(0.155, 0.1, (0, -0.004, 1.73), "straw", sides=20, radius_top=0.13)
    hat.cylinder(0.157, 0.028, (0, -0.004, 1.695), "hat_band", sides=20, radius_top=0.154)
    pack = b.on("backpack", "chest")
    pack.box((0.27, 0.13, 0.32), (0, -0.19, 1.19), "backpack", bevel=0.04)
    pack.box((0.19, 0.05, 0.13), (0, -0.266, 1.11), "backpack", bevel=0.02)
    for s in (-1, 1):
        low.sweep(pack, [(s * 0.1, -0.125, 1.33), (s * 0.105, -0.04, 1.41), (s * 0.11, 0.05, 1.395),
                         (s * 0.115, 0.112, 1.33), (s * 0.12, 0.13, 1.22), (s * 0.13, 0.1, 1.10)],
                  [(0.02, 0.007)] * 6, "backpack", sides=6, hint=(0, 0, 1))
    objs = b.build(arm)
    for o in objs.values():
        lib.smooth(o, angle=60.0)
    objs["face"] = face_plate(arm)
    return objs


def far_body(arm):
    """One merged, simplified body for the distant crowd: a low loft per
    region, surfaces named by role (skin, top, bottom, shoes, hair) so the
    pack paints them as the near parts."""
    b = low.Body()
    low.loft(b.on("far", "head"), [(z, rx, ry, cy) for z, rx, ry, cy in HEAD[::2]], "skin", sides=8)
    low.loft(b.on("far", "head"), _cap_rings(1.6, 0.02)[::2], "hair", sides=8, caps=(False, True))
    low.loft(b.on("far", "chest"), [(1.06, 0.16, 0.108, 0.0), (1.3, 0.19, 0.114, 0.0), (1.41, 0.07, 0.06, 0.0)],
             "top", sides=8)
    low.loft(b.on("far", "spine"), [(0.96, 0.16, 0.106, 0.0), (1.12, 0.16, 0.108, 0.0)], "top", sides=8)
    low.loft(b.on("far", "hips"), [(0.76, 0.1, 0.07, 0.0), (0.96, 0.162, 0.106, 0.0)], "bottom", sides=8)

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        low.limb(b.on("far", f"upper_arm_{sd}"), sh, el, [(0.0, 0.055), (1.05, 0.05)], "top", sides=5)
        low.limb(b.on("far", f"forearm_{sd}"), el, wr, [(0.0, 0.048), (1.1, 0.035)], "skin", sides=5)
        low.limb(b.on("far", f"thigh_{sd}"), hip, knee, [(-0.1, 0.08), (1.05, 0.06)], "bottom", sides=5)
        low.limb(b.on("far", f"shin_{sd}"), knee, ankle, [(0.0, 0.058), (1.0, 0.05)], "bottom", sides=5)
        x = hip[0]
        b.on("far", f"foot_{sd}").box((0.1, 0.25, 0.08), (x, 0.04, 0.04), "shoes")

    low._mirror(side)
    objs = b.build(arm)
    lib.smooth(objs["far"], angle=60.0)
    return objs


def _character(uniform):
    arm = low.build_rig("human")
    build_anime(arm, uniform)
    far_body(arm)
    low.add_actions(arm, "human")


def character_anime():
    _character(False)


def agent_anime():
    _character(True)


ASSETS = {
    "character_anime": character_anime,
    "agent_anime": agent_anime,
}
ANIMATED = set(ASSETS)
