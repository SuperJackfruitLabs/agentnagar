#!/usr/bin/env bash
# boot_test.sh [SECONDS]: starts the game itself through run_game.sh in each style of STYLES (default: the five
# with pieces built), in a hidden desktop, lets it run SECONDS (default 25) and counts what it complains of.
# Says nothing about how it looks.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
secs=${1:-25}
mkdir -p "$W/logs"
for style in ${STYLES:-lowpoly_tropical neon_noir anime_cel solarpunk voxel}; do
  log="$W/logs/boot-$style.log"
  cat > "$W/logs/boot-inner.sh" <<INNER
#!/usr/bin/env bash
GODOT_ARGS="--display-driver x11 --resolution 1920x1080" timeout $secs "$W/work/run_game.sh" $style > "$log" 2>&1
echo "boot-exit=\$?" >> "$log"
INNER
  chmod +x "$W/logs/boot-inner.sh"
  timeout $((secs + 240)) setpriv --no-new-privs kwin_wayland --virtual --xwayland --width 1920 --height 1080 --socket "wl-boot-$$" \
    --no-lockscreen --no-global-shortcuts --no-kactivities --exit-with-session "$W/logs/boot-inner.sh" > /dev/null 2>&1
  echo "$style: $(grep boot-exit "$log") (124 = still running when stopped), script errors: $(grep -c 'SCRIPT ERROR' "$log"), errors: $(grep -c '^ERROR' "$log")"
done
rm -f "$W/logs/boot-inner.sh"
