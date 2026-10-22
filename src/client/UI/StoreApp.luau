--!strict
-- StoreApp: the phone's Store (user 2026-10-21: "an actual store for passes, day passes + developer
-- products"). Three tabs, Passes / Day Passes / Items (ProductShelves.storeItems), over a two-column grid
-- of navy HUD cards (Hud.Panel skin): big icon, white name, an orange price chip with the live Roblox price (GetProductInfo, never the config number), a tick once
-- a pass is owned, a clock chip while a day pass runs, the exact Cash on a Cash pack. Tapping a card opens
-- the Roblox purchase prompt, gated like the world cards by ProductShelves.cardState / mayPrompt (offered
-- in Monetization_GetCatalogue, a real id, the price loaded). Rule 6: no prices before three operations.
-- Touch / mouse: tap; keyboard: Left / Right switch tabs; gamepad: L2 / R2 switch tabs, d-pad + A buy.
--   StoreApp.mount(page: Frame) -> cleanup
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))

local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local player = Players.LocalPlayer
local config: any = MonetizationConfig
local studio = RunService:IsStudio()

local ACTION_TAB = "StoreApp_Tab"
local CATALOGUE_TTL = 20
local PENDING_TIMEOUT = 30
local TAB_H = 56
local INK = Color3.fromHex("1B2430")
local WHITE = Color3.new(1, 1, 1)
local GREEN = Color3.fromHex("38B864")
local TABS = {
	{ id = "Passes", label = "Passes", color = Color3.fromHex("F29A2E") },
	{ id = "DayPasses", label = "Day Pass", color = Color3.fromHex("2FA4E7") },
	{ id = "Items", label = "Items", color = Color3.fromHex("8A5CF0") },
}

type Ref = ProductShelves.ItemRef
type Card = {
	ref: Ref,
	button: TextButton,
	icon: ImageLabel,
	glyph: Frame,
	pill: Frame,
	pillText: TextLabel,
	tick: Frame,
	chip: TextLabel,
}

local StoreApp = {}

local function text(parent: Instance, name: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = HudTheme.HeaderFont
	l.TextSize = size
	l.TextColor3 = color
	l.TextWrapped = true
	l.Text = ""
	l.Parent = parent
	return l
end

-- the glyph that stands for an item when Roblox has no icon for it (id 0, or still loading)
local function glyphFor(item: any): string
	if item.cashMultiplier or item.cashMinutes or item.cashOnce then
		return "coin"
	elseif item.dayPassFor == "QuickLaunch" or item.name == "Quick Launch" then
		return "speed"
	end
	return "boat"
end

local function clock(seconds: number): string
	local h, m = seconds // 3600, (seconds % 3600) // 60
	return if h > 0 then `{h}h {m}m` else `{math.max(m, 1)}m`
end

function StoreApp.mount(page: Frame): () -> ()
	local alive = true
	local conns: { RBXScriptConnection } = {}
	local catalogue: { [string]: { [string]: any } } = {} -- "kind/key" -> entry
	local catalogueAt = -math.huge
	local fetching = false
	local prices: { [number]: number | false } = {} -- id -> Robux (false: failed)
	local icons: { [number]: string } = {}
	local infoFetching: { [number]: boolean } = {}
	local pendingKey: string? = nil
	local pendingAt = 0
	local tabIndex = 1
	local cards: { Card } = {}

	local root = Instance.new("Frame")
	root.Name = "Store"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = page

	local bar = Instance.new("Frame")
	bar.Name = "Tabs"
	bar.Size = UDim2.new(1, 0, 0, TAB_H)
	bar.BackgroundColor3 = HudTheme.Colors.panelLight
	bar.BackgroundTransparency = 0.2
	HudTheme.corner(bar, TAB_H // 2)
	HudTheme.padding(bar, 5)
	bar.Parent = root
	local barLayout = Instance.new("UIListLayout")
	barLayout.FillDirection = Enum.FillDirection.Horizontal
	barLayout.Padding = UDim.new(0, 5)
	barLayout.SortOrder = Enum.SortOrder.LayoutOrder
	barLayout.Parent = bar

	local grid = Instance.new("ScrollingFrame")
	grid.Name = "Grid"
	grid.Position = UDim2.fromOffset(0, TAB_H + 12)
	grid.Size = UDim2.new(1, 0, 1, -(TAB_H + 12))
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Selectable = false
	grid.Parent = root
	local cellPad = Instance.new("UIPadding")
	cellPad.PaddingTop = UDim.new(0, 2)
	cellPad.PaddingBottom = UDim.new(0, 12)
	cellPad.PaddingRight = UDim.new(0, 6)
	cellPad.Parent = grid
	local layout = Instance.new("UIGridLayout")
	layout.CellPadding = UDim2.fromOffset(12, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = grid
	-- cells 4:5, in the phone's design units (a 100 du probe reads the UIScale stack)
	local probe = Instance.new("Frame")
	probe.Name = "Probe"
	probe.Size = UDim2.fromOffset(100, 0)
	probe.BackgroundTransparency = 1
	probe.Parent = root
	local function sizeCells()
		local du = math.max(probe.AbsoluteSize.X, 1) / 100
		local w = (grid.AbsoluteSize.X / du - 6 - 12) / 2
		layout.CellSize = UDim2.new(0.5, -12, 0, math.floor(math.max(w, 80) * 1.32))
	end
	table.insert(conns, probe:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells))
	table.insert(conns, grid:GetPropertyChangedSignal("AbsoluteSize"):Connect(sizeCells))
	sizeCells()

	local curtain = text(root, "Curtain", 24, HudTheme.Colors.textDim)
	curtain.Text = ProductShelves.CURTAIN_TEXT
	curtain.Size = UDim2.new(1, -40, 0, 80)
	curtain.AnchorPoint = Vector2.new(0.5, 0.5)
	curtain.Position = UDim2.fromScale(0.5, 0.45)

	local function keyOf(ref: Ref): string
		return `{ref.kind}/{ref.key}`
	end
	local function itemOf(ref: Ref): any
		return ProductShelves.configItem(config, ref)
	end
	local function numberAttr(name: string): number?
		local v = player:GetAttribute(name)
		return if type(v) == "number" then v else nil
	end
	local function shown(): boolean
		local gui = page:FindFirstAncestorWhichIsA("ScreenGui")
		local holder = page.Parent
		return gui ~= nil
			and gui.Enabled
			and page.Visible
			and (not holder or not holder:IsA("GuiObject") or holder.Visible)
	end
	local function pricedOpen(): boolean
		return true -- user 2026-10-21: phone Store and Robux buttons open from the start (world shelves keep rule 6)
	end
	-- a day pass for a pass bought for good is never sold
	local function passOwnedFor(item: any): boolean
		return item.dayPassFor ~= nil and player:GetAttribute("Pass_" .. item.dayPassFor) == true
	end
	local function dayLeft(item: any): number
		local ends = item.dayPassFor and numberAttr("DayPass_" .. item.dayPassFor)
		return if ends then math.max(0, ends - Workspace:GetServerTimeNow()) else 0
	end

	local function contextFor(ref: Ref): ProductShelves.CardContext
		local item = itemOf(ref)
		local entry = catalogue[keyOf(ref)]
		local id = if item and type(item.id) == "number" then item.id else 0
		local price = prices[id]
		local weather = ReplicatedStorage:FindFirstChild("Weather")
		local stormQueue = weather and weather:GetAttribute("SummonQueue")
		return {
			offered = entry ~= nil and entry.id == id,
			owned = player:GetAttribute("Pass_" .. ref.key) == true
				or (entry ~= nil and entry.owned == true),
			price = if type(price) == "number" then price else nil,
			priceFailed = price == false,
			ownsDoubleCash = player:GetAttribute("Pass_DoubleCash") == true,
			cashPacksToday = numberAttr("CashPacksToday"),
			cashPerMinute = numberAttr("CashPerMinute"),
			stormQueue = if type(stormQueue) == "number" then stormQueue else nil,
			pending = pendingKey == keyOf(ref) and os.clock() - pendingAt < PENDING_TIMEOUT,
		}
	end

	local paint: () -> ()

	local function fetchInfo(ref: Ref)
		local item = itemOf(ref)
		local id = if item and type(item.id) == "number" then item.id else 0
		if id <= 0 or prices[id] ~= nil or infoFetching[id] then
			return
		end
		infoFetching[id] = true
		task.spawn(function()
			local infoType = if ref.kind == "GamePasses"
				then Enum.InfoType.GamePass
				else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			local robux = if ok and type(info) == "table" then info.PriceInRobux else nil
			prices[id] = if type(robux) == "number" then robux else false
			local iconId = if ok and type(info) == "table" then info.IconImageAssetId else nil
			if type(iconId) == "number" and iconId > 0 then
				icons[id] = `rbxassetid://{iconId}`
			end
			infoFetching[id] = nil
			if alive then
				paint()
			end
		end)
	end

	local function fetchCatalogue(force: boolean)
		if fetching or (not force and os.clock() - catalogueAt < CATALOGUE_TTL) then
			return
		end
		fetching = true
		task.spawn(function()
			local remote = Net.init():WaitForChild("Monetization_GetCatalogue", 10)
			if remote and remote:IsA("RemoteFunction") then
				local ok, list = pcall(function()
					return remote:InvokeServer()
				end)
				if ok and type(list) == "table" then
					local fresh: { [string]: { [string]: any } } = {}
					for _, entry in list do
						if type(entry) == "table" and type(entry.key) == "string" then
							fresh[`{entry.kind}/{entry.key}`] = entry
						end
					end
					catalogue = fresh
					catalogueAt = os.clock()
				end
			end
			fetching = false
			if alive then
				paint()
			end
		end)
	end

	local function buy(ref: Ref)
		local item = itemOf(ref)
		local ctx = contextFor(ref)
		if
			not pricedOpen()
			or passOwnedFor(item)
			or not ProductShelves.mayPrompt(config, ref, ctx)
		then
			return
		end
		pendingKey, pendingAt = keyOf(ref), os.clock()
		paint()
		local ok, err = pcall(function()
			if ref.kind == "GamePasses" then
				MarketplaceService:PromptGamePassPurchase(player, item.id)
			else
				MarketplaceService:PromptProductPurchase(player, item.id)
			end
		end)
		if not ok then
			warn("[StoreApp] prompt failed:", err)
			pendingKey = nil
			paint()
		end
	end

	local function newCard(ref: Ref, order: number, color: Color3): Card
		local item = itemOf(ref)
		local b = Instance.new("TextButton")
		b.Name = ref.key
		b.LayoutOrder = order
		b.Text = ""
		b.AutoButtonColor = false
		HudTheme.skin(b) -- the HUD's navy 9-slice, one style with the rest of the HUD
		b.Parent = grid

		local art = Instance.new("Frame")
		art.Name = "Art"
		art.AnchorPoint = Vector2.new(0.5, 0)
		art.Position = UDim2.fromScale(0.5, 0.07)
		art.Size = UDim2.fromScale(0.72, 0.46)
		art.BackgroundColor3 = color
		art.BackgroundTransparency = 0.55
		HudTheme.corner(art, 16)
		art.Parent = b
		local glyph = Instance.new("Frame")
		glyph.Name = "Glyph"
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Size = UDim2.fromScale(0.8, 0.8)
		glyph.BackgroundTransparency = 1
		glyph.Parent = art
		local square = Instance.new("UIAspectRatioConstraint")
		square.Parent = art
		Glyph.draw(glyphFor(item), glyph, WHITE)
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.Size = UDim2.fromScale(1, 1)
		icon.BackgroundTransparency = 1
		icon.Visible = false
		HudTheme.corner(icon, 16)
		icon.Parent = art

		local name = text(b, "Name", 20, WHITE)
		name.Text = item.name
		name.Position = UDim2.fromScale(0.05, 0.55)
		name.Size = UDim2.new(0.9, 0, 0.45, -48) -- down to the price pill
		name.Font = Enum.Font.BuilderSansBold
		name.TextScaled = true
		local cap = Instance.new("UITextSizeConstraint")
		cap.MinTextSize = 18
		cap.MaxTextSize = 22
		cap.Parent = name

		local pill = Instance.new("Frame")
		pill.Name = "Price"
		pill.AnchorPoint = Vector2.new(0.5, 1)
		pill.Position = UDim2.new(0.5, 0, 1, -8)
		pill.Size = UDim2.new(0.84, 0, 0, 34)
		pill.BackgroundColor3 = HudTheme.Colors.accent
		HudTheme.corner(pill, 99)
		pill.Parent = b
		local pillText = text(pill, "Text", 20, WHITE)
		pillText.Font = Enum.Font.BuilderSansBold
		pillText.Size = UDim2.fromScale(1, 1)
		pillText.TextScaled = true
		local pillCap = Instance.new("UITextSizeConstraint")
		pillCap.MinTextSize = 18
		pillCap.MaxTextSize = 22
		pillCap.Parent = pillText
		local tick = Instance.new("Frame")
		tick.Name = "Tick"
		tick.AnchorPoint = Vector2.new(0.5, 0.5)
		tick.Position = UDim2.fromScale(0.5, 0.5)
		tick.Size = UDim2.fromScale(0.3, 1)
		tick.BackgroundTransparency = 1
		Instance.new("UIAspectRatioConstraint").Parent = tick
		Glyph.draw("check", tick, WHITE)
		tick.Parent = pill

		-- top-right: a running day pass's clock, or the exact Cash a pack pays
		local chip = text(b, "Chip", 18, INK)
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, -6, 0, 6)
		chip.Size = UDim2.fromOffset(0, 28)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.TextWrapped = false
		chip.BackgroundColor3 = HudTheme.Colors.gold
		chip.BackgroundTransparency = 0
		chip.ZIndex = 3
		HudTheme.corner(chip, 14)
		local chipPad = Instance.new("UIPadding")
		chipPad.PaddingLeft = UDim.new(0, 8)
		chipPad.PaddingRight = UDim.new(0, 8)
		chipPad.Parent = chip

		b.Activated:Connect(function()
			buy(ref)
		end)
		return {
			ref = ref,
			button = b,
			icon = icon,
			glyph = glyph,
			pill = pill,
			pillText = pillText,
			tick = tick,
			chip = chip,
		}
	end

	paint = function()
		if not alive then
			return
		end
		local open = pricedOpen()
		curtain.Visible = not open
		grid.Visible = open
		for _, card in cards do
			local item = itemOf(card.ref)
			local id = if type(item.id) == "number" then item.id else 0
			fetchInfo(card.ref)
			local ctx = contextFor(card.ref)
			local state = ProductShelves.cardState(config, card.ref, ctx)
			local owned = state.status == "owned" or passOwnedFor(item)
			-- not for sale yet (no id / not offered): left out, not shown as "Coming soon"
			card.button.Visible = state.status ~= "hidden" and state.status ~= "comingSoon"
			card.icon.Image = icons[id] or ""
			card.icon.Visible = icons[id] ~= nil
			card.glyph.Visible = icons[id] == nil
			card.tick.Visible = owned
			card.pill.BackgroundColor3 = if owned
				then GREEN
				elseif state.canBuy then HudTheme.Colors.accent
				else HudTheme.Colors.panelLight
			card.pillText.Visible = not owned
			card.pillText.Text = if state.canBuy and ctx.price
				then `{ProductShelves.ROBUX} {ProductShelves.formatNumber(ctx.price)}`
				else state.buyText
			local left = dayLeft(item)
			local cash = ProductShelves.packCash(item, numberAttr("CashPerMinute"))
			card.chip.Visible = left > 0 or cash ~= nil
			card.chip.Text = if left > 0
				then clock(left)
				elseif cash then `+{ProductShelves.formatNumber(cash)}`
				else ""
			card.chip.BackgroundColor3 = if left > 0 then WHITE else HudTheme.Colors.gold
		end
		for i, tab in TABS do
			local b = bar:FindFirstChild(tab.id)
			if b and b:IsA("TextButton") then
				b.BackgroundColor3 = if i == tabIndex then tab.color else HudTheme.Colors.panelLight
				b.BackgroundTransparency = if i == tabIndex then 0 else 1
				b.TextColor3 = if i == tabIndex then WHITE else HudTheme.Colors.textDim
			end
		end
	end

	local function showTab(i: number)
		tabIndex = math.clamp(i, 1, #TABS)
		for _, card in cards do
			card.button:Destroy()
		end
		table.clear(cards)
		local tab = TABS[tabIndex]
		for order, ref in ProductShelves.storeItems(config, tab.id, studio) do
			table.insert(cards, newCard(ref, order, tab.color))
		end
		grid.CanvasPosition = Vector2.zero
		fetchCatalogue(false)
		paint()
		if UserInputService.GamepadEnabled and shown() and cards[1] then
			GuiService.SelectedObject = cards[1].button
		end
	end

	for i, tab in TABS do
		local b = Instance.new("TextButton")
		b.Name = tab.id
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / #TABS, -4, 1, 0)
		b.Font = HudTheme.HeaderFont
		b.TextSize = 20 -- fixed: 3 tabs of ~80 du fit "Passes" / "Day Pass" / "Items" at 20
		b.Text = tab.label
		b.AutoButtonColor = true
		HudTheme.corner(b, 99)
		b.Parent = bar
		b.Activated:Connect(function()
			showTab(i)
		end)
	end

	ContextActionService:BindActionAtPriority(
		ACTION_TAB,
		function(_, state, input): Enum.ContextActionResult
			if state ~= Enum.UserInputState.Begin or not shown() then
				return Enum.ContextActionResult.Pass
			end
			local step = if input.KeyCode == Enum.KeyCode.Left
					or input.KeyCode == Enum.KeyCode.ButtonL2
				then -1
				else 1
			showTab((tabIndex - 1 + step) % #TABS + 1)
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonL2,
		Enum.KeyCode.ButtonR2
	)

	local function purchaseFinished()
		pendingKey = nil
		fetchCatalogue(true)
		paint()
	end
	table.insert(conns, MarketplaceService.PromptGamePassPurchaseFinished:Connect(purchaseFinished))
	table.insert(conns, MarketplaceService.PromptProductPurchaseFinished:Connect(purchaseFinished))
	table.insert(
		conns,
		player.AttributeChanged:Connect(function(attr: string)
			if
				attr:sub(1, 5) == "Pass_"
				or attr:sub(1, 8) == "DayPass_"
				or attr == "CashPacksToday"
				or attr == "CashPerMinute"
				or attr == "OpsCompleted"
			then
				paint()
			end
		end)
	)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Monetization_Purchased", 30)
		if alive and remote and remote:IsA("RemoteEvent") then
			table.insert(conns, remote.OnClientEvent:Connect(purchaseFinished))
		end
	end)
	task.spawn(function() -- the day pass clocks
		while alive do
			task.wait(1)
			if alive and shown() then
				paint()
			end
		end
	end)

	showTab(1)

	return function()
		alive = false
		ContextActionService:UnbindAction(ACTION_TAB)
		for _, c in conns do
			c:Disconnect()
		end
		root:Destroy()
	end
end

return StoreApp
