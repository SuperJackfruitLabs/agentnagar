"""asset_compare.py CONFIG BEFORE_DIR AFTER_JSON OUT_DIR: comparison sheets for a placed asset.

AFTER_JSON maps each style to the folder its final captures are in ({"lowpoly_tropical": "captures/bench-fit-2", ...}).
Writes OUT_DIR/<style>.png (the sheet's drawing; the game today and the new build, from eye height at two
facings and from above) and OUT_DIR/overview.png (every style: sheet | today | new). A 2D style's entry is
{"before": [sprite files], "after": [sprite files], "overview": [which of them the overview shows]} instead.
"""
import json
import os
import sys
from PIL import Image, ImageDraw, ImageFont

W = os.path.dirname(os.path.abspath(__file__))
config = json.load(open(sys.argv[1])); before = sys.argv[2]; after = json.load(open(sys.argv[3])); out = sys.argv[4]
os.makedirs(out, exist_ok=True)
NAMES = {'lowpoly_tropical': 'Low-poly tropical', 'voxel': 'Voxel', 'anime_cel': 'Anime cel', 'solarpunk': 'Solarpunk',
         'neon_noir': 'Neon noir', 'pixel_art': 'Pixel art'}
FONT = next(p for p in ('/usr/share/fonts/noto/NotoSans-Regular.ttf', '/usr/share/fonts/TTF/DejaVuSans.ttf',
                        '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf') if os.path.exists(p))
BG, INK = (246, 244, 239), (30, 30, 30)
font = lambda size: ImageFont.truetype(FONT, size)  # noqa: E731


def fit(im, h):
    return im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)


def view(d, style, name):
    im = Image.open(f'{d}/{style}/{name}.png').convert('RGB'); w, h = im.size
    return im.crop((int(w * 0.2), int(h * 0.12), int(w * 0.8), int(h * 0.88)))


def panel(style, widest=None):
    """The sheet's drawing of the asset; with `widest`, cut at its middle to that many times its height."""
    st = config['styles'][style]
    im = Image.open(st.get('panel_file') or f"{W}/panels/{style}-{st.get('panel', config['panel'])}.png").convert('RGB')
    if st.get('look'):
        x0, y0, x1, y1 = st['look']; w, h = im.size
        im = im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    if widest and im.width > widest * im.height:
        keep = int(widest * im.height); left = (im.width - keep) // 2
        im = im.crop((left, 0, left + keep, im.height))
    return im


def sprites(files, scale=6, cols=4):
    ims = []
    for f in files:
        im = Image.open(f).convert('RGBA')
        bg = Image.new('RGBA', (44, 40), (222, 196, 150, 255)); bg.alpha_composite(im, ((44 - im.width) // 2, (40 - im.height) // 2))
        ims.append(bg.convert('RGB').resize((44 * scale, 40 * scale), Image.NEAREST))
    rows = (len(ims) + cols - 1) // cols
    s = Image.new('RGB', (cols * (44 * scale + 6) - 6, rows * (40 * scale + 6) - 6), BG)
    for i, t in enumerate(ims):
        s.paste(t, ((i % cols) * (44 * scale + 6), (i // cols) * (40 * scale + 6)))
    return s


def row(tiles, labels, h, gap=12, label_h=32):
    tiles = [fit(t, h) for t in tiles]
    o = Image.new('RGB', (sum(t.width for t in tiles) + gap * (len(tiles) - 1), h + label_h), BG)
    d = ImageDraw.Draw(o); x = 0
    for t, lab in zip(tiles, labels):
        d.text((x + 2, 4), lab, fill=INK, font=font(20))
        o.paste(t, (x, label_h)); x += t.width + gap
    return o


def stack(rows, title, gap=16, pad=20):
    o = Image.new('RGB', (max(r.width for r in rows) + 2 * pad, pad + 44 + sum(r.height for r in rows) + gap * (len(rows) - 1) + pad), BG)
    ImageDraw.Draw(o).text((pad, pad - 6), title, fill=INK, font=font(28))
    y = pad + 44
    for r in rows:
        o.paste(r, (pad, y)); y += r.height + gap
    return o


cells = []
for style in config['styles']:
    if style not in after:
        continue
    a = after[style]
    if isinstance(a, dict):                                   # a 2D style: its sprites
        r1 = row([panel(style, 1.5), sprites(a['before']), sprites(a['after'])], ['Concept sheet', 'Game today (sprites, six times size)', 'New'], 380)
        stack([r1], f"{NAMES.get(style, style)}: the {config['asset']}").save(f'{out}/{style}.png')
        pick = a.get('overview', [0, 1])
        cells.append(row([panel(style, 1.5), sprites([a['before'][i] for i in pick], cols=len(pick)), sprites([a['after'][i] for i in pick], cols=len(pick))],
                         [f'{NAMES.get(style, style)}: concept', 'Game today', 'New'], 250, gap=8))
        continue
    r1 = row([panel(style, 2.2), view(before, style, 'asset-eye-0'), view(a, style, 'asset-eye-0')], ['Concept sheet', 'Game today', 'New'], 420)
    r2 = row([view(before, style, 'asset-above-0'), view(a, style, 'asset-above-0'), view(before, style, 'asset-eye-1'), view(a, style, 'asset-eye-1')],
             ['Game today, from above', 'New', 'Game today, another facing', 'New'], 330)
    stack([r1, r2], f"{NAMES.get(style, style)}: the {config['asset']}").save(f'{out}/{style}.png')
    cells.append(row([panel(style, 1.5), view(before, style, 'asset-eye-0'), view(a, style, 'asset-eye-0')], [f'{NAMES.get(style, style)}: concept', 'Game today', 'New'], 250, gap=8))
wide = max(c.width for c in cells)
grid = []
for i in range(0, len(cells), 2):
    pair = Image.new('RGB', (wide * 2 + 30, cells[i].height), BG)
    pair.paste(cells[i], (0, 0))
    if i + 1 < len(cells):
        pair.paste(cells[i + 1], (wide + 30, 0))
    grid.append(pair)
stack(grid, f"The {config['asset']} in {len(cells)} styles: concept sheet, the game today, and the new build").save(f'{out}/overview.png')
print(f'{out}/overview.png and {len(cells)} style sheets')
