"""A Blender review stage for the voxel kit: clear sky, a warm sun with
crisp shadows, ambient occlusion, and the palette shown as authored
(Standard view transform), close to the 02-voxel sheets' bright daylight.
Used by render_preview.py and compose.py only (never by the build)."""
import math

import bpy
from mathutils import Vector


def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.objects, bpy.data.cameras,
                  bpy.data.lights, bpy.data.images, bpy.data.worlds, bpy.data.collections):
        for item in list(block):
            block.remove(item)


def setup(width, height, sun_yaw=205.0, sun_pitch=48.0):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = 0.0
    try:
        scene.eevee.use_shadows = True
        scene.eevee.shadow_ray_count = 2
        scene.eevee.shadow_step_count = 8
        scene.eevee.use_raytracing = True
        scene.eevee.fast_gi_method = "GLOBAL_ILLUMINATION"
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.42, 0.62, 0.86, 1)
    bg.inputs["Strength"].default_value = 0.7
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 2.9
    sun.color = (1.0, 0.95, 0.86)
    sun.angle = math.radians(1.5)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(90 - sun_pitch), 0, math.radians(sun_yaw))
    scene.collection.objects.link(so)


def ground(size, colour=(0.62, 0.62, 0.58)):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, -0.12))
    g = bpy.context.active_object
    g.name = "ground"
    mat = bpy.data.materials.new("ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*colour, 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    g.data.materials.append(mat)
    return g


def camera(location, target, lens=50, ortho=None):
    cam = bpy.data.cameras.new("cam")
    cam.lens = lens
    cam.clip_end = 2000
    if ortho:
        cam.type = "ORTHO"
        cam.ortho_scale = ortho
    co = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(co)
    co.location = location
    co.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co
    return co
