--!strict
-- ConstructionController (docs/24 B): every island's build site, drawn from the plot's SiteKey /
-- SiteProgress / SiteRate / SiteBuilders attributes (DockService). Client-only Lego dressing round the lot
-- (fence, scaffold, a small crane, brick stacks); a billboard over the roof (bar / time / crew count, your own site:
-- a Robux Finish button) pops in only near the site and draws on top of the walls. The building is the
-- server's model, its parts above the progress height hidden locally in BuildSeq's bottom-to-top order. On
-- finish the remaining bricks drop with the BuildSeq bounce, VFXKit's build_done / hq_levelup plays and the
-- fence/scaffold go away. Each brick lands a hair low and settles with one plastic click per course; the snap grows
-- with the level and the unlock flies to its button (docs/28 feel 5-6). Your builds that land off screen replay as a
-- watch beat the next time you step off at home (feel 7).
-- Late joiners reconcile to the same attributes, so they see the same state.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AssetIds = require(Shared:WaitForChild("Config"):WaitForChild("AssetIds"))
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Shared:WaitForChild("Config"):WaitForChild("ProgressionConfig"))
local VFXTextures = require(Shared:WaitForChild("Config"):WaitForChild("VFXTextures"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local CameraController = require(script.Parent:WaitForChild("CameraController"))
local OpsController = require(script.Parent:WaitForChild("OpsController"))
local Kit = UI:WaitForChild("Kit")
local Layout = require(UI:WaitForChild("Layout"))
local PriceButtonUI = require(Kit:WaitForChild("PriceButton"))
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local UnlockFly = require(UI:WaitForChild("UnlockFly"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))
local VFXPresets = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("Presets"))

local ConstructionController = {}
local player = Players.LocalPlayer

local RED = Color3.fromRGB(224, 56, 40)
local WHITE = Color3.fromRGB(242, 240, 232)
local YELLOW = Color3.fromRGB(250, 208, 40)
local STEEL = Color3.fromRGB(190, 194, 198)
local GREY = Color3.fromRGB(99, 95, 98)

type Site = {
	plot: Model,
	model: Model,
	key: string,
	props: Model,
	center: Vector3,
	parts: { BasePart },
	ys: { number }, -- each part's rise key: its height, or its layer on a layered asset
	lo: number,
	hi: number,
	kept: { [BasePart]: boolean }, -- the lower levels' parts: the standing building shows them
	hidden: { [BasePart]: boolean },
	original: { [BasePart]: number },
	minY: number,
	maxY: number,
	ground: number,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
	hw: number,
	hd: number,
	level: number, -- the level being built (1: a first build)
	sea: boolean, -- docs/27: a sea plate (its model's SeaSite): props float on scaffold barges
	progress: number,
	ready: boolean,
	bar: Frame,
	timer: TextLabel,
	count: TextLabel,
	post: BasePart,
	dust: ParticleEmitter,
	prompt: ProximityPrompt?,
	gui: BillboardGui,
	root: Frame,
	near: boolean,
	finish: PriceButtonUI.PriceButton?,
	price: number,
	clickAt: number, -- os.clock() of the last course click (capped ~3 a second)
	stacks: { BasePart }, -- the brick stacks, top bricks first: they run down as the building rises
	crane: { pivot: CFrame, parts: { BasePart }, offsets: { CFrame }, bob: number }, -- slew round the mast; parts[bob..] bob
	drop: { parts: { BasePart }, finals: { CFrame } }?, -- the bricks the finish dropped (a replay drops them again)
}

local sites: { [number]: Site } = {}
local livePrice: { [number]: number } = {}
local finishAsked: { [number]: boolean } = {}
local SHOW_NEAR, HIDE_FAR = 50, 60 -- studs from the site: the billboard pops in / out (a gap, so it never flickers)

-- The FinishNow product for a site's time left, with the live Robux price when there is an id.
local function finishProduct(left: number): (any, number)
	local product = MonetizationConfig.Products[`FinishNow{BuildTimer.finishTier(left)}`]
	if not product then
		return nil, 0
	end
	local id = product.id
	if id ~= 0 and not livePrice[id] and not finishAsked[id] then
		finishAsked[id] = true
		task.spawn(function()
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(id, Enum.InfoType.Product)
			end)
			if ok and type(info) == "table" and type(info.PriceInRobux) == "number" then
				livePrice[id] = info.PriceInRobux
			end
		end)
	end
	return product, livePrice[id] or product.price
end

-- Unready products stay visible in Studio, like the shelves' coming-soon cards.
local function finishOffered(product: any): boolean
	return product ~= nil
		and (RunService:IsStudio() or (product.ready ~= false and product.id ~= 0))
end

local function padUser(): boolean
	return string.sub(UserInputService:GetLastInputType().Name, 1, 7) == "Gamepad"
end

-- The owner's Finish: a green Robux button on the billboard (click / tap) and, for gamepads only, a stand-near
-- prompt (billboard buttons are out of pad selection). Both ask the server for its tier prompt; the button greys
-- out until that purchase prompt closes.
local function addFinishPrompt(site: Site)
	if site.prompt then
		return
	end
	local function ask()
		local finish = site.finish
		if finish and not finish.root.Active then
			return -- a purchase prompt is already open
		end
		if finish then
			finish.setState("disabled")
			task.delay(
				15,
				function() -- shortcut: no Finished event when the server declines; 15 s re-arms the button
					if finish.root.Parent then
						finish.setState("buy")
					end
				end
			)
		end
		Net.event("Dock_Finish"):FireServer()
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FinishNow"
	prompt.ActionText = "Finish"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = site.post
	prompt.Triggered:Connect(ask)
	site.prompt = prompt
	local finish = PriceButtonUI.new(site.root, { price = 0, currency = "Robux", onActivate = ask })
	finish.root.Name = "Finish"
	finish.root.AnchorPoint = Vector2.new(0.5, 1)
	finish.root.Position = UDim2.fromScale(0.5, 1)
	finish.root.Size = UDim2.fromOffset(150, 52)
	finish.root.Visible = false
	site.finish = finish
	site.gui.Size = UDim2.fromOffset(230, 92 + 6 + 52)
end

local function brick(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	colour: Color3
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function hide(part: BasePart, st: Site, on: boolean)
	if on and not st.hidden[part] then
		st.original[part] = part.Transparency
		st.hidden[part] = true
		part.Transparency = 1
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
				(child :: any).Enabled = false
			end
		end
	elseif not on and st.hidden[part] then
		st.hidden[part] = nil
		part.Transparency = st.original[part] or 0
		for _, child in part:GetChildren() do
			if child:IsA("SurfaceGui") or child:IsA("BillboardGui") then
				(child :: any).Enabled = true
			end
		end
	end
end

-- A brick falls `fall` s to BuildSeq.SINK under its rest, then Back-Outs up into it: the Lego squash.
local function settle(part: BasePart, final: CFrame, fall: number, delay: number)
	local drop = TweenService:Create(
		part,
		TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay),
		{ CFrame = final - Vector3.new(0, BuildSeq.SINK, 0) }
	)
	drop.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			TweenService:Create(
				part,
				TweenInfo.new(BuildSeq.SETTLE, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = final }
			):Play()
		end
	end)
	drop:Play()
end

-- The site's billboard over the roof: progress bar, time left and the hammer count. Under PlayerGui (adorned to
-- the sign post) so its Finish button takes clicks and taps; on top so the walls never hide it.
local function makeSign(st: Site, build: boolean)
	local def = if build then DockConfig.Buildings[st.key] else DockConfig.Decorations[st.key]
	local gui = Instance.new("BillboardGui")
	gui.Name = `ConstructionSign_{st.plot.Name}`
	gui.Size = UDim2.fromOffset(230, 92)
	gui.Adornee = st.post
	gui.StudsOffsetWorldSpace = Vector3.new(st.center.X, st.maxY + 6, st.center.Z - 3)
		- st.post.Position -- over the lot
	gui.AlwaysOnTop = true
	gui.Active = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	st.gui = gui
	st.root = Instance.new("Frame")
	st.root.Name = "Root"
	st.root.BackgroundTransparency = 1
	st.root.Size = UDim2.fromScale(1, 1)
	st.root.Visible = false
	st.root.Parent = gui
	local board = Instance.new("Frame")
	board.BackgroundTransparency = 1
	board.Size = UDim2.fromOffset(230, 92)
	board.Parent = st.root
	local holder, face = Style.block(board, Style.grad("ink"), { radius = 10, lip = 4 })
	holder.Name = "Board"
	local name = if build
		then DockConfig.levelName(st.key, tonumber(st.plot:GetAttribute("SiteLevel")) or 1)
		elseif def then def.name
		else st.key
	local title = Style.label(face, name, Theme.Text.small)
	title.Position = UDim2.fromOffset(10, 6)
	title.Size = UDim2.new(1, -100, 0, 26)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextWrapped = false
	title.TextTruncate = Enum.TextTruncate.AtEnd
	local hammer = Instance.new("Frame")
	hammer.BackgroundTransparency = 1
	hammer.AnchorPoint = Vector2.new(1, 0)
	hammer.Position = UDim2.new(1, -10, 0, 6)
	hammer.Size = UDim2.fromOffset(22, 22)
	hammer.Parent = face
	Style.icon(hammer, "build")
	st.count = Style.label(face, "", Theme.Text.small)
	st.count.AnchorPoint = Vector2.new(1, 0)
	st.count.Position = UDim2.new(1, -38, 0, 6)
	st.count.Size = UDim2.fromOffset(60, 22)
	st.count.TextXAlignment = Enum.TextXAlignment.Right
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = Color3.fromRGB(30, 44, 66)
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 10, 1, -22)
	bar.Size = UDim2.new(1, -20, 0, 12)
	Style.corner(bar, 6)
	bar.Parent = face
	st.bar = Instance.new("Frame")
	st.bar.Name = "Fill"
	st.bar.BackgroundColor3 = YELLOW
	st.bar.BorderSizePixel = 0
	st.bar.Size = UDim2.fromScale(0, 1)
	Style.corner(st.bar, 6)
	st.bar.Parent = bar
	st.timer = Style.label(face, "0:00", Theme.Text.small)
	st.timer.Name = "Timer"
	st.timer.AnchorPoint = Vector2.new(1, 1)
	st.timer.Position = UDim2.new(1, -10, 1, -30)
	st.timer.Size = UDim2.fromOffset(64, 22)
	st.timer.TextXAlignment = Enum.TextXAlignment.Right
end

-- M_Prop_BuildSiteKit (Blender, art/source/props/M_Prop_BuildSiteKit/build.py): each module's MeshPart and its
-- offset from the module's origin (ATT_<slot>). nil until DepotArtService publishes the kit: the Parts stand in.
local KIT_SLOT = {
	FencePanel = "Fence",
	FenceGate = "Gate",
	FencePost = "Post",
	ScaffoldBay = "Scaffold",
	CraneBase = "Crane",
	CraneSlew = "Crane",
	CraneHook = "Crane",
	StackPallet = "Stack",
	StackLow = "Stack",
	StackMid = "Stack",
	StackTop = "Stack",
	SignBoard = "Sign",
	Cone = "Cone",
	Barrier = "Barrier",
}
local kitCache: { [string]: { part: BasePart, offset: CFrame } }? = nil

local function siteKit(): { [string]: { part: BasePart, offset: CFrame } }?
	if kitCache then
		return kitCache
	end
	local folder = ReplicatedStorage:FindFirstChild("DepotTemplates")
	local kit = folder and folder:FindFirstChild("BuildSiteKit")
	local att = (AssetIds.Attachments :: any).M_Prop_BuildSiteKit
	if not (kit and kit:IsA("Model") and att) then
		return nil
	end
	local pivot = kit:GetPivot()
	local out, count = {}, 0
	for _, d in kit:GetDescendants() do
		local key = if d:IsA("BasePart") then string.match(d.Name, "^L%d%d_(%a+)") else nil
		local origin = key and KIT_SLOT[key] and att[`ATT_{KIT_SLOT[key]}`]
		if key and origin and not out[key] then
			out[key] = {
				part = d :: BasePart,
				offset = CFrame.new(origin):Inverse() * pivot:ToObjectSpace(d.CFrame),
			}
			count += 1
		end
	end
	if count < 14 then -- a partial upload: keep the Parts
		return nil
	end
	kitCache = out
	return out
end

-- One kit module with its origin at `cf`, stretched by sx along the module's x (fence and scaffold runs fit the lot).
local function module(parent: Instance, key: string, cf: CFrame, sx: number?): BasePart
	local k = (kitCache :: any)[key]
	local p = k.part:Clone()
	local offset = k.offset
	if sx and sx ~= 1 then
		local along = offset.Rotation:VectorToObjectSpace(Vector3.xAxis) -- the module's x in the part's own axes
		p.Size *= Vector3.one + (sx - 1) * Vector3.new(
			math.abs(along.X),
			math.abs(along.Y),
			math.abs(along.Z)
		)
		offset = CFrame.new(offset.Position * Vector3.new(sx, 1, 1)) * offset.Rotation
	end
	p.Anchored = true
	p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
	p.CastShadow = false
	p.CFrame = cf * offset
	p.Parent = parent
	return p
end

-- The kit dressing round the lot; false when the kit has not loaded (the caller builds the Parts).
local function kitProps(st: Site, props: Model, at: CFrame): boolean
	if not siteKit() then
		return false
	end
	local fw, fd = st.hw + 4, st.hd + 4 -- one stud wider than the Parts fence: the scaffold fits inside
	local gate = not st.sea and fw >= 11
	if not st.sea then
		-- fence ring, counter-clockwise from the front so every panel's front (-z) faces out; posts at the corners
		local corners = {
			Vector3.new(-fw, 0, -fd),
			Vector3.new(fw, 0, -fd),
			Vector3.new(fw, 0, fd),
			Vector3.new(-fw, 0, fd),
		}
		local function fill(a: Vector3, b: Vector3)
			local dir = (b - a).Unit
			local len = (b - a).Magnitude
			local n = math.max(1, math.round(len / 8))
			local sx = len / (n * 8)
			for i = 0, n - 1 do
				local pos = a + dir * (i + 0.5) * len / n
				module(props, "FencePanel", at * CFrame.fromMatrix(pos, dir, Vector3.yAxis), sx)
			end
		end
		for i, c in corners do
			local nxt = corners[i % 4 + 1]
			local dir = (nxt - c).Unit
			module(props, "FencePost", at * CFrame.new(c))
			if i == 1 and gate then
				module(props, "FenceGate", at * CFrame.new(0, 0, -fd))
				fill(c + dir * 0.65, Vector3.new(-4, 0, -fd))
				fill(Vector3.new(4, 0, -fd), nxt - dir * 0.65)
			else
				fill(c + dir * 0.65, nxt - dir * 0.65)
			end
		end
		-- scaffold bays up the front face, tiled to its width, stacked to about half the finished height
		local n = math.max(1, math.round(st.hw * 2 / 6))
		local sx = st.hw * 2 / (n * 6)
		for level = 0, math.clamp(math.round((st.maxY - st.ground) / 10), 1, 3) - 1 do
			for i = 0, n - 1 do
				local x = -st.hw + (i + 0.5) * 6 * sx
				module(props, "ScaffoldBay", at * CFrame.new(x, level * 5, -st.hd - 1.4), sx)
			end
		end
		module(
			props,
			"Barrier",
			at * CFrame.new(fw + 2, 0, -fd + 4) * CFrame.Angles(0, -math.pi / 2, 0)
		)
		if gate then -- cones flank the opening
			module(props, "Cone", at * CFrame.new(-4.9, 0, -fd - 1.3))
			module(props, "Cone", at * CFrame.new(4.9, 0, -fd - 1.3))
		end
	end
	-- the tower crane: off the back-left corner with its jib over the lot (at sea: on the front-left barge); the
	-- slew and hook turn round ATT_CranePivot
	local hw, hd = st.hw + 3, st.hd + 3
	local base = if st.sea
		then at * CFrame.new(-hw + 3, 0, -hd - 4)
		else at
			* CFrame.new(-fw - 4.5, 0, fd + 4.5)
			* CFrame.Angles(0, math.pi / 4, 0) -- the brick clears the walls
	module(props, "CraneBase", base)
	local att = (AssetIds.Attachments :: any).M_Prop_BuildSiteKit
	local pivot = base * CFrame.new(att.ATT_CranePivot - att.ATT_Crane)
	st.crane = { pivot = pivot, parts = {}, offsets = {}, bob = 2 }
	for _, key in { "CraneSlew", "CraneHook" } do
		local part = module(props, key, base)
		table.insert(st.crane.parts, part)
		table.insert(st.crane.offsets, pivot:ToObjectSpace(part.CFrame))
	end
	-- brick pallets along the front right, in view: three courses each, the top courses go first as the building rises
	local courses: { { BasePart } } = { {}, {}, {} }
	for n = 0, 2 do
		local cf = at
			* if st.sea
				then CFrame.new(-9 + n * 3.8, 0, hd + 2)
				else CFrame.new(6.5 + n * 3.8, 0, -fd - 2.4)
		module(props, "StackPallet", cf)
		for k, key in { "StackTop", "StackMid", "StackLow" } do
			table.insert(courses[k], module(props, key, cf))
		end
	end
	st.stacks = table.move(courses[3], 1, 3, 7, table.move(courses[2], 1, 3, 4, courses[1]))
	st.post = module(props, "SignBoard", at * CFrame.new(
		if gate then -math.min(8.6, fw - 2.4) else 0, -- left of the gate: the pallets go right
		0,
		if st.sea then -hd - 1.5 else -fd - 2
	))
	return true
end

-- The Lego dressing round the lot (about 37 parts a site).
local function makeProps(st: Site)
	local props = Instance.new("Model")
	props.Name = `Construction_{st.key}`
	props.Parent = st.plot
	st.props = props
	local at = CFrame.new(st.center.X, st.ground, st.center.Z)
	local hw, hd = st.hw + 3, st.hd + 3
	-- four runs of three panels: every run is (offset, panel length, runs along X?)
	local runs: { { offset: Vector3, along: number, flat: boolean } } = {
		{ offset = Vector3.new(0, 0, -hd), along = hw * 2, flat = true },
		{ offset = Vector3.new(0, 0, hd), along = hw * 2, flat = true },
		{ offset = Vector3.new(-hw, 0, 0), along = hd * 2, flat = false },
		{ offset = Vector3.new(hw, 0, 0), along = hd * 2, flat = false },
	}
	if st.sea then
		runs = {} -- docs/27: no fence on the water; the crew works off floating Lego scaffold barges
		at += Vector3.new(0, 0.6, 0)
		for _, b in { { -hw + 3, -hd - 4, 9, 9 }, { 0, -hd - 1.5, 6, 4 }, { -5, hd + 2, 14, 5 } } do
			brick(
				props,
				"ScaffoldBarge",
				Vector3.new(b[3], 1.4, b[4]),
				at * CFrame.new(b[1], -0.7, b[2]),
				YELLOW
			)
		end
	end
	if not kitProps(st, props, at) then
		for _, run in runs do
			local offset, along, flat = run.offset, run.along, run.flat
			for n = 0, 2 do
				local shift = (n - 1) * along / 3
				local size = if flat
					then Vector3.new(along / 3 - 0.3, 3, 0.4)
					else Vector3.new(0.4, 3, along / 3 - 0.3)
				brick(
					props,
					"Fence",
					size,
					at
						* CFrame.new(
							offset.X + (if flat then shift else 0),
							1.5,
							offset.Z + (if flat then 0 else shift)
						),
					if n % 2 == 0 then RED else WHITE
				)
			end
		end
		for _, corner in
			(if st.sea
				then {}
				else {
					Vector3.new(-hw, 0, -hd),
					Vector3.new(hw, 0, -hd),
					Vector3.new(-hw, 0, hd),
					Vector3.new(hw, 0, hd),
				}) :: { Vector3 }
		do
			brick(
				props,
				"FencePost",
				Vector3.new(0.6, 3.4, 0.6),
				at * CFrame.new(corner.X, 1.7, corner.Z),
				RED
			)
		end
		-- scaffold poles at the corners of the building, with two rails on the front
		for _, corner in
			(if st.sea
				then {} -- the rising pillars are the scaffold
				else {
					Vector3.new(-st.hw, 0, -st.hd),
					Vector3.new(st.hw, 0, -st.hd),
					Vector3.new(-st.hw, 0, st.hd),
					Vector3.new(st.hw, 0, st.hd),
				}) :: { Vector3 }
		do
			brick(
				props,
				"Scaffold",
				Vector3.new(0.5, 10, 0.5),
				at * CFrame.new(corner.X, 5, corner.Z),
				STEEL
			)
		end
		for _, y in (if st.sea then {} else { 4, 8 }) :: { number } do
			brick(
				props,
				"ScaffoldRail",
				Vector3.new(st.hw * 2, 0.35, 0.35),
				at * CFrame.new(0, y, -st.hd - 0.6),
				STEEL
			)
		end
		-- a small Lego crane by the front-left corner
		local base = at * CFrame.new(-hw + 3, 0, -hd - 4)
		brick(props, "CraneBase", Vector3.new(4, 1.2, 4), base * CFrame.new(0, 0.6, 0), GREY)
		brick(props, "CraneMast", Vector3.new(1.2, 13, 1.2), base * CFrame.new(0, 7, 0), YELLOW)
		local pivot = base * CFrame.new(0, 13.6, 0)
		st.crane = { pivot = pivot, parts = {}, offsets = {}, bob = 3 }
		for _, c in
			{
				{ "CraneCab", Vector3.new(2.4, 2.4, 2.4), Vector3.zero, RED },
				{ "CraneJib", Vector3.new(11, 0.7, 0.7), Vector3.new(4.5, 0.8, 0), YELLOW },
				{ "CraneHook", Vector3.new(0.3, 4.5, 0.3), Vector3.new(9.4, -1.5, 0), GREY },
				{ "CraneBlock", Vector3.new(1.1, 1.1, 1.1), Vector3.new(9.4, -3.9, 0), RED },
			} :: { { any } }
		do
			local offset = CFrame.new(c[3])
			table.insert(st.crane.parts, brick(props, c[1], c[2], pivot * offset, c[4]))
			table.insert(st.crane.offsets, offset)
		end
		-- brick stacks along the front: the top bricks go first as the building rises
		local tops: { BasePart }, bottoms: { BasePart } = {}, {}
		for n = 0, 2 do
			local stack = at * CFrame.new(-8 + n * 3.4, 0, hd + 2)
			table.insert(
				bottoms,
				brick(
					props,
					"Bricks",
					Vector3.new(2.6, 0.8, 1.2),
					stack * CFrame.new(0, 0.4, 0),
					WHITE
				)
			)
			table.insert(
				tops,
				brick(
					props,
					"Bricks",
					Vector3.new(2.6, 0.8, 1.2),
					stack * CFrame.new(0, 1.2, 0),
					RED
				)
			)
		end
		st.stacks = table.move(bottoms, 1, #bottoms, #tops + 1, tops)
		-- the sign post
		st.post = brick(
			props,
			"SignPost",
			Vector3.new(0.5, 8, 0.5),
			at * CFrame.new(0, 4, -hd - 1.5),
			GREY
		)
	end
	local dust = Instance.new("Part")
	dust.Name = "Dust"
	dust.Size = Vector3.one
	dust.Transparency = 1
	dust.Anchored, dust.CanCollide, dust.CanQuery, dust.CanTouch = true, false, false, false
	dust.Position = at.Position + Vector3.new(0, 2, -st.hd)
	dust.Parent = props
	st.dust = Instance.new("ParticleEmitter")
	local puff = VFXTextures.puff_smoke -- the game's studded puffs, not the stock smoke
	st.dust.Texture = puff.id
	st.dust.FlipbookLayout = (Enum.ParticleFlipbookLayout :: any)[puff.layout]
	st.dust.FlipbookMode = (Enum.ParticleFlipbookMode :: any)[puff.mode]
	st.dust.Color = ColorSequence.new(Color3.fromRGB(230, 222, 205))
	st.dust.Size = NumberSequence.new(2, 5)
	st.dust.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	st.dust.Lifetime = NumberRange.new(0.5, 0.9)
	st.dust.Speed = NumberRange.new(3, 7)
	st.dust.SpreadAngle = Vector2.new(90, 90)
	st.dust.EmissionDirection = Enum.NormalId.Top
	st.dust.Acceleration = Vector3.new(0, -5, 0)
	st.dust.Drag = 2
	st.dust.Rate = 0
	st.dust.Parent = dust
end

-- docs/25 J: a layered asset (Lv<k>_L<nn>_ meshes, e.g. the Depot and the HQ) rises layer by layer, the pile with
-- its rack; nil: a lower level's part (no Lv<k>_: Lv1, like the quay and the paths), which the standing building
-- shows. Parts DockPieces adds around a mesh (the HQ's sign ribbons) carry BuildLv / BuildY (a layer number).
local function layerOf(part: BasePart, level: number): number?
	local lv = tonumber(part:GetAttribute("BuildLv") or string.match(part.Name, "Lv(%d)_")) or 1
	if lv < level then
		return nil
	end
	local layer = tonumber(part:GetAttribute("BuildY") or string.match(part.Name, "_L(%d%d)_"))
	if layer then
		return layer
	end
	return if string.find(part.Name, "_Stack_", 1, true) then 3.5 else 0 -- 0: hulls and marks, there from the start
end

local function startSite(plot: Model, model: Model, key: string, mine: boolean): Site
	local parts, ys, kept = {}, {}, {}
	local minY, maxY = math.huge, -math.huge
	local ground = math.huge
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local level = tonumber(plot:GetAttribute("SiteLevel")) or 1
	local layered = false
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.match(d.Name, "_L%d%d_") then
			layered = true
			break
		end
	end
	local lo, hi = math.huge, -math.huge
	for _, d in model:GetDescendants() do
		if not d:IsA("BasePart") then
			continue
		end
		local rise = if layered then layerOf(d, level) else d.CFrame.Y
		if not rise then
			kept[d] = true
			continue
		end
		table.insert(parts, d)
		table.insert(ys, rise)
		lo, hi = math.min(lo, rise), math.max(hi, rise)
		local holder = d:FindFirstAncestorWhichIsA("Model")
		if holder and holder ~= model and holder:GetAttribute("SiteApart") then
			continue -- the fence and sign go round the lot, not round a far quay
		end
		minY, maxY = math.min(minY, d.CFrame.Y), math.max(maxY, d.CFrame.Y)
		ground = math.min(ground, d.CFrame.Y - d.Size.Y / 2)
		local p = d.Position
		minX, maxX = math.min(minX, p.X), math.max(maxX, p.X)
		minZ, maxZ = math.min(minZ, p.Z), math.max(maxZ, p.Z)
	end
	local sea = model:GetAttribute("SeaSite") == true
	if sea then
		ground, minY = 0, math.max(minY, 0) -- the waterline, not the seabed under the pillars
	end
	if #parts == 0 then
		lo, hi = 0, 0
		minY, maxY, ground = 0, 0, 0
		minX, maxX, minZ, maxZ = 0, 0, 0, 0
	end
	local site: Site = {
		plot = plot,
		model = model,
		key = key,
		props = nil :: any,
		center = Vector3.new((minX + maxX) / 2, minY, (minZ + maxZ) / 2),
		parts = parts,
		ys = ys,
		lo = lo,
		hi = hi,
		kept = kept,
		hidden = {},
		original = {},
		minY = minY,
		maxY = maxY,
		ground = ground,
		minX = minX,
		maxX = maxX,
		minZ = minZ,
		maxZ = maxZ,
		hw = (maxX - minX) / 2 + 1,
		hd = (maxZ - minZ) / 2 + 1,
		level = level,
		sea = sea,
		progress = 0,
		ready = false,
		bar = nil :: any,
		timer = nil :: any,
		count = nil :: any,
		post = nil :: any,
		dust = nil :: any,
		prompt = nil,
		gui = nil :: any,
		root = nil :: any,
		near = false,
		finish = nil,
		price = -1,
		clickAt = 0,
		stacks = {},
		crane = nil :: any,
		drop = nil,
	}
	for part in kept do
		hide(part, site, true)
	end
	makeProps(site)
	makeSign(site, DockConfig.Buildings[key] ~= nil)
	if mine then
		addFinishPrompt(site)
	end
	return site
end

local function update(site: Site, progress: number, rate: number, builders: number)
	local p = math.clamp(progress, 0, 1)
	local cutoff = site.lo + (site.hi - site.lo) * p
	local popped = false
	for n, part in site.parts do
		local hid = site.ys[n] > cutoff + 1e-3 -- the resting height: a part mid-drop must not hide again
		if not hid and site.hidden[part] and site.ready then
			-- a newly reached course drops into place with a short Lego bounce
			local final = part.CFrame
			hide(part, site, false)
			part.CFrame = final + Vector3.new(0, 2, 0)
			settle(part, final, 0.25, 0)
			popped = true
		else
			hide(part, site, hid)
		end
	end
	local now = os.clock()
	if popped and now - site.clickAt >= BuildSeq.CLICK_GAP then
		site.clickAt = now
		task.delay(0.25, function() -- the course clicks home, higher as the building rises
			local at = Vector3.new(
				site.center.X,
				site.ground + (site.maxY - site.ground) * p,
				site.center.Z
			)
			local pitch = BuildSeq.PITCH_LO + p * (BuildSeq.PITCH_HI - BuildSeq.PITCH_LO)
			AudioController.play("FX_Snap", at, 0.45, pitch)
		end)
	end
	for k, stack in site.stacks do
		stack.Transparency = if k <= math.floor(p * #site.stacks) then 1 else 0
	end
	site.progress = p
	site.ready = true
	site.bar.Size = UDim2.fromScale(p, 1)
	local work = if DockConfig.Buildings[site.key]
		then BuildTimer.work(DockConfig.Buildings[site.key].cash)
		else BuildTimer.DECOR
	local left = BuildTimer.timeLeft(p, rate, work)
	site.timer.Text = BuildTimer.text(left)
	site.count.Text = `x{builders}`
	if site.prompt and site.finish then
		local product, price = finishProduct(left)
		-- SiteFinish: the server's tutorial / free-build gate (DockService.finishAllowed)
		local offered = left >= 3
			and finishOffered(product)
			and site.plot:GetAttribute("SiteFinish") == true
		site.prompt.Enabled = offered and padUser()
		site.prompt.ObjectText = `R$ {price}`
		-- touch: the pixel-sized on-top billboard lands under steering thumbs; phones finish from the tablet
		site.finish.root.Visible = offered and not Layout.current().touch
		if price ~= site.price then
			site.price = price
			site.finish.setPrice(price)
		end
	end
end

-- Pop the billboard in near the site (measured from the lot's edge: big lots too), out when walking away.
local function showNear(site: Site, at: Vector3)
	local dx = math.max(math.abs(at.X - site.center.X) - site.hw, 0)
	local dz = math.max(math.abs(at.Z - site.center.Z) - site.hd, 0)
	local d = math.sqrt(dx * dx + dz * dz)
	local near = if site.near then d < HIDE_FAR else d < SHOW_NEAR
	if near ~= site.near then
		site.near = near
		Style.pop(site.root, near)
	end
end

local function stop(site: Site)
	if site.model.Parent then
		for part in site.hidden do
			hide(part, site, false)
		end
	end
	site.props:Destroy()
	site.gui:Destroy()
end

-- docs/27 plate_drop (spectacle, ~3 s): anticipation 0.5 s, the deck lowers from above on the crane hook while its
-- shadow grows on the water (a brick rattle); impact, the deep snap with rings out from under the plate (VFXKit
-- plate_drop, its camera kick off under Reduce motion); settle, the rim bricks pop in left to right, then the
-- bollards, lamps and the rest drop in with the BuildSeq bounce. Never a sparkle.
local DROP_T, DECK_LIFT = 0.5, 14
local function plateDrop(site: Site, parts: { BasePart }, finals: { CFrame }, mine: boolean)
	local camera = Workspace.CurrentCamera
	local right = if camera then camera.CFrame.RightVector else Vector3.xAxis
	local deck, rim, rest = {}, {}, {}
	for i, part in parts do
		local row = { part = part, final = finals[i] }
		if part.Name == "Deck" or part.Name == "Gangway" then
			table.insert(deck, row)
		elseif part.Name == "Rim" then
			table.insert(rim, row)
		else
			table.insert(rest, row)
		end
	end
	table.sort(rim, function(a, b)
		return a.final.Position:Dot(right) < b.final.Position:Dot(right)
	end)
	local centre = Vector3.new(site.center.X, 0, site.center.Z)
	local size = Vector3.new(site.maxX - site.minX, 0.2, site.maxZ - site.minZ)
	local shadow = brick(
		site.plot,
		"PlateShadow",
		size * 0.55,
		CFrame.new(centre + Vector3.new(0, 0.3, 0)),
		GREY
	)
	shadow.Transparency = 0.75
	TweenService:Create(
		shadow,
		TweenInfo.new(DROP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = size, Transparency = 0.45 }
	):Play()
	AudioController.play("FX_PlasticRain", centre, 0.6, 0.75) -- the brick rattle on the hook
	for _, row in deck do
		hide(row.part, site, false)
		row.part.CFrame = row.final + Vector3.new(0, DECK_LIFT, 0)
		TweenService:Create(
			row.part,
			TweenInfo.new(DROP_T, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = row.final }
		):Play()
	end
	task.delay(DROP_T, function()
		shadow:Destroy()
		VFXKit.play("plate_drop", CFrame.new(centre), {
			radius = math.max(site.hw, site.hd),
			height = 6,
			still = not mine,
		})
	end)
	local function pop(row: { part: BasePart, final: CFrame }, at: number, lift: number)
		task.delay(at, function()
			if not site.model.Parent then
				return
			end
			hide(row.part, site, false)
			row.part.CFrame = row.final + Vector3.new(0, lift, 0)
			TweenService:Create(
				row.part,
				TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ CFrame = row.final }
			):Play()
		end)
	end
	for k, row in rim do
		pop(row, DROP_T + 0.15 + 0.6 * (k - 1) / math.max(#rim - 1, 1), 3)
	end
	local ys = {}
	for i, row in rest do
		ys[i] = row.final.Y
	end
	for _, step in BuildSeq.plan(ys, math.random(0, 1_000_000)) do
		pop(rest[step.i], DROP_T + 0.8 + math.min(step.delay, 0.8), 4)
	end
	task.delay(DROP_T + 1.1, AudioController.play, "FX_PlasticRain", centre, 0.5, 1.15) -- the rim clicks home
	site.props:Destroy()
end

local function isMine(site: Site): boolean
	return site.plot.Name == `Plot{player:GetAttribute("DockPlot")}`
end

-- The tutorial's free Hut and first Workshop keep OnboardingController's own beats.
local function tutorialBeat(site: Site): boolean
	return site.level == 1 and (site.key == "HQ" or site.key == "Workshop")
end

-- docs/28 feel 6: what the level unlocked flies off the roof to its button (your own buildings only, not decor)
local function flyUnlock(site: Site, roof: Vector3)
	local def = DockConfig.Buildings[site.key]
	if def and isMine(site) and not tutorialBeat(site) then
		local target = BuildSeq.unlockTarget(
			site.key,
			site.level,
			def,
			ProgressionConfig.Vehicles,
			DockConfig.Unlocks
		)
		task.spawn(UnlockFly.play, roof, target)
	end
end

-- The last bricks drop with the BuildSeq bounce, a plastic click per course, a Lego clack and confetti as they
-- land (your HQ: a fanfare too). A replay (feel 7) drops the same bricks again from `site.drop`.
local function land(site: Site)
	for part in site.kept do
		hide(part, site, false) -- already standing: no drop
	end
	if not site.drop then
		local drop = { parts = {}, finals = {} }
		for part in site.hidden do
			table.insert(drop.parts, part)
			table.insert(drop.finals, part.CFrame)
		end
		site.drop = drop
	end
	local drop = site.drop :: { parts: { BasePart }, finals: { CFrame } }
	local parts, finals = drop.parts, drop.finals
	local roof = Vector3.new(site.center.X, site.maxY + 2, site.center.Z)
	if site.sea then
		plateDrop(site, parts, finals, isMine(site))
		task.delay(DROP_T + 0.9, flyUnlock, site, roof)
		return
	end
	local ys = {}
	for i, part in parts do
		hide(part, site, false)
		ys[i] = finals[i].Y
	end
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local last = 0
	for _, step in plan do
		last = math.max(last, step.delay)
		local part = parts[step.i]
		part.CFrame = finals[step.i] + Vector3.new(0, step.drop, 0)
		settle(part, finals[step.i], BuildSeq.FALL, step.delay)
	end
	local mid =
		Vector3.new(site.center.X, site.ground + (site.maxY - site.ground) * 0.5, site.center.Z)
	for _, click in BuildSeq.clicks(plan, ys) do
		task.delay(click.t, AudioController.play, "FX_Snap", mid, 0.45, click.pitch)
	end
	local top =
		Vector3.new(site.center.X, site.ground + (site.maxY - site.minY) * 0.6, site.center.Z)
	local mine = isMine(site)
	local hq = site.key == "HQ" and mine
	-- the last brick clacks home (a plastic snap, two quick hits), then the confetti; your HQ gets the big beat
	task.delay(last + BuildSeq.FALL, function()
		AudioController.play("Album_Sticker", top, 1, 1.5)
		task.delay(0.07, function()
			AudioController.play("UI_Click", top, 3, 0.75)
		end)
		-- docs/26 FX1: a studded ring and plates race out low, rays and confetti only above the roof (never on the
		-- building); it grows with the level (feel 6); your HQ gets the charge, the white-hot core and the pillar
		local base = CFrame.new(site.center.X, site.ground, site.center.Z)
		local fx = {
			radius = math.max(site.hw, site.hd) + 1,
			height = site.maxY - site.ground + 8, -- confetti well clear of the ridge (F1 AD r2)
			still = not mine,
		}
		local snap = if site.level >= 3
			then "fx1_build_snap_lv3"
			elseif site.level == 2 then "fx1_build_snap_lv2"
			else "fx1_build_snap"
		VFXKit.play(if hq then "fx1_hq_levelup" else snap, base, fx)
		if hq then
			task.delay(0.5, AudioController.play, "Music_CrateFanfare", nil, 1, 1) -- on the impact (HQ_AT)
		end
		task.delay(if hq then 1.1 else 0.6, flyUnlock, site, roof)
	end)
	site.props:Destroy()
	if site.gui.Parent then
		Style.pop(site.root, false)
		task.delay(0.2, site.gui.Destroy, site.gui)
	end
end

-- Playtest 2026-10-31 (pta 5): the Depot and the Ramp Wharf finished off screen. Your own site's finish gets a
-- watch beat: the camera eases over (WATCH_EASE), holds through the drop and the snap, eases back to where it was.
-- Skippable; reduced motion cuts instead of easing. Never seated, on a call, under a panel or from afar, nor for
-- the tutorial beats.
local WATCH_EASE, WATCH_HOLD = 0.9, 3.4 -- s; the shortest hold: a small drop + fx1_build_snap (OnboardingController SITE_HOLD)
local BURST = 1.2 -- s the snap's rings and confetti play before the camera eases back

-- How long the camera holds: the whole drop (a big building's span is ~4.2 s) and the snap's burst.
local function holdFor(site: Site): number
	local n = if site.drop then #site.drop.parts else 0
	if not site.drop then
		for _ in site.hidden do
			n += 1
		end
	end
	if site.sea then
		return WATCH_HOLD
	end
	return math.max(WATCH_HOLD, BuildSeq.span(n) + BuildSeq.FALL + BuildSeq.SETTLE + BURST)
end

local function watch(site: Site): number?
	if tutorialBeat(site) then
		return nil
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local tablet = player:FindFirstChild("PlayerGui")
		and player.PlayerGui:FindFirstChild("BuildTablet")
	local ops = OpsController.GetState()
	local cam = Workspace.CurrentCamera
	if
		not (hum and root and root:IsA("BasePart") and cam)
		or hum.SeatPart
		or (ops and ops.state == "Active")
		or Layout.coldOpen()
		or player:GetAttribute("MenuOpen") == true
		or player:GetAttribute("CinematicPlaying") == true
		or (tablet and tablet:IsA("ScreenGui") and tablet.Enabled)
		or (root.Position - site.center).Magnitude > 320
	then
		return nil
	end
	local height = site.maxY - site.ground
	local at = Vector3.new(site.center.X, site.ground + height * 0.4, site.center.Z)
	local side = (cam.CFrame.Position - at) * Vector3.new(1, 0, 1)
	local dist = math.max(site.hw, site.hd, height) * 2 + 18 -- the whole lot and the burst in shot (F1 AD r2)
	local eye = at
		+ (if side.Magnitude > 1 then side.Unit else Vector3.zAxis) * dist
		+ Vector3.new(0, dist * 0.42, 0)
	local view = CFrame.lookAt(eye, at)
	local back, fov = cam.CFrame, cam.FieldOfView
	if CameraController.Comfort.reducedMotion() then
		CameraController.PlayCinematic(
			{ { from = view, duration = holdFor(site), fov = fov, handheld = 0 } },
			{
				skippable = true,
			}
		)
		return 0
	end
	local push = view * CFrame.new(0, 0, -dist * 0.08) -- a slow push-in while the bricks land
	CameraController.PlayCinematic({
		{ from = back, to = view, duration = WATCH_EASE, fov = fov, toFov = 50, handheld = 0 },
		{ from = view, to = push, duration = holdFor(site), fov = 50, handheld = 0.15 },
		{ from = push, to = back, duration = WATCH_EASE, fov = 50, toFov = fov, handheld = 0 },
	}, { skippable = true })
	return WATCH_EASE
end

-- docs/28 feel 7: your builds that land where you can't see them (at sea, off screen, past the VFX cull) wait here,
-- newest last, and replay as a watch beat the next time you step off a craft near them (your jetty).
local missed: { Site } = {}
local MISSED_MAX = 3

local function unseen(site: Site): boolean
	local cam = Workspace.CurrentCamera
	if not cam then
		return true
	end
	local _, onScreen = cam:WorldToViewportPoint(site.center)
	return not onScreen or (cam.CFrame.Position - site.center).Magnitude > VFXPresets.CULL
end

local function finish(site: Site)
	local mine = isMine(site)
	local lead = if mine then watch(site) else nil
	if mine and not lead and not tutorialBeat(site) and unseen(site) then
		table.insert(missed, site)
		if #missed > MISSED_MAX then
			table.remove(missed, 1)
		end
	end
	if lead and lead > 0 then
		task.delay(lead, land, site) -- the bricks wait for the camera
	else
		land(site)
	end
end

-- Still standing as it landed, and no new construction on the same model.
local function replayable(site: Site): boolean
	local drop = site.drop
	if not (drop and site.model.Parent) then
		return false
	end
	for _, other in sites do
		if other.model == site.model then
			return false
		end
	end
	for i, part in drop.parts do
		if not part.Parent or (part.Position - drop.finals[i].Position).Magnitude > 0.05 then
			return false
		end
	end
	return true
end

local replaying = false
local function replayMissed()
	if replaying then
		return
	end
	replaying = true
	while #missed > 0 do
		local site = table.remove(missed) :: Site
		if replayable(site) then
			local lead = watch(site)
			if not lead then
				table.insert(missed, site) -- not now (a menu, a call): the next step-off
				break
			end
			task.wait(lead)
			land(site)
			task.wait(holdFor(site) + WATCH_EASE + 0.3) -- the camera is home again before the next one
		end
	end
	replaying = false
end

local function reconcile()
	local marina = Workspace:FindFirstChild("Marina")
	if not marina then
		return
	end
	for i = 1, 6 do
		local plot = marina:FindFirstChild(`Plot{i}`)
		local site = sites[i]
		if plot then
			local key = plot:GetAttribute("SiteKey")
			if type(key) == "string" then
				local model = plot:FindFirstChild(`Site_{key}`) or plot:FindFirstChild(key)
				if model and model:IsA("Model") then
					local current: Site? = site
					if
						not current
						or current.model ~= model
						or current.key ~= key
						or current.plot ~= plot
					then
						if current then
							stop(current)
						end
						current = startSite(plot, model, key, player:GetAttribute("DockPlot") == i)
						sites[i] = current :: Site
					end
					if current then
						if current.prompt == nil and player:GetAttribute("DockPlot") == i then
							addFinishPrompt(current :: Site)
						end
						update(
							current :: Site,
							tonumber(plot:GetAttribute("SiteProgress")) or 0,
							tonumber(plot:GetAttribute("SiteRate")) or 1,
							tonumber(plot:GetAttribute("SiteBuilders")) or 2
						)
					end
				end
			elseif site then
				if site.model.Parent then
					finish(site) -- the site became the owned building
				else
					stop(site) -- the plot was released / streamed out
				end
				sites[i] = nil
			end
		elseif site then
			stop(site)
			sites[i] = nil
		end
	end
end

local function eye(): Vector3
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

function ConstructionController.Start()
	MarketplaceService.PromptProductPurchaseFinished:Connect(function()
		local site = sites[tonumber(player:GetAttribute("DockPlot")) or 0]
		if site and site.finish then
			site.finish.setState("buy")
		end
	end)
	task.spawn(function()
		local seated = false
		while true do
			reconcile()
			local at = eye()
			for _, site in sites do
				showNear(site, at)
			end
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local now = hum ~= nil and hum.SeatPart ~= nil
			if seated and not now and #missed > 0 then
				task.delay(0.8, replayMissed) -- off the craft and on your feet first
			end
			seated = now
			task.wait(0.25)
		end
	end)
	task.spawn(function() -- dust puffs and a tink from the nearest builders
		while true do
			local at = eye()
			local best, dist = nil, math.huge
			for _, site in sites do
				local d = (site.center - at).Magnitude
				if d < dist then
					best, dist = site, d
				end
			end
			local near: Site? = best
			if near and dist < 180 then
				-- the crane slews slowly round its mast and the hook bobs: the site is at work
				local t = os.clock()
				local turn = CFrame.Angles(0, math.sin(t * 0.3) * 0.5, 0)
				local bob = math.sin(t * 0.8) * 0.6
				for k, part in near.crane.parts do
					local lift = if k >= near.crane.bob
						then Vector3.new(0, bob, 0)
						else Vector3.zero
					TweenService:Create(
						part,
						TweenInfo.new(0.7, Enum.EasingStyle.Linear),
						{ CFrame = near.crane.pivot * turn * near.crane.offsets[k] + lift }
					):Play()
				end
				near.dust:Emit(8)
				AudioController.play(
					"Rigging_Clink_1",
					near.center + Vector3.new(0, 2, 0),
					0.35,
					0.85 + math.random() * 0.3
				)
			end
			task.wait(0.7)
		end
	end)
end

return ConstructionController
