from pathlib import Path
import bpy
import math
import json
from mathutils import Vector

source=bpy.data.scenes['SJL Humanoid Study']
assert bpy.data.scenes.get('SJL Humanoid | Rigged') is None, 'Rigged scene already exists'
scene=bpy.data.scenes.new('SJL Humanoid | Rigged')
bpy.context.window.scene=scene
scene.world=source.world.copy()
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.render.fps=24;scene.frame_start=1;scene.frame_end=96
scene.view_settings.view_transform='AgX'
character=bpy.data.collections.new('Rigged Maker | Character');scene.collection.children.link(character)
studio=bpy.data.collections.new('Rigged Maker | Studio');scene.collection.children.link(studio)
objects={}
for old in bpy.data.collections['Humanoid | Maker 01'].all_objects:
    obj=old.copy();obj.data=old.data.copy();obj.name='Rigged | '+old.name
    character.objects.link(obj);objects[old.name]=obj
for old in bpy.data.collections['Studio'].all_objects:
    obj=old.copy();obj.data=old.data.copy();obj.name='Rigged | '+old.name
    studio.objects.link(obj)
    if old==source.camera:
        scene.camera=obj

# Mesh copies preserve the editable, unrigged study in its own scene.
for name,obj in list(objects.items()):
    if obj.type=='CURVE':
        bpy.ops.object.select_all(action='DESELECT');obj.select_set(True)
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
        objects[name]=bpy.context.object

data=bpy.data.armatures.new('Maker Skeleton')
rig=bpy.data.objects.new('Maker Rig',data);character.objects.link(rig)
rig.show_in_front=True;data.display_type='OCTAHEDRAL'
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None,deform=True):
    b=data.edit_bones.new(name);b.head=head;b.tail=tail;b.use_deform=deform
    if parent:
        b.parent=data.edit_bones[parent]
    return b
bone('root',(0,0,0),(0,0,.2),deform=False)
bone('pelvis',(0,0,.93),(0,0,1.06),'root')
bone('spine',(0,0,1.06),(0,0,1.30),'pelvis')
bone('chest',(0,0,1.30),(0,0,1.49),'spine')
bone('neck',(0,0,1.49),(0,0,1.60),'chest')
bone('head',(0,0,1.60),(0,0,1.96),'neck')
finger_specs=[('index',-.032,.073,-.009),('middle',-.007,.085,0),('ring',.018,.077,.004),('little',.040,.059,.010)]
hand_frames={}
for side,label in [(-1,'R'),(1,'L')]:
    shoulder=(side*.235,0,1.40);elbow=(side*.395,-.008,1.18);wrist=(side*.48,-.012,.98)
    bone('clavicle.'+label,(side*.06,0,1.42),shoulder,'chest')
    bone('upper_arm.'+label,shoulder,elbow,'clavicle.'+label)
    bone('forearm.'+label,elbow,wrist,'upper_arm.'+label)
    origin=Vector(wrist);down=Vector((side*.39,0,-.921)).normalized();across=Vector((side*.921,0,.39)).normalized();front=Vector((0,-1,0))
    hand_frames[label]=(origin,across,front,down)
    def point(u,v,w):return origin+across*u+front*v+down*w
    bone('hand.'+label,wrist,point(0,0,.10),'forearm.'+label)
    for name,u,length,spread in finger_specs:
        a=point(u,0,.086);b=point(u+spread*.5,.004,.086+length*.53);c=point(u+spread,.019,.086+length)
        bone(name+'.01.'+label,a,b,'hand.'+label)
        bone(name+'.02.'+label,b,c,name+'.01.'+label)
    bone('thumb.01.'+label,point(-.033,.003,.039),point(-.064,.013,.063),'hand.'+label)
    bone('thumb.02.'+label,point(-.064,.013,.063),point(-.074,.027,.094),'thumb.01.'+label)
    hip=(side*.105,0,.96);knee=(side*.13,0,.58);ankle=(side*.14,0,.22)
    bone('thigh.'+label,hip,knee,'pelvis')
    bone('shin.'+label,knee,ankle,'thigh.'+label)
    bone('foot.'+label,ankle,(side*.14,-.20,.10),'shin.'+label)
bpy.ops.object.mode_set(mode='OBJECT')

def rigid_bone(name):
    if name in ['Hips','Belt','Belt buckle']:return 'pelvis'
    if name=='Neck':return 'neck'
    if name in ['Torso | jacket','Collar','Jacket zip','Chest pocket','Maker badge']:return 'chest'
    if name[:2] in ['L ','R ']:
        side=name[0];part=name[2:]
        if part=='thigh':return 'thigh.'+side
        if part in ['shin','knee','knee patch']:return 'shin.'+side
        if part in ['boot','sole','boot strap']:return 'foot.'+side
        if part in ['shoulder','upper arm']:return 'upper_arm.'+side
        if part in ['forearm','elbow','cuff']:return 'forearm.'+side
    return 'head'

def clamp(x):return max(0,min(1,x))
def distance(p,a,b):
    delta=b-a;t=clamp((p-a).dot(delta)/delta.length_squared)
    return (p-(a+t*delta)).length

for name,obj in objects.items():
    assert obj.type=='MESH',(name,obj.type)
    mod=obj.modifiers.new('Maker skeletal deformation','ARMATURE');mod.object=rig
    obj.parent=rig
    if 'hand | sculpted' not in name:
        group=obj.vertex_groups.new(name=rigid_bone(name))
        group.add(list(range(len(obj.data.vertices))),1.0,'REPLACE')
        continue
    label=name[0];origin,across,front,down=hand_frames[label]
    group_names=['hand.'+label]+[n+suffix+'.'+label for n in ['index','middle','ring','little','thumb'] for suffix in ['.01','.02']]
    groups={n:obj.vertex_groups.new(name=n) for n in group_names}
    finger_bones={n:[data.bones[n+'.01.'+label],data.bones[n+'.02.'+label]] for n in ['index','middle','ring','little','thumb']}
    for vertex in obj.data.vertices:
        p=obj.matrix_world@vertex.co;relative=p-origin
        u=relative.dot(across);w=relative.dot(down)
        if w<.024:
            groups['hand.'+label].add([vertex.index],1,'REPLACE');continue
        digit=min(finger_bones,key=lambda n:min(distance(p,b.head_local,b.tail_local) for b in finger_bones[n]))
        if digit=='thumb':
            influence=clamp((-u-.031)/.026)
        else:
            influence=clamp((w-.079)/.022)
        proximal,distal=finger_bones[digit]
        direction=(distal.tail_local-proximal.head_local).normalized()
        joint=(p-distal.head_local).dot(direction)
        bend=clamp((joint+.010)/.020)
        weights={'hand.'+label:1-influence,digit+'.01.'+label:influence*(1-bend),digit+'.02.'+label:influence*bend}
        for g,weight in weights.items():
            if weight>0.000001:groups[g].add([vertex.index],weight,'REPLACE')

for name,obj in objects.items():
    assert all(abs(sum(g.weight for g in v.groups)-1)<.0001 for v in obj.data.vertices),name
rig['rig_notes']='FK segmented-character rig; smooth hand weights and two bones per digit. No IK or facial rig.'
rig['source_scene']=source.name
scene['rigged_meshes']=len(objects)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
for area in (area for screen in bpy.data.screens for area in screen.areas):
    if area.type=='VIEW_3D':
        area.spaces.active.region_3d.view_perspective='CAMERA'
        area.spaces.active.overlay.show_overlays=False
        area.spaces.active.shading.type='SOLID';area.spaces.active.shading.color_type='MATERIAL'
print(json.dumps({'scene':scene.name,'bones':len(data.bones),'bound_meshes':len(objects),'weights_normalized':True}))
