#!/usr/bin/env bash
# pixel_run.sh [PARAMS.json]: render the round-two pixel sprite, post-process it with the kit, report the
# crown's palette shares, and put it into the working copy of the client.
set -e
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
KIT=$AGENTNAGAR/city/tools/styles/pixel
RAW=$W/pixraw2; OUT=$W/out2/pixel_art; rm -rf "$RAW"; mkdir -p "$RAW" "$OUT"
PARTS=$W/parts NAME=lowpoly_tropical PARAMS=${1:-} blender --background --factory-startup --python-exit-code 1 \
  --python "$W/pixel_pre2.py" --python "$KIT/render.py" -- "$RAW" tree_square 2>&1 | grep -E 'PIXEL|pixel render|Error|Traceback' | head -5
# The kit's post-processing needs the project's Python (Pillow as CI pins it).
"$AGENTNAGAR/.local/venv/bin/python" - <<PY
import json, sys
from pathlib import Path
sys.path.insert(0, '$KIT')
import models, post, palette
import numpy as np
from PIL import Image
spec = [s for s in models.KIT if s['name'] == 'tree_square']
anchors, info = {}, {}
written = post.process('$RAW', '$OUT', spec, anchors, info)
Path('$OUT/tree_square.meta.json').write_text(json.dumps({'anchors': anchors, 'info': info}, indent=1))
im = np.asarray(Image.open('$OUT/scenery/tree_square.png').convert('RGBA'))
h = im.shape[0]
crown = im[: int(h * 0.62)]                      # the crown: the sprite's upper part
px = crown[crown[:, :, 3] > 0][:, :3]
names = {tuple(v): k for k, v in palette.C.items()}
counts = {}
for c in map(tuple, px):
    counts[names.get(c, str(c))] = counts.get(names.get(c, str(c)), 0) + 1
total = sum(counts.values())
print('sprite', im.shape[1], 'x', im.shape[0], 'anchor', anchors, '| crown shares:',
      ', '.join(f'{k} {v * 100 // total}%' for k, v in sorted(counts.items(), key=lambda kv: -kv[1])[:7]))
# into the working copy: the sprite, its night twin, its anchor and its size
copy = Path('$W/city/godot/styles/pixel_art/assets')
for n in ('tree_square.png', 'tree_square_night.png'):
    (copy / 'scenery' / n).write_bytes(Path('$OUT/scenery/' + n).read_bytes())
a = json.loads((copy / 'anchors.json').read_text()); a['scenery/tree_square.png'] = anchors['scenery/tree_square.png']
(copy / 'anchors.json').write_text(json.dumps(a, indent=2, sort_keys=True) + '\n')
k = json.loads((copy / 'kit.json').read_text()); k['sprites']['scenery/tree_square.png']['size'] = info['scenery/tree_square.png']['size']
(copy / 'kit.json').write_text(json.dumps(k, indent=2, sort_keys=True) + '\n')
PY
