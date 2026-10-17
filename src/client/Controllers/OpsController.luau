--!strict
-- OpsController: the client side of operations v2 (CONTRACT.md "Operations v2").
-- Discovers step mechanics in src/client/Mechanics/<mechanicId>.luau (Mechanics/Default when one is
-- missing), plays the one the server starts for this player (Ops_StepStart), and submits its
-- result (Ops_StepResult). It also draws a greybox tasking card, an operation strip and a debrief;
-- the radio wheel / tasking card / debrief stream replaces those through the signals below and
-- sets OpsController.UseBuiltInUi = false.
--
-- API for other controllers:
--   OpsController.OnOffer / OnState / OnDebrief / OnRadio / OnClosed : { Connect(self, fn) }
--   OpsController.Accept(opId)            accept a tasking (big call: join)
--   OpsController.TakeStep(stepKey)       swap station: take the step an NPC is doing
--   OpsController.GetState(): snapshot?   the last Ops_State
--   OpsController.GetMechanic(mechanicId) the module that would play it (Default if missing)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudTheme = require(script.Parent.Parent:WaitForChild("UI"):WaitForChild("HudTheme"))
local Remotes =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Remotes"))

type Mechanic = {
	start: (ctx: { [string]: any }, finish: (result: { [string]: any }) -> ()) -> (() -> ())?,
}

local OpsController = {}
OpsController.Priority = 80
OpsController.UseBuiltInUi = true

local function signal()
	local list: { (any) -> () } = {}
	return {
		Connect = function(_self: any, fn: (any) -> ())
			table.insert(list, fn)
			return {
				Disconnect = function()
					local i = table.find(list, fn)
					if i then
						table.remove(list, i)
					end
				end,
			}
		end,
		Fire = function(_self: any, data: any)
			for _, fn in table.clone(list) do
				task.spawn(fn, data)
			end
		end,
	}
end

OpsController.OnOffer = signal()
OpsController.OnState = signal()
OpsController.OnDebrief = signal()
OpsController.OnRadio = signal()
OpsController.OnClosed = signal()

local player = Players.LocalPlayer
local state: { [string]: any }? = nil
local running: { key: string, opId: string, cleanup: (() -> ())? }? = nil
local mechanicsFolder: Instance? = nil
local cache: { [string]: Mechanic } = {}

---------------------------------------------------------------- mechanics

function OpsController.GetMechanic(mechanicId: string): Mechanic
	local cached = cache[mechanicId]
	if cached then
		return cached
	end
	local folder = mechanicsFolder
	local mod = folder and folder:FindFirstChild(mechanicId)
	local chosen: Mechanic? = nil
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and type(result) == "table" and type((result :: any).start) == "function" then
			chosen = result :: any
		else
			warn(`[OpsController] mechanic {mechanicId} failed to load, using the stub: {result}`)
		end
	end
	if not chosen then
		local default =
			assert(folder and folder:FindFirstChild("Default"), "Mechanics/Default missing")
		chosen = (require :: any)(default) :: Mechanic
	end
	assert(chosen, "unreachable")
	cache[mechanicId] = chosen
	return chosen
end

local function cancelRunning()
	local r = running
	running = nil
	if r and r.cleanup then
		pcall(r.cleanup)
	end
end

local function onStepStart(ctx: { [string]: any })
	cancelRunning()
	local key: string = ctx.step.key
	local opId: string = ctx.operation.id
	local entry = { key = key, opId = opId, cleanup = nil :: (() -> ())? }
	running = entry
	local sent = false
	local function finish(result: { [string]: any })
		if sent or running ~= entry then
			return
		end
		sent = true
		running = nil
		Remotes.event("Ops_StepResult"):FireServer(opId, key, result)
	end
	local mechanic = OpsController.GetMechanic(ctx.step.mechanicId)
	local ok, cleanup = pcall(mechanic.start, ctx, finish)
	if not ok then
		warn(`[OpsController] mechanic {ctx.step.mechanicId} errored: {cleanup}`)
		finish({ metrics = {}, failed = true })
		return
	end
	if running == entry then
		entry.cleanup = cleanup
	end
end

---------------------------------------------------------------- greybox UI

local gui: ScreenGui
local offerFrame: Frame
local stripFrame: Frame
local debriefFrame: Frame
local radioLabel: TextLabel
local offerId: string? = nil

local function label(
	parent: Instance,
	text: string,
	y: number,
	h: number,
	size: number,
	dim: boolean?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(14, y)
	l.Size = UDim2.new(1, -28, 0, h)
	l.Font = if dim then HudTheme.BodyFont else HudTheme.BoldFont
	l.TextColor3 = if dim then HudTheme.Colors.textDim else HudTheme.Colors.text
	l.TextSize = size
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.Text = text
	l.Parent = parent
	return l
end

local function panel(name: string, pos: UDim2, size: UDim2, anchor: Vector2): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = anchor
	f.Position = pos
	f.Size = size
	f.BackgroundColor3 = HudTheme.Colors.panel
	f.BackgroundTransparency = HudTheme.PanelTransparency
	f.Visible = false
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, HudTheme.Corner)
	c.Parent = f
	f.Parent = gui
	return f
end

local function button(parent: Instance, text: string, onClick: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1, -12, 1, -10)
	b.Size = UDim2.fromOffset(150, HudTheme.MinButtonHeight)
	b.BackgroundColor3 = HudTheme.Colors.accent
	b.Font = HudTheme.BoldFont
	b.TextColor3 = HudTheme.Colors.text
	b.TextSize = 20
	b.Text = text
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, HudTheme.Corner)
	c.Parent = b
	b.Activated:Connect(onClick)
	b.Parent = parent
	return b
end

local function clear(f: Frame)
	for _, ch in f:GetChildren() do
		if not ch:IsA("UICorner") then
			ch:Destroy()
		end
	end
end

local function showOffer(data: { [string]: any })
	if not OpsController.UseBuiltInUi then
		return
	end
	offerId = data.opId
	clear(offerFrame)
	label(offerFrame, `RADIO · {data.title}`, 10, 26, 22)
	label(offerFrame, data.radioLine, 40, 44, 16, true)
	label(offerFrame, `{data.zoneName} · ~{data.cash} Cash · {data.rep} Rep`, 88, 20, 15, true)
	button(offerFrame, if data.isBig then "Join" else "Accept", function()
		OpsController.Accept(data.opId)
	end)
	offerFrame.Visible = true
end

local function showState(s: { [string]: any })
	if not OpsController.UseBuiltInUi then
		return
	end
	clear(stripFrame)
	local current = "Next step..."
	local takeKey: string? = nil
	for _, c in s.current do
		if c.trackId == s.myTrack then
			current = if c.npc then `{c.label} (NPC crew)` else `{c.label} · {c.assignee}`
			if c.npc then
				takeKey = c.key
			end
		end
	end
	local cas = s.casualties[1]
	local condText = if cas
		then `{cas.label} {cas.condition}%` .. (if s.total > 1
			then ` · {s.saved}/{s.total} safe`
			else "")
		else ""
	label(stripFrame, `{s.title} · {#s.results}/{#s.plan} steps`, 8, 22, 18)
	label(stripFrame, current, 32, 20, 16, true)
	label(stripFrame, condText, 54, 20, 16, true)
	if takeKey then
		local key = takeKey
		button(stripFrame, "Do it myself", function()
			OpsController.TakeStep(key)
		end)
	end
	stripFrame.Visible = true
end

local function showDebrief(d: { [string]: any })
	stripFrame.Visible = false
	if not OpsController.UseBuiltInUi then
		return
	end
	clear(debriefFrame)
	label(debriefFrame, `{d.title}: {d.grade}`, 10, 30, 26)
	local lines = {}
	for _, s in d.steps do
		table.insert(lines, `{s.grade} · {s.label} ({s.by})`)
	end
	label(debriefFrame, table.concat(lines, "\n"), 46, 220, 14, true)
	label(debriefFrame, `+{d.cash} Cash · +{d.rep} Rep`, 272, 22, 18)
	if d.tip then
		label(debriefFrame, `Chief Aggie: {d.tip}`, 298, 40, 15, true)
	end
	button(debriefFrame, "Close", function()
		debriefFrame.Visible = false
	end)
	debriefFrame.Visible = true
	task.delay(10, function()
		debriefFrame.Visible = false
	end)
end

local radioSerial = 0
local function showRadio(r: { [string]: any })
	if not OpsController.UseBuiltInUi then
		return
	end
	radioSerial += 1
	local mine = radioSerial
	radioLabel.Text = `{r.from}: {r.text}`
	radioLabel.Visible = true
	task.delay(6, function()
		if radioSerial == mine then
			radioLabel.Visible = false
		end
	end)
end

---------------------------------------------------------------- API

function OpsController.Accept(opId: string)
	offerFrame.Visible = false
	Remotes.event("Ops_Accept"):FireServer(opId)
end

function OpsController.TakeStep(stepKey: string)
	local s = state
	if s then
		Remotes.event("Ops_TakeStep"):FireServer(s.opId, stepKey)
	end
end

function OpsController.GetState(): { [string]: any }?
	return state
end

function OpsController.Init()
	mechanicsFolder = script.Parent.Parent:WaitForChild("Mechanics", 10)
	gui = Instance.new("ScreenGui")
	gui.Name = "OpsGreybox"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 15
	offerFrame =
		panel("Offer", UDim2.new(1, -16, 0, 120), UDim2.fromOffset(380, 170), Vector2.new(1, 0))
	stripFrame =
		panel("Strip", UDim2.new(0.5, 0, 0, 12), UDim2.fromOffset(460, 84), Vector2.new(0.5, 0))
	debriefFrame = panel(
		"Debrief",
		UDim2.fromScale(0.5, 0.5),
		UDim2.fromOffset(440, 400),
		Vector2.new(0.5, 0.5)
	)
	radioLabel = label(gui, "", 0, 24, 18)
	radioLabel.Position = UDim2.new(0, 16, 1, -260)
	radioLabel.Size = UDim2.fromOffset(520, 48)
	radioLabel.BackgroundTransparency = 0.3
	radioLabel.BackgroundColor3 = HudTheme.Colors.panel
	radioLabel.Visible = false
	gui.Parent = player:WaitForChild("PlayerGui")

	Remotes.event("Ops_Offered").OnClientEvent:Connect(function(data)
		OpsController.OnOffer:Fire(data)
		showOffer(data)
		if player:GetAttribute("OpsAutoStub") == true then
			task.delay(1, OpsController.Accept, data.opId)
		end
	end)
	Remotes.event("Ops_State").OnClientEvent:Connect(function(s)
		state = s
		if offerId == s.opId then
			offerFrame.Visible = false
		end
		-- the server moved on (takeover, NPC took it, another unit): drop the running mechanic
		local r = running
		if r and r.opId == s.opId then
			local still = false
			for _, c in s.current do
				still = still or (c.key == r.key and not c.npc)
			end
			if not still then
				cancelRunning()
			end
		end
		OpsController.OnState:Fire(s)
		showState(s)
	end)
	Remotes.event("Ops_StepStart").OnClientEvent:Connect(onStepStart)
	Remotes.event("Ops_StepAck").OnClientEvent:Connect(function(ack)
		if not ack.accepted then
			warn(`[OpsController] step {ack.stepKey} not accepted: {ack.reason}`)
		end
	end)
	Remotes.event("Ops_Radio").OnClientEvent:Connect(function(r)
		OpsController.OnRadio:Fire(r)
		showRadio(r)
	end)
	Remotes.event("Ops_Debrief").OnClientEvent:Connect(function(d)
		cancelRunning()
		state = nil
		OpsController.OnDebrief:Fire(d)
		showDebrief(d)
	end)
	Remotes.event("Ops_Closed").OnClientEvent:Connect(function(c)
		if offerId == c.opId then
			offerFrame.Visible = false
			offerId = nil
		end
		OpsController.OnClosed:Fire(c)
	end)
end

return OpsController
