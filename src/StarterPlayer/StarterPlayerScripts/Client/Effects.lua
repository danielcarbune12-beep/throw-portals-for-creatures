-- Effects: camera shake, flashes, shockwaves, particle bursts, light beams, floating text,
-- flying-coin money effect, rarity banners and per-world lighting.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Effects (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local Effects = {}
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFX"
fxFolder.Parent = workspace
Effects.Folder = fxFolder

local gui = Instance.new("ScreenGui")
gui.Name = "FX"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")
Effects.Gui = gui

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
Effects.Tween = tween

---------------------------------------------------------------- camera shake
local shakeAmt, shakeEnd = 0, 0
RunService:BindToRenderStep("TPFC_Shake", Enum.RenderPriority.Camera.Value + 1, function()
	local now = os.clock()
	if now < shakeEnd then
		local k = (shakeEnd - now)
		local a = shakeAmt * math.min(1, k * 3)
		camera.CFrame = camera.CFrame * CFrame.Angles(math.noise(now * 25, 0) * a * 0.03, math.noise(0, now * 25) * a * 0.03, 0)
	end
end)
function Effects.Shake(intensity: number, duration: number)
	local active = os.clock() < shakeEnd
	shakeAmt = active and math.max(shakeAmt, intensity) or intensity
	shakeEnd = math.max(shakeEnd, os.clock() + duration)
end

---------------------------------------------------------------- screen flash
function Effects.Flash(color: Color3, duration: number?, strength: number?)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - (strength or 0.6)
	f.BorderSizePixel = 0
	f.ZIndex = 50
	f.Parent = gui
	tween(f, duration or 0.5, { BackgroundTransparency = 1 }).Completed:Once(function() f:Destroy() end)
end

---------------------------------------------------------------- world-space effects
local function fxPart(size, cf, color, mat, transp, meshType)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.Transparency = transp or 0
	if meshType then
		local m = Instance.new("SpecialMesh"); m.MeshType = meshType; m.Parent = p
	end
	p.Parent = fxFolder
	return p
end
Effects.Part = fxPart

function Effects.Shockwave(pos: Vector3, color: Color3, radius: number?, time: number?)
	local r = radius or 14
	local ring = fxPart(Vector3.new(0.3, 1, 1), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, 0.1)
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, time or 0.6, { Size = Vector3.new(0.1, r * 2, r * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay((time or 0.6) + 0.05, function() ring:Destroy() end)
	-- inner dome pulse
	local dome = fxPart(Vector3.new(1, 1, 1), CFrame.new(pos), color, Enum.Material.ForceField, 0, Enum.MeshType.Sphere)
	tween(dome, (time or 0.6) * 0.8, { Size = Vector3.new(r, r * 0.6, r), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay(time or 0.6, function() dome:Destroy() end)
end

function Effects.Burst(pos: Vector3, colorSeq, count: number?, speed: number?, size: number?, tex: string?)
	local p = fxPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), nil, 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = tex or SPARKLE
	pe.Color = typeof(colorSeq) == "Color3" and ColorSequence.new(colorSeq) or colorSeq
	pe.LightEmission = 1
	pe.Rate = 0
	pe.Lifetime = NumberRange.new(0.6, 1.4)
	pe.Speed = NumberRange.new((speed or 20) * 0.4, speed or 20)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 3
	pe.Acceleration = Vector3.new(0, -8, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size or 1), NumberSequenceKeypoint.new(1, 0) })
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Parent = p
	pe:Emit(count or 40)
	task.delay(2, function() p:Destroy() end)
end

function Effects.LightBeam(pos: Vector3, color: Color3, height: number?, duration: number?)
	local h = height or 120
	local beam = fxPart(Vector3.new(h, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, 0.1)
	beam.Shape = Enum.PartType.Cylinder
	local l = Instance.new("PointLight"); l.Color = color; l.Range = 40; l.Brightness = 5; l.Parent = beam
	tween(beam, 0.35, { Size = Vector3.new(h, 9, 9) }, Enum.EasingStyle.Back)
	task.delay(0.35, function()
		tween(beam, duration or 1.6, { Size = Vector3.new(h, 0.2, 0.2), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(l, duration or 1.6, { Brightness = 0 })
	end)
	task.delay((duration or 1.6) + 0.5, function() beam:Destroy() end)
end

function Effects.FloatingText(pos: Vector3, text: string, color: Color3?, size: number?)
	local anchor = fxPart(Vector3.new(0.1, 0.1, 0.1), CFrame.new(pos), Color3.new(1, 1, 1), nil, 1)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(240, 60)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(30, 20, 40); st.Parent = t
	local sc = Instance.new("UIScale"); sc.Scale = 0.2; sc.Parent = t
	t.Parent = bb
	tween(sc, 0.35, { Scale = size or 1 }, Enum.EasingStyle.Back)
	tween(anchor, 1.6, { CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) }, Enum.EasingStyle.Quad)
	task.delay(1.1, function()
		tween(t, 0.5, { TextTransparency = 1 })
		tween(st, 0.5, { Transparency = 1 })
	end)
	task.delay(1.7, function() anchor:Destroy() end)
end

---------------------------------------------------------------- money: coins fly to the counter
Effects.MoneyTarget = nil -- set by UI to the money counter GuiObject
function Effects.Coins(worldPos: Vector3?, count: number?)
	local target = Effects.MoneyTarget
	if not target then return end
	local start
	if worldPos then
		local sp, onScreen = camera:WorldToViewportPoint(worldPos)
		start = onScreen and Vector2.new(sp.X, sp.Y) or camera.ViewportSize / 2
	else
		start = camera.ViewportSize / 2
	end
	local goal = target.AbsolutePosition + target.AbsoluteSize / 2 + Vector2.new(0, game:GetService("GuiService"):GetGuiInset().Y)
	for i = 1, count or 12 do
		task.delay(i * 0.03, function()
			local c = Instance.new("TextLabel")
			c.Size = UDim2.fromOffset(30, 30)
			c.AnchorPoint = Vector2.new(0.5, 0.5)
			c.Position = UDim2.fromOffset(start.X, start.Y)
			c.BackgroundColor3 = Color3.fromRGB(255, 205, 50)
			c.Text = "$"
			c.Font = Enum.Font.FredokaOne
			c.TextScaled = true
			c.TextColor3 = Color3.fromRGB(160, 100, 0)
			c.ZIndex = 40
			local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(1, 0); corner.Parent = c
			local st = Instance.new("UIStroke"); st.Color = Color3.fromRGB(255, 240, 160); st.Thickness = 2; st.Parent = c
			c.Parent = gui
			local mid = start + Vector2.new(math.random(-120, 120), math.random(-120, 40))
			tween(c, 0.25, { Position = UDim2.fromOffset(mid.X, mid.Y), Rotation = math.random(-40, 40) }, Enum.EasingStyle.Quad)
			task.delay(0.25, function()
				tween(c, 0.45, { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(18, 18) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				task.delay(0.45, function()
					c:Destroy()
					if Effects.OnCoinArrive then Effects.OnCoinArrive() end
				end)
			end)
		end)
	end
end

---------------------------------------------------------------- rarity banner
function Effects.RarityBanner(def, chanceText)
	local rc = Config.Rarities[def.rarity]
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.3)
	holder.Size = UDim2.fromScale(0.6, 0.16)
	holder.BackgroundTransparency = 1
	holder.ZIndex = 45
	holder.Parent = gui
	local sc = Instance.new("UIScale"); sc.Scale = 0; sc.Parent = holder
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.Text = def.rarity:upper() .. "!"
	title.TextColor3 = Color3.new(1, 1, 1)
	title.ZIndex = 46
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new(rc.color:Lerp(Color3.new(1, 1, 1), 0.5), rc.color)
	grad.Rotation = 90
	grad.Parent = title
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Color = Color3.fromRGB(25, 15, 35); st.Parent = title
	title.Parent = holder
	local name = title:Clone()
	name.Size = UDim2.fromScale(1, 0.38)
	name.Position = UDim2.fromScale(0, 0.62)
	name.Text = def.name .. (chanceText and ("  •  " .. chanceText) or "")
	name:FindFirstChildOfClass("UIGradient"):Destroy()
	name.Parent = holder
	tween(sc, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin = RunService.RenderStepped:Connect(function()
		grad.Offset = Vector2.new(0, math.sin(os.clock() * 4) * 0.2)
		holder.Rotation = math.sin(os.clock() * 3) * 2
	end)
	task.delay(2.6, function()
		tween(sc, 0.3, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.35, function() spin:Disconnect(); holder:Destroy() end)
	end)
end

---------------------------------------------------------------- lighting per world
local bloom, cc, atmo, rays
function Effects.SetupLighting()
	-- (Lighting.Technology can't be set by scripts; it's set to Future in the place file)
	pcall(function()
		Lighting.GlobalShadows = true
		Lighting.Brightness = 2.4
		Lighting.EnvironmentDiffuseScale = 0.6
		Lighting.EnvironmentSpecularScale = 0.6
	end)
	bloom = Lighting:FindFirstChild("TPFC_Bloom") or Instance.new("BloomEffect")
	bloom.Name = "TPFC_Bloom"; bloom.Intensity = 0.7; bloom.Size = 28; bloom.Threshold = 1.6; bloom.Parent = Lighting
	cc = Lighting:FindFirstChild("TPFC_CC") or Instance.new("ColorCorrectionEffect")
	cc.Name = "TPFC_CC"; cc.Saturation = 0.18; cc.Contrast = 0.08; cc.Parent = Lighting
	rays = Lighting:FindFirstChild("TPFC_Rays") or Instance.new("SunRaysEffect")
	rays.Name = "TPFC_Rays"; rays.Intensity = 0.06; rays.Spread = 0.6; rays.Parent = Lighting
	atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.3; atmo.Haze = 1; atmo.Glare = 0.3; atmo.Parent = Lighting
	local dof = Lighting:FindFirstChild("TPFC_DOF") or Instance.new("DepthOfFieldEffect")
	dof.Name = "TPFC_DOF"; dof.FarIntensity = 0.12; dof.FocusDistance = 60; dof.InFocusRadius = 80; dof.NearIntensity = 0; dof.Parent = Lighting
	Effects.SetupExtras()
end

-- ambient particles that follow the camera, themed per zone
local AMBIENT = {
	Forest  = { col = { Color3.fromRGB(220, 255, 140), Color3.fromRGB(255, 240, 160) }, rate = 18, speed = 0.6, size = 0.35, accel = Vector3.new(0, 0.3, 0) },   -- fireflies
	Volcano = { col = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 60, 20) },    rate = 40, speed = 1.5, size = 0.3,  accel = Vector3.new(0, 4, 0) },      -- embers
	Frozen  = { col = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 235, 255) }, rate = 70, speed = 1,   size = 0.35, accel = Vector3.new(1, -4, 0) },     -- snow
	Crystal = { col = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(100, 240, 255) }, rate = 30, speed = 0.5, size = 0.4,  accel = Vector3.new(0, 0.5, 0) },
	Candy   = { col = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(140, 220, 255) }, rate = 30, speed = 0.8, size = 0.45, accel = Vector3.new(0, -1, 0) },
	Space   = { col = { Color3.fromRGB(255, 255, 220), Color3.fromRGB(160, 140, 255) }, rate = 50, speed = 0.2, size = 0.3,  accel = Vector3.zero },             -- stardust
	Shadow  = { col = { Color3.fromRGB(150, 60, 255), Color3.fromRGB(60, 0, 90) },      rate = 30, speed = 0.4, size = 0.6,  accel = Vector3.new(0, 0.6, 0) },
	Heaven  = { col = { Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 255, 255) }, rate = 40, speed = 0.6, size = 0.45, accel = Vector3.new(0, 1, 0) },     -- light motes
}
local ambientPart, ambientPE
local function setupAmbient()
	ambientPart = Instance.new("Part")
	ambientPart.Name = "Ambient"
	ambientPart.Anchored, ambientPart.CanCollide, ambientPart.CanQuery, ambientPart.CanTouch = true, false, false, false
	ambientPart.Transparency = 1
	ambientPart.Size = Vector3.new(80, 30, 80)
	ambientPart.Parent = fxFolder
	ambientPE = Instance.new("ParticleEmitter")
	ambientPE.Texture = SPARKLE
	ambientPE.Shape = Enum.ParticleEmitterShape.Box
	ambientPE.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	ambientPE.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	ambientPE.LightEmission = 1
	ambientPE.Lifetime = NumberRange.new(3, 6)
	ambientPE.SpreadAngle = Vector2.new(180, 180)
	ambientPE.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.1), NumberSequenceKeypoint.new(0.8, 0.2), NumberSequenceKeypoint.new(1, 1) })
	ambientPE.Parent = ambientPart
	RunService.RenderStepped:Connect(function()
		ambientPart.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * 25)
	end)
end
local function applyAmbient(id)
	local a = AMBIENT[id]
	if not a or not ambientPE then return end
	ambientPE.Color = ColorSequence.new(a.col[1], a.col[2])
	ambientPE.Rate = a.rate
	ambientPE.Speed = NumberRange.new(a.speed * 0.5, a.speed)
	ambientPE.Acceleration = a.accel
	ambientPE.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, a.size), NumberSequenceKeypoint.new(1, 0) })
end

local clouds, sky
local function setupSky()
	pcall(function()
		clouds = workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Color = Color3.new(1, 1, 1)
		clouds.Parent = workspace.Terrain
	end)
	sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 3000
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
end

function Effects.SetupExtras()
	-- (the floating ambient particles were removed on request)
	setupSky()
end

local currentWorld
function Effects.UpdateWorld(pos: Vector3)
	local id = Config.WorldAt(pos)
	if not id or id == currentWorld then return currentWorld end
	currentWorld = id
	local W = Config.Worlds[id]
	applyAmbient(id)
	if clouds then
		local cover = ({ Forest = 0.55, Volcano = 0.75, Frozen = 0.8, Crystal = 0.3, Candy = 0.6, Space = 0, Shadow = 0.7, Heaven = 0.9 })[id] or 0.5
		local ccol = ({ Volcano = Color3.fromRGB(90, 60, 60), Shadow = Color3.fromRGB(70, 40, 90), Candy = Color3.fromRGB(255, 210, 235) })[id] or Color3.new(1, 1, 1)
		tween(clouds, 2, { Cover = cover, Color = ccol })
	end
	tween(Lighting, 1.5, { Ambient = W.ambient, OutdoorAmbient = W.ambient, ClockTime = W.clock, FogColor = W.fog })
	if cc then tween(cc, 1.5, { TintColor = W.tint }) end
	if atmo then tween(atmo, 1.5, { Color = W.atmo, Decay = W.fog, Density = (id == "Space") and 0.15 or (id == "Shadow" and 0.45 or 0.3) }) end
	return id
end

return Effects
