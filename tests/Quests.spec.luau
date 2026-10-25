-- Quests (docs/23 (l), WP-21b): the data is sound, rotation is daily and never repeats until the pool cycles,
-- the chain runs in order, the save flag round-trips, the talk trees pass Dialogue.check.
return function(t)
	local Data = t.require("Quests/Data")
	local Rules = t.require("Quests/Rules")
	local Dialogue = t.require("Dialogue")
	local CallTypes = t.require("Calls/CallTypes")
	local DockConfig = t.require("Config/DockConfig")
	local HubLayout = t.require("Config/HubLayout")
	local ProgressionRules = t.require("ProgressionRules")

	local function words(s: string): number
		local n = 0
		for _ in string.gmatch(s, "%S+") do
			n += 1
		end
		return n
	end

	t.test("six givers, one per quest camp; every quest is sound", function()
		t.expect(#Data.Npcs).toBe(6)
		t.expect(#HubLayout.Hub.questSpots >= #Data.Npcs).toBe(true)
		t.expect(#Data.Quests >= 12).toBe(true)
		local kinds = {}
		for _, q in Data.Quests do
			kinds[q.kind] = true
			t.expect(`{q.id} giver {Data.npcById[q.npc] ~= nil}`).toBe(`{q.id} giver true`)
			t.expect(`{q.id} ask {words(q.ask) <= 12}`).toBe(`{q.id} ask true`)
			t.expect(`{q.id} thanks {words(q.thanks) <= 12}`).toBe(`{q.id} thanks true`)
			t.expect(typeof(Rules.target(q))).toBe("Vector3")
			if q.kind == "rescue" then
				t.expect(CallTypes.SpawnZones[q.at.zone :: string] ~= nil).toBe(true)
			end
			if q.after then
				t.expect(Data.byId[q.after].npc).toBe(q.npc)
			end
			if q.blueprint then
				t.expect(DockConfig.Blueprints[q.blueprint] ~= nil).toBe(true)
			end
			-- sane against a call (~1,100 Cash, docs/23 (i))
			t.expect(q.cash >= 500 and q.cash <= 3000 and q.rep > 0 and q.rep <= 500).toBe(true)
		end
		for _, k in { "find", "deliver", "salvage", "rescue" } do
			t.expect(`{k} {kinds[k] == true}`).toBe(`{k} true`)
		end
		for _, npc in Data.Npcs do
			t.expect(words(npc.idle) <= 12).toBe(true)
		end
		for _, r in Rules.REPLIES do
			t.expect(words(r) >= 1 and words(r) <= 3).toBe(true)
		end
	end)

	t.test("every talk tree passes Dialogue.check", function()
		for _, npc in Data.Npcs do
			for _, q in Data.Quests do
				for _, case in
					{
						{ nil, nil, q.id },
						{ q.id, "go", nil },
						{ q.id, "back", nil },
						{ q.id, "go", q.id },
					}
				do
					local tree = Rules.talk(npc.id, case[1], case[2], case[3])
					t.expect(Dialogue.check(tree) or "ok").toBe("ok")
				end
			end
			t.expect(Rules.talk(npc.id, nil, nil, nil).nodes.hello.line).toBe(npc.idle)
		end
		local offer = Rules.talk("QuestMaud", nil, nil, "Dog").nodes.hello
		t.expect(offer.options[1].action).toBe("accept")
		t.expect(Rules.talk("QuestMaud", "Dog", "back", nil).nodes.hello.options[1].action)
			.toBe("handIn")
		t.expect(Rules.talk("QuestTam", "Dog", "go", "Keeper").nodes.hello.line).toBe(Rules.BUSY)
	end)

	t.test("one quest at a time: accept, reach, hand in; one per giver per day", function()
		local s = Rules.new()
		local day = 20000
		local dog = Data.byId.Dog
		t.expect(Rules.accept(s, dog)).toBe(true)
		t.expect(Rules.accept(s, Data.byId.Keeper)).toBe(false)
		t.expect(Rules.complete(s, day)).toBeNil() -- not reached yet
		Rules.reached(s)
		t.expect(Rules.complete(s, day)).toBe(dog)
		t.expect(s.active).toBeNil()
		t.expect(Rules.offer(s, "QuestMaud", day)).toBeNil() -- done for today
		local tomorrow = Rules.offer(s, "QuestMaud", day + 1)
		t.expect(tomorrow and tomorrow.id).toBe("Satchel") -- the dog doesn't repeat
		Rules.accept(s, tomorrow :: any)
		Rules.reached(s)
		Rules.complete(s, day + 1)
		t.expect(s.done.Dog).toBeNil() -- the pool cycled
		t.expect(Rules.offer(s, "QuestMaud", day + 2) ~= nil).toBe(true)
	end)

	t.test("the offer is the same all day and changes with the day", function()
		local s = Rules.new()
		local seen = {}
		for day = 20000, 20009 do
			local a = Rules.offer(s, "QuestTam", day)
			t.expect(a).toBe(Rules.offer(s, "QuestTam", day))
			seen[(a :: any).id] = true
		end
		t.expect(seen.Keeper and seen.Post).toBe(true)
	end)

	t.test("the chain runs in order and its last step names the blueprint", function()
		local s = Rules.new()
		for i, id in { "Lamp1", "Lamp2", "Lamp3" } do
			local q = Rules.offer(s, "QuestIves", 20000 + i)
			t.expect(q and q.id).toBe(id)
			Rules.accept(s, q :: any)
			Rules.reached(s)
			Rules.complete(s, 20000 + i)
		end
		t.expect(Data.byId.Lamp3.blueprint).toBe("Lighthouse")
	end)

	t.test("salvage needs the submarine", function()
		local s = Rules.new()
		local noSub = function(q)
			return q.needs == nil
		end
		t.expect(Rules.offer(s, "QuestRook", 20000, noSub)).toBeNil()
		t.expect(Rules.offer(s, "QuestRook", 20000) ~= nil).toBe(true)
	end)

	t.test("the save flag survives the profile sanitiser", function()
		local s = Rules.new()
		Rules.accept(s, Data.byId.Bell)
		Rules.reached(s)
		for _, q in Data.Quests do
			s.done[q.id] = true
		end
		for _, npc in Data.Npcs do
			s.last[npc.id] = 20123
		end
		local raw = ProgressionRules.defaultData()
		raw.flags.quest = Rules.encode(s)
		local back = Rules.decode(ProgressionRules.migrate(raw).flags.quest)
		t.expect(back.active).toBe("Bell")
		t.expect(back.stage).toBe("back")
		t.expect(back.done.Lamp3).toBe(true)
		t.expect(back.last.QuestPip).toBe(20123)
		t.expect(Rules.decode({ a = "Nope" }).active).toBeNil()
		t.expect(Rules.decode(nil).active).toBeNil()
	end)
end
