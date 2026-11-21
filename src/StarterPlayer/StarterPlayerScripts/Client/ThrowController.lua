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
local Settings = require(script.Parent.ClientSettings)
local Builder = require(Shared.CreatureBuilder)
local Timeline = require(Shared.PresentationTimeline)

local TC = {}
TC.Charging = false
TC.Power = 0
TC.OnThrowResult = nil -- callback(power, perfect) for UI feedback
TC.MyThrow, TC.MyThrowT = nil, 0 -- your portal currently in play (one at a time)
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local Remotes = State.Remotes

local chargeStart = 0
local lastThrow = 0
local heldOrb, heldRefs
local chargeSound
local throws = {} -- [id] = { gate, gateRefs, pos, portal }
local finishedThrows = {} -- terminal events can arrive before a paused client finishes its arc

---------------------------------------------------------------- arm pose (local)
local shoulder, shoulderC0, armBlend, armTarget = nil, nil, 0, 0
local armDisabled = false
local function findShoulder()
	local char = player.Character
	if not char then
		return
	end
	local m = (char:FindFirstChild("RightUpperArm") and char.RightUpperArm:FindFirstChild("RightShoulder"))
		or (char:FindFirstChild("Torso") and char.Torso:FindFirstChild("Right Shoulder"))
	if m and not m:IsA("Motor6D") then
		m = nil
	end
	if m ~= shoulder then
		shoulder = m
		shoulderC0 = m and m.C0
	end
end

local function handCFrame()
	local char = player.Character
	if not char then
		return nil
	end
	local hand = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	return hand and hand.CFrame
end

---------------------------------------------------------------- charging and input ownership
TC.Submitting = false
TC.ChargeSource = nil
TC.Phase = "Ready"
TC.OnLaunchFailed = nil
local submissionSerial = 0

function TC.CancelCharge(_reason)
	local wasCharging = TC.Charging
	TC.Charging, TC.ChargeSource, TC.Power = false, nil, 0
	armTarget = 0
	if heldOrb then
		heldOrb:Destroy()
		heldOrb = nil
	end
	heldRefs = nil
	if chargeSound then
		Sounds.StopLoop("Charge", 0.08)
		chargeSound = nil
	end
	if wasCharging then
		TC.Phase = "Ready"
	end
	return wasCharging
end

function TC.BeginCharge(source)
	if TC.InputBlocked or TC.SystemMenuOpen or TC.Charging or not State.Loaded then
		return false
	end
	if TC.Submitting or TC.MyThrow then
		if TC.OnBusy then
			TC.OnBusy(
				TC.Submitting and "Confirming your launch..."
					or "Your portal is active. The creature will be caught automatically."
			)
		end
		return false
	end
	if os.clock() - lastThrow < Config.ThrowCooldown then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		return false
	end
	if not Config.InThrowZone(hrp.Position) then
		if TC.OnNotInZone then
			TC.OnNotInZone()
		end
		return false
	end
	local d = State.Data
	if #d.Creatures >= (d.SlotsOpen or 0) + (d.StorageCap or 0) then
		if TC.OnLaunchFailed then
			TC.OnLaunchFailed("Your garden and storage are full. Open Menu > Pets to make room.")
		end
		return false
	end
	if TC.StopFollow then
		TC.StopFollow(true)
	end
	TC.Charging, TC.Power, TC.ChargeSource, TC.Phase = true, 0, source or "Programmatic", "Charging"
	chargeStart = os.clock()
	findShoulder()
	armTarget = 1
	heldOrb, heldRefs = PortalBuilder.BuildOrb(d.EquippedPortal, 0.5)
	heldOrb.Parent = Effects.Folder
	chargeSound = Sounds.Play("Charge")
	return true
end

function TC.EndCharge(source)
	if not TC.Charging or (source and source ~= TC.ChargeSource) then
		return false
	end
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 or not Config.InThrowZone(hrp.Position) or TC.InputBlocked then
		TC.CancelCharge("invalid release")
		return false
	end
	local power = TC.Power
	TC.CancelCharge("released")
	TC.Submitting, TC.Phase = true, "Submitting"
	submissionSerial += 1
	local serial = submissionSerial
	lastThrow = os.clock()
	camera = workspace.CurrentCamera or camera
	local look = camera.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	if dir.Magnitude < 0.1 or dir.Z < 0.2 then
		dir = Vector3.new(math.clamp(dir.X, -0.5, 0.5), 0, 1)
	end
	dir = dir.Unit
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)
	Remotes.Throw:FireServer(power, dir)
	armTarget = -0.45
	task.delay(0.16, function()
		if not TC.Charging then
			armTarget = 0
		end
	end)
	Sounds.Play("Throw", 0.95 + power * 0.18)
	local perfect = power >= 0.92
	if TC.OnThrowResult then
		TC.OnThrowResult(power, perfect)
	end
	if perfect then
		Effects.Shake(0.25, 0.12)
	end
	task.delay(4, function()
		if TC.Submitting and submissionSerial == serial then
			TC.Submitting, TC.Phase = false, "Ready"
			if TC.OnLaunchFailed then
				TC.OnLaunchFailed("The launch was not confirmed. Try again.")
			end
		end
	end)
	return true
end

Remotes.Notify.OnClientEvent:Connect(function(_text, kind)
	if TC.Submitting and (kind == "error" or kind == "throwzone") then
		TC.Submitting, TC.Phase = false, "Ready"
		submissionSerial += 1
	end
end)

-- Power ping-pongs so timing matters; the top 8% is the PERFECT zone
local PERIOD = 1.5
local perfectCueAt = -10
RunService.RenderStepped:Connect(function(dt)
	if TC.Charging then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not Config.InThrowZone(root.Position) then
			TC.CancelCharge("left hall")
			return
		end
		local t = (os.clock() - chargeStart) / (PERIOD / 2)
		local k = t % 2
		local p = k <= 1 and k or 2 - k
		TC.Power = 1 - (1 - p) ^ 1.6 -- eases toward the top so the perfect zone is catchable
		if chargeSound then
			chargeSound.PlaybackSpeed = 0.65 + TC.Power * 0.65
		end
		if TC.Power >= 0.92 and os.clock() - perfectCueAt > 0.9 then
			perfectCueAt = os.clock()
			Sounds.Play("Perfect")
		end
		local hcf = handCFrame()
		if heldOrb and hcf then
			local s = 0.6 + TC.Power * 0.6
			heldOrb:PivotTo(hcf * CFrame.new(0, -1.2, 0))
			heldOrb:ScaleTo(s)
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
			local rot = isR15 and CFrame.Angles(armBlend * 1.5, 0, armBlend * -0.15)
				or CFrame.Angles(0, 0, armBlend * 1.5)
			local ok = pcall(function()
				shoulder.C0 = shoulderC0 * rot
			end)
			if not ok then
				armDisabled = true
			end
		end
	end
end)

local function inputSource(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return "Pointer"
	end
	if input.KeyCode == Enum.KeyCode.F then
		return "Keyboard"
	end
	if input.KeyCode == Enum.KeyCode.ButtonR2 then
		return "Gamepad"
	end
	return nil
end
UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.ButtonB then
		TC.CancelCharge("cancel")
		return
	end
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	local source = inputSource(input)
	if source then
		TC.BeginCharge(source)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	local source = inputSource(input)
	if source then
		TC.EndCharge(source)
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	TC.CancelCharge("focus lost")
end)
UserInputService.TextBoxFocused:Connect(function()
	TC.CancelCharge("typing")
end)
game:GetService("GuiService").MenuOpened:Connect(function()
	TC.SystemMenuOpen = true
	TC.CancelCharge("Roblox menu")
	if TC.StopFollow then
		TC.StopFollow(true)
	end
end)
game:GetService("GuiService").MenuClosed:Connect(function()
	TC.SystemMenuOpen = false
end)
player.CharacterRemoving:Connect(function()
	TC.CancelCharge("respawn")
	TC.Submitting = false
	submissionSerial += 1
	if TC.StopFollow then
		TC.StopFollow(true)
	end
end)
player.CharacterAdded:Connect(function()
	TC.CancelCharge("new character")
	shoulder, shoulderC0, armDisabled, armBlend, armTarget = nil, nil, false, 0, 0
end)

-- quick arm curl used by the training stations
function TC.Curl()
	findShoulder()
	armTarget = 0.9
	task.delay(0.15, function()
		if not TC.Charging then
			armTarget = 0
		end
	end)
end

---------------------------------------------------------------- camera follows your long throws
-- One claim at a time. The previous camera state is saved and ALWAYS restored: on completion,
-- timeout, death/respawn, menu interruption or a newer claim.
local camFollow, camReturn = nil, nil
local idleFov = camera.FieldOfView
local ownsFov = false
local function restoreCamera(saved)
	if not saved then
		return
	end
	camera = workspace.CurrentCamera or camera
	camera.CameraType = saved.type == Enum.CameraType.Scriptable and Enum.CameraType.Custom or saved.type
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	camera.CameraSubject = (saved.subject and saved.subject.Parent) and saved.subject or hum
	camera.FieldOfView = saved.fov
	idleFov = saved.fov
	ownsFov = false
end
local function claimCamera(id, pos, duration)
	camera = workspace.CurrentCamera or camera
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local saved = camFollow and camFollow.saved
		or camReturn and camReturn.saved
		or {
			type = camera.CameraType,
			subject = camera.CameraSubject,
			fov = idleFov,
			offset = root and camera.CFrame.Position - root.Position or Vector3.new(0, 7, -16),
			rotation = camera.CFrame.Rotation,
		}
	camReturn = nil
	camFollow = {
		pos = pos,
		untilT = os.clock() + math.min(duration, Timeline.CameraTimeout),
		id = id,
		saved = saved,
		started = os.clock(),
	}
end
function TC.IsFollowing()
	return camFollow ~= nil or camReturn ~= nil
end
function TC.StopFollow(immediate)
	local active = camFollow or camReturn
	if not active then
		return
	end
	local saved = active.saved
	camFollow, camReturn = nil, nil
	if immediate or Settings.ReducedMotion then
		restoreCamera(saved)
		return
	end
	camReturn = { saved = saved, started = os.clock(), from = camera.CFrame, fov = camera.FieldOfView }
end
RunService:BindToRenderStep("TPFC_FollowCam", Enum.RenderPriority.Camera.Value, function(dt)
	camera = workspace.CurrentCamera or camera
	if camReturn then
		local r = camReturn
		local k = math.clamp((os.clock() - r.started) / 0.28, 0, 1)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			camReturn = nil
			restoreCamera(r.saved)
			return
		end
		local target = CFrame.new(root.Position + r.saved.offset) * r.saved.rotation
		local e = 1 - (1 - k) ^ 3
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = r.from:Lerp(target, e)
		camera.FieldOfView = r.fov + (r.saved.fov - r.fov) * e
		if k >= 1 then
			camReturn = nil
			restoreCamera(r.saved)
		end
		return
	end
	if not camFollow then
		if camera.CameraType ~= Enum.CameraType.Custom then
			return
		end
		if TC.Charging and not Settings.ReducedMotion then
			if not ownsFov then
				idleFov = camera.FieldOfView
				ownsFov = true
			end
			local target = idleFov - 3 * TC.Power
			camera.FieldOfView += (target - camera.FieldOfView) * (1 - math.exp(-10 * dt))
		elseif ownsFov then
			camera.FieldOfView += (idleFov - camera.FieldOfView) * (1 - math.exp(-12 * dt))
			if Settings.ReducedMotion or math.abs(camera.FieldOfView - idleFov) < 0.02 then
				camera.FieldOfView = idleFov
				ownsFov = false
			end
		else
			idleFov = camera.FieldOfView
		end
		return
	end
	if os.clock() > camFollow.untilT or os.clock() - camFollow.started > Timeline.CameraTimeout then
		TC.StopFollow()
		return
	end
	local target = camFollow.pos
	local wild = Renderer.Wild[camFollow.id]
	local dist, height = 34, 12
	if wild and wild.model and wild.model.Parent and wild.anim then
		local ok, cf, size = pcall(Builder.VisualBounds, wild.model)
		if ok and size.Magnitude > 0.5 and size.Magnitude < 80 then
			target = cf.Position
			dist = math.clamp(size.Magnitude * 2.2, 18, 46)
			height = math.clamp(size.Y * 0.8 + 4, 6, 16)
		end
	end
	local desired = CFrame.lookAt(target + Vector3.new(dist * 0.4, height, -dist), target)
	if Settings.ReducedMotion then
		camFollow.cf = camFollow.cf or desired
	else
		camFollow.cf = (camFollow.cf or camera.CFrame):Lerp(desired, 1 - math.exp(-6 * dt))
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camFollow.cf
end)
local function watchCharacter(char)
	TC.StopFollow(true)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			TC.CancelCharge("died")
			TC.StopFollow(true)
		end)
	end
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.defer(watchCharacter, player.Character)
end

---------------------------------------------------------------- flight + landing + gate
local function bezier(a, b, c, t)
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

local function openGate(id, info)
	if finishedThrows[id] then
		return
	end
	local pos = info.to
	local R = 5
	local gate, refs = PortalBuilder.BuildGate(info.portal, R)
	local center = pos + Vector3.new(0, R + 0.6, 0)
	-- the portal always faces back toward the throw line, so the creature walks out toward you
	local baseCF = CFrame.lookAt(center, center + Vector3.new(0, 0, -1))
	gate:PivotTo(baseCF)
	gate:ScaleTo(0.05)
	gate.Parent = Effects.Folder
	local record = { gate = gate, refs = refs, pos = pos, portal = info.portal, t0 = os.clock() }
	throws[id] = record
	local P = Config.Portals[info.portal]
	Effects.Shockwave(pos, P.color, 10, 0.5)
	Effects.Burst(center, PortalBuilder.ColorSeq(info.portal), Settings.LowVFX() and 6 or 22, 14, 0.65)
	Sounds.PlayAt("Open", center, 1)
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not gate.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		local k = math.clamp(t / Timeline.GateOpen, 0, 1)
		local e = 1 - (1 - k) ^ 4
		local closing = record.closeT
		if closing then
			local ck = math.clamp((os.clock() - closing) / Timeline.GateClose, 0, 1)
			e = (1 - ck * ck)
			if ck >= 1 then
				gate:Destroy()
				conn:Disconnect()
				return
			end
		end
		gate:ScaleTo(math.max(0.05, e))
		gate:PivotTo(CFrame.new(pos + Vector3.new(0, (R + 0.6) * math.max(0.05, e), 0)) * baseCF.Rotation)
		PortalBuilder.Spin(refs, t)
	end)
end

local function closeGate(id)
	local g = throws[id]
	if not g or g.closeT then
		return
	end
	g.closeT = os.clock()
	Effects.Burst(g.pos + Vector3.new(0, 3.5, 0), PortalBuilder.ColorSeq(g.portal), 20, 10, 0.6)
	task.delay(0.5, function()
		g.gate:Destroy()
		if throws[id] == g then
			throws[id] = nil
		end
	end)
end

local seenThrown, seenOpened = {}, {}
Remotes.PortalThrown.OnClientEvent:Connect(function(info)
	if seenThrown[info.id] or finishedThrows[info.id] then
		return
	end -- duplicate / late event: one flight per throw
	seenThrown[info.id] = true
	task.delay(Config.PendingLifetime + 10, function()
		seenThrown[info.id] = nil
		seenOpened[info.id] = nil
	end)
	local orb, refs = PortalBuilder.BuildOrb(info.portal, 0.75)
	local a, c = info.from, info.to + Vector3.new(0, 0.9, 0)
	local mid = (a + c) / 2 + Vector3.new(0, math.min(10 + info.dist * 0.3, 220), 0)
	orb:PivotTo(CFrame.new(a))
	orb.Parent = Effects.Folder
	refs.trail.Enabled = true
	local mine = info.owner == player.UserId
	if mine then
		TC.Submitting = false
		submissionSerial += 1
		TC.MyThrow, TC.MyThrowT, TC.Phase, TC.TargetZone = info.id, os.clock(), "Flying", info.zone
	end
	local follow = mine
		and info.dist > 70
		and not Settings.ReducedMotion
		and not TC.InputBlocked
		and not TC.SystemMenuOpen
	if follow then
		claimCamera(info.id, a, info.t + Timeline.LandBounce + 1.5)
	end
	if not mine then
		Sounds.PlayAt("Whoosh", a)
	end
	local start = os.clock()
	local landed = false
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not orb.Parent or finishedThrows[info.id] then
			orb:Destroy()
			conn:Disconnect()
			return
		end
		local t = os.clock() - start
		if t < info.t then
			local k = t / info.t
			local ek = k < 0.5 and k * 1.1 or 0.55 + (k - 0.5) * 0.9 -- slight hang time at the apex
			local p = bezier(a, mid, c, math.clamp(ek, 0, 1))
			orb:PivotTo(CFrame.new(p) * CFrame.Angles(t * 4, t * 2.6, 0))
			if follow and camFollow and camFollow.id == info.id then
				camFollow.pos = p
			end
			PortalBuilder.Spin(refs, t * 2)
		else
			if not landed then
				landed = true
				if mine then
					TC.Phase = "Landing"
				end
				Sounds.PlayAt("Land", c)
				Effects.Burst(
					c - Vector3.new(0, 0.6, 0),
					ColorSequence.new(Color3.fromRGB(230, 220, 200)),
					18,
					10,
					1.2,
					"rbxasset://textures/particles/smoke_main.dds"
				)
				Effects.Shockwave(c - Vector3.new(0, 0.8, 0), Config.Portals[info.portal].color, 6, 0.4)
				if mine then
					Effects.Shake(0.3, 0.14)
				end
				refs.trail.Enabled = false
			end
			-- two decaying bounces, then a charged-up wobble before it bursts open
			local bt = t - info.t
			local bounce = 0
			if bt < 0.22 then
				bounce = math.sin(bt / 0.22 * math.pi) * 1.6
			elseif bt < 0.36 then
				bounce = math.sin((bt - 0.22) / 0.14 * math.pi) * 0.5
			end
			local wobble = bt > 0.36 and math.sin(bt * 40) * (bt - 0.36) * 0.6 or 0
			orb:PivotTo(CFrame.new(c + Vector3.new(0, bounce, 0)) * CFrame.Angles(wobble, bt * 12, wobble * 0.5))
			refs.light.Brightness = 2 + bt * 8
			if bt > 0.5 then
				conn:Disconnect()
				orb:Destroy()
				if mine then
					TC.Phase = "Opening"
				end
				openGate(info.id, info)
			end
		end
	end)
end)

Remotes.PortalOpened.OnClientEvent:Connect(function(info)
	if seenOpened[info.id] or finishedThrows[info.id] then
		return
	end
	seenOpened[info.id] = true
	local def = CreatureData.ById[info.creature]
	if not def then
		return
	end
	local rc = Config.Rarities[def.rarity]
	local mine = info.owner == player.UserId
	local chanceText = Odds.OneIn(info.chance)
	if mine then
		TC.Phase = "Revealing"
	end
	local center = info.pos + Vector3.new(0, 3.8, 0)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local near = myRoot and (myRoot.Position - info.pos).Magnitude < 250
	local camNear = (camera.CFrame.Position - info.pos).Magnitude < 300
	if not near and not mine and not camNear then
		return
	end

	-- rarity weight: one clear accent per tier, local to the reveal (no screen-filling effects)
	local low = Settings.LowVFX()
	if rc.order >= 5 then
		if not low then
			Effects.LightBeam(
				info.pos,
				def.rarity == "Secret" and Color3.fromRGB(0, 255, 200) or rc.color,
				rc.order >= 7 and 140 or 90,
				1.6
			)
		end
		Effects.Shockwave(info.pos, rc.color, 14 + rc.order * 2, 0.9)
		if mine then
			Effects.Shake(rc.order >= 7 and 0.9 or 0.6, 0.4)
			Sounds.Play("Rare")
			Effects.RarityBanner(def, chanceText)
		end
	elseif mine then
		Effects.RarityBanner(def, chanceText)
	end
	if not low or rc.order >= 3 then
		Effects.Burst(center, rc.color, 10 + rc.order * 5, 10 + rc.order * 2, 0.8)
	end
	Sounds.PlayAt("Spawn", center, 1.2 - rc.order * 0.05)
	Renderer.SpawnWild(info.id, info.creature, info.pos, info.owner, chanceText)
	if mine then
		-- Rarity caption and world label already show the odds; avoid a third floating label.
		if TC.InputBlocked or TC.SystemMenuOpen then
			TC.StopFollow(true)
		elseif camFollow and camFollow.id == info.id then
			camFollow.pos = info.pos
			camFollow.untilT = os.clock() + Timeline.FollowHoldAfterOpen(def.rarity)
		elseif myRoot and (myRoot.Position - info.pos).Magnitude > 70 then
			claimCamera(info.id, info.pos, Timeline.FollowHoldAfterOpen(def.rarity))
		end
	end
	task.delay(Timeline.GateCloseAfterOpen(def.rarity), function()
		closeGate(info.id)
	end)
end)

Remotes.CreatureGone.OnClientEvent:Connect(function(id, reason, collectorId)
	finishedThrows[id] = true
	task.delay(Config.PendingLifetime + 10, function()
		finishedThrows[id] = nil
	end)
	if TC.MyThrow == id then
		TC.MyThrow = nil
		TC.Phase = "Ready"
	end
	Renderer.RemoveWild(id, reason, collectorId)
	if reason == "collected" and collectorId == player.UserId then
		Sounds.Play("Collect")
	end
	closeGate(id)
end)

return TC
