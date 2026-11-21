-- CreatureAnimator: procedural, layered animation for rigs from CreatureBuilder.
-- Location: ReplicatedStorage > Shared > CreatureAnimator (ModuleScript)
--
-- Layers (highest priority first):
--   1. lifecycle  : PlayAccent("enter" | "capture", dur) — owns pose; roaming, signatures and
--                   reactions are suppressed while it runs (renderer drives the root path).
--   2. reaction   : React(kind) — species pet/attention reaction (anticipation/action/recovery).
--   3. signature  : species signature idle every ~6-12 s (seeded per instance, never all at once).
--   4. locomotion : gait per species (hop / quad / biped / bug6 / fly / float / swim / slither / heavy / hover).
--   5. secondary  : breathing, blink, ear twitch, tail/chain follow-through, orbiting ornaments.
-- Poses are additive channels (see SpeciesProfiles header). Joints are rewritten every frame from
-- the stored bind transforms (entry.c0), so nothing accumulates drift.
--
-- TIME: Step(dt) advances the animation phase by the full elapsed dt (LOD-safe: a culled pet keeps
-- its phase), but movement is integrated in bounded substeps (<= 1/30 s, at most 0.5 s per call) so a
-- long pause never teleports or fast-forwards a pet. Timers (blink / signature) fire at most once per call.
--
-- Compatible API: new, Step, SetHome, MoveTo, Teleport, Jump, React, LookAt, SetScale, Destroy.
-- Added: PlayAccent(kind, dur), EndAccent(), onFx (callback(kind, anim) for local procedural effects).

local Profiles = require(script.Parent.SpeciesProfiles)

local Animator = {}
Animator.__index = Animator

local sin, cos, abs, clamp, exp = math.sin, math.cos, math.abs, math.clamp, math.exp
local TAU = math.pi * 2
local EMPTY = {}
local CHANNELS = { "bob", "tiltX", "tiltZ", "yaw", "roll", "spin", "crouch", "lean", "sqY", "headYaw", "headPitch", "headRoll",
	"armL", "armR", "armIn", "legFL", "legFR", "legBL", "legBR", "earL", "earR", "wingFold", "wingL", "wingR", "wingFlap",
	"tailCurl", "tailWag", "mouth", "jaw", "lid", "glow", "open", "chainCurl", "chainWave", "spread", "hide" }

local GAIT_SPEED = { hop = 6, quad = 5.5, biped = 4, bug6 = 4, fly = 8, float = 4, swim = 4, slither = 4.5, heavy = 3.5, hover = 4 }
local DEFAULT_GAIT = { hop = "hop", walk = "quad", fly = "fly", float = "float", slither = "slither" }

local instanceCounter = 0

local function scaledCF(cf, s)
	return CFrame.new(cf.Position * s) * cf.Rotation
end

local function springTo(cur, target, k, dt)
	return cur + (target - cur) * (1 - exp(-k * dt))
end

local function smooth(u)
	u = clamp(u, 0, 1)
	return u * u * (3 - 2 * u)
end

local function blendInto(pose, a, b, u, w)
	for ch, v in pairs(a) do pose[ch] = (pose[ch] or 0) + v * (1 - u) * w end
	for ch, v in pairs(b) do pose[ch] = (pose[ch] or 0) + v * u * w end
end

-- keyframes: { {t, pose}, ... } with implicit neutral start (and end unless hold)
local function evalKeys(keys, k, hold, pose, w)
	local prevT, prevP = 0, EMPTY
	for _, kf in ipairs(keys) do
		if k <= kf[1] then
			local span = kf[1] - prevT
			blendInto(pose, prevP, kf[2], span > 0 and smooth((k - prevT) / span) or 1, w)
			return
		end
		prevT, prevP = kf[1], kf[2]
	end
	if hold then
		blendInto(pose, prevP, EMPTY, 0, w)
	else
		local span = 1 - prevT
		blendInto(pose, prevP, EMPTY, span > 0 and smooth((k - prevT) / span) or 1, w)
	end
end
Animator.EvalKeys = evalKeys

function Animator.new(rig, startCFrame: CFrame?)
	local def = rig.def
	local prof = rig.profile or Profiles.Get(def.id)
	local self = setmetatable({}, Animator)
	instanceCounter += 1
	self.rig = rig
	self.def = def
	self.prof = prof
	-- stable per-instance seed: duplicates never blink / perform signatures in lockstep
	local seed = (instanceCounter * 7919 + #def.id * 104729) % 2147483647
	self.rng = Random.new(seed)
	self.seed = self.rng:NextNumber() * 100
	self.t = self.rng:NextNumber() * 10
	local cf = startCFrame or rig.root.CFrame
	self.pos = cf.Position
	local _, yaw = cf:ToEulerAnglesYXZ()
	self.yaw, self.targetYaw = yaw, yaw
	self.scale, self._appliedScale = 1, -1
	self.gait = prof.gait or DEFAULT_GAIT[def.move] or "quad"
	self.moveTarget, self.moveSpeed, self.speedNow = nil, GAIT_SPEED[self.gait] or 5, 0
	self.gaitPhase, self.hopPhase, self.hopWait = 0, 0, 0
	self.landSquash, self.lean = 0, 0
	self.blinkTimer = self.rng:NextNumber(1, 4)
	self.twitchT = self.rng:NextNumber(1, 4)
	self.sigTimer = self.rng:NextNumber(3, 12)
	self.look, self.lookAmt, self.lookYaw = nil, 0, 0
	self.home, self.homeRadius = nil, 10
	self.idleTimer = self.rng:NextNumber(1, 4)
	self.hover = prof.hover or ((def.move == "fly" and 2.6) or ((def.move == "float" or def.move == "slither") and 0.6) or 0)
	self.groundY = self.pos.Y
	self.pose = {}
	self.glowNow = 0
	self.hideNow = -1
	self.fragOffsets = {}
	for i = 1, 4 do
		self.fragOffsets[i] = Vector3.new(self.rng:NextNumber(-1, 1), self.rng:NextNumber(-0.5, 1), self.rng:NextNumber(-1, 1)) * rig.size * 0.6
	end
	self.onFx = nil
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
	self.moveSpeed = speed or (GAIT_SPEED[self.gait] or 5)
end

function Animator:Teleport(cf: CFrame)
	self.pos = cf.Position
	self.groundY = cf.Position.Y
	local _, yaw = cf:ToEulerAnglesYXZ()
	self.yaw, self.targetYaw = yaw, yaw
end

function Animator:Jump()
	if not self.jumpT and not self.life then self.jumpT = 0 end
end

-- kind: "pet" / "happy" / nil -> species reaction; "spin" -> legacy spin
function Animator:React(kind: string?)
	if self.life then return false end
	kind = kind or "pet"
	if kind == "spin" and not self.prof.react then
		self.spinT = 0
		return true
	end
	if self.reactT then return false end
	if self.prof.react then
		self.reactT = 0
		self.reactFx = {}
		self.sigT = nil
	else
		self:Jump()
	end
	return true
end

function Animator:LookAt(pos: Vector3?)
	self.look = pos
end

function Animator:SetScale(s: number)
	self.scale = s
end

-- lifecycle accent ("enter" plays the species entrance pose, "capture" holds its capture pose)
function Animator:PlayAccent(kind: string, dur: number)
	local spec = (kind == "enter") and self.prof.enter or self.prof.capture
	self.life = { kind = kind, t = 0, dur = math.max(dur, 0.05), spec = spec or EMPTY, fired = {} }
	self.reactT, self.sigT, self.jumpT, self.spinT = nil, nil, nil, nil
	self.moveTarget = nil
end

function Animator:EndAccent()
	self.life = nil
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
		if e.baseSize then e.part.Size = e.baseSize * s end -- sculpted MeshParts scale by Size
	end
end

-- rotation applied in the joint's own frame
function Animator:_set(e, extra: CFrame)
	e.w.C0 = scaledCF(e.c0, self.scale) * extra
end

-- rotation applied in the parent's frame, about the joint position
function Animator:_setP(e, rot: CFrame)
	local c0 = e.c0
	e.w.C0 = CFrame.new(c0.Position * self.scale) * rot * c0.Rotation
end

function Animator:_fire(list, k, fired)
	if not list then return end
	for i, ev in ipairs(list) do
		if not fired[i] and k >= ev[1] then
			fired[i] = true
			if self.onFx then task.spawn(self.onFx, ev[2], self) end
		end
	end
end

function Animator:_brain(dt)
	if not self.home or self.moveTarget or self.life or self.reactT or self.sigT then return end
	self.idleTimer -= dt
	if self.idleTimer <= 0 then
		self.idleTimer = self.rng:NextNumber(3, 7.5)
		local a = self.rng:NextNumber() * TAU
		local r = self.rng:NextNumber() * self.homeRadius
		local run = self.rng:NextNumber() < 0.15
		self:MoveTo(self.home + Vector3.new(cos(a) * r, 0, sin(a) * r), run and (GAIT_SPEED[self.gait] or 5) * 1.7 or nil)
	end
end

function Animator:_integrate(h)
	local prof = self.prof
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
			local dy = (self.targetYaw - self.yaw + math.pi) % TAU - math.pi
			local step = math.min(dist, self.moveSpeed * h)
			-- walkers turn before / while launching instead of moonwalking
			step *= clamp(cos(dy), 0, 1) ^ 2
			if self.gait == "hop" then
				local ph = self.hopPhase % 1
				step = (ph > 0.15 and ph < 0.7 and self.hopWait <= 0) and step / 0.55 or 0
				if abs(dy) > 0.7 then step = 0 end
			end
			self.pos += dir * step
			local stride = (prof.stride or 1.2) * self.rig.size
			self.gaitPhase += step / stride
		end
	end
	self.moving = moving
	self.speedNow = springTo(self.speedNow, moving and self.moveSpeed or 0, 8, h)
	local dy = (self.targetYaw - self.yaw + math.pi) % TAU - math.pi
	local turnRate = (self.gait == "heavy") and 3 or 7
	self.yaw += dy * (1 - exp(-turnRate * h))
	self.lean = springTo(self.lean, clamp(dy * 1.5, -0.5, 0.5), 6, h)
	-- hop cycle: 15% anticipation, 10% takeoff, 45% arc, 15% land, 15% settle
	if self.gait == "hop" then
		if self.hopWait > 0 then
			self.hopWait -= h
		elseif moving or (self.hopPhase % 1) > 0.01 then
			local before = self.hopPhase % 1
			local period = 0.55 * (prof.lowGrav and 1.45 or 1) / math.max(0.6, (prof.hopK or 1) ^ 0.3)
			self.hopPhase += h / period
			local ph = self.hopPhase % 1
			if before < 0.7 and ph >= 0.7 then self.landSquash = 1 end
			if ph < before then -- cycle completed
				if not moving then self.hopPhase = math.floor(self.hopPhase) end
				if prof.hopPause then self.hopWait = prof.hopPause end
			end
		end
	end
	if self.landSquash > 0.001 then self.landSquash = springTo(self.landSquash, 0, 10, h) end
end

---------------------------------------------------------------- per-frame
function Animator:Step(dt: number)
	local rig = self.rig
	if not rig then return end
	dt = clamp(dt, 0, 5)
	self.t += dt
	local t = self.t
	local def, prof = self.def, self.prof
	self:_applyScale()

	-- timers (fire at most once per call, even after a long LOD pause)
	if not self.life then self:_brain(math.min(dt, 0.5)) end
	local remaining = math.min(dt, 0.5)
	while remaining > 1e-4 do
		local h = math.min(remaining, 1 / 30)
		self:_integrate(h)
		remaining -= h
	end

	local pose = self.pose
	for _, ch in ipairs(CHANNELS) do pose[ch] = 0 end
	local s = rig.size

	-------------------------------------------------- lifecycle / reaction / signature layers
	local life = self.life
	if life then
		life.t += dt
		local k = clamp(life.t / life.dur, 0, 1)
		local spec = life.spec
		if spec.keys then evalKeys(spec.keys, k, life.kind == "capture" or spec.hold, pose, 1) end
		self:_fire(spec.fx, k, life.fired)
	else
		if self.reactT then
			local r = prof.react
			self.reactT += dt
			local k = self.reactT / r.dur
			if k >= 1 then self.reactT = nil
			else
				evalKeys(r.keys, k, false, pose, 1)
				self:_fire(r.fx, k, self.reactFx)
			end
		end
		self.sigTimer -= dt
		if self.sigTimer <= 0 then
			if prof.sig and not self.moving and not self.reactT then
				self.sigT, self.sigFx = 0, {}
				self.sigTimer = self.rng:NextNumber(6, 12) + prof.sig.dur
			else
				self.sigTimer = self.rng:NextNumber(1.5, 3)
			end
		end
		if self.sigT then
			local sg = prof.sig
			self.sigT += dt
			local k = self.sigT / sg.dur
			if k >= 1 or self.moving then self.sigT = nil
			else
				evalKeys(sg.keys, k, false, pose, 1)
				self:_fire(sg.fx, k, self.sigFx)
			end
		end
	end

	-------------------------------------------------- locomotion
	local spd = clamp(self.speedNow / math.max(self.moveSpeed, 1), 0, 1.6)
	local gait = self.gait
	local gp = self.gaitPhase * TAU
	local legSwing = {}
	local tuck = 0
	local sqY = 1
	local hoverBob = 0
	if gait == "hop" then
		local ph = self.hopPhase % 1
		local hk = prof.hopK or 1
		if self.hopWait <= 0 and (self.moving or ph > 0.01) then
			if ph < 0.15 then
				sqY -= sin(ph / 0.15 * math.pi) * 0.1
				pose.tiltX += sin(ph / 0.15 * math.pi) * 0.12
			elseif ph < 0.7 then
				local u = (ph - 0.15) / 0.55
				-- bound height ~0.15-0.3 body heights (no giant generic happy hop)
				pose.bob += sin(u * math.pi) * 0.65 * hk * s * (prof.lowGrav and 1.4 or 1)
				sqY += sin(u * math.pi) * 0.08 - (u < 0.2 and 0 or 0)
				pose.tiltX += (0.5 - u) * -0.35
				tuck = sin(u * math.pi) * 0.6
				if prof.rollHop then pose.roll += sin(u * math.pi) * 0.45 end
			end
		end
	elseif gait == "quad" or gait == "heavy" or gait == "biped" or gait == "bug6" then
		local amp = (gait == "heavy" and 0.35 or (gait == "bug6" and 0.45 or 0.55)) * clamp(spd, 0, 1.3)
		local trot = spd > 1.1
		legSwing.amp = amp * (trot and 1.25 or 1)
		pose.bob += abs(sin(gp)) * (gait == "heavy" and 0.08 or 0.12) * s * clamp(spd, 0, 1)
		if gait == "heavy" then
			pose.tiltZ += sin(gp) * 0.05 * spd
			pose.yaw += sin(gp) * 0.06 * spd -- chest counter-rotation
		elseif gait == "biped" then
			pose.tiltZ += sin(gp) * 0.1 * spd -- waddle
		else
			pose.tiltX += 0.04 * spd
		end
	elseif gait == "fly" or gait == "hover" then
		hoverBob = sin(t * (gait == "hover" and 1.8 or 2.4) + self.seed) * 0.4 * s
		pose.tiltX += (gait == "hover" and 0.08 or 0.25) * spd
		pose.tiltZ += -self.lean * (gait == "hover" and 0.3 or 0.8)
		tuck = 0.6
	elseif gait == "float" or gait == "swim" then
		hoverBob = sin(t * TAU / 3 + self.seed) * 0.3 * s
		pose.tiltX += 0.12 * spd
		pose.tiltZ += -self.lean * 0.4
		if gait == "swim" then sqY += sin(t * 2.6 + self.seed) * 0.03 end
		if prof.airRun then legSwing.amp = 0.45 * clamp(spd, 0.2, 1); legSwing.air = true end
	elseif gait == "slither" then
		hoverBob = sin(t * 1.8 + self.seed) * 0.25 * s
		pose.tiltZ += -self.lean * 0.5
	end

	-- legacy jump / spin
	if self.jumpT then
		self.jumpT += dt
		local k = self.jumpT / 0.55
		if k >= 1 then self.jumpT = nil; self.landSquash = 1
		else pose.bob += sin(k * math.pi) * 1.6 * s; sqY += sin(k * math.pi) * 0.1 end
	end
	if self.spinT then
		self.spinT += dt
		local k = clamp(self.spinT / 0.7, 0, 1)
		pose.spin += (1 - (1 - k) ^ 3) * TAU
		if k >= 1 then self.spinT = nil end
	end

	-------------------------------------------------- secondary: breathing, landing squash
	local br = prof.breath or { 3, 0.02 }
	sqY *= 1 + sin(t * TAU / br[1] + self.seed) * br[2]
	sqY += pose.sqY
	pose.roll += self.rootRoll or 0 -- renderer-driven roll (e.g. rolling entrances)
	if self.landSquash > 0.001 then sqY *= 1 - self.landSquash * (gait == "heavy" and 0.04 or 0.18) end
	-- hard-surface style: body volumes stay constant (weight comes from joints and root motion)
	local sqk = (rig.style and rig.style.squash) or 1
	sqY = clamp(1 + (sqY - 1) * sqk, 0.6, 1.4)
	local sqXZ = 1 / math.sqrt(sqY)

	-------------------------------------------------- root + body
	local scale = self.scale
	local rootCF = CFrame.new(self.pos.X, self.groundY, self.pos.Z) * CFrame.Angles(0, self.yaw + pose.spin, 0)
	rig.root.CFrame = rootCF
	local be = rig.bodyEntry
	local headIsBody = (rig.head == rig.body) or not rig.headEntry
	local hb = 0
	if headIsBody then hb = 0.45 end
	local lookYaw, lookPitch = 0, 0
	if self.look then
		local lp = rootCF:PointToObjectSpace(self.look)
		local want = math.atan2(-lp.X, -lp.Z)
		if abs(want) < 2.2 then
			self.lookYaw = springTo(self.lookYaw, clamp(want, -0.7, 0.7), 6, dt)
			self.lookAmt = springTo(self.lookAmt, 1, 5, dt)
			lookPitch = clamp(math.atan2(lp.Y - 2 * s, math.sqrt(lp.X * lp.X + lp.Z * lp.Z)), -0.35, 0.35)
		else
			self.lookAmt = springTo(self.lookAmt, 0, 3, dt)
		end
	else
		self.lookAmt = springTo(self.lookAmt, 0, 3, dt)
	end
	if self.life then self.lookAmt = 0 end
	lookYaw = self.lookYaw * self.lookAmt
	lookPitch *= self.lookAmt
	if be then
		local y = (self.hover + hoverBob + pose.bob - pose.crouch * s) * scale
		local bodyRot = CFrame.Angles(-(pose.tiltX + pose.roll) + (headIsBody and -(pose.headPitch * hb) or 0),
			pose.yaw + (headIsBody and (pose.headYaw + lookYaw) * hb or 0),
			pose.tiltZ + (headIsBody and pose.headRoll * hb or 0))
		self:_set(be, CFrame.new(0, y, -pose.lean * s * scale) * bodyRot)
		if be.mesh then be.mesh.Scale = Vector3.new(sqXZ, sqY, sqXZ) * scale end
	end

	-------------------------------------------------- head(s)
	local headPitch = pose.headPitch - lookPitch
	if rig.headEntry and not headIsBody then
		local heads = rig.groups.heads
		if heads and #heads > 1 then
			for i, he in ipairs(heads) do
				local gaze = sin(t * 0.45 + i * 2.1 + self.seed) * 0.35 * (1 - self.lookAmt)
				self:_set(he, CFrame.Angles(-headPitch * 0.8, pose.headYaw * 0.5 + lookYaw + gaze, pose.headRoll + (i - 2) * 0.1 * pose.spread))
			end
		else
			self:_set(rig.headEntry, CFrame.Angles(-headPitch + sin(t * 2.2 + self.seed) * 0.02, pose.headYaw + lookYaw, pose.headRoll))
		end
	end
	for _, jaw in ipairs(rig.groups.jaws or EMPTY) do
		self:_set(jaw, CFrame.Angles(-(pose.jaw + pose.mouth * 0.25), 0, 0))
	end

	-------------------------------------------------- eyes: blink + pupils
	self.blinkTimer -= dt
	if self.blinkTimer <= 0 then
		self.blinkT = 0
		local bl = prof.blink or { 2.5, 6 }
		self.blinkTimer = self.rng:NextNumber(bl[1], bl[2])
		if self.rng:NextNumber() < 0.15 then self.blinkTimer = 0.3 end
	end
	local lid = pose.lid
	if self.blinkT then
		self.blinkT += dt
		local k = self.blinkT / 0.15
		if k >= 1 then self.blinkT = nil else lid = math.max(lid, sin(k * math.pi)) end
	end
	local eyeY = clamp(1 - lid * 0.94, 0.06, 1.3)
	for _, e in ipairs(rig.eyes) do
		if e.mesh then e.mesh.Scale = Vector3.new(1, eyeY, 1) * scale end
	end
	local px, py = sin(t * 0.37 + self.seed) * 0.05, sin(t * 0.23) * 0.03
	if self.lookAmt > 0.1 then px = clamp(-lookYaw * 0.15, -0.1, 0.1) end
	for _, e in ipairs(rig.pupils) do
		self:_set(e, CFrame.new(px * scale, py * scale, 0))
	end
	for _, m in ipairs(rig.mouths) do
		if m.mesh then m.mesh.Scale = Vector3.new(1 + pose.mouth * 0.2, 1 + pose.mouth * 2.2, 1) * scale end
	end

	-------------------------------------------------- ears / antennae
	self.twitchT -= dt
	local twitch = 0
	if self.twitchT < 0 then
		if self.twitchT < -0.25 then self.twitchT = self.rng:NextNumber(1.5, 4.5) end
		twitch = sin((-self.twitchT) / 0.25 * math.pi) * 0.3
	end
	for i, ear in ipairs(rig.ears) do
		local fold = ear.side < 0 and pose.earL or pose.earR
		local lag = -clamp(pose.bob, -1, 1) * 0.25 + sin(gp) * 0.1 * spd
		local a = sin(t * 2 + i) * 0.05 + (i == 1 and twitch or 0)
		self:_set(ear.e, CFrame.Angles(fold + lag, 0, -ear.side * a))
	end

	-------------------------------------------------- wings / fins
	local fl = prof.flap
	local flapRate, flapAmp = 3, 0.1
	if gait == "fly" then flapRate, flapAmp = (fl and fl[1] or 10) * (1 + spd * 0.3), fl and fl[2] or 0.6
	elseif gait == "hover" then flapRate, flapAmp = fl and fl[1] or 16, fl and fl[2] or 0.45
	elseif gait == "swim" or rig.legKind == "none" then flapRate, flapAmp = 4, 0.3 end
	-- glide: periodically hold wings out instead of flapping symmetrically forever
	if gait == "fly" and sin(t * 0.35 + self.seed) > 0.55 then flapAmp *= 0.15 end
	flapAmp *= clamp(1 + pose.wingFlap, 0, 2) * (1 - pose.wingFold)
	local x = (t * flapRate / TAU) % 1
	-- strong downstroke (40%), softer recovery (60%)
	local f = x < 0.4 and (1 - 2 * smooth(x / 0.4)) or (-1 + 2 * smooth((x - 0.4) / 0.6))
	for _, w in ipairs(rig.wings) do
		local raise = w.side < 0 and pose.wingL or pose.wingR
		local tierLag = (w.tier == 2) and 0.7 or 1
		self:_set(w.e, CFrame.Angles(0, w.side * pose.wingFold * 1.0, w.side * (f * flapAmp * tierLag + raise - pose.wingFold * 0.35)))
	end

	-------------------------------------------------- generic tail with follow-through
	local wag = (pose.tailWag > 0 or self.reactT) and 12 or (3 + spd * 4)
	local wagAmp = 0.22 + pose.tailWag * 0.35
	for i, e in ipairs(rig.tail) do
		local ph = t * wag - i * 0.6
		self:_set(e, CFrame.Angles(sin(ph * 0.5) * 0.06 - pose.tailCurl * 0.3, sin(ph) * (wagAmp + i * 0.03), 0))
	end

	-------------------------------------------------- legs / feet
	local legs = rig.feet
	local lk = rig.legKind
	local legCh = { pose.legFL, pose.legFR, pose.legBL, pose.legBR }
	for i, e in ipairs(legs) do
		local phase = 0
		if lk == "quad" then
			phase = (i == 1 or i == 4) and 0 or math.pi -- diagonal pairs
		elseif lk == "bug6" then
			phase = (i == 1 or i == 4 or i == 5) and 0 or math.pi -- alternating tripods
		else
			phase = (i % 2 == 0) and math.pi or 0
		end
		local swing = legSwing.amp and sin(gp + phase) * legSwing.amp or 0
		if legSwing.air then swing = sin(t * 4 + phase) * legSwing.amp end
		local lift = 0
		if lk == "bug6" then
			lift = (i <= 2) and (i == 1 and pose.legFL or pose.legFR) or 0
			self:_setP(e, CFrame.Angles(0, swing, 0) * CFrame.Angles(-lift * 0.6, 0, 0))
		else
			lift = (lk == "quad" and legCh[i]) or (i == 1 and pose.legFL) or (i == 2 and pose.legFR) or 0
			local hipExtra = 0
			if e.knee then
				-- two-bone leg: on a crouch the upper leg folds back by a while the knee turns forward by a,
				-- so the shin stays upright, the paw stays flat and the body drops d = upperLen(1 - cos a);
				-- the knee also flexes while the foot swings forward
				local dir = e.kneeDir or 1
				local a = math.acos(clamp(1 - math.max(pose.crouch, 0) * s / (e.upperLen or s), -1, 1))
				local flex = math.max(0, -math.cos(gp + phase)) * 0.55 * clamp(spd, 0, 1)
				hipExtra = -a * dir
				self:_set(e.knee, CFrame.Angles((a + flex) * dir, 0, 0))
			end
			self:_setP(e, CFrame.Angles(-swing - lift + hipExtra + tuck * (lk == "quad" and (i <= 2 and -0.4 or 0.4) or 0.6), 0, 0))
		end
	end

	-------------------------------------------------- arms
	for _, arm in ipairs(rig.arms) do
		local raise = arm.side < 0 and pose.armL or pose.armR
		local swing = sin(gp + (arm.side > 0 and math.pi or 0)) * 0.3 * clamp(spd, 0, 1) + sin(t * 2 + arm.side) * 0.05
		self:_set(arm.e, CFrame.Angles(swing - pose.armIn * 0.5, arm.side * pose.armIn * 0.5, -arm.side * raise * 1.4))
	end

	-------------------------------------------------- chains (tails, tentacles, necks, spines, streamers)
	local moveK = clamp(spd, 0, 1)
	for _, ch in ipairs(rig.chains) do
		local kind, n = ch.kind, ch.n
		local amp = (ch.amp or 0.2) * (1 + pose.chainWave)
		local freq, lag, ci = ch.freq or 1.5, ch.lag or 0.6, ch.i or 1
		for j, e in ipairs(ch.entries) do
			local u = j / n
			local pitch, yawA, roll = 0, 0, 0
			if kind == "fan" then
				local wv = sin(t * freq - j * lag - ci * 0.45) * amp * (0.4 + u)
				if j == 1 then yawA = (ch.baseYaw or 0) * (1 + pose.spread * 0.6) end
				yawA += wv * 0.6 + pose.chainWave * sin(t * 3 - ci * 0.6 - j * 0.4) * 0.12
				pitch = sin(t * freq * 0.7 - j * lag + ci) * amp * 0.4 - pose.tailCurl * 0.2 + self.lean * 0.1
			elseif kind == "tentacle" then
				pitch = sin(t * freq - j * lag + ci * 0.8) * amp * (0.4 + u) - pose.chainCurl * 0.35 + moveK * 0.15
				yawA = sin(t * freq * 0.6 - j * lag + ci) * amp * 0.4 + pose.open * 0.25 * ((j == 1) and 1 or 0)
			elseif kind == "neck" then
				local side = ch.side or 0
				if j == 1 then yawA = side * pose.spread * 0.35 end
				pitch = sin(t * freq + ci * 1.7 + j * 0.4) * amp * 0.5 + pose.chainCurl * 0.15
				roll = sin(t * freq * 0.8 + ci * 2.3) * amp * 0.6 * (1 + pose.chainWave)
			elseif kind == "spine" then
				local f2 = freq * (1 + moveK * 0.8)
				yawA = sin(t * f2 - j * lag) * amp * (0.3 + u) + pose.chainCurl * 0.42
				pitch = sin(t * f2 * 0.5 - j * lag) * 0.05
			elseif kind == "fluke" then
				pitch = sin(t * freq * (1 + moveK) - j * lag) * amp * (0.5 + u)
			elseif kind == "plume" then
				pitch = -(ch.curl or 0.4) + sin(t * freq - j * lag) * amp * 0.5 - pose.tailCurl * 0.2
				yawA = sin(t * freq * 0.5 - j * lag) * amp * 0.3
			elseif kind == "echo" then
				yawA = sin((t - 0.25) * freq - j * lag) * amp * (0.4 + u) + pose.open * 0.2
				pitch = -0.3 * ((j == 1) and 1 or 0) - pose.tailCurl * 0.2
			else -- trail (streamers, tendrils, ribbons)
				pitch = sin(t * freq - j * lag + ci) * amp * (0.3 + u) + moveK * 0.2 * u - pose.chainCurl * 0.4
				yawA = sin(t * freq * 0.7 - j * lag + ci * 1.3) * amp * 0.5
			end
			self:_set(e, CFrame.Angles(pitch, yawA, roll))
		end
	end

	-------------------------------------------------- groups
	local g = rig.groups
	local open = pose.open
	for _, e in ipairs(g.open or EMPTY) do
		self:_set(e, CFrame.fromAxisAngle(e.openAxis, open * e.openAmt))
	end
	for _, e in ipairs(g.flutter or EMPTY) do
		self:_set(e, CFrame.Angles(sin(t * 2.4 + e.c0.Position.X) * 0.12 + moveK * 0.25, 0, sin(t * 1.7) * 0.08))
	end
	for i, e in ipairs(g.scarfEnds or EMPTY) do
		if not (g.flutter and table.find(g.flutter, e)) then
			self:_set(e, CFrame.Angles(sin(t * 3 + i) * 0.15 + moveK * 0.3, 0, 0))
		end
	end
	for _, e in ipairs(g.motifOrbit or EMPTY) do self:_set(e, CFrame.Angles(0, t * 0.6, 0)) end
	for i, e in ipairs(g.motifs or EMPTY) do self:_set(e, CFrame.new(0, sin(t * 1.3 + i) * 0.25 * s, 0) * CFrame.Angles(0, t * 1.2, sin(t + i) * 0.3)) end
	local orbitR = 1 + pose.spread * 0.35
	for i, e in ipairs(g.ornamentOrbit or EMPTY) do
		local c0 = e.c0
		e.w.C0 = CFrame.new(c0.Position * scale) * CFrame.Angles(0, t * 0.7 + i, 0) * CFrame.new()
		for _, o in ipairs(g.ornaments or EMPTY) do
			local p0 = o.c0.Position
			o.w.C0 = CFrame.new(p0 * orbitR * scale + Vector3.new(0, sin(t * 1.5 + p0.X) * 0.2 * s, 0)) * CFrame.Angles(0, t, 0)
		end
	end
	for i, e in ipairs(g.orbit or EMPTY) do self:_set(e, CFrame.Angles(0, t * 0.5 * (i % 2 == 0 and -1 or 1), 0)) end
	for _, e in ipairs(g.rays or EMPTY) do self:_set(e, CFrame.Angles(0, 0, t * 0.25)) end
	for _, e in ipairs(g.rings or EMPTY) do self:_set(e, CFrame.Angles(0, t * 0.3, sin(t * 0.4) * 0.08)) end
	for _, e in ipairs(g.clockRings or EMPTY) do
		local stepT = math.floor(t * 1.0) + smooth((t % 1) / 0.25)
		self:_set(e, CFrame.Angles(0, stepT * (e.stepRate or 0.2), 0))
	end
	for _, e in ipairs(g.palmCrystal or EMPTY) do self:_set(e, CFrame.Angles(0, t * 1.5, 0)) end
	for _, e in ipairs(g.lag or EMPTY) do
		self.lagX = springTo(self.lagX or 0, -pose.tiltZ * 0.5, 4, dt)
		self.lagY = springTo(self.lagY or 0, -(pose.bob + hoverBob) * 0.25, 4, dt)
		self:_set(e, CFrame.new(self.lagX * s * scale, self.lagY * scale, 0) * CFrame.Angles(0, t * 0.8, 0))
	end
	for i, e in ipairs(g.fragments or EMPTY) do
		local off = self.fragOffsets[(e.fragIndex or i) % 4 + 1] * open
		self:_set(e, CFrame.new(off * scale) * CFrame.Angles(t * 0.5, t * 0.7, 0))
	end
	for _, e in ipairs(g.abdomen or EMPTY) do
		self:_set(e, CFrame.Angles(pose.tiltX * 0.4 + sin(t * 1.2 + self.seed) * 0.04, -self.lean * 0.3, 0))
	end
	for _, e in ipairs(rig.halos) do
		self:_set(e, CFrame.new(0, sin(t * 1.6) * 0.1 * scale, 0) * CFrame.Angles(0, t * 0.6, 0))
	end
	for _, e in ipairs(rig.bobbers) do
		self:_set(e, CFrame.Angles(sin(t * 3) * 0.15 - clamp(pose.bob, -1, 1) * 0.2, 0, sin(t * 2.3) * 0.2))
	end

	-------------------------------------------------- glow + reveal
	local glowT = clamp(pose.glow, -1, 1)
	if abs(glowT - self.glowNow) > 0.02 then
		self.glowNow = glowT
		local gk = clamp(glowT, 0, 1) * 0.6
		for _, gl in ipairs(rig.glows or EMPTY) do
			gl.part.Color = gl.base:Lerp(gl.bright, gk)
		end
		if rig.light then rig.light.Brightness = (rig.light:GetAttribute("Base") or rig.light.Brightness) * (1 + gk) end
	end
	if rig.reveal then
		local hide = clamp(pose.hide, 0, 1)
		if abs(hide - self.hideNow) > 0.01 then
			self.hideNow = hide
			local units = rig.reveal
			local n = #units
			for i, parts in ipairs(units) do
				-- units appear in order as hide goes 1 -> 0
				local vis = clamp((1 - hide) * n - (i - 1), 0, 1)
				for _, p in ipairs(parts) do p.LocalTransparencyModifier = 1 - vis end
			end
		end
	end
end

function Animator:Destroy()
	self.onFx = nil
	self.rig = nil
end

return Animator
