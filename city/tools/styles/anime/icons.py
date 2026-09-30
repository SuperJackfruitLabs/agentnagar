"""Presence and badge icons for the anime pack: the low-poly kit's glyphs,
redrawn at SUPER times the size and downsampled so every edge is smooth,
on discs in the anime palette with an indigo ink rim.

python3 city/tools/styles/anime/icons.py [OUT_DIR]
"""
import importlib.util
import sys
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
DEFAULT_OUT = HERE.parents[2] / "godot" / "styles" / "anime_cel" / "assets" / "icons"
_spec = importlib.util.spec_from_file_location("lowpoly_icons", HERE.parent / "lowpoly" / "icons.py")
glyphs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(glyphs)
S = 64
SUPER = 4
INK = (43, 44, 69, 255)


class Scaled:
    """An ImageDraw whose coordinates and widths are in 64 px icon units."""

    def __init__(self, draw, k):
        self.d, self.k = draw, k

    def _xy(self, xy):
        if isinstance(xy, (list, tuple)) and xy and isinstance(xy[0], (list, tuple)):
            return [(x * self.k, y * self.k) for x, y in xy]
        return [v * self.k for v in xy]

    def _kw(self, kw):
        out = dict(kw)
        for key in ("width", "radius"):
            if key in out:
                out[key] = out[key] * self.k
        return out

    def ellipse(self, xy, **kw):
        self.d.ellipse(self._xy(xy), **self._kw(kw))

    def rectangle(self, xy, **kw):
        self.d.rectangle(self._xy(xy), **self._kw(kw))

    def rounded_rectangle(self, xy, **kw):
        self.d.rounded_rectangle(self._xy(xy), **self._kw(kw))

    def polygon(self, xy, **kw):
        self.d.polygon(self._xy(xy), **self._kw(kw))

    def line(self, xy, **kw):
        self.d.line(self._xy(xy), joint="curve", **self._kw(kw))

    def arc(self, xy, start, end, **kw):
        self.d.arc(self._xy(xy), start, end, **self._kw(kw))


COLOURS = {
    "working": (244, 194, 74, 255), "waiting": (47, 100, 201, 255), "queued": (62, 66, 143, 255),
    "idle": (92, 159, 64, 255), "done": (59, 123, 59, 255), "present": (47, 128, 203, 255),
    "offline": (154, 160, 174, 255), "error": (228, 81, 59, 255), "stale": (183, 165, 138, 255),
    "unknown": (116, 120, 196, 255), "badge_ai": (47, 100, 201, 255), "badge_simulation": (92, 159, 64, 255),
}


def icon(name):
    big = Image.new("RGBA", (S * SUPER, S * SUPER), (0, 0, 0, 0))
    d = Scaled(ImageDraw.Draw(big), SUPER)
    d.ellipse((2, 2, S - 3, S - 3), fill=COLOURS[name], outline=INK, width=3)
    getattr(glyphs, name)(d)
    return big.resize((S, S), Image.LANCZOS)


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    out.mkdir(parents=True, exist_ok=True)
    for name in COLOURS:
        icon(name).save(out / f"{name}.png", optimize=False)
    print(f"icons: wrote {len(COLOURS)} icons")


if __name__ == "__main__":
    main()
