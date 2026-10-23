--!strict
-- RadioSubtitle (docs/16 K17): the subtitle under a radio line is at most six words; the voice
-- still says the whole line. Known long lines get a written short form; anything else drops the
-- radio address ("Haven Rescue, Gale Isles Coastguard.") and procedure words, keeps the first
-- sentence and caps it. Pure, Lune-tested (tests/RadioSubtitle.spec.luau).
local RadioSubtitle = {}

RadioSubtitle.MAX_WORDS = 6

-- full spoken text (lower case) -> subtitle. The op radioLines (shared/Ops/Definitions).
RadioSubtitle.Short = {
	["haven rescue, gale isles coastguard. person in the water, request you launch."] = "Person in the water. Launch.",
	["haven rescue, gale isles coastguard. swimmer caught in a rip current off haven sands, request you launch."] = "Swimmer in a rip. Launch.",
	["haven rescue, gale isles coastguard. walker in the water below haven head, one casualty. over."] = "Walker below the cliffs. Launch.",
	["mayday from the motor cruiser firefly: engine fire, two people in the water."] = "MAYDAY! Boat on fire!",
	["mayday from the fishing boat morwenna's pride: taking water fast off the harbour, three aboard."] = "MAYDAY! Boat sinking, three aboard!",
	["mayday relay, all stations: the gale queen has capsized off the harbour mouth."] = "MAYDAY! The ferry capsized!",
	["wildlife in trouble off the harbour, request a rescue."] = "Animal in trouble. Launch.",
} :: { [string]: string }

local PROCEDURE = { roger = true, over = true, out = true, copy = true, received = true }

local function words(s: string): { string }
	local out = {}
	for w in string.gmatch(s, "%S+") do
		table.insert(out, w)
	end
	return out
end

-- "Haven Rescue, Gale Isles Coastguard." / "One-One, Coastguard.": callee, caller, nothing else.
local function isAddress(sentence: string): boolean
	if not string.find(sentence, ",") then
		return false
	end
	for _, w in words(sentence) do
		if not string.match(w, "^%u") then
			return false
		end
	end
	return true
end

function RadioSubtitle.of(text: string): string
	local known = RadioSubtitle.Short[string.lower(text)]
	if known then
		return known
	end
	local kept = {}
	for sentence in string.gmatch(text, "[^%.!?]+[%.!?]*") do
		sentence = string.match(sentence, "^%s*(.-)%s*$") :: string
		local bare = string.lower((string.gsub(sentence, "[%p]", "")))
		if sentence ~= "" and not isAddress(sentence) and not PROCEDURE[bare] then
			-- a trailing ", over." is procedure too
			sentence = string.gsub(sentence, ",%s*[Oo]ver([%.!?]*)$", "%1")
			table.insert(kept, sentence)
		end
	end
	local joined = table.concat(kept, " ")
	if joined ~= "" and #words(joined) <= RadioSubtitle.MAX_WORDS then
		return joined
	end
	local first = words(kept[1] or text)
	if #first <= RadioSubtitle.MAX_WORDS then
		return table.concat(first, " ")
	end
	return table.concat(first, " ", 1, RadioSubtitle.MAX_WORDS) .. "…"
end

return RadioSubtitle
