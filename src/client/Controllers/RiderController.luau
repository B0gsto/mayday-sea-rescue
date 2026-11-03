--!strict
-- RiderController (feel review item 8): every jet ski rider in view, ours and other players', leans into turns,
-- tucks on the throttle and rides the bumps (Shared.Boat.RiderPose). The pose comes from the craft's replicated
-- motion, so nothing is sent; each joint's Transform is turned after the Animator's sit, the WorkerController
-- applyTurns way (a joint the sit track skips turns from the Animator's last write, never stacks).
-- Reduce motion: a smaller lean and tuck, no bounce.
-- The ride's water (AD 2026-11-01: "almost no spray"): a rooster tail off the stern scaled by speed, side spray off
-- the outside of a carve, and one splash (with its sound) as a hard carve bites or a wave slams; pooled VFXKit
-- presets (ski_rooster / ski_carve / ski_splash) on a 0.1 s tick, culled with the pose. The hull's own bank is
-- BoatController's (RiderPose.bank); the head counters it too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local RiderPose = require(Shared:WaitForChild("Boat"):WaitForChild("RiderPose"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))
local Waves = require(Shared:WaitForChild("Waves"))

local RiderController = {}

local CULL = 220 -- studs from the camera
local JOINTS: { [string]: string } = { Root = "LowerTorso", Waist = "UpperTorso", Neck = "Head" } -- Motor6D -> its Part1
local SPRAY_TICK = 0.1 -- seconds between spray puffs
local HARD_CARVE = 0.75 -- RiderPose.spray side strength that throws the splash
local SPLASH_GAP = 0.8 -- seconds between splashes per rider

type Rider = {
	state: RiderPose.State,
	motors: { [string]: Motor6D },
	held: { [Motor6D]: { CFrame } },
	nextSpray: number,
	carving: boolean,
	lastSplash: number,
	slammed: boolean,
}
local riders: { [Model]: Rider } = {}

local function release(r: Rider)
	for m, h in r.held do
		m.Transform = h[1]
	end
end

-- The jet ski (its seat, top speed and physics root) a character sits on, if any.
local function jetSkiOf(character: Model): (VehicleSeat?, number, BasePart?)
	local hum = character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	if not (seat and seat:IsA("VehicleSeat")) then
		return nil, 0, nil
	end
	local node: Instance? = seat.Parent
	while node and node ~= Workspace do
		local id = node:GetAttribute("VehicleId")
		if id ~= nil then
			local spec = if VehicleConfig.isJetSki(id) then VehicleConfig.get(id :: string) else nil
			local root = if spec and node:IsA("Model") then node.PrimaryPart else nil
			return if root then seat else nil, if spec then spec.topSpeed else 0, root
		end
		node = node.Parent
	end
	return nil, 0, nil
end

-- A pooled emitter host at `at` whose up axis (the emitters' direction) points along `up`.
local function aim(at: Vector3, up: Vector3): CFrame
	local x = up:Cross(Vector3.yAxis)
	return CFrame.fromMatrix(at, if x.Magnitude > 1e-3 then x.Unit else Vector3.xAxis, up)
end

-- The ride's water off one jet ski: rooster tail, carve spray and the splash (RiderPose.spray strengths).
local function spray(
	r: Rider,
	root: BasePart,
	top: number,
	yawRate: number,
	speed: number,
	mine: boolean
)
	local now = os.clock()
	if now < r.nextSpray then
		return
	end
	r.nextSpray = now + SPRAY_TICK
	if math.abs(root.Position.Y - Waves.SEA_LEVEL) > 6 then -- airborne off a crest or hauled out
		r.carving, r.slammed = false, false
		return
	end
	local tail, side = RiderPose.spray(speed, top, yawRate)
	local cf = root.CFrame
	local back, half = -cf.LookVector, root.Size * 0.5
	local waterline = Vector3.new(0, -half.Y * 0.4, 0)
	local still = not mine -- someone else's ride: no camera moment
	if tail > 0.05 then
		VFXKit.play(
			"ski_rooster",
			aim(root.Position + back * half.Z * 0.95 + waterline, (back + Vector3.yAxis * 1.2).Unit),
			{ scale = tail, still = still }
		)
	end
	local out = cf.RightVector * (if yawRate > 0 then 1 else -1) -- a left turn throws off the starboard side
	if side > 0.05 then
		VFXKit.play(
			"ski_carve",
			aim(
				root.Position + out * half.X + back * half.Z * 0.35 + waterline,
				(out + Vector3.yAxis * 0.7 + back * 0.4).Unit
			),
			{ scale = side, still = still }
		)
	end
	local hard = side >= HARD_CARVE
	if ((hard and not r.carving) or r.slammed) and now - r.lastSplash > SPLASH_GAP then
		r.lastSplash = now
		local at = root.Position + waterline + (if hard then out * half.X else Vector3.zero)
		VFXKit.play(
			"ski_splash",
			CFrame.new(at),
			{ scale = math.max(0.5, side, tail), still = still }
		)
	end
	r.carving, r.slammed = hard, false
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local scale = if Comfort.reducedMotion() then 0.4 else 1
	local seen: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local seat: VehicleSeat?, top, root = nil, 0, nil
		if character then
			seat, top, root = jetSkiOf(character)
		end
		if not (character and seat and root) then
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
			r = {
				state = RiderPose.new(),
				motors = motors,
				held = {},
				nextSpray = 0,
				carving = false,
				lastSplash = 0,
				slammed = false,
			}
			riders[character] = r
		end
		seen[character] = true
		local frame = root.CFrame -- the physics root: the seat rides the visual bank
		local visual = root:FindFirstChild("VisualJoint")
		local bank = 0
		if visual and visual:IsA("Motor6D") then
			bank = select(3, visual.Transform:ToEulerAnglesXYZ())
		end
		local yawRate = root.AssemblyAngularVelocity:Dot(frame.UpVector)
		local speed = root.AssemblyLinearVelocity:Dot(frame.LookVector)
		local pose = RiderPose.step(r.state, {
			dt = dt,
			yawRate = yawRate,
			speed = speed,
			topSpeed = top,
			vertical = root.AssemblyLinearVelocity.Y,
			scale = scale,
			bank = bank,
		}) :: { [string]: CFrame }
		r.slammed = r.slammed or r.state.slam -- held for the next spray tick
		spray(r, root, top, yawRate, speed, player == Players.LocalPlayer)
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
