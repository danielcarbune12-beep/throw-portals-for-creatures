-- Inject into an isolated SanctuaryTest Studio session only. Uses real requests
-- and the real mission timer, never edits profiles or forwards a client clock.
if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local p = game.Players.LocalPlayer
local C = p.PlayerScripts:WaitForChild("Client")
local S, H, E = require(C.ClientState), require(C.HUD), require(C.ExpeditionPanel)
local Http = game:GetService("HttpService")
local result = { passed = 0, failures = {} }
local function check(value, message)
	if value then
		result.passed += 1
	else
		table.insert(result.failures, message)
		warn("[SKYFORGE REVIEW] " .. message)
	end
end
local function waitFor(fn, seconds)
	local started = os.clock()
	repeat
		if fn() then
			return true
		end
		task.wait(0.1)
	until os.clock() - started > seconds
	return false
end
local function request(name, arg)
	local ok, msg = S.Request(name, arg)
	task.wait(0.22)
	return ok, msg
end
local ok, err = pcall(function()
	check(
		waitFor(function()
			return S.Loaded and H.Gui.Enabled
		end, 45),
		"profile and presentation ready"
	)
	H.Close()
	local char = p.Character or p.CharacterAdded:Wait()
	local root, hum = char:WaitForChild("HumanoidRootPart"), char:WaitForChild("Humanoid")
	local base = workspace.Bases["Base" .. p:GetAttribute("BaseIndex")]
	check(
		base:GetAttribute("BaseStyle") == "SkyforgeCourtyard" and base:GetAttribute("SanctuaryVersion") == 5,
		"approved courtyard built"
	)
	check(
		base:FindFirstChild("ExpeditionTable") ~= nil and base:FindFirstChild("WorkoutSeat", true) == nil,
		"functional table replaces bench"
	)
	check(
		waitFor(function()
			return base.ExpeditionAnchor:FindFirstChild("OwnExpeditionPrompt") ~= nil
		end, 4),
		"contextual own-base prompt"
	)
	local prompts = 0
	for _, b in workspace.Bases:GetChildren() do
		if b:FindFirstChild("OwnExpeditionPrompt", true) then
			prompts += 1
		end
	end
	check(prompts == 1, "no prompts on other players' tables")
	check(request("Admin", Http:JSONEncode({ cmd = "give", value = "Mossbun" })), "review pet added")
	local uid = S.Data.Creatures[1].u
	check(S.Data.Expeditions and #S.Data.Expeditions.routes == 8, "eight biome routes synced")
	check(
		not request("StartExpedition", Http:JSONEncode({ route = "Forest", petUid = uid })),
		"remote dispatch rejected away from table"
	)
	local cf = base.Center.CFrame
	local function walk(x, z, message)
		local target = cf:PointToWorldSpace(Vector3.new(x, 0, z))
		hum:MoveTo(target)
		check(
			waitFor(function()
				return ((root.Position - target) * Vector3.new(1, 0, 1)).Magnitude < 2
			end, 10),
			message
		)
	end
	char:PivotTo(cf * CFrame.new(0, 4, -40))
	task.wait(0.3)
	walk(0, -25, "walk through open entrance")
	walk(-19, -21, "reach collection pad")
	walk(0, -24, "collection route clear")
	walk(19, -24, "reach expedition planning position")
	check(not request("StartExpedition", "invalid JSON"), "malformed dispatch rejected")
	check(
		not request("StartExpedition", Http:JSONEncode({ route = "Forest", petUid = 999999 })),
		"foreign creature rejected"
	)
	check(not request("StartExpedition", Http:JSONEncode({ route = "Volcano", petUid = uid })), "locked biome rejected")
	local strength = S.Data.Strength
	check(not request("Train") and S.Data.Strength == strength, "retired lifting cannot award strength")
	E.Open()
	task.wait(0.5)
	check(H.IsOpen("Expeditions"), "expedition panel opens")
	local page = H.Panels.Expeditions
	check(page.frame:FindFirstChild("Pet_" .. uid, true) ~= nil, "owned pet selector shown")
	check(page.frame:FindFirstChild("Route_Forest", true) ~= nil, "route selector shown")
	check(request("StartExpedition", Http:JSONEncode({ route = "Forest", petUid = uid })), "real expedition dispatch")
	local active = S.Data.Expeditions.active
	check(type(active) == "table" and active.petUid == uid and active.matched, "native biome bonus and identity")
	local tripId, coins = active.id, active.coins
	result.duration = active.endsAt - active.startedAt
	check(#S.Data.Creatures == 1 and #S.Data.Placed == 1, "pet and placed slot retained")
	check(S.Data.Income == 0, "away pet garden income pauses")
	check(#Http:JSONDecode(p:GetAttribute("BaseCreatures")) == 0, "away pet leaves rendered courtyard")
	check(not request("Sell", uid), "away pet cannot be sold")
	check(not request("Unplace", uid), "away pet cannot be stored")
	check(not request("Place", uid), "away pet cannot be placed twice")
	check(not request("EquipBest"), "away slot cannot be rearranged")
	check(not request("ClaimExpedition", tripId), "early claim rejected")
	check(
		not request("StartExpedition", Http:JSONEncode({ route = "Forest", petUid = uid })),
		"duplicate dispatch rejected"
	)
	check(page.frame:FindFirstChild("ActiveExpedition", true).Visible, "active mission view shown")
	local claim = page.frame:FindFirstChild("ClaimExpedition", true)
	check(not claim:GetAttribute("Enabled"), "claim disabled before ready")
	p:SetAttribute("SkyforgeReviewStage", "Exploring")
	local startMoney = S.Data.Money
	check(
		waitFor(function()
			return os.time() >= active.endsAt + 1
		end, result.duration + 8),
		"real mission time elapsed"
	)
	task.wait(1.1)
	check(claim:GetAttribute("Enabled"), "claim enabled after real timer")
	check(request("ClaimExpedition", tripId), "ready expedition claimed")
	check(S.Data.Money == startMoney + coins, "exact frozen reward awarded")
	check(not S.Data.Expeditions.active and S.Data.Expeditions.completed == 1, "trip consumed and completion saved")
	check(S.Data.Expeditions.relics.Forest, "first biome relic earned")
	check(S.Data.Income == 1 and #S.Data.Placed == 1, "pet returns and income resumes")
	check(base.ExpeditionRelics:FindFirstChild("BiomeRelic_Forest") ~= nil, "earned relic displayed on map")
	check(
		not request("ClaimExpedition", tripId) and S.Data.Money == startMoney + coins,
		"replayed claim cannot pay again"
	)
	H.Close()
	check(not H.Root.Gameplay.Navigation.Visible and H.Root.Gameplay.Menu.Visible, "minimal HUD retained")
	check(
		not H.Root.Gameplay:FindFirstChild("Training", true) or not H.Root.Gameplay.Training.Visible,
		"lifting panel stays hidden"
	)
	result.reward = coins
	result.strength = S.Data.Strength
	p:SetAttribute("SkyforgeReviewStage", "Complete")
end)
if not ok then
	table.insert(result.failures, tostring(err))
	p:SetAttribute("SkyforgeReviewStage", "Error")
end
p:SetAttribute("SkyforgeReviewResult", Http:JSONEncode(result))
print("[SKYFORGE REVIEW] " .. Http:JSONEncode(result))
