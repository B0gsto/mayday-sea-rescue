--!strict
-- Sets the Terrain grass decoration in map/terrain/Terrain.rbxm (run by studio_terrain.py after the export; Lune,
-- because Terrain.Decoration and GrassLength are NotScriptable, so execute_luau cannot set them).
-- usage: lune run tools/world/terrain_decoration.luau <Terrain.rbxm> [decoration true|false] [grassLength 0.1..1]
-- Look-dev round 2: off (studio_terrain.py passes "false"): the stock blades read as large, sparse, saturated
-- cones over the photoreal turf, and with neutral MaterialColors they would turn white.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "map/terrain/Terrain.rbxm"
local decoration = process.args[2] ~= "false"
local grassLength = tonumber(process.args[3]) or 0.55 -- short, wind-cropped coastal turf

local model = roblox.deserializeModel(fs.readFile(path))
local terrain: any = model[1]
assert(terrain and terrain.ClassName == "Terrain", "expected a Terrain at the root of " .. path)
terrain.Decoration = decoration
terrain.GrassLength = grassLength
fs.writeFile(path, roblox.serializeModel(model))
print(
	`{path}: Decoration {terrain.Decoration}, GrassLength {string.format(
		"%.2f",
		terrain.GrassLength
	)}`
)
