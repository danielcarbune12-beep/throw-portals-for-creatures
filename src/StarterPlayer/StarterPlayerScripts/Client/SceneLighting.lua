-- The only runtime owner of scene light, atmosphere, clouds and grading.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Look = require(Shared.SanctuaryLook)
local Config = require(Shared.Config)
local Settings = require(script.Parent.ClientSettings)
local Scene = {}
local started, refs, lastKey
local activeTweens = {}
local function lowQuality()
	local q = UserSettings().GameSettings.SavedQualityLevel.Value
	return Settings.LowVFX() or (q > 0 and q <= 3)
end
function Scene.Refresh(force)
	if not refs then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local pos = camera.CFrame.Position
	local id = pos.Z < Config.BarrierZ and "Hub" or Config.WorldAt(pos)
	local weather = workspace:GetAttribute("FarmWeather") or "Clear"
	local low = lowQuality()
	local key = table.concat(
		{ id, weather, tostring(low), tostring(Settings.ReducedMotion), tostring(Settings.ReducedFlashes) },
		":"
	)
	if key == lastKey and not force then
		return
	end
	lastKey = key
	local target = Look.Targets(id, weather, low, Settings.ReducedFlashes)
	for _, tw in activeTweens do
		tw:Cancel()
	end
	table.clear(activeTweens)
	local info =
		TweenInfo.new(Settings.ReducedMotion and 0.25 or 1.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	for group, object in refs do
		local tw = TweenService:Create(object, info, target[group])
		table.insert(activeTweens, tw)
		tw:Play()
	end
	refs.bloom.Enabled, refs.rays.Enabled = not low, not low
	workspace:SetAttribute("TPFC_VisualZone", id)
	workspace:SetAttribute("TPFC_VisualWeather", weather)
	workspace:SetAttribute("TPFC_VisualLow", low)
end
function Scene.Start()
	if started then
		return
	end
	started = true
	refs = Look.Apply(Lighting)
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Parent = workspace.Terrain
	refs.clouds = clouds
	local obsolete = workspace:FindFirstChild("TPFC_GroundMist")
	if obsolete then
		obsolete:Destroy()
	end
	Scene.Refresh(true)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.2 then
			elapsed = 0
			Scene.Refresh()
		end
	end)
	workspace:GetAttributeChangedSignal("FarmWeather"):Connect(function()
		Scene.Refresh()
	end)
	Settings.Changed.Event:Connect(function()
		Scene.Refresh()
	end)
	UserSettings().GameSettings:GetPropertyChangedSignal("SavedQualityLevel"):Connect(function()
		Scene.Refresh()
	end)
end
return Scene
