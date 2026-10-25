--!strict
-- Ops/CraftBoard (docs/23 (h), WP-10a): may the person at `target` climb aboard this craft now? Boats keep
-- Ops/Board's rule; the helicopter winches (Heli/Winch: hover inside the ring, low, slow and level), the
-- seaplane takes people only while it sits on the water (Plane/Flight.mayBoard), the submarine inside its
-- ring at their depth (Sub/Dive.pickupReady). Pure; the server (AmbientRescueService) and the client
-- (auto_board) both measure the craft and ask here. Lune-tested in tests/Craft.spec.luau.
local Board = require(script.Parent.Board)
local Dive = require(script.Parent.Parent.Sub.Dive)
local PlaneFlight = require(script.Parent.Parent.Plane.Flight)
local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)
local Winch = require(script.Parent.Parent.Heli.Winch)

local CraftBoard = {}

-- "Heli" | "Plane" | "Sub", or nil for a boat (or anything unknown).
function CraftBoard.kind(vehicleId: any): string?
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	return spec and spec.craft
end

-- at: the craft's root; halfBeam: half its width; speed: flat studs/s; tilt: degrees off level; waterY: the
-- sea under the craft (only the seaplane reads it).
function CraftBoard.ready(
	vehicleId: any,
	at: Vector3,
	halfBeam: number,
	target: Vector3,
	speed: number,
	tilt: number,
	room: boolean,
	waterY: number
): boolean
	local d = target - at
	local flat = Vector2.new(d.X, d.Z).Magnitude
	local gap = math.max(0, flat - halfBeam)
	local kind = CraftBoard.kind(vehicleId)
	if kind == "Heli" then
		return Winch.ready(flat, -d.Y, speed, tilt, room)
	elseif kind == "Plane" then
		local spec = PlaneFlight.get(vehicleId) :: PlaneFlight.Spec
		return PlaneFlight.mayBoard(
			PlaneFlight.altitude(at.Y, waterY, spec),
			gap,
			speed,
			tilt,
			room
		)
	elseif kind == "Sub" then
		return Dive.pickupReady(d.X, d.Y, d.Z, speed, room)
	end
	return Board.ready(gap, speed, tilt, room)
end

return CraftBoard
