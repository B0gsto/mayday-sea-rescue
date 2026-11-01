--!strict
-- PickupRingController (docs/23 e.1, WP-2): "slow down here" reads from the water. Every survivor still in the
-- water (Workspace.CallProps "Victim" with Survivor and no OnVehicle; PrivateCasualtyController already unparents
-- other crews' casualties) gets a red-and-white Lego lifebuoy ring (studded tiles, steady) of Board.ringFor(your hull) on the water: missions, free-roam and big calls alike.
-- It dims grey while the craft you sit in is full (the seat pips say why) and swells and fades as they climb aboard. They
-- wave on their own (RescueService "Wave" pose with a boat in sight, CasualtyController).
-- Assist(craft, throttle, steer): BoatController runs the driven hull's helm through it, so with room a hands-off
-- helm near the nearest ring is nudged onto them (Board.nudge). The throttle is never cut (docs/24 A: drive next
-- to them at any speed). Keys, stick and touch all get the same assist; the player still steers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Board = require(Shared:WaitForChild("Ops"):WaitForChild("Board"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))
local Weather = require(Shared:WaitForChild("Weather"))

local PickupRingController = {}

local RED, WHITE = Color3.fromRGB(205, 36, 36), Color3.fromRGB(245, 245, 240) -- lifebuoy quarters
local GREY, PALE = Color3.fromRGB(150, 150, 150), Color3.fromRGB(196, 196, 196) -- full: the same ring, greyed
local TILES, PER_QUARTER = 24, 3 -- round of 1xN tiles, 8 colour quarters of 3
local LIFT = 0.05 -- red quarters sit this much higher: no shared top plane where they overlap white (no z-fight)
local BAND = 1.4 -- studs wide up close; it widens with distance so it reads from ~150 studs out -- tune
local FAR_WIDTH = 1 / 25 -- band width per stud of camera distance (150 studs: ~6 wide) -- tune
local FADE = 1 -- s: once they leave the water the ring swells and fades, so the climb aboard reads
-- far marker: a lifebuoy pip over the swimmer, always on top, out to MARK_FAR; it fades out as you close
-- (the ring takes over) between MARK_NEAR and MARK_NEAR * 2. Pooled: MARK_MAX nearest get one.
local MARK_FAR, MARK_NEAR, MARK_MAX = 560, 45, 8 -- 560: the cove-mouth swimmers read from your island
local MARK_PX = 48 -- px: a pip this close on screen to a nearer swimmer's is dropped (the pip is 44 wide)

local SLOW_FAR, SLOW_EVERY = 200, 1 / 8 -- past 200 studs a ring's bob/size update runs at 8 Hz (phones) -- tune

type Ring = {
	anchor: Part,
	tiles: { BoxHandleAdornment },
	studs: { CylinderHandleAdornment },
	r: number,
	w: number,
	h: number,
	full: boolean?,
	fade: number,
}
local rings: { [Model]: Ring } = {}
local nextAt: { [Model]: number } = {} -- os.clock() of a far ring's next update
local fading: { [Ring]: number } = {} -- ring -> os.clock() they left the water
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

local function newRing(): Ring
	local p = Instance.new("Part")
	p.Name = "PickupRing"
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = folder
	local ring: Ring = { anchor = p, tiles = {}, studs = {}, r = 0, w = 0, h = 0, fade = 0 }
	for k = 1, TILES do
		local tile = Instance.new("BoxHandleAdornment")
		tile.Adornee = p
		tile.Parent = p
		ring.tiles[k] = tile
		local stud = Instance.new("CylinderHandleAdornment")
		stud.Adornee = p
		stud.Parent = p
		ring.studs[k] = stud
	end
	return ring
end

-- lay the tiles round the circle (outer chords meet; the inner corners overlap) with a stud on each
local function layout(ring: Ring, r: number, w: number, h: number)
	if
		math.abs(r - ring.r) < 0.05
		and math.abs(w - ring.w) < w * 0.03
		and math.abs(h - ring.h) < 0.03
	then
		return
	end
	ring.r, ring.w, ring.h = r, w, h
	local chord = 2 * r * math.sin(math.pi / TILES)
	local sh = math.max(h * 0.5, 0.12)
	for k, tile in ring.tiles do
		local lift = if (k - 1) // PER_QUARTER % 2 == 0 then LIFT else 0
		local at = CFrame.Angles(0, (k - 0.5) * 2 * math.pi / TILES, 0)
			* CFrame.new(0, lift, -(r - w / 2))
		tile.Size = Vector3.new(chord, h, w)
		tile.CFrame = at
		local stud = ring.studs[k]
		stud.Radius = w * 0.3
		stud.Height = sh
		stud.CFrame = at * CFrame.new(0, (h + sh) / 2, 0) * CFrame.Angles(math.pi / 2, 0, 0) -- the axis (Z) up
	end
end

local function paint(ring: Ring, full: boolean, fade: number)
	if ring.full == full and math.abs(ring.fade - fade) < 0.01 then
		return
	end
	ring.full, ring.fade = full, fade
	for k, tile in ring.tiles do
		local red = (k - 1) // PER_QUARTER % 2 == 0
		local c = if full then (if red then GREY else PALE) elseif red then RED else WHITE
		local t = (if full then 0.6 else 0.05) + (1 - (if full then 0.6 else 0.05)) * fade
		tile.Color3, tile.Transparency = c, t
		ring.studs[k].Color3, ring.studs[k].Transparency = c, t
	end
end

local function step()
	local props = Workspace:FindFirstChild("CallProps")
	local craft = seatedCraft()
	local full = craft ~= nil and not Board.hasRoom(craft)
	local root = craft and craft.PrimaryPart
	-- your craft's reach, plus the Captain skill's extra studs (SkillService)
	local reachAdd = tonumber(Players.LocalPlayer:GetAttribute("SkillReach")) or 0
	local ring = if root then Board.ringFor(root.Size.X / 2, reachAdd) else Board.RING + reachAdd
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
			local far = if cam then (cam.CFrame.Position - at).Magnitude else 0
			if far < MARK_FAR and far > MARK_NEAR then
				table.insert(near, { m = v, d = far })
			end
			local clock = os.clock()
			if far > SLOW_FAR and clock < (nextAt[v] or 0) then
				continue
			end
			nextAt[v] = clock + SLOW_EVERY
			local ok, h = pcall(Weather.heightAt, at)
			-- wider and taller far off: a flat 1.4-stud band vanished at a grazing angle (playtest 2026-10-26)
			local tall = math.clamp(far / 150, 0.2, 1.2)
			layout(band, ring, math.clamp(far * FAR_WIDTH, BAND, ring / 2), tall)
			band.anchor.CFrame = CFrame.new(
				at.X,
				(if ok and type(h) == "number" then h else at.Y) + 0.15 + tall / 2,
				at.Z
			)
			paint(band, full, 0)
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	-- one pip per on-screen cluster (owner 2026-11-01: two swimmers' pips stacked over the cove mouth)
	local points: { Vector2 } = {}
	for i, n in near do
		local sp = if cam
			then cam:WorldToViewportPoint((n.m.PrimaryPart :: BasePart).Position)
			else Vector3.new(i * MARK_PX, 0, 0)
		points[i] = Vector2.new(sp.X, sp.Y)
	end
	local free = Board.pipShown(points, MARK_PX)
	local kept: { { m: Model, d: number } } = {}
	for i, n in near do
		if free[i] and #kept < MARK_MAX then
			table.insert(kept, n)
		end
	end
	near = kept
	for i = 1, math.max(#marks, #near) do
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
			nextAt[v] = nil
			fading[band] = os.clock()
		end
	end
	for band, t0 in fading do
		local u = (os.clock() - t0) / FADE
		if u >= 1 then
			band.anchor:Destroy()
			fading[band] = nil
		else
			layout(band, ring * (1 + 0.5 * u), band.w, band.h)
			paint(band, false, u)
		end
	end
end

-- The helm the driven craft gets near the nearest waiting survivor (unchanged with no room or none near).
-- Only a hands-off helm is nudged onto them; the throttle is always the player's (docs/24 A: no auto-brake).
function PickupRingController.Assist(craft: Model, input: number, steer: number): (number, number)
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
	if dist < 0.5 or dist > Board.OUTER then
		return input, steer
	end
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = if flatLook.Magnitude > 1e-3 then flatLook.Unit else Vector3.zAxis
	local right = flatLook:Cross(Vector3.yAxis)
	local side, ahead = to:Dot(right), to:Dot(flatLook)
	local bearing = math.deg(math.atan2(side, ahead))
	return input, Board.nudge(steer, bearing, dist)
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
