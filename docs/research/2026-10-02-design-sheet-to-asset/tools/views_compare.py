"""views_compare.py STYLE OUT.png [VIEW ...]: the game's standard views with the kit's pieces (left) and with
the new ones (right), one row a view (default: diagonal, topdown, gathering, night-rain; the other standard views show none of
the pieces built here)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
style, out = sys.argv[1], Path(sys.argv[2])
views = sys.argv[3:] or ["diagonal", "topdown", "gathering", "night-rain"]
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 20) if FONT else ImageFont.load_default()
width, pad, lab = 1100, 12, 30
rows = []
for view in views:
    pair = []
    for label, folder in (("today", "before"), ("new seats and great tree", "new")):
        im = Image.open(W / "game" / "captures" / folder / style / f"{view}.png").convert("RGB")
        pair.append((f"{view}: {label}", im.resize((width, round(width * im.height / im.width)), Image.LANCZOS)))
    rows.append(pair)
h = rows[0][0][1].height
sheet = Image.new("RGB", (2 * width + 3 * pad, len(rows) * (h + lab + pad) + pad), (246, 244, 239))
d = ImageDraw.Draw(sheet)
for r, pair in enumerate(rows):
    for c, (label, im) in enumerate(pair):
        x, y = pad + c * (width + pad), pad + r * (h + lab + pad)
        d.text((x + 2, y + 2), label, fill=(30, 30, 30), font=font)
        sheet.paste(im, (x, y + lab))
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print("views:", out, sheet.size)
