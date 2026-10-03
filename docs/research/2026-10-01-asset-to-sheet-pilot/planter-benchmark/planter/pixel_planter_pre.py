"""The pixel-art pack's planter sprite (scenery/planter.png), from a model drawn as the sheet draws its
planters. Runs before the pixel kit's render.py in the same Blender session:

    blender --background --factory-startup --python-exit-code 1 \
        --python planter/pixel_planter_pre.py --python city/tools/styles/pixel/render.py -- RAW_DIR planter

It swaps the model behind the `planter` sprite and leaves the rest of the kit (camera, passes, the 32-colour
palette, outline, dither, night twin) exactly as it is.

The sheet's planter: a box of grey stone blocks, full of plants with blossoms all over them. The kit's: a
smooth sand-coloured box under a ring of shrub balls with one flowering ball on top. This one is a box in the
kit's coursed stone, with a low heap of small leaf clumps, most of them the kit's flowering kind. Its size
where people walk is the kit's (the catalogue's footprint).
"""
import math
import os
import random
import sys
from pathlib import Path

KIT = Path(os.environ["AGENTNAGAR"]) / "city" / "tools" / "styles"
sys.path.insert(0, str(KIT / "pixel"))
sys.path.insert(0, str(KIT / "lowpoly"))
import models  # noqa: E402


def build():
    m = models.Model()
    lo, hi = models.PLANTER
    m.box(lo, hi, lo, hi, 0.0, 0.52, "stone")                       # coursed grey stone
    m.box(lo + 0.13, hi - 0.13, lo + 0.13, hi - 0.13, 0.5, 0.54, "soil")
    rng = random.Random(51)
    for k in range(7):                                              # a ring of small clumps, blossoms on most
        a = 2 * math.pi * k / 7
        m.sphere(math.cos(a) * 0.34, math.sin(a) * 0.34, 0.76 + rng.uniform(0, 0.1), 0.3,
                 models.mv("flowers" if k % 3 else "shrub", rng.randrange(256)), sub=2, scale=(1, 1, 0.9), jitter=0.12, seed=60 + k)
    for k in range(3):                                              # and a few standing higher in the middle
        a = 2 * math.pi * k / 3 + 0.5
        m.sphere(math.cos(a) * 0.12, math.sin(a) * 0.12, 1.0 + 0.07 * k, 0.28, models.mv("flowers", 60 + 70 * k), sub=2,
                 jitter=0.12, seed=70 + k)
    return m.build("planter")


for spec in models.KIT:
    if spec["name"] == "planter":
        spec["build"] = build
        print("PIXEL planter: model swapped")
