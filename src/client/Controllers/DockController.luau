--!strict
-- DockController (docs/23 (j) rule 4, WP-14d): the owner's build station by the spawn carries a tablet
-- whose prompt opens the top-down build mode. The camera lifts to a Scriptable island view (shared/DockBuild),
-- movement locks, every empty lot for sale gets a flat paper blueprint (WP-14e: blue sheet, white grid, the
-- item's Lego line drawing; never a 3D preview), and a Kit panel docked on the right lists every level,
-- building, quest blueprint and decor as a card (Build / Decor tabs). Tapping a paper or a card focuses it:
-- the camera eases in to its lot (0.6 s), a flat outline pulses and a bottom strip shows its name, one line
-- (DockConfig desc) and the buy buttons. Cash buys through Dock_Upgrade (greyed when the rank or the Cash is
-- short); Robux opens Roblox's purchase prompt (skips both). Escape / B / tapping empty sea backs out of the
-- focus, then out of build mode; the red X or a teleport closes and restores the camera and controls. On a buy the pieces already exist in their final state; Dock_Build tells this controller to play
-- the Lego build beat (shared/BuildSeq): each piece drops in, staggered, with a snap and a squash, then dust.
-- Reads player attributes DockPlot, DockLevel, DockHangar / DockSubPen / Decor<key> and the PlayerDataChanged
-- snapshot. Paint booth (docs/23 d.3, WP-13): sitting in a craft inside your own Lv 3+ booth
-- (DockConfig.PAINT_BOOTH) opens the paint card: a swatch strip and the existing cosmetic pickers for Livery
-- and Decal (the same rows as the phone's Settings). Leaving the booth or B / the X button closes it.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local DockBlueprints = require(Shared:WaitForChild("DockBlueprints"))
local DockBuild = require(Shared:WaitForChild("DockBuild"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local CashBurst = require(UI:WaitForChild("CashBurst"))
local CosmeticPicker = require(UI:WaitForChild("CosmeticPicker"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))

local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local Kit = UI:WaitForChild("Kit")
local PanelUI = require(Kit:WaitForChild("Panel"))
local PriceButtonUI = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local TabsUI = require(Kit:WaitForChild("Tabs"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local S = Theme.Size
local C = HudTheme.Colors
local DockController = {}
local LIST_W = 440 -- the right-hand list, du
local CARD_BUY_H = 168 -- a card with its buy buttons
local CARD_H = 104 -- owned / not for sale yet
local STRIP_H = 132 -- the focus strip
local OUTLINE = Color3.fromRGB(255, 214, 60)
local PAPER = Color3.fromRGB(38, 102, 190) -- blueprint blue
local PAPER_PPS = 20 -- SurfaceGui pixels per stud on the paper

local snapshot: { [string]: any } = {}
local livePrice: { [number]: number } = {} -- product id -> Robux price, read from Roblox once
local shownCount: number? = nil

local displayed = false
local plotFrame: CFrame? = nil
local stationPos: Vector3? = nil
local returnCf: CFrame? = nil
local tabIndex = 1
local focused: DockBlueprints.Item? = nil

local ui: ScreenGui? = nil
local listPanel: PanelUI.Panel? = nil
local cardsContent: ScrollingFrame? = nil
local focusStrip: Frame? = nil
local stripContent: Frame? = nil
local tabs: TabsUI.Tabs? = nil
local cards: { ImageButton } = {}

local papers: Folder? = nil
local paperItems: { [Instance]: DockBlueprints.Item } = {}

local modal: InputGlyph.Modal

local camValue: CFrameValue? = nil
local camTween: Tween? = nil
local camRun = 0
local outline: Model? = nil
local humConn: RBXScriptConnection? = nil
type Movement = { walk: number, jump: number, jumpHeight: number }
local savedMovement: Movement? = nil

local function currentLevel(): number
	local level = player:GetAttribute("DockLevel")
	return if type(level) == "number" then level else 1
end

local function entryOf(item: DockBlueprints.Item): any
	if item.kind == "Level" then
		return DockConfig.Levels[item.key :: number]
	elseif item.kind == "Building" then
		return DockConfig.Buildings[item.key :: string]
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key :: string]
	end
	return nil
end

local function ownedOf(item: DockBlueprints.Item): boolean
	if item.kind == "Level" then
		return currentLevel() >= (item.key :: number)
	end
	local prefix = if item.kind == "Decor" then "Decor" else "Dock"
	return player:GetAttribute(prefix .. tostring(item.key)) == true
end

local function sameItem(a: DockBlueprints.Item?, b: DockBlueprints.Item?): boolean
	return a ~= nil and b ~= nil and a.kind == b.kind and a.key == b.key
end

local function aspect(): number
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.max(vp.X / math.max(vp.Y, 1), 0.3)
end

local function shake(target: GuiObject?)
	if not target then
		AudioController.play("UI_Fail")
		return
	end
	local at = target.Position
	target.Position = at + UDim2.fromOffset(8, 0)
	TweenService:Create(target, TweenInfo.new(0.3, Enum.EasingStyle.Elastic), { Position = at })
		:Play()
	AudioController.play("UI_Fail")
end

local function fly(target: CFrame, duration: number): (number, Tween)
	camRun += 1
	local run = camRun
	local cv: CFrameValue
	if camValue then
		cv = camValue
	else
		local made = Instance.new("CFrameValue")
		made.Name = "BuildCamera"
		local camera = Workspace.CurrentCamera
		made.Value = if camera then camera.CFrame else CFrame.identity
		made:GetPropertyChangedSignal("Value"):Connect(function()
			CameraController.SetOverride(made.Value, DockBuild.FOV)
		end)
		camValue = made
		cv = made
	end
	CameraController.SetOverride(cv.Value, DockBuild.FOV)
	if camTween then
		camTween:Cancel()
	end
	local tw = TweenService:Create(
		cv,
		TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = target }
	)
	tw:Play()
	camTween = tw
	return run, tw
end

local function endCamera(run: number)
	if run ~= camRun then
		return
	end
	CameraController.ClearOverride()
	if camValue then
		camValue:Destroy()
		camValue = nil
	end
	camTween = nil
end

local function clearOutline()
	if outline then
		outline:Destroy()
		outline = nil
	end
end

local function outlineSpot(world: CFrame, size: Vector2)
	clearOutline()
	local m = Instance.new("Model")
	m.Name = "BuildOutline"
	local parts: { BasePart } = {}
	local function edge(name: string, partSize: Vector3, offset: Vector3)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = partSize
		p.CFrame = world * CFrame.new(offset)
		p.Color = OUTLINE
		p.Material = Enum.Material.Neon
		p.Transparency = 0.1
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
			true, false, false, false, false
		p.Parent = m
		table.insert(parts, p)
	end
	local barH = 0.16
	local thick = 0.7
	local y = DockBuild.PAPER_LIFT + 0.12
	edge("Front", Vector3.new(size.X, barH, thick), Vector3.new(0, y, -size.Y / 2))
	edge("Back", Vector3.new(size.X, barH, thick), Vector3.new(0, y, size.Y / 2))
	edge("Left", Vector3.new(thick, barH, size.Y), Vector3.new(-size.X / 2, y, 0))
	edge("Right", Vector3.new(thick, barH, size.Y), Vector3.new(size.X / 2, y, 0))
	for _, p in parts do
		TweenService:Create(
			p,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.75 }
		):Play()
	end
	m.Parent = Workspace
	outline = m
end

-- The item's Lego line drawing (DockBlueprints.GLYPHS) inside `parent` (a square frame). Card art: white
-- bricks with an ink edge, holes in ink. Paper: white lines only.
local function drawGlyph(parent: GuiObject, item: DockBlueprints.Item, line: number?)
	for _, box in DockBlueprints.glyph(item) do
		local f = Instance.new("Frame")
		f.Name = "Brick"
		f.BorderSizePixel = 0
		f.Position = UDim2.fromScale(box.x, box.y)
		f.Size = UDim2.fromScale(box.w, box.h)
		f.BackgroundColor3 = if box.hole then Theme.Colors.ink else Color3.new(1, 1, 1)
		f.BackgroundTransparency = if line then 1 else 0
		f.ZIndex = if box.hole then 3 else 2
		local corner = Instance.new("UICorner")
		corner.CornerRadius = if box.round
			then UDim.new(0.5, 0)
			else UDim.new(0, if line then 2 else 4)
		corner.Parent = f
		local stroke = Instance.new("UIStroke")
		stroke.Color = if line then Color3.new(1, 1, 1) else Theme.Colors.ink
		stroke.Thickness = line or 2.5
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = f
		f.Parent = parent
	end
end

-- What an item's card and strip show: owned / for sale (Cash and Robux buttons) / why it is locked.
type Status = {
	owned: boolean,
	forSale: boolean, -- not owned, the dock level allows it, not a quest reward
	rankLock: boolean, -- for sale with Robux only (Robux skips the rank, docs/23 (c) rule 4)
	cash: number,
	productId: number, -- 0: no Robux product
	robux: number,
	badge: string?, -- "Owned", a rank, "Dock Lv N", "Quest"
}

local function statusOf(item: DockBlueprints.Item): Status
	local entry = entryOf(item)
	local owned = ownedOf(item)
	local levelLock = if item.kind == "Level"
		then (item.key :: number) > currentLevel() + 1
		elseif item.kind == "Building" then currentLevel()
			< DockConfig.Buildings[item.key :: string].needs
		else false
	local rankLock = item.kind ~= "Decor"
		and item.kind ~= "Blueprint"
		and entry ~= nil
		and DockConfig.rankIndex(entry.rank) > (snapshot.rankIndex or 1)
	local forSale = not owned and not levelLock and DockBlueprints.buyable(item)
	local product = entry and entry.product and MonetizationConfig.Products[entry.product]
	local id = if product then product.id else 0
	local badge: string? = nil
	if owned then
		badge = "Owned"
	elseif item.kind == "Blueprint" then
		badge = "Quest"
	elseif levelLock then
		badge = if item.kind == "Level"
			then `Dock Lv {(item.key :: number) - 1}`
			else `Dock Lv {DockConfig.Buildings[item.key :: string].needs}`
	elseif rankLock then
		badge = ProgressionConfig.Ranks[DockConfig.rankIndex(entry.rank)].displayName
	end
	return {
		owned = owned,
		forSale = forSale,
		rankLock = rankLock,
		cash = if entry and type(entry.cash) == "number" then entry.cash else 0,
		productId = id,
		robux = livePrice[id] or (entry and entry.robux) or 0,
		badge = badge,
	}
end

local function cashBuy(item: DockBlueprints.Item)
	local remote = Net.init():WaitForChild("Dock_Upgrade", 5) :: RemoteFunction?
	if not remote then
		return
	end
	local ok = remote:InvokeServer(item.key)
	if not ok then
		shake(if focused then focusStrip else listPanel and listPanel.root)
	end
end

local function robuxBuy(id: number)
	if id == 0 then
		shake(focusStrip)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

-- The Cash button (greyed when the rank or the Cash is short) and the Robux button (skips both), side by
-- side in `parent`. Items without a Robux product (decor) get the Cash button alone.
local function buyButtons(parent: GuiObject, item: DockBlueprints.Item, st: Status)
	local row = Instance.new("Frame")
	row.Name = "Buy"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = parent
	Style.list(row, true, 10)
	local both = st.productId ~= 0
	local width = if both then UDim2.new(0.5, -5, 1, 0) else UDim2.fromScale(1, 1)
	local cashButton = PriceButtonUI.new(row, {
		price = st.cash,
		currency = "Cash",
		state = if st.rankLock or st.cash > (snapshot.cash or 0) then "disabled" else "buy",
		onActivate = function()
			cashBuy(item)
		end,
	})
	cashButton.root.Name = "Cash"
	cashButton.root.Size = width
	if not both then
		return
	end
	local id = st.productId
	local rb = PriceButtonUI.new(row, {
		price = st.robux,
		currency = "Robux",
		onActivate = function()
			robuxBuy(id)
		end,
	})
	rb.root.Name = "Robux"
	rb.root.Size = width
	rb.root.LayoutOrder = 1
	if not livePrice[id] then
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				livePrice[id] = info.PriceInRobux
				if rb.root.Parent then
					rb.setPrice(info.PriceInRobux)
				end
			end
		end)
	end
end

-- The state badge: a tick + Owned, or a padlock + what it waits for. Its own row, never over the title.
local function badgeRow(parent: GuiObject, st: Status): Frame?
	local text = st.badge
	if not text then
		return nil
	end
	local row = Instance.new("Frame")
	row.Name = "Badge"
	row.BackgroundTransparency = 1
	row.Parent = parent
	local list = Style.list(row, true, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local mark = Instance.new("Frame")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromOffset(26, 26)
	mark.Parent = row
	if st.owned then
		local tick = Instance.new("ImageLabel")
		tick.BackgroundTransparency = 1
		tick.Image = UiImages.VehicleArt.Check
		tick.Size = UDim2.fromScale(1, 1)
		tick.Parent = mark
	else
		Style.icon(mark, "lock")
	end
	local label = Style.label(row, text, Theme.Text.small)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -32, 1, 0)
	label.LayoutOrder = 1
	return row
end

local function colorOf(item: DockBlueprints.Item): string
	if item.kind == "Level" then
		return "blue"
	elseif item.kind == "Building" then
		return "teal"
	elseif item.kind == "Blueprint" then
		return "purple"
	end
	return DockConfig.Decorations[item.key :: string].color
end

local function artWell(parent: GuiObject, item: DockBlueprints.Item, side: number): Frame
	local well = Instance.new("Frame")
	well.Name = "Art"
	well.BackgroundColor3 = Color3.new(1, 1, 1)
	well.BackgroundTransparency = 0.6
	well.Size = UDim2.fromOffset(side, side)
	Style.corner(well, S.cornerSmall)
	well.Parent = parent
	local inner = Instance.new("Frame")
	inner.BackgroundTransparency = 1
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.8, 0.8)
	inner.Parent = well
	drawGlyph(inner, item)
	return well
end

local focusItem: (DockBlueprints.Item) -> ()

local function refreshCards()
	local content = cardsContent
	if not content then
		return
	end
	for _, card in cards do
		card:Destroy()
	end
	cards = {}
	local n = 0
	for _, item in DockBlueprints.catalog() do
		if (tabIndex == 2) == (item.kind == "Decor") then
			n += 1
			local st = statusOf(item)
			local root = Style.button(
				content,
				UDim2.new(1, -8, 0, if st.forSale then CARD_BUY_H else CARD_H)
			)
			root.Name = `Card{n}`
			root.LayoutOrder = n
			local locked = not st.owned and not st.forSale
			local _, face =
				Style.block(root, Style.grad(if locked then "locked" else colorOf(item)))
			local well = artWell(face, item, 76)
			well.Position = UDim2.fromOffset(10, 10)
			local title = Style.label(face, DockBlueprints.label(item), Theme.Text.heading)
			title.Name = "Title"
			title.Position = UDim2.fromOffset(98, 8)
			title.Size = UDim2.new(1, -108, 0, 36)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = false
			title.TextTruncate = Enum.TextTruncate.AtEnd
			local badge = badgeRow(face, st)
			if badge then
				badge.Position = UDim2.fromOffset(98, 48)
				badge.Size = UDim2.new(1, -108, 0, 28)
			end
			if st.forSale then
				local slot = Instance.new("Frame")
				slot.BackgroundTransparency = 1
				slot.AnchorPoint = Vector2.new(0, 1)
				slot.Position = UDim2.new(0, 10, 1, -10)
				slot.Size = UDim2.new(1, -20, 0, 58)
				slot.Parent = face
				buyButtons(slot, item, st)
			end
			Style.press(root, function()
				focusItem(item)
			end, S.corner)
			table.insert(cards, root)
		end
	end
	local sel = GuiService.SelectedObject
	if
		InputGlyph.device() == "Gamepad"
		and cards[1]
		and not (sel and ui and sel:IsDescendantOf(ui))
	then
		GuiService.SelectedObject = cards[1]
	end
end

-- The focus strip: the item's drawing, name, one line and the two buy buttons (or its badge).
local function refreshStrip()
	local holder, content = focusStrip, stripContent
	if not holder or not content then
		return
	end
	content:ClearAllChildren()
	local item = focused
	holder.Visible = item ~= nil
	if not item then
		return
	end
	local st = statusOf(item)
	local well = artWell(content, item, STRIP_H - 30)
	well.Position = UDim2.fromOffset(0, 0)
	local buyW = if st.forSale then (if st.productId ~= 0 then 380 else 190) else 0
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(STRIP_H - 16, 0)
	words.Size = UDim2.new(1, -(STRIP_H - 16) - buyW - 12, 1, 0)
	words.Parent = content
	local name = Style.label(words, DockBlueprints.label(item), Theme.Text.heading)
	name.Size = UDim2.new(1, 0, 0, 36)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local line = Style.label(words, DockBlueprints.desc(item), Theme.Text.small)
	line.Position = UDim2.fromOffset(0, 38)
	line.Size = UDim2.new(1, 0, 0, 52)
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	if st.forSale then
		local slot = Instance.new("Frame")
		slot.BackgroundTransparency = 1
		slot.AnchorPoint = Vector2.new(1, 0.5)
		slot.Position = UDim2.fromScale(1, 0.5)
		slot.Size = UDim2.fromOffset(buyW, 64)
		slot.Parent = content
		buyButtons(slot, item, st)
	end
	local badge = badgeRow(words, st)
	if badge then
		badge.Position = UDim2.new(0, 0, 1, -28)
		badge.Size = UDim2.new(1, 0, 0, 28)
		line.Size = UDim2.new(1, 0, 0, 30)
	end
end

-- A flat paper blueprint on an empty lot: blue sheet, white grid and border, the item's line drawing.
-- Solid and only lifted off the plate, never a 3D preview (docs/23 (n), no holograms).
local function makePaper(item: DockBlueprints.Item, frame: CFrame, parent: Instance)
	local cf, size = DockBuild.paper(item, frame)
	local p = Instance.new("Part")
	p.Name = "Blueprint"
	p.Size = Vector3.new(size.X, 0.2, size.Y)
	p.CFrame = cf
	p.Color = PAPER
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, true, false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = PAPER_PPS
	gui.LightInfluence = 1
	gui.Parent = p
	local function rule(pos: UDim2, sz: UDim2)
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 0.6
		f.Position = pos
		f.Size = sz
		f.Parent = gui
	end
	for x = 2, size.X - 1, 2 do
		rule(UDim2.fromOffset(x * PAPER_PPS - 1, 0), UDim2.new(0, 2, 1, 0))
	end
	for z = 2, size.Y - 1, 2 do
		rule(UDim2.fromOffset(0, z * PAPER_PPS - 1), UDim2.new(1, 0, 0, 2))
	end
	local inset = 0.6 * PAPER_PPS
	local border = Instance.new("Frame")
	border.BackgroundTransparency = 1
	border.Position = UDim2.fromOffset(inset, inset)
	border.Size = UDim2.new(1, -2 * inset, 1, -2 * inset)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 0.35 * PAPER_PPS
	stroke.Parent = border
	border.Parent = gui
	local side = math.min(size.X, size.Y) * 0.62 * PAPER_PPS
	local art = Instance.new("Frame")
	art.Name = "Drawing"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromOffset(side, side)
	art.Parent = gui
	drawGlyph(art, item, math.max(0.25 * PAPER_PPS, side / 30))
	p.Parent = parent
	paperItems[p] = item
end

local function clearPapers()
	if papers then
		papers:Destroy()
		papers = nil
	end
	paperItems = {}
end

local function refreshPapers()
	clearPapers()
	local b = plotFrame
	if not b then
		return
	end
	local owned: { [string]: boolean } = {}
	for _, item in DockBlueprints.catalog() do
		if item.kind ~= "Level" and ownedOf(item) then
			owned[item.key :: string] = true
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "BuildBlueprints"
	for _, item in DockBlueprints.onIsland(currentLevel(), owned) do
		makePaper(item, b, folder)
	end
	folder.Parent = Workspace
	papers = folder
end

local function islandView(duration: number)
	local b = plotFrame
	if b then
		fly(DockBuild.camera(b, DockBuild.ISLAND_RADIUS, aspect(), nil), duration)
	end
end

-- Zoom to an item's lot (from its card or its paper on the island) and show its strip.
focusItem = function(item: DockBlueprints.Item)
	local b = plotFrame
	if not b then
		return
	end
	focused = item
	local spot, size = DockBuild.spot(item)
	outlineSpot(b * spot, size)
	local at, paperSize = DockBuild.paper(item, b)
	fly(DockBuild.focus(b, at.Position, paperSize, aspect()), 0.6)
	refreshStrip()
	AudioController.play("UI_Click")
end

local function unfocus()
	focused = nil
	clearOutline()
	refreshStrip()
	islandView(0.6)
end

local function closeBuild()
	if not displayed then
		return
	end
	displayed = false
	focused = nil
	clearOutline()
	clearPapers()
	refreshStrip()
	if ui then
		ui.Enabled = false
	end
	modal.close()
	ContextActionService:UnbindAction("BuildModeExit")
	if humConn then
		humConn:Disconnect()
		humConn = nil
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and savedMovement then
		hum.WalkSpeed = savedMovement.walk
		hum.JumpPower = savedMovement.jump
		hum.JumpHeight = savedMovement.jumpHeight
	end
	savedMovement = nil
	if camValue then
		local run, tw = fly(returnCf or camValue.Value, 0.8)
		tw.Completed:Connect(function()
			endCamera(run)
		end)
	else
		CameraController.ClearOverride()
	end
	AudioController.play("UI_Click")
end

-- Escape / B: back out of the focus view first, then out of build mode.
local function back()
	if focused then
		unfocus()
	else
		closeBuild()
	end
end

local function redraw()
	refreshCards()
	refreshPapers()
	refreshStrip()
end

local function buildUI(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BuildTablet"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 25
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui
	local canvas = Style.canvas(gui)

	-- the list: a Kit panel docked on the right, full height, Build / Decor tabs on top
	local p = PanelUI.new(canvas, {
		title = "Build",
		icon = "build",
		size = Vector2.new(LIST_W, 2000),
		tabs = true,
		onClose = closeBuild,
	})
	p.root.AnchorPoint = Vector2.new(1, 0.5)
	p.root.Position = UDim2.new(1, -S.margin, 0.5, 0)
	listPanel = p
	cardsContent = p.body
	tabs = TabsUI.new(
		p.top,
		{ { name = "Build", icon = "build" }, { name = "Decor", icon = "gift" } },
		function(i)
			tabIndex = i
			refreshCards()
			p.body.CanvasPosition = Vector2.zero
		end
	)

	-- the focus strip, bottom left of the list
	local holder = Instance.new("Frame")
	holder.Name = "Focus"
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, S.margin, 1, -S.margin)
	holder.Size = UDim2.new(1, -(LIST_W + 3 * S.margin), 0, STRIP_H)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = canvas
	local _, face = Style.block(holder, Style.grad("blue"), { shadow = true })
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(S.pad, S.pad)
	inner.Size = UDim2.new(1, -2 * S.pad, 1, -2 * S.pad)
	inner.Parent = face
	focusStrip = holder
	stripContent = inner

	return gui
end

local function bindExit()
	ContextActionService:BindActionAtPriority("BuildModeExit", function(_, state)
		if state == Enum.UserInputState.Begin then
			back()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 6, Enum.KeyCode.Escape)
end

local function openBuild()
	if displayed then
		return
	end
	local plot = player:GetAttribute("DockPlot")
	local b = player:GetAttribute("BayCFrame")
	if type(plot) ~= "number" or typeof(b) ~= "CFrame" then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	displayed = true
	plotFrame = b
	stationPos = DockConfig.stationSpot(b).Position
	local camera = Workspace.CurrentCamera
	returnCf = if camera then camera.CFrame else nil
	savedMovement = { walk = hum.WalkSpeed, jump = hum.JumpPower, jumpHeight = hum.JumpHeight }
	hum.WalkSpeed, hum.JumpPower, hum.JumpHeight = 0, 0, 0
	humConn = hum.Died:Connect(closeBuild)
	ui = ui or buildUI()
	local screen = ui :: ScreenGui
	screen.Enabled = true
	local p = listPanel :: PanelUI.Panel
	Style.pop(p.root, true)
	local tabBar = tabs
	if tabBar then
		tabBar.select(tabIndex)
	end
	refreshPapers()
	modal.open(p.closeButton)
	if InputGlyph.device() == "Gamepad" and cards[1] then
		GuiService.SelectedObject = cards[1]
	end
	bindExit()
	islandView(0.8)
	AudioController.play("UI_Click")
end

-- A click / tap on the island in build mode: a paper blueprint focuses its item; empty sea or land backs out.
local function onWorldTap(input: InputObject, processed: boolean)
	if not displayed or processed or not papers then
		return
	end
	local kind = input.UserInputType
	if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.Touch then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ScreenPointToRay(input.Position.X, input.Position.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { papers }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 3000, params)
	local item = hit and paperItems[hit.Instance]
	if item then
		if not sameItem(item, focused) then
			focusItem(item)
		end
	elseif focused then
		unfocus()
	end
end

-- The Lego build beat (WP-14c): each part of a freshly built model drops from above with a stagger,
-- lands with a squash and a snap, then a dust puff. Client tweens only; the server owns the final
-- positions, so skipping this (a missed event) just shows the finished building.
local function snapSound(at: Vector3)
	AudioController.play("UI_Click", at, 0.5)
end

local function dustPuff(at: Vector3)
	local p = Instance.new("Part")
	p.Name = "BuildDust"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 222, 205))
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = p
	p.Parent = Workspace
	e:Emit(25)
	game:GetService("Debris"):AddItem(p, 3)
end

local function playBuild(model: Model)
	local parts: { BasePart } = {}
	local ys: { number } = {}
	local base = Vector3.zero
	local minY = math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			table.insert(ys, d.CFrame.Y)
			base += d.Position * Vector3.new(1, 0, 1)
			minY = math.min(minY, d.CFrame.Y)
		end
	end
	if #parts == 0 then
		return
	end
	base /= #parts
	local at = Vector3.new(base.X, minY, base.Z)
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local last = 0
	for _, step in plan do
		local part = parts[step.i]
		local final = part.CFrame
		part.CFrame = final + Vector3.new(0, step.drop, 0)
		local tween = TweenService:Create(
			part,
			TweenInfo.new(
				0.45,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				step.delay
			),
			{ CFrame = final }
		)
		last = math.max(last, step.delay + 0.45)
		tween.Completed:Connect(function()
			if tween.PlaybackState ~= Enum.PlaybackState.Cancelled then
				snapSound(final.Position)
				local size = part.Size
				TweenService
					:Create(part, TweenInfo.new(0.07), { Size = size * Vector3.new(1, 0.82, 1) })
					:Play()
				TweenService:Create(
					part,
					TweenInfo.new(
						0.07,
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.Out,
						0,
						false,
						0.07
					),
					{ Size = size }
				):Play()
			end
		end)
		tween:Play()
	end
	task.delay(last + 0.3, function()
		dustPuff(at)
	end)
end

-- A purchase (a level, building or decor landed, seen through the attributes): the till and the coin burst.
local function refresh()
	local level = player:GetAttribute("DockLevel")
	if type(level) ~= "number" then
		return
	end
	local count = level
	for _, key in DockConfig.BUILDINGS do
		if player:GetAttribute("Dock" .. key) == true then
			count += 1
		end
	end
	for _, key in DockConfig.DECOR do
		if player:GetAttribute("Decor" .. key) == true then
			count += 1
		end
	end
	if shownCount and count > shownCount then
		AudioController.play("Chandlery_Till")
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(800, 600)
		CashBurst.playAt(playerGui, view / 2, 0, false)
	end
	shownCount = count
end

type Booth = { gui: ScreenGui, pickers: { CosmeticPicker.Picker } }
local booth: Booth? = nil
local inBooth = false
local boothModal: InputGlyph.Modal

local function closeBooth()
	if booth then
		booth.gui.Enabled = false
	end
	boothModal.close()
end

local BOOTH_SWATCHES = {
	Color3.fromRGB(214, 86, 20),
	Color3.fromRGB(201, 162, 74),
	Color3.fromRGB(40, 150, 142),
	Color3.fromRGB(79, 98, 117),
	Color3.fromRGB(226, 85, 122),
}

local function buildBooth(): Booth
	local gui = Instance.new("ScreenGui")
	gui.Name = "PaintBoothCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 30
	gui.Enabled = false
	gui.Parent = playerGui
	local panel = HudTheme.panel("Card", UDim2.fromOffset(360, 168), gui)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -110)
	panel.BackgroundTransparency = HudTheme.PromptTransparency
	HudTheme.padding(panel, 14)
	HudTheme.skin(panel)
	-- the header is the paint itself: a strip of swatches
	local strip = Instance.new("Frame")
	strip.Name = "Swatches"
	strip.Size = UDim2.new(1, -44, 0, 26)
	strip.BackgroundTransparency = 1
	strip.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 6)
	layout.Parent = strip
	for _, c in BOOTH_SWATCHES do
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(34, 26)
		sw.BackgroundColor3 = c
		sw.BorderSizePixel = 0
		HudTheme.corner(sw, 6)
		sw.Parent = strip
	end
	local closeButton = HudTheme.button("Close", "X", UDim2.fromOffset(34, 34), panel)
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.fromScale(1, 0)
	closeButton.BackgroundColor3 = C.panelLight
	closeButton.Activated:Connect(closeBooth)
	local listRows = Instance.new("Frame")
	listRows.Name = "Rows"
	listRows.Position = UDim2.fromOffset(0, 42)
	listRows.Size = UDim2.new(1, 0, 1, -42)
	listRows.BackgroundTransparency = 1
	listRows.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = listRows
	return {
		gui = gui,
		pickers = {
			CosmeticPicker.new(listRows, "Livery", { layoutOrder = 1 }),
			CosmeticPicker.new(listRows, "Decal", { layoutOrder = 2 }),
		},
	}
end

local function openBooth()
	booth = booth or buildBooth()
	local b = booth :: Booth
	for _, picker in b.pickers do
		picker.refresh()
	end
	b.gui.Enabled = true
	boothModal.open(b.pickers[1].first)
	AudioController.play("UI_Click")
end

-- seated (driving or aboard) with the seat inside your own booth
local function boothCheck()
	local level, b = player:GetAttribute("DockLevel"), player:GetAttribute("BayCFrame")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local now = false
	if seat and type(level) == "number" and level >= 3 and typeof(b) == "CFrame" then
		local zone = DockConfig.PAINT_BOOTH
		local d = ((b :: CFrame) * zone.cf):PointToObjectSpace(seat.Position)
		local h = zone.size / 2
		now = math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
	end
	if now ~= inBooth then
		inBooth = now
		if now then
			openBooth()
		else
			closeBooth()
		end
	end
end

function DockController.Init()
	modal = InputGlyph.modal("BuildTablet", back)
	boothModal = InputGlyph.modal("PaintBooth", closeBooth)
end

function DockController.Start()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
			if displayed then
				refreshCards()
				refreshStrip()
			end
		end
	end)
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30) :: RemoteFunction?
		local ok, data = pcall(function()
			return getData and getData:InvokeServer()
		end)
		if ok and type(data) == "table" then
			snapshot = data
			if displayed then
				refreshCards()
				refreshStrip()
			end
		end
	end)
	local function onProgress()
		refresh()
		if displayed then
			redraw()
		end
	end
	player:GetAttributeChangedSignal("DockLevel"):Connect(onProgress)
	for _, key in DockConfig.BUILDINGS do
		player:GetAttributeChangedSignal("Dock" .. key):Connect(onProgress)
	end
	for _, key in DockConfig.DECOR do
		player:GetAttributeChangedSignal("Decor" .. key):Connect(onProgress)
	end
	refresh()
	UserInputService.InputBegan:Connect(onWorldTap)
	-- the Lego build beat, from DockService (the model is already in its final state)
	local buildEvent = Net.init():WaitForChild("Dock_Build", 30) :: RemoteEvent?
	if buildEvent then
		buildEvent.OnClientEvent:Connect(function(payload: any)
			local plot, name, parent =
				payload and payload.plot, payload and payload.name, payload and payload.parent
			if type(plot) ~= "number" or type(name) ~= "string" then
				return
			end
			task.spawn(function()
				local marina = Workspace:WaitForChild("Marina", 5)
				local pm = marina and marina:WaitForChild(`Plot{plot}`, 5)
				if not pm then
					return
				end
				local holder = if typeof(parent) == "string" then pm:WaitForChild(parent, 3) else pm
				local model = holder and holder:WaitForChild(name, 3)
				if model and model:IsA("Model") then
					playBuild(model)
				end
			end)
		end)
	end
	-- the tablet on my own plot: the plot and station may stream in after the claim, and out and back again
	task.spawn(function()
		while true do
			local plot = player:GetAttribute("DockPlot")
			if type(plot) == "number" then
				local marina = Workspace:FindFirstChild("Marina")
				local pm = marina and marina:FindFirstChild(`Plot{plot}`)
				local station = pm and pm:FindFirstChild("BuildStation")
				local tablet = station and station:FindFirstChild("Tablet", true)
				if
					tablet
					and tablet:IsA("BasePart")
					and not tablet:FindFirstChildOfClass("ProximityPrompt")
				then
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Build"
					prompt.ObjectText = "Tablet"
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 12
					prompt.RequiresLineOfSight = false
					prompt.Parent = tablet
					prompt.Triggered:Connect(openBuild)
				end
			end
			task.wait(2)
		end
	end)
	-- close if a teleport (or respawn) takes the player off the station
	task.spawn(function()
		while true do
			if displayed and stationPos then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local at = if root and root:IsA("BasePart") then root.Position else nil
				if not at or (at - stationPos).Magnitude > 90 then
					closeBuild()
				end
			end
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while true do
			boothCheck()
			task.wait(0.25)
		end
	end)
end

return DockController
