"""ramps.py: the colours a style's concept sheet paints its banyan in, as five
stops from shadow to highlight (mean colour of each luminance band of the crown
patch) and three for the trunk. Writes ramps.json and a swatch sheet."""
import json
import os
import numpy as np
from PIL import Image, ImageDraw
W = os.path.dirname(os.path.abspath(__file__))
CROWN = (0.28, 0.12, 0.72, 0.52)
TRUNK = {'lowpoly_tropical': (0.40, 0.62, 0.56, 0.84), 'voxel': (0.42, 0.62, 0.56, 0.90), 'anime_cel': (0.44, 0.62, 0.58, 0.84),
         'solarpunk': (0.42, 0.62, 0.56, 0.90), 'neon_noir': (0.42, 0.62, 0.56, 0.90), 'pixel_art': (0.50, 0.62, 0.62, 0.86)}
BANDS = ((0.0, 0.10), (0.10, 0.35), (0.35, 0.65), (0.65, 0.90), (0.90, 1.0))
out = {}
sw = Image.new('RGB', (60 * 9 + 150, 46 * 6), 'white'); d = ImageDraw.Draw(sw)
for row, style in enumerate(('lowpoly_tropical', 'voxel', 'anime_cel', 'solarpunk', 'neon_noir', 'pixel_art')):
    im = Image.open(f'{W}/inputs/{style}-banyan.png').convert('RGB'); w, h = im.size
    def bands(box, wood=False):
        a = np.asarray(im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))).reshape(-1, 3).astype(np.float64)
        if wood:   # keep brownish pixels only: red over green over blue, not sky, not leaf
            keep = (a[:, 0] >= a[:, 1] * 0.98) & (a[:, 1] >= a[:, 2] * 0.92)
            a = a[keep] if keep.sum() > 50 else a
        else:      # keep leafy pixels only: not sky (blue highest)
            keep = ~((a[:, 2] > a[:, 1] * 1.05) & (a[:, 2] > a[:, 0] * 1.05))
            a = a[keep] if keep.sum() > 50 else a
        lum = a @ np.array([0.2126, 0.7152, 0.0722]); order = np.argsort(lum); n = len(order)
        use = BANDS if not wood else ((0.0, 0.25), (0.35, 0.65), (0.80, 1.0))
        return ['#%02X%02X%02X' % tuple(int(v) for v in a[order[int(lo * n): max(int(lo * n) + 1, int(hi * n))]].mean(axis=0)) for lo, hi in use]
    out[style] = {'leaf': bands(CROWN), 'wood': bands(TRUNK[style], wood=True)}
    d.text((4, row * 46 + 14), style, fill=(0, 0, 0))
    for k, c in enumerate(out[style]['leaf'] + [None] + out[style]['wood']):
        if c:
            d.rectangle([150 + k * 60, row * 46 + 3, 150 + k * 60 + 56, row * 46 + 42], fill=c)
    print(style, out[style])
# The trunk patch of two sheets takes in things that are not bark (leaves, a lamp's glow): their lightest
# stop is set by hand to a lighter tone of the sheet's own bark.
out['anime_cel']['wood'][2] = '#8E7C66'
out['pixel_art']['wood'][2] = '#8A5E4C'
json.dump(out, open(f'{W}/ramps.json', 'w'), indent=1)
sw.save(f'{W}/previews/ramps.png')
