--!strict
-- MapService: publishes the map waypoint setting. ReplicatedStorage attribute UseMapWaypoints = true
-- tells every system (server and client) that the GTA-style map (MapController) shows casualties,
-- drop-offs and destinations, so 3D guidance arrows, beams and markers should not be drawn.
-- Set it false (Studio command bar) to bring the old 3D guidance back.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapService = {}
MapService.Priority = 1

function MapService.Init()
	if ReplicatedStorage:GetAttribute("UseMapWaypoints") == nil then
		ReplicatedStorage:SetAttribute("UseMapWaypoints", true)
	end
end

function MapService.Start() end

return MapService
