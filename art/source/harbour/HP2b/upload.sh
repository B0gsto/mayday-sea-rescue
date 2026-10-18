#!/bin/bash
# HP2b upload: every map PNG (Image) and every FBX LOD (Model) of the 11 buoys, then gen_asset_ids.py.
# usage: upload.sh [Kind ...]   (default all, names from marks.py)
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
cd "$GAME"
KINDS="${*:-Port Starboard North East South West IsolatedDanger SafeWater Bell MooringBuoy PickupBuoy}"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "HP2b upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for k in '"$KINDS"'; do
  case $k in MooringBuoy|PickupBuoy) a=M_Hbr_$k;; *) a=M_Hbr_NavMark_$k;; esac
  for f in assets/textures/$a/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  for lod in LOD0 LOD1 LOD2; do
    n=$a; [ $lod = LOD0 ] || n=${a}_$lod
    python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -1
  done
done
'
for i in 1 2 3 4 5; do python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break; sleep 5; done
