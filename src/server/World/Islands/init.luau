--!strict
-- Islands: the archipelago build loader (docs/21 §7, package A). WorldDressingService calls Islands.place(base) at
-- server start; it runs place(base, island) of every child module named after a WorldConfig.Islands id, each in its
-- own thread, so one island's error never stops another. One B1 builder owns one child module.
-- `island` is the WorldConfig.Islands row (generated from tools/world/layout.py ARCHIPELAGO): id, name, center,
-- radius, landmark, stamp, landing (on the terrain, Y from the bake), dock (sea level), pads (flat ground, y).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("WorldConfig")
)

local Islands = {}

function Islands.place(base: Instance)
	for _, island in WorldConfig.Islands do
		local mod = script:FindFirstChild(island.id)
		if mod and mod:IsA("ModuleScript") then
			task.spawn(function()
				local ok, err = pcall(function()
					(require :: any)(mod).place(base, island)
				end)
				if not ok then
					warn(`[Islands] {island.id} failed: {err}`)
				end
			end)
		end
	end
end

return Islands
