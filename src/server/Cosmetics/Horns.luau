--!strict
-- Horns (RP-M5 Horn Pack, server). Action "Horn" from a client (no arguments): the player must be
-- in the DriverSeat of a boat or jet ski, have a Horn Pack horn equipped (Cos_Horn, already
-- sanitised against the pass by CosmeticsService) and be off cooldown (the horn's length, min 2 s).
-- Then every client within the horn's range gets Cosmetics_Event "Horn" (model, hornId, userId);
-- src/client/Cosmetics/Horns plays it. The driver always gets it (their own horn is never muted).
-- Refusals answer the driver with "CosmeticRefused" ("Horn", reason) so the client can say why.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local VehicleSounds = require(Shared:WaitForChild("VehicleSounds"))

local Horns = {}
Horns.Priority = 50

local service: any = nil
local cooldowns = VehicleSounds.newCooldowns()

local function isDriver(player: Player, model: Model): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = model:FindFirstChild("DriverSeat", true)
	return humanoid ~= nil
		and seat ~= nil
		and seat:IsA("VehicleSeat")
		and (seat :: VehicleSeat).Occupant == humanoid
end

local function onHorn(player: Player)
	local model, kind = service.VehicleOf(player)
	local id = service.Equipped(player, "Horn")
	local option = service.Cosmetics.option("Horn", id)
	local now = os.clock()
	local ok, reason = VehicleSounds.checkHorn({
		hasVehicle = model ~= nil,
		isDriver = model ~= nil and isDriver(player, model),
		kind = kind,
		option = option,
		owns = function(pass: string): boolean
			return service.Owns(player, pass)
		end,
		now = now,
		readyAt = cooldowns.readyAt(player),
	})
	if not ok or not model then
		if reason ~= "cooldown" then
			service.FireClient(player, "CosmeticRefused", "Horn", reason)
		end
		return
	end
	cooldowns.mark(player, now, VehicleSounds.hornCooldown(option))
	local root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not root then
		return
	end
	local range = VehicleSounds.range(option, VehicleSounds.HORN_RANGE)
	service.FireNear((root :: BasePart).Position, range, "Horn", model, id, player.UserId)
	-- the driver's character sits on the vehicle, so FireNear reaches them; this covers a
	-- character root that streamed oddly or a seat far from the root part
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if
		not (hrp and hrp:IsA("BasePart"))
		or (hrp.Position - (root :: BasePart).Position).Magnitude > range
	then
		service.FireClient(player, "Horn", model, id, player.UserId)
	end
end

function Horns.Init(s: any)
	service = s
	s.OnAction("Horn", onHorn)
	game:GetService("Players").PlayerRemoving:Connect(function(player: Player)
		cooldowns.clear(player)
	end)
end

return Horns
