--!strict
-- PetSeat: real-world pet sizes and where a pet rides on a craft. Pure data plus lookups; safe
-- to load in Lune (tests/PetSeat.spec.luau).
--
-- Scale: the code-built WildlifeRig animals are chunky (2-5 studs), so each species is scaled to
-- its real head height or body length. 1 m = 3 studs, the same scale as VehicleConfig, and an R15
-- character is about 5 studs tall. `built` is the rig's nose-to-tail or head-top extent in studs.
--
-- Seats: the builder puts a PetSeat attachment on the hull root (Boat/Builder). Each is low and
-- out of the driver's forward view and the chase camera: the jet ski's pet rides at the aft end
-- of the rescue sled behind the rider, the RIB's on the starboard aft deck behind the crew, and
-- the lifeboat's on the foredeck ahead of the wheelhouse. The fallback anchors let the client
-- seat a pet on a craft built before the PetSeat attachment existed.

export type Size = {
	metres: number, -- real head height or body length
	built: number, -- the same extent on the built rig (studs)
}

export type Seat = {
	anchor: string, -- fallback attachment on the hull root
	offset: Vector3, -- fallback offset from that attachment (studs)
	yaw: number, -- local facing (the jet ski's pet looks back at the rider)
	at: Vector3?, -- hull-root point for the built PetSeat attachment
}

local PetSeat = {}

PetSeat.STUDS_PER_METRE = 3
PetSeat.Sizes = {
	SealPup = { metres = 0.9, built = 4.0 }, -- nose to tail
	Puffin = { metres = 0.3, built = 2.55 }, -- head height
	Otter = { metres = 1.0, built = 5.08 }, -- nose to tail
	Turtle = { metres = 0.6, built = 2.7 }, -- shell length
	Gull = { metres = 0.45, built = 2.27 }, -- head height
} :: { [string]: Size }

PetSeat.Seats = {
	JetSki = {
		anchor = "SurvivorSlot1",
		offset = Vector3.new(0, 0, 1.2),
		yaw = math.pi,
	},
	RIB = {
		anchor = "TowHitch",
		offset = Vector3.new(1.5, -0.5, -2.4),
		yaw = 0,
		at = Vector3.new(1.5, 0.1, 9.0),
	},
	Lifeboat = {
		anchor = "BowPoint",
		offset = Vector3.new(0, 2.9, 8.4),
		yaw = 0,
		at = Vector3.new(0, 3.55, -16.5),
	},
} :: { [string]: Seat }
PetSeat.Fallback = { anchor = "BowPoint", offset = Vector3.new(0, 0.3, 0), yaw = 0 } :: Seat

-- The scale factor that turns the built rig into the species' real-world size.
function PetSeat.scaleFor(speciesId: string): number
	local size = PetSeat.Sizes[speciesId]
	if not size then
		return 1
	end
	return size.metres * PetSeat.STUDS_PER_METRE / size.built
end

-- The hull-root point for the PetSeat attachment. The jet ski's seat follows its survivor slot
-- so it sits on the sled surface of both the asset and the greybox hull.
function PetSeat.builderPoint(vehicleId: string, slots: { Vector3 }): Vector3?
	local seat = PetSeat.Seats[vehicleId]
	if not seat then
		return nil
	end
	if seat.at then
		return seat.at
	end
	local slot = slots[1]
	return if slot then slot + seat.offset else nil
end

-- No land vehicle ships a PetSeat: the pet rides on the rear of the roof / load bed, just above
-- the hull's bounding box. Returns the offset in the box's frame.
function PetSeat.landSeat(size: Vector3): CFrame
	return CFrame.new(0, size.Y * 0.5, size.Z * 0.25)
end

-- Picks the anchor and local offset for the client. A craft with a built PetSeat uses it; an
-- older or unknown hull falls back to a known attachment (bow when it has nothing else).
function PetSeat.choose(vehicleId: string, has: ((string) -> boolean)?): (string, Vector3, number)
	local seat = PetSeat.Seats[vehicleId] or PetSeat.Fallback
	if not has or has("PetSeat") then
		return "PetSeat", Vector3.zero, seat.yaw
	end
	return seat.anchor, seat.offset, seat.yaw
end

return PetSeat
