"""Building modules for the neon noir kit, after the 10 sheets: the
workshop's dark metal sawtooth bays over tall black-framed glazing lit warm
from inside; the library's stone arcade of tall lit windows under a flat
roof carrying a glowing drum and a dark ribbed glass dome; dark glass
towers stepping back to planted terraces, their windows a mix of lit and
dark, magenta neon at their crowns; slate and charcoal houses with warm
windows; a shop with an abstract neon glyph sign.

Conventions match the anime and low-poly kits so the townscape assembles
every kit the same way (Blender Z-up; a wall module spans x in [-W/2, W/2]
with its outer face on y = 0 facing +Y, Godot's forward -Z, its body behind
at y < 0; z = 0 is the ground):
    hall_wall, hall_window_wall                   4 m bays, 5.2 m high
    hall_door_wall     a door bay (DOOR_W): the opening clear, a lintel
    hall_door_leaves   one side's doors folded into the reveal
    hall_corner                                   a dark steel pier
    hall_sawtooth_bay                             4 m x 4 m of roof over
                                                  z = 0 at the wall top
    hall_sawtooth_gable                           closes a tooth's end
    lib_wall_arch      a 2 m bay, 8 m high: a tall two-storey lit window
    lib_column         the pilaster at every bay joint and corner
    lib_entrance       a door bay (DOOR_W): a lit portal over the open
                       doorway, a canopy, a low step
    lib_door_leaves    one side's doors folded into the reveal
    lib_roof           the roof over the 20 m x 18 m library, z = 0 at the
                       wall top, origin at the footprint's centre: a flat
                       deck, a glowing drum, a dark glass dome on a lit ring
    lib_banner         a banner hanging below its bracket (z = 0)
Blocks (origin at the footprint's centre on the ground, fronts facing +Y):
    tower_a, tower_b   dark glass towers stepping back to planted terraces
    house_a/b/c        three-storey flat-roofed slate town houses
    shop_a             a lit shopfront under a neon glyph sign
    tram_shelter       a dark steel-and-glass shelter, open to +Y

Neon is kept in separate objects named `neon`, `neon_2` (see NEON), so the
pack can switch it by time of day; lit glazing is `window_glow`, lamps and
strip lights `lamp_glow`.
"""
import importlib.util
import math
import random
from pathlib import Path

import lib
from lib import Mesh, rect_hole

# The anime kit's face-frame and foliage helpers, built on this kit's lib.
_spec = importlib.util.spec_from_file_location("anime_buildings",
                                               Path(__file__).resolve().parents[1] / "anime" / "buildings.py")
anime = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(anime)
_merge_xform, _faces, _clump, _tree = anime._merge_xform, anime._faces, anime._clump, anime._tree

# Neon node -> colour, per asset, for the pack.
NEON = {"tower_a": {"neon": "neon_magenta"}, "tower_b": {"neon": "neon_magenta"},
        "shop_a": {"neon": "neon_cyan", "neon_2": "neon_magenta"}}


# ---- Shared helpers ----

def _quad(m, a, b, c, d, mat, want=None):
    """A single quad a-b-c-d, flipped if its normal points away from `want`."""
    pts = [lib.Vector(p) for p in (a, b, c, d)]
    if want is not None:
        n = (pts[1] - pts[0]).cross(pts[2] - pts[1])
        if n.dot(lib.Vector(want)) < 0:
            pts.reverse()
    m._faces([tuple(p) for p in pts], [(0, 1, 2, 3)], mat)


def _ngon(m, pts, mat, want):
    """One flat polygon through `pts`, facing along `want`."""
    pts = [lib.Vector(p) for p in pts]
    if (pts[1] - pts[0]).cross(pts[2] - pts[1]).dot(lib.Vector(want)) < 0:
        pts.reverse()
    m._faces([tuple(p) for p in pts], [tuple(range(len(pts)))], mat)


def _pane(t, x0, x1, z0, z1, y, mat):
    """A flat pane in a face's frame on y, facing +y."""
    _quad(t, (x0, y, z0), (x0, y, z1), (x1, y, z1), (x1, y, z0), mat, (0, 1, 0))


def _strip(m, pts, normals, sides, width, height, mat):
    """A raised rib along the polyline `pts`: a U of two sides and a top,
    `width` across (along `sides`) and `height` out (along `normals`)."""
    rows = []
    for p, n, s in zip(pts, normals, sides):
        p, n, s = lib.Vector(p), lib.Vector(n), lib.Vector(s)
        bl, br = p - s * width / 2, p + s * width / 2
        rows.append((bl, bl + n * height, br + n * height, br, n, s))
    for (a0, a1, a2, a3, n, s), (b0, b1, b2, b3, _, _) in zip(rows, rows[1:]):
        _quad(m, a0, b0, b1, a1, mat, -s)
        _quad(m, a1, b1, b2, a2, mat, n)
        _quad(m, a2, b2, b3, a3, mat, s)


def _lit(rng, p):
    return rng.random() < p


# ---- Workshop ----

HALL_BAY = 4.0
HALL_H = 5.2
WALL_T = 0.3
# A door bay: the door's 2 m opening and a reveal either side for its
# folded leaves; nothing stands in the opening in the walking band.
DOOR_REVEAL = 0.3
DOOR_W = 2.0 + 2 * DOOR_REVEAL
DOOR_H = 3.1


def _glazing(m, x0, x1, z0, z1, cols, rows=(), depth=-0.17, pane="window_glow"):
    """Tall glazing lit from inside, set back to `depth` in a black steel
    frame, with `cols` lights and transoms at `rows`."""
    w, h = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.box((w, 0.03, h), (cx, depth, cz), pane)
    f = depth + 0.05
    for x in (x0 + 0.05, x1 - 0.05):
        m.box((0.1, 0.12, h), (x, f, cz), "frame")
    for z in (z0 + 0.05, z1 - 0.05):
        m.box((w, 0.12, 0.1), (cx, f, z), "frame")
    for k in range(1, cols):
        m.box((0.07, 0.1, h), (x0 + w * k / cols, f - 0.01, cz), "frame")
    for z in rows:
        m.box((w, 0.1, 0.07), (cx, f - 0.01, z), "frame")


def _pendants(m, x0, x1, z, depth=-0.17, n=2):
    """Pendant lamps hanging inside the glazing: dark shades on cords, a
    bright underside, just proud of the lit pane."""
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        m.box((0.02, 0.02, 0.5), (x, depth + 0.03, z + 0.25), "frame")
        m.box((0.36, 0.03, 0.14), (x, depth + 0.03, z - 0.05), "frame")
        m.box((0.3, 0.035, 0.05), (x, depth + 0.035, z - 0.14), "lamp_glow")


def _cladding(m, x0, x1, z0, z1, every=0.5):
    """Standing seams on the dark metal cladding between x0 and x1."""
    x = x0 + every / 2
    while x < x1 - 0.05:
        m.box((0.05, 0.04, z1 - z0), (x, 0.02, (z0 + z1) / 2), "slate_light")
        x += every


def _hall_base(m, w, top):
    """The wall's concrete plinth and steel coping."""
    m.box((w, WALL_T + 0.06, 0.4), (0, -WALL_T / 2 + 0.03, 0.2), "concrete", bevel=0.015)
    m.box((w + 0.02, WALL_T + 0.14, 0.22), (0, -WALL_T / 2 + 0.07, top - 0.11), "steel_dark", bevel=0.015)


def _hall_slab(m, holes, base=0.4):
    w = HALL_BAY
    m.slab([(-w / 2, base), (w / 2, base), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)],
           holes, WALL_T, (0, -WALL_T / 2, 0), "slate", reveal_mat="steel_dark")


def hall_wall():
    """A clad bay: dark standing-seam metal with a wide lit clerestory."""
    r = lib.root("hall_wall")
    m = Mesh()
    x0, x1, z0, z1 = -1.5, 1.5, 2.9, 4.6
    _hall_slab(m, [rect_hole(x0, x1, z0, z1)])
    _glazing(m, x0, x1, z0, z1, 3)
    _pendants(m, x0, x1, 4.1)
    _cladding(m, -HALL_BAY / 2, HALL_BAY / 2, 0.4, z0 - 0.08)
    for x in (-1.75, 1.75):
        m.box((0.05, 0.04, z1 - z0 + 0.16), (x, 0.02, (z0 + z1) / 2), "slate_light")
    m.box((x1 - x0 + 0.16, 0.26, 0.07), (0, 0.03, z0 - 0.035), "steel_dark")
    _hall_base(m, HALL_BAY, HALL_H)
    m.build("wall", r)


def hall_window_wall():
    """A glazed bay: floor-to-eaves glazing lit warm, four lights and a
    transom, pendants glowing inside."""
    r = lib.root("hall_window_wall")
    m = Mesh()
    x0, x1, z0, z1 = -1.72, 1.72, 0.5, 4.8
    _hall_slab(m, [rect_hole(x0, x1, z0, z1)])
    _glazing(m, x0, x1, z0, z1, 4, rows=(3.3,))
    _pendants(m, x0, x1, 4.15, n=2)
    # A workbench's dark silhouette across the lower lights.
    m.box((x1 - x0 - 0.3, 0.03, 0.08), (0, -0.14, 1.35), "frame")
    m.box((x1 - x0 + 0.16, 0.26, 0.07), (0, 0.03, z0 - 0.035), "steel_dark")
    _hall_base(m, HALL_BAY, HALL_H)
    m.build("wall", r)


def hall_door_wall():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): dark cladding over a black steel lintel and a lit transom, a
    steel canopy with a warm strip light, a threshold, a lamp. Nothing
    stands in the opening below the lintel; the doors fold into the reveals
    (hall_door_leaves)."""
    r = lib.root("hall_door_wall")
    m = Mesh()
    w = DOOR_W
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, HALL_H - 0.22), (-w / 2, HALL_H - 0.22)],
           [rect_hole(-1.05, 1.05, 3.45, 4.55)], WALL_T, (0, -WALL_T / 2, 0), "slate", reveal_mat="steel_dark")
    m.box((w, 0.34, 0.12), (0, 0.0, DOOR_H + 0.06), "frame")
    _glazing(m, -1.05, 1.05, 3.45, 4.55, 4)
    # A slim steel canopy, a warm strip under its front edge.
    m.box((3.2, 1.3, 0.12), (0, 0.55, 3.45), "steel_dark", bevel=0.01)
    m.box((3.0, 0.06, 0.04), (0, 1.1, 3.37), "lamp_glow")
    for x in (-1.5, 1.5):
        m.box((0.05, 1.25, 0.05), (x, 0.55, 3.72), "frame")
    m.box((w + 0.4, 0.9, 0.1), (0, 0.35, 0.05), "concrete", bevel=0.015)
    m.box((w + 0.02, WALL_T + 0.14, 0.22), (0, -WALL_T / 2 + 0.07, HALL_H - 0.11), "steel_dark", bevel=0.015)
    # A lamp over the door.
    m.box((0.06, 0.26, 0.06), (0, 0.13, 4.05), "frame")
    m.box((0.22, 0.22, 0.1), (0, 0.28, 4.0), "frame")
    m.box((0.18, 0.18, 0.08), (0, 0.28, 3.91), "lamp_glow")
    m.build("wall", r)


def hall_door_leaves():
    """One side's glazed doors, folded open into the reveal beside the
    opening: four black steel panels square to the wall, stacked across the
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
    m.box((0.7, 0.7, 0.42), (0, 0, 0.21), "concrete", bevel=0.02)
    m.box((0.58, 0.58, HALL_H - 0.42), (0, 0, 0.42 + (HALL_H - 0.42) / 2), "charcoal", bevel=0.015)
    for z in (1.5, 3.0, 4.5):
        m.box((0.62, 0.62, 0.05), (0, 0, z), "steel_dark")
    m.box((0.72, 0.72, 0.16), (0, 0, HALL_H + 0.04), "steel_dark", bevel=0.02)
    m.build("pier", r)


def hall_sawtooth_bay():
    """One 4 m x 4 m bay of sawtooth roof: a long navy standing-seam slope
    rising to +x, and a steep glazed face lit warm from inside."""
    r = lib.root("hall_sawtooth_bay")
    m = Mesh()
    w, d, h = HALL_BAY, HALL_BAY, 2.7
    x0, x1 = -w / 2 - 0.08, w / 2 + 0.08
    y0, y1 = -d / 2 - 0.02, d / 2 + 0.02
    m.prism([(x0, 0.0), (x1 - 0.5, h), (x1 - 0.2, h), (x1 - 0.2, 0.0)], y1 - y0, (0, 0, 0), "navy", axis="y")
    for k in range(9):
        y = y0 + 0.2 + k * (y1 - y0 - 0.4) / 8
        m.beam((x0 + 0.05, y, 0.05), (x1 - 0.5, y, h + 0.02), 0.04, "slate_light")
    # The steep north light: warm glazing between black mullions.
    m.box((0.06, y1 - y0 - 0.1, h - 0.3), (x1 - 0.17, 0, h / 2 + 0.05), "window_glow")
    for k in range(6):
        y = y0 + 0.05 + k * (y1 - y0 - 0.1) / 5
        m.box((0.08, 0.07, h - 0.2), (x1 - 0.14, y, h / 2 + 0.05), "frame")
    m.box((0.1, y1 - y0, 0.08), (x1 - 0.14, 0, h - 0.1), "frame")
    m.box((0.12, y1 - y0, 0.1), (x1 - 0.14, 0, 0.1), "frame")
    m.box((0.1, y1 - y0, 0.06), (x1 - 0.14, 0, h * 0.45), "frame")
    # Ridge cap and the valley gutter.
    m.box((0.36, y1 - y0 + 0.04, 0.1), (x1 - 0.35, 0, h + 0.03), "steel_dark", bevel=0.01)
    m.box((0.3, y1 - y0, 0.08), (x0 + 0.15, 0, 0.06), "steel_dark")
    m.build("roof", r)


def hall_sawtooth_gable():
    """A tooth's end, seen from both sides: dark cladding over a tall lit
    window under the high end, framed in black steel."""
    r = lib.root("hall_sawtooth_gable")
    m = Mesh()
    w, h, t = HALL_BAY, 2.4, 0.3
    xa, xb = -w / 2 - 0.05, w / 2 + 0.05
    xr = w / 2 - 0.4
    pts = [(xa, 0.0), (xr, h), (xb, h), (xb, 0.0)]

    def z_top(x):
        return h if x >= xr else (x - xa) * h / (xr - xa)

    g0, g1 = 0.35, 1.8
    hole = [(g0, 0.2), (g0, z_top(g0) - 0.28), (xr, h - 0.28), (g1, h - 0.28), (g1, 0.2)]
    m.slab(pts, [hole], t, (0, 0, 0), "slate", reveal_mat="steel_dark")
    for side in (-1, 1):
        y = side * (t / 2 + 0.01)
        # The lit glazing just inside each face: the roof tile's end stands
        # only 3 cm inside the gable's outer face.
        _ngon(m, [(x, side * 0.14, z) for x, z in hole], "window_glow", (0, side, 0))
        for x in (g0 + 0.47, g0 + 0.95):
            top = z_top(x) - 0.28
            m.box((0.06, 0.03, top - 0.2), (x, side * 0.15, 0.2 + (top - 0.2) / 2), "frame")
        m.box((g1 - g0, 0.03, 0.06), ((g0 + g1) / 2, side * 0.15, 0.9), "frame")
        # Seams on the cladding and a black rake along the slope.
        x = xa + 0.35
        while x < g0 - 0.1:
            top = z_top(x)
            m.box((0.05, 0.04, top - 0.05), (x, y, top / 2), "slate_light")
            x += 0.5
        m.prism([(xa, 0.0), (xr, h), (xr, h - 0.1), (xa + 0.15, 0.0)], 0.04, (0, y, 0), "frame", axis="y")
        m.box((0.08, 0.04, h), (xb - 0.04, y, h / 2), "frame")
    m.build("gable", r)


# ---- Library ----

LIB_BAY = 2.0
LIB_H = 8.0
LIB_T = 0.36
FLOOR_Z = 3.75


def _lib_glazing(m, x0, x1, z0, z1, lights=2, transoms=(), floor=None, depth=-0.24):
    """A tall lit window set back to `depth`: warm panes in a black steel
    frame, `lights` bays of mullions, transoms, and at `floor` the slab
    edge of the upper floor with its rail."""
    w = x1 - x0
    cx = (x0 + x1) / 2
    m.box((w, 0.03, z1 - z0), (cx, depth, (z0 + z1) / 2), "window_glow")
    f = depth + 0.05
    for x in (x0 + 0.05, x1 - 0.05):
        m.box((0.1, 0.1, z1 - z0), (x, f, (z0 + z1) / 2), "frame")
    for z in (z0 + 0.05, z1 - 0.05):
        m.box((w, 0.1, 0.1), (cx, f, z), "frame")
    for k in range(1, lights):
        m.box((0.06, 0.08, z1 - z0), (x0 + w * k / lights, f - 0.01, (z0 + z1) / 2), "frame")
    for z in transoms:
        m.box((w, 0.08, 0.06), (cx, f - 0.01, z), "frame")
    if floor is not None:
        m.box((w, 0.1, 0.32), (cx, f + 0.01, floor), "slate_dark", bevel=0.01)
        m.box((w, 0.05, 0.05), (cx, f + 0.02, floor + 1.0), "frame")
        for k in range(1, 2 * lights):
            m.box((0.03, 0.03, 0.84), (x0 + w * k / (2 * lights), f + 0.02, floor + 0.58), "frame")


def _lib_trim(m, w, t=LIB_T):
    """The library wall's dark plinth, pale frieze and cornice, and a warm
    cove light washing down the wall under the frieze."""
    m.box((w, t + 0.1, 0.55), (0, -t / 2 + 0.05, 0.275), "stone_dark", bevel=0.02)
    m.box((w, t + 0.14, 0.3), (0, -t / 2 + 0.07, LIB_H - 0.35), "cream", bevel=0.02)
    m.box((w, t + 0.3, 0.2), (0, -t / 2 + 0.15, LIB_H - 0.1), "cream", bevel=0.02)
    m.box((w, 0.05, 0.04), (0, 0.06, LIB_H - 0.52), "lamp_glow")


def lib_wall_arch():
    """A 2 m bay: a tall two-storey window lit warm, the upper floor's slab
    edge and glass rail across it, a stone sill and a dark head."""
    r = lib.root("lib_wall_arch")
    m = Mesh()
    w = LIB_BAY
    x0, x1, z0, z1 = -0.64, 0.64, 0.75, 7.0
    m.slab([(-w / 2, 0.55), (w / 2, 0.55), (w / 2, LIB_H - 0.5), (-w / 2, LIB_H - 0.5)],
           [rect_hole(x0, x1, z0, z1)], LIB_T, (0, -LIB_T / 2, 0), "stone", reveal_mat="stone_dark")
    _lib_glazing(m, x0, x1, z0, z1, lights=2, transoms=(2.6, 5.6), floor=FLOOR_Z)
    m.box((x1 - x0 + 0.22, 0.2, 0.1), (0, 0.04, z0 - 0.05), "cream", bevel=0.015)
    m.box((x1 - x0 + 0.22, 0.08, 0.2), (0, 0.02, z1 + 0.1), "stone_dark", bevel=0.01)
    _lib_trim(m, w)
    m.build("wall", r)


def lib_column():
    """A pale stone pilaster with an uplight washing it from its base."""
    r = lib.root("lib_column")
    m = Mesh()
    m.box((0.6, 0.3, 0.7), (0, 0.1, 0.35), "stone_dark", bevel=0.03)
    m.box((0.42, 0.24, LIB_H - 1.25), (0, 0.07, 0.7 + (LIB_H - 1.25) / 2), "cream", bevel=0.02)
    m.box((0.52, 0.28, 0.2), (0, 0.09, FLOOR_Z), "stone", bevel=0.02)
    m.box((0.56, 0.3, 0.32), (0, 0.1, LIB_H - 0.36), "stone", bevel=0.03)
    m.box((0.32, 0.05, 0.03), (0, 0.22, 0.71), "lamp_glow")
    m.build("column", r)


def lib_entrance():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): a tall lit portal over the open doorway, the upper floor
    behind its rail, a steel canopy with a warm strip light, a low step,
    and a raised parapet with the library's lit book emblem. Nothing stands
    in the opening below the glazing; the doors fold into the reveals
    (lib_door_leaves)."""
    r = lib.root("lib_entrance")
    m = Mesh()
    w = DOOR_W
    x0, x1, top = -w / 2, w / 2, 6.6
    m.slab([(x0, top), (x1, top), (x1, LIB_H - 0.5), (x0, LIB_H - 0.5)], [], LIB_T, (0, -LIB_T / 2, 0), "stone")
    _lib_glazing(m, x0, x1, DOOR_H, top, lights=4, transoms=(5.3,), floor=FLOOR_Z, depth=-0.26)
    m.box((w, 0.1, 0.14), (0, -0.21, DOOR_H + 0.07), "frame")
    m.box((w, 0.14, 0.4), (0, 0.07, top + 0.2), "cream", bevel=0.02)
    # A slim steel canopy on tie rods, a warm strip under its front edge.
    m.box((3.5, 2.0, 0.12), (0, 1.0, 3.25), "steel_dark", bevel=0.02)
    m.box((3.3, 0.06, 0.04), (0, 1.9, 3.17), "lamp_glow")
    for x in (-1.0, 1.0):
        m.box((0.16, 0.16, 0.03), (x, 0.9, 3.18), "lamp_glow")
    for x in (-1.6, 1.6):
        m.beam((x, 0.0, 4.7), (x, 1.92, 3.32), 0.05, "frame")
    m.box((w + 0.8, 1.2, 0.15), (0, 0.6, 0.075), "stone", bevel=0.02)
    # The parapet over the bay and its emblem: an open book on a lit disc.
    m.box((w, LIB_T + 0.14, 0.3), (0, -LIB_T / 2 + 0.07, LIB_H - 0.35), "cream", bevel=0.02)
    m.box((w, LIB_T + 0.3, 0.2), (0, -LIB_T / 2 + 0.15, LIB_H - 0.1), "cream", bevel=0.02)
    m.box((w, 0.05, 0.04), (0, 0.06, LIB_H - 0.52), "lamp_glow")
    m.box((2.2, 0.3, 0.6), (0, -0.05, LIB_H + 0.3), "stone", bevel=0.03)
    m.box((2.4, 0.36, 0.1), (0, -0.05, LIB_H + 0.62), "cream", bevel=0.02)
    m.cylinder(0.25, 0.04, (0, 0.11, LIB_H + 0.3), "window_glow", 16, rot=lib.rotx(90))
    m.cylinder(0.29, 0.03, (0, 0.105, LIB_H + 0.3), "frame", 16, rot=lib.rotx(90))
    for side in (-1, 1):
        m.box((0.15, 0.02, 0.2), (side * 0.085, 0.14, LIB_H + 0.3), "frame", rot=lib.roty(side * -14))
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
        m.box((0.054, LIB_T - 0.1, DOOR_H - 0.5), (x, -LIB_T / 2, (DOOR_H - 0.5) / 2 + 0.25), "glass")
    m.build("leaves", r)


def lib_banner():
    """An indigo banner with a pale open book, hung below a steel bracket
    at z = 0, a small spot on the arm lighting it."""
    r = lib.root("lib_banner")
    m = Mesh()
    m.box((0.36, 0.06, 0.22), (0, 0.03, 0.0), "frame", bevel=0.01)
    m.box((0.06, 0.62, 0.07), (0, 0.33, 0.0), "frame")
    m.beam((0, 0.06, -0.3), (0, 0.45, 0.0), 0.04, "frame")
    m.cylinder(0.035, 1.2, (0, 0.6, -0.08), "steel_dark", 8, rot=lib.roty(90))
    for x in (-0.6, 0.6):
        m.sphere(0.06, (x, 0.6, -0.08), "steel", subdivisions=1)
    m.box((0.12, 0.12, 0.1), (0, 0.4, 0.09), "frame")
    m.box((0.1, 0.02, 0.08), (0, 0.46, 0.09), "lamp_glow")
    # The cloth: indigo with a pale open book and a swallowtail hem.
    m.box((1.0, 0.04, 3.7), (0, 0.6, -1.97), "indigo", bevel=0.01)
    m.prism([(-0.5, 0.0), (0.5, 0.0), (0.5, -0.42), (0.0, -0.16), (-0.5, -0.42)], 0.04, (0, 0.6, -3.8),
            "indigo", axis="y")
    for side in (-1, 1):
        m.prism([(0.0, 0.0), (0.3, 0.06), (0.3, 0.46), (0.0, 0.4)], 0.02, (0, 0.625, -1.55), "warm_white",
                axis="y", rot=None if side > 0 else lib.rotz(180))
    m.box((0.03, 0.03, 0.44), (0, 0.63, -1.33), "navy")
    for k, wd in enumerate((0.7, 0.5)):
        m.box((wd, 0.02, 0.06), (0, 0.625, -2.35 - k * 0.16), "warm_white")
    m.box((1.0, 0.05, 0.08), (0, 0.6, -0.2), "brass")
    m.build("banner", r)


# The roof: a flat deck fitted to the 20 m x 18 m library, a stone drum
# with a lit clerestory, and a dark ribbed glass dome on a lit ring.
ROOF_W, ROOF_D = 20.4, 18.4
DRUM_R = 5.7
DOME_R = 5.45
DOME_SQUASH = 0.62


def _dome_frame(a, b):
    """(point, outward normal, azimuth tangent, meridian tangent) on the dome
    at elevation a and azimuth b (about the dome's base centre)."""
    ca, sa, cb, sb = math.cos(a), math.sin(a), math.cos(b), math.sin(b)
    R, S = DOME_R, DOME_SQUASH
    p = lib.Vector((ca * cb * R, ca * sb * R, sa * R * S))
    n = lib.Vector((p.x / R ** 2, p.y / R ** 2, p.z / (R * S) ** 2)).normalized()
    t_az = lib.Vector((-sb, cb, 0.0))
    t_mer = lib.Vector((-sa * cb * R, -sa * sb * R, ca * R * S)).normalized()
    return p, n, t_az, t_mer


def lib_roof():
    r = lib.root("lib_roof")
    m, d = Mesh(), Mesh()
    hw, hd = ROOF_W / 2, ROOF_D / 2
    # The deck: a dark membrane inside a pale parapet and coping.
    m.box((ROOF_W - 0.5, ROOF_D - 0.5, 0.2), (0, 0, 0.1), "slate_dark")
    for sx, sy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        length = ROOF_D if sx else ROOF_W
        size = (0.36, length, 0.42) if sx else (length, 0.36, 0.42)
        cap = (0.44, length, 0.08) if sx else (length, 0.44, 0.08)
        at = (sx * (hw - 0.18), sy * (hd - 0.18))
        m.box(size, (at[0], at[1], 0.21), "stone")
        m.box(cap, (sx * (hw - 0.2), sy * (hd - 0.2), 0.46), "cream", bevel=0.01)
    # Two rooftop plant boxes behind the dome.
    for x in (-7.4, 7.4):
        m.box((1.6, 1.2, 0.7), (x, -6.8, 0.55), "slate", bevel=0.02)
        m.box((1.2, 0.05, 0.4), (x, -6.18, 0.55), "steel_dark")
    # The drum: a stone base, a clerestory lit warm between black mullions,
    # a pale cornice, and the bright ring the dome stands on.
    m.cylinder(DRUM_R + 0.35, 0.4, (0, 0, 0.4), "stone", 32)
    m.cylinder(DRUM_R + 0.05, 0.35, (0, 0, 0.775), "cream", 32, cap=False)
    m.cylinder(DRUM_R, 1.3, (0, 0, 1.6), "window_glow", 32, cap=False)
    n = 24
    for k in range(n):
        b = 2 * math.pi * (k + 0.5) / n
        m.box((0.12, 0.1, 1.3), (math.cos(b) * (DRUM_R + 0.04), math.sin(b) * (DRUM_R + 0.04), 1.6), "frame",
              rot=lib.rotz(math.degrees(b)))
    m.cylinder(DRUM_R + 0.08, 0.1, (0, 0, 1.0), "frame", 32, cap=False)
    m.cylinder(DRUM_R + 0.3, 0.26, (0, 0, 2.38), "cream", 32)
    m.cylinder(DRUM_R + 0.02, 0.2, (0, 0, 2.61), "lamp_glow", 32, cap=False)
    m.cylinder(DRUM_R + 0.1, 0.08, (0, 0, 2.75), "steel_dark", 32)
    # The dome: blue glass, ribbed in black along meridians and three parallels, a
    # small lantern at the crown.
    z0 = 2.79
    d.dome(DOME_R, (0, 0, z0), "glass_light", segments=32, rings=8, squash=DOME_SQUASH)
    top = math.radians(84)
    for k in range(20):
        b = 2 * math.pi * k / 20
        rows = [_dome_frame(top * i / 7, b) for i in range(8)]
        _strip(d, [p + lib.Vector((0, 0, z0)) for p, *_ in rows], [nn for _, nn, _, _ in rows],
               [t for _, _, t, _ in rows], 0.09, 0.07, "frame")
    for a in (22, 44, 64):
        rows = [_dome_frame(math.radians(a), 2 * math.pi * k / 32) for k in range(33)]
        _strip(d, [p + lib.Vector((0, 0, z0)) for p, *_ in rows], [nn for _, nn, _, _ in rows],
               [t for _, _, _, t in rows], 0.1, 0.07, "frame")
    ztop = z0 + DOME_R * DOME_SQUASH
    d.cylinder(0.62, 0.14, (0, 0, ztop - 0.02), "steel_dark", 16)
    d.cylinder(0.4, 0.26, (0, 0, ztop + 0.18), "frame", 16, radius_top=0.3)
    m.build("roof", r)
    lib.smooth(d.build("dome", r), 30)


# ---- Towers ----

TOWER = 11.36
FLOOR = 3.2
LOBBY = 4.0


def _tower_tier(m, x0, x1, y0, y1, z0, floors, rng, lobby=False, bay=1.8, lit=0.55):
    """A tier over [x0, x1] x [y0, y1]: dark glass behind slim mullions, its
    rooms a deterministic mix of lit and dark (some lit only below a
    blind), pale slab edges at every floor, dark corners. A lobby tier's ground
    floor is set back behind piers, lit warm. Returns its roof height."""
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
            m.box((w, d, 0.32), (cx, cy, z + 0.16), "warm_white", bevel=0.03)
        z += h
    m.box((w + 0.04, d + 0.04, 0.4), (cx, cy, top - 0.2), "warm_white", bevel=0.03)
    for (ax, ay), (sx, sy) in (((x0, y0), (1, 1)), ((x1, y0), (-1, 1)), ((x1, y1), (-1, -1)), ((x0, y1), (1, -1))):
        m.box((0.42, 0.42, zt - zg), (ax + sx * 0.23, ay + sy * 0.23, (zg + zt) / 2), "slate")
    for _, length, turn, off in _faces(w, d):
        t = Mesh()
        n = max(2, round((length - 0.5) / bay))
        xs = [-length / 2 + 0.25 + (length - 0.5) * k / n for k in range(n + 1)]
        for x in xs[1:-1]:
            t.box((0.1, 0.14, zt - zg), (x, -0.12, (zg + zt) / 2), "steel_dark")
        for f in range(floors):
            fz = zg + f * FLOOR + 0.32
            for k in range(n):
                if not _lit(rng, lit):
                    continue
                # A lit room: two lights either side of a mullion, a rail
                # across them, some lit only below a drawn blind.
                z1 = fz + (FLOOR - 0.32) * (0.5 if _lit(rng, 0.25) else 1.0)
                mid = (xs[k] + xs[k + 1]) / 2
                for a, b in ((xs[k] + 0.06, mid - 0.04), (mid + 0.04, xs[k + 1] - 0.06)):
                    if _lit(rng, 0.85):
                        _pane(t, a, b, fz, fz + 0.9, -0.16, "window_glow")
                        _pane(t, a, b, fz + 1.0, z1, -0.16, "window_glow")
        _merge_xform(m, t, turn, (cx + off[0], cy + off[1]))
    if lobby:
        m.box((w - 1.2, d - 1.2, LOBBY), (cx, cy, z0 + LOBBY / 2), "window_glow")
        for _, length, turn, off in _faces(w, d):
            t = Mesh()
            n = max(2, round(length / 2.8))
            for k in range(1, n):
                t.box((0.36, 0.36, LOBBY), (-length / 2 + length * k / n, -0.26, z0 + LOBBY / 2), "slate")
            for k in range(n):
                x = -length / 2 + length * (k + 0.5) / n
                t.box((0.06, 0.08, LOBBY - 0.4), (x, -0.62, z0 + LOBBY / 2 - 0.1), "frame")
            t.box((length - 1.0, 0.08, 0.1), (0, -0.62, z0 + 2.9), "frame")
            _merge_xform(m, t, turn, (cx + off[0], cy + off[1]))
    return top


def _planter(m, g, a, b, z, seed, inward, width=0.8, trees=(), spacing=2.0, tree_h=2.6, lights=True):
    """A dark planter from a to b, heaped with shrubs, small trees at the
    fractions `trees` of its length leaning `inward`, and warm uplights set
    in its rim."""
    (ax, ay), (bx, by) = a, b
    length = math.dist(a, b)
    ux, uy = (bx - ax) / length, (by - ay) / length
    c = ((ax + bx) / 2, (ay + by) / 2)
    size = (abs(bx - ax) + (width if abs(ux) < 0.5 else 0), abs(by - ay) + (width if abs(uy) < 0.5 else 0))
    m.box((size[0], size[1], 0.75), (c[0], c[1], z + 0.375), "slate_dark")
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
        if lights:
            # An uplight in the rim under each tree.
            px, py = ax + ux * f * length - inward[0] * 0.3, ay + uy * f * length - inward[1] * 0.3
            m.box((0.16, 0.16, 0.04), (px, py, z + 0.77), "lamp_glow")


_EDGE = {"s": (0, 1), "e": (-1, 0), "n": (0, -1), "w": (1, 0)}


def _terrace(m, g, outer, z, seed, edges=("s", "e", "n", "w"), trees=(), tree_h=2.6):
    """A planted setback on the lower tier's roof `outer` (x0, x1, y0, y1):
    dark decking, and planters along its exposed `edges`, with trees at the
    fractions `trees` of every other edge."""
    x0, x1, y0, y1 = outer
    ends = {"s": ((x0, y0), (x1, y0)), "e": ((x1, y0), (x1, y1)), "n": ((x1, y1), (x0, y1)), "w": ((x0, y1), (x0, y0))}
    order = "senw"
    m.box((x1 - x0 - 0.2, y1 - y0 - 0.2, 0.06), ((x0 + x1) / 2, (y0 + y1) / 2, z + 0.03), "wood_dark")
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
    """Glazed doors lit warm under a dark canopy with a warm strip light."""
    m.box((3.4, 1.2, 0.16), (0, y - 0.5, z + 3.2), "slate_dark", bevel=0.03)
    m.box((3.2, 0.06, 0.04), (0, y + 0.07, z + 3.11), "lamp_glow")
    m.box((2.4, 0.06, 2.7), (0, y - 0.6, z + 1.35), "window_glow")
    for x in (-1.2, -0.4, 0.4, 1.2):
        m.box((0.08, 0.1, 2.7), (x, y - 0.56, z + 1.35), "frame")


def _neon_ring(n, x0, x1, y0, y1, z, t=0.08, out=0.05):
    """Magenta tubes round a rectangle just outside its edges at height z."""
    for (ax, ay), (bx, by) in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        if ay == by:
            yy = ay + (out if ay > (y0 + y1) / 2 else -out)
            n.box((abs(bx - ax) + 2 * out + t, t, t), ((ax + bx) / 2, yy, z), "neon_magenta")
        else:
            xx = ax + (out if ax > (x0 + x1) / 2 else -out)
            n.box((t, abs(by - ay) + 2 * out - t, t), (xx, (ay + by) / 2, z), "neon_magenta")


def _neon_post(n, x, y, z0, z1, t=0.08):
    """A vertical magenta tube on a tier's corner, from z0 to z1."""
    n.box((t, t, z1 - z0), (x, y, (z0 + z1) / 2), "neon_magenta")


def _corner(x, y, cx, cy, out=0.06):
    """A point just outside the corner (x, y) of a tier centred on (cx, cy)."""
    return x + math.copysign(out, x - cx), y + math.copysign(out, y - cy)


def _crown_box(m, n, x, y, w, d, z, h):
    """A rooftop plant room with a magenta tube round its top edge."""
    m.box((w, d, h), (x, y, z + h / 2), "slate", bevel=0.03)
    m.box((w + 0.1, d + 0.1, 0.1), (x, y, z + h + 0.05), "steel_dark")
    _neon_ring(n, x - w / 2, x + w / 2, y - d / 2, y + d / 2, z + h - 0.12, t=0.07, out=0.04)


def tower_a():
    """Three floors over a lobby, then two, then one, each stepping back to
    a planted terrace; a plant room on top; magenta neon round the crown
    and down two corners."""
    r = lib.root("tower_a")
    m, g, n = Mesh(), Mesh(), Mesh()
    rng = random.Random(101)
    h, s2, s3 = TOWER / 2, 4.1, 2.8
    t1 = _tower_tier(m, -h, h, -h, h, 0.0, 3, rng, lobby=True)
    t2 = _tower_tier(m, -s2, s2, -s2, s2, t1, 2, rng)
    t3 = _tower_tier(m, -s3, s3, -s3, s3, t2, 1, rng)
    _terrace(m, g, (-h, h, -h, h), t1, 3, trees=(0.12, 0.88))
    _terrace(m, g, (-s2, s2, -s2, s2), t2, 7)
    _terrace(m, g, (-s3, s3, -s3, s3), t3, 17, trees=(0.3,), tree_h=2.1)
    _crown_box(m, n, -0.4, -0.3, 2.0, 1.8, t3, 1.3)
    _neon_ring(n, -s3, s3, -s3, s3, t3 - 0.2)
    for sx, sy in ((1, 1), (-1, -1)):
        x, y = _corner(sx * s3, sy * s3, 0, 0)
        _neon_post(n, x, y, t2 + 0.1, t3 - 0.25)
    x, y = _corner(-s2, s2, 0, 0)
    _neon_post(n, x, y, t1 + 1.8, t2 - 0.2)
    _tower_door(m, h)
    m.build("tower", r)
    lib.smooth(g.build("garden", r), 60)
    n.build("neon", r)


def tower_b():
    """Two floors over a lobby, then a tier set back from the front (+y),
    then a crown set back from the east too: terraces cascading down to
    the street, magenta neon round the crown and down its corners."""
    r = lib.root("tower_b")
    m, g, n = Mesh(), Mesh(), Mesh()
    rng = random.Random(202)
    h = TOWER / 2
    yb, xb = h - 3.8, h - 4.2
    t1 = _tower_tier(m, -h, h, -h, h, 0.0, 2, rng, lobby=True)
    t2 = _tower_tier(m, -h, h, -h, yb, t1, 2, rng)
    t3 = _tower_tier(m, -h, xb, -h, yb - 2.0, t2, 1, rng)
    _terrace(m, g, (-h, h, yb, h), t1, 5, edges=("e", "n", "w"), trees=(0.5,))
    _terrace(m, g, (xb, h, -h, yb), t2, 9, edges=("s", "e", "n"))
    _terrace(m, g, (-h, xb, yb - 2.0, yb), t2, 11, edges=("n",), trees=(0.3,))
    _terrace(m, g, (-h, xb, -h, yb - 2.0), t3, 13)
    cx3, cy3 = (-h + xb) / 2, (-h + yb - 2.0) / 2
    _crown_box(m, n, cx3 - 0.3, cy3 - 0.4, 1.8, 1.6, t3, 1.2)
    _neon_ring(n, -h, xb, -h, yb - 2.0, t3 - 0.2)
    for x, y in ((xb, yb - 2.0), (-h, yb - 2.0)):
        px, py = _corner(x, y, cx3, cy3)
        _neon_post(n, px, py, t2 + 0.1, t3 - 0.25)
    px, py = _corner(h, yb, 0, (-h + yb) / 2)
    _neon_post(n, px, py, t1 + 1.8, t2 - 0.25)
    _tower_door(m, h)
    m.build("tower", r)
    lib.smooth(g.build("garden", r), 60)
    n.build("neon", r)


# ---- Houses and the shop ----

HOUSE_W, HOUSE_D = 5.8, 7.6
HOUSE_T = 0.22
PLINTH = 0.35
STOREYS = (PLINTH, 2.6, 4.85)
EAVES = 7.1
PARAPET = 7.55
COPING = 0.35


def _hwindow(t, x, z0, z1, width, lit):
    """A window on a face's frame (its hole already cut): a pane lit warm
    or dark glass, set back in a black frame with a mullion and transom,
    a stone sill and a slim dark head."""
    zc = (z0 + z1) / 2
    y = -HOUSE_T + 0.06
    _pane(t, x - width / 2, x + width / 2, z0, z1, y, "window_glow" if lit else "glass")
    t.box((0.06, 0.05, z1 - z0), (x, y + 0.03, zc), "frame")
    t.box((width, 0.05, 0.06), (x, y + 0.03, z0 + (z1 - z0) * 0.7), "frame")
    t.box((width + 0.2, 0.2, 0.07), (x, 0.07, z0 - 0.035), "stone")


def _hfrench(t, x, z0, z1, width, lit=True):
    """A glazed door onto a balcony: two leaves and a transom light."""
    y = -HOUSE_T + 0.06
    _pane(t, x - width / 2, x + width / 2, z0, z1, y, "window_glow" if lit else "glass")
    for dx in (-width / 2 + 0.04, 0.0, width / 2 - 0.04):
        t.box((0.07, 0.06, z1 - z0), (x + dx, y + 0.03, (z0 + z1) / 2), "frame")
    t.box((width, 0.06, 0.07), (x, y + 0.03, z1 - 0.45), "frame")
    t.box((width, 0.06, 0.07), (x, y + 0.03, z1 - 0.035), "frame")
    t.box((width + 0.2, 0.08, 0.1), (x, 0.03, z1 + 0.05), "slate_dark")


def _hbalcony(t, x, z, width):
    """A balcony at floor height z: a dark slab with a glass balustrade
    under a steel rail, a warm light under the slab."""
    t.box((width, 0.8, 0.14), (x, 0.4, z - 0.07), "slate_dark", bevel=0.02)
    t.box((width - 0.1, 0.03, 0.85), (x, 0.76, z + 0.5), "glass_light")
    for sx in (-1, 1):
        t.box((0.03, 0.72, 0.85), (x + sx * (width / 2 - 0.05), 0.4, z + 0.5), "glass_light")
    t.box((width, 0.05, 0.05), (x, 0.78, z + 0.95), "steel")
    for sx in (-1, 1):
        t.box((0.05, 0.78, 0.05), (x + sx * (width / 2 - 0.03), 0.4, z + 0.95), "steel")
    t.box((0.3, 0.1, 0.03), (x, 0.55, z - 0.155), "lamp_glow")


def _hdoor(t, x, width=1.0, height=2.2):
    """A dark front door with a lit side light, a wall lamp, a slim canopy
    with a warm strip, and a stone step."""
    z = PLINTH
    y = -HOUSE_T + 0.08
    t.box((width * 0.72, 0.05, height), (x - width * 0.14, y, z + height / 2), "wood_dark")
    t.box((width * 0.24, 0.03, height), (x + width * 0.37, y, z + height / 2), "window_glow")
    t.box((0.05, 0.06, height), (x + width * 0.23, y + 0.03, z + height / 2), "frame")
    for dz in (0.55, 1.35):
        t.box((width * 0.5, 0.03, 0.55), (x - width * 0.14, y + 0.035, z + dz), "wood", bevel=0.01)
    t.box((0.04, 0.05, 0.3), (x + width * 0.1, y + 0.06, z + 1.0), "brass")
    for sx in (-1, 1):
        t.box((0.1, 0.07, height + 0.1), (x + sx * (width / 2 + 0.05), 0.035, z + (height + 0.1) / 2), "frame")
    t.box((width + 0.6, 0.62, 0.1), (x, 0.31, z + height + 0.3), "slate_dark", bevel=0.02)
    t.box((width + 0.4, 0.05, 0.03), (x, 0.58, z + height + 0.235), "lamp_glow")
    t.box((0.14, 0.1, 0.26), (x - width / 2 - 0.3, 0.05, z + 1.8), "frame")
    t.box((0.1, 0.04, 0.2), (x - width / 2 - 0.3, 0.11, z + 1.8), "lamp_glow")
    t.box((width + 0.5, 0.6, 0.16), (x, 0.3, z - 0.08), "stone", bevel=0.02)


def _hwall(t, length, top, holes, mat, base=PLINTH):
    t.slab([(-length / 2, base), (length / 2, base), (length / 2, top), (-length / 2, top)], holes, HOUSE_T,
           (0, -HOUSE_T / 2, 0), mat, reveal_mat="slate_dark")


def _flat_roof(m, w, d, eaves, parapet, roofbox, seed, g=None):
    """A roof deck inside the parapet, a coping ring projecting COPING all
    round, and a rooftop stair house (x, y, bw, bd, height) with a lit
    door; a planter on the deck if `g` is given."""
    m.box((w - 2 * HOUSE_T, d - 2 * HOUSE_T, 0.1), (0, 0, eaves - 0.05), "slate_dark")
    ow, od = w / 2 + COPING, d / 2 + COPING
    cw = COPING + HOUSE_T + 0.05
    for sy in (-1, 1):
        m.box((2 * ow, cw, 0.14), (0, sy * (od - cw / 2), parapet + 0.07), "stone_dark", bevel=0.01)
    for sx in (-1, 1):
        m.box((cw, 2 * od - 2 * cw, 0.14), (sx * (ow - cw / 2), 0, parapet + 0.07), "stone_dark", bevel=0.01)
    x, y, bw, bd, bh = roofbox
    m.box((bw, bd, bh - 0.08), (x, y, eaves + (bh - 0.08) / 2), "slate", bevel=0.02)
    m.box((bw + 0.14, bd + 0.14, 0.08), (x, y, eaves + bh - 0.04), "stone_dark")
    dh = min(0.9, bh - 0.3)
    m.box((0.8, 0.04, dh), (x, y + bd / 2 + 0.01, eaves + 0.05 + dh / 2), "wood_dark")
    m.box((0.2, 0.05, 0.08), (x, y + bd / 2 + 0.03, eaves + dh + 0.12), "lamp_glow")
    if g is not None:
        px, py = -x * 0.6, -y * 0.8
        m.box((1.6, 0.6, 0.45), (px, py, eaves + 0.225), "slate_dark")
        for k in range(2):
            _clump(g, (px - 0.4 + k * 0.8, py, eaves + 0.45), 0.36, seed * 5 + k, scale=(1.1, 1.0, 0.9),
                   mat="leaf_dark", cap="leaf", cut=0.0)


def _flowers(g, x, y, z, seed):
    """A pot of flowers standing at (x, y, z)."""
    rng = random.Random(seed)
    g.cylinder(0.16, 0.3, (x, y, z + 0.15), "charcoal", 8, radius_top=0.2)
    _clump(g, (x, y, z + 0.32), 0.24, seed * 3 + 1, scale=(1.0, 1.0, 0.9), mat="leaf",
           cap=rng.choice(("flower_pink", "flower_white", "flower_yellow")), cut=0.0)


def _house(name, wall, band, front, roofbox, sides=1, seed=0, lit=0.72):
    """A three-storey flat-roofed town house: dark walls on a stone plinth,
    string courses, windows lit or dark, the front's door and balconies
    from `front` (per storey: ("w" window | "f" French door with a balcony
    | "d" door | "b" French door with a wide balcony, x)), a parapet with a
    projecting coping, and a stair house on the roof."""
    r = lib.root(name)
    m, g = Mesh(), Mesh()
    rng = random.Random(seed * 17 + 3)
    w, d = HOUSE_W, HOUSE_D
    m.box((w + 0.1, d + 0.1, PLINTH), (0, 0, PLINTH / 2), "stone_dark", bevel=0.02)
    for face, length, turn, off in _faces(w, d):
        t = Mesh()
        holes = []
        span = length - 2 * HOUSE_T if face in ("east", "west") else length
        if face == "front":
            for storey, items in enumerate(front):
                z0 = STOREYS[storey]
                for kind, x in items:
                    if kind == "w":
                        holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                        _hwindow(t, x, z0 + 0.75, z0 + 2.0, 0.9, _lit(rng, lit))
                    elif kind == "d":
                        holes.append(rect_hole(x - 0.5, x + 0.5, PLINTH, PLINTH + 2.2))
                        _hdoor(t, x)
                    else:
                        wide = kind == "b"
                        holes.append(rect_hole(x - 0.55, x + 0.55, z0 + 0.02, z0 + 2.05))
                        _hfrench(t, x, z0 + 0.02, z0 + 2.05, 1.1, _lit(rng, lit + 0.15))
                        _hbalcony(t, x, z0, 2.6 if wide else 1.7)
                        _flowers(g, x - (0.95 if wide else 0.55), d / 2 + 0.52, z0, seed + storey)
        else:
            xs = [0.0] if face in ("east", "west") and sides == 1 else [-span / 4, span / 4]
            for z0 in STOREYS:
                for x in xs:
                    holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                    _hwindow(t, x, z0 + 0.75, z0 + 2.0, 0.9, _lit(rng, lit))
        _hwall(t, span, PARAPET, holes, wall)
        for z in STOREYS[1:]:
            t.box((span, 0.06, 0.12), (0, 0.03, z - 0.08), band)
        _merge_xform(m, t, turn, off)
    _flat_roof(m, w, d, EAVES, PARAPET, roofbox, seed, g)
    m.build("house", r)
    lib.smooth(g.build("plants", r), 60)


def house_a():
    _house("house_a", "slate_light", "slate_dark",
           [[("d", -1.45), ("w", 1.45)], [("w", -1.45), ("f", 1.45)], [("f", -1.45), ("w", 1.45)]],
           (0.9, -1.6, 1.8, 2.2, 1.15), seed=1)


def house_b():
    _house("house_b", "charcoal", "stone_dark",
           [[("w", -1.7), ("d", 0.0), ("w", 1.7)], [("w", -1.7), ("w", 0.0), ("w", 1.7)],
            [("w", -2.0), ("b", 0.0), ("w", 2.0)]], (-1.2, -1.4, 2.0, 2.4, 1.3), sides=2, seed=4)


def house_c():
    _house("house_c", "render_sky", "slate_dark",
           [[("w", -1.6), ("d", 1.75)], [("w", -1.9), ("f", 0.0), ("w", 1.9)], [("w", -1.9), ("f", 0.0), ("w", 1.9)]],
           (1.0, -1.2, 1.9, 2.4, 1.52), seed=7)


SHOP_W, SHOP_D = 4.6, 7.4
SHOP_FLOORS = (3.3, 5.55)
SHOP_EAVES = 7.8
SHOP_PARAPET = 8.2


def shop_a():
    """A shop: a lit shopfront under a steel canopy with a warm strip, a
    dark fascia carrying a cyan neon glyph (no text), a projecting blade
    sign outlined in magenta, two dark floors above with warm windows, a
    parapet and a rooftop plant room."""
    r = lib.root("shop_a")
    m, g, n1, n2 = Mesh(), Mesh(), Mesh(), Mesh()
    rng = random.Random(55)
    w, d = SHOP_W, SHOP_D
    m.box((w + 0.1, d + 0.1, 0.15), (0, 0, 0.075), "stone_dark", bevel=0.02)
    for face, length, turn, off in _faces(w, d):
        t = Mesh()
        holes = []
        span = length - 2 * HOUSE_T if face in ("east", "west") else length
        xs = [-1.1, 1.1] if face in ("front", "back") else [-1.6, 1.6]
        for z0 in SHOP_FLOORS:
            for x in xs:
                holes.append(rect_hole(x - 0.45, x + 0.45, z0 + 0.75, z0 + 2.0))
                _hwindow(t, x, z0 + 0.75, z0 + 2.0, 0.9, _lit(rng, 0.7))
        if face == "front":
            holes.append(rect_hole(-2.0, 2.0, 0.15, 2.85))
            f1, f2 = Mesh(), Mesh()
            _shopfront(t, f1, f2)
            _merge_xform(n1, f1, turn, off)
            _merge_xform(n2, f2, turn, off)
        elif face == "back":
            holes.append(rect_hole(-0.5, 0.5, 0.15, 2.35))
            t.box((1.0, 0.05, 2.2), (0, -HOUSE_T + 0.08, 1.25), "wood_dark")
            t.box((0.12, 0.08, 0.2), (0.75, 0.04, 2.1), "frame")
            t.box((0.08, 0.03, 0.14), (0.75, 0.09, 2.1), "lamp_glow")
            for x in (-1.3, 1.3):
                holes.append(rect_hole(x - 0.45, x + 0.45, 1.0, 2.25))
                _hwindow(t, x, 1.0, 2.25, 0.9, _lit(rng, 0.5))
        _hwall(t, span, SHOP_PARAPET, holes, "charcoal", base=0.15)
        for z in SHOP_FLOORS:
            t.box((span, 0.06, 0.12), (0, 0.03, z - 0.08), "slate_light")
        _merge_xform(m, t, turn, off)
    for k, x in enumerate((-1.1, 1.1)):
        rng2 = random.Random(40 + k)
        for j in range(2):
            _clump(g, (x - 0.22 + j * 0.44, d / 2 + 0.14, SHOP_FLOORS[0] + 0.72), 0.2, 50 + 2 * k + j,
                   scale=(1.0, 0.8, 0.9), mat="leaf", cap=rng2.choice(("flower_pink", "flower_yellow", "flower_white")),
                   cut=0.0)
        m.box((1.0, 0.24, 0.2), (x, d / 2 + 0.12, SHOP_FLOORS[0] + 0.62), "slate_dark")
    for x in (-2.12, 2.12):
        g.cylinder(0.24, 0.5, (x, d / 2 + 0.45, 0.25), "charcoal", 8, radius_top=0.3)
        _clump(g, (x, d / 2 + 0.45, 0.55), 0.38, 60 + int(x), scale=(1.0, 1.0, 1.1), mat="leaf_dark",
               cap="leaf_light", cut=0.0)
    _flat_roof(m, w, d, SHOP_EAVES, SHOP_PARAPET, (0.6, -1.8, 1.8, 2.0, 0.76), 9)
    m.build("shop", r)
    lib.smooth(g.build("plants", r), 60)
    n1.build("neon", r)
    n2.build("neon_2", r)


def _shopfront(t, n1, n2):
    """The shopfront in the front face's frame: a black frame round a lit
    display and a glazed door, shelves in silhouette, a steel canopy with a
    warm strip, a fascia with a cyan neon glyph, and a blade sign outlined
    in magenta."""
    y = -HOUSE_T + 0.06
    t.box((4.0, 0.05, 0.55), (0, y + 0.02, 0.42), "frame")
    t.box((2.75, 0.03, 2.1), (-0.62, y, 1.75), "window_glow")
    t.box((0.95, 0.03, 2.5), (1.5, y, 1.4), "window_glow")
    for z in (1.25, 1.85):
        t.box((2.6, 0.03, 0.05), (-0.62, y + 0.025, z), "frame")
    for k, (x, h) in enumerate(((-1.6, 0.3), (-1.05, 0.2), (-0.3, 0.26), (0.3, 0.18))):
        t.box((0.34, 0.03, h), (x, y + 0.025, 1.28 + h / 2 if k % 2 == 0 else 1.88 + h / 2), "slate")
    for x, zc, h in ((-1.97, 1.5, 2.7), (0.98, 1.5, 2.7), (1.97, 1.5, 2.7), (-0.62, 1.75, 2.1)):
        t.box((0.1 if abs(x) > 0.7 else 0.05, 0.08, h), (x, y + 0.04, zc), "frame")
    t.box((4.0, 0.08, 0.08), (0, y + 0.04, 2.3), "frame")
    t.box((0.05, 0.06, 0.5), (1.15, y + 0.08, 1.3), "brass")
    t.box((4.0, 0.08, 0.1), (0, y + 0.04, 2.8), "frame")
    # The canopy over the pavement.
    reach = 1.3
    t.box((4.5, reach, 0.12), (0, reach / 2, 2.95), "steel_dark", bevel=0.01)
    t.box((4.3, 0.06, 0.04), (0, reach - 0.08, 2.87), "lamp_glow")
    for x in (-1.2, 0.0, 1.2):
        t.box((0.18, 0.18, 0.03), (x, 0.6, 2.88), "lamp_glow")
    for x in (-2.2, 2.2):
        t.beam((x, 0.0, 3.6), (x, reach - 0.05, 3.0), 0.05, "frame")
    # The fascia and its glyph, a pictogram rather than letters: a steaming
    # cup, and a wave running along the fascia.
    t.box((4.5, 0.14, 0.62), (0, 0.07, 3.36), "charcoal", bevel=0.02)
    yf = 0.17
    cx, cz, rad = -1.25, 3.42, 0.2
    bowl = [(cx + rad * math.cos(math.pi + math.pi * k / 6), cz + rad * math.sin(math.pi + math.pi * k / 6))
            for k in range(7)]
    handle = [(cx + 0.24 + 0.08 * math.cos(-math.pi / 2 + math.pi * k / 3), cz - 0.07 + 0.08 * math.sin(-math.pi / 2 + math.pi * k / 3))
              for k in range(4)]
    steam = [[(x + 0.04 * (k % 2), 3.49 + 0.05 * k) for k in range(4)] for x in (cx - 0.09, cx + 0.05)]
    wave = [(-0.7 + 2.5 * k / 10, 3.36 + 0.07 * math.sin(math.pi * k / 2.5)) for k in range(11)]
    for line in [bowl + [bowl[0]], handle, wave] + steam:
        for (ax, az), (bx, bz) in zip(line, line[1:]):
            n1.beam((ax, yf, az), (bx, yf, bz), 0.05, "neon_cyan")
    # The blade sign, standing out from the wall above the canopy.
    bx, bz0, bz1, reach_b = 1.95, 3.8, 5.55, 0.95
    t.box((0.06, 0.2, 0.08), (bx, 0.1, bz1 - 0.1), "frame")
    t.box((0.06, 0.2, 0.08), (bx, 0.1, bz0 + 0.1), "frame")
    t.box((0.14, reach_b - 0.2, bz1 - bz0), (bx, 0.2 + (reach_b - 0.2) / 2, (bz0 + bz1) / 2), "charcoal", bevel=0.02)
    yc, zc = 0.2 + (reach_b - 0.2) / 2, (bz0 + bz1) / 2
    hy, hz = (reach_b - 0.2) / 2 - 0.06, (bz1 - bz0) / 2 - 0.06
    for sx in (-1, 1):
        x = bx + sx * 0.09
        for a, b in (((yc - hy, zc - hz), (yc + hy, zc - hz)), ((yc + hy, zc - hz), (yc + hy, zc + hz)),
                     ((yc + hy, zc + hz), (yc - hy, zc + hz)), ((yc - hy, zc + hz), (yc - hy, zc - hz))):
            n2.beam((x, a[0], a[1]), (x, b[0], b[1]), 0.05, "neon_magenta")
        # A diamond and a dot inside the frame.
        dz = 0.3
        for a, b in (((yc, zc + dz + 0.15), (yc + 0.2, zc + 0.15)), ((yc + 0.2, zc + 0.15), (yc, zc - dz + 0.15)),
                     ((yc, zc - dz + 0.15), (yc - 0.2, zc + 0.15)), ((yc - 0.2, zc + 0.15), (yc, zc + dz + 0.15))):
            n2.beam((x, a[0], a[1]), (x, b[0], b[1]), 0.05, "neon_magenta")
        n2.box((0.05, 0.12, 0.12), (x, yc, zc - 0.5), "neon_magenta")


def tram_shelter():
    """A tram stop: a dark steel frame, a dark glass back and canopy, a
    bench, a lit timetable panel and a warm strip under the canopy's front
    edge; open to +Y."""
    r = lib.root("tram_shelter")
    m = Mesh()
    w, h = 4.4, 2.62
    # Where people walk the stop is laid out to the tram-shelter kind's
    # footprint: its back 0.75 m behind the point (the posts' back faces),
    # the bench to 0.15 m, the end screen's post to 0.40 m; the front is
    # open to the stand.
    yb, yf = -0.69, 1.02
    m.box((w + 0.1, 1.9, 0.08), (0, 0.12, 0.04), "paving_dark", bevel=0.01)
    for x in (-w / 2 + 0.12, 0.0, w / 2 - 0.12):
        m.box((0.1, 0.12, h - 0.08), (x, yb, 0.08 + (h - 0.08) / 2), "frame")
        m.beam((x, yb - 0.3, h + 0.05), (x, yf, h + 0.16), 0.1, "frame", depth=0.16)
    roof = [(yb - 0.35, h + 0.12), (yf + 0.05, h + 0.23), (yf + 0.05, h + 0.27), (yb - 0.35, h + 0.16)]
    m.prism(roof, w + 0.3, (0, 0, 0), "glass", axis="x")
    m.box((w + 0.35, 0.12, 0.14), (0, yf + 0.06, h + 0.2), "steel_dark", bevel=0.01)
    m.box((w + 0.35, 0.12, 0.1), (0, yb - 0.35, h + 0.12), "steel_dark", bevel=0.01)
    m.box((w - 0.3, 0.06, 0.05), (0, yf - 0.02, h + 0.1), "lamp_glow")
    m.box((w - 0.3, 0.05, 0.04), (0, yb + 0.1, h + 0.06), "lamp_glow")
    # The glass back and one end screen.
    m.box((w - 0.3, 0.03, 1.95), (0, yb, 1.28), "glass")
    for z in (0.3, 2.26):
        m.box((w - 0.2, 0.07, 0.06), (0, yb, z), "frame")
    m.box((0.03, 1.0, 1.95), (-w / 2 + 0.12, yb + 0.55, 1.28), "glass")
    for z in (0.3, 2.26):
        m.box((0.07, 1.05, 0.06), (-w / 2 + 0.12, yb + 0.55, z), "frame")
    m.box((0.06, 0.06, 2.0), (-w / 2 + 0.12, yb + 1.06, 1.28), "frame")
    # A timber bench on steel legs along the back.
    m.box((2.36, 0.42, 0.07), (-0.55, yb + 0.33, 0.47), "wood", bevel=0.015)
    m.box((2.36, 0.06, 0.3), (-0.55, yb + 0.1, 0.78), "wood", bevel=0.015)
    for x in (-1.6, 0.5):
        m.box((0.06, 0.36, 0.44), (x, yb + 0.33, 0.3), "frame")
    # The timetable: a lit panel in a dark frame at the open end.
    m.box((0.7, 0.1, 1.35), (1.55, yb + 0.1, 1.28), "steel_dark", bevel=0.02)
    m.box((0.56, 0.03, 1.1), (1.55, yb + 0.16, 1.3), "window_glow")
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
    "lib_roof": lib_roof,
    "lib_banner": lib_banner,
    "tower_a": tower_a,
    "tower_b": tower_b,
    "house_a": house_a,
    "house_b": house_b,
    "house_c": house_c,
    "shop_a": shop_a,
    "tram_shelter": tram_shelter,
}
