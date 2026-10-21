--!strict
-- StationService: the station crew's capped Cash pot (docs/15 hook H6, docs/03 section 6).
-- The pot accrues in real time, online and offline, from the workshop level (data.flags.station,
-- with Radio Room and Kennel levels stored beside it at 0 until those upgrades exist). IdleIncome
-- owns the maths; this service owns the remotes (a use cooldown), the workshop purchase and the Cash.
--
-- The pot and levels live on the profile as `data.flags.station` (a flat table, see IdleIncome).
-- Remotes (under ReplicatedStorage.Net):
--   Station_State   S->C  the pot view (Cash in the pot, rate, cap, fill, time to full, level, cost)
--   Station_Get     C->S  function -> the same view (first pull)
--   Station_Collect C->S  function -> { ok, cash, cashAfter, view } from the phone's Crew Pay app
--   Station_Upgrade C->S  function -> { ok, view } from the phone's Pay Rise app
-- Studio: ServerStorage.StationDev:Invoke("away", hours) fakes a timestamp offset (the pot accrues
-- from there), ("fill"), ("level", n), ("reset"), ("view").
--
-- Cash in goes through ProgressionService.Award (one line, reason "Station:Idle"). The workshop
-- purchase deducts Cash through the profile record (DataService.Get + MarkDirty) because there is
-- no generic spend API yet; ProgressionService.Refresh pushes the new balance.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"):WaitForChild("StationConfig"))
local IdleIncome = require(Shared:WaitForChild("IdleIncome"))
local Net = require(Shared:WaitForChild("Net"))

local DataService = require(script.Parent.DataService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))

local StationService = {}
StationService.Priority = 92

local FLAG = "station"
local USE_COOLDOWN = 0.5

local stateRemote: RemoteEvent? = nil
local lastUse: { [Player]: number } = {}

local function flagOf(data: any): any
	if type(data) ~= "table" or type(data.flags) ~= "table" then
		return nil
	end
	return data.flags[FLAG]
end

local function stateOf(data: any): (IdleIncome.Levels, IdleIncome.Pot)
	return IdleIncome.fromFlag(flagOf(data))
end

local function viewOf(data: any): { [string]: any }
	local levels, pot = stateOf(data)
	local preview = IdleIncome.preview(pot, levels, os.time())
	local cost = IdleIncome.cost(levels)
	return {
		level = levels.workshop,
		radio = levels.radio,
		kennel = levels.kennel,
		maxLevel = Config.MaxLevel,
		cost = if cost then cost else 0,
		maxed = cost == nil,
		cash = preview.cash,
		rate = preview.rate,
		capCash = preview.capCash,
		capHours = preview.capHours,
		fill = preview.fill,
		full = preview.full,
		secondsToFull = preview.secondsToFull,
	}
end

local function push(player: Player, view: { [string]: any })
	local remote = stateRemote
	if remote and player.Parent then
		remote:FireClient(player, view)
	end
end

local function commit(player: Player, levels: IdleIncome.Levels, pot: IdleIncome.Pot): boolean
	return ProgressionService.SetFlag(player, FLAG, IdleIncome.toFlag(levels, pot))
end

local function ready(player: Player): boolean
	local now = os.clock()
	local last = lastUse[player]
	if last and now - last < USE_COOLDOWN then
		return false
	end
	lastUse[player] = now
	return true
end

local function collect(player: Player): any
	local data = DataService.Get(player)
	if not data or not ready(player) then
		return nil
	end
	local levels, pot = stateOf(data)
	local claim = IdleIncome.claim(pot, levels, os.time())
	if claim.cash <= 0 then
		commit(player, levels, claim.pot)
		return { ok = false, view = viewOf(data) }
	end
	local before = ProgressionService.GetData(player)
	if not before then
		return nil
	end
	if not commit(player, levels, claim.pot) then
		return nil
	end
	ProgressionService.Award(player, claim.cash, 0, "Station:Idle", true)
	Telemetry.Custom(player, "IdleCollect", claim.cash)
	local after = ProgressionService.GetData(player)
	local view = viewOf(data)
	push(player, view)
	return {
		ok = true,
		cash = if after then after.cash - before.cash else claim.cash,
		cashAfter = if after then after.cash else before.cash + claim.cash,
		view = view,
	}
end

local function upgrade(player: Player): any
	local data = DataService.Get(player)
	if not data or not ready(player) then
		return nil
	end
	local levels, pot = stateOf(data)
	local cost = IdleIncome.cost(levels)
	if not cost then
		return { ok = false, view = viewOf(data) }
	end
	if data.cash < cost then
		return { ok = false, reason = "cash", view = viewOf(data) }
	end
	-- settle the pot at the old rate first, so the next level is not retroactive
	local settled = IdleIncome.accrue(pot, levels, os.time())
	local nextLevels: IdleIncome.Levels = {
		workshop = levels.workshop + 1,
		radio = levels.radio,
		kennel = levels.kennel,
	}
	data.cash -= cost
	Telemetry.CashSpent(player, cost, data.cash, "Station", "Workshop")
	DataService.MarkDirty(player)
	if not commit(player, nextLevels, settled) then
		data.cash += cost
		return nil
	end
	ProgressionService.Refresh(player, { bought = "StationWorkshop" })
	task.spawn(DataService.Save, player, false) -- an upgrade is a milestone
	local view = viewOf(data)
	push(player, view)
	return { ok = true, view = view }
end

local function ensureRemoteEvent(folder: Instance, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local created = Instance.new("RemoteEvent")
	created.Name = name
	created.Parent = folder
	return created
end

local function ensureRemoteFunction(folder: Instance, name: string): RemoteFunction
	local existing = folder:FindFirstChild(name)
	if existing and existing:IsA("RemoteFunction") then
		return existing
	end
	local created = Instance.new("RemoteFunction")
	created.Name = name
	created.Parent = folder
	return created
end

function StationService.Init()
	local folder = Net.init()

	stateRemote = ensureRemoteEvent(folder, "Station_State")
	local get = ensureRemoteFunction(folder, "Station_Get")
	local collectFn = ensureRemoteFunction(folder, "Station_Collect")
	local upgradeFn = ensureRemoteFunction(folder, "Station_Upgrade")

	get.OnServerInvoke = function(player: Player)
		local data = DataService.Get(player)
		return if data then viewOf(data) else nil
	end
	collectFn.OnServerInvoke = collect
	upgradeFn.OnServerInvoke = upgrade

	if RunService:IsStudio() then
		-- Studio dev hook: fake time away, jump levels and teleport for the smoke shots.
		local dev = Instance.new("BindableFunction")
		dev.Name = "StationDev"
		dev.OnInvoke = function(cmd: string, arg: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			local data = DataService.Get(player)
			if not data then
				return nil
			end
			local levels, pot = stateOf(data)
			if cmd == "away" then
				local hours = math.max(0, tonumber(arg) or 3)
				local now = os.time()
				pot.lastAt = now - math.floor(hours * 3600)
				commit(player, levels, pot)
				push(player, viewOf(data))
			elseif cmd == "fill" then
				pot.lastAt = os.time() - 1000 * 3600
				commit(player, levels, pot)
				push(player, viewOf(data))
			elseif cmd == "level" then
				local wanted: IdleIncome.Levels = {
					workshop = math.clamp(math.floor(tonumber(arg) or 0), 0, Config.MaxLevel),
					radio = levels.radio,
					kennel = levels.kennel,
				}
				commit(player, wanted, pot)
				push(player, viewOf(data))
			elseif cmd == "reset" then
				commit(player, IdleIncome.newLevels(), { lastAt = os.time(), cash = 0 })
				push(player, viewOf(data))
			end
			return viewOf(data)
		end
		dev.Parent = game:GetService("ServerStorage")
	end

	DataService.OnLoaded(function(player: Player, data: any)
		if flagOf(data) == nil then
			-- start the clock now, so the first return actually earns something
			commit(player, IdleIncome.newLevels(), { lastAt = os.time(), cash = 0 })
		end
		push(player, viewOf(data))
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastUse[player] = nil
	end)
end

function StationService.Start() end

return StationService
