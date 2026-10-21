-- Dialogue: every NPC tree is sound (start, replies, links, short lines) and choose() walks it.
return function(t)
	local Dialogue = t.require("Dialogue")

	t.test("every tree is sound and every node is reachable", function()
		for npc, tree in Dialogue.TREES do
			t.expect(`{npc}: {Dialogue.check(tree) or "ok"}`).toBe(`{npc}: ok`)
			local seen, queue = { [tree.start] = true }, { tree.start }
			while #queue > 0 do
				local node = Dialogue.node(tree, table.remove(queue) :: string)
				for _, o in node.options do
					if o.next and not seen[o.next] then
						seen[o.next] = true
						table.insert(queue, o.next)
					end
				end
			end
			for id in tree.nodes do
				t.expect(`{npc}.{id} reachable {seen[id] == true}`)
					.toBe(`{npc}.{id} reachable true`)
			end
		end
	end)

	t.test("choose branches, ends, and ignores a key with no reply", function()
		local aggie = Dialogue.TREES.ChiefAggie
		t.expect(Dialogue.choose(aggie, "hello", 1)).toBe("boat")
		t.expect(Dialogue.choose(aggie, "boat", 2)).toBe(nil)
		t.expect(Dialogue.choose(aggie, "gear", 3)).toBe("gear")
	end)

	t.test("check catches a broken link", function()
		local bad = {
			name = "X",
			start = "a",
			nodes = { a = { line = "Hi.", options = { { text = "Go", next = "zz" } } } },
		}
		t.expect(Dialogue.check(bad) ~= nil).toBe(true)
	end)
end
