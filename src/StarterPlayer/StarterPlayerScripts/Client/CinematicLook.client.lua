-- CinematicLook: premium "modern renderer" finish on top of the existing lighting.
-- Location: StarterPlayer > StarterPlayerScripts > Client > CinematicLook (LocalScript)
--
-- Ownership: Effects.lua / SanctuaryLook own Ambient, ClockTime, Fog, Brightness, ExposureCompensation,
-- the Atmosphere and the TPFC_* post effects, and tween them per zone. This script NEVER writes those.
-- It only adds:
--   * crisp-soft shadows (ShadowSoftness) and a per-zone sun latitude for longer, more graphic shadows
--   * a second filmic grade (TPFC_FilmGrade: contrast/saturation/split tint) stacked on the zone grade
--   * a high-threshold highlight bloom (TPFC_HighlightGlow) so specular glints and neon read as light
--   * a soft drifting ground mist near the camera (built-in smoke texture, no uploads)
-- Everything scales with the player's graphics quality and is skipped on low settings.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local camera = workspace.CurrentCamera

-- per-zone finishing: split-tone tint, extra contrast/saturation, sun latitude, highlight glow
local GRADE = {
	Hub     = { tint = Color3.fromRGB(255, 248, 238), contrast = 0.06, sat = 0, lat = 34, glow = 0.18 },
	Forest  = { tint = Color3.fromRGB(255, 250, 236), contrast = 0.08, sat = 0, lat = 38, glow = 0.18 },
	Volcano = { tint = Color3.fromRGB(255, 236, 222), contrast = 0.12, sat = 0, lat = 24, glow = 0.30 },
	Frozen  = { tint = Color3.fromRGB(240, 248, 255), contrast = 0.07, sat = 0, lat = 52, glow = 0.20 },
	Crystal = { tint = Color3.fromRGB(246, 238, 255), contrast = 0.10, sat = 0, lat = 30, glow = 0.32 },
	Candy   = { tint = Color3.fromRGB(255, 246, 250), contrast = 0.05, sat = 0, lat = 40, glow = 0.16 },
	Space   = { tint = Color3.fromRGB(238, 238, 255), contrast = 0.12, sat = 0, lat = 20, glow = 0.34 },
	Shadow  = { tint = Color3.fromRGB(248, 236, 252), contrast = 0.11, sat = 0, lat = 28, glow = 0.28 },
	Heaven  = { tint = Color3.fromRGB(255, 250, 240), contrast = 0.05, sat = 0, lat = 46, glow = 0.20 },
}

local function quality()
	-- 1..10; Automatic reports 0 -> treat as high
	local ok, q = pcall(function() return UserSettings().GameSettings.SavedQualityLevel.Value end)
	if not ok or q == 0 then return 10 end
	return q
end

---------------------------------------------------------------- post effects (unique names, stacked)
local grade = Lighting:FindFirstChild("TPFC_FilmGrade") or Instance.new("ColorCorrectionEffect")
grade.Name = "TPFC_FilmGrade"
grade.Parent = Lighting

local glow = Lighting:FindFirstChild("TPFC_HighlightGlow") or Instance.new("BloomEffect")
glow.Name = "TPFC_HighlightGlow"
glow.Threshold = 2.4
glow.Size = 40
glow.Parent = Lighting

pcall(function() Lighting.ShadowSoftness = 0.18 end)

---------------------------------------------------------------- ground mist (low drifting fog sheets around the view)
-- Built-in smoke texture, no uploads. A box emitter follows a point ahead of the camera at ground level;
-- sheets are large, very faint and slow so they read as fog layers, never as smoke puffs over the pet.
local MIST = {
	Hub     = { color = Color3.fromRGB(226, 228, 244), rate = 9 },
	Forest  = { color = Color3.fromRGB(222, 238, 226), rate = 12 },
	Volcano = { color = Color3.fromRGB(150, 120, 112), rate = 15 },
	Frozen  = { color = Color3.fromRGB(232, 242, 255), rate = 18 },
	Crystal = { color = Color3.fromRGB(206, 186, 240), rate = 12 },
	Candy   = { color = Color3.fromRGB(255, 226, 242), rate = 12 },
	Space   = { color = Color3.fromRGB(120, 110, 180), rate = 0 },
	Shadow  = { color = Color3.fromRGB(120, 100, 150), rate = 21 },
	Heaven  = { color = Color3.fromRGB(255, 250, 236), rate = 21 },
}
local mistPart = Instance.new("Part")
mistPart.Name = "TPFC_GroundMist"
mistPart.Anchored, mistPart.CanCollide, mistPart.CanQuery, mistPart.CanTouch, mistPart.CastShadow = true, false, false, false, false
mistPart.Transparency = 1
mistPart.Size = Vector3.new(200, 3, 200)
local mist = Instance.new("ParticleEmitter")
mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
mist.Shape = Enum.ParticleEmitterShape.Box
mist.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 16), NumberSequenceKeypoint.new(1, 30) })
mist.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.74),
	NumberSequenceKeypoint.new(0.7, 0.78), NumberSequenceKeypoint.new(1, 1),
})
mist.Lifetime = NumberRange.new(10, 15)
mist.Speed = NumberRange.new(0.3, 1)
mist.SpreadAngle = Vector2.new(180, 10)
mist.Acceleration = Vector3.new(0.25, 0, 0.15)
mist.Rotation = NumberRange.new(0, 360)
mist.RotSpeed = NumberRange.new(-3, 3)
mist.LightInfluence = 0.55
mist.LightEmission = 0
mist.Rate = 0
mist.Parent = mistPart
mistPart.Parent = workspace

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(x, z, fallback)
	local hit = workspace:Raycast(Vector3.new(x, fallback + 120, z), Vector3.new(0, -400, 0), groundParams)
	return hit and hit.Position.Y or 0
end
local mistY, mistT = 0, 0
RunService.Heartbeat:Connect(function(dt)
	local cf = camera.CFrame
	local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, 1)
	local p = cf.Position + look * 45
	mistT += dt
	if mistT > 0.5 then
		mistT = 0
		mistY = groundY(p.X, p.Z, cf.Position.Y)
	end
	mistPart.CFrame = CFrame.new(p.X, mistY + 2, p.Z)
end)

---------------------------------------------------------------- zone tracking (camera position, 2 Hz)
local current
local function apply(id)
	local m = MIST[id] or MIST.Hub
	local mq = quality()
	mist.Color = ColorSequence.new(m.color)
	mist.Rate = mq <= 3 and 0 or (mq <= 6 and m.rate * 0.5 or m.rate)
	local g = GRADE[id] or GRADE.Hub
	local q = quality()
	local strength = q <= 3 and 0 or (q <= 6 and 0.6 or 1)
	local info = TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	TweenService:Create(grade, info, {
		TintColor = Color3.new(1, 1, 1):Lerp(g.tint, strength),
		Contrast = g.contrast * strength,
		Saturation = g.sat * strength,
	}):Play()
	TweenService:Create(glow, info, { Intensity = g.glow * strength }):Play()
	pcall(function() TweenService:Create(Lighting, info, { GeographicLatitude = g.lat }):Play() end)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.5 then return end
	acc = 0
	local pos = camera.CFrame.Position
	local id = (pos.Z < 0) and "Hub" or (Config.WorldAt(pos) or "Hub")
	if id ~= current then
		current = id
		apply(id)
	end
end)
apply("Hub")
