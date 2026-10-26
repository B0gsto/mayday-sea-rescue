--!strict
-- SpinService: the prize wheel's server half (docs/24 D). Every roll happens here; the client only
-- asks for one and animates the segment the server picked.
--
-- Free spins: 1 a UTC day and 1 per 10 people rescued (SpinRules.accrue). Robux products (Spin1 /
-- Spin5 / Spin15) grant their spins through the normal MonetizationService receipt flow.
-- Prizes are granted once (finish / trail bitmask, pet variants in the pets flag, the grand boat in
-- data.vehicles plus flags.spinBoat); a duplicate pays Cash by rarity.
-- Legendary / Mythic wins fire Spin_Flex to every client (banner + confetti).
-- Remotes: Spin_Spin C->S function -> result table; Spin_Flex S->C flex payload.
-- Studio: ServerStorage.SpinDev "give" (n free spins) / "force" (next roll that rarity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local SpinRules = require(Shared:WaitForChild("SpinRules"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PetService = require(script.Parent.PetService)
local ProgressionService = require(script.Parent.ProgressionService)

local SpinService = {}
SpinService.Priority = 72 -- after ProgressionService (30), CosmeticsService (40) and PetService (66)

local FLAG = "spin"
local COOLDOWN = 0.75
local REFRESH_SECONDS = 60

local lastSpin: { [Player]: number } = {}
local forced: string? = nil
local flexRemote: RemoteEvent? = nil

local function stateOf(data: any): SpinRules.State
	return SpinRules.decode(if type(data.flags) == "table" then data.flags[FLAG] else nil)
end

local function publish(player: Player, state: SpinRules.State)
	player:SetAttribute("FreeSpins", state.free)
	player:SetAttribute("SpinPityEpic", state.pity.epic)
	player:SetAttribute("SpinPityLegendary", state.pity.legendary)
end

local function store(player: Player, state: SpinRules.State): boolean
	return ProgressionService.SetFlag(player, FLAG, SpinRules.encode(state))
end

-- Accrues the free spins that came due and mirrors the counters to the client.
function SpinService.Refresh(player: Player): SpinRules.State?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = stateOf(data)
	local nextState = SpinRules.accrue(state, data.totalRescues or 0, os.time())
	if
		nextState.free ~= state.free
		or nextState.day ~= state.day
		or nextState.rescued ~= state.rescued
	then
		store(player, nextState)
	end
	publish(player, nextState)
	return nextState
end

function SpinService.GiveFree(player: Player, n: number): number?
	local state = SpinService.Refresh(player)
	if not state then
		return nil
	end
	state.free += math.max(1, math.floor(n))
	store(player, state)
	publish(player, state)
	return state.free
end

local function grantCash(player: Player, cash: number)
	ProgressionService.Award(player, cash, "spin", true)
end

-- Applies one prize. Returns the (possibly changed) spin state and the duplicate Cash paid.
local function grantPrize(
	player: Player,
	state: SpinRules.State,
	prize: SpinRules.Prize
): (SpinRules.State, number?)
	if prize.kind == "cash" then
		grantCash(player, SpinRules.cashFor(prize.rarity))
		return state, nil
	elseif prize.kind == "petVariant" then
		if prize.variant and PetService.GrantVariant(player, prize.variant) then
			return state, nil
		end
	elseif prize.kind == "finish" or prize.kind == "trail" then
		if not SpinRules.owns(state, prize) then
			return SpinRules.claim(state, prize), nil
		end
	elseif prize.kind == "boat" and prize.vehicle then
		local data = DataService.Get(player)
		local owned = data ~= nil
			and ProgressionRules.ownsVehicle(
				data,
				prize.vehicle,
				ProgressionService.OwnsVehiclePass(player, prize.vehicle)
			)
		if not owned then
			if data then
				data.vehicles[prize.vehicle] = true
				DataService.MarkDirty(player)
			end
			ProgressionService.SetFlag(player, "spinBoat", prize.vehicle)
			ProgressionService.Refresh(player)
			return state, nil
		end
		-- already owned: the Mythic finish instead
		local galaxy = SpinRules.prize("GalaxyFinish")
		if galaxy and not SpinRules.owns(state, galaxy) then
			return SpinRules.claim(state, galaxy), nil
		end
	end
	local cash = SpinRules.duplicateCash(prize)
	grantCash(player, cash)
	return state, cash
end

local function fireFlex(player: Player, prize: SpinRules.Prize)
	local remote = flexRemote
	if not remote then
		return
	end
	remote:FireAllClients({
		userId = player.UserId,
		name = player.DisplayName,
		prize = prize.name,
		rarity = prize.rarity,
		icon = prize.icon,
	})
end

function SpinService.Spin(player: Player): { [string]: any }
	if not player.Parent then
		return { ok = false, reason = "Left" }
	end
	local now = os.clock()
	if now - (lastSpin[player] or 0) < COOLDOWN then
		return { ok = false, reason = "Too fast" }
	end
	lastSpin[player] = now
	local state = SpinService.Refresh(player)
	if not state then
		return { ok = false, reason = "Profile not loaded" }
	end
	if state.free < 1 then
		return { ok = false, reason = "No spins" }
	end

	local rng: () -> number = function(): number
		return math.random()
	end
	local prize: SpinRules.Prize
	local pity = state.pity
	if forced then
		prize = SpinRules.prizeOfRarity(rng, forced :: SpinRules.Rarity)
		forced = nil
	else
		local result = SpinRules.roll(rng, state.pity)
		prize, pity = result.prize, result.pity
	end
	local segment = SpinRules.segment(rng, prize.rarity)

	state.free -= 1
	state.pity = pity
	local duplicate = grantPrize(player, state, prize)
	store(player, state)
	publish(player, state)
	CosmeticsService.Refresh(player)
	if SpinRules.rank(prize.rarity) >= SpinRules.rank("Legendary") then
		fireFlex(player, prize)
	end
	return {
		ok = true,
		prize = prize.id,
		name = prize.name,
		rarity = prize.rarity,
		kind = prize.kind,
		icon = prize.icon,
		segment = segment,
		duplicateCash = duplicate,
	}
end

local function grantProductSpins(_player: Player, data: any, n: number): boolean
	if type(data.flags) ~= "table" then
		return false
	end
	local state = SpinRules.decode(data.flags[FLAG])
	state.free += n
	data.flags[FLAG] = SpinRules.encode(state)
	return true
end

function SpinService.Init()
	flexRemote = Net.event("Spin_Flex")
	local spin = Net.func("Spin_Spin")
	spin.OnServerInvoke = function(player: Player)
		return SpinService.Spin(player)
	end

	for key, item in MonetizationConfig.Products do
		local n = item.spins
		if type(n) == "number" then
			MonetizationService.OnProduct(key, function(_player: Player, data: any): boolean
				return grantProductSpins(_player, data, n)
			end, function(player: Player)
				SpinService.Refresh(player)
			end)
		end
	end

	DataService.OnLoaded(function(player: Player)
		SpinService.Refresh(player)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastSpin[player] = nil
	end)

	if RunService:IsStudio() then
		local dev = Instance.new("BindableFunction")
		dev.Name = "SpinDev"
		dev.OnInvoke = function(cmd: string, arg: any): any
			local player = Players:GetPlayers()[1]
			if not player then
				return nil
			end
			if cmd == "give" then
				return SpinService.GiveFree(player, tonumber(arg) or 1)
			elseif cmd == "force" then
				if type(arg) == "string" and SpinRules.RARITIES[arg] then
					forced = arg
					return true
				end
				return false
			end
			return nil
		end
		dev.Parent = ServerStorage
	end
end

function SpinService.Start()
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			for _, player in Players:GetPlayers() do
				SpinService.Refresh(player)
			end
		end
	end)
end

return SpinService
