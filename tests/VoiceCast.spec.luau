-- VoiceCast: every cast member has a valid TTS preset, speakers resolve, text is cleaned and chunked.
return function(t)
	local VoiceCast = t.load("src/client/UI/VoiceCast.luau")
	local Lines = t.load("src/client/UI/RadioLines.luau")

	t.test("every lines.csv voice has a preset in range", function()
		for _, cast in Lines.Voices do
			local v = VoiceCast.Cast[cast]
			t.expect(`{cast}: {v ~= nil}`).toBe(`{cast}: true`)
			t.expect(math.abs(v.pitch) <= 12 and v.speed >= 0.5 and v.speed <= 2).toBe(true)
			t.expect(tonumber(v.voice) ~= nil).toBe(true)
		end
	end)

	t.test("speaker names map to the cast", function()
		t.expect(VoiceCast.castFor("Chief Aggie · Port Haven", "X")).toBe("AGGIE")
		t.expect(VoiceCast.castFor("Gale Isles Coastguard", "X")).toBe("CG_DAY")
		t.expect(VoiceCast.castFor("Haven Harbour", "X")).toBe("PATROL")
		t.expect(VoiceCast.castFor("Crew", "X")).toBe("CREW_FINN")
		t.expect(VoiceCast.castFor("Dee", "X")).toBe("CREW_DEE")
		t.expect(VoiceCast.castFor("You pull once:", "X")).toBe("PLAYER_M")
		t.expect(VoiceCast.castFor("LOU", "X")).toBe("LOU")
		t.expect(VoiceCast.castFor("Deeside", "X")).toBe("X")
	end)

	t.test("spoken text drops cues and keeps quoted speech", function()
		t.expect(VoiceCast.spoken("[Faint tapping, somewhere aft]")).toBe(nil)
		t.expect(VoiceCast.spoken('Mara: "Stay close."')).toBe("Stay close.")
		t.expect(VoiceCast.spoken('[One pull: "All OK?"]')).toBe(nil)
		t.expect(VoiceCast.spoken("Securite, securite.")).toBe("say-cure-ee-tay, say-cure-ee-tay.")
		t.expect(VoiceCast.spoken("Pan-pan, pan-pan.")).toBe("pahn-pahn, pahn-pahn.")
	end)

	t.test("chunks stay under the TTS limit and keep every word", function()
		local s = string.rep("Haven Rescue, steer two seven zero. ", 20)
		local parts = VoiceCast.chunks(s)
		t.expect(#parts > 1).toBe(true)
		local words = 0
		for _, p in parts do
			t.expect(#p <= VoiceCast.MAX).toBe(true)
			for _ in string.gmatch(p, "%S+") do
				words += 1
			end
		end
		t.expect(words).toBe(120)
		t.expect(#VoiceCast.chunks("Short.")).toBe(1)
	end)
end
