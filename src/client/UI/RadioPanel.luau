--!strict
-- RadioPanel: the radio subtitle as one compact strip (Layout "subtitle" region: top centre on
-- desktop, under the objective strip on touch, never over the craft): a navy 9-slice bar, the
-- speaker as an orange name chip then the line, with an RX/TX lamp and a signal bar that drops in
-- storms. It clears itself 1.5 s after the line. The log (last lines) unfolds under it while the
-- radio wheel is open.
local AvatarCosmetics = require(
	game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("AvatarCosmetics")
)
local Hud = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
).Hud
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

local NAVY = Color3.fromHex("0A1830")
local LAMP_RX = Color3.fromHex("3EE07A")
local LAMP_TX = Color3.fromHex("FF4D3A")
local LOG_MAX = 8
local LINGER = 1.5 -- s the strip stays after the line ends

local RadioPanel = {}

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

function RadioPanel.new(playerGui: Instance): Panel
	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 18
	Layout.prepare(gui)
	gui.Parent = playerGui
	local region = Layout.region(gui, "subtitle")

	-- the navy 9-slice bar (UiImages Hud.Panel), the region's size: speaker chip, then the line
	local body =
		HudTheme.image("VHF", Hud.Panel, UDim2.fromScale(1, 1), region, HudTheme.Slice.Panel, 0.45)
	body.Visible = false
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(10, 0)
	row.Size = UDim2.new(1, -100, 1, 0)
	row.ClipsDescendants = true
	row.Parent = body
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, 10)
	rowList.Parent = row

	local chip = Instance.new("Frame")
	chip.Name = "SpeakerChip"
	chip.LayoutOrder = 1
	chip.Size = UDim2.fromOffset(0, 28)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = HudTheme.Colors.accent
	chip.Parent = row
	corner(chip, 14)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, 10)
	chipPad.PaddingRight = UDim.new(0, 10)
	chipPad.Parent = chip
	local speaker = HudTheme.outline(
		HudTheme.label("Speaker", "", UDim2.fromScale(0, 1), HudTheme.LabelFont, 16, chip)
	)
	speaker.AutomaticSize = Enum.AutomaticSize.X
	speaker.TextTruncate = Enum.TextTruncate.None
	speaker.RichText = true

	local lamp = Instance.new("Frame")
	lamp.Name = "Lamp"
	lamp.AnchorPoint = Vector2.new(1, 0.5)
	lamp.Position = UDim2.new(1, -14, 0.5, 0)
	lamp.Size = UDim2.fromOffset(12, 12)
	lamp.BackgroundColor3 = LAMP_RX
	lamp.BorderSizePixel = 0
	lamp.Parent = body
	corner(lamp, 6)
	local mode =
		HudTheme.label("Mode", "RX", UDim2.fromOffset(40, 16), HudTheme.LabelFont, 14, body)
	mode.AnchorPoint = Vector2.new(1, 0.5)
	mode.Position = UDim2.new(1, -32, 0.5, 0)
	mode.TextXAlignment = Enum.TextXAlignment.Right
	mode.TextColor3 = HudTheme.Colors.textDim
	-- signal bars
	local bars: { Frame } = {}
	for i = 1, 4 do
		local b = Instance.new("Frame")
		b.AnchorPoint = Vector2.new(1, 1)
		b.Position = UDim2.new(1, -76 - (4 - i) * 6, 0.5, 8)
		b.Size = UDim2.fromOffset(4, 4 + i * 3)
		b.BackgroundColor3 = Color3.new(1, 1, 1)
		b.BorderSizePixel = 0
		b.Parent = body
		bars[i] = b
	end

	local line = HudTheme.outline(
		HudTheme.label("Line", "", UDim2.fromScale(0, 1), HudTheme.BoldFont, 20, row)
	)
	line.LayoutOrder = 2
	line.AutomaticSize = Enum.AutomaticSize.X
	line.TextTruncate = Enum.TextTruncate.None

	-- the radio log, unfolded under the strip while the wheel is open
	local log = Instance.new("Frame")
	log.Name = "Log"
	log.Position = UDim2.new(0, 0, 1, 8)
	log.Size = UDim2.new(1, 0, 0, 190)
	log.BackgroundColor3 = NAVY
	log.BackgroundTransparency = 0.12
	log.BorderSizePixel = 0
	log.Visible = false
	log.Parent = body
	corner(log, 12)
	local logText =
		HudTheme.label("Lines", "", UDim2.new(1, -20, 1, -16), HudTheme.BodyFont, 15, log)
	logText.Position = UDim2.fromOffset(10, 8)
	logText.TextColor3 = HudTheme.Colors.text
	logText.TextWrapped = true
	logText.TextTruncate = Enum.TextTruncate.None
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
					task.delay(LINGER, function()
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
