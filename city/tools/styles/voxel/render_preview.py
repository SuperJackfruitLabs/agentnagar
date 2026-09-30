"""Renders each voxel kit GLB from the sheets' diagonal (and optionally the
opposite side) into previews/<name>.png (gitignored), for review beside the
02-voxel sheets. Run contact_sheet.py afterwards for previews/sheet.png.

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/voxel/render_preview.py -- [--back] [--humans] [NAME_PREFIX ...]

--humans renders the static review humans (humans.static) instead;
--poses renders the skinned human.glb at four phases of each action
(previews/human_<action>_<k>.png), with hair_1 and no accessories.
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import stage  # noqa: E402
import humans  # noqa: E402
import palette  # noqa: E402
import voxel  # noqa: E402

ASSETS = HERE.parents[2] / "godot" / "styles" / "voxel" / "assets" / "v2"
OUT = HERE / "previews"
SIZE = 480


def frame(back):
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in bpy.context.scene.objects:
        if o.type == "MESH" and o.name != "ground":
            for corner in o.bound_box:
                w = o.matrix_world @ Vector(corner)
                lo = Vector(map(min, lo, w))
                hi = Vector(map(max, hi, w))
    ground = bpy.data.objects.get("ground")
    if ground is not None:
        ground.location.z = min(lo.z, 0.0) - 0.01
    centre = (lo + hi) / 2
    radius = max((hi - lo).length / 2, 0.3)
    # Blender axes: Godot -z (a piece's front) is Blender +y, so the default
    # view looks at the front from the front-left and above.
    direction = Vector((-0.8, 1.0, 0.85) if not back else (0.8, -1.0, 0.85)).normalized()
    stage.camera(centre + direction * radius * 3.0, centre, lens=50)


def poses():
    for action in ("walk", "idle", "sit", "typing"):
        for k in range(4):
            stage.reset()
            for a in list(bpy.data.actions):
                bpy.data.actions.remove(a)
            stage.setup(SIZE, SIZE)
            stage.ground(200)
            bpy.ops.import_scene.gltf(filepath=str(ASSETS / "human.glb"))
            for o in list(bpy.context.scene.objects):
                if o.name.split(".")[0] in ("hair_0", "hair_2", "hair_3", "hat_sun", "backpack"):
                    o.hide_render = True
            arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
            act = bpy.data.actions[action]
            arm.animation_data_create().action = act
            start, end = act.frame_range
            bpy.context.scene.frame_set(int(start + (end - start) * k / 4))
            frame(False)
            bpy.context.scene.render.filepath = str(OUT / f"human_{action}_{k}.png")
            bpy.ops.render.render(write_still=True)
            print(f"preview: human {action} {k}")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if "--poses" in argv:
        OUT.mkdir(exist_ok=True)
        poses()
        return
    back = "--back" in argv
    source = ASSETS
    if "--humans" in argv:
        source = OUT / "humans"
        source.mkdir(parents=True, exist_ok=True)
        for v in humans.VARIANTS:
            a = humans.static(v)
            (source / f"{a.name}.glb").write_bytes(voxel.glb_bytes(a.name, a.meshes(), palette.PALETTE, palette.PROPS))
    argv = [a for a in argv if a not in ("--back", "--humans")]
    OUT.mkdir(exist_ok=True)
    names = sorted(p.stem for p in source.glob("*.glb"))
    if argv:
        names = [n for n in names if any(n.startswith(a) for a in argv)]
    for name in names:
        stage.reset()
        stage.setup(SIZE, SIZE)
        stage.ground(200)
        bpy.ops.import_scene.gltf(filepath=str(source / f"{name}.glb"))
        frame(back)
        suffix = "_back" if back else ""
        bpy.context.scene.render.filepath = str(OUT / f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)
        print(f"preview: {name}")


main()
