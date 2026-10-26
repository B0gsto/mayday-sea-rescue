--!strict
-- PickupRingController (docs/23 e.1, WP-2): "slow down here" reads from the water. Every survivor still in the
-- water (Workspace.CallProps "Victim" with Survivor and no OnVehicle; PrivateCasualtyController already unparents
-- other crews' casualties) gets an orange ring of Board.ringFor(your hull) on the water: missions, free-roam and big calls alike.
-- It dims grey while the craft you sit in is full (the seat pips say why) and swells and fades as they climb aboard. They
-- wave on their own (RescueService "Wave" pose with a boat in sight, CasualtyController).
-- Assist(craft, throttle, steer, spec): BoatController runs the driven hull's throttle and helm through it, so a
-- craft with room slows itself to Board.ASSIST_SPEED by the nearest ring (Board.assistThrottle), steering hard
-- toward a survivor eases speed until the turn reaches the ring (Board.turnSpeed), and a hands-off helm is
-- nudged onto them (Board.nudge). Keys, stick and touch all get the same assist; the player still steers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local Buoyancy = require(Shared:WaitForChild("Boat"):WaitForChild("Buoyancy"))
local Helm = require(Shared:WaitForChild("Boat"):WaitForChild("Helm"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local Weather = require(Shared:WaitForChild("Weather"))

local PickupRingController = {}

local ORANGE = Color3.fromRGB(255, 140, 30)
local GREY = Color3.fromRGB(150, 150, 150)
local BAND = 1.4 -- studs wide up close; it widens with distance so it reads from ~150 studs out -- tune
local FAR_WIDTH = 1 / 25 -- band width per stud of camera distance (150 studs: ~6 wide) -- tune
local FADE = 1 -- s: once they leave the water the ring swells and fades, so the climb aboard reads
-- far marker: a lifebuoy pip over the swimmer, always on top, out to MARK_FAR; it fades out as you close
-- (the ring takes over) between MARK_NEAR and MARK_NEAR * 2. Pooled: MARK_MAX nearest get one.
local MARK_FAR, MARK_NEAR, MARK_MAX = 400, 45, 8

local rings: { [Model]: CylinderHandleAdornment } = {}
local fading: { [CylinderHandleAdornment]: number } = {} -- band -> os.clock() they left the water
local folder: Folder? = nil
local marks: { BillboardGui } = {}

local function mark(i: number): BillboardGui
	if not marks[i] then
		local gui = Instance.new("BillboardGui")
		gui.Name = "SurvivorMark"
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Size = UDim2.fromOffset(44, 44)
		gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		gui.SizeOffset = Vector2.new(0, 0.7) -- clear of the ring at any distance
		local img = Instance.new("ImageLabel")
		img.Name = "Icon"
		img.BackgroundTransparency = 1
		img.Image = UiImages.Kit.lifebuoy
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = gui
		gui.Parent = folder
		marks[i] = gui
	end
	return marks[i]
end

local function seatedCraft(): Model?
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		if node:IsA("Model") and node:GetAttribute("VehicleId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function waiting(m: Instance): boolean
	return m:IsA("Model")
		and m.Name == "Victim"
		and m:GetAttribute("Survivor") == true
		and m:GetAttribute("OnVehicle") == nil
		and m.PrimaryPart ~= nil
end

local function newRing(): CylinderHandleAdornment
	local p = Instance.new("Part")
	p.Name = "PickupRing"
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	local band = Instance.new("CylinderHandleAdornment")
	band.Adornee = p
	band.Height = 0.1
	band.Radius = Board.RING
	band.InnerRadius = Board.RING - BAND
	band.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- the cylinder's axis (Z) up
	band.Parent = p
	return band
end

local function step()
	local props = Workspace:FindFirstChild("CallProps")
	local craft = seatedCraft()
	local full = craft ~= nil and not Board.hasRoom(craft)
	local root = craft and craft.PrimaryPart
	local ring = if root then Board.ringFor(root.Size.X / 2) else Board.RING -- your craft's reach
	local seen: { [Model]: boolean } = {}
	local cam = Workspace.CurrentCamera
	local near: { { m: Model, d: number } } = {}
	for _, m in if props then props:GetChildren() else {} do
		if waiting(m) then
			local v = m :: Model
			seen[v] = true
			local band = rings[v] or newRing()
			rings[v] = band
			local at = (v.PrimaryPart :: BasePart).Position
			local ok, h = pcall(Weather.heightAt, at)
			local anchor = band.Adornee :: BasePart
			-- wider and taller far off: a flat 1.4-stud band vanished at a grazing angle (playtest 2026-10-26)
			local far = if cam then (cam.CFrame.Position - at).Magnitude else 0
			band.Radius = ring
			band.InnerRadius = ring - math.clamp(far * FAR_WIDTH, BAND, ring / 2)
			band.Height = math.clamp(far / 150, 0.1, 1.2)
			anchor.CFrame = CFrame.new(
				at.X,
				(if ok and type(h) == "number" then h else at.Y) + 0.15 + band.Height / 2,
				at.Z
			)
			band.Color3 = if full then GREY else ORANGE
			band.Transparency = if full then 0.7 else 0.15
			if far < MARK_FAR and far > MARK_NEAR then
				table.insert(near, { m = v, d = far })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.max(#marks, math.min(#near, MARK_MAX)) do
		local n = near[i]
		if n then
			local gui = mark(i)
			gui.Adornee = n.m.PrimaryPart :: BasePart
			gui.Enabled = true
			local img = gui:FindFirstChild("Icon") :: ImageLabel
			local shown = math.clamp(n.d / MARK_NEAR - 1, 0, 1) * (if full then 0.4 else 1)
			img.ImageColor3 = if full then GREY else Color3.new(1, 1, 1)
			img.ImageTransparency = 1 - shown
		else
			marks[i].Enabled = false
		end
	end
	for v, band in rings do
		if not seen[v] then
			rings[v] = nil
			fading[band] = os.clock()
		end
	end
	for band, t0 in fading do
		local u = (os.clock() - t0) / FADE
		if u >= 1 then
			(band.Adornee :: Instance):Destroy()
			fading[band] = nil
		else
			local w = band.Radius - band.InnerRadius
			band.Radius = ring * (1 + 0.5 * u)
			band.InnerRadius = band.Radius - w
			band.Color3 = ORANGE
			band.Transparency = 0.15 + 0.85 * u
		end
	end
end

-- The throttle and helm the driven craft gets near the nearest waiting survivor (unchanged with no room or
-- none near). spec: its VehicleConfig entry (brake and turning circle); nil keeps the old jet ski numbers.
function PickupRingController.Assist(
	craft: Model,
	input: number,
	steer: number,
	spec: any?
): (number, number)
	local root = craft.PrimaryPart
	if not root or not Board.hasRoom(craft) then
		return input, steer
	end
	local pos = Vector3.new(root.Position.X, 0, root.Position.Z)
	local best: Vector3? = nil
	for v in rings do
		local p = v.PrimaryPart
		if p and v.Parent then
			local d = Vector3.new(p.Position.X, 0, p.Position.Z) - pos
			if not best or d.Magnitude < (best :: Vector3).Magnitude then
				best = d
			end
		end
	end
	if not best then
		return input, steer
	end
	local to = best :: Vector3
	local dist = to.Magnitude
	local ring = Board.ringFor(root.Size.X / 2)
	local vel = root.AssemblyLinearVelocity
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.zAxis
	local forward = vel:Dot(flatLook)
	local closing = if dist > 0.5 then vel:Dot(to.Unit) else forward
	local throttle = Board.assistThrottle(
		input,
		dist - (ring - Board.RING),
		closing,
		forward,
		if spec then spec.brakeDecel else 16
	)
	if dist < 0.5 or dist > Board.OUTER or not spec then
		return throttle, steer
	end
	local right = flatLook:Cross(Vector3.yAxis)
	local side, ahead = to:Dot(right), to:Dot(flatLook)
	local bearing = math.deg(math.atan2(side, ahead))
	steer = Board.nudge(steer, bearing, dist)
	-- steering hard toward them (not behind): slow enough that the turn reaches the ring
	if steer * side > 0 and math.abs(steer) > 0.5 and ahead > -0.2 * dist then
		local lock = Helm.AT_SPEED -- the least helm left at speed: brakes a touch early rather than late
		local cap = Board.turnSpeed(
			dist,
			math.abs(side) / dist,
			ring,
			math.rad(spec.turnRate) * lock,
			spec.turnRadiusSlow,
			spec.maxLateralG * Buoyancy.GRAVITY * lock
		)
		throttle = math.min(throttle, math.clamp((cap - forward) / Board.ASSIST_SPAN, -1, 1))
	end
	return throttle, steer
end

function PickupRingController.Init() end

function PickupRingController.Start()
	local f = Instance.new("Folder")
	f.Name = "PickupRings"
	f.Parent = Workspace
	folder = f
	RunService.Heartbeat:Connect(step)
end

return PickupRingController
