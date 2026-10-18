#!/bin/bash
# HP2a upload: the shared atlas maps (2 sets + _Wet) once, then every prop's LOD0 / LOD1 FBX, under the assets lock.
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "HP2a upload" -- bash -c '
T=~/RobloxProjects/tools
for f in assets/textures/M_Hbr_PropAtlas/*.png; do
  python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
done
for a in $(python3 -c "import sys; sys.path.insert(0,\"art/source/harbour/M_Hbr_PropAtlas\"); from refs import REFS; print(\" \".join(REFS))"); do
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD0.fbx --type Model --name $a 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD1.fbx --type Model --name ${a}_LOD1 2>&1 | tail -1
done
'
