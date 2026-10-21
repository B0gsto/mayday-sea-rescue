--!strict
-- WildlifeArtService (G76): publishes the static grey seal and herring gull meshes as
-- ReplicatedStorage.WildlifeTemplates for the client's ambient wildlife (WildlifeController); clients can't load
-- assets themselves (InsertService is server only). Each template carries attribute Parts (its BasePart count).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))

local WildlifeArtService = {}

local ASSETS = { "M_Ani_GreySeal", "M_Ani_HerringGull" }

function WildlifeArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "WildlifeTemplates"
	for _, asset in ASSETS do
		local m = AssetLoader.clone(asset, "LOD0")
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
		end
	end
	folder.Parent = ReplicatedStorage -- parented once complete
end

return WildlifeArtService
