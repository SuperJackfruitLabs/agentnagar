"""terrace_rules.py: what the game holds a café table, its umbrella and a square planter to, checked from the
built files alone (check.py calls this for an asset whose entry has `rules`: "table", "umbrella" or "planter").
The rules are those of notes/contracts/terrace.md; each is given here with the code it comes from.

Every piece
  * one root node, named as the kit's, with no transform and no mesh of its own: the game writes the root's
    position and, for a filled piece, its scale (pack_3d.gd `_placement`, `_fill_footprint`), and measures the
    piece in the root's own frame (kit_town.gd `band_points_of`);
  * it stands on the ground (its lowest point within 2 mm of y = 0);
  * material names: no two alike but for a `.001`, none beginning glass or neon, none beginning paving, asphalt,
    kerb, road, path or street in the styles whose ground the rain wets (neon, anime, solarpunk), and none of
    lamp_glow, window_glow, fairy_glow, light on a material that does not emit (kit_town.gd `_collect`,
    pack_3d.gd rain).

A table (kind cafe-table-top, footprint 1.00 m square; filled in every style but voxel)
  * its fill: what it draws between 0.15 and 2.2 m up is fitted to the footprint, widths only. The top must be
    the widest thing there, or the fill fits something else and the top comes out narrow;
  * the top's upper face at the kit body's height (the game never changes heights);
  * the collision audit (tools/collision_audit/audit.gd), on what it draws between 0.25 and 1.9 m once filled:
    something within 10 cm of the centre of each of the 16 cells the grid blocks (centres -38, -13, 12, 37 cm
    from the point on each axis) and nothing within 10 cm of the 20 centres round them (-63, 62 cm);
  * the column on the fitted slice's middle (where the umbrella's pole comes up), within 1 cm once filled;
  * knee room on its two x sides, where the chairs stand: nothing between 0.12 and 0.65 m up farther than 12 cm
    from the axis within 20 cm of the x axis (the note's figures are `about`; 2 cm of slack on the lower one).

An umbrella (kind umbrella; never filled, drawn by its origin on the table's point)
  * its pole on the origin's vertical axis: between 0.8 and 1.3 m up within 1.5 cm of it (the voxel kit's pole
    is one cube off the axis: there, within the 20 cm about the axis);
  * its base inside the footprint's disc (0.40 m) and at most 0.10 m high;
  * its canopy's lowest point beyond 0.5 m from the axis no lower than the kit's own (the `lights` parts, a
    neon kit's bulbs, left out of both);
  * with the same style's table built beside it: below the table's top the pole and its sleeve inside the
    table's column as the game widens it (otherwise they show round it), read every 2 cm of height.

A planter (kind planter, footprint 1.30 m square, drawn 1.305 m; filled in every style)
  * its fill: what it draws between 0.15 and 2.2 m is fitted to 1.305 m, so plants reaching past the box's
    outline shrink the box by as much: more than 2 mm is a miss. The box's outline is what stands between
    0.15 m and a centimetre under its rim (the rim's height from the fit's report beside the file; 0.30 m
    without one). A kit box with a coping wider than its walls is read by its walls, so this is a rule for
    pieces the fit builds, not a measure of the kits' own;
  * the collision audit once filled: something within 10 cm of each of the 36 blocked cells' centres (-63 to
    62 cm), nothing within 10 cm of the 28 round them (-88, 87 cm): a box square to its corners does both;
  * with a `light` part (neon): where the game hangs its lamp, the middle of that part's bounds.

A voxel piece, besides: no part named as its root, every primitive indexed, and its triangles inside the kit's
limit, which the voxel kit's own test holds every piece of its kit to (check.py reports a limit, it does not
hold a piece to it).

Not checked here, because a file cannot show it: how the anime ink pass and toon step draw the piece, whether
surfaces that nearly coincide flicker, the frame cost, what LOD generation makes of the mesh, and whether the
pinned glTF validator passes it.
"""
import json
import struct

import numpy as np

FILL_BAND = (0.15, 2.2)
AUDIT_BAND = (0.25, 1.9)
CLEAR = 0.10
ACTED_ON = ("lamp_glow", "window_glow", "fairy_glow", "light")
PREFIXES = ("glass", "neon")
WET_PREFIXES = ("paving", "asphalt", "kerb", "road", "path", "street")          # darkened in rain, in the styles with wet ground
WET_STYLES = ("neon_noir", "anime_cel", "solarpunk")
LIGHT_PARTS = ("light", "lights")


class Piece:
    """A GLB: its JSON, and each mesh node's triangles in the root's frame (y up)."""

    def __init__(self, path):
        data = open(path, "rb").read()
        n = struct.unpack_from("<I", data, 12)[0]
        self.g = json.loads(data[20:20 + n])
        blob = data[20 + n + 8:]
        g = self.g

        def acc(i):
            a = g["accessors"][i]
            v = g["bufferViews"][a["bufferView"]]
            comps = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[a["type"]]
            dtype = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}[a["componentType"]]
            size = np.dtype(dtype).itemsize * comps
            off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
            stride = v.get("byteStride", size)
            if stride == size:
                return np.frombuffer(blob, dtype, a["count"] * comps, off).reshape(a["count"], comps)
            return np.array([np.frombuffer(blob, dtype, comps, off + k * stride) for k in range(a["count"])])
        self.parts, self.part_materials = {}, {}
        self.prims = []                    # (mesh node's name, material's name, its triangles), in the file's order
        self.mesh_nodes = []               # the names of the nodes that carry a mesh, in the order the game meets them
        self.roots = g["scenes"][g.get("scene", 0)]["nodes"]

        def local(node):
            if "matrix" in node:
                return np.array(node["matrix"], dtype=float).reshape(4, 4).T
            t, s = node.get("translation", [0, 0, 0]), node.get("scale", [1, 1, 1])
            x, y, z, w = node.get("rotation", [0, 0, 0, 1])
            r = np.array([[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
                          [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
                          [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]])
            m = np.eye(4)
            m[:3, :3] = r * np.array(s)[None, :]
            m[:3, 3] = t
            return m

        def visit(i, parent, is_root):
            node = g["nodes"][i]
            world = parent if is_root else parent @ local(node)          # the root's own transform is the game's to write
            if "mesh" in node:
                self.mesh_nodes.append(node.get("name", str(i)))
                for prim in g["meshes"][node["mesh"]]["primitives"]:
                    pos = acc(prim["attributes"]["POSITION"]).astype(float)
                    pos = pos @ world[:3, :3].T + world[:3, 3]
                    idx = acc(prim["indices"]).ravel() if "indices" in prim else np.arange(len(pos))
                    name = node.get("name", str(i))
                    self.parts.setdefault(name, []).append(pos[idx.reshape(-1, 3)])
                    self.prims.append((name, g["materials"][prim["material"]].get("name", "") if "material" in prim else "", pos[idx.reshape(-1, 3)]))
                    if "material" in prim:
                        self.part_materials.setdefault(name, []).append(g["materials"][prim["material"]].get("name", ""))
            for c in node.get("children", []):
                visit(c, world, False)
        for r in self.roots:
            visit(r, np.eye(4), True)
        self.parts = {k: np.concatenate(v) for k, v in self.parts.items()}

    def tris(self, lights=True):
        chosen = [t for name, t in self.parts.items() if lights or name.split(".")[0] not in LIGHT_PARTS]
        return np.concatenate(chosen) if chosen else np.zeros((0, 3, 3))


def slab_sets(tris, lo, hi):
    """Per triangle, the game's band points (kit_town.gd `_band_points`, the audit's `_silhouette`): its
    vertices between the two heights and where its edges cross them, as (x, z). Triangles with none are left out."""
    out = []
    y = tris[:, :, 1]
    reach = (y.max(axis=1) >= lo) & (y.min(axis=1) <= hi)
    for tri in tris[reach]:
        pts = []
        for k in range(3):
            p, q = tri[k], tri[(k + 1) % 3]
            if lo <= p[1] <= hi:
                pts.append((p[0], p[2]))
            if p[1] != q[1]:
                for level in (lo, hi):
                    f = (level - p[1]) / (q[1] - p[1])
                    if 0.0 < f < 1.0:
                        pts.append((p[0] + (q[0] - p[0]) * f, p[2] + (q[2] - p[2]) * f))
        if pts:
            out.append(np.array(pts))
    return out


def box_of(sets):
    """(x0, z0, x1, z1) of the slab's points, or None."""
    if not sets:
        return None
    pts = np.concatenate(sets)
    return np.array([pts[:, 0].min(), pts[:, 1].min(), pts[:, 0].max(), pts[:, 1].max()])


def distances(sets, queries):
    """From each query point (x, z) to the nearest thing the slab draws: 0 inside a triangle's slice."""
    best = np.full(len(queries), np.inf)
    for pts in sets:
        lo, hi = pts.min(axis=0), pts.max(axis=0)
        gap = np.maximum(np.maximum(lo - queries, queries - hi), 0)
        near = np.hypot(gap[:, 0], gap[:, 1]) < best
        if not near.any():
            continue
        q = queries[near]
        if len(pts) >= 3:
            mid = pts.mean(axis=0)
            ring = pts[np.argsort(np.arctan2(pts[:, 1] - mid[1], pts[:, 0] - mid[0]))]
        else:
            ring = pts
        a, b = ring, np.roll(ring, -1, axis=0)
        ab = b - a
        aq = q[:, None, :] - a[None, :, :]
        t = np.clip((aq * ab[None]).sum(axis=2) / np.maximum((ab * ab).sum(axis=1), 1e-18)[None], 0, 1)
        d = np.linalg.norm(aq - t[..., None] * ab[None], axis=2).min(axis=1)
        if len(ring) >= 3:
            cross = ab[None, :, 0] * aq[:, :, 1] - ab[None, :, 1] * aq[:, :, 0]
            d = np.where((cross >= -1e-12).all(axis=1) | (cross <= 1e-12).all(axis=1), 0.0, d)
        best[near] = np.minimum(best[near], d)
    return best


def reach_at(tris, heights, about=(0.0, 0.0), half=0.005):
    """How far from the vertical through `about` the piece reaches at each height (a slice 1 cm thick), and the
    slice's own middle and widths."""
    out = []
    for h in heights:
        box = box_of(slab_sets(tris, h - half, h + half))
        if box is None:
            out.append(None)
            continue
        pts = np.concatenate(slab_sets(tris, h - half, h + half))
        out.append({"reach": float(np.hypot(pts[:, 0] - about[0], pts[:, 1] - about[1]).max()), "mid": ((box[0] + box[2]) / 2, (box[1] + box[3]) / 2),
                    "wide": (float(box[2] - box[0]), float(box[3] - box[1]))})
    return out


def filled(tris, footprint):
    """The game's fill: the scale (x, z) and the shift that put the piece's band box on the footprint
    (x0, z0, x1, z1), and the triangles as then drawn about the placement's point. None with nothing in the band."""
    box = box_of(slab_sets(tris, *FILL_BAND))
    if box is None or box[2] - box[0] < 1e-3 or box[3] - box[1] < 1e-3:
        return None
    sx, sz = (footprint[2] - footprint[0]) / (box[2] - box[0]), (footprint[3] - footprint[1]) / (box[3] - box[1])
    ox = (footprint[0] + footprint[2]) / 2 - (box[0] + box[2]) / 2 * sx
    oz = (footprint[1] + footprint[3]) / 2 - (box[1] + box[3]) / 2 * sz
    drawn = tris.copy()
    drawn[:, :, 0] = tris[:, :, 0] * sx + ox
    drawn[:, :, 2] = tris[:, :, 2] * sz + oz
    return {"scale": (float(sx), float(sz)), "shift": (float(ox), float(oz)), "tris": drawn, "band_box": box}


def audit(tris, blocked, around, problems, what):
    """The collision audit's two rules for a placement, on the piece as drawn: each blocked cell's centre within
    the clearance of something drawn in the walking band, each walkable centre round them clear of it."""
    sets = slab_sets(tris, *AUDIT_BAND)
    cells = np.array([(x, z) for x in blocked for z in blocked])
    ring = np.array([(x, z) for x in around + blocked for z in around + blocked if x in around or z in around])
    if not sets:
        problems.append(f"draws nothing between {AUDIT_BAND[0]} and {AUDIT_BAND[1]} m: every cell it blocks is bare")
        return {}
    d_in, d_out = distances(sets, cells), distances(sets, ring)
    bare, touched = int((d_in >= CLEAR).sum()), int((d_out < CLEAR - 1e-4).sum())
    if bare:
        problems.append(f"{bare} of the {len(cells)} cells the grid blocks for {what} have nothing drawn within 10 cm (worst {d_in.max() * 100:.1f} cm): the audit's reverse_blocked gate")
    if touched:
        problems.append(f"{touched} walkable cells round {what} have it within 10 cm (nearest {d_out.min() * 100:.1f} cm): the audit's within_10cm gate")
    return {"blocked_cells": len(cells), "farthest_blocked_cm": round(float(d_in.max()) * 100, 1), "nearest_walkable_cm": round(float(d_out.min()) * 100, 1)}


def common(piece, kit, style, problems, notes):
    g = piece.g
    if len(piece.roots) != 1:
        problems.append(f"{len(piece.roots)} root nodes: the game writes one root's position and scale")
        return
    root, kit_root = g["nodes"][piece.roots[0]], kit.g["nodes"][kit.roots[0]]
    if root.get("name") != kit_root.get("name"):
        problems.append(f"the root is named {root.get('name')!r}, the kit's {kit_root.get('name')!r}")
    moved = [k for k in ("translation", "rotation", "scale", "matrix") if k in root and list(root[k]) not in ([0, 0, 0], [0, 0, 0, 1], [1, 1, 1])]
    if moved:
        problems.append(f"the root carries a transform ({', '.join(moved)}): the game overwrites it")
    if "mesh" in root:
        problems.append("the root holds a mesh: the kit keeps its geometry in named parts under it")
    low = float(piece.tris()[:, :, 1].min())
    if abs(low) > 0.002:
        problems.append(f"its lowest point is {low * 100:+.1f} cm from the ground")
    names = [m.get("name", "") for m in g.get("materials", [])]
    for m in g.get("materials", []):
        name = m.get("name", "")
        glows = "emissiveTexture" in m or any(v > 0 for v in m.get("emissiveFactor", [0, 0, 0]))
        if name in ACTED_ON and not glows:
            problems.append(f"material {name!r} does not emit: the game would light it as a lamp")
        if name.startswith(PREFIXES) or (style in WET_STYLES and name.startswith(WET_PREFIXES)):
            problems.append(f"material {name!r} begins with a name the game acts on")
        if len(name) > 4 and name[-4] == "." and name[-3:].isdigit():
            problems.append(f"material {name!r}: a second material of one name, which the game does not know")
    if style == "voxel":
        # The voxel kit's own tests (city/tools/styles/voxel/test_assets.py): Godot renames a part that shares its
        # root's name, and the suite's reader takes every primitive's indices without a fallback.
        shared = [n.get("name") for k, n in enumerate(g["nodes"]) if k not in piece.roots and n.get("name") == root.get("name")]
        if shared:
            problems.append(f"a part is named as the root ({root.get('name')!r}): Godot renames it")
        bare = sum(1 for mesh in g.get("meshes", []) for prim in mesh["primitives"] if "indices" not in prim)
        if bare:
            problems.append(f"{bare} primitives without indices: the voxel kit's tests read them without a fallback")
    notes.append("root, ground and material names as the game needs (" + ", ".join(names) + ")")


def voxel_kit(piece, kit_path, problems, notes):
    """What the voxel kit's own test holds every piece of its kit to beyond what check.py holds a piece to
    (city/tools/styles/voxel/test_assets.py, test_every_asset_meets_its_spec): the spec's triangle count is
    a limit there. The specs are read from the checkout the kit's file is in."""
    specs = {}
    for file in sorted((kit_path.parents[5] / "tools" / "styles" / "voxel" / "specs").glob("*.json")):
        specs.update(json.loads(file.read_text()))
    spec = specs.get(kit_path.stem)
    if spec is None:
        problems.append(f"the voxel kit has no spec for {kit_path.stem}")
        return
    count = len(piece.tris())
    if count > spec["tris"]:
        problems.append(f"{count} triangles, over the voxel kit's limit of {spec['tris']}: the kit's own test fails")
    else:
        notes.append(f"{count} triangles, inside the voxel kit's limit of {spec['tris']}, which its own test holds")


TABLE_FOOTPRINT = (-0.5, -0.5, 0.5, 0.5)
PLANTER_DRAWN = (-0.655, -0.655, 0.65, 0.65)          # CityGeometry.drawn_rect of the 1.30 m footprint on the 25 cm grid


def table(piece, kit, style, problems, notes, numbers, beside):
    tris = piece.tris(lights=False)
    top = float(tris[:, :, 1].max())
    kit_top = float(kit.tris(lights=False)[:, :, 1].max())
    if abs(top - kit_top) > 0.01:
        problems.append(f"the top's upper face is {top:.3f} m up, the kit's {kit_top:.3f} m: the game does not change heights")
    all_tris = piece.tris()
    if style == "voxel":
        drawn, scale, about = all_tris, (1.0, 1.0), (0.0, 0.0)
        band_box = box_of(slab_sets(all_tris, *FILL_BAND))
        notes.append("not filled in this style: drawn as built, by its origin")
    else:
        fit = filled(all_tris, TABLE_FOOTPRINT)
        if fit is None:
            problems.append("draws nothing between 0.15 and 2.2 m: the game cannot fit it to its footprint")
            return
        drawn, scale, band_box = fit["tris"], fit["scale"], fit["band_box"]
        about = ((band_box[0] + band_box[2]) / 2, (band_box[1] + band_box[3]) / 2)
        notes.append(f"the game widens it {scale[0]:.3f} by {scale[1]:.3f} (its top to 1.00 m)")
    numbers["game_scale_computed"] = [round(scale[0], 4), round(scale[1], 4)]
    # The top is the widest thing the fill measures.
    top_box = box_of(slab_sets(all_tris, top - 0.08, top + 0.01))
    if top_box is not None and np.abs(top_box - band_box).max() > 0.002:
        problems.append(f"something wider than the top stands between 0.15 and 2.2 m ({band_box[2] - band_box[0]:.3f} by {band_box[3] - band_box[1]:.3f} m against the top's "
                        f"{top_box[2] - top_box[0]:.3f} by {top_box[3] - top_box[1]:.3f}): the fill fits that, and the top comes out narrow")
    numbers.update(audit(drawn, [-0.38, -0.13, 0.12, 0.37], [-0.63, 0.62], problems, "a table"))
    # The column: the narrowest slice between 0.3 m and 15 cm under the top, as built and as drawn.
    heights = [round(h, 2) for h in np.arange(0.30, top - 0.15, 0.02)]
    slices = [s for s in reach_at(all_tris, heights, about) if s is not None]
    if slices:
        thin = min(slices, key=lambda s: max(s["wide"]))
        off = float(np.hypot((thin["mid"][0] - about[0]) * scale[0], (thin["mid"][1] - about[1]) * scale[1]))
        numbers["column_across_drawn_m"] = round(min(thin["wide"][0] * scale[0], thin["wide"][1] * scale[1]), 3)
        numbers["column_off_the_point_cm"] = round(off * 100, 2)
        if off > 0.01:
            problems.append(f"the column stands {off * 100:.1f} cm off the middle of the top, where the umbrella's pole comes up")
        notes.append(f"column {numbers['column_across_drawn_m'] * 100:.1f} cm across once widened, {off * 100:.1f} cm off the point")
    # Knee room on the two x sides.
    pts = np.concatenate(slab_sets(all_tris, 0.12, 0.65) or [np.zeros((0, 2))])
    lane = pts[(np.abs(pts[:, 0] - about[0]) > 0.12) & (np.abs(pts[:, 1] - about[1]) <= 0.20)]
    numbers["points_in_the_knee_room"] = int(len(lane))
    if len(lane):
        problems.append(f"between 0.12 and 0.65 m up something reaches {float(np.abs(lane[:, 0] - about[0]).max()) * 100:.0f} cm from the axis on an x side, where a sitter's knees and shins are")
    # The feet: how high anything stands beyond 12 cm from the axis, and where (said, not held to).
    feet = np.concatenate(slab_sets(all_tris, 0.0, top - 0.15) or [np.zeros((0, 2))])
    numbers["foot_reach_drawn_m"] = round(float(np.hypot((feet[:, 0] - about[0]) * scale[0], (feet[:, 1] - about[1]) * scale[1]).max()), 3) if len(feet) else 0.0


def umbrella(piece, kit, style, problems, notes, numbers, beside):
    tris, kit_tris = piece.tris(), kit.tris(lights=False)
    for h, s in zip((0.8, 0.9, 1.0, 1.1, 1.2, 1.3), reach_at(tris, (0.8, 0.9, 1.0, 1.1, 1.2, 1.3))):
        if s is None:
            problems.append(f"nothing stands at {h} m up: the pole does not run from the ground into the canopy")
            break
        off = float(np.hypot(*s["mid"]))
        if (style == "voxel" and max(abs(s["mid"][0]), abs(s["mid"][1])) > 0.1) or (style != "voxel" and off > 0.015):
            problems.append(f"the pole stands {off * 100:.1f} cm off the origin's axis at {h} m up: the game places it by its origin, on the table's middle")
            break
        numbers["pole_off_axis_cm"] = max(numbers.get("pole_off_axis_cm", 0.0), round(off * 100, 2))
        numbers["pole_across_m"] = round(max(s["wide"]), 3)
    low = np.concatenate(slab_sets(tris, 0.0, 0.25) or [np.zeros((0, 2))])
    base_reach = float(np.hypot(low[:, 0], low[:, 1]).max()) if len(low) else 0.0
    if base_reach > 0.40 + 0.005:
        problems.append(f"the base reaches {base_reach:.2f} m from the axis: outside the footprint's disc of 0.40 m")
    verts = tris.reshape(-1, 3)
    ring = verts[(np.hypot(verts[:, 0], verts[:, 2]) > 0.10) & (verts[:, 1] < 0.5)]
    base_high = float(ring[:, 1].max()) if len(ring) else 0.0
    if base_high > 0.105:
        problems.append(f"the base stands {base_high:.2f} m high: the kits' are at most 0.10 m, at the table's foot between the sitters' feet")
    numbers.update({"base_reach_m": round(base_reach, 3), "base_high_m": round(base_high, 3)})

    def edge(t):
        v = t.reshape(-1, 3)
        far = v[np.hypot(v[:, 0], v[:, 2]) > 0.5]
        return float(far[:, 1].min()) if len(far) else None
    mine, theirs = edge(piece.tris(lights=False)), edge(kit_tris)
    numbers.update({"canopy_edge_m": None if mine is None else round(mine, 3), "kit_canopy_edge_m": None if theirs is None else round(theirs, 3)})
    if mine is None:
        problems.append("nothing reaches beyond 0.5 m from the axis: no canopy")
    elif theirs is not None and mine < theirs - 0.005:
        problems.append(f"the canopy's edge hangs to {mine:.2f} m, lower than the kit's {theirs:.2f} m: through walkers' heads")
    notes.append(f"pole {numbers.get('pole_across_m', 0) * 100:.1f} cm across above the table, base {base_reach:.2f} m out and {base_high * 100:.1f} cm high, canopy's edge {mine if mine is None else round(mine, 2)} m up (kit's {theirs if theirs is None else round(theirs, 2)})")
    # With the table: the pole inside the column below the top.
    if beside is not None:
        t_all = beside.tris()
        t_top = float(beside.tris(lights=False)[:, :, 1].max())
        if style == "voxel":
            t_drawn = t_all
        else:
            fit = filled(t_all, TABLE_FOOTPRINT)
            t_drawn = None if fit is None else fit["tris"]
        if t_drawn is not None:
            heights = [round(h, 2) for h in np.arange(0.16, t_top - 0.06, 0.02)]
            shows = [float(h) for h, u, t in zip(heights, reach_at(tris, heights), reach_at(t_drawn, heights)) if u is not None and (t is None or u["reach"] > t["reach"] + 1e-4)]
            numbers["pole_shows_outside_the_table_at_m"] = shows
            if shows:
                problems.append(f"below the table's top the pole or its sleeve is wider than the table's column from {shows[0]} to {shows[-1]} m up: it shows round the column")
            else:
                notes.append("below the table's top the pole is inside the table's column at every height")
    else:
        notes.append("no table of this style is built beside it: the pole was not held against a column")


def planter(piece, kit, style, problems, notes, numbers, beside, rim=None):
    tris = piece.tris()
    fit = filled(tris, PLANTER_DRAWN)
    if fit is None:
        problems.append("draws nothing between 0.15 and 2.2 m: the game cannot fit it to its footprint")
        return
    box, scale = fit["band_box"], fit["scale"]
    numbers["game_scale_computed"] = [round(scale[0], 4), round(scale[1], 4)]
    walls = box_of(slab_sets(tris, 0.15, max((rim or 0.30) - 0.01, 0.16)))
    if walls is None:
        problems.append("nothing stands between 0.15 m and the rim: no box to measure")
        return
    over = np.array([walls[0] - box[0], walls[1] - box[1], box[2] - walls[2], box[3] - walls[3]])
    numbers["plants_past_the_box_cm"] = [round(float(v) * 100, 2) for v in over]
    numbers["box_drawn_m"] = [round(float((walls[2] - walls[0]) * scale[0]), 3), round(float((walls[3] - walls[1]) * scale[1]), 3)]
    if over.max() > 0.002:
        problems.append(f"its plants reach {over.max() * 100:.1f} cm past the box's outline in the band: the game fits them to the footprint and draws the box "
                        f"{numbers['box_drawn_m'][0]:.3f} by {numbers['box_drawn_m'][1]:.3f} m instead of 1.305")
    notes.append(f"the game widens it {scale[0]:.3f} by {scale[1]:.3f}; its box is drawn {numbers['box_drawn_m'][0]:.3f} by {numbers['box_drawn_m'][1]:.3f} m, plants inside its outline")
    numbers.update(audit(fit["tris"], [-0.63, -0.38, -0.13, 0.12, 0.37, 0.62], [-0.88, 0.87], problems, "a planter"))
    light = piece.parts.get("light")
    if light is not None:
        pts = light.reshape(-1, 3)
        mid = (pts.min(axis=0) + pts.max(axis=0)) / 2
        numbers["lamp_at_m"] = [round(float(v), 3) for v in mid]
        notes.append(f"the game hangs its lamp at {mid[0]:+.2f}, {mid[1]:.2f}, {mid[2]:+.2f} m (the middle of the `light` part)")
        if abs(mid[0]) > 0.3 or abs(mid[2]) > 0.3 or mid[1] > 1.5:
            problems.append("the `light` part's middle is off the planter's middle or above 1.5 m: the lamp would hang there")
        if "lamp_glow" not in piece.part_materials.get("light", []) and "light" not in piece.part_materials.get("light", []):
            problems.append("the `light` part has no lamp material (lamp_glow): it would not glow")


RULES = {"table": table, "umbrella": umbrella, "planter": planter}


def check(rules, style, path, kit_path, beside_path=None):
    """(problems, notes, numbers) for the built piece at `path`, held to `rules`; `beside_path` is the same
    style's built table for an umbrella, when there is one."""
    problems, notes, numbers = [], [], {}
    piece, kit = Piece(path), Piece(kit_path)
    common(piece, kit, style, problems, notes)
    if style == "voxel":
        voxel_kit(piece, kit_path, problems, notes)
    beside = Piece(beside_path) if beside_path is not None and beside_path.exists() else None
    if rules == "planter":
        report = path.with_suffix(".json")
        rim = json.loads(report.read_text()).get("planter", {}).get("rim_m") if report.exists() else None
        planter(piece, kit, style, problems, notes, numbers, beside, rim)
    else:
        RULES[rules](piece, kit, style, problems, notes, numbers, beside)
    return problems, notes, numbers
