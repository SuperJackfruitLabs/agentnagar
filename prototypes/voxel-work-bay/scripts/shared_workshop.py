"""Reusable courtyard kit and layout, authored in metres with Y-up recipes.

Every rendered cuboid is original; geometry.Blocks supplies outward winding.
Collision proxies follow solid cuboids, with deliberate open windows and door.
"""
from math import sin,cos,radians
from geometry import Blocks,label
from character import RESIDENTS


def kit(materials):
    assets={}; solids={}
    def begin(name):
        nonlocal b,key
        key=name;b=Blocks('Shared_'+name,materials);solids[name]=[]
    def box(p,s,c,solid=False):
        b.box((p[0],-p[2],p[1]),(s[0],s[2],s[1]),c)
        if solid or key=='roof':solids[key].append((p,s))
    def end():assets[key]=[b.finish()]
    b=None;key=''
    begin('floor');box((0,-.115,0),(2,.17,2),'wood');solids['floor'].append(((0,-.10,0),(2,.2,2)))
    for x in range(4):
        for z in range(2):box((-.75+x*.5,-.0125,-.5+z),(.488,.025,.986),'wood_light' if (x+z)%3 else 'wood_honey')
    end()
    for kind in ('wall','window','door'):
        begin(kind)
        if kind=='wall':box((0,1.4,0),(2,2.8,.18),'cream',True)
        else:
            width=1.4 if kind=='door' else 1.5
            bottom=0 if kind=='door' else .9;top=2.2
            for x in (-1+(2-width)/4,1-(2-width)/4):box((x,1.4,0),((2-width)/2,2.8,.18),'cream',True)
            box((0,(top+2.8)/2,0),(width,2.8-top,.18),'cream',True)
            if bottom:box((0,bottom/2,0),(width,bottom,.18),'cream',True)
            # Open clerestory-style window: structural frame, no opaque fake glass.
            if kind=='window':
                box((0,.91,0),(1.5,.08,.23),'wood_light',True)
                box((0,1.55,0),(.045,1.3,.12),'cobalt',True)
                box((0,2.18,0),(1.5,.06,.21),'wood_light',True)
        for x in (-.95,.95):box((x,1.4,-.105),(.1,2.8,.07),'wood_honey')
        if kind!='door':box((0,.18,-.11),(2,.36,.06),'cobalt')
        box((0,2.71,-.105),(2,.18,.09),'wood_light')
        end()
    begin('roof')
    # Three sawtooth bays are preserved in count; the wider hall widens each bay.
    w=4.0
    for step in range(8):
        y=2.86+step*.105
        box((-w/2+(step+.5)*w/8,y,0),(w/8,.14,8),'orange')
        # Stepped north/south fascia closes the triangular gables.
        for z in (-3.95,3.95):box((-w/2+(step+.5)*w/8,(2.8+y)/2,z),(w/8,y-2.8,.08),'orange')
    box((w/2-.055,3.15,0),(.11,.7,8),'sky')
    for z in (-3.92,-2,0,2,3.92):box((w/2-.09,3.15,z),(.13,.78,.10),'cobalt')
    for z in (-3.8,0,3.8):box((0,2.77,z),(w,.16,.14),'wood_dark')
    end()
    begin('path');box((0,-.123,0),(2,.174,2),'sand');solids['path'].append(((0,-.105,0),(2,.21,2)))
    for x in (-.5,.5):
        for z in (-.5,.5):box((x,-.016,z),(.972,.032,.972),'cream' if x==z else 'ivory')
    end()
    begin('lawn');box((0,-.11,0),(2,.22,2),'green',True);end()
    # Junction tiles share one grammar: a cobalt marker stud, a paved strip per
    # open arm, and corner pavers. Closed sides leave the sand base showing.
    def junction(name,arms):
        begin(name);box((0,-.123,0),(2,.174,2),'sand');solids[name].append(((0,-.105,0),(2,.21,2)))
        box((0,-.016,0),(.44,.032,.44),'cobalt')
        for x in (-.62,.62):
            for z in (-.62,.62):box((x,-.016,z),(.7,.032,.7),'cream' if x==z else 'ivory')
        for dx,dz in arms:
            box((dx*.66,-.016,dz*.66),(.62 if dx else .6,.032,.6 if dx else .62),'ivory')
        end()
    junction('path_corner',((1,0),(0,-1)))
    junction('path_t',((-1,0),(1,0),(0,1)))
    begin('railing')
    # One 2 m protective panel; a single continuous proxy keeps joins solid.
    for x in (-.94,.94):box((x,.55,0),(.12,1.1,.12),'navy')
    box((0,1.04,0),(2,.12,.1),'wood_light');box((0,.62,0),(2,.08,.08),'cobalt');box((0,.22,0),(2,.1,.08),'cobalt')
    solids['railing'].append(((0,.55,0),(2,1.1,.14)))
    end()
    begin('awning')
    # Cantilevered entrance canopy projecting +X from the wall plane over 4 m of
    # frontage. Underside stays at or above 2.44 m so the doorway corridor is clear.
    for step in range(5):box((.2+step*.4,2.67-step*.04,0),(.4,.14,4),'orange')
    box((1.95,2.52,0),(.1,.14,4),'orange_dark')
    for z in (-1.4,1.4):
        box((.06,2.6,z),(.12,.36,.18),'cobalt')
        for step in range(5):box((.2+step*.4,2.76-step*.04,z),(.4,.06,.14),'cobalt')
    solids['awning'].append(((1,2.52,0),(2,.14,4)))
    end()
    begin('planter');box((0,.22,0),(1.3,.44,.7),'cream',True);box((0,.43,0),(1.22,.09,.62),'wood_dark')
    for x in (-.42,0,.42):
        box((x,.66,0),(.43,.38,.48),'leaf');box((x,.9,.04),(.29,.18,.3),'leaf_light')
    end()
    begin('tree');box((0,.15,0),(1.7,.3,1.7),'cream',True);box((0,.32,0),(1.5,.06,1.5),'wood_dark')
    box((0,1.35,0),(.32,2.1,.32),'wood',True)
    for p,s,c in [((0,2.5,0),(1.7,1.1,1.65),'green'),((-.65,2.72,.1),(.95,.7,1.2),'leaf'),((.55,2.85,-.1),(1,.85,1.1),'leaf'),((0,3.35,0),(.9,.5,.9),'leaf_light'),((.1,2.6,.78),(.8,.6,.55),'leaf')]:box(p,s,c)
    end()
    begin('bench');box((0,.76,0),(2,.12,.72),'wood_light',True)
    for x in (-.85,.85):
        for z in (-.25,.25):box((x,.35,z),(.1,.7,.1),'navy',True)
    box((-.5,.86,0),(.48,.08,.36),'cobalt');box((.35,.87,-.08),(.25,.1,.3),'orange');end()
    begin('shelf')
    for x in (-.9,.9):box((x,1.1,0),(.09,2.2,.48),'navy',True)
    for y in (.2,.85,1.5,2.15):box((0,y,0),(2,.09,.55),'wood_light',True)
    for x in (-.62,0,.62):
        for y in (.43,1.08,1.73):
            box((x,y,0),(.42,.35,.43),'orange' if x==0 else 'cobalt')
            box((x,y,.222),(.17,.07,.012),'paper')
    end()
    begin('sign');box((0,1.1,0),(.09,2.2,.09),'wood_dark',True);box((0,1.9,0),(1.7,.6,.12),'cobalt',True);end()
    # Text faces local +Z (east after a +90 degree instance rotation).
    assets['sign'].append(label('WORKSHOP', (0,-.069,1.97),.19,materials['ivory']))
    assets['sign'].append(label('SAMPLE / 02', (0,-.07,1.76),.10,materials['orange']))
    return assets,solids


# Roster order: GR01-GR07 west zone north to south, GR08-GR14 east zone.
BAYS=[(-3,z) for z in (-6,-4,-2,0,2,4,6)]+[(3,z) for z in (-6,-4,-2,0,2,4,6)]


def _roster_stations():
    # RESIDENTS is the single source of truth for roster order; the table's
    # 'roster' field (1-14) is not derivable from the dict's key order, since
    # GS numbers do not follow GR order (Kai is GS-030 but GR04). Sorting on
    # it here means BAYS never has to be re-listed alongside the cast.
    order=sorted(RESIDENTS,key=lambda k:RESIDENTS[k]['roster'])
    numbers=sorted(RESIDENTS[k]['roster'] for k in RESIDENTS)
    assert numbers==list(range(1,15)),f'roster numbers must be exactly 1-14 with no duplicates, got {numbers}'
    assert len(order)==len(BAYS)==14,'fourteen residents must map onto fourteen bays'
    return [{'resident':name,'origin':[x,0,z]} for name,(x,z) in zip(order,BAYS)]


def layout(solids):
    # Roster order seats GR01-GR07 in the west zone north to south, GR08-GR14
    # east zone north to south; Kai is GR04 and Lyra GR05, so they land at
    # [-3,0,0] and [-3,0,2] respectively.
    d={'version':1,'bounds':{'min':[-6.3,0,-8.5],'max':[12.5,4,8.5]},
       'stations':_roster_stations(),
       'instances':[],'collisions':[]}
    def put(name,pos,group='structure',rot=0):
        id=f'{name}_{len(d["instances"]):03}'
        d['instances'].append({'id':id,'asset':f'workshop/{name}.glb','position':list(pos),'rotation_y':rot,'group':group})
        a=radians(rot)
        for n,(p,s) in enumerate(solids[name]):
            d['collisions'].append({'id':f'{id}_{n}','position':[round(pos[0]+cos(a)*p[0]+sin(a)*p[2],6),pos[1]+p[1],round(pos[2]-sin(a)*p[0]+cos(a)*p[2],6)],'size':list(s),'rotation_y':rot})
    # Hall is 12 x 16 m on the 2 m grid, with the doorway on the east wall.
    HALL_X=(-5,-3,-1,1,3,5); HALL_Z=(-7,-5,-3,-1,1,3,5,7)
    for x in HALL_X:
        for z in HALL_Z:put('floor',(x,0,z))
        put('window' if abs(x)<4 else 'wall',(x,0,-8))
        put('window' if abs(x)<4 else 'wall',(x,0,8),'front',180)
    for z in HALL_Z:
        put('window' if abs(z)<4 else 'wall',(-6,0,z),rot=90)
        put('door' if z==1 else 'window' if abs(z)<4 else 'wall',(6,0,z),'front',90)
    for x in (-4,0,4):
        for z in (-4,4):put('roof',(x,0,z),'roof')
    # Closed public loop around a central planted island, translated one metre
    # east so it stays clear of the enlarged hall. Geometry is unchanged.
    loop={(7,1):('path_t',270),(7,-1):('path_corner',270),(9,-1):('path',0),
          (11,-1):('path_corner',180),(11,1):('path',90),(11,3):('path_corner',90),
          (9,3):('path',0),(7,3):('path_corner',0)}
    for x in (7,9,11):
        for z in (-3,-1,1,3):
            name,rot=loop.get((x,z),('lawn',0))
            put(name,(x,0,z),'courtyard',rot)
    put('tree',(9.2,0,1),'courtyard')
    for p in ((7,0,-3),(9,0,-3),(11,0,-3)):put('planter',p,'courtyard')
    put('awning',(6,0,1),'front')
    for z in (-3,-1,1,3):put('railing',(12,0,z),'courtyard',90)
    for x in (7,9,11):
        put('railing',(x,0,-4),'courtyard')
        put('railing',(x,0,4),'courtyard',180)
    put('sign',(6.5,0,2.9),'decor',90)
    # Every bay now holds a station; workshop_station.gd furnishes each one
    # (desk, terminal, chair) from the resident's key, so no reserved-bay
    # furniture or collision proxies are emitted here.
    for x in (-1,1):put('shelf',(x,0,-7.55),'decor');put('bench',(x,0,7.1),'decor')
    return d
