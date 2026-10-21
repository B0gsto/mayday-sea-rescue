--!strict
-- SinkingScene (server): the fishing boat's world (docs/09 section 8.1, LU-3). A code-built
-- trawler lies off the harbour with its crew on the cabin roof; she lists and settles as the
-- bilge floods (shared/SinkingVessel), with the leak's swirl and a waterline that climbs her
-- side. The salvage pump, the leak and the crew are the three world actions the client offers.
-- The pump handle rocks while the client keeps the rhythm, and the leak's jet weakens as the bung
-- goes in (the client reports effort on ReplicatedStorage.Net.Sinking_Effort). OperationService
-- calls Spawn on activate, Saved when the save step completes, and Cleanup when the operation
-- closes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RescueDressing = require(script.Parent:WaitForChild("RescueDressing"))
local SinkingVessel =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SinkingVessel"))

type Crew = { model: Model, parts: { BasePart } }

type Rec = {
	opId: string,
	folder: Folder,
	model: Model,
	hull: BasePart,
	leak: BasePart,
	pump: BasePart,
	handle: BasePart,
	handleLocal: CFrame,
	crew: { Crew },
	base: CFrame,
	state: SinkingVessel.State,
	conn: RBXScriptConnection?,
	pumping: boolean,
	plugging: boolean,
	beat: boolean,
	plugged: boolean,
	evacuated: boolean,
	shownPlug: number,
	plugShown: boolean,
}

local SinkingScene = {}

local live: { [any]: Rec } = setmetatable({}, { __mode = "k" }) :: any
local byOpId: { [string]: Rec } = {}

-- C->S effort from the save mechanic: ("<opId>", "beat") or ("<opId>", "plug", holding).
local EFFORT_REMOTE = "Sinking_Effort"
local effortHooked = false

local function ensureEffortRemote(): RemoteEvent
	local net = ReplicatedStorage:FindFirstChild("Net")
	if not net then
		net = Instance.new("Folder")
		net.Name = "Net"
		net.Parent = ReplicatedStorage
	end
	local existing = net:FindFirstChild(EFFORT_REMOTE)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = EFFORT_REMOTE
	created.Parent = net
	return created
end

local function hookEffort()
	if effortHooked then
		return
	end
	effortHooked = true
	ensureEffortRemote().OnServerEvent:Connect(
		function(_player: Player, opId: any, action: any, value: any)
			if type(opId) ~= "string" or type(action) ~= "string" then
				return
			end
			local rec = byOpId[opId]
			if not rec then
				return
			end
			if action == "beat" then
				rec.beat = true
			elseif action == "plug" then
				rec.plugging = value == true and not rec.state.plugged
			end
		end
	)
end

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent
	return p
end

-- A code-built person for the cabin roof (no rig asset needed for a placeholder scene).
local function person(parent: Instance, index: number, cf: CFrame): Crew
	local model = Instance.new("Model")
	model.Name = `Crew{index}`
	model.Parent = parent
	local parts: { BasePart } = {}
	local function bit(name: string, size: Vector3, offset: CFrame, colour: Color3): Part
		local p = part(model, name, size, cf * offset, colour)
		table.insert(parts, p)
		return p
	end
	local torso =
		bit("Torso", Vector3.new(2, 2, 1.1), CFrame.new(0, 3, 0), Color3.fromRGB(240, 140, 30))
	bit("Head", Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, 4.8, 0), Color3.fromRGB(214, 168, 130))
	bit("LeftLeg", Vector3.new(0.8, 2, 0.8), CFrame.new(-0.5, 1, 0), Color3.fromRGB(40, 55, 70))
	bit("RightLeg", Vector3.new(0.8, 2, 0.8), CFrame.new(0.5, 1, 0), Color3.fromRGB(40, 55, 70))
	bit("LeftArm", Vector3.new(0.7, 2, 0.7), CFrame.new(-1.4, 3, 0), Color3.fromRGB(60, 80, 100))
	bit("RightArm", Vector3.new(0.7, 2, 0.7), CFrame.new(1.4, 3, 0), Color3.fromRGB(60, 80, 100))
	model.PrimaryPart = torso
	model:SetAttribute("Crew", true)
	return { model = model, parts = parts }
end

-- The wooden bung goes in once the client has pushed it home.
local function plugVisual(rec: Rec)
	if rec.model:FindFirstChild("Plug") then
		return
	end
	part(
		rec.model,
		"Plug",
		Vector3.new(1.8, 1.8, 1.2),
		rec.leak.CFrame,
		Color3.fromRGB(140, 100, 60)
	)
	rec.folder:SetAttribute("Plugged", true)
end

local function buildCrew(model: Model, n: number)
	local crew = {}
	for i = 1, n do
		local x = (i - (n + 1) / 2) * 3.2
		table.insert(crew, person(model, i, CFrame.new(x, 12.2, -4)))
	end
	return crew
end

function SinkingScene.Spawn(scene: any)
	if live[scene] then
		return
	end
	local callProps = Workspace:FindFirstChild("CallProps")
	if not callProps then
		callProps = Instance.new("Folder")
		callProps.Name = "CallProps"
		callProps.Parent = Workspace
	end
	local folder = Instance.new("Folder")
	folder.Name = `Sinking_{scene.opId}`
	folder.Parent = callProps

	local model = Instance.new("Model")
	model.Name = "SinkingBoat"
	model.Parent = folder

	local hull =
		part(model, "Hull", Vector3.new(24, 7, 52), CFrame.new(), Color3.fromRGB(224, 226, 220))
	hull.Material = Enum.Material.SmoothPlastic
	model.PrimaryPart = hull
	part(model, "Keel", Vector3.new(22, 2, 50), CFrame.new(0, -3.4, 0), Color3.fromRGB(150, 44, 40))
	part(
		model,
		"Cabin",
		Vector3.new(14, 8, 18),
		CFrame.new(0, 7.5, -4),
		Color3.fromRGB(236, 238, 232)
	)
	part(
		model,
		"Roof",
		Vector3.new(15.5, 0.7, 19.5),
		CFrame.new(0, 11.85, -4),
		Color3.fromRGB(200, 202, 196)
	)
	part(
		model,
		"Wheelhouse",
		Vector3.new(12.4, 2.2, 1),
		CFrame.new(0, 8.7, -13.1),
		Color3.fromRGB(40, 60, 78),
		Enum.Material.Glass
	)
	local gunwale = Color3.fromRGB(190, 60, 50)
	part(model, "RailPort", Vector3.new(0.4, 0.8, 48), CFrame.new(-11.8, 3.9, 0), gunwale)
	part(model, "RailStarboard", Vector3.new(0.4, 0.8, 48), CFrame.new(11.8, 3.9, 0), gunwale)
	part(
		model,
		"Mast",
		Vector3.new(0.8, 12, 0.8),
		CFrame.new(0, 18, -9),
		Color3.fromRGB(90, 94, 98)
	)
	part(
		model,
		"Boom",
		Vector3.new(0.6, 0.6, 14),
		CFrame.new(0, 23, -2),
		Color3.fromRGB(90, 94, 98)
	)
	part(
		model,
		"NameBoard",
		Vector3.new(7, 1.6, 0.3),
		CFrame.new(0, 3.9, -26.2),
		Color3.fromRGB(24, 40, 58)
	)

	RescueDressing.apply(model, scene.variant, { root = hull :: BasePart, large = true })

	-- the salvage pump on the after deck, with its hose already led over the side
	local pump = part(
		model,
		"SalvagePump",
		Vector3.new(3.2, 2.2, 2.6),
		CFrame.new(-4.5, 4.6, 16),
		Color3.fromRGB(250, 190, 30)
	)
	pump.Material = Enum.Material.Metal
	local handleLocal = CFrame.new(-4.5, 5.9, 16)
	local handle = part(
		model,
		"PumpHandle",
		Vector3.new(4.4, 0.4, 0.4),
		handleLocal,
		Color3.fromRGB(40, 40, 44),
		Enum.Material.Metal
	)
	local hoseA = Instance.new("Attachment")
	hoseA.Position = Vector3.new(0, 0, 1.4)
	hoseA.Parent = pump
	local hoseB = Instance.new("Attachment")
	hoseB.Position = Vector3.new(14.2, 1.6, 16)
	hoseB.Parent = hull
	local hose = Instance.new("Beam")
	hose.Name = "PumpHose"
	hose.Attachment0 = hoseA
	hose.Attachment1 = hoseB
	hose.Width0 = 0.5
	hose.Width1 = 0.5
	hose.CurveSize0 = 3
	hose.CurveSize1 = -4
	hose.Color = ColorSequence.new(Color3.fromRGB(30, 30, 34))
	hose.LightInfluence = 0.3
	hose.Parent = model

	-- where the water comes in: a bright swirl and bubbles on the starboard quarter
	local leak = part(
		model,
		"LeakPoint",
		Vector3.new(2.2, 2.2, 2.2),
		CFrame.new(12.2, 0.4, 6),
		Color3.fromRGB(225, 245, 255),
		Enum.Material.Neon
	)
	leak.Shape = Enum.PartType.Ball
	leak.Transparency = 0.25
	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "LeakSwirl"
	bubbles.Rate = 22
	bubbles.Lifetime = NumberRange.new(0.4, 0.9)
	bubbles.Speed = NumberRange.new(1, 3)
	bubbles.SpreadAngle = Vector2.new(18, 18)
	bubbles.Size = NumberSequence.new(0.5, 0.1)
	bubbles.Color = ColorSequence.new(Color3.fromRGB(235, 250, 255))
	bubbles.Transparency = NumberSequence.new(0.2, 1)
	bubbles.Parent = leak

	local crew = buildCrew(model, math.clamp(scene.pob or SinkingVessel.Rates.Crew, 1, 4))

	-- the sea's edge on her side: a fixed white line the hull settles through
	local foam = part(
		folder,
		"Waterline",
		Vector3.new(30, 0.12, 58),
		CFrame.new(scene.position.X, 0.22, scene.position.Z) * CFrame.Angles(0, math.rad(18), 0),
		Color3.fromRGB(245, 250, 252),
		Enum.Material.SmoothPlastic
	)
	foam.Transparency = 0.45

	local base = CFrame.new(scene.position.X, 0, scene.position.Z)
		* CFrame.Angles(0, math.rad(18), 0)
	model:PivotTo(base)
	folder:SetAttribute("OpId", scene.opId)
	hull:SetAttribute("Flood", SinkingVessel.Rates.StartFlood)

	local rec: Rec = {
		opId = scene.opId,
		folder = folder,
		model = model,
		hull = hull,
		leak = leak,
		pump = pump,
		handle = handle,
		handleLocal = handleLocal,
		crew = crew,
		base = base,
		state = SinkingVessel.new(),
		conn = nil,
		pumping = false,
		plugging = false,
		beat = false,
		plugged = false,
		evacuated = false,
		shownPlug = 0,
		plugShown = false,
	}
	rec.state.crew = #crew
	hookEffort()
	rec.conn = RunService.Heartbeat:Connect(function(dt)
		local r = live[scene]
		if not r or not r.folder.Parent then
			return
		end
		local beat = r.beat
		r.beat = false
		SinkingVessel.step(r.state, math.min(dt, 0.5), {
			pump = r.state.pump or r.pumping,
			plug = r.plugging,
			beat = beat,
		})
		local f = r.state.flood
		r.hull:SetAttribute("Flood", math.floor(f * 1000 + 0.5) / 1000)
		r.hull:SetAttribute("List", math.deg(r.state.list))
		r.hull:SetAttribute("Sunk", r.state.sunk)
		local plug = SinkingVessel.plugProgress(r.state)
		r.folder:SetAttribute("Plug", math.floor(plug * 1000 + 0.5) / 1000)
		if math.abs(plug - r.shownPlug) > 0.01 or (r.state.plugged and not r.plugShown) then
			r.shownPlug = plug
			local emitter = r.leak:FindFirstChildOfClass("ParticleEmitter")
			if emitter then
				emitter.Rate = 22 * (1 - 0.85 * plug)
			end
			r.leak.Transparency = math.min(1, 0.25 + 0.7 * plug)
			if r.state.plugged then
				r.plugShown = true
				plugVisual(r)
			end
		end
		r.model:PivotTo(
			r.base
				* CFrame.new(0, -SinkingVessel.settle(r.state), 0)
				* CFrame.Angles(0, 0, r.state.list)
		)
		if r.handle.Parent then
			local rock = math.sin(r.state.elapsed * (2 * math.pi / SinkingVessel.Rates.Beat))
				* 0.4
				* (0.2 + 0.8 * r.state.pumpEffort)
			r.handle.CFrame = r.model:GetPivot() * r.handleLocal * CFrame.Angles(0, 0, rock)
		end
	end)
	live[scene] = rec
	byOpId[rec.opId] = rec
end

-- The save step completed: whichever way the crew chose, the water starts to lose.
function SinkingScene.Saved(scene: any, _by: Player?, metrics: { [string]: number | boolean }?)
	local rec = live[scene]
	if not rec then
		return
	end
	local m: { [string]: number | boolean } = metrics or {}
	if m.pump == 1 or m.pump == true then
		rec.pumping = true
		rec.state.pump = true
		rec.folder:SetAttribute("Pump", true)
	end
	if m.plugged == 1 or m.plugged == true then
		rec.plugged = true
		rec.state.plugged = true
		rec.state.plug = 1
		rec.leak.Transparency = 1
		local emitter = rec.leak:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Enabled = false
		end
		plugVisual(rec)
	end
	if m.evacuated == 1 or m.evacuated == true then
		for _, c in rec.crew do
			c.model:Destroy()
		end
		rec.crew = {}
		rec.state.crew = 0
		rec.evacuated = true
		rec.folder:SetAttribute("Evacuated", true)
	end
end

function SinkingScene.Cleanup(scene: any)
	local rec = live[scene]
	if not rec then
		return
	end
	live[scene] = nil
	byOpId[rec.opId] = nil
	if rec.conn then
		rec.conn:Disconnect()
		rec.conn = nil
	end
	if rec.folder.Parent then
		rec.folder:Destroy()
	end
end

return SinkingScene
