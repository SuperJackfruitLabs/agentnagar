#!/usr/bin/env bash
# run_game.sh [STYLE]: opens the working copy of the game (the one holding the new pieces) in a style
# (lowpoly_tropical, neon_noir, anime_cel, solarpunk or voxel; pixel art has no new pieces). AGENTNAGAR must name the checkout. On a
# laptop with two graphics cards, put `prime-run` in front to use the faster one.
#
# Swapping a piece into the copy deletes the engine's cached import of it, so the copy is imported first
# (a few seconds when little has changed); without that the game cannot load the piece.
# GODOT_ARGS, if set, is passed to the engine (the boot test uses it to run in a hidden desktop).
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
G="$W/game"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh"
( W="$G"; source "$G/import-copy.sh"; import_copy ) || exit 1
cd "$G/city" && exec godot ${GODOT_ARGS:-} --path godot -- --style="${1:-lowpoly_tropical}"
