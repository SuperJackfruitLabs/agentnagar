"""Puts a style's captures beside the concept sheet's panels, row by row,
for review: sheet panel on the left, the running client on the right.

python3 city/tools/evidence/compare.py STYLE_DIR OUT.png \\
    SHEET_ID:PANEL=CAPTURE.png [SHEET_ID:PANEL=CAPTURE.png ...]

STYLE_DIR is a style study folder (docs/vision/style-studies/styles/11-...);
SHEET_ID is a sheet folder prefix (00, 02, ...); PANEL is tl, tr, bl or br
(the sheet's four panels, e.g. 00:tr is "Top-down" and 00:br "Street").
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROW_H = 420
LABEL = 22


def latest_sheet(style_dir: Path, sheet_id: str) -> Path:
    folder = next(p for p in sorted((style_dir / "sheets").iterdir()) if p.name.startswith(sheet_id))
    rev = sorted(p for p in folder.iterdir() if p.is_dir())[-1]
    return rev / "image.png"


def panel(sheet: Image.Image, which: str) -> Image.Image:
    """One of the sheet's four panels, its frame and caption trimmed."""
    w, h = sheet.size
    mx, my = int(w * 0.03), int(h * 0.045)
    cx, cy = w // 2, int(h * 0.475)
    boxes = {
        "tl": (mx, my, cx - 6, cy - 4), "tr": (cx + 6, my, w - mx, cy - 4),
        "bl": (mx, cy + 6, cx - 6, int(h * 0.94)), "br": (cx + 6, cy + 6, w - mx, int(h * 0.94)),
    }
    return sheet.crop(boxes[which])


def fit(im: Image.Image, height: int) -> Image.Image:
    return im.resize((int(im.width * height / im.height), height), Image.LANCZOS)


def main():
    style_dir, out = Path(sys.argv[1]), Path(sys.argv[2])
    rows = []
    for spec in sys.argv[3:]:
        left, capture = spec.split("=", 1)
        sheet_id, which = left.split(":")
        sheet = Image.open(latest_sheet(style_dir, sheet_id)).convert("RGB")
        a = fit(panel(sheet, which), ROW_H)
        b = fit(Image.open(capture).convert("RGB"), ROW_H)
        rows.append((f"sheet {sheet_id} {which}", a, Path(capture).stem, b))
    width = max(a.width + b.width for _, a, _, b in rows) + 30
    canvas = Image.new("RGB", (width, len(rows) * (ROW_H + LABEL + 10) + 10), (250, 246, 236))
    draw = ImageDraw.Draw(canvas)
    y = 10
    for la, a, lb, b in rows:
        draw.text((10, y), la, fill=(40, 40, 40))
        draw.text((20 + a.width, y), lb, fill=(40, 40, 40))
        canvas.paste(a, (10, y + LABEL))
        canvas.paste(b, (20 + a.width, y + LABEL))
        y += ROW_H + LABEL + 10
    canvas.save(out)
    print(f"compare: {out} ({len(rows)} rows)")


main()
