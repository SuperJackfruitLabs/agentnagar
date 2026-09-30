"""Tiles previews/*.png into previews/sheet.png with each asset's name.

python3 city/tools/styles/voxel/contact_sheet.py [NAME_PREFIX ...]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
PREVIEWS = HERE / "previews"


def main():
    prefixes = sys.argv[1:]
    shots = sorted(p for p in PREVIEWS.glob("*.png") if p.name != "sheet.png"
                   and (not prefixes or any(p.stem.startswith(x) for x in prefixes)))
    if not shots:
        raise SystemExit("no previews; run render_preview.py first")
    cell = 240
    cols = 6
    rows = (len(shots) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * (cell + 18)), (250, 246, 236))
    draw = ImageDraw.Draw(sheet)
    for k, p in enumerate(shots):
        im = Image.open(p).convert("RGB").resize((cell, cell))
        x, y = (k % cols) * cell, (k // cols) * (cell + 18)
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + cell + 3), p.stem, fill=(40, 40, 40))
    sheet.save(PREVIEWS / "sheet.png")
    print(f"sheet: {len(shots)} previews")


main()
