--!strict
-- QuestService (docs/23 (l), WP-21b): the six quest givers at the hub's quest camps (Quests/Data, HubLayout
-- questSpots) and each player's one active quest (Quests/Rules; saved in the profile flag `quest`).
--   Talk (TalkController, numbered replies) -> remote Quest_Talk C->S (npcId, "accept" | "handIn" | "drop").
--   find: the item waits on its island; walk into it and it rides on your back. salvage: the same from the sub
--   at a wreck. deliver: you carry it from the camp; walk it to the flag. rescue: a call is offered at the zone
--   (OperationService.OfferCall), done when its survivor is delivered (OperationCompleted). Then back to the
--   giver ("?") to hand in: Cash + Rep (flat), and the chain's last step adds its blueprint to your island.
-- Player attributes (QuestController / MapController / TalkController read them): QuestId, QuestStage
-- ("go" | "back"), QuestTarget (Vector3: the thing, then the giver), QuestOffer_<npcId> (today's offer).
-- Studio: ServerStorage.QuestDev:Invoke("accept", npcId) | ("reach") | ("hand") | ("tp": to the pin) | ("chain") |
-- ("reset").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CallTypes = require(Shared:WaitForChild("Calls"):WaitForChild("CallTypes"))
local Data = require(Shared:WaitForChild("Quests"):WaitForChild("Data"))
local DataService = require(script.Parent:WaitForChild("DataService"))
local DockService = require(script.Parent:WaitForChild("DockService"))
local HubLayout = require(Shared:WaitForChild("Config"):WaitForChild("HubLayout"))
local Net = require(Shared:WaitForChild("Net"))
local NpcFactory = require(script.Parent.Parent:WaitForChild("Npc"):WaitForChild("NpcFactory"))
local OperationService = require(script.Parent:WaitForChild("OperationService"))
local ProgressionService = require(script.Parent:WaitForChild("ProgressionService"))
local Rules = require(Shared:WaitForChild("Quests"):WaitForChild("Rules"))

local QuestService = {}
QuestService.Priority = 130

local TICK = 0.3
local TALK_RANGE = 16 -- studs from the giver a reply counts from
local OFFER_RETRY = CallTypes.Scheduler.OfferSeconds + 10 -- a quest call not taken by then is offered again

type Live = {
	item: Model?, -- the thing waiting in the world (find / salvage) or the delivery flag
	rescue: { id: string?, at: number }?,
}

local states: { [Player]: Rules.State } = {}
local live: { [Player]: Live } = {}
local giverAt: { [string]: Vector3 } = {}
local folder: Folder
local npcFolder: Instance

-- Item looks (placeholder Parts): size, colour, material, shape
local ITEMS: { [string]: { any } } = {
	dog = { Vector3.new(1.2, 1.1, 2.2), Color3.fromRGB(150, 98, 52), Enum.Material.Fabric },
	satchel = { Vector3.new(1.6, 1.2, 0.6), Color3.fromRGB(110, 70, 40), Enum.Material.Fabric },
	crate = { Vector3.new(2, 2, 2), Color3.fromRGB(176, 132, 80), Enum.Material.Wood },
	sack = { Vector3.new(1.6, 2, 1.2), Color3.fromRGB(214, 196, 150), Enum.Material.Fabric },
	bell = {
		Vector3.new(1.8, 1.8, 1.8),
		Color3.fromRGB(196, 150, 60),
		Enum.Material.Metal,
		Enum.PartType.Ball,
	},
	chest = { Vector3.new(2.4, 1.6, 1.6), Color3.fromRGB(96, 64, 40), Enum.Material.Wood },
	glass = {
		Vector3.new(1.6, 1.6, 1.6),
		Color3.fromRGB(170, 220, 255),
		Enum.Material.Glass,
		Enum.PartType.Ball,
	},
	oil = {
		Vector3.new(2.2, 1.6, 1.6),
		Color3.fromRGB(196, 52, 40),
		Enum.Material.Metal,
		Enum.PartType.Cylinder,
	},
	lens = {
		Vector3.new(1.8, 1.8, 1.8),
		Color3.fromRGB(255, 220, 140),
		Enum.Material.Glass,
		Enum.PartType.Ball,
	},
	kite = { Vector3.new(2.4, 0.2, 2.4), Color3.fromRGB(226, 60, 70), Enum.Material.Fabric },
	lunch = {
		Vector3.new(1.2, 0.8, 0.8),
		Color3.fromRGB(46, 110, 200),
		Enum.Material.SmoothPlastic,
	},
}

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material
): Part
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color, p.Material = size, cf, color, mat
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- The quest thing as a Model (pivot at its centre); the dog gets a head and a tail.
local function itemModel(kind: string, cf: CFrame): Model
	local m = Instance.new("Model")
	m.Name = "QuestItem"
	local look = ITEMS[kind] or ITEMS.crate
	local body = part(m, look[1], cf, look[2], look[3])
	if look[4] then
		body.Shape = look[4]
	end
	if kind == "kite" then
		body.CFrame = cf * CFrame.Angles(0, math.rad(45), 0)
	elseif kind == "dog" then
		part(m, Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(0, 0.6, -1.3), look[2], look[3])
		part(m, Vector3.new(0.2, 0.2, 0.8), cf * CFrame.new(0, 0.5, 1.3), look[2], look[3])
		part(
			m,
			Vector3.new(0.3, 0.3, 0.2),
			cf * CFrame.new(0, 0.6, -1.85),
			Color3.new(0, 0, 0),
			look[3]
		)
	end
	m.PrimaryPart = body
	return m
end

local function settle(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder, npcFolder }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -90, 0), params)
	local y = if hit then hit.Position.Y else at.Y
	return Vector3.new(at.X, math.max(y, 0), at.Z)
end

local function rootOf(player: Player): BasePart?
	local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

local function inSub(player: Player): boolean
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = hum and hum.SeatPart
	local craft = seat and seat:FindFirstAncestorWhichIsA("Model")
	while craft and craft:GetAttribute("VehicleId") == nil do
		craft = craft:FindFirstAncestorWhichIsA("Model")
	end
	return craft ~= nil and craft:GetAttribute("VehicleId") == "Submarine"
end

-- The carried thing on the character's back (welded, massless); nil kind takes it off.
local function carry(player: Player, kind: string?)
	local char = player.Character
	local old = char and char:FindFirstChild("QuestCarry")
	if old then
		old:Destroy()
	end
	local torso = char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
	if not (kind and kind ~= "" and torso and torso:IsA("BasePart")) then
		return
	end
	local m = itemModel(kind, torso.CFrame * CFrame.new(0, 0, 1.4))
	m.Name = "QuestCarry"
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.Anchored, p.Massless = false, true
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = torso, p
			w.Parent = p
		end
	end
	m.Parent = char
end

local function clearLive(player: Player)
	local l = live[player]
	if l and l.item then
		l.item:Destroy()
	end
	live[player] = {}
end

local function questOf(player: Player): Data.Quest?
	local s = states[player]
	return if s and s.active then Data.byId[s.active] else nil
end

-- The world side of the current stage: the waiting thing / the drop flag (go), what you carry (back / deliver go).
local function stage(player: Player)
	clearLive(player)
	local quest, s = questOf(player), states[player]
	if not (quest and s) then
		carry(player, nil)
		return
	end
	local l = live[player]
	if s.stage == "back" then
		carry(player, if quest.kind == "deliver" then nil else quest.item)
	elseif quest.kind == "find" or quest.kind == "salvage" then
		carry(player, nil)
		local at = Rules.target(quest)
		at = if quest.kind == "find"
			then settle(at) + Vector3.new(0, 0.9, 0)
			else at + Vector3.new(0, 2, 0)
		l.item = itemModel(quest.item, CFrame.new(at));
		(l.item :: Model).Parent = folder
	elseif quest.kind == "deliver" then
		carry(player, quest.item)
		local at = settle(Rules.target(quest))
		local flag = Instance.new("Model")
		flag.Name = "QuestDrop"
		part(
			flag,
			Vector3.new(0.4, 8, 0.4),
			CFrame.new(at + Vector3.new(0, 4, 0)),
			Color3.new(1, 1, 1),
			Enum.Material.Wood
		)
		part(
			flag,
			Vector3.new(0.1, 1.6, 2.6),
			CFrame.new(at + Vector3.new(0, 7, 1.3)),
			Color3.fromRGB(255, 196, 40),
			Enum.Material.Fabric
		)
		flag.Parent = folder
		l.item = flag
	else
		carry(player, nil)
	end
end

local function save(player: Player)
	local s = states[player]
	if s and not ProgressionService.SetFlag(player, "quest", Rules.encode(s)) then
		warn(`[QuestService] could not save {player.Name}'s quest flag`)
	end
end

local function can(player: Player): (Data.Quest) -> boolean
	return function(q: Data.Quest): boolean
		return q.needs == nil or ProgressionService.CanUseVehicle(player, q.needs) == true
	end
end

local function today(): number
	return Rules.day(os.time())
end

-- The client's view: today's offers, the active quest and where the pin goes.
local function publish(player: Player)
	local s = states[player]
	if not s then
		return
	end
	local day, ok = today(), can(player)
	for _, npc in Data.Npcs do
		local offer = Rules.offer(s, npc.id, day, ok)
		player:SetAttribute(`QuestOffer_{npc.id}`, if offer then offer.id else nil)
	end
	local quest = questOf(player)
	player:SetAttribute("QuestId", s.active)
	player:SetAttribute("QuestStage", s.stage)
	local target: Vector3? = nil
	if quest and s.stage == "back" then
		target = giverAt[quest.npc]
	elseif quest then
		local l = live[player]
		target = if l and l.item then l.item:GetPivot().Position else Rules.target(quest)
	end
	if quest and quest.kind == "rescue" and s.stage == "go" then
		local op = OperationService.GetOperationOf(player)
		local r = live[player] and live[player].rescue
		if op and r and op.id == r.id then
			target = nil -- the call's own pin takes over
		end
	end
	player:SetAttribute("QuestTarget", target)
end

local function reached(player: Player)
	Rules.reached(states[player])
	stage(player)
	save(player)
	publish(player)
end

-- The go stage: picked up / delivered when close enough; a rescue quest keeps its call on offer.
local function tick(player: Player)
	local quest, s, l = questOf(player), states[player], live[player]
	local root = rootOf(player)
	if not (quest and s and l and root) then
		return
	end
	if s.stage == "back" then
		if
			quest.kind ~= "deliver"
			and player.Character
			and not player.Character:FindFirstChild("QuestCarry")
		then
			carry(player, quest.item) -- respawned
		end
		return
	end
	if quest.kind == "rescue" then
		local r = l.rescue
		local op = OperationService.GetOperationOf(player)
		if not op and (not r or os.clock() - r.at > OFFER_RETRY) then
			local id = OperationService.OfferCall(player, "PersonInWater", { zone = quest.at.zone })
			-- not offered (busy, the after-call breather): try again in a few seconds
			l.rescue = { id = id, at = if id then os.clock() else os.clock() - OFFER_RETRY + 5 }
		end
		return
	end
	local item = l.item
	if not item then
		return
	end
	local at = item:GetPivot().Position
	if (root.Position - at).Magnitude > Rules.RANGE[quest.kind] then
		return
	end
	if quest.kind == "salvage" and not inSub(player) then
		return
	end
	if quest.kind == "deliver" then
		local left = itemModel(
			quest.item,
			CFrame.new(settle(at + Vector3.new(2, 0, 0)) + Vector3.new(0, 1, 0))
		)
		left.Parent = folder
		task.delay(30, left.Destroy, left)
	end
	reached(player)
end

local function handIn(player: Player)
	local s = states[player]
	local quest = Rules.complete(s, today())
	if not quest then
		return
	end
	ProgressionService.Award(player, quest.cash, quest.rep, `Quest:{quest.id}`, true)
	local data: any = DataService.Get(player)
	if quest.blueprint and data then
		data.dockBuildings = if type(data.dockBuildings) == "table" then data.dockBuildings else {}
		if not data.dockBuildings[quest.blueprint] then
			data.dockBuildings[quest.blueprint] = true
			DataService.MarkDirty(player)
			DockService.Refresh(player)
		end
	end
	stage(player)
	save(player)
	task.spawn(DataService.Save, player, false)
	publish(player)
end

local function onTalk(player: Player, npcId: any, action: any)
	local s, root = states[player], rootOf(player)
	local at: Vector3? = if type(npcId) == "string" then giverAt[npcId] else nil
	if not (s and root and at) or (root.Position - at).Magnitude > TALK_RANGE then
		return
	end
	local quest = questOf(player)
	if action == "accept" then
		local offer = Rules.offer(s, npcId, today(), can(player))
		if offer and Rules.accept(s, offer) then
			live[player].rescue = nil
			stage(player)
			save(player)
		end
	elseif action == "handIn" and quest and quest.npc == npcId then
		handIn(player)
	elseif action == "drop" and quest and quest.npc == npcId then
		Rules.drop(s)
		stage(player)
		save(player)
	end
	publish(player)
end

-- A giver at their camp: a canvas lean-to, crates and a lantern post behind them.
local function spawnGiver(npc: Data.Npc, spot: { cframe: CFrame })
	local cf = spot.cframe
	local feet = settle(cf.Position)
	local stand = CFrame.lookAt(feet, feet + cf.LookVector * Vector3.new(1, 0, 1))
	giverAt[npc.id] = feet + Vector3.new(0, 3, 0)
	local camp = Instance.new("Model")
	camp.Name = `{npc.id}Camp`
	local back = stand * CFrame.new(0, 0, 7)
	local canvas = Color3.fromRGB(214, 200, 160)
	local wood = Color3.fromRGB(110, 80, 52)
	for _, x in { -4, 4 } do
		part(camp, Vector3.new(0.5, 6, 0.5), back * CFrame.new(x, 3, -2), wood, Enum.Material.Wood)
	end
	part(
		camp,
		Vector3.new(9.5, 0.2, 6),
		back * CFrame.new(0, 4, 0.4) * CFrame.Angles(math.rad(-30), 0, 0),
		canvas,
		Enum.Material.Fabric
	)
	part(
		camp,
		Vector3.new(2, 2, 2),
		stand * CFrame.new(3.5, 1, 2),
		Color3.fromRGB(176, 132, 80),
		Enum.Material.Wood
	)
	part(
		camp,
		Vector3.new(1.6, 1.6, 1.6),
		stand * CFrame.new(3.6, 2.8, 2.2),
		Color3.fromRGB(150, 110, 70),
		Enum.Material.Wood
	)
	part(
		camp,
		Vector3.new(0.4, 5, 0.4),
		stand * CFrame.new(-3.5, 2.5, 1.5),
		wood,
		Enum.Material.Wood
	)
	local lamp = part(
		camp,
		Vector3.new(0.8, 1, 0.8),
		stand * CFrame.new(-3.5, 5.3, 1.5),
		Color3.fromRGB(255, 200, 120),
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = lamp.Color, 14, 1.2
	light.Parent = lamp
	camp.Parent = folder
	task.spawn(NpcFactory.spawn, npc.role, {
		name = npc.id,
		pose = "Idle",
		seed = npc.seed,
		cframe = stand,
		parent = npcFolder,
	})
end

local function load(player: Player, data: any)
	states[player] = Rules.decode(type(data.flags) == "table" and data.flags.quest or nil)
	live[player] = {}
	stage(player)
	publish(player)
	player.CharacterAdded:Connect(function()
		task.wait(1)
		if states[player] then
			stage(player) -- the carried thing back on the new character
		end
	end)
end

function QuestService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Quests"
	folder.Parent = Workspace
	local remote = Instance.new("RemoteEvent")
	remote.Name = "Quest_Talk"
	remote.OnServerEvent:Connect(onTalk)
	remote.Parent = Net.init()
end

function QuestService.Start()
	npcFolder = Workspace:WaitForChild("Npcs")
	for i, npc in Data.Npcs do
		local spot = HubLayout.Hub.questSpots[i]
		if spot then
			spawnGiver(npc, spot)
		end
	end
	DataService.OnLoaded(load)
	Players.PlayerRemoving:Connect(function(player)
		clearLive(player)
		states[player], live[player] = nil, nil
	end)
	OperationService.OperationCompleted:Connect(function(snap: any)
		for player, l in live do
			local quest = questOf(player)
			if l.rescue and l.rescue.id == snap.id and quest and states[player].stage == "go" then
				if (snap.saved or 0) > 0 then
					reached(player)
				else
					l.rescue = nil -- lost: offered again
				end
			end
		end
	end)
	task.spawn(function()
		local n = 0
		while true do
			task.wait(TICK)
			n += 1
			for player in states do
				tick(player)
				if n % 10 == 0 then
					publish(player) -- day rollover, a sub bought, the rescue call taken
				end
			end
		end
	end)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "QuestDev"
		dev.OnInvoke = function(cmd: string, arg: any): any
			local player = Players:GetPlayers()[1]
			local s = player and states[player]
			local root = player and rootOf(player)
			if not (s and root) then
				return nil
			end
			if cmd == "accept" then
				root.CFrame = CFrame.new(giverAt[arg] + Vector3.new(0, 0, 4))
				onTalk(player, arg, "accept")
			elseif cmd == "tp" then
				local target = player:GetAttribute("QuestTarget")
				if typeof(target) == "Vector3" then
					root.CFrame = CFrame.new(target + Vector3.new(0, 4, 0))
				end
			elseif cmd == "reach" then
				reached(player)
			elseif cmd == "hand" then
				handIn(player)
			elseif cmd == "chain" then -- Keeper Ives' three steps handed in at once: the lighthouse rises
				for _, id in { "Lamp1", "Lamp2", "Lamp3" } do
					s.active, s.stage, s.last.QuestIves = id, "back", nil
					handIn(player)
				end
			elseif cmd == "reset" then
				states[player] = Rules.new()
				stage(player)
				save(player)
			end
			publish(player)
			return states[player].active, states[player].stage
		end
		dev.Parent = game:GetService("ServerStorage")
	end
end

return QuestService
