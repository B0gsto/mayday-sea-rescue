--!strict
-- LiveryPattern (G38, pure): the code-made trim that makes a livery read from 30-60 studs.
-- The uploaded RIB / jet ski meshes only take flat tints (LiveryPaint), so a scheme needs a
-- contrasting band plus a pattern in geometry. Liveries (server) welds the returned plates to the
-- hull, tubes and deck; the colours come from the livery option (stripe / glow).
--
--   LiveryPattern.plan(pattern, surface, size) -> { Spec }
--     pattern: "band" | "twin" | "stripes" | "chevron" | "glow" | "lights" (unknown -> band)
--     surface: "hull" | "tube" | "deck"
--     size:    the anchor part's Size (local X beam, Y up, Z length)
-- Each Spec is in the anchor part's local space: offset and size in studs, yaw radians about Y,
-- glow = use the option's glow colour and a Neon material. Both hull sides are returned.
type Spec = {
	offset: Vector3,
	size: Vector3,
	yaw: number,
	glow: boolean,
}

local LiveryPattern = {}

local PLATE = 0.1
local TUBE_PLATE = 0.12
local DECK_PLATE = 0.06

local function add(out: { Spec }, offset: Vector3, size: Vector3, yaw: number?, glow: boolean?)
	table.insert(out, {
		offset = offset,
		size = size,
		yaw = yaw or 0,
		glow = glow == true,
	})
end

local function hull(pattern: string, size: Vector3): { Spec }
	local out: { Spec } = {}
	local len = size.Z * 0.55
	local height = math.min(0.8, size.Y * 0.32)
	local x = size.X / 2 + PLATE / 2
	-- above the resting waterline (the hull bbox bottom is well below it): a band at the bbox
	-- middle would be submerged on a RIB
	local low = size.Y * 0.34
	for _, side in { -1, 1 } do
		local sx = x * side
		if pattern == "twin" then
			local h = math.min(0.3, size.Y * 0.13)
			add(out, Vector3.new(sx, size.Y * 0.3, 0), Vector3.new(PLATE, h, len))
			add(out, Vector3.new(sx, size.Y * 0.46, 0), Vector3.new(PLATE, h, len))
		elseif pattern == "stripes" then
			local h = math.min(0.16, size.Y * 0.07)
			for _, f in { 0.18, 0.32, 0.46 } do
				add(out, Vector3.new(sx, size.Y * f, 0), Vector3.new(PLATE, h, len * 1.08))
			end
		elseif pattern == "chevron" then
			for _, z0 in { -1.5, 1.5 } do
				add(out, Vector3.new(sx, low, z0 - 0.55), Vector3.new(PLATE, 0.32, 1.5), 0.68)
				add(out, Vector3.new(sx, low, z0 + 0.55), Vector3.new(PLATE, 0.32, 1.5), -0.68)
			end
		elseif pattern == "glow" then
			add(out, Vector3.new(sx, size.Y * 0.34, 0), Vector3.new(PLATE, 0.26, len), 0, true)
			add(out, Vector3.new(sx, size.Y * 0.48, 0), Vector3.new(PLATE, 0.16, len), 0, true)
		elseif pattern == "lights" then
			-- two strings of short neon dashes, like fairy lights along the hull
			local span = size.Z * 0.9
			for _, y in { size.Y * 0.36, size.Y * 0.5 } do
				for i = 1, 7 do
					local z = -span / 2 + (i - 0.5) * (span / 7)
					add(out, Vector3.new(sx, y, z), Vector3.new(PLATE, 0.18, 0.7), 0, true)
				end
			end
		else
			add(out, Vector3.new(sx, low, 0), Vector3.new(PLATE, height, len))
		end
	end
	return out
end

local function tube(pattern: string, size: Vector3): { Spec }
	local out: { Spec } = {}
	local glow = pattern == "glow"
	local h = if glow then 0.5 else 0.42
	local x = size.X / 2 + 0.03 -- proud of the tube's widest point so it cannot be swallowed by the mesh
	for _, side in { -1, 1 } do
		add(
			out,
			Vector3.new(x * side, size.Y * 0.05, 0),
			Vector3.new(TUBE_PLATE, h, size.Z * 0.5),
			0,
			glow
		)
	end
	return out
end

local function deck(pattern: string, size: Vector3): { Spec }
	local out: { Spec } = {}
	-- the hull bbox top is the deck sole; 0.35 keeps the pattern on the open foredeck, clear of the
	-- console and the seat, where the chase camera sees it
	local y = size.Y / 2 + 0.35
	local z = -size.Z * 0.2 -- forward of the console
	local len = size.Z * 0.42
	if pattern == "twin" then
		for _, x in { -0.7, 0.7 } do
			add(out, Vector3.new(x, y, z), Vector3.new(0.4, DECK_PLATE, len))
		end
	elseif pattern == "stripes" then
		for _, x in { -1.1, 0, 1.1 } do
			add(out, Vector3.new(x, y, z), Vector3.new(0.3, DECK_PLATE, len * 1.05))
		end
	elseif pattern == "chevron" then
		for _, f in { 1.35, 0.65 } do
			local z0 = z * f
			for _, side in { -1, 1 } do
				add(
					out,
					Vector3.new(0.7 * side, y, z0 + 0.6 * side),
					Vector3.new(0.4, DECK_PLATE, 2.2),
					0.6 * side
				)
			end
		end
	elseif pattern == "glow" then
		for _, x in { -1.3, 1.3 } do
			add(out, Vector3.new(x, y, z), Vector3.new(0.34, DECK_PLATE, len), 0, true)
		end
	elseif pattern == "lights" then
		for _, x in { -1.3, 1.3 } do
			for i = 1, 5 do
				add(
					out,
					Vector3.new(x, y, z - len / 2 + (i - 0.5) * (len / 5)),
					Vector3.new(0.28, DECK_PLATE, 0.6),
					0,
					true
				)
			end
		end
	else
		add(out, Vector3.new(0, y, z), Vector3.new(0.6, DECK_PLATE, len))
	end
	return out
end

local KNOWN =
	{ band = true, twin = true, stripes = true, chevron = true, glow = true, lights = true }

function LiveryPattern.known(pattern: string?): boolean
	return pattern ~= nil and KNOWN[pattern] == true
end

function LiveryPattern.plan(pattern: string?, surface: string, size: Vector3): { Spec }
	local p = if pattern and KNOWN[pattern] then pattern else "band"
	if surface == "tube" then
		return tube(p, size)
	elseif surface == "deck" then
		return deck(p, size)
	end
	return hull(p, size)
end

return LiveryPattern
