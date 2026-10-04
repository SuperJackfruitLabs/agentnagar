"""Original geometric tram, sailboat and sculpted clouds; no legacy builder reuse."""
import sys,math,json,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import *

def box(n,p,s,m,b=.008,part='body'):
 return tag(cube(n,p,s,m,b),part)
def palette():
 global cream,coral,iron,teak,glass,light,olive,gold,rubber
 cream=mat('warm ivory','E8DDC5');coral=mat('coral enamel','C8654E');iron=mat('charcoal','343C3A');teak=mat('honey teak','B88452');olive=mat('sage upholstery','839565');gold=mat('sun yellow','EBC760');rubber=mat('graphite rubber','424542')
 glass=mat('glass_tram','476365',.23);glass['keep_material']=True
 light=mat('lamp_glow','FFF0C5',.35);light['keep_material']=True
 p=light.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(*rgb('FFE9B0'),1);p.inputs['Emission Strength'].default_value=.35

def prism_x(name,x0,x1,profile,m,part='body'):
 v=[(x,y,z) for x in [x0,x1] for y,z in profile];n=len(profile)
 f=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,v,f,m,part)

def tram():
 clean();palette()
 # Physical apertures at all three game boarding positions.
 doors=[6.15,0,-6.15];jointcentres=[-3.55,3.55]
 cuts=sorted([(-10.0,-9.6),(9.6,10.0)]+[(x-.65,x+.65) for x in doors]+[(x-.28,x+.28) for x in jointcentres])
 sections=[(-9.82,-3.83),(-3.27,3.27),(3.83,9.82)]
 floor=box('continuous accessible floor',(0,0,.355),(20.3,2.24,.09),teak,.02,'interior')
 for s in [-1,1]:
  for a,b in sections:
   # Split sidewall around door holes.
   spans=[(a,b)]
   for mid in doors:
    spans=[seg for l,r in spans for seg in ([(l,min(r,mid-.65))] if l<mid-.65 else [])+([(max(l,mid+.65),r)] if r>mid+.65 else []) if seg[1]-seg[0]>.025] if any(l<mid+.65 and r>mid-.65 for l,r in spans) else spans
   for l,r in spans:
    box('lower cream side',((l+r)/2,s*1.205,.88),(r-l,.09,.96),cream,.025)
    box('continuous coral waist',((l+r)/2,s*1.258,.64),(r-l,.026,.33),coral,.004)
    box('window sill',((l+r)/2,s*1.213,1.335),(r-l,.115,.07),iron,.003)
    n=max(1,round((r-l)/1.05));w=(r-l)/n
    for i in range(n):
     x=l+w*(i+.5)
     gl=max(-9.55,x-w/2+.0275);gr=min(9.55,x+w/2-.0275)
     if gr>gl:box('side glazing',((gl+gr)/2,s*1.215,2.005),(gr-gl,.025,1.31),glass,.012)
     box('window mullion',(l+w*i,s*1.218,2.005),(.046,.065,1.36),iron,.004)
   box('upper cream fascia',((a+b)/2,s*1.205,2.885),(b-a,.10,.39),cream,.045)
  for end in [-1,1]:box('cab opaque side cheek',(end*9.685,s*1.215,2.005),(.27,.065,1.31),cream,.015)
  for k,x in enumerate(doors):
   for leaf,off in [('fore',.327),('aft',-.327)]:
    part=f'door_{"left" if s==1 else "right"}_{k}_{leaf}';cx=x+off
    box('door lower panel',(cx,s*1.226,.89),(.632,.06,.96),cream,.012,part)
    box('door coral stripe',(cx,s*1.264,.64),(.632,.018,.33),coral,.002,part)
    box('door window',(cx,s*1.235,2.0),(.538,.033,1.30),glass,.013,part)
    for xx in [cx-.301,cx+.301]:box('sliding door frame',(xx,s*1.243,1.58),(.034,.05,2.34),iron,.002,part)
    for z in [1.335,2.67]:box('door frame transom',(cx,s*1.243,z),(.63,.05,.038),iron,.002,part)
    box('yellow door control',(x+(0.08 if off>0 else -.08),s*1.281,1.3),(.027,.024,.13),gold,.006,part)
   box('door threshold',(x,s*1.17,.425),(1.29,.14,.03),gold,.005,'interior')
 # Cab faces: chamfered taper; no solid upper volume blocking glazing.
 for sign in [-1,1]:
  x=sign*10.075
  prism_x('faceted cab base',min(sign*9.78,sign*10.25),max(sign*9.78,sign*10.25),[(-1.23,.4),(1.23,.4),(1.23,1.26),(1.10,1.40),(-1.10,1.40),(-1.23,1.26)],cream)
  box('end coral belt',(sign*10.254,0,.67),(.018,2.24,.30),coral,.03)
  # Slanted windscreens following nose slope.
  vs=[(sign*10.255,-1.05,1.42),(sign*10.255,1.05,1.42),(sign*9.85,1.02,2.79),(sign*9.85,-1.02,2.79)]
  mesh('cab panoramic windshield',vs,[(0,1,2,3)],glass)
  for side in [-1,1]:
   mesh('closed faceted cab cheek',[(sign*9.54,side*1.23,1.35),(sign*10.25,side*1.10,1.35),(sign*9.85,side*1.10,2.80),(sign*9.54,side*1.23,2.80)],[(0,1,2,3)],cream)
  mesh('cab header',[(sign*9.85,-1.1,2.79),(sign*9.85,1.1,2.79),(sign*9.82,1.2,3.10),(sign*9.82,-1.2,3.10)],[(0,1,2,3)],cream)
  for y in [-1.10,1.10]:beam('cab corner pillar',(sign*10.22,y,1.35),(sign*9.80,y,2.91),.065,cream,8)
  beam('windscreen bottom seal',(sign*10.263,-1.055,1.42),(sign*10.263,1.055,1.42),.025,iron,8)
  beam('windscreen top seal',(sign*9.852,-1.045,2.79),(sign*9.852,1.045,2.79),.025,iron,8)
  box('blank destination display',(sign*9.92,0,2.85),(.06,.8,.12),iron,.025)
  for y in [-.83,.83]:
   beam('headlight surround',(sign*10.255,y,1.08),(sign*10.277,y,1.08),.09,iron,12)
   beam('warm headlight lens',(sign*10.277,y,1.08),(sign*10.286,y,1.08),.059,light,12)
  beam('single wiper',(sign*10.21,.1,1.58),(sign*10.01,.44,2.2),.013,iron,6)
 # Three shallow faceted roofs; all equipment fades with roof node.
 for a,b in sections:
  prism_x('faceted roof cap',a,b,[(-1.23,3.08),(1.23,3.08),(1.19,3.27),(.99,3.42),(-.99,3.42),(-1.19,3.27)],cream,'roof')
  box('roof equipment tray',((a+b)/2,0,3.48),(min(2.7,b-a-1),1.0,.15),iron,.035,'roof')
  for yy in [-.40,-.24,-.08,.08,.24,.40]:box('vent blade',((a+b)/2,yy,3.565),(1.6,.025,.015),rubber,.001,'roof')
 for x in jointcentres:
  for n in range(8):
   xx=x-.245+n*.07
   for y in [-1.16,1.16]:box('accordion vertical rib',(xx,y,1.72),(.038,.10,2.63),rubber,.01)
   box('accordion crown rib',(xx,0,3.06),(.038,2.35,.10),rubber,.01,'roof')
 # Bogies and correctly spaced tread centres.
 for x in [-7.7,-2.7,2.7,7.7]:
  box('bogie',(x,0,.29),(1.30,1.48,.26),iron,.04)
  for xx in [x-.42,x+.42]:
   beam('axle',(xx,-.72,.26),(xx,.72,.26),.058,iron,10)
   for y in [-.72,.72]:
    ob=cylinder('wheel',(xx,y,.26),.26,.13,rubber,16);ob.rotation_euler[0]=math.pi/2
    ob=cylinder('wheel hub',(xx,y+(.075 if y>0 else -.075),.26),.12,.016,iron,12);ob.rotation_euler[0]=math.pi/2
 # Match actual layout rider rows; all seats face travel +X.
 layout=json.loads((REPO/'city/godot/styles/tram_layout.json').read_text())
 for slot in layout['slots']:
  if slot['pose']!='sitting':continue
  x=10.25-slot['along_cm']/100;y=slot['across_cm']/100
  box('rider seat cushion',(x,y,.81),(.52,.48,.08),olive,.04,'interior')
  box('rider seat back',(x-.235,y,1.16),(.07,.48,.66),olive,.04,'interior')
  box('seat cantilever',(x,y,.60),(.055,.055,.35),iron,.01,'interior')
 for x in [-6.15,0,6.15]:
  for y in [-.45,.45]:beam('grab pole',(x,y,.41),(x,y,2.9),.021,gold,8,part='interior')
 for x in [-7,0,7]:box('ceiling light',(x,0,2.98),(2.0,.14,.035),light,.006,'lights')
 for y in [-.35,.35]:
  beam('pantograph lower',(0,y,3.60),(.80,y,4.0),.025,iron,8,part='roof')
  beam('pantograph upper',(.80,y,4.0),(-.1,y,4.45),.025,iron,8,part='roof')
 beam('contact shoe',(-.1,-.75,4.45),(-.1,.75,4.45),.025,iron,8,part='roof')
 # End lenses and seals fit within the runtime's exact 20.5 m envelope.
 bpy.context.view_layer.update()
 meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
 tip=max(abs((o.matrix_world@v.co).x) for o in meshes for v in o.data.vertices)
 for o in meshes:
  inv=o.matrix_world.inverted()
  for v in o.data.vertices:
   p=o.matrix_world@v.co
   if abs(p.x)>9.8:p.x=math.copysign(9.8+(abs(p.x)-9.8)*.45/(tip-9.8),p.x);v.co=inv@p
 for o in meshes:
  bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=0.000001);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=0.000001)
  bad=[f for f in bm.faces if f.calc_area()<1e-12]
  if bad:bmesh.ops.delete(bm,geom=bad,context='FACES')
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 finish('tram',notes=['Original cream/coral three-section tram; preserves all 12 independently sliding leaves at runtime boarding positions.','Rail tread centres +/-0.72m; floor0.4m; seats0.85m; 40-slot layout.'])

def sailboat():
 clean();palette();hull=mat('red cedar hull','B65E42');hull2=mat('hull lower plane','904A38');sail=mat('ivory sail','F0E5CE')
 # Open hull: longitudinal stations, four cross-section levels, separate inner skin.
 stations=[(-2.46,.04),(-1.85,.65),(-.9,.88),(.2,.92),(1.25,.69),(2.10,.35),(2.46,.025)]
 verts=[]
 for y,w in stations:
  for x,z in [(-w,.72),(-w*.82,.34),(0,.06),(w*.82,.34),(w,.72),(w-.065 if w>.08 else 0,.68),(0,.20),(-w+.065 if w>.08 else 0,.68)]:verts.append((x,y,z))
 faces=[]
 for k in range(len(stations)-1):
  for j in range(8):faces.append((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j))
 faces += [tuple(reversed(range(8))),tuple(range((len(stations)-1)*8,len(stations)*8))]
 ob=mesh('watertight open cedar hull',verts,faces,[hull,hull2],'boat')
 for p in ob.data.polygons:p.material_index=1 if p.center.z<.35 else 0
 for s in [-1,1]:
  for i in range(len(stations)-1):
   y,w=stations[i];yy,ww=stations[i+1];beam('teak gunwale',(s*w,y,.735),(s*ww,yy,.735),.035,teak,6,part='boat')
 for y in [-1.40,-.35,.80]:
  w=.7 if y!=-1.4 else .57;box('thwart',(0,y,.61),(w*2,.25,.06),teak,.015,'boat')
 for x in [-.26,-.13,0,.13,.26]:box('cockpit floorboard',(x,0,.255),(.118,2.9,.035),teak,.003,'boat')
 beam('mast',(0,.30,.27),(0,.30,6.80),.045,teak,10,radius2=.024,part='boat')
 beam('boom',(0,.30,1.02),(0,-2.08,1.02),.029,teak,8,part='boat')
 # Broad triangles with a shallow belly and sewn panel change.
 v=[(0,.30,6.56),(0,.30,1.14),(0,-2.04,1.14),(.14,-.66,2.80),(0,.30,2.0),(0,-1.68,2.0)]
 ob=mesh('main sail',v,[(0,4,3),(0,3,5),(4,1,2,5,3)],[sail,gold],'boat');ob.data.polygons[-1].material_index=1
 ob=mesh('foresail',[(0,.39,6.21),(0,2.30,.89),(.09,1.1,1.0),(0,.39,1.15)],[(0,1,2),(0,2,3)],sail,'boat')
 for a,b in [((0,.3,6.71),(0,2.42,.77)),((0,.3,6.71),(0,-2.40,.77)),((0,-2.08,1.02),(.36,-1.40,.7))]:beam('running rigging',a,b,.009,iron,5,part='boat')
 finish('sailboat',notes=['Original open hull, thwarts, mast, two faceted sails and rigging. Sail surfaces intentionally two-sided.'])

def cloud(name,variant):
 clean();white=mat('cloud warm white','F5F5EB');shade=mat('cloud pale shadow','DDE2DB')
 blobs=[(-3,0,1.2,2.0,1.55,1.5),(-.9,0,1.4,2.6,1.8,2.3),(1.3,.15,1.8,2.5,1.7,2.7),(3.4,0,1.1,1.65,1.35,1.4)] if variant==0 else [(-2.7,0,.8,1.7,1.2,1.2),(-.7,0,1.5,1.9,1.6,2.2),(1.4,0,.8,2.1,1.4,1.4),(2.8,0,.6,1.3,1.1,1.0)]
 obs=[ico('cloud lobe',(x,y,z),(sx,sy,sz),white,2,'cloud') for x,y,z,sx,sy,sz in blobs]
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();ob=bpy.context.object
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 mod=ob.modifiers.new('unified cloud skin','REMESH');mod.mode='VOXEL';mod.voxel_size=.22;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=ob.modifiers.new('broad designed facets','DECIMATE');mod.ratio=.065;bpy.ops.object.modifier_apply(modifier=mod.name)
 for v in ob.data.vertices:v.co.z=max(.08,v.co.z)
 bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.001);bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(ob.data);bm.free()
 ob.data.materials.append(shade)
 for p in ob.data.polygons:p.material_index=1 if p.normal.z<-.3 else 0
 # Scale to broad actual dimensions while retaining flattened base.
 target=(9.87,4.37,4.09) if variant==0 else (8.22,3.75,3.43)
 bpy.context.view_layer.update();ob.dimensions=target;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 minz=min(v.co.z for v in ob.data.vertices)
 for v in ob.data.vertices:v.co.z-=minz
 finish(name,notes=['Original merged and decimated cloud lobes; flattened underside; intentionally broad facets.'])

def aliases():
 for src,dst in [('seat_bench_v2','bench_park'),('seat_reading-chair_v2','reading_chair_v2')]:
  clean();bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/lowpoly_tropical'/(src+'.blend')))
  for ob in list(bpy.context.scene.objects):
   if ob.name.startswith('Studio /'):bpy.data.objects.remove(ob,do_unlink=True)
  finish(dst,notes=['Alias of approved original '+src+' geometry; source design preserved.'])
 clean()
 for name,x,ang in [('cafe_table',0,0),('seat_cafe-table_v2',-.68,-math.pi/2),('seat_cafe-table_v2',.68,math.pi/2)]:
  with bpy.data.libraries.load(str(ROOT/'assets/lowpoly_tropical'/(name+'.blend')),link=False) as (source,dest):dest.objects=source.objects
  selected=[o for o in dest.objects if o is not None];meshes=[o for o in selected if o.type=='MESH']
  for ob in selected:bpy.context.collection.objects.link(ob)
  bpy.context.view_layer.update()
  matrices={ob:ob.matrix_world.copy() for ob in meshes}
  for ob in meshes:
   mw=matrices[ob];ob.parent=None;ob.matrix_world=mw
   from mathutils import Matrix
   ob.matrix_world=Matrix.Translation((x,0,0))@Matrix.Rotation(ang,4,'Z')@ob.matrix_world;ob['asset_part']='body'
  for ob in selected:
   if ob.type!='MESH':bpy.data.objects.remove(ob,do_unlink=True)
 for i,o in enumerate(bpy.context.scene.objects):
  if o.type=='MESH':o.name='assembly_source_'+str(i)
 finish('cafe_table_set',notes=['Assembly of approved thin table and two approved cafe chairs, no remodel.'])

if __name__=='__main__':
 tasks=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['tram','sailboat','clouds','aliases']
 for t in tasks:
  if t=='tram':tram()
  elif t=='sailboat':sailboat()
  elif t=='clouds':cloud('cloud_a',0);cloud('cloud_b',1)
  elif t=='aliases':aliases()
