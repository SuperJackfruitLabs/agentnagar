"""bands.py STYLE CAPTURE_DIR [CAPTURE_DIR ...]: the five tone bands of the crown (darkest tenth, next quarter,
middle 30%, next quarter, lightest tenth) in the concept sheet and in captures, from the street and from above,
and three bands of the trunk. Importable: bands(), wood(), measure()."""
import os
import sys
import numpy as np
from PIL import Image
W = os.path.dirname(os.path.abspath(__file__))
BANDS = ((0.0, 0.10), (0.10, 0.35), (0.35, 0.65), (0.65, 0.90), (0.90, 1.0))
LUM = np.array([0.2126, 0.7152, 0.0722])
CROWN_SHEET = (0.28, 0.12, 0.72, 0.52)
CROWN_STREET = (0.445, 0.13, 0.555, 0.36)
CROWN_ABOVE = (0.50, 0.29, 0.58, 0.38)
TRUNK_STREET = (0.475, 0.42, 0.525, 0.60)
DIAG_SHEET = {'lowpoly_tropical': (0.52, 0.37, 0.64, 0.49)}
TRUNK = {'lowpoly_tropical': (0.40, 0.62, 0.56, 0.84), 'voxel': (0.42, 0.62, 0.56, 0.90), 'anime_cel': (0.44, 0.62, 0.58, 0.84),
         'solarpunk': (0.42, 0.62, 0.56, 0.90), 'neon_noir': (0.42, 0.62, 0.56, 0.90), 'pixel_art': (0.50, 0.62, 0.62, 0.86)}


def _pixels(path, box):
    im = Image.open(path).convert('RGB'); w, h = im.size
    return np.asarray(im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))).reshape(-1, 3).astype(np.float64)


def _split(a, cuts):
    lum = a @ LUM; order = np.argsort(lum); n = len(order)
    out = []
    for lo, hi in cuts:
        c = a[order[int(lo * n): max(int(lo * n) + 1, int(hi * n))]].mean(axis=0)
        out.append(('#%02X%02X%02X' % tuple(int(v) for v in c), float(c @ LUM) / 255, [float(v) / 255 for v in c]))
    return out


def bands(path, box):
    """Five (hex, lightness, rgb) bands of the leafy pixels in a patch (sky left out)."""
    a = _pixels(path, box)
    keep = ~((a[:, 2] > a[:, 1] * 1.05) & (a[:, 2] > a[:, 0] * 1.05))
    return _split(a[keep] if keep.sum() > 50 else a, BANDS)


def wood(path, box):
    """Three bands of the brownish pixels in a patch."""
    a = _pixels(path, box)
    keep = (a[:, 0] >= a[:, 1] * 0.98) & (a[:, 1] >= a[:, 2] * 0.92)
    return _split(a[keep] if keep.sum() > 50 else a, ((0.0, 0.25), (0.35, 0.65), (0.80, 1.0)))


def measure(style, capture_dir):
    """{'street': bands, 'above': bands, 'trunk': bands} for a capture, and the sheet's targets."""
    sheet = f'{W}/inputs/{style}-banyan.png'
    target = {'street': bands(sheet, CROWN_SHEET), 'trunk': wood(sheet, TRUNK[style])}
    target['above'] = bands(f'{W}/sheets/{style}-diagonal.png', DIAG_SHEET[style]) if style in DIAG_SHEET else target['street']
    got = {}
    if os.path.exists(f'{capture_dir}/{style}/street.png'):
        got['street'] = bands(f'{capture_dir}/{style}/street.png', CROWN_STREET)
        got['trunk'] = wood(f'{capture_dir}/{style}/street.png', TRUNK_STREET)
    if os.path.exists(f'{capture_dir}/{style}/diagonal.png'):
        got['above'] = bands(f'{capture_dir}/{style}/diagonal.png', CROWN_ABOVE)
    return target, got


def show(label, b):
    print(f"  {label:24s} " + "  ".join(f"{c} {l:.2f}" for c, l, _rgb in b))


if __name__ == '__main__':
    style = sys.argv[1]
    for view, title in (('street', 'crown from the street'), ('trunk', 'trunk from the street'), ('above', 'crown from above (diagonal)')):
        print(f"{style}: {title}")
        first = True
        for d in sys.argv[2:]:
            target, got = measure(style, d)
            if first:
                show('concept', target[view]); first = False
            if view in got:
                show(os.path.basename(d.rstrip('/')), got[view])
