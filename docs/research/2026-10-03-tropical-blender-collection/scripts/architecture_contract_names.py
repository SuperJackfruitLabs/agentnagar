import sys,json,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from assetkit import *
labels={'house_a':'house','house_b':'house','house_c':'house','shop_a':'shop','tower_a':'tower','tower_b':'tower','cafe':'cafe','bridge_span':'span','bridge_pier':'pier','quay_wall':'wall'}
p=ROOT/'assets'/'lowpoly_tropical'
for n,label in labels.items():
 clean();meta=json.loads((p/(n+'.json')).read_text())
 source=Path('/tmp')/('architecture-contract-'+n+'.blend');shutil.copyfile(p/(n+'.blend'),source)
 with bpy.data.libraries.load(str(source),link=False) as (src,dst):dst.objects=src.objects
 for ob in dst.objects:
  if ob and ob.type=='MESH':bpy.context.collection.objects.link(ob);ob.parent=None;tag(ob,label)
  elif ob:bpy.data.objects.remove(ob)
 finish(n,notes=meta['notes'])
