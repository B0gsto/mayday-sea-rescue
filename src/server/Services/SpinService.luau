--!strict
-- SpinService: the prize wheel's server half (docs/24 D). Every roll happens here; the client only
-- asks for one and animates the segment the server picked.
--
-- Free spins: 1 a UTC day and 1 per 10 people rescued (SpinRules.accrue). Robux products (Spin1 /
-- Spin5 / Spin15) grant their spins through the normal MonetizationService receipt flow.
-- Prizes are granted once (finish / trail bitmask, pet variants in the pets flag, the grand boat in
-- data.vehicles plus flags.spinBoat); a duplicate pays Cash by rarity.
-- A physical wheel spin (DockService's button / prompt) calls WheelSpin: the same roll, saved at
-- once, then Spin_Wheel goes to every client so the island's wheel animates and reveals the prize.
-- Legendary / Mythic wins fire Spin_Flex when the wheel stops (banner + confetti).
-- Remotes: Spin_Wheel S->C spin payload; Spin_Flex S->C flex payload.
-- Studio: ServerStorage.SpinDev "give" (n free spins) / "force" (next roll that rarity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local ProgressionRules = require(Shared:WaitForChild("ProgressionRules"))
local SpinRules = require(Shared:WaitForChild("SpinRules"))

local CosmeticsService = require(script.Parent.CosmeticsService)
local DataService = require(script.Parent.DataService)
local MonetizationService = require(script.Parent.MonetizationService)
local PetService = require(script.Parent.PetService)
local ProgressionService = require(script.Parent.ProgressionService)
local Telemetry = require(script.Parent.TelemetryService)

local SpinService = {}
SpinService.Priority = 72 -- after ProgressionService (30), CosmeticsService (40) and PetService (66)

local FLAG = "spin"
local COOLDOWN = 0.75
local REFRESH_SECONDS = 60
local WHEEL_TIME = 4.5 -- the client's spin; the reveal and flex land when it stops
SpinService.WHEEL_TIME = WHEEL_TIME

local lastSpin: { [Player]: number } = {}
local wheelBusy: { [Player]: boolean } = {}
local forced: string? = nil
local flexRemote: RemoteEvent? = nil
local wheelRemote: RemoteEvent? = nil

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

-- docs/24 E: the finished Workshop earns exactly one tutorial spin, once. The saved step is the
-- receipt: a player who already spun (STEP_DONE) or skipped the tutorial (no STEP_SITE) never gets it.
local function tutorialSpin(player: Player, data: any, state: SpinRules.State): boolean
	if data.tutorialStep ~= Onboarding.STEP_SITE then
		return false
	end
	if type(data.dockBuildings) ~= "table" or data.dockBuildings.Workshop ~= true then
		return false
	end
	data.tutorialStep = Onboarding.STEP_SPIN
	state.free = math.min(SpinRules.MAX_FREE, state.free + 1)
	DataService.MarkDirty(player)
	return true
end

-- Accrues the free spins that came due and mirrors the counters to the client.
function SpinService.Refresh(player: Player): SpinRules.State?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = stateOf(data)
	local nextState = SpinRules.accrue(state, data.totalRescues or 0, os.time())
	-- the Workshop completion (DockService) calls Tutorial; this also catches an offline finish on join
	local tutorial = tutorialSpin(player, data, nextState)
	if
		tutorial
		or nextState.free ~= state.free
		or nextState.day ~= state.day
		or nextState.rescued ~= state.rescued
	then
		store(player, nextState)
	end
	if tutorial then
		ProgressionService.Refresh(player) -- the client sees tutorialStep (the chip's Spin tick)
	end
	publish(player, nextState)
	return nextState
end

-- The Workshop is done: hand over the first spin (docs/24 E). Idempotent through data.tutorialStep.
function SpinService.Tutorial(player: Player)
	SpinService.Refresh(player)
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

-- Applies one prize. Returns the (possibly changed) spin state, the duplicate Cash paid and the
-- prize actually given when it differs (an owned grand boat becomes the Galaxy finish).
local function grantPrize(
	player: Player,
	state: SpinRules.State,
	prize: SpinRules.Prize
): (SpinRules.State, number?, SpinRules.Prize?)
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
		-- ownsVehicle needs both the vehicle and the flag; no flag room = the Cash fallback below
		if data and not owned and ProgressionService.SetFlag(player, "spinBoat", prize.vehicle) then
			data.vehicles[prize.vehicle] = true
			DataService.MarkDirty(player)
			ProgressionService.Refresh(player)
			return state, nil
		end
		-- already owned: the Mythic finish instead
		local galaxy = SpinRules.prize("GalaxyFinish")
		if galaxy and not SpinRules.owns(state, galaxy) then
			return SpinRules.claim(state, galaxy), nil, galaxy
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
	-- the spent spin is saved before anything is granted: a failed save never yields a free prize
	if not store(player, state) then
		return { ok = false, reason = "Could not save" }
	end
	local granted, duplicate, instead = grantPrize(player, state, prize)
	prize = instead or prize
	if granted ~= state then
		state = granted
		store(player, state)
	end
	publish(player, state)
	CosmeticsService.Refresh(player)
	-- docs/24 E: the first spin ticks the tutorial's last chip; the permanent Next chip takes over
	local data = DataService.Get(player)
	if data and data.tutorialStep == Onboarding.STEP_SPIN then
		data.tutorialStep = Onboarding.STEP_DONE
		DataService.MarkDirty(player)
		ProgressionService.Refresh(player)
		Telemetry.Funnel(player, "FirstSpin")
	end
	if SpinRules.rank(prize.rarity) >= SpinRules.rank("Legendary") then
		task.spawn(DataService.Save, player, false) -- a big win is saved right away
	end
	return {
		ok = true,
		prize = prize.id,
		name = prize.name,
		rarity = prize.rarity,
		kind = prize.kind,
		icon = prize.icon,
		variant = prize.variant,
		option = prize.option,
		vehicle = prize.vehicle,
		segment = segment,
		duplicateCash = duplicate,
	}
end

-- The physical wheel (docs/24 D): one server roll, then every client animates this island's wheel
-- and shows the prize. The flex banner follows when the wheel stops, not while it is still spinning.
function SpinService.WheelSpin(player: Player): { [string]: any }
	if wheelBusy[player] then
		return { ok = false, reason = "Spinning" }
	end
	local result = SpinService.Spin(player)
	if result.ok ~= true then
		return result
	end
	local prize = SpinRules.prize(result.prize)
	wheelBusy[player] = true
	local remote = wheelRemote
	if remote then
		remote:FireAllClients({
			userId = player.UserId,
			plot = player:GetAttribute("DockPlot"),
			segment = result.segment,
			startTime = workspace:GetServerTimeNow(),
			duration = WHEEL_TIME,
			prize = result.prize,
			name = result.name,
			rarity = result.rarity,
			kind = result.kind,
			icon = result.icon,
			variant = result.variant,
			option = result.option,
			vehicle = result.vehicle,
			duplicateCash = result.duplicateCash,
		})
	end
	task.delay(WHEEL_TIME, function()
		wheelBusy[player] = nil
		-- only the rare wins are worth telling the whole server about
		if prize and (prize.rarity == "Legendary" or prize.rarity == "Mythic") then
			fireFlex(player, prize)
		end
	end)
	result.duration = WHEEL_TIME
	return result
end

local function grantProductSpins(player: Player, data: any, n: number): boolean
	-- paid random items: refused (receipt left unprocessed) unless the policy allows them
	local policy = MonetizationService.GetPolicy(player)
	if
		type(data.flags) ~= "table" or not (policy and policy.ArePaidRandomItemsRestricted == false)
	then
		return false
	end
	local state = SpinRules.decode(data.flags[FLAG])
	state.free += n
	data.flags[FLAG] = SpinRules.encode(state)
	return true
end

function SpinService.Init()
	flexRemote = Net.event("Spin_Flex")
	wheelRemote = Net.event("Spin_Wheel")

	for key, item in MonetizationConfig.Products do
		local n = item.spins
		if type(n) == "number" then
			MonetizationService.OnProduct(key, function(player: Player, data: any): boolean
				return grantProductSpins(player, data, n)
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
		wheelBusy[player] = nil
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
