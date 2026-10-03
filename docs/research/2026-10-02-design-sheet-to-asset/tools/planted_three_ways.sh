#!/usr/bin/env bash
# planted_three_ways.sh STYLE: the town's wide views with the kit's street trees and palms, with the ones built
# from the design sheets in the sheets' own greens, and with the same in the kit's greens (the `kit-green`
# variants), and one sheet of the three side by side (previews/planted-<style>-three-ways.png). It leaves the
# design-green pieces in the working copy of the game.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cd "$W"
s=$1
PIECES="street-tree-a street-tree-b palm-tall palm-short palm-mid"
KIT_GREEN=""; for p in $PIECES; do KIT_GREEN="$KIT_GREEN $p-kit-green"; done
if [ -z "${SKIP_FIT:-}" ]; then                    # SKIP_FIT=1: the pieces are built already
  python3 work/build.py fit $s $PIECES > logs/planted-$s.log 2>&1
  python3 work/build.py fit $s $KIT_GREEN >> logs/planted-$s.log 2>&1
fi
python3 work/build.py restore $s $PIECES > /dev/null
( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/trees-before" | tail -1 )
python3 work/build.py place $s $KIT_GREEN > /dev/null
( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/trees-kit-green" | tail -1 )
python3 work/build.py place $s $PIECES > /dev/null
( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/trees" | tail -1 )
venv/bin/python work/three_ways.py $s previews/planted-$s-three-ways.png
