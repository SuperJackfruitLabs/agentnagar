"""Fresh-process modular workshop build; pass -- --render for authoring images."""
import hashlib,json,sys,math
from pathlib import Path
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
from geometry import palette
from shared_workshop import kit,layout
ROOT=HERE.parent;OUT=ROOT/'godot/assets/workshop'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def select(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0]
def point(o,p):o.rotation_euler=(Vector(p)-o.location).to_track_quat('-Z','Y').to_euler()
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    assets,solids=kit(palette());d=layout(solids)
    (OUT/'layout.json').write_text(json.dumps(d,indent=2)+'\n')
    m={'revision':'shared-workshop-r004','blender':bpy.app.version_string,'units':'metres; GLB/Godot Y-up','references':{'city':'02-voxel/00-city-perspectives/r004','living':'02-voxel/01-living-community/r002'},'provenance':'Original procedural modular environment; unchanged existing robot/furniture GLBs imported for editable source presentation.','scope':'One shared workshop and bounded courtyard, sample data. No full district or production acceptance.','assets':{},'reused_assets':{}}
    for name,objs in assets.items():
        select(objs);p=OUT/(name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(p),export_format='GLB',use_selection=True,export_yup=True,export_animations=False,export_cameras=False,export_lights=False)
        m['assets'][name]={'file':str(p.relative_to(ROOT)),'bytes':p.stat().st_size,'sha256':sha(p),'source_vertices':sum(len(o.data.vertices) for o in objs)}
    originals=[o for objs in assets.values() for o in objs]
    for i in d['instances']:
        name=Path(i['asset']).stem
        root=bpy.data.objects.new(i['id'],None);bpy.context.collection.objects.link(root)
        x,y,z=i['position'];root.location=(x,-z,y);root.rotation_euler.z=math.radians(i['rotation_y']);root['group']=i['group']
        if name in assets:
            for template in assets[name]:
                obj=template.copy();obj.data=template.data;bpy.context.collection.objects.link(obj);obj.parent=root
        else:
            # Reserved-bay furniture reuses existing robot/furniture GLBs from
            # godot/assets/, imported unmodified for authoring presentation only.
            p=ROOT/'godot/assets'/(name+'.glb');m['reused_assets'][name]=sha(p)
            before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p));new=set(bpy.data.objects)-before
            for o in new:
                if o.parent is None:o.parent=root
    for o in originals:bpy.data.objects.remove(o,do_unlink=True)
    for station in d['stations']:
        x,y,z=station['origin']
        for name,offset in [('desk',(0,0,0)),('chair',(0,0,-.65)),('terminal',(0,.78,.12)),(station['resident'],(0,0,-.65))]:
            p=ROOT/'godot/assets'/(name+'.glb');m['reused_assets'][name]=sha(p)
            before=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(p));new=set(bpy.data.objects)-before
            group=bpy.data.objects.new(station['resident']+'_'+name,None);bpy.context.collection.objects.link(group)
            group.location=(x+offset[0],-z-offset[2],y+offset[1])
            for o in new:
                if o.parent is None:o.parent=group
                if o.type=='ARMATURE' and o.animation_data:
                    action=next((strip.action for track in o.animation_data.nla_tracks for strip in track.strips if 'typing' in strip.action.name),None)
                    for track in o.animation_data.nla_tracks:track.mute=True
                    if action:
                        o.animation_data.action=action
                        if action.slots:o.animation_data.action_slot=action.slots[0]
    scene=bpy.context.scene;scene.frame_set(1);scene.unit_settings.system='METRIC';scene.render.engine='CYCLES';scene.cycles.samples=24
    scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.world.use_nodes=True;scene.world.node_tree.nodes.get('Background').inputs['Color'].default_value=(.65,.75,.83,1);scene.world.node_tree.nodes.get('Background').inputs['Strength'].default_value=.5
    for name,pos,power,size in [('Sunsoft',(1,-6,12),2400,8),('Courtyard',(10,2,10),1800,7),('Interior',(-2,0,7),1300,6)]:
        dat=bpy.data.lights.new(name,'AREA');dat.energy=power;dat.shape='DISK';dat.size=size
        o=bpy.data.objects.new(name,dat);scene.collection.objects.link(o);o.location=pos;point(o,(2,0,0))
    cam=bpy.data.objects.new('SharedReview',bpy.data.cameras.new('SharedReview'));scene.collection.objects.link(cam);scene.camera=cam
    cam.data.type='ORTHO';cam.data.ortho_scale=23;cam.location=(18,-21,16);point(cam,(3,0,1))
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.23));g=bpy.context.object;g.name='AuthoringBackdrop'
    mat=bpy.data.materials.new('Backdrop');mat.diffuse_color=(.42,.48,.4,1);g.data.materials.append(mat)
    source=ROOT/'source/shared-workshop.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
    m['source_sha256']=sha(source);m['layout_sha256']=sha(OUT/'layout.json');m['recipe_sha256']={n:sha(HERE/n) for n in ('build_shared_workshop.py','shared_workshop.py','geometry.py','character.py')}
    (ROOT/'shared-workshop-manifest.json').write_text(json.dumps(m,indent=2)+'\n')
    if '--render' in sys.argv:
        for view in ('exterior','cutaway'):
            if view=='cutaway':
                for o in bpy.data.objects:
                    if o.get('group') in ('front','roof'):
                        for child in o.children:child.hide_render=True
            scene.render.filepath=str(ROOT/'evidence'/('shared-authoring-'+view+'.png'));bpy.ops.render.render(write_still=True)
    print('SHARED_EXPORTS_READY',len(m['assets']),sum(a['bytes'] for a in m['assets'].values()))
if __name__=='__main__':main()
