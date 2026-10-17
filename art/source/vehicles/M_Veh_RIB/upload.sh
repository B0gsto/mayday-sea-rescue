#!/bin/bash
# V2 upload: every RIB / helm map (Image) and the FBX LODs (Model, downloaded back as assets/models/<name>.rbxm).
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
cd "$GAME"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "V2 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for f in assets/textures/M_Veh_RIB/*.png assets/textures/M_Veh_RIB_Helm/*.png; do
  n=$(basename "$f" .png)
  python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
done
python3 $T/assets.py upload . assets/fbx/M_Veh_RIB/M_Veh_RIB_LOD0.fbx --type Model --name M_Veh_RIB 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_RIB/M_Veh_RIB_LOD1.fbx --type Model --name M_Veh_RIB_LOD1 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_RIB/M_Veh_RIB_LOD2.fbx --type Model --name M_Veh_RIB_LOD2 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_RIB_Helm/M_Veh_RIB_Helm_LOD0.fbx --type Model --name M_Veh_RIB_Helm 2>&1 | tail -2
'
