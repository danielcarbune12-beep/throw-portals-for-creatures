-- Deliberate close-up detail for the lobby. Decorative only; all gameplay paths stay clear.
local P = require(script.Parent.SanctuaryArchitecture).Palette
local Details = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
function Details.Build(start)
	local old = start:FindFirstChild("SanctuaryDetails")
	if old then
		old:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "SanctuaryDetails"
	root.Parent = start
	local count = 0
	local function part(name, size, cf, color, material, transparency)
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.SmoothPlastic
		p.Transparency = transparency or 0
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = root
		count += 1
		return p
	end
	local function segment(name, a, b, width, height, color, material)
		local mid = (a + b) / 2
		local delta = b - a
		return part(name, V(width, height, delta.Magnitude), CFrame.lookAt(mid, b), color, material)
	end
	local function ring(name, x, z, r, y, segments, width, color)
		for i = 0, segments - 1 do
			local a = i * math.pi * 2 / segments
			local b = (i + 1) * math.pi * 2 / segments
			segment(
				name,
				V(x + math.cos(a) * r, y, z + math.sin(a) * r),
				V(x + math.cos(b) * r, y, z + math.sin(b) * r),
				width,
				0.035,
				color
			)
		end
	end
	local function flower(x, y, z, tone)
		part("Stem", V(0.12, 0.7, 0.12), CF(x, y + 0.35, z), P.leaf)
		for i = 0, 3 do
			local a = i * math.pi / 2
			part(
				"Petal",
				V(0.48, 0.16, 0.35),
				CF(x + math.cos(a) * 0.27, y + 0.78, z + math.sin(a) * 0.27) * A(0, a, 0),
				tone
			)
		end
		part("FlowerHeart", V(0.2, 0.2, 0.2), CF(x, y + 0.88, z), P.goldLight)
	end
	-- Restrained stone cutting and brass inlay: large shapes remain readable at distance.
	for i, z in ipairs({ -53, -101, -145, -189, -229, -273, -313, -357, -405 }) do
		for _, side in { -1, 1 } do
			for j = 0, 2 do
				part("CutStoneJoint", V(4.1, 0.025, 0.10), CF(side * (10 + j * 4.2), 0.232, z), P.stone)
			end
			part(
				"BrassPathStud",
				V(0.44, 0.035, 0.44),
				CF(side * 19.6, 0.26, z) * A(0, math.pi / 4, 0),
				P.gold,
				M.Metal
			)
		end
		if i % 3 == 0 then
			task.wait()
		end
	end
	for _, z in { -84, -160, -236, -312 } do
		for _, side in { -1, 1 } do
			-- Narrow drains beside the kerb, never across garden approaches.
			part("DrainBed", V(0.62, 0.03, 6), CF(side * 21.5, 0.255, z + 17), P.roof, M.Metal)
			for n = 0, 7 do
				part("DrainGrate", V(0.7, 0.04, 0.11), CF(side * 21.5, 0.28, z + 14.3 + n * 0.73), P.stone, M.Metal)
			end
			-- Small planting beds at avenue corners, outside the clear walking corridor.
			local bx, bz = side * 28.2, z - 19
			part("FlowerBedBase", V(4.4, 0.45, 6.8), CF(bx, 0.35, bz), P.stone, M.Limestone)
			part("FlowerBedSoil", V(3.7, 0.18, 6.1), CF(bx, 0.64, bz), Color3.fromRGB(76, 58, 65), M.Ground)
			for n = 0, 3 do
				flower(bx + ((n % 2) - 0.5) * 1.35, 0.75, bz - 2 + n * 1.3, n % 2 == 0 and P.pink or P.lilac)
			end
		end
		task.wait()
	end
	-- A compass mosaic at the entrance uses thin, flush geometry rather than another sign.
	ring("CompassOuter", 0, -54, 8, 0.27, 16, 0.13, P.gold)
	ring("CompassInner", 0, -54, 6.8, 0.273, 16, 0.09, P.stone)
	for i = 0, 7 do
		local a = i * math.pi / 4
		part(
			"CompassPoint",
			V(0.75, 0.05, i % 2 == 0 and 4.2 or 2.8),
			CF(math.sin(a) * 3.6, 0.30, -54 + math.cos(a) * 3.6) * A(0, a, 0),
			i % 2 == 0 and P.roof or P.gold
		)
	end
	-- Hall masonry: sill steps, foundation courses, panel joints and roof corbels.
	for _, side in { -1, 1 } do
		local x = side * 38
		for _, y in { 3.2, 6.7, 22.7 } do
			part("FacadeStoneCourse", V(19.6, 0.25, 0.24), CF(x, y, -36.78), P.stone, M.Limestone)
		end
		for i = 0, 4 do
			part("FoundationJoint", V(0.08, 2.7, 0.26), CF(x - 8 + i * 4, 4.8, -36.82), P.ivory, M.Limestone)
		end
		for _, wx in { x - 3.4, x + 3.4 } do
			part("WindowSill", V(5.9, 0.42, 1.2), CF(wx, 9.1, -37.0), P.light, M.Limestone)
			part("WindowSillGold", V(5.5, 0.10, 1.24), CF(wx, 9.37, -37.02), P.gold, M.Metal)
		end
		for i = 0, 5 do
			part("EaveCorbel", V(0.68, 1.3, 0.84), CF(x - 8.5 + i * 3.4, 23.8, -37), P.light, M.Limestone)
		end
		for _, z in { -33, -26, -19, -12, -5 } do
			part("OuterWallCourse", V(0.26, 0.24, 6.8), CF(side * 48.1, 6.7, z), P.stone, M.Limestone)
			part("RoofTileSeam", V(22.3, 0.04, 0.13), CF(x, 25.73, z), P.gold, M.Metal)
		end
		task.wait()
	end
	-- Public fountain plaza: cut paving, seating and flower borders form one composed destination.
	for _, side in { -1, 1 } do
		for i = 0, 4 do
			part("PlazaJoint", V(0.07, 0.035, 34), CF(78 - 15 + i * 7.5, 0.275, -22), P.stone)
		end
		local bx = 78 + side * 14
		part("BenchSeat", V(2.4, 0.5, 9), CF(bx, 2, -22), P.ivory, M.Limestone)
		for _, z in { -25, -19 } do
			part("BenchFoot", V(1.7, 1.5, 0.75), CF(bx, 1, z), P.stone, M.Limestone)
		end
		part("BenchTrim", V(2.5, 0.12, 9.1), CF(bx, 2.30, -22), P.gold, M.Metal)
		for n = 0, 3 do
			flower(78 + side * 11, 0.3, -35 + n * 1.7, n % 2 == 0 and P.pink or P.light)
		end
	end
	ring("FountainBrassRing", 78, -22, 12, 0.31, 24, 0.16, P.gold)
	ring("FountainOuterStone", 78, -22, 14, 0.30, 24, 0.12, P.stone)
	-- Faceted light-catching water strips on the side cascades, with stone catch-basin rims.
	for _, side in { -1, 1 } do
		for _, z in { -124, -278 } do
			for i = 0, 3 do
				part(
					"WaterRibbon",
					V(0.035, 19 - i * 0.8, 0.16),
					CF(side * 101.65, 12, z - 2.5 + i * 1.6),
					P.light,
					M.Glass,
					0.68
				)
			end
			for i = 0, 5 do
				local a = i * math.pi / 3
				part(
					"CascadeBasinRim",
					V(4, 0.24, 0.45),
					CF(side * 100 + math.sin(a) * 5.7, 0.45, z + math.cos(a) * 5.7) * A(0, a, 0),
					P.light,
					M.Limestone
				)
			end
		end
	end
	-- Localized water mist and portal glimmers, not a particle field following the camera.
	local tags = game:GetService("CollectionService")
	local function emitter(name, pos, rate, magic)
		local anchor = part(name, V(1, 1, 1), CF(pos), P.water, M.SmoothPlastic, 1)
		local pe = Instance.new("ParticleEmitter")
		pe.Name = name .. "Emitter"
		pe.Texture = magic and "rbxasset://textures/particles/sparkles_main.dds"
			or "rbxasset://textures/particles/smoke_main.dds"
		pe.Rate = rate
		pe.Lifetime = NumberRange.new(magic and 2 or 2.5, magic and 3 or 4)
		pe.Speed = NumberRange.new(0.35, magic and 1.1 or 0.8)
		pe.SpreadAngle = Vector2.new(90, 90)
		pe.Acceleration = V(magic and 0 or 0.1, magic and 0.15 or 0.04, 0)
		pe.Drag = 0.7
		pe.Color = ColorSequence.new(magic and P.goldLight or Color3.fromRGB(217, 233, 241))
		pe.LightEmission = magic and 0.6 or 0.12
		pe.LightInfluence = magic and 0.2 or 0.7
		pe.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, magic and 0.08 or 1.4),
			NumberSequenceKeypoint.new(0.55, magic and 0.18 or 3.8),
			NumberSequenceKeypoint.new(1, magic and 0.05 or 5.2),
		})
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.25, magic and 0.45 or 0.9),
			NumberSequenceKeypoint.new(0.75, magic and 0.65 or 0.94),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-8, 8)
		pe.Parent = anchor
		pe:SetAttribute("BaseRate", rate)
		tags:AddTag(pe, "TPFC_EnvironmentEmitter")
	end
	for _, side in { -1, 1 } do
		for _, z in { -124, -278 } do
			emitter("CascadeMist", V(side * 100, 1.3, z), 4, false)
		end
		emitter("FountainMist", V(78 + side * 4, 1.6, -22), 2, false)
		emitter("ArchGlimmer", V(side * 23, 10, -34), 1.5, true)
	end

	root:SetAttribute("Parts", count)
	root:SetAttribute("Version", 1)
	return root
end
return Details
