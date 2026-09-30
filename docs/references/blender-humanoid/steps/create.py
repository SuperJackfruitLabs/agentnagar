from pathlib import Path
import bpy
import math
import json
from mathutils import Vector

assert bpy.data.scenes.get('SJL Humanoid Study') is None, 'Study already exists'
previous = bpy.context.scene
original_objects = {o.name: [list(row) for row in o.matrix_world] for o in previous.objects}
scene = bpy.data.scenes.new('SJL Humanoid Study')
bpy.context.window.scene = scene
character = bpy.data.collections.new('Humanoid | Maker 01')
scene.collection.children.link(character)
studio = bpy.data.collections.new('Studio')
scene.collection.children.link(studio)

def material(name, color, roughness=0.6, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = roughness
    p.inputs['Metallic'].default_value = metallic
    return m

skin = material('Maker | warm clay skin', (0.61, 0.31, 0.17))
suit = material('Maker | deep teal cloth', (0.035, 0.26, 0.27))
trim = material('Maker | sea glass trim', (0.16, 0.52, 0.48))
boot = material('Maker | charcoal boots', (0.035, 0.055, 0.065))
hair = material('Maker | dark hair', (0.045, 0.022, 0.015))
ivory = material('Maker | warm ivory', (0.89, 0.87, 0.73))
ink = material('Maker | eyes', (0.008, 0.014, 0.016), 0.28)
orange = material('Maker | orange badge', (0.98, 0.29, 0.055))
base_mat = material('Studio | blue slate', (0.10, 0.17, 0.20))
floor_mat = material('Studio | background', (0.035, 0.06, 0.08))

def finish(obj, name, mat, collection=character):
    obj.name = name
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    collection.objects.link(obj)
    obj.data.materials.append(mat)
    if obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj

def ellipsoid(name, loc, scale, mat, segments=24, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat)

def box(name, loc, scale, mat, bevel=0.025, collection=character):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, mat, collection)
    if bevel:
        mod = obj.modifiers.new('Soft edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
    return obj

def limb(name, a, b, radius_a, radius_b, mat):
    a, b = Vector(a), Vector(b)
    direction = b-a
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius_a, radius2=radius_b,
        depth=direction.length, location=(a+b)/2)
    obj = bpy.context.object
    obj.rotation_mode='QUATERNION'
    obj.rotation_quaternion=direction.to_track_quat('Z','Y')
    finish(obj,name,mat)
    mod=obj.modifiers.new('Rounded seams','BEVEL')
    mod.width=min(radius_a,radius_b)*0.32
    mod.segments=3
    obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return obj

def line(name, pts, radius, mat):
    curve=bpy.data.curves.new(name,'CURVE')
    curve.dimensions='3D'
    curve.bevel_depth=radius
    curve.bevel_resolution=3
    spline=curve.splines.new('BEZIER')
    spline.bezier_points.add(len(pts)-1)
    for point,loc in zip(spline.bezier_points,pts):
        point.co=loc
        point.handle_left_type='AUTO'
        point.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve)
    character.objects.link(obj)
    curve.materials.append(mat)
    return obj

# Rounded torso with a narrowing waist.
vertices=[]
levels=[(1.02,.165,.105),(1.20,.20,.125),(1.42,.235,.12),(1.49,.145,.095)]
for z,w,d in levels:
    vertices.extend([(-w,-d,z),(w,-d,z),(w,d,z),(-w,d,z)])
faces=[(3,2,1,0)]
for level in range(3):
    for j in range(4):
        a=level*4+j; b=level*4+(j+1)%4
        faces.append((a,b,b+4,a+4))
faces.append((12,13,14,15))
mesh=bpy.data.meshes.new('Tapered torso mesh')
mesh.from_pydata(vertices,[],faces)
mesh.update()
torso=bpy.data.objects.new('Torso | jacket',mesh)
character.objects.link(torso)
mesh.materials.append(suit)
bev=torso.modifiers.new('Tailored rounded edges','BEVEL'); bev.width=.05; bev.segments=4
torso.modifiers.new('Weighted normals','WEIGHTED_NORMAL')

ellipsoid('Hips', (0,0,.99),(.185,.12,.145),suit)
box('Belt',(0,-.002,1.045),(.35,.22,.055),boot,.018)
box('Belt buckle',(0,-.126,1.045),(.068,.022,.052),orange,.008)
limb('Neck',(0,0,1.46),(0,0,1.61),.065,.07,skin)
ellipsoid('Collar',(0,0,1.48),(.113,.094,.047),trim)
box('Jacket zip',(0,-.133,1.28),(.013,.012,.32),ivory,.004)
box('Chest pocket',(.125,-.137,1.335),(.108,.018,.105),trim,.012)
box('Maker badge',(.125,-.15,1.365),(.055,.011,.027),orange,.004)

for side,label in [(-1,'R'),(1,'L')]:
    hip=(side*.105,0,.96); knee=(side*.13,0,.58); ankle=(side*.14,0,.22)
    limb(label+' thigh',knee,hip,.089,.105,suit)
    ellipsoid(label+' knee',knee,(.086,.088,.086),suit)
    limb(label+' shin',ankle,knee,.063,.079,suit)
    box(label+' knee patch',(side*.13,-.078,.60),(.12,.027,.15),trim,.027)
    box(label+' boot',(side*.14,-.047,.135),(.155,.29,.19),boot,.045)
    box(label+' sole',(side*.14,-.049,.052),(.166,.305,.042),ivory,.016)
    box(label+' boot strap',(side*.14,-.108,.20),(.15,.035,.038),orange,.01)
    shoulder=(side*.235,0,1.40); elbow=(side*.395,-.008,1.18); wrist=(side*.48,-.012,.98)
    ellipsoid(label+' shoulder',shoulder,(.098,.101,.105),suit)
    limb(label+' upper arm',elbow,shoulder,.069,.088,suit)
    ellipsoid(label+' elbow',elbow,(.068,.073,.070),trim)
    limb(label+' forearm',wrist,elbow,.047,.063,suit)
    limb(label+' cuff',(side*.464,-.012,1.02),wrist,.054,.052,ivory)
    palm=Vector((side*.505,-.014,.925))
    hand=ellipsoid(label+' hand',palm,(.056,.035,.075),skin)
    hand.rotation_euler[1]=side*.28
    for i,length in enumerate([.069,.085,.079,.062]):
        x=side*(.466+i*.022)
        a=(x,-.022,.891); b=(x+side*.022,-.032,.891-length)
        limb(label+' finger '+str(i+1),a,b,.013,.010,skin)
        ellipsoid(label+' fingertip '+str(i+1),b,(.010,.012,.013),skin,16,8)
    limb(label+' thumb',(side*.468,-.015,.946),(side*.442,-.045,.888),.021,.015,skin)

ellipsoid('Head',(0,-.006,1.754),(.205,.173,.225),skin,32,24)
for side,label in [(-1,'R'),(1,'L')]:
    ellipsoid(label+' ear',(side*.203,.004,1.76),(.038,.032,.06),skin)
    ellipsoid(label+' eye white',(side*.076,-.163,1.797),(.046,.021,.038),ivory)
    ellipsoid(label+' pupil',(side*.076,-.182,1.798),(.022,.010,.026),ink)
    ellipsoid(label+' eye glint',(side*.071,-.191,1.808),(.006,.004,.008),ivory,16,8)
    line(label+' eyebrow',[(side*.04,-.168,1.851),(side*.074,-.174,1.86),(side*.11,-.16,1.854)],.012,hair)
ellipsoid('Nose',(0,-.177,1.749),(.033,.052,.038),skin)
line('Smile',[(-.057,-.164,1.700),(0,-.184,1.685),(.057,-.164,1.700)],.007,hair)
ellipsoid('Hair cap',(0,.012,1.917),(.207,.177,.087),hair,32,16)
ellipsoid('Hair sweep',(-.055,-.092,1.91),(.16,.09,.075),hair)
for side in [-1,1]:
    ellipsoid('Sideburn '+str(side),(side*.184,.015,1.84),(.026,.085,.075),hair)

# A separate studio, so the model remains easy to select and reuse.
bpy.ops.mesh.primitive_cylinder_add(vertices=96, radius=.88, depth=.075, location=(0,0,-.018))
platform=finish(bpy.context.object,'Display plinth',base_mat,studio)
bev=platform.modifiers.new('Plinth edge','BEVEL'); bev.width=.022; bev.segments=3
box('Studio floor',(0,0,-.092),(200,200,.04),floor_mat,0,studio)

world=bpy.data.worlds.new('Humanoid studio world'); world.use_nodes=True
world.node_tree.nodes['Background'].inputs['Color'].default_value=(.13,.18,.23,1)
world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
scene.world=world

def aim(obj,target):
    obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

for name,loc,power,size,color in [
    ('Key softbox',(3,-4,5),550,4,(1,.86,.71)),
    ('Fill softbox',(-3,-2,3),350,3,(.64,.86,1)),
    ('Rim softbox',(1,3,4),750,3,(.63,1,.93))]:
    data=bpy.data.lights.new(name,'AREA'); data.energy=power; data.shape='DISK'; data.size=size; data.color=color
    obj=bpy.data.objects.new(name,data); studio.objects.link(obj); obj.location=loc; aim(obj,(0,0,1))
camdata=bpy.data.cameras.new('Portrait camera'); camdata.type='ORTHO'; camdata.ortho_scale=2.65
camera=bpy.data.objects.new('Portrait camera',camdata); studio.objects.link(camera)
camera.location=(3.2,-6,2.8); aim(camera,(0,0,1.02)); scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=900; scene.render.resolution_y=1000; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.render.filepath=str(Path(OUTPUT_DIR) / 'humanoid.png')
scene.view_settings.view_transform='AgX'
for obj in scene.objects:
    obj.select_set(False)
torso.select_set(True); bpy.context.view_layer.objects.active=torso
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.overlay.show_overlays=False
            area.spaces.active.shading.type='MATERIAL'
assert {o.name:[list(row) for row in o.matrix_world] for o in previous.objects}==original_objects
scene['model_description']='Stylized humanoid maker, unrigged modeling study, created through Blender MCP'
scene['original_scene_preserved']=previous.name
bpy.ops.wm.save_as_mainfile(filepath=str(Path(OUTPUT_DIR) / 'humanoid.blend'),copy=True)
print(json.dumps({'scene':scene.name,'character_objects':len(character.objects),'original_scene':previous.name,'original_objects_preserved':True}))
