--!strict
-- ChallengeTracker: the small HUD tracker for the player's daily and weekly challenges (LU-1).
-- Icons, one-word labels and numbers only; no menus and nothing to press (the player just plays).
-- Daily rows show progress; the weekly row shows completed challenges and the stamp count.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("ChallengeConfig"))
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)

local C = HudTheme.Colors
local W, H = 214, 128

local BY_ID: { [string]: any } = {}
for _, def in Config.Pool do
	BY_ID[def.id] = def
end

export type View = {
	daily: { { id: string, progress: number, target: number, done: boolean } },
	weekly: { { id: string, progress: number, target: number, done: boolean } },
	stamps: number,
}

export type Tracker = { update: (view: View?) -> () }

local ChallengeTracker = {}

local function row(parent: Instance, y: number): (TextLabel, TextLabel, TextLabel)
	local bg = Instance.new("Frame")
	bg.Name = "Row"
	bg.BackgroundColor3 = C.panelLight
	bg.BackgroundTransparency = 0.55
	bg.BorderSizePixel = 0
	bg.Position = UDim2.fromOffset(8, y)
	bg.Size = UDim2.new(1, -16, 0, 24)
	bg.Parent = parent
	local icon = HudTheme.label("Icon", "", UDim2.fromOffset(24, 24), HudTheme.BodyFont, 20, bg)
	icon.TextXAlignment = Enum.TextXAlignment.Center
	local name = HudTheme.label("Name", "", UDim2.new(1, -88, 0, 24), HudTheme.BodyFont, 20, bg)
	name.Position = UDim2.fromOffset(26, 0)
	name.TextColor3 = C.textDim
	local value = HudTheme.label("Value", "", UDim2.fromOffset(54, 24), HudTheme.BoldFont, 20, bg)
	value.AnchorPoint = Vector2.new(1, 0)
	value.Position = UDim2.fromScale(1, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return icon, name, value
end

function ChallengeTracker.build(gui: ScreenGui): Tracker
	local frame = HudTheme.panel("ChallengeTracker", UDim2.fromOffset(W, H), gui)
	frame.AnchorPoint = Vector2.new(0, 0)
	HudTheme.padding(frame, 0)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	-- touch: the card collapses to one icon under the minimap (Layout "challenge" rect)
	local full = Instance.new("Frame")
	full.Name = "Full"
	full.BackgroundTransparency = 1
	full.Size = UDim2.fromScale(1, 1)
	full.Parent = frame
	local compact =
		HudTheme.label("Compact", "🏆", UDim2.fromScale(1, 1), HudTheme.BodyFont, 34, frame)
	compact.TextXAlignment = Enum.TextXAlignment.Center
	compact.Visible = false

	local header = HudTheme.label(
		"Title",
		"CHALLENGES",
		UDim2.new(1, -56, 0, 24),
		HudTheme.HeaderFont,
		20,
		full
	)
	header.Position = UDim2.fromOffset(10, 4)
	header.TextColor3 = C.accent
	local stamps =
		HudTheme.label("Stamps", "", UDim2.fromOffset(44, 24), HudTheme.BoldFont, 20, full)
	stamps.AnchorPoint = Vector2.new(1, 0)
	stamps.Position = UDim2.new(1, -10, 0, 4)
	stamps.TextXAlignment = Enum.TextXAlignment.Right
	stamps.TextColor3 = C.gold

	local daily = {}
	for i = 1, Config.DailyCount do
		local icon, name, value = row(full, 30 + (i - 1) * 24)
		daily[i] = { icon = icon, name = name, value = value }
	end
	local weeklyIcon, weeklyName, weeklyValue = row(full, 30 + Config.DailyCount * 24)
	weeklyIcon.Text = "🗓"
	weeklyName.Text = "WEEKLY"
	weeklyValue.TextColor3 = C.text

	local function place(mt: Layout.Metrics)
		local _, pos, size = Layout.rect("challenge", mt)
		scale.Scale = mt.scale
		frame.Position = UDim2.fromOffset(pos.X * mt.scale, pos.Y * mt.scale)
		frame.Size = UDim2.fromOffset(size.X, size.Y)
		full.Visible = not mt.touch
		compact.Visible = mt.touch
	end
	place(Layout.current())
	Layout.onMetrics(place)

	local function update(view: View?)
		local weeklyDone, weeklyTotal = 0, 0
		for i, cell in daily do
			local slot = if view then view.daily[i] else nil
			local def = if slot then BY_ID[slot.id] else nil
			cell.icon.Text = if def then def.icon else "·"
			cell.name.Text = if def then def.label else "--"
			if slot then
				cell.value.Text = if slot.done then "✓" else `{slot.progress}/{slot.target}`
				cell.value.TextColor3 = if slot.done then C.ready else C.text
			else
				cell.value.Text = "--"
				cell.value.TextColor3 = C.textDim
			end
		end
		if view then
			for _, slot in view.weekly do
				weeklyTotal += 1
				if slot.done then
					weeklyDone += 1
				end
			end
			weeklyValue.Text = `{weeklyDone}/{weeklyTotal}`
			stamps.Text = `★{view.stamps}`
		else
			weeklyValue.Text = "--"
			stamps.Text = ""
		end
		weeklyValue.TextColor3 = if weeklyTotal > 0 and weeklyDone == weeklyTotal
			then C.ready
			else C.text
	end

	local tracker: Tracker = { update = update }
	update(nil)
	return tracker
end

return ChallengeTracker
