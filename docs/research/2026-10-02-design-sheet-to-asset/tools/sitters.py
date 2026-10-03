"""sitters.py OUT.png [STYLE ...]: the street view at full size round the great tree's foot, where people sit on
the benches, with the kit's pieces (left) and the new ones (right), one row a style (default: all five)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 18) if FONT else ImageFont.load_default()
tiles = []
styles = sys.argv[2:] or ["lowpoly_tropical", "neon_noir", "anime_cel", "solarpunk", "voxel"]
for style in styles:
    for label, folder in (("today", "before"), ("new pieces", "new")):
        im = Image.open(W / "game" / "captures" / folder / style / "street.png").convert("RGB")
        w, h = im.size
        crop = im.crop((int(0.28 * w), int(0.50 * h), int(0.72 * w), int(0.80 * h)))
        d = ImageDraw.Draw(crop)
        d.rectangle((0, 0, 250, 24), fill=(0, 0, 0))
        d.text((6, 2), f"{style.split('_')[0]}: {label}", fill=(255, 255, 255), font=font)
        tiles.append(crop)
w, h = tiles[0].size
sheet = Image.new("RGB", (w * 2 + 8, (h + 8) * len(styles)), (246, 244, 239))
for k, t in enumerate(tiles):
    sheet.paste(t, ((k % 2) * (w + 8), (k // 2) * (h + 8)))
out = Path(sys.argv[1])
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print("sitters:", out, sheet.size)
