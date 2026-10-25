--!strict
-- DockController (docs/23 (j) rule 4, WP-14d): the owner's build station by the spawn carries a tablet
-- whose prompt opens the top-down build mode. The camera lifts to a Scriptable island view (shared/DockBuild),
-- movement locks, and a Kit bottom bar lists every level, building, quest blueprint and decor as a card
-- (Build / Decor tabs). Picking a card pans the camera to its lot and pulses a flat outline; the Cash button
-- buys through Dock_Upgrade (locked + rank line until the rank is there, greyed when Cash is short) and the
-- Robux button opens Roblox's purchase prompt. X / B / Escape / a teleport closes and restores the camera and
-- controls. On a buy the pieces already exist in their final state; Dock_Build tells this controller to play
-- the Lego build beat (shared/BuildSeq): each piece drops in, staggered, with a snap and a squash, then dust.
-- Reads player attributes DockPlot, DockLevel, DockHangar / DockSubPen / Decor<key> and the PlayerDataChanged
-- snapshot. Paint booth (docs/23 d.3, WP-13): sitting in a craft inside your own Lv 3+ booth
-- (DockConfig.PAINT_BOOTH) opens the paint card: a swatch strip and the existing cosmetic pickers for Livery
-- and Decal (the same rows as the phone's Settings). Leaving the booth or B / the X button closes it.
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local DockBlueprints = require(Shared:WaitForChild("DockBlueprints"))
local DockBuild = require(Shared:WaitForChild("DockBuild"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local CashBurst = require(UI:WaitForChild("CashBurst"))
local CosmeticPicker = require(UI:WaitForChild("CosmeticPicker"))
local HudTheme = require(UI:WaitForChild("HudTheme"))
local InputGlyph = require(UI:WaitForChild("InputGlyph"))

local Kit = UI:WaitForChild("Kit")
local CardUI = require(Kit:WaitForChild("Card"))
local PriceButtonUI = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local TabsUI = require(Kit:WaitForChild("Tabs"))
local Theme = require(Kit:WaitForChild("Theme"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local S = Theme.Size
local C = HudTheme.Colors
local DockController = {}
local CARD_W = 470
local PRICE_W = 184
local PRICE_H = 54
local OUTLINE = Color3.fromRGB(255, 214, 60)

local snapshot: { [string]: any } = {}
local livePrice: { [number]: number } = {} -- product id -> Robux price, read from Roblox once
local shownCount: number? = nil

local displayed = false
local plotFrame: CFrame? = nil
local stationPos: Vector3? = nil
local returnCf: CFrame? = nil
local tabIndex = 1

local ui: ScreenGui? = nil
local bar: Frame? = nil
local cardsContent: Frame? = nil
local tabs: TabsUI.Tabs? = nil

type Row = {
	card: CardUI.Card,
	select: ImageButton,
	robux: PriceButtonUI.PriceButton?,
}
local rows: { Row } = {}

local modal: InputGlyph.Modal

local camValue: CFrameValue? = nil
local camTween: Tween? = nil
local camRun = 0
local outline: Model? = nil
local humConn: RBXScriptConnection? = nil
type Movement = { walk: number, jump: number, jumpHeight: number }
local savedMovement: Movement? = nil

local function currentLevel(): number
	local level = player:GetAttribute("DockLevel")
	return if type(level) == "number" then level else 1
end

local function entryOf(item: DockBlueprints.Item): any
	if item.kind == "Level" then
		return DockConfig.Levels[item.key :: number]
	elseif item.kind == "Building" then
		return DockConfig.Buildings[item.key :: string]
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key :: string]
	end
	return nil
end

local function ownedOf(item: DockBlueprints.Item): boolean
	if item.kind == "Level" then
		return currentLevel() >= (item.key :: number)
	end
	local prefix = if item.kind == "Decor" then "Decor" else "Dock"
	return player:GetAttribute(prefix .. tostring(item.key)) == true
end

local function aspect(): number
	local camera = Workspace.CurrentCamera
	local vp = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	return math.max(vp.X / math.max(vp.Y, 1), 0.3)
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
			CameraController.SetOverride(made.Value, DockBuild.FOV)
		end)
		camValue = made
		cv = made
	end
	CameraController.SetOverride(cv.Value, DockBuild.FOV)
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
	local parts: { BasePart } = {}
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
		table.insert(parts, p)
	end
	local barH = 0.16
	local thick = 0.7
	local y = 0.2
	edge("Front", Vector3.new(size.X, barH, thick), Vector3.new(0, y, -size.Y / 2))
	edge("Back", Vector3.new(size.X, barH, thick), Vector3.new(0, y, size.Y / 2))
	edge("Left", Vector3.new(thick, barH, size.Y), Vector3.new(-size.X / 2, y, 0))
	edge("Right", Vector3.new(thick, barH, size.Y), Vector3.new(size.X / 2, y, 0))
	for _, p in parts do
		TweenService:Create(
			p,
			TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.75 }
		):Play()
	end
	m.Parent = Workspace
	outline = m
end

local function selectItem(item: DockBlueprints.Item)
	local b = plotFrame
	if not b then
		return
	end
	local spot, size = DockBuild.spot(item)
	local world = b * spot
	outlineSpot(world, size)
	fly(DockBuild.camera(b, DockBuild.ISLAND_RADIUS, aspect(), world.Position), 0.5)
	AudioController.play("UI_Click")
end

local function cashBuy(item: DockBlueprints.Item)
	local remote = Net.init():WaitForChild("Dock_Upgrade", 5) :: RemoteFunction?
	if not remote then
		return
	end
	local ok = remote:InvokeServer(item.key)
	if not ok then
		shake(bar)
	end
end

local function robuxBuy(item: DockBlueprints.Item, id: number)
	if id == 0 then
		shake(bar)
		return
	end
	local entry = entryOf(item)
	if not entry then
		return
	end
	MarketplaceService:PromptProductPurchase(player, id)
end

local function iconOf(item: DockBlueprints.Item): string
	if item.kind == "Level" then
		return "build"
	elseif item.kind == "Building" then
		return if (item.key :: string) == "Hangar" then "boat_to_me" else "lifebuoy"
	elseif item.kind == "Blueprint" then
		return "map"
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key :: string].icon
	end
	return "build"
end

local function colorOf(item: DockBlueprints.Item): string
	if item.kind == "Level" then
		return "blue"
	elseif item.kind == "Building" then
		return "teal"
	elseif item.kind == "Blueprint" then
		return "purple"
	elseif item.kind == "Decor" then
		return DockConfig.Decorations[item.key :: string].color
	end
	return "blue"
end

local function levelLocked(item: DockBlueprints.Item): boolean
	if item.kind == "Level" then
		return (item.key :: number) > currentLevel() + 1
	elseif item.kind == "Building" then
		return currentLevel() < DockConfig.Buildings[item.key :: string].needs
	end
	return item.kind == "Blueprint"
end

local function rankLocked(item: DockBlueprints.Item): boolean
	if item.kind == "Blueprint" or item.kind == "Decor" then
		return false
	end
	local entry = entryOf(item)
	local rank = snapshot.rankIndex or 1
	return entry ~= nil and DockConfig.rankIndex(entry.rank) > rank
end

local function lineOf(item: DockBlueprints.Item, owned: boolean, levelLock: boolean): string
	if owned then
		return "Owned"
	elseif item.kind == "Blueprint" then
		return "Quest"
	elseif item.kind == "Decor" then
		return "Cash only"
	elseif levelLock and item.kind == "Level" then
		return `Dock Lv {(item.key :: number) - 1}`
	elseif levelLock and item.kind == "Building" then
		return `Dock Lv {DockConfig.Buildings[item.key :: string].needs}`
	end
	local entry = entryOf(item)
	if entry and entry.rank then
		local need = DockConfig.rankIndex(entry.rank)
		return `Rank {ProgressionConfig.Ranks[need].displayName}`
	end
	return ""
end

local function refreshCards()
	local content = cardsContent
	if not content then
		return
	end
	for _, row in rows do
		row.card.root:Destroy()
	end
	rows = {}
	local cash = snapshot.cash or 0
	local n = 0
	for _, item in DockBlueprints.catalog() do
		local decor = item.kind == "Decor"
		if (tabIndex == 2) == decor then
			n += 1
			local entry = entryOf(item)
			local owned = ownedOf(item)
			local blockedLevel, blockedRank = levelLocked(item), rankLocked(item)
			local cashPrice = if entry and type(entry.cash) == "number" then entry.cash else 0
			local state: CardUI.State = if owned
				then "owned"
				elseif blockedLevel or blockedRank or item.kind == "Blueprint" then "locked"
				elseif cashPrice > cash then "disabled"
				else "buy"
			local card: CardUI.Card
			card = CardUI.new(content, {
				art = iconOf(item),
				title = DockBlueprints.label(item),
				line = lineOf(item, owned, blockedLevel),
				color = colorOf(item),
				price = cashPrice,
				currency = "Cash",
				state = state,
				onBuy = function()
					cashBuy(item)
				end,
			})
			card.root.Name = `Card{n}`
			card.root.Size = UDim2.fromOffset(CARD_W, S.card)
			card.root.LayoutOrder = n
			local cashButton = card.price.root
			cashButton.AnchorPoint = Vector2.new(1, 0)
			cashButton.Position = UDim2.new(1, -8, 0, 8)
			cashButton.Size = UDim2.fromOffset(PRICE_W, PRICE_H)
			if item.kind == "Blueprint" then
				cashButton.Visible = false
			end
			local robux: PriceButtonUI.PriceButton? = nil
			if entry and entry.robux and not owned and item.kind ~= "Blueprint" then
				local product = MonetizationConfig.Products[entry.product]
				local id = if product then product.id else 0
				local rb = PriceButtonUI.new(card.root, {
					price = livePrice[id] or entry.robux,
					currency = "Robux",
					state = if id ~= 0 then "buy" else "disabled",
					onActivate = function()
						robuxBuy(item, id)
					end,
				})
				rb.root.AnchorPoint = Vector2.new(1, 1)
				rb.root.Position = UDim2.new(1, -8, 1, -8)
				rb.root.Size = UDim2.fromOffset(PRICE_W, PRICE_H)
				robux = rb
				if id ~= 0 and not livePrice[id] then
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
			local select = Style.button(card.root, UDim2.fromScale(1, 1))
			select.Name = "Select"
			select.ZIndex = 0
			Style.press(select, function()
				selectItem(item)
			end, S.corner)
			table.insert(rows, { card = card, select = select, robux = robux })
		end
	end
	if InputGlyph.device() == "Gamepad" and rows[1] then
		GuiService.SelectedObject = rows[1].select
	end
end

local function closeBuild()
	if not displayed then
		return
	end
	displayed = false
	clearOutline()
	if ui then
		ui.Enabled = false
	end
	modal.close()
	ContextActionService:UnbindAction("BuildModeExit")
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

	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -S.margin)
	holder.Size = UDim2.new(1, -2 * S.margin, 0, S.tab + 8 + S.card + 2 * S.pad)
	holder.BackgroundTransparency = 1
	holder.Parent = canvas
	local block, face = Style.block(holder, Style.grad("blue"), { studs = true })
	block.Size = UDim2.fromScale(1, 1)
	bar = holder

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BackgroundTransparency = 1
	inner.Position = UDim2.fromOffset(S.pad, S.pad)
	inner.Size = UDim2.new(1, -2 * S.pad, 1, -2 * S.pad)
	inner.Parent = face

	tabs = TabsUI.new(
		inner,
		{ { name = "Build", icon = "build" }, { name = "Decor", icon = "gift" } },
		function(i)
			tabIndex = i
			refreshCards()
		end
	)
	local tabBar = tabs :: TabsUI.Tabs
	tabBar.root.Size = UDim2.new(1, -(S.close + 10), 0, S.tab)

	local close = Style.button(inner, UDim2.fromOffset(S.close - 10, S.close - 10))
	close.Name = "Close"
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.fromScale(1, 0)
	close.ZIndex = 3
	local closeBlock, closeFace =
		Style.block(close, Style.grad("close"), { radius = S.cornerSmall })
	closeBlock.ZIndex = 3
	closeFace.ZIndex = 3
	local x = Style.label(closeFace, "X", Theme.Text.heading)
	x.ZIndex = 4
	Style.press(close, closeBuild, S.cornerSmall)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Cards"
	scroll.Position = UDim2.fromOffset(0, S.tab + 8)
	scroll.Size = UDim2.new(1, 0, 1, -(S.tab + 8))
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = Theme.Colors.text
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = inner
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.fromScale(0, 1)
	content.AutomaticSize = Enum.AutomaticSize.X
	content.Parent = scroll
	Style.list(content, true, 10)
	cardsContent = content

	return gui
end

local function bindExit()
	ContextActionService:BindActionAtPriority("BuildModeExit", function(_, state)
		if state == Enum.UserInputState.Begin then
			closeBuild()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 6, Enum.KeyCode.Escape)
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
	local tabBar = tabs
	if tabBar then
		tabBar.select(tabIndex)
	end
	local first = rows[1]
	modal.open(if first then first.select else nil)
	bindExit()
	fly(DockBuild.camera(b, DockBuild.ISLAND_RADIUS, aspect(), nil), 0.8)
	AudioController.play("UI_Click")
end

-- The Lego build beat (WP-14c): each part of a freshly built model drops from above with a stagger,
-- lands with a squash and a snap, then a dust puff. Client tweens only; the server owns the final
-- positions, so skipping this (a missed event) just shows the finished building.
local function snapSound(at: Vector3)
	AudioController.play("UI_Click", at, 0.5)
end

local function dustPuff(at: Vector3)
	local p = Instance.new("Part")
	p.Name = "BuildDust"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = at
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(230, 222, 205))
	e.Size =
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(0.6, 1.1)
	e.Speed = NumberRange.new(6, 14)
	e.SpreadAngle = Vector2.new(90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Drag = 2
	e.Enabled = false
	e.Parent = p
	p.Parent = Workspace
	e:Emit(25)
	game:GetService("Debris"):AddItem(p, 3)
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
	task.delay(last + 0.3, function()
		dustPuff(at)
	end)
end

-- A purchase (a level, building or decor landed, seen through the attributes): the till and the coin burst.
local function refresh()
	local level = player:GetAttribute("DockLevel")
	if type(level) ~= "number" then
		return
	end
	local count = level
	for _, key in DockConfig.BUILDINGS do
		if player:GetAttribute("Dock" .. key) == true then
			count += 1
		end
	end
	for _, key in DockConfig.DECOR do
		if player:GetAttribute("Decor" .. key) == true then
			count += 1
		end
	end
	if shownCount and count > shownCount then
		AudioController.play("Chandlery_Till")
		local view = Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize
			or Vector2.new(800, 600)
		CashBurst.playAt(playerGui, view / 2, 0, false)
	end
	shownCount = count
end

type Booth = { gui: ScreenGui, pickers: { CosmeticPicker.Picker } }
local booth: Booth? = nil
local inBooth = false
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
	local level, b = player:GetAttribute("DockLevel"), player:GetAttribute("BayCFrame")
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local now = false
	if seat and type(level) == "number" and level >= 3 and typeof(b) == "CFrame" then
		local zone = DockConfig.PAINT_BOOTH
		local d = ((b :: CFrame) * zone.cf):PointToObjectSpace(seat.Position)
		local h = zone.size / 2
		now = math.abs(d.X) <= h.X and math.abs(d.Y) <= h.Y and math.abs(d.Z) <= h.Z
	end
	if now ~= inBooth then
		inBooth = now
		if now then
			openBooth()
		else
			closeBooth()
		end
	end
end

function DockController.Init()
	modal = InputGlyph.modal("BuildTablet", closeBuild)
	boothModal = InputGlyph.modal("PaintBooth", closeBooth)
end

function DockController.Start()
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			snapshot = data
			if displayed then
				refreshCards()
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
			if displayed then
				refreshCards()
			end
		end
	end)
	local function onProgress()
		refresh()
		if displayed then
			refreshCards()
		end
	end
	player:GetAttributeChangedSignal("DockLevel"):Connect(onProgress)
	for _, key in DockConfig.BUILDINGS do
		player:GetAttributeChangedSignal("Dock" .. key):Connect(onProgress)
	end
	for _, key in DockConfig.DECOR do
		player:GetAttributeChangedSignal("Decor" .. key):Connect(onProgress)
	end
	refresh()
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
					prompt.MaxActivationDistance = 12
					prompt.RequiresLineOfSight = false
					prompt.Parent = tablet
					prompt.Triggered:Connect(openBuild)
				end
			end
			task.wait(2)
		end
	end)
	-- close if a teleport (or respawn) takes the player off the station
	task.spawn(function()
		while true do
			if displayed and stationPos then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart")
				local at = if root and root:IsA("BasePart") then root.Position else nil
				if not at or (at - stationPos).Magnitude > 90 then
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
