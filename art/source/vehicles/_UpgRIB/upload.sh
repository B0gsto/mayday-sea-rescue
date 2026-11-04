#!/bin/bash
# Uploads the shared palette maps and every piece's LOD FBX (run from the game root). Ids land in assets/manifest.json.
set -uo pipefail
~/RobloxProjects/tools/with-lock.sh assets.MaydaySeaRescue --owner "art-rib" -- bash -c '
T=~/RobloxProjects/tools
for f in build/prod/_UpgRIB/textures/*.png; do
  python3 $T/assets.py upload . "$f" --type Image --name "$(basename "$f" .png)" 2>&1 | tail -1
done
for p in MegaOutboard ArchSpoiler NeonFins FatTubes Grandstand PaddleWheel SharkJaws ExhaustOrgan ThunderWing; do
  a=M_Upg_RIB_$p
  for lod in LOD0 LOD1 LOD2; do
    n=$a; [ $lod != LOD0 ] && n=${a}_$lod
    python3 $T/assets.py upload . build/prod/$a/fbx/$a/${a}_$lod.fbx --type Model --name "$n" 2>&1 | tail -1
  done
done
'
