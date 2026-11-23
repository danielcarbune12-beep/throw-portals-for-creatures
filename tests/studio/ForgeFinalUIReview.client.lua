if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
-- Manual UI checkpoints for the opt-in ForgeReview fixture. Select and confirm using actual UI input.
-- Invoke PlayerGui.ForgeFinalUIReview with Gold, Ruby, then Walk after those gameplay stages.
local p = game.Players.LocalPlayer
local C = p.PlayerScripts.Client
local S = require(C.ClientState)
local H = require(C.HUD)
local out = { passed = 0, failures = {} }
local function check(ok, message)
	if ok then
		out.passed += 1
	else
		table.insert(out.failures, message)
	end
end
check(#S.Data.Creatures == 14, "Risk review has not consumed inputs")
local b = Instance.new("BindableFunction")
b.Name = "ForgeFinalUIReview"
b.OnInvoke = function(stage)
	if stage == "Gold" then
		local output
		for _, pet in S.Data.Creatures do
			if pet.u == 100 then
				output = pet
			end
		end
		check(#S.Data.Creatures == 10, "Five normal pets produce one Gold")
		check(output and output.v == "Gold" and output.l == 9, "Gold keeps strongest input level")
		check(S.Data.LastForge.succeeded and S.Data.LastForge.count == 5, "Five-input success guaranteed")
		check(not H.StorageFull, "Full-pets warning clears")
		local count = #S.Data.Creatures
		local ok = S.Request(
			"Forge",
			game.HttpService:JSONEncode({ id = S.Data.LastForge.id, target = "Gold", uids = { 5, 6, 7, 8, 9 } })
		)
		task.wait(0.3)
		check(ok and #S.Data.Creatures == count, "Network retry consumes no additional pets")
	elseif stage == "Ruby" then
		local output
		for _, pet in S.Data.Creatures do
			if pet.u == 101 then
				output = pet
			end
		end
		check(#S.Data.Creatures == 6, "Five Gold pets produce one Ruby")
		check(output and output.v == "Ruby", "Correct Ruby output")
		for _, uid in { 2, 3 } do
			local found = false
			for _, pet in S.Data.Creatures do
				found = found or pet.u == uid
			end
			check(found, "Protected pet remains " .. uid)
		end
	elseif stage == "Walk" then
		H.Close()
		local function walk(a, target, axis, limit)
			p.Character:PivotTo(CFrame.new(a))
			task.wait(0.6)
			p.Character.Humanoid:MoveTo(target)
			local deadline = os.clock() + 8
			repeat
				task.wait(0.1)
			until os.clock() > deadline
				or (axis == "Z" and p.Character:GetPivot().Position.Z < limit)
				or (axis == "X" and p.Character:GetPivot().Position.X > limit)
			return (axis == "Z" and p.Character:GetPivot().Position.Z < limit)
				or (axis == "X" and p.Character:GetPivot().Position.X > limit)
		end
		check(walk(Vector3.new(0, 4, -190), Vector3.new(0, 2, -279), "Z", -276), "Main hall passage walkable")
		check(walk(Vector3.new(-28, 4, -236), Vector3.new(28, 2, -236), "X", 25), "Courtyard cross passage walkable")
	end
	p:SetAttribute("ForgeFinalUIResult", game.HttpService:JSONEncode(out))
	return out
end
b.Parent = p.PlayerGui
