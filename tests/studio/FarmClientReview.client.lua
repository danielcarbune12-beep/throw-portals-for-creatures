-- Run after FarmLoopReview.server.lua in an isolated Studio session.
assert(game:GetService("RunService"):IsStudio() and workspace:GetAttribute("SanctuaryTest"))
local p = game.Players.LocalPlayer
local H = require(p.PlayerScripts.Client.HUD)
local State = require(p.PlayerScripts.Client.ClientState)
State.Request("Sync")
task.wait(0.3)
local passed, failures = 0, {}
local function check(value, name)
	if value then
		passed += 1
	else
		table.insert(failures, name)
	end
end
check(State.Loaded, "native state loaded")
local ok = State.Request("EquipBest")
task.wait(0.3)
check(ok and #State.Data.Placed == 4 and not table.find(State.Data.Placed, 3), "Place best includes level bonuses")
H.Open("Creatures")
task.wait(0.3)
local foreign, stand = 0, 0
for _, v in workspace.Bases:GetDescendants() do
	if v:IsA("ProximityPrompt") and v:GetAttribute("FarmPrompt") and v.Enabled then
		if v:GetAttribute("BaseIndex") ~= p:GetAttribute("BaseIndex") then
			foreign += 1
		end
		if v:GetAttribute("FarmStation") == "Stand" then
			stand += 1
		end
	end
end
check(foreign == 0, "foreign courtyard controls stay hidden")
check(stand == 1, "stand offers one action at a time")
local panel = H.Panels.Creatures
local grid = panel.content.Catalogue.Creatures
local tile = grid:FindFirstChild("Creature_1")
check(tile ~= nil and tile.PetRarity.Text:find("Lv 10", 1, true), "inventory card shows pet level")
if panel.compact then
	check(grid.AbsoluteSize.Y >= tile.AbsoluteSize.Y, "compact catalogue fits a complete first-row tile")
	local center = tile.AbsolutePosition.Y + tile.AbsoluteSize.Y / 2
	check(
		center >= grid.AbsolutePosition.Y and center <= grid.AbsolutePosition.Y + grid.AbsoluteSize.Y,
		"pet tile click target is inside the visible scroll area"
	)
	check(panel.frame.OpenCollection.Position.Y.Offset < 40, "secondary collection link shares compact header")
end
p:SetAttribute(
	"FarmFinalClientReview",
	game:GetService("HttpService"):JSONEncode({ passed = passed, failures = failures, compact = panel.compact })
)
print("[FarmClientReview]", p:GetAttribute("FarmFinalClientReview"))
