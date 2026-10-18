--!strict
-- CottageLights: the pure rules behind CottageRig (H3 cottages M_Bld_Cottage_01..06), unit-tested in
-- tests/CottageRig.spec.luau.
--
--   CottageLights.kind(partName) -> "glow" | "glass" | nil
--       glow:  the GlassLit mesh (M_Bld_Cottage_GlassLit_NN_LODk: lit panes + lantern cores)
--       glass: the window / fanlight glass (M_Bld_Cottage_Glass_NN_LODk), Transparency ~0.35 over the room backplate
--   CottageLights.lightsOn(preset)              lights + glow at night or in a storm (ChandleryRig.preset() names)
--   CottageLights.smokeOn(preset, weatherState) chimney smoke in cold weather (anything but a clear day) or a storm
--   CottageLights.stacks(points, gap?)          one smoke point per chimney stack: drops pots within `gap` studs
--                                               (default 2.5) of one already kept, in the given order

local CottageLights = {}

function CottageLights.kind(name: string): string?
	if string.find(name, "_GlassLit_", 1, true) then
		return "glow"
	elseif string.find(name, "_Glass_", 1, true) then
		return "glass"
	end
	return nil
end

function CottageLights.lightsOn(preset: string): boolean
	return preset == "Night" or preset == "Storm"
end

function CottageLights.smokeOn(preset: string, weatherState: string): boolean
	if weatherState == "Warning" or weatherState == "Storm" or weatherState == "Clearing" then
		return true
	end
	return preset ~= "Clear"
end

function CottageLights.stacks(points: { Vector3 }, gap: number?): { number }
	local reach = gap or 2.5
	local kept: { number } = {}
	for i, p in points do
		local near = false
		for _, k in kept do
			if (points[k] - p).Magnitude < reach then
				near = true
				break
			end
		end
		if not near then
			table.insert(kept, i)
		end
	end
	return kept
end

return CottageLights
