"""three_ways.py STYLE OUT.png [--columns "LABEL=FOLDER;..."] [VIEW ...]: the town's wide views several ways, side by
side (the folders of game/captures named, a column each). Without --columns, three ways: with the kit's street
trees and palms, with the ones built from the design sheets in the sheets' own greens, and with the same in the
kit's greens (game/captures/trees-before, trees, trees-kit-green; planted_three_ways.sh takes them)."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

W = Path(__file__).resolve().parent.parent
style, out = sys.argv[1], Path(sys.argv[2])
COLUMNS = [("the kit's trees and palms", "trees-before"), ("from the design sheets, the sheets' greens", "trees"), ("from the design sheets, the kit's greens", "trees-kit-green")]
args = sys.argv[3:]
if "--columns" in args:                               # --columns "LABEL=FOLDER;LABEL=FOLDER;..." (folders under game/captures)
    spec = args[args.index("--columns") + 1]
    COLUMNS = [tuple(c.split("=", 1)) for c in spec.split(";")]
    del args[args.index("--columns"): args.index("--columns") + 2]
views = args or ["park", "diagonal", "street", "topdown"]
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 22) if FONT else ImageFont.load_default()
rows = []
for view in views:
    tiles = []
    for label, folder in COLUMNS:
        im = Image.open(W / "game" / "captures" / folder / style / f"{view}.png").convert("RGB")
        im = im.resize((900, round(900 * im.height / im.width)), Image.LANCZOS)
        d = ImageDraw.Draw(im)
        text = f"{style.split('_')[0]}, {view}: {label}"
        d.rectangle((0, 0, d.textlength(text, font=font) + 14, 32), fill=(0, 0, 0))
        d.text((7, 3), text, fill=(255, 255, 255), font=font)
        tiles.append(im)
    rows.append(tiles)
h = rows[0][0].height
sheet = Image.new("RGB", (908 * len(COLUMNS) - 8, (h + 8) * len(rows) - 8), (246, 244, 239))
for r, tiles in enumerate(rows):
    for c, t in enumerate(tiles):
        sheet.paste(t, (c * 908, r * (h + 8)))
out.parent.mkdir(parents=True, exist_ok=True)
sheet.save(out)
print(f"three ways: {out} {sheet.size}")
