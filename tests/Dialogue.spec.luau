-- Dialogue: check() catches broken trees and choose() walks one (the quest trees: Quests.spec).
return function(t)
	local Dialogue = t.require("Dialogue")

	t.test("choose branches, ends, and ignores a key with no reply", function()
		local tree = {
			name = "X",
			start = "a",
			nodes = {
				a = { line = "Hi.", options = { { text = "Go", next = "b" } } },
				b = { line = "Bye.", options = { { text = "Ok" }, { text = "Ok" } } },
			},
		}
		t.expect(Dialogue.check(tree)).toBe(nil)
		t.expect(Dialogue.choose(tree, "a", 1)).toBe("b")
		t.expect(Dialogue.choose(tree, "b", 2)).toBe(nil)
		t.expect(Dialogue.choose(tree, "b", 3)).toBe("b")
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
