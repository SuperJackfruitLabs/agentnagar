"""planted_rules.py: what the game holds a street tree or a palm to, checked from the built file alone (check.py
calls this for an asset whose entry has `planted`). The rules are those of notes/contracts/trees.md (F3 to F9),
each with the code it comes from.

  * the game draws copies of the file's FIRST mesh node only (kit_town.gd `mesh_of`): every triangle must be in it;
  * it tells leaf from trunk by the material's name (leaf, leaves, foliage, frond; kit_town.gd `LEAF`): one
    material named so and one not, and no more than two in all (the anime family's kit tests hold these pieces
    to two);
  * it scales each copy's width by 0.25 m over the trunk's reach: the farthest thing from the origin, in plan,
    that is not leaf, between 0.15 and 2.2 m up, vertices and the points where edges cross those heights
    (kit_town.gd `band_reach`). A piece built to be drawn as built has a reach of 0.25 m; more than 2% off is a
    miss, except in the voxel style, where the trunk is whole cubes and the scale is reported;
  * it turns each copy about the origin: the trunk's foot stands on it. Its middle more than half the reach
    (12.5 cm) off is a miss; more than 3 cm is said (the kits' own trees stand 4 cm off);
  * where the kit has a far twin (<piece>_far.glb, drawn beyond 90 m), the built piece has one too, with one
    mesh node and inside the far spec's triangle limit;
  * no leaf lies on the ground at the foot: a leaf face wholly below 0.5 m is a patch of the drawn ground or
    shadow that the leaf rules took for leaf (the game's width scale and its collision audit do not see it,
    so only this rule does).
"""
import numpy as np

from terrace_rules import Piece, slab_sets

LEAF = ("leaf", "leaves", "foliage", "frond")
BAND = (0.15, 2.2)


def leafy(name):
    return any(word in name.lower() for word in LEAF)


def check(style, path, kit_path, far_limit=800):
    problems, notes, numbers = [], [], {}
    piece = Piece(path)
    nodes = piece.mesh_nodes
    if len(nodes) != 1:
        problems.append(f"{len(nodes)} mesh nodes ({', '.join(nodes)}): the game draws the first only")
    materials = sorted({m for _n, m, _t in piece.prims})
    leaf_names, wood_names = [m for m in materials if leafy(m)], [m for m in materials if not leafy(m)]
    if not leaf_names or not wood_names:
        problems.append(f"materials {materials}: one has to be named as leaf and one not")
    if len(materials) > 2 and style != "voxel" and style != "lowpoly_tropical":
        problems.append(f"{len(materials)} materials: the kit's tests allow two")
    wood = [t for _n, m, t in piece.prims if not leafy(m)]
    reach = 0.0
    if wood:
        sets = slab_sets(np.concatenate(wood), *BAND)
        if sets:
            pts = np.concatenate(sets)
            reach = float(np.hypot(pts[:, 0], pts[:, 1]).max())
            foot = np.concatenate(slab_sets(np.concatenate(wood), 0.0, 0.3) or [np.zeros((1, 2))])
            off = float(np.hypot(*((foot.min(axis=0) + foot.max(axis=0)) / 2)))
            numbers["trunk_foot_off_origin_cm"] = round(off * 100, 1)
            if off > 0.125:
                problems.append(f"the trunk's foot is {off * 100:.0f} cm off the origin: each copy turns about the origin")
            elif off > 0.03:
                notes.append(f"the foot's middle {off * 100:.0f} cm off the origin")
    numbers["trunk_reach_m"] = round(reach, 3)
    leaf = [t for _n, m, t in piece.prims if leafy(m)]
    if leaf:
        tops = np.concatenate(leaf)[:, :, 1].max(axis=1)                       # the file is y up
        low = int((tops < 0.5).sum())
        numbers["leaf_faces_below_half_a_metre"] = low
        if low:
            problems.append(f"{low} leaf faces lie wholly below 0.5 m, at the foot (--planted-leaf-from)")
    if reach < 1e-3:
        problems.append("nothing but leaf between 0.15 and 2.2 m: the game falls back to the height scale for the width")
    else:
        numbers["width_scale_in_game"] = round(0.25 / reach, 3)
        if abs(0.25 / reach - 1) > 0.02 and style != "voxel":
            problems.append(f"trunk reach {reach:.3f} m: the game draws it {0.25 / reach:.2f} times as wide as built")
    notes.append(f"trunk reach {reach:.3f} m, drawn {0.25 / reach:.3f} times as wide as built" if reach > 1e-3 else "no trunk in the band")
    tris = sum(len(t) for _n, _m, t in piece.prims)
    numbers["leaf_triangles"] = int(sum(len(t) for _n, m, t in piece.prims if leafy(m)))
    numbers["wood_triangles"] = int(tris - numbers["leaf_triangles"])
    kit_far = kit_path.with_name(kit_path.stem + "_far.glb")
    if kit_far.exists():
        far = path.with_name(path.stem + "_far.glb")
        if not far.exists():
            problems.append("no far twin: beyond 90 m the game would draw the kit's")
        else:
            twin = Piece(far)
            far_tris = sum(len(t) for _n, _m, t in twin.prims)
            numbers["far_triangles"] = int(far_tris)
            if len(twin.mesh_nodes) != 1:
                problems.append(f"far twin: {len(twin.mesh_nodes)} mesh nodes")
            if far_tris > far_limit:
                problems.append(f"far twin: {far_tris} triangles, limit {far_limit}")
            notes.append(f"far twin {far_tris} triangles")
    return problems, notes, numbers
