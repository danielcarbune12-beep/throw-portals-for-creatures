-- ThrowController: charge meter input, held-portal + arm wind-up, the portal flight arc,
-- landing bounce, portal gate opening and creature reveal choreography (for ALL players' throws).
-- Location: StarterPlayer > StarterPlayerScripts > Client > ThrowController (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local CreatureData = require(Shared.CreatureData)
local PortalBuilder = require(Shared.PortalBuilder)
local Odds = require(Shared.Odds)
local State = require(script.Parent.ClientState)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)
local Renderer = require(script.Parent.CreatureRenderer)

local TC = {}
TC.Charging = false
TC.Power = 0
TC.OnThrowResult = nil   -- callback(power, perfect) for UI feedback
TC.MyThrow, TC.MyThrowT = nil, 0  -- your portal currently in play (one at a time)
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = State.Remotes

local chargeStart = 0
local lastThrow = 0
local heldOrb, heldRefs
local chargeSound
local throws = {} -- [id] = { gate, gateRefs, pos, portal }

---------------------------------------------------------------- arm pose (local)
local shoulder, shoulderC0, armBlend, armTarget = nil, nil, 0, 0
local armDisabled = false
local function findShoulder()
	local char = player.Character
	if not char then return end
	local m = (char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder"))
		or (char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder"))
	if m and not m:IsA("Motor6D") then m = nil end
	if m ~= shoulder then
		shoulder = m
		shoulderC0 = m and m.C0
	end
end

local function handCFrame()
	local char = player.Character
	if not char then return nil end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	return hand and hand.CFrame
end

---------------------------------------------------------------- charging
function TC.BeginCharge()
	if TC.Charging or not State.Loaded then return end
	if os.clock() - lastThrow < Config.ThrowCooldown then return end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	if not Config.InThrowZone(char.HumanoidRootPart.Position) then
		if TC.OnNotInZone then TC.OnNotInZone() end
		return
	end
	-- one portal at a time: wait until your last creature has been caught
	if TC.MyThrow and os.clock() - TC.MyThrowT < 20 then
		if TC.OnBusy then TC.OnBusy() end
		return
	end
	TC.Charging = true
	chargeStart = os.clock()
	findShoulder()
	armTarget = 1
	heldOrb, heldRefs = PortalBuilder.BuildOrb(State.Data.EquippedPortal, 0.5)
	heldOrb.Parent = Effects.Folder
	chargeSound = Sounds.Play("Charge")
end

function TC.EndCharge()
	if not TC.Charging then return end
	TC.Charging = false
	if chargeSound then chargeSound:Stop() end
	local power = TC.Power
	lastThrow = os.clock()
	local look = camera.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.1 then dir = Vector3.new(0, 0, -1) end
	dir = dir.Unit
	local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if hrp then hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir) end
	Remotes.Throw:FireServer(power, dir)
	-- swing the arm forward
	armTarget = -0.6
	task.delay(0.18, function() armTarget = 0 end)
	if heldOrb then heldOrb:Destroy(); heldOrb = nil end
	Sounds.Play("Throw", 0.9 + power * 0.3)
	local perfect = power >= 0.92
	if TC.OnThrowResult then TC.OnThrowResult(power, perfect) end
	if perfect then Effects.Shake(0.8, 0.2) end
end

-- Power ping-pongs so timing matters; the top 8% is the PERFECT zone
local PERIOD = 1.5
RunService.RenderStepped:Connect(function(dt)
	if TC.Charging then
		local t = (os.clock() - chargeStart) / (PERIOD / 2)
		local k = t % 2
		local p = k <= 1 and k or 2 - k
		TC.Power = 1 - (1 - p) ^ 1.6 -- eases toward the top so the perfect zone is catchable
		if chargeSound then chargeSound.PlaybackSpeed = 0.5 + TC.Power * 1.2 end
		local hcf = handCFrame()
		if heldOrb and hcf then
			local s = 0.6 + TC.Power * 0.6
			heldOrb:PivotTo(hcf * CFrame.new(0, -1.2, 0))
			heldRefs.core.Size = Vector3.new(0.8, 0.8, 0.8) * s
			heldRefs.light.Range = 6 + TC.Power * 10
			PortalBuilder.Spin(heldRefs, os.clock() * (1 + TC.Power * 3))
		end
	else
		TC.Power = math.max(0, TC.Power - dt * 3)
	end
	-- arm wind-up spring (skipped on avatars whose shoulder joint can't be edited)
	if shoulder and shoulder.Parent and not armDisabled then
		armBlend += (armTarget - armBlend) * (1 - math.exp(-18 * dt))
		if math.abs(armBlend) > 0.002 or math.abs(armTarget) > 0 then
			local isR15 = shoulder.Name == "RightShoulder"
			local rot = isR15 and CFrame.Angles(armBlend * 2.6, 0, armBlend * -0.3) or CFrame.Angles(0, 0, armBlend * 2.6)
			local ok = pcall(function() shoulder.C0 = shoulderC0 * rot end)
			if not ok then armDisabled = true end
		end
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		TC.BeginCharge()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonR2 then
		TC.EndCharge()
	end
end)
player.CharacterAdded:Connect(function()
	shoulder = nil
	TC.Charging = false
	if heldOrb then heldOrb:Destroy(); heldOrb = nil end
end)

-- quick arm curl used by the training stations
function TC.Curl()
	findShoulder()
	armTarget = 0.9
	task.delay(0.15, function() if not TC.Charging then armTarget = 0 end end)
end

---------------------------------------------------------------- camera follows your long throws
local camFollow = nil -- { pos = Vector3, untilT = number, cf = CFrame }
RunService:BindToRenderStep("TPFC_FollowCam", Enum.RenderPriority.Camera.Value, function(dt)
	if not camFollow then return end
	if os.clock() > camFollow.untilT then
		if camFollow.closeup then TC.EndCloseup() end
		camFollow = nil
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	local target = camFollow.pos
	local desired = CFrame.lookAt(target + Vector3.new(14, 12, -34), target + Vector3.new(0, 2, 0))
	if camFollow.closeup then
		-- CINEMATIC CLOSE-UP: slow orbit around the creature, pushing in
		local e = Renderer.Wild[camFollow.id]
		local p
		if e and e.anim and e.model and e.model.Parent then
			p = Vector3.new(e.anim.pos.X, e.anim.groundY, e.anim.pos.Z)
			camFollow.lastP = p
		else
			p = camFollow.lastP or camFollow.pos
		end
		local t = os.clock() - camFollow.closeT
		local h = camFollow.height
		local look = p + Vector3.new(0, h * 0.55, 0)
		local a = -0.7 + t * 0.32
		local R = camFollow.radius * (1.35 - 0.35 * math.min(1, t / 1.5))
		desired = CFrame.lookAt(look + Vector3.new(math.sin(a) * R, h * 0.25 + 1.5, -math.cos(a) * R), look)
		if Effects.DOF then Effects.DOF.FocusDistance = R end
	end
	camFollow.cf = camFollow.cf and camFollow.cf:Lerp(desired, 1 - math.exp(-5 * dt)) or camera.CFrame:Lerp(desired, 0.2)
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camFollow.cf
end)
function TC.StopFollow()
	if camFollow then camFollow.untilT = 0 end
end

-- start a cinematic zoom on a good creature you just found
function TC.StartCloseup(id, def, pos, duration)
	local rc = Config.Rarities[def.rarity]
	local size = rc.size * (def.scale or 1)
	camFollow = camFollow or { pos = pos, untilT = 0 }
	camFollow.id = id
	camFollow.pos = pos
	camFollow.closeup = true
	camFollow.closeT = os.clock()
	camFollow.height = 4 * size
	camFollow.radius = (7 + rc.order * 0.8) * size
	camFollow.untilT = os.clock() + duration
	Effects.Letterbox(true)
	Effects.Tween(camera, 0.7, { FieldOfView = 48 }, Enum.EasingStyle.Quad)
	if Effects.DOF then
		Effects.DOF.InFocusRadius = 12
		Effects.Tween(Effects.DOF, 0.6, { FarIntensity = 0.45 })
	end
end

function TC.EndCloseup()
	Effects.Letterbox(false)
	Effects.Tween(camera, 0.6, { FieldOfView = 70 }, Enum.EasingStyle.Quad)
	if Effects.DOF then
		Effects.Tween(Effects.DOF, 0.6, { FarIntensity = 0.18 })
		Effects.DOF.InFocusRadius = 70
		Effects.DOF.FocusDistance = 50
	end
end

---------------------------------------------------------------- flight + landing + gate
local function bezier(a, b, c, t)
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

local function openGate(id, info)
	local pos = info.to
	local camPos = camera.CFrame.Position
	local R = 5
	local gate, refs = PortalBuilder.BuildGate(info.portal, R)
	local center = pos + Vector3.new(0, R + 0.6, 0)
	-- the portal always faces back toward the throw line, so the creature walks out toward you
	local baseCF = CFrame.lookAt(center, center + Vector3.new(0, 0, -1))
	gate:PivotTo(baseCF)
	gate:ScaleTo(0.05)
	gate.Parent = Effects.Folder
	throws[id] = { gate = gate, refs = refs, pos = pos, portal = info.portal, t0 = os.clock() }
	local P = Config.Portals[info.portal]
	Effects.Shockwave(pos, P.color, 10, 0.5)
	Effects.Burst(center, PortalBuilder.ColorSeq(info.portal), 45, 22, 1.1)
	Sounds.PlayAt("Open", center, 1)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not gate.Parent then conn:Disconnect() return end
		local t = os.clock() - start
		local k = math.clamp(t / 0.45, 0, 1)
		-- back-out ease for a punchy open
		local c1 = 2.2
		local e = 1 + (c1 + 1) * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
		local closing = throws[id] and throws[id].closeT
		if closing then
			local ck = math.clamp((os.clock() - closing) / 0.35, 0, 1)
			e = (1 - ck * ck)
			if ck >= 1 then gate:Destroy(); conn:Disconnect(); return end
		end
		gate:ScaleTo(math.max(0.05, e))
		gate:PivotTo(baseCF * CFrame.new(0, math.sin(t * 2) * 0.15, 0))
		PortalBuilder.Spin(refs, t)
	end)
end

local function closeGate(id)
	local g = throws[id]
	if not g or g.closeT then return end
	g.closeT = os.clock()
	Effects.Burst(g.pos + Vector3.new(0, 3.5, 0), PortalBuilder.ColorSeq(g.portal), 20, 10, 0.6)
	task.delay(0.5, function() throws[id] = nil end)
end

Remotes.PortalThrown.OnClientEvent:Connect(function(info)
	local orb, refs = PortalBuilder.BuildOrb(info.portal, 0.75)
	local a, c = info.from, info.to + Vector3.new(0, 0.9, 0)
	local mid = (a + c) / 2 + Vector3.new(0, math.min(10 + info.dist * 0.3, 220), 0)
	orb:PivotTo(CFrame.new(a))
	orb.Parent = Effects.Folder
	refs.trail.Enabled = true
	local mine = info.owner == player.UserId
	if mine then TC.MyThrow, TC.MyThrowT = info.id, os.clock() end
	local follow = mine and info.dist > 70
	if follow then
		camFollow = { pos = a, untilT = os.clock() + info.t + 8, id = info.id }
	end
	if not mine then Sounds.PlayAt("Whoosh", a) end
	local start = os.clock()
	local landed = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - start
		if t < info.t then
			local k = t / info.t
			local ek = k < 0.5 and k * 1.1 or 0.55 + (k - 0.5) * 0.9 -- slight hang time at the apex
			local p = bezier(a, mid, c, math.clamp(ek, 0, 1))
			orb:PivotTo(CFrame.new(p) * CFrame.Angles(t * 9, t * 6, 0))
			if follow and camFollow and camFollow.id == info.id then camFollow.pos = p end
			PortalBuilder.Spin(refs, t * 2)
		else
			if not landed then
				landed = true
				Sounds.PlayAt("Land", c)
				Effects.Burst(c - Vector3.new(0, 0.6, 0), ColorSequence.new(Color3.fromRGB(230, 220, 200)), 18, 10, 1.2, "rbxasset://textures/particles/smoke_main.dds")
				Effects.Shockwave(c - Vector3.new(0, 0.8, 0), Config.Portals[info.portal].color, 6, 0.4)
				if mine then Effects.Shake(0.5, 0.15) end
				refs.trail.Enabled = false
			end
			-- two decaying bounces, then a charged-up wobble before it bursts open
			local bt = t - info.t
			local bounce = 0
			if bt < 0.22 then bounce = math.sin(bt / 0.22 * math.pi) * 1.6
			elseif bt < 0.36 then bounce = math.sin((bt - 0.22) / 0.14 * math.pi) * 0.5 end
			local wobble = bt > 0.36 and math.sin(bt * 40) * (bt - 0.36) * 0.6 or 0
			orb:PivotTo(CFrame.new(c + Vector3.new(0, bounce, 0)) * CFrame.Angles(wobble, bt * 12, wobble * 0.5))
			refs.light.Brightness = 2 + bt * 8
			if bt > 0.5 then
				conn:Disconnect()
				orb:Destroy()
				openGate(info.id, info)
			end
		end
	end)
end)

Remotes.PortalOpened.OnClientEvent:Connect(function(info)
	local def = CreatureData.ById[info.creature]
	local rc = Config.Rarities[def.rarity]
	local mine = info.owner == player.UserId
	local chanceText = Odds.OneIn(info.chance)
	local center = info.pos + Vector3.new(0, 3.8, 0)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = myRoot and (myRoot.Position - info.pos).Magnitude < 250
	local camNear = (camera.CFrame.Position - info.pos).Magnitude < 300
	if not near and not mine and not camNear then return end

	-- special entrances for Legendary and above
	if rc.order >= 5 then
		Effects.LightBeam(info.pos, rc.color, rc.order >= 7 and 200 or 120, 1.8)
		Effects.Shockwave(info.pos, rc.color, 22 + rc.order * 2, 0.9)
		if mine then
			Effects.Shake(rc.order >= 7 and 2.2 or 1.4, 0.6)
			Effects.Flash(def.rarity == "Secret" and Color3.fromRGB(20, 0, 40) or rc.color, 0.8, 0.55)
			Sounds.Play("Rare")
			Effects.RarityBanner(def, chanceText)
		end
		if def.rarity == "Secret" then
			Effects.Burst(center, ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170)), 90, 30, 1.4)
		elseif def.rarity == "Divine" then
			Effects.Burst(center, ColorSequence.new(Color3.fromRGB(255, 245, 190), Color3.new(1, 1, 1)), 120, 35, 1.6)
		end
	elseif mine then
		Effects.RarityBanner(def, chanceText)
	end
	Effects.Burst(center, rc.color, 30 + rc.order * 8, 16 + rc.order * 2, 1)
	Sounds.PlayAt("Spawn", center, 1.2 - rc.order * 0.05)
	local e = Renderer.SpawnWild(info.id, info.creature, info.pos, info.owner, chanceText)
	if e then
		-- after stepping out of the portal: a happy hop
		task.delay(1.9, function() if e.anim and e.anim.rig then e.anim:React("happy") end end)
	end
	if mine then
		Effects.FloatingText(center + Vector3.new(0, 5, 0), chanceText, rc.color, 1.3)
		if rc.order >= 3 then
			-- a GOOD pet: zoom in on it and keep watching through its entrance and capture
			local catchDur = (Renderer.CatchConfig[def.rarity] or Renderer.CatchConfig.Common).dur
			TC.StartCloseup(info.id, def, info.pos, (Config.CatchDelay[def.rarity] or 3) + catchDur + 0.5)
		elseif camFollow and camFollow.id == info.id then
			camFollow.pos = info.pos
			camFollow.untilT = os.clock() + 2.5
		end
	end
	task.delay(rc.order >= 5 and 3 or 2.3, function() closeGate(info.id) end)
end)

Remotes.CreatureGone.OnClientEvent:Connect(function(id, reason, collectorId)
	if TC.MyThrow == id then TC.MyThrow = nil end
	Renderer.RemoveWild(id, reason, collectorId)
	if reason == "collected" and collectorId == player.UserId then
		Sounds.Play("Collect")
		task.delay(0.3, Sounds.Play, "Rare", 1.5)
	end
	closeGate(id)
end)

return TC
