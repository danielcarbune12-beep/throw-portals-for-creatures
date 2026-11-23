-- PlayerFeel: how the local player's character moves and feels.
-- Location: StarterPlayer > StarterPlayerScripts > Client > PlayerFeel (LocalScript)
--
--   * Run: hold Left Shift (PC), press L3 (gamepad) or tap the Run button (mobile, toggles).
--     Speed eases between walk and run instead of snapping; the default Animate script picks
--     its run cycle from the higher speed.
--   * Body: a small additive layer on top of the default animations
--       - leans forward with speed and banks into turns
--       - the head follows where the camera looks (clamped), so the avatar feels aware
--       - idle: slow breathing and an occasional weight shift
--   * Feel: wider FOV while running, footstep dust, a soft camera dip on hard landings.
-- Everything switches off while the throw/cutscene/intro owns the body or camera, and respects
-- Reduced Motion and graphics quality. Purely cosmetic: no gameplay values change on the server.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Settings = require(script.Parent.ClientSettings)
local TC = require(script.Parent.ThrowController)
local MovementFov = require(script.Parent.MovementFov)

local player = Players.LocalPlayer

local WALK, RUN = 16, 26
local RUN_FOV_ADD = 7

---------------------------------------------------------------- state
local sprintHeld, sprintToggled = false, false
local char, hum, hrp
local joints = {} -- name -> { kind, obj, rest = CFrame }
local baseSpeed = WALK
local lastSetSpeed
local lean, bank, headYaw, headPitch = 0, 0, 0, 0
local lastYaw
local stepT, idleT, shiftT, shiftDir = 0, 0, 0, 0
local fallStart

local function quality()
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if not ok or q == 0 then return 10 end
	return q
end

local function bodyOwnedElsewhere()
	if workspace:GetAttribute("TPFC_IntroPlaying") then return true end
	if TC.InputBlocked or TC.SystemMenuOpen or TC.Charging or TC.Submitting then return true end
	if TC.Phase and TC.Phase ~= "Ready" then return true end
	local cam = workspace.CurrentCamera
	return cam and cam.CameraType ~= Enum.CameraType.Custom
end

---------------------------------------------------------------- character binding
-- Characters use either classic Motor6D joints or the newer AnimationConstraint joints
-- (avatar joint upgrade). Motor6D: offset C0. AnimationConstraint: offset its Attachment0.
-- Roblox can swap a freshly spawned avatar's Motor6Ds for AnimationConstraints a moment later,
-- so joints are re-resolved (non-yielding) whenever a bound one stops being live.
local jointMap = {}
local function joint(partName, jointName)
	local p = char and char:FindFirstChild(partName)
	local j = p and p:FindFirstChild(jointName)
	if not j then return nil end
	if j:IsA("Motor6D") then
		return { kind = "motor", obj = j, rest = j.C0 }
	end
	if j:IsA("AnimationConstraint") and j.Attachment0 then
		return { kind = "attach", obj = j.Attachment0, rest = j.Attachment0.CFrame }
	end
	return nil
end

local function bind(c)
	MovementFov.Clear(workspace.CurrentCamera)
	char = c
	hum = c:WaitForChild("Humanoid", 10)
	hrp = c:WaitForChild("HumanoidRootPart", 10)
	joints = {}
	lastSetSpeed = nil
	if not hum then return end
	baseSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or WALK
	local r15 = hum.RigType == Enum.HumanoidRigType.R15
	local map = r15 and {
		Root = { "LowerTorso", "Root" },
		Waist = { "UpperTorso", "Waist" },
		Neck = { "Head", "Neck" },
	} or {
		Root = { "HumanoidRootPart", "RootJoint" },
		Neck = { "Torso", "Neck" },
	}
	c:WaitForChild("Head", 10)
	jointMap = { specs = map, r6 = not r15 }
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			fallStart = hrp and hrp.Position.Y
		elseif new == Enum.HumanoidStateType.Landed and fallStart and hrp then
			local drop = fallStart - hrp.Position.Y
			fallStart = nil
			if drop > 7 and Settings.CameraShake and not Settings.ReducedMotion and not bodyOwnedElsewhere() then
				-- soft camera dip on a hard landing
				local k = math.clamp((drop - 7) / 20, 0.25, 1)
				hum.CameraOffset = Vector3.new(0, -0.7 * k, 0)
				TweenService:Create(hum, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CameraOffset = Vector3.zero }):Play()
			end
		end
	end)
end

local function resolveJoints()
	joints = {}
	for name, spec in pairs(jointMap.specs or {}) do
		local j = joint(spec[1], spec[2])
		if j then
			j.r6 = jointMap.r6
			j.src = spec
			joints[name] = j
		end
	end
end
local function jointsLive()
	for _, j in pairs(joints) do
		local p = char and char:FindFirstChild(j.src[1])
		local cur = p and p:FindFirstChild(j.src[2])
		if not cur then return false end
		if j.kind == "motor" and cur ~= j.obj then return false end
		if j.kind == "attach" and not (cur:IsA("AnimationConstraint") and cur.Attachment0 == j.obj) then return false end
	end
	return next(joints) ~= nil
end

player.CharacterAdded:Connect(bind)
if player.Character then task.spawn(bind, player.Character) end

---------------------------------------------------------------- run input
local function sprintAction(_, state, input)
    if UserInputService:GetFocusedTextBox() or TC.SystemMenuOpen then
        sprintHeld = false
        return Enum.ContextActionResult.Pass
    end
	if input.UserInputType == Enum.UserInputType.Touch then
		if state == Enum.UserInputState.Begin then
			sprintToggled = not sprintToggled
			ContextActionService:SetTitle("TPFC_Run", sprintToggled and "Walk" or "Run")
		end
	elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
		if state == Enum.UserInputState.Begin then sprintToggled = not sprintToggled end
	else
		sprintHeld = state == Enum.UserInputState.Begin
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction("TPFC_Run", sprintAction, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
ContextActionService:SetTitle("TPFC_Run", "Run")
pcall(function() ContextActionService:SetPosition("TPFC_Run", UDim2.new(1, -170, 1, -150)) end)
-- lose Shift if the window loses focus while held
UserInputService.WindowFocusReleased:Connect(function()
    sprintHeld, sprintToggled = false, false
    ContextActionService:SetTitle("TPFC_Run", "Run")
end)

---------------------------------------------------------------- footstep dust
local dustFolder = Instance.new("Folder")
dustFolder.Name = "TPFC_FootDust"
dustFolder.Parent = workspace
local function dust(pos, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Shape = Enum.PartType.Ball
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = 0.55
	p.Size = Vector3.new(0.6, 0.6, 0.6)
	p.CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 0.6, 0.2, (math.random() - 0.5) * 0.6))
	p.Parent = dustFolder
	TweenService:Create(p, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.8, 1.2, 1.8), Transparency = 1, CFrame = p.CFrame + Vector3.new(0, 0.7, 0),
	}):Play()
	task.delay(0.6, function() p:Destroy() end)
end

---------------------------------------------------------------- per frame
local function approach(a, b, rate, dt)
	return a + (b - a) * (1 - math.exp(-rate * dt))
end

RunService.RenderStepped:Connect(function(dt)
	if not (hum and hrp and hum.Parent and hum.Health > 0) then return end
	local cam = workspace.CurrentCamera
	local busy = bodyOwnedElsewhere()

	-- speed: respect anything else that changed WalkSpeed (admin speed, slows) as the new base
	if lastSetSpeed and math.abs(hum.WalkSpeed - lastSetSpeed) > 0.01 then
		baseSpeed = hum.WalkSpeed
	end
	local moving = hum.MoveDirection.Magnitude > 0.1
	local wantRun = (sprintHeld or sprintToggled) and moving and not busy
	local target = wantRun and baseSpeed * (RUN / WALK) or baseSpeed
	local speed = approach(hum.WalkSpeed, target, wantRun and 6 or 9, dt)
	if math.abs(speed - target) < 0.05 then speed = target end
	hum.WalkSpeed = speed
	lastSetSpeed = speed

    -- Sprint never bakes into the lens saved by a throw or another camera owner.
    if cam and cam.CameraType == Enum.CameraType.Custom and not busy then
        local runK = math.clamp((hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude - WALK, 0, RUN - WALK) / (RUN - WALK)
        MovementFov.Update(cam, Settings.ReducedMotion and 0 or RUN_FOV_ADD * runK, dt)
    else
        MovementFov.Clear(cam)
    end

	-- footstep dust while running on the ground
	local planar = (hrp.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	if planar > WALK + 3 and grounded and quality() > 3 and not Settings.LowVFX() then
		stepT += dt
		if stepT > 0.16 then
			stepT = 0
			local mat = hum.FloorMaterial
			local col = (mat == Enum.Material.Snow or mat == Enum.Material.Glacier) and Color3.fromRGB(240, 246, 255)
				or (mat == Enum.Material.Sand or mat == Enum.Material.Ground) and Color3.fromRGB(200, 178, 140)
				or Color3.fromRGB(214, 208, 196)
			dust(hrp.Position - Vector3.new(0, hum.HipHeight + hrp.Size.Y / 2 - 0.1, 0) - hrp.CFrame.LookVector * 0.6, col)
		end
	end

	-- additive body layer on the joints' rest offsets (C0); the animator only writes Transform,
	-- so this never compounds. Restored to rest while the throw/cutscene owns the rig.
	local function setJoint(j, extra)
		if not (j and j.obj.Parent) then return end
		if j.kind == "motor" then
			j.obj.C0 = j.rest * extra
		else
			j.obj.CFrame = j.rest * extra
		end
	end
	if not jointsLive() then resolveJoints() end
	if busy or not joints.Neck then
		if lean ~= 0 or headYaw ~= 0 or bank ~= 0 then
			for _, j in pairs(joints) do setJoint(j, CFrame.identity) end
		end
		lean, bank, headYaw, headPitch = 0, 0, 0, 0
		lastYaw = nil
		return
	end
	local motionK = Settings.ReducedMotion and 0.4 or 1
	local _, yaw = hrp.CFrame:ToEulerAnglesYXZ()
	local yawRate = 0
	if lastYaw then
		local d = yaw - lastYaw
		if d > math.pi then d -= 2 * math.pi elseif d < -math.pi then d += 2 * math.pi end
		yawRate = d / math.max(dt, 1e-3)
	end
	lastYaw = yaw
	local runK = math.clamp(planar / RUN, 0, 1.2)
	lean = approach(lean, math.rad(2 + 7 * runK) * (planar > 1 and 1 or 0) * motionK, 7, dt)
	bank = approach(bank, math.clamp(yawRate * 0.045 * runK, -0.16, 0.16) * motionK, 8, dt)

	-- head follows the camera look direction (relative to the body), clamped
	if cam then
		local rel = hrp.CFrame:VectorToObjectSpace(cam.CFrame.LookVector)
		local wantYaw = math.clamp(math.atan2(-rel.X, -rel.Z), -0.8, 0.8)
		local wantPitch = math.clamp(math.asin(math.clamp(rel.Y, -1, 1)), -0.35, 0.4)
		if rel.Z > 0.3 then wantYaw = 0 end -- camera in front of the face: don't twist backwards
		headYaw = approach(headYaw, wantYaw * 0.65 * motionK, 6, dt)
		headPitch = approach(headPitch, wantPitch * 0.5 * motionK, 6, dt)
	end

	-- idle life: breathing + an occasional weight shift
	local breath, shift = 0, 0
	if planar < 1 then
		idleT += dt
		breath = math.sin(idleT * 1.6) * math.rad(1.1) * motionK
		shiftT -= dt
		if shiftT <= 0 then
			shiftT = 4 + math.random() * 4
			shiftDir = (math.random() < 0.5 and -1 or 1)
		end
		shift = math.sin(math.clamp(1 - shiftT / 1.2, 0, 1) * math.pi) * shiftDir * math.rad(2.2) * motionK
	else
		idleT, shiftT = 0, 2
	end

	-- apply: lean/bank at the hips, breathing + counter-shift at the waist, head look at the neck
	local root, waist, neck = joints.Root, joints.Waist, joints.Neck
	if root then
		if root.r6 then
			setJoint(root, CFrame.Angles(-lean, bank + shift, 0))
		else
			setJoint(root, CFrame.Angles(-lean * 0.6, 0, bank + shift))
		end
	end
	if waist then
		setJoint(waist, CFrame.Angles(-lean * 0.4 + breath, 0, -shift * 0.5))
	end
	if neck then
		if neck.r6 then
			setJoint(neck, CFrame.Angles(headPitch, 0, headYaw))
		else
			setJoint(neck, CFrame.Angles(headPitch + lean * 0.5, headYaw, 0))
		end
	end
end)

---------------------------------------------------------------- one-time hint (PC) after the intro
task.spawn(function()
	task.wait(2)
	while workspace:GetAttribute("TPFC_IntroPlaying") or player.PlayerGui:FindFirstChild("Intro") do
		task.wait(0.5)
	end
	task.wait(1.5)
	if UserInputService.KeyboardEnabled then
		pcall(function() require(script.Parent.HUD).Notify("Hold Shift to run") end)
	end
end)
