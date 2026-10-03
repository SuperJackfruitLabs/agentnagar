#!/usr/bin/env bash
# bench_far_swap.sh [STYLE]: a style's street trees and palms built from their design sheets, drawn in full within
# 90 m and as their far twins beyond (the game's own swap, switched on by placing the twins: far_swap.py), against
# the kit's. The order and the warming are bench_pairs.sh's; results go to bench/trees-far-swap/. Afterwards the
# twins are taken out again and the built pieces are left placed, as they were.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh" > /dev/null 2>&1
cd "$W"; s=${1:-lowpoly_tropical}; out=$W/bench/trees-far-swap
mkdir -p "$out"; : > "$out/pairs.txt"
temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1; }
run() { "$W/work/bench.sh" "$1" "$2" > /dev/null; for f in "$W/bench/$1".*; do [ -e "$f" ] && mv "$f" "$out/"; done; }
python3 work/build.py restore $s > /dev/null; python3 work/far_swap.py $s --remove > /dev/null
last=0; n=0
while [ "$n" -lt 5 ]; do
  n=$((n + 1)); before=$(temp); run "warm-$s-$n" "$s"; now=$(temp)
  echo "  warm-$s-$n: card $before C before, $now C after (thrown away)" | tee -a "$out/pairs.txt"
  if [ "$n" -gt 1 ] && [ $((now - last)) -le 1 ] && [ $((last - now)) -le 1 ]; then break; fi
  last=$now
done
echo "$s: card steady at $(temp) C after $n warming runs" | tee -a "$out/pairs.txt"
for r in kit-1 new-1 new-2 kit-2; do
  if [ "${r%-*}" = kit ]; then python3 work/build.py restore $s > /dev/null; python3 work/far_swap.py $s --remove > /dev/null
  else python3 work/build.py place $s @trees > /dev/null; python3 work/far_swap.py $s > "$out/placed.txt"; fi
  before=$(temp); run "${r%-*}-$s-${r#*-}" "$s"
  echo "  ${r%-*}-$s-${r#*-}: card $before C before, $(temp) C after" | tee -a "$out/pairs.txt"
done
python3 work/build.py place $s @trees > /dev/null; python3 work/far_swap.py $s --remove > /dev/null
