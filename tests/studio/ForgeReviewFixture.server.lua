assert(
	game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"),
	"Isolated profiles required"
)
local DS = require(game.ServerScriptService.Server.DataService)
local fixture = Instance.new("RemoteFunction")
fixture.Name = "ForgeReviewFixture"
fixture.OnServerInvoke = function(player, action)
	local d = DS.Get(player)
	assert(d, "Profile ready")
	if action == "Full" then
		d.Creatures, d.Placed, d.EquippedPets = {}, { 1, 2, 3, 4 }, { 2 }
		d.ForgeReceipts, d.LastForge, d.NextUid = {}, {}, 100
		d.Discovered = { Mossbun = true }
		for i = 1, 14 do
			table.insert(
				d.Creatures,
				{
					u = i,
					c = "Mossbun",
					v = i >= 10 and "Gold" or nil,
					l = i <= 9 and i or 2,
					e = i,
					locked = i == 3 or nil,
				}
			)
		end
		return true
	end
	return false
end
fixture.Parent = game.ReplicatedStorage
workspace:SetAttribute("ForgeFixtureReady", true)
