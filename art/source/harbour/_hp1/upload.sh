#!/bin/bash
# HP1 upload: every map PNG (Image) and every FBX LOD (Model) of the quay kit, pontoon kit and ladder, under the assets lock.
# HP1b: optional asset names as arguments limit the Model uploads (maps dedupe by sha in the manifest).
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
export HP1_ASSETS="${*:-M_Hbr_QuayKit_Straight M_Hbr_QuayKit_Corner M_Hbr_QuayKit_Steps M_Hbr_QuayKit_Head M_Hbr_QuayKit_Armour M_Hbr_QuayKit_LadderBay M_Hbr_Pontoon_Straight6 M_Hbr_Pontoon_Straight12 M_Hbr_Pontoon_Corner M_Hbr_Pontoon_Finger M_Hbr_Pontoon_Gangway M_Hbr_Ladder}"
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "HP1 upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for d in M_Hbr_QuayKit M_Hbr_Pontoon M_Hbr_Ladder; do
  for f in assets/textures/$d/*.png; do
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
done
for a in $HP1_ASSETS; do
  for lod in LOD0 LOD1 LOD2; do
    n=$a; [ $lod != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . assets/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -1
  done
done
'
