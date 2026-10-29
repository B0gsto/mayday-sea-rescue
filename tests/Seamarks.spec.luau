-- Seamarks (RP-I1b-2): the IALA Region A layout, the light characteristics of the HP2b dims.md files, the
-- photocell and wave-tilt rules, and the S1a wreck / anchor data the server places them by.
return function(t)
	local R = t.load("src/shared/SeamarkRules.luau")
	local AssetIds = t.load("src/shared/Config/AssetIds.luau")
	local WorldConfig = t.load("src/shared/Config/WorldConfig.luau")
	local Ribs = t.load("src/server/World/MorwennaRibs.luau")

	local function mark(id: string): any
		for _, m in R.Marks do
			if m.id == id then
				return m
			end
		end
		error(`no mark {id}`)
	end

	-- the dims.md characteristic of each nav-mark asset (art/reference/<asset>/dims.md) and its period
	local CHAR = {
		M_Hbr_NavMark_North = { "Q W", 1 },
		M_Hbr_NavMark_East = { "Q(3) W 10s", 10 },
		M_Hbr_NavMark_South = { "Q(6)+LFl W 15s", 15 },
		M_Hbr_NavMark_West = { "Q(9) W 15s", 15 },
		M_Hbr_NavMark_IsolatedDanger = { "Fl(2) W 5s", 5 },
	}

	t.test("every mark is a unique, uploaded HP2b asset with its own dims.md light", function()
		local seen = {}
		local used = {}
		for _, m in R.Marks do
			t.expect(seen[m.id]).toBeNil()
			seen[m.id] = true
			t.expect(AssetIds.Models[m.asset] ~= nil).toBe(true)
			used[m.asset] = true
			local c = CHAR[m.asset]
			if c then
				t.expect(m.light).toBe(c[1])
				t.expect(R.period(R.Lights[m.light].seq)).toBeCloseTo(c[2], 1e-6)
			else
				t.expect(m.light).toBeNil() -- moorings and pick-ups are unlit
			end
		end
		for asset in CHAR do
			t.expect(used[asset]).toBe(true) -- every listed nav-mark type is in the world
		end
	end)

	t.test("flash rhythms: Fl, Fl(2), Q(3) and the south cardinal's long flash", function()
		local fl = R.Lights["Fl R 4s"].seq
		t.expect(R.isOn(fl, 0.2)).toBe(true)
		t.expect(R.isOn(fl, 1)).toBe(false)
		t.expect(R.isOn(fl, 4.1)).toBe(true) -- loops
		local fl2 = R.Lights["Fl(2) R 10s"].seq
		t.expect(R.isOn(fl2, 0.25)).toBe(true)
		t.expect(R.isOn(fl2, 1)).toBe(false)
		t.expect(R.isOn(fl2, 1.7)).toBe(true)
		t.expect(R.isOn(fl2, 5)).toBe(false)
		local q3 = R.Lights["Q(3) W 10s"].seq
		local flashes = 0
		local was = false
		for i = 0, 999 do
			local on = R.isOn(q3, i / 100)
			if on and not was then
				flashes += 1
			end
			was = on
		end
		t.expect(flashes).toBe(3)
		local s = R.Lights["Q(6)+LFl W 15s"].seq
		t.expect(R.isOn(s, 6.5)).toBe(true) -- the 2 s long flash after six quick ones
		t.expect(R.isOn(s, 7.9)).toBe(true)
		t.expect(R.isOn(s, 8.1)).toBe(false)
		t.expect(R.phase("GullStone")).toBe(R.phase("GullStone"))
		t.expect(R.phase("GullStone") >= 0 and R.phase("GullStone") < 1).toBe(true)
	end)

	t.test("cardinals lie on their named side of the danger they mark", function()
		local reefs = {}
		for _, r in WorldConfig.Reefs do
			reefs[r.id] = r.center
		end
		local skN = reefs.SkerriesReefN
		t.expect(mark("SkerriesNorth").z < skN.Z).toBe(true) -- north is -Z
		t.expect(mark("SkerriesWest").x < skN.X).toBe(true)
		t.expect(mark("SkerriesEast").x > skN.X).toBe(true)
		local wreck
		for _, p in WorldConfig.POIs do
			if p.id == "Morwenna" then
				wreck = p.position
			end
		end
		t.expect(mark("MorwennaSouth").z > wreck.Z).toBe(true)
		t.expect(mark("MorwennaWest").x < wreck.X).toBe(true)
		local e = reefs.SkerriesReefE
		local gull = mark("GullStone")
		t.expect(math.sqrt((gull.x - e.X) ^ 2 + (gull.z - e.Z) ^ 2) < 120).toBe(true)
	end)

	t.test("every buoy floats in water deep enough for its tail (terrain bake)", function()
		local fs = t.lune("fs")
		local meta = t.lune("serde")
			.decode("json", fs.readFile(`{t.gameDir}/map/generated/terrain.json`))
		-- the main grid or the island window holding (x, z)
		local function terrainY(x: number, z: number): number
			for _, g in { meta, table.unpack(meta.windows) } do
				local ix = math.floor((x - g.originX) / meta.cell + 0.5)
				local iz = math.floor((z - g.originZ) / meta.cell + 0.5)
				if ix >= 0 and ix < g.nx and iz >= 0 and iz < g.nz then
					local raw = fs.readFile(`{t.gameDir}/map/generated/{g.height}`)
					return string.unpack("<i2", raw, (iz * g.nx + ix) * 2 + 1) / meta.heightScale
				end
			end
			return meta.stats.minY -- deep sea, no voxels
		end
		for _, m in R.Marks do
			local need = if CHAR[m.asset] then -7 else -6 -- pillar tail 2.05 m, ball riser 1.85 m (dims.md)
			local y = terrainY(m.x, m.z)
			if y > need then
				error(`{m.id} at ({m.x}, {m.z}) is over terrain Y {y}`)
			end
		end
	end)

	t.test(
		"photocell: lit at night, dusk and in a storm; dark on a clear or overcast day",
		function()
			t.expect(R.lightsOn("Calm", "Clear", 0.6)).toBe(false)
			t.expect(R.lightsOn("Calm", "Overcast", 0.3)).toBe(false)
			t.expect(R.lightsOn("Calm", "Clear", -0.2)).toBe(true)
			t.expect(R.lightsOn("Calm", "Clear", 0.03)).toBe(true)
			t.expect(R.lightsOn("Calm", "Night", 0.5)).toBe(true)
			t.expect(R.lightsOn("Storm", "Clear", 0.8)).toBe(true)
		end
	)

	t.test("buoys lean with the wave slope, clamped by hull class", function()
		local pillar, ball = R.motion("M_Hbr_NavMark_Port"), R.motion("M_Hbr_MooringBuoy")
		t.expect(pillar.lag > ball.lag).toBe(true)
		local p, r = R.tiltFrom(0, 0, 1, 20)
		t.expect(p).toBe(0)
		t.expect(r).toBe(0)
		p, r = R.tiltFrom(-0.1, 0.1, 1, 20)
		t.expect(p).toBeCloseTo(math.asin(0.1), 1e-9) -- top toward +Z where the surface faces +Z
		t.expect(r).toBeCloseTo(math.asin(0.1), 1e-9) -- normal toward -X: roll positive (top to -X)
		p = R.tiltFrom(0, 0.9, pillar.follow, pillar.maxTilt)
		t.expect(p).toBeCloseTo(math.rad(pillar.maxTilt), 1e-9)
	end)

	t.test(
		"wreck and anchor data: S1a frame clones, burial depths, the 12 x 10 anchor footprint",
		function()
			t.expect(#Ribs.rows).toBe(28)
			local masters = 0
			for _, r in Ribs.rows do
				if r.master then
					masters += 1
				end
			end
			t.expect(masters).toBe(6)
			t.expect(Ribs.terrainAboveBase).toBeCloseTo(5.214, 1e-6)
			local anchor, wreck
			for _, p in WorldConfig.POIs do
				if p.id == "AdmiraltyAnchor" then
					anchor = p
				elseif p.id == "Morwenna" then
					wreck = p
				end
			end
			t.expect(anchor.length).toBe(12)
			t.expect(anchor.beam).toBe(10)
			-- the anchor's ring and crown (AssetIds.Attachments) run along its local Z: the POI length axis
			local a = AssetIds.Attachments.M_Sea_AdmiraltyAnchor
			t.expect(math.abs(a.ATT_AnchorCrown.Z - a.ATT_Anchor.Z)).toBeCloseTo(10.86, 0.05)
			-- the Morwenna's stem is within the 84-stud discovery footprint (half 42 along local Z)
			t.expect(
				math.abs(AssetIds.Attachments.M_Sea_Morwenna.ATT_Stem.Z) < wreck.length / 2 + 2
			)
				.toBe(true)
		end
	)
end
