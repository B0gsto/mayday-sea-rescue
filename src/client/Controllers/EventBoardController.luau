--!strict
-- EventBoardController: feeds the phone's Events page (docs/15 section 2). Pulls the station and
-- streak views so a player's own crate and strongbox appear, and pushes the pure EventCalendar rows
-- once a second. Times use EventState's server Now, so every server agrees. (The harbour world
-- board was removed in a playtest round: timers live in the phone only.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventCalendar = require(Shared:WaitForChild("EventCalendar"))

local Phone = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Phone"))

local EventBoardController = {}
EventBoardController.Priority = 84

type StationState = {
	cash: number,
	rate: number,
	capCash: number,
	level: number,
	radio: number,
	kennel: number,
}

local eventFolder: Folder? = nil
local station: StationState? = nil
local stationAnchoredAt = 0
local streakAvailable = false
local stationGet: RemoteFunction? = nil
local streakGet: RemoteFunction? = nil

local function now(): number
	local folder = eventFolder
	if folder then
		local value = folder:GetAttribute("Now")
		if type(value) == "number" and value > 0 then
			return value
		end
	end
	return os.time()
end

-- The station view is anchored at the server's Cash; between pushes the phone lets it fill at the
-- same rate, the way the strongbox itself does (IdleIncome then turns it into fill and clock).
local function stationView(): EventCalendar.StationView?
	local state = station
	if not state then
		return nil
	end
	local cash = state.cash
	if state.rate > 0 then
		cash += state.rate * math.max(0, os.clock() - stationAnchoredAt) / 3600
	end
	return {
		cash = math.clamp(cash, 0, state.capCash),
		level = state.level,
		radio = state.radio,
		kennel = state.kennel,
	}
end

local function applyStation(view: any)
	if type(view) ~= "table" then
		return
	end
	station = {
		cash = tonumber(view.cash) or 0,
		rate = math.max(0, tonumber(view.rate) or 0),
		capCash = math.max(0, tonumber(view.capCash) or 0),
		level = math.max(0, math.floor(tonumber(view.level) or 0)),
		radio = math.max(0, math.floor(tonumber(view.radio) or 0)),
		kennel = math.max(0, math.floor(tonumber(view.kennel) or 0)),
	}
	stationAnchoredAt = os.clock()
end

local function applyStreak(view: any)
	if type(view) == "table" then
		streakAvailable = view.available == true
	end
end

-- LiveOps (G60): the owner-scheduled event row, from the replicated LiveOpsState attributes.
local function liveOpsView(): EventCalendar.LiveOpsView?
	local folder = ReplicatedStorage:FindFirstChild("LiveOpsState")
	if not folder then
		return nil
	end
	local event = folder:GetAttribute("Event")
	local startsAt = folder:GetAttribute("StartsAt")
	local endsAt = folder:GetAttribute("EndsAt")
	if
		type(event) ~= "string"
		or event == ""
		or type(startsAt) ~= "number"
		or type(endsAt) ~= "number"
	then
		return nil
	end
	return { event = event, startsAt = startsAt, endsAt = endsAt }
end

local function draw()
	if not eventFolder then
		eventFolder = ReplicatedStorage:FindFirstChild("EventState")
	end
	local rows = EventCalendar.rows(now(), {
		streak = { available = streakAvailable },
		station = stationView(),
		halloweenForced = Workspace:GetAttribute("SeasonalEventForce") == true,
		liveOps = liveOpsView(),
		stormOff = eventFolder ~= nil and eventFolder:GetAttribute("StormOff") == true,
	})
	Phone.setEventRows(rows)
end

function EventBoardController.Start()
	eventFolder = ReplicatedStorage:FindFirstChild("EventState")

	local net = ReplicatedStorage:WaitForChild("Net", 30)
	if net then
		local push = net:FindFirstChild("Station_State")
		if push and push:IsA("RemoteEvent") then
			push.OnClientEvent:Connect(applyStation)
		end
		local get = net:FindFirstChild("Station_Get")
		if get and get:IsA("RemoteFunction") then
			stationGet = get
		end
		local streakState = net:FindFirstChild("Streak_State")
		if streakState and streakState:IsA("RemoteEvent") then
			streakState.OnClientEvent:Connect(applyStreak)
		end
		local getStreak = net:FindFirstChild("Streak_Get")
		if getStreak and getStreak:IsA("RemoteFunction") then
			streakGet = getStreak
		end
	end

	task.spawn(function()
		local get = stationGet
		if get then
			local ok, view = pcall(function()
				return get:InvokeServer()
			end)
			if ok then
				applyStation(view)
			end
		end
		local sget = streakGet
		if sget then
			local ok, view = pcall(function()
				return sget:InvokeServer()
			end)
			if ok then
				applyStreak(view)
			end
		end
	end)

	while true do
		draw()
		task.wait(1)
	end
end

return EventBoardController
