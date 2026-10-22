--!strict
-- OpsDebrief: the end-of-call result as a notification (docs 09 section 2.4). Show, don't tell
-- (docs/14 section 2): a toast slides down at the top centre with the grade medal stamping in and
-- Cash and Rep rolling up (the coins fly to the HUD's Cash counter), then slides away on its own.
-- It never takes input or covers the play area (playtest 2026-10-21: the full-screen tablet felt
-- like a menu).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local A11yPalette = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("A11yPalette"))
local CashBurst = require(script.Parent.CashBurst)
local HudTheme = require(script.Parent.HudTheme)
local OpsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops")
local Exercises = require(OpsFolder:WaitForChild("Definitions"):WaitForChild("Exercises"))
local Operations = require(OpsFolder:WaitForChild("Operations"))

export type Debrief = {
	show: (d: { [string]: any }, auto: number?) -> (),
	hide: () -> (),
	shownFor: () -> number,
}

local GRADE_LABEL: { [string]: string } = {
	Gold = "Gold",
	Silver = "Silver",
	Bronze = "Bronze",
	Fail = "Fail",
	Takeover = "", -- wordless (2026-10-21): the icon and +0 say it
}
local SHOW_FOR = 5 -- s on screen

-- Certifications earned on live operations (docs 09 section 11): step ids that count, at Silver+.
local CERTS = {
	{ name = "Helm", steps = { "approach", "alongside" }, need = 2, all = false },
	{ name = "Casualty Care", steps = { "primary_survey", "treat" }, need = 2, all = true },
	{ name = "Rescue Swimmer", steps = { "recover_swimmer" }, need = 1, all = false },
}

local OpsDebrief = {}

local function silverPlus(g: string?): boolean
	return g == "Gold" or g == "Silver"
end

-- Why a step got its grade, in Chief Aggie's plain words (kept for callers and tests).
function OpsDebrief.reasonFor(kind: string, s: { [string]: any }): string
	if s.grade == "Fail" then
		return "Missed"
	end
	if s.by == "NPC" then
		return "NPC crew · max Silver"
	end
	if s.grade == "Gold" then
		return "Textbook."
	end
	local ex = Exercises.get(kind)
	local def = if ex then ex.def else Operations.get(kind)
	for _, st in (def and def.steps or {}) :: { any } do
		if st.id == s.id and st.tip then
			return st.tip
		end
	end
	return if s.grade == "Silver" then "Nearly Gold" else "Slow down"
end

local function escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- The debrief payload's badges as RichText lines (kept for callers; the tablet shows icons only).
function OpsDebrief.badgeLines(badges: { any }): { string }
	local out = {}
	for _, b in badges do
		if type(b) == "table" and type(b.title) == "string" then
			local strong = b.kind == "cert" or b.kind == "rank"
			local colour = if strong then "#E3C88F" else "#8FB7BC"
			local text = if type(b.text) == "string" and b.text ~= ""
				then `  {escape(b.text)}`
				else ""
			table.insert(out, `<font color="{colour}"><b>{escape(b.title)}</b></font>{text}`)
		end
	end
	return out
end

-- Certification credit from this debrief for the player (userId).
function OpsDebrief.certCredits(steps: { any }, userId: number): { { name: string, need: number } }
	local out = {}
	for _, c in CERTS do
		local hits = 0
		for _, id in c.steps do
			for _, s in steps do
				if s.id == id and s.userId == userId and silverPlus(s.grade) then
					hits += 1
					break
				end
			end
		end
		if (c.all and hits == #c.steps) or (not c.all and hits > 0) then
			table.insert(out, { name = c.name, need = c.need })
		end
	end
	return out
end

local function gradeRank(g: string?): number
	if g == "Gold" then
		return 4
	elseif g == "Silver" then
		return 3
	elseif g == "Bronze" then
		return 2
	end
	return 1
end

-- At most `max` icons, in order: each slot keeps the worst grade of its slice, so a failed step
-- is never hidden by the cut.
function OpsDebrief.iconSteps(steps: { any }, max: number): { any }
	local n = #steps
	if n <= max then
		return steps
	end
	local out = {}
	for i = 1, max do
		local a = math.floor((i - 1) * n / max) + 1
		local b = math.max(a, math.floor(i * n / max))
		local pick = steps[a]
		for j = a + 1, b do
			if gradeRank(steps[j].grade) < gradeRank(pick.grade) then
				pick = steps[j]
			end
		end
		table.insert(out, pick)
	end
	return out
end

local function medal(parent: Instance, grade: string, size: number): Frame
	local m = Instance.new("Frame")
	m.Size = UDim2.fromOffset(size, size)
	m.BackgroundColor3 = A11yPalette.colour("Grade", grade)
	m.BorderSizePixel = 0
	m.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = m
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromHex("FFFFFF")
	s.Transparency = 0.6
	s.Thickness = 2
	s.Parent = m
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = HudTheme.BoldFont
	l.TextScaled = true
	l.TextColor3 = if grade == "Fail" then Color3.fromHex("FFC1B8") else Color3.fromHex("1B1F22")
	l.Text = A11yPalette.symbol("Grade", grade)
	l.Parent = m
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = l
	return m
end

-- A coin icon (same look as CashBurst) or a Rep chevron, then a number that rolls up from 0.
local function counter(
	parent: Frame,
	order: number,
	glyph: string,
	color: Color3,
	value: number,
	coin: boolean
): TextLabel
	local group = Instance.new("Frame")
	group.Name = if coin then "Cash" else "Rep"
	group.LayoutOrder = order
	group.Size = UDim2.fromOffset(150, 40)
	group.BackgroundTransparency = 1
	group.Parent = parent
	if coin then
		local c = Instance.new("Frame")
		c.Name = "Coin"
		c.Position = UDim2.fromOffset(2, 9)
		c.Size = UDim2.fromOffset(22, 22)
		c.BackgroundColor3 = Color3.fromRGB(255, 208, 106)
		c.BorderSizePixel = 0
		c.Parent = group
		HudTheme.corner(c, 11)
		local inner = Instance.new("Frame")
		inner.Position = UDim2.fromOffset(4, 4)
		inner.Size = UDim2.fromOffset(14, 14)
		inner.BackgroundColor3 = Color3.fromRGB(214, 164, 62)
		inner.BorderSizePixel = 0
		inner.Parent = c
		HudTheme.corner(inner, 7)
	else
		local icon =
			HudTheme.label("Icon", glyph, UDim2.fromOffset(28, 32), HudTheme.BoldFont, 24, group)
		icon.Position = UDim2.fromOffset(0, 4)
		icon.TextXAlignment = Enum.TextXAlignment.Center
		icon.TextColor3 = color
	end
	local label =
		HudTheme.label("Value", "+0", UDim2.fromOffset(116, 40), HudTheme.BoldFont, 26, group)
	label.Position = UDim2.fromOffset(32, 0)
	label.TextColor3 = color
	local n = Instance.new("NumberValue")
	n.Value = 0
	n.Parent = label
	n.Changed:Connect(function(v: number)
		label.Text = `+{HudTheme.formatNumber(v)}`
	end)
	task.delay(0.3 + order * 0.08, function()
		TweenService:Create(
			n,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Value = value }
		):Play()
	end)
	return label
end

function OpsDebrief.new(parent: GuiObject): Debrief
	local player = Players.LocalPlayer
	local toast = HudTheme.panel("DebriefTablet", UDim2.fromOffset(380, 84), parent)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	HudTheme.skin(toast)
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = toast
	local OPEN = UDim2.new(0.5, 0, 0, 8)
	local CLOSED = UDim2.new(0.5, 0, 0, -100)

	local shownAt = 0
	local closeThread: thread? = nil
	local debrief: Debrief
	debrief = {
		shownFor = function()
			return if toast.Visible then os.clock() - shownAt else math.huge
		end,
		hide = function()
			if not toast.Visible then
				return
			end
			shownAt = -math.huge
			local t = TweenService:Create(
				toast,
				TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = CLOSED }
			)
			t.Completed:Connect(function(state)
				if state == Enum.PlaybackState.Completed then
					toast.Visible = false
				end
			end)
			t:Play()
		end,
		-- `auto`: seconds on screen (default SHOW_FOR)
		show = function(d: { [string]: any }, auto: number?)
			content:ClearAllChildren()
			local grade = d.grade or "Bronze"

			-- the grade medal stamps in from large to its resting size
			local m = medal(content, grade, 110)
			m.AnchorPoint = Vector2.new(0.5, 0.5)
			m.Position = UDim2.fromOffset(42, 42)
			m.Rotation = -12
			m.ZIndex = 2
			TweenService
				:Create(m, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.fromOffset(60, 60),
					Rotation = 0,
				})
				:Play()
			local gradeLabel = HudTheme.label(
				"Grade",
				GRADE_LABEL[grade] or grade,
				UDim2.fromOffset(100, 30),
				HudTheme.BoldFont,
				24,
				content
			)
			gradeLabel.AnchorPoint = Vector2.new(0, 0.5)
			gradeLabel.Position = UDim2.new(0, 84, 0.5, 0)
			gradeLabel.TextColor3 = A11yPalette.colour("Grade", grade)

			-- Cash and Rep roll up
			local pay = Instance.new("Frame")
			pay.Name = "Pay"
			pay.AnchorPoint = Vector2.new(1, 0.5)
			pay.Position = UDim2.new(1, -16, 0.5, 0)
			pay.Size = UDim2.fromOffset(150, 76)
			pay.BackgroundTransparency = 1
			pay.Parent = content
			local payLayout = Instance.new("UIListLayout")
			payLayout.FillDirection = Enum.FillDirection.Vertical
			payLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
			payLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			payLayout.Padding = UDim.new(0, -4)
			payLayout.Parent = pay
			local cashLabel =
				counter(pay, 1, "", HudTheme.Colors.gold, math.max(d.cash or 0, 0), true)
			counter(pay, 2, "★", HudTheme.Colors.bar, math.max(d.rep or 0, 0), false)

			toast.Position = CLOSED
			toast.Visible = true
			TweenService
				:Create(
					toast,
					TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{
						Position = OPEN,
					}
				)
				:Play()
			shownAt = os.clock()
			-- the payout flies from the Cash counter into the HUD's Cash counter
			if (d.cash or 0) > 0 then
				task.delay(0.9, function()
					local playerGui = player.PlayerGui
					if toast.Visible and playerGui then
						local at = cashLabel.AbsolutePosition + cashLabel.AbsoluteSize * 0.5
						CashBurst.playAt(playerGui, at, d.cash, false)
					end
				end)
			end
			if closeThread then
				task.cancel(closeThread)
			end
			closeThread = task.delay(auto or SHOW_FOR, debrief.hide)
		end,
	}
	return debrief
end

return OpsDebrief
