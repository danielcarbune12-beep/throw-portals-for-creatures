-- Optional isolated Studio review; never included in production builds.
if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local p = game.Players.LocalPlayer
local client = p.PlayerScripts:WaitForChild("Client")
local State, HUD = require(client.ClientState), require(client.HUD)
local Settings = require(client.ClientSettings)
local Run = game:GetService("RunService")
local result = { passed = 0, failures = {}, samples = {} }
local function check(ok, message)
	if ok then
		result.passed += 1
	else
		table.insert(result.failures, message)
	end
end
local function waitFor(fn, seconds)
	local start = os.clock()
	repeat
		if fn() then
			return true
		end
		task.wait(0.05)
	until os.clock() - start > seconds
	return false
end
local function move(pos)
	p.Character:PivotTo(CFrame.new(pos))
	task.wait(0.5)
end
local function visibleParts()
	local n = 0
	for _, part in workspace.KnightGuideArrows:GetChildren() do
		if part.Transparency < 0.95 then
			n += 1
		end
	end
	return n
end
local ok, err = pcall(function()
	assert(
		waitFor(function()
			return State.Loaded and HUD.Gui.Enabled and not p.PlayerGui:FindFirstChild("Intro")
		end, 70),
		"game ready"
	)
	HUD.Close()
	State.Request("Tutorial", "Restart")
	move(Vector3.new(0, 4, -100))
	local panel = HUD.Root.KnightGuide
	assert(
		waitFor(function()
			return panel.Visible and visibleParts() == 14
		end, 5),
		"guide visible"
	)
	check(panel:GetAttribute("GuideStep") == 1, "replay shows first saved step")
	local clearsInlays = true
	for _, part in workspace.KnightGuideArrows:GetChildren() do
		clearsInlays = clearsInlays and part.Position.Y >= 0.49
	end
	check(clearsInlays, "central trail clears non-querying decorative paving")
	if HUD.Compact then
		local quest = p.PlayerGui.QuestPanel.Card
		check(
			panel.AbsolutePosition.X + panel.AbsoluteSize.X < quest.AbsolutePosition.X,
			"compact guide clears the quest tracker"
		)
		check(panel.AbsolutePosition.Y < 120, "compact guide clears bottom movement controls")
	end
	local roots = 0
	for _, o in workspace:GetChildren() do
		if o.Name == "KnightGuideArrows" then
			roots += 1
		end
	end
	require(client.KnightGuide).Init()
	local afterRoots = 0
	for _, o in workspace:GetChildren() do
		if o.Name == "KnightGuideArrows" then
			afterRoots += 1
		end
	end
	check(
		roots == 1 and afterRoots == 1 and #workspace.KnightGuideArrows:GetChildren() == 14,
		"repeated Init creates no extra arrows"
	)
	local copyCount = 0
	for _, o in HUD.Root:GetChildren() do
		if o.Name == "KnightGuide" then
			copyCount += 1
		end
	end
	check(copyCount == 1, "repeated Init creates no extra guide panel")
	local edits = 0
	local textConnection = panel.Instruction:GetPropertyChangedSignal("Text"):Connect(function()
		edits += 1
	end)
	local layoutConnection = panel:GetPropertyChangedSignal("Size"):Connect(function()
		edits += 1
	end)
	task.wait(1.2)
	check(edits == 0, "idle guide does not rewrite text or layout")
	textConnection:Disconnect()
	layoutConnection:Disconnect()
	local arrow = workspace.KnightGuideArrows:GetChildren()[1]
	local frames, changed, maxJump, last = 0, 0, 0, arrow.Position
	local connection = Run.RenderStepped:Connect(function()
		frames += 1
		local jump = (arrow.Position - last).Magnitude
		if jump > 0.002 then
			changed += 1
		end
		maxJump = math.max(maxJump, jump)
		last = arrow.Position
	end)
	p.Character.Humanoid:MoveTo(Vector3.new(0, 2, -73))
	task.wait(1.25)
	connection:Disconnect()
	p.Character.Humanoid:MoveTo(p.Character:GetPivot().Position)
	result.samples.walk = { frames = frames, changed = changed, maxArrowJump = maxJump }
	check(changed > frames * 0.6, "arrows move on rendered frames rather than eight updates per second")
	check(maxJump < 1.5, "normal walking has no multi-stud arrow jumps")
	Settings.Set("VFXQuality", "Low")
	task.wait(0.6)
	check(visibleParts() == 8, "Low VFX renders four chevrons")
	Settings.Set("ReducedMotion", true)
	task.wait(0.3)
	local before = arrow.Transparency
	task.wait(0.4)
	check(math.abs(before - arrow.Transparency) < 0.001, "Reduced Motion has no pulsing")
	check(panel.Instruction.TextTransparency == 0, "Reduced Motion leaves instructions fully legible")
	HUD.Open("Creatures")
	task.wait(0.2)
	check(not panel.Visible and visibleParts() == 0, "menus immediately suspend guide and arrows")
	local position = arrow.CFrame
	task.wait(0.3)
	check(arrow.CFrame == position, "hidden guide stops updating arrow transforms")
	HUD.Close()
	task.wait(0.3)
	check(panel.Visible and visibleParts() == 8, "closing menu restores the existing guide")
	Settings.Set("ReducedMotion", false)
	Settings.Set("VFXQuality", "High")
	move(Vector3.new(0, 4, -14))
	check(
		waitFor(function()
			return panel:GetAttribute("GuideStep") == 2
		end, 4),
		"arrival advances through the real server"
	)
	task.wait(0.5)
	check(
		visibleParts() == 0 and not panel.GuideDirection.Visible,
		"catch step removes navigation while already in the throw zone"
	)
	check(panel.Instruction.Text:find("charge") ~= nil, "catch instructions replace travel instructions")
	State.Request("Tutorial", "Skip")
	task.wait(0.3)
	check(not panel.Visible and visibleParts() == 0, "skip removes the guide and arrows")
	State.Request("Tutorial", "Restart")
	move(Vector3.new(0, 4, -100))
	check(panel.Visible and visibleParts() == 14, "replay reuses and restores the trail")
	result.samples.partsAfterReplay = #workspace.KnightGuideArrows:GetChildren()
	check(result.samples.partsAfterReplay == 14, "replay keeps the arrow count bounded")
end)
if not ok then
	table.insert(result.failures, tostring(err))
end
result.completed = true
p:SetAttribute("TutorialMotionReview", game.HttpService:JSONEncode(result))
