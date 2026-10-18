#!/bin/bash
# Strand line: upload the StrandLine atlas maps (Image) and every M_Veg_Strand_* LOD FBX (Model) through assets.py under
# the asset lock, then wait (STRAND_MOD_WAIT s, default 900) until all are moderation-Approved (as upload_g1.sh).
# Identical bytes are a no-op upload. Then run python3 tools/gen_asset_ids.py.
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../../.." && pwd)"; cd "$GAME"
L=~/RobloxProjects/tools/with-lock.sh; A=~/RobloxProjects/tools/assets.py; ERR=build/strand_upload_err.txt
mkdir -p build
fail=0
for f in assets/textures/M_Veg_StrandLine/*.png; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Image --name "Mayday_$(basename "$f" .png)" > /dev/null 2>> "$ERR" || { echo "FAIL $f"; fail=1; }
done
for f in assets/fbx/M_Veg_Strand_*/M_Veg_Strand_*_LOD[012].fbx; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" upload . "$f" --type Model --name "$(basename "$f" .fbx)" > /dev/null 2>> "$ERR" || { echo "FAIL $f"; fail=1; }
done
echo "upload done (fail=$fail)"; [ "$fail" = 0 ] || exit 1
pending() { python3 -c '
import json
for e in json.load(open("assets/manifest.json")).values():
    s = e.get("source", "")
    if ("/M_Veg_Strand" in s or "/M_Veg_StrandLine/" in s) and e.get("moderation") != "Approved":
        print("%s=%s" % (s.rsplit("/", 1)[-1], e.get("moderation")))'; }
deadline=$((SECONDS + ${STRAND_MOD_WAIT:-900}))
while :; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" refresh . > /dev/null 2>> "$ERR"
  p="$(pending)"
  [ -z "$p" ] && { echo "moderation: all strand assets Approved"; exit 0; }
  echo "$p" | grep -q "=Rejected" && { echo "REJECTED:"; echo "$p" | grep "=Rejected"; exit 3; }
  [ "$SECONDS" -ge "$deadline" ] && { echo "TIMEOUT pending:"; echo "$p"; exit 2; }
  sleep 30
done
