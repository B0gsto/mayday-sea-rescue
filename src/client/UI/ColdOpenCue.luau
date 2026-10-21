--!strict
-- ColdOpenCue: the cold open's world cues (docs/14 F-3, RP-UX2), local only. While the player
-- rides the cold-open jet ski, the casualty (CallProps "Victim" of ColdOpenOpId) gets a thin
-- orange ring on the water, a pulse ring spreading from it, orange smoke and splashes (and the
-- casualty waves: CasualtyController), so the goal reads from the world with no text to read. If the player makes no headway
-- for 10 s (shared/Boat/ColdOpen.nudge) a red flare pops over them. All of it goes once the
-- casualty holds on (PiwMode "held") or the cold open ends. Then the way in shows: orange smoke
-- and a pulse ring at each shore point (ColdOpen.SHORE: the station slipway, Haven Sands), and
-- after 10 s without headway toward land the smoke thickens and a flare pops over the nearest one.
-- Started by OpsHud.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local Weather = require(Shared:WaitForChild("Weather"))

local ColdOpenCue = {}

local ORANGE = Color3.fromRGB(255, 120, 20)
local PULSE = 1.6 -- s per ring
local RING_MAX = 40 -- studs across at the end of a pulse (26 read too small at range: playtest)
local MARK = 10 -- studs across the steady ring round the casualty

-- The marker lies on the water, not on the casualty's root (which can sit a stud under it).
local function waterY(p: Vector3): number
	local ok, h = pcall(Weather.heightAt, p)
	return if ok and type(h) == "number" then h else p.Y
end

local function craftOpId(): string?
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local node: Instance? = hum and hum.SeatPart
	while node do
		local id = node:GetAttribute("ColdOpenOpId")
		if node:IsA("Model") and type(id) == "string" then
			return id
		end
		node = node.Parent
	end
	return nil
end

local function victimOf(opId: string): Model?
	local folder = Workspace:FindFirstChild("CallProps")
	for _, m in if folder then folder:GetChildren() else {} do
		if m:IsA("Model") and m.Name == "Victim" and m:GetAttribute("CallId") == opId then
			return if m.PrimaryPart then m else nil
		end
	end
	return nil
end

export type Ring = { anchor: Part, band: CylinderHandleAdornment }

-- A thin ring lying on the water (a hollow cylinder adornment on an invisible anchor), not a
-- filled disc: it marks the spot without hiding the casualty.
local function ring(name: string, color: Color3, parent: Instance): Ring
	local p = Instance.new("Part")
	p.Name = name
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.Parent = parent
	local band = Instance.new("CylinderHandleAdornment")
	band.Adornee = p
	band.Color3 = color
	band.Height = 0.05
	band.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- the cylinder's axis (Z) up
	band.Parent = p
	return { anchor = p, band = band }
end

-- Places a ring flat at `at`, `across` studs wide; the band is a tenth of the radius (>= 0.25).
local function setRing(r: Ring, at: Vector3, across: number, transparency: number)
	local radius = across / 2
	r.anchor.CFrame = CFrame.new(at)
	r.band.Radius = radius
	r.band.InnerRadius = math.max(radius - math.max(radius * 0.1, 0.25), 0)
	r.band.Transparency = transparency
end

local function smoke(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Smoke_Orange")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 190, 140))
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 10) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = 10
	e.Speed = NumberRange.new(3, 5)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Acceleration = Vector3.new(1.5, 0.8, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

local function splash(parent: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 255))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	e.Transparency =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Rate = 0 -- bursts, timed with the call
	e.Speed = NumberRange.new(7, 12)
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- A red parachute flare: shoots up over `at`, hangs and drifts down, lighting the sea.
local function flare(at: Vector3, parent: Instance)
	local p = Instance.new("Part")
	p.Name = "Flare"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(1.4, 1.4, 1.4)
	p.Material = Enum.Material.Neon
	p.Color = Color3.fromRGB(255, 40, 30)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Position = at
	local light = Instance.new("PointLight")
	light.Color = p.Color
	light.Range = 60
	light.Brightness = 4
	light.Parent = p
	local trail = Instance.new("ParticleEmitter")
	trail.Color = ColorSequence.new(Color3.fromRGB(255, 230, 225))
	trail.Size = NumberSequence.new(1, 3)
	trail.Transparency = NumberSequence.new(0.4, 1)
	trail.Lifetime = NumberRange.new(2, 3)
	trail.Rate = 40
	trail.Speed = NumberRange.new(0, 0.5)
	trail.Parent = p
	p.Parent = parent
	local up = TweenService:Create(
		p,
		TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = at + Vector3.new(0, 90, 0) }
	)
	up.Completed:Connect(function()
		trail.Rate = 6
		TweenService:Create(p, TweenInfo.new(8, Enum.EasingStyle.Linear), {
			Position = at + Vector3.new(6, 35, 0),
			Transparency = 0.6,
		}):Play()
	end)
	up:Play()
	task.delay(9.6, function()
		p:Destroy()
	end)
end

-- Runs until the returned stop is called. onHeld(held) fires when the casualty takes hold or lets go.
-- `opIdOf` (the first station calls) points the casualty cues at that op's victim instead; no
-- shore cues then (the transport step has its own way home).
function ColdOpenCue.start(onHeld: ((held: boolean) -> ())?, opIdOf: (() -> string?)?): () -> ()
	local folder: Folder? = nil
	local victim: Model? = nil
	local splashes: ParticleEmitter? = nil
	local mark: Ring? = nil
	local pulse: Ring? = nil
	local nudge = ColdOpen.newNudge(os.clock())
	local lastBurst = 0
	local shore: Folder? = nil
	local shoreSmoke: { ParticleEmitter } = {}
	local shoreRings: { Ring } = {}
	local shoreNudge = ColdOpen.newNudge(os.clock())
	local wasHeld: boolean? = nil

	local function clearShore()
		if shore then
			shore:Destroy()
		end
		shore, shoreSmoke, shoreRings = nil, {}, {}
	end

	-- the way in: smoke on the dry end of each shore point, a ring on its water
	local function buildShore()
		local f = Instance.new("Folder")
		f.Name = "ColdOpenShore"
		f.Parent = Workspace
		shore = f
		for _, sp in ColdOpen.SHORE do
			local post = Instance.new("Part")
			post.Name = `Smoke_{sp.id}`
			post.Size = Vector3.new(1, 1, 1)
			post.Transparency = 1
			post.Anchored, post.CanCollide, post.CanQuery, post.CanTouch = true, false, false, false
			post.Position = sp.dry + Vector3.new(0, 6, 0)
			post.Parent = f
			local a = Instance.new("Attachment")
			a.Parent = post
			table.insert(shoreSmoke, smoke(a))
			table.insert(shoreRings, ring(`Ring_{sp.id}`, Color3.fromRGB(255, 170, 60), f))
		end
		shoreNudge = ColdOpen.newNudge(os.clock())
	end

	local function clear()
		if folder then
			folder:Destroy()
		end
		folder, victim, splashes, mark, pulse = nil, nil, nil, nil, nil
	end

	local function build(m: Model)
		clear()
		victim = m
		local root = m.PrimaryPart :: BasePart
		local f = Instance.new("Folder")
		f.Name = "ColdOpenCue"
		f.Parent = Workspace
		folder = f
		mark = ring("Mark", ORANGE, f)
		pulse = ring("Pulse", Color3.fromRGB(255, 170, 60), f)
		local a = Instance.new("Attachment")
		a.Name = "ColdOpenCue"
		a.Parent = root
		smoke(a)
		splashes = splash(a)
		-- the attachment lives on the victim, so tie its lifetime to the folder
		f.Destroying:Connect(function()
			a:Destroy()
		end)
		nudge = ColdOpen.newNudge(os.clock())
	end

	local conn = RunService.Heartbeat:Connect(function()
		local opId = if opIdOf then opIdOf() else craftOpId()
		local m = opId and victimOf(opId)
		-- holding on (the old drag) or aboard the craft (auto_board, AddSurvivor sets OnVehicle)
		local held = m ~= nil
			and (m:GetAttribute("PiwMode") == "held" or m:GetAttribute("OnVehicle") ~= nil)
		if m and held ~= wasHeld and onHeld then
			wasHeld = held
			onHeld(held)
		end
		if not m or held then
			clear()
			if not m or opIdOf then
				clearShore()
				return
			end
			if not shore then
				buildShore()
			end
			local t = os.clock()
			local k = (t % PULSE) / PULSE
			for i, sp in ColdOpen.SHORE do
				setRing(
					shoreRings[i],
					Vector3.new(sp.water.X, waterY(sp.water) + 0.08, sp.water.Z),
					6 + k * ColdOpen.SHORE_RADIUS * 2,
					0.25 + 0.75 * k
				)
			end
			-- 10 s rule on the way in: thicker smoke and a flare over the nearest shore
			local root = m.PrimaryPart :: BasePart
			local near, d = ColdOpen.nearestShore(root.Position)
			if shore and ColdOpen.nudge(shoreNudge, t, d) then
				for _, e in shoreSmoke do
					e.Rate = math.min(e.Rate * 1.6, 40)
				end
				flare(near.dry + Vector3.new(0, 4, 0), shore)
			end
			return
		end
		clearShore()
		if m ~= victim then
			build(m)
		end
		local root = m.PrimaryPart :: BasePart
		local t = os.clock()
		local base = Vector3.new(root.Position.X, waterY(root.Position) + 0.08, root.Position.Z)
		local k = (t % PULSE) / PULSE
		if mark and pulse then
			setRing(mark, base, MARK, 0.15)
			setRing(pulse, base, MARK + k * (RING_MAX - MARK), 0.3 + 0.7 * k)
		end
		-- a splash burst every 0.8 s (the waving arms are the call for help)
		if splashes and t - lastBurst > 0.8 then
			lastBurst = t
			splashes:Emit(10)
		end
		-- 10 s rule (docs/14): no headway toward them, the world helps
		local char = Players.LocalPlayer.Character
		local pivot = char and char:GetPivot().Position
		if pivot and folder then
			local d = (Vector3.new(pivot.X, 0, pivot.Z) - Vector3.new(base.X, 0, base.Z)).Magnitude
			if ColdOpen.nudge(nudge, t, d) then
				flare(base, folder)
			end
		end
	end)

	return function()
		conn:Disconnect()
		clear()
		clearShore()
	end
end

return ColdOpenCue
