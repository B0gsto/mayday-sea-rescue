#!/bin/bash
# H1/H2 upload: the own texture sets (Station Render / Slate / Details, Slipway Steel) and the FBX LODs of both assets.
# Shared sets (BldTrim Sheet, B02 QuayStone / Concrete / WeedyConcrete) are already uploaded (assets/materials/manifest.csv).
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "H1 upload" -- bash -c '
T=~/RobloxProjects/tools
for f in assets/textures/M_Bld_Station/*.png assets/textures/M_Bld_Slipway/*.png; do
  python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
done
for a in M_Bld_Station M_Bld_Slipway; do
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD0.fbx --type Model --name $a 2>&1 | tail -2
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD1.fbx --type Model --name ${a}_LOD1 2>&1 | tail -2
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD2.fbx --type Model --name ${a}_LOD2 2>&1 | tail -2
done
'
