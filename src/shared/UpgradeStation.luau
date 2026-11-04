--!strict
-- UpgradeStation (docs/30 section 2): the landmark at the water on every island: M_Bld_UpgradeStation, scaled so the
-- biggest boat fits its bay (tests/BoatLevels.spec), on a spot clear of the lane and the sea plates (RingLayout). Pure.
--   UpgradeStation.frame(island) -> CFrame     the model's pivot (bow side, -Z, to the open sea)
--   UpgradeStation.landing(island) -> CFrame   where a boat lands in the bay, bow to the open sea (Go back uses it)
--   UpgradeStation.fromBerth(berth) -> CFrame  the same, from that island's berth CFrame
--   UpgradeStation.parts(island) -> { StationPart }     what the server always builds: `Board` and `Button` carry the
--                                              UI and prompt, the arm walks there from the plate
--   UpgradeStation.fallback(island) -> { StationPart }  placeholder Parts for when the mesh can't be loaded
--   UpgradeStation.buttonAt(island) -> Vector3   the green button: the tutorial's arrow and the Next chip point here
--   UpgradeStation.nearest(position) -> number   the island whose station is closest
--   UpgradeStation.shot(island, length) -> camera, focus   frames a boat of that length and the board on landing
--   UpgradeStation.pose(t, reduced) -> y, spin, tilt   the level-up moment's lift (0..1 of the height), radians, radians
local AssetIds = require(script.Parent.Config.AssetIds)
local RingLayout = require(script.Parent.Config.RingLayout)

export type StationPart = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
}

local UpgradeStation = {}

local ORIGIN = RingLayout.STATION_ORIGIN
local ATT = AssetIds.Attachments.M_Bld_UpgradeStation
UpgradeStation.SCALE = ORIGIN.scale
-- the bay in the model's frame, x scale: the back is closed, so a boat sits at its middle, not at ATT_BoatLanding
UpgradeStation.BAY_WIDTH = 24 * ORIGIN.scale
UpgradeStation.BAY_LENGTH = 30 * ORIGIN.scale
UpgradeStation.BAY_MIDDLE_Z = 7 * ORIGIN.scale
UpgradeStation.WATER_BELOW = 1.5 * ORIGIN.scale -- the sea sits this far under the model's origin
UpgradeStation.CLEAR_HEIGHT = 13.15 * ORIGIN.scale -- above the water under the gate, across the whole bay
UpgradeStation.GATE_BACK_Z = 1 * ORIGIN.scale -- nothing overhead behind this, up to the board
UpgradeStation.SCREEN_SIZE = Vector2.new(14.82, 9.36) * ORIGIN.scale
UpgradeStation.USE_RANGE = 120 -- studs from the button: the whole bay and the quays -- tune
UpgradeStation.BERTH_RIGHT = 6 -- the berth line
UpgradeStation.LANDING_FWD = ORIGIN.fwd - UpgradeStation.BAY_MIDDLE_Z -- island frame
UpgradeStation.LANDING_RIGHT = ORIGIN.right
UpgradeStation.LANDING_OUT = UpgradeStation.LANDING_FWD - 255 -- studs out from the berth (fwd 255)
UpgradeStation.LANDING_SIDE = UpgradeStation.LANDING_RIGHT - UpgradeStation.BERTH_RIGHT -- and to starboard of its line
UpgradeStation.MOMENT = 1.8 -- s, the whole level-up (docs/30: under 3)
UpgradeStation.BLAST_AT = 0.85 -- s: the bricks fly and the boat swaps to its new self
UpgradeStation.SLAM_AT = 1.35 -- s: it hits the water

local WOOD = Color3.fromRGB(120, 84, 56)
local NAVY = Color3.fromRGB(30, 58, 110)
local WHITE = Color3.fromRGB(236, 236, 228)
local GREEN = Color3.fromRGB(58, 190, 84)
local PILE = Color3.fromRGB(72, 80, 88)
local STONE = Color3.fromRGB(150, 150, 146)

local function islandOf(index: number): RingLayout.Island
	return RingLayout.Islands[math.clamp(index, 1, #RingLayout.Islands)]
end

function UpgradeStation.fromBerth(berth: CFrame): CFrame
	return berth * CFrame.new(UpgradeStation.LANDING_SIDE, 0, -UpgradeStation.LANDING_OUT)
end

function UpgradeStation.landing(index: number): CFrame
	-- the berth's own water height and facing
	return UpgradeStation.fromBerth(islandOf(index).berths.Boat)
end

function UpgradeStation.frame(index: number): CFrame
	local island = islandOf(index)
	local cf = island.frame * CFrame.new(ORIGIN.right, 0, -ORIGIN.fwd)
	local y = UpgradeStation.landing(index).Position.Y + UpgradeStation.WATER_BELOW
	return cf - Vector3.new(0, cf.Position.Y - y, 0)
end

-- The screen's middle in the world, and the way it faces (the open sea).
local function screen(index: number): CFrame
	return UpgradeStation.frame(index) * CFrame.new(ATT.ATT_BoardScreen * ORIGIN.scale)
end

function UpgradeStation.parts(index: number): { StationPart }
	local island = islandOf(index)
	local Y = island.center.Y
	local out: { StationPart } = {}
	local function at(right: number, fwd: number, y: number): CFrame
		local cf = island.frame * CFrame.new(right, 0, -fwd)
		return cf - Vector3.new(0, cf.Position.Y - y, 0)
	end
	local function add(name: string, size: Vector3, cf: CFrame, color: Color3)
		table.insert(out, {
			name = name,
			size = size,
			cframe = cf,
			color = color,
			material = Enum.Material.SmoothPlastic,
		})
	end
	-- the arm, plate to quay: it stays out of RingLayout.EXIT_LANE and off SeaPlate2's lot
	add("ArmStarboard", Vector3.new(6, 3, 129), at(56, 384.5, Y - 1.55), WOOD)
	for i = 0, 4 do
		local h = Y + 3
		add(
			`PileStarboard{i}`,
			Vector3.new(3.4, h, 3.4),
			at(56, 340 + i * 25, Y - 3 - h / 2 + 0.2),
			PILE
		)
	end
	-- 0.06 off the mesh's blank screen; the Button box wraps the mesh's button, so its colour shows who can pay
	local BOARD_DEPTH = 0.2
	add(
		"Board",
		Vector3.new(UpgradeStation.SCREEN_SIZE.X, UpgradeStation.SCREEN_SIZE.Y, BOARD_DEPTH),
		screen(index) * CFrame.new(0, 0, -0.06 - BOARD_DEPTH / 2),
		NAVY
	)
	add(
		"Button",
		Vector3.new(11.9, 2.2, 2.09) * ORIGIN.scale + Vector3.new(0.1, 0.1, 0.1),
		UpgradeStation.frame(index) * CFrame.new(Vector3.new(0, 5.19, 23.255) * ORIGIN.scale),
		GREEN
	)
	return out
end

function UpgradeStation.fallback(index: number): { StationPart }
	local frame = UpgradeStation.frame(index)
	local s = ORIGIN.scale
	local function box(
		name: string,
		x0: number,
		x1: number,
		y0: number,
		y1: number,
		z0: number,
		z1: number,
		color: Color3
	): StationPart
		return {
			name = name,
			size = Vector3.new(x1 - x0, y1 - y0, z1 - z0) * s,
			cframe = frame * CFrame.new(Vector3.new(x0 + x1, y0 + y1, z0 + z1) * s / 2),
			color = color,
			material = Enum.Material.SmoothPlastic,
		}
	end
	return {
		box("QuayPort", -32, -12, -4, 0.4, -8, 30, STONE),
		box("QuayStarboard", 12, 32, -4, 0.4, -8, 30, STONE),
		box("QuayBack", -12, 12, -4, 0.35, 22, 30, STONE),
		box("TowerPort", -21, -12, 0.4, 16, -8, 1, WHITE),
		box("TowerStarboard", 12, 21, 0.4, 16, -8, 1, WHITE),
	}
end

local function ease(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
end

function UpgradeStation.buttonAt(index: number): Vector3
	for _, part in UpgradeStation.parts(index) do
		if part.name == "Button" then
			return part.cframe.Position
		end
	end
	error("UpgradeStation: no Button")
end

-- Where someone on foot stands by the boat in the bay: the walkway beside the button (its long axis runs along it).
function UpgradeStation.standAt(index: number): Vector3
	for _, part in UpgradeStation.parts(index) do
		if part.name == "Button" then
			return (part.cframe * CFrame.new(20, 0, 0)).Position
		end
	end
	error("UpgradeStation: no Button")
end

function UpgradeStation.nearest(position: Vector3): number
	local best, bestDistance = 1, math.huge
	for index in RingLayout.Islands do
		local d = (UpgradeStation.landing(index).Position - position).Magnitude
		if d < bestDistance then
			best, bestDistance = index, d
		end
	end
	return best
end

-- The landing shot: past the bow, off to one side so a tall boat doesn't hide the screen, low enough to see under the
-- gate's beam. The focus sits between the boat and the board, so both stay in frame (tests/BoatLevels.spec).
function UpgradeStation.shot(index: number, length: number): (Vector3, Vector3)
	local landing = UpgradeStation.landing(index)
	local water = landing.Position.Y
	local board = screen(index).Position
	local camera = landing * CFrame.new(length * 0.3 + 6, 0, -(length * 0.5 + 30))
	local focus = landing.Position:Lerp(board, 0.6)
	return Vector3.new(camera.Position.X, water + 14 + length * 0.12, camera.Position.Z),
		Vector3.new(focus.X, water + 19, focus.Z)
end

-- Up, a full spin at the top, then down fast and one small dip on the slam.
function UpgradeStation.pose(t: number, reduced: boolean?): (number, number, number)
	local lift
	if t < 0.55 then
		lift = ease(t / 0.55)
	elseif t < 1.1 then
		lift = 1
	elseif t < UpgradeStation.SLAM_AT then
		local u = (t - 1.1) / (UpgradeStation.SLAM_AT - 1.1)
		lift = 1 - u * u
	elseif t < UpgradeStation.MOMENT then
		lift = -0.08
			* math.sin(
				math.pi
					* (t - UpgradeStation.SLAM_AT)
					/ (UpgradeStation.MOMENT - UpgradeStation.SLAM_AT)
			)
	else
		lift = 0
	end
	if reduced then
		return math.max(lift, 0) * 0.25, 0, 0
	end
	local spin = 2 * math.pi * ease((t - 0.25) / 0.85)
	local tilt = math.rad(12) * math.sin(math.pi * math.clamp(t / UpgradeStation.SLAM_AT, 0, 1))
	return lift, if t >= UpgradeStation.SLAM_AT then 0 else spin, tilt
end

return UpgradeStation
