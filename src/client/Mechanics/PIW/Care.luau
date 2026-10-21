--!strict
-- PIW/Care: the world kit the casualty care steps share (docs 14 section 2: no choice UI).
--   Care.body(ctx, bag)          the casualty (or a stand-in where they lie) and its body areas
--   Care.picker(bag, folder, fn)  look at a target (screen centre, the free mouse, or the finger on
--                                touch): it glows and shows the device glyph. Press E / X / left
--                                click / tap; hold the same to work on it (the caller times it).
--   Care.part / Care.stick       code-built kit pieces and keeping them on a body area
--   Care.chest                   the chest dipping (a compression) or rising (a breath)
--   Care.finding                 what a survey letter shows on the body (puffs, lips, graze, shiver)
--   Care.puffs / Care.shiver / Care.tilt / Care.spray   the cues themselves
local Debris = game:GetService("Debris")
local GuiService = game:GetService("GuiService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraController = require(
	script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("CameraController")
)
local Comfort = require(script.Parent.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local Flipbooks =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Fx"):WaitForChild("Flipbooks"))
local InputGlyph =
	require(script.Parent.Parent.Parent:WaitForChild("UI"):WaitForChild("InputGlyph"))
local Medical = require(script.Parent.Medical)
local Pick = require(script.Parent.Pick)
local Ui = require(script.Parent.Ui)
local World = require(script.Parent.World)

local Care = {}

Care.RANGE = 60 -- studs from the camera a target can be worked from

local function noop() end

---------------------------------------------------------------- the body

export type Body = {
	model: Model?,
	folder: Folder,
	cf: (area: string) -> CFrame,
	at: (area: string) -> Vector3,
}

local PARTS = {
	head = "Head",
	chest = "UpperTorso",
	arm = "LeftLowerArm",
	hand = "LeftHand",
	body = "LowerTorso",
	legs = "LeftLowerLeg",
}
-- where each area sits on a rig without that part (or on the stand-in), model axes
local OFFSETS = {
	head = Vector3.new(0, 1.6, 0),
	chest = Vector3.new(0, 0.7, 0),
	arm = Vector3.new(-1.3, 0.3, 0),
	hand = Vector3.new(-1.5, -0.3, 0),
	body = Vector3.new(0, -0.3, 0),
	legs = Vector3.new(-0.5, -1.9, 0),
}

function Care.body(ctx: { [string]: any }, bag: Ui.Bag): Body
	local model = World.victim(ctx)
	local folder = Ui.add(bag, Instance.new("Folder"))
	folder.Name = "PIW_Care"
	folder.Parent = Workspace
	local base = CFrame.new(World.casualtyPos(ctx, model))
	local found: { [string]: BasePart } = {}
	local function cf(area: string): CFrame
		local m = model
		if m and m.Parent then
			local p: BasePart? = found[area]
			if not p or not p.Parent then
				local d = m:FindFirstChild((PARTS :: any)[area] or "", true)
				p = if d and d:IsA("BasePart") then d else nil
				if p then
					found[area] = p
				end
			end
			if p then
				return p.CFrame
			end
			return m:GetPivot() * CFrame.new((OFFSETS :: any)[area] or Vector3.zero)
		end
		return base * CFrame.new((OFFSETS :: any)[area] or Vector3.zero)
	end
	return {
		model = model,
		folder = folder,
		cf = cf,
		at = function(area: string): Vector3
			return cf(area).Position
		end,
	}
end

function Care.part(
	body: Body,
	size: Vector3,
	colour: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = body.folder
	return p
end

-- Keeps `part` on a body area (offset in the area's frame) every frame.
function Care.stick(bag: Ui.Bag, body: Body, part: BasePart, area: string, offset: CFrame?)
	local o = offset or CFrame.identity
	part.CFrame = body.cf(area) * o
	Ui.add(
		bag,
		RunService.RenderStepped:Connect(function()
			if part.Parent then
				part.CFrame = body.cf(area) * o
			end
		end)
	)
end

---------------------------------------------------------------- look, glow, glyph, press

export type Picker = {
	set: (id: string, at: () -> Vector3?, size: number?) -> (),
	remove: (id: string) -> (),
	clear: () -> (),
	aimed: () -> string?,
	down: () -> boolean,
	fill: (progress: number?) -> (),
	hint: (id: string?) -> (),
}

local GLOW = Color3.fromRGB(255, 244, 214)
local livePickers = 0

function Care.picker(bag: Ui.Bag, folder: Instance, onPress: (id: string) -> ()): Picker
	local targets: { [string]: { at: () -> Vector3?, ball: Part } } = {}
	-- close work: the camera dollies into first person for the care steps (CameraController
	-- refcounts the holds, so consecutive steps and CPR's nested picker keep one move). It aims
	-- the end of the dolly at the middle of the care targets (G81), so they sit near the centre
	-- and the E / gamepad pick can reach them.
	local function focus(): Vector3?
		local sum, n = Vector3.zero, 0
		for _, tg in targets do
			local p = tg.at()
			if p then
				sum += p
				n += 1
			end
		end
		return if n > 0 then sum / n else nil
	end
	local releaseCamera: (() -> ())? = nil
	if type((CameraController :: any).HoldFirstPerson) == "function" then
		local ok, release = pcall((CameraController :: any).HoldFirstPerson, focus)
		if ok and type(release) == "function" then
			releaseCamera = release
		end
	end
	Ui.add(bag, function()
		if releaseCamera then
			releaseCamera()
			releaseCamera = nil
		end
	end)
	-- a ProximityPrompt in reach (E / X, e.g. the slipway's Launch_JetSki) eats the press as
	-- gameProcessed, so no care action registers: prompts are off while any picker is live
	livePickers += 1
	ProximityPromptService.Enabled = false
	Ui.add(bag, function()
		livePickers -= 1
		if livePickers == 0 then
			ProximityPromptService.Enabled = true
		end
	end)
	local aimedId: string? = nil
	local hinted: string? = nil
	local touchPos: Vector2? = nil
	local held: { [any]: boolean } = {}

	-- the device glyph and a hold bar over whatever is looked at
	local gui = Instance.new("BillboardGui")
	gui.Name = "CareGlyph"
	gui.Size = UDim2.fromOffset(64, 46)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Enabled = false
	Ui.add(bag, gui)
	local chip = InputGlyph.chip(gui, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.fromScale(0.5, 0)
	-- the selection glyph: a small diamond over whatever is picked, on every device (touch has
	-- no key chip, so the glow needs a mark of its own)
	local mark = Instance.new("Frame")
	mark.Name = "Selected"
	mark.AnchorPoint = Vector2.new(0.5, 1)
	mark.Position = UDim2.fromScale(0.5, 1)
	mark.Size = UDim2.fromOffset(10, 10)
	mark.Rotation = 45
	mark.BackgroundColor3 = Ui.Theme.Colors.accent
	mark.BorderSizePixel = 0
	mark.Parent = gui
	Ui.Theme.corner(mark, 2)
	local track = Instance.new("Frame")
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.fromScale(0.5, 1)
	track.Size = UDim2.new(1, 0, 0, 8)
	track.BackgroundColor3 = Ui.Theme.Colors.panel
	track.BackgroundTransparency = 0.3
	track.BorderSizePixel = 0
	track.Visible = false
	track.Parent = gui
	Ui.Theme.corner(track, 4)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.fromScale(0, 1)
	bar.BackgroundColor3 = Ui.Theme.Colors.ready
	bar.BorderSizePixel = 0
	bar.Parent = track
	Ui.Theme.corner(bar, 4)

	local function aimPoint(cam: Camera): Vector2
		if touchPos then
			return touchPos
		end
		if
			InputGlyph.device() == "Keyboard"
			and UserInputService.MouseBehavior == Enum.MouseBehavior.Default
		then
			return UserInputService:GetMouseLocation() -- viewport space, like WorldToViewportPoint
		end
		return cam.ViewportSize / 2
	end

	local function onScreen(cam: Camera): { Pick.Target }
		local out: { Pick.Target } = {}
		for id, tg in targets do
			local p = tg.at()
			if p then
				local v = cam:WorldToViewportPoint(p)
				if v.Z > 0 and v.Z < Care.RANGE then
					table.insert(out, { id = id, at = Vector2.new(v.X, v.Y) })
				end
			end
		end
		return out
	end

	-- the pointer stays on its target while it is still (a bobbing boat moves the body under
	-- it); moving the pointer chooses again. The stick (gamepad) steps through the targets.
	-- A mouse click or touch tap picks the target under the pointer (44 px), a fresh pick.
	local anchor: Vector2? = nil
	local function pick(pointer: Vector2?): string?
		local cam = World.camera()
		local aim = pointer or aimPoint(cam)
		if pointer then
			aimedId = Pick.choose(aim, true, onScreen(cam), nil, Pick.CLICK_HIT)
			anchor = aim
			return aimedId
		end
		local moved = anchor == nil or (aim - (anchor :: Vector2)).Magnitude >= Pick.MOVE
		local reach = math.max(70, cam.ViewportSize.Y * 0.1)
		local id = Pick.choose(aim, moved, onScreen(cam), aimedId, reach)
		if id ~= aimedId then
			aimedId = id
			anchor = aim
		elseif moved then
			anchor = aim
		end
		return aimedId
	end

	local function cycle(step: number)
		local cam = World.camera()
		aimedId = Pick.cycle(onScreen(cam), aimedId, step)
		anchor = aimPoint(cam)
	end

	Ui.add(
		bag,
		RunService.RenderStepped:Connect(function()
			aimedId = pick()
			local pulse = os.clock() % 0.8 < 0.4
			for id, tg in targets do
				local p = tg.at()
				if p then
					tg.ball.Position = p
				end
				tg.ball.Transparency = if id == aimedId
					then 0.35
					elseif id == hinted and pulse then 0.3
					else 0.85
			end
			local tg = aimedId and targets[aimedId]
			gui.Parent = if tg then tg.ball else nil
			gui.Enabled = tg ~= nil
		end)
	)

	local function key(i: InputObject): any
		return if i.UserInputType == Enum.UserInputType.Touch
			then i
			elseif i.UserInputType == Enum.UserInputType.Keyboard or string.sub(
				i.UserInputType.Name,
				1,
				7
			) == "Gamepad" then i.KeyCode
			else i.UserInputType
	end
	Ui.add(
		bag,
		UserInputService.InputBegan:Connect(function(i: InputObject, processed: boolean)
			if processed then
				return
			end
			if i.UserInputType == Enum.UserInputType.Touch then
				local inset = GuiService:GetGuiInset()
				touchPos = Vector2.new(i.Position.X, i.Position.Y) + inset
			elseif
				not (
					i.KeyCode == Enum.KeyCode.E
					or i.KeyCode == Enum.KeyCode.ButtonX
					or i.UserInputType == Enum.UserInputType.MouseButton1
				)
			then
				return
			end
			local k = key(i)
			if Comfort.get("holdToTap") == true and held[k] then
				held[k] = nil -- a second press stops a toggled hold
				return
			end
			held[k] = true
			local pointer = if i.UserInputType == Enum.UserInputType.Touch
				then touchPos
				elseif
					i.UserInputType == Enum.UserInputType.MouseButton1
				then UserInputService:GetMouseLocation()
				else nil
			aimedId = pick(pointer)
			if aimedId then
				onPress(aimedId)
			end
		end)
	)
	local cycleLatch = false
	Ui.add(
		bag,
		UserInputService.InputChanged:Connect(function(i: InputObject)
			if i.UserInputType == Enum.UserInputType.Touch and held[i] then
				touchPos = Vector2.new(i.Position.X, i.Position.Y) + GuiService:GetGuiInset()
			elseif i.KeyCode == Enum.KeyCode.Thumbstick2 then
				-- one stick flick = one target (the gamepad's aim point is the screen centre)
				local x = i.Position.X
				if math.abs(x) < 0.3 then
					cycleLatch = false
				elseif
					not cycleLatch
					and math.abs(x) > 0.65
					and InputGlyph.device() == "Gamepad"
				then
					cycleLatch = true
					cycle(if x > 0 then 1 else -1)
				end
			end
		end)
	)
	Ui.add(
		bag,
		UserInputService.InputEnded:Connect(function(i: InputObject)
			local k = key(i)
			if i.UserInputType == Enum.UserInputType.Touch then
				touchPos = nil
			end
			if held[k] and Comfort.get("holdToTap") ~= true then
				held[k] = nil
			end
		end)
	)

	local picker: Picker
	picker = {
		set = function(id: string, at: () -> Vector3?, size: number?)
			local old = targets[id]
			local ball = if old then old.ball else Instance.new("Part")
			ball.Name = id
			ball.Shape = Enum.PartType.Ball
			ball.Size = Vector3.one * (size or 0.8)
			ball.Material = Enum.Material.Neon
			ball.Color = GLOW
			ball.Transparency = 0.85
			ball.Anchored = true
			ball.CanCollide = false
			ball.CanQuery = false
			ball.CanTouch = false
			ball.CastShadow = false
			ball.Position = at() or Vector3.zero
			ball.Parent = folder
			targets[id] = { at = at, ball = ball }
		end,
		remove = function(id: string)
			local tg = targets[id]
			if tg then
				if gui.Parent == tg.ball then
					gui.Parent = nil
				end
				tg.ball:Destroy()
				targets[id] = nil
			end
			if aimedId == id then
				aimedId = nil
			end
		end,
		clear = function()
			for id in targets do
				picker.remove(id)
			end
		end,
		aimed = function(): string?
			return aimedId
		end,
		down = function(): boolean
			return next(held) ~= nil
		end,
		fill = function(progress: number?)
			track.Visible = progress ~= nil and progress > 0
			bar.Size = UDim2.fromScale(math.clamp(progress or 0, 0, 1), 1)
		end,
		hint = function(id: string?)
			hinted = id
		end,
	}
	return picker
end

---------------------------------------------------------------- cues on the body

-- Breath you can see: a small white puff at the mouth on every breath (none when they aren't
-- breathing). `speed` > 1 runs time faster (the triage count). Returns stop().
function Care.puffs(bag: Ui.Bag, body: Body, perMinute: number, speed: number?): () -> ()
	if perMinute <= 0 then
		return noop
	end
	local alive = true
	Ui.add(
		bag,
		task.spawn(function()
			while alive do
				local p = Care.part(
					body,
					Vector3.one * 0.35,
					Color3.fromRGB(240, 244, 248),
					Enum.Material.SmoothPlastic,
					Enum.PartType.Ball
				)
				p.Transparency = 0.3
				p.CFrame = body.cf("head") * CFrame.new(0, -0.25, -0.7)
				TweenService:Create(p, TweenInfo.new(0.9), {
					Size = Vector3.one * 1.1,
					Transparency = 1,
					CFrame = p.CFrame * CFrame.new(0, 0.4, -0.5),
				}):Play()
				Debris:AddItem(p, 1)
				task.wait(60 / perMinute / (speed or 1))
			end
		end)
	)
	local function stop()
		alive = false
	end
	Ui.add(bag, stop)
	return stop
end

local function joint(body: Body, part1: string): Motor6D?
	local m = body.model
	if not m then
		return nil
	end
	for _, d in m:GetDescendants() do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == part1 then
			return d
		end
	end
	return nil
end

-- Shivering: the torso trembles. C0 is local to this client; the rig's poses write Transform.
function Care.shiver(bag: Ui.Bag, body: Body): () -> ()
	local j = joint(body, "UpperTorso")
	if not j then
		return noop
	end
	local base = j.C0
	local conn = RunService.RenderStepped:Connect(function()
		local t = os.clock()
		j.C0 = base
			* CFrame.Angles(math.rad(1.2 * math.sin(t * 47)), 0, math.rad(1.6 * math.sin(t * 61)))
	end)
	local function stop()
		if conn.Connected then
			conn:Disconnect()
			j.C0 = base
		end
	end
	Ui.add(bag, stop)
	return stop
end

-- Head tilted back (the airway opened), held until the step ends.
function Care.tilt(bag: Ui.Bag, body: Body)
	local j = joint(body, "Head")
	if not j then
		return
	end
	local base = j.C0
	TweenService:Create(j, TweenInfo.new(0.6), { C0 = base * CFrame.Angles(math.rad(25), 0, 0) })
		:Play()
	Ui.add(bag, function()
		j.C0 = base
	end)
end

-- The chest moving: press(-depth) pushes it down (a compression), press(+lift) raises it (a
-- breath); it springs back. Nothing moves on the stand-in (no rig).
function Care.chest(bag: Ui.Bag, body: Body): (number) -> ()
	local j = joint(body, "UpperTorso")
	local base = if j then j.C0 else CFrame.identity
	if j then
		Ui.add(bag, function()
			j.C0 = base
		end)
	end
	return function(amount: number)
		-- the torso's front is -Z, so down into the chest is +Z
		local out = CFrame.new(0, 0, -amount)
		local back = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if j then
			j.C0 = base * out
			TweenService:Create(j, back, { C0 = base }):Play()
		end
	end
end

-- What one survey letter's answer (Medical.surveyCards) shows on the body. `say` voices the
-- casualty's answer (nil: no voice, e.g. when the treatment re-shows the findings). Returns
-- stop(), which clears the cue (a blanket stops the shivering, a dressing covers the graze).
function Care.finding(
	bag: Ui.Bag,
	body: Body,
	letter: string,
	answer: number,
	say: ((string, number?) -> ())?
): () -> ()
	if letter == "Response" then
		local line = ({ '"I\'m okay..."', '"Mm..."', '"Nngh."' })[answer]
		if say and line then
			say(line, 2)
		end
	elseif letter == "Airway" then
		if answer == 2 then
			Care.tilt(bag, body)
		end
	elseif letter == "Breathing" then
		return Care.puffs(bag, body, Medical.BREATHS[answer] or 14)
	elseif letter == "Circulation" then
		local p: Part? = nil
		if answer == 2 then -- pale and cold: blue lips
			p = Care.part(body, Vector3.new(0.45, 0.12, 0.1), Color3.fromRGB(90, 110, 190))
			Care.stick(bag, body, p :: Part, "head", CFrame.new(0, -0.32, -0.56))
		elseif answer == 3 then -- a graze, oozing
			p = Care.part(body, Vector3.new(0.5, 0.7, 0.08), Color3.fromRGB(170, 20, 25))
			Care.stick(bag, body, p :: Part, "arm", CFrame.new(0, 0, -0.33))
		end
		return function()
			if p then
				p:Destroy()
			end
		end
	elseif letter == "Disability" then
		if answer == 1 then
			return Care.shiver(bag, body)
		end
	end
	return noop
end

-- Splashing on a panicking casualty (FX1 slam burst sheet; each particle a whole splash). Returns
-- the emitter (nil without a casualty model) and the rate for full panic.
function Care.spray(bag: Ui.Bag, victim: Model?): (ParticleEmitter?, number)
	local root = victim and victim.PrimaryPart
	if not root then
		return nil, 0
	end
	local e = Instance.new("ParticleEmitter")
	Flipbooks.apply(e, "FX_Spray_SlamBurst")
	local sheet = Flipbooks.uploaded("FX_Spray_SlamBurst")
	e.Color = ColorSequence.new(Color3.fromRGB(235, 245, 250))
	e.Size = if sheet
		then NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(1, 2.2),
		})
		else NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(1, 1.2),
		})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, if sheet then 0.1 else 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = if sheet then NumberRange.new(0.6, 0.9) else NumberRange.new(0.4, 0.8)
	e.Speed = if sheet then NumberRange.new(0.5, 1.5) else NumberRange.new(6, 10)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Rotation = NumberRange.new(-20, 20)
	e.Acceleration = Vector3.new(0, if sheet then -4 else -29.43, 0) -- the sheet carries its own fall
	e.Rate = 0
	e.Parent = root
	Ui.add(bag, e)
	return e, if sheet then 12 else 40 -- one sheet = one splash
end

return Care
