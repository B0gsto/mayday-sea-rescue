--!strict
-- VehiclesApp: the phone's vehicle page (replaces the quay boat desk and the Bay 1 upgrade stands).
-- One big card per vehicle (boats, then the land fleet), swiped / scrolled / paged sideways: a turning
-- 3D preview (a clone of a live one of that kind for the real art, else the shared builder's greybox,
-- else the boat glyph), the name, a green tick on the one you have out, the boat's three upgrades
-- (icon + coin price, tick once fitted) and one button: Spawn (owned), coin + price (for sale), or the
-- rank it needs. Mouse / touch: tap and swipe; keyboard: Left / Right; gamepad: L2 / R2 and A.
--   Buy a boat     BuyGear(vehicleId)                   (ProgressionService: rank + Cash)
--   Fit upgrade    Upgrade_Buy(vehicleId, upgradeId)    (UpgradeService)
--   Spawn a boat   RequestVehicle(vehicleId, true, true) docked at the free bay nearest you; Quick Launch
--                  pass owners: Vehicle_QuickLaunch(vehicleId), seated at the helm at once from anywhere
--                  (a lightning mark on Spawn, no footprint trail). Others see a Quick Launch chip that
--                  opens the pass's Roblox purchase prompt (MonetizationService grants it).
--   Spawn a car    CarController.Request(vehicleId)     (Land_Request: the nearest road spawn point)
-- Spawning closes the phone and FootTrail walks you to it. Data: PlayerDataChanged snapshots.
--   VehiclesApp.mount(page: Frame) -> cleanup
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local BoatBuilder = require(Shared:WaitForChild("Boat"):WaitForChild("Builder"))
local CarBuilder = require(Shared:WaitForChild("Car"):WaitForChild("Builder"))
local LandVehicleConfig = require(Config:WaitForChild("LandVehicleConfig"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local FootTrail = require(script.Parent:WaitForChild("FootTrail"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local C = HudTheme.Colors
local player = Players.LocalPlayer
local ICON = { Engine = "speed", Hull = "boat", Fit = "seat" }
local FOLDERS = { "Vehicles", "LandVehicles" } -- VehicleService / LandVehicleService
-- server reason codes -> 1 to 2 words on the button
local SHORT: { [string]: string } = {
	Cooldown = "Wait",
	BayBusy = "Bay busy",
	NoBay = "No bay",
	NoSpawnPoint = "No spot",
	Occupied = "Occupied",
	Locked = "Locked",
	NotReady = "Offline",
	NotOwned = "No pass",
	ColdOpen = "Not yet",
}
local QUICK = "QuickLaunch" -- the pass

local function ownsQuick(): boolean
	return player:GetAttribute("Pass_" .. QUICK) == true
end

-- a small gold lightning bolt (two slanted bars)
local function bolt(parent: Instance, size: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Bolt"
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.Parent = parent
	-- upper stroke, the kink, lower stroke: a Z-shaped bolt
	for _, spec in
		{ { 0.62, 0.27, 0.2, 0.5, 22 }, { 0.5, 0.5, 0.56, 0.14, 0 }, { 0.38, 0.73, 0.2, 0.5, 22 } }
	do
		local bar = Instance.new("Frame")
		bar.AnchorPoint = Vector2.new(0.5, 0.5)
		bar.Position = UDim2.fromScale(spec[1], spec[2])
		bar.Size = UDim2.fromScale(spec[3], spec[4])
		bar.Rotation = spec[5]
		bar.BackgroundColor3 = C.gold
		bar.BorderSizePixel = 0
		bar.Parent = f
	end
	return f
end
local ACTION_PAGE = "VehiclesApp_Page"

type Entry = { id: string, land: boolean, name: string }
type Tile = { id: string, button: TextButton, price: TextLabel, coin: Frame, check: Frame }
type Card = {
	entry: Entry,
	frame: Frame,
	camera: Camera?,
	centre: Vector3,
	size: Vector3, -- the model's bounding box, framed to the stage every frame
	out: Frame,
	action: TextButton,
	actionCoin: Frame,
	actionLabel: TextLabel,
	actionBolt: Frame,
	tiles: { Tile },
	flash: string?,
}

local VehiclesApp = {}

local function entries(): { Entry }
	local out: { Entry } = {}
	for _, id in VehicleConfig.Order do
		local spec = VehicleConfig.get(id)
		table.insert(out, { id = id, land = false, name = if spec then spec.displayName else id })
	end
	for _, id in LandVehicleConfig.Order do
		local spec = (LandVehicleConfig :: any)[id]
		table.insert(out, { id = id, land = true, name = if spec then spec.displayName else id })
	end
	return out
end

local function label(parent: Instance, name: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = HudTheme.HeaderFont
	l.TextSize = size
	l.TextColor3 = color
	l.Text = ""
	l.Parent = parent
	return l
end

local function square(parent: Instance, name: string, px: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.fromOffset(px, px)
	f.BackgroundTransparency = 1
	f.Parent = parent
	return f
end

local function row(parent: Instance): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 6)
	l.Parent = parent
	return l
end

local function liveModel(id: string, ownerOnly: boolean): Model?
	for _, name in FOLDERS do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			for _, m in folder:GetChildren() do
				if
					m:IsA("Model")
					and m:GetAttribute("VehicleId") == id
					and (not ownerOnly or m:GetAttribute("Owner") == player.UserId)
				then
					return m
				end
			end
		end
	end
	return nil
end

-- the preview: anyone's live one (the uploaded art), else the shared builder's greybox
local function previewModel(entry: Entry): Model?
	local live = liveModel(entry.id, false)
	local model: Model? = if live then live:Clone() else nil
	if not model then
		local ok, built = pcall(function(): Model?
			if entry.land then
				local spec = (LandVehicleConfig :: any)[entry.id]
				return if spec then (CarBuilder.build(spec)) else nil
			end
			local spec = VehicleConfig.get(entry.id)
			return if spec then BoatBuilder.build(spec) else nil
		end)
		model = if ok then built else nil
	end
	if model then
		for _, d in model:GetDescendants() do
			if d:IsA("BaseScript") or d:IsA("Sound") then
				d:Destroy()
			end
		end
	end
	return model
end

function VehiclesApp.mount(page: Frame): () -> ()
	local list = entries()
	local cards: { Card } = {}
	local conns: { RBXScriptConnection } = {}
	local snapshot: { [string]: any }? = nil
	local busy = false
	local alive = true

	local root = Instance.new("Frame")
	root.Name = "Vehicles"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = page

	local strip = Instance.new("Frame")
	strip.Name = "Cards"
	strip.Size = UDim2.new(1, 0, 1, -30)
	strip.BackgroundTransparency = 1
	strip.ClipsDescendants = true
	strip.Parent = root
	local pages = Instance.new("UIPageLayout")
	pages.FillDirection = Enum.FillDirection.Horizontal
	pages.SortOrder = Enum.SortOrder.LayoutOrder
	pages.Padding = UDim.new(0, 12)
	pages.Animated = true
	pages.EasingStyle = Enum.EasingStyle.Quart
	pages.TweenTime = 0.3
	pages.Circular = false
	pages.TouchInputEnabled = true
	pages.ScrollWheelInputEnabled = true
	pages.GamepadInputEnabled = true
	pages.Parent = strip

	-- page dots with a tap target either side (mouse users)
	local nav = Instance.new("Frame")
	nav.Name = "Nav"
	nav.AnchorPoint = Vector2.new(0, 1)
	nav.Position = UDim2.fromScale(0, 1)
	nav.Size = UDim2.new(1, 0, 0, 26)
	nav.BackgroundTransparency = 1
	nav.Parent = root
	row(nav).Padding = UDim.new(0, 5)
	local dots: { Frame } = {}
	local function arrow(name: string, text: string, order: number, go: () -> ())
		local b = Instance.new("TextButton")
		b.Name = name
		b.LayoutOrder = order
		b.Size = UDim2.fromOffset(34, 26)
		b.BackgroundTransparency = 1
		b.Font = HudTheme.HeaderFont
		b.TextSize = 24
		b.TextColor3 = C.textDim
		b.Text = text
		b.Parent = nav
		b.Activated:Connect(go)
	end
	arrow("Prev", "<", 0, function()
		pages:Previous()
	end)
	for i in list do
		local d = Instance.new("Frame")
		d.Name = `Dot{i}`
		d.LayoutOrder = i
		d.Size = UDim2.fromOffset(7, 7)
		d.BackgroundColor3 = C.textDim
		d.BorderSizePixel = 0
		HudTheme.corner(d, 99)
		d.Parent = nav
		dots[i] = d
	end
	arrow("Next", ">", #list + 1, function()
		pages:Next()
	end)

	local function data(): Rules.PlayerData?
		return if snapshot then Rules.fromSnapshot(snapshot) else nil
	end

	local function paint()
		local d = data()
		for _, card in cards do
			local id = card.entry.id
			local unlock = ProgressionConfig.Vehicles[id]
			local usable = d ~= nil and Rules.canUseVehicle(d, id)
			local lock = if d then Rules.vehicleLock(d, id) else nil
			local canBuy = d ~= nil and Rules.canBuyVehicle(d, id)
			card.out.Visible = liveModel(id, true) ~= nil
			card.actionCoin.Visible = false
			card.actionBolt.Visible = false
			card.actionLabel.TextColor3 = C.text
			if card.flash then
				card.actionLabel.Text = card.flash
				card.action.BackgroundColor3 = C.locked
				card.actionLabel.TextColor3 = Color3.fromRGB(244, 128, 112)
			elseif not d then
				card.actionLabel.Text = "..."
				card.action.BackgroundColor3 = C.locked
			elseif usable then
				card.actionLabel.Text = "Spawn"
				card.action.BackgroundColor3 = C.accent
				card.actionBolt.Visible = ownsQuick() and not card.entry.land
			elseif lock then
				card.actionLabel.Text = string.gsub(lock, "^Rank: ", "")
				card.action.BackgroundColor3 = C.locked
				card.actionLabel.TextColor3 = C.textDim
			elseif unlock then
				card.actionCoin.Visible = true
				card.actionLabel.Text = HudTheme.formatNumber(unlock.price)
				card.actionLabel.TextColor3 = if canBuy then C.gold else C.textDim
				card.action.BackgroundColor3 = if canBuy then C.panelLight else C.locked
			end
			local stored = if snapshot and type(snapshot.vehicleUpgrades) == "table"
				then snapshot.vehicleUpgrades
				else {}
			local mask = VehicleUpgrades.mask(stored[id])
			for _, tile in card.tiles do
				local upgrade = VehicleUpgrades.entry(id, tile.id)
				local fitted = VehicleUpgrades.has(mask, tile.id)
				local ok = d ~= nil
					and upgrade ~= nil
					and VehicleUpgrades.canBuy(
						id,
						tile.id,
						mask,
						d.cash,
						Rules.rankIndex(d),
						Rules.ownsVehicle(d, id)
					)
				tile.check.Visible = fitted
				tile.coin.Visible = not fitted
				tile.price.Visible = not fitted
				tile.price.Text = if upgrade then HudTheme.formatNumber(upgrade.price) else ""
				tile.price.TextColor3 = if ok then C.gold else C.textDim
				tile.button.BackgroundTransparency = if fitted or ok then 0.1 else 0.55
			end
		end
	end

	local function flash(card: Card, reason: any)
		local text = if type(reason) == "string" then (SHORT[reason] or reason) else "Try again"
		card.flash = if #text <= 16 then text else "Try again"
		paint()
		task.delay(1.6, function()
			card.flash = nil
			if alive then
				paint()
			end
		end)
	end

	local function pop(button: GuiObject)
		local scale = button:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = button
		scale.Scale = 1.12
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- one remote call at a time; ok -> pop, else the server's reason on the button
	local function call(
		card: Card,
		button: GuiObject,
		fn: () -> (boolean, any),
		onOk: ((any) -> ())?
	)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			local ok, done, result = pcall(fn)
			busy = false
			if not alive then
				return
			end
			if ok and done then
				pop(button)
				if onOk then
					onOk(result)
				end
			else
				flash(card, if ok then result else "NotReady")
			end
		end)
	end

	local function spawned(result: any, seated: boolean?)
		-- untyped require: Phone mounts this app (a typed one would be a cyclic module dependency)
		(require :: any)(script.Parent:WaitForChild("Phone")).setOpen(false)
		if not seated and typeof(result) == "Instance" and result:IsA("Model") then
			FootTrail.guide(result)
		end
	end

	local function activate(card: Card)
		local d = data()
		if not d then
			return
		end
		local id = card.entry.id
		if Rules.canUseVehicle(d, id) then
			local quickUsed = false
			call(card, card.action, function()
				if card.entry.land then
					local cars = require(
						script.Parent.Parent
							:WaitForChild("Controllers")
							:WaitForChild("CarController")
					) :: any
					return cars.Request(id)
				end
				if ownsQuick() then
					local net = ReplicatedStorage:FindFirstChild("Net")
					local quick = net and net:FindFirstChild("Vehicle_QuickLaunch")
					if quick and quick:IsA("RemoteFunction") then
						quickUsed = true
						return quick:InvokeServer(id)
					end
				end
				return Net.func("RequestVehicle"):InvokeServer(id, true, true)
			end, function(result: any)
				spawned(result, quickUsed) -- Quick Launch seats you: no footprints
			end)
		elseif Rules.canBuyVehicle(d, id) then
			call(card, card.action, function()
				return Net.func("BuyGear"):InvokeServer(id)
			end)
		end
	end

	local function buildCard(entry: Entry, order: number): Card
		local frame = Instance.new("Frame")
		frame.Name = entry.id
		frame.LayoutOrder = order
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = C.panel
		frame.BackgroundTransparency = 0.2
		frame.BorderSizePixel = 0
		HudTheme.corner(frame, 16)
		HudTheme.stroke(frame)
		frame.Parent = strip

		-- the stage: a lit gradient with the turning model
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.Position = UDim2.fromOffset(8, 8)
		stage.Size = UDim2.new(1, -16, 0.5, 0)
		stage.BackgroundColor3 = Color3.new(1, 1, 1)
		stage.BorderSizePixel = 0
		HudTheme.corner(stage, 12)
		local grad = Instance.new("UIGradient")
		grad.Color = ColorSequence.new(Color3.fromHex("3A6F80"), Color3.fromHex("13232C"))
		grad.Rotation = 90
		grad.Parent = stage
		stage.Parent = frame
		local vp = Instance.new("ViewportFrame")
		vp.Name = "Preview"
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(150, 160, 170)
		vp.LightColor = Color3.fromRGB(255, 246, 230)
		vp.LightDirection = Vector3.new(-1, -2, -1)
		vp.Parent = stage

		local card: Card = {
			entry = entry,
			frame = frame,
			camera = nil,
			centre = Vector3.zero,
			size = Vector3.one,
			out = square(stage, "Out", 26),
			action = Instance.new("TextButton"),
			actionCoin = square(frame, "Coin", 22),
			actionLabel = label(frame, "Label", 20, C.text),
			actionBolt = bolt(frame, 22),
			tiles = {},
			flash = nil,
		}
		card.out.AnchorPoint = Vector2.new(1, 0)
		card.out.Position = UDim2.new(1, -6, 0, 6)
		Glyph.draw("check", card.out, C.ready)

		local model = previewModel(entry)
		if model then
			local cf, size = model:GetBoundingBox()
			local camera = Instance.new("Camera")
			camera.FieldOfView = 30
			camera.Parent = vp
			vp.CurrentCamera = camera
			model.Parent = vp
			card.camera = camera
			card.centre = cf.Position
			card.size = size
		else
			local icon = square(stage, "Icon", 90)
			icon.AnchorPoint = Vector2.new(0.5, 0.5)
			icon.Position = UDim2.fromScale(0.5, 0.5)
			Glyph.draw("boat", icon, C.text)
		end

		local name = label(frame, "Name", 22, C.text)
		name.Position = UDim2.new(0, 10, 0.5, 14)
		name.Size = UDim2.new(1, -20, 0, 26)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = entry.name

		-- the boat's upgrades: picture + coin price, a tick once fitted
		if VehicleUpgrades.Vehicles[entry.id] then
			local tiles = Instance.new("Frame")
			tiles.Name = "Upgrades"
			tiles.Position = UDim2.new(0, 8, 0.5, 46)
			tiles.Size = UDim2.new(1, -16, 0, 62)
			tiles.BackgroundTransparency = 1
			tiles.Parent = frame
			row(tiles)
			for i, upgradeId in VehicleUpgrades.UpgradeOrder do
				local b = Instance.new("TextButton")
				b.Name = upgradeId
				b.LayoutOrder = i
				b.Text = ""
				b.Size = UDim2.fromOffset(64, 62)
				b.BackgroundColor3 = C.panelLight
				b.BorderSizePixel = 0
				HudTheme.corner(b, 10)
				b.Parent = tiles
				local icon = square(b, "Icon", 32)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 5)
				Glyph.draw(ICON[upgradeId] or "ring", icon, C.text)
				local priceRow = Instance.new("Frame")
				priceRow.Name = "Price"
				priceRow.AnchorPoint = Vector2.new(0, 1)
				priceRow.Position = UDim2.new(0, 0, 1, -3)
				priceRow.Size = UDim2.new(1, 0, 0, 20)
				priceRow.BackgroundTransparency = 1
				priceRow.Parent = b
				row(priceRow).Padding = UDim.new(0, 2)
				local coin = square(priceRow, "Coin", 14)
				Glyph.draw("coin", coin, C.gold)
				local price = label(priceRow, "Amount", 15, C.gold)
				price.LayoutOrder = 1
				price.AutomaticSize = Enum.AutomaticSize.X
				price.Size = UDim2.fromOffset(0, 20)
				local check = square(priceRow, "Fitted", 18)
				check.LayoutOrder = 2
				Glyph.draw("check", check, C.ready)
				local tile: Tile =
					{ id = upgradeId, button = b, price = price, coin = coin, check = check }
				table.insert(card.tiles, tile)
				b.Activated:Connect(function()
					call(card, b, function()
						local remote = Net.init():WaitForChild("Upgrade_Buy", 10)
						if not (remote and remote:IsA("RemoteFunction")) then
							return false, "NotReady"
						end
						return remote:InvokeServer(entry.id, upgradeId)
					end)
				end)
			end
		end

		-- the one button: Spawn / coin + price / the rank it needs
		local action = card.action
		action.Name = "Action"
		action.Text = ""
		action.AnchorPoint = Vector2.new(0.5, 1)
		action.Position = UDim2.new(0.5, 0, 1, -8)
		action.Size = UDim2.new(1, -16, 0, 48)
		action.BackgroundColor3 = C.accent
		action.BorderSizePixel = 0
		action.AutoButtonColor = true
		HudTheme.corner(action, 10)
		action.Parent = frame
		row(action)
		card.actionCoin.Parent = action
		card.actionLabel.Parent = action
		card.actionBolt.Parent = action
		card.actionLabel.LayoutOrder = 1
		card.actionLabel.AutomaticSize = Enum.AutomaticSize.X
		card.actionLabel.Size = UDim2.fromOffset(0, 48)
		action.Activated:Connect(function()
			activate(card)
		end)
		return card
	end

	for i, entry in list do
		table.insert(cards, buildCard(entry, i))
	end

	local function current(): Card?
		for _, card in cards do
			if card.frame == pages.CurrentPage then
				return card
			end
		end
		return nil
	end

	local function onPage()
		local card = current()
		for i, dot in dots do
			local on = cards[i] == card
			dot.Size = UDim2.fromOffset(if on then 16 else 7, 7)
			dot.BackgroundColor3 = if on then C.accent else C.textDim
		end
		if card and UserInputService.GamepadEnabled and page.Visible then
			GuiService.SelectedObject = card.action
		end
	end
	table.insert(conns, pages:GetPropertyChangedSignal("CurrentPage"):Connect(onPage))

	-- the turntable: only the card in view turns
	local angle = 0.6
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt: number)
			local card = current()
			if card and card.camera and page.Visible then
				angle += dt * 0.5
				-- fit the hull's length to the stage width and its height to the stage height
				local px = (card.camera.Parent :: ViewportFrame).AbsoluteSize
				local tanV = math.tan(math.rad(card.camera.FieldOfView / 2))
				local tanH = tanV * (if px.Y > 0 then px.X / px.Y else 2)
				local s = card.size
				local distance = math.max(math.max(s.X, s.Z) / 2 / tanH, s.Y / tanV) * 1.08
					+ math.min(s.X, s.Z) / 2
				local eye = Vector3.new(math.sin(angle), 0.32, math.cos(angle)).Unit * distance
				card.camera.CFrame = CFrame.lookAt(card.centre + eye, card.centre)
			end
		end)
	)

	ContextActionService:BindActionAtPriority(
		ACTION_PAGE,
		function(_, state, input): Enum.ContextActionResult
			if state ~= Enum.UserInputState.Begin or not page.Visible then
				return Enum.ContextActionResult.Pass
			end
			if input.KeyCode == Enum.KeyCode.Left or input.KeyCode == Enum.KeyCode.ButtonL2 then
				pages:Previous()
			else
				pages:Next()
			end
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Left,
		Enum.KeyCode.Right,
		Enum.KeyCode.ButtonL2,
		Enum.KeyCode.ButtonR2
	)

	local function onData(d: any)
		if type(d) == "table" and alive then
			snapshot = d
			paint()
		end
	end
	table.insert(conns, Net.event("PlayerDataChanged").OnClientEvent:Connect(onData))
	for _, name in FOLDERS do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(conns, folder.ChildAdded:Connect(paint))
			table.insert(conns, folder.ChildRemoved:Connect(paint))
		end
	end
	-- Quick Launch upsell for non-owners: the Roblox pass prompt (MonetizationService grants Pass_ on buy)
	local pass = MonetizationConfig.GamePasses[QUICK]
	if pass and pass.ready and pass.id ~= 0 then
		local chip = Instance.new("TextButton")
		chip.Name = "QuickLaunchChip"
		chip.Text = ""
		chip.Position = UDim2.fromOffset(16, 16)
		chip.Size = UDim2.fromOffset(0, 32)
		chip.AutomaticSize = Enum.AutomaticSize.X
		chip.BackgroundColor3 = C.panel
		chip.BackgroundTransparency = 0.15
		chip.ZIndex = 5
		HudTheme.corner(chip, 16)
		HudTheme.stroke(chip, C.gold, 1).Transparency = 0.3
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 8)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = chip
		row(chip)
		bolt(chip, 20).LayoutOrder = 0
		local text = label(chip, "Label", 16, C.gold)
		text.Text = "Quick Launch"
		text.LayoutOrder = 1
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, 32)
		chip.Parent = root
		local function showChip()
			chip.Visible = not ownsQuick()
			paint()
		end
		showChip()
		table.insert(conns, player:GetAttributeChangedSignal("Pass_" .. QUICK):Connect(showChip))
		chip.Activated:Connect(function()
			local ok, err = pcall(function()
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			end)
			if not ok then
				warn("[VehiclesApp] Quick Launch prompt failed:", err)
			end
		end)
	end
	paint()
	-- open on the vehicle you have out
	for _, card in cards do
		if card.out.Visible then
			pages:JumpTo(card.frame)
			break
		end
	end
	onPage()
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30)
		if getData and getData:IsA("RemoteFunction") then
			local ok, d = pcall(function()
				return getData:InvokeServer()
			end)
			if ok then
				onData(d)
			end
		end
	end)

	return function()
		alive = false
		ContextActionService:UnbindAction(ACTION_PAGE)
		for _, c in conns do
			c:Disconnect()
		end
		root:Destroy()
	end
end

return VehiclesApp
