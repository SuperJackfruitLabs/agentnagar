"""strip.py OUT.png LABEL=IMAGE [LABEL=IMAGE ...] [--height 380] [--cols N]: images side by side under labels.
A cut-out (an image with transparency) is laid on the design sheets' grey backdrop and trimmed to its object,
so that a dark object is not lost on black."""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

argv = sys.argv[1:]
height = int(argv[argv.index("--height") + 1]) if "--height" in argv else 380
cols = int(argv[argv.index("--cols") + 1]) if "--cols" in argv else 0
items = [a.split("=", 1) for a in argv[1:] if "=" in a]
FONT = next((p for p in ("/usr/share/fonts/noto/NotoSans-Regular.ttf", "/usr/share/fonts/TTF/DejaVuSans.ttf") if Path(p).exists()), None)
font = ImageFont.truetype(FONT, 18) if FONT else ImageFont.load_default()
tiles = []
for label, path in items:
    im = Image.open(path)
    if im.mode == "RGBA":
        box = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        if box:
            pad = max(8, round(0.04 * max(box[2] - box[0], box[3] - box[1])))
            im = im.crop((max(box[0] - pad, 0), max(box[1] - pad, 0), min(box[2] + pad, im.width), min(box[3] + pad, im.height)))
        ground = Image.new("RGBA", im.size, (176, 176, 178, 255))
        im = Image.alpha_composite(ground, im)
    im = im.convert("RGB")
    tiles.append((label, im.resize((max(1, round(im.width * height / im.height)), height), Image.LANCZOS)))
cols = cols or len(tiles)
rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
gap, lab = 10, 26
w = max(sum(t.width for _, t in r) + gap * (len(r) + 1) for r in rows)
sheet = Image.new("RGB", (w, len(rows) * (height + lab + gap) + gap), (246, 244, 239))
d = ImageDraw.Draw(sheet)
y = gap
for r in rows:
    x = gap
    for label, t in r:
        d.text((x + 2, y + 2), label, fill=(30, 30, 30), font=font)
        sheet.paste(t, (x, y + lab))
        x += t.width + gap
    y += height + lab + gap
Path(argv[0]).parent.mkdir(parents=True, exist_ok=True)
sheet.save(argv[0])
print("strip:", argv[0], sheet.size)
