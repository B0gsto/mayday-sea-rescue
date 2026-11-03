--!strict
-- UpgradeStation (docs/30 section 2): the landmark at the water on every island, placeholder Parts until a concept
-- passes AD. Pure layout (tests/BoatLevels.spec): the bay sits in the berth's exit lane between the two arms, the board
-- and tower on a deck off the starboard arm, which joins the plate so the board can be reached on foot.
--   UpgradeStation.landing(island) -> CFrame   where a boat lands in that island's bay, bow to the open sea (Go back uses it)
--   UpgradeStation.parts(island) -> { StationPart }   what the server builds; `Board` and `Button` carry the UI and prompt
--   UpgradeStation.pose(t, reduced) -> y, spin, tilt   the level-up moment's lift (0..1 of the height), radians, radians
local RingLayout = require(script.Parent.Config.RingLayout)

export type StationPart = {
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
}

local UpgradeStation = {}

UpgradeStation.USE_RANGE = 160 -- studs from the button: the whole bay and the deck -- tune
UpgradeStation.LANDING_FWD = 375 -- island frame: between the sea plates, clear of the lane's narrow slot
UpgradeStation.LANDING_RIGHT = 6 -- the berth line
UpgradeStation.LANDING_OUT = UpgradeStation.LANDING_FWD - 255 -- studs straight out from the berth (fwd 255)
UpgradeStation.BOARD_SIZE = Vector3.new(44, 28, 1.5)
UpgradeStation.MOMENT = 1.8 -- s, the whole level-up (docs/30: under 3)
UpgradeStation.BLAST_AT = 0.85 -- s: the bricks fly and the boat swaps to its new self
UpgradeStation.SLAM_AT = 1.35 -- s: it hits the water

local WOOD = Color3.fromRGB(120, 84, 56)
local NAVY = Color3.fromRGB(30, 58, 110)
local WHITE = Color3.fromRGB(236, 236, 228)
local RED = Color3.fromRGB(214, 58, 48)
local GREEN = Color3.fromRGB(58, 190, 84)
local PILE = Color3.fromRGB(72, 80, 88)

local function islandOf(index: number): RingLayout.Island
	return RingLayout.Islands[math.clamp(index, 1, #RingLayout.Islands)]
end

function UpgradeStation.landing(index: number): CFrame
	local island = islandOf(index)
	-- the berth's own water height and facing, out along its line
	return island.berths.Boat * CFrame.new(0, 0, -UpgradeStation.LANDING_OUT)
end

function UpgradeStation.parts(index: number): { StationPart }
	local island = islandOf(index)
	local Y = island.center.Y
	local out: { StationPart } = {}
	local function at(right: number, fwd: number, y: number): CFrame
		local cf = island.frame * CFrame.new(right, 0, -fwd)
		return cf - Vector3.new(0, cf.Position.Y - y, 0)
	end
	local function add(
		name: string,
		size: Vector3,
		cf: CFrame,
		color: Color3,
		material: Enum.Material?
	)
		table.insert(out, {
			name = name,
			size = size,
			cframe = cf,
			color = color,
			material = material or Enum.Material.SmoothPlastic,
		})
	end
	-- the two arms: they stay out of RingLayout.EXIT_LANE and off the sea plates' lots
	add("ArmPort", Vector3.new(6, 3, 100), at(-46, 380, Y - 1.55), WOOD)
	add("ArmStarboard", Vector3.new(6, 3, 109.92), at(56, 375.02, Y - 1.55), WOOD)
	for i = 0, 3 do
		local fwd = 340 + i * 25
		local h = Y + 3
		add(`PilePort{i}`, Vector3.new(3.4, h, 3.4), at(-46, fwd, Y - 3 - h / 2 + 0.2), PILE)
		add(`PileStarboard{i}`, Vector3.new(3.4, h, 3.4), at(56, fwd, Y - 3 - h / 2 + 0.2), PILE)
	end
	-- the deck, the board facing the bay, and the tower that marks it from the far side of the lagoon
	add("Deck", Vector3.new(51, 3, 45), at(78.5, 451.5, Y - 1.6), WOOD)
	local boardAt = at(76, 468, Y + 22)
	local landing = UpgradeStation.landing(index).Position
	local facing =
		CFrame.lookAt(boardAt.Position, Vector3.new(landing.X, boardAt.Position.Y, landing.Z))
	add("Board", UpgradeStation.BOARD_SIZE, facing, NAVY)
	add("Button", Vector3.new(30, 6.9, 2), facing * CFrame.new(0, -18, -0.7), GREEN)
	for _, side in { -1, 1 } do
		add(
			`Post{if side < 0 then "L" else "R"}`,
			Vector3.new(2, 30, 2),
			facing * CFrame.new(side * 18, -9, 2),
			PILE
		)
	end
	add("TowerLow", Vector3.new(14, 22, 14), at(94, 438, Y + 10.85), WHITE)
	add("TowerMid", Vector3.new(13, 20, 13), at(94, 438, Y + 31.8), RED)
	add("TowerTop", Vector3.new(12, 20, 12), at(94, 438, Y + 51.7), WHITE)
	add("TowerCap", Vector3.new(20, 6, 20), at(94, 438, Y + 64.6), GREEN)
	return out
end

local function ease(u: number): number
	local x = math.clamp(u, 0, 1)
	return x * x * (3 - 2 * x)
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
