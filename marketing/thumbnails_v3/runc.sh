#!/bin/sh
# usage: runc.sh file.luau  -- run a Client script with lib_client prepended (note: the prelude resets the tour camera)
D=/Users/bogdan/RobloxProjects/MaydaySeaRescue/marketing/thumbnails_v3
cat $D/lua/lib_client.luau "$1" > /tmp/tv3_runc.luau && $D/run.sh Client /tmp/tv3_runc.luau
