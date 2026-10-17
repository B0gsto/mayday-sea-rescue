--!strict
-- VehicleConfig: per-vehicle handling and capacity. Pure data.
-- Seats and capacities from docs 02 section 4; handling notes from docs 06 section 3.2.
-- Speeds/forces have no doc source yet: all -- tune. (Character walk speed is 16 studs/s.)
--
-- floatPoints are offsets from the hull's root part in its local frame (-Z is forward, Y up),
-- one buoyancy attachment each: depth = Waves.heightAt(point) - point.Y,
-- lift = clamp(depth / draft, 0, 1) * buoyancyPerPoint (docs 06 section 3.2).

export type VehicleSpec = {
	id: string,
	displayName: string,
	topSpeed: number, -- studs/s
	accel: number, -- studs/s^2 at the throttle
	brakeDecel: number, -- studs/s^2 when reversing throttle
	turnRate: number, -- degrees/s at full lock
	seats: number, -- player seats including the driver
	survivorCapacity: number,
	hullSize: Vector3, -- greybox hull, studs
	massHint: number, -- target assembly mass (Roblox mass units); tune densities to hit it
	draft: number, -- studs of hull below the waterline at rest
	floatPoints: { Vector3 },
	lateralGrip: number, -- 0..1, sideways drag vs forward drag (keel / grip force)
	canCapsize: boolean,
	canTow: boolean,
	firePump: boolean,
}

local VehicleConfig = {}

VehicleConfig.JetSki = {
	id = "JetSki",
	displayName = "Jet Ski",
	topSpeed = 75, -- tune: fastest in calm water
	accel = 40, -- tune
	brakeDecel = 45, -- tune
	turnRate = 120, -- tune: twitchy
	seats = 1, -- 1 rider (docs 02)
	survivorCapacity = 1, -- on the rescue sled (docs 02)
	hullSize = Vector3.new(3, 1.6, 9),
	massHint = 60, -- tune
	draft = 0.6, -- tune
	floatPoints = {
		Vector3.new(-1.2, -0.8, -3.5),
		Vector3.new(1.2, -0.8, -3.5),
		Vector3.new(-1.2, -0.8, 3.5),
		Vector3.new(1.2, -0.8, 3.5),
	},
	lateralGrip = 0.7, -- tune: slides on turns
	canCapsize = true,
	canTow = false,
	firePump = false,
} :: VehicleSpec

VehicleConfig.RIB = {
	id = "RIB",
	displayName = "RIB Inflatable",
	topSpeed = 60, -- tune
	accel = 28, -- tune
	brakeDecel = 40, -- tune: quick to stop
	turnRate = 80, -- tune
	seats = 3, -- 3 crew (docs 02)
	survivorCapacity = 2, -- docs 02
	hullSize = Vector3.new(6, 2.4, 15),
	massHint = 160, -- tune: light and bouncy
	draft = 0.9, -- tune
	floatPoints = {
		Vector3.new(-2.4, -1.2, -6),
		Vector3.new(2.4, -1.2, -6),
		Vector3.new(-2.6, -1.2, 0),
		Vector3.new(2.6, -1.2, 0),
		Vector3.new(-2.4, -1.2, 6),
		Vector3.new(2.4, -1.2, 6),
	},
	lateralGrip = 0.85, -- tune
	canCapsize = true,
	canTow = true, -- tows light boats (docs 02)
	firePump = true, -- small fire pump (docs 02)
} :: VehicleSpec

-- Every vehicle id, in shop / bay menu order.
VehicleConfig.Order = { "JetSki", "RIB" }

function VehicleConfig.get(id: string): VehicleSpec?
	local spec = (VehicleConfig :: any)[id]
	if type(spec) == "table" and spec.id == id then
		return spec :: VehicleSpec
	end
	return nil
end

return VehicleConfig
