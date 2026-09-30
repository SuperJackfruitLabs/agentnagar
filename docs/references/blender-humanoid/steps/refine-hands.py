from pathlib import Path
import bpy
import math
import json
from mathutils import Vector, Matrix

scene=bpy.context.scene
assert scene.name=='SJL Humanoid Study'
assert bpy.data.collections.get('Hands | Refined') is None, 'Refined hands already exist'
character=bpy.data.collections['Humanoid | Maker 01']
archive=bpy.data.collections.new('Hands | Original archived')
scene.collection.children.link(archive)
archive.hide_render=True
archive.hide_viewport=True
names=[]
for side in ['L','R']:
    names += [side+' hand',side+' thumb']
    names += [side+' finger '+str(i) for i in range(1,5)]
    names += [side+' fingertip '+str(i) for i in range(1,5)]
for name in names:
    obj=bpy.data.objects.get(name)
    assert obj is not None,name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    archive.objects.link(obj)
new=bpy.data.collections.new('Hands | Refined')
character.children.link(new)
skin=bpy.data.materials['Maker | warm clay skin']

def attach(obj):
    for coll in list(obj.users_collection):
        coll.objects.unlink(obj)
    new.objects.link(obj)
    obj.data.materials.append(skin)
    for poly in obj.data.polygons:
        poly.use_smooth=True
    return obj

hands=[]
for side,label in [(-1,'R'),(1,'L')]:
    origin=Vector((side*.48,-.012,.98))
    down=Vector((side*.39,0,-.921)).normalized()
    across=Vector((side*.921,0,.39)).normalized()
    front=Vector((0,-1,0))
    rotation=Matrix((across,front,down)).transposed().to_quaternion()
    # Mirror via the coordinate mapping; use a proper rotation for the ellipsoids.
    if side<0:
        rotation=Matrix((-across,front,down)).transposed().to_quaternion()
    pieces=[]
    def point(u,v,w):
        return origin+across*u+front*v+down*w
    def ball(name,uvw,scale):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=point(*uvw))
        obj=attach(bpy.context.object); obj.name=label+' '+name
        obj.scale=scale
        obj.rotation_mode='QUATERNION';obj.rotation_quaternion=rotation
        pieces.append(obj)
        return obj
    def segment(name,a,b,ra,rb):
        a,b=point(*a),point(*b)
        direction=b-a
        bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=ra,radius2=rb,depth=direction.length,location=(a+b)/2)
        obj=attach(bpy.context.object);obj.name=label+' '+name
        obj.rotation_mode='QUATERNION';obj.rotation_quaternion=direction.to_track_quat('Z','Y')
        pieces.append(obj)
    ball('palm',(0,0,.051),(.045,.025,.059))
    ball('wrist',(0,0,.007),(.032,.024,.027))
    ball('thumb pad',(-.031,.006,.049),(.024,.024,.035))
    for name,u,length,radius,spread in [
        ('index',-.032,.073,.0125,-.009),
        ('middle',-.007,.085,.013,0),
        ('ring',.018,.077,.012,.004),
        ('little',.040,.059,.010,.010)]:
        root=(u,0,.086)
        middle=(u+spread*.5,.004,.086+length*.53)
        tip=(u+spread,.019,.086+length)
        ball(name+' knuckle',root,(radius*1.10,radius*1.1,radius*1.1))
        segment(name+' proximal',root,middle,radius,radius*.92)
        ball(name+' joint',middle,(radius*.94,radius*.94,radius*.94))
        segment(name+' distal',middle,tip,radius*.92,radius*.77)
        ball(name+' tip',tip,(radius*.79,radius*.79,radius*.85))
    a=(-.033,.003,.039); b=(-.064,.013,.063); c=(-.074,.027,.094)
    segment('thumb base',a,b,.021,.016)
    ball('thumb joint',b,(.017,.017,.019))
    segment('thumb end',b,c,.016,.0125)
    ball('thumb tip',c,(.013,.013,.015))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in pieces:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=pieces[0]
    bpy.ops.object.join()
    hand=bpy.context.object
    hand.name=label+' hand | sculpted'
    bpy.ops.object.transform_apply(location=False,rotation=True,scale=True)
    remesh=hand.modifiers.new('Unified palm and fingers','REMESH')
    remesh.mode='VOXEL';remesh.voxel_size=.0018
    remesh.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    smooth=hand.modifiers.new('Soften finger transitions','SMOOTH')
    smooth.factor=.6;smooth.iterations=3
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    sub=hand.modifiers.new('Hand surface','SUBSURF');sub.levels=1;sub.render_levels=1
    for poly in hand.data.polygons:
        poly.use_smooth=True
    hand['design']='Unified stylized palm, opposed thumb, four tapered relaxed fingers'
    hands.append(hand)
bpy.ops.object.select_all(action='DESELECT')
for hand in hands:
    hand.select_set(True)
bpy.context.view_layer.objects.active=hands[-1]
scene['hand_revision']=2
bpy.ops.wm.save_as_mainfile(filepath=str(Path(OUTPUT_DIR) / 'humanoid-v2.blend'),copy=True)
print(json.dumps({'hands':[{'name':h.name,'vertices':len(h.data.vertices)} for h in hands],'original_hands_archived':True}))
