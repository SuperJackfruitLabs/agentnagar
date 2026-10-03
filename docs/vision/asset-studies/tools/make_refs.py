#!/usr/bin/env python3
"""Makes the reference images that the jobs name. Needs Pillow:

    uv run --with pillow python3 tools/make_refs.py panels
    uv run --with pillow python3 tools/make_refs.py frames CAPTURES_DIR [--commit GAME_COMMIT]
    uv run --with pillow python3 tools/make_refs.py contact

panels    cuts the sixteen panels out of each style's four selected concept sheets, keeping well inside each
          panel so that no caption comes along, into refs/panels/<style>/<panel>.jpg. The jobs give two or three of them to the image model
          as style references. They are crops of AI-generated concept art (see the style studies).
frames    takes captures of the game as it is today (CAPTURES_DIR/<style>/<view>.png, as the project's
          city/godot/tools/sheet_views.gd saves them) and makes the edit targets of the frame jobs:
          refs/frames/<style>/<view>.jpg, 1536 x 1024. A 3D pack's capture is cropped to 3:2 about its centre
          and scaled; the pixel pack's is cropped only, so its pixels stay whole.
contact   lays every reference out on sheets for checking by eye: refs/contact-<style>.jpg.
"""
import json
import sys
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
PACK = HERE.parent
REPO = PACK.parents[2]
STUDIES = REPO / "docs" / "vision" / "style-studies" / "styles"
# The comparison contract's sheet layout (docs/vision/style-studies/shared/CONSISTENCY-CONTRACT.md):
# 1536 x 1024, a 20 px matte, 12 px gutters, panels of 742 x 464 with a 32 px caption strip at their top.
MATTE, GUTTER, PANEL_W, PANEL_H, CAPTION = 20, 12, 742, 464, 32
# The sheets do not all follow that layout to the pixel, and some draw their captions as label boxes inside
# the panel. So a crop keeps well inside: these many pixels come off the top, right, bottom and left of the
# contract's caption-free panel. Measured on all 24 selected sheets on 2026-10-02: no caption survives.
TRIM = (64, 24, 22, 24)
FRAME = (1536, 1024)


def load():
    styles = json.loads((PACK / "data" / "styles.json").read_text())
    plan = json.loads((PACK / "data" / "plan.json").read_text())
    return styles, plan


def selected(study, sheet):
    revision = json.loads((STUDIES / study / "manifest.json").read_text())["selected"][sheet]
    return STUDIES / study / "sheets" / sheet / revision / "image.png"


def panels():
    styles, plan = load()
    record = {}
    for style_id in styles["order"]:
        study = styles["styles"][style_id]["study"]
        out = PACK / "refs" / "panels" / style_id
        out.mkdir(parents=True, exist_ok=True)
        for name, (sheet, row, col) in plan["panels"].items():
            source = selected(study, sheet)
            image = Image.open(source).convert("RGB")
            top, right, bottom, left = TRIM
            x = MATTE + col * (PANEL_W + GUTTER)
            y = MATTE + row * (PANEL_H + GUTTER) + CAPTION
            image.crop((x + left, y + top, x + PANEL_W - right, y + PANEL_H - CAPTION - bottom)).save(out / f"{name}.jpg", quality=93)
            record[f"{style_id}/{name}.jpg"] = str(source.relative_to(REPO))
    (PACK / "refs" / "panels" / "sources.json").write_text(json.dumps(record, indent=1) + "\n")
    print(f"panels: {len(record)} panels cut into refs/panels/")


def frames(captures, commit):
    styles, plan = load()
    views = sorted({f["view"] for f in plan["frames"]})
    record = {"made": date.today().isoformat(), "game_commit": commit, "frames": {}}
    for style_id in styles["order"]:
        out = PACK / "refs" / "frames" / style_id
        out.mkdir(parents=True, exist_ok=True)
        for view in views:
            source = captures / style_id / f"{view}.png"
            if not source.exists():
                print(f"frames: missing {source}")
                continue
            image = Image.open(source).convert("RGB")
            w, h = image.size
            if styles["styles"][style_id].get("sprite"):
                left, top = (w - FRAME[0]) // 2, (h - FRAME[1]) // 2
                image = image.crop((left, top, left + FRAME[0], top + FRAME[1]))
                how = "cropped about its centre, not scaled"
            else:
                crop_w = min(w, round(h * FRAME[0] / FRAME[1]))
                crop_h = round(crop_w * FRAME[1] / FRAME[0])
                left, top = (w - crop_w) // 2, (h - crop_h) // 2
                image = image.crop((left, top, left + crop_w, top + crop_h)).resize(FRAME, Image.LANCZOS)
                how = f"cropped to {crop_w} x {crop_h} about its centre, then scaled"
            image.save(out / f"{view}.jpg", quality=92)
            record["frames"][f"{style_id}/{view}.jpg"] = {"capture_size": [w, h], "how": how}
    (PACK / "refs" / "frames" / "sources.json").write_text(json.dumps(record, indent=1) + "\n")
    print(f"frames: {len(record['frames'])} frames made in refs/frames/")


def contact():
    styles, plan = load()
    for style_id in styles["order"]:
        files = sorted((PACK / "refs" / "panels" / style_id).glob("*.jpg")) + sorted((PACK / "refs" / "frames" / style_id).glob("*.jpg"))
        if not files:
            continue
        cell_w, cell_h, label, cols = 380, 240, 18, 4
        rows = -(-len(files) // cols)
        sheet = Image.new("RGB", (cols * cell_w, rows * (cell_h + label)), (40, 40, 44))
        draw = ImageDraw.Draw(sheet)
        for k, path in enumerate(files):
            image = Image.open(path).convert("RGB")
            image.thumbnail((cell_w - 6, cell_h - 6))
            x, y = (k % cols) * cell_w, (k // cols) * (cell_h + label)
            draw.text((x + 4, y + 3), f"{path.parent.parent.name}/{path.name}  {Image.open(path).size[0]}x{Image.open(path).size[1]}", fill=(230, 230, 230))
            sheet.paste(image, (x + 3, y + label + 3))
        sheet.save(PACK / "refs" / f"contact-{style_id}.jpg", quality=85)
        print(f"contact: refs/contact-{style_id}.jpg ({len(files)} images)")


def main(argv):
    if not argv:
        sys.exit(__doc__)
    if argv[0] == "panels":
        panels()
    elif argv[0] == "frames":
        commit = argv[argv.index("--commit") + 1] if "--commit" in argv else "not recorded"
        frames(Path(argv[1]), commit)
    elif argv[0] == "contact":
        contact()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
