--!strict
-- TrafficArtService: publishes the parked-car meshes (M_Road_ParkedCar_01..03 LOD0, _COL hull kept, inert) as
-- ReplicatedStorage.TrafficTemplates for the client's moving traffic (AmbientController); clients can't load
-- assets themselves (InsertService is server only). Each template carries attribute Parts (its BasePart count).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local CarPaint = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("CarPaint"))

local TrafficArtService = {}

local ASSETS = { "M_Road_ParkedCar_01", "M_Road_ParkedCar_02", "M_Road_ParkedCar_03" }

function TrafficArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "TrafficTemplates"
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
			-- one template per paint: AmbientController picks a template by seed, so the traffic mixes colours
			for k = 1, #(if string.find(asset, "_02", 1, true) then CarPaint.RED else CarPaint.LIGHT) do
				local painted = if k == 1 then m else m:Clone()
				CarPaint.apply(painted, asset, k - 1)
				painted.Parent = folder
			end
		end
	end
	folder.Parent = ReplicatedStorage -- parented once complete
end

return TrafficArtService
