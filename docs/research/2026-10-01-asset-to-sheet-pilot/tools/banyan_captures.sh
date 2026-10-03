#!/usr/bin/env bash
# banyan_captures.sh [STYLE ...]: takes again the game's frames that the great tree's measures and comparison
# sheets read (metrics.py, compare2.py, look.py, round.sh). They are not kept in the repository. For each
# style, in the working copy of the client: the game today (captures/before), with round 1's tree
# (captures/after) and with round 2's (captures/round2), which it leaves in place. About 15 s a style a set,
# and the copy's first import on top. The frames are taken at the size the recorded ones were (a 1920x1080
# nested desktop), so the measures can be compared. Run from a working folder made by setup.sh without --bare.
set -e
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
export CAP_DESKTOP="${CAP_DESKTOP:-1920x1080}"
STYLES=${*:-lowpoly_tropical voxel anime_cel solarpunk neon_noir pixel_art}
put() {   # put STYLE FROM: the style's tree from FROM (the pack's own assets, out/STYLE or out2/STYLE) into the copy
  local s=$1 from=$2 assets="$W/city/godot/styles/$1/assets"
  case $s in
    voxel) cp "$from/v2/tree_large.glb" "$assets/v2/tree_large.glb" ;;
    pixel_art) python3 - "$from" "$assets" <<'PY' ;;
# The sprite, its night twin, its anchor and its size: from a build's record, or from the pack's own files.
import json, sys
from pathlib import Path
src, copy = Path(sys.argv[1]), Path(sys.argv[2])
key = 'scenery/tree_square.png'
if (src / 'tree_square.meta.json').exists():
    meta = json.loads((src / 'tree_square.meta.json').read_text())
    anchor, size = meta['anchors'][key], meta['info'][key]['size']
else:
    anchor = json.loads((src / 'anchors.json').read_text())[key]
    size = json.loads((src / 'kit.json').read_text())['sprites'][key]['size']
for n in ('tree_square.png', 'tree_square_night.png'):
    (copy / 'scenery' / n).write_bytes((src / 'scenery' / n).read_bytes())
a = json.loads((copy / 'anchors.json').read_text()); a[key] = anchor
(copy / 'anchors.json').write_text(json.dumps(a, indent=2, sort_keys=True) + '\n')
k = json.loads((copy / 'kit.json').read_text()); k['sprites'][key]['size'] = size
(copy / 'kit.json').write_text(json.dumps(k, indent=2, sort_keys=True) + '\n')
PY
    *) cp "$from/tree_banyan.glb" "$assets/tree_banyan.glb" ;;
  esac
}
for s in $STYLES; do
  for set in before after round2; do
    case $set in
      before) put "$s" "$AGENTNAGAR/city/godot/styles/$s/assets" ;;
      after) put "$s" "$W/out/$s" ;;
      round2) put "$s" "$W/out2/$s" ;;
    esac
    "$W/try.sh" "$s" "$W/captures/$set"
    [ -f "$W/captures/$set/$s/street.png" ] || { echo "$s: no street view in captures/$set"; exit 1; }
  done
done
