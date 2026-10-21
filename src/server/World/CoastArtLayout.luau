--!strict
-- CoastArtLayout: the placement data behind CoastArt (G75: the coast and seabed art from I2f). Unit-tested in
-- tests/CoastArt.spec.luau. Studs, +X east, -Z north, Y up; yaw is radians for CFrame.Angles(0, yaw, 0).
--
-- The cliffs continue the Haven Head face (docs/10 section 1.2, docs/12 row M_Rock_Cliff_01 to _08) and leave the
-- cliff-casualty shelf at CliffRules.SITE.foot (1740, 890) clear. The ledges sit at the waterline either side of it.
-- Kelp beds come from WorldConfig.KelpBeds. The I2d clutter follows docs/10 section 4.2: a bottle field off the old
-- quay, lost pots and mooring blocks in the harbour and its approaches, sand ripples in Calm Bay.

local CoastArtLayout = {}

CoastArtLayout.Arch = {
	asset = "M_Rock_NeedlesEye",
	poi = "GullyArch",
	sink = 0.6,
}

-- The mail seaplane replaces its greybox POI: origin is the float waterline, so it sits a little proud of the sand.
CoastArtLayout.Seaplane = {
	asset = "M_Sea_MailSeaplane",
	poi = "MailSeaplane",
	lift = 1.4,
}

-- The three faces of Haven Head, each with the strip's long axis on the coast tangent.
CoastArtLayout.Cliffs = {
	{ asset = "M_Rock_Cliff_06", x = 1740, z = 960, yaw = 0.306, sink = 4 },
	{ asset = "M_Rock_Cliff_07", x = 1950, z = 780, yaw = 0.524, sink = 1 },
	{ asset = "M_Rock_Cliff_08", x = 2370, z = 650, yaw = 0, sink = 2 },
}

CoastArtLayout.Ledges = {
	{ asset = "M_Rock_Ledge_04", x = 1380, z = 760, yaw = 0.6, sink = 0.35 },
	{ asset = "M_Rock_Ledge_04", x = 1872, z = 1040, yaw = -0.4, sink = 0.35 },
	{ asset = "M_Rock_Ledge_04", x = 2300, z = 680, yaw = 0.9, sink = 0.35 },
}

-- bed: WorldConfig.KelpBeds id; inner: keep the plants off the very centre where the scatter starts.
CoastArtLayout.Kelp = {
	{ bed = "HavenHeadKelp", count = 55, seed = 7101, inner = 35, lod = "LOD0", piece = 1 },
	{ bed = "SkerriesKelp", count = 45, seed = 7102, inner = 30, lod = "LOD1", piece = 2 },
	{ bed = "WestLedgesKelp", count = 35, seed = 7103, inner = 25, lod = "LOD1", piece = 3 },
}

CoastArtLayout.BottleField = {
	x = 245,
	z = 220,
	radius = 26,
	count = 10,
	seed = 7110,
	keep = {
		"M_Sea_BottleField_Cluster_LOD0",
		"M_Sea_BottleField_Scatter_LOD0",
		"M_Sea_BottleField_Wine_LOD0",
		"M_Sea_BottleField_Beer_LOD0",
		"M_Sea_BottleField_Medicine_LOD0",
		"M_Sea_BottleField_Jar_LOD0",
	},
}

CoastArtLayout.Pots = {
	{ x = -250, z = 120, yaw = 0.4 },
	{ x = -270, z = 260, yaw = 1.9 },
	{ x = 240, z = 90, yaw = 3.1 },
	{ x = 280, z = 300, yaw = 0.9 },
	{ x = -180, z = 330, yaw = 2.4 },
	{ x = 195, z = 340, yaw = 4.2 },
}

CoastArtLayout.MooringBlocks = {
	{ x = -140, z = 430, yaw = 0.2 },
	{ x = 150, z = 460, yaw = 1.2 },
	{ x = -230, z = 520, yaw = 2.1 },
	{ x = 215, z = 540, yaw = 0.7 },
}

-- One patch per spot, so the ripples read as separate sand patches, not a line.
CoastArtLayout.Ripples = {
	{ x = 700, z = 690, yaw = 0.3, keep = "M_Sea_SandRipples_PatchA_LOD0" },
	{ x = 930, z = 760, yaw = 1.4, keep = "M_Sea_SandRipples_PatchB_LOD0" },
	{ x = 1130, z = 860, yaw = 2.2, keep = "M_Sea_SandRipples_PatchC_LOD0" },
	{ x = 790, z = 930, yaw = 0.8, keep = "M_Sea_SandRipples_PatchD_LOD0" },
	{ x = 620, z = 620, yaw = 1.9, keep = "M_Sea_SandRipples_PatchA_LOD0" },
}

-- Keep the dressing off the cliff-casualty shelf and the arch's opening (the operation sites and the eye).
CoastArtLayout.Exclusions = {
	{ x = 1740, z = 890, radius = 58 },
	{ x = 1760, z = 1066, radius = 28 },
}

-- The harbour channel (x +-40 at the mouth, x +-60 for the dredged basin) is left clear for boat traffic.
CoastArtLayout.HARBOUR = { minZ = 4, maxZ = 560, halfWidth = 60 }

function CoastArtLayout.inHarbourChannel(x: number, z: number): boolean
	local h = CoastArtLayout.HARBOUR
	return z >= h.minZ and z <= h.maxZ and math.abs(x) <= h.halfWidth
end

function CoastArtLayout.excluded(x: number, z: number, pad: number?): boolean
	for _, e in CoastArtLayout.Exclusions do
		local dx, dz = x - e.x, z - e.z
		if dx * dx + dz * dz < (e.radius + (pad or 0)) ^ 2 then
			return true
		end
	end
	return false
end

return CoastArtLayout
