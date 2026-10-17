#!/bin/bash
# G1: upload the FoliageLand atlas maps (Image) and every M_Veg_* LOD FBX (Model) through assets.py under the asset
# lock, then wait (G1_MOD_WAIT s, default 900) until all are moderation-Approved. Identical bytes are a no-op upload.
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../../.." && pwd)"; cd "$GAME"
L=~/RobloxProjects/tools/with-lock.sh; A=~/RobloxProjects/tools/assets.py; ERR=build/g1_upload_err.txt
fail=0
for f in assets/textures/M_Veg_FoliageLand/*.png; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Image --name "Mayday_$(basename "$f" .png)" > /dev/null 2>> "$ERR" || { echo "FAIL $f"; fail=1; }
done
for f in assets/fbx/M_Veg_*/M_Veg_*_LOD[012].fbx; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Model --name "$(basename "$f" .fbx)" > /dev/null 2>> "$ERR" || { echo "FAIL $f"; fail=1; }
done
echo "upload done (fail=$fail)"; [ "$fail" = 0 ] || exit 1
pending() { python3 -c '
import json
for e in json.load(open("assets/manifest.json")).values():
    s = e.get("source", "")
    if ("/M_Veg_" in s and "Kelp" not in s and "Wrack" not in s and "Eelgrass" not in s) and e.get("moderation") != "Approved":
        print("%s=%s" % (s.rsplit("/", 1)[-1], e.get("moderation")))'; }
deadline=$((SECONDS + ${G1_MOD_WAIT:-900}))
while :; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" refresh . > /dev/null 2>> "$ERR"
  p="$(pending)"
  [ -z "$p" ] && { echo "moderation: all G1 assets Approved"; exit 0; }
  echo "$p" | grep -q "=Rejected" && { echo "REJECTED:"; echo "$p" | grep "=Rejected"; exit 3; }
  [ "$SECONDS" -ge "$deadline" ] && { echo "TIMEOUT pending:"; echo "$p"; exit 2; }
  sleep 30
done
