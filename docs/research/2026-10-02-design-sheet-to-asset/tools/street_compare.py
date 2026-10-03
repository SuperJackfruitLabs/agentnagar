"""street_compare.py STYLE OUT.png [VIEW]: one view of the game four ways: the concept sheet's panel, the repainted
frame (the like-for-like target, where there is one), the game today, and the game with the new seats and great tree."""
import os
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
PACK = Path(os.environ["AGENTNAGAR"]) / "docs" / "vision" / "asset-studies"
style, out = sys.argv[1], Path(sys.argv[2])
view = sys.argv[3] if len(sys.argv) > 3 else "street"
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 22) if FONT else ImageFont.load_default()
panel = {"street": "street", "diagonal": "diagonal", "gathering": "gathering", "park": "park", "night-rain": "night-rain", "workshop": "workshop", "topdown": "topdown"}[view]
tiles = [("concept sheet", PACK / "refs" / "panels" / style / f"{panel}.jpg")]
target = PACK / "sheets" / style / f"D-{view}" / "r001" / "image.png"
if target.exists():
    tiles.append(("repainted frame (target)", target))
tiles += [("game today", W / "game" / "captures" / "before" / style / f"{view}.png"), ("game with the new seats and great tree", W / "game" / "captures" / "new" / style / f"{view}.png")]
width, pad, label_h = 1180, 14, 34
ims = []
for label, path in tiles:
    im = Image.open(path).convert("RGB")
    # every tile at one aspect (3:2), cropped about its centre
    w, h = im.size
    cw = min(w, round(h * 1.5)); ch = round(cw / 1.5)
    im = im.crop(((w - cw) // 2, (h - ch) // 2, (w - cw) // 2 + cw, (h - ch) // 2 + ch)).resize((width, round(width / 1.5)), Image.LANCZOS)
    ims.append((label, im))
cols = 2
rows = -(-len(ims) // cols)
th = ims[0][1].height
sheet = Image.new("RGB", (cols * width + (cols + 1) * pad, rows * (th + label_h) + (rows + 1) * pad), (246, 244, 239))
d = ImageDraw.Draw(sheet)
for k, (label, im) in enumerate(ims):
    x = pad + (k % cols) * (width + pad); y = pad + (k // cols) * (th + label_h + pad)
    d.text((x + 2, y + 2), label, fill=(30, 30, 30), font=font)
    sheet.paste(im, (x, y + label_h))
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"street compare: {out} {sheet.size}")
