--!strict
-- HelloController: example controller (see the convention at the top of src/client/Main.client.luau).
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local HelloController = {}

local seaLevel = 0

function HelloController.Init()
	local value = Workspace:GetAttribute("SeaLevel")
	if type(value) == "number" then
		seaLevel = value
	end
end

function HelloController.Start()
	print(`[HelloController] hello {Players.LocalPlayer.Name}, sea level is Y = {seaLevel}`)
end

return HelloController
