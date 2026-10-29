--!strict
-- DepotArtService (docs/25 D, K4): the uploaded building art. DockPieces builds the Depot (M_Bld_Depot), the
-- HQ's Lv1/Lv2 (M_Bld_RescueHQ) and Lv4/Lv5 add-ons (M_Bld_HQAddons), the Bunkhouse's Lv1-5 (M_Bld_Bunkhouse) and the Workshop's, Fish Market's, Clinic's,
-- Lookout's, Boat Yard's, Rescue Boathouse's, Air Station's, Trophy Hall's and Sub Pen's Lv2/Lv3 and the Boathouse's Lv3 add-ons (M_Bld_*Addons) through DockPieces.meshes (the walk-in _COL hulls collide, the visual meshes don't), and the
-- supply barge M_Veh_SupplyBarge is published as ReplicatedStorage.DepotTemplates.Barge for the clients' barge
-- visuals (DepotController; clients can't load assets).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local DockPieces = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("DockPieces"))

local DepotArtService = {}

local retrying: { [string]: boolean } = {}

-- A live place never shows a code-built stand-in: a mesh that failed to load is retried (AssetLoader warns each
-- failure) and every player's plot is rebuilt once it loads (its buildings are tagged MissingMesh).
local function retry(asset: string)
	if retrying[asset] then
		return
	end
	retrying[asset] = true
	task.spawn(function()
		while not AssetLoader.getTemplate(asset, "LOD0") do
			warn(`[DepotArtService] {asset} still not loaded: its buildings stand empty, retrying`)
			task.wait(AssetLoader.RETRY_AFTER)
		end
		retrying[asset] = nil
		local DockService = require(script.Parent:WaitForChild("DockService")) :: any
		for _, player in Players:GetPlayers() do
			DockService.Refresh(player)
		end
	end)
end

function DepotArtService.Init()
	AssetLoader.preload({
		"M_Bld_AirStationAddons",
		"M_Bld_BoathouseAddons",
		"M_Bld_BoatYardAddons",
		"M_Bld_Bunkhouse",
		"M_Bld_ClinicAddons",
		"M_Bld_Depot",
		"M_Bld_FishMarketAddons",
		"M_Bld_HQAddons",
		"M_Bld_LookoutAddons",
		"M_Bld_RescueBoathouseAddons",
		"M_Bld_RescueHQ",
		"M_Bld_SubPenAddons",
		"M_Bld_TrophyHallAddons",
		"M_Bld_WorkshopAddons",
		"M_Prop_BuildStation",
		"M_Prop_JettyCrane",
		"M_Veh_SupplyBarge",
	})
	-- shortcut: yields while the first load runs, so a plot synced in that second waits; two syncs of one plot in
	-- that window could both place a Depot (DockService keeps the last). Make the sync re-entrant if it shows.
	DockPieces.standIns = RunService:IsStudio()
	DockPieces.meshes = function(asset: string): Model?
		local m = AssetLoader.cloneStatic(asset, "LOD0", true)
		if not m and not DockPieces.standIns then
			retry(asset)
		end
		return m
	end
end

function DepotArtService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "DepotTemplates"
	local barge = AssetLoader.clone("M_Veh_SupplyBarge", "LOD0")
	if barge then
		for _, d in barge:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
			end
		end
		barge.Name = "Barge"
		barge.Parent = folder
	end
	folder.Parent = ReplicatedStorage -- parented once complete
end

return DepotArtService
