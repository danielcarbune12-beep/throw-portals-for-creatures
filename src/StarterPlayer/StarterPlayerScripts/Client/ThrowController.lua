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
local aimCam = nil -- cinematic over-the-shoulder camera while charging / throwing (see TC.StartAim)

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
		-- cancelled (not thrown): leave throw mode and give the camera back
		if _reason ~= "released" and TC.EndAim then
			TC.EndAim()
		end
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
	if TC.StartAim then
		TC.StartAim(hrp)
	end
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
	if aimCam then
		-- the throw-mode camera sits over the shoulder (slightly off-centre), so throw straight down the lane
		dir = Vector3.new(0, 0, 1)
	end
	dir = dir.Unit
	hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + dir)
	Remotes.Throw:FireServer(power, dir)
	if TC.ReleaseAim then
		TC.ReleaseAim(power)
	end
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
		or aimCam and aimCam.saved
		or {
			type = camera.CameraType,
			subject = camera.CameraSubject,
			fov = idleFov,
			offset = root and camera.CFrame.Position - root.Position or Vector3.new(0, 7, -16),
			rotation = camera.CFrame.Rotation,
		}
	camReturn = nil
	aimCam = nil -- the follow camera takes over smoothly from the throw camera
	camFollow = {
		pos = pos,
		untilT = os.clock() + math.min(duration, Timeline.CameraTimeout),
		id = id,
		saved = saved,
		started = os.clock(),
	}
end

---------------------------------------------------------------- THROW MODE (cinematic aim + throw)
-- Charging puts you in "throw mode": the camera glides over your right shoulder, facing down the
-- lane, letterbox bars slide in and the view tightens as power builds. On release your character
-- plays an overhand throw, light bursts from your hand, the camera kicks forward, and then the
-- follow camera picks up the ball (or the view glides back for a short throw).
local THROW_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514", -- Roblox's built-in overhand tool swing
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
}
local throwTrack, throwHum = nil, nil
local function playThrowAnim()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	if hum ~= throwHum then
		throwHum, throwTrack = hum, nil
		local animator = hum:FindFirstChildOfClass("Animator") or hum
		local anim = Instance.new("Animation")
		anim.AnimationId = THROW_ANIM[hum.RigType] or THROW_ANIM[Enum.HumanoidRigType.R15]
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			throwTrack = track
		end
	end
	if throwTrack then
		throwTrack:Play(0.05, 1, 1.25)
	end
end

function TC.StartAim(hrp)
	if Settings.ReducedMotion or camFollow or camReturn then
		return
	end
	camera = workspace.CurrentCamera or camera
	if camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	aimCam = {
		saved = {
			type = camera.CameraType,
			subject = camera.CameraSubject,
			fov = camera.FieldOfView,
			offset = hrp and (camera.CFrame.Position - hrp.Position) or Vector3.new(0, 7, -16),
			rotation = camera.CFrame.Rotation,
		},
		cf = camera.CFrame,
	}
	if hrp then
		hrp.CFrame = CFrame.lookAt(hrp.Position, hrp.Position + Vector3.new(0, 0, 1)) -- face down the lane
	end
	Effects.Letterbox(true)
end

-- Release: the throw itself now happens at the END of the throw cutscene (TC.PlayThrowCutscene),
-- which starts when the server confirms the launch. Here we only hold the shot until then.
function TC.ReleaseAim(power)
	if not Settings.ReducedMotion then
		Effects.Shake(0.15 + power * 0.2, 0.12)
	end
	local a = aimCam
	if not a then
		return
	end
	a.released = os.clock()
	task.delay(1.5, function()
		if aimCam == a and not a.cutscene then
			TC.EndAim() -- the launch was never confirmed: give the camera back
		end
	end)
end

function TC.EndAim()
	local a = aimCam
	if not a then
		return
	end
	aimCam = nil
	Effects.Letterbox(false)
	camera = workspace.CurrentCamera or camera
	camReturn = { saved = a.saved, started = os.clock(), from = camera.CFrame, fov = camera.FieldOfView }
end

---------------------------------------------------------------- THROW CUTSCENE
-- When the server confirms your launch it also tells us how rare the creature inside is (tier 1-8)
-- and how long the wind-up lasts. The cutscene:
--   A  (first half)   the portal appears in your hand and grows; you raise it up (camera in front)
--   B  (power-up)     the camera circles you while the portal charges, effects scale with rarity
--   C  (last 0.3 s)   camera whips over your shoulder, overhand throw, the ball leaves your hand
-- Rarer = crazier:  Rare sparkles | Epic lightning + shake | Legendary golden pillar + flash |
--                   Mythical sky darkens + energy rings | Secret glitch cuts | Divine heaven beam
local Lighting = game:GetService("Lighting")
local RAISE_ANIM = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://507770677", -- Roblox's built-in cheer: both arms up
	[Enum.HumanoidRigType.R6] = "rbxassetid://129423030",
}
local raiseTrack, raiseHum = nil, nil
local function raiseAnim()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return nil
	end
	if hum ~= raiseHum then
		raiseHum, raiseTrack = hum, nil
		local animator = hum:FindFirstChildOfClass("Animator") or hum
		local anim = Instance.new("Animation")
		anim.AnimationId = RAISE_ANIM[hum.RigType] or RAISE_ANIM[Enum.HumanoidRigType.R15]
		local ok, track = pcall(function()
			return animator:LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			raiseTrack = track
		end
	end
	return raiseTrack
end

local cutsceneConn = nil
function TC.PlayThrowCutscene(info, windup, tier, color)
	if cutsceneConn then
		cutsceneConn:Disconnect()
		cutsceneConn = nil
	end
	color = color or Color3.fromRGB(200, 200, 210)
	tier = tier or 1
	local w = math.max(windup, 0.4)
	local calm = Settings.ReducedMotion
	local t0 = os.clock()
	if aimCam then
		aimCam.cutscene = { t0 = t0, w = w, tier = tier }
	end
	-- the portal appears in your hand
	local handOrb, handRefs = PortalBuilder.BuildOrb(info.portal, 0.45)
	handOrb.Parent = Effects.Folder
	if handRefs.light and tier >= 3 then
		handRefs.light.Color = color
	end
	local hcf0 = handCFrame()
	if hcf0 then
		Effects.Burst(hcf0.Position, PortalBuilder.ColorSeq(info.portal), 18, 8, 0.6)
	end
	Sounds.Play("Open", 1.3)
	local raise = raiseAnim()
	if raise then
		raise:Play(0.15, 1, 1)
	end
	local phaseB, phaseC, released = false, false, false
	local fxTimer, ringTimer = 0, 0
	local savedExposure = nil
	local function finish()
		if cutsceneConn then
			cutsceneConn:Disconnect()
			cutsceneConn = nil
		end
		if handOrb then
			handOrb:Destroy()
			handOrb = nil
		end
		if raise and raise.IsPlaying then
			raise:Stop(0.1)
		end
		if savedExposure then
			Effects.Tween(Lighting, 0.6, { ExposureCompensation = savedExposure })
			savedExposure = nil
		end
	end
	cutsceneConn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			finish()
			return
		end
		local hcf = handCFrame()
		local handPos = hcf and hcf.Position or (root.Position + Vector3.new(0, 3, 0))
		-- the portal in your hand grows, then pulses harder as it charges
		if handOrb and hcf then
			local grow = math.min(1, t / 0.4)
			local pulse = 1 + math.sin(t * (8 + tier * 2)) * 0.06 * tier / 4
			handOrb:PivotTo(hcf * CFrame.new(0, -1.1, 0))
			handOrb:ScaleTo(math.max(0.05, (1 - (1 - grow) ^ 3) * pulse * (1 + 0.25 * math.min(1, t / w))))
			PortalBuilder.Spin(handRefs, t * (2 + tier))
			if handRefs.light then
				handRefs.light.Range = 8 + tier * 2 + t * 4
			end
		end
		-- B: power-up (escalates with rarity)
		if not phaseB and t >= w * 0.45 then
			phaseB = true
			Sounds.Play("Upgrade", 0.7 + tier * 0.1)
			if tier >= 5 then
				Effects.LightBeam(root.Position - Vector3.new(0, 3, 0), tier == 8 and Color3.fromRGB(255, 250, 225) or color, 120, w)
				if not calm then
					Effects.Flash(tier == 7 and Color3.new(0, 0, 0) or color, 0.5, 0.35)
				end
				Effects.Shockwave(root.Position - Vector3.new(0, 2.8, 0), color, 14 + tier * 2, 0.6)
			end
			if tier >= 6 and not calm then
				savedExposure = Lighting.ExposureCompensation
				Effects.Tween(Lighting, 0.4, { ExposureCompensation = savedExposure - 1 })
			end
			if tier == 8 then
				Sounds.Play("Rare", 0.75)
			end
		end
		if phaseB and not phaseC then
			fxTimer -= dt
			ringTimer -= dt
			if fxTimer <= 0 then
				fxTimer = 0.12
				if tier >= 3 then
					Effects.Burst(handPos, color, 3 + tier * 2, 6, 0.5)
				end
				if tier >= 4 then
					local off = Vector3.new(math.random(-30, 30), math.random(-10, 30), math.random(-30, 30)) / 10
					Effects.Burst(handPos + off, color, 10, 20, 0.45)
					if not calm then
						Effects.Shake(0.12 * tier / 4, 0.15)
					end
				end
				if tier == 7 and not calm and math.random() < 0.3 then
					Effects.Flash(Color3.new(0, 0, 0), 0.06, 0.75)
					Effects.Burst(handPos, ColorSequence.new(Color3.fromRGB(0, 255, 200), Color3.fromRGB(255, 0, 170)), 12, 18, 0.5)
				end
			end
			if tier >= 6 and ringTimer <= 0 then
				ringTimer = 0.36
				Effects.Shockwave(root.Position - Vector3.new(0, 2.8, 0), color, 8 + tier, 0.4)
			end
		end
		-- C: whip over the shoulder and throw
		if not phaseC and t >= w - 0.3 then
			phaseC = true
			if raise and raise.IsPlaying then
				raise:Stop(0.08)
			end
			playThrowAnim()
			Sounds.Play("Throw", 1 + tier * 0.03)
		end
		-- the ball leaves your hand (the flight starts at exactly this moment)
		if not released and t >= w then
			released = true
			Effects.Burst(handPos, PortalBuilder.ColorSeq(info.portal), 30, 18, 0.8)
			if tier >= 3 then
				Effects.Burst(handPos, color, 20 + tier * 6, 22, 0.8)
			end
			if not calm then
				Effects.Shake(0.3 + tier * 0.12, 0.25)
				if tier >= 5 then
					Effects.Flash(color, 0.35, 0.3)
				end
			end
			finish()
		end
	end)
end
function TC.IsFollowing()
	return camFollow ~= nil or camReturn ~= nil
end
function TC.StopFollow(immediate)
	local active = camFollow or camReturn
	if not active then
		return
	end
	if camFollow and camFollow.closeup then TC.EndCloseup() end
	Effects.Letterbox(false) -- throw mode / follow bars always slide away when the camera is handed back
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
	if aimCam and not camFollow then
		-- THROW MODE camera: over the right shoulder, looking down the lane
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then
			TC.EndAim()
			return
		end
		if aimCam.cutscene then
			-- THROW CUTSCENE camera (character faces +Z: front is +Z, right side is -X)
			local cs = aimCam.cutscene
			local t = os.clock() - cs.t0
			local R = root.Position
			local desired, fov, sharp
			if t < cs.w - 0.3 then
				local kk = math.clamp(t / math.max(0.1, cs.w - 0.3), 0, 1)
				local ang = -0.45 + kk * (1.2 + cs.tier * 0.12) -- orbit from the front; rarer = wider swing
				local r = 7.5 - kk * 1.8
				local h = 2.2 + kk * 1.4
				local center = R + Vector3.new(-0.8, 0, 0)
				desired = CFrame.lookAt(center + Vector3.new(math.sin(ang) * r, h, math.cos(ang) * r), R + Vector3.new(-0.6, 2.6 + kk, 0))
				fov = 58 - kk * (4 + cs.tier * 1.5)
				sharp = 7
				if cs.tier == 7 and not Settings.ReducedMotion then
					desired = desired * CFrame.new(math.random(-6, 6) / 10, math.random(-6, 6) / 10, 0) -- glitch jitter
					sharp = 30
				end
			else
				desired = CFrame.lookAt(R + Vector3.new(-2.8, 2.4, -7.5), R + Vector3.new(0, 3.5, 45))
				fov = aimCam.saved.fov + 6
				sharp = 14
			end
			aimCam.cf = aimCam.cf:Lerp(desired, 1 - math.exp(-sharp * dt))
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = aimCam.cf
			camera.FieldOfView += (fov - camera.FieldOfView) * (1 - math.exp(-8 * dt))
			return
		end
		local released = aimCam.released and (os.clock() - aimCam.released) or nil
		local power = TC.Charging and TC.Power or (released and 1 or 0)
		local push = released and math.min(1, released / 0.35) or 0
		-- facing +Z, the character's right side is -X
		local pos = root.Position + Vector3.new(-2.8, 2.6 - push * 0.5, -8.5 + push * 3)
		local desired = CFrame.lookAt(pos, root.Position + Vector3.new(0, 3.5, 45))
		aimCam.cf = aimCam.cf:Lerp(desired, 1 - math.exp(-9 * dt))
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = aimCam.cf
		local fovTarget = aimCam.saved.fov - 16 * power + push * 10
		camera.FieldOfView += (fovTarget - camera.FieldOfView) * (1 - math.exp(-10 * dt))
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
	if os.clock() > camFollow.untilT or (not camFollow.closeup and os.clock() - camFollow.started > Timeline.CameraTimeout) then
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
	if camFollow.closeup then
		-- CINEMATIC CLOSE-UP (good pets): slow orbit around the creature, pushing in
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
	if Settings.ReducedMotion then
		camFollow.cf = camFollow.cf or desired
	else
		camFollow.cf = (camFollow.cf or camera.CFrame):Lerp(desired, 1 - math.exp(-6 * dt))
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = camFollow.cf
end)
local function watchCharacter(char)
	if aimCam then
		local a = aimCam
		aimCam = nil
		Effects.Letterbox(false)
		restoreCamera(a.saved)
	end
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

-- start a cinematic zoom on a good creature you just found
function TC.StartCloseup(id, def, pos, duration)
	local rc = Config.Rarities[def.rarity]
	local size = rc.size * (def.scale or 1)
	if not camFollow then claimCamera(id, pos, duration) end
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
	local mine = info.owner == player.UserId
	if mine then
		TC.Submitting = false
		submissionSerial += 1
		TC.MyThrow, TC.MyThrowT, TC.Phase, TC.TargetZone = info.id, os.clock(), "Flying", info.zone
	end
	-- THROW CUTSCENE first; the ball leaves the hand when it ends (the server waits the same time)
	local windup = math.clamp(tonumber(info.windup) or 0, 0, 4)
	local rinfo = info.rarity and Config.Rarities[info.rarity]
	local tier = rinfo and rinfo.order or 1
	local rarityColor = rinfo and rinfo.color or nil
	if mine then
		TC.PlayThrowCutscene(info, windup, tier, rarityColor)
	elseif tier >= 5 and windup > 0 and rarityColor then
		Effects.LightBeam(info.from - Vector3.new(0, 1.5, 0), rarityColor, 80, windup) -- others see the power-up too
	end
	task.delay(windup, function()
	if finishedThrows[info.id] then
		return
	end
	local orb, refs = PortalBuilder.BuildOrb(info.portal, 0.75)
	local a, c = info.from, info.to + Vector3.new(0, 0.9, 0)
	if mine then
		local hcf = handCFrame()
		if hcf and (hcf.Position - a).Magnitude < 12 then
			a = hcf.Position -- the ball leaves from your hand
		end
	end
	local mid = (a + c) / 2 + Vector3.new(0, math.min(10 + info.dist * 0.3, 220), 0)
	orb:PivotTo(CFrame.new(a))
	orb.Parent = Effects.Folder
	refs.trail.Enabled = true
	if tier >= 3 and rarityColor then
		-- the ball glows in the colour of what's inside (gacha style)
		refs.trail.Color = ColorSequence.new(rarityColor, Color3.new(1, 1, 1))
		if refs.light then
			refs.light.Color = rarityColor
			refs.light.Range = 10 + tier * 3
		end
		if refs.emitter then
			refs.emitter.Color = ColorSequence.new(rarityColor)
		end
	end
	local follow = mine
		and info.dist > 70
		and not Settings.ReducedMotion
		and not TC.InputBlocked
		and not TC.SystemMenuOpen
	if follow then
		claimCamera(info.id, a, info.t + Timeline.LandBounce + 1.5)
	elseif mine and TC.EndAim then
		task.delay(0.35, TC.EndAim) -- short throw: glide the camera back after the release
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
	end) -- task.delay(windup): flight starts after the throw cutscene
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
		elseif rc.order >= 3 and not Settings.ReducedMotion then
			-- a GOOD pet: zoom in on it and keep watching through its entrance and capture
			local catchDur = (Renderer.CatchConfig[def.rarity] or Renderer.CatchConfig.Common).dur
			TC.StartCloseup(info.id, def, info.pos, (Config.CatchDelay[def.rarity] or 3) + catchDur + 0.5)
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
