#!/bin/bash
# CH6: upload Bosun maps (Image) and LOD FBXs (Model) through assets.py under the asset lock.
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$GAME"
L=~/RobloxProjects/tools/with-lock.sh
A=~/RobloxProjects/tools/assets.py
ERR=art/source/characters/M_Chr_Bosun/upload_last_err.txt
fail=0; ok=0
for f in assets/textures/M_Chr_Bosun/*.png; do
  n="Mayday_$(basename "$f" .png)"
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Image --name "$n" > /dev/null 2> "$ERR" \
    && ok=$((ok+1)) || { echo "FAIL $f"; tail -3 "$ERR"; fail=1; }
done
echo "images ok=$ok fail=$fail"
for l in 0 1 2; do
  f="assets/fbx/M_Chr_Bosun/M_Chr_Bosun_LOD$l.fbx"
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Model --name "M_Chr_Bosun_LOD$l" 2> "$ERR" | tail -3 \
    || { echo "FAIL $f"; tail -3 "$ERR"; }
  tail -2 "$ERR"
done
echo "upload done"
