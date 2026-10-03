"""pair.py TABLE.glb UMBRELLA.glb OUT.png [--fill W,D] [--size 500]: a café table and its umbrella as the game
stands them, on one point.

The game puts both placements on the same point. The umbrella is drawn as built, by its origin. The table, in
the styles whose entry has `fill`, is widened until what it draws between 0.15 and 2.2 m up (its top) is the
footprint, W by D metres (1.0,1.0), with that slice's middle on the point and its heights unchanged
(pack_3d.gd `_fill_footprint`); without --fill (the voxel style) it is drawn as built, by its origin.

Renders OUT-<view>.png and OUT-<view>-lit.png (shaded) from four places: `quarter` (from above the canopy's
edge), `seat` (a seated eye, 1.2 m up and 0.95 m from the middle: the pole coming out of the top), `low` (0.45 m
up and 2.4 m off: the column, the feet and the umbrella's base under the top) and `foot` (looking down on the
foot from 1.1 m up beside the table). Prints one line beginning PAIR with the scale the table was given and how
wide the two are at the heights where one has to hide the other.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
table_path, umbrella_path, out = argv[0], argv[1], Path(argv[2])
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 500
fill = [float(v) for v in argv[argv.index("--fill") + 1].split(",")] if "--fill" in argv else None
BAND = (0.15, 2.2)


def load(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def triangles(objs):
    """Every triangle of the objects' meshes, in world space (n, 3, 3)."""
    out_ = []
    for o in objs:
        if o.type != "MESH":
            continue
        me = o.data
        me.calc_loop_triangles()
        co = np.array([(o.matrix_world @ v.co)[:] for v in me.vertices])
        out_.append(co[np.array([lt.vertices[:] for lt in me.loop_triangles])])
    return np.concatenate(out_)


def band_points(tris, lo, hi):
    """The game's measure (kit_town.gd `_band_points`): the vertices between the two heights and the points
    where edges cross them, flattened (Blender's z is up)."""
    pts = []
    for k in range(3):
        p, q = tris[:, k], tris[:, (k + 1) % 3]
        inside = (p[:, 2] >= lo) & (p[:, 2] <= hi)
        pts.append(p[inside][:, :2])
        for level in (lo, hi):
            den = q[:, 2] - p[:, 2]
            ok = den != 0
            f = np.where(ok, (level - p[:, 2]) / np.where(ok, den, 1), -1)
            cross = ok & (f > 0) & (f < 1)
            pts.append((p[cross] + (q[cross] - p[cross]) * f[cross][:, None])[:, :2])
    return np.concatenate(pts)


def widths(tris, heights):
    """How far from the vertical through the origin the triangles reach at each height (a slice 1 cm thick)."""
    out_ = []
    for z in heights:
        pts = band_points(tris, z - 0.005, z + 0.005)
        out_.append(float(np.hypot(pts[:, 0], pts[:, 1]).max()) if len(pts) else 0.0)
    return out_


bpy.ops.wm.read_factory_settings(use_empty=True)
table = load(table_path)
t_root = next(o for o in table if o.parent is None)
numbers = {"table_scale": [1.0, 1.0], "table_moved_m": [0.0, 0.0]}
if fill:
    pts = band_points(triangles(table), *BAND)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    sx, sy = fill[0] / (hi[0] - lo[0]), fill[1] / (hi[1] - lo[1])
    mid = (lo + hi) / 2
    t_root.scale = (sx, sy, 1.0)                      # Blender's y is the game's z
    t_root.location = (-mid[0] * sx, -mid[1] * sy, 0.0)
    bpy.context.view_layer.update()
    numbers = {"table_scale": [round(float(sx), 4), round(float(sy), 4)], "table_moved_m": [round(float(-mid[0] * sx), 4), round(float(-mid[1] * sy), 4)]}
umbrella = load(umbrella_path)
bpy.context.view_layer.update()
t_tris, u_tris = triangles(table), triangles(umbrella)
top = float(t_tris[:, :, 2].max())
heights = [round(h, 2) for h in np.arange(0.02, top + 0.20, 0.04)]
numbers["table_top_m"] = round(top, 3)
numbers["reach_from_the_axis_m"] = [{"at_m": h, "table": round(a, 3), "umbrella": round(b, 3)} for h, a, b in zip(heights, widths(t_tris, heights), widths(u_tris, heights))]
# Where the umbrella shows outside the table: between the table's foot and its top, the umbrella's reach from
# the axis more than the table's.
numbers["umbrella_outside_table_between_m"] = [r["at_m"] for r in numbers["reach_from_the_axis_m"] if 0.14 < r["at_m"] < top - 0.08 and r["umbrella"] > r["table"] + 1e-4]

# The umbrella's base under the table's feet: at each point of the ground round the axis (from 6 cm out, every
# 3 degrees and 1 cm), the height of the base's top against the height of the table's underside above it. Where
# the base is the higher, a foot passes through it.
from mathutils.bvhtree import BVHTree


def tree_of(tris):
    flat = tris.reshape(-1, 3)
    return BVHTree.FromPolygons([tuple(v) for v in flat], [(3 * i, 3 * i + 1, 3 * i + 2) for i in range(len(tris))])


t_tree, u_tree = tree_of(t_tris), tree_of(u_tris)
u_low = u_tris.reshape(-1, 3)
u_low = u_low[u_low[:, 2] < 0.12]
base_reach = float(np.hypot(u_low[:, 0], u_low[:, 1]).max()) if len(u_low) else 0.0
through, worst, tried = 0, 0.0, 0
for r in np.arange(0.06, base_reach + 0.005, 0.01):
    for deg in range(0, 360, 3):
        x, y = float(r * np.cos(np.radians(deg))), float(r * np.sin(np.radians(deg)))
        base_top = u_tree.ray_cast(Vector((x, y, 0.3)), Vector((0, 0, -1)))
        under = t_tree.ray_cast(Vector((x, y, -0.01)), Vector((0, 0, 1)))
        if base_top[0] is None:
            continue
        tried += 1
        if under[0] is not None and under[0].z < base_top[0].z - 0.001 and under[0].z < 0.3:
            through += 1
            worst = max(worst, base_top[0].z - under[0].z)
numbers["umbrella_base"] = {"reach_m": round(base_reach, 3), "points_tried": tried, "points_where_a_table_foot_passes_through_it": through,
                            "deepest_m": round(worst, 3)}

for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf and bsdf.inputs["Base Color"].is_linked:
        node = bsdf.inputs["Base Color"].links[0].from_node
        if node.type == "TEX_IMAGE":
            m.node_tree.nodes.active = node
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.color_type = "TEXTURE"
scene.display.shading.show_backface_culling = False
scene.render.resolution_x = scene.render.resolution_y = size
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = False
world.color = (0.55, 0.57, 0.6)
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
bpy.ops.mesh.primitive_plane_add(size=8.0, location=(0, 0, -0.001))          # the paving, so the feet read as standing
ground = bpy.context.view_layer.objects.active
gm = bpy.data.materials.new("ground")
gm.diffuse_color = (0.62, 0.6, 0.57, 1.0)
ground.data.materials.append(gm)
scene.display.shading.color_type = "TEXTURE"
views = [("quarter", (3.1, -3.1, 2.9), (0, 0, 1.15), 50), ("seat", (0.95, -0.25, 1.2), (0, 0, 0.82), 24),
         ("low", (1.7, -1.7, 0.45), (0, 0, 0.42), 50), ("foot", (0.75, -0.75, 1.1), (0, 0, 0.0), 35)]
paths = []
for lit in (False, True):
    scene.display.shading.light = "STUDIO" if lit else "FLAT"
    for name, pos, at, lens in views:
        cam_data.lens = lens
        cam.location = pos
        cam.rotation_euler = (Vector(at) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out.with_name(f"{out.stem}-{name}{'-lit' if lit else ''}.png"))
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
numbers["images"] = paths
print("PAIR " + json.dumps(numbers))
