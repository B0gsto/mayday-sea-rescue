#!/bin/bash
# Build (once) and start the virtual keyboard daemon as root. Run in a terminal: tools/roblox/keyd.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
KVH="${KVH_SRC:-/tmp/kvh/src}"  # git clone https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git
if [ ! -x "$HERE/.rbxkeyd" ] || [ "$HERE/rbxkeyd.cpp" -nt "$HERE/.rbxkeyd" ]; then
  [ -d "$KVH" ] || git clone --depth 1 --branch v8.5.0 https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice.git "$KVH"  # match the daemon Karabiner-Elements 16.3 ships
  clang++ -std=c++23 -O2 -I"$KVH/include" -I"$KVH/vendor/vendor/include" "$HERE/rbxkeyd.cpp" -o "$HERE/.rbxkeyd" \
    -framework CoreFoundation -framework IOKit
fi
pkill -f "$HERE/.rbxkeyd" 2>/dev/null || true
exec sudo "$HERE/.rbxkeyd"
