--!strict
-- RiderController (feel review item 8): every jet ski rider in view, ours and other players', leans into turns,
-- tucks on the throttle and rides the bumps (Shared.Boat.RiderPose). The pose comes from the craft's replicated
-- motion, so nothing is sent; each joint's Transform is turned after the Animator's sit, the WorkerController
-- applyTurns way (a joint the sit track skips turns from the Animator's last write, never stacks).
-- Reduce motion: a smaller lean and tuck, no bounce.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local RiderPose = require(Shared:WaitForChild("Boat"):WaitForChild("RiderPose"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local RiderController = {}

local CULL = 220 -- studs from the camera
local JOINTS: { [string]: string } = { Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head" } -- Motor6D -> its Part1

type Rider = {
	state: RiderPose.State,
	motors: { [string]: Motor6D },
	held: { [Motor6D]: { CFrame } },
}
local riders: { [Model]: Rider } = {}

local function release(r: Rider)
	for m, h in r.held do
		m.Transform = h[1]
	end
end

-- The jet ski (and its top speed) a character sits on, if any.
local function jetSkiOf(character: Model): (VehicleSeat?, number)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil, 0
	end
	local node: Instance? = seat.Parent
	while node and node ~= Workspace do
		local id = node:GetAttribute("VehicleId")
		if id ~= nil then
			local spec = if VehicleConfig.isJetSki(id) then VehicleConfig.get(id :: string) else nil
			return if spec then seat else nil, if spec then spec.topSpeed else 0
		end
		node = node.Parent
	end
	return nil, 0
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local scale = if Comfort.reducedMotion() then 0.4 else 1
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local seat: VehicleSeat?, top = nil, 0
		if character then
			seat, top = jetSkiOf(character)
		end
		if not (character and seat) then
			continue
		end
		if camera and (seat.Position - camera.CFrame.Position).Magnitude > CULL then
			continue
		end
		local r = riders[character]
		if not r then
			local motors: { [string]: Motor6D } = {}
			for joint, partName in JOINTS do
				local part = character:FindFirstChild(partName)
				local m = part and part:FindFirstChild(joint)
				if m and m:IsA("Motor6D") then
					motors[joint] = m
				end
			end
			r = { state = RiderPose.new(), motors = motors, held = {} }
			riders[character] = r
		end
		seen[character] = true
		local frame = seat.CFrame
		local pose = RiderPose.step(r.state, {
			dt = dt,
			yawRate = seat.AssemblyAngularVelocity:Dot(frame.UpVector),
			speed = seat.AssemblyLinearVelocity:Dot(frame.LookVector),
			topSpeed = top,
			vertical = seat.AssemblyLinearVelocity.Y,
			scale = scale,
		}) :: { [string]: CFrame }
		for joint, m in r.motors do
			local tf = m.Transform
			local h = r.held[m]
			if h and tf == h[2] then
				tf = h[1] -- the sit track skipped this joint: turn from its last own pose
			end
			local out = tf * pose[joint]
			m.Transform = out
			r.held[m] = { tf, out }
		end
	end
	for character, r in riders do
		if not seen[character] then
			release(r)
			riders[character] = nil
		end
	end
end

function RiderController.Init() end

function RiderController.Start()
	RunService.PreSimulation:Connect(step)
end

return RiderController
