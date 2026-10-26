--!strict
-- PetRules: the pure animal-sanctuary rules (docs/15 section 2, hook H4). No services; safe to
-- load in Lune (tests/Pets.spec.luau).
--
-- A rescued animal is added with the server's wall-clock time and recovers for
-- Wildlife.RecoverySeconds (10 real minutes). The profile flag `pets` is a flat table of scalars
-- (ProgressionRules.sanitizeFlag): n = next id, a = the active pet id (0 = none), t = fish treats
-- carried, p1..p6 = one animal each as "species|rare|rescuedAt|bond|adopted". Nothing is ever
-- removed: the sanctuary only grows, and a full yard simply means the next animal is not taken
-- in (nothing is lost for not playing).
--
-- One companion out at a time (owner, 2026-10-24): a = 0 means Bosun the dog is out; picking a pet
-- sends him home and picking Bosun (PetRules.BOSUN) sends the pet back. Old saves load unchanged.
--
-- G48: bond pips (five) came from fish treats, removed 2026-10-24 with petting; saved pips and a
-- full bond's code-built life vest stay.
-- The trick triggers are pure too, so the client only picks the animation.
--
-- The species and the rare colour variant are rolled deterministically from the operation id,
-- so every rescuer of the same call brings home the same animal (the same golden seal pup).

local Wildlife = require(script.Parent.Config.Wildlife)

export type Entry = {
	id: number,
	species: string,
	rare: boolean,
	at: number, -- Unix seconds the animal was landed
	bond: number, -- 0..BOND_MAX heart pips
	adopted: boolean, -- has followed the player at least once (wanders its pen)
}

export type State = {
	nextId: number,
	active: number?,
	entries: { Entry },
	treats: number, -- fish treats in the player's pocket
	variant: string?, -- the equipped spin-wheel pet variant (nil = natural colours)
	variants: { [string]: boolean }, -- owned variants (spin prizes)
}

export type ViewEntry = {
	id: number,
	species: string,
	rare: boolean,
	label: string,
	ready: boolean,
	progress: number, -- 0..1 recovery meter
	remaining: number, -- seconds until it can be adopted
	active: boolean,
	bond: number,
	bondMax: number,
	adopted: boolean,
	accessory: string?,
}

export type View = {
	now: number,
	treats: number,
	variant: string?,
	variants: { string },
	pets: { ViewEntry },
}

local PetRules = {}

PetRules.MAX = Wildlife.MaxPets
PetRules.BOND_MAX = 5
PetRules.TREAT_MAX = 9
PetRules.NAP_SECONDS = 30
PetRules.ACCESSORY = "Vest"
PetRules.BOSUN = 0 -- the companion id for Bosun (no pet out)
-- Spin-wheel pet variants (docs/24 D). Purely visual; every pet the player owns can wear one.
PetRules.VARIANTS = { "Golden", "Neon", "Rainbow", "Galaxy" }

local function speciesKnown(id: string): boolean
	return Wildlife.Species[id] ~= nil
end

local function flagTime(value: any): number
	local n = tonumber(value)
	if not n or n ~= n then
		return 0
	end
	return math.max(0, math.floor(n))
end

local function decodeEntry(raw: any): Entry?
	if type(raw) ~= "string" then
		return nil
	end
	local parts = string.split(raw, "|")
	if #parts < 3 then
		return nil
	end
	local species = parts[1]
	if not speciesKnown(species) then
		return nil
	end
	local rare = parts[2] == "1"
	return {
		id = 0, -- filled by decode from the p<n> key
		species = species,
		rare = rare,
		at = flagTime(parts[3]),
		bond = math.clamp(flagTime(parts[4]), 0, PetRules.BOND_MAX),
		adopted = parts[5] == "1",
	}
end

local function encodeEntry(entry: Entry): string
	local bond = math.clamp(flagTime(entry.bond), 0, PetRules.BOND_MAX)
	return `{entry.species}|{if entry.rare then 1 else 0}|{math.floor(entry.at)}|{bond}|{if entry.adopted
		then 1
		else 0}`
end

function PetRules.newState(): State
	return { nextId = 1, active = nil, entries = {}, treats = 0, variants = {} }
end

function PetRules.decode(raw: any): State
	local state = PetRules.newState()
	if type(raw) ~= "table" then
		return state
	end
	for i = 1, PetRules.MAX do
		local entry = decodeEntry(raw[`p{i}`])
		if entry then
			entry.id = i
			table.insert(state.entries, entry)
		end
	end
	local nextId = math.floor(flagTime(raw.n))
	state.nextId =
		math.clamp(if nextId > 0 then nextId else #state.entries + 1, 1, PetRules.MAX + 1)
	local active = math.floor(flagTime(raw.a))
	if active > 0 then
		for _, entry in state.entries do
			if entry.id == active then
				state.active = active
				break
			end
		end
	end
	state.treats = math.clamp(flagTime(raw.t), 0, PetRules.TREAT_MAX)
	if type(raw.v) == "string" and table.find(PetRules.VARIANTS, raw.v) then
		state.variant = raw.v
	end
	if type(raw.w) == "string" then
		for id in string.gmatch(raw.w, "[^,]+") do
			if table.find(PetRules.VARIANTS, id) then
				state.variants[id] = true
			end
		end
	end
	return state
end

function PetRules.encode(state: State): { [string]: any }
	local out: { [string]: any } = {
		n = math.clamp(math.floor(state.nextId), 1, PetRules.MAX + 1),
		a = state.active or 0,
		t = math.clamp(flagTime(state.treats), 0, PetRules.TREAT_MAX),
	}
	for _, entry in state.entries do
		out[`p{entry.id}`] = encodeEntry(entry)
	end
	if state.variant and state.variants[state.variant] then
		out.v = state.variant
	end
	local owned = {}
	for _, id in PetRules.VARIANTS do
		if state.variants[id] then
			table.insert(owned, id)
		end
	end
	if #owned > 0 then
		out.w = table.concat(owned, ",")
	end
	return out
end

function PetRules.get(state: State, id: number): Entry?
	for _, entry in state.entries do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

-- Adds one rescued animal. Returns the same state and nil when the sanctuary is full.
function PetRules.add(state: State, speciesId: string, rare: boolean, now: number): (State, Entry?)
	if not speciesKnown(speciesId) or #state.entries >= PetRules.MAX then
		return state, nil
	end
	local id = math.clamp(math.floor(state.nextId), 1, PetRules.MAX)
	if PetRules.get(state, id) then
		return state, nil
	end
	local entries = table.clone(state.entries)
	local entry: Entry = {
		id = id,
		species = speciesId,
		rare = rare,
		at = flagTime(now),
		bond = 0,
		adopted = false,
	}
	table.insert(entries, entry)
	local nextState: State = {
		nextId = math.min(state.nextId + 1, PetRules.MAX + 1),
		active = state.active,
		entries = entries,
		treats = state.treats or 0,
		variant = state.variant,
		variants = state.variants,
	}
	return nextState, entry
end

function PetRules.readyAt(entry: Entry): number
	return entry.at + Wildlife.RecoverySeconds
end

function PetRules.progress(entry: Entry, now: number): number
	return math.clamp((now - entry.at) / Wildlife.RecoverySeconds, 0, 1)
end

function PetRules.ready(entry: Entry, now: number): boolean
	return now >= PetRules.readyAt(entry)
end

function PetRules.remaining(entry: Entry, now: number): number
	return math.max(0, PetRules.readyAt(entry) - now)
end

function PetRules.canEquip(state: State, id: number, now: number): (boolean, string?)
	if id == PetRules.BOSUN then
		return true
	end
	local entry = PetRules.get(state, id)
	if not entry then
		return false, "Unknown pet"
	end
	if not PetRules.ready(entry, now) then
		return false, "Still recovering"
	end
	return true
end

-- Adopts one pet (or Bosun, id BOSUN); the previous companion goes home.
function PetRules.equip(state: State, id: number): (State, boolean)
	if id == PetRules.BOSUN then
		return {
			nextId = state.nextId,
			active = nil,
			entries = state.entries,
			treats = state.treats or 0,
			variant = state.variant,
			variants = state.variants,
		},
			true
	end
	if not PetRules.get(state, id) then
		return state, false
	end
	local entries = {}
	for _, entry in state.entries do
		if entry.id == id then
			local adopted = table.clone(entry)
			adopted.adopted = true
			table.insert(entries, adopted)
		else
			table.insert(entries, entry)
		end
	end
	return {
		nextId = state.nextId,
		active = id,
		entries = entries,
		treats = state.treats or 0,
		variant = state.variant,
		variants = state.variants,
	},
		true
end

function PetRules.activeEntry(state: State): Entry?
	local id = state.active
	return if id then PetRules.get(state, id) else nil
end

function PetRules.treats(state: State): number
	return math.clamp(flagTime(state.treats), 0, PetRules.TREAT_MAX)
end

function PetRules.ownsVariant(state: State, id: string): boolean
	return table.find(PetRules.VARIANTS, id) ~= nil and state.variants[id] == true
end

-- Adds a spin-wheel variant to the sanctuary. Returns the state and true only the first time.
function PetRules.grantVariant(state: State, id: string): (State, boolean)
	if not table.find(PetRules.VARIANTS, id) or state.variants[id] then
		return state, false
	end
	local variants = table.clone(state.variants)
	variants[id] = true
	return {
		nextId = state.nextId,
		active = state.active,
		entries = state.entries,
		treats = state.treats or 0,
		variant = state.variant or id,
		variants = variants,
	},
		true
end

-- Wears an owned variant (nil = natural colours).
function PetRules.equipVariant(state: State, id: string?): (State, boolean)
	if id ~= nil and not PetRules.ownsVariant(state, id) then
		return state, false
	end
	if state.variant == id then
		return state, true
	end
	return {
		nextId = state.nextId,
		active = state.active,
		entries = state.entries,
		treats = state.treats or 0,
		variant = id,
		variants = state.variants,
	},
		true
end

-- The cosmetic reward at a full bond (code-built by PetAccessory on the client).
function PetRules.accessory(entry: Entry): string?
	if (entry.bond or 0) >= PetRules.BOND_MAX then
		return PetRules.ACCESSORY
	end
	return nil
end

-- Trick triggers: the client animates, these rules pick which trick a moment earns.
local TRICKS: { [string]: string } = {
	RescueDone = "Celebrate",
	CrateOpen = "Celebrate",
	Spawn = "Greet",
	Drive = "Bow",
}

function PetRules.trickFor(signal: string): string?
	return TRICKS[signal]
end

function PetRules.napDue(idleSeconds: number, atStation: boolean): boolean
	return atStation and idleSeconds >= PetRules.NAP_SECONDS
end

-- The remote/UI view: one row per animal, oldest first.
function PetRules.view(state: State, now: number): View
	local rows = table.create(#state.entries)
	for _, entry in state.entries do
		table.insert(rows, {
			id = entry.id,
			species = entry.species,
			rare = entry.rare,
			label = Wildlife.label(entry.species, entry.rare),
			ready = PetRules.ready(entry, now),
			progress = PetRules.progress(entry, now),
			remaining = PetRules.remaining(entry, now),
			active = state.active == entry.id,
			bond = math.clamp(entry.bond or 0, 0, PetRules.BOND_MAX),
			bondMax = PetRules.BOND_MAX,
			adopted = entry.adopted == true,
			accessory = PetRules.accessory(entry),
		})
	end
	local variants = {}
	for _, id in PetRules.VARIANTS do
		if state.variants[id] then
			table.insert(variants, id)
		end
	end
	return {
		now = math.floor(now),
		treats = PetRules.treats(state),
		variant = state.variant,
		variants = variants,
		pets = rows,
	}
end

-- A small stable string hash (no math.random: the same call always brings the same animal).
local function hash(seed: string): number
	local h = 2166136261
	for i = 1, #seed do
		h = (h * 31 + string.byte(seed, i)) % 2147483647
	end
	return math.floor(h)
end

-- Which animal a call brings: (species id, rare colour variant).
function PetRules.roll(seed: string): (string, boolean)
	local h = hash(seed)
	local order = Wildlife.SpeciesOrder
	local species = order[h % #order + 1]
	local rare = math.floor(h / 7) % Wildlife.RareEvery == 0
	return species, rare
end

return PetRules
