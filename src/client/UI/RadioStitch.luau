--!strict
-- RadioStitch (pure): builds a radio line from voice fragments (assets/voice/lines.csv ids, text in
-- RadioLines) so a stitched sentence can be played clip by clip and subtitled exactly.
--
-- Token grammar (a template is a list of tokens):
--   "STEM_LAUNCH_TO"     a line suffix; the voice prefix is added (CG -> CGD_/CGN_, PL -> PLM_/PLF_)
--   "PLACE_{place}_E"    {name} is replaced by params[name] (keys from Stitch.key.*), then as above
--   "@AGG_DEBRIEF_GOLD"  an absolute line id (any voice)
--   ","  "."             punctuation glued to the previous part (no clip)
--   "'free text'"        text only, no clip (the line then plays as subtitles only)
-- A part whose id has no text in RadioLines falls back to the raw param text (no clip).
local RadioLines = require(script.Parent.RadioLines)

export type Part = { id: string?, text: string, glue: boolean? }
export type Line = {
	voice: string, -- the lines.csv voice ("CG_DAY", "PLAYER_M", ...)
	parts: { Part },
	text: string,
	ids: { string }, -- clip ids in order (only parts that have one)
	complete: boolean, -- every part has a line id (can be fully voiced if the clips exist)
}
export type Options = { night: boolean?, playerVoice: string? }

local Stitch = {}

local PREFIX = {
	CG = { day = "CGD", night = "CGN", voiceDay = "CG_DAY", voiceNight = "CG_NIGHT" },
	PL = { M = "PLM", F = "PLF", voiceM = "PLAYER_M", voiceF = "PLAYER_F" },
}

-- python build_lines.slug: upper case, runs of other characters become "_"
function Stitch.slug(s: string): string
	local out = string.gsub(string.upper(s), "[^A-Z0-9]+", "_")
	out = string.gsub(out, "^_+", "")
	out = string.gsub(out, "_+$", "")
	return string.sub(out, 1, 40)
end

local function nearest(list: { number }, n: number): number
	local best, bestD = list[1], math.huge
	for _, v in list do
		local d = math.abs(v - n)
		if d < bestD then
			best, bestD = v, d
		end
	end
	return best
end

local MINUTES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20, 25, 30, 40 }
local PLAYER_MINUTES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15 }
local DISTANCES = { 50, 100, 200, 300, 400, 500, 800, 926, 1000 }
local DISTANCE_KEY = { [926] = "NMHALF", [1000] = "D1K" }

-- Param helpers: turn game values into the keys the templates expect.
Stitch.key = {
	number = function(n: number, max: number?): string
		return string.format("N%02d", math.clamp(math.floor(n + 0.5), 1, max or 40))
	end,
	minutes = function(m: number, player: boolean?): string
		return string.format(
			"M%02d",
			nearest(if player then PLAYER_MINUTES else MINUTES, math.max(1, m))
		)
	end,
	-- metres -> the nearest spoken distance fragment
	distance = function(metres: number): string
		local d = nearest(DISTANCES, metres)
		return DISTANCE_KEY[d] or ("D" .. d)
	end,
	-- "Sandy Point" / "the harbour mouth" / "SANDY_POINT" -> the PLACE key, or nil if unknown
	place = function(name: string): string?
		local slug = Stitch.slug(name)
		if RadioLines.Coastguard["PLACE_" .. slug .. "_M"] then
			return slug
		end
		local want = string.lower(name)
		for k, text in RadioLines.Coastguard do
			local key = string.match(k, "^PLACE_(.+)_M$")
			if key and string.lower(text) == want then
				return key
			end
		end
		return nil
	end,
	-- compass degrees (0 = north, clockwise) -> "SOUTH_WEST"
	compass = function(degrees: number): string
		local names = {
			"NORTH",
			"NORTH_EAST",
			"EAST",
			"SOUTH_EAST",
			"SOUTH",
			"SOUTH_WEST",
			"WEST",
			"NORTH_WEST",
		}
		local i = math.floor(((degrees % 360) + 22.5) / 45) % 8 + 1
		return names[i]
	end,
}

local function sentenceCase(s: string): string
	local out: string = string.gsub(s, "^(%l)", function(c: string): string
		return string.upper(c)
	end)
	out = string.gsub(out, "([%.%?!]%s+)(%l)", function(...: string): string
		local p, c = ...
		return p .. string.upper(c)
	end)
	return out
end

-- Joins parts into the subtitle text (punctuation glued, sentence starts capitalised).
function Stitch.join(parts: { Part }): string
	local pieces: { string } = {}
	for _, p in parts do
		if not p.glue and #pieces > 0 then
			table.insert(pieces, " ")
		end
		table.insert(pieces, p.text)
	end
	local buf = table.concat(pieces)
	buf = string.gsub(buf, ",%s*,", ",")
	buf = string.gsub(buf, ",%s*%.", ".")
	return sentenceCase(buf)
end

local function prefixFor(voice: string, opts: Options): (string, string)
	if voice == "PL" then
		local g = if opts.playerVoice == "F" then "F" else "M"
		return PREFIX.PL[g], PREFIX.PL["voice" .. g]
	end
	if opts.night then
		return PREFIX.CG.night, PREFIX.CG.voiceNight
	end
	return PREFIX.CG.day, PREFIX.CG.voiceDay
end

-- Builds a line. voice: "CG" (Coastguard, day or night watch) or "PL" (the player's reply voice).
function Stitch.build(
	voice: string,
	tokens: { string },
	params: { [string]: any }?,
	opts: Options?
): Line
	local o: Options = opts or {}
	local p = params or {}
	local prefix, voiceName = prefixFor(voice, o)
	local parts: { Part } = {}
	local ids: { string } = {}
	local complete = true
	for _, tok in tokens do
		if tok == "," or tok == "." or tok == "?" then
			table.insert(parts, { text = tok :: string, glue = true } :: Part)
			continue
		end
		local free = string.match(tok, "^'(.*)'$")
		if free then
			table.insert(parts, { text = free })
			complete = false
			continue
		end
		local rawValue: string? = nil
		local resolved = string.gsub(tok, "{(%w+)}", function(name: string)
			local v = p[name]
			rawValue = if v ~= nil then tostring(v) else name
			return if v ~= nil then tostring(v) else "?"
		end)
		local id = if string.sub(resolved, 1, 1) == "@"
			then string.sub(resolved, 2)
			else prefix .. "_" .. resolved
		local text = RadioLines.text(id)
		if text then
			table.insert(parts, { id = id, text = text })
			table.insert(ids, id)
		else
			-- unknown fragment: show the raw param (or the token) so the subtitle stays readable
			local spaced: string = string.gsub(rawValue or resolved, "_", " ")
			local shown = string.lower(spaced)
			if string.match(resolved, "_E$") then
				shown ..= "."
			end
			table.insert(parts, { text = shown })
			complete = false
		end
	end
	return {
		voice = voiceName,
		parts = parts,
		text = Stitch.join(parts),
		ids = ids,
		complete = complete,
	}
end

-- Words-per-second pacing for subtitle-only lines (radio speech, about 160 words a minute).
function Stitch.readSeconds(text: string): number
	local words = 0
	for _ in string.gmatch(text, "%S+") do
		words += 1
	end
	return math.clamp(0.8 + words / 2.7, 1.5, 22)
end

-- The stitched line can be voiced only if it is complete and every clip is in the manifest.
function Stitch.playable(line: Line, clips: { [string]: string }): boolean
	if not line.complete or #line.ids == 0 then
		return false
	end
	for _, id in line.ids do
		local asset = clips[id]
		if type(asset) ~= "string" or asset == "" then
			return false
		end
	end
	return true
end

return Stitch
