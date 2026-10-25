--!strict
-- VehiclesApp: the phone's vehicle page (portrait). Since docs/23 c.5 the boats are chosen and bought at
-- the dock's boards, so the phone page is just one big Boat to me (RequestVehicle(nil, false, true): your
-- current or last craft comes to the open water nearest you, seated). A board opens one card through
-- Phone.openApp(_, mount) with `only` = that craft (buy, upgrades, Spawn = docked at the berth).
-- Cards: a swipeable carousel of big navy cards (Hud.Panel skin): a slowly turning 3D preview of the real
-- model (the server's ReplicatedStorage.VehiclePreviews.<id>, the exact build the spawner makes; else a
-- live one of that kind; else the shared builder's greybox), the name (gold for the Robux-only premium
-- fleet), three stat bars (speed, people aboard, toughness; fitted upgrades lengthen them), the boat's
-- upgrades (icon, word, coin price, tick once fitted) and the action row: Spawn when owned (spawning
-- another craft swaps yours: this is how you switch, docs/16 K3), else a Cash button (coin + price, or
-- the rank it needs) and a Robux button (the vehicle's Game Pass, Roblox's live price).
-- Opens on the cheapest thing Cash covers (shared/Affordable), else the craft you have out, else the
-- biggest one you own. That upgrade tile or Cash button pulses gold; a buy throws coins and sparks
-- and the stat bar grows (docs/16 B5).
-- Mouse / touch: round arrows and swipe; keyboard: Left / Right or Q / E vehicles; gamepad: L2 / R2
-- vehicles, A on the selected button.
--   Buy with Cash   BuyGear(vehicleId)                   (ProgressionService: rank + Cash)
--   Buy with Robux  PromptGamePassPurchase(pass id)      (MonetizationService grants Pass_<Key>; the
--                   server's CanUseVehicle reads it: Cash-owned OR pass-owned)
--   Fit upgrade     Upgrade_Buy(vehicleId, upgradeId)    (UpgradeService)
--   Spawn a boat    (the board's card) RequestVehicle(vehicleId, true): docked at your berth
-- Spawning closes the phone and FootTrail walks you to it. Data: PlayerDataChanged snapshots.
--   VehiclesApp.mount(page: Frame, close?, only: string?) -> cleanup
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
local Affordable = require(Shared:WaitForChild("Affordable"))
local BoatBuilder = require(Shared:WaitForChild("Boat"):WaitForChild("Builder"))
local MonetizationConfig = require(Config:WaitForChild("MonetizationConfig"))
local MonetizationEffects = require(Shared:WaitForChild("MonetizationEffects"))
local Net = require(Shared:WaitForChild("Net"))
local ProductShelves = require(Shared:WaitForChild("ProductShelves"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local UiImages = require(Config:WaitForChild("UiImages"))
local VehicleConfig = require(Config:WaitForChild("VehicleConfig"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local Client = script.Parent.Parent
local AudioController = require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))
local Comfort = require(Client:WaitForChild("Camera"):WaitForChild("Comfort"))
local FootTrail = require(script.Parent:WaitForChild("FootTrail"))
local Glyph = require(script.Parent:WaitForChild("Glyph"))
local HudTheme = require(script.Parent:WaitForChild("HudTheme"))
local Telemetry = require(Client:WaitForChild("Telemetry"))

local C = HudTheme.Colors
local ROBUX_GREEN = Color3.fromHex("2F9E5B")
local player = Players.LocalPlayer
local FOLDERS = { "Vehicles" } -- VehicleService
local PREVIEWS = "VehiclePreviews" -- ReplicatedStorage folder the two services fill
local UPGRADE_ICON = { Engine = "speed", Hull = "shield", Fit = "seat" }
local STAT_ART = { "Speed", "People", "Tough" } -- UiImages.VehicleArt keys of the three stat rows
local STAT_WORD = { "SPEED", "SEATS", "TOUGH" } -- the small-caps word after each stat icon
local STAT_WORD_W = 52 -- du
local ENGINE, HULL = 1.08, 0.1 -- how far a fitted Engine / Hull lengthens the speed / toughness bar
local UPGRADE_WORD = { Engine = "Engine", Hull = "Hull", Fit = "Seat" }
local TABS = {
	{ name = "Boats", glyph = "boat" },
	{ name = "Jet Skis", glyph = "jetski" },
}
local TAB_H = 40
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
local BOAT_TO_ME_H = 72
local KG_PER_RMU = 37 -- VehicleConfig massHint units

type Entry = {
	id: string,
	tab: number,
	name: string,
	premium: boolean, -- Robux only
	pass: string?, -- GamePasses key
	speed: number,
	people: number,
	mass: number, -- kg
}
type Tile = {
	id: string,
	button: TextButton,
	price: TextLabel,
	coin: ImageLabel,
	check: Frame,
	glow: UIStroke,
}
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
	floor: Frame,
	main: TextButton,
	mainLabel: TextLabel,
	mainBolt: Frame,
	cash: TextButton,
	cashLabel: TextLabel,
	cashCoin: ImageLabel,
	cashGlow: UIStroke,
	robux: TextButton,
	robuxLabel: TextLabel,
	quick: TextButton?,
	tiles: { Tile },
	flash: string?,
	bars: { Frame }, -- speed, people, toughness fills
	fillNow: { number }, -- what they show (-1: not painted yet)
	hot: GuiObject?, -- the pulsing buy on this card
}
type Tab = {
	button: TextButton,
	strip: Frame,
	pages: UIPageLayout,
	dots: { Frame },
	cards: { Card },
}

local VehiclesApp = {}

local function ownsQuick(): boolean -- the pass or its day pass (the server's rule)
	local ends = player:GetAttribute("DayPass_" .. QUICK)
	return MonetizationEffects.passActive(
		player:GetAttribute("Pass_" .. QUICK) == true,
		if type(ends) == "number" then ends else nil,
		Workspace:GetServerTimeNow()
	)
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
	if kind == "jetski" then
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

-- an uploaded icon (UiImages.VehicleArt, docs/18) when there is one, else the drawn glyph
local function art(key: string, glyph: string, parent: Instance, c: Color3)
	local image = (UiImages.VehicleArt :: { [string]: string })[key]
	if image and image ~= "" then
		local i = Instance.new("ImageLabel")
		i.Name = "Art"
		i.Size = UDim2.fromScale(1, 1)
		i.BackgroundTransparency = 1
		i.Image = image
		i.ScaleType = Enum.ScaleType.Fit
		i.Parent = parent
	else
		drawIcon(glyph, parent, c)
	end
end

-- the HUD's coin sprite
local function coinIcon(parent: Instance, px: number): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Name = "Coin"
	i.Size = UDim2.fromOffset(px, px)
	i.BackgroundTransparency = 1
	i.Image = UiImages.Hud.Coin
	i.ScaleType = Enum.ScaleType.Fit
	i.Parent = parent
	return i
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
	return out
end

-- 0..1 bar fills, scaled across the fleet, with room left for the upgrades
local function statFills(list: { Entry }): { [string]: { number } }
	local r = { speed = 0, people = 0, lo = math.huge, hi = 0 }
	for _, e in list do
		r.speed = math.max(r.speed, e.speed)
		r.people = math.max(r.people, e.people)
		r.lo = math.min(r.lo, math.log(e.mass))
		r.hi = math.max(r.hi, math.log(e.mass))
	end
	local out = {}
	for _, e in list do
		local tough = if r.hi > r.lo then (math.log(e.mass) - r.lo) / (r.hi - r.lo) else 1
		out[e.id] = {
			math.max(0.12, e.speed / (r.speed * ENGINE)),
			math.max(0.12, e.people / (r.people + 1)),
			0.15 + (0.85 - HULL) * tough,
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

function VehiclesApp.mount(page: Frame, _close: (() -> ())?, only: string?): () -> ()
	Telemetry.shop("AppOpened", "Vehicles")
	local all = entries()
	local fills = statFills(all)
	local shown: { Entry } = {}
	for _, e in all do
		if e.id == only then -- no `only`: the phone page, Boat to me alone
			table.insert(shown, e)
		end
	end
	local tabs: { Tab } = {}
	local activeTab = if shown[1] then shown[1].tab else 3
	local conns: { RBXScriptConnection } = {}
	local snapshot: { [string]: any }? = nil
	local prices: { [number]: number | false } = {} -- pass id -> Robux (false: lookup failed)
	local busy = false
	local alive = true
	local mountedAt = os.clock()
	local hot: GuiObject? = nil -- the one pulsing buy (an upgrade tile or a Cash button)
	local hotGlow: UIStroke? = nil

	local root = Instance.new("Frame")
	root.Name = "Vehicles"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = page

	local setTab: (index: number) -> ()
	local tabNames = {}
	for i, def in TABS do
		tabNames[i] = def.name
	end
	local segments, tabButtons, setSegment = HudTheme.segmented(
		root,
		tabNames,
		TAB_H,
		function(i: number)
			setTab(i)
		end
	)
	segments.Visible = false -- one craft per page now (a board's), none on the phone page
	local top = if only then 0 else BOAT_TO_ME_H + 10

	local function data(): Rules.PlayerData?
		return if snapshot then Rules.fromSnapshot(snapshot) else nil
	end

	-- the cheapest buy Cash covers now (the phone's red dot reads the same)
	local function pick(): Affordable.Pick?
		local snap = snapshot
		return if snap
			then Affordable.cheapest(snap, function(vehicleId: string): boolean
				local pass = Rules.vehiclePass(vehicleId)
				return pass ~= nil and player:GetAttribute("Pass_" .. pass) == true
			end)
			else nil
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

	local function paintCard(card: Card, d: Rules.PlayerData?, best: Affordable.Pick?)
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
		card.hot = nil
		local buyHere = best ~= nil and best.vehicleId == id
		card.cashGlow.Enabled = buyHere and best ~= nil and best.upgradeId == nil and showCash
		if card.cashGlow.Enabled then
			card.hot = card.cash
		end
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
			tile.glow.Enabled = buyHere and best ~= nil and best.upgradeId == tile.id
			if tile.glow.Enabled then
				card.hot = tile.button
			end
		end

		-- the stat bars, lengthened by fitted upgrades; a change grows with a flash
		local base = fills[id]
		local want = {
			base[1] * (if VehicleUpgrades.has(mask, "Engine") then ENGINE else 1),
			base[2] * (if VehicleUpgrades.has(mask, "Fit")
				then (entry.people + 1) / entry.people
				else 1),
			base[3] + (if VehicleUpgrades.has(mask, "Hull") then HULL else 0),
		}
		for i, bar in card.bars do
			local fill = math.min(1, want[i])
			local was = card.fillNow[i]
			if math.abs(was - fill) > 1e-3 then
				card.fillNow[i] = fill
				if was < 0 or Comfort.reducedMotion() then
					bar.Size = UDim2.fromScale(fill, 1)
				else
					local colour = if entry.premium then C.gold else C.bar
					bar.BackgroundColor3 = Color3.new(1, 1, 1)
					TweenService:Create(
						bar,
						TweenInfo.new(
							0.7,
							Enum.EasingStyle.Back,
							Enum.EasingDirection.Out,
							0,
							false,
							0.15
						),
						{ Size = UDim2.fromScale(fill, 1) }
					):Play()
					TweenService:Create(
						bar,
						TweenInfo.new(0.9, Enum.EasingStyle.Quad),
						{ BackgroundColor3 = colour }
					):Play()
				end
			end
		end
	end

	paint = function()
		local d = data()
		local best = pick()
		local nextHot: GuiObject? = nil
		for _, tab in tabs do
			for _, card in tab.cards do
				paintCard(card, d, best)
				nextHot = nextHot or card.hot
			end
		end
		if nextHot ~= hot then
			local old = hot
			local scale = old and old:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 1 -- the pulse ends on the old one
			end
			hot = nextHot
			hotGlow = if nextHot then nextHot:FindFirstChild("Glow") :: UIStroke? else nil
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

	-- a buy: coins and sparks burst out of the button over its card, with the till sound
	local function celebrate(card: Card, from: GuiObject)
		AudioController.play("Cash_Coins")
		if Comfort.reducedMotion() then
			return
		end
		local host = card.frame
		local size = host.AbsoluteSize
		if size.X <= 0 or size.Y <= 0 then
			return
		end
		local at = (from.AbsolutePosition + from.AbsoluteSize / 2 - host.AbsolutePosition) / size
		local function fly(obj: GuiObject, angle: number, reach: number, t: number)
			obj.AnchorPoint = Vector2.new(0.5, 0.5)
			obj.Position = UDim2.fromScale(at.X, at.Y)
			obj.ZIndex = 10
			obj.Parent = host
			local to = UDim2.new(at.X, math.cos(angle) * reach, at.Y, math.sin(angle) * reach - 20)
			TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quart), { Position = to })
				:Play()
			TweenService:Create(
				obj,
				TweenInfo.new(
					0.25,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In,
					0,
					false,
					t - 0.2
				),
				{
					[if obj:IsA("ImageLabel")
						then "ImageTransparency"
						else "BackgroundTransparency"] = 1,
				}
			):Play()
			task.delay(t + 0.1, function()
				obj:Destroy()
			end)
		end
		for i = 1, 8 do -- coins: the HUD sprite, spinning out
			local coin = coinIcon(host, 20)
			coin.Rotation = math.random(-30, 30)
			fly(coin, -math.pi / 2 + (i - 4.5) * 0.36, math.random(60, 95), 0.6)
		end
		for i = 1, 12 do -- sparks: short gold streaks pointing outwards
			local angle = (i / 12) * math.pi * 2 + math.random() * 0.3
			local spark = Instance.new("Frame")
			spark.Size = UDim2.fromOffset(14, 3)
			spark.Rotation = math.deg(angle)
			spark.BackgroundColor3 = if i % 3 == 0 then Color3.new(1, 1, 1) else C.gold
			spark.BorderSizePixel = 0
			HudTheme.corner(spark, 2)
			fly(spark, angle, math.random(40, 70), 0.4)
		end
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
		call(card, card.main, function()
			return Net.func("RequestVehicle"):InvokeServer(id, true) -- the board's card: docked at your berth
		end, function(result: any)
			spawned(result)
		end)
	end

	local function buyCash(card: Card)
		local d = data()
		if not (d and Rules.canBuyVehicle(d, card.entry.id, ownsPass(card.entry))) then
			shake(card.cash)
			return
		end
		Telemetry.shop("BuyTapped", "Vehicles", card.entry.id, "Cash")
		call(card, card.cash, function()
			return Net.func("BuyGear"):InvokeServer(card.entry.id)
		end, function()
			celebrate(card, card.cash)
		end)
	end

	local function buyRobux(card: Card)
		local id = passId(card.entry)
		if id <= 0 or type(prices[id]) ~= "number" or not pricedOpen() then
			shake(card.robux)
			return
		end
		Telemetry.shop("BuyTapped", "Vehicles", card.entry.pass, "Robux")
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

	local function statRow(parent: Instance, order: number, icon: string, gold: boolean): Frame
		local r = Instance.new("Frame")
		r.Name = `Stat{order}`
		r.LayoutOrder = order
		r.Size = UDim2.new(1, 0, 0, 20)
		r.BackgroundTransparency = 1
		r.Parent = parent
		local i = square(r, "Icon", 20)
		art(STAT_ART[order], icon, i, C.textDim)
		local word = HudTheme.label(
			"Word",
			STAT_WORD[order],
			UDim2.new(0, STAT_WORD_W, 1, 0),
			HudTheme.LabelFont,
			12,
			r
		)
		word.Position = UDim2.fromOffset(26, 0)
		word.TextColor3 = C.textDim
		local x = 30 + STAT_WORD_W
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.Position = UDim2.new(0, x, 0.5, -4)
		track.Size = UDim2.new(1, -x, 0, 8)
		track.BackgroundColor3 = C.locked
		track.BorderSizePixel = 0
		HudTheme.corner(track, 4)
		track.Parent = r
		local bar = Instance.new("Frame")
		bar.Name = "Fill"
		bar.Size = UDim2.fromScale(0, 1)
		bar.BackgroundColor3 = if gold then C.gold else C.bar
		bar.BorderSizePixel = 0
		HudTheme.corner(bar, 4)
		bar.Parent = track
		return bar
	end

	local function buildCard(tab: Tab, entry: Entry, order: number, count: number): Card
		local hasUpgrades = VehicleUpgrades.Vehicles[entry.id] ~= nil
		local frame = Instance.new("Frame")
		frame.Name = entry.id
		frame.LayoutOrder = order
		frame.Size = UDim2.fromScale(1, 1)
		frame.Parent = tab.strip
		HudTheme.skin(frame) -- the HUD's navy card, as in the Store
		local body = Instance.new("Frame")
		body.Name = "Body"
		body.Size = UDim2.fromScale(1, 1)
		body.BackgroundTransparency = 1
		body.Parent = frame
		list(body, false, 8).VerticalAlignment = Enum.VerticalAlignment.Top
		HudTheme.padding(body, 10)

		-- name 30, stats 76, upgrades 70, action 56, padding 20, gaps 8 each
		local fixed = 30 + 76 + 56 + 20 + 8 * 4 + (if hasUpgrades then 70 + 8 else 0)
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
		stage.Parent = body
		-- a soft floor shadow, kept under the vehicle by the turntable; two faded ellipses for a soft edge
		local floor = Instance.new("Frame")
		floor.Name = "Floor"
		floor.AnchorPoint = Vector2.new(0.5, 0.5)
		floor.Position = UDim2.fromScale(0.5, 0.62)
		floor.Size = UDim2.fromScale(0.6, 0.1)
		floor.BackgroundTransparency = 1
		floor.Parent = stage
		for _, k in { 1, 0.55 } do
			local blob = Instance.new("Frame")
			blob.AnchorPoint = Vector2.new(0.5, 0.5)
			blob.Position = UDim2.fromScale(0.5, 0.5)
			blob.Size = UDim2.fromScale(k, k)
			blob.BackgroundColor3 = Color3.new(0, 0, 0)
			blob.BorderSizePixel = 0
			HudTheme.corner(blob, 999)
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = blob
			blob.Parent = floor
		end
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
		actions.Parent = body
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
			floor = floor,
			main = button(actions, "Spawn", C.accent),
			mainLabel = label(actions, "Label", 24, C.text),
			mainBolt = bolt(actions, 24),
			cash = button(actions, "BuyCash", C.panelLight),
			cashLabel = label(actions, "Label", 22, C.gold),
			cashCoin = coinIcon(actions, 24),
			cashGlow = HudTheme.stroke(actions, C.gold, 2.5),
			robux = button(actions, "BuyRobux", ROBUX_GREEN),
			robuxLabel = label(actions, "Label", 22, C.text),
			quick = nil,
			tiles = {},
			flash = nil,
			bars = {},
			fillNow = { -1, -1, -1 },
			hot = nil,
		}
		card.main.Size = UDim2.fromScale(1, 1)
		for i, b in { card.main, card.cash, card.robux } do
			b.LayoutOrder = i
			list(b, true, 6)
		end
		card.mainLabel.Parent, card.mainBolt.Parent = card.main, card.main
		card.cashCoin.Parent, card.cashLabel.Parent = card.cash, card.cash
		card.robuxLabel.Parent = card.robux
		card.cashGlow.Name = "Glow"
		card.cashGlow.Enabled = false
		card.cashGlow.Parent = card.cash
		for _, l in { card.mainLabel, card.cashLabel, card.robuxLabel } do
			l.Font = Enum.Font.BuilderSansBold
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
		art("Check", "check", card.out, C.ready)

		-- big round arrows over the stage edges (touch also swipes); dimmed at the ends of the list
		for _, side in { -1, 1 } do
			local live = if side < 0 then order > 1 else order < count
			local a = Instance.new("TextButton")
			a.Name = if side < 0 then "Prev" else "Next"
			a.Text = ""
			a.AutoButtonColor = false
			a.Active = live
			a.AnchorPoint = Vector2.new(0.5, 0.5)
			a.Position = UDim2.new(if side < 0 then 0 else 1, -side * 30, 0.5, 0)
			a.Size = UDim2.fromOffset(48, 48)
			a.BackgroundColor3 = Color3.new(0, 0, 0)
			a.BackgroundTransparency = if live then 0.45 else 0.8
			a.ZIndex = 3
			HudTheme.corner(a, 999)
			HudTheme.stroke(a, Color3.new(1, 1, 1), 1.5).Transparency = if live then 0.7 else 0.9
			-- chevron from two rotated bars (the text "‹" read too thin)
			for _, half in { -1, 1 } do
				local bar = Instance.new("Frame")
				bar.AnchorPoint = Vector2.new(0.5, 0.5)
				bar.Position = UDim2.new(0.5, -side * 2, 0.5, half * 5.5)
				bar.Size = UDim2.fromOffset(16, 4)
				bar.Rotation = -side * half * 45
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				bar.BackgroundTransparency = if live then 0 else 0.7
				bar.BorderSizePixel = 0
				bar.ZIndex = 4
				HudTheme.corner(bar, 2)
				bar.Parent = a
			end
			a.Parent = stage
			if live then
				local scale = Instance.new("UIScale")
				scale.Parent = a
				local function to(v: number)
					TweenService
						:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = v })
						:Play()
				end
				a.MouseEnter:Connect(function()
					to(1.1)
				end)
				a.MouseLeave:Connect(function()
					to(1)
				end)
				a.MouseButton1Down:Connect(function()
					to(0.88)
				end)
				a.MouseButton1Up:Connect(function()
					to(1)
				end)
				a.Activated:Connect(function()
					pop(a, 0.85)
					if side < 0 then
						tab.pages:Previous()
					else
						tab.pages:Next()
					end
				end)
			end
		end

		-- Quick Launch upsell for non-owners: the Roblox pass prompt (MonetizationService grants Pass_)
		local quickPass = MonetizationConfig.GamePasses[QUICK]
		if quickPass and quickPass.ready and quickPass.id ~= 0 then
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
				Telemetry.shop("BuyTapped", "Vehicles", "QuickLaunch", "Robux")
				local ok, err = pcall(function()
					MarketplaceService:PromptGamePassPurchase(player, quickPass.id)
				end)
				if not ok then
					warn("[VehiclesApp] Quick Launch prompt failed:", err)
				end
			end)
		end

		local name = label(body, "Name", 24, if entry.premium then C.gold else C.text)
		name.Font = Enum.Font.BuilderSansBold
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
		stats.Parent = body
		list(stats, false, 8)
		for i, icon in { "speed", "seat", "shield" } do
			card.bars[i] = statRow(stats, i, icon, entry.premium)
		end

		-- the boat's upgrades: picture + word + coin price, a tick once fitted
		if hasUpgrades then
			local tiles = Instance.new("Frame")
			tiles.Name = "Upgrades"
			tiles.LayoutOrder = 4
			tiles.Size = UDim2.new(1, 0, 0, 70)
			tiles.BackgroundTransparency = 1
			tiles.Parent = body
			list(tiles, true, 8)
			local upgrades = VehicleUpgrades.Vehicles[entry.id] -- the jet ski has no Extra seat
			for i, upgrade in upgrades do
				local upgradeId = upgrade.id
				local b = button(tiles, upgradeId, C.panelLight)
				b.LayoutOrder = i
				b.Size = UDim2.new(1 / #upgrades, -6, 1, 0)
				local icon = square(b, "Icon", 26)
				icon.AnchorPoint = Vector2.new(0.5, 0)
				icon.Position = UDim2.new(0.5, 0, 0, 5)
				art(upgradeId, UPGRADE_ICON[upgradeId] or "ring", icon, C.text)
				local glow = HudTheme.stroke(b, C.gold, 2.5)
				glow.Name = "Glow"
				glow.Enabled = false
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
				local coin = coinIcon(priceRow, 16)
				local price = label(priceRow, "Amount", 15, C.gold)
				price.Font = Enum.Font.BuilderSansBold
				price.LayoutOrder = 1
				price.AutomaticSize = Enum.AutomaticSize.X
				price.Size = UDim2.fromOffset(0, 20)
				local check = square(priceRow, "Fitted", 18)
				check.LayoutOrder = 2
				art("Check", "check", check, C.ready)
				table.insert(card.tiles, {
					id = upgradeId,
					button = b,
					price = price,
					coin = coin,
					check = check,
					glow = glow,
				})
				b.Activated:Connect(function()
					Telemetry.shop("BuyTapped", "Vehicles", `{entry.id}:{upgradeId}`, "Cash")
					call(card, b, function()
						local remote = Net.init():WaitForChild("Upgrade_Buy", 10)
						if not (remote and remote:IsA("RemoteFunction")) then
							return false, "NotReady"
						end
						return remote:InvokeServer(entry.id, upgradeId)
					end, function()
						celebrate(card, b)
					end)
				end)
			end
		end

		local model, real = previewModel(entry)
		setPreview(card, model, real)
		fetchPrice(passId(entry))
		return card
	end

	-- the phone page's one boat action: your craft comes to the water nearest you (docs/23 c.5)
	if not only then
		local go = button(root, "BoatToMe", C.accent)
		go.Size = UDim2.new(1, 0, 0, BOAT_TO_ME_H)
		list(go, true, 10)
		local icon = square(go, "Icon", 40)
		drawIcon("boat", icon, C.text)
		local text = label(go, "Label", 24, C.text)
		text.Text = "Boat to me"
		text.LayoutOrder = 1
		text.AutomaticSize = Enum.AutomaticSize.X
		text.Size = UDim2.fromOffset(0, BOAT_TO_ME_H)
		-- the free call's cooldown (WP-11a): a ring of ticks round the boat fills back up; Quick Launch: the bolt
		local fast = bolt(go, 24)
		fast.LayoutOrder = 2
		local ticks: { Frame } = {}
		for i = 1, 24 do
			local a = (i - 0.5) / 24 * 2 * math.pi
			local t = Instance.new("Frame")
			t.Name = "CooldownTick"
			t.AnchorPoint = Vector2.new(0.5, 0.5)
			t.Position = UDim2.fromScale(0.5 + 0.68 * math.sin(a), 0.5 - 0.68 * math.cos(a))
			t.Size = UDim2.fromOffset(5, 5)
			t.BackgroundColor3 = C.gold
			t.BorderSizePixel = 0
			Instance.new("UICorner", t).CornerRadius = UDim.new(1, 0)
			t.Parent = icon
			ticks[i] = t
		end
		local function paintCooldown()
			local last = player:GetAttribute("BoatToMeAt")
			local left = MonetizationEffects.boatToMeWait(
				ownsQuick(),
				if type(last) == "number" then last else nil,
				Workspace:GetServerTimeNow()
			)
			local lit = math.floor((1 - left / MonetizationEffects.BOAT_TO_ME_COOLDOWN) * #ticks)
			for i, t in ticks do
				t.Visible = left > 0 and i <= lit
			end
			fast.Visible = ownsQuick()
		end
		paintCooldown()
		table.insert(conns, RunService.Heartbeat:Connect(paintCooldown))
		local sending = false
		go.Activated:Connect(function()
			if sending then
				return
			end
			sending = true
			task.spawn(function()
				local ok, done, result = pcall(function()
					return Net.func("RequestVehicle"):InvokeServer(nil, false, true)
				end)
				sending = false
				if not alive then
					return
				end
				if ok and done then
					pop(go)
					spawned(result, true) -- seated: no footprints
					return
				end
				local why = if ok then result else "NotReady"
				text.Text = if type(why) == "string" and SHORT[why] then SHORT[why] else "Try again"
				shake(go)
				task.delay(1.6, function()
					text.Text = "Boat to me"
				end)
			end)
		end)
	end

	local viewed = false
	local function selectFor(card: Card?)
		if card and not viewed then
			viewed = true -- the funnel counts the first view per visit; swipes would only spend rate
			Telemetry.shop("ItemViewed", "Vehicles", card.entry.id)
		end
		if card and UserInputService.GamepadEnabled and page.Visible then
			GuiService.SelectedObject = if card.hot
				then card.hot
				elseif card.main.Visible then card.main
				elseif card.robux.Visible then card.robux
				else card.cash
		end
	end

	local function current(): Card?
		local tab = tabs[activeTab]
		if not tab then
			return nil -- the page opens on its last tab, still being built
		end
		for _, card in tab.cards do
			if card.frame == tab.pages.CurrentPage then
				return card
			end
		end
		return nil
	end

	setTab = function(index: number)
		activeTab = index
		setSegment(index)
		for i, tab in tabs do
			tab.strip.Visible = i == index
		end
		local card = current()
		if card then
			pop(card.frame, 0.96)
		end
		selectFor(card)
	end

	for i, def in TABS do
		local strip = Instance.new("Frame")
		strip.Name = `Cards_{def.name}`
		strip.Position = UDim2.fromOffset(0, top)
		strip.Size = UDim2.new(1, 0, 1, -top - 20)
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
		local tab: Tab =
			{ button = tabButtons[i], strip = strip, pages = pages, dots = {}, cards = {} }
		tabs[i] = tab

		local mine: { Entry } = {}
		for _, e in shown do
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
			-- the cheapest affordable buy breathes: a gold ring and a slight swell
			local h, glow = hot, hotGlow
			if h and glow then
				local w = (math.sin(os.clock() * 5) + 1) / 2
				glow.Transparency = 0.6 * (1 - w)
				if not Comfort.reducedMotion() then
					local scale = h:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
					scale.Scale = 1 + 0.04 * w
					scale.Parent = h
				end
			end
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
				-- park the shadow under the hull: project the bottom centre, size it to the length
				local depth = distance + s.Y / 2 * eye.Unit.Y
				local up = card.camera.CFrame.UpVector:Dot(Vector3.new(0, -s.Y / 2, 0) - eye)
				local w = math.clamp(math.max(s.X, s.Z) / (2 * depth * tanH) * 0.85, 0.25, 0.85)
				card.floor.Position = UDim2.fromScale(0.5, 0.5 - up / depth / tanV / 2)
				card.floor.Size = UDim2.fromScale(w, w * 0.22 * px.X / math.max(px.Y, 1))
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
			local k = input.KeyCode
			if k == Enum.KeyCode.Left or k == Enum.KeyCode.ButtonL2 or k == Enum.KeyCode.Q then
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
		Enum.KeyCode.ButtonR2,
		Enum.KeyCode.Q,
		Enum.KeyCode.E
	)

	-- open on the cheapest buy Cash covers, else the craft you have out, else the biggest you own
	local function land()
		local d = data()
		local best = pick()
		local target: string? = if best then best.vehicleId else nil
		for _, tab in tabs do
			for _, card in tab.cards do
				if not target and card.out.Visible then
					target = card.entry.id
				end
			end
		end
		if not target and d then
			for _, e in shown do
				if Rules.canUseVehicle(d, e.id, ownsPass(e)) then
					target = e.id
				end
			end
		end
		for i, tab in tabs do
			for _, card in tab.cards do
				if card.entry.id == target then
					tab.pages:JumpTo(card.frame)
					setTab(i)
					return
				end
			end
		end
		setTab(activeTab)
	end

	local landed = false
	local function onData(d: any)
		if type(d) == "table" and alive then
			snapshot = d
			paint()
			-- the first data lands the page, unless the player has been browsing a while already
			if not landed and os.clock() - mountedAt < 1.5 then
				land()
			end
			landed = true
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
	land()
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
