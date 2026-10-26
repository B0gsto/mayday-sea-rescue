--!strict
-- Layout: the one HUD layout. Every HUD element sits inside a named screen region. The geometry
-- is pure and lives in Shared/HudLayout (tests/HudLayout.spec.luau); this module turns it into
-- live ScreenGui containers.
--
-- Desktop / gamepad:
--
--   +------------------------------------------------------------------+
--   | menu  wallet          notice (toasts, call-outs)        mission  |
--   | menu  objective                                         card     |
--   | menu  (step card)     prompt (mechanic panels,          column   |
--   | menu                  interaction cards)                (pager,  |
--   | menu  minimap                                           monitor) |
--   |       [obj pill]                                        gauges   |
--   +------------------------------------------------------------------+
--
-- Touch: the menu grid (UI/Menu, as many rows as fit above the thumbstick) top left, the 130 px
-- minimap right of it (tap it for the full map), the objective strip right of that, the wallet (Cash)
-- under the objective and the notice band beside or under the wallet. Nothing reaches into the
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
--
-- Phone check (tests/HudLayout.spec.luau: phones and tablets, landscape and portrait, scale 0.7+):
-- every region ends above the thumbstick zone at 55% of the safe height and the card column above
-- the jump zone at 65%.
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

if RunService:IsClient() and Players.LocalPlayer then
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			evaluate()
			promptIsBusy = anyPromptPanel()
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
