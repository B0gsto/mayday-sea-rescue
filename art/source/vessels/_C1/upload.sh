#!/bin/bash
# C1 upload: every map PNG (Image) and every FBX LOD (Model) of The Optimist, the kayak and the SUP.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "C1 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
up_asset() {  # $1 asset, $2.. LODs
  a=$1; shift
  for f in assets/textures/$a/*.png; do
    n=$(basename "$f" .png)
    python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
  done
  for lod in "$@"; do
    n=$a; [ "$lod" != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -2
  done
}
up_asset M_Veh_Optimist LOD0 LOD1 LOD2
up_asset M_Veh_Kayak LOD0 LOD1 LOD2
up_asset M_Veh_Paddleboard LOD0 LOD1 LOD2
'
