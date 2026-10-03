"""look.py MODEL.glb OUT.png [--size 512] [--from-behind] [--lit] [--colour texture|vertex|material] [--view ...]
[--views a,b] [--span M] [--heights Z0,Z1] [--light NAME]:
a model from five places, in its own colours, unlit: front, three-quarter from above, the side, from a standing
eye under it (1.6 m up, 9 m off, looking up), from straight above. For a model with several textures the colour
one is shown (not the glow or the bumps).

--lit          shaded, to see form.
--from-behind  the front and three-quarter cameras stand on the other side (a piece whose front is glTF -z
               shows its back to the usual ones).
--colour HOW   where the colours come from: `texture` (the default when a material has one), `vertex` (a kit
               piece that carries its colours on its vertices; the default when there are any and no texture),
               `material` (a kit piece coloured by its materials alone).
--view NAME=X,Y,Z,TX,TY,TZ[,LENS]  only this view (may be given several times): the camera at X,Y,Z looking at
               TX,TY,TZ, in the piece's own frame as the game has it (glTF: y up, -z its front), metres, with a
               lens of LENS mm (default 35). Written to OUT-NAME.png like the others.
--views a,b    only the views named, of the five or of those given with --view.
--span M       frames the model as if it were M metres across, so that two pieces of different sizes can be set
               side by side at one scale.
--heights Z0,Z1  looks at the part of the model between two heights (a lamp post's lantern, its foot).
--light NAME   with --lit: Blender's studio light (Default; paint.sl darkens a pale colour least)."""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], Path(argv[1])
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 512
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
textured = False
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf and bsdf.inputs["Base Color"].is_linked:
        node = bsdf.inputs["Base Color"].links[0].from_node
        while node.type != "TEX_IMAGE" and node.inputs and any(i.is_linked for i in node.inputs):
            node = next(i for i in node.inputs if i.is_linked).links[0].from_node
        if node.type == "TEX_IMAGE":
            m.node_tree.nodes.active = node
            textured = True
pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
mid, span = (lo + hi) / 2, max(hi - lo)
if "--heights" in argv:
    z0, z1 = (float(v) for v in argv[argv.index("--heights") + 1].split(","))
    near = [o.matrix_world @ v.co for o in meshes for v in o.data.vertices if z0 <= (o.matrix_world @ v.co).z <= z1]
    lo = Vector((min(p.x for p in near), min(p.y for p in near), z0))
    hi = Vector((max(p.x for p in near), max(p.y for p in near), z1))
    mid, span = (lo + hi) / 2, max(hi - lo)
if "--span" in argv:
    span = float(argv[argv.index("--span") + 1])
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO" if "--lit" in argv else "FLAT"          # --lit: shaded, to see form on a piece of one colour
if "--lit" in argv and "--light" in argv:
    scene.display.shading.studio_light = argv[argv.index("--light") + 1]
textured = any(m.use_nodes and any(n.type == "TEX_IMAGE" for n in m.node_tree.nodes) for m in bpy.data.materials)
painted = any(len(o.data.color_attributes) for o in meshes)
how = argv[argv.index("--colour") + 1] if "--colour" in argv else ("texture" if textured else "vertex" if painted else "material")
scene.display.shading.color_type = {"texture": "TEXTURE", "vertex": "VERTEX", "material": "MATERIAL"}[how]
scene.display.shading.show_backface_culling = False
scene.render.resolution_x = scene.render.resolution_y = size
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w"); scene.world = world
world.use_nodes = False; world.color = (0.55, 0.57, 0.6)
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data); scene.collection.objects.link(cam); scene.camera = cam


def aim(pos, at):
    cam.location = pos
    cam.rotation_euler = (Vector(at) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()


d = span * 1.9
side = -1.0 if "--from-behind" in argv else 1.0          # a piece turned to face the kit's way shows its back to the usual camera
views = [("front", (mid.x, mid.y - side * d, mid.z), mid), ("quarter", (mid.x + d * 0.62, mid.y - side * d * 0.62, mid.z + d * 0.5), mid),
         ("side", (mid.x + d, mid.y, mid.z), mid),
         ("eye", (mid.x, mid.y - span * 0.75, lo.z + span * 0.133), (mid.x, mid.y, lo.z + (hi.z - lo.z) * 0.6)),
         ("above", (mid.x, mid.y - 0.001, mid.z + d), mid)]
cam_data.lens = 50
lenses = {"eye": 24}
asked = [argv[i + 1] for i, a in enumerate(argv) if a == "--view"]
if asked:
    views = []
    for item in asked:
        label, numbers = item.split("=", 1)
        v = [float(x) for x in numbers.split(",")]
        views.append((label, (v[0], -v[2], v[1]), (v[3], -v[5], v[4])))          # glTF (x, y up, z) -> Blender (x, -z, y)
        lenses[label] = v[6] if len(v) > 6 else 35
paths = []
if "--views" in argv:
    wanted = argv[argv.index("--views") + 1].split(",")
    views = [v for v in views if v[0] in wanted]
for name, pos, at in views:
    cam_data.lens = lenses.get(name, 50)
    aim(pos, at)
    scene.render.filepath = str(out.with_name(f"{out.stem}-{name}.png"))
    bpy.ops.render.render(write_still=True)
    paths.append(scene.render.filepath)
print("LOOK " + " ".join(paths))
