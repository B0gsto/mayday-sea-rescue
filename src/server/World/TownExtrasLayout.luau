--!strict
-- TownExtrasLayout (I2a): pure moored-boat placement for TownExtras, tested in tests/TownExtras.spec.luau.
-- A boat lies BOAT_OFFSET studs from its visitors' mooring buoy, bow (ATT_Moor_Bow) toward the buoy; the fixed
-- bearing puts it opposite the pick-up buoy (3.2, 2.4 studs north-east of the mooring).

local TownExtrasLayout = {}

TownExtrasLayout.BOAT_OFFSET = 9 -- studs, mooring buoy to the boat's pivot (waterline)
TownExtrasLayout.MOOR_BOW = 5.775 -- ATT_Moor_Bow, studs forward of the pivot
local BEARING = math.rad(200) -- the boat lies west-north of its buoy

export type Mooring = { id: string, x: number, z: number }
export type Moored = { id: string, cf: CFrame }

-- swinging at anchor in the harbour pool, clear of the visitors' moorings (Shared.SeamarkRules), the pontoons
-- (x -124 dock, x 130 hospital), the pier and slip, the dredged channel (|x| < 40) and the harbour mouth (z 352+)
local HARBOUR = {
	-- west of the slip, off the cold open's run from the casualty to the drop-off (ColdOpen.SHORE; was -140, 140)
	{ id = "Crabber1", asset = "M_Veh_MooredBoat_02", x = -230, z = 75, yaw = 35 },
	{ id = "Crabber2", asset = "M_Veh_MooredBoat_02", x = 60, z = 12.5, yaw = 90 },
	{ id = "Crabber3", asset = "M_Veh_MooredBoat_02", x = -270, z = 190, yaw = 120 },
	{ id = "Trawler1", asset = "M_Veh_MooredBoat_03", x = 250, z = 90, yaw = 200 },
	{ id = "Trawler2", asset = "M_Veh_MooredBoat_03", x = -160, z = 300, yaw = 15 },
	{ id = "Crabber4", asset = "M_Veh_MooredBoat_02", x = 100, z = 250, yaw = 160 },
	{ id = "Crabber5", asset = "M_Veh_MooredBoat_02", x = -90, z = 230, yaw = 300 },
	-- punts: small open boats on their own moorings, swung every which way
	{ id = "Punt1", asset = "M_Veh_MooredBoat_01", x = -215, z = 135, yaw = 30 },
	{ id = "Punt2", asset = "M_Veh_MooredBoat_01", x = 190, z = 145, yaw = 250 },
	{ id = "Punt3", asset = "M_Veh_MooredBoat_01", x = 228, z = 185, yaw = 100 },
	{ id = "Punt4", asset = "M_Veh_MooredBoat_01", x = -75, z = 120, yaw = 200 },
}

-- hull half-length / half-beam (studs, from ATT_Moor_Bow / ATT_Moor_Stern and the boarding points)
TownExtrasLayout.HULL = {
	M_Veh_MooredBoat_01 = { half = 6, beam = 2.5 },
	M_Veh_MooredBoat_02 = { half = 13.5, beam = 4.5 },
	M_Veh_MooredBoat_03 = { half = 22, beam = 7 },
}

function TownExtrasLayout.mooredBoats(moorings: { Mooring }, seaY: number): { Moored }
	local out: { Moored } = {}
	local dx = math.cos(BEARING) * TownExtrasLayout.BOAT_OFFSET
	local dz = math.sin(BEARING) * TownExtrasLayout.BOAT_OFFSET
	for _, m in moorings do
		-- local -Z (the bow) points at the buoy, i.e. along -offset
		local yaw = math.atan2(dx, dz)
		table.insert(out, {
			id = m.id,
			cf = CFrame.new(m.x + dx, seaY, m.z + dz) * CFrame.Angles(0, yaw, 0),
		})
	end
	return out
end

function TownExtrasLayout.harbourBoats(seaY: number): { Moored & { asset: string } }
	local out: { Moored & { asset: string } } = {}
	for _, b in HARBOUR do
		table.insert(out, {
			id = b.id,
			asset = b.asset,
			cf = CFrame.new(b.x, seaY, b.z) * CFrame.Angles(0, math.rad(b.yaw), 0),
		})
	end
	return out
end

return TownExtrasLayout
