-- PortalBuilder: builds the throwable portal orb and the opened portal gate.
-- Location: ReplicatedStorage > Shared > PortalBuilder (ModuleScript)

local Config = require(script.Parent.Config)

local PortalBuilder = {}
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 170, 40)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 240, 70)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 230, 110)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(70, 150, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)) })

local function part(model, name, size, color, mat, meshType, transp)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.Neon
	p.Transparency = transp or 0
	p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
	p.CastShadow = false
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType or Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = model
	return p, m
end

local function weld(a, b, c0)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = a, b, c0
	w.Parent = b
	return w
end

function PortalBuilder.ColorSeq(portalId)
	local P = Config.Portals[portalId]
	if P.fx == "Rainbow" then return RAINBOW end
	return ColorSequence.new(P.color, P.color2)
end

function PortalBuilder.Emitter(parent, portalId, rate, size, speed)
	local P = Config.Portals[portalId]
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = (P.fx == "Smoke" or P.fx == "Glitch") and SMOKE or (P.fx == "Fire" and FIRE or SPARKLE)
	pe.Color = PortalBuilder.ColorSeq(portalId)
	pe.LightEmission = (P.fx == "Smoke") and 0.3 or 1
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(0.5, 1.2)
	pe.Speed = NumberRange.new(speed * 0.5, speed)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new(0, 1)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-180, 180)
	pe.Parent = parent
	return pe
end

-- Small glowing orb that gets thrown. Returns model, refs.
function PortalBuilder.BuildOrb(portalId: string, scale: number?)
	local P = Config.Portals[portalId]
	local s = scale or 1
	local model = Instance.new("Model")
	model.Name = "PortalOrb"
	local core = part(model, "Core", Vector3.new(1.6, 1.6, 1.6) * s, P.color2, Enum.Material.Neon)
	core.Anchored = true
	model.PrimaryPart = core
	local shell = part(model, "Shell", Vector3.new(2.2, 2.2, 2.2) * s, P.color, Enum.Material.Glass, nil, 0.35)
	weld(core, shell, CFrame.identity)
	-- two orbiting rings of beads
	local rings = {}
	for r = 1, 2 do
		local hub = part(model, "RingHub", Vector3.new(0.1, 0.1, 0.1), P.color, Enum.Material.Neon, nil, 1)
		local w = weld(core, hub, CFrame.Angles(r == 1 and 0.5 or -0.9, 0, r == 1 and 0.3 or -0.4))
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2
			local b = part(model, "Bead", Vector3.new(0.28, 0.28, 0.28) * s, i % 2 == 0 and P.color or P.color2, Enum.Material.Neon)
			weld(hub, b, CFrame.new(math.cos(a) * 1.6 * s, 0, math.sin(a) * 1.6 * s))
		end
		table.insert(rings, { w = w, base = w.C0, dir = r == 1 and 1 or -1 })
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = P.color, 12, 2
	light.Parent = core
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, 0.7, 0) * s; a0.Parent = core
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -0.7, 0) * s; a1.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Color = PortalBuilder.ColorSeq(portalId)
	trail.LightEmission = 1
	trail.Lifetime = 0.45
	trail.Transparency = NumberSequence.new(0.1, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = core
	local pe = PortalBuilder.Emitter(core, portalId, 18, 0.6 * s, 2)
	return model, { core = core, rings = rings, trail = trail, emitter = pe, light = light }
end

-- Vertical portal gate (opens on landing; also used in shop previews). Faces -Z.
function PortalBuilder.BuildGate(portalId: string, radius: number?)
	local P = Config.Portals[portalId]
	local R = radius or 4
	local model = Instance.new("Model")
	model.Name = "PortalGate"
	local root = part(model, "Root", Vector3.new(0.2, 0.2, 0.2), P.color, Enum.Material.Neon, nil, 1)
	root.Anchored = true
	model.PrimaryPart = root
	local frameHub = part(model, "FrameHub", Vector3.new(0.1, 0.1, 0.1), P.color, Enum.Material.Neon, nil, 1)
	local frameW = weld(root, frameHub, CFrame.identity)
	local n = 28
	for i = 1, n do
		local a = i / n * math.pi * 2
		local col = P.fx == "Rainbow" and Color3.fromHSV(i / n, 0.75, 1) or (i % 2 == 0 and P.color or P.color:Lerp(P.color2, 0.4))
		local seg = part(model, "Frame", Vector3.new(R * 0.36, R * 0.36, R * 0.42), col, Enum.Material.Neon)
		weld(frameHub, seg, CFrame.new(math.cos(a) * R, math.sin(a) * R, 0) * CFrame.Angles(0, 0, a))
	end
	-- outer glass rim for depth
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local rim = part(model, "Rim", Vector3.new(R * 0.5, R * 0.5, R * 0.3), P.color2, Enum.Material.Glass, nil, 0.4)
		weld(frameHub, rim, CFrame.new(math.cos(a) * R * 1.12, math.sin(a) * R * 1.12, 0.1))
	end
	-- swirling inner discs
	local discs = {}
	for i = 1, 3 do
		local d = part(model, "Swirl", Vector3.new(R * 2 * (1 - i * 0.22), 0.1 + i * 0.02, R * 2 * (1 - i * 0.22)),
			i % 2 == 1 and P.color or P.color2, Enum.Material.Neon, Enum.MeshType.Cylinder, 0.15 + i * 0.12)
		local w = weld(root, d, CFrame.new(0, 0, -0.05 * i) * CFrame.Angles(math.pi / 2, 0, 0))
		table.insert(discs, { w = w, base = w.C0, dir = i % 2 == 1 and 1 or -1, speed = 1 + i * 0.7 })
		-- spiral arms on each disc
		for k = 1, 3 do
			local arm = part(model, "SwirlArm", Vector3.new(R * 0.9 * (1 - i * 0.2), 0.2, R * 0.18), P.color2:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Neon, nil, 0.3)
			weld(d, arm, CFrame.Angles(0, k / 3 * math.pi * 2, 0) * CFrame.new(R * 0.35 * (1 - i * 0.2), 0.12, 0) * CFrame.Angles(0, 0.6, 0))
		end
	end
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness = P.color, R * 5, 3
	light.Parent = root
	local pe = PortalBuilder.Emitter(root, portalId, 40, 0.9, 6)
	pe.Shape = Enum.ParticleEmitterShape.Disc
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	pe.EmissionDirection = Enum.NormalId.Front
	return model, { root = root, frame = { w = frameW, base = frameW.C0 }, discs = discs, emitter = pe, light = light, radius = R }
end

-- Rotates the gate's swirl each frame
function PortalBuilder.Spin(refs, t: number)
	if refs.discs then
		for _, d in ipairs(refs.discs) do
			d.w.C0 = d.base * CFrame.Angles(0, t * d.speed * d.dir * 2, 0)
		end
		refs.frame.w.C0 = refs.frame.base * CFrame.Angles(0, 0, t * 0.6)
	end
	if refs.rings then
		for _, r in ipairs(refs.rings) do
			r.w.C0 = r.base * CFrame.Angles(0, t * 4 * r.dir, 0)
		end
	end
end

return PortalBuilder
