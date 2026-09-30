"""Presence and badge icons for the low-poly pack: 64 x 64 PNGs drawn with
simple shapes in the 11 palette.

python3 city/tools/styles/lowpoly/icons.py [OUT_DIR]
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

DEFAULT_OUT = Path(__file__).resolve().parents[3] / "godot" / "styles" / "lowpoly_tropical" / "assets" / "icons"
S = 64
INK = (46, 43, 42, 255)
WHITE = (255, 255, 255, 255)


def disc(colour):
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse((2, 2, S - 3, S - 3), fill=colour, outline=INK, width=3)
    return im, d


def working(d):
    for k, x in enumerate((18, 32, 46)):
        d.ellipse((x - 5, 27, x + 5, 37), fill=WHITE)


def waiting(d):
    d.polygon([(20, 16), (44, 16), (32, 32)], fill=WHITE)
    d.polygon([(20, 48), (44, 48), (32, 32)], fill=WHITE)


def queued(d):
    for y in (20, 31, 42):
        d.rectangle((18, y, 46, y + 4), fill=WHITE)


def idle(d):
    d.line([(22, 20), (42, 20), (22, 44), (42, 44)], fill=WHITE, width=5)


def done(d):
    d.line([(18, 33), (28, 43), (46, 21)], fill=WHITE, width=7)


def present(d):
    d.ellipse((24, 24, 40, 40), fill=WHITE)


def offline(d):
    d.ellipse((18, 18, 46, 46), outline=WHITE, width=5)


def error(d):
    d.rectangle((29, 14, 35, 38), fill=WHITE)
    d.rectangle((29, 44, 35, 50), fill=WHITE)


def stale(d):
    d.ellipse((16, 16, 48, 48), outline=WHITE, width=4)
    d.line([(32, 32), (32, 20)], fill=WHITE, width=4)
    d.line([(32, 32), (41, 36)], fill=WHITE, width=4)


def unknown(d):
    d.arc((20, 12, 44, 36), start=180, end=90, fill=WHITE, width=6)
    d.rectangle((29, 34, 35, 42), fill=WHITE)
    d.rectangle((29, 46, 35, 52), fill=WHITE)


def badge_ai(d):
    d.rounded_rectangle((16, 18, 48, 46), radius=6, fill=WHITE)
    d.rectangle((21, 27, 43, 34), fill=(28, 36, 48, 255))


def badge_simulation(d):
    d.polygon([(32, 14), (50, 32), (32, 50), (14, 32)], fill=WHITE)


ICONS = {
    "working": ((242, 182, 50, 255), working),
    "waiting": ((47, 140, 140, 255), waiting),
    "queued": ((94, 158, 138, 255), queued),
    "idle": ((109, 179, 63, 255), idle),
    "done": ((63, 143, 58, 255), done),
    "present": ((47, 140, 140, 255), present),
    "offline": ((120, 120, 120, 255), offline),
    "error": ((196, 98, 58, 255), error),
    "stale": ((150, 140, 125, 255), stale),
    "unknown": ((110, 110, 130, 255), unknown),
    "badge_ai": ((242, 182, 50, 255), badge_ai),
    "badge_simulation": ((94, 158, 138, 255), badge_simulation),
}


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    out.mkdir(parents=True, exist_ok=True)
    for name, (colour, draw) in ICONS.items():
        im, d = disc(colour)
        draw(d)
        im.save(out / f"{name}.png", optimize=True)


if __name__ == "__main__":
    main()
