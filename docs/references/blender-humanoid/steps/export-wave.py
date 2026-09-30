import bpy,json
from pathlib import Path
root=Path(OUTPUT_DIR)
scene=bpy.context.scene
assert scene.name=='SJL Humanoid | Rigged'
rig=bpy.data.objects['Maker Rig']
bpy.ops.object.select_all(action='DESELECT')
for obj in bpy.data.collections['Rigged Maker | Character'].all_objects:
    obj.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active=rig
scene.frame_set(1)
bpy.ops.export_scene.gltf(filepath=str(root/'humanoid-wave.glb'),export_format='GLB',
    use_selection=True,use_active_scene=True,export_animations=True,export_animation_mode='ACTIONS',
    export_frame_range=True,export_force_sampling=True,export_apply=True,
    export_skins=True,export_cameras=False,export_lights=False)
scene.frame_set(40)
# Write only the two study scenes and dependencies. Saving the entire running
# application also captures file-browser paths and cached brush-library paths.
# A scene library is an ordinary editable .blend without that saved UI state.
studies={bpy.data.scenes['SJL Humanoid Study'],scene}
render_paths={s:s.render.filepath for s in studies}
try:
    for s in studies:
        s.render.filepath='//' + Path(s.render.filepath).name
    bpy.data.libraries.write(str(root/'humanoid-rigged.blend'),studies,
        path_remap='RELATIVE_ALL',fake_user=True,compress=True)
finally:
    for s,path in render_paths.items():
        s.render.filepath=path
print(json.dumps({'glb_bytes':(root/'humanoid-wave.glb').stat().st_size,'action':rig.animation_data.action.name}))
