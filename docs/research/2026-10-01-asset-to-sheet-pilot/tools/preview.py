"""Quick look at a GLB: four views in one image (front, three-quarter, side, top-down three-quarter).

    blender --background --factory-startup --python preview.py -- IN.glb OUT.png [--decimate N] [--texture] [--size PX]

Workbench render. Without --texture the model is drawn as plain clay with
cavity shading, which shows the shape; with it, the model's own colours.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = Path(argv[0]), Path(argv[1])
target = int(argv[argv.index("--decimate") + 1]) if "--decimate" in argv else 0
textured = "--texture" in argv
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 512

bpy.ops.wm.read_factory_settings(use_empty=True)
if src.suffix == ".blend":
    bpy.ops.wm.open_mainfile(filepath=str(src))
else:
    bpy.ops.import_scene.gltf(filepath=str(src))
scene = bpy.context.scene
meshes = [o for o in scene.objects if o.type == "MESH"]
tris = 0
for o in meshes:
    n = sum(len(p.vertices) - 2 for p in o.data.polygons)
    tris += n
    if target and n > target:
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new("d", "DECIMATE")
        mod.ratio = target / n
        bpy.ops.object.modifier_apply(modifier=mod.name)
print(f"PREVIEW {src.name}: {tris} triangles in {len(meshes)} mesh(es)")

# Bounds in world space.
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
centre, radius = (lo + hi) / 2, (hi - lo).length / 2

scene.render.engine = "BLENDER_WORKBENCH"
sh = scene.display.shading
sh.light = "STUDIO"
sh.color_type = "TEXTURE" if textured else ("OBJECT" if src.suffix == ".blend" else "SINGLE")
if "--vertex" in argv:
    # Show the colours baked into the model's vertex colours.
    sh.color_type = "VERTEX"
    sh.light = "FLAT"
if "--material" in argv:
    # Show each material's own base colour (the importer leaves the viewport colour grey).
    sh.color_type = "MATERIAL"
    for mat in bpy.data.materials:
        if mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "BSDF_PRINCIPLED":
                    c = node.inputs["Base Color"].default_value
                    mat.diffuse_color = (c[0], c[1], c[2], 1.0)
    sh.show_shadows = True
    sh.shadow_intensity = 0.35
sh.single_color = (0.78, 0.76, 0.72)
sh.show_cavity = True
sh.cavity_type = "BOTH"
sh.show_shadows = False
scene.display.render_aa = "8"
scene.render.film_transparent = False
scene.world = bpy.data.worlds.new("w")
scene.world.color = (0.92, 0.92, 0.94)
scene.render.resolution_x = scene.render.resolution_y = size
scene.view_settings.view_transform = "Standard"

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = radius * 2.05
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

views = [("front", 0, 8), ("quarter", 35, 22), ("side", 90, 8), ("above", 35, 50)]
paths = []
for label, yaw, pitch in views:
    y, p = math.radians(yaw), math.radians(pitch)
    d = Vector((math.sin(y) * math.cos(p), -math.cos(y) * math.cos(p), math.sin(p)))
    cam.location = centre + d * radius * 4
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = out.with_name(f"{out.stem}-{label}.png")
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
    paths.append(path)

# One sheet of the four views.
imgs = [bpy.data.images.load(str(p)) for p in paths]
import numpy as np  # noqa: E402
tiles = [np.array(i.pixels[:], dtype=np.float32).reshape(size, size, 4) for i in imgs]
sheet = np.concatenate(tiles, axis=1)
res = bpy.data.images.new("sheet", size * 4, size, alpha=True)
res.pixels = sheet.ravel()
res.filepath_raw = str(out)
res.file_format = "PNG"
res.save()
for p in paths:
    p.unlink()
print(f"PREVIEW wrote {out}")
