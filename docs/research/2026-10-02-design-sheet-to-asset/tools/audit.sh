#!/usr/bin/env bash
# audit.sh STYLE [DEST]: the game's own collision audit (city/godot/tools/collision_audit.gd) on the working copy
# of the game as it stands, without a display and without a day: the three counts that need no simulated day
# (through, within 10 cm, reverse blocked), with any above zero the offenders by piece. The other three
# (walker_pass, player_pass, tram_overlap) are written as zero unmeasured: the game's own test of the audit
# simulates the day (game_tests.sh collision). Writes DEST/STYLE/report.json and overlay.png (default: the working folder's out/audit).
# Exit 1 when any count is above zero: the game's own test holds every style to zero.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
s=$1
dest="${2:-$W/out/audit}"
mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"
cd "$W/game/city"
timeout 900 godot --headless --path godot --import --quit > /dev/null 2>&1
timeout 900 godot --headless --path godot --script res://tools/collision_audit.gd -- --audit-style="$s" --audit-ticks=0 --audit-out="$dest" > "$dest/$s.log" 2>&1
python3 - "$dest/$s/report.json" "$s" <<'PY'
import json, sys
r = json.load(open(sys.argv[1]))
gates = ("through", "within_10cm", "walker_pass", "player_pass", "tram_overlap", "reverse_blocked")
counts = {g: r[g]["count"] for g in gates}
print(sys.argv[2], "audit:", ", ".join(f"{g} {n}" for g, n in counts.items()))
for g in gates:
    by = {}
    for o in r[g]["offenders"]:
        key = f"{o.get('kind')} {o.get('placement_id', o.get('building', o.get('mesh', '')))}"
        by[key] = by.get(key, 0) + 1
    for key, n in sorted(by.items()):
        print(f"  {g}: {key}: {n} cells")
sys.exit(1 if any(counts.values()) else 0)
PY
