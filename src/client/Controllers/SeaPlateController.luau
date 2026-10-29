--!strict
-- SeaPlateController (docs/27): the Ramp Wharf's jump ramp and the teal brick, client side. A craft you drive that
-- passes the ramp's invisible RampLip (DockPieces) plays ramp_jump there (a spray fan off the lip, a whoosh); on your
-- own ramp the first jump is the Expand funnel's Used step. Picking up the teal brick (DockService's TealPrompt)
-- pops it with crew_arrive. No UI, no score: the ramp is a free toy.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Workspace = game:GetService("Workspace")

local Telemetry = require(script.Parent.Parent:WaitForChild("Telemetry"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local SeaPlateController = {}
local player = Players.LocalPlayer

local REARM = 2.5 -- s before the same craft can jump again
local NEAR = 6 -- studs of slack round the lip box

local lastJump = -math.huge

-- the driver's seat you sit in, if it is a craft's
local function driving(): BasePart?
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	return if seat and seat:IsA("VehicleSeat") then seat else nil
end

local function check()
	local seat = driving()
	local marina = Workspace:FindFirstChild("Marina")
	if not (seat and marina) or os.clock() - lastJump < REARM then
		return
	end
	for _, plot in marina:GetChildren() do
		local plate = plot:FindFirstChild("SeaPlate1")
		local lip = plate and plate:FindFirstChild("RampLip")
		if lip and lip:IsA("BasePart") then
			local l = lip.CFrame:PointToObjectSpace(seat.Position)
			local half = lip.Size / 2 + Vector3.new(NEAR, NEAR, NEAR)
			if math.abs(l.X) < half.X and math.abs(l.Y) < half.Y and math.abs(l.Z) < half.Z then
				lastJump = os.clock()
				VFXKit.play("ramp_jump", lip.CFrame)
				if plot.Name == `Plot{player:GetAttribute("DockPlot")}` then
					Telemetry.send("Expand", "Used", "SeaPlate1") -- the server keeps the first
				end
				return
			end
		end
	end
end

function SeaPlateController.Start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local brick = prompt.Parent
		if prompt.Name == "TealPrompt" and brick and brick:IsA("BasePart") then
			VFXKit.play("crew_arrive", brick.CFrame, { color = brick.Color })
		end
	end)
	task.spawn(function()
		while true do
			check()
			task.wait(0.05) -- a jet ski crosses the lip box (3 + 12 studs) in ~0.15 s at full speed
		end
	end)
end

return SeaPlateController
