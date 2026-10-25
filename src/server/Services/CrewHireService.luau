--!strict
-- CrewHireService (docs/23 (j), WP-15): the late-game crew. Job seekers line up outside the
-- owner's station (an R15 line via NpcFactory, everyone sees them) and are replaced by a new
-- group every 20 minutes (CrewHire.groupIndex on os.time). The client (CrewHireController)
-- draws the role glyph + skill stars billboard, the Hire / Close card and the clock above the
-- station door. Hiring goes through Crew_Hire (Cash + the dock Lv 5 / Coxswain gate); Crew_Fire
-- removes one. The daily wage is taken off data.cash when the profile loads (each session
-- starts), never below 0. Hired crew tween to their spot and idle there: Mechanic in the
-- boathouse, Lifeguard at the beach tower, Dispatcher seated in the station. The effects are
-- one-liners in VehicleService (Boat to me cooldown x0.7), AmbientRescueService (+1 swimmer) and
-- OperationService (offers x0.8). Everything is in-server only; nothing runs offline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CrewHire = require(Shared:WaitForChild("Crew"):WaitForChild("CrewHire"))
local Marina = require(Shared:WaitForChild("Marina"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))

local DataService = require(script.Parent.DataService)
local NpcFactory = require(script.Parent.Parent.Npc.NpcFactory)
local ProgressionService = require(script.Parent.ProgressionService)

local CrewHireService = {}

type State = {
	folder: Folder,
	group: number,
	lineGroup: number?,
	line: { Model },
	crew: { [string]: Model },
	building: { [string]: boolean }, -- role spawns still loading in the catalog
}

local folder: Folder? = nil
local states: { [Player]: State } = {}

-- the station (DockPieces ST): half depth 15, half width 26, height 16; -Z is the front with the door
local ST = { hd = 15 }
local LINE_BACK = 5 -- studs out from the station front wall
local WALK_SECONDS = 2.5

local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if folder then { folder } else {}
	local hit = Workspace:Raycast(at + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	return if hit then hit.Position else at
end

-- Feet CFrame at `at`, facing `toward` (level). Same as NpcService; a floorY picks an indoor
-- floor instead of the raycast (which would land on the roof of the station or boathouse).
local function stand(at: Vector3, toward: Vector3, floorY: number?): CFrame
	local p = if floorY then Vector3.new(at.X, floorY, at.Z) else ground(at)
	local look = Vector3.new(toward.X, p.Y, toward.Z)
	if (look - p).Magnitude < 0.1 then
		return CFrame.new(p)
	end
	return CFrame.lookAt(p, look)
end

local function stationFrame(b: CFrame): CFrame
	return b * Marina.LOTS.Station.cf
end

-- Where a hired role works (placeholder spots until art lands, CLAUDE.md).
local function crewSpot(b: CFrame, role: string): CFrame
	if role == "Mechanic" then
		-- in the boathouse, by the wall, facing the doors (the cove)
		local L = b * Marina.LOTS.Boathouse.cf
		local spot = L * CFrame.new(2, 0, 12)
		return stand(spot.Position, spot.Position - L.LookVector * 10, L.Position.Y + 0.2)
	elseif role == "Lifeguard" then
		-- at the beach tower lot, facing out to sea (away from the hub)
		local isle = b * Marina.ISLAND
		local spot = b * Marina.LOTS.LifeguardTower.cf * CFrame.new(0, 0, 1)
		return stand(spot.Position, isle.Position + isle.LookVector * 30)
	end
	-- Dispatcher: seated just inside the station, facing the door
	local s = stationFrame(b)
	local spot = s * CFrame.new(-6, 0, -(ST.hd - 3))
	return stand(spot.Position, spot.Position - s.LookVector * 10, s.Position.Y + 0.2)
end

-- The line outside the station front, one row centred on the door.
local function lineSpots(b: CFrame, n: number): { CFrame }
	local s = stationFrame(b)
	local out = {}
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 4.5
		local at = s * CFrame.new(x, 0, -(ST.hd + LINE_BACK))
		table.insert(out, stand(at.Position, s.Position))
	end
	return out
end

local function tagModel(model: Model, player: Player, role: string)
	model:SetAttribute("CrewOwner", player.UserId)
	model:SetAttribute("CrewRole", role)
end

-- Yields (catalog build); nil while the owner's state was cleared meanwhile.
local function spawnNpc(
	player: Player,
	st: State,
	role: string,
	stars: number,
	hired: boolean,
	at: CFrame
): Model?
	local seat = (role == "Dispatcher" and hired) or nil
	local model, height = NpcFactory.spawn("Crew", {
		name = `{(if hired then "Crew" else "Seeker")}_{player.UserId}_{role}`,
		pose = if seat then "Sit" else "Idle",
		seed = player.UserId * 31 + (table.find(CrewHire.Order, role) or 1) * 7 + if hired
			then 13
			else 0,
		cframe = at,
		parent = st.folder :: Instance?,
	})
	if states[player] ~= st then -- fired or left while the catalog loaded
		model:Destroy()
		return nil
	end
	tagModel(model, player, role)
	model:SetAttribute("CrewHeight", height) -- root centre above the feet, for the hire walk
	model:SetAttribute("CrewStars", stars)
	if hired then
		model:SetAttribute("CrewHired", true)
	else
		model:SetAttribute("CrewSeeker", true)
	end
	return model
end

local function buildLine(player: Player, st: State)
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return
	end
	local group = st.group
	local entries = CrewHire.lineup(player.UserId, group)
	local spots = lineSpots(bay :: CFrame, #entries)
	task.spawn(function()
		for i, entry in entries do
			if states[player] ~= st or st.group ~= group then
				return -- cleared or rotated while the catalog loaded
			end
			local model = spawnNpc(player, st, entry.role, entry.stars, false, spots[i])
			if model then
				table.insert(st.line, model)
			end
		end
	end)
end

local function buildCrew(player: Player, st: State, role: string)
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" or st.building[role] then
		return
	end
	st.building[role] = true
	task.spawn(function()
		local model = spawnNpc(player, st, role, 0, true, crewSpot(bay :: CFrame, role))
		if model then
			st.crew[role] = model
		end
		st.building[role] = false
	end)
end

-- The hire walk: a straight tween of the model's pivot to the role spot (simple, docs/23 (j)).
local POSES = { Sit = "rbxassetid://2506281703" }

-- Same as NpcFactory.playPose (kept local): the Dispatcher sits once she reaches the station.
local function playPose(model: Model, pose: string)
	local id = POSES[pose]
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (id and hum) then
		return
	end
	local animator: Animator? = hum:FindFirstChildOfClass("Animator")
	if not animator then
		local a = Instance.new("Animator")
		a.Parent = hum
		animator = a
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	for _, track in (animator :: Animator):GetPlayingAnimationTracks() do
		track:Stop(0.2) -- the walk-in idle stops, the seat pose takes over
	end
	pcall(function()
		local track = (animator :: Animator):LoadAnimation(anim)
		track.Looped = true
		track:Play(0.2)
	end)
end

-- A trust boundary: the card is only shown next to the NPC, so hiring / firing from far away is
-- not a real player action.
local function near(player: Player, at: Vector3): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	return root ~= nil and root:IsA("BasePart") and (root.Position - at).Magnitude <= 18
end

local function walkTo(model: Model, spot: CFrame, pose: string?)
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		model:PivotTo(spot)
		return
	end
	local height = model:GetAttribute("CrewHeight")
	local target = spot * CFrame.new(0, if type(height) == "number" then height else 3, 0)
	local tween = TweenService:Create(
		root,
		TweenInfo.new(WALK_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ CFrame = target }
	)
	if pose then
		tween.Completed:Connect(function()
			playPose(model, pose)
		end)
	end
	tween:Play()
end

local function hire(player: Player, role: string): (boolean, string)
	local data = DataService.Get(player)
	if not data then
		return false, "Loading"
	end
	if not CrewHire.unlocked(data.dockLevel, ProgressionRules.rankIndex(data)) then
		return false, "Locked"
	end
	local st = states[player]
	if not st then
		return false, "Locked"
	end
	local seeker: Model? = nil
	for _, model in st.line do
		if model:GetAttribute("CrewRole") == role then
			seeker = model
			break
		end
	end
	if not seeker then
		return false, "Gone" -- the group rotated; the next line will have one
	end
	if not near(player, (seeker :: Model):GetPivot().Position) then
		return false, "Far"
	end
	local ok, reason = CrewHire.canHire(role, data.crew, data.cash)
	if not ok then
		return false, reason
	end
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return false, "NoPlot"
	end
	data.cash -= CrewHire.Roles[role].price
	data.crew[role] = true
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	task.spawn(DataService.Save, player, false)
	local i = table.find(st.line, seeker :: Model)
	if i then
		table.remove(st.line, i)
	end
	seeker:SetAttribute("CrewSeeker", nil)
	seeker:SetAttribute("CrewHired", true)
	st.crew[role] = seeker :: Model
	walkTo(
		seeker :: Model,
		crewSpot(bay :: CFrame, role),
		if role == "Dispatcher" then "Sit" else nil
	)
	return true, "ok"
end

local function fire(player: Player, role: string): (boolean, string)
	local data = DataService.Get(player)
	if not data or data.crew[role] ~= true then
		return false, "None"
	end
	local st = states[player]
	local model = st and st.crew[role]
	if model and not near(player, model:GetPivot().Position) then
		return false, "Far"
	end
	if st then
		st.crew[role] = nil
	end
	data.crew[role] = nil
	DataService.MarkDirty(player)
	ProgressionService.Refresh(player)
	task.spawn(DataService.Save, player, false)
	if model then
		model:Destroy()
	end
	return true, "ok"
end

local function clearState(player: Player)
	local st = states[player]
	states[player] = nil
	if st then
		st.folder:Destroy()
	end
end

-- The 5-second heartbeat: unlocks on dock level 5 + rank, rotates the line every 20 minutes,
-- and keeps the hired crew in the world while the owner is in the server.
local function sync(player: Player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	player:SetAttribute("CrewMechanic", data.crew.Mechanic == true) -- the client's Boat to me ring
	if not CrewHire.unlocked(data.dockLevel, ProgressionRules.rankIndex(data)) then
		clearState(player)
		return
	end
	local st = states[player]
	if not st then
		local f = Instance.new("Folder")
		f.Name = tostring(player.UserId)
		f.Parent = folder
		st = { folder = f, group = -1, line = {}, crew = {}, building = {} }
		states[player] = st
	end
	local group = CrewHire.groupIndex(os.time())
	if group ~= st.group then
		st.group = group
		for _, model in st.line do
			model:Destroy()
		end
		st.line = {}
		st.lineGroup = nil
	end
	-- the line waits for the island (BayCFrame) when the profile loads first
	if st.lineGroup ~= group and typeof(player:GetAttribute("BayCFrame")) == "CFrame" then
		st.lineGroup = group
		buildLine(player, st)
	end
	for role, yes in data.crew do
		if yes and not st.crew[role] then
			buildCrew(player, st, role)
		end
	end
	for role, model in st.crew do
		if not data.crew[role] then
			model:Destroy()
			st.crew[role] = nil
		end
	end
end

-- The three effect hooks (docs/23 (j)); read the live profile, nothing persists offline.
function CrewHireService.HasRole(player: Player, role: string): boolean
	local data = DataService.Get(player)
	return data ~= nil and data.crew[role] == true
end

function CrewHireService.MechanicCooldown(player: Player): number
	return if CrewHireService.HasRole(player, "Mechanic") then CrewHire.MechanicCooldown else 1
end

function CrewHireService.OfferFactor(player: Player): number
	return if CrewHireService.HasRole(player, "Dispatcher") then CrewHire.DispatchFactor else 1
end

function CrewHireService.ExtraSwimmers(player: Player): number
	return if CrewHireService.HasRole(player, "Lifeguard") then CrewHire.LifeguardSwimmers else 0
end

function CrewHireService.Init()
	local f = Instance.new("Folder")
	f.Name = "CrewHire"
	f.Parent = Workspace
	folder = f

	Players.PlayerRemoving:Connect(clearState)

	local folderNet = Net.init()
	local hireRemote = Instance.new("RemoteFunction")
	hireRemote.Name = "Crew_Hire"
	hireRemote.OnServerInvoke = function(player: Player, role: any): (boolean, string)
		if type(role) ~= "string" then
			return false, "Unknown"
		end
		return hire(player, role)
	end
	hireRemote.Parent = folderNet

	local fireRemote = Instance.new("RemoteFunction")
	fireRemote.Name = "Crew_Fire"
	fireRemote.OnServerInvoke = function(player: Player, role: any): (boolean, string)
		if type(role) ~= "string" then
			return false, "Unknown"
		end
		return fire(player, role)
	end
	fireRemote.Parent = folderNet

	DataService.OnLoaded(function(player: Player, data: ProgressionRules.PlayerData)
		-- the daily wage comes off at the start of each session, never below 0 (docs/23 (j))
		local wage = CrewHire.dailyWage(data.crew)
		if wage > 0 then
			data.cash = math.max(0, data.cash - wage)
			DataService.MarkDirty(player)
			ProgressionService.Refresh(player)
		end
		sync(player)
	end)
end

function CrewHireService.Start()
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				sync(player)
			end
			task.wait(5)
		end
	end)
end

return CrewHireService
