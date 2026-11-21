-- Lune harness: loads the game's ModuleScripts from src/ outside Roblox so shared logic
-- (builder, anatomy, animator, odds, timeline) can be exercised offline.
-- Run from the repo root:  lune run tests/lune/roster
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local H = {}

-- minimal Random polyfill (Lune has no Roblox Random datatype)
local Random = {}
Random.__index = Random
function Random.new(seed)
	local self = setmetatable({ s = (seed or os.clock() * 1e6) % 2147483647 }, Random)
	if self.s <= 0 then self.s = 1 end
	return self
end
function Random:_next()
	self.s = (self.s * 16807) % 2147483647
	return self.s / 2147483647
end
function Random:NextNumber(a, b)
	local r = self:_next()
	if a == nil then return r end
	return a + (b - a) * r
end
function Random:NextInteger(a, b)
	return math.floor(a + (b - a + 1) * self:_next())
end

local cache = {}
local fakeScripts = {}

-- fake `script` objects: script.Parent.<Name> resolves to sibling module paths
local function fakeScript(dir, name)
	local key = dir .. "/" .. name
	if fakeScripts[key] then return fakeScripts[key] end
	local parent = setmetatable({}, {
		__index = function(_, child)
			if child == "Parent" then return nil end
			return { __path = dir .. "/" .. child, Name = child }
		end,
	})
	local s = { Name = name, Parent = parent, __path = key }
	fakeScripts[key] = s
	return s
end

local env
local function requireModule(target)
	local path = type(target) == "table" and target.__path or target
	if cache[path] then return cache[path] end
	local file = path .. ".lua"
	local src = fs.readFile(file)
	local dir, name = path:match("^(.*)/([^/]+)$")
	local e = { script = fakeScript(dir, name) }
	for k, v in pairs(env) do e[k] = v end
	local fn = luau.load(src, { debugName = file, environment = e })
	local result = fn()
	cache[path] = result
	return result
end

env = setmetatable({
	require = requireModule,
	Instance = roblox.Instance, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame,
	Color3 = roblox.Color3, Enum = roblox.Enum, UDim2 = roblox.UDim2, UDim = roblox.UDim,
	NumberRange = roblox.NumberRange, NumberSequence = roblox.NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	Random = Random, task = task, typeof = typeof,
}, { __index = _G })

H.require = requireModule
H.Random = Random
H.roblox = roblox
H.SHARED = "src/ReplicatedStorage/Shared"

local passed, failed = 0, 0
function H.check(cond, msg)
	if cond then passed += 1 else failed += 1; print("FAIL: " .. msg) end
end
function H.summary()
	print(string.format("\n%d checks passed, %d failed", passed, failed))
	return failed
end

return H
