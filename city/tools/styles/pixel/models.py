"""Blender models for the 08 pixel-art kit, pre-rendered by render.py.

Every model is written in Godot axes (x east, z south, y up; metres) through
`Model`, which turns them into Blender geometry (x east, y north, z up) with
the low-poly kit's `lib.Mesh`. Faces carry a material key from
palette.MATERIALS, optionally with a variation value (`"leaf|37"`).

KIT lists every render: its model, its outputs (the sprites cut from it by
world cell) and post-processing options. Outputs name the cells they take
({"x"|"z"|"y": [lo, hi]}, inclusive) and their origin point (x, z, y): the
sprite's anchor is where that point lands. Conventions (see kit.json):

* **Façade modules** are 1 m slices of a wall seen from outside. A south
  face (`s_*`) runs along x with its outer face on the line z = Z and the
  wall's thickness behind it (toward -z); its origin is the slice's +x end
  on that line. An east face (`e_*`) runs along z with its outer face on
  x = X; its origin is the slice's +z end. Pairs (`_0`, `_1`) are 2 m bays
  and go in order of increasing x (south) or z (east). A doorway is
  `door_l`, one `door_m` a metre of its width and `door_r`, in that order:
  the opening is clear, and its leaves stand folded in the reveals at
  the ends of `door_l` and `door_r`.
* **The walking band** (0.25-1.9 m up, where people walk into things)
  holds nothing of a wall outside its WALL-deep strip: what stands proud
  (sills, courses, pilasters, cornices) does so above or below it. The
  same goes for every prop: in the band it keeps to its kind's footprint.
* **Roof pieces** have their base (eave) at y = 0: lift them by the wall
  height. **Corners** fill the WALL-square where two walls meet, and
  sit on its centre.
* **Props, blocks and trees** stand on their origin (the ground point that
  sorts them); blocks' origin is their footprint's south-east corner.
* **Tiles** are 1 m ground cells, origin at the cell centre (32 x 16).

This module imports bpy only inside Model, so post.py and the tests can read
KIT without Blender.
"""
import math
import random

WALL = 0.25         # wall thickness behind every façade's outer face (the kind's `wall`)
# The wall's face stands this far back from its outer line, so what is
# flush with the line (sills, plinths, pilasters in the band) still shows.
RECESS = 0.02
# How far a doorway's reveal runs on beyond its opening, where its leaves
# stand folded.
REVEAL = 0.3
BAND_TOP = 1.9      # the walking band's top, above which walls may stand proud
HALL_H = 5.2        # hall eave height (wall top)
LIB_H = 8.0         # library roof level (two storeys); parapet to 8.8
LIB_PARAPET = 8.8
DOME_R = 4.5        # library drum radius

KIT = []


def out(path, cells=None, origin=(0, 0, 0), box=None):
    o = {"path": path, "cells": cells or {}, "origin": list(origin)}
    if box:
        o["box"] = list(box)
    return o


TILE_BOX = (-16, -8, 32, 16)


def add(name, build, outputs, outline=True, params=None, info=None):
    KIT.append({"name": name, "build": build, "outputs": outputs, "outline": outline,
                "params": params or {}, "info": info or {}})


def mv(key, var):
    return f"{key}|{int(var) % 256}"


class Model:
    """Geometry in Godot axes, one Blender object (optionally turned about
    the vertical axis by `turn` degrees, counter-clockwise from above)."""

    def __init__(self):
        import lib  # noqa: F401 (the low-poly kit's Mesh, imported inside Blender)
        self.lib = lib
        self.m = lib.Mesh()
        self.turn = 0.0

    @staticmethod
    def g(x, z, y):
        return (x, -z, y)

    def box(self, x0, x1, z0, z1, y0, y1, mat):
        if x1 - x0 <= 1e-6 or z1 - z0 <= 1e-6 or y1 - y0 <= 1e-6:
            return
        self.m.box((x1 - x0, z1 - z0, y1 - y0), self.g((x0 + x1) / 2, (z0 + z1) / 2, (y0 + y1) / 2), mat)

    def cyl(self, x, z, y0, y1, r, mat, sides=12, r_top=None, cap=True):
        self.m.cylinder(r, y1 - y0, self.g(x, z, (y0 + y1) / 2), mat, sides=sides, radius_top=r_top, cap=cap)

    def sphere(self, x, z, y, r, mat, sub=2, scale=(1, 1, 1), jitter=0.0, seed=0, hemi=False):
        # scale is (x, z, y) like points; Blender's y is Godot's z (north), z is up.
        self.m.sphere(r, self.g(x, z, y), mat, subdivisions=sub, scale=tuple(scale),
                      jitter=jitter, seed=seed, hemisphere=hemi)

    def prism_x(self, profile_zy, x0, x1, mat):
        """A (z, y) profile extruded along x from x0 to x1."""
        self.m.prism([(-z, y) for z, y in profile_zy], x1 - x0, ((x0 + x1) / 2, 0, 0), mat, axis="x")

    def prism_z(self, profile_xy, z0, z1, mat):
        """An (x, y) profile extruded along z from z0 to z1."""
        self.m.prism(list(profile_xy), z1 - z0, (0, -(z0 + z1) / 2, 0), mat, axis="y")

    def wall_s(self, outer_xy, holes_xy, z_face, thick, mat, reveal=None):
        """A wall whose outer face lies on z = z_face (looking south), the
        outline and holes given as (x, y), `thick` deep toward -z."""
        self.m.slab(list(outer_xy), [list(h) for h in holes_xy], thick, (0, -(z_face - thick / 2), 0), mat,
                    axis="y", reveal_mat=reveal)

    def beam(self, p, q, t, mat):
        self.m.beam(self.g(*p), self.g(*q), t, mat)

    def quad(self, pts, mat):
        self.m._faces([self.g(*p) for p in pts], [list(range(len(pts)))], mat)

    def box_yaw(self, cx, cz, cy, sx, sz, sy, mat, yaw):
        """A box centred on (cx, cz, cy), sized (sx along its own x, sz
        along its own z, sy up), turned `yaw` degrees about the vertical
        (from +x toward +z)."""
        from mathutils import Matrix
        self.m.box((sx, sz, sy), self.g(cx, cz, cy), mat, rot=Matrix.Rotation(math.radians(-yaw), 3, "Z"))

    def strip(self, spine, widths, mat, lift=0.0):
        """A flat ribbon along `spine` points (x, z, y), `widths` wide at
        each point, lying horizontal-ish with a slight V fold (fronds)."""
        pts = []
        for k, p in enumerate(spine):
            q = spine[min(k + 1, len(spine) - 1)]
            o = spine[max(k - 1, 0)]
            dx, dz = q[0] - o[0], q[1] - o[1]
            ln = math.hypot(dx, dz) or 1.0
            sx, sz = -dz / ln * widths[k] / 2, dx / ln * widths[k] / 2
            pts.append(((p[0] - sx, p[1] - sz, p[2] - lift * widths[k]), p, (p[0] + sx, p[1] + sz, p[2] - lift * widths[k])))
        for a, b in zip(pts, pts[1:]):
            self.quad([a[0], b[0], b[1], a[1]], mat)
            self.quad([a[1], b[1], b[2], a[2]], mat)

    def dome(self, x, z, y, r, mat, segments=24, rings=8, squash=1.0):
        self.m.dome(r, self.g(x, z, y), mat, segments=segments, rings=rings, squash=squash)

    def build(self, name):
        import bpy
        for key in self.m.mats:
            if key not in bpy.data.materials:
                bpy.data.materials.new(key)
        o = self.m.build(name)
        o.rotation_euler = (0.0, 0.0, math.radians(self.turn))
        return o


# ---------------------------------------------------------------------------
# Façades: strips built looking south (outer face on z = 0, along x), turned
# 90° for the east face (outer face on x = 0, along -z). Every feature stays
# inside its 1 m cell or its 2 m pair, so modules join in any order.
# ---------------------------------------------------------------------------

def facade_outputs(folder, cells_along, turn):
    """Outputs for façade modules cut from a strip. `cells_along` maps a
    module name to the strip's along-cell index. Turned strips (east faces)
    run along -z: along cell j is z cell -(j + 1)."""
    outs = []
    for name, j in cells_along.items():
        if turn:
            outs.append(out(f"{folder}/e_{name}.png", {"z": [-(j + 1), -(j + 1)]}, (0, -j, 0)))
        else:
            outs.append(out(f"{folder}/s_{name}.png", {"x": [j, j]}, (j + 1, 0, 0)))
    return outs


def pair(stem, j0, turn):
    """The two cells of a 2 m bay starting at along cell j0, named in order
    of increasing x (south) or z (east): east strips run the other way."""
    return {f"{stem}_0": j0 + 1, f"{stem}_1": j0} if turn else {f"{stem}_0": j0, f"{stem}_1": j0 + 1}


def walled(m, length, top, holes, mat, reveal=None):
    """A wall slab along x (0..length) with holes, its face RECESS behind
    the outer line; holes that reach the ground split the slab, since a
    slab hole cannot touch its edge."""
    doors = sorted([h for h in holes if min(p[1] for p in h) <= 0.0], key=lambda h: h[0][0])
    windows = [h for h in holes if min(p[1] for p in h) > 0.0]
    edges = [0.0]
    for d in doors:
        xs = [p[0] for p in d]
        edges += [min(xs), max(xs)]
    edges.append(float(length))
    for k in range(0, len(edges), 2):
        a, b = edges[k], edges[k + 1]
        if b - a <= 1e-6:
            continue
        inside = [w for w in windows if a <= min(p[0] for p in w) and max(p[0] for p in w) <= b]
        m.wall_s([(a, 0), (a, top), (b, top), (b, 0)], inside, -RECESS, WALL - RECESS, mat, reveal=reveal or mat)
    for d in doors:
        xs = [p[0] for p in d]
        head = max(p[1] for p in d)
        m.wall_s([(min(xs), head), (min(xs), top), (max(xs), top), (max(xs), head)], [], -RECESS, WALL - RECESS, mat,
                 reveal=reveal or mat)


def doorways(layout):
    """The doorways in a strip's layout: (first opening metre, width) for
    each run of 'O' between an 'L' and an 'R'."""
    out, k = [], 0
    while k < len(layout):
        if layout[k] == "O":
            start = k
            while k < len(layout) and layout[k] == "O":
                k += 1
            out.append((start, k - start))
            continue
        k += 1
    return out


def door_hole(start, width, head):
    """A doorway's hole in its wall: the opening and its reveals, to the head."""
    a, b = start - REVEAL, start + width + REVEAL
    return [(a, 0.0), (a, head), (b, head), (b, 0.0)]


def folded_leaves(m, a, b, head, mats=("frame", "glass_warm")):
    """A doorway's leaves standing open, folded into its reveal from a to b
    along the wall: four panels square to the wall, across its depth."""
    step = (b - a) / 4
    for k in range(4):
        x = a + step * k + step * 0.2
        m.box(x, x + step * 0.6, -WALL + 0.02, -0.02, 0.03, head - 0.05, mats[k % 2])


# ---- The hall: brick, tall factory windows, glazed doors, navy sawtooth ----

HALL_HEAD = 3.3     # a hall doorway's head


def hall_strip(m, layout, low=False):
    """A brick wall along x, one letter per metre: 'W' a 2 m window bay
    (its second metre 'w'), 'L', 'O'... 'R' a doorway (its reveals and a
    metre of opening each), '-' plain."""
    h = HALL_H
    top = 0.6 if low else h
    holes = []
    for j, c in enumerate(layout):
        if low:
            break
        if c == "W":
            w0, w1, sill, head = j + 0.4, j + 1.6, 0.9, 4.1
            m.box(w0, w1, -0.18, -0.08, sill, head, "glass_warm")
            m.box(w0 - 0.08, w1 + 0.08, -0.08, 0.0, sill - 0.14, sill, "stone_light")
            m.box(w0 - 0.12, w1 + 0.12, -0.02, 0.07, head, head + 0.32, "brick_trim")
            holes.append([(w0, sill), (w0, head), (w1, head), (w1, sill)])
        elif c == "L":
            folded_leaves(m, j + 1 - REVEAL, j + 1, HALL_HEAD)
            m.box(j + 1 - REVEAL - 0.12, j + 1, -0.02, 0.07, HALL_HEAD, HALL_HEAD + 0.3, "brick_trim")
        elif c == "R":
            folded_leaves(m, j, j + REVEAL, HALL_HEAD)
            m.box(j, j + REVEAL + 0.12, -0.02, 0.07, HALL_HEAD, HALL_HEAD + 0.3, "brick_trim")
        elif c == "O":
            m.box(j, j + 1, -0.02, 0.07, HALL_HEAD, HALL_HEAD + 0.3, "brick_trim")
            m.box(j, j + 1, -0.02, 0.1, 3.8, 4.5, "sign")
            m.box(j, j + 1, -WALL, 0.8, 0.0, 0.1, "concrete")
    if not low:
        for start, width in doorways(layout):
            holes.append(door_hole(start, width, HALL_HEAD))
    walled(m, len(layout), top, holes, "brick")
    for a, b in plinth_runs(layout, low):
        m.box(a, b, -RECESS - 0.01, 0.0, 0.0, 0.3 if low else 0.45, "plinth")
    if low:
        m.box(0, len(layout), -WALL, 0.0, top, top + 0.1, "brick_trim")
    else:
        m.box(0, len(layout), -WALL, 0.1, h - 0.3, h, "brick_trim")


def plinth_runs(layout, low):
    """Where a strip's plinth runs: along its wall, but not across a
    doorway (its opening and reveals)."""
    if low:
        return [(0.0, float(len(layout)))]
    runs, a = [], 0.0
    for start, width in doorways(layout):
        runs.append((a, start - REVEAL))
        a = start + width + REVEAL
    runs.append((a, float(len(layout))))
    return [(a, b) for a, b in runs if b - a > 1e-6]


DOOR_CELLS = {"door_l": 2, "door_m": 3, "door_r": 5}


def facade(strip, name, folder, turn, kind):
    """One module kind rendered in its own specimen, flanked by plain wall
    (so no neighbour's steps or columns hide any of it), cut at cell 2 (a
    doorway's parts at cells 2, 3 and 5 of a 2 m doorway)."""
    doorway = {"door_l": 5, "door_m": 3, "door_r": 2} if turn else DOOR_CELLS
    layouts = {"plain": ("-----", {"plain": 2}), "low": ("-----", {"low": 2}),
               "wall": ("--Ww--", pair("wall", 2, turn)), "door": ("--LOOR--", doorway),
               "banner": ("--N--", {"banner": 2})}
    layout, cells = layouts[kind]

    def build():
        m = Model()
        m.turn = turn
        strip(m, layout, low=kind == "low")
        return m.build(name)

    add(f"{name}_{kind}_{turn}", build, facade_outputs(folder, cells, turn))


def hall_corner(low=False):
    """The WALL-square where two walls meet, filled to the walls' height."""
    def build():
        m = Model()
        top = 0.6 if low else HALL_H - 0.3
        half = WALL / 2
        m.box(-half, half, -half, half, 0.45 if not low else 0.3, top, "brick")
        m.box(-half, half, -half, half, 0.0, 0.45 if not low else 0.3, "plinth")
        if low:
            m.box(-half, half, -half, half, top, top + 0.1, "brick_trim")
        else:
            m.box(-half - 0.1, half + 0.1, -half - 0.1, half + 0.1, top, top + 0.3, "brick_trim")
        return m.build("hall_corner")
    return build


def hall_roof():
    """One sawtooth tooth, 4 m along x, its eave at y = 0: a navy slope
    rising east to a glazed clerestory looking east, brick gables with a
    lit window at the ends. The specimen covers 6 m of rooms (z -6..0),
    its gables on the walls outside them and its slope over the east wall
    (the tooth's +x end) of a hall whose last tooth it is."""
    rise = 2.4

    def build():
        m = Model()
        z0, z1 = -6.0, 0.0
        tri = [(0.0, 0.0), (4.0, 0.0), (4.0, rise)]
        for za, zb in ((z1, z1 + WALL), (z0 - WALL, z0)):
            m.prism_z(tri, za, zb, "brick")
        # A lit window in the south gable.
        m.prism_z([(2.2, 0.35), (3.6, 0.35), (3.6, 1.95 * 3.6 / 4.0 - 0.1)], z1 + WALL - 0.02, z1 + WALL + 0.03,
                  "glass_warm")
        # The clerestory: glass between mullion posts, over a fascia.
        m.box(3.82, 3.94, z0, z1, 0.0, rise - 0.05, "glass_sky")
        m.box(3.78, 4.02, z0 - WALL, z1 + WALL, -0.05, 0.14, "fascia")
        s = rise / 4.0
        end = 4.0 + WALL + 0.06
        prof = [(-0.3, -0.3 * s - 0.02), (end, end * s + 0.02), (end, end * s + 0.18), (-0.3, -0.3 * s + 0.14)]
        m.prism_z(prof, z0 - WALL - 0.35, z1 + WALL + 0.35, "roof_navy")
        for zz in (z0 - WALL - 0.35, z1 + WALL + 0.35):
            m.beam((-0.3, zz, -0.3 * s + 0.06), (end, zz, end * s + 0.1), 0.14, "fascia")
        return m.build("hall_roof")

    outs = [out("buildings/hall/roof_s.png", {"z": [-1, 0]}, (4, 0, 0)),
            out("buildings/hall/roof_mid.png", {"z": [-3, -3]}, (4, -2, 0)),
            out("buildings/hall/roof_n.png", {"z": [-7, -6]}, (4, -5, 0))]
    return build, outs


# ---- The library: sandstone, arched windows, banners, a navy dome ----

LIB_HEAD = 4.3      # a library doorway's head


def arched(x0, x1, sill, spring, rise, segments=8):
    import lib  # noqa: F401
    return [(x0, sill)] + [((x0 + x1) / 2 - math.cos(math.pi * k / segments) * (x1 - x0) / 2,
                            spring + math.sin(math.pi * k / segments) * rise) for k in range(segments + 1)] + [(x1, sill)]


def arched_outline(x0, x1, sill, spring, rise, segments=8):
    return list(reversed(arched(x0, x1, sill, spring, rise, segments)))


def pilaster(m, a, b, top, proud=0.1):
    """A pilaster from a to b along the wall: flush below the walking
    band's top, where people pass it, standing proud above."""
    m.box(a, b, -RECESS - 0.01, 0.0, 0.7, BAND_TOP, "sand_trim")
    m.box(a, b, -0.02, proud, BAND_TOP, top, "sand_trim")


def lib_strip(m, layout, low=False):
    """A sandstone wall along x: 'W' a 2 m bay of two arched windows
    between paired pilasters (its second metre 'w'), 'L', 'O'... 'R' an
    entrance (its reveals and a metre of opening each), 'N' a banner
    metre, '-' plain."""
    top = 0.8 if low else LIB_PARAPET
    holes = []
    for j, c in enumerate(layout):
        if low:
            break
        if c == "W":
            for sill, spring in ((1.1, 2.9), (4.8, 6.5)):
                w0, w1 = j + 0.52, j + 1.48
                holes.append(arched(w0, w1, sill, spring, 0.48))
                m.wall_s(arched_outline(w0, w1, sill, spring, 0.48), [], -0.16, 0.05, "glass_sky")
                m.box(w0 - 0.08, w1 + 0.08, -0.08 if sill < BAND_TOP else -0.02, 0.0 if sill < BAND_TOP else 0.1,
                      sill - 0.12, sill, "sand_trim")
                m.box(j + 0.93, j + 1.07, -0.02, 0.1, spring + 0.4, spring + 0.68, "sand_trim")  # keystone
            for a in (j + 0.07, j + 1.69):
                pilaster(m, a, a + 0.24, 7.55)
                m.box(a - 0.02, a + 0.26, -0.02, 0.14, 7.2, 7.55, "sand_trim")
        elif c in "LR":
            a = j + 1 - REVEAL if c == "L" else j
            folded_leaves(m, a, a + REVEAL, LIB_HEAD, ("wood_dark", "glass_warm"))
            p = j + 0.3 if c == "L" else j + 0.4
            pilaster(m, p, p + 0.3, 5.0, proud=0.2)
            m.box(p - 0.03, p + 0.33, -0.02, 0.26, 5.0, 5.2, "sand_trim")                   # capital
            e0, e1 = (j + 0.05, j + 1) if c == "L" else (j, j + 0.95)
            m.box(e0, e1, -0.02, 0.4, 5.2, 5.6, "sand_trim")                                 # entablature
        elif c == "O":
            m.box(j, j + 1, -0.2, -0.14, 3.4, LIB_HEAD, "glass_warm")                        # transom
            m.box(j, j + 1, -0.2, -0.1, 3.3, 3.4, "sand_trim")
            m.box(j, j + 1, -0.02, 0.4, 5.2, 5.6, "sand_trim")                               # entablature
            m.box(j, j + 1, 0.0, 0.08, 5.8, 6.5, "sign")                                     # "LIBRARY"
            for dz, yy in ((0.6, 0.08), (0.3, 0.15)):
                m.box(j, j + 1, -WALL, dz, 0.0, yy, "stone_light")                           # steps
        elif c == "N":
            m.box(j + 0.2, j + 0.8, 0.06, 0.12, 2.4, 6.2, "banner")
            m.box(j + 0.2, j + 0.5, 0.06, 0.12, 2.1, 2.4, "banner")
            m.box(j + 0.5, j + 0.8, 0.06, 0.12, 2.25, 2.4, "banner")
            m.box(j + 0.3, j + 0.47, 0.12, 0.14, 3.9, 4.4, "emblem")
            m.box(j + 0.53, j + 0.7, 0.12, 0.14, 3.9, 4.4, "emblem")
            m.box(j + 0.15, j + 0.85, 0.0, 0.16, 6.2, 6.3, "metal")
    if not low:
        for start, width in doorways(layout):
            holes.append(door_hole(start, width, LIB_HEAD))
    walled(m, len(layout), top, holes, "sandstone")
    n = len(layout)
    for a, b in plinth_runs(layout, low):
        m.box(a, b, -RECESS - 0.01, 0.0, 0.0, 0.3 if low else 0.7, "stone")
    if low:
        m.box(0, n, -WALL, 0.0, top, top + 0.1, "sand_trim")
        return
    m.box(0, n, -0.02, 0.1, 3.9, 4.15, "sand_trim")          # string course
    m.box(0, n, -0.02, 0.24, 7.55, 8.0, "sand_trim")          # cornice
    m.box(0, n, -WALL - 0.04, 0.08, top, top + 0.14, "sand_trim")  # coping


def lib_corner(low=False):
    """The WALL-square where two walls meet, filled to the walls' height,
    its courses standing proud above the walking band."""
    def build():
        m = Model()
        top = 0.8 if low else LIB_PARAPET
        half = WALL / 2
        m.box(-half, half, -half, half, 0.7 if not low else 0.3, top, "sand_trim")
        m.box(-half, half, -half, half, 0.0, 0.7 if not low else 0.3, "stone")
        if not low:
            m.box(-half - 0.1, half + 0.1, -half - 0.1, half + 0.1, 3.9, 4.15, "sand_trim")
            m.box(-half - 0.24, half + 0.24, -half - 0.24, half + 0.24, 7.55, 8.0, "sand_trim")
            m.box(-half - 0.04, half + 0.08, -half - 0.04, half + 0.08, top, top + 0.14, "sand_trim")
        else:
            m.box(-half, half, -half, half, top, top + 0.1, "sand_trim")
        return m.build("lib_corner")
    return build


def lib_dome():
    """The drum, dome and lantern, standing on the roof at y = 0."""
    drum_h, ring = 2.2, 0.28
    base = drum_h + ring

    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.35, DOME_R + 0.3, "stone", sides=40)
        m.cyl(0, 0, 0.35, drum_h, DOME_R, "sandstone", sides=40)
        m.cyl(0, 0, drum_h, base, DOME_R + 0.22, "sand_trim", sides=40)
        for k in range(20):
            a = 2 * math.pi * (k + 0.5) / 20
            m.box_yaw(math.cos(a) * (DOME_R + 0.02), math.sin(a) * (DOME_R + 0.02), 1.3, 0.12, 0.5, 1.1,
                      "glass_sky", yaw=math.degrees(a))
            m.box_yaw(math.cos(a) * (DOME_R + 0.05), math.sin(a) * (DOME_R + 0.05), 1.3, 0.12, 0.18, 1.5,
                      "sand_trim", yaw=math.degrees(a) + 0)
        m.dome(0, 0, base, DOME_R - 0.1, "dome", segments=48, rings=14, squash=0.92)
        top = base + (DOME_R - 0.1) * 0.92
        m.cyl(0, 0, top - 0.25, top + 0.55, 0.7, "sand_trim", sides=16)
        m.cyl(0, 0, top + 0.55, top + 0.85, 0.85, "fascia", sides=16, r_top=0.2)
        m.cyl(0, 0, top + 0.85, top + 1.25, 0.06, "metal", sides=6)
        return m.build("lib_dome")

    return build, {"dome_centre": [0.0, 0.0, base], "dome_radius": DOME_R - 0.1}


def roof_tile(mat):
    def build():
        m = Model()
        m.quad([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], mat)
        return m.build("roof")
    return build


for _turn in (0, 90):
    for _kind in ("wall", "door", "plain", "low"):
        facade(hall_strip, "hall_facade", "buildings/hall", _turn, _kind)
    for _kind in ("wall", "door", "banner", "plain", "low"):
        facade(lib_strip, "lib_facade", "buildings/library", _turn, _kind)
add("hall_corner", hall_corner(), [out("buildings/hall/corner.png")])
add("hall_corner_low", hall_corner(True), [out("buildings/hall/corner_low.png")])
_b, _o = hall_roof()
add("hall_roof", _b, _o)
add("lib_corner", lib_corner(), [out("buildings/library/corner.png")])
add("lib_corner_low", lib_corner(True), [out("buildings/library/corner_low.png")])
_b, _p = lib_dome()
add("lib_dome", _b, [out("buildings/library/dome.png")], params=_p)
add("lib_roof", roof_tile("roof_flat"), [out("buildings/library/roof.png", None, (0.5, 0.5, 0), TILE_BOX)], outline=False)


# ---------------------------------------------------------------------------
# Blocks: background buildings, whole or stacked; origin at the footprint's
# south-east ground corner, footprint toward -x and -z.
# ---------------------------------------------------------------------------

def ring(m, x0, x1, z0, z1, y0, y1, t, mat):
    """A rectangular wall ring (parapet) `t` thick inside the rectangle."""
    m.box(x0, x1, z1 - t, z1, y0, y1, mat)
    m.box(x0, x1, z0, z0 + t, y0, y1, mat)
    m.box(x0, x0 + t, z0 + t, z1 - t, y0, y1, mat)
    m.box(x1 - t, x1, z0 + t, z1 - t, y0, y1, mat)


def windows_on(m, w, d, y0, y1, every, width, mat="glass_sky", sill="stone_light", south=True, east=True):
    if south:
        a = -w + every / 2
        while a < -0.3:
            m.box(a - width / 2, a + width / 2, -0.02, 0.04, y0, y1, mat)
            m.box(a - width / 2 - 0.06, a + width / 2 + 0.06, -0.02, 0.1, y0 - 0.1, y0, sill)
            a += every
    if east:
        a = -d + every / 2
        while a < -0.3:
            m.box(-0.02, 0.04, a - width / 2, a + width / 2, y0, y1, mat)
            m.box(-0.02, 0.1, a - width / 2 - 0.06, a + width / 2 + 0.06, y0 - 0.1, y0, sill)
            a += every


def roof_garden(m, w, d, y, seed, trees=3):
    rng = random.Random(seed)
    m.box(-w + 0.6, -w + 1.8, -d + 0.6, -d + 1.6, y, y + 0.9, "concrete")      # stair hut
    m.box(-1.6, -0.7, -d + 0.8, -d + 1.5, y, y + 0.5, "metal_light")           # AC unit
    for k in range(trees):
        x = -w + 1.2 + rng.uniform(0, w - 2.4)
        z = -d + 2.2 + rng.uniform(0, d - 3.2)
        m.box(x - 0.5, x + 0.5, z - 0.5, z + 0.5, y, y + 0.35, "wood")
        for c in range(4):
            m.sphere(x + rng.uniform(-0.3, 0.3), z + rng.uniform(-0.3, 0.3), y + 0.6 + rng.uniform(0, 0.3),
                     rng.uniform(0.35, 0.5), mv("shrub", rng.randrange(256)), sub=1, scale=(1, 1, 0.85),
                     jitter=0.1, seed=seed * 7 + k * 5 + c)


def house(w, d, storeys, wall, seed, shop=False):
    def build():
        m = Model()
        h = storeys * 3.1 + 0.3
        m.box(-w, 0, -d, 0, 0.0, h, wall)
        m.box(-w - 0.05, 0.05, -d - 0.05, 0.05, 0.0, 0.4, "stone")
        m.quad([(-w, -d, h + 0.003), (0, -d, h + 0.003), (0, 0, h + 0.003), (-w, 0, h + 0.003)], "roof_flat")
        ring(m, -w, 0, -d, 0, h, h + 0.5, 0.25, wall)
        ring(m, -w - 0.1, 0.1, -d - 0.1, 0.1, h + 0.5, h + 0.64, 0.42, "white_frame")
        first = 1
        if shop:
            m.box(-w + 0.3, -0.3, -0.04, 0.02, 0.4, 2.7, "glass_warm")
            m.box(-w + 0.2, -0.2, -0.02, 0.1, 2.7, 3.0, "white_frame")
            prof = [(0.0, 3.2), (1.2, 2.6), (1.2, 2.45), (0.0, 3.05)]
            m.prism_x(prof, -w + 0.15, -0.15, "awning")
            m.box(-w + 0.6, -0.6, 0.0, 0.06, 3.3, 3.8, "sign")
            windows_on(m, w, d, 0.9, 2.4, 1.7, 0.9, south=False)
        else:
            m.box(-w * 0.5 - 0.45, -w * 0.5 + 0.45, -0.03, 0.03, 0.4, 2.5, "wood")
            m.box(-w * 0.5 - 0.6, -w * 0.5 + 0.6, 0.0, 0.5, 2.6, 2.75, "white_frame")
            windows_on(m, w, d, 1.0, 2.4, 1.7, 0.9, south=False)
            for a in (-w + 0.85, -0.85):
                m.box(a - 0.45, a + 0.45, -0.02, 0.04, 1.0, 2.4, "glass_sky")
        for s in range(first, storeys):
            y = s * 3.1 + 0.9
            windows_on(m, w, d, y, y + 1.4, 1.7, 0.9)
            m.box(-w - 0.04, 0.04, -d - 0.04, 0.04, s * 3.1 + 0.25, s * 3.1 + 0.4, "white_frame")
        roof_garden(m, w, d, h + 0.003, seed)
        return m.build("house")
    return build


TOWER = 12
TOWER_BASE, TOWER_STOREY, TOWER_MIDS = 4, 3, 4
TOWER_TOP = TOWER_BASE + TOWER_STOREY * TOWER_MIDS


def tower():
    """A glazed tower in stackable pieces: a 4 m lobby storey, 3 m storeys
    and a roof with a garden, cut from one specimen by height."""
    w = d = TOWER

    def build():
        m = Model()
        # Lobby.
        m.box(-w + 0.6, -0.6, -d + 0.6, -0.6, 0.0, TOWER_BASE, "glass_warm")
        for a in range(0, w + 1, 3):
            x = -w + a
            m.box(x - 0.3, x + 0.3, -0.6, 0.0, 0.0, TOWER_BASE, "render_sand")
            m.box(-0.6, 0.0, x - 0.3, x + 0.3, 0.0, TOWER_BASE, "render_sand")
        m.box(-w, 0, -d, 0, TOWER_BASE - 0.5, TOWER_BASE, "render_sand")
        m.box(-w * 0.5 - 1.5, -w * 0.5 + 1.5, -0.2, 1.3, 3.0, 3.2, "fascia")        # entrance canopy
        # Storeys: glass curtain between white fins and floor bands.
        for s in range(TOWER_MIDS):
            y0 = TOWER_BASE + s * TOWER_STOREY
            m.box(-w + 0.25, -0.25, -d + 0.25, -0.25, y0, y0 + TOWER_STOREY, "glass_tower")
            m.box(-w, 0, -d, 0, y0, y0 + 0.45, "render_sand")
            for a in range(0, w + 1, 3):
                x = -w + a
                m.box(x - 0.18, x + 0.18, -0.35, 0.0, y0, y0 + TOWER_STOREY, "white_frame")
                m.box(-0.35, 0.0, x - 0.18, x + 0.18, y0, y0 + TOWER_STOREY, "white_frame")
        # Roof: parapet, garden, plant room.
        y = TOWER_TOP
        m.box(-w, 0, -d, 0, y, y + 0.2, "render_sand")
        m.quad([(-w, -d, y + 0.203), (0, -d, y + 0.203), (0, 0, y + 0.203), (-w, 0, y + 0.203)], "roof_flat")
        ring(m, -w, 0, -d, 0, y + 0.2, y + 0.9, 0.3, "render_sand")
        ring(m, -w - 0.1, 0.1, -d - 0.1, 0.1, y + 0.9, y + 1.05, 0.5, "white_frame")
        m.box(-w + 2.5, -w + 7.0, -d + 2.0, -d + 6.0, y, y + 3.0, "render_sand")
        m.box(-w + 2.3, -w + 7.2, -d + 1.8, -d + 6.2, y + 3.0, y + 3.2, "white_frame")
        rng = random.Random(41)
        for k in range(9):
            x = -w + 1.5 + rng.uniform(0, w - 3.0)
            z = -d + 7.0 + rng.uniform(0, d - 8.5) if k % 2 else -d + 1.5 + rng.uniform(0, d - 3.0)
            if -w + 2.0 < x < -w + 7.6 and z < -d + 6.6:
                continue
            m.box(x - 0.7, x + 0.7, z - 0.7, z + 0.7, y + 0.2, y + 0.6, "wood")
            for c in range(5):
                m.sphere(x + rng.uniform(-0.5, 0.5), z + rng.uniform(-0.5, 0.5), y + 1.0 + rng.uniform(0, 0.6),
                         rng.uniform(0.5, 0.75), mv("shrub", rng.randrange(256)), sub=2, scale=(1, 1, 0.85),
                         jitter=0.12, seed=300 + k * 9 + c)
        return m.build("tower")

    mid0 = TOWER_BASE + TOWER_STOREY
    outs = [out("buildings/blocks/tower_base.png", {"y": [0, TOWER_BASE - 1]}, (0, 0, 0)),
            out("buildings/blocks/tower_mid.png", {"y": [mid0, mid0 + TOWER_STOREY - 1]}, (0, 0, mid0)),
            out("buildings/blocks/tower_top.png", {"y": [TOWER_TOP, 99]}, (0, 0, TOWER_TOP))]
    return build, outs


# Where a house or shop stands in the walking band about its south-east
# corner, [x0, x1, z0, z1] (its plinth all round, the ground floor's east
# sills 10 cm proud); the tower's lobby columns stand 0.3 m out at its
# far corners.
def house_band(w, d):
    return [-w - 0.05, 0.1, -d - 0.05, 0.05]


add("house_a", house(5, 5, 2, "render_sand", 11), [out("buildings/blocks/house_a.png")],
    info={"footprint": [5, 5], "storeys": 2, "band": house_band(5, 5)})
add("house_b", house(5, 5, 3, "render_warm", 12), [out("buildings/blocks/house_b.png")],
    info={"footprint": [5, 5], "storeys": 3, "band": house_band(5, 5)})
add("house_c", house(5, 5, 2, "brick", 13), [out("buildings/blocks/house_c.png")],
    info={"footprint": [5, 5], "storeys": 2, "band": house_band(5, 5)})
add("shop_a", house(5, 4, 2, "render_warm", 14, shop=True), [out("buildings/blocks/shop_a.png")],
    info={"footprint": [5, 4], "storeys": 2, "band": house_band(5, 4)})
_b, _o = tower()
add("tower", _b, _o, info={"footprint": [TOWER, TOWER], "base": TOWER_BASE, "storey": TOWER_STOREY,
                           "band": [-TOWER - 0.3, 0.0, -TOWER - 0.3, 0.0]})


# A block's garden wall, laid a metre at a time along the inside of its
# lot's edges, and its closed gate toward the street: how high and thick
# the wall stands, the gate's leaf and its posts (as the 3D kits' KitTown).
GARDEN_WALL_H = 1.1
GARDEN_WALL_T = 0.2
GATE_W = 1.2
GATE_POST = 0.3
GATE_POST_H = 1.35


def garden_wall(turn):
    """A metre of garden wall along x about its middle, before it turns."""
    def build():
        m = Model()
        m.turn = turn
        t = GARDEN_WALL_T / 2
        m.box(-0.5, 0.5, -t, t, 0.0, GARDEN_WALL_H - 0.08, "render_sand")
        m.box(-0.5, 0.5, -t, t, GARDEN_WALL_H - 0.08, GARDEN_WALL_H, "stone_light")
        return m.build("garden_wall")
    return build


def garden_gate(turn):
    """Two metres of garden wall about its middle holding a closed gate:
    two sandstone posts either side of a shut timber leaf, all within the
    wall's thickness, so the lot stays closed where people walk."""
    def build():
        m = Model()
        m.turn = turn
        t = GARDEN_WALL_T / 2
        half = GATE_W / 2 + GATE_POST
        for sgn in (-1, 1):
            a, b = sorted((sgn * half, sgn * 1.0))
            m.box(a, b, -t, t, 0.0, GARDEN_WALL_H - 0.08, "render_sand")
            m.box(a, b, -t, t, GARDEN_WALL_H - 0.08, GARDEN_WALL_H, "stone_light")
            a, b = sorted((sgn * GATE_W / 2, sgn * half))
            m.box(a, b, -t, t, 0.0, GATE_POST_H, "sandstone")
            m.box(a - 0.02, b + 0.02, -t - 0.02, t + 0.02, GATE_POST_H, GATE_POST_H + 0.06, "stone_light")
        m.box(-GATE_W / 2, GATE_W / 2, -0.03, 0.03, 0.06, 1.0, "wood")
        for x in (-0.3, 0.0, 0.3):
            m.box(x - 0.02, x + 0.02, -0.03, 0.03, 1.0, 1.08, "wood")
        return m.build("garden_gate")
    return build


add("garden_wall_x", garden_wall(0), [out("scenery/garden_wall_x.png")])
add("garden_wall_z", garden_wall(90), [out("scenery/garden_wall_z.png")])
add("garden_gate_x", garden_gate(0), [out("scenery/garden_gate_x.png")])
add("garden_gate_z", garden_gate(90), [out("scenery/garden_gate_z.png")])


# ---------------------------------------------------------------------------
# Trees and plants: standing on their origin.
# ---------------------------------------------------------------------------

def crown(m, cx, cz, base, radius, height, seed, clumps=None, mat="leaf", clump=0.5):
    """A dense crown like the sheet's: small leaf clusters over the shell
    of an ellipsoid (each lit on its own, so it reads as a cluster with a
    bright top and a dark underside), over a dark core that fills the gaps."""
    rng = random.Random(seed)
    cy = base + height / 2
    ry = height / 2
    m.sphere(cx, cz, cy, radius * 0.9, "leaf_dark", sub=2, scale=(1, 1, ry / radius * 0.95), jitter=0.05, seed=seed)
    n = clumps or int(11 * radius * radius + 14)
    golden = math.pi * (3 - math.sqrt(5))
    for k in range(n):
        v = 1 - 2 * (k + 0.5) / n            # -1 (bottom) .. 1 (top)
        if v < -0.55:
            continue
        rho = math.sqrt(1 - v * v)
        a = golden * k + rng.uniform(-0.2, 0.2)
        rr = clump * rng.uniform(0.8, 1.2) * (1.0 + 0.25 * (radius > 3))
        x = cx + math.cos(a) * rho * (radius - rr * 0.35)
        z = cz + math.sin(a) * rho * (radius - rr * 0.35)
        y = cy + v * (ry - rr * 0.3)
        # The cluster's variation value carries its place on the crown
        # toward the sun, so the crown as a whole is lit, not just each
        # cluster (post.py turns it into lightness).
        d = (math.cos(a) * rho, math.sin(a) * rho, v)
        lit = (-0.42 * d[0] + 0.62 * d[1] + 1.0 * d[2]) / 1.27
        var = 128 + 127 * max(-1.0, min(0.0, lit - 0.35)) + rng.uniform(-12, 12)
        m.sphere(x, z, y, rr, mv(mat, var), sub=2, scale=(1, 1, 0.85), jitter=0.24, seed=seed * 97 + k)


def tree_round(seed, radius=2.1, height=5.8, lobes=9):
    def build():
        m = Model()
        m.cyl(0, 0, 0, height * 0.5, 0.2, "trunk", sides=8, r_top=0.13)
        rng = random.Random(seed)
        for k in range(3):
            a = rng.uniform(0, 2 * math.pi)
            m.beam((0, 0, height * 0.35), (math.cos(a) * 0.8, math.sin(a) * 0.8, height * 0.6), 0.12, "trunk")
        crown(m, 0, 0, height * 0.32, radius, height * 0.66, seed)
        return m.build("tree")
    return build


def tree_square():
    """The square's big banyan-like tree: a broad crown on a thick,
    buttressed trunk whose limbs show beneath it."""
    def build():
        m = Model()
        m.cyl(0, 0, 0, 4.6, 0.7, "trunk", sides=12, r_top=0.45)
        rng = random.Random(77)
        for k in range(6):
            a = 2 * math.pi * k / 6 + rng.uniform(-0.2, 0.2)
            m.beam((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.0), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1.1), 0.34, "trunk")
        for k in range(5):
            a = 2 * math.pi * k / 5 + 0.3
            r = rng.uniform(2.0, 2.8)
            m.beam((0, 0, 3.0), (math.cos(a) * r, math.sin(a) * r, 5.4), 0.36, "trunk")
        crown(m, 0, 0, 4.2, 4.6, 5.6, 78, clump=0.52)
        return m.build("tree_square")
    return build


# Trunks stand upright to here before they lean, so a trunk keeps to its
# kind's 25 cm disc where people walk (and a little above).
UPRIGHT = 2.4


def palm(seed, height=6.5, lean=0.9, fronds=9):
    def build():
        m = Model()
        rng = random.Random(seed)
        a = rng.uniform(0, 2 * math.pi)
        ys = sorted({height * k / 8 for k in range(9)} | {UPRIGHT})
        pts = []
        for y in ys:
            t = max(0.0, (y - UPRIGHT) / (height - UPRIGHT))
            pts.append((math.cos(a) * lean * t * t, math.sin(a) * lean * t * t, y))
        for p, q in zip(pts, pts[1:]):
            r = 0.2 - 0.07 * p[2] / height
            m.cyl((p[0] + q[0]) / 2, (p[1] + q[1]) / 2, p[2], q[2] + 0.02, r, "palm_trunk", sides=7)
        tx, tz, ty = pts[-1]
        for k in range(fronds):
            b = 2 * math.pi * k / fronds + rng.uniform(-0.15, 0.15)
            length = rng.uniform(2.4, 3.0)
            spine, widths = [], []
            for s in range(7):
                t = s / 6
                droop = 0.9 * t * t * length * 0.55 - 0.35 * t
                spine.append((tx + math.cos(b) * length * t, tz + math.sin(b) * length * t, ty + 0.2 - droop))
                widths.append(0.18 + 0.5 * math.sin(math.pi * min(t * 1.2, 1.0)))
            m.strip(spine, widths, mv("palm", rng.randrange(256)), lift=0.25)
        for k in range(3):
            c = 2 * math.pi * k / 3
            m.sphere(tx + math.cos(c) * 0.2, tz + math.sin(c) * 0.2, ty - 0.15, 0.13, "wood", sub=1)
        return m.build("palm")
    return build


def shrub(seed, r=1.06):
    """A clipped bush mass as wide as the shrub kind's disc (105 cm; a
    32-sided drum whose flats lie a hair inside r), rounding over, with
    leafy lobes on top inside its circle."""
    def build():
        m = Model()
        rng = random.Random(seed)
        m.cyl(0, 0, 0.0, 0.42, r, mv("shrub", 70), sides=32)
        m.cyl(0, 0, 0.42, 0.52, r - 0.12, mv("shrub", 110), sides=32)
        for k in range(7):
            a = 2 * math.pi * k / 7 + rng.uniform(-0.1, 0.1)
            m.sphere(math.cos(a) * 0.55, math.sin(a) * 0.55, 0.6 + rng.uniform(0, 0.12), 0.38,
                     mv("shrub", rng.randrange(256)), sub=2, scale=(1, 1, 0.85), jitter=0.1, seed=seed + k)
        m.sphere(0, 0, 0.85, 0.5, mv("shrub", rng.randrange(256)), sub=2, jitter=0.1, seed=seed + 9)
        return m.build("shrub")
    return build


add("tree_round_a", tree_round(3), [out("scenery/tree_round_a.png")])
add("tree_round_b", tree_round(5, radius=1.8, height=5.0), [out("scenery/tree_round_b.png")])
add("tree_square", tree_square(), [out("scenery/tree_square.png")])
add("palm_tall", palm(21, 7.2, 1.2), [out("scenery/palm_tall.png")])
add("palm_short", palm(22, 4.6, 0.6, fronds=8), [out("scenery/palm_short.png")])
add("shrub", shrub(31), [out("scenery/shrub.png")])


# ---------------------------------------------------------------------------
# Props
# ---------------------------------------------------------------------------

def lamp():
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.35, 0.16, "metal", sides=8, r_top=0.11)
        m.cyl(0, 0, 0.35, 3.0, 0.065, "metal", sides=6)
        m.cyl(0, 0, 2.95, 3.05, 0.14, "metal", sides=8)
        m.cyl(0, 0, 3.05, 3.5, 0.2, "lamp", sides=8, r_top=0.24)
        m.cyl(0, 0, 3.5, 3.72, 0.3, "metal", sides=8, r_top=0.05)
        m.cyl(0, 0, 3.72, 3.85, 0.04, "metal", sides=6)
        return m.build("lamp")
    return build


def bench(turn):
    def build():
        m = Model()
        m.turn = turn
        for k in range(4):
            z = -0.2 + k * 0.1
            m.box(-0.9, 0.9, z, z + 0.08, 0.42, 0.48, "wood")
        for k in range(3):
            y = 0.58 + k * 0.12
            m.box(-0.9, 0.9, -0.3, -0.24, y, y + 0.08, "wood")
        for x in (-0.8, 0.8):
            m.box(x - 0.04, x + 0.04, -0.28, 0.18, 0.0, 0.42, "metal")
            m.box(x - 0.04, x + 0.04, -0.3, -0.24, 0.42, 0.95, "metal")
            m.box(x - 0.04, x + 0.04, -0.28, 0.2, 0.6, 0.66, "metal")
        return m.build("bench")
    return build


def cafe_set():
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.05, 0.25, "metal", sides=8)
        m.cyl(0, 0, 0.05, 0.72, 0.04, "metal", sides=6)
        m.cyl(0, 0, 0.72, 0.77, 0.42, "stone_light", sides=16)
        for x in (-0.7, 0.7):
            m.box(x - 0.2, x + 0.2, -0.2, 0.2, 0.42, 0.47, "wood")
            bx = x - 0.2 if x < 0 else x + 0.16
            m.box(bx, bx + 0.04, -0.2, 0.2, 0.47, 0.9, "wood")
            for dx in (-0.16, 0.16):
                for dz in (-0.16, 0.16):
                    m.box(x + dx - 0.02, x + dx + 0.02, dz - 0.02, dz + 0.02, 0.0, 0.42, "metal")
        return m.build("cafe_set")
    return build


def umbrella():
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.1, 0.25, "metal", sides=8)
        m.cyl(0, 0, 0.1, 2.5, 0.035, "metal", sides=6)
        m.cyl(0, 0, 2.05, 2.55, 1.35, "awning", sides=16, r_top=0.02, cap=False)
        m.cyl(0, 0, 2.55, 2.7, 0.05, "metal", sides=6)
        return m.build("umbrella")
    return build, {"stripes": "angle", "stripe_centre": [0.0, 0.0], "stripe_count": 16}


def bollard():
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.8, 0.1, "metal", sides=8)
        m.cyl(0, 0, 0.62, 0.7, 0.105, "lamp", sides=8)
        m.sphere(0, 0, 0.8, 0.1, "metal", sub=1)
        return m.build("bollard")
    return build


def railing(turn):
    """One metre of railing where walkable ground ends, along x before it
    turns: a stone kerb, a dark iron post at its -x end and a mid rail,
    and a white handrail at 1 m; open between the rails, so the ground
    shows through at 16 px a metre. Laid a metre at a time, so each slice sorts at
    its own ground point; a railing_post closes a run."""
    def build():
        m = Model()
        m.turn = turn
        m.box(-0.5, 0.5, -0.07, 0.07, 0.0, 0.08, "stone_light")
        m.box(-0.5, -0.42, -0.04, 0.04, 0.08, 1.02, "metal")
        m.box(-0.5, 0.5, -0.035, 0.035, 0.94, 1.02, "paint_white")
        m.box(-0.5, 0.5, -0.02, 0.02, 0.5, 0.56, "metal")
        return m.build("railing")
    return build


def railing_post():
    def build():
        m = Model()
        m.box(-0.07, 0.07, -0.07, 0.07, 0.0, 0.08, "stone_light")
        m.box(-0.04, 0.04, -0.04, 0.04, 0.08, 1.02, "metal")
        m.box(-0.055, 0.055, -0.055, 0.055, 1.02, 1.07, "paint_white")
        return m.build("railing_post")
    return build


# The drawn rectangles of the fitted props about their point, metres
# (CityGeometry.drawn_rect at a 25 cm snap, facing 0): each kind's
# footprint, its edges moved out to 2.5 cm past the cells the grid blocks
# round it (a cell's centre lies at its corner plus 12 cm, so the lot is
# a centimetre lopsided), which is what the prop fills where people walk.
PLANTER = (-0.655, 0.65)                    # 130 x 130 cm, x and z
FLOWERBED = ((-1.655, 1.645), (-0.655, 0.645))  # 310 x 110 cm
WORKBENCH_Z = (-0.655, 0.645)               # 120 cm deep; 2 m a module along x


def planter(square=True):
    def build():
        m = Model()
        if square:
            lo, hi = PLANTER
            m.box(lo + 0.05, hi - 0.05, lo + 0.05, hi - 0.05, 0.0, 0.55, "sand_trim")
            m.box(lo, hi, lo, hi, 0.5, 0.6, "stone_light")
            m.box(lo + 0.13, hi - 0.13, lo + 0.13, hi - 0.13, 0.55, 0.58, "soil")
            rng = random.Random(51)
            for k in range(6):
                a = 2 * math.pi * k / 6
                m.sphere(math.cos(a) * 0.26, math.sin(a) * 0.26, 0.85 + rng.uniform(0, 0.15), 0.32,
                         mv("shrub", rng.randrange(256)), sub=2, scale=(1, 1, 0.9), jitter=0.1, seed=60 + k)
            m.sphere(0, 0, 1.1, 0.34, mv("flowers", 90), sub=2, jitter=0.1, seed=69)
        else:
            m.cyl(0, 0, 0.0, 0.6, 0.3, "terracotta", sides=12, r_top=0.4)
            m.cyl(0, 0, 0.6, 0.68, 0.44, "terracotta", sides=12)
            for k in range(6):
                b = 2 * math.pi * k / 6
                spine = [(math.cos(b) * 0.9 * t, math.sin(b) * 0.9 * t, 0.7 + 0.9 * t - 0.8 * t * t) for t in
                         (0, 0.25, 0.5, 0.75, 1.0)]
                m.strip(spine, [0.1, 0.3, 0.34, 0.26, 0.08], mv("palm", k * 40), lift=0.2)
        return m.build("planter")
    return build


def flowerbed(turn=0):
    """The flowerbed kind's bed along x before it turns to its facing,
    stone-kerbed (the kerb 0.3 m, where people walk) and planted."""
    def build():
        m = Model()
        m.turn = -turn
        (x0, x1), (z0, z1) = FLOWERBED
        m.box(x0, x1, z0, z1, 0.0, 0.3, "stone_light")
        m.box(x0 + 0.1, x1 - 0.1, z0 + 0.1, z1 - 0.1, 0.3, 0.33, "soil")
        rng = random.Random(61)
        for k in range(13):
            x = x0 + 0.35 + (x1 - x0 - 0.7) * k / 12 + rng.uniform(-0.05, 0.05)
            z = rng.uniform(-0.2, 0.2)
            m.sphere(x, z, 0.45, rng.uniform(0.22, 0.3), mv("flowers", rng.randrange(256)), sub=2, scale=(1, 1, 0.8),
                     jitter=0.12, seed=70 + k)
        return m.build("flowerbed")
    return build


def tram_shelter(turn=0):
    """A 4.3 m stop in the tram-shelter kind's frame, before it turns to
    its facing: its back to -z, open toward its stand (+z). Where people
    walk it is the kind's footprint: posts along the glass back, a bench
    to 15 cm in front of it, the lit timetable at the bench's open end
    and a glass end screen at +x, its post reaching 40 cm forward; the
    navy canopy stands above."""
    def build():
        m = Model()
        m.turn = -turn
        for x in (-2.1, 0.0, 2.1):
            m.box(x - 0.05, x + 0.05, -0.75, -0.55, 0.0, 2.6, "metal")
        m.box(-2.15, 2.15, -0.68, -0.62, 0.3, 2.3, "glass_sky")
        m.box(-2.15, 2.15, -0.7, -0.6, 0.0, 0.3, "metal")
        m.box(-2.3, 2.3, -0.9, 0.55, 2.6, 2.75, "roof_navy")
        m.box(-2.3, 2.3, 0.51, 0.59, 2.45, 2.75, "fascia")
        m.box(-0.65, 1.75, -0.55, -0.15, 0.42, 0.48, "wood")
        for x in (-0.55, 1.65):
            m.box(x - 0.03, x + 0.03, -0.5, -0.2, 0.0, 0.42, "metal")
        m.box(-1.9, -1.2, -0.55, -0.5, 1.0, 2.0, "glass_warm")
        m.box(-1.58, -1.52, -0.55, -0.5, 0.0, 1.0, "metal")
        m.box(2.05, 2.1, -0.55, 0.3, 0.3, 2.3, "glass_sky")
        m.box(2.0, 2.15, 0.3, 0.4, 0.0, 2.6, "metal")
        return m.build("tram_shelter")
    return build


def workbench():
    """Two metres of the workshop's bench (laid end to end along its
    footprint), as deep as the footprint's drawn rectangle."""
    def build():
        m = Model()
        z0, z1 = WORKBENCH_Z
        m.box(-1.0, 1.0, z0, z1, 0.82, 0.92, "wood")
        for x in (-0.92, 0.92):
            for z in (z0 + 0.08, z1 - 0.08):
                m.box(x - 0.05, x + 0.05, z - 0.05, z + 0.05, 0.0, 0.82, "wood_dark")
        m.box(-0.95, 0.95, z0 + 0.05, z1 - 0.05, 0.2, 0.26, "wood_dark")
        m.box(-0.85, -0.45, -0.3, 0.1, 0.92, 1.12, "metal_light")          # a toolbox
        m.box(0.2, 0.75, -0.45, -0.4, 0.95, 1.35, "glass_dark")            # a screen
        m.box(0.44, 0.5, -0.43, -0.37, 0.92, 0.97, "metal")
        m.box(-0.2, 0.1, 0.05, 0.3, 0.92, 1.0, "tram_red")                # a part being built
        m.box(-0.95, 0.95, z0, z0 + 0.06, 0.92, 1.7, "wood_dark")         # pegboard
        for k in range(4):
            x = -0.8 + k * 0.4
            m.box(x, x + 0.06, z0 + 0.06, z0 + 0.1, 1.2, 1.55, "metal")
        return m.build("workbench")
    return build


# ---- Seats: the occupant sits on the origin, facing north (-z) before
# the model turns to its facing (8 facings, 45 degrees apart). ----

FACINGS = (0, 45, 90, 135, 180, 225, 270, 315)
# Benches are also rendered at the facings of the square's ring of ten,
# 36 degrees apart, so each is drawn at its own facing, not the nearest
# eighth.
BENCH_FACINGS = tuple(sorted(set(FACINGS) | {36 * k for k in range(10)}))


def chair(m, mat="wood", back=True, arms=None):
    m.box(-0.22, 0.22, -0.2, 0.22, 0.42, 0.48, mat)
    for dx in (-0.18, 0.18):
        for dz in (-0.16, 0.18):
            m.box(dx - 0.025, dx + 0.025, dz - 0.025, dz + 0.025, 0.0, 0.42, "metal")
    if back:
        m.box(-0.22, 0.22, 0.18, 0.24, 0.48, 0.95, mat)


# A workstation's screen, as the 3D kits draw it (usables.DISPLAY): the
# middle of its face (x, z, y, metres about the sitter's place, before the
# seat's turn), its size (width, height), and the way it looks relative to
# the seat (180: back at the sitter), for the pack to light.
WORKSTATION_SCREEN = {"at": [0.0, -0.895, 1.02], "size": [0.54, 0.3], "facing": 180}


def seat_model(kind):
    """A seat's whole furniture, fitted to its kind's footprint where people
    walk, the sitter's own chair or seat inside the square 25 cm about the
    seat point (which the sitter's own furniture may fill): a bench of the
    3D kits' own size (1.6 m, its seat from the square's front edge and its
    back 0.27 m behind the sitter); a desk's top across its 130 x 70 cm in
    front; a workstation's desk with a monitor at its far edge looking back
    at the sitter (WORKSTATION_SCREEN) and a keyboard; a café chair of the
    kits' own size, just inside the kind's two side strips; a reading
    chair's arms and back round its cushion."""
    def build(turn):
        m = Model()
        m.turn = -turn
        if kind == "bench":
            for k in range(4):
                z = -0.25 + k * 0.115
                m.box(-0.8, 0.8, z, z + 0.09, 0.42, 0.48, "wood")
            for k in range(3):
                y = 0.58 + k * 0.12
                m.box(-0.8, 0.8, 0.27, 0.35, y, y + 0.08, "wood")
            for x in (-0.76, 0.76):
                m.box(x - 0.04, x + 0.04, -0.23, 0.33, 0.0, 0.42, "metal")
                m.box(x - 0.04, x + 0.04, 0.27, 0.35, 0.42, 0.95, "metal")
                m.box(x - 0.04, x + 0.04, -0.25, 0.35, 0.6, 0.66, "metal")
        elif kind == "desk":
            chair(m, "tram_cream")
            m.box(-0.655, 0.65, -0.95, -0.25, 0.7, 0.76, "wood")
            for dx in (-0.6, 0.6):
                m.box(dx - 0.04, dx + 0.04, -0.9, -0.3, 0.0, 0.7, "wood_dark")
            m.box(-0.3, 0.3, -0.86, -0.82, 0.8, 1.15, "glass_dark")
            m.box(-0.04, 0.04, -0.84, -0.76, 0.76, 0.82, "metal")
            m.box(-0.22, 0.22, -0.55, -0.43, 0.76, 0.78, "metal_light")
        elif kind == "workstation":
            chair(m, "cloth_navy")
            m.box(-0.655, 0.65, -0.95, -0.25, 0.7, 0.76, "wood")
            for dx in (-0.6, 0.6):
                m.box(dx - 0.04, dx + 0.04, -0.9, -0.3, 0.0, 0.7, "wood_dark")
            # The monitor: a pale case (the style's CRT) on a stand, its
            # dark screen on its front; the keyboard before it.
            (sx, sz, sy), (sw, sh) = WORKSTATION_SCREEN["at"], WORKSTATION_SCREEN["size"]
            m.box(-0.12, 0.12, -0.94, -0.8, 0.76, 0.79, "metal_light")
            m.box(-0.05, 0.05, -0.94, -0.9, 0.79, 0.84, "metal")
            m.box(-0.31, 0.31, -0.95, -0.9, 0.83, 1.21, "stone_light")
            m.box(sx - sw / 2, sx + sw / 2, -0.9, sz, sy - sh / 2, sy + sh / 2, "fascia")
            m.box(-0.22, 0.22, -0.52, -0.38, 0.76, 0.78, "metal_light")
        elif kind == "cafe-table":
            # The kits' own chair: a sprite stands on its nearest pixel, up
            # to 5 cm off its point, so its sides keep 3 cm inside the
            # kind's strips.
            m.box(-0.22, 0.22, -0.21, 0.2, 0.42, 0.48, "wood")               # the seat
            for dx in (-0.18, 0.18):
                for dz in (-0.17, 0.16):
                    m.box(dx - 0.025, dx + 0.025, dz - 0.025, dz + 0.025, 0.0, 0.42, "metal")
            m.box(-0.22, 0.22, 0.2, 0.26, 0.48, 0.95, "wood")                # its back
        elif kind == "reading-chair":
            m.box(-0.45, 0.45, -0.4, 0.5, 0.06, 0.1, "wood_dark")
            m.box(-0.25, 0.25, -0.24, 0.25, 0.1, 0.42, "banner")
            m.box(-0.25, 0.25, 0.25, 0.5, 0.1, 1.0, "banner")
            for x0 in (-0.45, 0.25):
                m.box(x0, x0 + 0.2, -0.4, 0.5, 0.1, 0.62, "banner")
            m.box(-0.25, 0.25, -0.24, 0.25, 0.42, 0.5, "canvas_red")
            for dx in (-0.4, 0.4):
                for dz in (-0.35, 0.45):
                    m.box(dx - 0.03, dx + 0.03, dz - 0.03, dz + 0.03, 0.0, 0.06, "wood_dark")
        return m.build(kind)
    return build


def cafe_table():
    """The café table kind's table: a round top as wide as its 100 cm
    square footprint's reach where people walk."""
    def build():
        m = Model()
        m.cyl(0, 0, 0.0, 0.05, 0.25, "metal", sides=8)
        m.cyl(0, 0, 0.05, 0.72, 0.04, "metal", sides=6)
        m.cyl(0, 0, 0.72, 0.77, 0.5, "stone_light", sides=16)
        m.box(-0.08, 0.08, -0.08, 0.08, 0.77, 0.9, "terracotta")
        m.sphere(0, 0, 0.95, 0.1, mv("flowers", 40), sub=1)
        return m.build("cafe_table")
    return build


# The great tree's drawn square about its point, metres, x and z: its
# 520 x 510 cm footprint grown to 2.5 cm past the cells the grid blocks
# round it (CityGeometry.drawn_rect at a 25 cm snap).
ROOTS = (-2.655, 2.645)


def tree_roots():
    """The great tree's surface roots, filling its square where people
    walk: from under its buttresses a root runs out to every quarter metre
    of the square's edge, arching at knee height, and dives into the
    ground there."""
    def build():
        m = Model()
        lo, hi = ROOTS
        m.quad([(lo, lo, 0.01), (hi, lo, 0.01), (hi, hi, 0.01), (lo, hi, 0.01)], "soil")
        edge = []
        n = int(round((hi - lo) / 0.25))
        for k in range(n):
            t = lo + (k + 0.5) * (hi - lo) / n
            edge += [(t, lo + 0.06), (t, hi - 0.06), (lo + 0.06, t), (hi - 0.06, t)]
        rng = random.Random(89)
        for x, z in edge:
            d = math.hypot(x, z)
            ux, uz = x / d, z / d
            y0 = rng.uniform(0.5, 0.6)
            mid = (ux * (0.9 + d) / 2, uz * (0.9 + d) / 2, rng.uniform(0.4, 0.5))
            t = rng.uniform(0.11, 0.14)
            m.beam((ux * 0.9, uz * 0.9, y0), mid, t + 0.03, "trunk")
            m.beam(mid, (x, z, 0.32), t, "trunk")
            m.box(x - 0.06, x + 0.06, z - 0.06, z + 0.06, 0.0, 0.34, "trunk")
        return m.build("tree_roots")
    return build


def bookshelf(turn):
    """A 2 m library bookcase, 2.2 m tall and as deep as the bookshelf
    kind's footprint (0.6 m), its shelves of coloured books facing north
    (-z) before it turns to its facing."""
    def build():
        m = Model()
        m.turn = -turn
        for x in (-1.0, 0.94):
            m.box(x, x + 0.06, -0.3, 0.3, 0.0, 2.2, "wood_dark")           # the sides
        m.box(-0.94, 0.94, 0.24, 0.3, 0.0, 2.2, "wood")                   # the back
        m.box(-0.94, 0.94, -0.3, 0.24, 0.0, 0.1, "wood_dark")             # the plinth
        colours = ["cloth_red", "cloth_teal", "cloth_yellow", "cloth_blue", "cloth_green", "cloth_purple"]
        rng = random.Random(55 + turn)
        for row in range(4):
            y0 = 0.14 + row * 0.5
            m.box(-0.94, 0.94, -0.3, 0.24, y0 - 0.04, y0, "wood_dark")     # a shelf
            x = -0.9
            while x < 0.86:
                w = rng.choice((0.06, 0.08, 0.1))
                h = rng.uniform(0.3, 0.42)
                m.box(x, x + w, -0.22, 0.2, y0, y0 + h, colours[rng.randrange(len(colours))])
                x += w + 0.01
        m.box(-1.0, 1.0, -0.3, 0.3, 2.2, 2.26, "wood_dark")              # the cornice
        return m.build("bookshelf")
    return build


for _f in (0, 90, 180, 270):
    add(f"bookshelf_{_f}", bookshelf(_f), [out(f"scenery/bookshelf_{_f}.png")], info={"facing": _f})

for _kind in ("bench", "desk", "workstation", "cafe-table", "reading-chair"):
    for _f in BENCH_FACINGS if _kind == "bench" else FACINGS:
        add(f"seat_{_kind}_{_f}", (lambda b, f: (lambda: b(f)))(seat_model(_kind), _f),
            [out(f"scenery/seats/{_kind}_{_f}.png")],
            info={"facing": _f, **({"display": WORKSTATION_SCREEN} if _kind == "workstation" else {})})
add("cafe_table", cafe_table(), [out("scenery/cafe_table.png")])
add("tree_roots", tree_roots(), [out("scenery/tree_roots.png")])
add("lamp", lamp(), [out("scenery/lamp.png")])
add("bench_x", bench(0), [out("scenery/bench_x.png")])
add("bench_z", bench(90), [out("scenery/bench_z.png")])
add("cafe_set", cafe_set(), [out("scenery/cafe_set.png")])
_b, _p = umbrella()
add("umbrella", _b, [out("scenery/umbrella.png")], params=_p)
add("bollard", bollard(), [out("scenery/bollard.png")])
add("railing_x", railing(0), [out("scenery/railing_x.png")])
add("railing_z", railing(90), [out("scenery/railing_z.png")])
add("railing_post", railing_post(), [out("scenery/railing_post.png")])
add("planter", planter(True), [out("scenery/planter.png")])
add("planter_pot", planter(False), [out("scenery/planter_pot.png")])
for _f in (0, 90):
    add(f"flowerbed_{_f}", flowerbed(_f), [out(f"scenery/flowerbed_{_f}.png")], info={"facing": _f})
for _f in (0, 90, 180, 270):
    add(f"tram_shelter_{_f}", tram_shelter(_f), [out(f"scenery/tram_shelter_{_f}.png")], info={"facing": _f})
add("workbench", workbench(), [out("scenery/workbench.png")])


# ---------------------------------------------------------------------------
# The tram: three cream-and-red cars along x (0.25..20.75 m), centred on
# its line (z = 0), on the shared tram layout (tools/styles/shared/
# tram_layout.py): 20.5 m long, doors at 20, 50 and 80% of it, seats under
# the seated slots. It is drawn in two halves cut into 1 m slices so riders
# show in its windows: the back (the far side, z < 0, with the floor,
# seats, roof, the joints' ends and the -x cab) sorts at z = TRAM_BACK_Z,
# before the riders; the front (the near side, its windows open, and the +x
# cab) at z = TRAM_FRONT_Z, after them. Door leaves are sprites of their own
# that slide.
# ---------------------------------------------------------------------------

TRAM_LEN = 21
TRAM_CARS = ((0.25, 7.25), (7.65, 13.35), (13.75, 20.75))
TRAM_HW = 1.25          # the tram kind's width (250 cm) about its line, where people walk
# The sides' faces, a centimetre in, so their frames stand out to TRAM_HW.
TRAM_SIDE = TRAM_HW - 0.01
TRAM_BACK_Z, TRAM_FRONT_Z = -1.3, 1.3
TRAM_LEAF = 0.65         # a door leaf's width
TRAM_FLOOR = 0.4
TRAM_SILL, TRAM_HEAD = 1.35, 2.6
TRAM_GANGWAY = 0.85


def _tram_layout():
    import sys
    from pathlib import Path
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
    import tram_layout
    return tram_layout


def _tram_openings():
    """Each car's doors (the layout's, about the sprite's middle at x = 10)
    and the windows between them: [(x0, x1, is_door)] per car."""
    doors = sorted((TRAM_LEN / 2 + a, TRAM_LEN / 2 + b) for a, b in _tram_layout().doors_m())
    out = []
    for a, b in TRAM_CARS:
        door = next(d for d in doors if a < d[0] < b)
        out.append([(a + 0.6, door[0] - 0.25, False), (door[0], door[1], True), (door[1] + 0.25, b - 0.6, False)])
    return out


def _tram_side(m, z_face, sign, openings, glazed):
    """One side of the cars at z = z_face (sign: which way is out): a red
    skirt, cream above, the windows (glazed dark, or open with a frame
    round them) and the doorways left open, framed."""
    t = 0.08
    z0, z1 = (z_face - t, z_face) if sign > 0 else (z_face, z_face + t)
    for (a, b), holes in zip(TRAM_CARS, openings):
        cuts = [a] + [x for x0, x1, _ in holes for x in (x0, x1)] + [b]
        for k in range(0, len(cuts), 2):
            m.box(cuts[k], cuts[k + 1], z0, z1, 0.35, 1.1, "tram_red")
            m.box(cuts[k], cuts[k + 1], z0, z1, 1.1, 3.0, "tram_cream")
        for x0, x1, door in holes:
            if door:
                m.box(x0, x1, z0, z1, TRAM_HEAD + 0.1, 3.0, "tram_cream")
                for x in (x0 - 0.06, x1):
                    m.box(x, x + 0.06, z0 - 0.01, z1 + 0.01, 0.35, TRAM_HEAD + 0.1, "rubber")
                continue
            m.box(x0, x1, z0, z1, 0.35, 1.1, "tram_red")
            m.box(x0, x1, z0, z1, 1.1, TRAM_SILL, "tram_cream")
            m.box(x0, x1, z0, z1, TRAM_HEAD, 3.0, "tram_cream")
            if glazed:
                m.box(x0, x1, z0 + 0.02, z1 - 0.02, TRAM_SILL, TRAM_HEAD, "glass_dark")
            else:
                for y in (TRAM_SILL, TRAM_HEAD - 0.05):
                    m.box(x0, x1, z0 - 0.01, z1 + 0.01, y, y + 0.05, "rubber")
                mid = (x0 + x1) / 2
                m.box(mid - 0.04, mid + 0.04, z0 - 0.01, z1 + 0.01, TRAM_SILL, TRAM_HEAD, "rubber")
        # The red band under the roof, 2 cm proud of the side.
        m.box(a, b, z0 if sign > 0 else z0 - 0.02, z1 + 0.02 if sign > 0 else z1, 2.82, 2.92, "tram_red")


def _tram_end(m, x, zs, cab, sgn):
    """A car's end at x across z in `zs`: at a cab, a windscreen and lamps
    (sgn: the way it faces); at a joint, walls either side of the gangway."""
    z0, z1 = zs
    if cab:
        xa, xb = (x - 0.05, x) if sgn > 0 else (x, x + 0.05)
        m.box(xa, xb, z0, z1, 0.35, 1.1, "tram_red")
        m.box(xa, xb, z0, z1, 1.1, 3.0, "tram_cream")
        m.box(xa - 0.01, xb + 0.01, max(z0, -1.0), min(z1, 1.0), 1.4, 2.7, "glass_dark")
        for z in (-0.8, 0.8):
            if z0 <= z <= z1:
                m.box(xa - 0.02, xb + 0.02, z - 0.14, z + 0.14, 0.75, 0.95, "lamp")
        return
    xa, xb = (x - 0.06, x) if sgn > 0 else (x, x + 0.06)
    for g0, g1 in ((-TRAM_HW, -TRAM_GANGWAY), (TRAM_GANGWAY, TRAM_HW)):
        lo, hi = max(z0, g0), min(z1, g1)
        if hi > lo:
            m.box(xa, xb, lo, hi, 0.35, 3.0, "tram_cream")
    lo, hi = max(z0, -TRAM_GANGWAY), min(z1, TRAM_GANGWAY)
    if hi > lo:
        m.box(xa, xb, lo, hi, 2.3, 3.0, "tram_cream")


def tram_back():
    """The tram's far half: the far side glazed, the floor, the seats and
    poles, the roof and pantograph, bogies, bellows, the joints' ends and
    the cab at -x."""
    def build():
        m = Model()
        lay = _tram_layout()
        openings = _tram_openings()
        _tram_side(m, -TRAM_SIDE, -1, openings, glazed=True)
        for ci, (a, b) in enumerate(TRAM_CARS):
            m.box(a, b, -TRAM_HW, TRAM_HW, 0.3, TRAM_FLOOR, "rubber")
            m.box(a + 0.1, b - 0.1, -TRAM_HW + 0.1, TRAM_HW - 0.1, 3.0, 3.2, "tram_roof")
            _tram_end(m, a, (-TRAM_HW, TRAM_HW), ci == 0, -1)
            if ci < len(TRAM_CARS) - 1:
                _tram_end(m, b, (-TRAM_HW, TRAM_HW), False, 1)
            for bx in (a + 1.2, b - 1.2):
                m.box(bx - 0.8, bx + 0.8, -TRAM_HW + 0.15, TRAM_HW - 0.15, 0.05, 0.3, "rubber")
            if ci == 1:
                door = (a + b) / 2
                m.box(door - 1.2, door + 1.2, -0.6, 0.6, 3.2, 3.45, "metal_light")
                m.beam((door - 0.6, 0.0, 3.45), (door + 0.3, 0.0, 4.1), 0.06, "metal")
                m.beam((door + 0.3, 0.0, 4.1), (door - 0.4, 0.0, 4.5), 0.06, "metal")
                m.box(door - 0.8, door + 0.0, -0.5, 0.5, 4.48, 4.54, "metal")
        for a, b in zip([c[1] for c in TRAM_CARS], [c[0] for c in TRAM_CARS[1:]]):
            m.box(a, b, -TRAM_HW + 0.1, TRAM_HW - 0.1, 0.3, TRAM_FLOOR, "rubber")
            m.box(a - 0.05, b + 0.05, -1.05, -0.85, 0.5, 2.8, "rubber")
            m.box(a - 0.05, b + 0.05, -1.05, 1.05, 2.6, 2.95, "rubber")
        seat_top = TRAM_FLOOR + lay.SEAT_CM / 100.0
        for x, y in lay.seats_m():
            sx, sz = TRAM_LEN / 2 + x, -y
            z0, z1 = (sz - 0.1, min(sz + 0.42, TRAM_HW - 0.1)) if sz > 0 else (max(sz - 0.42, -TRAM_HW + 0.1), sz + 0.1)
            m.box(sx - 0.22, sx + 0.22, z0, z1, seat_top - 0.08, seat_top, "banner")
            m.box(sx - 0.29, sx - 0.22, z0, z1, seat_top, seat_top + 0.5, "banner")
        for a, b in lay.doors_m():
            for dx in (-0.51, 0.51):
                cx = TRAM_LEN / 2 + (a + b) / 2 + dx
                m.box(cx - 0.03, cx + 0.03, -0.03, 0.03, TRAM_FLOOR, 3.0, "metal_light")
        return m.build("tram_back")
    return build


def tram_front():
    """The tram's near half: the near side with its windows open, so the
    riders show through them, and the cab at +x."""
    def build():
        m = Model()
        _tram_side(m, TRAM_SIDE, 1, _tram_openings(), glazed=False)
        _tram_end(m, TRAM_CARS[-1][1], (-TRAM_HW, TRAM_HW), True, 1)
        for a, b in zip([c[1] for c in TRAM_CARS], [c[0] for c in TRAM_CARS[1:]]):
            m.box(a - 0.05, b + 0.05, 0.85, 1.05, 0.5, 2.8, "rubber")
        return m.build("tram_front")
    return build


def tram_door():
    """A door leaf, TRAM_LEAF wide along x about its origin: a red frame
    round dark glass over a solid kick panel."""
    def build():
        m = Model()
        h = TRAM_LEAF / 2
        m.box(-h, h, -0.02, 0.02, TRAM_FLOOR, 0.95, "tram_red")
        m.box(-h, h, -0.02, 0.02, TRAM_HEAD, TRAM_HEAD + 0.1, "tram_red")
        for x in (-h, h - 0.06):
            m.box(x, x + 0.06, -0.02, 0.02, 0.95, TRAM_HEAD, "tram_red")
        m.box(-h + 0.06, h - 0.06, -0.015, 0.015, 0.95, TRAM_HEAD, "glass_dark")
        return m.build("tram_door")
    return build


def _tram_slices(half, z):
    outs = [out(f"scenery/tram/{half}_{i:02d}.png", {"x": [i, i]}, (i + 0.5, z, 0)) for i in range(TRAM_LEN)]
    outs[0]["cells"]["x"] = [-1, 0]
    outs[-1]["cells"]["x"] = [TRAM_LEN - 1, TRAM_LEN]
    return outs


add("tram_back", tram_back(), _tram_slices("back", TRAM_BACK_Z), params={"pane_top": 2.6},
    info={"length": TRAM_LEN, "axis": "x", "z": TRAM_BACK_Z})
add("tram_front", tram_front(), _tram_slices("front", TRAM_FRONT_Z), params={"pane_top": 2.6},
    info={"length": TRAM_LEN, "axis": "x", "z": TRAM_FRONT_Z})
add("tram_door", tram_door(), [out("scenery/tram/door.png")], params={"pane_top": 2.6},
    info={"width": TRAM_LEAF})


# ---------------------------------------------------------------------------
# The bridge: stone arches along x, deck at 1.6 m, 4 m wide (z -2..2), its
# parapets standing just outside the deck, where no one walks; a 4 m span
# module and the two ends (ramps, open at their sides, since the ramps run
# down onto the ground people walk), each metre cut into a back half
# (north of z = 1: deck and north parapet) and a front half (south parapet
# and arch face), so walkers on the deck sort between them.
# ---------------------------------------------------------------------------

DECK = 1.6
BRIDGE_W = 2.0
# How far outside the deck a parapet's inner face stands, and its depth.
PARAPET_OFF = 0.01
PARAPET_T = 0.25


def arc(x0, x1, spring, rise, segments=10):
    r = (x1 - x0) / 2
    return [((x0 + x1) / 2 - math.cos(math.pi * k / segments) * r, spring + math.sin(math.pi * k / segments) * rise)
            for k in range(segments + 1)]


def parapet(m, x0, x1, y0, z_in, out, mat="stone_light"):
    """A balustrade 0.95 m high along x from x0 to x1 at deck height y0,
    its inner face on z = z_in and PARAPET_T deep the way `out` (+1 south,
    -1 north) points; its coping overhangs outward only."""
    holes = []
    x = x0 + 0.25
    while x + 0.2 <= x1 - 0.2:
        holes.append([(x, y0 + 0.22), (x, y0 + 0.72), (x + 0.16, y0 + 0.72), (x + 0.16, y0 + 0.22)])
        x += 0.4
    z_face = z_in + PARAPET_T if out > 0 else z_in
    m.wall_s([(x0, y0), (x0, y0 + 0.9), (x1, y0 + 0.9), (x1, y0)], holes, z_face, PARAPET_T, mat)
    z_far = z_in + out * (PARAPET_T + 0.04)
    m.box(x0, x1, min(z_in, z_far), max(z_in, z_far), y0 + 0.9, y0 + 1.0, mat)


def bridge():
    """Specimen: a ramp up from the west bank (x -2..0), three 4 m spans
    (0..12) and a ramp down to the east bank (12..14)."""
    hw = BRIDGE_W
    edge = hw + PARAPET_OFF + PARAPET_T     # the parapets' outer faces

    def build():
        m = Model()
        for k in range(3):
            a = k * 4.0
            m.box(a, a + 0.9, -edge, edge, 0.0, DECK, "stone")                       # pier
            m.box(a - 0.08, a + 0.98, -edge - 0.1, edge + 0.1, 0.0, 0.35, "stone")   # cutwater footing
            curve = arc(a + 0.9, a + 3.9, 0.35, 0.95)
            m.wall_s(curve + [(a + 3.9, DECK), (a + 0.9, DECK)], [], edge, 2 * edge, "stone")
            for z_in, out_ in ((hw + PARAPET_OFF, 1), (-hw - PARAPET_OFF, -1)):
                parapet(m, a, a + 4.0, DECK, z_in, out_)
                z_far = z_in + out_ * (PARAPET_T + 0.06)
                m.box(a + 0.15, a + 0.75, min(z_in, z_far), max(z_in, z_far), DECK, DECK + 1.15,
                      "stone_light")                                             # pedestal over the pier
        m.box(0, 12, -edge - 0.1, edge + 0.1, DECK - 0.22, DECK, "stone_light")  # cornice
        m.quad([(0, -hw, DECK + 0.004), (12, -hw, DECK + 0.004), (12, hw, DECK + 0.004),
                (0, hw, DECK + 0.004)], "paving")
        # The ramps: solid abutments and sloped decks.
        for xa, xb, up in ((-2.0, 0.0, True), (12.0, 14.0, False)):
            prof = [(xa, 0.0), (xb, 0.0), (xb, DECK)] if up else [(xa, 0.0), (xb, 0.0), (xa, DECK)]
            m.prism_z(prof, -hw, hw, "stone")
            y_a, y_b = (0.0, DECK) if up else (DECK, 0.0)
            m.quad([(xa, -hw, y_a + 0.004), (xb, -hw, y_b + 0.004), (xb, hw, y_b + 0.004),
                    (xa, hw, y_a + 0.004)], "paving")
        return m.build("bridge")

    outs = []
    names = [(f"end_w_{i}", -2 + i) for i in range(2)] + [(f"span_{p}", 4 + p) for p in range(4)] + \
        [(f"end_e_{i}", 12 + i) for i in range(2)]
    for name, cx in names:
        outs.append(out(f"scenery/bridge/{name}_back.png", {"x": [cx, cx], "z": [-9, 0]}, (cx + 1, -hw, 0)))
        outs.append(out(f"scenery/bridge/{name}_front.png", {"x": [cx, cx], "z": [1, 9]}, (cx + 1, hw, 0)))
    return build, outs


_b, _o = bridge()
add("bridge", _b, _o, info={"deck": DECK, "width": 2 * BRIDGE_W, "span": 4, "axis": "x"})


# ---------------------------------------------------------------------------
# Ground tiles: 1 m cells at (0..1, 0..1), no outline, origin at the centre.
# Overlays sit 2 mm up so the depth test, not draw order, picks them.
# ---------------------------------------------------------------------------

def tile(mat, overlays=()):
    def build():
        m = Model()
        m.quad([(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], mat)
        for i, (x0, x1, z0, z1, omat) in enumerate(overlays):
            y = 0.002 * (i + 1)
            m.quad([(x0, z0, y), (x1, z0, y), (x1, z1, y), (x0, z1, y)], omat)
        return m.build("tile")
    return build


def add_tile(name, mat, overlays=(), params=None):
    add(f"tile_{name}", tile(mat, overlays), [out(f"ground/{name}.png", None, (0.5, 0.5, 0), TILE_BOX)], outline=False,
        params=params)


for _k in range(4):
    add_tile(f"paving_{_k}", "paving", params={"seed": 101 + _k})
for _k in range(2):
    add_tile(f"grass_{_k}", "grass", params={"seed": 201 + _k})
    add_tile(f"water_{_k}", "water", params={"seed": 301, "frame": _k})
add_tile("street", "asphalt")
add_tile("street_dash_x", "asphalt", [(0.1, 0.9, 0.44, 0.56, "paint_white")])
add_tile("street_dash_z", "asphalt", [(0.44, 0.56, 0.1, 0.9, "paint_white")])
add_tile("crossing_x", "asphalt", [(0.08, 0.42, 0.0, 1.0, "paint_white"), (0.58, 0.92, 0.0, 1.0, "paint_white")])
add_tile("crossing_z", "asphalt", [(0.0, 1.0, 0.08, 0.42, "paint_white"), (0.0, 1.0, 0.58, 0.92, "paint_white")])
for _side, _band in (("n", (0, 1, 0, 0.3)), ("s", (0, 1, 0.7, 1)), ("w", (0, 0.3, 0, 1)), ("e", (0.7, 1, 0, 1))):
    add_tile(f"kerb_{_side}", "asphalt", [(*_band, "kerb")])
add_tile("track_x", "gravel", [(0.05, 0.3, 0.0, 1.0, "sleeper"), (0.55, 0.8, 0.0, 1.0, "sleeper")]
         + [(0.0, 1.0, z, z + 0.08, "rail") for z in (0.2, 0.72)])
add_tile("track_z", "gravel", [(0.0, 1.0, 0.05, 0.3, "sleeper"), (0.0, 1.0, 0.55, 0.8, "sleeper")]
         + [(x, x + 0.08, 0.0, 1.0, "rail") for x in (0.2, 0.72)])
# Half a track, for a track whose middle runs along a cell edge: the half
# south of a middle on the tile's north edge (_n) or north of one on its
# south edge (_s); east of a middle on its west edge (_w), west of one on
# its east edge (_e). The rails keep the whole track's gauge.
add_tile("track_x_n", "gravel", [(0.05, 0.3, 0.0, 0.5, "sleeper"), (0.55, 0.8, 0.0, 0.5, "sleeper"),
                                 (0.0, 1.0, 0.22, 0.3, "rail")])
add_tile("track_x_s", "gravel", [(0.05, 0.3, 0.5, 1.0, "sleeper"), (0.55, 0.8, 0.5, 1.0, "sleeper"),
                                 (0.0, 1.0, 0.7, 0.78, "rail")])
add_tile("track_z_w", "gravel", [(0.0, 0.5, 0.05, 0.3, "sleeper"), (0.0, 0.5, 0.55, 0.8, "sleeper"),
                                 (0.22, 0.3, 0.0, 1.0, "rail")])
add_tile("track_z_e", "gravel", [(0.5, 1.0, 0.05, 0.3, "sleeper"), (0.5, 1.0, 0.55, 0.8, "sleeper"),
                                 (0.7, 0.78, 0.0, 1.0, "rail")])
add_tile("path", "path")
add_tile("floor_wood", "floorboards")
add_tile("floor_stone", "floor_stone", params={"seed": 401})
add_tile("floor_carpet", "carpet")
add_tile("quay_e", "water", [(0.62, 1.0, 0.0, 1.0, "kerb")], params={"seed": 301, "frame": 0})
add_tile("quay_w", "water", [(0.0, 0.38, 0.0, 1.0, "kerb")], params={"seed": 301, "frame": 0})


# ---- The things to use: displays, perches and the meadow (things.py) ----
import things  # noqa: E402

things.add_things()


# ---- People and robots: the shared rig in eight directions (figures.py) ----
import figures  # noqa: E402

figures.add_figures()
