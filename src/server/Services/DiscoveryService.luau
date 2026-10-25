--!strict
-- DiscoveryService: the exploration album and map fog on the server (docs/21 §3, package B2).
--
-- Every 0.25 s it reads each player's character position (server-observed, never a client claim) and runs
-- DiscoveryRules.scan: sighting and reaching islands, walking up to an island's stamp post (the
-- WorldConfig.Islands stamp point; the post itself is built by the island module), and the collectibles
-- of DiscoveryConfig (bottles, telescope viewpoints, rare animals). Each sticker pays its one-time Cash
-- (flat, reason "Sticker:<kind>"), a completed page pays DiscoveryConfig.Cash.Page. Once a second it clears
-- the fog cells around the player. Profile flags "isles" and "fog" (DiscoveryRules encodings).
--
-- It places the placeholder collectibles in Workspace.Discovery (one Model per sticker, attributes Island
-- and Sticker); the client hides the ones a player has found. Remotes (under ReplicatedStorage.Net,
-- created here so shared/Net.luau needs no edit):
--   Discovery_State  S->C  { isles = encoded album, fog = encoded fog }
--   Discovery_Found  S->C  { island, sticker, kind, page } (the stamp slam / sticker pop)
--   Discovery_Get    C->S  function -> the same state (first pull)
-- Telemetry: Explore funnel Sighted / Reached / Stamped (+ stamp count), StickerFound, AlbumPage.
-- Studio: ServerStorage.DiscoveryDev:Invoke("reset") clears the first player's album and fog.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DataService = require(script.Parent.DataService)
local DiscoveryConfig = require(Shared:WaitForChild("Config"):WaitForChild("DiscoveryConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionService = require(script.Parent.ProgressionService)
local Rules = require(Shared:WaitForChild("DiscoveryRules"))
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
local WildlifeRig = require(Shared:WaitForChild("WildlifeRig"))

local DiscoveryService = {}
DiscoveryService.Priority = 67

local TICK = 0.25
local FOG_TICKS = 4

type Live = { state: Rules.State, fog: buffer }

local live: { [Player]: Live } = {}
local points: { [string]: { [string]: Vector3 } } = {}
local stateRemote: RemoteEvent? = nil
local foundRemote: RemoteEvent? = nil

local function payload(l: Live): any
	return {
		isles = Rules.encode(l.state),
		fog = Rules.encodeFog(l.fog),
	}
end

local function liveOf(player: Player): Live?
	local l = live[player]
	if l then
		return l
	end
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	l = {
		state = Rules.decode(data.flags.isles),
		fog = Rules.decodeFog(data.flags.fog),
	}
	live[player] = l
	return l
end

local function push(player: Player, l: Live)
	if stateRemote and player.Parent then
		stateRemote:FireClient(player, payload(l))
	end
end

-- the placeholder props ------------------------------------------------------------------------------

local function part(
	model: Model,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = model
	return p
end

local function bottle(model: Model, at: Vector3)
	local cf = CFrame.new(at + Vector3.new(0, 0.45, 0))
		* CFrame.Angles(0, math.rad(35), math.rad(80))
	local glass = part(
		model,
		Vector3.new(2.2, 0.9, 0.9),
		cf,
		Color3.fromRGB(90, 170, 120),
		Enum.Material.Glass
	)
	glass.Shape = Enum.PartType.Cylinder
	glass.Transparency = 0.35
	local neck = part(
		model,
		Vector3.new(0.8, 0.42, 0.42),
		cf * CFrame.new(1.4, 0, 0),
		Color3.fromRGB(90, 170, 120),
		Enum.Material.Glass
	)
	neck.Shape = Enum.PartType.Cylinder
	neck.Transparency = 0.35
	local cork = part(
		model,
		Vector3.new(0.3, 0.36, 0.36),
		cf * CFrame.new(1.9, 0, 0),
		Color3.fromRGB(160, 120, 80),
		Enum.Material.Wood
	)
	cork.Shape = Enum.PartType.Cylinder
	part(
		model,
		Vector3.new(1.4, 0.5, 0.5),
		cf,
		Color3.fromRGB(240, 228, 200),
		Enum.Material.SmoothPlastic
	)
	local glint = Instance.new("Sparkles")
	glint.SparkleColor = Color3.fromRGB(255, 250, 220)
	glint.Parent = glass
end

local function telescope(model: Model, at: Vector3)
	local brass = Color3.fromRGB(200, 160, 70)
	local base = CFrame.new(at)
	for i = 0, 2 do
		local a = math.rad(i * 120)
		local foot = base
			* CFrame.Angles(0, a, 0)
			* CFrame.new(0, 1.6, 0.7)
			* CFrame.Angles(math.rad(-20), 0, 0)
		part(
			model,
			Vector3.new(0.2, 3.4, 0.2),
			foot,
			Color3.fromRGB(70, 50, 35),
			Enum.Material.Wood
		)
	end
	local tube = part(
		model,
		Vector3.new(3.4, 0.5, 0.5),
		base * CFrame.new(0, 3.4, 0) * CFrame.Angles(0, 0, math.rad(12)),
		brass,
		Enum.Material.Metal
	)
	tube.Shape = Enum.PartType.Cylinder
	local lens = part(
		model,
		Vector3.new(0.6, 0.75, 0.75),
		tube.CFrame * CFrame.new(1.7, 0, 0),
		brass,
		Enum.Material.Metal
	)
	lens.Shape = Enum.PartType.Cylinder
end

local function critter(model: Model, at: Vector3, species: string?)
	local ok, rig = pcall(WildlifeRig.build, species or "SealPup", true)
	if ok and rig then
		for _, d in rig:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		local _, size = rig:GetBoundingBox()
		rig:PivotTo(CFrame.new(at + Vector3.new(0, size.Y / 2, 0)))
		rig.Parent = model
	else
		part(
			model,
			Vector3.new(2, 1.4, 3),
			CFrame.new(at + Vector3.new(0, 0.7, 0)),
			Color3.fromRGB(230, 230, 230),
			Enum.Material.SmoothPlastic
		)
	end
end

-- settles a point on the ground (terrain or a built island part), never below the sea
local function settle(at: Vector3, ignore: Instance): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), params)
	local y = if hit then hit.Position.Y else at.Y
	return Vector3.new(at.X, math.max(y, 0), at.Z)
end

local function placeProps()
	local folder = Instance.new("Folder")
	folder.Name = "Discovery"
	folder.Parent = Workspace
	for _, page in Rules.Pages do
		points[page.id] = {}
		for _, s in page.stickers do
			if s.kind == "Stamp" or s.kind == "Wreck" then
				continue -- the post is the island module's, the wreck is on the seabed (DiverRescue): no prop
			end
			local at = settle(s.point, folder)
			points[page.id][s.id] = at
			local model = Instance.new("Model")
			model.Name = `{page.id}_{s.id}`
			model:SetAttribute("Island", page.id)
			model:SetAttribute("Sticker", s.id)
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			if s.kind == "Bottle" then
				bottle(model, at)
			elseif s.kind == "View" then
				telescope(model, at)
			else
				critter(model, at, s.species)
			end
			model.Parent = folder
		end
	end
end

-- awarding ------------------------------------------------------------------------------------------

local function apply(player: Player, l: Live, events: { Rules.Event })
	for _, e in events do
		if e.step ~= "Sticker" then
			Telemetry.Explore(player, e.island, e.step)
			continue
		end
		local s = e.sticker :: Rules.Sticker
		if s.kind == "Stamp" then
			Telemetry.Explore(player, e.island, "Stamped", Rules.stamps(l.state))
		end
		Telemetry.Custom(player, "StickerFound", 1, e.island, s.kind, s.id)
		ProgressionService.Award(
			player,
			DiscoveryConfig.Cash[s.kind] or 0,
			`Sticker:{s.kind}`,
			true
		)
		if e.page then
			Telemetry.Custom(player, "AlbumPage", 1, e.island)
			ProgressionService.Award(player, DiscoveryConfig.Cash.Page, "Sticker:Page", true)
		end
		if foundRemote then
			foundRemote:FireClient(
				player,
				{ island = e.island, sticker = s.id, kind = s.kind, page = e.page == true }
			)
		end
	end
end

local function onFoot(character: Model, root: BasePart): boolean
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil
		and hum.Health > 0
		and not hum.Sit
		and hum.FloorMaterial ~= Enum.Material.Air
		and hum.FloorMaterial ~= Enum.Material.Water
		and root.Position.Y > 1
end

local function scanPlayer(player: Player, fogTick: boolean): nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (character and root and root:IsA("BasePart")) then
		return nil
	end
	local l = liveOf(player)
	if not l then
		return nil
	end
	local pos = root.Position
	local nextState, events = Rules.scan(l.state, pos, onFoot(character, root), points)
	local fogChanged = fogTick and Rules.reveal(l.fog, pos)
	if #events > 0 then
		l.state = nextState
		ProgressionService.SetFlag(player, "isles", Rules.encode(nextState))
		apply(player, l, events)
	end
	if fogChanged then
		ProgressionService.SetFlag(player, "fog", Rules.encodeFog(l.fog))
	end
	if #events > 0 or fogChanged then
		push(player, l)
	end
	return nil
end

function DiscoveryService.Init()
	local folder = Net.init()
	local function remote(className: string, name: string): Instance
		local r = folder:FindFirstChild(name)
		if not (r and r.ClassName == className) then
			r = Instance.new(className)
			assert(r, "unreachable")
			r.Name = name
			r.Parent = folder
		end
		return r :: Instance
	end
	stateRemote = remote("RemoteEvent", "Discovery_State") :: RemoteEvent
	foundRemote = remote("RemoteEvent", "Discovery_Found") :: RemoteEvent
	local get = remote("RemoteFunction", "Discovery_Get") :: RemoteFunction
	get.OnServerInvoke = function(player: Player)
		local l = liveOf(player)
		return if l then payload(l) else nil
	end

	DataService.OnLoaded(function(player: Player)
		live[player] = nil
		local l = liveOf(player)
		if l then
			push(player, l)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		live[player] = nil
	end)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "DiscoveryDev"
		dev.OnInvoke = function(cmd: string): any
			local player = Players:GetPlayers()[1]
			local l = player and liveOf(player)
			if not (player and l) then
				return nil
			end
			if cmd == "reset" then
				l.state = {}
				l.fog = Rules.newFog()
				ProgressionService.SetFlag(player, "isles", nil)
				ProgressionService.SetFlag(player, "fog", nil)
				push(player, l)
			end
			return payload(l)
		end
		dev.Parent = ServerStorage
	end
end

function DiscoveryService.Start()
	placeProps()
	local n = 0
	while true do
		task.wait(TICK)
		n += 1
		for _, player in Players:GetPlayers() do
			local ok, err = pcall(scanPlayer, player, n % FOG_TICKS == 0)
			if not ok then
				warn(`[DiscoveryService] {player.Name}: {err}`)
			end
		end
	end
end

return DiscoveryService
