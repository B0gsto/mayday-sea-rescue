--!strict
-- Quests/Rules (docs/23 (l), WP-21b): the pure quest rules, Lune-safe (tests/Quests.spec.luau). QuestService runs
-- them on the server; TalkController builds the talk tree from them.
--   One active quest per player. Stages: "go" (the pin on the target) -> "back" (the pin on the giver, "?").
--   Rotation: each giver offers one quest a day (Rules.offer: a day seed over the ones not yet done, chain steps in
--   order); a giver whose quest was finished today offers nothing more till tomorrow, except the next step of the
--   chain just handed in, which is offered at once. When every quest of a giver is done, their pool starts over.
--   Save: profile flag `quest` = { a = active id, s = stage, x<id> = true (done), n<giver> = the day of their last }.
--   `next` (the chain step just unlocked) is session only: it is not encoded.
local CallTypes = require(script.Parent.Parent:WaitForChild("Calls"):WaitForChild("CallTypes"))
local Data = require(script.Parent:WaitForChild("Data"))
local Dialogue = require(script.Parent.Parent:WaitForChild("Dialogue"))
local WorldConfig = require(script.Parent.Parent:WaitForChild("Config"):WaitForChild("WorldConfig"))

export type State = {
	active: string?,
	stage: string?,
	done: { [string]: boolean },
	last: { [string]: number },
	next: string?,
}

local Rules = {}

Rules.DAY = 86400
-- studs from the character (3D) at which the item is picked up / the delivery lands; salvage: from the sub
Rules.RANGE = { find = 12, deliver = 14, salvage = 30 } :: { [string]: number }
Rules.REPLIES = {
	accept = "On it!",
	later = "Later.",
	handIn = "Here you go.",
	going = "On my way.",
	drop = "Give up.",
	bye = "See you.",
}
Rules.BUSY = "Finish your other job first, love."

function Rules.day(unix: number): number
	return unix // Rules.DAY
end

function Rules.new(): State
	return { done = {}, last = {} }
end

function Rules.decode(flag: any): State
	local s = Rules.new()
	if type(flag) ~= "table" then
		return s
	end
	if type(flag.a) == "string" and Data.byId[flag.a] then
		s.active = flag.a
		s.stage = if flag.s == "back" then "back" else "go"
	end
	for id in Data.byId do
		if flag["x" .. id] == true then
			s.done[id] = true
		end
	end
	for id in Data.npcById do
		if type(flag["n" .. id]) == "number" then
			s.last[id] = flag["n" .. id]
		end
	end
	return s
end

function Rules.encode(s: State): { [string]: any }
	local out: { [string]: any } = { a = s.active, s = s.stage }
	for id in s.done do
		out["x" .. id] = true
	end
	for id, day in s.last do
		out["n" .. id] = day
	end
	return out
end

local function islandRow(id: string): any
	for _, row in WorldConfig.Islands do
		if row.id == id then
			return row
		end
	end
	return nil
end

-- Where the quest's thing is (find / deliver: on the ground before the server settles it; salvage: the wreck on
-- the seabed; rescue: the middle of the call zone).
function Rules.target(quest: Data.Quest): Vector3
	local at = quest.at
	if at.site then
		for _, site in CallTypes.DiveSites do
			if site.id == at.site then
				return site.wreck
			end
		end
	elseif at.zone then
		return CallTypes.SpawnZones[at.zone].center
	end
	local row = islandRow(at.island :: string)
	return (row[at.from or "landing"] :: Vector3) + (at.offset or Vector3.zero)
end

-- The island the quest goes to: its id (UiImages.Stickers key) and display name, for the 1-3 word cards.
function Rules.place(quest: Data.Quest): (string, string)
	local at = quest.at
	local id = at.island or at.zone
	if at.site then
		for _, site in CallTypes.DiveSites do
			if site.id == at.site then
				id = site.island
			end
		end
	end
	local row = islandRow(id :: string)
	return id :: string, if row then row.name else id :: string
end

-- Today's quest from giver `npc`, or nil. `can(quest)` = the player can do it (salvage needs the submarine).
function Rules.offer(
	s: State,
	npc: string,
	day: number,
	can: ((Data.Quest) -> boolean)?
): Data.Quest?
	-- the chain step unlocked by the last hand-in comes before the day rotation
	local nxt = s.next and Data.byId[s.next]
	if nxt and nxt.npc == npc and not s.done[nxt.id] and (can == nil or can(nxt)) then
		return nxt
	end
	if s.last[npc] == day then
		return nil
	end
	local open = {}
	for _, quest in Data.Quests do
		if
			quest.npc == npc
			and not s.done[quest.id]
			and (quest.after == nil or s.done[quest.after])
			and (can == nil or can(quest))
		then
			table.insert(open, quest)
		end
	end
	if #open == 0 then
		return nil
	end
	local salt = 0
	for i = 1, #npc do
		salt += string.byte(npc, i)
	end
	return open[(day * 7 + salt) % #open + 1]
end

function Rules.accept(s: State, quest: Data.Quest): boolean
	if s.active then
		return false
	end
	s.active, s.stage = quest.id, "go"
	return true
end

-- The thing is picked up / delivered / the survivor is home: back to the giver.
function Rules.reached(s: State)
	if s.active then
		s.stage = "back"
	end
end

function Rules.drop(s: State)
	s.active, s.stage = nil, nil
end

-- Hand in at the giver: the quest is done (its pool starts over once all of the giver's are). -> the quest or nil.
function Rules.complete(s: State, day: number): Data.Quest?
	local quest = s.active and Data.byId[s.active]
	if not quest or s.stage ~= "back" then
		return nil
	end
	s.done[quest.id] = true
	s.last[quest.npc] = day
	s.active, s.stage = nil, nil
	s.next = nil
	for _, other in Data.Quests do
		if other.npc == quest.npc and other.after == quest.id and not s.done[other.id] then
			s.next = other.id
			break
		end
	end
	local all = true
	for _, other in Data.Quests do
		if other.npc == quest.npc and not s.done[other.id] then
			all = false
		end
	end
	if all then
		for _, other in Data.Quests do
			if other.npc == quest.npc then
				s.done[other.id] = nil
			end
		end
	end
	return quest
end

-- The talk tree for giver `npc` (Dialogue.Tree; option actions: accept, handIn, drop). `active` / `stage` the
-- player's quest, `offer` the id this giver offers today (QuestService's player attributes).
function Rules.talk(npc: string, active: string?, stage: string?, offer: string?): Dialogue.Tree
	local who = Data.npcById[npc]
	local R = Rules.REPLIES
	local mine = active and Data.byId[active]
	local node: Dialogue.Node
	if mine and mine.npc == npc then
		node = if stage == "back"
			then { line = mine.thanks, options = { { text = R.handIn, action = "handIn" } } }
			else {
				line = mine.ask,
				options = { { text = R.going }, { text = R.drop, action = "drop" } },
			}
	elseif offer and Data.byId[offer] and not active then
		node = {
			line = Data.byId[offer].ask,
			options = { { text = R.accept, action = "accept" }, { text = R.later } },
		}
	elseif offer and active then
		node = { line = Rules.BUSY, options = { { text = R.bye } } }
	else
		node = { line = who.idle, options = { { text = R.bye } } }
	end
	return { name = who.name, start = "hello", nodes = { hello = node }, cast = who.cast }
end

return Rules
