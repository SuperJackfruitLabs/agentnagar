"""metrics.py: how a tree's crown looks, in numbers, for the concept sheet and each game version.

Inside the crown patch (resized to 256 x 192): contrast (standard deviation of lightness), fine detail (mean
absolute difference between neighbouring pixels), colour variety (distinct colours at 32 levels a channel),
deep shadow (share of pixels under half the median lightness) and highlight (share over one and a half times
it). These were the numbers behind round 1's finding that the look had not moved; they are not what round 2's
colours were fitted to (that was the five tone bands, see bands.py).
"""
import json
import os
import sys
import numpy as np
from PIL import Image
W = os.path.dirname(os.path.abspath(__file__))
LUM = np.array([0.2126, 0.7152, 0.0722])
SHEET, STREET = (0.28, 0.12, 0.72, 0.52), (0.445, 0.13, 0.555, 0.36)


def look(path, box):
    im = Image.open(path).convert('RGB'); w, h = im.size
    a = np.asarray(im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h))).resize((256, 192), Image.LANCZOS)).astype(np.float64)
    lum = (a @ LUM) / 255
    grad = (np.abs(np.diff(lum, axis=0)).mean() + np.abs(np.diff(lum, axis=1)).mean()) / 2
    q = (a // 8).astype(np.int64).reshape(-1, 3)
    colours = len(np.unique(q[:, 0] * 1024 + q[:, 1] * 32 + q[:, 2]))
    med = np.median(lum)
    return {'contrast': round(float(lum.std()), 3), 'detail': round(float(grad), 4), 'colours': int(colours),
            'deep_shadow': round(float((lum < 0.5 * med).mean()), 3), 'highlight': round(float((lum > 1.5 * med).mean()), 3)}


def closeness(a, b):
    """How far a version sits from the sheet over the five measures: the mean of |log ratio| (0 = the same)."""
    out = []
    for k in a:
        x, y = max(a[k], 1e-3), max(b[k], 1e-3)
        out.append(abs(np.log(x / y)))
    return round(float(np.mean(out)), 3)


rows = {}
final = json.load(open(f'{W}/final.json'))
for style in ('lowpoly_tropical', 'voxel', 'anime_cel', 'solarpunk', 'neon_noir'):
    sheet = look(f'{W}/inputs/{style}-banyan.png', SHEET)
    rows[style] = {'concept': sheet}
    for label, d in (('today', f'{W}/captures/before'), ('round 1', f'{W}/captures/after'), ('round 2', f'{W}/captures/{final[style]}')):
        m = look(f'{d}/{style}/street.png', STREET)
        m['distance'] = closeness({k: m[k] for k in sheet}, sheet)
        rows[style][label] = m
json.dump(rows, open(f'{W}/metrics.json', 'w'), indent=1)
for style, r in rows.items():
    print(style)
    for label, m in r.items():
        print(f"  {label:9s} contrast {m['contrast']:.3f}  detail {m['detail']:.4f}  colours {m['colours']:4d}  deep shadow {m['deep_shadow']:.3f}  highlight {m['highlight']:.3f}"
              + (f"  | distance from the sheet {m['distance']:.3f}" if 'distance' in m else ''))
