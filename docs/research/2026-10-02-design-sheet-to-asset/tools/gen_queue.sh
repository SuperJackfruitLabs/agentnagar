#!/usr/bin/env bash
# gen_queue.sh BATCH [STYLE ...]: puts a batch's design sheets through the image-to-3D model as they arrive,
# one object at a time (the model wants the graphics card to itself), until every object of every sheet of the
# batch has its model in raw/. A sheet has arrived when its first revision holds review.md (the last file the
# intake writes). The objects are those in assets.json whose `batch` is BATCH. While the file scratch/gen.pause
# exists nothing new is started (for a frame-time run or a set of captures that needs the card); remove it to
# go on. Progress: logs/gen-queue.log. AGENTNAGAR must name the checkout.
set -u
W="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export AGENTNAGAR="${AGENTNAGAR:?set AGENTNAGAR to the Agentnagar checkout}"
cd "$W"
batch=${1:?usage: gen_queue.sh BATCH [STYLE ...]}; shift
styles="${*:-anime_cel lowpoly_tropical neon_noir solarpunk voxel}"
S="$AGENTNAGAR/docs/vision/asset-studies/sheets"
log="$W/logs/gen-queue.log"; mkdir -p "$W/logs" "$W/scratch"
say() { echo "$(date +%H:%M:%S) $*" | tee -a "$log"; }
# "sheet key" pairs of the batch, in the order of assets.json.
pairs() { python3 -c "
import json
c = json.load(open('$W/work/assets.json'))
for k, a in c['assets'].items():
    if a.get('batch') == '$batch':
        print(a['sheet'], k)"; }
say "queue for $batch: $(pairs | wc -l) objects a style, styles: $styles"
while :; do
  did=0; waiting=0
  for st in $styles; do
    while read -r sheet key; do
      [ -s "raw/$st/$key.glb" ] && continue
      [ -e "raw/$st/$key.failed" ] && continue                      # tried and failed: left for a person to look at
      if [ ! -f "$S/$st/$sheet/r001/review.md" ]; then waiting=$((waiting + 1)); continue; fi
      [ -f "crops/$st/$sheet/boxes.json" ] || python3 work/build.py cut "$st" "$sheet" >> "$log" 2>&1 < /dev/null
      while [ -e scratch/gen.pause ]; do sleep 20; done
      say "$(python3 work/build.py gen "$st" "$key" 2>&1 < /dev/null | tail -1 | cut -c1-200)"
      if [ ! -s "raw/$st/$key.glb" ]; then mkdir -p "raw/$st"; touch "raw/$st/$key.failed"; say "$st $key: no model came out; marked raw/$st/$key.failed"; fi
      did=1
    done < <(pairs)
  done
  if [ "$did" = 0 ]; then
    [ "$waiting" = 0 ] && break
    sleep 60
  fi
done
say "queue for $batch done"
