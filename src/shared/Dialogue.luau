--!strict
-- Dialogue: the talk tree types (the quest givers' trees come from Quests/Rules.talk; TalkController shows them)
-- plus lookups; tested in tests/Dialogue.spec.luau.
--   Dialogue.node(tree, id) -> Node?
--   Dialogue.choose(tree, id, index) -> string?   the next node id; nil ends the conversation
--   Dialogue.check(tree) -> string?               the first problem in a tree, nil when it is sound
-- Lines are one short sentence; each node has 1 to 3 replies (keys 1-3).

export type Option = { text: string, next: string?, action: string? } -- action: sent to the server (quests)
export type Node = { line: string, options: { Option } }
export type Tree = { name: string, start: string, nodes: { [string]: Node }, cast: string? } -- cast: VoiceCast id

local Dialogue = {}

local MAX_LINE = 90 -- characters: one sentence on a phone
local MAX_OPTION = 32

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
