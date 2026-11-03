#!/bin/bash
# Upload: the heli flat-colour maps (Image) and the FBX LODs (Model, downloaded back as assets/models/<name>.rbxm).
# Run from the checkout that holds assets/ (worktree or main).
set -uo pipefail
GAME=${GAME:-$(cd "$(dirname "$0")/../../../.." && pwd)}
T=~/RobloxProjects/tools
cd "$GAME"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "RescueHeli upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for f in assets/textures/M_Veh_RescueHeli/*.png; do
  n=$(basename "$f" .png)
  python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
done
python3 $T/assets.py upload . assets/fbx/M_Veh_RescueHeli/M_Veh_RescueHeli_LOD0.fbx --type Model --name M_Veh_RescueHeli 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_RescueHeli/M_Veh_RescueHeli_LOD1.fbx --type Model --name M_Veh_RescueHeli_LOD1 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_RescueHeli/M_Veh_RescueHeli_LOD2.fbx --type Model --name M_Veh_RescueHeli_LOD2 2>&1 | tail -2
'
