-- Inject in an isolated Studio Play session only. Uses temporary in-memory profiles.
local Http = game:GetService("HttpService")
local Players = game:GetService("Players")
assert(
	game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"),
	"Isolated Studio test required"
)
local DS = require(game.ServerScriptService.Server.DataService)
local FS = require(game.ServerScriptService.Server.FarmService)
local BB = require(game.ServerScriptService.Server.BaseBuilder)
local Farm = require(game.ReplicatedStorage.Shared.FarmConfig)
local CreatureData = require(game.ReplicatedStorage.Shared.CreatureData)
local Variants = require(game.ReplicatedStorage.Shared.Variants)
local p = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local deadline = os.clock() + 20
repeat
	task.wait(0.1)
until DS.Get(p) or os.clock() > deadline
assert(DS.Get(p), "Profile did not load")
local base = BB.Bases[p:GetAttribute("BaseIndex")]
local root = p.Character:WaitForChild("HumanoidRootPart")
local passed, failures = 0, {}
local function check(ok, text)
	if ok then
		passed += 1
	else
		table.insert(failures, text)
	end
end
local function at(offset)
	root.Anchored = true
	root.CFrame = base.cf * CFrame.new(offset + Vector3.new(0, 3, 0))
	base.farm.lastAction = 0
end
local data = DS.Default()
DS.Profiles[p] = data
data.Money = 10000
data.Creatures = { { u = 1, c = "Mossbun", l = 1, e = 0 }, { u = 2, c = "Mossbun", l = 10, e = 0 } }
data.Placed = { 1, 2 }
local f = FS.Ensure(data)
f.Pantry = { ["Moonberry|"] = 20, ["Moonberry|Rainbow"] = 1 }
at(FS.Layout.trough)
FS.OnFeed(base, p)
check(
	f.Pantry["Moonberry|"] == 15 and f.Pantry["Moonberry|Rainbow"] == 1,
	"feeding preserves remaining food and rare produce"
)
check(data.Creatures[1].l == 2 and data.Creatures[1].e == 50, "feeding awards exact XP to lowest-level pet")
check(
	f.Fed == 5 and f.FedUntil > os.time() and FS.IncomeBuff(data) == 1.2,
	"feeding activates authoritative income buff"
)
FS.OnFeed(base, p)
check(f.Pantry["Moonberry|"] == 15, "rapid duplicate action is rejected")
at(FS.Layout.trough + Vector3.new(100, 0, 0))
FS.OnFeed(base, p)
check(f.Pantry["Moonberry|"] == 15, "remote feeding outside the station is rejected")
at(FS.Layout.trough)
FS.OnFeed(base, {})
check(f.Pantry["Moonberry|"] == 15, "non-owner cannot consume food")
data.Placed = { 1 }
data.ActiveExpedition = { petUid = 1 }
FS.OnFeed(base, p)
check(f.Pantry["Moonberry|"] == 15, "expedition pets cannot be fed at home")
data.ActiveExpedition = nil
data.Creatures[1].l, data.Creatures[1].e = 100, 0
at(FS.Layout.trough)
FS.OnFeed(base, p)
check(f.Pantry["Moonberry|"] == 10 and data.Creatures[1].l == 100, "max-level pets can renew Well Fed")
at(FS.Layout.trough)
local value = FS.ItemValue(data, Farm.ById.Moonberry, nil) * 10 + FS.ItemValue(data, Farm.ById.Moonberry, "Rainbow")
local money, earned = data.Money, data.TotalEarned
FS.OnSell(base, p)
check(
	next(f.Pantry) == nil and data.Money == money + value and data.TotalEarned == earned + value,
	"sell all pays exact Pantry value once"
)
at(FS.Layout.trough)
FS.OnSell(base, p)
check(data.Money == money + value, "empty Pantry sale cannot pay again")
check(
	base.farm.sellPrompt.HoldDuration == 1 and base.farm.sellPrompt:GetAttribute("FarmAvailable") == false,
	"sell all requires hold and hides when empty"
)

at(FS.Layout.plots[1])
money = data.Money
FS.OnPlot(base, 1, p)
check(f.Plots["1"] and data.Money == money - 20, "planting charges the correct seed cost")
local harvests = f.Harvests
at(FS.Layout.plots[1])
FS.OnPlot(base, 1, p)
check(f.Harvests == harvests, "growing crops cannot be harvested early")
check(
	base.farm.plots[1].prompt:GetAttribute("FarmAvailable") == false,
	"growing bed shows timer without an unusable action"
)
f.Plots["1"].t = os.time() - 60
f.Plots["1"].m = nil
at(FS.Layout.plots[1])
money = data.Money
FS.OnPlot(base, 1, p)
check(f.Harvests == harvests + 1 and f.Pantry["Moonberry|"] == 1, "ripe crops go to the Pantry")
check(
	f.Plots["1"] and f.Plots["1"].t >= os.time() - 1 and data.Money == money - 20,
	"harvest replants selected seed with exact cost"
)
check(f.Almanac["Moonberry|"] == true and FS.AlmanacCount(data) == 1, "harvest records one permanent discovery")
local xp = f.XP
at(FS.Layout.plots[1] + Vector3.new(100, 0, 0))
FS.OnPlot(base, 1, p)
check(f.XP == xp, "out-of-range crop action cannot change progression")

data.Bounties = { { k = "harvest", p = 3, n = 3, money = 100, xp = 10 } }
at(FS.Layout.board)
money = data.Money
FS.OnBoard(base, p)
check(data.Money == money + 100 and #data.Bounties == Farm.BountySlots, "bounty pays once and replaces completed jobs")
at(FS.Layout.board)
FS.OnBoard(base, p)
check(data.Money == money + 100, "uncompleted replacement jobs cannot pay")
at(FS.Layout.chest)
FS.OnChest(base, p)
money = data.Money
check(data.Daily.streak == 1 and data.Daily.last > 0, "daily gift starts the streak")
at(FS.Layout.chest)
FS.OnChest(base, p)
check(data.Money == money and data.Daily.streak == 1, "daily gift cannot be claimed twice")

-- Leave a useful fixture for client visual checks. No test data is saved.
f.Spirit, f.Sprinkler, f.Seed = true, 0, "Moonberry"
f.Pantry = { ["Moonberry|"] = Farm.PantryCap - 1 }
f.Plots = { ["1"] = { c = "Moonberry", t = os.time() - 180 } }
local beforeHarvests, beforeTreasury = f.Harvests, data.Uncollected
task.wait(1.3)
f.Spirit = false
check(f.Harvests == beforeHarvests + 4, "Spirit catches up four historical harvests")
local pantrySize = 0
for _, count in pairs(f.Pantry) do
	pantrySize += count
end
check(
	pantrySize == Farm.PantryCap and data.Uncollected > beforeTreasury,
	"Spirit respects Pantry capacity and sends overflow to Treasury"
)
check(f.Plots["1"] and f.Plots["2"] and f.Plots["3"], "Spirit replants harvested and empty beds")
data.Creatures[1].l, data.Creatures[1].e = 10, 40
data.Creatures[2].l = 100
for i = 3, 5 do
	table.insert(data.Creatures, { u = i, c = "Mossbun", l = i - 2, e = 0 })
end
f.Pantry = { ["Moonberry|"] = 20, ["Moonberry|Rainbow"] = 1 }
at(FS.Layout.trough)
FS.OnFeed(base, p)
check(base.farm.feedPrompt.ActionText == "Feed 5 food", "feeding action shows bounded meal size")
check(base.farm.sellPrompt.ActionText == "Sell all 16 produce", "sale action shows entire quantity")
local expectedIncome = CreatureData.Income("Mossbun") * Variants.Mult(nil, nil) * Farm.PetMult(10)
check(
	FS.PetMult(data.Creatures[1]) == Farm.PetMult(10) and expectedIncome > CreatureData.Income("Mossbun"),
	"level income multiplier remains in the farm loop"
)
local signs = 0
for _, item in base.farm.root:GetDescendants() do
	if item:GetAttribute("FarmFeedback") then
		signs += 1
		check(item:IsA("TextLabel") and item.Parent:IsA("SurfaceGui"), "feedback is mounted on a physical sign")
	end
end
check(signs == 4, "four physical stations have dedicated feedback surfaces")
root.Anchored = false
local result = { passed = passed, failures = failures, isolated = true }
workspace:SetAttribute("FarmLoopReview", Http:JSONEncode(result))
print("[FarmLoopReview]", Http:JSONEncode(result))
