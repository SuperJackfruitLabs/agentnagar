#!/usr/bin/env bash
# game_tests.sh [NAME ...]: the game's own test suite (city/godot/tests/run_all.gd, what its CI runs) on the working
# copy of the game as it stands, without a display. With names, only the test files whose names contain one.
# Writes out/game-tests.txt (or out/game-tests-<names>.txt) and prints the failures and the count.
# The whole suite takes about a quarter of an hour on this laptop; its collision test alone (`collision`) a few minutes.
# A timing test (test_work_app's "worst event" budget, test_frame_cost) can fail on a busy machine: run it again
# alone before reading it as a fault of the pieces.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh" > /dev/null 2>&1
name="game-tests"; [ $# -gt 0 ] && name="game-tests-$(echo "$*" | tr ' ' '-')"
log="$W/out/$name.txt"
cd "$W/game/city"
timeout 900 godot --headless --path godot --import --quit > /dev/null 2>&1
{ date '+started %Y-%m-%d %H:%M:%S'
  if [ $# -gt 0 ]; then timeout 5400 godot --headless --path godot --script res://tests/run_all.gd -- "$@"
  else timeout 5400 godot --headless --path godot --script res://tests/run_all.gd; fi
  echo "exit $?"; date '+ended %H:%M:%S'; } > "$log" 2>&1
grep -E "^FAIL |^PASS [0-9]+, FAIL [0-9]+|^exit " "$log" | cut -c1-260
