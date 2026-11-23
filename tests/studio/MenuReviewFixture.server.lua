assert(
	game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"),
	"Enable isolated profiles before starting Studio Play"
)
local DS = require(game.ServerScriptService.Server.DataService)
local p = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local d
repeat
	task.wait(0.1)
	d = DS.Get(p)
until d
local CD = require(game.ReplicatedStorage.Shared.CreatureData)
local ids = { "Mossbun", "PrismLion", "Thornhog", "VoidCrystalHydra", "Infinity", "MagmaKraken", "Acornip", "Petalfly" }
d.Creatures = {}
d.Discovered = {}
for i, id in ids do
	if CD.ById[id] then
		table.insert(
			d.Creatures,
			{ u = i, c = id, l = 2 + i * 2, e = i * 6, s = i == 2 and "Big" or nil, v = i == 4 and "Gold" or nil }
		)
		d.Discovered[id] = true
	end
end
d.Placed = { 1, 2, 3, 4 }
d.EquippedPets = { 3 }
d.Money = 45000
d.NextUid = 100
d.UnlockedWorlds = { Forest = true, Volcano = true, Frozen = true }
d.OwnedPortals = { Basic = true, Forest = true, Lava = true }
