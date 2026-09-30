#!/usr/bin/env python3
"""Lays a style's game captures beside the concept-sheet panels they are
meant to match, one pair per row, for review:

    python3 city/godot/tools/sheet_compare.py STYLE_DIR_NAME STUDY_DIR OUT_PNG

STUDY_DIR is the style study under docs/vision/style-studies/styles/ (for
example 06-anime). Captures come from tools/sheet_views.gd, under
~/.cache/agentnagar-sheets/<style>/. Sheets follow the comparison
contract's layout: 1536 x 1024, 20 px matte, 12 px gutters, a 32 px
caption strip on each panel and a 44 px footer.

With --maps it sets every style's map (map.png, from sheet_views.gd's map
mode) beside its sheet-00 MAP panel instead, one style per row, the
capture scaled whole to the panel's height, never cropped:

    python3 city/godot/tools/sheet_compare.py --maps OUT_PNG
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[3]
PANEL_W, PANEL_H, CAPTION = 742, 464, 32
# view -> (sheet, row, column) in the study's current selections.
PAIRS = [
    ("topdown", "00-city-perspectives", 0, 1),
    ("diagonal", "00-city-perspectives", 1, 0),
    ("street", "00-city-perspectives", 1, 1),
    ("night-rain", "02-creating-exploring", 1, 0),
    ("park", "02-creating-exploring", 1, 1),
    ("workshop", "01-living-community", 0, 0),
    ("gathering", "01-living-community", 1, 1),
    ("a1", "01-living-community", 1, 0),
    ("map", "00-city-perspectives", 0, 0),
]


# pack -> its style study, in the order of the style specs' tables.
STYLES = [
    ("anime_cel", "06-anime"),
    ("solarpunk", "09-solarpunk"),
    ("neon_noir", "10-neon-noir"),
    ("pixel_art", "08-pixel-art"),
    ("lowpoly_tropical", "11-low-poly-tropical-diorama"),
    ("voxel", "02-voxel"),
]
GUTTER, LABEL = 12, 22


def selected(study: Path, sheet: str) -> Path:
    revs = sorted((study / "sheets" / sheet).glob("r*/image.png"))
    readme = (study / "README.md").read_text()
    for r in reversed(revs):
        if f"sheets/{sheet}/{r.parent.name}/image.png" in readme.split("## Revision history")[0]:
            return r
    return revs[-1]


def panel(image: Path, row: int, col: int) -> Image.Image:
    sheet = Image.open(image).convert("RGB")
    x = 20 + col * (PANEL_W + 12)
    y = 20 + row * (PANEL_H + 12) + CAPTION
    return sheet.crop((x, y, x + PANEL_W, y + PANEL_H - CAPTION))


def fit(capture: Image.Image, size) -> Image.Image:
    w, h = size
    scale = max(w / capture.width, h / capture.height)
    c = capture.resize((round(capture.width * scale), round(capture.height * scale)), Image.LANCZOS)
    left, top = (c.width - w) // 2, (c.height - h) // 2
    return c.crop((left, top, left + w, top + h))


def maps(out: Path):
    """Each style's MAP panel (sheet 00, top left) beside its map.png."""
    caps_root = Path.home() / ".cache" / "agentnagar-sheets"
    height = PANEL_H - CAPTION
    capture_w = round(height * 16 / 9)
    width = GUTTER + PANEL_W + GUTTER + capture_w + GUTTER
    row_h = LABEL + height + GUTTER
    sheet = Image.new("RGB", (width, GUTTER + row_h * len(STYLES)), (246, 244, 240))
    draw = ImageDraw.Draw(sheet)
    for k, (style, study_name) in enumerate(STYLES):
        study = REPO / "docs" / "vision" / "style-studies" / "styles" / study_name
        chosen = selected(study, "00-city-perspectives")
        y = GUTTER + k * row_h
        draw.text((GUTTER, y + 4), f"{style}: sheet 00-city-perspectives {chosen.parent.name} MAP", fill=(40, 40, 60))
        sheet.paste(panel(chosen, 0, 0), (GUTTER, y + LABEL))
        x = GUTTER + PANEL_W + GUTTER
        path = caps_root / style / "map.png"
        draw.text((x, y + 4), f"{style}: game, map at 1920 x 1080, Workshop selected", fill=(40, 40, 60))
        if path.exists():
            capture = Image.open(path).convert("RGB")
            sheet.paste(capture.resize((capture_w, height), Image.LANCZOS), (x, y + LABEL))
        else:
            draw.text((x + 8, y + LABEL + 8), f"missing: {path}", fill=(160, 40, 40))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, optimize=True)
    print(f"map compare: {len(STYLES)} styles to {out}")


def main(argv):
    if argv[0] == "--maps":
        maps(Path(argv[1]))
        return
    style, study_name, out = argv[0], argv[1], Path(argv[2])
    study = REPO / "docs" / "vision" / "style-studies" / "styles" / study_name
    caps = Path.home() / ".cache" / "agentnagar-sheets" / style
    w, h = PANEL_W, PANEL_H - CAPTION
    rows = [(v, s, r, c) for v, s, r, c in PAIRS if (caps / f"{v}.png").exists()]
    sheet = Image.new("RGB", (w * 2 + 36, (h + 34) * len(rows) + 12), (246, 244, 240))
    d = ImageDraw.Draw(sheet)
    for k, (view, name, r, c) in enumerate(rows):
        y = 12 + k * (h + 34)
        d.text((12, y), f"{view}: sheet {name} (left) / game (right)", fill=(40, 40, 60))
        sheet.paste(panel(selected(study, name), r, c), (12, y + 20))
        sheet.paste(fit(Image.open(caps / f"{view}.png").convert("RGB"), (w, h)), (w + 24, y + 20))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    print(f"sheet compare: {len(rows)} views to {out}")


if __name__ == "__main__":
    main(sys.argv[1:])
