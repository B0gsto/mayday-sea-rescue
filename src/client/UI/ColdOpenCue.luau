--!strict
-- ColdOpenCue: the cold open's world cues (docs/14 F-3, RP-UX2), local only. While the player
-- rides the cold-open jet ski, the casualty (CallProps "Victim" of ColdOpenOpId) gets a pulse ring
-- spreading on the water (the steady orange ring is PickupRingController's), orange smoke and splashes (and the
-- casualty waves: CasualtyController), so the goal reads from the world with no text to read. If the player makes no headway
-- for 10 s (shared/Boat/ColdOpen.nudge) a red flare pops over them. All of it goes once the
-- casualty holds on (PiwMode "held") or climbs aboard, or the cold open ends.
-- ColdOpenCue.home (docs/20 change 4, every delivery): with survivors aboard, the drop-off pulses
-- green from 60 m (the slipway in the cold open, else the nearest pad), where the green house pin points.
-- Started by OpsHud.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ColdOpen = require(Shared:WaitForChild("Boat"):WaitForChild("ColdOpen"))
local Flipbooks = require(Shared:WaitForChild("Fx"):WaitForChild("Flipbooks"))
local Weather = require(Shared:WaitForChild("Weather"))

-- the photoreal red parachute rocket (flipbooks), the same flare every distress call uses
local PyroController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("PyroController"))

local ColdOpenCue = {}

local GREEN = Color3.fromRGB(90, 225, 120) -- home
local PULSE = 1.6 -- s per ring
local RING_MAX = 40 -- studs across at the end of a pulse (26 read too small at range: playtest)
local MARK = 10 -- studs across where the pulse starts

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

-- Runs until the returned stop is called. onHeld(held) fires when the casualty takes hold or lets go.
-- `opIdOf` (the first station calls) points the casualty cues at that op's victim instead.
function ColdOpenCue.start(onHeld: ((held: boolean) -> ())?, opIdOf: (() -> string?)?): () -> ()
	local folder: Folder? = nil
	local victim: Model? = nil
	local splashes: ParticleEmitter? = nil
	local pulse: Ring? = nil
	local nudge = ColdOpen.newNudge(os.clock())
	local lastBurst = 0
	local wasHeld: boolean? = nil

	local function clear()
		if folder then
			folder:Destroy()
		end
		folder, victim, splashes, pulse = nil, nil, nil, nil
	end

	local function build(m: Model)
		clear()
		victim = m
		local root = m.PrimaryPart :: BasePart
		local f = Instance.new("Folder")
		f.Name = "ColdOpenCue"
		f.Parent = Workspace
		folder = f
		pulse = ring("Pulse", Color3.fromRGB(255, 110, 90), f)
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
			return
		end
		if m ~= victim then
			build(m)
		end
		local root = m.PrimaryPart :: BasePart
		local t = os.clock()
		local base = Vector3.new(root.Position.X, waterY(root.Position) + 0.08, root.Position.Z)
		local k = (t % PULSE) / PULSE
		if pulse then
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
				PyroController.parachute(base)
			end
		end
	end)

	return function()
		conn:Disconnect()
		clear()
	end
end

local HOME_RANGE = ColdOpen.DROP_RADIUS + 180 -- studs: the drop-off starts to pulse 60 m out from its zone -- tune
local HOME_MARK = 14 -- studs across the centre ring; the pulse spreads from it to the zone's edge

-- Where the craft's survivors land: the nearest cold-open slipway while the cold open runs (the
-- server lands them there, OperationService isHome), else your berth's drop-off zone.
local function homePoint(from: Vector3): Vector3?
	local best: Vector3?, bestD = nil, math.huge
	local function consider(p: Vector3)
		local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
		if d < bestD then
			best, bestD = p, d
		end
	end
	if Players.LocalPlayer:GetAttribute("ColdOpenActive") == true then
		for _, sp in ColdOpen.SHORE do
			consider(Vector3.new(sp.water.X, waterY(sp.water) + 0.08, sp.water.Z))
		end
		return best
	end
	local p = ColdOpen.dropOff(Players.LocalPlayer:GetAttribute("BayCFrame"))
	return if p then Vector3.new(p.X, waterY(p) + 0.08, p.Z) else nil
end

-- The local player's craft while they carry survivors, else nil.
local function carryingCraft(): Model?
	local folder = Workspace:FindFirstChild("Vehicles")
	for _, m in if folder then folder:GetChildren() else {} do
		if
			m:IsA("Model")
			and m:GetAttribute("Owner") == Players.LocalPlayer.UserId
			and (tonumber(m:GetAttribute("SurvivorCount")) or 0) > 0
		then
			return m
		end
	end
	return nil
end

-- Every delivery (started once by OnboardingController): a green steady ring on the drop-off zone's edge (land
-- anywhere inside it) and a pulse spreading out to it while your craft carries someone within HOME_RANGE.
function ColdOpenCue.home(): () -> ()
	local folder: Folder? = nil
	local mark: Ring? = nil
	local pulse: Ring? = nil
	local edge: Ring? = nil
	local conn = RunService.Heartbeat:Connect(function()
		local craft = carryingCraft()
		local at = craft and homePoint(craft:GetPivot().Position)
		local near = at and craft and (at - craft:GetPivot().Position) * Vector3.new(1, 0, 1)
		if not (at and near and near.Magnitude <= HOME_RANGE) then
			if folder then
				folder:Destroy()
				folder, mark, pulse, edge = nil, nil, nil, nil
			end
			return
		end
		if not folder then
			local f = Instance.new("Folder")
			f.Name = "HomeCue"
			f.Parent = Workspace
			folder = f
			mark = ring("Mark", GREEN, f)
			pulse = ring("Pulse", GREEN, f)
			edge = ring("Edge", GREEN, f)
		end
		local k = (os.clock() % PULSE) / PULSE
		if mark and pulse and edge then
			local zone = ColdOpen.DROP_RADIUS * 2
			setRing(mark, at, HOME_MARK, 0.1)
			setRing(pulse, at, HOME_MARK + k * (zone - HOME_MARK), 0.2 + 0.8 * k)
			setRing(edge, at, zone, 0.35)
		end
	end)
	return function()
		conn:Disconnect()
		if folder then
			folder:Destroy()
		end
	end
end

return ColdOpenCue
