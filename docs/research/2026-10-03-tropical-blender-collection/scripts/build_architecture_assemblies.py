import bpy,math,sys,json
from pathlib import Path
from mathutils import Matrix,Vector
ROOT=Path(__file__).resolve().parent.parent
assets=ROOT/'assets'/'lowpoly_tropical';dest=ROOT/'assemblies';dest.mkdir(exist_ok=True)
components=[]
def clean():
 components.clear()
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def bounds(objects,matrices):
 pts=[matrices[o]@v.co for o in objects for v in o.data.vertices]
 return [[min(v[i] for v in pts) for i in range(3)],[max(v[i] for v in pts) for i in range(3)]]
def add(n,pos=(0,0,0),angle=0,scale=(1,1,1)):
 with bpy.data.libraries.load(str(assets/(n+'.blend')),link=False) as (src,target):target.objects=src.objects
 loaded=[o for o in target.objects if o]
 for o in loaded:bpy.context.collection.objects.link(o)
 bpy.context.view_layer.update()
 meshes=[o for o in loaded if o.type=='MESH']
 cached={o:o.matrix_world.copy() for o in meshes}
 local=bounds(meshes,cached)
 metadata=json.loads((assets/(n+'.json')).read_text())
 for k,key in enumerate(['bounds_min','bounds_max']):
  assert all(abs(local[k][i]-metadata[key][i])<.0001 for i in range(3)),(n,'local source differs from exported GLB metadata',local,metadata)
 xf=Matrix.Translation(Vector(pos))@Matrix.Rotation(angle,4,'Z')@Matrix.Diagonal(Vector((*scale,1)))
 expected=bounds(meshes,{o:xf@cached[o] for o in meshes})
 for o in meshes:
  o.parent=None;o.matrix_world=xf@cached[o];o['assembly_component']=n
 for o in loaded:
  if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
 bpy.context.view_layer.update()
 actual=bounds(meshes,{o:o.matrix_world.copy() for o in meshes})
 assert all(abs(actual[k][i]-expected[k][i])<.0001 for k in range(2) for i in range(3)),(n,'placed component bounds changed')
 components.append({'asset':n,'position':list(pos),'source_bounds_match_glb_metadata':True,'placed_min':actual[0],'placed_max':actual[1],'editable_meshes':len(meshes)})
def save(n):
 bpy.ops.wm.save_as_mainfile(filepath=str(dest/(n+'.blend')))
 bpy.ops.export_scene.gltf(filepath=str(dest/(n+'.glb')),export_format='GLB',export_yup=True,export_texcoords=False)
 (dest/(n+'.json')).write_text(json.dumps({'assembly':n,'source':'Original candidate components; illustrative composition, not runtime adoption','mesh_count':len([o for o in bpy.context.scene.objects if o.type=='MESH']),'component_bounds_verified':components},indent=2))
clean()
# Demonstrates continuous sawtooth silhouette and a clear front doorway.
for x in [-4,4]:add('hall_window_wall',(x,-4,0));add('hall_window_wall',(x,4,0),math.pi)
add('hall_door_wall',(0,-4,0));add('hall_wall',(0,4,0))
for x in [-1.15,1.15]:add('hall_door_leaves',(x,-4,0))
for x in [-6,6]:
 for y in [-2,2]:add('hall_wall',(x,y,0),math.pi/2)
for x in [-6,6]:
 for y in [-4,4]:add('hall_corner',(x,y,0))
for x in [-4,0,4]:
 for y in [-2,2]:add('hall_sawtooth_bay',(x,y,5.2))
 for y in [-4,4]:add('hall_sawtooth_gable',(x,y,5.2))
save('hall_assembly')
clean()
# Lower arcade plus roof drum/copper cap follows supplied library reference.
for y in [-5,5]:
 for x in [-5,-3,3,5]:add('lib_wall_arch',(x,y,0),0 if y<0 else math.pi)
 add('lib_entrance',(0,y,0),0 if y<0 else math.pi)
 for x in [-6,-4,-2,2,4,6]:add('lib_column',(x,y,0))
for x in [-6,6]:
 for y in [-4,-2,0,2,4]:add('lib_wall_arch',(x,y,0),math.pi/2)
 for y in [-5,-3,-1,1,3,5]:add('lib_column',(x,y,0))
for x in [-1.15,1.15]:add('lib_door_leaves',(x,-5,0))
for x in [-2.1,2.1]:add('lib_banner',(x,-5.25,7.2))
# Editable limestone roof terrace, datum 8m.
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,7.98));ob=bpy.context.object;ob.name='Illustrative cornice terrace';ob.dimensions=(12.3,10.3,.22);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
material=bpy.data.materials.get('Ivory limewash');ob.data.materials.append(material)
add('lib_dome',(0,0,8))
save('library_assembly')
clean()
for x in [-8,0,8]:add('bridge_span',(x,0,0))
for x in [-4,4]:add('bridge_pier',(x,0,0))
save('bridge_assembly')
