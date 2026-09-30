#!/usr/bin/env bash
# Frame-rate benchmark: every style through the bench scenes on a real
# display, fullscreen at the display's native resolution, as players see
# it. tools/bench.gd fails the run when the desktop will not give the
# window those pixels. Fails when a style that declares a budget in its
# style.json breaks it, and when the run does not complete: a bench
# script that fails to load leaves Godot exiting 0, so the run must end
# with its "bench: N scenes" line and a fresh bench.json. Where
# nvidia-smi is present, the GPU's temperature and graphics clock are
# sampled every half second and each scene's peak temperature and clocks
# are printed after the run (godot/tools/bench_heat.py), so heat can be
# told apart from cost. BENCH_STYLES=a,b limits it to those styles, and
# BENCH_SCENES=x,y to those scenes.
# Results: ~/.cache/agentnagar-bench/bench.json, bench.log and gpu.csv.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -z "${DISPLAY:-}" ]; then
    echo "city: no display; skipping the frame-time benchmark"
    exit 0
fi
OUT="$HOME/.cache/agentnagar-bench"
mkdir -p "$OUT"
rm -f "$OUT/bench.json" "$OUT/bench.log" "$OUT/gpu.csv"

SAMPLER=""
if command -v nvidia-smi >/dev/null 2>&1; then
    (
        while :; do
            echo "$(date +%s.%N),$(nvidia-smi --query-gpu=temperature.gpu,clocks.gr --format=csv,noheader,nounits 2>/dev/null)"
            sleep 0.5
        done
    ) >"$OUT/gpu.csv" &
    SAMPLER=$!
fi
stop_sampler() {
    if [ -n "$SAMPLER" ]; then
        kill "$SAMPLER" 2>/dev/null || true
        wait "$SAMPLER" 2>/dev/null || true
        SAMPLER=""
    fi
}
trap stop_sampler EXIT

STATUS=0
godot --path godot --script res://tools/bench.gd 2>&1 | tee "$OUT/bench.log" || STATUS=$?
stop_sampler

if ! grep -qE '^bench: [0-9]+ scenes' "$OUT/bench.log" || [ ! -s "$OUT/bench.json" ]; then
    echo "city: the benchmark did not complete (see $OUT/bench.log)"
    exit 1
fi
if [ -s "$OUT/gpu.csv" ]; then
    python3 godot/tools/bench_heat.py "$OUT/bench.json" "$OUT/gpu.csv" || true
fi
exit "$STATUS"
