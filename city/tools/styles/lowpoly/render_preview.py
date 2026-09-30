"""Renders review previews of the kit's GLBs: each asset imported alone,
framed from the front three-quarter view under a warm sun, written to
previews/<name>.png (gitignored), then a contact sheet, previews/sheet.png.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/lowpoly/render_preview.py -- [OPTIONS] [NAME_PREFIX ...]

Options, for animated and switchable assets (the file name records them):
    --action NAME --frame N   pose the asset at frame N (24 fps) of an action
    --hide A,B                hide the objects named A, B (e.g. other hairs)
    --yaw DEG                 orbit the camera DEG degrees about the asset
    --pitch DEG               camera elevation in degrees (default 27)
    --size PX                 image size (e.g. 64 for a game-distance check)
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import lib  # noqa: E402

ASSETS = HERE.parents[2] / "godot" / "styles" / "lowpoly_tropical" / "assets"
OUT = HERE / "previews"
SIZE = 480


def stage():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = SIZE
    scene.render.resolution_y = SIZE
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Base Contrast"
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.72, 0.86, 1)
    bg.inputs["Strength"].default_value = 0.9
    scene.world = world
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.2
    sun.color = (1.0, 0.9, 0.76)
    sun.angle = math.radians(3)
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(so)
    ground = lib.Mesh()
    ground.box((200, 200, 0.02), (0, 0, -0.011), "paving_light")
    ground.build("ground")


def frame(yaw=0.0, pitch=None):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name != "ground" and not o.hide_render and o.visible_get():
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.3)
    cam = bpy.data.cameras.new("cam")
    cam.lens = 50
    co = bpy.data.objects.new("cam", cam)
    bpy.context.scene.collection.objects.link(co)
    direction = Vector((0.75, 1.1, 0.7)).normalized()
    if pitch is not None:
        flat = Vector((direction.x, direction.y, 0)).normalized()
        direction = (flat * math.cos(math.radians(pitch)) + Vector((0, 0, math.sin(math.radians(pitch))))).normalized()
    direction = Matrix.Rotation(math.radians(yaw), 3, "Z") @ direction
    co.location = centre + direction * radius * 3.1
    co.rotation_euler = (centre - co.location).to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = co


def options(argv):
    """Splits `--key value` options from name prefixes."""
    opts, rest = {}, []
    k = 0
    while k < len(argv):
        if argv[k].startswith("--"):
            opts[argv[k][2:]] = argv[k + 1]
            k += 2
        else:
            rest.append(argv[k])
            k += 1
    return opts, rest


def pose(opts):
    """Hides the named objects and poses every armature at a frame of an
    action; returns the file-name suffix recording what was done, or None
    when the asset has no such action."""
    suffix = ""
    hidden = [n for n in opts.get("hide", "").split(",") if n]
    for o in bpy.context.scene.objects:
        if o.name.split(".")[0] in hidden:
            o.hide_render = True
    if "action" in opts:
        name = opts["action"]
        act = next((a for a in bpy.data.actions if a.name == name or a.name.startswith(name + "_")), None)
        if act is None:
            return None
        for o in bpy.context.scene.objects:
            if o.type == "ARMATURE":
                ad = o.animation_data_create()
                for t in ad.nla_tracks:
                    t.mute = True
                ad.action = act
                if hasattr(ad, "action_slot") and len(act.slots):
                    ad.action_slot = act.slots[0]
        bpy.context.scene.render.fps = 24
        frame_no = int(opts.get("frame", 0))
        bpy.context.scene.frame_set(frame_no)
        suffix += f"@{name}{frame_no}"
    if "yaw" in opts:
        suffix += f"_y{opts['yaw']}"
    if "pitch" in opts:
        suffix += f"_p{opts['pitch']}"
    if "size" in opts:
        suffix += f"_s{opts['size']}"
    if hidden:
        suffix += "_h" + "-".join(hidden)
    return suffix


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opts, argv = options(argv)
    if "size" in opts:
        global SIZE
        SIZE = int(opts["size"])
    OUT.mkdir(exist_ok=True)
    names = sorted(p.stem for p in ASSETS.glob("*.glb"))
    if argv:
        names = [n for n in names if any(n.startswith(a) for a in argv)]
    for name in names:
        lib.reset()
        for w in list(bpy.data.worlds):
            bpy.data.worlds.remove(w)
        stage()
        bpy.ops.import_scene.gltf(filepath=str(ASSETS / f"{name}.glb"))
        suffix = pose(opts)
        if suffix is None:
            print(f"preview: {name} has no action {opts['action']}; skipped")
            continue
        frame(float(opts.get("yaw", 0)), float(opts["pitch"]) if "pitch" in opts else None)
        bpy.context.scene.render.filepath = str(OUT / f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)
        print(f"preview: {name}")


main()
