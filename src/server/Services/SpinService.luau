--!strict
-- SpinService: the prize wheel's server half (docs/24 D). Every roll happens here; the client only
-- asks for one and animates the segment the server picked.
--
-- Free spins: 1 a UTC day and 1 per 10 people rescued (SpinRules.accrue). Robux products (Spin1 /
-- Spin5 / Spin15) grant their spins through the normal MonetizationService receipt flow.
-- Prizes are granted once (finish bitmask, pets in the pets flag, boat looks in the flags.spinBoat list: no stats, never
-- a craft in data.vehicles, docs/30 section 3); a duplicate pays Cash by rarity. The wedge rolled is the wedge paid.
-- A physical wheel spin (DockService's button / prompt) calls WheelSpin: the same roll, saved at
-- once, then Spin_Wheel goes to every client so the island's wheel animates and reveals the prize.
-- Legendary / Mythic wins fire Spin_Flex when the wheel stops (banner + confetti).
-- Remotes: Spin_Wheel S->C spin payload; Spin_Flex S->C flex payload.
-- Studio: ServerStorage.SpinDev "give" (n free spins) / "force" (next roll that rarity, or that wedge number) / "spin" (a wheel spin).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared:WaitForChild("Config"):WaitForChild("MonetizationConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local PetRules = require(Shared:WaitForChild("PetRules"))
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
local forcedWedge: number? = nil
local flexRemote: RemoteEvent? = nil
local wheelRemote: RemoteEvent? = nil

local function stateOf(data: any): SpinRules.State
	return SpinRules.decode(if type(data.flags) == "table" then data.flags[FLAG] else nil)
end

-- fails closed: no successful policy read yet means no paid random item
local function paidAllowed(player: Player): boolean
	local policy = MonetizationService.GetPolicy(player)
	return policy ~= nil and policy.ArePaidRandomItemsRestricted == false
end

-- won on the wheel, or the old pass (a buyer keeps it as an owned look)
local function ownsBoatLook(player: Player, data: any, vehicle: string): boolean
	return SpinRules.wonBoat(data.flags.spinBoat, vehicle)
		or ProgressionService.OwnsVehiclePass(player, vehicle)
end

local function publish(player: Player, state: SpinRules.State)
	local pets = PetService.GetState(player)
	local data = DataService.Get(player)
	local owned = SpinRules.ownedIds(state, function(species: string): boolean
		-- a full sanctuary can't take the animal in, so the wedge pays Cash as if owned
		return pets ~= nil
			and (PetRules.ownsSpecies(pets, species) or #pets.entries >= PetRules.MAX)
	end, function(vehicle: string): boolean
		return data ~= nil and ownsBoatLook(player, data, vehicle)
	end)
	player:SetAttribute("SpinOwned", table.concat(owned, ",")) -- the odds board's owned rows
	player:SetAttribute("FreeSpins", SpinRules.usable(state, paidAllowed(player)))
	player:SetAttribute("SpinPityEpic", state.pity.epic)
	player:SetAttribute("SpinPityLegendary", state.pity.legendary)
end

local function store(player: Player, state: SpinRules.State): boolean
	return ProgressionService.SetFlag(player, FLAG, SpinRules.encode(state))
end

-- docs/30 section 4: the first trip back out after L2 earns exactly one tutorial spin, once; so does an old save's
-- Workshop finished on the old beat (STEP_SITE). The saved step is the receipt: past STEP_SITE it is spent.
local function tutorialSpin(
	player: Player,
	data: any,
	state: SpinRules.State,
	tripDone: boolean?
): boolean
	if (data.tutorialStep or 0) >= Onboarding.STEP_SPIN then
		return false
	end
	local oldWorkshop = data.tutorialStep == Onboarding.STEP_SITE
		and type(data.dockBuildings) == "table"
		and data.dockBuildings.Workshop == true
	if not (tripDone or oldWorkshop) then
		return false
	end
	data.tutorialStep = Onboarding.STEP_SPIN
	state.free = math.min(SpinRules.MAX_FREE, state.free + 1)
	DataService.MarkDirty(player)
	return true
end

-- Accrues the free spins that came due and mirrors the counters to the client.
function SpinService.Refresh(player: Player, tripDone: boolean?): SpinRules.State?
	local data = DataService.Get(player)
	if not data then
		return nil
	end
	local state = stateOf(data)
	local nextState = SpinRules.accrue(state, data.totalRescues or 0, os.time())
	-- also catches an old save's offline Workshop finish on join
	local tutorial = tutorialSpin(player, data, nextState, tripDone)
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

-- The first trip is home (UpgradeService), or an old save's Workshop stands (DockService): hand over the first spin.
-- Idempotent through data.tutorialStep.
function SpinService.Tutorial(player: Player, tripDone: boolean?)
	SpinService.Refresh(player, tripDone)
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

-- Applies one prize. Returns the (possibly changed) spin state and the duplicate Cash paid, if any.
local function grantPrize(
	player: Player,
	state: SpinRules.State,
	prize: SpinRules.Prize
): (SpinRules.State, number?)
	if prize.kind == "cash" then
		grantCash(player, SpinRules.cashFor(prize.rarity))
		return state, nil
	elseif prize.kind == "pet" and prize.pet then
		if PetService.GrantPet(player, prize.pet) then
			return state, nil
		end
	elseif prize.kind == "finish" then
		if not SpinRules.owns(state, prize) then
			return SpinRules.claim(state, prize), nil
		end
	elseif prize.kind == "boat" and prize.vehicle then
		local data = DataService.Get(player)
		-- no flag room = the Cash fallback below
		if
			data
			and not ownsBoatLook(player, data, prize.vehicle)
			and ProgressionService.SetFlag(
				player,
				"spinBoat",
				SpinRules.addWonBoat(data.flags.spinBoat, prize.vehicle)
			)
		then
			return state, nil
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
	if SpinRules.usable(state, paidAllowed(player)) < 1 then
		return { ok = false, reason = "No spins" }
	end

	local rng: () -> number = function(): number
		return math.random()
	end
	local prize: SpinRules.Prize
	local segment: number
	local pity = state.pity
	if forcedWedge then
		segment, forcedWedge = forcedWedge, nil
		prize = SpinRules.prize(SpinRules.WEDGES[segment]) :: SpinRules.Prize
	elseif forced then
		prize, segment = SpinRules.prizeOfRarity(rng, forced :: SpinRules.Rarity)
		forced = nil
	else
		local result = SpinRules.roll(rng, state.pity)
		prize, segment, pity = result.prize, result.wedge, result.pity
	end

	SpinRules.spendOne(state, paidAllowed(player))
	state.pity = pity
	-- the spent spin is saved before anything is granted: a failed save never yields a free prize
	if not store(player, state) then
		return { ok = false, reason = "Could not save" }
	end
	local granted, duplicate = grantPrize(player, state, prize)
	if granted ~= state then
		state = granted
		store(player, state)
	end
	publish(player, state)
	CosmeticsService.Refresh(player)
	-- docs/30: the first spin ends the tutorial (a trip home without it does too: UpgradeService)
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
		pet = prize.pet,
		option = prize.option,
		vehicle = prize.vehicle,
		segment = segment,
		duplicate = duplicate ~= nil,
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
	player:SetAttribute("WheelSpinning", true) -- Go back refuses until the sequence ends (Boat/GoBack)
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
			pet = result.pet,
			option = result.option,
			vehicle = result.vehicle,
			duplicate = result.duplicate,
			duplicateCash = result.duplicateCash,
		})
	end
	task.delay(WHEEL_TIME, function()
		wheelBusy[player] = nil
		player:SetAttribute("WheelSpinning", nil)
		-- only the rare wins are worth telling the whole server about; a duplicate paid Cash, it won nothing
		if
			prize
			and result.duplicate ~= true
			and (prize.rarity == "Legendary" or prize.rarity == "Mythic")
		then
			fireFlex(player, prize)
		end
	end)
	result.duration = WHEEL_TIME
	return result
end

-- Paid spins: always granted. The policy gate is at the prompt (Core.isOffered, DockService wheelBuy); a receipt
-- refused here would stay unprocessed on every join if the player's policy later read restricted (PERF-MON1).
local function grantProductSpins(data: any, n: number): boolean
	data.flags = if type(data.flags) == "table" then data.flags else {}
	data.flags[FLAG] = SpinRules.addPaid(data.flags[FLAG], n)
	return true
end

function SpinService.Init()
	flexRemote = Net.event("Spin_Flex")
	wheelRemote = Net.event("Spin_Wheel")

	for key, item in MonetizationConfig.Products do
		local n = item.spins
		if type(n) == "number" then
			MonetizationService.OnProduct(key, function(_player: Player, data: any): boolean
				return grantProductSpins(data, n)
			end, function(player: Player)
				SpinService.Refresh(player)
			end)
		end
	end

	DataService.OnLoaded(function(player: Player)
		SpinService.Refresh(player)
		player
			:GetAttributeChangedSignal("PolicyRead")
			:Once(function() -- bought spins show once the policy says so
				SpinService.Refresh(player)
			end)
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
			elseif cmd == "spin" then -- the wheel's own path (a token, the roll, Spin_Wheel): back-to-back tests
				return SpinService.WheelSpin(player).ok == true
			elseif cmd == "force" then
				if type(arg) == "number" and SpinRules.WEDGES[arg] then
					forcedWedge = arg
					return true
				end
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
