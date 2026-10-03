#!/bin/sh
# terrace_previews.sh STYLE [STYLE...]: the café terrace's comparison sheets for the styles named, into previews/.
# For each of the table, the umbrella and the planter: previews/<style>-<piece>.png, the design cut-out and the
# generated model, then the kit's piece and the built piece from the same four places, in colour and shaded
# (look.py; the shaded views show form, not the relief map). And previews/<style>-pair.png: the built table and
# umbrella as the game stands them, on one point, the table widened as the game widens it (pair.py), with what
# pair.py measured in previews/<style>-pair.txt. Run from the working folder with AGENTNAGAR set. One Blender at a time.
W=$(cd "$(dirname "$0")/.." && pwd)
K=$AGENTNAGAR/city/godot/styles
P=$W/previews
mkdir -p $P/parts
look() { blender --background --factory-startup --python $W/work/look.py -- "$@" > /dev/null 2>&1; }
for style in "$@"; do
  umbrella=umbrella_cafe; [ $style = lowpoly_tropical ] && umbrella=umbrella_yellow
  dir=assets; fill="--fill 1.0,1.0"
  if [ $style = voxel ]; then dir=assets/v2; fill=""; fi
  for pair in "cafe-table:cafe_table" "umbrella:$umbrella" "planter:planter_square"; do
    piece=${pair%%:*}; file=${pair##*:}
    [ $style = voxel ] && { [ $piece = umbrella ] && file=umbrella; [ $piece = planter ] && file=planter; }
    new=$W/out/$style/$file.glb
    [ -f $new ] || { echo "$style $piece: nothing built"; continue; }
    s=$P/parts/$style-$piece
    look $K/$style/$dir/$file.glb $s-kit.png --size 400
    look $K/$style/$dir/$file.glb $s-kit-lit.png --size 400 --lit
    look $new $s-new.png --size 400
    look $new $s-new-lit.png --size 400 --lit
    look $W/raw/$style/$piece.glb $s-raw.png --size 400
    $W/venv/bin/python $W/work/strip.py $P/$style-$piece.png \
      "the design=$W/raw/$style/${piece}_cutout.png" "the kit's piece=$s-kit-quarter.png" "built=$s-new-quarter.png" "kit, front=$s-kit-front.png" "built, front=$s-new-front.png" "kit, from above=$s-kit-above.png" "built, from above=$s-new-above.png" \
      "as generated=$s-raw-quarter.png" "kit, shaded=$s-kit-lit-quarter.png" "built, shaded=$s-new-lit-quarter.png" "kit, front, shaded=$s-kit-lit-front.png" "built, front, shaded=$s-new-lit-front.png" "kit, from below, shaded=$s-kit-lit-eye.png" "built, from below, shaded=$s-new-lit-eye.png" \
      --cols 7 --height 300
  done
  table=$W/out/$style/cafe_table.glb; canopy=$W/out/$style/$umbrella.glb
  [ $style = voxel ] && canopy=$W/out/$style/umbrella.glb
  if [ -f $table ] && [ -f $canopy ]; then
    blender --background --factory-startup --python $W/work/pair.py -- $table $canopy $P/parts/$style-pair.png $fill 2>&1 | grep "^PAIR" | cut -c6- > $P/$style-pair.txt
    s=$P/parts/$style-pair
    $W/venv/bin/python $W/work/strip.py $P/$style-pair.png "from above=$s-quarter.png" "from a seat=$s-seat.png" "from low down=$s-low.png" "the foot=$s-foot.png" \
      "from above, shaded=$s-quarter-lit.png" "from a seat, shaded=$s-seat-lit.png" "from low down, shaded=$s-low-lit.png" "the foot, shaded=$s-foot-lit.png" --cols 4 --height 420
  fi
done
