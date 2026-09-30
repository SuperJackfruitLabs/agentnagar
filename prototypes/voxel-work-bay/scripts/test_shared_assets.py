"""Regression tests for the exported shared workshop; standard-library only."""
import hashlib,json,struct,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'godot/assets/workshop'

def glb(path):
    raw=path.read_bytes(); n=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+n]),raw[28+n:]

def accessor(doc,blob,index):
    a=doc['accessors'][index]; v=doc['bufferViews'][a['bufferView']]
    fmt={5126:'f',5125:'I',5123:'H',5121:'B'}[a['componentType']]
    count={'SCALAR':1,'VEC3':3}[a['type']]; size=struct.calcsize(fmt)*count
    return [struct.unpack_from('<'+fmt*count,blob,v.get('byteOffset',0)+a.get('byteOffset',0)+i*v.get('byteStride',size)) for i in range(a['count'])]

def _stub_blender_modules_for_table_import():
    """character.py and geometry.py `import bpy`/`mathutils` at module level
    for mesh authoring, but RESIDENTS itself is plain data (strings and
    function references never called at import time). This file otherwise
    runs under plain python3, with no Blender process behind it, so a
    minimal stand-in lets the table be inspected without launching Blender."""
    import sys, types
    if 'bpy' not in sys.modules:
        bpy_stub = types.ModuleType('bpy')
        bpy_stub.data = types.SimpleNamespace()
        bpy_stub.context = types.SimpleNamespace()
        bpy_stub.ops = types.SimpleNamespace()
        sys.modules['bpy'] = bpy_stub
    if 'mathutils' not in sys.modules:
        mathutils_stub = types.ModuleType('mathutils')
        mathutils_stub.Vector = object
        mathutils_stub.Euler = object
        sys.modules['mathutils'] = mathutils_stub

class SharedAssets(unittest.TestCase):
    def test_layout_and_clearance(self):
        d=json.loads((OUT/'layout.json').read_text())
        self.assertEqual(d['version'],1)
        self.assertEqual(len([i for i in d['instances'] if i['group']=='roof']),6)
        self.assertEqual(len({i['id'] for i in d['instances']}),len(d['instances']))
        for i in d['instances']: self.assertTrue((ROOT/'godot/assets'/i['asset']).exists())
        # Body corridor through east doorway at heights 0.05..2.19, z .31..1.69.
        for c in d['collisions']:
            x,y,z=c['position']; sx,sy,sz=c['size']
            if abs(c['rotation_y'])%180==90:sx,sz=sz,sx
            self.assertFalse(x-sx/2<6.15 and x+sx/2>5.85 and y+sy/2>.05 and y-sy/2<2.19 and z+sz/2>.31 and z-sz/2<1.69,c['id'])
        self.assertTrue(any(Path(i['asset']).stem in PAVED and i['position']==[7,0,1] for i in d['instances']),'no paved landing outside the east doorway')
    def test_manifest_and_geometry(self):
        m=json.loads((ROOT/'shared-workshop-manifest.json').read_text())
        for name,h in m['recipe_sha256'].items(): self.assertEqual(hashlib.sha256((ROOT/'scripts'/name).read_bytes()).hexdigest(),h)
        self.assertEqual(hashlib.sha256((ROOT/'source/shared-workshop.blend').read_bytes()).hexdigest(),m['source_sha256'])
        self.assertEqual(hashlib.sha256((OUT/'layout.json').read_bytes()).hexdigest(),m['layout_sha256'])
        for name,a in m['assets'].items():
            p=ROOT/a['file']; self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),a['sha256'])
            d,b=glb(p); volume=0; top_area=0
            for mesh in d['meshes']:
                for prim in mesh['primitives']:
                    vs=accessor(d,b,prim['attributes']['POSITION']); normals=accessor(d,b,prim['attributes']['NORMAL']); ids=[i[0] for i in accessor(d,b,prim['indices'])]
                    for j in range(0,len(ids),3):
                        p,q,r=[vs[k] for k in ids[j:j+3]]
                        u=[q[k]-p[k] for k in range(3)]; v=[r[k]-p[k] for k in range(3)]
                        cross=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0])
                        self.assertGreater(sum(cross[k]*normals[ids[j]][k] for k in range(3)),0,'Winding/normal mismatch: '+name)
                        if name in PAVED|{'floor'} and all(abs(v[1])<1e-6 for v in (p,q,r)):
                            top_area+=abs((q[0]-p[0])*(r[2]-p[2])-(q[2]-p[2])*(r[0]-p[0]))/2
                        volume+=(p[0]*(q[1]*r[2]-q[2]*r[1])+p[1]*(q[2]*r[0]-q[0]*r[2])+p[2]*(q[0]*r[1]-q[1]*r[0]))/6
            self.assertGreater(volume,0,name)
            if name in PAVED|{'floor'}:self.assertLess(top_area,4.01,'Coplanar duplicate top surfaces: '+name)
        for name,width in [('floor',2),('wall',2),('window',2),('door',2),('roof',4.0),('path_corner',2),('path_t',2),('railing',2),('awning',2)]:
            d,b=glb(OUT/(name+'.glb')); xs=[]
            for mesh in d['meshes']:
                for p in mesh['primitives']:xs.extend(v[0] for v in accessor(d,b,p['attributes']['POSITION']))
            self.assertAlmostEqual(max(xs)-min(xs),width,places=4)



PAVED={'path','path_corner','path_t'}
# Canonical local arms before rotation, as (dx,dz) grid steps in Godot axes.
ARMS={'path':[(1,0),(-1,0)],'path_corner':[(0,-1),(1,0)],'path_t':[(-1,0),(1,0),(0,1)]}
DOORWAY=(6.0,1.0)   # hall threshold; a west arm may terminate here instead of on a tile.
GRID=2.0

def turn(arm,rot):
    """Rotate a local arm exactly as layout() rotates its collision proxies."""
    from math import radians,sin,cos
    a=radians(rot);x,z=arm
    return (round(cos(a)*x+sin(a)*z),round(-sin(a)*x+cos(a)*z))

class CourtyardKit(unittest.TestCase):
    def setUp(self):
        self.d=json.loads((OUT/'layout.json').read_text())
        self.paved={}
        for i in self.d['instances']:
            name=Path(i['asset']).stem
            if name in PAVED:self.paved[(i['position'][0],i['position'][2])]=(name,i['rotation_y'])

    def test_every_arm_reaches_paving_or_the_doorway(self):
        self.assertTrue(self.paved,'no paved tiles in layout')
        for (x,z),(name,rot) in sorted(self.paved.items()):
            for arm in ARMS[name]:
                dx,dz=turn(arm,rot)
                target=(x+dx*GRID,z+dz*GRID)
                edge=(x+dx*GRID/2,z+dz*GRID/2)   # an arm may instead die on the hall threshold
                reached=target in self.paved or (abs(edge[0]-DOORWAY[0])<1e-6 and abs(edge[1]-DOORWAY[1])<1e-6)
                self.assertTrue(reached,f'{name} at {(x,z)} rot {rot} has an arm to {target} with nothing to walk onto')

    def test_no_paved_neighbour_is_left_unconnected(self):
        for (x,z),(name,rot) in sorted(self.paved.items()):
            open_arms={turn(a,rot) for a in ARMS[name]}
            for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
                if (x+dx*GRID,z+dz*GRID) in self.paved:
                    self.assertIn((dx,dz),open_arms,f'{name} at {(x,z)} rot {rot} abuts paving to {(dx,dz)} with no arm facing it')

    def test_public_route_is_a_closed_loop(self):
        nodes=set(self.paved);edges=set()
        for x,z in nodes:
            for dx,dz in ((1,0),(0,1)):
                n=(x+dx*GRID,z+dz*GRID)
                if n in nodes:edges.add(((x,z),n))
        seen=set();stack=[next(iter(nodes))]
        while stack:
            c=stack.pop()
            if c in seen:continue
            seen.add(c)
            for dx,dz in ((1,0),(-1,0),(0,1),(0,-1)):
                n=(c[0]+dx*GRID,c[1]+dz*GRID)
                if n in nodes and n not in seen:stack.append(n)
        self.assertEqual(seen,nodes,'paved tiles are not all connected')
        # A tree has nodes-1 edges; a closed circuit needs at least one more.
        self.assertGreaterEqual(len(edges),len(nodes),'public route is a dead end, not a closed loop')

    def test_perimeter_railing_has_no_gaps(self):
        runs={}
        for i in self.d['instances']:
            if Path(i['asset']).stem!='railing':continue
            x,_,z=i['position'];rot=i['rotation_y']%180
            key=('z',z) if rot==0 else ('x',x)
            centre=x if rot==0 else z
            runs.setdefault(key,[]).append((centre-1.0,centre+1.0))
        self.assertTrue(runs,'no railing placed on the courtyard perimeter')
        for key,spans in runs.items():
            spans.sort()
            for (_,end),(start,_) in zip(spans,spans[1:]):
                self.assertLessEqual(start,end+1e-6,f'railing run {key} has a gap at {end}..{start}')

    def test_awning_clears_the_walking_head_height(self):
        boxes=[c for c in self.d['collisions'] if c['id'].startswith('awning')]
        self.assertTrue(boxes,'awning contributes no collision proxy')
        for c in boxes:
            self.assertGreaterEqual(c['position'][1]-c['size'][1]/2,2.4-1e-6,f"{c['id']} hangs below 2.4 m head clearance")

    def test_hall_and_courtyard_remain_flush(self):
        """GS-014 is Blocked because this rise is zero; fail if that ever changes silently."""
        tops={}
        for name in ('floor','path'):
            doc,blob=glb(OUT/(name+'.glb'));ys=[]
            for mesh in doc['meshes']:
                for prim in mesh['primitives']:ys.extend(v[1] for v in accessor(doc,blob,prim['attributes']['POSITION']))
            tops[name]=max(ys)
        self.assertAlmostEqual(tops['floor'],0,places=6)
        self.assertAlmostEqual(tops['path'],0,places=6)
        self.assertAlmostEqual(tops['floor']-tops['path'],0,places=6,msg='a threshold rise now exists; GS-014 must be re-specified')

class HallEnvelope(unittest.TestCase):
    def setUp(self):
        self.d=json.loads((OUT/'layout.json').read_text())

    def test_hall_is_twelve_by_sixteen_metres(self):
        floors=[i['position'] for i in self.d['instances'] if i['asset']=='workshop/floor.glb']
        self.assertEqual(len(floors),48)
        xs=sorted({p[0] for p in floors}); zs=sorted({p[2] for p in floors})
        self.assertEqual(xs,[-5,-3,-1,1,3,5])
        self.assertEqual(zs,[-7,-5,-3,-1,1,3,5,7])

    def test_three_sawtooth_bays_cover_the_wider_hall(self):
        roof=[i for i in self.d['instances'] if i['group']=='roof']
        self.assertEqual(len(roof),6,'three bays, two 8 m modules deep each')
        self.assertEqual(sorted({i['position'][0] for i in roof}),[-4,0,4])
        self.assertEqual(sorted({i['position'][2] for i in roof}),[-4,4])

    def test_doorway_moved_east_with_the_wall(self):
        doors=[i for i in self.d['instances'] if i['asset']=='workshop/door.glb']
        self.assertEqual(len(doors),1)
        self.assertEqual(doors[0]['position'],[6,0,1])

    def test_every_bay_holds_a_resident(self):
        self.assertEqual(len(self.d['stations']),14,'all fourteen bays are occupied')
        origins=sorted((s['origin'][0],s['origin'][2]) for s in self.d['stations'])
        self.assertEqual(sorted({x for x,_ in origins}),[-3,3])
        for zone in (-3,3):
            zs=sorted(z for x,z in origins if x==zone)
            self.assertEqual(zs,[-6,-4,-2,0,2,4,6])
        for asset in ('desk.glb','terminal.glb','chair.glb'):
            self.assertEqual([i for i in self.d['instances'] if i['asset']==asset],[],
                             'stations furnish their own bays; no reserved furniture should remain')

    def test_stations_are_seated_in_roster_order(self):
        import sys
        _stub_blender_modules_for_table_import()
        sys.path.insert(0,str(ROOT/'scripts'))
        from character import RESIDENTS
        expected_order=sorted(RESIDENTS,key=lambda k:RESIDENTS[k]['roster'])
        actual_order=[s['resident'] for s in self.d['stations']]
        self.assertEqual(actual_order,expected_order,'stations must be seated in roster order (GR01-GR14)')
        by_resident={s['resident']:s['origin'] for s in self.d['stations']}
        self.assertEqual(by_resident['kai'],[-3,0,0],"Kai (GR04) must stay at [-3,0,0]")
        self.assertEqual(by_resident['lyra'],[-3,0,2],"Lyra (GR05) must stay at [-3,0,2]")

if __name__=='__main__':unittest.main()
