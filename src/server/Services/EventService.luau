--!strict
-- EventService: the server-clock events every server shares (docs/15 H1).
--   Great Storm   every hour at :00 UTC: ForceStorm(true) starts a 120 s warning two minutes
--                 before, so the sky darkens, the flags snap and the siren sounds; the storm is
--                 the 240 s Great Storm phase. Rep is x2 then (player attribute EventGreatStorm).
--   Ghost Light   every 3 hours at :30 UTC for 10 minutes: night fog on the client and a normal
--                 Disabled Vessel call in Calm Bay with a lantern on its bow. Joining mid-event
--                 joins it (the loop starts a call for every free player).
-- The clock event wins over the paid storm queue: Weather.ClockEventSoon makes StormService's
-- queue wait; a summon already running is upgraded into the Great Storm.
-- Replicated state: ReplicatedStorage.EventState attributes Event, Phase ("Before" | "Active" |
-- ""), StartAt, EndsAt, Now (UTC epoch seconds), Offset (dev fast-forward, seconds).
-- Studio fast-forward: Workspace:SetAttribute("EventClockOffset", seconds).
-- API: EventService.IsEventActive("GreatStorm") -> boolean (rare calls / the Rescue Album hook).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventClock = require(Shared:WaitForChild("EventClock"))
local OperationService = require(script.Parent:WaitForChild("OperationService"))
local StormService = require(script.Parent:WaitForChild("StormService"))

local TICK_SECONDS = 0.5
local FOLDER_NAME = "EventState"

local EventService = {}
EventService.Priority = 25

local folder: Folder
local weatherFolder: Folder
local stormStart = 0 -- the occurrence of Great Storm already forced into StormService
local ghostStart = 0 -- the occurrence of Ghost Light already started
local ghostStarted: { [Player]: string } = {} -- player -> op id (one ghost call per event)
local lanterns: { [string]: Model } = {} -- op id -> lantern model

local function offset(): number
	local value = Workspace:GetAttribute("EventClockOffset")
	return if type(value) == "number"
			and (RunService:IsStudio() or Workspace:GetAttribute("DevBoard"))
		then value
		else 0
end

local function now(): number
	return os.time() + offset()
end

-- LiveOps (G60): the replicated schedule; Active means the event is on right now.
local function liveOpsActive(id: string): boolean
	local live = ReplicatedStorage:FindFirstChild("LiveOpsState")
	return live ~= nil
		and live:GetAttribute("Event") == id
		and live:GetAttribute("Phase") == "Active"
end

function EventService.IsEventActive(id: string): boolean
	-- LegendaryRush rolls the rare calls as if a Great Storm were on (LiveOpsService).
	if id == "GreatStorm" and liveOpsActive("LegendaryRush") then
		return true
	end
	return EventClock.isActive(id, now())
end

local function findBoat(opId: string): Model?
	local props = Workspace:FindFirstChild("CallProps")
	if not props then
		return nil
	end
	for _, child in props:GetChildren() do
		if
			child:IsA("Model")
			and child.Name == "DisabledBoat"
			and child:GetAttribute("CallId") == opId
		then
			return child
		end
	end
	return nil
end

local function makeLantern(opId: string)
	local model = Instance.new("Model")
	model.Name = "GhostLantern"
	local pole = Instance.new("Part")
	pole.Name = "Pole"
	pole.Anchored = true
	pole.CanCollide = false
	pole.CanQuery = false
	pole.CanTouch = false
	pole.Size = Vector3.new(0.18, 3, 0.18)
	pole.Color = Color3.fromRGB(60, 48, 36)
	pole.Material = Enum.Material.Wood
	pole.CFrame = CFrame.new(0, 1.5, 0)
	pole.Parent = model
	local lamp = Instance.new("Part")
	lamp.Name = "Lamp"
	lamp.Shape = Enum.PartType.Ball
	lamp.Anchored = true
	lamp.CanCollide = false
	lamp.CanQuery = false
	lamp.CanTouch = false
	lamp.Size = Vector3.new(0.6, 0.6, 0.6)
	lamp.Color = Color3.fromRGB(255, 198, 110)
	lamp.Material = Enum.Material.Neon
	lamp.CFrame = CFrame.new(0, 3.2, 0)
	lamp.Parent = model
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 190, 100)
	light.Brightness = 2.5
	light.Range = 26
	light.Shadows = false
	light.Parent = lamp
	model.PrimaryPart = pole
	model.Parent = Workspace
	lanterns[opId] = model
end

local function clearLanterns()
	for opId, model in lanterns do
		model:Destroy()
		lanterns[opId] = nil
	end
end

local function tryGhost(player: Player)
	if ghostStarted[player] then
		return
	end
	if player:GetAttribute("ColdOpenDone") ~= true or player:GetAttribute("OffDuty") == true then
		return
	end
	if OperationService.GetOperationOf(player) then
		return
	end
	-- offer only: the player accepts the ghost call as usual (no forced activation)
	local ok, opId = pcall(OperationService.OfferCall, player, "DisabledVessel")
	if ok and type(opId) == "string" then
		ghostStarted[player] = opId
	end
end

local function updateLanterns()
	-- the lantern appears once the accepted call has spawned its boat
	for _, opId in ghostStarted do
		if not lanterns[opId] and findBoat(opId) then
			makeLantern(opId)
		end
	end
	for opId, model in lanterns do
		local boat = findBoat(opId)
		local hull = boat and boat.PrimaryPart
		if hull and hull.Parent then
			model:PivotTo(hull.CFrame * CFrame.new(0, 2.4, -5.6))
		else
			model:Destroy()
			lanterns[opId] = nil
		end
	end
end

local function applyRep(player: Player, great: boolean)
	player:SetAttribute("EventGreatStorm", if great then true else nil)
end

local function publish(id: string, phase: string, current: EventClock.Current?, t: number)
	folder:SetAttribute("Event", id)
	folder:SetAttribute("Phase", phase)
	folder:SetAttribute("StartAt", if current then current.startAt else 0)
	folder:SetAttribute("EndsAt", if current then current.endsAt else 0)
	folder:SetAttribute("Now", t)
	folder:SetAttribute("Offset", offset())
	weatherFolder:SetAttribute("ClockEventSoon", id == "GreatStorm" and phase ~= "")
	local great = id == "GreatStorm" and phase == "Active"
	for _, player in Players:GetPlayers() do
		applyRep(player, great)
	end
end

local function tick()
	local t = now()
	local current = EventClock.current(t)
	local id = if current then current.id else ""
	local phase = if current then current.phase else ""
	publish(id, phase, current, t)

	-- a new player's cold open holds the storm back (bounded: OperationService.ColdOpenHoldsWeather);
	-- LiveOps CalmSeas holds every new storm for its hour (LiveOpsService also clears a running one)
	if
		id == "GreatStorm"
		and not OperationService.ColdOpenHoldsWeather()
		and not liveOpsActive("CalmSeas")
	then
		if phase == "Before" and current and current.startAt ~= stormStart then
			stormStart = current.startAt
			StormService.ForceStorm(true, false, math.max(1, current.startAt - t))
		elseif
			phase == "Active"
			and (
				weatherFolder:GetAttribute("State") ~= "Storm"
				or weatherFolder:GetAttribute("IsGreatStorm") ~= true
			)
		then
			StormService.ForceStorm(true, true) -- joined mid-event or a plain storm: make it Great
		end
	elseif id ~= "GreatStorm" then
		stormStart = 0
	end

	if id == "GhostLight" and phase == "Active" and current then
		if ghostStart ~= current.startAt then
			ghostStart = current.startAt
			ghostStarted = {}
			clearLanterns()
		end
		for _, player in Players:GetPlayers() do
			tryGhost(player)
		end
	else
		ghostStart = 0
		if next(lanterns) then
			ghostStarted = {}
			clearLanterns()
		end
	end
end

function EventService.Init()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	folder:SetAttribute("Event", "")
	folder:SetAttribute("Phase", "")
	folder:SetAttribute("StartAt", 0)
	folder:SetAttribute("EndsAt", 0)
	folder:SetAttribute("Now", os.time())
	folder:SetAttribute("Offset", 0)
	weatherFolder = assert(
		ReplicatedStorage:FindFirstChild("Weather") :: Folder,
		"StormService must create ReplicatedStorage.Weather first"
	)
	Players.PlayerAdded:Connect(function(player: Player)
		applyRep(
			player,
			folder:GetAttribute("Event") == "GreatStorm"
				and folder:GetAttribute("Phase") == "Active"
		)
		if ghostStart ~= 0 then
			-- joining mid-event joins it; the cold open still finishes first
			task.delay(3, function()
				if player.Parent and ghostStart ~= 0 then
					tryGhost(player)
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		ghostStarted[player] = nil
	end)
end

function EventService.Start()
	RunService.Heartbeat:Connect(updateLanterns)
	while true do
		tick()
		task.wait(TICK_SECONDS)
	end
end

return EventService
