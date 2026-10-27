--!strict
-- Album panel: one card per discovery page. A page shows its found stickers; tapping a card opens
-- a larger page so a small sticker can be read. State comes from DiscoveryController.
-- Below the pages, the Specials (docs/25 E): one card per WorkerRules.SPECIALS, a grey silhouette until you
-- have them, then their name in their rarity colour, type icon and what makes them special; tapping one
-- opens the survivor card. Owned = in your saved workers (the PlayerDataChanged snapshot, as the Crew panel).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DiscoveryController = require(
	script.Parent.Parent.Parent:WaitForChild("Controllers"):WaitForChild("DiscoveryController")
)
local Net = require(Shared:WaitForChild("Net"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Rules = require(Shared:WaitForChild("DiscoveryRules"))
local WorkerRules = require(Shared:WaitForChild("WorkerRules"))
local UI = script.Parent.Parent
local Portrait = require(UI:WaitForChild("Portrait"))
local Sticker = require(UI:WaitForChild("Sticker"))
local SurvivorCard = require(UI:WaitForChild("SurvivorCard"))
local SurvivorTag = require(UI:WaitForChild("SurvivorTag"))
local WorkerBadge = require(UI:WaitForChild("WorkerBadge"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local S = Theme.Size
local Album = {}

-- what makes each special special (docs/25 E), as a 1-3 word label
local PERK = {
	Brickbeard = "3 stacks",
	BigLou = "Refill x2",
	CaptainMarlow = "Trips x2",
	DrCoral = "Rarity up",
	Bolt = "Works offline",
	Pearl = "Golden fish",
	Nova = "Counts x5",
	OldBones = "Night salvage",
}
local SPECIAL_W, SPECIAL_H = 160, 196
local GREY = Color3.fromHex("8A8F99")

-- a grey person shape (head + shoulders) with a "?" for a special not found yet
local function silhouette(parent: Instance)
	local head = Instance.new("Frame")
	head.BackgroundColor3 = GREY
	head.AnchorPoint = Vector2.new(0.5, 0)
	head.Position = UDim2.fromScale(0.5, 0.04)
	head.Size = UDim2.fromScale(0.42, 0.42)
	Style.corner(head, 999)
	head.Parent = parent
	local body = Instance.new("Frame")
	body.BackgroundColor3 = GREY
	body.AnchorPoint = Vector2.new(0.5, 1)
	body.Position = UDim2.fromScale(0.5, 1)
	body.Size = UDim2.fromScale(0.8, 0.46)
	Style.corner(body, 26)
	body.Parent = parent
	local q = Style.label(parent, "?", Theme.Text.title)
	q.Name = "Unknown"
	q.ZIndex = 2
end

local function fullPage(state: Rules.State, id: string): boolean
	return Rules.complete(state, id)
end

function Album.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Album",
		icon = "album",
		size = Vector2.new(800, 600),
		onClose = onClose,
	})
	local preview: GuiObject? = nil
	local stopPortraits = function() end
	local workers: { WorkerRules.Worker } = {}
	local buildings: { [string]: boolean } = {}
	-- the survivor card over the panel (Sibling ZIndex: the holder lifts the whole card above the list)
	local cardHost = Instance.new("Frame")
	cardHost.Name = "SpecialCard"
	cardHost.BackgroundTransparency = 1
	cardHost.Size = UDim2.fromScale(1, 1)
	cardHost.ZIndex = 8
	cardHost.Parent = panel.root
	local survivorCard = SurvivorCard.new(cardHost)

	local function closePreview()
		if preview then
			local old = preview
			preview = nil
			old:Destroy()
		end
	end

	local function showPage(page: Rules.Page)
		closePreview()
		local shade = Instance.new("TextButton")
		shade.Name = "StickerPreview"
		shade.Text = ""
		shade.AutoButtonColor = false
		shade.BackgroundColor3 = Theme.Colors.shadow
		shade.BackgroundTransparency = 0.35
		shade.Size = UDim2.fromScale(1, 1)
		shade.ZIndex = 8
		shade.Parent = panel.root
		preview = shade
		shade.Activated:Connect(closePreview)

		local card = Instance.new("Frame")
		card.BackgroundTransparency = 1
		card.AnchorPoint = Vector2.new(0.5, 0.5)
		card.Position = UDim2.fromScale(0.5, 0.5)
		card.Size = UDim2.fromOffset(620, 400)
		card.ZIndex = 9
		card.Parent = shade
		local _, face = Style.block(card, Style.grad("blue"), { shadow = true, lip = 10 })
		local title = Style.label(face, page.name, Theme.Text.title)
		title.Position = UDim2.fromOffset(24, 8)
		title.Size = UDim2.new(1, -48, 0, 54)
		title.ZIndex = 10
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.AnchorPoint = Vector2.new(0.5, 0.5)
		row.Position = UDim2.fromScale(0.5, 0.56)
		row.Size = UDim2.new(1, -40, 1, -100)
		row.ZIndex = 10
		row.Parent = face
		local list = Style.list(row, true, 18)
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		for _, s in page.stickers do
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(160, 210)
			cell.ZIndex = 10
			cell.Parent = row
			Sticker.draw(
				cell,
				page.id,
				s.id,
				Rules.has(DiscoveryController.State(), page.id, s.bit)
			)
			local name =
				Style.label(cell, if s.id == "Stamp" then page.name else s.id, Theme.Text.small)
			name.Position = UDim2.new(0, 0, 1, -42)
			name.Size = UDim2.new(1, 0, 0, 34)
			name.ZIndex = 10
		end
		local close = Style.button(face, UDim2.fromOffset(S.close, S.close + S.lip))
		close.AnchorPoint = Vector2.new(1, 0)
		close.Position = UDim2.new(1, -12, 0, 12)
		close.ZIndex = 11
		local _, xFace = Style.block(close, Style.grad("close"))
		Style.label(xFace, "X", Theme.Text.title).ZIndex = 12
		Style.press(close, closePreview)
	end

	local function rebuild()
		stopPortraits()
		closePreview()
		for _, c in panel.body:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local state = DiscoveryController.State()
		local host = Instance.new("Frame")
		host.Name = "Pages"
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 0)
		host.AutomaticSize = Enum.AutomaticSize.Y
		host.Parent = panel.body
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(188, 210)
		grid.CellPadding = UDim2.fromOffset(14, 14)
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = host
		for order, page in Rules.Pages do
			local found, total = Rules.count(state, page.id)
			local complete = fullPage(state, page.id)
			local card = Style.button(host, UDim2.fromOffset(188, 210))
			card.Name = "Page_" .. page.id
			card.LayoutOrder = order
			-- dark card + a light round well: a found stamp shows in full colour, a missing one as a
			-- solid dark silhouette (audit 2026-10-28: the pale-on-pale cards were unreadable)
			local _, face = Style.block(card, Style.grad(if complete then "yellow" else "tabOff"))
			local well = Instance.new("Frame")
			well.BackgroundColor3 = Color3.new(1, 1, 1)
			well.BackgroundTransparency = 0.1
			well.AnchorPoint = Vector2.new(0.5, 0)
			well.Position = UDim2.fromOffset(0, 10) + UDim2.fromScale(0.5, 0)
			well.Size = UDim2.fromOffset(112, 112)
			Style.corner(well, 999)
			Style.stroke(well, S.border, true)
			well.Parent = face
			local art = Instance.new("Frame")
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0.5)
			art.Position = UDim2.fromScale(0.5, 0.5)
			art.Size = UDim2.fromScale(1.1, 1.1)
			art.Parent = well
			Sticker.draw(art, page.id, "Stamp", Rules.has(state, page.id, 4))
			local name = Style.label(face, page.name, Theme.Text.small)
			name.Position = UDim2.new(0, 8, 1, -72)
			name.Size = UDim2.new(1, -16, 0, 26)
			name.TextWrapped = false
			name.TextScaled = true
			-- the found counter: a bold dark pill
			local pill = Instance.new("Frame")
			pill.BackgroundColor3 = Theme.Grad.ink.bottom
			pill.AnchorPoint = Vector2.new(0.5, 1)
			pill.Position = UDim2.new(0.5, 0, 1, -8)
			pill.Size = UDim2.fromOffset(96, 36)
			Style.corner(pill, 999)
			Style.stroke(pill, 2, true)
			pill.Parent = face
			Style.label(pill, `{found}/{total}`, Theme.Text.body)
			Style.press(card, function()
				showPage(page)
			end)
		end

		-- Specials: a header with the found count, then one card each
		local owned = WorkerRules.ownedSpecials(workers)
		local found = 0
		for _, sp in WorkerRules.SPECIALS do
			if owned[sp.id] then
				found += 1
			end
		end
		local header = Instance.new("Frame")
		header.Name = "SpecialsHeader"
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 44)
		header.LayoutOrder = 2
		header.Parent = panel.body
		local icon = Instance.new("Frame")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(40, 40)
		icon.Parent = header
		Style.icon(icon, "vip")
		local title = Style.label(header, "Specials", Theme.Text.heading, true)
		title.Position = UDim2.fromOffset(50, 0)
		title.Size = UDim2.new(1, -170, 1, 0)
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextWrapped = false
		local counter =
			Style.label(header, `{found}/{#WorkerRules.SPECIALS}`, Theme.Text.heading, true)
		counter.Name = "Found"
		counter.AnchorPoint = Vector2.new(1, 0)
		counter.Position = UDim2.fromScale(1, 0)
		counter.Size = UDim2.new(0, 110, 1, 0)
		counter.TextXAlignment = Enum.TextXAlignment.Right

		local specials = Instance.new("Frame")
		specials.Name = "Specials"
		specials.BackgroundTransparency = 1
		specials.Size = UDim2.fromScale(1, 0)
		specials.AutomaticSize = Enum.AutomaticSize.Y
		specials.LayoutOrder = 3
		specials.Parent = panel.body
		local sgrid = Instance.new("UIGridLayout")
		sgrid.CellSize = UDim2.fromOffset(SPECIAL_W, SPECIAL_H)
		sgrid.CellPadding = UDim2.fromOffset(14, 14)
		sgrid.HorizontalAlignment = Enum.HorizontalAlignment.Center
		sgrid.SortOrder = Enum.SortOrder.LayoutOrder
		sgrid.Parent = specials
		local place = WorkerRules.assign(workers, buildings)
		local slots: { Portrait.Slot } = {}
		for order, sp in WorkerRules.SPECIALS do
			local index: number? = nil
			for i, w in workers do
				if w.special == sp.id then
					index = i
					break
				end
			end
			local art = Instance.new("Frame")
			art.BackgroundTransparency = 1
			art.AnchorPoint = Vector2.new(0.5, 0)
			art.Position = UDim2.new(0.5, 0, 0, 12)
			art.Size = UDim2.fromOffset(84, 84)
			if not index then
				local slot = Instance.new("Frame")
				slot.Name = "Special_" .. sp.id
				slot.BackgroundTransparency = 1
				slot.LayoutOrder = order
				slot.Parent = specials
				local _, face = Style.block(slot, Style.grad("disabled"))
				art.Parent = face
				silhouette(art)
				continue
			end
			local w = workers[index]
			local tier = Rarity.TIERS[sp.rarity]
			local card = Style.button(specials, UDim2.fromOffset(SPECIAL_W, SPECIAL_H))
			card.Name = "Special_" .. sp.id
			card.LayoutOrder = order
			local face = Portrait.back(card, sp.rarity)
			art.Position = UDim2.fromOffset(8, 8)
			art.AnchorPoint = Vector2.zero
			art.Size = UDim2.new(1, -16, 0, 92)
			art.Parent = face
			table.insert(
				slots,
				{ holder = art, rig = WorkerRules.rigOf(index, w.name), category = w.category } :: Portrait.Slot
			)
			local kind = Instance.new("Frame")
			kind.BackgroundTransparency = 1
			kind.Position = UDim2.fromOffset(10, 10)
			kind.Size = UDim2.fromOffset(30, 30)
			kind.ZIndex = 2
			kind.Parent = face
			WorkerBadge.icon(kind, sp.category)
			local name = Style.label(face, sp.name, Theme.Text.body)
			name.Position = UDim2.fromOffset(6, 102)
			name.Size = UDim2.new(1, -12, 0, 32)
			name.TextWrapped = false
			name.TextScaled = true
			local cap = Instance.new("UITextSizeConstraint")
			cap.MaxTextSize = Theme.Text.body
			cap.MinTextSize = 12
			cap.Parent = name
			local perk = Style.label(face, PERK[sp.id] or tier.name, Theme.Text.small)
			perk.Position = UDim2.fromOffset(6, 138)
			perk.Size = UDim2.new(1, -12, 0, 40)
			Style.press(card, function()
				local workplace = if place[index]
					then WorkerRules.buildingOf(w.category) or ""
					else ""
				survivorCard.open(
					SurvivorTag.fromWorker(w, workplace, nil, WorkerRules.rigOf(index, w.name)),
					false
				)
			end)
		end
		stopPortraits = Portrait.lazy(panel.body, slots)
	end

	rebuild()
	DiscoveryController.Changed:Connect(function()
		if panel.isOpen() then
			rebuild()
		end
	end)
	local function onData(raw: any)
		if type(raw) == "table" and type(raw.workers) == "table" then
			workers = WorkerRules.clean(raw.workers)
			buildings = if type(raw.dockBuildings) == "table" then raw.dockBuildings else {}
			if panel.isOpen() then
				rebuild()
			end
		end
	end
	Net.event("PlayerDataChanged").OnClientEvent:Connect(onData)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Progression_GetData", 10)
		if remote and remote:IsA("RemoteFunction") then
			local ok, raw = pcall(function()
				return remote:InvokeServer()
			end)
			if ok then
				onData(raw)
			end
		end
	end)

	return {
		open = function()
			panel.open()
			rebuild()
		end,
		close = function()
			closePreview()
			survivorCard.close()
			panel.close()
		end,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Album
