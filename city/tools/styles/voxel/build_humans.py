"""Builds the voxel human on the shared rig: human.glb (Blender).

blender --background --factory-startup --python-exit-code 1 \\
    --python city/tools/styles/voxel/build_humans.py -- [--out DIR]

The voxel parts (humans.parts) are meshed per bone with voxel.mesh, turned
into one Blender object per recolourable role (skin, top, bottom, shoes,
details, hair_0..hair_3, hat_sun, backpack), each vertex weighted 1.0 to
its bone, skinned to `rig_human` from city/tools/styles/lowpoly/
characters.py, given that module's walk, sit, idle and typing actions
(fitted to the rig's joints) and exported with lowpoly lib.export, which
the pinned validator accepts. One character per scene, as the rig module
asks (a second rig would get `walk.001`).
"""
import sys
from pathlib import Path

import bmesh
import bpy

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(1, str(HERE.parent / "lowpoly"))
import humans  # noqa: E402
import palette  # noqa: E402
import voxel  # noqa: E402
import characters  # noqa: E402  (lowpoly: the shared rig and actions)
import lib  # noqa: E402  (lowpoly: reset and export)

DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "voxel" / "assets" / "v2"
# Roles meshed together per bone (faces between them are hidden) and the
# object each goes to; the optional objects are meshed on their own.
BODY = {"skin": "skin", "top": "top", "bottom": "bottom", "shoes": "shoes",
        "eye": "details", "mouth": "details", "belt": "details"}
OPTIONAL = ["hair_0", "hair_1", "hair_2", "hair_3", "hat_sun", "backpack"]


def material(role):
    """A matte material named after its role, in the role's default voxel
    palette colour (the pack recolours it)."""
    if role in bpy.data.materials:
        return bpy.data.materials[role]
    m = bpy.data.materials.new(role)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    rgb = [voxel.srgb_to_linear(c) for c in voxel.hex_rgb(palette.PALETTE[humans.DEFAULTS[role]])]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.85
    return m


def _add(store, name, key, meshes, bone):
    pos, _, idx = meshes[key]
    store.setdefault(name, []).append((key, bone, pos, idx))


def objects():
    """{object name: [(role, bone, positions, indices)]} in Godot axes."""
    every = humans.parts()
    store = {}
    for bone in humans.BONES:
        body = voxel.Grid(humans.HUMAN_VOXEL)
        for name in ("skin", "top", "bottom", "shoes", "details"):
            body.blit(every[bone][name])
        meshed = voxel.mesh(body)
        for key in sorted(meshed):
            _add(store, BODY[key], key, meshed, bone)
        for name in OPTIONAL:
            meshed = voxel.mesh(every[bone][name])
            for key in sorted(meshed):
                _add(store, name, key, meshed, bone)
    return store


def build(arm):
    out = {}
    for name in humans.OBJECTS:
        chunks = objects_cache[name]
        bm = bmesh.new()
        deform = bm.verts.layers.deform.verify()
        roles = []
        for role, bone, pos, idx in chunks:
            if role not in roles:
                roles.append(role)
            group = characters.BONES.index(bone)
            # Godot (x, y up, z south) -> Blender (x, -z, y): a rotation,
            # so the winding stays outward.
            verts = [bm.verts.new((x, -z, y)) for (x, y, z) in pos]
            for v in verts:
                v[deform][group] = 1.0
            for t in range(0, len(idx), 3):
                f = bm.faces.new((verts[idx[t]], verts[idx[t + 1]], verts[idx[t + 2]]))
                f.material_index = roles.index(role)
        me = bpy.data.meshes.new(name)
        bm.normal_update()
        bm.to_mesh(me)
        bm.free()
        for p in me.polygons:
            p.use_smooth = False
        for role in roles:
            me.materials.append(material(role))
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        for bone in characters.BONES:
            obj.vertex_groups.new(name=bone)
        characters.bind(obj, arm)
        out[name] = obj
    return out


objects_cache = {}


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = Path(argv[argv.index("--out") + 1]) if "--out" in argv else DEFAULT_OUT
    out.mkdir(parents=True, exist_ok=True)
    objects_cache.update(objects())
    lib.reset()
    arm = characters.build_rig("human")
    build(arm)
    characters.add_actions(arm, "human")
    lib.export(out / "human.glb", animations=True)
    print(f"voxel: wrote human.glb ({lib.triangles()} triangles)")


main()
