--!strict
-- WorldService: example service (see the convention at the top of src/server/Main.server.luau).
-- Publishes world constants as Workspace attributes so clients and tools can read them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig")
)

local WorldService = {}
WorldService.Priority = 10 -- world constants first, before services that read them

function WorldService.Init()
	Workspace:SetAttribute("SeaLevel", GameConfig.SeaLevel)
	Workspace:SetAttribute("MapRadius", GameConfig.MapRadius)
end

function WorldService.Start()
	print(`[WorldService] sea level at Y = {Workspace:GetAttribute("SeaLevel")}`)
end

return WorldService
