#!/bin/bash
# H3 upload: the shared cottage kit maps (Image) and every cottage FBX LOD (Model), then regenerate the asset ids.
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
cd "$GAME"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "H3 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for f in assets/textures/M_Bld_Cottage_Kit/*.png; do
  n=$(basename "$f" .png)
  python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
done
for i in 01 02 03 04 05 06; do
  a=M_Bld_Cottage_$i
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD0.fbx --type Model --name "$a" 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD1.fbx --type Model --name "${a}_LOD1" 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD2.fbx --type Model --name "${a}_LOD2" 2>&1 | tail -1
done
'
