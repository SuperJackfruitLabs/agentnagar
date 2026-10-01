"""Blender pass 1: turn a raw generated tree (a TRELLIS.2 GLB) into clean parts.

    blender --background --factory-startup --python analyse.py -- IN.glb OUT_DIR NAME [--height 9.8] [--across 12.0]

What it does, in order:
  1. imports the GLB, joins its meshes and applies transforms (Blender is Z-up);
  2. reads each face's colour from the generated base-colour texture and sorts
     faces into wood (trunk, limbs, roots), leaf (crown) and other (whatever
     else the picture held: people, lamps, a tram);
  3. drops the "other" faces and small loose pieces;
  4. stands the tree on the ground with the trunk's foot at the origin and
     scales it to the pack's size for the great tree;
  5. writes OUT_DIR/NAME-wood.json and NAME-leaf.json (vertices and triangles),
     NAME-lobes.json (the crown as overlapping ellipsoids, for leaf-card
     crowns) and NAME-report.json (counts and sizes), and saves NAME-clean.blend.

Nothing here is style-specific; the per-style builders read these files.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out_dir, name = Path(argv[0]), Path(argv[1]), argv[2]
HEIGHT = float(argv[argv.index("--height") + 1]) if "--height" in argv else 9.8
ACROSS = float(argv[argv.index("--across") + 1]) if "--across" in argv else 12.0
out_dir.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(src))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
obj = bpy.context.view_layer.objects.active
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Keep the tree; drop separate pieces the picture also held (a bush, a lamp).
bm0 = bmesh.new()
bm0.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm0, verts=bm0.verts, dist=1e-6)
bm0.verts.ensure_lookup_table()
seen0, isles0 = set(), []
for v in bm0.verts:
    if v.index in seen0:
        continue
    stack, isle = [v], []
    seen0.add(v.index)
    while stack:
        u = stack.pop()
        isle.append(u)
        for e in u.link_edges:
            o2 = e.other_vert(u)
            if o2.index not in seen0:
                seen0.add(o2.index)
                stack.append(o2)
    isles0.append(isle)
big0 = max(len(i) for i in isles0)
gone = [v for i in isles0 if len(i) < 0.3 * big0 for v in i]
dropped_pieces = sum(1 for i in isles0 if len(i) < 0.3 * big0)
bmesh.ops.delete(bm0, geom=gone, context="VERTS")
bm0.to_mesh(obj.data)
bm0.free()
obj.data.update()

me = obj.data
report = {"source": src.name, "separate_pieces_dropped": dropped_pieces, "raw_triangles": sum(len(p.vertices) - 2 for p in me.polygons),
          "raw_vertices": len(me.vertices)}

# ---- Face colours from the generated texture ----
image = None
for mat in me.materials:
    if mat and mat.use_nodes:
        for node in mat.node_tree.nodes:
            if node.type == "BSDF_PRINCIPLED":
                link = node.inputs["Base Color"].links
                if link and link[0].from_node.type == "TEX_IMAGE":
                    image = link[0].from_node.image
report["has_texture"] = image is not None
n_faces = len(me.polygons)
colour = np.zeros((n_faces, 3), dtype=np.float32)
if image is not None and me.uv_layers:
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, image.channels)[:, :, :3]
    uv = np.zeros(len(me.loops) * 2, dtype=np.float32)
    me.uv_layers.active.data.foreach_get("uv", uv)
    uv = uv.reshape(-1, 2)
    for p in me.polygons:
        c = uv[p.loop_start:p.loop_start + p.loop_total].mean(axis=0)
        x = min(w - 1, max(0, int(c[0] % 1.0 * w)))
        y = min(h - 1, max(0, int(c[1] % 1.0 * h)))
        colour[p.index] = px[y, x]
elif me.color_attributes:
    att = me.color_attributes[0]
    data = np.zeros(len(att.data) * 4, dtype=np.float32)
    att.data.foreach_get("color", data)
    data = data.reshape(-1, 4)[:, :3]
    for p in me.polygons:
        idx = list(p.loop_indices) if att.domain == "CORNER" else list(p.vertices)
        colour[p.index] = data[idx].mean(axis=0)
    report["has_texture"] = True

centres = np.array([p.center[:] for p in me.polygons], dtype=np.float32)
zmin, zmax = float(centres[:, 2].min()), float(centres[:, 2].max())
r, g, b = colour[:, 0], colour[:, 1], colour[:, 2]
lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
if report["has_texture"]:
    # Pixels are linear here. Leaves: green leads. Wood: red leads green leads blue, not too bright.
    leaf = (g > r * 1.04) & (g > b * 1.12)
    wood = (~leaf) & (r >= g * 0.98) & (g >= b * 0.95) & (lum < 0.45)
else:
    # No colour: split by distance from the trunk's axis and height.
    cx, cy = np.median(centres[centres[:, 2] < zmin + 0.25 * (zmax - zmin), 0]), np.median(
        centres[centres[:, 2] < zmin + 0.25 * (zmax - zmin), 1])
    rad = np.hypot(centres[:, 0] - cx, centres[:, 1] - cy)
    span = max(np.ptp(centres[:, 0]), np.ptp(centres[:, 1]))
    wood = (rad < 0.12 * span) & (centres[:, 2] < zmin + 0.55 * (zmax - zmin))
    leaf = ~wood
other = ~(leaf | wood)
report["faces"] = {"leaf": int(leaf.sum()), "wood": int(wood.sum()), "other": int(other.sum())}

kind = np.where(leaf, 1, np.where(wood, 2, 0)).astype(np.int32)
layer = me.attributes.new("kind", "INT", "FACE")
layer.data.foreach_set("value", kind)


def part(mask, label, keep_ratio=0.02):
    """A new object holding the faces in `mask`, minus loose pieces smaller
    than `keep_ratio` of the largest."""
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    drop = [f for f in bm.faces if not mask[f.index]]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    # Loose islands.
    bm.verts.ensure_lookup_table()
    seen, islands = set(), []
    for v in bm.verts:
        if v in seen:
            continue
        stack, isle = [v], []
        seen.add(v)
        while stack:
            u = stack.pop()
            isle.append(u)
            for e in u.link_edges:
                o = e.other_vert(u)
                if o not in seen:
                    seen.add(o)
                    stack.append(o)
        islands.append(isle)
    if islands:
        biggest = max(len(i) for i in islands)
        small = [v for i in islands if len(i) < keep_ratio * biggest for v in i]
        bmesh.ops.delete(bm, geom=small, context="VERTS")
    m = bpy.data.meshes.new(f"{name}-{label}")
    bm.to_mesh(m)
    bm.free()
    o = bpy.data.objects.new(f"{name}-{label}", m)
    bpy.context.scene.collection.objects.link(o)
    return o


wood_o = part(wood, "wood")
leaf_o = part(leaf, "leaf", keep_ratio=0.004)
wood_o.color = (0.36, 0.2, 0.1, 1.0)
leaf_o.color = (0.22, 0.5, 0.16, 1.0)
bpy.data.objects.remove(obj)

# ---- Stand it up, centre it on the trunk's foot, scale to the pack's size ----
wv = np.array([v.co[:] for v in wood_o.data.vertices], dtype=np.float64)
lv = np.array([v.co[:] for v in leaf_o.data.vertices], dtype=np.float64)
allv = np.vstack([wv, lv]) if len(wv) and len(lv) else (wv if len(wv) else lv)
base_z = float(wv[:, 2].min()) if len(wv) else float(allv[:, 2].min())
if len(wv):
    low = wv[wv[:, 2] < base_z + 0.12 * (wv[:, 2].max() - base_z)]
    foot = np.array([np.median(low[:, 0]), np.median(low[:, 1]), base_z])
else:
    foot = np.array([np.median(allv[:, 0]), np.median(allv[:, 1]), base_z])
height = float(allv[:, 2].max() - base_z)
across = float(max(np.ptp(allv[:, 0]), np.ptp(allv[:, 1])))
scale = min(HEIGHT / height, ACROSS / across)
report.update({"generated_height": height, "generated_across": across, "scale": scale,
               "final_height": height * scale, "final_across": across * scale})
# A crown as broad as the pack's on a tree shorter than the pack's reads small
# in the square, so the tree may stand up to a quarter taller, to the pack's height.
zs = max(1.0, min(1.25, HEIGHT / (height * scale)))
report["z_stretch"] = zs
report["final_height"] = height * scale * zs
BAND_TOP, HALF = 1.95, 2.5
for o in (wood_o, leaf_o):
    for v in o.data.vertices:
        c = (Vector(v.co) - Vector(foot)) * scale
        c.z *= zs
        # Nothing but the trunk and roots stands in the walking band outside the tree's square.
        if c.z < BAND_TOP and (abs(c.x) > HALF or abs(c.y) > HALF):
            c.z = BAND_TOP
        v.co = c
    o.data.update()

# ---- The generator's colours, as points the builders can sample ----
# (face centres of the raw model, moved as the parts were, with each face's
# colour from the generated texture; a few thousand of each kind)
pts = (centres.astype(np.float64) - foot) * scale
pts[:, 2] *= zs
rng0 = np.random.default_rng(3)
samples = {}
for label, mask, most in (("leaf", leaf, 9000), ("wood", wood, 3000)):
    idx = np.flatnonzero(mask)
    if len(idx) > most:
        idx = rng0.choice(idx, most, replace=False)
    samples[label] = {"points": np.round(pts[idx], 3).tolist(), "colours": np.round(colour[idx], 4).tolist()}
    if len(idx):
        lum_ = 0.2126 * colour[idx, 0] + 0.7152 * colour[idx, 1] + 0.0722 * colour[idx, 2]
        report[f"{label}_luminance"] = [round(float(np.percentile(lum_, q)), 4) for q in (5, 50, 95)]
(out_dir / f"{name}-colours.json").write_text(json.dumps(samples))


def dump(o, path, target=None):
    """Writes vertices and triangles; `target` decimates to about that many triangles first."""
    bpy.context.view_layer.objects.active = o
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    if target and tris > target:
        mod = o.modifiers.new("decimate", "DECIMATE")
        mod.ratio = target / tris
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.verts.ensure_lookup_table()
    data = {"verts": [[round(c, 4) for c in v.co] for v in bm.verts],
            "faces": [[v.index for v in f.verts] for f in bm.faces]}
    bm.free()
    Path(path).write_text(json.dumps(data))
    return len(data["faces"])


bpy.ops.wm.save_as_mainfile(filepath=str(out_dir / f"{name}-clean.blend"))
report["wood_full"] = dump(wood_o, out_dir / f"{name}-wood-full.json")
report["leaf_full"] = dump(leaf_o, out_dir / f"{name}-leaf-full.json")

# ---- The crown as ellipsoid lobes (k-means over leaf vertices) ----
lv = np.array([v.co[:] for v in leaf_o.data.vertices], dtype=np.float64)
lobes = []
if len(lv) > 50:
    k = 26
    rng = np.random.default_rng(7)
    cent = lv[rng.choice(len(lv), k, replace=False)]
    for _ in range(40):
        d = ((lv[:, None, :] - cent[None, :, :]) ** 2).sum(axis=2)
        lab = d.argmin(axis=1)
        for j in range(k):
            pts = lv[lab == j]
            if len(pts):
                cent[j] = pts.mean(axis=0)
    for j in range(k):
        pts = lv[lab == j]
        if len(pts) < 20:
            continue
        rad = np.clip(pts.std(axis=0) * 1.9, 0.75, 2.0)
        lobes.append([[round(float(c), 3) for c in cent[j]], [round(float(x), 3) for x in rad]])
(out_dir / f"{name}-lobes.json").write_text(json.dumps(lobes))
report["lobes"] = len(lobes)
report["crown_centre"] = [round(float(c), 3) for c in lv.mean(axis=0)] if len(lv) else None
report["crown_half"] = [round(float(c), 3) for c in (np.ptp(lv, axis=0) / 2)] if len(lv) else None

# ---- Occupancy, for the voxel pack: which blocks the tree fills ----
from mathutils.bvhtree import BVHTree  # noqa: E402


def tree_of(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    t = BVHTree.FromBMesh(bm)
    bm.free()
    return t


def occupied(o, step, pad=0.35):
    """Block indices (i, j, k) in Godot axes (x east, y up, z south) whose
    centre is inside `o` or within `pad` blocks of its surface."""
    if not len(o.data.vertices):
        return []
    t = tree_of(o)
    co = np.array([v.co[:] for v in o.data.vertices])
    lo = np.floor(co.min(axis=0) / step).astype(int) - 1
    hi = np.ceil(co.max(axis=0) / step).astype(int) + 1
    out = []
    for i in range(lo[0], hi[0]):
        for j in range(lo[1], hi[1]):
            for k in range(max(0, lo[2]), hi[2]):
                p = Vector(((i + 0.5) * step, (j + 0.5) * step, (k + 0.5) * step))
                loc, nrm, _idx, dist = t.find_nearest(p)
                if loc is None:
                    continue
                inside = (p - loc).dot(nrm) < 0.0
                if inside or dist < pad * step:
                    # Blender (x, y, z up) -> Godot (x, y up, z = -y)
                    out.append([int(i), int(k), int(-j - 1)])
    return out


occ = {"wood_step": 0.2, "leaf_step": 0.7,
       "wood": occupied(wood_o, 0.2), "leaf": occupied(leaf_o, 0.7, pad=0.5)}
(out_dir / f"{name}-blocks.json").write_text(json.dumps(occ))
report["wood_blocks"], report["leaf_blocks"] = len(occ["wood"]), len(occ["leaf"])

wv2 = np.array([v.co[:] for v in wood_o.data.vertices], dtype=np.float64)
rad2 = np.hypot(wv2[:, 0], wv2[:, 1])
cand = wv2[(rad2 > 1.5) & (rad2 < 2.3) & (wv2[:, 2] > 2.3) & (wv2[:, 2] < 4.2)]
drops = []
if len(cand):
    ang = np.arctan2(cand[:, 1], cand[:, 0])
    for sector in range(9):
        lo_a = -math.pi + sector * 2 * math.pi / 9
        sel = cand[(ang >= lo_a) & (ang < lo_a + 2 * math.pi / 9)]
        if len(sel):
            pick = sel[np.argmin(sel[:, 2])]   # the lowest limb point in this sector
            drops.append([round(float(c), 3) for c in pick])
(out_dir / f"{name}-drops.json").write_text(json.dumps(drops))
report["drops"] = len(drops)

# Decimated parts for the faceted and blocky styles.
report["wood_3000"] = dump(wood_o, out_dir / f"{name}-wood.json", target=3000)
bpy.context.view_layer.objects.active = leaf_o
rm = leaf_o.modifiers.new("remesh", "REMESH")
rm.mode = "VOXEL"
rm.voxel_size = 0.28
rm.adaptivity = 0.0
bpy.ops.object.modifier_apply(modifier=rm.name)
report["leaf_remeshed"] = sum(len(q.vertices) - 2 for q in leaf_o.data.polygons)
report["leaf_2600"] = dump(leaf_o, out_dir / f"{name}-leaf.json", target=2600)
report["leaf_core"] = dump(leaf_o, out_dir / f"{name}-leaf-core.json", target=900)
(out_dir / f"{name}-report.json").write_text(json.dumps(report, indent=2))
print("ANALYSE", json.dumps(report))
