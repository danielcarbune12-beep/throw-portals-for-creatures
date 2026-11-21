-- Run only as an explicitly injected LocalScript in an isolated Studio review.
if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local player = game.Players.LocalPlayer
local C = script.Parent:WaitForChild("Client")
local State, TC, H, Settings =
	require(C.ClientState), require(C.ThrowController), require(C.HUD), require(C.ClientSettings)
local Http = game:GetService("HttpService")
local result = { passed = 0, failures = {} }
local function check(ok, message)
	if ok then
		result.passed += 1
	else
		table.insert(result.failures, message)
		warn("[FEEL TEST] " .. message)
	end
end
local function waitFor(fn, timeout)
	local t = os.clock()
	repeat
		if fn() then
			return true
		end
		task.wait(0.05)
	until os.clock() - t > timeout
	return false
end
local function admin(cmd, value)
	local ok, msg = State.Request("Admin", Http:JSONEncode({ cmd = cmd, value = value }))
	check(ok, cmd .. ": " .. tostring(msg))
	task.wait(0.2)
end
local function orbs()
	local n = 0
	for _, v in workspace.ClientFX:GetChildren() do
		if v.Name == "PortalOrb" then
			n += 1
		end
	end
	return n
end
local function finish()
	player:SetAttribute("GameplayPolishTestResult", Http:JSONEncode(result))
	print("[FEEL TEST] " .. Http:JSONEncode(result))
end
local ok, err = pcall(function()
	check(
		waitFor(function()
			return State.Loaded
		end, 30),
		"profile loaded"
	)
	local char = player.Character or player.CharacterAdded:Wait()
	local root = char:WaitForChild("HumanoidRootPart")
	local function hall()
		char:PivotTo(CFrame.lookAt(Vector3.new(0, 4, -14), Vector3.new(0, 4, 100)))
		task.wait(0.3)
	end
	local baseFov = workspace.CurrentCamera.FieldOfView
	hall()
	H.Close()
	task.wait(1.3)
	hall()
	check(TC.BeginCharge("Keyboard"), "keyboard charge begins")
	task.wait(0.2)
	check(TC.Power > 0 and orbs() == 1, "one held orb and live charge power")
	check(
		not TC.EndCharge("Pointer") and TC.Charging and not TC.Submitting,
		"pointer release cannot end a keyboard charge"
	)
	check(TC.CancelCharge("test cancel"), "cancel acknowledged")
	task.wait(0.25)
	check(not TC.Charging and orbs() == 0, "cancel cleans held orb")
	local sound = game.SoundService:FindFirstChild("Charge")
	check(sound and not sound.IsPlaying, "cancel fades and stops loop")
	TC.BeginCharge("Keyboard")
	task.wait(0.1)
	H.Open("Menu")
	task.wait(0.2)
	check(not TC.Charging and not TC.Submitting and orbs() == 0, "opening menu cancels without launching")
	check(not TC.BeginCharge("Pointer"), "menu prevents charging")
	H.Close()
	TC.BeginCharge("Pointer")
	task.wait(0.1)
	char:PivotTo(CFrame.new(0, 4, -60))
	task.wait(0.3)
	check(not TC.Charging and not TC.Submitting and orbs() == 0, "leaving hall cancels charge")
	task.wait(0.4)
	check(math.abs(workspace.CurrentCamera.FieldOfView - baseFov) < 0.1, "charge FOV restored")
	admin("throwlevel", 10)
	admin("forcenext", "Mossbun")
	hall()
	local before = #State.Data.Creatures
	check(TC.BeginCharge("Keyboard"), "long throw charge begins")
	task.wait(0.65)
	check(TC.EndCharge("Keyboard"), "matching release launches")
	check(TC.Submitting and not TC.BeginCharge("Keyboard"), "launch acknowledgement gap blocks duplicates")
	check(
		waitFor(function()
			return TC.MyThrow ~= nil
		end, 4),
		"server confirms launch"
	)
	check(not TC.Submitting, "confirmation clears submission state")
	task.wait(0.2)
	check(workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable, "long throw claims follow camera")
	check(not H.ThrowButton.Visible, "no charge button while portal active")
	H.Open("Menu")
	check(workspace.CurrentCamera.CameraType == Enum.CameraType.Custom, "opening a menu restores follow camera")
	check(TC.InputBlocked, "menu maintains input block during active throw")
	H.Close()
	check(
		waitFor(function()
			return #State.Data.Creatures == before + 1 and not TC.MyThrow
		end, 18),
		"one creature awarded and pending throw cleared"
	)
	check(TC.BeginCharge("Keyboard"), "next charge can begin after confirmed award")
	check(workspace.CurrentCamera.CameraType == Enum.CameraType.Custom, "next charge immediately restores avatar view")
	TC.CancelCharge("test")
	task.wait(1.3)
	Settings.Set("ReducedMotion", true)
	admin("forcenext", "Mossbun")
	hall()
	before = #State.Data.Creatures
	TC.BeginCharge("Keyboard")
	task.wait(0.65)
	TC.EndCharge("Keyboard")
	check(
		waitFor(function()
			return TC.MyThrow ~= nil
		end, 4),
		"reduced-motion launch confirms"
	)
	task.wait(0.25)
	check(workspace.CurrentCamera.CameraType == Enum.CameraType.Custom, "reduced motion skips flight chase")
	check(
		waitFor(function()
			return TC.Phase == "Revealing"
		end, 8),
		"reduced motion still reveals creature"
	)
	task.wait(0.15)
	local cf = workspace.CurrentCamera.CFrame
	task.wait(0.25)
	check(
		(workspace.CurrentCamera.CFrame.Position - cf.Position).Magnitude < 0.05,
		"reduced-motion reveal camera stays planted"
	)
	check(
		waitFor(function()
			return #State.Data.Creatures == before + 1 and not TC.MyThrow
		end, 10),
		"reduced-motion catch awards once"
	)
	check(
		waitFor(function()
			return workspace.CurrentCamera.CameraType == Enum.CameraType.Custom
		end, 5),
		"camera restores after capture"
	)
	check(math.abs(workspace.CurrentCamera.FieldOfView - baseFov) < 0.1, "follow restores field of view")
	Settings.Set("ReducedMotion", false)
	local g = workspace.Map.Start:FindFirstChild("SanctuaryDetails")
	check(g ~= nil, "polished lobby retained")
	local menu = H.Root.Gameplay.Menu
	check(menu.Visible, "single Menu still accessible")
	check(not H.Root.Gameplay.Navigation.Visible, "no navigation rail reintroduced")
	result.creaturesAwarded = #State.Data.Creatures
	result.finalPhase = TC.Phase
end)
if not ok then
	table.insert(result.failures, tostring(err))
end
TC.CancelCharge("review complete")
TC.StopFollow(true)
Settings.Set("ReducedMotion", false)
finish()
