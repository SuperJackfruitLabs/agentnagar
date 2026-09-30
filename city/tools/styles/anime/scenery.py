"""Scenery for the cel-shaded anime kit, after the 06 sheets: clean asphalt
between pale kerbs; the tram lane's grooved rails set flush in warm paving;
bright flat water with lighter ripple bands; the river's pale stone
three-arch bridge (one arch a span) with its voussoirs, cornice, parapet
and lamps; the cream tram with its coral stripes, big dark-framed windows
and rounded noses; puffy cumulus; a white sailboat with blue trim; the
square's cream stone paving; the park's gravel path; the waterfront's
black iron railing under a white handrail.

Pivots, orientations and extents match the low-poly kit's pieces of the
same names, because the anime townscape reuses their placement (Blender
Z-up, metres; +Y is Godot's forward, -Z):
    street_tile         2 m x 2 m of asphalt, its top at z = 0
    street_kerb         2 m of kerb along x, its body on z in [-0.08, 0.08]
                        (placed 8 cm up), a pale gutter on its road side, -Y
    tram_track          2 m of track along x in a 2.8 m strip of paving, its
                        top at z = 0 (placed 2 cm up)
    water_tile          4 m x 4 m of water; z = 0 is the surface
    bridge_span         one 8 m arch along x, the deck's paving at z = 1.26
                        (placed at y = -0.9: walkers 0.36 m up)
    bridge_pier         the pier at each joint of spans: cutwaters up and
                        down stream (+-Y), lamps on the parapets
    tram                three sections along x, 20.5 m (the shared tram
                        layout's length); z = 0 is the rail
    cloud_a, cloud_b    cumulus, base at z = 0
    sailboat            5 m long along +Y; z = 0 is the waterline
    paving_tile_a/b/c   1 m of the square's paving on a 0.5 m grid
    path                1 m of park path running along Y
    railing             2 m of railing along x, its post at the -x end
    railing_post        the post that closes a run
The pack draws tiled pieces (ground tiles, kerb, track, water, railings)
with MultiMesh from the first mesh it finds, so each is a single mesh; the
paving tiles and the path are that mesh alone, named after the asset.

Godot's importer quantizes each material's vertices on its own, so an edge
shared by two colours can open by a fraction of a millimetre. Wherever
such a seam would show the sky or the ground through a pinhole, something
of the same colour lies just behind it: the tram's and the hull's inner
cores, an underlay beneath the flush strips of the track and the water.
"""
import math

import bmesh
from mathutils.geometry import tessellate_polygon
from mathutils import Vector

import sys
from pathlib import Path

import lib
from lib import Mesh, rotz

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "shared"))
import tram_layout  # noqa: E402
import tram_parts  # noqa: E402


# ---- Helpers ----

def _add(m, verts, faces, mats):
    """Raw faces on a Mesh; `mats` is one palette name per face, or one for
    all."""
    if isinstance(mats, str):
        mats = [mats] * len(faces)
    vs = [m.bm.verts.new(v) for v in verts]
    for f, mat in zip(faces, mats):
        try:
            nf = m.bm.faces.new([vs[i] for i in f])
        except ValueError:
            continue
        nf.material_index = m.slot(mat)


def _block(m, lo, hi, top, side=None):
    """An axis-aligned block from `lo` to `hi`: its top in `top`, its sides
    in `side`, and no underside (ground pieces lie on the ground)."""
    x0, y0, z0 = lo
    x1, y1, z1 = hi
    v = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
         (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
    faces = [(4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    _add(m, v, faces, [top] + [side or top] * 4)


def _solid(m, verts, faces, mats):
    """A closed solid from raw faces, its normals turned outward."""
    if isinstance(mats, str):
        mats = [mats] * len(faces)
    tmp = bmesh.new()
    vs = [tmp.verts.new(v) for v in verts]
    for f, mat in zip(faces, mats):
        tmp.faces.new([vs[i] for i in f]).material_index = m.slot(mat)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    m._merge_indexed(tmp, None, (0, 0, 0))


def _loft(m, rings, band, cap0, cap1):
    """Joins closed rings of points (each the same length) with quads, the
    quad from ring i to i + 1 between points k and k + 1 in band(i, k) (none
    where it gives None); caps the first ring in `cap0` and the last in
    `cap1`, flat (none for None). Normals are turned outward, so the rings
    may run either way round."""
    tmp = bmesh.new()
    vs = [[tmp.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for i in range(len(rings) - 1):
        for k in range(n):
            j = (k + 1) % n
            mat = band(i, k)
            if mat is None:
                continue
            f = tmp.faces.new([vs[i][k], vs[i][j], vs[i + 1][j], vs[i + 1][k]])
            f.material_index = m.slot(mat)
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    m._merge_indexed(tmp, None, (0, 0, 0))
    # The caps on their own vertices, so smooth shading keeps them flat.
    if cap0 is not None and cap1 is not None:
        _solid(m, rings[0] + rings[-1], [tuple(range(n)), tuple(range(n, 2 * n))], [cap0, cap1])
    elif cap0 is not None or cap1 is not None:
        _solid(m, rings[0] if cap0 is not None else rings[-1], [tuple(range(n))], [cap0 or cap1])


def _inlaid(m, outer, inlays, z, mat):
    """A flat face at height z: the anticlockwise polygon `outer` in `mat`
    with inlays [(anticlockwise points, colour), ...] cut into the same
    plane, so colours meet without overlapping (nothing to flicker) and
    without relief (nothing for the ink pass to line)."""
    loops = [outer] + [pts for pts, _ in inlays]
    flat = [p for loop in loops for p in loop]
    faces = []
    for a, b, c in tessellate_polygon([[Vector((x, y, 0)) for x, y in loop] for loop in loops]):
        (ax, ay), (bx, by), (cx, cy) = flat[a], flat[b], flat[c]
        faces.append((a, b, c) if (bx - ax) * (cy - ay) - (by - ay) * (cx - ax) > 0 else (a, c, b))
    _add(m, [(x, y, z) for x, y in flat], faces, mat)
    for pts, colour in inlays:
        _add(m, [(x, y, z) for x, y in pts], [tuple(range(len(pts)))], colour)


def _sides(m, outer, z0, z1, mat):
    """The upright sides of the anticlockwise polygon `outer` from z0 to
    z1, facing out."""
    v = []
    for (x0, y0), (x1, y1) in zip(outer, outer[1:] + outer[:1]):
        v += [(x0, y0, z0), (x1, y1, z0), (x1, y1, z1), (x0, y0, z1)]
    _add(m, v, [(k, k + 1, k + 2, k + 3) for k in range(0, len(v), 4)], mat)


def _pane(m, x0, x1, z0, z1, y, facing, mat):
    """A flat panel on a face at y looking along `facing` (+1: +Y, -1: -Y)."""
    if facing > 0:
        v = [(x1, y, z0), (x0, y, z0), (x0, y, z1), (x1, y, z1)]
    else:
        v = [(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)]
    _add(m, v, [(0, 1, 2, 3)], mat)


def _sheet(m, pts, mat):
    """A thin double-sided sheet (a sail) through the points given."""
    n = len(pts)
    faces = [(0, k, k + 1) for k in range(1, n - 1)]
    _add(m, pts, faces, mat)
    _add(m, pts, [tuple(reversed(f)) for f in faces], mat)


# ---- Streets ----

def street_tile():
    """Clean asphalt; the sides a shade darker."""
    r = lib.root("street_tile")
    m = Mesh()
    _block(m, (-1.0, -1.0, -0.08), (1.0, 1.0, 0.0), "asphalt", "asphalt_dark")
    m.build("street", r)


def street_kerb():
    """A pale stone kerb with a chamfered road edge, and a light concrete
    gutter 30 cm into the road (its road side, -Y), which the sheets' roads
    show as a pale edge. The pack puts the kerb 8 cm up, so the gutter lies
    6 mm over the road surface."""
    r = lib.root("street_kerb")
    m = Mesh()
    m.prism([(-0.17, -0.08), (0.17, -0.08), (0.17, 0.06), (0.15, 0.08), (-0.12, 0.08), (-0.17, 0.035)],
            2.0, (0, 0, 0), "kerb", axis="x")
    _block(m, (-1.0, -0.47, -0.08), (1.0, -0.17, -0.074), "concrete", "stone")
    m.build("kerb", r)


def tram_track():
    """Two grooved rails, each a grey running head and check lip either
    side of a dark groove (the sheets' paired lines), set flush in warm
    paving between stone edging strips; no sleepers show."""
    r = lib.root("tram_track")
    m = Mesh()
    bands = [(-1.40, "stone"), (-1.28, "paving_dark"), (-0.79, "steel"), (-0.73, "frame"),
             (-0.69, "steel"), (-0.65, "paving"), (0.65, "steel"), (0.69, "frame"), (0.73, "steel"),
             (0.79, "paving_dark"), (1.28, "stone"), (1.40, None)]
    verts, faces, mats = [], [], []
    for (y0, mat), (y1, _) in zip(bands, bands[1:]):
        k = len(verts)
        verts += [(-1.0, y0, 0.0), (1.0, y0, 0.0), (1.0, y1, 0.0), (-1.0, y1, 0.0)]
        faces.append((k, k + 1, k + 2, k + 3))
        mats.append(mat)
    _add(m, verts, faces, mats)
    _add(m, [(-1, -1.4, -0.01), (1, -1.4, -0.01), (1, 1.4, -0.01), (-1, 1.4, -0.01)], [(0, 1, 2, 3)], "paving_dark")
    # The strip's edges and ends, down to 12 cm below.
    _sides(m, [(-1, -1.4), (1, -1.4), (1, 1.4), (-1, 1.4)], -0.12, 0.0, "stone")
    m.build("track", r)


# ---- Water ----

# Lighter ripple bands on each water tile: (x, y, length, width), pointed
# lozenges running across the river.
RIPPLES = [(-1.0, 1.25, 1.5, 0.12), (1.05, 0.55, 1.1, 0.09), (-0.35, -0.45, 1.9, 0.13),
           (1.25, -1.35, 0.9, 0.08), (-1.45, -1.55, 0.7, 0.07)]


def water_tile():
    """Flat bright water with a few lighter ripple bands cut into the same
    surface (no overlaps to flicker), and a skirt 15 cm down so tiles meet
    the quays cleanly. The pack animates the sparkle."""
    r = lib.root("water_tile")
    m = Mesh()
    outer = [(-2.0, -2.0), (2.0, -2.0), (2.0, 2.0), (-2.0, 2.0)]
    bands = [([(x - l / 2, y), (x - 0.1 * l, y - w / 2), (x + l / 2, y), (x - 0.1 * l, y + w / 2)], "water_light")
             for x, y, l, w in RIPPLES]
    _inlaid(m, outer, bands, 0.0, "water")
    _add(m, [(x, y, -0.01) for x, y in outer], [(0, 1, 2, 3)], "water")
    _sides(m, outer, -0.15, 0.0, "water")
    m.build("water", r)


# ---- The bridge ----

SPAN = 8.0
DECK = 1.2          # the deck's structure; its paving is 6 cm on top
FOOT = -2.4
FACE = 2.0          # the spandrels' faces, at y = +-FACE
PIER = 0.65         # the pier's half-width; arches spring just inside it
ARCH_A = SPAN / 2 - PIER + 0.05   # the springing hides in the pier
ARCH_SPRING = -1.6
ARCH_RISE = 2.42    # the soffit's crown at z = 0.82
RING = 0.3          # the voussoirs' depth
VOUSSOIRS = 15


def _arch_point(t, out=0.0):
    """A point on the semi-elliptical arch at parameter t (0 at the -x
    springing, pi at the +x), `out` metres out from the soffit along its
    normal."""
    a, b = ARCH_A, ARCH_RISE
    nx, nz = -b * math.cos(t), a * math.sin(t)
    k = out / math.hypot(nx, nz)
    return (-a * math.cos(t) + nx * k, ARCH_SPRING + b * math.sin(t) + nz * k)


def bridge_span():
    """One arch of the sheets' pale stone bridge: a semi-elliptical arch
    ringed by voussoirs (a deeper keystone at the crown) on both faces,
    plain spandrels (the soffit in the same stone, which its shadow
    darkens), a white string course at deck level, and a solid
    parapet under a white coping each side of a paved deck."""
    r = lib.root("bridge_span")
    m = Mesh()
    # Spandrels and soffit: the span's outline with the arch cut from below.
    arch = [_arch_point(math.pi * k / 16) for k in range(17)]
    outline = [(-SPAN / 2, FOOT), (-ARCH_A, FOOT)] + arch + [(ARCH_A, FOOT), (SPAN / 2, FOOT),
                                                             (SPAN / 2, DECK), (-SPAN / 2, DECK)]
    m.slab(outline, [], 2 * FACE, (0, 0, 0), "stone")
    # Voussoirs, standing 5 cm proud of each face with joints between.
    for k in range(VOUSSOIRS):
        t0, t1 = math.pi * k / VOUSSOIRS, math.pi * (k + 1) / VOUSSOIRS
        key = k == VOUSSOIRS // 2
        depth = RING + (0.06 if key else 0.0)
        pts = []
        for t, sgn in ((t0, 1), (t1, -1)):
            speed = math.hypot(ARCH_A * math.sin(t), ARCH_RISE * math.cos(t))
            pts.append(t + sgn * 0.018 / speed)
        profile = [_arch_point(pts[0]), _arch_point(pts[1]), _arch_point(pts[1], depth), _arch_point(pts[0], depth)]
        for y in (-1, 1):
            m.prism(profile, 0.05, (0, y * (FACE + 0.025), 0), "warm_white", axis="y")
    for y in (-1, 1):
        # String course.
        m.box((SPAN, 0.22, 0.2), (0, y * (FACE + 0.01), DECK - 0.1), "warm_white", bevel=0.02)
        # Parapet and coping.
        m.box((SPAN, 0.28, 0.94), (0, y * (FACE - 0.14), DECK + 0.47), "stone", bevel=0.015)
        m.box((SPAN, 0.4, 0.16), (0, y * (FACE - 0.14), DECK + 1.02), "warm_white", bevel=0.03)
    # The deck: paving, lighter footways by the parapets.
    top = DECK + 0.06
    inner = FACE - 0.28
    strips = [(-inner, "paving_light"), (-1.2, "paving"), (1.2, "paving_light"), (inner, None)]
    verts, faces, mats = [], [], []
    for (y0, mat), (y1, _) in zip(strips, strips[1:]):
        k = len(verts)
        verts += [(-SPAN / 2, y0, top), (SPAN / 2, y0, top), (SPAN / 2, y1, top), (-SPAN / 2, y1, top)]
        faces.append((k, k + 1, k + 2, k + 3))
        mats.append(mat)
    _add(m, verts, faces, mats)
    h = SPAN / 2
    _add(m, [(h, -inner, DECK), (h, inner, DECK), (h, inner, top), (h, -inner, top),
             (-h, inner, DECK), (-h, -inner, DECK), (-h, -inner, top), (-h, inner, top)],
         [(0, 1, 2, 3), (4, 5, 6, 7)], "paving")
    m.build("span", r)


def bridge_pier():
    """A pier between arches: pointed cutwaters up and down stream under
    sloping white hoods, its faces rising as pilasters to a white cornice,
    and a pedestal on each parapet carrying a black iron lamp."""
    r = lib.root("bridge_pier")
    m = Mesh()
    half_y = FACE + 0.3
    m.box((2 * PIER, 2 * half_y, DECK - FOOT + 2.0), (0, 0, (DECK + FOOT - 2.0) / 2), "stone", bevel=0.03)
    for s in (-1, 1):
        # The cutwater to the waterline, and its hood.
        m.prism([(-PIER, 0.0), (PIER, 0.0), (0.0, s * 1.1)], 4.4, (0, s * half_y, -2.2), "stone", axis="z")
        base, hood = 0.0, 0.62
        _solid(m, [(-PIER - 0.07, s * half_y, base), (PIER + 0.07, s * half_y, base), (0, s * (half_y + 1.16), base),
                   (0, s * half_y, base + hood)],
               [(0, 1, 2), (0, 2, 3), (2, 1, 3), (1, 0, 3)], "warm_white")
        # The pedestal on the parapet, its cap and lamp.
        y = s * (FACE - 0.1)
        m.box((0.84, 0.6, 1.2), (0, y, DECK + 0.6), "stone", bevel=0.02)
        m.box((0.96, 0.72, 0.14), (0, y, DECK + 1.27), "warm_white", bevel=0.02)
        z = DECK + 1.34
        m.box((0.26, 0.26, 0.3), (0, y, z + 0.15), "iron", bevel=0.02)
        m.cylinder(0.07, 1.16, (0, y, z + 0.88), "iron", 8, radius_top=0.05)
        m.box((0.16, 0.16, 0.06), (0, y, z + 1.49), "iron")
        m.box((0.26, 0.26, 0.32), (0, y, z + 1.68), "lamp_glow")
        m.cylinder(0.24, 0.13, (0, y, z + 1.905), "iron", 4, radius_top=0.03, rot=rotz(45))
        m.box((0.05, 0.05, 0.08), (0, y, z + 2.01), "iron")
    # The cornice, wrapping the pilasters.
    m.box((2 * PIER + 0.2, 2 * half_y + 0.24, 0.22), (0, 0, DECK - 0.09), "warm_white", bevel=0.02)
    m.build("pier", r)


# ---- The tram ----

TRAM_HW = 1.2       # half-width at the sides
TRAM_NOSE = 1.0     # how far the nose rounds off, in plan
TRAM_CORNER = 0.14  # the joint ends' corner radius, in plan
# The body's rings up the side: (z, inset from the sides, pull back from the
# nose). The windscreen rakes back; the roof rolls over.
TRAM_RINGS = [(0.30, 0.06, 0.06), (0.36, 0.0, 0.0), (0.46, 0.0, 0.0), (0.98, 0.0, 0.0), (1.25, 0.0, 0.0),
              (2.55, 0.0, 0.30), (2.72, 0.0, 0.36), (2.98, 0.0, 0.44), (3.14, 0.0, 0.50), (3.24, 0.04, 0.56),
              (3.31, 0.12, 0.64), (3.35, 0.26, 0.78)]
# The inner core's rings: 3 cm inside the body throughout, behind every
# seam between the livery's colours; inside, it lines the walls.
TRAM_CORE = [(0.36, 0.03, 0.03), (1.25, 0.03, 0.03), (2.55, 0.03, 0.33), (2.98, 0.03, 0.47), (3.14, 0.03, 0.53),
             (3.24, 0.07, 0.59), (3.30, 0.15, 0.68)]
# Each band's colour along the sides and round the nose.
TRAM_BANDS = [("tram_dark", "tram_dark"), ("tram_cream", "tram_dark"), ("tram_coral", "tram_coral"),
              ("tram_cream", "tram_cream"), ("tram_cream", "glass"), ("tram_cream", "tram_dark"),
              ("tram_coral", "tram_coral"), ("tram_cream", "tram_cream"), ("tram_cream", "tram_cream"),
              ("warm_white", "warm_white"), ("warm_white", "warm_white")]
# The glazing runs between the rings at these heights, where the roof (its
# own node, which the client fades in overhead views) begins; doors open
# from the floor ring to the roof.
TRAM_SILL, TRAM_HEAD, TRAM_FLOOR_RING = 1.25, 2.55, 0.36
# The gangway through each joint end, either side of the middle.
TRAM_GANGWAY = 0.85
# Door leaves stand just proud of the body and its window frames.
TRAM_LEAF_OUT = TRAM_HW + 0.06
# The sections, the line's 20.5 m end to end (tram_layout.LENGTH_CM): (x0,
# x1, nose end), and their windows and doors on each side: (x0, x1,
# panes); panes 0 is a door, at the shared layout's doors.
TRAM_SECTIONS = [(-10.25, -3.25, -1, [(-9.05, -7.0, 2), (-6.8, -5.5, 0), (-5.3, -3.55, 2)]),
                 (-2.85, 2.85, 0, [(-2.55, -0.85, 2), (-0.65, 0.65, 0), (0.85, 2.55, 2)]),
                 (3.25, 10.25, 1, [(3.55, 5.3, 2), (5.5, 6.8, 0), (7.0, 9.05, 2)])]
TRAM_JOINTS = (-3.05, 3.05)
assert sorted((a, b) for *_, openings in TRAM_SECTIONS for a, b, panes in openings if not panes) == \
    sorted((round(a, 3), round(b, 3)) for a, b in tram_layout.doors_m()), "the doors are the shared layout's"


def _tram_plan(x0, x1, nose, inset, pull, support=True):
    """A section's outline seen from above, anticlockwise: joint ends with
    rounded corners; a nose end rounded into a half-ellipse, drawn back by
    `pull`. `support` adds a point 2 cm along the flat beside each curve,
    so smooth shading leaves the long sides truly flat. Returns the points
    and the x of the nose's start."""
    if nose < 0:
        pts, c = _tram_plan(-x1, -x0, 1, inset, pull, support)
        return [(-x, y) for x, y in reversed(pts)], -c
    h, r = TRAM_HW - inset, TRAM_CORNER

    def corner(cx, cy, a0):
        """A quarter round from angle a0, with a support point 2 cm along
        the flat either side."""
        arc = [(cx + r * math.cos(math.radians(a0 + 30 * k)), cy + r * math.sin(math.radians(a0 + 30 * k)))
               for k in range(4)]
        if not support:
            return arc
        t0, t1 = math.radians(a0), math.radians(a0 + 90)
        return ([(arc[0][0] + 0.02 * math.sin(t0), arc[0][1] - 0.02 * math.cos(t0))] + arc +
                [(arc[-1][0] - 0.02 * math.sin(t1), arc[-1][1] + 0.02 * math.cos(t1))])

    a = x0 + inset
    pts = []
    if nose == 0:
        b = x1 - inset
        pts += corner(b - r, -h + r, -90) + corner(b - r, h - r, 0)
        c = None
    else:
        c = x1 - TRAM_NOSE
        d = TRAM_NOSE - pull
        nose_pts = [(c + d * math.cos(math.radians(-90 + 22.5 * k)), h * math.sin(math.radians(-90 + 22.5 * k)))
                    for k in range(9)]
        pts += ([(c - 0.02, -h)] + nose_pts + [(c - 0.02, h)]) if support else nose_pts
    pts += corner(a + r, h - r, 90) + corner(a + r, -h + r, 180)
    return pts, c


def _tram_outline(x0, x1, nose, inset, pull, openings, support=True):
    """A section's outline (_tram_plan) with points where its windows and
    doors meet the long sides, and either side of the gangway on each joint
    end, so the faces between can be glazed or left open. Returns the
    points and, for the edge from each point to the next, what it is:
    'window', 'door', 'gangway' or 'wall'."""
    pts, _ = _tram_plan(x0, x1, nose, inset, pull, support)
    h = TRAM_HW - inset
    xs = sorted({x for a, b, _ in openings for x in (a, b)})
    joints = [x for x, joint in ((x0 + inset, nose >= 0), (x1 - inset, nose <= 0)) if joint]
    out = []
    n = len(pts)
    for k in range(n):
        p, q = pts[k], pts[(k + 1) % n]
        out.append(p)
        if abs(p[1] - q[1]) < 1e-9 and abs(abs(p[1]) - h) < 1e-9:
            cuts = [(x, p[1]) for x in xs if min(p[0], q[0]) + 1e-6 < x < max(p[0], q[0]) - 1e-6]
            out += sorted(cuts, reverse=q[0] < p[0])
        elif abs(p[0] - q[0]) < 1e-9 and any(abs(p[0] - j) < 1e-9 for j in joints):
            cuts = [(p[0], y) for y in (-TRAM_GANGWAY, TRAM_GANGWAY) if min(p[1], q[1]) + 1e-6 < y < max(p[1], q[1]) - 1e-6]
            out += sorted(cuts, key=lambda v: v[1], reverse=q[1] < p[1])
    kinds = []
    for k in range(len(out)):
        (px, py), (qx, qy) = out[k], out[(k + 1) % len(out)]
        kind = "wall"
        if abs(py - qy) < 1e-9 and abs(abs(py) - h) < 1e-9:
            mx = (px + qx) / 2
            for a, b, panes in openings:
                if a < mx < b:
                    kind = "window" if panes else "door"
        elif abs(px - qx) < 1e-9 and any(abs(px - j) < 1e-9 for j in joints) and abs(py + qy) / 2 < TRAM_GANGWAY:
            kind = "gangway"
        kinds.append(kind)
    return out, kinds


def _tram_section(m, roof, x0, x1, nose, openings):
    """A section's body up to the roof in `m`, lofted up the side in the
    livery's bands: glass in its windows, open in its doors and its
    gangways. Its roof, from the windows' head up, goes in `roof`, over a
    ceiling. The inner core lines both. Returns the x of the nose's start."""
    below = [(z, i, p) for z, i, p in TRAM_RINGS if z <= TRAM_HEAD]
    above = [(z, i, p) for z, i, p in TRAM_RINGS if z >= TRAM_HEAD]
    flat, c = _tram_plan(x0, x1, nose, 0.0, 0.0)
    outline, kinds = _tram_outline(x0, x1, nose, 0.0, 0.0, openings)
    n = len(outline)

    def on_nose_of(pts):
        return [nose != 0 and all(nose * pts[i][0] >= nose * c - 1e-6 for i in (k, (k + 1) % len(pts)))
                for k in range(len(pts))]

    def bands(pts, offset):
        on_nose = on_nose_of(pts)
        # The windscreen's outermost facets are its dark frame.
        edge = [on_nose[k] and not (on_nose[k - 1] and on_nose[(k + 1) % len(pts)]) for k in range(len(pts))]

        def band(i, k):
            mat = TRAM_BANDS[i + offset][1 if on_nose[k] else 0]
            return "tram_dark" if mat == "glass" and edge[k] else mat
        return band

    lower = bands(outline, 0)

    def body_band(i, k):
        z = below[i][0]
        if kinds[k] in ("door", "gangway") and z >= TRAM_FLOOR_RING:
            return None
        if kinds[k] == "window" and z >= TRAM_SILL:
            return "glass"
        return lower(i, k)

    _loft(m, [[(x, y, z) for x, y in _tram_outline(x0, x1, nose, inset, pull, openings)[0]] for z, inset, pull in below],
          body_band, "tram_dark", None)
    rings = [[(x, y, z) for x, y in _tram_plan(x0, x1, nose, inset, pull)[0]] for z, inset, pull in above]
    assert len(rings[0]) == len(flat)
    _loft(roof, rings, bands(flat, len(below) - 1), "tram_cream", "warm_white")
    # The core: the walls' lining below, the roof's above.
    core_below = [(z, i, p) for z, i, p in TRAM_CORE if z <= TRAM_HEAD]
    core_above = [(z, i, p) for z, i, p in TRAM_CORE if z >= TRAM_HEAD]
    _, core_kinds = _tram_outline(x0, x1, nose, 0.0, 0.0, openings, support=False)

    def core_band(i, k):
        if core_kinds[k] in ("door", "gangway") or (core_kinds[k] == "window" and core_below[i][0] >= TRAM_SILL):
            return None
        return "tram_cream"

    _loft(m, [[(x, y, z) for x, y in _tram_outline(x0, x1, nose, inset, pull, openings, support=False)[0]]
              for z, inset, pull in core_below], core_band, "tram_cream", None)
    _loft(roof, [[(x, y, z) for x, y in _tram_plan(x0, x1, nose, inset, pull, support=False)[0]]
                 for z, inset, pull in core_above], lambda i, k: "tram_cream", None, "tram_cream")
    assert n == len(kinds)
    return c


def _tram_side(m, openings):
    """On both sides, black frames round the windows (sill, head, jambs and
    a mullion between panes) and dark jambs and a head round each door."""
    for s in (-1, 1):
        y = s * (TRAM_HW + 0.015)
        for x0, x1, panes in openings:
            if panes:
                m.box((x1 - x0 + 0.06, 0.02, 0.07), ((x0 + x1) / 2, y, TRAM_SILL), "frame")
                m.box((x1 - x0 + 0.06, 0.02, 0.07), ((x0 + x1) / 2, y, TRAM_HEAD - 0.03), "frame")
                w = (x1 - x0) / panes
                for k in range(panes + 1):
                    m.box((0.06, 0.02, TRAM_HEAD - TRAM_SILL), (x0 + k * w, y, (TRAM_SILL + TRAM_HEAD) / 2), "frame")
            else:
                for x in (x0 - 0.03, x1 + 0.03):
                    m.box((0.06, 0.02, TRAM_HEAD - TRAM_FLOOR_RING), (x, y, (TRAM_FLOOR_RING + TRAM_HEAD) / 2),
                          "tram_dark")
                m.box((x1 - x0 + 0.12, 0.02, 0.07), ((x0 + x1) / 2, y, TRAM_HEAD - 0.03), "tram_dark")


def _tram_nose(m, roof, c, nose):
    """Headlights low on the nose, and a lit destination sign over the
    windscreen on the roof."""
    for t in (-50, 50):
        a = math.radians(t)
        x = c + nose * TRAM_NOSE * math.cos(a)
        y = TRAM_HW * math.sin(a)
        normal = math.atan2(math.sin(a) / TRAM_HW, nose * math.cos(a) / TRAM_NOSE)
        m.box((0.1, 0.26, 0.12), (x, y, 0.72), "lamp_glow", rot=rotz(math.degrees(normal)))
    tip = c + nose * (TRAM_NOSE - 0.33)
    roof.box((0.16, 0.62, 0.08), (tip - nose * 0.05, 0, 2.635), "window_glow")


def _tram_inside(x):
    """How far either side of the middle the floor and seats may reach at
    x: 8 cm inside the body, narrowing round the noses."""
    hw = TRAM_HW - 0.08
    for x0, x1, nose, _ in TRAM_SECTIONS:
        if nose:
            c = x1 - TRAM_NOSE if nose > 0 else x0 + TRAM_NOSE
            t = (x - c) * nose / TRAM_NOSE
            if t > 0:
                return max(0.0, TRAM_HW * math.sqrt(max(0.0, 1 - t * t)) - 0.08)
    return hw


def tram():
    """The sheets' tram: three cream sections articulated on dark bellows, a
    coral skirt and a coral band under the roof, big dark-framed windows
    you see the riders through, dark glazed doors that slide open, rounded
    noses with raked windscreens framed in black under a lit sign, dark roof
    equipment and a pantograph over the middle section. Inside, on the
    shared layout: a floor, seats, poles by the doors and ceiling lights.
    Nodes: body, roof (from the windows' head up), interior, lights, and
    the door leaves (tram_parts.doors)."""
    tram_layout.write()
    r = lib.root("tram")
    m, roof = Mesh(), Mesh()
    for x0, x1, nose, openings in TRAM_SECTIONS:
        c = _tram_section(m, roof, x0, x1, nose, openings)
        _tram_side(m, openings)
        if nose:
            _tram_nose(m, roof, c, nose)
            # Roof equipment: a long housing with a dark grille.
            xc = (x0 + x1) / 2 - nose * 0.3
            roof.box((2.8, 1.3, 0.28), (xc, 0, 3.47), "steel_dark", bevel=0.06)
            roof.box((1.8, 0.9, 0.08), (xc, 0, 3.64), "tram_dark", bevel=0.02)
    # Bellows at the joints: their sides and roof, open through the middle.
    for x in TRAM_JOINTS:
        for s in (-1, 1):
            m.box((0.52, 0.3, 2.19), (x, s * 0.99, 1.465), "tram_dark", bevel=0.04)
        roof.box((0.52, 2.2, 0.62), (x, 0, 2.87), "tram_dark", bevel=0.04)
        m.box((0.52, 1.8, 0.06), (x, 0, 0.37), "tram_dark")
    # Bogies: dark frames, the wheels mostly hidden by the skirt, all below
    # the floor.
    for x in (-8.15, -4.45, 0.0, 4.45, 8.15):
        m.box((1.9, 1.8, 0.24), (x, 0, 0.24), "tram_dark", bevel=0.02)
        for w in (-0.5, 0.5):
            m.cylinder(0.2, 2.0, (x + w, 0, 0.2), "iron", 10, rot=lib.rotx(90))
    # The pantograph on the middle section: base, a single folding arm and
    # the collector head.
    roof.box((1.3, 1.0, 0.1), (0, 0, 3.4), "steel_dark", bevel=0.02)
    roof.box((0.9, 1.1, 0.22), (1.9, 0, 3.46), "steel_dark", bevel=0.04)
    roof.beam((-0.5, 0, 3.46), (0.32, 0, 3.98), 0.07, "iron")
    roof.beam((0.32, 0, 3.98), (-0.3, 0, 4.34), 0.05, "iron")
    roof.box((0.08, 1.5, 0.05), (-0.3, 0, 4.37), "iron")
    for s in (-1, 1):
        roof.beam((-0.3, s * 0.74, 4.37), (-0.3, s * 0.92, 4.29), 0.035, "iron")
    lib.smooth(m.build("body", r))
    lib.smooth(roof.build("roof", r))
    tram_insides(r, _tram_inside, TRAM_LEAF_OUT)


def tram_insides(r, inside, leaf_out, colours=None):
    """The interior on the sections' floors, the ceiling lights and the
    doors (tram_parts); `inside(x)` is how far the floor may reach either
    side at x."""
    spans = [(x0 + 0.05, x1 - 0.05) for x0, x1, *_ in TRAM_SECTIONS]
    spans += [(a - 0.05, b + 0.05) for a, b in zip([s[1] for s in TRAM_SECTIONS], [s[0] for s in TRAM_SECTIONS[1:]])]
    tram_parts.interior(r, spans, inside, colours)
    lights = [(x0 + 0.5, x1 - 0.5) if not nose else ((x0 + 0.5, x1 - 1.2) if nose > 0 else (x0 + 1.2, x1 - 0.5))
              for x0, x1, nose, _ in TRAM_SECTIONS]
    tram_parts.lights(r, lights, colours)
    tram_parts.doors(r, leaf_out, colours)


# ---- Sky and river ----

def _lobe(m, cx, cy, cz, rx, ry, top, bottom, seg=12, rings=7):
    """A cloud lobe: an ellipsoid `top` tall above its centre and `bottom`
    below; faces turned down are the soft blue-grey underside."""
    tmp = bmesh.new()
    rows = [[tmp.verts.new((cx, cy, cz + top))]]
    for i in range(1, rings):
        phi = math.pi * i / rings
        z = math.cos(phi)
        zz = cz + z * (top if z >= 0 else bottom)
        rows.append([tmp.verts.new((cx + rx * math.sin(phi) * math.cos(2 * math.pi * j / seg),
                                    cy + ry * math.sin(phi) * math.sin(2 * math.pi * j / seg), zz))
                     for j in range(seg)])
    rows.append([tmp.verts.new((cx, cy, cz - bottom))])
    for a, b in zip(rows, rows[1:]):
        for j in range(seg):
            j2 = (j + 1) % seg
            if len(a) == 1:
                tmp.faces.new([a[0], b[j], b[j2]])
            elif len(b) == 1:
                tmp.faces.new([a[j], b[0], a[j2]])
            else:
                tmp.faces.new([a[j], b[j], b[j2], a[j2]])
    bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
    tmp.normal_update()
    white, grey = m.slot("warm_white"), m.slot("steel_light")
    for f in tmp.faces:
        f.material_index = grey if f.normal.z < -0.35 else white
    m._merge_indexed(tmp, None, (0, 0, 0))


def _cloud(name, lobes):
    r = lib.root(name)
    m = Mesh()
    for lobe in lobes:
        _lobe(m, *lobe)
    lib.smooth(m.build("cloud", r), 60)


def cloud_a():
    """A broad cumulus: a tall crown between two shoulders, flat-bottomed."""
    _cloud("cloud_a", [(0.3, 0.0, 1.3, 2.3, 2.0, 2.7, 1.3), (-2.4, 0.2, 1.0, 1.9, 1.7, 2.0, 1.0),
                       (2.7, -0.1, 0.95, 1.9, 1.8, 2.1, 0.95), (-4.0, 0.0, 0.6, 1.0, 1.1, 1.3, 0.6),
                       (4.1, 0.2, 0.55, 0.9, 1.0, 1.2, 0.55), (-1.1, 0.4, 2.5, 1.2, 1.2, 1.5, 0.9),
                       (1.7, -0.3, 2.3, 1.1, 1.1, 1.3, 0.8), (0.8, 1.1, 0.9, 1.2, 1.1, 1.4, 0.9),
                       (-0.9, -1.2, 0.85, 1.1, 1.0, 1.3, 0.85)])


def cloud_b():
    """A smaller cumulus."""
    _cloud("cloud_b", [(0.0, 0.0, 1.1, 1.9, 1.7, 2.3, 1.1), (-2.2, 0.1, 0.8, 1.5, 1.4, 1.7, 0.8),
                       (2.1, -0.1, 0.85, 1.5, 1.5, 1.8, 0.85), (-3.4, 0.0, 0.45, 0.7, 0.8, 1.0, 0.45),
                       (3.3, 0.1, 0.5, 0.8, 0.8, 1.0, 0.5), (0.9, 0.3, 2.0, 1.0, 1.0, 1.4, 0.8),
                       (-0.6, 0.9, 0.7, 1.0, 1.0, 1.2, 0.7), (0.5, -1.0, 0.65, 0.9, 0.9, 1.1, 0.65)])


# Hull stations from the transom to the stem: (y, half-beam, sheer height,
# depth of the keel below the waterline).
HULL = [(-2.3, 0.70, 0.52, 0.18), (-1.6, 0.84, 0.50, 0.26), (-0.6, 0.90, 0.50, 0.30), (0.5, 0.86, 0.52, 0.30),
        (1.4, 0.66, 0.56, 0.26), (2.1, 0.36, 0.60, 0.18), (2.6, 0.04, 0.64, 0.05)]
# The hull's section runs from the starboard sheer down round the keel and
# back across the deck; each segment's colour: a blue sheer stripe, white
# topsides, a blue bottom, a teak deck.
HULL_SEGMENTS = ["blue", "warm_white", "blue", "blue", "blue", "blue", "warm_white", "blue", "wood_light",
                 "wood_light"]


def sailboat():
    """A small white sloop: a round-bilged hull with a blue sheer stripe, a
    teak deck and a little cabin, a silver mast, the mainsail set on a blue
    boom and a jib, both eased to starboard."""
    r = lib.root("sailboat")
    m = Mesh()
    rings = []
    for y, b, zs, d in HULL:
        rings.append([(b, y, zs), (0.97 * b, y, zs - 0.16), (0.9 * b, y, 0.06), (0.6 * b, y, -0.6 * d), (0, y, -d),
                      (-0.6 * b, y, -0.6 * d), (-0.9 * b, y, 0.06), (-0.97 * b, y, zs - 0.16), (-b, y, zs),
                      (0, y, zs + 0.04)])
    _loft(m, rings, lambda i, k: HULL_SEGMENTS[k], "warm_white", "warm_white")
    core = [[(0.85 * b, y, zs - 0.06), (0.72 * b, y, 0.0), (0, y, -0.75 * d), (-0.72 * b, y, 0.0),
             (-0.85 * b, y, zs - 0.06)] for y, b, zs, d in HULL[:-1]]
    _loft(m, core, lambda i, k: "warm_white", "warm_white", "warm_white")
    # The cabin, with portholes.
    m.box((0.9, 1.1, 0.3), (0, 0.55, 0.66), "warm_white", bevel=0.04)
    for s in (-1, 1):
        for y in (0.3, 0.8):
            x = s * 0.462
            v = [(x, y - 0.1 * s, 0.63), (x, y + 0.1 * s, 0.63), (x, y + 0.1 * s, 0.71), (x, y - 0.1 * s, 0.71)]
            _add(m, v, [(0, 1, 2, 3)], "glass")
    # Mast, boom and sails.
    mast = (0.0, 0.75)
    m.cylinder(0.05, 5.7, (mast[0], mast[1], 3.65), "steel_light", 8, radius_top=0.035)
    clew = (0.45, -1.78)
    m.beam((mast[0], mast[1] - 0.04, 1.2), (clew[0], clew[1], 1.2), 0.08, "blue")
    _sheet(m, [(0.02, 0.7, 1.26), (clew[0], clew[1] + 0.02, 1.27), (0.4, -0.95, 3.2), (0.03, 0.71, 6.3)], "canvas")
    _sheet(m, [(0.0, 2.5, 0.74), (0.02, 0.82, 5.5), (0.55, 0.35, 0.95)], "canvas")
    lib.smooth(m.build("boat", r))


# ---- Paving and paths ----

# The slabs of each 1 m tile as (x0, y0, x1, y1, colour), on a 0.5 m grid so
# joints run straight across neighbouring (and turned) tiles; JOINT wide.
TILES = {
    "a": [(0, 0, 1, 0.5, "paving_light"), (0, 0.5, 1, 1, "paving")],
    "b": [(0, 0, 0.5, 1, "paving"), (0.5, 0, 1, 0.5, "paving_light"), (0.5, 0.5, 1, 1, "paving")],
    "c": [(0, 0, 0.5, 0.5, "paving_light"), (0.5, 0, 1, 0.5, "paving"), (0, 0.5, 0.5, 1, "paving"),
          (0.5, 0.5, 1, 1, "paving_light")],
}
JOINT = 0.03


def paving_tile(key):
    def build():
        """The square's cream stone paving: slabs inlaid flush in a top of
        grout colour, with 3 cm joints (half a joint at each edge, so
        neighbours make whole ones). Flush and flat, the joints read as
        soft lines: no chamfers for the ink pass to draw into a grid, none
        too thin to break into dots at a distance."""
        m = Mesh()
        outer = [(-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)]
        h = JOINT / 2
        slabs = [([(x0 - 0.5 + h, y0 - 0.5 + h), (x1 - 0.5 - h, y0 - 0.5 + h), (x1 - 0.5 - h, y1 - 0.5 - h),
                   (x0 - 0.5 + h, y1 - 0.5 - h)], mat) for x0, y0, x1, y1, mat in TILES[key]]
        _inlaid(m, outer, slabs, 0.06, "paving_dark")
        _add(m, [(x, y, 0.05) for x, y in outer], [(0, 1, 2, 3)], "paving_dark")
        _sides(m, outer, 0.0, 0.06, "paving_dark")
        m.build(f"paving_tile_{key}")
    build.__doc__ = build.__doc__.replace("paving:", f"paving, variant {key}:")
    return build


def path():
    """A metre of the park's path running along Y: pale gravel between low
    stone edgings."""
    m = Mesh()
    _block(m, (-0.4, -0.5, 0.0), (0.4, 0.5, 0.045), "paving_light")
    for s in (-1, 1):
        prof = [(0.4, 0.0), (0.5, 0.0), (0.5, 0.045), (0.485, 0.06), (0.415, 0.06), (0.4, 0.045)]
        m.prism([(s * u, w) for u, w in prof], 1.0, (0, 0, 0), "paving_dark", axis="y")
    m.build("path")


# ---- Railings ----

RAIL_H = 1.0


def _railing_post(m, x):
    """A square black iron post on a base plate, collared, with a ball
    finial."""
    m.box((0.14, 0.14, 0.05), (x, 0, 0.025), "iron", bevel=0.01)
    m.box((0.075, 0.075, RAIL_H - 0.01), (x, 0, 0.05 + (RAIL_H - 0.01) / 2), "iron", bevel=0.008)
    m.box((0.1, 0.1, 0.03), (x, 0, RAIL_H + 0.055), "iron", bevel=0.008)
    m.sphere(0.032, (x, 0, RAIL_H + 0.09), "iron", subdivisions=2)


def railing():
    """Two metres of the waterfront railing, running along x from -1 to 1:
    a post at the -x end (the next module's post, or a `railing_post`,
    closes the +x end), a slimmer baluster midway, black iron rails, and a
    white cap along the handrail."""
    m = Mesh()
    _railing_post(m, -0.93)
    m.box((0.045, 0.045, RAIL_H - 0.16), (0.07, 0, 0.14 + (RAIL_H - 0.16) / 2), "iron", bevel=0.006)
    m.box((2.0, 0.04, 0.04), (0, 0, RAIL_H - 0.02), "iron")
    m.box((2.0, 0.075, 0.035), (0, 0, RAIL_H + 0.0175), "warm_white", bevel=0.01)
    for z in (0.55, 0.15):
        m.box((2.0, 0.03, 0.03), (0, 0, z), "iron")
    lib.finish("railing", {"body": m}, smooth_parts=("body",))


def railing_post():
    """The post that closes a run of railing, or turns its corner."""
    m = Mesh()
    _railing_post(m, 0.0)
    lib.finish("railing_post", {"body": m}, smooth_parts=("body",))


ASSETS = {
    "street_tile": street_tile,
    "street_kerb": street_kerb,
    "tram_track": tram_track,
    "water_tile": water_tile,
    "bridge_span": bridge_span,
    "bridge_pier": bridge_pier,
    "tram": tram,
    "cloud_a": cloud_a,
    "cloud_b": cloud_b,
    "sailboat": sailboat,
    "paving_tile_a": paving_tile("a"),
    "paving_tile_b": paving_tile("b"),
    "paving_tile_c": paving_tile("c"),
    "path": path,
    "railing": railing,
    "railing_post": railing_post,
}
