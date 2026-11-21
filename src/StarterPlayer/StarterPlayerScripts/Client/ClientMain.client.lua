-- ClientMain: wires all client modules together.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ClientMain (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureData = require(Shared.CreatureData)
local Config = require(Shared.Config)
local Format = require(Shared.Format)
local Timeline = require(Shared.PresentationTimeline)

local Client = script.Parent
local State = require(Client.ClientState)
local Effects = require(Client.Effects)
local Sounds = require(Client.Sounds)
local Renderer = require(Client.CreatureRenderer)
local TC = require(Client.ThrowController)
local HUD = require(Client.HUD)
local Feel = require(Client.GameplayFeel)
local Panels = require(Client.Panels)

local player = Players.LocalPlayer
local Remotes = State.Remotes

Effects.SetupLighting()
Renderer.Start()
local WorldFx = require(Client.WorldFx)
WorldFx.TC = TC
task.spawn(function()
	workspace:WaitForChild("Map", 60)
	WorldFx.Start()
end)
Panels.Init()
HUD.TC = TC
TC.OnThrowResult = HUD.ThrowFeedback
HUD.Refresh()
Feel.Start(TC, HUD)

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
	if collecting[throwId] then
		return
	end
	collecting[throwId] = true
	local ok, msg = State.Request("Collect", throwId)
	collecting[throwId] = nil
	if not ok then
		HUD.Notify(msg or "Can't collect", "error")
	end
end

HUD.OnCollect = Renderer.OnCollectRequest

---------------------------------------------------------------- the limit: barrier + "throw from here"
local function barrierPulse(pos)
	local map = workspace:FindFirstChild("Map")
	local wall = map and map:FindFirstChild("Start") and map.Start:FindFirstChild("Barrier")
	if wall then
		wall.Transparency = 0.94
		Effects.Tween(wall, 0.4, { Transparency = 1 })
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

TC.OnBusy = function(message)
	HUD.Notify(message or "Your portal is active. Wait for the catch.", "info")
end
TC.OnLaunchFailed = function(message)
	HUD.Notify(message, "error")
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
local LIFT_ANIM =
	{ [Enum.HumanoidRigType.R15] = "rbxassetid://507770677", [Enum.HumanoidRigType.R6] = "rbxassetid://129423030" }
local liftTrack, liftHum, lastLift = nil, nil, 0
local function playLift()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if hum ~= liftHum then
		liftHum = hum
		liftTrack = nil
		local animator = hum:FindFirstChildOfClass("Animator") or hum
		local anim = Instance.new("Animation")
		anim.AnimationId = LIFT_ANIM[hum.RigType] or LIFT_ANIM[Enum.HumanoidRigType.R15]
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			liftTrack = track
		end
	end
	lastLift = os.clock()
	if liftTrack and not liftTrack.IsPlaying then
		liftTrack:Play(0.15, 1, 1.7)
	end
end
RunService.Heartbeat:Connect(function()
	if liftTrack and liftTrack.IsPlaying and os.clock() - lastLift > 0.7 then
		liftTrack:Stop(0.25)
	end
end)

local lastRep = 0
local function doRep()
	local idx = HUD.TrainStation
	if not idx or os.clock() - lastRep < Config.TrainCooldown then
		return
	end
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
				Effects.FloatingText(
					root.Position + Vector3.new(math.random(-2, 2), 4, 0),
					"+" .. Format.Short(st.gain) .. " 💪",
					Color3.fromRGB(255, 150, 120),
					0.8
				)
			end
		elseif msg then
			HUD.Notify(msg, "error")
		end
	end)
end
RunService.Heartbeat:Connect(function()
	if HUD.TrainStation and (HUD.TrainHeld or HUD.AutoTrain) then
		doRep()
	end
end)
game:GetService("UserInputService").InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.E and HUD.TrainStation then
		doRep()
	end
end)

---------------------------------------------------------------- server messages
Remotes.Notify.OnClientEvent:Connect(function(text, kind)
	if kind == "throwzone" then
		HUD.ShowThrowHere("🎯 GO TO THE THROW LINE!", nil)
		return
	end
	-- The owner's reveal caption already announces this find. Keep broadcasts for other players.
	local ownReveal = Config.Rarities[kind]
		and text:sub(1, #player.DisplayName + 9) == player.DisplayName .. " found a "
	if not ownReveal then
		HUD.Notify(text, kind)
	end
	if kind == "discover" then
		Sounds.Play("Upgrade", 1.1)
	end
end)

Remotes.MoneyFx.OnClientEvent:Connect(Feel.Money)

-- "CAUGHT!" card: pops up with the spinning creature, then flies into the Pets button
local caughtCard = require(Client.CaughtPresentation)

-- Card queue: a card is shown only for a CONFIRMED deposit, after its capture presentation
-- finished (Renderer.CaptureFinished) or a bounded fallback timeout — one card per deposit.
local cardQueue, cardBusy = {}, false
local pendingCards = {} -- deposits waiting for their capture visual: { id, deadline }
local recentCaptures = {} -- captures that finished before the deposit arrived: { id, t }
local function pumpCards()
	if cardBusy or #cardQueue == 0 then
		return
	end
	cardBusy = true
	local id = table.remove(cardQueue, 1)
	task.spawn(function()
		pcall(caughtCard, id)
		task.wait(Timeline.CardTotal())
		cardBusy = false
		pumpCards()
	end)
end
local function enqueueCard(id)
	table.insert(cardQueue, id)
	pumpCards()
end
Renderer.CaptureFinished.Event:Connect(function(_throwId, ownerId, creatureId)
	if ownerId ~= player.UserId then
		return
	end
	for i, pc in ipairs(pendingCards) do
		if pc.id == creatureId then
			table.remove(pendingCards, i)
			enqueueCard(creatureId)
			return
		end
	end
	table.insert(recentCaptures, { id = creatureId, t = os.clock() })
end)
Remotes.Deposit.OnClientEvent:Connect(function(ids)
	for _, id in ipairs(ids) do
		if CreatureData.ById[id] then
			local matched = false
			for i, rc in ipairs(recentCaptures) do
				if rc.id == id and os.clock() - rc.t < 6 then
					table.remove(recentCaptures, i)
					matched = true
					break
				end
			end
			if matched then
				enqueueCard(id)
			else
				table.insert(pendingCards, {
					id = id,
					deadline = os.clock() + Timeline.CardFallback + Timeline.CaptureFor(CreatureData.ById[id].rarity),
				})
			end
		end
	end
end)
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for i = #pendingCards, 1, -1 do
		if now > pendingCards[i].deadline then
			enqueueCard(table.remove(pendingCards, i).id)
		end
	end
end)

---------------------------------------------------------------- per-world lighting + guide beam to base
local guideBeam, guideA0, guideA1
local function ensureGuide()
	if guideBeam then
		return
	end
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
	if acc < 0.2 then
		return
	end
	acc = 0
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	-- lighting/ambience follow the CAMERA, so the follow-cam shows each zone's mood
	Effects.UpdateWorld(workspace.CurrentCamera.CFrame.Position)
	HUD.SetInZone(Config.InThrowZone(root.Position))
	-- touching the limit: wall flashes and the "throw from here" animation plays
	if
		root.Position.Z > Config.BarrierZ - 2.6
		and root.Position.Z < Config.BarrierZ + 3
		and os.clock() - lastBarrierFx > 1.5
	then
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
	local carryBaseIndex = player:GetAttribute("BaseIndex")
	local base = carryBaseIndex
		and workspace:FindFirstChild("Bases")
		and workspace.Bases:FindFirstChild("Base" .. carryBaseIndex)
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

-- First-throw guidance is context driven by GameplayFeel, without a recurring welcome toast.
