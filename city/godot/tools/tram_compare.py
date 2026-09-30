#!/usr/bin/env python3
"""Lays each style's tram captures beside the concept-sheet panel they are
meant to match, one style per row, for review:

    python3 city/godot/tools/tram_compare.py OUT_PNG

Each row holds the style's sheet-02 TRANSIT panel (top right of its
"creating and exploring" sheet, at the revision the study's README
selects, as tools/sheet_compare.py chooses it), then the game's ride in
first person, boarding at the Square stop, the lit tram at night and the
overhead view with passengers, from tools/sheet_views.gd's tram mode under
~/.cache/agentnagar-sheets/<style>/. Captures are scaled whole to the
panel's height, never cropped.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from sheet_compare import CAPTION, GUTTER, LABEL, PANEL_H, PANEL_W, REPO, STYLES, panel, selected

SHEET = "02-creating-exploring"
TRANSIT = (0, 1)
CAPTURES = [("tram-ride", "riding (first person)"), ("tram-board", "at the Square stop"),
            ("tram-night", "at night"), ("tram-overhead", "overhead")]
# Everything is drawn at half the sheets' own size.
SCALE = 0.5


def scaled(image: Image.Image, height: int) -> Image.Image:
    return image.resize((round(image.width * height / image.height), height), Image.LANCZOS)


def main(argv):
    out = Path(argv[0])
    caps_root = Path.home() / ".cache" / "agentnagar-sheets"
    height = round((PANEL_H - CAPTION) * SCALE)
    panel_w = round(PANEL_W * SCALE)
    capture_w = round(height * 16 / 9)
    width = GUTTER + panel_w + GUTTER + len(CAPTURES) * (capture_w + GUTTER)
    row_h = LABEL + height + GUTTER
    sheet = Image.new("RGB", (width, GUTTER + row_h * len(STYLES)), (246, 244, 240))
    draw = ImageDraw.Draw(sheet)
    for k, (style, study_name) in enumerate(STYLES):
        study = REPO / "docs" / "vision" / "style-studies" / "styles" / study_name
        chosen = selected(study, SHEET)
        y = GUTTER + k * row_h
        x = GUTTER
        draw.text((x, y + 4), f"{style}: sheet 02 {chosen.parent.name} TRANSIT", fill=(40, 40, 60))
        sheet.paste(scaled(panel(chosen, *TRANSIT), height), (x, y + LABEL))
        x += panel_w + GUTTER
        for name, label in CAPTURES:
            path = caps_root / style / f"{name}.png"
            draw.text((x, y + 4), f"game: {label}", fill=(40, 40, 60))
            if path.exists():
                sheet.paste(scaled(Image.open(path).convert("RGB"), height), (x, y + LABEL))
            else:
                draw.text((x + 8, y + LABEL + 8), f"missing: {path}", fill=(160, 40, 40))
            x += capture_w + GUTTER
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(f"tram compare: {len(STYLES)} styles to {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
