--!strict
-- LiveOpsService: owner-triggered live events across every server at once (docs/15 section 1;
-- marketing/liveops.md). The owner tool publishes one MessagingService message on topic "LiveOps"
-- and writes the MemoryStore sorted map "LiveOpsActive", so servers that boot mid-event adopt it.
--
-- This service owns only the schedule. The effects read the replicated state:
--   GoldenHour      ProgressionService.Award multiplies Cash and Rep (flat awards stay flat)
--   CalmSeas        StormService holds new storms (LiveOpsService also clears a running one)
--
-- Message: { event, startsAt (UTC epoch s), duration (s), nonce }; "Cancel" clears it. Ignore
-- duplicates/old nonces, unknown events, > 7 days ahead, > 3 h, and finished events.
-- Replicated state: ReplicatedStorage.LiveOpsState attributes Event, Phase ("Pending" | "Active" |
-- ""), StartsAt, EndsAt, Duration, Now. Studio: ServerStorage.LiveOpsDev "schedule" event startsAt
-- duration / "cancel" / "state" (no real publish needed).

local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LiveOps = require(Shared:WaitForChild("LiveOps"))

local FOLDER_NAME = "LiveOpsState"
local TICK = 1
local SUBSCRIBE_BACKOFF = 30
local SEEN_MAX = 64

local LiveOpsService = {}
LiveOpsService.Priority = 26 -- the folder exists before any Start loop

local folder: Folder
local state: LiveOps.State = LiveOps.empty()
local seen: { [string]: boolean } = {}
local seenOrder: { string } = {}
local lastPhase: LiveOps.Phase = "Idle"

function LiveOpsService.GetState(): LiveOps.State
	return state
end

function LiveOpsService.IsActive(id: string): boolean
	return LiveOps.isActive(state, id, os.time())
end

function LiveOpsService.Multipliers(): LiveOps.Multipliers
	return LiveOps.multipliers(state, os.time())
end

local function remember(nonce: string)
	if seen[nonce] then
		return false
	end
	seen[nonce] = true
	table.insert(seenOrder, nonce)
	while #seenOrder > SEEN_MAX do
		seen[table.remove(seenOrder, 1) :: string] = nil
	end
	return true
end

local function clearStorms()
	local module = script.Parent:FindFirstChild("StormService")
	if not module then
		return
	end
	local ok, storm = pcall(require, module :: ModuleScript)
	if ok and type(storm) == "table" and type((storm :: any).ForceCalm) == "function" then
		pcall((storm :: any).ForceCalm)
	end
end

-- Adopt one validated message. Returns true when the schedule changed.
function LiveOpsService.Adopt(message: any): boolean
	local t = os.time()
	local ok, reason = LiveOps.validate(message, t)
	if not ok then
		warn(`[LiveOpsService] ignored message ({reason})`)
		return false
	end
	local nonce = (message :: any).nonce :: string
	if not remember(nonce) then
		return false -- duplicate nonce
	end
	if reason == "cancel" then
		state = LiveOps.empty()
		lastPhase = "Idle"
		return true
	end
	if not LiveOps.supersedes(state, message, t) then
		return false -- an older schedule arriving late
	end
	state = LiveOps.fromMessage(message)
	lastPhase = LiveOps.phase(state, t)
	return true
end

local function publish(t: number, phase: LiveOps.Phase)
	folder:SetAttribute("Event", state.event)
	folder:SetAttribute("Phase", if state.event == "" then "" else phase)
	folder:SetAttribute("StartsAt", state.startsAt)
	folder:SetAttribute("EndsAt", if state.event == "" then 0 else LiveOps.endsAt(state))
	folder:SetAttribute("Duration", state.duration)
	folder:SetAttribute("Now", t)
end

local function tick()
	local t = os.time()
	local phase: LiveOps.Phase = LiveOps.phase(state, t)
	if phase ~= lastPhase then
		if phase == "Active" and state.event == "CalmSeas" then
			clearStorms() -- the relaxed hour starts now, even if a storm was rolling
		end
		lastPhase = phase
	end
	if phase == "Idle" and state.event ~= "" then
		state = LiveOps.empty()
	end
	publish(t, phase)
end

local function readActive(): any
	if RunService:IsStudio() then
		return nil -- Studio has no MemoryStore; LiveOpsDev drives the check instead
	end
	local ok, value = pcall(function()
		return MemoryStoreService:GetSortedMap(LiveOps.Map):GetAsync(LiveOps.Key)
	end)
	if not ok or type(value) ~= "string" then
		return nil
	end
	local fine, message = pcall(HttpService.JSONDecode, HttpService, value)
	return if fine then message else nil
end

local function onMessage(raw: any)
	if type(raw) ~= "string" then
		return
	end
	local ok, message = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok or type(message) ~= "table" then
		warn("[LiveOpsService] bad message shape")
		return
	end
	LiveOpsService.Adopt(message)
end

-- SubscribeAsync can fail (service hiccup): retry with backoff, never take the server down.
local function subscribe()
	local wait = 2
	while true do
		local ok, result = pcall(function()
			return MessagingService:SubscribeAsync(LiveOps.Topic, onMessage)
		end)
		if ok and typeof(result) == "RBXScriptConnection" then
			LiveOpsService.Subscription = result
			return
		end
		warn(
			`[LiveOpsService] subscribe failed: {if ok then "no connection" else tostring(result)}`
		)
		task.wait(wait)
		wait = math.min(wait * 2, SUBSCRIBE_BACKOFF)
	end
end

local function setupDev()
	if not RunService:IsStudio() then
		return
	end
	local dev = Instance.new("BindableFunction")
	dev.Name = "LiveOpsDev"
	dev.OnInvoke = function(cmd: string, a: any, b: any, c: any): any
		if cmd == "schedule" then
			local changed = LiveOpsService.Adopt({
				event = tostring(a),
				startsAt = tonumber(b) or 0,
				duration = tonumber(c) or 0,
				nonce = `dev{os.time()}{math.random(1000, 9999)}`,
			})
			return changed
		elseif cmd == "cancel" then
			return LiveOpsService.Adopt({ event = "Cancel", nonce = `cancel{os.time()}` })
		elseif cmd == "state" then
			return {
				event = state.event,
				phase = LiveOps.phase(state, os.time()),
				startsAt = state.startsAt,
				endsAt = LiveOps.endsAt(state),
				now = os.time(),
			}
		end
		return nil
	end
	dev.Parent = ServerStorage
end

function LiveOpsService.Init()
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
	end
	folder:SetAttribute("Event", "")
	folder:SetAttribute("Phase", "")
	folder:SetAttribute("StartsAt", 0)
	folder:SetAttribute("EndsAt", 0)
	folder:SetAttribute("Duration", 0)
	folder:SetAttribute("Now", os.time())
	folder.Parent = ReplicatedStorage
	setupDev()
end

function LiveOpsService.Start()
	local boot = readActive()
	if boot ~= nil then
		LiveOpsService.Adopt(boot) -- a server booting mid-event joins it
	end
	task.spawn(subscribe)
	while true do
		tick()
		task.wait(TICK)
	end
end

return LiveOpsService
