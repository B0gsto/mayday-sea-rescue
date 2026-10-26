-- VoiceCast: every cast member has a valid TTS preset, text is cleaned and chunked.
return function(t)
	local VoiceCast = t.load("src/client/UI/VoiceCast.luau")

	t.test("every cast member has a preset in range", function()
		for _, v in VoiceCast.Cast do
			t.expect(math.abs(v.pitch) <= 12 and v.speed >= 0.5 and v.speed <= 2).toBe(true)
			t.expect(tonumber(v.voice) ~= nil).toBe(true)
		end
	end)

	t.test("spoken text drops cues and keeps quoted speech", function()
		t.expect(VoiceCast.spoken("[Faint tapping, somewhere aft]")).toBe(nil)
		t.expect(VoiceCast.spoken('Mara: "Stay close."')).toBe("Stay close.")
		t.expect(VoiceCast.spoken('[One pull: "All OK?"]')).toBe(nil)
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
