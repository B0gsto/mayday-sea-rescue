#!/bin/bash
# CH6: upload Bosun maps (Image) and LOD FBXs (Model) through assets.py under the asset lock, then wait (time-boxed,
# BOSUN_MOD_WAIT seconds, default 900) until every Bosun manifest entry is moderation-Approved, so Studio can fetch the
# images and generate its TexturePacks before studio_pass.sh shoots. Exit 0 = all Approved, 2 = timed out, 3 = Rejected,
# 1 = an upload failed. Identical bytes are a no-op upload (manifest keyed by sha256).
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
    || { echo "FAIL $f"; tail -3 "$ERR"; fail=1; }
  tail -2 "$ERR"
done
echo "upload done (fail=$fail)"
[ "$fail" = 0 ] || exit 1

# Moderation poll: `assets.py refresh` re-reads every non-final manifest entry (locked read-merge-write of the manifest).
pending() {
  python3 - <<'EOF'
import json
m = json.load(open("assets/manifest.json"))
for e in m.values():
    src = e.get("source", "")
    if "/M_Chr_Bosun/" in src and e.get("moderation") != "Approved":
        print("%s=%s" % (src.rsplit("/", 1)[-1], e.get("moderation")))
EOF
}
deadline=$((SECONDS + ${BOSUN_MOD_WAIT:-900}))
while :; do
  "$L" assets.MaydaySeaRescue -- python3 "$A" refresh . > /dev/null 2>> "$ERR"
  p="$(pending)"
  if [ -z "$p" ]; then echo "moderation: all Bosun assets Approved"; exit 0; fi
  if echo "$p" | grep -q "=Rejected"; then echo "moderation: REJECTED:"; echo "$p" | grep "=Rejected"; exit 3; fi
  if [ "$SECONDS" -ge "$deadline" ]; then echo "moderation: TIMEOUT, still pending:"; echo "$p"; exit 2; fi
  echo "moderation: $(echo "$p" | wc -l | tr -d ' ') pending, next check in 30 s"
  sleep 30
done
