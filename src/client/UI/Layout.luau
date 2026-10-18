--!strict
-- Layout: the one HUD layout. Every HUD element sits inside a named screen region, so nothing
-- overlaps at 1366x768, 1920x1080 or a landscape phone (~844x390).
--
--   +------------------------------------------------------------------+
--   | objective          notice (toasts, call-outs)            status  |
--   | (step card)                                              --------|
--   |                                                          right   |
--   |                    prompt (mechanic panels,              column  |
--   |                    interaction cards)                    (pager, |
--   |  [obj pill]                                              monitor)|
--   |  minimap           subtitle (VHF / dispatcher)           gauges  |
--   +------------------------------------------------------------------+
--
-- Regions are transparent container Frames in "design units" (du): the usable area (the
-- ScreenGui with CoreUISafeInsets: below the Roblox top bar and inside notches / home bar)
-- divided by a UIScale of `scale` (1 on desktop, down to MIN_SCALE on phones). Children use
-- plain scale + offset inside their region. Containers track the viewport live.
--
-- Cold open (docs 09 9.1, a new player's first rescue on the jet ski): Layout.coldOpen() is true
-- from the moment the player rides a ColdOpen craft until the player attribute ColdOpenDone; the
-- HUD shows only the objective line, the radio subtitle, the interaction prompt and the minimap
-- then. The minimap stays visible on purpose: with 3D waypoint arrows off it is the only guidance
-- to the casualty (its objective pill and route line). The objective line shows only while no
-- prompt panel is up, since a mechanic panel's header repeats the same step (show it once).
-- Layout.onColdOpen(fn) calls fn(active) now and on every change.
-- Layout.promptBusy() is true while any "prompt" region holds a visible panel;
-- Layout.onPromptBusy(fn) calls fn(busy) now and on every change (polled every 0.25 s).
--
-- Phone check (844x390 landscape, ~750x330 usable): scale clamps to MIN_SCALE 0.7 (so 18 px body
-- text draws at ~12.6 px, the smallest that stays readable), usable 1071x471 du; the objective
-- region ends at 144 du, the prompt region spans 152-333 du, the minimap 303-459 du: no overlap.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Layout = {}

Layout.MARGIN = 12 -- du from the safe-area edge
Layout.GAP = 8 -- du between stacked regions
Layout.SUBTITLE_HEIGHT = 118 -- the VHF set
Layout.STATUS_HEIGHT = 100 -- status strip (52) + crew row (40)
Layout.OBJECTIVE_HEIGHT = 132 -- step card (92) + takeover banner
Layout.PROMPT_HEIGHT = 230
Layout.NOTICE_HEIGHT = 120

local REF_HEIGHT = 720 -- usable px at which the HUD draws 1:1
local REF_WIDTH = 1200
local MIN_SCALE = 0.7

export type RegionName =
	"objective"
	| "status"
	| "right"
	| "notice"
	| "prompt"
	| "subtitle"
	| "minimap"
	| "gauges"

export type Metrics = {
	scale: number,
	usable: Vector2, -- design units
	side: number, -- minimap / gauges square
	objectiveWidth: number,
	rightWidth: number,
	centreWidth: number, -- prompt
	subtitleWidth: number,
	noticeWidth: number,
}

-- Pure: the region sizes for a usable area in pixels (tested numbers in the header).
function Layout.metrics(px: Vector2): Metrics
	local s = math.clamp(math.min(px.Y / REF_HEIGHT, px.X / REF_WIDTH), MIN_SCALE, 1)
	local u = px / s
	local m = Layout.MARGIN
	local side = math.clamp(math.floor(u.Y * 0.3), 156, 230)
	local objectiveWidth = math.clamp(math.floor(u.X * 0.3), 320, 460)
	local rightWidth = math.clamp(math.floor(u.X * 0.24), 280, 360)
	local outer = math.max(side, rightWidth)
	return {
		scale = s,
		usable = u,
		side = side,
		objectiveWidth = objectiveWidth,
		rightWidth = rightWidth,
		centreWidth = math.min(u.X - 2 * (outer + 2 * m), 640),
		subtitleWidth = math.min(u.X - 2 * (side + 2 * m), 620),
		noticeWidth = math.min(u.X - 2 * (math.max(objectiveWidth, rightWidth) + 2 * m), 420),
	}
end

-- Pure: anchor, position and size (all offsets, du) of a region.
function Layout.rect(name: RegionName, mt: Metrics): (Vector2, Vector2, Vector2)
	local m, g, u = Layout.MARGIN, Layout.GAP, mt.usable
	local bottom = u.Y - m
	if name == "objective" then
		return Vector2.new(0, 0),
			Vector2.new(m, m),
			Vector2.new(mt.objectiveWidth, Layout.OBJECTIVE_HEIGHT)
	elseif name == "status" then
		return Vector2.new(1, 0),
			Vector2.new(u.X - m, m),
			Vector2.new(mt.rightWidth, Layout.STATUS_HEIGHT)
	elseif name == "right" then
		local top = m + Layout.STATUS_HEIGHT + g
		local h = math.max(bottom - mt.side - g - top, 120)
		return Vector2.new(1, 0), Vector2.new(u.X - m, top), Vector2.new(mt.rightWidth, h)
	elseif name == "notice" then
		return Vector2.new(0.5, 0),
			Vector2.new(u.X / 2, m),
			Vector2.new(mt.noticeWidth, Layout.NOTICE_HEIGHT)
	elseif name == "prompt" then
		local b = bottom - Layout.SUBTITLE_HEIGHT - g
		local h = math.min(Layout.PROMPT_HEIGHT, b - (m + Layout.OBJECTIVE_HEIGHT + g))
		return Vector2.new(0.5, 1), Vector2.new(u.X / 2, b), Vector2.new(mt.centreWidth, h)
	elseif name == "subtitle" then
		return Vector2.new(0.5, 1),
			Vector2.new(u.X / 2, bottom),
			Vector2.new(mt.subtitleWidth, Layout.SUBTITLE_HEIGHT)
	elseif name == "minimap" then
		return Vector2.new(0, 1), Vector2.new(m, bottom), Vector2.new(mt.side, mt.side)
	else -- gauges
		return Vector2.new(1, 1), Vector2.new(u.X - m, bottom), Vector2.new(mt.side, mt.side)
	end
end

-- ---------------------------------------------------------------- live containers

type Entry = { frame: Frame, scale: UIScale, name: RegionName, gui: ScreenGui }
local entries: { Entry } = {}
local current: Metrics? = nil
local metricsChanged = Instance.new("BindableEvent")

local function usablePixels(gui: ScreenGui?): Vector2
	local px = if gui then gui.AbsoluteSize else Vector2.zero
	if px.X < 1 or px.Y < 1 then
		local cam = Workspace.CurrentCamera
		px = if cam then cam.ViewportSize - Vector2.new(0, 58) else Vector2.new(1366, 710)
	end
	return px
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
	local mt = Layout.metrics(usablePixels(gui))
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
	if not prev or prev.scale ~= mt.scale or prev.usable ~= mt.usable then
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

local promptEvent = Instance.new("BindableEvent")
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

local function evaluatePrompt()
	local busy = anyPromptPanel()
	if busy ~= promptIsBusy then
		promptIsBusy = busy
		promptEvent:Fire(busy)
	end
end

function Layout.promptBusy(): boolean
	return promptIsBusy
end

function Layout.onPromptBusy(fn: (boolean) -> ()): RBXScriptConnection
	local c = promptEvent.Event:Connect(fn)
	task.spawn(fn, promptIsBusy)
	return c
end

function Layout.coldOpen(): boolean
	return coldOpenActive
end

function Layout.onColdOpen(fn: (boolean) -> ()): RBXScriptConnection
	local c = coldOpenEvent.Event:Connect(fn)
	task.spawn(fn, coldOpenActive)
	return c
end

if RunService:IsClient() and Players.LocalPlayer then
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			evaluate()
			evaluatePrompt()
		end
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("ColdOpenDone"):Connect(evaluate)
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
