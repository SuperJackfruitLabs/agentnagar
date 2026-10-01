"""asset_look.py CONFIG STYLE VIEWS_DIR OUT.png [BEFORE_DIR]: one style's asset as its sheet draws it (the
config's `look` box, or the whole panel), beside the game's close views: from eye height and from above, the
game today on the top row (BEFORE_DIR) and the new build below."""
import json
import os
import sys
from PIL import Image

W = os.path.dirname(os.path.abspath(__file__))
config = json.load(open(sys.argv[1])); style, views, out = sys.argv[2], sys.argv[3], sys.argv[4]
before = sys.argv[5] if len(sys.argv) > 5 else None
st = config['styles'][style]
H = 420


def fit(im, h=H):
    return im.resize((max(1, int(im.width * h / im.height)), h), Image.LANCZOS)


def view(d, name):
    im = Image.open(f'{d}/{style}/{name}.png').convert('RGB'); w, h = im.size
    return im.crop((int(w * 0.2), int(h * 0.12), int(w * 0.8), int(h * 0.88)))


panel = Image.open(st.get('panel_file') or f"{W}/panels/{style}-{st.get('panel', config['panel'])}.png").convert('RGB')
if st.get('look'):
    x0, y0, x1, y1 = st['look']; w, h = panel.size
    panel = panel.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
rows = []
for d in ([before] if before else []) + [views]:
    tiles = [fit(view(d, n)) for n in ('asset-eye-0', 'asset-above-0', 'asset-eye-1')]
    row = Image.new('RGB', (sum(t.width for t in tiles) + 8 * (len(tiles) - 1), H), 'white'); x = 0
    for t in tiles:
        row.paste(t, (x, 0)); x += t.width + 8
    rows.append(row)
side = fit(panel, H * len(rows) + 8 * (len(rows) - 1))
if side.width > 900:
    side = side.resize((900, int(side.height * 900 / side.width)), Image.LANCZOS)
sheet = Image.new('RGB', (side.width + 8 + max(r.width for r in rows), H * len(rows) + 8 * (len(rows) - 1)), 'white')
sheet.paste(side, (0, 0))
for i, r in enumerate(rows):
    sheet.paste(r, (side.width + 8, i * (H + 8)))
sheet.save(out); print(out, sheet.size)
