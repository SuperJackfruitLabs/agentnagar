import sys,math,random
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import *
_finish=finish
def finish(name,parts=None,notes=None):
    labels={'house_a':'house','house_b':'house','house_c':'house','shop_a':'shop','tower_a':'tower','tower_b':'tower','cafe':'cafe','bridge_span':'span','bridge_pier':'pier','quay_wall':'wall'}
    if name in labels:
        for ob in bpy.context.scene.objects:
            if ob.type=='MESH':tag(ob,labels[name])
    return _finish(name,parts,notes)
S=mat('Ivory limewash','E5D5B7'); ST=mat('Warm cut limestone','C9B48F'); WO=mat('Honey teak','91633D'); IR=mat('Charcoal iron','3B4440'); GL=mat('Deep teal glazing','355456',.32); TC=[mat('Terracotta '+str(i),c) for i,c in enumerate(['B95E3D','C56E49','AA553C'])]; CU=[mat('Weathered copper '+str(i),c,.5) for i,c in enumerate(['759A88','86A291','66897D'])]; Y=mat('Sun yellow canvas','EBC351'); GR=mat('Olive foliage','718043'); FL=mat('Coral flowers','CE725B'); GOLD=mat('Brass','D8AF58',.4)
def box(n,x,y,z,w,d,h,m,part='body',b=.01): return tag(cube(n,(x,y,z),(w,d,h),m,b),part)
def extrude(n,poly,y,depth,m,part='body'):
 v=[(x,y+s*depth/2,z) for s in [-1,1] for x,z in poly];k=len(poly);f=[tuple(range(k-1,-1,-1)),tuple(range(k,2*k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
 return mesh(n,v,f,m,part)
def arch(n,x,y,spring,r,thick,depth,m,part='body',segs=12):
 for i in range(segs):
  a=math.pi*i/segs;b=math.pi*(i+1)/segs
  poly=[(x+rr*math.cos(t),spring+rr*math.sin(t)) for rr,t in [(r,a),(r+thick,a),(r+thick,b),(r,b)]]
  extrude(n+str(i),poly,y,depth,m,part)
def archedwall(n,w,h,r,spring,depth=.28,glazed=True,part='wall'):
 # Actual opening, not a glass overlay on a solid block.
 for sign in [-1,1]:box(n+' jamb',sign*(w/2+r)/2,0,spring/2,w/2-r,depth,spring,S,part)
 for i in range(16):
  x0=-r+2*r*i/16;x1=-r+2*r*(i+1)/16;z0=spring+math.sqrt(max(0,r*r-x0*x0));z1=spring+math.sqrt(max(0,r*r-x1*x1))
  extrude(n+' spandrel',[(x0,z0),(x1,z1),(x1,h),(x0,h)],0,depth,S,part)
 arch(n+' voussoir',0,-depth/2-.04,spring,r,.14,.10,ST,part)
 box(n+' cornice',0,0,h-.12,w,.42,.24,ST,part)
 if glazed:
  poly=[(-r,.22),(r,.22),(r,spring)]+[(r*math.cos(t),spring+r*math.sin(t)) for t in [i*math.pi/16 for i in range(1,17)]]
  extrude(n+' glass',poly,.02,.045,GL,part)
  for x in [-r,0,r]:box(n+' mullion',x,-.05,spring/2,.04,.055,spring,IR,part,b=0)
  arch(n+' metal arch',0,-.055,spring,r-.025,.035,.055,IR,part)
  for z in [spring*.33,spring*.66,spring]:box(n+' transom',0,-.05,z,2*r,.055,.04,IR,part,b=0)
def window(x,y,z,w,h,shutter=None,side=False):
 obs=[];before=set(bpy.context.scene.objects)
 box('Window recess',x,y,z,w,.08,h,GL)
 for xx in [x-w/2,x,x+w/2]:box('Slender mullion',xx,y-.05,z,.045,.07,h,IR,b=0)
 box('Crossbar',x,y-.05,z,w,.065,.04,IR,b=0)
 for zz in [z-h/2-.09,z+h/2+.09]:box('Stone sill',x,y,zz,w+.3,.24,.16,ST)
 if shutter:
  for sg in [-1,1]:
   xx=x+sg*(w/2+.25);box('Shutter',xx,y-.06,z,.4,.09,h,shutter)
   for zz in [-h/2+.15,h/2-.15]:box('Shutter rail',xx,y-.12,z+zz,.32,.04,.07,WO)
 if y>0:
  for ob in set(bpy.context.scene.objects)-before:ob.location.y=2*y-ob.location.y
 if side:
  for ob in set(bpy.context.scene.objects)-before:
   ob.location=((-1 if side==-1 else 1)*ob.location.y,ob.location.x,ob.location.z);ob.rotation_euler.z=(-1 if side==-1 else 1)*math.pi/2

def hip(w,d,z,rise,m):
 verts=[(-w/2,-d/2,z),(w/2,-d/2,z),(w/2,d/2,z),(-w/2,d/2,z),(-max(0,(w-d)/2),0,z+rise),(max(0,(w-d)/2),0,z+rise)]
 ob=mesh('Hip roof',verts,[(0,1,5,4),(1,2,5),(2,3,4,5),(3,0,4),(3,2,1,0)],m)
 # Coarse deliberate tile courses and ridge caps, no texture dependency.
 for i in range(1,7):
  t=i/7;ww=w*(1-t);dd=d*(1-t)
  for yy in [-dd/2,dd/2]:beam('Roof tile course',(-ww/2,yy,z+rise*t+.018),(ww/2,yy,z+rise*t+.018),.023,TC[i%3],6)
  for xx in [-ww/2,ww/2]:beam('Hip course',(xx,-dd/2,z+rise*t+.018),(xx,dd/2,z+rise*t+.018),.023,TC[i%3],6)
 for p in verts[:4]:beam('Hip ridge',p,(0,0,z+rise+.03),.07,TC[1],8)
 box('Eaves',0,0,z-.06,w,d,.12,IR)
def awning(w,y,z,part='body'):
 box('Canvas shade',0,y-.5,z,w,1.25,.06,Y,part,0).rotation_euler.x=math.radians(12)
 box('Valance',0,y-1.1,z-.17,w,.05,.20,Y,part)
 for x in [-w/2+.08,w/2-.08]:
  beam('Slim iron shade bracket',(x,y,z+.45),(x,y-1.1,z-.16),.028,IR,8,part=part);beam('Bracket brace',(x,y,z-.6),(x,y-1.1,z-.16),.022,IR,8,part=part)
def plant(x,y,z,scale=1):
 box('Stone planter',x,y,z+.2*scale,.6*scale,.55*scale,.4*scale,ST)
 for i in range(7):
  t=i*2*math.pi/7;ico('Broad tropical leaf',(x+.21*scale*math.cos(t),y+.21*scale*math.sin(t),z+.7*scale),(.11*scale,.28*scale,.40*scale),GR)
def residential(name,variant):
 clean();w=6.6;d=8.8;h=6.8
 box('Limewashed house',0,0,h/2,w,d,h,S)
 box('Stone foundation',0,0,.18,w+.08,d+.08,.36,ST)
 for x in [-w/2,w/2]:
  for y in [-d/2,d/2]:
   for i in range(10):box('Quoin',x,y,.45+i*.63,.30,.30,.26,ST)
 sh=[mat('Sage shutters','819479'),Y,TC[1]][variant]
 for z in [1.75,4.8]:
  for x in [-2.1,0,2.1]:
   if z==1.75 and x==0:continue
   window(x,-d/2-.045,z,1.0,1.65,sh)
  for xx in [-2.2,2.2]:
   window(xx,-w/2-.045,z,.8,1.5,side=True)
   window(xx,-w/2-.045,z,.8,1.5,side=-1)
 box('Door surround',0,-d/2-.13,1.42,1.4,.18,2.84,ST);box('Timber entrance',0,-d/2-.24,1.36,1.08,.12,2.65,WO)
 for x in [-.32,.32]:box('Door panel',x,-d/2-.32,1.35,.40,.06,2.25,WO)
 beam('Brass door grip',(.35,-d/2-.37,1.1),(.35,-d/2-.37,1.48),.022,GOLD)
 hip(w+.65,d+.65,h,1.45,TC)
 if variant==1:
  box('Balcony floor',-2.1,-d/2-.62,3.8,1.6,1.2,.16,WO)
  for xx in [-2.85,-1.35]:box('Balcony post',xx,-d/2-1.12,4.22,.08,.08,.8,WO)
  beam('Balcony top',(-2.85,-d/2-1.12,4.62),(-1.35,-d/2-1.12,4.62),.04,WO)
  for i in range(9):box('Balcony spindle',-2.8+i*.175,-d/2-1.12,4.23,.035,.04,.7,WO,b=0)
 if variant==2:
  extrude('Front gable',[(-1.5,6.8),(1.5,6.8),(0,8.2)],-d/2+.6,1.4,S)
  mesh('Terracotta gable cap',[(-1.58,-d/2-.18,6.82),(0,-d/2-.18,8.27),(1.58,-d/2-.18,6.82),(-1.58,-d/2+1.4,6.82),(0,-d/2+1.4,8.27),(1.58,-d/2+1.4,6.82)],[(0,1,4,3),(1,2,5,4)],TC[1])
  for xx in [-1.58,1.58]:beam('Gable roof fascia',(xx,-d/2-.18,6.82),(0,-d/2-.18,8.27),.045,IR)
 finish(name)
def build_hall(name):
 clean();p={'hall_corner':'pier','hall_sawtooth_bay':'roof','hall_sawtooth_gable':'gable','hall_door_leaves':'leaves'}.get(name,'wall')
 if name=='hall_wall':
  box('Limewash wall',0,0,2.6,4,.28,5.2,S,p)
  for i in range(9):box('Brick horizontal joint',0,-.147,.5+i*.52,4,.015,.018,ST,p,0)
 elif name=='hall_window_wall':
  for x in [-1.88,1.88]:box('Timber pier',x,0,2.6,.24,.32,5.2,WO,p)
  box('Low sill',0,0,.2,3.52,.30,.4,ST,p);box('Teal glazing',0,0,2.8,3.52,.06,4.8,GL,p)
  for x in [-1.75,0,1.75]:box('Slim frame',x,-.08,2.8,.06,.1,4.8,IR,p,0)
  for z in [.44,3.25,5.15]:box('Transom',0,-.08,z,3.52,.1,.07,IR,p,0)
  awning(3.48,-.16,3.1,p)
 elif name=='hall_door_wall':
  for x in [-1.15,1.15]:box('Limestone door jamb',x,0,2.6,.30,.30,5.2,S,p)
  box('Lintel',0,0,4.25,2.6,.34,1.9,S,p);box('Inset sign border',0,-.2,4.3,2.25,.1,.68,ST,p);box('Blank sign',0,-.26,4.3,2.08,.02,.5,S,p)
 elif name=='hall_corner':box('Timber corner',0,0,2.6,.30,.30,5.2,WO,p)
 elif name=='hall_door_leaves':
  for y in [-.07,.07]:box('Folded teak leaf',0,y,1.6,.25,.06,3.2,WO,p)
  beam('Folded handle',(.09,-.12,1.35),(.09,-.12,1.7),.018,IR,part=p)
 elif name=='hall_sawtooth_bay':
  # x slopes from low west to high east, north south ridge.
  ob=mesh('Terracotta slope',[(-2,-2,.1),(2,-2,2.35),(2,2,2.35),(-2,2,.1)],[(0,1,2,3)],TC,p)
  box('Clerestory',1.94,0,1.22,.08,4,2.25,GL,p)
  for yy in [-2,-1,0,1,2]:box('Clerestory frame',2,yy,1.22,.08,.045,2.3,IR,p,0)
  for yy in [-2,2]:beam('Slope teak fascia',(-2,yy,.1),(2,yy,2.35),.065,WO,part=p)
  for yy in [-1.33,-.66,0,.66,1.33]:beam('Tile seam',(-2,yy,.12),(2,yy,2.37),.016,TC[1],6,part=p)
  box('Ridge flashing',2,0,2.36,.12,4,.08,TC[1],p)
 elif name=='hall_sawtooth_gable':
  extrude('Triangle glazing',[(-2,.1),(2,.1),(2,2.35)],0,.08,GL,p)
  for a,b in [((-2,0,.1),(2,0,2.35)),((-2,0,.1),(2,0,.1)),((2,0,.1),(2,0,2.35))]:beam('Gable iron frame',a,b,.045,IR,part=p)
  for xx in [-1,0,1]:box('Gable mullion',xx,-.05,.1+(xx+2)*.28125,.04,.055,(xx+2)*.5625,IR,p,0)
 finish(name,notes=['Hall module authored for 4m bay and 5.2m wall; entrance has clear 2m by 3.2m opening.'])
def build_library(name):
 clean();p={'lib_dome':'dome','lib_column':'column','lib_entrance':'entrance','lib_banner':'banner','lib_door_leaves':'leaves'}.get(name,'wall')
 if name=='lib_wall_arch':archedwall('Library',2,8,.67,6.3,.28,True,p)
 elif name=='lib_entrance':
  # Above the walk aperture a true arch with dark fanlight.
  archedwall('Entrance',2.6,8,1,5.45,.30,False,p)
  poly=[(-1,2.8),(1,2.8),(1,5.45)]+[(math.cos(i*math.pi/16),5.45+math.sin(i*math.pi/16)) for i in range(1,17)]
  extrude('Fanlight',poly,.02,.04,GL,p)
  for x in [-.7,-.35,0,.35,.7]:box('Fanlight mullion',x,-.05,4.4,.035,.05,3.2,IR,p,0)
  box('Transom above clear door',0,0,2.89,2,.30,.18,WO,p)
 elif name=='lib_column':
  for z,r,d in [(.25,.25,.5),(.56,.18,.16),(3.8,.125,6.3),(7.12,.18,.20),(7.35,.23,.26)]:cylinder('Column stone', (0,0,z),r,d,ST,12,part=p)
  box('Square capital',0,0,7.56,.58,.34,.15,S,p)
 elif name=='lib_banner':
  extrude('Swallowtail canvas',[(-.52,0),(.52,0),(.52,-3.75),(0,-3.3),(-.52,-3.75)],-.10,.025,Y,p)
  beam('Banner pole',(-.65,0,0),(.65,0,0),.03,IR,part=p)
  # Original botanical mark: stem + three pointed leaves.
  box('Emblem stem',0,-.128,-1.8,.045,.02,1.0,S,p,0)
  for sg in [-1,1]:extrude('Emblem leaf',[(0,-1.9),(sg*.3,-1.6),(sg*.24,-1.28),(0,-1.6)],-.13,.012,S,p)
  extrude('Emblem top',[(0,-1.65),(-.15,-1.28),(0,-.94),(.15,-1.28)],-.13,.012,S,p)
 elif name=='lib_door_leaves':
  for y in [-.10,.10]:box('Folded panel leaf',0,y,1.4,.25,.075,2.8,WO,p)
  beam('Brass pull',(.08,-.155,1.15),(.08,-.155,1.5),.018,GOLD,part=p)
 elif name=='lib_dome':
  # Local drum starts at roof datum, not the ground. Ref cupola top silhouette.
  N=24;r=4.45;drum=1.9
  cylinder('Round clerestory drum',(0,0,drum/2),r,drum,S,N,part=p)
  for i in range(N):
   a=2*math.pi*i/N;x=(r+.016)*math.sin(a);y=(r+.016)*math.cos(a)
   ob=box('Drum window',x,y,1.0,.55,.06,1.28,GL,p);ob.rotation_euler.z=-a
   beam('Drum pilaster',(x,y,.12),(x,y,1.8),.075,ST,8,part=p)
  for zz,rr,dd in [(0,4.54,.18),(1.84,4.56,.20)]:cylinder('Drum cornice',(0,0,zz),rr,dd,ST,N,part=p)
  rows=7;verts=[]
  for j in range(rows+1):
   theta=(math.pi/2)*j/rows;rr=r*math.cos(theta);zz=drum+3.4*math.sin(theta)
   verts.extend([(rr*math.cos(2*math.pi*i/N),rr*math.sin(2*math.pi*i/N),zz) for i in range(N)])
  ob=mesh('Faceted copper dome',verts,[(j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i) for j in range(rows) for i in range(N)],CU,p)
  for poly in ob.data.polygons:poly.material_index=(poly.index//N+poly.index%N)%3
  for i in range(N):
   for j in range(rows):beam('Fine copper rib',verts[j*N+i],verts[(j+1)*N+i],.018,CU[2],6,part=p)
  cylinder('Lantern',(0,0,5.3),.48,.55,CU[1],12,part=p);cylinder('Lantern cap',(0,0,5.67),.64,.24,CU[0],12,radius2=.3,part=p);cylinder('Finial',(0,0,6.12),.08,.65,GOLD,8,radius2=0,part=p)
 finish(name,notes=['Library dome begins at local roof datum and contains a 1.9m clerestory drum; runtime places at 7.8m.','Door modules retain true clear 2m wide walking opening below 2.8m.'])
def shop():
 clean();w=4.9;d=8.8;h=6.9
 box('Shop body',0,0,h/2,w,d,h,S);box('Shop foundation',0,0,.16,w,d,.32,ST)
 for x in [-1.6,0,1.6]:window(x,-d/2-.04,5.1,.95,1.85)
 for z in [1.7,5.1]:
  window(0,-w/2-.04,z,.9,1.5,side=True)
  window(0,-w/2-.04,z,.9,1.5,side=-1)
 box('Storefront glazing',-.6,-d/2-.07,1.6,3.1,.09,2.6,GL)
 for x in [-2.2,-1.1,0,.9]:box('Storefront mullion',x,-d/2-.14,1.6,.075,.10,2.7,WO)
 box('Shop door',1.65,-d/2-.1,1.48,1.2,.13,2.7,WO);box('Door glass',1.65,-d/2-.18,1.72,.85,.035,1.88,GL)
 box('Blank fascia',0,-d/2-.1,3.58,w,.17,.65,ST);box('Blank sign surface',0,-d/2-.20,3.58,w-.25,.03,.45,S)
 awning(w,-d/2-.2,3.0);hip(w+.5,d+.5,h,1.35,TC)
 box('Juliet balcony base',0,-d/2-.36,4.03,1.2,.5,.14,ST)
 for x in [-.56,.56]:beam('Juliet post',(x,-d/2-.59,4.1),(x,-d/2-.59,4.85),.027,IR)
 beam('Juliet handrail',(-.56,-d/2-.59,4.85),(.56,-d/2-.59,4.85),.03,IR)
 for i in range(7):beam('Juliet spindle',(-.5+i/6,-d/2-.59,4.1),(-.5+i/6,-d/2-.59,4.85),.018,IR)
 for x in [-2.2,2.2]:plant(x,-d/2-.65,0,.8)
 finish('shop_a')
def cafe():
 clean();w=6;d=5;h=3.5
 # Shell sides and back, clear arcaded facade.
 box('Cafe rear',0,d/2-.1,h/2,w,.20,h,S)
 for x in [-2.9,2.9]:box('Cafe side',x,0,h/2,.20,d,h,S)
 box('Interior floor',0,0,.05,w,d,.1,ST)
 for x in [-2.8,-.95,.95,2.8]:box('Arcade pier',x,-2.43,1.05,.3,.32,2.1,S);box('Pier base',x,-2.45,.2,.44,.45,.4,ST)
 for x in [-1.87,0,1.87]:
  arch('Cafe arcade',x,-2.43,2.05,.77,.18,.32,ST)
  # Spandrel above arches is original extruded polygon.
  for i in range(12):
   x0=-.92+1.84*i/12;x1=-.92+1.84*(i+1)/12
   z0=2.05+math.sqrt(max(0,.92*.92-x0*x0));z1=2.05+math.sqrt(max(0,.92*.92-x1*x1))
   extrude('Arcade spandrel',[(x+x0,z0),(x+x1,z1),(x+x1,h),(x+x0,h)],-2.43,.26,S)
 window(-1.87,-1.9,1.5,1.3,1.5)
 box('Serving counter',-1.87,-2.04,.7,1.5,.4,.14,WO)
 box('Cafe double doors',0,-1.9,1.4,1.5,.10,2.6,WO)
 for x in [-.39,.39]:box('Door glass',x,-1.96,1.65,.57,.035,1.65,GL)
 plant(1.87,-1.7,0,.9)
 window(0,-w/2-.11,1.7,.7,1.0,side=True)
 window(0,-w/2-.11,1.7,.7,1.0,side=-1)
 box('Cafe sign border',0,-2.59,3.25,2.5,.08,.37,ST);box('Cafe blank sign',0,-2.65,3.25,2.3,.03,.25,S)
 hip(w+.4,d+.4,h,.8,TC);awning(w-.2,-2.59,2.88)
 # Restrained bougainvillea on one corner.
 for i in range(10):
  z=.4+i*.34;ico('Climbing leaves',(-2.93,-2.6,z),(.24,.16,.26),GR)
  if i%2==0:ico('Bougainvillea',(-3.04,-2.73,z+.05),(.12,.08,.11),FL)
 finish('cafe')
def tower(name,variant):
 clean();height=3.0
 for floor in range(8):
  z=floor*height;w=11.2 if floor<3 else (9.5 if floor<6 else (7.0 if floor==6 else 4.8));d=w
  cx=(.7 if variant and floor>=3 else 0);cy=(.4 if variant and floor>=6 else 0)
  box('Limestone storey',cx,cy,z+1.5,w,d,3,S)
  box('Belt cornice',cx,cy,z+.12,w+.26,d+.26,.24,ST)
  for i in range(max(2,int(w/2.5))):
   xx=cx-w/2+(i+.5)*w/max(2,int(w/2.5));window(xx,cy-d/2-.04,z+1.52,1.25,2.05)
   # Back glazing also gives proper silhouette from every direction.
   window(xx,cy+d/2+.05,z+1.52,1.25,2.05)
  for i in range(max(2,int(d/2.5))):
   yy=cy-d/2+(i+.5)*d/max(2,int(d/2.5));window(yy,cx-w/2-.04,z+1.52,1.25,2.05,side=True);window(yy,cx+w/2+.04,z+1.52,1.25,2.05,side=True)
  for x in [cx-w/2,cx+w/2]:
   for y in [cy-d/2,cy+d/2]:box('Corner pilaster',x,y,z+1.5,.22,.22,2.8,ST)
  if floor in [2,5,6,7]:
   box('Terrace coping',cx,cy,z+2.95,w+.35,d+.35,.15,ST)
   for x in [cx-w/2+.4,cx+w/2-.4]:plant(x,cy-d/2+.35,z+3,.7)
 box('Entrance canopy',0,-5.9,2.9,2.6,1.15,.16,WO);box('Entrance frame',0,-5.65,1.45,2,.18,2.9,WO);box('Entrance glass',0,-5.76,1.45,1.62,.035,2.52,GL)
 for x in [-4.5,4.5]:plant(x,-5.9,0,1.1)
 if variant==0:cylinder('Brass rooftop finial',(0,0,24.65),.24,1.3,GOLD,8,radius2=0)
 finish(name,notes=['Eight storeys, designed stepped setbacks. 24m roof; facade iron kept slender.'])
def bridge(name):
 clean();p='body'
 if name=='bridge_span':
  # Walking surface at .9 above local runtime origin -0.9; arches below.
  box('Bridge stone deck',0,0,.76,8,4,.28,S)
  # Underdeck arch clear down to -1.6, segmental arch rising to .4.
  for yy in [-1.9,1.9]:
   for i in range(16):
    x0=-4+i*.5;x1=x0+.5
    z0=-1.6+2*math.sqrt(max(0,1-(x0/4)**2));z1=-1.6+2*math.sqrt(max(0,1-(x1/4)**2))
    extrude('Arch spandrel',[(x0,z0),(x1,z1),(x1,.62),(x0,.62)],yy,.2,ST)
    # Clear wedge voussoir below spandrel.
    extrude('Arch stone',[(x0,z0-.20),(x1,z1-.20),(x1,z1),(x0,z0)],yy,.26,S)
   box('Parapet curb',0,yy,.99,8,.20,.18,ST)
   for x in [-3.65,0,3.65]:box('Parapet stone post',x,yy,1.45,.32,.34,1.1,S);box('Post cap',x,yy,2.02,.42,.44,.14,ST)
   for zz in [1.18,1.86]:beam('Slim iron railing',(-3.65,yy,zz),(3.65,yy,zz),.035,IR,8)
   for i in range(38):beam('Iron spindle',(-3.65+i*(7.3/37),yy,1.18),(-3.65+i*(7.3/37),yy,1.86),.018,IR,6)
 elif name=='bridge_pier':
  box('Pier core',0,0,-.45,1.35,4,2.5,ST)
  for yy in [-2.12,2.12]:
   cylinder('Cutwater',(0,yy,-.8),.72,1.8,S,8,radius2=.54)
   cylinder('Cutwater pointed cap',(0,yy,.27),.60,.65,S,8,radius2=0)
   box('Parapet pier',0,yy,1.42,.46,.46,1.1,S);box('Pier cap',0,yy,2.02,.58,.58,.15,ST)
  box('Pier deck',0,0,.77,1.4,4,.26,S)
 elif name=='quay_wall':
  box('Quay masonry',0,0,-1.2,4,.7,2.4,ST);box('Quay coping',0,0,.05,4,.86,.16,S)
  for j in range(5):
   zz=-2.1+j*.43
   box('Masonry course',0,-.357,zz,4,.015,.018,S,b=0)
   for i in range(4):box('Masonry joint',-1.5+i+(j%2)*.5,-.357,zz+.21,.015,.015,.41,S,b=0)
 finish(name,notes=['Deck top at local +0.90m matches runtime origin -0.90m. Parapet clear inner half width 1.8m.'] if name!='quay_wall' else [])
if '--tower-only' in sys.argv:
 tower('tower_a',0);tower('tower_b',1)
elif '--facade-only' in sys.argv:
 for i,n in enumerate(['house_a','house_b','house_c']):residential(n,i)
 shop();cafe()
elif '--bridge-only' in sys.argv:
 for n in ['bridge_span','bridge_pier','quay_wall']:bridge(n)
else:
 for n in ['hall_wall','hall_window_wall','hall_door_wall','hall_corner','hall_sawtooth_bay','hall_sawtooth_gable','hall_door_leaves']:build_hall(n)
 for n in ['lib_wall_arch','lib_column','lib_entrance','lib_dome','lib_banner','lib_door_leaves']:build_library(n)
 for i,n in enumerate(['house_a','house_b','house_c']):residential(n,i)
 shop();cafe();tower('tower_a',0);tower('tower_b',1)
 for n in ['bridge_span','bridge_pier','quay_wall']:bridge(n)
