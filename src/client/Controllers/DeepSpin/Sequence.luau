--!strict
-- DeepSpin/Sequence: the spinner's own spin, rebuilt from the owner-approved reference (docs/prototypes/spin-wheel.html;
-- timing in shared/SpinCurve). Client only: others see the normal wheel turn and land (PrizeWheelController).
--   dive     first spin only, 1.9 s: the wheel grinds up, cracks race out, the ground bursts, it drops through a rock
--            shaft and punches through foam into the Deep
--   spin     wind-up, spin hard to 3200 deg/s (blur, vortex, FOV push), three claw slams with hit-stop, the crawl
--   stop     0.28 s of dead silence with the winning wedge up and the rest dimmed
--   reveal   the real prize builds brick by brick (Prize), sized by rarity; a tap skips
--   surface  one spin per trip (owner 2026-11-03): the water rises over the still-turning prize, then falls away over
--            the intact island. The next spin is a new press on land, with its own dive.
-- Every exit (home, death, reset, a script error) goes through leave(): camera, HUD, prompts, sounds, Lighting,
-- character and the real wheel come back, and the private set is destroyed. Reduce motion: no shake, tilt, FOV push or
-- flashes.
--   Sequence.start(ctx)       ctx: { payload, hub: CFrame (the rotor's rest pivot), wheel: Model, onExit: () -> () }
--   Sequence.active(), Sequence.whenDone(fn), Sequence.preload()
-- Player attribute SpinCinematic (true while on; RewardController waits on it), SpinRevealed (the held Cash lands).
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("Config"):WaitForChild("AssetIds"))
local SpinCurve = require(Shared:WaitForChild("SpinCurve"))
local SpinRules = require(Shared:WaitForChild("SpinRules"))

local Prize = require(script.Parent:WaitForChild("Prize"))
local Set = require(script.Parent:WaitForChild("Set"))
local Controllers = script.Parent.Parent
local AudioController = require(Controllers:WaitForChild("AudioController"))
local CameraController = require(Controllers:WaitForChild("CameraController"))
local Client = script.Parent.Parent.Parent
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local VFXKit = require(Client:WaitForChild("VFX"):WaitForChild("VFXKit"))
local Kit = Client:WaitForChild("UI"):WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))

local player = Players.LocalPlayer
local rgb = Color3.fromRGB
local H, U, R = Set.H, Set.U, Set.R
local smooth, easeOutBack = SpinCurve.smooth, SpinCurve.easeOutBack
local STEP = SpinCurve.STEP
local PRIZE_Z = -8 -- the prize stands this far in front of the wheel
local PRIZE_SIZE = 6.4
-- the reference's rarity colours (RAR.c / hi), Common .. Mythic
local GLOW = {
	rgb(196, 201, 208),
	rgb(111, 224, 127),
	rgb(92, 184, 255),
	rgb(208, 124, 245),
	rgb(255, 228, 106),
	rgb(255, 155, 214),
}

local Sequence = {}

local run: any = nil
local after: { () -> () } = {}

local function reducedMotion(): boolean
	return Comfort.reducedMotion()
end

local function lowQuality(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and level >= 1 and level <= 3
end

local function damp(rate: number, dt: number): number
	return 1 - math.exp(-dt * rate)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local function sfx(name: string, volume: number?, pitch: number?)
	AudioController.play(name, nil, volume, pitch)
end

---------------------------------------------------------------- what goes away while we are down there

local function setWorldHidden(s: any, on: boolean)
	-- the character and followers stand round the wheel: out of the shot
	local models: { Instance } = {}
	if player.Character then
		table.insert(models, player.Character)
	end
	local dogs = Workspace:FindFirstChild("Bosun")
	for _, dog in if dogs then dogs:GetChildren() else {} do
		table.insert(models, dog)
	end
	for _, m in Workspace:GetChildren() do
		if m:IsA("Model") and string.sub(m.Name, 1, 9) == "Wildlife_" then
			table.insert(models, m)
		end
	end
	for _, model in models do
		for _, x in model:GetDescendants() do
			if x:IsA("BasePart") or x:IsA("Decal") then
				(x :: any).LocalTransparencyModifier = if on then 1 else 0
			end
		end
	end
	-- the real wheel's stand, rotor and flapper: the hero copy stands in its place until the break
	local keep =
		{ s.wheel:FindFirstChild("OddsBoard", true), s.wheel:FindFirstChild("TokenMachine", true) }
	for _, x in s.wheel:GetDescendants() do
		if
			(x:IsA("BasePart") or x:IsA("Decal"))
			and not (keep[1] and x:IsDescendantOf(keep[1]))
			and not (keep[2] and x:IsDescendantOf(keep[2]))
		then
			(x :: any).LocalTransparencyModifier = if on then 1 else 0
		end
	end
end

local function hideGuis(s: any)
	for _, g in player:WaitForChild("PlayerGui"):GetChildren() do
		if g:IsA("ScreenGui") and g.Enabled and g ~= s.gui and g ~= s.wallGui then
			g.Enabled = false
			table.insert(s.hidden, g)
		end
	end
end

local function setControls(on: boolean)
	pcall(function()
		local module = (require :: any)((player :: any).PlayerScripts:WaitForChild("PlayerModule"))
		local controls = module:GetControls()
		if on then
			controls:Enable()
		else
			controls:Disable()
		end
	end)
end

local function setUnderwater(s: any, on: boolean)
	for _, eq in s.eq do
		eq:Destroy()
	end
	s.eq = {}
	local air = s.air
	if on then
		for _, cat in { "SFX", "Ambience", "Music" } do
			local eq = Instance.new("EqualizerSoundEffect")
			eq.HighGain, eq.MidGain, eq.LowGain = -28, -8, 2
			eq.Parent = AudioController.group(cat)
			table.insert(s.eq, eq)
		end
		if air then
			air.part.Density, air.part.Haze, air.part.Glare = 0.34, 0, 0
			air.part.Color, air.part.Decay = rgb(26, 120, 140), rgb(6, 54, 84)
		end
	elseif air then
		air.part.Density, air.part.Haze, air.part.Glare = air.density, air.haze, air.glare
		air.part.Color, air.part.Decay = air.color, air.decay
	end
	s.grade.Enabled = on
end

---------------------------------------------------------------- leaving

local function leave()
	local s = run
	if not s then
		return
	end
	run = nil
	RunService:UnbindFromRenderStep("DeepSpin")
	for _, c in s.conns do
		c:Disconnect()
	end
	CameraController.ClearOverride()
	local cam = Workspace.CurrentCamera
	if cam then
		cam.FieldOfView = s.fovBack
	end
	setUnderwater(s, false)
	setWorldHidden(s, false)
	setControls(true)
	for _, g in s.hidden do
		if g.Parent then
			g.Enabled = true
		end
	end
	ProximityPromptService.Enabled = s.promptsWere
	if s.prize then
		s.prize.destroy()
	end
	s.grade:Destroy()
	s.drone:Destroy()
	s.roar:Destroy()
	s.gui:Destroy()
	s.stage.folder:Destroy()
	player:SetAttribute("SpinCinematic", nil)
	local fn = s.ctx.onExit
	if fn then
		task.spawn(fn)
	end
	local queued = after
	after = {}
	for _, f in queued do
		task.spawn(f)
	end
end

---------------------------------------------------------------- screen layer

local function buildGui(s: any)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepSpinUi"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 44
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	s.gui = gui

	local wash = Instance.new("Frame")
	wash.Name = "Wash"
	wash.BorderSizePixel = 0
	wash.Size = UDim2.fromScale(1, 1)
	wash.BackgroundColor3 = rgb(204, 242, 255)
	wash.BackgroundTransparency = 1
	wash.Parent = gui
	s.wash = wash

	local canvas = Style.canvas(gui)
	canvas.ZIndex = 2

	local name = Style.label(canvas, "", 46)
	name.AnchorPoint = Vector2.new(0.5, 0.5)
	name.Position = UDim2.fromScale(0.5, 0.68)
	name.Size = UDim2.fromOffset(620, 64)
	name.Visible = false
	s.nameLabel = name
	local pill = Instance.new("Frame")
	pill.BackgroundTransparency = 1
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.76)
	pill.Size = UDim2.fromOffset(190, 44)
	pill.Visible = false
	pill.Parent = canvas
	s.pill = pill
	local holder, pillFace = Style.block(pill, Style.grad("blue"), {})
	s.pillHolder = holder
	local pillText = Style.label(pillFace, "", 24)
	pillText.Size = UDim2.fromScale(1, 1)
	s.pillText = pillText
end

-- the water wall home: covers the whole frame, then falls away off the bottom of the screen over the island
local function waterWall(): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = "DeepSpinWall"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 45
	gui.Parent = player:WaitForChild("PlayerGui")
	local wall = Instance.new("Frame")
	wall.BorderSizePixel = 0
	wall.Size = UDim2.fromScale(1, 1.2)
	wall.BackgroundColor3 = Color3.new(1, 1, 1)
	wall.Parent = gui
	local grad = Instance.new("UIGradient")
	grad.Rotation = 90
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, rgb(43, 185, 204)),
		ColorSequenceKeypoint.new(0.35, rgb(13, 111, 150)),
		ColorSequenceKeypoint.new(1, rgb(4, 41, 77)),
	})
	grad.Parent = wall
	for i = 1, 22 do -- chunky foam blobs sell the lip at phone size
		local d = 18 + (i * 7 % 5) * 7
		local blob = Instance.new("Frame")
		blob.BorderSizePixel = 0
		blob.BackgroundColor3 = Color3.new(1, 1, 1)
		blob.AnchorPoint = Vector2.new(0.5, 0.5)
		blob.Position = UDim2.fromScale((i - 0.5) / 22, 0)
		blob.Size = UDim2.fromOffset(d, d)
		blob.Parent = wall
		Instance.new("UICorner", blob).CornerRadius = UDim.new(0.5, 0)
	end
	return gui, wall
end

local function surface(s: any)
	s.mode = "surface"
	s.t = 0
	sfx("FX_Whoosh", 0.8, 1.1)
	sfx("Splash_Entry", 0.7, 0.75)
	local gui, wall = waterWall()
	s.wallGui = gui
	s.wall = wall
	wall.BackgroundTransparency = 1
end

local function runWall(gui: ScreenGui, wall: Frame, startK: number)
	-- the wall outlives the set: it falls away over the real island
	local start = os.clock() - startK
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - start
		wall.BackgroundTransparency = 0
		wall.Position = UDim2.fromScale(0, 1 - lerp(1.2, 0, smooth(0.08, 0.95, k)))
		if k >= SpinCurve.T_SURFACE and conn then
			conn:Disconnect()
			gui:Destroy()
		end
	end)
end

---------------------------------------------------------------- beats

-- a play frame whose up axis points at the camera (flat rings face the shot)
local function facing(s: any, at: Vector3): CFrame
	return CFrame.fromMatrix(at, s.stage.origin.RightVector, s.stage.origin.LookVector)
end

local function fx(name: string, at: CFrame, opts: any?)
	local o = opts or {}
	o.still = true
	VFXKit.play(name, at, o)
end

local function startSpin(s: any)
	s.mode = "spin"
	s.t = 0
	s.st = 0
	s.ev = 0
	s.curve = SpinCurve.build(s.angle, s.segment, SpinCurve.offset(math.random()))
	s.zoomFrom = s.zoom
	sfx("FX_Whoosh", 0.5, 0.45) -- the riser
end

local function release(s: any)
	s.kick = 1
	s.shake = 1
	s.flash = 0.1
	fx("deep_release", facing(s, s.frame.Position))
end

local function slam(s: any, k: number)
	s.shake = 1 + k * 0.15
	s.kick = -0.85
	s.flash = 0.07
	s.sw *= 0.62
	s.hold = 0.05 + k * 0.012
	s.tiltV += (if k % 2 == 1 then -1 else 1) * (2.4 + k * 0.5)
	local origin = s.stage.origin
	for _, side in { 1, -1 } do
		-- the rim runs vertically at the claws; sparks shear along the spin (clockwise from the front)
		local at = s.frame * CFrame.new(side * R * 1.035, 0, -1)
		fx("deep_slam", CFrame.fromMatrix(at.Position, origin.RightVector, origin.UpVector * side))
	end
end

local function showLabel(s: any)
	local p = s.payload
	local tier = SpinCurve.tier(p.rarity)
	local row = SpinRules.RARITIES[p.rarity]
	s.nameLabel.Text = p.name or "Prize"
	s.nameLabel.Visible = true
	Style.recolor(s.pillHolder, Style.grad(if row then row.color else "disabled"))
	s.pillText.Text = string.upper(p.rarity or "Common")
	s.pill.Visible = true
	Style.pop(s.nameLabel, true)
	Style.pop(s.pill, true)
	s.nameLabel.TextColor3 = GLOW[tier]
end

local function startReveal(s: any)
	local p = s.payload
	local tier = SpinCurve.tier(p.rarity)
	s.mode = "reveal"
	s.t = 0
	s.drone.Volume = s.droneVolume
	s.boost = if tier == 6 then 1 else s.boost -- Mythic pulls the whale close
	s.rv = {
		tier = tier,
		t = 0,
		color = GLOW[tier],
		built = false,
		duplicate = p.duplicate == true,
		shattered = false,
		buildDur = SpinCurve.BUILD_DUR[tier],
		-- nothing waits for a button any more: an owned prize still gets time to read its payout after the shatter
		hold = SpinCurve.HOLD[tier] + (if p.duplicate == true then 1 else 0),
	}
	s.prize = Prize.reveal(p, s.stage.folder, s.rv.buildDur, PRIZE_SIZE)
	local top = s.frame * CFrame.new(0, R * 0.8, -1)
	fx(
		"wheel_win",
		CFrame.new(top.Position),
		{ color = s.rv.color, scale = SpinCurve.BURST[tier] * 0.6 }
	)
	sfx("Album_Sticker", 0.8, 1.2)
	sfx("FX_PlasticRain", 0.5, 0.9) -- the bricks are on their way
end

local function finishPrize(s: any)
	local R_ = s.rv
	R_.built = true
	s.kick = 0.4
	if R_.tier >= 4 then
		s.shake = math.max(s.shake, 0.55)
	end
	local at = s.frame * CFrame.new(0, 0.09 * H * 0.7, PRIZE_Z)
	local jackpot = R_.tier >= 5
	fx(
		if jackpot then "fx1_wheel_jackpot" else "wheel_win",
		CFrame.new(at.Position),
		{ color = R_.color, scale = SpinCurve.BURST[R_.tier] }
	)
	sfx("UI_Pickup", 0.7, 1)
	if R_.tier >= 3 and not jackpot then
		sfx("Album_Sparkle", 1, 1)
	end
	if R_.tier >= 4 then
		sfx("Music_CrateFanfare", 1, 1)
	end
	if s.payload.kind == "cash" then
		sfx("Cash_Coins", 0.9, 1)
		fx("deep_coins", CFrame.new(at.Position), { scale = 0.6 })
	end
	if R_.duplicate then
		s.prize.grey()
	end
	showLabel(s)
	player:SetAttribute("SpinRevealed", os.clock()) -- HudController lands the held Cash now
end

local function shatter(s: any)
	local R_ = s.rv
	R_.shattered = true
	local at = s.frame * CFrame.new(0, 0.09 * H * 0.7, PRIZE_Z)
	fx("wheel_win", CFrame.new(at.Position), { color = rgb(124, 133, 145), scale = 0.6 })
	fx("deep_coins", CFrame.new(at.Position), { scale = 0.6 })
	sfx("Cash_Coins", 1, 1)
	s.prize.hide()
	local cash = tonumber(s.payload.duplicateCash)
	s.pillText.Text = "OWNED"
	s.nameLabel.Text = if cash then `+{cash} Cash` else "Owned"
end

---------------------------------------------------------------- the frame

local function tick(s: any, speed: number)
	local ticks = math.floor((s.angle + 15) / STEP)
	if ticks ~= s.ticks then
		local d = math.abs(ticks - s.ticks)
		s.ticks = ticks
		local sign = if speed == 0 then 1 elseif speed > 0 then 1 else -1
		s.flapV -= math.min(d, 2) * 6 * sign
		if math.abs(speed) < 950 then -- single, countable ticks; above that the roar takes over
			sfx("UI_Prompt", 0.45, 1.25 + math.min(math.abs(speed), 900) / 1800)
		end
	end
end

local function stepDive(s: any, dt: number)
	local k = s.t
	local d = SpinCurve.dive(k)
	s.zoom = d.zoom
	s.angle += d.speed * dt
	tick(s, d.speed)
	s.speed = d.speed
	s.roar.Volume = s.roarVolume * math.min(d.speed / 1500, 1) * 0.6
	s.roar.PlaybackSpeed = 0.6 + d.speed / 1500 * 0.5
	if not s.reduced then
		s.shake = math.max(s.shake, if s.inSet then 0 else d.crack * 0.62)
	end
	s.stage:setCracks(d.crack)
	if not s.inSet and k >= SpinCurve.T_BREAK then
		-- the cut: the same frame in the private set, hidden by the burst
		s.inSet = true
		s.place = s.stage.origin
		s.stage:showCracks(nil)
		s.stage:throwPlates(s.grass)
		s.shake, s.kick, s.flash = 1.25, -0.7, 0.08
		fx("deep_ground_burst", CFrame.new((s.place * CFrame.new(0, -10, 0)).Position))
	end
	s.stage:stepPlates(dt)
	s.frameY = -d.fall * H + d.bob * H
	s.camY = -d.fall * H
	s.stage:setStand(
		if s.inSet then s.place * CFrame.new(0, -10, 0) else s.groundFrame,
		d.broken,
		true
	)
	if not s.didWater and s.camY <= Set.WATER then
		s.didWater = true
		s.impact = 1
		s.kick, s.flash = -0.55, 0.1
		s.shake = math.max(s.shake, 0.9)
		setUnderwater(s, true)
		s.stage:showDeep()
		s.drone:Play()
		fx("deep_water_burst", facing(s, (s.place * CFrame.new(0, s.camY, 0)).Position))
	end
	local rush = if s.didWater
		then 1 - smooth(SpinCurve.T_DIVE, SpinCurve.T_PLUNGE, k) * 0.85
		else 0
	s.rushAt -= dt
	if rush > 0.02 and s.rushAt <= 0 then
		s.rushAt = 0.09
		fx(
			"deep_rush",
			CFrame.new((s.place * CFrame.new(math.random(-12, 12), s.camY - 16, -6)).Position),
			{ scale = rush }
		)
	end
	if k >= SpinCurve.T_PLUNGE then
		s.frameY, s.camY = Set.DEEP, Set.DEEP
		s.stage:setStand(s.place * CFrame.new(0, -10, 0), 1, false)
		s.deep = 1
		s.stage:dropShaft()
		startSpin(s)
	end
end

local function stepSpin(s: any, dt: number)
	if s.hold > 0 then
		s.hold -= dt -- hit-stop: the wheel visibly bites on each slam
	end
	s.st += if s.hold > 0 then dt * 0.1 else dt
	local prev = s.angle
	s.angle = s.curve.at(s.st)
	s.speed = (s.angle - prev) / math.max(dt, 1e-4)
	s.claw = SpinCurve.table(SpinCurve.CLAW_KEYS, s.st)
	local speedK = math.min(math.abs(s.speed) / SpinCurve.MAX_SPEED, 1)
	s.sw = lerp(s.sw, speedK, damp(4, dt))
	s.swA += dt * (3 + speedK * 15)
	local windK = if s.st < SpinCurve.T_RELEASE then smooth(0.1, 0.78, s.st) else 0
	s.zoom = lerp(s.zoom, 1 + (if s.reduced then 0 else speedK * 0.17 + windK * 0.07), damp(5, dt))
	if s.st < SpinCurve.T_RELEASE and s.st > 0.1 then
		s.shake = math.max(s.shake, windK * 0.22)
	end
	if s.ev == 0 and s.st >= SpinCurve.T_RELEASE then
		release(s)
		s.ev = 1
	end
	for i, at in SpinCurve.T_SLAM do
		if s.ev == i and s.st >= at then
			slam(s, i - 1)
			s.ev = i + 1
		end
	end
	s.gripAt -= dt
	if s.claw > 0.92 and math.abs(s.speed) > 150 and s.gripAt <= 0 then -- brake pads spit sparks while they grip
		s.gripAt = 0.12
		for _, side in { 1, -1 } do
			fx(
				"deep_grip",
				CFrame.fromMatrix(
					(s.frame * CFrame.new(side * R * 1.035, 0, -1)).Position,
					s.stage.origin.RightVector,
					s.stage.origin.UpVector * side
				)
			)
		end
	end
	tick(s, s.speed)
	s.roar.Volume = if s.st < SpinCurve.T_RELEASE then 0 else speedK * s.roarVolume
	s.roar.PlaybackSpeed = 0.55 + speedK * 1.15
	if s.st >= SpinCurve.T_END then
		s.angle = s.curve.final
		s.speed = 0
		s.mode = "stop"
		s.t = 0
		s.roar.Volume = 0
		s.drone.Volume = 0
		s.stage:setWedge(s.segment, 1, 1)
	end
end

local function stepReveal(s: any, dt: number)
	local R_ = s.rv
	s.claw = lerp(s.claw, 0, damp(14, dt))
	s.sw = lerp(s.sw, 0, dt * 3)
	s.swA += dt * 2
	s.zoom = lerp(s.zoom, 0.84, damp(4, dt))
	s.dim = lerp(s.dim, 0.62, damp(9, dt))
	s.rar = lerp(s.rar, SpinCurve.GLOW[R_.tier], damp(5, dt))
	R_.t += dt
	s.prize.step(
		s.prize,
		dt,
		s.place * CFrame.new(0, s.camY + 0.09 * H * 0.7 - PRIZE_SIZE * 0.42, PRIZE_Z)
	)
	if not R_.built and R_.t >= R_.buildDur then
		finishPrize(s)
	end
	if R_.built and R_.duplicate and not R_.shattered and R_.t >= R_.buildDur + 0.6 then
		shatter(s)
	end
	if s.mode == "reveal" and R_.t >= R_.buildDur + R_.hold then
		surface(s)
	end
	s.boost = math.max(0, s.boost - dt * 0.16)
end

local function step(dt: number)
	local s = run
	if not s then
		return
	end
	s.t += dt
	s.time += dt
	s.guiCheck -= dt
	if s.guiCheck <= 0 then
		s.guiCheck = 0.5
		hideGuis(s) -- a toast or a join prompt switching its ScreenGui on mid-show stays down
	end
	if s.mode == "dive" then
		stepDive(s, dt)
	elseif s.mode == "spin" then
		stepSpin(s, dt)
	elseif s.mode == "stop" then
		s.claw = lerp(s.claw, 0, damp(7, dt))
		local k = smooth(0, 0.2, s.t)
		s.stage:setWedge(nil, 1 + 0.15 * easeOutBack(k), 1)
		s.stage:setDim(0.55 * k, 0)
		if s.t >= SpinCurve.T_STOP then
			startReveal(s)
		end
	elseif s.mode == "reveal" then
		stepReveal(s, dt)
	elseif s.mode == "surface" then
		stepReveal(s, dt) -- the prize keeps turning until the water has covered it
		local k = s.t
		s.wall.BackgroundTransparency = 1 - smooth(0, 0.14, k)
		s.wall.Position = UDim2.fromScale(0, 1 - 1.2)
		if k >= 0.16 then -- the frame is covered: the real wheel, whole, waits behind the wall
			local gui, wall = s.wall.Parent, s.wall
			s.wallGui = nil
			leave()
			runWall(gui, wall, k)
			return
		end
	end
	if s ~= run then
		return
	end

	-- springs and decays, verbatim
	s.tiltV += (-s.tilt * 130 * dt) - s.tiltV * 12 * dt
	s.tilt += s.tiltV * dt
	s.flap += s.flapV * dt * 60 * 0.016
	s.flapV += (-s.flap * 240 - s.flapV * 19) * dt
	s.flap = math.clamp(s.flap, -0.75, 0.75)
	s.impact = math.max(0, s.impact - dt * 2.6)
	s.shake = math.max(0, s.shake - dt * 3.5)
	s.kick = lerp(s.kick, 0, damp(8, dt))
	s.flash = math.max(0, s.flash - dt * 0.85)

	-- the wheel's frame
	local still = s.reduced
	local shk = if still then 0 else s.shake * s.shake * 2.2 * U
	local tilt = if still then 0 else s.tilt
	local roll = if still
		then 0
		else tilt
			+ s.sw * 0.05 * math.sin(s.time * 1.2)
			+ math.sin(s.time * 97) * s.shake * s.shake * 0.018
	local yaw = (if still then 0 else 0.13 * math.sin(s.time * 0.42) * s.deep) + s.sw * 0.05
	local x = -(tilt * 40 * U) - math.sin(s.time * 91) * shk
	local y = s.frameY + math.cos(s.time * 83) * shk + 0.015 * math.sin(s.time * 0.9) * s.deep * H
	local frame = s.place
		* CFrame.new(x, y, 0)
		* CFrame.Angles(0, 0, roll)
		* CFrame.Angles(0, yaw, 0)
	s.frame = frame
	local bend = math.clamp(s.speed / SpinCurve.MAX_SPEED * 0.65 + s.flap, -0.75, 0.75)
	s.stage:place(frame, s.angle, bend)
	s.stage:setBlur(smooth(450, 1500, math.abs(s.speed)))
	s.stage:setBulbs(s.time, s.sw)
	local jitter = if s.mode == "spin"
			and s.claw > 0.9
			and not still
		then math.sin(s.time * 73) * 0.6 * U * math.min(math.abs(s.speed) / 1400, 1)
		else 0
	s.stage:setClaws(frame, s.claw, jitter)
	s.stage:setVortex(frame, s.sw * (if still then 0.4 else 1), s.swA)
	if s.rv then
		s.stage:setDim(0.55, 0.75 * math.min(s.dim / 0.62, 1))
		s.stage:setGlow(frame, s.rv.color, s.rar, if s.rv.tier >= 3 then s.rar * 0.7 else 0, s.time)
	end
	if s.didWater then
		s.stage:stepDeep(s.time - s.whaleT0, s.boost)
		s.bubbleAt -= dt
		if s.bubbleAt <= 0 then
			s.bubbleAt = 0.6
			fx(
				"deep_bubbles",
				CFrame.new(
					(s.place * CFrame.new(math.random(-16, 16), s.camY - 11, math.random(-8, 10))).Position
				)
			)
		end
	end

	-- the camera: fixed framing, the wheel at 0.53 H, the width of the shot held by FOV (zoom, kick)
	local dist = if s.inSet then Set.DIST else s.landDist
	local zoom = s.zoom + (if still then 0 else s.kick * 0.045)
	local eye = s.place * CFrame.new(0, s.camY + 0.03 * H, -dist)
	local look = s.place * CFrame.new(0, s.camY + 0.03 * H, 0)
	local cf = CFrame.lookAt(eye.Position, look.Position, s.place.UpVector)
	local fov = math.deg(2 * math.atan((H / (2 * zoom)) / dist))
	if s.mode == "dive" and s.t < 0.3 then -- the swoop from wherever the player was looking
		local e = smooth(0, 0.3, s.t)
		cf = s.camFrom:Lerp(cf, e)
		fov = lerp(s.fovBack, fov, e)
	end
	CameraController.SetOverride(cf, fov)

	-- the white-water burst and small flashes, soft and skipped under reduce motion
	local wash = if still then 0 else math.max(s.flash, s.impact * s.impact * 0.55)
	s.wash.BackgroundTransparency = 1 - wash
end

local function onInput(input: InputObject, processed: boolean)
	local s = run
	if not s then
		return
	end
	local key, kind = input.KeyCode, input.UserInputType
	local tap = kind == Enum.UserInputType.MouseButton1
		or kind == Enum.UserInputType.Touch
		or key == Enum.KeyCode.ButtonA
		or key == Enum.KeyCode.Space
		or key == Enum.KeyCode.Return
	if s.mode == "reveal" and tap and not processed then
		local rv = s.rv
		if not rv.built then -- skip the build, then skip the hold
			rv.t = rv.buildDur
			s.prize.finish()
		elseif rv.t > rv.buildDur + 0.15 and (not rv.duplicate or rv.shattered) then
			surface(s)
		end
	end
end

---------------------------------------------------------------- in

local function enter(ctx: any)
	local payload = ctx.payload
	local cam = Workspace.CurrentCamera
	local hub: CFrame = ctx.hub
	local wheel: Model = ctx.wheel
	local character = player.Character

	-- the real plaza under the wheel (its colour, its height) and the room in front of the wheel
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = if character then { wheel, character } else { wheel }
	params.IgnoreWater = true
	local grass = rgb(79, 191, 70)
	local groundY = hub.Position.Y - 10
	local hit = Workspace:Raycast(hub.Position, Vector3.new(0, -30, 0), params)
	if hit then
		groundY = hit.Position.Y
		if not hit.Instance:IsA("Terrain") then
			grass = hit.Instance.Color
		end
	end
	local room = Workspace:Raycast(hub.Position, hub.LookVector * Set.DIST, params)

	local s: any = {
		ctx = ctx,
		payload = payload,
		segment = math.clamp(tonumber(payload.segment) or 1, 1, SpinCurve.COUNT),
		wheel = wheel,
		hub = hub,
		mode = "dive",
		t = 0,
		time = 0,
		guiCheck = 0.5,
		reduced = reducedMotion(),
		place = hub,
		inSet = false,
		didWater = false,
		grass = grass,
		landDist = if room then math.clamp(room.Distance - 1, 14, Set.DIST) else Set.DIST,
		groundFrame = hub * CFrame.new(0, groundY - hub.Position.Y, 0),
		camFrom = cam.CFrame,
		fovBack = cam.FieldOfView,
		frameY = 0,
		camY = 0,
		frame = hub,
		angle = 0,
		speed = 0,
		ticks = 0,
		flap = 0,
		flapV = 0,
		tilt = 0,
		tiltV = 0,
		shake = 0,
		kick = 0,
		flash = 0,
		impact = 0,
		zoom = 0.78,
		sw = 0,
		swA = 0,
		claw = 0,
		dim = 0,
		rar = 0,
		hold = 0,
		deep = 0,
		boost = 0,
		rushAt = 0,
		gripAt = 0,
		bubbleAt = 0,
		whaleT0 = 1.3 - 26 * (0.2 + 0.45) / 1.9, -- it is already crossing when you arrive
		hidden = {},
		conns = {},
		eq = {},
		promptsWere = ProximityPromptService.Enabled,
	}
	s.stage = Set.new(hub, grass, lowQuality())
	s.stage:place(hub, 0, 0)
	s.stage:showCracks(s.groundFrame)
	s.stage:setStand(s.groundFrame, 0, true)
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "DeepSpinGrade"
	grade.TintColor = rgb(214, 244, 248)
	grade.Contrast, grade.Saturation = 0.08, 0.12
	grade.Enabled = false
	grade.Parent = cam
	s.grade = grade
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		s.air = {
			part = atmo,
			density = atmo.Density,
			haze = atmo.Haze,
			glare = atmo.Glare,
			color = atmo.Color,
			decay = atmo.Decay,
		}
	end
	s.drone = AudioController.newSound("Under_Ambience", nil, true)
	s.droneVolume = s.drone.Volume
	s.roar = AudioController.newSound("Hull_Wake", nil, true)
	s.roarVolume = s.roar.Volume
	s.roar.Volume = 0
	s.roar:Play()
	buildGui(s)

	run = s
	hideGuis(s)
	ProximityPromptService.Enabled = false
	setWorldHidden(s, true)
	setControls(false)
	player:SetAttribute("SpinCinematic", true)
	table.insert(s.conns, UserInputService.InputBegan:Connect(onInput))
	table.insert(s.conns, player.CharacterRemoving:Connect(leave))
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		table.insert(s.conns, hum.Died:Connect(leave))
	end
	sfx("Rigging_Creak", 2.5, 0.9) -- the wheel grinds up
	sfx("FX_Boom", 0.5, 0.5) -- the rumble under it
	RunService:BindToRenderStep("DeepSpin", Enum.RenderPriority.Camera.Value, function(dt: number)
		local ok, err = pcall(step :: any, dt)
		if not ok then
			warn(`[DeepSpin] {err}`)
			leave() -- never strand the camera
		end
	end)
end

function Sequence.start(ctx: any)
	if not run then
		enter(ctx)
	end
end

function Sequence.active(): boolean
	return run ~= nil
end

function Sequence.whenDone(fn: () -> ())
	if run then
		table.insert(after, fn)
	else
		fn()
	end
end

-- so the first spin has no blank frame
function Sequence.preload()
	task.spawn(function()
		local list = {}
		for _, id in (AssetIds :: any).DeepSpin do
			local d = Instance.new("Decal")
			d.Texture = id
			table.insert(list, d)
		end
		pcall(function()
			ContentProvider:PreloadAsync(list)
		end)
		for _, d in list do
			d:Destroy()
		end
	end)
end

return Sequence
