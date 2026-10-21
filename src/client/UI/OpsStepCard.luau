--!strict
-- OpsStepCard: the running operation as a slim objective strip (Layout "objective" region, top
-- left): a step icon, the current step in at most three words, the plan as grade-coloured pips and
-- "Take it" while the NPC crew holds your step. A takeover shows as a banner. The real term and
-- who has it are left to the radio and the world (docs/14 section 2: show, don't tell).
local ContextActionService = game:GetService("ContextActionService")

local A11yPalette =
	require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("A11yPalette"))
local HudTheme = require(script.Parent.HudTheme)
local InputGlyph = require(script.Parent.InputGlyph)

export type StepCard = {
	update: (s: { [string]: any }, onTake: (key: string) -> ()) -> (),
	hide: () -> (),
	setCompact: (on: boolean) -> (),
	setLabel: (text: string?) -> (),
}

local ICON: { [string]: string } = {
	tasking = "📻",
	relay = "📻",
	kit_launch = "🧰",
	launch = "🚤",
	passage = "🧭",
	search = "🔍",
	approach = "↘",
	calm = "✋",
	recovery = "🙋", -- not the ring buoy emoji: too new for Roblox, it drew a missing-glyph box
	survey = "🩺",
	treatment = "🩹",
	transport = "🏠",
	handover = "🚑",
	assess = "👀",
	heaving_line = "🪢",
	rig = "🔗",
	take_strain = "⚓",
	tow = "⛓",
	alongside = "⛵",
	alongside_vessel = "⛵",
	find_vessel = "🔭",
	berth = "⚓",
	scene_command = "📣",
	hull_knock = "✊",
	air_pocket = "🫧",
	pickup = "🙋",
	triage = "🏷",
	movement = "➡",
	account = "✅",
	access = "🧗",
	free = "✂",
	carry = "🤲",
	mark = "🚩",
	beach = "🏖",
	save = "🚰",
	crew_off = "🚶",
	fire_fight = "💦",
	standby = "👀",
	closeout = "🏁",
	mob_spot = "👀",
	mob_approach = "↩",
	mob_recovery = "🙋",
}

-- step id -> <= 3 words
local SHORT: { [string]: string } = {
	tasking = "Answer the call",
	relay = "Answer relay",
	kit_launch = "Kit and launch",
	launch = "Get aboard",
	passage = "Get there",
	search = "Find them",
	approach = "Come in slow",
	calm = "Calm them",
	recovery = "Pick them up",
	survey = "Check them",
	treatment = "Treat them",
	transport = "Bring them home",
	handover = "Hand over",
	assess = "Look and ask",
	heaving_line = "Throw the line",
	rig = "Rig the tow",
	take_strain = "Take the strain",
	tow = "Tow her home",
	alongside = "Alongside",
	berth = "Berth her",
	scene_command = "Take command",
	hull_knock = "Knock the hull",
	air_pocket = "Air pocket",
	pickup = "Pick up",
	triage = "Tag them",
	movement = "Move them",
	account = "Count everyone",
	access = "Get down",
	beach = "Reach the sand",
	save = "Keep her up",
	crew_off = "Crew off",
	fire_fight = "Knock the fire",
	standby = "Watch hotspots",
	closeout = "Stand down",
	mob_spot = "Spot them",
	mob_approach = "Come about",
	mob_recovery = "Get them aboard",
}

local function short(text: string): string
	local words = {}
	for w in string.gmatch(text, "%S+") do
		table.insert(words, w)
		if #words == 3 then
			break
		end
	end
	return table.concat(words, " ")
end

local OpsStepCard = {}

-- Shared with the debrief: a step's icon and its 1-3 word label.
function OpsStepCard.iconFor(id: string?): string
	return ICON[id or ""] or "•"
end

function OpsStepCard.shortFor(id: string?, label: string?): string
	local known = SHORT[id or ""]
	return if known then known else short(label or id or "")
end

function OpsStepCard.new(gui: GuiBase2d): StepCard
	local body = Instance.new("Frame")
	body.Name = "StepCard"
	body.Size = UDim2.new(1, 0, 0, 76)
	body.BackgroundColor3 = HudTheme.Colors.panel
	body.BackgroundTransparency = HudTheme.PanelTransparency
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = gui
	HudTheme.corner(body)
	HudTheme.stroke(body)

	local icon =
		HudTheme.label("Icon", "•", UDim2.fromOffset(32, 32), HudTheme.BoldFont, 24, body)
	icon.Position = UDim2.fromOffset(12, 22)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local step = HudTheme.label("Step", "", UDim2.new(1, -170, 0, 32), HudTheme.BoldFont, 21, body)
	step.Position = UDim2.fromOffset(52, 22)
	-- push-to-talk steps show their key (R / DPadUp); touch has the Radio button instead
	local ptt = Instance.new("Frame")
	ptt.Name = "PttKey"
	ptt.BackgroundTransparency = 1
	ptt.Size = UDim2.fromOffset(40, 36)
	ptt.AnchorPoint = Vector2.new(1, 0.5)
	ptt.Position = UDim2.new(1, -6, 0.5, -4)
	ptt.Visible = false
	ptt.Parent = body
	InputGlyph.chip(ptt, Enum.KeyCode.R, Enum.KeyCode.DPadUp)

	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.new(0, 12, 1, -14)
	pips.Size = UDim2.new(1, -24, 0, 10)
	pips.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = pips

	local take =
		HudTheme.button("Take", "Take it", UDim2.fromOffset(150, HudTheme.MinButtonHeight), body)
	take.AnchorPoint = Vector2.new(1, 0.5)
	take.Position = UDim2.new(1, -10, 0.5, -4)
	take.TextSize = 18
	take.Visible = false
	HudTheme.corner(take, 10)
	local takeKey: string? = nil
	local takeFn: ((string) -> ())? = nil
	local function doTake()
		if takeKey and takeFn then
			takeFn(takeKey)
		end
	end
	take.Activated:Connect(doTake)
	-- T / DPadLeft only while the NPC crew holds your step (no mechanic binds then)
	InputGlyph.chip(take, Enum.KeyCode.T, Enum.KeyCode.DPadLeft)
	take:GetPropertyChangedSignal("Visible"):Connect(function()
		if take.Visible then
			ContextActionService:BindAction("OpsTakeStep", function(_, state)
				if state == Enum.UserInputState.Begin then
					doTake()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.KeyCode.T, Enum.KeyCode.DPadLeft)
		else
			ContextActionService:UnbindAction("OpsTakeStep")
		end
	end)

	local banner =
		HudTheme.label("Takeover", "", UDim2.new(1, 0, 0, 26), HudTheme.BoldFont, 16, body)
	banner.AnchorPoint = Vector2.new(0, 0)
	banner.Position = UDim2.new(0, 0, 1, 6)
	banner.BackgroundColor3 = Color3.fromHex("8C2A24")
	banner.BackgroundTransparency = 0.25
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.Visible = false
	HudTheme.corner(banner, 8)

	local compact = false
	local function applyCompact()
		icon.Position = UDim2.fromOffset(12, if compact then 8 else 22)
		icon.Size = UDim2.fromOffset(if compact then 24 else 32, if compact then 24 else 32)
		icon.TextSize = if compact then 18 else 24
		step.Position = UDim2.fromOffset(if compact then 44 else 52, if compact then 9 else 22)
		step.Size = UDim2.new(1, if compact then -56 else -170, 0, if compact then 26 else 32)
		pips.Visible = not compact
		body.Size = UDim2.new(1, 0, 0, if compact then 46 else 76)
	end

	local label: string? = nil -- the cold open's step line follows the world (setLabel)

	local card: StepCard
	card = {
		setLabel = function(text: string?)
			label = text
			if text then
				step.Text = text
			end
		end,
		setCompact = function(on: boolean)
			compact = on
			applyCompact()
		end,
		update = function(s: { [string]: any }, onTake: (string) -> ())
			takeFn = onTake
			local mine: { [string]: any }? = nil
			for _, c in s.current or {} do
				if c.trackId == s.myTrack then
					mine = c
				end
			end
			if mine then
				icon.Text = ICON[mine.id] or "•"
				step.Text = label or SHORT[mine.id] or short(tostring(mine.label or ""))
				takeKey = if mine.npc then mine.key else nil
			else
				icon.Text = "•"
				step.Text = "Stand by"
				takeKey = nil
			end
			take.Visible = takeKey ~= nil and not compact
			ptt.Visible = mine ~= nil
				and not mine.npc
				and (mine.mechanicId == "radio_ack" or mine.mechanicId == "radio_closeout")
			-- pips: one per plan step, coloured by its grade once done. They are TextLabels, so clear
			-- every GuiObject (clearing only Frames stacked a new set each update: the endless strip)
			for _, ch in pips:GetChildren() do
				if ch:IsA("GuiObject") then
					ch:Destroy()
				end
			end
			local grades: { [string]: string } = {}
			for _, r in s.results or {} do
				if r.trackId == nil or r.trackId == s.myTrack then
					grades[r.stepId] = r.grade
				end
			end
			local n = math.max(#(s.plan or {}), 1)
			for i, p in s.plan or {} do
				local pip = Instance.new("TextLabel")
				pip.Name = "Pip" .. i
				pip.BorderSizePixel = 0
				pip.Size = UDim2.new(1 / n, -4, 1, 0)
				local g = grades[p.id]
				local isCur = mine ~= nil and mine.id == p.id
				pip.BackgroundColor3 = if g
					then A11yPalette.colour("Grade", g)
					elseif isCur then HudTheme.Colors.accent
					else HudTheme.Colors.locked
				pip.Text = if g then A11yPalette.symbol("Grade", g) elseif isCur then "▶" else "·"
				pip.TextColor3 = if g then Color3.fromRGB(12, 18, 24) else HudTheme.Colors.text
				pip.TextSize = 9
				pip.Font = HudTheme.BoldFont
				pip.Parent = pips
				HudTheme.corner(pip, 3)
			end
			if s.takeover then
				banner.Text = "Coastguard taking over"
				banner.Visible = true
			else
				banner.Visible = false
			end
			body.Visible = true
		end,
		hide = function()
			body.Visible = false
			take.Visible = false
			ptt.Visible = false
		end,
	}
	return card
end

return OpsStepCard
