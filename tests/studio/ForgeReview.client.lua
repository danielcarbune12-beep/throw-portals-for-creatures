if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local p = game.Players.LocalPlayer
local C = p.PlayerScripts:WaitForChild("Client")
local S, H = require(C.ClientState), require(C.HUD)
local Forge = require(C.ForgePanel)
local Http = game:GetService("HttpService")
local result = { passed = 0, failures = {}, requests = {} }
local function check(ok, message)
	if ok then
		result.passed += 1
	else
		table.insert(result.failures, message)
	end
end
local function waitFor(fn, timeout)
	local t = os.clock()
	repeat
		if fn() then
			return true
		end
		task.wait(0.08)
	until os.clock() - t > timeout
	return false
end
local function request(action, arg)
	local ok, message = S.Request(action, arg)
	task.wait(0.2)
	if action == "Tutorial" then
		table.insert(
			result.requests,
			{ arg = arg, ok = ok, message = message, step = S.Data.TutorialStep, menu = H.IsOpen("Creatures") }
		)
	end
	return ok, message
end
local function move(pos)
	p.Character:PivotTo(CFrame.new(pos))
	task.wait(0.6)
end
local function save()
	p:SetAttribute("ForgeReviewResult", Http:JSONEncode(result))
end
local bridge = Instance.new("BindableFunction")
bridge.Name = "ForgeReviewControl"
bridge.OnInvoke = function(action)
	if action == "OpenGold" then
		H.Close()
		Forge.Open("Gold")
	elseif action == "OpenRuby" then
		H.Close()
		Forge.Open("Ruby")
	elseif action == "Close" then
		H.Close()
	elseif action == "RestartGuide" then
		H.Close()
		request("Tutorial", "Restart")
	elseif action == "AfterGold" then
		check(#S.Data.Creatures == 10, "Gold consumes five and produces exactly one")
		local output
		for _, pet in S.Data.Creatures do
			if pet.u == 100 then
				output = pet
			end
		end
		check(output and output.v == "Gold" and output.l == 9, "Gold output preserves strongest selected level")
		check(S.Data.LastForge.succeeded and S.Data.LastForge.count == 5, "guaranteed attempt committed")
		check(not H.StorageFull, "capacity warning clears when forging frees space")
		local total = #S.Data.Creatures
		local ok =
			request("Forge", Http:JSONEncode({ id = S.Data.LastForge.id, target = "Gold", uids = { 5, 6, 7, 8, 9 } }))
		check(ok and #S.Data.Creatures == total, "replayed network request consumes no additional pets")
		save()
	elseif action == "AfterRuby" then
		check(#S.Data.Creatures == 6, "Ruby consumes five Gold and produces one")
		local ruby
		for _, pet in S.Data.Creatures do
			if pet.u == 101 then
				ruby = pet
			end
		end
		check(ruby and ruby.v == "Ruby", "second tier is Ruby")
		for _, uid in { 2, 3 } do
			local exists = false
			for _, pet in S.Data.Creatures do
				exists = exists or pet.u == uid
			end
			check(exists, "protected pet retained " .. uid)
		end
		save()
	elseif action == "WalkHall" then
		H.Close()
		move(Vector3.new(0, 4, -190))
		p.Character.Humanoid:MoveTo(Vector3.new(0, 2, -279))
		check(
			waitFor(function()
				return p.Character:GetPivot().Position.Z < -276
			end, 8),
			"north-south hall passage walkable"
		)
		move(Vector3.new(-28, 4, -236))
		p.Character.Humanoid:MoveTo(Vector3.new(28, 2, -236))
		check(
			waitFor(function()
				return p.Character:GetPivot().Position.X > 25
			end, 8),
			"cross passage keeps courtyards accessible"
		)
		save()
	end
	return {
		count = #S.Data.Creatures,
		step = S.Data.TutorialStep,
		full = H.StorageFull,
		last = S.Data.LastForge,
		result = result,
	}
end
bridge.Parent = p.PlayerGui
local ok, err = pcall(function()
	assert(
		waitFor(function()
			return S.Loaded
				and H.Gui.Enabled
				and not p.PlayerGui:FindFirstChild("Intro")
				and workspace:GetAttribute("ForgeFixtureReady")
		end, 70),
		"game ready"
	)
	task.wait(1)
	H.Close()
	H.Open("Creatures")
	check(H.IsOpen("Creatures"), "menu suspends automatic guide during isolated assertions")
	check(S.Data.TutorialStep == 1, "brand-new player starts saved tutorial")
	check(not request("Tutorial", "Advance:1"), "guide does not advance far from Launch Hall")
	move(Vector3.new(0, 4, -14))
	check(request("Tutorial", "Advance:1") and S.Data.TutorialStep == 2, "Launch Hall arrival advances guide")
	check(not request("Tutorial", "Advance:2"), "guide waits for first pet")
	assert(game.ReplicatedStorage.ForgeReviewFixture:InvokeServer("Full"))
	request("Sync")
	check(request("Tutorial", "Advance:2") and S.Data.TutorialStep == 3, "caught companion advances guide")
	local b = workspace.Bases["Base" .. S.Data.BaseIndex]
	move(b:FindFirstChild("CollectPad", true).Position + Vector3.new(0, 3, 0))
	check(request("Tutorial", "Advance:3") and S.Data.TutorialStep == 4, "treasury arrival advances guide")
	move(Vector3.new(0, 4, -197))
	check(request("Tutorial", "Advance:4") and S.Data.TutorialStep == 5, "Forge Hall completes saved tutorial")
	check(request("Tutorial", "Restart") and S.Data.TutorialStep == 1, "guide replay works")
	check(request("Tutorial", "Skip") and S.Data.TutorialStep == 5, "skip persists completion")
	H.Close()
	task.wait(0.25)
	check(
		H.StorageFull and p.PlayerGui.HUD.Root.Gameplay.PetCapacityWarning.Visible,
		"full inventory has visible fixed warning"
	)
	move(Vector3.new(0, 4, -60))
	check(
		not request("Forge", Http:JSONEncode({ id = "review-far-away", target = "Gold", uids = { 5, 6, 7, 8, 9 } })),
		"server rejects forging away from hall"
	)
	move(Vector3.new(-12, 4, -242))
	check(
		not request("Forge", Http:JSONEncode({ id = "review-duplicate", target = "Gold", uids = { 5, 5 } })),
		"duplicate UID rejected by real server"
	)
	check(
		not request("Forge", Http:JSONEncode({ id = "review-equipped", target = "Gold", uids = { 1, 2 } })),
		"following pet protected by real server"
	)
	check(
		not request("Forge", Http:JSONEncode({ id = "review-locked-pet", target = "Gold", uids = { 1, 3 } })),
		"locked pet protected by real server"
	)
	check(#S.Data.Creatures == 14, "rejected attempts consume nothing")
	result.backendCompleted = true
end)
if not ok then
	table.insert(result.failures, tostring(err))
end
save()
