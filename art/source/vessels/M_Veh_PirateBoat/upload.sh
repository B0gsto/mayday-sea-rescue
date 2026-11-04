#!/bin/bash
# Upload the pirate set: shared palette maps (Image) and FBX LODs (Model) from build/prod. Run from a checkout that holds them.
set -uo pipefail
GAME=${GAME:-$(cd "$(dirname "$0")/../../../.." && pwd)}
cd "$GAME"
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "pirates upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for f in build/prod/M_Veh_PirateBoat/textures/M_Veh_PirateBoat/*.png; do
  python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
done
for A in M_Veh_PirateBoat M_Chr_PirateCaptain M_Chr_PirateDeckhand M_Chr_PirateLookout; do
  for f in build/prod/$A/fbx/$A/${A}_LOD*.fbx; do
    python3 $T/assets.py upload . "$f" --type Model --name "$(basename "$f" .fbx)" 2>&1 | tail -2
  done
done
'
