--!strict
-- TerrainOnlyController: Shared.TerrainOnly on the client's own Workspace parts (scatter, local builds), before any
-- controller makes them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TerrainOnly = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("TerrainOnly"))

local TerrainOnlyController = {}
TerrainOnlyController.Priority = 0

function TerrainOnlyController.Init()
	TerrainOnly.guard(Workspace)
end

return TerrainOnlyController
