"""The square planter (planter_square.glb) for the anime, solarpunk and neon kits: the kit's own planter,
painted from the style's sheet.

    blender --background --factory-startup --python planter/build_planter_kit.py -- KIT OUT.glb [PARAMS.json]

In these three styles the kit's planter is already the sheet's (a stone box and a clipped leafy shrub; a timber
crate and a flowering shrub; a dark concrete box lit at its foot), so the shape is left alone: the kit's own
`planter_square()` builds it. What differs from the sheets is colour. Its faces are sorted by their baked
colours (marks.by_colour): leaf cards and green faces are `leaf`, the box's palette colours are `box`, and
flowers, soil and lamps keep the kit's colours. Then shade.py paints leaf and box from the sheet's ramps.
"""
import json
import os
import sys
from pathlib import Path

argv = sys.argv[sys.argv.index("--") + 1:]
kit, out = argv[0], Path(argv[1])
HERE = Path(__file__).resolve().parent
TOOLS = HERE.parent
ROOT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
PACK = {"anime": "anime_cel", "solarpunk": "solarpunk", "neon": "neon_noir"}[kit]
STYLE = json.loads((TOOLS / "city" / "godot" / "styles" / PACK / "style.json").read_text())
CONFIG = json.loads((HERE / "asset.json").read_text())
# The box's colours in each kit's palette (the neon kit recolours the anime kit's stone to these).
BOX = {"anime": ("stone_dark", "stone"), "solarpunk": ("timber", "timber_light", "timber_dark"),
       "neon": ("concrete", "stone_dark")}[kit]
sys.path.insert(0, str(TOOLS))
sys.path.insert(0, str(ROOT / "shared"))
sys.path.insert(0, str(ROOT / kit))
import lib  # noqa: E402  (this kit's palette and exporter)
import vegetation as veg  # noqa: E402
import marks  # noqa: E402

P = marks.settings(STYLE, toon=kit == "anime")
P["fix_winding"] = True                    # the kit's boxes are wound inside out
P["ranges"] = {"box": {"tops": [0.5, 1.0], "sides": [0.1, 0.85], "under": [0.0, 0.2]}}
P["weights"] = {"box": {"up": {"facing": 0.2, "sky": 0.3, "group": 0.3, "grain": 0.2},
                        "rest": {"facing": 0.5, "sky": 0.2, "group": 0.2, "grain": 0.1}}}
if len(argv) > 2 and Path(argv[2]).exists():
    P.update(json.loads(Path(argv[2]).read_text()))
ramps = json.loads((HERE / "ramps.json").read_text())[PACK]

sys.modules["lib"] = lib
lib.reset()
veg.planter_square()
import bake  # noqa: E402  (tools/styles/shared: palette colours into vertex colours, as the kits' builds do)
import bpy  # noqa: E402
bake.bake_scene()
bpy.context.view_layer.update()
# Under leaf cards the kit puts dark hearts: they stay in the ramp's dark half. The solarpunk kit's shrub is
# solid clumps with no cards, so its faces take the whole ramp by how they face.
hearts = None if kit == "solarpunk" else (0.0, 0.45)
entries = marks.by_colour(P, {"box": [lib.rgb(name) for name in BOX]}, leaf_from=0.5, cell=0.25, hearts=hearts)
stats = marks.paint(entries, ramps, STYLE, P, CONFIG["kinds"])
out.parent.mkdir(parents=True, exist_ok=True)
lib.export(out)
count = {k: sum(1 for rows in entries.values() for e in rows if e and e[0] == k) for k in CONFIG["kinds"]}
print(f"BUILD planter {kit}: wrote {out} ({lib.triangles()} triangles; faces by kind {count}) {json.dumps(stats)}")
