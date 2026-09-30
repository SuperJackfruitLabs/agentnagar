"""Building modules for the low-poly tropical kit (v2): the pack assembles
each facility from these along its footprint.

Conventions (Blender, Z-up): a wall module spans x in [-W/2, W/2], its outer
face on y = 0 facing +Y (the exporter makes that Godot's forward, -Z), its
body behind it (y < 0) and its trim standing proud (y > 0); z = 0 is the
ground. The pack turns each module to face its side's outward normal.

Guild hall (a timber-and-brick workshop under terracotta sawtooth roofs):
    hall_wall, hall_window_wall                   4 m bays, 5.2 m high
    hall_door_wall     a door bay (DOOR_W): the opening clear, a lintel
    hall_door_leaves   one side's doors folded into the reveal
    hall_corner                                   a brick pier on a corner
    hall_sawtooth_bay                             4 m x 4 m of roof, z = 0 at
                                                  the wall top, rising east
                                                  (+x) to a glazed clerestory
    hall_sawtooth_gable                           closes a tooth at either
                                                  end (it reads both ways)
Library (limewash, arched windows, a green-copper dome):
    lib_wall_arch      2 m bay, 8 m high, two storeys of arched windows
    lib_column         a pilaster for every bay joint and corner
    lib_entrance       an arched door bay (DOOR_W), its opening clear
    lib_door_leaves    one side's doors folded into the reveal
    lib_dome           drum, ribbed dome and lantern; z = 0 at the drum base
    lib_banner         a yellow banner with a book emblem on a bracket
tram_shelter           a glass canopy, bench and timetable, open to +Y
"""
import math

import lib
from lib import Mesh, arch, arched_hole, rect_hole, rotz

HALL_BAY = 4.0
HALL_H = 5.2
LIB_BAY = 2.0
LIB_H = 8.0
# A door bay: the door's 2 m opening and a reveal either side for its
# folded leaves; nothing stands in the opening in the walking band.
DOOR_REVEAL = 0.3
DOOR_W = 2.0 + 2 * DOOR_REVEAL
DOOR_H = 3.3


# ---- Guild hall ----

def _hall_trim(m, w, t=0.3):
    """Plinth, cornice and the brick shell's edge posts shared by the
    hall's wall modules."""
    m.box((w, t + 0.08, 0.45), (0, -t / 2 + 0.04, 0.225), "stone", bevel=0.02)
    m.box((w + 0.02, t + 0.3, 0.32), (0, -t / 2 + 0.15, HALL_H - 0.16), "wood_dark", bevel=0.02)
    for x in (-w / 2 + 0.11, w / 2 - 0.11):
        m.box((0.22, 0.12, HALL_H - 0.77), (x, 0.06, 0.45 + (HALL_H - 0.77) / 2), "wood", bevel=0.015)


def _glazing(m, x0, x1, z0, z1, mullions, transom=None, depth=-0.16):
    """A glazed opening: pane set back, timber frame, mullions, a transom and
    a stone sill."""
    w = x1 - x0
    cx = (x0 + x1) / 2
    m.box((w, 0.04, z1 - z0), (cx, depth, (z0 + z1) / 2), "glass")
    for x in (x0 + 0.06, x1 - 0.06):
        m.box((0.12, 0.16, z1 - z0), (x, depth + 0.06, (z0 + z1) / 2), "wood")
    m.box((w, 0.16, 0.12), (cx, depth + 0.06, z1 - 0.06), "wood")
    for k in range(1, mullions + 1):
        x = x0 + w * k / (mullions + 1)
        m.box((0.08, 0.1, z1 - z0), (x, depth + 0.04, (z0 + z1) / 2), "wood")
    if transom is not None:
        m.box((w, 0.1, 0.09), (cx, depth + 0.04, transom), "wood")
    m.box((w + 0.2, 0.34, 0.08), (cx, 0.02, z0 - 0.04), "stone", bevel=0.015)


def hall_wall():
    r = lib.root("hall_wall")
    m = Mesh()
    w = HALL_BAY
    m.slab([(-w / 2, 0.45), (w / 2, 0.45), (w / 2, HALL_H - 0.32), (-w / 2, HALL_H - 0.32)],
           [rect_hole(-1.5, 1.5, 3.7, 4.55)], 0.3, (0, -0.15, 0), "brick", reveal_mat="clay")
    _glazing(m, -1.5, 1.5, 3.7, 4.55, 3)
    # Brick coursing: a soldier course and two string lines.
    for z in (1.2, 2.4):
        m.box((w - 0.44, 0.04, 0.06), (0, 0.02, z), "clay")
    _hall_trim(m, w)
    m.build("wall", r)


def hall_window_wall():
    r = lib.root("hall_window_wall")
    m = Mesh()
    w = HALL_BAY
    m.slab([(-w / 2, 0.45), (w / 2, 0.45), (w / 2, HALL_H - 0.32), (-w / 2, HALL_H - 0.32)],
           [rect_hole(-1.55, 1.55, 0.7, 4.45)], 0.3, (0, -0.15, 0), "brick", reveal_mat="clay")
    _glazing(m, -1.55, 1.55, 0.7, 4.45, 2, transom=3.3)
    _hall_trim(m, w)
    m.build("wall", r)


def hall_door_wall():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): brick over a timber lintel and a glazed fanlight, a stone
    threshold, a lamp. Nothing stands in the opening below the lintel; the
    leaves fold into the reveals (hall_door_leaves)."""
    r = lib.root("hall_door_wall")
    m = Mesh()
    w = DOOR_W
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, HALL_H - 0.32), (-w / 2, HALL_H - 0.32)],
           [rect_hole(-1.1, 1.1, 3.55, 4.5)], 0.3, (0, -0.15, 0), "brick", reveal_mat="clay")
    m.box((w, 0.4, 0.26), (0, 0.02, DOOR_H + 0.13), "wood_dark", bevel=0.02)
    _glazing(m, -1.1, 1.1, 3.55, 4.5, 3)
    m.box((w + 0.2, 0.7, 0.12), (0, 0.2, 0.06), "stone", bevel=0.02)
    m.box((w + 0.02, 0.6, 0.32), (0, 0.0, HALL_H - 0.16), "wood_dark", bevel=0.02)
    # A lamp over the door.
    m.box((0.08, 0.3, 0.08), (0, 0.2, 3.9), "iron")
    m.box((0.22, 0.22, 0.3), (0, 0.36, 3.7), "lamp_glow")
    m.build("wall", r)


def hall_door_leaves():
    """One side's doors, folded open into the reveal beside the opening:
    four timber panels with glazed tops, square to the wall and stacked
    across the reveal (x in [-DOOR_REVEAL / 2, DOOR_REVEAL / 2]), as deep as
    the wall."""
    r = lib.root("hall_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, 0.28, DOOR_H - 0.1), (x, -0.15, (DOOR_H - 0.1) / 2 + 0.05), "wood", bevel=0.01)
        m.box((0.054, 0.18, 1.2), (x, -0.15, DOOR_H - 0.95), "glass")
    m.build("leaves", r)


def hall_corner():
    r = lib.root("hall_corner")
    m = Mesh()
    m.box((0.72, 0.72, 0.5), (0, 0, 0.25), "stone", bevel=0.03)
    m.box((0.6, 0.6, HALL_H - 0.5), (0, 0, 0.5 + (HALL_H - 0.5) / 2), "brick", bevel=0.02)
    for z in (1.4, 2.8, 4.2):
        m.box((0.64, 0.64, 0.08), (0, 0, z), "clay")
    m.box((0.76, 0.76, 0.18), (0, 0, HALL_H + 0.05), "stone", bevel=0.03)
    m.build("pier", r)


def hall_sawtooth_bay():
    r = lib.root("hall_sawtooth_bay")
    m = Mesh()
    w = HALL_BAY
    d = HALL_BAY
    rise = 2.4
    # The sloped plate, rising east, with tile ribs running down the slope.
    m.prism([(-w / 2 - 0.25, -0.12), (w / 2, rise), (w / 2, rise + 0.2), (-w / 2 - 0.25, 0.08)], d, (0, 0, 0),
            "terracotta", axis="y")
    ribs = 8
    for k in range(ribs):
        y = -d / 2 + d * (k + 0.5) / ribs
        m.beam((-w / 2 - 0.2, y, 0.12), (w / 2 - 0.05, y, rise + 0.23), 0.1,
               "terracotta_light" if k % 2 else "terracotta_dark")
    m.box((0.24, d, 0.2), (w / 2 - 0.08, 0, rise + 0.28), "terracotta_dark", bevel=0.03)
    # The clerestory: glass facing east between timber posts.
    m.box((0.05, d, rise - 0.2), (w / 2 - 0.04, 0, (rise - 0.2) / 2 + 0.05), "glass")
    for k in range(5):
        y = -d / 2 + d * k / 4
        m.box((0.14, 0.12, rise), (w / 2, y, rise / 2), "wood")
    m.box((0.18, d, 0.14), (w / 2, 0, 0.07), "wood_dark")
    # A timber truss mid-bay, seen through the glass.
    slope = math.atan2(rise, w)
    m.beam((-w / 2, 0, 0.05), (w / 2 - 0.1, 0, 0.05), 0.16, "wood")
    m.beam((-w / 2 + 0.1, 0, 0.1), (w / 2 - 0.1, 0, rise - 0.1), 0.14, "wood")
    for f in (0.3, 0.55, 0.8):
        x = -w / 2 + w * f
        m.beam((x, 0, 0.1), (x, 0, (x + w / 2) * math.tan(slope) - 0.05), 0.08, "wood_light")
    m.build("roof", r)


def hall_sawtooth_gable():
    r = lib.root("hall_sawtooth_gable")
    m = Mesh()
    w = HALL_BAY
    rise = 2.4
    tri = [(-w / 2, 0.0), (w / 2, 0.0), (w / 2, rise)]
    inset = [(-w / 2 + 1.0, 0.25), (w / 2 - 0.3, 0.25), (w / 2 - 0.3, rise - 0.75)]
    m.slab(tri, [inset], 0.26, (0, 0, 0), "brick", reveal_mat="clay")
    m.prism(inset, 0.04, (0, 0, 0), "glass", axis="y")
    m.beam((-w / 2, 0, 0.0), (w / 2, 0, rise), 0.18, "terracotta_dark", depth=0.34)
    m.build("gable", r)


# ---- Library ----

def _lib_window(m, x0, x1, sill, spring, rise, muntins=True):
    """An arched window: glass set back in the reveal, a frame, glazing bars,
    a stone sill and a keystone."""
    cx = (x0 + x1) / 2
    outline = arched_hole(x0, x1, sill, spring, rise, 8)
    m.prism([(u, v) for u, v in reversed(outline)], 0.04, (0, -0.3, 0), "glass", axis="y")
    if muntins:
        m.box((0.05, 0.05, spring + rise - sill - 0.05), (cx, -0.27, (sill + spring + rise) / 2), "copper_dark")
        for z in (sill + (spring - sill) * 0.5, spring):
            m.box((x1 - x0, 0.05, 0.05), (cx, -0.27, z), "copper_dark")
    m.box((x1 - x0 + 0.3, 0.3, 0.1), (cx, 0.06, sill - 0.05), "sandstone", bevel=0.02)
    m.box((0.26, 0.14, 0.42), (cx, 0.04, spring + rise + 0.05), "sandstone", bevel=0.02)


def lib_wall_arch():
    r = lib.root("lib_wall_arch")
    m = Mesh()
    w = LIB_BAY
    t = 0.4
    holes = [arched_hole(-0.55, 0.55, 1.1, 3.0, 0.55), arched_hole(-0.5, 0.5, 4.9, 6.6, 0.5)]
    m.slab([(-w / 2, 0.9), (w / 2, 0.9), (w / 2, LIB_H - 0.55), (-w / 2, LIB_H - 0.55)], holes, t,
           (0, -t / 2, 0), "limewash", reveal_mat="limewash_shade")
    _lib_window(m, -0.55, 0.55, 1.1, 3.0, 0.55)
    _lib_window(m, -0.5, 0.5, 4.9, 6.6, 0.5)
    # Plinth, string course and a cornice with dentils.
    m.box((w, t + 0.12, 0.9), (0, -t / 2 + 0.06, 0.45), "sandstone", bevel=0.02)
    m.box((w, t + 0.2, 0.26), (0, -t / 2 + 0.1, 4.12), "sandstone", bevel=0.02)
    m.box((w, t + 0.36, 0.3), (0, -t / 2 + 0.18, LIB_H - 0.4), "sandstone", bevel=0.02)
    m.box((w, t + 0.5, 0.22), (0, -t / 2 + 0.25, LIB_H - 0.11), "sandstone", bevel=0.03)
    for k in range(6):
        m.box((0.12, 0.14, 0.14), (-w / 2 + 0.17 + k * 0.33, 0.16, LIB_H - 0.62), "limewash_shade")
    m.build("wall", r)


def lib_column():
    r = lib.root("lib_column")
    m = Mesh()
    m.box((0.62, 0.3, 0.95), (0, 0.05, 0.475), "sandstone", bevel=0.03)
    m.box((0.46, 0.2, LIB_H - 1.6), (0, 0.06, 0.95 + (LIB_H - 1.6) / 2), "limewash", bevel=0.02)
    for x in (-0.12, 0.0, 0.12):
        m.box((0.05, 0.03, LIB_H - 1.9), (x, 0.17, 0.95 + (LIB_H - 1.6) / 2), "limewash_shade")
    m.box((0.6, 0.3, 0.3), (0, 0.08, LIB_H - 0.55), "sandstone", bevel=0.03)
    m.box((0.52, 0.26, 0.26), (0, 0.07, 4.12), "sandstone", bevel=0.02)
    m.build("column", r)


def lib_entrance():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): an arched portal under a glowing fanlight, its sandstone
    arch, three arched windows over it and a pediment, and a low threshold
    step. Nothing stands in the opening below the arch; the leaves fold
    into the reveals (lib_door_leaves)."""
    r = lib.root("lib_entrance")
    m = Mesh()
    w = DOOR_W
    t = 0.4
    spring, rise = DOOR_H - 0.4, w / 2
    upper = [arched_hole(-1.2, -0.5, 4.9, 6.4, 0.35), arched_hole(-0.3, 0.3, 4.9, 6.6, 0.3),
             arched_hole(0.5, 1.2, 4.9, 6.4, 0.35)]
    head = arch(-w / 2, w / 2, spring, rise, 10)
    m.slab(head + [(w / 2, LIB_H - 0.55), (-w / 2, LIB_H - 0.55)], upper, t, (0, -t / 2, 0), "limewash",
           reveal_mat="limewash_shade")
    # The glowing fanlight in the arch, its copper glazing bars.
    m.prism([(-w / 2, spring)] + head[1:-1] + [(w / 2, spring)], 0.04, (0, -0.32, 0), "window_glow", axis="y")
    m.box((w, 0.06, 0.1), (0, -0.3, spring), "copper_dark")
    for k in range(3):
        a = math.pi * (k + 1) / 4
        m.beam((0, -0.3, spring), (-math.cos(a) * rise, -0.3, spring + math.sin(a) * rise), 0.05, "copper_dark")
    for x0, x1, top in ((-1.2, -0.5, 6.4), (-0.3, 0.3, 6.6), (0.5, 1.2, 6.4)):
        _lib_window(m, x0, x1, 4.9, top, 0.35 if top < 6.5 else 0.3, muntins=False)
    # The arch's sandstone surround, and a pediment.
    for k in range(9):
        a0 = math.pi * k / 9
        a1 = math.pi * (k + 1) / 9
        p0 = (-math.cos(a0) * (rise + 0.13), 0.1, spring + math.sin(a0) * (rise + 0.13))
        p1 = (-math.cos(a1) * (rise + 0.13), 0.1, spring + math.sin(a1) * (rise + 0.13))
        m.beam(p0, p1, 0.26, "sandstone", depth=0.22)
    m.prism([(-w / 2 - 0.2, 0.0), (w / 2 + 0.2, 0.0), (0.0, 0.9)], 0.5, (0, 0.2, LIB_H - 0.3), "sandstone", axis="y")
    m.prism([(-w / 2 + 0.3, 0.12), (w / 2 - 0.3, 0.12), (0.0, 0.7)], 0.52, (0, 0.2, LIB_H - 0.3), "limewash", axis="y")
    # A low step out onto the square (below the walking band).
    m.box((w + 0.4, 0.9, 0.16), (0, 0.45, 0.08), "sandstone", bevel=0.02)
    m.box((w, t + 0.36, 0.3), (0, -t / 2 + 0.18, LIB_H - 0.4), "sandstone", bevel=0.02)
    m.box((w, t + 0.5, 0.22), (0, -t / 2 + 0.25, LIB_H - 0.11), "sandstone", bevel=0.03)
    m.build("entrance", r)


def lib_door_leaves():
    """One side of the library's doors, folded open into the reveal beside
    the opening: four dark timber panels with glazed tops, square to the
    wall and stacked across the reveal, as deep as the wall."""
    r = lib.root("lib_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, 0.38, DOOR_H - 0.5), (x, -0.2, (DOOR_H - 0.5) / 2 + 0.05), "wood_dark", bevel=0.01)
        m.box((0.054, 0.26, 1.1), (x, -0.2, DOOR_H - 1.2), "glass")
    m.build("leaves", r)


def lib_dome():
    r = lib.root("lib_dome")
    m = Mesh()
    rad = 4.2
    sides = 24
    m.cylinder(rad + 0.35, 0.5, (0, 0, 0.25), "sandstone", sides)
    m.cylinder(rad, 2.8, (0, 0, 0.5 + 1.4), "limewash", sides)
    # Arched windows around the drum.
    for k in range(12):
        a = 2 * math.pi * (k + 0.5) / 12
        rot = rotz(math.degrees(a) + 90)
        at = (math.cos(a) * (rad + 0.02), math.sin(a) * (rad + 0.02), 0)
        outline = arched_hole(-0.35, 0.35, 1.0, 2.2, 0.35, 6)
        m.prism([(u, v) for u, v in reversed(outline)], 0.05, at, "glass", axis="y", rot=rot)
        m.box((0.18, 0.12, 2.3), (math.cos(a + 0.26) * (rad + 0.05), math.sin(a + 0.26) * (rad + 0.05), 1.95),
              "sandstone", rot=rotz(math.degrees(a)))
    m.cylinder(rad + 0.3, 0.35, (0, 0, 3.4), "sandstone", sides)
    m.dome(rad + 0.1, (0, 0, 3.55), "copper", segments=sides, rings=7, squash=0.9, ribs_mat="copper_light")
    top = 3.55 + (rad + 0.1) * 0.9
    m.cylinder(0.9, 0.3, (0, 0, top - 0.05), "sandstone", 12)
    for k in range(8):
        a = 2 * math.pi * k / 8
        m.box((0.14, 0.14, 1.0), (math.cos(a) * 0.7, math.sin(a) * 0.7, top + 0.6), "limewash")
    m.cylinder(0.78, 1.0, (0, 0, top + 0.6), "glass", 8)
    m.dome(0.9, (0, 0, top + 1.1), "copper", segments=12, rings=3)
    m.cylinder(0.06, 0.7, (0, 0, top + 2.2), "jackfruit", 6)
    m.sphere(0.14, (0, 0, top + 2.6), "jackfruit", subdivisions=1)
    m.build("dome", r)


def lib_banner():
    r = lib.root("lib_banner")
    m = Mesh()
    m.box((0.5, 0.06, 0.2), (0, 0.03, 0), "iron")
    m.box((0.06, 0.6, 0.06), (0, 0.3, 0.0), "iron")
    m.cylinder(0.035, 1.2, (0, 0.6, -0.05), "iron", 6, rot=lib.roty(90))
    # The banner hangs in front of the bracket, facing out (+Y).
    m.box((1.0, 0.04, 3.4), (0, 0.6, -1.8), "jackfruit")
    m.prism([(-0.5, 0.0), (0.5, 0.0), (0.0, 0.35)], 0.04, (0, 0.6, -3.85), "jackfruit", axis="y", rot=lib.rotx(180))
    # A white open book: two pages tilted about the spine.
    for side in (-1, 1):
        m.box((0.3, 0.02, 0.4), (side * 0.16, 0.63, -1.4), "white", rot=lib.roty(side * -12))
    m.box((0.03, 0.02, 0.42), (0, 0.635, -1.42), "jackfruit_dark")
    m.box((0.9, 0.02, 0.05), (0, 0.63, -2.6), "white")
    m.box((0.7, 0.02, 0.05), (0, 0.63, -2.75), "white")
    m.build("banner", r)


# ---- Tram shelter ----

def tram_shelter():
    """A tram stop open to +Y: teal posts along a glass back, a glass
    screen at one end, a timber bench and the timetable, under a glass
    canopy. Where people walk it is laid out as the other kits' stops (the
    tram-shelter kind's footprint): the front stays open to the stand."""
    r = lib.root("tram_shelter")
    m = Mesh()
    w, d, h = 4.4, 1.8, 2.8
    # Where people walk the stop is laid out to the tram-shelter kind's
    # footprint: its back 0.75 m behind the point (the posts' back faces),
    # the bench to 0.15 m, the end screen's post to 0.40 m; the front is
    # open to the stand.
    yb = -0.69
    for x in (-w / 2 + 0.12, w / 2 - 0.12):
        m.box((0.1, 0.12, h), (x, yb, h / 2), "teal_dark")
    m.prism([(-d / 2 - 0.1, h), (d / 2 + 0.25, h - 0.2), (d / 2 + 0.25, h - 0.05), (-d / 2 - 0.1, h + 0.15)],
            w + 0.3, (0, 0, 0), "glass_light", axis="x")
    m.box((w + 0.35, 0.14, 0.14), (0, d / 2 + 0.2, h - 0.12), "teal")
    m.box((w + 0.35, 0.14, 0.14), (0, -d / 2 - 0.05, h + 0.07), "teal")
    # The glass back and the end screen.
    m.box((w - 0.3, 0.03, 1.95), (0, yb, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((w - 0.2, 0.07, 0.06), (0, yb, z), "teal_dark")
    m.box((0.03, 1.0, 1.95), (-w / 2 + 0.12, yb + 0.55, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((0.07, 1.05, 0.06), (-w / 2 + 0.12, yb + 0.55, z), "teal_dark")
    m.box((0.06, 0.06, h - 0.2), (-w / 2 + 0.12, yb + 1.06, (h - 0.2) / 2), "teal_dark")
    # A timber bench with a back rail, on iron legs.
    m.box((2.36, 0.42, 0.06), (-0.55, yb + 0.33, 0.46), "wood_light", bevel=0.01)
    m.box((2.36, 0.06, 0.3), (-0.55, yb + 0.1, 0.78), "wood_light", bevel=0.01)
    for x in (-1.6, 0.5):
        m.box((0.06, 0.36, 0.44), (x, yb + 0.33, 0.22), "iron")
    # The timetable, against the glass at the bench's open end.
    m.box((0.7, 0.1, 1.2), (1.55, yb + 0.1, 1.3), "teal")
    for k in range(4):
        m.box((0.56, 0.02, 0.06), (1.55, yb + 0.16, 1.6 - k * 0.2), "white")
    m.box((w - 0.4, 0.3, 0.1), (0, 0, 0.05), "paving_dark")
    m.build("shelter", r)


ASSETS = {
    "hall_wall": hall_wall,
    "hall_window_wall": hall_window_wall,
    "hall_door_wall": hall_door_wall,
    "hall_door_leaves": hall_door_leaves,
    "hall_corner": hall_corner,
    "hall_sawtooth_bay": hall_sawtooth_bay,
    "hall_sawtooth_gable": hall_sawtooth_gable,
    "lib_wall_arch": lib_wall_arch,
    "lib_column": lib_column,
    "lib_entrance": lib_entrance,
    "lib_door_leaves": lib_door_leaves,
    "lib_dome": lib_dome,
    "lib_banner": lib_banner,
    "tram_shelter": tram_shelter,
}
