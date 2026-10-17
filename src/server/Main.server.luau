--!strict
-- Mayday: Sea Rescue server entry point.
--
-- HOW TO ADD SERVER CODE (no need to edit this file):
--   Drop a ModuleScript into src/server/Services/. It must return a table with:
--     Init(): ()      -- synchronous setup: read config, create state, connect remotes.
--                      -- Must not yield. Other services may not be started yet.
--     Start(): ()     -- runs after EVERY service's Init has finished. May yield or loop
--                      -- (each Start runs in its own thread via task.spawn).
--     Priority: number?  -- optional; lower runs first (default 100). Ties sort by name.
--   Services talk to each other by requiring the sibling module directly
--   (require(script.Parent.OtherService)); only call into another service after Init.
--   Remotes are all declared in src/shared/Net.luau and created by Net.init() below,
--   before any service runs, so Net.event / Net.func never yields on the server.
--   Nested folders inside Services are ignored (use them for a service's private modules).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

type Module = {
	Init: (() -> ())?,
	Start: (() -> ())?,
	Priority: number?,
}

Net.init()

local loaded: { { name: string, module: Module, priority: number } } = {}
for _, child in script.Parent:WaitForChild("Services"):GetChildren() do
	if child:IsA("ModuleScript") then
		local module = (require :: any)(child) :: Module
		assert(type(module) == "table", `Service {child.Name} must return a table`)
		table.insert(
			loaded,
			{ name = child.Name, module = module, priority = module.Priority or 100 }
		)
	end
end
table.sort(loaded, function(a, b)
	if a.priority ~= b.priority then
		return a.priority < b.priority
	end
	return a.name < b.name
end)

-- A failing module is reported with its traceback and skipped; the others still boot.
local function runPhase(phase: string, name: string, fn: () -> ())
	xpcall(fn, function(err)
		warn(`[Main] {name}.{phase} failed: {err}\n{debug.traceback()}`)
	end)
end

for _, entry in loaded do
	local init = entry.module.Init
	if init then
		runPhase("Init", entry.name, init)
	end
end

for _, entry in loaded do
	local start = entry.module.Start
	if start then
		task.spawn(runPhase, "Start", entry.name, start)
	end
end

print(`[Main] server started {#loaded} services`)
