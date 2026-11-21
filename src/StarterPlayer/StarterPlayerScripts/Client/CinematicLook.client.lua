-- CinematicLook: premium "modern renderer" finish on top of the existing lighting.
-- Location: StarterPlayer > StarterPlayerScripts > Client > CinematicLook (LocalScript)
--
-- Ownership: Effects.lua / SanctuaryLook own Ambient, ClockTime, Fog, Brightness, ExposureCompensation,
-- the Atmosphere and the TPFC_* post effects, and tween them per zone. This script NEVER writes those.
-- It only adds:
--   * crisp-soft shadows (ShadowSoftness) and a per-zone sun latitude for longer, more graphic shadows
--   * a second filmic grade (TPFC_FilmGrade: contrast/saturation/split tint) stacked on the zone grade
--   * a high-threshold highlight bloom (TPFC_HighlightGlow) so specular glints and neon read as light
--   * an asset-free edge vignette (four gradient frames) that never takes input
-- Everything scales with the player's graphics quality and is skipped on low settings.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- per-zone finishing: split-tone tint, extra contrast/saturation, sun latitude, highlight glow
local GRADE = {
	Hub     = { tint = Color3.fromRGB(255, 248, 238), contrast = 0.06, sat = 0.06, lat = 34, glow = 0.18 },
	Forest  = { tint = Color3.fromRGB(255, 250, 236), contrast = 0.08, sat = 0.10, lat = 38, glow = 0.18 },
	Volcano = { tint = Color3.fromRGB(255, 236, 222), contrast = 0.12, sat = 0.08, lat = 24, glow = 0.30 },
	Frozen  = { tint = Color3.fromRGB(240, 248, 255), contrast = 0.07, sat = 0.04, lat = 52, glow = 0.20 },
	Crystal = { tint = Color3.fromRGB(246, 238, 255), contrast = 0.10, sat = 0.10, lat = 30, glow = 0.32 },
	Candy   = { tint = Color3.fromRGB(255, 246, 250), contrast = 0.05, sat = 0.04, lat = 40, glow = 0.16 },
	Space   = { tint = Color3.fromRGB(238, 238, 255), contrast = 0.12, sat = 0.06, lat = 20, glow = 0.34 },
	Shadow  = { tint = Color3.fromRGB(248, 236, 252), contrast = 0.11, sat = 0.06, lat = 28, glow = 0.28 },
	Heaven  = { tint = Color3.fromRGB(255, 250, 240), contrast = 0.05, sat = 0.05, lat = 46, glow = 0.20 },
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

---------------------------------------------------------------- vignette (no image assets: four gradient edges)
local gui = Instance.new("ScreenGui")
gui.Name = "TPFC_Vignette"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = -10
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
local edges = {}
local function edge(pos, size, rotation)
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Color3.fromRGB(8, 6, 16)
	f.BorderSizePixel = 0
	f.Position, f.Size = pos, size
	f.Active = false
	pcall(function() f.Interactable = false end)
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.55, 0.92), NumberSequenceKeypoint.new(1, 1) })
	g.Parent = f
	f.Parent = gui
	table.insert(edges, g)
end
edge(UDim2.fromScale(0, 0), UDim2.fromScale(0.22, 1), 0)       -- left -> fades rightward
edge(UDim2.fromScale(0.78, 0), UDim2.fromScale(0.22, 1), 180)   -- right
edge(UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.2), 90)        -- top
edge(UDim2.fromScale(0, 0.8), UDim2.fromScale(1, 0.2), 270)     -- bottom
gui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------- zone tracking (camera position, 2 Hz)
local current
local function apply(id)
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
	gui.Enabled = strength > 0
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
