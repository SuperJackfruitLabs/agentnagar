#!/usr/bin/env bash
# run_all.sh: every step from the design sheets to the comparison sheets, in order, for the five styles with
# design sheets a model can be made from (STYLES names fewer) and for the seats and the great tree (PIECES names
# others: piece names or sets of them such as @trees, see `sets` in assets.json). STEPS names the steps to take
# (default: all of them): cut gen fit today new check sheets.
# It skips the image-to-3D runs whose output is already in raw/ (they are the slow part and give the same model
# for the same image and seed). AGENTNAGAR must name the checkout. It does not run the frame-time comparison
# (bench_pairs.sh: it wants the graphics card to itself), the boot test (boot_test.sh) or the game's own test
# suite (game_tests.sh); the game's collision audit it does run, with the checks.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cd "$W"
STYLES="${STYLES:-lowpoly_tropical neon_noir anime_cel solarpunk voxel}"
PIECES="${PIECES:-@first}"
VARIANTS="${VARIANTS-@first-variants}"
STEPS="${STEPS:-cut gen fit today new check sheets}"
step() { case " $STEPS " in *" $1 "*) return 0;; esac; return 1; }
for s in $STYLES; do
  if step cut; then python3 work/build.py cut $s; fi
  if step gen; then
    python3 work/build.py gen $s $PIECES || exit 1
    [ -n "$VARIANTS" ] && { python3 work/build.py gen $s $VARIANTS || exit 1; }
  fi
  if step fit; then
    python3 work/build.py fit $s $PIECES || exit 1                            # the shape decides the triangle count
    python3 work/build.py fit $s $PIECES --budget || exit 1                   # the same held to the kit's limit, where that differs
    [ -n "$VARIANTS" ] && { python3 work/build.py fit $s $VARIANTS || exit 1; }   # the variants (each only in the styles it names)
  fi
done
# The game as it is today: each piece's own views and the standard views, with the kit's pieces in place.
if step today; then
  for s in $STYLES; do
    python3 work/build.py restore $s
    python3 work/build.py try $s today $PIECES
    ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/before" | tail -1 )
    work/audit.sh $s "$W/out/audit-kit" | tee "out/audit-kit-$s.txt"
  done
fi
if step new; then
  for s in $STYLES; do
    # The standard views at the size the pilot's were taken at (the tree's measures are compared with them);
    # each piece's own views at the tool's default size, as today's were.
    python3 work/build.py restore $s
    python3 work/build.py place $s $PIECES
    if [ -d out-budget/$s ]; then                                              # the pieces held to the limit, over the new ones
      python3 work/build.py place $s $PIECES --budget
      ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/budget" | tail -1 )
      python3 work/build.py place $s $PIECES
    fi
    if [ -n "$VARIANTS" ] && [ -d out-first-sheet/$s ]; then
      python3 work/build.py place $s great-tree-first-sheet
      ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/first-sheet" | tail -1 )
      python3 work/build.py place $s $PIECES
    fi
    python3 work/build.py try $s new $PIECES
    ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/new" | tail -1 )
    # The game's own collision audit with the pieces in place: its test holds every count to zero.
    work/audit.sh $s "$W/out/audit" | tee "out/audit-$s.txt"
  done
fi
if step check; then
  # The checks come after the captures: the contract check reads the scale the game gave each piece from them.
  # It exits 1 when a piece misses its kit's spec, which is a finding to read, not a reason to stop here.
  ( source "$AGENTNAGAR/.local/dev-env.sh" >/dev/null 2>&1
    python3 work/check.py; echo "-- held to the kit's triangle limit:"; python3 work/check.py --budget
    echo "-- the worn bench:"; python3 work/check.py --variant worn; echo "-- the neon tree from the first sheet:"; python3 work/check.py --variant first-sheet ) | tee out/check.txt
  seats=""
  for s in $STYLES; do seats="$seats $(python3 work/build.py seats $s)"; done
  blender --background --factory-startup --python work/seat_top.py -- $seats 2>/dev/null | grep "^SEAT" | tee out/seat-heights.txt
  # The tree's measures. The rows for the asset-to-sheet pilot's two rounds appear only where its own captures have
  # been put in game/captures/after and game/captures/round2 (its banyan_captures.sh takes them).
  ( cd game && cvenv/bin/python "$W/work/tree_metrics.py" $STYLES ) | tee out/tree-metrics.txt
fi
if step sheets; then
  for s in $STYLES; do
    venv/bin/python work/compare.py $s previews/compare-$s-seats.png bench cafe-chair reading-chair --views eye-0,eye-1 --height 400
    venv/bin/python work/compare.py $s previews/compare-$s-tree.png great-tree --views eye-0,above-0 --height 520
    venv/bin/python work/street_compare.py $s previews/street-$s.png street
    venv/bin/python work/views_compare.py $s previews/views-$s.png
  done
  venv/bin/python work/sitters.py previews/sitters.png $STYLES
  venv/bin/python work/limit_compare.py previews/limit.png $STYLES
fi
