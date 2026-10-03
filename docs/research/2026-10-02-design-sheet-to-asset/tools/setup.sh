#!/usr/bin/env bash
# setup.sh WORK_DIR: makes a working folder for these tools from this folder, the asset-to-sheet pilot's
# toolkit and an Agentnagar checkout. The checkout itself is never written to: the pieces are swapped into a
# copy of the client under WORK_DIR/game.
#
#   tools/setup.sh /some/work/dir
#   export AGENTNAGAR=/path/to/agentnagar
#   /some/work/dir/work/run_all.sh
#
# What it makes: work/ (these tools and assets.json), venv/ (Python 3.12 with the three libraries the cutting
# and comparing scripts use), game/ (the pilot's working copy of the client with its capture tools, and the
# crops of the concept sheets the great tree's measures read), and the empty folders the steps fill.
# It needs uv, Blender, the image-to-3D model (trellis.cpp and its weights; see gen3d.sh) and the game's own
# development environment (.local/dev-env.sh in the checkout).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:-$(git -C "$HERE" rev-parse --show-toplevel)}"
PILOT="$AGENTNAGAR/docs/research/2026-10-01-asset-to-sheet-pilot"
WORK="${1:?usage: setup.sh WORK_DIR}"
mkdir -p "$WORK"/{work,raw,crops,out,logs,previews,captures,bench,scratch}
cp "$HERE"/*.py "$HERE"/*.sh "$HERE"/*.gd "$HERE"/*.cjs "$HERE"/assets.json "$HERE"/requirements.txt "$WORK/work/"
uv venv --quiet --python 3.12 "$WORK/venv"
uv pip install --quiet --python "$WORK/venv/bin/python" -r "$HERE/requirements.txt"
"$PILOT/tools/setup.sh" --bare "$WORK/game"
cp "$HERE/asset_views.gd" "$WORK/game/asset_views.gd"          # this record's: it can name a piece's whole file and take several pieces in one start
cp "$HERE/asset_try_many.sh" "$WORK/game/asset_try_many.sh"
cp -r "$PILOT/banyan/inputs" "$WORK/game/inputs"
echo "working folder ready: $WORK"
echo "then: export AGENTNAGAR=$AGENTNAGAR; $WORK/work/run_all.sh"
