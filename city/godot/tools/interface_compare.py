#!/usr/bin/env python3
"""Lays each style's game interface beside the concept-sheet panels it is
meant to match, one style per row, for review:

    python3 city/godot/tools/interface_compare.py OUT_PNG

Each row holds the style's sheet-03 FACILITY and MOBILE panels (the top
row of its "interfaces and perspectives" sheet, at the revision the
study's README selects, as tools/sheet_compare.py chooses it), then the
game menu, the play HUD and the title at 1920 x 1080, from
tools/sheet_views.gd's interface mode under
~/.cache/agentnagar-sheets/<style>/. Captures are scaled whole to the
panels' height, never cropped, so every corner of the HUD shows.
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

from sheet_compare import CAPTION, GUTTER, LABEL, PANEL_H, PANEL_W, REPO, STYLES, panel, selected

SHEET = "03-interfaces-perspectives"
PANELS = [("FACILITY", 0, 0), ("MOBILE", 0, 1)]
CAPTURES = ["menu", "hud", "title"]
# Everything is drawn at three quarters of the sheets' own size.
SCALE = 0.75


def scaled(image: Image.Image, height: int) -> Image.Image:
    return image.resize((round(image.width * height / image.height), height), Image.LANCZOS)


def main(argv):
    out = Path(argv[0])
    caps_root = Path.home() / ".cache" / "agentnagar-sheets"
    height = round((PANEL_H - CAPTION) * SCALE)
    panel_w = round(PANEL_W * SCALE)
    capture_w = round(height * 16 / 9)
    width = GUTTER + len(PANELS) * (panel_w + GUTTER) + len(CAPTURES) * (capture_w + GUTTER)
    row_h = LABEL + height + GUTTER
    sheet = Image.new("RGB", (width, GUTTER + row_h * len(STYLES)), (246, 244, 240))
    draw = ImageDraw.Draw(sheet)
    for k, (style, study_name) in enumerate(STYLES):
        study = REPO / "docs" / "vision" / "style-studies" / "styles" / study_name
        chosen = selected(study, SHEET)
        y = GUTTER + k * row_h
        x = GUTTER
        for name, row, col in PANELS:
            draw.text((x, y + 4), f"{style}: sheet {SHEET} {chosen.parent.name} {name}", fill=(40, 40, 60))
            sheet.paste(scaled(panel(chosen, row, col), height), (x, y + LABEL))
            x += panel_w + GUTTER
        for view in CAPTURES:
            path = caps_root / style / f"ui-{view}.png"
            draw.text((x, y + 4), f"{style}: game, {view}", fill=(40, 40, 60))
            if path.exists():
                sheet.paste(scaled(Image.open(path).convert("RGB"), height), (x, y + LABEL))
            else:
                draw.text((x + 8, y + LABEL + 8), f"missing: {path}", fill=(160, 40, 40))
            x += capture_w + GUTTER
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(f"interface compare: {len(STYLES)} styles to {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
