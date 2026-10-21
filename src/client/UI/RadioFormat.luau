--!strict
-- RadioFormat (pure): the player's radio messages as structured data and their spoken tokens
-- (player voice fragments for RadioStitch). Push-to-talk voices the correct reply (docs 09 section 3:
-- the station called first, then who you are, the message, then "Over" or "Out").
export type Order = "toFrom" | "fromTo" | "fromOnly" | "none"
export type Proword = "Over" | "Out" | "OverAndOut" | "None"
export type Message = {
	order: Order,
	to: string, -- "CG"
	from: string, -- callsign key "HR11"
	body: string, -- a Bodies key
	proword: Proword,
	params: { [string]: any }?,
}

local RadioFormat = {}

RadioFormat.Callsigns = table.freeze({
	HR11 = { full = "Haven Rescue One-One", short = "One-One" },
	HR21 = { full = "Haven Rescue Two-One", short = "Two-One" },
	HR31 = { full = "Haven Rescue Three-One", short = "Three-One" },
	CG = { full = "Gale Isles Coastguard", short = "Coastguard" },
})

-- Bodies: `tokens` are the spoken fragments without the proword; `overTokens` (when set) is a
-- single clip that already ends in ", over." and is used when the proword is Over.
type Body = { tokens: { string }, overTokens: { string }?, label: string }
local B: { [string]: Body } = {
	copy_launching = { tokens = { "TASKING_COPY_LAUNCHING" }, label = "Copy, launching" },
	wilco = { tokens = { "'Wilco.'" }, overTokens = { "TASKING_WILCO" }, label = "Wilco" },
	roger = { tokens = { "'Roger.'" }, overTokens = { "TASKING_ROGER" }, label = "Roger" },
	say_again = {
		tokens = { "'Say again.'" },
		overTokens = { "TASKING_SAY_AGAIN" },
		label = "Say again",
	},
	unable = { tokens = { "'Unable.'" }, overTokens = { "TASKING_UNABLE" }, label = "Unable" },
	launched = {
		tokens = { "LAUNCH_LAUNCHED", "NUMBER_{pob}_M", "LAUNCH_POB" },
		label = "Launched, {pobN} POB",
	},
	eta = { tokens = { "PASSAGE_ETA", "MINUTES_{minutes}_E" }, label = "ETA {min} min" },
	on_scene = {
		tokens = { "'On scene.'" },
		overTokens = { "ON_SCENE_ON_SCENE" },
		label = "On scene",
	},
	sighted = {
		tokens = { "'Casualty sighted.'" },
		overTokens = { "ON_SCENE_SIGHTED" },
		label = "Casualty sighted",
	},
	searching = {
		tokens = { "'Searching, no contact yet.'" },
		overTokens = { "ON_SCENE_SEARCHING" },
		label = "Searching",
	},
	recovered = { tokens = { "NUMBER_{n}_M", "SITREP_RECOVERED" }, label = "{nN} recovered" },
	condition = { tokens = { "SITREP_{cond}" }, label = "Casualty condition" },
	req_ambulance = {
		tokens = { "'Request ambulance at the slipway.'" },
		overTokens = { "SITREP_REQ_AMB" },
		label = "Request ambulance",
	},
	req_helo = {
		tokens = { "'Request helicopter.'" },
		overTokens = { "SITREP_REQ_HELO_MVP" },
		label = "Request helicopter",
	},
	req_second = {
		tokens = { "'Request a second unit.'" },
		overTokens = { "SITREP_REQ_SECOND" },
		label = "Request second unit",
	},
	returning = {
		tokens = {
			"TRANSPORT_RETURNING_TO",
			"TRANSPORT_DEST_SLIPWAY",
			"PASSAGE_ETA",
			"MINUTES_{minutes}_E",
		},
		label = "Returning, ETA {min} min",
	},
	handed_over = {
		tokens = { "'Casualty handed over.'" },
		overTokens = { "HANDOVER_HANDED_OVER" },
		label = "Casualty handed over",
	},
	returning_station = {
		tokens = { "'Returning to station.'" },
		overTokens = { "HANDOVER_RETURNING_STATION" },
		label = "Returning to station",
	},
	ready = {
		tokens = { "'Ready for tasking.'" },
		overTokens = { "HANDOVER_READY" },
		label = "Ready for tasking",
	},
	wildlife_safe = {
		tokens = { "'Animal safe, heading in.'" },
		label = "Animal safe, heading in",
	},
	vessel_secured = {
		tokens = { "NUMBER_{pob}_M", "LAUNCH_POB", "'Vessel secured alongside, all persons safe.'" },
		overTokens = { "NUMBER_{pob}_M", "LAUNCH_POB", "HANDOVER_VESSEL_SECURED" },
		label = "{pobN} POB, vessel secured",
	},
	all_accounted = {
		tokens = { "NUMBER_{n}_M", "SITREP_RECOVERED", "'All persons accounted for.'" },
		overTokens = { "NUMBER_{n}_M", "SITREP_RECOVERED", "FERRY_ALL_ACCOUNTED" },
		label = "{nN} recovered, all accounted",
	},
}
RadioFormat.Bodies = B

local function fill(label: string, params: { [string]: any }?): string
	local p = params or {}
	return (
		string.gsub(label, "{(%w+)}", function(k: string)
			local v = p[k]
			return if v ~= nil then tostring(v) else "?"
		end)
	)
end

-- Spoken tokens of a message (player voice "PL").
function RadioFormat.tokens(msg: Message): { string }
	local body = B[msg.body]
	assert(body, "unknown radio body " .. tostring(msg.body))
	local out: { string } = {}
	local cs = msg.from
	if msg.order == "toFrom" then
		table.insert(out, "FRAG_COASTGUARD")
		table.insert(out, "CALLSIGN_" .. cs .. "_E")
	elseif msg.order == "fromTo" then
		local own = RadioFormat.Callsigns[cs]
		table.insert(out, "'" .. (if own then own.full else cs) .. ",'")
		table.insert(out, "'Gale Isles Coastguard.'")
	elseif msg.order == "fromOnly" then
		local own = RadioFormat.Callsigns[cs]
		table.insert(out, "'" .. (if own then own.full else cs) .. ".'")
	end
	if msg.proword == "Over" and body.overTokens then
		for _, t in body.overTokens do
			table.insert(out, t)
		end
		return out
	end
	for _, t in body.tokens do
		table.insert(out, t)
	end
	if msg.proword == "Over" then
		table.insert(out, "FRAG_END_OVER")
	elseif msg.proword == "Out" then
		table.insert(out, "'Out.'")
	elseif msg.proword == "OverAndOut" then
		table.insert(out, "'Over and out.'")
	end
	return out
end

-- The short wheel label: shows the procedure so it can be judged ("CG, One-One · Copy, launching · Over").
function RadioFormat.label(msg: Message): string
	local body = B[msg.body]
	local own = RadioFormat.Callsigns[msg.from]
	local short = if own then own.short else msg.from
	local head = if msg.order == "toFrom"
		then "Coastguard, " .. short .. " · "
		elseif msg.order == "fromTo" then short .. ", Coastguard · "
		elseif msg.order == "fromOnly" then short .. " · "
		else ""
	local tail = if msg.proword == "Over"
		then " · Over"
		elseif msg.proword == "Out" then " · Out"
		elseif msg.proword == "OverAndOut" then " · Over and out"
		else ""
	return head .. fill(if body then body.label else msg.body, msg.params) .. tail
end

local PLAYER_MINUTES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15 }

-- Params for RadioStitch: numbers become fragment keys (player voice has N01-N20 and 12 minute
-- lengths); `{x}N` / `min` stay readable for the label.
function RadioFormat.stitchParams(m: Message): { [string]: any }
	local out: { [string]: any } = table.clone(m.params or {})
	for _, k in { "pob", "n" } do
		local v = out[k]
		if type(v) == "number" then
			out[k] = string.format("N%02d", math.clamp(math.floor(v + 0.5), 1, 20))
		end
	end
	local mins = out.minutes
	if type(mins) == "number" then
		local best, bestD = 1, math.huge
		for _, v in PLAYER_MINUTES do
			if math.abs(v - mins) < bestD then
				best, bestD = v, math.abs(v - mins)
			end
		end
		out.minutes = string.format("M%02d", best)
	end
	return out
end

-- A subtitle is one short line: the first `max` words, then an ellipsis.
function RadioFormat.capWords(text: string, max: number): string
	local out, n = {}, 0
	for w in string.gmatch(text, "%S+") do
		n += 1
		if n > max then
			local joined = (string.gsub(table.concat(out, " "), "[%.,;:]+$", ""))
			return joined .. "…"
		end
		out[n] = w
	end
	return table.concat(out, " ")
end

-- A spoken subtitle (crew call-outs, Ferry captions): capWords, with a leading speaker tag before a
-- quote (`Crew: "..."`) not counted.
function RadioFormat.capLine(text: string, max: number): string
	local who, said = string.match(text, '^([^":]+:)%s+(".*)$')
	if who and said then
		return who .. " " .. RadioFormat.capWords(said, max)
	end
	return RadioFormat.capWords(text, max)
end

-- The radio subtitle at a glance (docs/14 section 2): drop a leading callsign address ("Haven
-- Rescue, Coastguard."), keep the first clause, skip articles, at most `max` words. The full line
-- stays in the radio log.
local ADDRESS = { "Rescue", "Coastguard", "Station", "this is" }
local ARTICLE = { the = true, a = true, an = true }
function RadioFormat.caption(text: string, max: number): string
	local first, rest = string.match(text, "^([^%.!?]*)[%.!?]%s+(.+)$")
	if first and rest and string.find(first, ",", 1, true) then
		for _, w in ADDRESS do
			if string.find(first, w, 1, true) then
				text = rest
				break
			end
		end
	end
	local clause = string.match(text, "^%s*([^%.,;!?]+)") or text
	local out = {}
	for w in string.gmatch(clause, "%S+") do
		if not ARTICLE[string.lower(w)] then
			table.insert(out, w)
			if #out == max then
				break
			end
		end
	end
	return table.concat(out, " ")
end

-- POB number carried by a message (closeout and launch bodies), or nil.
function RadioFormat.pobOf(m: Message): number?
	local p: { [string]: any } = m.params or {}
	local v = p.pob or p.n
	return if type(v) == "number" then v else nil
end

return RadioFormat
