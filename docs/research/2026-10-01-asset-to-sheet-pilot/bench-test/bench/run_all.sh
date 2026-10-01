#!/usr/bin/env bash
# run_all.sh [OUT.tsv]: every machine step of the bench, for all six styles, from the concept sheets to the
# comparison sheets, with the settings already fitted (bench/params/), each step timed. Nothing here needs a
# person or an agent: it is what a re-run costs. It writes step, style and seconds to OUT.tsv
# (default bench/benchmark.tsv). Run from the working folder (setup.sh), with nothing else using the GPU.
set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; W="$(dirname "$HERE")"; cd "$W"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
OUT=${1:-$HERE/benchmark.tsv}; : > "$OUT"
PY=$W/cvenv/bin/python
STYLES3D="lowpoly_tropical voxel anime_cel solarpunk neon_noir"
t() {   # t STEP STYLE COMMAND...: run it, record its seconds
  local step=$1 style=$2; shift 2
  local t0=$(date +%s.%N)
  "$@" > "$W/run-all-last.log" 2>&1 || { echo "FAILED: $step $style"; tail -5 "$W/run-all-last.log"; exit 1; }
  printf '%s\t%s\t%.1f\n' "$step" "$style" "$(echo "$(date +%s.%N) - $t0" | awk '{print $1 - $3}')" >> "$OUT"
}
needle() { $PY -c "import json,sys; print(json.load(open('$HERE/asset.json'))['styles'][sys.argv[1]]['needle'])" "$1"; }
file() { $PY -c "import json,sys; print(json.load(open('$HERE/asset.json'))['styles'][sys.argv[1]]['asset_file'])" "$1"; }

t "1 cut the sheets' panels" all $PY cut_panels.py
t "2 measure the sheets' ramps" all $PY asset_ramps.py "$HERE/asset.json"
for s in $STYLES3D; do          # the game today: the kit's own asset back in the copy, captured close up
  cp "$AGENTNAGAR/city/godot/styles/$s/$(file $s)" "$W/city/godot/styles/$s/$(file $s)"
  t "3 capture the game today" $s ./asset_try.sh $s "$(needle $s)" "$W/captures/bench-replay-before" 3
done
for s in $STYLES3D; do          # build, put in the copy, capture, measure (one round: the settings are fitted)
  t "4 build, capture and measure" $s $PY asset_fit.py "$HERE/asset.json" $s 1 replay
done
t "5 pixel sprites: render and post-process (16 facings)" pixel_art "$HERE/pixel_bench_run.sh"
t "6 pixel pack: capture the sheet views" pixel_art ./try.sh pixel_art "$W/captures/bench-replay-pixel"
# (a report: a piece off its kit's spec does not stop the run; see the README for the voxel bench's)
t "7 check the kits' specs and the footprint" all bash -c "$PY asset_contracts.py '$HERE/asset.json' '$W/captures/bench-replay-0' > '$HERE/contracts.txt' || true"
$PY - > "$HERE/after-replay.json" <<PY
import json
kit = '$AGENTNAGAR/city/godot/styles/pixel_art/assets/scenery/seats'
new = '$W/out-bench/pixel_art/scenery/seats'
facings = (0, 45, 90, 135, 180, 225, 270, 315)
after = {s: '$W/captures/bench-replay-0' for s in '$STYLES3D'.split()}
after['pixel_art'] = {'before': [f'{kit}/bench_{f}.png' for f in facings], 'after': [f'{new}/bench_{f}.png' for f in facings], 'overview': [2, 4]}
print(json.dumps(after, indent=1))
PY
t "8 compose the comparison sheets" all $PY asset_compare.py "$HERE/asset.json" "$W/captures/bench-replay-before" "$HERE/after-replay.json" "$W/compare-bench"
awk -F'\t' '{a[$1] += $3; n[$1]++; total += $3} END {for (k in a) printf "%-58s %6.1f s over %d\n", k, a[k], n[k]; printf "%-58s %6.1f s\n", "total", total}' "$OUT" | sort
