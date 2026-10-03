#!/usr/bin/env bash
# props_run.sh STYLE [STYLE ...]: the square's props in the working copy of the game, on top of the seats and the
# great tree. For each style: the kit's props with the new seats and tree in place are captured ("today": each
# prop's own views, and the standard views in game/captures/props-before), then every prop that is built is put
# in, the game's collision audit is run, and the same views are taken again ("new", game/captures/props).
# The street trees and palms go in in the sheets' own greens, or in the kit's greens for the styles named in
# KIT_GREEN (default: neon_noir, where the sheet's greens read brown). AGENTNAGAR must name the checkout.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cd "$W"
KIT_GREEN="${KIT_GREEN-neon_noir}"
for s in "$@"; do
  python3 work/build.py restore $s > /dev/null
  python3 work/build.py place $s @first > /dev/null
  python3 work/build.py try $s today @props | tail -1
  ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/props-before" | tail -1 )
  python3 work/build.py place $s @props | grep -c "placed" | sed "s/^/$s: props placed: /"
  case " $KIT_GREEN " in *" $s "*) python3 work/build.py place $s @trees-kit-green | grep -c placed | sed "s/^/$s: trees in the kit's greens: /";; esac
  work/audit.sh $s "$W/out/audit-props" | tee "out/audit-props-$s.txt"
  python3 work/build.py try $s new @props | tail -1
  ( cd game && CAP_DESKTOP=1920x1080 ./try.sh $s "$W/game/captures/props" | tail -1 )
done
