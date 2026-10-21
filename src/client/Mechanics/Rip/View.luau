--!strict
-- Rip/View (client): the visible rip off Haven Sands (docs/09 section 8.4) — a slightly darker,
-- calmer band of water between the banks, whitewater breaking on both banks with a gap over the
-- channel, and thin foam streaks drifting seaward (plus the floating kit it carries out: a body
-- board, a rescue board, a rescue tube). Everything is low-transparency, textured foam and follows
-- the drawn ocean surface (OceanController.GetVisualHeight), so it sits on the swell instead of
-- lying on it as flat slabs. Client-local: the flow is the pure field (shared/RipCurrent), the same
-- current the server drifts casualties with and SwimController swims in. OpsController calls
-- start() once (the channel shows itself when the player is near) and sync(state) on every
-- operation snapshot (a rip tasking speaks its radio line, once per operation).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Client = script.Parent.Parent.Parent
local Flipbooks =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fx"):WaitForChild("Flipbooks"))
local Radio = require(Client:WaitForChild("Controllers"):WaitForChild("RadioController"))
local RipCurrent = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("RipCurrent"))

local View = {}

View.NEAR = 1200 -- studs: show the channel this close (the station is about 1100 out) -- tune
View.FAR = 1450 -- studs: take it away again beyond this
View.SEGMENT = 16 -- studs per band segment
View.STREAKS = 12 -- foam streaks streaming out
View.SURF = 10 -- whitewater patches per bank
View.STRIPS = 5 -- band strips across the channel (soft edges)

local F = RipCurrent.HavenSands
local DIR = RipCurrent.unit(F)
local SDIR = RipCurrent.shoreParallel(F)
local HALF = F.width / 2

type Band = { p: Part, c: Vector3, ax: Vector3, az: Vector3, w: number, l: number }
type Surf = { p: Part, c: Vector3, d: Decal, base: number, phase: number }

local rng = Random.new()
local folder: Folder? = nil
local attached = false
local started = false
local streaks: { Part } = {}
local kit: { { part: Part, t: number, s: number } } = {}
local band: { Band } = {}
local surf: { Surf } = {}
local board: Part? = nil
local boardFor: Model? = nil -- the body-boarder's victim model (drawn while attached)
local tasked: string? = nil -- the rip operation whose tasking line has been spoken

local ocean: any = nil
local swellAcc = 0

local function at(t: number, s: number, y: number): Vector3
	local p = RipCurrent.point(F, t, s)
	return Vector3.new(p.X, y, p.Z)
end

local function part(name: string, size: Vector3, colour: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = transparency
	p.Parent = folder
	return p
end

-- Surface Y as drawn this frame (the ocean mesh's own wave height); flat sea until it is hooked.
local function surface(x: number, z: number): number
	if ocean and type(ocean.GetVisualHeight) == "function" then
		local ok, h = pcall(ocean.GetVisualHeight, x, z)
		if ok and type(h) == "number" then
			return h
		end
	end
	return 0
end

-- A flat foam map (not a block of colour): the decal's alpha is the only thing drawn.
local function foam(p: Part, sheet: string, transparency: number): Decal
	local d = Instance.new("Decal")
	d.Name = "Foam"
	d.Face = Enum.NormalId.Top
	d.Texture = Flipbooks.id(sheet)
	d.Transparency = transparency
	d.Color3 = Color3.fromRGB(232, 240, 238)
	d.Parent = p
	return d
end

-- Lay a part on the swell: sample its four corners, sit its centre on the mean height and tilt it
-- to the local slope (so a long strip follows the wave instead of clipping through it).
local function fit(
	p: Part,
	c: Vector3,
	ax: Vector3,
	w: number,
	az: Vector3,
	l: number,
	lift: number
)
	local hA = surface(c.X - az.X * l * 0.5, c.Z - az.Z * l * 0.5)
	local hB = surface(c.X + az.X * l * 0.5, c.Z + az.Z * l * 0.5)
	local hL = surface(c.X - ax.X * w * 0.5, c.Z - ax.Z * w * 0.5)
	local hR = surface(c.X + ax.X * w * 0.5, c.Z + ax.Z * w * 0.5)
	local y = (hA + hB + hL + hR) * 0.25 + lift
	local ta = (az + Vector3.yAxis * ((hB - hA) / l)).Unit
	local tx = (ax + Vector3.yAxis * ((hR - hL) / w)).Unit
	local n = tx:Cross(ta).Unit
	if n.Y < 0 then
		n = -n
	end
	local vx = (ax - n * ax:Dot(n)).Unit
	p.CFrame = CFrame.fromMatrix(Vector3.new(c.X, y, c.Z), vx, n)
end

local function randomSpot(): (number, number)
	return rng:NextNumber(8, F.length * 0.35), rng:NextNumber(-HALF * 0.75, HALF * 0.75)
end

local function recycle(i: number)
	local t, s = randomSpot()
	local p = at(t, s, 0)
	local streak = streaks[i]
	streak.CFrame = CFrame.lookAt(Vector3.new(p.X, surface(p.X, p.Z) + 0.08, p.Z), p + DIR)
	local foamDecal = streak:FindFirstChild("Foam")
	if foamDecal and foamDecal:IsA("Decal") then
		foamDecal.Transparency = rng:NextNumber(0.45, 0.7)
	end
end

local function waterTint(): Color3
	local c = Lighting:GetAttribute("OceanWaterColor")
	local base = if typeof(c) == "Color3" then c else Color3.fromRGB(54, 88, 94)
	-- a rip reads darker and a touch greener than the water around it
	return Color3.new(base.R * 0.62, base.G * 0.74, base.B * 0.78)
end

-- Lay the standing pieces on the swell and let the surf breathe (a slow whitewater pulse).
local function swell(now: number)
	for _, b in band do
		fit(b.p, b.c, b.ax, b.w, b.az, b.l, 0.06)
	end
	for _, s in surf do
		fit(s.p, s.c, DIR, s.p.Size.X, SDIR, s.p.Size.Z, 0.09)
		s.d.Transparency = math.clamp(s.base + 0.1 * math.sin(now * 0.55 + s.phase), 0.2, 0.8)
	end
end

local function build()
	local f = Instance.new("Folder")
	f.Name = "RipCurrentView"
	f.Parent = Workspace
	folder = f
	-- the darker, calmer band: overlapping low-alpha strips across the channel, faded at both ends
	local tint = waterTint()
	local w = F.width / View.STRIPS
	for i = 1, View.STRIPS do
		local s = -HALF + w * (i - 0.5)
		local edge = math.abs(s) / HALF
		local alpha = 0.09 + 0.11 * (1 - edge * edge)
		for t = 0, F.length - View.SEGMENT, View.SEGMENT do
			local mid = t + View.SEGMENT / 2
			local near = math.clamp(t / 24, 0, 1)
			local far = math.clamp((F.length - mid) / (F.length * 0.3), 0, 1)
			local a = alpha
				* near
				* (0.35 + 0.65 * far)
				* (0.9 + 0.1 * math.sin(mid * 0.21 + i * 1.7))
			local size = Vector3.new(w + 0.35, 0.04, View.SEGMENT + 0.7)
			local p = part("RipBand", size, tint, 1 - a)
			band[#band + 1] = {
				p = p,
				c = at(mid, s, 0),
				ax = SDIR,
				az = DIR,
				w = size.X,
				l = size.Z,
			}
		end
	end
	-- whitewater breaking on both banks, leaving the channel itself smooth and unbroken
	for side = -1, 1, 2 do
		for i = 1, View.SURF do
			local t = 10 + (F.length - 40) * ((i - 0.5 + rng:NextNumber(-0.25, 0.25)) / View.SURF)
			local s = side * (HALF * 0.92 + rng:NextNumber(3, 16))
			local c = at(t, s, 0)
			local size = Vector3.new(rng:NextNumber(5, 8), 0.04, rng:NextNumber(8, 18))
			local p = part("Surf", size, Color3.new(1, 1, 1), 1)
			local d = foam(p, "FX_Foam_Swash", rng:NextNumber(0.3, 0.55))
			surf[#surf + 1] = {
				p = p,
				c = c,
				d = d,
				base = d.Transparency,
				phase = rng:NextNumber(0, math.pi * 2),
			}
		end
	end
	-- thin foam streaks streaming out with the flow
	for i = 1, View.STREAKS do
		local p = part(
			"DriftFoam",
			Vector3.new(rng:NextNumber(1.2, 2), 0.04, rng:NextNumber(4, 8)),
			Color3.new(1, 1, 1),
			1
		)
		foam(p, "FX_Foam_CrestStreak", rng:NextNumber(0.45, 0.7))
		streaks[i] = p
	end
	-- floating kit carried out: a rescue board, a rescue tube, a body board
	local looks: { { size: Vector3, colour: Color3 } } = {
		{ size = Vector3.new(7, 0.5, 1.8), colour = Color3.fromRGB(235, 120, 30) },
		{ size = Vector3.new(2.2, 0.7, 2.2), colour = Color3.fromRGB(250, 200, 40) },
		{ size = Vector3.new(3.5, 0.35, 1.6), colour = Color3.fromRGB(60, 110, 190) },
	}
	for i, look in looks do
		kit[i] = {
			part = part("FloatingKit", look.size, look.colour, 0.05),
			t = 30 + i * 25,
			s = (i - 2) * 14,
		}
	end
	swell(0)
end

local function clear()
	table.clear(streaks)
	table.clear(kit)
	table.clear(band)
	table.clear(surf)
	board, boardFor = nil, nil
	local f = folder
	folder = nil
	if f then
		f:Destroy()
	end
end

-- one frame of drift: foam and kit ride the current, the body board rides the casualty
local function drift(dt: number)
	for i, p in streaks do
		local pos = p.Position
		local vel = RipCurrent.velocityAt(F, Vector3.new(pos.X, 0, pos.Z))
		if vel.Magnitude < 0.2 then
			recycle(i)
		else
			local moved = pos + vel * dt
			local y = surface(moved.X, moved.Z) + 0.08
			local at_ = Vector3.new(moved.X, y, moved.Z)
			p.CFrame = CFrame.lookAt(at_, at_ + DIR)
		end
	end
	for _, k in kit do
		local flow = RipCurrent.velocityAt(F, at(k.t, k.s, 0))
		k.t += flow.Magnitude * dt
		if k.t > F.length * 0.92 then
			k.t, k.s = randomSpot()
		end
		local flat = at(k.t, k.s, 0)
		local bob = surface(flat.X, flat.Z) + 0.2 + math.sin(os.clock() * 1.1 + k.t * 0.05) * 0.15
		local p = at(k.t, k.s, bob)
		k.part.CFrame = CFrame.lookAt(p, p + flow + Vector3.new(0.01, 0, 0.01))
	end
	-- the body-boarder's board under the casualty
	if boardFor and boardFor.Parent and boardFor.PrimaryPart then
		if not board then
			board = part("BodyBoard", Vector3.new(3.5, 0.35, 1.6), Color3.fromRGB(60, 110, 190), 0)
		end
		local root = boardFor.PrimaryPart.Position
		local c = Vector3.new(root.X, surface(root.X, root.Z) + 0.55, root.Z)
		local b = board :: Part
		b.CFrame = CFrame.lookAt(c, c + DIR)
	elseif board then
		board:Destroy()
		board = nil
	end
end

local function victimOf(opId: string): Model?
	local props = Workspace:FindFirstChild("CallProps")
	if not props then
		return nil
	end
	for _, m in props:GetChildren() do
		if m:IsA("Model") and m:GetAttribute("CallId") == opId then
			return m
		end
	end
	return nil
end

-- A rip tasking (OpsController's state hook): speak the Coastguard line once per operation,
-- and watch for the body-boarder's board.
function View.sync(state: { [string]: any }?)
	if not (state and state.kind == "RipCurrent" and type(state.opId) == "string") then
		return
	end
	local victim = victimOf(state.opId)
	boardFor = if victim and victim:GetAttribute("RipBoard") == true then victim else nil
	if tasked == state.opId then
		return
	end
	tasked = state.opId
	local cas = state.casualties and state.casualties[1]
	Radio.say("tasking_rip", {
		optype = "PIW1",
		direction = "OFF",
		place = "HAVEN_SANDS",
		casDesc = if boardFor then "PADDLEBOARDER" else "ADULT_SWIMMER",
		casKit = if boardFor then "CLINGING" elseif cas and cas.lifejacket then "LJ" else "NO_LJ",
		casState = "CAUGHT_RIP",
	})
end

local function hookOcean()
	local controllers = Client:FindFirstChild("Controllers")
	local module = controllers and controllers:FindFirstChild("OceanController")
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require :: any, module)
		if ok and type(result) == "table" then
			ocean = result
		end
	end
end

-- The channel shows itself when the player is near Haven Sands (it is geography, not a step).
function View.start()
	if started then
		return
	end
	started = true
	hookOcean()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if attached then
			drift(dt)
			swellAcc += dt
			if swellAcc >= 1 / 15 then
				swell(os.clock())
				swellAcc = 0
			end
		end
		acc += dt
		if acc < 0.5 then
			return
		end
		acc = 0
		local char = Players.LocalPlayer.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local pos = if root and root:IsA("BasePart") then root.Position else nil
		local mid = at(F.length * 0.45, 0, 0)
		local d = if pos
			then (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(mid.X, 0, mid.Z)).Magnitude
			else 1e9
		if not attached and d < View.NEAR then
			attached = true
			build()
			for i in streaks do
				recycle(i)
			end
		elseif attached and d > View.FAR then
			attached = false
			clear()
		end
	end)
end

return View
