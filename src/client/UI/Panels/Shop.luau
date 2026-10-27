--!strict
-- Shop panel: the kit Store. Tabs Passes / Packs / Boosts / Day passes (ProductShelves.storeItems)
-- as kit Cards with live Roblox prices, owned ticks, day-pass clocks, and ProductShelves' prompt
-- gating. Gamepad: L1 / R1 step the tabs.
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
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local Telemetry = require(script.Parent.Parent.Parent:WaitForChild("Telemetry"))
local UnlockTree = require(Shared:WaitForChild("UnlockTree"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Card = require(Kit:WaitForChild("Card"))
local Panel = require(Kit:WaitForChild("Panel"))
local Tabs = require(Kit:WaitForChild("Tabs"))

local config: any = MonetizationConfig
local player = Players.LocalPlayer
local studio = RunService:IsStudio()
local PENDING_TIMEOUT = 30
local CATALOGUE_TTL = 20
local TABS = {
	{ id = "Passes", name = "Passes", icon = "vip", color = "purple" },
	{ id = "Packs", name = "Packs", icon = "cash", color = "yellow" },
	{ id = "Boosts", name = "Boosts", icon = "boost", color = "orange" },
	{ id = "DayPasses", name = "Day", icon = "daily", color = "blue" },
}

type Ref = ProductShelves.ItemRef
type Row = { ref: Ref, card: Card.Card, icon: ImageLabel }

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

	local tab = 1
	local cards: { Row } = {}
	local catalogue: { [string]: { [string]: any } } = {}
	local catalogueAt = -math.huge
	local fetching = false
	local prices: { [number]: number | false } = {}
	local icons: { [number]: string } = {}
	local infoFetching: { [number]: boolean } = {}
	local pendingKey: string? = nil
	local pendingAt = 0
	local setTab: (number) -> ()

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
		local unlock = item and item.vehicle and ProgressionConfig.Vehicles[item.vehicle]
		local need = unlock and unlock.needs
		return {
			needs = if need and player:GetAttribute("Dock" .. need) ~= true
				then UnlockTree.needName(need)
				else nil,
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

	local function newCard(ref: Ref, order: number, color: string): Row
		local item = itemOf(ref)
		local card = Card.new(panel.body, {
			art = glyphFor(item),
			title = item.name,
			line = "",
			color = color,
			price = 0,
			currency = "Robux",
			onBuy = function()
				buy(ref)
			end,
		})
		card.root.Name = ref.key
		card.root.LayoutOrder = order
		local icon = Instance.new("ImageLabel") -- the product's own Roblox icon over the glyph
		icon.Name = "ProductIcon"
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromScale(1, 1)
		icon.ZIndex = 2
		icon.Visible = false
		icon.Parent = card.art
		return { ref = ref, card = card, icon = icon }
	end

	paint = function()
		for _, row in cards do
			local item = itemOf(row.ref)
			local id = if type(item.id) == "number" then item.id else 0
			fetchInfo(row.ref)
			local ctx = contextFor(row.ref)
			local state = ProductShelves.cardState(config, row.ref, ctx)
			local owned = state.status == "owned" or passOwnedFor(item)
			local price = row.card.price
			row.card.root.Visible = state.status ~= "hidden" and state.status ~= "comingSoon"
			row.icon.Image = icons[id] or ""
			row.icon.Visible = icons[id] ~= nil
			local left = dayLeft(item)
			if owned then
				price.setState("owned")
				price.setText(if left > 0 then clock(left) else nil)
			elseif state.canBuy and ctx.price then
				price.setState("buy")
				price.setText(nil)
				price.setPrice(ctx.price)
			else
				price.setState("disabled")
				price.setText(state.buyText)
			end
			local cash = ProductShelves.packCash(item, numberAttr("CashPerMinute"))
			row.card.setLine(
				if left > 0
					then `Active · {clock(left)}`
					elseif cash then `+{ProductShelves.formatNumber(cash)} Cash`
					elseif ctx.pending then "Opening Roblox…"
					else nil
			)
		end
	end

	local tabs = Tabs.new(panel.top, TABS :: any, function(i: number)
		setTab(i)
	end)

	setTab = function(i: number)
		tab = math.clamp(i, 1, #TABS)
		for _, row in cards do
			row.card.root:Destroy()
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
			GuiService.SelectedObject = cards[1].card.price.root
		end
	end

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

	tabs.select(1)

	return {
		open = function()
			panel.open()
			setTab(tab)
			Telemetry.shop("PanelOpened", "Store")
		end,
		close = panel.close,
		isOpen = panel.isOpen,
		root = panel.root,
	}
end

return Shop
