#!/usr/bin/env bash
# asset_try.sh STYLE NEEDLE [VIEWS_DIR] [COUNT] [FRAME]: import the working copy of the client and capture close
# views of one placed asset (tools/asset_views.gd: from eye height and from above, up to COUNT pieces at
# different facings, each with its mask, material and unlit passes), windowless. FRAME is `prop` (the default:
# cameras placed for a piece about the size of a bench) or `auto` (they stand back by the piece's own size). The views land in VIEWS_DIR/STYLE/
# (default: captures/asset), with asset-views.json: where each piece stands and the scale the game gave it.
# CAP_DESKTOP is the nested desktop's size (default 2560x1440, which gives frames of 2544 by 1424).
# Exits 1 if no placed piece was found: a capture that finds none is tried once more (its log kept as
# cap-copy-failed.log) before giving up.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
s=$1; needle=$2; dest=${3:-$W/captures/asset}; count=${4:-3}; frame=${5:-prop}; desk=${CAP_DESKTOP:-2560x1440}
source "$AGENTNAGAR/.local/dev-env.sh"; ulimit -c 0
cp "$W/asset_views.gd" "$W/city/godot/tools/asset_views.gd"
capture() {
  rm -f "$W/cap-copy.log"; rm -rf ~/.cache/agentnagar-sheets/$s
  W="$W" CAP_SCRIPT=res://tools/asset_views.gd CAP_ARGS="$s $needle $count $frame" timeout 600 setpriv --no-new-privs kwin_wayland --virtual --xwayland \
    --width "${desk%x*}" --height "${desk#*x}" --socket "wl-asset-$s-$$-$RANDOM" --no-lockscreen --no-global-shortcuts --no-kactivities \
    --exit-with-session "$W/cap-copy.sh" > "$W/cap-copy-kwin.log" 2>&1
  found=$(grep -o 'asset views: [0-9]*' "$W/cap-copy.log" 2>/dev/null | grep -o '[0-9]*$' || true)
}
source "$W/import-copy.sh"; import_copy || exit 1
capture
if [ "${found:-0}" = 0 ]; then
  cp "$W/cap-copy.log" "$W/cap-copy-failed.log" 2>/dev/null || true
  echo "$s: no placed piece found; importing and capturing once more (log kept as cap-copy-failed.log)"
  import_copy || exit 1
  capture
fi
echo "$s: $(grep capture-exit "$W/cap-copy.log"), script errors: $(grep -cE 'SCRIPT ERROR' "$W/cap-copy.log"), $(grep 'asset views' "$W/cap-copy.log")"
[ "${found:-0}" != 0 ] || { echo "$s: no placed piece whose scene file contains '$needle'"; exit 1; }
mkdir -p "$dest"; rm -rf "$dest/$s"; mkdir -p "$dest/$s"; mv ~/.cache/agentnagar-sheets/$s/asset-* "$dest/$s/"; rmdir ~/.cache/agentnagar-sheets/$s 2>/dev/null || true
