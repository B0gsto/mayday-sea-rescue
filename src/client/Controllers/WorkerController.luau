--!strict
-- WorkerController (WP-26): draws the WorkerBadge billboard (category icon + rarity stars, legendary glow) on
-- every model tagged "WorkerBadge" (a picked-up survivor, your workers), and plays the offline
-- earnings welcome: a coin burst into the wallet and a Toast when the player attribute WorkerOffline arrives.
-- It also draws every island's workers, client-side only: the server publishes them as data
-- (ReplicatedStorage.Workers.<owner>.<i>, WorkerService) and this clones a shared R15 template
-- (ReplicatedStorage.WorkerRigs) into Workspace.WorkersLocal for each one within NEAR studs of you, drops it
-- past FAR, animates it only within LIVELY (a still pose beyond), and walks it along a cached
-- PathfindingService route when its Spot changes (a new recruit walks in from the jetty). At their building a
-- Builder hammers, a Mechanic swings a wrench, a Gatherer carries a crate.
local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
	Swing = "rbxassetid://522635514", -- toolslash, looped slow: hammering
}
local WORK: { [string]: { anim: string?, prop: string } } = {
	Builder = { anim = "Swing", prop = "Hammer" },
	Mechanic = { anim = "Swing", prop = "Wrench" },
	Gatherer = { prop = "Crate" },
}

type Rec = {
	cfg: Configuration,
	feet: CFrame, -- where the worker stands (or is headed, once culled)
	rig: Model?,
	height: number,
	loaded: { [string]: AnimationTrack },
	lively: boolean,
	walking: {}?, -- the running walk's token
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

local function work(r: Rec): { anim: string?, prop: string }?
	local category = r.cfg:GetAttribute("WorkerCategory")
	return if r.cfg:GetAttribute("Work") == true and type(category) == "string"
		then WORK[category]
		else nil
end

-- Plays the tracks the worker should show now (none when far or culled); tracks load once per rig.
local function pose(r: Rec)
	local want: { [string]: boolean } = {}
	if r.rig and r.lively then
		if r.walking then
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

local function brick(name: string, size: Vector3, color: Color3, to: BasePart, c0: CFrame)
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
	CollectionService:AddTag(rig, "WorkerBadge") -- the billboard (badge below)
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
			local target = p + Vector3.new(0, r.height, 0)
			local at = root.Position
			if (target - at).Magnitude > 0.5 then
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
		task.wait(0.25)
	end
end

return WorkerController
