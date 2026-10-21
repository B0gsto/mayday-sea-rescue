--!strict
-- OpsConditionMonitor: the casualty's condition as a portable patient monitor (Assist only; hidden
-- in Pro, where the casualty is read from their behaviour). A sweeping ECG trace whose rate and
-- amplitude follow the condition meter, a heart with the rate, a thermometer with an estimated core
-- temperature (hypothermia drops both), a status face and a trend arrow; a lifejacket icon (struck
-- when they have none). No words (docs/14 section 2). On a big call it follows the casualty in the
-- worst state.
local RunService = game:GetService("RunService")

local HudTheme = require(script.Parent.HudTheme)

export type Monitor = { update: (casualties: { any }, visible: boolean) -> (), hide: () -> () }

local SCREEN = Color3.fromHex("060B0A")
local TRACE = Color3.fromHex("3EE07A")
local AMBER = Color3.fromHex("FFB020")
local RED = Color3.fromHex("FF4D3A")
local SAMPLES = 48

-- condition band -> status face (VeryCold reads as cold, not "not responding")
local FACE: { [string]: string } =
	{ Stable = "🙂", Concern = "😟", Serious = "😵", Critical = "🚨" }

local OpsConditionMonitor = {}

-- One heartbeat of a PQRST complex, phase 0..1 -> amplitude -1..1.
local function ecg(phase: number): number
	local function bump(c: number, w: number, a: number): number
		local x = (phase - c) / w
		return a * math.exp(-x * x)
	end
	return bump(0.18, 0.035, 0.12)
		- bump(0.36, 0.012, 0.15)
		+ bump(0.4, 0.014, 1)
		- bump(0.44, 0.014, 0.25)
		+ bump(0.68, 0.06, 0.22)
end

function OpsConditionMonitor.new(gui: GuiBase2d): Monitor
	local body = Instance.new("Frame")
	body.Name = "CasualtyMonitor"
	body.LayoutOrder = 2 -- under the pager in the Layout "right" column
	body.Size = UDim2.fromOffset(230, 132)
	body.BackgroundColor3 = Color3.fromHex("2A3034")
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = gui
	HudTheme.corner(body, 12)
	local screen = Instance.new("Frame")
	screen.Position = UDim2.fromOffset(8, 8)
	screen.Size = UDim2.new(1, -16, 1, -16)
	screen.BackgroundColor3 = SCREEN
	screen.BorderSizePixel = 0
	screen.ClipsDescendants = true
	screen.Parent = body
	HudTheme.corner(screen, 6)

	local function txt(
		name: string,
		x: number,
		y: number,
		w: number,
		size: number,
		color: Color3
	): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromOffset(x, y)
		l.Size = UDim2.fromOffset(w, size + 2)
		l.Font = Enum.Font.Code
		l.TextSize = size
		l.TextColor3 = color
		l.TextXAlignment = Enum.TextXAlignment.Left
		l.Text = ""
		l.Parent = screen
		return l
	end
	local who = txt("Who", 8, 4, 200, 16, HudTheme.Colors.textDim)
	who.Font = HudTheme.BoldFont
	local hr = txt("HR", 8, 80, 80, 22, TRACE)
	hr.Font = HudTheme.BoldFont
	local temp = txt("Temp", 86, 80, 84, 20, AMBER)
	temp.Font = HudTheme.BoldFont
	local band = txt("Band", 166, 78, 44, 22, HudTheme.Colors.text)
	band.TextXAlignment = Enum.TextXAlignment.Right

	-- the trace: dots on a sweeping cursor
	local dots: { Frame } = {}
	for i = 1, SAMPLES do
		local d = Instance.new("Frame")
		d.BorderSizePixel = 0
		d.AnchorPoint = Vector2.new(0.5, 0.5)
		d.Size = UDim2.fromOffset(3, 3)
		d.BackgroundColor3 = TRACE
		d.Position = UDim2.new((i - 0.5) / SAMPLES, 0, 0, 46)
		d.Parent = screen
		dots[i] = d
	end
	local values = table.create(SAMPLES, 0)

	local cond = 100
	local lastCond = 100
	local trend = 0
	local beatPhase = 0
	local cursor = 1
	local acc = 0
	local conn: RBXScriptConnection? = nil

	local function start()
		if conn then
			return
		end
		conn = RunService.RenderStepped:Connect(function(dt: number)
			-- condition -> heart rate: 92/min when fine, a slow 38/min near critical
			local rate = 38 + 54 * math.clamp(cond / 100, 0, 1)
			beatPhase = (beatPhase + dt * rate / 60) % 1
			acc += dt
			local step = 2.2 / SAMPLES -- 2.2 s across the screen
			while acc >= step do
				acc -= step
				local amp = 0.45 + 0.55 * math.clamp(cond / 100, 0, 1)
				values[cursor] = ecg(beatPhase) * amp
				local d = dots[cursor]
				d.Position = UDim2.new((cursor - 0.5) / SAMPLES, 0, 0, 46 - values[cursor] * 26)
				d.BackgroundTransparency = 0
				-- the gap ahead of the cursor, fading tail behind it
				for k = 1, SAMPLES do
					local age = (cursor - k) % SAMPLES
					dots[k].BackgroundTransparency = if age > SAMPLES - 4
						then 1
						else age / SAMPLES * 0.7
				end
				cursor = cursor % SAMPLES + 1
			end
		end)
	end

	local monitor: Monitor
	monitor = {
		update = function(casualties: { any }, visible: boolean)
			local worst: any = nil
			for _, c in casualties do
				if
					not c.delivered
					and not c.takenOver
					and (worst == nil or c.condition < worst.condition)
				then
					worst = c
				end
			end
			if not visible or not worst then
				monitor.hide()
				return
			end
			lastCond = cond
			cond = worst.condition
			trend = trend * 0.6 + (cond - lastCond) * 0.4
			local color = if cond >= 70 then TRACE elseif cond >= 40 then AMBER else RED
			for _, d in dots do
				d.BackgroundColor3 = color
			end
			hr.TextColor3 = color
			local bpm = math.floor(38 + 54 * math.clamp(cond / 100, 0, 1) + 0.5)
			hr.Text = `❤ {bpm}`
			-- an estimate a crew would make: 36.8 when fine, ~31 at critical
			temp.Text = string.format("🌡%.1f°", 31 + 5.8 * math.clamp(cond / 100, 0, 1))
			local arrow = if trend < -0.05 then "▼" elseif trend > 0.05 then "▲" else ""
			local face = if worst.state == "VeryCold" and worst.band == "Serious"
				then "🥶"
				else FACE[worst.band or ""] or "🙂"
			band.Text = face .. arrow
			band.TextColor3 = color
			local count = #casualties
			local jacket = if worst.lifejacket then "🦺" else "🚫🦺"
			who.Text = if count > 1
				then `👤 {worst.index or "?"}/{count}  {jacket}  {worst.tag or ""}`
				else `👤  {jacket}`
			body.Visible = true
			start()
		end,
		hide = function()
			body.Visible = false
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end,
	}
	return monitor
end

return OpsConditionMonitor
