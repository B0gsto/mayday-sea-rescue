--!strict
-- VehiclesApp: the phone's vehicle page (portrait). Three tabs on top (Boats, Jet Skis, Cars), each a
-- swipeable carousel of big cards: a slowly turning 3D preview of the real model (the server's
-- ReplicatedStorage.VehiclePreviews.<id>, the exact build the spawner makes; else a live one of that
-- kind; else the shared builder's greybox), the name (gold for the Robux-only premium fleet), three stat
-- bars (speed, people aboard, toughness), the boat's three upgrades (icon, word, coin price, tick once
-- fitted) and the action row: Spawn when owned, else a Cash button (coin + price, or the rank it needs)
-- and a Robux button (the vehicle's Game Pass, Roblox's live price).
-- Mouse / touch: tap and swipe; keyboard: Left / Right vehicles, Up / Down tabs; gamepad: L2 / R2
-- vehicles, Y tabs, A on the selected button.
--   Buy with Cash   BuyGear(vehicleId)                   (ProgressionService: rank + Cash)
--   Buy with Robux  PromptGamePassPurchase(pass id)      (MonetizationService grants Pass_<Key>; the
--                   server's CanUseVehicle reads it: Cash-owned OR pass-owned)
--   Fit upgrade     Upgrade_Buy(vehicleId, upgradeId)    (UpgradeService)
--   Spawn a boat    RequestVehicle(vehicleId, true, true) docked at the free bay nearest you; Quick
--                   Launch owners: Vehicle_QuickLaunch(vehicleId), seated at once (a bolt on Spawn).
--   Spawn a car     CarController.Request(vehicleId)     (Land_Request: the nearest road spawn point)
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
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local FootTrail = require(script.Parent:WaitForChild("FootTrail"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))

local C = HudTheme.Colors
local ROBUX_GREEN = Color3.fromHex("2F9E5B")
local player = Players.LocalPlayer
local FOLDERS = { "Vehicles", "LandVehicles" } -- VehicleService / LandVehicleService
local PREVIEWS = "VehiclePreviews" -- ReplicatedStorage folder the two services fill
local UPGRADE_ICON = { Engine = "speed", Hull = "shield", Fit = "seat" }
local UPGRADE_WORD = { Engine = "Engine", Hull = "Hull", Fit = "Seat" }
local TABS = {
	{ name = "Boats", glyph = "boat" },
	{ name = "Jet Skis", glyph = "jetski" },
	{ name = "Cars", glyph = "car" },
}
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
local ACTION_PAGE = "VehiclesApp_Page"
local ACTION_TAB = "VehiclesApp_Tab"
local KG_PER_RMU = 37 -- VehicleConfig massHint units

type Entry = {
	id: string,
	land: boolean,
	tab: number,
	name: string,
	premium: boolean, -- Robux only
	pass: string?, -- GamePasses key
	speed: number,
	people: number,
	mass: number, -- kg
}
type Tile = { id: string, button: TextButton, price: TextLabel, coin: Frame, check: Frame }
type Card = {
	entry: Entry,
	frame: Frame,
	vp: ViewportFrame,
	model: Model?,
	real: boolean, -- the spawner's model (not the greybox stand-in)
	camera: Camera?,
	centre: Vector3,
	size: Vector3,
	out: Frame,
	main: TextButton,
	mainLabel: TextLabel,
	mainBolt: Frame,
	cash: TextButton,
	cashLabel: TextLabel,
	cashCoin: Frame,
	robux: TextButton,
	robuxLabel: TextLabel,
	quick: TextButton?,
	tiles: { Tile },
	flash: string?,
}
type Tab = {
	button: TextButton,
	strip: Frame,
	pages: UIPageLayout,
	dots: { Frame },
	cards: { Card },
}

local VehiclesApp = {}

local function ownsQuick(): boolean
	return player:GetAttribute("Pass_" .. QUICK) == true
end

local function ownsPass(entry: Entry): boolean
	return entry.pass ~= nil and player:GetAttribute("Pass_" .. entry.pass) == true
end

local function passId(entry: Entry): number
	local item = if entry.pass then MonetizationConfig.GamePasses[entry.pass] else nil
	return if item and item.ready then item.id else 0
end

-- icons Glyph lacks, from the same pill bars
local function drawIcon(kind: string, parent: Instance, c: Color3)
	local bar, v = Glyph.bar, Vector2.new
	if kind == "car" then
		bar(parent, v(0.92, 0.26), v(0.5, 0.56), 0, c, 0.35)
		bar(parent, v(0.5, 0.24), v(0.48, 0.38), 0, c, 0.45)
		bar(parent, v(0.24, 0.24), v(0.26, 0.74), 0, c)
		bar(parent, v(0.24, 0.24), v(0.74, 0.74), 0, c)
	elseif kind == "jetski" then
		bar(parent, v(0.9, 0.18), v(0.5, 0.7), -6, c, 0.5)
		bar(parent, v(0.38, 0.13), v(0.6, 0.55), 0, c)
		bar(parent, v(0.08, 0.32), v(0.32, 0.46), 22, c)
		bar(parent, v(0.26, 0.08), v(0.27, 0.3), 0, c)
	elseif kind == "shield" then
		bar(parent, v(0.62, 0.46), v(0.5, 0.36), 0, c, 0.2)
		bar(parent, v(0.44, 0.44), v(0.5, 0.56), 45, c, 0.15)
	else
		Glyph.draw(kind, parent, c)
	end
end

-- a small gold lightning bolt (two slanted bars)
local function bolt(parent: Instance, size: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Bolt"
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.Parent = parent
	for _, spec in
		{ { 0.62, 0.27, 0.2, 0.5, 22 }, { 0.5, 0.5, 0.56, 0.14, 0 }, { 0.38, 0.73, 0.2, 0.5, 22 } }
	do
		Glyph.bar(
			f,
			Vector2.new(spec[3], spec[4]),
			Vector2.new(spec[1], spec[2]),
			spec[5],
			C.gold,
			0
		)
	end
	return f
end

local function entries(): { Entry }
	local out: { Entry } = {}
	for _, id in VehicleConfig.Order do
		local spec = VehicleConfig.get(id)
		local unlock = ProgressionConfig.Vehicles[id]
		if spec then
			table.insert(out, {
				id = id,
				land = false,
				tab = if VehicleConfig.isJetSki(id) then 2 else 1,
				name = spec.displayName,
				premium = unlock ~= nil and unlock.passOnly == true,
				pass = Rules.vehiclePass(id),
				speed = spec.topSpeed,
				people = spec.seats + spec.survivorCapacity,
				mass = spec.massHint * KG_PER_RMU,
			})
		end
	end
	for _, id in LandVehicleConfig.Order do
		local spec = (LandVehicleConfig :: any)[id]
		local unlock = ProgressionConfig.Vehicles[id]
		if spec then
			table.insert(out, {
				id = id,
				land = true,
				tab = 3,
				name = spec.displayName,
				premium = unlock ~= nil and unlock.passOnly == true,
				pass = Rules.vehiclePass(id),
				speed = spec.topSpeed,
				people = spec.seats,
				mass = spec.mass,
			})
		end
	end
	return out
end

-- 0..1 bar fills, scaled across the sea fleet or the land fleet
local function statFills(list: { Entry }): { [string]: { number } }
	local range = {}
	for _, land in { false, true } do
		local r = { speed = 0, people = 0, lo = math.huge, hi = 0 }
		for _, e in list do
			if e.land == land then
				r.speed = math.max(r.speed, e.speed)
				r.people = math.max(r.people, e.people)
				r.lo = math.min(r.lo, math.log(e.mass))
				r.hi = math.max(r.hi, math.log(e.mass))
			end
		end
		range[land] = r
	end
	local out = {}
	for _, e in list do
		local r = range[e.land]
		local tough = if r.hi > r.lo then (math.log(e.mass) - r.lo) / (r.hi - r.lo) else 1
		out[e.id] = {
			math.max(0.12, e.speed / r.speed),
			math.max(0.12, e.people / r.people),
			0.15 + 0.85 * tough,
		}
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

local function list(parent: Instance, horizontal: boolean, gap: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = if horizontal
		then Enum.FillDirection.Horizontal
		else Enum.FillDirection.Vertical
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, gap)
	l.Parent = parent
	return l
end

local function button(parent: Instance, name: string, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.BackgroundColor3 = color
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	HudTheme.corner(b, 12)
	b.Parent = parent
	return b
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

-- the preview: the spawner's build, else anyone's live one, else the shared builder's greybox
local function previewModel(entry: Entry): (Model?, boolean)
	local folder = ReplicatedStorage:FindFirstChild(PREVIEWS)
	local source = (folder and folder:FindFirstChild(entry.id)) or liveModel(entry.id, false)
	local model: Model? = if source and source:IsA("Model") then source:Clone() else nil
	local real = model ~= nil
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
			if d:IsA("BaseScript") or d:IsA("Sound") or d:IsA("ProximityPrompt") then
				d:Destroy()
			end
		end
	end
	return model, real
end

-- world box of the visible parts (the hull's invisible physics parts would frame it too loose)
local function visibleBounds(model: Model): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			local half = d.Size / 2
			for _, x in { -1, 1 } do
				for _, y in { -1, 1 } do
					for _, z in { -1, 1 } do
						local p = d.CFrame:PointToWorldSpace(half * Vector3.new(x, y, z))
						lo, hi = lo:Min(p), hi:Max(p)
					end
				end
			end
		end
	end
	if lo.X > hi.X then
		local cf, size = model:GetBoundingBox()
		return cf.Position, size
	end
	return (lo + hi) / 2, hi - lo
end

function VehiclesApp.mount(page: Frame): () -> ()
	local all = entries()
	local fills = statFills(all)
	local tabs: { Tab } = {}
	local activeTab = 1
	local conns: { RBXScriptConnection } = {}
	local snapshot: { [string]: any }? = nil
	local prices: { [number]: number | false } = {} -- pass id -> Robux (false: lookup failed)
	local busy = false
	local alive = true

	local root = Instance.new("Frame")
	root.Name = "Vehicles"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = page

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.Size = UDim2.new(1, 0, 0, 46)
	tabBar.BackgroundColor3 = C.panel
	tabBar.BackgroundTransparency = 0.3
	HudTheme.corner(tabBar, 14)
	tabBar.Parent = root
	list(tabBar, true, 6)
	HudTheme.padding(tabBar, 4)

	local function data(): Rules.PlayerData?
		return if snapshot then Rules.fromSnapshot(snapshot) else nil
	end

	local function pricedOpen(): boolean
		return true -- user 2026-10-21: phone Store and Robux buttons open from the start (world shelves keep rule 6)
	end

	local paint: () -> ()

	local function fetchPrice(id: number)
		if id <= 0 or prices[id] ~= nil then
			return
		end
		prices[id] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.GamePass)
			end)
			local robux = if ok and type(info) == "table" then info.PriceInRobux else nil
			if type(robux) == "number" and alive then
				prices[id] = robux
				paint()
			end
		end)
	end

	local function paintCard(card: Card, d: Rules.PlayerData?)
		local entry = card.entry
		local id = entry.id
		local pass = ownsPass(entry)
		local unlock = ProgressionConfig.Vehicles[id]
		local usable = d ~= nil and Rules.canUseVehicle(d, id, pass)
		local lock = if d then Rules.vehicleLock(d, id) else nil
		local canBuy = d ~= nil and Rules.canBuyVehicle(d, id, pass)
		local robuxId = passId(entry)
		local price = prices[robuxId]
		card.out.Visible = liveModel(id, true) ~= nil
		if card.quick then
			card.quick.Visible = not ownsQuick()
		end

		-- the action row: one big Spawn, or the Cash and Robux buttons side by side
		local showCash = d ~= nil
			and not usable
			and not card.flash
			and unlock ~= nil
			and not unlock.passOnly
		local showRobux = d ~= nil and not usable and not card.flash and entry.pass ~= nil
		card.main.Visible = not (showCash or showRobux)
		card.cash.Visible = showCash
		card.robux.Visible = showRobux
		local half = UDim2.new(0.5, -4, 1, 0)
		card.cash.Size = if showRobux then half else UDim2.fromScale(1, 1)
		card.robux.Size = if showCash then half else UDim2.fromScale(1, 1)
		card.mainBolt.Visible = false
		card.mainLabel.TextColor3 = C.text
		if card.flash then
			card.mainLabel.Text = card.flash
			card.main.BackgroundColor3 = C.locked
			card.mainLabel.TextColor3 = Color3.fromRGB(244, 128, 112)
		elseif not d then
			card.mainLabel.Text = "..."
			card.main.BackgroundColor3 = C.locked
		elseif usable then
			card.mainLabel.Text = "Spawn"
			card.main.BackgroundColor3 = C.accent
			card.mainBolt.Visible = ownsQuick() and not entry.land
		else
			card.mainLabel.Text = "Soon"
			card.main.BackgroundColor3 = C.locked
			card.mainLabel.TextColor3 = C.textDim
		end
		if showCash and unlock then
			card.cashCoin.Visible = lock == nil
			card.cashLabel.Text = if lock
				then string.gsub(lock, "^Rank: ", "")
				else HudTheme.formatNumber(unlock.price)
			card.cashLabel.TextColor3 = if canBuy then C.gold else C.textDim
			card.cash.BackgroundColor3 = if canBuy then C.panelLight else C.locked
		end
		if showRobux then
			local live = robuxId > 0 and type(price) == "number" and pricedOpen()
			card.robuxLabel.Text = if live
				then `{ProductShelves.ROBUX} {HudTheme.formatNumber(price :: number)}`
				else `{ProductShelves.ROBUX} Soon`
			card.robux.BackgroundColor3 = if live then ROBUX_GREEN else C.locked
			card.robuxLabel.TextColor3 = if live then C.text else C.textDim
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
					Rules.ownsVehicle(d, id, pass)
				)
			tile.check.Visible = fitted
			tile.coin.Visible = not fitted
			tile.price.Visible = not fitted
			tile.price.Text = if upgrade then HudTheme.formatNumber(upgrade.price) else ""
			tile.price.TextColor3 = if ok then C.gold else C.textDim
			tile.button.BackgroundColor3 = if fitted then Color3.fromHex("2E5A42") else C.panelLight
			tile.button.BackgroundTransparency = if fitted or ok then 0.05 else 0.5
		end
	end

	paint = function()
		local d = data()
		for _, tab in tabs do
			for _, card in tab.cards do
				paintCard(card, d)
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

	local function pop(target: GuiObject, from: number?)
		local scale = target:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
		scale.Parent = target
		scale.Scale = from or 1.12
		TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end

	-- "not yet": a short wobble instead of a sentence
	local function shake(target: GuiObject)
		target.Rotation = 4
		TweenService:Create(
			target,
			TweenInfo.new(0.06, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 3, true),
			{ Rotation = -4 }
		):Play()
		task.delay(0.4, function()
			target.Rotation = 0
		end)
	end

	-- one remote call at a time; ok -> pop, else the server's reason on the button
	local function call(
		card: Card,
		target: GuiObject,
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
				pop(target)
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

	local function spawnVehicle(card: Card)
		local d = data()
		local id = card.entry.id
		if not (d and Rules.canUseVehicle(d, id, ownsPass(card.entry))) then
			return
		end
		local quickUsed = false
		call(card, card.main, function()
			if card.entry.land then
				local cars = require(
					script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("CarController")
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
	end

	local function buyCash(card: Card)
		local d = data()
		if not (d and Rules.canBuyVehicle(d, card.entry.id, ownsPass(card.entry))) then
			shake(card.cash)
			return
		end
		call(card, card.cash, function()
			return Net.func("BuyGear"):InvokeServer(card.entry.id)
		end)
	end

	local function buyRobux(card: Card)
		local id = passId(card.entry)
		if id <= 0 or type(prices[id]) ~= "number" or not pricedOpen() then
			shake(card.robux)
			return
		end
		local ok, err = pcall(function()
			MarketplaceService:PromptGamePassPurchase(player, id)
		end)
		if not ok then
			warn("[VehiclesApp] pass prompt failed:", err)
		end
	end

	local function setPreview(card: Card, model: Model?, real: boolean)
		if card.model then
			card.model:Destroy()
		end
		card.model, card.real = model, real
		local icon = card.vp.Parent and card.vp.Parent:FindFirstChild("Icon")
		if icon then
			icon:Destroy()
		end
		if model then
			card.centre, card.size = visibleBounds(model)
			model.Parent = card.vp
			if not card.camera then
				local camera = Instance.new("Camera")
				camera.FieldOfView = 28
				camera.Parent = card.vp
				card.vp.CurrentCamera = camera
				card.camera = camera
			end
		else
			local fallback = square(card.vp.Parent :: Instance, "Icon", 90)
			fallback.AnchorPoint = Vector2.new(0.5, 0.5)
			fallback.Position = UDim2.fromScale(0.5, 0.5)
			drawIcon(TABS[card.entry.tab].glyph, fallback, C.text)
		end
	end

	local function statRow(
		parent: Instance,
		order: number,
		icon: string,
		fill: number,
		gold: boolean
	)
		local r = Instance.new("Frame")
		r.Name = `Stat{order}`
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 20)
		r.BackgroundTransparency = 1
		r.Parent = parent
		local i = square(r, "Icon", 20)
		drawIcon(icon, i, C.textDim)
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.new(0, 30, 0.5, -5)
		track.Size = UDim2.new(1, -30, 0, 10)
		track.BackgroundColor3 = C.locked
		track.BorderSizePixel = 0
		HudTheme.corner(track, 5)
		track.Parent = r
		local bar = Instance.new("Frame")
		bar.Name = "Fill"
		bar.Size = UDim2.fromScale(fill, 1)
		bar.BackgroundColor3 = if gold then C.gold else C.bar
		bar.BorderSizePixel = 0
		HudTheme.corner(bar, 5)
		bar.Parent = track
	end

	local function buildCard(tab: Tab, entry: Entry, order: number, count: number): Card
		local hasUpgrades = VehicleUpgrades.Vehicles[entry.id] ~= nil
		local frame = Instance.new("Frame")
		frame.Name = entry.id
		frame.LayoutOrder = order
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = C.panel
		frame.BackgroundTransparency = 0.15
		frame.BorderSizePixel = 0
		HudTheme.corner(frame, 18)
		if entry.premium then
			HudTheme.stroke(frame, C.gold, 2)
		else
			HudTheme.stroke(frame)
		end
		frame.Parent = tab.strip
		list(frame, false, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		HudTheme.padding(frame, 8)

		-- name 30, stats 76, upgrades 70, action 56, padding 16, gaps 8 each
		local fixed = 30 + 76 + 56 + 16 + 8 * 4 + (if hasUpgrades then 70 + 8 else 0)
		local stage = Instance.new("Frame")
		stage.Name = "Stage"
		stage.LayoutOrder = 1
		stage.Size = UDim2.new(1, 0, 1, -fixed)
		stage.BackgroundColor3 = Color3.new(1, 1, 1)
		stage.BorderSizePixel = 0
		stage.ClipsDescendants = true
		HudTheme.corner(stage, 14)
		local grad = Instance.new("UIGradient")
		grad.Color = if entry.premium
			then ColorSequence.new(Color3.fromHex("5A4A2A"), Color3.fromHex("15110A"))
			else ColorSequence.new(Color3.fromHex("3A6F80"), Color3.fromHex("10202A"))
		grad.Rotation = 90
		grad.Parent = stage
		stage.Parent = frame
		-- a soft floor shadow under the turntable
		local floor = Instance.new("Frame")
		floor.Name = "Floor"
		floor.AnchorPoint = Vector2.new(0.5, 0.5)
		floor.Position = UDim2.fromScale(0.5, 0.78)
		floor.Size = UDim2.fromScale(0.8, 0.16)
		floor.BackgroundColor3 = Color3.new(0, 0, 0)
		floor.BackgroundTransparency = 0.55
		floor.BorderSizePixel = 0
		HudTheme.corner(floor, 999)
		floor.Parent = stage
		local vp = Instance.new("ViewportFrame")
		vp.Name = "Preview"
		vp.Size = UDim2.fromScale(1, 1)
		vp.BackgroundTransparency = 1
		vp.Ambient = Color3.fromRGB(135, 145, 160)
		vp.LightColor = Color3.fromRGB(255, 244, 226)
		vp.LightDirection = Vector3.new(-0.6, -1, -0.5)
		vp.Parent = stage

		local actions = Instance.new("Frame")
		actions.Name = "Actions"
		actions.LayoutOrder = 5
		actions.Size = UDim2.new(1, 0, 0, 56)
		actions.BackgroundTransparency = 1
		actions.Parent = frame
		list(actions, true, 8)

		local card: Card = {
			entry = entry,
			frame = frame,
			vp = vp,
			model = nil,
			real = false,
			camera = nil,
			centre = Vector3.zero,
			size = Vector3.one,
			out = square(stage, "Out", 28),
			main = button(actions, "Spawn", C.accent),
			mainLabel = label(actions, "Label", 24, C.text),
			mainBolt = bolt(actions, 24),
			cash = button(actions, "BuyCash", C.panelLight),
			cashLabel = label(actions, "Label", 22, C.gold),
			cashCoin = square(actions, "Coin", 24),
			robux = button(actions, "BuyRobux", ROBUX_GREEN),
			robuxLabel = label(actions, "Label", 22, C.text),
			quick = nil,
			tiles = {},
			flash = nil,
		}
		card.main.Size = UDim2.fromScale(1, 1)
		for i, b in { card.main, card.cash, card.robux } do
			b.LayoutOrder = i
			list(b, true, 6)
		end
		card.mainLabel.Parent, card.mainBolt.Parent = card.main, card.main
		card.cashCoin.Parent, card.cashLabel.Parent = card.cash, card.cash
		card.robuxLabel.Parent = card.robux
		Glyph.draw("coin", card.cashCoin, C.gold)
		for _, l in { card.mainLabel, card.cashLabel, card.robuxLabel } do
			l.LayoutOrder = 1
			l.AutomaticSize = Enum.AutomaticSize.X
			l.Size = UDim2.fromOffset(0, 56)
		end
		card.mainBolt.LayoutOrder = 2
		card.main.Activated:Connect(function()
			spawnVehicle(card)
		end)
		card.cash.Activated:Connect(function()
			buyCash(card)
		end)
		card.robux.Activated:Connect(function()
			buyRobux(card)
		end)

		card.out.AnchorPoint = Vector2.new(1, 0)
		card.out.Position = UDim2.new(1, -8, 0, 8)
		card.out.ZIndex = 3
		Glyph.draw("check", card.out, C.ready)

		-- big arrows over the stage edges (mouse users; touch swipes)
		for _, side in { -1, 1 } do
			local a = Instance.new("TextButton")
			a.Name = if side < 0 then "Prev" else "Next"
			a.AnchorPoint = Vector2.new(if side < 0 then 0 else 1, 0.5)
			a.Position = UDim2.fromScale(if side < 0 then 0 else 1, 0.5)
			a.Size = UDim2.fromOffset(44, 64)
			a.BackgroundTransparency = 1
			a.Font = HudTheme.HeaderFont
			a.TextSize = 44
			a.TextColor3 = C.text
			a.TextTransparency = 0.2
			a.Text = if side < 0 then "‹" else "›"
			a.ZIndex = 3
			a.Visible = if side < 0 then order > 1 else order < count
			a.Parent = stage
			a.Activated:Connect(function()
				if side < 0 then
					tab.pages:Previous()
				else
					tab.pages:Next()
				end
			end)
		end

		-- Quick Launch upsell for non-owners: the Roblox pass prompt (MonetizationService grants Pass_)
		local quickPass = MonetizationConfig.GamePasses[QUICK]
		if not entry.land and quickPass and quickPass.ready and quickPass.id ~= 0 then
			local chip = Instance.new("TextButton")
			chip.Name = "QuickLaunchChip"
			chip.Text = ""
			chip.AnchorPoint = Vector2.new(0, 1)
			chip.Position = UDim2.new(0, 8, 1, -8)
			chip.Size = UDim2.fromOffset(0, 30)
			chip.AutomaticSize = Enum.AutomaticSize.X
			chip.BackgroundColor3 = C.panel
			chip.BackgroundTransparency = 0.2
			chip.ZIndex = 3
			HudTheme.corner(chip, 15)
			HudTheme.stroke(chip, C.gold, 1).Transparency = 0.3
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 6)
			pad.PaddingRight = UDim.new(0, 10)
			pad.Parent = chip
			list(chip, true, 4)
			bolt(chip, 18).LayoutOrder = 0
			local text = label(chip, "Label", 15, C.gold)
			text.Text = "Quick Launch"
			text.LayoutOrder = 1
			text.AutomaticSize = Enum.AutomaticSize.X
			text.Size = UDim2.fromOffset(0, 30)
			chip.Parent = stage
			card.quick = chip
			chip.Activated:Connect(function()
				local ok, err = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, quickPass.id)
				end)
				if not ok then
					warn("[VehiclesApp] Quick Launch prompt failed:", err)
				end
			end)
		end

		local name = label(frame, "Name", 26, if entry.premium then C.gold else C.text)
		name.LayoutOrder = 2
		name.Size = UDim2.new(1, 0, 0, 30)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		name.Text = entry.name

		-- speed, people aboard, toughness
		local stats = Instance.new("Frame")
		stats.Name = "Stats"
		stats.LayoutOrder = 3
		stats.Size = UDim2.new(1, -24, 0, 76)
		stats.BackgroundTransparency = 1
		stats.Parent = frame
		list(stats, false, 8)
		local f = fills[entry.id]
		statRow(stats, 1, "speed", f[1], entry.premium)
		statRow(stats, 2, "seat", f[2], entry.premium)
		statRow(stats, 3, "shield", f[3], entry.premium)

		-- the boat's upgrades: picture + word + coin price, a tick once fitted
		if hasUpgrades then
			local tiles = Instance.new("Frame")
			tiles.Name = "Upgrades"
			tiles.LayoutOrder = 4
			tiles.Size = UDim2.new(1, 0, 0, 70)
			tiles.BackgroundTransparency = 1
			tiles.Parent = frame
			list(tiles, true, 8)
			for i, upgradeId in VehicleUpgrades.UpgradeOrder do
				local b = button(tiles, upgradeId, C.panelLight)
				b.LayoutOrder = i
				b.Size = UDim2.new(1 / 3, -6, 1, 0)
				local icon = square(b, "Icon", 26)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 5)
				drawIcon(UPGRADE_ICON[upgradeId] or "ring", icon, C.text)
				local word = label(b, "Word", 13, C.textDim)
				word.Position = UDim2.fromOffset(0, 32)
				word.Size = UDim2.new(1, 0, 0, 14)
				word.Text = UPGRADE_WORD[upgradeId] or upgradeId
				local priceRow = Instance.new("Frame")
				priceRow.Name = "Price"
				priceRow.AnchorPoint = Vector2.new(0, 1)
				priceRow.Position = UDim2.new(0, 0, 1, -3)
				priceRow.Size = UDim2.new(1, 0, 0, 20)
				priceRow.BackgroundTransparency = 1
				priceRow.Parent = b
				list(priceRow, true, 2)
				local coin = square(priceRow, "Coin", 14)
				Glyph.draw("coin", coin, C.gold)
				local price = label(priceRow, "Amount", 15, C.gold)
				price.LayoutOrder = 1
				price.AutomaticSize = Enum.AutomaticSize.X
				price.Size = UDim2.fromOffset(0, 20)
				local check = square(priceRow, "Fitted", 18)
				check.LayoutOrder = 2
				Glyph.draw("check", check, C.ready)
				table.insert(
					card.tiles,
					{ id = upgradeId, button = b, price = price, coin = coin, check = check }
				)
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

		local model, real = previewModel(entry)
		setPreview(card, model, real)
		fetchPrice(passId(entry))
		return card
	end

	local function selectFor(card: Card?)
		if card and UserInputService.GamepadEnabled and page.Visible then
			GuiService.SelectedObject = if card.main.Visible
				then card.main
				elseif card.robux.Visible then card.robux
				else card.cash
		end
	end

	local function current(): Card?
		local tab = tabs[activeTab]
		for _, card in tab.cards do
			if card.frame == tab.pages.CurrentPage then
				return card
			end
		end
		return nil
	end

	local function setTab(index: number)
		activeTab = index
		for i, tab in tabs do
			local on = i == index
			tab.strip.Visible = on
			tab.button.BackgroundColor3 = if on then C.accent else C.panelLight
			tab.button.BackgroundTransparency = if on then 0 else 0.4
		end
		local card = current()
		if card then
			pop(card.frame, 0.96)
		end
		selectFor(card)
	end

	for i, def in TABS do
		local b = button(tabBar, def.name, C.panelLight)
		b.LayoutOrder = i
		b.Size = UDim2.new(1 / 3, -4, 1, 0)
		list(b, true, 6)
		local icon = square(b, "Icon", 22)
		drawIcon(def.glyph, icon, C.text)
		local text = label(b, "Label", 17, C.text)
		text.LayoutOrder = 1
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, 38)
		text.Text = def.name

		local strip = Instance.new("Frame")
		strip.Name = `Cards_{def.name}`
		strip.Position = UDim2.fromOffset(0, 54)
		strip.Size = UDim2.new(1, 0, 1, -54 - 20)
		strip.BackgroundTransparency = 1
		strip.ClipsDescendants = true
		strip.Visible = false
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
		local tab: Tab = { button = b, strip = strip, pages = pages, dots = {}, cards = {} }
		tabs[i] = tab
		b.Activated:Connect(function()
			setTab(i)
		end)

		local mine: { Entry } = {}
		for _, e in all do
			if e.tab == i then
				table.insert(mine, e)
			end
		end
		-- page dots under the strip (gold for the premium ones)
		local dots = Instance.new("Frame")
		dots.Name = `Dots_{def.name}`
		dots.AnchorPoint = Vector2.new(0, 1)
		dots.Position = UDim2.fromScale(0, 1)
		dots.Size = UDim2.new(1, 0, 0, 16)
		dots.BackgroundTransparency = 1
		dots.Parent = root
		list(dots, true, 6)
		for n, entry in mine do
			table.insert(tab.cards, buildCard(tab, entry, n, #mine))
			local dot = Instance.new("Frame")
			dot.Name = `Dot{n}`
			dot.LayoutOrder = n
			dot.Size = UDim2.fromOffset(8, 8)
			dot.BackgroundColor3 = if entry.premium then C.gold else C.textDim
			dot.BorderSizePixel = 0
			HudTheme.corner(dot, 99)
			dot.Parent = dots
			tab.dots[n] = dot
		end
		local function onPage()
			local card = current()
			for n, dot in tab.dots do
				local on = tab.cards[n].frame == pages.CurrentPage
				dot.Size = UDim2.fromOffset(if on then 20 else 8, 8)
				dot.BackgroundTransparency = if on then 0 else 0.4
			end
			if activeTab == i then
				selectFor(card)
			end
		end
		table.insert(conns, pages:GetPropertyChangedSignal("CurrentPage"):Connect(onPage))
		table.insert(
			conns,
			strip:GetPropertyChangedSignal("Visible"):Connect(function()
				dots.Visible = strip.Visible
			end)
		)
		dots.Visible = false
		onPage()
	end

	-- previews published after the page opened replace the stand-ins
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild(PREVIEWS, 60)
		if not (folder and alive) then
			return
		end
		local function upgrade()
			for _, tab in tabs do
				for _, card in tab.cards do
					if not card.real and folder:FindFirstChild(card.entry.id) then
						setPreview(card, previewModel(card.entry))
					end
				end
			end
		end
		table.insert(conns, folder.ChildAdded:Connect(upgrade))
		upgrade()
	end)

	-- the turntable: only the card in view turns
	local angle = 0.6
	table.insert(
		conns,
		RunService.RenderStepped:Connect(function(dt: number)
			local card = current()
			if card and card.camera and page.Visible then
				angle += dt * 0.35
				-- fit the length to the stage width and the height to the stage height
				local px = card.vp.AbsoluteSize
				local tanV = math.tan(math.rad(card.camera.FieldOfView / 2))
				local tanH = tanV * (if px.Y > 0 then px.X / px.Y else 1)
				local s = card.size
				local distance = math.max(math.max(s.X, s.Z) / 2 / tanH, s.Y / tanV) * 1.12
					+ math.min(s.X, s.Z) / 2
				local eye = Vector3.new(math.sin(angle), 0.36, math.cos(angle)).Unit * distance
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
			local pages = tabs[activeTab].pages
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
	ContextActionService:BindActionAtPriority(
		ACTION_TAB,
		function(_, state, input): Enum.ContextActionResult
			if state ~= Enum.UserInputState.Begin or not page.Visible then
				return Enum.ContextActionResult.Pass
			end
			local step = if input.KeyCode == Enum.KeyCode.Up then -1 else 1
			setTab((activeTab - 1 + step) % #tabs + 1)
			return Enum.ContextActionResult.Sink
		end,
		false,
		Enum.ContextActionPriority.High.Value,
		Enum.KeyCode.Up,
		Enum.KeyCode.Down,
		Enum.KeyCode.ButtonY
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
	-- a vehicle pass bought (or Quick Launch): Spawn appears at once
	table.insert(
		conns,
		player.AttributeChanged:Connect(function(name: string)
			if string.sub(name, 1, 5) == "Pass_" or name == "OpsCompleted" then
				paint()
			end
		end)
	)
	paint()
	-- open on the vehicle you have out
	local opened = false
	for i, tab in tabs do
		for _, card in tab.cards do
			if not opened and card.out.Visible then
				tab.pages:JumpTo(card.frame)
				setTab(i)
				opened = true
			end
		end
	end
	if not opened then
		setTab(1)
	end
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
		ContextActionService:UnbindAction(ACTION_TAB)
		for _, c in conns do
			c:Disconnect()
		end
		root:Destroy()
	end
end

VehiclesApp.portrait = true -- the phone stays upright (Phone.luau OPTIONAL)

return VehiclesApp
