--!strict
-- AlbumService: the Rescue Album at the station and the Legendary call moment (docs/15 H2).
-- RescueAlbum (shared, pure) owns the collection maths; this service owns the profile field
-- (data.flags.album, like ChallengeService's flags), the Cash for a completed kind's set, the
-- physical board the client draws on (Workspace.StationAlbumBoard) and the server-wide sky flare.
--
-- Remotes (under ReplicatedStorage.Net):
--   Album_State  S->C  { owned = { [variantId]: true }, ownedCount, total }
--   Album_Get    C->S  function -> the same view (first pull)
--   Album_Flare  S->C  { variant, rarity, kind, position } a Legendary call appeared (icon only)
-- Studio: ServerStorage.AlbumDev (BindableFunction) "grant" id / "grantall" / "view".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local RescueAlbum = require(Shared:WaitForChild("RescueAlbum"))
local RescueVariants = require(Shared:WaitForChild("Config"):WaitForChild("RescueVariants"))

local BadgeService = require(script.Parent.BadgeService)
local DataService = require(script.Parent.DataService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local AlbumService = {}
AlbumService.Priority = 88

local FLAG = "album"
local BOARD_NAME = "StationAlbumBoard"

local stateRemote: RemoteEvent? = nil
local flareRemote: RemoteEvent? = nil
local TOTAL = 0
for _, list in RescueVariants.Kinds do
	TOTAL += #list
end

local function flagOf(data: any): any
	if type(data) ~= "table" or type(data.flags) ~= "table" then
		return nil
	end
	return data.flags[FLAG]
end

local function stateOf(data: any): RescueAlbum.State
	return RescueAlbum.fromFlagTable(flagOf(data))
end

local function viewOf(state: RescueAlbum.State): { [string]: any }
	local owned = {}
	local count = 0
	for _, def in RescueVariants.Kinds do
		for _, variant in def do
			if state.owned[variant.id] then
				owned[variant.id] = true
				count += 1
			end
		end
	end
	return { owned = owned, ownedCount = count, total = TOTAL }
end

local function push(player: Player, state: RescueAlbum.State)
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, viewOf(state))
	end
end

local function record(player: Player, variantId: string)
	local data = DataService.Get(player)
	if not data then
		return
	end
	local state = stateOf(data)
	local variant = RescueVariants.ById(variantId)
	if variant then
		if variant.rarity == "Legendary" then
			BadgeService.Count(player, "LegendaryRescue")
		end
		if variant.id == "GoldenGull" then
			BadgeService.Count(player, "GoldenGull")
		end
	end
	local fresh, setKind = RescueAlbum.record(state, variantId)
	if not fresh then
		return
	end
	Telemetry.Custom(
		player,
		"AlbumSticker",
		1,
		if variant then variant.rarity else "None",
		variantId
	)
	if not ProgressionService.SetFlag(player, FLAG, RescueAlbum.flagTable(state)) then
		return
	end
	if setKind then
		ProgressionService.Award(player, RescueVariants.SetCash[setKind] or 0, 0, `Album:{setKind}`)
		BadgeService.Count(player, "AlbumSet")
	end
	if viewOf(state).ownedCount >= TOTAL then
		BadgeService.Count(player, "AlbumComplete")
	end
	push(player, state)
end

local function onCompleted(snap: any, helpers: { Player })
	if type(snap.variant) ~= "string" or snap.grade == "Fail" then
		return
	end
	for _, player in helpers do
		record(player, snap.variant)
	end
end

-- A Legendary call: a gold flare in the sky over the scene for a full minute, a gold beam
-- standing on the spot that reads across the map, and its sticker flashed to everyone. An Epic
-- gets the smaller flare (no beam). Nothing else is said (docs/15 section 1: an icon, no text).
local FLARE_SECONDS = 60
local EPIC_SECONDS = 22

local function skyFlare(position: Vector3, legendary: boolean)
	local at = position + Vector3.new(0, 110, 0)
	local model = Instance.new("Model")
	model.Name = if legendary then "LegendaryFlare" else "EpicFlare"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = Workspace
	local ball = Instance.new("Part")
	ball.Name = "Flare"
	ball.Shape = Enum.PartType.Ball
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Material = Enum.Material.Neon
	ball.Color = Color3.fromRGB(255, 214, 90)
	local size = if legendary then 14 else 8
	ball.Size = Vector3.new(size, size, size)
	ball.CFrame = CFrame.new(at)
	ball.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 202, 80)
	light.Brightness = if legendary then 7 else 3.5
	light.Range = if legendary then 500 else 240
	light.Shadows = false
	light.Parent = ball
	local beams: { Part } = {}
	if legendary then
		local beam = Instance.new("Part")
		beam.Name = "Beam"
		beam.Anchored = true
		beam.CanCollide = false
		beam.CanQuery = false
		beam.CanTouch = false
		beam.CastShadow = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 210, 96)
		beam.Transparency = 0.45
		beam.Size = Vector3.new(240, 3, 3)
		beam.CFrame = CFrame.new(at + Vector3.new(0, 110, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		beam.Parent = model
		table.insert(beams, beam)

		-- the beam from the spot itself: a gold column from the sea to well above the sky flare
		local column = Instance.new("Part")
		column.Name = "LightBeam"
		column.Anchored = true
		column.CanCollide = false
		column.CanQuery = false
		column.CanTouch = false
		column.CastShadow = false
		column.Material = Enum.Material.Neon
		column.Color = Color3.fromRGB(255, 214, 110)
		column.Transparency = 0.3
		column.Size = Vector3.new(16, 520, 16)
		column.CFrame = CFrame.new(position + Vector3.new(0, 260, 0))
		column.Parent = model
		table.insert(beams, column)
	end
	local life = if legendary then FLARE_SECONDS else EPIC_SECONDS
	task.delay(life - 4, function()
		TweenService:Create(ball, TweenInfo.new(4), { Transparency = 1 }):Play()
		for _, beam in beams do
			TweenService:Create(beam, TweenInfo.new(4), { Transparency = 1 }):Play()
		end
		light.Enabled = false
		task.delay(4.2, function()
			model:Destroy()
		end)
	end)
end

function AlbumService.AnnounceCall(op: any)
	local variant = RescueVariants.ById(op.variant)
	if not variant then
		return
	end
	local legendary = variant.rarity == "Legendary"
	if not legendary and variant.rarity ~= "Epic" then
		return
	end
	skyFlare(op.position, legendary)
	local remote = flareRemote
	if remote then
		remote:FireAllClients({
			variant = variant.id,
			rarity = variant.rarity,
			kind = variant.kind,
			position = op.position,
			legendary = legendary,
		})
	end
end

local function ensureRemoteEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensureRemoteFunction(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A freestanding book-like board on the quay, west of the spawn, facing the harbour (+Z).
local function buildBoard()
	if Workspace:FindFirstChild(BOARD_NAME) then
		return
	end
	local model = Instance.new("Model")
	model.Name = BOARD_NAME
	-- RP-P1: the client mounts a local SurfaceGui on the panel once; a streamed-out Atomic board
	-- would come back as new parts and the printed board would never remount. Four parts, keep it.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local wood = Color3.fromRGB(86, 58, 40)
	local cover = Color3.fromRGB(24, 42, 52)
	-- authored on LandTopY 4; the town terrain sits about 2 studs higher here, which buried the posts
	local hit = Workspace:Raycast(Vector3.new(-84, 40, -14), Vector3.new(0, -80, 0))
	local dy = if hit then hit.Position.Y - 4 else 0
	local cf = CFrame.new(-84, 7.6 + dy, -14) * CFrame.Angles(0, math.pi, 0)
	local panel = part(model, "Panel", Vector3.new(6.8, 5.6, 0.25), cf, cover, Enum.Material.Wood)
	model.PrimaryPart = panel
	part(
		model,
		"Back",
		Vector3.new(7.2, 6.0, 0.2),
		cf * CFrame.new(0, 0, 0.2),
		wood,
		Enum.Material.Wood
	)
	for _, x in { -3.2, 3.2 } do
		part(
			model,
			"Post",
			Vector3.new(0.3, 5.6, 0.3),
			CFrame.new(-84 + x, 6.2 + dy, -13.9),
			wood,
			Enum.Material.Wood
		)
	end
	part(
		model,
		"Cap",
		Vector3.new(7.6, 0.3, 0.7),
		CFrame.new(-84, 10.55 + dy, -13.9),
		wood,
		Enum.Material.Wood
	)
	panel:SetAttribute("AlbumBoard", true)
	model.Parent = Workspace
end

function AlbumService.Init()
	local folder = Net.init()
	stateRemote = ensureRemoteEvent(folder, "Album_State")
	flareRemote = ensureRemoteEvent(folder, "Album_Flare")
	local get = ensureRemoteFunction(folder, "Album_Get")
	get.OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		return if data then viewOf(stateOf(data)) else nil
	end

	DataService.OnLoaded(function(player: Player, data: any)
		push(player, stateOf(data))
	end)
	OperationService.OperationCompleted:Connect(onCompleted)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "AlbumDev"
		dev.OnInvoke = function(cmd: string, value: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			local data = DataService.Get(player)
			if cmd == "grant" and type(value) == "string" then
				record(player, value)
				return true
			elseif cmd == "grantall" then
				local state = if data then stateOf(data) else RescueAlbum.newState()
				for _, list in RescueVariants.Kinds do
					for _, variant in list do
						state.owned[variant.id] = true
					end
				end
				ProgressionService.SetFlag(player, FLAG, RescueAlbum.flagTable(state))
				push(player, state)
				return true
			elseif cmd == "view" and data then
				return viewOf(stateOf(data))
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function AlbumService.Start()
	task.spawn(buildBoard)
end

return AlbumService
