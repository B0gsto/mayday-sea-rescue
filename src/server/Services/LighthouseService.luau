--!strict
-- LighthouseService (G67): the lighthouses as world goals (docs/03 section 7).
--   * Skerry Light is built on Skerry Isle (the current map has the isle; the Harbor Light already
--     exists through Street.swaps). Both are tagged Lighthouse / LighthouseLens; the client turns
--     each player's relit beams through StreetController.
--   * A board by the station yard offers the next unlit light when its rank / certification / Rep
--     gates are met: OperationService.OfferCall with the mission's Ops definition, the light as the
--     scene position, and op.mission so it pays no rescue Cash or certification progress.
--   * Completing the crank step relights the light for the helpers: profile flag `lighthouses`
--     (docs/03 section 7: the light shines for that player on every server), the radio line, and
--     the Outer (Skerries) call zone opens.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Lighthouses = require(Shared:WaitForChild("Lighthouses"))
local Remotes = require(Shared:WaitForChild("Ops"):WaitForChild("Remotes"))

local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)

local LighthouseService = {}
LighthouseService.Priority = 110 -- after OperationService and ProgressionService

local BOARD_POSITION = Vector3.new(-199, 0, -50) -- the notice row west of the station, west of the crew sign
local BOARD_NAME = "LighthouseBoard"
local STEEL = Color3.fromRGB(62, 68, 72)
local PAINT = Color3.fromRGB(226, 226, 218)

local function groundAt(x: number, z: number, fallback: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -600, 0))
	return if hit and hit.Position.Y > -20 then hit.Position.Y else fallback
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Skerry Light: a greybox granite tower on the west head of Skerry Isle, tall enough to read from
-- the harbour. The client finds ATT_Light and builds the Fl(2) beam rig there.
local function buildSkerry()
	if Workspace:FindFirstChild("SkerryLight") then
		return
	end
	local light = assert(Lighthouses.get("SkerryLight"))
	local x, z = light.position.X, light.position.Z
	local baseY = groundAt(x, z, light.position.Y)
	local base = Vector3.new(x, baseY, z)
	local model = Instance.new("Model")
	model.Name = "SkerryLight"
	model:SetAttribute("LightId", light.id)
	local bottom = part(
		model,
		"Base",
		Vector3.new(14, 6, 14),
		CFrame.new(base + Vector3.new(0, 2, 0)),
		Color3.fromRGB(104, 106, 104),
		Enum.Material.Slate
	)
	local towerY = base.Y + 5
	local segment = 12
	for i = 0, 3 do
		local height = 9 - i
		part(
			model,
			`Tower{i + 1}`,
			Vector3.new(segment, height, height),
			CFrame.new(base + Vector3.new(0, towerY + segment * (i + 0.5), 0))
				* CFrame.Angles(0, 0, math.pi / 2),
			if i % 2 == 0 then PAINT else Color3.fromRGB(172, 44, 38),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end
	local lampY = base.Y + 5 + segment * 4 + 4
	local lens = part(
		model,
		"Lens",
		Vector3.new(7, 7, 7),
		CFrame.new(Vector3.new(x, lampY, z)),
		Color3.fromRGB(214, 220, 212),
		Enum.Material.Glass,
		Enum.PartType.Ball
	)
	lens.CanCollide = false
	CollectionService:AddTag(lens, "LighthouseLens")
	local att = Instance.new("Attachment")
	att.Name = "ATT_Light"
	att.Parent = lens
	part(
		model,
		"Roof",
		Vector3.new(10, 3, 10),
		CFrame.new(Vector3.new(x, lampY + 5, z)),
		Color3.fromRGB(172, 44, 38),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	local gallery = part(
		model,
		"Gallery",
		Vector3.new(12, 1, 12),
		CFrame.new(Vector3.new(x, lampY - 5, z)),
		STEEL,
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	gallery.CanCollide = false
	model.PrimaryPart = bottom
	model.WorldPivot = CFrame.new(base)
	CollectionService:AddTag(model, "Lighthouse")
	model.Parent = Workspace
end

-- The station's lighthouse board: one prompt, no menu. It offers the next unlit light the player's
-- gates allow; the offer then runs like any call (radio card, accept, steps).
local function buildBoard()
	if Workspace:FindFirstChild(BOARD_NAME) then
		return
	end
	local y = groundAt(BOARD_POSITION.X, BOARD_POSITION.Z, 6)
	local origin = Vector3.new(BOARD_POSITION.X, y, BOARD_POSITION.Z)
	local model = Instance.new("Model")
	model.Name = BOARD_NAME
	for _, sx in { -2.6, 2.6 } do
		part(
			model,
			"Post",
			Vector3.new(0.5, 9, 0.5),
			CFrame.new(origin + Vector3.new(sx, 4.5, 0)),
			STEEL,
			Enum.Material.Metal
		)
	end
	local board = part(
		model,
		"Board",
		Vector3.new(7, 4.5, 0.4),
		CFrame.new(origin + Vector3.new(0, 8, 0)) * CFrame.Angles(0, math.pi, 0),
		PAINT,
		Enum.Material.WoodPlanks
	)
	local lamp = part(
		model,
		"Lamp",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(origin + Vector3.new(0, 10.9, 0)),
		Lighthouses.DarkColour,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	lamp.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LighthousePrompt"
	prompt.ObjectText = "Lighthouses"
	prompt.ActionText = "Light the lamp"
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = board
	prompt.Triggered:Connect(function(player)
		LighthouseService.Offer(player)
	end)
	model.PrimaryPart = board
	model.WorldPivot = CFrame.new(origin)
	model.Parent = Workspace
end

-- Offer the next unlit light to `player` when its gates are met. Returns the op id or nil.
function LighthouseService.Offer(player: Player): string?
	local snap = ProgressionService.GetData(player)
	if type(snap) ~= "table" then
		return nil
	end
	local light = Lighthouses.next(snap.flags)
	if not light then
		return nil
	end
	local ok = Lighthouses.canStart(snap, light.id)
	if not ok then
		return nil
	end
	return OperationService.OfferCall(player, light.mission.id, {
		def = light.mission,
		position = light.approach,
		zone = light.spawnZone,
		zoneName = light.displayName,
		mission = true,
	})
end

local function relight(player: Player, lightId: string): boolean
	local snap = ProgressionService.GetData(player)
	if type(snap) ~= "table" or Lighthouses.isLit(snap.flags, lightId) then
		return false
	end
	local flags = Lighthouses.withLit(Lighthouses.fromFlags(snap.flags), lightId)
	if not ProgressionService.SetFlag(player, Lighthouses.FLAG, flags) then
		return false
	end
	ProgressionService.Refresh(player)
	player:SetAttribute("LighthouseRelit", lightId)
	return true
end

-- WP1 retired OperationService's mission path; WP5 deletes this service (docs/16 C15)
local function _onMissionCompleted(snap: any, helpers: { Player })
	if snap.reason ~= "Complete" then
		return
	end
	local light = Lighthouses.missionLight(snap.kind)
	if not light then
		return
	end
	local players = if #helpers > 0 then helpers else snap.assignedTo or {}
	for _, player in players do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
			if relight(player, light.id) then
				Remotes.event("Ops_Radio"):FireClient(player, {
					opId = snap.id,
					from = "Gale Isles Coastguard",
					text = light.radio,
				})
			end
		end
	end
end

function LighthouseService.Init() end

function LighthouseService.Start()
	buildSkerry()
	buildBoard()
	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "LighthouseDev"
		dev.OnInvoke = function(cmd: string, id: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "relight" and type(id) == "string" then
				relight(player, id)
				return ProgressionService.GetData(player)
			elseif cmd == "offer" then
				return LighthouseService.Offer(player)
			end
			return nil
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return LighthouseService
