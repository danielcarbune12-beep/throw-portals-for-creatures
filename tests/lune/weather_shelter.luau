local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local V, CF = H.roblox.Vector3.new, H.roblox.CFrame.new
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/FarmClient.client.lua")
local first = assert(source:find("local shelterHall, shelterFloor", 1, true))
local last = assert(source:find("local function field(", first, true))
local root = { Position = V(0, 4, -236) }
local player = { Character = {
	FindFirstChild = function()
		return root
	end,
} }
local hall, searches = nil, 0
local start = {
	FindFirstChild = function()
		return hall
	end,
}
local map = {
	FindFirstChild = function()
		return start
	end,
}
local world = { CurrentCamera = { CFrame = CF(30, 8, -220) } }
function world:FindFirstChild()
	return map
end
local actual = luau.load(
	source:sub(first, last - 1)
		.. "\nreturn { origin = weatherOrigin, sheltered = forgeSheltered, update = updateWeatherField }",
	{
		environment = setmetatable({ player = player, workspace = world, CFrame = H.roblox.CFrame }, { __index = _G }),
	}
)()
local function makeHall(cf)
	local model = { attrs = { HallStyle = "MedievalForge", TPFCGenerated = true } }
	local floor = { CFrame = cf, Size = V(44, 0.4, 70), owner = model }
	function floor:IsDescendantOf(other)
		return self.owner == other
	end
	function floor:IsA(class)
		return class == "BasePart"
	end
	function model:GetAttribute(key)
		return self.attrs[key]
	end
	function model:FindFirstChild()
		searches += 1
		return self.floor
	end
	model.floor = floor
	return model
end
H.check(actual.origin() == root.Position, "weather follows the character instead of a distant camera")
player.Character = nil
H.check(actual.origin() == world.CurrentCamera.CFrame.Position, "camera provides origin during respawn")
world.CurrentCamera = nil
H.check(actual.origin() == nil, "missing camera and character safely suspend weather")
H.check(not actual.sheltered(V(0, 4, -236)), "no generated hall means outdoor weather")
hall = makeHall(CF(0, 0.35, -236))
H.check(actual.sheltered(V(0, 4, -236)), "forge nave is sheltered")
H.check(actual.sheltered(V(20, 18, -205)), "interior near the eaves is sheltered")
H.check(not actual.sheltered(V(22, 4, -236)), "outside the side wall is not sheltered")
H.check(not actual.sheltered(V(0, 4, -200)), "outside the entrance is not sheltered")
H.check(not actual.sheltered(V(0, 0, -236)), "beneath the foundation is not sheltered")
H.check(not actual.sheltered(V(0, 34, -236)), "standing on the roof retains outdoor weather")
H.check(searches == 1, "foundation discovery is cached across weather ticks")
hall.attrs.TPFCGenerated = false
H.check(not actual.sheltered(V(0, 4, -236)), "unowned similarly named geometry is ignored")
hall = makeHall(CF(120, 10, 30) * H.roblox.CFrame.Angles(0, math.pi / 3, 0))
H.check(
	actual.sheltered(hall.floor.CFrame:PointToWorldSpace(V(20, 5, 30))),
	"moved and rotated hall uses local shelter bounds"
)
H.check(not actual.sheltered(hall.floor.CFrame:PointToWorldSpace(V(24, 5, 0))), "rotated exterior remains exposed")
local oldFloor = hall.floor
oldFloor.owner = nil
hall.floor = nil
H.check(not actual.sheltered(V(120, 14, 30)), "partially rebuilding hall does not use a stale floor")
hall.floor = makeHall(CF(120, 10, 30)).floor
hall.floor.owner = hall
H.check(actual.sheltered(V(120, 14, 30)), "foundation is reacquired when rebuilding finishes")
local clears = 0
local emitter = {
	Enabled = true,
	Clear = function()
		clears += 1
	end,
}
local f = { part = { Parent = true, CFrame = CF() }, offset = CF(0, 55, 0), emitter = emitter }
local at = V(0, 4, -236)
actual.update(f, at, false)
H.check(emitter.Enabled and f.part.CFrame.Position == at + V(0, 55, 0), "outdoor field is positioned before emission")
actual.update(f, at, true)
H.check(not emitter.Enabled and clears == 1, "entering forge disables and clears lingering particles")
actual.update(f, at, true)
H.check(clears == 1, "sheltered ticks do not clear particles repeatedly")
actual.update(f, at, false)
H.check(emitter.Enabled and clears == 1, "leaving forge restores the same field")
actual.update(f, nil, false)
H.check(not emitter.Enabled and clears == 2, "respawn without an origin clears and suspends the field")
actual.update(f, at, false)
H.check(emitter.Enabled, "weather resumes after the camera or character returns")
f.part.Parent = nil
actual.update(f, nil, true)
H.check(emitter.Enabled and clears == 2, "removed fields are ignored")
assert(H.summary() == 0, "Weather shelter regressions")
