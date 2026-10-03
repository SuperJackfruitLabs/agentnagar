"""drawn.py MODEL.glb OUT.png [--shrub [--grow G]] [--bed L,D[,FIT]] [--size 480] [--flat] [--toon EL,AZ]: a planting piece
as the game draws it, shaded and in its colours, standing on a lawn: from a walker's eye (OUT-eye.png), from a
quarter above (OUT-quarter.png) and from straight above (OUT-above.png).

The game does not draw a planting piece as its file has it:

--shrub     as the pack plants a shrub (pack_3d.gd _planted_across, kit_town.gd mesh_of and band_reach): only
            the FIRST mesh of the file, its node's transform dropped, scaled across by 1.05 m over the farthest
            the whole file reaches from its origin between 0.15 and 2.2 m up, and in height by --grow (default
            1.0; the game grows each shrub by 0.85 to 1.19). The footprint's disc, 1.05 m, is a red line on the
            lawn.
--bed L,D[,FIT]  as the pack fits a bed (pack_3d.gd _fit_prop): the whole scene, stretched until what it draws
            between 0.15 and 2.2 m up is L by D metres (3.3,1.3 in the town) and set by the middle of that
            slice, its height as built; with FIT (the skin's module length: 2.0 in the voxel kit), in
            round(L / FIT) copies end to end. The rectangle is a red line on the lawn.
Without either the piece is drawn as its file has it.

Materials are drawn as the file has them: a colour texture, vertex colours (the kits' baked pieces), a flat
colour, leaf cards cut out by their texture's alpha, what glows glowing. The light is a sun and the sky, with
shadows (EEVEE); --flat shows the colours alone. A preview of form and colour: not the game's own shading (no
toon step, no ink line, no night).

--toon EL,AZ  the piece shaded as the anime pack's toon step shades it, as far as that can be said without the
            game: each point takes its painted colour where its normal faces the sun and the shadow tone (0.38 of
            red and green, 0.59 of blue, as measured in the game on the street trees) where it does not, with the
            step Godot's toon diffuse makes at roughness 0.32 (smoothstep from -0.32 to 0.32 of the cosine). The
            sun stands EL degrees up (the game's: 16 at dawn to 58 at noon) and AZ degrees round from behind the
            camera (0: behind the viewer; 180: behind the piece). The file's own normals are used, so this shows
            what turning them (--leaf-round, --leaf-lift) does. No cast shadows, no ink line, no rim.

Prints DRAWN and the three files, and SCALE with what the game's rule gave.
"""
import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
src, out = argv[0], Path(argv[1])
size = int(argv[argv.index("--size") + 1]) if "--size" in argv else 480
grow = float(argv[argv.index("--grow") + 1]) if "--grow" in argv else 1.0
bed = [float(v) for v in argv[argv.index("--bed") + 1].split(",")] if "--bed" in argv else None
BAND = (0.15, 2.2)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
roots = [o for o in bpy.data.objects if o.parent is None]


def world_points(o):
    v = np.empty(len(o.data.vertices) * 3)
    o.data.vertices.foreach_get("co", v)
    w = np.array(o.matrix_world)
    return v.reshape(-1, 3) @ w[:3, :3].T + w[:3, 3]


def band_points(objs):
    """kit_town.gd _band_points: vertices in the band and where edges cross its two heights, from above."""
    found = [np.zeros((0, 2))]
    for o in objs:
        v = world_points(o)
        found.append(v[(v[:, 2] >= BAND[0]) & (v[:, 2] <= BAND[1])][:, :2])
        e = np.empty(len(o.data.edges) * 2, dtype=np.int32)
        o.data.edges.foreach_get("vertices", e)
        a, b = v[e[0::2]], v[e[1::2]]
        rise = b[:, 2] - a[:, 2]
        for level in BAND:
            with np.errstate(divide="ignore", invalid="ignore"):
                f = (level - a[:, 2]) / rise
            ok = (rise != 0) & (f > 0) & (f < 1)
            found.append((a[ok] + (b[ok] - a[ok]) * f[ok][:, None])[:, :2])
    return np.concatenate(found)


# ---- Materials as the engine reads them: vertex colours multiply the colour where the mesh carries them ----
for o in meshes:
    if not len(o.data.color_attributes):
        continue
    for m in o.data.materials:
        if m is None or not m.use_nodes or m.get("vertex_colour_done"):
            continue
        m["vertex_colour_done"] = True
        tree = m.node_tree
        bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is None or any(n.type == "VERTEX_COLOR" for n in tree.nodes):
            continue
        colour = tree.nodes.new("ShaderNodeVertexColor")
        socket = bsdf.inputs["Base Color"]
        if socket.is_linked:
            mix = tree.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 1.0
            tree.links.new(socket.links[0].from_socket, mix.inputs["A"])
            tree.links.new(colour.outputs["Color"], mix.inputs["B"])
            tree.links.new(mix.outputs["Result"], socket)
        else:
            tree.links.new(colour.outputs["Color"], socket)
for m in bpy.data.materials:
    if m.use_nodes:
        bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf is not None and "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.08          # leaves and stone, not plastic

# ---- The piece as the game places it ----
line = None
drawn = meshes
if "--shrub" in argv:
    pts = band_points(meshes)
    reach = float(np.hypot(pts[:, 0], pts[:, 1]).max())
    order = []

    def walk(o):
        if o.type == "MESH":
            order.append(o)
        for c in sorted(o.children, key=lambda c: c.name):
            walk(c)
    for r in roots:
        walk(r)
    first = order[0]
    for o in list(bpy.data.objects):
        if o is not first:
            bpy.data.objects.remove(o, do_unlink=True)
    across = 1.05 / reach
    first.parent = None
    first.matrix_world = Matrix.Diagonal((across, across, grow, 1.0))
    drawn = [first]
    line = ("disc", 1.05)
    print(f"SCALE across {across:.3f} (reach {reach:.4f} m), up {grow:.2f}; first mesh {first.name}; {len(order)} mesh node(s) in the file")
elif bed:
    pts = band_points(meshes)
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    n = max(1, round(bed[0] / bed[2])) if len(bed) > 2 else 1
    sl, sd = bed[0] / n / (hi[0] - lo[0]), bed[1] / (hi[1] - lo[1])
    mid = (lo + hi) / 2
    holders = []
    for k in range(n):
        holder = bpy.data.objects.new(f"copy{k}", None)
        scene.collection.objects.link(holder)
        holder.scale = (sl, sd, 1.0)
        holder.location = (-bed[0] / 2 + (k + 0.5) * bed[0] / n - mid[0] * sl, -mid[1] * sd, 0.0)
        holders.append(holder)
    for r in roots:
        r.parent = holders[0]
    for k in range(1, n):
        for o in list(meshes):
            world = o.matrix_world.copy()
            c = o.copy()
            scene.collection.objects.link(c)
            c.parent = holders[k]
            c.matrix_parent_inverse = Matrix.Identity(4)
            c.matrix_basis = world
            drawn = drawn + [c]
    line = ("rect", bed[0], bed[1])
    print(f"SCALE along {sl:.3f}, deep {sd:.3f} (slice {hi[0] - lo[0]:.3f} by {hi[1] - lo[1]:.3f} m), {n} cop{'y' if n == 1 else 'ies'}")
bpy.context.view_layer.update()
corners = [o.matrix_world @ Vector(c) for o in drawn for c in o.bound_box]
lo3 = Vector((min(p.x for p in corners), min(p.y for p in corners), min(p.z for p in corners)))
hi3 = Vector((max(p.x for p in corners), max(p.y for p in corners), max(p.z for p in corners)))
wide = max(hi3.x - lo3.x, hi3.y - lo3.y, 0.5)
tall = hi3.z

# ---- The lawn, the footprint's line, the light ----
bpy.ops.mesh.primitive_plane_add(size=1.0, location=(0, 0, -0.003))
lawn = bpy.context.view_layer.objects.active
lawn.scale = (60, 60, 1)
lawn_mat = bpy.data.materials.new("lawn")
lawn_mat.use_nodes = True
lawn_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.36, 0.44, 0.25, 1)
lawn_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
lawn.data.materials.append(lawn_mat)
if line:
    line_mat = bpy.data.materials.new("line")
    line_mat.use_nodes = True
    line_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.85, 0.12, 0.10, 1)
    if line[0] == "disc":
        bpy.ops.mesh.primitive_torus_add(location=(0, 0, 0.003), major_radius=line[1], minor_radius=0.008, major_segments=128, minor_segments=4)
        bpy.context.view_layer.objects.active.data.materials.append(line_mat)
    else:
        for x, y, sx, sy in ((0, line[2] / 2, line[1], 0.016), (0, -line[2] / 2, line[1], 0.016), (line[1] / 2, 0, 0.016, line[2]), (-line[1] / 2, 0, 0.016, line[2])):
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, 0.002))
            bar = bpy.context.view_layer.objects.active
            bar.scale = (sx, sy, 0.006)
            bar.data.materials.append(line_mat)
if "--toon" in argv:
    el, az = (math.radians(float(v)) for v in argv[argv.index("--toon") + 1].split(","))
    to_sun = (-math.cos(el) * math.sin(az), -math.cos(el) * math.cos(az), math.sin(el))
    for o in drawn:
        for m in o.data.materials:
            if m is None or not m.use_nodes or m.get("toon_done"):
                continue
            m["toon_done"] = True
            tree = m.node_tree
            bsdf = next((n for n in tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            out_node = next((n for n in tree.nodes if n.type == "OUTPUT_MATERIAL"), None)
            if bsdf is None or out_node is None or bsdf.inputs["Emission Strength"].default_value > 0 and (bsdf.inputs["Emission Color"].is_linked or max(bsdf.inputs["Emission Color"].default_value[:3]) > 0):
                continue                                                  # what glows is left as it is
            geometry = tree.nodes.new("ShaderNodeNewGeometry")
            dot = tree.nodes.new("ShaderNodeVectorMath")
            dot.operation = "DOT_PRODUCT"
            dot.inputs[1].default_value = to_sun
            tree.links.new(geometry.outputs["Normal"], dot.inputs[0])
            step = tree.nodes.new("ShaderNodeMapRange")
            step.interpolation_type = "SMOOTHSTEP"
            step.inputs["From Min"].default_value, step.inputs["From Max"].default_value = -0.32, 0.32
            tree.links.new(dot.outputs["Value"], step.inputs["Value"])
            shade = tree.nodes.new("ShaderNodeMix")
            shade.data_type = "RGBA"
            shade.blend_type = "MULTIPLY"
            shade.inputs["Factor"].default_value = 1.0
            shade.inputs["B"].default_value = (0.38, 0.38, 0.59, 1.0)
            both = tree.nodes.new("ShaderNodeMix")
            both.data_type = "RGBA"
            socket = bsdf.inputs["Base Color"]
            if socket.is_linked:
                source = socket.links[0].from_socket
                tree.links.new(source, shade.inputs["A"])
                tree.links.new(source, both.inputs["B"])
            else:
                shade.inputs["A"].default_value = socket.default_value
                both.inputs["B"].default_value = socket.default_value
            tree.links.new(shade.outputs["Result"], both.inputs["A"])
            tree.links.new(step.outputs["Result"], both.inputs["Factor"])
            glow = tree.nodes.new("ShaderNodeEmission")
            tree.links.new(both.outputs["Result"], glow.inputs["Color"])
            tree.links.new(glow.outputs["Emission"], out_node.inputs["Surface"])
flat = "--flat" in argv
world = bpy.data.worlds.new("sky")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.60, 0.72, 0.90, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 3.0 if flat else 0.9
if not flat:
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = 3.2
    sun_data.angle = math.radians(2.0)
    sun = bpy.data.objects.new("sun", sun_data)
    scene.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = int(size * 1.6)
scene.render.resolution_y = size
scene.render.film_transparent = False
scene.view_settings.view_transform = "Standard"
cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam


def aim(pos, at):
    cam.location = pos
    cam.rotation_euler = (Vector(at) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()


back = wide * 1.25 + 1.6
views = [("eye", (0.0, -back, 1.7), (0, 0, 0.45 * tall), 35),
         ("quarter", (back * 0.62, -back * 0.72, back * 0.62), (0, 0, 0.3 * tall), 35),
         ("above", (0.0, -0.001, wide * 1.15 + 2.2), (0, 0, 0), 35)]
paths = []
for name, pos, at, lens in views:
    cam_data.lens = lens
    cam_data.type = "ORTHO" if name == "above" else "PERSP"          # from above without perspective: the outline against the red line is true
    cam_data.ortho_scale = max(wide * 1.25, 2.6) * 1.6
    aim(pos, at)
    scene.render.filepath = str(out.with_name(f"{out.stem}-{name}.png"))
    bpy.ops.render.render(write_still=True)
    paths.append(scene.render.filepath)
print("DRAWN " + " ".join(paths))
