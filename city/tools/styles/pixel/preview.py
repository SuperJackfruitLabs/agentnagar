"""Previews of the pre-rendered kit, for reviewing it against sheet 08.

python3 city/tools/styles/pixel/preview.py [ASSETS_DIR] [OUT_DIR]

Writes (default OUT_DIR: city/tools/styles/pixel/previews/, gitignored):

* `contact.png` / `contact_2x.png`: every kit sprite on a neutral ground,
  day above night, grouped by folder;
* `compare.png`: sheet 08/00's Diagonal panel (2x, left) beside the
  scene at 1:1 (right), for the written comparison;
* `scene.png` / `scene_2x.png` / `scene_night.png`: a small district
  assembled from the modules the way the pack does it (façade slices,
  corners and roofs placed at their anchors, y-sorted by ground point),
  in the spirit of the sheet's Diagonal panel.
"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import models  # noqa: E402

DEFAULT_ASSETS = HERE.parents[2] / "godot" / "styles" / "pixel_art" / "assets"
DEFAULT_OUT = HERE / "previews"
SHEET = HERE.parents[3] / "docs" / "vision" / "style-studies" / "styles" / "08-pixel-art" / "sheets" / \
    "00-city-perspectives" / "r005" / "image.png"
KIT_DIRS = ("buildings", "scenery", "ground")


def iso(x, z, y=0.0):
    return (round((x - z) * 16.0), round((x + z) * 8.0 - y * 16.0))


class Scene:
    """Sprites placed at ground points and drawn in y-sort order, like the
    pack's Node2D tree: ground tiles first, then everything by the screen y
    of its sort point (ties in insertion order)."""

    def __init__(self, assets, night=False):
        self.assets = Path(assets)
        self.night = night
        self.anchors = json.loads((self.assets / "anchors.json").read_text())
        self.tiles = []
        self.items = []
        self.cache = {}

    def img(self, rel):
        key = rel if not self.night else rel.replace(".png", "_night.png")
        if key not in self.cache:
            self.cache[key] = Image.open(self.assets / key).convert("RGBA")
        return self.cache[key]

    def tile(self, rel, x, z):
        self.tiles.append((rel, iso(x + 0.5, z + 0.5)))

    def put(self, rel, x, z, lift=0.0, sort=None):
        at = iso(x, z)
        at = (at[0], at[1] - round(lift * 16))
        s = iso(*(sort if sort is not None else (x, z)))
        self.items.append((s[1], len(self.items), rel, at))

    def render(self, pad=24, bg=(158, 204, 238)):
        placed = []
        for rel, at in self.tiles:
            im = self.img(rel)
            placed.append((im, (at[0] - 16, at[1] - 8)))
        for _, _, rel, at in sorted(self.items):
            im = self.img(rel)
            ax, ay = self.anchors[rel]
            placed.append((im, (at[0] - ax, at[1] - ay)))
        x0 = min(p[0] for _, p in placed) - pad
        y0 = min(p[1] for _, p in placed) - pad
        x1 = max(p[0] + im.width for im, p in placed) + pad
        y1 = max(p[1] + im.height for im, p in placed) + pad
        canvas = Image.new("RGBA", (x1 - x0, y1 - y0), (*bg, 255) if not self.night else (22, 26, 52, 255))
        for im, (px, py) in placed:
            canvas.alpha_composite(im, (px - x0, py - y0))
        return canvas


# ---- Assembly, as pack v2 would do it ----

def facade_plan(length, doors, banners=False):
    """Module names for a face of `length` metres with 2 m doorways whose
    openings start at the given offsets: each opening a door_m a metre
    between its reveals door_l and door_r, banners beside doorways
    (library), 2 m window bays, a plain metre where a bay does not fit."""
    names = [None] * length
    for d in doors:
        names[d], names[d + 1] = "door_m", "door_m"
        for k, name in ((d - 1, "door_l"), (d + 2, "door_r")):
            if 0 <= k < length and names[k] is None:
                names[k] = name
        if banners:
            for b in (d - 2, d + 3):
                if 0 <= b < length and names[b] is None:
                    names[b] = "banner"
    k = 0
    while k < length:
        if names[k] is None:
            if k + 1 < length and names[k + 1] is None:
                names[k], names[k + 1] = "wall_0", "wall_1"
                k += 2
                continue
            names[k] = "plain"
        k += 1
    return names


def building(scene, folder, x0, z0, x1, z1, doors, roof, wall_top, open_=False, extras=(), banners=False):
    """Façades on all four sides (far sides seen from inside), corners and
    the roof, as the pack assembles them: the walls stand in the ring WALL
    deep outside the rooms (x0..x1, z0..z1); every slice sorts at its own
    ground point; the roof sorts at the ring's south-east corner, above
    every wall slice; cut-away hides the roof and swaps the near (south,
    east) façades for their low twins (an opening has none)."""
    wall = models.WALL
    plan = lambda n, side: facade_plan(n, doors.get(side, []), banners)  # noqa: E731
    low = lambda name: None if name == "door_m" else "low"  # noqa: E731
    for k, name in enumerate(plan(x1 - x0, "north")):
        scene.put(f"{folder}/s_{name}.png", x0 + k + 1, z0)
    for k, name in enumerate(plan(z1 - z0, "west")):
        scene.put(f"{folder}/e_{name}.png", x0, z0 + k + 1)
    for k, name in enumerate(plan(x1 - x0, "south")):
        shown = low(name) if open_ else name
        if shown:
            scene.put(f"{folder}/s_{shown}.png", x0 + k + 1, z1 + wall)
    for k, name in enumerate(plan(z1 - z0, "east")):
        shown = low(name) if open_ else name
        if shown:
            scene.put(f"{folder}/e_{shown}.png", x1 + wall, z0 + k + 1)
    corner = f"{folder}/corner{'_low' if open_ else ''}.png"
    h = wall / 2
    for cx, cz in ((x0 - h, z0 - h), (x1 + h, z0 - h), (x0 - h, z1 + h), (x1 + h, z1 + h)):
        scene.put(corner, cx, cz)
    if open_:
        return
    se = (x1 + wall, z1 + wall)
    if roof == "sawtooth":
        for t in range((x1 - x0) // 4):
            xb = x0 + 4 * t + 4
            for k in range(z0, z1):
                piece = "roof_n" if k == z0 else "roof_s" if k == z1 - 1 else "roof_mid"
                scene.put(f"{folder}/{piece}.png", xb, k + 1, lift=wall_top, sort=se)
    elif roof == "flat":
        for zz in range(z0, z1):
            for xx in range(x0, x1):
                scene.put(f"{folder}/roof.png", xx + 0.5, zz + 0.5, lift=wall_top, sort=se)
    for rel, x, z in extras:
        scene.put(rel, x, z, lift=wall_top, sort=se)


def tower(scene, x, z, mids):
    """A tower's stacked pieces, all sorted at its south-east corner."""
    scene.put("buildings/blocks/tower_base.png", x, z)
    for k in range(mids):
        scene.put("buildings/blocks/tower_mid.png", x, z, lift=models.TOWER_BASE + k * models.TOWER_STOREY)
    scene.put("buildings/blocks/tower_top.png", x, z, lift=models.TOWER_BASE + mids * models.TOWER_STOREY)


def district(assets, night=False, open_=False):
    """A slice of the district laid out like the sheet's Diagonal panel."""
    s = Scene(assets, night)
    W, E, N, S = -27, 46, -22, 42
    for z in range(N, S):
        for x in range(W, E):
            if x < -15:
                name = f"ground/water_{(x + z) % 2}.png"
            elif x == -15:
                name = "ground/quay_w.png" if False else "ground/kerb_w.png" if 23 <= z <= 28 else "ground/path.png"
            elif 23 <= z <= 28 or -6 <= z <= -2:
                top, bottom = (23, 28) if z > 0 else (-6, -2)
                if z == top:
                    name = "ground/kerb_n.png"
                elif z == bottom:
                    name = "ground/kerb_s.png"
                elif z == 25:
                    name = "ground/track_x.png"
                elif z == (27 if z > 0 else -4) and x % 4 < 2:
                    name = "ground/street_dash_x.png"
                elif z == 26 and x % 20 in (9, 10):
                    name = "ground/crossing_x.png"
                else:
                    name = "ground/street.png"
            elif x < -8 or z >= 30 or z < -7:
                name = f"ground/grass_{(x * 5 + z * 3) % 2}.png"
            else:
                name = f"ground/paving_{(x * 7 + z * 13) % 4}.png"
            s.tile(name, x, z)
    # Buildings: hall west of the square, library east, towers and houses around.
    building(s, "buildings/hall", -8, 2, 8, 16, {"south": [7]}, "sawtooth", models.HALL_H, open_=open_)
    building(s, "buildings/library", 28, 2, 42, 16, {"south": [6]}, "flat", models.LIB_H, open_=open_,
             extras=[("buildings/library/dome.png", 35.0, 9.0)], banners=True)
    for x in (2, 17, 32):
        tower(s, x, -9, 4 if x != 17 else 5)
    for rel, x, z in (("house_a", 41, -9), ("house_c", 46, -9), ("house_b", -6, -9), ("house_a", -11, -9),
                      ("house_b", -4, 40), ("house_c", 2, 40), ("shop_a", 8, 39), ("house_a", 14, 40),
                      ("house_b", 30, 40), ("shop_a", 36, 39), ("house_c", 42, 40)):
        s.put(f"buildings/blocks/{rel}.png", x, z)
    # The tree square.
    s.put("scenery/tree_square.png", 18, 9)
    for (x, z) in ((14, 5), (22, 5), (14, 13), (22, 13)):
        s.put("scenery/planter.png", x, z)
    for (x, z) in ((18, 3.6), (18, 14.6)):
        s.put("scenery/bench_x.png", x, z)
    for (x, z) in ((12.4, 9), (23.6, 9)):
        s.put("scenery/bench_z.png", x, z)
    for (x, z) in ((11, 3), (25, 3), (11, 15), (25, 15), (11, 20), (25, 20), (18, 20), (4, 20), (32, 20), (40, 20)):
        s.put("scenery/lamp.png", x, z)
    for (x, z) in ((15, 18), (21, 18), (30, 18.5), (36, 18.5)):
        s.put("scenery/flowerbed_0.png", x, z)
    for (x, z) in ((16, 21.6), (20, 21.6), (8.6, 21.6)):
        s.put("scenery/bollard.png", x, z)
    s.put("scenery/tram_shelter_180.png", 13, 22.2)
    # Café terrace by the hall.
    for (x, z) in ((-5, 18.5), (-1, 18.5), (3, 18.5)):
        s.put("scenery/cafe_set.png", x, z)
        s.put("scenery/umbrella.png", x - 0.1, z - 0.2)
    for x in (-3, 1, 5):
        s.put("scenery/planter_pot.png", x, 17)
    # Street trees and the park.
    for x in range(-12, 46, 4):
        if not (8 < x < 28):
            s.put("scenery/tree_round_a.png" if x % 8 else "scenery/tree_round_b.png", x + 0.5, 21.5)
        s.put("scenery/tree_round_b.png" if x % 8 else "scenery/tree_round_a.png", x + 1.5, 31.5)
        s.put("scenery/tree_round_a.png" if x % 8 else "scenery/tree_round_b.png", x + 1.0, -0.5)
    for (x, z, rel) in ((-12, 4, "palm_tall"), (-11, 9, "palm_short"), (-13, 13, "palm_tall"), (-10, 17, "shrub"),
                        (-12, 19, "palm_short"), (-10, 1, "shrub")):
        s.put(f"scenery/{rel}.png", x, z)
    for (x, z) in ((10, 11), (26, 11), (10, 6), (26, 6)):
        s.put("scenery/tree_round_b.png", x, z)
    # The tram on its line, and the bridge over the river.
    n = len([k for k in s.anchors if k.startswith("scenery/tram/back_")])
    for i in range(n):
        s.put(f"scenery/tram/back_{i:02d}.png", 4 + i + 0.5, 25.5 + models.TRAM_BACK_Z)
    for i in range(n):
        s.put(f"scenery/tram/front_{i:02d}.png", 4 + i + 0.5, 25.5 + models.TRAM_FRONT_Z)
    cells = ["end_w_0", "end_w_1"] + [f"span_{k % 4}" for k in range(8)] + ["end_e_0", "end_e_1"]
    for i, name in enumerate(cells):
        x = -28 + i
        s.put(f"scenery/bridge/{name}_back.png", x + 1, 25.5 - models.BRIDGE_W)
        s.put(f"scenery/bridge/{name}_front.png", x + 1, 25.5 + models.BRIDGE_W)
    return s


def contact(assets, night=False, scale=1):
    assets = Path(assets)
    rels = sorted(p.relative_to(assets).as_posix() for d in KIT_DIRS for p in (assets / d).rglob("*.png")
                  if not p.name.endswith("_night.png"))
    ims = [(r, Image.open(assets / (r if not night else r.replace(".png", "_night.png"))).convert("RGBA")) for r in rels]
    width = 1400
    x = y = 8
    row_h = 0
    boxes = []
    for r, im in ims:
        if x + im.width + 8 > width:
            x, y = 8, y + row_h + 16
            row_h = 0
        boxes.append((r, im, x, y))
        x += im.width + 10
        row_h = max(row_h, im.height)
    canvas = Image.new("RGBA", (width, y + row_h + 24), (120, 150, 110, 255) if not night else (22, 26, 52, 255))
    d = ImageDraw.Draw(canvas)
    for r, im, bx, by in boxes:
        canvas.alpha_composite(im, (bx, by))
        d.text((bx, by + im.height + 1), Path(r).stem[:14], fill=(255, 255, 255, 200))
    if scale != 1:
        canvas = canvas.resize((canvas.width * scale, canvas.height * scale), Image.NEAREST)
    return canvas


def main():
    assets = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_ASSETS
    out = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUT
    out.mkdir(parents=True, exist_ok=True)
    contact(assets).save(out / "contact.png")
    contact(assets, scale=2).save(out / "contact_2x.png")
    contact(assets, night=True).save(out / "contact_night.png")
    day = district(assets).render()
    day.save(out / "scene.png")
    day.resize((day.width * 2, day.height * 2), Image.NEAREST).save(out / "scene_2x.png")
    district(assets, night=True).render().save(out / "scene_night.png")
    district(assets, open_=True).render().save(out / "scene_open.png")
    if SHEET.exists():
        sheet = Image.open(SHEET).convert("RGBA").crop((6, 505, 760, 980))
        sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
        cx = (day.width - sheet.width) // 2 + 60
        ours = day.crop((cx, 200, cx + sheet.width, 200 + sheet.height))
        pair = Image.new("RGBA", (sheet.width * 2 + 16, sheet.height), (24, 28, 48, 255))
        pair.alpha_composite(sheet, (0, 0))
        pair.alpha_composite(ours, (sheet.width + 16, 0))
        pair.save(out / "compare.png")
    print(f"pixel previews in {out}")


if __name__ == "__main__":
    main()
