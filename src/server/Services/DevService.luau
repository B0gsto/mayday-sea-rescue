--!strict
-- DevService: the developer "dev board" (works on live servers). Access is DevConfig.isAllowed:
-- Studio, the listed user ids, or rank >= 254 in the studio group (checked once on join, cached).
-- Only an allowed player gets Dev_Grant (the client panel stays inert without it); every
-- Dev_Action re-checks the sender, validates the args (DevConfig.validate), is rate-limited and
-- printed with the dev's user id. Non-devs get nil and no error text.
-- Remotes under ReplicatedStorage.Net: Dev_Grant (S->C, { toggle = true? }), Dev_Action
-- (C->S function: action, args -> ok, short text, data?). Chat "/dev" toggles the panel.
-- Each action reuses the owning service's API; see CONTRACT.md "Dev board".
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = Shared:WaitForChild("Config")
local DevConfig = require(Config:WaitForChild("DevConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionConfig = require(Config:WaitForChild("ProgressionConfig"))
local Rules = require(Shared:WaitForChild("ProgressionRules"))
local VehicleUpgrades = require(Shared:WaitForChild("VehicleUpgrades"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local DogService = require(script.Parent.DogService)
local LiveOpsService = require(script.Parent.LiveOpsService)
local MonetizationService = require(script.Parent.MonetizationService)
local OperationService = require(script.Parent.OperationService)
local PetService = require(script.Parent.PetService)
local ProgressionService = require(script.Parent.ProgressionService)
local StormService = require(script.Parent.StormService)
local VehicleService = require(script.Parent.VehicleService)

local DevService = {}
DevService.Priority = 200 -- after every service it drives

local LIVEOPS_SECONDS = 1800
local BOOT = os.clock()

local allowed: { [Player]: boolean } = {}
local stamps: { [Player]: { number } } = {}
local god: { [Player]: true } = {}
local grant: RemoteEvent
local heartbeatFps = 60

local function isDev(player: Player): boolean
	return allowed[player] == true and player.Parent ~= nil
end

local function log(dev: Player, action: string, args: { any }, result: string)
	local parts = {}
	for _, v in args do
		table.insert(parts, tostring(v))
	end
	print(`[DevService] {dev.UserId} {dev.Name}: {action}({table.concat(parts, ", ")}) -> {result}`)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Unseat, then move the character (the server may move a client-owned assembly).
local function moveTo(player: Player, cf: CFrame): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) then
		return false
	end
	if humanoid.SeatPart then
		humanoid.Sit = false
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
	end
	character:PivotTo(cf)
	return true
end

-- Ground (or sea level) under a spot: underwater points land on the surface above them.
local function landing(position: Vector3): CFrame
	local params = RaycastParams.new()
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.FilterType = Enum.RaycastFilterType.Exclude
	local top = math.max(position.Y, 0) + 400
	local hit =
		Workspace:Raycast(Vector3.new(position.X, top, position.Z), Vector3.new(0, -800, 0), params)
	local y = if hit and hit.Position.Y > -2 then hit.Position.Y else 0
	return CFrame.new(position.X, y + 4, position.Z)
end

local function edit(target: Player, fn: (data: Rules.PlayerData) -> ()): (boolean, string)
	local data = DataService.Get(target)
	if not data then
		return false, "Not loaded"
	end
	fn(data)
	DataService.MarkDirty(target)
	ProgressionService.Refresh(target)
	return true, "Done"
end

local function setGod(player: Player, on: boolean)
	if on then
		god[player] = true
	else
		god[player] = nil
	end
	local character = player.Character
	if not character then
		return
	end
	local field = character:FindFirstChild("DevGod")
	if on and not field then
		local ff = Instance.new("ForceField")
		ff.Name = "DevGod"
		ff.Visible = false
		ff.Parent = character
	elseif not on and field then
		field:Destroy()
	end
end

local function setInvisible(player: Player, on: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local part = d :: any -- both have Transparency
			local saved = part:GetAttribute("DevT")
			if on and saved == nil then
				part:SetAttribute("DevT", part.Transparency)
				part.Transparency = 1
			elseif not on and type(saved) == "number" then
				part.Transparency = saved
				part:SetAttribute("DevT", nil)
			end
		end
	end
end

local function event(id: string, on: boolean): (boolean, string)
	-- LiveOps: this server only (no MessagingService publish)
	local nonce = `dev{os.time()}{math.random(1000, 9999)}`
	local changed = LiveOpsService.Adopt(
		if on
			then { event = id, startsAt = os.time(), duration = LIVEOPS_SECONDS, nonce = nonce }
			else { event = "Cancel", nonce = nonce }
	)
	return changed, if changed then id else "No change"
end

local function unlockAll(target: Player): (boolean, string)
	local ok = edit(target, function(data)
		for id in ProgressionConfig.Vehicles do
			data.vehicles[id] = true
		end
		for _, id in VehicleUpgrades.VehicleOrder do
			data.vehicleUpgrades[id] = VehicleUpgrades.MAX_MASK
		end
	end)
	for _, id in DevConfig.Passes do
		if id ~= "All" then
			pcall(MonetizationService.SetPassOwnedForTesting, target, id, true)
		end
	end
	for _, id in VehicleUpgrades.VehicleOrder do
		pcall(VehicleService.RefreshUpgrades, target, id)
	end
	pcall(CosmeticsService.Refresh, target)
	return ok, if ok then "Unlocked" else "Not loaded"
end

-- Wipe the profile through DataService's real save (same session lock, same key), release it,
-- then send the player back in so the cold open plays. Never touches any other DataStore key.
local function resetProfile(target: Player): (boolean, string)
	local data = DataService.Get(target) :: any
	if not data then
		return false, "Not loaded"
	end
	table.clear(data) -- in place: every service holding this table sees the fresh profile
	for k, v in Rules.defaultData() :: any do
		data[k] = v
	end
	DataService.MarkDirty(target)
	if not DataService.Save(target, true) then
		return false, "Save failed"
	end
	task.spawn(function()
		local ok = pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { target })
		if not ok and target.Parent then
			target:Kick("Profile reset. Rejoin to start fresh.")
		end
	end)
	return true, "Reset"
end

local function stats(): any
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, { userId = p.UserId, name = p.Name, dev = allowed[p] == true })
	end
	return {
		players = list,
		maxPlayers = Players.MaxPlayers,
		memoryMb = math.floor(Stats:GetTotalMemoryUsageMb()),
		fps = math.floor(heartbeatFps + 0.5),
		uptime = math.floor(os.clock() - BOOT),
		placeVersion = game.PlaceVersion,
		jobId = game.JobId,
		studio = RunService:IsStudio(),
	}
end

local handlers: { [string]: (dev: Player, target: Player?, args: { any }) -> (boolean, string, any?) } =
	{
		god = function(dev, _, a)
			setGod(dev, a[1])
			return true, if a[1] then "God on" else "God off"
		end,
		invisible = function(dev, _, a)
			setInvisible(dev, a[1])
			return true, if a[1] then "Hidden" else "Visible"
		end,
		tpSpot = function(dev, _, a)
			return moveTo(dev, landing(DevConfig.Spots[a[1]].position)), a[1]
		end,
		tpPlayer = function(dev, target)
			local root = target and rootOf(target)
			return root ~= nil and moveTo(dev, root.CFrame * CFrame.new(0, 0, 4)), "Teleported"
		end,
		bring = function(dev, target)
			local root = rootOf(dev)
			return target ~= nil and root ~= nil and moveTo(
				target,
				root.CFrame * CFrame.new(0, 0, -4)
			),
				"Brought"
		end,
		tpPos = function(dev, _, a)
			return moveTo(dev, CFrame.new((a[1] :: Vector3) + Vector3.new(0, 4, 0))), "Teleported"
		end,
		vehicle = function(_, target, a)
			local p = target :: Player
			local id = a[2] :: string
			-- launched from the player's bay (spawning at the player put boats on the street)
			local ok, result = VehicleService.DevLaunch(p, id)
			return ok, if ok then id else tostring(result)
		end,
		pet = function(_, target, a)
			local p = target :: Player
			local entry = PetService.AddRescue(p, a[2], false)
			if entry then
				PetService.DevReady(p)
			end
			return entry ~= nil, if entry then "At sanctuary" else "Refused"
		end,
		bosun = function(_, target)
			local p = target :: Player
			local dog, root = DogService.GetDog(p), rootOf(p)
			if not (dog and root) then
				return false, "No Bosun"
			end
			dog:PivotTo(root.CFrame * CFrame.new(3, 0, 3))
			return true, "Woof"
		end,
		op = function(_, target, a)
			local p = target :: Player
			local kind = a[2] :: string
			local id
			if kind == "ColdOpen" then
				id = OperationService.StartColdOpen(p, nil, true)
			else
				id = OperationService.DevStart(p, kind)
			end
			return id ~= nil, if id then kind else "Busy"
		end,
		opEnd = function(_, target, a)
			local ok = OperationService.DevEnd(target :: Player, a[2])
			return ok, if ok then (if a[2] then "Completed" else "Cancelled") else "No op"
		end,
		storm = function(_, _, a)
			StormService.SetDevStorms(a[1] ~= "Calm")
			if a[1] == "Calm" then
				StormService.ForceCalm()
			else
				StormService.ForceStorm(a[1] == "GreatStorm", true)
			end
			return true, a[1]
		end,
		clock = function(_, _, a)
			Lighting.ClockTime = a[1]
			return true, string.format("%.1f h", a[1])
		end,
		event = function(_, _, a)
			return event(a[1], a[2])
		end,
		award = function(_, target, a)
			return edit(target :: Player, function(data)
				data.cash += math.floor(a[2])
				data.rep += math.floor(a[3])
			end)
		end,
		rank = function(_, target, a)
			return edit(target :: Player, function(data)
				data.rep = ProgressionConfig.Ranks[math.floor(a[2])].rep
			end)
		end,
		unlockAll = function(_, target)
			return unlockAll(target :: Player)
		end,
		pass = function(_, target, a)
			for _, id in DevConfig.Passes do
				if id ~= "All" and (a[2] == "All" or a[2] == id) then
					pcall(MonetizationService.SetPassOwnedForTesting, target :: Player, id, true)
				end
			end
			pcall(CosmeticsService.Refresh, target :: Player)
			return true, "Test owned"
		end,
		reset = function(_, target)
			return resetProfile(target :: Player)
		end,
		kick = function(dev, target)
			if target == dev then
				return false, "Not yourself"
			end
			local p = target :: Player
			p:Kick("Removed by a developer.")
			return true, "Kicked"
		end,
		stats = function()
			return true, "Stats", stats()
		end,
	}

local function onAction(dev: Player, action: any, args: any): any
	if not isDev(dev) then
		return nil -- non-devs: nothing, no error text
	end
	if not DevConfig.rateOk(stamps[dev], os.clock()) then
		return false, "Slow down"
	end
	local valid, clean = DevConfig.validate(action, args)
	if not valid then
		log(dev, tostring(action), {}, `refused: {clean}`)
		return false, "Bad request"
	end
	local spec = DevConfig.Actions[action]
	local target: Player? = nil
	if spec[1] and spec[1].kind == "player" then
		target = Players:GetPlayerByUserId(clean[1])
		if not target then
			log(dev, action, clean, "refused: player not in server")
			return false, "Not here"
		end
	end
	local ok, result, okText, data = pcall(handlers[action], dev, target, clean)
	if not ok then
		log(dev, action, clean, `error: {result}`)
		return false, "Error"
	end
	log(dev, action, clean, tostring(okText))
	return result == true, okText, data
end

local function check(player: Player)
	local rank = 0
	if not RunService:IsStudio() and not DevConfig.UserIds[player.UserId] then
		-- shortcut: the deprecated rank call still answers; move to GroupService:GetRolesInGroupAsync if it stops
		local ok, value = pcall(function()
			return (player :: any):GetRankInGroupAsync(DevConfig.GroupId)
		end)
		rank = if ok and type(value) == "number" then value else 0
	end
	if not player.Parent or not DevConfig.isAllowed(player.UserId, rank, RunService:IsStudio()) then
		return
	end
	allowed[player] = true
	stamps[player] = {}
	print(`[DevService] dev board granted to {player.UserId} {player.Name}`)
	player.CharacterAdded:Connect(function(character)
		if god[player] then
			character:WaitForChild("HumanoidRootPart", 10)
			setGod(player, true)
		end
	end)
	grant:FireClient(player, {})
end

function DevService.Init()
	local folder = Net.init()
	grant = Instance.new("RemoteEvent")
	grant.Name = "Dev_Grant"
	grant.Parent = folder
	local action = Instance.new("RemoteFunction")
	action.Name = "Dev_Action"
	action.OnServerInvoke = onAction
	action.Parent = folder
end

function DevService.Start()
	Players.PlayerAdded:Connect(check)
	for _, player in Players:GetPlayers() do
		task.spawn(check, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		allowed[player] = nil
		stamps[player] = nil
		god[player] = nil
	end)
	local frames, since = 0, os.clock()
	RunService.Heartbeat:Connect(function()
		frames += 1
		local now = os.clock()
		if now - since >= 1 then
			heartbeatFps = frames / (now - since)
			frames, since = 0, now
		end
	end)
	-- chat "/dev": devs toggle the panel, everyone else sees nothing happen
	local function toggle(player: Player?)
		if player and isDev(player) then
			grant:FireClient(player, { toggle = true })
		end
	end
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local command = Instance.new("TextChatCommand")
		command.Name = "Dev_Board"
		command.PrimaryAlias = "/dev"
		command.AutocompleteVisible = false
		command.Triggered:Connect(function(source: TextSource)
			toggle(Players:GetPlayerByUserId(source.UserId))
		end)
		command.Parent = TextChatService:FindFirstChild("TextChatCommands") or TextChatService
	else
		local function hook(player: Player)
			player.Chatted:Connect(function(message)
				if message == "/dev" then
					toggle(player)
				end
			end)
		end
		Players.PlayerAdded:Connect(hook)
		for _, player in Players:GetPlayers() do
			hook(player)
		end
	end
end

return DevService
