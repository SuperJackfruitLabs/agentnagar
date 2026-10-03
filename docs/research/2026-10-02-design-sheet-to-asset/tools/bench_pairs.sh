#!/usr/bin/env bash
# bench_pairs.sh [STYLE ...]: the frame-time comparison between the kit's pieces and the built ones, one style
# at a time, so that the graphics card's warming does not pass for a difference. For each style (default: the
# five with pieces built) it runs the game's bench (bench.sh) on that style's two scenes in the order kit, new,
# new, kit, so that a steady drift falls on both alike.
#
# The card's temperature decides the frame time more than the pieces do: a run over all five styles in one go
# warmed the card from 63 to 82 degrees and its later runs came out up to four times slower than its first,
# and starting each style on a card cooled to 68 degrees measured the warming and nothing else. So by default
# (STEADY=1) each style is first run with the kit's pieces until the card stops warming (two runs in a row
# ending within one degree of each other, at most WARM runs, default 5): those runs are thrown away, and the
# four that count are taken on a card that is as warm as it is going to get. STEADY=0 is the earlier way: wait
# for the card to cool to COOL degrees (default 68; at most WAIT seconds, default 420) before each style.
#
# PIECES names what "new" is (default: every built piece; piece names or sets such as @first). Results go to
# BENCH (default bench/): kit-<style>-<n>.json and new-<style>-<n>.json (and .log, .temperature.txt), n = 1, 2;
# pairs.txt lists the order and the card's temperature before and after each run.
# It leaves the built pieces in the working copy of the game.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cool=${COOL:-68}; wait_most=${WAIT:-420}; steady=${STEADY:-1}; warm_most=${WARM:-5}
out="${BENCH:-$W/bench}"; pieces="${PIECES-}"
styles="${*:-lowpoly_tropical neon_noir anime_cel solarpunk voxel}"
temp() { nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null | head -1; }
mkdir -p "$out"; : > "$out/pairs.txt"
run() {   # run LABEL STYLE: one bench run, its files moved to $out
  "$W/work/bench.sh" "$1" "$2" > /dev/null
  if [ "$out" != "$W/bench" ]; then for f in "$W/bench/$1".*; do [ -e "$f" ] && mv "$f" "$out/"; done; fi
}
for s in $styles; do
  python3 "$W/work/build.py" restore "$s" > /dev/null
  if [ "$steady" = 1 ]; then
    last=0; n=0
    while [ "$n" -lt "$warm_most" ]; do
      n=$((n + 1)); before=$(temp); run "warm-$s-$n" "$s"; now=$(temp)
      echo "  warm-$s-$n: card $before C before, $now C after (thrown away)" | tee -a "$out/pairs.txt"
      if [ "$n" -gt 1 ] && [ $((now - last)) -le 1 ] && [ $((last - now)) -le 1 ]; then break; fi
      last=$now
    done
    echo "$s: card steady at $(temp) C after $n warming runs" | tee -a "$out/pairs.txt"
  else
    waited=0
    while [ "$(temp)" -gt "$cool" ] 2>/dev/null && [ "$waited" -lt "$wait_most" ]; do sleep 10; waited=$((waited + 10)); done
    echo "$s: waited $waited s for the card to cool, now $(temp) C" | tee -a "$out/pairs.txt"
  fi
  for r in kit-1 new-1 new-2 kit-2; do
    if [ "${r%-*}" = kit ]; then python3 "$W/work/build.py" restore "$s" > /dev/null; else python3 "$W/work/build.py" place "$s" $pieces > /dev/null; fi
    before=$(temp)
    run "${r%-*}-$s-${r#*-}" "$s"
    echo "  ${r%-*}-$s-${r#*-}: card $before C before, $(temp) C after" | tee -a "$out/pairs.txt"
  done
  python3 "$W/work/build.py" place "$s" $pieces > /dev/null
done
