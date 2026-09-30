"""Face atlases for the semi-realistic styles (09 Solarpunk, 10 Neon noir):
illustrated human faces (almond eyes with irises, lids, lashes and a
catchlight, brows drawn hair-wise, nostrils, two-tone lips) over
transparency so one atlas suits every skin tone, the head's modelled
brow, nose, cheeks and lips taking the light beneath; and the robot
agents' emissive eye atlases (solarpunk's two cyan eyes on a dark visor,
neon's single cyan ring).

Layout matches the anime atlas (faces.py): columns are expressions
(neutral, smile, talk, surprised, blink), rows face variants; CELL px
cells drawn at SUPER times and downsampled. Each human cell is a
straight front view of the face plate of people.py: x metres either side
of the midline (the person's right on the viewer's left), z metres up,
in the box FACE_HW wide either side, FACE_BOTTOM to FACE_TOP high (these
must match people.py). The lit face shader draws texels at alpha 0.5 and
over, so features are opaque and their colours are bled into the clear
texels round them (clean edges under filtering and mipmaps).
Deterministic: standard library plus Pillow.
"""
import math

from PIL import Image, ImageDraw, ImageFilter

CELL = 256
SUPER = 4
EXPRESSIONS = ["neutral", "smile", "talk", "surprised", "blink"]
# Four faces: iris colour; eye width, openness and tilt (outer corner up,
# metres); brow weight and arch; a winged lash line; a lid crease; mouth
# width and lip fullness.
VARIANTS = [
    {"iris": (112, 74, 46), "width": 1.0, "open": 1.0, "tilt": 0.0011, "brow": 0.85, "arch": 1.2, "wing": True,
     "crease": True, "mouth": 0.96, "lips": 1.15},
    {"iris": (60, 42, 32), "width": 1.03, "open": 0.84, "tilt": 0.0002, "brow": 1.3, "arch": 0.45, "wing": False,
     "crease": True, "mouth": 1.06, "lips": 0.8},
    {"iris": (86, 116, 142), "width": 0.95, "open": 1.12, "tilt": -0.0004, "brow": 1.0, "arch": 1.0, "wing": False,
     "crease": True, "mouth": 0.94, "lips": 1.0},
    {"iris": (92, 100, 58), "width": 1.0, "open": 0.76, "tilt": 0.0016, "brow": 1.05, "arch": 0.7, "wing": True,
     "crease": False, "mouth": 1.0, "lips": 1.05},
]
# The face frame (people.py) and where the features sit on the head.
FACE_TOP, FACE_BOTTOM, FACE_HW = 1.668, 1.494, 0.087
EYE_X, EYE_Z = 0.031, 1.6105
BROW_Z = 1.6295
NOSTRIL_Z = 1.5703
MOUTH_Z = 1.547
LASH = (36, 26, 24, 255)
LID = (98, 64, 56, 255)
BROW = (60, 44, 36, 255)
WHITE = (226, 220, 211, 255)
NOSTRIL = (82, 48, 43, 255)
INSIDE = (62, 30, 32, 255)
TEETH = (234, 228, 218, 255)
# Lips per style: upper, lower, the line between.
LIPS = {"warm": ((138, 78, 72, 255), (156, 92, 84, 255), (84, 42, 40, 255)),
        "cool": ((128, 72, 76, 255), (146, 86, 90, 255), (76, 38, 44, 255))}


def _pt(x, y):
    s = CELL * SUPER
    return (x * s, y * s)


def _w(frac):
    return max(1, int(frac * CELL * SUPER))


def _p(x, z):
    """Pixel of the supersampled cell at face-frame (x, z) metres."""
    s = CELL * SUPER
    return ((0.5 - x / (2 * FACE_HW)) * s, (FACE_TOP - z) / (FACE_TOP - FACE_BOTTOM) * s)


def _m(metres):
    """A length in supersampled pixels."""
    return metres / (FACE_TOP - FACE_BOTTOM) * CELL * SUPER


def _stroke(d, pts, widths, fill):
    """A tapered stroke through face-frame points: a polygon offset either
    side by half the width at each point."""
    left, right = [], []
    for i, (x, z) in enumerate(pts):
        x0, z0 = pts[max(i - 1, 0)]
        x1, z1 = pts[min(i + 1, len(pts) - 1)]
        tx, tz = x1 - x0, z1 - z0
        ln = math.hypot(tx, tz) or 1.0
        nx, nz = -tz / ln, tx / ln
        h = widths[i] / 2
        left.append(_p(x + nx * h, z + nz * h))
        right.append(_p(x - nx * h, z - nz * h))
    d.polygon(left + right[::-1], fill=fill)


def _lids(side, v, expr):
    """The eye opening's outline in face-frame metres: (upper, lower) point
    lists from the inner corner to the outer."""
    hw = 0.0154 * v["width"]
    up = 0.006 * v["open"]
    lo = 0.004 * v["open"]
    if expr == "smile":
        up, lo = up * 0.9, lo * 0.5
    elif expr == "surprised":
        up, lo = up * 1.4, lo * 1.12
    upper, lower = [], []
    for k in range(19):
        t = math.pi * k / 18
        u = -math.cos(t)  # -1 inner corner, +1 outer
        x = side * (EYE_X + hw * u)
        tilt = v["tilt"] * (u + 1) / 2
        upper.append((x, EYE_Z + tilt + up * math.sin(t) ** 0.8 * (1.0 - 0.12 * u)))
        lower.append((x, EYE_Z + tilt - lo * math.sin(t) ** 1.2 * (1.0 + 0.18 * u)
                      + (0.0012 * math.sin(t) if expr == "smile" else 0.0)))
    return upper, lower


def _eye(img, side, v, expr):
    d = ImageDraw.Draw(img)
    upper, lower = _lids(side, v, expr)
    if expr == "blink":
        # Closed: the lid's lash line curving down, the crease above.
        lid = [(x, z - 0.0016 - 0.0022 * math.sin(math.pi * k / 18)) for k, (x, z) in enumerate(upper)]
        _stroke(d, lid, [0.0009 + 0.0009 * k / 18 for k in range(19)], LASH)
        crease = [(x, z + 0.0006) for x, z in upper[3:17]]
        if v["crease"]:
            _stroke(d, crease, [0.0006] * len(crease), LID)
        return
    outline = [_p(x, z) for x, z in upper] + [_p(x, z) for x, z in lower[::-1]]
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.polygon(outline, fill=WHITE)
    cx, cz = side * EYE_X, EYE_Z + v["tilt"] / 2 - 0.0003
    r = 0.0056
    ir = v["iris"]
    dark = tuple(int(c * 0.55) for c in ir) + (255,)
    ld.ellipse([_p(cx + r, cz + r), _p(cx - r, cz - r)], fill=dark)
    ld.ellipse([_p(cx + r * 0.86, cz + r * 0.86), _p(cx - r * 0.86, cz - r * 0.86)], fill=ir + (255,))
    light = tuple(min(255, int(c * 1.3 + 12)) for c in ir) + (255,)
    ld.chord([_p(cx + r * 0.8, cz + r * 0.8), _p(cx - r * 0.8, cz - r * 0.8)], 20, 160, fill=light)
    ld.ellipse([_p(cx + r * 0.62, cz + r * 0.62), _p(cx - r * 0.62, cz - r * 0.62)], fill=ir + (255,))
    ld.ellipse([_p(cx + 0.0019, cz + 0.0019), _p(cx - 0.0019, cz - 0.0019)], fill=(16, 12, 12, 255))
    # The upper lid's shadow across the top of the eye.
    shadow = [(x, z) for x, z in upper] + [(x, z - 0.0016) for x, z in upper[::-1]]
    ld.polygon([_p(x, z) for x, z in shadow], fill=(120, 100, 96, 255))
    hx, hz = _p(cx, cz)
    rr = _m(0.0009)
    ld.ellipse([hx - _m(0.0017) - rr, hz - _m(0.0017) - rr, hx - _m(0.0017) + rr, hz - _m(0.0017) + rr],
               fill=(250, 248, 244, 255))
    img.alpha_composite(Image.composite(layer, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))
    # The lash line along the upper lid, heavier to the outer corner.
    widths = [0.0011 + 0.001 * (k / 18) ** 1.5 for k in range(19)]
    _stroke(d, upper, widths, LASH)
    if v["wing"]:
        x1, z1 = upper[-1]
        _stroke(d, [upper[-3], (x1, z1), (x1 + side * 0.0026, z1 + 0.0014)], [0.0014, 0.0013, 0.0004], LASH)
    # The lower lid, faint, on its outer part.
    _stroke(d, lower[7:], [0.0006] * len(lower[7:]), LID)
    if v["crease"]:
        crease = [(x, z + 0.0034 + 0.0006 * math.sin(math.pi * k / 13)) for k, (x, z) in enumerate(upper[3:17])]
        _stroke(d, crease, [0.0005 + 0.0002 * math.sin(math.pi * k / 13) for k in range(len(crease))], LID)
    else:
        # A hooded lid: the fold's edge close over the lash line.
        fold = [(x, z + 0.0012) for x, z in upper[6:18]]
        _stroke(d, fold, [0.0005] * len(fold), LID)


def _brow(d, side, v, expr):
    lift = {"surprised": 0.0045, "smile": 0.001, "talk": 0.0007}.get(expr, 0.0)
    arch = 0.0034 * v["arch"] + (0.0012 if expr == "surprised" else 0.0)
    w = 0.0034 * v["brow"]
    pts, widths = [], []
    for k in range(13):
        u = k / 12
        x = side * (0.0125 + 0.046 * u)
        z = BROW_Z + lift * (1.0 - 0.3 * u) + arch * math.sin(math.pi * min(1.0, u / 0.7) * 0.5) ** 1.5 \
            - (0.0026 * ((u - 0.7) / 0.3) ** 2 if u > 0.7 else 0.0)
        pts.append((x, z))
        widths.append(w * (1.0 - 0.62 * u ** 1.3))
    _stroke(d, pts, widths, BROW)
    # Hairs at the inner end, brushed up.
    for k in range(4):
        x, z = pts[k]
        _stroke(d, [(x, z - w * 0.4), (x + side * 0.0012, z + w * 0.7)], [0.0006, 0.0003], BROW)


def _nose(d):
    for s in (-1, 1):
        cx = s * 0.0066
        pts = [(cx - s * 0.0024, NOSTRIL_Z - 0.0003), (cx, NOSTRIL_Z + 0.0005), (cx + s * 0.0022, NOSTRIL_Z + 0.0001)]
        _stroke(d, pts, [0.0011, 0.0017, 0.0009], NOSTRIL)


def _lip_shapes(v, expr):
    """Upper lip, lower lip and the opening (or None), as face-frame point
    lists; and the mouth line."""
    mw = 0.0232 * v["mouth"]
    full = v["lips"]
    n = 16
    if expr in ("neutral", "blink"):
        line = [(mw * (2 * k / n - 1), MOUTH_Z + 0.0005 * (1 - (2 * k / n - 1) ** 2)) for k in range(n + 1)]
        opening = None
        top_c, bot_c = 0.0056 * full, 0.0078 * full
    elif expr == "smile":
        mw *= 1.08
        line = [(mw * (2 * k / n - 1), MOUTH_Z + 0.0032 * (2 * k / n - 1) ** 2) for k in range(n + 1)]
        # The lips part over the upper teeth.
        opening = ([(x, z + 0.0003 * (1 - (x / mw) ** 2)) for x, z in line],
                   [(x, z - 0.0042 * (1 - (x / mw) ** 2)) for x, z in line])
        top_c, bot_c = 0.0048 * full, 0.0062 * full
    elif expr == "talk":
        mw *= 0.86
        line = [(mw * (2 * k / n - 1), MOUTH_Z + 0.0014 * (1 - (2 * k / n - 1) ** 2)) for k in range(n + 1)]
        opening = ([(x, z + 0.0008 * (1 - (x / mw) ** 2)) for x, z in line],
                   [(x, z - 0.0072 * (1 - (x / mw) ** 2) ** 0.8) for x, z in line])
        top_c, bot_c = 0.0052 * full, 0.0068 * full
    else:  # surprised: a small round opening
        mw *= 0.56
        line = [(mw * math.cos(math.pi * (1 - k / n)), MOUTH_Z - 0.0022) for k in range(n + 1)]
        opening = ([(mw * 0.8 * math.cos(math.pi * (1 - k / n)), MOUTH_Z - 0.0022 + 0.0042 * math.sin(math.pi * k / n))
                    for k in range(n + 1)],
                   [(mw * 0.8 * math.cos(math.pi * (1 - k / n)), MOUTH_Z - 0.0022 - 0.0052 * math.sin(math.pi * k / n))
                    for k in range(n + 1)])
        top_c, bot_c = 0.0054 * full, 0.0068 * full
    # The upper lip's outer border: a cupid's bow over the line.
    upper = []
    for x, z in line:
        u = abs(x) / mw
        bow = 1.0 - 0.28 * math.exp(-(u / 0.14) ** 2) + 0.12 * math.exp(-((u - 0.3) / 0.14) ** 2)
        upper.append((x, z + top_c * bow * (1 - u ** 2.2) ** 0.7))
    lower = [(x, z - bot_c * (1 - (abs(x) / mw) ** 2) ** 0.75) for x, z in line]
    return line, upper, lower, opening


def _mouth(d, v, expr, lips):
    up_c, lo_c, line_c = lips
    line, upper, lower, opening = _lip_shapes(v, expr)
    if opening is None:
        d.polygon([_p(*q) for q in line + upper[::-1]], fill=up_c)
        d.polygon([_p(*q) for q in line + lower[::-1]], fill=lo_c)
    else:
        top_in, bot_in = opening
        if expr == "surprised":
            outer_top = [(x * 1.45, MOUTH_Z - 0.0022 + (z - MOUTH_Z + 0.0022) * 1.55) for x, z in top_in]
            outer_bot = [(x * 1.45, MOUTH_Z - 0.0022 + (z - MOUTH_Z + 0.0022) * 1.45) for x, z in bot_in]
            d.polygon([_p(*q) for q in outer_top + outer_bot[::-1]], fill=lo_c)
            d.polygon([_p(*q) for q in outer_top + top_in[::-1]], fill=up_c)
            d.polygon([_p(*q) for q in top_in + bot_in[::-1]], fill=INSIDE)
            teeth = [(x, z - 0.0012) for x, z in top_in]
            d.polygon([_p(*q) for q in top_in[3:-3] + teeth[3:-3][::-1]], fill=TEETH)
            return
        d.polygon([_p(*q) for q in top_in + upper[::-1]], fill=up_c)
        d.polygon([_p(*q) for q in bot_in + lower[::-1]], fill=lo_c)
        d.polygon([_p(*q) for q in top_in + bot_in[::-1]], fill=INSIDE)
        depth = 0.0034 if expr == "smile" else 0.0016
        teeth = [(x, z - depth * (1 - (x / line[-1][0]) ** 2) ** 0.5) for x, z in top_in]
        d.polygon([_p(*q) for q in top_in[2:-2] + teeth[2:-2][::-1]], fill=TEETH)
        if expr == "talk":
            tongue = [(x * 0.7, z + 0.0018 * (1 - (x / line[-1][0]) ** 2)) for x, z in bot_in]
            d.polygon([_p(*q) for q in bot_in[3:-3] + tongue[3:-3][::-1]], fill=(150, 74, 78, 255))
        line = top_in
    _stroke(d, line, [0.0006 + 0.0005 * (1 - abs(2 * k / (len(line) - 1) - 1)) for k in range(len(line))], line_c)
    # Corners of the mouth.
    for s in (-1, 1):
        x, z = line[-1] if s > 0 else line[0]
        _stroke(d, [(x - s * 0.0015, z), (x + s * 0.0012, z + (0.0014 if expr == "smile" else -0.0002))],
                [0.0007, 0.0003], line_c)


def _bleed(img, reach=9):
    """Fills the colour of the clear texels within `reach` of a feature
    from the features nearest them (a push-pull through halved copies),
    keeping alpha; texels further out stay black."""
    levels = [img]
    while min(levels[-1].size) > 2:
        w, h = levels[-1].size
        levels.append(levels[-1].resize((max(1, w // 2), max(1, h // 2)), Image.BOX))
    rgb = levels[-1].convert("RGB")
    for lvl in reversed(levels[:-1]):
        up = rgb.resize(lvl.size, Image.BILINEAR)
        mask = lvl.getchannel("A").point(lambda a: 255 if a > 0 else 0)
        rgb = Image.composite(lvl.convert("RGB"), up, mask)
    near = img.getchannel("A").point(lambda a: 255 if a > 0 else 0).filter(ImageFilter.MaxFilter(reach))
    out = Image.composite(rgb, Image.new("RGB", img.size, (0, 0, 0)), near).convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def cell(variant, expr, blush=40, lips="warm"):
    s = CELL * SUPER
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    if blush:
        # Warm cheeks, drawn under the shader's alpha threshold: they show
        # only if the face is ever blended rather than cut out.
        shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shade)
        for side in (-1, 1):
            x0, z0 = _p(side * 0.047 + 0.012, 1.593)
            x1, z1 = _p(side * 0.047 - 0.012, 1.577)
            sd.ellipse([min(x0, x1), z0, max(x0, x1), z1], fill=(200, 110, 100, blush))
        img.alpha_composite(shade.filter(ImageFilter.GaussianBlur(radius=s * 0.02)))
    d = ImageDraw.Draw(img)
    for side in (-1, 1):
        _eye(img, side, variant, expr)
        _brow(d, side, variant, expr)
    _nose(d)
    _mouth(d, variant, expr, LIPS[lips])
    return img.resize((CELL, CELL), Image.LANCZOS)


# Per style: cheek warmth (solarpunk's sunlit faces; none under neon) and
# the lip tone.
STYLES = {"solarpunk": {"blush": 40, "lips": "warm"}, "neon": {"blush": 0, "lips": "cool"}}


def atlas(style="solarpunk"):
    out = Image.new("RGBA", (CELL * len(EXPRESSIONS), CELL * len(VARIANTS)), (0, 0, 0, 0))
    for row, v in enumerate(VARIANTS):
        for col, e in enumerate(EXPRESSIONS):
            out.paste(cell(v, e, **STYLES[style]), (col * CELL, row * CELL))
    return _bleed(out)


# ---- Robot eyes ----

EYE_EXPRESSIONS = ["neutral", "smile", "talk", "surprised", "blink"]


def robot_eyes(kind, colour=(96, 232, 236)):
    """A row of robot eye cells (one per expression), light on black:
    'pair' (solarpunk: two soft eyes, arcs when smiling) or 'ring' (neon:
    one ring eye). The pack draws them emissive on the visor."""
    out = Image.new("RGBA", (CELL * len(EYE_EXPRESSIONS), CELL), (0, 0, 0, 255))
    glow = colour + (255,)
    for col, e in enumerate(EYE_EXPRESSIONS):
        s = CELL * SUPER
        img = Image.new("RGBA", (s, s), (0, 0, 0, 255))
        d = ImageDraw.Draw(img)
        if kind == "pair":
            for x in (0.27, 0.73):
                if e == "blink":
                    d.line([_pt(x - 0.13, 0.52), _pt(x + 0.13, 0.52)], fill=glow, width=_w(0.05))
                elif e == "smile":
                    pts = [(x + 0.13 * math.cos(math.radians(a)), 0.58 - 0.15 * math.sin(math.radians(a))) for a in range(0, 181, 10)]
                    d.line([_pt(*p) for p in pts], fill=glow, width=_w(0.06), joint="curve")
                else:
                    r = 0.21 if e == "surprised" else 0.19
                    d.ellipse([_pt(x - r * 0.7, 0.5 - r), _pt(x + r * 0.7, 0.5 + r)], fill=glow)
            if e == "talk":
                d.line([_pt(0.43, 0.8), _pt(0.57, 0.8)], fill=glow, width=_w(0.03))
        else:
            r = 0.2 if e != "surprised" else 0.24
            if e == "blink":
                d.line([_pt(0.34, 0.5), _pt(0.66, 0.5)], fill=glow, width=_w(0.04))
            else:
                d.ellipse([_pt(0.5 - r, 0.5 - r), _pt(0.5 + r, 0.5 + r)], outline=glow, width=_w(0.05))
                if e == "smile":
                    d.arc([_pt(0.5 - r * 0.6, 0.5 - r * 0.6), _pt(0.5 + r * 0.6, 0.5 + r * 0.6)], 20, 160, fill=glow, width=_w(0.03))
                elif e == "talk":
                    d.ellipse([_pt(0.5 - r * 0.35, 0.5 - r * 0.35), _pt(0.5 + r * 0.35, 0.5 + r * 0.35)], fill=glow)
        bloom = img.filter(ImageFilter.GaussianBlur(radius=s * 0.012))
        img = Image.blend(bloom, img, 0.65)
        out.paste(img.resize((CELL, CELL), Image.LANCZOS), (col * CELL, 0))
    return out


def write(out, style, eyes):
    """Writes face_atlas.png (for `style`) and eyes_atlas.png (robot eyes of
    kind `eyes`: 'pair' or 'ring') into directory `out`."""
    from pathlib import Path
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    atlas(style).save(out / "face_atlas.png", optimize=False)
    robot_eyes(eyes).save(out / "eyes_atlas.png", optimize=False)
    print(f"faces_real: wrote face_atlas.png ({style}) and eyes_atlas.png ({eyes})")


if __name__ == "__main__":
    import sys
    write(sys.argv[1], sys.argv[2], sys.argv[3])
