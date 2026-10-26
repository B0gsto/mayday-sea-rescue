--!strict
-- WorkerController (WP-26): draws the WorkerBadge billboard (category icon + rarity stars, legendary glow) on
-- every model tagged "WorkerBadge" (a picked-up survivor), and plays the offline
-- earnings welcome: a coin burst into the wallet and a Toast when the player attribute WorkerOffline arrives.
-- It also draws every island's workers, client-side only: the server publishes them as data
-- (ReplicatedStorage.Workers.<owner>.<i>, WorkerService) and this clones a shared R15 template
-- (ReplicatedStorage.WorkerRigs) into Workspace.WorkersLocal for each one within NEAR studs of you, drops it
-- past FAR, animates it only within LIVELY (a still pose beyond), and walks it along a cached
-- PathfindingService route when its Spot changes (a new recruit walks in from the jetty). At their building each
-- Job loops a stock animation with a small code-built prop (docs/24 C): Build hammers, Fish carries a crate,
-- Repair turns a wrench, Rescue scans with binoculars, Heal holds a clipboard, Gather saws, Idle stands. Workers
-- waiting on the jetty keep their category badge (they are not at work). Gatherer/Rescuer pay pops a "+$".
-- Each yard shows one crew badge (icon + count) instead of one per worker.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local UI = script.Parent.Parent:WaitForChild("UI")
local CashBurst = require(UI:WaitForChild("CashBurst"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local Toast = require(UI:WaitForChild("Kit"):WaitForChild("Toast"))
local WorkerBadge = require(UI:WaitForChild("WorkerBadge"))

local WorkerController = {}

local player = Players.LocalPlayer

local NEAR, FAR = 200, 240 -- studs from you: a rig is made within NEAR, dropped beyond FAR
local LIVELY = 90 -- animated within this (the badge shows within 60)
local WALK_SPEED = 9 -- studs/s
local MAKE_PER_TICK = 8 -- rigs cloned per 0.25 s pass (no hitch when you land on a full island)
local ANIM_IDS: { [string]: string } = { -- stock R15 animations (the default Animate script's)
	Idle = "rbxassetid://507766666",
	Walk = "rbxassetid://507777826",
	Swing = "rbxassetid://522635514", -- toolslash, looped slow: hammering / sawing / wrenching
	Point = "rbxassetid://507770453", -- point: binoculars / clipboard read
}
-- Jobs (docs/24 C) and their held prop. A worker with no Job attribute falls back to its category.
local JOBS: { [string]: { anim: string?, prop: string? } } = {
	Build = { anim = "Swing", prop = "Hammer" },
	Fish = { prop = "Crate" },
	Repair = { anim = "Swing", prop = "Wrench" },
	Rescue = { anim = "Point", prop = "Binoculars" },
	Heal = { anim = "Point", prop = "Clipboard" },
	Gather = { anim = "Swing", prop = "Saw" },
	Idle = {},
}
local CATEGORY_JOB = {
	Builder = "Build",
	Gatherer = "Fish",
	Mechanic = "Repair",
	Rescuer = "Rescue",
	Medic = "Heal",
}

type Rec = {
	cfg: Configuration,
	feet: CFrame, -- where the worker stands (or is headed, once culled)
	rig: Model?,
	height: number,
	loaded: { [string]: AnimationTrack },
	lively: boolean,
	walking: {}?, -- the running walk's token
	carry: ("walk" | "rest")?, -- a Gatherer's crate loop, while it runs
}

local anims: { [string]: Animation } = {} -- one Animation per id, shared by every rig
for name, id in ANIM_IDS do
	local a = Instance.new("Animation")
	a.AnimationId = id
	anims[name] = a
end
local recs: { [Configuration]: Rec } = {}
local localFolder: Folder? = nil

local function eye(): Vector3
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end
	local cam = Workspace.CurrentCamera
	return if cam then cam.CFrame.Position else Vector3.zero
end

local function jobOf(r: Rec): string?
	local job = r.cfg:GetAttribute("Job")
	if type(job) == "string" and JOBS[job] then
		return job
	end
	local category = r.cfg:GetAttribute("WorkerCategory")
	return if type(category) == "string" then CATEGORY_JOB[category] else nil
end

local function work(r: Rec): { anim: string?, prop: string? }?
	if r.cfg:GetAttribute("Work") ~= true then
		return nil
	end
	local job = jobOf(r)
	return job and JOBS[job]
end

-- Plays the tracks the worker should show now (none when far or culled); tracks load once per rig.
local function pose(r: Rec)
	local want: { [string]: boolean } = {}
	if r.rig and r.lively then
		if r.walking or r.carry == "walk" then
			want.Walk = true
		else
			want.Idle = true
			local w = work(r)
			if w and w.anim then
				want[w.anim] = true
			end
		end
	end
	for name, track in r.loaded do
		if track.IsPlaying and not want[name] then
			track:Stop(0.2)
		end
	end
	local hum = r.rig and r.rig:FindFirstChildOfClass("Humanoid")
	if not hum or next(want) == nil then
		return
	end
	local animator: Animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animator.Parent = hum
	for name in want do
		local track = r.loaded[name] or animator:LoadAnimation(anims[name])
		if r.loaded[name] ~= track then
			track.Looped = true
			r.loaded[name] = track
		end
		if not track.IsPlaying then
			track:Play(0.2)
			track:AdjustSpeed(if name == "Swing" then 0.45 else 1)
		end
	end
end

local function brick(name: string, size: Vector3, color: Color3, to: BasePart, c0: CFrame): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
	p:SetAttribute("WorkProp", true)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = to, p, c0
	w.Parent = p
	p.Parent = to
	return p
end

-- The work prop (hammer, wrench, crate) while at their building, none on the jetty.
local function dress(r: Rec)
	local rig = r.rig
	if not rig then
		return
	end
	local w = work(r)
	local want = w and w.prop
	for _, d in rig:GetDescendants() do
		if d:GetAttribute("WorkProp") and not (want and string.sub(d.Name, 1, #want) == want) then
			d:Destroy()
		end
	end
	local hand = rig:FindFirstChild("RightHand")
	local torso = rig:FindFirstChild("UpperTorso")
	if not want or rig:FindFirstChild(want, true) or not (hand and hand:IsA("BasePart")) then
		return
	end
	local grip = hand:FindFirstChild("RightGripAttachment")
	local g = if grip and grip:IsA("Attachment") then grip.CFrame else CFrame.new(0, -0.3, 0)
	if want == "Crate" then -- on the right shoulder
		if torso and torso:IsA("BasePart") then
			brick(
				want,
				Vector3.new(1.4, 1.1, 1.4),
				Color3.fromRGB(242, 140, 30),
				torso,
				CFrame.new(0.7, 1.35, 0.1)
			)
		end
	elseif want == "Saw" then -- a handle and a flat blade
		brick(
			want,
			Vector3.new(0.3, 1.2, 0.3),
			Color3.fromRGB(224, 56, 40),
			hand,
			g * CFrame.new(0, 0.4, 0)
		)
		brick(
			`{want}Blade`,
			Vector3.new(0.16, 1.8, 0.85),
			Color3.fromRGB(200, 205, 214),
			hand,
			g * CFrame.new(0, 1.1, 0.1)
		)
	elseif want == "Binoculars" then -- two barrels on a bridge, held up to the face by Point
		for _, x in { -0.26, 0.26 } do
			local barrel = brick(
				want,
				Vector3.new(1.1, 0.38, 0.38),
				Color3.fromRGB(52, 58, 70),
				hand,
				g * CFrame.new(x, 0.9, -0.1) * CFrame.Angles(0, math.pi / 2, 0)
			)
			barrel.Shape = Enum.PartType.Cylinder
		end
		brick(
			`{want}Bridge`,
			Vector3.new(0.5, 0.22, 0.22),
			Color3.fromRGB(90, 96, 110),
			hand,
			g * CFrame.new(0, 0.9, 0.3)
		)
	elseif want == "Clipboard" then -- a board and a paper sheet
		brick(
			want,
			Vector3.new(0.16, 1.4, 1.8),
			Color3.fromRGB(105, 64, 40),
			hand,
			g * CFrame.new(0.35, 0.7, 0)
		)
		brick(
			`{want}Paper`,
			Vector3.new(0.18, 1.1, 1.4),
			Color3.fromRGB(242, 240, 232),
			hand,
			g * CFrame.new(0.26, 0.7, 0)
		)
	else -- hammer / wrench: the handle out of the fist, the head at its end
		local hammer = want == "Hammer"
		local handle = if hammer then Color3.fromRGB(250, 208, 40) else Color3.fromRGB(224, 56, 40)
		local head = if hammer then Color3.fromRGB(90, 96, 110) else Color3.fromRGB(200, 205, 214)
		brick(want, Vector3.new(0.25, 1.5, 0.25), handle, hand, g * CFrame.new(0, 0.55, 0))
		brick(`{want}Head`, Vector3.new(0.45, 0.4, 0.9), head, hand, g * CFrame.new(0, 1.3, 0))
	end
end

local function place(r: Rec)
	local rig = r.rig
	if rig then
		rig:PivotTo(r.feet * CFrame.new(0, r.height, 0))
	end
end

local function makeRig(r: Rec): boolean
	local rigs = ReplicatedStorage:FindFirstChild("WorkerRigs")
	local tpl = rigs and rigs:FindFirstChild(tostring(r.cfg:GetAttribute("Rig")))
	if not (tpl and tpl:IsA("Model")) then
		return false -- the server is still building the templates
	end
	local rig = tpl:Clone()
	r.height = tonumber(tpl:GetAttribute("RootHeight")) or 3
	r.loaded = {}
	for _, key in { "WorkerCategory", "WorkerRarity", "WorkerName" } do
		rig:SetAttribute(key, r.cfg:GetAttribute(key))
	end
	r.rig = rig
	place(r)
	dress(r)
	rig.Parent = localFolder
	pose(r)
	return true
end

local function dropRig(r: Rec)
	if r.rig then
		r.rig:Destroy()
		r.rig = nil
		r.loaded = {}
	end
	r.walking = nil
end

-- shortcut: routes are cached 30 s by 4-stud cells, so a building placed meanwhile is walked through until then
local routes: { [string]: { at: number, points: { Vector3 } } } = {}
local function route(a: Vector3, b: Vector3): { Vector3 }
	local key = `{a.X // 4},{a.Z // 4}>{b.X // 4},{b.Z // 4}`
	local hit = routes[key]
	if hit and os.clock() - hit.at < 30 then
		return hit.points
	end
	local points = { b }
	local path = PathfindingService:CreatePath({
		AgentRadius = 1.5,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 12,
	})
	local ok = pcall(function()
		path:ComputeAsync(a, b)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		points = {}
		for _, wp in path:GetWaypoints() do
			table.insert(points, wp.Position)
		end
		points[math.max(#points, 1)] = b
	end -- no route (plate not streamed in, odd geometry): a straight line
	routes[key] = { at = os.clock(), points = points }
	return points
end

-- Steps the rig's root from where it is to the feet CFrame `to`, facing the way it goes; yields.
local function stride(r: Rec, root: BasePart, to: Vector3)
	local target = to + Vector3.new(0, r.height, 0)
	local at = root.Position
	if (target - at).Magnitude <= 0.5 then
		return
	end
	local flat = Vector3.new(target.X - at.X, 0, target.Z - at.Z)
	-- straight up / down: keep facing (lookAt on the same point is NaN)
	local face = if flat.Magnitude > 0.05
		then CFrame.lookAt(Vector3.zero, flat).Rotation
		else root.CFrame.Rotation
	root.CFrame = CFrame.new(at) * face
	local tween = TweenService:Create(
		root,
		TweenInfo.new((target - at).Magnitude / WALK_SPEED, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(target) * face }
	)
	tween:Play()
	tween.Completed:Wait()
end

-- A Gatherer at its stall paces with crates along the counter and back, a short rest at each end, while near.
local function carry(r: Rec)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	if not (rig and root) then
		return
	end
	local legs = { r.feet * CFrame.new(-2.2, 0, 0), r.feet * CFrame.new(2.2, 0, 0) } -- along the stall counter
	local function on(): boolean
		return r.rig == rig and r.lively and not r.walking and jobOf(r) == "Fish"
	end
	r.carry = "rest"
	task.spawn(function()
		local i = 0
		while on() do
			i = i % 2 + 1
			r.carry = "walk"
			pose(r)
			stride(r, root, legs[i].Position)
			if not on() then
				break
			end
			r.carry = "rest"
			pose(r)
			task.wait(0.6 + math.random() * 0.8) -- uneven, so a crew never paces in step
		end
		r.carry = nil
		if r.rig == rig and not r.walking then
			place(r)
			pose(r)
		end
	end)
end

-- Walks the rig from where it is to `to` (feet) along a route; culled or far, it is just there.
local function walkTo(r: Rec, to: CFrame)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	if not (rig and root and r.lively) then
		r.walking = nil
		r.feet = to
		place(r)
		dress(r)
		pose(r)
		return
	end
	local token = {}
	r.walking = token
	dress(r)
	pose(r)
	task.spawn(function()
		for _, p in route(r.feet.Position, to.Position) do
			stride(r, root, p)
			if r.walking ~= token or r.rig ~= rig then
				return -- a newer walk took over, or the rig was culled (its feet are set)
			end
			r.feet = CFrame.new(p) * root.CFrame.Rotation
		end
		r.walking = nil
		r.feet = to
		place(r)
		dress(r)
		pose(r)
	end)
end

local function track(cfg: Instance)
	if not cfg:IsA("Configuration") or recs[cfg] then
		return
	end
	local spot = cfg:GetAttribute("Spot")
	if typeof(spot) ~= "CFrame" then
		return
	end
	local from = cfg:GetAttribute("From")
	local r: Rec = {
		cfg = cfg,
		feet = if typeof(from) == "CFrame" then from else spot,
		height = 3,
		loaded = {},
		lively = false,
	}
	recs[cfg] = r
	cfg:GetAttributeChangedSignal("Spot"):Connect(function()
		local to = cfg:GetAttribute("Spot")
		if typeof(to) == "CFrame" then
			walkTo(r, to)
		end
	end)
	cfg:GetAttributeChangedSignal("Work"):Connect(function()
		if not r.walking then -- a walk dresses on arrival
			dress(r)
			pose(r)
		end
	end)
	cfg:GetAttributeChangedSignal("Job")
		:Connect(function() -- a job swap with Work already true: new prop + loop
			if not r.walking then
				dress(r)
				pose(r)
			end
		end)
end

local function untrack(cfg: Instance)
	local r = if cfg:IsA("Configuration") then recs[cfg] else nil
	if r then
		recs[r.cfg] = nil
		dropRig(r)
	end
end

-- The cull / LOD pass: makes and drops rigs by distance, stills far ones, starts a recruit's walk in.
local function cullPass()
	local at = eye()
	local made = 0
	for cfg, r in recs do
		local d = (r.feet.Position - at).Magnitude
		if r.rig and d > FAR then
			dropRig(r)
			local spot = cfg:GetAttribute("Spot")
			r.feet = if typeof(spot) == "CFrame" then spot else r.feet
		elseif not r.rig and d < NEAR and made < MAKE_PER_TICK then
			r.lively = d < LIVELY
			if makeRig(r) then
				made += 1
				local spot = cfg:GetAttribute("Spot")
				if typeof(spot) == "CFrame" and spot ~= r.feet then
					walkTo(r, spot) -- a new recruit: from the jetty to their spot
				end
			end
		end
		local lively = r.rig ~= nil and d < (if r.lively then LIVELY + 15 else LIVELY)
		if lively ~= r.lively then
			r.lively = lively
			pose(r)
		end
		if r.lively and not r.walking and not r.carry and jobOf(r) == "Fish" then
			carry(r)
		end
	end
end

-- One badge per yard (one owner + category) over the middle of its settled crew, count when 2+: five badges
-- stacked over one stall was noise (docs/24 C art r2). WorkerBadge.crew's MaxDistance keeps it near-only.
local crews: { [string]: { gui: BillboardGui, at: Attachment } } = {}
local function crewPass()
	local groups: { [string]: { cat: string, sum: Vector3, rigs: { Model } } } = {}
	for cfg, r in recs do
		local cat = cfg:GetAttribute("WorkerCategory")
		if r.rig and not r.walking and work(r) and type(cat) == "string" then
			local key = `{cfg.Parent and cfg.Parent.Name}/{cat}`
			local g = groups[key] or { cat = cat, sum = Vector3.zero, rigs = {} }
			groups[key] = g
			g.sum += r.feet.Position
			table.insert(g.rigs, r.rig)
		end
	end
	for key, g in groups do
		local c = crews[key]
		if not c then
			local at = Instance.new("Attachment")
			at.Name = "CrewTag"
			at.Parent = Workspace.Terrain
			c = { at = at, gui = WorkerBadge.crew(at, g.cat, localFolder :: Folder) }
			crews[key] = c
		end
		local crew = c :: { gui: BillboardGui, at: Attachment }
		crew.at.WorldPosition = g.sum / #g.rigs + Vector3.new(0, 7.5, 0)
		local count = crew.gui:FindFirstChild("Count") :: TextLabel
		count.Text = if #g.rigs > 1 then `x{#g.rigs}` else ""
	end
	for key, c in crews do
		if not groups[key] then
			c.gui:Destroy()
			c.at:Destroy()
			crews[key] = nil
		end
	end
end

-- docs/24 C: a small "+$" over the worker when the server pays its category (client only)
local function popCash(r: Rec)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	if not (rig and root) then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "PayPop"
	gui.Adornee = root
	gui.Size = UDim2.fromOffset(48, 28)
	gui.StudsOffset = Vector3.new(0, 4.8, 0)
	gui.MaxDistance = 80
	gui.LightInfluence = 0
	gui.Parent = rig
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 214, 60)
	label.TextStrokeTransparency = 0
	label.Text = "+$"
	label.Parent = gui
	TweenService:Create(
		gui,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, 7.6, 0) }
	):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		gui:Destroy()
	end)
end

-- the local player's workers of one category pop the paid mark
local function paid(category: string)
	for cfg, r in recs do
		if r.rig and work(r) and cfg.Parent and cfg.Parent.Name == tostring(player.UserId) then
			if cfg:GetAttribute("WorkerCategory") == category and not r.walking then
				popCash(r)
			end
		end
	end
end

local function badge(inst: Instance)
	if not inst:IsA("Model") then
		return
	end
	-- the rig may stream in after the tag: retry briefly
	task.spawn(function()
		for _ = 1, 20 do
			if inst.Parent == nil or inst:FindFirstChild("WorkerTag") then
				return
			end
			WorkerBadge.billboard(inst)
			task.wait(0.5)
		end
	end)
end

local shown = false -- once a session (the server sets it once)
local function welcome()
	local pay = player:GetAttribute("WorkerOffline")
	if shown or type(pay) ~= "number" or pay <= 0 then
		return
	end
	-- the pay lands on join, under the loading screen and its flyover (playtest 2: the toast was gone by then);
	-- these attributes clearing calls this again
	if
		player:GetAttribute("LoadingScreenActive") == true
		or player:GetAttribute("CinematicPlaying") == true
	then
		return
	end
	shown = true
	local gui = Instance.new("ScreenGui")
	gui.Name = "WorkerWelcome"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 40
	gui.Parent = player:WaitForChild("PlayerGui")
	Toast.show(Style.canvas(gui), `+{pay}`, { icon = "cash", color = "green", duration = 6 })
	local camera = Workspace.CurrentCamera
	if camera then
		CashBurst.playAt(
			gui.Parent :: Instance,
			camera.ViewportSize * Vector2.new(0.5, 0.3),
			pay,
			false
		)
	end
	task.delay(8, function()
		gui:Destroy()
	end)
end

function WorkerController.Start()
	CollectionService:GetInstanceAddedSignal("WorkerBadge"):Connect(badge)
	for _, inst in CollectionService:GetTagged("WorkerBadge") do
		badge(inst)
	end
	for _, name in { "WorkerOffline", "LoadingScreenActive", "CinematicPlaying" } do
		player:GetAttributeChangedSignal(name):Connect(welcome)
	end
	Net.event("PlayerDataChanged").OnClientEvent:Connect(function(data: any)
		local award = data and data.award
		if type(award) ~= "table" then
			return
		end
		if award.reason == "Workers:Gather" then
			paid("Gatherer")
		elseif award.reason == "Workers:Rescue" then
			paid("Rescuer")
		end
	end)
	task.delay(4, welcome) -- set before this ran: wait for the HUD to be up
	local f = Instance.new("Folder")
	f.Name = "WorkersLocal"
	f.Parent = Workspace
	localFolder = f
	local root = ReplicatedStorage:WaitForChild("Workers")
	root.DescendantAdded:Connect(track)
	root.DescendantRemoving:Connect(untrack)
	for _, d in root:GetDescendants() do
		track(d)
	end
	while true do
		cullPass()
		crewPass()
		task.wait(0.25)
	end
end

return WorkerController
