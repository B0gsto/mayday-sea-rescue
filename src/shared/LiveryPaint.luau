--!strict
-- LiveryPaint (RP-M5 E1, pure): which part of a vehicle takes which livery colour.
-- Used by src/server/Cosmetics/Liveries (applies it) and tests/Livery.spec.luau.
--
-- Two kinds of paintable parts:
--   * uploaded MeshParts (RIB, jet ski, jet ski rider close-up) with SurfaceAppearances: the part is
--     matched by name (<asset>_<Token>[_LODn]) and repainted by swapping in a map-only
--     SurfaceAppearance of the same texture set (normal + roughness + metalness, no ColorMap) whose
--     Color is the livery colour; wet uses the set's wet roughness and a darker colour.
--   * greybox Parts (cars, greybox boats) carry a "Paint" attribute set by the builders:
--     "Body" | "Secondary" | "Stripe1" | "Stripe2"; their Color is set directly.
-- Parts that match nothing (seats, deck, consoles, engines, glass, lamps) keep the stock look.

local LiveryPaint = {}

export type Role = "primary" | "secondary" | "stripe" | "stripe2" | "trim"
export type MeshRule = { set: string, role: Role }

-- asset -> name token -> rule. Sets are the AssetLoader texture sets (AssetLoader.PART_SETS).
LiveryPaint.MESH_RULES = {
	M_Veh_RIB = {
		Tubes = { set = "Hull", role = "primary" },
		Hull = { set = "Hull", role = "secondary" },
		Decals = { set = "Decals", role = "stripe" },
		AFrame = { set = "Rig", role = "trim" },
	},
	M_Veh_RIB_Helm = {
		Console = { set = "Console", role = "trim" },
	},
	M_Veh_JetSki = {
		Hull = { set = "Hull", role = "primary" },
		Decals = { set = "Hull", role = "stripe" },
		Sled = { set = "Sled", role = "secondary" },
	},
} :: { [string]: { [string]: MeshRule } }

-- longest first so M_Veh_JetSki_CloseUp is never read as M_Veh_JetSki + "CloseUp"
local ASSETS = {}
for asset in LiveryPaint.MESH_RULES do
	table.insert(ASSETS, asset)
end
table.sort(ASSETS, function(a, b)
	return #a > #b
end)

-- "Paint" attribute on greybox parts -> role
LiveryPaint.ATTR_ROLES = {
	Body = "primary",
	Secondary = "secondary",
	Stripe1 = "stripe",
	Stripe2 = "stripe2",
} :: { [string]: Role }

-- vehicles that keep their service paint (VehicleId): the galvanised trailer and the ambulance
LiveryPaint.SKIP_VEHICLES = {
	BoatTrailer = true,
	Ambulance = true,
} :: { [string]: boolean }

-- Wet paint is darker (docs/05 section 3.3: wet drops albedo value by about 20 to 30 %).
LiveryPaint.WET_FACTOR = 0.76

-- docs/05 section 3.2 reserved signal colours (sRGB) that no cosmetic may use, and the minimum
-- RGB distance a livery colour keeps from each.
LiveryPaint.SIGNALS = {
	HullOrange = Color3.fromRGB(255, 102, 0),
	HiVisYellow = Color3.fromRGB(223, 255, 0),
	SolasOrange = Color3.fromRGB(255, 90, 31),
	DistressRed = Color3.fromRGB(255, 42, 26),
	RetroSilver = Color3.fromRGB(214, 217, 220),
	WaypointGreen = Color3.fromRGB(62, 224, 122),
} :: { [string]: Color3 }
LiveryPaint.SIGNAL_MIN_DISTANCE = 40 -- in 0..255 RGB units

-- (asset, token) from a MeshPart name like "M_Veh_RIB_Tubes_LOD0"; nil when not a known asset.
function LiveryPaint.parseName(name: string): (string?, string?)
	local base = string.gsub(name, "_LOD%d+$", "")
	for _, asset in ASSETS do
		local prefix = asset .. "_"
		if string.sub(base, 1, #prefix) == prefix then
			local rest = string.sub(base, #prefix + 1)
			local token = string.match(rest, "^([%w]+)")
			return asset, token
		end
	end
	return nil, nil
end

-- the rule for an uploaded MeshPart by name, or nil (stock)
function LiveryPaint.meshRule(name: string): MeshRule?
	local asset, token = LiveryPaint.parseName(name)
	if not asset or not token then
		return nil
	end
	return LiveryPaint.MESH_RULES[asset][token]
end

-- the texture-set key the server keeps a map-only SurfaceAppearance for, e.g. "M_Veh_RIB/Hull"
function LiveryPaint.setKey(name: string): string?
	local asset = LiveryPaint.parseName(name)
	local rule = LiveryPaint.meshRule(name)
	return if asset and rule then `{asset}/{rule.set}` else nil
end

-- the role of a greybox part's "Paint" attribute, or nil
function LiveryPaint.attrRole(paint: any): Role?
	return if type(paint) == "string" then LiveryPaint.ATTR_ROLES[paint] else nil
end

-- the colour for a role in a livery option (nil for the stock option or a missing field)
function LiveryPaint.colorFor(option: { [string]: any }?, role: Role): Color3?
	if not option then
		return nil
	end
	local c = option[role]
	if typeof(c) == "Color3" then
		return c
	end
	-- stripe2 falls back to secondary, secondary to stripe
	if role == "stripe2" then
		return LiveryPaint.colorFor(option, "secondary")
	end
	return nil
end

-- true when the option actually repaints (has a primary colour); the stock option does not
function LiveryPaint.paints(option: { [string]: any }?): boolean
	return option ~= nil and typeof(option.primary) == "Color3"
end

function LiveryPaint.wet(c: Color3): Color3
	local f = LiveryPaint.WET_FACTOR
	return Color3.new(c.R * f, c.G * f, c.B * f)
end

local function dist255(a: Color3, b: Color3): number
	local dr, dg, db = (a.R - b.R) * 255, (a.G - b.G) * 255, (a.B - b.B) * 255
	return math.sqrt(dr * dr + dg * dg + db * db)
end

-- the reserved signal colour `c` is too close to, or nil
function LiveryPaint.signalClash(c: Color3): string?
	for name, s in LiveryPaint.SIGNALS do
		if dist255(c, s) < LiveryPaint.SIGNAL_MIN_DISTANCE then
			return name
		end
	end
	return nil
end

-- problems in a livery slot config (empty list = fine): every painting option has all four roles,
-- no colour clashes with a signal colour, and albedo stays in docs/05 3.3 range (30..240 value).
function LiveryPaint.validate(config: { options: { { [string]: any } } }): { string }
	local problems = {}
	for _, o in config.options do
		if not LiveryPaint.paints(o) then
			continue
		end
		for _, role in { "primary", "secondary", "stripe", "stripe2", "trim" } do
			local c = LiveryPaint.colorFor(o, role :: Role)
			if not c then
				if role ~= "trim" then -- trim is optional: nil keeps the stock A-frame / helm console
					table.insert(problems, `{o.id}: no {role} colour`)
				end
				continue
			end
			local clash = LiveryPaint.signalClash(c)
			if clash then
				table.insert(problems, `{o.id}: {role} is too close to {clash}`)
			end
			local v = math.max(c.R, c.G, c.B) * 255
			if v < 30 or v > 240 then
				table.insert(problems, `{o.id}: {role} value {math.floor(v)} outside 30..240`)
			end
		end
	end
	return problems
end

return LiveryPaint
