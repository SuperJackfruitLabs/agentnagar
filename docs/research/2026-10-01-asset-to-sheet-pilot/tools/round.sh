#!/usr/bin/env bash
# round.sh STYLE LABEL: put the style's built asset (out2/) into the working copy of the client, capture it
# into captures/LABEL/, and print the tone bands beside the sheet's, today's and round 1's.
W="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
s=$1; label=$2
export CAP_DESKTOP="${CAP_DESKTOP:-1920x1080}"   # the size the tree's recorded frames were taken at
case $s in
  voxel) cp "$W/out2/voxel/v2/tree_large.glb" "$W/city/godot/styles/voxel/assets/v2/tree_large.glb" ;;
  pixel_art) : ;;   # pixel_run.sh puts the sprite, its night twin, its anchor and its size in
  *) cp "$W/out2/$s/tree_banyan.glb" "$W/city/godot/styles/$s/assets/tree_banyan.glb" ;;
esac
"$W/try.sh" "$s" "$W/captures/$label"
"$W/cvenv/bin/python" "$W/bands.py" "$s" "$W/captures/before" "$W/captures/after" "$W/captures/$label"
