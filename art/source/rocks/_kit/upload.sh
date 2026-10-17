#!/bin/bash
# K1 upload: every kit piece's Granite set (+ _Wet) and its three FBX LODs, under the assets lock.
set -uo pipefail
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "K1 upload" -- bash -c '
T=~/RobloxProjects/tools
for a in $(python3 -c "import sys; sys.path.insert(0,\"art/source/rocks/_kit\"); from kit import KIT; print(\" \".join(r[0] for r in KIT))"); do
  for f in assets/textures/$a/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD0.fbx --type Model --name $a 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD1.fbx --type Model --name ${a}_LOD1 2>&1 | tail -1
  python3 $T/assets.py upload . assets/fbx/$a/${a}_LOD2.fbx --type Model --name ${a}_LOD2 2>&1 | tail -1
done
'
