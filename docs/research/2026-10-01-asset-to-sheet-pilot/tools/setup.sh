#!/usr/bin/env bash
# setup.sh [--bare] WORK_DIR [ASSET_DIR ...]: assembles a working folder for the workflow (../WORKFLOW.md) from
# this pilot's folder and an Agentnagar checkout. The scripts sit flat in it beside their data, as they were run.
#
#   export AGENTNAGAR=/path/to/agentnagar        # the checkout; every script in the working folder reads it
#   tools/setup.sh /some/work/dir
#   tools/setup.sh --bare /some/work/dir bench-test/bench
#
# What it makes: the scripts; a copy of the client (city/) to swap assets into, so the checkout is never
# touched; a Python environment for the measuring scripts (cvenv/); the concept sheets' panels (panels/);
# each ASSET_DIR given (an asset's config, builders and settings), copied in under its own name; and, unless
# --bare, the banyan's data: the sheets' ramps and each style's fitted settings, the generated tree's parts,
# the sheet crops, and round 1's and round 2's trees (out/, out2/). The game's frames that the banyan's
# measures read are not kept in the repository: banyan_captures.sh takes them again (captures/before,
# captures/after, captures/round2).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; P="$(dirname "$HERE")/banyan"; R="$P/round2"
# Not set: the checkout this folder sits in.
export AGENTNAGAR="${AGENTNAGAR:-$(git -C "$HERE" rev-parse --show-toplevel)}"
BARE=0; if [ "${1:-}" = "--bare" ]; then BARE=1; shift; fi
WORK="${1:?usage: setup.sh [--bare] WORK_DIR [ASSET_DIR ...]}"; shift
mkdir -p "$WORK"/{captures,previews}
cp "$HERE"/*.py "$HERE"/*.sh "$HERE"/*.gd "$WORK/"
if [ $BARE = 0 ]; then
  mkdir -p "$WORK"/{compare2,out2}
  cp "$R/ramps.json" "$WORK/"
  cp -r "$R/params" "$R/parts" "$R/sheets" "$WORK/"
  cp -r "$P/inputs" "$WORK/inputs"
  cp -r "$P/out" "$WORK/out"
  cp -r "$R/out/." "$WORK/out2/"
  echo '{"lowpoly_tropical": "round2", "voxel": "round2", "anime_cel": "round2", "solarpunk": "round2", "neon_noir": "round2", "pixel_art": "round2"}' > "$WORK/final.json"
fi
for a in "$@"; do cp -r "$a" "$WORK/$(basename "$a")"; done
rsync -a --exclude target --exclude .godot "$AGENTNAGAR/city/" "$WORK/city/"
uv venv --quiet --python 3.12 "$WORK/cvenv"
uv pip install --quiet --python "$WORK/cvenv/bin/python" -r "$HERE/requirements.txt"
(cd "$WORK" && cvenv/bin/python cut_panels.py > /dev/null)
echo "working folder ready: $WORK (client copied from $AGENTNAGAR/city at $(git -C "$AGENTNAGAR" rev-parse --short HEAD))"
echo "its scripts read the checkout from the environment: export AGENTNAGAR=$AGENTNAGAR"
