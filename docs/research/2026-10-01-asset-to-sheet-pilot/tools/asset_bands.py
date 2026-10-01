"""asset_bands.py CONFIG STYLE VIEWS_DIR [VIEWS_DIR ...]: a placed asset's tone bands, by material, beside its
concept sheet's.

CONFIG is the asset's config (see WORKFLOW.md): its kinds of face, and for each style the boxes in the sheet's
panel that lie on each kind. VIEWS_DIR/STYLE/ holds asset_views.gd's captures (asset_try.sh). The game's
pixels are found exactly: the mask pass says which pixels are the piece; which material each is comes from the
build's marks (the kind pass) or, for a piece no build marked (the kit's own), from its unlit colours by the
config's `unmarked` rule. Pixels are pooled over every view (three pieces at different facings, from eye
height and from above), so the bands hold what the sun does to the piece all the way round.

Importable: sheet_bands(), game_bands(), measure().
"""
import glob
import json
import os
import sys
import numpy as np
from PIL import Image
import kinds as K

W = os.path.dirname(os.path.abspath(__file__))
LUM = np.array([0.2126, 0.7152, 0.0722])
BANDS5 = ((0.0, 0.10), (0.10, 0.35), (0.35, 0.65), (0.65, 0.90), (0.90, 1.0))
BANDS3 = ((0.0, 0.25), (0.35, 0.65), (0.80, 1.0))


def _split(a, cuts):
    lum = a @ LUM; order = np.argsort(lum); n = len(order)
    out = []
    for lo, hi in cuts:
        c = a[order[int(lo * n): max(int(lo * n) + 1, int(hi * n))]].mean(axis=0)
        out.append(('#%02X%02X%02X' % tuple(int(v) for v in c), float(c @ LUM) / 255, [float(v) / 255 for v in c]))
    return out


def panel_path(config, style):
    """The sheet panel a style's boxes refer to: the config's `panel`, or the style's own (`panel`, or a
    file as `panel_file`)."""
    st = config['styles'][style]
    return st.get('panel_file') or f"{W}/panels/{style}-{st.get('panel', config['panel'])}.png"


def _rule(a, rule):
    """Which pixels a colour rule keeps: 'warm' (wood: red over green over blue, with some colour), 'grey'
    (little colour), 'green' (leaves: green over red and blue; flowers fall out), 'pale' (stone, plaster:
    low saturation), 'any'."""
    r, g, b = a[:, 0], a[:, 1], a[:, 2]
    if rule == 'green':
        return (g >= r * 0.95) & (g > b * 1.05) & ((g - b) > 0.2 * g)      # green, and not a pale petal
    if rule == 'pale':
        return (np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)) <= 0.3 * np.maximum(np.maximum(np.maximum(r, g), b), 1.0)
    if rule == 'warm':
        return (r >= g) & (g >= b * 0.95) & ((r - b) > 0.2 * np.maximum(r, 1.0))
    if rule == 'grey':
        return (np.abs(r - b) <= 0.2 * np.maximum(np.maximum(r, b), 1.0))
    return np.ones(len(a), dtype=bool)


def sheet_pixels(config, style, kind):
    st = config['styles'][style]
    im = Image.open(panel_path(config, style)).convert('RGB'); w, h = im.size
    parts = []
    for x0, y0, x1, y1 in st['sheet'].get(kind, []):
        parts.append(np.asarray(im.crop((int(x0 * w), int(y0 * h), max(int(x0 * w) + 1, int(x1 * w)), max(int(y0 * h) + 1, int(y1 * h))))).reshape(-1, 3))
    if not parts:
        return np.zeros((0, 3))
    a = np.concatenate(parts).astype(np.float64)
    keep = _rule(a, {**config.get('sheet_rule', {}), **st.get('sheet_rule', {})}.get(kind, 'any'))
    return a[keep] if keep.sum() > 20 else a


def game_pixels(config, style, views_dir, which='asset-*'):
    """{kind: pixels} of the piece in every view under views_dir/style matching `which`."""
    levels = K.level_of(config['kinds'])
    out = {k: [] for k in config['kinds']}
    marked = False
    for path in sorted(glob.glob(f'{views_dir}/{style}/{which}-mask.png')):
        base = path[:-len('-mask.png')]
        mask = np.asarray(Image.open(path).convert('RGB')).astype(np.int32)
        m = (mask[:, :, 0] > 200) & (mask[:, :, 2] > 200) & (mask[:, :, 1] < 70)
        if not m.any():
            continue
        normal = np.asarray(Image.open(base + '.png').convert('RGB')).astype(np.float64)[m]
        grey = np.asarray(Image.open(base + '-kind.png').convert('RGB')).astype(np.int32)[:, :, 0][m]
        albedo = np.asarray(Image.open(base + '-albedo.png').convert('RGB')).astype(np.float64)[m]
        coded = np.zeros(len(grey), dtype=bool)
        for k in config['kinds']:
            coded |= np.abs(grey - levels[k]) <= 9
        if coded.mean() > 0.2:                             # the build marked its kinds
            marked = True
            for k in config['kinds']:
                out[k].append(normal[np.abs(grey - levels[k]) <= 9])
        else:                                              # the kit's own piece: by its unlit colours
            rules = config.get('unmarked', {})
            taken = np.zeros(len(normal), dtype=bool)
            for k in config['kinds']:
                if k in rules:
                    keep = _rule(albedo, rules[k]) & ~taken
                else:
                    keep = ~taken
                out[k].append(normal[keep]); taken |= keep
    return {k: (np.concatenate(v) if v else np.zeros((0, 3))) for k, v in out.items()}, marked


def bands_of(a, n=5):
    return _split(a, BANDS5 if n == 5 else BANDS3) if len(a) else []


def sheet_bands(config, style):
    out = {k: bands_of(sheet_pixels(config, style, k), config.get('stops', {}).get(k, 5)) for k in config['kinds']}
    # A stop the config sets by hand (where a box could not help taking in something else).
    for kind, stops in config.get('ramp_override', {}).get(style, {}).items():
        for i, h in enumerate(stops):
            if h and out.get(kind):
                rgb = [int(h[j:j + 2], 16) / 255 for j in (1, 3, 5)]
                out[kind][i] = (h, float(np.array(rgb) @ LUM), rgb)
    return out


def game_bands(config, style, views_dir, which='asset-*'):
    px, marked = game_pixels(config, style, views_dir, which)
    return {k: bands_of(px[k], config.get('stops', {}).get(k, 5)) for k in config['kinds']}, {k: len(px[k]) for k in px}, marked


def error(target, got):
    return float(np.mean([abs(t[1] - g[1]) for t, g in zip(target, got)])) if target and got else float('nan')


def lab(rgb):
    c = np.array(rgb, dtype=np.float64)
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    M = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750], [0.0193339, 0.1191920, 0.9503041]])
    xyz = M @ c / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > 0.008856, np.cbrt(xyz), 7.787 * xyz + 16 / 116)
    return np.array([116 * f[1] - 16, 500 * (f[0] - f[1]), 200 * (f[1] - f[2])])


def colour_distance(target, got):
    """Mean colour difference (CIE76) over the bands."""
    return float(np.mean([np.linalg.norm(lab(t[2]) - lab(g[2])) for t, g in zip(target, got)])) if target and got else float('nan')


def show(label, b):
    print(f"  {label:26s} " + "  ".join(f"{c} {l:.2f}" for c, l, _rgb in b))


if __name__ == '__main__':
    config = json.load(open(sys.argv[1])); style = sys.argv[2]
    target = sheet_bands(config, style)
    for kind in config['kinds']:
        if not target[kind]:
            continue
        print(f"{style}: {kind}")
        show('sheet', target[kind])
        for d in sys.argv[3:]:
            got, counts, marked = game_bands(config, style, d)
            if got[kind]:
                show(os.path.basename(d.rstrip('/')) + ('' if marked else ' (by colour)'), got[kind])
                print(f"  {'':26s} {counts[kind]} pixels, band error {error(target[kind], got[kind]):.3f}, colour distance {colour_distance(target[kind], got[kind]):.1f}")
