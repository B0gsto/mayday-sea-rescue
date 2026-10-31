--!strict
-- BoatReveal (docs/28 Feel 1): the buy-a-boat moment. After a successful BuyGear (Panels/Board, BoatCard) the
-- new craft builds in at its berth, local only: a copy of its VehiclePreviews model drops in brick by brick
-- (BuildSeq.plan, the same 0.45 s Quad-In land as ConstructionController), the build-watch camera eases over,
-- fx1_build_snap, a horn and the fanfare, then a Launch prompt on the copy. Launch fires Net BoardLaunch (the
-- normal board launch: you in its seat); the copy goes then, when any craft of ours spawns, or after LINGER s.
--   BoatReveal.play(id)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local DockPieces = require(Shared:WaitForChild("DockPieces"))
local Net = require(Shared:WaitForChild("Net"))
local VehicleConfig = require(Shared:WaitForChild("Config"):WaitForChild("VehicleConfig"))

local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

local player = Players.LocalPlayer
local BOARDS = { AirStation = "HangarBoard", SubPen = "SubBoard" } -- else the boat board (server/Dock/BoatBoard)
local AFLOAT = 1.5 -- the copy's pivot over the berth, as BoatBoard's crane leaves it
local LAND_T = 0.45 -- one brick's drop (ConstructionController land)
local EASE = 0.9 -- the watch camera's ease in / out
local LINGER = 90 -- s the built copy waits for Launch
local REACH = 16 -- the Launch prompt, from the craft's root (BoatBoard checks 22 from its spot)

local BoatReveal = {}

local function myBerth(): BasePart?
	local marina = Workspace:FindFirstChild("Marina")
	for _, d in if marina then marina:GetDescendants() else {} do
		if
			d:IsA("BasePart")
			and d:GetAttribute("LaunchBay")
			and d:GetAttribute("Owner") == player.UserId
		then
			return d
		end
	end
	return nil
end

-- where the board's launch leaves the craft: its building's pad / pen, else the berth (slid seaward for a long hull)
-- shortcut: ignores the pontoon's second spot (VehicleService dockSpot); the server's launch still picks it
local function restOf(id: string, berth: BasePart, copy: Model): CFrame
	local building = DockConfig.buildingOf(id)
	local b = building and (DockPieces.Buildings :: any)[building]
	local offset = b and b.targets and b.targets[id]
	if offset then
		local spot = (berth.CFrame - Vector3.new(0, 0.2, 0)) * offset
		if building == "AirStation" then -- on the pad floor
			copy:PivotTo(spot)
			local box, size = copy:GetBoundingBox()
			return spot + Vector3.new(0, spot.Y - (box.Y - size.Y / 2), 0)
		end
		return spot * CFrame.new(0, AFLOAT, 0)
	end
	local spec = VehicleConfig.get(id)
	local out = if spec then math.max(0, spec.hullSize.Z / 2 - berth.Size.Z / 2) else 0
	return berth.CFrame * CFrame.new(0, AFLOAT, -out)
end

-- the build-watch camera beat (ConstructionController watch): ease over, a slow push-in through the drop, ease back
local function watch(at: Vector3, radius: number, hold: number)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local cam = Workspace.CurrentCamera
	if
		not (hum and root and root:IsA("BasePart") and cam)
		or hum.SeatPart
		or (root.Position - at).Magnitude > 320
	then
		return
	end
	local side = (cam.CFrame.Position - at) * Vector3.new(1, 0, 1)
	local dist = radius * 1.6 + 16
	local eye = at
		+ (if side.Magnitude > 1 then side.Unit else Vector3.zAxis) * dist
		+ Vector3.new(0, dist * 0.55, 0)
	local view = CFrame.lookAt(eye, at)
	local back, fov = cam.CFrame, cam.FieldOfView
	if CameraController.Comfort.reducedMotion() then
		CameraController.PlayCinematic(
			{ { from = view, duration = hold, fov = fov, handheld = 0 } },
			{ skippable = true }
		)
		return
	end
	local push = view * CFrame.new(0, 0, -dist * 0.08)
	CameraController.PlayCinematic({
		{ from = back, to = view, duration = EASE, fov = fov, toFov = 50, handheld = 0 },
		{ from = view, to = push, duration = hold, fov = 50, handheld = 0.15 },
		{ from = push, to = back, duration = EASE, fov = 50, toFov = fov, handheld = 0 },
	}, { skippable = true })
end

local current: (() -> ())? = nil

function BoatReveal.play(id: string)
	local previews = ReplicatedStorage:FindFirstChild("VehiclePreviews")
	local source = previews and previews:FindFirstChild(id)
	local berth = myBerth()
	if not (source and source:IsA("Model") and berth) then
		return
	end
	if current then
		current()
	end
	local copy = source:Clone()
	copy.Name = "BoatReveal_" .. id
	local parts: { BasePart } = {}
	for _, d in copy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanTouch, d.CanQuery = true, false, false, false
			table.insert(parts, d)
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	local rest = restOf(id, berth, copy)
	copy:PivotTo(rest)
	local box, size = copy:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2

	-- our docked hull on that spot hides while the copy stands there (the launch replaces it)
	local hidden: { BasePart } = {}
	local vehicles = Workspace:FindFirstChild("Vehicles")
	for _, m in if vehicles then vehicles:GetChildren() else {} do
		local r = m:IsA("Model") and m:GetAttribute("Owner") == player.UserId and m.PrimaryPart
		if r and (r.Position - box.Position).Magnitude < radius + 6 then
			for _, d in m:GetDescendants() do
				if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then
					d.LocalTransparencyModifier = 1
					table.insert(hidden, d)
				end
			end
		end
	end
	local bay = berth:FindFirstChild("Launch")
	local muted = bay and bay:IsA("ProximityPrompt") and bay.Enabled and bay or nil -- one Launch here: the copy's
	if muted then
		muted.Enabled = false
	end

	local conns: { RBXScriptConnection } = {}
	local done = false
	local function cleanup()
		if done then
			return
		end
		done = true
		if current == cleanup then
			current = nil
		end
		for _, c in conns do
			c:Disconnect()
		end
		copy:Destroy()
		for _, p in hidden do
			p.LocalTransparencyModifier = 0
		end
		if muted then
			muted.Enabled = true -- BoatController hides it again if a craft is out
		end
	end
	current = cleanup

	-- the bricks: hidden until their turn, then each drops in from BuildSeq's height, bottom to top
	local ys, finals = {}, {}
	for i, p in parts do
		finals[i] = p.CFrame
		ys[i] = p.CFrame.Y
		p.LocalTransparencyModifier = 1
	end
	copy.Parent = Workspace
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local last = 0
	for _, s in plan do
		last = math.max(last, s.delay)
	end
	local snapAt = EASE + last + LAND_T
	watch(box.Position, math.max(radius, size.Y), last + LAND_T + 1.6)
	AudioController.play("FX_PlasticRain", box.Position, 0.6, 0.8) -- the bricks are on their way
	for _, s in plan do
		local p, final = parts[s.i], finals[s.i]
		task.delay(EASE + s.delay, function()
			if done then
				return
			end
			p.CFrame = final + Vector3.new(0, s.drop, 0)
			p.LocalTransparencyModifier = 0
			TweenService:Create(
				p,
				TweenInfo.new(LAND_T, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = final }
			):Play()
		end)
	end

	task.delay(snapAt, function()
		if done then
			return
		end
		local base = CFrame.new(box.Position.X, box.Position.Y - size.Y / 2, box.Position.Z)
		AudioController.play("Album_Sticker", box.Position, 1, 1.5) -- the last brick clacks home
		task.delay(0.07, AudioController.play, "UI_Click", box.Position, 3, 0.75)
		VFXKit.play("fx1_build_snap", base, { radius = radius + 1, height = size.Y + 4 })
		task.delay(0.35, AudioController.play, "Horn_Ferry", box.Position, 1, 1)
		task.delay(0.5, AudioController.play, "Music_CrateFanfare", nil, 1, 1)

		local holder = copy.PrimaryPart or parts[1]
		if not holder then
			return
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Launch"
		prompt.ActionText = "Launch"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = REACH
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("FootOnly", true)
		prompt.Parent = holder
		table.insert(
			conns,
			prompt.Triggered:Connect(function()
				cleanup()
				Net.event("BoardLaunch")
					:FireServer(BOARDS[DockConfig.buildingOf(id) or ""] or "BoatBoard", id)
			end)
		)
	end)
	table.insert(
		conns,
		Net.event("VehicleSpawned").OnClientEvent:Connect(function(model: any)
			if typeof(model) == "Instance" and model:GetAttribute("Owner") == player.UserId then
				cleanup()
			end
		end)
	)
	task.delay(LINGER, cleanup)
end

return BoatReveal
