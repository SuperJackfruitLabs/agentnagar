#!/usr/bin/env bash
# pixel_planter_run.sh: render the planter's sprite from the swapped model, post-process it with the kit, report
# its palette shares beside the kit's own sprite's, and put it into the working copy.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; W="$(dirname "$HERE")"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
KIT=$AGENTNAGAR/city/tools/styles/pixel
RAW=$W/pixraw-planter; OUT=$W/out-planter/pixel_art; rm -rf "$RAW"; mkdir -p "$RAW" "$OUT"
blender --background --factory-startup --python-exit-code 1 \
  --python "$HERE/pixel_planter_pre.py" --python "$KIT/render.py" -- "$RAW" planter 2>&1 | grep -E 'PIXEL|Error|Traceback' | head -5
"$AGENTNAGAR/.local/venv/bin/python" - <<PY
import json, sys
from pathlib import Path
sys.path.insert(0, '$KIT')
import models, post, palette
import numpy as np
from PIL import Image
spec = [s for s in models.KIT if s['name'] == 'planter']
anchors, info = {}, {}
written = post.process('$RAW', '$OUT', spec, anchors, info)
Path('$OUT/planter.meta.json').write_text(json.dumps({'anchors': anchors, 'info': info}, indent=1))
names = {tuple(v): k for k, v in palette.C.items()}
def shares(p):
    im = np.asarray(Image.open(p).convert('RGBA')); px = im[im[:, :, 3] > 0][:, :3]
    counts = {}
    for c in map(tuple, px):
        counts[names.get(c, str(c))] = counts.get(names.get(c, str(c)), 0) + 1
    total = sum(counts.values())
    return f'{im.shape[1]}x{im.shape[0]}: ' + ', '.join(f'{k} {v * 100 / total:.0f}%' for k, v in sorted(counts.items(), key=lambda kv: -kv[1])[:8])
kit_dir = Path('$AGENTNAGAR/city/godot/styles/pixel_art/assets')
for p in written:
    print('  the kit today:', shares(kit_dir / p)); print('  this build:   ', shares(Path('$OUT') / p))
copy = Path('$W/city/godot/styles/pixel_art/assets')
a = json.loads((copy / 'anchors.json').read_text()); k = json.loads((copy / 'kit.json').read_text())
for p in written:
    for n in (p, p.replace('.png', '_night.png')):
        (copy / n).write_bytes((Path('$OUT') / n).read_bytes())
    a[p] = anchors[p]; k['sprites'][p]['size'] = info[p]['size']
(copy / 'anchors.json').write_text(json.dumps(a, indent=2, sort_keys=True) + '\n')
(copy / 'kit.json').write_text(json.dumps(k, indent=2, sort_keys=True) + '\n')
PY
