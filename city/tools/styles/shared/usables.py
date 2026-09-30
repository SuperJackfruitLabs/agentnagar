"""Things to use (interactions spec sections 2 to 5), shared by the kits
built on the low-poly lib (low-poly, anime, solarpunk and neon noir): the
displays (noticeboard, plaque, kiosk), the perches (steps, low wall,
fountain) and the seat a sitter takes on one, the meadow's grass and
flower clumps, and the workstation: a desk, its chair and a monitor.

Every kit draws the same object from these builders: its size, its parts,
where a display's face is and where a sitter sits, so a noticeboard is a
board on two posts in every style (the visual consistency contract). A
kit passes its `look`, the palette key for each role, and adds its own
ornament.

Conventions (as the kits' props): Blender Z-up, pieces face +Y (Godot
-Z); the origin is the centre of the kind's footprint on the ground, so a
piece fills its catalogue footprint (city/catalogue/catalogue.json) in the
walking band, 0.25 to 1.9 m up (the pack stretches a `fill` piece to the
cells the grid blocks). Above the band a piece may reach past it (a
noticeboard's roof).

- A display carries an empty named `display` at the middle of its face,
  its -Z (Godot) the face's outward normal, where the pack mounts the
  surface's text. Its scale is the face's size, its width along X and its
  height along Z (Godot Y), so the pack fits the text to the face drawn.
- A perch's sit anchors lie just outside its solid part, facing out.
  `perch_seat` is the seat a sitter takes there: its origin is the
  sitter's place on the ground (the anchor), facing +Y, and it reaches
  back into the perch, so a sitter's hips (over the anchor, as the
  characters sit) rest on it at SEAT_TOP.
- A meadow clump carries a second UV map, `bend`, whose U is the bend
  weight: 0 at a blade's root rising to 1 at its tip (Task 8's sway reads
  it as UV2.x).
- The workstation is a seat: its origin is the sitter's place, facing +Y,
  with the desk ahead on the kind's footprint and the chair in the square
  round the sitter. Its monitor's face looks back at the sitter, so its
  `display` empty is turned (DISPLAY_TURN); its screen is its own part,
  `screen`, which the pack lights (idle, in use, or the station computer
  itself).
"""
import math
import random

import bpy

import lib
from lib import Mesh

# How high a perch's seat is: the characters sit with their hips 0.45 to
# 0.6 m up over the seat's origin (the kits' SEAT_HEIGHT, 0.45 m).
SEAT_TOP = 0.46
# How far a perch's seat reaches in front of the sitter's place, under the
# thighs: inside the 25 cm square round the sit anchor that the collision
# audit leaves to a seat's own furniture.
SEAT_FRONT = 0.15
# The perches' solid part is this high (the catalogue's `height`).
PERCH_TOP = 0.45
# Where each display's face is (the `display` empty), in the piece's frame,
# and its size (width, height), as the builders below draw it.
DISPLAY = {
    "noticeboard": ((0.0, 0.042, 1.30), (0.94, 0.80)),
    "plaque": ((0.0, 0.125, 0.975), (0.48, 0.34)),
    "kiosk": ((0.0, 0.245, 1.30), (0.60, 0.80)),
    "workstation": ((0.0, 0.880, 1.02), (0.54, 0.30)),
}
# Displays whose face looks back (-Y) rather than out of the front: the
# workstation's monitor faces its sitter. Degrees about the vertical.
DISPLAY_TURN = {"workstation": 180.0}


def display_node(root_name):
    """The `display` empty under asset `root_name`, at the middle of its
    face (DISPLAY), facing the piece's front (or turned, DISPLAY_TURN),
    scaled to the face's size."""
    at, (width, height) = DISPLAY[root_name]
    root = bpy.data.objects[root_name]
    e = bpy.data.objects.new("display", None)
    bpy.context.scene.collection.objects.link(e)
    e.parent = root
    e.location = at
    e.rotation_euler = (0.0, 0.0, math.radians(DISPLAY_TURN.get(root_name, 0.0)))
    e.scale = (width, 1.0, height)
    return e


def ring(m, r0, r1, z0, z1, mat, sides=48, bottom=False):
    """An upright ring from radius r0 to r1 (its corners on the circles),
    z0 to z1: outer and inner walls and a top, and a bottom when asked."""
    def at(r, k, z):
        a = 2 * math.pi * k / sides
        return (r * math.cos(a), r * math.sin(a), z)
    verts = []
    for r, z in ((r1, z0), (r1, z1), (r0, z1), (r0, z0)):
        verts += [at(r, k, z) for k in range(sides)]
    faces = []
    for k in range(sides):
        n = (k + 1) % sides
        o0, o1, i1, i0 = (k, k + sides, k + 2 * sides, k + 3 * sides)
        p0, p1, q1, q0 = (n, n + sides, n + 2 * sides, n + 3 * sides)
        faces.append((o0, p0, p1, o1))       # outer wall, facing out
        faces.append((o1, p1, q1, i1))       # top
        faces.append((i1, q1, q0, i0))       # inner wall, facing in
        if bottom:
            faces.append((i0, q0, p0, o0))
    m._faces(verts, faces, mat)


def disc(m, r, z, mat, sides=48):
    """A flat disc facing up at height z."""
    verts = [(0.0, 0.0, z)] + [(r * math.cos(2 * math.pi * k / sides), r * math.sin(2 * math.pi * k / sides), z)
                               for k in range(sides)]
    m._faces(verts, [(0, 1 + k, 1 + (k + 1) % sides) for k in range(sides)], mat)


# ---- Displays ----

def noticeboard(look):
    """A board on two posts (the kind's 120 x 20 cm footprint): square
    posts at the ends, a framed board between them, its face (`board`) 1 m
    wide from 0.90 to 1.70 m, and a little gabled roof over it, above the
    walking band (from 2.24 m, reaching past the footprint)."""
    m = Mesh()
    for x in (-0.555, 0.555):
        m.box((0.09, 0.09, 2.3), (x, 0, 1.15), look["post"], bevel=0.01)
        m.box((0.13, 0.13, 0.08), (x, 0, 0.04), look["post_foot"])
    m.box((1.02, 0.08, 0.9), (0, 0, 1.30), look["frame"], bevel=0.01)
    m.box((0.94, 0.004, 0.8), (0, 0.04, 1.30), look["board"])
    # A ledge under the board, as a notice's pins and chalk would sit on.
    m.box((1.02, 0.12, 0.04), (0, 0.02, 0.84), look["frame"])
    # The roof: two slopes meeting at a ridge along x, over a beam.
    m.box((1.2, 0.1, 0.06), (0, 0, 2.27), look["frame"])
    for s in (-1, 1):
        m.box((1.44, 0.34, 0.04), (0, s * 0.15, 2.36), look["roof"], rot=lib.rotx(-s * 24))
    m.box((1.46, 0.05, 0.05), (0, 0, 2.45), look["roof_ridge"])
    return {"body": m}


def plaque(look):
    """A lettered plaque on a low stone plinth (60 x 30 cm): a stepped
    plinth, an upright stone to 1.2 m under a cap, and the plaque
    (`plaque`) 50 x 35 cm on its face, from 0.80 to 1.15 m."""
    m = Mesh()
    m.box((0.6, 0.3, 0.2), (0, 0, 0.1), look["stone_dark"], bevel=0.015)
    m.box((0.54, 0.24, 0.98), (0, -0.01, 0.69), look["stone"], bevel=0.012)
    m.box((0.6, 0.29, 0.06), (0, -0.005, 1.21), look["stone_dark"], bevel=0.012)
    m.box((0.52, 0.02, 0.38), (0, 0.113, 0.975), look["plaque_frame"], bevel=0.005)
    m.box((0.48, 0.006, 0.34), (0, 0.124, 0.975), look["plaque"])
    return {"body": m}


def kiosk(look):
    """A standing screen for browsing (80 x 50 cm): a plinth, a housing to
    1.8 m under a canopy, a lectern ledge, and the screen (`screen`) 60 x
    80 cm on its face, from 0.90 to 1.70 m."""
    m, screen = Mesh(), Mesh()
    m.box((0.8, 0.5, 0.14), (0, 0, 0.07), look["base"], bevel=0.015)
    m.box((0.72, 0.44, 1.66), (0, -0.01, 0.97), look["housing"], bevel=0.02)
    m.box((0.8, 0.5, 0.08), (0, 0, 1.84), look["canopy"], bevel=0.015)
    m.box((0.68, 0.02, 0.86), (0, 0.22, 1.30), look["bezel"], bevel=0.008)
    screen.box((0.6, 0.006, 0.8), (0, 0.232, 1.30), look["screen"])
    m.box((0.66, 0.1, 0.03), (0, 0.2, 0.82), look["canopy"], rot=lib.rotx(-12))
    return {"body": m, "screen": screen}


# ---- Perches ----

def steps(look):
    """Broad steps (300 x 100 cm) sat on at their top step's front edge,
    looking out (+Y): the top step 45 cm high and 50 cm deep, the lower
    one 30 cm and 50 cm deep behind it, each with a nosing along its
    front."""
    m = Mesh()
    m.box((3.0, 0.5, 0.45), (0, -0.25, 0.225), look["step"], bevel=0.012)
    m.box((3.0, 0.5, 0.30), (0, -0.75, 0.15), look["step"], bevel=0.012)
    m.box((3.0, 0.06, 0.04), (0, -0.03, 0.43), look["nosing"])
    m.box((3.0, 0.06, 0.04), (0, -0.53, 0.28), look["nosing"])
    return {"body": m}


def low_wall(look):
    """Three metres of low wall (300 x 30 cm), 40 cm of wall under a 5 cm
    coping, sat on along its front (+Y)."""
    m = Mesh()
    m.box((3.0, 0.28, 0.40), (0, 0, 0.20), look["wall"])
    m.box((3.0, 0.3, 0.05), (0, 0, 0.425), look["coping"], bevel=0.01)
    m.box((3.0, 0.3, 0.06), (0, 0, 0.03), look["coping"])
    return {"body": m}


def fountain(look, sides=48):
    """A round fountain (a 1.5 m disc): a basin wall to 40 cm under a rim
    stone to 45 cm, water brimming inside at 32 cm, and in the middle a
    pedestal carrying two bowls to 1.8 m."""
    m, water = Mesh(), Mesh()
    ring(m, 1.28, 1.5, 0.0, 0.40, look["basin"], sides)
    ring(m, 1.26, 1.5, 0.40, 0.45, look["rim"], sides, bottom=True)
    disc(water, 1.28, 0.32, look["water"], sides)
    m.cylinder(0.32, 0.36, (0, 0, 0.18), look["basin"], sides=16)
    m.cylinder(0.14, 0.7, (0, 0, 0.65), look["rim"], sides=12)
    m.cylinder(0.12, 0.18, (0, 0, 1.0), look["basin"], sides=16, radius_top=0.55)
    ring(m, 0.5, 0.56, 1.09, 1.15, look["rim"], 24)
    disc(water, 0.5, 1.12, look["water"], 24)
    m.cylinder(0.07, 0.4, (0, 0, 1.3), look["rim"], sides=10)
    m.cylinder(0.06, 0.1, (0, 0, 1.5), look["basin"], sides=12, radius_top=0.26)
    ring(m, 0.23, 0.27, 1.55, 1.59, look["rim"], 16)
    disc(water, 0.23, 1.57, look["water"], 16)
    m.cylinder(0.04, 0.2, (0, 0, 1.68), look["rim"], sides=8)
    m.sphere(0.06, (0, 0, 1.8), look["rim"], subdivisions=1)
    return {"body": m, "water": water}


def perch_seat(look):
    """The seat a sitter takes on a perch: a block 26 cm wide from 40 cm
    behind the sitter's place (inside the perch) to 5 cm short of the
    seat's front, topped by a seat 30 cm wide to SEAT_TOP that reaches
    SEAT_FRONT in front, under the thighs."""
    m = Mesh()
    back = -0.40
    m.box((0.26, SEAT_FRONT - 0.05 - back, 0.40), (0, (back + SEAT_FRONT - 0.05) / 2, 0.20), look["seat_block"])
    m.box((0.30, SEAT_FRONT - back, 0.06), (0, (back + SEAT_FRONT) / 2, SEAT_TOP - 0.03), look["seat"], bevel=0.012)
    return {"body": m}


# ---- The meadow ----

def _blade(m, rng, base, lean, height, width, mat, segments=3):
    """One blade of grass (or a stem) from `base`: a strip leaning out by
    `lean` (a vector, metres at its tip), tapering from `width` to a point,
    one face thick (the kits' materials are double-sided); each vertex's
    bend weight rises with its height up the blade."""
    bx, by = base
    lx, ly = lean
    # Across the blade, square to its lean.
    a = rng.uniform(0, math.pi)
    cx, cy = math.cos(a) * width / 2, math.sin(a) * width / 2
    verts, w = [], []
    for s in range(segments):
        t = s / segments
        curve = t * t
        px, py, pz = bx + lx * curve, by + ly * curve, height * t
        taper = 1.0 - t
        verts += [(px - cx * taper, py - cy * taper, pz), (px + cx * taper, py + cy * taper, pz)]
        w += [t, t]
    verts.append((bx + lx, by + ly, height))
    w.append(1.0)
    faces = []
    for s in range(segments - 1):
        k = 2 * s
        faces.append((k, k + 1, k + 3, k + 2))
    tip = len(verts) - 1
    faces.append((2 * (segments - 1), 2 * (segments - 1) + 1, tip))
    _weighted(m, verts, faces, mat, w)
    return verts[-1]


def _weighted(m, verts, faces, mat, w):
    """Adds faces to Mesh `m` on vertices of their own, recording each
    vertex's bend weight, and a normal (in `m.normals`, the convention the
    anime kit's finish applies) from a smooth field: up, leaning out from
    the clump's middle. So a clump is lit as one soft tuft, and a line pass
    that inks normal creases does not ink every blade."""
    idx = m.slot(mat)
    layer = m.bm.verts.layers.float.get("bend") or m.bm.verts.layers.float.new("bend")
    if not hasattr(m, "normals"):
        m.normals = {}
    vs = []
    for v, wt in zip(verts, w):
        m.normals[len(m.bm.verts)] = _tuft_normal(v)
        bv = m.bm.verts.new(v)
        bv[layer] = wt
        vs.append(bv)
    for f in faces:
        try:
            face = m.bm.faces.new([vs[i] for i in f])
        except ValueError:
            continue
        face.material_index = idx


def _tuft_normal(v):
    """The normal field over a clump at point `v`: mostly up, leaning out
    from its middle."""
    x, y, z = v
    n = (x * 0.6, y * 0.6, 0.35)
    length = math.sqrt(sum(c * c for c in n))
    return tuple(c / length for c in n)


def _head(m, at, radius, petal, centre, petals=5):
    """A flower's head at the top of its stem: a flat star of `petals`
    round a centre, facing up; all of it bends as the tip."""
    x, y, z = at
    verts = [(x, y, z + 0.01)]
    for k in range(petals * 2):
        a = math.pi * k / petals
        r = radius if k % 2 == 0 else radius * 0.45
        verts.append((x + r * math.cos(a), y + r * math.sin(a), z))
    n = petals * 2
    faces = [(0, 1 + k, 1 + (k + 1) % n) for k in range(n)]
    _weighted(m, verts, faces, petal, [1.0] * len(verts))
    _weighted(m, [(x, y, z + 0.015), (x + radius * 0.3, y, z + 0.012), (x, y + radius * 0.3, z + 0.012),
                  (x - radius * 0.3, y, z + 0.012), (x, y - radius * 0.3, z + 0.012)],
              [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1)], centre, [1.0] * 5)


def grass_clump(look, seed, blades=14, flowers=0, reach=0.2, height=(0.5, 0.9)):
    """A clump of tall grass, and `flowers` flowers among it, about
    `reach` m round its origin: the meadow plants it by the dozen, each
    copy turned and sized, so a clump is one mesh of a few greens."""
    rng = random.Random(seed)
    m = Mesh()
    greens = [look["grass"], look["grass_dark"], look["grass_light"]]
    for k in range(blades):
        a = 2 * math.pi * (k + rng.uniform(-0.3, 0.3)) / blades
        r = rng.uniform(0.0, 0.05)
        base = (r * math.cos(a), r * math.sin(a))
        out = rng.uniform(0.05, reach - r)
        h = rng.uniform(*height)
        _blade(m, rng, base, (out * math.cos(a), out * math.sin(a)), h, rng.uniform(0.05, 0.08),
               greens[k % len(greens)])
    colours = look.get("flowers", [])
    for k in range(flowers):
        a = 2 * math.pi * (k + 0.5) / max(1, flowers) + rng.uniform(-0.4, 0.4)
        r = rng.uniform(0.02, 0.07)
        base = (r * math.cos(a), r * math.sin(a))
        out = rng.uniform(0.02, 0.06)
        h = rng.uniform(height[0] * 0.9, height[1])
        tip = _blade(m, rng, base, (out * math.cos(a), out * math.sin(a)), h, 0.015, look["stem"])
        _head(m, tip, rng.uniform(0.035, 0.05), colours[k % len(colours)], look["flower_centre"])
    return {"body": m}


def bend_uv(root_name):
    """Writes each vertex's bend weight (the `bend` layer the meadow
    builders record) into a second UV map, `bend` (U the weight), after a
    first all-zero map, so the glTF carries it as TEXCOORD_1 (Godot's
    UV2); then drops the layer."""
    root = bpy.data.objects[root_name]
    for o in root.children:
        me = o.data
        attr = me.attributes.get("bend")
        if attr is None:
            continue
        weights = [d.value for d in attr.data]
        me.uv_layers.new(name="UVMap")
        uv = me.uv_layers.new(name="bend")
        for loop in me.loops:
            uv.data[loop.index].uv = (weights[loop.vertex_index], 0.0)
        me.attributes.remove(me.attributes["bend"])


def meadow(name, seed, flowers, look, finish):
    """A kit's builder for asset `name`: a clump of the meadow's tall grass
    (grass_clump) with `flowers` flowers, in the kit's `look`, finished by
    the kit's `finish`, its bend weight in UV2 (bend_uv)."""
    def run():
        finish(name, grass_clump(look, seed, flowers=flowers))
        bend_uv(name)
    run.__doc__ = meadow.__doc__
    return run


# ---- The workstation ----

# The desk's top: its height, and how far it reaches ahead of the sitter
# (the kind's footprint, 25 to 95 cm ahead, 130 cm across).
DESK_TOP = 0.76
DESK_NEAR, DESK_FAR = 0.25, 0.95
DESK_HALF = 0.65
# The monitor: its panel's front and back (ahead of the sitter), its size
# and middle's height, and the screen on its front (DISPLAY["workstation"]).
MONITOR_FRONT, MONITOR_BACK = 0.885, 0.925
MONITOR_SIZE = (0.60, 0.36)
MONITOR_MIDDLE = 1.02


def workstation(look):
    """A desk seating one at the origin, facing +Y (the workstation kind's
    130 x 70 cm footprint ahead, the chair in the square round the sitter),
    with a monitor at its far edge whose face looks back at the sitter: its
    screen (`screen`) 54 x 30 cm on the monitor's front, the display anchor
    at it, 0.87 to 1.17 m up. A keyboard and a mouse on the desk. The
    monitor's frame is the kit's own (`look["frame_style"]`): `flat`, a
    clean thin bezel; `inked`, a bezel outlined in the ink colour; `wood`,
    a timber frame round the screen; `glass`, a thin glass edge with a
    light strip under it."""
    m, screen = Mesh(), Mesh()
    style = look.get("frame_style", "flat")
    # The chair, inside the square round the sitter.
    m.box((0.46, 0.42, 0.07), (0, 0.0, 0.46), look["chair"], bevel=0.02)
    m.box((0.44, 0.06, 0.40), (0, -0.195, 0.77), look["chair"], bevel=0.02, rot=lib.rotx(-6))
    m.beam((0, -0.17, 0.46), (0, -0.19, 0.6), 0.04, look["chair_frame"])
    m.cylinder(0.035, 0.36, (0, 0, 0.24), look["chair_frame"], sides=8)
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        m.beam((0, 0, 0.05), (0.22 * math.cos(a), 0.22 * math.sin(a), 0.03), 0.04, look["chair_frame"])
    # The desk: its top over the footprint, legs at its corners, a modesty
    # panel along the far edge and a drawer pedestal on the right.
    depth = DESK_FAR - DESK_NEAR
    mid = (DESK_NEAR + DESK_FAR) / 2
    m.box((2 * DESK_HALF, depth, 0.04), (0, mid, DESK_TOP - 0.02), look["desk"], bevel=0.008)
    for x in (-DESK_HALF + 0.03, DESK_HALF - 0.03):
        for y in (DESK_NEAR + 0.03, DESK_FAR - 0.03):
            m.box((0.05, 0.05, DESK_TOP - 0.04), (x, y, (DESK_TOP - 0.04) / 2), look["desk_leg"])
    m.box((2 * DESK_HALF - 0.1, 0.02, 0.3), (0, DESK_FAR - 0.03, DESK_TOP - 0.21), look["desk_leg"])
    m.box((0.36, depth - 0.1, 0.56), (0.38, mid, 0.33), look["drawer"], bevel=0.008)
    for z in (0.5, 0.3):
        m.box((0.3, 0.01, 0.14), (0.38, DESK_NEAR + 0.045, z), look["desk"])
    # The keyboard and the mouse.
    m.box((0.44, 0.15, 0.02), (0, 0.45, DESK_TOP + 0.01), look["keys"], bevel=0.004)
    m.box((0.06, 0.1, 0.025), (0.32, 0.45, DESK_TOP + 0.012), look["keys"], bevel=0.008)
    # The monitor: a foot and a neck behind it, its panel, the screen.
    w, h = MONITOR_SIZE
    m.box((0.24, 0.16, 0.02), (0, MONITOR_BACK - 0.06, DESK_TOP + 0.01), look["casing"], bevel=0.004)
    m.box((0.06, 0.04, MONITOR_MIDDLE - h / 2 - DESK_TOP), (0, MONITOR_BACK - 0.02,
          (DESK_TOP + MONITOR_MIDDLE - h / 2) / 2), look["casing"])
    thick = MONITOR_BACK - MONITOR_FRONT
    m.box((w, thick, h), (0, (MONITOR_FRONT + MONITOR_BACK) / 2, MONITOR_MIDDLE), look["casing"], bevel=0.008)
    (sx, sy, sz), (sw, sh) = DISPLAY["workstation"]
    screen.box((sw, 0.006, sh), (sx, sy + 0.003, sz), look["screen"])
    lip = MONITOR_FRONT - 0.004
    if style == "inked":
        # An ink line round the screen, and round the panel's edge.
        for dz in (-1, 1):
            m.box((sw + 0.03, 0.006, 0.015), (0, lip, sz + dz * (sh / 2 + 0.0075)), look["trim"])
        for dx in (-1, 1):
            m.box((0.015, 0.006, sh + 0.03), (dx * (sw / 2 + 0.0075), lip, sz), look["trim"])
    elif style == "wood":
        # A timber frame standing proud round the screen.
        for dz in (-1, 1):
            m.box((w + 0.04, 0.03, 0.05), (0, MONITOR_FRONT + 0.008, sz + dz * (h / 2 - 0.005)), look["trim"], bevel=0.006)
        for dx in (-1, 1):
            m.box((0.05, 0.03, h + 0.04), (dx * (w / 2 - 0.005), MONITOR_FRONT + 0.008, sz), look["trim"], bevel=0.006)
    elif style == "glass":
        # A glass edge, and a light strip along the panel's foot.
        m.box((w + 0.02, 0.006, h + 0.02), (0, MONITOR_BACK + 0.001, sz), look["trim"])
        m.box((w - 0.08, 0.008, 0.012), (0, lip, sz - h / 2 + 0.012), look["light"])
        m.box((2 * DESK_HALF - 0.04, 0.012, 0.012), (0, DESK_NEAR + 0.004, DESK_TOP - 0.03), look["light"])
    return {"body": m, "screen": screen}
