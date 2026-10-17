#!/bin/bash
# Spike 1: upload every FBX (Model, download route delivery, then luau; never studio) and every PNG (Image).
# One upload per lock hold. Results: art/spike1/upload_log.txt (one "== file" block per upload, exit code included).
set -u
G=/Users/bogdan/RobloxProjects/MaydaySeaRescue
T=/Users/bogdan/RobloxProjects/tools
LOG=$G/art/spike1/upload_log.txt
: > "$LOG"
up() {
	echo "== $*" >> "$LOG"
	"$T/with-lock.sh" assets.MaydaySeaRescue -- python3 "$T/assets.py" upload "$G" "$@" >> "$LOG" 2>&1
	echo "exit $?" >> "$LOG"
}
for f in "$G"/assets/fbx/Spike1/*.fbx; do up "$f" --type Model --route delivery; done
for f in "$G"/assets/textures/Spike1/*.png; do up "$f" --type Image; done
echo "== DONE" >> "$LOG"
