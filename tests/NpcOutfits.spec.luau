-- NpcOutfits: the R15 NPC outfit table (docs/12 section 2.9) has the shape NpcFactory expects.
return function(t)
	local NpcOutfits = t.require("Config/NpcOutfits")
	local ROLES = { "Crew", "Aggie", "Swimmer", "Boater", "Passenger" }

	local function validId(id)
		return type(id) == "number" and id > 0 and id == math.floor(id)
	end

	local function checkOutfit(o)
		t.expect(type(o.name) == "string" and #o.name > 0).toBeTruthy()
		for _, key in { "layers", "hair", "hat", "front", "waist", "back" } do
			t.expect(type(o[key])).toBe("table")
		end
		for _, key in { "hair", "hat", "front", "waist", "back" } do
			for _, id in o[key] do
				t.expect(validId(id)).toBeTruthy()
			end
		end
		for _, l in o.layers do
			t.expect(validId(l.id)).toBeTruthy()
			t.expect(NpcOutfits.LAYER_KINDS[l.kind]).toBe(true)
		end
		for _, key in { "shirt", "pants", "face" } do
			t.expect(o[key] == nil or validId(o[key])).toBeTruthy()
		end
		-- something on the torso and the legs, and a head of hair or a hat
		local top = o.shirt ~= nil or #o.front > 0
		local legs = o.pants ~= nil
		for _, l in o.layers do
			top = top
				or l.kind == "TShirt"
				or l.kind == "Shirt"
				or l.kind == "Jacket"
				or l.kind == "Sweater"
			legs = legs or l.kind == "Pants" or l.kind == "Shorts" or l.kind == "DressSkirt"
		end
		t.expect(top and legs).toBeTruthy()
		t.expect(#o.hair + #o.hat > 0).toBeTruthy()
		if o.skin then
			t.expect(string.match(o.skin, "^#%x%x%x%x%x%x$") ~= nil).toBeTruthy()
		end
		if o.scale then
			for _, k in { "height", "width", "depth", "head" } do
				t.expect(o.scale[k] >= 0.5 and o.scale[k] <= 1.5).toBeTruthy()
			end
			t.expect(o.scale.bodyType >= 0 and o.scale.bodyType <= 1).toBeTruthy()
			t.expect(o.scale.proportion >= 0 and o.scale.proportion <= 1).toBeTruthy()
		end
	end

	t.test("every role has variants with a valid outfit shape", function()
		for _, role in ROLES do
			local variants = NpcOutfits.Roles[role]
			t.expect(type(variants) == "table" and #variants > 0).toBeTruthy()
			for _, o in variants do
				checkOutfit(o)
			end
		end
		for _, tone in NpcOutfits.SKIN_TONES do
			t.expect(string.match(tone, "^#%x%x%x%x%x%x$") ~= nil).toBeTruthy()
		end
	end)

	t.test("crew wear the drysuit / lifejacket kit with a helmet; Aggie wears navy", function()
		local id = NpcOutfits.ID
		for _, o in NpcOutfits.Roles.Crew do
			t.expect(table.find(o.hat, id.rescueHelmet) ~= nil).toBeTruthy()
			t.expect(#o.front > 0).toBeTruthy()
			t.expect(o.stormGear).toBe(false)
		end
		t.expect(table.find(NpcOutfits.Roles.Aggie[1].front, id.navyLifejacket) ~= nil).toBeTruthy()
	end)

	t.test("pick is deterministic, covers every variant and fills the skin tone", function()
		for _, role in ROLES do
			local seen = {}
			for seed = 0, 40 do
				local a = NpcOutfits.pick(role, seed, false)
				local b = NpcOutfits.pick(role, seed, false)
				t.expect(a.name).toBe(b.name)
				t.expect(a.skin).toBe(b.skin)
				t.expect(a.skin ~= nil).toBeTruthy()
				checkOutfit(a)
				seen[a.name] = true
			end
			local n = 0
			for _ in seen do
				n += 1
			end
			t.expect(n).toBe(#NpcOutfits.Roles[role])
		end
		t.expect(NpcOutfits.pick("NoSuchRole", 0).name).toBe(NpcOutfits.Roles.Passenger[1].name)
	end)

	t.test(
		"storms add the wet-weather layer except for drysuited crew, and never mutate the table",
		function()
			local raincoat = NpcOutfits.STORM.layers[1].id
			local walker = NpcOutfits.pick("Swimmer", 3, true)
			local coats = 0
			for _, l in walker.layers do
				t.expect(l.kind == "Jacket" and l.id ~= raincoat).toBe(false)
				if l.id == raincoat then
					coats += 1
				end
			end
			t.expect(coats).toBe(1)
			t.expect(walker.hat[1]).toBe(NpcOutfits.STORM.hat[1])
			checkOutfit(walker)
			t.expect(NpcOutfits.Roles.Swimmer[4].layers[1].kind).toBe("Jacket")
			t.expect(#NpcOutfits.Roles.Swimmer[4].hat).toBe(0)
			local crew = NpcOutfits.pick("Crew", 0, true)
			t.expect(crew.name).toBe(NpcOutfits.Roles.Crew[1].name)
			t.expect(#crew.layers).toBe(0)
		end
	)
end
