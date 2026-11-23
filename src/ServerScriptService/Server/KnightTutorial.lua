-- Saved, skippable guide. Location checks cannot award anything or bypass progression.
local Rules = require(game.ReplicatedStorage.Shared.ForgeRules)
local Config = require(game.ReplicatedStorage.Shared.Config)
local Tutorial = {}
function Tutorial.Ensure(data)
	if type(data.TutorialStep) ~= "number" or data.TutorialStep < 1 then
		data.TutorialStep = (#data.Creatures > 0 or (data.Throws or 0) > 0) and 5 or 1
	end
	data.TutorialStep = math.clamp(math.floor(data.TutorialStep), 1, 5)
	return data.TutorialStep
end
function Tutorial.Act(player, data, st, arg)
	local step = Tutorial.Ensure(data)
	if arg == "Skip" then
		data.TutorialStep = 5
		return true
	end
	if arg == "Restart" then
		data.TutorialStep = 1
		return true
	end
	if arg ~= "Advance:" .. step or step >= 5 then
		return false, "Guide step changed."
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false, "Waiting for your character."
	end
	local ready = (step == 1 and Config.InThrowZone(root.Position))
		or (step == 2 and #data.Creatures > 0)
		or (step == 3 and st.base and (root.Position - st.base.collect.Position).Magnitude <= 13)
		or (step == 4 and (root.Position - Rules.Door).Magnitude <= 18)
	if not ready then
		return false, "Follow the brass arrows."
	end
	data.TutorialStep = step + 1
	return true
end
return Tutorial
