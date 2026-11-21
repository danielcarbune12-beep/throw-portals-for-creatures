-- Runs the REAL WorldBuilder + BaseBuilder under Lune with a recording Terrain mock and exports
-- every part + terrain fill to JSON for tests/render_map.py. Engine-free: no physics, lighting or
-- materials; Terrain fills are recorded as boxes/balls (Air carves are listed separately).
-- Usage (repo root): lune run tests/lune/export_map
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local serde = require("@lune/serde")
local H = require("./harness")

local game = roblox.Instance.new("DataModel")
local ws = game:GetService("Workspace")

local fills, colors = {}, {}
local function mat(m) return tostring(m):match("%.(%w+)$") or tostring(m) end
local TERRAIN = {
	FillBlock = function(_, cf, size, m)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		table.insert(fills, { kind = "block", cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { size.X, size.Y, size.Z }, mat = mat(m) })
	end,
	FillCylinder = function(_, cf, h, r, m)
		local x, y, z = cf.Position.X, cf.Position.Y, cf.Position.Z
		table.insert(fills, { kind = "cyl", c = { x, y, z }, h = h, r = r, mat = mat(m) })
	end,
	FillBall = function(_, c, r, m) table.insert(fills, { kind = "ball", c = { c.X, c.Y, c.Z }, r = r, mat = mat(m) }) end,
	SetMaterialColor = function(_, m, col) colors[mat(m)] = { col.R, col.G, col.B } end,
}
setmetatable(TERRAIN, { __newindex = function() end })

local tags = {}
local COLLECTION = { AddTag = function(_, inst, t) tags[inst] = t end }
local RS = { Shared = { Config = { __path = H.SHARED .. "/Config" } } }

local SERVER = "src/ServerScriptService/Server"
local cache = {}
local function load(name)
	if cache[name] then return cache[name] end
	local src = fs.readFile(SERVER .. "/" .. name .. ".lua")
	src = src:gsub("workspace%.Terrain", "TERRAIN")
	src = src:gsub('game:GetService%("CollectionService"%)', "COLLECTION")
	src = src:gsub('game:GetService%("ReplicatedStorage"%)', "RS")
	local env = {
		TERRAIN = TERRAIN, COLLECTION = COLLECTION, RS = RS, workspace = ws, game = game, task = task,
		Instance = roblox.Instance, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame, Color3 = roblox.Color3,
		Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim, NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint, ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Random = H.Random, typeof = typeof, warn = function(...) print("WARN", ...) end,
		script = { Parent = setmetatable({}, { __index = function(_, k) return { __server = k } end }) },
		require = function(t)
			if type(t) == "table" and t.__server then return load(t.__server) end
			return H.require(t)
		end,
	}
	setmetatable(env, { __index = _G })
	cache[name] = luau.load(src, { debugName = name, environment = env })()
	return cache[name]
end

local Base = load("BaseBuilder")
local World = load("WorldBuilder")
local okB, eB = pcall(Base.BuildAll)
print("BaseBuilder.BuildAll", okB, eB)
local okW, eW = pcall(World.BuildAll)
print("WorldBuilder.BuildAll", okW, eW)

local parts = {}
for _, d in ipairs(ws:GetDescendants()) do
	if d:IsA("BasePart") and d.Transparency < 0.97 then
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = d.CFrame:GetComponents()
		local m = d:FindFirstChildOfClass("SpecialMesh")
		local size = d.Size
		if m and m.MeshType == roblox.Enum.MeshType.Sphere then size = size * m.Scale end
		local shape = "Block"
		if d.ClassName == "WedgePart" then shape = "Wedge"
		elseif d.ClassName == "CornerWedgePart" then shape = "Corner"
		elseif m and m.MeshType == roblox.Enum.MeshType.Sphere then shape = "Ball"
		elseif d:IsA("Part") then shape = d.Shape.Name end
		table.insert(parts, {
			cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 }, size = { size.X, size.Y, size.Z }, shape = shape,
			color = { d.Color.R, d.Color.G, d.Color.B }, tr = d.Transparency, neon = d.Material == roblox.Enum.Material.Neon,
			collide = d.CanCollide, query = d.CanQuery,
		})
	end
end
-- landing-corridor audit: any part that could intrude above the corridor floor
local intrude = 0
for _, p in ipairs(parts) do
	local x, y, z = p.cf[1], p.cf[2], p.cf[3]
	if z > 8 and z < 3200 and math.abs(x) < 36 and y - p.size[2] / 2 > 0.5 and y < 60 then intrude += 1 end
end
print("parts", #parts, "terrain fills", #fills, "corridor intrusions (center |x|<36, low, solid)", intrude)
fs.writeFile("tests/lune/tmp/map.json", serde.encode("json", { parts = parts, fills = fills, colors = colors }))
