--!strict
-- DiscoveryRules: the exploration album and the map fog as pure rules (docs/21 §3, package B2). Lune-tested
-- (tests/Discovery.spec.luau); DiscoveryService applies them to server-observed positions, the client
-- (DiscoveryController, the Album app, the map fog) reads the same state.
--
-- Album state: island id -> a bit mask. Bit 1 sighted, bit 2 reached (on foot on the island), then one
-- bit per sticker in page order (sticker 1 = the island stamp). Saved as profile flag "isles" (a flat
-- table of numbers); decode drops unknown islands and bits, so old or tampered saves load clean.
--   sighted   within the island radius + DiscoveryConfig.SightRange (horizontal)
--   reached   on foot (not seated, above the sea) within the island radius (horizontal)
--   sticker   within DiscoveryConfig.Range[kind] of its point (3D)
-- Fog: a buffer, one byte per cell of the DiscoveryConfig.Fog grid (1 = revealed), saved as flag "fog"
-- (64-char base64 chunks f1..f9). Cell index = iz * count + ix + 1. docs/23 (l): a second, finer buffer
-- covers the hub island only (DiscoveryConfig.Fog.Hub, saved as flag "foghub", chunks h1..hn) so the
-- forest fog is not cleared by the coarse 400-stud reveal; inside the hub grid the coarse grid is skipped.
local CallTypes = require(script.Parent.Calls.CallTypes)
local DiscoveryConfig = require(script.Parent.Config.DiscoveryConfig)
local WorldConfig = require(script.Parent.Config.WorldConfig)

export type State = { [string]: number }
export type Sticker = {
	id: string,
	kind: string,
	bit: number,
	point: Vector3,
	species: string?,
	bonus: boolean?, -- not needed to complete the page (the wreck stickers came after pages were won)
}
export type Page = {
	id: string,
	name: string,
	island: any, -- the WorldConfig.Islands row
	colour: Color3,
	icon: string,
	cosmetic: string?,
	stickers: { Sticker },
}
export type Event = {
	island: string,
	step: string, -- "Sighted" | "Reached" | "Sticker"
	sticker: Sticker?,
	page: boolean?, -- this sticker completed the page
}

local Rules = {}

Rules.SIGHTED = 1
Rules.REACHED = 2

local FOG = DiscoveryConfig.Fog
local CELLS = FOG.count * FOG.count
local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local CHUNK = 64

-- the hub's fine grid: a square of Hub.cell cells centred on the hub, wide enough that a reveal at the
-- island's rim stays inside the domain
local HUB = DiscoveryConfig.Fog.Hub
local HUB_HALF = math.ceil((WorldConfig.Hub.radius + HUB.radius + HUB.cell) / HUB.cell) * HUB.cell
local HUB_COUNT = math.floor(2 * HUB_HALF / HUB.cell)
local HUB_CELLS = HUB_COUNT * HUB_COUNT
local HUB_X0 = WorldConfig.Hub.center.X - HUB_HALF
local HUB_Z0 = WorldConfig.Hub.center.Z - HUB_HALF

-- pages in WorldConfig.Islands order, every sticker's bit and unsettled world point
Rules.Pages = {} :: { Page }
Rules.ById = {} :: { [string]: Page }
-- docs/23 (l): the hub forest gets a page too (last, so the islands keep their order). Its row carries every hub
-- clearing's centre by id, so a sticker's `from` can name one (Ruin, Wreck); the stamp is by the monument.
local hubRow: { [string]: any } = {
	id = "Hub",
	name = "Coastguard Hub",
	center = WorldConfig.Hub.center,
	radius = WorldConfig.Hub.radius,
}
for _, c in WorldConfig.Hub.clearings do
	hubRow[c.id] = c.center
end
hubRow.stamp = hubRow.Monument + Vector3.new(-12, 0, 8)
local rows = table.clone(WorldConfig.Islands) :: { any }
table.insert(rows, hubRow)

for _, island in rows do
	local cfg = DiscoveryConfig.Pages[island.id]
	local page: Page = {
		id = island.id,
		name = island.name,
		island = island,
		colour = if cfg then cfg.colour else Color3.fromHex("5B7F95"),
		icon = if cfg then cfg.icon else "light",
		cosmetic = if cfg then cfg.cosmetic else nil,
		stickers = { { id = "Stamp", kind = "Stamp", bit = 4, point = island.stamp } },
	}
	local list: { any } = if cfg then cfg.stickers else {}
	for i, s in list do
		local base = (island :: any)[s.from] :: Vector3
		table.insert(page.stickers, {
			id = s.id,
			kind = s.kind,
			bit = 2 ^ (i + 2),
			point = base + s.offset,
			species = s.species,
		})
	end
	-- docs/23 (h): each dive-site wreck is a bonus sticker on its island's page, found by driving the sub
	-- close (DiscoveryConfig.Range.Wreck). Appended last so the older stickers keep their bits.
	for _, site in CallTypes.DiveSites do
		if site.island == island.id then
			table.insert(page.stickers, {
				id = "Wreck",
				kind = "Wreck",
				bit = 2 ^ (#page.stickers + 2),
				point = site.wreck,
				bonus = true,
			})
		end
	end
	table.insert(Rules.Pages, page)
	Rules.ById[island.id] = page
end

local function full(page: Page): number
	return 2 ^ (#page.stickers + 2) - 1
end

local function stickerBits(page: Page): number
	local bits = full(page) - Rules.SIGHTED - Rules.REACHED
	for _, s in page.stickers do
		if s.bonus then
			bits -= s.bit
		end
	end
	return bits
end

function Rules.decode(flag: any): State
	local state: State = {}
	if type(flag) ~= "table" then
		return state
	end
	for _, page in Rules.Pages do
		local n = tonumber(flag[page.id])
		if n and n == n and n > 0 then
			local clean = bit32.band(math.floor(math.min(n, 2 ^ 31)), full(page))
			if clean > 0 then
				state[page.id] = clean
			end
		end
	end
	return state
end

function Rules.encode(state: State): { [string]: number }
	return table.clone(state)
end

function Rules.has(state: State, islandId: string, bit: number): boolean
	return bit32.band(state[islandId] or 0, bit) ~= 0
end

-- stickers found / stickers on the page
function Rules.count(state: State, islandId: string): (number, number)
	local page = Rules.ById[islandId]
	if not page then
		return 0, 0
	end
	local n = 0
	for _, s in page.stickers do
		if Rules.has(state, islandId, s.bit) then
			n += 1
		end
	end
	return n, #page.stickers
end

function Rules.complete(state: State, islandId: string): boolean
	local page = Rules.ById[islandId]
	return page ~= nil and bit32.band(state[islandId] or 0, stickerBits(page)) == stickerBits(page)
end

function Rules.stamps(state: State): number
	local n = 0
	for _, page in Rules.Pages do
		if Rules.has(state, page.id, 4) then
			n += 1
		end
	end
	return n
end

-- cosmetic keys of completed pages (the hook for CosmeticLoadout.owned)
function Rules.cosmetics(state: State): { [string]: boolean }
	local set = {}
	for _, page in Rules.Pages do
		if page.cosmetic and Rules.complete(state, page.id) then
			set[page.cosmetic] = true
		end
	end
	return set
end

local function flat(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- What this position finds. `points[islandId][stickerId]` overrides a sticker's point (the server's
-- ground-settled spot); `onFoot` = walking on land (not seated, above the sea). Returns the new state
-- and the events in order (Sighted, Reached, then stickers; the last sticker of a page has page = true).
function Rules.scan(
	state: State,
	pos: Vector3,
	onFoot: boolean,
	points: { [string]: { [string]: Vector3 } }?
): (State, { Event })
	local nextState = table.clone(state)
	local events: { Event } = {}
	for _, page in Rules.Pages do
		local island = page.island
		local d = flat(pos, island.center)
		if d > island.radius + DiscoveryConfig.SightRange then
			continue
		end
		local id = page.id
		local function mark(bit: number)
			nextState[id] = bit32.bor(nextState[id] or 0, bit)
		end
		if not Rules.has(nextState, id, Rules.SIGHTED) then
			mark(Rules.SIGHTED)
			table.insert(events, { island = id, step = "Sighted" })
		end
		if onFoot and d <= island.radius and not Rules.has(nextState, id, Rules.REACHED) then
			mark(Rules.REACHED)
			table.insert(events, { island = id, step = "Reached" })
		end
		local spots = points and points[id]
		for _, s in page.stickers do
			local at = spots and spots[s.id] or s.point
			local reach = DiscoveryConfig.Range[s.kind] or 8
			if not Rules.has(nextState, id, s.bit) and (pos - at).Magnitude <= reach then
				local was = Rules.complete(nextState, id) -- a bonus sticker after the page: no second page bonus
				mark(s.bit)
				table.insert(events, {
					island = id,
					step = "Sticker",
					sticker = s,
					page = not was and Rules.complete(nextState, id),
				})
			end
		end
	end
	return nextState, events
end

-- Fog ------------------------------------------------------------------------------------------------

function Rules.newFog(): buffer
	return buffer.create(CELLS)
end

function Rules.cellOf(pos: Vector3): number?
	local ix = math.floor((pos.X - FOG.origin) / FOG.cell)
	local iz = math.floor((pos.Z - FOG.origin) / FOG.cell)
	if ix < 0 or iz < 0 or ix >= FOG.count or iz >= FOG.count then
		return nil
	end
	return iz * FOG.count + ix + 1
end

function Rules.revealed(fog: buffer, index: number): boolean
	return index >= 1 and index <= CELLS and buffer.readu8(fog, index - 1) == 1
end

-- clears every cell whose centre is within the fog radius (+ half a cell); true when any cell changed
local function clearCells(
	buf: buffer,
	count: number,
	cell: number,
	ox: number,
	oz: number,
	pos: Vector3,
	radius: number
): boolean
	local reach = radius + cell / 2
	local x0 = math.floor((pos.X - reach - ox) / cell)
	local x1 = math.floor((pos.X + reach - ox) / cell)
	local z0 = math.floor((pos.Z - reach - oz) / cell)
	local z1 = math.floor((pos.Z + reach - oz) / cell)
	local changed = false
	for iz = math.max(z0, 0), math.min(z1, count - 1) do
		for ix = math.max(x0, 0), math.min(x1, count - 1) do
			local cx = ox + (ix + 0.5) * cell
			local cz = oz + (iz + 0.5) * cell
			local i = iz * count + ix
			if
				(cx - pos.X) ^ 2 + (cz - pos.Z) ^ 2 <= reach * reach
				and buffer.readu8(buf, i) == 0
			then
				buffer.writeu8(buf, i, 1)
				changed = true
			end
		end
	end
	return changed
end

function Rules.reveal(fog: buffer, pos: Vector3, hub: buffer?): boolean
	-- inside the hub island the fine grid stands in for the coarse one (docs/23 (l)): the forest fog
	-- reads from it, and the coarse 400-stud reveal would clear the whole island at spawn
	if hub and Rules.hubCellOf(pos) then
		return clearCells(hub, HUB_COUNT, HUB.cell, HUB_X0, HUB_Z0, pos, HUB.radius)
	end
	return clearCells(fog, FOG.count, FOG.cell, FOG.origin, FOG.origin, pos, FOG.radius)
end

-- the hub's fine fog (docs/23 (l)) ---------------------------------------------------------------------

function Rules.newHubFog(): buffer
	return buffer.create(HUB_CELLS)
end

function Rules.hubCellOf(pos: Vector3): number?
	local ix = math.floor((pos.X - HUB_X0) / HUB.cell)
	local iz = math.floor((pos.Z - HUB_Z0) / HUB.cell)
	if ix < 0 or iz < 0 or ix >= HUB_COUNT or iz >= HUB_COUNT then
		return nil
	end
	return iz * HUB_COUNT + ix + 1
end

function Rules.hubRevealed(hub: buffer, index: number): boolean
	return index >= 1 and index <= HUB_CELLS and buffer.readu8(hub, index - 1) == 1
end

-- six cells per base64 character, 64 characters per flag field
local function encodeBits(buf: buffer, cells: number): { [string]: string }
	local chars = {}
	for c = 0, math.ceil(cells / 6) - 1 do
		local v = 0
		for b = 0, 5 do
			local i = c * 6 + b
			if i < cells and buffer.readu8(buf, i) == 1 then
				v += 2 ^ b
			end
		end
		table.insert(chars, string.sub(CHARS, v + 1, v + 1))
	end
	local s = table.concat(chars)
	local out = {}
	for k = 1, math.ceil(#s / CHUNK) do
		out[`f{k}`] = string.sub(s, (k - 1) * CHUNK + 1, k * CHUNK)
	end
	return out
end

local function decodeBits(flag: any, cells: number): buffer
	local buf = buffer.create(cells)
	if type(flag) ~= "table" then
		return buf
	end
	for k = 1, math.ceil(math.ceil(cells / 6) / CHUNK) do
		local s = flag[`f{k}`]
		if type(s) ~= "string" then
			continue
		end
		for j = 1, math.min(#s, CHUNK) do
			local v = (string.find(CHARS, string.sub(s, j, j), 1, true) or 1) - 1
			local c = (k - 1) * CHUNK + j - 1
			for b = 0, 5 do
				local i = c * 6 + b
				if i < cells and bit32.band(v, 2 ^ b) ~= 0 then
					buffer.writeu8(buf, i, 1)
				end
			end
		end
	end
	return buf
end

function Rules.encodeFog(fog: buffer): { [string]: string }
	return encodeBits(fog, CELLS)
end

function Rules.decodeFog(flag: any): buffer
	return decodeBits(flag, CELLS)
end

function Rules.encodeHubFog(hub: buffer): { [string]: string }
	return encodeBits(hub, HUB_CELLS)
end

function Rules.decodeHubFog(flag: any): buffer
	return decodeBits(flag, HUB_CELLS)
end

return Rules
