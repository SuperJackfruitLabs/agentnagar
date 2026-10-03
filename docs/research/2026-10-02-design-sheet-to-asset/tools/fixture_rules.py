"""fixture_rules.py: what the game and its tests hold a street fixture to, as far as the file alone shows it.

check.py calls `rules` for a piece whose entry in assets.json names a `contract`: `lamp`, `bollard` or `railing`
(its second file, the post, is checked as `railing_post`). The rules are those of
notes/contracts/street-fixtures.md, each with the code it was read from. Standard library only.

Every fixture
  * material names: none begins with glass or neon (the game glazes and lights a material by those names:
    kit_town.gd _collect), nor, in a style whose ground turns wet in rain (anime, neon, solarpunk), with paving,
    asphalt, kerb, road, path or street (pack_3d.gd wet ground); each is used once, and none is a second copy
    (`name.001`: the game knows a lit material by its exact name);
  * a material named `lamp_glow` brings its own emission (a factor above zero, or a texture): the game sets only
    its strength (pack_3d.gd set_time_of_day);
  * node names are unique, the root is named after the file, and in voxel no part carries the file's name
    (the voxel kit's test: the engine renames such a part);
  * it stands on the ground (its lowest point within 5 mm of y = 0).

A lamp post or a bollard (drawn unscaled at a point: pack_3d.gd _placement)
  * the collision audit's rule (tools/collision_audit, tests/test_collision_audit.gd holds every style to zero
    offenders): the core blocks the four cells round the piece's point, their centres up to 18.4 cm from it,
    and the nearest centre it leaves free is 38.9 cm away. Between 0.25 and 1.9 m above the ground the piece
    must draw something within 10 cm of each blocked centre, whichever of the eight facings it stands at
    (checked every 5 degrees round, at 18.4 cm), and nothing within 10 cm of a free one (so nothing further
    than 28.9 cm from its axis). The audit lifts the band by the height of any ground drawn under the piece,
    which a file does not show, so both are also taken with the band lifted by up to 0.25 m. A foot too slim at
    0 or at 0.15 m is a miss (every kit's lamp and bollard holds to 0.15 m at least); how much ground the foot
    holds with is reported. Reaching past 28.9 cm is a miss in the band as it stands, and reported where it
    begins higher (the low-poly kit's banner does, from 2.02 m). Reaching outside the catalogue's disc (20 cm a
    lamp, 15 cm a bollard) is reported, not a miss;
  * a lamp: one mesh part named `light` (the game hangs its lamp at the middle of that part's box:
    kit_town.gd light_point), that middle 3.0 m up or higher (the neon test's high lamps; the anime test wants
    1.5 m) and within 15 cm of the axis, every material on it emitting, one of them `lamp_glow`;
  * a bollard: no part named `light` in low-poly, anime and voxel (it would get a full lamp at knee height, and
    fails the anime test that every lamp is above 1.5 m) nor in solarpunk (whose band glows as a `lamp_glow`
    surface of the body); in neon a mesh part `light` in `lamp_glow` (its spec names it).

A railing panel and its post (drawn as instances of the file's first mesh: kit_town.gd mesh_of, pack_3d.gd _fence)
  * one mesh in the file, and no transform on any node (the instances ignore node transforms);
  * the panel runs from x = -1 to x = +1 (within 2 mm): the game lays panels 2 m apart;
  * its own post at the -x end and nothing closing the +x end: in the last 12 cm at -x something rises from the
    ground, unbroken, past three quarters of the panel's height, and in the last 2.5 cm at +x nothing does (a
    kerb or a low wall along the ground and the rails' ends are not a post, nor is a frame bar that stands
    back from the end; a far post left on the panel has its outer face on the end);
  * alike on both sides of z = 0 where the game measures it (0.15 to 2.2 m up: kit_town.gd band_box), to
    within a centimetre;
  * the post is centred on the origin and as high as the panel (within a centimetre). With the fence set off
    the floor by the larger half depth of the two pieces plus a centimetre (pack_3d.gd _fence), every face the
    anime test looks at (the panel's two faces across the run, the post's four sides: test_anime_pack.gd
    test_fences_stand_just_off_the_floor_they_edge) must stand off the floor by more than nothing and less
    than 2 cm: a miss in anime, whose test it is, and reported in the other styles (there it says how far a
    post that is slimmer than its panel stands off the floor);
  * triangles inside the kit's limit: check.py holds these two to it, because they are drawn by the hundred.

Not checked here, because a file does not show it: the audit itself (it reads the ground the game draws under
each piece), how the lamp's light and the glow pass look, the Khronos validator (check.py runs it when it is
installed), and the kits' byte-for-byte test, which any replaced file fails by design.
"""
import math

AUDIT_BAND = (0.25, 1.9)
MEASURE_BAND = (0.15, 2.2)
BLOCKED_CENTRE = 0.184          # the farthest of the four blocked cell centres from the piece's point
FREE_CENTRE = 0.389             # the nearest centre left walkable
CLEARANCE = 0.10
DISC = {"lamp": 0.20, "bollard": 0.15}
LIFTS = (0.0, 0.05, 0.10, 0.15, 0.20, 0.25)
ACTED_ON = ("glass", "neon")
WETTED = ("paving", "asphalt", "kerb", "road", "path", "street")
WET_GROUND = ("anime_cel", "neon_noir", "solarpunk")
NO_LIGHT_ON_A_BOLLARD = ("lowpoly_tropical", "anime_cel", "voxel", "solarpunk")


def _hull(points):
    pts = sorted(set(points))
    if len(pts) < 3:
        return pts
    def turn(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and turn(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and turn(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def _slices(tris, lo, hi):
    """Each triangle's part between two heights, flattened to (x, z), as the audit cuts it (solids_3d.gd
    _silhouette): its corners inside the band and the points where its edges cross the band's two heights,
    taken as their convex outline."""
    out = []
    for tri in tris:
        ys = (tri[0][1], tri[1][1], tri[2][1])
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
            out.append(_hull(pts))
    return out


def _distance(c, poly):
    """From the point c to a convex outline (0 inside it)."""
    n = len(poly)
    if n == 1:
        return math.hypot(c[0] - poly[0][0], c[1] - poly[0][1])
    best, inside = math.inf, n >= 3
    for i in range(n if n > 2 else 1):
        a, b = poly[i], poly[(i + 1) % n]
        dx, dy = b[0] - a[0], b[1] - a[1]
        den = dx * dx + dy * dy
        t = 0.0 if den == 0 else max(0.0, min(1.0, ((c[0] - a[0]) * dx + (c[1] - a[1]) * dy) / den))
        best = min(best, math.hypot(c[0] - a[0] - t * dx, c[1] - a[1] - t * dy))
        if dx * (c[1] - a[1]) - dy * (c[0] - a[0]) < 0:
            inside = False
    return 0.0 if inside else best


def audit_reach(tris, lift=0.0):
    """What the piece draws in the audit's band lifted by `lift`: (the greatest distance from a blocked cell's
    centre, taken every 5 degrees round at 18.4 cm, to anything drawn; how far from the axis it reaches at
    most). None with nothing in the band."""
    pieces = _slices(tris, AUDIT_BAND[0] + lift, AUDIT_BAND[1] + lift)
    if not pieces:
        return None
    far = max(math.hypot(x, z) for poly in pieces for x, z in poly)
    near_enough = [poly for poly in pieces if max(math.hypot(x, z) for x, z in poly) > BLOCKED_CENTRE - 1.5 * CLEARANCE]      # the rest lie more than 15 cm from every centre
    worst = 0.0
    for step in range(72):
        t = math.radians(step * 5)
        c = (BLOCKED_CENTRE * math.cos(t), BLOCKED_CENTRE * math.sin(t))
        worst = max(worst, min((_distance(c, poly) for poly in near_enough), default=math.inf))
    return worst, far


def _rise(tris, end, width):
    """How high what stands on the ground rises, unbroken, within `width` of a panel's end (-1 or +1): the top of
    the run of heights, from the ground up, that the triangles there cover (a break of under 5 mm is none)."""
    spans = []
    for tri in tris:
        inside = [p for p in tri if (p[0] - end * (1.0 - width)) * end >= 0]
        if not inside:
            continue
        ys = [p[1] for p in inside]
        for k in range(3):
            p, q = tri[k], tri[(k + 1) % 3]
            if (p[0] - end * (1.0 - width)) * (q[0] - end * (1.0 - width)) < 0:
                f = (end * (1.0 - width) - p[0]) / (q[0] - p[0])
                ys.append(p[1] + (q[1] - p[1]) * f)
        spans.append((min(ys), max(ys)))
    top = 0.05
    for lo_y, hi_y in sorted(spans):
        if lo_y > top + 0.005:
            break
        top = max(top, hi_y)
    return top if any(lo_y < 0.05 for lo_y, _ in spans) else 0.0


def _box(tris):
    pts = [p for tri in tris for p in tri]
    return [min(p[k] for p in pts) for k in range(3)], [max(p[k] for p in pts) for k in range(3)]


def _emits(material):
    return sum(material.get("emissiveFactor", [0, 0, 0])) > 0 or "emissiveTexture" in material


def _materials_of(doc, node):
    return [doc["materials"][p["material"]] for p in doc["meshes"][node["mesh"]]["primitives"] if "material" in p]


def measure_box(band, tris):
    """The game's measure of a piece where people walk (kit_town.gd band_box): [x0, z0, x1, z1], or None."""
    pts = band.band_points(tris, MEASURE_BAND)
    return [min(x for x, _ in pts), min(z for _, z in pts), max(x for x, _ in pts), max(z for _, z in pts)] if pts else None


def rules(role, style, path, doc, by_node, band, partner=None):
    """(problems, notes, facts) for the file at `path`: `doc` its JSON, `by_node` its triangles by node (y up, in
    the root's frame), `band` the pilot's band module, `partner` the panel's triangles when `role` is the post."""
    problems, notes, facts = [], [], {}
    nodes = doc.get("nodes", [])
    names = [n.get("name") for n in nodes]
    materials = doc.get("materials", [])
    every = [tri for tris in by_node.values() for tri in tris]

    # ---- every fixture
    material_names = [m.get("name", "") for m in materials]
    for name in material_names:
        if name.lower().startswith(ACTED_ON) or (style in WET_GROUND and name.lower().startswith(WETTED)):
            problems.append(f"material `{name}`: the game acts on that name")
        if len(name) > 4 and name[-4] == "." and name[-3:].isdigit():
            problems.append(f"material `{name}` is a second copy of a name: the game does not know it")
    if len(set(material_names)) != len(material_names):
        problems.append(f"material names used twice: {sorted({n for n in material_names if material_names.count(n) > 1})}")
    for m in materials:
        if m.get("name") == "lamp_glow" and not _emits(m):
            problems.append("`lamp_glow` has no emission in the file: the game sets only its strength")
    if len(set(names)) != len(names):
        problems.append(f"node names used twice: {sorted({n for n in names if names.count(n) > 1})}")
    roots = doc["scenes"][doc.get("scene", 0)]["nodes"]
    root_names = [nodes[i].get("name") for i in roots]
    if root_names != [path.stem]:
        problems.append(f"root {root_names}, not one root named after the file (`{path.stem}`)")
    if style == "voxel" and path.stem in [n.get("name") for k, n in enumerate(nodes) if k not in roots]:
        problems.append(f"a part carries the file's name `{path.stem}`: the engine renames it")
    lo, hi = _box(every)
    facts["lowest_m"] = round(lo[1], 4)
    if abs(lo[1]) > 0.005:
        problems.append(f"its lowest point is {lo[1] * 100:.1f} cm off the ground")
    facts["materials"] = material_names

    # ---- a post stood on a point
    if role in ("lamp", "bollard"):
        reaches = {}
        for lift in LIFTS:
            got = audit_reach(every, lift)
            reaches[lift] = None if got is None else (round(got[0], 4), round(got[1], 4))
        facts["audit_m"] = {f"{k:.2f}": v for k, v in reaches.items()}
        for lift in (0.0, 0.15):
            got = reaches[lift]
            where = "the walking band" if lift == 0 else f"the band lifted {lift} m (ground drawn under it)"
            if got is None:
                problems.append(f"draws nothing in {where}")
            elif got[0] >= CLEARANCE - 0.002:
                problems.append(f"in {where} a blocked cell's centre is {got[0] * 100:.1f} cm from anything it draws (the audit wants under 10): its foot is too slim")
        far = reaches[0.0][1] if reaches[0.0] else 0.0
        if far > FREE_CENTRE - CLEARANCE:
            problems.append(f"reaches {far * 100:.1f} cm from its axis where people walk: within 10 cm of a cell left walkable (limit 28.9)")
        elif far > DISC[role] + 0.002:
            notes.append(f"reaches {far * 100:.1f} cm from its axis in the band, outside its {DISC[role] * 100:.0f} cm disc but inside the audit's 28.9 cm")
        wide_from = next((lift for lift in LIFTS if reaches[lift] and reaches[lift][1] > FREE_CENTRE - CLEARANCE), None)
        if wide_from and far <= FREE_CENTRE - CLEARANCE:
            notes.append(f"reaches {reaches[wide_from][1] * 100:.1f} cm from its axis below {AUDIT_BAND[1] + wide_from:.2f} m: clear of the audit only while the ground drawn under it is lower than {wide_from * 100:.0f} cm")
        held = [lift for lift in LIFTS if reaches[lift] and reaches[lift][0] < CLEARANCE - 0.002]
        if held and reaches[0.0]:
            notes.append(f"audit's rule: every blocked centre within {reaches[0.0][0] * 100:.1f} cm of the piece (under 10 wanted), and still with {max(held) * 100:.0f} cm of ground under it; reaches {far * 100:.1f} cm at most")
    lights = [n for n in nodes if n.get("name") == "light"]
    if role == "lamp":
        if len(lights) != 1 or "mesh" not in lights[0]:
            problems.append(f"{len(lights)} part(s) named `light` that are meshes wanted: exactly one (the game hangs its lamp there)")
        else:
            l_lo, l_hi = _box(by_node["light"])
            at = [(a + b) / 2 for a, b in zip(l_lo, l_hi)]
            facts["lamp_at_m"] = [round(v, 3) for v in at]
            if at[1] < 3.0:
                problems.append(f"the lamp would hang {at[1]:.2f} m up: the neon test's high lamps are at 3.0 m or above")
            if math.hypot(at[0], at[2]) > 0.15:
                problems.append(f"the lamp would hang {math.hypot(at[0], at[2]) * 100:.0f} cm off the post's axis")
            on_light = _materials_of(doc, lights[0])
            if not on_light or not all(_emits(m) for m in on_light):
                problems.append("a material on `light` does not emit")
            if "lamp_glow" not in [m.get("name") for m in on_light]:
                problems.append("`light` has no material named `lamp_glow`")
            notes.append(f"lamp at {at[1]:.2f} m, {math.hypot(at[0], at[2]) * 100:.1f} cm off the axis")
    if role == "bollard":
        if style in NO_LIGHT_ON_A_BOLLARD and lights:
            problems.append("a part named `light`: the game would hang a lamp on this bollard")
        if style == "neon_noir":
            if len(lights) != 1 or "mesh" not in lights[0]:
                problems.append("neon's bollard wants one mesh part named `light` (its lit band)")
            elif "lamp_glow" not in [m.get("name") for m in _materials_of(doc, lights[0])]:
                problems.append("`light` has no material named `lamp_glow`")
        if style == "solarpunk" and "lamp_glow" not in material_names:
            notes.append("no `lamp_glow` surface: the solarpunk kit's bollard has a band that glows")

    # ---- a fence panel and its post
    if role in ("railing", "railing_post"):
        meshes = [n for n in nodes if "mesh" in n]
        if len(meshes) != 1:
            problems.append(f"{len(meshes)} meshes in the file: the game draws only the first")
        moved = [n.get("name") for n in nodes if any(k in n for k in ("translation", "rotation", "scale", "matrix"))]
        if moved:
            problems.append(f"transforms on {moved}: the instances ignore them")
        box = measure_box(band, every)
        facts["band_box_m"] = None if box is None else [round(v, 4) for v in box]
        if box is None:
            problems.append("draws nothing between 0.15 and 2.2 m")
    if role == "railing" and facts.get("band_box_m"):
        if abs(lo[0] + 1.0) > 0.002 or abs(hi[0] - 1.0) > 0.002:
            problems.append(f"runs from x = {lo[0]:.3f} to {hi[0]:.3f}, not from -1 to +1")
        rises = {-1: _rise(every, -1, 0.12), 1: _rise(every, 1, 0.025)}
        facts["rises_from_the_ground_m"] = {"at -x": round(rises[-1], 3), "at +x": round(rises[1], 3)}
        if rises[-1] < 0.75 * hi[1]:
            problems.append(f"no post at the -x end: what stands on the ground there rises to {rises[-1]:.2f} m of {hi[1]:.2f}")
        if rises[1] >= 0.75 * hi[1]:
            problems.append(f"a post closes the +x end (it rises from the ground to {rises[1]:.2f} m): the next panel's post stands there")
        if abs(-box[1] - box[3]) > 0.01:
            problems.append(f"not alike on both sides of z = 0 where people walk: {-box[1] * 100:.1f} cm and {box[3] * 100:.1f} cm")
        half = max(-box[1], box[3])
        facts["half_depth_m"] = round(half, 4)
        notes.append(f"half depth where people walk {half * 100:.1f} cm (the kits': 5 to 10), so the fence stands {half * 100 + 1:.1f} cm off the floor")
    if role == "railing_post" and facts.get("band_box_m") and partner is not None:
        panel = measure_box(band, partner)
        p_lo, p_hi = _box(partner)
        if abs(box[0] + box[2]) > 0.01 or abs(box[1] + box[3]) > 0.01:
            problems.append(f"not centred on the origin: x {box[0]:.3f} to {box[2]:.3f}, z {box[1]:.3f} to {box[3]:.3f}")
        if abs(hi[1] - p_hi[1]) > 0.01:
            problems.append(f"{hi[1]:.3f} m high against the panel's {p_hi[1]:.3f} m")
        depth = max(-panel[1], panel[3], -box[1], box[3])
        gaps = {"the panel's -z face": depth + 0.01 + panel[1], "the panel's +z face": depth + 0.01 - panel[3],
                "the post's -x side": depth + 0.01 + box[0], "the post's +x side": depth + 0.01 - box[2],
                "the post's -z side": depth + 0.01 + box[1], "the post's +z side": depth + 0.01 - box[3]}
        facts["off_the_floor_m"] = {k: round(v, 4) for k, v in gaps.items()}
        for which, gap in gaps.items():
            if not 0.0 < gap < 0.02 and (style == "anime_cel" or gap <= 0.0):
                problems.append(f"{which} would stand {gap * 100:.1f} cm off the floor it edges (the anime test wants more than 0 and under 2)")
        notes.append(f"with the panel: the fence set off by {depth * 100 + 1:.1f} cm; its six faces stand {min(gaps.values()) * 100:.1f} to {max(gaps.values()) * 100:.1f} cm off the floor (under 2 wanted)")
    return problems, notes, facts
