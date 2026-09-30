from pathlib import Path
import bpy
import bmesh
import json

scene=bpy.context.scene
assert scene.name=='SJL Humanoid Study'
reports=[]
for name in ['L hand | sculpted','R hand | sculpted']:
    hand=bpy.data.objects[name]
    mesh=bmesh.new();mesh.from_mesh(hand.data)
    unseen=set(mesh.verts);components=0
    while unseen:
        components+=1
        stack=[unseen.pop()]
        while stack:
            current=stack.pop()
            for edge in current.link_edges:
                other=edge.other_vert(current)
                if other in unseen:
                    unseen.remove(other);stack.append(other)
    nonmanifold=sum(not edge.is_manifold for edge in mesh.edges)
    mesh.free()
    assert components==1,(name,components)
    assert nonmanifold==0,(name,nonmanifold)
    reports.append({'name':name,'connected_components':components,'nonmanifold_edges':nonmanifold})
scene.render.filepath=str(Path(OUTPUT_DIR) / 'humanoid-v2.png')
bpy.ops.wm.save_as_mainfile(filepath=str(Path(OUTPUT_DIR) / 'humanoid-v2.blend'),copy=True)
if globals().get('RENDER_PREVIEWS', True):
    bpy.ops.render.render(write_still=True)
print(json.dumps({'hands':reports,'render':scene.render.filepath}))
