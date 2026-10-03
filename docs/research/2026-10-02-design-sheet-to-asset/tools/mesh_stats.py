"""mesh_stats.py RAW.glb: how a generated mesh is built: parts, open edges, edges shared by more than two faces."""
import sys
import bpy, bmesh
raw = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=raw)
o = [x for x in bpy.data.objects if x.type == "MESH"][0]
bpy.context.view_layer.objects.active = o; o.select_set(True)
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT"); bpy.ops.mesh.remove_doubles(threshold=1e-6); bpy.ops.object.mode_set(mode="OBJECT")
bm = bmesh.new(); bm.from_mesh(o.data)
open_e = sum(1 for e in bm.edges if len(e.link_faces) == 1)
multi = sum(1 for e in bm.edges if len(e.link_faces) > 2)
wire = sum(1 for e in bm.edges if len(e.link_faces) == 0)
print(f"STATS verts {len(bm.verts)} faces {len(bm.faces)} edges {len(bm.edges)}: open {open_e}, shared by 3+ faces {multi}, wire {wire}")
