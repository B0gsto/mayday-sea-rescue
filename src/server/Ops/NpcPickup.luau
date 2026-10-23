--!strict
-- NpcPickup (2026-10-21, user): a failed rescue is never a drowning. When a call is taken over, an NPC
-- rescue boat (the RIB build, anchored and code-driven) runs in from the station side, the casualty
-- climbs aboard with the same climb as onto a player's boat (VehicleService.Climb), and the boat runs
-- back out of sight and is removed. Wordless: the player just sees someone else do it.
--
-- The race (docs/16 K15): `race` makes the same boat leave the station bays after `race.delay` s, at
-- RACE_SPEED, siren on (the CosmeticSiren contract, Config/Cosmetics/Siren) and a wake (its hull
-- velocity drives client Ocean/Wake). Alongside a casualty still in the water it asks `race.claim()`;
-- true (the call is lost to it) and it takes them, otherwise it turns for home empty-handed.
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NpcPickup = {}

NpcPickup.VEHICLE = "RIB"
NpcPickup.SPEED = 28 -- studs/s
NpcPickup.START = 140 -- studs from the casualty, toward the station
NpcPickup.REACH = 9 -- studs: alongside, the climb starts
NpcPickup.STATION = Vector3.new(-95, 0, 18) -- Bay 1: "the station side"
NpcPickup.MAX_SECONDS = 60
NpcPickup.RACE_SPEED = 42 -- studs/s: a base jet ski (69) wins from the bay; a slow start loses -- tune
NpcPickup.RACE_DELAY = 12 -- s after the call is accepted before the racer casts off -- tune
NpcPickup.RACE_SECONDS = 240

export type Race = { claim: () -> boolean, delay: number? }

-- Runs the pickup; onPicked fires once the boat has taken them away (or on any failure, so the caller
-- never waits forever). `where` returns the casualty's live position (nil once they are out of the water);
-- `release` takes them off the call and returns their model.
function NpcPickup.run(
	vehicleService: any,
	where: () -> Vector3?,
	release: () -> Model?,
	onPicked: () -> (),
	race: Race?
)
	local done = false
	local function picked()
		if not done then
			done = true
			onPicked()
		end
	end
	if race and race.delay then
		task.wait(race.delay)
	end
	local at = where()
	local ok, boat = pcall(vehicleService.BuildProp, NpcPickup.VEHICLE)
	if not at or not ok or not boat then
		picked()
		return
	end
	local speed = if race then NpcPickup.RACE_SPEED else NpcPickup.SPEED
	local home = NpcPickup.STATION - at
	home = if home.Magnitude > 1 then Vector3.new(home.X, 0, home.Z).Unit else Vector3.new(0, 0, -1)
	local pos = if race then NpcPickup.STATION else at + home * NpcPickup.START
	local function place(look: Vector3)
		boat:PivotTo(vehicleService.RestCFrame(boat, pos.X, pos.Z, look))
	end
	place(-home)
	if race then
		boat:SetAttribute("SirenTone", "Wail")
		boat:SetAttribute("SirenPattern", "Wail")
		boat:SetAttribute("SirenBy", 0)
		boat:AddTag("CosmeticSiren")
	end
	boat.Parent = Workspace
	local hull = boat.PrimaryPart :: BasePart
	local slot = hull:FindFirstChild("SurvivorSlot1") :: Attachment?
	local deadline = os.clock() + (if race then NpcPickup.RACE_SECONDS else NpcPickup.MAX_SECONDS)
	local function drive(target: Vector3, stopAt: number): boolean
		while boat.Parent and os.clock() < deadline do
			local to = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			if to.Magnitude <= stopAt then
				hull.AssemblyLinearVelocity = Vector3.zero
				return true
			end
			local dt = RunService.Heartbeat:Wait()
			pos += to.Unit * math.min(speed * dt, to.Magnitude)
			place(to.Unit)
			hull.AssemblyLinearVelocity = to.Unit * speed -- anchored: only feeds the client wake
		end
		return false
	end
	task.spawn(function()
		-- run in, the casualty drifting meanwhile
		local reached = false
		while not done and boat.Parent and os.clock() < deadline do
			local p = where()
			if not p then
				break
			end
			if drive(p, NpcPickup.REACH) then
				reached = true
				break
			end
		end
		local model = if race and not (reached and race.claim()) then nil else release()
		if model and slot then
			local _, size = model:GetBoundingBox()
			local function seat(): CFrame
				return slot.WorldCFrame * CFrame.new(0, size.Y / 2, 0)
			end
			pcall(vehicleService.Climb, model, hull, seat)
			model.Parent = boat -- rides along: the boat's PivotTo carries them
		elseif model then
			model:Destroy()
		end
		-- and away, back toward the station, gone once well clear; the call closes (the debrief
		-- covers the view) only once the player has watched them go
		speed = NpcPickup.SPEED
		deadline = os.clock() + 220 / NpcPickup.SPEED + 2
		drive(pos + home * 220, 2)
		boat:Destroy()
		picked()
	end)
end

return NpcPickup
