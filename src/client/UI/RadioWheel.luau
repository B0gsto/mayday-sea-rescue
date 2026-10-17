--!strict
-- RadioWheel: the quick-reply wheel (docs 09 section 3.3), drawn as a VHF handset hub with the
-- replies around it. Pick by pointing (mouse, right stick, thumb) and releasing, by number keys
-- 1-6, or by tapping a card. In Assist the right card glows after a few seconds of hesitation.
local HudTheme = require(script.Parent.HudTheme)

export type WheelOption = { label: string, correct: boolean?, [string]: any }
export type OpenOpts = { title: string?, hint: boolean?, hintAfter: number? }
export type Wheel = {
	open: (options: { WheelOption }, onPick: (WheelOption, number) -> (), opts: OpenOpts?) -> (),
	close: () -> (),
	isOpen: () -> boolean,
	point: (dir: Vector2?) -> (),
	confirm: () -> boolean,
	pick: (index: number) -> (),
	OnClosed: BindableEvent,
}

local CARD_BG = Color3.fromHex("1B1F22")
local CARD_HOT = Color3.fromHex("0E5E6F")
local HINT = Color3.fromHex("3EE07A")

local RadioWheel = {}

function RadioWheel.new(playerGui: Instance): Wheel
	local gui = Instance.new("ScreenGui")
	gui.Name = "RadioWheel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui

	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.55
	shade.BorderSizePixel = 0
	shade.Parent = gui

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromOffset(150, 150)
	hub.BackgroundColor3 = Color3.fromHex("15181A")
	hub.BorderSizePixel = 0
	hub.Parent = gui
	local hubCorner = Instance.new("UICorner")
	hubCorner.CornerRadius = UDim.new(1, 0)
	hubCorner.Parent = hub
	local hubStroke = Instance.new("UIStroke")
	hubStroke.Color = HudTheme.Colors.accent
	hubStroke.Thickness = 3
	hubStroke.Parent = hub
	-- handset grille
	for i = -2, 2 do
		local slot = Instance.new("Frame")
		slot.AnchorPoint = Vector2.new(0.5, 0.5)
		slot.Position = UDim2.new(0.5, 0, 0.32, i * 7)
		slot.Size = UDim2.fromOffset(64 - math.abs(i) * 10, 3)
		slot.BackgroundColor3 = Color3.fromHex("3A4248")
		slot.BorderSizePixel = 0
		slot.Parent = hub
	end
	local ptt = Instance.new("TextLabel")
	ptt.BackgroundTransparency = 1
	ptt.AnchorPoint = Vector2.new(0.5, 0)
	ptt.Position = UDim2.fromScale(0.5, 0.52)
	ptt.Size = UDim2.fromScale(0.86, 0.36)
	ptt.Font = Enum.Font.Code
	ptt.TextColor3 = Color3.fromHex("C8F7D2")
	ptt.TextScaled = true
	ptt.TextWrapped = true
	ptt.Text = "PTT\nCH 16"
	ptt.Parent = hub

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.new(0.5, 0, 0.5, -230)
	title.Size = UDim2.fromOffset(520, 30)
	title.Font = HudTheme.BoldFont
	title.TextSize = 20
	title.TextColor3 = HudTheme.Colors.text
	title.Parent = gui

	local cards: { TextButton } = {}
	local options: { WheelOption } = {}
	local onPickFn: ((WheelOption, number) -> ())? = nil
	local hot: number? = nil
	local isOpen = false
	local serial = 0
	local closed = Instance.new("BindableEvent")

	local wheel: Wheel

	local function paint()
		for i, c in cards do
			c.BackgroundColor3 = if i == hot then CARD_HOT else CARD_BG
			local s = c:FindFirstChildOfClass("UIStroke")
			if s and s:GetAttribute("Hint") ~= true then
				s.Color = if i == hot then HudTheme.Colors.accent else Color3.fromHex("3A4248")
			end
		end
	end

	local function layout()
		local cam = workspace.CurrentCamera
		local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		local small = math.min(vp.X, vp.Y)
		local r = math.clamp(small * 0.3, 120, 220)
		local w = math.clamp(small * 0.36, 170, 270)
		title.Position = UDim2.new(0.5, 0, 0.5, -r - 46)
		local n = #cards
		for i, c in cards do
			local a = -math.pi / 2 + (i - 1) / n * math.pi * 2
			c.Position = UDim2.new(0.5, math.cos(a) * r, 0.5, math.sin(a) * r)
			c.Size = UDim2.fromOffset(w, 66)
		end
	end

	wheel = {
		OnClosed = closed,
		isOpen = function()
			return isOpen
		end,
		open = function(opts: { WheelOption }, onPick: (WheelOption, number) -> (), o: OpenOpts?)
			local oo: OpenOpts = o or {}
			for _, c in cards do
				c:Destroy()
			end
			table.clear(cards)
			options = opts
			onPickFn = onPick
			hot = nil
			serial += 1
			title.Text = oo.title or "Radio · channel 16"
			for i, opt in opts do
				local b = Instance.new("TextButton")
				b.Name = "Option" .. i
				b.AnchorPoint = Vector2.new(0.5, 0.5)
				b.AutoButtonColor = false
				b.BackgroundColor3 = CARD_BG
				b.BorderSizePixel = 0
				b.Font = HudTheme.BoldFont
				b.TextColor3 = HudTheme.Colors.text
				b.TextScaled = true
				b.TextWrapped = true
				b.Text = opt.label
				b.Parent = gui
				local c = Instance.new("UICorner")
				c.CornerRadius = UDim.new(0, 10)
				c.Parent = b
				local s = Instance.new("UIStroke")
				s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				s.Color = Color3.fromHex("3A4248")
				s.Thickness = 2
				s.Parent = b
				local pad = Instance.new("UIPadding")
				pad.PaddingLeft = UDim.new(0, 30)
				pad.PaddingRight = UDim.new(0, 8)
				pad.PaddingTop = UDim.new(0, 6)
				pad.PaddingBottom = UDim.new(0, 6)
				pad.Parent = b
				local lim = Instance.new("UITextSizeConstraint")
				lim.MaxTextSize = 19
				lim.MinTextSize = 12
				lim.Parent = b
				local key = Instance.new("TextLabel")
				key.BackgroundTransparency = 1
				key.Position = UDim2.fromOffset(-24, 0)
				key.Size = UDim2.new(0, 18, 1, 0)
				key.Font = Enum.Font.Code
				key.TextColor3 = HudTheme.Colors.textDim
				key.TextSize = 16
				key.Text = tostring(i)
				key.Parent = b
				b.MouseEnter:Connect(function()
					hot = i
					paint()
				end)
				b.Activated:Connect(function()
					wheel.pick(i)
				end)
				table.insert(cards, b)
			end
			layout()
			gui.Enabled = true
			isOpen = true
			if oo.hint then
				local mine = serial
				task.delay(oo.hintAfter or 5, function()
					if serial ~= mine or not isOpen then
						return
					end
					for i, opt in options do
						local s = cards[i] and cards[i]:FindFirstChildOfClass("UIStroke")
						if opt.correct and s then
							s:SetAttribute("Hint", true)
							s.Color = HINT
							s.Thickness = 4
						end
					end
				end)
			end
		end,
		close = function()
			if not isOpen then
				return
			end
			isOpen = false
			serial += 1
			gui.Enabled = false
			onPickFn = nil
			closed:Fire()
		end,
		point = function(dir: Vector2?)
			if not isOpen or #cards == 0 then
				return
			end
			if not dir or dir.Magnitude < 0.35 then
				return
			end
			-- screen angle: 0 = up, clockwise (the first card sits at the top)
			local a = math.atan2(dir.X, -dir.Y)
			local n = #cards
			local idx = math.floor(((a % (2 * math.pi)) / (2 * math.pi)) * n + 0.5) % n + 1
			if idx ~= hot then
				hot = idx
				paint()
			end
		end,
		confirm = function(): boolean
			if isOpen and hot then
				wheel.pick(hot)
				return true
			end
			return false
		end,
		pick = function(index: number)
			local opt = options[index]
			local fn = onPickFn
			if not isOpen or not opt or not fn then
				return
			end
			wheel.close()
			task.spawn(fn, opt, index)
		end,
	}
	return wheel
end

return RadioWheel
