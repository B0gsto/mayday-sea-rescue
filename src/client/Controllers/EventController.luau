--!strict
-- EventController: the client side of the server-clock events (docs/15 H1). Reads
-- ReplicatedStorage.EventState (EventService): the Great Storm's harbour siren. The clocks are rows in the phone's Events app (EventCalendar), not HUD chips. Late joiners read the same attributes, so they join
-- the event in progress.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioController = require(script.Parent:WaitForChild("AudioController"))

local TICK = 0.2

local EventController = {}
EventController.Priority = 110

local folder: Folder
local lastSiren = 0

local function attr(name: string, default: any): any
	local value = folder:GetAttribute(name)
	return if value == nil then default else value
end

function EventController.Init()
	folder = ReplicatedStorage:WaitForChild("EventState")
end

function EventController.Start()
	-- no Ghost Light night fog: always sunny (user, 2026-10-22); its call still runs (EventService)
	while true do
		local event = attr("Event", "") :: string
		local phase = attr("Phase", "") :: string
		local startAt = attr("StartAt", 0) :: number
		if event == "GreatStorm" and phase == "Before" and startAt ~= lastSiren then
			lastSiren = startAt
			AudioController.play("Siren_HiLo", nil, 0.55)
		end
		task.wait(TICK)
	end
end

return EventController
