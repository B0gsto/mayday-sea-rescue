--!strict
-- TerrainOnlyService: Shared.TerrainOnly on the server's world (Workspace, ReplicatedStorage), before MapService
-- builds anything, so no replicated Part ever uses a terrain MaterialService variant.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TerrainOnly = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TerrainOnly"))

local TerrainOnlyService = {}
TerrainOnlyService.Priority = 0

function TerrainOnlyService.Init()
	TerrainOnly.guard(Workspace)
	TerrainOnly.guard(ReplicatedStorage)
end

return TerrainOnlyService
