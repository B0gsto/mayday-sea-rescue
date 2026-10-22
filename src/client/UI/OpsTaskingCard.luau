--!strict
-- OpsTaskingCard: the tasking offer as a DSC pager (top right), a vertical card: the call-type
-- icon (the PIW sprite, else a Glyph disc), a one to three word label over the distance, and a
-- pulsing accept button (check sprite + device key chip; the check alone on touch). No readout lines (docs/14 section 2:
-- show, don't tell). Readable and tappable on a phone (>= 52 px key).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

-- keyboard / gamepad accept while the pager shows (every pad button is taken in play, so this
-- one outranks the light-bar toggle on DPadLeft for those few seconds)
local ACCEPT_KEY, ACCEPT_PAD = Enum.KeyCode.Return, Enum.KeyCode.DPadLeft
local ACCEPT_ACTION = "TaskingAccept"

local RED = Color3.fromHex("E8332A")
local AMBER = Color3.fromHex("FFB020")

-- kind -> Glyph icon, <= 3 words, alert colour
local KIND: { [string]: { icon: string, label: string, color: Color3 } } = {
	PersonInWater = { icon = "swimmer", label = "Person in water", color = RED },
	CapsizedFerry = { icon = "boat", label = "Ferry relay", color = RED },
	DisabledVessel = { icon = "boat", label = "Disabled vessel", color = AMBER },
	VesselFire = { icon = "boat", label = "Vessel fire", color = RED },
	RipCurrent = { icon = "swimmer", label = "Rip current", color = RED },
	SinkingVessel = { icon = "boat", label = "Sinking vessel", color = RED },
	CliffCasualty = { icon = "cross", label = "Cliff casualty", color = RED },
	ExerciseBoatHandling = { icon = "boat", label = "Boat drill", color = AMBER },
	ExerciseCasualtyCare = { icon = "cross", label = "Care drill", color = AMBER },
	ExerciseSwimTest = { icon = "swimmer", label = "Swim drill", color = AMBER },
}

-- The first three words of a title, for kinds not in the table.
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

local OpsTaskingCard = {}

function OpsTaskingCard.new(gui: GuiBase2d): Card
	-- a vertical card (assets/ui/hud/mockup.png): alert strip, call icon, label, range, accept
	local body = HudTheme.image(
		"TaskingPager",
		Hud.Panel,
		UDim2.fromOffset(180, 236),
		gui,
		HudTheme.Slice.Panel,
		0.45
	)
	body.LayoutOrder = 1 -- top of the Layout "right" column
	body.Visible = false
	-- 0.8x on touch (clear of the jump button); made before the labels so their text floor sees it
	local touchScale = Instance.new("UIScale")
	touchScale.Parent = body
	local function fitTouch(mt: Layout.Metrics)
		touchScale.Scale = if mt.touch then 0.8 else 1
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

	-- the call icon: the PIW sprite, or a Glyph disc for kinds without one
	local ICON = 64
	local sprite = HudTheme.image("Sprite", Hud.MissionPiw, UDim2.fromOffset(ICON, ICON), body)
	sprite.AnchorPoint = Vector2.new(0.5, 0)
	sprite.Position = UDim2.new(0.5, 0, 0, 14)
	local badge = Instance.new("Frame")
	badge.Name = "Kind"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 16)
	badge.Size = UDim2.fromOffset(ICON - 4, ICON - 4)
	badge.BackgroundColor3 = RED
	badge.BorderSizePixel = 0
	badge.Parent = body
	HudTheme.corner(badge, 32)
	HudTheme.stroke(badge, Color3.new(1, 1, 1), 3)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.66, 0.66)
	icon.BackgroundTransparency = 1
	icon.Parent = badge

	-- three words on two lines
	local name = HudTheme.label("Name", "", UDim2.new(1, -16, 0, 50), HudTheme.LabelFont, 20, body)
	name.AnchorPoint = Vector2.new(0.5, 0)
	name.Position = UDim2.new(0.5, 0, 0, 80)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextWrapped = true
	HudTheme.outline(name)
	local range =
		HudTheme.label("Range", "", UDim2.new(1, -16, 0, 34), HudTheme.NumberFont, 30, body)
	range.AnchorPoint = Vector2.new(0.5, 0)
	range.Position = UDim2.new(0.5, 0, 0, 130)
	range.TextXAlignment = Enum.TextXAlignment.Center
	HudTheme.outline(range)

	-- accept: the check sprite (>= 48 px touch target), the device key chip on its corner
	local key = Instance.new("ImageButton")
	key.Name = "Launch"
	key.AnchorPoint = Vector2.new(0.5, 1)
	key.Position = UDim2.new(0.5, 0, 1, -10)
	key.Size = UDim2.fromOffset(60, 60)
	key.BackgroundTransparency = 1
	key.Image = Hud.AcceptButton
	key.ScaleType = Enum.ScaleType.Fit
	key.Parent = body
	local pulse = Instance.new("UIScale")
	pulse.Parent = key
	local chip = InputGlyph.chip(key, ACCEPT_KEY, ACCEPT_PAD)
	chip.AnchorPoint = Vector2.new(0.5, 0.5)
	chip.Position = UDim2.new(1, -6, 1, -8)

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
			currentId = data.opId
			acceptFn = onAccept
			local kind = KIND[data.kind]
			if not kind then
				kind = {
					icon = "ring",
					label = short(tostring(data.title or "Tasking")),
					color = AMBER,
				}
			end
			local piw = data.kind == "PersonInWater"
			sprite.Visible = piw
			badge.Visible = not piw
			if not piw then
				Glyph.draw(kind.icon, icon, Color3.new(1, 1, 1))
			end
			badge.BackgroundColor3 = kind.color
			strip.BackgroundColor3 = kind.color
			name.Text = string.upper(kind.label)
			body.Visible = true
			ContextActionService:BindActionAtPriority(ACCEPT_ACTION, function(_, state)
				if state == Enum.UserInputState.Begin then
					accept()
				end
				return Enum.ContextActionResult.Sink
			end, false, Enum.ContextActionPriority.High.Value, ACCEPT_KEY, ACCEPT_PAD)
			if conn then
				conn:Disconnect()
			end
			local t = 0
			conn = RunService.Heartbeat:Connect(function(dt)
				t += dt
				-- the alert strip flashes and the accept button pulses like a DSC alarm
				strip.BackgroundTransparency = if math.floor(t * 2.5) % 2 == 0 then 0 else 0.5
				pulse.Scale = 1 + 0.04 * math.sin(t * 5)
				local char = Players.LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local pos = data.position
				if root and typeof(pos) == "Vector3" then
					local d = pos - root.Position
					local metres = Vector3.new(d.X, 0, d.Z).Magnitude * 0.28
					range.Text = if metres < 1000
						then `{math.floor(metres / 10 + 0.5) * 10} m`
						else string.format("%.1f km", metres / 1000)
				else
					range.Text = ""
				end
				local left = (data.offerExpiresAt or 0) - workspace:GetServerTimeNow()
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
