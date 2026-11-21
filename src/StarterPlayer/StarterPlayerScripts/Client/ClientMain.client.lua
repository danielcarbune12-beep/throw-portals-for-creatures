-- ClientMain: wires all client modules together.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ClientMain (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureData = require(Shared.CreatureData)
local Config = require(Shared.Config)
local Format = require(Shared.Format)

local Client = script.Parent
local State = require(Client.ClientState)
local Effects = require(Client.Effects)
local Sounds = require(Client.Sounds)
local Renderer = require(Client.CreatureRenderer)
local TC = require(Client.ThrowController)
local HUD = require(Client.HUD)
local Panels = require(Client.Panels)

local player = Players.LocalPlayer
local Remotes = State.Remotes

Effects.SetupLighting()
Renderer.Start()
Panels.Init()
HUD.TC = TC
TC.OnThrowResult = HUD.ThrowFeedback
HUD.Refresh()

-- ask the server for a full data sync (retries until our save has loaded)
task.spawn(function()
	while not State.Loaded do
		State.Request("Sync")
		task.wait(1.5)
	end
end)

---------------------------------------------------------------- collecting wild creatures
local collecting = {}
Renderer.OnCollectRequest = function(throwId)
	if collecting[throwId] then return end
	collecting[throwId] = true
	local ok, msg = State.Request("Collect", throwId)
	collecting[throwId] = nil
	if not ok then HUD.Notify(msg or "Can't collect", "error") end
end

HUD.OnCollect = Renderer.OnCollectRequest

---------------------------------------------------------------- the limit: barrier + "throw from here"
local function barrierPulse(pos)
	local map = workspace:FindFirstChild("Map")
	local wall = map and map:FindFirstChild("Start") and map.Start:FindFirstChild("Barrier")
	if wall then
		wall.Transparency = 0.02
		Effects.Tween(wall, 0.8, { Transparency = 0.35 })
	end
	if pos then
		Effects.Shockwave(Vector3.new(pos.X, 1, Config.BarrierZ - 1), Color3.fromRGB(190, 140, 255), 10, 0.5)
		Effects.Burst(Vector3.new(pos.X, pos.Y, Config.BarrierZ - 1), Color3.fromRGB(200, 160, 255), 20, 10, 0.7)
	end
end
TC.OnNotInZone = function()
	HUD.ShowThrowHere("🎯 GO TO THE THROW LINE!", nil)
end
local lastBarrierFx = 0

TC.OnBusy = function()
	HUD.ShowThrowHere("⏳ ONE PORTAL AT A TIME", "Wait until your creature is caught!")
end

---------------------------------------------------------------- training: buy equipment + lifting animation
HUD.OnUpgradeGym = function()
	local ok, msg = State.Request("UpgradeEquipment")
	if ok then
		local st = Config.TrainingStations[math.clamp(State.Data.EquipLevel or 1, 1, #Config.TrainingStations)]
		Sounds.Play("Upgrade")
		task.delay(0.15, Sounds.Play, "Rare", 1.3)
		HUD.Notify(msg or "Gym upgraded!", "success")
		Effects.Coins(nil, 12)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			Effects.Burst(root.Position + Vector3.new(0, 2, 0), st.color, 50, 18, 1)
			Effects.Shockwave(root.Position - Vector3.new(0, 2.5, 0), st.color, 12, 0.5)
		end
		HUD._shownGym = nil -- refresh the buttons
	else
		HUD.Notify(msg or "Can't upgrade", "error")
	end
end

-- Lifting uses Roblox's built-in "cheer" animation (both arms raise the weight overhead).
-- It plays on your own character, so other players see it too.
local LIFT_ANIM = { [Enum.HumanoidRigType.R15] = "rbxassetid://507770677", [Enum.HumanoidRigType.R6] = "rbxassetid://129423030" }
local liftTrack, liftHum, lastLift = nil, nil, 0
local function playLift()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if hum ~= liftHum then
		liftHum = hum
		liftTrack = nil
		local animator = hum:FindFirstChildOfClass("Animator") or hum
		local anim = Instance.new("Animation")
		anim.AnimationId = LIFT_ANIM[hum.RigType] or LIFT_ANIM[Enum.HumanoidRigType.R15]
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			liftTrack = track
		end
	end
	lastLift = os.clock()
	if liftTrack and not liftTrack.IsPlaying then liftTrack:Play(0.15, 1, 1.7) end
end
RunService.Heartbeat:Connect(function()
	if liftTrack and liftTrack.IsPlaying and os.clock() - lastLift > 0.7 then liftTrack:Stop(0.25) end
end)

local lastRep = 0
local function doRep()
	local idx = HUD.TrainStation
	if not idx or os.clock() - lastRep < Config.TrainCooldown then return end
	lastRep = os.clock()
	local st = Config.TrainingStations[idx]
	playLift()
	HUD.TrainPulse()
	task.spawn(function()
		local ok, msg = State.Request("Train", idx)
		if ok then
			Sounds.Play("Collect", 1.4 + math.random() * 0.2)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if root then
				Effects.FloatingText(root.Position + Vector3.new(math.random(-2, 2), 4, 0), "+" .. Format.Short(st.gain) .. " 💪", Color3.fromRGB(255, 150, 120), 0.8)
			end
		elseif msg then
			HUD.Notify(msg, "error")
		end
	end)
end
RunService.Heartbeat:Connect(function()
	if HUD.TrainStation and (HUD.TrainHeld or HUD.AutoTrain) then doRep() end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.E and HUD.TrainStation then doRep() end
end)

---------------------------------------------------------------- server messages
Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	if kind == "throwzone" then
		HUD.ShowThrowHere("🎯 GO TO THE THROW LINE!", nil)
		return
	end
	HUD.Notify(text, kind)
	if kind == "discover" then Sounds.Play("Rare", 1.3) end
end)

Remotes.MoneyFx.OnClientEvent:Connect(function(amount, padPos)
	Sounds.Play("Money")
	task.delay(0.15, Sounds.Play, "Money", 1.25)
	Effects.Coins(padPos, math.clamp(math.floor(math.log10(amount + 1) * 4), 6, 22))
	Effects.FloatingText(padPos + Vector3.new(0, 4, 0), "+" .. Format.Money(amount), Color3.fromRGB(130, 255, 130), 1.3)
	Effects.Burst(padPos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 215, 70), 30, 14, 0.8)
end)

-- "CAUGHT!" card: pops up with the spinning creature, then flies into the Pets button
local K = require(Client.UIKit)
local function caughtCard(id)
	local def = CreatureData.ById[id]
	if not def then return end
	local rc = Config.Rarities[def.rarity]
	local cfg = Renderer.CatchConfig[def.rarity] or Renderer.CatchConfig.Common
	local bad = rc.order <= 1
	local W, H = 300, 340
	local cardCol = bad and Color3.fromRGB(170, 170, 180) or rc.color:Lerp(Color3.new(1, 1, 1), 0.25)
	local card = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(W, H),
		BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 30, Parent = HUD.Root },
		{ K.corner(26), K.stroke(rc.order >= 5 and 7 or 5, rc.order >= 5 and Color3.fromRGB(255, 220, 90) or nil), K.grad(Color3.new(1, 1, 1), cardCol, 90) })
	local sc = K.new("UIScale", { Scale = 0, Parent = card })
	local targetScale = 0.7 + cfg.size * 0.28 -- tiny for bad pets, big for great ones
	-- spinning glow behind the creature (two layers for Legendary+)
	local glow = K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(190, 190),
		BackgroundColor3 = bad and Color3.fromRGB(140, 140, 150) or rc.color, BackgroundTransparency = 0.35, ZIndex = 30, Parent = card }, { K.corner(30) })
	local glow2 = rc.order >= 5 and K.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(230, 230),
		BackgroundColor3 = Color3.fromRGB(255, 230, 120), BackgroundTransparency = 0.6, ZIndex = 30, Parent = card }, { K.corner(40) }) or nil
	K.label(cfg.text, UDim2.new(1, -20, 0, 46), bad and Color3.fromRGB(220, 220, 220) or Color3.fromRGB(255, 230, 90), { Position = UDim2.fromOffset(10, 8), ZIndex = 32, Parent = card })
	-- confetti for Epic and better
	if rc.order >= 4 then
		for c = 1, 24 + rc.order * 4 do
			local bit = K.new("Frame", { Size = UDim2.fromOffset(math.random(6, 12), math.random(10, 18)), Position = UDim2.new(math.random(), 0, 0, -20),
				BackgroundColor3 = Color3.fromHSV(math.random(), 0.7, 1), BorderSizePixel = 0, Rotation = math.random(0, 360), ZIndex = 29, Parent = HUD.Root })
			K.tween(bit, 1.6 + math.random() * 1.2, { Position = UDim2.new(bit.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 20), Rotation = math.random(-720, 720) },
				Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(3, function() bit:Destroy() end)
		end
	end
	local model = Renderer.BuildPreview(id)
	local vp = K.viewport(model, UDim2.fromOffset(220, 200), true)
	vp.Position = UDim2.new(0.5, -110, 0, 50)
	vp.ZIndex = 31
	vp.Parent = card
	K.label(def.name, UDim2.new(1, -20, 0, 34), Color3.new(1, 1, 1), { Position = UDim2.fromOffset(10, 252), ZIndex = 32, Parent = card })
	K.label(def.rarity .. "  •  +" .. Format.Money(CreatureData.Income(id)) .. "/s", UDim2.new(1, -20, 0, 26), rc.color:Lerp(Color3.new(1, 1, 1), 0.2),
		{ Position = UDim2.fromOffset(10, 286), ZIndex = 32, Parent = card })
	K.label("Added to your pets!", UDim2.new(1, -20, 0, 20), Color3.fromRGB(200, 255, 200), { Position = UDim2.fromOffset(10, 314), ZIndex = 32, Parent = card })
	K.tween(sc, 0.45, { Scale = targetScale }, Enum.EasingStyle.Back)
	if bad then Sounds.Play("Click", 0.8) else Sounds.Play("Rare", 1.4 - rc.order * 0.06) end
	local spin = RunService.RenderStepped:Connect(function()
		glow.Rotation = (os.clock() * 60) % 360
		if glow2 then glow2.Rotation = -(os.clock() * 40) % 360 end
		card.Rotation = math.sin(os.clock() * 3) * (1 + rc.order * 0.3)
	end)
	task.delay(1.9, function()
		local pets = HUD.SideButtons["Pets"]
		if pets and card.Parent then
			local s = math.max(card.AbsoluteSize.X / (W * math.max(sc.Scale, 0.01)), 0.01)
			local target = (pets.AbsolutePosition + pets.AbsoluteSize / 2 - HUD.Root.AbsolutePosition) / s
			K.tween(card, 0.5, { Position = UDim2.fromOffset(target.X, target.Y), Rotation = -20 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			K.tween(sc, 0.5, { Scale = 0.08 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.5, function()
				spin:Disconnect()
				card:Destroy()
				K.pop(pets, 1.35)
				Sounds.Play("Collect", 1.3)
			end)
		else
			spin:Disconnect()
			card:Destroy()
		end
	end)
end

Remotes.Deposit.OnClientEvent:Connect(function(ids)
	for i, id in ipairs(ids) do
		-- wait for the capture animation to finish, then show the card
		local def = CreatureData.ById[id]
		local cfg = def and Renderer.CatchConfig[def.rarity] or Renderer.CatchConfig.Common
		task.delay(cfg.dur + 0.15 + (i - 1) * 2.6, caughtCard, id)
	end
end)

---------------------------------------------------------------- per-world lighting + guide beam to base
local guideBeam, guideA0, guideA1
local function ensureGuide()
	if guideBeam then return end
	guideA1 = Instance.new("Attachment")
	guideA1.Parent = workspace.Terrain
	guideBeam = Instance.new("Beam")
	guideBeam.Attachment1 = guideA1
	guideBeam.Color = ColorSequence.new(Color3.fromRGB(150, 255, 160), Color3.fromRGB(120, 200, 255))
	guideBeam.LightEmission = 1
	guideBeam.Width0, guideBeam.Width1 = 1.2, 3
	guideBeam.FaceCamera = true
	guideBeam.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	guideBeam.TextureMode = Enum.TextureMode.Static
	guideBeam.TextureLength = 4
	guideBeam.TextureSpeed = 2
	guideBeam.Transparency = NumberSequence.new(0.2, 0.6)
	guideBeam.CurveSize0 = 20
	guideBeam.Parent = workspace.Terrain
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.2 then return end
	acc = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	-- lighting/ambience follow the CAMERA, so the follow-cam shows each zone's mood
	Effects.UpdateWorld(workspace.CurrentCamera.CFrame.Position)
	HUD.SetInZone(Config.InThrowZone(root.Position))
	-- touching the limit: wall flashes and the "throw from here" animation plays
	if root.Position.Z > Config.BarrierZ - 2.6 and root.Position.Z < Config.BarrierZ + 3 and os.clock() - lastBarrierFx > 1.5 then
		lastBarrierFx = os.clock()
		barrierPulse(root.Position)
		HUD.ShowThrowHere()
	end
	-- standing in YOUR OWN gym?
	local inGym = false
	local idx = player:GetAttribute("BaseIndex")
	local myBase = idx and workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. idx)
	local gymPad = myBase and myBase:FindFirstChild("GymPad")
	if gymPad then
		inGym = ((root.Position - gymPad.Position) * Vector3.new(1, 0, 1)).Magnitude < Config.TrainRange
	end
	local level = inGym and math.clamp(State.Data.EquipLevel or 1, 1, #Config.TrainingStations) or nil
	local nextSt = level and Config.TrainingStations[level + 1]
	local canBuy = nextSt and (State.Data.Money or 0) >= nextSt.price
	if level ~= HUD._shownGym or canBuy ~= HUD._shownCanBuy then
		HUD._shownGym, HUD._shownCanBuy = level, canBuy
		HUD.SetGym(level)
	end
	-- creatures are caught automatically now, so the manual collect button stays hidden
	HUD.SetCollectable(nil)
	-- show a sparkly guide beam to your base while carrying creatures
	local carrying = #(State.Data.Carry or {}) > 0
	local idx = player:GetAttribute("BaseIndex")
	local base = idx and workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild("Base" .. idx)
	if carrying and base then
		ensureGuide()
		if not guideA0 or guideA0.Parent ~= root then
			guideA0 = Instance.new("Attachment")
			guideA0.Position = Vector3.new(0, -2, 0)
			guideA0.Parent = root
			guideBeam.Attachment0 = guideA0
		end
		guideA1.WorldPosition = base.Center.Position + Vector3.new(0, 2, 0)
		guideBeam.Enabled = true
	elseif guideBeam then
		guideBeam.Enabled = false
	end
end)

-- welcome
task.delay(3, function()
	HUD.Notify("Welcome to Throw Portals For Creatures! Hold to charge, release to throw!", "info")
end)
