# Sourced by try.sh and asset_try.sh (W is the working folder, godot is on the path).
# import_copy: imports the working copy of the client, then checks that every GLB in it came through as a
# scene. One unattended run once captured a fresh copy with nothing imported (the game then draws placeholders
# and no placed piece is found); it did not recur in ten later fresh copies and its cause was not found.
# So the import is checked, tried once more if short (its log kept as import-copy-failed.log), and the script
# stops if it is still short.
import_copy() {
  local want got try
  want=$(find "$W/city/godot" -name '*.glb' -not -path '*/.godot/*' | wc -l)
  for try in 1 2; do
    (cd "$W/city/godot" && timeout 1800 godot --headless --path . --import --quit > "$W/import-copy.log" 2>&1) || true
    got=$(ls "$W/city/godot/.godot/imported" 2>/dev/null | grep -c '\.glb-.*\.scn$' || true)
    [ "${got:-0}" -ge "$want" ] && return 0
    cp "$W/import-copy.log" "$W/import-copy-failed.log" 2>/dev/null || true
    echo "import: ${got:-0} of $want GLBs came through (try $try); log kept as import-copy-failed.log"
  done
  echo "import: still short after two tries"; return 1
}
