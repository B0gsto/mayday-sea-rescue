--!strict
-- ArtLayout (pure): where the uploaded land-vehicle model sits on the greybox chassis, and which
-- art wheel mesh drives which raycast wheel part (src/shared/Car/Art.luau applies it).
--
-- The uploaded models are authored at their own origin (frame_offset.json): wheels on the ground,
-- forward -Z. The Builder model's root is the centre of mass at 0,0,0. The offset that puts the art
-- on the root is taken from the first wheel hub: its authored ATT_Wheel_* must land on the physics
-- wheel's rest centre (Chassis.prepare). Trailers use T1L..T2R parts but FL/FR/RL/RR or L1/L2 art
-- markers.
local Chassis = require(script.Parent.Chassis)
local LandVehicleConfig = require(script.Parent.Parent.Config.LandVehicleConfig)

type Spec = LandVehicleConfig.Spec
type Markers = { [string]: Vector3 }

local ArtLayout = {}

-- vehicle id -> uploaded asset (AssetIds.Models key)
ArtLayout.ASSETS = {
	LifeguardPickup = "M_Veh_LifeguardPickup",
	CoastguardResponse = "M_Veh_Coastguard4x4",
	BeachATV = "M_Veh_ATV",
	Ambulance = "M_Veh_Ambulance",
} :: { [string]: string }

-- trailer boat id -> uploaded trailer body
ArtLayout.TRAILER_ASSETS = {
	RIB = "M_Veh_BoatTrailer_RIB",
	JetSki = "M_Veh_BoatTrailer_JetSki",
} :: { [string]: string }
ArtLayout.DEFAULT_TRAILER = "M_Veh_BoatTrailer_RIB"

-- art wheel token -> Builder wheel part name (Chassis.prepare names)
local CAR_WHEELS = { FL = "FL", FR = "FR", RL = "RL", RR = "RR" }
local TRAILER_WHEELS = {
	FL = "T1L",
	FR = "T1R",
	RL = "T2L",
	RR = "T2R",
	L1 = "T1L",
	R1 = "T1R",
	L2 = "T2L",
	R2 = "T2R",
}

-- uploaded asset name for a vehicle id (nil when it has no art), trailer picked by boat id
function ArtLayout.assetFor(vehicleId: string, boatId: string?): string?
	if vehicleId == "BoatTrailer" then
		return ArtLayout.TRAILER_ASSETS[boatId or ""] or ArtLayout.DEFAULT_TRAILER
	end
	local spec = (LandVehicleConfig :: any)[vehicleId]
	return (if type(spec) == "table" then spec.model else nil) or ArtLayout.ASSETS[vehicleId]
end

-- Builder wheel part name for an art wheel token (FL / L1 / ...), nil for a non-wheel token
function ArtLayout.wheelPart(token: string, trailer: boolean): string?
	if trailer then
		return TRAILER_WHEELS[token]
	end
	return CAR_WHEELS[token]
end

-- Root-space offset from the art's authored origin: aligned by the first wheel hub the art has.
function ArtLayout.origin(spec: Spec, markers: Markers): Vector3
	local derived = Chassis.prepare(spec)
	local trailer = spec.class == "Trailer"
	local order: { string }
	if trailer then
		order = { "FL", "L1", "FR", "R1", "RL", "L2", "RR", "R2" }
	else
		order = { "FL", "FR", "RL", "RR" }
	end
	for _, token in order do
		local art = markers[`ATT_Wheel_{token}`]
		local partName = ArtLayout.wheelPart(token, trailer)
		if art and partName then
			for _, w in derived.wheels do
				if w.name == partName then
					return Vector3.new(0, w.centreRest.Y - art.Y, w.centreRest.Z - art.Z)
				end
			end
		end
	end
	local drive = markers.ATT_DriveAttachment
	return if drive then -drive else Vector3.zero
end

return ArtLayout
