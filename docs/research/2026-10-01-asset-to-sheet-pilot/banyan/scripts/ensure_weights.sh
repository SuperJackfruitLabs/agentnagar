#!/usr/bin/env bash
# Resumes the TRELLIS.2 weight downloads until every file matches the size the
# model repository lists. Usage: ensure_weights.sh FILE [FILE ...]  (names without .gguf)
set -u
M=$HOME/.local/share/trellis2-gguf/q8
mkdir -p "$M"; cd "$M"
sizes=$(curl -fsSL 'https://huggingface.co/api/models/ilintar/trellis2-gguf/tree/main/q8')
want() { python3 -c "
import json,sys,os
for f in json.loads(sys.argv[1]):
    if os.path.basename(f['path'])==sys.argv[2]+'.gguf': print(f.get('lfs',{}).get('size',f.get('size')))" "$sizes" "$1"; }
for f in "$@"; do
  w=$(want "$f")
  for attempt in 1 2 3 4 5 6 7 8; do
    have=$(stat -c %s "$f.gguf" 2>/dev/null || echo 0)
    [ "$have" = "$w" ] && { echo "$f: complete ($have bytes)"; break; }
    echo "$f: $have of $w, attempt $attempt"
    curl -fL -C - --retry 5 --retry-all-errors -sS -o "$f.gguf" "https://huggingface.co/ilintar/trellis2-gguf/resolve/main/q8/$f.gguf" || true
  done
done
