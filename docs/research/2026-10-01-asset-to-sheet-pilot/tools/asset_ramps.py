"""asset_ramps.py CONFIG: the colours each style's sheet paints an asset's materials in, as ramps from shadow
to highlight (the mean colour of each lightness band of the config's boxes for that material; five stops, or
three where the config's `stops` says so). Writes ramps.json and ramps.png beside CONFIG.

Check ramps.png by eye before using it: a box that takes in something else gives a wrong stop.
"""
import json
import os
import sys
from PIL import Image, ImageDraw
import asset_bands as A

path = sys.argv[1]
config = json.load(open(path))
here = os.path.dirname(os.path.abspath(path))
out = {}
styles = list(config['styles'])
sw = Image.new('RGB', (170 + 60 * 9, 46 * len(styles)), 'white'); d = ImageDraw.Draw(sw)
for row, style in enumerate(styles):
    bands = A.sheet_bands(config, style)
    out[style] = {k: [b[0] for b in v] for k, v in bands.items() if v}
    # A stop set by hand, where a box could not help taking in something else (the config says why).
    for kind, stops in config.get('ramp_override', {}).get(style, {}).items():
        out[style][kind] = [s or o for s, o in zip(stops, out[style][kind])]
    d.text((4, row * 46 + 14), style, fill=(0, 0, 0))
    x = 170
    for kind in config['kinds']:
        for c in out[style].get(kind, []):
            d.rectangle([x, row * 46 + 3, x + 56, row * 46 + 42], fill=c); x += 60
        x += 30
    print(style, out[style])
json.dump(out, open(f'{here}/ramps.json', 'w'), indent=1)
sw.save(f'{here}/ramps.png')
