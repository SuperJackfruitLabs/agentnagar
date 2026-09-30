#!/usr/bin/env bash
# Tests scripts/bench.sh without Godot or a GPU: stub `godot` and
# `nvidia-smi` on PATH stand in for them, so the script's own decisions are
# checked. A run passes only when it completed (its "bench: N scenes" line
# and a fresh bench.json) and nothing broke a budget; a bench script that
# fails to load, which leaves Godot exiting 0, fails. Also checks
# godot/tools/bench_heat.py, which puts each scene's peak GPU temperature
# and graphics clock beside its result.
set -euo pipefail
CITY_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0
check() { # check DESCRIPTION COMMAND...
    local what="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        PASSED=$((PASSED + 1))
    else
        FAILED=$((FAILED + 1))
        echo "test_bench: FAIL: $what" >&2
    fi
}
fails() { ! "$@"; }

STUB="$WORK/bin"
mkdir -p "$STUB"
cat >"$STUB/nvidia-smi" <<'EOF'
#!/bin/sh
echo "55, 1500"
EOF
chmod +x "$STUB/nvidia-smi"

# The stub Godot does what $GODOT_DOES says: "complete" writes bench.json
# and the closing line and exits 0; "over" does the same but exits 1, as a
# broken budget does; "parse" prints a script error and exits 0, as Godot
# does when the bench script fails to load; "stale" leaves an old
# bench.json in place and prints nothing.
cat >"$STUB/godot" <<'EOF'
#!/bin/sh
out="$HOME/.cache/agentnagar-bench"
case "$GODOT_DOES" in
    complete|over)
        mkdir -p "$out"
        echo '{"results": [], "budgets": {}, "baseline": {}}' >"$out/bench.json"
        echo "bench: 0 scenes, 0 over budget"
        [ "$GODOT_DOES" = over ] && exit 1
        exit 0 ;;
    parse)
        echo 'SCRIPT ERROR: Parse Error: There is already a variable named "shown"'
        exit 0 ;;
    stale)
        exit 0 ;;
esac
EOF
chmod +x "$STUB/godot"

run() { # run WHAT: bench.sh with the stubs, in a home of its own
    local home="$WORK/home-$1"
    mkdir -p "$home"
    HOME="$home" PATH="$STUB:$PATH" WAYLAND_DISPLAY=stub GODOT_DOES="$1" \
        bash "$CITY_DIR/scripts/bench.sh"
}

check "a completed run within budget passes" run complete
check "a broken budget fails" fails run over
check "a bench script that fails to load fails, though Godot exits 0" fails run parse
mkdir -p "$WORK/home-stale/.cache/agentnagar-bench"
echo '{"results": []}' >"$WORK/home-stale/.cache/agentnagar-bench/bench.json"
echo "bench: 0 scenes, 0 over budget" >"$WORK/home-stale/.cache/agentnagar-bench/bench.log"
check "a run that writes nothing fails, whatever an earlier run left" fails run stale

# ---- bench_heat.py: each scene's peak temperature and clocks ----

cat >"$WORK/bench.json" <<'EOF'
{"results": [
  {"style": "a", "scene": "menu", "t0": 100.0, "t1": 110.0},
  {"style": "a", "scene": "title", "t0": 110.0, "t1": 120.0},
  {"style": "a", "scene": "old", "t0": 300.0, "t1": 310.0}
]}
EOF
cat >"$WORK/gpu.csv" <<'EOF'
99.5,50, 1800
100.5,61, 1700
105.0,70, 1650
109.9,72, 1400
112.0,74, 1500
119.0,79, 1200
121.0,90, 900
EOF
HEAT="$(python3 "$CITY_DIR/godot/tools/bench_heat.py" "$WORK/bench.json" "$WORK/gpu.csv")"
check "the table has a row per scene" test "$(grep -c '^a ' <<<"$HEAT")" -eq 3
check "the menu's peak is its own samples' highest" grep -qE '^a +menu +72 +1400 +1650 ' <<<"$HEAT"
check "the title's peak and clocks" grep -qE '^a +title +79 +1200 +1350 ' <<<"$HEAT"
check "a scene without samples says so" grep -qE '^a +old +- +- +- ' <<<"$HEAT"
check "bench.json gains the peak" python3 -c "
import json, sys
r = json.load(open('$WORK/bench.json'))['results']
sys.exit(0 if r[0]['gpu_peak_c'] == 72 and r[1]['gpu_clock_min_mhz'] == 1200 and 'gpu_peak_c' not in r[2] else 1)"

echo "test_bench: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
