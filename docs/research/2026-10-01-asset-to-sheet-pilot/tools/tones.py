"""Prints the colours of the shadows, mid-tones and highlights inside a tree's
crown (mean colour of the darkest 15%, the middle 30% and the lightest 15% of
pixels), for comparing a capture with its concept.  tones.py LABEL=PATH:x0,y0,x1,y1 ..."""
import sys
import numpy as np
from PIL import Image
for arg in sys.argv[1:]:
    label, rest = arg.split('=', 1)
    path, box = rest.rsplit(':', 1)
    x0, y0, x1, y1 = [float(v) for v in box.split(',')]
    im = Image.open(path).convert('RGB'); w, h = im.size
    a = np.asarray(im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))).reshape(-1, 3).astype(np.float64)
    lum = a @ np.array([0.2126, 0.7152, 0.0722])
    order = np.argsort(lum); n = len(order)
    parts = {'shadow': order[: int(0.15 * n)], 'mid': order[int(0.35 * n): int(0.65 * n)], 'light': order[int(0.85 * n):]}
    out = []
    for k, idx in parts.items():
        c = a[idx].mean(axis=0)
        out.append(f"{k} #{int(c[0]):02X}{int(c[1]):02X}{int(c[2]):02X} (L {lum[idx].mean() / 255:.2f})")
    print(f"{label:22s} " + " | ".join(out))
