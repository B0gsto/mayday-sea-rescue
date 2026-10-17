--!strict
-- Kit: the client-side plumbing the tow mechanics share (not pure; the pure maths is in
-- Ballistics, Procedures and Shared/Tow/TowLine). Scene lookup (the casualty boat, our hitch), wind
-- and waves, the visible hands (the camera stream's Viewmodel.playAction, in a pcall), the crew's
-- spoken lines, small diegetic choice cards and the tow link: the TowLine simulation that drives
-- the rope's sag and creak, pulls on our boat and moves the casualty hull on this client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local TowLine = require(Shared:WaitForChild("Tow"):WaitForChild("TowLine"))
local Waves = require(Shared:WaitForChild("Waves"))

local Procedures = require(script.Parent:WaitForChild("Procedures"))

local Kit = {}

Kit.KNOT = 1.543 -- studs/s
-- CONTRACT (audio): a looping rope creak; empty = silent (the sag, drips and thrum still show).
Kit.CREAK_SOUND = ""
Kit.SNAP_SOUND = ""
Kit.N_TO_FORCE = 3 / 37 -- newtons -> RMU * studs/s^2 (1 RMU = 37 kg, 1 m = 3 studs)

---------------------------------------------------------------- scene

local viewmodel: any = nil
local viewmodelTried = false

-- Visible hands. The camera stream owns Viewmodel; it may not exist yet.
function Kit.hands(action: string)
	if not viewmodelTried then
		viewmodelTried = true
		local root = script:FindFirstAncestor("Mechanics")
		local client = root and root.Parent
		local module = client and client:FindFirstChild("Viewmodel", true)
		if module and module:IsA("ModuleScript") then
			local ok, result = pcall(require, module)
			if ok then
				viewmodel = result
			end
		end
	end
	if viewmodel and type(viewmodel.playAction) == "function" then
		pcall(viewmodel.playAction, action)
	end
end

function Kit.casualtyModel(ctx: any): Model?
	local props = Workspace:FindFirstChild("CallProps")
	if not props then
		return nil
	end
	local id = ctx.operation and ctx.operation.id
	local best: Model? = nil
	local bestD = math.huge
	local near = ctx.casualty and ctx.casualty.position or ctx.operation and ctx.operation.position
	for _, child in props:GetChildren() do
		if child:IsA("Model") and child.Name == "DisabledBoat" then
			if child:GetAttribute("CallId") == id then
				return child
			end
			if typeof(near) == "Vector3" then
				local d = (child:GetPivot().Position - near).Magnitude
				if d < bestD then
					best, bestD = child, d
				end
			end
		end
	end
	return best
end

function Kit.vehicleRoot(ctx: any): BasePart?
	local v = ctx.vehicle
	if typeof(v) ~= "Instance" or not v:IsA("Model") then
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local seat = hum and hum.SeatPart
		v = seat and seat:FindFirstAncestorWhichIsA("Model")
		if typeof(v) == "Instance" and v:IsA("Model") then
			ctx.vehicle = v
		else
			return nil
		end
	end
	local model = v :: Model
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
end

function Kit.hitch(root: BasePart): Attachment
	local a = root.Parent and root.Parent:FindFirstChild("TowHitch", true)
	if a and a:IsA("Attachment") then
		return a
	end
	local made = root:FindFirstChild("TowHitchLocal")
	if made and made:IsA("Attachment") then
		return made
	end
	local att = Instance.new("Attachment")
	att.Name = "TowHitchLocal"
	att.Position = Vector3.new(0, 0.6, root.Size.Z / 2)
	att.Parent = root
	return att
end

function Kit.part(model: Model, name: string): BasePart?
	local p = model:FindFirstChild(name, true)
	return if p and p:IsA("BasePart") then p else nil
end

function Kit.people(model: Model): { Vector3 }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Head" or d.Name == "Torso") then
			table.insert(out, d.Position)
		end
	end
	return out
end

local function weatherModule(): any
	local m = Shared:FindFirstChild("Weather")
	if m and m:IsA("ModuleScript") then
		local ok, w = pcall(require, m)
		if ok then
			return w
		end
	end
	return nil
end

function Kit.intensity(ctx: any): number
	local w = weatherModule()
	local i = 0
	if w and type(w.getIntensity) == "function" then
		local ok, v = pcall(w.getIntensity)
		i = if ok and type(v) == "number" then v else 0
	end
	if ctx.operation and ctx.operation.storm then
		i = math.max(i, 0.6)
	end
	return math.clamp(i, 0, 1)
end

-- Wind velocity (studs/s, blowing toward) from the scene's wind direction and the sea state.
function Kit.wind(ctx: any): Vector3
	local a = ctx.scene and ctx.scene.windDirection or 0
	local speed = (8 + 40 * Kit.intensity(ctx)) * Kit.KNOT
	return Vector3.new(math.cos(a), 0, math.sin(a)) * speed
end

function Kit.waveParams(pos: Vector3): any
	local w = weatherModule()
	if w and type(w.getWaveParams) == "function" then
		local ok, p = pcall(w.getWaveParams, pos)
		if ok and p then
			return p
		end
	end
	return Waves.paramsFor(0, 0, 0)
end

function Kit.now(): number
	return Workspace:GetServerTimeNow()
end

-- Per-operation state the tow steps hand to each other (the scenario, the rig, the line).
local shared: { [string]: { [string]: any } } = {}

function Kit.shared(ctx: any): { [string]: any }
	local id = tostring(ctx.operation and ctx.operation.id or "?")
	local s = shared[id]
	if not s then
		s = {}
		shared[id] = s
	end
	return s
end

-- The casualty vessel's story (deterministic per operation, so the whole crew hears the same).
-- POB is the people actually aboard the model the server built.
function Kit.scenario(ctx: any): Procedures.Scenario
	local s = Kit.shared(ctx)
	if not s.scenario then
		local sc =
			Procedures.roll(Procedures.seedOf(tostring(ctx.operation and ctx.operation.id or "?")))
		local model = Kit.casualtyModel(ctx)
		if model then
			local n = 0
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "Torso" then
					n += 1
				end
			end
			sc.pob = math.max(1, n)
		end
		s.scenario = sc
	end
	return s.scenario
end

-- Smoke runs (tools/studio/smoke.py ops) set OpsAutoStub: complete by ourselves with a stub.
function Kit.autoStub(finish: (any) -> (), metrics: { [string]: any }): boolean
	if Players.LocalPlayer:GetAttribute("OpsAutoStub") == true then
		task.delay(1, finish, { metrics = metrics, stub = true, grade = "Silver" })
		return true
	end
	return false
end

-- The harbour's pontoons (map DropOffs pads).
function Kit.dropOffs(): { BasePart }
	local out = {}
	local map = Workspace:FindFirstChild("Map")
	local folder = map and map:FindFirstChild("DropOffs", true)
	for _, d in (if folder then folder:GetChildren() else {}) :: { Instance } do
		if d:IsA("BasePart") and d:GetAttribute("DropOff") ~= nil then
			table.insert(out, d)
		end
	end
	return out
end

function Kit.nearestPad(pos: Vector3): (BasePart?, number)
	local best, bestD = nil, math.huge
	for _, pad in Kit.dropOffs() do
		local d = Vector3.new(pad.Position.X - pos.X, 0, pad.Position.Z - pos.Z).Magnitude
		if d < bestD then
			best, bestD = pad, d
		end
	end
	return best, bestD
end

-- A finish-once wrapper plus a cleanup bag: returns (complete, cleanup, bag).
function Kit.session(
	gui: ScreenGui,
	finish: (any) -> ()
): ((any) -> (), () -> (), { RBXScriptConnection | () -> () })
	local done = false
	local bag: { RBXScriptConnection | () -> () } = {}
	local function cleanup()
		done = true
		for _, item in bag do
			if typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			else
				pcall(item)
			end
		end
		table.clear(bag)
		gui:Destroy()
	end
	local function complete(result: any)
		if done then
			return
		end
		cleanup()
		finish(result)
	end
	return complete, cleanup, bag
end

---------------------------------------------------------------- UI

function Kit.gui(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 21
	gui.IgnoreGuiInset = true
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- A spoken line, as a subtitle at the bottom (the crew and the casualty talk; docs 09 2.3).
function Kit.say(gui: ScreenGui, who: string, text: string, seconds: number?)
	local label = gui:FindFirstChild("Subtitle") :: TextLabel?
	if not label then
		local l = Instance.new("TextLabel")
		l.Name = "Subtitle"
		l.AnchorPoint = Vector2.new(0.5, 1)
		l.Position = UDim2.new(0.5, 0, 1, -170)
		l.Size = UDim2.fromOffset(640, 30)
		l.BackgroundColor3 = Color3.new(0, 0, 0)
		l.BackgroundTransparency = 0.55
		l.Font = HudTheme.BodyFont
		l.TextSize = 20
		l.TextColor3 = HudTheme.Colors.text
		l.TextWrapped = true
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.Parent = gui
		HudTheme.corner(l, 8)
		label = l
	end
	local lbl = label :: TextLabel
	lbl.Text = `{who}: {text}`
	lbl.Visible = true
	local stamp = os.clock()
	lbl:SetAttribute("Stamp", stamp)
	task.delay(seconds or 4, function()
		if lbl.Parent and lbl:GetAttribute("Stamp") == stamp then
			lbl.Visible = false
		end
	end)
end

-- Plain instruction text at the top (what the crew lead tells you to do, not a game prompt).
function Kit.brief(gui: ScreenGui, text: string)
	local label = gui:FindFirstChild("Brief") :: TextLabel?
	if not label then
		local l = Instance.new("TextLabel")
		l.Name = "Brief"
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, 96)
		l.Size = UDim2.fromOffset(560, 26)
		l.BackgroundTransparency = 1
		l.Font = HudTheme.BoldFont
		l.TextSize = 19
		l.TextColor3 = HudTheme.Colors.text
		l.TextStrokeTransparency = 0.5
		l.TextWrapped = true
		l.Parent = gui
		label = l
	end
	(label :: TextLabel).Text = text
end

export type Choice = { id: string, text: string }

-- 2 to 4 cards (number keys 1-4, tap, or click). `right` glows after 5 s of hesitation in Assist.
-- Returns a cancel function. onPick is called once.
function Kit.choose(
	gui: ScreenGui,
	title: string,
	choices: { Choice },
	onPick: (id: string) -> (),
	assist: boolean,
	right: string?
): () -> ()
	local frame = Instance.new("Frame")
	frame.Name = "Cards"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -210)
	frame.Size = UDim2.fromOffset(math.min(#choices, 4) * 170 + 20, 112)
	frame.BackgroundColor3 = HudTheme.Colors.panel
	frame.BackgroundTransparency = 0.25
	frame.Parent = gui
	HudTheme.corner(frame)
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromOffset(12, 4)
	head.Size = UDim2.new(1, -24, 0, 26)
	head.Font = HudTheme.BoldFont
	head.TextSize = 18
	head.TextColor3 = HudTheme.Colors.text
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.Text = title
	head.Parent = frame
	local done = false
	local conns: { RBXScriptConnection } = {}
	local function close()
		done = true
		for _, c in conns do
			c:Disconnect()
		end
		frame:Destroy()
	end
	local function pick(id: string)
		if done then
			return
		end
		close()
		onPick(id)
	end
	for i, ch in choices do
		if i > 4 then
			break
		end
		local b = Instance.new("TextButton")
		b.Name = ch.id
		b.Position = UDim2.fromOffset(10 + (i - 1) * 170, 36)
		b.Size = UDim2.fromOffset(160, HudTheme.MinButtonHeight + 12)
		b.BackgroundColor3 = HudTheme.Colors.panelLight
		b.Font = HudTheme.BodyFont
		b.TextSize = 17
		b.TextWrapped = true
		b.TextColor3 = HudTheme.Colors.text
		b.Text = `{i}  {ch.text}`
		b.Parent = frame
		HudTheme.corner(b, 10)
		table.insert(
			conns,
			b.Activated:Connect(function()
				pick(ch.id)
			end)
		)
	end
	local keys = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
	table.insert(
		conns,
		UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			local idx = table.find(keys, input.KeyCode)
			if idx and choices[idx] then
				pick(choices[idx].id)
			end
		end)
	)
	if assist and right then
		task.delay(5, function()
			local b = if not done then frame:FindFirstChild(right) else nil
			if b and b:IsA("TextButton") then
				HudTheme.stroke(b, HudTheme.Colors.ready, 3)
			end
		end)
	end
	return function()
		if not done then
			close()
		end
	end
end

-- A small, subtle gauge (Assist only): a thin bar with green/amber/red ticks.
function Kit.gauge(gui: ScreenGui, label: string): (number) -> ()
	local frame = Instance.new("Frame")
	frame.Name = "TensionGauge"
	frame.AnchorPoint = Vector2.new(1, 1)
	frame.Position = UDim2.new(1, -24, 1, -140)
	frame.Size = UDim2.fromOffset(180, 34)
	frame.BackgroundTransparency = 1
	frame.Parent = gui
	local cap = Instance.new("TextLabel")
	cap.BackgroundTransparency = 1
	cap.Size = UDim2.new(1, 0, 0, 16)
	cap.Font = HudTheme.BodyFont
	cap.TextSize = 14
	cap.TextColor3 = HudTheme.Colors.textDim
	cap.TextXAlignment = Enum.TextXAlignment.Right
	cap.Text = label
	cap.Parent = frame
	local track = Instance.new("Frame")
	track.Position = UDim2.fromOffset(0, 20)
	track.Size = UDim2.new(1, 0, 0, 6)
	track.BackgroundColor3 = Color3.fromRGB(30, 40, 48)
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Parent = frame
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 170, 90)),
		ColorSequenceKeypoint.new(TowLine.GREEN - 0.01, Color3.fromRGB(60, 170, 90)),
		ColorSequenceKeypoint.new(TowLine.GREEN, Color3.fromRGB(230, 170, 40)),
		ColorSequenceKeypoint.new(TowLine.AMBER - 0.01, Color3.fromRGB(230, 170, 40)),
		ColorSequenceKeypoint.new(TowLine.AMBER, Color3.fromRGB(210, 60, 50)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 60, 50)),
	})
	grad.Parent = track
	local needle = Instance.new("Frame")
	needle.AnchorPoint = Vector2.new(0.5, 0.5)
	needle.Position = UDim2.fromOffset(0, 23)
	needle.Size = UDim2.fromOffset(3, 14)
	needle.BackgroundColor3 = HudTheme.Colors.text
	needle.BorderSizePixel = 0
	needle.Parent = frame
	return function(value: number)
		needle.Position = UDim2.new(math.clamp(value, 0, 1), 0, 0, 23)
	end
end

---------------------------------------------------------------- the tow link

export type Link = {
	opId: string,
	line: TowLine.Line,
	model: Model,
	hull: BasePart,
	root: BasePart,
	hitch: Attachment,
	rope: Beam,
	ropeA0: Attachment,
	ropeA1: Attachment,
	mid: Attachment,
	drips: ParticleEmitter,
	creak: Sound?,
	force: VectorForce?,
	serverCF: { [BasePart]: CFrame },
	lastSet: { [BasePart]: CFrame },
	conn: RBXScriptConnection?,
	lengthStuds: number,
	lashed: CFrame?, -- alongside: the casualty's CFrame relative to our root
	onUpdate: ((Link, number) -> ())?,
	wavelength: number,
	inStep: boolean,
	parts: { BasePart },
}

local links: { [string]: Link } = {}

local function hullHeading(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(look.X, look.Z)
end

local function bowAttachment(model: Model, hull: BasePart): Attachment
	local bow = model:FindFirstChild("BowPoint", true)
	if bow and bow:IsA("Attachment") then
		return bow
	end
	local a = Instance.new("Attachment")
	a.Name = "BowPointLocal"
	a.Position = Vector3.new(0, 0.6, -hull.Size.Z / 2)
	a.Parent = hull
	return a
end

function Kit.getLink(ctx: any): Link?
	local id = ctx.operation and ctx.operation.id
	local link = id and links[id]
	if link and link.model.Parent and link.root.Parent then
		return link
	end
	return nil
end

-- Makes (or returns) the tow link for this operation: our hitch to their bow. lengthStuds is the
-- paid-out line; the line starts slack lying in the water.
function Kit.link(
	ctx: any,
	lengthStuds: number,
	opts: { bridle: boolean?, strongPoint: boolean? }?
): Link?
	local existing = Kit.getLink(ctx)
	if existing then
		return existing
	end
	local model = Kit.casualtyModel(ctx)
	local root = Kit.vehicleRoot(ctx)
	if not model or not root then
		return nil
	end
	local hull = model.PrimaryPart or Kit.part(model, "Hull")
	if not hull then
		return nil
	end
	local hitch = Kit.hitch(root)
	local cf = hull.CFrame
	local line = TowLine.new({
		lengthStuds = lengthStuds,
		lwlStuds = hull.Size.Z,
		massKg = 1500,
		bridle = opts and opts.bridle,
		strongPoint = opts and opts.strongPoint,
		x = cf.Position.X,
		z = cf.Position.Z,
		heading = hullHeading(cf),
	})
	-- never start stretched: pay out at least the current gap
	local bx, bz = TowLine.bowPosition(line)
	local gap = Vector3.new(hitch.WorldPosition.X - bx, 0, hitch.WorldPosition.Z - bz).Magnitude
	TowLine.setLength(line, math.max(lengthStuds, gap + 1))

	local a1 = bowAttachment(model, hull)
	local a0 = Instance.new("Attachment")
	a0.Name = "TowLineLocalA0"
	a0.Parent = root
	a0.WorldPosition = hitch.WorldPosition
	local rope = Instance.new("Beam")
	rope.Name = "TowLineLocal"
	rope.Attachment0 = a0
	rope.Attachment1 = a1
	rope.Width0, rope.Width1 = 0.22, 0.22
	rope.Segments = 24
	rope.FaceCamera = true
	rope.Color = ColorSequence.new(Color3.fromRGB(236, 120, 40)) -- orange polypropylene-nylon tow line
	rope.LightInfluence = 1
	rope.Parent = root
	local mid = Instance.new("Attachment")
	mid.Name = "TowLineMid"
	mid.Parent = Workspace.Terrain
	local drips = Instance.new("ParticleEmitter")
	drips.Name = "Drips"
	drips.Rate = 0
	drips.Lifetime = NumberRange.new(0.4, 0.8)
	drips.Speed = NumberRange.new(1, 3)
	drips.SpreadAngle = Vector2.new(60, 60)
	drips.Acceleration = Vector3.new(0, -29.43, 0)
	drips.Size = NumberSequence.new(0.12, 0.04)
	drips.Transparency = NumberSequence.new(0.2, 1)
	drips.Color = ColorSequence.new(Color3.fromRGB(220, 235, 240))
	drips.Parent = mid
	local creak: Sound? = nil
	if Kit.CREAK_SOUND ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Kit.CREAK_SOUND
		s.Looped = true
		s.Volume = 0
		s.RollOffMaxDistance = 120
		s.Parent = a0
		s:Play()
		creak = s
	end
	local force: VectorForce? = nil
	if root:IsDescendantOf(Workspace) and not root.Anchored then
		local f = Instance.new("VectorForce")
		f.Name = "TowLoad"
		f.Attachment0 = hitch
		f.RelativeTo = Enum.ActuatorRelativeTo.World
		f.ApplyAtCenterOfMass = false
		f.Force = Vector3.zero
		f.Parent = root
		force = f
	end
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	local link: Link = {
		opId = ctx.operation.id,
		line = line,
		model = model,
		hull = hull,
		root = root,
		hitch = hitch,
		rope = rope,
		ropeA0 = a0,
		ropeA1 = a1,
		mid = mid,
		drips = drips,
		creak = creak,
		force = force,
		serverCF = {},
		lastSet = {},
		conn = nil,
		lengthStuds = lengthStuds,
		lashed = nil,
		onUpdate = nil,
		wavelength = 64,
		inStep = false,
		parts = parts,
	}
	links[link.opId] = link
	local lastHitch = hitch.WorldPosition
	local prevTension = 0
	link.conn = RunService.PreRender:Connect(function(dt)
		if not model.Parent or not root.Parent then
			Kit.release(link)
			return
		end
		dt = math.min(dt, 0.1)
		-- capture what the server last sent for each part (anything we did not set ourselves)
		for _, p in parts do
			local cur = p.CFrame
			if link.lastSet[p] ~= cur then
				link.serverCF[p] = cur
			end
		end
		local serverHull = link.serverCF[hull] or hull.CFrame
		local hp = hitch.WorldPosition
		local hv = (hp - lastHitch) / math.max(dt, 1e-3)
		lastHitch = hp
		local params = Kit.waveParams(serverHull.Position)
		local now = Kit.now()
		local hx, hz = TowLine.hullPosition(line)
		local _, gx, gz = Waves.gradientAt(hx, hz, now, params)
		local wind = Kit.wind(ctx)
		local target: CFrame
		if link.lashed then
			-- alongside: lashed to our side, moves with us
			target = root.CFrame * link.lashed
			line.x, line.z = target.Position.X / 3, target.Position.Z / 3
			line.vx, line.vz = hv.X / 3, hv.Z / 3
			line.heading = hullHeading(target)
			line.tension, line.slack = 0, true
		else
			TowLine.step(line, hp.X, hp.Z, hv.X, hv.Z, dt, {
				windX = wind.X,
				windZ = wind.Z,
				slopeX = gx,
				slopeZ = gz,
			})
			hx, hz = TowLine.hullPosition(line)
			local h = Waves.heightAt(hx, hz, now, params)
			local yaw = line.heading - hullHeading(serverHull)
			local rot = serverHull - serverHull.Position
			-- the bow dips under load, then rises as the strain eases
			local pitch = -math.clamp(line.tension, 0, 1.2) * 0.06
			target = CFrame.new(
				hx,
				h
					+ (
						serverHull.Position.Y
						- Waves.heightAt(serverHull.Position.X, serverHull.Position.Z, now, params)
					),
				hz
			) * CFrame.Angles(0, yaw, 0) * rot * CFrame.Angles(pitch, 0, 0)
		end
		-- move every part of the casualty with the hull (keeps the server's bob and the waving arms)
		local delta = target * serverHull:Inverse()
		local list, cfs = {}, {}
		for _, p in parts do
			local base = link.serverCF[p] or p.CFrame
			local moved = delta * base
			table.insert(list, p)
			table.insert(cfs, moved)
			link.lastSet[p] = moved
		end
		Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- the line: sag when slack (it lies in the water), straight and thin when hard
		local a1p = a1.WorldPosition
		local dist = (Vector3.new(a1p.X, 0, a1p.Z) - Vector3.new(hp.X, 0, hp.Z)).Magnitude
		local sag = if link.lashed
			then 0.3
			else TowLine.sag(link.line.length * 3, dist, line.tensionN)
		local t = line.tension
		local thrum = if t > TowLine.GREEN then math.sin(os.clock() * 70) * 0.08 * t else 0
		rope.CurveSize0 = -(sag * 1.3) + thrum
		rope.CurveSize1 = sag * 1.3 - thrum
		local w = 0.24 - math.clamp(t, 0, 1) * 0.06
		rope.Width0, rope.Width1 = w, w
		rope.Enabled = not line.parted
		a0.WorldPosition = hp
		mid.WorldPosition = hp:Lerp(a1p, 0.5) - Vector3.new(0, math.min(sag, 4), 0)
		-- lifting out of the water: drips shed off the line as it comes taut
		drips.Rate = if t > 0.08 and prevTension < t then 40 * math.clamp(t, 0, 1) else 0
		if line.snatch > 0 then
			drips:Emit(math.floor(20 + 60 * line.snatch))
		end
		prevTension = t
		if creak then
			creak.Volume = math.clamp((t - 0.25) * 1.4, 0, 0.8)
			creak.PlaybackSpeed = 0.8 + t * 0.5
		end
		if force then
			local dir = Vector3.new(a1p.X - hp.X, 0, a1p.Z - hp.Z)
			local n = if dir.Magnitude > 1e-3 then dir.Unit else Vector3.zero
			local mag = math.min(line.tensionN * Kit.N_TO_FORCE, 4000)
			force.Force = n * mag
		end
		-- in step: both boats on the same phase of the dominant wave
		link.wavelength = TowLine.dominantWavelength(params)
		local spacing = (root.Position - target.Position).Magnitude
		link.inStep = TowLine.inStep(spacing, link.wavelength)
		if link.onUpdate then
			link.onUpdate(link, dt)
		end
	end)
	return link
end

function Kit.setLength(link: Link, lengthStuds: number)
	link.lengthStuds = lengthStuds
	TowLine.setLength(link.line, lengthStuds)
end

function Kit.snapSound(where: Attachment)
	if Kit.SNAP_SOUND ~= "" then
		local s = Instance.new("Sound")
		s.SoundId = Kit.SNAP_SOUND
		s.Volume = 1
		s.PlayOnRemove = true
		s.Parent = where
		s:Destroy()
	end
end

-- Lets the casualty go back to the server's motion and removes our line.
function Kit.release(link: Link)
	if link.conn then
		link.conn:Disconnect()
		link.conn = nil
	end
	if links[link.opId] == link then
		links[link.opId] = nil
	end
	link.rope:Destroy()
	link.ropeA0:Destroy()
	link.mid:Destroy()
	if link.force then
		link.force:Destroy()
	end
	if link.ropeA1.Name == "BowPointLocal" then
		link.ropeA1:Destroy()
	end
	local list, cfs = {}, {}
	for p, cf in link.serverCF do
		if p.Parent then
			table.insert(list, p)
			table.insert(cfs, cf)
		end
	end
	if #list > 0 then
		Workspace:BulkMoveTo(list, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function Kit.releaseFor(ctx: any)
	local link = Kit.getLink(ctx)
	if link then
		Kit.release(link)
	end
end

-- Our boat's speed over the ground (studs/s) and the throttle feel the player is giving.
function Kit.speed(root: BasePart): number
	local v = root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude
end

return Kit
