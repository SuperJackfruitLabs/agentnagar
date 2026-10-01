#!/usr/bin/env bash
# pixel_bench_run.sh [PARAMS.json]: render the bench's sixteen sprites from the swapped model, post-process them
# with the kit, report their palette shares beside the kit's own sprites', and put them into the working copy.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; W="$(dirname "$HERE")"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
KIT=$AGENTNAGAR/city/tools/styles/pixel
RAW=$W/pixraw-bench; OUT=$W/out-bench/pixel_art; rm -rf "$RAW"; mkdir -p "$RAW" "$OUT"
PARAMS=${1:-} blender --background --factory-startup --python-exit-code 1 \
  --python "$HERE/pixel_bench_pre.py" --python "$KIT/render.py" -- "$RAW" seat_bench 2>&1 | grep -E 'PIXEL|Error|Traceback' | head -5
"$AGENTNAGAR/.local/venv/bin/python" - <<PY
import json, sys
from pathlib import Path
sys.path.insert(0, '$KIT')
import models, post, palette
import numpy as np
from PIL import Image
spec = [s for s in models.KIT if s['name'].startswith('seat_bench_')]
anchors, info = {}, {}
written = post.process('$RAW', '$OUT', spec, anchors, info)
Path('$OUT/bench.meta.json').write_text(json.dumps({'anchors': anchors, 'info': info}, indent=1))
names = {tuple(v): k for k, v in palette.C.items()}
def shares(paths):
    counts = {}
    for p in paths:
        im = np.asarray(Image.open(p).convert('RGBA')); px = im[im[:, :, 3] > 0][:, :3]
        for c in map(tuple, px):
            counts[names.get(c, str(c))] = counts.get(names.get(c, str(c)), 0) + 1
    total = sum(counts.values())
    return ', '.join(f'{k} {v * 100 / total:.0f}%' for k, v in sorted(counts.items(), key=lambda kv: -kv[1])[:6])
kit_dir = Path('$AGENTNAGAR/city/godot/styles/pixel_art/assets')
print(len(written), 'sprites')
print('  the kit today:', shares([kit_dir / p for p in written]))
print('  this build:   ', shares([Path('$OUT') / p for p in written]))
copy = Path('$W/city/godot/styles/pixel_art/assets')
a = json.loads((copy / 'anchors.json').read_text()); k = json.loads((copy / 'kit.json').read_text())
for p in written:
    for n in (p, p.replace('.png', '_night.png')):
        (copy / n).write_bytes((Path('$OUT') / n).read_bytes())
    a[p] = anchors[p]; k['sprites'][p]['size'] = info[p]['size']
(copy / 'anchors.json').write_text(json.dumps(a, indent=2, sort_keys=True) + '\n')
(copy / 'kit.json').write_text(json.dumps(k, indent=2, sort_keys=True) + '\n')
PY
