-- AutoTestClient: plays the game like a player (only in the test build: Workspace has an "AutoTest" value).
-- Prints "[AUTOTEST]" lines that show up in the Studio log.
if not workspace:FindFirstChild("AutoTest") then return end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local Client = script.Parent:WaitForChild("Client")
local State = require(Client.ClientState)
local TC = require(Client.ThrowController)
local HUD = require(Client.HUD)
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local function log(...) print("[AUTOTEST]", ...) end
local function step(name, fn)
	local ok, err = pcall(fn)
	log(name, ok and "OK" or ("FAILED: " .. tostring(err)))
end
local function admin(cmd, value)
	local ok, msg = State.Request("Admin", HttpService:JSONEncode({ cmd = cmd, value = value }))
	log("admin", cmd, tostring(value), ok, msg)
end
local function root() return player.Character and player.Character:WaitForChild("HumanoidRootPart", 10) end
local function goTo(pos, lookAt)
	local r = root()
	if r then player.Character:PivotTo(CFrame.lookAt(pos, lookAt or (pos + Vector3.new(0, 0, 1)))) end
	task.wait(0.6)
end
local function throw(label, holdTime)
	local busyBefore = TC.MyThrow
	TC.BeginCharge()
	log(label, "charging =", TC.Charging, "busy =", tostring(busyBefore))
	task.wait(holdTime or 0.72)
	local p = TC.Power
	TC.EndCharge()
	log(label, string.format("released at power %.2f", p))
end

local RS = game:GetService("ReplicatedStorage")
local CreatureData = require(RS.Shared.CreatureData)
local Builder = require(RS.Shared.CreatureBuilder)
local Animator = require(RS.Shared.CreatureAnimator)
local Renderer = require(Client.CreatureRenderer)
local passed, failed = 0, 0
local function check(cond, msg)
	if cond then passed += 1 else failed += 1; warn("[AUTOTEST] FAIL: " .. msg) end
end

local t0 = os.clock()
while not State.Loaded and os.clock() - t0 < 40 do task.wait(0.5) end
log("data loaded:", State.Loaded, "money:", State.Data.Money)
task.wait(2)

step("all 74 creatures build, solve welds and animate in the real engine", function()
	local holder = Instance.new("Folder"); holder.Name = "RosterTest"; holder.Parent = workspace
	local baseline = #holder:GetDescendants()
	for i, def in ipairs(CreatureData.List) do
		local model, rig = Builder.Build(def.id)
		model:PivotTo(CFrame.new((i % 10) * 14, 300, math.floor(i / 10) * 14))
		model.Parent = holder
		local anim = Animator.new(rig, model:GetPivot())
		for _ = 1, 3 do anim:Step(1 / 30) end
		anim:PlayAccent("enter", 0.5); anim:Step(0.25); anim:EndAccent()
		anim:React("pet"); anim:Step(0.3)
		task.wait()
		local _, size = Builder.VisualBounds(model)
		check(size.Magnitude > 1 and size.Magnitude < 70, def.id .. " visual bounds " .. tostring(size))
		local collide = 0
		for _, d in ipairs(model:GetDescendants()) do if d:IsA("BasePart") and d.CanCollide then collide += 1 end end
		check(collide == 0, def.id .. " has no collidable pieces")
		anim:Destroy()
		model:Destroy()
	end
	check(#holder:GetDescendants() == baseline, "roster test cleaned up")
	holder:Destroy()
end)

step("admin setup", function()
	admin("money", 50000000)
	admin("strength", 40000)
	task.wait(1)
	log("max throw distance:", State.Data.MaxDistance)
end)

step("try throwing OUTSIDE the hall (should be blocked)", function()
	goTo(Vector3.new(0, 4, -70))
	throw("outside", 0.3)
	log("charging after outside attempt =", TC.Charging)
end)

-- into the Launch Hall
step("walk into Launch Hall", function()
	goTo(Vector3.new(0, 4, -14))
	task.wait(1)
	log("in throw zone:", Config.InThrowZone(root().Position))
end)

step("throw 1 (random pet)", function()
	throw("throw1")
	task.wait(1)
	throw("throw1-again (should be blocked: one at a time)", 0.3)
	task.wait(8)
	log("after throw1, creatures:", #State.Data.Creatures, "placed:", #State.Data.Placed)
end)

-- one forced pet per rarity + the bespoke-anatomy showcase pets, through the real throw flow
local FORCED = { "Mossbun", "Acornip", "Petalfly", "Thornhog", "PrismLion", "MagmaKraken", "VoidCrystalHydra", "Glitchling", "Infinity" }
for _, id in ipairs(FORCED) do
	step("throw forced " .. id .. " (" .. CreatureData.ById[id].rarity .. ")", function()
		goTo(Vector3.new(0, 4, -14))
		local before = #State.Data.Creatures
		admin("forcenext", id)
		throw("throw-" .. id)
		task.wait(13)
		check(#State.Data.Creatures == before + 1, id .. " granted exactly once (" .. before .. " -> " .. #State.Data.Creatures .. ")")
		check(workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable, id .. " camera restored after reveal")
		local wildLeft = 0
		for _ in pairs(Renderer.Wild) do wildLeft += 1 end
		check(wildLeft == 0, id .. " wild entry cleaned up")
	end)
end

step("visit my base (pets should roam)", function()
	local idx = player:GetAttribute("BaseIndex")
	local base = workspace.Bases:FindFirstChild("Base" .. tostring(idx))
	log("base index", idx, "found", base ~= nil, "pets in base attr:", player:GetAttribute("BaseCreatures"))
	if base then
		local c = base.Center.Position
		goTo(c + Vector3.new(0, 4, -20), c)
		task.wait(6)
	end
end)

step("upgrade + lift in my personal gym", function()
	local ok, msg = State.Request("UpgradeEquipment")
	log("upgrade gym:", ok, msg)
	local idx = player:GetAttribute("BaseIndex")
	local base = workspace.Bases:FindFirstChild("Base" .. tostring(idx))
	local gym = base and base:FindFirstChild("GymPad")
	if not gym then error("no gym pad found") end
	goTo(gym.Position + Vector3.new(0, 4, 0), gym.Position + Vector3.new(0, 4, -10))
	task.wait(1)
	local before = State.Data.Strength
	log("train station shown:", tostring(HUD.TrainStation))
	HUD.AutoTrain = true
	task.wait(5)
	HUD.AutoTrain = false
	task.wait(0.6)
	log("strength before/after:", before, State.Data.Strength)
	local prop = player.Character and player.Character:FindFirstChild("LiftProp")
	log("lift prop visible right after:", prop ~= nil)
end)

step("open menus", function()
	for _, name in ipairs({ "Creatures", "Index", "Worlds", "Portals", "Upgrades", "Admin" }) do
		HUD.Open(name)
		task.wait(1.6)
	end
	HUD.Close()
end)

log("client done, total creatures:", #State.Data.Creatures, "money:", State.Data.Money, "active renders:", Renderer.ActiveCount())
log(string.format("ASSERTIONS: %d passed, %d failed", passed, failed))
