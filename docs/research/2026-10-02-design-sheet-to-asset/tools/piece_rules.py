"""piece_rules.py: what the game and its tests hold a fountain and a tram shelter to, checked on the file alone.

check.py calls this for the two pieces. Standard library only; the geometry is read with the pilot's band.py
(the game's own measure of a piece's walking-band slice, in Python). Everything is in the piece's own frame as
the GLB has it: y up, -z the front, metres.

The rules, and where each comes from (notes/contracts/fountain.md and tram-shelter.md give the code references):

  Both pieces
  - the collision audit (city/godot/tools/collision_audit/, budget zero in every style), as far as one placement
    on level ground can show it: the piece's slice between 0.25 and 1.9 m is flattened mesh by mesh, what its
    outline encloses counts as solid (holes are not traced), and then
      * no walkable cell's centre may lie within 10 cm of the solid, except inside the 0.5 m squares round the
        placement's own sit anchors (`within_10cm`, `through`);
      * no blocked cell reached from walkable floor through such cells may be without something solid within
        10 cm (`reverse_blocked`). The kit's perch seats, which the game stands at the sit anchors as part of the
        placement, count as solid here.
    The cells are the walk grid's 25 cm cells; every placement of the two kinds in the district fixture has its
    point on a cell corner (checked by hand against city/fixtures/district/manifest.json and the grid's origin),
    so the centres lie 12.5 cm either side of the point. A cell is blocked when its centre lies within 10 cm of
    the kind's footprint (city/crates/city-core/src/footprint.rs). The audit itself traces outlines on a 2.5 cm
    raster, as this does; its probe may still differ by a centimetre, so a margin under 1.5 cm is reported as
    close, not as a pass.
  - material names: unique in the file; none that the game treats as ground in rain (paving, asphalt, kerb,
    road, path, street); `neon...`, `glass...`, `lamp_glow`, `window_glow`, `fairy_glow`, `light` are reported,
    since the game lights them by name (kit_town.gd _collect);
  - no part named `light`, `lights` or `display` (the game would hang a lamp or look for a panel there).

  The tram shelter (the game stretches it to its footprint: pack_3d.gd _fill_footprint, kit_town.gd band_box)
  - its slice between 0.15 and 2.2 m must be the footprint's box, -2.15,-0.40 to 2.15,0.75: within 1.5 cm on
    every side, or the game scales the whole piece by more than half a per cent (in voxel within 5.5 cm: a
    piece of 0.1 m cubes cannot be 1.15 m deep, and the kit's own is 1.20). The scale the game would give
    is reported, and the audit above is run on the piece as the game would scale it;
  - the bench's top between 0.44 and 0.53 m (the perch seats that join it are 0.46 to 0.51 m);
  - glass and lamp materials are reported: a material named `glass...` (lit at night) and one named exactly
    `lamp_glow` or `window_glow` that emits in the file.

  The fountain (drawn unscaled, turned 0)
  - the basin's outer face in the band, round the circle: greatest and least radius (the audit above decides;
    the contract's own arithmetic puts a round basin between 1.42 and 1.52 m);
  - the rim where the eight perch seats meet it (radius 1.40 to 1.50 m at the eight bearings): top between
    0.40 and 0.46 m (voxel 0.45 to 0.51), flat to 1.5 cm, and stone in to 1.40 m or less;
  - a part named `water` that draws something, with a material that is not the body's (its roughness is
    reported: it is what makes it water).

Not checked here, because they need the game: the audit's two counts that need a simulated day (`walker_pass`,
`player_pass`), the tram overlap, the kit tests' Khronos validator and byte-for-byte rule, how the piece looks.
"""
import json
import math
import struct
from pathlib import Path

PIXEL = 0.025
CELL = 0.25
CLEARANCE = 0.10
AUDIT_BAND = (0.25, 1.9)
RAIN_GROUND = ("paving", "asphalt", "kerb", "road", "path", "street")
LIT_BY_NAME = ("lamp_glow", "window_glow", "fairy_glow", "light")


def gltf_json(path):
    data = Path(path).read_bytes()
    n = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + n])


def materials_of(path):
    """(the file's materials, {node name: [material index of each of its primitives]})."""
    g = gltf_json(path)
    per_node = {}
    for node in g.get("nodes", []):
        if "mesh" in node:
            per_node[node.get("name", "?")] = [p.get("material") for p in g["meshes"][node["mesh"]]["primitives"]]
    return g.get("materials", []), per_node


def band_polygons(tris, band):
    """Each triangle's part between two heights, flattened to (x, z): the points the audit takes (its vertices
    in the band and where its edges cross the two heights)."""
    lo, hi = band
    out = []
    for tri in tris:
        ys = [p[1] for p in tri]
        if max(ys) <= lo or min(ys) >= hi:
            continue
        pts = [(p[0], p[2]) for p in tri if lo <= p[1] <= hi]
        for k in range(3):
            p, q = tri[k], tri[(k + 1) % 3]
            if p[1] == q[1]:
                continue
            for level in (lo, hi):
                f = (level - p[1]) / (q[1] - p[1])
                if 0.0 < f < 1.0:
                    pts.append((p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f))
        if pts:
            out.append(pts)
    return out


def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def half(seq):
        h = []
        for p in seq:
            while len(h) >= 2 and (h[-1][0] - h[-2][0]) * (p[1] - h[-2][1]) - (h[-1][1] - h[-2][1]) * (p[0] - h[-2][0]) <= 0:
                h.pop()
            h.append(p)
        return h
    lower, upper = half(pts), half(reversed(pts))
    return lower[:-1] + upper[:-1]


class Raster:
    """Solids drawn on a 2.5 cm raster, as the audit traces them: polygons filled, their outlines drawn as
    unbroken lines, and what a mesh's pieces enclose filled in."""

    def __init__(self, x0, z0, x1, z1):
        self.x0, self.z0 = x0, z0
        self.w, self.h = int(math.ceil((x1 - x0) / PIXEL)) + 1, int(math.ceil((z1 - z0) / PIXEL)) + 1
        self.bits = [bytearray(self.w) for _ in range(self.h)]

    def _set(self, i, j, grid):
        if 0 <= i < self.w and 0 <= j < self.h:
            grid[j][i] = 1

    def add_mesh(self, polygons):
        """One mesh's band slice: its pieces, and whatever they enclose."""
        grid = [bytearray(self.w) for _ in range(self.h)]
        for pts in polygons:
            poly = [((x - self.x0) / PIXEL, (z - self.z0) / PIXEL) for x, z in hull(pts)]
            if len(poly) >= 3:
                ys = [p[1] for p in poly]
                for j in range(max(0, int(math.floor(min(ys) - 0.5)) + 1), min(self.h, int(math.floor(max(ys) - 0.5)) + 1)):
                    y = j + 0.5
                    xs = []
                    for k in range(len(poly)):
                        a, b = poly[k], poly[(k + 1) % len(poly)]
                        if (a[1] - y) * (b[1] - y) > 0.0 or a[1] == b[1]:
                            continue
                        xs.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
                    if xs:
                        for i in range(max(0, int(math.floor(min(xs)))), min(self.w - 1, int(math.floor(max(xs)))) + 1):
                            grid[j][i] = 1
            for k in range(len(poly)):
                a, b = poly[k], poly[(k + 1) % len(poly)]
                n = int(math.ceil(math.hypot(b[0] - a[0], b[1] - a[1]) * 3.0)) + 1
                for s in range(n + 1):
                    self._set(int(math.floor(a[0] + (b[0] - a[0]) * s / n)), int(math.floor(a[1] + (b[1] - a[1]) * s / n)), grid)
        # what the pieces enclose: everything not reached from the raster's edge
        outside = [bytearray(self.w) for _ in range(self.h)]
        stack = [(i, j) for i in range(self.w) for j in (0, self.h - 1)] + [(i, j) for j in range(self.h) for i in (0, self.w - 1)]
        while stack:
            i, j = stack.pop()
            if not (0 <= i < self.w and 0 <= j < self.h) or outside[j][i] or grid[j][i]:
                continue
            outside[j][i] = 1
            stack += [(i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)]
        for j in range(self.h):
            for i in range(self.w):
                if not outside[j][i]:
                    self.bits[j][i] = 1

    def distance(self, x, z, reach=0.3):
        """How far the point is from the nearest solid raster cell (0 inside one); `reach` or more when none is near."""
        ci, cj = (x - self.x0) / PIXEL, (z - self.z0) / PIXEL
        r = int(math.ceil(reach / PIXEL)) + 1
        best = reach
        for j in range(max(0, int(cj) - r), min(self.h, int(cj) + r + 1)):
            row = self.bits[j]
            dz = 0.0 if j <= cj <= j + 1 else min(abs(cj - j), abs(cj - j - 1))
            for i in range(max(0, int(ci) - r), min(self.w, int(ci) + r + 1)):
                if row[i]:
                    dx = 0.0 if i <= ci <= i + 1 else min(abs(ci - i), abs(ci - i - 1))
                    d = math.hypot(dx, dz) * PIXEL
                    if d < best:
                        best = d
        return best


def turned(x, z, facing):
    """A point of a seat's or kind's own frame turned `facing` degrees clockwise from north (x east, z south)."""
    t = math.radians(facing)
    return x * math.cos(t) - z * math.sin(t), x * math.sin(t) + z * math.cos(t)


def audit(path, kind, to_kind, seat_box, catalogue, span):
    """The collision audit's three counts that need no simulated day, for one placement of `kind` drawn with
    this piece. `to_kind(x, z)` takes a point of the piece's frame, as the game scales and turns the piece, to
    the kind's frame; `seat_box` is the perch seat's walking-band box in its own frame (x0, z0, x1, z1), or
    None; `span` the half-size of the square of cells looked at, metres."""
    import band
    footprint, anchors = kind.get("footprint", []), kind.get("anchors", [])
    sits = [(a["at"]["x"] / 100.0, a["at"]["z"] / 100.0, float(a.get("facing", 0))) for a in anchors if a.get("type") == "sit"]

    def blocked(x, z):
        for sh in footprint:
            if "r" in sh:
                if (x * 100 - sh["x"]) ** 2 + (z * 100 - sh["z"]) ** 2 < (sh["r"] + 10) ** 2:
                    return True
            elif sh["x"] - 10 <= x * 100 < sh["x"] + sh["w"] + 10 and sh["z"] - 10 <= z * 100 < sh["z"] + sh["d"] + 10:
                return True
        return False

    def own_square(x, z):
        for ax, az, facing in sits:
            lx, lz = turned(x - ax, z - az, -facing)
            if max(abs(lx), abs(lz)) <= 0.25 + 1e-4:
                return True
        return False
    own, with_seats = Raster(-span, -span, span, span), Raster(-span, -span, span, span)
    for name, tris in band.triangles(path).items():
        polygons = [[to_kind(x, z) for x, z in pts] for pts in band_polygons(tris, AUDIT_BAND)]
        if polygons:
            own.add_mesh(polygons)
            with_seats.add_mesh(polygons)
    if seat_box:
        for ax, az, facing in sits:
            corners = [turned(x, z, facing) for x, z in ((seat_box[0], seat_box[1]), (seat_box[2], seat_box[1]), (seat_box[2], seat_box[3]), (seat_box[0], seat_box[3]))]
            with_seats.add_mesh([[(ax + x, az + z) for x, z in corners]])
    n = int(round(span / CELL))
    cells = [(CELL * (i + 0.5), CELL * (j + 0.5)) for i in range(-n, n) for j in range(-n, n)]
    through, within, least_walkable, most_blocked = [], [], None, None
    uncovered = set()
    for x, z in cells:
        if blocked(x, z):
            d = with_seats.distance(x, z)
            if d >= CLEARANCE:
                uncovered.add((round(x, 3), round(z, 3)))
            if most_blocked is None or d > most_blocked[0]:
                most_blocked = (d, x, z)
        else:
            if own_square(x, z):
                continue
            d = own.distance(x, z)
            if d <= 0.0:
                through.append((x, z))
            elif d < CLEARANCE - 1e-4:
                within.append((x, z, d))
            if least_walkable is None or d < least_walkable[0]:
                least_walkable = (d, x, z)
    # blocked cells with nothing solid near, reached from walkable floor through such cells
    reached, frontier = set(), [(round(x, 3), round(z, 3)) for x, z in cells if not blocked(x, z)]
    for _ in range(12):
        nxt = []
        for x, z in frontier:
            for dx, dz in ((CELL, 0), (-CELL, 0), (0, CELL), (0, -CELL)):
                c = (round(x + dx, 3), round(z + dz, 3))
                if c in uncovered and c not in reached:
                    reached.add(c)
                    nxt.append(c)
        frontier = nxt
    return {"through": len(through), "within_10cm": len(within), "reverse_blocked": len(reached),
            "walkable_cell_nearest_m": None if least_walkable is None else [round(v, 3) for v in least_walkable],
            "blocked_cell_farthest_m": None if most_blocked is None else [round(v, 3) for v in most_blocked],
            "offending_walkable_cells": [[round(v, 3) for v in c] for c in (through + [w[:2] for w in within])[:12]],
            "uncovered_blocked_cells": sorted(reached)[:12]}


def audit_problems(result, problems, notes):
    for count, what in (("through", "walkable cells with the piece drawn through their centre"), ("within_10cm", "walkable cells with the piece within 10 cm of their centre"),
                        ("reverse_blocked", "blocked cells with nothing drawn within 10 cm")):
        if result[count]:
            cells = result["offending_walkable_cells"] if count != "reverse_blocked" else result["uncovered_blocked_cells"]
            problems.append(f"collision audit: {result[count]} {what} (at {cells[:4]})")
    near, far = result["walkable_cell_nearest_m"], result["blocked_cell_farthest_m"]
    if near and far:
        notes.append(f"collision audit: the nearest walkable cell centre is {near[0] * 100:.1f} cm from the piece (10 needed), the worst blocked one {far[0] * 100:.1f} cm (under 10 needed)")
        if 0 <= near[0] - CLEARANCE < 0.015 or 0 < CLEARANCE - far[0] < 0.015:
            notes.append("collision audit: within 1.5 cm of a limit, which the game's own tracing may read differently")


def names(path, problems, notes):
    g = gltf_json(path)
    mats = [m.get("name", "") for m in g.get("materials", [])]
    if len(set(mats)) != len(mats):
        problems.append(f"material names not unique: {mats}")
    wet = [m for m in mats if m.lower().startswith(RAIN_GROUND)]
    if wet:
        problems.append(f"materials the game darkens in rain as ground: {wet}")
    lit = [m for m in mats if m.startswith("glass") or m.startswith("neon") or m in LIT_BY_NAME]
    notes.append("materials: " + ", ".join(mats) + (f" (lit by name: {', '.join(lit)})" if lit else " (none lit by name)"))
    odd = sorted({n.get("name", "") for n in g.get("nodes", [])} & {"light", "lights", "display"})
    if odd:
        problems.append(f"parts the game acts on by name: {odd}")
    return mats


def kind_of(agentnagar, kind_id):
    catalogue = json.loads((agentnagar / "city" / "catalogue" / "catalogue.json").read_text())
    return next(k for k in catalogue["kinds"] if k["id"] == kind_id)


def perch_box(agentnagar, style):
    """The kit perch seat's walking-band box in its own frame (x0, z0, x1, z1): what the game stands at a sit anchor."""
    import band
    path = agentnagar / "city" / "godot" / "styles" / style / "assets" / ("v2/perch_seat.glb" if style == "voxel" else "perch_seat.glb")
    polygons = [p for tris in band.triangles(path).values() for p in band_polygons(tris, AUDIT_BAND)]
    xs, zs = [x for p in polygons for x, _ in p], [z for p in polygons for _, z in p]
    return (min(xs), min(zs), max(xs), max(zs)) if xs else None


def shelter_rules(path, style, agentnagar):
    import band
    problems, notes, numbers = [], [], {}
    footprint = [-2.15, -0.40, 2.15, 0.75]
    box, _ = band.band_box(path)
    numbers["band_box"] = [round(v, 3) for v in box]
    off = max(abs(a - b) for a, b in zip(box, footprint))
    sx, sz = (footprint[2] - footprint[0]) / (box[2] - box[0]), (footprint[3] - footprint[1]) / (box[3] - box[1])
    numbers["game_scale"] = [round(sx, 4), round(sz, 4)]
    notes.append(f"walking-band slice {box[0]:.3f},{box[1]:.3f} to {box[2]:.3f},{box[3]:.3f} (footprint -2.15,-0.40 to 2.15,0.75): the game would scale it {sx:.4f} by {sz:.4f}")
    # A piece of 0.1 m cubes cannot be 1.15 m deep: the voxel kit's own shelter is 1.20 (and 4.40 long), and the
    # game draws it 0.977 by 0.958. A voxel piece may be as far off as that, half a cell.
    if off > (0.055 if style == "voxel" else 0.015):
        problems.append(f"its slice between 0.15 and 2.2 m is {off * 100:.1f} cm off the footprint's box: the game will scale the whole piece {sx:.3f} by {sz:.3f}")
    elif off > 0.015:
        notes.append(f"the slice is {off * 100:.1f} cm off the footprint's box, half a cube: as the voxel kit's own piece, which the game draws 0.977 by 0.958")
    # as the game draws it: scaled about the slice so that it fills the footprint, turned half a turn into the kind's frame
    cx, cz, fx, fz = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2, (footprint[0] + footprint[2]) / 2, (footprint[1] + footprint[3]) / 2

    def to_kind(x, z):
        return -(fx + (x - cx) * sx), -(fz + (z - cz) * sz)
    result = audit(path, kind_of(agentnagar, "tram-shelter"), to_kind, perch_box(agentnagar, style), None, 3.5)
    numbers["audit"] = result
    audit_problems(result, problems, notes)
    # the bench's top: where the faces that look up inside the bench's rectangle, below 0.7 m, mostly lie
    tops = {}
    for tris in band.triangles(path).values():
        for a, b, c in tris:
            cxz = ((a[0] + b[0] + c[0]) / 3, (a[2] + b[2] + c[2]) / 3)
            if not (-1.6 < cxz[0] < 0.5 and 0.2 < cxz[1] < 0.5) or max(a[1], b[1], c[1]) > 0.7:
                continue
            u, v = [b[i] - a[i] for i in range(3)], [c[i] - a[i] for i in range(3)]
            n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
            size = math.sqrt(sum(q * q for q in n))
            if size > 0 and n[1] / size > 0.9:                 # looks up (glTF winds a face's front anticlockwise)
                level = round((a[1] + b[1] + c[1]) / 3 / 0.01)
                tops[level] = tops.get(level, 0.0) + size / 2
    if tops:
        seat = max(tops, key=tops.get) * 0.01
        numbers["bench_top_m"] = round(seat, 2)
        notes.append(f"bench top {seat:.2f} m")
        if not 0.44 <= seat <= 0.53:
            problems.append(f"bench top {seat:.2f} m (the perch seats that join it are 0.46 to 0.51 m)")
    else:
        problems.append("no bench found in the bench's rectangle")
    mats = names(path, problems, notes)
    listed, _ = materials_of(path)
    glowing = [m.get("name") for m in listed if m.get("name") in ("lamp_glow", "window_glow") and ("emissiveTexture" in m or any(m.get("emissiveFactor", [0, 0, 0])))]
    numbers["glass_materials"] = [m for m in mats if m.startswith("glass")]
    numbers["lamp_materials_that_emit"] = glowing
    if any(m in ("lamp_glow", "window_glow") for m in mats) and not glowing:
        problems.append("a lamp material that does not emit in the file: the game only sets its strength")
    return problems, notes, numbers


def fountain_rules(path, style, agentnagar):
    import band
    problems, notes, numbers = [], [], {}
    tris_by_node = band.triangles(path)
    # the outer face in the audit's band, bearing by bearing
    reach = [0.0] * 72
    for tris in tris_by_node.values():
        for pts in band_polygons(tris, AUDIT_BAND):
            for x, z in pts:
                k = int((math.degrees(math.atan2(z, x)) % 360) // 5) % 72
                reach[k] = max(reach[k], math.hypot(x, z))
    numbers["outer_radius_m"] = {"greatest": round(max(reach), 3), "least": round(min(reach), 3)}
    notes.append(f"outer face between 0.25 and 1.9 m up: {min(reach):.3f} to {max(reach):.3f} m from the centre round the circle (a round basin passes between 1.42 and 1.52)")
    result = audit(path, kind_of(agentnagar, "fountain-rim"), lambda x, z: (x, z), perch_box(agentnagar, style), None, 3.0)
    numbers["audit"] = result
    audit_problems(result, problems, notes)
    # the rim where the seats meet it: the top of the stone under points 1.41, 1.45 and 1.49 m out along each of
    # the eight bearings and 12 cm either side (a seat is 30 cm wide), and at 1.385 m, just inside where a seat ends
    lo, hi = (0.45, 0.51) if style == "voxel" else (0.40, 0.46)
    near_rim = []
    for name, tris in tris_by_node.items():
        if name == "water":
            continue
        for t in tris:
            rs = [math.hypot(p[0], p[2]) for p in t]
            if max(rs) > 1.30 and min(p[1] for p in t) < 0.7:
                near_rim.append(t)

    def top_under(x, z):
        """The height of the highest stone on the upright line through (x, z), below 0.7 m; None with none."""
        best = None
        for a, b, c in near_rim:
            d = (b[2] - c[2]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[2] - c[2])
            if abs(d) < 1e-12:
                continue
            u = ((b[2] - c[2]) * (x - c[0]) + (c[0] - b[0]) * (z - c[2])) / d
            v = ((c[2] - a[2]) * (x - c[0]) + (a[0] - c[0]) * (z - c[2])) / d
            if u < -1e-9 or v < -1e-9 or u + v > 1 + 1e-9:
                continue
            y = u * a[1] + v * b[1] + (1 - u - v) * c[1]
            if y < 0.7 and (best is None or y > best):
                best = y
        return best
    tops, inner = [], []
    for bearing in range(0, 360, 45):
        t = math.radians(bearing)
        ux, uz = math.sin(t), -math.cos(t)                    # bearing 0 is north, the piece's -z
        for across in (-0.12, 0.0, 0.12):
            for along in (1.41, 1.45, 1.49):
                tops.append(top_under(ux * along - uz * across, uz * along + ux * across))
            inner.append(top_under(ux * 1.385 - uz * across, uz * 1.385 + ux * across))
    numbers["rim_top_m_where_the_seats_meet_it"] = None if any(v is None for v in tops) else [round(min(tops), 3), round(max(tops), 3)]
    if any(v is None for v in tops):
        problems.append("no rim between 1.40 and 1.50 m from the centre under one of the eight seats")
    else:
        notes.append(f"rim top under the eight seats {min(tops):.3f} to {max(tops):.3f} m")
        if min(tops) < lo - 0.005 or max(tops) > hi + 0.005:
            problems.append(f"rim top {min(tops):.2f} to {max(tops):.2f} m where the seats meet it (the seat's board lies on it between {lo} and {hi} m)")
        if max(tops) - min(tops) > 0.015:
            problems.append(f"rim not level where the seats meet it ({(max(tops) - min(tops)) * 100:.1f} cm)")
        if any(v is None or v < min(tops) - 0.03 for v in inner):
            problems.append("the rim's stone does not reach in to 1.40 m under one of the eight seats: the seat's back end would stand in the water")
    mats = names(path, problems, notes)
    listed, per_node = materials_of(path)
    if style != "voxel":
        if not tris_by_node.get("water"):
            problems.append("the part `water` draws nothing")
        else:
            body_mats = {m for name, ms in per_node.items() if name != "water" for m in ms}
            own = [m for m in per_node.get("water", []) if m not in body_mats]
            if not own:
                problems.append("the water has no material of its own")
            numbers["water"] = {"triangles": len(tris_by_node["water"]),
                                "materials": [{"name": listed[m].get("name"), "roughness": listed[m].get("pbrMetallicRoughness", {}).get("roughnessFactor", 1.0),
                                               "textured": "baseColorTexture" in listed[m].get("pbrMetallicRoughness", {})} for m in own]}
            notes.append("water: " + ", ".join(f"{w['name']} (roughness {w['roughness']:.2f}{', textured' if w['textured'] else ''})" for w in numbers["water"]["materials"]))
    return problems, notes, numbers
