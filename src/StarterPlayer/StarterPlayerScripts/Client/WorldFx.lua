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
-- Only parts within RANGE of the camera are updated, at ~20 Hz; far scenery stays static.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Settings = require(script.Parent.ClientSettings)

local WorldFx = {}
local camera = workspace.CurrentCamera
local RANGE = 650
local TAGS = { "TPFC_Sway", "TPFC_Bob", "TPFC_Spin", "TPFC_Pulse", "TPFC_Glint", "TPFC_ChargeChannel", "TPFC_Rotor" }
local items = {} -- part -> { kind, base, baseTr, phase, ... }
WorldFx.TC = nil -- ThrowController (for charge channels), set by ClientMain

local function add(kind, p)
	if items[p] then
		return
	end
	local model = p:IsA("Model")
	if not p:IsA("BasePart") and not (model and (kind == "TPFC_Bob" or kind == "TPFC_Spin")) then
		return
	end
	local base = model and p:GetPivot() or p.CFrame
	local seed = (base.X * 12.9898 + base.Z * 78.233) % 1
	local rotor = kind == "TPFC_Rotor" and p:FindFirstChild("PortalRotor") or nil
	items[p] = {
		kind = kind,
		base = rotor and rotor.C0 or base,
		baseTr = not model and p.Transparency or 0,
		baseCol = not model and p.Color or Color3.new(1, 1, 1),
		phase = seed * 100,
		model = model,
		rotor = rotor,
	}
end

function WorldFx.Start()
	for _, t in ipairs(TAGS) do
		for _, p in ipairs(CollectionService:GetTagged(t)) do
			add(t, p)
		end
		CollectionService:GetInstanceAddedSignal(t):Connect(function(p)
			add(t, p)
		end)
		CollectionService:GetInstanceRemovedSignal(t):Connect(function(p)
			items[p] = nil
		end)
	end
	local emitters = {}
	local function addEmitter(pe)
		if pe:IsA("ParticleEmitter") then
			emitters[pe] = pe:GetAttribute("BaseRate") or pe.Rate
		end
	end
	for _, pe in CollectionService:GetTagged("TPFC_EnvironmentEmitter") do
		addEmitter(pe)
	end
	CollectionService:GetInstanceAddedSignal("TPFC_EnvironmentEmitter"):Connect(addEmitter)
	CollectionService:GetInstanceRemovedSignal("TPFC_EnvironmentEmitter"):Connect(function(pe)
		emitters[pe] = nil
	end)
	local envAccumulator = 0
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		if workspace:GetAttribute("TPFC_IntroPlaying") then
			return -- the intro fly-over owns the frame budget
		end
		acc += dt
		if acc < 0.05 then
			return
		end
		acc = 0
		local t = os.clock()
		camera = workspace.CurrentCamera or camera
		if not camera then
			return
		end
		local cam = camera.CFrame.Position
		envAccumulator += 0.05
		if envAccumulator > 0.5 then
			envAccumulator = 0
			for pe, rate in emitters do
				if not pe.Parent then
					emitters[pe] = nil
					continue
				end
				local pos = pe.Parent:IsA("BasePart") and pe.Parent.Position or cam
				pe.Rate = (Settings.LowVFX() or (pos - cam).Magnitude > 220) and 0 or rate
			end
		end
		local motionK = Settings.ReducedMotion and 0.4 or 1
		local tc = WorldFx.TC
		local charging = tc and tc.Charging
		local power = tc and tc.Power or 0
		for p, it in pairs(items) do
			if not p.Parent then
				items[p] = nil
				continue
			end
			local kind = it.kind
			local position = it.model and p:GetPivot().Position or p.Position
			if kind ~= "TPFC_ChargeChannel" and (position - cam).Magnitude > RANGE then
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
					it.rotor.C0 = it.base
						* CFrame.Angles(
							0,
							0,
							t * (p:FindFirstChild("PortalRotor"):GetAttribute("Rate") or 0.5) * motionK
						)
				end
			elseif kind == "TPFC_Pulse" then
				local per = p:GetAttribute("Period") or 6
				local base, peak = p:GetAttribute("Base") or it.baseTr, p:GetAttribute("Peak") or 0
				-- warm-up / hold / fade / long rest inside one period
				local u = (ph % per) / per
				local k = u < 0.12 and (u / 0.12) or (u < 0.3 and 1 or (u < 0.5 and 1 - (u - 0.3) / 0.2 or 0))
				p.Transparency = base + (peak - base) * k
			elseif kind == "TPFC_Glint" then
				if not Settings.LowVFX() then
					local per = p:GetAttribute("Period") or 10
					local u = ph % per
					local k = u < 0.15 and u / 0.15 or (u < 0.65 and 1 - (u - 0.15) / 0.5 or 0)
					p.Transparency = it.baseTr + (0 - it.baseTr) * k
				end
			elseif kind == "TPFC_ChargeChannel" then
				-- energise from the player's side toward the front arch with the charge power
				local idx = p:GetAttribute("Index") or 0
				if charging then
					local wave = 0.5 + 0.5 * math.sin(t * 10 - math.abs(idx) * 0.6)
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
	end)
end

return WorldFx
