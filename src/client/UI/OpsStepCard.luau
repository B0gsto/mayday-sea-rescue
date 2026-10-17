--!strict
-- OpsStepCard: the running operation as a slim strip (top centre): priority and title, the step
-- you are on (plain label, the real term and the role), who has it (you, a crewmate or the NPC
-- crew, with "Do it myself" to swap in), the plan as grade-coloured pips, and saved/total on big
-- calls. A takeover shows as a banner ("Rescue Gale One is taking the casualty").
local HudTheme = require(script.Parent.HudTheme)

export type StepCard = {
	update: (s: { [string]: any }, onTake: (key: string) -> ()) -> (),
	hide: () -> (),
}

local GRADE_COLORS: { [string]: Color3 } = {
	Gold = Color3.fromHex("FFC872"),
	Silver = Color3.fromHex("C9D2D9"),
	Bronze = Color3.fromHex("C7834A"),
	Fail = Color3.fromHex("5A2F2F"),
}

local OpsStepCard = {}

function OpsStepCard.new(gui: ScreenGui): StepCard
	local body = Instance.new("Frame")
	body.Name = "StepCard"
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.Position = UDim2.new(0.5, 0, 0, 10)
	body.Size = UDim2.new(0.5, 0, 0, 92)
	body.BackgroundColor3 = HudTheme.Colors.panel
	body.BackgroundTransparency = 0.12
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = gui
	HudTheme.corner(body, 12)
	local lim = Instance.new("UISizeConstraint")
	lim.MinSize = Vector2.new(320, 0)
	lim.MaxSize = Vector2.new(620, 200)
	lim.Parent = body

	local head = HudTheme.label("Head", "", UDim2.new(1, -24, 0, 20), HudTheme.BoldFont, 15, body)
	head.Position = UDim2.fromOffset(12, 6)
	head.TextColor3 = HudTheme.Colors.textDim
	local step = HudTheme.label("Step", "", UDim2.new(1, -170, 0, 26), HudTheme.BoldFont, 22, body)
	step.Position = UDim2.fromOffset(12, 26)
	local who = HudTheme.label("Who", "", UDim2.new(1, -170, 0, 18), HudTheme.BodyFont, 15, body)
	who.Position = UDim2.fromOffset(12, 52)
	who.TextColor3 = HudTheme.Colors.textDim

	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.Position = UDim2.new(0, 12, 1, -14)
	pips.Size = UDim2.new(1, -24, 0, 6)
	pips.Parent = body
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 4)
	layout.Parent = pips

	local take = HudTheme.button(
		"Take",
		"Do it myself",
		UDim2.fromOffset(150, HudTheme.MinButtonHeight),
		body
	)
	take.AnchorPoint = Vector2.new(1, 0.5)
	take.Position = UDim2.new(1, -10, 0.5, -4)
	take.TextSize = 18
	take.Visible = false
	HudTheme.corner(take, 10)
	local takeKey: string? = nil
	local takeFn: ((string) -> ())? = nil
	take.Activated:Connect(function()
		if takeKey and takeFn then
			takeFn(takeKey)
		end
	end)

	local banner =
		HudTheme.label("Takeover", "", UDim2.new(1, 0, 0, 26), HudTheme.BoldFont, 16, body)
	banner.AnchorPoint = Vector2.new(0, 0)
	banner.Position = UDim2.new(0, 0, 1, 6)
	banner.BackgroundColor3 = Color3.fromHex("E8332A")
	banner.BackgroundTransparency = 0.1
	banner.TextXAlignment = Enum.TextXAlignment.Center
	banner.Visible = false
	HudTheme.corner(banner, 8)

	local card: StepCard
	card = {
		update = function(s: { [string]: any }, onTake: (string) -> ())
			takeFn = onTake
			local word = if s.kind == "DisabledVessel" then "PAN-PAN" else "MAYDAY"
			local count = if (s.total or 0) > 1 then ` · {s.saved or 0}/{s.total} safe` else ""
			head.Text = `{word} · {string.upper(tostring(s.title or ""))}{count}`
			local mine: { [string]: any }? = nil
			for _, c in s.current or {} do
				if c.trackId == s.myTrack then
					mine = c
				end
			end
			if mine then
				step.Text = `{mine.label}`
				local by = if mine.npc then "NPC crew has it" else `{mine.assignee or "You"}`
				who.Text = `{mine.realTerm or ""} · {mine.role or ""} · {by}`
				takeKey = if mine.npc then mine.key else nil
			else
				step.Text = "Stand by"
				who.Text = "Waiting for the next step"
				takeKey = nil
			end
			take.Visible = takeKey ~= nil
			-- pips: one per plan step, coloured by its grade once done
			for _, ch in pips:GetChildren() do
				if ch:IsA("Frame") then
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
				local pip = Instance.new("Frame")
				pip.Name = "Pip" .. i
				pip.BorderSizePixel = 0
				pip.Size = UDim2.new(1 / n, -4, 1, 0)
				local g = grades[p.id]
				local isCur = mine ~= nil and mine.id == p.id
				pip.BackgroundColor3 = if g
					then GRADE_COLORS[g] or HudTheme.Colors.textDim
					elseif isCur then HudTheme.Colors.accent
					else HudTheme.Colors.locked
				pip.Parent = pips
				HudTheme.corner(pip, 3)
			end
			if s.takeover then
				banner.Text = "Coastguard asset taking over · stand by to assist"
				banner.Visible = true
			else
				banner.Visible = false
			end
			body.Visible = true
		end,
		hide = function()
			body.Visible = false
		end,
	}
	return card
end

return OpsStepCard
