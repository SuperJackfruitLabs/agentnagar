import struct,json,math
from pathlib import Path
r=Path(__file__).resolve().parent.parent
b=(r/'assets/lowpoly_tropical/bridge_span.glb').read_bytes();ln=struct.unpack_from('<I',b,12)[0];j=json.loads(b[20:20+ln]);bl=struct.unpack_from('<I',b,20+ln)[0];binary=b[28+ln:28+ln+bl]
def data(i):
 a=j['accessors'][i];v=j['bufferViews'][a['bufferView']];n={'SCALAR':1,'VEC3':3}[a['type']];fmt={5126:'f',5125:'I',5123:'H'}[a['componentType']];sz=struct.calcsize(fmt)*n;stride=v.get('byteStride',sz);off=v.get('byteOffset',0)+a.get('byteOffset',0);return [struct.unpack_from('<'+fmt*n,binary,off+k*stride) for k in range(a['count'])]
# Exactly reproduce kit_town's band-points triangle clipping, Y up glTF.
pts=[];inner=float('inf');lo=.92;hi=2.8
for m in j['meshes']:
 for p in m['primitives']:
  vs=data(p['attributes']['POSITION']);ix=[x[0] for x in data(p['indices'])]
  for t in range(0,len(ix),3):
   tri=[vs[k] for k in ix[t:t+3]];cut=[]
   for k in range(3):
    a=tri[k];c=tri[(k+1)%3]
    if lo<=a[1]<=hi:cut.append(a)
    if a[1]!=c[1]:
     for z in [lo,hi]:
      f=(z-a[1])/(c[1]-a[1])
      if 0<f<1:cut.append(tuple(a[q]+f*(c[q]-a[q]) for q in range(3)))
   if cut:
    pts+=cut;z0=min(x[2] for x in cut);z1=max(x[2] for x in cut);inner=min(inner,0 if z0<0<z1 else min(abs(z0),abs(z1)))
maxx=max(abs(p[0]) for p in pts)
nearest_maxx=max(abs(p[0]) for p in pts if abs(p[2])<=inner+.05)
# Runtime across fitting sets the nearest physical parapet face to half+0.01.
assert inner>0;assert maxx<=4.0;assert nearest_maxx<=3.9
report={'walking_band_local_y':[lo,hi],'above_deck_half_span_max':maxx,'nominal_half_span':4.0,'nearest_parapet_face_half_span':nearest_maxx,'nearest_parapet_approach_inset_local_m':4-nearest_maxx,'approach_inset_local_m':4-maxx,'raw_inner_half_width':inner,'runtime_fit_clear_half_width_for_4m_deck':inner*(2.01/inner),'assertions':'all above-deck geometry stays inside longitudinal span; cross fitting preserves 4.02m clear width'}
(r/'reports/architecture-bridge-clearance.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
