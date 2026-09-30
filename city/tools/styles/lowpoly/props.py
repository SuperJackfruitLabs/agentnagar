"""Props v2 for the low-poly tropical kit: street furniture, the café, the
workshop and library interiors, paving and garden paths.

Conventions (as vegetation.py): Blender Z-up, pieces face +Y (Godot -Z); the
origin is the centre of the footprint on the ground. Seat assets
(`seat_<kind>_v2`) instead put the origin at the seated occupant's position
on the floor, facing +Y, as kit v1 did. Each asset is an empty named after
it parenting one merged mesh, `body`, plus the parts the pack drives by name:
`light` (a lamp's emissive glass; the pack adds an OmniLight there) and
`screen` (an emissive display). Ground tiles are a single mesh named after
the asset, for MultiMesh use.
"""
import math
import sys
from pathlib import Path

from mathutils import Vector

import lib
from lib import Mesh, rotx, rotz
from vegetation import add, finish, leafy_plant

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import usables  # noqa: E402  (the things to use every kit draws alike)

lib.PALETTE.update({
    "screen": "#9FE3DC",           # a terminal's lit display
    "sand": "#EAD7B0",             # garden path gravel
})
lib.EMISSIVE.setdefault("screen", 1.2)


class Frame:
    """Places parts in a local frame (rotated about Z by `deg`, moved to
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

    def cylinder(self, radius, depth, at, mat, sides=8, radius_top=None):
        self.m.cylinder(radius, depth, self.p(at), mat, sides=sides, radius_top=radius_top, rot=self.r)


# ---- Street furniture ----

def bench(f):
    """A park bench seating one at the local origin, facing +Y: chunky wooden
    slats on dark iron end frames with armrests."""
    for y in (-0.17, 0.0, 0.17):
        f.box((1.6, 0.15, 0.05), (0, y, 0.45), "wood_light", bevel=0.012)
    back = rotx(-12)
    for z in (0.62, 0.79):
        y = -0.26 - (z - 0.55) * math.tan(math.radians(12))
        f.box((1.6, 0.05, 0.13), (0, y, z), "wood_light", bevel=0.012, rot=back)
    for x in (-0.66, 0.66):
        f.beam((x, 0.2, 0.0), (x, 0.2, 0.62), 0.06, "iron")
        f.beam((x, -0.22, 0.0), (x, -0.3, 0.86), 0.06, "iron")
        f.beam((x, -0.26, 0.41), (x, 0.24, 0.41), 0.05, "iron")
        f.box((0.08, 0.5, 0.04), (x, -0.02, 0.64), "wood", bevel=0.01)
        f.box((0.14, 0.1, 0.02), (x, 0.2, 0.01), "iron")
        f.box((0.14, 0.1, 0.02), (x, -0.22, 0.01), "iron")


def bench_park():
    m = Mesh()
    bench(Frame(m, at=(0, 0.03, 0)))
    finish("bench_park", {"body": m})


def seat_bench():
    m = Mesh()
    bench(Frame(m))
    finish("seat_bench_v2", {"body": m})


def bollard():
    """A dark iron bollard with a steel band and a rounded head."""
    m = Mesh()
    m.cylinder(0.12, 0.06, (0, 0, 0.03), "iron", sides=8)
    m.cylinder(0.095, 0.74, (0, 0, 0.43), "iron", sides=8, radius_top=0.085)
    m.cylinder(0.105, 0.05, (0, 0, 0.66), "steel", sides=8)
    m.cylinder(0.09, 0.04, (0, 0, 0.82), "iron", sides=8)
    m.sphere(0.088, (0, 0, 0.84), "iron", subdivisions=2, scale=(1, 1, 0.7), hemisphere=True)
    finish("bollard", {"body": m})


def lamp_post():
    """An ornate lamp post: a stepped plinth, a fluted pole with collars, a
    yellow leaf banner and a square lantern whose glass is `light`."""
    m, glow = Mesh(), Mesh()
    m.cylinder(0.24, 0.22, (0, 0, 0.11), "iron", sides=8)
    m.cylinder(0.18, 0.32, (0, 0, 0.38), "iron", sides=8, radius_top=0.09)
    m.cylinder(0.06, 3.0, (0, 0, 2.04), "iron", sides=8, radius_top=0.05)
    for z in (0.6, 1.3, 3.4):
        m.cylinder(0.085, 0.06, (0, 0, z), "iron", sides=8)
    # Scroll brackets under the lantern.
    for s in (-1, 1):
        m.beam((0, 0, 3.25), (s * 0.13, 0, 3.4), 0.025, "iron")
    # Banner on a short arm.
    m.beam((0, 0, 2.92), (0.5, 0, 2.92), 0.035, "iron")
    m.box((0.38, 0.02, 0.84), (0.3, 0, 2.47), "jackfruit")
    m.box((0.38, 0.03, 0.08), (0.3, 0, 2.06), "jackfruit_dark")
    for y in (-0.016, 0.016):
        m.box((0.13, 0.004, 0.13), (0.3, y, 2.52), "leaf_dark", rot=lib.roty(45))
        m.box((0.02, 0.004, 0.24), (0.3, y, 2.44), "leaf_dark")
    # Lantern: tray, corner posts, glowing glass, pyramid roof and finial.
    m.box((0.3, 0.3, 0.05), (0, 0, 3.47), "iron", bevel=0.01)
    for x in (-0.12, 0.12):
        for y in (-0.12, 0.12):
            m.box((0.035, 0.035, 0.42), (x, y, 3.7), "iron")
    glow.box((0.22, 0.22, 0.38), (0, 0, 3.7), "lamp_glow")
    m.box((0.32, 0.32, 0.04), (0, 0, 3.93), "iron")
    m.cylinder(0.24, 0.18, (0, 0, 4.04), "iron", sides=4, radius_top=0.0, rot=rotz(45))
    m.sphere(0.04, (0, 0, 4.15), "jackfruit_dark", subdivisions=1)
    finish("lamp_post", {"body": m, "light": glow})


# ---- Café ----

def umbrella_yellow():
    """A yellow café umbrella: an eight-panel canopy with a scalloped
    valance, a white pole and a weighted base."""
    m = Mesh()
    m.cylinder(0.3, 0.08, (0, 0, 0.04), "charcoal", sides=8)
    m.cylinder(0.035, 2.36, (0, 0, 1.24), "white", sides=6)
    r, z0, z1, n = 1.25, 2.05, 2.44, 8
    rim = [(r * math.cos(2 * math.pi * (k + 0.5) / n), r * math.sin(2 * math.pi * (k + 0.5) / n), z0)
           for k in range(n)]
    verts = rim + [(0, 0, z1)]
    faces = [(k, (k + 1) % n, n) for k in range(n)]
    add(m, verts, faces, "jackfruit")
    verts, faces = [], []
    for k in range(n):
        a, b = Vector(rim[k]), Vector(rim[(k + 1) % n])
        mid = (a + b) / 2
        verts += [a, b, b - Vector((0, 0, 0.16)), mid - Vector((0, 0, 0.27)), a - Vector((0, 0, 0.16))]
        faces.append(tuple(range(5 * k, 5 * k + 5)))
    add(m, verts, faces, "jackfruit_dark")
    for k in range(n):
        a = Vector(rim[k])
        m.beam((0, 0, 1.75), a * 0.55 + Vector((0, 0, z0 * 0.45 + 0.02)), 0.02, "white")
    m.sphere(0.05, (0, 0, 2.47), "white", subdivisions=1)
    finish("umbrella_yellow", {"body": m})


def cafe_table(f):
    """A round bistro table with a wooden top on an iron pedestal."""
    f.cylinder(0.4, 0.04, (0, 0, 0.73), "wood_light", sides=12)
    f.cylinder(0.36, 0.02, (0, 0, 0.7), "wood", sides=12)
    f.cylinder(0.04, 0.68, (0, 0, 0.35), "iron", sides=6)
    f.box((0.6, 0.06, 0.03), (0, 0, 0.015), "iron")
    f.box((0.06, 0.6, 0.03), (0, 0, 0.015), "iron")


def cafe_chair(f):
    """A bistro chair seating one at the local origin, facing +Y."""
    f.box((0.44, 0.42, 0.05), (0, 0, 0.45), "wood_light", bevel=0.012)
    for x in (-0.18, 0.18):
        f.beam((x, 0.17, 0.43), (x * 1.1, 0.2, 0.0), 0.03, "iron")
        f.beam((x, -0.17, 0.43), (x * 1.1, -0.21, 0.0), 0.03, "iron")
        f.beam((x, -0.19, 0.45), (x, -0.23, 0.9), 0.03, "iron")
    for z in (0.66, 0.84):
        f.box((0.42, 0.03, 0.08), (0, -0.21 - (z - 0.45) * 0.09, z), "wood_light", bevel=0.008)


def cafe_table_prop():
    m = Mesh()
    cafe_table(Frame(m))
    finish("cafe_table", {"body": m})


def cafe_table_set():
    """A table with two chairs facing it across the X axis, laid out like the
    café terrace's seats (70 cm either side)."""
    m = Mesh()
    cafe_table(Frame(m))
    cafe_chair(Frame(m, -90, (-0.7, 0, 0)))
    cafe_chair(Frame(m, 90, (0.7, 0, 0)))
    finish("cafe_table_set", {"body": m})


def seat_cafe_table():
    m = Mesh()
    cafe_chair(Frame(m))
    finish("seat_cafe-table_v2", {"body": m})


# ---- Workshop ----

def truss(f, x0, x1, y, z, h, bays=4, t=0.02, mat="wood_light"):
    """One side of a timber Warren truss with verticals, from x0 to x1."""
    dx = (x1 - x0) / bays
    f.beam((x0, y, z), (x1, y, z), t, mat)
    f.beam((x0 + dx / 2, y, z + h), (x1 - dx / 2, y, z + h), t, mat)
    for i in range(bays):
        bx, tx = x0 + i * dx, x0 + (i + 0.5) * dx
        f.beam((bx, y, z), (tx, y, z + h), t * 0.8, mat)
        f.beam((tx, y, z + h), (bx + dx, y, z), t * 0.8, mat)
        f.beam((tx, y, z), (tx, y, z + h), t * 0.7, mat)


def workbench():
    """A 3.2 m timber workbench: a thick top on trestles, a shelf of crates,
    a green cutting mat with a timber bridge model and white blocks, a tool
    pot, mug, mallet and vice, and a screen at the back (`screen`)."""
    m, screen = Mesh(), Mesh()
    f = Frame(m)
    f.box((3.2, 1.0, 0.08), (0, 0, 0.88), "wood_light", bevel=0.015)
    for x in (-1.42, 1.42):
        for y in (-0.38, 0.38):
            f.box((0.09, 0.09, 0.84), (x, y, 0.42), "wood", bevel=0.01)
        f.box((0.09, 0.84, 0.08), (x, 0, 0.18), "wood")
    f.box((2.9, 0.08, 0.1), (0, -0.38, 0.75), "wood")
    f.box((2.9, 0.8, 0.03), (0, 0, 0.24), "wood")
    f.box((0.5, 0.4, 0.3), (-0.9, 0.05, 0.4), "wood_light", bevel=0.01)
    f.box((0.45, 0.35, 0.26), (-0.35, -0.05, 0.38), "wood_light", bevel=0.01)
    f.box((0.5, 0.26, 0.2), (0.8, 0.1, 0.35), "tram_red", bevel=0.01)
    top = 0.92
    # Cutting mat, the bridge model and blocks.
    f.box((1.3, 0.62, 0.012), (-0.25, 0.05, top + 0.006), "teal_dark")
    z = top + 0.02
    for y in (-0.05, 0.13):
        truss(f, -0.8, 0.3, y, z + 0.02, 0.28)
    f.box((1.1, 0.2, 0.02), (-0.25, 0.04, z + 0.02), "wood")
    for x in (-0.53, -0.25, 0.03):
        f.beam((x, -0.05, z + 0.3), (x, 0.13, z + 0.3), 0.018, "wood_light")
    for k, (x, y, s) in enumerate(((0.45, -0.1, 0.11), (0.58, 0.04, 0.09), (0.47, 0.14, 0.08),
                                   (0.52, 0.02, 0.07))):
        f.box((s, s, s), (x, y, z + s / 2 + (0.09 if k == 3 else 0)), "white", bevel=0.006)
    # Tool pot with pencils, a mug, a mallet and a vice.
    f.cylinder(0.05, 0.13, (0.95, -0.2, top + 0.065), "charcoal", sides=6)
    for k, mat in enumerate(("jackfruit", "coral", "teal")):
        a = 2 * math.pi * k / 3
        f.beam((0.95 + 0.02 * math.cos(a), -0.2 + 0.02 * math.sin(a), top + 0.05),
               (0.95 + 0.05 * math.cos(a), -0.2 + 0.05 * math.sin(a), top + 0.24), 0.012, mat)
    f.cylinder(0.045, 0.1, (1.1, 0.15, top + 0.05), "teal", sides=8)
    f.beam((0.7, 0.3, top + 0.02), (1.0, 0.36, top + 0.02), 0.03, "wood")
    f.box((0.06, 0.13, 0.06), (0.69, 0.3, top + 0.03), "iron", rot=rotz(12))
    f.box((0.2, 0.14, 0.12), (1.45, 0.38, top + 0.06), "iron", bevel=0.01)
    f.box((0.2, 0.03, 0.08), (1.45, 0.47, top + 0.08), "steel")
    # A screen on a stand at the back, facing the worker (+Y).
    f.box((0.2, 0.14, 0.02), (1.1, -0.32, top + 0.01), "charcoal")
    f.box((0.05, 0.04, 0.12), (1.1, -0.35, top + 0.07), "charcoal")
    f.box((0.62, 0.04, 0.38), (1.1, -0.36, top + 0.27), "charcoal", bevel=0.01)
    screen.box((0.56, 0.01, 0.32), (1.1, -0.335, top + 0.27), "screen")
    finish("workbench", {"body": m, "screen": screen})


# ---- Library ----

BOOKS = ["book_a", "book_b", "book_c", "teal", "coral", "leaf_dark", "cream", "terracotta", "book_b", "book_a"]


def book(m, x0, x1, z0, h, y0, y1, mat):
    """A book standing on a shelf: its spine (front), top and sides; the back
    and bottom are hidden against the shelf."""
    v = [(x0, y1, z0), (x1, y1, z0), (x1, y1, z0 + h), (x0, y1, z0 + h),
         (x0, y0, z0), (x1, y0, z0), (x1, y0, z0 + h), (x0, y0, z0 + h)]
    add(m, v, [(0, 1, 2, 3), (3, 2, 6, 7), (4, 0, 3, 7), (1, 5, 6, 2)], mat)


def bookshelf_v2():
    """A 2 m library bookshelf in warm timber: five shelves of books in the
    sheet's colours (a few leaning or stacked) and a potted plant on top."""
    m = Mesh()
    w, d, h = 2.0, 0.45, 2.2
    m.box((0.06, d, h), (-w / 2 + 0.03, 0, h / 2), "wood_light", bevel=0.01)
    m.box((0.06, d, h), (w / 2 - 0.03, 0, h / 2), "wood_light", bevel=0.01)
    m.box((0.05, d - 0.04, h - 0.1), (0, -0.01, h / 2), "wood_light")
    m.box((w, d + 0.04, 0.06), (0, 0.01, h - 0.03), "wood_light", bevel=0.01)
    m.box((w - 0.04, d, 0.1), (0, 0, 0.05), "wood")
    m.box((w - 0.08, 0.02, h - 0.1), (0, -d / 2 + 0.01, h / 2), "wood")
    levels = [0.1, 0.52, 0.94, 1.36, 1.78]
    for z in levels[1:]:
        m.box((w - 0.08, d - 0.03, 0.03), (0, 0.0, z - 0.015), "wood_light")
    k = 0
    for li, z in enumerate(levels):
        for half in (-1, 1):
            x0 = -0.95 if half < 0 else 0.04
            x1 = -0.04 if half < 0 else 0.95
            x = x0 + 0.02
            n = 0
            while True:
                k += 1
                n += 1
                bw = 0.05 + 0.012 * ((k * 7) % 5)
                bh = 0.26 + 0.02 * ((k * 3) % 5)
                if li == 4 and half > 0 and n == 3:
                    # A small stack lying flat.
                    for s in range(3):
                        m.box((0.22, 0.26, 0.05), (x + 0.12, 0.04, z + 0.025 + 0.05 * s), BOOKS[(k + s) % 10])
                    x += 0.28
                    continue
                if x + bw > x1 - (0.12 if (li + (half > 0)) % 2 else 0.0):
                    break
                book(m, x, x + bw, z, bh, -0.18, 0.15 - 0.02 * (k % 2), BOOKS[k % len(BOOKS)])
                x += bw + 0.004
            if (li + (half > 0)) % 2 and x < x1 - 0.08:
                # One book leaning into the gap.
                m.box((0.05, 0.24, 0.3), (x + 0.1, -0.02, z + 0.14), BOOKS[(k + 3) % 10], rot=lib.roty(22))
    m.cylinder(0.12, 0.18, (0.6, 0, h + 0.09), "terracotta", sides=8, radius_top=0.15)
    leafy_plant(m, (0.6, 0, h + 0.17), 0.4, leaves=7, seed=71)
    finish("bookshelf_v2", {"body": m})


def reading_chair(f):
    """A timber-framed reading armchair with deep green cushions and a
    yellow pillow, seating one at the local origin facing +Y."""
    for x in (-0.37, 0.37):
        f.box((0.09, 0.72, 0.5), (x, -0.02, 0.33), "wood_light", bevel=0.015)
        f.box((0.12, 0.76, 0.04), (x, -0.02, 0.6), "wood", bevel=0.01)
        for y in (-0.3, 0.26):
            f.box((0.07, 0.07, 0.1), (x, y, 0.05), "wood")
    # The seat stops 0.24 m ahead of the sitter, within the square round
    # them: the arms either side are the footprint.
    f.box((0.66, 0.58, 0.12), (0, -0.06, 0.2), "wood")
    f.box((0.66, 0.54, 0.15), (0, -0.03, 0.34), "leaf_dark", bevel=0.04)
    back = rotx(-14)
    f.box((0.66, 0.1, 0.62), (0, -0.33, 0.62), "wood_light", bevel=0.015, rot=back)
    f.box((0.6, 0.14, 0.5), (0, -0.25, 0.64), "leaf_dark", bevel=0.045, rot=back)
    f.box((0.28, 0.1, 0.24), (0.17, -0.14, 0.55), "jackfruit", bevel=0.04, rot=back @ rotz(-10))


def reading_chair_v2():
    m = Mesh()
    reading_chair(Frame(m, at=(0, 0.04, 0)))
    finish("reading_chair_v2", {"body": m})


def seat_reading_chair():
    m = Mesh()
    reading_chair(Frame(m))
    finish("seat_reading-chair_v2", {"body": m})


# ---- Desk ----

def desk_set(f, screen):
    """A desk seating one at the local origin, facing +Y: a teal task chair,
    a timber desk with a drawer pedestal, a terminal (its display is
    `screen`, facing the sitter), keyboard, mug and a small plant."""
    # Chair.
    f.box((0.46, 0.44, 0.08), (0, 0, 0.46), "teal", bevel=0.025)
    f.box((0.44, 0.07, 0.42), (0, -0.25, 0.76), "teal", bevel=0.025, rot=rotx(-8))
    f.beam((0, -0.22, 0.47), (0, -0.27, 0.6), 0.04, "charcoal")
    f.cylinder(0.035, 0.36, (0, 0, 0.24), "charcoal", sides=6)
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        f.beam((0, 0, 0.05), (0.26 * math.cos(a), 0.26 * math.sin(a), 0.03), 0.04, "charcoal")
    # Desk, 1.3 m: the desk kind's footprint, so it is filled across
    # without widening the chair.
    f.box((1.3, 0.6, 0.05), (0, 0.5, 0.735), "wood_light", bevel=0.012)
    for x in (-0.6, 0.6):
        f.box((0.05, 0.54, 0.05), (x, 0.5, 0.025), "wood")
        f.box((0.05, 0.05, 0.7), (x, 0.5, 0.36), "wood")
    f.box((1.2, 0.03, 0.2), (0, 0.76, 0.6), "wood")
    f.box((0.32, 0.5, 0.5), (0.34, 0.5, 0.32), "limewash_shade", bevel=0.01)
    for z in (0.44, 0.24):
        f.box((0.26, 0.01, 0.12), (0.34, 0.25, z), "limewash")
        f.box((0.08, 0.02, 0.015), (0.34, 0.24, z + 0.02), "charcoal")
    # Terminal.
    top = 0.76
    f.box((0.24, 0.16, 0.02), (0, 0.66, top + 0.01), "charcoal")
    f.box((0.05, 0.04, 0.16), (0, 0.68, top + 0.09), "charcoal")
    f.box((0.58, 0.04, 0.36), (0, 0.67, top + 0.26), "charcoal", bevel=0.01)
    screen.box((0.52, 0.01, 0.3), f.p((0, 0.645, top + 0.26)), "screen", rot=f.r)
    f.box((0.42, 0.14, 0.02), (0, 0.38, top + 0.01), "white", bevel=0.005)
    f.box((0.06, 0.1, 0.02), (0.3, 0.38, top + 0.01), "white", bevel=0.005)
    f.cylinder(0.04, 0.09, (-0.4, 0.4, top + 0.045), "coral", sides=8)
    f.cylinder(0.06, 0.1, (-0.4, 0.66, top + 0.05), "terracotta", sides=8, radius_top=0.07)
    leafy_plant(f.m, f.p((-0.4, 0.66, top + 0.1)), 0.32, leaves=6, seed=81)


def desk_v2():
    m, screen = Mesh(), Mesh()
    desk_set(Frame(m, at=(0, -0.25, 0)), screen)
    finish("desk_v2", {"body": m, "screen": screen})


def seat_desk():
    m, screen = Mesh(), Mesh()
    desk_set(Frame(m), screen)
    finish("seat_desk_v2", {"body": m, "screen": screen})


# ---- Ground ----

# The slabs of each 1 m tile as (x0, y0, x1, y1, palette colour), on a 0.5 m
# grid so grout lines run straight across neighbouring tiles.
TILES = {
    "a": [(0, 0, 1, 0.5, "paving_light"), (0, 0.5, 1, 1, "paving")],
    "b": [(0, 0, 0.5, 1, "paving"), (0.5, 0, 1, 0.5, "sandstone"), (0.5, 0.5, 1, 1, "paving_light")],
    "c": [(0, 0, 0.5, 0.5, "paving_light"), (0.5, 0, 1, 0.5, "paving"), (0, 0.5, 0.5, 1, "paving"),
          (0.5, 0.5, 1, 1, "paving_light")],
}


def slab(m, x0, y0, x1, y1, mat, top=0.06, base=0.045, gap=0.012, chamfer=0.014, tilt=0.0):
    """A sandstone slab filling a cell (less half a grout gap each side), with
    chamfered edges; `tilt` lifts one corner a few millimetres so the facets
    catch the light unevenly."""
    x0, y0, x1, y1 = x0 + gap / 2, y0 + gap / 2, x1 - gap / 2, y1 - gap / 2
    c = chamfer
    v = [(x0, y0, base), (x1, y0, base), (x1, y1, base), (x0, y1, base),
         (x0 + c, y0 + c, top), (x1 - c, y0 + c, top + tilt), (x1 - c, y1 - c, top), (x0 + c, y1 - c, top - tilt)]
    add(m, v, [(4, 5, 6), (4, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], mat)


def paving_tile(key):
    def build():
        m = Mesh()
        m.box((1.0, 1.0, 0.045), (0, 0, 0.0225), "paving_dark")
        for k, (x0, y0, x1, y1, mat) in enumerate(TILES[key]):
            slab(m, x0 - 0.5, y0 - 0.5, x1 - 0.5, y1 - 0.5, mat, tilt=0.004 * (1 if k % 2 else -1))
        m.build(f"paving_tile_{key}")
    return build


def path():
    """A 1 m garden path tile running along Y: sand gravel between low stone
    edgings, with two flagstones; tiles end to end along Y."""
    m = Mesh()
    m.box((1.0, 1.0, 0.035), (0, 0, 0.0175), "sand")
    for x in (-0.46, 0.46):
        m.box((0.08, 1.0, 0.06), (x, 0, 0.03), "kerb", bevel=0.012)
    for (cx, cy, rx, ry, rot, mat) in ((-0.12, -0.24, 0.24, 0.18, 12, "sandstone"),
                                        (0.14, 0.26, 0.22, 0.17, -8, "paving_light")):
        pts = []
        for k in range(6):
            a = 2 * math.pi * k / 6 + math.radians(rot)
            pts.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
        v = [(x, y, 0.03) for x, y in pts] + [(x, y, 0.05) for x, y in pts]
        faces = [tuple(range(6, 12))] + [(k, (k + 1) % 6, 6 + (k + 1) % 6, 6 + k) for k in range(6)]
        add(m, v, faces, mat)
    m.build("path")


# ---- Railings (wherever walkable ground ends) ----

RAIL_H = 1.0


def _railing_post(m, x):
    """A square teal post on a stone footing, capped, with a ball finial."""
    m.box((0.14, 0.14, 0.08), (x, 0, 0.04), "stone", bevel=0.01)
    m.box((0.085, 0.085, RAIL_H - 0.04), (x, 0, 0.08 + (RAIL_H - 0.04) / 2), "teal_dark")
    m.box((0.12, 0.12, 0.035), (x, 0, RAIL_H + 0.055), "teal_dark", bevel=0.008)
    m.sphere(0.034, (x, 0, RAIL_H + 0.1), "teal_dark", subdivisions=1)


def railing():
    """Two metres of quay railing, running along x from -1 to 1: a stone
    kerb, a post at the -x end (the next module's post, or a
    `railing_post`, closes the +x end), iron balusters between an iron
    bottom rail and a painted teal handrail."""
    m = Mesh()
    m.box((2.0, 0.1, 0.07), (0, 0, 0.035), "stone", bevel=0.008)
    _railing_post(m, -0.93)
    m.box((2.0, 0.07, 0.05), (0, 0, RAIL_H), "teal", bevel=0.012)
    m.box((2.0, 0.04, 0.035), (0, 0, 0.17), "iron")
    for k in range(9):
        x = -0.72 + k * 0.2
        m.box((0.022, 0.022, RAIL_H - 0.2), (x, 0, 0.17 + (RAIL_H - 0.2) / 2), "iron")
    finish("railing", {"body": m})


def railing_post():
    """The post that closes a run of railing, or turns its corner."""
    m = Mesh()
    _railing_post(m, 0.0)
    finish("railing_post", {"body": m})


# ---- Things to use: displays and perches ----

# The kit's colour for each role in the shared things to use: tropical
# timber and terracotta, sandstone and brick, a verdigris plaque, and
# dark faces the surfaces' light text reads on.
USE_LOOK = {
    "post": "wood_dark", "post_foot": "iron", "frame": "wood", "board": "teal_dark",
    "roof": "terracotta", "roof_ridge": "terracotta_dark",
    "stone": "sandstone", "stone_dark": "stone", "plaque": "copper_dark", "plaque_frame": "copper",
    "base": "stone", "housing": "teal", "canopy": "jackfruit", "bezel": "charcoal", "screen": "visor",
    "step": "sandstone", "nosing": "stone_dark", "wall": "brick", "coping": "sandstone",
    "basin": "sandstone", "rim": "stone", "water": "water",
    "seat_block": "stone", "seat": "wood_light",
}


def used(name, build, display=False):
    """Asset `name` from the shared builder `build` in the kit's look;
    a display gets its `display` empty."""
    def run():
        finish(name, build(USE_LOOK))
        if display:
            usables.display_node(name)
    run.__doc__ = build.__doc__
    return run


# The workstation in the kit's look: a teal task chair at a timber desk, a
# clean charcoal monitor (the kit's flat frame), white keys.
WORK_LOOK = {
    **USE_LOOK, "chair": "teal", "chair_frame": "charcoal", "desk": "wood_light", "desk_leg": "wood",
    "drawer": "limewash_shade", "keys": "white", "casing": "charcoal", "screen": "visor", "trim": "charcoal",
    "frame_style": "flat",
}


def workstation():
    """The shared workstation (usables.workstation) in the kit's look, with
    a mug and a potted plant on the desk's left."""
    parts = usables.workstation(WORK_LOOK)
    m = parts["body"]
    top = usables.DESK_TOP
    m.cylinder(0.04, 0.09, (-0.36, 0.42, top + 0.045), "coral", sides=8)
    m.cylinder(0.06, 0.1, (-0.46, 0.72, top + 0.05), "terracotta", sides=8, radius_top=0.07)
    leafy_plant(m, (-0.46, 0.72, top + 0.1), 0.3, leaves=6, seed=83)
    finish("workstation", parts)
    usables.display_node("workstation")


ASSETS = {
    "workstation": workstation,
    "noticeboard": used("noticeboard", usables.noticeboard, display=True),
    "plaque": used("plaque", usables.plaque, display=True),
    "kiosk": used("kiosk", usables.kiosk, display=True),
    "steps": used("steps", usables.steps),
    "low_wall": used("low_wall", usables.low_wall),
    "fountain": used("fountain", usables.fountain),
    "perch_seat": used("perch_seat", usables.perch_seat),
    "railing": railing,
    "railing_post": railing_post,
    "bench_park": bench_park,
    "seat_bench_v2": seat_bench,
    "bollard": bollard,
    "lamp_post": lamp_post,
    "umbrella_yellow": umbrella_yellow,
    "cafe_table": cafe_table_prop,
    "cafe_table_set": cafe_table_set,
    "seat_cafe-table_v2": seat_cafe_table,
    "workbench": workbench,
    "bookshelf_v2": bookshelf_v2,
    "reading_chair_v2": reading_chair_v2,
    "seat_reading-chair_v2": seat_reading_chair,
    "desk_v2": desk_v2,
    "seat_desk_v2": seat_desk,
    "paving_tile_a": paving_tile("a"),
    "paving_tile_b": paving_tile("b"),
    "paving_tile_c": paving_tile("c"),
    "path": path,
}
