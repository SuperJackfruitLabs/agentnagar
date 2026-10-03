"""planting_rules.py: what the game and its tests hold a shrub and a kerbed bed to, as far as a GLB file alone
can show it. check.py calls these; standard library only (and the pilot's band.py for reading triangles).

The rules, each with where it comes from (city/godot/ unless said):

A shrub (pack_3d.gd _planted_across, kit_town.gd mesh_of and band_reach; tests/test_anime_pack.gd:146-172;
tools/collision_audit/solids_3d.gd; city/tools/styles/*/test_assets.py):
  one-mesh      the file has one mesh node: the game draws the first alone, and measures them all;
  no-transform  no node carries a transform: the MultiMesh drops it;
  reach         the farthest the file draws from its origin between 0.15 and 2.2 m up is the kit piece's (the
                game scales a shrub across by 1.05 m over it: a different reach is a differently sized shrub);
  circle        what it draws between 0.30 and 1.59 m of its own height (inside the audit's 0.25 to 1.9 m band
                at every height the game grows a shrub to, 0.85 to 1.19) reaches, in each of 360 directions
                from the origin, at least 0.995 of the reach (the kits' 32-sided drum reaches 0.9952), so the
                copy fills its footprint's disc and leaves no blocked cell bare;
  materials     at most two in the anime, neon and solarpunk kits (their tests' rule for planted pieces).

A kerbed bed (pack_3d.gd _fit_prop; tools/collision_audit; the contract note's arithmetic):
  kerb          along the whole edge of the rectangle the file draws between 0.15 and 2.2 m (what the game
                stretches to the footprint, 3.30 by 1.30 m in the town), something is drawn between 0.255 and
                1.9 m within 10 cm as the game draws it: the kerb is the whole rectangle, corners included, it
                stands higher than 0.25 m, and no plant hangs far enough over it to push it inside the
                footprint. (The grid blocks cells whose centres lie 2.5 cm or more inside that rectangle, and
                the audit wants something solid within 10 cm of each: 10 cm from the edge leaves a margin.
                The voxel kit's own bed has a 0.4 m gap in the kerb at each end, with its bushes 8 cm behind
                it as drawn; it passes the audit, and passes here.);
  lights        in neon, a node `lights` whose material is named `lamp_glow` and emits in the file.

Any planting piece:
  names         no material is named as the game names what it lights or wets (`light`, `lamp_glow`,
                `window_glow`, `fairy_glow`, glass*, neon*; and in the styles that wet their ground, paving*,
                asphalt*, kerb*, road*, path*, street*), except `lamp_glow` on a `lights` node;
  root          in the voxel kit no node but the root carries the asset's name.

Not checkable from the file: whether the collision audit's counts stay zero (it reads the placed copies on
the walking grid, in the engine); the kits' rebuild test (a swapped file is not what the kit's generator
builds); the pinned Khronos validator (not run here); frame cost; how the piece looks under the game's light.
"""
import json
import math
import struct

BAND_MEASURE = (0.15, 2.2)
SHRUB_AUDIT = (0.30, 1.59)          # inside the audit's 0.25-1.9 m band at every growth from 0.85 to 1.19
BED_AUDIT = (0.255, 1.9)
LIT = ("light", "lamp_glow", "window_glow", "fairy_glow")
LIT_PREFIX = ("glass", "neon")
WET_PREFIX = ("paving", "asphalt", "kerb", "road", "path", "street")
WET_STYLES = ("neon_noir", "anime_cel", "solarpunk")
TWO_MATERIALS = ("neon_noir", "anime_cel", "solarpunk")


def glb_json(path):
    data = open(path, "rb").read()
    n = struct.unpack("<I", data[12:16])[0]
    return json.loads(data[20:20 + n])


def mesh_nodes(g):
    """The file's nodes that carry a mesh, in the order the engine meets them (depth first): (name, node)."""
    found = []

    def visit(i):
        node = g["nodes"][i]
        if "mesh" in node:
            found.append((node.get("name", str(i)), node))
        for c in node.get("children", []):
            visit(c)
    for i in g["scenes"][g.get("scene", 0)]["nodes"]:
        visit(i)
    return found


def materials_of(g, node):
    return [g["materials"][p["material"]].get("name", "") if "material" in p else "" for p in g["meshes"][node["mesh"]]["primitives"]]


def band_part(tri, lo, hi):
    """A triangle's part between two heights, from above: the (x, z) of its vertices inside the band and of the
    points where its edges cross the two heights (as the audit's _silhouette takes them)."""
    if max(p[1] for p in tri) <= lo or min(p[1] for p in tri) >= hi:
        return []
    pts = [(p[0], p[2]) for p in tri if lo <= p[1] <= hi]
    for k in range(3):
        p, q = tri[k], tri[(k + 1) % 3]
        if p[1] == q[1]:
            continue
        for level in (lo, hi):
            f = (level - p[1]) / (q[1] - p[1])
            if 0.0 < f < 1.0:
                pts.append((p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f))
    return pts


def hull(points):
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def half(seq):
        out = []
        for p in seq:
            while len(out) >= 2 and (out[-1][0] - out[-2][0]) * (p[1] - out[-2][1]) - (out[-1][1] - out[-2][1]) * (p[0] - out[-2][0]) <= 0:
                out.pop()
            out.append(p)
        return out
    lower, upper = half(pts), half(reversed(pts))
    return lower[:-1] + upper[:-1]


def band_points(tris, band=BAND_MEASURE):
    """kit_town.gd _band_points: (x, z) of vertices inside the band and of edges' crossings of its heights."""
    lo, hi = band
    out = []
    for tri in tris:
        for k in range(3):
            p, q = tri[k], tri[(k + 1) % 3]
            if lo <= p[1] <= hi:
                out.append((p[0], p[2]))
            if p[1] == q[1]:
                continue
            for level in (lo, hi):
                f = (level - p[1]) / (q[1] - p[1])
                if 0.0 < f < 1.0:
                    out.append((p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f))
    return out


def outline_by_direction(tris, band, n=360):
    """How far from the origin what the triangles draw in the band reaches along each of n directions: the
    farthest crossing of the direction's ray with any triangle's flattened part (what the parts enclose
    counts as filled, as the audit traces outer outlines only)."""
    best = [0.0] * n
    step = 2 * math.pi / n
    for tri in tris:
        poly = hull(band_part(tri, *band))
        if len(poly) < 2:
            continue
        edges = [(poly[k], poly[(k + 1) % len(poly)]) for k in range(len(poly) if len(poly) > 2 else 1)]
        for p, q in edges:
            a0, a1 = math.atan2(p[1], p[0]), math.atan2(q[1], q[0])
            d = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi          # the short way round from p to q
            lo_a, hi_a = (a0, a0 + d) if d >= 0 else (a0 + d, a0)
            ex, ey = q[0] - p[0], q[1] - p[1]
            for k in range(math.ceil(lo_a / step - 1e-9), math.floor(hi_a / step + 1e-9) + 1):
                dx, dy = math.cos(k * step), math.sin(k * step)
                den = dx * ey - dy * ex
                if abs(den) < 1e-12:
                    t = max(math.hypot(*p), math.hypot(*q)) if (p[0] * dx + p[1] * dy) > 0 else 0.0
                else:
                    t = (p[0] * ey - p[1] * ex) / den
                    s = (p[0] * dy - p[1] * dx) / den
                    if not -1e-9 <= s <= 1 + 1e-9:
                        continue
                if t > best[k % n]:
                    best[k % n] = t
    return best


def solid_cells(tris, band, pixel=0.01):
    """The cells (i, j), `pixel` metres wide, that what the triangles draw in the band covers from above: each
    part's outline drawn as lines and, where it has area, filled."""
    cells = set()
    for tri in tris:
        poly = hull(band_part(tri, *band))
        if not poly:
            continue
        for k in range(len(poly)):
            p, q = poly[k], poly[(k + 1) % len(poly)]
            n = max(1, int(math.hypot(q[0] - p[0], q[1] - p[1]) / (pixel / 2)))
            for s in range(n + 1):
                cells.add((math.floor((p[0] + (q[0] - p[0]) * s / n) / pixel), math.floor((p[1] + (q[1] - p[1]) * s / n) / pixel)))
        if len(poly) >= 3:
            j0, j1 = math.floor(min(p[1] for p in poly) / pixel), math.floor(max(p[1] for p in poly) / pixel)
            for j in range(j0, j1 + 1):
                y = (j + 0.5) * pixel
                xs = []
                for k in range(len(poly)):
                    a, b = poly[k], poly[(k + 1) % len(poly)]
                    if (a[1] - y) * (b[1] - y) < 0:
                        xs.append(a[0] + (y - a[1]) * (b[0] - a[0]) / (b[1] - a[1]))
                if len(xs) >= 2:
                    for i in range(math.floor(min(xs) / pixel), math.floor(max(xs) / pixel) + 1):
                        cells.add((i, j))
    return cells


def shrub(path, tris_by_node, style, kit_reach):
    """(problems, numbers) for a shrub's file."""
    g = glb_json(path)
    problems, numbers = [], {}
    meshes = mesh_nodes(g)
    numbers["mesh_nodes"] = [name for name, _ in meshes]
    if len(meshes) != 1:
        problems.append(f"{len(meshes)} mesh nodes ({', '.join(name for name, _ in meshes)}): the game draws the first alone and measures them all")
    moved = [n.get("name", "?") for n in g["nodes"] if any(k in n for k in ("translation", "rotation", "scale", "matrix"))]
    if moved:
        problems.append(f"nodes with a transform, which the game drops: {moved}")
    every = [t for tris in tris_by_node.values() for t in tris]
    pts = band_points(every)
    reach = max((math.hypot(x, z) for x, z in pts), default=0.0)
    numbers["reach_m"] = round(reach, 4)
    numbers["kit_reach_m"] = round(kit_reach, 4)
    numbers["drawn_scale_across"] = round(1.05 / reach, 3) if reach else None
    if abs(reach - kit_reach) > 0.01 * kit_reach:
        problems.append(f"reach {reach:.3f} m against the kit's {kit_reach:.3f} m: the game would scale it across by {1.05 / max(reach, 1e-9):.2f}, not {1.05 / kit_reach:.2f}")
    first = tris_by_node.get(meshes[0][0], []) if meshes else []
    ring = outline_by_direction(first, SHRUB_AUDIT)
    least = min(ring) / reach if reach else 0.0
    numbers["circle_least"] = round(least, 4)
    numbers["circle_directions_short"] = sum(1 for r in ring if r < 0.995 * reach)
    if least < 0.995:
        problems.append(f"its outline between {SHRUB_AUDIT[0]} and {SHRUB_AUDIT[1]} m reaches only {least:.3f} of its reach in {numbers['circle_directions_short']} of 360 directions: not a whole circle")
    names = [m.get("name", "") for m in g.get("materials", [])]
    numbers["materials"] = names
    if style in TWO_MATERIALS and len(names) > 2:
        problems.append(f"{len(names)} materials (the kit's tests allow a planted piece two)")
    return problems, numbers


def bed(path, tris_by_node, style, drawn=(3.30, 1.30), copies=1):
    """(problems, numbers) for a kerbed bed's file, drawn `copies` times end to end over `drawn` metres."""
    g = glb_json(path)
    problems, numbers = [], {}
    every = [t for tris in tris_by_node.values() for t in tris]
    pts = band_points(every)
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    z0, z1 = min(p[1] for p in pts), max(p[1] for p in pts)
    numbers["band_box_m"] = [round(v, 3) for v in (x0, z0, x1, z1)]
    numbers["slice_m"] = [round(x1 - x0, 3), round(z1 - z0, 3)]
    along, deep = drawn[0] / copies / (x1 - x0), drawn[1] / (z1 - z0)
    numbers["drawn_scale"] = [round(along, 3), round(deep, 3)]
    pixel, reach_drawn = 0.01, 0.10
    near = math.ceil(reach_drawn / pixel / min(along, deep))
    cells = solid_cells(every, BED_AUDIT, pixel)
    bare, total = [], 0
    edge = []
    n_x, n_z = int((x1 - x0) / 0.02), int((z1 - z0) / 0.02)
    edge += [(x0 + (x1 - x0) * k / n_x, z) for k in range(n_x + 1) for z in (z0, z1)]
    edge += [(x, z0 + (z1 - z0) * k / n_z) for k in range(n_z + 1) for x in (x0, x1)]
    for x, z in edge:
        total += 1
        i, j = math.floor(x / pixel), math.floor(z / pixel)
        if not any((i + di, j + dj) in cells for di in range(-near, near + 1) for dj in range(-near, near + 1)
                   if (di * pixel * along) ** 2 + (dj * pixel * deep) ** 2 <= reach_drawn ** 2):
            bare.append((round(x, 2), round(z, 2)))
    numbers["edge_points_bare"] = len(bare)
    numbers["edge_points"] = total
    if bare:
        problems.append(f"{len(bare)} of {total} points along the edge of its slice have nothing drawn between {BED_AUDIT[0]} and {BED_AUDIT[1]} m within 10 cm as drawn (first: {bare[:3]}): "
                        "the kerb is not the whole rectangle there, or is under 0.25 m, or a plant hangs far over it")
    if style == "neon_noir":
        lights = [node for name, node in mesh_nodes(g) if name == "lights"]
        if not lights:
            problems.append("no `lights` node (the neon spec names one)")
        else:
            mats = [g["materials"][p["material"]] for p in g["meshes"][lights[0]["mesh"]]["primitives"] if "material" in p]
            glows = [m for m in mats if m.get("name") == "lamp_glow" and (any(v > 0 for v in m.get("emissiveFactor", [0, 0, 0])) or "emissiveTexture" in m)]
            numbers["lights_materials"] = [m.get("name") for m in mats]
            if not glows:
                problems.append("the `lights` node has no material named `lamp_glow` that emits in the file (the game does not switch emission on)")
    return problems, numbers


def names(path, style, asset_name):
    """(problems, numbers) on the names the game acts on."""
    g = glb_json(path)
    problems = []
    for name, node in mesh_nodes(g):
        for m in materials_of(g, node):
            lit = m in LIT or m.startswith(LIT_PREFIX)
            wet = style in WET_STYLES and m.startswith(WET_PREFIX)
            if (lit and not (m == "lamp_glow" and name == "lights")) or wet:
                problems.append(f"material `{m}` on `{name}`: the game {'lights' if lit else 'wets'} a material of that name")
    if style == "voxel":
        roots = set(g["scenes"][g.get("scene", 0)]["nodes"])
        same = [n.get("name") for i, n in enumerate(g["nodes"]) if i not in roots and n.get("name") == asset_name]
        if same:
            problems.append(f"a node below the root is named `{asset_name}` (the voxel kit's tests forbid it)")
    return problems, {"materials": [m.get("name", "") for m in g.get("materials", [])]}
