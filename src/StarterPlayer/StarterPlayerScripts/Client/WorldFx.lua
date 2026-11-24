-- WorldFx: ONE shared, staggered scheduler for environment motion on tagged map parts
-- (no per-prop RenderStepped connections, no camera-following particles).
-- Location: StarterPlayer > StarterPlayerScripts > Client > WorldFx (ModuleScript)
--
-- Tags (set by WorldLandmarks on the server):
--   TPFC_Sway   {Amp radians, Period s}    canopies, banners, candy discs: slow wind
--   TPFC_Bob    {Amp studs, Period, Spin deg/s}  hub crystal, suspended stones
--   TPFC_Spin   {Rate deg/s}               planet / observatory rings, asteroids (yaw precession)
--   TPFC_Pulse  {Period, Base, Peak}       transparency pulse (vents, runes, crystal cores, lava)
--   TPFC_Glint  {Period}                   0.15 s brighten, 0.5 s fade on one face, never in sync
--   TPFC_ChargeChannel {Index}             Launch Hall floor channels, energised while charging
-- Only the nearest budgeted scenery is updated, at ~20 Hz; far scenery stays static.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Settings = require(script.Parent.ClientSettings)

local WorldFx = {}
local RANGE = 180
local MAX_COSMETICS, MAX_CHANNELS = 64, 32
local EMITTER_RANGE, MAX_EMITTER_RATE, TOTAL_EMITTER_RATE = 140, 24, 72
local TAGS = { "TPFC_Sway", "TPFC_Bob", "TPFC_Spin", "TPFC_Pulse", "TPFC_Glint", "TPFC_ChargeChannel", "TPFC_Rotor" }
local items = {} -- part -> { kind, base, baseTr, phase, ... }
local pendingModels = {} -- tagged models whose replicated pivot/geometry is still arriving
local started, membershipDirty = false, true
local activeItems = {}
local ticks = 0
local serial = 0
WorldFx.TC = nil -- ThrowController (for charge channels), set by ClientMain

local function add(kind, p)
	if items[p] then
		return
	end
	local model = p:IsA("Model")
	if not p:IsA("BasePart") and not (model and (kind == "TPFC_Bob" or kind == "TPFC_Spin")) then
		return
	end
	if model then
		local count = p:GetAttribute("TPFC_AnimationParts")
		if not p.PrimaryPart or (count and #p:GetChildren() < count) then
			pendingModels[p] = kind
			return
		end
	end
	pendingModels[p] = nil
	local base = model and (p:GetAttribute("TPFC_AnimationBase") or p:GetPivot()) or p.CFrame
	local seed = (base.X * 12.9898 + base.Z * 78.233) % 1
	local rotor = kind == "TPFC_Rotor" and p:FindFirstChild("PortalRotor") or nil
	membershipDirty = true
	serial += 1
	items[p] = {
		part = p,
		position = base.Position,
		kind = kind,
		base = rotor and rotor.C0 or base,
		baseTr = not model and p.Transparency or 0,
		baseCol = not model and p.Color or Color3.new(1, 1, 1),
		phase = seed * 100,
		model = model,
		rotor = rotor,
		order = serial,
	}
end

local function lowQuality()
	local q = UserSettings().GameSettings.SavedQualityLevel.Value
	return Settings.LowVFX() or (q > 0 and q <= 3)
end
local function rest(p, it)
	if it.rotor then
		it.rotor.C0 = it.base
	elseif it.model then
		p:PivotTo(it.base)
	else
		p.CFrame = it.base
	end
	if not it.model then
		p.Transparency, p.Color = it.baseTr, it.baseCol
	end
end
function WorldFx.Diagnostics()
	local count = 0
	for _ in items do
		count += 1
	end
	return {
		registered = count,
		active = #activeItems,
		ticks = ticks,
		low = lowQuality(),
		range = RANGE,
		cosmeticLimit = MAX_COSMETICS,
		channelLimit = MAX_CHANNELS,
		emitterRateLimit = TOTAL_EMITTER_RATE,
	}
end
function WorldFx.Start()
	if started then
		return
	end
	started = true
	for _, t in ipairs(TAGS) do
		for _, p in ipairs(CollectionService:GetTagged(t)) do
			add(t, p)
		end
		CollectionService:GetInstanceAddedSignal(t):Connect(function(p)
			add(t, p)
		end)
		CollectionService:GetInstanceRemovedSignal(t):Connect(function(p)
			if items[p] and p.Parent then
				rest(p, items[p])
			end
			items[p] = nil
			pendingModels[p] = nil
			membershipDirty = true
		end)
	end
	local emitters = {}
	local function addEmitter(pe)
		if pe:IsA("ParticleEmitter") and not emitters[pe] then
			serial += 1
			emitters[pe] = { rate = pe:GetAttribute("BaseRate") or pe.Rate, order = serial }
			-- Replicated emitters wait for the local camera budget before emitting.
			if pe.Rate > 0 then
				pe.Rate = 0
				pe:Clear()
			end
		end
	end
	for _, pe in CollectionService:GetTagged("TPFC_EnvironmentEmitter") do
		addEmitter(pe)
	end
	CollectionService:GetInstanceAddedSignal("TPFC_EnvironmentEmitter"):Connect(addEmitter)
	CollectionService:GetInstanceRemovedSignal("TPFC_EnvironmentEmitter"):Connect(function(pe)
		if emitters[pe] and pe.Parent then
			pe.Rate = 0
			pe:Clear()
		end
		emitters[pe] = nil
	end)
	local envAccumulator, regionAccumulator = 1, 1
	local candidates, emitterCandidates = {}, {}
	local lastRegionPosition
	local lastLow, lastCalm, suspended
	local function silenceEmitters()
		for pe in emitters do
			if pe.Parent and pe.Rate > 0 then
				pe.Rate = 0
				pe:Clear()
			end
		end
	end
	local function nearer(a, b)
		return a.distance < b.distance or (a.distance == b.distance and a.order < b.order)
	end
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if workspace:GetAttribute("TPFC_IntroPlaying") or not camera then
			if not suspended then
				silenceEmitters()
				suspended = true
			end
			return -- the intro fly-over owns the frame budget; missing cameras stay quiet
		end
		if suspended then
			suspended, membershipDirty, envAccumulator = false, true, 1
		end
		acc += dt
		if acc < 0.05 then
			return
		end
		local elapsed = acc
		acc = 0
		ticks += 1
		for model, kind in pairs(pendingModels) do
			if model.Parent and CollectionService:HasTag(model, kind) then
				add(kind, model)
			else
				pendingModels[model] = nil
			end
		end
		local t = os.clock()
		local cam = camera.CFrame.Position
		local low = lowQuality()
		local calm = low or Settings.ReducedMotion
		if low ~= lastLow or calm ~= lastCalm then
			envAccumulator, membershipDirty, lastLow, lastCalm = 1, true, low, calm
		end
		regionAccumulator += elapsed
		if
			membershipDirty
			or regionAccumulator >= 0.5
			or not lastRegionPosition
			or (cam - lastRegionPosition).Magnitude > 32
		then
			membershipDirty, regionAccumulator, lastRegionPosition = false, 0, cam
			table.clear(candidates)
			for p, it in items do
				if not p.Parent then
					items[p] = nil
				else
					local delta = it.position - cam
					it.distance = delta:Dot(delta)
					it.selected = false
					if it.distance <= RANGE * RANGE and (not calm or it.kind == "TPFC_ChargeChannel") then
						table.insert(candidates, it)
					end
				end
			end
			table.sort(candidates, nearer)
			local cosmetics, channels = 0, 0
			for _, it in candidates do
				if it.kind == "TPFC_ChargeChannel" then
					it.selected = channels < MAX_CHANNELS
					channels += it.selected and 1 or 0
				else
					it.selected = cosmetics < MAX_COSMETICS
					cosmetics += it.selected and 1 or 0
				end
			end
			-- Return only previously moving objects to rest when leaving the budget.
			for _, it in activeItems do
				if it.part.Parent and not it.selected and not it.sleeping then
					rest(it.part, it)
					it.sleeping = true
				end
			end
			table.clear(activeItems)
			for _, it in candidates do
				if it.selected then
					table.insert(activeItems, it)
				end
			end
		end
		envAccumulator += elapsed
		if envAccumulator > 0.5 then
			envAccumulator = 0
			table.clear(emitterCandidates)
			for pe, record in emitters do
				if not pe.Parent then
					emitters[pe] = nil
					continue
				end
				local parent = pe.Parent
				local pos = parent:IsA("BasePart") and parent.Position
					or (parent:IsA("Attachment") and parent.WorldPosition)
				local delta = pos and (pos - cam)
				local distance = delta and delta:Dot(delta)
				record.allowed = 0
				if not low and distance and distance <= EMITTER_RANGE * EMITTER_RANGE then
					record.distance = distance
					table.insert(emitterCandidates, record)
				end
			end
			table.sort(emitterCandidates, nearer)
			local remaining = TOTAL_EMITTER_RATE
			for _, record in emitterCandidates do
				record.allowed = math.min(math.max(0, record.rate), MAX_EMITTER_RATE, remaining)
				remaining -= record.allowed
			end
			for pe, record in emitters do
				if pe.Rate ~= record.allowed then
					local stopped = pe.Rate > 0 and record.allowed == 0
					pe.Rate = record.allowed
					if stopped then
						pe:Clear()
					end
				end
			end
		end
		local motionK = Settings.ReducedMotion and 0.4 or 1
		local tc = WorldFx.TC
		local charging = tc and tc.Charging
		local power = tc and tc.Power or 0
		debug.profilebegin("TPFC_EnvironmentMotion")
		for _, it in activeItems do
			local p = it.part
			if not p.Parent then
				items[p] = nil
				continue
			end
			local kind = it.kind
			if low and kind ~= "TPFC_ChargeChannel" then
				if not it.sleeping then
					rest(p, it)
					it.sleeping = true
				end
				continue
			end
			it.sleeping = false
			if Settings.ReducedFlashes and (kind == "TPFC_Pulse" or kind == "TPFC_Glint") then
				p.Transparency = it.baseTr
				continue
			end
			local ph = t + it.phase
			if kind == "TPFC_Sway" then
				local per, amp = p:GetAttribute("Period") or 6, (p:GetAttribute("Amp") or 0.02) * motionK
				local w = math.pi * 2 / per
				p.CFrame = it.base * CFrame.Angles(math.sin(ph * w) * amp, 0, math.cos(ph * w * 0.8) * amp * 0.7)
			elseif kind == "TPFC_Bob" then
				local per, amp, spin =
					p:GetAttribute("Period") or 4,
					(p:GetAttribute("Amp") or 0.25) * motionK,
					p:GetAttribute("Spin") or 0
				local pos = it.base.Position + Vector3.new(0, math.sin(ph * math.pi * 2 / per) * amp, 0)
				local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(spin * t * motionK), 0) * it.base.Rotation
				if it.model then
					p:PivotTo(cf)
				else
					p.CFrame = cf
				end
			elseif kind == "TPFC_Spin" then
				local rate = (p:GetAttribute("Rate") or 4) * motionK
				local cf = CFrame.new(it.base.Position) * CFrame.Angles(0, math.rad(rate * t), 0) * it.base.Rotation
				if it.model then
					p:PivotTo(cf)
				else
					p.CFrame = cf
				end
			elseif kind == "TPFC_Rotor" then
				if it.rotor then
					it.rotor.C0 = it.base * CFrame.Angles(0, 0, t * (it.rotor:GetAttribute("Rate") or 0.5) * motionK)
				end
			elseif kind == "TPFC_Pulse" then
				local per = p:GetAttribute("Period") or 6
				local base, peak = p:GetAttribute("Base") or it.baseTr, p:GetAttribute("Peak") or 0
				-- warm-up / hold / fade / long rest inside one period
				local u = (ph % per) / per
				local k = u < 0.12 and (u / 0.12) or (u < 0.3 and 1 or (u < 0.5 and 1 - (u - 0.3) / 0.2 or 0))
				p.Transparency = base + (peak - base) * k
			elseif kind == "TPFC_Glint" then
				if not low then
					local per = p:GetAttribute("Period") or 10
					local u = ph % per
					local k = u < 0.15 and u / 0.15 or (u < 0.65 and 1 - (u - 0.15) / 0.5 or 0)
					p.Transparency = it.baseTr + (0 - it.baseTr) * k
				end
			elseif kind == "TPFC_ChargeChannel" then
				-- energise from the player's side toward the front arch with the charge power
				local idx = p:GetAttribute("Index") or 0
				if charging then
					local wave = Settings.ReducedFlashes and 0 or (0.5 + 0.5 * math.sin(t * 10 - math.abs(idx) * 0.6))
					p.Transparency = math.clamp(0.6 - power * 0.45 - wave * 0.1, 0.05, 0.9)
					p.Color = power >= 0.92 and Color3.fromRGB(255, 215, 90) or it.baseCol
				elseif p.Transparency ~= it.baseTr then
					p.Transparency = math.min(it.baseTr, p.Transparency + 0.08) -- ~0.3 s recovery
					if p.Transparency >= it.baseTr - 0.01 then
						p.Transparency = it.baseTr
						p.Color = it.baseCol
					end
				end
			end
		end
		debug.profileend()
	end)
end

return WorldFx
