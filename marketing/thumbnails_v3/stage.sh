#!/bin/sh
# usage: stage.sh <scene>  runs lua/<scene>_pre_client, lua/<scene>_server, lua/<scene>_client (libs prepended), in that order
D=/Users/bogdan/RobloxProjects/MaydaySeaRescue/marketing/thumbnails_v3/lua
for part in pre_client server client; do
  f=$D/$1_$part.luau
  [ -f $f ] || continue
  case $part in *client) lib=$D/lib_client.luau; ctx=Client;; *) lib=$D/lib_server.luau; ctx=Server;; esac
  cat $lib $f > /tmp/tv3_$part.luau
  echo "[$part] $($D/../run.sh $ctx /tmp/tv3_$part.luau)"
done
