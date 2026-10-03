#!/usr/bin/env bash
# bench.sh LABEL [STYLES] [SCENES]: the game's own frame-time bench (tools/bench.gd) on the working copy, inside
# the hidden desktop the captures use, so nothing shows on the screen. It is a comparison between two builds of
# the same scene on the same machine in the same minutes, not the project's frame-rate gate: the gate needs the
# real display at its own refresh rate. Results: bench/<LABEL>.json and .log.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
G="$W/game"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
label=$1; styles=${2:-lowpoly_tropical,neon_noir,anime_cel,solarpunk,voxel}; scenes=${3:-diagonal,street}
source "$AGENTNAGAR/.local/dev-env.sh"; ulimit -c 0
W="$G"; source "$G/import-copy.sh"; import_copy || exit 1; W="$(dirname "$G")"
# The game's bench writes to one fixed place. Whatever result is there (the project's own gate's) is put aside
# and put back afterwards.
KEPT=~/.cache/agentnagar-bench
mkdir -p "$KEPT"
for f in bench.json bench.log gpu.csv; do [ -e "$KEPT/$f" ] && mv "$KEPT/$f" "$KEPT/$f.kept-by-asset-bench"; done
put_back() { for f in bench.json bench.log gpu.csv; do [ -e "$KEPT/$f.kept-by-asset-bench" ] && mv "$KEPT/$f.kept-by-asset-bench" "$KEPT/$f"; done; return 0; }
trap put_back EXIT
rm -f "$G/cap-copy.log"
W="$G" CAP_SCRIPT=res://tools/bench.gd CAP_ARGS=" " BENCH_STYLES=$styles BENCH_SCENES=$scenes timeout 1800 setpriv --no-new-privs \
  kwin_wayland --virtual --xwayland --width 1920 --height 1080 --socket "wl-bench-$$" --no-lockscreen --no-global-shortcuts \
  --no-kactivities --exit-with-session "$G/cap-copy.sh" > "$G/cap-copy-kwin.log" 2>&1
mkdir -p "$W/bench"
cp "$G/cap-copy.log" "$W/bench/$label.log"
if [ -s "$KEPT/bench.json" ]; then mv "$KEPT/bench.json" "$W/bench/$label.json"; fi
nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader > "$W/bench/$label.temperature.txt" 2>/dev/null || true
echo "$label: $(grep -c '' "$W/bench/$label.log") log lines, $(grep capture-exit "$W/bench/$label.log"), temp $(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader 2>/dev/null)"
