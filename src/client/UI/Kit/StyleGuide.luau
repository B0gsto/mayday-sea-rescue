--!strict
-- StyleGuide (Studio dev tool): every Kit piece on three fake devices side by side, desktop
-- 1280x720, phone portrait 390x844 and phone landscape 844x390, each with its own Theme scale.
-- Pages: "shop" (left bar, Shop panel with tabs + pass / pack / owned / locked cards, counters,
-- a toast), "settings" (a settings panel of toggles), "dialog" (NPC talk with 3 replies).
--   StyleGuide.show("shop") / StyleGuide.show(nil) hides. Hook: Controllers/KitStyleGuide.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Kit = script.Parent
local Card = require(Kit:WaitForChild("Card"))
local Counter = require(Kit:WaitForChild("Counter"))
local Dialog = require(Kit:WaitForChild("Dialog"))
local IconButton = require(Kit:WaitForChild("IconButton"))
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Tabs = require(Kit:WaitForChild("Tabs"))
local Theme = require(Kit:WaitForChild("Theme"))
local Toast = require(Kit:WaitForChild("Toast"))
local Toggle = require(Kit:WaitForChild("Toggle"))
local UiImages = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("Shared")
		:WaitForChild("Config")
		:WaitForChild("UiImages")
) :: any

local S = Theme.Size

local StyleGuide = {}

local DEVICES = {
	{ name = "Desktop 1280x720", size = Vector2.new(1280, 720) },
	{ name = "Phone 390x844", size = Vector2.new(390, 844) },
	{ name = "Phone 844x390", size = Vector2.new(844, 390) },
}
local GAP = 40
local LABEL = 44

local BAR = {
	{ "shop", "Shop", "yellow" },
	{ "quests", "Quests", "orange" },
	{ "album", "Album", "pink" },
	{ "companion", "Buddy", "purple" },
	{ "crew", "Crew", "teal" },
	{ "settings", "Settings", "blue" },
}

local function iconBar(canvas: Frame, vp: Vector2, scale: number)
	local cols = Theme.iconColumns(vp, scale, #BAR)
	local rows = math.ceil(#BAR / cols)
	local cell = Vector2.new(S.icon + 18, S.icon + S.iconLabel + 8)
	local bar = Instance.new("Frame")
	bar.Name = "IconBar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.new(0, S.margin, 0.5, 0)
	bar.Size = UDim2.fromOffset(cols * cell.X, rows * cell.Y)
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	grid.CellPadding = UDim2.new()
	grid.FillDirectionMaxCells = cols
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = bar
	for i, b in BAR do
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.LayoutOrder = i
		slot.Parent = bar
		local btn = IconButton.new(slot, { icon = b[1], label = b[2], color = b[3] })
		btn.root.AnchorPoint = Vector2.new(0.5, 0)
		btn.root.Position = UDim2.fromScale(0.5, 0)
		if b[1] == "quests" then
			btn.setBadge(3)
		elseif b[1] == "album" then
			btn.setBadge(true)
		end
	end
	bar.Parent = canvas
	-- the one world action sits alone on the right edge, not in the menu grid
	local boat =
		IconButton.new(canvas, { icon = "boat_to_me", label = "Boat to me", color = "green" })
	boat.root.AnchorPoint = Vector2.new(1, 0.5)
	boat.root.Position = UDim2.new(1, -S.margin - 12, 0.5, 0)
end

local function counters(canvas: Frame)
	local box = Instance.new("Frame")
	box.Name = "Counters"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0, 1)
	box.Position = UDim2.new(0, S.margin + 10, 1, -S.margin)
	box.Size = UDim2.fromOffset(S.counter.X, S.counter.Y * 2 + 10)
	local l = Style.list(box, false, 10)
	l.VerticalAlignment = Enum.VerticalAlignment.Bottom
	Counter.new(box, { kind = "rank", value = 12 })
	Counter.new(box, { kind = "cash", value = 12450 }).root.LayoutOrder = 1
	box.Parent = canvas
end

local function shop(canvas: Frame)
	local p = Panel.new(canvas, { title = "Shop", icon = "shop", tabs = true })
	Tabs.new(p.top, {
		{ name = "Passes", icon = "vip" },
		{ name = "Packs", icon = "gift" },
		{ name = "Boosts", icon = "boost" },
	})
	Card.new(p.body, {
		art = "vip",
		title = "VIP",
		line = "Double cash forever",
		color = "purple",
		price = 399,
	})
	Card.new(
		p.body,
		{ art = "cash", title = "Cash Pack", line = "A big bag", color = "yellow", price = 99 }
	)
	Card.new(p.body, {
		art = "boost",
		title = "2x Speed",
		line = "Zoom for 1 hour",
		color = "pink",
		price = 49,
		state = "owned",
	})
	Card.new(p.body, {
		art = "build",
		title = "Gold Dock",
		line = "Rank 20",
		color = "orange",
		price = 25000,
		currency = "Cash",
		state = "locked",
	})
	p.open()
end

local SETTINGS = {
	{ art = "note", name = "Music", on = true },
	{ art = "horn", name = "Sounds", on = true },
	{ art = "shake", name = "Shake", on = false },
	{ art = "waves", name = "Waves", on = true },
}

local function settings(canvas: Frame)
	local p =
		Panel.new(canvas, { title = "Settings", icon = "settings", size = Vector2.new(580, 520) })
	for i, row in SETTINGS do
		local r = Instance.new("Frame")
		r.BackgroundTransparency = 1
		r.Size = UDim2.new(1, 0, 0, 86)
		r.LayoutOrder = i
		local _, face = Style.block(r, Style.grad("blue"), { lip = 6 })
		local well = Instance.new("Frame")
		well.AnchorPoint = Vector2.new(0, 0.5)
		well.Position = UDim2.new(0, 10, 0.5, 0)
		well.Size = UDim2.fromOffset(58, 58)
		well.BackgroundColor3 = Theme.Grad.ink.top
		Style.corner(well, S.cornerSmall)
		Style.stroke(well, 3, true)
		well.Parent = face
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = (UiImages.SettingsArt :: any)[row.art] or ""
		img.Size = UDim2.fromScale(0.8, 0.8)
		img.Position = UDim2.fromScale(0.1, 0.1)
		img.Parent = well
		local t = Style.label(face, row.name, Theme.Text.heading)
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.Position = UDim2.fromOffset(84, 0)
		t.Size = UDim2.new(1, -200, 1, 0)
		local tg = Toggle.new(face, { on = row.on })
		tg.root.AnchorPoint = Vector2.new(1, 0.5)
		tg.root.Position = UDim2.new(1, -12, 0.5, 0)
		r.Parent = p.body
	end
	p.open()
end

local function dialog(canvas: Frame)
	Dialog.new(canvas, {
		name = "Harbour Master",
		portrait = "crew",
		line = "Storm's coming. Help?",
		replies = { "On my way!", "Need a boat", "Later" },
	})
	Toast.show(canvas, "+250", { icon = "cash", color = "green", duration = 0 })
end

local PAGES: { [string]: (Frame) -> () } = { shop = shop, settings = settings, dialog = dialog }

local function device(parent: Instance, d: { name: string, size: Vector2 }, page: string, x: number)
	local frame = Instance.new("Frame")
	frame.Name = d.name
	frame.Position = UDim2.fromOffset(x, LABEL)
	frame.Size = UDim2.fromOffset(d.size.X, d.size.Y)
	frame.ClipsDescendants = true
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	local sky = Instance.new("UIGradient")
	sky.Rotation = 90
	sky.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromHex("8FD3F5")),
		ColorSequenceKeypoint.new(0.46, Color3.fromHex("CDEBF7")),
		ColorSequenceKeypoint.new(0.47, Color3.fromHex("2F8FC4")),
		ColorSequenceKeypoint.new(1, Color3.fromHex("135C8C")),
	})
	sky.Parent = frame
	frame.Parent = parent
	local tag = Instance.new("TextLabel")
	tag.BackgroundTransparency = 1
	tag.Font = Enum.Font.BuilderSansBold
	tag.TextSize = 30
	tag.TextColor3 = Color3.fromHex("9FB3C8")
	tag.Text = d.name
	tag.TextXAlignment = Enum.TextXAlignment.Left
	tag.Position = UDim2.fromOffset(x, 0)
	tag.Size = UDim2.fromOffset(d.size.X, LABEL - 6)
	tag.Parent = parent

	local canvas = Style.canvas(frame, d.size)
	local scale = Theme.scaleFor(d.size)
	if page ~= "dialog" then -- talk hides the bar (camera zooms on the NPC)
		iconBar(canvas, d.size, scale)
	end
	if page ~= "dialog" then
		counters(canvas)
	end
	PAGES[page](canvas)
end

function StyleGuide.show(page: string?)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("KitStyleGuide")
	if old then
		old:Destroy()
	end
	if not page or not PAGES[page] then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "KitStyleGuide"
	gui.DisplayOrder = 10000
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local back = Instance.new("Frame")
	back.BackgroundColor3 = Theme.Colors.backdrop
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = gui

	local total = Vector2.new(-GAP, 0)
	for _, d in DEVICES do
		total = Vector2.new(total.X + d.size.X + GAP, math.max(total.Y, d.size.Y + LABEL))
	end
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Size = UDim2.fromOffset(total.X, total.Y)
	local fit = Instance.new("UIScale")
	fit.Parent = holder
	holder.Parent = back
	local function place()
		-- the capture keeps a centred 16:9 crop below the top 8% (tools/studio/smoke.py shot --full)
		local vp = (Workspace.CurrentCamera :: Camera).ViewportSize
		local h = vp.Y * 0.92
		local w = math.min(vp.X, h * 16 / 9)
		fit.Scale = math.min(w * 0.97 / total.X, h * 0.95 / total.Y)
		holder.Position = UDim2.fromScale(0.5, 0.54)
	end
	place()
	local x = 0
	for _, d in DEVICES do
		device(holder, d, page, x)
		x += d.size.X + GAP
	end
	gui.Parent = pg
end

return StyleGuide
