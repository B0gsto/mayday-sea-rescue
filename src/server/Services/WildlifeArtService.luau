--!strict
-- WildlifeArtService (G76): publishes the static grey seal and herring gull meshes as
-- ReplicatedStorage.WildlifeTemplates for the client's ambient wildlife (WildlifeController); clients can't load
-- assets themselves (InsertService is server only). Each template carries attribute Parts (its BasePart count).
-- Also the low-poly pets (Shared.WildlifeRig) with an M_Ani_<pet>_Rare copy where a rare albedo exists, and the
-- fishing boats (LOD1) that work lazy loops round the ring (SeaLifeController, sea1).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = script.Parent.Parent:WaitForChild("Assets")
local AssetLoader = require(Assets:WaitForChild("AssetLoader"))

local WildlifeArtService = {}

local ASSETS = {
	"M_Ani_GreySeal",
	"M_Ani_HerringGull",
	"M_Ani_SealPup",
	"M_Ani_Otter",
	"M_Ani_Turtle",
	"M_Ani_Puffin",
	"M_Ani_Gull",
	"M_Veh_MooredBoat_02@LOD1",
	"M_Veh_MooredBoat_03@LOD1",
}

-- A copy of `m` wearing the rare albedo set (Appearances.<asset>_Rare.Rare.Dry), or nil when there is none.
local function rareCopy(asset: string, m: Model): Model?
	local appearances = Assets:FindFirstChild("Appearances")
	local set = appearances and appearances:FindFirstChild(asset .. "_Rare")
	local rareSet = set and set:FindFirstChild("Rare")
	local dry = rareSet and rareSet:FindFirstChild("Dry")
	if not dry then
		return nil
	end
	local copy = m:Clone()
	copy.Name = asset .. "_Rare"
	for _, d in copy:GetDescendants() do
		if d:IsA("MeshPart") then
			local old = d:FindFirstChildOfClass("SurfaceAppearance")
			if old then
				old:Destroy()
			end
			local sa = dry:Clone()
			sa.Name = "SurfaceAppearance"
			sa.Parent = d
		end
	end
	return copy
end

function WildlifeArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "WildlifeTemplates"
	for _, entry in ASSETS do
		local split = string.split(entry, "@") -- "<asset>@<lod>", LOD0 by default
		local asset = split[1]
		local m = AssetLoader.clone(asset, split[2] or "LOD0")
		if m then
			local parts = 0
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					parts += 1
				end
			end
			m.Name = asset
			m:SetAttribute("Parts", parts)
			m.Parent = folder
			local rare = rareCopy(asset, m)
			if rare then
				rare.Parent = folder
			end
		end
	end
	folder.Parent = ReplicatedStorage -- parented once complete
end

return WildlifeArtService
