--!strict
-- Sirens (RP-M5 Siren Pack, server). Action "Siren" (no arguments) toggles the equipped pack tone on
-- the vehicle the player drives (boat, jet ski or car). Switching on needs: DriverSeat, a Siren Pack
-- tone equipped (Cos_Siren), and a tasking (OperationService.GetOperationOf; the car's blues follow
-- the same rule, docs 10 section 3.3). Switching off is always allowed for the player who switched
-- it on.
--
-- While a siren sounds the vehicle Model carries (contract in Config/Cosmetics/Siren.luau):
--   SirenTone = tone id, SirenPattern = its light pattern id   ("" and "" when off)
-- plus SirenBy = the UserId who switched it on (0 when off) and the CollectionService tag
-- "CosmeticSiren" (so clients find sounding vehicles as they stream in, late joiners included).
-- src/client/Cosmetics/Sirens plays the looped Sound.
-- Cars: when the car's own blues switch its "Siren" attribute on (LandVehicleService) and the
-- driver has a pack tone equipped, the pack tone sounds with them and stops with them.
-- A siren stops when the operation ends, the tone is unequipped, the owner leaves or the vehicle
-- goes. Refusals answer with "CosmeticRefused" ("Siren", reason).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleSounds = require(Shared:WaitForChild("VehicleSounds"))

local Sirens = {}
Sirens.Priority = 50

local CHECK_EVERY = 2 -- s between tasking checks of the sounding sirens
local TAG = "CosmeticSiren"

type Active = { owner: Player, tone: string, viaBlues: boolean }

local service: any = nil
local active: { [Model]: Active } = {}
local hooked: { [Model]: boolean } = {}

local function onTasking(player: Player): boolean
	local services = script.Parent.Parent:FindFirstChild("Services")
	local m = services and services:FindFirstChild("OperationService")
	if not (m and m:IsA("ModuleScript")) then
		return false
	end
	local ok, ops = pcall(require, m)
	if not (ok and type(ops) == "table" and type((ops :: any).GetOperationOf) == "function") then
		return false
	end
	local ok2, op = pcall((ops :: any).GetOperationOf, player)
	return ok2 and op ~= nil
end

local function isDriver(player: Player, model: Model): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = model:FindFirstChild("DriverSeat", true)
	return humanoid ~= nil
		and seat ~= nil
		and seat:IsA("VehicleSeat")
		and (seat :: VehicleSeat).Occupant == humanoid
end

local function setTone(
	model: Model,
	owner: Player?,
	option: VehicleSounds.Option?,
	viaBlues: boolean
)
	local tone, pattern = VehicleSounds.sirenAttributes(option)
	if tone == "" or not owner then
		active[model] = nil
	else
		active[model] = { owner = owner, tone = tone, viaBlues = viaBlues }
	end
	model:SetAttribute("SirenTone", tone)
	model:SetAttribute("SirenPattern", pattern)
	model:SetAttribute("SirenBy", if tone ~= "" and owner then owner.UserId else 0)
	if tone ~= "" then
		CollectionService:AddTag(model, TAG)
	else
		CollectionService:RemoveTag(model, TAG)
	end
end

local function stop(model: Model)
	if active[model] or (model:GetAttribute("SirenTone") or "") ~= "" then
		setTone(model, nil, nil, false)
	end
end

local function equippedOption(player: Player): VehicleSounds.Option?
	return service.Cosmetics.option("Siren", service.Equipped(player, "Siren"))
end

local function request(player: Player, model: Model?, kind: string?): (boolean, string)
	return VehicleSounds.checkSiren({
		hasVehicle = model ~= nil,
		isDriver = model ~= nil and isDriver(player, model),
		kind = kind,
		option = equippedOption(player),
		owns = function(pass: string): boolean
			return service.Owns(player, pass)
		end,
		onTasking = onTasking(player),
	})
end

local function onToggle(player: Player)
	local model, kind = service.VehicleOf(player)
	if model then
		local a = active[model]
		if a and a.owner == player then
			stop(model)
			return
		end
	end
	local ok, reason = request(player, model, kind)
	if not ok or not model then
		service.FireClient(player, "CosmeticRefused", "Siren", reason)
		return
	end
	setTone(model, player, equippedOption(player), false)
end

-- cars: follow the car's own blues ("Siren" attribute) with the equipped pack tone
local function hookCar(player: Player, model: Model)
	if hooked[model] then
		return
	end
	hooked[model] = true
	model:GetAttributeChangedSignal("Siren"):Connect(function()
		local on = model:GetAttribute("Siren") == true
		local a = active[model]
		if not on then
			if a and a.viaBlues then
				stop(model)
			end
			return
		end
		if a then
			return -- already sounding (toggled with G)
		end
		local driver = player
		if not isDriver(driver, model) then
			return
		end
		if request(driver, model, "Car") then
			setTone(model, driver, equippedOption(driver), true)
		end
	end)
	model.Destroying:Connect(function()
		hooked[model] = nil
		active[model] = nil
	end)
end

function Sirens.Init(s: any)
	service = s
	s.OnAction("Siren", onToggle)
	s.Changed:Connect(function(player: Player, slot: string, id: string)
		if slot ~= "Siren" then
			return
		end
		for model, a in active do
			if a.owner == player then
				local option = s.Cosmetics.option("Siren", id)
				if VehicleSounds.playable(option) then
					setTone(model, player, option, a.viaBlues)
				else
					stop(model)
				end
			end
		end
	end)
	s.VehicleSpawned:Connect(function(player: Player, model: Model, kind: string)
		if kind == "Car" then
			hookCar(player, model)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		for model, a in active do
			if a.owner == player then
				stop(model)
			end
		end
	end)
end

function Sirens.Start()
	while true do
		task.wait(CHECK_EVERY)
		for model, a in active do
			if not model.Parent or not a.owner.Parent then
				active[model] = nil
				if model.Parent then
					stop(model)
				end
			elseif not onTasking(a.owner) then
				stop(model)
			end
		end
	end
end

return Sirens
