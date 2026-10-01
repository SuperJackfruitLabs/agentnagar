"""look.py STYLE ROUND2_DIR OUT.png: concept and capture side by side for the street view (top row) and,
below, today's and the new diagonal view cropped on the tree."""
import os
import sys
from PIL import Image
W = os.path.dirname(os.path.abspath(__file__))
style, r2, out = sys.argv[1], sys.argv[2], sys.argv[3]
H = 620


def fit(im, h=H):
    return im.resize((int(im.width * h / im.height), h))


def street(path):
    im = Image.open(path).convert('RGB'); w, h = im.size
    return im.crop((int(w * 0.30), int(h * 0.02), int(w * 0.72), int(h * 0.72)))


def above(path, view, box):
    im = Image.open(path.replace('street', view)).convert('RGB'); w, h = im.size
    return im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))


top = [fit(Image.open(f'{W}/inputs/{style}-banyan.png').convert('RGB')), fit(street(f'{W}/captures/before/{style}/street.png')),
       fit(street(f'{r2}/{style}/street.png'))]
box = (0.40, 0.18, 0.70, 0.52)
bottom = [fit(above(f'{W}/captures/before/{style}/street.png', 'diagonal', box), 400), fit(above(f'{r2}/{style}/street.png', 'diagonal', box), 400),
          fit(above(f'{r2}/{style}/street.png', 'topdown', (0.36, 0.25, 0.64, 0.75)), 400), fit(above(f'{r2}/{style}/street.png', 'gathering', (0.2, 0.05, 0.8, 0.95)), 400)]
width = max(sum(t.width for t in top), sum(t.width for t in bottom))
sheet = Image.new('RGB', (width, H + 400), 'white')
x = 0
for t in top:
    sheet.paste(t, (x, 0)); x += t.width
x = 0
for t in bottom:
    sheet.paste(t, (x, H)); x += t.width
sheet.save(out); print(out, sheet.size)
