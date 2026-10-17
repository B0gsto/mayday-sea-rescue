-- Lune: make_work_place.luau <in.rbxl> <out.rbxl> <generatedDir>
-- Copies a built place and stages the terrain bake (map/generated/*) in it as base64 StringValues under
-- ServerStorage.__WorldTerrain, so the Studio writer (tools/world/write_terrain.luau) can read it without
-- pushing megabytes through execute_luau.
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inPath, outPath, genDir = process.args[1], process.args[2], process.args[3]
assert(inPath and outPath and genDir, "usage: make_work_place.luau <in.rbxl> <out.rbxl> <generatedDir>")

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local CHUNK = 190000 -- base64 chars per StringValue (multiple of 4)

local function base64(raw: string): string
	local n = #raw
	local out = buffer.create(math.ceil(n / 3) * 4)
	local o = 0
	for i = 1, n, 3 do
		local a, b, c = string.byte(raw, i, i + 2)
		local v = a * 65536 + (b or 0) * 256 + (c or 0)
		buffer.writeu8(out, o, string.byte(ALPHABET, bit32.rshift(v, 18) + 1))
		buffer.writeu8(out, o + 1, string.byte(ALPHABET, bit32.band(bit32.rshift(v, 12), 63) + 1))
		buffer.writeu8(out, o + 2, if b then string.byte(ALPHABET, bit32.band(bit32.rshift(v, 6), 63) + 1) else 61)
		buffer.writeu8(out, o + 3, if c then string.byte(ALPHABET, bit32.band(v, 63) + 1) else 61)
		o += 4
	end
	return buffer.tostring(out)
end

local game = roblox.deserializePlace(fs.readFile(inPath))
local meta = serde.decode("json", fs.readFile(genDir .. "/terrain.json"))
local ss = game:GetService("ServerStorage")
local old = ss:FindFirstChild("__WorldTerrain")
if old then
	old.Parent = nil
end
local folder = roblox.Instance.new("Folder")
folder.Name = "__WorldTerrain"
for _, key in { "nx", "nz", "originX", "originZ", "cell", "heightScale", "shellLand", "shellSea" } do
	folder:SetAttribute(key, meta[key])
end
folder:SetAttribute("materials", table.concat(meta.materials, ","))
for _, entry in { { "H", meta.height }, { "M", meta.material } } do
	local raw = fs.readFile(genDir .. "/" .. entry[2])
	local b64 = base64(raw)
	local count = 0
	for i = 1, #b64, CHUNK do
		count += 1
		local sv = roblox.Instance.new("StringValue")
		sv.Name = entry[1] .. count
		sv.Value = string.sub(b64, i, i + CHUNK - 1)
		sv.Parent = folder
	end
	folder:SetAttribute(entry[1] .. "Count", count)
	folder:SetAttribute(entry[1] .. "Bytes", #raw)
end
folder.Parent = ss
fs.writeFile(outPath, roblox.serializePlace(game))
print(`staged terrain {meta.nx}x{meta.nz} into {outPath}`)
