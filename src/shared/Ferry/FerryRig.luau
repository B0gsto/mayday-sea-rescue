--!strict
-- FerryRig: how the Capsized Ferry scene places the C2 art (M_Veh_GaleQueen, M_Sea_Liferaft; art/status/C2b.csv)
-- on RescueService's floaters. Pure data and maths, Lune-tested in tests/MechFerryRig.spec.luau. Used by
-- src/server/Services/RescueService.luau (build) and src/client/Mechanics/hull_knock.luau (hull frame).
--
-- Frames (studs). Asset pivot space: the authored pivot, keel bottom centre, upright, bow -Z (AssetIds.Attachments
-- are in it). Ferry floater frame: RescueService rolls it 72 deg about its Z (f.tilt, +X goes up), its origin
-- AXIS_ABOVE_SEA above the sea surface. The roll axis is the art's review axis, ROLL_AXIS_Y above the keel at
-- midships (render_sheet.py 'capsized': 2 m, sea 0.6 m below it; build.py hang() ends the Damage part's loose lines
-- at 1.0 m rolled height, LINE_END_BELOW_AXIS under the axis). Raft floater frame: the sea surface at the raft's
-- ATT_Waterline (the tube centre), upright.

local FerryRig = {}

FerryRig.FERRY = "M_Veh_GaleQueen"
FerryRig.RAFT = "M_Sea_Liferaft"
FerryRig.LOD = "LOD0"

FerryRig.TILT = math.rad(72) -- greybox tilt CFrame.Angles(0, 0, TILT), kept for the art
FerryRig.ROLL_AXIS_Y = 6 -- 2 m above the keel bottom
FerryRig.LINE_END_BELOW_AXIS = 3 -- the Damage lines end 1.0 m rolled height = 3 studs under the axis
-- The art put the sea 1.8 studs under the axis (lines 1.2 under water). In game the storm sea is sampled at
-- midships only, so she sits SINK studs deeper: the hanging lines still reach the water on the wave troughs
-- along her 63-stud length (Studio check, docs in RescueService.buildFerry).
FerryRig.SINK = 0.6
FerryRig.AXIS_ABOVE_SEA = 1.8 - FerryRig.SINK
FerryRig.HULL_LENGTH = 62.8 -- Hull MeshPart bbox length (the HullKnock axis)
FerryRig.KNOCKS = 5
FerryRig.RAFT_SEATS = 6
FerryRig.SEAT_TORSO = 1.3 -- studs from a seat attachment up to a sitting casualty's torso centre (as the dinghy)

-- C2 part tokens (MeshPart "M_Veh_GaleQueen_<token>_LOD0"): which ship state shows each. Others always show.
FerryRig.STATE_PARTS = {
	Damage = "Capsized",
	GrabLines = "Capsized",
	Undamaged = "Upright",
} :: { [string]: string }

export type Atts = { [string]: Vector3 }

local function two(i: number): string
	return string.format("%02d", i)
end

function FerryRig.knockName(i: number): string
	return "ATT_Knock_" .. two(i)
end

function FerryRig.liferaftName(i: number): string
	return "ATT_Liferaft_" .. two(i)
end

function FerryRig.seatName(i: number): string
	return "ATT_Seat_" .. two(i)
end

-- The C2 token of an asset MeshPart name ("M_Veh_GaleQueen_Damage_LOD0" -> "Damage"); the bare name when it has
-- no asset prefix ("Hull" after RescueService renames it).
function FerryRig.token(name: string): string
	local t = string.match(name, "^M_%a+_%w+_(%w+)_LOD%d$")
	return t or name
end

-- Is a part with this name visible in this state? ("Capsized" or "Upright")
function FerryRig.visibleIn(name: string, state: string): boolean
	local only = FerryRig.STATE_PARTS[FerryRig.token(name)]
	return only == nil or only == state
end

-- Midships along the length (between ATT_Bow and ATT_Stern), pivot space Z.
function FerryRig.midZ(atts: Atts): number
	local bow, stern = atts.ATT_Bow, atts.ATT_Stern
	if bow and stern then
		return (bow.Z + stern.Z) / 2
	end
	return 0
end

-- Ferry floater frame -> asset pivot (put the roll axis at midships on the floater origin).
function FerryRig.ferryOffset(atts: Atts): CFrame
	return CFrame.new(0, -FerryRig.ROLL_AXIS_Y, -FerryRig.midZ(atts))
end

-- The hull's knock axis in pivot space: midships on the roll axis, asset orientation (length along Z).
function FerryRig.hullAxis(atts: Atts): CFrame
	return CFrame.new(0, FerryRig.ROLL_AXIS_Y, FerryRig.midZ(atts))
end

-- Height of a pivot-space point above the floater origin once rolled (the art's world_z, minus the axis).
function FerryRig.rolledHeight(p: Vector3): number
	local y = p.Y - FerryRig.ROLL_AXIS_Y
	return p.X * math.sin(FerryRig.TILT) + y * math.cos(FerryRig.TILT)
end

-- Horizontal offset of a pivot-space point from the axis once rolled (+ toward the floater's +X, the keel side).
function FerryRig.rolledAcross(p: Vector3): number
	local y = p.Y - FerryRig.ROLL_AXIS_Y
	return p.X * math.cos(FerryRig.TILT) - y * math.sin(FerryRig.TILT)
end

-- How far under the calm sea the Damage part's loose lines end (studs, > 0 = in the water).
function FerryRig.lineEndDepth(): number
	return FerryRig.LINE_END_BELOW_AXIS - FerryRig.AXIS_ABOVE_SEA
end

-- The air pocket in pivot space: the asset's ATT_AirPocket (authored under compartment 4) moved along the hull
-- to the compartment HullKnock.pocketCompartment picked for this operation.
function FerryRig.pocketPoint(atts: Atts, pocket: number): Vector3?
	local base = atts.ATT_AirPocket
	local knock = atts[FerryRig.knockName(pocket)]
	if not base then
		return nil
	end
	return Vector3.new(base.X, base.Y, if knock then knock.Z else base.Z)
end

-- Footprint of the rolled ferry in the floater's horizontal frame (x across, + = keel side; z along), studs:
-- the superstructure lies out to -X (masthead about -25), the bottom to about +6.
FerryRig.FOOTPRINT = { minX = -27, maxX = 8, minZ = -33, maxZ = 33 }
FerryRig.CLEAR_MARGIN = 3

-- Pushes a point (floater horizontal frame) out of the footprint to the nearest side, plus the margin, so
-- no casualty floats inside the hull. Returns the point unchanged when it is already clear.
function FerryRig.pushClear(x: number, z: number): (number, number)
	local f, m = FerryRig.FOOTPRINT, FerryRig.CLEAR_MARGIN
	local minX, maxX, minZ, maxZ = f.minX - m, f.maxX + m, f.minZ - m, f.maxZ + m
	if x <= minX or x >= maxX or z <= minZ or z >= maxZ then
		return x, z
	end
	local dl, dr, df, db = x - minX, maxX - x, z - minZ, maxZ - z
	local best = math.min(dl, dr, df, db)
	if best == dr then
		return maxX, z
	elseif best == dl then
		return minX, z
	elseif best == df then
		return x, minZ
	end
	return x, maxZ
end

-- The deployed liferafts: which canister (ATT_Liferaft_nn, painter end) each floated off from, and where it
-- rides in the floater's horizontal frame (x across, z along). Canisters 1 and 2 are on the low (-X) side
-- (hydrostatic release under water); 3 stays in its cradle, 4 is torn out in the Damage part. They lie off the
-- deck side, past the superstructure, held on their painters.
FerryRig.RAFTS = {
	{ canister = 1, x = -36, z = 1, yaw = math.rad(80) },
	{ canister = 2, x = -34, z = 16, yaw = math.rad(110) },
}

-- Raft floater frame -> raft pivot: the sea surface at ATT_Waterline (the tube centre).
function FerryRig.raftOffset(raft: Atts): CFrame
	local w = raft.ATT_Waterline or Vector3.zero
	return CFrame.new(-w)
end

-- Where a casualty sitting at seat i rides on the raft floater: torso centre SEAT_TORSO above the seat
-- attachment, facing the raft's centre.
function FerryRig.seatOffset(raft: Atts, i: number): CFrame?
	local seat = raft[FerryRig.seatName(i)]
	if not seat then
		return nil
	end
	local centre = raft.ATT_Waterline or Vector3.zero
	local torso = seat + Vector3.new(0, FerryRig.SEAT_TORSO, 0)
	local look = Vector3.new(centre.X, torso.Y, centre.Z) - torso
	local cf = if look.Magnitude > 0.05
		then CFrame.lookAt(torso, torso + look.Unit)
		else CFrame.new(torso)
	return FerryRig.raftOffset(raft) * cf
end

-- Seat fill order: opposite pairs first so two or three people trim the raft.
FerryRig.SEAT_ORDER = { 1, 4, 2, 5, 3, 6 }

export type Seat = { raft: number, seat: number }

-- Which casualties sit in the rafts: the last floor(count / 2) of them (at most every seat), alternating rafts,
-- seats in SEAT_ORDER. Returns victim index -> { raft, seat }; the rest are in the water.
function FerryRig.assignSeats(count: number, rafts: number?, seats: number?): { [number]: Seat }
	local nRafts = rafts or #FerryRig.RAFTS
	local nSeats = math.min(seats or FerryRig.RAFT_SEATS, #FerryRig.SEAT_ORDER)
	local out: { [number]: Seat } = {}
	if nRafts <= 0 or nSeats <= 0 then
		return out
	end
	local n = math.min(math.floor(count / 2), nRafts * nSeats)
	for k = 1, n do
		local victim = count - n + k
		out[victim] = {
			raft = (k - 1) % nRafts + 1,
			seat = FerryRig.SEAT_ORDER[(k - 1) // nRafts + 1],
		}
	end
	return out
end

return FerryRig
