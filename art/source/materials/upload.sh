#!/bin/bash
# B02: upload every material and trim-sheet map (Open Cloud via tools/assets.py; identical bytes are a no-op).
set -uo pipefail
GAME="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$GAME"
fail=0
for f in assets/textures/Materials/*.png assets/textures/M_Bld_TrimSheet/*.png; do
  n="Mayday_$(basename "$f" .png)"
  python3 ~/RobloxProjects/tools/assets.py upload . "$f" --type Image --name "$n" > /dev/null 2> build/materials/upload_last_err.txt \
    || { echo "FAIL $f"; tail -3 build/materials/upload_last_err.txt; fail=1; }
done
echo "upload done fail=$fail"
