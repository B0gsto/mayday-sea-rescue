--!strict
-- The Arches (docs/21 §2.2): B1 builds this island here (landmark, stamp post, jetty landing -> dock, paths,
-- lookout). Islands/init.luau calls place(base, island) with the WorldConfig.Islands row; terrain is baked already.
local M = {}

-- phase 2 (GitHub issue #1): bare terrain plus a "Coming soon" board until a builder dresses it
function M.place(base: Instance, island: any)
	require(script.Parent:WaitForChild("ComingSoon")).place(base, island)
end

return M
