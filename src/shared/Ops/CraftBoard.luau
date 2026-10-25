--!strict
-- Ops/CraftBoard (docs/23 (h), WP-10a): may the person at `target` climb aboard this craft now? Boats keep
-- Ops/Board's rule; the helicopter winches (Heli/Winch: hover inside the ring, low, slow and level), the
-- submarine inside its ring at their depth (Sub/Dive.pickupReady). Pure; the server (AmbientRescueService) and the client
-- (auto_board) both measure the craft and ask here. Lune-tested in tests/Craft.spec.luau.
local Board = require(script.Parent.Board)
local Dive = require(script.Parent.Parent.Sub.Dive)
local VehicleConfig = require(script.Parent.Parent.Config.VehicleConfig)
local Winch = require(script.Parent.Parent.Heli.Winch)

local CraftBoard = {}

CraftBoard.DEEP = 15 -- studs under the sea: a diver (CallTypes.DiveSites are 25+ down) no boat or heli reaches

-- "Heli" | "Sub", or nil for a boat (or anything unknown).
function CraftBoard.kind(vehicleId: any): string?
	local spec = if type(vehicleId) == "string" then VehicleConfig.get(vehicleId) else nil
	return spec and spec.craft
end

-- at: the craft's root; halfBeam: half its width; speed: flat studs/s; tilt: degrees off level; waterY: the
-- sea under the craft.
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
	if kind ~= "Sub" and target.Y < waterY - CraftBoard.DEEP then
		return false -- a diver down on the seabed: only the submarine reaches them
	elseif kind == "Heli" then
		return Winch.ready(flat, -d.Y, speed, tilt, room)
	elseif kind == "Sub" then
		return Dive.pickupReady(d.X, d.Y, d.Z, speed, room)
	end
	return Board.ready(gap, speed, tilt, room)
end

return CraftBoard
