#!/usr/bin/env bash
# replay.sh DIR [adopt]: every piece built again in an empty folder, from the design sheets and the generator's
# output, with the tools as they stand, and compared byte for byte with the pieces kept in the working folder.
# It is the proof that the tools in work/ make the pieces in out/: tools merged from several hands, and pieces
# built at different hours of a day, drift apart otherwise.
#
# DIR gets a copy of work/, links to raw/ (the generator's output: the slow step is not repeated) and to venv/,
# its own crops/ (the sheets are cut again) and its own out folders. The five styles are fitted side by side.
# Then every .glb in DIR's out, out-budget, out-first-sheet, out-worn, out-kit-green and out-leaves is compared with the
# working folder's: `same`, `differs` or `only here` / `only there`, in DIR/replay.txt.
# With `adopt` as a second word the pieces that differ, and their reports, are then copied over the working
# folder's (the earlier ones go to scratch/before-replay/), so that what is kept is what the tools make.
# AGENTNAGAR must name the checkout. Nothing is placed in the game.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
source "$AGENTNAGAR/.local/dev-env.sh" > /dev/null 2>&1
DIR="${1:?usage: replay.sh DIR [adopt]}"; adopt="${2:-}"
STYLES="${STYLES:-lowpoly_tropical neon_noir anime_cel solarpunk voxel}"
if [ ! -d "$DIR/work" ]; then
  mkdir -p "$DIR/work" "$DIR/logs"
  for f in "$W"/work/*; do [ -f "$f" ] && cp -p "$f" "$DIR/work/"; done
  ln -sfn "$W/raw" "$DIR/raw"; ln -sfn "$W/venv" "$DIR/venv"
  mkdir -p "$DIR/scratch"; [ -d "$W/scratch/validator" ] && ln -sfn "$W/scratch/validator" "$DIR/scratch/validator"
  date '+started %H:%M:%S' > "$DIR/logs/times.txt"
  for s in $STYLES; do python3 "$DIR/work/build.py" cut $s > "$DIR/logs/cut-$s.log" 2>&1 & done; wait
  for s in $STYLES; do (
    python3 "$DIR/work/build.py" fit $s
    python3 "$DIR/work/build.py" fit $s @first --budget
    python3 "$DIR/work/build.py" fit $s @first-variants
    python3 "$DIR/work/build.py" fit $s @trees-kit-green
    python3 "$DIR/work/build.py" fit $s shrub-round-leaves
  ) > "$DIR/logs/fit-$s.log" 2>&1 & done; wait
  date '+fitted %H:%M:%S' >> "$DIR/logs/times.txt"
fi
python3 - "$W" "$DIR" "$adopt" <<'PY'
import filecmp, shutil, sys
from pathlib import Path
W, D, adopt = Path(sys.argv[1]), Path(sys.argv[2]).resolve(), sys.argv[3] == "adopt"
lines, counts = [], {"same": 0, "differs": 0, "only in the replay": 0, "only in the working folder": 0}
for folder in ("out", "out-budget", "out-first-sheet", "out-worn", "out-kit-green", "out-leaves"):
    here = {p.relative_to(D / folder) for p in (D / folder).glob("*/*.glb")} if (D / folder).exists() else set()
    there = {p.relative_to(W / folder) for p in (W / folder).glob("*/*.glb")} if (W / folder).exists() else set()
    for rel in sorted(here | there):
        if rel not in there:
            verdict = "only in the replay"
        elif rel not in here:
            verdict = "only in the working folder"
        else:
            verdict = "same" if filecmp.cmp(D / folder / rel, W / folder / rel, shallow=False) else "differs"
        counts[verdict] += 1
        lines.append(f"{verdict:26s} {folder}/{rel}")
        if adopt and verdict in ("differs", "only in the replay"):
            for src in sorted((D / folder / rel.parent).glob(rel.stem + ".*")):
                dst = W / folder / rel.parent / src.name
                if dst.exists():
                    keep = W / "scratch" / "before-replay" / folder / rel.parent / src.name
                    keep.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(dst, keep)
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
summary = ", ".join(f"{n} {k}" for k, n in counts.items())
(D / "replay.txt").write_text("\n".join(lines) + "\n" + summary + ("\nthe pieces that differ were copied over the working folder's\n" if adopt else "\n"))
print(summary)
print("\n".join(l for l in lines if not l.startswith("same")))
PY
grep -L "tris" "$DIR"/logs/fit-*.log 2>/dev/null | sed 's/^/no piece built, see /'
grep -h "FAILED\|fit failed" "$DIR"/logs/fit-*.log 2>/dev/null | cut -c1-160
