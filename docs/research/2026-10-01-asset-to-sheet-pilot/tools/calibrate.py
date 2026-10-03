"""calibrate.py STYLE ROUNDS [--from LABEL]: fits a style's painted colours to its concept sheet.

Each round builds the style's round-two tree, captures it in the scratch copy of the game, measures the crown's
five tone bands from the street and from above (and the trunk's three) against the sheet's, and moves the
painting's gains toward the sheet: the two classes of face (seen from above, seen from the street), the ramp's
stops, the three colour channels, and the bark. Damped, so a few rounds settle.
"""
import json
import math
import os
import subprocess
import sys
import numpy as np
import bands as B
W = os.path.dirname(os.path.abspath(__file__))
style, rounds = sys.argv[1], int(sys.argv[2])
P = f'{W}/params/{style}.json'
BUILD = {
    'lowpoly_tropical': ['blender', '--background', '--factory-startup', '--python-exit-code', '1', '--python', f'{W}/build_lowpoly2.py', '--',
                         f'{W}/parts', 'lowpoly_tropical', f'{W}/out2/lowpoly_tropical/tree_banyan.glb', P],
    'anime_cel': ['blender', '--background', '--factory-startup', '--python-exit-code', '1', '--python', f'{W}/build_cards2.py', '--',
                  'anime', f'{W}/parts', 'lowpoly_tropical', f'{W}/out2/anime_cel/tree_banyan.glb', P],
    'solarpunk': ['blender', '--background', '--factory-startup', '--python-exit-code', '1', '--python', f'{W}/build_cards2.py', '--',
                  'solarpunk', f'{W}/parts', 'lowpoly_tropical', f'{W}/out2/solarpunk/tree_banyan.glb', P],
    'neon_noir': ['blender', '--background', '--factory-startup', '--python-exit-code', '1', '--python', f'{W}/build_cards2.py', '--',
                  'neon', f'{W}/parts', 'lowpoly_tropical', f'{W}/out2/neon_noir/tree_banyan.glb', P],
    'voxel': ['blender', '--background', '--factory-startup', '--python-exit-code', '1', '--python', f'{W}/build_voxel2.py', '--',
              f'{W}/parts', 'voxel', f'{W}/out2/voxel/v2/tree_large.glb', P],
}


def lin(v):
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def ratio(target, got, lo=0.4, hi=2.5):
    """Per band, how much more light the sheet shows than the capture (linear)."""
    return [min(hi, max(lo, lin(t[1]) / max(1e-4, lin(g[1])))) for t, g in zip(target, got)]


def geo(v):
    return math.exp(sum(math.log(x) for x in v) / len(v))


def error(target, got):
    return float(np.mean([abs(t[1] - g[1]) for t, g in zip(target, got)]))


for n in range(rounds):
    label = f'cal-{style}-{n}'
    out = subprocess.run(BUILD[style], capture_output=True, text=True)
    line = [l for l in out.stdout.splitlines() if l.startswith('BUILD')]
    if out.returncode != 0 or not line:
        print(out.stdout[-3000:], out.stderr[-2000:]); sys.exit(1)
    print(line[-1][:400])
    subprocess.run([f'{W}/round.sh', style, label], capture_output=True, text=True)
    target, got = B.measure(style, f'{W}/captures/{label}')
    p = json.load(open(P))
    errs = {v: error(target[v], got[v]) for v in got}
    print(f"round {n}: mean band error " + ", ".join(f"{v} {e:.3f}" for v, e in errs.items()))
    for v in ('street', 'above', 'trunk'):
        if v in got:
            B.show(f'{v} sheet', target[v]); B.show(f'{v} game', got[v])
    if n == rounds - 1:
        break
    d = 0.7                                             # damping
    rs, ra = ratio(target['street'], got['street']), ratio(target['above'], got['above'])
    cg = p.setdefault('class_gain', {}).setdefault('leaf', {}); cg.setdefault('up', 1.0); cg.setdefault('rest', 1.0)
    cg['rest'] = round(cg['rest'] * geo(rs) ** d, 4)
    cg['up'] = round(cg['up'] * geo(ra) ** d, 4)
    sg = p.setdefault('stop_gain', {}).setdefault('leaf', [1.0] * 5)
    p['stop_gain']['leaf'] = [round(s * ((rs[i] / geo(rs)) * (ra[i] / geo(ra))) ** (d / 2), 4) for i, s in enumerate(sg)]
    # Hue: per channel, against green, over the three middle bands of both views.
    ch = p.setdefault('channel', {}).setdefault('leaf', [1.0, 1.0, 1.0])
    for c in (0, 2):
        want = geo([lin(target[v][i][2][c]) / max(1e-4, lin(target[v][i][2][1])) for v in ('street', 'above') for i in (1, 2, 3)])
        have = geo([max(1e-4, lin(got[v][i][2][c])) / max(1e-4, lin(got[v][i][2][1])) for v in ('street', 'above') for i in (1, 2, 3)])
        ch[c] = round(min(3.0, max(0.33, ch[c] * (want / have) ** 0.5)), 4)
    # Bark.
    rw = ratio(target['trunk'], got['trunk'])
    p['gain_wood'] = round(p.get('gain_wood', 1.0) * geo(rw[1:]) ** d, 4)
    json.dump(p, open(P, 'w'), indent=1)
print(json.dumps(json.load(open(P))))
