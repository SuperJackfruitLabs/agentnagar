"""Props for the cel-shaded anime kit, after the 06 sheets: the square's
black classic street lamps and bollards, park benches of warm slats on
black iron, cream café umbrellas and bistro tables, and the interiors: the
workshop's timber workbench, pegboard of tools and black industrial
pendant lamps, desks with monitors, the library's pale-wood bookshelves and
reading armchairs.

Conventions (as the low-poly kit's props, so the pack places and seats
people the same way): Blender Z-up, pieces face +Y (Godot -Z); the origin
is the centre of the footprint on the floor. Seat assets
(`seat_<kind>_v2`) instead put the origin at the seated occupant's position
on the floor, facing +Y: a bench or café chair seat is 0.47 m high, a desk
chair 0.5 m, a reading chair's cushion 0.42 m; a desk seat's desk and
monitor stand ahead of the sitter, the display facing them. Each asset is an
empty named after it parenting one merged mesh, `body`, plus the parts the
pack drives by name: `light` (a lamp's glowing glass; the pack adds an
OmniLight there) and `screen` (a monitor's display, in `glass_light`, so
it glows at night).

Wall and ceiling pieces also stand on the floor origin: the pegboard hangs
on the wall plane behind it (its back at y = -0.05) from 1.0 m to 2.2 m, over
a workbench; the pendant lamp hangs from 3.7 m down to a shade 2.5 m up.
"""
import math

from mathutils import Vector

from lib import Mesh, rotx, roty, rotz
from vegetation import add, finish, frond, puff

import usables  # noqa: E402  (tools/styles/shared, on the path from vegetation: the things to use)


class Frame:
    """Places parts in a local frame (turned about Z by `deg`, moved to
    `at`), so one piece can be reused turned and moved."""

    def __init__(self, m, deg=0.0, at=(0, 0, 0)):
        self.m = m
        self.r = rotz(deg)
        self.t = Vector(at)

    def p(self, v):
        return self.r @ Vector(v) + self.t

    def box(self, size, at, mat, bevel=0.0, rot=None):
        self.m.box(size, self.p(at), mat, bevel=bevel, rot=self.r @ rot if rot is not None else self.r)

    def beam(self, a, b, thickness, mat):
        self.m.beam(self.p(a), self.p(b), thickness, mat)

    def cylinder(self, radius, depth, at, mat, sides=12, radius_top=None, rot=None, cap=True):
        self.m.cylinder(radius, depth, self.p(at), mat, sides=sides, radius_top=radius_top,
                        rot=self.r @ rot if rot is not None else self.r, cap=cap)


SMOOTH = 40  # degrees: rounds cylinders and domes, keeps boxes crisp


# ---- Street furniture ----

def lamp_post():
    """The sheets' black classic street lamp: a stepped plinth, a slender
    pole with collars, a ladder bar, and a square lantern whose tapering
    glass is `light`, under a flared roof with a finial."""
    m, glow = Mesh(), Mesh()
    m.cylinder(0.25, 0.12, (0, 0, 0.06), "iron", sides=8)
    m.cylinder(0.19, 0.5, (0, 0, 0.37), "iron", sides=12, radius_top=0.09)
    m.cylinder(0.11, 0.06, (0, 0, 0.65), "iron", sides=12)
    m.cylinder(0.065, 2.72, (0, 0, 2.04), "iron", sides=10, radius_top=0.05)
    for z in (1.1, 3.0):
        m.cylinder(0.075, 0.05, (0, 0, z), "iron", sides=10)
    m.beam((-0.34, 0, 3.1), (0.34, 0, 3.1), 0.03, "iron")
    for x in (-0.34, 0.34):
        m.sphere(0.036, (x, 0, 3.1), "iron", subdivisions=1)
    m.cylinder(0.05, 0.2, (0, 0, 3.4), "iron", sides=10, radius_top=0.09)
    # The lantern: a square tray, tapering glass between corner posts, a
    # flared roof, a cap and a finial.
    sq = rotz(45)
    m.cylinder(0.15, 0.05, (0, 0, 3.52), "iron", sides=4, rot=sq)
    glow.cylinder(0.12, 0.42, (0, 0, 3.75), "lamp_glow", sides=4, radius_top=0.2, rot=sq)
    for k in range(4):
        a = math.pi / 2 * k
        c, s = math.cos(a), math.sin(a)
        m.beam((0.13 * c, 0.13 * s, 3.54), (0.215 * c, 0.215 * s, 3.96), 0.03, "iron")
    m.cylinder(0.29, 0.04, (0, 0, 3.98), "iron", sides=4, rot=sq)
    m.cylinder(0.27, 0.12, (0, 0, 4.06), "iron", sides=4, radius_top=0.07, rot=sq)
    m.cylinder(0.05, 0.05, (0, 0, 4.14), "iron", sides=8)
    m.sphere(0.04, (0, 0, 4.18), "iron", subdivisions=1)
    finish("lamp_post", {"body": m, "light": glow}, smooth={"body": SMOOTH})


def bollard():
    """A black bollard: a footing ring, a round post, a band and a
    domed head."""
    m = Mesh()
    m.cylinder(0.12, 0.05, (0, 0, 0.025), "iron", sides=14)
    m.cylinder(0.1, 0.72, (0, 0, 0.41), "iron", sides=14, radius_top=0.095)
    m.cylinder(0.105, 0.04, (0, 0, 0.66), "iron", sides=14)
    m.cylinder(0.098, 0.04, (0, 0, 0.79), "iron", sides=14)
    m.dome(0.098, (0, 0, 0.81), "iron", segments=14, rings=3, squash=0.9)
    finish("bollard", {"body": m}, smooth={"body": SMOOTH})


def bench(f):
    """A park bench seating one at the local origin, facing +Y: warm wooden
    slats, a raked back, on black iron ends with armrests."""
    for y in (-0.165, -0.055, 0.055, 0.165):
        f.box((1.6, 0.095, 0.045), (0, y, 0.4475), "wood_light", bevel=0.01)
    back = rotx(15)
    for z in (0.58, 0.69, 0.8):
        f.box((1.6, 0.035, 0.09), (0, -0.25 - (z - 0.5) * math.tan(math.radians(15)), z), "wood_light",
              bevel=0.01, rot=back)
    # The ends stand no further forward than the slats, so seen from above
    # the bench is one rectangle, as the city stretches it to its
    # footprint: a square-section leg's corner reaches half its diagonal
    # past its line, so the front legs stand back from the slats' edge.
    for x in (-0.68, 0.68):
        f.beam((x, 0.17, 0.0), (x, 0.175, 0.43), 0.05, "iron")
        f.beam((x, -0.2, 0.0), (x, -0.21, 0.43), 0.05, "iron")
        f.beam((x, -0.21, 0.42), (x, -0.31, 0.84), 0.045, "iron")
        f.beam((x, -0.24, 0.41), (x, 0.19, 0.41), 0.045, "iron")
        f.beam((x, 0.175, 0.43), (x, 0.175, 0.63), 0.04, "iron")
        f.box((0.06, 0.44, 0.04), (x, -0.01, 0.65), "iron", bevel=0.012)
        for y in (0.19, -0.2):
            f.box((0.1, 0.1, 0.025), (x, y, 0.0125), "iron", bevel=0.006)


def bench_park():
    m = Mesh()
    bench(Frame(m, at=(0, 0.04, 0)))
    finish("bench_park", {"body": m}, smooth={"body": SMOOTH})


def seat_bench():
    m = Mesh()
    bench(Frame(m))
    finish("seat_bench_v2", {"body": m}, smooth={"body": SMOOTH})


# ---- Café ----

def umbrella_cafe():
    """A cream market umbrella, as on the sheets' square: an eight-panel
    canopy with a gentle crown and a scalloped valance, ribs and stretchers
    beneath, a vent cap and finial, on a pole in a weighted iron base."""
    m = Mesh()
    m.box((0.5, 0.5, 0.07), (0, 0, 0.035), "iron", bevel=0.015)
    m.cylinder(0.08, 0.16, (0, 0, 0.15), "iron", sides=12, radius_top=0.05)
    m.cylinder(0.03, 2.28, (0, 0, 1.24), "warm_white", sides=10)
    n = 8
    apex = Vector((0, 0, 2.4))

    def ring(r, z, k):
        a = 2 * math.pi * k / n
        return Vector((r * math.cos(a), r * math.sin(a), z))

    # Ribs are ridges and each panel sags a little between them.
    verts, faces = [apex], []
    for k in range(n):
        verts += [ring(0.6, 2.22, k), ring(1.15, 1.95, k), ring(0.56, 2.2, k + 0.5), ring(1.06, 1.93, k + 0.5)]
    for k in range(n):
        a, b = 1 + 4 * k, 1 + 4 * ((k + 1) % n)
        mid, low = a + 2, a + 3
        faces += [(0, a, mid), (0, mid, b), (a, a + 1, low, mid), (mid, low, b + 1, b)]
    add(m, verts, faces, "canvas")
    verts, faces = [], []
    for k in range(n):
        a, b = ring(1.15, 1.95, k), ring(1.15, 1.95, k + 1)
        mid = (a + b) / 2
        verts += [a, b, b - Vector((0, 0, 0.1)), mid - Vector((0, 0, 0.17)), a - Vector((0, 0, 0.1))]
        faces.append(tuple(range(5 * k, 5 * k + 5)))
    add(m, verts, faces, "cream")
    for k in range(n):
        m.beam((0, 0, 2.36), ring(1.12, 1.92, k), 0.022, "warm_white")
        m.beam((0, 0, 1.78), ring(0.6, 2.18, k), 0.018, "warm_white")
    m.cylinder(0.05, 0.06, (0, 0, 1.78), "warm_white", sides=10)
    m.cylinder(0.16, 0.07, (0, 0, 2.43), "canvas", sides=8, radius_top=0.03)
    m.sphere(0.035, (0, 0, 2.48), "warm_white", subdivisions=1)
    finish("umbrella_cafe", {"body": m}, smooth={"body": SMOOTH})


def cafe_table(f):
    """A round bistro table: a cream top with a timber edge on a black iron
    pedestal and foot."""
    f.cylinder(0.4, 0.035, (0, 0, 0.7325), "warm_white", sides=18)
    f.cylinder(0.395, 0.03, (0, 0, 0.7), "wood", sides=18)
    f.cylinder(0.035, 0.66, (0, 0, 0.36), "iron", sides=10)
    f.cylinder(0.1, 0.05, (0, 0, 0.66), "iron", sides=10, radius_top=0.05)
    f.cylinder(0.24, 0.04, (0, 0, 0.02), "iron", sides=16, radius_top=0.2)
    f.cylinder(0.08, 0.06, (0, 0, 0.07), "iron", sides=10, radius_top=0.04)


def cafe_chair(f):
    """A bistro chair seating one at the local origin, facing +Y: a timber
    seat on splayed black iron legs, a hooped iron back with two slats."""
    f.box((0.44, 0.42, 0.045), (0, 0, 0.4475), "wood_light", bevel=0.012)
    f.box((0.4, 0.38, 0.03), (0, 0, 0.415), "iron")
    for x in (-0.18, 0.18):
        f.beam((x, 0.17, 0.41), (x * 1.18, 0.21, 0.0), 0.028, "iron")
        f.beam((x, -0.17, 0.41), (x * 1.18, -0.22, 0.0), 0.028, "iron")
        f.beam((x, -0.19, 0.44), (x * 0.95, -0.24, 0.9), 0.028, "iron")
    f.beam((-0.18 * 0.95, -0.24, 0.89), (0.18 * 0.95, -0.24, 0.89), 0.028, "iron")
    for z in (0.64, 0.8):
        f.box((0.38, 0.03, 0.08), (0, -0.2 - (z - 0.45) * 0.1, z), "wood_light", bevel=0.008)
    for x in (-0.198, 0.198):
        f.beam((x, 0.192, 0.18), (x, -0.198, 0.18), 0.02, "iron")


def cafe_table_prop():
    m = Mesh()
    cafe_table(Frame(m))
    finish("cafe_table", {"body": m}, smooth={"body": SMOOTH})


def cafe_table_set():
    """A table with two chairs facing it across the X axis, 70 cm either
    side, as the café terrace seats people."""
    m = Mesh()
    cafe_table(Frame(m))
    cafe_chair(Frame(m, -90, (-0.7, 0, 0)))
    cafe_chair(Frame(m, 90, (0.7, 0, 0)))
    finish("cafe_table_set", {"body": m}, smooth={"body": SMOOTH})


def seat_cafe_table():
    m = Mesh()
    cafe_chair(Frame(m))
    finish("seat_cafe-table_v2", {"body": m}, smooth={"body": SMOOTH})


# ---- Workshop ----

def monitor(f, screen, x, y, z, w=0.6, h=0.36, deg=0.0):
    """A black-bezelled monitor on a stand at (x, y) on a top at height z,
    its display (`screen`) facing +Y (turned by `deg`)."""
    g = Frame(f.m, 0.0, f.p((x, y, 0)))
    g.r = f.r @ rotz(deg)
    g.box((0.22, 0.15, 0.02), (0, -0.02, z + 0.01), "frame", bevel=0.005)
    g.box((0.05, 0.035, 0.16), (0, -0.04, z + 0.09), "frame")
    g.box((w, 0.035, h), (0, -0.02, z + 0.08 + h / 2), "frame", bevel=0.01)
    screen.box((w - 0.05, 0.01, h - 0.05), g.p((0, -0.001, z + 0.08 + h / 2)), "glass_light", rot=g.r)


def workbench():
    """A 3.2 m timber workbench, as in the workshop sheet: a thick top on
    black steel legs, a shelf of crates and a red toolbox, a green cutting
    mat with a little white rover, a pencil pot, mug, parts trays and a
    vice, and a monitor at the back whose display is `screen`, facing the
    worker at the front (+Y)."""
    m, screen = Mesh(), Mesh()
    f = Frame(m)
    top = 0.92
    f.box((3.2, 1.0, 0.08), (0, 0, top - 0.04), "wood_light", bevel=0.015)
    for x in (-1.5, 1.5):
        for y in (-0.42, 0.42):
            f.box((0.07, 0.07, top - 0.08), (x, y, (top - 0.08) / 2), "frame")
        f.box((0.06, 0.84, 0.06), (x, 0, 0.2), "frame")
    f.box((3.0, 0.05, 0.08), (0, -0.42, top - 0.12), "frame")
    f.box((3.0, 0.86, 0.03), (0, 0, 0.245), "wood")
    f.box((0.5, 0.4, 0.3), (-1.0, 0.05, 0.41), "wood_light", bevel=0.01)
    f.box((0.46, 0.36, 0.02), (-1.0, 0.05, 0.56), "wood")
    f.box((0.45, 0.36, 0.24), (-0.4, -0.05, 0.38), "wood_light", bevel=0.01)
    f.box((0.55, 0.28, 0.22), (0.75, 0.08, 0.37), "vermilion", bevel=0.015)
    f.box((0.3, 0.04, 0.03), (0.75, 0.08, 0.5), "frame")
    # Cutting mat and the white rover on it.
    f.box((1.2, 0.6, 0.01), (-0.35, 0.08, top + 0.005), "leaf_dark")
    z = top + 0.01
    f.box((0.28, 0.2, 0.12), (-0.3, 0.1, z + 0.1), "warm_white", bevel=0.02)
    f.box((0.2, 0.14, 0.05), (-0.3, 0.1, z + 0.185), "warm_white", bevel=0.012)
    f.cylinder(0.045, 0.06, (-0.18, 0.1, z + 0.16), "frame", sides=10, rot=roty(90))
    f.cylinder(0.03, 0.02, (-0.145, 0.1, z + 0.16), "glass", sides=10, rot=roty(90))
    for x in (-0.4, -0.2):
        for y in (-0.01, 0.21):
            f.cylinder(0.045, 0.035, (x, y, z + 0.045), "frame", sides=10, rot=rotx(90))
    f.box((0.2, 0.06, 0.012), (-0.72, 0.2, z + 0.006), "warm_white")
    f.box((0.14, 0.1, 0.03), (-0.75, -0.05, z + 0.015), "blue", bevel=0.005)
    # Pencil pot, mug, parts trays and a vice.
    f.cylinder(0.05, 0.13, (0.45, -0.25, top + 0.065), "frame", sides=8)
    for k, mat in enumerate(("yellow", "vermilion", "blue")):
        a = 2 * math.pi * k / 3
        f.beam((0.45 + 0.02 * math.cos(a), -0.25 + 0.02 * math.sin(a), top + 0.05),
               (0.45 + 0.05 * math.cos(a), -0.25 + 0.05 * math.sin(a), top + 0.23), 0.014, mat)
    f.cylinder(0.045, 0.1, (0.35, 0.28, top + 0.05), "warm_white", sides=10)
    f.box((0.02, 0.05, 0.05), (0.405, 0.28, top + 0.05), "warm_white")
    for k, mat in enumerate(("indigo", "blue", "indigo")):
        f.box((0.18, 0.12, 0.05), (0.75 + k * 0.2, -0.3, top + 0.025), mat, bevel=0.008)
    f.box((0.2, 0.14, 0.1), (1.45, 0.36, top + 0.05), "steel_dark", bevel=0.01)
    f.box((0.2, 0.04, 0.07), (1.45, 0.45, top + 0.07), "steel")
    f.beam((1.33, 0.4, top + 0.06), (1.57, 0.4, top + 0.06), 0.02, "steel")
    monitor(f, screen, 1.05, -0.33, top)
    finish("workbench", {"body": m, "screen": screen}, smooth={"body": SMOOTH})


def pegboard():
    """A pegboard of tools, as over the workshop sheet's benches: a warm
    board in a timber frame, hung with wrenches, screwdrivers, a hammer,
    pliers and a tape. It stands on the floor origin, its back on the wall
    plane (y = -0.05), hanging from 1.0 m to 2.2 m."""
    m = Mesh()
    z0, w, h = 1.0, 2.0, 1.2
    zc = z0 + h / 2
    m.box((w - 0.08, 0.05, h - 0.08), (0, -0.025, zc), "wood_light")
    for x in (-w / 2 + 0.04, w / 2 - 0.04):
        m.box((0.08, 0.07, h), (x, -0.015, zc), "wood", bevel=0.012)
    for z in (z0 + 0.04, z0 + h - 0.04):
        m.box((w, 0.07, 0.08), (0, -0.015, z), "wood", bevel=0.012)
    # The tools hang on hooks just proud of the board.
    t = Frame(m, at=(0, 0.012, 0))
    # A row of wrenches, largest first.
    for k in range(6):
        x = -0.78 + k * 0.1
        ln = 0.42 - k * 0.04
        top = z0 + h - 0.16
        t.box((0.035, 0.02, ln), (x, 0.0, top - ln / 2), "frame")
        t.box((0.07, 0.02, 0.06), (x, 0.0, top), "frame")
        t.box((0.03, 0.022, 0.035), (x, 0.001, top + 0.015), "wood_light")
    # Screwdrivers: coloured handles over steel shafts.
    for k, mat in enumerate(("vermilion", "yellow", "blue", "vermilion")):
        x = -0.12 + k * 0.09
        top = z0 + h - 0.14
        t.box((0.04, 0.03, 0.12), (x, 0.005, top - 0.06), mat, bevel=0.008)
        t.box((0.012, 0.02, 0.2), (x, 0.0, top - 0.22), "steel")
    # Hammer, pliers and a tape measure.
    t.box((0.035, 0.025, 0.34), (0.42, 0.0, z0 + 0.62), "wood", bevel=0.006)
    t.box((0.16, 0.04, 0.05), (0.42, 0.005, z0 + 0.8), "steel_dark", bevel=0.01)
    for s in (-1, 1):
        t.beam((0.62, 0.0, z0 + 0.84), (0.62 + s * 0.05, 0.0, z0 + 0.56), 0.025, "vermilion")
    t.box((0.06, 0.03, 0.06), (0.62, 0.005, z0 + 0.86), "steel_dark", bevel=0.01)
    t.cylinder(0.07, 0.04, (0.8, 0.005, z0 + 0.78), "yellow", sides=12, rot=rotx(90))
    # A second row: a saw, a square and a level.
    t.box((0.5, 0.012, 0.12), (-0.5, 0.0, z0 + 0.3), "steel_light")
    t.box((0.1, 0.03, 0.12), (-0.8, 0.005, z0 + 0.3), "wood", bevel=0.01)
    t.box((0.3, 0.012, 0.03), (0.05, 0.0, z0 + 0.28), "steel")
    t.box((0.03, 0.012, 0.2), (-0.085, 0.0, z0 + 0.37), "steel")
    t.box((0.5, 0.03, 0.05), (0.55, 0.005, z0 + 0.3), "yellow", bevel=0.008)
    t.box((0.06, 0.032, 0.02), (0.55, 0.006, z0 + 0.3), "water_light")
    finish("pegboard", {"body": m}, smooth={"body": SMOOTH})


def pendant_lamp():
    """A black industrial pendant, as over the workshop sheet's benches: a
    ceiling rose and cord from 3.7 m down to a dome shade whose rim is 2.5 m
    above the floor origin, a glowing bulb (`light`) beneath."""
    m, glow = Mesh(), Mesh()
    top, rim = 3.7, 2.5
    m.cylinder(0.07, 0.03, (0, 0, top - 0.015), "frame", sides=12)
    m.cylinder(0.008, top - rim - 0.3, (0, 0, (top + rim + 0.3) / 2), "frame", sides=6)
    m.cylinder(0.035, 0.08, (0, 0, rim + 0.3), "frame", sides=12)
    # The shade: a dome flaring to a lipped rim, open underneath.
    prof = [(0.04, rim + 0.27), (0.1, rim + 0.25), (0.17, rim + 0.19), (0.215, rim + 0.1), (0.24, rim + 0.02),
            (0.25, rim)]
    sides = 16
    verts, faces = [], []
    for r, z in prof:
        for k in range(sides):
            a = 2 * math.pi * k / sides
            verts.append((r * math.cos(a), r * math.sin(a), z))
    for i in range(len(prof) - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            faces.append(((i + 1) * sides + k, (i + 1) * sides + k2, i * sides + k2, i * sides + k))
    faces.append(tuple(range(sides)))
    add(m, verts, faces, "frame")
    glow.sphere(0.06, (0, 0, rim + 0.05), "lamp_glow", subdivisions=2, scale=(1, 1, 1.15))
    glow.cylinder(0.14, 0.01, (0, 0, rim + 0.2), "lamp_glow", sides=16)
    finish("pendant_lamp", {"body": m, "light": glow}, smooth={"body": SMOOTH, "light": 60})


# ---- Desk ----

def desk_set(f, screen):
    """A desk seating one at the local origin, facing +Y: an indigo task
    chair, a timber desk on black steel legs with a drawer pedestal, a
    monitor (its display is `screen`, facing the sitter), keyboard, mouse,
    mug and a small potted plant."""
    # Chair.
    f.box((0.46, 0.44, 0.08), (0, 0, 0.46), "indigo", bevel=0.03)
    f.box((0.44, 0.07, 0.42), (0, -0.25, 0.77), "indigo", bevel=0.03, rot=rotx(8))
    f.beam((0, -0.2, 0.44), (0, -0.27, 0.6), 0.04, "frame")
    f.cylinder(0.035, 0.36, (0, 0, 0.24), "frame", sides=8)
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        f.beam((0, 0, 0.06), (0.26 * math.cos(a), 0.26 * math.sin(a), 0.04), 0.04, "frame")
        f.box((0.04, 0.04, 0.03), (0.26 * math.cos(a), 0.26 * math.sin(a), 0.015), "frame")
    # Desk, 1.3 m: the desk kind's footprint, so it is filled across
    # without widening the chair.
    top = 0.76
    f.box((1.3, 0.6, 0.04), (0, 0.5, top - 0.02), "wood_light", bevel=0.01)
    for x in (-0.62, 0.62):
        f.box((0.04, 0.04, top - 0.04), (x, 0.26, (top - 0.04) / 2), "frame")
        f.box((0.04, 0.04, top - 0.04), (x, 0.74, (top - 0.04) / 2), "frame")
        f.box((0.04, 0.5, 0.04), (x, 0.5, 0.1), "frame")
    f.box((1.2, 0.02, 0.14), (0, 0.76, top - 0.11), "frame")
    f.box((0.34, 0.5, 0.52), (0.33, 0.5, 0.35), "warm_white", bevel=0.01)
    for z in (0.5, 0.3):
        f.box((0.3, 0.01, 0.16), (0.33, 0.245, z), "cream")
        f.box((0.1, 0.02, 0.015), (0.33, 0.24, z + 0.05), "frame")
    monitor(f, screen, 0, 0.7, top, w=0.56, h=0.34, deg=180)
    f.box((0.44, 0.15, 0.02), (0, 0.38, top + 0.01), "warm_white", bevel=0.005)
    f.box((0.06, 0.1, 0.025), (0.32, 0.38, top + 0.012), "warm_white", bevel=0.008)
    f.cylinder(0.04, 0.1, (-0.36, 0.4, top + 0.05), "vermilion", sides=10)
    f.cylinder(0.06, 0.1, (-0.4, 0.66, top + 0.05), "terracotta", sides=10, radius_top=0.07)
    puff(f.m, f.p((-0.4, 0.66, top + 0.16)), 0.09, "leaf", cap="leaf_light", seed=81, seg=8, rings=5)


def desk_v2():
    m, screen = Mesh(), Mesh()
    desk_set(Frame(m, at=(0, -0.25, 0)), screen)
    finish("desk_v2", {"body": m, "screen": screen}, smooth={"body": SMOOTH})


def seat_desk():
    m, screen = Mesh(), Mesh()
    desk_set(Frame(m), screen)
    finish("seat_desk_v2", {"body": m, "screen": screen}, smooth={"body": SMOOTH})


# ---- Library ----

BOOKS = ["book_a", "book_b", "book_c", "book_d", "book_b", "canvas", "book_a", "indigo", "book_d", "book_c",
         "book_b", "book_a"]


def book(m, x0, x1, z0, h, y0, y1, mat):
    """A book standing on a shelf: its spine (front), top and sides; the back
    and bottom are hidden against the shelf."""
    v = [(x0, y1, z0), (x1, y1, z0), (x1, y1, z0 + h), (x0, y1, z0 + h),
         (x0, y0, z0), (x1, y0, z0), (x1, y0, z0 + h), (x0, y0, z0 + h)]
    add(m, v, [(0, 1, 2, 3), (3, 2, 6, 7), (4, 0, 3, 7), (1, 5, 6, 2)], mat)


def bookshelf_v2():
    """A 2 m library bookshelf in pale timber, as in the facility sheet: five
    shelves full of books in the sheets' colours (some leaning, a stack
    lying flat), a cornice, and a potted plant on top."""
    m = Mesh()
    w, d, h = 2.0, 0.45, 2.3
    for x in (-w / 2 + 0.03, w / 2 - 0.03):
        m.box((0.06, d, h - 0.08), (x, 0, (h - 0.08) / 2), "wood_light", bevel=0.01)
    m.box((0.04, d - 0.04, h - 0.18), (0, -0.01, h / 2 - 0.04), "wood_light")
    m.box((w + 0.06, d + 0.02, 0.08), (0, 0.01, h - 0.04), "wood_light", bevel=0.015)
    m.box((w - 0.04, d - 0.02, 0.1), (0, 0, 0.05), "wood")
    m.box((w - 0.08, 0.02, h - 0.1), (0, -d / 2 + 0.01, h / 2), "wood")
    levels = [0.1, 0.52, 0.94, 1.36, 1.78]
    for z in levels[1:] + [2.2]:
        m.box((w - 0.08, d - 0.03, 0.03), (0, 0.0, z - 0.015), "wood_light")
    k = 0
    for li, z in enumerate(levels):
        for half in (-1, 1):
            x0 = -0.95 if half < 0 else 0.03
            x1 = -0.03 if half < 0 else 0.95
            x = x0 + 0.01
            n = 0
            gap = (li + (half > 0)) % 2
            while True:
                k += 1
                n += 1
                bw = 0.052 + 0.012 * ((k * 7) % 5)
                bh = 0.27 + 0.022 * ((k * 3) % 5)
                if li == 3 and half > 0 and n == 4:
                    for s in range(3):
                        m.box((0.24, 0.27, 0.05), (x + 0.13, 0.03, z + 0.025 + 0.05 * s), BOOKS[(k + s) % 12])
                    x += 0.28
                    continue
                if x + bw > x1 - (0.12 if gap else 0.0):
                    break
                book(m, x, x + bw, z, bh, -0.19, 0.16 - 0.02 * (k % 2), BOOKS[k % len(BOOKS)])
                x += bw + 0.003
            if gap and x < x1 - 0.08:
                m.box((0.05, 0.25, 0.31), (x + 0.1, -0.02, z + 0.145), BOOKS[(k + 5) % 12], rot=roty(22))
    m.cylinder(0.12, 0.2, (0.62, 0, h + 0.1), "terracotta", sides=12, radius_top=0.15)
    for k in range(7):
        a = 2 * math.pi * k / 7
        frond(m, (0.62, 0, h + 0.18), a, 0.22, 0.07, lift=1.1, droop=0.2, mat="leaf" if k % 2 else "leaf_light",
              stations=3, notch=0.0)
    for s in range(2):
        m.box((0.3, 0.22, 0.05), (-0.55, 0.0, h + 0.025 + 0.05 * s), ("book_b", "book_c")[s], rot=rotz(8 * s))
    finish("bookshelf_v2", {"body": m}, smooth={"body": SMOOTH})


def reading_chair(f):
    """A timber-framed reading armchair with plump indigo cushions and a
    yellow pillow, seating one at the local origin facing +Y."""
    for x in (-0.37, 0.37):
        f.box((0.1, 0.74, 0.46), (x, -0.02, 0.31), "wood_light", bevel=0.02)
        f.box((0.13, 0.78, 0.045), (x, -0.02, 0.56), "wood", bevel=0.012)
        for y in (-0.31, 0.27):
            f.box((0.07, 0.07, 0.1), (x, y, 0.05), "wood")
    f.box((0.66, 0.68, 0.12), (0, -0.02, 0.18), "wood")
    # The cushion stops 0.24 m ahead of the sitter, within the square round
    # them: the arms either side are the footprint.
    f.box((0.64, 0.54, 0.17), (0, -0.03, 0.33), "indigo", bevel=0.05)
    back = rotx(14)
    f.box((0.66, 0.1, 0.66), (0, -0.34, 0.6), "wood_light", bevel=0.02, rot=back)
    f.box((0.6, 0.15, 0.52), (0, -0.25, 0.64), "indigo", bevel=0.06, rot=back)
    f.box((0.28, 0.11, 0.24), (0.15, -0.14, 0.55), "yellow", bevel=0.045, rot=back @ rotz(-10))


def reading_chair_v2():
    m = Mesh()
    reading_chair(Frame(m, at=(0, 0.04, 0)))
    finish("reading_chair_v2", {"body": m}, smooth={"body": SMOOTH})


def seat_reading_chair():
    m = Mesh()
    reading_chair(Frame(m))
    finish("seat_reading-chair_v2", {"body": m}, smooth={"body": SMOOTH})


# ---- Things to use: displays and perches ----

# The kit's colour for each role in the shared things to use: black iron
# and warm timber, a vermilion roof, pale stone and red brick, and dark
# faces (a chalkboard green, an indigo screen) the light text reads on.
USE_LOOK = {
    "post": "iron", "post_foot": "iron", "frame": "wood", "board": "leaf_dark",
    "roof": "vermilion", "roof_ridge": "brick_dark",
    "stone": "stone", "stone_dark": "stone_dark", "plaque": "steel_dark", "plaque_frame": "brass",
    "base": "stone_dark", "housing": "warm_white", "canopy": "vermilion", "bezel": "iron", "screen": "indigo",
    "step": "stone", "nosing": "stone_dark", "wall": "brick", "coping": "stone",
    "basin": "stone", "rim": "stone_dark", "water": "water",
    "seat_block": "stone_dark", "seat": "wood_light",
}


def used(name, build, display=False, look=None, ornament=None):
    """Asset `name` from the shared builder `build` in a kit's look (this
    kit's unless given), with `ornament` (a function of its parts) adding
    the kit's own; a display gets its `display` empty. Round parts are
    smooth-shaded, as toon light wants."""
    def run():
        parts = build(look or USE_LOOK)
        if ornament is not None:
            ornament(parts)
        finish(name, parts, smooth={node: SMOOTH for node in parts})
        if display:
            usables.display_node(name)
    run.__doc__ = build.__doc__
    return run


def _outline_board(parts):
    """The noticeboard's frame picked out in black iron, as the sheets ink
    their signs."""
    m = parts["body"]
    for z in (0.855, 1.745):
        m.box((1.04, 0.09, 0.02), (0, 0, z), "iron")


def _lantern_kiosk(parts):
    """A little lantern on the kiosk's canopy, the square's lamps' glow."""
    m = parts["body"]
    m.cylinder(0.05, 0.12, (0, 0, 1.94), "iron", sides=8)
    m.sphere(0.07, (0, 0, 2.06), "lamp_glow", subdivisions=1)


def _cushioned_seat(parts):
    """A cushion on the perch's seat, as the sheets pad a bench."""
    parts["body"].box((0.24, 0.40, 0.03), (0, usables.SEAT_FRONT - 0.22, usables.SEAT_TOP + 0.015), "indigo", bevel=0.01)


# The workstation in the kit's look: an indigo task chair at a timber desk
# on black steel, a black monitor with its screen inked round (the kit's
# inked frame).
WORK_LOOK = {
    **USE_LOOK, "chair": "indigo", "chair_frame": "frame", "desk": "wood_light", "desk_leg": "frame",
    "drawer": "warm_white", "keys": "warm_white", "casing": "frame", "screen": "indigo", "trim": "iron",
    "frame_style": "inked",
}


def _mug_and_plant(parts):
    """A vermilion mug and a little potted plant on the desk's left."""
    m = parts["body"]
    top = usables.DESK_TOP
    m.cylinder(0.04, 0.1, (-0.36, 0.42, top + 0.05), "vermilion", sides=10)
    m.cylinder(0.06, 0.1, (-0.46, 0.72, top + 0.05), "terracotta", sides=10, radius_top=0.07)
    puff(m, (-0.46, 0.72, top + 0.16), 0.09, "leaf", cap="leaf_light", seed=83, seg=8, rings=5)


ASSETS = {
    "workstation": used("workstation", usables.workstation, display=True, look=WORK_LOOK, ornament=_mug_and_plant),
    "noticeboard": used("noticeboard", usables.noticeboard, display=True, ornament=_outline_board),
    "plaque": used("plaque", usables.plaque, display=True),
    "kiosk": used("kiosk", usables.kiosk, display=True, ornament=_lantern_kiosk),
    "steps": used("steps", usables.steps),
    "low_wall": used("low_wall", usables.low_wall),
    "fountain": used("fountain", usables.fountain),
    "perch_seat": used("perch_seat", usables.perch_seat, ornament=_cushioned_seat),
    "lamp_post": lamp_post,
    "bollard": bollard,
    "bench_park": bench_park,
    "seat_bench_v2": seat_bench,
    "umbrella_cafe": umbrella_cafe,
    "cafe_table": cafe_table_prop,
    "cafe_table_set": cafe_table_set,
    "seat_cafe-table_v2": seat_cafe_table,
    "workbench": workbench,
    "pegboard": pegboard,
    "pendant_lamp": pendant_lamp,
    "desk_v2": desk_v2,
    "seat_desk_v2": seat_desk,
    "bookshelf_v2": bookshelf_v2,
    "reading_chair_v2": reading_chair_v2,
    "seat_reading-chair_v2": seat_reading_chair,
}
