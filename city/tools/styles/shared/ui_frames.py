"""The interface skins' nine-slice frames, drawn with PIL: solarpunk's
brass bevel round a deep-teal field, and pixel art's navy pixel frame. A
style's `ui.frame` names the file and its margin; UiTheme stretches the
middle and edges and keeps the corners whole.

python3 city/tools/styles/shared/ui_frames.py [STYLES_DIR]

With no argument it writes into city/godot/styles.
"""
import sys
from pathlib import Path

from PIL import Image

STYLES = Path(__file__).resolve().parents[3] / "godot" / "styles"

FRAMES = {
    "brass": {"path": "solarpunk/assets/ui/brass_frame.png", "margin": 16},
    "pixel": {"path": "pixel_art/assets/ui/pixel_frame.png", "margin": 6},
}

BRASS_DARK = (0xB8, 0x86, 0x2F)
BRASS_LIGHT = (0xE4, 0xC2, 0x7A)
TEAL = (0x12, 0x3C, 0x3A)

PIXEL_OUTLINE = (0x0A, 0x0F, 0x22)
PIXEL_HIGHLIGHT = (0x3E, 0x5A, 0xA8)
PIXEL_FIELD = (0x14, 0x1B, 0x33)

# Samples per pixel, each way, for the brass frame's rounded outer corners.
SUPER = 4


def _mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def _corner_distance(x, y, size, radius):
    """How far the point lies outside the rounded square of side `size`
    whose corners have `radius`; negative inside."""
    cx = min(max(x, radius), size - radius)
    cy = min(max(y, radius), size - radius)
    return ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 - radius


def brass_frame(size=96, bevel=12, radius=16):
    """A 12 px brass bevel round a teal field: the brass is darkest at its
    outer and inner edges and lightest along the middle, a lit rail. The
    outer corners are rounded, anti-aliased; the field is flat."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = im.load()
    for y in range(size):
        for x in range(size):
            depth = min(x, y, size - 1 - x, size - 1 - y)
            if depth >= bevel:
                colour = TEAL
            else:
                # 0 at either edge of the rail, 1 at its middle.
                t = 1 - abs((depth + 0.5) - bevel / 2) / (bevel / 2)
                colour = _mix(BRASS_DARK, BRASS_LIGHT, max(0.0, min(1.0, t)))
            cover = 0
            for sy in range(SUPER):
                for sx in range(SUPER):
                    sample_x = x + (sx + 0.5) / SUPER
                    sample_y = y + (sy + 0.5) / SUPER
                    if _corner_distance(sample_x, sample_y, size, radius) <= 0:
                        cover += 1
            alpha = round(255 * cover / (SUPER * SUPER))
            px[x, y] = colour + (alpha,)
    return im


def pixel_frame(size=48):
    """At one image pixel per screen pixel: a 3 px outline, a 1 px
    highlight inside it and the navy field, with the outer corner pixel
    notched out."""
    im = Image.new("RGBA", (size, size), PIXEL_FIELD + (255,))
    px = im.load()
    for y in range(size):
        for x in range(size):
            depth = min(x, y, size - 1 - x, size - 1 - y)
            if depth < 3:
                px[x, y] = PIXEL_OUTLINE + (255,)
            elif depth == 3:
                px[x, y] = PIXEL_HIGHLIGHT + (255,)
    for x, y in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
        px[x, y] = (0, 0, 0, 0)
    return im


DRAW = {"brass": brass_frame, "pixel": pixel_frame}


def write(styles=STYLES):
    """Writes every frame under `styles`, at its pack path."""
    for name, frame in FRAMES.items():
        out = Path(styles) / frame["path"]
        out.parent.mkdir(parents=True, exist_ok=True)
        DRAW[name]().save(out, optimize=False)


if __name__ == "__main__":
    write(Path(sys.argv[1]) if len(sys.argv) > 1 else STYLES)
