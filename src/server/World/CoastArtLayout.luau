--!strict
-- CoastArtLayout: the placement data behind CoastArt (G75: the coast and seabed art from I2f). Unit-tested in
-- tests/CoastArt.spec.luau. Studs, +X east, -Z north, Y up; yaw is radians for CFrame.Angles(0, yaw, 0).
--
-- Kelp beds come from WorldConfig.KelpBeds; sand ripples on the seabed (docs/10 section 4.2).

local CoastArtLayout = {}

-- The mail seaplane replaces its greybox POI: origin is the float waterline, so it sits a little proud of the sand.
CoastArtLayout.Seaplane = {
	asset = "M_Sea_MailSeaplane",
	poi = "MailSeaplane",
	lift = 1.4,
}

-- bed: WorldConfig.KelpBeds id; inner: keep the plants off the very centre where the scatter starts.
CoastArtLayout.Kelp = {
	{ bed = "SkerriesKelp", count = 45, seed = 7102, inner = 30, lod = "LOD1", piece = 2 },
}

-- One patch per spot, so the ripples read as separate sand patches, not a line.
CoastArtLayout.Ripples = {
	{ x = 700, z = 690, yaw = 0.3, keep = "M_Sea_SandRipples_PatchA_LOD0" },
	{ x = 930, z = 760, yaw = 1.4, keep = "M_Sea_SandRipples_PatchB_LOD0" },
	{ x = 1130, z = 860, yaw = 2.2, keep = "M_Sea_SandRipples_PatchC_LOD0" },
	{ x = 790, z = 930, yaw = 0.8, keep = "M_Sea_SandRipples_PatchD_LOD0" },
	{ x = 620, z = 620, yaw = 1.9, keep = "M_Sea_SandRipples_PatchA_LOD0" },
}

-- Deterministic even disk scatter (golden-angle spiral with a little jitter from a fixed seed).
function CoastArtLayout.scatter(
	center: Vector3,
	radius: number,
	count: number,
	seed: number,
	inner: number?
): { Vector3 }
	local lo = inner or 0
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	local function rand(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
	local out: { Vector3 } = {}
	local golden = math.pi * (3 - math.sqrt(5))
	for i = 1, count do
		local t = (i - 0.5) / count
		local r = math.min(radius, lo + (radius - lo) * math.sqrt(t) * (0.9 + rand() * 0.1))
		local a = i * golden + (rand() - 0.5) * 0.35
		table.insert(
			out,
			Vector3.new(center.X + math.cos(a) * r, center.Y, center.Z + math.sin(a) * r)
		)
	end
	return out
end

return CoastArtLayout
