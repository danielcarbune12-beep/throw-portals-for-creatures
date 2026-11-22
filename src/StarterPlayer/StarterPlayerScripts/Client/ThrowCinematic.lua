-- ThrowCinematic: the throw cutscene (owner only). Full screen, no letterbox.
-- Location: StarterPlayer > StarterPlayerScripts > Client > ThrowCinematic (ModuleScript)
--
-- A short film in up to four camera shots, with HARD CUTS between them (w = wind-up seconds sent
-- by the server, longer for rarer creatures; the ball leaves the hand exactly at w):
--
--   SHOT A  SUMMON   close-up on your open hand: energy spirals in, the portal implodes into
--                    being with orbiting rings, the world loses colour around you
--   SHOT B  POWER    low wide hero shot sweeping around you: pitcher's leg lift, torso coils,
--                    aura rises from your feet, rocks tear out of the ground and float,
--                    rarity effects escalate (lightning, light pillar, sky strikes, glitch, wings)
--   SHOT C  FOCUS    (Legendary+) extreme profile close-up, heartbeat, the arm cocked and trembling
--   SHOT D  THROW    over the shoulder down the lane: the leg plants, the ground cracks, the arm
--                    whips through leaving a light trail; impact frame, shockwave, speed lines,
--                    the floating rocks are blasted away and the camera punches forward
--
-- Common/Uncommon play A -> D, Rare/Epic play A -> B -> D, Legendary and up play all four.
-- The body is animated procedurally (Motor6D.Transform, blended over the default animations)
-- for both R15 and R6, so it works on every avatar without uploaded animations.

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
local THROW_AT = 0.42 -- seconds from the cocked pose to the release (the whip)
local RAD = math.rad
local UP = Vector3.new(0, 1, 0)
local FWD = Vector3.new(0, 0, 1) -- the lane runs along +Z
local RIGHT = Vector3.new(-1, 0, 0) -- your right while facing +Z
local SNAP = 1000 -- camera "sharpness" that means: hard cut

---------------------------------------------------------------- easing / helpers
local function c01(k) return math.clamp(k, 0, 1) end
local function lin(k) return c01(k) end
local function eOut(k) k = c01(k); return 1 - (1 - k) ^ 3 end
local function eIn(k) k = c01(k); return k * k * k end
local function eInOut(k) k = c01(k); return k < 0.5 and 4 * k * k * k or 1 - (-2 * k + 2) ^ 3 / 2 end
local function eBack(k) k = c01(k); local c1 = 1.9; return 1 + (c1 + 1) * (k - 1) ^ 3 + c1 * (k - 1) ^ 2 end

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

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

---------------------------------------------------------------- procedural body animation
-- Rotations are given in degrees {pitch X, yaw Y, roll Z} in the PARENT part's axes
-- (X = right, Y = up, Z = back). Shoulder +X raises the arm forward/up/over; knee -X bends it.
local JOINTS = {
	R15 = {
		Waist = { "UpperTorso", "Waist" }, Neck = { "Head", "Neck" },
		RSh = { "RightUpperArm", "RightShoulder" }, REl = { "RightLowerArm", "RightElbow" },
		LSh = { "LeftUpperArm", "LeftShoulder" }, LEl = { "LeftLowerArm", "LeftElbow" },
		RHip = { "RightUpperLeg", "RightHip" }, RKnee = { "RightLowerLeg", "RightKnee" },
		LHip = { "LeftUpperLeg", "LeftHip" }, LKnee = { "LeftLowerLeg", "LeftKnee" },
	},
	R6 = {
		Neck = { "Torso", "Neck" },
		RSh = { "Torso", "Right Shoulder" }, LSh = { "Torso", "Left Shoulder" },
		RHip = { "Torso", "Right Hip" }, LHip = { "Torso", "Left Hip" },
	},
}
local KEYS = { "Waist", "Neck", "RSh", "REl", "LSh", "LEl", "RHip", "RKnee", "LHip", "LKnee" }
local ZERO = { 0, 0, 0 }

local POSE = {
	IDLE = {},
	-- palm presented in front of the chest, looking down at it
	SUMMON = { Waist = { 4, -8, 0 }, Neck = { -16, -12, 0 }, RSh = { 62, -18, 8 }, REl = { 82, 0, 0 },
		LSh = { 12, 0, -10 }, LEl = { 10, 0, 0 }, RKnee = { -6, 0, 0 }, LKnee = { -6, 0, 0 } },
	-- pitcher's leg lift: torso coiled away from the lane, lead arm aiming, ball arm drawn up
	COIL = { Waist = { 8, -40, 0 }, Neck = { 4, 32, 0 }, RSh = { 195, 0, 22 }, REl = { 82, 0, 0 },
		LSh = { 90, -10, -8 }, LEl = { 8, 0, 0 }, LHip = { 72, 0, 0 }, LKnee = { -82, 0, 0 },
		RHip = { -4, 0, 0 }, RKnee = { -14, 0, 0 } },
	-- maximum tension just before the whip
	COCKED = { Waist = { 14, -56, 0 }, Neck = { 6, 46, 0 }, RSh = { 218, 0, 28 }, REl = { 102, 0, 0 },
		LSh = { 96, 16, -10 }, LEl = { 6, 0, 0 }, LHip = { 58, 0, 0 }, LKnee = { -62, 0, 0 },
		RHip = { -6, 0, 0 }, RKnee = { -22, 0, 0 } },
	-- the release frame: lead leg planted, torso fully unwound and leaning into the throw
	THROW = { Waist = { -18, 36, 0 }, Neck = { -6, -30, 0 }, RSh = { 76, 10, 12 }, REl = { 12, 0, 0 },
		LSh = { -22, 0, -18 }, LEl = { 36, 0, 0 }, LHip = { 42, 0, 0 }, LKnee = { -22, 0, 0 },
		RHip = { -28, 0, 0 }, RKnee = { -38, 0, 0 } },
	-- follow-through: arm sweeps across the body
	FOLLOW = { Waist = { -24, 44, 0 }, Neck = { -8, -34, 0 }, RSh = { 26, 36, -5 }, REl = { 22, 0, 0 },
		LSh = { -36, 0, -12 }, LEl = { 40, 0, 0 }, LHip = { 38, 0, 0 }, LKnee = { -18, 0, 0 },
		RHip = { -36, 0, 0 }, RKnee = { -56, 0, 0 } },
}

local function loadRig(char, hum)
	local map = hum.RigType == Enum.HumanoidRigType.R6 and JOINTS.R6 or JOINTS.R15
	local rig = {}
	for key, def in pairs(map) do
		local part = char:FindFirstChild(def[1])
		local m = part and part:FindFirstChild(def[2])
		-- classic Motor6D or the newer AnimationConstraint joint; both expose Transform
		local isMotor = m and m:IsA("Motor6D")
		if isMotor or (m and m:IsA("AnimationConstraint") and m.Attachment0) then
			local rot = isMotor and m.C0.Rotation or m.Attachment0.CFrame.Rotation
			rig[key] = { motor = m, rot = rot, inv = rot:Inverse() }
		end
	end
	return rig
end

local function lerpPose(a, b, k)
	local out = {}
	for _, key in ipairs(KEYS) do
		local pa, pb = a[key] or ZERO, b[key] or ZERO
		out[key] = { pa[1] + (pb[1] - pa[1]) * k, pa[2] + (pb[2] - pa[2]) * k, pa[3] + (pb[3] - pa[3]) * k }
	end
	return out
end

-- blends the pose over whatever the Animator wrote this frame (weight 0..1)
local function applyPose(rig, pose, weight)
	for key, j in pairs(rig) do
		local a = pose[key] or ZERO
		local target = j.inv * CFrame.Angles(RAD(a[1]), RAD(a[2]), RAD(a[3])) * j.rot
		local ok = pcall(function()
			j.motor.Transform = weight >= 1 and target or j.motor.Transform:Lerp(target, weight)
		end)
		if not ok then rig[key] = nil end -- some avatars lock a joint: just leave it to the Animator
	end
end

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
	return { rings = rings, glow = glow, center = center }
end

local function updateCircle(c, dt, alpha, pulse)
	for _, ring in ipairs(c.rings) do
		ring.angle += ring.speed * dt * (1 + pulse)
		for _, s in ipairs(ring.parts) do
			local a = s.a + ring.angle
			local r = ring.radius * (0.6 + 0.4 * alpha)
			s.part.CFrame = CFrame.new(c.center + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r)) * CFrame.Angles(0, -a, 0)
				* (s.rune and CFrame.Angles(0, math.rad(45), 0) or CFrame.identity)
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

-- thin rings that orbit the portal ball on tilted axes
local function orbitRings(color, count)
	local rings = {}
	for r = 1, count do
		local ring = {
			parts = {},
			tilt = CFrame.Angles(math.random() * math.pi, math.random() * math.pi, 0),
			speed = (r % 2 == 0 and -1 or 1) * (3 + r * 1.3),
			radius = 0.75 + r * 0.32,
		}
		for i = 1, 14 do
			table.insert(ring.parts, { part = neon(Vector3.new(0.3, 0.06, 0.06), CFrame.new(), color:Lerp(Color3.new(1, 1, 1), 0.35), 1), a = i / 14 * math.pi * 2 })
		end
		table.insert(rings, ring)
	end
	return rings
end
local function updateOrbitRings(rings, center, t, s, alpha)
	for _, ring in ipairs(rings) do
		local base = CFrame.new(center) * ring.tilt * CFrame.Angles(0, t * ring.speed, 0)
		local r = ring.radius * s
		for _, seg in ipairs(ring.parts) do
			seg.part.Size = Vector3.new(r * 2 * math.pi / 14 * 0.7, 0.06, 0.06)
			seg.part.CFrame = base * CFrame.Angles(0, seg.a, 0) * CFrame.new(0, 0, -r)
			seg.part.Transparency = 1 - alpha * 0.85
		end
	end
end
local function destroyOrbitRings(rings, burstCenter)
	for _, ring in ipairs(rings) do
		for _, seg in ipairs(ring.parts) do
			if burstCenter then
				local out = (seg.part.Position - burstCenter)
				tween(seg.part, 0.3, { Transparency = 1, Size = seg.part.Size * 2, CFrame = seg.part.CFrame + (out.Magnitude > 0 and out.Unit or UP) * 3 })
			else
				tween(seg.part, 0.2, { Transparency = 1 })
			end
			Debris:AddItem(seg.part, 0.35)
		end
	end
end

-- a glowing mote that spirals from a random point into the hand
local function mote(getHand, color, reach)
	local hand = getHand()
	if not hand then return end
	local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5)
	if dir.Magnitude < 0.05 then dir = UP end
	local start = hand + dir.Unit * (reach + math.random() * reach)
	local p = neon(Vector3.new(0.4, 0.4, 0.4), CFrame.new(start), color, 0.1, Enum.PartType.Ball)
	local t0, dur = os.clock(), 0.34 + math.random() * 0.14
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - t0) / dur
		local h = getHand() or hand
		if k >= 1 or not p.Parent then
			conn:Disconnect()
			p:Destroy()
			return
		end
		local e = k * k
		local swirl = CFrame.Angles(0, k * 6, 0) * (start - h) * (1 - e)
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
		local p = a + dir * (i / n)
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

-- rocks that tear out of the ground, float around you, and are blasted away on the release
local function makeRocks(center, n, color)
	local rocks = {}
	for _ = 1, n do
		local a = math.random() * math.pi * 2
		local r = 3.2 + math.random() * 6
		local s = 0.35 + math.random() * 0.85
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.Slate
		p.Color = Color3.fromRGB(72, 66, 80):Lerp(color, 0.12)
		p.Size = Vector3.new(s, s * (0.6 + math.random() * 0.5), s * (0.7 + math.random() * 0.4))
		local base = center + Vector3.new(math.cos(a) * r, -s * 0.4, math.sin(a) * r)
		p.CFrame = CFrame.new(base)
		p.Parent = Effects.Folder
		table.insert(rocks, {
			part = p, base = base, rise = 1.2 + math.random() * 4.5, ph = math.random() * 6,
			spin = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 2.5,
		})
	end
	return rocks
end
local function updateRocks(rocks, t, lift)
	for _, r in ipairs(rocks) do
		local pos = r.base + UP * (r.rise * eOut(lift) + math.sin(t * 2.2 + r.ph) * 0.25 * lift)
		r.part.CFrame = CFrame.new(pos) * CFrame.Angles(r.spin.X * t, r.spin.Y * t, r.spin.Z * t)
	end
end
local function blastRocks(rocks, center)
	for _, r in ipairs(rocks) do
		local flat = (r.part.Position - center) * Vector3.new(1, 0, 1)
		local dir = (flat.Magnitude > 0.1 and flat.Unit or FWD) + UP * 0.5
		tween(r.part, 0.75, { CFrame = r.part.CFrame * CFrame.Angles(3, 2, 1) + dir * (16 + math.random() * 16), Transparency = 1 })
		Debris:AddItem(r.part, 0.8)
	end
end

-- glowing cracks that split the ground where the lead foot lands
local function groundCracks(center, color, n)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + math.random() * 0.4
		local prev = center
		for s = 1, 4 do
			a += (math.random() - 0.5) * 0.7
			local step = 1.1 + math.random() * 1.5 - s * 0.15
			local nxt = prev + Vector3.new(math.cos(a) * step, 0, math.sin(a) * step)
			local seg = neon(Vector3.new(0.16 - s * 0.025, 0.05, step), CFrame.lookAt((prev + nxt) / 2, nxt), color:Lerp(Color3.new(1, 1, 1), 0.3), 0)
			tween(seg, 1 + s * 0.15, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(seg, 1.3 + s * 0.15)
			prev = nxt
		end
	end
end

-- wings of light behind the character (Divine)
local function makeWings(color)
	local feathers = {}
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 7 do
			local f = neon(Vector3.new(0.35, 4.6 - i * 0.28, 0.1), CFrame.new(), color:Lerp(Color3.new(1, 1, 1), 0.6), 1)
			table.insert(feathers, { part = f, side = side, i = i })
		end
	end
	return feathers
end
local function updateWings(feathers, rootCF, t, alpha)
	for _, f in ipairs(feathers) do
		local spread = (0.3 + f.i * 0.2) * (0.3 + 0.7 * alpha) + math.sin(t * 5 + f.i * 0.3) * 0.06
		f.part.CFrame = rootCF * CFrame.new(f.side * 0.6, 1.1, 0.9) * CFrame.Angles(0, 0, -f.side * spread) * CFrame.new(0, f.part.Size.Y / 2, 0)
		f.part.Transparency = 1 - alpha * 0.7
	end
end

-- radial speed lines on screen at the release
local function speedLines(color, count)
	for i = 1, count do
		local a = i / count * math.pi * 2 + math.random() * 0.2
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Size = UDim2.new(0, 2 + math.random(0, 3), 0.18 + math.random() * 0.16, 0)
		line.Position = UDim2.new(0.5 + math.sin(a) * 0.16, 0, 0.5 - math.cos(a) * 0.2, 0)
		line.Rotation = math.deg(a)
		line.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.7)
		line.BackgroundTransparency = 0.2
		line.BorderSizePixel = 0
		line.Parent = fxGui
		tween(line, 0.38, { Position = UDim2.new(0.5 + math.sin(a) * 0.65, 0, 0.5 - math.cos(a) * 0.75, 0), BackgroundTransparency = 1 })
		Debris:AddItem(line, 0.4)
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

local function emitter(parent, props)
	local pe = Instance.new("ParticleEmitter")
	pe.Rate = 0
	pe.LightEmission = 1
	pe.LightInfluence = 0
	for k, v in pairs(props) do pe[k] = v end
	pe.Parent = parent
	return pe
end

---------------------------------------------------------------- shot plan
-- times (seconds from the start) of every shot boundary for this wind-up and tier
local function plan(w, tier)
	local tAt = w - THROW_AT
	local ph = { w = w, tAt = tAt, tier = tier }
	if tier <= 2 then
		ph.aEnd, ph.bEnd, ph.cEnd = tAt * 0.5, tAt * 0.5, tAt * 0.5 -- A, then straight to the throw shot
	elseif tier <= 4 then
		ph.aEnd, ph.bEnd, ph.cEnd = tAt * 0.38, tAt, tAt
	else
		ph.aEnd, ph.bEnd, ph.cEnd = tAt * 0.3, tAt * 0.72, tAt
	end
	ph.formAt = math.min(0.32, ph.aEnd * 0.45) -- the portal pops into existence
	ph.keys = {
		{ t = 0, pose = POSE.IDLE },
		{ t = math.min(0.4, ph.aEnd * 0.7), pose = POSE.SUMMON, ease = eOut },
		{ t = ph.aEnd, pose = POSE.SUMMON, ease = lin },
		{ t = ph.aEnd + (tAt - ph.aEnd) * 0.6, pose = POSE.COIL, ease = eInOut },
		{ t = tAt, pose = POSE.COCKED, ease = eInOut },
		{ t = w, pose = POSE.THROW, ease = eIn }, -- accelerates: the whip
		{ t = w + 0.22, pose = POSE.FOLLOW, ease = eOut },
		{ t = w + 0.7, pose = POSE.IDLE, ease = eInOut },
	}
	return ph
end

local function samplePose(ph, t)
	local keys = ph.keys
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b.t then
			return lerpPose(a.pose, b.pose, b.ease((t - a.t) / math.max(1e-3, b.t - a.t)))
		end
	end
	return keys[#keys].pose
end

---------------------------------------------------------------- the cutscene
local active = nil
local cur = nil -- shared with Cine.Camera: plan + live hand/head positions

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
	local tier, color, w = p.tier or 1, p.color or Color3.fromRGB(190, 200, 215), math.max(p.w or 1, 0.9)
	local fx = tier >= 3 and color or PortalBuilder.ColorSeq(p.portal).Keypoints[1].Value
	local calm = p.calm
	local ph = plan(w, tier)
	local t0 = os.clock()
	local baseCF = CFrame.lookAt(root.Position, root.Position + FWD)
	-- the forward stride must never push you into the Launch Hall's force field (Z = 5..7)
	local stepDist = math.clamp(3.5 - root.Position.Z, 0, 1.6)
	local wasAnchored, wasAutoRotate = root.Anchored, hum.AutoRotate
	root.Anchored = true
	hum.AutoRotate = false
	root.CFrame = baseCF

	local rig = loadRig(char, hum)
	local feetDrop = hum.RigType == Enum.HumanoidRigType.R6 and 3 or (hum.HipHeight + root.Size.Y / 2)
	local ground = root.Position - Vector3.new(0, feetDrop - 0.05, 0)
	local head = char:FindFirstChild("Head")
	local handPart = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")

	cur = { ph = ph, t0 = t0, hand = nil, head = nil }

	-- props
	local orb, orbRefs = PortalBuilder.BuildOrb(p.portal, 0.45)
	orb.Parent = Effects.Folder
	if orbRefs.light then orbRefs.light.Color = fx end
	orb:ScaleTo(0.05)
	local rings = orbitRings(fx, tier >= 3 and 3 or 2)
	local circle = runeCircle(ground, fx, tier)
	local rocks = tier >= 3 and makeRocks(ground, 3 + tier * 2, fx) or {}
	local wings = tier >= 8 and makeWings(color) or nil
	local split = (tier == 7 and not calm) and glitchSplit() or nil
	local halo = tier >= 8 and neon(Vector3.new(0.2, 2.6, 2.6), CFrame.new(), Color3.fromRGB(255, 240, 180), 1, Enum.PartType.Cylinder) or nil

	-- aura from the feet, flames for Legendary+, falling feathers for Divine
	local feet = Instance.new("Attachment")
	feet.Position = Vector3.new(0, -feetDrop + 0.2, 0)
	feet.Parent = root
	local aura = emitter(feet, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(fx),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(4, 9), SpreadAngle = Vector2.new(28, 28),
		Lifetime = NumberRange.new(0.5, 1.1), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	})
	local flames = tier >= 5 and emitter(feet, {
		Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(fx, Color3.new(1, 1, 1)),
		EmissionDirection = Enum.NormalId.Top, Speed = NumberRange.new(5, 10), SpreadAngle = Vector2.new(14, 14),
		Lifetime = NumberRange.new(0.4, 0.8), Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Shape = Enum.ParticleEmitterShape.Disc, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	}) or nil
	if flames then flames.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward end
	local feathers = nil
	if tier >= 8 then
		local sky = Instance.new("Attachment")
		sky.Position = Vector3.new(0, 9, 0)
		sky.Parent = root
		feathers = emitter(sky, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(Color3.fromRGB(255, 236, 170)),
			EmissionDirection = Enum.NormalId.Bottom, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(80, 80),
			Acceleration = Vector3.new(0, -2, 0), Lifetime = NumberRange.new(2, 3), RotSpeed = NumberRange.new(-90, 90),
			Size = NumberSequence.new(0.35), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		})
	end

	-- light trail behind the throwing hand (only during the whip)
	local trail
	if handPart then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position = Vector3.new(0, 0.3, 0), Vector3.new(0, -0.9, 0)
		a0.Parent, a1.Parent = handPart, handPart
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = ColorSequence.new(Color3.new(1, 1, 1), fx)
		trail.LightEmission = 1
		trail.Lifetime = 0.28
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		trail.Enabled = false
		trail.Parent = handPart
		Debris:AddItem(a0, w + 3)
		Debris:AddItem(a1, w + 3)
		Debris:AddItem(trail, w + 3)
	end

	-- colour grade of the whole world (desaturates, tints, impact frame)
	local grade
	if not calm then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "ThrowGrade"
		grade.Parent = Lighting
	end

	Sounds.Play("Open", 0.8 + tier * 0.03)

	local state = { formed = false, powered = false, threw = false, released = false, focusBeat = 0,
		moteT = 0, boltT = 0, skyT = 0, glitchT = 0, waveT = 0 }
	local savedExposure = nil
	local renderConn, poseConn
	local function cleanup(final)
		if renderConn then renderConn:Disconnect(); renderConn = nil end
		if poseConn then poseConn:Disconnect(); poseConn = nil end
		for _, j in pairs(rig) do pcall(function() j.motor.Transform = CFrame.identity end) end
		if orb then orb:Destroy(); orb = nil end
		destroyOrbitRings(rings, nil)
		destroyCircle(circle)
		if not state.released then
			for _, r in ipairs(rocks) do tween(r.part, 0.3, { Transparency = 1 }); Debris:AddItem(r.part, 0.35) end
		end
		if wings then for _, f in ipairs(wings) do tween(f.part, 0.3, { Transparency = 1 }); Debris:AddItem(f.part, 0.35) end end
		if halo then tween(halo, 0.3, { Transparency = 1 }); Debris:AddItem(halo, 0.35) end
		if split then for _, f in ipairs(split) do f:Destroy() end end
		if trail then trail.Enabled = false end
		aura.Rate = 0
		if flames then flames.Rate = 0 end
		if feathers then feathers.Rate = 0; Debris:AddItem(feathers.Parent, 3) end
		Debris:AddItem(feet, 1.2)
		if grade then
			tween(grade, 0.3, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
			Debris:AddItem(grade, 0.35)
		end
		if savedExposure then tween(Lighting, 0.6, { ExposureCompensation = savedExposure }); savedExposure = nil end
		if root.Parent then
			root.Anchored = wasAnchored
			hum.AutoRotate = wasAutoRotate
		end
		active = nil
		cur = nil
	end
	active = { cancel = function()
		local wasReleased = state.released
		cleanup(false)
		if not wasReleased and p.onRelease then p.onRelease() end
	end }

	-- weight of the procedural pose over the default animations
	local function poseWeight(t)
		return math.min(eOut(t / 0.2), 1 - eInOut((t - (w + 0.4)) / 0.4))
	end

	-- BODY: written every frame after the Animator, so it wins
	poseConn = RunService.Stepped:Connect(function()
		local t = os.clock() - t0
		local pose = samplePose(ph, t)
		if t > ph.aEnd and t < w then
			-- trembling with power, stronger for rarer creatures
			local amp = (0.3 + tier * 0.25) * c01((t - ph.aEnd) / math.max(0.05, ph.tAt - ph.aEnd))
			pose.RSh[1] += math.sin(t * 47) * amp
			pose.Waist[2] += math.sin(t * 39) * amp * 0.5
		elseif t <= ph.aEnd then
			pose.RSh[1] += math.sin(t * 3) * 2 -- the hand gently bobs while the portal forms
		end
		applyPose(rig, pose, poseWeight(t))
	end)

	local function rootCF(t)
		local step = 0
		if t >= ph.tAt then
			step = stepDist * eOut((t - ph.tAt) / THROW_AT)
		end
		local cf = baseCF * CFrame.new(0, 0, -step)
		if not rig.Waist then
			-- R6 has no waist joint: lean/turn the whole body instead
			local pose = samplePose(ph, t)
			local wst = pose.Waist or ZERO
			local k = poseWeight(t) * 0.6
			cf *= CFrame.Angles(RAD(wst[1]) * k, RAD(wst[2]) * k, 0)
		end
		return cf
	end

	renderConn = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - t0
		if not root.Parent or hum.Health <= 0 then
			active.cancel()
			return
		end
		root.CFrame = rootCF(t)
		local hcf = p.getHand()
		local handPos = hcf and hcf.Position or (root.Position + Vector3.new(-0.8, 1.5, 1))
		local blend = 1 - math.exp(-16 * dt)
		cur.hand = cur.hand and cur.hand:Lerp(handPos, blend) or handPos
		cur.head = head and head.Position or (root.Position + UP * 1.6)
		local power = c01((t - ph.aEnd) / math.max(0.05, ph.tAt - ph.aEnd)) -- 0 at summon .. 1 cocked
		local pulse = (math.sin(t * (6 + tier * 1.5)) + 1) / 2

		-- SHOT A: the portal forms in the hand
		local formK = c01((t - ph.formAt) / 0.38)
		if not state.formed and t >= ph.formAt then
			state.formed = true
			Sounds.Play("Collect", 0.55)
			Effects.Burst(handPos, fx, 14 + tier * 3, 7, 0.5)
			Effects.Shockwave(handPos, fx, 3 + tier * 0.4, 0.3)
		end
		local orbPos = hcf and (hcf * CFrame.new(0, -1.0, 0)).Position or handPos
		local s = (state.formed and eBack(formK) or 0.05) * (1 + power * (0.25 + tier * 0.03) + pulse * 0.04 * tier)
		if orb then
			orb:PivotTo(hcf and (hcf * CFrame.new(0, -1.0, 0)) or CFrame.new(orbPos))
			orb:ScaleTo(math.max(0.05, s))
			PortalBuilder.Spin(orbRefs, t * (2 + tier * 0.8 + power * 4))
			if orbRefs.light then orbRefs.light.Range = 5 + power * (8 + tier * 2) end
			updateOrbitRings(rings, orbPos, t, math.max(0.1, s), formK)
		end
		updateCircle(circle, dt, eOut(t / 0.4) * (state.released and math.max(0, 1 - (t - w) / 0.3) or 1), pulse)
		if not state.released then updateRocks(rocks, t, power) end
		if wings then updateWings(wings, root.CFrame, t, eOut(power)) end
		if halo then
			halo.CFrame = root.CFrame * CFrame.new(0, 3.6 + math.sin(t * 3) * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
			halo.Transparency = 1 - eOut(power) * 0.6
		end
		if not state.threw then
			aura.Rate = tier >= 2 and power * (8 + tier * 9) or 0
			if flames then flames.Rate = power * (10 + tier * 4) end
			if feathers then feathers.Rate = power * 14 end
		end

		-- energy streaming into the hand
		if not state.threw then
			state.moteT -= dt
			if state.moteT <= 0 then
				state.moteT = math.max(0.02, (t < ph.formAt and 0.035 or 0.08) - tier * 0.006)
				mote(function() return cur and cur.hand end, fx, t < ph.formAt and 3 or 4 + tier * 0.5)
			end
		end

		-- SHOT B begins: the power-up
		if not state.powered and t >= ph.aEnd then
			state.powered = true
			Sounds.Play("Upgrade", 0.6 + tier * 0.08)
			Effects.Shockwave(ground, fx, 8 + tier * 2, 0.5)
			if tier >= 5 then
				local pillar = neon(Vector3.new(220, 2, 2), CFrame.new(root.Position + Vector3.new(0, 107, 0)) * CFrame.Angles(0, 0, math.pi / 2),
					tier >= 8 and Color3.fromRGB(255, 250, 225) or color, 0.35, Enum.PartType.Cylinder)
				tween(pillar, 0.3, { Size = Vector3.new(220, 4 + tier, 4 + tier) }, Enum.EasingStyle.Back)
				task.delay(math.max(0.2, ph.tAt - ph.aEnd), function()
					tween(pillar, 0.4, { Size = Vector3.new(220, 0.2, 0.2), Transparency = 1 })
					Debris:AddItem(pillar, 0.45)
				end)
				if tier >= 8 then Sounds.Play("Rare", 0.75) end
			end
			if tier >= 5 and not calm then
				savedExposure = Lighting.ExposureCompensation
				tween(Lighting, 0.5, { ExposureCompensation = savedExposure - (tier >= 6 and 1.1 or 0.6) })
			end
		end
		if state.powered and not state.threw then
			-- pulsing wind rings at your feet
			state.waveT -= dt
			if state.waveT <= 0 and tier >= 2 then
				state.waveT = math.max(0.22, 0.6 - tier * 0.05)
				Effects.Shockwave(ground, fx, 4 + tier + power * 4, 0.45)
			end
			-- Epic+: lightning crawling into the hand
			if tier >= 4 then
				state.boltT -= dt
				if state.boltT <= 0 then
					state.boltT = math.max(0.07, 0.22 - tier * 0.02)
					local from = handPos + Vector3.new(math.random(-50, 50), math.random(-20, 50), math.random(-50, 50)) / 10
					bolt(from, handPos, color, 0.12)
					if not calm then Effects.Shake(0.05 * tier, 0.1) end
				end
			end
			-- Mythical+: strikes from the sky
			if tier >= 6 then
				state.skyT -= dt
				if state.skyT <= 0 then
					state.skyT = 0.3
					local top = root.Position + Vector3.new(math.random(-14, 14), 80, math.random(-14, 14))
					local hit = ground + Vector3.new(math.random(-9, 9), 0, math.random(-9, 9))
					bolt(top, hit, color, 0.5)
					Effects.Shockwave(hit, color, 5 + tier * 0.5, 0.3)
					Effects.Burst(hit, color, 8, 14, 0.6)
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
		-- SHOT C: heartbeat while the arm trembles
		if tier >= 5 and t >= ph.bEnd and t < ph.tAt then
			state.focusBeat -= dt
			if state.focusBeat <= 0 then
				state.focusBeat = 0.42
				Sounds.Play("Land", 0.32)
			end
		end

		-- colour grade
		if grade then
			local gIn = eOut(t / 0.45)
			local hold = math.max(0.35, power)
			local sat = -(0.2 + 0.07 * tier * hold) * gIn
			local con = (0.08 + 0.035 * tier * hold) * gIn
			local tint = Color3.new(1, 1, 1):Lerp(fx, (0.03 + 0.018 * tier) * hold * gIn)
			local bri = -0.012 * tier * hold * gIn
			if state.released then
				local since = t - w
				if since < 0.07 then
					sat, con, bri, tint = -1, 1.3, 0.22, Color3.new(1, 1, 1) -- impact frame
				else
					local d = 1 - eOut((since - 0.07) / 0.5)
					sat, con, bri = sat * d, con * d, bri * d
					tint = Color3.new(1, 1, 1):Lerp(tint, d)
				end
			end
			grade.Saturation, grade.Contrast, grade.Brightness, grade.TintColor = sat, con, bri, tint
		end

		-- SHOT D: the whip
		if not state.threw and t >= ph.tAt then
			state.threw = true
			if split then for _, f in ipairs(split) do f.BackgroundTransparency = 1 end end
			if trail then trail.Enabled = true end
			aura.Rate = 0
			if flames then flames.Rate = 0 end
			Sounds.Play("Whoosh", 0.7 + tier * 0.03)
			task.delay(THROW_AT * 0.55, function() Sounds.Play("Throw", 1 + tier * 0.03) end)
		end

		-- RELEASE
		if not state.released and t >= w then
			state.released = true
			if orb then orb:Destroy(); orb = nil end
			destroyOrbitRings(rings, cur and cur.hand or handPos)
			rings = {}
			local plant = root.Position + FWD * 1.2 - Vector3.new(0, feetDrop - 0.05, 0)
			if not calm then
				Effects.Flash(Color3.new(1, 1, 1), 0.1, 0.12 + tier * 0.03)
				Effects.Shake(0.4 + tier * 0.13, 0.32)
				speedLines(fx, 16 + tier * 3)
			end
			Effects.Burst(handPos, PortalBuilder.ColorSeq(p.portal), 35, 24, 0.9)
			Effects.Burst(handPos, fx, 20 + tier * 8, 28, 0.8)
			Effects.Shockwave(handPos, fx, 8 + tier * 1.5, 0.35)
			Effects.Shockwave(plant, fx, 10 + tier * 2.5, 0.5)
			Effects.Burst(plant, ColorSequence.new(Color3.fromRGB(225, 215, 200)), 14 + tier * 2, 9, 1.3, "rbxasset://textures/particles/smoke_main.dds")
			if tier >= 3 then groundCracks(plant, fx, 4 + tier) end
			blastRocks(rocks, ground)
			Sounds.Play("Land", 0.45)
			if tier >= 5 then Sounds.Play("Land", 0.3) end
			if p.onRelease then p.onRelease() end
		end
		if trail and state.released and t >= w + 0.25 then trail.Enabled = false end
		if t >= w + 0.82 then
			cleanup(true)
		end
	end)
	-- safety: never leave the character anchored
	task.delay(w + 2.5, function()
		if active and root.Parent and root.Anchored then active.cancel() end
	end)
end

---------------------------------------------------------------- camera
-- Returns desired CFrame, FOV and sharpness. A sharpness of SNAP (1000) is a hard cut: the caller
-- jumps straight to the new shot (position and FOV). Character faces +Z; its right is -X.
function Cine.Camera(cs, R, savedFov)
	local t = os.clock() - cs.t0
	local ph = (cur and cur.ph) or plan(cs.w, cs.tier or 1)
	local w, tier = ph.w, ph.tier
	local hand = (cur and cur.hand) or (R + Vector3.new(-0.8, 1.5, 1))
	local headP = (cur and cur.head) or (R + UP * 1.6)
	local shot, desired, fov, sharp
	local function around(center, a, r, h)
		return center + FWD * math.cos(a) * r + RIGHT * math.sin(a) * r + UP * h
	end

	if t < ph.aEnd then
		-- A: low close-up on the hand from the front-right, pushing in
		shot = "A"
		local k = eOut(t / ph.aEnd)
		local look = hand:Lerp(headP, 0.22)
		desired = CFrame.lookAt(around(hand, 0.95 - 0.35 * k, 4.4 - 1.4 * k, -0.7 + 0.3 * k), look)
		fov, sharp = savedFov - 10, 22
	elseif t < ph.bEnd then
		-- B: wide, low hero shot sweeping across your front
		shot = "B"
		local k = (t - ph.aEnd) / math.max(0.05, ph.bEnd - ph.aEnd)
		local e = eInOut(k)
		local r = (tier >= 8 and 13 or 11.5) - 2.2 * e
		desired = CFrame.lookAt(around(R, -1.0 + 1.25 * e, r, -1.7 + 0.5 * e), R + UP * (tier >= 8 and 2.2 or 1.4))
		if tier >= 6 then
			desired *= CFrame.new((math.random() - 0.5) * 0.12 * tier / 6, (math.random() - 0.5) * 0.12 * tier / 6, 0)
		end
		fov, sharp = savedFov - 2, 20
	elseif t < ph.tAt then
		-- C: extreme profile close-up, slow push, trembling
		shot = "C"
		local k = eOut((t - ph.bEnd) / math.max(0.05, ph.tAt - ph.bEnd))
		local look = headP + FWD * 0.3 + UP * 0.2
		local pos = look + RIGHT * (4 - 1.2 * k) + FWD * (1.6 - 0.4 * k) - UP * 0.15
		local jit = 0.03 + 0.05 * k
		desired = CFrame.lookAt(pos, look) * CFrame.new((math.random() - 0.5) * jit, (math.random() - 0.5) * jit, 0)
		if tier == 7 then desired *= CFrame.new((math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.4, 0) end
		fov, sharp = savedFov - 14, 30
	else
		-- D: over the right shoulder, low, looking down the lane; dollies in and punches on release
		shot = "D"
		local start = math.min(ph.cEnd, ph.tAt)
		local k = eOut((t - start) / math.max(0.3, w + 0.3 - start))
		desired = CFrame.lookAt(R - FWD * (7 - 2.2 * k) + RIGHT * 2.4 + UP * (1.6 + 0.4 * k), R + FWD * 40 + UP * 4)
		fov = savedFov - 4
		if t >= w then
			fov = savedFov + 4 + 14 * math.exp(-(t - w) * 6)
		end
		sharp = 28
	end
	if cs.lastShot ~= shot then
		cs.lastShot = shot
		sharp = SNAP -- hard cut to the new shot
	end
	return desired, fov, sharp
end

function Cine.Cancel()
	if active then active.cancel() end
end

return Cine
