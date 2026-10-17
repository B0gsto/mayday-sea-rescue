--!strict
-- RadioFormat (pure): the player's radio messages as structured data, their wheel options, the
-- spoken tokens (player voice fragments for RadioStitch) and the grading of voice procedure.
--
-- Procedure graded (docs 09 section 3): call the station you want first, then say who you are
-- ("Gale Isles Coastguard, Haven Rescue One-One"), then the message, then the right proword:
-- "Over" when you expect a reply, "Out" when the exchange is finished. "Over and out" is never
-- right (it means "reply" and "don't reply" at once).
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
export type Expect = {
	to: string,
	from: string,
	proword: Proword,
	bodies: { [string]: number }, -- body -> credit 0..1
}
export type Option = { label: string, msg: Message, correct: boolean, icon: string? }

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

-- Grades voice procedure. Returns score 0..1 (the "format" metric) and the faults, worst first.
function RadioFormat.grade(msg: Message, expect: Expect): (number, { string })
	local faults: { string } = {}
	local cs = 0
	if msg.order == "toFrom" and msg.to == expect.to and msg.from == expect.from then
		cs = 1
	elseif msg.order == "fromOnly" and msg.from == expect.from then
		cs = 0.5
		table.insert(faults, "Call the Coastguard first, then say who you are.")
	elseif msg.order == "fromTo" then
		table.insert(
			faults,
			"Callsigns reversed: the station you call comes first, then 'this is' you."
		)
	else
		table.insert(faults, "No callsigns: they can't tell who is talking.")
	end
	local body = expect.bodies[msg.body] or 0
	if body <= 0 then
		table.insert(faults, "Wrong message for this call.")
	elseif body < 1 then
		table.insert(faults, "'Roger' only says you heard it. Say what you will do.")
	end
	local pw = 0
	if msg.proword == expect.proword then
		pw = 1
	elseif msg.proword == "OverAndOut" then
		table.insert(faults, "Never 'over and out': over asks for a reply, out ends the call.")
	elseif msg.proword == "Out" then
		table.insert(faults, "Use 'over': you expect the Coastguard to answer.")
	elseif msg.proword == "Over" then
		table.insert(faults, "Use 'out': nothing more is expected.")
	else
		table.insert(faults, "End with a proword: 'over' or 'out'.")
	end
	local score = math.floor((cs + body + pw) / 3 * 100 + 0.5) / 100
	return score, faults
end

-- Small deterministic shuffle so options don't sit in the same slot every time.
-- (a tiny LCG instead of Random, so the module stays pure and testable under Lune)
local function lcg(seed: number): (number, number) -> number
	local x = math.floor(math.abs(seed)) % 2147483647 + 1
	return function(lo: number, hi: number): number
		x = (x * 48271) % 2147483647
		return lo + x % (hi - lo + 1)
	end
end

local function shuffle<T>(list: { T }, seed: number): { T }
	local next = lcg(seed)
	for i = #list, 2, -1 do
		local j = next(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

local function msg(
	order: Order,
	from: string,
	body: string,
	pw: Proword,
	params: { [string]: any }?
): Message
	return { order = order, to = "CG", from = from, body = body, proword = pw, params = params }
end

local function option(m: Message, correct: boolean): Option
	return { label = RadioFormat.label(m), msg = m, correct = correct }
end

RadioFormat.AckExpect = function(cs: string): Expect
	return {
		to = "CG",
		from = cs,
		proword = "Over",
		bodies = { copy_launching = 1, wilco = 1, roger = 0.5 },
	}
end

-- The tasking acknowledgement wheel: one right answer, procedure decoys, "Say again" and "Unable".
function RadioFormat.ackOptions(cs: string, seed: number): { Option }
	local list = {
		option(msg("toFrom", cs, "copy_launching", "Over"), true),
		option(msg("none", cs, "copy_launching", "Over"), false),
		option(msg("toFrom", cs, "copy_launching", "OverAndOut"), false),
		option(msg("fromTo", cs, "roger", "Out"), false),
	}
	shuffle(list, seed)
	table.insert(list, option(msg("toFrom", cs, "say_again", "Over"), false))
	table.insert(list, option(msg("toFrom", cs, "unable", "Over"), false))
	return list
end

RadioFormat.CloseoutExpect = function(cs: string, ferry: boolean): Expect
	return {
		to = "CG",
		from = cs,
		proword = "Over",
		bodies = if ferry then { all_accounted = 1 } else { vessel_secured = 1 },
	}
end

-- POB numbers offered on the closeout: the truth and its neighbours (never below 1).
function RadioFormat.pobChoices(truth: number, seed: number): { number }
	local set = { truth }
	if truth > 1 then
		table.insert(set, truth - 1)
	end
	table.insert(set, truth + 1)
	if #set < 3 then
		table.insert(set, truth + 2)
	end
	return shuffle(set, seed)
end

-- The closeout wheel: correct procedure with each POB choice, plus two procedure decoys.
function RadioFormat.closeoutOptions(
	cs: string,
	truth: number,
	ferry: boolean,
	seed: number
): { Option }
	local body = if ferry then "all_accounted" else "vessel_secured"
	local key = if ferry then "n" else "pob"
	local list: { Option } = {}
	local choices = RadioFormat.pobChoices(truth, seed)
	for _, n in choices do
		local p = { [key] = n, [key .. "N"] = n }
		table.insert(list, option(msg("toFrom", cs, body, "Over", p), n == truth))
	end
	local pick = lcg(seed + 7)
	local n1 = choices[pick(1, #choices)]
	local n2 = choices[pick(1, #choices)]
	table.insert(
		list,
		option(msg("toFrom", cs, body, "OverAndOut", { [key] = n1, [key .. "N"] = n1 }), false)
	)
	table.insert(
		list,
		option(msg("fromOnly", cs, body, "Out", { [key] = n2, [key .. "N"] = n2 }), false)
	)
	return shuffle(list, seed + 1)
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

-- POB number carried by a message (closeout and launch bodies), or nil.
function RadioFormat.pobOf(m: Message): number?
	local p: { [string]: any } = m.params or {}
	local v = p.pob or p.n
	return if type(v) == "number" then v else nil
end

return RadioFormat
