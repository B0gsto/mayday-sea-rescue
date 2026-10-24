--!strict
-- RacerController (docs/20 change 3): the NPC rescue boat is never hidden. While it races you, a red
-- boat blip follows it on the minimap (server player attribute RacerAt, kept off the boat itself
-- because it may not be streamed in). When an NPC boat takes your survivor (RacerTaking = the spot)
-- the camera cuts there for 2 s, so the "Too slow" debrief that follows has a reason you saw.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RacerController = {}

local CUT_SECONDS = 2

local player = Players.LocalPlayer

function RacerController.Start()
	local MapController = require(script.Parent.MapController) :: any
	local CameraController = require(script.Parent.CameraController) :: any

	local function blip()
		local at = player:GetAttribute("RacerAt")
		MapController.SetBlips(
			"Racer",
			if typeof(at) == "Vector3"
				then { { id = "boat", position = at, style = "Racer", size = 20 } }
				else nil
		)
	end
	player:GetAttributeChangedSignal("RacerAt"):Connect(blip)
	blip()

	player:GetAttributeChangedSignal("RacerTaking"):Connect(function()
		local at = player:GetAttribute("RacerTaking")
		if typeof(at) ~= "Vector3" then
			return
		end
		-- from your side of the pickup, a little above, easing in
		local cam = Workspace.CurrentCamera
		local away = if cam then (cam.CFrame.Position - at) * Vector3.new(1, 0, 1) else Vector3.zero
		away = if away.Magnitude > 1 then away.Unit else Vector3.new(0, 0, 1)
		local look = at + Vector3.new(0, 2, 0)
		CameraController.PlayCinematic({
			{
				from = CFrame.lookAt(at + away * 34 + Vector3.new(0, 12, 0), look),
				to = CFrame.lookAt(at + away * 24 + Vector3.new(0, 8, 0), look),
				duration = CUT_SECONDS,
			},
		}, { id = "takeover", repeatable = true, skippable = false })
	end)
end

return RacerController
