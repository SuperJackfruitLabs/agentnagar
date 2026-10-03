#!/usr/bin/env bash
# try.sh STYLE [VIEWS_DIR]: import the working copy of the client and capture one style's sheet views
# offscreen (the project's tools/sheet_views.gd: topdown, diagonal, street, night-rain, park, workshop,
# gathering, a1). The views land in VIEWS_DIR/STYLE/ (default: captures/round2).
#
# The capture runs in a nested, windowless KWin so nothing shows on the desktop. `setpriv --no-new-privs`
# is needed when this is started from a Claude Code session, whose processes may not go real-time.
# CAP_DESKTOP is that desktop's size (default 2560x1440, which gives frames of 2544 by 1424; the great
# tree's recorded frames were taken on 1920x1080, which gives 1920 by 1080).
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
s=$1; dest=${2:-$W/captures/round2}; desk=${CAP_DESKTOP:-2560x1440}
source "$AGENTNAGAR/.local/dev-env.sh"; ulimit -c 0
source "$W/import-copy.sh"; import_copy || exit 1
rm -f "$W/cap-copy.log"
W="$W" CAP_STYLE=$s timeout 600 setpriv --no-new-privs kwin_wayland --virtual --xwayland --width "${desk%x*}" --height "${desk#*x}" \
  --socket "wl-try-$s-$$" --no-lockscreen --no-global-shortcuts --no-kactivities --exit-with-session "$W/cap-copy.sh" \
  > "$W/cap-copy-kwin.log" 2>&1
echo "$s: $(grep capture-exit "$W/cap-copy.log"), script errors: $(grep -cE 'SCRIPT ERROR' "$W/cap-copy.log")"
mkdir -p "$dest"; rm -rf "$dest/$s"; mv ~/.cache/agentnagar-sheets/$s "$dest/"
