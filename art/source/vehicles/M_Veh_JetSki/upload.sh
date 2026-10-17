#!/bin/bash
# V1 upload: every jet ski / close-up map (Image) and the FBX LODs (Model, downloaded back as assets/models/<name>.rbxm).
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=~/RobloxProjects/tools
cd "$GAME"
"$T/with-lock.sh" assets.MaydaySeaRescue --owner "V1 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for f in assets/textures/M_Veh_JetSki/*.png assets/textures/M_Veh_JetSki_CloseUp/*.png; do
  n=$(basename "$f" .png)
  python3 $T/assets.py upload . "$f" --type Image --name "$n" 2>&1 | tail -1
done
python3 $T/assets.py upload . assets/fbx/M_Veh_JetSki/M_Veh_JetSki_LOD0.fbx --type Model --name M_Veh_JetSki 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_JetSki/M_Veh_JetSki_LOD1.fbx --type Model --name M_Veh_JetSki_LOD1 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_JetSki/M_Veh_JetSki_LOD2.fbx --type Model --name M_Veh_JetSki_LOD2 2>&1 | tail -2
python3 $T/assets.py upload . assets/fbx/M_Veh_JetSki_CloseUp/M_Veh_JetSki_CloseUp_LOD0.fbx --type Model --name M_Veh_JetSki_CloseUp 2>&1 | tail -2
'
