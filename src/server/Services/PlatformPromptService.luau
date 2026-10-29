--!strict
-- PlatformPromptService: Roblox's own re-engagement prompts, offered once at a good moment
-- (docs/15 hooks). The client asks after a trigger (first crate open, first island building, first
-- crew rescue); this service holds the request until PlatformPrompts allows it (3 min into the
-- session, not on an operation, 10 min since the last prompt) and only then tells the client to
-- show Roblox's prompt. Asked timestamps persist in data.flags.platformPrompts.
--
-- Remotes (own events under ReplicatedStorage.Net):
--   PlatformPrompt_Ask    C->S  kind: "notify" | "favorite" | "invite"
--   PlatformPrompt_Offer  S->C  the same kind, once the timing policy allows it
-- Studio: Workspace attribute PlatformPromptForce (true) skips the session, gap and operation
-- gates; the trigger checks still run unless forced too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local PlatformPrompts = require(Shared:WaitForChild("PlatformPrompts"))

local DataService = require(script.Parent.DataService)
local OperationService = require(script.Parent.OperationService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local PlatformPromptService = {}
PlatformPromptService.Priority = 85

local FLAG = "platformPrompts"
local CHECK_SECONDS = 5

local pending: { [Player]: { PlatformPrompts.Kind } } = {}
local sessionStart: { [Player]: number } = {}
local offerRemote: RemoteEvent? = nil

local function forceOn(): boolean
	return RunService:IsStudio() and Workspace:GetAttribute("PlatformPromptForce") == true
end

local function onOp(player: Player): boolean
	if forceOn() then
		return false
	end
	return OperationService.GetOperationOf(player) ~= nil
end

-- The trigger the client says it saw, checked against what the server already published.
local function triggered(player: Player, kind: PlatformPrompts.Kind): boolean
	if forceOn() then
		return true
	end
	if kind == "notify" then -- after a rescue debrief (owner 2026-10-28): someone delivered home at least once
		local data: any = DataService.Get(player)
		return data ~= nil and (tonumber(data.totalRescues) or 0) >= 1
	elseif kind == "favorite" then
		local data: any = DataService.Get(player) -- after the first island building (the start's jetty doesn't count)
		if data == nil or type(data.dockBuildings) ~= "table" then
			return false
		end
		for key in data.dockBuildings do
			if key ~= "Harbour" then
				return true
			end
		end
		return false
	elseif kind == "invite" then
		return player:GetAttribute("CrewOpDone") == true
	end
	return false
end

local function stateOf(player: Player): PlatformPrompts.State?
	local data = DataService.Get(player)
	if not data or type(data.flags) ~= "table" then
		return nil
	end
	return PlatformPrompts.decode(data.flags[FLAG])
end

local function offer(player: Player, kind: PlatformPrompts.Kind, state: PlatformPrompts.State)
	local now = os.time()
	local nextState = PlatformPrompts.record(state, kind, now)
	if not ProgressionService.SetFlag(player, FLAG, PlatformPrompts.encode(nextState)) then
		return
	end
	local remote = offerRemote
	if remote and player.Parent then
		Telemetry.Custom(player, "PromptShown", 1, kind)
		remote:FireClient(player, kind)
	end
end

local function tick()
	local now = os.time()
	local forced = forceOn()
	for player, queue in pending do
		local state = stateOf(player)
		if not state then
			continue
		end
		local sinceSession = if forced
			then PlatformPrompts.MIN_SESSION
			else now - (sessionStart[player] or now)
		local busy = onOp(player)
		for i = #queue, 1, -1 do
			local kind: PlatformPrompts.Kind = queue[i]
			local ok, reason = PlatformPrompts.allowed(kind, state, now, sinceSession, busy)
			if ok then
				table.remove(queue, i)
				offer(player, kind, state)
				state = stateOf(player) or state
			elseif reason == "asked" then
				table.remove(queue, i) -- once-ever prompt already used: never wait on it again
			end
		end
		if #queue == 0 then
			pending[player] = nil
		end
	end
end

function PlatformPromptService.Init()
	local folder = Net.init()
	local ask = folder:FindFirstChild("PlatformPrompt_Ask")
	if not (ask and ask:IsA("RemoteEvent")) then
		local created = Instance.new("RemoteEvent")
		created.Name = "PlatformPrompt_Ask"
		created.Parent = folder
		ask = created
	end
	local offerEvent = folder:FindFirstChild("PlatformPrompt_Offer")
	if not (offerEvent and offerEvent:IsA("RemoteEvent")) then
		local created = Instance.new("RemoteEvent")
		created.Name = "PlatformPrompt_Offer"
		created.Parent = folder
		offerEvent = created
	end
	offerRemote = offerEvent :: RemoteEvent
	local optIn = folder:FindFirstChild("PlatformPrompt_OptIn")
	if not (optIn and optIn:IsA("RemoteEvent")) then
		local created = Instance.new("RemoteEvent")
		created.Name = "PlatformPrompt_OptIn"
		created.Parent = folder
		optIn = created
	end
	-- The engine has no accept/decline result (PromptOptIn returns nil), so the client reports the
	-- prompt closing; Roblox itself only delivers to players who really opted in.
	local optInEvent = optIn :: RemoteEvent
	optInEvent.OnServerEvent:Connect(function(player: Player)
		local state = stateOf(player)
		if state and state.notify then
			ProgressionService.SetFlag(player, "notifyOptIn", true)
		end
	end)

	local askEvent = ask :: RemoteEvent
	askEvent.OnServerEvent:Connect(function(player: Player, kind: any)
		if not PlatformPrompts.isKind(kind) then
			return
		end
		if not triggered(player, kind) then
			return
		end
		local queue: { PlatformPrompts.Kind } = pending[player] or {}
		pending[player] = queue
		if table.find(queue, kind) == nil then
			table.insert(queue, kind)
		end
	end)

	local function joined(player: Player)
		sessionStart[player] = os.time()
	end
	for _, player in Players:GetPlayers() do
		joined(player)
	end
	Players.PlayerAdded:Connect(joined)
	Players.PlayerRemoving:Connect(function(player: Player)
		sessionStart[player] = nil
		pending[player] = nil
	end)

	-- The first completed rescue with another player aboard is the invite moment (docs/15 H9).
	OperationService.OperationCompleted:Connect(function(_info: any, helpers: { Player })
		if #helpers < 2 then
			return
		end
		for _, player in helpers do
			if player:GetAttribute("CrewOpDone") ~= true then
				player:SetAttribute("CrewOpDone", true)
			end
		end
	end)
end

function PlatformPromptService.Start()
	task.spawn(function()
		while true do
			task.wait(CHECK_SECONDS)
			tick()
		end
	end)
end

return PlatformPromptService
