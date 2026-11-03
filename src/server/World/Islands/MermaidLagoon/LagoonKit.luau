--!strict
-- Mermaid Lagoon's mesh dressing (PERF-BL12): M_Prop_LagoonKit's named modules go where
-- art/source/props/M_Prop_LagoonKit/build.py's LAYOUT says, at the code's real world coordinates (y nil = groundY raycast,
-- skipped when gy <= 0.5). The meshes are inert; the invisible Parts in SOLIDS collide. init.luau falls back to its
-- code-built props when build returns false. tests/LagoonKit.spec.luau keeps the rows, spots and doorway honest.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetIds = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("AssetIds")
)

local LagoonKit = {}

LagoonKit.ASSET = "M_Prop_LagoonKit"

-- Each module's ATT_<slot> origin in the kit strip (build.py MODULES).
LagoonKit.SLOTS = {
	L01_Statue = "Statue",
	L02_StatuePlinth = "Statue",
	L03_Jetty = "Jetty",
	L04_DayMark = "DayMark",
	L05_Telescope = "Telescope",
	L06_StampPost = "StampPost",
	L07_Cafe = "Cafe",
	L08_CafeBulbs = "Cafe",
	L09_Table = "Table",
	L10_ParasolTeal = "ParasolTeal",
	L11_ParasolCoral = "ParasolCoral",
	L12_ParasolYellow = "ParasolYellow",
	L13_VigLounge = "VigLounge",
	L14_VigTowels = "VigTowels",
	L15_VigCastle = "VigCastle",
	L16_HutCoral = "HutCoral",
	L17_HutTeal = "HutTeal",
	L18_Palm = "Palm",
	L19_PathPlate = "PathPlate",
	L20_Agapanthus = "Agapanthus",
	L21_RockArch = "RockArch",
	L22_CoralCluster = "Coral",
	L23_ColumnTall = "ColumnTall",
	L24_ColumnStump = "ColumnStump",
	L25_ColumnFallen = "ColumnFallen",
	L26_RuinBlock = "RuinBlock",
	L27_Surfboards = "Surfboards",
	L28_SandPlate = "SandPlate",
	L29_BeachRock = "BeachRock",
	L30_BeachFlag = "BeachFlag",
	L31_ShellCluster = "ShellCluster",
	L32_PalmBase = "PalmBase",
	L33_VigRed = "VigRed",
	L34_CoralClump = "CoralClump",
} :: { [string]: string }

type Row = { module: string, x: number, y: number?, z: number, yaw: number, scale: number }

local function r(module: string, x: number, y: number?, z: number, yaw: number, scale: number): Row
	return { module = module, x = x, y = y, z = z, yaw = yaw, scale = scale }
end

-- build.py's LAYOUT, row for row (its seeded palm and shell yaws are expanded here).
LagoonKit.LAYOUT = {
	r("L01_Statue", 300, 0, 5265, 340, 1),
	r("L02_StatuePlinth", 300, 0, 5265, 340, 1),
	r("L03_Jetty", 500, 0, 4810, 0, 1),
	r("L04_DayMark", 300, nil, 4950, 0, 1),
	r("L05_Telescope", 294, nil, 4958, 0, 1),
	r("L06_StampPost", 340, nil, 4990, 180, 1),
	r("L07_Cafe", 405, 16.3, 4993, 0, 1),
	r("L08_CafeBulbs", 405, 16.3, 4993, 0, 1),
	r("L09_Table", 392, 16.9, 5000, 0, 1),
	r("L10_ParasolTeal", 392, 19.6, 5000, 0, 1),
	r("L09_Table", 405, 16.9, 5010, 0, 1),
	r("L11_ParasolCoral", 405, 19.6, 5010, 0, 1),
	r("L09_Table", 418, 16.9, 5000, 0, 1),
	r("L12_ParasolYellow", 418, 19.6, 5000, 0, 1),
	r("L13_VigLounge", 385, nil, 5056, 227, 1),
	r("L14_VigTowels", 431, nil, 5056, 247, 1),
	r("L15_VigCastle", 385, nil, 5083, 225, 1),
	r("L18_Palm", 334, nil, 5054, 88, 1.354),
	r("L32_PalmBase", 334, nil, 5054, 0, 1),
	r("L18_Palm", 356, nil, 5062, 145, 1.042),
	r("L32_PalmBase", 356, nil, 5062, 0, 1),
	r("L18_Palm", 455, nil, 5042, 277, 1.25),
	r("L32_PalmBase", 455, nil, 5042, 0, 1),
	r("L18_Palm", 466, nil, 5052, 40, 0.99),
	r("L32_PalmBase", 466, nil, 5052, 0, 1),
	r("L18_Palm", 472, nil, 4978, 298, 1.458),
	r("L32_PalmBase", 472, nil, 4978, 0, 1),
	r("L18_Palm", 484, nil, 4990, 89, 1.146),
	r("L32_PalmBase", 484, nil, 4990, 0, 1),
	r("L18_Palm", 214, nil, 4992, 147, 1.302),
	r("L32_PalmBase", 214, nil, 4992, 0, 1),
	r("L18_Palm", 226, nil, 5006, 69, 1.042),
	r("L32_PalmBase", 226, nil, 5006, 0, 1),
	r("L18_Palm", 186, nil, 5040, 141, 1.146),
	r("L32_PalmBase", 186, nil, 5040, 0, 1),
	r("L18_Palm", 132, nil, 4988, 75, 0.99),
	r("L32_PalmBase", 132, nil, 4988, 0, 1),
	r("L18_Palm", 522, nil, 5002, 338, 1.146),
	r("L32_PalmBase", 522, nil, 5002, 0, 1),
	r("L18_Palm", 446, nil, 4932, 310, 1.198),
	r("L32_PalmBase", 446, nil, 4932, 0, 1),
	r("L18_Palm", 330, nil, 4926, 273, 0.781),
	r("L32_PalmBase", 330, nil, 4926, 0, 1),
	r("L18_Palm", 262, nil, 5050, 286, 0.885),
	r("L32_PalmBase", 262, nil, 5050, 0, 1),
	r("L18_Palm", 900, nil, 5480, 344, 1.354),
	r("L32_PalmBase", 900, nil, 5480, 0, 1),
	r("L18_Palm", 926, nil, 5602, 195, 1.51),
	r("L32_PalmBase", 926, nil, 5602, 0, 1),
	r("L18_Palm", 956, nil, 5528, 177, 1.198),
	r("L32_PalmBase", 956, nil, 5528, 0, 1),
	r("L18_Palm", 906, nil, 5682, 83, 1.146),
	r("L32_PalmBase", 906, nil, 5682, 0, 1),
	r("L18_Palm", -332, nil, 5560, 76, 1.354),
	r("L32_PalmBase", -332, nil, 5560, 0, 1),
	r("L18_Palm", -320, nil, 5574, 343, 1.042),
	r("L32_PalmBase", -320, nil, 5574, 0, 1),
	r("L18_Palm", -312, nil, 5684, 89, 1.198),
	r("L32_PalmBase", -312, nil, 5684, 0, 1),
	r("L18_Palm", -362, nil, 5742, 165, 1.042),
	r("L32_PalmBase", -362, nil, 5742, 0, 1),
	r("L18_Palm", 640, nil, 6162, 281, 1.198),
	r("L32_PalmBase", 640, nil, 6162, 0, 1),
	r("L18_Palm", 700, nil, 6184, 318, 1.458),
	r("L32_PalmBase", 700, nil, 6184, 0, 1),
	r("L18_Palm", 742, nil, 6160, 254, 1.042),
	r("L32_PalmBase", 742, nil, 6160, 0, 1),
	r("L18_Palm", -84, nil, 6200, 156, 1.302),
	r("L32_PalmBase", -84, nil, 6200, 0, 1),
	r("L18_Palm", -22, nil, 6214, 46, 1.146),
	r("L32_PalmBase", -22, nil, 6214, 0, 1),
	r("L18_Palm", -124, nil, 6196, 12, 0.99),
	r("L32_PalmBase", -124, nil, 6196, 0, 1),
	r("L18_Palm", 484, nil, 4922, 235, 1.771),
	r("L32_PalmBase", 484, nil, 4922, 0, 1),
	r("L18_Palm", 362, nil, 4904, 83, 1.667),
	r("L32_PalmBase", 362, nil, 4904, 0, 1),
	r("L20_Agapanthus", 364, nil, 5034, 12, 1),
	r("L20_Agapanthus", 380, nil, 5040, 140, 1),
	r("L20_Agapanthus", 440, nil, 5038, 2, 1),
	r("L20_Agapanthus", 456, nil, 5022, 294, 1),
	r("L20_Agapanthus", 458, nil, 4994, 290, 1),
	r("L20_Agapanthus", 352, nil, 4972, 252, 1),
	r("L20_Agapanthus", 330, nil, 5004, 211, 1),
	r("L20_Agapanthus", 470, nil, 4956, 260, 1),
	r("L20_Agapanthus", 488, nil, 4962, 106, 1),
	r("L20_Agapanthus", 302, nil, 4988, 66, 1),
	r("L20_Agapanthus", 912, nil, 5540, 225, 1),
	r("L20_Agapanthus", -320, nil, 5620, 3, 1),
	r("L20_Agapanthus", 680, nil, 6170, 138, 1),
	r("L23_ColumnTall", 221.8, 0, 5221.3, 0, 1),
	r("L25_ColumnFallen", 400.05, 0, 5223.6, 28, 1),
	r("L24_ColumnStump", 382.8, 0, 5304.1, 0, 1),
	r("L26_RuinBlock", 244.8, 0, 5324.8, 40, 1),
	r("L23_ColumnTall", 392, 0, 5248.9, 90, 0.8),
	r("L21_RockArch", 590, 0, 4870, 20, 1),
	r("L21_RockArch", 215, 0, 5140, -25, 0.85),
	r("L21_RockArch", 430, 0, 5245, 70, 1),
	r("L22_CoralCluster", 440, 0, 5085, 15, 1.4),
	r("L22_CoralCluster", 350, 0, 5118, 200, 1.26),
	r("L22_CoralCluster", 232, 0, 5290, 75, 1.54),
	r("L22_CoralCluster", 368, 0, 5316, 300, 1.4),
	r("L29_BeachRock", 325, nil, 5068, 30, 1.4),
	r("L29_BeachRock", 456, nil, 5064, 200, 1),
	r("L33_VigRed", 345, nil, 5082, 215, 1),
	r("L33_VigRed", 283, nil, 5062, 180, 1),
	r("L34_CoralClump", 408, nil, 5040, 20, 1),
	r("L34_CoralClump", 412, nil, 5076, 140, 1),
	r("L17_HutTeal", 352, nil, 4888, 0, 1),
	r("L28_SandPlate", 366, nil, 4886, 0, 1.4),
	r("L11_ParasolCoral", 366, nil, 4886, 0, 1.4),
	r("L30_BeachFlag", 340, nil, 4890, 0, 1.8),
	r("L16_HutCoral", 404, nil, 4905, 0, 1),
	r("L28_SandPlate", 418, nil, 4903, 0, 1.4),
	r("L10_ParasolTeal", 418, nil, 4903, 0, 1.4),
	r("L30_BeachFlag", 392, nil, 4907, 0, 1.8),
	r("L17_HutTeal", 452, nil, 4925, 0, 1),
	r("L28_SandPlate", 466, nil, 4923, 0, 1.4),
	r("L12_ParasolYellow", 466, nil, 4923, 0, 1.4),
	r("L30_BeachFlag", 440, nil, 4927, 0, 1.8),
	r("L16_HutCoral", 528, nil, 4946, 0, 1),
	r("L28_SandPlate", 542, nil, 4944, 0, 1.4),
	r("L10_ParasolTeal", 542, nil, 4944, 0, 1.4),
	r("L30_BeachFlag", 516, nil, 4948, 0, 1.8),
	r("L30_BeachFlag", 372, nil, 4952, 0, 1.8),
	r("L30_BeachFlag", 386, nil, 4952, 0, 1.8),
	r("L30_BeachFlag", 400, nil, 4952, 0, 1.8),
	r("L30_BeachFlag", 414, nil, 4952, 0, 1.8),
	r("L30_BeachFlag", 428, nil, 4952, 0, 1.8),
	r("L27_Surfboards", 470, nil, 4950, 200, 1.4),
	r("L19_PathPlate", 495, nil, 4962, 0, 1),
	r("L19_PathPlate", 477, nil, 4966, 0, 1),
	r("L19_PathPlate", 459, nil, 4970, 0, 1),
	r("L19_PathPlate", 441, nil, 4974, 0, 1),
	r("L19_PathPlate", 438, nil, 4992, 0, 1),
	r("L19_PathPlate", 438, nil, 5010, 0, 1),
	r("L19_PathPlate", 440, nil, 5028, 0, 1),
	r("L19_PathPlate", 446, nil, 5046, 0, 1),
	r("L31_ShellCluster", 262, nil, 5076, 2, 1.4),
	r("L31_ShellCluster", 318, nil, 5094, 32, 1.4),
	r("L31_ShellCluster", 240, nil, 4930, 337, 1.4),
	r("L31_ShellCluster", 300, nil, 4905, 153, 1.4),
	r("L31_ShellCluster", 470, nil, 5085, 225, 1.4),
} :: { Row }

-- One Atomic model per prop so streaming stays local, as the code-built props; these share theirs. The rest get their own.
local GROUPS: { [string]: string } = {
	L01_Statue = "MermaidStatue",
	L02_StatuePlinth = "MermaidStatue",
	L23_ColumnTall = "MermaidStatue",
	L24_ColumnStump = "MermaidStatue",
	L25_ColumnFallen = "MermaidStatue",
	L26_RuinBlock = "MermaidStatue",
	L03_Jetty = "Jetty",
	L04_DayMark = "DayMark",
	L05_Telescope = "Telescope",
	L06_StampPost = "StampPost",
	L07_Cafe = "Cafe",
	L08_CafeBulbs = "Cafe",
}

-- The jetty's solids, from island.dock at sea level (build.py jetty): deck 3.5, stair top 12.5.
local DECK, TOP, STAIR_TOP_Z = 3.5, 12.5, 136
local JETTY: { { number } } = {
	{ -4, TOP - 1.2, STAIR_TOP_Z, 4, TOP, STAIR_TOP_Z + 7 }, -- landing
	{ -4.55, DECK - 0.5, 16, 4.55, DECK, 116.8 }, -- deck, kerbs included
	{ -12, DECK - 0.5, 6, 12, DECK, 16 }, -- T-head
	{ 9.55, DECK, 14.05, 10.45, DECK + 11.5, 14.95 }, -- lamp
	{ -10.35, DECK, 14.15, -9.65, DECK + 13, 14.85 }, -- flag pole
}
for i = 1, 12 do -- stair treads
	local top = TOP - 0.75 * i
	table.insert(
		JETTY,
		{ -3, top - 0.7, STAIR_TOP_Z - 1.6 * i, 3, top, STAIR_TOP_Z - 1.6 * (i - 1) }
	)
end
for z = 114.8, 17, -12 do -- pile bents: boats still pass between them
	table.insert(JETTY, { -4.6, DECK - 1.3, z - 0.5, 4.6, DECK - 0.5, z + 0.5 })
	for _, x in { -3.9, 3.9 } do
		table.insert(JETTY, { x - 0.6, -12, z - 0.6, x + 0.6, DECK - 1.3, z + 0.6 })
	end
end
for _, x in { -11.5, -4, 4, 11.5 } do -- mooring posts
	for _, z in { 6.6, 15.4 } do
		table.insert(JETTY, { x - 0.75, -12, z - 0.75, x + 0.75, DECK + 1.6, z + 0.75 })
	end
end
for _, x in { -8, 8 } do -- bollards
	table.insert(JETTY, { x - 1.1, DECK, 6.3, x + 1.1, DECK + 1.7, 8.5 })
end

-- The café, from pad.y at z 4993 (build.py cafe): the shack grew 1.22x round its back wall, these are its grown sizes. The door
-- is in the east wall, z -23.12 to -16.29, 8.84 tall (floor 0.6); the serving hatch stays open over the counter.
local CAFE: { { number } } = {
	{ -23, -7, -29, 23, 0.6, 29 }, -- terrace and shack floor
	{ -14.2, 0.6, -28.18, 14.2, 11.58, -27.02 }, -- back wall
	{ -14.2, 0.6, -27.02, -12.44, 11.58, -10.74 }, -- west wall
	{ 12.44, 0.6, -27.02, 14.2, 11.58, -23.12 }, -- east wall, behind the door
	{ 12.44, 0.6, -16.29, 14.2, 11.58, -10.74 }, -- east wall, in front of it
	{ 12.44, 8.84, -23.12, 14.2, 11.58, -16.29 }, -- over the door
	{ -12.44, 0.6, -11.9, 12.44, 5.42, -9.33 }, -- counter
	{ -12.44, 5.42, -11.9, -10.92, 11.58, -10.74 }, -- hatch pillars
	{ 10.92, 5.42, -11.9, 12.44, 11.58, -10.74 },
	{ -10.92, 9.63, -11.9, 10.92, 11.58, -10.92 }, -- lintel
	{ -17.08, 11.3, -31.17, 17.08, 16.95, -7.75 }, -- roof
	{ -11.59, 0.6, -26.78, -7.69, 7.92, -23.61 }, -- fridge
	{ 18.15, 0.6, -10.35, 20.85, 19, -7.65 }, -- the cone's post
	{ -21.42, 0.6, 25.58, -20.58, 9.6, 26.42 }, -- light posts
	{ 20.58, 0.6, 25.58, 21.42, 9.6, 26.42 },
}

local HUT: { { number } } = { -- open to -z
	{ -5.1, 0, 3.6, 5.1, 7.6, 4.6 },
	{ -5.1, 0, -4.4, -4.1, 7.6, 3.6 },
	{ 4.1, 0, -4.4, 5.1, 7.6, 3.6 },
	{ -6.4, 7.6, -5.8, 6.4, 10.9, 6 },
}

-- Each module's solids from its origin, before the row's yaw and scale: x0, y0, z0, x1, y1, z1. Anything else is walked through.
LagoonKit.SOLIDS = {
	L01_Statue = {
		{ -27.3, 19.2, -11.7, 39, 50, 19.5 },
		{ -46.8, 50, -11.7, 54.6, 66, 19.5 },
		{ -46.8, 66, -11.7, -11.7, 85, 19.5 },
	},
	L02_StatuePlinth = {
		{ -64, -22, -32, 64, 1.6, 32 },
		{ -56, 1.6, -24, 56, 8, 24 },
		{ -48, 8, -16, 48, 19.2, 16 },
	},
	L03_Jetty = JETTY,
	L04_DayMark = {
		{ -5.2, 0, -5.2, 5.2, 2, 5.2 },
		{ -4, 2, -4, 4, 52, 4 },
		{ -2.6, 52, -2.6, 2.6, 64, 2.6 },
	},
	L05_Telescope = { { -0.6, 0, -0.6, 0.6, 4, 0.6 } },
	L06_StampPost = { { -0.8, 0, -0.8, 0.8, 7.1, 0.8 } },
	L07_Cafe = CAFE,
	L09_Table = { { -4.25, 0, -1.9, 4.25, 2.75, 1.9 } },
	L16_HutCoral = HUT,
	L17_HutTeal = HUT,
	L18_Palm = { { -2.2, 0, -2.2, 2.2, 8, 2.2 } },
	L21_RockArch = { -- boats pass between the legs, under the span
		{ -28, -12, -8, -12, 21.6, 8 },
		{ 12, -12, -8, 28, 21.6, 8 },
		{ -24, 21.6, -8, 24, 28, 8 },
		{ -20, 28, -4, 12, 35.4, 8 },
	},
	L23_ColumnTall = {
		{ -5.6, -12, -5.6, 14.2, 1, 5.6 },
		{ -3.6, 1, -3.6, 3.6, 28.2, 3.6 },
		{ -5, 28.2, -5, 5, 31.5, 5 },
		{ 7, 1, -2.75, 13, 6.45, 2.75 }, -- the fallen drum
	},
	L24_ColumnStump = {
		{ -5.4, -12, -5.4, 5.4, 0.9, 5.4 },
		{ -3.6, 0.9, -3.6, 3.6, 16.9, 3.6 },
	},
	L25_ColumnFallen = {
		{ -11, -12, -5, 11, 0.7, 5 },
		{ -8.5, 0.7, -3.2, 5.5, 6.6, 3.2 },
		{ 5.6, 0.7, -3.9, 10, 6, 3.9 },
	},
	L26_RuinBlock = {
		{ -5, -12, -4, 5, 0.8, 4 },
		{ -3.6, 0.8, -3.6, 3.6, 8.1, 3.6 },
	},
} :: { [string]: { { number } } }

local function solid(parent: Instance, size: Vector3, cf: CFrame)
	local p = Instance.new("Part")
	p.Name = "Col"
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = parent
end

-- A PointLight at `offset` from the row's origin.
local function light(
	p: BasePart,
	cf: CFrame,
	offset: Vector3,
	color: Color3,
	range: number,
	brightness: number
)
	local a = Instance.new("Attachment")
	a.CFrame = p.CFrame:ToObjectSpace(cf * CFrame.new(offset))
	a.Parent = p
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = a
end

-- The code keeps the bulbs' glow and the lamps (build.py L08, ATT_Lamp).
local function finish(p: BasePart, module: string, cf: CFrame, atts: any)
	if module == "L08_CafeBulbs" then
		local sa = p:FindFirstChildOfClass("SurfaceAppearance")
		if sa then
			sa:Destroy()
		end
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 220, 150)
		p.CastShadow = false
		for _, s in { -1, 1 } do -- each string's third bulb, as the code-built strings
			light(p, cf, Vector3.new(s * 16.67, 8.93, 5.18), Color3.fromRGB(255, 208, 140), 18, 0.9)
		end
	elseif module == "L03_Jetty" then
		light(p, cf, atts.ATT_Lamp - atts.ATT_Jetty, Color3.fromRGB(255, 214, 150), 22, 1.4)
	end
end

-- Places every row under `root`. False, with nothing placed, when the kit lacks a module: the caller builds the old props.
function LagoonKit.build(
	root: Instance,
	kit: Model,
	groundY: (x: number, z: number) -> number?,
	islandId: string
): boolean
	local atts = (AssetIds :: any).Attachments[LagoonKit.ASSET]
	for module, slot in LagoonKit.SLOTS do
		if not (atts and atts[`ATT_{slot}`] and kit:FindFirstChild(module, true)) then
			warn(`[MermaidLagoon] {LagoonKit.ASSET} has no {module}: code-built props instead`)
			return false
		end
	end
	local holders: { [string]: Model } = {}
	for _, row in LagoonKit.LAYOUT do
		local y = row.y
		if y == nil then
			local gy = groundY(row.x, row.z)
			y = if gy and gy > 0.5 then gy else nil
		end
		if y then
			local group = GROUPS[row.module]
			local m: Model = if group and holders[group]
				then holders[group]
				else Instance.new("Model")
			if not m.Parent then
				m.Name = group or row.module
				m.ModelStreamingMode = if group == "DayMark"
					then Enum.ModelStreamingMode.Persistent
					else Enum.ModelStreamingMode.Atomic
				m.Parent = root
				if group then
					holders[group] = m
				end
			end
			local src = kit:FindFirstChild(row.module, true) :: BasePart
			local origin = kit.WorldPivot * CFrame.new(atts[`ATT_{LagoonKit.SLOTS[row.module]}`])
			local rel = origin:ToObjectSpace(src.CFrame)
			local cf = CFrame.new(row.x, y, row.z) * CFrame.Angles(0, math.rad(row.yaw), 0)
			local p = src:Clone()
			p.Size = src.Size * row.scale
			p.CFrame = cf * (rel - rel.Position + rel.Position * row.scale)
			p.Anchored = true
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
			finish(p, row.module, cf, atts)
			p.Parent = m
			local solids: { { number } } = LagoonKit.SOLIDS[row.module] or {}
			for _, b in solids do
				local lo = Vector3.new(b[1], b[2], b[3]) * row.scale
				local hi = Vector3.new(b[4], b[5], b[6]) * row.scale
				solid(m, hi - lo, cf * CFrame.new((lo + hi) / 2))
			end
		end
	end
	if holders.StampPost then
		holders.StampPost:SetAttribute("Island", islandId)
	end
	holders.MermaidStatue:SetAttribute("ExploreSpot", "MermaidStatue")
	return true
end

return LagoonKit
