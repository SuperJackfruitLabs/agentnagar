"""The pixel-art pack's bench sprites (scenery/seats/bench_<facing>.png, sixteen facings), from a model drawn
as the sheet draws its bench. Runs before the pixel kit's render.py in the same Blender session:

    [PARAMS=FILE.json] blender --background --factory-startup --python-exit-code 1 \
        --python bench/pixel_bench_pre.py --python city/tools/styles/pixel/render.py -- RAW_DIR seat_bench

It swaps the model behind every `seat_bench_<facing>` sprite and leaves the rest of the kit (camera, passes,
the 32-colour palette, outline, dither, night twins) exactly as it is.

The sheet's bench: dark brown slats whose tops catch the light, with dark gaps between them, on thin navy
posts. The kit's: mid-brown slats, three to the back at 12 cm (under two pixels each at this scale, so they
run together into one dithered panel). This one has two broad back planks with a gap a pixel wide and three
broad seat planks, dark with lit tops as the
sheet's do: the back in the kit's dark timber with a lit top edge, the seat in the kit's timber, whose tops
come out mid brown and whose sides dark. Its size where people walk is the kit's (the catalogue's footprint).
"""
import json
import os
import sys
from pathlib import Path

KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(KIT / "pixel"))
sys.path.insert(0, str(KIT / "lowpoly"))
import models  # noqa: E402

P = {"seat_timber": "wood", "back_timber": "wood_dark", "cap": "wood", "frame": "metal", "seat": [0.40, 0.48],
     "back": [[0.55, 0.72], [0.78, 0.95]]}
if os.environ.get("PARAMS") and Path(os.environ["PARAMS"]).exists():
    P.update(json.loads(Path(os.environ["PARAMS"]).read_text()))


def bench(turn):
    def build():
        m = models.Model()
        m.turn = -turn
        # Godot axes: x along the bench, z toward the back, y up (the kit's seat model's own).
        for k in range(3):                                   # the seat: three broad planks
            z = -0.25 + k * 0.175
            m.box(-0.8, 0.8, z, z + 0.16, P["seat"][0], P["seat"][1], P["seat_timber"])
        for y0, y1 in P["back"]:                             # the back: two broad planks, a gap between,
            m.box(-0.8, 0.8, 0.27, 0.35, y0, y1 - 0.03, P["back_timber"])   # dark, their top edges lit
            m.box(-0.8, 0.8, 0.27, 0.35, y1 - 0.03, y1, P["cap"])
        for x in (-0.76, 0.76):                              # thin dark posts and an arm rail
            m.box(x - 0.04, x + 0.04, -0.23, 0.33, 0.0, P["seat"][0], P["frame"])
            m.box(x - 0.04, x + 0.04, 0.27, 0.35, P["seat"][0], 0.97, P["frame"])
            m.box(x - 0.04, x + 0.04, -0.25, 0.35, 0.6, 0.66, P["frame"])
        return m.build("bench")
    return build


swapped = 0
for spec in models.KIT:
    if spec["name"].startswith("seat_bench_"):
        spec["build"] = bench(spec["info"]["facing"])
        swapped += 1
print(f"PIXEL bench: {swapped} facings swapped")
