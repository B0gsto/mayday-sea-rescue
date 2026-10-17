--!strict
-- FirstPerson: the locked first-person camera, on foot and on a first-person vehicle (jet ski,
-- or the helm view of a chase vehicle).
--
-- On foot it rides Roblox's own camera (LockFirstPerson handles mouse, touch and gamepad look)
-- and layers a subtle head bob on top: CameraController calls preFoot() before the default camera
-- updates (undoing last frame's offset, so the look direction never drifts) and foot() after it.
-- The body stays visible when looking down (torso and legs; the arms hide while the viewmodel
-- shows), the head and accessories never block the view.
--
-- On a vehicle it is a scripted camera at the seat's EyePoint: the heading follows the hull, the
-- pitch and roll blend between hull locked and horizon locked (Comfort.horizonStab), with a G-force
-- lean, a neck that gives on slams, shake from wave slams, the speed FOV kick and spray on the lens.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CameraMath = require(script.Parent.CameraMath)
local Comfort = require(script.Parent.Comfort)

local FirstPerson = {}

export type VehicleCtx = {
	root: BasePart,
	seat: BasePart,
	eye: Attachment?,
	topSpeed: number,
	telemetry: { speed: number, slam: number, contact: number, planing: number }?,
}

local ARM_PARTS = {
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	["Left Arm"] = true,
	["Right Arm"] = true,
}

-- Shows the torso and legs, hides the head, the accessories and (when the viewmodel is drawn)
-- the arms. Call after the default camera's transparency pass.
-- The vehicle the local player rides with a rider-only close-up set (see FirstPerson.setRider). Its
-- seated eye is inside the rider's own head and torso, so the whole body is hidden.
local riderModel: Model? = nil

function FirstPerson.applyBodyVisibility(character: Model, hideArms: boolean)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			local hide = riderModel ~= nil
				or d.Name == "Head"
				or d:FindFirstAncestorWhichIsA("Accessory") ~= nil
				or (hideArms and ARM_PARTS[d.Name] == true)
			d.LocalTransparencyModifier = if hide then 1 else 0
		elseif d:IsA("Decal") and d.Parent and d.Parent.Name == "Head" then
			d.LocalTransparencyModifier = 1
		end
	end
end

function FirstPerson.resetBodyVisibility(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			(d :: any).LocalTransparencyModifier = 0
		end
	end
end

---------------------------------------------------------------- on foot

local bobPhase = 0
local bobAmount = 0
local lastOffset = CFrame.identity

function FirstPerson.enterFoot(humanoid: Humanoid)
	local player = Players.LocalPlayer
	local camera = Workspace.CurrentCamera
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMinZoomDistance = 0.5
	player.CameraMaxZoomDistance = 0.5
	camera.CameraType = Enum.CameraType.Custom
	camera.CameraSubject = humanoid
	-- eyes sit in front of the head's centre: looking down shows the chest, not the inside of it
	humanoid.CameraOffset = Vector3.new(0, 0.1, -0.55)
	lastOffset = CFrame.identity
end

function FirstPerson.exitFoot(humanoid: Humanoid?)
	if humanoid then
		humanoid.CameraOffset = Vector3.zero
	end
	lastOffset = CFrame.identity
end

-- Before the default camera update: remove last frame's bob so its look vector stays clean.
function FirstPerson.preFoot()
	local camera = Workspace.CurrentCamera
	if lastOffset ~= CFrame.identity then
		camera.CFrame = camera.CFrame * lastOffset:Inverse()
		lastOffset = CFrame.identity
	end
end

-- After the default camera update: head bob, FOV.
function FirstPerson.foot(dt: number, humanoid: Humanoid, root: BasePart)
	local camera = Workspace.CurrentCamera
	local v = root.AssemblyLinearVelocity
	local speed = Vector3.new(v.X, 0, v.Z).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
	local walkSpeed = math.max(humanoid.WalkSpeed, 1)
	local target = if grounded or swimming
		then math.clamp(speed / walkSpeed, 0, 1) * Comfort.get("headBob") * (if swimming
			then 0.4
			else 1)
		else 0
	bobAmount = CameraMath.damp(bobAmount, target, 0.12, dt)
	bobPhase += CameraMath.bobRate(if swimming then speed * 0.5 else speed) * dt
	if bobAmount < 0.01 then
		-- settle to the nearest rest point of the cycle instead of freezing mid-step
		bobPhase =
			CameraMath.damp(bobPhase, math.floor(bobPhase / math.pi + 0.5) * math.pi, 0.1, dt)
	end
	local offset, roll = CameraMath.headBob(bobPhase, bobAmount)
	local o = CFrame.new(offset) * CFrame.Angles(0, 0, roll)
	camera.CFrame = camera.CFrame * o
	lastOffset = o
	camera.FieldOfView = CameraMath.damp(camera.FieldOfView, Comfort.get("fov"), 0.15, dt)
end

---------------------------------------------------------------- vehicle

local look = { yaw = 0, pitch = 0, idle = 0 }
local baseRot: CFrame? = nil
local prevVel: Vector3? = nil
local accel = Vector3.zero
local lean = { roll = 0, rollV = 0, pitch = 0, pitchV = 0 }
local neck = { y = 0, v = 0 }
local trauma = 0
local clock = 0
local blur: BlurEffect? = nil

local YAW_LIMIT = math.rad(150)
local PITCH_MIN, PITCH_MAX = math.rad(-70), math.rad(60)

local DEFAULT_PITCH = math.rad(-6)
local restPitch = DEFAULT_PITCH -- the EyePoint's EyePitch attribute (degrees), else DEFAULT_PITCH
local freshEye = true -- the first vehicle frame snaps the look pitch to restPitch

-- Rider-only first-person set (Builder.buildJetSkiAsset): the close-up model (attribute RiderOnly)
-- is built hidden for everyone; the rider's client shows it locally (Transparency is not
-- replicated back) and hides the parts tagged HideForRider (the base model's Bars) with
-- LocalTransparencyModifier so the two sets don't double up. Re-applied while riding, for parts
-- that stream in late.
local riderCheckAt = 0

local function applyRider(model: Model, on: boolean)
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		if d:GetAttribute("HideForRider") == true then
			d.LocalTransparencyModifier = if on then 1 else 0
		end
		local shown = d:GetAttribute("RiderTransparency")
		if typeof(shown) == "number" then
			local parent = d:FindFirstAncestorWhichIsA("Model")
			if parent and parent:GetAttribute("RiderOnly") == true then
				d.Transparency = if on then shown else 1
			end
		end
	end
end

-- model: the vehicle the local player drives in first person, or nil to put everything back.
function FirstPerson.setRider(model: Model?)
	if riderModel == model then
		return
	end
	if riderModel and riderModel.Parent then
		applyRider(riderModel, false)
	end
	riderModel = model
	riderCheckAt = 0
	if model then
		applyRider(model, true)
	end
end

function FirstPerson.enterVehicle()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	freshEye = true
	look.yaw, look.pitch, look.idle = 0, DEFAULT_PITCH, 0
	baseRot = nil
	prevVel = nil
	accel = Vector3.zero
	lean.roll, lean.rollV, lean.pitch, lean.pitchV = 0, 0, 0, 0
	neck.y, neck.v = 0, 0
	trauma = 0
end

function FirstPerson.addTrauma(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

---------------------------------------------------------------- lens spray

local sprayGui: ScreenGui? = nil
local drops = 0

local function sprayDrop(big: boolean)
	local gui = sprayGui
	if not gui or drops >= 28 then
		return
	end
	drops += 1
	local size = if big then math.random(22, 46) else math.random(7, 20)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(math.random(), math.random() * 0.8)
	f.Size = UDim2.fromOffset(size, size * (0.85 + math.random() * 0.3))
	f.BackgroundColor3 = Color3.fromRGB(225, 238, 245)
	f.BackgroundTransparency = 0.84
	f.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Transparency = 0.55
	stroke.Thickness = 1
	stroke.Parent = f
	local glint = Instance.new("Frame")
	glint.Size = UDim2.fromScale(0.28, 0.22)
	glint.Position = UDim2.fromScale(0.22, 0.18)
	glint.BackgroundColor3 = Color3.new(1, 1, 1)
	glint.BackgroundTransparency = 0.45
	glint.BorderSizePixel = 0
	local gc = corner:Clone()
	gc.Parent = glint
	glint.Parent = f
	f.Parent = gui
	local life = 1.2 + math.random() * 1.6
	local slide = math.random(20, 90)
	local start = f.Position
	task.spawn(function()
		local t = 0
		while t < life and f.Parent do
			t += task.wait()
			local k = t / life
			-- drops cling, then run down the lens and thin out
			f.Position = start + UDim2.fromOffset(0, slide * k * k)
			f.BackgroundTransparency = 0.84 + 0.16 * k
			stroke.Transparency = 0.55 + 0.45 * k
			glint.BackgroundTransparency = 0.45 + 0.55 * k
		end
		f:Destroy()
		drops -= 1
	end)
end

function FirstPerson.setSprayEnabled(on: boolean)
	if on and not sprayGui then
		local gui = Instance.new("ScreenGui")
		gui.Name = "LensSpray"
		gui.IgnoreGuiInset = true
		gui.ResetOnSpawn = false
		gui.DisplayOrder = -5
		gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		sprayGui = gui
	elseif not on and sprayGui then
		sprayGui:Destroy()
		sprayGui = nil
		drops = 0
	end
end

---------------------------------------------------------------- vehicle update

-- One frame of the vehicle first-person camera. `lookDelta` is (yaw, pitch) radians of look input
-- this frame. Returns the camera CFrame (also applied).
function FirstPerson.vehicle(dt: number, ctx: VehicleCtx, lookDelta: Vector2): CFrame
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	clock += dt
	local hullCF = ctx.root.CFrame
	local vel = ctx.root.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local top = math.max(ctx.topSpeed, 1)

	-- look: free head turn relative to the hull, eased back ahead after a moment without input
	if lookDelta.Magnitude > 1e-5 then
		look.idle = 0
	else
		look.idle += dt
	end
	if freshEye then
		freshEye = false
		local deg = if ctx.eye then ctx.eye:GetAttribute("EyePitch") else nil
		restPitch = if typeof(deg) == "number" then math.rad(deg) else DEFAULT_PITCH
		look.pitch = restPitch
	end
	if riderModel then
		riderCheckAt -= dt
		if riderCheckAt <= 0 then
			riderCheckAt = 1
			applyRider(riderModel, true)
		end
	end
	look.yaw = math.clamp(look.yaw + lookDelta.X, -YAW_LIMIT, YAW_LIMIT)
	look.pitch = math.clamp(look.pitch + lookDelta.Y, PITCH_MIN, PITCH_MAX)
	if look.idle > 1.2 and speed > 4 then
		look.yaw = CameraMath.damp(look.yaw, 0, 0.6, dt)
		look.pitch = CameraMath.damp(look.pitch, restPitch, 0.8, dt)
	end

	-- head stabilisation: blend hull and horizon, then a short low-pass for engine/chop jitter
	local target = CameraMath.stabilise(hullCF, Comfort.get("horizonStab"))
	local prev = baseRot or target
	baseRot = prev:Lerp(target, 1 - 2 ^ (-dt / 0.035))
	local rot = baseRot :: CFrame

	-- G-force lean from the smoothed hull acceleration
	if prevVel and dt > 0 then
		accel = CameraMath.damp(accel, (vel - (prevVel :: Vector3)) / dt, 0.08, dt)
	end
	prevVel = vel
	local accelLocal = hullCF:VectorToObjectSpace(accel)
	local rollT, pitchT = CameraMath.gLean(accelLocal, Comfort.get("gLean"), math.rad(10))
	lean.roll, lean.rollV = CameraMath.spring(lean.roll, lean.rollV, rollT, 1.8, 0.8, dt)
	lean.pitch, lean.pitchV = CameraMath.spring(lean.pitch, lean.pitchV, pitchT, 1.8, 0.8, dt)
	-- the neck gives a little under vertical g (wave slams), then springs back
	local neckT = math.clamp(-accelLocal.Y * 0.004, -0.45, 0.3)
	neck.y, neck.v = CameraMath.spring(neck.y, neck.v, neckT, 3, 0.6, dt)

	-- shake from slams plus a faint hull buzz on the plane
	local tel = ctx.telemetry
	if tel then
		if tel.slam > 2 then
			FirstPerson.addTrauma(math.min(tel.slam * 0.025, 0.6))
			if Comfort.get("lensSpray") and tel.slam > 6 then
				for _ = 1, math.random(2, 5) do
					sprayDrop(math.random() < 0.35)
				end
			end
		end
		if Comfort.get("lensSpray") and tel.contact > 0.4 and speed > top * 0.45 then
			if math.random() < dt * 2.5 * (speed / top) then
				sprayDrop(false)
			end
		end
	end
	trauma = math.max(trauma - dt * 1.4, 0)
	local buzz = math.clamp((speed / top) * 0.22, 0, 0.22)
	local s = CameraMath.shake(math.max(trauma, buzz), Comfort.get("shake"), clock, math.noise)

	local eyePos = if ctx.eye
		then ctx.eye.WorldPosition
		else ctx.seat.CFrame:PointToWorldSpace(Vector3.new(0, ctx.seat.Size.Y * 0.5 + 2.4, 0))
	local cf = CFrame.new(eyePos + rot.UpVector * neck.y)
		* rot
		* CFrame.Angles(lean.pitch, 0, -lean.roll)
		* CFrame.Angles(0, look.yaw, 0)
		* CFrame.Angles(look.pitch, 0, 0)
		* CFrame.Angles(s.X, s.Y, s.Z)
	camera.CFrame = cf

	local fov = Comfort.get("fov")
	if Comfort.get("speedFov") then
		fov = CameraMath.speedFov(fov, speed, top, 8)
	end
	camera.FieldOfView = CameraMath.damp(camera.FieldOfView, fov, 0.2, dt)

	-- motion blur only when the player opts in
	if Comfort.get("motionBlur") then
		if not blur then
			local b = Instance.new("BlurEffect")
			b.Name = "SpeedBlur"
			b.Size = 0
			b.Parent = camera
			blur = b
		end
		local b = blur :: BlurEffect
		b.Size =
			CameraMath.damp(b.Size, 3 * CameraMath.smoothstep((speed / top - 0.6) / 0.4), 0.2, dt)
	elseif blur then
		blur:Destroy()
		blur = nil
	end
	return cf
end

function FirstPerson.exitVehicle()
	if blur then
		blur:Destroy()
		blur = nil
	end
	FirstPerson.setSprayEnabled(false)
end

return FirstPerson
