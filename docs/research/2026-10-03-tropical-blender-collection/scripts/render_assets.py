"""Matched orthographic product photography of exported, re-imported GLBs."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import clean,mat,cube,ROOT,REPO
args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
mode=args[0] if args else 'ours'
names=args[1].split(',') if len(args)>1 else sorted(p.stem for p in (ROOT/'assets/lowpoly_tropical').glob('*.glb') if not p.stem.endswith('_far'))
views=args[2].split(',') if len(args)>2 else ['hero']
prefs=bpy.context.preferences.addons['cycles'].preferences
try:
 prefs.compute_device_type='OPTIX';prefs.get_devices()
 for d in prefs.devices:d.use=d.type=='OPTIX'
 gpu=any(d.type=='OPTIX' for d in prefs.devices)
except:gpu=False
print('GPU',gpu,flush=True)
for name in names:
 path={'ours':ROOT/'assets/lowpoly_tropical','assembly':ROOT/'assemblies','proof':ROOT/'reports','prior':REPO/'docs/research/2026-10-02-design-sheet-to-asset/out/lowpoly_tropical','kit':REPO/'city/godot/styles/lowpoly_tropical/assets'}[mode]/(name+'.glb')
 if not path.exists():continue
 clean();bpy.ops.import_scene.gltf(filepath=str(path))
 for ob in bpy.context.scene.objects:
  if ob.name in ['hair_1','hair_2','hair_3']:ob.hide_render=True;ob.hide_set(True)
 if name in ['character_human','character_robot']:
  for ob in list(bpy.context.scene.objects):
   if ob.type=='MESH' and not any(m.type=='ARMATURE' for m in ob.modifiers):bpy.data.objects.remove(ob,do_unlink=True)
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render];bpy.context.view_layer.update()
 pts=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
 lo=Vector([min(p[i] for p in pts) for i in range(3)]);hi=Vector([max(p[i] for p in pts) for i in range(3)])
 contracts=json.loads((ROOT/'baseline-contracts.json').read_text())
 # Shared scale per named asset: no flattering change of framing between candidates.
 dims=[max(hi[i]-lo[i] for i in range(3))]
 for origin in contracts.get(name,{}).values():
  dims.append(max(max(o['hi'][i] for o in origin)-min(o['lo'][i] for o in origin) for i in range(3)))
 stats=ROOT/'assets/lowpoly_tropical'/(name+'.json')
 if stats.exists():
  t=json.loads(stats.read_text());dims.append(max(t['bounds_max'][i]-t['bounds_min'][i] for i in range(3)))
 factor=1/max(dims)
 top_objects=[o for o in bpy.context.scene.objects if o.parent is None]
 presentation=bpy.data.objects.new('Presentation scale',None);bpy.context.collection.objects.link(presentation)
 for o in top_objects:o.parent=presentation
 presentation.scale=(factor,factor,factor)
 bpy.context.view_layer.update()
 target=Vector(((hi.x+lo.x)*factor*.5,(hi.y+lo.y)*factor*.5,(hi.z+lo.z)*factor*.5))
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.device='GPU' if gpu else 'CPU';s.cycles.samples=32;s.cycles.use_denoising=True
 s.render.resolution_x=850;s.render.resolution_y=850;s.render.resolution_percentage=100;s.render.image_settings.file_format='PNG'
 s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
 s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.7,.74,.79,1);s.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.45
 cube('Studio / warm floor',(0,0,lo.z*factor-.026),(200,200,.05),mat('Studio / floor','DAD6C9'),0)
 for label,loc,power,size in [('key',(-3,4,5),450,4),('fill',(3,1,3),150,3),('rim',(-1,-3,4),250,3)]:
  bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.name='Studio / '+label;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';s.camera=cam
 for view in views:
  facing_south=mode=='assembly' or name.startswith(('hall_','lib_','house_','shop_','tower_')) or name in ['cafe','plaque']
  vectors={'hero':(3.3,-4.5,2.9) if facing_south else (-3.3,4.5,2.9),'rear':(-3.3,4.5,2.9) if facing_south else (3.3,-4.5,2.9),'front':(0,-5 if facing_south else 5,0),'top':(0,0,5)}
  cam.location=target+Vector(vectors[view]);cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.50
  if name=='tram':
   s.render.resolution_x=1600;s.render.resolution_y=750;cam.location=target+Vector((-1.2,5 if view!='rear' else -5,2.1));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.22
  if mode=='proof':
   s.render.resolution_x=1600;s.render.resolution_y=800;cam.location=target+Vector((0,5,1.25));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=1.24
  out=ROOT/'renders'/f'{mode}-{name}-{view}.png';s.render.filepath=str(out);print('RENDER',out,flush=True);bpy.ops.render.render(write_still=True)
print('RENDER_COMPLETE',flush=True)
