"""Original 24 tropical props from inspected October 3 reference sheets. No old meshes/builders."""
import sys,math,random,json,os
from mathutils import Matrix
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import *
random.seed(103)
TEAK=[mat('Teak honey','AE7C49'),mat('Teak golden board','B98550'),mat('Teak pale grain','BE905D'),mat('Teak dark grain','976B40')]
STONE=[mat('Limestone cream','DED2BB'),mat('Limestone shade','D2C5AE'),mat('Limestone pale','E5DAC5')]
STEEL=mat('Charcoal powdercoat','343B39',.5); DARK=mat('Unlit screen','354A49',.28); BRASS=mat('Brass details','C6A050',.45)
YELLOW=mat('Marigold shade','F3C547'); CORAL=mat('Terracotta','B66F52'); SOIL=mat('Soil','534837')
GREEN=[mat('Leaf deep','52682D'),mat('Leaf olive','7C912E'),mat('Leaf sun','A5B83D')]; PETAL=mat('Ivory blossom','FFF1C5'); CENTER=mat('Flower pollen','E8BD45')
ASPHALT=[mat('Warm street stone','918B7F'),mat('Street lighter','999285')]; SAND=mat('Path ochre','CDA56E')
REPORTS=[]
ONLY=set(os.environ.get('PROPS_ONLY','').split(','))-{''}
def box(n,p,s,m=TEAK[0],b=.003,part='body',rot=(0,0,0)):
 return tag(cube(n,p,s,m,b,rot),part)
def anchor(p,size,tilt=0,yaw=0):
 o=bpy.data.objects.new('display',None);bpy.context.collection.objects.link(o);o.location=p;o.rotation_euler=(math.pi/2+tilt,0,yaw);o.scale=(size[0],size[1],1);return o

def done(name,notes=(),display=None):
 if ONLY and name not in ONLY:return
 # Anchors are empties, never merged into screen/body mesh: scale is live face size.
 a=anchor(*display) if display else None
 parts=[o for o in bpy.context.scene.objects if o.type=='MESH']
 r=finish(name,parts,list(notes)+['Original Blender construction from inspected references; source repository read-only.'])
 if a:
  root=bpy.data.objects[name];a.parent=root;a.select_set(True)
  bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/lowpoly_tropical'/f'{name}.glb'),export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_normals=True,export_texcoords=False)
  r['parts'].append('display');r['display_authoring']={'position':list(a.location),'scale':list(a.scale),'rotation_x':a.rotation_euler.x}
  (ROOT/'assets/lowpoly_tropical'/f'{name}.json').write_text(json.dumps(r,indent=2))
 REPORTS.append(r)

def boards(n,p,s,count=5):
 w,d,h=s
 for k in range(count):
  box(n+str(k),(p[0],p[1]-d/2+(k+.5)*d/count,p[2]),(w,d/count-.002,h),TEAK[k%3])
 # restrained authored grain strokes, flush top rather than noisy striping
 for k in range(count):
  for j in range(2):
   box(n+' grain', (p[0]+(-.2+j*.4)*w,p[1]-d/2+(k+.3+j*.23)*d/count,p[2]+h/2+.0003),(w*.32,.0013,.0006),TEAK[3],0)

def table(w,d,h,th=.03,steel=.03):
 boards('Teak surface',(0,0,h-th/2),(w,d,th),5)
 for x in (-w/2+.045,w/2-.045):
  for y in (-d/2+.045,d/2-.045):box('Square steel leg',(x,y,(h-th)/2),(steel,steel,h-th),STEEL,.0015)
  box('End brace',(x,0,.17),(steel,d-.06,steel),STEEL,.0015)
 for y in (-d/2+.045,d/2-.045):box('Top longitudinal brace',(0,y,h-th-.023),(w-.06,steel,steel),STEEL,.0015)

def stool(y=.7):
 boards('Stool seat',(0,y,.435),(.4,.4,.03),3)
 for x in (-.175,.175):
  for yy in (y-.175,y+.175):box('Stool leg',(x,yy,.21),(.025,.025,.42),STEEL,.001)
  box('Stool side brace',(x,y,.12),(.025,.36,.025),STEEL,.001)
 for yy in (y-.175,y+.175):box('Stool front brace',(0,yy,.12),(.36,.025,.025),STEEL,.001)

def monitor(top=.75,x=0):
 box('Monitor foot',(x,-.23,top+.015),(.23,.16,.026),STEEL)
 box('Monitor stem',(x,-.26,top+.13),(.035,.032,.23),STEEL,.002)
 box('Monitor bezel',(x,-.255,top+.285),(.51,.04,.325),STEEL,.007)
 box('Blank monitor face',(x,-.231,top+.285),(.47,.005,.285),DARK,.001,'screen')
 box('Keyboard base',(x,.01,top+.011),(.33,.125,.019),STEEL,.002)
 for row in range(3):
  for col in range(11):box('Keyboard key',(x-.14+col*.028,-.03+row*.027,top+.023),(.022,.019,.007),ASPHALT[0],.001)
 ico('Mouse',(x+.27,.02,top+.023),(.025,.04,.021),STEEL,2)
 return ((x,-.226,top+.285),(.47,.285),0)

for name in ['desk_v2','seat_desk_v2','workstation']:
 clean();table(1.3,.7,.75);stool(.65)
 disp=monitor()
 for ob in bpy.context.scene.objects:
  if ob.name.startswith(('Monitor bezel','Blank monitor face')):ob.location.z+=.0025
 disp=((0,-.226,1.0375),(.47,.285),0)
 # matching runtime screen contract for desk aliases, too
 bpy.context.view_layer.update()
 for ob in bpy.context.scene.objects:
  if ob.type=='MESH':ob.matrix_world=Matrix.Translation((0,.60,0)) @ Matrix.Rotation(math.pi,4,'Z') @ ob.matrix_world
 disp=((0,.826,1.0375),(.47,.285),0,math.pi)
 done(name,['30 mm table steel; 25 mm stool steel. Ref desktop .75 m; complete seat+monitor assembly.'],disp if name=='workstation' else None)
clean();table(3.2,1.,.9,.045,.05);boards('Low workbench shelf',(0,0,.22),(3.09,.89,.03),5)
# screen detachable service module at rear retains historical contract envelope without thick furniture
monitor(.9)
for ob in bpy.context.scene.objects:
 if ob.name.startswith(('Monitor bezel','Blank monitor face')):ob.location.z-=.0475
done('workbench',['50 mm steel maximum, .90 m work surface. Detachable monitor retains required screen node.'])
clean()
box('Bookcase back',(0,-.205,1.3),(2.,.035,2.6),TEAK[3])
for x in (-.98,.98):box('Bookcase side',(x,0,1.3),(.04,.45,2.6),TEAK[0])
for z in [.025,.535,1.045,1.555,2.065,2.575]:box('Bookcase shelf',(0,0,z),(1.96,.45,.045),TEAK[1])
bookm=[mat('Book ochre','C7A447'),mat('Book olive','657A44'),mat('Book teal','54716B'),mat('Book coral','B9724D')]
for tier in range(5):
 for side in [-1,1]:
  x=side*.48
  for k in range(6):
   bw=.075+random.random()*.018;bh=random.uniform(.28,.39)
   box('Individual book',(x+(k-2.5)*.092,-.017,.054+tier*.51+bh/2),(bw,.28,bh),bookm[(k+tier)%4],.002)
   box('Book spine band',(x+(k-2.5)*.092,.125,.13+tier*.51),(bw*.8,.003,.013),BRASS,.0005)
done('bookshelf_v2',['2 x 2.6 x .45 m; five filled shelves, open negative-space bays.'])
clean();box('Pegboard timber',(0,0,.6),(2.,.035,1.2),TEAK[1])
for row in range(11):
 for col in range(21):
  o=cylinder('Dark drilled hole',(-.94+col*.094,.019,.065+row*.106),.006,.001,STEEL,8);o.rotation_euler=(math.pi/2,0,0)
for k in range(5):
 x=-.85+k*.115;box('Screwdriver steel',(x,.04,.68),(.009,.012,.3),ASPHALT[0],.001);box('Screwdriver handle',(x,.045,.9),(.034,.028,.15),YELLOW,.01)
for k in range(4):
 x=.36+k*.16;box('Spanner handle',(x,.044,.65),(.025,.018,.29),ASPHALT[0],.003)
 o=cylinder('Spanner open head',(x,.044,.82),.044,.018,ASPHALT[0],8);o.rotation_euler=(math.pi/2,0,0)
 box('Spanner jaw cutout',(x,.056,.849),(.021,.009,.036),TEAK[1],0)
box('Hammer handle',(-.15,.057,.66),(.035,.035,.38),TEAK[3]);box('Hammer head',(-.15,.057,.88),(.17,.055,.055),STEEL)
for k in range(3):box('Parts tray',(-.73+k*.28,.09,.16),(.22,.13,.075),STEEL)
box('Spirit level',(.56,.07,.2),(.58,.045,.06),YELLOW)
for x in [.36,.75]:box('Level glass',(x,.096,.2),(.055,.005,.029),DARK,.002)
done('pegboard',['2 x 1.2 m; original screwdriver, hammer, spanners, level, trays; face holes are shallow dark geometry.'])
clean()
# Hollow revolved shade, rather than solid cone.
verts=[];faces=[];rings=[(.225,0),(.15,.085),(.06,.145),(.027,.2),(.02,.2),(.053,.137),(.145,.077),(.221,.003)]
for radius,z in rings:
 for k in range(16):a=k*math.tau/16;verts.append((math.cos(a)*radius,math.sin(a)*radius,z))
for r in range(7):
 for k in range(16):faces.append((r*16+k,r*16+(k+1)%16,(r+1)*16+(k+1)%16,(r+1)*16+k))
mesh('Marigold pendant shade',verts,faces,YELLOW)
beam('Pendant cord',(0,0,.2),(0,0,1.18),.003,STEEL,8);cylinder('Ceiling rose',(0,0,1.19),.035,.02,STEEL)
light=mat('Warm pendant bulb','FFF2C4');light['keep_material']=True;bs=light.node_tree.nodes.get('Principled BSDF');bs.inputs['Emission Color'].default_value=(*rgb('FFF2C4'),1);bs.inputs['Emission Strength'].default_value=.8
ico('Bulb',(0,0,.05),(.026,.026,.033),light,2,'light');done('pendant_lamp',['.45 m diameter hollow shade; 1 m cord.'])
clean()
for x in [-.67,.67]:
 box('Board post',(x,0,1.22),(.07,.075,2.44),STEEL)
 box('Post foot',(x,0,.015),(.10,.13,.03),STEEL)
box('Board back',(0,0,1.67),(1.29,.055,1.04),TEAK[3])
box('Blank notice face',(0,.031,1.67),(1.19,.006,.92),STONE[2],0)
for x in [-.63,.63]:box('Board side frame',(x,.045,1.67),(.065,.075,1.06),TEAK[0])
for z in [1.15,2.19]:box('Board horizontal frame',(0,.045,z),(1.32,.075,.065),TEAK[1])
# two sloping terracotta roof panels and charcoal finials
for side in [-1,1]:box('Notice roof',(0,side*.158,2.34),(1.46,.326,.026),CORAL,.002,rot=(-side*.25,0,0))
for x in [-.67,.67]:box('Post cap',(x,0,2.455),(.09,.095,.05),STEEL)
done('noticeboard',['Blank 1.19 x .92 m face, runtime display anchor centred, roof .63 m depth.'],((0,.041,1.67),(1.19,.92),0))
clean();box('Plaque plinth',(0,0,.065),(.6,.3,.13),STONE[1]);box('Plaque pedestal',(0,0,.62),(.51,.24,1.06),STONE[0],.008)
# angled lectern face: outward +Y, normal inclined upward .35 radians
box('Plaque top moulding',(0,.015,1.094),(.54,.035,.30),BRASS,.003,rot=(.35,0,0))
box('Blank plaque',(0,.033,1.100),(.50,.01,.26),DARK,.001,rot=(.35,0,0))
done('plaque',['Blank brass-rimmed sloping face; anchor normal and scale follow tilt.'],((0,.041,1.102),(.50,.26),.35))
clean();box('Kiosk stone column',(0,-.008,.94),(.8,.484,1.88),STONE[0],.065)
box('Kiosk lower moulding',(0,0,.1),(.8,.5,.16),STONE[1],.012)
# actual recess framed by column and bezel, blank screen no graphic text
box('Kiosk inset rim',(0,.230,1.12),(.64,.018,1.12),STONE[1],.025)
box('Kiosk blank screen',(0,.243,1.12),(.57,.01,1.02),DARK,.012,'screen')
done('kiosk',['Blank .57 x 1.02 m screen, separately named screen and display nodes.'],((0,.25,1.12),(.57,1.02),0))
clean()
for k in range(3):
 h=[.26,.355,.45][k];d=(3-k)/3
 box('Limestone step',(0,-.5+d/2,h/2),(3,d,h),STONE[k%3],.002)
done('steps',['Three visible treads .26/.355/.45 m: lowest above .25 m walking band, width3 depth1 height.45. Runtime footprint retained; no hidden solids.'])
clean();box('Wall limestone body',(0,0,.205),(3,.27,.41),STONE[0],.003)
for k in range(3):box('Separate wall coping',(-1+(k),0,.4275),(.998,.3,.045),STONE[2],.002)
done('low_wall',['3 x .3 x .45 m; three restrained limestone coping joints.'])
clean();box('Perch SOLID limestone',(0,0,.21),(.29,.54,.42),STONE[0],.003)
box('Perch teak cap',(0,0,.44),(.3,.55,.04),TEAK[1],.003)
for y in [-.1375,0,.1375]:box('Cap board joint',(0,y,.4598),(.296,.001,.0004),TEAK[3],0)
for ob in bpy.context.scene.objects:
 if ob.type=='MESH':ob.location.y-=.125
done('perch_seat',['Exactly .30 x .55 x .46 m. Solid block from ground; no legs or underside gap.'])

def leaf(n,start,end,width,material):
 a,b=Vector(start),Vector(end);v=b-a
 side=v.cross(Vector((0,1,0)))
 if side.length<.001:side=Vector((1,0,0))
 side.normalize();mid=a+v*.53;ridge=mid+Vector((0,0,.02))
 verts=[a,mid+side*width/2,b,mid-side*width/2,ridge]
 ob=mesh(n,verts,[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],material)
 # double face material for scattered view from both sides
 material.use_nodes=True;material.surface_render_method='DITHERED' if hasattr(material,'surface_render_method') else None
 return ob

def grass(count=15,scale=1,basez=0,spread=.08):
 for k in range(count):
  theta=k*2.39996;h=random.uniform(.48,.88)*scale;r=random.uniform(.045,.15)*scale
  a=(math.cos(theta)*spread,math.sin(theta)*spread,basez)
  end=(math.cos(theta)*r,math.sin(theta)*r,basez+h)
  leaf('Folded grass blade',a,end,.034*scale,GREEN[k%3])

def flower(p,r=.032):
 x,y,z=p
 beam('Flower stem',(x,y,z-.32),(x,y,z),.003,GREEN[0],6)
 for k in range(5):
  a=k*math.tau/5;dx,dy=math.cos(a)*r*.7,math.sin(a)*r*.7
  ico('Ivory petal',(x+dx,y+dy,z),(r*.57,r*.57,.007),PETAL,1)
 ico('Golden flower centre',(x,y,z+.006),(.010,.010,.009),CENTER,1)
 for k in range(2):leaf('Stem leaf',(x,y,z-.21+k*.08),(x+(-1)**k*.045,y+.02,z-.16+k*.08),.019,GREEN[1])
clean();grass();leaf('Tall centre blade',(0,0,0),(.035,.02,.88),.035,GREEN[2]);done('meadow_grass',['Original folded triangular tapered blades, rooted at zero; .88 m tallest target.'])
clean();grass(12,.7)
for p in [(-.07,.02,.89),(.08,.02,.74),(.01,-.075,.63),(-.10,-.03,.49)]:flower(p)
done('meadow_flowers',['Ivory five-petal blossoms on individual stems amid folded grass.'])
clean()
# tapered hollow cream pot with separate rim, 16 low-poly sectors
verts=[];faces=[]
for r,z in [(.25,0),(.345,.22),(.40,.56),(.355,.56),(.307,.22),(.23,.05)]:
 for k in range(16):a=k*math.tau/16;verts.append((r*math.cos(a),r*math.sin(a),z))
for j in range(5):
 for k in range(16):faces.append((j*16+k,j*16+(k+1)%16,(j+1)*16+(k+1)%16,(j+1)*16+k))
o=mesh('Hollow faceted limestone pot',verts,faces,STONE)
for p in o.data.polygons:p.material_index=random.choices([0,1,2],[6,2,2])[0]
cylinder('Recessed soil',(0,0,.525),.35,.025,SOIL,16)
for k in range(22):
 a=k*2.39996;r=random.uniform(.12,.30);h=random.uniform(.20,.51)
 leaf('Broad tropical pot leaf',(math.cos(a)*.1,math.sin(a)*.1,.54),(math.cos(a)*r,math.sin(a)*r,.54+h),.11,GREEN[k%3])
leaf('Central spear',(0,0,.54),(.02,.02,1.10),.09,GREEN[2])
for p in [(-.16,.16,.82),(.17,.03,.75),(-.03,-.18,.83)]:flower(p,.044)
done('planter_pot',['Hollow limestone pot .8 m wide; foliage reaches1.1 m; recessed soil and cream blossoms.'])

# Modular surfaces use negative authoring Z, so their walking top lies at zero.
def paving(name,pattern):
 clean();box('Tile grout base',(0,0,-.034),(1,1,.052),STONE[1],0,part=name)
 if pattern=='b':
  for row in range(3):
   cuts=[-.5,-.05,.5] if row%2==0 else [-.5,.2,.5]
   for j in range(2):
    width=cuts[j+1]-cuts[j]
    box('Offset limestone paver',((cuts[j+1]+cuts[j])/2,-.5+(row+.5)/3,-.014),(width-.002,1/3-.002,.028),STONE[(row+j)%3],.001,part=name)
 else:
  for i in range(2):
   for j in range(2):box('Square limestone paver',(-.25+i*.5,-.25+j*.5,-.014),(.498,.498,.028),SAND if pattern=='c' and (i+j)%2 else STONE[2],.001,part=name)
 done(name,['1m module; top zero; .06m thickness; visible 2mm joints.'])
for n in ['a','b','c']:paving('paving_tile_'+n,n)
clean();box('Ochre compacted path',(0,0,-.03),(1,1,.06),SAND,.001,part='path')
# Subtle flat angular aggregate, coplanar 0.2 mm height maximum.
for k in range(28):
 x=random.uniform(-.47,.47);y=random.uniform(-.47,.47)
 mesh('Path fine aggregate',[(x-.003,y-.003,.0002),(x+.004,y-.002,.0002),(x,y+.004,.0002)],[(0,1,2)],TEAK[2],part='path')
done('path',['1m ochre module; fine flat aggregate, no protruding scatter.'])
clean();box('Street module foundation',(0,0,-.06),(2,2,.04),ASPHALT[0],0,part='street')
for i in range(2):
 for j in range(2):box('Street square',(-.5+i,-.5+j,-.02),(.998,.998,.04),ASPHALT[(i+j)%2],.001,part='street')
done('street_tile',['2x2m .08m thick; four limestone-grey slabs.'])
clean();box('Kerb body',(0,0,.045),(2,.66,.17),STONE[0],.018,part='kerb');done('street_kerb',['2m module, .66m cross-width and .17m height; underside -.04 aligns street base.'])
clean()
# Track runs +X as tram_layout.py; approved tram wheel centres y=±.72m.
box('Track stone bed',(0,0,-.075),(2,2.8,.09),ASPHALT[0],.001,part='track')
for y in [-.72,.72]:
 box('Rail embedded dark groove',(0,y,-.02),(2,.11,.02),STEEL,0,part='track')
 box('Steel rail running head',(0,y,-.012),(2,.048,.024),ASPHALT[1],.001,part='track')
 for yy in [-.021,.021]:box('Rail polished edge',(0,y+yy,-.001),(2,.006,.002),STEEL,0,part='track')
for a,b in [(-1.4,-.775),(-.665,.665),(.775,1.4)]:box('Track infill',(0,(a+b)/2,-.025),(2,b-a,.026),ASPHALT[0],.001,part='track')
done('tram_track',['Track length2 width2.8; X travel, rails y±.72m; gauge1.44m matches new tram wheel tread centres coordinated with parent.'])
clean()
WATER=[mat('Lagoon turquoise','58B7B7',.3),mat('Lagoon pale','6BC4BF',.3),mat('Lagoon teal','50AEAE',.3),mat('Lagoon highlight','7CCFC8',.3)]
for m in WATER:m['keep_material']=True
box('Water slab',(0,0,-.09),(4,4,.12),WATER[0],0,part='water')
verts=[];faces=[]
N=10
for j in range(N+1):
 for i in range(N+1):
  x=-2+i*4/N;y=-2+j*4/N
  if 0<i<N and 0<j<N:x+=random.uniform(-.12,.12);y+=random.uniform(-.12,.12)
  # Tile perimeter continuous at zero; broad faceted plane variations in the interior.
  z=0 if i in [0,N] or j in [0,N] else random.uniform(-.018,.0)
  verts.append((x,y,z))
for j in range(N):
 for i in range(N):a=j*(N+1)+i;faces.extend([(a,a+1,a+N+2),(a,a+N+2,a+N+1)])
o=mesh('Broad water facets',verts,faces,WATER,part='water')
for p in o.data.polygons:p.material_index=random.choices([0,1,2,3],[6,3,3,1])[0]
done('water_tile',['4x4m .15m deep; flat stitched perimeter, irregular triangular lagoon surface.'])
report_path=ROOT/'reports/props-complete.json'
if ONLY and report_path.exists():
 old=json.loads(report_path.read_text());changed={r['name']:r for r in REPORTS};REPORTS=[changed.get(r['name'],r) for r in old]
report_path.write_text(json.dumps(REPORTS,indent=2))
print('PROPS_COMPLETE',len(REPORTS),flush=True)
