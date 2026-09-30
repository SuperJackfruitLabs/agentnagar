"""Low-poly tropical characters v2: skinned, animated people and robots.

Builds `character_human.glb` and `character_robot.glb` for the pack: chunky,
faceted figures in the proportions of sheet 11 (a head about a sixth of the
height, broad shoulders), rigidly skinned (weight 1.0) to one shared bone
set and animated with four looping actions.

Axes and origin. Blender Z-up, metres; the character faces +Y (Godot -Z)
and its right hand is on +X. The origin is on the floor between the feet
and every action keeps it there: walking is in place, the pack moves the
node.

Bones (both rigs, all deform; each bone's Z axis faces forward, the feet's
faces up):

    hips > spine > chest > neck > head
    chest > upper_arm_l > forearm_l > hand_l        (and _r)
    hips  > thigh_l > shin_l > foot_l                 (and _r)

Sides use a lower-case `_l` / `_r` suffix, the character's own left being
-X: valid as Godot node and bone names, and in line with the v1 parts
(`arm_l`, `leg_l`).

Actions (glTF animations sampled at 24 fps; the last key repeats the first,
so each loops seamlessly with Godot's LOOP_LINEAR):

    walk    1 s  two steps in place: heel strike, flat foot, toe-off and
                 swing, arm swing, pelvis twist and sway, and a slight bob
                 (about 1.5 cm, lowest at each heel strike).
                 Legs are solved by IK, so a planted foot slides back at
                 exactly STRIDE metres per cycle: play at speed / STRIDE.
    idle    6 s  two breaths and one slow weight shift, feet locked.
    sit     3 s  seated: hip joints over the origin, the thighs' underside
                 on a seat SEAT_HEIGHT high, feet flat on the floor ahead,
                 hands on the thighs, breathing.
    typing  1 s  seated as `sit`, leaning in, wrists on a desk's keyboard
                 (TYPING: 0.17 m either side, 0.32 m ahead of the seat point,
                 0.77 m high; a desk top at about 0.74 m), hands tapping
                 alternately.

A seated character's origin goes at the seat point on the floor (under the
middle of the seat, facing the way the seat faces); the action lowers it.

Objects. Each is one recolourable part, skinned to the armature, and named
after its material role:

    human: skin, top, bottom, shoes, details (eyes, brows, belt), hair_0
           (bun), hair_1 (short), hair_2 (ponytail), hair_3 (curly), hat_sun
           (straw hat), backpack
    robot: shell (white), panel (yellow), joint (black), face (glossy face
           plate), eyes (emissive cyan arcs), badge (leaf)

All four hairs, the hat and the backpack are in the GLB; the pack shows one
hair and toggles the accessories. Each part carries one material named
after its role (details and hat_sun carry two: eye/brow/belt and
straw/hat_band), so the pack recolours a part with `material_override` on
the node of that name. Skinned meshes are not parented to the armature in
Blender (glTF wants them at the root); Godot puts them under the Skeleton3D.

Reuse (pixel pre-renders, voxel bodies):

    arm = build_rig("human")            # armature `rig_human`, rest pose
    objs = build_human(arm, {"top": my_material, "skin": "skin"})
    add_actions(arm)                    # walk, idle, sit, typing on NLA
    # or your own parts: body = Body(); body.on("top", "chest").box(...)
    #                    body.build(arm, materials)
    # or an existing mesh: bind(my_object, arm, bone="chest")

`JOINTS[kind][bone]` gives each bone's (head, tail) in the rest pose, and
`CONTACTS[kind]` the soles' floor points. `add_actions` fits the actions to
the armature's own joints (feet locked, seat height), so any body built on
these rigs animates. Material maps take role -> palette name or bpy
material; `ACTIONS` maps each name to (seconds, pose function).
"""
import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

import lib

FPS = 24
SEAT_HEIGHT = 0.45
STRIDE = 1.1
TYPING = (0.17, 0.32, 0.77)  # wrists in `typing`: |x|, forward, height (m)

BONES = ["hips", "spine", "chest", "neck", "head",
         "upper_arm_l", "forearm_l", "hand_l", "upper_arm_r", "forearm_r", "hand_r",
         "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
PARENTS = {"hips": None, "spine": "hips", "chest": "spine", "neck": "chest", "head": "neck"}
for _s in "lr":
    PARENTS.update({f"upper_arm_{_s}": "chest", f"forearm_{_s}": f"upper_arm_{_s}",
                    f"hand_{_s}": f"forearm_{_s}", f"thigh_{_s}": "hips",
                    f"shin_{_s}": f"thigh_{_s}", f"foot_{_s}": f"shin_{_s}"})

# Default colours for the material roles (the pack recolours most of them).
lib.PALETTE.update({
    "top": "#E9B23C", "bottom": "#3F5A70", "shoes": "#4A3528", "eye": "#1C1512",
    "brow": "#2E2018", "belt": "#3A2C22", "straw": "#E0BE78", "hat_band": "#6B4A32",
    "backpack": "#3F6A45",
    "shell": "#F2EFE8", "panel": "#F2B632", "joint": "#2B2A2E", "face": "#0E1114",
    "eyes": "#5FF4F2", "badge": "#3F8F3A",
})
lib.ROUGHNESS.update({"face": 0.12, "shell": 0.62, "panel": 0.6, "joint": 0.55})
lib.EMISSIVE.update({"eyes": 4.0})

HUMAN_ROLES = ["skin", "top", "bottom", "shoes", "hair", "eye", "brow", "belt", "straw",
               "hat_band", "backpack"]
ROBOT_ROLES = ["shell", "panel", "joint", "face", "eyes", "badge"]


def _sides(left):
    """{bone: (head, tail)} for both sides from the left side's joints."""
    out = {}
    for bone, (h, t) in left.items():
        out[f"{bone}_l"] = (h, t)
        out[f"{bone}_r"] = ((-h[0], h[1], h[2]), (-t[0], t[1], t[2]))
    return out


JOINTS = {
    "human": {
        "hips": ((0, 0, 0.86), (0, 0, 0.97)),
        "spine": ((0, 0, 0.97), (0, 0, 1.13)),
        "chest": ((0, 0, 1.13), (0, 0, 1.39)),
        "neck": ((0, 0, 1.39), (0, 0.01, 1.44)),
        "head": ((0, 0.01, 1.44), (0, 0.01, 1.71)),
        **_sides({
            "upper_arm": ((-0.218, -0.005, 1.342), (-0.242, -0.015, 1.08)),
            "forearm": ((-0.242, -0.015, 1.08), (-0.256, 0.0, 0.855)),
            "hand": ((-0.256, 0.0, 0.855), (-0.26, 0.01, 0.73)),
            "thigh": ((-0.10, 0.0, 0.83), (-0.10, 0.005, 0.485)),
            "shin": ((-0.10, 0.005, 0.485), (-0.102, -0.01, 0.085)),
            "foot": ((-0.102, -0.01, 0.085), (-0.102, 0.13, 0.025)),
        }),
    },
    "robot": {
        "hips": ((0, 0, 0.84), (0, 0, 0.95)),
        "spine": ((0, 0, 0.95), (0, 0, 1.06)),
        "chest": ((0, 0, 1.06), (0, 0, 1.30)),
        "neck": ((0, 0, 1.30), (0, 0, 1.36)),
        "head": ((0, 0, 1.36), (0, 0, 1.625)),
        **_sides({
            "upper_arm": ((-0.238, 0.0, 1.235), (-0.258, -0.01, 0.99)),
            "forearm": ((-0.258, -0.01, 0.99), (-0.268, 0.0, 0.775)),
            "hand": ((-0.268, 0.0, 0.775), (-0.272, 0.01, 0.66)),
            "thigh": ((-0.105, 0.0, 0.81), (-0.105, 0.005, 0.47)),
            "shin": ((-0.105, 0.005, 0.47), (-0.105, -0.01, 0.095)),
            "foot": ((-0.105, -0.01, 0.095), (-0.105, 0.13, 0.03)),
        }),
    },
}

# Where the soles meet the floor in the rest pose: heel and toe of each foot
# (armature space). The actions keep the lowest of these on the floor.
CONTACTS = {
    "human": {"l": [(-0.102, -0.088, 0.0), (-0.102, 0.185, 0.0), (-0.148, 0.12, 0.0), (-0.056, 0.12, 0.0)]},
    "robot": {"l": [(-0.105, -0.08, 0.0), (-0.105, 0.175, 0.0), (-0.155, 0.12, 0.0), (-0.055, 0.12, 0.0)]},
}
for _k in CONTACTS.values():
    _k["r"] = [(-x, y, z) for x, y, z in _k["l"]]

# Half-thickness of the thigh under its bone: the seated hip joint sits this
# far above the seat.
THIGH_UNDER = {"human": 0.09, "robot": 0.085}


# ---- Rig ----

def build_rig(kind, name=None):
    """An armature object `rig_<kind>` (or `name`) with the shared bones at
    JOINTS[kind], in the rest pose, linked to the scene."""
    name = name or f"rig_{kind}"
    data = bpy.data.armatures.new(name)
    arm = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(arm)
    arm["kind"] = kind
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for bone in BONES:
        eb = data.edit_bones.new(bone)
        head, tail = JOINTS[kind][bone]
        eb.head, eb.tail = head, tail
        eb.align_roll(Vector((0, 0, 1)) if bone.startswith("foot") else Vector((0, 1, 0)))
    for bone in BONES:
        if PARENTS[bone]:
            data.edit_bones[bone].parent = data.edit_bones[PARENTS[bone]]
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return arm


def bind(obj, arm, bone=None):
    """Skins `obj` to `arm` with an Armature modifier and, with `bone`,
    weights every vertex 1.0 to that bone. Without `bone` the object must
    already carry vertex groups named after bones. The object is not
    parented to the armature: glTF wants skinned meshes at the root (the
    validator warns otherwise), and the skin carries the binding."""
    obj.parent = None
    if bone is not None:
        vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
        vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    mod = obj.modifiers.new("rig", "ARMATURE")
    mod.object = arm
    return obj


# ---- Geometry helpers ----

def _ring(rx, ry, sides, phase, cx=0.0, cy=0.0, tilt=0.0, z=0.0):
    out = []
    for k in range(sides):
        a = phase + 2 * math.pi * k / sides
        s = math.sin(a)
        out.append((cx + rx * math.cos(a), cy + ry * s, z + tilt * s))
    return out


def _bridge(bm, rings, caps=(True, True)):
    for r0, r1 in zip(rings, rings[1:]):
        n = len(r0)
        for k in range(n):
            bm.faces.new([r0[k], r0[(k + 1) % n], r1[(k + 1) % n], r1[k]])
    if caps[0]:
        bm.faces.new(list(reversed(rings[0])))
    if caps[1]:
        bm.faces.new(rings[-1])


def _jitter(bm, amount, seed):
    if amount <= 0:
        return
    rng = random.Random(seed)
    for v in bm.verts:
        v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * amount


def loft(mesh, rings, mat, sides=10, caps=(True, True), jitter=0.0, seed=0, at=(0, 0, 0)):
    """A faceted body of revolution along Z: `rings` are (z, rx, ry[, cy[,
    tilt]]) cross-sections, bottom to top; `tilt` raises the front (+Y) of a
    ring and lowers its back. A flat facet faces front."""
    tmp = bmesh.new()
    phase = math.pi / 2 - math.pi / sides
    loops = []
    for r in rings:
        z, rx, ry = r[:3]
        cy = r[3] if len(r) > 3 else 0.0
        tilt = r[4] if len(r) > 4 else 0.0
        loops.append([tmp.verts.new(p) for p in _ring(rx, ry, sides, phase, 0.0, cy, tilt, z)])
    _bridge(tmp, loops, caps)
    _jitter(tmp, jitter, seed)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, at)


def _frame(tangent, hint):
    """An orthonormal frame (x, y, z) with z along `tangent`, x as close to
    world X as possible and y towards `hint`."""
    z = Vector(tangent).normalized()
    x = Vector((1, 0, 0)) - z * z.x
    if x.length < 1e-4:
        x = Vector((0, 1, 0)) - z * z.y
    x.normalize()
    y = z.cross(x)
    if y.dot(Vector(hint)) < 0:
        y = -y
    return x, y, z


def sweep(mesh, points, radii, mat, sides=6, hint=(0, 1, 0), caps=(True, True), jitter=0.0, seed=0):
    """A faceted tube through `points`, with cross-section radii (rx, ry) at
    each point (rx across world X, ry towards `hint`)."""
    pts = [Vector(p) for p in points]
    tmp = bmesh.new()
    loops = []
    phase = math.pi / 2 - math.pi / sides
    tangents = [(pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized() for i in range(len(pts))]
    x, y, _ = _frame(tangents[0], hint)
    for i, p in enumerate(pts):
        if i:
            # Parallel transport, so the tube does not twist along a curve.
            q = tangents[i - 1].rotation_difference(tangents[i])
            x = (q @ x).normalized()
            y = (q @ y).normalized()
        rx, ry = radii[i]
        loops.append([tmp.verts.new(p + x * u + y * w) for u, w, _ in _ring(rx, ry, sides, phase)])
    _bridge(tmp, loops, caps)
    _jitter(tmp, jitter, seed)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def limb(mesh, a, b, profile, mat, sides=7, hint=(0, 1, 0), jitter=0.0, seed=0):
    """A tapered faceted limb along a->b: `profile` is [(t, rx[, ry])] with t
    the fraction of the way from a to b (may run past either end)."""
    a, b = Vector(a), Vector(b)
    pts = [a.lerp(b, p[0]) for p in profile]
    radii = [(p[1], p[2] if len(p) > 2 else p[1]) for p in profile]
    x, y, z = _frame(b - a, hint)
    tmp = bmesh.new()
    phase = math.pi / 2 - math.pi / sides
    loops = [[tmp.verts.new(p + x * u + y * w) for u, w, _ in _ring(rx, ry, sides, phase)]
             for p, (rx, ry) in zip(pts, radii)]
    _bridge(tmp, loops)
    _jitter(tmp, jitter, seed)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def patch(mesh, rings, mat, centre=90.0, columns=6, thickness=0.012, jitter=0.0, seed=0):
    """A curved plate lying on a loft's surface: `rings` are (z, rx, ry, cy,
    half_angle_deg) and the plate spans centre ± half_angle on each ring
    (90 = front, 0 = the character's right). It is `thickness` deep, inwards
    from the given radii."""
    tmp = bmesh.new()
    outer, inner = [], []
    for z, rx, ry, cy, half in rings:
        o_row, i_row = [], []
        for k in range(columns + 1):
            a = math.radians(centre - half + 2 * half * k / columns)
            o_row.append(tmp.verts.new((rx * math.cos(a), cy + ry * math.sin(a), z)))
            i_row.append(tmp.verts.new(((rx - thickness) * math.cos(a), cy + (ry - thickness) * math.sin(a), z)))
        outer.append(o_row)
        inner.append(i_row)
    n = len(rings)
    for i in range(n - 1):
        for k in range(columns):
            tmp.faces.new([outer[i][k], outer[i][k + 1], outer[i + 1][k + 1], outer[i + 1][k]])
            tmp.faces.new([inner[i][k], inner[i + 1][k], inner[i + 1][k + 1], inner[i][k + 1]])
    for i in range(n - 1):
        for k in (0, columns):
            tmp.faces.new([outer[i][k], outer[i + 1][k], inner[i + 1][k], inner[i][k]])
    for i in (0, n - 1):
        for k in range(columns):
            tmp.faces.new([outer[i][k], outer[i][k + 1], inner[i][k + 1], inner[i][k]])
    _jitter(tmp, jitter, seed)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def surface(rings, sides, z, x):
    """Where a loft's front surface is at height z and lateral x: (y, facet
    angle about Z in degrees) for placing details flush on it."""
    rings = sorted(rings, key=lambda r: r[0])
    for r0, r1 in zip(rings, rings[1:]):
        if r0[0] <= z <= r1[0]:
            f = (z - r0[0]) / (r1[0] - r0[0])
            rx, ry = (r0[1] + (r1[1] - r0[1]) * f, r0[2] + (r1[2] - r0[2]) * f)
            c0 = r0[3] if len(r0) > 3 else 0.0
            c1 = r1[3] if len(r1) > 3 else 0.0
            cy = c0 + (c1 - c0) * f
            break
    else:
        raise ValueError(z)
    phase = math.pi / 2 - math.pi / sides
    poly = [(rx * math.cos(phase + 2 * math.pi * k / sides), cy + ry * math.sin(phase + 2 * math.pi * k / sides))
            for k in range(sides)]
    for (x0, y0), (x1, y1) in zip(poly, poly[1:] + poly[:1]):
        if min(x0, x1) <= x <= max(x0, x1) and (y0 + y1) / 2 > cy:
            f = (x - x0) / (x1 - x0) if x1 != x0 else 0.5
            return y0 + (y1 - y0) * f, math.degrees(math.atan2(y1 - y0, x1 - x0))
    raise ValueError(x)


def _mirror(fn):
    for side, s in (("l", -1), ("r", 1)):
        fn(side, s)


# ---- Bodies ----

class Body:
    """Geometry for one character, collected per (object, bone) in the rig's
    rest pose, then built as one rigidly skinned object per name."""

    def __init__(self):
        self.parts = {}

    def on(self, name, bone):
        """The lib.Mesh for object `name` that moves with `bone`."""
        return self.parts.setdefault((name, bone), lib.Mesh())

    def build(self, arm, materials=None):
        """One object per name, rigidly skinned to `arm` (each vertex weighs
        1.0 on its bone), faces triangulated so every facet shades on its
        own, role materials replaced by `materials`. Returns {name: object}."""
        out = {}
        names = []
        for name, _ in self.parts:
            if name not in names:
                names.append(name)
        for name in names:
            bm = bmesh.new()
            deform = bm.verts.layers.deform.verify()
            mats = []
            for (n, bone), mesh in self.parts.items():
                if n != name:
                    continue
                remap = []
                for m in mesh.mats:
                    if m not in mats:
                        mats.append(m)
                    remap.append(mats.index(m))
                group = BONES.index(bone)
                vmap = {}
                for v in mesh.bm.verts:
                    nv = bm.verts.new(v.co)
                    nv[deform][group] = 1.0
                    vmap[v] = nv
                for f in mesh.bm.faces:
                    try:
                        nf = bm.faces.new([vmap[v] for v in f.verts])
                    except ValueError:
                        continue
                    nf.material_index = remap[f.material_index]
                mesh.bm.free()
            bmesh.ops.triangulate(bm, faces=bm.faces, quad_method="BEAUTY", ngon_method="BEAUTY")
            obj = lib._object(name, bm, mats)
            for bone in BONES:
                obj.vertex_groups.new(name=bone)
            bind(obj, arm)
            out[name] = obj
        self.parts = {}
        apply_materials(out.values(), materials)
        return out


def apply_materials(objects, materials):
    """Replaces role materials: `materials` maps a role name to a palette
    name (lib.material) or a bpy material."""
    if not materials:
        return
    for obj in objects:
        for i, m in enumerate(obj.data.materials):
            if m is not None and m.name in materials:
                new = materials[m.name]
                obj.data.materials[i] = new if isinstance(new, bpy.types.Material) else lib.material(new)


HEAD = [  # (z, rx, ry, cy) of the human head, chin to crown
    (1.412, 0.046, 0.034, 0.07),
    (1.448, 0.091, 0.081, 0.04),
    (1.50, 0.121, 0.115, 0.015),
    (1.565, 0.134, 0.130, 0.004),
    (1.632, 0.133, 0.133, -0.006),
    (1.684, 0.105, 0.113, -0.013),
    (1.714, 0.046, 0.057, -0.011),
]
HEAD_SIDES = 12
CHEST = [  # the tee over the chest
    (1.06, 0.172, 0.114, 0.0),
    (1.15, 0.182, 0.123, 0.006),
    (1.25, 0.198, 0.133, 0.014),
    (1.315, 0.21, 0.123, 0.006),
    (1.352, 0.194, 0.108, -0.002),
    (1.384, 0.15, 0.092, -0.004),
    (1.408, 0.086, 0.066, 0.0),
]


def _cap(z0, tilt, grow=0.014, top=0.018):
    """Rings for a hair cap hugging the head from a hairline at z0 whose
    front is raised by `tilt` (and back lowered as much)."""
    rings = []
    for r0, r1 in zip(HEAD, HEAD[1:]):
        if r0[0] <= z0 <= r1[0]:
            f = (z0 - r0[0]) / (r1[0] - r0[0])
            rings.append((z0, r0[1] + (r1[1] - r0[1]) * f + grow, r0[2] + (r1[2] - r0[2]) * f + grow,
                          r0[3] + (r1[3] - r0[3]) * f - 0.004, tilt))
    crown = HEAD[-2][0]
    for z, rx, ry, cy in HEAD[:-1]:
        if z > z0 + 0.01:
            rings.append((z, rx + grow, ry + grow, cy - 0.004, tilt * max(0.0, (crown - z) / (crown - z0))))
    rings.append((HEAD[-1][0] + top, 0.052, 0.06, -0.012, 0.0))
    return rings


def build_human(arm, materials=None, body=None):
    """The human's parts on `arm` (a `build_rig("human")` armature)."""
    J = JOINTS["human"]
    b = body or Body()
    facet = 0.005  # vertex jitter that breaks surfaces into sculpted facets

    # Head, neck, face.
    skin = b.on("skin", "head")
    loft(skin, HEAD, "skin", sides=HEAD_SIDES, jitter=0.003, seed=1)
    skin.prism([(0.127, 1.574), (0.16, 1.528), (0.127, 1.513)], 0.038, (0, 0, 0), "skin", axis="x")
    for s in (-1, 1):
        skin.box((0.024, 0.054, 0.068), (s * 0.133, -0.004, 1.556), "skin", bevel=0.008)
    b.on("skin", "neck").cylinder(0.056, 0.13, (0, 0.006, 1.415), "skin", sides=7)
    det = b.on("details", "head")
    for s in (-1, 1):
        y, ang = surface(HEAD, HEAD_SIDES, 1.574, s * 0.053)
        det.box((0.024, 0.014, 0.034), (s * 0.053, y + 0.001, 1.574), "eye", rot=lib.rotz(ang))
        y, ang = surface(HEAD, HEAD_SIDES, 1.615, s * 0.057)
        det.box((0.05, 0.012, 0.012), (s * 0.057, y + 0.002, 1.616), "brow",
                rot=lib.rotz(ang) @ lib.roty(-s * 8))
    # Belt, over the trousers' waistband.
    loft(b.on("details", "hips"), [(0.94, 0.182, 0.121, 0.0), (0.978, 0.178, 0.118, 0.0)], "belt", sides=10)
    b.on("details", "hips").box((0.05, 0.02, 0.034), (0, 0.121, 0.959), "belt")

    # Torso: the tee.
    loft(b.on("top", "chest"), CHEST, "top", sides=10, jitter=facet * 1.4, seed=2)
    loft(b.on("top", "spine"), [(0.972, 0.178, 0.118, 0.0), (1.04, 0.172, 0.113, 0.0),
                                (1.12, 0.174, 0.115, 0.0)], "top", sides=10, caps=(True, False),
         jitter=facet, seed=4)

    # Trousers.
    loft(b.on("bottom", "hips"), [(0.745, 0.10, 0.075, -0.005), (0.80, 0.176, 0.114, -0.012),
                                  (0.88, 0.182, 0.118, -0.008), (0.96, 0.174, 0.114, 0.0)],
         "bottom", sides=10, jitter=facet, seed=3)

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        _, tip = J[f"hand_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        seed = 10 if s < 0 else 20
        # Sleeve over the shoulder and upper arm, bare arm below it.
        limb(b.on("top", f"upper_arm_{sd}"), sh, el, [(-0.12, 0.036), (-0.03, 0.066), (0.1, 0.08, 0.078),
                                                      (0.3, 0.076), (0.46, 0.08), (0.5, 0.072)],
             "top", sides=8, jitter=facet, seed=seed)
        limb(b.on("skin", f"upper_arm_{sd}"), sh, el, [(0.4, 0.062), (0.8, 0.056), (1.02, 0.051)],
             "skin", sides=7, jitter=0.002, seed=seed + 1)
        limb(b.on("skin", f"forearm_{sd}"), el, wr, [(-0.1, 0.049), (0.02, 0.054), (0.35, 0.052, 0.049),
                                                     (1.0, 0.04, 0.036)], "skin", sides=7, jitter=0.002,
             seed=seed + 2)
        hand = b.on("skin", f"hand_{sd}")
        mid = Vector(wr).lerp(Vector(tip), 0.42)
        hand.box((0.046, 0.086, 0.118), mid, "skin", bevel=0.015)
        hand.box((0.03, 0.034, 0.056), mid + Vector((-s * 0.014, 0.05, 0.018)), "skin", rot=lib.rotx(-25))
        # Trouser legs.
        limb(b.on("bottom", f"thigh_{sd}"), hip, knee, [(-0.14, 0.09), (0.05, 0.098, 0.1), (0.5, 0.086, 0.088),
                                                         (1.0, 0.07), (1.1, 0.064)],
             "bottom", sides=8, jitter=facet, seed=seed + 3)
        limb(b.on("bottom", f"shin_{sd}"), knee, ankle, [(-0.1, 0.064), (0.05, 0.069), (0.35, 0.067),
                                                          (0.8, 0.057), (0.9, 0.061), (0.93, 0.054)],
             "bottom", sides=8, jitter=0.003, seed=seed + 4)
        # Shoes: a chunky upper on a flat sole.
        x = hip[0] - s * 0.002
        shoe = b.on("shoes", f"foot_{sd}")
        sweep(shoe, [(x, -0.08, 0.054), (x, -0.05, 0.066), (x, 0.04, 0.064), (x, 0.135, 0.05), (x, 0.178, 0.036)],
              [(0.043, 0.038), (0.054, 0.05), (0.058, 0.05), (0.055, 0.037), (0.036, 0.02)], "shoes",
              sides=8, hint=(0, 0, 1), jitter=0.002, seed=seed + 5)
        shoe.box((0.114, 0.27, 0.024), (x, 0.048, 0.012), "shoes")
        shoe.cylinder(0.058, 0.08, (x, -0.012, 0.1), "shoes", sides=7, radius_top=0.054)

    _mirror(side)

    # Hair: four caps with distinct silhouettes, all on the head bone.
    h0 = b.on("hair_0", "head")  # bun, loose strands
    loft(h0, _cap(1.585, 0.05, grow=0.017), "hair", sides=HEAD_SIDES, caps=(False, True), jitter=0.004, seed=31)
    h0.sphere(0.084, (0, -0.1, 1.682), "hair", subdivisions=2, scale=(1.0, 0.95, 0.9), jitter=0.07, seed=32)
    h0.cylinder(0.052, 0.03, (0, -0.078, 1.642), "hair", sides=7, rot=lib.rotx(-35))
    for s in (-1, 1):
        sweep(h0, [(s * 0.12, 0.05, 1.63), (s * 0.136, 0.055, 1.57), (s * 0.127, 0.06, 1.515)],
              [(0.012, 0.016), (0.012, 0.014), (0.004, 0.006)], "hair", sides=4)
    h1 = b.on("hair_1", "head")  # short, tousled
    loft(h1, _cap(1.57, 0.058, grow=0.02, top=0.028), "hair", sides=HEAD_SIDES, caps=(False, True),
         jitter=0.007, seed=41)
    h1.prism([(-0.105, 0.018), (0.105, 0.022), (0.065, -0.02), (-0.02, -0.005), (-0.095, -0.022)], 0.05,
             (0, 0.114, 1.64), "hair", axis="y", rot=lib.rotx(-18))
    h2 = b.on("hair_2", "head")  # sleek, ponytail
    loft(h2, _cap(1.565, 0.07, grow=0.012, top=0.014), "hair", sides=HEAD_SIDES, caps=(False, True),
         jitter=0.003, seed=51)
    h2.cylinder(0.032, 0.03, (0, -0.146, 1.618), "hair", sides=6, rot=lib.rotx(80))
    sweep(h2, [(0, -0.152, 1.63), (0, -0.172, 1.59), (0, -0.182, 1.51), (0, -0.177, 1.42), (0, -0.167, 1.35)],
          [(0.034, 0.032), (0.048, 0.042), (0.045, 0.038), (0.032, 0.028), (0.008, 0.008)], "hair", sides=6,
          jitter=0.004, seed=52)
    h3 = b.on("hair_3", "head")  # curly volume
    loft(h3, _cap(1.575, 0.05, grow=0.02, top=0.02), "hair", sides=10, caps=(False, True), seed=61)
    rng = random.Random(62)
    for k in range(15):
        if k < 10:
            a = 2 * math.pi * k / 10 + 0.3
            el = math.radians(10 + 28 * (k % 2))
            if math.sin(a) > 0.5:
                el = math.radians(46)
        else:
            a = 2 * math.pi * (k - 10) / 5
            el = math.radians(66)
        r = 0.142
        c = Vector((r * math.cos(a) * math.cos(el), -0.01 + r * math.sin(a) * math.cos(el), 1.612 + r * math.sin(el)))
        h3.sphere(0.044 + 0.008 * rng.random(), c, "hair", subdivisions=1, jitter=0.12, seed=63 + k)

    # Accessories.
    hat = b.on("hat_sun", "head")
    hat.cylinder(0.26, 0.03, (0, -0.004, 1.642), "straw", sides=14, radius_top=0.158)
    hat.cylinder(0.145, 0.1, (0, -0.004, 1.702), "straw", sides=11, radius_top=0.125)
    hat.cylinder(0.148, 0.03, (0, -0.004, 1.667), "hat_band", sides=11, radius_top=0.145)
    pack = b.on("backpack", "chest")
    pack.box((0.28, 0.13, 0.32), (0, -0.2, 1.19), "backpack", bevel=0.035)
    pack.box((0.286, 0.142, 0.1), (0, -0.2, 1.315), "backpack", bevel=0.03)
    pack.box((0.19, 0.05, 0.13), (0, -0.278, 1.11), "backpack", bevel=0.018)
    for s in (-1, 1):
        sweep(pack, [(s * 0.1, -0.135, 1.33), (s * 0.105, -0.04, 1.418), (s * 0.11, 0.06, 1.402),
                     (s * 0.115, 0.122, 1.33), (s * 0.12, 0.142, 1.22), (s * 0.135, 0.11, 1.10),
                     (s * 0.15, -0.02, 1.06)],
              [(0.025, 0.008)] * 7, "backpack", sides=4, hint=(0, 0, 1))
    return b.build(arm, materials)


HELMET = [  # (z, rx, ry, cy) of the robot helmet
    (1.345, 0.124, 0.119, -0.004),
    (1.385, 0.160, 0.157, 0.0),
    (1.452, 0.176, 0.172, 0.0),
    (1.522, 0.172, 0.169, -0.004),
    (1.578, 0.148, 0.146, -0.008),
    (1.614, 0.094, 0.094, -0.010),
    (1.634, 0.032, 0.032, -0.010),
]
HELMET_SIDES = 14
TORSO = [  # the robot chest shell
    (1.03, 0.158, 0.109, 0.0),
    (1.12, 0.184, 0.124, 0.006),
    (1.20, 0.204, 0.134, 0.012),
    (1.262, 0.214, 0.127, 0.006),
    (1.302, 0.182, 0.102, 0.0),
    (1.325, 0.088, 0.066, 0.0),
]


def band(mesh, rings, sides, path, half, mat, thickness=0.02, lift=0.004):
    """A strip lying on a loft's front surface along `path` [(x, z)], `half`
    high above and below it."""
    tmp = bmesh.new()
    grid = []
    for x, z in path:
        col = []
        for dz in (-half, half):
            y, _ = surface(rings, sides, z + dz, x)
            col.append((tmp.verts.new((x, y + lift, z + dz)), tmp.verts.new((x, y - thickness, z + dz))))
        grid.append(col)
    for c0, c1 in zip(grid, grid[1:]):
        (a0o, a0i), (b0o, b0i) = c0
        (a1o, a1i), (b1o, b1i) = c1
        tmp.faces.new([a0o, a1o, b1o, b0o])
        tmp.faces.new([a0i, b0i, b1i, a1i])
        tmp.faces.new([a0o, a0i, a1i, a1o])
        tmp.faces.new([b0o, b1o, b1i, b0i])
    for (ao, ai), (bo, bi) in (grid[0], grid[-1]):
        tmp.faces.new([ao, bo, bi, ai])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    mesh._merge(tmp, mat, None, (0, 0, 0))


def build_robot(arm, materials=None, body=None):
    """The robot's parts on `arm` (a `build_rig("robot")` armature)."""
    J = JOINTS["robot"]
    b = body or Body()
    head = b.on("shell", "head")
    loft(head, HELMET, "shell", sides=HELMET_SIDES, jitter=0.002, seed=101)
    # The face plate: a glossy black visor over most of the helmet's front.
    grow = 0.007
    plate = [(1.352, 0.127 + grow, 0.122 + grow, -0.004, 42), (1.385, 0.160 + grow, 0.157 + grow, 0.0, 62),
             (1.452, 0.176 + grow, 0.172 + grow, 0.0, 70), (1.522, 0.172 + grow, 0.169 + grow, -0.004, 66),
             (1.57, 0.153 + grow, 0.151 + grow, -0.007, 48)]
    patch(b.on("face", "head"), plate, "face", columns=8, thickness=0.02)
    # Eyes: two glowing arcs, curved up like closed, smiling eyes.
    eyes = b.on("eyes", "head")
    for s in (-1, 1):
        cx, cz, r = s * 0.063, 1.472, 0.028
        pts = []
        for k in range(6):
            a = math.pi * k / 5
            x, z = cx + r * math.cos(a), cz + r * math.sin(a) * 1.1
            rx, ry = 0.176 + grow, 0.172 + grow
            pts.append((x, ry * math.sqrt(max(0.0, 1 - (x / rx) ** 2)) + 0.002, z))
        sweep(eyes, pts, [(0.008, 0.008)] * 6, "eyes", sides=4, hint=(0, 0, 1))
    # Ear discs and the crest.
    panel = b.on("panel", "head")
    for s in (-1, 1):
        panel.cylinder(0.065, 0.036, (s * 0.177, -0.012, 1.47), "panel", sides=12, rot=lib.roty(90))
        panel.cylinder(0.04, 0.02, (s * 0.202, -0.012, 1.47), "panel", sides=10, rot=lib.roty(90))
    sweep(panel, [(0, 0.126, 1.578), (0, 0.074, 1.621), (0, 0.0, 1.64), (0, -0.074, 1.621), (0, -0.126, 1.578)],
          [(0.036, 0.008)] * 5, "panel", sides=4, hint=(0, 0, 1))
    b.on("joint", "neck").cylinder(0.055, 0.12, (0, 0, 1.33), "joint", sides=8)

    # Torso: white shell with yellow shoulder panels and a sash, black waist.
    loft(b.on("shell", "chest"), TORSO, "shell", sides=10, jitter=0.003, seed=102)
    chest_panel = b.on("panel", "chest")
    # A yoke over the shoulders, flush with the shell.
    patch(chest_panel, [(1.244, 0.221, 0.139, 0.013, 180), (1.262, 0.221, 0.134, 0.006, 180),
                        (1.302, 0.189, 0.109, 0.0, 180), (1.325, 0.095, 0.073, 0.0, 180)],
          "panel", centre=90.0, columns=20, thickness=0.02)
    # A sash across the belly, from the left ribs down to the right hip.
    band(chest_panel, TORSO, 10, [(-0.17 + 0.32 * t / 15, 1.21 - 0.136 * t / 15 + 0.03 * math.sin(math.pi * t / 15))
                                  for t in range(16)], 0.026, "panel", lift=0.007)
    y, ang = surface(TORSO, 10, 1.2, 0.085)
    b.on("badge", "chest").prism([(-0.034, 0.0), (-0.017, 0.013), (0.0, 0.017), (0.021, 0.011), (0.036, 0.0),
                                  (0.019, -0.011), (0.0, -0.015), (-0.019, -0.011)], 0.006,
                                 (0.085, y + 0.003, 1.21), "badge", axis="y", rot=lib.rotz(ang) @ lib.roty(-40))
    b.on("joint", "spine").cylinder(0.122, 0.13, (0, 0, 0.995), "joint", sides=10, radius_top=0.13)
    loft(b.on("shell", "hips"), [(0.735, 0.10, 0.074, -0.004), (0.795, 0.166, 0.11, -0.008),
                                 (0.875, 0.172, 0.114, -0.004), (0.962, 0.156, 0.105, 0.0)],
         "shell", sides=10, jitter=0.003, seed=103)

    def side(sd, s):
        sh, el = J[f"upper_arm_{sd}"]
        _, wr = J[f"forearm_{sd}"]
        _, tip = J[f"hand_{sd}"]
        hip, knee = J[f"thigh_{sd}"]
        _, ankle = J[f"shin_{sd}"]
        seed = 110 if s < 0 else 130
        b.on("joint", f"upper_arm_{sd}").sphere(0.07, sh, "joint", subdivisions=2)
        limb(b.on("shell", f"upper_arm_{sd}"), sh, el, [(-0.25, 0.045), (-0.12, 0.088), (0.06, 0.096),
                                                        (0.24, 0.082), (0.3, 0.072), (0.88, 0.066)],
             "shell", sides=8, jitter=0.003, seed=seed)
        b.on("joint", f"forearm_{sd}").sphere(0.062, el, "joint", subdivisions=1)
        limb(b.on("shell", f"forearm_{sd}"), el, wr, [(0.1, 0.06), (0.3, 0.068), (0.8, 0.074)], "shell",
             sides=8, jitter=0.003, seed=seed + 1)
        limb(b.on("panel", f"forearm_{sd}"), el, wr, [(0.76, 0.08), (0.98, 0.078), (1.02, 0.056)], "panel",
             sides=8, seed=seed + 2)
        hand = b.on("shell", f"hand_{sd}")
        mid = Vector(wr).lerp(Vector(tip), 0.45)
        hand.box((0.05, 0.088, 0.108), mid, "shell", bevel=0.017)
        hand.box((0.032, 0.034, 0.054), mid + Vector((-s * 0.013, 0.05, 0.02)), "shell", bevel=0.01,
                 rot=lib.rotx(-25))
        b.on("joint", f"thigh_{sd}").sphere(0.075, hip, "joint", subdivisions=1)
        limb(b.on("shell", f"thigh_{sd}"), hip, knee, [(0.1, 0.078), (0.22, 0.09), (0.6, 0.082), (0.88, 0.07)],
             "shell", sides=8, jitter=0.003, seed=seed + 3)
        b.on("joint", f"shin_{sd}").sphere(0.064, knee, "joint", subdivisions=1)
        b.on("panel", f"shin_{sd}").box((0.1, 0.03, 0.095), Vector(knee) + Vector((0, 0.066, -0.035)), "panel",
                                        bevel=0.012, rot=lib.rotx(8))
        limb(b.on("shell", f"shin_{sd}"), knee, ankle, [(0.12, 0.064), (0.4, 0.07), (0.8, 0.074), (0.95, 0.078)],
             "shell", sides=8, jitter=0.003, seed=seed + 4)
        x = hip[0]
        boot = b.on("shell", f"foot_{sd}")
        sweep(boot, [(x, -0.072, 0.062), (x, -0.04, 0.078), (x, 0.05, 0.072), (x, 0.135, 0.054), (x, 0.17, 0.04)],
              [(0.052, 0.046), (0.062, 0.058), (0.064, 0.052), (0.06, 0.038), (0.044, 0.024)], "shell",
              sides=8, hint=(0, 0, 1), jitter=0.002, seed=seed + 5)
        b.on("joint", f"foot_{sd}").box((0.124, 0.256, 0.026), (x, 0.05, 0.013), "joint")

    _mirror(side)
    return b.build(arm, materials)


# ---- Actions ----
#
# Each action is a function of phase (0..1) returning a Pose: upper-body
# rotations (degrees about the armature's rest axes, X right, Y forward,
# Z up, applied at each bone's head and relative to its parent), a hips
# offset, and ankle targets with foot pitches. Legs are solved by two-bone
# IK, so planted feet stay locked to the floor, and the hips drop just
# enough for every foot to be reached.

WALK = {"duty": 0.62, "heel": 18.0, "toe": 30.0, "flat": (0.12, 0.34), "lift": 0.09, "reach": 0.997,
        "back": 0.05}


def _rest(arm):
    return {b.name: b.matrix_local.copy() for b in arm.data.bones}


def _rot3(rot):
    """A rotation given as Euler degrees (XYZ) or a 3x3 matrix."""
    if isinstance(rot, Matrix):
        return rot
    return Euler([math.radians(a) for a in rot], "XYZ").to_matrix()


def _basis(rest, bone, rot=(0, 0, 0), offset=(0, 0, 0)):
    """A pose bone's basis matrix for a rotation in the armature's rest
    frame about the bone's head, and an armature-space offset of the head."""
    b3 = rest[bone].to_3x3()
    local = b3.inverted() @ _rot3(rot) @ b3
    return Matrix.Translation(b3.inverted() @ Vector(offset)) @ local.to_4x4()


def _fk(rest, bases):
    out = {}
    for bone in BONES:
        parent = PARENTS[bone]
        basis = bases.get(bone, Matrix.Identity(4))
        if parent is None:
            out[bone] = rest[bone] @ basis
        else:
            out[bone] = out[parent] @ (rest[parent].inverted() @ rest[bone]) @ basis
    return out


def _mirror_rot(side, rot):
    x, y, z = rot
    return (x, y, z) if side == "l" else (x, -y, -z)


class Leg:
    """A leg's rest geometry: joints, bone lengths, and where the heel and
    toe meet the floor relative to the ankle."""

    def __init__(self, rest, kind, sd):
        self.hip = rest[f"thigh_{sd}"].translation.copy()
        self.knee = rest[f"shin_{sd}"].translation.copy()
        self.ankle = rest[f"foot_{sd}"].translation.copy()
        self.l1 = (self.knee - self.hip).length
        self.l2 = (self.ankle - self.knee).length
        ys = [p[1] for p in CONTACTS[kind][sd]]
        self.heel = min(ys) - self.ankle.y
        self.toe = max(ys) - self.ankle.y
        self.height = self.ankle.z


class Pose:
    """One frame of an action. `rot` holds rotations per bone, `offset` the
    hips' offset, `feet` ankle targets per side as (Vector, pitch degrees,
    toe up positive), `hands` wrist targets per side as (Vector, the hand's
    world rotation from its rest). `mode` places the body: 'stand' lowers the hips just
    enough for every foot to be reached (never above `drop` below rest),
    'seat' puts the hip joints over the origin at seat height, 'floor'
    (no feet) keeps the lowest sole on the floor."""

    def __init__(self, mode="stand"):
        self.rot = {}
        self.offset = Vector((0, 0, 0))
        self.mode = mode
        self.feet = {}
        self.hands = {}
        self.drop = 0.004
        self.reach = WALK["reach"]

    def set(self, bone, x=0.0, y=0.0, z=0.0):
        self.rot[bone] = (x, y, z)

    def side(self, bone, side, x=0.0, y=0.0, z=0.0):
        self.rot[f"{bone}_{side}"] = _mirror_rot(side, (x, y, z))


class Rig:
    """What the actions need to know about an armature."""

    def __init__(self, arm, kind):
        self.kind = kind
        self.rest = _rest(arm)
        self.legs = {sd: Leg(self.rest, kind, sd) for sd in "lr"}


def _bases(rest, pose):
    bases = {bone: _basis(rest, bone, pose.rot.get(bone, (0, 0, 0))) for bone in BONES}
    bases["hips"] = _basis(rest, "hips", pose.rot.get("hips", (0, 0, 0)), pose.offset)
    return bases


def _contact_z(rig, posed):
    zs = []
    for sd in "lr":
        m = posed[f"foot_{sd}"] @ rig.rest[f"foot_{sd}"].inverted()
        zs += [(m @ Vector(p)).z for p in CONTACTS[rig.kind][sd]]
    return min(zs)


def _softmin(values, k=0.008):
    m = min(values)
    return m - k * math.log(sum(math.exp(-(v - m) / k) for v in values))


def _two_bone(root, parent, rest_a, rest_b, l1, l2, target, pole):
    """Two-bone IK from joint `root` under a parent world rotation `parent`:
    rotations (relative to the parent, then to the first bone) that aim the
    bones, rest directions `rest_a` and `rest_b`, at `target`, bending
    towards `pole`. Returns (first, second, second's world rotation)."""
    d = Vector(target) - root
    dist = min(max(d.length, abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    u = d.normalized()
    w = pole - u * pole.dot(u)
    w = w.normalized() if w.length > 1e-6 else Vector((0, 1, 0))
    a = max(-1.0, min(1.0, (l1 ** 2 + dist ** 2 - l2 ** 2) / (2 * l1 * dist)))
    mid = root + u * (l1 * a) + w * (l1 * math.sqrt(1 - a * a))
    end = root + u * dist
    first = rest_a.rotation_difference(parent.inverted() @ (mid - root).normalized()).to_matrix()
    first_world = parent @ first
    second = rest_b.rotation_difference(first_world.inverted() @ (end - mid).normalized()).to_matrix()
    return first, second, first_world @ second


def _ik(rig, pose, sd, target, pitch, posed_hips):
    """Leg IK: thigh and shin reach the ankle `target` with the knee towards
    the hips' forward; the foot takes `pitch` (toe up positive) about X."""
    leg = rig.legs[sd]
    hips_delta = _rot3(pose.rot.get("hips", (0, 0, 0)))
    hip = (posed_hips @ rig.rest["hips"].inverted() @ leg.hip.to_4d()).to_3d()
    thigh, shin, shin_world = _two_bone(hip, hips_delta, (leg.knee - leg.hip).normalized(),
                                        (leg.ankle - leg.knee).normalized(), leg.l1, leg.l2, target,
                                        hips_delta @ Vector((0, 1, 0)))
    pose.rot[f"thigh_{sd}"] = thigh
    pose.rot[f"shin_{sd}"] = shin
    pose.rot[f"foot_{sd}"] = shin_world.inverted() @ Matrix.Rotation(math.radians(pitch), 3, "X")


def _arm_ik(rig, pose, sd, target, hand):
    """Arm IK: upper arm and forearm reach the wrist `target`, the elbow out
    and back; the hand takes the world rotation `hand` (from its rest)."""
    rest = rig.rest
    posed = _fk(rest, _bases(rest, pose))
    chest = _rot3(pose.rot.get("hips", (0, 0, 0))) @ _rot3(pose.rot.get("spine", (0, 0, 0))) @ \
        _rot3(pose.rot.get("chest", (0, 0, 0)))
    shoulder = posed[f"upper_arm_{sd}"].translation
    j = [rest[f"{b}_{sd}"].translation for b in ("upper_arm", "forearm", "hand")]
    out = 1 if sd == "r" else -1
    upper, fore, fore_world = _two_bone(shoulder, chest, (j[1] - j[0]).normalized(), (j[2] - j[1]).normalized(),
                                        (j[1] - j[0]).length, (j[2] - j[1]).length, target,
                                        chest @ Vector((0.6 * out, -1, -0.4)))
    pose.rot[f"upper_arm_{sd}"] = upper
    pose.rot[f"forearm_{sd}"] = fore
    pose.rot[f"hand_{sd}"] = fore_world.inverted() @ hand


def _hip_need(rig, pose):
    """For a standing pose: the highest hips offset (z) at which every foot
    target is within reach, and never above `drop` below the rest pose."""
    pose.offset.z = 0.0
    posed = _fk(rig.rest, _bases(rig.rest, pose))
    needs = [-pose.drop]
    for sd, (target, _) in pose.feet.items():
        leg = rig.legs[sd]
        hip = posed[f"thigh_{sd}"].translation
        flat = Vector((target[0] - hip.x, target[1] - hip.y))
        reach = pose.reach * (leg.l1 + leg.l2)
        needs.append(target[2] + math.sqrt(max(reach ** 2 - flat.length_squared, 0.0)) - hip.z)
    return _softmin(needs)


def _settle(needs, stiffness=1.2):
    """A smooth hips height under a loop of per-frame limits: the lower
    envelope of parabolas hung from each limit, so the hips never rise
    above a limit and never change direction abruptly."""
    n = len(needs)
    out = []
    for i in range(n):
        out.append(min(needs[j] + stiffness * (min(abs(i - j), n - abs(i - j)) / n) ** 2 for j in range(n)))
    return out


def _solve(rig, pose):
    """Places the hips for `pose` (unless it is standing and its hips height
    is already set) and solves its legs."""
    rest = rig.rest
    if pose.mode == "seat":
        hip = rig.legs["l"].hip
        pose.offset = Vector((pose.offset.x, -hip.y, SEAT_HEIGHT + THIGH_UNDER[rig.kind] - hip.z))
    posed_hips = _fk(rest, {"hips": _bases(rest, pose)["hips"]})["hips"]
    for sd, (target, pitch) in pose.feet.items():
        _ik(rig, pose, sd, target, pitch, posed_hips)
    for sd, (target, hand) in pose.hands.items():
        _arm_ik(rig, pose, sd, target, hand)
    if pose.mode == "floor":
        pose.offset.z = 0.0
        pose.offset.z = -_contact_z(rig, _fk(rest, _bases(rest, pose)))
    return pose


def _smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def _stance(leg, ph):
    """Ankle (y, z) and foot pitch of a planted foot at leg phase `ph`
    (0 = heel strike, WALK['duty'] = toe-off). The ground under the foot
    slides back at STRIDE per cycle; the foot rolls on its heel after the
    strike and on its toe before lift-off, the pivot never slipping."""
    duty, (f0, f1) = WALK["duty"], WALK["flat"]
    ground = leg.ankle.y + STRIDE * (duty / 2 - ph) - WALK["back"]
    if ph < f0:
        pitch = WALK["heel"] * (1 - _smooth(ph / f0))
    elif ph < f1:
        pitch = 0.0
    else:
        pitch = -WALK["toe"] * _smooth((ph - f1) / (duty - f1))
    pivot = leg.heel if pitch >= 0 else leg.toe
    p = math.radians(pitch)
    dy, dz = -pivot, leg.height
    return (ground + pivot + dy * math.cos(p) - dz * math.sin(p), dy * math.sin(p) + dz * math.cos(p), pitch)


def _hermite(p0, p1, m0, m1, s):
    s2, s3 = s * s, s * s * s
    return (2 * s3 - 3 * s2 + 1) * p0 + (s3 - 2 * s2 + s) * m0 + (-2 * s3 + 3 * s2) * p1 + (s3 - s2) * m1


def walk_foot(leg, ph):
    """Ankle (y, z) and pitch at leg phase `ph` over the whole cycle."""
    duty = WALK["duty"]
    if ph < duty:
        return _stance(leg, ph)
    swing = 1.0 - duty
    s = (ph - duty) / swing
    e = 1e-3
    a, b = _stance(leg, duty), _stance(leg, 0.0)
    da = [(x - y) / e * swing for x, y in zip(a, _stance(leg, duty - e))]
    db = [(x - y) / e * swing for x, y in zip(_stance(leg, e), b)]
    # The foot lifts early in the swing and reaches out before the strike.
    y = _hermite(a[0], b[0], da[0], 0.5 * db[0], s)
    z = _hermite(a[1], b[1], da[1], db[1], s) + WALK["lift"] * math.sin(math.pi * s ** 0.55) ** 2
    pitch = _hermite(a[2], b[2], 0.0, 0.0, s)
    return y, z, pitch


def walk_pose(phase, rig):
    p = Pose("stand")
    c = math.cos(2 * math.pi * phase)
    s = math.sin(2 * math.pi * phase)
    for sd, ph in (("l", phase), ("r", (phase + 0.5) % 1.0)):
        leg = rig.legs[sd]
        y, z, pitch = walk_foot(leg, ph)
        p.feet[sd] = (Vector((leg.ankle.x, y, z)), pitch)
        # Arms swing against the legs, the forearm lifting on the forward swing.
        cc = math.cos(2 * math.pi * ph)
        p.side("upper_arm", sd, -24 * cc, 4, 0)
        p.side("forearm", sd, 16 + 14 * max(0.0, -cc))
        p.side("hand", sd, 4)
    twist = -5 * c
    p.set("hips", 0, 0, twist)
    p.set("spine", -3, 0, -twist * 0.6)
    p.set("chest", -1, 0, -twist * 0.9)
    p.set("neck", 2, 0, 0)
    p.set("head", 1.5 * math.cos(4 * math.pi * phase), 0, 0)
    p.offset = Vector((-0.014 * s, 0, 0))
    return p


def idle_pose(phase, rig):
    p = Pose("stand")
    p.drop = 0.012  # soft knees
    breath = math.sin(4 * math.pi * phase)  # two breaths
    shift = math.sin(2 * math.pi * phase)   # one weight shift
    roll = -1.5 * shift  # the hip over the weight-bearing leg rises
    p.offset = Vector((0.018 * shift, 0, 0))
    for sd in "lr":
        leg = rig.legs[sd]
        p.feet[sd] = (leg.ankle.copy(), 0.0)
        p.side("upper_arm", sd, 2 + 1.2 * breath, 3 + 0.8 * breath)
        p.side("forearm", sd, 10)
        p.side("hand", sd, 3)
    p.set("hips", 0, roll, 0)
    p.set("spine", -1 - 0.6 * breath, -roll * 1.4, 0)
    p.set("chest", 1.2 * breath, -0.8 * shift, 0)
    p.set("neck", -0.6 * breath, 0.6 * shift, 0)
    p.set("head", 1.5, 0.5 * shift, 5 * math.sin(2 * math.pi * phase + 1.0))
    return p


def _seated(rig, breath):
    """Seated: the feet flat on the floor a little ahead of the knees."""
    p = Pose("seat")
    for sd in "lr":
        leg = rig.legs[sd]
        p.feet[sd] = (Vector((leg.ankle.x, 0.92 * leg.l1 + 0.04, leg.height)), 0.0)
    p.set("spine", -1 - 0.6 * breath)
    p.set("chest", 1.0 * breath)
    p.set("neck", -0.5 * breath)
    p.set("head", 3)
    return p


def _hand(pitch, inward, sd):
    """A hand's world rotation: pitched forward from hanging (90 = pointing
    ahead) and turned `inward` towards the body's midline."""
    turn = inward if sd == "l" else -inward
    return Matrix.Rotation(math.radians(-turn), 3, "Z") @ Matrix.Rotation(math.radians(pitch), 3, "X")


def sit_pose(phase, rig):
    breath = math.sin(2 * math.pi * phase)
    p = _seated(rig, breath)
    for sd in "lr":
        # Wrists resting on top of the thighs, hands draped forward.
        leg = rig.legs[sd]
        top = SEAT_HEIGHT + 2 * THIGH_UNDER[rig.kind] - 0.05
        p.hands[sd] = (Vector((leg.hip.x * 1.3, 0.24, top + 0.035 + 0.003 * breath)), _hand(100, 10, sd))
    return p


def typing_pose(phase, rig):
    p = _seated(rig, 0.4 * math.sin(2 * math.pi * phase))
    p.set("spine", -5)
    p.set("chest", -3)
    p.set("head", 10)
    for sd, off in (("l", 0.0), ("r", 0.5)):
        # Wrists over a keyboard on a desk about 0.74 m high, fingers tapping.
        tap = max(0.0, math.sin(2 * math.pi * (3 * phase + off)))
        x = -0.17 if sd == "l" else 0.17
        p.hands[sd] = (Vector((x, TYPING[1], TYPING[2] + 0.008 * tap)), _hand(84 - 9 * tap, 12, sd))
    return p


ACTIONS = {  # name: (seconds, pose(phase, rig))
    "walk": (1.0, walk_pose),
    "idle": (6.0, idle_pose),
    "sit": (3.0, sit_pose),
    "typing": (1.0, typing_pose),
}


def add_actions(arm, kind=None, actions=None):
    """Creates the actions on `arm` (fitted to its own joint positions) and
    stashes each on an NLA track of the same name, leaving the armature in
    its rest pose. Returns {name: action}."""
    rig = Rig(arm, kind or arm.get("kind", "human"))
    ad = arm.animation_data_create()
    out = {}
    for name, (seconds, pose_fn) in (actions or ACTIONS).items():
        act = bpy.data.actions.new(name)
        ad.action = act
        frames = int(round(seconds * FPS))
        poses = [pose_fn(f / frames, rig) for f in range(frames)]
        standing = [k for k, p in enumerate(poses) if p.mode == "stand"]
        if standing:
            heights = _settle([_hip_need(rig, poses[k]) for k in standing]) if len(standing) == frames else \
                [_hip_need(rig, poses[k]) for k in standing]
            for k, h in zip(standing, heights):
                poses[k].offset.z = h
        for f in range(frames + 1):
            pose = _solve(rig, poses[f % frames])
            bases = _bases(rig.rest, pose)
            for bone in BONES:
                pb = arm.pose.bones[bone]
                loc, rot, _ = bases[bone].decompose()
                if rot.w < 0:
                    rot = -rot
                pb.rotation_quaternion = rot
                pb.keyframe_insert("rotation_quaternion", frame=f)
                if bone == "hips":
                    pb.location = loc
                    pb.keyframe_insert("location", frame=f)
        for fc in _fcurves(act):
            for k in fc.keyframe_points:
                k.interpolation = "LINEAR"
        track = ad.nla_tracks.new()
        track.name = name
        track.strips.new(name, 0, act)
        ad.action = None
        out[name] = act
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    return out


def _fcurves(act):
    if hasattr(act, "fcurves") and len(getattr(act, "fcurves", [])):
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out


# ---- Assets ----

def build_character(kind, materials=None):
    """The complete character of `kind` in the current scene: rig, parts
    and actions. Returns (armature, {name: object})."""
    arm = build_rig(kind)
    objects = (build_human if kind == "human" else build_robot)(arm, materials)
    add_actions(arm, kind)
    return arm, objects


def character_human():
    build_character("human")


def character_robot():
    build_character("robot")


ASSETS = {
    "character_human": character_human,
    "character_robot": character_robot,
}
ANIMATED = set(ASSETS)
