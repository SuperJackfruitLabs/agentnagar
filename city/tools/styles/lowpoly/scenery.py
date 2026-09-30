"""The city around the district for the low-poly tropical kit (v2): blocks,
the bridge, ground tiles and the tram.

Conventions (Blender, Z-up): origin at the centre of the footprint on the
ground; fronts face +Y (Godot's forward). Blocks are sized for the lots the
pack cuts from a manifest block (about 6 m houses and 5 m shops) and are
scaled a little to fit; towers fill a 13 m lot.

    house_a, house_b    two-storey limewash houses, 6 m x 8 m
    shop_a              a shop with an awning and a flat roof, 5 m x 8 m
    tower_a             a stepped limewash tower with rooftop gardens
    bridge_span         one 8 m stone arch with its balustrades, running x
    bridge_pier         a pier with a cutwater and a lamp pillar
    street_tile         2 m x 2 m of asphalt
    street_kerb         2 m of kerb, its road side on -Y
    tram_track          2 m of track in paving, running x
    water_tile          4 m x 4 m of gently faceted water; z = 0 is the surface
    tram                three cream-and-red cars running x, 20.5 m long
    cloud_a, cloud_b    faceted cumulus clusters for the sky, base at z = 0
"""
import math
import random

import sys
from pathlib import Path

import lib
from lib import Mesh, arched_hole, rect_hole

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import tram_layout  # noqa: E402
import tram_parts  # noqa: E402


def _shutters(m, x, z, w, h, y, colour):
    for side in (-1, 1):
        m.box((w * 0.5, 0.05, h), (x + side * (w * 0.5 + w * 0.25 + 0.03), y + 0.03, z), colour)


def _window(m, x, z, w, h, y, face="y", shutters=None):
    """A window on a wall face at y (facing +Y): glass, frame and sill."""
    m.box((w, 0.05, h), (x, y + 0.01, z), "glass")
    m.box((w + 0.12, 0.08, 0.08), (x, y + 0.03, z + h / 2 + 0.04), "limewash_shade")
    m.box((w + 0.2, 0.18, 0.07), (x, y + 0.07, z - h / 2 - 0.04), "sandstone")
    m.box((0.05, 0.06, h), (x, y + 0.03, z), "white")
    if shutters:
        _shutters(m, x, z, w, h, y, shutters)


def _house_windows(m, w, d, storeys, shutters):
    """Windows on all four faces, two per storey on the short sides and
    three on the long ones, rotated onto each face."""
    for face, (length, off, rot) in {
            "front": (w, d / 2, 0), "back": (w, d / 2, 180), "east": (d, w / 2, -90), "west": (d, w / 2, 90)}.items():
        n = 2 if length < 7 else 3
        tmp = Mesh()
        for s in range(storeys):
            z = 1.55 + s * 2.9
            for k in range(n):
                x = -length / 2 + length * (k + 0.5) / n
                if face == "front" and s == 0 and k == n // 2:
                    continue
                _window(tmp, x, z, 0.8, 1.2, 0.0, shutters=shutters)
        _merge_rotated(m, tmp, rot, off)


def _merge_rotated(m, tmp, degrees, offset):
    """Copies tmp's geometry into m, turned about Z and pushed `offset`
    along the turned +Y (onto a face)."""
    rot = lib.rotz(degrees)
    push = rot @ lib.Vector((0, offset, 0))
    for f in tmp.bm.faces:
        verts = [m.bm.verts.new(rot @ v.co + push) for v in f.verts]
        try:
            nf = m.bm.faces.new(verts)
            nf.material_index = m.slot(tmp.mats[f.material_index])
        except ValueError:
            pass
    tmp.bm.free()


def house_a():
    r = lib.root("house_a")
    m = Mesh()
    w, d, h = 5.6, 7.4, 6.0
    m.box((w + 0.2, d + 0.2, 0.5), (0, 0, 0.25), "stone", bevel=0.03)
    m.box((w, d, h - 0.5), (0, 0, 0.5 + (h - 0.5) / 2), "limewash", bevel=0.04)
    m.box((w + 0.12, d + 0.12, 0.14), (0, 0, 3.25), "limewash_shade")
    _house_windows(m, w, d, 2, "teal")
    # Front door with a step and a little canopy.
    m.box((1.0, 0.06, 2.1), (0, d / 2 + 0.01, 1.55), "wood_dark", bevel=0.01)
    m.box((1.3, 0.5, 0.14), (0, d / 2 + 0.25, 0.43), "stone")
    m.box((1.5, 0.7, 0.1), (0, d / 2 + 0.35, 2.8), "terracotta_dark")
    # A balcony on the upper front, with a railing and a plant.
    m.box((2.6, 1.0, 0.14), (0, d / 2 + 0.5, 3.35), "sandstone", bevel=0.02)
    m.box((2.6, 0.06, 0.8), (0, d / 2 + 0.97, 3.82), "iron")
    for x in (-1.27, 1.27):
        m.box((0.06, 1.0, 0.8), (x, d / 2 + 0.5, 3.82), "iron")
    m.box((0.36, 0.36, 0.34), (0.9, d / 2 + 0.6, 3.59), "terracotta")
    m.sphere(0.34, (0.9, d / 2 + 0.6, 4.0), "leaf", jitter=0.12, seed=4)
    # A terracotta hip roof with a ridge cap.
    _hip_roof(m, w, d, h, 2.1, 0.45, "terracotta")
    m.build("house", r)


def house_b():
    r = lib.root("house_b")
    m = Mesh()
    w, d, h = 5.6, 7.4, 5.8
    m.box((w + 0.2, d + 0.2, 0.45), (0, 0, 0.225), "stone", bevel=0.03)
    m.box((w, d, h - 0.45), (0, 0, 0.45 + (h - 0.45) / 2), "sandstone", bevel=0.04)
    _house_windows(m, w, d, 2, "wood")
    # An arched door, a timber balcony the width of the front, flower boxes.
    m.slab([(-0.7, 0.0), (0.7, 0.0), (0.7, 2.8), (-0.7, 2.8)], [arched_hole(-0.5, 0.5, 0.0, 1.8, 0.5)], 0.1,
           (0, d / 2 + 0.05, 0.45), "limewash")
    m.box((1.0, 0.04, 2.3), (0, d / 2 - 0.01, 1.6), "teal_dark")
    m.box((w + 0.4, 1.1, 0.12), (0, d / 2 + 0.55, 3.3), "wood", bevel=0.02)
    for x in (-w / 2 - 0.1, w / 2 + 0.1):
        m.box((0.12, 0.12, 3.3), (x, d / 2 + 1.0, 1.65), "wood_dark")
    m.box((w + 0.4, 0.06, 0.08), (0, d / 2 + 1.07, 4.2), "wood_dark")
    for k in range(8):
        m.box((0.06, 0.06, 0.8), (-w / 2 + 0.2 + k * (w / 7.4), d / 2 + 1.07, 3.8), "wood_dark")
    for x in (-1.6, 1.6):
        m.box((0.9, 0.25, 0.22), (x, d / 2 + 0.95, 4.35), "wood")
        for j in range(3):
            m.sphere(0.13, (x - 0.3 + j * 0.3, d / 2 + 0.95, 4.55), ("pink", "jackfruit", "white")[j], subdivisions=1)
    # A gable roof with barge boards.
    over = 0.45
    rise = 2.2
    m.prism([(-w / 2 - over, h - 0.08), (0, h + rise), (w / 2 + over, h - 0.08), (w / 2 + over, h + 0.08),
             (0, h + rise + 0.16), (-w / 2 - over, h + 0.08)], d + 2 * over, (0, 0, 0), "terracotta_light", axis="y")
    m.prism([(-w / 2, h), (w / 2, h), (0, h + rise - 0.1)], d - 0.02, (0, 0, 0), "sandstone", axis="y")
    for y in (-d / 2 - over, d / 2 + over):
        m.beam((-w / 2 - over, y, h), (0, y, h + rise + 0.1), 0.18, "wood_dark", depth=0.1)
        m.beam((w / 2 + over, y, h), (0, y, h + rise + 0.1), 0.18, "wood_dark", depth=0.1)
    m.build("house", r)


def _hip_roof(m, w, d, h, rise, over, mat):
    hw, hd = w / 2 + over, d / 2 + over
    inset = min(hw, hd)
    tmp = lib.bmesh.new()
    c = [tmp.verts.new(p) for p in ((-hw, -hd, h), (hw, -hd, h), (hw, hd, h), (-hw, hd, h))]
    if hd >= hw:
        a = tmp.verts.new((0, -hd + inset, h + rise))
        b = tmp.verts.new((0, hd - inset, h + rise))
        tmp.faces.new([c[1], c[2], b, a])
        tmp.faces.new([c[3], c[0], a, b])
        tmp.faces.new([c[0], c[1], a])
        tmp.faces.new([c[2], c[3], b])
    else:
        a = tmp.verts.new((-hw + inset, 0, h + rise))
        b = tmp.verts.new((hw - inset, 0, h + rise))
        tmp.faces.new([c[0], c[1], b, a])
        tmp.faces.new([c[2], c[3], a, b])
        tmp.faces.new([c[1], c[2], b])
        tmp.faces.new([c[3], c[0], a])
    tmp.faces.new(list(reversed(c)))
    lib.bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    m._merge(tmp, mat, None, (0, 0, 0))
    ra = (0, -hd + inset, h + rise) if hd >= hw else (-hw + inset, 0, h + rise)
    rb = (0, hd - inset, h + rise) if hd >= hw else (hw - inset, 0, h + rise)
    m.beam(ra, rb, 0.16, "terracotta_dark")
    for corner in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)):
        end = ra if (corner[1] < 0 if hd >= hw else corner[0] < 0) else rb
        m.beam((corner[0], corner[1], h + 0.03), end, 0.12, "terracotta_dark")


def shop_a():
    r = lib.root("shop_a")
    m = Mesh()
    w, d, h = 4.6, 7.4, 7.0
    m.box((w, d, h), (0, 0, h / 2), "cream", bevel=0.04)
    m.box((w + 0.16, d + 0.16, 0.5), (0, 0, h + 0.1), "sandstone", bevel=0.03)
    # The shopfront: a glazed ground floor behind slim piers, a sign band
    # and a striped awning.
    m.box((w - 0.6, 0.06, 2.3), (0, d / 2 + 0.01, 1.45), "glass")
    for x in (-w / 2 + 0.15, 0, w / 2 - 0.15):
        m.box((0.3, 0.12, 2.6), (x, d / 2 + 0.03, 1.3), "wood_dark")
    m.box((w - 0.4, 0.08, 0.1), (0, d / 2 + 0.05, 0.3), "wood_dark")
    m.box((w + 0.1, 0.14, 0.55), (0, d / 2 + 0.07, 3.0), "teal", bevel=0.02)
    m.box((w * 0.6, 0.04, 0.26), (0, d / 2 + 0.15, 3.0), "cream")
    stripes = 8
    for k in range(stripes):
        x = -w / 2 + w * (k + 0.5) / stripes
        m.box((w / stripes, 1.4, 0.05), (x, d / 2 + 0.7, 2.5), "jackfruit" if k % 2 == 0 else "cream",
              rot=lib.rotx(-18))
    m.box((w, 0.05, 0.22), (0, d / 2 + 1.36, 2.18), "jackfruit_dark")
    tmp = Mesh()
    for k in range(3):
        _window(tmp, -w / 2 + w * (k + 0.5) / 3, 4.9, 0.8, 1.4, 0.0, shutters=None)
    _merge_rotated(m, tmp, 0, d / 2)
    for face, length, off, rot in (("east", d, w / 2, -90), ("west", d, w / 2, 90), ("back", w, d / 2, 180)):
        tmp = Mesh()
        for s in range(2):
            for k in range(3 if length > 6 else 2):
                n = 3 if length > 6 else 2
                _window(tmp, -length / 2 + length * (k + 0.5) / n, 1.6 + s * 3.2, 0.8, 1.3, 0.0)
        _merge_rotated(m, tmp, rot, off)
    m.box((0.5, 0.5, 0.45), (1.2, -1.5, h + 0.55), "terracotta")
    m.sphere(0.45, (1.2, -1.5, h + 1.05), "leaf_light", jitter=0.15, seed=9)
    m.build("shop", r)


def tower_a():
    r = lib.root("tower_a")
    m = Mesh()
    tiers = [(11.0, 12.0), (9.0, 6.0), (6.4, 3.3)]
    z = 0.0
    rng = random.Random(11)
    for k, (size, height) in enumerate(tiers):
        m.box((size, size, height), (0, 0, z + height / 2), "limewash" if k != 1 else "limewash_shade", bevel=0.05)
        # Window bands and piers on every face.
        floors = int(height // 3.0)
        for f in range(floors):
            zf = z + 1.5 + f * 3.0
            for rot, off in ((0, size / 2), (90, size / 2), (180, size / 2), (270, size / 2)):
                tmp = Mesh()
                tmp.box((size - 0.8, 0.06, 1.5), (0, 0.02, zf), "glass")
                cols = int(size // 1.6)
                for c in range(cols + 1):
                    tmp.box((0.16, 0.12, 1.6), (-size / 2 + 0.4 + (size - 0.8) * c / cols, 0.05, zf), "sandstone")
                tmp.box((size, 0.2, 0.12), (0, 0.08, zf - 0.85), "sandstone")
                _merge_rotated(m, tmp, rot, off)
        z += height
        m.box((size + 0.3, size + 0.3, 0.35), (0, 0, z + 0.05), "sandstone", bevel=0.04)
        # A roof garden on each setback: shrubs along the parapet.
        if k < len(tiers) - 1:
            inner = tiers[k + 1][0]
            for j in range(10):
                a = rng.uniform(0, 2 * math.pi)
                rad = rng.uniform(inner / 2 + 0.6, size / 2 - 0.5)
                x, y = math.cos(a) * rad, math.sin(a) * rad
                if max(abs(x), abs(y)) < inner / 2 + 0.5:
                    continue
                m.sphere(rng.uniform(0.4, 0.7), (x, y, z + 0.5), rng.choice(["leaf", "leaf_light", "leaf_dark"]),
                         jitter=0.15, seed=j + 20 * k)
    # A crown: a small copper cupola and a flagpole.
    m.cylinder(1.4, 1.2, (0, 0, z + 0.8), "limewash", 8)
    m.dome(1.5, (0, 0, z + 1.4), "copper", segments=8, rings=3)
    m.cylinder(0.05, 1.6, (0, 0, z + 3.2), "iron", 5)
    m.sphere(0.12, (0, 0, z + 4.05), "jackfruit")
    m.build("tower", r)


def bridge_span():
    r = lib.root("bridge_span")
    m = Mesh()
    L, W = 8.0, 4.0
    deck = 1.2
    # The arch ring and spandrels, both faces, as one slab with a round hole.
    outer = [(-L / 2, -2.4), (L / 2, -2.4), (L / 2, deck), (-L / 2, deck)]
    hole = [(-L / 2 + 0.6, -2.4)] + lib.arch(-L / 2 + 0.6, L / 2 - 0.6, -1.4, 2.2, 10) + [(L / 2 - 0.6, -2.4)]
    m.slab(outer, [hole], W, (0, 0, 0), "stone", reveal_mat="stone_dark")
    for k in range(11):
        a0 = math.pi * k / 11
        a1 = math.pi * (k + 1) / 11
        rr = L / 2 - 0.6
        p0 = (-math.cos(a0) * (rr + 0.12), 0, -1.4 + math.sin(a0) * 2.2 * (rr + 0.12) / rr)
        p1 = (-math.cos(a1) * (rr + 0.12), 0, -1.4 + math.sin(a1) * 2.2 * (rr + 0.12) / rr)
        for y in (-W / 2 - 0.02, W / 2 + 0.02):
            m.beam((p0[0], y, p0[2]), (p1[0], y, p1[2]), 0.3, "sandstone", depth=0.06)
    # The deck: paving between kerbs, and balustrades.
    m.box((L, W - 1.0, 0.06), (0, 0, deck + 0.03), "paving")
    for y in (-W / 2 + 0.25, W / 2 - 0.25):
        m.box((L, 0.5, 0.2), (0, y, deck + 0.1), "sandstone")
        m.box((L, 0.3, 0.14), (0, y, deck + 1.05), "limewash", bevel=0.02)
        m.box((L, 0.34, 0.14), (0, y, deck + 0.27), "sandstone")
        for k in range(14):
            x = -L / 2 + 0.3 + k * (L - 0.6) / 13
            m.cylinder(0.08, 0.64, (x, y, deck + 0.66), "limewash", 6, radius_top=0.06)
    m.build("span", r)


def bridge_pier():
    r = lib.root("bridge_pier")
    m = Mesh()
    W = 4.0
    deck = 1.2
    m.box((1.4, W + 0.4, 5.6), (0, 0, deck - 2.8), "stone", bevel=0.04)
    # Cutwaters pointing up and down the river (±y), below the deck.
    for y in (-1, 1):
        tip = [(-0.7, 0.0), (0.7, 0.0), (0.0, y * 1.1)]
        m.prism(tip, 3.8, (0, y * (W / 2 + 0.2), -2.5), "stone_dark", axis="z")
        m.prism([(-0.75, 0.0), (0.75, 0.0), (0.0, y * 1.2)], 0.2, (0, y * (W / 2 + 0.2), -0.5), "sandstone", axis="z")
    # Pillars on both sides of the deck, each with a lamp.
    for y in (-W / 2 + 0.25, W / 2 - 0.25):
        m.box((0.6, 0.6, 1.4), (0, y, deck + 0.7), "sandstone", bevel=0.03)
        m.box((0.74, 0.74, 0.16), (0, y, deck + 1.46), "limewash", bevel=0.02)
        m.cylinder(0.05, 1.3, (0, y, deck + 2.2), "iron", 6)
        m.box((0.28, 0.28, 0.36), (0, y, deck + 3.0), "lamp_glow")
        m.cylinder(0.24, 0.16, (0, y, deck + 3.26), "iron", 4, radius_top=0.02)
    m.build("pier", r)


def street_tile():
    r = lib.root("street_tile")
    m = Mesh()
    m.box((2.0, 2.0, 0.08), (0, 0, -0.04), "asphalt")
    m.build("street", r)


def street_kerb():
    r = lib.root("street_kerb")
    m = Mesh()
    m.box((2.0, 0.34, 0.16), (0, 0, 0.0), "kerb", bevel=0.03)
    m.box((2.0, 0.3, 0.02), (0, -0.32, -0.01), "asphalt")
    m.build("kerb", r)


def tram_track():
    r = lib.root("tram_track")
    m = Mesh()
    m.box((2.0, 2.8, 0.06), (0, 0, -0.03), "paving_dark")
    for k in range(3):
        m.box((0.24, 2.1, 0.05), (-0.66 + k * 0.66, 0, 0.005), "stone_dark")
    for y in (-0.72, 0.72):
        m.box((2.0, 0.1, 0.06), (0, y, 0.03), "steel")
        m.box((2.0, 0.04, 0.02), (0, y - 0.09, 0.005), "asphalt")
    m.build("track", r)


def water_tile():
    r = lib.root("water_tile")
    m = Mesh()
    n = 4
    s = 4.0 / n
    tmp = lib.bmesh.new()
    grid = [[tmp.verts.new((-2 + i * s, -2 + j * s, 0.0)) for i in range(n + 1)] for j in range(n + 1)]
    # Interior vertices undulate; edge vertices stay flat so tiles meet.
    for j in range(1, n):
        for i in range(1, n):
            grid[j][i].co.z = 0.06 * math.sin(i * 1.7 + j * 2.3) + 0.04 * math.cos(i * 2.9 - j * 1.1)
    for j in range(n):
        for i in range(n):
            if (i + j) % 2:
                tmp.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i + 1]])
                tmp.faces.new([grid[j][i], grid[j + 1][i + 1], grid[j + 1][i]])
            else:
                tmp.faces.new([grid[j][i], grid[j][i + 1], grid[j + 1][i]])
                tmp.faces.new([grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]])
    m._merge(tmp, "water", None, (0, 0, 0))
    m.build("water", r)


# The cars of the tram, the shared layout's 20.5 m end to end (see
# tools/styles/shared/tram_layout.py): (x0, x1, cab end), with their
# windows and doors along each side, (x0, x1, panes); panes 0 is a door,
# at the layout's doors.
TRAM_HW = 1.2
TRAM_CARS = [(-10.25, -3.25, -1, [(-9.3, -7.0, 2), (-6.8, -5.5, 0), (-5.3, -3.5, 2)]),
             (-2.85, 2.85, 0, [(-2.6, -0.85, 2), (-0.65, 0.65, 0), (0.85, 2.6, 2)]),
             (3.25, 10.25, 1, [(3.5, 5.3, 2), (5.5, 6.8, 0), (7.0, 9.3, 2)])]
TRAM_CAB = 0.45           # the cab's rounded nose, beyond the side walls
# The windows run from below a seated rider's eyes (the layout's floor plus
# its seated eye, 1.6 m) to above a standing rider's; the red skirt runs up
# to the windows.
TRAM_SILL, TRAM_HEAD, TRAM_TOP = 1.25, 2.75, 3.25
TRAM_SKIRT = 1.05
TRAM_GANGWAY = 0.85
assert sorted((a, b) for *_, openings in TRAM_CARS for a, b, panes in openings if not panes) == \
    sorted((round(a, 3), round(b, 3)) for a, b in tram_layout.doors_m()), "the doors are the shared layout's"


def _tram_wall(m, a, b, y, z0, z1, colour):
    """A piece of side wall from x a to b, z0 to z1, 8 cm thick about y
    (on either side of the middle): its outside in `colour`, lined cream
    inside."""
    if b - a > 1e-6 and z1 - z0 > 1e-6:
        s = 1 if y > 0 else -1
        m.box((b - a, 0.05, z1 - z0), ((a + b) / 2, y + s * 0.015, (z0 + z1) / 2), colour)
        m.box((b - a, 0.03, z1 - z0), ((a + b) / 2, y - s * 0.025, (z0 + z1) / 2), "cream")


def _tram_car(m, roof, x0, x1, cab, openings):
    """One car: a red skirt and cream sides round glazed windows and open
    doorways, open joint ends for the gangway, a cab with a windscreen and
    lamps at a nose end, and its roof (in `roof`)."""
    wx0 = x0 + (TRAM_CAB if cab < 0 else 0.0)
    wx1 = x1 - (TRAM_CAB if cab > 0 else 0.0)
    for s in (-1, 1):
        y = s * (TRAM_HW - 0.04)
        cuts = [wx0] + [x for a, b, _ in openings for x in (a, b)] + [wx1]
        for k in range(0, len(cuts), 2):
            a, b = cuts[k], cuts[k + 1]
            _tram_wall(m, a, b, y, 0.35, TRAM_SKIRT, "tram_red")
            _tram_wall(m, a, b, y, TRAM_SKIRT, TRAM_TOP, "cream")
        for a, b, panes in openings:
            if panes:
                _tram_wall(m, a, b, y, 0.35, TRAM_SKIRT, "tram_red")
                _tram_wall(m, a, b, y, TRAM_SKIRT, TRAM_SILL, "cream")
                _tram_wall(m, a, b, y, TRAM_HEAD, TRAM_TOP, "cream")
                m.box((b - a, 0.02, TRAM_HEAD - TRAM_SILL), ((a + b) / 2, y, (TRAM_SILL + TRAM_HEAD) / 2), "glass")
                w = (b - a) / panes
                for k in range(1, panes):
                    m.box((0.1, 0.1, TRAM_HEAD - TRAM_SILL), (a + k * w, y, (TRAM_SILL + TRAM_HEAD) / 2), "cream")
            else:
                _tram_wall(m, a, b, y, 2.8, TRAM_TOP, "cream")
        # The thin jackfruit rule along the skirt's top.
        for k in range(0, len(cuts), 2):
            m.box((cuts[k + 1] - cuts[k], 0.1, 0.1), ((cuts[k] + cuts[k + 1]) / 2, y + s * 0.02, TRAM_SKIRT + 0.05), "jackfruit")
    # Joint ends: wall either side of the gangway, a lintel over it.
    for x, joint in ((wx0, cab >= 0), (wx1, cab <= 0)):
        if not joint:
            continue
        for s in (-1, 1):
            m.box((0.08, TRAM_HW - TRAM_GANGWAY, TRAM_TOP - 0.35),
                  (x, s * (TRAM_GANGWAY + TRAM_HW) / 2, (0.35 + TRAM_TOP) / 2), "cream")
        m.box((0.08, 2 * TRAM_GANGWAY, TRAM_TOP - 2.6), (x, 0, (2.6 + TRAM_TOP) / 2), "cream")
    if cab:
        nx = wx1 if cab > 0 else wx0
        m.box((TRAM_CAB + 0.05, 2.4, 1.0), (nx + cab * (TRAM_CAB - 0.05) / 2, 0, 0.85), "tram_red", bevel=0.12)
        m.box((TRAM_CAB + 0.05, 2.3, 0.35), (nx + cab * (TRAM_CAB - 0.05) / 2, 0, 1.52), "cream", bevel=0.08)
        m.box((0.3, 2.0, 1.05), (nx + cab * 0.25, 0, 2.2), "glass", bevel=0.05)
        m.box((TRAM_CAB, 2.3, 0.5), (nx + cab * TRAM_CAB / 2 - cab * 0.05, 0, 3.0), "cream", bevel=0.08)
        for y in (-0.7, 0.7):
            m.box((0.06, 0.3, 0.16), (nx + cab * (TRAM_CAB - 0.03), y, 1.0), "lamp_glow")
    # Bogies.
    mid, half = (x0 + x1) / 2, (x1 - x0) / 2
    for b in (-1, 1):
        bx = mid + b * (half - 1.3)
        # Under the floor: the frame and wheels keep below 0.4 m.
        m.box((1.6, 2.0, 0.3), (bx, 0, 0.2), "charcoal", bevel=0.04)
        for w in (-0.45, 0.45):
            m.cylinder(0.2, 2.1, (bx + w, 0, 0.2), "iron", 10, rot=lib.rotx(90))
    roof.box((x1 - x0 - 0.1, 2.4, 0.2), (mid, 0, TRAM_TOP + 0.1), "steel", bevel=0.05)


def tram():
    """Three cream-and-red cars running x, 20.5 m long on the shared tram
    layout: glazed windows you see the riders through, doors that slide
    open, a seat under every seated slot, poles by the doors and ceiling
    lights. Nodes: body, roof, interior, lights and the door leaves
    (tools/styles/shared/tram_parts.py)."""
    tram_layout.write()
    r = lib.root("tram")
    m, roof = Mesh(), Mesh()
    for x0, x1, cab, openings in TRAM_CARS:
        _tram_car(m, roof, x0, x1, cab, openings)
    # Bellows between the cars: their sides and roof, open through the middle.
    for a, b in zip([c[1] for c in TRAM_CARS], [c[0] for c in TRAM_CARS[1:]]):
        for s in (-1, 1):
            m.box((b - a + 0.1, 0.3, 2.8), ((a + b) / 2, s * 1.0, 1.85), "charcoal")
        roof.box((b - a + 0.1, 2.2, 0.5), ((a + b) / 2, 0, 3.0), "charcoal")
    # A pantograph on the middle car.
    roof.beam((-0.8, 0, 3.45), (0.2, 0, 4.4), 0.06, "iron")
    roof.beam((0.8, 0, 3.45), (-0.2, 0, 4.4), 0.06, "iron")
    roof.box((0.1, 1.4, 0.06), (0, 0, 4.45), "iron")
    m.build("body", r)
    roof.build("roof", r)
    spans = [(x0 + (TRAM_CAB if cab < 0 else 0.0) + 0.05, x1 - (TRAM_CAB if cab > 0 else 0.0) - 0.05)
             for x0, x1, cab, _ in TRAM_CARS]
    spans += [(a - 0.05, b + 0.05) for a, b in zip([c[1] for c in TRAM_CARS], [c[0] for c in TRAM_CARS[1:]])]
    colours = {"floor": "stone_dark", "seat": "teal", "seat_frame": "charcoal", "pole": "steel",
               "door": "tram_red", "door_glass": "glass", "light": "window_glow"}
    tram_parts.interior(r, spans, TRAM_HW - 0.1, colours)
    tram_parts.lights(r, [(x0 + 0.5, x1 - 0.5) for x0, x1 in spans[:3]], colours, z=TRAM_TOP)
    tram_parts.doors(r, TRAM_HW + 0.05, colours)


def _cloud(name, lobes, seed):
    r = lib.root(name)
    m = Mesh()
    for k, (x, y, z, rad) in enumerate(lobes):
        m.sphere(rad, (x, y, z), "white" if k % 3 else "cream", subdivisions=2,
                 scale=(1.0, 0.85, 0.62), jitter=0.12, seed=seed + k)
    # A flat, slightly shaded underside.
    m.box((max(l[0] for l in lobes) - min(l[0] for l in lobes) + 2.0, 3.0, 0.3), (0, 0, 0.15), "limewash_shade")
    m.build("cloud", r)


def sailboat():
    """A small sailing dinghy, 5 m long along +Y: a white hull with a teal
    stripe, a mast and a triangular sail. z = 0 is the waterline."""
    r = lib.root("sailboat")
    m = Mesh()
    m.prism([(-0.9, 0.5), (0.9, 0.5), (0.6, -0.3), (-0.6, -0.3)], 3.8, (0, -0.4, 0), "white", axis="y")
    # The bow: a wedge closing the hull's front.
    m.prism([(-0.9, 1.5), (0.9, 1.5), (0.0, 2.6)], 0.8, (0, 0, 0.1), "white", axis="z")
    m.box((1.84, 3.85, 0.12), (0, -0.4, 0.3), "teal")
    m.box((1.6, 3.6, 0.05), (0, -0.4, 0.52), "wood_light")
    m.cylinder(0.05, 6.0, (0, 0.5, 3.5), "wood_dark", 6)
    m.beam((0, 0.5, 1.1), (0, -2.0, 1.1), 0.07, "wood_dark")
    m.prism([(0.45, 1.15), (0.45, 6.3), (-1.95, 1.15)], 0.03, (0, 0, 0), "cream", axis="x")
    m.build("boat", r)


def cloud_a():
    _cloud("cloud_a", [(0, 0, 1.6, 2.6), (2.6, 0.3, 1.2, 2.0), (-2.4, -0.2, 1.1, 1.9), (0.8, 0.6, 2.8, 1.8),
                       (-1.2, 0.4, 2.4, 1.5), (4.2, -0.2, 0.9, 1.3)], 31)


def cloud_b():
    _cloud("cloud_b", [(0, 0, 1.3, 2.1), (2.0, -0.3, 1.0, 1.6), (-2.0, 0.2, 1.0, 1.7), (0.4, 0.2, 2.3, 1.5),
                       (-3.4, 0.0, 0.8, 1.1)], 47)


ASSETS = {
    "sailboat": sailboat,
    "cloud_a": cloud_a,
    "cloud_b": cloud_b,
    "house_a": house_a,
    "house_b": house_b,
    "shop_a": shop_a,
    "tower_a": tower_a,
    "bridge_span": bridge_span,
    "bridge_pier": bridge_pier,
    "street_tile": street_tile,
    "street_kerb": street_kerb,
    "tram_track": tram_track,
    "water_tile": water_tile,
    "tram": tram,
}
