#!/bin/sh
# usage: shot.sh <out.png>   full 1920x1080 game-view capture
export MAYDAY_STUDIO_TAG=mayday-store2
o="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
cd /Users/bogdan/RobloxProjects/MaydaySeaRescue && python3 tools/studio/smoke.py shot tv3 --full "$o" 2>&1 | grep -v '^\[locks\]'
