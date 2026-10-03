"""before_after.py OUT.png LABEL=PREFIX [LABEL=PREFIX...]: look.py's views of several builds of one piece, a row a
build (quarter, above, side, front), for looking at what a change did."""
import sys

from PIL import Image, ImageDraw

rows = []
for arg in sys.argv[2:]:
    label, prefix = arg.split("=", 1)
    tiles = [Image.open(f"{prefix}-{v}.png").convert("RGB") for v in ("quarter", "above", "side", "front")]
    row = Image.new("RGB", (sum(t.width for t in tiles) + 6 * 3, tiles[0].height + 22), (245, 244, 238))
    x = 0
    for t in tiles:
        row.paste(t, (x, 22)); x += t.width + 6
    ImageDraw.Draw(row).text((6, 4), label, fill=(0, 0, 0))
    rows.append(row)
sheet = Image.new("RGB", (max(r.width for r in rows), sum(r.height + 6 for r in rows)), (255, 255, 255))
y = 0
for r in rows:
    sheet.paste(r, (0, y)); y += r.height + 6
sheet.save(sys.argv[1])
print(sheet.size)
