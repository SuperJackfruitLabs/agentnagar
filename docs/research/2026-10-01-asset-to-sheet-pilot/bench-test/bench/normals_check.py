import sys, os
from pathlib import Path
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(ROOT / "shared")); sys.path.insert(0, str(ROOT / "lowpoly"))
import lib
from lib import Mesh
from mathutils import Vector
lib.reset()
for bevel in (0.0, 0.012):
    m = Mesh(); m.box((1.0, 0.4, 0.2), (0, 0, 1.0), "wood", bevel=bevel)
    m.bm.normal_update()
    out_ = sum(1 for f in m.bm.faces if f.normal.dot(f.calc_center_median() - Vector((0, 0, 1.0))) > 0)
    print(f"NORMALS box bevel {bevel}: {len(m.bm.faces)} faces, {out_} point outward")
m = Mesh(); m.beam((0, 0, 0), (0, 0.2, 1.0), 0.07, "iron"); m.bm.normal_update()
c = Vector((0, 0.1, 0.5))
print(f"NORMALS beam: {len(m.bm.faces)} faces, {sum(1 for f in m.bm.faces if f.normal.dot(f.calc_center_median() - c) > 0)} point outward")
m = Mesh(); m.slab([(0.2, 0.0), (0.2, 0.4), (-0.2, 0.4), (-0.2, 0.0)], [], 0.07, (0, 0, 0), "wood", axis="x"); m.bm.normal_update()
c = Vector((0, 0, 0.2))
print(f"NORMALS slab: {len(m.bm.faces)} faces, {sum(1 for f in m.bm.faces if f.normal.dot(f.calc_center_median() - c) > 0)} point outward; centre {tuple(round(v, 3) for v in sum((f.calc_center_median() for f in m.bm.faces), Vector()) / len(m.bm.faces))}")
