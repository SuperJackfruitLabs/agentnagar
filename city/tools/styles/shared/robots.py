"""Robot agents for the lit styles (09 Solarpunk, 10 Neon noir), on the
low-poly kit's robot rig and motion (imported by path, not copied), so
they walk, sit, idle and type as agents do in every style.

build_robot(arm, look) builds the parts on a build_rig("robot") armature:

    shell     the glossy body shell: helmet, torso, hips, limbs, hands
    plate     (look "plates") contrasting limb and helmet side plates
    trim      rings and details: the visor rim, ear discs, cuffs, collar
    joint     dark joints between shell parts
    visor     the glossy dark face glass
    eyes      a plate just proud of the visor, UV-mapped to the first cell
              of eyes_atlas.png (one row of expressions, faces_real.py);
              the pack draws it emissive and picks the expression
    light     (look "side_light") an emissive strip on the helmet's side
    scarf     (look "scarf") a knitted scarf with tails down the front
    hoodie    (look "hoodie") a hooded top over the torso and arms
    badge     the leaf badge on an ID card
    umbrella  held in the right hand; the pack shows it in the rain
    far       one merged, simplified body for the distant crowd

`look` is a dict:
    helmet      "round" (solarpunk: a big round head, brass ear discs) or
                "sleek" (neon: an egg-shaped helmet with side plates)
    extras      a list of "scarf", "hoodie", "plates", "side_light"
    eye_at      the eyes plate's centre, degrees round the visor (90 is
                the middle; less is toward the robot's right)
    eye_span    the eyes plate's half-width in degrees
    eye_z       the eyes plate's (bottom, top) heights (default: the visor's)
    side_light  the palette colour of the side strip

Colours are the kit palette's roles, named as the parts are; the pack may
repaint them. Axes, origin, bones and actions: see the low-poly characters
module.
"""
import importlib.util
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

import lib

_LOW = Path(__file__).resolve().parents[1] / "lowpoly" / "characters.py"


def _load_low():
    saved = dict(lib.PALETTE)
    spec = importlib.util.spec_from_file_location("robots_lowpoly_characters", _LOW)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    # The low-poly characters module sets its own role colours; the kit's win.
    lib.PALETTE.update(saved)
    return m


low = _load_low()
J = low.JOINTS["robot"]
SIDES = 20
EYE_COLS = 5  # the eye atlas: expressions across, one row

def _dome(z0, cz, top, rx, ry, cy=0.0, lean=0.0, n=18):
    """Rings (z, rx, ry, cy) of a smooth helmet: an ellipsoid about height
    cz reaching `top`, cut flat at z0 (the chin), leaning back by `lean`
    towards the crown."""
    rz = top - cz
    rings = []
    a0 = math.asin(max(-1.0, (z0 - cz) / rz))
    for k in range(n + 1):
        a = a0 + (math.pi / 2 - a0) * k / n
        z = cz + rz * math.sin(a)
        c = max(math.cos(a), 0.04 if k < n else 0.0)
        rings.append((z, rx * c, ry * c, cy - lean * max(0.0, math.sin(a))))
    return rings


HELMETS = {
    # (z, rx, ry, cy): chin to crown.
    "round": _dome(1.338, 1.49, 1.678, 0.194, 0.188, 0.0, 0.007),
    "sleek": _dome(1.338, 1.49, 1.68, 0.18, 0.194, 0.004, 0.014),
}
# The visor: (z, half-angle) down the face, per helmet.
VISORS = {
    "round": [(1.405, 30), (1.425, 46), (1.47, 54), (1.53, 54), (1.565, 46), (1.585, 30)],
    "sleek": [(1.372, 48), (1.40, 68), (1.46, 78), (1.53, 78), (1.585, 66), (1.615, 44)],
}
TORSO = [(1.03, 0.158, 0.112, 0.0), (1.12, 0.182, 0.126, 0.006), (1.2, 0.2, 0.134, 0.01),
         (1.262, 0.21, 0.13, 0.006), (1.302, 0.182, 0.106, 0.0), (1.326, 0.1, 0.07, 0.0)]


def _at(rings, z):
    """(rx, ry, cy) of a loft's surface at height z (clamped to its ends)."""
    z = min(max(z, rings[0][0]), rings[-1][0])
    for r0, r1 in zip(rings, rings[1:]):
        if r0[0] <= z <= r1[0]:
            f = (z - r0[0]) / (r1[0] - r0[0])
            return tuple(r0[k] + (r1[k] - r0[k]) * f for k in (1, 2, 3))
    raise ValueError(z)


def _on(rings, a_deg, z, out):
    rx, ry, cy = _at(rings, z)
    a = math.radians(a_deg)
    return Vector(((rx + out) * math.cos(a), cy + (ry + out) * math.sin(a), z))


def _shell_patch(mesh, rings, spans, mat, out, thickness, centre=90.0, columns=14):
    """A plate over a loft's surface: `spans` are (z, half-angle) rows; the
    plate's outer face is `out` proud of the surface."""
    low.patch(mesh, [(z, *(_at(rings, z)[k] + (out if k < 2 else 0.0) for k in range(3)), half)
                     for z, half in spans], mat, centre=centre, columns=columns, thickness=thickness)


def eyes_plate(arm, rings, centre, span, z0, z1, out):
    """The eyes: a curved grid `out` proud of the helmet between heights z0
    and z1 and centre ± span degrees, UV-mapped to the eye atlas's first
    cell (u from the viewer's left, v from the top), skinned to the head."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    rows, cols = 6, 10
    grid = []
    for i in range(rows + 1):
        v = i / rows
        z = z1 + (z0 - z1) * v
        row = []
        for k in range(cols + 1):
            u = k / cols
            # u = 0 is the viewer's left: the robot's right (+X).
            row.append((bm.verts.new(_on(rings, centre - span + 2 * span * u, z, out)), u, v))
        grid.append(row)
    for i in range(rows):
        for k in range(cols):
            a, b, c, d = grid[i][k], grid[i][k + 1], grid[i + 1][k + 1], grid[i + 1][k]
            f = bm.faces.new([a[0], d[0], c[0], b[0]])
            for loop, (_, u, v) in zip(f.loops, [a, d, c, b]):
                loop[uv].uv = (u / EYE_COLS, 1.0 - v)
    me = bpy.data.meshes.new("eyes")
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(lib.material("visor"))
    obj = bpy.data.objects.new("eyes", me)
    bpy.context.scene.collection.objects.link(obj)
    for bone in low.BONES:
        obj.vertex_groups.new(name=bone)
    obj.vertex_groups["head"].add(list(range(len(me.vertices))), 1.0, "REPLACE")
    low.bind(obj, arm)
    return obj


def _helmet(b, look, rings):
    kind = look.get("helmet", "round")
    extras = set(look.get("extras", ()))
    low.loft(b.on("shell", "head"), rings, "shell", sides=28)
    visor = VISORS[kind]
    # The visor glass sits proud of the shell; a trim rim just behind it
    # frames it.
    rim = [(visor[0][0] - 0.014, visor[0][1] - 4)] + [(z, h + 5) for z, h in visor[1:-1]] + \
          [(visor[-1][0] + 0.014, visor[-1][1] - 4)]
    if kind == "round":
        _shell_patch(b.on("trim", "head"), rings, rim, "trim", 0.006, 0.02, columns=18)
    _shell_patch(b.on("visor", "head"), rings, visor, "visor", 0.012, 0.02, columns=18)
    trim = b.on("trim", "head")
    head_mid = 1.49
    rx, _, cy = _at(rings, head_mid)
    if kind == "round":
        # Brass ear discs, like headphones, with dark centres.
        for s in (-1, 1):
            trim.cylinder(0.068, 0.034, (s * (rx + 0.008), cy, head_mid), "trim", sides=20, rot=lib.roty(90))
            trim.cylinder(0.05, 0.012, (s * (rx + 0.028), cy, head_mid), "trim", sides=20, rot=lib.roty(90))
            b.on("joint", "head").cylinder(0.034, 0.01, (s * (rx + 0.035), cy, head_mid), "joint", sides=16,
                                           rot=lib.roty(90))
    else:
        # Side plates, a crest seam and a small side intake.
        plate = "plate" if "plates" in extras else "shell"
        for s, centre in ((1, 0.0), (-1, 180.0)):
            _shell_patch(b.on(plate, "head"), rings, [(1.385, 42), (1.43, 58), (1.52, 62), (1.58, 52), (1.62, 34)],
                         plate, 0.004, 0.016, centre=centre, columns=10)
            trim.cylinder(0.03, 0.014, (s * (rx + 0.018), cy - 0.02, head_mid - 0.02), "trim", sides=14,
                          rot=lib.roty(90))
        if "side_light" in extras:
            light = b.on("light", "head")
            for s in (-1, 1):
                pts = [_on(rings, 90 - s * 52 if s > 0 else 90 + 52, z, 0.014) for z in (1.44, 1.48, 1.52, 1.555)]
                low.sweep(light, pts, [(0.006, 0.004)] * len(pts), look.get("side_light", "neon_cyan"), sides=6)
    # A collar ring under the helmet.
    trim.cylinder(0.075, 0.03, (0, 0, 1.33), "trim", sides=18, radius_top=0.068)
    b.on("joint", "neck").cylinder(0.052, 0.1, (0, 0, 1.325), "joint", sides=14)


def _torso(b, look):
    extras = set(look.get("extras", ()))
    low.loft(b.on("shell", "chest"), TORSO, "shell", sides=SIDES)
    b.on("joint", "spine").cylinder(0.12, 0.13, (0, 0, 0.995), "joint", sides=16, radius_top=0.128)
    low.loft(b.on("shell", "hips"), [(0.735, 0.1, 0.074, -0.004), (0.795, 0.166, 0.11, -0.008),
                                     (0.875, 0.172, 0.114, -0.004), (0.962, 0.156, 0.105, 0.0)], "shell",
             sides=SIDES)
    if "hoodie" not in extras:
        # A trim belt line.
        low.loft(b.on("trim", "hips"), [(0.94, 0.162, 0.109, 0.0), (0.962, 0.16, 0.108, 0.0)], "trim", sides=SIDES)
    # The ID card with the leaf badge, on the chest's left.
    y, ang = low.surface(TORSO, SIDES, 1.17, -0.075)
    badge = b.on("badge", "chest")
    rot = lib.rotz(ang)
    at = Vector((-0.075, y + 0.03 if "hoodie" in extras else y + 0.006, 1.17))
    badge.box((0.066, 0.005, 0.092), at, "card", bevel=0.005, rot=rot)
    badge.cylinder(0.02, 0.004, at + Vector((0, 0.004, 0.012)), "badge", sides=16, rot=rot @ lib.rotx(90))
    badge.prism([(-0.013, 0.0), (0.0, 0.009), (0.014, 0.0), (0.0, -0.007)], 0.003,
                at + Vector((0, 0.007, 0.012)), "card", axis="y", rot=rot @ lib.roty(-40))
    badge.box((0.03, 0.004, 0.006), at + Vector((0, 0.004, -0.024)), "badge", rot=rot)
    # Lanyard up round the neck.
    low.sweep(badge, [at + Vector((0, 0.0, 0.046)), Vector((-0.06, 0.1, 1.28)), Vector((-0.05, 0.075, 1.33))],
              [(0.006, 0.002)] * 3, "badge", sides=4)


def _scarf(b):
    s = b.on("scarf", "chest")
    low.loft(s, [(1.31, 0.118, 0.1, 0.004), (1.335, 0.13, 0.112, 0.006), (1.365, 0.122, 0.105, 0.006),
                 (1.385, 0.1, 0.086, 0.004)], "scarf", sides=SIDES)
    # The knot at the robot's left collarbone, and two tails down the chest.
    s.sphere(0.036, (-0.062, 0.1, 1.33), "scarf", subdivisions=2, scale=(1.1, 0.8, 1.0))
    for dx, dy, end in ((-0.07, 0.126, 1.14), (-0.036, 0.132, 1.17)):
        pts = [Vector((dx + 0.01, 0.11, 1.32)), Vector((dx, dy, 1.25)), Vector((dx - 0.004, dy + 0.004, end))]
        low.sweep(s, pts, [(0.03, 0.009), (0.032, 0.01), (0.034, 0.01)], "scarf", sides=6, hint=(0, 1, 0))


def _hoodie(b, rings):
    h = b.on("hoodie", "chest")
    grow = 0.022
    low.loft(h, [(0.93, 0.172 + grow, 0.12 + grow, 0.0), (1.03, 0.166 + grow, 0.116 + grow, 0.0)] +
             [(z, rx + grow, ry + grow, cy) for z, rx, ry, cy in TORSO[1:5]] +
             [(1.338, 0.12, 0.096, 0.0)], "hoodie", sides=SIDES, caps=(True, False))
    # The hood: gathered behind the helmet, open at the front.
    hood = []
    for z, half in ((1.32, 150), (1.37, 128), (1.43, 116), (1.5, 106), (1.56, 96), (1.6, 80)):
        rx, ry, cy = _at(rings, z)
        hood.append((z, rx + 0.03, ry + 0.034, cy - 0.01, half))
    low.patch(b.on("hoodie", "chest"), hood, "hoodie", centre=270.0, columns=16, thickness=0.018)
    # The pocket and drawstrings.
    y, ang = low.surface(TORSO, SIDES, 1.08, 0.0)
    h.box((0.2, 0.014, 0.085), (0, y + grow + 0.006, 1.06), "hoodie_lining", bevel=0.01)
    for s in (-1, 1):
        low.sweep(h, [(s * 0.05, 0.118, 1.33), (s * 0.052, 0.15, 1.25), (s * 0.05, 0.152, 1.19)],
                  [(0.004, 0.004)] * 3, "card", sides=4)


def _limbs(b, look):
    extras = set(look.get("extras", ()))
    hooded = "hoodie" in extras
    plated = "plates" in extras
    cuff = "plate" if plated else "trim"

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        _, tip = J[f"hand_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        b.on("joint", f"upper_arm_{sd}").sphere(0.068, sh, "joint", subdivisions=2)
        upper = "hoodie" if hooded else "shell"
        low.limb(b.on(upper, f"upper_arm_{sd}"), sh, el,
                 [(-0.25, 0.05), (-0.12, 0.09), (0.06, 0.098), (0.5, 0.086) if not hooded else (0.5, 0.094),
                  (0.95, 0.074 if not hooded else 0.088), (1.05, 0.06 if not hooded else 0.084)],
                 upper, sides=14)
        b.on("joint", f"forearm_{sd}").sphere(0.06, el, "joint", subdivisions=2)
        if hooded:
            low.limb(b.on("hoodie", f"forearm_{sd}"), el, wr, [(-0.1, 0.082), (0.3, 0.08), (0.7, 0.078),
                                                               (0.74, 0.07)], "hoodie", sides=14)
        low.limb(b.on("shell", f"forearm_{sd}"), el, wr, [(0.1, 0.058), (0.4, 0.066), (0.8, 0.07)], "shell",
                 sides=14)
        low.limb(b.on(cuff, f"forearm_{sd}"), el, wr, [(0.74, 0.076), (0.97, 0.074), (1.02, 0.056)], cuff,
                 sides=14)
        hand = b.on("shell", f"hand_{sd}")
        mid = Vector(wr).lerp(Vector(tip), 0.45)
        hand.box((0.05, 0.086, 0.104), mid, "shell", bevel=0.02)
        hand.box((0.03, 0.032, 0.05), mid + Vector((-s * 0.013, 0.05, 0.02)), "shell", bevel=0.012,
                 rot=lib.rotx(-25))
        b.on("joint", f"thigh_{sd}").sphere(0.072, hip, "joint", subdivisions=2)
        low.limb(b.on("shell", f"thigh_{sd}"), hip, knee, [(0.1, 0.078), (0.22, 0.09), (0.6, 0.082), (0.9, 0.07)],
                 "shell", sides=14)
        b.on("joint", f"shin_{sd}").sphere(0.062, knee, "joint", subdivisions=2)
        b.on(cuff, f"shin_{sd}").box((0.1, 0.03, 0.095), Vector(knee) + Vector((0, 0.064, -0.035)), cuff,
                                     bevel=0.014, rot=lib.rotx(8))
        low.limb(b.on("plate" if plated else "shell", f"shin_{sd}"), knee, ankle,
                 [(0.12, 0.064), (0.4, 0.07), (0.8, 0.074), (0.95, 0.078)], "plate" if plated else "shell",
                 sides=14)
        x = hip[0]
        boot = b.on("shell", f"foot_{sd}")
        low.sweep(boot, [(x, -0.072, 0.062), (x, -0.04, 0.078), (x, 0.05, 0.072), (x, 0.135, 0.054),
                         (x, 0.17, 0.04)],
                  [(0.052, 0.046), (0.062, 0.058), (0.064, 0.052), (0.06, 0.038), (0.044, 0.024)], "shell",
                  sides=12, hint=(0, 0, 1))
        b.on("joint", f"foot_{sd}").box((0.124, 0.256, 0.026), (x, 0.05, 0.013), "joint", bevel=0.006)

    low._mirror(side)


def _umbrella(b):
    hand_at = Vector(J["hand_r"][0]).lerp(Vector(J["hand_r"][1]), 0.45)
    top_at = Vector((0.07, 0.03, 1.94))
    shaft = b.on("umbrella", "hand_r")
    low.sweep(shaft, [hand_at, top_at + (hand_at - top_at) * 0.02], [(0.009, 0.009), (0.009, 0.009)], "iron",
              sides=6)
    axis = (top_at - hand_at).normalized()
    turn = Vector((0, 0, 1)).rotation_difference(axis).to_matrix()
    shaft.cylinder(0.5, 0.2, top_at - axis * 0.09, "umbrella", sides=12, radius_top=0.02, rot=turn)
    shaft.sphere(0.018, top_at + axis * 0.05, "iron", subdivisions=1)


def build_robot(arm, look):
    """The robot's parts on `arm` (a build_rig("robot") armature), built as
    one rigidly skinned object per part name. Returns {name: object}."""
    lib.PALETTE.setdefault("umbrella", lib.PALETTE.get("coral", "#E4513B"))
    rings = HELMETS[look.get("helmet", "round")]
    b = low.Body()
    _helmet(b, look, rings)
    _torso(b, look)
    if "scarf" in look.get("extras", ()):
        _scarf(b)
    if "hoodie" in look.get("extras", ()):
        _hoodie(b, rings)
    _limbs(b, look)
    _umbrella(b)
    objs = b.build(arm)
    for name, o in objs.items():
        lib.smooth(o, angle=55.0)
    centre = look.get("eye_at", 90.0)
    span = look.get("eye_span", 44.0)
    visor = VISORS[look.get("helmet", "round")]
    z0, z1 = look.get("eye_z", (visor[1][0] + 0.006, visor[-2][0] - 0.004))
    objs["eyes"] = eyes_plate(arm, rings, centre, span, z0, z1, 0.0135)
    return objs


def far_body(arm, look):
    """One merged, simplified robot for the distant crowd, its surfaces
    named by role so the pack paints them as the near parts."""
    rings = HELMETS[look.get("helmet", "round")]
    hooded = "hoodie" in look.get("extras", ())
    b = low.Body()
    low.loft(b.on("far", "head"), rings[::2] + [rings[-1]], "shell", sides=8)
    _shell_patch(b.on("far", "head"), rings, VISORS[look.get("helmet", "round")][1:-1:2], "visor", 0.01, 0.02,
                 columns=4)
    body = "hoodie" if hooded else "shell"
    low.loft(b.on("far", "chest"), [(r[0], r[1] + 0.01, r[2] + 0.01, r[3]) for r in TORSO[::2]] + [TORSO[-1]],
             body, sides=8)
    low.loft(b.on("far", "hips"), [(0.74, 0.1, 0.074, 0.0), (0.96, 0.158, 0.106, 0.0)], "shell", sides=8)

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        low.limb(b.on("far", f"upper_arm_{sd}"), sh, el, [(0.0, 0.08), (1.05, 0.07)], body, sides=5)
        low.limb(b.on("far", f"forearm_{sd}"), el, wr, [(0.0, 0.064), (1.15, 0.06)], "shell", sides=5)
        low.limb(b.on("far", f"thigh_{sd}"), hip, knee, [(-0.1, 0.085), (1.05, 0.07)], "shell", sides=5)
        low.limb(b.on("far", f"shin_{sd}"), knee, ankle, [(0.0, 0.066), (1.0, 0.07)], "shell", sides=5)
        b.on("far", f"foot_{sd}").box((0.12, 0.25, 0.08), (hip[0], 0.05, 0.04), "shell")

    low._mirror(side)
    objs = b.build(arm)
    lib.smooth(objs["far"], angle=60.0)
    return objs


def build(look):
    """The complete robot in the current scene: rig, parts, far body and
    actions."""
    arm = low.build_rig("robot")
    build_robot(arm, look)
    far_body(arm, look)
    low.add_actions(arm, "robot")
    return arm
