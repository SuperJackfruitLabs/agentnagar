"""Draws the anime kit's face atlas: every expression of every face
variant, crisp vector art over transparency (the skin shows through, so
one atlas suits every skin tone).

    python3 city/tools/styles/anime/faces.py [OUT_PNG]

Columns are expressions, rows face variants (see EXPRESSIONS, VARIANTS);
each cell is CELL px, drawn at SUPER times that size and downsampled, so
lines stay smooth and sharp. The face plate of the characters maps one
cell: u across the face (ear to ear), v down it (brow to chin). The pack's
face shader picks the cell. Standard library plus Pillow; deterministic.
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "anime_cel" / "assets" / "face_atlas.png"
CELL = 256
SUPER = 4
EXPRESSIONS = ["neutral", "smile", "talk", "surprised", "blink"]
# Iris colour, and the eye's shape: width, openness, outer-corner lift.
VARIANTS = [
    {"iris": (58, 118, 214), "width": 1.0, "open": 1.0, "lift": 0.0},    # A1: bright blue
    {"iris": (122, 76, 44), "width": 0.95, "open": 0.9, "lift": 0.02},    # warm brown
    {"iris": (64, 58, 128), "width": 1.02, "open": 1.08, "lift": -0.01},  # deep violet
    {"iris": (92, 124, 64), "width": 0.92, "open": 0.95, "lift": 0.035},  # hazel green
]
INK = (34, 28, 46, 255)
LASH = (26, 20, 34, 255)
MOUTH = (150, 62, 66, 255)
TONGUE = (226, 118, 118, 255)
BLUSH = (240, 128, 138, 70)


def _pt(x, y):
    """Cell fractions to super-sampled pixels."""
    s = CELL * SUPER
    return (x * s, y * s)


def _poly(draw, pts, fill=None, width=0, colour=None):
    p = [_pt(*q) for q in pts]
    if fill:
        draw.polygon(p, fill=fill)
    if width:
        draw.line(p, fill=colour, width=int(width * CELL * SUPER), joint="curve")


def _arc_points(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def _eye(img, cx, cy, side, v, expression):
    """One eye at (cx, cy) in cell fractions; side -1 is the face's left
    (image left), +1 right."""
    draw = ImageDraw.Draw(img)
    w = 0.15 * v["width"]
    h = 0.13 * v["open"] * (1.12 if expression == "surprised" else 1.0)
    lift = v["lift"]
    if expression == "blink":
        # Closed: a soft downward arc with a lash flick.
        pts = _arc_points(cx, cy - 0.005, w, 0.03, 200, 340)
        _poly(draw, pts, width=0.012, colour=LASH)
        _poly(draw, [pts[0 if side < 0 else -1], (cx - side * -1 * (w + 0.02), cy - 0.02)], width=0.008, colour=LASH)
        return
    smile = expression == "smile"
    # The opening: an almond, a little squashed from below when smiling.
    # Upper lid from the right corner over to the left; the outer corner
    # (away from the nose) lifts by the variant's `lift`.
    def corner_lift(x):
        return -lift * max(0.0, (x - cx) * side / w)
    top = [(cx + w * math.cos(math.radians(a)), cy - h * math.sin(math.radians(a)) + corner_lift(cx + w * math.cos(math.radians(a))))
           for a in range(0, 181, 10)]
    bottom_h = h * (0.35 if smile else 0.62)
    bottom = [(cx + w * math.cos(math.radians(a)), cy + bottom_h * math.sin(math.radians(a - 180)) + corner_lift(cx + w * math.cos(math.radians(a))))
              for a in range(180, 361, 10)]
    opening = top + bottom
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon([_pt(*q) for q in opening], fill=255)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    _poly(ld, opening, fill=(252, 250, 247, 255))
    # Iris: a tall ellipse, darker at the top, a lighter lower band, a
    # pupil, and the two highlights anime eyes carry.
    ir = v["iris"]
    iw, ih = w * 0.58, h * 1.05
    ix, iy = cx + side * w * 0.04, cy - h * 0.05
    dark = tuple(int(c * 0.45) for c in ir) + (255,)
    mid = ir + (255,)
    light = tuple(min(255, int(c * 1.35 + 30)) for c in ir) + (255,)
    ld.ellipse([_pt(ix - iw, iy - ih), _pt(ix + iw, iy + ih)], fill=dark)
    ld.ellipse([_pt(ix - iw * 0.9, iy - ih * 0.55), _pt(ix + iw * 0.9, iy + ih * 0.95)], fill=mid)
    ld.ellipse([_pt(ix - iw * 0.62, iy + ih * 0.2), _pt(ix + iw * 0.62, iy + ih * 0.88)], fill=light)
    ld.ellipse([_pt(ix - iw * 0.36, iy - ih * 0.3), _pt(ix + iw * 0.36, iy + ih * 0.42)], fill=(22, 18, 30, 255))
    ld.ellipse([_pt(ix - iw * 0.62, iy - ih * 0.62), _pt(ix - iw * 0.02, iy - ih * 0.02)], fill=(255, 255, 255, 255))
    ld.ellipse([_pt(ix + iw * 0.25, iy + ih * 0.3), _pt(ix + iw * 0.52, iy + ih * 0.56)], fill=(255, 255, 255, 235))
    img.alpha_composite(Image.composite(layer, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    # Upper lash line: thick, heavier at the outer corner, with a flick.
    lash = top[::-1] if side > 0 else top
    _poly(draw, top, width=0.017, colour=LASH)
    outer = top[0] if side > 0 else top[-1]
    _poly(draw, [outer, (outer[0] + side * 0.03, outer[1] - 0.018 + lift)], width=0.012, colour=LASH)
    # Lower lid: a short, thin line under the outer half.
    low = bottom[3:-3]
    low = low[len(low) // 2:] if side > 0 else low[:len(low) // 2]
    _poly(draw, low, width=0.006, colour=INK)
    del lash


def _brow(draw, cx, cy, side, expression):
    raise_ = {"surprised": -0.03, "smile": -0.008}.get(expression, 0.0)
    pts = _arc_points(cx, cy + raise_ + 0.03, 0.12, 0.03, 200, 330) if side < 0 else \
        _arc_points(cx, cy + raise_ + 0.03, 0.12, 0.03, 210, 340)
    _poly(draw, pts, width=0.009, colour=INK)


def _mouth(img, draw, expression):
    cx, cy = 0.5, 0.82
    if expression in ("neutral", "blink"):
        _poly(draw, [(cx - 0.035, cy), (cx, cy + 0.004), (cx + 0.035, cy)], width=0.007, colour=MOUTH)
    elif expression == "smile":
        _poly(draw, _arc_points(cx, cy - 0.025, 0.06, 0.035, 20, 160), width=0.008, colour=MOUTH)
    elif expression == "talk":
        shape = _arc_points(cx, cy - 0.005, 0.05, 0.045, 0, 180) + [(cx - 0.05, cy - 0.005), (cx + 0.05, cy - 0.005)]
        _poly(draw, shape, fill=MOUTH)
        draw.ellipse([_pt(cx - 0.028, cy + 0.012), _pt(cx + 0.028, cy + 0.04)], fill=TONGUE)
    elif expression == "surprised":
        draw.ellipse([_pt(cx - 0.024, cy - 0.02), _pt(cx + 0.024, cy + 0.03)], fill=MOUTH)


def cell(variant, expression):
    """One face, CELL x CELL, transparent where the skin shows."""
    size = CELL * SUPER
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    if expression in ("smile", "talk"):
        blush = Image.new("RGBA", img.size, (0, 0, 0, 0))
        bd = ImageDraw.Draw(blush)
        for x in (0.27, 0.73):
            bd.ellipse([_pt(x - 0.08, 0.66), _pt(x + 0.08, 0.715)], fill=BLUSH)
        img.alpha_composite(blush)
    draw = ImageDraw.Draw(img)
    for side, x in ((-1, 0.3), (1, 0.7)):
        _eye(img, x, 0.52, side, variant, expression)
        _brow(draw, x, 0.3, side, expression)
    # A nose: a short soft stroke of shade.
    _poly(draw, [(0.505, 0.69), (0.515, 0.712), (0.5, 0.718)], width=0.006, colour=(196, 128, 110, 170))
    _mouth(img, draw, expression)
    return img.resize((CELL, CELL), Image.LANCZOS)


def atlas():
    out = Image.new("RGBA", (CELL * len(EXPRESSIONS), CELL * len(VARIANTS)), (0, 0, 0, 0))
    for row, v in enumerate(VARIANTS):
        for col, e in enumerate(EXPRESSIONS):
            out.paste(cell(v, e), (col * CELL, row * CELL))
    return out


def main(argv):
    path = Path(argv[0]) if argv else DEFAULT_OUT
    path.parent.mkdir(parents=True, exist_ok=True)
    atlas().save(path, optimize=False)
    print(f"faces: wrote {path.name} ({len(VARIANTS)} faces x {len(EXPRESSIONS)} expressions)")


if __name__ == "__main__":
    main(sys.argv[1:])
