--!strict
-- OpsTaskingCard: the tasking offer as a DSC pager (top right), one compact row: the call-type
-- icon (Glyph, no emoji), a one to three word label over the distance, and a pulsing accept key
-- (check + device key chip; the check alone on touch). No readout lines (docs/14 section 2:
-- show, don't tell). Readable and tappable on a phone (>= 52 px key).
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Glyph = require(script.Parent.Glyph)
local HudTheme = require(script.Parent.HudTheme)
local InputGlyph = require(script.Parent.InputGlyph)

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
	-- one 64 px row: [kind icon] [label / range] [accept]; the column's UIScale fits the screen
	local body = Instance.new("Frame")
	body.Name = "TaskingPager"
	body.LayoutOrder = 1 -- top of the Layout "right" column
	body.Size = UDim2.new(1, 0, 0, 64)
	body.BackgroundColor3 = HudTheme.Colors.panel
	body.BackgroundTransparency = 0.12
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = gui
	HudTheme.corner(body, 12)
	local stroke = HudTheme.stroke(body, RED, 1.5)

	local badge = Instance.new("Frame")
	badge.Name = "Kind"
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, 8, 0.5, 0)
	badge.Size = UDim2.fromOffset(48, 48)
	badge.BackgroundColor3 = RED
	badge.BorderSizePixel = 0
	badge.Parent = body
	HudTheme.corner(badge, 10)
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	icon.Size = UDim2.fromScale(0.78, 0.78)
	icon.BackgroundTransparency = 1
	icon.Parent = badge

	local KEY_W = 92 -- accept key width (>= 48 px touch target, room for "Enter")
	local textW = UDim2.new(1, -(64 + KEY_W + 16), 0, 22)
	local name = HudTheme.label("Name", "", textW, Enum.Font.BuilderSansBold, 16, body)
	name.Position = UDim2.fromOffset(64, 10)
	name.TextScaled = true -- three words fit the narrowest column
	local fit = Instance.new("UITextSizeConstraint")
	fit.MaxTextSize = 16
	fit.MinTextSize = 11
	fit.Parent = name
	local range = HudTheme.label("Range", "", textW, Enum.Font.BuilderSansBold, 20, body)
	range.Position = UDim2.fromOffset(64, 32)
	range.TextColor3 = HudTheme.Colors.textDim

	local key = Instance.new("TextButton")
	key.Name = "Launch"
	key.AnchorPoint = Vector2.new(1, 0.5)
	key.Position = UDim2.new(1, -8, 0.5, 0)
	key.Size = UDim2.fromOffset(KEY_W, 48)
	key.BackgroundColor3 = HudTheme.Colors.accent
	key.BorderSizePixel = 0
	key.Text = ""
	key.AutoButtonColor = true
	key.Parent = body
	HudTheme.corner(key, 10)
	local pulse = Instance.new("UIScale")
	pulse.Parent = key
	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.HorizontalAlignment = Enum.HorizontalAlignment.Center
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 6)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = key
	local tick = Instance.new("Frame")
	tick.Name = "Check"
	tick.Size = UDim2.fromOffset(26, 26)
	tick.BackgroundTransparency = 1
	tick.Parent = key
	Glyph.draw("check", tick, HudTheme.Colors.text)
	local chip = InputGlyph.chip(key, ACCEPT_KEY, ACCEPT_PAD)
	chip.LayoutOrder = 1

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
			Glyph.draw(kind.icon, icon, Color3.new(1, 1, 1))
			badge.BackgroundColor3 = kind.color
			stroke.Color = kind.color
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
				-- the alert badge flashes and the accept glyph pulses like a DSC alarm
				badge.BackgroundTransparency = if math.floor(t * 2.5) % 2 == 0 then 0 else 0.3
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
