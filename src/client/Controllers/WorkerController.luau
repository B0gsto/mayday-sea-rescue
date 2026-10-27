--!strict
-- WorkerController (WP-26, docs/25 J): draws every island's workers, client-side only. The server publishes
-- them as data (ReplicatedStorage.Workers.<owner>.<i>, WorkerService) and this clones a shared R15 template
-- (ReplicatedStorage.WorkerRigs) into Workspace.WorkersLocal for each one within NEAR studs of you, drops it
-- past FAR, animates it only within LIVELY (a still pose beyond), and walks it along a cached
-- PathfindingService route when its Spot changes (a new recruit walks in from the jetty). At their building each
-- Job loops 2-3 beats of a stock animation with a small code-built prop (WorkLoop, docs/25 G): Build hammers, Fish
-- serves at the counter, hauls a net and carries a crate back, Repair wrenches round the hull, Rescue scans with
-- binoculars and checks the boat, Heal walks the beds with a clipboard, Gather saws, Idle stands; holds and walk
-- speeds vary per worker so a crew never moves in step. Day/night (DayClock moves Lighting.ClockTime): from dusk
-- (WorkLoop.isHome, each a little late) survivors down tools, walk in through the Bunkhouse door (else the Rescue
-- Hut's) and hide till dawn, then walk back out to their spots (far ones just appear / vanish). At night
-- (WorkLoop.isNight) each Bunkhouse floor gets a warm PointLight, the roof a "Zzz", and the NightLamp lamps light. With the
-- uploaded Depot standing (docs/25 D, K4) Haulers push a crate cart barge -> pile and a site's Builders carry brick
-- stacks over their heads pile -> site, paced by HaulRate / CarryRate, waiting at the pile while SiteWaiting. Every
-- rig gets its rarity name tag and info card (SurvivorController); each yard shows one crew badge (icon + count)
-- instead of one per worker. Gatherer/Rescuer pay pops a "+$". It also plays the offline earnings welcome: a
-- coin burst into the wallet and a Toast when the player attribute WorkerOffline arrives.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DockConfig = require(Shared:WaitForChild("Config"):WaitForChild("DockConfig"))
local Marina = require(Shared:WaitForChild("Marina"))
local Net = require(Shared:WaitForChild("Net"))
local WorkLoop = require(Shared:WaitForChild("WorkLoop"))
local UI = script.Parent.Parent:WaitForChild("UI")
local CashBurst = require(UI:WaitForChild("CashBurst"))
local DepotController = require(script.Parent:WaitForChild("DepotController"))
local Style = require(UI:WaitForChild("Kit"):WaitForChild("Style"))
local SurvivorController = require(script.Parent:WaitForChild("SurvivorController"))
local Toast = require(UI:WaitForChild("Kit"):WaitForChild("Toast"))
local WorkerBadge = require(UI:WaitForChild("WorkerBadge"))

local WorkerController = {}

local player = Players.LocalPlayer

local NEAR, FAR = 200, 240 -- studs from you: a rig is made within NEAR, dropped beyond FAR
local LIVELY = 90 -- animated within this (the yard crew badge shows within 60)
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
	Haul = { prop = "Cart" },
	Idle = {},
}
local CATEGORY_JOB = {
	Builder = "Build",
	Gatherer = "Fish",
	Mechanic = "Repair",
	Rescuer = "Rescue",
	Medic = "Heal",
	Hauler = "Haul",
}

type Rec = {
	cfg: Configuration,
	feet: CFrame, -- where the worker stands (or is headed, once culled)
	rig: Model?,
	height: number,
	loaded: { [string]: AnimationTrack },
	lively: boolean,
	walking: {}?, -- the running walk's token
	carry: ("walk" | "rest")?, -- a work / haul / carry loop, while it runs
	beat: WorkLoop.Beat?, -- the work loop's beat now (its anim and prop)
	beatI: number?, -- the last beat played; nil until the first loop (which starts late, out of step)
	speed: number, -- walk studs/s
	sleep: boolean?, -- home for the night (walking there, or in and hidden)
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

-- K1 calls it Category; WP-26 called it WorkerCategory. Read either, so the client outlives the migration.
local function categoryOf(cfg: Configuration): string?
	local category = cfg:GetAttribute("Category")
	if type(category) == "string" then
		return category
	end
	local legacy = cfg:GetAttribute("WorkerCategory")
	return if type(legacy) == "string" then legacy else nil
end

local function jobOf(r: Rec): string?
	local job = r.cfg:GetAttribute("Job")
	if type(job) == "string" and JOBS[job] then
		return job
	end
	local category = categoryOf(r.cfg)
	return if category then CATEGORY_JOB[category] else nil
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
			local anim = if r.beat then r.beat.anim else w and w.anim
			if w and anim then
				want[anim] = true
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
		end
		track:AdjustSpeed(r.beat and r.beat.speed or if name == "Swing" then 0.45 else 1)
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
	if w and r.beat and r.beat.prop then
		want = if r.beat.prop == "" then nil else r.beat.prop
	end
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
	local root = rig.PrimaryPart
	if want == "Cart" and root then -- a hand cart pushed in front: a deck on two wheels, handles back to the hands
		brick(
			want,
			Vector3.new(2.2, 0.3, 2),
			Color3.fromRGB(105, 64, 40),
			root,
			CFrame.new(0, -1.6, -2.4)
		)
		for _, x in { -1.25, 1.25 } do
			local wheel = brick(
				`{want}Wheel`,
				Vector3.new(0.35, 1.2, 1.2),
				Color3.fromRGB(30, 34, 40),
				root,
				CFrame.new(x, -2.4, -2.4)
			)
			wheel.Shape = Enum.PartType.Cylinder
			brick(
				`{want}Handle`,
				Vector3.new(0.2, 0.2, 1.6),
				Color3.fromRGB(250, 208, 40),
				root,
				CFrame.new(x * 0.6, -1.0, -1.0) * CFrame.Angles(math.rad(-40), 0, 0)
			)
		end
		local load = brick( -- shown while loaded (cargo)
			`{want}Crate`,
			Vector3.new(1.6, 1.3, 1.6),
			Color3.fromRGB(242, 140, 30),
			root,
			CFrame.new(0, -0.8, -2.4)
		)
		load.Transparency = 1
	elseif want == "Crate" then -- on the right shoulder
		if torso and torso:IsA("BasePart") then
			brick(
				want,
				Vector3.new(1.4, 1.1, 1.4),
				Color3.fromRGB(242, 140, 30),
				torso,
				CFrame.new(0.7, 1.35, 0.1)
			)
		end
	elseif want == "Net" then -- a bundled net with a float, hauled in hand over hand
		brick(
			want,
			Vector3.new(1.1, 0.8, 1.1),
			Color3.fromRGB(40, 120, 90),
			hand,
			g * CFrame.new(0, 0, -0.4)
		)
		brick(
			`{want}Float`,
			Vector3.new(0.5, 0.5, 0.5),
			Color3.fromRGB(242, 140, 30),
			hand,
			g * CFrame.new(0, 0.55, -0.4)
		)
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
	-- K1 properties (plus the WP-26 names while the server migrates) drive the tag and the info card
	for _, key in
		{
			"SurvivorName",
			"Rarity",
			"Category",
			"Trait",
			"Special",
			"Workplace",
			"Job",
			"WorkerCategory",
			"WorkerRarity",
			"WorkerName",
			"Rig",
		}
	do
		rig:SetAttribute(key, r.cfg:GetAttribute(key))
	end
	r.rig = rig
	place(r)
	dress(r)
	rig.Parent = localFolder
	SurvivorController.attach(rig)
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
	r.beat = nil
end

-- shortcut: routes are cached 30 s by the start's 16-stud cell and the goal's 4-stud cell (a dusk crowd heading to one
-- door shares a route), so a building placed meanwhile is walked through until then
local ROUTE_TTL = 30
local routes: { [string]: { at: number, points: { Vector3 } } } = {}
local function route(a: Vector3, b: Vector3): { Vector3 }
	local key = `{a.X // 16},{a.Z // 16}>{b.X // 4},{b.Z // 4}`
	local hit = routes[key]
	local now = os.clock()
	if hit and now - hit.at < ROUTE_TTL then
		return hit.points
	end
	for k, old in routes do -- a miss costs a ComputeAsync anyway: drop the stale ones
		if now - old.at >= ROUTE_TTL then
			routes[k] = nil
		end
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
		TweenInfo.new((target - at).Magnitude / r.speed, Enum.EasingStyle.Linear),
		{ CFrame = CFrame.new(target) * face }
	)
	tween:Play()
	tween.Completed:Wait()
end

-- docs/25 D flows 1 and 2: one leg after another (a route per leg); false when the loop should stop
local function legs(r: Rec, root: BasePart, points: { Vector3 }, on: () -> boolean): boolean
	r.carry = "walk"
	pose(r)
	for _, p in points do
		stride(r, root, p)
		if not on() then
			return false
		end
	end
	r.carry = "rest"
	pose(r)
	return true
end

local function feetOf(r: Rec, root: BasePart): Vector3
	return root.Position - Vector3.new(0, r.height, 0)
end

local function seedOf(cfg: Configuration): number
	return (tonumber(cfg.Parent and cfg.Parent.Name) or 0) + (tonumber(cfg.Name) or 0) * 131
end

-- One pass of the worker's WorkLoop beats at its Spot (cullPass starts the next, so a Builder's site or a Depot
-- that stands up meanwhile takes over); short straight steps inside the building, no route.
local function loop(r: Rec)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	local job = jobOf(r)
	local beats = job and WorkLoop.BEATS[job]
	local function on(): boolean
		return r.rig == rig and r.lively and not r.walking and jobOf(r) == job and work(r) ~= nil
	end
	if not (rig and root and beats and on()) then
		return
	end
	local seed = seedOf(r.cfg)
	local home = r.feet
	local pivot = (home * CFrame.new(0, 0, -WorkLoop.PIVOT)).Position
	r.carry = "rest"
	task.spawn(function()
		if not r.beatI then
			r.beatI = seed % #beats
			task.wait(WorkLoop.jitter(seed, 0) * 2 - 1.4) -- the crew starts out of step
		end
		for _ = 1, #beats do
			if not on() then
				break
			end
			local i = (r.beatI :: number) % #beats + 1
			r.beatI = i
			local b = beats[i]
			r.beat = b
			dress(r)
			local to = (home * CFrame.new(b.side or 0, 0, b.back or 0)).Position
			if (to - feetOf(r, root)).Magnitude > 0.3 then
				r.carry = "walk"
				pose(r)
				stride(r, root, to)
				if not on() then
					break
				end
			end
			local flat = Vector3.new(pivot.X - to.X, 0, pivot.Z - to.Z)
			root.CFrame = CFrame.new(root.Position)
				* (
					if flat.Magnitude > 0.05
						then CFrame.lookAt(Vector3.zero, flat).Rotation
						else home.Rotation
				)
			r.carry = "rest"
			pose(r)
			task.wait(b.hold * WorkLoop.jitter(seed, i))
		end
		r.carry = nil
		if r.rig == rig and not r.walking and not on() then
			r.beat = nil
			place(r)
			dress(r)
			pose(r)
		end
	end)
end

local function ownerPlot(r: Rec): Model?
	local id = r.cfg.Parent and tonumber(r.cfg.Parent.Name)
	return if id then DepotController.plotOf(id) else nil
end

-- docs/25 G: where a plot's survivors sleep: 3 studs in through the Bunkhouse door (its mesh's ATT_Door_01, else the
-- lot's front edge), else the Rescue Hut's; nil with neither. Cached per building instance, so a Bunkhouse built or
-- upgraded mid-night (a new model) moves it.
local doors: { [Model]: { by: Instance, at: CFrame } } = {}
local function doorOf(r: Rec): CFrame?
	local plot = ownerPlot(r)
	local b = plot and (plot:FindFirstChild("Bunkhouse") or plot:FindFirstChild("HQ"))
	if not (plot and b) then
		return nil
	end
	local hit = doors[plot]
	if hit and hit.by == b then
		return hit.at
	end
	local def = DockConfig.Buildings[b.Name]
	local i = tonumber(string.match(plot.Name, "^Plot(%d+)$"))
	if not (def and i) then
		return nil
	end
	local lot = Marina.berth(i) * def.spot
	local att = b:FindFirstChild("ATT_Door_01", true)
	local door = if att and att:IsA("Attachment")
		then att.WorldPosition
		else (lot * CFrame.new(0, 0, -def.size.Y / 2)).Position
	local inward = Vector3.new(lot.X - door.X, 0, lot.Z - door.Z)
	local at = if inward.Magnitude > 0.1
		then CFrame.lookAt(door, door + inward) * CFrame.new(0, 0, -3)
		else CFrame.new(door)
	doors[plot] = { by = b, at = at }
	return at
end

-- seconds a worker rests after a trip so `crew` of them make `perMinute` trips a minute (K4 HaulRate / CarryRate)
local function rest(perMinute: any, crew: number, walked: number): number
	if type(perMinute) ~= "number" or perMinute <= 0 then
		return 2
	end
	return math.clamp(60 * crew / perMinute - walked, 1, 20)
end

local function crewOf(r: Rec, job: string): number
	local n = 0
	for cfg, o in recs do
		if cfg.Parent == r.cfg.Parent and o.rig and jobOf(o) == job then
			n += 1
		end
	end
	return math.max(n, 1)
end

-- A Hauler: from the pile to the quay, waits for the barge, pushes a crate up to a drop-off bay, rests, again.
local function haul(r: Rec)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	local plot = ownerPlot(r)
	local function on(): boolean
		return r.rig == rig
			and r.lively
			and not r.walking
			and jobOf(r) == "Haul"
			and work(r) ~= nil
			and DepotController.depot(plot :: Model) ~= nil
	end
	if not (rig and root and plot and on()) then
		return
	end
	local slot = (tonumber(r.cfg.Name) or 0) % 4 - 1.5 -- side by side along the quay
	r.carry = "rest"
	r.beat = nil
	dress(r)
	task.spawn(function()
		local trip = tonumber(r.cfg.Name) or 0
		while on() do
			local depot = DepotController.depot(plot :: Model) :: Model
			local land = DepotController.mark(depot, "ATT_QuayLand")
			local load = DepotController.mark(depot, "ATT_QuayLoad")
			local drops = DepotController.marks(depot, "ATT_DropOff_")
			if not (land and load and #drops > 0) then
				break
			end
			trip += 1
			local drop = drops[trip % #drops + 1].Position
			local cart = rig:FindFirstChild("CartCrate", true) :: BasePart?
			local start = os.clock()
			local quay = load.Position + load.LookVector * slot * 3
			local out = table.clone(route(feetOf(r, root), land.Position)) -- route's tables are its cache
			table.insert(out, quay)
			if not legs(r, root, out, on) then
				break
			end
			while on() and not DepotController.moored(plot :: Model) do
				task.wait(0.5)
			end
			if not on() then
				break
			end
			task.wait(1) -- the crate swings on
			if cart then
				cart.Transparency = 0
			end
			local back = table.clone(route(land.Position, drop))
			table.insert(back, 1, land.Position)
			if not legs(r, root, back, on) then
				break
			end
			if cart then
				cart.Transparency = 1
			end
			task.wait(
				rest(
					(plot :: Model):GetAttribute("HaulRate"),
					crewOf(r, "Haul"),
					os.clock() - start
				)
			)
		end
		local cart = rig:FindFirstChild("CartCrate", true)
		if cart and cart:IsA("BasePart") then
			cart.Transparency = 1
		end
		r.carry = nil
		if r.rig == rig and not r.walking then
			place(r)
			pose(r)
		end
	end)
end

-- the brick stack a Builder holds over their head (on: shown)
local BRICK_COLOURS =
	{ Color3.fromRGB(224, 56, 40), Color3.fromRGB(250, 208, 40), Color3.fromRGB(40, 96, 208) }
local function bricks(rig: Model, on: boolean)
	local head = rig:FindFirstChild("Head")
	local had = rig:FindFirstChild("BrickStack", true)
	if had and not on then
		had:Destroy()
	elseif on and not had and head and head:IsA("BasePart") then
		local base = brick(
			"BrickStack",
			Vector3.new(1.8, 0.55, 0.9),
			BRICK_COLOURS[1],
			head,
			CFrame.new(0, 1.1, 0)
		)
		for k = 2, 3 do
			brick(
				`BrickStack{k}`,
				Vector3.new(1.8, 0.55, 0.9),
				BRICK_COLOURS[k],
				base,
				CFrame.new(0, 0.55 * (k - 1), 0)
			)
		end
	end
end

-- the running site's lot when this Builder's spot is at it (DockService puts a site's Builders round its lot)
local function atSite(r: Rec, plot: Model): boolean
	local key = plot:GetAttribute("SiteKey")
	local def = if type(key) == "string" then DockConfig.Buildings[key] else nil
	local i = tonumber(string.match(plot.Name, "^Plot(%d+)$"))
	if not (def and i) then
		return false
	end
	local lot = (Marina.berth(i) * def.spot).Position
	return (r.feet.Position - lot).Magnitude < math.max(def.size.X, def.size.Y) / 2 + 8
end

-- A site's Builder: walks to a pick-up bay, waits there while the Depot is empty, carries a brick stack back and
-- hammers it on, again. False when it does not apply (the Builder works its WorkLoop beats instead).
local function supply(r: Rec): boolean
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	local plot = ownerPlot(r)
	local function on(): boolean
		return r.rig == rig
			and r.lively
			and not r.walking
			and jobOf(r) == "Build"
			and work(r) ~= nil
			and DepotController.depot(plot :: Model) ~= nil
			and atSite(r, plot :: Model)
	end
	if not (rig and root and plot and on()) then
		return false
	end
	r.carry = "rest"
	r.beat = nil
	dress(r)
	task.spawn(function()
		local trip = tonumber(r.cfg.Name) or 0
		task.wait(WorkLoop.jitter(seedOf(r.cfg), 0) * 3 - 2.2) -- a site's crew sets off out of step
		while on() do
			local picks =
				DepotController.marks(DepotController.depot(plot :: Model) :: Model, "ATT_PickUp_")
			if #picks == 0 then
				break
			end
			trip += 1
			local pick = picks[trip % #picks + 1].Position
			local start = os.clock()
			if not legs(r, root, route(feetOf(r, root), pick), on) then
				break
			end
			while on() and (plot :: Model):GetAttribute("SiteWaiting") == true do
				task.wait(1) -- an empty Depot: waits at the pile, hands empty
			end
			if not on() then
				break
			end
			bricks(rig, true)
			if not legs(r, root, route(pick, r.feet.Position), on) then
				break
			end
			bricks(rig, false)
			root.CFrame = CFrame.new(root.Position) * r.feet.Rotation -- faces the site: hammers the bricks on
			pose(r)
			local crew = tonumber((plot :: Model):GetAttribute("SiteBuilders"))
				or crewOf(r, "Build")
			task.wait(rest((plot :: Model):GetAttribute("CarryRate"), crew, os.clock() - start))
		end
		bricks(rig, false)
		r.carry = nil
		if r.rig == rig and not r.walking then
			place(r)
			pose(r)
		end
	end)
	return true
end

-- Walks the rig from where it is to `to` (feet) along a route; culled or far, it is just there.
local function walkTo(r: Rec, to: CFrame)
	local rig = r.rig
	local root = rig and rig.PrimaryPart
	r.beat, r.beatI = nil, nil
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
		-- Speedy (docs/25 E) walks 30% faster; everyone a little off the others' pace
		speed = WALK_SPEED
			* (if cfg:GetAttribute("Trait") == "Speedy" then 1.3 else 1)
			* (0.8 + 0.2 * WorkLoop.jitter(seedOf(cfg), 9)),
	}
	recs[cfg] = r
	cfg:GetAttributeChangedSignal("Spot"):Connect(function()
		local to = cfg:GetAttribute("Spot")
		if typeof(to) == "CFrame" and not r.sleep then -- asleep: walks to the new spot at dawn
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
			r.beat, r.beatI = nil, nil
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
		local door = if WorkLoop.isHome(Lighting.ClockTime, seedOf(cfg)) then doorOf(r) else nil
		if r.sleep and not door then -- dawn: made at the door below and walked out to the Spot; far ones are just there
			local spot = cfg:GetAttribute("Spot")
			if typeof(spot) == "CFrame" and (r.feet.Position - at).Magnitude > LIVELY then
				r.feet = spot
			end
		end
		r.sleep = door ~= nil
		local d = (r.feet.Position - at).Magnitude
		if r.rig and d > FAR then
			dropRig(r)
			local spot = cfg:GetAttribute("Spot")
			r.feet = if typeof(spot) == "CFrame" then spot else r.feet
		elseif not r.rig and not r.sleep and d < NEAR and made < MAKE_PER_TICK then
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
		if door then -- dusk: stops the work loop (walkTo), walks in, then hides till dawn
			if not r.rig then
				r.feet = door
			elseif not r.walking then
				if (r.feet.Position - door.Position).Magnitude < 1 then
					dropRig(r)
				else
					walkTo(r, door) -- a still (far) rig is just there, hidden next pass
				end
			end
		elseif r.lively and not r.walking and not r.carry then
			local job = jobOf(r)
			if job == "Haul" then
				haul(r)
			elseif not (job == "Build" and supply(r)) then
				loop(r)
			end
		end
	end
end

-- One badge per yard (one owner + category) over the middle of its settled crew, count when 2+: five badges
-- stacked over one stall was noise (docs/24 C art r2). WorkerBadge.crew's MaxDistance keeps it near-only.
local crews: { [string]: { gui: BillboardGui, at: Attachment } } = {}
local function crewPass()
	local groups: { [string]: { cat: string, sum: Vector3, rigs: { Model } } } = {}
	for cfg, r in recs do
		local cat = categoryOf(cfg)
		if r.rig and not r.walking and work(r) and cat then
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
			if categoryOf(cfg) == category and not r.walking then
				popCash(r)
			end
		end
	end
end

-- docs/25 G: at night every built Bunkhouse floor glows warm from inside and a "Zzz" floats over the roof. The mesh's
-- Lamp panes (M_Bld_Bunkhouse_Lv<l>_L<k>_Lamp_LOD0) are its windows, so one light per level sits at their middle.
local bunks: { [Model]: { lights: { PointLight }, zzz: BillboardGui?, bob: Tween? } } = {}
-- phones: ~100 night PointLights over the ring; only those this close to the camera shine (the Neon bulbs glow at any range)
local LIGHT_RANGE = 250
local function near(at: Vector3): boolean
	return (at - eye()).Magnitude < LIGHT_RANGE
end
-- The dock and bridge lamps (tag NightLamp): plain warm light at night, an unlit bulb by day.
local function lamp(p: Instance, on: boolean)
	if not p:IsA("BasePart") then
		return
	end
	p.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
	local light = p:FindFirstChildOfClass("PointLight")
	if not light and on then
		local made = Instance.new("PointLight")
		made.Color = p.Color
		made.Range = 24
		made.Brightness = 1.2
		made.Parent = p
		light = made
	end
	if light then
		light.Enabled = on and near(p.Position)
	end
end
local lampsLit: boolean? = nil
local function nightPass()
	local night = WorkLoop.isNight(Lighting.ClockTime)
	if night ~= lampsLit then
		lampsLit = night
		for _, p in CollectionService:GetTagged("NightLamp") do
			lamp(p, night)
		end
	elseif night then -- the camera moved: lamps in and out of LIGHT_RANGE
		for _, p in CollectionService:GetTagged("NightLamp") do
			local light = p:IsA("BasePart") and p:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = near(p.Position)
			end
		end
	end
	for mesh, b in bunks do
		if not mesh.Parent then
			bunks[mesh] = nil
			continue
		end
		for _, light in b.lights do
			light.Enabled = night and near((light.Parent :: Attachment).WorldPosition)
		end
		if b.zzz and b.bob then
			b.zzz.Enabled = night
			if night then
				b.bob:Play()
			else
				b.bob:Pause()
			end
		end
	end
end

local function lightBunk(mesh: Instance)
	if not mesh:IsA("Model") or mesh.Name ~= "BunkhouseMesh" or bunks[mesh] then
		return
	end
	local b: { lights: { PointLight }, zzz: BillboardGui?, bob: Tween? } = { lights = {} }
	bunks[mesh] = b
	-- shortcut: the lamps are read once, 2 s after the mesh lands; a part streamed in later stays dark
	task.delay(2, function()
		local floors: { [number]: { sum: Vector3, n: number, part: BasePart } } = {}
		for _, d in mesh:GetDescendants() do
			local lv = if d:IsA("BasePart")
					and (
						string.find(d.Name, "_Lamp_", 1, true)
						or string.find(d.Name, "_Bulbs_", 1, true)
					)
				then tonumber(string.match(d.Name, "_Lv(%d)_"))
				else nil
			if lv then
				local f = floors[lv] or { sum = Vector3.zero, n = 0, part = d :: BasePart }
				floors[lv] = f
				f.sum += (d :: BasePart).Position
				f.n += 1
			end
		end
		local top: Attachment? = nil
		for lv, f in floors do
			local at = Instance.new("Attachment")
			at.Name = `NightLight{lv}`
			at.Parent = f.part
			at.WorldPosition = f.sum / f.n
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 186, 104)
			light.Range = 18
			light.Brightness = 1.6
			light.Parent = at
			table.insert(b.lights, light)
			if not top or at.WorldPosition.Y > top.WorldPosition.Y then
				top = at
			end
		end
		if top then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Zzz"
			gui.Size = UDim2.fromOffset(72, 40)
			gui.StudsOffset = Vector3.new(0, 9, 0)
			gui.MaxDistance = 220
			gui.LightInfluence = 0
			gui.Parent = top
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Size = UDim2.fromScale(1, 1)
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.fromRGB(214, 228, 255)
			label.TextStrokeColor3 = Color3.fromRGB(30, 44, 66)
			label.TextStrokeTransparency = 0
			label.Text = "Zzz"
			label.Parent = gui
			b.zzz = gui
			b.bob = TweenService:Create( -- plays only at night
				gui,
				TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ StudsOffset = Vector3.new(0, 10.5, 0) }
			)
		end
		nightPass()
	end)
end

-- docs/25 B: the Lookout's add-ons (LookoutMesh) at night: a warm light in the Lv2 lantern, and the Lv3 searchlight
-- sweeps slowly round its drum (SweepPivot, DockPieces) with a plain SpotLight, only while you are within LIVELY.
-- The HQ's Lv5 beacon lamp (HQMesh) gets the same steady warm light.
local LANTERNS = { LookoutMesh = "Lv2_L03_Lantern", HQMesh = "Lv5_L05_Beacon" }
type Lookout =
	{ lantern: PointLight?, beam: SpotLight?, drum: BasePart?, sweep: Tween?, at: Vector3 }
local lookouts: { [Model]: Lookout } = {}

local function lightLookout(mesh: Instance)
	if not mesh:IsA("Model") or not LANTERNS[mesh.Name] or lookouts[mesh] then
		return
	end
	local o: Lookout = { at = mesh:GetPivot().Position }
	lookouts[mesh] = o
	-- shortcut: read once, 2 s after the mesh lands (like the bunk lamps); a part streamed in later stays dark
	task.delay(2, function()
		local lantern = mesh:FindFirstChild(LANTERNS[mesh.Name], true)
		if lantern and lantern:IsA("BasePart") then
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(255, 186, 104)
			light.Range = 20
			light.Brightness = 2
			light.Enabled = false
			light.Parent = lantern
			o.lantern = light
			o.at = lantern.Position
		end
		local drum = mesh:FindFirstChild("Lv3_L04_Searchlight", true)
		local pivot = drum and drum:FindFirstChild("SweepPivot")
		if drum and drum:IsA("BasePart") and pivot and pivot:IsA("Attachment") then
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Front
			spot.Color = Color3.fromRGB(255, 244, 214)
			spot.Range = 60
			spot.Angle = 30
			spot.Brightness = 3
			spot.Enabled = false
			spot.Parent = pivot
			o.beam = spot
			o.drum = drum
		end
	end)
end

-- made on the first night it plays, so the build's drop-in has long settled the drum: it turns round the world up
-- axis through the drum centre, 40 degrees each side of the front
local function sweepOf(drum: BasePart, beam: SpotLight): Tween
	local p = CFrame.new((beam.Parent :: Attachment).WorldPosition)
	local still = p:ToObjectSpace(drum.CFrame)
	local yaw = Instance.new("NumberValue")
	yaw.Changed:Connect(function(a: number)
		drum.CFrame = p * CFrame.Angles(0, math.rad(a), 0) * still
	end)
	yaw.Value = -40
	return TweenService:Create(
		yaw,
		TweenInfo.new(7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = 40 }
	)
end

local function lookoutPass()
	local night = WorkLoop.isNight(Lighting.ClockTime)
	local me = eye()
	for mesh, o in lookouts do
		if not mesh.Parent then
			if o.sweep then
				o.sweep:Cancel()
			end
			lookouts[mesh] = nil
			continue
		end
		local lit = night and (o.at - me).Magnitude < LIGHT_RANGE
		if o.lantern then
			o.lantern.Enabled = lit
		end
		if o.beam and o.drum then
			local on = night and (o.at - me).Magnitude < LIVELY
			o.beam.Enabled = lit
			if on and not o.sweep then
				o.sweep = sweepOf(o.drum, o.beam)
			end
			local sweep = o.sweep
			if sweep and on and sweep.PlaybackState ~= Enum.PlaybackState.Playing then
				sweep:Play()
			elseif sweep and not on and sweep.PlaybackState == Enum.PlaybackState.Playing then
				sweep:Pause()
			end
		end
	end
end

-- docs/25 B: the Rescue Boathouse's moored RIB (Lv2) and lifeboat (Lv3) (RescueBoathouseMesh) bob gently on their
-- slips, only while you are within LIVELY; the berth and the boats' _COL boxes stay put. The Air Station's Lv2
-- windsock (AirStationMesh) sways the same way, turning about its pole (mesh frame x -45.6, z 18.7) instead, and
-- the Sub Pen's Lv2 mini-sub (SubPenMesh) rolls a little on its straps about the hook block (x -3.95, y 10).
type Mooring = {
	boats: { BasePart },
	bob: Tween?,
	at: Vector3,
	pole: CFrame?,
	swing: number,
	period: number,
}
local moorings: { [Model]: Mooring } = {}
local MOORED = {
	RescueBoathouseMesh = { "Lv2_L04_RIB", "Lv3_L03_Lifeboat" },
	AirStationMesh = { "Lv2_L04_Windsock" },
	SubPenMesh = { "Lv2_L03_MiniSub" },
}
-- in the mesh frame, turning about the pole's Y: swing in radians, half a period in seconds
local POLES: { [string]: { pole: CFrame, swing: number, period: number } } = {
	AirStationMesh = { pole = CFrame.new(-45.6, 0, 18.7), swing = math.rad(14), period = 3.4 },
	SubPenMesh = { -- Y along the hull
		pole = CFrame.new(-3.95, 10, 0) * CFrame.Angles(math.pi / 2, 0, 0),
		swing = math.rad(4),
		period = 2.8,
	},
}

local function moorBoats(mesh: Instance)
	local names = MOORED[mesh.Name]
	if not names or not mesh:IsA("Model") or moorings[mesh] then
		return
	end
	local spec = POLES[mesh.Name]
	local o: Mooring = {
		boats = {},
		at = mesh:GetPivot().Position,
		pole = if spec then mesh:GetPivot() * spec.pole else nil,
		swing = if spec then spec.swing else 0.18,
		period = if spec then spec.period else 2.6,
	}
	moorings[mesh] = o
	-- shortcut: read once, 2 s after the mesh lands (like the lookout); a boat streamed in later stays still
	task.delay(2, function()
		for _, name in names do
			local boat = mesh:FindFirstChild(name, true)
			if boat and boat:IsA("BasePart") then
				table.insert(o.boats, boat)
			end
		end
	end)
end

-- moves the boats by the change in height (the windsock by the change in turn), so a rise or rebuild that sets their
-- CFrame is never fought for long
local function bobOf(o: Mooring): Tween
	local heave = Instance.new("NumberValue")
	local last = 0
	local pole = o.pole
	heave.Changed:Connect(function(y: number)
		for _, boat in o.boats do
			boat.CFrame = if pole
				then pole * CFrame.Angles(0, y - last, 0) * pole:ToObjectSpace(boat.CFrame)
				else boat.CFrame + Vector3.new(0, y - last, 0)
		end
		last = y
	end)
	return TweenService:Create(
		heave,
		TweenInfo.new(o.period, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Value = o.swing }
	)
end

local function mooringPass()
	local me = eye()
	for mesh, o in moorings do
		if not mesh.Parent then
			if o.bob then
				o.bob:Cancel()
			end
			moorings[mesh] = nil
			continue
		end
		local on = #o.boats > 0 and (o.at - me).Magnitude < LIVELY
		if on and not o.bob then
			o.bob = bobOf(o)
		end
		local bob = o.bob
		if bob and on and bob.PlaybackState ~= Enum.PlaybackState.Playing then
			bob:Play()
		elseif bob and not on and bob.PlaybackState == Enum.PlaybackState.Playing then
			bob:Pause()
		end
	end
end

-- docs/25 B: the Boathouse's Lv3 quick-launch bay (BoathouseMesh) holds a static lifeboat on its trolley; on your
-- own plot it is hidden (locally) while your Lifeboat is out: VehicleService's Vehicles/<name>_Lifeboat with an
-- unanchored root (its Dock mode, at a bay, anchors it). Its _COL box stays.
local bayBoats: { [Model]: BasePart } = {}
local function bayBoat(mesh: Instance)
	if mesh.Name ~= "BoathouseMesh" or not mesh:IsA("Model") then
		return
	end
	-- shortcut: read once, 2 s after the mesh lands (like the moorings)
	task.delay(2, function()
		local boat = mesh:FindFirstChild("Lv3_L07_Lifeboat", true)
		if boat and boat:IsA("BasePart") then
			bayBoats[mesh] = boat
		end
	end)
end

local function bayPass()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	local own = vehicles and vehicles:FindFirstChild(`{player.Name}_Lifeboat`)
	local root = own and own:IsA("Model") and own.PrimaryPart
	local out = root ~= nil and not root.Anchored
	local mine = if out then DepotController.plotOf(player.UserId) else nil
	for mesh, boat in bayBoats do
		if not mesh.Parent then
			bayBoats[mesh] = nil
			continue
		end
		boat.LocalTransparencyModifier = if mine and mesh:IsDescendantOf(mine) then 1 else 0
	end
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
	Lighting:GetPropertyChangedSignal("ClockTime"):Connect(nightPass)
	CollectionService:GetInstanceAddedSignal("NightLamp"):Connect(function(p)
		lamp(p, lampsLit == true) -- streamed in or built later
	end)
	nightPass()
	task.spawn(function()
		local marina = Workspace:WaitForChild("Marina")
		marina.DescendantAdded:Connect(function(d)
			lightBunk(d)
			lightLookout(d)
			moorBoats(d)
			bayBoat(d)
		end)
		for _, d in marina:GetDescendants() do
			lightBunk(d)
			lightLookout(d)
			moorBoats(d)
			bayBoat(d)
		end
	end)
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
	local lightsAt = 0
	while true do
		cullPass()
		crewPass()
		lookoutPass()
		if os.clock() - lightsAt >= 1 then -- night lights follow the camera (LIGHT_RANGE) once a second
			lightsAt = os.clock()
			nightPass()
		end
		mooringPass()
		bayPass()
		task.wait(0.25)
	end
end

return WorkerController
