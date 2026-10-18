--!strict
-- OpsDebrief: the debrief on the station's waterproof tablet (docs 09 section 2.4). Overall medal,
-- the step timeline (Gold/Silver/Bronze with the reason, your own steps highlighted), the
-- condition graph, Cash and Rep, Chief Aggie's tip for the weakest step and certification
-- progress (docs 09 section 11). One tap closes it; it never holds up the next tasking > 10 s.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HudTheme = require(script.Parent.HudTheme)
local OpsFolder = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops")
local Exercises = require(OpsFolder:WaitForChild("Definitions"):WaitForChild("Exercises"))
local Operations = require(OpsFolder:WaitForChild("Operations"))

export type Debrief = { show: (d: { [string]: any }) -> (), hide: () -> (), shownFor: () -> number }

local MEDAL: { [string]: Color3 } = {
	Gold = Color3.fromHex("FFC872"),
	Silver = Color3.fromHex("C9D2D9"),
	Bronze = Color3.fromHex("C7834A"),
	Fail = Color3.fromHex("6B3A3A"),
}
local SCREEN = Color3.fromHex("0F1418")

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

-- Why a step got its grade, in Chief Aggie's plain words.
function OpsDebrief.reasonFor(kind: string, s: { [string]: any }): string
	if s.grade == "Fail" then
		return "Skipped or timed out: no points for this one."
	end
	if s.by == "NPC" then
		return "Done by the NPC crew: Silver at most. Take the seat to earn Gold."
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
	return if s.grade == "Silver"
		then "Good. One detail off Gold."
		else "Safe, but rough. Slow it down."
end

local function escape(s: string): string
	return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
end

-- The debrief payload's badges (ProgressionRules.DebriefBadge: certifications earned, live
-- operations counted, an exercise passed, a promotion) as the tablet's certification lines, in
-- RichText: earned certifications and promotions in brass, progress in the Rep teal. Pure.
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

local function medal(parent: Instance, grade: string, size: number): Frame
	local m = Instance.new("Frame")
	m.Size = UDim2.fromOffset(size, size)
	m.BackgroundColor3 = MEDAL[grade] or MEDAL.Fail
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
	l.TextColor3 = Color3.fromHex("1B1F22")
	l.Text = if grade == "Fail" then "-" else string.sub(grade, 1, 1)
	l.Parent = m
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0.18, 0)
	pad.PaddingBottom = UDim.new(0.18, 0)
	pad.Parent = l
	return m
end

local function lineSeg(parent: Instance, a: Vector2, b: Vector2, color: Color3)
	local d = b - a
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundColor3 = color
	f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	f.Size = UDim2.fromOffset(d.Magnitude + 1, 2)
	f.Rotation = math.deg(math.atan2(d.Y, d.X))
	f.Parent = parent
end

function OpsDebrief.new(gui: ScreenGui): Debrief
	local player = Players.LocalPlayer
	-- the tablet: an orange rubber bumper around a dark screen
	local tablet = Instance.new("Frame")
	tablet.Name = "DebriefTablet"
	tablet.AnchorPoint = Vector2.new(0.5, 0.5)
	tablet.Position = UDim2.fromScale(0.5, 0.5)
	tablet.Size = UDim2.fromScale(0.9, 0.86)
	tablet.BackgroundColor3 = HudTheme.Colors.accent
	tablet.BorderSizePixel = 0
	tablet.Visible = false
	tablet.Parent = gui
	HudTheme.corner(tablet, 26)
	local lim = Instance.new("UISizeConstraint")
	lim.MaxSize = Vector2.new(780, 560)
	lim.Parent = tablet
	local screen = Instance.new("Frame")
	screen.Position = UDim2.fromOffset(14, 14)
	screen.Size = UDim2.new(1, -28, 1, -28)
	screen.BackgroundColor3 = SCREEN
	screen.BorderSizePixel = 0
	screen.Parent = tablet
	HudTheme.corner(screen, 14)

	local shownAt = 0
	local closeThread: thread? = nil

	local debrief: Debrief
	debrief = {
		shownFor = function()
			return if tablet.Visible then os.clock() - shownAt else math.huge
		end,
		hide = function()
			tablet.Visible = false
		end,
		show = function(d: { [string]: any })
			for _, ch in screen:GetChildren() do
				if not ch:IsA("UICorner") then
					ch:Destroy()
				end
			end
			-- header
			local m = medal(screen, d.grade or "Bronze", 56)
			m.Position = UDim2.fromOffset(16, 12)
			local title = HudTheme.label(
				"Title",
				`DEBRIEF · {d.title or ""}`,
				UDim2.new(1, -230, 0, 28),
				HudTheme.BoldFont,
				24,
				screen
			)
			title.Position = UDim2.fromOffset(84, 12)
			local pro = player:GetAttribute("OpsPro") == true
			local sub = `{d.grade or ""} overall`
				.. (if d.takeover then " · Coastguard asset took over" else "")
				.. (if (d.total or 0) > 1 then ` · {d.saved}/{d.total} safe` else "")
				.. (if pro then " · PRO" else " · Assist")
			local subL =
				HudTheme.label("Sub", sub, UDim2.new(1, -230, 0, 20), HudTheme.BodyFont, 16, screen)
			subL.Position = UDim2.fromOffset(84, 42)
			subL.TextColor3 = HudTheme.Colors.textDim
			local pay = HudTheme.label(
				"Pay",
				`+{d.cash or 0} Cash   +{d.rep or 0} Rep`,
				UDim2.fromOffset(200, 26),
				HudTheme.BoldFont,
				20,
				screen
			)
			pay.AnchorPoint = Vector2.new(1, 0)
			pay.Position = UDim2.new(1, -16, 0, 16)
			pay.TextXAlignment = Enum.TextXAlignment.Right
			pay.TextColor3 = HudTheme.Colors.gold

			-- step timeline (left, scrolls)
			local list = Instance.new("ScrollingFrame")
			list.Name = "Steps"
			list.Position = UDim2.fromOffset(12, 80)
			list.Size = UDim2.new(0.58, -12, 1, -150)
			list.BackgroundTransparency = 1
			list.BorderSizePixel = 0
			list.ScrollBarThickness = 6
			list.AutomaticCanvasSize = Enum.AutomaticSize.Y
			list.CanvasSize = UDim2.new()
			list.Parent = screen
			local layout = Instance.new("UIListLayout")
			layout.Padding = UDim.new(0, 6)
			layout.Parent = list
			for i, s in d.steps or {} do
				local mine = s.userId == player.UserId
				local row = Instance.new("Frame")
				row.Name = "Step" .. i
				row.LayoutOrder = i
				row.Size = UDim2.new(1, -10, 0, 58)
				row.BackgroundColor3 = if mine
					then Color3.fromHex("1E3440")
					else Color3.fromHex("171D22")
				row.BorderSizePixel = 0
				row.Parent = list
				HudTheme.corner(row, 8)
				if mine then
					local bar = Instance.new("Frame")
					bar.Size = UDim2.new(0, 4, 1, -12)
					bar.Position = UDim2.fromOffset(2, 6)
					bar.BackgroundColor3 = HudTheme.Colors.accent
					bar.BorderSizePixel = 0
					bar.Parent = row
				end
				local md = medal(row, s.grade or "Fail", 34)
				md.Position = UDim2.fromOffset(12, 12)
				local by = if mine then "You" else tostring(s.by or "")
				local name = HudTheme.label(
					"Label",
					`{s.label}  ·  {s.realTerm or ""}  ·  {by}`,
					UDim2.new(1, -60, 0, 20),
					HudTheme.BoldFont,
					16,
					row
				)
				name.Position = UDim2.fromOffset(54, 6)
				local why = HudTheme.label(
					"Reason",
					OpsDebrief.reasonFor(d.kind, s),
					UDim2.new(1, -60, 0, 28),
					HudTheme.BodyFont,
					14,
					row
				)
				why.Position = UDim2.fromOffset(54, 26)
				why.TextWrapped = true
				why.TextYAlignment = Enum.TextYAlignment.Top
				why.TextColor3 = HudTheme.Colors.textDim
			end

			-- right column: condition graph, tip, certifications
			local right = Instance.new("Frame")
			right.BackgroundTransparency = 1
			right.Position = UDim2.new(0.58, 6, 0, 80)
			right.Size = UDim2.new(0.42, -18, 1, -150)
			right.Parent = screen
			local graph = Instance.new("Frame")
			graph.Name = "Condition"
			graph.Size = UDim2.new(1, 0, 0, 120)
			graph.BackgroundColor3 = Color3.fromHex("060B0A")
			graph.BorderSizePixel = 0
			graph.ClipsDescendants = true
			graph.Parent = right
			HudTheme.corner(graph, 8)
			local gl = HudTheme.label(
				"GraphTitle",
				"CONDITION",
				UDim2.new(1, -12, 0, 14),
				Enum.Font.Code,
				12,
				graph
			)
			gl.Position = UDim2.fromOffset(8, 4)
			gl.TextColor3 = HudTheme.Colors.textDim
			task.defer(function()
				local w, h = graph.AbsoluteSize.X, graph.AbsoluteSize.Y
				local hist = d.condition or {}
				local n = #hist
				if n >= 2 and w > 0 then
					local t0, t1 = hist[1].t, hist[n].t
					local span = math.max(t1 - t0, 1)
					local series = #(hist[1].c or {})
					for k = 1, math.min(series, 4) do
						local prev: Vector2? = nil
						for _, sample in hist do
							local v = (sample.c or {})[k]
							if type(v) == "number" then
								local pt = Vector2.new(
									6 + (sample.t - t0) / span * (w - 12),
									20 + (1 - v / 100) * (h - 26)
								)
								if prev then
									local col = if v >= 70
										then Color3.fromHex("3EE07A")
										elseif v >= 40 then Color3.fromHex("FFB020")
										else Color3.fromHex("FF4D3A")
									lineSeg(graph, prev, pt, col)
								end
								prev = pt
							end
						end
					end
				end
			end)
			local y = 128
			if d.tip then
				local tip = HudTheme.label(
					"Tip",
					`Chief Aggie: "{d.tip}"`,
					UDim2.new(1, 0, 0, 64),
					HudTheme.BodyFont,
					15,
					right
				)
				tip.Position = UDim2.fromOffset(0, y)
				tip.TextWrapped = true
				tip.TextYAlignment = Enum.TextYAlignment.Top
				y += 68
			end
			-- the server's own result (RP-C1b): what this debrief earned, counted or passed
			local badges = if type(d.badges) == "table"
				then OpsDebrief.badgeLines(d.badges)
				else nil
			local credits: { { name: string, need: number } } = if badges
				then {}
				else OpsDebrief.certCredits(d.steps or {}, player.UserId)
			local certLines = {}
			for _, c in credits do
				local have = player:GetAttribute("Cert_" .. string.gsub(c.name, " ", ""))
				local n = if type(have) == "number" then math.min(have, c.need) else nil
				table.insert(
					certLines,
					if n
						then `{c.name}: {n}/{c.need} operations`
						else `{c.name}: +1 operation toward sign-off ({c.need} needed)`
				)
			end
			if badges then
				certLines = badges
			end
			local cert = HudTheme.label(
				"Certs",
				if #certLines > 0
					then "CERTIFICATION\n" .. table.concat(certLines, "\n")
					else "CERTIFICATION\nNo sign-off credit this time.",
				UDim2.new(1, 0, 0, 80),
				HudTheme.BodyFont,
				15,
				right
			)
			cert.Position = UDim2.fromOffset(0, y)
			cert.TextWrapped = true
			cert.TextYAlignment = Enum.TextYAlignment.Top
			cert.TextColor3 = HudTheme.Colors.bar
			cert.RichText = badges ~= nil
			cert.TextTruncate = Enum.TextTruncate.None
			if badges and #badges > 3 then
				cert.Size = UDim2.new(1, 0, 0, 20 + 19 * #badges)
			end

			local close = HudTheme.button(
				"Close",
				"Close",
				UDim2.fromOffset(200, HudTheme.MinButtonHeight),
				screen
			)
			close.AnchorPoint = Vector2.new(0.5, 1)
			close.Position = UDim2.new(0.5, 0, 1, -10)
			HudTheme.corner(close, 10)
			close.Activated:Connect(debrief.hide)

			tablet.Visible = true
			shownAt = os.clock()
			if closeThread then
				task.cancel(closeThread)
			end
			closeThread = task.delay(40, debrief.hide)
		end,
	}
	return debrief
end

return OpsDebrief
