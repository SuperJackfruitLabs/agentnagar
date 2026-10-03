#!/usr/bin/env bash
# bench_far_as_near.sh [STYLE]: a style's street trees and palms (default: low-poly's) drawn as their far twins
# at every distance, against the kit's: what the planted trees would cost a frame at about 775 triangles each.
# The order and the warming are bench_pairs.sh's; results go to bench/trees-as-far-twins/. It leaves the kit's
# pieces in the working copy for that style: place the built ones again afterwards.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh" > /dev/null 2>&1
cd "$W"; s=${1:-lowpoly_tropical}; out=$W/bench/trees-as-far-twins
mkdir -p "$out"; : > "$out/pairs.txt"
temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1; }
run() { "$W/work/bench.sh" "$1" "$2" > /dev/null; for f in "$W/bench/$1".*; do [ -e "$f" ] && mv "$f" "$out/"; done; }
date '+%H:%M:%S the trees as their far twins'; uptime | sed 's/.*load/load/'
python3 work/build.py restore $s > /dev/null
last=0; n=0
while [ "$n" -lt 5 ]; do
  n=$((n + 1)); before=$(temp); run "warm-$s-$n" "$s"; now=$(temp)
  echo "  warm-$s-$n: card $before C before, $now C after (thrown away)" | tee -a "$out/pairs.txt"
  if [ "$n" -gt 1 ] && [ $((now - last)) -le 1 ] && [ $((last - now)) -le 1 ]; then break; fi
  last=$now
done
echo "$s: card steady at $(temp) C after $n warming runs" | tee -a "$out/pairs.txt"
for r in kit-1 new-1 new-2 kit-2; do
  if [ "${r%-*}" = kit ]; then python3 work/build.py restore $s > /dev/null
  else python3 work/build.py place $s @trees > /dev/null; python3 work/far_as_near.py $s > "$out/placed.txt"; fi
  before=$(temp); run "${r%-*}-$s-${r#*-}" "$s"
  echo "  ${r%-*}-$s-${r#*-}: card $before C before, $(temp) C after" | tee -a "$out/pairs.txt"
done
python3 work/build.py restore $s > /dev/null
date '+%H:%M:%S done'
