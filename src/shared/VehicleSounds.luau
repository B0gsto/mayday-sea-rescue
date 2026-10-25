--!strict
-- VehicleSounds (RP-M5 Horn Pack / Siren Pack): the pure rules behind cosmetic horns and sirens.
-- No Roblox services; the server modules (src/server/Cosmetics/Horns, Sirens) and the client
-- players (src/client/Cosmetics/Horns, Sirens) call these. Option tables come from
-- Config/Cosmetics/Horn.luau and Siren.luau.
--
--   VehicleSounds.playable(option): boolean          the option carries a pack clip
--   VehicleSounds.checkHorn(req): (ok, reason)       may this player sound this horn now?
--   VehicleSounds.checkSiren(req): (ok, reason)      may this player switch this siren on?
--   VehicleSounds.hornCooldown(option): number       s between two horns of this option
--   VehicleSounds.range(option, fallback): number    studs, clamped to RANGE_MIN..RANGE_MAX
--   VehicleSounds.patternOf(option?): string         light pattern id, "" for none
--   VehicleSounds.sirenAttributes(option?): (tone, pattern)   model attributes ("" , "" when off)
--   VehicleSounds.loopRegion(option): (start, finish)?        validated LoopRegion seconds
--   VehicleSounds.audible(isOwn, muted): boolean     owners always hear their own
--   VehicleSounds.newCooldowns() -> { ready(key, now, seconds), mark(key, now), clear(key) }
--
-- Reasons (stable strings, shown to the player by the client when useful):
--   "no_vehicle" "not_driver" "bad_kind" "no_pack_option" "not_owned" "cooldown" "no_tasking"
local VehicleSounds = {}

VehicleSounds.KINDS = { Boat = true, JetSki = true } :: { [string]: boolean }
VehicleSounds.PATTERNS = { "Wail", "Yelp", "HiLo", "Phaser" }
VehicleSounds.MIN_HORN_COOLDOWN = 2 -- s
VehicleSounds.RANGE_MIN = 60 -- studs
VehicleSounds.RANGE_MAX = 900
VehicleSounds.HORN_RANGE = 500 -- default when an option names none
VehicleSounds.SIREN_RANGE = 600

VehicleSounds.Reasons = {
	no_vehicle = "Drive a vehicle to use it.",
	not_driver = "Only the driver can use it.",
	bad_kind = "Not on this vehicle.",
	no_pack_option = "Equip a pack option first (Settings, Owned items).",
	not_owned = "You do not own this pack.",
	cooldown = "Wait a moment.",
	no_tasking = "Sirens sound only on a tasking.",
} :: { [string]: string }

export type Option = { id: string, name: string, pass: string?, [string]: any }

export type Request = {
	hasVehicle: boolean,
	isDriver: boolean,
	kind: string?,
	option: Option?,
	owns: (string) -> boolean,
	-- horns
	now: number?,
	readyAt: number?, -- the player's cooldown ends at this time (0 / nil = ready)
	-- sirens
	onTasking: boolean?,
	requireTasking: boolean?,
}

function VehicleSounds.playable(option: Option?): boolean
	return option ~= nil and type(option.clip) == "string" and option.clip ~= ""
end

-- the checks shared by horns and sirens, in the order the player would fix them
local function common(req: Request): (boolean, string)
	if not req.hasVehicle then
		return false, "no_vehicle"
	end
	if not req.isDriver then
		return false, "not_driver"
	end
	if type(req.kind) ~= "string" or not VehicleSounds.KINDS[req.kind :: string] then
		return false, "bad_kind"
	end
	local option = req.option
	if not option or not VehicleSounds.playable(option) then
		return false, "no_pack_option"
	end
	if option.pass ~= nil and not req.owns(option.pass) then
		return false, "not_owned"
	end
	return true, ""
end

function VehicleSounds.checkHorn(req: Request): (boolean, string)
	local ok, reason = common(req)
	if not ok then
		return false, reason
	end
	if (req.now or 0) < (req.readyAt or 0) then
		return false, "cooldown"
	end
	return true, ""
end

function VehicleSounds.checkSiren(req: Request): (boolean, string)
	local ok, reason = common(req)
	if not ok then
		return false, reason
	end
	if req.requireTasking ~= false and req.onTasking ~= true then
		return false, "no_tasking"
	end
	return true, ""
end

function VehicleSounds.hornCooldown(option: Option?): number
	local length = option and option.length
	if type(length) ~= "number" or length ~= length then
		return VehicleSounds.MIN_HORN_COOLDOWN
	end
	return math.max(VehicleSounds.MIN_HORN_COOLDOWN, length)
end

function VehicleSounds.range(option: Option?, fallback: number): number
	local r = option and option.range
	if type(r) ~= "number" or r ~= r then
		r = fallback
	end
	return math.clamp(r :: number, VehicleSounds.RANGE_MIN, VehicleSounds.RANGE_MAX)
end

function VehicleSounds.patternOf(option: Option?): string
	local p = option and option.pattern
	if type(p) == "string" and table.find(VehicleSounds.PATTERNS, p) then
		return p
	end
	return ""
end

-- the SirenTone / SirenPattern attribute pair for a sounding option (nil = off)
function VehicleSounds.sirenAttributes(option: Option?): (string, string)
	if not option or not VehicleSounds.playable(option) then
		return "", ""
	end
	return option.id, VehicleSounds.patternOf(option)
end

-- LoopRegion bounds when the option names a sane pair, else nil (loop the whole clip)
function VehicleSounds.loopRegion(option: Option?): (number?, number?)
	local a = option and option.loopStart
	local b = option and option.loopEnd
	if type(a) == "number" and type(b) == "number" and a >= 0 and b - a >= 0.5 then
		return a, b
	end
	return nil, nil
end

function VehicleSounds.audible(isOwn: boolean, muted: boolean): boolean
	return isOwn or not muted
end

export type Cooldowns = {
	readyAt: (key: any) -> number,
	ready: (key: any, now: number) -> boolean,
	mark: (key: any, now: number, seconds: number) -> (),
	clear: (key: any) -> (),
}

function VehicleSounds.newCooldowns(): Cooldowns
	local until_: { [any]: number } = {}
	local self = {}
	function self.readyAt(key: any): number
		return until_[key] or 0
	end
	function self.ready(key: any, now: number): boolean
		return now >= (until_[key] or 0)
	end
	function self.mark(key: any, now: number, seconds: number)
		until_[key] = now + seconds
	end
	function self.clear(key: any)
		until_[key] = nil
	end
	return self :: Cooldowns
end

-- config problems for a Horn / Siren slot table (empty when fine); used by the specs
function VehicleSounds.validate(slot: { options: { Option } }, isSiren: boolean): { string }
	local out = {}
	for _, o in slot.options do
		if o.pass == nil then
			if VehicleSounds.playable(o) then
				table.insert(out, `{o.id}: the free option must not carry a pack clip`)
			end
			continue
		end
		if not VehicleSounds.playable(o) then
			table.insert(out, `{o.id}: no clip`)
		end
		if type(o.label) ~= "string" or #o.label == 0 or #o.label > 14 then
			table.insert(out, `{o.id}: label missing or longer than 14`)
		end
		if type(o.range) ~= "number" then
			table.insert(out, `{o.id}: no range`)
		end
		if isSiren then
			if VehicleSounds.patternOf(o) == "" then
				table.insert(out, `{o.id}: unknown pattern`)
			end
			if VehicleSounds.loopRegion(o) == nil then
				table.insert(out, `{o.id}: no loop region`)
			end
		elseif type(o.length) ~= "number" or o.length <= 0 then
			table.insert(out, `{o.id}: no length`)
		end
	end
	return out
end

return VehicleSounds
