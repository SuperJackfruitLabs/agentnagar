#!/usr/bin/env bash
# sheets_all.sh [STYLE ...]: the comparison sheets of the square's props, from the captures props_run.sh took.
# For each style: one sheet a family (previews/compare-<style>-<family>.png: the design image, then the kit's
# piece and the new one from eye height and from above, for each piece of the family that was captured in the
# style), and the town before and after (previews/town-<style>-before-after.png: the standard views of the kit's
# town, which run_all.sh's `today` step captured into game/captures/before, and of the town with every built piece). A planted piece the capture tool cannot frame alone (a railing) is in
# the town's views only.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cd "$W"
styles="${*:-lowpoly_tropical neon_noir anime_cel solarpunk voxel}"
for s in $styles; do
  for fam in "trees street-tree-a street-tree-b palm-tall palm-mid palm-short" "terrace cafe-table umbrella planter" \
             "fixtures lamp-post bollard railing" "planting shrub-round shrub-leafy flowerbed" "water fountain tram-shelter"; do
    set -- $fam; name=$1; shift; have=""
    for p in "$@"; do
      if ls captures/new/$p/$s/*eye-0* > /dev/null 2>&1 && ls captures/today/$p/$s/*eye-0* > /dev/null 2>&1; then have="$have $p"; fi
    done
    # Which of a piece's placements is shown: the first, unless something stands between it and the camera there
    # (--clear: in neon a new street tree's crown hides the first shrub from above, so the second is shown), or a
    # neighbour stands in the foreground (by hand: the first voxel street tree is seen from under the next one,
    # and the first two small solarpunk street trees stand among palms; the third stands alone).
    show=""
    [ "$s $name" = "voxel trees" ] && show="--show street-tree-a=eye-2,above-0"
    [ "$s $name" = "solarpunk trees" ] && show="--show street-tree-b=eye-2,above-2"
    if [ -n "$have" ]; then
      venv/bin/python work/compare.py $s previews/compare-$s-$name.png $have --views eye-0,above-0 --clear $show --height 330 | tail -1 | sed "s/^/$s $name ($have ): /"
    else
      rm -f previews/compare-$s-$name.png; echo "$s $name: nothing captured"
    fi
  done
  venv/bin/python work/three_ways.py $s previews/town-$s-before-after.png --columns "the kit's town=before;with every piece built=props" street park gathering diagonal | tail -1
done
