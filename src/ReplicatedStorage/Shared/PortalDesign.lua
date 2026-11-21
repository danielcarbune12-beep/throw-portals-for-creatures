-- Architectural portals and faceted throw orbs. No uploaded meshes or textures required.
-- API refs deliberately match ThrowController/UIKit. Structural frames do not spin.
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local PI, M = math.pi, Enum.Material
local GOLD = Color3.fromRGB(218, 174, 85)
local IVORY = Color3.fromRGB(235, 228, 218)
local INK = Color3.fromRGB(31, 24, 48)
local function make(model, name, size, color, mat, transparency, class)
	local p = Instance.new(class or "Part")
	p.Name, p.Size, p.Color, p.Material = name, size, color, mat or M.SmoothPlastic
	p.Transparency = transparency or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, false, true
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = model
	return p
end
local function weld(parent, p, cf, name)
	local w = Instance.new("Weld")
	w.Name, w.Part0, w.Part1, w.C0 = name or "Bind", parent, p, cf
	w.Parent = p
	return w
end
local function block(model, hub, name, size, cf, color, mat, tr)
	local p = make(model, name, size, color, mat, tr)
	weld(hub, p, cf)
	return p
end
local function beam(model, hub, name, p0, p1, width, depth, color, mat)
	local d = p1 - p0
	return block(
		model,
		hub,
		name,
		V(width, d.Magnitude + width * 0.12, depth),
		CF((p0 + p1) / 2, p1) * A(PI / 2, 0, 0),
		color,
		mat
	)
end
local function triangle(model, hub, name, a, b, c, color, mat, thickness, transparency)
	-- Two native solid wedges fill a triangle. The longest edge is the base, ensuring
	-- the perpendicular projection stays within it, with no negative or sliver dimensions.
	local ab, ac, bc = (b - a).Magnitude, (c - a).Magnitude, (c - b).Magnitude
	if ac > ab and ac > bc then
		b, c = c, b
	elseif bc > ab then
		a, c = c, a
	end
	local z = (b - a).Unit
	local foot = a + z * (c - a):Dot(z)
	local y = (c - foot).Unit
	local h = (c - foot).Magnitude
	for _, point in ipairs({ a, b }) do
		local width = (foot - point).Magnitude
		if width > 0.0001 then
			local zz = (foot - point).Unit
			local x = y:Cross(zz)
			local cf = CFrame.fromMatrix((point + foot) / 2 + y * h / 2, x, y, zz)
			local p = make(model, name, V(thickness or 0.04, h, width), color, mat, transparency, "WedgePart")
			weld(hub, p, cf)
		end
	end
end
local function diamond(model, hub, name, cf, length, width, depth, color, mat)
	local top, bottom = cf * V(0, length / 2, 0), cf * V(0, -length / 2, 0)
	triangle(model, hub, name, cf * V(-width / 2, 0, 0), bottom, top, color, mat, depth)
	triangle(model, hub, name, cf * V(width / 2, 0, 0), top, bottom, color, mat, depth)
end
local function ring(model, hub, name, radius, radialWidth, depth, z, color, mat, n, tr)
	n = n or 24
	local length = 2 * radius * math.tan(PI / n) * 1.015
	for i = 0, n - 1 do
		local angle = (i + 0.5) / n * PI * 2
		local col = type(color) == "function" and color(i, n) or color
		block(
			model,
			hub,
			name,
			V(length, radialWidth, depth),
			CF(math.cos(angle) * radius, math.sin(angle) * radius, z) * A(0, 0, angle + PI / 2),
			col,
			mat,
			tr
		)
	end
end
local function disk(model, hub, name, radius, z, color, mat, tr)
	local p = make(model, name, V(0.055, radius * 2, radius * 2), color, mat, tr)
	p.Shape = Enum.PartType.Cylinder -- native cylinder axis X, rotated onto portal normal Z
	weld(hub, p, CF(0, 0, z) * A(0, PI / 2, 0))
	return p
end
local function rotor(model, root, name, base, speed, direction)
	local p = make(model, name, V(0.05, 0.05, 0.05), INK, M.SmoothPlastic, 1)
	local w = weld(root, p, base, "PortalRotor")
	w:SetAttribute("Rate", speed * direction)
	w:SetAttribute("Axis", "Z")
	return p, { w = w, base = base, speed = speed, dir = direction, axis = "Z" }
end

-- A regular icosahedron provides real planar orb faces, rather than a round glass ball.
local phi = (1 + math.sqrt(5)) / 2
local ico = {
	V(-1, phi, 0),
	V(1, phi, 0),
	V(-1, -phi, 0),
	V(1, -phi, 0),
	V(0, -1, phi),
	V(0, 1, phi),
	V(0, -1, -phi),
	V(0, 1, -phi),
	V(phi, 0, -1),
	V(phi, 0, 1),
	V(-phi, 0, -1),
	V(-phi, 0, 1),
}
for i, p in ipairs(ico) do
	ico[i] = p.Unit
end
local faces, edges = {}, {}
for a = 1, 10 do
	for b = a + 1, 11 do
		for c = b + 1, 12 do
			local normal = (ico[b] - ico[a]):Cross(ico[c] - ico[a])
			local positive, negative = false, false
			for j, p in ipairs(ico) do
				if j ~= a and j ~= b and j ~= c then
					local d = normal:Dot(p - ico[a])
					positive = positive or d > 0.0001
					negative = negative or d < -0.0001
				end
			end
			if not (positive and negative) then
				table.insert(faces, { a, b, c })
				for _, pair in ipairs({ { a, b }, { b, c }, { a, c } }) do
					local x, y = math.min(pair[1], pair[2]), math.max(pair[1], pair[2])
					edges[x .. ":" .. y] = { x, y }
				end
			end
		end
	end
end

return function(API, Config)
	local function themeDetails(model, hub, id, r, p)
		if id == "Forest" then
			for side = -1, 1, 2 do
				for j = 0, 3 do
					local angle = side * (0.5 + j * 0.48)
					diamond(
						model,
						hub,
						"CarvedLeaf",
						CF(math.sin(angle) * r * 1.12, math.cos(angle) * r * 1.1, -r * 0.09) * A(0.22, 0, -angle),
						r * 0.62,
						r * 0.24,
						r * 0.07,
						j % 2 == 0 and p.color or p.color2,
						M.SmoothPlastic
					)
				end
				beam(
					model,
					hub,
					"BranchRoot",
					V(side * r * 0.55, -r * 0.95, 0),
					V(side * r * 1.35, -r * 1.17, -0.15),
					r * 0.18,
					r * 0.18,
					Color3.fromRGB(101, 70, 43),
					M.Wood
				)
			end
		elseif id == "Lava" or id == "Dark" or id == "Ice" then
			for i = 0, 7 do
				local a = i / 8 * PI * 2
				local ice = id == "Ice"
				local col = ice and Color3.fromRGB(190, 230, 245)
					or (id == "Lava" and Color3.fromRGB(46, 37, 42) or INK)
				diamond(
					model,
					hub,
					ice and "FrostCrystal" or "ArmoredSpine",
					CF(math.sin(a) * r * 1.14, math.cos(a) * r * 1.14, 0) * A(0, 0, -a),
					r * (ice and 0.70 or (id == "Dark" and (i % 2 == 0 and 0.95 or 0.35) or 0.54)),
					r * 0.26,
					r * 0.19,
					col,
					ice and M.Ice or API.Theme[id].frameMat
				)
				block(
					model,
					hub,
					"InsetEnergySeam",
					V(r * 0.055, r * 0.22, r * 0.035),
					CF(math.sin(a) * r, math.cos(a) * r, -r * 0.20) * A(0, 0, -a),
					p.color2,
					M.Neon
				)
			end
		elseif id == "Galaxy" then
			ring(model, hub, "Astrolabe", r * 1.32, r * 0.035, r * 0.035, 0.16, GOLD, M.Metal, 32)
			for i = 0, 5 do
				local a = i / 6 * PI * 2
				diamond(
					model,
					hub,
					"StarMarker",
					CF(math.sin(a) * r * 1.32, math.cos(a) * r * 1.32, -0.06) * A(0, 0, -a),
					r * 0.24,
					r * 0.12,
					0.04,
					p.color2,
					M.Neon
				)
			end
		elseif id == "Divine" then
			for side = -1, 1, 2 do
				for j = 0, 3 do
					local bladeCF = CF(side * r * (1.08 + j * 0.13), r * (0.10 + j * 0.23), 0.02)
						* A(0, 0, -side * (0.8 - j * 0.12))
					diamond(
						model,
						hub,
						"ArchitecturalWingBlade",
						bladeCF,
						r * (0.9 - j * 0.10),
						r * 0.21,
						r * 0.07,
						j == 0 and GOLD or IVORY,
						M.SmoothPlastic
					)
					beam(
						model,
						hub,
						"FeatherGoldVein",
						bladeCF * V(0, -r * (0.40 - j * 0.04), -r * 0.05),
						bladeCF * V(0, r * (0.40 - j * 0.04), -r * 0.05),
						r * 0.027,
						r * 0.027,
						GOLD,
						M.Metal
					)
				end
			end
			local halo = block(model, hub, "HaloMount", V(0.05, 0.05, 0.05), CF(0, r * 1.48, 0), GOLD, M.Metal, 1)
			ring(model, halo, "DivineHalo", r * 0.30, r * 0.035, r * 0.055, 0, GOLD, M.Metal, 16)
		elseif id == "Secret" then
			for i = 0, 11 do
				local a = i / 12 * PI * 2
				block(
					model,
					hub,
					"BrokenCircuitPlate",
					V(r * 0.33, r * 0.15, r * 0.22),
					CF(math.sin(a) * r * 1.18, math.cos(a) * r * 1.18, i % 2 == 0 and 0.15 or -0.10) * A(0, 0, -a),
					INK,
					M.Metal
				)
				block(
					model,
					hub,
					"CircuitInset",
					V(r * 0.23, r * 0.025, 0.025),
					CF(math.sin(a) * r * 1.18, math.cos(a) * r * 1.18, -r * 0.14) * A(0, 0, -a),
					i % 2 == 0 and p.color or p.color2,
					M.Neon
				)
			end
		end
	end
	function API.BuildOrb(id: string, scale: number?)
		local p = assert(Config.Portals[id], "Unknown portal " .. tostring(id))
		local s = scale or 1
		local model = Instance.new("Model")
		model.Name = "PortalOrb"
		local root = make(model, "Core", V(0.12, 0.12, 0.12), p.color, M.SmoothPlastic, 1)
		root.Anchored = true
		model.PrimaryPart = root
		for i, face in ipairs(faces) do
			local col = p.fx == "Rainbow" and Color3.fromHSV(i / #faces, 0.55, 0.85)
				or p.color:Lerp(p.color2, (i % 4) * 0.12)
			triangle(
				model,
				root,
				"CrystalFacet",
				ico[face[1]] * s,
				ico[face[2]] * s,
				ico[face[3]] * s,
				col,
				M.SmoothPlastic,
				0.035 * s
			)
		end
		local trim = (id == "Lava" or id == "Dark" or id == "Secret") and p.color2 or GOLD
		for _, edge in pairs(edges) do
			beam(
				model,
				root,
				"InlaidCage",
				ico[edge[1]] * s * 1.025,
				ico[edge[2]] * s * 1.025,
				0.065 * s,
				0.065 * s,
				trim,
				M.Metal
			)
		end
		local hub, ringRef = rotor(model, root, "OrbitRuneAssembly", CF(), 0.7, 1)
		for j = 0, 2 do
			local a = j / 3 * PI * 2
			diamond(
				model,
				hub,
				"OrbitRune",
				CF(math.cos(a) * 1.26 * s, math.sin(a) * 1.26 * s, 0) * A(0, 0, a),
				0.30 * s,
				0.13 * s,
				0.04 * s,
				p.color2,
				M.Neon
			)
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = p.color, 9 * s, 0.7
		light.Parent = root
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Position, a1.Position, a0.Parent, a1.Parent = V(0, 0.5, 0) * s, V(0, -0.5, 0) * s, root, root
		local trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1, trail.Color = a0, a1, API.ColorSeq(id)
		trail.Lifetime, trail.LightEmission, trail.FaceCamera, trail.Enabled = 0.28, 0.8, true, false
		trail.Transparency, trail.WidthScale = NumberSequence.new(0.3, 1), NumberSequence.new(0.65, 0)
		trail.Parent = root
		local pe = API.Emitter(root, id, 4, 0.15 * s, 0.8)
		model:SetAttribute("PortalId", id)
		model:SetAttribute("DesignVersion", 2)
		return model, { core = root, rings = { ringRef }, trail = trail, emitter = pe, light = light }
	end
	function API.BuildGate(id: string, radius: number?, options)
		local p = assert(Config.Portals[id], "Unknown portal " .. tostring(id))
		local r = radius or 4
		assert(r > 0 and r < 100, "Portal radius out of bounds")
		local sanctuary = options and options.sanctuary
		if sanctuary then
			p = { color = Color3.fromRGB(143, 84, 217), color2 = Color3.fromRGB(214, 177, 255), fx = "Stars" }
		end
		local th = API.Theme[id]
		local model = Instance.new("Model")
		model.Name = sanctuary and "SanctuaryPortal" or "PortalGate"
		local root = make(model, "Root", V(0.05, 0.05, 0.05), INK, M.SmoothPlastic, 1)
		root.Anchored = true
		model.PrimaryPart = root
		local frameHub = make(model, "FrameHub", V(0.05, 0.05, 0.05), INK, M.SmoothPlastic, 1)
		local fw = weld(root, frameHub, CF())
		local frameColor = sanctuary and Color3.fromRGB(83, 50, 129) or th.frameCol
		local function frameRing(modelArg, hub, name, rr, width, depth, z, color, mat, n, tr)
			if not sanctuary then
				ring(modelArg, hub, name, rr, width, depth, z, color, mat, n, tr)
				return
			end
			local pieces = 16
			for i = 0, pieces - 1 do
				local angle = (i + 0.5) / pieces * PI
				block(
					modelArg,
					hub,
					name,
					V(2 * rr * math.tan(PI / (pieces * 2)) * 1.015, width, depth),
					CF(math.cos(angle) * rr, math.sin(angle) * rr, z) * A(0, 0, angle + PI / 2),
					color,
					mat,
					tr
				)
			end
			for side = -1, 1, 2 do
				block(modelArg, hub, name, V(width, rr, depth), CF(side * rr, -rr / 2, z), color, mat, tr)
			end
		end
		local framePaint = id == "Rainbow" and function(i, n)
			return Color3.fromHSV(i / n, 0.45, 0.94)
		end or frameColor
		frameRing(
			model,
			frameHub,
			"Frame",
			r,
			r * 0.20,
			r * 0.23,
			0,
			framePaint,
			sanctuary and M.SmoothPlastic or th.frameMat,
			24
		)
		frameRing(model, frameHub, "OuterMolding", r * 1.105, r * 0.055, r * 0.29, 0, GOLD, M.Metal, 24)
		frameRing(model, frameHub, "InnerMolding", r * 0.89, r * 0.035, r * 0.12, -r * 0.15, GOLD, M.Metal, 24)
		frameRing(
			model,
			frameHub,
			"EnergyInlay",
			r * 0.855,
			r * 0.025,
			r * 0.035,
			-r * 0.17,
			id == "Rainbow" and function(i, n)
				return Color3.fromHSV(i / n, 0.6, 1)
			end or p.color,
			M.Neon,
			24,
			0.2
		)
		for i = 0, 7 do
			local a = sanctuary and (i / 7 - 0.5) * PI or i / 8 * PI * 2
			block(
				model,
				frameHub,
				"RadialClasp",
				V(r * 0.16, r * 0.29, r * 0.29),
				CF(math.sin(a) * r, math.cos(a) * r, -r * 0.02) * A(0, 0, -a),
				GOLD,
				M.Metal
			)
		end
		for side = -1, 1, 2 do
			block(
				model,
				frameHub,
				"Footing",
				V(r * 0.42, r * 0.30, r * 0.48),
				CF(side * r * (sanctuary and 1 or 0.78), -r * 0.94, 0),
				sanctuary and IVORY or frameColor,
				M.SmoothPlastic
			)
		end
		diamond(
			model,
			frameHub,
			"CrownSetting",
			CF(0, r * 1.16, -r * 0.12),
			r * 0.64,
			r * 0.36,
			r * 0.12,
			GOLD,
			M.Metal
		)
		diamond(
			model,
			frameHub,
			"CrownCrystal",
			CF(0, r * 1.16, -r * 0.20),
			r * 0.43,
			r * 0.21,
			r * 0.055,
			p.color,
			M.SmoothPlastic
		)
		if not sanctuary then
			themeDetails(model, frameHub, id, r, p)
		end
		disk(
			model,
			root,
			"ApertureDepth",
			r * 0.86,
			0.06,
			p.color:Lerp(INK, id == "Rainbow" and 0.93 or 0.80),
			M.SmoothPlastic,
			sanctuary and 1 or 0.08
		)
		disk(model, root, "EnergyVeil", r * 0.85, -r * 0.07, p.color, M.Neon, sanctuary and 1 or 0.93)
		local discs = {}
		for arm = 0, 3 do
			local hub, ref = rotor(model, root, "VortexArm" .. arm, CF(0, 0, -r * (0.09 + arm * 0.005)), 0.65, 1)
			table.insert(discs, ref)
			for j = 1, 9 do
				local t0, t1 = (j - 1) / 9, j / 9
				local function point(t)
					local a = arm / 4 * PI * 2 + t * 2.85
					local rr = r * (0.02 + t * 0.77)
					return V(math.cos(a) * rr, math.sin(a) * rr, 0)
				end
				local d = point(t1) - point(t0)
				block(
					model,
					hub,
					"VortexRibbon",
					V(d.Magnitude * 1.20, r * (0.06 + 0.14 * math.sin((t0 + t1) / 2 * PI)), r * 0.008),
					CF((point(t0) + point(t1)) / 2) * A(0, 0, math.atan2(d.Y, d.X)),
					id == "Rainbow" and Color3.fromHSV((arm / 4 + t0 * 0.30) % 1, 0.5, 1)
						or p.color2:Lerp(Color3.new(1, 1, 1), 0.55 - t0 * 0.30),
					M.Neon,
					sanctuary and 1 or 0.12 + j * 0.042
				)
			end
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = p.color, math.min(r * 3, 40), sanctuary and 0.5 or 1.1
		light.Parent = root
		local pe = API.Emitter(root, id, sanctuary and 0 or 8, 0.25, 1.5)
		pe.Shape, pe.ShapeStyle, pe.EmissionDirection =
			Enum.ParticleEmitterShape.Disc, Enum.ParticleEmitterShapeStyle.Surface, Enum.NormalId.Front
		model:SetAttribute("PortalId", id)
		model:SetAttribute("DesignVersion", 2)
		return model,
			{ root = root, frame = { w = fw, base = fw.C0 }, discs = discs, emitter = pe, light = light, radius = r }
	end
	function API.Spin(refs, t: number)
		-- Architecture stays planted. Only the aperture and small orbit runes move.
		local root = refs.root or refs.core
		local scale = 1
		if typeof(game) == "Instance" and root and root.Parent then
			scale = root.Parent:GetScale()
		end
		for _, d in ipairs(refs.discs or refs.rings or {}) do
			d.w.C0 = CF(d.base.Position * scale) * d.base.Rotation * A(0, 0, t * d.speed * d.dir)
		end
	end
	API.Geometry = { triangle = triangle, icoFaces = #faces, icoVertices = #ico }
	return API
end
