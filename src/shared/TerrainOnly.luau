--!strict
-- TerrainOnly: keeps Parts off the terrain's MaterialService variants.
-- src/materials/MaterialService.model.json overrides these built-in materials for terrain, and the override also hits
-- Parts. The live client loads a variant a Part uses through a texture pack, that request fails, and the variant is
-- then dropped for the terrain too: the slot draws flat Terrain.MaterialColors (white for Concrete, flat olive for
-- Grass; tools/world/write_terrain.luau). So every Part with an overridden material, or naming a terrain variant, is
-- moved to an unmapped lookalike. Server and client both call guard(): the server for the map and replicated
-- builds, the client for its own local parts.
-- Since 2026-10-22 MaterialService sets no terrain slots (Town.paint tints the built-in ones); the guard stays so
-- Part looks do not shift and a slot override can come back safely.
--
--   TerrainOnly.remap(materialName, variantName) -> newMaterialName?   pure: nil = the part is fine
--   TerrainOnly.guard(root)   fixes root's parts now and each one added later (checked a frame after parenting)

local TerrainOnly = {}

-- overridden built-in material -> unmapped lookalike for Parts (mirror MaterialService's *Name slots)
local SWAP: { [string]: string } = {
	Sand = "Plaster",
	Sandstone = "Plaster",
	Salt = "Plaster",
	Limestone = "Granite",
	CrackedLava = "Granite",
	Rock = "Granite",
	Slate = "Granite",
	Basalt = "Granite",
	Grass = "Fabric",
	LeafyGrass = "Fabric",
	Snow = "Plaster",
	WoodPlanks = "Wood",
	Brick = "Plaster",
	Glacier = "Plaster",
	Ice = "Glass",
	Mud = "Fabric",
	Ground = "Fabric",
	Pavement = "Granite",
	Asphalt = "Granite",
	Cobblestone = "Pebble",
	Concrete = "Plaster",
}

-- the variants the terrain slots use (and their weather twins): a Part naming one breaks the terrain the same way
local TERRAIN_VARIANT: { [string]: boolean } = {}
for _, name in
	{
		"SandDry",
		"SandWet",
		"SeabedSand",
		"ShellGravel",
		"Shingle",
		"Granite",
		"KelpRock",
		"SplashRock",
		"Turf",
		"Moor",
		"TurfStraw",
		"TurfOlive",
		"TurfWorn",
		"SandRipple",
		"Wrack",
		"Mud",
		"Earth",
		"RoadGravelTrack",
		"Asphalt",
		"RoadHarbourCobbles",
		"Concrete",
	}
do
	TERRAIN_VARIANT[name] = true
	TERRAIN_VARIANT[name .. "_Wet"] = true
end

function TerrainOnly.remap(materialName: string, variantName: string): string?
	if variantName ~= "" and not TERRAIN_VARIANT[variantName] then
		return nil -- its own named variant: the slot override does not apply
	end
	local to = SWAP[materialName]
	if to then
		return to
	end
	return if variantName ~= "" then materialName else nil -- a terrain variant on an unmapped base: just drop it
end

local function fix(d: Instance)
	if d:IsA("BasePart") and not d:IsA("Terrain") then
		local to = TerrainOnly.remap(d.Material.Name, d.MaterialVariant)
		if to then
			d.MaterialVariant = ""
			d.Material = (Enum.Material :: any)[to]
		end
	end
end

function TerrainOnly.guard(root: Instance)
	for _, d in root:GetDescendants() do
		fix(d)
	end
	-- deferred: builders often parent first and set Material after
	-- shortcut: a material changed later on a live part is not seen; hook Material changes if one turns up
	root.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			task.defer(fix, d)
		end
	end)
end

return TerrainOnly
