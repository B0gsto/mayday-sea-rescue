--!strict
-- Spin panel (docs/24 D): the full-screen prize wheel. Free spins, Robux spins, the odds card
-- (Roblox requires odds for paid random items) and the reveal card. Every roll is the server's
-- (Spin_Spin); this only animates the returned segment.
--
-- The wheel is a masked disc of thin radial wedges, coloured by rarity (Mythic is a rainbow fan).
-- It eases out with a small overshoot, ticks on each segment, then pops the prize card (rays for
-- Epic+). Legendary / Mythic wins also arrive as a Spin_Flex banner + confetti on every client.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local SpinRules = require(Shared:WaitForChild("SpinRules"))

local Client = script.Parent.Parent.Parent
local AudioController = require(Client:WaitForChild("Controllers"):WaitForChild("AudioController"))

local Kit = script.Parent.Parent:WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local Toast = require(Kit:WaitForChild("Toast"))

local player = Players.LocalPlayer
local S = Theme.Size
local SEG_DEG = 360 / #SpinRules.SEGMENTS
local WEDGES_PER_SEGMENT = 6
local GOLD = Color3.fromHex("FFD84A")
local SPIN_KEYS = { "Spin1", "Spin5", "Spin15" }
local SPIN_LABELS = { Spin1 = "1 spin", Spin5 = "5 spins", Spin15 = "15 spins" }

local Spin = {}

local function rarityColor(rarity: string): Color3
	local row = SpinRules.RARITIES[rarity]
	if not row then
		return Color3.fromRGB(160, 168, 180)
	end
	return Theme.Grad[row.color].top
end

local function wheelColor(rarity: string, wedge: number): Color3
	if rarity == "Mythic" then
		return Color3.fromHSV((wedge * 0.11) % 1, 0.7, 1)
	end
	local c = rarityColor(rarity)
	return if wedge % 2 == 0 then c else c:Lerp(Color3.new(1, 1, 1), 0.12)
end

local function confetti(userId: number, rarity: string)
	local winner = Players:GetPlayerByUserId(userId)
	local character = winner and winner.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "SpinConfetti"
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Anchored = true
	anchor.CFrame = root.CFrame * CFrame.new(0, 7, 0)
	anchor.Parent = Workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(1.2, 2.2)
	emitter.Speed = NumberRange.new(14, 26)
	emitter.SpreadAngle = Vector2.new(75, 75)
	emitter.Acceleration = Vector3.new(0, -40, 0)
	emitter.Size = NumberSequence.new(0.5)
	emitter.LightEmission = 0.45
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	local base = rarityColor(rarity)
	emitter.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, base),
		ColorSequenceKeypoint.new(0.33, Color3.fromHSV((os.clock() * 0.2) % 1, 0.8, 1)),
		ColorSequenceKeypoint.new(0.66, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, base:Lerp(Color3.new(1, 1, 1), 0.5)),
	})
	emitter.Parent = anchor
	emitter:Emit(80)
	task.delay(3, function()
		anchor:Destroy()
	end)
end

function Spin.new(canvas: Frame, onClose: () -> ())
	local root = Instance.new("Frame")
	root.Name = "Panel_Spin"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = 6
	root.Parent = canvas

	local dim = Instance.new("Frame")
	dim.Name = "SpinDim"
	dim.BackgroundColor3 = Theme.Colors.shadow
	dim.BackgroundTransparency = 0.4
	dim.Size = UDim2.fromScale(1, 1)
	dim.Visible = false
	dim.ZIndex = 5
	dim.Parent = canvas

	-- the wheel ---------------------------------------------------------------------------------
	local holder = Instance.new("Frame")
	holder.Name = "WheelHolder"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.ZIndex = 6
	holder.Parent = root

	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.BackgroundColor3 = Theme.Colors.ink
	wheel.ClipsDescendants = true
	wheel.Size = UDim2.fromScale(1, 1)
	wheel.ZIndex = 6
	Style.corner(wheel, 999)
	Style.stroke(wheel, 8, true)
	wheel.Parent = holder

	local rotor = Instance.new("Frame")
	rotor.Name = "Rotor"
	rotor.BackgroundTransparency = 1
	rotor.Size = UDim2.fromScale(1, 1)
	rotor.AnchorPoint = Vector2.new(0.5, 0.5)
	rotor.Position = UDim2.fromScale(0.5, 0.5)
	rotor.ZIndex = 6
	rotor.Parent = wheel
	local rotorSpins: { Frame } = {}

	local hub = Instance.new("Frame")
	hub.Name = "Hub"
	hub.AnchorPoint = Vector2.new(0.5, 0.5)
	hub.Position = UDim2.fromScale(0.5, 0.5)
	hub.Size = UDim2.fromScale(0.22, 0.22)
	hub.ZIndex = 8
	hub.Parent = wheel
	local _, hubFace = Style.block(hub, Style.grad("ink"), { lip = 4, radius = 999 })
	local hubLabel = Style.label(hubFace, "SPIN", Theme.Text.small)
	hubLabel.TextScaled = true

	local pointer = Style.label(holder, "▼", 58)
	pointer.Name = "Pointer"
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.fromScale(0.5, 0)
	pointer.Size = UDim2.fromOffset(74, 74)
	pointer.TextColor3 = GOLD
	pointer.ZIndex = 9
	Style.stroke(pointer, 3)

	-- the controls ------------------------------------------------------------------------------
	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundTransparency = 1
	controls.AnchorPoint = Vector2.new(0.5, 0.5)
	controls.ZIndex = 6
	controls.Parent = root
	local list = Style.list(controls, false, 10)
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local title = Style.label(controls, "Prize wheel", Theme.Text.heading)
	title.Size = UDim2.fromScale(1, 0)
	title.AutomaticSize = Enum.AutomaticSize.Y
	title.LayoutOrder = 1

	local spinButton = Style.button(controls, UDim2.fromOffset(260, 84))
	spinButton.Name = "SpinButton"
	spinButton.LayoutOrder = 2
	local _, spinFace = Style.block(spinButton, Style.grad("buy"), { lip = 7, radius = S.corner })
	local spinLabel = Style.label(spinFace, "SPIN", Theme.Text.title)
	spinLabel.TextScaled = true
	local freeLabel = Style.label(spinFace, "", Theme.Text.small)
	freeLabel.AnchorPoint = Vector2.new(0, 1)
	freeLabel.Position = UDim2.new(0, 10, 1, -4)
	freeLabel.Size = UDim2.new(1, -20, 0, 18)
	freeLabel.TextXAlignment = Enum.TextXAlignment.Left

	local robuxRow = Instance.new("Frame")
	robuxRow.Name = "RobuxSpins"
	robuxRow.BackgroundTransparency = 1
	robuxRow.Size = UDim2.new(1, 0, 0, 92)
	robuxRow.LayoutOrder = 3
	robuxRow.Parent = controls
	local rowList = Style.list(robuxRow, true, 8)
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center

	local productButtons: { any } = {}
	local prices: { [number]: number | false } = {}
	local offered: { [string]: boolean } = {}
	local function paintProducts()
		for _, row in productButtons do
			local item = row.item
			local live = item.ready ~= false and item.id ~= 0
			-- a live paid spin shows only once the server's catalogue offers it (paid-random policy)
			row.cell.Visible = not live or offered[row.key] == true
			if not live then
				row.button.setState("disabled")
				row.button.setText("Soon")
				continue
			end
			if offered[row.key] ~= true then
				continue
			end
			local price = prices[item.id]
			if type(price) == "number" then
				row.button.setPrice(price)
				row.button.setState("buy")
			else
				row.button.setState("disabled")
				row.button.setText("…")
			end
		end
	end

	local function fetchPrice(item: any)
		if item.ready == false or item.id == 0 or prices[item.id] ~= nil then
			return
		end
		prices[item.id] = false
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.Product)
			end)
			local price = ok and info and tonumber(info.PriceInRobux)
			prices[item.id] = if price then price else false
			task.defer(paintProducts)
		end)
	end

	for _, key in SPIN_KEYS do
		local item = MonetizationConfig.Products[key]
		if item then
			local cell = Instance.new("Frame")
			cell.BackgroundTransparency = 1
			cell.Size = UDim2.fromOffset(92, 88)
			cell.Parent = robuxRow
			local caption = Style.label(cell, SPIN_LABELS[key] or key, Theme.Text.small, true)
			caption.Position = UDim2.fromOffset(0, 0)
			caption.Size = UDim2.new(1, 0, 0, 20)
			local button = require(Kit:WaitForChild("PriceButton")).new(cell, {
				price = item.price,
				onActivate = function()
					if item.ready == false or item.id == 0 or offered[key] ~= true then
						return
					end
					MarketplaceService:PromptProductPurchase(player, item.id)
				end,
			})
			button.root.AnchorPoint = Vector2.new(0.5, 0)
			button.root.Position = UDim2.new(0.5, 0, 0, 24)
			button.root.Size = UDim2.fromOffset(92, 62)
			table.insert(productButtons, { item = item, button = button, cell = cell, key = key })
			fetchPrice(item)
		end
	end

	local odds: ImageButton
	local oddsButton = Style.button(controls, UDim2.fromOffset(180, 54))
	oddsButton.Name = "OddsButton"
	oddsButton.LayoutOrder = 4
	local _, oddsFace =
		Style.block(oddsButton, Style.grad("blue"), { lip = 5, radius = S.cornerSmall })
	Style.label(oddsFace, "Odds", Theme.Text.button)
	Style.press(oddsButton, function()
		odds.Visible = not odds.Visible
	end, S.cornerSmall)

	local closeButton = Style.button(root, UDim2.fromOffset(S.close, S.close + S.lip))
	closeButton.Name = "Close"
	closeButton.AnchorPoint = Vector2.new(1, 0)
	closeButton.Position = UDim2.new(1, -14, 0, 14)
	closeButton.ZIndex = 10
	local _, closeFace = Style.block(closeButton, Style.grad("close"), { radius = S.cornerSmall })
	Style.label(closeFace, "X", Theme.Text.title)

	-- the odds card (paid random items must show them) ------------------------------------------
	odds = Style.button(root, UDim2.fromOffset(430, 360))
	odds.Name = "OddsCard"
	odds.AnchorPoint = Vector2.new(0.5, 0.5)
	odds.Position = UDim2.fromScale(0.5, 0.5)
	odds.BackgroundTransparency = 1
	odds.Visible = false
	odds.ZIndex = 12
	local oddsHolder, oddsBody =
		Style.block(odds, Style.grad("body"), { shadow = true, lip = 6, radius = S.corner })
	oddsHolder.ZIndex = 1
	oddsBody.ZIndex = 1
	local oddsFrame = Instance.new("Frame")
	oddsFrame.BackgroundTransparency = 1
	oddsFrame.Size = UDim2.fromScale(1, 1)
	oddsFrame.Parent = oddsBody
	local oddsList = Style.list(oddsFrame, false, 6)
	oddsList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local oddsTitle = Style.label(oddsFrame, "Odds", Theme.Text.heading, true)
	oddsTitle.ZIndex = 2
	oddsTitle.Size = UDim2.new(1, 0, 0, 44)
	for i, rarity in SpinRules.RARITY_ORDER do
		local row = Style.label(
			oddsFrame,
			`{rarity}  {SpinRules.RARITIES[rarity].odds}%`,
			Theme.Text.body,
			true
		)
		row.Size = UDim2.new(0.8, 0, 0, 30)
		row.LayoutOrder = i
		row.ZIndex = 2
	end
	local pity = Style.label(
		oddsFrame,
		`Epic+ every {SpinRules.PITY_EPIC}, Legendary+ every {SpinRules.PITY_LEGENDARY}`,
		Theme.Text.small,
		true
	)
	pity.Size = UDim2.new(0.9, 0, 0, 24)
	pity.LayoutOrder = 99
	pity.ZIndex = 2
	Style.press(odds, function()
		odds.Visible = false
	end, S.cornerSmall)

	-- the reveal card ---------------------------------------------------------------------------
	local reveal = Style.button(root, UDim2.fromOffset(430, 330))
	reveal.Name = "Reveal"
	reveal.AnchorPoint = Vector2.new(0.5, 0.5)
	reveal.Position = UDim2.fromScale(0.5, 0.5)
	reveal.BackgroundTransparency = 1
	reveal.Visible = false
	reveal.ZIndex = 14

	local rays = Instance.new("Frame")
	rays.Name = "Rays"
	rays.AnchorPoint = Vector2.new(0.5, 0.5)
	rays.Position = UDim2.fromScale(0.5, 0.5)
	rays.Size = UDim2.fromOffset(640, 640)
	rays.BackgroundTransparency = 1
	rays.Visible = false
	rays.ZIndex = 1
	rays.Parent = reveal
	for i = 1, 20 do
		local ray = Instance.new("Frame")
		ray.BackgroundColor3 = GOLD
		ray.BackgroundTransparency = 0.45
		ray.BorderSizePixel = 0
		ray.AnchorPoint = Vector2.new(0.5, 1)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromOffset(18, 320)
		ray.Rotation = (i - 1) * 18
		ray.ZIndex = 1
		ray.Parent = rays
	end
	local raySpin: Tween? = nil

	local cardHolder, cardFace =
		Style.block(reveal, Style.grad("body"), { shadow = true, lip = 8, radius = S.corner })
	cardHolder.ZIndex = 2
	cardFace.ZIndex = 2
	local cardText = Style.label(cardFace, "", Theme.Text.title, true)
	cardText.ZIndex = 3
	cardText.Position = UDim2.fromOffset(26, 18)
	cardText.Size = UDim2.new(1, -52, 0, 44)
	cardText.TextWrapped = false
	cardText.TextTruncate = Enum.TextTruncate.AtEnd
	cardText.ZIndex = 3
	local cardIcon = Instance.new("Frame")
	cardIcon.Name = "PrizeIcon"
	cardIcon.AnchorPoint = Vector2.new(0.5, 0.5)
	cardIcon.Position = UDim2.fromScale(0.5, 0.45)
	cardIcon.Size = UDim2.fromOffset(150, 150)
	cardIcon.BackgroundTransparency = 1
	cardIcon.ZIndex = 3
	cardIcon.Parent = reveal
	local cardRarity = Style.label(cardFace, "", Theme.Text.heading, true)
	cardRarity.ZIndex = 3
	cardRarity.Position = UDim2.new(0, 26, 1, -70)
	cardRarity.Size = UDim2.new(1, -52, 0, 34)
	local cardCash = Style.label(cardFace, "", Theme.Text.body, true)
	cardCash.ZIndex = 3
	cardCash.Position = UDim2.new(0, 26, 1, -36)
	cardCash.Size = UDim2.new(1, -52, 0, 26)
	Style.press(reveal, function()
		reveal.Visible = false
		rays.Visible = false
		if raySpin then
			raySpin:Cancel()
			raySpin = nil
		end
	end, S.corner)

	-- spin --------------------------------------------------------------------------------------
	local busy = false
	local wheelRotation = 0
	local lastSegment = 0
	local function rotSeg(rotation: number): number
		local a = ((rotation % 360) + 360) % 360
		return math.floor(a / SEG_DEG) + 1
	end

	local function showReveal(result: any)
		for _, c in cardIcon:GetChildren() do
			c:Destroy()
		end
		Style.icon(cardIcon, result.icon or "gift")
		cardText.Text = result.name or "Prize"
		cardRarity.Text = string.upper(result.rarity or "")
		cardRarity.TextColor3 = rarityColor(result.rarity)
		cardCash.Text = if result.duplicateCash
			then `Already owned  +{result.duplicateCash} Cash`
			else ""
		local epic = SpinRules.rank(result.rarity) >= SpinRules.rank("Epic")
		rays.Visible = epic
		reveal.Visible = true
		Style.pop(reveal, true)
		cardIcon.Size = UDim2.fromOffset(if epic then 170 else 150, if epic then 170 else 150)
		if epic then
			if raySpin then
				raySpin:Cancel()
			end
			local spinRays = TweenService:Create(
				rays,
				TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
				{ Rotation = 360 }
			)
			raySpin = spinRays
			spinRays:Play()
		end
		if SpinRules.rank(result.rarity) >= SpinRules.rank("Epic") then
			AudioController.play("UI_Success", nil, 0.8, 1)
		else
			AudioController.play("UI_Pickup", nil, 0.7, 1)
		end
	end

	local function animate(segment: number, done: () -> ())
		local centre = (segment - 0.5) * SEG_DEG
		local want = (360 - centre) % 360
		local now = ((wheelRotation % 360) + 360) % 360
		local delta = (want - now) % 360
		local target = wheelRotation + 360 * 3 + delta + 4
		local value = Instance.new("NumberValue")
		value.Value = wheelRotation
		lastSegment = rotSeg(wheelRotation)
		local conn = value:GetPropertyChangedSignal("Value"):Connect(function()
			rotor.Rotation = value.Value
			local seg = rotSeg(value.Value)
			if seg ~= lastSegment then
				lastSegment = seg
				AudioController.play("UI_Prompt", nil, 0.55, 0.9 + (seg % 6) * 0.06)
			end
		end)
		local tween = TweenService:Create(
			value,
			TweenInfo.new(3.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
			{ Value = target }
		)
		tween:Play()
		tween.Completed:Wait()
		local settle = TweenService:Create(
			value,
			TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{ Value = target - 4 }
		)
		settle:Play()
		settle.Completed:Wait()
		wheelRotation = target - 4
		conn:Disconnect()
		value:Destroy()
		done()
	end

	local function refresh()
		local free = player:GetAttribute("FreeSpins")
		local n = if type(free) == "number" then free else 0
		freeLabel.Text = if n > 0 then `{n} free` else "no free spins"
		spinButton.Active = n > 0 and not busy
		spinLabel.Text = if busy then "…" else "SPIN"
		spinLabel.TextTransparency = if n > 0 or busy then 0 else 0.45
		local epic = tonumber(player:GetAttribute("SpinPityEpic")) or 0
		local legend = tonumber(player:GetAttribute("SpinPityLegendary")) or 0
		pity.Text =
			`Epic+ every {SpinRules.PITY_EPIC} ({SpinRules.PITY_EPIC - epic})  ·  Legendary+ every {SpinRules.PITY_LEGENDARY} ({SpinRules.PITY_LEGENDARY - legend})`
	end

	local function spin()
		if busy then
			return
		end
		local free = player:GetAttribute("FreeSpins")
		if type(free) ~= "number" or free < 1 then
			Toast.show(canvas, "No free spins", { icon = "spin", color = "orange" })
			return
		end
		busy = true
		refresh()
		local ok, result = pcall(function()
			return Net.func("Spin_Spin"):InvokeServer()
		end)
		if not (ok and type(result) == "table" and result.ok) then
			busy = false
			refresh()
			Toast.show(canvas, "Try again", { icon = "spin", color = "red" })
			return
		end
		animate(result.segment or 1, function()
			busy = false
			refresh()
			showReveal(result)
		end)
	end
	Style.press(spinButton, spin, S.corner)
	Style.press(closeButton, function()
		reveal.Visible = false
		rays.Visible = false
		if raySpin then
			raySpin:Cancel()
			raySpin = nil
		end
		onClose()
		root.Visible = false
		dim.Visible = false
	end, S.cornerSmall)

	-- layout ------------------------------------------------------------------------------------
	local function rebuildWheel(size: number)
		for _, spoke in rotorSpins do
			spoke:Destroy()
		end
		table.clear(rotorSpins)
		for i, rarity in SpinRules.SEGMENTS do
			for j = 1, WEDGES_PER_SEGMENT do
				local spoke = Instance.new("Frame")
				spoke.Name = `Segment{i}`
				spoke.BackgroundColor3 = wheelColor(rarity, j)
				spoke.BorderSizePixel = 0
				spoke.AnchorPoint = Vector2.new(0.5, 1)
				spoke.Position = UDim2.fromScale(0.5, 0.5)
				spoke.Size = UDim2.fromOffset(size * 0.11, size * 0.5 - 5)
				spoke.Rotation = (i - 1) * SEG_DEG + (j - 0.5) * SEG_DEG / WEDGES_PER_SEGMENT
				spoke.ZIndex = 6
				spoke.Parent = rotor
				table.insert(rotorSpins, spoke)
			end
		end
	end

	local fitted = 0
	local function layout()
		local vp = Style.metrics(root)
		local narrow = vp.X < 900
		local size = if narrow
			then math.floor(math.min(vp.X * 0.82, vp.Y * 0.5))
			else math.floor(math.min(vp.Y * 0.78, 640))
		size = math.max(size, 220)
		if size ~= fitted then
			fitted = size
			holder.Size = UDim2.fromOffset(size, size)
			rebuildWheel(size)
			rotor.Rotation = wheelRotation
		end
		if narrow then
			holder.Position = UDim2.fromScale(0.5, 0.3)
			controls.Size = UDim2.new(vp.X - 40, 0, 0, 300)
			controls.Position = UDim2.fromScale(0.5, 0.76)
		else
			holder.Position = UDim2.fromScale(0.33, 0.5)
			controls.Size = UDim2.fromOffset(360, 400)
			controls.Position = UDim2.fromScale(0.73, 0.5)
		end
		odds.Position = UDim2.fromScale(0.5, 0.5)
	end
	layout()
	canvas:GetAttributeChangedSignal("KitViewport"):Connect(layout)

	-- flex: banner + confetti on every client (Legendary / Mythic) ------------------------------
	Net.event("Spin_Flex").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.name) ~= "string" then
			return
		end
		Toast.show(canvas, `{payload.name} won a {string.upper(payload.rarity)} {payload.prize}!`, {
			icon = payload.icon,
			color = if SpinRules.RARITIES[payload.rarity]
				then SpinRules.RARITIES[payload.rarity].color
				else "yellow",
			duration = 6,
		})
		confetti(payload.userId, payload.rarity)
	end)

	-- the catalogue (and the paid-random policy gate) decides which Robux spins may show
	local function fetchCatalogue()
		local net = ReplicatedStorage:FindFirstChild("Net")
		local remote = net and net:FindFirstChild("Monetization_GetCatalogue")
		if not (remote and remote:IsA("RemoteFunction")) then
			paintProducts()
			return
		end
		task.spawn(function()
			local ok, entries = pcall(function()
				return (remote :: RemoteFunction):InvokeServer()
			end)
			if ok and type(entries) == "table" then
				local set = {}
				for _, entry in entries do
					if
						type(entry) == "table"
						and entry.kind == "Products"
						and type(entry.key) == "string"
					then
						set[entry.key] = true
					end
				end
				offered = set
			end
			paintProducts()
		end)
	end

	player:GetAttributeChangedSignal("FreeSpins"):Connect(refresh)
	player:GetAttributeChangedSignal("SpinPityEpic"):Connect(refresh)
	player:GetAttributeChangedSignal("SpinPityLegendary"):Connect(refresh)
	refresh()
	paintProducts()
	fetchCatalogue()

	return {
		root = root,
		open = function()
			root.Visible = true
			dim.Visible = true
			reveal.Visible = false
			rays.Visible = false
			odds.Visible = false
			layout()
			refresh()
			fetchCatalogue() -- the policy can arrive after the first fetch
			Style.pop(root, true)
		end,
		close = function()
			root.Visible = false
			dim.Visible = false
			reveal.Visible = false
			rays.Visible = false
			if raySpin then
				raySpin:Cancel()
				raySpin = nil
			end
			onClose()
		end,
		isOpen = function(): boolean
			return root.Visible
		end,
	}
end

return Spin
