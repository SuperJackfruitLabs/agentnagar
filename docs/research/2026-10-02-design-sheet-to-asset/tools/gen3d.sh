#!/usr/bin/env bash
# gen3d.sh INPUT.png OUT.glb [SEED] [extra trellis-cli options]: one image through the image-to-3D model
# (TRELLIS.2 via trellis.cpp, 8-bit weights, 512 path), with its cut-out saved beside the output and the
# seconds it took appended to logs/gen3d-times.tsv. The log goes next to the output as OUT.log.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="${TRELLIS_HOME:-$HOME/.local/opt/trellis.cpp}"; M="${TRELLIS_MODELS:-$HOME/.local/share/trellis2-gguf/q8}"
in=$1; out=$2; seed=${3:-42}; shift 2; [ $# -gt 0 ] && shift
mkdir -p "$(dirname "$out")" "$W/logs"
t0=$(date +%s.%N)
# The model writes to a name of its own and the result is moved into place when it is whole, so that a run
# stopped half way leaves nothing that looks like a finished model.
part="${out%.glb}.part.glb"
LD_LIBRARY_PATH="$B" "$B/trellis-cli" "$in" "$part" --models "$M" --res 512 --seed "$seed" --webp off --dump-bg "$@" > "${out%.glb}.log" 2>&1
code=$?
if [ $code -eq 0 ] && [ -s "$part" ]; then
  mv "$part" "$out"
  for side in _base.png _cutout.png .ply; do [ -e "${part%.glb}$side" ] && mv "${part%.glb}$side" "${out%.glb}$side"; done
fi
secs=$(echo "$(date +%s.%N) $t0" | awk '{printf "%.1f", $1 - $2}')
printf '%s\t%s\t%s\t%s\n' "$(date +%T)" "$out" "$secs" "$code" >> "$W/logs/gen3d-times.tsv"
if [ $code -ne 0 ] || [ ! -s "$out" ]; then echo "gen3d FAILED ($code) for $in after $secs s: $(tail -2 "${out%.glb}.log" | tr '\n' ' ' | cut -c1-200)"; exit 1; fi
echo "gen3d: $out in $secs s ($(stat -c %s "$out" | awk '{printf "%.1f MB", $1/1048576}'))"
