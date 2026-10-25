--!strict
-- Quests/Data (docs/23 (l), WP-21b): the six quest givers at the hub's quest camps (HubLayout.Hub.questSpots, in
-- order) and their quests. Pure data, Lune-safe; Quests/Rules reads it, tests/Quests.spec.luau checks it.
--   kind  find     pick the item up on an outer island (walk into it), carry it back to the giver
--         deliver  you carry the item from the camp; walk it to the spot, then back to the giver
--         salvage  in the submarine, reach the item at a CallTypes.DiveSites wreck, bring it back
--         rescue   a call is offered at the `zone` (CallTypes.SpawnZones); deliver the survivor as usual, then back
--   at    find / deliver: { island (WorldConfig.Islands id), from (its point: landing / stamp / dock), offset }
--         salvage: { site = CallTypes.DiveSites id }; rescue: { zone = CallTypes.SpawnZones id }
--   after the quest that must be done first (a chain); blueprint = the DockConfig.Blueprints key it unlocks
-- Lines are at most 12 words; replies 1 to 3 words (Rules.REPLIES).

export type At = { island: string?, from: string?, offset: Vector3?, site: string?, zone: string? }
export type Quest = {
	id: string,
	npc: string,
	kind: string,
	item: string,
	at: At,
	ask: string,
	thanks: string,
	cash: number,
	needs: string?, -- a vehicle the player must be able to use (salvage: Submarine)
	after: string?,
	blueprint: string?,
}
export type Npc =
	{ id: string, name: string, role: string, seed: number, cast: string, idle: string }

local Data = {}

-- pay (docs/23 (i): a call is ~300 x distance up to x4, ~1,100 Cash in ~4.5 min). A quest is a trip
-- out to an outer island and back (~1.5 calls); a rescue quest also pays the call itself.
local FIND, SALVAGE, RESCUE = 1500, 2500, 1000

Data.Npcs = {
	{
		id = "QuestMaud",
		name = "Old Maud",
		role = "Passenger",
		seed = 0,
		cast = "HAZEL",
		idle = "Nothing lost today, dear. Pop back tomorrow.",
	},
	{
		id = "QuestTam",
		name = "Tam",
		role = "Boater",
		seed = 0,
		cast = "PATROL",
		idle = "No cargo today. Try me tomorrow.",
	},
	{
		id = "QuestRook",
		name = "Captain Rook",
		role = "Boater",
		seed = 1,
		cast = "BARNABY",
		idle = "Wrecks keep. Come back with a sub.",
	},
	{
		id = "QuestNell",
		name = "Nell",
		role = "Passenger",
		seed = 1,
		cast = "PARENT_F",
		idle = "Everyone's safe today. Thank goodness.",
	},
	{
		id = "QuestIves",
		name = "Keeper Ives",
		role = "Boater",
		seed = 2,
		cast = "INFORMANT_M",
		idle = "The lamp can wait till tomorrow.",
	},
	{
		id = "QuestPip",
		name = "Pip",
		role = "Passenger",
		seed = 2,
		cast = "TEEN_M",
		idle = "Nothing today. Tomorrow, maybe!",
	},
} :: { Npc }

local function q(row: { [string]: any }, cash: number): Quest
	row.cash = cash
	return row :: any
end

local function v(x: number, z: number): Vector3
	return Vector3.new(x, 0, z)
end

Data.Quests = {
	q({
		id = "Dog",
		npc = "QuestMaud",
		kind = "find",
		item = "dog",
		at = { island = "PuffinIsle", from = "landing", offset = v(12, 8) },
		ask = "My dog Biscuit ran off on Puffin Isle!",
		thanks = "Biscuit! Oh, you angel.",
	}, FIND),
	q({
		id = "Satchel",
		npc = "QuestMaud",
		kind = "find",
		item = "satchel",
		at = { island = "SkerryIsle", from = "landing", offset = v(10, -6) },
		ask = "I left my satchel on Skerry Isle. Fetch it?",
		thanks = "My satchel! Bless you.",
	}, FIND),
	q({
		id = "Keeper",
		npc = "QuestTam",
		kind = "deliver",
		item = "crate",
		at = { island = "GannetRock", from = "landing", offset = v(0, 0) },
		ask = "Supplies for the Gannet Rock keeper. Take this crate?",
		thanks = "Keeper got them? Good work.",
	}, FIND),
	q({
		id = "Post",
		npc = "QuestTam",
		kind = "deliver",
		item = "sack",
		at = { island = "Penwyn", from = "landing", offset = v(-10, 0) },
		ask = "Penwyn's post is late. Run this sack over?",
		thanks = "Post delivered. Ta!",
	}, FIND),
	q({
		id = "Bell",
		npc = "QuestRook",
		kind = "salvage",
		item = "bell",
		at = { site = "GannetStar" },
		needs = "Submarine",
		ask = "The Gannet Star's bell lies below. Bring it up?",
		thanks = "Her bell! She rings again.",
	}, SALVAGE),
	q({
		id = "Chest",
		npc = "QuestRook",
		kind = "salvage",
		item = "chest",
		at = { site = "ReefHulk" },
		needs = "Submarine",
		ask = "A sea chest lies in the Wreck Reef hulk.",
		thanks = "Heavy, isn't it? Well done.",
	}, SALVAGE),
	q({
		id = "Kayak",
		npc = "QuestNell",
		kind = "rescue",
		item = "",
		at = { zone = "WreckReef" },
		ask = "My brother Jory kayaked to Wreck Reef. He's late!",
		thanks = "Jory's safe! Thank you!",
	}, RESCUE),
	q({
		id = "Swim",
		npc = "QuestNell",
		kind = "rescue",
		item = "",
		at = { zone = "TheArches" },
		ask = "My friend swam out by the Arches. Please hurry!",
		thanks = "She's home! You're a hero.",
	}, RESCUE),
	q({
		id = "Lamp1",
		npc = "QuestIves",
		kind = "find",
		item = "glass",
		at = { island = "GannetRock", from = "landing", offset = v(-8, 10) },
		ask = "My lamp needs new glass. It washed up on Gannet Rock.",
		thanks = "Good glass. Now the oil.",
	}, FIND),
	q({
		id = "Lamp2",
		npc = "QuestIves",
		kind = "find",
		item = "oil",
		after = "Lamp1",
		at = { island = "MermaidLagoon", from = "landing", offset = v(-12, 6) },
		ask = "Lamp oil drifted to Mermaid Lagoon. Fetch the drum?",
		thanks = "Oil's in. One last job.",
	}, FIND),
	q({
		id = "Lamp3",
		npc = "QuestIves",
		kind = "find",
		item = "lens",
		after = "Lamp2",
		at = { island = "TheArches", from = "landing", offset = v(10, 8) },
		ask = "The old lens is up at the Arches. Bring it home.",
		thanks = "Done! Build your own lighthouse at home.",
		blueprint = "Lighthouse",
	}, 2000),
	q({
		id = "Kite",
		npc = "QuestPip",
		kind = "find",
		item = "kite",
		at = { island = "MermaidLagoon", from = "landing", offset = v(14, -4) },
		ask = "My kite blew to Mermaid Lagoon! Can you get it?",
		thanks = "My kite! Best day ever!",
	}, FIND),
	q({
		id = "Lunch",
		npc = "QuestPip",
		kind = "deliver",
		item = "lunch",
		at = { island = "SkerryIsle", from = "landing", offset = v(-10, 6) },
		ask = "Dad's fishing on Skerry Isle. Take him his lunch?",
		thanks = "He got it? Yes!",
	}, FIND),
} :: { Quest }

Data.byId = {} :: { [string]: Quest }
for _, quest in Data.Quests do
	Data.byId[quest.id] = quest
end
Data.npcById = {} :: { [string]: Npc }
for _, npc in Data.Npcs do
	Data.npcById[npc.id] = npc
end

return table.freeze(Data)
