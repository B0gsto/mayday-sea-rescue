--!strict
-- DockController (docs/23 (j) rule 4, WP-14d; building levels, docs/25 A/B/J): the owner's build stand carries a
-- tablet whose prompt opens the top-down build mode. The camera lifts to a Scriptable island view
-- (shared/DockBuild), movement locks, and a Kit panel on the right lists the cards: Build (one card per building,
-- its level as stars, Build / Upgrade with the Cash and Robux price, "MAX" when done, a padlock and
-- "Needs: HQ 2" / the missing building when locked; the HQ card shows what the next HQ level needs as icons
-- with ticks) and Decor. An unbuilt lot shows nothing (docs/25 J). A busy site shows its m:ss on its card and
-- an hourglass on the other buyables. Tapping a card focuses it (owner rule): the camera eases in to the
-- building or its empty lot (0.6 s) and a steady flat outline marks it (never blinks: owner 2026-10-28); a "Needs" chip focuses what it needs. Cash
-- buys through Dock_Upgrade (greyed when the Cash is short); Robux opens Roblox's purchase prompt (skips the
-- Cash, never the order). Escape / B / tapping the world backs out of the focus, then out of build mode
-- (Escape is read from UserInputService: Roblox keeps it from ContextActionService); the red X or a teleport
-- closes and restores the camera and controls. On a buy the pieces already exist in their final state;
-- Dock_Build tells this controller to play the Lego build beat (shared/BuildSeq): each piece drops in,
-- staggered, with a snap and a squash, then dust. Out of build mode a bobbing green Lego arrow stands over every
-- building you can build or upgrade right now (allowed and affordable; none while a site runs).
-- Reads player attributes DockPlot, DockLevel<key> / Dock<key> / Decor<key> and the PlayerDataChanged snapshot (Cash).
-- Paint booth (docs/23 d.3, WP-13): sitting in a craft inside your own boathouse's booth
-- (DockConfig.PAINT_BOOTH) opens the paint card: a swatch strip and the existing cosmetic pickers for Livery
-- and Decal. Leaving the booth, boarding a seat (a launch puts you in the booth) or B / the X button closes it.
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockBlueprints = require(Shared:WaitForChild("DockBlueprints"))
local DockBuild = require(Shared:WaitForChild("DockBuild"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local CashBurst = require(UI:WaitForChild("CashBurst"))
local CosmeticPicker = require(UI:WaitForChild("CosmeticPicker"))
local Glyph = require(UI:WaitForChild("Glyph"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

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
local STRIP_H = 160 -- the focus strip: name, the badge row
local OUTLINE = Color3.fromRGB(255, 214, 60)

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
local decorTabs: TabsUI.Tabs? = nil
local cards: { ImageButton } = {}
local pulseKey: string? = nil -- docs/24 E, docs/25 J: the HQ / Workshop card pulses while the tutorial points at it
local pickTab: (number) -> () = function() end
local closeBuild: () -> ()

local modal: InputGlyph.Modal

local camValue: CFrameValue? = nil
local camFov = DockBuild.FOV
local camTween: Tween? = nil
local camRun = 0
local outline: Model? = nil
local humConn: RBXScriptConnection? = nil
type Movement = { walk: number, jump: number, jumpHeight: number }
local savedMovement: Movement? = nil

-- A one-line card label shrinks to fit (down to 12) instead of cutting its word ("Rescu...").
local function fit(label: TextLabel, size: number)
	label.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = size
	cap.MinTextSize = 12
	cap.Parent = label
end

local function entryOf(item: DockBlueprints.Item): any
	if item.kind == "Building" then
		return DockConfig.Buildings[item.key]
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key]
	end
	return nil
end

local function ownedOf(item: DockBlueprints.Item): boolean
	local prefix = if item.kind == "Decor" then "Decor" else "Dock"
	return player:GetAttribute(prefix .. item.key) == true
end

-- The island's building levels (data.dock.levels): DockService's DockLevel<key> attributes move first, the
-- snapshot fills in before they replicate.
local function levelsMap(): { [string]: number }
	local saved = type(snapshot.dock) == "table" and snapshot.dock.levels
	local out: { [string]: number } = {}
	for _, key in DockConfig.BUILDINGS do
		local n = player:GetAttribute(`DockLevel{key}`)
		out[key] = if type(n) == "number"
			then n
			else (type(saved) == "table" and tonumber(saved[key])) or 0
	end
	return out
end

local function aspect(): number
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.max(vp.X / math.max(vp.Y, 1), 0.3)
end

-- The screen share left of the list (the island and the lot being built are framed there, not under it).
local function free(): number
	local p = listPanel
	if not p then
		return 1
	end
	local vp, scale = Style.metrics(p.root)
	return math.clamp((vp.X - (LIST_W + 2 * S.margin) * scale) / math.max(vp.X, 1), 0.4, 1)
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
	camFov = DockBuild.fov(aspect() * free()) -- the FOV DockBuild framed `target` with
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
			CameraController.SetOverride(made.Value, camFov)
		end)
		camValue = made
		cv = made
	end
	CameraController.SetOverride(cv.Value, camFov)
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
	end
	local barH = 0.16
	local thick = 0.7
	local y = DockBuild.PAPER_LIFT + 0.12
	edge("Front", Vector3.new(size.X, barH, thick), Vector3.new(0, y, -size.Y / 2))
	edge("Back", Vector3.new(size.X, barH, thick), Vector3.new(0, y, size.Y / 2))
	edge("Left", Vector3.new(thick, barH, size.Y), Vector3.new(-size.X / 2, y, 0))
	edge("Right", Vector3.new(thick, barH, size.Y), Vector3.new(size.X / 2, y, 0))
	m.Parent = Workspace
	outline = m
end

local drawGlyph = BuildGlyph

-- Why an item is not for sale (or that it is owned): an icon (Kit name or asset id) and a 1-3 word label. A
-- reason with `item` names a prerequisite (docs/23 (q)): its chip shows a padlock and that item's drawing, and
-- tapping it focuses that item.
type Reason = { icon: string, text: string, item: DockBlueprints.Item? }

-- What an item's card and strip show: owned (a building: maxed) / for sale (Cash and Robux buttons) / why it
-- is locked. A building's `level` / `max` are its stars; `cash` and the product are its next level's.
type Status = {
	owned: boolean,
	forSale: boolean, -- the next level is allowed now (only the Cash may be short), not a quest reward
	level: number,
	max: number,
	cash: number,
	productId: number, -- 0: no Robux product
	robux: number,
	reason: Reason?,
	busy: ("site" | "wait")?, -- another construction runs: this lot (timer) or any other (hourglass)
}

-- The island's running construction, published by DockService on the plot (docs/24 B).
local function siteState(): { key: string?, progress: number, rate: number }
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local plot = if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
	local key = plot and plot:GetAttribute("SiteKey")
	return {
		key = if type(key) == "string" then key else nil,
		progress = (plot and tonumber(plot:GetAttribute("SiteProgress"))) or 0,
		rate = (plot and tonumber(plot:GetAttribute("SiteRate"))) or 1,
	}
end

-- A building row's next level: allowed now (the HQ gate and needs stand), or why not ("Needs: HQ 2").
local function buildingStatus(key: string, site: { key: string? }): Status
	local levels = levelsMap()
	local level = levels[key] or 0
	local max = UnlockTree.maxLevel(key)
	local want = math.min(level + 1, max)
	local lvl = DockConfig.Buildings[key].levels[want]
	local ok, why, _, need = UnlockTree.canBuild(key, level + 1, levels, math.huge)
	local maxed = level >= max
	local forSale = not maxed and ok
	local product = lvl.product and MonetizationConfig.Products[lvl.product]
	local id = if product and product.ready then product.id else 0
	local prepaid = type(snapshot.dockPrepaid) == "table" and snapshot.dockPrepaid[key]
	local busy: ("site" | "wait")? = nil
	if forSale and site.key then
		busy = if site.key == key then "site" else "wait"
	elseif forSale and prepaid then
		busy = "wait" -- Robux paid: it starts by itself, never offer a second buy
	end
	local reason: Reason? = nil
	if maxed then
		reason = { icon = UiImages.VehicleArt.Check, text = "MAX" }
	elseif forSale then
		reason = { icon = "build", text = if level == 0 then "Build" else "Upgrade" }
	elseif why == "HQ" then
		reason =
			{ icon = "lock", text = `Needs: HQ {lvl.hq}`, item = { kind = "Building", key = "HQ" } }
	elseif need then
		reason = {
			icon = "lock",
			text = if prepaid then "Paid" else `Needs: {UnlockTree.needName(need)}`,
			item = { kind = "Building", key = need },
		}
	end
	return {
		owned = maxed,
		forSale = forSale,
		level = level,
		max = max,
		cash = lvl.cash,
		productId = id,
		robux = livePrice[id] or lvl.robux or 0,
		reason = reason,
		busy = busy,
	}
end

local function statusOf(item: DockBlueprints.Item): Status
	local site = siteState()
	if item.kind == "Building" then
		return buildingStatus(item.key, site)
	end
	local entry = entryOf(item)
	local owned = ownedOf(item)
	local forSale = not owned and DockBlueprints.buyable(item)
	local product = entry and entry.product and MonetizationConfig.Products[entry.product]
	local id = if product and product.ready then product.id else 0
	local busy: ("site" | "wait")? = nil
	if forSale and site.key then
		busy = if site.key == item.key then "site" else "wait"
	elseif forSale and type(snapshot.dockPrepaid) == "table" and snapshot.dockPrepaid[item.key] then
		busy = "wait" -- Robux paid: it starts by itself, never offer a second buy
	end
	local reason: Reason? = nil
	if owned then
		reason = { icon = UiImages.VehicleArt.Check, text = "Owned" }
	elseif item.kind == "Blueprint" then
		reason = { icon = "quests", text = "Quest" }
	end
	return {
		owned = owned,
		forSale = forSale,
		level = if owned then 1 else 0,
		max = 1,
		cash = if entry and type(entry.cash) == "number" then entry.cash else 0,
		productId = id,
		robux = livePrice[id] or (entry and entry.robux) or 0,
		reason = reason,
		busy = busy,
	}
end

local function cashBuy(item: DockBlueprints.Item)
	local remote = Net.init():WaitForChild("Dock_Upgrade", 5) :: RemoteFunction?
	if not remote then
		return
	end
	local ok = remote:InvokeServer(item.key)
	if ok then
		-- docs/24 G: a bought building closes the tablet so the player sees the site start
		if displayed and item.kind == "Building" then
			closeBuild()
		end
	else
		shake(if focused then focusStrip else listPanel and listPanel.root)
	end
end

local function robuxBuy(id: number)
	if id == 0 then
		shake(if focused then focusStrip else listPanel and listPanel.root)
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

-- The build tablet's busy state (docs/24 B): the lot being built shows its timer and bar, every other buy
-- button is an hourglass and refuses.
local timerRows: { { label: TextLabel, fill: Frame?, work: number, finish: any? } } = {}
local finishAsked: { [number]: boolean } = {}

-- The FinishNow product for a site's time left, with the live Robux price when there is an id.
local function finishProduct(left: number): (any, number)
	local product = MonetizationConfig.Products[`FinishNow{BuildTimer.finishTier(left)}`]
	if not product then
		return nil, 0
	end
	local id = product.id
	if id ~= 0 and not livePrice[id] and not finishAsked[id] then
		finishAsked[id] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				livePrice[id] = info.PriceInRobux
			end
		end)
	end
	return product, livePrice[id] or product.price
end

-- Unready products stay visible in Studio, like the shelves' coming-soon cards.
local function finishOffered(product: any): boolean
	return product ~= nil
		and (RunService:IsStudio() or (product.ready ~= false and product.id ~= 0))
end

local function itemWork(item: DockBlueprints.Item): number
	if item.kind == "Decor" then
		return BuildTimer.DECOR
	end
	local b = DockConfig.Buildings[item.key]
	if not b then
		return BuildTimer.work(0)
	end
	-- the level going up is the next one (it is not counted until it finishes)
	local n = math.clamp((levelsMap()[item.key] or 0) + 1, 1, #b.levels)
	return BuildTimer.work(b.levels[n].cash)
end

local function hourglass(parent: GuiObject, side: number)
	if Style.iconId("hourglass") then
		local img = Style.icon(parent, "hourglass")
		img.AnchorPoint = Vector2.new(0.5, 0.5)
		img.Position = UDim2.fromScale(0.5, 0.5)
		img.Size = UDim2.fromOffset(side, side)
		return
	end
	local box = Instance.new("Frame")
	box.Name = "Hourglass"
	box.BackgroundTransparency = 1
	box.AnchorPoint = Vector2.new(0.5, 0.5)
	box.Position = UDim2.fromScale(0.5, 0.5)
	box.Size = UDim2.fromOffset(side, side)
	box.Parent = parent
	local function bar(w: number, h: number, x: number, y: number, rot: number)
		local f = Instance.new("Frame")
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.Rotation = rot
		f.Parent = box
	end
	bar(side * 0.55, side * 0.09, 0.5, 0.1, 0) -- caps
	bar(side * 0.55, side * 0.09, 0.5, 0.9, 0)
	local long = side * 0.48
	bar(side * 0.09, long, 0.36, 0.36, 38)
	bar(side * 0.09, long, 0.64, 0.36, -38)
	bar(side * 0.09, long, 0.36, 0.64, -38)
	bar(side * 0.09, long, 0.64, 0.64, 38)
end

local function busyRow(parent: GuiObject, item: DockBlueprints.Item, st: Status)
	local row = Instance.new("Frame")
	row.Name = "Busy"
	row.BackgroundTransparency = 1
	row.Size = UDim2.fromScale(1, 1)
	row.Parent = parent
	if st.busy == "wait" then
		local button = Style.button(row, UDim2.fromScale(1, 1))
		local _, face = Style.block(button, Style.grad("disabled"), { studs = true })
		hourglass(face, 42)
		Style.press(button, function()
			shake(row)
		end)
		return
	end
	local site = siteState()
	local work = itemWork(item)
	local left = BuildTimer.timeLeft(site.progress, site.rate, work)
	local icon = Instance.new("Frame")
	icon.BackgroundTransparency = 1
	icon.Position = UDim2.fromOffset(0, 4)
	icon.Size = UDim2.fromOffset(30, 30)
	icon.Parent = row
	Style.icon(icon, "build")
	local label = Style.label(row, BuildTimer.text(left), Theme.Text.small)
	label.Name = "Timer"
	label.Position = UDim2.fromOffset(38, 4)
	label.Size = UDim2.fromOffset(60, 24)
	label.TextXAlignment = Enum.TextXAlignment.Left
	local product, price = finishProduct(left)
	local finish = PriceButtonUI.new(row, {
		price = price,
		currency = "Robux",
		onActivate = function()
			Net.event("Dock_Finish"):FireServer()
		end,
	})
	finish.root.Name = "Finish"
	finish.root.AnchorPoint = Vector2.new(1, 0.5)
	finish.root.Position = UDim2.fromScale(1, 0.5)
	finish.root.Size = UDim2.new(0.48, -2, 1, 0)
	finish.root.Visible = left >= 3 and finishOffered(product)
	local bolt = Instance.new("Frame")
	bolt.Name = "FinishIcon"
	bolt.BackgroundTransparency = 1
	bolt.Position = UDim2.fromOffset(5, 3)
	bolt.Size = UDim2.fromOffset(22, 22)
	bolt.ZIndex = 3
	bolt.Parent = finish.root
	Style.icon(bolt, "finish_now")
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = C.panelLight
	bar.BackgroundTransparency = 0.4
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 38, 1, -2)
	bar.Size = UDim2.new(0.52, -44, 0, 12)
	Style.corner(bar, S.cornerSmall)
	bar.Parent = row
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = C.gold
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(site.progress, 1)
	Style.corner(fill, S.cornerSmall)
	fill.Parent = bar
	table.insert(timerRows, { label = label, fill = fill, work = work, finish = finish })
end

-- Runs while the tablet is open: the busy lot's clock moves without rebuilding the cards.
local function updateTimers()
	local site = siteState()
	local live = {}
	for _, row in timerRows do
		if row.label.Parent then
			local left = BuildTimer.timeLeft(site.progress, site.rate, row.work)
			row.label.Text = BuildTimer.text(left)
			if row.fill then
				row.fill.Size = UDim2.fromScale(site.progress, 1)
			end
			if row.finish then
				local product, price = finishProduct(left)
				row.finish.setPrice(price)
				row.finish.root.Visible = left >= 3 and finishOffered(product)
			end
			table.insert(live, row)
		end
	end
	timerRows = live
end

-- The Cash button (greyed when the Cash is short) and the Robux button (skips the Cash), side by side in
-- `parent`; only shown once the prerequisites stand. Items without a Robux product get the Cash button alone.
-- docs/24 E: the tutorial's Workshop is always buyable: the server tops the wallet up to its price
-- on the buy (the same coin burst as any purchase), so the greyed short-Cash button never blocks it.
local function tutorialBuild(item: DockBlueprints.Item): boolean
	if item.kind ~= "Building" or item.key ~= Onboarding.WORKSHOP then
		return false
	end
	local site = siteState()
	return Onboarding.beat({
		coldOpenDone = snapshot.coldOpenDone == true or player:GetAttribute("ColdOpenDone") == true,
		totalRescues = tonumber(snapshot.totalRescues)
			or tonumber(player:GetAttribute("Rescued"))
			or 0,
		step = tonumber(snapshot.tutorialStep),
		owned = if type(snapshot.dockBuildings) == "table" then snapshot.dockBuildings else {},
		constructionKey = site.key,
	}) == "BuildStation"
end

local function buyButtons(parent: GuiObject, item: DockBlueprints.Item, st: Status)
	if st.busy then
		busyRow(parent, item, st)
		return
	end
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
		state = if st.cash > (snapshot.cash or 0) and not tutorialBuild(item)
			then "disabled"
			else "buy",
		onActivate = function()
			-- the tutorial top-up is the existing coin burst; the server turns it into the buy
			if st.cash > (snapshot.cash or 0) and tutorialBuild(item) then
				local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
					or Vector2.new(800, 600)
				CashBurst.playAt(playerGui, view / 2, 0, false)
			end
			cashBuy(item)
		end,
	})
	cashButton.root.Name = "Cash"
	if st.cash == 0 then
		cashButton.setText("Free")
	end
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

local function colorOf(item: DockBlueprints.Item): string
	if item.kind == "Building" then
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

local focusItem: (DockBlueprints.Item, number?) -> ()

-- A "Needs" tap: focus what is missing and bring its card into the list's view.
local function jumpTo(need: DockBlueprints.Item)
	focusItem(need)
	local content = cardsContent
	for _, card in cards do
		if content and card:GetAttribute("ItemKey") == need.key then
			local _, scale = Style.metrics(content)
			local dy = (card.AbsolutePosition.Y - content.AbsolutePosition.Y)
				/ math.max(scale, 0.05)
			content.CanvasPosition = Vector2.new(0, math.max(0, content.CanvasPosition.Y + dy - 8))
			if InputGlyph.device() == "Gamepad" then
				GuiService.SelectedObject = card
			end
			break
		end
	end
end

-- The state badge on its own row (never over the title): the reason's icon and label. A prerequisite reason
-- is a chip with that item's drawing; tapping it focuses the prerequisite.
local function badgeRow(parent: GuiObject, st: Status): GuiObject?
	local reason = st.reason
	if not reason then
		return nil
	end
	local need = reason.item
	local row: GuiObject = if need then Style.button(parent, UDim2.new()) else Instance.new("Frame")
	row.Name = "Badge"
	row.BackgroundTransparency = 1
	row.Parent = parent
	local list = Style.list(row, true, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	if need then
		local lock = Instance.new("Frame")
		lock.Name = "Lock"
		lock.BackgroundTransparency = 1
		lock.Size = UDim2.fromOffset(24, 24)
		lock.LayoutOrder = -1
		lock.Parent = row
		Style.icon(lock, "lock")
	end
	local mark = Instance.new("Frame")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromOffset(26, 26)
	mark.Parent = row
	if need then
		drawGlyph(mark, need)
	elseif string.find(reason.icon, "://", 1, true) then
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Image = reason.icon
		img.Size = UDim2.fromScale(1, 1)
		img.Parent = mark
	else
		Style.icon(mark, reason.icon)
	end
	local label = Style.label(row, reason.text, Theme.Text.small)
	label.TextWrapped = false
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, if need then -62 else -32, 1, 0)
	fit(label, Theme.Text.small)
	label.LayoutOrder = 1
	if need and row:IsA("GuiButton") then
		Style.press(row, function()
			jumpTo(need)
		end, S.cornerSmall)
	end
	return row
end

-- A building's level as stars: gold up to the built level (Lv1-Lv3; HQ and Bunkhouse up to 5).
local function stars(parent: GuiObject, st: Status): Frame
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.BackgroundTransparency = 1
	row.Parent = parent
	Style.list(row, true, 2)
	for i = 1, st.max do
		local star = Instance.new("ImageLabel")
		star.Name = `Star{i}`
		star.BackgroundTransparency = 1
		star.Image = if i <= st.level then UiImages.Badges.StarOn else UiImages.Badges.StarOff
		star.ScaleType = Enum.ScaleType.Fit
		star.Size = UDim2.fromOffset(24, 24)
		star.Parent = row
		star.LayoutOrder = i
	end
	return row
end

-- The HQ card (docs/25 A): what the next HQ level needs, every building the current HQ offers, ticked once
-- built (UnlockTree.nextHqNeed lists the unticked ones). Tapping an icon focuses that building.
local function hqNeeds(parent: GuiObject): Frame?
	local levels = levelsMap()
	local hq = levels.HQ or 0
	if hq < 1 or hq >= UnlockTree.maxLevel("HQ") then
		return nil
	end
	local row = Instance.new("Frame")
	row.Name = "HqNeeds"
	row.BackgroundTransparency = 1
	row.Parent = parent
	Style.list(row, true, 6)
	for i, key in DockConfig.BUILDINGS do
		if key ~= "HQ" and DockConfig.Buildings[key].unlockAt <= hq then
			local need: DockBlueprints.Item = { kind = "Building", key = key }
			local chip = Style.button(row, UDim2.fromOffset(28, 28))
			chip.Name = key
			chip.LayoutOrder = i
			drawGlyph(chip, need)
			if (levels[key] or 0) >= 1 then
				local tick = Instance.new("Frame")
				tick.Name = "Tick"
				tick.AnchorPoint = Vector2.new(0.5, 0.5)
				tick.Position = UDim2.fromScale(0.9, 0.1)
				tick.Size = UDim2.fromOffset(16, 16)
				tick.BackgroundColor3 = Color3.new(1, 1, 1)
				tick.ZIndex = 4
				tick.Parent = chip
				Style.corner(tick, 8)
				Style.gradient(tick, Style.grad("buy"))
				Style.stroke(tick, 2, true)
				Glyph.draw("check", tick, Color3.new(1, 1, 1))
			end
			Style.press(chip, function()
				jumpTo(need)
			end, S.cornerSmall)
		end
	end
	return row
end

-- docs/24 E, docs/25 J: the card the tutorial points at wears a steady gold outline that pops in once
-- (never a blinking pulse: owner 2026-10-28).
local function pulseRing(face: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Pulse"
	stroke.Color = OUTLINE
	stroke.Thickness = 10
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = face
	TweenService:Create(
		stroke,
		TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Thickness = 5 }
	):Play()
end

-- The cards of the open tab: Build (one per building, then the quest blueprints) or Decor.
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
	local pulsed: ImageButton? = nil
	for _, item in DockBlueprints.catalog() do
		if (item.kind == "Decor") == (tabIndex == 2) then
			n += 1
			local st = statusOf(item)
			local root = Style.button(
				content,
				UDim2.new(1, -8, 0, if st.forSale then CARD_BUY_H else CARD_H)
			)
			root.Name = `Card{n}`
			root.LayoutOrder = n
			root:SetAttribute("ItemKey", item.key)
			local locked = not st.owned and not st.forSale
			local _, face =
				Style.block(root, Style.grad(if locked then "locked" else colorOf(item)))
			local well = artWell(face, item, 76)
			well.Position = UDim2.fromOffset(10, 10)
			local title =
				Style.label(face, DockBlueprints.label(item, st.level), Theme.Text.heading)
			title.Name = "Title"
			title.Position = UDim2.fromOffset(98, 8)
			title.Size = UDim2.new(1, -108, 0, 32)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = false
			title.TextTruncate = Enum.TextTruncate.AtEnd
			fit(title, Theme.Text.heading)
			local y = 48
			if item.kind == "Building" then
				local row = stars(face, st)
				row.Position = UDim2.fromOffset(98, 37)
				row.Size = UDim2.new(1, -108, 0, 24)
				y = 62 -- the badge row ends above the buy slot (SE: "Free" covered "Build")
			end
			local needs = if item.kind == "Building" and item.key == "HQ"
				then hqNeeds(face)
				else nil
			local badge: GuiObject? = needs or badgeRow(face, st)
			if badge then
				badge.Position = UDim2.fromOffset(98, y)
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
			if pulseKey == item.key then
				pulseRing(face)
				pulsed = root
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
		GuiService.SelectedObject = pulsed or cards[1]
	end
end

-- docs/24 E, docs/25 J: the tutorial points at the HQ / Workshop card while its beat is up; nil stops the pulse.
function DockController.Pulse(key: string?)
	pulseKey = key
	if not displayed then
		return
	end
	if key and tabIndex ~= 1 then
		pickTab(1) -- the pointed card lives on the Build tab
	else
		refreshCards()
	end
end

-- The focus strip: the item's drawing, name and the two buy buttons (or its badge); no sentence (show, don't tell).
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
	-- keep the Hud's Cash counter (desktop: left edge, under the menu) clear: start right of any left-half HUD
	-- box in the strip's band
	local canvas = holder.Parent :: Frame
	local s = tonumber(canvas:GetAttribute("KitScale")) or 1
	local vp = canvas.AbsoluteSize
	local bottom = vp.Y - S.margin * s
	local top = bottom - STRIP_H * s
	local left = S.margin
	for _, box in Layout.hudBoxes() do
		if box.min.X < vp.X / 2 and box.max.Y > top and box.min.Y < bottom then
			left = math.max(left, box.max.X / s + S.margin)
		end
	end
	holder.Position = UDim2.new(0, left, 1, -S.margin)
	holder.Size = UDim2.new(1, -(LIST_W + 2 * S.margin + left), 0, STRIP_H)
	local st = statusOf(item)
	local well = artWell(content, item, 96)
	well.AnchorPoint = Vector2.new(0, 0.5)
	well.Position = UDim2.fromScale(0, 0.5)
	local buyW = if st.forSale then (if st.productId ~= 0 then 350 else 175) else 0
	local words = Instance.new("Frame")
	words.Name = "Words"
	words.BackgroundTransparency = 1
	words.Position = UDim2.fromOffset(112, 0)
	words.Size = UDim2.new(1, -112 - buyW - 12, 1, 0)
	words.Parent = content
	local name = Style.label(words, DockBlueprints.label(item, st.level), Theme.Text.heading)
	name.Size = UDim2.new(1, 0, 0, 36)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
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
	end
end

local function islandView(duration: number)
	local b = plotFrame
	if b then
		fly(DockBuild.camera(b, DockBuild.ISLAND_RADIUS, aspect(), nil, free()), duration)
	end
end

-- Focus on tap (docs/25 J): zoom to an item's building or its empty lot and show its strip. `room` widens the view
-- (a building going up is taller than its footprint).
focusItem = function(item: DockBlueprints.Item, room: number?)
	local b = plotFrame
	if not b then
		return
	end
	focused = item
	local spot, size = DockBuild.spot(item)
	outlineSpot(b * spot, size)
	local at, paperSize = DockBuild.paper(item, b)
	fly(DockBuild.focus(b, at.Position, paperSize * (room or 1), aspect(), free()), 0.6)
	refreshStrip()
	AudioController.play("UI_Click")
end

local function unfocus()
	focused = nil
	clearOutline()
	refreshStrip()
	islandView(0.6)
end

-- Build mode is a full-screen view: the world HUD (minimap, map, waypoints, ops, dev button) steps aside so
-- the cards and the strip read; the main Hud (Cash) stays. The left menu buttons covered the plot (phones) and
-- half of a focused lot (desktop), so Menu hides them under the BuildHidesMenu attribute; on phones the list
-- covers the Cash corner too, so HudController hides it under BuildHidesWallet.
-- shortcut: keyed by ScreenGui name; switch to a HUD hide API if the HUD gets one.
local HUD_KEEP =
	{ Hud = true, Menu = true, BuildTablet = true, Freecam = true, ProximityPrompts = true }
local hiddenGuis: { ScreenGui } = {}

local function hideHud(on: boolean)
	local vp = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize or Vector2.zero
	player:SetAttribute("BuildHidesMenu", on or nil)
	player:SetAttribute("BuildHidesWallet", on and Theme.compact(vp, Theme.scaleFor(vp)) or nil)
	if on then
		for _, g in playerGui:GetChildren() do
			if g:IsA("ScreenGui") and g.Enabled and not HUD_KEEP[g.Name] then
				g.Enabled = false
				table.insert(hiddenGuis, g)
			end
		end
	else
		for _, g in hiddenGuis do
			g.Enabled = true
		end
		hiddenGuis = {}
	end
end

closeBuild = function()
	if not displayed then
		return
	end
	displayed = false
	focused = nil
	clearOutline()
	refreshStrip()
	hideHud(false)
	if ui then
		ui.Enabled = false
	end
	modal.close()
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
	refreshStrip()
end

local syncingTabs = false

local function showTab()
	local p = listPanel
	if p then
		p.root.Visible = displayed
	end
	if not displayed then
		return
	end
	refreshCards()
	refreshStrip()
	if p then
		p.body.CanvasPosition = Vector2.zero
		if InputGlyph.device() == "Gamepad" and cards[1] then
			GuiService.SelectedObject = cards[1]
		end
	end
end

pickTab = function(i: number)
	tabIndex = i
	syncingTabs = true
	local tabs = decorTabs
	if tabs then
		tabs.select(i)
	end
	syncingTabs = false
	showTab()
end

local function onTab(i: number)
	if syncingTabs then
		return
	end
	pickTab(i)
	AudioController.play("UI_Click")
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
	-- phones: the full-height list starts under the Roblox top bar (the strip keeps the full screen)
	local listArea = Instance.new("Frame")
	listArea.Name = "ListArea"
	listArea.BackgroundTransparency = 1
	listArea.Parent = gui
	local function fitListArea()
		local vp = gui.AbsoluteSize
		local top = if Theme.compact(vp, Theme.scaleFor(vp)) then GuiService:GetGuiInset().Y else 0
		listArea.Position = UDim2.fromOffset(0, top)
		listArea.Size = UDim2.new(1, 0, 1, -top)
	end
	fitListArea()
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitListArea)

	-- the Kit panel docked on the right, full height, Build / Decor tabs on top
	local p = PanelUI.new(Style.canvas(listArea), {
		title = "Build",
		icon = "build",
		size = Vector2.new(LIST_W, 2000),
		tabs = true,
		onClose = closeBuild,
	})
	p.root.AnchorPoint = Vector2.new(1, 0.5)
	p.root.Position = UDim2.new(1, -S.margin, 0.5, 0)
	p.root.Visible = false
	listPanel = p
	cardsContent = p.body
	decorTabs = TabsUI.new(
		p.top,
		{ { name = "Build", icon = "build" }, { name = "Decor", icon = "gift" } },
		onTab
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
	hideHud(true)
	local p = listPanel :: PanelUI.Panel
	if pulseKey then
		tabIndex = 1 -- the tutorial's card lives on the Build tab
	end
	pickTab(tabIndex)
	Style.pop(p.root, true)
	modal.open(p.closeButton)
	if InputGlyph.device() == "Gamepad" and cards[1] then
		local want = cards[1]
		for _, card in cards do
			if card:GetAttribute("ItemKey") == pulseKey then
				want = card
			end
		end
		GuiService.SelectedObject = want
	end
	islandView(0.8)
	AudioController.play("UI_Click")
end

-- A click / tap on the island in build mode backs out of the focus (the cards are the way in).
local function onWorldTap(input: InputObject, processed: boolean)
	if not displayed or processed or not focused then
		return
	end
	local kind = input.UserInputType
	if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
		unfocus()
	end
end

-- The Lego build beat (WP-14c): each part of a freshly built model drops from above with a stagger,
-- lands with a squash and a snap, then a dust ring (VFXKit place_dust). Client tweens only; the server owns the final
-- positions, so skipping this (a missed event) just shows the finished building.
local function snapSound(at: Vector3)
	AudioController.play("UI_Click", at, 0.5)
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
	local size = model:GetExtentsSize()
	task.delay(
		last + 0.1,
		function() -- the last brick lands: a studded dust ring round it and a soft thud
			VFXKit.play("place_dust", CFrame.new(at), { radius = math.max(size.X, size.Z) * 0.5 })
		end
	)
end

-- A purchase (a building or decor landed, seen through the attributes): the till and the coin burst.
local function refresh()
	if type(player:GetAttribute("DockPlot")) ~= "number" then
		return
	end
	local count = 0
	for _, n in levelsMap() do
		count += n -- an upgrade rings the till too
	end
	for _, key in DockConfig.DECOR do
		if player:GetAttribute("Decor" .. key) == true then
			count += 1
		end
	end
	if shownCount and count > shownCount then
		AudioController.play("Shop_Till")
		AudioController.play("FX_Pop", nil, 0.8, 1.15)
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(800, 600)
		CashBurst.playAt(playerGui, view / 2, 0, false)
	end
	shownCount = count
end

-- docs/25 A: a bobbing green Lego arrow over every built building you can upgrade right now (allowed and
-- affordable, no site running, not Robux-paid already); none when nothing is possible. A flat sticker sprite
-- (CLAUDE.md "UI art": art/source/ui/build_arrow.svg) at a fixed screen size, ~40 pt on a phone, its tip on the
-- spot; no particles, no glow (docs/25 J). Seen from the third-person camera, the build view too.
local arrows: { [string]: BasePart } = {}
local arrowAt: { [string]: Vector3 } = {}
local ARROW_BOB = 6 -- px

local function arrowSize(): UDim2
	local w = math.round(56 * Layout.current().scale) -- 39 px on a phone (scale 0.7), 56 at 720p, 84 at 1080p
	return UDim2.fromOffset(w, math.round(w * 516 / 392) + ARROW_BOB) -- the sprite's 392 x 516 px
end

local function makeArrow(): BasePart
	local p = Instance.new("Part")
	p.Name = "BuildArrow"
	p.Size = Vector3.one
	p.Transparency = 1
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
		true, false, false, false, false
	local bb = Instance.new("BillboardGui")
	bb.Name = "Sprite"
	bb.Size = arrowSize()
	bb.SizeOffset = Vector2.new(0, 0.5) -- the gui's bottom (the tip) sits on the spot
	bb.LightInfluence = 0
	bb.MaxDistance = 1000
	bb.Adornee = p
	bb.Parent = p
	local img = Instance.new("ImageLabel")
	img.Name = "Arrow"
	img.BackgroundTransparency = 1
	img.Image = UiImages.Markers.BuildArrow
	img.ScaleType = Enum.ScaleType.Fit
	img.AnchorPoint = Vector2.new(0.5, 1)
	img.Position = UDim2.fromScale(0.5, 1)
	img.Size = UDim2.new(1, 0, 1, -ARROW_BOB)
	img.Parent = bb
	return p
end
Layout.onMetrics(function()
	for _, p in arrows do
		(p:FindFirstChild("Sprite") :: BillboardGui).Size = arrowSize()
	end
end)

-- Over the standing building (its top), or high over its empty lot.
local function arrowSpot(key: string): Vector3?
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return nil
	end
	local spot = (bay :: CFrame) * DockConfig.Buildings[key].spot
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local pm = if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
	local built = pm and pm:FindFirstChild(key)
	if built and built:IsA("Model") then
		local cf, size = built:GetBoundingBox()
		return Vector3.new(spot.X, cf.Y + size.Y / 2 + 3, spot.Z)
	end
	-- high over an empty lot: lower, the sprite stood in front of the island's name sign seen from the jetty (des1)
	return spot.Position + Vector3.new(0, 14, 0)
end

local function refreshArrows()
	local want: { [string]: Vector3 } = {}
	if not siteState().key then
		local levels = levelsMap()
		local cash = tonumber(snapshot.cash) or 0
		local prepaid = if type(snapshot.dockPrepaid) == "table" then snapshot.dockPrepaid else {}
		for _, key in DockConfig.BUILDINGS do
			local have = levels[key] or 0
			-- upgrades only: over an empty lot the arrow pointed at bare ground (owner, 2026-10-28); new builds are
			-- found through the Next chip and the build tablet
			local at = if prepaid[key] or have < 1 then nil else arrowSpot(key)
			if at and UnlockTree.canBuild(key, have + 1, levels, cash) then
				want[key] = at
			end
		end
	end
	for key, m in arrows do
		if not want[key] then
			m:Destroy()
			arrows[key] = nil
		end
	end
	for key in want do
		local m = arrows[key] or makeArrow()
		m.Parent = Workspace
		arrows[key] = m
	end
	arrowAt = want
end

type Booth = { gui: ScreenGui, pickers: { CosmeticPicker.Picker } }
local booth: Booth? = nil
local inBooth = false
local boothSeat: BasePart? = nil
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
	local b = player:GetAttribute("BayCFrame")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local now = false
	if seat and player:GetAttribute("DockBoathouse") == true and typeof(b) == "CFrame" then
		local zone = DockConfig.PAINT_BOOTH
		local d = ((b :: CFrame) * zone.cf):PointToObjectSpace(seat.Position)
		local h = zone.size / 2
		now = math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
	end
	if seat ~= boothSeat then
		-- sitting down (a launch seats you inside the booth) or getting up closes it: drive in to paint
		boothSeat, inBooth = seat, now
		closeBooth()
	elseif now ~= inBooth then
		inBooth = now
		if now then
			openBooth()
		else
			closeBooth()
		end
	end
end

-- The Next chip (UI/NextChip) opens the tablet when the player already stands at the station.
function DockController.OpenBuild(): boolean
	if not displayed then
		openBuild()
	end
	return displayed
end

function DockController.Init()
	modal = InputGlyph.modal("BuildTablet", back)
	boothModal = InputGlyph.modal("PaintBooth", closeBooth)
end

function DockController.Start()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
			refreshArrows()
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
			refreshArrows()
			if displayed then
				refreshCards()
				refreshStrip()
			end
		end
	end)
	local function onProgress()
		refresh()
		refreshArrows()
		if displayed then
			redraw()
		end
	end
	player:GetAttributeChangedSignal("DockPlot"):Connect(onProgress)
	for _, key in DockConfig.BUILDINGS do
		player:GetAttributeChangedSignal("Dock" .. key):Connect(onProgress)
		player:GetAttributeChangedSignal(`DockLevel{key}`):Connect(onProgress)
	end
	for _, key in DockConfig.DECOR do
		player:GetAttributeChangedSignal("Decor" .. key):Connect(onProgress)
	end
	refresh()
	RunService.Heartbeat:Connect(function()
		if next(arrows) == nil then
			return
		end
		-- the bob is in screen px (a stud bob vanished at range): the sprite rides up and down in its gui
		local bob = UDim2.new(0.5, 0, 1, -ARROW_BOB * (0.5 + 0.5 * math.sin(os.clock() * 3)))
		for key, p in arrows do
			local at = arrowAt[key]
			if at then
				p.CFrame = CFrame.new(at)
				local img = p:FindFirstChild("Arrow", true) :: ImageLabel?
				if img then
					img.Position = bob
				end
			end
		end
	end)
	UserInputService.InputBegan:Connect(onWorldTap)
	-- Escape backs out (focus first, then build mode); ContextActionService never sees it, so read it here
	UserInputService.InputBegan:Connect(function(input: InputObject)
		if displayed and input.KeyCode == Enum.KeyCode.Escape then
			back()
		end
	end)
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
					local decor = parent == "Decorations"
					if
						displayed
						and plot == player:GetAttribute("DockPlot")
						and (
							if decor
								then DockConfig.Decorations[name]
								else DockConfig.Buildings[name]
						)
					then
						-- my own build while the tablet is up: watch the bricks land (left of the list)
						focusItem(
							{ kind = if decor then "Decor" else "Building", key = name } :: any,
							2.2
						)
					end
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
					prompt.MaxActivationDistance = 15 -- 12 missed it from the dock side (13 studs, playtest 2026-10-28)
					prompt.RequiresLineOfSight = false
					prompt.Parent = tablet
					prompt.Triggered:Connect(openBuild)
				end
			end
			refreshArrows() -- buildings stream in and out: the arrows follow their tops
			task.wait(2)
		end
	end)
	-- a new / finished site moves the arrows and, while the tablet is open, redraws the cards; the busy
	-- lot's timer moves without a rebuild (docs/24 B)
	task.spawn(function()
		local lastKey: string? = nil
		local lastProgress = -1
		while true do
			local site = siteState()
			if site.key ~= lastKey then
				lastKey, lastProgress = site.key, site.progress
				refreshArrows()
				if displayed then
					refreshCards()
					refreshStrip()
				end
			elseif displayed and site.progress ~= lastProgress then
				lastProgress = site.progress
				updateTimers()
			end
			task.wait(0.5)
		end
	end)
	-- close if a teleport (or respawn) takes the player off the station, or a seat (a launch) takes them
	task.spawn(function()
		while true do
			if displayed and stationPos then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local hum = character and character:FindFirstChildOfClass("Humanoid")
				local at = if root and root:IsA("BasePart") then root.Position else nil
				if not at or (at - stationPos).Magnitude > 90 or (hum and hum.SeatPart) then
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
