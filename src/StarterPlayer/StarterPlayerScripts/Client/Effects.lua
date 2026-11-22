-- Effects: camera shake, flashes, shockwaves, particle bursts, light beams, floating text,
-- flying-coin money effect, rarity banners and per-world lighting.
-- Location: StarterPlayer > StarterPlayerScripts > Client > Effects (ModuleScript)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Settings = require(script.Parent.ClientSettings)

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
	if not Settings.CameraShake then return end
	if Settings.ReducedMotion then intensity *= 0.4 end
	local active = os.clock() < shakeEnd
	shakeAmt = active and math.max(shakeAmt, intensity) or intensity
	shakeEnd = math.max(shakeEnd, os.clock() + duration)
end

---------------------------------------------------------------- screen flash
function Effects.Flash(color: Color3, duration: number?, strength: number?)
	if Settings.ReducedFlashes then return end
	-- never a full-opacity frame: cap strength so the scene stays visible
	strength = math.min(strength or 0.6, 0.35)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 1 - strength
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
	local ring = fxPart(Vector3.new(0.3, 1, 1), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, 0.4)
	ring.Shape = Enum.PartType.Cylinder
	tween(ring, time or 0.6, { Size = Vector3.new(0.1, r * 2, r * 2), Transparency = 1 }, Enum.EasingStyle.Quart)
	task.delay((time or 0.6) + 0.05, function() ring:Destroy() end)
	-- inner dome pulse
	local dome = fxPart(Vector3.new(1, 1, 1), CFrame.new(pos), color, Enum.Material.ForceField, 0.92, Enum.MeshType.Sphere)
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
	local beam = fxPart(Vector3.new(h, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, Enum.Material.Neon, 0.78)
	beam.Shape = Enum.PartType.Cylinder
	local l = Instance.new("PointLight"); l.Color = color; l.Range = 18; l.Brightness = 1.2; l.Parent = beam
	tween(beam, 0.25, { Size = Vector3.new(h, 1.1, 1.1) }, Enum.EasingStyle.Quart)
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
	t.Font = require(script.Parent.UITheme).Display
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 2; st.Transparency = 0.25; st.Color = Color3.fromRGB(10, 8, 18); st.Parent = t
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
-- Tiered cinematic title (caption -> gold card -> full-screen moment for Legendary+), see RevealTitle.
function Effects.RarityBanner(def, chanceText)
	local ok, err = pcall(function() require(script.Parent.RevealTitle).Show(def, chanceText) end)
	if not ok then warn("[RevealTitle] " .. tostring(err)) end
end

---------------------------------------------------------------- lighting per world
local bloom, cc, atmo, rays
function Effects.SetupLighting()
	-- (Lighting.Technology can't be set by scripts; it's set to Future in the place file)
	pcall(function()
		Lighting.GlobalShadows = true
		Lighting.Brightness = 3
		Lighting.ShadowSoftness = 0.06 -- crisp directional shadows
		Lighting.EnvironmentDiffuseScale = 0.55
		Lighting.EnvironmentSpecularScale = 0.3 -- stone/wood read matte, not plastic
		Lighting.GeographicLatitude = 38
		local look = require(ReplicatedStorage.Shared.SanctuaryLook)
		Lighting.ColorShift_Top = look.sunTop
		Lighting.ColorShift_Bottom = look.shadeBottom
	end)
	bloom = Lighting:FindFirstChild("TPFC_Bloom") or Instance.new("BloomEffect")
	bloom.Name = "TPFC_Bloom"; bloom.Intensity = 0.3; bloom.Size = 22; bloom.Threshold = 1.9; bloom.Parent = Lighting
	cc = Lighting:FindFirstChild("TPFC_CC") or Instance.new("ColorCorrectionEffect")
	cc.Name = "TPFC_CC"; cc.Saturation = 0.06; cc.Contrast = 0.1; cc.Brightness = 0; cc.Parent = Lighting
	rays = Lighting:FindFirstChild("TPFC_Rays") or Instance.new("SunRaysEffect")
	rays.Name = "TPFC_Rays"; rays.Intensity = 0.05; rays.Spread = 0.6; rays.Parent = Lighting
	atmo = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmo.Density = 0.3; atmo.Offset = 0.16; atmo.Haze = 0.9; atmo.Glare = 0.15; atmo.Parent = Lighting
	local dof = Lighting:FindFirstChild("TPFC_DOF") or Instance.new("DepthOfFieldEffect")
	dof.Name = "TPFC_DOF"; dof.FarIntensity = 0; dof.FocusDistance = 50; dof.InFocusRadius = 70; dof.NearIntensity = 0; dof.Parent = Lighting
	Effects.DOF = dof
	Effects.SetupExtras()
	-- vignette removed on request (clean frame edges)
end

---------------------------------------------------------------- cinematic vignette + letterbox bars
function Effects.SetupVignette()
	-- soft dark edges (four gradient frames), always on, drawn BELOW the HUD
	local vgui = Instance.new("ScreenGui")
	vgui.Name = "Vignette"
	vgui.IgnoreGuiInset = true
	vgui.ResetOnSpawn = false
	vgui.DisplayOrder = -5
	vgui.Parent = gui.Parent
	local edges = {
		{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0), 90 },
		{ UDim2.new(1, 0, 0.22, 0), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0, 0), 0 },
		{ UDim2.new(0.16, 0, 1, 0), UDim2.fromScale(0.84, 0), 180 },
	}
	for _, e in ipairs(edges) do
		local f = Instance.new("Frame")
		f.Size, f.Position = e[1], e[2]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 1
		local g = Instance.new("UIGradient")
		g.Rotation = e[3]
		g.Transparency = NumberSequence.new(0.55, 1)
		g.Parent = f
		f.Parent = vgui
	end
end

local bars
function Effects.Letterbox(on: boolean)
	if not bars then
		bars = {}
		for i, pos in ipairs({ UDim2.fromScale(0, -0.12), UDim2.fromScale(0, 1) }) do
			local b = Instance.new("Frame")
			b.Size = UDim2.fromScale(1, 0.12)
			b.Position = pos
			b.BackgroundColor3 = Color3.new(0, 0, 0)
			b.BorderSizePixel = 0
			b.ZIndex = 45
			b.Parent = gui
			bars[i] = b
		end
	end
	tween(bars[1], 0.45, { Position = on and UDim2.fromScale(0, 0) or UDim2.fromScale(0, -0.12) }, Enum.EasingStyle.Quad)
	tween(bars[2], 0.45, { Position = on and UDim2.fromScale(0, 0.88) or UDim2.fromScale(0, 1) }, Enum.EasingStyle.Quad)
end

-- ambient particles that follow the camera, themed per zone
local AMBIENT = {
	Hub = { col = { Color3.fromRGB(241,202,115), Color3.fromRGB(168,139,244) }, rate=6, speed=.3, size=.12, accel=Vector3.new(0,.05,0) },
	Forest  = { col = { Color3.fromRGB(220, 255, 140), Color3.fromRGB(255, 240, 160) }, rate = 18, speed = 0.6, size = 0.35, accel = Vector3.new(0, 0.3, 0) },   -- fireflies
	Volcano = { col = { Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 60, 20) },    rate = 40, speed = 1.5, size = 0.3,  accel = Vector3.new(0, 4, 0) },      -- embers
	Frozen  = { col = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 235, 255) }, rate = 70, speed = 1,   size = 0.35, accel = Vector3.new(1, -4, 0) },     -- snow
	Crystal = { col = { Color3.fromRGB(200, 120, 255), Color3.fromRGB(100, 240, 255) }, rate = 30, speed = 0.5, size = 0.4,  accel = Vector3.new(0, 0.5, 0) },
	Candy   = { col = { Color3.fromRGB(255, 130, 200), Color3.fromRGB(140, 220, 255) }, rate = 30, speed = 0.8, size = 0.45, accel = Vector3.new(0, -1, 0) },
	Space   = { col = { Color3.fromRGB(255, 255, 220), Color3.fromRGB(160, 140, 255) }, rate = 50, speed = 0.2, size = 0.3,  accel = Vector3.zero },             -- stardust
	Shadow  = { col = { Color3.fromRGB(150, 60, 255), Color3.fromRGB(60, 0, 90) },      rate = 30, speed = 0.4, size = 0.6,  accel = Vector3.new(0, 0.6, 0) },
	Heaven  = { col = { Color3.fromRGB(255, 245, 190), Color3.fromRGB(255, 255, 255) }, rate = 40, speed = 0.6, size = 0.45, accel = Vector3.new(0, 1, 0) },     -- light motes
}
local ambientPart, ambientPE, currentWorld
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

Settings.Changed.Event:Connect(function(key,value)
	if key=="AmbientMotes" then
		if value and not ambientPE then setupAmbient() applyAmbient(currentWorld or "Hub") end
		if ambientPE then ambientPE.Enabled=value end
	end
end)

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
	-- The camera-following ambient particle field was removed on request and stays OFF by default.
	-- It only comes back if a player explicitly enables Settings.AmbientMotes.
	setupSky()
	if Settings.AmbientMotes then setupAmbient() end
end

---------------------------------------------------------------- procedural motifs (no fake textures)
-- Small local shapes for species accents: leaves, petals, embers, snowflakes, hearts, stars,
-- bubbles, clouds, honeycomb, arcs, rings. Each is a tiny anchored model that drifts and fades.
local PI = math.pi
local function shapePart(size, cf, color, meshType, mat, tr)
	local p = fxPart(size, cf, color, mat or Enum.Material.SmoothPlastic, tr or 0, meshType or Enum.MeshType.Sphere)
	return p
end

local function wedgePair(parts, cf, thick, h, base, color, mat)
	table.insert(parts, shapePart(Vector3.new(thick, h, base / 2), cf * CFrame.new(0, 0, -base / 4), color, Enum.MeshType.Wedge, mat))
	table.insert(parts, shapePart(Vector3.new(thick, h, base / 2), cf * CFrame.new(0, 0, base / 4) * CFrame.Angles(0, PI, 0), color, Enum.MeshType.Wedge, mat))
end

-- builds a shape at cf; returns list of { part, offset }
local function buildShape(kind, cf, color, k)
	local parts = {}
	if kind == "leaf" or kind == "petal" or kind == "flame" then
		local R = cf * CFrame.Angles(0, PI / 2, 0)
		local len, w = 0.9 * k, 0.45 * k
		local mat = kind == "flame" and Enum.Material.Neon or nil
		wedgePair(parts, R * CFrame.new(0, len / 4, 0), 0.06 * k, len / 2, w, color, mat)
		wedgePair(parts, R * CFrame.new(0, -len / 4, 0) * CFrame.Angles(0, 0, PI), 0.06 * k, len / 2, w, color, mat)
	elseif kind == "snowflake" then
		for i = 0, 2 do table.insert(parts, shapePart(Vector3.new(0.08, 0.8, 0.08) * k, cf * CFrame.Angles(0, 0, i * PI / 3), color, Enum.MeshType.Brick, Enum.Material.Neon)) end
	elseif kind == "star" then
		for i = 0, 1 do
			local R = cf * CFrame.Angles(0, 0, i * PI / 2) * CFrame.Angles(0, PI / 2, 0)
			wedgePair(parts, R * CFrame.new(0, 0.18 * k, 0), 0.05 * k, 0.36 * k, 0.16 * k, color, Enum.Material.Neon)
			wedgePair(parts, R * CFrame.new(0, -0.18 * k, 0) * CFrame.Angles(0, 0, PI), 0.05 * k, 0.36 * k, 0.16 * k, color, Enum.Material.Neon)
		end
	elseif kind == "heart" then
		table.insert(parts, shapePart(Vector3.new(0.4, 0.4, 0.18) * k, cf * CFrame.new(-0.16 * k, 0.1 * k, 0), color))
		table.insert(parts, shapePart(Vector3.new(0.4, 0.4, 0.18) * k, cf * CFrame.new(0.16 * k, 0.1 * k, 0), color))
		wedgePair(parts, cf * CFrame.new(0, -0.15 * k, 0) * CFrame.Angles(0, PI / 2, PI), 0.18 * k, 0.42 * k, 0.6 * k, color)
	elseif kind == "bubble" then
		table.insert(parts, shapePart(Vector3.new(1, 1, 1) * k, cf, color, Enum.MeshType.Sphere, Enum.Material.Glass, 0.5))
	elseif kind == "cloud" then
		for i = -1, 1 do table.insert(parts, shapePart(Vector3.new(1.1, 0.8, 0.9) * k * (1 - math.abs(i) * 0.2), cf * CFrame.new(i * 0.6 * k, 0, 0), color)) end
	elseif kind == "hex" then
		table.insert(parts, shapePart(Vector3.new(0.12, 0.7, 0.7) * k, cf * CFrame.Angles(0, PI / 2, 0), color, Enum.MeshType.Cylinder, Enum.Material.Glass, 0.3))
	elseif kind == "cube" then
		table.insert(parts, shapePart(Vector3.new(0.35, 0.35, 0.35) * k, cf, color, Enum.MeshType.Brick, Enum.Material.Neon))
	else -- mote
		table.insert(parts, shapePart(Vector3.new(0.3, 0.3, 0.3) * k, cf, color, Enum.MeshType.Sphere, Enum.Material.Neon))
	end
	return parts
end

-- animate a shape from cf along `velocity` with a spin, fading out over `life`
local function driftShape(kind, cf, color, k, velocity, life, spin)
	local parts = buildShape(kind, cf, color, k)
	local offsets = {}
	for i, p in ipairs(parts) do offsets[i] = cf:ToObjectSpace(p.CFrame) end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if t >= life then
			conn:Disconnect()
			for _, p in ipairs(parts) do p:Destroy() end
			return
		end
		local u = t / life
		local base = CFrame.new(cf.Position + velocity * t + Vector3.new(0, -0.5 * t * t * (velocity.Y < 0 and 1 or 0), 0)) * cf.Rotation * CFrame.Angles(0, t * (spin or 2), math.sin(t * 3) * 0.4)
		for i, p in ipairs(parts) do
			p.CFrame = base * offsets[i]
			p.LocalTransparencyModifier = math.max(0, (u - 0.6) / 0.4)
		end
	end)
end

local MOTIF_COLORS = {
	leaf = Color3.fromRGB(120, 210, 90), petal = Color3.fromRGB(255, 150, 210), ember = Color3.fromRGB(255, 150, 50),
	snow = Color3.fromRGB(230, 248, 255), star = Color3.fromRGB(255, 240, 160), cloud = Color3.fromRGB(255, 250, 255),
	honey = Color3.fromRGB(255, 190, 40), gold = Color3.fromRGB(255, 215, 90), cyan = Color3.fromRGB(125, 249, 255),
}
local RAINBOW = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 235, 80), Color3.fromRGB(110, 230, 110),
	Color3.fromRGB(90, 200, 255), Color3.fromRGB(120, 120, 255), Color3.fromRGB(210, 110, 255) }

local function arc(origin, forward, radius, n, colorAt, kind, k, life)
	local right = forward:Cross(Vector3.yAxis).Unit
	for i = 1, n do
		local a = (i - 1) / math.max(1, n - 1) * PI
		local pos = origin + right * math.cos(a) * radius + Vector3.new(0, math.sin(a) * radius, 0)
		task.delay(i * 0.03, driftShape, kind, CFrame.lookAt(pos, pos + forward), colorAt(i), k, Vector3.new(0, 0.3, 0), life, 0.5)
	end
end

local function ring(center, radius, n, kind, color, k, life, rise)
	for i = 1, n do
		local a = i / n * PI * 2
		local pos = center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
		driftShape(kind, CFrame.new(pos), color, k, Vector3.new(0, rise or 0.5, 0), life, 1)
	end
end

-- kind: species accent event name (SpeciesProfiles fx); pos: creature centre; forward: facing
function Effects.Motif(kind: string, pos: Vector3, forward: Vector3, accent: Color3?, size: number?)
	local k = size or 1
	local low = Settings.LowVFX()
	local C = MOTIF_COLORS
	accent = accent or C.star
	if kind == "leaf" or kind == "leaves2" then
		for i = 1, (kind == "leaves2" and 2 or 1) do
			driftShape("leaf", CFrame.new(pos + Vector3.new((i - 1.5) * 1.2, 0.5, 0)) * CFrame.Angles(0.6, i, 0.3), C.leaf, k, Vector3.new((i - 1.5) * 0.6, -0.8, 0), 1.8, 1.5)
		end
	elseif kind == "petals" then
		for i = 1, low and 3 or 5 do
			driftShape("petal", CFrame.new(pos) * CFrame.Angles(0, i * 1.25, 0.5), C.petal, k * 0.8, Vector3.new(math.cos(i * 1.25), 2.5, math.sin(i * 1.25)), 1.2, 3)
		end
	elseif kind == "ember" then
		for i = 1, 3 do driftShape("flame", CFrame.new(pos + Vector3.new((i - 2) * 0.5, 0, 0)), C.ember, k * 0.6, Vector3.new(0, 3 + i, 0), 0.9, 4) end
	elseif kind == "puff" or kind == "groundSmoke" then
		Effects.Burst(pos - Vector3.new(0, 1, 0), ColorSequence.new(Color3.fromRGB(220, 210, 200)), low and 6 or 12, 6, 1.4, "rbxasset://textures/particles/smoke_main.dds")
	elseif kind == "frost" then
		Effects.Burst(pos - Vector3.new(0, 1, 0), ColorSequence.new(Color3.fromRGB(235, 248, 255)), low and 8 or 16, 6, 1.2, "rbxasset://textures/particles/smoke_main.dds")
	elseif kind == "snowflakes" then
		for i = 1, 3 do driftShape("snowflake", CFrame.new(pos + Vector3.new((i - 2) * 1.2, 1, 0)), C.snow, k * 0.8, Vector3.new(0, -0.5, 0), 1.6, 1) end
	elseif kind == "snowflakeRing" then
		ring(pos + Vector3.new(0, 4, 0), 3.5 * k, low and 4 or 6, "snowflake", C.snow, k, 1.4, -0.5)
	elseif kind == "bubble" then
		driftShape("bubble", CFrame.new(pos + Vector3.new(0, 1, 0)), accent, k * 0.8, Vector3.new(0, 1.2, 0), 0.7, 0)
	elseif kind == "flowerBud" then
		for i = 1, 5 do driftShape("petal", CFrame.new(pos + forward * 2.5) * CFrame.Angles(0, i * 1.25, 0.9), C.petal, k * 0.5, Vector3.new(math.cos(i * 1.25) * 0.6, 0.6, math.sin(i * 1.25) * 0.6), 1.4, 0.5) end
	elseif kind == "ashSwirl" or kind == "starburst" or kind == "nebulaPuff" or kind == "cometTrail" then
		local col = kind == "ashSwirl" and ColorSequence.new(Color3.fromRGB(120, 110, 110), Color3.fromRGB(255, 140, 60)) or ColorSequence.new(accent)
		Effects.Burst(pos, col, low and 10 or 24, 8, 0.8)
	elseif kind == "glint" or kind == "branchLight" or kind == "mote" then
		driftShape("star", CFrame.new(pos + Vector3.new(0, 2, 0)), kind == "branchLight" and Color3.fromRGB(140, 255, 180) or Color3.new(1, 1, 1), k * 1.2, Vector3.new(0, 0.8, 0), 0.6, 2)
	elseif kind == "auroraArc" or kind == "prismArcs" or kind == "rainbowArc" or kind == "rainbowRibbon" then
		if not low then arc(pos - forward * 2, forward, 4 * k, 7, function(i) return RAINBOW[i] end, "cube", k * 0.7, 1.4) end
	elseif kind == "wrapper" then
		for i = -1, 1, 2 do driftShape("petal", CFrame.new(pos + Vector3.new(i * 1.2, 1.5, 0)) * CFrame.Angles(0, 0, i * 0.6), accent, k, Vector3.new(i * 1.5, 1, 0), 0.8, 2) end
	elseif kind == "cloudPuff" or kind == "cloudRibbon" then
		for i = 1, kind == "cloudRibbon" and 4 or 2 do
			driftShape("cloud", CFrame.new(pos + Vector3.new((i - 2) * 1.6, -0.5, 0)), C.cloud, k, Vector3.new((i - 2) * 0.5, 0.4, 0), 1.5, 0)
		end
	elseif kind == "honeycomb" then
		ring(pos + Vector3.new(0, 2, 0) - forward * 1.5, 1.6 * k, low and 4 or 6, "hex", C.honey, k, 1.2, 0.2)
	elseif kind == "ringRipple" or kind == "primordialRing" or kind == "creationRing" or kind == "dawnDisk" then
		Effects.Shockwave(pos, kind == "ringRipple" and accent or C.gold, 9 * k, 0.9)
	elseif kind == "constellation" or kind == "galaxySpiral" then
		for i = 1, low and 4 or 7 do
			local a = i * 0.9
			driftShape("star", CFrame.new(pos + Vector3.new(math.cos(a) * (2 + i * 0.4), 3 + math.sin(i) * 1.5, math.sin(a) * (2 + i * 0.4))), C.star, k * 0.7, Vector3.zero, 1.6, 1)
		end
	elseif kind == "rift" or kind == "eclipseDisk" then
		local disk = fxPart(Vector3.new(0.2, 0.5, 0.5), CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0) + forward) * CFrame.Angles(0, PI / 2, 0),
			kind == "rift" and Color3.fromRGB(20, 0, 40) or Color3.fromRGB(10, 6, 16), Enum.Material.SmoothPlastic, 0.1)
		disk.Shape = Enum.PartType.Cylinder
		tween(disk, 0.4, { Size = Vector3.new(0.2, 7 * k, 7 * k) }, Enum.EasingStyle.Back)
		if kind == "eclipseDisk" then Effects.Shockwave(pos + Vector3.new(0, 3, 0), C.gold, 5 * k, 0.8) end
		task.delay(1.2, function() tween(disk, 0.5, { Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1 }) end)
		task.delay(1.8, function() disk:Destroy() end)
	elseif kind == "shadowMotes" then
		for i = 1, 2 do driftShape("mote", CFrame.new(pos + Vector3.new(i - 1.5, 0.5, 0)), Color3.fromRGB(70, 30, 120), k, Vector3.new(i - 1.5, 0.8, 0), 1.4, 0) end
	elseif kind == "goldenArch" then
		arc(pos - forward * 2, forward, 5 * k, low and 5 or 9, function() return C.gold end, "cube", k * 0.6, 1.6)
	elseif kind == "tailStars" then
		arc(pos + Vector3.new(0, 1, 0) - forward * 2, forward, 3 * k, 9, function() return Color3.new(1, 1, 1) end, "star", k * 0.7, 1.6)
	elseif kind == "helix" then
		for i = 1, low and 6 or 12 do
			local a = i * 0.7
			task.delay(i * 0.05, driftShape, "mote", CFrame.new(pos + Vector3.new(math.cos(a) * 2, i * 0.4, math.sin(a) * 2)), C.gold, k * 0.6, Vector3.new(0, 2, 0), 1.0, 0)
		end
	elseif kind == "clockRing" then
		ring(pos + Vector3.new(0, 3, 0), 3.5 * k, 12, "cube", C.cyan, k * 0.5, 1.4, 0)
	elseif kind == "seed" then
		driftShape("mote", CFrame.new(pos + forward * 2), Color3.fromRGB(255, 250, 220), k * 1.4, Vector3.new(0, 0.3, 0), 1.6, 0)
	elseif kind == "heart" then
		driftShape("heart", CFrame.new(pos + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 120, 170), k, Vector3.new(0, 2, 0), 1.0, 0)
	else
		Effects.Burst(pos, ColorSequence.new(accent), low and 6 or 14, 8, 0.6)
	end
end

local HUB_LOOK = require(ReplicatedStorage.Shared.SanctuaryLook)

-- per-zone grade + fog, restrained: lighting does the work, not bloom or saturation.
-- density/offset keep the near field crisp and let distant structures fall into soft layers.
local LOOK = {
	Forest  = { exposure = -0.05, sat = 0.08, contrast = 0.12, bloom = 0.3,  rays = 0.07, density = 0.33, haze = 0.9, offset = 0.14, glare = 0.2 },
	Volcano = { exposure = -0.1,  sat = 0.08, contrast = 0.16, bloom = 0.45, rays = 0.06, density = 0.38, haze = 1.4, offset = 0.12, glare = 0.15 },
	Frozen  = { exposure = -0.15, sat = 0.02, contrast = 0.1,  bloom = 0.3,  rays = 0.07, density = 0.36, haze = 1.1, offset = 0.14, glare = 0.25 },
	Crystal = { exposure = -0.05, sat = 0.06, contrast = 0.14, bloom = 0.55, rays = 0.03, density = 0.34, haze = 0.8, offset = 0.14, glare = 0.1 },
	Candy   = { exposure = -0.25, sat = 0.08, contrast = 0.08, bloom = 0.3,  rays = 0.06, density = 0.32, haze = 0.8, offset = 0.15, glare = 0.15 },
	Space   = { exposure = 0.0,   sat = 0.06, contrast = 0.18, bloom = 0.7,  rays = 0.0,  density = 0.2,  haze = 0.4, offset = 0.1,  glare = 0.0 },
	Shadow  = { exposure = -0.05, sat = 0.04, contrast = 0.18, bloom = 0.6,  rays = 0.0,  density = 0.4,  haze = 1.2, offset = 0.1,  glare = 0.0 },
	Heaven  = { exposure = -0.2,  sat = 0.04, contrast = 0.08, bloom = 0.35, rays = 0.08, density = 0.34, haze = 1.1, offset = 0.15, glare = 0.3 },
}

function Effects.UpdateWorld(pos: Vector3)
	local inHub = pos.Z < Config.BarrierZ
	local id = inHub and "Hub" or Config.WorldAt(pos)
	if not id or id == currentWorld then return currentWorld end
	currentWorld = id
	local W = inHub and HUB_LOOK or Config.Worlds[id]
	applyAmbient(id)
	if clouds then
		local cover = ({ Hub = 0.25, Forest = 0.55, Volcano = 0.75, Frozen = 0.8, Crystal = 0.3, Candy = 0.6, Space = 0, Shadow = 0.7, Heaven = 0.9 })[id] or 0.5
		local ccol = ({ Volcano = Color3.fromRGB(90, 60, 60), Shadow = Color3.fromRGB(70, 40, 90), Candy = Color3.fromRGB(255, 210, 235) })[id] or Color3.new(1, 1, 1)
		tween(clouds, 2, { Cover = cover, Color = ccol })
	end
	-- per-zone grade (brother's LOOK) on the map-tuned sun/fog from Config; the hub keeps SanctuaryLook
	local look = (not inHub) and (LOOK[id] or LOOK.Forest) or nil
	-- shade fill: each zone keeps a hint of its own colour, but pulled toward a cool neutral so shadows stay
	-- readable and nothing turns purple; occluded areas get a darker version of it
	local NEUTRAL = Color3.fromRGB(118, 124, 138)
	local outdoor = inHub and HUB_LOOK.ambient or W.ambient:Lerp(NEUTRAL, 0.55)
	local indoor = inHub and HUB_LOOK.indoor or outdoor:Lerp(Color3.fromRGB(40, 42, 48), 0.45)
	tween(Lighting, 1.5, { Ambient = indoor, OutdoorAmbient = outdoor, ClockTime = inHub and HUB_LOOK.clock or W.clock, FogColor = W.fog, Brightness = 3, ExposureCompensation = inHub and -0.15 or look.exposure })
	if cc then tween(cc, 1.5, { TintColor = W.tint, Saturation = inHub and 0.06 or look.sat, Contrast = inHub and 0.1 or look.contrast }) end
	if atmo then tween(atmo, 1.5, { Color = W.atmo, Decay = W.fog, Haze = inHub and HUB_LOOK.haze or look.haze, Glare = inHub and HUB_LOOK.glare or look.glare, Offset = inHub and HUB_LOOK.offset or look.offset, Density = inHub and HUB_LOOK.density or look.density }) end
	if bloom then tween(bloom, 1.0, { Intensity = inHub and HUB_LOOK.bloom or look.bloom }) end
	if rays then tween(rays, 1.5, { Intensity = inHub and 0.05 or look.rays }) end
	return id
end

return Effects
