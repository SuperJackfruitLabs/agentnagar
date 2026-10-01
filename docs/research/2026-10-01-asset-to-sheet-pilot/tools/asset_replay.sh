#!/usr/bin/env bash
# asset_replay.sh CONFIG [OUT.tsv]: every machine step for one asset in every style its config names, from the
# concept sheets to the comparison sheets, with the settings already fitted (<asset folder>/params/), each step
# timed. Nothing here needs a person or an agent: it is what a re-run costs, and running it from a fresh
# working folder (setup.sh --bare WORK ASSET_DIR) proves the asset's record is complete.
#
# It reads from the config: `asset`; each style's `needle`, `asset_file` and `build` (a 3D piece); for a style
# drawn as sprites, `run` (a script in the asset's folder that renders them into out-<asset>/<style>/ and puts
# them in the client copy) and `sprites` ({"files": [paths under the pack's assets/], "overview": [which two
# the overview shows]}); `frame`. Writes step, style and seconds to OUT.tsv (default <asset folder>/benchmark.tsv),
# the contract report to <asset folder>/contracts.txt and the sheets to compare-<asset>/.
# Run from the working folder with nothing else using the GPU.
set -e
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$W"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
CONFIG="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; HERE="$(dirname "$CONFIG")"
OUT=${2:-$HERE/benchmark.tsv}; : > "$OUT"
PY=$W/cvenv/bin/python
q() { $PY -c "
import json, sys
c = json.load(open('$CONFIG')); expr = sys.argv[1]
print(eval(expr, {'c': c, 's': c['styles']}))" "$1"; }
ASSET=$(q "c['asset']"); FRAME=$(q "c.get('frame', 'prop')")
STYLES3D=$(q "' '.join(k for k, v in s.items() if 'build' in v)")
SPRITES=$(q "' '.join(k for k, v in s.items() if 'run' in v)")
t() {   # t STEP STYLE COMMAND...: run it, record its seconds
  local step=$1 style=$2; shift 2
  local t0=$(date +%s.%N)
  "$@" > "$W/replay-last.log" 2>&1 || { echo "FAILED: $step $style"; tail -5 "$W/replay-last.log"; exit 1; }
  printf '%s\t%s\t%.1f\n' "$step" "$style" "$(echo "$(date +%s.%N) - $t0" | awk '{print $1 - $3}')" >> "$OUT"
}
t "1 cut the sheets' panels" all $PY cut_panels.py
t "2 measure the sheets' ramps" all $PY asset_ramps.py "$CONFIG"
for s in $STYLES3D; do          # the game today: the kit's own asset back in the copy, captured close up
  f=$(q "s['$s']['asset_file']")
  cp "$AGENTNAGAR/city/godot/styles/$s/$f" "$W/city/godot/styles/$s/$f"
  t "3 capture the game today" $s ./asset_try.sh $s "$(q "s['$s']['needle']")" "$W/captures/$ASSET-replay-before" 3 "$FRAME"
done
for s in $STYLES3D; do          # build, put in the copy, capture, measure (one round: the settings are fitted)
  t "4 build, capture and measure" $s $PY asset_fit.py "$CONFIG" $s 1 replay
done
for s in $SPRITES; do
  t "5 sprites: render and post-process" $s "$HERE/$(q "s['$s']['run']")"
  t "6 sprite pack: capture the sheet views" $s ./try.sh $s "$W/captures/$ASSET-replay-sprites"
done
# (a report: a piece off its kit's spec does not stop the run)
t "7 check the kits' specs and the footprint" all bash -c "$PY asset_contracts.py '$CONFIG' '$W/captures/$ASSET-replay-0' > '$HERE/contracts.txt' || true"
$PY - > "$HERE/after-replay.json" <<PY
import json
c = json.load(open('$CONFIG'))
after = {k: '$W/captures/$ASSET-replay-0' for k, v in c['styles'].items() if 'build' in v}
for k, v in c['styles'].items():
    if 'run' in v:
        files = v['sprites']['files']
        after[k] = {'before': ['$AGENTNAGAR/city/godot/styles/' + k + '/assets/' + f for f in files],
                    'after': ['$W/out-$ASSET/' + k + '/' + f for f in files], 'overview': v['sprites'].get('overview', [0])}
print(json.dumps(after, indent=1))
PY
t "8 compose the comparison sheets" all $PY asset_compare.py "$CONFIG" "$W/captures/$ASSET-replay-before" "$HERE/after-replay.json" "$W/compare-$ASSET"
awk -F'\t' '{a[$1] += $3; n[$1]++; total += $3} END {for (k in a) printf "%-48s %6.1f s over %d\n", k, a[k], n[k]; printf "%-48s %6.1f s\n", "total", total}' "$OUT" | sort
