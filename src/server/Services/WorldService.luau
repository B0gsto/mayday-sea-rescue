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
	-- Real gravity at 1 m = 3 studs (docs 02 section 4.2): 9.81 m/s^2 x 3. Owned by stream B (boats).
	-- On foot (tune): walk 12 studs/s = 4 m/s, a brisk jog (a real 1.4 m/s walk is too slow for the
	-- map); jump 3 studs = 1 m, so a dock step or gunwale is a hop (JumpHeight, so Roblox derives the
	-- jump speed from this gravity: sqrt(2 g h) = 13.3 studs/s, 0.9 s in the air).
	Workspace.Gravity = 29.43
	local StarterPlayer = game:GetService("StarterPlayer")
	StarterPlayer.CharacterWalkSpeed = 12
	StarterPlayer.CharacterUseJumpPower = false
	StarterPlayer.CharacterJumpHeight = 3
end

function WorldService.Start()
	print(`[WorldService] sea level at Y = {Workspace:GetAttribute("SeaLevel")}`)
end

return WorldService
