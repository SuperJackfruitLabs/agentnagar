"""grid.py IN OUT [WIDTH] [x0,y0,x1,y1 [STEP]]: the image with a labelled grid, for picking patches by eye.

With no box: a 10 x 10 grid over the whole image, labelled in fractions of its width and height.
With a box (fractions of the image): that part enlarged, with a line every STEP (default 0.02) labelled in
fractions of the WHOLE image, so a patch read off it can be used as it is.
"""
import sys
from PIL import Image, ImageDraw
im = Image.open(sys.argv[1]).convert('RGB')
width = int(sys.argv[3]) if len(sys.argv) > 3 else 1400
if len(sys.argv) > 4:
    x0, y0, x1, y1 = [float(v) for v in sys.argv[4].split(',')]
    step = float(sys.argv[5]) if len(sys.argv) > 5 else 0.02
    W, H = im.size
    im = im.crop((int(x0 * W), int(y0 * H), int(x1 * W), int(y1 * H)))
    im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    d = ImageDraw.Draw(im)
    k = int(x0 / step) + 1
    while k * step < x1:
        x = int((k * step - x0) / (x1 - x0) * im.width)
        d.line([(x, 0), (x, im.height)], fill=(255, 0, 255), width=1)
        d.text((x + 2, 2), f'{k * step:.2f}'.lstrip('0'), fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        k += 1
    k = int(y0 / step) + 1
    while k * step < y1:
        y = int((k * step - y0) / (y1 - y0) * im.height)
        d.line([(0, y), (im.width, y)], fill=(255, 0, 255), width=1)
        d.text((2, y + 2), f'{k * step:.2f}'.lstrip('0'), fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        k += 1
else:
    im = im.resize((width, int(im.height * width / im.width)))
    d = ImageDraw.Draw(im)
    for k in range(1, 10):
        x, y = im.width * k // 10, im.height * k // 10
        d.line([(x, 0), (x, im.height)], fill=(255, 0, 255), width=1)
        d.line([(0, y), (im.width, y)], fill=(255, 0, 255), width=1)
        d.text((x + 3, 3), f'.{k}', fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
        d.text((3, y + 3), f'.{k}', fill=(255, 255, 255), stroke_width=2, stroke_fill=(0, 0, 0))
im.save(sys.argv[2]); print(sys.argv[2], im.size)
