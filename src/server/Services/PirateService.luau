--!strict
-- PirateService (docs/29 D, docs/30 section 5): the pirate that hunts a boat with survivors aboard. Rules and steering:
-- shared/PirateRules. The server steers a plain position and publishes it as attributes; PirateController moves the boat
-- on each client (no physics, nothing replicated part by part). A ram takes one survivor (RescueService.KnockOverboard),
-- ends the run and cancels a Go back charge; the rider stays seated and nobody is hurt.
--   Spawn(player, forced?) -> (ok, why)  DEV `pirate`; forced skips the eligibility and the roll
--   OnDelivery(driver, wentBack)         RescueService, before the pay: Go back after a chase with no hit earns the +25%
-- Workspace.Pirates holds one Model per chase, attributes: Hunting (user id), Phase ("Hunt", "Off"), At, Vel, Rel (the
-- pirate less the boat as the server sees it), Ram (where a ram landed). Player: PirateChase (a chase with no hit so far,
-- cleared by a ram or delivery), PirateBonusAt (the +25% paid: server time).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BoatLevels = require(Shared:WaitForChild("BoatLevels"))
local CraftBoard = require(Shared:WaitForChild("Ops"):WaitForChild("CraftBoard"))
local Onboarding = require(Shared:WaitForChild("Onboarding"))
local PirateBoat = require(Shared:WaitForChild("PirateBoat"))
local PirateRules = require(Shared:WaitForChild("PirateRules"))
local SeaZones = require(Shared:WaitForChild("Calls"):WaitForChild("SeaZones"))
local Simulator = require(Shared:WaitForChild("Boat"):WaitForChild("Simulator"))

local AssetLoader = require(script.Parent.Parent:WaitForChild("Assets"):WaitForChild("AssetLoader"))
local DataService = require(script.Parent.DataService)
local RescueRunService = require(script.Parent.RescueRunService)
local RescueService = require(script.Parent.RescueService)
local Telemetry = require(script.Parent:WaitForChild("TelemetryService"))
local VehicleService = require(script.Parent.VehicleService)

local PirateService = {}
PirateService.Priority = 150 -- after the services it drives

local STEP = 1 / 30 -- s, the steering
local PUBLISH = 0.1 -- s, the attributes each client smooths between
local LANTERN = Color3.fromRGB(255, 214, 130) -- the mesh's panes and lantern

type Live = {
	player: Player,
	chase: PirateRules.Chase,
	model: Model,
	zone: number,
	top: number,
	boat: Vector3, -- last seen
	off: boolean,
}

local lives: { [Player]: Live } = {}
local rollAt: { [Player]: number } = {}
local folder: Folder
local rng = Random.new()

-- The player's own hull under way: the boat, its root and its top speed (level and upgrades, no boost: 0.92x of that
-- is what a boost outruns). Helis and subs carry no TopSpeed, and CraftBoard names them anyway.
local function boatOf(player: Player): (Model?, BasePart?, number)
	local model = VehicleService.GetVehicle(player)
	local root = model and model.PrimaryPart
	local top = model and model:GetAttribute("TopSpeed")
	if
		not (model and root and type(top) == "number")
		or VehicleService.GetDriver(model) ~= player
		or CraftBoard.kind(model:GetAttribute("VehicleId")) ~= nil
	then
		return nil, nil, 0
	end
	local mult = model:GetAttribute("SpeedMultiplier")
	return model,
		root,
		top * BoatLevels.capMultiplier(top, if type(mult) == "number" then mult else 1)
end

local function survivorsOn(model: Model): number
	return tonumber(model:GetAttribute("SurvivorCount")) or 0
end

local function publish(live: Live, boat: Vector3)
	local c, model = live.chase, live.model
	model:SetAttribute("At", c.pos)
	model:SetAttribute("Vel", c.vel)
	model:SetAttribute("Rel", c.pos - Vector3.new(boat.X, 0, boat.Z))
end

local function sailOff(live: Live, why: string)
	live.off = true
	live.model:SetAttribute("Phase", "Off")
	rollAt[live.player] = os.clock() + PirateRules.COOLDOWN
	Telemetry.Custom(live.player, "Pirate", live.zone, "End", why)
end

local function remove(live: Live)
	live.model:Destroy()
	if lives[live.player] == live then
		lives[live.player] = nil
	end
end

-- The mesh and its crew, anchored and inert like the Parts; the Parts when it can't be loaded.
local function inert(model: Model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanTouch, d.CanQuery = false, false, false
			if string.find(d.Name, "_Lights", 1, true) then
				local look = d:FindFirstChildOfClass("SurfaceAppearance")
				if look then
					look:Destroy() -- Neon can't glow through a SurfaceAppearance
				end
				d.Material = Enum.Material.Neon
				d.Color = LANTERN
			end
		end
	end
end

local function buildPirate(): Model
	local boat = AssetLoader.clone(PirateBoat.ASSET)
	if not boat then
		return PirateBoat.build()
	end
	inert(boat)
	boat:ScaleTo(PirateBoat.SCALE)
	boat:PivotTo(CFrame.identity)
	for asset, offset in PirateBoat.CREW do
		local crew = AssetLoader.clone(asset)
		if crew then
			inert(crew)
			crew:ScaleTo(PirateBoat.SCALE)
			crew:PivotTo(CFrame.new(offset * PirateBoat.SCALE))
			crew.Parent = boat
		end
	end
	return boat
end

function PirateService.Spawn(player: Player, forced: boolean?): (boolean, string)
	if lives[player] then
		return false, "Already hunted"
	end
	local model, root, top = boatOf(player)
	if not (model and root) then
		return false, "No boat"
	end
	if survivorsOn(model) <= 0 then
		return false, "No survivors"
	end
	local boat = root.Position
	local zone = SeaZones.zoneAt(boat)
	if zone < 2 then
		return false, "Shallows"
	end
	if not forced then
		local inZone = 0
		for _, other in lives do
			inZone += if other.zone == zone then 1 else 0
		end
		if inZone >= PirateRules.MAX_PER_ZONE then
			return false, "Zone full"
		end
	end
	local at = PirateRules.spawnPoint(boat, root.CFrame.LookVector, top, rng:NextNumber() < 0.5)
	if not at then
		return false, "No water"
	end
	local chase = PirateRules.newChase(at, boat, root.AssemblyLinearVelocity, top)
	local pirate = buildPirate()
	pirate.Name = `Pirate{player.UserId}`
	-- seen from afar at any speed: its parts never stream out, and only the attributes change
	pirate.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	pirate:PivotTo(
		CFrame.new(at.X, Simulator.waterHeight(at.X, at.Z, Workspace:GetServerTimeNow()), at.Z)
	)
	pirate:SetAttribute("Hunting", player.UserId)
	pirate:SetAttribute("Phase", "Hunt")
	local live: Live = {
		player = player,
		chase = chase,
		model = pirate,
		zone = zone,
		top = top,
		boat = boat,
		off = false,
	}
	publish(live, boat)
	pirate.Parent = folder
	lives[player] = live
	player:SetAttribute("PirateChase", true)
	Telemetry.Custom(player, "Pirate", zone, "Spawn", tostring(model:GetAttribute("VehicleId")))
	return true, "Pirate"
end

local function ram(live: Live, boat: Model)
	local player = live.player
	local at = RescueService.KnockOverboard(boat)
	if at then
		live.model:SetAttribute("Ram", at)
	end
	RescueRunService.End(player)
	VehicleService.CancelGoBack(player)
	player:SetAttribute("PirateChase", nil)
	sailOff(live, "Hit")
end

local function stepLive(live: Live, dt: number)
	local player = live.player
	local boat, root, top = boatOf(player)
	if boat and root then
		live.boat, live.top = root.Position, top
	end
	if live.off then
		if PirateRules.stepSailOff(live.chase, live.boat, live.top, dt) then
			remove(live)
		end
		return
	end
	if not (boat and root) or survivorsOn(boat) <= 0 then
		sailOff(live, "Lost") -- delivered, or off the boat: nothing to hunt
		return
	end
	local why = PirateRules.step(live.chase, {
		boat = root.Position,
		vel = root.AssemblyLinearVelocity,
		top = top,
		ping = player:GetNetworkPing(),
		dt = dt,
	})
	if why == "Hit" then
		ram(live, boat)
	elseif why then
		sailOff(live, why)
	end
end

local function tryRoll(player: Player)
	local model, root = boatOf(player)
	if not (model and root) then
		return
	end
	local survivors = survivorsOn(model)
	local zone = SeaZones.zoneAt(root.Position)
	local data = DataService.Get(player)
	if
		PirateRules.eligible({
			survivors = survivors,
			zone = zone,
			calls = tonumber(player:GetAttribute("OpsCompletedTotal")) or 0,
			coldOpenDone = player:GetAttribute("ColdOpenDone") == true,
			coldOpenActive = player:GetAttribute("ColdOpenActive") == true,
			testRide = player:GetAttribute("TestRide") ~= nil,
			surfaceBoat = true, -- boatOf
			tutorial = not data or Onboarding.beat(Onboarding.factsOf(data)) ~= "Done",
		})
		and rng:NextNumber()
			< PirateRules.chance(zone, survivors, tonumber(model:GetAttribute("Capacity")) or 1)
	then
		PirateService.Spawn(player)
	end
end

local function stepRolls(now: number)
	for _, player in Players:GetPlayers() do
		if lives[player] then
			continue
		end
		-- the flag only means something with survivors aboard: a trip that ended at a pad or a lost boat drops it
		if player:GetAttribute("PirateChase") == true then
			local model = VehicleService.GetVehicle(player)
			if not model or survivorsOn(model) <= 0 then
				player:SetAttribute("PirateChase", nil)
			end
		end
		if now >= (rollAt[player] or 0) then
			rollAt[player] = now + PirateRules.ROLL_EVERY
			tryRoll(player)
		end
	end
end

function PirateService.OnDelivery(driver: Player, wentBack: boolean)
	if driver:GetAttribute("PirateChase") ~= true then
		return
	end
	driver:SetAttribute("PirateChase", nil)
	if wentBack then
		local now = Workspace:GetServerTimeNow()
		RescueRunService.SetEscapeBonus(driver, now + PirateRules.BONUS_WINDOW)
		driver:SetAttribute("PirateBonusAt", now)
		Telemetry.Custom(driver, "Pirate", 0, "Escaped")
	end
end

function PirateService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Pirates"
	folder.Parent = Workspace
	Players.PlayerRemoving:Connect(function(player: Player)
		rollAt[player] = nil
		local live = lives[player]
		if live then
			remove(live)
		end
	end)
end

function PirateService.Start()
	AssetLoader.preload({ PirateBoat.ASSET, "M_Chr_PirateCaptain", "M_Chr_PirateDeckhand", "M_Chr_PirateLookout" })
	local stepped, published, rolled = 0, 0, 0
	RunService.Heartbeat:Connect(function(dt: number)
		stepped += dt
		published += dt
		rolled += dt
		while stepped >= STEP do
			stepped -= STEP
			for _, live in lives do
				stepLive(live, STEP)
			end
		end
		if published >= PUBLISH then
			published = 0
			for _, live in lives do
				publish(live, live.boat)
			end
		end
		if rolled >= 1 then
			rolled = 0
			stepRolls(os.clock())
		end
	end)
end

return PirateService
