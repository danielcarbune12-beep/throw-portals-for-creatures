-- Focused real-game test for lobby navigation and all nine portal lifecycles.
-- Opt-in Studio session only. DataService recognizes this marker and keeps all data in memory.
if
	not game:GetService("RunService"):IsStudio()
	or not (workspace:GetAttribute("SanctuaryTest") or workspace:FindFirstChild("SanctuaryTest"))
then
	return
end
local Players, RS = game:GetService("Players"), game:GetService("ReplicatedStorage")
local Http = game:GetService("HttpService")
local player = Players.LocalPlayer
local Client = script.Parent:WaitForChild("Client")
local State, TC = require(Client.ClientState), require(Client.ThrowController)
local Config = require(RS.Shared.Config)
local Renderer = require(Client.CreatureRenderer)
local HUD = require(Client.HUD)
local MovementFov = require(Client.MovementFov)
local passed, failures, records = 0, {}, {}
local function check(ok, message)
	if ok then
		passed += 1
	else
		table.insert(failures, message)
		warn("[SANCTUARY TEST] FAIL: " .. message)
	end
end
local function admin(cmd, value)
	local ok, msg = State.Request("Admin", Http:JSONEncode({ cmd = cmd, value = value }))
	check(ok, "admin setup " .. cmd .. ": " .. tostring(msg))
end
local function finish()
	local result = { passed = passed, failures = failures, portalRuns = records, completed = true }
	player:SetAttribute("SanctuaryTestResult", Http:JSONEncode(result))
	print("[SANCTUARY TEST] " .. Http:JSONEncode(result))
end
local ok, err = pcall(function()
	local start = os.clock()
	while not State.Loaded and os.clock() - start < 45 do
		task.wait(0.25)
	end
	check(State.Loaded, "player profile loaded")
	if not State.Loaded then
		return
	end
	local introDeadline = os.clock() + 35
	while player.PlayerGui:FindFirstChild("Intro") and os.clock() < introDeadline do
		task.wait(0.1)
	end
	HUD.Close()
	admin("reset")
	local character = player.Character or player.CharacterAdded:Wait()
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	check(root and humanoid, "spawned controllable avatar")
	if not root or not humanoid then
		return
	end
	-- Real walking, through the center of the reference arch, without teleporting over it.
	character:PivotTo(CFrame.lookAt(Vector3.new(0, 4, -60), Vector3.new(0, 4, 0)))
	task.wait(0.5)
	TC.BeginCharge()
	task.wait(0.15)
	check(not TC.Charging, "throw rejected outside the hall")
	TC.EndCharge()
	humanoid:MoveTo(Vector3.new(0, 2.2, -14))
	local walkStart = os.clock()
	while root.Position.Z < -20 and os.clock() - walkStart < 10 do
		task.wait(0.1)
	end
	check(Config.InThrowZone(root.Position), "avatar walked through the arch into the hall")
	if not Config.InThrowZone(root.Position) then
		return
	end
	admin("allportals")
	for _, id in ipairs(Config.PortalOrder) do
		character:PivotTo(CFrame.lookAt(Vector3.new(0, 4, -14), Vector3.new(0, 4, 30)))
		local equipped, msg = State.Request("EquipPortal", id)
		check(equipped, id .. " equips: " .. tostring(msg))
		admin("forcenext", "Mossbun")
		task.wait(0.25)
		local before, t0 = #State.Data.Creatures, os.clock()
		local baselineFov = workspace.CurrentCamera.FieldOfView
		MovementFov.Update(workspace.CurrentCamera, 7, 3)
		TC.BeginCharge()
		task.wait(0.65)
		check(TC.Charging, id .. " charge started")
		TC.EndCharge()
		local sawGate, sawOrb = false, false
		while os.clock() - t0 < 18 do
			local folder = workspace:FindFirstChild("ClientFX")
			if folder then
				for _, item in ipairs(folder:GetChildren()) do
					sawGate = sawGate or item.Name == "PortalGate"
					sawOrb = sawOrb or item.Name == "PortalOrb"
				end
			end
			if #State.Data.Creatures == before + 1 and not TC.MyThrow then
				break
			end
			task.wait(0.1)
		end
		local restoreDeadline = os.clock() + 3.5
		while
			(TC.IsFollowing() or workspace.CurrentCamera.CameraType == Enum.CameraType.Scriptable)
			and os.clock() < restoreDeadline
		do
			task.wait(0.1)
		end
		task.wait(0.35)
		check(sawOrb, id .. " flight orb appeared")
		check(sawGate, id .. " gate opened in the real throw flow")
		check(#State.Data.Creatures == before + 1, id .. " awarded exactly one creature")
		check(not TC.MyThrow, id .. " pending throw cleared")
		check(workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable, id .. " camera restored")
		check(
			math.abs(workspace.CurrentCamera.FieldOfView - baselineFov) < 0.1,
			id .. " sprint lens does not leak through the real throw lifecycle"
		)
		local dof = game.Lighting:FindFirstChild("TPFC_DOF")
		check(
			not dof or (dof.FarIntensity < 0.001 and dof.NearIntensity < 0.001),
			id .. " closeup blur clears for gameplay"
		)
		local wild = 0
		for _ in pairs(Renderer.Wild) do
			wild += 1
		end
		check(wild == 0, id .. " reveal renderer cleaned up")
		local left = 0
		for _, item in ipairs(workspace.ClientFX:GetChildren()) do
			if item.Name == "PortalGate" or item.Name == "PortalOrb" then
				left += 1
			end
		end
		check(left == 0, id .. " portal and orb cleaned up")
		table.insert(
			records,
			{ id = id, seconds = math.round((os.clock() - t0) * 100) / 100, sawGate = sawGate, sawOrb = sawOrb }
		)
		print("[SANCTUARY TEST] completed " .. id)
	end
end)
if not ok then
	table.insert(failures, tostring(err))
end
finish()
