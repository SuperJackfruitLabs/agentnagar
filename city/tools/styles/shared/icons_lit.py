"""Presence and badge icons for the lit styles: the anime kit's smooth
redraw of the low-poly glyphs, on discs in each style's colours:
solarpunk's jade, coral and sun on a warm brass rim; neon noir's glowing
rims round dark navy discs.

python3 city/tools/styles/shared/icons_lit.py STYLE OUT_DIR
"""
import importlib.util
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

_spec = importlib.util.spec_from_file_location("anime_icons", Path(__file__).resolve().parents[1] / "anime" / "icons.py")
anime = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(anime)
S, SUPER = anime.S, anime.SUPER

STYLES = {
    "solarpunk": {
        "rim": (156, 122, 56, 255), "glow": None,
        "fills": {
            "working": (242, 193, 78, 255), "waiting": (60, 158, 124, 255), "queued": (62, 79, 143, 255),
            "idle": (90, 146, 51, 255), "done": (42, 122, 94, 255), "present": (43, 138, 203, 255),
            "offline": (170, 164, 150, 255), "error": (224, 85, 58, 255), "stale": (189, 178, 160, 255),
            "unknown": (130, 120, 190, 255), "badge_ai": (60, 158, 124, 255), "badge_simulation": (238, 122, 92, 255),
        },
    },
    "neon": {
        "rim": None, "glow": True,
        "fills": {
            "working": (255, 178, 60, 255), "waiting": (63, 227, 255, 255), "queued": (155, 92, 255, 255),
            "idle": (61, 200, 120, 255), "done": (47, 156, 106, 255), "present": (63, 180, 255, 255),
            "offline": (120, 126, 140, 255), "error": (255, 70, 90, 255), "stale": (150, 140, 120, 255),
            "unknown": (255, 61, 184, 255), "badge_ai": (63, 227, 255, 255), "badge_simulation": (255, 61, 184, 255),
        },
    },
}
NAVY = (22, 30, 52, 255)


def icon(style, name):
    spec = STYLES[style]
    colour = spec["fills"][name]
    big = Image.new("RGBA", (S * SUPER, S * SUPER), (0, 0, 0, 0))
    d = anime.Scaled(ImageDraw.Draw(big), SUPER)
    if spec["glow"]:
        halo = Image.new("RGBA", big.size, (0, 0, 0, 0))
        anime.Scaled(ImageDraw.Draw(halo), SUPER).ellipse((3, 3, S - 4, S - 4), outline=colour, width=5)
        big.alpha_composite(halo.filter(ImageFilter.GaussianBlur(radius=SUPER * 2.5)))
        d.ellipse((4, 4, S - 5, S - 5), fill=NAVY, outline=colour, width=3)
        glyph = Image.new("RGBA", big.size, (0, 0, 0, 0))
        getattr(anime.glyphs, name)(anime.Scaled(ImageDraw.Draw(glyph), SUPER))
        # The glyph glows in the icon's colour on the dark disc.
        tinted = Image.new("RGBA", big.size, colour)
        tinted.putalpha(glyph.getchannel("A"))
        big.alpha_composite(tinted)
    else:
        d.ellipse((2, 2, S - 3, S - 3), fill=colour, outline=spec["rim"], width=3)
        getattr(anime.glyphs, name)(d)
    return big.resize((S, S), Image.LANCZOS)


def main(style, out):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for name in STYLES[style]["fills"]:
        icon(style, name).save(out / f"{name}.png", optimize=False)
    print(f"icons: wrote {len(STYLES[style]['fills'])} {style} icons")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
