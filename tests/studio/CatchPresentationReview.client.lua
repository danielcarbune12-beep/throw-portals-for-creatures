-- Opt-in, isolated Studio review of the real throw -> deposit -> presentation flow.
if not game:GetService("RunService"):IsStudio() or not workspace:GetAttribute("SanctuaryTest") then
	return
end
local player = game.Players.LocalPlayer
local C = player.PlayerScripts:WaitForChild("Client")
local S, H, TC = require(C.ClientState), require(C.HUD), require(C.ThrowController)
local Renderer = require(C.CreatureRenderer)
local Settings = require(C.ClientSettings)
local Timeline = require(game.ReplicatedStorage.Shared.PresentationTimeline)
local Http = game:GetService("HttpService")
local result = { passed = 0, failures = {}, runs = {} }
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
		task.wait(0.04)
	until os.clock() - t > timeout
	return false
end
local function admin(cmd, value)
	local ok, message = S.Request("Admin", Http:JSONEncode({ cmd = cmd, value = value }))
	assert(ok, tostring(message))
end
local receipt = require(C.CaughtPresentation)
local review = Instance.new("BindableFunction")
review.Name = "CatchReviewControl"
review.OnInvoke = function(key, discovery)
	local old = Timeline.Card.hold
	Timeline.Card.hold = 10
	receipt(key, discovery)
	Timeline.Card.hold = old
	return true
end
review.Parent = player.PlayerGui
local ok, err = pcall(function()
	assert(
		waitFor(function()
			return S.Loaded and H.Gui.Enabled and not player.PlayerGui:FindFirstChild("Intro")
		end, 65),
		"game ready"
	)
	H.Close()
	admin("reset")
	for _, test in
		{
			{ "Mossbun", true },
			{ "Mossbun", false },
			{ "Acornip", true },
			{ "Acornip", false },
			{ "Petalfly", true },
			{ "Petalfly", true },
		}
	do
		local id, expected = test[1], test[2]
		local seen, banner, flags, started, captured, interrupted = nil, false, nil, false, false, false
		local before = #S.Data.Creatures
		local connections = {}
		table.insert(
			connections,
			S.Remotes.PortalThrown.OnClientEvent:Connect(function(info)
				if info.owner == player.UserId then
					seen = info
				end
			end)
		)
		table.insert(
			connections,
			S.Remotes.Deposit.OnClientEvent:Connect(function(_, discoveryFlags)
				flags = discoveryFlags
			end)
		)
		table.insert(
			connections,
			Renderer.CaptureFinished.Event:Connect(function(_, owner)
				if owner == player.UserId then
					captured = true
				end
			end)
		)
		admin("forcenext", id)
		player.Character:PivotTo(CFrame.lookAt(Vector3.new(0, 4, -14), Vector3.new(0, 4, 30)))
		task.wait(0.25)
		Settings.ReducedMotion = id == "Acornip"
		TC.BeginCharge()
		task.wait(0.65)
		TC.EndCharge()
		local releasedAt = os.clock()
		local deadline = releasedAt + 22
		repeat
			for _, e in pairs(Renderer.Wild) do
				if e.owner == player.UserId then
					started = true
					check((e.entrance ~= nil or e.presentation) == expected, id .. " entrance policy")
					check((e.tag ~= nil) == expected, id .. " nameplate policy")
					if e.tag then
						check(e.tag.Size.X.Offset <= 216 and e.tag.Size.Y.Offset <= 72, "compact world nameplate")
					end
				end
			end
			local slip = H.Root:FindFirstChild("CatchReceipt")
			if slip then
				banner = true
				check(slip.Size.X.Offset <= 272 and slip.Size.Y.Offset <= 80, "compact receipt bounds")
			end
			if
				not expected
				and os.clock() - releasedAt > 0.6
				and workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable
			then
				interrupted = true
			end
			task.wait(0.05)
		until os.clock() > deadline or (#S.Data.Creatures == before + 1 and captured and (banner or not expected))
		check(seen ~= nil and seen.presentation == expected, id .. " server reveal decision")
		check(started and captured, id .. " renderer completes")
		check(#S.Data.Creatures == before + 1, id .. " awarded exactly once")
		check(banner == expected, id .. " receipt policy")
		check(flags ~= nil and type(flags[1]) == "boolean", id .. " authoritative discovery flag")
		check(not interrupted, id .. " routine catch leaves camera alone")
		check(S.Data.Discovered[id], id .. " saved discovery synced")
		for _, connection in connections do
			connection:Disconnect()
		end
		table.insert(
			result.runs,
			{ id = id, presentation = seen and seen.presentation, receipt = banner, discovery = flags and flags[1] }
		)
		assert(
			waitFor(function()
				return not H.Root:FindFirstChild("CatchReceipt") and not TC.IsFollowing()
			end, 7),
			"presentation clears"
		)
		S.Request("Sync")
		task.wait(0.3)
	end
	Settings.ReducedMotion = false
	-- Owner decision: every throw keeps its reveal, including lower-tier repeats.
	check(
		Timeline.ShouldPresent("Common", false) and Timeline.ShouldPresent("Uncommon", false),
		"lower-tier repeats keep their reveal"
	)
	check(Timeline.ShouldPresent("Rare", false), "Rare repeat still earns reveal")
	H.Open("Creatures")
	receipt("Mossbun", true)
	check(not H.Root:FindFirstChild("CatchReceipt"), "open menu is not covered by a catch slip")
	H.Close()
end)
Settings.ReducedMotion = false
if not ok then
	table.insert(result.failures, tostring(err))
end
result.completed = true
player:SetAttribute("CatchPresentationReview", Http:JSONEncode(result))
print("[CATCH REVIEW] " .. Http:JSONEncode(result))
