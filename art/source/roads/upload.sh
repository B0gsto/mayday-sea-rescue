#!/bin/bash
# R1a upload: road surface maps (M_Road_Ribbon: strips, tiles, markings) and the street furniture (shared Street atlas
# copies, identical bytes = one upload) + three FBX LODs each, under the assets lock. Then: python3 tools/gen_asset_ids.py
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "R1a upload" -- bash -c '
T=~/RobloxProjects/tools
for f in assets/textures/M_Road_Ribbon/*.png; do
  python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
done
for a in M_Road_StreetLamp M_Road_Bench M_Road_Bin M_Road_Bollard; do
  for f in assets/textures/$a/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD0.fbx --type Model --name $a 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD1.fbx --type Model --name ${a}_LOD1 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD2.fbx --type Model --name ${a}_LOD2 2>&1 | tail -1
done
'
