"""Puts the composition renders beside the matching 02-voxel sheet panels
(city perspectives r004: top-down, diagonal, street) in
previews/compare.png. Run compose.py first.

python3 city/tools/styles/voxel/compare.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
PREVIEWS = HERE / "previews"
SHEET = HERE.parents[3] / "docs" / "vision" / "style-studies" / "styles" / "02-voxel" / "sheets" / \
    "00-city-perspectives" / "r004" / "image.png"
# Panel boxes on the 1536 x 1024 sheet.
PANELS = {"topdown": (776, 36, 1528, 498), "diagonal": (10, 536, 760, 985), "street": (776, 536, 1528, 985)}


def main():
    sheet = Image.open(SHEET).convert("RGB")
    w, h = 750, 460
    out = Image.new("RGB", (2 * w + 30, len(PANELS) * (h + 26) + 10), (250, 246, 236))
    draw = ImageDraw.Draw(out)
    for row, (view, box) in enumerate(PANELS.items()):
        y = 10 + row * (h + 26)
        ref = sheet.crop(box).resize((w, h))
        ours = Image.open(PREVIEWS / f"compose_{view}.png").convert("RGB")
        # Crop our render to the panel's aspect, centred.
        aspect = w / h
        ow, oh = ours.size
        if ow / oh > aspect:
            cw = int(oh * aspect)
            ours = ours.crop(((ow - cw) // 2, 0, (ow - cw) // 2 + cw, oh))
        else:
            ch = int(ow / aspect)
            ours = ours.crop((0, (oh - ch) // 2, ow, (oh - ch) // 2 + ch))
        out.paste(ref, (10, y))
        out.paste(ours.resize((w, h)), (w + 20, y))
        draw.text((14, y + h + 6), f"sheet 00 r004 - {view}", fill=(40, 40, 40))
        draw.text((w + 24, y + h + 6), f"voxel kit v2 composition - {view}", fill=(40, 40, 40))
    out.save(PREVIEWS / "compare.png")
    print("compare: previews/compare.png")


main()
