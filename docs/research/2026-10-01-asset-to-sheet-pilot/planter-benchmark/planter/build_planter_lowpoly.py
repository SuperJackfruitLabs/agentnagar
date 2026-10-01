"""The square planter (planter_square.glb) for the low-poly tropical kit, drawn as its sheet draws it and
painted from the sheet's colours.

    blender --background --factory-startup --python planter/build_planter_lowpoly.py -- OUT.glb [PARAMS.json]

The kit's planter is a limewash box with one clipped ball of a shrub. The sheet's (WATERFRONT PARK) is a pale
stone box brimming with broad-leaved tropical plants, yellow and pink blossoms among them. This one is the
kit's box, 1.3 m square as the catalogue's footprint has it, with the kit's own leafy rosettes (`leafy_plant`)
standing thick in it and the kit's own blossoms (`flower`). Nothing leafy reaches outside the footprint: the
game would squeeze the whole planter if it did.

Box and leaves are painted from the sheet's ramps (planter/ramps.json) by shade.py, through marks.py; the
blossoms and the soil keep the kit's colours.
"""
import json
import math
import os
import random
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index("--") + 1:]
out = Path(argv[0])
HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
STYLE = json.loads((TOOLS / "city" / "godot" / "styles" / "lowpoly_tropical" / "style.json").read_text())
CONFIG = json.loads((HERE / "asset.json").read_text())
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / "lowpoly"))
import lib  # noqa: E402
import vegetation as veg  # noqa: E402
from lib import Mesh  # noqa: E402
import marks  # noqa: E402

P = marks.settings(STYLE)
P["ranges"] = {"box": {"tops": [0.55, 1.0], "sides": [0.1, 0.85], "under": [0.0, 0.2]},
               "leaf": {"tops": [0.3, 1.0], "sides": [0.1, 0.8], "under": [0.0, 0.35]}}
P["weights"] = {"box": {"up": {"facing": 0.2, "sky": 0.3, "group": 0.3, "grain": 0.2},
                        "rest": {"facing": 0.55, "sky": 0.2, "group": 0.15, "grain": 0.1}},
                "leaf": {"up": {"facing": 0.15, "sky": 0.25, "group": 0.35, "grain": 0.25},
                         "rest": {"facing": 0.25, "sky": 0.25, "group": 0.3, "grain": 0.2}}}
if len(argv) > 1 and Path(argv[1]).exists():
    P.update(json.loads(Path(argv[1]).read_text()))
ramps = json.loads((HERE / "ramps.json").read_text())["lowpoly_tropical"]

lib.reset()
rng = random.Random(41)
m = Mesh()
marked = marks.Marks(m, P)
S, H = 1.3, 0.5                      # the footprint's side; the box's height
m.box((S - 0.07, S - 0.07, H), (0, 0, H / 2), "limewash", bevel=0.02)
marked.mark("box", "wall")
m.box((S, S, 0.08), (0, 0, H + 0.01), "limewash_shade", bevel=0.02)
marked.mark("box", "coping")
m.box((S - 0.2, S - 0.2, 0.04), (0, 0, H + 0.04), "soil")
marked.mark(None, "soil")
# Plants: one tall rosette in the middle, a ring of five lower ones, and small ones in the corners.
REACH = S / 2 - 0.02                 # nothing leafy beyond this: the footprint's edge
first = len(m.bm.verts)
spots = [(0.0, 0.0, H + 0.14, 1.25, 11)]
for k in range(6):
    a = 2 * math.pi * k / 6 + 0.4
    spots.append((0.3 * math.cos(a), 0.3 * math.sin(a), H + 0.06, rng.uniform(0.85, 1.0), 9))
for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
    spots.append((sx * 0.44, sy * 0.44, H + 0.04, 0.6, 6))
starts = []
for k, (x, y, z, size, leaves) in enumerate(spots):
    start = len(m.bm.verts)
    veg.leafy_plant(m, (x, y, z), size, leaves=leaves, seed=43 + k, colours=("leaf_light", "leaf", "leaf_dark"))
    # A plant's leaves are drawn in where they would reach past the footprint.
    m.bm.verts.ensure_lookup_table()
    mine = list(m.bm.verts)[start:]
    far = max(max(abs(v.co.x), abs(v.co.y)) for v in mine)
    if far > REACH:
        f = (REACH - max(abs(x), abs(y))) / (far - max(abs(x), abs(y)))
        for v in mine:
            v.co.x, v.co.y = x + (v.co.x - x) * f, y + (v.co.y - y) * f
    marked.mark("leaf", ("plant", k), turn="up")
# Blossoms among the leaves: yellow and pink, as the sheet has them.
blooms = 0
for k in range(16):
    a = 2 * math.pi * k / 16 + rng.uniform(-0.15, 0.15)
    r = rng.uniform(0.12, 0.5)
    z = H + 0.42 + 0.3 * (1 - r / 0.5) + rng.uniform(-0.05, 0.08)
    veg.flower(m, (r * math.cos(a), r * math.sin(a), z), ("jackfruit", "pink", "jackfruit", "coral")[k % 4], r=0.07, seed=600 + k)
    blooms += 1
marked.mark(None, "blossoms")
assert len(marked.entries) == len(m.bm.faces)
veg.finish("planter_square", {"body": m})
import bake  # noqa: E402
import bpy  # noqa: E402
bake.bake_scene()
bpy.context.view_layer.update()
stats = marks.paint({"body": marked.entries}, ramps, STYLE, P, CONFIG["kinds"])
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
print(f"BUILD planter lowpoly: wrote {out} ({lib.triangles()} triangles, {len(spots)} plants, {blooms} blossoms) {json.dumps(stats)}")
