-- Build retargeted mocap clips: art/source/anim/mocap/out/<Name>.json (retarget.py) -> art/out/anims/<Name>.rbxm,
-- compiled by the shared AnimKit (same KeyframeSequence builder as tools/anim/build.luau), after sanity asserts.
-- usage (repo root): lune run art/source/anim/mocap/mocap.luau [NameFilter]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local CFrame = (roblox :: any).CFrame
local kitPath = process.env.HOME .. "/RobloxProjects/tools/anim/AnimKit.luau"
local AnimKit = luau.load(fs.readFile(kitPath), {
	debugName = kitPath,
	environment = {
		require = function(m)
			return require(m)
		end,
	},
})()

local dir, outDir = "art/source/anim/mocap", "art/out/anims"
local filter = process.args[1]
fs.writeDir(outDir)

local function qcf(q)
	return CFrame.new(0, 0, 0, q[2], q[3], q[4], q[1])
end
local function angle(a, b) -- radians between two rotations
	local _, ang = a:ToObjectSpace(b):ToAxisAngle()
	return math.abs(ang)
end

-- hand-keyed clips (keyed.py -> out/keyed/<Name>.json) replace the mocap slot of the same name
local jobs, keyed = {}, {}
if fs.isDir(dir .. "/out/keyed") then
	for _, f in fs.readDir(dir .. "/out/keyed") do
		local name = string.match(f, "^(.+)%.json$")
		if name then
			keyed[name] = true
			table.insert(jobs, { name = name, path = `{dir}/out/keyed/{f}` })
		end
	end
end
for _, clip in serde.decode("json", fs.readFile(dir .. "/clips.json")).clips do
	if not keyed[clip.name] then
		table.insert(jobs, { name = clip.name, path = `{dir}/out/{clip.name}.json` })
	end
end

local count = 0
for _, clip in jobs do
	local path = clip.path
	if (filter and not string.find(clip.name, filter, 1, true)) or not fs.isFile(path) then
		if not filter then
			print(`{clip.name}: no {path} yet (run retarget.py)`)
		end
		continue
	end
	local c = serde.decode("json", fs.readFile(path))
	local n = c.name
	assert(c.length >= 0.5 and c.length <= 12, `{n}: length {c.length} s out of range`)
	assert(
		c.keys[1].t == 0 and math.abs(c.keys[#c.keys].t - c.length) < 1e-3,
		`{n}: keys must span 0..length`
	)
	local keys = {}
	for i, k in c.keys do
		assert(i == 1 or k.t > c.keys[i - 1].t, `{n} key {i}: times must increase`)
		local pose = {}
		for j, q in k.q do
			local len = math.sqrt(q[1] ^ 2 + q[2] ^ 2 + q[3] ^ 2 + q[4] ^ 2)
			assert(
				len == len and math.abs(len - 1) < 2e-3,
				`{n} key {i} {j}: quaternion not normalized ({len})`
			)
			local cf = qcf(q)
			local x, y, z = cf:ToEulerAnglesXYZ()
			assert(angle(CFrame.Angles(x, y, z), cf) < 1e-3, `{n} key {i} {j}: euler round trip`)
			pose[j] = { x = math.deg(x), y = math.deg(y), z = math.deg(z) }
		end
		if k.root then
			for _, v in k.root do
				assert(v == v and math.abs(v) < 4, `{n} key {i}: bad root offset`)
			end
			pose.Root = pose.Root or {}
			pose.Root.pos = k.root
		end
		keys[i] = { t = k.t, pose = pose }
	end
	local first, last = c.keys[1], c.keys[#c.keys]
	for j, q in first.q do
		if c.loop then
			assert(angle(qcf(q), qcf(last.q[j])) < 0.01, `{n}: loop not seamless at {j}`)
		else
			assert(
				angle(qcf(q), CFrame.new()) < 0.035 and angle(qcf(last.q[j]), CFrame.new()) < 0.035,
				`{n}: one-shot must start/end at rest ({j})`
			)
		end
	end
	if c.loop and first.root then
		for a = 1, 3 do
			assert(math.abs(first.root[a] - last.root[a]) < 0.01, `{n}: loop root not seamless`)
		end
	end
	local ks = AnimKit.build({
		name = n,
		priority = c.priority,
		loop = c.loop,
		ease = "Linear",
		dir = "In",
		keys = keys,
	})
	fs.writeFile(`{outDir}/{n}.rbxm`, roblox.serializeModel({ ks }))
	print(
		`{n}: {c.length} s, loop {c.loop}, {#keys} keys, {c.priority}, frames {c.frames[1]}-{c.frames[2]}, rise {c.rise} -> {outDir}/{n}.rbxm`
	)
	count += 1
end
print(`built {count} mocap clips`)
