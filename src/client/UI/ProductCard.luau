--!strict
-- ProductCard (RP-M3): the diegetic product cards (docs/04 section 1.1; no shop button, only shops).
-- Shelves are real places tagged ProductShelf = <id> (ChandleryRig on the H2 shop's ATT_ markers, the
-- harbourmaster's desk in map/Build.luau) plus a Quick Launch card on the BoatDesk. This client adds a
-- local ProximityPrompt on each shelf it may see (rule 6: none of the priced shelves before three
-- operations), and the prompt opens a card in the Layout "prompt" region: the place, the item, its exact
-- effect, the live price from MarketplaceService and a Buy button showing that price. Only tapping Buy
-- opens the Roblox prompt (rule 5), and only for an item the server offered (Monetization_GetCatalogue)
-- with a real id (ProductShelves.mayPrompt): id 0 / ready = false items read "Coming soon".
-- Several items on one shelf page with the arrows (gamepad: LB / RB). B or Close shuts the card, and
-- walking away closes it. Rules and copy live in src/shared/ProductShelves.luau (tested).
--
--   ProductCard.mount(onOpen?) -> Card   once, from HudShop.build
--   card.setSnapshot(snapshot)            PlayerDataChanged snapshots (rule 6 gate)
--   card.close() / card.isOpen()
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local HudTheme = require(script.Parent.HudTheme)
local Layout = require(script.Parent.Layout)
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))

local C = HudTheme.Colors
local player = Players.LocalPlayer

export type Card = {
	setSnapshot: (snapshot: { [string]: any }) -> (),
	close: () -> (),
	isOpen: () -> boolean,
}

local DISPLAY_ORDER = 36 -- above the HUD store panels (35), below Cinematic (50)
local PROMPT_DISTANCE = 8
local WALK_AWAY_MARGIN = 6
local CATALOGUE_TTL = 20
local PENDING_TIMEOUT = 30
local ACTION_CLOSE = "ProductCard_Close"
local ACTION_PAGE = "ProductCard_Page"

local ProductCard = {}

local function isGamepad(): boolean
	local t = UserInputService:GetLastInputType()
	return t.Name:sub(1, 7) == "Gamepad"
end

local function anchorPosition(anchor: Instance): Vector3?
	if anchor:IsA("Attachment") then
		return anchor.WorldPosition
	elseif anchor:IsA("BasePart") then
		return anchor.Position
	end
	return nil
end

function ProductCard.mount(onOpen: (() -> ())?): Card
	local studio = RunService:IsStudio()
	local config: any = MonetizationConfig

	-- ---------------------------------------------------------------- view
	local gui = Instance.new("ScreenGui")
	gui.Name = "ProductCard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = DISPLAY_ORDER
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	Layout.prepare(gui)
	gui.Parent = player:WaitForChild("PlayerGui")
	local region = Layout.region(gui, "prompt")

	local frame = HudTheme.panel("Card", UDim2.fromScale(1, 1), region)
	frame.BackgroundTransparency = HudTheme.PromptTransparency
	frame.Visible = false
	HudTheme.padding(frame, 14)

	local place = HudTheme.label(
		"Place",
		"",
		UDim2.new(1, -120, 0, 20),
		HudTheme.BodyFont,
		HudTheme.TextSize.small,
		frame
	)
	place.TextColor3 = C.textDim
	local pager = HudTheme.label(
		"Pager",
		"",
		UDim2.fromOffset(110, 20),
		HudTheme.BodyFont,
		HudTheme.TextSize.small,
		frame
	)
	pager.AnchorPoint = Vector2.new(1, 0)
	pager.Position = UDim2.fromScale(1, 0)
	pager.TextXAlignment = Enum.TextXAlignment.Right
	pager.TextColor3 = C.textDim

	local name = HudTheme.label(
		"Name",
		"",
		UDim2.new(1, -120, 0, 28),
		HudTheme.HeaderFont,
		HudTheme.TextSize.title,
		frame
	)
	name.Position = UDim2.fromOffset(0, 20)
	local tag = HudTheme.label(
		"Tag",
		"",
		UDim2.fromOffset(110, 28),
		HudTheme.HeaderFont,
		HudTheme.TextSize.small,
		frame
	)
	tag.AnchorPoint = Vector2.new(1, 0)
	tag.Position = UDim2.new(1, 0, 0, 20)
	tag.TextXAlignment = Enum.TextXAlignment.Right

	local effect = HudTheme.label(
		"Effect",
		"",
		UDim2.new(1, 0, 1, -136),
		HudTheme.BodyFont,
		HudTheme.TextSize.body,
		frame
	)
	effect.Position = UDim2.fromOffset(0, 52)
	effect.TextWrapped = true
	effect.TextTruncate = Enum.TextTruncate.None
	effect.TextYAlignment = Enum.TextYAlignment.Top

	local note = HudTheme.label(
		"Note",
		"",
		UDim2.new(1, 0, 0, 20),
		HudTheme.BodyFont,
		HudTheme.TextSize.small,
		frame
	)
	note.AnchorPoint = Vector2.new(0, 1)
	note.Position = UDim2.new(0, 0, 1, -HudTheme.MinButtonHeight - 8)
	note.TextColor3 = C.gold

	local h = HudTheme.MinButtonHeight
	local prev = HudTheme.button("Prev", "<", UDim2.fromOffset(h, h), frame)
	prev.AnchorPoint = Vector2.new(0, 1)
	prev.Position = UDim2.fromScale(0, 1)
	prev.BackgroundColor3 = C.panelLight
	local nextButton = HudTheme.button("Next", ">", UDim2.fromOffset(h, h), frame)
	nextButton.AnchorPoint = Vector2.new(0, 1)
	nextButton.Position = UDim2.new(0, h + 8, 1, 0)
	nextButton.BackgroundColor3 = C.panelLight

	local buy = HudTheme.button("Buy", "", UDim2.fromOffset(170, h), frame)
	buy.AnchorPoint = Vector2.new(1, 1)
	buy.Position = UDim2.fromScale(1, 1)
	local closeButton = HudTheme.button("Close", "Close", UDim2.fromOffset(100, h), frame)
	closeButton.AnchorPoint = Vector2.new(1, 1)
	closeButton.Position = UDim2.new(1, -178, 1, 0)
	closeButton.BackgroundColor3 = C.panelLight

	-- ---------------------------------------------------------------- state
	local snapshot: { [string]: any }? = nil
	local openShelf: string? = nil
	local openAnchor: Instance? = nil
	local items: { ProductShelves.ItemRef } = {}
	local page = 1
	local catalogue: { [string]: { [string]: any } } = {} -- "kind/key" -> entry
	local catalogueAt = -math.huge
	local fetching = false
	local prices: { [number]: number | false } = {} -- id -> Robux (false: failed)
	local priceFetching: { [number]: boolean } = {}
	local pendingKey: string? = nil
	local pendingAt = 0

	local function keyOf(ref: ProductShelves.ItemRef): string
		return `{ref.kind}/{ref.key}`
	end

	local function stormQueue(): number?
		local weather = ReplicatedStorage:FindFirstChild("Weather")
		local n = weather and weather:GetAttribute("SummonQueue")
		return if type(n) == "number" then n else nil
	end

	local function numberAttr(nameOf: string): number?
		local v = player:GetAttribute(nameOf)
		return if type(v) == "number" then v else nil
	end

	local function contextFor(ref: ProductShelves.ItemRef): ProductShelves.CardContext
		local item = ProductShelves.configItem(config, ref)
		local entry = catalogue[keyOf(ref)]
		local id = if item and type(item.id) == "number" then item.id else 0
		local price = prices[id]
		return {
			offered = entry ~= nil and entry.id == id,
			owned = player:GetAttribute("Pass_" .. ref.key) == true
				or (entry ~= nil and entry.owned == true),
			price = if type(price) == "number" then price else nil,
			priceFailed = price == false,
			ownsDoubleCash = player:GetAttribute("Pass_DoubleCash") == true,
			cashPacksToday = numberAttr("CashPacksToday"),
			cashPerMinute = numberAttr("CashPerMinute"),
			stormQueue = stormQueue(),
			pending = pendingKey == keyOf(ref) and os.clock() - pendingAt < PENDING_TIMEOUT,
		}
	end

	local render: () -> ()
	local open = false
	local closeCard: () -> ()

	local function fetchPrice(ref: ProductShelves.ItemRef)
		local item = ProductShelves.configItem(config, ref)
		local id = if item and type(item.id) == "number" then item.id else 0
		if id <= 0 or prices[id] ~= nil or priceFetching[id] then
			return
		end
		priceFetching[id] = true
		task.spawn(function()
			local infoType = if ref.kind == "GamePasses"
				then Enum.InfoType.GamePass
				else Enum.InfoType.Product
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, infoType)
			end)
			local robux = if ok and type(info) == "table" then info.PriceInRobux else nil
			prices[id] = if type(robux) == "number" then robux else false
			priceFetching[id] = nil
			render()
		end)
	end

	local function fetchCatalogue(force: boolean)
		if fetching or (not force and os.clock() - catalogueAt < CATALOGUE_TTL) then
			return
		end
		fetching = true
		task.spawn(function()
			local net = ReplicatedStorage:WaitForChild("Net", 10)
			local remote = net and net:WaitForChild("Monetization_GetCatalogue", 10)
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
			render()
		end)
	end

	-- the items this shelf shows now (Cash Boost drops out for 2x Cash owners)
	local function visibleItems(shelfId: string): { ProductShelves.ItemRef }
		local out: { ProductShelves.ItemRef } = {}
		for _, ref in ProductShelves.shelfItems(config, shelfId, studio) do
			if ProductShelves.cardState(config, ref, contextFor(ref)).status ~= "hidden" then
				table.insert(out, ref)
			end
		end
		return out
	end

	render = function()
		if not openShelf then
			return
		end
		local shelf = ProductShelves.Shelves[openShelf]
		items = visibleItems(openShelf)
		if #items == 0 then
			closeCard()
			return
		end
		page = math.clamp(page, 1, #items)
		local ref = items[page]
		local item = ProductShelves.configItem(config, ref)
		local ctx = contextFor(ref)
		local st = ProductShelves.cardState(config, ref, ctx)
		if ctx.offered then
			fetchPrice(ref)
		end
		place.Text = shelf.title
		pager.Text = if #items > 1 then `{page} of {#items}` else ""
		prev.Visible = #items > 1
		nextButton.Visible = #items > 1
		name.Text = item.name
		effect.Text = item.description
		note.Text = st.note or ""
		tag.Text = if st.status == "owned"
			then "OWNED"
			elseif st.status == "comingSoon" then "COMING SOON"
			else ""
		tag.TextColor3 = if st.status == "owned" then C.ready else C.textDim
		buy.Text = st.buyText
		buy.Active = st.canBuy
		buy.AutoButtonColor = st.canBuy
		buy.BackgroundColor3 = if st.canBuy then C.accent else C.locked
		buy.TextColor3 = if st.canBuy then C.text else C.textDim
		frame.Visible = true
	end

	local function onAction(actionName: string, inputState: Enum.UserInputState, input: InputObject)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		if actionName == ACTION_CLOSE then
			closeCard()
		elseif actionName == ACTION_PAGE and #items > 1 then
			local step = if input.KeyCode == Enum.KeyCode.ButtonL1 then -1 else 1
			page = (page - 1 + step) % #items + 1
			render()
		end
		return Enum.ContextActionResult.Sink
	end

	closeCard = function()
		if not open then
			return
		end
		open = false
		openShelf = nil
		openAnchor = nil
		frame.Visible = false
		ContextActionService:UnbindAction(ACTION_CLOSE)
		ContextActionService:UnbindAction(ACTION_PAGE)
		local sel = GuiService.SelectedObject
		if sel and sel:IsDescendantOf(gui) then
			GuiService.SelectedObject = nil
		end
	end

	local function openCard(shelfId: string, anchor: Instance)
		if onOpen then
			onOpen()
		end
		openShelf = shelfId
		openAnchor = anchor
		page = 1
		open = true
		fetchCatalogue(false)
		render()
		ContextActionService:BindAction(ACTION_CLOSE, onAction, false, Enum.KeyCode.ButtonB)
		ContextActionService:BindAction(
			ACTION_PAGE,
			onAction,
			false,
			Enum.KeyCode.ButtonL1,
			Enum.KeyCode.ButtonR1
		)
		if isGamepad() then
			GuiService.SelectedObject = if buy.Active then buy else closeButton
		end
	end

	prev.Activated:Connect(function()
		if #items > 1 then
			page = (page - 2) % #items + 1
			render()
		end
	end)
	nextButton.Activated:Connect(function()
		if #items > 1 then
			page = page % #items + 1
			render()
		end
	end)
	closeButton.Activated:Connect(function()
		closeCard()
	end)

	-- Rule 5: the only path to a purchase prompt.
	buy.Activated:Connect(function()
		local ref = items[page]
		if not (open and ref) then
			return
		end
		local ctx = contextFor(ref)
		if not ProductShelves.mayPrompt(config, ref, ctx) then
			return
		end
		local id = ProductShelves.configItem(config, ref).id :: number
		pendingKey, pendingAt = keyOf(ref), os.clock()
		render()
		local ok, err = pcall(function()
			if ref.kind == "GamePasses" then
				MarketplaceService:PromptGamePassPurchase(player, id)
			else
				MarketplaceService:PromptProductPurchase(player, id)
			end
		end)
		if not ok then
			warn("[ProductCard] prompt failed:", err)
			pendingKey = nil
			render()
		end
	end)

	local function purchaseFinished()
		pendingKey = nil
		fetchCatalogue(true)
		render()
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(purchaseFinished)
	MarketplaceService.PromptProductPurchaseFinished:Connect(purchaseFinished)
	task.spawn(function()
		local net = ReplicatedStorage:WaitForChild("Net", 30)
		local remote = net and net:WaitForChild("Monetization_Purchased", 30)
		if remote and remote:IsA("RemoteEvent") then
			remote.OnClientEvent:Connect(purchaseFinished)
		end
	end)
	player.AttributeChanged:Connect(function(attr: string)
		if
			open
			and (attr:sub(1, 5) == "Pass_" or attr == "CashPacksToday" or attr == "CashPerMinute")
		then
			render()
		end
	end)
	task.spawn(function()
		local weather = ReplicatedStorage:WaitForChild("Weather", 30)
		if weather then
			weather:GetAttributeChangedSignal("SummonQueue"):Connect(render)
		end
	end)

	-- ---------------------------------------------------------------- shelves and prompts
	type Spot = { anchor: Instance, shelf: string, prompt: ProximityPrompt? }
	local spots: { [Instance]: Spot } = {}

	local function pricedOpen(): boolean
		local ops = player:GetAttribute("OpsCompleted")
		return ProductShelves.pricedOpen(snapshot, if type(ops) == "number" then ops else nil)
	end

	local function refreshSpot(spot: Spot)
		local visible = spot.anchor:IsDescendantOf(Workspace)
			and ProductShelves.shelfVisible(config, spot.shelf, studio, pricedOpen())
		if visible and not spot.prompt then
			local shelf = ProductShelves.Shelves[spot.shelf]
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "ProductShelfPrompt"
			prompt.ActionText = shelf.action
			prompt.ObjectText = shelf.object
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = PROMPT_DISTANCE
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Panel", "ProductShelf")
			prompt:SetAttribute("Shelf", spot.shelf)
			if spot.shelf == "BoatDeskQuickLaunch" then
				-- the desk's own E / X prompt collects a boat; this card sits on F / Y
				prompt.KeyboardKeyCode = Enum.KeyCode.F
				prompt.GamepadKeyCode = Enum.KeyCode.ButtonY
			end
			prompt.Triggered:Connect(function()
				openCard(spot.shelf, spot.anchor)
			end)
			prompt.Parent = spot.anchor
			spot.prompt = prompt
		elseif not visible and spot.prompt then
			spot.prompt:Destroy()
			spot.prompt = nil
			if openAnchor == spot.anchor then
				closeCard()
			end
		end
	end

	local function refreshAll()
		for _, spot in spots do
			refreshSpot(spot)
		end
	end

	local function storeBoard(anchor: Instance)
		local model = anchor.Parent
		local board = model and model:FindFirstChild("StormBoard")
		local surface = board and board:FindFirstChild("Sign")
		local text = surface and surface:FindFirstChild("Text")
		if not (text and text:IsA("TextLabel")) then
			return
		end
		local label = text :: TextLabel
		local function update()
			label.Text = ProductShelves.stormBoardText(stormQueue())
		end
		update()
		task.spawn(function()
			local weather = ReplicatedStorage:WaitForChild("Weather", 30)
			if weather then
				weather:GetAttributeChangedSignal("SummonQueue"):Connect(update)
			end
		end)
	end

	local function track(anchor: Instance)
		local shelf = anchor:GetAttribute("ProductShelf")
		local existing = spots[anchor]
		if type(shelf) ~= "string" or not ProductShelves.Shelves[shelf] then
			if existing then
				if existing.prompt then
					existing.prompt:Destroy()
				end
				spots[anchor] = nil
			end
			return
		end
		if existing then
			return
		end
		local spot: Spot = { anchor = anchor, shelf = shelf, prompt = nil }
		spots[anchor] = spot
		if shelf == "StormDesk" then
			storeBoard(anchor)
		end
		refreshSpot(spot)
		anchor.AncestryChanged:Connect(function()
			if not anchor:IsDescendantOf(game) then
				spots[anchor] = nil
			end
		end)
	end

	-- ChandleryRig tags its ATT_ markers after the H2 models are placed: watch those by name too
	local shelfNames = ProductShelves.attachmentShelves()
	local watched: { [Instance]: boolean } = {}
	local function consider(inst: Instance)
		if inst:IsA("Attachment") and shelfNames[inst.Name] and not watched[inst] then
			watched[inst] = true
			inst:GetAttributeChangedSignal("ProductShelf"):Connect(function()
				track(inst)
			end)
		end
		if inst:GetAttribute("ProductShelf") ~= nil then
			track(inst)
		elseif inst:IsA("BasePart") and inst:GetAttribute("PromptAnchor") == "BoatDesk" then
			-- the Quick Launch card sits at the boatyard desk (docs/04 1.1), beside the collect prompt
			if not inst:FindFirstChild("QuickLaunchCard") then
				local a = Instance.new("Attachment")
				a.Name = "QuickLaunchCard"
				a.Position = Vector3.new(-3, 0, 0)
				a:SetAttribute("ProductShelf", "BoatDeskQuickLaunch")
				a.Parent = inst
			end
		end
	end
	task.defer(function()
		for _, inst in Workspace:GetDescendants() do
			consider(inst)
		end
		Workspace.DescendantAdded:Connect(consider)
	end)
	player:GetAttributeChangedSignal("OpsCompleted"):Connect(refreshAll)

	-- walking away, dying or sitting down closes the card
	RunService.Heartbeat:Connect(function()
		if not open then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local at = openAnchor and anchorPosition(openAnchor)
		if
			not (root and root:IsA("BasePart") and humanoid and at)
			or humanoid.Health <= 0
			or humanoid.SeatPart ~= nil
			or (root.Position - at).Magnitude > PROMPT_DISTANCE + WALK_AWAY_MARGIN
		then
			closeCard()
		end
	end)

	return {
		setSnapshot = function(data: { [string]: any })
			local was = pricedOpen()
			snapshot = data
			if pricedOpen() ~= was then
				refreshAll()
			end
		end,
		close = closeCard,
		isOpen = function()
			return open
		end,
	}
end

return ProductCard
