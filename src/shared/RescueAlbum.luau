--!strict
-- RescueAlbum: the station album's collection logic (docs/15 section 2, hook H2). Pure, tested in
-- tests/RescueAlbum.spec.luau. AlbumService owns the profile field (data.flags.album, a flat
-- table of scalars like ChallengeService's data.flags.challenges) and the set payouts.
--
-- Stickers are stored as variant id -> 1; a paid set is "set:<kind>" -> 1, so completing a kind's
-- set pays Cash exactly once, even across sessions and servers.

local Variants = require(script.Parent.Config.RescueVariants)

export type State = {
	owned: { [string]: boolean },
	paid: { [string]: boolean },
}

export type Row = {
	kind: string,
	label: string,
	variants: { { id: string, label: string, rarity: Variants.Rarity, owned: boolean } },
	owned: number,
	total: number,
	paid: boolean,
}

export type View = {
	rows: { Row },
	owned: number,
	total: number,
}

local PT = "set:"

local RescueAlbum = {}

function RescueAlbum.newState(): State
	return { owned = {}, paid = {} }
end

-- Accepts the persisted flat table (or anything corrupt) and keeps only real stickers and sets.
function RescueAlbum.fromFlagTable(raw: any): State
	local state = RescueAlbum.newState()
	if type(raw) ~= "table" then
		return state
	end
	for key, value in raw do
		if type(key) ~= "string" or value ~= 1 then
			continue
		end
		if string.sub(key, 1, #PT) == PT then
			local kind = string.sub(key, #PT + 1)
			if Variants.Kinds[kind] then
				state.paid[kind] = true
			end
		elseif Variants.ById(key) then
			state.owned[key] = true
		end
	end
	return state
end

function RescueAlbum.flagTable(state: State): { [string]: number }
	local out: { [string]: number } = {}
	for id in state.owned do
		if Variants.ById(id) then
			out[id] = 1
		end
	end
	for kind in state.paid do
		if Variants.Kinds[kind] then
			out[PT .. kind] = 1
		end
	end
	return out
end

function RescueAlbum.has(state: State, id: any): boolean
	return type(id) == "string" and state.owned[id] == true
end

function RescueAlbum.setProgress(state: State, kind: string): (number, number)
	local list = Variants.Kinds[kind]
	if not list then
		return 0, 0
	end
	local owned = 0
	for _, variant in list do
		if state.owned[variant.id] then
			owned += 1
		end
	end
	return owned, #list
end

-- Record one rescued variant. Returns whether it was new, and the kind whose set it just completed
-- (only the first time: the set is marked paid here).
function RescueAlbum.record(state: State, id: any): (boolean, string?)
	local variant = Variants.ById(id)
	if not variant then
		return false, nil
	end
	local fresh = not state.owned[variant.id]
	if fresh then
		state.owned[variant.id] = true
	end
	local owned, total = RescueAlbum.setProgress(state, variant.kind)
	if total > 0 and owned >= total and not state.paid[variant.kind] then
		state.paid[variant.kind] = true
		return fresh, variant.kind
	end
	return fresh, nil
end

function RescueAlbum.view(state: State): View
	local rows: { Row } = {}
	local ownedAll, totalAll = 0, 0
	for _, kind in Variants.KindOrder do
		local variants = {}
		local ownedCount = 0
		local list: { Variants.Variant } = Variants.Kinds[kind] or {}
		for _, variant in list do
			local owned = state.owned[variant.id] == true
			if owned then
				ownedCount += 1
			end
			table.insert(variants, {
				id = variant.id,
				label = variant.label,
				rarity = variant.rarity,
				owned = owned,
			})
		end
		ownedAll += ownedCount
		totalAll += #variants
		table.insert(rows, {
			kind = kind,
			label = Variants.KindLabel[kind] or kind,
			variants = variants,
			owned = ownedCount,
			total = #variants,
			paid = state.paid[kind] == true,
		})
	end
	return { rows = rows, owned = ownedAll, total = totalAll }
end

return RescueAlbum
