--!strict
-- Layout: the one HUD layout. Every HUD element sits inside a named screen region. The geometry
-- is pure and lives in Shared/HudLayout (tests/HudLayout.spec.luau); this module turns it into
-- live ScreenGui containers.
--
-- Desktop / gamepad:
--
--   +------------------------------------------------------------------+
--   | menu  objective       notice (toasts, call-outs)                 |
--   | menu  (step card)                                                |
--   | menu                  prompt (mechanic panels,          [sale]  |
--   | menu                                                     [quest]  |
--   | menu                  interaction cards)               [pill]   |
--   | wallet (Cash)                                          minimap  |
--   +------------------------------------------------------------------+
--
-- Touch: the menu grid (UI/Menu, as many rows as fit above the thumbstick) top left, the objective strip
-- right of it, the 100-130 px minimap in the top-right corner (portrait: right of the menu; tap it for the
-- full map), the wallet (Cash) under the objective and the notice band beside or under the wallet. Nothing reaches into the
-- thumbstick or the jump / action buttons (HudLayout).
--
-- Regions are transparent container Frames in "design units" (du): the usable area (the
-- ScreenGui with CoreUISafeInsets: below the Roblox top bar and inside notches / home bar)
-- divided by a UIScale of `scale` (0.7 on phones up to 1.6 on big screens). Children use
-- plain scale + offset inside their region. Containers track the viewport live.
--
-- Cold open (docs 09 9.1, a new player's first rescue on the jet ski): Layout.coldOpen() is true
-- from the moment the player rides a ColdOpen craft until the player attribute ColdOpenDone; the
-- HUD shows only the interaction prompt, the speed dock and the minimap then.
-- The minimap stays visible on purpose: with 3D waypoint arrows off it is the only guidance to
-- the casualty; the world marker (UI/Waypoint: icon + distance) is the one objective readout (no step strip).
-- Layout.onColdOpen(fn) calls fn(active) now and on every change.
-- Layout.promptBusy() is true while any "prompt" region holds a visible panel (polled every 0.25 s).
-- Layout.newPlayer() is true on a new-profile HUD: the cold open and the first 3 calls after it.
-- Layout.quietHud() is true until the boat's first level-up (the side menus and Robux chips wait).
--
-- Phone check (tests/HudLayout.spec.luau: phones and tablets, landscape and portrait, scale 0.7+):
-- every region ends above the thumbstick zone at 55% of the safe height and clear of the jump zone.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Comfort = require(script.Parent.Parent:WaitForChild("Camera"):WaitForChild("Comfort"))
local HudLayout = require(Shared:WaitForChild("HudLayout"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))

local Layout = {}

Layout.MARGIN = HudLayout.MARGIN
Layout.GAP = HudLayout.GAP
Layout.SUBTITLE_HEIGHT = HudLayout.SUBTITLE_HEIGHT
Layout.OBJECTIVE_HEIGHT = HudLayout.OBJECTIVE_HEIGHT
Layout.PROMPT_HEIGHT = HudLayout.PROMPT_HEIGHT
Layout.NOTICE_HEIGHT = HudLayout.NOTICE_HEIGHT
Layout.WALLET_WIDTH = HudLayout.WALLET_WIDTH
Layout.WALLET_HEIGHT = HudLayout.WALLET_HEIGHT

export type RegionName = HudLayout.RegionName
export type Metrics = HudLayout.Metrics

-- Text size (100 / 125 / 150 %): HudTheme labels scale by this and redraw on a change.
local textScaleEvent = Instance.new("BindableEvent")

function Layout.textScale(): number
	return Comfort.textScale()
end

function Layout.onTextScale(fn: (number) -> ()): RBXScriptConnection
	local c = textScaleEvent.Event:Connect(fn)
	task.spawn(fn, Layout.textScale())
	return c
end

Comfort.changed:Connect(function(key: string)
	if key == "textSize" then
		textScaleEvent:Fire(Layout.textScale())
	end
end)

-- Pure: the region metrics for a usable area in pixels (false = desktop / gamepad).
function Layout.metrics(px: Vector2, touch: boolean?): Metrics
	return HudLayout.metrics(px, touch == true)
end

-- Pure: anchor, position and size (all offsets, du) of a region.
function Layout.rect(name: RegionName, mt: Metrics): (Vector2, Vector2, Vector2)
	local r = mt.rects[name]
	return r.anchor, r.pos, r.size
end

-- ---------------------------------------------------------------- live containers

type Entry = { frame: Frame, scale: UIScale, name: RegionName, gui: ScreenGui }
local entries: { Entry } = {}
local current: Metrics? = nil
local metricsChanged = Instance.new("BindableEvent")

local ZERO_INSETS = { top = 0, bottom = 0, left = 0, right = 0 }

-- Touch hardware, not the last input: a paired gamepad must not flip the HUD mid-rescue.
local function device(): string
	-- Studio only: Workspace attribute HudDevice ("Touch" | "Gamepad" | "Keyboard") previews another layout
	local forced = RunService:IsStudio() and Workspace:GetAttribute("HudDevice")
	if forced == "Touch" or forced == "Gamepad" or forced == "Keyboard" then
		return forced
	end
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Touch"
	elseif UserInputService.GamepadEnabled and not UserInputService.MouseEnabled then
		return "Gamepad"
	end
	return "Keyboard"
end

-- "Touch" | "Gamepad" | "Keyboard": the device the HUD is laid out for (TouchDriveController shows its pad on Touch)
Layout.device = device

local function metricsNow(gui: ScreenGui?): Metrics
	local px = if gui then gui.AbsoluteSize else Vector2.zero
	-- Studio only: Workspace attribute HudViewport (Vector2 px) lays the HUD out for that screen in the
	-- top-left corner (a phone-sized preview on a desktop window)
	local forced = RunService:IsStudio() and Workspace:GetAttribute("HudViewport")
	if typeof(forced) == "Vector2" then
		px = forced
	end
	if px.X >= 1 and px.Y >= 1 then
		return HudLayout.compute(px, ZERO_INSETS, device())
	end
	-- no screen yet: the camera viewport minus the GuiService top-bar inset
	local cam = Workspace.CurrentCamera
	local screen = if cam then cam.ViewportSize else Vector2.new(1366, 768)
	local inset = GuiService:GetGuiInset()
	return HudLayout.compute(
		screen,
		{ top = inset.Y, bottom = 0, left = inset.X, right = 0 },
		device()
	)
end

local function place(e: Entry, mt: Metrics)
	local anchor, pos, size = Layout.rect(e.name, mt)
	-- the frame's own size is scaled by UIScale about its anchor; positions are px in the gui
	e.scale.Scale = mt.scale
	e.frame.AnchorPoint = anchor
	e.frame.Position = UDim2.fromOffset(pos.X * mt.scale, pos.Y * mt.scale)
	e.frame.Size = UDim2.fromOffset(size.X, size.Y)
end

local function refresh(gui: ScreenGui?)
	local mt = metricsNow(gui)
	local prev = current
	current = mt
	for i = #entries, 1, -1 do
		local e = entries[i]
		if e.frame.Parent == nil then
			table.remove(entries, i)
		else
			place(e, mt)
		end
	end
	if not prev or prev.scale ~= mt.scale or prev.usable ~= mt.usable or prev.touch ~= mt.touch then
		metricsChanged:Fire(mt)
	end
end

-- Sets a HUD ScreenGui up for the layout (safe area, no top bar overlap).
function Layout.prepare(gui: ScreenGui): ScreenGui
	gui.IgnoreGuiInset = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		refresh(gui)
	end)
	if RunService:IsStudio() then
		Workspace:GetAttributeChangedSignal("HudDevice"):Connect(function()
			refresh(gui)
		end)
		Workspace:GetAttributeChangedSignal("HudViewport"):Connect(function()
			refresh(gui)
		end)
	end
	return gui
end

-- The region's container in `gui` (created once per gui). Parent HUD elements to it.
function Layout.region(gui: ScreenGui, name: RegionName): Frame
	local key = `Region_{name}`
	local existing = gui:FindFirstChild(key)
	if existing and existing:IsA("Frame") then
		return existing
	end
	local f = Instance.new("Frame")
	f.Name = key
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.ClipsDescendants = false
	f:SetAttribute("HudRegion", true) -- HudTheme's phone text floor reads the scale under it
	local sc = Instance.new("UIScale")
	sc.Parent = f
	f.Parent = gui
	local e: Entry = { frame = f, scale = sc, name = name, gui = gui }
	table.insert(entries, e)
	if not current then
		refresh(gui)
	end
	place(e, current :: Metrics)
	return f
end

function Layout.current(): Metrics
	if not current then
		refresh(nil)
	end
	return current :: Metrics
end

function Layout.onMetrics(fn: (Metrics) -> ()): RBXScriptConnection
	return metricsChanged.Event:Connect(fn)
end

-- ---------------------------------------------------------------- cold open

local coldOpenEvent = Instance.new("BindableEvent")
local coldOpenActive = false
local coldOpenSince = 0
local coldOpenExpired = false
local COLD_OPEN_MAX = 600 -- s: never keep the HUD stripped past this (fail-safe)

local function ridingColdOpen(player: Player): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local model = seat and seat:FindFirstAncestorOfClass("Model")
	return model ~= nil
		and (model:GetAttribute("ColdOpen") == true or model:GetAttribute("ColdOpenOpId") ~= nil)
end

local function evaluate()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	if coldOpenActive and os.clock() - coldOpenSince > COLD_OPEN_MAX then
		coldOpenExpired = true
	end
	local active = coldOpenActive
	if player:GetAttribute("ColdOpenDone") == true or coldOpenExpired then
		active = false
	elseif not active and ridingColdOpen(player) then
		active = true -- latched: stays stripped while swimming / recovering off the ski
		coldOpenSince = os.clock()
	end
	if active ~= coldOpenActive then
		coldOpenActive = active
		coldOpenEvent:Fire(active)
	end
end

local promptIsBusy = false

local function anyPromptPanel(): boolean
	for _, e in entries do
		if e.name == "prompt" and e.frame.Visible and e.gui.Enabled and e.gui.Parent ~= nil then
			for _, ch in e.frame:GetChildren() do
				if ch:IsA("GuiObject") and ch.Visible then
					return true
				end
			end
		end
	end
	return false
end

-- Viewport px boxes (IgnoreGuiInset space) round the visible HUD in the edge regions, 4x a second: world pins and
-- their edge arrows keep out of them (UI/Waypoint; playtest 2026-10-26: pins hid behind the menu buttons)
export type Box = { min: Vector2, max: Vector2 }
local EDGE_REGIONS = {
	menu = true,
	wallet = true,
	objective = true,
	minimap = true,
	gauges = true,
	quest = true,
	sale = true, -- the timed-sale button (UI/Menu)
	chips = true, -- the Next / tutorial chips (SE device pass 2026-10-28: "40 m" slid under them)
	steer = true, -- the touch drive pad (TouchDriveController)
	drive = true,
	goback = true,
}
local hudBoxes: { Box } = {}

local function boxHud(): { Box }
	local out: { Box } = {}
	local inset = GuiService:GetGuiInset()
	for _, e in entries do
		if EDGE_REGIONS[e.name] and e.frame.Visible and e.gui.Enabled and e.gui.Parent ~= nil then
			local lo, hi = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
			for _, ch in e.frame:GetChildren() do
				if ch:IsA("GuiObject") and ch.Visible and ch.AbsoluteSize.X > 1 then
					lo, hi =
						lo:Min(ch.AbsolutePosition), hi:Max(ch.AbsolutePosition + ch.AbsoluteSize)
				end
			end
			if lo.X < hi.X then
				local off = if e.gui.IgnoreGuiInset then Vector2.zero else inset
				table.insert(out, { min = lo + off, max = hi + off })
			end
		end
	end
	return out
end

function Layout.hudBoxes(): { Box }
	return hudBoxes
end

-- A screen pin at `at` (viewport px) slid toward the screen centre until it clears every HUD box, kept `clear` px
-- off each side and `hang` px more above (a label hanging under the pin). Pushing out of one box at a time parked
-- pins in the gap between the menu column and the quest chip (playtest 2 2026-10-26: on the Settings button).
local function blocked(p: Vector2, clear: Vector2, up: Vector2): boolean
	for _, b in hudBoxes do
		local lo, hi = b.min - clear - up, b.max + clear
		if p.X > lo.X and p.X < hi.X and p.Y > lo.Y and p.Y < hi.Y then
			return true
		end
	end
	return false
end

function Layout.clearOfHud(at: Vector2, clear: Vector2, hang: number?): Vector2
	local cam = Workspace.CurrentCamera
	local centre = if cam then cam.ViewportSize / 2 else at
	local up = Vector2.new(0, hang or 0)
	for i = 0, 24 do
		local p = at:Lerp(centre, i / 24)
		if not blocked(p, clear, up) then
			return p
		end
	end
	-- boxed in on the way to the centre (the menu column, a goal to the left): slide along the screen edge past it, so
	-- a pointer never lands on the avatar
	local bottom = centre.Y * 2 - clear.Y
	for i = 1, 24 do
		for _, y in { at.Y + (bottom - at.Y) * i / 24, at.Y + (clear.Y - at.Y) * i / 24 } do
			local p = Vector2.new(at.X, y)
			if not blocked(p, clear, up) then
				return p
			end
		end
	end
	return centre -- boxed in all the way: over the play view, never under the HUD
end

-- An off-screen goal's edge pin (viewport px): where `dir` (from the screen centre) meets the screen edge, `inset` px
-- in (below the top bar), slid ALONG that edge until clear of the HUD. Slid toward the centre it sat mid-screen
-- beside on-screen pins (AD phone pass 2026-11-01); only a fully blocked edge falls back to clearOfHud.
function Layout.onEdge(dir: Vector2, inset: Vector2, clear: Vector2, hang: number?): Vector2
	local cam = Workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1366, 768)
	local lo = inset + Vector2.new(0, GuiService:GetGuiInset().Y)
	local hi = vp - inset
	local c, half = (lo + hi) / 2, ((hi - lo) / 2):Max(Vector2.one)
	if dir.Magnitude < 1e-3 then
		dir = Vector2.yAxis
	end
	local kx = half.X / math.max(math.abs(dir.X), 1e-6)
	local ky = half.Y / math.max(math.abs(dir.Y), 1e-6)
	local at = c + dir * math.min(kx, ky)
	local along = if kx < ky then Vector2.yAxis else Vector2.xAxis -- a side edge slides up / down, top or bottom across
	local up = Vector2.new(0, hang or 0)
	for s = 0, 2 * math.max(half.X, half.Y), 8 do
		for _, sign in { 1, -1 } do
			local p = (at + along * s * sign):Max(lo):Min(hi)
			if not blocked(p, clear, up) then
				return p
			end
		end
	end
	return Layout.clearOfHud(at, clear, hang)
end

-- A world prompt's BillboardGui slid (SizeOffset, +Y up) clear of the HUD boxes like the pins: "E Build" drew under
-- the Next chip (in-game AD 2026-11-01). `base` is the gui's own SizeOffset. Call it every frame while it shows.
function Layout.keepClear(bb: BillboardGui, base: Vector2?)
	local b = base or Vector2.zero
	local cam = Workspace.CurrentCamera
	local a = bb.Adornee
	local size = Vector2.new(bb.Size.X.Offset, bb.Size.Y.Offset)
	local at = if a and a:IsA("BasePart")
		then a.Position
		elseif a and a:IsA("Attachment") then a.WorldPosition
		else nil
	if not (cam and at) or size.X < 1 or size.Y < 1 then
		return
	end
	local p, on = cam:WorldToViewportPoint(at + bb.StudsOffsetWorldSpace)
	if not on then
		return
	end
	local centre = Vector2.new(p.X + b.X * size.X, p.Y - b.Y * size.Y)
	local d = Layout.clearOfHud(centre, size / 2) - centre
	bb.SizeOffset = b + Vector2.new(d.X / size.X, -d.Y / size.Y)
end

function Layout.promptBusy(): boolean
	return promptIsBusy
end

function Layout.coldOpen(): boolean
	return coldOpenActive
end

function Layout.onColdOpen(fn: (boolean) -> ()): RBXScriptConnection
	local c = coldOpenEvent.Event:Connect(fn)
	task.spawn(fn, coldOpenActive)
	return c
end

-- ---------------------------------------------------------------- new player

-- New-player HUD (docs/15 section 3): the cold open and the first three calls keep the screen
-- bare. `OpsCompletedTotal` is saved, so a returning player is never treated as new.
local newPlayerActive = false

local function evaluateNewPlayer()
	local player = Players.LocalPlayer
	if not player then
		return
	end
	local total = player:GetAttribute("OpsCompletedTotal")
	newPlayerActive = Onboarding.newPlayerHud(
		player:GetAttribute("ColdOpenDone") == true,
		if type(total) == "number" then total else nil
	)
end

function Layout.newPlayer(): boolean
	return newPlayerActive
end

-- Quiet HUD (fresh-player audit 2026-11-07): until the first boat level-up only the boat loop's buttons show (Menu hides
-- Album, Pet, Crew, Skills and the Starter sale tag; BoatCard the Quick Launch chip). An old save with 5+ rescues is never quiet.
function Layout.quietHud(): boolean
	local p = Players.LocalPlayer
	local level = p and p:GetAttribute("BoatLevel")
	return type(level) == "number"
		and level < Onboarding.UPGRADE_LEVEL
		and (tonumber(p:GetAttribute("Rescued")) or 0) < Onboarding.SKIP_RESCUES
end

if RunService:IsClient() and Players.LocalPlayer then
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			evaluate()
			promptIsBusy = anyPromptPanel()
			hudBoxes = boxHud()
			evaluateNewPlayer()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("ColdOpenDone"):Connect(evaluate)
	Players.LocalPlayer:GetAttributeChangedSignal("OpsCompletedTotal"):Connect(evaluateNewPlayer)
	evaluateNewPlayer()
	local function watchCamera()
		local cam = Workspace.CurrentCamera
		if cam then
			cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				task.defer(function()
					local e = entries[1]
					refresh(if e then e.gui else nil)
				end)
			end)
		end
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
	watchCamera()
end

return Layout
