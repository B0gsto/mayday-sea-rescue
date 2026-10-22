#!/bin/bash
# Premium jet skis upload (I2f pattern): copy FBX + ship maps from build/prod to assets/, upload every map PNG (Image)
# and FBX LOD (Model), then tools/gen_asset_ids.py.
# usage: upload.sh [asset ...]   (default: both skis)
set -uo pipefail
GAME=/Users/bogdan/RobloxProjects/MaydaySeaRescue
cd "$GAME"
WHAT=${*:-"M_Veh_JetSki_RiptideX M_Veh_JetSki_GildedGull"}
for a in $WHAT; do
  rm -rf "assets/fbx/$a" "assets/textures/$a"
  cp -R "build/prod/$a/fbx/$a" "assets/fbx/$a"
  cp -R "build/prod/$a/textures/$a" "assets/textures/$a"
done
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "premium jet ski upload" -- bash -c '
set -u
T=~/RobloxProjects/tools
for a in '"$(echo $WHAT)"'; do
  for f in assets/textures/$a/*.png; do
    [ -f "$f" ] || continue
    python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
  done
  for lod in LOD0 LOD1 LOD2; do
    f=assets/fbx/$a/${a}_$lod.fbx
    [ -f "$f" ] || continue
    n=$a; [ $lod != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . "$f" --type Model --name "$n" 2>&1 | tail -2
  done
done
'
for i in 1 2 3 4 5; do
  python3 tools/gen_asset_ids.py 2>&1 | tail -2 && break
  echo "gen_asset_ids retry $i"; sleep 5
done
