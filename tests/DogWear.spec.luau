-- RP-M5 Bosun's Wardrobe / Water Dog Friends: the dog slots load and validate, every option has a look,
-- no colour is a reserved signal colour, part geometry is sane and sits on Bosun.
return function(t)
	local Cos = t.load("src/shared/Cosmetics.luau")
	local W = t.load("src/shared/Dog/DogWear.luau")
	local Config = t.load("src/shared/Config/MonetizationConfig.luau")

	local function ownsNone(_: string): boolean
		return false
	end
	local function ownsWardrobe(key: string): boolean
		return key == "BosunsWardrobe"
	end

	t.test("dog slots validate and defaults are free", function()
		t.expect(#Cos.validate()).toBe(0)
		for _, slot in { "Dog", "DogBandana", "DogJacket" } do
			t.expect(Cos.slot(slot) ~= nil).toBeTruthy()
			local def = Cos.option(slot, Cos.default(slot))
			t.expect(def ~= nil and def.pass == nil).toBeTruthy()
		end
		t.expect(Config.GamePasses.BosunsWardrobe ~= nil).toBeTruthy()
		t.expect(Config.GamePasses.WaterDogFriends ~= nil).toBeTruthy()
	end)

	t.test("wardrobe counts: six bandanas and a life jacket", function()
		local function paid(slot)
			local n = 0
			for _, o in Cos.slot(slot).options do
				if o.pass then
					t.expect(o.pass).toBe("BosunsWardrobe")
					n += 1
				end
			end
			return n
		end
		t.expect(paid("DogBandana")).toBe(6)
		t.expect(paid("DogJacket")).toBe(1)
		t.expect(#Cos.slotsForPass("BosunsWardrobe")).toBe(2)
		t.expect(Cos.slot("DogHarness")).toBeNil() -- not shipped (art review)
		t.expect(Cos.slot("DogHat")).toBeNil()
	end)

	t.test("equip rules follow the pass", function()
		t.expect(Cos.canEquip("DogBandana", "Red", ownsNone)).toBe(false)
		t.expect(Cos.canEquip("DogBandana", "Red", ownsWardrobe)).toBe(true)
		t.expect(Cos.canEquip("Dog", "Labrador", ownsWardrobe)).toBe(false)
		local s = Cos.sanitize({ DogJacket = "LifeJacket", Dog = "Labrador" }, ownsWardrobe)
		t.expect(s.DogJacket).toBe("LifeJacket")
		t.expect(s.Dog).toBe("Bosun")
	end)

	t.test("every option has a look that builds", function()
		local kinds = { DogBandana = "Bandana", DogJacket = "Jacket" }
		for slot, kind in kinds do
			for _, o in Cos.slot(slot).options do
				local n = #W.parts(kind, o.look)
				if o.look == "None" then
					t.expect(n).toBe(0)
				else
					t.expect(n > 0).toBeTruthy()
				end
			end
		end
		for _, o in Cos.slot("Dog").options do
			t.expect(type(o.breed)).toBe("string")
			if o.pass then
				t.expect(o.pass).toBe("WaterDogFriends")
			end
		end
	end)

	t.test("no cosmetic colour is a reserved signal colour", function()
		for _, hex in W.allColors() do
			for name, reserved in W.RESERVED do
				local d = W.distance(hex, reserved)
				if d < W.MIN_RESERVED_DISTANCE then
					error(`{hex} too close to {name} ({d})`)
				end
			end
		end
	end)

	t.test("parts are sane and sit on the dog", function()
		local all = {}
		for _, look in { "Red", "Navy" } do
			for _, p in W.parts("Bandana", look) do
				table.insert(all, p)
			end
		end
		for _, p in W.lifeJacket() do
			table.insert(all, p)
		end
		for _, p in W.captainsHat() do
			table.insert(all, p)
		end
		local names = {}
		for _, p in all do
			t.expect(p.on == "Fore" or p.on == "Head").toBeTruthy()
			t.expect(p.size.X > 0 and p.size.Y > 0 and p.size.Z > 0).toBeTruthy()
			t.expect(#p.color).toBe(6)
			local pos = p.cframe.Position
			-- inside Bosun's LOD0 bounds plus a coat's depth (studs, authored frame)
			t.expect(math.abs(pos.X) < 1.0).toBeTruthy()
			t.expect(pos.Y > 0.8 and pos.Y < 3.0).toBeTruthy()
			t.expect(pos.Z > -1.9 and pos.Z < 1.4).toBeTruthy()
			local r, u = p.cframe.RightVector, p.cframe.UpVector
			t.expect(math.abs(r:Dot(u)) < 1e-4).toBeTruthy()
			names[p.name] = true
		end
		t.expect(names.JacketHandle).toBeTruthy()
		t.expect(names.HatCrown).toBeTruthy()
		t.expect(names.BandanaR and names.BandanaL).toBeTruthy()
	end)
end
