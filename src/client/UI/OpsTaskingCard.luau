--!strict
-- OpsTaskingCard: the call as a DSC pager (top right), wordless (docs/16 K2): a flashing alert
-- strip, the call-type icon (the PIW sprite, else a Glyph disc), how far away it is (docs/20) and a
-- pulsing accept button
-- (check sprite + device key chip: R / gamepad DPadUp; the check alone on touch). The world shows
-- the way (flare, minimap blip, Bosun) and a chevron off the pager points at the call's world
-- marker; driving at the call takes it too (OpsController).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Glyph = require(script.Parent.Glyph)
local Hud = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
).Hud
local HudTheme = require(script.Parent.HudTheme)
local InputGlyph = require(script.Parent.InputGlyph)
local Layout = require(script.Parent.Layout)

export type Card = {
	show: (data: { [string]: any }, onAccept: (opId: string) -> ()) -> (),
	hide: (opId: string?) -> (),
}

-- R answers the radio; the pad's DPadUp is the radio key too. Bound at High priority only while
-- the pager shows (it outranks the whistle / car lights for those seconds).
local ACCEPT_KEY, ACCEPT_PAD = Enum.KeyCode.R, Enum.KeyCode.DPadUp
local ACCEPT_ACTION = "TaskingAccept"

local RED = Color3.fromHex("E8332A")
local AMBER = Color3.fromHex("FFB020")

-- kind -> Glyph icon and alert colour (PersonInWater uses the MissionPiw sprite)
local KIND: { [string]: { icon: string, color: Color3 } } = {
	PersonInWater = { icon = "swimmer", color = RED },
	RipCurrent = { icon = "swimmer", color = RED },
	CapsizedFerry = { icon = "boat", color = RED },
	SinkingVessel = { icon = "boat", color = RED },
	VesselFire = { icon = "flare", color = RED },
	CliffCasualty = { icon = "cross", color = RED },
	WildlifeRescue = { icon = "ring", color = AMBER },
}

local OpsTaskingCard = {}
OpsTaskingCard.KIND = KIND -- the world waypoint (UI/Waypoint) draws the same icon

function OpsTaskingCard.new(gui: GuiBase2d): Card
	local body = HudTheme.image(
		"TaskingPager",
		Hud.Panel,
		UDim2.fromOffset(120, 196), -- 20 px taller for the distance
		gui,
		HudTheme.Slice.Panel,
		0.45
	)
	body.LayoutOrder = 1 -- top of the Layout "right" column
	body.Visible = false
	-- 0.8x on touch (clear of the jump button); the show pop scales from here
	local scale = Instance.new("UIScale")
	scale.Parent = body
	local baseScale = 1
	local function fitTouch(mt: Layout.Metrics)
		baseScale = if mt.touch then 0.8 else 1
		scale.Scale = baseScale
	end
	fitTouch(Layout.current())
	Layout.onMetrics(fitTouch)
	local strip = Instance.new("Frame")
	strip.Name = "Alert"
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.fromScale(0.5, 0)
	strip.Size = UDim2.new(0.62, 0, 0, 7)
	strip.BackgroundColor3 = RED
	strip.BorderSizePixel = 0
	strip.Parent = body
	HudTheme.corner(strip, 4)

	-- the call icon: the PIW sprite, or a Glyph disc for the other kinds
	local ICON = 72
	local sprite = HudTheme.image("Sprite", Hud.MissionPiw, UDim2.fromOffset(ICON, ICON), body)
	sprite.AnchorPoint = Vector2.new(0.5, 0)
	sprite.Position = UDim2.new(0.5, 0, 0, 18)
	local badge = Instance.new("Frame")
	badge.Name = "Kind"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 20)
	badge.Size = UDim2.fromOffset(ICON - 4, ICON - 4)
	badge.BackgroundColor3 = RED
	badge.BorderSizePixel = 0
	badge.Parent = body
	HudTheme.corner(badge, 34)
	HudTheme.stroke(badge, Color3.new(1, 1, 1), 3)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.BackgroundTransparency = 1
	icon.Parent = badge

	-- how far: metres from you to the call, live (Waypoint.metres' format; Waypoint requires this module)
	local far =
		HudTheme.label("Distance", "", UDim2.new(1, 0, 0, 22), HudTheme.NumberFont, 20, body)
	far.Position = UDim2.fromOffset(0, 90)
	far.TextColor3 = HudTheme.Colors.text
	far.TextStrokeColor3 = Color3.fromHex("06101C")
	far.TextStrokeTransparency = 0.55

	-- accept: the check sprite (>= 48 px touch target); the key chip at its right shoulder
	local key = Instance.new("ImageButton")
	key.Name = "Launch"
	key.AnchorPoint = Vector2.new(0.5, 1)
	key.Position = UDim2.new(0.5, 0, 1, -10)
	key.Size = UDim2.fromOffset(64, 64)
	key.BackgroundTransparency = 1
	key.Image = Hud.AcceptButton
	key.ScaleType = Enum.ScaleType.Fit
	key.Parent = body
	local pulse = Instance.new("UIScale")
	pulse.Parent = key
	local chip = InputGlyph.chip(key, ACCEPT_KEY, ACCEPT_PAD)
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.fromScale(0.92, 0.12)

	-- the way to the call (playtest 2: the pager did not read as "drive there"): a chevron round the
	-- pager's rim, pointing at the world marker (UI/Waypoint's Mark) and nudging toward it
	local HALF = Vector2.new(60, 98) -- the pager's half size
	local way = Instance.new("Frame")
	way.Name = "Way"
	way.Position = UDim2.fromScale(0.5, 0.5)
	way.Size = UDim2.fromOffset(0, 0) -- turns about the pager's centre
	way.BackgroundTransparency = 1
	way.Visible = false
	way.Parent = body
	local arrow = Instance.new("Frame")
	arrow.Name = "Chevron"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(34, 26)
	arrow.BackgroundTransparency = 1
	arrow.Parent = way
	for _, side in { -1, 1 } do
		local arm = Instance.new("Frame")
		arm.AnchorPoint = Vector2.new(0.5, 0.5)
		arm.Position = UDim2.new(0.5, side * 7.5, 0.5, 3)
		arm.Size = UDim2.fromOffset(25, 9)
		arm.Rotation = side * 45
		arm.BorderSizePixel = 0
		arm.Parent = arrow
		HudTheme.corner(arm, 4)
		HudTheme.stroke(arm, Color3.new(1, 1, 1), 2)
	end

	local currentId: string? = nil
	local acceptFn: ((string) -> ())? = nil
	local conn: RBXScriptConnection? = nil
	local function accept()
		local id, fn = currentId, acceptFn
		if id and fn then
			fn(id)
		end
	end
	key.Activated:Connect(accept)

	local card: Card
	card = {
		show = function(data: { [string]: any }, onAccept: (string) -> ())
			local fresh = currentId ~= data.opId
			currentId = data.opId
			acceptFn = onAccept
			local kind = KIND[data.kind] or { icon = "ring", color = AMBER }
			local piw = data.kind == "PersonInWater"
			sprite.Visible = piw
			badge.Visible = not piw
			if not piw then
				Glyph.draw(kind.icon, icon, Color3.new(1, 1, 1))
			end
			badge.BackgroundColor3 = kind.color
			strip.BackgroundColor3 = kind.color
			for _, arm in arrow:GetChildren() do
				(arm :: Frame).BackgroundColor3 = kind.color
			end
			body.Visible = false -- the Heartbeat shows it (and binds R) while the phone is shut
			if conn then
				conn:Disconnect()
			end
			local t = 0
			conn = RunService.Heartbeat:Connect(function(dt)
				t += dt
				-- the phone covers the HUD: hide the pager and free R for the phone's own keys
				local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
				local phone = pg and pg:FindFirstChild("Phone") -- UI/Phone's ScreenGui, Enabled while up
				local shown = not (phone and phone:IsA("ScreenGui") and phone.Enabled)
				if shown ~= body.Visible then
					body.Visible = shown
					if shown then
						ContextActionService:BindActionAtPriority(ACCEPT_ACTION, function(_, state)
							if state == Enum.UserInputState.Begin then
								accept()
							end
							return Enum.ContextActionResult.Sink
						end, false, Enum.ContextActionPriority.High.Value, ACCEPT_KEY, ACCEPT_PAD)
						if fresh then -- a new call pops in
							fresh = false
							scale.Scale = baseScale * 0.6
							TweenService
								:Create(
									scale,
									TweenInfo.new(
										0.35,
										Enum.EasingStyle.Back,
										Enum.EasingDirection.Out
									),
									{ Scale = baseScale }
								)
								:Play()
						end
					else
						ContextActionService:UnbindAction(ACCEPT_ACTION)
					end
				end
				-- the alert strip flashes and the accept button pulses like a DSC alarm
				strip.BackgroundTransparency = if math.floor(t * 2.5) % 2 == 0 then 0 else 0.5
				pulse.Scale = 1 + 0.05 * math.sin(t * 5)
				local wp = pg and pg:FindFirstChild("Waypoint")
				local mark = wp and wp:FindFirstChild("Mark") :: GuiObject?
				way.Visible = shown and mark ~= nil and mark.Visible
				if way.Visible then
					local m = mark :: GuiObject
					local d = m.AbsolutePosition
						+ m.AbsoluteSize / 2
						- body.AbsolutePosition
						- body.AbsoluteSize / 2
					local a = math.atan2(d.X, -d.Y) -- 0 = up, clockwise
					local sa, ca = math.abs(math.sin(a)), math.abs(math.cos(a))
					local rim = math.min(HALF.X / math.max(sa, 1e-3), HALF.Y / math.max(ca, 1e-3))
					way.Rotation = math.deg(a)
					arrow.Position = UDim2.fromOffset(0, -(rim + 24 + 6 * math.sin(t * 6)))
				end
				local me = Players.LocalPlayer.Character
				if me and typeof(data.position) == "Vector3" then
					local m = ((me:GetPivot().Position - data.position) * Vector3.new(1, 0, 1)).Magnitude
						/ 3
					far.Text = if m >= 1000
						then string.format("%.1f km", m / 1000)
						else `{math.floor(m / 10 + 0.5) * 10} m`
				end
				far.Visible = me ~= nil and typeof(data.position) == "Vector3"
				local left = (data.offerExpiresAt or math.huge) - workspace:GetServerTimeNow()
				if left < -2 then
					card.hide(data.opId)
				end
			end)
		end,
		hide = function(opId: string?)
			if opId and opId ~= currentId then
				return
			end
			currentId = nil
			body.Visible = false
			ContextActionService:UnbindAction(ACCEPT_ACTION)
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end,
	}
	return card
end

return OpsTaskingCard
