-- Studio-only UI review bridge. Inject as a LocalScript for isolated QA, never production.
local Run = game:GetService("RunService")
if not Run:IsStudio() or not workspace:GetAttribute("UIReview") then
	return
end
local player = game:GetService("Players").LocalPlayer
local Client = player:WaitForChild("PlayerScripts"):WaitForChild("Client")
local State = require(Client.ClientState)
local HUD = require(Client.HUD)
local Settings = require(Client.ClientSettings)
local TC = require(Client.ThrowController)
local Http = game:GetService("HttpService")
while not State.Loaded do
	State.Request("Sync")
	task.wait(0.3)
end
local bridge = Instance.new("BindableFunction")
bridge.Name = "UIReviewControl"
bridge.Parent = player.PlayerGui
local passed, failures = 0, {}
local function check(value, message)
	if value then
		passed += 1
	else
		table.insert(failures, message)
	end
end
local function snapshot()
	local d = State.Data
	local ids = {}
	for _, e in ipairs(d.Creatures) do
		table.insert(ids, { uid = e.u, id = e.c, placed = State.IsPlaced(e.u) })
	end
	return {
		money = d.Money,
		equipped = d.EquippedPortal,
		owned = d.OwnedPortals,
		creatures = ids,
		placed = d.Placed,
		upgrades = d.Upgrades,
		decor = d.Decor,
		floor = d.FloorTheme,
		settings = { motion = Settings.ReducedMotion, flashes = Settings.ReducedFlashes, vfx = Settings.VFXQuality },
		charging = TC.Charging,
		blocked = TC.InputBlocked,
		panels = (function()
			local names = {}
			for name in HUD.Panels do
				table.insert(names, name)
			end
			return names
		end)(),
	}
end
bridge.OnInvoke = function(action, arg)
	if action == "Snapshot" then
		return Http:JSONEncode(snapshot())
	end
	if action == "Open" then
		HUD.Open(arg)
		return "Opened"
	end
	if action == "Close" then
		HUD.Close()
		return "Closed"
	end
	if action == "Fixture" then
		for _, req in ipairs({ { "money", 10000 }, { "give", "Mossbun" }, { "give", "Acornip" } }) do
			local ok, msg = State.Request("Admin", Http:JSONEncode({ cmd = req[1], value = req[2] }))
			check(ok, "Fixture " .. req[1] .. ": " .. tostring(msg))
			task.wait(0.25)
		end
		State.Request("Sync")
		task.wait(0.3)
		return Http:JSONEncode(snapshot())
	end
	if action == "Check" then
		local d = State.Data
		if arg == "initial" then
			check(State.Loaded, "data loaded")
			check(#snapshot().panels == 9, "nine menu panels")
			check(#player.PlayerGui:GetChildren() > 0, "player GUI exists")
			for _, name in
				{ "Portals", "Upgrades", "Creatures", "Index", "Worlds", "Base", "Settings", "Admin", "Menu" }
			do
				check(HUD.Panels[name] ~= nil, "panel " .. name)
			end
		elseif arg == "portalBought" then
			check(d.OwnedPortals.Forest == true, "Forest purchase persisted")
			check(d.Money == 9650, "Forest debited exactly 400")
		elseif arg == "portalEquipped" then
			check(d.EquippedPortal == "Forest", "Forest equipped")
		elseif arg == "upgradeBought" then
			check(d.Upgrades.ThrowPower == 2, "Throw Power upgraded once")
			check(d.Money == 9590, "upgrade debited exactly 60")
		elseif arg == "settings" then
			check(Settings.ReducedMotion, "reduced motion enabled")
			check(Settings.ReducedFlashes, "reduced flashes enabled")
			check(Settings.VFXQuality == "Low", "low effects selected")
		elseif arg == "saleCancelled" then
			check(#d.Creatures == 2, "changing selection did not sell either pet")
		elseif arg == "soldOnce" then
			check(#d.Creatures == 1, "confirmed sale removed exactly one pet")
		elseif arg == "decorBought" then
			check(d.Decor.FlowerBed == true, "flower bed purchased")
		elseif arg == "floorBought" then
			check(d.FloorTheme == "Stone", "stone floor applied")
			check(d.OwnedFloors.Stone == true, "stone ownership recorded")
		elseif arg == "modalGuard" then
			check(HUD.AnyPanelOpen(), "panel open")
			check(TC.InputBlocked, "throw blocked while menu open")
			TC.BeginCharge()
			check(not TC.Charging, "menu cannot charge portal")
		elseif arg == "close" then
			check(not HUD.AnyPanelOpen(), "panel closed")
			check(not TC.InputBlocked, "throw guard released")
			check(HUD.Root.Gameplay.Visible, "gameplay HUD restored")
		end
		player:SetAttribute("UIReviewResult", Http:JSONEncode({ passed = passed, failures = failures }))
		return Http:JSONEncode({ passed = passed, failures = failures, snapshot = snapshot() })
	end
	return "Unknown review command"
end
player:SetAttribute("UIReviewReady", true)
print("[UI REVIEW] Isolated interaction review ready")
