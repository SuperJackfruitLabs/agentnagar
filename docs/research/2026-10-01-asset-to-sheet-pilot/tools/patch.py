"""patch.py LABEL=PATH:x0,y0,x1,y1 ...: the median colour of each patch, its lightness and saturation."""
import colorsys
import sys
import numpy as np
from PIL import Image
for arg in sys.argv[1:]:
    label, rest = arg.split('=', 1)
    path, box = rest.rsplit(':', 1)
    x0, y0, x1, y1 = [float(v) for v in box.split(',')]
    im = Image.open(path).convert('RGB'); w, h = im.size
    a = np.asarray(im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))).reshape(-1, 3).astype(np.float64)
    c = np.median(a, axis=0)
    hh, ll, ss = colorsys.rgb_to_hls(*(c / 255))
    lum = (c @ np.array([0.2126, 0.7152, 0.0722])) / 255
    print(f"{label:26s} #{int(c[0]):02X}{int(c[1]):02X}{int(c[2]):02X}  L {lum:.2f}  sat {ss:.2f}  hue {hh * 360:5.1f}")
