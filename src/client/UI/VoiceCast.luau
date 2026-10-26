--!strict
-- VoiceCast (pure): the NPC cast (the quest givers, casualty shouts) mapped to Roblox
-- AudioTextToSpeech presets, used by Controllers/VoiceTTS. Presets (create.roblox.com/docs/audio/objects,
-- "List of artificial voices"): 1 British M, 2 British F, 3 US M #1, 4 US F #1, 5 US M #2, 6 US F #2,
-- 7 Australian M, 8 Australian F, 11 Host. Pitch in semitones (-12..12), Speed 0.5..2.
--   VoiceCast.Cast[castId] -> { voice, pitch, speed }
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
	BARNABY = v(11, -1, 1.0), -- cheerful, rolling
	PATROL = v(3, -2, 1.0), -- easy-going
	HAZEL = v(4, 2, 0.92), -- chatty, older
	CASUALTY_M = v(5, 1, 1.1), -- cold, short breaths
	CASUALTY_F = v(8, 1, 1.08),
	PARENT_F = v(6, 1, 1.08),
	INFORMANT_M = v(7, -1, 1.12),
	TEEN_M = v(3, 3, 1.1),
} :: { [string]: Voice }

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
