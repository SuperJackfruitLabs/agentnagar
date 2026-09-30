"""Building modules for the cel-shaded anime kit, after the 06 sheets: the
workshop's bright red-orange brick under a sawtooth roof whose steep faces
are glazed, black-framed tall windows with stone sills and lintels; the
library's two-storey glazed arcade under a silver standing-seam barrel
vault; glass towers stepping back to planted terraces; cream and peach
houses with balconies; a shop with an awning.

Conventions match the low-poly kit so the anime townscape assembles the
same way (Blender Z-up; a wall module spans x in [-W/2, W/2] with its outer
face on y = 0 facing +Y, Godot's forward -Z, its body behind at y < 0;
z = 0 is the ground):
    hall_wall, hall_window_wall                   4 m bays, 5.2 m high
    hall_door_wall     a door bay (DOOR_W): the opening clear, a lintel
    hall_door_leaves   one side's doors folded into the reveal
    hall_corner                                   a brick pier
    hall_sawtooth_bay                             4 m x 4 m of roof over
                                                  z = 0 at the wall top
    hall_sawtooth_gable                           closes a tooth's end
    lib_wall_arch      a 2 m bay, 8 m high: a two-storey arched window
    lib_column         the pilaster at every bay joint and corner
    lib_entrance       a door bay (DOOR_W): a glazed arch over the open
                       doorway, a canopy, a low step
    lib_door_leaves    one side's doors folded into the reveal
    lib_vault          the roof over the 20 m x 18 m library, z = 0 at the
                       wall top; its axis runs x, the glazed gable at -x
    lib_banner         a blue book banner hanging below its bracket (z = 0)
Blocks (origin at the footprint's centre on the ground, fronts facing +Y):
    tower_a, tower_b   glass towers stepping back to planted terraces
    house_a/b/c        three-storey rendered town houses, terracotta roofs
    shop_a             a shopfront under a striped awning, two floors above
    tram_shelter       a steel-and-glass shelter, open to +Y
"""
import math
import random

import lib
from lib import Mesh, arch, arched_hole, rect_hole

HALL_BAY = 4.0
HALL_H = 5.2
WALL_T = 0.3
# A door bay: the door's 2 m opening and a reveal either side for its
# folded leaves; nothing stands in the opening in the walking band.
DOOR_REVEAL = 0.3
DOOR_W = 2.0 + 2 * DOOR_REVEAL
DOOR_H = 3.1


# ---- Workshop ----

def _brick_courses(m, x0, x1, z0, z1, every=0.6):
    """Slightly proud header courses across a brick face, the sheets'
    horizontal banding."""
    z = z0 + every
    while z < z1 - 0.1:
        m.box((x1 - x0, 0.03, 0.05), ((x0 + x1) / 2, 0.015, z), "brick_dark")
        z += every


def _hall_window(m, x0, x1, z0, z1, cols, rows, depth=-0.14):
    """A tall steel window: glass set back, a black frame, a grid of thin
    black glazing bars, a stone sill and lintel."""
    w, h = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.box((w, 0.03, h), (cx, depth, cz), "glass")
    for x in (x0 + 0.04, x1 - 0.04):
        m.box((0.08, 0.1, h), (x, depth + 0.04, cz), "frame")
    for z in (z0 + 0.04, z1 - 0.04):
        m.box((w, 0.1, 0.08), (cx, depth + 0.04, z), "frame")
    for k in range(1, cols):
        m.box((0.035, 0.06, h), (x0 + w * k / cols, depth + 0.03, cz), "frame")
    for k in range(1, rows):
        m.box((w, 0.06, 0.035), (cx, depth + 0.03, z0 + h * k / rows), "frame")
    m.box((w + 0.16, 0.26, 0.1), (cx, 0.03, z0 - 0.05), "stone", bevel=0.01)
    m.box((w + 0.16, 0.12, 0.16), (cx, 0.0, z1 + 0.08), "stone", bevel=0.01)


def _lining(m, w, holes, z0=0.4):
    """The painted inner face of a hall wall (the sheets' workshop is
    white inside), with the wall's openings."""
    m.slab([(-w / 2, z0), (w / 2, z0), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)], holes, 0.02,
           (0, -WALL_T - 0.01, 0), "warm_white")


def _hall_base(m, w, top):
    """The wall's plinth and coping, shared by the bays."""
    m.box((w, WALL_T + 0.06, 0.4), (0, -WALL_T / 2 + 0.03, 0.2), "stone_dark", bevel=0.015)
    m.box((w + 0.02, WALL_T + 0.14, 0.22), (0, -WALL_T / 2 + 0.07, top - 0.11), "stone", bevel=0.015)


def hall_wall():
    r = lib.root("hall_wall")
    m = Mesh()
    w = HALL_BAY
    m.slab([(-w / 2, 0.4), (w / 2, 0.4), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)],
           [rect_hole(-0.7, 0.7, 2.6, 4.4)], WALL_T, (0, -WALL_T / 2, 0), "brick", reveal_mat="brick_dark")
    _lining(m, w, [rect_hole(-0.7, 0.7, 2.6, 4.4)])
    _hall_window(m, -0.7, 0.7, 2.6, 4.4, 2, 3)
    _brick_courses(m, -w / 2, -0.8, 0.4, HALL_H - 0.3)
    _brick_courses(m, 0.8, w / 2, 0.4, HALL_H - 0.3)
    _hall_base(m, w, HALL_H)
    m.build("wall", r)


def hall_window_wall():
    r = lib.root("hall_window_wall")
    m = Mesh()
    w = HALL_BAY
    m.slab([(-w / 2, 0.4), (w / 2, 0.4), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)],
           [rect_hole(-1.45, 1.45, 0.75, 4.45)], WALL_T, (0, -WALL_T / 2, 0), "brick", reveal_mat="brick_dark")
    _lining(m, w, [rect_hole(-1.45, 1.45, 0.75, 4.45)])
    _hall_window(m, -1.45, 1.45, 0.75, 4.45, 4, 5)
    _hall_base(m, w, HALL_H)
    m.build("wall", r)


def hall_door_wall():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): brick over a black steel lintel and a transom window, a slim
    canopy, a stone threshold, a lamp. Nothing stands in the opening below
    the lintel; the doors fold into the reveals (hall_door_leaves)."""
    r = lib.root("hall_door_wall")
    m = Mesh()
    w = DOOR_W
    transom = rect_hole(-1.05, 1.05, 3.45, 4.5)
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)], [transom],
           WALL_T, (0, -WALL_T / 2, 0), "brick", reveal_mat="brick_dark")
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)], [transom], 0.02,
           (0, -WALL_T - 0.01, 0), "warm_white")
    m.box((w, 0.34, 0.12), (0, 0.0, DOOR_H + 0.06), "frame")
    _hall_window(m, -1.05, 1.05, 3.45, 4.5, 4, 1)
    m.box((w + 0.6, 1.3, 0.1), (0, 0.55, 3.45), "steel_dark", bevel=0.01)
    for x in (-1.5, 1.5):
        m.box((0.05, 1.25, 0.05), (x, 0.55, 3.72), "iron")
    m.box((w + 0.4, 0.9, 0.1), (0, 0.35, 0.05), "stone", bevel=0.015)
    m.box((w + 0.02, WALL_T + 0.14, 0.22), (0, -WALL_T / 2 + 0.07, HALL_H - 0.11), "stone", bevel=0.015)
    # A lamp over the door.
    m.box((0.06, 0.26, 0.06), (0, 0.13, 4.05), "iron")
    m.box((0.2, 0.2, 0.26), (0, 0.28, 3.88), "lamp_glow")
    m.build("wall", r)


def hall_door_leaves():
    """One side's doors, folded open into the reveal beside the opening:
    four black steel glazed panels square to the wall, stacked across the
    reveal (x in [-DOOR_REVEAL / 2, DOOR_REVEAL / 2]), as deep as the wall."""
    r = lib.root("hall_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, WALL_T - 0.02, DOOR_H - 0.1), (x, -WALL_T / 2, (DOOR_H - 0.1) / 2 + 0.05), "frame")
        m.box((0.054, WALL_T - 0.1, DOOR_H - 0.5), (x, -WALL_T / 2, (DOOR_H - 0.5) / 2 + 0.25), "glass")
    m.build("leaves", r)


def hall_corner():
    r = lib.root("hall_corner")
    m = Mesh()
    m.box((0.7, 0.7, 0.42), (0, 0, 0.21), "stone_dark", bevel=0.02)
    m.box((0.58, 0.58, HALL_H - 0.42), (0, 0, 0.42 + (HALL_H - 0.42) / 2), "brick", bevel=0.015)
    for z in (1.5, 3.0, 4.5):
        m.box((0.62, 0.62, 0.06), (0, 0, z), "brick_dark")
    m.box((0.72, 0.72, 0.16), (0, 0, HALL_H + 0.04), "stone", bevel=0.02)
    m.build("pier", r)


def hall_sawtooth_bay():
    """One 4 m x 4 m bay of sawtooth roof: a long brick-red slope rising
    east (+x) to a steep glazed face looking west, the ridge 2.7 m up."""
    r = lib.root("hall_sawtooth_bay")
    m = Mesh()
    w, d, h = HALL_BAY, HALL_BAY, 2.7
    x0, x1 = -w / 2 - 0.08, w / 2 + 0.08
    y0, y1 = -d / 2 - 0.02, d / 2 + 0.02
    # The slope: a prism (x, z) along y, standing-seam red roof.
    m.prism([(x0, 0.0), (x1 - 0.5, h), (x1 - 0.2, h), (x1 - 0.2, 0.0)], y1 - y0, (0, 0, 0), "terracotta", axis="y")
    # Seams running up the slope.
    for k in range(9):
        y = y0 + 0.2 + k * (y1 - y0 - 0.4) / 8
        m.beam((x0 + 0.05, y, 0.05), (x1 - 0.5, y, h + 0.02), 0.035, "terracotta_dark")
    # The steep north-light face: glazing between black mullions.
    m.box((0.06, y1 - y0 - 0.1, h - 0.3), (x1 - 0.17, 0, h / 2 + 0.05), "glass_light")
    for k in range(6):
        y = y0 + 0.05 + k * (y1 - y0 - 0.1) / 5
        m.box((0.08, 0.06, h - 0.2), (x1 - 0.14, y, h / 2 + 0.05), "frame")
    m.box((0.1, y1 - y0, 0.08), (x1 - 0.14, 0, h - 0.1), "frame")
    m.box((0.12, y1 - y0, 0.1), (x1 - 0.14, 0, 0.1), "frame")
    # Ridge cap.
    m.box((0.36, y1 - y0 + 0.04, 0.1), (x1 - 0.35, 0, h + 0.03), "steel_light", bevel=0.01)
    m.build("roof", r)


def hall_sawtooth_gable():
    """The brick triangle closing a tooth's end, with a small vent."""
    r = lib.root("hall_sawtooth_gable")
    m = Mesh()
    w, h = HALL_BAY, 2.4
    pts = [(-w / 2 - 0.05, 0.0), (w / 2 - 0.4, h), (w / 2 + 0.05, h), (w / 2 + 0.05, 0.0)]
    m.slab(pts, [], 0.3, (0, 0, 0), "brick", reveal_mat="brick_dark")
    m.box((0.9, 0.05, 0.4), (0.9, 0.16, 1.3), "frame")
    for k in range(4):
        m.box((0.8, 0.07, 0.03), (0.9, 0.17, 1.15 + k * 0.1), "steel_dark")
    m.build("gable", r)


# ---- Library ----

LIB_BAY = 2.0
LIB_H = 8.0
LIB_T = 0.36


def _arch_z(x, x0, x1, spring, rise):
    """The height of a round (or elliptical) arch over [x0, x1] at x."""
    u = (x - (x0 + x1) / 2) / ((x1 - x0) / 2)
    return spring + rise * math.sqrt(max(0.0, 1.0 - u * u))


def _lib_glazing(m, x0, x1, sill, spring, rise, lights=3, transoms=(), floor=None, depth=-0.24,
                 pane="window_glow", fan="glass_light"):
    """Glass in an arched opening, set back to `depth`: warm-lit panes up to
    the springing and a sky-bright fanlight, in a black steel frame with
    `lights` bays of mullions, transoms at `transoms` and a slim floor band
    at `floor` (the slab between the storeys)."""
    cx, w = (x0 + x1) / 2, x1 - x0
    m.box((w, 0.03, spring - sill), (cx, depth, (sill + spring) / 2), pane)
    m.prism(arch(x0, x1, spring, rise, 8), 0.03, (0, depth, 0), fan, axis="y")
    f = depth + 0.045
    for x in (x0 + 0.04, x1 - 0.04):
        m.box((0.08, 0.09, spring - sill), (x, f, (sill + spring) / 2), "frame")
    m.box((w, 0.09, 0.08), (cx, f, sill + 0.04), "frame")
    pts = arch(x0 + 0.04, x1 - 0.04, spring, rise - 0.04, 8)
    for a, b in zip(pts, pts[1:]):
        m.beam((a[0], f, a[1]), (b[0], f, b[1]), 0.08, "frame", depth=0.09)
    for k in range(1, lights):
        x = x0 + w * k / lights
        top = _arch_z(x, x0, x1, spring, rise) - 0.03
        m.box((0.05, 0.07, top - sill), (x, f - 0.01, (sill + top) / 2), "frame")
    for z in tuple(transoms) + (spring,):
        m.box((w, 0.07, 0.05), (cx, f - 0.01, z), "frame")
    if floor is not None:
        m.box((w, 0.1, 0.3), (cx, f + 0.01, floor), "steel_dark", bevel=0.01)
        m.box((w, 0.05, 0.05), (cx, f + 0.03, floor + 0.62), "frame")
        for k in range(1, 6):
            m.box((0.03, 0.03, 0.47), (x0 + w * k / 6, f + 0.03, floor + 0.38), "frame")


def _arch_band(m, x0, x1, spring, rise, width, y, depth, mat, segments=10):
    """A smooth stone band round an arch's head, `width` wide, its face
    standing `depth` proud of y."""
    outer = arch(x0 - width, x1 + width, spring, rise + width, segments)
    inner = arch(x0, x1, spring, rise, segments)
    m.slab(outer + list(reversed(inner)), [], depth, (0, y + depth / 2, 0), mat)


def _lib_trim(m, w, t=LIB_T):
    """The library wall's stone plinth and two-step cornice."""
    m.box((w, t + 0.1, 0.55), (0, -t / 2 + 0.05, 0.275), "stone", bevel=0.02)
    m.box((w, t + 0.14, 0.3), (0, -t / 2 + 0.07, LIB_H - 0.35), "warm_white", bevel=0.02)
    m.box((w, t + 0.3, 0.2), (0, -t / 2 + 0.15, LIB_H - 0.1), "stone", bevel=0.02)


def lib_wall_arch():
    r = lib.root("lib_wall_arch")
    m = Mesh()
    w = LIB_BAY
    x0, x1, sill, spring, rise = -0.62, 0.62, 0.7, 6.45, 0.62
    m.slab([(-w / 2, 0.55), (w / 2, 0.55), (w / 2, LIB_H - 0.5), (-w / 2, LIB_H - 0.5)],
           [arched_hole(x0, x1, sill, spring, rise, 8)], LIB_T, (0, -LIB_T / 2, 0), "cream", reveal_mat="stone")
    _lib_glazing(m, x0, x1, sill, spring, rise, lights=3, transoms=(2.7, 5.3), floor=3.75)
    # A stone sill, a band round the arch's head and a keystone.
    m.box((x1 - x0 + 0.22, 0.2, 0.1), (0, 0.04, sill - 0.05), "stone", bevel=0.015)
    _arch_band(m, x0, x1, spring, rise, 0.12, 0.0, 0.05, "warm_white")
    m.box((0.2, 0.09, 0.3), (0, 0.045, spring + rise + 0.1), "stone", bevel=0.015)
    _lib_trim(m, w)
    m.build("wall", r)


def lib_column():
    r = lib.root("lib_column")
    m = Mesh()
    m.box((0.6, 0.3, 0.7), (0, 0.1, 0.35), "stone", bevel=0.03)
    m.box((0.42, 0.24, LIB_H - 1.25), (0, 0.07, 0.7 + (LIB_H - 1.25) / 2), "warm_white", bevel=0.02)
    m.box((0.52, 0.28, 0.2), (0, 0.09, 3.75), "stone", bevel=0.02)
    m.box((0.56, 0.3, 0.32), (0, 0.1, LIB_H - 0.36), "stone", bevel=0.03)
    m.build("column", r)


def lib_entrance():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): a glazed arch over the open doorway, its stone band, a slim
    canopy on tie rods, a low step, and the raised parapet with the book
    sign. Nothing stands in the opening below the glazing; the doors fold
    into the reveals (lib_door_leaves)."""
    r = lib.root("lib_entrance")
    m = Mesh()
    w = DOOR_W
    x0, x1, spring, rise = -w / 2, w / 2, 5.1, 1.3
    head = arch(x0, x1, spring, rise, 10)
    m.slab([(x0, spring)] + head[1:-1] + [(x1, spring), (x1, LIB_H - 0.5), (x0, LIB_H - 0.5)], [], LIB_T,
           (0, -LIB_T / 2, 0), "cream")
    _lib_glazing(m, x0, x1, DOOR_H, spring, rise, lights=4, transoms=(), floor=3.75, depth=-0.26)
    m.box((w, 0.1, 0.12), (0, -0.21, DOOR_H + 0.06), "frame")
    _arch_band(m, x0, x1, spring, rise, 0.24, 0.0, 0.1, "warm_white", 12)
    m.box((0.34, 0.16, 0.5), (0, 0.08, spring + rise + 0.18), "stone", bevel=0.02)
    # A slim steel canopy on tie rods over the doorway.
    m.box((3.5, 2.0, 0.12), (0, 1.0, 3.05), "steel_dark", bevel=0.02)
    m.box((3.4, 1.9, 0.03), (0, 1.0, 3.12), "glass_light")
    for x in (-1.6, 1.6):
        m.beam((x, 0.0, 4.5), (x, 1.92, 3.12), 0.05, "frame")
    # A low stone step out onto the square.
    m.box((w + 0.8, 1.2, 0.15), (0, 0.6, 0.075), "stone", bevel=0.02)
    # A raised parapet over the bay carrying the library's book sign.
    m.box((w, LIB_T + 0.14, 0.3), (0, -LIB_T / 2 + 0.07, LIB_H - 0.35), "warm_white", bevel=0.02)
    m.box((w, LIB_T + 0.3, 0.2), (0, -LIB_T / 2 + 0.15, LIB_H - 0.1), "stone", bevel=0.02)
    m.box((2.2, 0.3, 0.6), (0, -0.05, LIB_H + 0.3), "warm_white", bevel=0.03)
    m.box((2.4, 0.36, 0.1), (0, -0.05, LIB_H + 0.62), "stone", bevel=0.02)
    m.cylinder(0.24, 0.06, (0, 0.13, LIB_H + 0.3), "blue", 16, rot=lib.rotx(90))
    for side in (-1, 1):
        m.box((0.15, 0.02, 0.2), (side * 0.085, 0.17, LIB_H + 0.3), "warm_white", rot=lib.roty(side * -14))
    m.build("entrance", r)


def lib_door_leaves():
    """One side of the library's glass doors, folded open into the reveal
    beside the opening: four black steel panels square to the wall, stacked
    across the reveal, as deep as the wall."""
    r = lib.root("lib_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, LIB_T - 0.02, DOOR_H - 0.1), (x, -LIB_T / 2, (DOOR_H - 0.1) / 2 + 0.05), "frame")
        m.box((0.054, LIB_T - 0.1, DOOR_H - 0.5), (x, -LIB_T / 2, (DOOR_H - 0.5) / 2 + 0.25), "glass_light")
    m.build("leaves", r)


def lib_banner():
    r = lib.root("lib_banner")
    m = Mesh()
    # A steel bracket fixed to the wall at z = 0, the banner hanging below.
    m.box((0.36, 0.06, 0.22), (0, 0.03, 0.0), "frame", bevel=0.01)
    m.box((0.06, 0.62, 0.07), (0, 0.33, 0.0), "frame")
    m.beam((0, 0.06, -0.3), (0, 0.45, 0.0), 0.04, "frame")
    m.cylinder(0.035, 1.2, (0, 0.6, -0.08), "steel", 8, rot=lib.roty(90))
    for x in (-0.6, 0.6):
        m.sphere(0.06, (x, 0.6, -0.08), "steel_light", subdivisions=1)
    # The cloth: blue with a white open book, and a swallowtail hem.
    m.box((1.0, 0.04, 3.7), (0, 0.6, -1.97), "blue", bevel=0.01)
    m.prism([(-0.5, 0.0), (0.5, 0.0), (0.5, -0.42), (0.0, -0.16), (-0.5, -0.42)], 0.04, (0, 0.6, -3.8),
            "blue", axis="y")
    for side in (-1, 1):
        m.prism([(0.0, 0.0), (0.3, 0.06), (0.3, 0.46), (0.0, 0.4)], 0.02, (0, 0.625, -1.55), "warm_white",
                axis="y", rot=None if side > 0 else lib.rotz(180))
    m.box((0.03, 0.03, 0.44), (0, 0.63, -1.33), "indigo")
    for k, wd in enumerate((0.7, 0.5)):
        m.box((wd, 0.02, 0.06), (0, 0.625, -2.35 - k * 0.16), "warm_white")
    m.box((1.0, 0.05, 0.08), (0, 0.6, -0.2), "yellow")
    m.build("banner", r)


# The vault: an elliptical segment springing steeply from the eaves, as the
# sheets draw it, 18.4 m across and 6 m high over a 20.4 m length along x.
VAULT_SPAN = 18.4
VAULT_LEN = 20.4
VAULT_RISE = 6.0
_T0 = math.radians(16)
_VB = VAULT_RISE / (1 - math.sin(_T0))
_VA = VAULT_SPAN / 2 / math.cos(_T0)
_VC = _VB * math.sin(_T0)


def _vault_point(t, grow=0.0):
    """(y, z) on the vault's section at parameter t in [0, 1] (y = -span/2
    to +span/2), moved `grow` along the outward normal."""
    a = _T0 + (math.pi - 2 * _T0) * t
    y, z = -_VA * math.cos(a), _VB * math.sin(a) - _VC
    ny, nz = -math.cos(a) / _VA, math.sin(a) / _VB
    n = math.hypot(ny, nz)
    return y + grow * ny / n, z + grow * nz / n, (ny / n, nz / n)


def _vault_curve(grow, n=32, floor=0.0):
    """The section offset by `grow`, its ends cut or dropped to z = floor."""
    pts = [_vault_point(k / n, grow)[:2] for k in range(n + 1)]
    for end, nxt in ((0, 1), (-1, -2)):
        (y, z), (y2, z2) = pts[end], pts[nxt]
        if z < floor:
            s = (floor - z) / (z2 - z)
            pts[end] = (y + (y2 - y) * s, floor)
    if pts[0][1] > floor + 1e-4:
        pts.insert(0, (pts[0][0], floor))
    if pts[-1][1] > floor + 1e-4:
        pts.append((pts[-1][0], floor))
    return pts


def _vault_ring(m, grow_out, grow_in, x, depth, mat, n=32):
    """An arch ring round the section between two offsets, `depth` along x."""
    outer = _vault_curve(grow_out, n)
    inner = _vault_curve(grow_in, n)
    m.slab(outer + list(reversed(inner)), [], depth, (x, 0, 0), mat, axis="x")


def lib_vault():
    r = lib.root("lib_vault")
    m = Mesh()
    n = 36
    half = VAULT_LEN / 2
    # The silver shell, 0.16 m thick, smooth-shaded over the curve.
    tmp = lib.bmesh.new()
    rows = []
    for grow in (0.0, -0.16):
        for x in (-half + 0.12, half - 0.12):
            rows.append([tmp.verts.new((x, *_vault_point(k / n, grow)[:2])) for k in range(n + 1)])
    out_w, out_e, in_w, in_e = rows
    for k in range(n):
        tmp.faces.new([out_w[k], out_w[k + 1], out_e[k + 1], out_e[k]])
        tmp.faces.new([in_w[k + 1], in_w[k], in_e[k], in_e[k + 1]])
        tmp.faces.new([out_w[k + 1], out_w[k], in_w[k], in_w[k + 1]])
        tmp.faces.new([out_e[k], out_e[k + 1], in_e[k + 1], in_e[k]])
    for k in (0, n):
        tmp.faces.new([out_w[k], out_e[k], in_e[k], in_w[k]])
    lib.bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    m._merge(tmp, "steel_light", None, (0, 0, 0))
    # Standing seams along the length every metre of the curve, broken by a
    # glazed skylight strip along the crown.
    fine = [_vault_point(k / 400)[:2] for k in range(401)]
    arc = [0.0]
    for a, b in zip(fine, fine[1:]):
        arc.append(arc[-1] + math.dist(a, b))
    total = arc[-1]
    seams = int(total // 1.0)
    for j in range(1, seams):
        s = total * j / seams
        if abs(s - total / 2) < 1.5:
            continue
        k = next(i for i, v in enumerate(arc) if v >= s)
        y, z, (ny, nz) = _vault_point(k / 400, 0.035)
        m.box((VAULT_LEN - 0.3, 0.05, 0.09), (0, y, z), "steel", rot=lib.rotx(math.degrees(math.atan2(-ny, nz))))
    # The skylight: glass over the crown between steel curbs, barred every 2 m.
    for side in (-1, 1):
        y, z, (ny, nz) = _vault_point(0.5 + side * 0.066, 0.07)
        m.box((VAULT_LEN - 3.2, 0.14, 0.18), (0, y, z), "steel_dark", rot=lib.rotx(math.degrees(math.atan2(-ny, nz))))
    glass = [_vault_point(0.5 + 0.066 * (i / 3 - 1), 0.06)[:2] for i in range(7)]
    glass = [(y, z) for y, z in glass] + [(y, z - 0.03) for y, z in reversed(glass)]
    m.prism(glass, VAULT_LEN - 3.3, (0, 0, 0), "glass_light", axis="x")
    for k in range(9):
        x = -half + 1.6 + (VAULT_LEN - 3.2) * k / 8
        pts = [_vault_point(0.5 + 0.066 * (i / 3 - 1), 0.1)[:2] for i in range(7)]
        for a, b in zip(pts, pts[1:]):
            m.beam((x, a[0], a[1]), (x, b[0], b[1]), 0.07, "frame")
    # Gutters and fascias along both eaves.
    for side in (-1, 1):
        y, z, _ = _vault_point(0.0 if side < 0 else 1.0, 0.0)
        m.box((VAULT_LEN - 0.1, 0.26, 0.2), (0, y + side * 0.1, 0.02), "steel_dark", bevel=0.02)
        m.box((VAULT_LEN - 0.1, 0.06, 0.08), (0, y + side * 0.2, 0.14), "steel_light")
    # West: the glazed gable in a stone arch rim, black mullions on a grid.
    xw = -half
    _vault_ring(m, 0.22, -0.42, xw + 0.2, 0.4, "warm_white")
    _vault_ring(m, -0.42, -0.52, xw + 0.3, 0.2, "stone")
    gl = _vault_curve(-0.45)
    m.slab(gl, [], 0.04, (xw + 0.42, 0, 0), "glass_light", axis="x")
    m.slab([(-8.5, 0.0), (8.5, 0.0), (8.5, 2.4), (-8.5, 2.4)], [], 0.03, (xw + 0.39, 0, 0), "window_glow", axis="x")
    fx = xw + 0.36
    cols = 12
    fine = _vault_curve(-0.45, 200)
    for k in range(1, cols):
        y = -VAULT_SPAN / 2 + VAULT_SPAN * k / cols
        top = next(z for yy, z in fine if yy >= y)
        m.box((0.08, 0.08, top), (fx, y, top / 2), "frame")
    for z, h in ((0.08, 0.16), (2.45, 0.08), (4.4, 0.08)):
        left = next(y for y, zz in fine if zz >= z)
        m.box((0.08, -2 * left, h), (fx, 0, z), "frame")
    pts = _vault_curve(-0.47, 24)
    for a, b in zip(pts[1:], pts[2:-1]):
        m.beam((fx, a[0], a[1]), (fx, b[0], b[1]), 0.09, "frame")
    # East: a plain cream lunette in the same rim.
    xe = half
    _vault_ring(m, 0.22, -0.42, xe - 0.2, 0.4, "warm_white")
    m.slab(_vault_curve(-0.3), [], 0.3, (xe - 0.35, 0, 0), "cream", axis="x")
    m.box((0.14, 17.2, 0.3), (xe - 0.16, 0, 0.15), "stone", bevel=0.02)
    lib.smooth(m.build("vault", r))


# ---- Blocks: shared helpers ----

def _merge_xform(m, tmp, degrees, offset):
    """Copies `tmp` (a Mesh built in a face's frame) into `m`, turned about
    Z and moved to `offset` (x, y)."""
    rot = lib.rotz(degrees)
    push = lib.Vector((offset[0], offset[1], 0.0))
    for f in tmp.bm.faces:
        verts = [m.bm.verts.new(rot @ v.co + push) for v in f.verts]
        try:
            nf = m.bm.faces.new(verts)
            nf.material_index = m.slot(tmp.mats[f.material_index])
        except ValueError:
            pass
    tmp.bm.free()


def _faces(w, d):
    """The four faces of a w x d footprint: (name, length, turn, offset);
    a face's frame has its outer face on y = 0 looking +y."""
    return (("front", w, 0, (0, d / 2)), ("back", w, 180, (0, -d / 2)),
            ("east", d, -90, (w / 2, 0)), ("west", d, 90, (-w / 2, 0)))


def _clump(m, at, radius, seed, scale=(1.0, 1.0, 0.85), mat="leaf", cap="leaf_light", cut=None):
    """A puffy leaf clump as the sheets draw one: a lumpy ball, flat
    underneath, its sunlit top in `cap`. `cut` drops the faces below that
    fraction of the radius (a shrub heaped on soil)."""
    tmp = lib.bmesh.new()
    lib.bmesh.ops.create_icosphere(tmp, subdivisions=2, radius=radius)
    if cut is not None:
        lib.bmesh.ops.delete(tmp, geom=[v for v in tmp.verts if v.co.z < -cut * radius], context="VERTS")
    rng = random.Random(seed)
    for v in tmp.verts:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        v.co += lib.Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.1
        v.co.z = max(v.co.z, -radius * scale[2] * 0.5)
    tmp.normal_update()
    top, side = m.slot(cap), m.slot(mat)
    for f in tmp.faces:
        f.material_index = top if f.normal.z > 0.55 else side
    m._merge_indexed(tmp, None, at)


def _tree(g, at, height, radius, seed, lean=(0.0, 0.0)):
    """A small terrace tree: a slim trunk under a crown of three clumps,
    the crown shifted by `lean`."""
    x, y, z = at
    g.cylinder(0.08, height * 0.62, (x, y, z + height * 0.31), "trunk", 6, radius_top=0.05, cap=False)
    x, y = x + lean[0], y + lean[1]
    rng = random.Random(seed)
    a = rng.uniform(0, 2 * math.pi)
    for k in range(2):
        b = a + math.pi * k
        _clump(g, (x + math.cos(b) * radius * 0.45, y + math.sin(b) * radius * 0.45, z + height - radius * 0.6),
               radius * 0.72, seed * 7 + k, mat=("leaf_dark", "leaf")[k], cap="leaf_light")
    _clump(g, (x, y, z + height - radius * 0.2), radius * 0.66, seed * 7 + 5, mat="leaf", cap="leaf_sun")


# ---- Towers ----

TOWER = 11.36
FLOOR = 3.2
LOBBY = 4.0


def _tower_tier(m, x0, x1, y0, y1, z0, floors, lobby=False, bay=1.8):
    """A glazed tier over [x0, x1] x [y0, y1]: pale glass behind white
    mullions, a concrete slab edge at every floor, concrete corners. A lobby
    tier's ground floor is set back behind concrete piers. Returns its roof
    height."""
    w, d = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    heights = ([LOBBY] if lobby else []) + [FLOOR] * floors
    top = z0 + sum(heights)
    zg = z0 + (LOBBY if lobby else 0.0)
    zt = top - 0.2
    m.box((w - 0.36, d - 0.36, zt - zg), (cx, cy, (zg + zt) / 2), "glass_tower")
    z = z0
    for k, h in enumerate(heights):
        if not (lobby and k == 0):
            m.box((w, d, 0.32), (cx, cy, z + 0.16), "concrete", bevel=0.03)
        z += h
    m.box((w + 0.04, d + 0.04, 0.4), (cx, cy, top - 0.2), "concrete", bevel=0.03)
    for (ax, ay), (sx, sy) in (((x0, y0), (1, 1)), ((x1, y0), (-1, 1)), ((x1, y1), (-1, -1)), ((x0, y1), (1, -1))):
        m.box((0.42, 0.42, zt - zg), (ax + sx * 0.23, ay + sy * 0.23, (zg + zt) / 2), "concrete")
    for _, length, turn, off in _faces(w, d):
        t = Mesh()
        n = max(2, round((length - 0.5) / bay))
        for k in range(1, n):
            x = -length / 2 + 0.25 + (length - 0.5) * k / n
            t.box((0.1, 0.14, zt - zg), (x, -0.12, (zg + zt) / 2), "warm_white")
        _merge_xform(m, t, turn, (cx + off[0], cy + off[1]))
    if lobby:
        m.box((w - 1.2, d - 1.2, LOBBY), (cx, cy, z0 + LOBBY / 2), "glass")
        for _, length, turn, off in _faces(w, d):
            t = Mesh()
            n = max(2, round(length / 2.8))
            for k in range(1, n):
                t.box((0.36, 0.36, LOBBY), (-length / 2 + length * k / n, -0.26, z0 + LOBBY / 2), "concrete")
            for k in range(n):
                x = -length / 2 + length * (k + 0.5) / n
                t.box((0.06, 0.08, LOBBY - 0.4), (x, -0.62, z0 + LOBBY / 2 - 0.1), "frame")
            t.box((length - 1.0, 0.08, 0.1), (0, -0.62, z0 + 2.9), "frame")
            _merge_xform(m, t, turn, (cx + off[0], cy + off[1]))
    return top


def _planter(m, g, a, b, z, seed, inward, width=0.8, trees=(), spacing=1.7, tree_h=2.6):
    """A concrete planter from a to b along its long side, heaped with
    shrubs, and small trees at the fractions `trees` of its length, their
    crowns leaning `inward` (a unit vector) over the terrace."""
    (ax, ay), (bx, by) = a, b
    length = math.dist(a, b)
    ux, uy = (bx - ax) / length, (by - ay) / length
    c = ((ax + bx) / 2, (ay + by) / 2)
    size = (abs(bx - ax) + (width if abs(ux) < 0.5 else 0), abs(by - ay) + (width if abs(uy) < 0.5 else 0))
    m.box((size[0], size[1], 0.75), (c[0], c[1], z + 0.375), "concrete")
    m.box((size[0] - 0.12, size[1] - 0.12, 0.04), (c[0], c[1], z + 0.75), "soil")
    rng = random.Random(seed)
    n = max(1, round(length / spacing))
    for k in range(n):
        s = (k + 0.5) / n * length
        if any(abs(s - f * length) < 0.7 for f in trees):
            continue
        rad = rng.uniform(0.5, 0.62)
        _clump(g, (ax + ux * s, ay + uy * s, z + 0.76), rad, seed * 31 + k, scale=(1.1, 1.1, 1.0),
               mat=rng.choice(("leaf", "leaf_dark", "leaf")), cap=rng.choice(("leaf_light", "leaf_sun")), cut=0.0)
    for k, f in enumerate(trees):
        rad = rng.uniform(0.95, 1.1)
        _tree(g, (ax + ux * f * length, ay + uy * f * length, z + 0.75), tree_h + rng.uniform(-0.2, 0.3), rad,
              seed * 13 + k, lean=(inward[0] * 0.45, inward[1] * 0.45))


_EDGE = {"s": (0, 1), "e": (-1, 0), "n": (0, -1), "w": (1, 0)}


def _terrace(m, g, outer, z, seed, edges=("s", "e", "n", "w"), trees=(), tree_h=2.6, lawn=True):
    """A planted setback on the lower tier's roof `outer` (x0, x1, y0, y1):
    a lawn, and planters along its exposed `edges` for a parapet, with
    trees at the fractions `trees` of every other edge."""
    x0, x1, y0, y1 = outer
    ends = {"s": ((x0, y0), (x1, y0)), "e": ((x1, y0), (x1, y1)), "n": ((x1, y1), (x0, y1)), "w": ((x0, y1), (x0, y0))}
    order = "senw"
    if lawn:
        m.box((x1 - x0 - 0.2, y1 - y0 - 0.2, 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, z + 0.03), "grass")
    for k, e in enumerate(edges):
        (ax, ay), (bx, by) = ends[e]
        nx, ny = _EDGE[e]
        length = math.dist((ax, ay), (bx, by))
        ux, uy = (bx - ax) / length, (by - ay) / length
        start = 0.84 if order[(order.index(e) - 1) % 4] in edges else 0.02
        a = (ax + nx * 0.42 + ux * start, ay + ny * 0.42 + uy * start)
        b = (bx + nx * 0.42 - ux * 0.02, by + ny * 0.42 - uy * 0.02)
        _planter(m, g, a, b, z, seed + k, (nx, ny), trees=trees if k % 2 == 0 else (), tree_h=tree_h)


def _tower_door(m, y, z=0.0):
    """Glazed doors lit warm under a white canopy, on the front at y."""
    m.box((3.4, 1.2, 0.16), (0, y - 0.5, z + 3.2), "warm_white", bevel=0.03)
    m.box((2.4, 0.06, 2.7), (0, y - 0.6, z + 1.35), "window_glow")
    for x in (-1.2, -0.4, 0.4, 1.2):
        m.box((0.08, 0.1, 2.7), (x, y - 0.56, z + 1.35), "frame")


def tower_a():
    """Four floors over a lobby, then two, then one, each stepping back to a
    planted terrace; a roof garden round a solar array on top."""
    r = lib.root("tower_a")
    m, g = Mesh(), Mesh()
    h, s2, s3 = TOWER / 2, 4.1, 2.8
    t1 = _tower_tier(m, -h, h, -h, h, 0.0, 3, lobby=True)
    t2 = _tower_tier(m, -s2, s2, -s2, s2, t1, 2)
    t3 = _tower_tier(m, -s3, s3, -s3, s3, t2, 1)
    _terrace(m, g, (-h, h, -h, h), t1, 3, trees=(0.12, 0.88))
    _terrace(m, g, (-s2, s2, -s2, s2), t2, 7)
    _terrace(m, g, (-s3, s3, -s3, s3), t3, 17, trees=(0.3,), tree_h=2.1)
    for k in range(2):
        y = -0.55 + k * 1.2
        m.box((2.2, 1.0, 0.06), (0.35, y, t3 + 0.5), "glass", rot=lib.rotx(-20))
        m.box((2.2, 0.08, 0.5), (0.35, y + 0.45, t3 + 0.3), "steel_dark")
    m.box((1.2, 1.1, 1.1), (-1.25, 0.1, t3 + 0.55), "concrete", bevel=0.03)
    _tower_door(m, h)
    m.build("tower", r)
    lib.smooth(g.build("garden", r), 60)


def tower_b():
    """Two floors over a lobby, then a tier set back from the front (+y),
    then a crown set back from the east too: terraces cascading down to
    the street."""
    r = lib.root("tower_b")
    m, g = Mesh(), Mesh()
    h = TOWER / 2
    yb, xb = h - 3.8, h - 4.2
    t1 = _tower_tier(m, -h, h, -h, h, 0.0, 2, lobby=True)
    t2 = _tower_tier(m, -h, h, -h, yb, t1, 2)
    t3 = _tower_tier(m, -h, xb, -h, yb - 2.0, t2, 1)
    _terrace(m, g, (-h, h, yb, h), t1, 5, edges=("e", "n", "w"), trees=(0.5,))
    _terrace(m, g, (xb, h, -h, yb), t2, 9, edges=("s", "e", "n"))
    _terrace(m, g, (-h, xb, yb - 2.0, yb), t2, 11, edges=("n",), trees=(0.3,))
    _terrace(m, g, (-h, xb, -h, yb - 2.0), t3, 13)
    _tower_door(m, h)
    m.build("tower", r)
    lib.smooth(g.build("garden", r), 60)

# ---- Houses and the shop ----

HOUSE_W, HOUSE_D = 5.8, 7.6
HOUSE_T = 0.22
PLINTH = 0.35
# Storey floors and the wall top of the three-storey houses.
STOREYS = (PLINTH, 2.6, 4.85)
EAVES = 7.1


def _window(t, x, z0, z1, width, bars=True):
    """A window on a face's frame (outer face on y = 0; its hole already cut
    in the wall): glass set back in a white reveal, glazing bars, a white
    head and a stone sill."""
    zc = (z0 + z1) / 2
    y = -HOUSE_T + 0.05
    t.box((width, 0.03, z1 - z0), (x, y, zc), "glass")
    if bars:
        t.box((0.05, 0.05, z1 - z0), (x, y + 0.03, zc), "warm_white")
        t.box((width, 0.05, 0.05), (x, y + 0.03, z0 + (z1 - z0) * 0.62), "warm_white")
    t.box((width + 0.26, 0.08, 0.13), (x, 0.04, z1 + 0.065), "warm_white")
    t.box((width + 0.3, 0.2, 0.08), (x, 0.08, z0 - 0.04), "stone")


def _french(t, x, z0, z1, width):
    """A glazed door onto a balcony: two leaves, a transom light."""
    y = -HOUSE_T + 0.05
    t.box((width, 0.03, z1 - z0), (x, y, (z0 + z1) / 2), "glass")
    for dx in (-width / 2 + 0.04, 0.0, width / 2 - 0.04):
        t.box((0.07, 0.06, z1 - z0), (x + dx, y + 0.03, (z0 + z1) / 2), "warm_white")
    t.box((width, 0.06, 0.07), (x, y + 0.03, z1 - 0.45), "warm_white")
    t.box((width + 0.26, 0.08, 0.13), (x, 0.04, z1 + 0.065), "warm_white")


def _balcony(t, x, z, width, mat="stone"):
    """A small balcony at floor height z: a slab on two brackets and a black
    railing of slim balusters."""
    t.box((width, 0.8, 0.14), (x, 0.4, z - 0.07), mat, bevel=0.02)
    for sx in (-1, 1):
        t.box((0.1, 0.5, 0.22), (x + sx * (width / 2 - 0.22), 0.25, z - 0.25), mat)
    t.box((width, 0.05, 0.05), (x, 0.77, z + 0.95), "frame")
    for sx in (-1, 1):
        t.box((0.05, 0.75, 0.05), (x + sx * (width / 2 - 0.03), 0.4, z + 0.95), "frame")
        t.box((0.04, 0.04, 0.95), (x + sx * (width / 2 - 0.03), 0.77, z + 0.475), "frame")
    n = max(3, round(width / 0.3))
    for k in range(1, n):
        t.box((0.03, 0.03, 0.9), (x - width / 2 + width * k / n, 0.77, z + 0.45), "frame")
    t.box((width, 0.04, 0.04), (x, 0.77, z + 0.1), "frame")


def _front_door(t, x, colour, width=1.0, height=2.2):
    """A panelled front door with a lit fanlight, white architraves, a hood
    on brackets and a stone step."""
    z = PLINTH
    y = -HOUSE_T + 0.08
    t.box((width, 0.05, height), (x, y, z + height / 2), colour)
    for dz in (0.55, 1.35):
        t.box((width * 0.7, 0.03, 0.55), (x, y + 0.035, z + dz), colour, bevel=0.01)
    t.box((width * 0.8, 0.03, 0.3), (x, y + 0.03, z + height - 0.25), "window_glow")
    t.box((0.05, 0.05, 0.16), (x + width * 0.36, y + 0.06, z + 1.0), "brass")
    for sx in (-1, 1):
        t.box((0.12, 0.07, height + 0.12), (x + sx * (width / 2 + 0.06), 0.035, z + (height + 0.12) / 2), "warm_white")
    t.box((width + 0.6, 0.62, 0.1), (x, 0.31, z + height + 0.3), "warm_white", bevel=0.02)
    for sx in (-1, 1):
        xb = x + sx * (width / 2 + 0.12)
        t.beam((xb, 0.0, z + height + 0.05), (xb, 0.5, z + height + 0.26), 0.06, "warm_white")
    t.box((width + 0.5, 0.6, 0.16), (x, 0.3, z - 0.08), "stone", bevel=0.02)


def _wall(t, length, top, holes, mat, base=PLINTH):
    """A rendered wall in a face's frame from the plinth to `top`, cut by
    `holes`, its reveals white."""
    t.slab([(-length / 2, base), (length / 2, base), (length / 2, top), (-length / 2, top)], holes, HOUSE_T,
           (0, -HOUSE_T / 2, 0), mat, reveal_mat="warm_white")


def _hip_roof(m, w, d, z, rise, over):
    """A terracotta hipped roof over w x d from z, eaves `over` out, with a
    white soffit board, and ridge and hip rolls."""
    hw, hd = w / 2 + over, d / 2 + over
    inset = min(hw, hd)
    tmp = lib.bmesh.new()
    c = [tmp.verts.new(p) for p in ((-hw, -hd, z), (hw, -hd, z), (hw, hd, z), (-hw, hd, z))]
    if hd >= hw:
        ra, rb = (0, -hd + inset, z + rise), (0, hd - inset, z + rise)
    else:
        ra, rb = (-hw + inset, 0, z + rise), (hw - inset, 0, z + rise)
    a, b = tmp.verts.new(ra), tmp.verts.new(rb)
    if hd >= hw:
        faces = ([c[1], c[2], b, a], [c[3], c[0], a, b], [c[0], c[1], a], [c[2], c[3], b])
    else:
        faces = ([c[0], c[1], b, a], [c[2], c[3], a, b], [c[1], c[2], b], [c[3], c[0], a])
    for f in faces:
        tmp.faces.new(f)
    tmp.faces.new(list(reversed(c)))
    lib.bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    m._merge(tmp, "terracotta", None, (0, 0, 0))
    m.box((2 * hw, 2 * hd, 0.12), (0, 0, z - 0.06), "warm_white")
    m.beam(ra, rb, 0.14, "terracotta_dark")
    for cx, cy in ((-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)):
        near = ra if (cy < 0 if hd >= hw else cx < 0) else rb
        m.beam((cx, cy, z + 0.03), near, 0.1, "terracotta_dark")


def _gable_roof(m, span, length, z, rise, over, along):
    """A terracotta gabled roof `span` across and `length` long from z, its
    ridge along `along` ("x" or "y"), eaves and verges `over` out."""
    hs = span / 2 + over
    k = 0.16
    prof = [(-hs, z - 0.08), (0, z + rise), (hs, z - 0.08), (hs, z + k - 0.08), (0, z + rise + k), (-hs, z + k - 0.08)]
    m.prism(prof, length + 2 * over, (0, 0, 0), "terracotta", axis=along)
    end = length / 2 + over
    top = z + rise + k
    if along == "x":
        m.beam((-end, 0, top), (end, 0, top), 0.15, "terracotta_dark")
    else:
        m.beam((0, -end, top), (0, end, top), 0.15, "terracotta_dark")


def _gable_end(t, span, z, rise, mat):
    """The rendered triangle closing a gable, in a face's frame."""
    t.slab([(-span / 2, z), (span / 2, z), (0, z + rise + 0.04)], [], HOUSE_T, (0, -HOUSE_T / 2, 0), mat)


def _house(name, render, door_colour, roof, front, sides=1, seed=0):
    """A three-storey town house: rendered walls on a stone plinth, framed
    windows, the front's door and balconies from `front` (a list per storey
    of ("w" window | "f" French door with a balcony | "d" door | "b" French
    door with a wide balcony, x)), a white cornice and a terracotta roof."""
    r = lib.root(name)
    m, g = Mesh(), Mesh()
    w, d = HOUSE_W, HOUSE_D
    m.box((w + 0.1, d + 0.1, PLINTH), (0, 0, PLINTH / 2), "stone", bevel=0.02)
    m.box((w + 0.24, d + 0.24, 0.24), (0, 0, EAVES - 0.2), "warm_white", bevel=0.02)
    rise = {"hip": 1.05, "gable_x": 1.05, "gable_y": 1.25}[roof]
    for face, length, turn, off in _faces(w, d):
        t = Mesh()
        holes = []
        if face == "front":
            for storey, items in enumerate(front):
                z0 = STOREYS[storey]
                for kind, x in items:
                    if kind == "w":
                        holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                        _window(t, x, z0 + 0.75, z0 + 2.0, 0.9)
                    elif kind == "d":
                        holes.append(rect_hole(x - 0.5, x + 0.5, PLINTH, PLINTH + 2.2))
                        _front_door(t, x, door_colour)
                    else:
                        wide = kind == "b"
                        holes.append(rect_hole(x - 0.55, x + 0.55, z0 + 0.02, z0 + 2.05))
                        _french(t, x, z0 + 0.02, z0 + 2.05, 1.1)
                        _balcony(t, x, z0, 2.6 if wide else 1.7)
                        _flowers(g, x - (0.95 if wide else 0.55), d / 2 + 0.52, z0, seed + storey)
        else:
            span = length - 2 * HOUSE_T if face in ("east", "west") else length
            xs = [0.0] if face in ("east", "west") and sides == 1 else [-span / 4, span / 4]
            for z0 in STOREYS:
                for x in xs:
                    holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                    _window(t, x, z0 + 0.75, z0 + 2.0, 0.9)
        _wall(t, length - 2 * HOUSE_T if face in ("east", "west") else length, EAVES, holes, render)
        if (roof == "gable_x" and face in ("east", "west")) or (roof == "gable_y" and face in ("front", "back")):
            _gable_end(t, length, EAVES, rise, render)
        _merge_xform(m, t, turn, off)
    if roof == "hip":
        _hip_roof(m, w, d, EAVES, rise, 0.4)
    elif roof == "gable_x":
        _gable_roof(m, d, w, EAVES - 0.06, rise + 0.06, 0.4, "x")
    else:
        _gable_roof(m, w, d, EAVES - 0.06, rise + 0.06, 0.4, "y")
    m.build("house", r)
    lib.smooth(g.build("plants", r), 60)


def _flowers(g, x, y, z, seed):
    """A pot of flowers standing at (x, y, z)."""
    rng = random.Random(seed)
    g.cylinder(0.16, 0.3, (x, y, z + 0.15), "terracotta", 8, radius_top=0.2)
    _clump(g, (x, y, z + 0.32), 0.24, seed * 3 + 1, scale=(1.0, 1.0, 0.9), mat="leaf",
           cap=rng.choice(("flower_pink", "flower_white", "flower_yellow")), cut=0.0)


def house_a():
    _house("house_a", "render_peach", "indigo", "hip",
           [[("d", -1.45), ("w", 1.45)], [("w", -1.45), ("f", 1.45)], [("f", -1.45), ("w", 1.45)]], seed=1)


def house_b():
    _house("house_b", "render_sky", "wood", "gable_x",
           [[("w", -1.7), ("d", 0.0), ("w", 1.7)], [("w", -1.7), ("w", 0.0), ("w", 1.7)],
            [("w", -2.0), ("b", 0.0), ("w", 2.0)]], sides=2, seed=4)


def house_c():
    _house("house_c", "cream", "blue", "gable_y",
           [[("w", -1.6), ("d", 1.75)], [("w", -1.9), ("f", 0.0), ("w", 1.9)], [("w", -1.9), ("f", 0.0), ("w", 1.9)]],
           seed=7)


SHOP_W, SHOP_D = 4.6, 7.4
SHOP_FLOORS = (3.3, 5.55)
SHOP_EAVES = 7.8


def shop_a():
    """A shop: a glazed shopfront under a red-and-white striped awning and
    a fascia with its sign, two rendered floors above, a hipped roof."""
    r = lib.root("shop_a")
    m, g = Mesh(), Mesh()
    w, d = SHOP_W, SHOP_D
    m.box((w + 0.1, d + 0.1, 0.15), (0, 0, 0.075), "stone", bevel=0.02)
    m.box((w + 0.24, d + 0.24, 0.24), (0, 0, SHOP_EAVES - 0.2), "warm_white", bevel=0.02)
    for face, length, turn, off in _faces(w, d):
        t = Mesh()
        holes = []
        span = length - 2 * HOUSE_T if face in ("east", "west") else length
        xs = [-1.1, 1.1] if face in ("front", "back") else [-1.6, 1.6]
        for z0 in SHOP_FLOORS:
            for x in xs:
                holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                _window(t, x, z0 + 0.75, z0 + 2.0, 0.9)
        if face == "front":
            holes.append(rect_hole(-2.0, 2.0, 0.15, 2.85))
            _shopfront(t)
            for x in xs:
                t.box((1.0, 0.24, 0.2), (x, 0.12, SHOP_FLOORS[0] + 0.62), "wood")
        elif face == "back":
            holes.append(rect_hole(-0.5, 0.5, 0.15, 2.35))
            t.box((1.0, 0.05, 2.2), (0, -HOUSE_T + 0.08, 1.25), "wood_dark")
            for x in (-1.3, 1.3):
                holes.append(rect_hole(x - 0.45, x + 0.45, 1.0, 2.25))
                _window(t, x, 1.0, 2.25, 0.9)
        _wall(t, span, SHOP_EAVES, holes, "cream", base=0.15)
        _merge_xform(m, t, turn, off)
    for k, x in enumerate((-1.1, 1.1)):
        rng = random.Random(40 + k)
        for j in range(2):
            _clump(g, (x - 0.22 + j * 0.44, d / 2 + 0.14, SHOP_FLOORS[0] + 0.72), 0.2, 50 + 2 * k + j,
                   scale=(1.0, 0.8, 0.9), mat="leaf", cap=rng.choice(("flower_pink", "flower_yellow", "flower_white")),
                   cut=0.0)
    for x in (-2.55, 2.55):
        g.cylinder(0.24, 0.5, (x * 0.83, d / 2 + 0.45, 0.25), "terracotta", 8, radius_top=0.3)
        _clump(g, (x * 0.83, d / 2 + 0.45, 0.55), 0.38, 60 + int(x), scale=(1.0, 1.0, 1.1), mat="leaf_dark",
               cap="leaf_light", cut=0.0)
    _hip_roof(m, w, d, SHOP_EAVES, 0.66, 0.22)
    m.build("shop", r)
    lib.smooth(g.build("plants", r), 60)


def _shopfront(t):
    """The shopfront in the front face's frame: an indigo frame round a
    display window and a glazed door, a fascia with its sign, and a striped
    awning over the pavement."""
    y = -HOUSE_T + 0.06
    t.box((4.0, 0.05, 0.55), (0, y + 0.02, 0.42), "indigo")
    t.box((2.75, 0.03, 2.1), (-0.62, y, 1.75), "glass")
    t.box((0.95, 0.03, 2.5), (1.5, y, 1.4), "glass")
    for x, zc, h in ((-1.97, 1.5, 2.7), (0.98, 1.5, 2.7), (1.97, 1.5, 2.7), (-0.62, 1.75, 2.1)):
        t.box((0.1 if abs(x) > 0.7 else 0.05, 0.08, h), (x, y + 0.04, zc), "indigo")
    t.box((4.0, 0.08, 0.08), (0, y + 0.04, 2.3), "indigo")
    t.box((0.05, 0.06, 0.5), (1.15, y + 0.08, 1.3), "brass")
    t.box((4.0, 0.08, 0.1), (0, y + 0.04, 2.8), "indigo")
    t.box((4.7, 0.16, 0.5), (0, 0.08, 3.12), "indigo", bevel=0.02)
    t.box((2.4, 0.04, 0.3), (0, 0.18, 3.12), "canvas")
    t.cylinder(0.13, 0.05, (-1.5, 0.18, 3.12), "yellow", 12, rot=lib.rotx(90))
    # The awning: stripes sloping out from the wall and a scalloped valance.
    stripes, reach, drop = 9, 1.35, 0.5
    slope = math.degrees(math.atan2(drop, reach))
    width = 4.4
    for k in range(stripes):
        x = -width / 2 + width * (k + 0.5) / stripes
        mat = "canvas_stripe" if k % 2 == 0 else "canvas"
        t.box((width / stripes, math.hypot(reach, drop), 0.04), (x, reach / 2, 2.87 - drop / 2), mat,
              rot=lib.rotx(-slope))
        t.prism([(-width / stripes / 2, 0.0), (width / stripes / 2, 0.0), (width / stripes / 2, -0.22),
                 (0.0, -0.3), (-width / stripes / 2, -0.22)], 0.03, (x, reach, 2.87 - drop), mat, axis="y")
    for x in (-width / 2, width / 2):
        t.beam((x, 0.0, 2.9), (x, reach, 2.87 - drop), 0.04, "frame")


def tram_shelter():
    """A tram stop: a slim steel frame, a glass back and canopy, a bench, a
    timetable and a lamp strip under the canopy's front edge; open to +Y."""
    r = lib.root("tram_shelter")
    m = Mesh()
    w, h = 4.4, 2.62
    # Where people walk the stop is laid out to the tram-shelter kind's
    # footprint: its back 0.75 m behind the point (the posts' back faces),
    # the bench to 0.15 m, the end screen's post to 0.40 m; the front is
    # open to the stand.
    yb, yf = -0.69, 1.02
    m.box((w + 0.1, 1.9, 0.08), (0, 0.12, 0.04), "concrete", bevel=0.01)
    for x in (-w / 2 + 0.12, 0.0, w / 2 - 0.12):
        m.box((0.1, 0.12, h - 0.08), (x, yb, 0.08 + (h - 0.08) / 2), "steel_dark")
        m.beam((x, yb - 0.3, h + 0.05), (x, yf, h + 0.16), 0.1, "steel_dark", depth=0.16)
    roof = [(yb - 0.35, h + 0.12), (yf + 0.05, h + 0.23), (yf + 0.05, h + 0.27), (yb - 0.35, h + 0.16)]
    m.prism(roof, w + 0.3, (0, 0, 0), "glass_light", axis="x")
    m.box((w + 0.35, 0.12, 0.14), (0, yf + 0.06, h + 0.2), "steel", bevel=0.01)
    m.box((w + 0.35, 0.12, 0.1), (0, yb - 0.35, h + 0.12), "steel", bevel=0.01)
    m.box((w - 0.3, 0.06, 0.05), (0, yf - 0.02, h + 0.1), "lamp_glow")
    # The glass back and one end screen.
    m.box((w - 0.3, 0.03, 1.95), (0, yb, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((w - 0.2, 0.07, 0.06), (0, yb, z), "steel_dark")
    m.box((0.03, 1.0, 1.95), (-w / 2 + 0.12, yb + 0.55, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((0.07, 1.05, 0.06), (-w / 2 + 0.12, yb + 0.55, z), "steel_dark")
    m.box((0.06, 0.06, 2.0), (-w / 2 + 0.12, yb + 1.06, 1.28), "steel_dark")
    # A timber bench on steel legs along the back.
    m.box((2.36, 0.42, 0.07), (-0.55, yb + 0.33, 0.47), "wood_light", bevel=0.015)
    m.box((2.36, 0.06, 0.3), (-0.55, yb + 0.1, 0.78), "wood_light", bevel=0.015)
    for x in (-1.6, 0.5):
        m.box((0.06, 0.36, 0.44), (x, yb + 0.33, 0.3), "steel_dark")
    # The timetable: a lit panel in a blue frame at the open end.
    m.box((0.7, 0.1, 1.35), (1.55, yb + 0.1, 1.28), "blue", bevel=0.02)
    m.box((0.56, 0.03, 1.1), (1.55, yb + 0.16, 1.3), "lamp_glow")
    for k in range(5):
        m.box((0.44, 0.02, 0.05), (1.55, yb + 0.18, 1.7 - k * 0.18), "tram_dark")
    m.box((0.5, 0.02, 0.12), (1.55, yb + 0.18, 1.82), "tram_coral")
    # The stop's roundel on the canopy's front edge.
    m.cylinder(0.19, 0.04, (w / 2 - 0.45, yf + 0.14, h + 0.16), "tram_coral", 16, rot=lib.rotx(90))
    m.box((0.2, 0.02, 0.05), (w / 2 - 0.45, yf + 0.165, h + 0.24), "warm_white")
    m.box((0.05, 0.02, 0.2), (w / 2 - 0.45, yf + 0.165, h + 0.155), "warm_white")
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
    "lib_vault": lib_vault,
    "lib_banner": lib_banner,
    "tower_a": tower_a,
    "tower_b": tower_b,
    "house_a": house_a,
    "house_b": house_b,
    "house_c": house_c,
    "shop_a": shop_a,
    "tram_shelter": tram_shelter,
}
