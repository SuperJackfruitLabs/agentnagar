"""limit_compare.py OUT.png [STYLE ...]: what holding to the kits' triangle limits costs. One row a style that has
pieces built both ways: the tree square from the street and from above with the pieces held to their kit's
limit (left of each pair) and with the shape deciding the count (right). The triangle counts written on each
tile are the great tree's, read from the files (check.py's results.json)."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 20) if FONT else ImageFont.load_default()
CROPS = {"street": (0.26, 0.04, 0.74, 0.82), "diagonal": (0.20, 0.10, 0.80, 0.90)}
out = Path(sys.argv[1])
rows = []
for style in sys.argv[2:] or ["lowpoly_tropical", "neon_noir", "anime_cel", "solarpunk"]:
    if not (W / "game" / "captures" / "budget" / style).is_dir():
        continue
    tiles = []
    for view, box in CROPS.items():
        for label, folder, built in (("held to the kit's limit", "budget", "out-budget"), ("the shape decides", "new", "out")):
            im = Image.open(W / "game" / "captures" / folder / style / f"{view}.png").convert("RGB")
            w, h = im.size
            im = im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
            im = im.resize((640, round(640 * im.height / im.width)), Image.LANCZOS)
            # The file's own triangles, as the report's tables give them (results.json, written by check.py): a
            # fit's report counts a few faces it later drops.
            tree = next(r["triangles"] for r in json.loads((W / built / "results.json").read_text()) if r["style"] == style and r["asset"] == "great-tree")
            d = ImageDraw.Draw(im)
            text = f"{style.split('_')[0]}, {view}: {label} (tree {tree:,} triangles)"
            d.rectangle((0, 0, d.textlength(text, font=font) + 12, 28), fill=(0, 0, 0))
            d.text((6, 2), text, fill=(255, 255, 255), font=font)
            tiles.append(im)
    rows.append(tiles)
if not rows:
    sys.exit("no style has pieces captured both ways")
pad = 8
height = max(t.height for row in rows for t in row)
sheet = Image.new("RGB", (4 * 640 + 3 * pad, len(rows) * height + (len(rows) - 1) * pad), (246, 244, 239))
for r, row in enumerate(rows):
    for c, t in enumerate(row):
        sheet.paste(t, (c * (640 + pad), r * (height + pad)))
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"limit compare: {out} {sheet.size}")
