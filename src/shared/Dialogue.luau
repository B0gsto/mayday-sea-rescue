--!strict
-- Dialogue: what the town NPCs say when the player walks up and talks (TalkController). Pure data
-- plus two lookups; tested in tests/Dialogue.spec.luau.
--   Dialogue.TREES[npcModelName] -> Tree   keyed by the NPC's model name under Workspace.Npcs
--   Dialogue.node(tree, id) -> Node?
--   Dialogue.choose(tree, id, index) -> string?   the next node id; nil ends the conversation
--   Dialogue.check(tree) -> string?               the first problem in a tree, nil when it is sound
-- Lines are one short sentence; each node has 1 to 3 replies (keys 1-3).

export type Option = { text: string, next: string? }
export type Node = { line: string, options: { Option } }
export type Tree = { name: string, start: string, nodes: { [string]: Node } }

local Dialogue = {}

local MAX_LINE = 90 -- characters: one sentence on a phone
local MAX_OPTION = 32

Dialogue.TREES = {
	ChiefAggie = {
		name = "Chief Aggie",
		start = "hello",
		nodes = {
			hello = {
				line = "Kettle's on, love. What can I do for you?",
				options = {
					{ text = "Where do I get a boat?", next = "boat" },
					{ text = "Any advice, Chief?", next = "advice" },
					{ text = "Just saying hello.", next = "bye" },
				},
			},
			boat = {
				line = "The boat desk out front on the quay; tell them Aggie sent you.",
				options = {
					{ text = "And gear?", next = "gear" },
					{ text = "Thanks, Chief." },
				},
			},
			gear = {
				line = "The Chandlery next door has the kit, and you can pick it up before you pay.",
				options = { { text = "Thanks, Chief." } },
			},
			advice = {
				line = "Read the water before you read the chart.",
				options = {
					{ text = "What else?", next = "drills" },
					{ text = "Got it." },
				},
			},
			drills = {
				line = "Drills are on the cork board in the boat hall, and they keep you sharp.",
				options = { { text = "I'll have a look." } },
			},
			bye = {
				line = "Hello yourself. Now go and get them.",
				options = { { text = "Will do." } },
			},
		},
	},
	StationCrew1 = {
		name = "Finn",
		start = "hello",
		nodes = {
			hello = {
				line = "Grand day for it, isn't it?",
				options = {
					{ text = "What's Bosun like?", next = "bosun" },
					{ text = "How's the station?", next = "station" },
					{ text = "See you, Finn." },
				},
			},
			bosun = {
				line = "Soft as butter on the quay, a torpedo in the water.",
				options = { { text = "Good dog." } },
			},
			station = {
				line = "Fresh paint, one jet ski and a lot of mugs to wash.",
				options = {
					{ text = "Who washes them?", next = "mugs" },
					{ text = "Ha. Later, Finn." },
				},
			},
			mugs = {
				line = "Whoever's slowest to the next shout, so be quick.",
				options = { { text = "Noted." } },
			},
		},
	},
	StationCrew2 = {
		name = "Dee",
		start = "hello",
		nodes = {
			hello = {
				line = "Weather's turning later, keep an eye on the sky.",
				options = {
					{ text = "How can you tell?", next = "sky" },
					{ text = "Any tips?", next = "tips" },
					{ text = "Thanks, Dee." },
				},
			},
			sky = {
				line = "Gulls come in low and the harbour goes quiet.",
				options = { { text = "Huh. Thanks." } },
			},
			tips = {
				line = "Come in slow on the survivor, the wash does the rest.",
				options = {
					{ text = "Anything else?", next = "tips2" },
					{ text = "Got it." },
				},
			},
			tips2 = {
				line = "Don't overload the boat; two trips beat one swim.",
				options = { { text = "Fair enough." } },
			},
		},
	},
} :: { [string]: Tree }

function Dialogue.node(tree: Tree, id: string): Node?
	return tree.nodes[id]
end

function Dialogue.choose(tree: Tree, id: string, index: number): string?
	local node = tree.nodes[id]
	local option = node and node.options[index]
	if not option then
		return id -- a key with no reply under it changes nothing
	end
	return option.next
end

function Dialogue.check(tree: Tree): string?
	if not tree.nodes[tree.start] then
		return `start "{tree.start}" missing`
	end
	for id, node in tree.nodes do
		if #node.line == 0 or #node.line > MAX_LINE then
			return `{id}: line length {#node.line}`
		end
		if #node.options < 1 or #node.options > 3 then
			return `{id}: {#node.options} options`
		end
		for _, o in node.options do
			if #o.text > MAX_OPTION then
				return `{id}: reply "{o.text}" too long`
			end
			if o.next and not tree.nodes[o.next] then
				return `{id}: next "{o.next}" missing`
			end
		end
	end
	return nil
end

return Dialogue
