--!strict
-- NpcOutfits: realistic outfits for the human NPCs, built as standard Roblox R15 characters from a
-- HumanoidDescription (docs/12 section 2.9, decision 2026-10-17). Pure data plus a deterministic
-- picker, so it runs under Lune; src/server/Npc/NpcFactory.luau turns an outfit into a rig.
--
-- Every id below is a real Roblox catalog asset, looked up with the public catalog / economy APIs
-- on 2026-10-18 (name and creator in the comment). No custom human meshes (docs/06 section 2.1a).
-- The approved custom swimmer (M_Chr_Casualty_Swimmer, Assets/CasualtyAsset) is not built here.
--
-- Fields of an outfit:
--   name        debug name of the variant
--   shirt/pants classic Shirt / Pants asset ids (HumanoidDescription.Shirt / .Pants)
--   layers      layered clothing { id, kind } where kind is an Enum.AccessoryType name
--   hair, hat, front, waist, back, face accessories (rigid accessory asset ids)
--   face        classic face decal asset id (HumanoidDescription.Face)
--   skin        hex colour for every body part; nil = picked from SKIN_TONES by the seed
--   scale       HumanoidDescription scales (height, width, depth, head, bodyType, proportion)
--   stormGear   false = never swap in the wet-weather layer (crew already wear drysuits)

export type Layer = { id: number, kind: string }
export type Scale = {
	height: number,
	width: number,
	depth: number,
	head: number,
	bodyType: number,
	proportion: number,
}
export type Outfit = {
	name: string,
	shirt: number?,
	pants: number?,
	layers: { Layer },
	hair: { number },
	hat: { number },
	front: { number },
	waist: { number },
	back: { number },
	face: number?,
	skin: string?,
	scale: Scale?,
	stormGear: boolean?,
}

local NpcOutfits = {}

-- Layered clothing kinds HumanoidDescription:SetAccessories accepts (Enum.AccessoryType names).
NpcOutfits.LAYER_KINDS = {
	TShirt = true,
	Shirt = true,
	Pants = true,
	Jacket = true,
	Sweater = true,
	Shorts = true,
	DressSkirt = true,
	LeftShoe = true,
	RightShoe = true,
}

-- Real skin tones, light to dark (05 section 8.2: age, build and skin tone vary).
NpcOutfits.SKIN_TONES = { "#F2D2B6", "#E3B48F", "#C88E66", "#9A6644", "#6B4430", "#4A2F22" }

local ID = {
	-- faces (classic decals, Roblox)
	faceMan = 86487700, -- "Man Face" (Roblox)
	faceWoman = 209994875, -- "Smiling Girl" (Roblox)
	faceSmile = 616380929, -- "The Winning Smile" (Roblox)
	-- hair (Roblox, free)
	hairFringeBlack = 7193401217, -- "Short Fringe - Black" (Roblox)
	hairFringeBrown = 9243976603, -- "Short Fringe - Brown" (Roblox)
	hairSleekBrown = 6993758617, -- "Short and Sleek - Brown" (Roblox)
	hairSleekBlonde = 9243987340, -- "Short and Sleek - Blonde" (Roblox)
	hairCurlsBrown = 9244137452, -- "Short Curls - Cool Brown" (Roblox)
	hairPonytail = 376527350, -- "Black Ponytail" (Roblox)
	hairCharmer = 376548738, -- "Brown Charmer Hair" (Roblox)
	hairBeanie = 1103003368, -- "Orange Beanie with Black Hair" (Roblox), fisherman's watch cap
	hairGreyBun = 93650855450887, -- "Light Grey Messy Bun" (exactly ablimity), Aggie
	-- crew kit (RNLI-style without RNLI marks)
	drysuitYellow = 73811047577081, -- classic shirt "Drysuit (+) Yellow" (Hugh's Dive Shop)
	drysuitOrange = 80871249248196, -- classic shirt "Drysuit (+) Orange" (Hugh's Dive Shop)
	drysuitRed = 128725802953566, -- classic shirt "Pastel Red Drysuit" (FouledAnchors)
	drysuitPants = 130251160455572, -- classic pants "Drysuit (-)" (Hugh's Dive Shop)
	crewLifejacket = 122223709873035, -- front "High-Vis Life Jacket" (Emergency Supply co.)
	inflatableVest = 75858505969915, -- front "Orange Hi-Vis Inflatable Life Jacket/Vest" (DevVinci)
	rescueHelmet = 8657543997, -- hat "Rescue Helmet" (FouledAnchors)
	-- Aggie, navy coxswain
	navyLifejacket = 134403920493764, -- front "Lifesaver Lifejacket Navy" (BCRS Supply)
	knitBlack = 9240757332, -- layered sweater "Knit Sweater - Black" (Roblox)
	blackJeans = 382537569, -- classic pants "Black Jeans" (Roblox)
	-- everyday clothes (Roblox layered, free)
	teeGray = 9112474888, -- layered t-shirt "Basic T-Shirt - Gray" (Roblox)
	teeStriped = 9119670803, -- layered t-shirt "Striped T-Shirt - Black" (Roblox)
	swimTrunks = 7192685245, -- layered shorts "Floral Swim Trunks - Blue" (Roblox)
	bermudaBlack = 9174391966, -- layered shorts "Bermuda Shorts - Black" (Roblox)
	wetsuitPants = 9120251003, -- layered pants "Wetsuit Pants - Black" (Roblox)
	cargoBrown = 6984740059, -- layered pants "Cargo Pants - Brown" (Roblox)
	sweatsGray = 7192664790, -- layered pants "Casual Sweats - Gray" (Roblox)
	hoodedGray = 8516620262, -- layered jacket "Hooded Jacket - Gray" (Roblox)
	zipHoodieTeal = 8648389231, -- layered jacket "Zip Hoodie - Teal" (Roblox)
	parkaBrown = 8648397446, -- layered jacket "Parka - Brown" (Roblox)
	denimJacket = 8516609675, -- layered jacket "Denim Jacket - Light Wash" (Roblox)
	knitBeige = 6984769289, -- layered sweater "Knit Sweater - Beige" (Roblox)
	-- fishing oilskins
	oilskinTop = 94004474935368, -- classic shirt "U | Folded Up Collar Oilskin [+]" (Bell & Co. Tailoring)
	oilskinPants = 71829632362362, -- classic pants "U | Oilskin [-]" (Bell & Co. Tailoring)
	-- casualty buoyancy
	lifejacketRed = 17281428265, -- front "Life Jacket Red" (OMBcreates)
	buoyancyRed = 74976155928165, -- front "Lifejacket [Red]" (OMBcreates), kayak buoyancy aid
	lifejacketBlack = 80099305062616, -- front "Lifejacket [Black]" (OMBcreates)
	ferryLifejacket = 114364558896578, -- front "Lifesaver Lifejacket Red" (BCRS Supply)
	-- wet weather (storms)
	raincoat = 17009234923, -- layered jacket "Raincoat" (Emotes CO.)
	rainHood = 14141635575, -- hat "Yellow Rain Hood" (DevAwesomely)
}
NpcOutfits.ID = ID

-- Wet-weather layer for Warning / Storm (anyone with stormGear ~= false).
NpcOutfits.STORM = {
	layers = { { id = ID.raincoat, kind = "Jacket" } } :: { Layer },
	hat = { ID.rainHood },
}

local MAN: Scale =
	{ height = 1.0, width = 1.0, depth = 1.0, head = 1.0, bodyType = 0.3, proportion = 0 }
local WOMAN: Scale =
	{ height = 0.95, width = 0.9, depth = 0.95, head = 0.97, bodyType = 0.3, proportion = 0.4 }
local OLDER: Scale =
	{ height = 0.94, width = 0.95, depth = 1.0, head = 1.0, bodyType = 0.25, proportion = 0.3 }

local function outfit(o: { [string]: any }): Outfit
	return {
		name = o.name,
		shirt = o.shirt,
		pants = o.pants,
		layers = o.layers or {},
		hair = o.hair or {},
		hat = o.hat or {},
		front = o.front or {},
		waist = o.waist or {},
		back = o.back or {},
		face = o.face,
		skin = o.skin,
		scale = o.scale,
		stormGear = o.stormGear,
	}
end

NpcOutfits.Roles = {
	-- Lifeboat crew: Hi-Vis yellow / red / orange drysuits or an orange lifejacket over dark kit,
	-- helmet on. Drysuits are their wet-weather gear already.
	Crew = {
		outfit({
			name = "Crew_YellowDrysuit",
			shirt = ID.drysuitYellow,
			pants = ID.drysuitPants,
			front = { ID.crewLifejacket },
			hat = { ID.rescueHelmet },
			hair = { ID.hairFringeBlack },
			face = ID.faceMan,
			scale = MAN,
			stormGear = false,
		}),
		outfit({
			name = "Crew_RedDrysuit",
			shirt = ID.drysuitRed,
			pants = ID.drysuitPants,
			front = { ID.inflatableVest },
			hat = { ID.rescueHelmet },
			hair = { ID.hairPonytail },
			face = ID.faceWoman,
			scale = WOMAN,
			stormGear = false,
		}),
		outfit({
			name = "Crew_OrangeDrysuit",
			shirt = ID.drysuitOrange,
			pants = ID.drysuitPants,
			front = { ID.crewLifejacket },
			hat = { ID.rescueHelmet },
			hair = { ID.hairSleekBrown },
			face = ID.faceSmile,
			scale = MAN,
			stormGear = false,
		}),
		outfit({
			name = "Crew_DarkKitLifejacket",
			layers = {
				{ id = ID.knitBlack, kind = "Sweater" },
				{ id = ID.wetsuitPants, kind = "Pants" },
			},
			front = { ID.inflatableVest },
			hat = { ID.rescueHelmet },
			hair = { ID.hairCurlsBrown },
			face = ID.faceMan,
			scale = MAN,
			stormGear = false,
		}),
	},
	-- Chief Agnes "Aggie" Brightwater, retired coxswain in her 60s: navy knit, navy lifejacket.
	Aggie = {
		outfit({
			name = "Aggie_NavyCoxswain",
			layers = { { id = ID.knitBlack, kind = "Sweater" } },
			pants = ID.blackJeans,
			front = { ID.navyLifejacket },
			hair = { ID.hairGreyBun },
			face = ID.faceWoman,
			skin = "#E6BE9C",
			scale = OLDER,
		}),
	},
	-- Fallback for the person in the water when the approved custom swimmer fails to load:
	-- beachgoer, kayaker, shore angler and coastal walker, each with buoyancy.
	Swimmer = {
		outfit({
			name = "Casualty_Beachgoer",
			layers = {
				{ id = ID.teeGray, kind = "TShirt" },
				{ id = ID.swimTrunks, kind = "Shorts" },
			},
			front = { ID.lifejacketRed },
			hair = { ID.hairSleekBlonde },
			face = ID.faceSmile,
			scale = MAN,
		}),
		outfit({
			name = "Casualty_Kayaker",
			layers = {
				{ id = ID.teeStriped, kind = "TShirt" },
				{ id = ID.wetsuitPants, kind = "Pants" },
			},
			front = { ID.buoyancyRed },
			hair = { ID.hairPonytail },
			face = ID.faceWoman,
			scale = WOMAN,
		}),
		outfit({
			name = "Casualty_Angler",
			shirt = ID.oilskinTop,
			pants = ID.oilskinPants,
			front = { ID.lifejacketBlack },
			hair = { ID.hairBeanie },
			face = ID.faceMan,
			scale = OLDER,
			stormGear = false,
		}),
		outfit({
			name = "Casualty_Walker",
			layers = {
				{ id = ID.hoodedGray, kind = "Jacket" },
				{ id = ID.cargoBrown, kind = "Pants" },
			},
			front = { ID.lifejacketRed },
			hair = { ID.hairCurlsBrown },
			face = ID.faceMan,
			scale = MAN,
		}),
	},
	-- Dinghy / small-boat people (drifting craft fallback, the disabled boat's POB).
	Boater = {
		outfit({
			name = "Boater_Oilskins",
			shirt = ID.oilskinTop,
			pants = ID.oilskinPants,
			front = { ID.lifejacketBlack },
			hair = { ID.hairBeanie },
			face = ID.faceMan,
			scale = OLDER,
			stormGear = false,
		}),
		outfit({
			name = "Boater_Parka",
			layers = {
				{ id = ID.parkaBrown, kind = "Jacket" },
				{ id = ID.cargoBrown, kind = "Pants" },
			},
			front = { ID.lifejacketRed },
			hair = { ID.hairFringeBrown },
			face = ID.faceSmile,
			scale = MAN,
		}),
		outfit({
			name = "Boater_Summer",
			layers = {
				{ id = ID.denimJacket, kind = "Jacket" },
				{ id = ID.bermudaBlack, kind = "Shorts" },
			},
			front = { ID.buoyancyRed },
			hair = { ID.hairCharmer },
			face = ID.faceWoman,
			scale = WOMAN,
		}),
	},
	-- Ferry passengers: ordinary travel clothes with the ferry's red lifejackets.
	Passenger = {
		outfit({
			name = "Passenger_Knit",
			layers = { { id = ID.knitBeige, kind = "Sweater" } },
			pants = ID.blackJeans,
			front = { ID.ferryLifejacket },
			hair = { ID.hairSleekBrown },
			face = ID.faceWoman,
			scale = WOMAN,
		}),
		outfit({
			name = "Passenger_Hoodie",
			layers = {
				{ id = ID.zipHoodieTeal, kind = "Jacket" },
				{ id = ID.cargoBrown, kind = "Pants" },
			},
			front = { ID.ferryLifejacket },
			hair = { ID.hairFringeBlack },
			face = ID.faceMan,
			scale = MAN,
		}),
		outfit({
			name = "Passenger_Parka",
			layers = {
				{ id = ID.parkaBrown, kind = "Jacket" },
				{ id = ID.sweatsGray, kind = "Pants" },
			},
			front = { ID.ferryLifejacket },
			hair = { ID.hairCharmer },
			face = ID.faceSmile,
			scale = OLDER,
		}),
	},
}

local function copy<T>(list: { T }): { T }
	return table.clone(list)
end

-- Deterministic: the same role, seed and storm flag always give the same outfit and skin tone.
-- Unknown roles fall back to Passenger. Returns a fresh table the caller may change.
function NpcOutfits.pick(role: string, seed: number?, storm: boolean?): Outfit
	local variants = (NpcOutfits.Roles :: any)[role] or NpcOutfits.Roles.Passenger
	local s = math.abs(math.floor(seed or 0))
	local base: Outfit = variants[s % #variants + 1]
	local o: Outfit = table.clone(base)
	o.layers = copy(base.layers)
	o.hair, o.hat, o.front = copy(base.hair), copy(base.hat), copy(base.front)
	o.waist, o.back = copy(base.waist), copy(base.back)
	if not o.skin then
		local tones = NpcOutfits.SKIN_TONES
		o.skin = tones[(s // #variants) % #tones + 1]
	end
	if storm and base.stormGear ~= false then
		-- the raincoat replaces any jacket / sweater layer; the rain hood replaces the hat
		local kept: { Layer } = {}
		for _, l in o.layers do
			if l.kind ~= "Jacket" and l.kind ~= "Sweater" then
				table.insert(kept, l)
			end
		end
		for _, l in NpcOutfits.STORM.layers do
			table.insert(kept, l)
		end
		o.layers = kept
		o.hat = copy(NpcOutfits.STORM.hat)
		o.name ..= "_Storm"
	end
	return o
end

return NpcOutfits
