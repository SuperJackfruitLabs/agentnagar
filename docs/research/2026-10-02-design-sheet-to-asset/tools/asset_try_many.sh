#!/usr/bin/env bash
# asset_try_many.sh STYLE DEST JOBS: asset_try.sh for several pieces in one start of the game. JOBS is a
# comma-separated list of NEEDLE@KEY[:FRAME[:COUNT]] (see asset_views.gd); each piece's views land in
# DEST/KEY/STYLE/. Starting the game and importing is most of what a capture costs, so twenty pieces taken
# this way cost little more than one. setup.sh puts this script in the working copy (game/), beside the
# asset-to-sheet pilot's asset_try.sh, whose way of starting the game it follows.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
s=$1; dest=$2; jobs=$3; desk=${CAP_DESKTOP:-2560x1440}
source "$AGENTNAGAR/.local/dev-env.sh"; ulimit -c 0
cp "$W/asset_views.gd" "$W/city/godot/tools/asset_views.gd"
source "$W/import-copy.sh"; import_copy || exit 1
rm -f "$W/cap-copy.log"; rm -rf ~/.cache/agentnagar-sheets/$s
W="$W" CAP_SCRIPT=res://tools/asset_views.gd CAP_ARGS="$s $jobs" timeout 1500 setpriv --no-new-privs kwin_wayland --virtual --xwayland \
  --width "${desk%x*}" --height "${desk#*x}" --socket "wl-asset-$s-$$-$RANDOM" --no-lockscreen --no-global-shortcuts --no-kactivities \
  --exit-with-session "$W/cap-copy.sh" > "$W/cap-copy-kwin.log" 2>&1
echo "$s: $(grep capture-exit "$W/cap-copy.log"), script errors: $(grep -cE 'SCRIPT ERROR' "$W/cap-copy.log"), $(grep 'asset views' "$W/cap-copy.log")"
grep "placed, " "$W/cap-copy.log" | grep -v "asset views" | grep " 0 placed" | sed "s/^/$s: no placed piece for/"
for job in ${jobs//,/ }; do
  key=${job#*@}; key=${key%%:*}
  [ -d ~/.cache/agentnagar-sheets/$s/$key ] || continue
  [ -n "$(ls ~/.cache/agentnagar-sheets/$s/$key/asset-*.png 2>/dev/null | head -1)" ] || { rm -rf ~/.cache/agentnagar-sheets/$s/$key; continue; }
  mkdir -p "$dest/$key"; rm -rf "$dest/$key/$s"; mv ~/.cache/agentnagar-sheets/$s/$key "$dest/$key/$s"
done
rm -rf ~/.cache/agentnagar-sheets/$s
