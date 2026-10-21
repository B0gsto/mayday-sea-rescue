--!strict
-- RadioPanel: the boat's VHF set as the subtitle display (diegetic, Layout "subtitle" region,
-- bottom centre between the minimap and the gauges). Always on:
-- every transmission shows the speaker's callsign and the text, with an RX/TX lamp, the channel
-- and a signal bar that drops in storms. The log (last lines) unfolds while the radio wheel is open.
local AvatarCosmetics = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AvatarCosmetics")
)
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)
local RadioFormat = require(script.Parent.RadioFormat)

export type Panel = {
	gui: ScreenGui,
	show: (speaker: string, text: string, mode: string, seconds: number) -> (),
	hide: () -> (),
	setLog: (visible: boolean) -> (),
	setSignal: (fraction: number) -> (),
}

local LCD_BG = Color3.fromHex("0B1D14")
local LCD_TEXT = Color3.fromHex("C8F7D2")
local LCD_DIM = Color3.fromHex("5E8A6B")
local BODY = Color3.fromHex("1B1F22")
local LAMP_RX = Color3.fromHex("3EE07A")
local LAMP_TX = Color3.fromHex("FF4D3A")
local LOG_MAX = 8

local RadioPanel = {}

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function text(
	parent: Instance,
	name: string,
	font: Enum.Font,
	size: number,
	color: Color3
): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = font
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Top
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

function RadioPanel.new(playerGui: Instance): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18
	Layout.prepare(gui)
	gui.Parent = playerGui
	local region = Layout.region(gui, "subtitle")

	-- the set: a rugged body with a recessed LCD
	local body = Instance.new("Frame")
	body.Name = "VHF"
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(1, 1)
	body.BackgroundColor3 = BODY
	body.BackgroundTransparency = 0.15
	body.BorderSizePixel = 0
	body.Visible = false
	body.Parent = region
	corner(body, 8)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromHex("3A4248")
	stroke.Thickness = 2
	stroke.Parent = body
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(Color3.fromHex("2A3034"), Color3.fromHex("15181A"))
	grad.Rotation = 90
	grad.Parent = body

	local lcd = Instance.new("Frame")
	lcd.Name = "LCD"
	lcd.Position = UDim2.fromOffset(10, 10)
	lcd.Size = UDim2.new(1, -20, 1, -20)
	lcd.BackgroundColor3 = LCD_BG
	lcd.BorderSizePixel = 0
	lcd.Parent = body
	corner(lcd, 6)
	local lcdStroke = Instance.new("UIStroke")
	lcdStroke.Color = Color3.fromHex("05100A")
	lcdStroke.Thickness = 3
	lcdStroke.Parent = lcd

	local header = text(lcd, "Header", Enum.Font.Code, 14, LCD_DIM)
	header.Position = UDim2.fromOffset(10, 6)
	header.Size = UDim2.new(1, -90, 0, 16)
	header.Text = "📻"
	local lamp = Instance.new("Frame")
	lamp.Name = "Lamp"
	lamp.AnchorPoint = Vector2.new(1, 0)
	lamp.Position = UDim2.new(1, -10, 0, 8)
	lamp.Size = UDim2.fromOffset(12, 12)
	lamp.BackgroundColor3 = LAMP_RX
	lamp.BorderSizePixel = 0
	lamp.Parent = lcd
	corner(lamp, 6)
	local mode = text(lcd, "Mode", Enum.Font.Code, 14, LCD_TEXT)
	mode.AnchorPoint = Vector2.new(1, 0)
	mode.Position = UDim2.new(1, -28, 0, 6)
	mode.Size = UDim2.fromOffset(30, 16)
	mode.TextXAlignment = Enum.TextXAlignment.Right
	mode.Text = "RX"
	-- signal bars
	local bars: { Frame } = {}
	for i = 1, 4 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -66 - (4 - i) * 6, 0, 22)
		b.Size = UDim2.fromOffset(4, 4 + i * 3)
		b.BackgroundColor3 = LCD_TEXT
		b.BorderSizePixel = 0
		b.Parent = lcd
		bars[i] = b
	end

	local speaker = text(lcd, "Speaker", HudTheme.BoldFont, 18, HudTheme.Colors.accent)
	speaker.Position = UDim2.fromOffset(10, 24)
	speaker.Size = UDim2.new(1, -20, 0, 20)
	speaker.TextTruncate = Enum.TextTruncate.AtEnd
	speaker.TextWrapped = false
	speaker.RichText = true
	local line = text(lcd, "Line", HudTheme.BodyFont, 18, LCD_TEXT)
	line.Position = UDim2.fromOffset(10, 46)
	line.Size = UDim2.new(1, -20, 1, -50)
	line.TextScaled = true
	line.TextWrapped = false
	line.TextTruncate = Enum.TextTruncate.AtEnd
	local limit = Instance.new("UITextSizeConstraint")
	limit.Parent = line
	local function applyTextScale()
		limit.MaxTextSize = HudTheme.scaled(19)
		limit.MinTextSize = HudTheme.scaled(13)
	end
	Layout.onTextScale(applyTextScale)
	applyTextScale()

	-- the radio log, unfolded above the set while the wheel is open
	local log = Instance.new("Frame")
	log.Name = "Log"
	log.AnchorPoint = Vector2.new(0, 1)
	log.Position = UDim2.fromOffset(0, -8)
	log.Size = UDim2.new(1, 0, 0, 190)
	log.BackgroundColor3 = LCD_BG
	log.BackgroundTransparency = 0.08
	log.BorderSizePixel = 0
	log.Visible = false
	log.Parent = body
	corner(log, 8)
	local logText = text(log, "Lines", HudTheme.BodyFont, 15, LCD_TEXT)
	logText.Position = UDim2.fromOffset(10, 8)
	logText.Size = UDim2.new(1, -20, 1, -16)
	logText.RichText = true
	logText.TextYAlignment = Enum.TextYAlignment.Bottom

	local entries: { string } = {}
	local serial = 0
	local logOpen = false

	local function escape(s: string): string
		return (string.gsub(string.gsub(string.gsub(s, "&", "&amp;"), "<", "&lt;"), ">", "&gt;"))
	end

	local panel: Panel
	panel = {
		gui = gui,
		show = function(who: string, msg: string, m: string, seconds: number)
			serial += 1
			local mine = serial
			-- RP-M5 E2: the VIP Crew Card's gold "VIP" tag beside the player's own callsign (Badge slot)
			local tag = if m == "tx"
				then AvatarCosmetics.radioTag(
					game:GetService("Players").LocalPlayer:GetAttribute("Cos_Badge") :: any
				)
				else nil
			local gold = `<font color="#{HudTheme.Colors.gold:ToHex()}"><b>{tag or ""}</b></font>`
			-- the speaker's name without the station ("Chief Aggie · Port Haven")
			local name = escape(string.match(who, "^(.-) · ") or who)
			speaker.Text = if tag then `🎙 {name}  {gold}` else `🎙 {name}`
			-- at a glance: three words; the whole line is in the log
			line.Text = RadioFormat.caption(msg, 3)
			local tx = m == "tx"
			mode.Text = if tx then "TX" elseif m == "intercom" then "ICM" else "RX"
			lamp.BackgroundColor3 = if tx then LAMP_TX else LAMP_RX
			lamp.BackgroundTransparency = 0
			body.Visible = true
			table.insert(
				entries,
				`<font color="#D9682E"><b>{escape(who)}</b></font>{if tag then " " .. gold else ""}  {escape(
					msg
				)}`
			)
			while #entries > LOG_MAX do
				table.remove(entries, 1)
			end
			logText.Text = table.concat(entries, "\n")
			task.delay(seconds, function()
				if serial == mine then
					lamp.BackgroundTransparency = 0.8
					mode.Text = "--"
					task.delay(4, function()
						if serial == mine and not logOpen then
							body.Visible = false
						end
					end)
				end
			end)
		end,
		hide = function()
			serial += 1
			if not logOpen then
				body.Visible = false
			end
		end,
		setLog = function(visible: boolean)
			logOpen = visible
			log.Visible = visible and #entries > 0
			if visible then
				body.Visible = true
				if speaker.Text == "" then
					speaker.Text = "🎙 Gale Isles Coastguard"
					line.Text = "Listening"
				end
			end
		end,
		setSignal = function(fraction: number)
			for i, b in bars do
				b.BackgroundTransparency = if fraction >= i / 4 - 0.01 then 0 else 0.85
			end
		end,
	}
	return panel
end

return RadioPanel
