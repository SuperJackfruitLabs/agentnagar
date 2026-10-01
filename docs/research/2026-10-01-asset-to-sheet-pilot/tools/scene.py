"""scene.py LABEL=DIR ...: patches of the low-poly frame beside the concept sheet's: paving, a far building's
lightness and contrast (haze), a ground shadow against lit paving."""
import os
import sys
import numpy as np
from PIL import Image
W = os.path.dirname(os.path.abspath(__file__))
LUM = np.array([0.2126, 0.7152, 0.0722])


def patch(path, box):
    im = Image.open(path).convert('RGB'); w, h = im.size
    a = np.asarray(im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))).reshape(-1, 3).astype(np.float64)
    lum = (a @ LUM) / 255
    c = np.median(a, axis=0)
    return '#%02X%02X%02X' % tuple(int(v) for v in c), float(np.median(lum)), float(lum.std())


def line(label, path, boxes):
    out = []
    for name, box in boxes.items():
        hx, l, sd = patch(path, box)
        out.append(f"{name} {hx} L {l:.2f} sd {sd:.2f}")
    print(f"{label:14s} " + " | ".join(out))


line('concept', f'{W}/sheets/lowpoly_tropical-street.png',
     {'far building': (0.36, 0.17, 0.44, 0.30), 'lit paving': (0.45, 0.80, 0.52, 0.84), 'ground shadow': (0.58, 0.955, 0.66, 0.985)})
for arg in sys.argv[1:]:
    label, d = arg.split('=')
    line(label, f'{d}/lowpoly_tropical/street.png',
         {'far building': (0.22, 0.16, 0.30, 0.40), 'lit paving': (0.20, 0.80, 0.34, 0.90), 'ground shadow': (0.625, 0.765, 0.655, 0.785)})
