--!strict
-- ConstructionController (docs/24 B): every island's build site, drawn from the plot's SiteKey /
-- SiteProgress / SiteRate / SiteBuilders attributes (DockService). Client-only Lego dressing round the lot
-- (fence, scaffold, a small crane, brick stacks, a sign with the bar / time / crew count); the building is the
-- server's model, its parts above the progress height hidden locally in BuildSeq's bottom-to-top order. On
-- finish the remaining bricks drop with the BuildSeq bounce, VFXKit's build_done / hq_levelup plays and the
-- fence/scaffold go away.
-- Late joiners reconcile to the same attributes, so they see the same state.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildSeq = require(Shared:WaitForChild("BuildSeq"))
local BuildTimer = require(Shared:WaitForChild("BuildTimer"))
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))

local UI = script.Parent.Parent:WaitForChild("UI")
local AudioController = require(script.Parent:WaitForChild("AudioController"))
local Kit = UI:WaitForChild("Kit")
local Style = require(Kit:WaitForChild("Style"))
local Theme = require(Kit:WaitForChild("Theme"))
local VFXKit = require(script.Parent.Parent:WaitForChild("VFX"):WaitForChild("VFXKit"))

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
	progress: number,
	ready: boolean,
	bar: Frame,
	timer: TextLabel,
	count: TextLabel,
	post: Part,
	dust: ParticleEmitter,
	prompt: ProximityPrompt?,
}

local sites: { [number]: Site } = {}
local livePrice: { [number]: number } = {}
local finishAsked: { [number]: boolean } = {}

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

-- The site's Finish prompt (the owner only): E / X / tap opens the server's tier prompt.
local function addFinishPrompt(site: Site)
	if site.prompt then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "FinishNow"
	prompt.ActionText = "Finish"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = site.post
	prompt.Triggered:Connect(function()
		Net.event("Dock_Finish"):FireServer()
	end)
	site.prompt = prompt
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

-- The site's billboard: progress bar, time left and the hammer count.
local function makeSign(st: Site, build: boolean)
	local def = if build then DockConfig.Buildings[st.key] else DockConfig.Decorations[st.key]
	local gui = Instance.new("BillboardGui")
	gui.Name = "ConstructionSign"
	gui.Size = UDim2.fromOffset(230, 92)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.MaxDistance = 260
	gui.AlwaysOnTop = false
	gui.Adornee = st.post
	gui.Parent = st.post
	local holder, face = Style.block(gui, Style.grad("ink"), { radius = 10, lip = 4 })
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
		{
			Vector3.new(-hw, 0, -hd),
			Vector3.new(hw, 0, -hd),
			Vector3.new(-hw, 0, hd),
			Vector3.new(hw, 0, hd),
		}
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
		{
			Vector3.new(-st.hw, 0, -st.hd),
			Vector3.new(st.hw, 0, -st.hd),
			Vector3.new(-st.hw, 0, st.hd),
			Vector3.new(st.hw, 0, st.hd),
		}
	do
		brick(
			props,
			"Scaffold",
			Vector3.new(0.5, 10, 0.5),
			at * CFrame.new(corner.X, 5, corner.Z),
			STEEL
		)
	end
	for _, y in { 4, 8 } do
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
	brick(props, "CraneCab", Vector3.new(2.4, 2.4, 2.4), base * CFrame.new(0, 13.6, 0), RED)
	brick(props, "CraneJib", Vector3.new(11, 0.7, 0.7), base * CFrame.new(4.5, 14.4, 0), YELLOW)
	brick(props, "CraneHook", Vector3.new(0.3, 4.5, 0.3), base * CFrame.new(9.4, 12.1, 0), GREY)
	brick(props, "CraneBlock", Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(9.4, 9.7, 0), RED)
	-- brick stacks along the front
	for n = 0, 2 do
		local stack = at * CFrame.new(-8 + n * 3.4, 0, hd + 2)
		brick(props, "Bricks", Vector3.new(2.6, 0.8, 1.2), stack * CFrame.new(0, 0.4, 0), WHITE)
		brick(props, "Bricks", Vector3.new(2.6, 0.8, 1.2), stack * CFrame.new(0, 1.2, 0), RED)
	end
	-- the sign post
	st.post =
		brick(props, "SignPost", Vector3.new(0.5, 8, 0.5), at * CFrame.new(0, 4, -hd - 1.5), GREY)
	local dust = Instance.new("Part")
	dust.Name = "Dust"
	dust.Size = Vector3.one
	dust.Transparency = 1
	dust.Anchored, dust.CanCollide, dust.CanQuery, dust.CanTouch = true, false, false, false
	dust.Position = at.Position + Vector3.new(0, 2, -st.hd)
	dust.Parent = props
	st.dust = Instance.new("ParticleEmitter")
	st.dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
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
		progress = 0,
		ready = false,
		bar = nil :: any,
		timer = nil :: any,
		count = nil :: any,
		post = nil :: any,
		dust = nil :: any,
		prompt = nil,
	}
	for part in kept do
		hide(part, site, true)
	end
	makeProps(site)
	if mine then
		addFinishPrompt(site)
	end
	makeSign(site, DockConfig.Buildings[key] ~= nil)
	return site
end

local function update(site: Site, progress: number, rate: number, builders: number)
	local p = math.clamp(progress, 0, 1)
	local cutoff = site.lo + (site.hi - site.lo) * p
	for n, part in site.parts do
		local hid = site.ys[n] > cutoff + 1e-3 -- the resting height: a part mid-drop must not hide again
		if not hid and site.hidden[part] and site.ready then
			-- a newly reached course drops into place with a short Lego bounce
			local final = part.CFrame
			hide(part, site, false)
			part.CFrame = final + Vector3.new(0, 2, 0)
			TweenService:Create(
				part,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ CFrame = final }
			):Play()
		else
			hide(part, site, hid)
		end
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
	if site.prompt then
		local product, price = finishProduct(left)
		site.prompt.Enabled = left >= 3 and finishOffered(product)
		site.prompt.ObjectText = `R$ {price}`
	end
end

local function stop(site: Site)
	if site.model.Parent then
		for part in site.hidden do
			hide(part, site, false)
		end
	end
	site.props:Destroy()
end

-- The last bricks drop with the BuildSeq bounce, a Lego clack and confetti as they land (your HQ: a fanfare too).
local function finish(site: Site)
	local parts, ys = {}, {}
	for part in site.kept do
		hide(part, site, false) -- already standing: no drop
	end
	for part in site.hidden do
		table.insert(parts, part)
		table.insert(ys, part.CFrame.Y)
	end
	local finals = {}
	for i, part in parts do
		finals[i] = part.CFrame
	end
	for _, part in parts do
		hide(part, site, false)
	end
	local plan = BuildSeq.plan(ys, math.random(0, 1_000_000))
	local last = 0
	for _, step in plan do
		last = math.max(last, step.delay)
		local part = parts[step.i]
		part.CFrame = finals[step.i] + Vector3.new(0, step.drop, 0)
		TweenService:Create(
			part,
			TweenInfo.new(
				0.45,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In,
				0,
				false,
				step.delay
			),
			{ CFrame = finals[step.i] }
		):Play()
	end
	local top =
		Vector3.new(site.center.X, site.ground + (site.maxY - site.minY) * 0.6, site.center.Z)
	local mine = site.plot.Name == `Plot{player:GetAttribute("DockPlot")}`
	local hq = site.key == "HQ" and mine
	-- the last brick clacks home (a plastic snap, two quick hits), then the confetti; your HQ gets the big beat
	task.delay(last + 0.45, function()
		AudioController.play("Album_Sticker", top, 1, 1.5)
		task.delay(0.07, function()
			AudioController.play("UI_Click", top, 3, 0.75)
		end)
		-- docs/26 FX1: a studded ring and plates race out low, rays and confetti only above the roof (never on the
		-- building); your HQ gets the charge, the white-hot core and the light pillar
		local base = CFrame.new(site.center.X, site.ground, site.center.Z)
		local fx = {
			radius = math.max(site.hw, site.hd) + 1,
			height = site.maxY - site.ground + 4,
			still = not mine,
		}
		VFXKit.play(if hq then "fx1_hq_levelup" else "fx1_build_snap", base, fx)
		if hq then
			task.delay(0.5, AudioController.play, "Music_CrateFanfare", nil, 1, 1) -- on the impact (HQ_AT)
		end
	end)
	site.props:Destroy()
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
	task.spawn(function()
		while true do
			reconcile()
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
