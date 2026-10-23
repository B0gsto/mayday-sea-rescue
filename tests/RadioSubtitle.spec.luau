-- RadioSubtitle (docs/16 K17): subtitles of six words at most; the voice keeps the whole line.
return function(t)
	local S = t.load("src/client/UI/RadioSubtitle.luau")

	local function count(s: string): number
		local n = 0
		for _ in string.gmatch(s, "%S+") do
			n += 1
		end
		return n
	end

	t.test("every written short form is six words or fewer", function()
		for full, short in S.Short do
			t.expect(full).toBe(string.lower(full))
			t.expect(count(short) <= S.MAX_WORDS).toBe(true)
		end
	end)

	t.test("a known op line gets its short form", function()
		local line = "Haven Rescue, Gale Isles Coastguard. Person in the water, request you launch."
		t.expect(S.of(line)).toBe("Person in the water. Launch.")
	end)

	t.test("short lines pass through untouched", function()
		t.expect(S.of("Casualty safe. Good work!")).toBe("Casualty safe. Good work!")
		t.expect(S.of("Person in the water. Dead ahead!")).toBe("Person in the water. Dead ahead!")
	end)

	t.test("the address and procedure words go first", function()
		t.expect(S.of("One-One, Coastguard. Roger. Datum is on your chart. Out."))
			.toBe("Datum is on your chart.")
		t.expect(S.of("One-One, Coastguard. Request situation report, over."))
			.toBe("Request situation report.")
	end)

	t.test("anything else is cut to six words", function()
		local out =
			S.of("Rescue Gale One has the casualty and is lifting now. Carry on with your search.")
		t.expect(count(out) <= S.MAX_WORDS).toBe(true)
		t.expect(string.sub(out, 1, 15)).toBe("Rescue Gale One")
	end)
end
