--!strict
-- EventBoardController: feeds the phone's Events page (docs/15 section 2). Pulls the streak view
-- so a player's own crate appears, and pushes the pure EventCalendar rows once a second. Times use EventState's server Now, so every server agrees. (The harbour world
-- board was removed in a playtest round: timers live in the phone only.)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EventCalendar = require(Shared:WaitForChild("EventCalendar"))

local Phone = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("Phone"))

local EventBoardController = {}
EventBoardController.Priority = 84

local eventFolder: Folder? = nil
local streakAvailable = false
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
