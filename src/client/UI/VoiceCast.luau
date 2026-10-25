--!strict
-- VoiceCast (pure): the NPC cast (docs/11 section 1, people met in person) mapped to Roblox
-- AudioTextToSpeech presets, used by Controllers/VoiceTTS. Presets (create.roblox.com/docs/audio/objects,
-- "List of artificial voices"): 1 British M, 2 British F, 3 US M #1, 4 US F #1, 5 US M #2, 6 US F #2,
-- 7 Australian M, 8 Australian F, 11 Host. Pitch in semitones (-12..12), Speed 0.5..2.
--   VoiceCast.Cast[castId] -> { voice, pitch, speed }
--   VoiceCast.castFor(speakerName, fallback) -> castId    "Chief Aggie" -> "AGGIE", "Crew" -> "CREW_FINN"
--   VoiceCast.spoken(text) -> string?   what to say: [cues] dropped, only "quoted" speech when quoted,
--                                       nil if nothing to say
--   VoiceCast.chunks(text) -> { string }   pieces of at most MAX characters, split at sentence ends
export type Voice = { voice: string, pitch: number, speed: number }

local VoiceCast = {}

VoiceCast.MAX = 300 -- AudioTextToSpeech.Text limit

local function v(voice: number, pitch: number, speed: number): Voice
	return { voice = tostring(voice), pitch = pitch, speed = speed }
end

-- Same preset only with a clear pitch / speed gap, so no two who talk together sound alike.
VoiceCast.Cast = {
	AGGIE = v(8, -2, 0.95), -- warm, dry, older
	CREW_FINN = v(7, 1, 1.08), -- keen, quick
	CREW_DEE = v(4, -1, 1.0), -- dry, flat, certain
	BARNABY = v(11, -1, 1.0), -- cheerful, rolling
	LOU = v(5, -3, 1.06), -- tight urgency, in control
	DR_OSEI = v(2, 2, 1.05), -- brisk
	PATROL = v(3, -2, 1.0), -- easy-going
	HAZEL = v(4, 2, 0.92), -- chatty, older
	CASUALTY_M = v(5, 1, 1.1), -- cold, short breaths
	CASUALTY_F = v(8, 1, 1.08),
	PARENT_F = v(6, 1, 1.08),
	INFORMANT_M = v(7, -1, 1.12),
	TEEN_M = v(3, 3, 1.1),
} :: { [string]: Voice }

-- First match wins (lower-case words in the shown speaker name).
local SPEAKERS: { { string } } = {
	{ "aggie", "AGGIE" },
	{ "finn", "CREW_FINN" },
	{ "dee", "CREW_DEE" },
	{ "mara", "CREW_DEE" },
	{ "crew", "CREW_FINN" },
	{ "optimist", "BARNABY" },
	{ "barnaby", "BARNABY" },
	{ "skipper", "BARNABY" },
	{ "lou", "LOU" },
	{ "hazel", "HAZEL" },
	{ "patrol", "PATROL" },
	{ "harbour", "PATROL" },
	{ "osei", "DR_OSEI" },
	{ "hospital", "DR_OSEI" },
}

function VoiceCast.castFor(name: string, fallback: string): string
	if VoiceCast.Cast[name] then
		return name
	end
	local s = string.lower(name)
	for _, pair in SPEAKERS do
		if string.find(s, "%f[%a]" .. pair[1] .. "%f[%A]") then
			return pair[2]
		end
	end
	return fallback
end

function VoiceCast.spoken(text: string): string?
	local s = string.gsub(text, "%b[]", "")
	if string.find(s, '"') then
		local quoted = {}
		for q in string.gmatch(s, '"([^"]*)"') do
			table.insert(quoted, q)
		end
		s = table.concat(quoted, " ")
	end
	s = string.gsub(string.gsub(s, "%s+", " "), "^ ", "")
	return if string.find(s, "%w") then s else nil
end

function VoiceCast.chunks(text: string): { string }
	local out = {}
	local rest = text
	while #rest > VoiceCast.MAX do
		local head = string.sub(rest, 1, VoiceCast.MAX)
		-- the last sentence end (or else the last space) inside the limit
		local cut = tonumber(string.match(head, "^.*()[%.!%?]%s") or string.match(head, "^.*() "))
			or VoiceCast.MAX
		table.insert(out, string.sub(rest, 1, cut))
		rest = string.gsub(string.sub(rest, cut + 1), "^%s+", "")
	end
	if #rest > 0 then
		table.insert(out, rest)
	end
	return out
end

return VoiceCast
