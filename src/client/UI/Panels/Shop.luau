--!strict
-- Shop panel: the kit Store. Passes / Day passes / Items from ProductShelves, live Roblox prices,
-- owned ticks, day-pass clocks, and the same prompt gating as the world shelves.
local ContextActionService = game:GetService("ContextActionService")
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
local Telemetry = require(script.Parent.Parent.Parent:WaitForChild("Telemetry"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Panel = require(Kit:WaitForChild("Panel"))
local PriceButton = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))

local config: any = MonetizationConfig
local player = Players.LocalPlayer
local studio = RunService.IsStudio()
local PENDING_TIMEOUT = 30
local CATALOGUE_TTL = 20
local TABS = {
	{ id = "Passes", name = "Passes", color = "orange" },
	{ id = "DayPasses", name = "Day pass", color = "blue" },
	{ id = "Items", name = "Items", color = "purple" },
}

type Ref = ProductShelves.ItemRef
type Card = {
	ref: Ref,
	row: Frame,
	art: Frame,
	icon: ImageLabel,
	line: TextLabel,
	price: PriceButton.PriceButton,
}

local Shop = {}

local function clock(seconds: number): string
	local h, m = seconds // 3600, (seconds % 3600) // 60
	return if h > 0 then `{h}h {m}m` else `{math.max(m, 1)}m`
end

local function glyphFor(item: any): string
	if item.cashMultiplier or item.cashMinutes or item.cashOnce then
		return "cash"
	elseif item.dayPassFor == "QuickLaunch" or item.name == "Quick Launch" then
		return "boost"
	end
	return "boat_to_me"
end

function Shop.new(canvas: Frame, onClose: () -> ())
	local panel = Panel.new(canvas, {
		title = "Shop",
		icon = "shop",
		size = Vector2.new(760, 580),
		tabs = true,
		onClose = onClose,
	})

	local tabButtons: { ImageButton } = {}
	local tabHolders: { Frame } = {}
	local tab = 1
	local cards: { Card } = {}
	local catalogue: { [string]: { [string]: any } } = {}
	local catalogueAt = -math.huge
	local fetching = false
	local prices: { [number]: number | false } = {}
	local icons: { [number]: string } = {}
	local infoFetching: { [number]: boolean } = {}
	local pendingKey: string? = nil
	local pendingAt = 0
	local setTab: (number) -> ()

	local tabRow = Instance.new("Frame")
	tabRow.Name = "ShopTabs"
	tabRow.BackgroundTransparency = 1
	tabRow.Size = UDim2.fromScale(1, 1)
	tabRow.Parent = panel.top
	local list = Style.list(tabRow, true, 10)
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	for i, t in TABS do
		local b = Style.button(tabRow, UDim2.new(1 / #TABS, -8, 0, Theme.Size.tab - 6))
		b.Name = "Tab_" .. t.id
		b.LayoutOrder = i
		local holder = Style.block(b, Style.grad("blue"), {
			lip = 5,
			radius = Theme.Size.cornerSmall,
		})
		local label = Style.label(holder, t.name, Theme.Text.body)
		label.TextWrapped = false
		Style.press(b, function()
			setTab(i)
		end, Theme.Size.cornerSmall)
		tabButtons[i] = b
		tabHolders[i] = holder
	end

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
			if panel.isOpen() then
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
				local ok, result = pcall(function()
					return remote:InvokeServer()
				end)
				if ok and type(result) == "table" then
					local fresh: { [string]: { [string]: any } } = {}
					for _, entry in result do
						if type(entry) == "table" and type(entry.key) == "string" then
							fresh[`{entry.kind}/{entry.key}`] = entry
						end
					end
					catalogue = fresh
					catalogueAt = os.clock()
				end
			end
			fetching = false
			if panel.isOpen() then
				paint()
			end
		end)
	end

	local function buy(ref: Ref)
		local item = itemOf(ref)
		local ctx = contextFor(ref)
		if passOwnedFor(item) or not ProductShelves.mayPrompt(config, ref, ctx) then
			return
		end
		pendingKey, pendingAt = keyOf(ref), os.clock()
		paint()
		Telemetry.shop("BuyTapped", "Store", ref.key, "Robux")
		local ok, err = pcall(function()
			if ref.kind == "GamePasses" then
				MarketplaceService:PromptGamePassPurchase(player, item.id)
			else
				MarketplaceService:PromptProductPurchase(player, item.id)
			end
		end)
		if not ok then
			warn("[Shop] prompt failed:", err)
			pendingKey = nil
			paint()
		end
	end

	local function newCard(ref: Ref, order: number, color: string): Card
		local item = itemOf(ref)
		local row = Instance.new("Frame")
		row.Name = ref.key
		row.LayoutOrder = order
		row.Size = UDim2.new(1, 0, 0, 124)
		row.BackgroundTransparency = 1
		row.Parent = panel.body
		local _, face = Style.block(row, Style.grad(color))

		local art = Instance.new("Frame")
		art.Name = "Art"
		art.BackgroundColor3 = Color3.new(1, 1, 1)
		art.BackgroundTransparency = 0.58
		art.AnchorPoint = Vector2.new(0, 0.5)
		art.Position = UDim2.new(0, 12, 0.5, 0)
		art.Size = UDim2.fromOffset(88, 88)
		Style.corner(art, Theme.Size.cornerSmall)
		art.Parent = face
		local glyph = Instance.new("Frame")
		glyph.BackgroundTransparency = 1
		glyph.Size = UDim2.fromScale(0.78, 0.78)
		glyph.AnchorPoint = Vector2.new(0.5, 0.5)
		glyph.Position = UDim2.fromScale(0.5, 0.5)
		glyph.Parent = art
		Style.icon(glyph, glyphFor(item))
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.Visible = false
		icon.Parent = art

		local words = Instance.new("Frame")
		words.Name = "Words"
		words.BackgroundTransparency = 1
		words.Position = UDim2.fromOffset(114, 10)
		words.Size = UDim2.new(1, -300, 1, -20)
		words.Parent = face
		local title = Style.label(words, item.name, Theme.Text.heading)
		title.Name = "Title"
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextWrapped = false
		title.TextTruncate = Enum.TextTruncate.AtEnd
		title.Size = UDim2.new(1, 0, 0, 40)
		local line = Style.label(words, "", Theme.Text.small)
		line.Name = "Line"
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.TextTruncate = Enum.TextTruncate.AtEnd
		line.Position = UDim2.fromOffset(0, 44)
		line.Size = UDim2.new(1, 0, 0, 32)

		local price = PriceButton.new(face, {
			price = 0,
			currency = "Robux",
			onActivate = function()
				buy(ref)
			end,
		})
		price.root.AnchorPoint = Vector2.new(1, 0.5)
		price.root.Position = UDim2.new(1, -12, 0.5, 0)
		local check = Instance.new("Frame")
		check.Name = "Owned"
		check.BackgroundTransparency = 1
		check.AnchorPoint = Vector2.new(1, 1)
		check.Position = UDim2.new(1, -16, 1, -10)
		check.Size = UDim2.fromOffset(28, 28)
		check.Visible = false
		check.Parent = face
		Style.icon(check, "daily")

		return { ref = ref, row = row, art = art, icon = icon, line = line, price = price }
	end

	paint = function()
		for _, card in cards do
			local item = itemOf(card.ref)
			local id = if type(item.id) == "number" then item.id else 0
			fetchInfo(card.ref)
			local ctx = contextFor(card.ref)
			local state = ProductShelves.cardState(config, card.ref, ctx)
			local owned = state.status == "owned" or passOwnedFor(item)
			card.row.Visible = state.status ~= "hidden" and state.status ~= "comingSoon"
			card.icon.Image = icons[id] or ""
			card.icon.Visible = icons[id] ~= nil
			local left = dayLeft(item)
			if owned then
				card.price.setState("owned")
				card.price.setText(if left > 0 then clock(left) else nil)
			elseif state.canBuy and ctx.price then
				card.price.setState("buy")
				card.price.setText(nil)
				card.price.setPrice(ctx.price)
			else
				card.price.setState("disabled")
				card.price.setText(state.buyText)
			end
			local cash = ProductShelves.packCash(item, numberAttr("CashPerMinute"))
			card.line.Text = if left > 0
				then `Active · {clock(left)}`
				elseif cash then `+{ProductShelves.formatNumber(cash)} Cash`
				elseif ctx.pending then "Opening Roblox…"
				else ""
		end
	end

	setTab = function(i: number)
		tab = math.clamp(i, 1, #TABS)
		for n, holder in tabHolders do
			Style.recolor(holder, Style.grad(if n == tab then "yellow" else "blue"))
			tabButtons[n].Size =
				UDim2.new(1 / #TABS, -8, 0, if n == tab then Theme.Size.tab else Theme.Size.tab - 8)
		end
		for _, card in cards do
			card.row:Destroy()
		end
		table.clear(cards)
		local t = TABS[tab]
		for order, ref in ProductShelves.storeItems(config, t.id, studio) do
			table.insert(cards, newCard(ref, order, t.color))
		end
		panel.body.CanvasPosition = Vector2.zero
		fetchCatalogue(false)
		paint()
		Telemetry.shop("ItemViewed", "Store", nil, "Robux")
		if UserInputService.GamepadEnabled and panel.isOpen() and cards[1] then
			pcall(function()
				game:GetService("GuiService").SelectedObject = cards[1].price.root
			end)
		end
	end

	local function stepTabs(input: InputObject)
		if not panel.isOpen() then
			return
		end
		local step = if input.KeyCode == Enum.KeyCode.ButtonL2 then -1 else 1
		setTab((tab - 1 + step) % #TABS + 1)
	end
	ContextActionService:BindActionAtPriority("Shop_Tabs", function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if input.KeyCode == Enum.KeyCode.ButtonL2 or input.KeyCode == Enum.KeyCode.ButtonR2 then
			if not panel.isOpen() then
				return Enum.ContextActionResult.Pass
			end
			stepTabs(input)
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2)

	local function purchaseFinished()
		pendingKey = nil
		fetchCatalogue(true)
		if panel.isOpen() then
			paint()
		end
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(purchaseFinished)
	MarketplaceService.PromptProductPurchaseFinished:Connect(purchaseFinished)
	player.AttributeChanged:Connect(function(attr)
		if
			string.sub(attr, 1, 5) == "Pass_"
			or string.sub(attr, 1, 8) == "DayPass_"
			or attr == "CashPacksToday"
			or attr == "CashPerMinute"
			or attr == "OpsCompleted"
		then
			if panel.isOpen() then
				paint()
			end
		end
	end)
	task.spawn(function()
		local remote = Net.init():WaitForChild("Monetization_Purchased", 30)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(purchaseFinished)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.isOpen() then
				paint()
			end
		end
	end)

	setTab(1)

	return {
		open = function()
			panel.open()
			setTab(tab)
			Telemetry.shop("AppOpened", "Store")
			if UserInputService.GamepadEnabled and cards[1] then
				pcall(function()
					game:GetService("GuiService").SelectedObject = cards[1].price.root
				end)
			end
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Shop
