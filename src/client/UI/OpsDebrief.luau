--!strict
-- OpsDebrief: the end-of-call result as a wordless toast (docs/16 K5). It slides down in the HudLayout
-- "debrief" region (top centre where it fits): up to three stars stamp in, Cash rolls up (the coins fly to the HUD's Cash counter), the
-- time shows on a stopwatch, and three mastery icons light up when earned: smooth ride (boat),
-- nobody left (seat) and fast (speed) (shared/Ops/Grading.mastery). No grading text. It never takes
-- input or covers the play area, and slides away on its own.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local AudioController =
	require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("AudioController"))
local CashBurst = require(script.Parent.CashBurst)
local Glyph = require(script.Parent.Glyph)
local Grading =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Ops"):WaitForChild("Grading"))
local Hud = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("UiImages")
).Hud
local HudTheme = require(script.Parent.HudTheme)
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

export type Debrief = {
	show: (d: { [string]: any }, auto: number?) -> (),
	hide: () -> (),
	shownFor: () -> number,
}

local SHOW_FOR = 5 -- s on screen
local STAR = 34
local MASTERY = 28
local DIM = Color3.fromHex("3A4650")

local OpsDebrief = {}

local function tween(o: Instance, seconds: number, props: { [string]: any }, delay: number?)
	local info = TweenInfo.new(
		seconds,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out,
		0,
		false,
		delay or 0
	)
	TweenService:Create(o, info, props):Play()
end

-- Three stars; the earned ones stamp in from large, one after another.
local function stars(parent: Instance, earned: number)
	for i = 1, 3 do
		local lit = i <= earned
		local slot = Instance.new("Frame")
		slot.Name = "Star" .. i
		slot.BackgroundTransparency = 1
		slot.Size = UDim2.fromOffset(STAR, STAR)
		slot.Position = UDim2.fromOffset((i - 1) * (STAR + 6), 0)
		slot.Parent = parent
		local s = HudTheme.image("Icon", Hud.XpStar, UDim2.fromScale(1, 1), slot)
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Position = UDim2.fromScale(0.5, 0.5)
		if lit then
			s.Size = UDim2.fromScale(2, 2)
			s.Rotation = -20
			s.ImageTransparency = 1
			tween(
				s,
				0.4,
				{ Size = UDim2.fromScale(1, 1), Rotation = 0, ImageTransparency = 0 },
				0.25 + i * 0.18
			)
			task.delay(0.6 + i * 0.18, function() -- each star stamps down, a step higher
				AudioController.play("Album_Sticker", nil, 0.9, 1 + (i - 1) * 0.12)
			end)
		else
			s.ImageColor3 = DIM
			s.ImageTransparency = 0.35
		end
	end
end

-- A mastery chip: a gold disc with a dark glyph when earned, a dim slate one when not.
local function mastery(parent: Instance, order: number, glyph: string, earned: boolean)
	local disc = Instance.new("Frame")
	disc.Name = glyph
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromOffset((order - 1) * (MASTERY + 12) + MASTERY // 2 + 3, MASTERY // 2)
	disc.Size = UDim2.fromOffset(MASTERY, MASTERY)
	disc.BackgroundColor3 = if earned then HudTheme.Colors.gold else DIM
	disc.BackgroundTransparency = if earned then 0 else 0.3
	disc.BorderSizePixel = 0
	disc.Parent = parent
	HudTheme.corner(disc, MASTERY // 2)
	local icon = Instance.new("Frame")
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.7, 0.7)
	icon.BackgroundTransparency = 1
	icon.Parent = disc
	Glyph.draw(glyph, icon, if earned then Color3.fromHex("1A1408") else Color3.fromHex("7C8A94"))
	if earned then
		disc.Size = UDim2.fromOffset(0, 0)
		tween(disc, 0.35, { Size = UDim2.fromOffset(MASTERY, MASTERY) }, 0.9 + order * 0.15)
	end
end

-- An icon, then a number; `roll` counts it up from 0 ("+300"), else the text shows as is.
local function row(
	parent: Instance,
	name: string,
	y: number,
	icon: GuiObject,
	size: number,
	color: Color3,
	roll: number?,
	text: string?
): TextLabel
	local group = Instance.new("Frame")
	group.Name = name
	group.Position = UDim2.fromOffset(0, y)
	group.Size = UDim2.new(1, 0, 0, 34)
	group.BackgroundTransparency = 1
	group.Parent = parent
	icon.Size = UDim2.fromOffset(28, 28)
	icon.Position = UDim2.fromOffset(0, 3)
	icon.Parent = group
	local label = HudTheme.label(
		"Value",
		text or "+0",
		UDim2.new(1, -36, 1, 0),
		HudTheme.NumberFont,
		size,
		group
	)
	label.Position = UDim2.fromOffset(36, 0)
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromHex("06101C")
	label.TextStrokeTransparency = 0.55
	if roll then
		local n = Instance.new("NumberValue")
		n.Parent = label
		n.Changed:Connect(function(v: number)
			label.Text = `+{HudTheme.formatNumber(v)}`
		end)
		local tw = TweenService:Create(
			n,
			TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.35),
			{ Value = roll }
		)
		tw.Completed:Connect(function()
			label.Text = `+{HudTheme.formatNumber(roll)}` -- lands on the exact pay, even when the tween is cut short
		end)
		tw:Play()
	end
	return label
end

local function clockIcon(): Frame
	local f = Instance.new("Frame")
	f.Name = "Icon"
	f.BackgroundTransparency = 1
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.9, 0.9)
	inner.BackgroundTransparency = 1
	inner.Parent = f
	Glyph.draw("clock", inner, HudTheme.Colors.text)
	return f
end

function OpsDebrief.new(parent: GuiObject): Debrief
	local player = Players.LocalPlayer
	local toast = HudTheme.panel("DebriefTablet", UDim2.fromOffset(340, 96), parent)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Visible = false
	HudTheme.skin(toast)
	-- shrinks to its HudLayout "debrief" region (a gap clear of the wallet and the edge HUD on small screens)
	local fit = Instance.new("UIScale")
	fit.Parent = toast
	local function refit()
		fit.Scale = math.min(1, parent.Size.X.Offset / 340)
	end
	parent:GetPropertyChangedSignal("Size"):Connect(refit)
	refit()
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Size = UDim2.fromScale(1, 1)
	content.BackgroundTransparency = 1
	content.Parent = toast
	local OPEN = UDim2.fromScale(0.5, 0)
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
			local m = Grading.mastery(
				tostring(d.grade or ""),
				if type(d.steps) == "table" then d.steps else {},
				tonumber(d.saved) or 0,
				tonumber(d.total) or 0
			)

			-- left: stars over the mastery chips
			local left = Instance.new("Frame")
			left.Name = "Result"
			left.BackgroundTransparency = 1
			left.Position = UDim2.fromOffset(18, 12)
			left.Size = UDim2.fromOffset(3 * STAR + 12, 76)
			left.Parent = content
			local starRow = Instance.new("Frame")
			starRow.Name = "Stars"
			starRow.BackgroundTransparency = 1
			starRow.Size = UDim2.fromOffset(3 * STAR + 12, STAR)
			starRow.Parent = left
			stars(starRow, m.stars)
			local chips = Instance.new("Frame")
			chips.Name = "Mastery"
			chips.BackgroundTransparency = 1
			chips.Position = UDim2.fromOffset(0, STAR + 10)
			chips.Size = UDim2.fromOffset(3 * STAR + 12, MASTERY)
			chips.Parent = left
			mastery(chips, 1, "boat", m.smooth)
			mastery(chips, 2, "seat", m.all)
			mastery(chips, 3, "speed", m.fast)

			-- right: Cash rolls up, the time under it
			local right = Instance.new("Frame")
			right.Name = "Pay"
			right.BackgroundTransparency = 1
			right.AnchorPoint = Vector2.new(1, 0)
			right.Position = UDim2.new(1, -14, 0, 12)
			right.Size = UDim2.fromOffset(150, 76)
			right.Parent = content
			local coin = HudTheme.image("Icon", Hud.Coin, UDim2.fromOffset(28, 28))
			row(
				right,
				"Cash",
				0,
				coin,
				28,
				HudTheme.Colors.gold,
				math.max(tonumber(d.cash) or 0, 0)
			)
			if m.stars > 0 then
				local secs = math.floor(m.seconds + 0.5)
				row(
					right,
					"Time",
					40,
					clockIcon(),
					22,
					HudTheme.Colors.text,
					nil,
					string.format("%d:%02d", secs // 60, secs % 60)
				)
			else
				-- a lost call with no time worth showing: a life ring, "next one"
				local ring = Instance.new("Frame")
				ring.BackgroundTransparency = 1
				Glyph.draw("ring", ring, HudTheme.Colors.gold)
				row(right, "Next", 40, ring, 22, HudTheme.Colors.text, nil, "Next one!")
			end

			toast.Position = CLOSED
			toast.Visible = true
			TweenService:Create(
				toast,
				TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = OPEN }
			):Play()
			shownAt = os.clock()
			-- the payout flies from the toast's coin into the HUD's Cash counter; lifebuoy plates and coins round you
			if (tonumber(d.cash) or 0) > 0 then
				local root = player.Character
					and player.Character:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local fx = if d.golden == true then "fx1_golden_rescue" else "rescue_done"
					VFXKit.play(fx, CFrame.new(root.Position), { radius = 3, height = 3 })
				end
				task.delay(0.9, function()
					local playerGui = player.PlayerGui
					if toast.Visible and playerGui then
						local at = coin.AbsolutePosition + coin.AbsoluteSize * 0.5
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
