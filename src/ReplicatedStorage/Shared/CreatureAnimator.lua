-- CreatureAnimator: procedural, physics-feel animation for rigs from CreatureBuilder.
-- Location: ReplicatedStorage > Shared > CreatureAnimator (ModuleScript)
--
-- Features: unique idle per personality, hop / walk / run / fly / float / slither
-- locomotion with squash & stretch, blinking, eye tracking, ear twitches, wing flaps,
-- tail wags with follow-through, reactions (happy hop + hearts), and a scale factor
-- used for pop-in reveals. Pure client-side; call anim:Step(dt) every frame.

local Animator = {}
Animator.__index = Animator

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local sin, cos, abs, clamp, rad = math.sin, math.cos, math.abs, math.clamp, math.rad

local function scaledCF(cf, s)
	return CFrame.new(cf.Position * s) * cf.Rotation
end

local function springTo(cur, target, k, dt)
	return cur + (target - cur) * (1 - math.exp(-k * dt))
end

function Animator.new(rig, startCFrame: CFrame?)
	local def = rig.def
	local self = setmetatable({}, Animator)
	self.rig = rig
	self.def = def
	self.t = math.random() * 10
	self.seed = math.random() * 100
	local cf = startCFrame or rig.root.CFrame
	self.pos = cf.Position
	local _, yaw = cf:ToEulerAnglesYXZ()
	self.yaw = yaw
	self.targetYaw = yaw
	self.scale = 1
	self._appliedScale = -1
	self.moveTarget = nil
	self.moveSpeed = 6
	self.moving = false
	self.hopPhase = 0
	self.jumpT = nil
	self.reactT = nil
	self.reactKind = nil
	self.spinT = nil
	self.blinkTimer = 1 + math.random() * 3
	self.blinkT = nil
	self.twitchT = 0
	self.look = nil         -- world position to look at
	self.lookAmt = 0
	self.speedNow = 0
	self.lean = 0
	self.landSquash = 0
	self.home = nil
	self.homeRadius = 10
	self.idleTimer = 1 + math.random() * 3
	self.flying = (def.move == "fly")
	self.hover = (def.move == "fly" and 2.6) or ((def.move == "float" or def.move == "slither") and 0.6) or 0
	self.groundY = self.pos.Y

	-- burst emitter for reactions
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 220, 120))
	pe.LightEmission = 1
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1.1)
	pe.Speed = NumberRange.new(4, 7)
	pe.SpreadAngle = Vector2.new(60, 60)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Acceleration = Vector3.new(0, -6, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = rig.head or rig.body
	self.burst = pe
	return self
end

---------------------------------------------------------------- control API
function Animator:SetHome(center: Vector3, radius: number)
	self.home = center
	self.homeRadius = radius
	self.groundY = center.Y
end

function Animator:MoveTo(pos: Vector3, speed: number?)
	self.moveTarget = pos
	self.moveSpeed = speed or (self.def.move == "fly" and 9 or 6)
end

function Animator:Teleport(cf: CFrame)
	self.pos = cf.Position
	self.groundY = cf.Position.Y
	local _, yaw = cf:ToEulerAnglesYXZ()
	self.yaw, self.targetYaw = yaw, yaw
end

function Animator:Jump()
	if not self.jumpT then self.jumpT = 0 end
end

function Animator:React(kind: string?)
	self.reactKind = kind or "happy"
	self.reactT = 0
	if self.reactKind == "happy" then
		self.burst:Emit(8)
		self:Jump()
	elseif self.reactKind == "spin" then
		self.spinT = 0
	end
end

function Animator:LookAt(pos: Vector3?)
	self.look = pos
end

function Animator:SetScale(s: number)
	self.scale = s
end

---------------------------------------------------------------- internals
function Animator:_applyScale()
	local s = self.scale
	if abs(s - self._appliedScale) < 0.001 then return end
	self._appliedScale = s
	for _, e in ipairs(self.rig.all) do
		e.w.C0 = scaledCF(e.c0, s)
		e.w.C1 = scaledCF(e.c1, s)
		if e.mesh then e.mesh.Scale = Vector3.one * s end
	end
end

function Animator:_set(e, extra: CFrame)
	e.w.C0 = scaledCF(e.c0, self.scale) * extra
end

function Animator:_brain(dt)
	if not self.home or self.moveTarget then return end
	self.idleTimer -= dt
	if self.idleTimer <= 0 then
		self.idleTimer = 2.5 + math.random() * 4
		local a = math.random() * math.pi * 2
		local r = math.random() * self.homeRadius
		local run = math.random() < 0.2
		self:MoveTo(self.home + Vector3.new(cos(a) * r, 0, sin(a) * r), run and 11 or nil)
		if math.random() < 0.15 then self.spinT = 0 end
	end
end

function Animator:Step(dt: number)
	dt = math.min(dt, 0.1)
	self.t += dt
	local t = self.t
	local rig, def = self.rig, self.def
	self:_applyScale()
	self:_brain(dt)

	-------------------------------------------------- locomotion
	local moving = false
	if self.moveTarget then
		local delta = (self.moveTarget - self.pos) * Vector3.new(1, 0, 1)
		local dist = delta.Magnitude
		if dist < 0.6 then
			self.moveTarget = nil
		else
			moving = true
			local dir = delta.Unit
			self.targetYaw = math.atan2(-dir.X, -dir.Z)
			local step = math.min(dist, self.moveSpeed * dt)
			if def.move == "hop" then
				-- only advance while airborne -> real hopping feel
				local ph = (self.hopPhase % 1)
				step = (ph < 0.75) and step * 1.6 or 0
			end
			self.pos += dir * step
		end
	end
	local targetSpeed = moving and self.moveSpeed or 0
	self.speedNow = springTo(self.speedNow, targetSpeed, 8, dt)
	local running = self.speedNow > 8

	-- smooth turning
	local dy = (self.targetYaw - self.yaw + math.pi) % (math.pi * 2) - math.pi
	self.yaw += dy * (1 - math.exp(-8 * dt))
	self.lean = springTo(self.lean, clamp(dy * 1.5, -0.5, 0.5), 6, dt)

	-------------------------------------------------- vertical / body motion
	local y = self.hover
	local bob, tiltX, tiltZ, yawWiggle = 0, 0, 0, 0
	local sqY = 1
	local hopRate = running and 3.2 or 2.2
	local spd = self.speedNow / math.max(self.moveSpeed, 1)

	if def.move == "hop" then
		if moving or (self.hopPhase % 1) > 0.02 then
			local before = self.hopPhase % 1
			self.hopPhase += dt * hopRate
			local ph = self.hopPhase % 1
			if ph < before then self.landSquash = 1 end -- just landed
			if not moving and ph < 0.05 then self.hopPhase = math.floor(self.hopPhase) end
			if ph < 0.75 then
				local k = ph / 0.75
				bob = sin(k * math.pi) * 1.4
				sqY = 1 + sin(k * math.pi) * 0.12
				tiltX = (0.5 - k) * 0.4
			end
		end
	elseif def.move == "walk" then
		bob = abs(sin(t * 9 * (running and 1.4 or 1))) * 0.18 * spd
		tiltZ = sin(t * 9) * 0.06 * spd
		tiltX = -0.08 * spd - (running and 0.12 or 0)
	elseif def.move == "fly" then
		bob = sin(t * 2.4 + self.seed) * 0.5
		tiltX = -0.3 * spd
		tiltZ = -self.lean * 0.8
	elseif def.move == "float" then
		bob = sin(t * 1.6 + self.seed) * 0.35
		tiltX = -0.15 * spd
		tiltZ = sin(t * 1.1) * 0.06
	elseif def.move == "slither" then
		bob = sin(t * 1.8 + self.seed) * 0.25
		yawWiggle = sin(t * 6) * 0.25 * (0.3 + spd)
		tiltZ = sin(t * 6 + 1) * 0.12
	end

	-------------------------------------------------- idle personality (only when still)
	local idleW = 1 - clamp(spd, 0, 1)
	local headYaw, headPitch, headRoll = 0, 0, 0
	local armRaise = 0
	local idle = def.idle
	if idleW > 0.01 then
		if idle == "bounce" then
			local ph = (t * 0.9 + self.seed) % 3
			if ph < 0.5 then
				local k = ph / 0.5
				bob += sin(k * math.pi) * 0.7 * idleW
				sqY *= 1 + sin(k * math.pi * 2) * 0.1
			end
			sqY *= 1 + sin(t * 3) * 0.03
		elseif idle == "sway" then
			tiltZ += sin(t * 1.5) * 0.12 * idleW
			headRoll = sin(t * 1.5 + 0.6) * 0.15
		elseif idle == "wiggle" then
			yawWiggle += sin(t * 14) * 0.12 * idleW * (sin(t * 0.7) > 0.3 and 1 or 0.2)
		elseif idle == "proud" then
			tiltX += 0.08 * idleW
			headYaw = sin(t * 0.5 + self.seed) * 0.5
			headPitch = 0.12
		elseif idle == "float" then
			bob += sin(t * 1.2) * 0.25 * idleW
			tiltX += sin(t * 0.8) * 0.05
		elseif idle == "peek" then
			headRoll = sin(t * 0.9 + self.seed) * 0.3
			headYaw = sin(t * 0.45 + self.seed) * 0.35
		elseif idle == "dance" then
			bob += abs(sin(t * 4)) * 0.3 * idleW
			yawWiggle += sin(t * 2) * 0.35 * idleW
			tiltZ += sin(t * 4) * 0.08 * idleW
			armRaise = (sin(t * 4) * 0.5 + 0.5) * idleW
		elseif idle == "spin" then
			if (t + self.seed) % 6 < 0.05 and not self.spinT then self.spinT = 0 end
		end
		-- breathing for everyone
		sqY *= 1 + sin(t * 2.2 + self.seed) * 0.025
	end

	-------------------------------------------------- jumps / reactions / spins
	if self.jumpT then
		self.jumpT += dt
		local k = self.jumpT / 0.55
		if k >= 1 then self.jumpT = nil; self.landSquash = 1
		else
			bob += sin(k * math.pi) * 2.2
			sqY *= 1 + sin(k * math.pi) * 0.15
		end
	end
	local spinYaw = 0
	if self.spinT then
		self.spinT += dt
		local k = clamp(self.spinT / 0.7, 0, 1)
		local e = 1 - (1 - k) ^ 3
		spinYaw = e * math.pi * 2
		if k >= 1 then self.spinT = nil; spinYaw = 0 end
	end
	local mouthOpen = 0
	if self.reactT then
		self.reactT += dt
		armRaise = math.max(armRaise, 1 - clamp(self.reactT / 1.2, 0, 1))
		mouthOpen = 1 - clamp(self.reactT / 1, 0, 1)
		if self.reactT > 1.2 then self.reactT = nil end
	end
	-- landing squash spring
	if self.landSquash > 0.001 then
		sqY *= 1 - self.landSquash * 0.22
		self.landSquash = springTo(self.landSquash, 0, 10, dt)
	end
	local sqXZ = 1 / math.sqrt(math.max(sqY, 0.5))

	-------------------------------------------------- apply root + body
	local rootCF = CFrame.new(self.pos.X, self.groundY, self.pos.Z) * CFrame.Angles(0, self.yaw + spinYaw, 0)
	rig.root.CFrame = rootCF
	local be = rig.bodyEntry
	if be then
		self:_set(be, CFrame.new(0, (y + bob) * self.scale, 0) * CFrame.Angles(tiltX, yawWiggle, tiltZ))
		be.mesh.Scale = Vector3.new(sqXZ, sqY, sqXZ) * self.scale
	end

	-------------------------------------------------- head look
	if self.look then
		local localLook = rootCF:PointToObjectSpace(self.look)
		local wantYaw = math.atan2(-localLook.X, -localLook.Z)
		if abs(wantYaw) < 2 then
			headYaw = clamp(wantYaw, -0.7, 0.7)
			self.lookAmt = springTo(self.lookAmt, 1, 6, dt)
		end
	else
		self.lookAmt = springTo(self.lookAmt, 0, 3, dt)
	end
	if rig.headEntry then
		self:_set(rig.headEntry, CFrame.Angles(headPitch + sin(t * 2.2) * 0.03, headYaw, headRoll))
	elseif headYaw ~= 0 or headRoll ~= 0 then
		-- head == body: turn the whole body a bit instead
		self:_set(be, CFrame.new(0, (y + bob) * self.scale, 0) * CFrame.Angles(tiltX, yawWiggle + headYaw * 0.4, tiltZ + headRoll * 0.4))
	end

	-------------------------------------------------- eyes: blink + pupils
	self.blinkTimer -= dt
	if self.blinkTimer <= 0 then
		self.blinkT = 0
		self.blinkTimer = 2 + math.random() * 3.5
		if math.random() < 0.2 then self.blinkTimer = 0.25 end -- double blink
	end
	local lid = 1
	if self.blinkT then
		self.blinkT += dt
		local k = self.blinkT / 0.14
		lid = (k < 0.5) and (1 - k * 1.8) or (0.1 + (k - 0.5) * 1.8)
		if k >= 1 then self.blinkT = nil; lid = 1 end
	end
	if mouthOpen > 0.5 then lid = math.min(lid, 0.35 + (1 - mouthOpen)) end -- happy squint
	for _, e in ipairs(rig.eyes) do
		e.mesh.Scale = Vector3.new(1, clamp(lid, 0.08, 1), 1) * self.scale
	end
	local px, py = sin(t * 0.37 + self.seed) * 0.06, sin(t * 0.23) * 0.04
	if self.look then px = clamp(-headYaw * 0.15, -0.1, 0.1) end
	for _, e in ipairs(rig.pupils) do
		self:_set(e, CFrame.new(px * self.scale, py * self.scale, 0))
	end
	if rig.mouth then
		rig.mouth.mesh.Scale = Vector3.new(1 + mouthOpen * 0.2, 1 + mouthOpen * 2.2, 1) * self.scale
	end

	-------------------------------------------------- ears (twitch)
	self.twitchT -= dt
	local twitch = 0
	if self.twitchT < 0 then
		if self.twitchT < -0.25 then self.twitchT = 1.5 + math.random() * 3 end
		twitch = sin((-self.twitchT) / 0.25 * math.pi) * 0.35
	end
	for i, ear in ipairs(rig.ears) do
		local a = sin(t * 2 + i) * 0.06 + (i == 1 and twitch or 0) - armRaise * 0.2
		self:_set(ear.e, CFrame.Angles(sin(t * 9) * 0.08 * spd, 0, -ear.side * a))
	end

	-------------------------------------------------- wings
	local flapSpeed = (def.move == "fly") and (14 + spd * 6) or 3
	local flapAmp = (def.move == "fly") and 0.75 or 0.12
	if def.wings == "bug" then flapSpeed *= 2.2; flapAmp *= 0.6 end
	if def.body == "fish" then flapSpeed = 5; flapAmp = 0.35 end
	for _, w in ipairs(rig.wings) do
		local f = sin(t * flapSpeed) * flapAmp
		self:_set(w.e, CFrame.Angles(0, 0, w.side * f))
	end

	-------------------------------------------------- tail with follow-through
	local wagSpeed = (idle == "wiggle" or self.reactT) and 14 or 3.5 + spd * 4
	for i, e in ipairs(rig.tail) do
		local ph = t * wagSpeed - i * 0.6
		self:_set(e, CFrame.Angles(sin(ph * 0.5) * 0.08, sin(ph) * (0.25 + i * 0.03), 0))
	end

	-------------------------------------------------- legs / feet
	local legSwing = (def.move == "walk") and (running and 0.9 or 0.6) * spd or 0
	for i, e in ipairs(rig.feet) do
		local phase = (i % 2 == 0) and 0 or math.pi
		if #rig.feet >= 4 and i > 2 then phase += math.pi end
		local tuck = (def.move == "hop" and bob > 0.3) and 0.4 or 0
		if def.move == "fly" then tuck = 0.5 end
		self:_set(e, CFrame.Angles(sin(t * 9 * (running and 1.4 or 1) + phase) * legSwing + tuck, 0, 0))
	end

	-------------------------------------------------- arms
	for _, arm in ipairs(rig.arms) do
		local wave = sin(t * 3 + arm.side) * 0.1 + sin(t * 9) * 0.25 * spd
		self:_set(arm.e, CFrame.Angles(wave, 0, -arm.side * (armRaise * 1.6)))
	end

	-------------------------------------------------- halos / orbits / bobbers
	for i, e in ipairs(rig.halos) do
		self:_set(e, CFrame.new(0, sin(t * 2 + i) * 0.12 * self.scale, 0) * CFrame.Angles(0, t * (i == 1 and 1.2 or -0.8), 0))
	end
	for _, e in ipairs(rig.bobbers) do
		self:_set(e, CFrame.Angles(sin(t * 3) * 0.2, 0, sin(t * 2.3) * 0.25))
	end
	if rig.aura then
		local pulse = 1 + sin(t * 3) * 0.05
		rig.aura.mesh.Scale = Vector3.one * pulse * self.scale
	end
end

function Animator:Destroy()
	if self.burst then self.burst:Destroy() end
	self.rig = nil
end

return Animator
