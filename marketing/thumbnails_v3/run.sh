#!/bin/sh
# usage: run.sh Server|Client file.luau  (runs in the mayday-store2 Studio window)
export MAYDAY_STUDIO_TAG=mayday-store2
f="$(cd "$(dirname "$2")" && pwd)/$(basename "$2")"
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue && python3 tools/studio/smoke.py lua "$1" "$f" 2>&1 | grep -v '^\[locks\]'
