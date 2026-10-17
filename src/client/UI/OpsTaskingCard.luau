--!strict
-- OpsTaskingCard: the tasking offer as a DSC pager / VHF alert readout (top right). A red (MAYDAY)
-- or amber (PAN-PAN) alert strip, the LCD readout (what, where, range and bearing from you, the
-- respond-by countdown, the award) and one big Launch/Join key. Readable on a phone (>= 52 px key).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HudTheme = require(script.Parent.HudTheme)

export type Card = {
	show: (data: { [string]: any }, onAccept: (opId: string) -> ()) -> (),
	hide: (opId: string?) -> (),
}

local LCD_BG = Color3.fromHex("0B1D14")
local LCD_TEXT = Color3.fromHex("C8F7D2")
local LCD_DIM = Color3.fromHex("5E8A6B")
local RED = Color3.fromHex("E8332A")
local AMBER = Color3.fromHex("FFB020")

local PRIORITY = {
	PersonInWater = { word = "MAYDAY", color = RED },
	CapsizedFerry = { word = "MAYDAY RELAY", color = RED },
	DisabledVessel = { word = "PAN-PAN", color = AMBER },
}

local OpsTaskingCard = {}

local function lcdLine(
	parent: Instance,
	y: number,
	size: number,
	color: Color3,
	font: Enum.Font?
): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position = UDim2.fromOffset(12, y)
	l.Size = UDim2.new(1, -24, 0, size + 4)
	l.Font = font or Enum.Font.Code
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Text = ""
	l.Parent = parent
	return l
end

function OpsTaskingCard.new(gui: ScreenGui): Card
	local body = Instance.new("Frame")
	body.Name = "TaskingPager"
	body.AnchorPoint = Vector2.new(1, 0)
	body.Position = UDim2.new(1, -12, 0, 64)
	body.Size = UDim2.fromOffset(360, 250)
	body.BackgroundColor3 = Color3.fromHex("1B1F22")
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = gui
	HudTheme.corner(body, 14)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("3A4248")
	stroke.Thickness = 2
	stroke.Parent = body
	local scale = Instance.new("UIScale")
	scale.Parent = body

	local strip = Instance.new("TextLabel")
	strip.Name = "Alert"
	strip.Position = UDim2.fromOffset(10, 10)
	strip.Size = UDim2.new(1, -20, 0, 30)
	strip.BackgroundColor3 = RED
	strip.BorderSizePixel = 0
	strip.Font = HudTheme.BoldFont
	strip.TextSize = 20
	strip.TextColor3 = Color3.new(1, 1, 1)
	strip.Parent = body
	HudTheme.corner(strip, 6)

	local lcd = Instance.new("Frame")
	lcd.Position = UDim2.fromOffset(10, 46)
	lcd.Size = UDim2.new(1, -20, 0, 128)
	lcd.BackgroundColor3 = LCD_BG
	lcd.BorderSizePixel = 0
	lcd.Parent = body
	HudTheme.corner(lcd, 6)
	local what = lcdLine(lcd, 6, 20, LCD_TEXT, HudTheme.BoldFont)
	local where = lcdLine(lcd, 32, 16, LCD_TEXT)
	local rangeL = lcdLine(lcd, 54, 16, LCD_TEXT)
	local award = lcdLine(lcd, 76, 16, LCD_DIM)
	local timer = lcdLine(lcd, 100, 16, LCD_TEXT)

	local key = Instance.new("TextButton")
	key.Name = "Launch"
	key.AnchorPoint = Vector2.new(0.5, 1)
	key.Position = UDim2.new(0.5, 0, 1, -10)
	key.Size = UDim2.new(1, -20, 0, HudTheme.MinButtonHeight)
	key.BackgroundColor3 = HudTheme.Colors.accent
	key.BorderSizePixel = 0
	key.Font = HudTheme.BoldFont
	key.TextSize = 22
	key.TextColor3 = HudTheme.Colors.text
	key.Parent = body
	HudTheme.corner(key, 10)

	local currentId: string? = nil
	local acceptFn: ((string) -> ())? = nil
	local conn: RBXScriptConnection? = nil
	key.Activated:Connect(function()
		local id, fn = currentId, acceptFn
		if id and fn then
			fn(id)
		end
	end)

	local card: Card
	card = {
		show = function(data: { [string]: any }, onAccept: (string) -> ())
			currentId = data.opId
			acceptFn = onAccept
			local pr = PRIORITY[data.kind] or { word = "SECURITE", color = AMBER }
			strip.Text = `DSC ALERT · {pr.word}`
			strip.BackgroundColor3 = pr.color
			what.Text = string.upper(tostring(data.title or "Tasking"))
			where.Text = `POS  {data.zoneName or "Gale Isles"}`
			award.Text = `AWARD  ~{data.cash or 0} Cash · {data.rep or 0} Rep`
			key.Text = if data.isBig then "JOIN · ALL UNITS" else "ACCEPT · LAUNCH"
			local cam = workspace.CurrentCamera
			scale.Scale = if cam and cam.ViewportSize.X < 700 then 0.82 else 1
			body.Visible = true
			if conn then
				conn:Disconnect()
			end
			local t = 0
			conn = RunService.Heartbeat:Connect(function(dt)
				t += dt
				-- the alert strip flashes like a DSC distress alarm
				strip.BackgroundTransparency = if math.floor(t * 2.5) % 2 == 0 then 0 else 0.45
				local char = Players.LocalPlayer.Character
				local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
				local pos = data.position
				if root and typeof(pos) == "Vector3" then
					local d = pos - root.Position
					local metres = Vector3.new(d.X, 0, d.Z).Magnitude * 0.28
					local brg = (math.deg(math.atan2(d.X, -d.Z)) + 360) % 360
					rangeL.Text = string.format(
						"RNG %.2f NM  BRG %03d°",
						metres / 1852,
						math.floor(brg + 0.5)
					)
				else
					rangeL.Text = "RNG --  BRG --"
				end
				local left = (data.offerExpiresAt or 0) - workspace:GetServerTimeNow()
				timer.Text = if left > 0
					then string.format(
						"RESPOND  %d:%02d",
						math.floor(left / 60),
						math.floor(left % 60)
					)
					else "RESPOND  NOW"
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
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end,
	}
	return card
end

return OpsTaskingCard
