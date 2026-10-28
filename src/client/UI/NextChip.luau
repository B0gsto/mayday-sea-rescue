--!strict
-- NextChip: the permanent "what to build next" chip (docs/24 E/F) in the HudLayout "chips" slot.
-- The UI kit look (owner 2026-10-28: the slate bar read as a dev HUD): a blue block card, the next building's
-- Lego icon on a white tile over its left edge, its 1-3 word name, a Cash bar to its price and coin + price.
-- At the price the price turns into a green pill with one pop (never a looping pulse: owner 2026-10-28);
-- during a construction it shows the site's progress and a clock + time left instead. Tapping / clicking
-- (or F / gamepad Y, shown as a light keycap) opens the build tablet when you stand at the station,
-- else puts the guide arrow and the minimap pin on the station for a few seconds.
-- The tutorial's chip row (OnboardingController) owns this slot until the tutorial is done.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Net = require(Shared:WaitForChild("Net"))
local NextGoal = require(Shared:WaitForChild("NextGoal"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local UiImages = require(Shared:WaitForChild("Config"):WaitForChild("UiImages"))

local UI = script.Parent
local BuildGlyph = require(UI:WaitForChild("BuildGlyph"))
local Glyph = require(UI:WaitForChild("Glyph"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))
local Layout = require(UI:WaitForChild("Layout"))
local OnboardingBeacon = require(UI:WaitForChild("OnboardingBeacon"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Theme = require(UI:WaitForChild("Kit"):WaitForChild("Theme"))

local player = Players.LocalPlayer

local NextChip = {}

local root: ImageButton? = nil
local iconArt: Frame? = nil
local nameLabel: TextLabel? = nil
local amountLabel: TextLabel? = nil
local coinIcon: Frame? = nil
local clockIcon: Frame? = nil
local pill: Frame? = nil
local amountScale: UIScale? = nil
local fill: Frame? = nil
local ready = false
local shownKey: string? = nil

local snapshot: { [string]: any }? = nil
local beacon: OnboardingBeacon.Beacon? = nil
local pointingUntil = 0
local doneAt: number? = nil
local pointingAt: Vector3? = nil
local lastSite: NextGoal.Site? = nil
local lastSiteAt = 0

local POINT_SECONDS = 10 -- s the arrow/pin stay after a tap
local NEAR_STATION = 18 -- studs: close enough to open the tablet from the chip

-- du inside the "chips" region (48 high): the tile hangs over the card's left edge, the amount and
-- the keycap sit right, the name over the bar fills the rest.
local TILE = 52
local CARD_X = 20
local TEXT_X = 42 -- on the card face
local AMOUNT_MIN = 76 -- the amount box grows with its number, the bar runs up to it
local KEY = 30
local GAP = 8
local BRICK = Color3.fromHex("FFC928")
local amountW = AMOUNT_MIN
local relayout: (() -> ())? = nil

local function applyData(data: any)
	if type(data) == "table" then
		snapshot = data
	end
end

local function siteState(): NextGoal.Site?
	local i = player:GetAttribute("DockPlot")
	local marina = Workspace:FindFirstChild("Marina")
	local plot = if type(i) == "number" and marina then marina:FindFirstChild(`Plot{i}`) else nil
	local key = plot and plot:GetAttribute("SiteKey")
	if type(key) ~= "string" then
		return nil
	end
	return {
		key = key,
		level = tonumber(plot:GetAttribute("SiteLevel")),
		progress = math.clamp(tonumber(plot:GetAttribute("SiteProgress")) or 0, 0, 1),
		rate = tonumber(plot:GetAttribute("SiteRate")) or 1,
	}
end

-- The station (the tablet) in the world: the same spot DockController opens by the berth frame.
local function stationPoint(): Vector3?
	local bay = player:GetAttribute("BayCFrame")
	if typeof(bay) ~= "CFrame" then
		return nil
	end
	return DockConfig.stationSpot(bay).Position + Vector3.new(0, 1.1, 0) -- the pad top (DockPieces.buildStation: 0.8 base + studs)
end

local function beat(): Onboarding.Beat
	local s = snapshot
	if not s then
		return "ColdOpen"
	end
	local site = siteState()
	return Onboarding.beat({
		coldOpenDone = s.coldOpenDone == true,
		totalRescues = tonumber(s.totalRescues) or 0,
		step = tonumber(s.tutorialStep),
		owned = if type(s.dockBuildings) == "table" then s.dockBuildings else {},
		constructionKey = if site then site.key else nil,
	})
end

local function clearPointing()
	pointingUntil, pointingAt = 0, nil
	if beacon then
		beacon.hide()
	end
	local map =
		require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("MapController"))
	map.SetBlips("NextGoal", nil)
end

local function pointAt(pos: Vector3)
	local b = beacon or OnboardingBeacon.start()
	beacon = b
	b.show(pos, "Place")
	pointingAt, pointingUntil = pos, os.clock() + POINT_SECONDS
	local map =
		require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("MapController"))
	map.SetBlips("NextGoal", {
		{ id = "Build", position = pos, style = "Waypoint", size = 22 },
	})
end

local function nearby(pos: Vector3): boolean
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and rootPart and rootPart:IsA("BasePart")) or hum.SeatPart then
		return false
	end
	local d = rootPart.Position - pos
	return Vector3.new(d.X, 0, d.Z).Magnitude <= NEAR_STATION
end

-- The chip's one action: open the tablet at the station, else lead there.
-- On foot anywhere: the build tablet opens on the shown goal's card (owner 2026-10-28: the station pointer alone read as
-- "does nothing"). At the helm it points at the station instead: build mode would freeze you at sea.
local function activate()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and not hum.SeatPart then
		local dock =
			require(script.Parent.Parent:WaitForChild("Controllers"):WaitForChild("DockController"))
		if dock.OpenBuild(shownKey) then
			clearPointing()
			return
		end
	end
	local station = stationPoint()
	if station then
		pointAt(station)
	end
end

-- At the price the amount sits on a green pill: one pop as it lands, then it rests.
local function setReady(on: boolean)
	local sc, p = amountScale, pill
	if not (sc and p) or ready == on then
		return
	end
	ready = on
	p.Visible = on
	if on then
		sc.Scale = 1.3
		Style.tween(sc, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

local function refresh()
	local r = root
	local s = snapshot
	local done = s ~= nil and beat() == "Done"
	if not done then
		doneAt = nil
	end
	if done and s and doneAt == nil then
		doneAt = os.clock() + Onboarding.DONE_HOLD + 0.5 -- the tutorial's ticked Spin chip keeps the slot first
	end
	if not (r and s and done and doneAt and os.clock() >= doneAt) then
		if r then
			r.Visible = false
		end
		setReady(false)
		return
	end
	local levels = if type(s.dock) == "table" and type(s.dock.levels) == "table"
		then s.dock.levels
		else {}
	-- a running site owns the chip: a frame without SiteKey (playtest 2026-10-26, not reproduced) must not flip
	-- it to the next buy. shortcut: a 3 s hold, until the server's site state is found to drop out
	local site = siteState()
	if site then
		lastSite, lastSiteAt = site, os.clock()
	elseif
		lastSite
		and os.clock() - lastSiteAt < 3
		and (tonumber(levels[lastSite.key]) or 0) < (lastSite.level or 1)
	then
		site = lastSite
	end
	local g = NextGoal.next({
		cash = tonumber(s.cash) or 0,
		levels = levels,
		construction = site,
	})
	if not g then
		r.Visible = false
		setReady(false)
		clearPointing()
		return
	end
	r.Visible = true
	if g.key ~= shownKey then
		shownKey = g.key
		local art = iconArt :: Frame
		art:ClearAllChildren()
		if DockConfig.Buildings[g.key] then
			BuildGlyph(art, { kind = "Building", key = g.key })
		else
			BuildGlyph(art, { kind = "Decor", key = g.key })
		end
		-- yellow Lego bricks, so the drawing reads on its white tile
		for _, b in art:GetChildren() do
			if b:IsA("Frame") and b.BackgroundColor3 == Color3.new(1, 1, 1) then
				b.BackgroundColor3 = BRICK
			end
		end
	end
	local name = nameLabel :: TextLabel
	name.Text = if g.level > 1 then `{g.name} Lv{g.level}` else g.name
	local f, num = fill :: Frame, amountLabel :: TextLabel
	local timer = g.kind == "Site"
	f.Size = UDim2.fromScale(g.progress, 1)
	f.Visible = g.progress > 0.02
	local clock, coin = clockIcon :: Frame, coinIcon :: Frame
	-- green only means go (the full bar next to the green price pill); a running site fills white
	Style.gradient(
		f,
		Style.grad(if timer then "body" elseif g.progress >= 1 then "green" else "yellow")
	)
	clock.Visible = timer
	coin.Visible = not timer
	num.Text = if timer then BuildTimer.text(g.timeLeft or 0) else Theme.short(g.price)
	local tw = TextService:GetTextSize(
		num.Text,
		num.TextSize,
		Enum.Font.FredokaOne,
		Vector2.new(1e4, 1e4)
	).X
	local w = math.max(AMOUNT_MIN, math.ceil(28 + 4 + tw + 24))
	if w ~= amountW and relayout then
		amountW = w
		relayout()
	end
	setReady(g.kind == "Build" and g.progress >= 1)
end

local function tick()
	-- hide under panels, cinematics and the cold open; the chip is part of the gameplay HUD
	local r = root
	if not r then
		return
	end
	local hidden = Layout.coldOpen()
		or player:GetAttribute("MenuOpen") == true
		or player:GetAttribute("MapOpen") == true
		or player:GetAttribute("CinematicPlaying") == true
		or player:GetAttribute("DebriefShown") == true
		or player:GetAttribute("BuildHidesMenu") == true -- the build list half-covered it (rc7); the tablet is open anyway
	if hidden then
		r.Visible = false
	else
		refresh()
	end
	if pointingAt then
		local station = stationPoint()
		if
			os.clock() > pointingUntil
			or (station and nearby(station))
			or player:GetAttribute("MenuOpen") == true
		then
			clearPointing()
		end
	end
end

function NextChip.mount(region: Frame)
	if root then
		return
	end
	local r = Style.button(region, UDim2.fromScale(1, 1))
	r.Name = "NextChip"
	r.Visible = false
	root = r

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundTransparency = 1
	card.Position = UDim2.fromOffset(CARD_X, 0)
	card.Size = UDim2.new(1, -CARD_X, 1, 0)
	card.Parent = r
	-- a soft drop shadow and a deeper blue than the kit's, so the card holds against a blue sky
	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = Theme.Colors.shadow
	shadow.BackgroundTransparency = 0.65
	shadow.Position = UDim2.fromOffset(0, 4)
	shadow.Size = UDim2.fromScale(1, 1)
	shadow.Parent = card
	Style.corner(shadow, 13)
	local _, face = Style.block(
		card,
		{ top = Color3.fromHex("7FDCFF"), bottom = Color3.fromHex("1B6FDB") },
		{ radius = 12, lip = 6, border = 3.5 }
	)

	-- the building's Lego icon on a white tile, tilted a touch like a sticker
	local tile = Instance.new("Frame")
	tile.Name = "Tile"
	tile.BackgroundTransparency = 1
	tile.Position = UDim2.fromOffset(0, -3)
	tile.Size = UDim2.fromOffset(TILE, TILE)
	tile.Rotation = -6
	tile.ZIndex = 2
	tile.Parent = r
	local _, tileFace = Style.block(
		tile,
		{ top = Color3.new(1, 1, 1), bottom = Color3.fromHex("D6E4F2") },
		{ radius = 12, lip = 4, border = 3 }
	)
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(0.76, 0.76)
	art.Parent = tileFace
	iconArt = art

	local name = Style.label(face, "", 23)
	name.Name = "Name"
	name.Position = UDim2.fromOffset(TEXT_X, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextWrapped = false
	name.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel = name

	-- the Cash bar: a deep blue trough with an ink outline, a bright fill with a gloss strip
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromHex("1D539C")
	bar.Position = UDim2.fromOffset(TEXT_X, 25)
	bar.Parent = face
	Style.corner(bar, 6)
	Style.stroke(bar, 2.5, true)
	local f = Instance.new("Frame")
	f.Name = "Fill"
	f.BackgroundColor3 = Color3.new(1, 1, 1)
	f.Size = UDim2.fromScale(0, 1)
	f.Parent = bar
	Style.corner(f, 6)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Color3.new(1, 1, 1)
	gloss.BackgroundTransparency = 0.45
	gloss.Position = UDim2.fromOffset(3, 2)
	gloss.Size = UDim2.new(1, -6, 0.3, 0)
	gloss.Parent = f
	Style.corner(gloss, 3)
	fill = f

	-- coin + price (or clock + time left); at the price a green pill pops in behind them
	local amount = Instance.new("Frame")
	amount.Name = "Amount"
	amount.BackgroundTransparency = 1
	amount.AnchorPoint = Vector2.new(1, 0)
	amount.Parent = face
	local sc = Instance.new("UIScale")
	sc.Parent = amount
	amountScale = sc
	local p =
		Style.block(amount, Style.grad("buy"), { radius = 12, lip = 6, border = 3, studs = true })
	p.Visible = false
	pill = p
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 1, -6)
	row.ZIndex = 2
	row.Parent = amount
	local list = Style.list(row, true, 4)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	local coin = Instance.new("Frame")
	coin.Name = "Coin"
	coin.BackgroundTransparency = 1
	coin.Size = UDim2.fromOffset(28, 28)
	coin.LayoutOrder = 1
	coin.Parent = row
	local coinArt = Instance.new("ImageLabel") -- the wallet's gold coin, so the price reads as Cash
	coinArt.BackgroundTransparency = 1
	coinArt.Image = UiImages.Hud.Coin
	coinArt.ScaleType = Enum.ScaleType.Fit
	coinArt.Size = UDim2.fromScale(1, 1)
	coinArt.Parent = coin
	coinIcon = coin
	local clock = Instance.new("Frame")
	clock.Name = "Clock"
	clock.BackgroundTransparency = 1
	clock.Size = UDim2.fromOffset(24, 24)
	clock.LayoutOrder = 1
	clock.Visible = false
	clock.Parent = row
	-- an ink copy nudged down under the white clock reads as the outlined font
	for i, off in { Vector2.new(1, 2), Vector2.zero } do
		local layer = Instance.new("Frame")
		layer.BackgroundTransparency = 1
		layer.Position = UDim2.fromOffset(off.X, off.Y)
		layer.Size = UDim2.fromScale(1, 1)
		layer.Parent = clock
		Glyph.draw("clock", layer, if i == 1 then Theme.Colors.ink else Color3.new(1, 1, 1))
	end
	clockIcon = clock
	local num = Style.label(row, "", 26)
	num.Name = "Num"
	num.AutomaticSize = Enum.AutomaticSize.X
	num.Size = UDim2.fromScale(0, 1)
	num.TextWrapped = false
	num.LayoutOrder = 2
	amountLabel = num

	-- the key hint: a light keycap on keyboard, the platform's Y button on a gamepad, none on touch
	local key = Instance.new("Frame")
	key.Name = "Key"
	key.BackgroundTransparency = 1
	key.AnchorPoint = Vector2.new(1, 0)
	key.Position = UDim2.new(1, -GAP, 0, 6)
	key.Size = UDim2.fromOffset(KEY, KEY)
	key.Parent = face
	local cap, capFace = Style.block(key, Style.grad("body"), { radius = 8, lip = 4, border = 2.5 })
	local keyText = Style.label(capFace, "F", 18, true)
	local padImage = Instance.new("ImageLabel")
	padImage.Name = "Pad"
	padImage.BackgroundTransparency = 1
	padImage.Size = UDim2.fromScale(1, 1)
	padImage.Parent = key
	local function placeKey()
		local d = InputGlyph.device()
		local touch = d == "Touch" or Layout.current().touch
		local image = if d == "Gamepad"
			then UserInputService:GetImageForKeyCode(Enum.KeyCode.ButtonY)
			else ""
		padImage.Image = image
		cap.Visible = image == ""
		keyText.Text = InputGlyph.text(Enum.KeyCode.F, Enum.KeyCode.ButtonY)
		key.Visible = not touch
		local right = GAP + if touch then 0 else KEY + 6
		amount.Position = UDim2.new(1, -right, 0, 3)
		amount.Size = UDim2.fromOffset(amountW, 36)
		local w = -(TEXT_X + amountW + right + 2)
		name.Size = UDim2.new(1, w, 0, 24)
		bar.Size = UDim2.new(1, w, 0, 15)
	end
	relayout = placeKey
	InputGlyph.onDevice(placeKey)
	Layout.onMetrics(placeKey)

	Style.press(r, activate, 12)
	Net.event("PlayerDataChanged").OnClientEvent:Connect(applyData)
	task.spawn(function()
		local getData = Net.init():WaitForChild("Progression_GetData", 30) :: RemoteFunction?
		local ok, data = pcall(function()
			return getData and getData:InvokeServer()
		end)
		if ok then
			applyData(data)
		end
	end)
	task.spawn(function()
		while true do
			tick()
			task.wait(0.25)
		end
	end)
	ContextActionService:BindActionAtPriority("NextGoal_Key", function(_, state, _input)
		if state ~= Enum.UserInputState.Begin or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if not root or not root.Visible then
			return Enum.ContextActionResult.Pass
		end
		activate()
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.Medium.Value - 1, Enum.KeyCode.F, Enum.KeyCode.ButtonY)
end

return NextChip
