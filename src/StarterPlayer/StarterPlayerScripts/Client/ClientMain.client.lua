-- ClientMain: wires all client modules together.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ClientMain (LocalScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CreatureData = require(Shared.CreatureData)
local Config = require(Shared.Config)
local Timeline = require(Shared.PresentationTimeline)
local Variants = require(Shared.Variants)

local Client = script.Parent
local State = require(Client.ClientState)
local Effects = require(Client.Effects)
local Sounds = require(Client.Sounds)
local HUD = require(Client.HUD)
-- cover the screen first (portal + title), before the heavy renderer/throw modules load, so the
-- intro starts the instant you join; the arrival flight starts once your courtyard is ready
pcall(function()
	require(Client.Intro).Cover(HUD.Gui)
end)
local Renderer = require(Client.CreatureRenderer)
local TC = require(Client.ThrowController)
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
require(Client.ExpeditionPanel).Init()
require(Client.ForgePanel).Init()
require(Client.FarmMarketPanel).Init()
require(Client.KnightGuide).Init()

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

-- Pet missions replace the old lift controls and held-weight animation.
HUD.SetGym(nil)

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

-- Bestiary slips: confirmed discoveries and Rare+ only, never routine repeats.
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
	local receipt = table.remove(cardQueue, 1)
	task.spawn(function()
		pcall(caughtCard, receipt.key, receipt.discovery)
		task.wait(Timeline.CardTotal())
		cardBusy = false
		pumpCards()
	end)
end
local function enqueueCard(id, discovery)
	table.insert(cardQueue, { key = id, discovery = discovery })
	pumpCards()
end
Renderer.CaptureFinished.Event:Connect(function(_throwId, ownerId, creatureId)
	if ownerId ~= player.UserId then
		return
	end
	for i, pc in ipairs(pendingCards) do
		if pc.id == creatureId then
			table.remove(pendingCards, i)
			enqueueCard(pc.key or creatureId, pc.discovery)
			return
		end
	end
	table.insert(recentCaptures, { id = creatureId, t = os.clock() })
end)
Remotes.Deposit.OnClientEvent:Connect(function(ids, discoveries)
	for index, key in ipairs(ids) do
		-- "CreatureId" or "CreatureId|Size|Material": the card shows the full variant name
		local id = Variants.Parse(key)
		local discovery = discoveries and discoveries[index] == true
		if not discoveries then
			discovery = not (State.Data.Discovered or {})[id]
		end
		local def = CreatureData.ById[id]
		if def and Timeline.ShouldPresent(def.rarity, discovery) then
			local matched = false
			for i, rc in ipairs(recentCaptures) do
				if rc.id == id and os.clock() - rc.t < 6 then
					table.remove(recentCaptures, i)
					matched = true
					break
				end
			end
			if matched then
				enqueueCard(key, discovery)
			else
				table.insert(pendingCards, {
					id = id,
					key = key,
					discovery = discovery,
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
			local pc = table.remove(pendingCards, i)
			enqueueCard(pc.key or pc.id, pc.discovery)
		end
	end
	for i = #recentCaptures, 1, -1 do
		if now - recentCaptures[i].t > 6 then
			table.remove(recentCaptures, i)
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
	HUD.SetGym(nil)
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

-- Cinematic arrival; Sir Rowan owns tutorial navigation and instructions.
task.spawn(function()
	local ok, err = pcall(function()
		require(Client.Intro).Play(HUD.Gui)
	end)
	if not ok then
		warn("[Intro] " .. tostring(err))
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		HUD.Gui.Enabled = true
		Effects.Letterbox(false)
		local cover = player.PlayerGui:FindFirstChild("Intro")
		if cover then
			cover:Destroy()
		end
		local blur = game:GetService("Lighting"):FindFirstChild("TPFC_IntroBlur")
		if blur then
			blur:Destroy()
		end
		workspace:SetAttribute("TPFC_IntroPlaying", nil)
	end
end)
