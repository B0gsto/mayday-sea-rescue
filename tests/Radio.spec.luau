-- Radio: template stitching (RadioStitch + RadioTemplates + RadioLines) and voice-procedure
-- grading (RadioFormat).
return function(t)
	local Stitch = t.load("src/client/UI/RadioStitch.luau")
	local Templates = t.load("src/client/UI/RadioTemplates.luau")
	local Format = t.load("src/client/UI/RadioFormat.luau")
	local Lines = t.load("src/client/UI/RadioLines.luau")

	local piw = {
		cs = "HR11",
		optype = "PIW1",
		distance = "D300",
		direction = "SOUTH_OF",
		place = "SANDY_POINT",
		casDesc = "ADULT_SWIMMER",
		casKit = "NO_LJ",
		casState = "WAVING",
		windDir = "SOUTH_WEST",
		wind = "LIGHT",
	}

	t.test("the PIW tasking stitches into the doc 09 example, fully voiced", function()
		local line = Stitch.build("CG", Templates.Templates.tasking_piw.tokens, piw)
		t.expect(line.complete).toBe(true)
		t.expect(line.voice).toBe("CG_DAY")
		t.expect(line.text).toBe(
			"Haven Rescue One-One, Haven Rescue One-One, this is Gale Isles Coastguard. Launch to a report of one person in the water, three hundred metres south of Sandy Point. Informant on the beach reports an adult swimmer, no lifejacket, waving for help. Wind south-west, light. Over."
		)
		t.expect(line.ids[1]).toBe("CGD_OPEN_HR11")
		t.expect(#line.ids).toBe(14)
	end)

	t.test("night watch uses the CG_NIGHT voice ids with the same text", function()
		local day = Stitch.build("CG", Templates.Templates.ack_datum.tokens, { cs = "HR21" })
		local night = Stitch.build(
			"CG",
			Templates.Templates.ack_datum.tokens,
			{ cs = "HR21" },
			{ night = true }
		)
		t.expect(night.text).toBe(day.text)
		t.expect(night.ids[1]).toBe("CGN_SHORT_HR21")
		t.expect(day.text).toBe("Two-One, Coastguard. Roger. Datum is on your chart. Out.")
	end)

	t.test("every template id exists in lines.csv for every callsign", function()
		local params = table.clone(piw)
		params.pob, params.n, params.minutes, params.pobStem =
			"N02", "N02", "M05", "PERSONS_ON_BOARD"
		params.optype = "ENGINE"
		for name, tpl in Templates.Templates do
			local line = Stitch.build(tpl.voice, tpl.tokens, params)
			for _, p in line.parts do
				if p.id == nil and not p.glue then
					-- only deliberate free-text parts are allowed
					local free = false
					for _, tok in tpl.tokens do
						free = free
							or (
								string.sub(tok, 1, 1) == "'"
								and string.find(tok, p.text, 1, true) ~= nil
							)
					end
					t.expect(free and name or "missing:" .. name .. ":" .. p.text).toBe(name)
				end
			end
		end
	end)

	t.test("unknown params fall back to readable text and mark the line subtitle-only", function()
		local params = table.clone(piw)
		params.place = "NOWHERE_ISLE"
		local line = Stitch.build("CG", Templates.Templates.tasking_piw.tokens, params)
		t.expect(line.complete).toBe(false)
		t.expect(string.find(line.text, "south of nowhere isle.", 1, true) ~= nil).toBe(true)
		t.expect(Stitch.playable(line, {})).toBe(false)
	end)

	t.test("playable needs every clip in the manifest", function()
		local line = Stitch.build("CG", Templates.Templates.roger_out.tokens, { cs = "HR11" })
		local clips = { CGD_SHORT_HR11 = "rbxassetid://1" }
		t.expect(Stitch.playable(line, clips)).toBe(false)
		clips.CGD_TASKING_ROGER_OUT = "rbxassetid://2"
		t.expect(Stitch.playable(line, clips)).toBe(true)
	end)

	t.test("key helpers map game values onto fragment keys", function()
		t.expect(Stitch.key.number(3)).toBe("N03")
		t.expect(Stitch.key.minutes(11)).toBe("M10")
		t.expect(Stitch.key.minutes(14, true)).toBe("M15")
		t.expect(Stitch.key.distance(320)).toBe("D300")
		t.expect(Stitch.key.distance(950)).toBe("NMHALF")
		t.expect(Stitch.key.place("Sandy Point")).toBe("SANDY_POINT")
		t.expect(Stitch.key.place("the harbour mouth")).toBe("HARBOUR_MOUTH")
		t.expect(Stitch.key.place("Atlantis")).toBeNil()
		t.expect(Stitch.key.compass(225)).toBe("SOUTH_WEST")
		t.expect(Stitch.key.compass(359)).toBe("NORTH")
		t.expect(Lines.text("PLF_FRAG_END_OVER")).toBe("Over.")
	end)

	t.test("the acknowledgement is voiced", function()
		local m = {
			order = "toFrom",
			to = "CG",
			from = "HR11",
			body = "copy_launching",
			proword = "Over",
		}
		local line = Stitch.build("PL", Format.tokens(m), Format.stitchParams(m))
		t.expect(line.text)
			.toBe("Gale Isles Coastguard, Haven Rescue One-One. Copy, launching. Over.")
		t.expect(line.complete).toBe(true)
	end)

	t.test("a subtitle is capped at six words", function()
		t.expect(Format.capWords("Copy, launching. Over.", 6)).toBe("Copy, launching. Over.")
		t.expect(
			Format.capWords(
				"Gale Isles Coastguard, Haven Rescue One-One. Copy, launching. Over.",
				6
			)
		)
			.toBe("Gale Isles Coastguard, Haven Rescue One-One…")
		t.expect(Format.capWords("One  two\nthree", 2)).toBe("One two…")
		-- call-outs: the speaker tag before a quote is free
		t.expect(Format.capLine('Crew: "Abort, abort! Go round!"', 6))
			.toBe('Crew: "Abort, abort! Go round!"')
		t.expect(Format.capLine('Crew: "One two three four five six seven"', 3))
			.toBe('Crew: "One two three…')
		t.expect(Format.capLine("Out of time: a heavy, clumsy lift.", 3)).toBe("Out of time…")
	end)

	t.test("a caption is the message in three words", function()
		t.expect(
			Format.caption(
				"Haven Rescue, Coastguard. Tasking available. Details on your radio panel. Over.",
				3
			)
		).toBe("Tasking available")
		t.expect(
			Format.caption(
				"Haven Rescue, Gale Isles Coastguard. Person in the water, request you launch.",
				3
			)
		).toBe("Person in water")
		-- one sentence that only looks like an address keeps its words
		t.expect(Format.caption("All Haven Rescue units, launch, launch.", 3))
			.toBe("All Haven Rescue")
		t.expect(Format.caption("Over here!", 3)).toBe("Over here")
	end)

	t.test("join glues punctuation and capitalises sentences", function()
		local text = Stitch.join({
			{ text = "copy," },
			{ text = "two" },
			{ text = "recovered." },
			{ text = "out." },
		})
		t.expect(text).toBe("Copy, two recovered. Out.")
		t.expect(Stitch.readSeconds("one two three") >= 1.5).toBe(true)
	end)
end
