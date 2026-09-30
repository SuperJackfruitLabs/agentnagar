from pathlib import Path
import bpy
import math
import json
from mathutils import Quaternion,Vector
scene=bpy.context.scene
assert scene.name=='SJL Humanoid | Rigged'
rig=bpy.data.objects['Maker Rig']
assert not rig.animation_data,'Animation already exists'

def rotate(name,axis,angle):
    p=rig.pose.bones[name]
    p.rotation_mode='QUATERNION'
    local=rig.data.bones[name].matrix_local.to_quaternion().inverted()@Vector(axis)
    p.rotation_quaternion=Quaternion(local,math.radians(angle))

poses=[(1,0,0,0),(18,-78,-70,-8),(24,-80,-68,-10),
       (32,-80,-68,14),(40,-80,-68,-16),(48,-80,-68,14),
       (56,-80,-68,-16),(64,-80,-68,14),(72,-78,-70,-7),
       (90,0,0,0),(96,0,0,0)]
for frame,upper,forearm,wrist in poses:
    scene.frame_set(frame)
    for p in rig.pose.bones:
        p.rotation_mode='QUATERNION';p.rotation_quaternion=Quaternion()
        p.location=(0,0,0);p.scale=(1,1,1)
    rotate('upper_arm.L',(0,1,0),upper)
    rotate('forearm.L',(0,1,0),forearm)
    rotate('hand.L',(0,1,0),wrist)
    factor=min(1,abs(upper)/78)
    rotate('head',(0,1,0),-3*factor)
    for digit,angle in [('index',2),('middle',4),('ring',6),('little',8)]:
        rotate(digit+'.01.L',(.921,0,.39),-angle*factor)
        rotate(digit+'.02.L',(.921,0,.39),-angle*.5*factor)
    for p in rig.pose.bones:
        p.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=p.name)
rig.animation_data.action.name='Wave_Hello'
rig.animation_data.action.use_fake_user=True
scene.frame_set(40)
scene.render.filepath=str(Path(OUTPUT_DIR) / 'wave-pose.png')
bpy.ops.wm.save_as_mainfile(filepath=str(Path(OUTPUT_DIR) / 'humanoid-rigged.blend'),copy=True)
if globals().get('RENDER_PREVIEWS', True):
    bpy.ops.render.render(write_still=True)
props=bpy.ops.export_scene.gltf.get_rna_type().properties
print(json.dumps({'action':rig.animation_data.action.name,'frame_range':[1,96],'fps':24,'bones':len(rig.pose.bones),
    'gltf_animation_modes':[i.identifier for i in props['export_animation_mode'].enum_items]}))
