-- Opt-in Studio traversal and station checks. Uses isolated profiles only.
if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local p = game.Players.LocalPlayer
local C = p.PlayerScripts:WaitForChild("Client")
local S, H = require(C.ClientState), require(C.HUD)
local Rules = require(game.ReplicatedStorage.Shared.ForgeRules)
local result = { passed = 0, failures = {}, paths = {} }
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
		task.wait(0.1)
	until os.clock() - t > timeout
	return false
end
local function walk(name, start, destination, seconds)
	p.Character:PivotTo(CFrame.new(start))
	task.wait(0.65)
	p.Character.Humanoid:MoveTo(destination)
	local ok = waitFor(function()
		local pos = p.Character:GetPivot().Position
		return (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(destination.X, 0, destination.Z)).Magnitude < 3
	end, seconds)
	check(ok, name)
	table.insert(result.paths, { name = name, reached = ok, position = tostring(p.Character:GetPivot().Position) })
end
local ok, err = pcall(function()
	assert(
		waitFor(function()
			return S.Loaded and H.Gui.Enabled and not p.PlayerGui:FindFirstChild("Intro")
		end, 70),
		"game loaded"
	)
	task.wait(1)
	S.Request("Tutorial", "Skip")
	H.Close()
	local hall = workspace.Map.Start:WaitForChild("GreatForgeHall")
	check(hall:GetAttribute("HallRevision") == 2, "revised hall built at runtime")
	local roots = 0
	for _, child in workspace.Map.Start:GetChildren() do
		if child.Name == "GreatForgeHall" then
			roots += 1
		end
	end
	check(roots == 1, "one generated hall")
	for recipe, pos in pairs(Rules.Stations) do
		local count = 0
		for _, o in hall:GetDescendants() do
			if o.Name == recipe .. "Station" then
				count += 1
			end
		end
		local anchor = hall:FindFirstChild(recipe .. "Station", true)
		check(count == 1 and anchor ~= nil, recipe .. " anchor unique")
		check(anchor and (anchor.Position - pos).Magnitude < 0.01, recipe .. " authoritative anchor unchanged")
		check(anchor and anchor:FindFirstChildOfClass("ProximityPrompt") ~= nil, recipe .. " interaction attached")
	end
	walk("central avenue remains open", Vector3.new(0, 4, -185), Vector3.new(0, 2, -281), 8)
	walk("both courtyard approaches remain open", Vector3.new(-29, 4, -236), Vector3.new(29, 2, -236), 7)
	walk("Gold work bay reachable", Vector3.new(0, 4, -236), Vector3.new(-12, 2, -242), 5)
	walk("Ruby work bay reachable", Vector3.new(0, 4, -236), Vector3.new(12, 2, -242), 5)
	local emberCount = 0
	for _, o in hall:GetDescendants() do
		if o:IsA("ParticleEmitter") then
			emberCount += 1
			check(
				game.CollectionService:HasTag(o, "TPFC_EnvironmentEmitter")
					and type(o:GetAttribute("BaseRate")) == "number",
				"ambience obeys existing VFX settings"
			)
		end
	end
	check(emberCount == 6, "bounded furnace and chimney effects")
end)
if not ok then
	table.insert(result.failures, tostring(err))
end
result.completed = true
p:SetAttribute("GuildForgeGeometryReview", game.HttpService:JSONEncode(result))
local control = Instance.new("BindableFunction")
control.Name = "GuildForgeReviewControl"
control.OnInvoke = function(stage)
	if stage == "Close" then
		H.Close()
	elseif stage == "Gold" or stage == "Ruby" then
		require(C.ForgePanel).Open(stage)
	end
	return result
end
control.Parent = p.PlayerGui
