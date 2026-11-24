local H = require("./harness")
local fs, luau = require("@lune/fs"), require("@lune/luau")
local source = fs.readFile("src/StarterPlayer/StarterPlayerScripts/Client/FarmClient.client.lua")
local first = assert(source:find("local prompts, signs =", 1, true))
local boundary = assert(source:find("local function track(inst)", first, true))
local nearest = assert(source:find("local function nearestStand(root)", boundary, true))
local finish = assert(source:find("task.spawn(function()", nearest, true))
local owner, reads, enemyReads = 1, 0, 0
local player = {
	GetAttribute = function()
		return owner
	end,
}
local code = source:sub(first, boundary - 1)
	.. source:sub(nearest, finish - 1)
	.. "\nreturn { cache = cacheStand, apply = applyPrompt, nearest = nearestStand, stands = ownedStands, setActive = function(p) activeStand = p end }"
local actual = luau.load(code, { environment = setmetatable({ player = player }, { __index = _G }) })()
local all = {}
local function prompt(base, station, x)
	local attrs = { BaseIndex = base, FarmStation = station, FarmAvailable = true }
	local p = { Parent = { WorldPosition = H.roblox.Vector3.new(x, 0, 0) }, Enabled = true }
	function p:GetAttribute(key)
		reads += 1
		if attrs.BaseIndex ~= owner then
			enemyReads += 1
		end
		return attrs[key]
	end
	all[p] = attrs
	actual.cache(p)
	return p, attrs
end
local ours = {}
for i = 1, 4 do
	ours[i] = prompt(1, "Stand", i - 1)
end
local bed = prompt(1, "Bed", 0)
for i = 1, 240 do
	prompt(2 + i % 10, i % 3 == 0 and "Bed" or "Stand", 0)
end
reads, enemyReads = 0, 0
local root = { Position = H.roblox.Vector3.zero }
H.check(actual.nearest(root) == ours[1], "nearest action belongs to the local player's stand")
H.check(reads == 4 and enemyReads == 0, "nearest search inspects four owned goods instead of 245 farm prompts")
actual.setActive(ours[1])
root.Position = H.roblox.Vector3.new(0.55, 0, 0)
H.check(actual.nearest(root) == ours[1], "small distance jitter keeps the current stand action")
root.Position = H.roblox.Vector3.new(0.8, 0, 0)
H.check(actual.nearest(root) == ours[2], "moving to another good changes the nearest action")
all[ours[2]].FarmAvailable = false
H.check(actual.nearest(root) == ours[1], "unavailable goods are not offered")
actual.setActive(ours[1])
for p in all do
	actual.apply(p)
end
local enabled = 0
for p, attrs in all do
	if attrs.FarmStation == "Stand" and p.Enabled then
		enabled += 1
	end
end
H.check(enabled == 1 and ours[1].Enabled, "only one owned stand action is enabled")
H.check(bed.Enabled, "owned crop bed interactions remain available")
H.check(actual.nearest(nil) == nil, "respawn without a character has no nearest action")
owner = 2
table.clear(actual.stands)
actual.setActive(nil)
for p in all do
	actual.cache(p)
	actual.apply(p)
end
root.Position = H.roblox.Vector3.zero
local replacement = actual.nearest(root)
H.check(replacement and all[replacement].BaseIndex == 2, "changing courtyard ownership rebuilds stand membership")
H.check(not ours[1].Enabled and not bed.Enabled, "previous courtyard prompts are disabled after reassignment")
for p in actual.stands do
	p.Parent = nil
end
H.check(actual.nearest(root) == nil, "destroyed stand attachments are ignored")
assert(H.summary() == 0, "Farm prompt budget regressions")
