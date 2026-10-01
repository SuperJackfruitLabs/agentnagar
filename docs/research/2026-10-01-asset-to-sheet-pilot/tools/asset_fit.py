"""asset_fit.py CONFIG STYLE ROUNDS [LABEL]: fits a placed asset's painted colours to its concept sheet.

Each round builds the style's asset (the config's `build` command), puts it into the working copy of the
client, captures the placed pieces close up (asset_try.sh), measures each material's tone bands over every
view against the sheet's (asset_bands.py), and moves that material's gains toward the sheet: an overall gain,
the red and blue channels against green and, unless the config says `"fit": {"stops": false}` (or false
for that kind: `{"stops": {"stone": false}}`), one gain per ramp stop. Damped, so two or three rounds settle. The last round only measures.

Per-stop gains suit foliage, where many small parts at every angle carry the ramp. On a piece of a few large
flat faces (a bench, a wall) the bands are which face the light falls on, not which part is which colour:
fitting stops there flattens the ramp, so such an asset fits its level and hue only. Settings are kept in <asset folder>/params/<style>.json; captures go to
captures/<asset>-<LABEL>-<round>/ (LABEL defaults to `fit`).

The config (see WORKFLOW.md) names, per style: `needle` (part of the placed scene's file name), `asset_file`
(where the asset lives under the pack's folder) and `build` (the command; {asset} is the config's folder,
{out} the built file, {params} the style's settings file). A style whose piece cannot carry material marks
(a kit piece with leaf cards, whose texture uses the UV layer) says `"marked": false`; its kinds are then told
apart by colour (the config's `unmarked` rules). A config's `frame` ("prop" or "auto") says how the
cameras are placed (asset_views.gd).
"""
import json
import math
import os
import shutil
import subprocess
import sys
import time
import numpy as np
import asset_bands as A

W = os.path.dirname(os.path.abspath(__file__))
config_path, style, rounds = sys.argv[1], sys.argv[2], int(sys.argv[3])
label = sys.argv[4] if len(sys.argv) > 4 else 'fit'
config = json.load(open(config_path))
asset_dir = os.path.dirname(os.path.abspath(config_path))
st = config['styles'][style]
name = config['asset']
out = f"{W}/out-{name}/{style}/{os.path.basename(st['asset_file'])}"
params = f"{asset_dir}/params/{style}.json"
os.makedirs(os.path.dirname(params), exist_ok=True)
if not os.path.exists(params):
    json.dump({}, open(params, 'w'))
build = [a.format(asset=asset_dir, out=out, params=params, W=W) for a in st['build']]
D = 0.7                                                    # damping


def lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def geo(v):
    return math.exp(sum(math.log(x) for x in v) / len(v))


times = {'build': [], 'capture': []}
for n in range(rounds):
    t0 = time.time()
    done = subprocess.run(build, capture_output=True, text=True)
    line = [l for l in done.stdout.splitlines() if l.startswith('BUILD')]
    if done.returncode != 0 or not line:
        print(done.stdout[-3000:], done.stderr[-2000:]); sys.exit(1)
    times['build'].append(time.time() - t0)
    shutil.copyfile(out, f"{W}/city/godot/styles/{style}/{st['asset_file']}")
    views = f"{W}/captures/{name}-{label}-{n}"
    t0 = time.time()
    cap = subprocess.run([f'{W}/asset_try.sh', style, st['needle'], views, '3', config.get('frame', 'prop')], capture_output=True, text=True)
    times['capture'].append(time.time() - t0)
    target = A.sheet_bands(config, style)
    got, counts, marked = A.game_bands(config, style, views)
    if not marked and st.get('marked', True):
        print(cap.stdout[-600:]); print('the capture shows no marked faces: is the built asset the one placed?'); sys.exit(1)
    print(f"round {n}: " + ", ".join(f"{k} band error {A.error(target[k], got[k]):.3f} colour distance {A.colour_distance(target[k], got[k]):.1f}"
                                     for k in config['kinds'] if target[k] and got[k]))
    for k in config['kinds']:
        if target[k] and got[k]:
            A.show(f'{k} sheet', target[k]); A.show(f'{k} game', got[k])
    if n == rounds - 1:
        break
    p = json.load(open(params))
    for k in config['kinds']:
        if not (target[k] and got[k]):
            continue
        r = [min(2.5, max(0.4, lin(t[1]) / max(1e-4, lin(g[1])))) for t, g in zip(target[k], got[k])]
        p.setdefault('gain', {})[k] = round(p.get('gain', {}).get(k, 1.0) * geo(r) ** D, 4)
        stops_fit = config.get('fit', {}).get('stops', True)
        if stops_fit.get(k, True) if isinstance(stops_fit, dict) else stops_fit:
            sg = p.setdefault('stop_gain', {}).get(k) or [1.0] * len(r)
            p['stop_gain'][k] = [round(s * (ri / geo(r)) ** (D * 0.7), 4) for s, ri in zip(sg, r)]
        ch = list(p.setdefault('channel', {}).get(k) or [1.0, 1.0, 1.0])
        mid = range(1, len(r) - 1) if len(r) > 3 else range(len(r))
        for c in (0, 2):
            want = geo([max(1e-4, lin(target[k][i][2][c])) / max(1e-4, lin(target[k][i][2][1])) for i in mid])
            have = geo([max(1e-4, lin(got[k][i][2][c])) / max(1e-4, lin(got[k][i][2][1])) for i in mid])
            ch[c] = round(min(3.0, max(0.33, ch[c] * (want / have) ** 0.5)), 4)
        p['channel'][k] = ch
    json.dump(p, open(params, 'w'), indent=1)
print(f"seconds a round: build {np.mean(times['build']):.1f}, import and capture {np.mean(times['capture']):.1f}")
print(json.dumps(json.load(open(params))))
