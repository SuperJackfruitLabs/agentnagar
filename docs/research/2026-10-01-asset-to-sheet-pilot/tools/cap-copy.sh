#!/usr/bin/env bash
# Runs a capture script from the working copy of the client: the project's sheet views for one style
# (tools/sheet_views.gd, the default), or the script and arguments in CAP_SCRIPT and CAP_ARGS.
# Started by try.sh or asset_try.sh inside the nested KWin; the X11 driver is the one that exits cleanly there.
W="${W:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh"
cd "$W/city"
echo "godot $(godot --version) on DISPLAY=$DISPLAY" > "$W/cap-copy.log"
timeout 600 godot --display-driver x11 --path godot --resolution 1920x1080 --script "${CAP_SCRIPT:-res://tools/sheet_views.gd}" \
  -- ${CAP_ARGS:-${CAP_STYLE:-lowpoly_tropical}} >> "$W/cap-copy.log" 2>&1
echo "capture-exit=$?" >> "$W/cap-copy.log"
