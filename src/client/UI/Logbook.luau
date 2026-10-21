--!strict
-- Logbook: the exploration logbook panel, its discovery notice and the On watch / Off duty switch
-- (docs 10 sections 5.1 and 5.2). Built by ExplorationController; data from Shared.Explore.Discovery.
--
--   panel    centred, 600 x 420 du (fits the 1071 x 471 du phone area): header with the count and
--            Cash earned, the duty switch, page tabs on the left and the page's entries on the
--            right (found: name, era, story line; unfound: where to look). Shown in the phone's
--            Logbook app (J, gamepad L3 or the icon); closes with X or gamepad B. Gamepad selection starts on the first page tab.
--   notice   a short "Logged" card in the Layout "notice" region for 6 s after each discovery.
--
-- CONTRACT (radio panel owner): docs 10 puts the logbook on a radio panel tab and the duty switch on
-- the radio panel; ExplorationController.Open() / SetOffDuty() are the hooks for that.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Discovery = require(Shared:WaitForChild("Explore"):WaitForChild("Discovery"))
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)

local C = HudTheme.Colors
local WIDTH, HEIGHT = 600, 420
local TAB_WIDTH = 196
local NOTICE_TIME = 6

export type Logbook = {
	gui: ScreenGui,
	setOpen: (open: boolean) -> (),
	isOpen: () -> boolean,
	update: (found: { [string]: boolean }, offDuty: boolean) -> (),
	notify: (id: string, cash: number, pages: { string }) -> (),
}

local Logbook = {}

local HINTS: { [string]: string } = {
	water = "Seabed · dive",
	foot = "On shore",
	any = "Foot or boat",
}

local function text(
	name: string,
	parent: Instance,
	str: string,
	size: number,
	color: Color3?
): TextLabel
	local l =
		HudTheme.label(name, str, UDim2.new(1, 0, 0, size + 6), HudTheme.BodyFont, size, parent)
	l.TextColor3 = color or C.text
	return l
end

local function segment(name: string, parent: Instance, str: string, x: number): TextButton
	local b = HudTheme.button(name, str, UDim2.fromOffset(150, HudTheme.MinButtonHeight), parent)
	b.Position = UDim2.fromOffset(x, 0)
	b.TextSize = 17
	return b
end

function Logbook.build(onDuty: (offDuty: boolean) -> ()): Logbook
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "LogbookHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")

	local foundSet: { [string]: boolean } = {}
	local isOff = false
	local open = false
	local pageId = Discovery.Pages[1].id

	-- ------------------------------------------------------------ the panel
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	Layout.onMetrics(function(mt)
		scale.Scale = mt.scale
	end)

	local panel = HudTheme.panel("Logbook", UDim2.fromScale(1, 1), holder)
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 16)

	local title = HudTheme.label(
		"Title",
		"LOGBOOK",
		UDim2.new(1, -60, 0, 28),
		HudTheme.HeaderFont,
		HudTheme.TextSize.title + 1,
		panel
	)
	title.TextColor3 = C.text
	local summary = text("Summary", panel, "", HudTheme.TextSize.small, C.textDim)
	summary.Position = UDim2.fromOffset(0, 30)

	local close = HudTheme.button("Close", "X", UDim2.fromOffset(48, 40), panel)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.BackgroundColor3 = C.panelLight
	close.Modal = true -- show, free the mouse in first person

	-- the duty switch
	local duty = Instance.new("Frame")
	duty.Name = "Duty"
	duty.BackgroundTransparency = 1
	duty.Position = UDim2.fromOffset(0, 64)
	duty.Size = UDim2.new(1, 0, 0, HudTheme.MinButtonHeight)
	duty.Parent = panel
	local onBtn = segment("OnWatch", duty, "ON WATCH", 0)
	local offBtn = segment("OffDuty", duty, "OFF DUTY", 156)
	local dutyNote = HudTheme.label(
		"Note",
		"",
		UDim2.new(1, -318, 1, 0),
		HudTheme.BodyFont,
		HudTheme.TextSize.small,
		duty
	)
	dutyNote.Position = UDim2.fromOffset(318, 0)
	dutyNote.TextColor3 = C.textDim
	dutyNote.TextWrapped = true
	dutyNote.TextTruncate = Enum.TextTruncate.None

	-- body: page tabs | entries
	local bodyTop = 64 + HudTheme.MinButtonHeight + 12
	local tabs = Instance.new("ScrollingFrame")
	tabs.Name = "Pages"
	tabs.BackgroundTransparency = 1
	tabs.BorderSizePixel = 0
	tabs.Position = UDim2.fromOffset(0, bodyTop)
	tabs.Size = UDim2.new(0, TAB_WIDTH, 1, -bodyTop)
	tabs.ScrollBarThickness = 4
	tabs.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabs.CanvasSize = UDim2.new()
	tabs.Parent = panel
	local tabList = Instance.new("UIListLayout")
	tabList.Padding = UDim.new(0, 6)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs

	local list = Instance.new("ScrollingFrame")
	list.Name = "Entries"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(TAB_WIDTH + 14, bodyTop)
	list.Size = UDim2.new(1, -(TAB_WIDTH + 14), 1, -bodyTop)
	list.ScrollBarThickness = 4
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local entryList = Instance.new("UIListLayout")
	entryList.Padding = UDim.new(0, 8)
	entryList.SortOrder = Enum.SortOrder.LayoutOrder
	entryList.Parent = list

	local tabButtons: { [string]: TextButton } = {}
	local render: () -> ()

	for i, p in Discovery.Pages do
		local b = HudTheme.button(`Tab_{p.id}`, "", UDim2.new(1, -6, 0, 46), tabs)
		b.LayoutOrder = i
		b.TextXAlignment = Enum.TextXAlignment.Left
		b.Font = HudTheme.BodyFont
		b.TextSize = HudTheme.TextSize.small
		b.TextWrapped = false
		b.TextTruncate = Enum.TextTruncate.AtEnd
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 10)
		pad.PaddingRight = UDim.new(0, 8)
		pad.Parent = b
		b.Activated:Connect(function()
			pageId = p.id
			render()
		end)
		tabButtons[p.id] = b
	end

	local function entryRow(e: Discovery.Entry, order: number)
		local row = Instance.new("Frame")
		row.Name = e.id
		row.LayoutOrder = order
		row.BackgroundColor3 = C.panelLight
		row.BackgroundTransparency = 0.45
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, -8, 0, 0)
		row.AutomaticSize = Enum.AutomaticSize.Y
		HudTheme.corner(row, 4)
		HudTheme.padding(row, 10)
		local rl = Instance.new("UIListLayout")
		rl.Padding = UDim.new(0, 2)
		rl.SortOrder = Enum.SortOrder.LayoutOrder
		rl.Parent = row
		local got = foundSet[e.id] == true
		local head =
			text("Name", row, "", HudTheme.TextSize.body, if got then C.text else C.textDim)
		head.LayoutOrder = 1
		head.Font = HudTheme.BoldFont
		local line = text("Line", row, "", HudTheme.TextSize.small, C.textDim)
		line.LayoutOrder = 2
		line.TextWrapped = true
		line.TextTruncate = Enum.TextTruncate.None
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.Size = UDim2.fromScale(1, 0)
		if got then
			head.Text = if e.era ~= "" then `{e.name}  ·  {e.era}` else e.name
			line.Text = e.blurb
			local paid =
				text("Paid", row, `Logged  ·  {HudTheme.formatNumber(e.reward)} Cash`, 15, C.gold)
			paid.LayoutOrder = 3
		else
			head.Text = "Not yet logged"
			line.Text = HINTS[e.mode] or HINTS.any
		end
		row.Parent = list
	end

	render = function()
		local total, have, cash = #Discovery.Entries, 0, 0
		for _, e in Discovery.Entries do
			if foundSet[e.id] then
				have += 1
				cash += e.reward
			end
		end
		summary.Text = `{have}/{total}  ·  {HudTheme.formatNumber(cash)} Cash`
		for _, p in Discovery.Pages do
			local got, configured, target = Discovery.pageProgress(foundSet, p.id)
			local b = tabButtons[p.id]
			b.Text = `{p.title}   {got}/{target}`
			local selected = p.id == pageId
			b.BackgroundColor3 = if selected then C.accent else C.panelLight
			b.TextColor3 = if configured > 0 or selected then C.text else C.textDim
		end
		for _, child in list:GetChildren() do
			if child:IsA("Frame") or child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local order = 0
		for _, e in Discovery.Entries do
			if e.page == pageId then
				order += 1
				entryRow(e, order)
			end
		end
		local p = Discovery.page(pageId)
		local got, configured, target = Discovery.pageProgress(foundSet, pageId)
		local foot = text("Footer", list, "", HudTheme.TextSize.small, C.textDim)
		foot.LayoutOrder = order + 1
		foot.TextWrapped = true
		foot.TextTruncate = Enum.TextTruncate.None
		foot.Size = UDim2.new(1, -8, 0, 44)
		if configured == 0 then
			foot.Text = "Soon"
		elseif got >= target then
			foot.Text = "Complete ✓"
		elseif p then
			local prize = if p.cosmetic then ` + {p.cosmetic}` else ""
			foot.Text = `{target}/{target}: {HudTheme.formatNumber(p.reward)} Cash{prize}`
		end
		-- the duty switch
		onBtn.BackgroundColor3 = if isOff then C.panelLight else C.accent
		offBtn.BackgroundColor3 = if isOff then C.accent else C.panelLight
		dutyNote.Text = if isOff then "Big calls only" else "Radio taskings"
	end

	onBtn.Activated:Connect(function()
		if isOff then
			isOff = false
			render()
			onDuty(false)
		end
	end)
	offBtn.Activated:Connect(function()
		if not isOff then
			isOff = true
			render()
			onDuty(true)
		end
	end)

	local function setOpen(v: boolean)
		if open == v then
			return
		end
		open = v
		holder.Visible = v
		if v then
			render()
			if UserInputService.GamepadEnabled then
				GuiService.SelectedObject = tabButtons[pageId]
			end
		elseif GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end
	close.Activated:Connect(function()
		setOpen(false)
	end)

	-- ------------------------------------------------------------ discovery notice
	local noticeRegion = Layout.region(gui, "notice")
	local card = HudTheme.panel("Logged", UDim2.fromOffset(400, 70), noticeRegion)
	card.AnchorPoint = Vector2.new(0.5, 0)
	card.Position = UDim2.fromScale(0.5, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.Visible = false
	HudTheme.padding(card, 12)
	local cl = Instance.new("UIListLayout")
	cl.Padding = UDim.new(0, 2)
	cl.SortOrder = Enum.SortOrder.LayoutOrder
	cl.Parent = card
	local kicker = text("Kicker", card, "LOGBOOK", 15, C.textDim)
	kicker.Font = HudTheme.HeaderFont
	kicker.LayoutOrder = 1
	local cardName = text("Name", card, "", HudTheme.TextSize.body)
	cardName.Font = HudTheme.BoldFont
	cardName.LayoutOrder = 2
	local cardPay = text("Pay", card, "", HudTheme.TextSize.small, C.gold)
	cardPay.LayoutOrder = 3
	cardPay.TextWrapped = true
	cardPay.TextTruncate = Enum.TextTruncate.None
	cardPay.AutomaticSize = Enum.AutomaticSize.Y
	cardPay.Size = UDim2.fromScale(1, 0)
	local noticeSerial = 0

	local function notify(id: string, cash: number, pages: { string })
		local e = Discovery.get(id)
		if not e then
			return
		end
		noticeSerial += 1
		local serial = noticeSerial
		cardName.Text = if e.era ~= "" then `{e.name}  ·  {e.era}` else e.name
		local pay = `+{HudTheme.formatNumber(cash)} Cash`
		for _, pid in pages do
			local p = Discovery.page(pid)
			if p then
				pay ..= `  ·  Page complete: {p.title}` .. (if p.cosmetic
					then ` (+ {p.cosmetic})`
					else "")
			end
		end
		cardPay.Text = pay .. "  ·  J Logbook"
		if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
			cardPay.Text = pay
		end
		card.Visible = true
		card.BackgroundTransparency = 1
		TweenService
			:Create(
				card,
				TweenInfo.new(0.35),
				{ BackgroundTransparency = HudTheme.PanelTransparency }
			)
			:Play()
		task.delay(NOTICE_TIME, function()
			if serial == noticeSerial then
				card.Visible = false
			end
		end)
		if open then
			render()
		end
	end

	return {
		gui = gui,
		setOpen = setOpen,
		isOpen = function()
			return open
		end,
		update = function(found: { [string]: boolean }, offDuty: boolean)
			foundSet = found
			isOff = offDuty
			if open then
				render()
			end
		end,
		notify = notify,
	}
end

return Logbook
