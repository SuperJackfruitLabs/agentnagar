"""compare2.py: round 2's comparison sheets.

compare2/<style>.png   the concept sheet, the game today, round 1 and round 2: from the street (top row) and
                       from above (bottom row)
compare2/overview-six-styles.png   every style: concept | today | round 2, from the street
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont
W = os.path.dirname(os.path.abspath(__file__))
OUT = f'{W}/compare2'
os.makedirs(OUT, exist_ok=True)
final = json.load(open(f'{W}/final.json'))
final.setdefault('pixel_art', 'r2-pixel')
NAMES = {'lowpoly_tropical': 'Low-poly tropical', 'voxel': 'Voxel', 'anime_cel': 'Anime cel', 'solarpunk': 'Solarpunk',
         'neon_noir': 'Neon noir', 'pixel_art': 'Pixel art'}
FONT = next(p for p in ('/usr/share/fonts/noto/NotoSans-Regular.ttf', '/usr/share/fonts/TTF/DejaVuSans.ttf',
                        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf') if os.path.exists(p))
BG, INK = (246, 244, 239), (30, 30, 30)


def font(size):
    return ImageFont.truetype(FONT, size)


def street(style, d):
    im = Image.open(f'{W}/captures/{d}/{style}/street.png').convert('RGB'); w, h = im.size
    box = (0.30, 0.0, 0.75, 0.62) if style == 'pixel_art' else (0.30, 0.02, 0.72, 0.72)
    return im.crop((int(w * box[0]), int(h * box[1]), int(w * box[2]), int(h * box[3])))


def above(style, d):
    im = Image.open(f'{W}/captures/{d}/{style}/diagonal.png').convert('RGB'); w, h = im.size
    box = (0.36, 0.30, 0.66, 0.70) if style == 'pixel_art' else (0.40, 0.18, 0.70, 0.52)
    return im.crop((int(w * box[0]), int(h * box[1]), int(w * box[2]), int(h * box[3])))


def fit(im, h):
    return im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)


def row(tiles, labels, h, gap=14, label_h=34):
    tiles = [fit(t, h) for t in tiles]
    width = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    out = Image.new('RGB', (width, h + label_h), BG)
    d = ImageDraw.Draw(out)
    x = 0
    for t, lab in zip(tiles, labels):
        d.text((x + 2, 4), lab, fill=INK, font=font(21))
        out.paste(t, (x, label_h)); x += t.width + gap
    return out


def stack(rows, gap=18, pad=22, title=None):
    width = max(r.width for r in rows) + 2 * pad
    top = pad + (46 if title else 0)
    out = Image.new('RGB', (width, top + sum(r.height for r in rows) + gap * (len(rows) - 1) + pad), BG)
    if title:
        ImageDraw.Draw(out).text((pad, pad - 6), title, fill=INK, font=font(30))
    y = top
    for r in rows:
        out.paste(r, (pad, y)); y += r.height + gap
    return out


for style in NAMES:
    concept = Image.open(f'{W}/inputs/{style}-banyan.png').convert('RGB')
    r1 = row([concept, street(style, 'before'), street(style, 'after'), street(style, final[style])],
             ['Concept sheet', 'Game today', 'Round 1: generated shape', 'Round 2: sheet colours, finer leaf masses'], 560)
    sheet_diag = Image.open(f'{W}/sheets/{style}-diagonal.png').convert('RGB')
    r2 = row([sheet_diag, above(style, 'before'), above(style, 'after'), above(style, final[style])],
             ['Concept sheet, from above', 'Game today', 'Round 1', 'Round 2'], 400)
    stack([r1, r2], title=f'{NAMES[style]}: the great tree').save(f'{OUT}/{style}.png')
    print(f'{OUT}/{style}.png')

cells = []
for style in NAMES:
    concept = Image.open(f'{W}/inputs/{style}-banyan.png').convert('RGB')
    cells.append(row([concept, street(style, 'before'), street(style, final[style])],
                     [f'{NAMES[style]}: concept', 'Game today', 'Round 2'], 330, gap=8))
wide = max(c.width for c in cells)
grid = []
for i in range(0, 6, 2):
    pair = Image.new('RGB', (wide * 2 + 30, cells[i].height), BG)
    pair.paste(cells[i], (0, 0)); pair.paste(cells[i + 1], (wide + 30, 0))
    grid.append(pair)
stack(grid, title='The great tree in six styles: concept sheet, the game today, and round 2').save(f'{OUT}/overview-six-styles.png')
print(f'{OUT}/overview-six-styles.png')
