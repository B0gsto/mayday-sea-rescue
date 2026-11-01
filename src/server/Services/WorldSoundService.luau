--!strict
-- Tags every Sound in Workspace "WorldSound" so the client's AudioController can put it in a volume group through a
-- tag signal: a client Workspace.DescendantAdded hook ran Lua for every streamed-in instance on phones.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WorldSoundService = {}
WorldSoundService.Priority = 0 -- hook before any service builds the world

local function tag(d: Instance)
	if d:IsA("Sound") then
		CollectionService:AddTag(d, "WorldSound")
	end
end

function WorldSoundService.Init()
	for _, d in Workspace:GetDescendants() do
		tag(d)
	end
	Workspace.DescendantAdded:Connect(tag)
end

return WorldSoundService
