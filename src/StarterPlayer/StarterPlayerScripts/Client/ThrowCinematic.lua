-- ThrowCinematic: the throw cutscene (owner only). No letterbox, full screen.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ThrowCinematic (ModuleScript)
--
-- Timeline (w = wind-up seconds from the server, longer for rarer creatures):
--   GATHER  0 .. 0.4w     energy motes stream into your hand and form the portal; a rune circle
--                          opens under your feet; you settle into a throwing stance
--   CHARGE  0.4w .. w-.32 you lean back with the arm cocked (throw pose held), the portal pulses;
--                          rarity effects escalate (lightning, light pillar, sky strikes, glitch, wings)
--   THROW   w-.32 .. w    weight shifts forward with a step, the arm whips through
--   RELEASE at w          impact flash, shockwave rings, speed lines, the ball leaves the hand
--   RECOVER w .. w+.45    you settle back upright, everything fades away
-- The body motion is done by tilting/stepping the (temporarily anchored) root plus Roblox's built-in
-- overhand tool swing, held at its wind-up frame during CHARGE and released on THROW.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PortalBuilder = require(ReplicatedStorage.Shared.PortalBuilder)
local Effects = require(script.Parent.Effects)
local Sounds = require(script.Parent.Sounds)

local Cine = {}
local player = Players.LocalPlayer
local SWING = {
	[Enum.HumanoidRigType.R15] = "rbxassetid://522635514", -- built-in overhand tool swing
	[Enum.HumanoidRigType.R6] = "rbxassetid://129967390",
}
local THROW_AT = 0.32 -- seconds before release when the arm whips through

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function ease(k) return 1 - (1 - math.clamp(k, 0, 1)) ^ 3 end
local function easeIn(k) k = math.clamp(k, 0, 1); return k * k end

local function neon(size, cf, color, transp, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Transparency = transp or 0
	if shape then p.Shape = shape end
	p.Parent = Effects.Folder
	return p
end

-- screen-space layer for speed lines / glitch split
local fxGui = Instance.new("ScreenGui")
fxGui.Name = "ThrowFX"
fxGui.IgnoreGuiInset = true
fxGui.ResetOnSpawn = false
fxGui.DisplayOrder = 25
fxGui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------- building blocks
-- rotating rune circle on the ground (more rings for rarer creatures)
local function runeCircle(center, color, tier)
	local rings = {}
	local count = 1 + math.floor(tier / 2)
	for r = 1, count do
		local radius = 3 + r * 1.6
		local segs = 18 + r * 4
		local ring = { radius = radius, speed = (r % 2 == 0 and -1 or 1) * (0.6 + r * 0.25), angle = 0, parts = {} }
		for i = 1, segs do
			local a = i / segs * math.pi * 2
			local isRune = (i % 6 == 0)
			local size = isRune and Vector3.new(0.7, 0.08, 0.7) or Vector3.new(0.18, 0.06, radius * 2 * math.pi / segs * 0.7)
			local part = neon(size, CFrame.new(center), color:Lerp(Color3.new(1, 1, 1), isRune and 0.4 or 0), 1)
			table.insert(ring.parts, { part = part, a = a, rune = isRune })
		end
		table.insert(rings, ring)
	end
	local glow = neon(Vector3.new(0.05, 1, 1), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, 1, Enum.PartType.Cylinder)
	return { rings = rings, glow = glow, center = center, alpha = 0 }
end

local function updateCircle(c, dt, alpha, pulse)
	c.alpha = alpha
	for _, ring in ipairs(c.rings) do
		ring.angle += ring.speed * dt
		for _, s in ipairs(ring.parts) do
			local a = s.a + ring.angle
			local r = ring.radius * (0.6 + 0.4 * alpha)
			s.part.CFrame = CFrame.new(c.center + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r)) * CFrame.Angles(0, -a, 0) * (s.rune and CFrame.Angles(0, math.rad(45), 0) or CFrame.identity)
			s.part.Transparency = 1 - alpha * (s.rune and 1 or 0.85)
		end
	end
	local d = (c.rings[#c.rings].radius * 2 + 1) * (0.6 + 0.4 * alpha)
	c.glow.Size = Vector3.new(0.05, d, d)
	c.glow.Transparency = 1 - alpha * (0.25 + pulse * 0.15)
end

local function destroyCircle(c)
	for _, ring in ipairs(c.rings) do
		for _, s in ipairs(ring.parts) do
			tween(s.part, 0.35, { Transparency = 1 })
			Debris:AddItem(s.part, 0.4)
		end
	end
	tween(c.glow, 0.35, { Transparency = 1, Size = c.glow.Size * Vector3.new(1, 1.5, 1.5) })
	Debris:AddItem(c.glow, 0.4)
end

-- a glowing mote that flies from a random point into the hand
local function mote(getHand, color)
	local hand = getHand()
	if not hand then return end
	local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
	if dir.Magnitude < 0.05 then dir = Vector3.new(0, 1, 0) end
	local start = hand + dir.Unit * (4 + math.random() * 4)
	local p = neon(Vector3.new(0.4, 0.4, 0.4), CFrame.new(start), color, 0.1, Enum.PartType.Ball)
	local t0, dur = os.clock(), 0.32 + math.random() * 0.12
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		local h = getHand() or hand
		if k >= 1 or not p.Parent then
			conn:Disconnect()
			p:Destroy()
			return
		end
		-- spiral in
		local e = easeIn(k)
		local swirl = CFrame.Angles(0, k * 5, 0) * (start - h) * (1 - e)
		p.CFrame = CFrame.new(h + swirl)
		p.Size = Vector3.one * (0.4 * (1 - e) + 0.08)
	end)
end

-- a jagged lightning bolt that flickers for a moment
local function bolt(a, b, color, width)
	local n = 7
	local prev = a
	local dir = b - a
	for i = 1, n do
		local k = i / n
		local p = a + dir * k
		if i < n then
			p += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * dir.Magnitude * 0.12
		end
		local len = (p - prev).Magnitude
		if len > 0.01 then
			local seg = neon(Vector3.new(width, width, len), CFrame.lookAt((prev + p) / 2, p), color:Lerp(Color3.new(1, 1, 1), 0.5), 0)
			tween(seg, 0.14, { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, len) })
			Debris:AddItem(seg, 0.16)
		end
		prev = p
	end
end

-- wings of light behind the character (Divine)
local function makeWings(color)
	local feathers = {}
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 6 do
			local f = neon(Vector3.new(0.35, 4.2 - i * 0.25, 0.1), CFrame.new(), color:Lerp(Color3.new(1, 1, 1), 0.6), 1)
			table.insert(feathers, { part = f, side = side, i = i })
		end
	end
	return feathers
end
local function updateWings(feathers, rootCF, t, alpha)
	for _, f in ipairs(feathers) do
		local spread = (0.35 + f.i * 0.2) * (0.4 + 0.6 * alpha) + math.sin(t * 6) * 0.05
		f.part.CFrame = rootCF * CFrame.new(f.side * 0.6, 1.1, 0.9) * CFrame.Angles(0, 0, -f.side * spread) * CFrame.new(0, f.part.Size.Y / 2, 0)
		f.part.Transparency = 1 - alpha * 0.7
	end
end

-- radial speed lines on screen at the release
local function speedLines(color)
	for i = 1, 22 do
		local a = i / 22 * math.pi * 2 + math.random() * 0.2
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.new(0, 3, 0.18 + math.random() * 0.12, 0)
		line.Position = UDim2.new(0.5 + math.sin(a) * 0.18, 0, 0.5 - math.cos(a) * 0.22, 0)
		line.Rotation = math.deg(a)
		line.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.7)
		line.BackgroundTransparency = 0.25
		line.BorderSizePixel = 0
		line.Parent = fxGui
		tween(line, 0.32, { Position = UDim2.new(0.5 + math.sin(a) * 0.6, 0, 0.5 - math.cos(a) * 0.7, 0), BackgroundTransparency = 1 })
		Debris:AddItem(line, 0.35)
	end
end

-- RGB split frames (Secret)
local function glitchSplit()
	local frames = {}
	for _, c in ipairs({ Color3.fromRGB(0, 255, 220), Color3.fromRGB(255, 0, 170) }) do
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = c
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.Parent = fxGui
		table.insert(frames, f)
	end
	return frames
end

local function loadSwing(hum)
	local animator = hum:FindFirstChildOfClass("Animator") or hum
	local anim = Instance.new("Animation")
	anim.AnimationId = SWING[hum.RigType] or SWING[Enum.HumanoidRigType.R15]
	local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action4
		track.Looped = false
		return track
	end
	return nil
end

---------------------------------------------------------------- the cutscene
local active = nil

-- p = { portal, tier, color, w, calm, getHand() -> CFrame?, onRelease() }
function Cine.Play(p)
	if active then active.cancel() end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		if p.onRelease then task.delay(p.w, p.onRelease) end
		return
	end
	local tier, color, w = p.tier or 1, p.color or Color3.fromRGB(190, 200, 215), math.max(p.w or 1, 0.6)
	local fx = tier >= 3 and color or PortalBuilder.ColorSeq(p.portal).Keypoints[1].Value
	local calm = p.calm
	local t0 = os.clock()
	local baseCF = CFrame.lookAt(root.Position, root.Position + Vector3.new(0, 0, 1))
	-- the forward step must never push you into the Launch Hall's force field (Z = 5..7)
	local stepDist = math.clamp(3.5 - root.Position.Z, 0, 1.5)
	local wasAnchored, wasAutoRotate = root.Anchored, hum.AutoRotate
	root.Anchored = true
	hum.AutoRotate = false
	root.CFrame = baseCF

	local swing = loadSwing(hum)
	if swing then
		swing:Play(0.15, 1, 1)
		swing.TimePosition = 0.05
		swing:AdjustSpeed(0) -- hold the cocked-arm wind-up pose
	end
	local orb, orbRefs = PortalBuilder.BuildOrb(p.portal, 0.45)
	orb.Parent = Effects.Folder
	if orbRefs.light then orbRefs.light.Color = fx end
	local feetDrop = hum.RigType == Enum.HumanoidRigType.R6 and 3 or (hum.HipHeight + root.Size.Y / 2)
	local circle = runeCircle(root.Position - Vector3.new(0, feetDrop - 0.05, 0), fx, tier)
	local wings = tier >= 8 and makeWings(color) or nil
	local split = (tier == 7 and not calm) and glitchSplit() or nil
	local halo = nil
	if tier >= 8 then
		halo = neon(Vector3.new(0.2, 2.6, 2.6), CFrame.new(), Color3.fromRGB(255, 240, 180), 1, Enum.PartType.Cylinder)
	end
	Sounds.Play("Open", 1.2 + tier * 0.03)

	local state = { chargeStarted = false, threw = false, released = false, moteT = 0, boltT = 0, skyT = 0, glitchT = 0 }
	local savedExposure = nil
	local conn
	local function cleanup(final)
		if conn then conn:Disconnect(); conn = nil end
		if orb then orb:Destroy(); orb = nil end
		destroyCircle(circle)
		if wings then for _, f in ipairs(wings) do tween(f.part, 0.3, { Transparency = 1 }); Debris:AddItem(f.part, 0.35) end end
		if halo then tween(halo, 0.3, { Transparency = 1 }); Debris:AddItem(halo, 0.35) end
		if split then for _, f in ipairs(split) do f:Destroy() end end
		if savedExposure then tween(Lighting, 0.6, { ExposureCompensation = savedExposure }); savedExposure = nil end
		if swing and swing.IsPlaying and not final then swing:Stop(0.1) end
		if root.Parent then
			root.Anchored = wasAnchored
			hum.AutoRotate = wasAutoRotate
		end
		active = nil
	end
	active = { cancel = function()
		local wasReleased = state.released
		cleanup(false)
		if not wasReleased and p.onRelease then p.onRelease() end
	end }

	local function bodyPose(t)
		-- lean (+ = back), yaw (shoulders turn), forward step; smooth through every phase
		local lean, yaw, step = 0, 0, 0
		local gEnd, tAt = w * 0.4, w - THROW_AT
		if t < gEnd then
			local k = ease(t / gEnd)
			lean, yaw = 0.06 * k, 0.12 * k
		elseif t < tAt then
			local k = ease((t - gEnd) / math.max(0.05, tAt - gEnd))
			lean, yaw = 0.06 + 0.16 * k, 0.12 + 0.2 * k
			lean += math.sin(t * 9) * 0.008 * tier -- trembling with power
		elseif t < w then
			local k = ease((t - tAt) / THROW_AT)
			lean, yaw, step = 0.22 - 0.5 * k, 0.32 - 0.6 * k, stepDist * k
		else
			local k = ease((t - w) / 0.45)
			lean, yaw, step = -0.28 * (1 - k), -0.28 * (1 - k), stepDist
		end
		return baseCF * CFrame.new(0, 0, -step) * CFrame.Angles(lean, yaw, 0)
	end

	conn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if not root.Parent or hum.Health <= 0 then
			active.cancel()
			return
		end
		root.CFrame = bodyPose(t)
		local hcf = p.getHand()
		local handPos = hcf and hcf.Position or (root.Position + Vector3.new(0, 2.5, 0))
		local gather = math.clamp(t / (w * 0.4), 0, 1)
		local charge = math.clamp((t - w * 0.4) / math.max(0.05, w * 0.6 - THROW_AT), 0, 1)
		local pulse = (math.sin(t * (6 + tier * 1.5)) + 1) / 2

		-- portal forming in the hand
		if orb and hcf then
			orb:PivotTo(hcf * CFrame.new(0, -1.1, 0))
			orb:ScaleTo(math.max(0.05, ease(gather) * (1 + charge * 0.35 + pulse * 0.05 * tier)))
			PortalBuilder.Spin(orbRefs, t * (2 + tier * 0.8))
			if orbRefs.light then orbRefs.light.Range = 6 + charge * (8 + tier * 2) end
		end
		updateCircle(circle, dt, ease(math.min(1, t / 0.35)) * (state.released and math.max(0, 1 - (t - w) / 0.3) or 1), pulse)
		if wings then updateWings(wings, root.CFrame, t, ease(charge)) end
		if halo then
			halo.CFrame = root.CFrame * CFrame.new(0, 3.6 + math.sin(t * 3) * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
			halo.Transparency = 1 - ease(charge) * 0.6
		end

		-- energy streaming into the hand (gather + charge)
		if not state.threw then
			state.moteT -= dt
			if state.moteT <= 0 then
				state.moteT = math.max(0.025, 0.07 - tier * 0.006)
				mote(function() local c = p.getHand(); return c and c.Position end, fx)
			end
		end

		-- CHARGE begins: rarity effects kick in
		if not state.chargeStarted and t >= w * 0.4 then
			state.chargeStarted = true
			Sounds.Play("Upgrade", 0.7 + tier * 0.08)
			if tier >= 5 then
				local pillar = neon(Vector3.new(200, 2, 2), CFrame.new(root.Position + Vector3.new(0, 97, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					tier >= 8 and Color3.fromRGB(255, 250, 225) or color, 0.35, Enum.PartType.Cylinder)
				tween(pillar, 0.3, { Size = Vector3.new(200, 4 + tier, 4 + tier) }, Enum.EasingStyle.Back)
				task.delay(math.max(0.2, w * 0.6 - THROW_AT), function()
					tween(pillar, 0.4, { Size = Vector3.new(200, 0.2, 0.2), Transparency = 1 })
					Debris:AddItem(pillar, 0.45)
				end)
				Effects.Shockwave(circle.center, color, 10 + tier * 2, 0.6)
				if tier >= 8 then Sounds.Play("Rare", 0.75) end
			end
			if tier >= 6 and not calm then
				savedExposure = Lighting.ExposureCompensation
				tween(Lighting, 0.4, { ExposureCompensation = savedExposure - 1 })
			end
		end
		if state.chargeStarted and not state.threw then
			-- Epic+: lightning crawling into the hand
			if tier >= 4 then
				state.boltT -= dt
				if state.boltT <= 0 then
					state.boltT = math.max(0.08, 0.22 - tier * 0.02)
					local from = handPos + Vector3.new(math.random(-50, 50), math.random(-20, 50), math.random(-50, 50)) / 10
					bolt(from, handPos, color, 0.12)
					if not calm then Effects.Shake(0.06 * tier, 0.12) end
				end
			end
			-- Mythical+: strikes from the sky onto you
			if tier >= 6 then
				state.skyT -= dt
				if state.skyT <= 0 then
					state.skyT = 0.32
					local top = root.Position + Vector3.new(math.random(-12, 12), 70, math.random(-12, 12))
					bolt(top, root.Position + Vector3.new(0, 4, 0), color, 0.45)
					Effects.Shockwave(circle.center, color, 6 + tier, 0.3)
				end
			end
			-- Secret: RGB split + flicker
			if split then
				state.glitchT -= dt
				if state.glitchT <= 0 then
					state.glitchT = 0.07
					local on = math.random() < 0.55
					split[1].BackgroundTransparency = on and 0.85 or 1
					split[2].BackgroundTransparency = on and 0.85 or 1
					split[1].Position = UDim2.fromOffset(math.random(-14, 14), 0)
					split[2].Position = UDim2.fromOffset(math.random(-14, 14), 0)
				end
			end
		end

		-- THROW: arm whips through, weight shifts forward
		if not state.threw and t >= w - THROW_AT then
			state.threw = true
			if split then for _, f in ipairs(split) do f.BackgroundTransparency = 1 end end
			if swing then swing:AdjustSpeed(1.9) end
			Sounds.Play("Throw", 1 + tier * 0.03)
		end

		-- RELEASE
		if not state.released and t >= w then
			state.released = true
			if orb then orb:Destroy(); orb = nil end
			if not calm then
				Effects.Flash(Color3.new(1, 1, 1), 0.12, 0.18 + tier * 0.04) -- impact frame
				Effects.Shake(0.35 + tier * 0.12, 0.3)
				speedLines(fx)
			end
			Effects.Burst(handPos, PortalBuilder.ColorSeq(p.portal), 35, 22, 0.9)
			Effects.Burst(handPos, fx, 20 + tier * 8, 26, 0.8)
			Effects.Shockwave(handPos, fx, 8 + tier * 1.5, 0.35)
			Sounds.Play("Land", 0.6)
			if p.onRelease then p.onRelease() end
		end
		if t >= w + 0.45 then
			cleanup(true)
		end
	end)
	-- safety: never leave the character anchored
	task.delay(w + 2, function()
		if active and root.Parent and root.Anchored then active.cancel() end
	end)
end

-- Camera for the cutscene (character faces +Z: front is +Z, right side is -X). No FOV squeeze.
function Cine.Camera(cs, R, savedFov)
	local t = os.clock() - cs.t0
	local w = cs.w
	local gEnd, tAt = w * 0.4, w - THROW_AT
	local desired, fov, sharp
	local function orbit(a, r, h, lookH)
		return CFrame.lookAt(R + Vector3.new(math.sin(a) * r - 0.6, h, math.cos(a) * r), R + Vector3.new(-0.6, lookH, 0))
	end
	if t < gEnd then
		local k = ease(t / gEnd)
		desired = orbit(-0.85 + 0.25 * k, 9.5 - 2 * k, 0.6 + 0.6 * k, 2.4) -- low hero angle, dolly in
		fov, sharp = savedFov, 6
	elseif t < tAt then
		local k = ease((t - gEnd) / math.max(0.05, tAt - gEnd))
		desired = orbit(-0.6 - (0.9 + cs.tier * 0.06) * k, 7.5 - 1.2 * k, 1.2 + 1.2 * k, 2.6) -- sweep to profile
		fov, sharp = savedFov - 2, 6
		if cs.tier == 7 then
			desired = desired * CFrame.new(math.random(-5, 5) / 10, math.random(-5, 5) / 10, 0)
			sharp = 30
		end
	else
		desired = CFrame.lookAt(R + Vector3.new(-2.6, 2.5, -7), R + Vector3.new(0, 3.2, 40)) -- over the shoulder
		fov, sharp = savedFov + 4, 16
	end
	return desired, fov, sharp
end

function Cine.Cancel()
	if active then active.cancel() end
end

return Cine
