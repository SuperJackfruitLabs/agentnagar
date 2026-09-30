"""Building modules for the solarpunk kit, after the 09 sheets: the
workshop's blonde timber under sawtooth bays whose long faces are deep blue
solar panels, warm glazing, vines and planters; the library's white ceramic
drum, two storeys of warm glazing between white bands, under a planted rim
and a glass-and-solar dome; rounded white towers with curved balconies,
planted terraces and solar crowns; white and cream houses with solar roofs,
pergolas and awnings; a timber tram shelter under a solar roof.

The pack renders the kit lit and physically based, so form reads through
real depth (reveals, projecting bands, bevels) and material contrast:
ceramic against timber, glass, brass and solar.

Conventions match the low-poly and anime kits so the townscape assembles
the same way (Blender Z-up; a wall module spans x in [-W/2, W/2] with its
outer face on y = 0 facing +Y, Godot's forward -Z, its body behind at
y < 0; z = 0 is the ground):
    hall_wall, hall_window_wall                   4 m bays, 5.2 m high
    hall_door_wall     a door bay (DOOR_W): the opening clear, a lintel
    hall_door_leaves   one side's doors folded into the reveal
    hall_corner                                   a ceramic corner pier
    hall_sawtooth_bay                             4 m x 4 m of roof over
                                                  z = 0 at the wall top
    hall_sawtooth_gable                           closes a tooth's end
    lib_wall_arch      a 2 m bay, 8 m high: two storeys of warm glazing
    lib_column         the ceramic fin at every bay joint and corner
    lib_entrance       a door bay (DOOR_W): glazing over the open
                       doorway under a curved canopy, a low step
    lib_door_leaves    one side's doors folded into the reveal
    lib_roof           the roof over the 20 m x 18 m library, z = 0 at the
                       wall top, origin at the footprint's centre: a planted
                       rim round a glass-and-solar dome
    lib_banner         a jade banner hanging below its bracket (z = 0)
Blocks (origin at the footprint's centre on the ground, fronts facing +Y):
    tower_a, tower_b   rounded white towers stepping back to planted terraces
    house_a/b/c        three-storey white and cream houses, solar roofs
    shop_a             a shopfront under a jade awning, two floors above
    tram_shelter       a timber-and-glass shelter, open to +Y
"""
import math
import random

import lib
from lib import Mesh, rect_hole

# Materials whose faces shade soft all over (foliage); everything else keeps
# edges sharper than the shading angle hard.
SOFT = {"leaf", "leaf_dark", "leaf_light", "leaf_sun", "vine", "palm", "palm_light", "flower_white",
        "flower_pink", "flower_yellow", "flower_coral", "grass"}


# ---- Shared helpers ----

def _shade(obj, angle=35.0):
    """Smooth-shades `obj`: edges sharper than `angle` degrees stay hard
    (boxes, bevels, slabs), curves go soft, and foliage is soft all over."""
    me = obj.data
    for p in me.polygons:
        p.use_smooth = True
    me.set_sharp_from_angle(angle=math.radians(angle))
    soft = {i for i, m in enumerate(me.materials) if m.name in SOFT}
    attr = me.attributes.get("sharp_edge")
    if soft and attr is not None:
        index = {e.key: e.index for e in me.edges}
        hard = {}
        for p in me.polygons:
            leafy = p.material_index in soft
            for key in p.edge_keys:
                i = index[key]
                hard[i] = hard.get(i, False) or not leafy
        for i, h in hard.items():
            if not h:
                attr.data[i].value = False
    return obj


# Colours folded together when a part is built, to keep each module's
# surfaces (draw calls) few: foliage in three greens and two flower colours
# everywhere, and the workshop's repeated bays leaner still.
MERGE = {"leaf_sun": "leaf_light", "vine": "leaf_dark", "flower_white": "flower_yellow",
         "flower_pink": "flower_coral"}
LEAN = dict(MERGE, leaf_dark="leaf", vine="leaf", soil="leaf", warm_white="ceramic", brass_dark="brass")


def _build(m, node, parent, angle=35.0, merge=MERGE):
    """Builds `m` as the part `node` under `parent`, its colours folded by
    `merge`, and shades it."""
    names = [merge.get(n, n) for n in m.mats]
    kept = list(dict.fromkeys(names))
    remap = [kept.index(n) for n in names]
    for f in m.bm.faces:
        f.material_index = remap[f.material_index]
    m.mats = kept
    return _shade(m.build(node, parent), angle)


def _clump(m, at, radius, seed, scale=(1.0, 1.0, 0.85), mat="leaf", cap="leaf_light", cut=None, sub=2,
           wall=False):
    """A leafy clump: a lumpy ball, flat underneath, its sunlit top in
    `cap`. `cut` drops the faces below that fraction of the radius; `wall`
    drops its back half (it hangs on a wall facing +y)."""
    tmp = lib.bmesh.new()
    lib.bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=radius)
    if cut is not None:
        lib.bmesh.ops.delete(tmp, geom=[v for v in tmp.verts if v.co.z < -cut * radius], context="VERTS")
    if wall:
        lib.bmesh.ops.delete(tmp, geom=[v for v in tmp.verts if v.co.y < -0.3 * radius], context="VERTS")
    rng = random.Random(seed)
    for v in tmp.verts:
        v.co.x *= scale[0]
        v.co.y *= scale[1]
        v.co.z *= scale[2]
        v.co += lib.Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.1
        v.co.z = max(v.co.z, -radius * scale[2] * 0.5)
        if wall:
            v.co.y = max(v.co.y, 0.0)
    tmp.normal_update()
    top, side = m.slot(cap), m.slot(mat)
    for f in tmp.faces:
        f.material_index = top if f.normal.z > 0.55 else side
    m._merge_indexed(tmp, None, at)


def _vine(m, x, y, z0, z1, seed, spread=0.3, depth=0.18, step=0.7):
    """A climbing vine up a wall face from z0 to z1: half-clumps of leaves
    stacked and staggered on the face at y, standing `depth` off it."""
    rng = random.Random(seed)
    z = z0 + 0.3
    k = 0
    while z < z1 - 0.1:
        r = rng.uniform(0.3, 0.36)
        dx = rng.uniform(-1, 1) * spread * 0.5
        _clump(m, (x + dx, y, z), r, seed * 17 + k, scale=(0.95, depth / r, 1.2),
               mat=("vine", "leaf_dark", "leaf")[k % 3], cap="leaf_light", wall=True)
        z += step * rng.uniform(0.9, 1.1)
        k += 1


def _flowers(m, at, radius, seed, colour):
    """A small flowering shrub heaped on a planter."""
    _clump(m, at, radius, seed, scale=(1.15, 1.0, 0.8), mat="leaf", cap=colour, cut=0.0, sub=1)


def _rrect(w, d, r, seg=4, cx=0.0, cy=0.0):
    """The outline of a w x d rectangle with corners rounded to r,
    counter-clockwise seen from above."""
    pts = []
    hw, hd = w / 2 - r, d / 2 - r
    for sx, sy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(seg + 1):
            a = math.radians(a0 + 90 * k / seg)
            pts.append((cx + sx * hw + r * math.cos(a), cy + sy * hd + r * math.sin(a)))
    return pts


def _ellipse(rx, ry, n, cx=0.0, cy=0.0):
    return [(cx + rx * math.cos(2 * math.pi * k / n), cy + ry * math.sin(2 * math.pi * k / n)) for k in range(n)]


def _extrude(m, pts, z0, z1, mat):
    """A closed outline `pts` (counter-clockwise) extruded from z0 to z1."""
    m.prism(pts, z1 - z0, (0, 0, (z0 + z1) / 2), mat, axis="z")


def _tube(m, outer, inner, z0, z1, mat, top=True, bottom=True, outside=True, inside=True):
    """A ring between two outlines of the same point count (both
    counter-clockwise) from z0 to z1: its outer and inner walls, top and
    bottom."""
    tmp = lib.bmesh.new()
    n = len(outer)
    ob = [tmp.verts.new((x, y, z0)) for x, y in outer]
    ot = [tmp.verts.new((x, y, z1)) for x, y in outer]
    ib = [tmp.verts.new((x, y, z0)) for x, y in inner]
    it = [tmp.verts.new((x, y, z1)) for x, y in inner]
    for k in range(n):
        j = (k + 1) % n
        if outside:
            tmp.faces.new([ob[k], ob[j], ot[j], ot[k]])
        if inside:
            tmp.faces.new([ib[j], ib[k], it[k], it[j]])
        if top:
            tmp.faces.new([ot[k], ot[j], it[j], it[k]])
        if bottom:
            tmp.faces.new([ob[j], ob[k], ib[k], ib[j]])
    for v in [v for v in tmp.verts if not v.link_faces]:
        tmp.verts.remove(v)
    m._merge(tmp, mat, None, (0, 0, 0))


def _bullnose(m, x0, x1, y_back, y_front, z0, z1, mat, seg=4):
    """A band along x whose front edge is rounded: its back at y_back, its
    nose at y_front, from z0 to z1."""
    r = min((z1 - z0) / 2, y_front - y_back)
    zc = (z0 + z1) / 2
    prof = [(y_back, z0), (y_front - r, z0)]
    hz = (z1 - z0) / 2
    for k in range(1, seg):
        a = -math.pi / 2 + math.pi * k / seg
        prof.append((y_front - r + r * math.cos(a), zc + hz * math.sin(a)))
    prof += [(y_front - r, z1), (y_back, z1)]
    m.prism(prof, x1 - x0, ((x0 + x1) / 2, 0, 0), mat, axis="x")


def _merge_xform(m, tmp, degrees, offset, z=0.0):
    """Copies `tmp` (a Mesh built in a face's frame) into `m`, turned about
    Z and moved to `offset` (x, y)."""
    rot = lib.rotz(degrees)
    push = lib.Vector((offset[0], offset[1], z))
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


def _quad(m, centre, sx, sy, rot, mat):
    """A flat sx x sy rectangle at `centre` facing `rot`'s +z."""
    c = lib.Vector(centre)
    pts = [c + rot @ lib.Vector((ax * sx / 2, ay * sy / 2, 0)) for ax, ay in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    m._faces([tuple(p) for p in pts], [(0, 1, 2, 3)], mat)


def _modules(m, centre, rot, length, width, cols, rows, gap=0.05, lift=0.03):
    """Deep blue solar modules in `cols` x `rows` over a light frame plate
    (length x width about `centre`, facing `rot`'s +z), `lift` above it."""
    c = lib.Vector(centre)
    n = rot @ lib.Vector((0, 0, 1))
    cw, rw = (length - gap) / cols, (width - gap) / rows
    for i in range(cols):
        for j in range(rows):
            local = lib.Vector((-length / 2 + gap / 2 + cw * (i + 0.5), -width / 2 + gap / 2 + rw * (j + 0.5), 0.0))
            _quad(m, c + rot @ local + n * lift, cw - gap, rw - gap, rot, "solar")


def _solar_array(m, cx, cy, z, length, width, tilt, cols, rows, turn=0.0, legs=None):
    """A solar array `length` (along x, before `turn`) by `width`, tilted
    `tilt` degrees about x (a positive tilt raises its back edge, so it
    faces the front, +y), its centre at (cx, cy, z): deep blue modules in a
    light frame, `cols` x `rows` of them. `legs` (a height) stands it on
    brass posts."""
    rot = lib.rotz(turn) @ lib.rotx(-tilt)
    centre = lib.Vector((cx, cy, z))
    m.box((length, width, 0.05), centre, "solar_frame", rot=rot)
    _modules(m, centre, rot, length - 0.04, width - 0.04, cols, rows, lift=0.028)
    if legs is not None:
        for sx in (-1, 1):
            for sy in (-1, 1):
                top = centre + rot @ lib.Vector((sx * (length / 2 - 0.3), sy * (width / 2 - 0.3), -0.03))
                m.box((0.07, 0.07, top.z - legs), (top.x, top.y, (top.z + legs) / 2), "brass")


# ---- Workshop ----

HALL_BAY = 4.0
HALL_H = 5.2
WALL_T = 0.24
# A door bay: the door's 2 m opening and a reveal either side for its
# folded leaves; nothing stands in the opening in the walking band.
DOOR_REVEAL = 0.3
DOOR_W = 2.0 + 2 * DOOR_REVEAL
DOOR_H = 3.0
PLINTH = 0.35
BAND = (3.3, 3.62)


def _strip(m, x, width, proud, z0, z1, mat, y=0.0):
    """A vertical strip standing `proud` off a face at y: its front and
    sides only (the rest is hidden against the face)."""
    a, b = x + width / 2, x - width / 2
    f = y + proud
    m._faces([(a, y, z0), (a, f, z0), (b, f, z0), (b, y, z0), (a, y, z1), (a, f, z1), (b, f, z1), (b, y, z1)],
             [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6)], mat)


def _battens(m, x0, x1, z0, z1, every=0.3, y=0.0, back=False):
    """Vertical timber battens standing proud of a clad face (of its back
    face, looking -y, if `back`)."""
    n = max(1, round((x1 - x0) / every))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        if back:
            m._faces([(x - 0.035, y, z0), (x - 0.035, y - 0.045, z0), (x + 0.035, y - 0.045, z0), (x + 0.035, y, z0),
                      (x - 0.035, y, z1), (x - 0.035, y - 0.045, z1), (x + 0.035, y - 0.045, z1), (x + 0.035, y, z1)],
                     [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6)], "timber_light")
        else:
            _strip(m, x, 0.07, 0.045, z0, z1, "timber_light", y)


def _hall_glazing(m, x0, x1, z0, z1, cols, transom=None, depth=-0.12, pane="window_glow"):
    """Warm glazing set back in an opening: a slim dark frame, `cols` bays
    of mullions and a transom."""
    w, h = x1 - x0, z1 - z0
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    m.box((w, 0.03, h), (cx, depth, cz), pane)
    f = depth + 0.035
    for x in (x0 + 0.035, x1 - 0.035):
        m.box((0.07, 0.07, h), (x, f, cz), "frame")
    for z in (z0 + 0.04, z1 - 0.035):
        m.box((w, 0.07, 0.08 if z < cz else 0.07), (cx, f, z), "frame")
    for k in range(1, cols):
        m.box((0.05, 0.06, h), (x0 + w * k / cols, f, cz), "frame")
    if transom is not None:
        m.box((w, 0.06, 0.05), (cx, f, transom), "frame")


def _hall_frame(m, w, holes, base=0.0):
    """The hall wall's timber body with its openings, the white lining
    inside, the ceramic plinth and coping, and the ceramic band over the
    ground floor."""
    top = HALL_H - 0.2
    m.slab([(-w / 2, base), (w / 2, base), (w / 2, top), (-w / 2, top)], holes, WALL_T, (0, -WALL_T / 2, 0),
           "timber", reveal_mat="timber_light")
    m.slab([(-w / 2, base), (w / 2, base), (w / 2, top), (-w / 2, top)], holes, 0.02, (0, -WALL_T - 0.01, 0),
           "warm_white")
    if base < 0.01:
        return
    m.box((w, WALL_T + 0.06, PLINTH), (0, -WALL_T / 2 + 0.03, PLINTH / 2), "ceramic_shade", bevel=0.02)


def _hall_top(m, w):
    m.box((w, WALL_T + 0.12, 0.2), (0, -WALL_T / 2 + 0.06, HALL_H - 0.1), "ceramic", bevel=0.03)


def _hall_band(m, x0, x1):
    _bullnose(m, x0, x1, -0.02, 0.19, BAND[0], BAND[1], "ceramic")


def _trough(m, x0, x1, seed, flowers=("flower_coral", "flower_yellow", "flower_white")):
    """A slim ceramic planter trough along the wall's foot, heaped with
    shrubs and flowers."""
    m.box((x1 - x0, 0.2, 0.5), ((x0 + x1) / 2, 0.1, 0.25), "ceramic", bevel=0.02)
    m.box((x1 - x0 - 0.06, 0.14, 0.03), ((x0 + x1) / 2, 0.1, 0.5), "soil")
    rng = random.Random(seed)
    n = max(1, round((x1 - x0) / 0.5))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        cap = rng.choice(flowers) if k % 2 else rng.choice(("leaf_light", "leaf_sun"))
        _clump(m, (x, 0.1, 0.5), rng.uniform(0.2, 0.25), seed * 7 + k, scale=(1.2, 0.5, 0.9),
               mat=rng.choice(("leaf", "leaf_dark")), cap=cap, cut=0.0, sub=1)


def _trailing(m, x0, x1, seed):
    """Greenery spilling over the ceramic band."""
    rng = random.Random(seed)
    n = max(1, round((x1 - x0) / 0.45))
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        r = rng.uniform(0.2, 0.26)
        _clump(m, (x, 0.0, BAND[0] + 0.02 - rng.uniform(0.0, 0.2)), r, seed * 5 + k, scale=(1.3, 0.2 / r, 1.3),
               mat=rng.choice(("vine", "leaf")), cap="leaf_light", wall=True)


def hall_wall():
    """A timber bay with a tall window in a ceramic surround and a vine."""
    r = lib.root("hall_wall")
    m = Mesh()
    w = HALL_BAY
    x0, x1, z0, z1 = -0.75, 0.75, 0.9, 3.05
    _hall_frame(m, w, [rect_hole(x0, x1, z0, z1)], PLINTH)
    _hall_glazing(m, x0, x1, z0, z1, 2, transom=2.35)
    # The ceramic surround and sill.
    for x in (x0 - 0.07, x1 + 0.07):
        m.box((0.14, 0.1, z1 - z0 + 0.14), (x, 0.03, (z0 + z1) / 2), "ceramic", bevel=0.02)
    m.box((x1 - x0 + 0.28, 0.16, 0.1), (0, 0.05, z0 - 0.05), "ceramic", bevel=0.02)
    _battens(m, -w / 2, x0 - 0.14, PLINTH, BAND[0])
    _battens(m, x1 + 0.14, w / 2, PLINTH, BAND[0])
    _battens(m, x0 - 0.14, x1 + 0.14, z1 + 0.07, BAND[0], every=0.34)
    _battens(m, -w / 2, w / 2, BAND[1], HALL_H - 0.2)
    _hall_band(m, -w / 2, w / 2)
    _hall_top(m, w)
    _trough(m, -1.85, -0.95, 3)
    _vine(m, -1.45, 0.0, 0.5, BAND[0] + 0.1, 5, step=0.78)
    _trailing(m, 0.2, 1.8, 7)
    _build(m, "wall", r, merge=LEAN)


def hall_window_wall():
    """A timber bay round a wide storefront of warm glazing."""
    r = lib.root("hall_window_wall")
    m = Mesh()
    w = HALL_BAY
    x0, x1, z0, z1 = -1.5, 1.5, 0.55, BAND[0]
    _hall_frame(m, w, [rect_hole(x0, x1, z0, z1)], PLINTH)
    _hall_glazing(m, x0, x1, z0, z1, 3, transom=2.65)
    m.box((x1 - x0 + 0.1, 0.16, 0.1), (0, 0.04, z0 - 0.05), "ceramic", bevel=0.02)
    _battens(m, -w / 2, x0, PLINTH, BAND[0], every=0.25)
    _battens(m, x1, w / 2, PLINTH, BAND[0], every=0.25)
    _battens(m, -w / 2, w / 2, BAND[1], HALL_H - 0.2)
    _hall_band(m, -w / 2, w / 2)
    _hall_top(m, w)
    _trough(m, x0 + 0.1, x1 - 0.1, 11)
    _vine(m, 1.76, 0.0, 0.35, BAND[0] + 0.3, 13, spread=0.1)
    _trailing(m, -1.8, -0.4, 17)
    _build(m, "wall", r, merge=LEAN)


def hall_door_wall():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): timber over a black lintel and a glazed transom, under a
    ceramic canopy with a timber soffit, a timber landing and a lamp.
    Nothing stands in the opening below the lintel; the doors fold into the
    reveals (hall_door_leaves)."""
    r = lib.root("hall_door_wall")
    m = Mesh()
    w = DOOR_W
    top = HALL_H - 0.2
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, top), (-w / 2, top)], [], WALL_T, (0, -WALL_T / 2, 0),
           "timber", reveal_mat="timber_light")
    m.slab([(-w / 2, DOOR_H), (w / 2, DOOR_H), (w / 2, top), (-w / 2, top)], [], 0.02, (0, -WALL_T - 0.01, 0),
           "warm_white")
    # The glazed transom over the doorway, up to the band.
    m.box((w, 0.03, BAND[0] - DOOR_H), (0, -0.12, (DOOR_H + BAND[0]) / 2), "window_glow")
    m.box((w, WALL_T + 0.04, 0.1), (0, -WALL_T / 2, DOOR_H), "frame")
    _battens(m, -w / 2, w / 2, BAND[1], HALL_H - 0.2)
    _hall_band(m, -w / 2, w / 2)
    _hall_top(m, w)
    # The canopy: a ceramic slab with a timber soffit and a brass fascia,
    # hung on brass rods.
    _bullnose(m, -1.75, 1.75, 0.0, 1.4, BAND[0], BAND[0] + 0.2, "ceramic")
    m.box((3.4, 1.25, 0.04), (0, 0.67, BAND[0] - 0.02), "timber_light")
    m.box((3.5, 0.04, 0.05), (0, 1.32, BAND[0] + 0.03), "brass")
    for x in (-1.6, 1.6):
        m.beam((x, 0.0, 4.6), (x, 1.25, BAND[0] + 0.2), 0.04, "brass")
    m.box((0.36, 0.36, 0.06), (0, 0.8, BAND[0] - 0.05), "lamp_glow")
    # A timber landing (below the walking band).
    m.box((w + 0.2, 0.9, 0.08), (0, 0.45, 0.04), "timber_dark", bevel=0.01)
    _build(m, "wall", r, merge=LEAN)


def hall_door_leaves():
    """One side's glazed doors, folded open into the reveal beside the
    opening: four dark-framed panels with brass pulls, square to the wall
    and stacked across the reveal (x in [-DOOR_REVEAL / 2, DOOR_REVEAL / 2]),
    as deep as the wall."""
    r = lib.root("hall_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, WALL_T - 0.02, DOOR_H - 0.1), (x, -WALL_T / 2, (DOOR_H - 0.1) / 2 + 0.05), "frame")
        m.box((0.054, WALL_T - 0.08, DOOR_H - 0.5), (x, -WALL_T / 2, (DOOR_H - 0.5) / 2 + 0.25), "glass_light")
    m.box((0.3, 0.03, 0.03), (0, -0.01, 1.05), "brass")
    _build(m, "leaves", r, merge=LEAN)


def hall_corner():
    """A rounded ceramic pier at the hall's corner, carrying the band."""
    r = lib.root("hall_corner")
    m = Mesh()
    _extrude(m, _rrect(0.7, 0.7, 0.14), 0.0, PLINTH, "ceramic_shade")
    _extrude(m, _rrect(0.6, 0.6, 0.18, 4), PLINTH, HALL_H - 0.16, "ceramic")
    _extrude(m, _rrect(0.72, 0.72, 0.2, 4), BAND[0], BAND[1], "ceramic")
    _extrude(m, _rrect(0.72, 0.72, 0.2, 4), HALL_H - 0.16, HALL_H + 0.12, "ceramic")
    m.box((0.62, 0.62, 0.05), (0, 0, 1.9), "brass")
    _build(m, "pier", r, merge=LEAN)


SAW_H = 2.45
SAW_LOW = -2.02
SAW_HIGH = 1.74
SAW_FACE = 1.88


def _saw_z(x):
    """The sawtooth slope's height at x."""
    return (x - SAW_LOW) * SAW_H / (SAW_HIGH - SAW_LOW)


def hall_sawtooth_bay():
    """One 4 m x 4 m bay of sawtooth roof: a long slope rising east (+x),
    clad in a deep blue solar array in a light frame, to a steep face of
    warm clerestory glazing behind timber fins."""
    r = lib.root("hall_sawtooth_bay")
    m = Mesh()
    d = HALL_BAY + 0.04
    h = SAW_H
    m.prism([(SAW_LOW, 0.0), (SAW_HIGH, h), (SAW_FACE, h), (SAW_FACE, 0.0)], d, (0, 0, 0), "timber", axis="y")
    # The solar array along the slope.
    run = SAW_HIGH - SAW_LOW
    length = math.hypot(run, h)
    tilt = math.degrees(math.atan2(h, run))
    mid = lib.Vector(((SAW_LOW + SAW_HIGH) / 2, 0, h / 2))
    normal = lib.Vector((-math.sin(math.radians(tilt)), 0, math.cos(math.radians(tilt))))
    rot = lib.roty(-tilt)
    m.box((length - 0.1, d - 0.08, 0.05), mid + normal * 0.045, "solar_frame", rot=rot)
    _modules(m, mid + normal * 0.045, rot, length - 0.16, d - 0.12, 5, 8, gap=0.04, lift=0.028)
    # The clerestory: warm glass behind timber fins, a ceramic sill and a
    # ceramic ridge cap.
    m.box((0.03, d - 0.02, h - 0.55), (SAW_FACE + 0.015, 0, 0.3 + (h - 0.55) / 2), "window_glow")
    for k in range(11):
        y = -d / 2 + 0.2 + (d - 0.4) * k / 10
        m.box((0.12, 0.06, h - 0.45), (SAW_FACE + 0.08, y, 0.25 + (h - 0.45) / 2), "timber_light")
    m.box((0.2, d, 0.1), (SAW_FACE + 0.06, 0, 0.3), "ceramic", bevel=0.02)
    m.box((0.36, d, 0.14), (SAW_FACE - 0.04, 0, h + 0.02), "ceramic", bevel=0.03)
    # The valley gutter at the foot of the slope.
    m.box((0.22, d, 0.1), (SAW_LOW + 0.1, 0, 0.05), "steel_light", bevel=0.01)
    _build(m, "roof", r, merge=LEAN)


def hall_sawtooth_gable():
    """The timber triangle closing a tooth's end, battened on both faces,
    with a ceramic verge along the slope."""
    r = lib.root("hall_sawtooth_gable")
    m = Mesh()
    x0, x1 = SAW_LOW - 0.03, SAW_FACE + 0.12
    top = SAW_H + 0.06
    pts = [(x0, 0.0), (x1, 0.0), (x1, top), (SAW_HIGH, top), (x0, 0.06)]
    m.slab(pts, [], 0.3, (0, 0, 0), "timber", reveal_mat="timber")
    # Battens on both faces, stopping under the verge.
    n = 12
    for k in range(n):
        x = x0 + 0.2 + (x1 - x0 - 0.3) * k / (n - 1)
        zt = min(top, _saw_z(x) + 0.06) - 0.14
        if zt < 0.2:
            continue
        _strip(m, x, 0.07, 0.03, 0.0, zt, "timber_light", 0.15)
        m._faces([(x - 0.035, -0.15, 0.0), (x - 0.035, -0.18, 0.0), (x + 0.035, -0.18, 0.0), (x + 0.035, -0.15, 0.0),
                  (x - 0.035, -0.15, zt), (x - 0.035, -0.18, zt), (x + 0.035, -0.18, zt), (x + 0.035, -0.15, zt)],
                 [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6)], "timber_light")
    tilt = math.degrees(math.atan2(SAW_H, SAW_HIGH - SAW_LOW))
    a, b = lib.Vector((x0, 0, 0.1)), lib.Vector((SAW_HIGH, 0, top + 0.04))
    m.box(((b - a).length + 0.04, 0.36, 0.12), (a + b) / 2, "ceramic", rot=lib.roty(-tilt))
    m.box((x1 - SAW_HIGH + 0.04, 0.36, 0.12), ((SAW_HIGH + x1) / 2, 0, top + 0.04), "ceramic")
    # A brass vent through the gable.
    m.box((0.7, 0.36, 0.44), (0.9, 0, 1.15), "brass_dark", bevel=0.02)
    _build(m, "gable", r, merge=LEAN)


# ---- Library ----

LIB_BAY = 2.0
LIB_H = 8.0
LIB_T = 0.36
LIB_PLINTH = 0.3
LIB_FLOOR = (3.5, 4.1)
LIB_PARAPET = 6.7


def _band(m, x0, x1, y_back, y_front, z0, z1, r, mat, seg=3):
    """A band along x from y_back to y_front, its two front corners rounded
    to r."""
    prof = [(y_back, z0)]
    for k in range(seg + 1):
        a = -math.pi / 2 + (math.pi / 2) * k / seg
        prof.append((y_front - r + r * math.cos(a), z0 + r + r * math.sin(a)))
    for k in range(seg + 1):
        a = (math.pi / 2) * k / seg
        prof.append((y_front - r + r * math.cos(a), z1 - r + r * math.sin(a)))
    prof.append((y_back, z1))
    m.prism(prof, x1 - x0, ((x0 + x1) / 2, 0, 0), mat, axis="x")


def _lib_bands(m, x0, x1, plinth=True):
    """The drum's white ceramic: the plinth, the band between the storeys
    and the deep band round the top, each with a brass line."""
    cx, w = (x0 + x1) / 2, x1 - x0
    if plinth:
        m.box((w, LIB_T + 0.08, LIB_PLINTH), (cx, -LIB_T / 2 + 0.04, LIB_PLINTH / 2), "ceramic_shade", bevel=0.02)
    _band(m, x0, x1, -LIB_T, 0.16, LIB_FLOOR[0], LIB_FLOOR[1], 0.14, "ceramic")
    m.box((w, 0.03, 0.05), (cx, 0.17, (LIB_FLOOR[0] + LIB_FLOOR[1]) / 2), "brass")
    _band(m, x0, x1, -LIB_T, 0.3, LIB_PARAPET, LIB_H, 0.26, "ceramic", seg=4)
    m.box((w, 0.03, 0.05), (cx, 0.31, LIB_PARAPET + 0.42), "brass")


def _lib_glass(m, x0, x1, z0, z1, mullions, transom=None, depth=-0.2, shelves=()):
    """A storey of warm glazing set back behind the bands: slim dark
    mullions, a transom, and the dark lines of shelves inside."""
    w, cx = x1 - x0, (x0 + x1) / 2
    m.box((w, 0.03, z1 - z0), (cx, depth, (z0 + z1) / 2), "window_glow")
    f = depth + 0.015
    for x in mullions:
        _strip(m, x, 0.06, 0.06, z0, z1, "frame", f)
    if transom is not None:
        m.box((w, 0.05, 0.05), (cx, f + 0.025, transom), "frame")
    for z in shelves:
        m.box((w - 0.3, 0.01, 0.06), (cx, f + 0.005, z), "timber_dark")


def lib_wall_arch():
    """A 2 m bay of the drum: two storeys of full-height warm glazing between
    the white bands."""
    r = lib.root("lib_wall_arch")
    m = Mesh()
    w = LIB_BAY
    _lib_bands(m, -w / 2, w / 2)
    _lib_glass(m, -w / 2, w / 2, LIB_PLINTH, LIB_FLOOR[0], [0.0], LIB_FLOOR[0] - 0.55)
    _lib_glass(m, -w / 2, w / 2, LIB_FLOOR[1], LIB_PARAPET, [0.0], LIB_PARAPET - 0.5)
    _build(m, "wall", r, merge=LEAN)


def _fin(half, back, nose, seg=4):
    """A D-shaped section: straight sides at x = +-half from y = back, a
    round nose reaching y = nose."""
    pts = [(half, back)]
    for k in range(seg + 1):
        a = math.pi * k / seg
        pts.append((half * math.cos(a), nose - half + half * math.sin(a)))
    pts.append((-half, back))
    return pts


def lib_column():
    """The slim ceramic fin at every bay joint, on a ceramic base, with
    brass collars at the storey band."""
    r = lib.root("lib_column")
    m = Mesh()
    m.box((0.6, 0.3, LIB_PLINTH + 0.06), (0, 0.1, (LIB_PLINTH + 0.06) / 2), "ceramic_shade", bevel=0.03)
    m.box((0.26, 0.2, 0.05), (0, 0.06, LIB_PLINTH + 0.085), "brass")
    _extrude(m, _fin(0.09, -0.05, 0.13), LIB_PLINTH + 0.06, 7.8, "ceramic")
    _build(m, "column", r, merge=LEAN)


def _roundel(m, at, radius):
    """The library's sign: a jade disc in a brass ring with a white open
    book, facing +y."""
    x, y, z = at
    m.cylinder(radius + 0.07, 0.05, (x, y, z), "brass", 20, rot=lib.rotx(90))
    m.cylinder(radius, 0.05, (x, y + 0.03, z), "jade", 20, rot=lib.rotx(90))
    for side in (-1, 1):
        m.prism([(0.0, 0.0), (0.26, 0.05), (0.26, 0.34), (0.0, 0.29)], 0.02, (x, y + 0.06, z - 0.17), "warm_white",
                axis="y", rot=None if side > 0 else lib.rotz(180))
    m.box((0.02, 0.02, 0.3), (x, y + 0.07, z - 0.02), "jade_dark")


def lib_entrance():
    """A door bay as wide as its opening and the reveals either side
    (DOOR_W): warm glazing over the open doorway under a curved ceramic
    canopy with a brass fascia, a low step, and the library's roundel on a
    raised parapet. Nothing stands in the opening below the glazing; the
    doors fold into the reveals (lib_door_leaves)."""
    r = lib.root("lib_entrance")
    m = Mesh()
    w = DOOR_W
    _lib_bands(m, -w / 2, w / 2, plinth=False)
    # The raised parapet over the doors, carrying the roundel.
    tab = [(-1.3, LIB_H - 0.3)] + [(1.3 - 0.3 + 0.3 * math.cos(math.pi / 2 * k / 3), LIB_H + 0.37 + 0.3 * math.sin(
        math.pi / 2 * k / 3)) for k in range(4)] + [(-1.3 + 0.3 - 0.3 * math.cos(math.pi / 2 * (3 - k) / 3),
                                                   LIB_H + 0.37 + 0.3 * math.sin(math.pi / 2 * (3 - k) / 3))
                                                  for k in range(4)]
    tab[1:1] = [(1.3, LIB_H - 0.3)]
    m.prism(tab, 0.5, (0, 0.04, 0), "ceramic", axis="y")
    m.box((2.6, 0.03, 0.05), (0, 0.305, LIB_H + 0.05), "brass")
    _roundel(m, (0, 0.3, LIB_H + 0.1), 0.42)
    # Ground floor: warm glazing over the doorway, a dark head.
    _lib_glass(m, -w / 2, w / 2, DOOR_H, LIB_FLOOR[0], [-0.65, 0.0, 0.65])
    m.box((w, 0.08, 0.08), (0, -0.2, DOOR_H), "frame")
    # Upper storey.
    _lib_glass(m, -w / 2, w / 2, LIB_FLOOR[1], LIB_PARAPET, [-1.0, 0.0, 1.0], LIB_PARAPET - 0.5)
    # The canopy: a half-ellipse slab, its soffit lit, a brass fascia.
    rx, ry, n = 2.1, 1.75, 14
    arc = [(rx * math.cos(math.pi * k / n), ry * math.sin(math.pi * k / n)) for k in range(n + 1)]
    _extrude(m, arc, LIB_FLOOR[0] - 0.24, LIB_FLOOR[0] - 0.02, "ceramic")
    fascia_out = [(x * (rx + 0.04) / rx, y * (ry + 0.04) / ry) for x, y in arc]
    tmp = Mesh()
    for (ax, ay), (bx, by) in zip(fascia_out, fascia_out[1:]):
        tmp._faces([(ax, ay, LIB_FLOOR[0] - 0.2), (bx, by, LIB_FLOOR[0] - 0.2), (bx, by, LIB_FLOOR[0] - 0.08),
                    (ax, ay, LIB_FLOOR[0] - 0.08)], [(0, 1, 2, 3)], "brass")
    _merge_xform(m, tmp, 0, (0, 0))
    for x, y in ((-0.9, 0.7), (0.9, 0.7), (0.0, 1.2)):
        m.cylinder(0.14, 0.03, (x, y, LIB_FLOOR[0] - 0.255), "lamp_glow", 10)
    # A low step out onto the square (below the walking band).
    m.box((w + 1.0, 1.4, 0.15), (0, 0.7, 0.075), "ceramic_shade", bevel=0.02)
    _build(m, "entrance", r, merge=LEAN)


def lib_door_leaves():
    """One side of the library's glass doors, folded open into the reveal
    beside the opening: four dark-framed panels with brass pulls, square to
    the wall and stacked across the reveal, as deep as the wall."""
    r = lib.root("lib_door_leaves")
    m = Mesh()
    for k in range(4):
        x = -DOOR_REVEAL / 2 + 0.04 + k * 0.07
        m.box((0.05, LIB_T - 0.02, DOOR_H - 0.1), (x, -LIB_T / 2, (DOOR_H - 0.1) / 2 + 0.05), "frame")
        m.box((0.054, LIB_T - 0.1, DOOR_H - 0.5), (x, -LIB_T / 2, (DOOR_H - 0.5) / 2 + 0.25), "glass_light")
    m.box((0.3, 0.03, 0.03), (0, -0.01, 1.05), "brass")
    _build(m, "leaves", r, merge=LEAN)


def _leaf(m, at, length, width, turn, mat, depth=0.02):
    """A flat leaf shape (a pointed lens) in the xz plane at `at`, turned
    `turn` degrees about y."""
    pts = []
    for k in range(7):
        t = k / 6
        pts.append((-length / 2 + length * t, width / 2 * math.sin(math.pi * t)))
    for k in range(5, 0, -1):
        t = k / 6
        pts.append((-length / 2 + length * t, -width / 2 * math.sin(math.pi * t)))
    m.prism(pts, depth, at, mat, axis="y", rot=lib.roty(turn))


def lib_banner():
    """A jade banner under a brass bracket fixed to the wall at z = 0: a
    cream leaf and an open book, a coral hem stripe, a pointed hem."""
    r = lib.root("lib_banner")
    m = Mesh()
    m.box((0.3, 0.06, 0.24), (0, 0.03, 0.0), "brass_dark", bevel=0.01)
    m.box((0.06, 0.62, 0.06), (0, 0.33, 0.0), "brass")
    m.beam((0, 0.06, -0.3), (0, 0.45, 0.0), 0.04, "brass")
    m.cylinder(0.03, 1.2, (0, 0.6, -0.08), "brass", 8, rot=lib.roty(90))
    for x in (-0.62, 0.62):
        m.sphere(0.06, (x, 0.6, -0.08), "brass", subdivisions=1)
    m.box((1.0, 0.04, 3.65), (0, 0.6, -1.95), "jade", bevel=0.01)
    m.prism([(-0.5, 0.0), (0.5, 0.0), (0.5, -0.12), (0.0, -0.42), (-0.5, -0.12)], 0.04, (0, 0.6, -3.77), "jade",
            axis="y")
    m.box((1.0, 0.05, 0.1), (0, 0.6, -0.28), "warm_white")
    _leaf(m, (0, 0.63, -1.35), 0.8, 0.3, -40, "warm_white")
    m.box((0.62, 0.02, 0.03), (0.0, 0.645, -1.35), "jade_dark", rot=lib.roty(-40))
    m.box((0.2, 0.02, 0.03), (-0.37, 0.635, -1.62), "warm_white", rot=lib.roty(-40))
    for side in (-1, 1):
        m.prism([(0.0, 0.0), (0.3, 0.06), (0.3, 0.4), (0.0, 0.34)], 0.02, (0, 0.625, -2.3), "warm_white",
                axis="y", rot=None if side > 0 else lib.rotz(180))
    m.box((1.0, 0.05, 0.08), (0, 0.6, -3.3), "coral")
    m.box((1.0, 0.05, 0.04), (0, 0.6, -3.45), "brass")
    _build(m, "banner", r, merge=LEAN)


ROOF_W, ROOF_D = 20.4, 18.4
DRUM_RX, DRUM_RY = 6.4, 5.8
DRUM_H = 0.9
DOME_H = 3.7
DOME_SECTORS = 24
DOME_RINGS = 5
DOME_TOP = math.radians(74)


def _dome_point(theta, phi, grow=0.0):
    """A point on the dome's ellipsoid (radii inside the drum) at sector
    angle theta and elevation phi, pushed `grow` along the normal; and the
    normal."""
    rx, ry = DRUM_RX - 0.3, DRUM_RY - 0.3
    p = lib.Vector((rx * math.cos(phi) * math.cos(theta), ry * math.cos(phi) * math.sin(theta),
                    DOME_H * math.sin(phi)))
    n = lib.Vector((p.x / rx ** 2, p.y / ry ** 2, p.z / DOME_H ** 2)).normalized()
    return p + n * grow + lib.Vector((0, 0, DRUM_H)), n


def _rib(m, pts, normals, width, height, mat):
    """A raised strip along a polyline on a surface: its top and sides."""
    verts, faces = [], []
    for k, (p, n) in enumerate(zip(pts, normals)):
        t = (pts[min(k + 1, len(pts) - 1)] - pts[max(k - 1, 0)]).normalized()
        s = t.cross(n).normalized() * (width / 2)
        verts += [p - s, p - s + n * height, p + s + n * height, p + s]
    for k in range(len(pts) - 1):
        a, b = 4 * k, 4 * (k + 1)
        faces += [(a + 1, b + 1, b, a), (a + 2, b + 2, b + 1, a + 1), (a + 3, b + 3, b + 2, a + 2)]
    m._faces([tuple(v) for v in verts], faces, mat)


def lib_roof():
    """The library's roof, fitted to its 20 m x 18 m footprint with z = 0 at
    the wall top: a white ceramic parapet ring, a planted rim of shrubs and
    flowers round a lawn with paths, and a glass-and-solar dome on a low
    ceramic drum, deep blue solar segments and turquoise glass between
    brass ribs, a lantern at its crown."""
    r = lib.root("lib_roof")
    m = Mesh()
    seg = 3
    outer = _rrect(ROOF_W, ROOF_D, 0.5, seg)
    rim = _rrect(ROOF_W - 0.8, ROOF_D - 0.8, 0.3, seg)
    bed = _rrect(ROOF_W - 2.2, ROOF_D - 2.2, 0.3, seg)
    # The deck (a lawn), the parapet ring and the planter ring inside it.
    _extrude(m, rim, -0.2, 0.06, "grass")
    _tube(m, outer, rim, -0.05, 0.42, "ceramic", bottom=False)
    _tube(m, rim, bed, 0.06, 0.62, "ceramic_shade", bottom=False, outside=False)
    _tube(m, rim, bed, 0.62, 0.65, "soil", bottom=False, outside=False, inside=False)
    m.box((ROOF_W - 1.0, 0.03, 0.05), (0, ROOF_D / 2 + 0.005, 0.2), "brass")
    m.box((ROOF_W - 1.0, 0.03, 0.05), (0, -ROOF_D / 2 - 0.005, 0.2), "brass")
    # Paths across the lawn to the drum.
    for (x, y, sx, sy) in ((0, (ROOF_D / 2 + DRUM_RY) / 2 - 0.6, 1.2, ROOF_D / 2 - DRUM_RY - 1.0),
                           (0, -(ROOF_D / 2 + DRUM_RY) / 2 + 0.6, 1.2, ROOF_D / 2 - DRUM_RY - 1.0),
                           ((ROOF_W / 2 + DRUM_RX) / 2 - 0.6, 0, ROOF_W / 2 - DRUM_RX - 1.0, 1.2),
                           (-(ROOF_W / 2 + DRUM_RX) / 2 + 0.6, 0, ROOF_W / 2 - DRUM_RX - 1.0, 1.2)):
        m.box((sx, sy, 0.04), (x, y, 0.08), "paving_light")
    ring_o = _ellipse(DRUM_RX + 1.0, DRUM_RY + 1.0, 32)
    ring_i = _ellipse(DRUM_RX, DRUM_RY, 32)
    _tube(m, ring_o, ring_i, 0.06, 0.1, "paving_light", bottom=False, inside=False)
    # The drum and its brass cornice.
    _tube(m, _ellipse(DRUM_RX, DRUM_RY, 32), _ellipse(DRUM_RX - 0.35, DRUM_RY - 0.35, 32), 0.06, DRUM_H, "ceramic",
          bottom=False, inside=False)
    _tube(m, _ellipse(DRUM_RX + 0.05, DRUM_RY + 0.05, 32), _ellipse(DRUM_RX - 0.35, DRUM_RY - 0.35, 32), DRUM_H,
          DRUM_H + 0.08, "brass", bottom=False, inside=False)
    # The dome: panels between rings of elevation, solar and glass sectors.
    n, rings = DOME_SECTORS, DOME_RINGS
    grid = [[_dome_point(2 * math.pi * i / n, DOME_TOP * j / rings)[0] for i in range(n)] for j in range(rings + 1)]
    for j in range(rings):
        for i in range(n):
            i2 = (i + 1) % n
            mat = "glass" if j >= rings - 2 else "solar"
            m._faces([tuple(grid[j][i]), tuple(grid[j][i2]), tuple(grid[j + 1][i2]), tuple(grid[j + 1][i])],
                     [(0, 1, 2, 3)], mat)
    # Brass ribs along every other meridian and round two parallels.
    fine = 5
    for i in range(0, n, 2):
        th = 2 * math.pi * i / n
        pts = [_dome_point(th, DOME_TOP * k / fine) for k in range(fine + 1)]
        _rib(m, [p for p, _ in pts], [nn for _, nn in pts], 0.09, 0.07, "brass")
    for j in (2, 4):
        ph = DOME_TOP * j / rings
        pts = [_dome_point(2 * math.pi * i / n, ph) for i in range(n + 1)]
        _rib(m, [p for p, _ in pts], [nn for _, nn in pts], 0.08, 0.06, "brass")
    # The lantern at the crown.
    top = grid[rings]
    cap = [(p.x, p.y) for p in top]
    zc = top[0].z
    _tube(m, [(x * 1.08, y * 1.08) for x, y in cap], cap, zc - 0.02, zc + 0.14, "brass", bottom=False)
    m.cylinder(1.25, 0.34, (0, 0, zc + 0.3), "glass_light", 16, radius_top=0.9)
    m.cylinder(0.95, 0.1, (0, 0, zc + 0.5), "brass", 16, radius_top=0.2)
    # The planted rim: shrubs heaped along the planter ring, flowers, and
    # a few small trees at the corners.
    rng = random.Random(61)
    path = _rrect(ROOF_W - 1.9, ROOF_D - 1.9, 0.3, seg)
    per = [0.0]
    for a, b in zip(path, path[1:] + path[:1]):
        per.append(per[-1] + math.dist(a, b))
    total = per[-1]
    count = 40
    for k in range(count):
        s = total * (k + 0.5) / count
        i = max(q for q in range(len(path)) if per[q] <= s)
        a, b = path[i], path[(i + 1) % len(path)]
        t = (s - per[i]) / max(1e-6, per[i + 1] - per[i])
        x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        if k % 3 == 1:
            _flowers(m, (x, y, 0.64), 0.4, 70 + k, rng.choice(("flower_coral", "flower_yellow", "flower_pink",
                                                               "flower_white")))
        else:
            _clump(m, (x, y, 0.64), rng.uniform(0.62, 0.78), 90 + k, scale=(1.1, 1.1, 1.05),
                   mat=rng.choice(("leaf", "leaf_dark")), cap=rng.choice(("leaf_light", "leaf_sun")), cut=0.0)
    for k, (x, y) in enumerate(((7.2, 6.2), (-7.2, 6.2), (7.2, -6.2), (-7.2, -6.2))):
        m.cylinder(0.1, 1.2, (x, y, 0.6), "trunk", 6, radius_top=0.07, cap=False)
        _clump(m, (x, y, 1.6), 0.8, 110 + k, scale=(1.1, 1.1, 0.8), mat="leaf", cap="leaf_sun")
    _build(m, "roof", r)


# ---- Blocks: shared helpers ----

def _perimeter(pts):
    per = [0.0]
    for a, b in zip(pts, pts[1:] + pts[:1]):
        per.append(per[-1] + math.dist(a, b))
    return per


def _along(pts, count, phase=0.5):
    """`count` points evenly spaced round a closed counter-clockwise
    outline, each with its outward normal."""
    per = _perimeter(pts)
    total = per[-1]
    n = len(pts)
    out = []
    for k in range(count):
        s = total * (k + phase) / count
        i = max(q for q in range(n) if per[q] <= s)
        a, b = pts[i], pts[(i + 1) % n]
        seg = per[i + 1] - per[i]
        t = (s - per[i]) / seg if seg > 1e-9 else 0.0
        tx, ty = (b[0] - a[0]) / seg, (b[1] - a[1]) / seg
        out.append(((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), (ty, -tx)))
    return out


def _vstrip(m, p, nrm, width, proud, z0, z1, mat):
    """A vertical strip on a face at p looking along nrm: its front and
    sides."""
    (x, y), (nx, ny) = p, nrm
    tx, ty = -ny, nx
    hw = width / 2
    a, b = (x - tx * hw, y - ty * hw), (x + tx * hw, y + ty * hw)
    af, bf = (a[0] + nx * proud, a[1] + ny * proud), (b[0] + nx * proud, b[1] + ny * proud)
    m._faces([(a[0], a[1], z0), (af[0], af[1], z0), (bf[0], bf[1], z0), (b[0], b[1], z0),
              (a[0], a[1], z1), (af[0], af[1], z1), (bf[0], bf[1], z1), (b[0], b[1], z1)],
             [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6)], mat)


def _inside(p, box):
    x0, x1, y0, y1 = box
    return x0 - 0.2 < p[0] < x1 + 0.2 and y0 - 0.2 < p[1] < y1 + 0.2


def _palm(m, at, height, seed, fronds=6):
    """A small palm: a slim leaning trunk and a crown of drooping fronds."""
    x, y, z = at
    rng = random.Random(seed)
    lean = rng.uniform(-0.25, 0.25)
    top = lib.Vector((x + lean, y + rng.uniform(-0.2, 0.2), z + height))
    m.cylinder(0.09, height, (x + lean / 2, (y + top.y) / 2, z + height / 2), "trunk_light", 6, radius_top=0.06,
               cap=False, rot=lib.roty(math.degrees(math.atan2(lean, height))))
    for k in range(fronds):
        a = 2 * math.pi * k / fronds + rng.uniform(-0.2, 0.2)
        d = lib.Vector((math.cos(a), math.sin(a), 0))
        tip = top + d * 1.2 + lib.Vector((0, 0, -0.45))
        mid = top + d * 0.6 + lib.Vector((0, 0, 0.1))
        for p0, p1, mat in ((top, mid, "palm"), (mid, tip, "palm_light")):
            u = (p1 - p0)
            side = u.cross(lib.Vector((0, 0, 1))).normalized() * 0.2
            m._faces([tuple(p0 - side * 0.4), tuple(p1 - side), tuple(p1 + side), tuple(p0 + side * 0.4)],
                     [(0, 1, 2, 3), (3, 2, 1, 0)], mat)


def _tree(m, at, height, radius, seed):
    """A small terrace tree: a slim trunk under two leafy clumps."""
    x, y, z = at
    m.cylinder(0.08, height * 0.6, (x, y, z + height * 0.3), "trunk", 6, radius_top=0.05, cap=False)
    _clump(m, (x + radius * 0.25, y, z + height - radius * 0.55), radius * 0.75, seed * 7, mat="leaf_dark",
           cap="leaf_light")
    _clump(m, (x - radius * 0.15, y + radius * 0.1, z + height - radius * 0.2), radius * 0.65, seed * 7 + 3,
           mat="leaf", cap="leaf_sun")


def _planting(m, outline, z, count, seed, skip=None, trees=(), inset=0.55, big=(0.42, 0.55)):
    """Shrubs and flowers heaped along a terrace's edge, `inset` inside the
    counter-clockwise `outline`, missing those inside the `skip` box, and
    trees at the indexes `trees`."""
    rng = random.Random(seed)
    for k, ((x, y), (nx, ny)) in enumerate(_along(outline, count)):
        p = (x - nx * inset, y - ny * inset)
        if skip is not None and _inside(p, skip):
            continue
        if k in trees:
            _tree(m, (p[0] - nx * 0.4, p[1] - ny * 0.4, z), rng.uniform(2.1, 2.6), rng.uniform(0.9, 1.1),
                  seed * 11 + k)
        elif k % 3 == 2:
            _flowers(m, (p[0], p[1], z), 0.34, seed * 5 + k, rng.choice(("flower_coral", "flower_yellow",
                                                                           "flower_pink", "flower_white")))
        else:
            _clump(m, (p[0], p[1], z), rng.uniform(*big), seed * 3 + k, scale=(1.15, 1.15, 1.0),
                   mat=rng.choice(("leaf", "leaf_dark")), cap=rng.choice(("leaf_light", "leaf_sun")), cut=0.0)


# ---- Towers ----

TOWER = 11.36
FLOOR = 3.2
LOBBY = 4.0
BAND_OUT = 0.25


def _tier(m, cx, cy, w, d, r, z0, floors, lobby=False, bay=1.5):
    """A rounded glass tier over w x d about (cx, cy): turquoise glass behind
    slim mullions, a white ceramic band wrapping each floor as a curved
    balcony, a deeper band round the top as the parapet. A lobby tier's
    ground floor is warm glazing set back behind round ceramic piers.
    Returns its roof height (the terrace level)."""
    heights = ([LOBBY] if lobby else []) + [FLOOR] * floors
    top = z0 + sum(heights)
    zg = z0 + (LOBBY if lobby else 0.0)
    glass = _rrect(w - 0.4, d - 0.4, max(0.2, r - 0.2), 4, cx, cy)
    _extrude(m, glass, zg, top, "glass_tower")
    for (p, nrm) in _along(glass, max(8, round(_perimeter(glass)[-1] / bay))):
        _vstrip(m, p, nrm, 0.07, 0.07, zg, top, "steel_light")
    band = _rrect(w + 2 * BAND_OUT, d + 2 * BAND_OUT, r + BAND_OUT, 4, cx, cy)
    z = z0
    for h in heights[:-1]:
        z += h
        _extrude(m, band, z - 0.3, z + 0.45, "ceramic")
    _tube(m, band, _rrect(w - 0.8, d - 0.8, max(0.2, r - 0.4), 4, cx, cy), top - 0.3, top + 0.75, "ceramic")
    if lobby:
        _extrude(m, _rrect(w - 1.3, d - 1.3, max(0.2, r - 0.6), 4, cx, cy), z0, zg, "window_glow")
        for (x, y), _ in _along(_rrect(w - 0.5, d - 0.5, max(0.2, r - 0.2), 4, cx, cy),
                                max(8, round((w + d) * 2 / 2.6))):
            m.cylinder(0.2, LOBBY - 0.3, (x, y, z0 + (LOBBY - 0.3) / 2), "ceramic", 8, cap=False)
    return top


def _terrace(m, g, cx, cy, w, d, r, z, count, seed, skip=None, trees=(), big=(0.55, 0.72)):
    """The planted terrace on a tier's roof at z: a lawn, a raised planter
    ring inside the parapet heaped with shrubs and flowers (missing those
    inside the `skip` box), and trees at the indexes `trees`."""
    _extrude(m, _rrect(w - 0.7, d - 0.7, max(0.2, r - 0.35), 4, cx, cy), z - 0.3, z + 0.05, "grass")
    outer = _rrect(w - 0.8, d - 0.8, max(0.2, r - 0.4), 4, cx, cy)
    inner = _rrect(w - 2.2, d - 2.2, max(0.2, r - 1.1), 4, cx, cy)
    _tube(m, outer, inner, z, z + 0.5, "ceramic_shade", bottom=False, outside=False, top=False)
    _tube(m, outer, inner, z + 0.5, z + 0.52, "soil", bottom=False, outside=False, inside=False)
    _planting(g, _rrect(w - 1.5, d - 1.5, max(0.2, r - 0.75), 4, cx, cy), z + 0.5, count, seed, skip=skip,
              trees=trees, inset=0.0, big=big)


def _tower_door(m, y, z=0.0):
    """Glazed doors in the lobby's glazing at y under a curved ceramic
    canopy, brass-framed."""
    arc = [(1.8 * math.cos(math.pi * k / 10), y + 0.95 * math.sin(math.pi * k / 10)) for k in range(11)]
    _extrude(m, arc, z + 3.1, z + 3.3, "ceramic")
    m.box((2.4, 0.06, 2.8), (0, y + 0.03, z + 1.4), "glass_light")
    for x in (-1.2, -0.4, 0.4, 1.2):
        m.box((0.07, 0.1, 2.8), (x, y + 0.07, z + 1.4), "brass_dark")
    m.box((2.5, 0.1, 0.08), (0, y + 0.07, z + 2.8), "brass_dark")


def tower_a():
    """Four floors over a lobby, then two, then one, each stepping back to a
    planted terrace; a roof garden under a solar crown on top."""
    r = lib.root("tower_a")
    m, g = Mesh(), Mesh()
    h, s2, s3 = TOWER / 2, 4.1, 2.8
    t1 = _tier(m, 0, 0, TOWER, TOWER, 2.4, 0.0, 3, lobby=True)
    t2 = _tier(m, 0, 0, 2 * s2, 2 * s2, 1.8, t1, 2)
    t3 = _tier(m, 0, 0, 2 * s3, 2 * s3, 1.3, t2, 1)
    _terrace(m, g, 0, 0, TOWER, TOWER, 2.4, t1, 28, 3, trees=(3, 10, 17, 24))
    _terrace(m, g, 0, 0, 2 * s2, 2 * s2, 1.8, t2, 20, 7, trees=(6, 16))
    _terrace(m, g, 0, 0, 2 * s3, 2 * s3, 1.3, t3, 10, 17)
    _solar_array(m, 0.0, -0.2, t3 + 2.0, 4.2, 3.0, 14, 5, 3, legs=t3)
    _palm(g, (-1.9, 1.9, t3 + 0.5), 2.4, 23)
    _tower_door(m, h - 0.65)
    _build(m, "tower", r)
    _build(g, "garden", r, 60.0)


def tower_b():
    """Two floors over a lobby, then a tier set back from the front (+y),
    then a crown set back from the east too: planted terraces cascading
    down to the street, a solar crown on top."""
    r = lib.root("tower_b")
    m, g = Mesh(), Mesh()
    h = TOWER / 2
    yb, xb = h - 3.8, h - 4.2
    t1 = _tier(m, 0, 0, TOWER, TOWER, 2.4, 0.0, 2, lobby=True)
    w2, d2, c2 = TOWER, yb + h, (0.0, (yb - h) / 2)
    t2 = _tier(m, c2[0], c2[1], w2, d2, 1.8, t1, 2)
    w3, d3, c3 = xb + h, yb - 2.0 + h, ((xb - h) / 2, (yb - 2.0 - h) / 2)
    t3 = _tier(m, c3[0], c3[1], w3, d3, 1.4, t2, 1)
    _terrace(m, g, 0, 0, TOWER, TOWER, 2.4, t1, 30, 5, skip=(-h, h, -h, yb - 0.5), trees=(2, 10))
    _terrace(m, g, c2[0], c2[1], w2, d2, 1.8, t2, 24, 9, skip=(-h, xb - 0.5, -h, yb - 2.5), trees=(1, 7))
    _terrace(m, g, c3[0], c3[1], w3, d3, 1.4, t3, 10, 13)
    _solar_array(m, c3[0], c3[1], t3 + 1.9, w3 - 2.4, d3 - 2.2, 14, 4, 2, legs=t3)
    _palm(g, (c3[0] + w3 / 2 - 1.1, c3[1] + d3 / 2 - 1.0, t3 + 0.5), 2.2, 31)
    _tower_door(m, h - 0.65)
    _build(m, "tower", r)
    _build(g, "garden", r, 60.0)


# ---- Houses and the shop ----

HOUSE_W, HOUSE_D = 5.8, 7.6
HOUSE_T = 0.22
H_PLINTH = 0.3
STOREYS = (0.3, 2.65, 5.0)
H_TOP = 7.25
CORNER = 0.55


def _arc_wall(m, cx, cy, r_out, r_in, a0, z0, z1, mat, seg=4):
    """A quarter of rounded wall about (cx, cy) from angle a0 (degrees):
    its outer and inner faces and its top."""
    ang = [math.radians(a0 + 90 * k / seg) for k in range(seg + 1)]
    o = [(cx + r_out * math.cos(a), cy + r_out * math.sin(a)) for a in ang]
    i = [(cx + r_in * math.cos(a), cy + r_in * math.sin(a)) for a in ang]
    verts = [(x, y, z0) for x, y in o] + [(x, y, z1) for x, y in o] + [(x, y, z0) for x, y in i] + \
            [(x, y, z1) for x, y in i]
    n = seg + 1
    faces = []
    for k in range(seg):
        faces.append((k, k + 1, n + k + 1, n + k))
        faces.append((2 * n + k + 1, 2 * n + k, 3 * n + k, 3 * n + k + 1))
        faces.append((n + k, n + k + 1, 3 * n + k + 1, 3 * n + k))
    m._faces(verts, faces, mat)


def _shell(m, w, d, top, render, faces, base=H_PLINTH, corner=CORNER):
    """A rounded-cornered house body: four walls (each built by
    `faces[name](t, length)` in its face's frame, returning its holes), the
    rounded corners and a ceramic plinth."""
    for face, length, turn, off in _faces(w, d):
        t = Mesh()
        span = length - 2 * corner
        holes = faces.get(face, lambda t, L: [])(t, span)
        t.slab([(-span / 2, base), (span / 2, base), (span / 2, top), (-span / 2, top)], holes, HOUSE_T,
               (0, -HOUSE_T / 2, 0), render, reveal_mat="ceramic")
        _merge_xform(m, t, turn, off)
    for sx, sy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        _arc_wall(m, sx * (w / 2 - corner), sy * (d / 2 - corner), corner, corner - HOUSE_T, a0, base, top, render,
                  seg=4 if corner > 0.4 else 2)
    _extrude(m, _rrect(w + 0.08, d + 0.08, corner + 0.04, 4 if corner > 0.4 else 2), 0.0, base, "ceramic_shade")


def _frame(t, x0, x1, z0, z1, y, mat, bar=0.06, depth=0.06):
    """A window frame on a face at y: its front ring, `bar` wide, and its
    inner reveal, `depth` deep (the rest hides in the wall's reveal)."""
    f = y + depth
    o = [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]
    i = [(x0 + bar, z0 + bar), (x1 - bar, z0 + bar), (x1 - bar, z1 - bar), (x0 + bar, z1 - bar)]
    verts = [(u, f, v) for u, v in o] + [(u, f, v) for u, v in i] + [(u, y, v) for u, v in i]
    faces = []
    for k in range(4):
        j = (k + 1) % 4
        faces.append((k, 4 + k, 4 + j, j))
        faces.append((4 + k, 8 + k, 8 + j, 4 + j))
    t._faces(verts, faces, mat)


def _hwin(t, x, z0, z1, width, frame="timber_light", mullions=1):
    """A window in a face's frame (its hole cut already): turquoise glass
    set back in a ceramic reveal, a slim timber frame, a ceramic sill."""
    y = -HOUSE_T + 0.07
    zc, h = (z0 + z1) / 2, z1 - z0
    _quad(t, (x, y, zc), width, h, lib.rotx(-90), "glass")
    x0, x1 = x - width / 2, x + width / 2
    _frame(t, x0, x1, z0, z1, y, frame)
    for k in range(1, mullions + 1):
        _strip(t, x0 + width * k / (mullions + 1), 0.05, 0.05, z0, z1, frame, y)
    t.box((width + 0.16, 0.16, 0.07), (x, 0.05, z0 - 0.035), "ceramic")


def _door(t, x, colour, hood="ceramic"):
    """A timber-framed door with a lit fanlight, a curved hood and a step."""
    z = H_PLINTH
    y = -HOUSE_T + 0.08
    t.box((1.0, 0.05, 2.2), (x, y, z + 1.1), colour)
    t.box((0.7, 0.03, 0.9), (x, y + 0.035, z + 1.5), "glass")
    t.box((0.8, 0.03, 0.26), (x, y + 0.03, z + 2.33), "window_glow")
    t.box((0.05, 0.06, 0.3), (x + 0.36, y + 0.06, z + 1.0), "brass")
    for sx in (-1, 1):
        t.box((0.08, 0.1, 2.5), (x + sx * 0.54, y + 0.02, z + 1.25), "timber_light")
    t.box((1.16, 0.1, 0.08), (x, y + 0.02, z + 2.5), "timber_light")
    arc = [(x + 0.85 * math.cos(math.pi * k / 8), 0.62 * math.sin(math.pi * k / 8)) for k in range(9)]
    _extrude(t, arc, z + 2.62, z + 2.76, hood)
    t.box((1.5, 0.55, 0.14), (x, 0.27, z - 0.07), "ceramic_shade", bevel=0.02)


def _awning(t, x, z, width, colour, reach=0.75, drop=0.4, stripes=5):
    """A canvas awning over a window: stripes of canvas and `colour`
    sloping out from the wall at z, a straight valance, brass arms."""
    slope = math.degrees(math.atan2(drop, reach))
    for k in range(stripes):
        xx = x - width / 2 + width * (k + 0.5) / stripes
        mat = colour if k % 2 == 0 else "canvas"
        t.box((width / stripes, math.hypot(reach, drop), 0.04), (xx, reach / 2, z - drop / 2), mat,
              rot=lib.rotx(-slope))
    t.box((width, 0.03, 0.2), (x, reach, z - drop - 0.08), colour)
    for xx in (x - width / 2 + 0.05, x + width / 2 - 0.05):
        t.beam((xx, 0.0, z - drop - 0.3), (xx, reach, z - drop), 0.03, "brass")


def _cbalcony(t, g, x, z, width, depth, seed, flowers=True):
    """A curved balcony: a ceramic slab with round ends, a glass balustrade
    with a brass rail, and planters of flowers."""
    _extrude(t, _rrect(width, 2 * depth, min(depth, 0.45), 3, x, 0.0), z - 0.18, z, "ceramic")
    rail = _rrect(width - 0.08, 2 * depth - 0.08, min(depth, 0.45) - 0.04, 3, x, 0.0)
    inner = _rrect(width - 0.14, 2 * depth - 0.14, min(depth, 0.45) - 0.07, 3, x, 0.0)
    front = [i for i, (_, y) in enumerate(rail) if y > -0.01]
    tmp = Mesh()
    _tube(tmp, rail, inner, z, z + 0.95, "glass_light", bottom=False, top=False)
    _tube(tmp, rail, inner, z + 0.95, z + 1.0, "brass", bottom=False, inside=False)
    # Keep the balustrade's front half (the back is inside the wall).
    for f in list(tmp.bm.faces):
        if all(v.co.y < 0.02 for v in f.verts):
            tmp.bm.faces.remove(f)
    _merge_xform(t, tmp, 0, (0, 0))
    if flowers:
        rng = random.Random(seed)
        for sx in (-1, 1):
            px = x + sx * (width / 2 - 0.35)
            t.box((0.5, 0.3, 0.3), (px, depth - 0.25, z + 0.15), "timber", bevel=0.02)
            _flowers(g, (px, depth - 0.25, z + 0.3), 0.26, seed + sx, rng.choice(
                ("flower_coral", "flower_pink", "flower_yellow")))


def _parapet(m, w, d, z):
    """The flat roof: a ceramic parapet ring round a deck."""
    _tube(m, _rrect(w + 0.36, d + 0.36, CORNER + 0.18, 4), _rrect(w - 0.4, d - 0.4, CORNER - 0.2, 4), z - 0.2,
          z + 0.4, "ceramic")
    _extrude(m, _rrect(w - 0.3, d - 0.3, CORNER - 0.15, 4), z - 0.25, z, "ceramic_shade")


def _roof_garden(m, g, w, d, z, seed, count=14):
    """Planters of shrubs and flowers inside a flat roof's parapet."""
    outer = _rrect(w - 0.4, d - 0.4, CORNER - 0.2, 4)
    inner = _rrect(w - 1.3, d - 1.3, 0.2, 4)
    _tube(m, outer, inner, z, z + 0.35, "ceramic_shade", bottom=False, outside=False, top=False)
    _tube(m, outer, inner, z + 0.35, z + 0.37, "soil", bottom=False, outside=False, inside=False)
    _planting(g, _rrect(w - 0.85, d - 0.85, 0.3, 4), z + 0.35, count, seed, inset=0.0, big=(0.32, 0.42))


def _pergola(m, g, x0, x1, y0, y1, z, height, seed, vines=True):
    """A timber pergola from z: four posts, beams and rafters, and a vine
    climbing a post and spreading over the top."""
    zt = z + height
    for x in (x0 + 0.08, x1 - 0.08):
        for y in (y0 + 0.08, y1 - 0.08):
            m.box((0.14, 0.14, height), (x, y, z + height / 2), "timber")
    for y in (y0 + 0.08, y1 - 0.08):
        m.box((x1 - x0 + 0.3, 0.1, 0.2), ((x0 + x1) / 2, y, zt + 0.1), "timber")
    n = max(3, round((y1 - y0) / 0.45))
    for k in range(n):
        y = y0 + (y1 - y0) * (k + 0.5) / n
        m.box((0.07, x1 - x0 + 0.4, 0.14), ((x0 + x1) / 2, y, zt + 0.27), "timber_light", rot=lib.rotz(90))
    if vines:
        rng = random.Random(seed)
        for k in range(3):
            _clump(g, (x0 + 0.1 + rng.uniform(-0.05, 0.05), y1 - 0.1, z + 0.5 + k * height * 0.3), 0.26,
                   seed * 5 + k, scale=(0.9, 0.9, 1.3), mat=("vine", "leaf_dark")[k % 2], cap="leaf_light")
        for k in range(3):
            _clump(g, (x0 + (x1 - x0) * (k + 0.5) / 3, y1 - 0.15 - rng.uniform(0, 0.3), zt + 0.3), 0.38,
                   seed * 5 + 7 + k, scale=(1.3, 1.1, 0.6), mat=("vine", "leaf")[k % 2],
                   cap=("leaf_light", "flower_pink", "leaf_sun")[k])


def _base_plants(g, x0, x1, y, seed, n=3):
    """Shrubs in a row of pots along the foot of a wall."""
    rng = random.Random(seed)
    for k in range(n):
        x = x0 + (x1 - x0) * (k + 0.5) / n
        g.cylinder(0.2, 0.42, (x, y, 0.21), "ceramic", 8, radius_top=0.24)
        _clump(g, (x, y, 0.42), rng.uniform(0.3, 0.38), seed * 3 + k, scale=(1.0, 1.0, 1.2),
               mat=rng.choice(("leaf", "leaf_dark")), cap=rng.choice(("leaf_light", "flower_coral", "leaf_sun")),
               cut=0.0)


def _side_windows(xs, z0s=STOREYS, width=1.1):
    def build(t, span):
        holes = []
        for z0 in z0s:
            for x in xs:
                if abs(x) + width / 2 < span / 2:
                    holes.append(rect_hole(x - width / 2, x + width / 2, z0 + 0.8, z0 + 2.0))
                    _hwin(t, x, z0 + 0.8, z0 + 2.0, width)
        return holes
    return build


def house_a():
    """White, with a curved balcony, a coral awning and a jade door; a roof
    garden under a tilted solar array."""
    r = lib.root("house_a")
    m, g = Mesh(), Mesh()
    w, d = HOUSE_W, HOUSE_D

    def front(t, span):
        holes = [rect_hole(-1.95, -0.95, H_PLINTH, H_PLINTH + 2.5), rect_hole(0.3, 1.9, 1.1, 2.3)]
        _door(t, -1.45, "jade")
        _hwin(t, 1.1, 1.1, 2.3, 1.6)
        # Storey two: a French window onto the curved balcony.
        holes.append(rect_hole(0.05, 1.45, STOREYS[1] + 0.02, STOREYS[1] + 2.1))
        _hwin(t, 0.75, STOREYS[1] + 0.02, STOREYS[1] + 2.1, 1.4, mullions=1)
        _cbalcony(t, g, 0.75, STOREYS[1], 2.4, 0.75, 5)
        # Storey three: a wide window under a coral awning.
        holes.append(rect_hole(-1.3, 1.3, STOREYS[2] + 0.75, STOREYS[2] + 1.95))
        _hwin(t, 0.0, STOREYS[2] + 0.75, STOREYS[2] + 1.95, 2.6, mullions=2)
        _awning(t, 0.0, STOREYS[2] + 2.35, 2.9, "coral")
        return holes

    _shell(m, w, d, H_TOP, "warm_white", {"front": front, "back": _side_windows((-1.0, 1.0)),
                                          "east": _side_windows((0.0,))})
    _parapet(m, w, d, H_TOP)
    _roof_garden(m, g, w, d, H_TOP, 3)
    _solar_array(m, 0.0, -0.3, H_TOP + 0.95, 4.2, 4.4, 12, 4, 4, legs=H_TOP)
    _base_plants(g, 0.1, 2.3, d / 2 + 0.35, 7, n=3)
    _build(m, "house", r)
    _build(g, "plants", r, 60.0)


def house_b():
    """Cream, under a mono-pitch roof clad in solar panels falling to the
    front; jade shutters, a timber pergola porch with a vine, a balcony."""
    r = lib.root("house_b")
    m, g = Mesh(), Mesh()
    w, d = HOUSE_W, HOUSE_D
    top = 7.0

    def front(t, span):
        holes = [rect_hole(-0.5, 0.5, H_PLINTH, H_PLINTH + 2.5)]
        _door(t, 0.0, "timber_dark", hood="timber")
        for x in (-1.55, 1.55):
            holes.append(rect_hole(x - 0.5, x + 0.5, 1.0, 2.3))
            _hwin(t, x, 1.0, 2.3, 1.0, mullions=0)
        for x in (-1.5, 0.0, 1.5):
            holes.append(rect_hole(x - 0.45, x + 0.45, STOREYS[1] + 0.8, STOREYS[1] + 2.0))
            _hwin(t, x, STOREYS[1] + 0.8, STOREYS[1] + 2.0, 0.9, mullions=0)
            for sx in (-1, 1):
                t.box((0.4, 0.05, 1.3), (x + sx * 0.68, 0.025, STOREYS[1] + 1.4), "jade")
                t.box((0.3, 0.02, 0.03), (x + sx * 0.68, 0.055, STOREYS[1] + 1.4), "jade_dark")
        holes.append(rect_hole(-1.1, 1.1, STOREYS[2] + 0.02, STOREYS[2] + 1.8))
        _hwin(t, 0.0, STOREYS[2] + 0.02, STOREYS[2] + 1.8, 2.2, mullions=2)
        _cbalcony(t, g, 0.0, STOREYS[2], 3.4, 0.8, 11)
        return holes

    # The walls rise with the roof toward the back.
    _shell(m, w, d, top, "cream", {"front": front, "back": _side_windows((-1.2, 1.2)),
                                    "west": _side_windows((0.0,))})
    rise = 1.1
    for sx in (-1, 1):
        x = sx * (w / 2 - HOUSE_T / 2)
        m.prism([(d / 2 - CORNER, top), (-d / 2 + CORNER, top), (-d / 2 + CORNER, top + rise * (d - 2 * CORNER) / d)],
                HOUSE_T, (x, 0, 0), "cream", axis="x")
    m.box((w - 2 * CORNER, HOUSE_T, rise), (0, -d / 2 + HOUSE_T / 2, top + rise / 2), "cream")
    # The roof slab: ceramic fascia, timber soffit, solar modules on top.
    over = 0.35
    run = d + 2 * over
    tilt = math.degrees(math.atan2(rise, d))
    zc = top + rise / 2 + 0.12
    rot = lib.rotx(-tilt)
    m.box((w + 2 * over, run, 0.2), (0, 0, zc), "ceramic", rot=rot, bevel=0.03)
    m.box((w + 2 * over - 0.1, run - 0.1, 0.03), (0, 0, zc - 0.11), "timber_light", rot=rot)
    _modules(m, (0, 0, zc), rot, w + 2 * over - 0.3, run - 0.3, 6, 8, lift=0.115)
    # The porch: a timber pergola over the door with a vine.
    _pergola(m, g, -1.0, 1.0, d / 2, d / 2 + 0.9, H_PLINTH, 2.55, 13)
    _base_plants(g, -2.4, -1.3, d / 2 + 0.35, 17, n=2)
    _base_plants(g, 1.3, 2.4, d / 2 + 0.35, 19, n=2)
    _build(m, "house", r)
    _build(g, "plants", r, 60.0)


def house_c():
    """White ceramic with cream bands, balconies on both upper storeys, a
    coral door and awning; a gabled roof, its ridge running back from the
    street, both slopes clad in solar panels, and a round lit window in the
    front gable."""
    r = lib.root("house_c")
    m, g = Mesh(), Mesh()
    w, d = HOUSE_W, HOUSE_D
    top, rise, over, corner = 7.05, 1.25, 0.35, 0.3

    def front(t, span):
        holes = [rect_hole(1.25, 2.25, H_PLINTH, H_PLINTH + 2.5), rect_hole(-2.1, 0.2, 1.1, 2.3)]
        _door(t, 1.75, "coral")
        _hwin(t, -0.95, 1.1, 2.3, 2.3, mullions=2)
        t.box((2.3, 0.3, 0.26), (-0.95, 0.15, 0.93), "coral", bevel=0.02)
        for k in range(4):
            _flowers(g, (-1.8 + k * 0.57, d / 2 + 0.15, 1.06), 0.2, 43 + k,
                     ("flower_yellow", "flower_white", "flower_pink", "flower_yellow")[k])
        for k, (z0, french, small) in enumerate(((STOREYS[1], -0.6, (1.4,)), (STOREYS[2], 0.0, (-1.75, 1.75)))):
            holes.append(rect_hole(french - 0.65, french + 0.65, z0 + 0.02, z0 + 2.05))
            _hwin(t, french, z0 + 0.02, z0 + 2.05, 1.3, mullions=1)
            for x in small:
                holes.append(rect_hole(x - 0.4, x + 0.4, z0 + 0.8, z0 + 2.0))
                _hwin(t, x, z0 + 0.8, z0 + 2.0, 0.8, mullions=0)
            _cbalcony(t, g, french, z0, 2.2 if k == 0 else 4.2, 0.7, 23 + k)
        return holes

    _shell(m, w, d, top, "ceramic", {"front": front, "back": _side_windows((-1.0, 1.0)),
                                     "east": _side_windows((0.0,))}, corner=corner)
    band = (_rrect(w + 0.1, d + 0.1, corner + 0.05, 2), _rrect(w - 0.1, d - 0.1, corner - 0.05, 2))
    _tube(m, band[0], band[1], STOREYS[1] - 0.12, STOREYS[1] + 0.02, "cream", inside=False)
    _tube(m, band[0], band[1], top - 0.2, top, "cream", inside=False)
    # The gable ends, front and back, and the round window in the front.
    for y, turn in ((d / 2, 0), (-d / 2, 180)):
        t = Mesh()
        t.slab([(-w / 2, top), (w / 2, top), (0, top + rise)], [], HOUSE_T, (0, -HOUSE_T / 2, 0), "ceramic")
        if turn == 0:
            t.cylinder(0.42, 0.05, (0, 0.02, top + rise * 0.4), "brass", 16, rot=lib.rotx(90))
            t.cylinder(0.34, 0.05, (0, 0.04, top + rise * 0.4), "window_glow", 16, rot=lib.rotx(90))
            t.box((0.68, 0.02, 0.04), (0, 0.07, top + rise * 0.4), "brass")
        _merge_xform(m, t, turn, (0, y))
    # The roof: a ceramic-edged slab each side, solar modules on both.
    hs = w / 2 + over
    slope = math.atan2(rise + 0.1, hs)
    run = math.hypot(hs, rise + 0.1)
    for side in (-1, 1):
        rot = lib.roty(side * math.degrees(slope))
        centre = lib.Vector((side * hs / 2, 0, top + (rise - 0.1) / 2 + 0.1))
        m.box((run + 0.05, d + 2 * over, 0.18), centre, "ceramic", rot=rot)
        _modules(m, centre, rot, run - 0.35, d + 2 * over - 0.3, 3, 7, lift=0.1)
    m.box((0.26, d + 2 * over + 0.04, 0.12), (0, 0, top + rise + 0.2), "ceramic")
    _base_plants(g, -2.3, 0.4, d / 2 + 0.55, 37, n=3)
    _build(m, "house", r)
    _build(g, "plants", r, 60.0)


SHOP_W, SHOP_D = 4.6, 7.4
SHOP_FLOORS = (3.3, 5.55)
SHOP_TOP = 7.7


def shop_a():
    """A shop: a timber shopfront under a jade striped awning and a timber
    fascia with its brass sign, two white floors above with window boxes, a
    flat roof with a solar array and planters."""
    r = lib.root("shop_a")
    m, g = Mesh(), Mesh()
    w, d = SHOP_W, SHOP_D

    def front(t, span):
        holes = [rect_hole(-1.75, 1.75, 0.15, 2.85)]
        y = -HOUSE_T + 0.06
        t.box((3.5, 0.03, 2.2), (-0.35, y, 1.55), "window_glow")
        t.box((0.9, 0.03, 2.55), (1.3, y, 1.4), "glass_light")
        for x, zc, h in ((-1.72, 1.5, 2.7), (0.8, 1.5, 2.7), (1.72, 1.5, 2.7), (-0.5, 1.6, 2.4)):
            t.box((0.1 if abs(x) > 0.7 else 0.06, 0.08, h), (x, y + 0.04, zc), "timber_dark")
        t.box((3.5, 0.1, 0.45), (0, y + 0.05, 0.37), "timber_dark")
        t.box((3.5, 0.08, 0.08), (0, y + 0.04, 2.75), "timber_dark")
        t.box((0.05, 0.06, 0.5), (1.0, y + 0.08, 1.3), "brass")
        # The fascia with its sign, and the awning.
        t.box((4.2, 0.16, 0.5), (0, 0.08, 3.12), "timber", bevel=0.02)
        t.cylinder(0.2, 0.05, (-1.35, 0.18, 3.12), "brass", 16, rot=lib.rotx(90))
        t.cylinder(0.14, 0.05, (-1.35, 0.2, 3.12), "jade", 16, rot=lib.rotx(90))
        t.box((1.8, 0.04, 0.12), (0.35, 0.18, 3.12), "brass")
        _awning(t, 0.0, 2.87, 4.1, "canvas_stripe", reach=1.3, drop=0.5, stripes=9)
        for z0 in SHOP_FLOORS:
            for x in (-0.95, 0.95):
                holes.append(rect_hole(x - 0.5, x + 0.5, z0 + 0.8, z0 + 2.0))
                _hwin(t, x, z0 + 0.8, z0 + 2.0, 1.0, mullions=0)
                t.box((1.1, 0.3, 0.26), (x, 0.15, z0 + 0.65), "timber", bevel=0.02)
                _clump(g, (x, d / 2 + 0.15, z0 + 0.78), 0.3, int(z0 * 10) + int(x * 10) + 60, scale=(1.6, 0.6, 0.7),
                       mat="leaf", cap=random.Random(int(z0 * 10 + x * 10)).choice(
                           ("flower_coral", "flower_pink", "flower_yellow")), cut=0.0)
        return holes

    def back(t, span):
        holes = [rect_hole(-0.5, 0.5, 0.15, 2.35)]
        t.box((1.0, 0.05, 2.2), (0, -HOUSE_T + 0.08, 1.25), "timber_dark")
        for z0 in SHOP_FLOORS:
            holes.append(rect_hole(-0.5, 0.5, z0 + 0.8, z0 + 2.0))
            _hwin(t, 0.0, z0 + 0.8, z0 + 2.0, 1.0, mullions=0)
        return holes

    _shell(m, w, d, SHOP_TOP, "warm_white", {"front": front, "back": back,
                                              "east": _side_windows((-1.5, 1.5), SHOP_FLOORS, 1.0),
                                              "west": _side_windows((0.0,), SHOP_FLOORS, 1.0)}, base=0.15)
    _tube(m, _rrect(w + 0.1, d + 0.1, CORNER + 0.05, 4), _rrect(w - 0.1, d - 0.1, CORNER - 0.05, 4), 3.35, 3.5,
          "ceramic", inside=False)
    _parapet(m, w, d, SHOP_TOP)
    _roof_garden(m, g, w, d, SHOP_TOP, 41, count=12)
    _solar_array(m, 0.0, -0.4, SHOP_TOP + 0.9, 3.2, 4.4, 12, 3, 4, legs=SHOP_TOP)
    for x in (-2.1, 2.1):
        g.cylinder(0.24, 0.5, (x, d / 2 + 0.45, 0.25), "ceramic", 8, radius_top=0.3)
        _clump(g, (x, d / 2 + 0.45, 0.5), 0.38, 70 + int(x), scale=(1.0, 1.0, 1.2), mat="leaf_dark",
               cap="leaf_light", cut=0.0)
    _build(m, "shop", r)
    _build(g, "plants", r, 60.0)


def tram_shelter():
    """A tram stop open to +Y: glulam timber posts and beams, a glass back
    and end screen in timber frames, a timber bench on brass legs, a jade
    timetable with a lit screen and the stop's jade roundel, under a solar
    roof with a planted strip along its back."""
    r = lib.root("tram_shelter")
    m = Mesh()
    w, h = 4.4, 2.6
    # Where people walk the stop is laid out to the tram-shelter kind's
    # footprint: its back 0.75 m behind the point (the posts' back faces),
    # the bench to 0.15 m, the end screen's post to 0.40 m; the front is
    # open to the stand.
    yb, yf = -0.69, 1.0
    m.box((w + 0.1, 1.9, 0.08), (0, 0.12, 0.04), "paving_light", bevel=0.01)
    for x in (-w / 2 + 0.12, w / 2 - 0.12):
        m.box((0.14, 0.14, h - 0.08), (x, yb, 0.08 + (h - 0.08) / 2), "timber", bevel=0.015)
        m.beam((x, yb - 0.3, h + 0.02), (x, yf, h + 0.14), 0.12, "timber", depth=0.18)
        m.box((0.2, 0.2, 0.04), (x, yb, 0.1), "brass")
    # The roof: a ceramic-edged slab, solar modules on top, a planted strip.
    roof = [(yb - 0.35, h + 0.1), (yf + 0.05, h + 0.21), (yf + 0.05, h + 0.3), (yb - 0.35, h + 0.19)]
    m.prism(roof, w + 0.3, (0, 0, 0), "timber_light", axis="x")
    m.box((w + 0.35, 0.1, 0.16), (0, yf + 0.06, h + 0.25), "ceramic", bevel=0.02)
    tilt = math.degrees(math.atan2(0.11, yf - yb + 0.4))
    _solar_array(m, 0.0, 0.35, h + 0.33, w + 0.1, 1.0, -tilt, 8, 2)
    m.box((w + 0.2, 0.42, 0.16), (0, yb - 0.12, h + 0.26), "ceramic_shade")
    m.box((w + 0.1, 0.34, 0.03), (0, yb - 0.12, h + 0.345), "grass")
    rng = random.Random(51)
    for k in range(5):
        x = -w / 2 + 0.45 + (w - 0.9) * k / 4
        _clump(m, (x, yb - 0.12, h + 0.35), 0.26, 53 + k, scale=(1.3, 0.8, 0.8), mat=rng.choice(("leaf", "leaf_dark")),
               cap=rng.choice(("leaf_light", "leaf_sun", "flower_yellow")), cut=0.0)
    m.box((w - 0.3, 0.06, 0.05), (0, yf - 0.02, h + 0.12), "lamp_glow")
    # The glass back and one end screen, in timber frames.
    m.box((w - 0.3, 0.03, 1.95), (0, yb, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((w - 0.2, 0.08, 0.07), (0, yb, z), "timber")
    m.box((0.03, 1.0, 1.95), (-w / 2 + 0.12, yb + 0.55, 1.28), "glass_light")
    for z in (0.3, 2.26):
        m.box((0.08, 1.05, 0.07), (-w / 2 + 0.12, yb + 0.55, z), "timber")
    m.box((0.08, 0.08, 2.0), (-w / 2 + 0.12, yb + 1.06, 1.28), "timber")
    # A timber bench on brass legs along the back.
    m.box((2.36, 0.42, 0.07), (-0.55, yb + 0.33, 0.47), "timber_light", bevel=0.015)
    m.box((2.36, 0.06, 0.3), (-0.55, yb + 0.1, 0.78), "timber_light", bevel=0.015)
    for x in (-1.6, 0.5):
        m.box((0.06, 0.36, 0.44), (x, yb + 0.33, 0.3), "brass")
    # The timetable: a lit screen in a jade frame at the open end.
    m.box((0.7, 0.1, 1.35), (1.55, yb + 0.1, 1.28), "jade", bevel=0.02)
    m.box((0.56, 0.03, 1.1), (1.55, yb + 0.16, 1.3), "lamp_glow")
    for k in range(5):
        m.box((0.44, 0.02, 0.05), (1.55, yb + 0.18, 1.7 - k * 0.18), "tram_dark")
    m.box((0.5, 0.02, 0.12), (1.55, yb + 0.18, 1.82), "tram_coral")
    # The stop's roundel on the roof's front edge.
    m.cylinder(0.2, 0.04, (w / 2 - 0.45, yf + 0.13, h + 0.26), "brass", 16, rot=lib.rotx(90))
    m.cylinder(0.16, 0.04, (w / 2 - 0.45, yf + 0.15, h + 0.26), "jade", 16, rot=lib.rotx(90))
    m.box((0.2, 0.02, 0.05), (w / 2 - 0.45, yf + 0.175, h + 0.33), "warm_white")
    m.box((0.05, 0.02, 0.2), (w / 2 - 0.45, yf + 0.175, h + 0.245), "warm_white")
    _build(m, "shelter", r)


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
