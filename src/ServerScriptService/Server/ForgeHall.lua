-- Fortified guild forge. World geometry only; the existing recipes and station anchors stay authoritative.
local RS = game:GetService("ReplicatedStorage")
local Collection = game:GetService("CollectionService")
local Knight = require(RS.Shared.GuideKnight)
local Lettering = require(script.Parent.HeraldicText)
local Hall = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local C, M, PI = Color3.fromRGB, Enum.Material, math.pi
local ORIGIN = CF(0, 0, -236)
local P = {
	stone = C(163, 163, 151),
	pale = C(205, 199, 180),
	shade = C(120, 124, 117),
	mortar = C(83, 88, 82),
	iron = C(50, 56, 56),
	steel = C(112, 122, 121),
	oak = C(87, 64, 43),
	wood = C(121, 91, 56),
	slate = C(51, 64, 71),
	brass = C(162, 126, 65),
	gold = C(225, 175, 68),
	jade = C(35, 81, 66),
	ruby = C(166, 32, 54),
	warm = C(255, 187, 103),
}
function Hall.Build(parent)
	-- Migrate the four old generated avenue pylons that obscure the guild facade.
	-- Flat legacy parts have no assembly, so scope this to their exact owned footprints.
	if parent.Name == "Start" and parent.Parent and parent.Parent.Name == "Map" then
		for _, child in parent:GetChildren() do
			local flat = child:IsA("BasePart") and (child.Name == "Part" or child.Name == "Wedge")
			local gemModel = child:IsA("Model") and child.Name == "Gem"
			local pos = flat and child.Position or (gemModel and child:GetPivot().Position)
			if
				pos
				and math.abs(math.abs(pos.X) - 24.2) < 2.5
				and (math.abs(pos.Z + 176) < 2.5 or math.abs(pos.Z + 252) < 2.5)
				and pos.Y >= 0
				and pos.Y < 25
			then
				if gemModel or (child.Size.X < 8 and child.Size.Z < 8) then
					child:Destroy()
				end
			end
		end
	end
	local old = parent:FindFirstChild("GreatForgeHall")
	if old then
		old:Destroy()
	end
	local hall = Instance.new("Model")
	hall.Name = "GreatForgeHall"
	hall:SetAttribute("TPFCGenerated", true)
	hall:SetAttribute("HallStyle", "MedievalForge")
	hall:SetAttribute("HallRevision", 2)
	hall.Parent = parent
	local rng = Random.new(46317)
	local batch, count, serial = Instance.new("Folder"), 0, 0
	local function flush()
		if count == 0 then
			return
		end
		serial += 1
		batch.Name = string.format("GuildCraft_%02d", serial)
		batch.Parent = hall
		task.wait()
		batch, count = Instance.new("Folder"), 0
	end
	local function part(name, size, cf, color, material, collide, shape)
		local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
		p.Name, p.Size, p.CFrame = name, size, ORIGIN * cf
		p.Color, p.Material = color, material or M.Limestone
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collide == true, false, collide == true
		p.CastShadow = math.max(size.X, size.Y, size.Z) > 0.65
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if typeof(shape) == "EnumItem" then
			p.Shape = shape
		end
		p.Parent = batch
		count += 1
		if count >= 96 then
			flush()
		end
		return p
	end
	local function beam(name, a, b, w, d, color, material)
		local delta = b - a
		return part(name, V(w, d, delta.Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
	end
	local function tube(name, cf, radius, height, color, material, collide)
		return part(
			name,
			V(height, radius * 2, radius * 2),
			cf * A(0, 0, PI / 2),
			color,
			material,
			collide,
			Enum.PartType.Cylinder
		)
	end
	local function triangle(name, a, b, c, depth, color, material)
		local ab, ac, bc = b - a, c - a, c - b
		if ab.Magnitude > ac.Magnitude and ab.Magnitude > bc.Magnitude then
			c, a = a, c
		elseif ac.Magnitude > bc.Magnitude then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local right = ac:Cross(ab).Unit
		local back = bc.Unit
		local up = bc:Cross(right).Unit
		local height = math.abs(ab:Dot(up))
		if height < 0.02 then
			return
		end
		part(
			name,
			V(depth, height, math.max(0.02, math.abs(ab:Dot(back)))),
			CFrame.fromMatrix((a + b) / 2, right, up, back),
			color,
			material,
			false,
			"wedge"
		)
		part(
			name,
			V(depth, height, math.max(0.02, math.abs(ac:Dot(back)))),
			CFrame.fromMatrix((a + c) / 2, -right, up, -back),
			color,
			material,
			false,
			"wedge"
		)
	end
	local function tint()
		return P.stone:Lerp(P.pale, rng:NextNumber(0, 0.24)):Lerp(P.shade, rng:NextNumber(0, 0.12))
	end
	local function masonry(cf, width, height, holes)
		local rowH = 1.3
		local rows = math.ceil(height / rowH)
		for row = 0, rows - 1 do
			local bottom, top = row * rowH, math.min(height, (row + 1) * rowH)
			local intervals = { { -width / 2, width / 2 } }
			for _, hole in holes or {} do
				if top > hole[3] and bottom < hole[4] then
					local nextIntervals = {}
					for _, interval in intervals do
						if hole[1] >= interval[2] or hole[2] <= interval[1] then
							table.insert(nextIntervals, interval)
						else
							if interval[1] < hole[1] then
								table.insert(nextIntervals, { interval[1], hole[1] })
							end
							if interval[2] > hole[2] then
								table.insert(nextIntervals, { hole[2], interval[2] })
							end
						end
					end
					intervals = nextIntervals
				end
			end
			for _, interval in intervals do
				local x = interval[1]
				local first = true
				while x < interval[2] - 0.1 do
					local w = math.min((first and row % 2 == 0) and 2.05 or 4.1, interval[2] - x)
					part(
						"DressedAshlar",
						V(math.max(0.06, w - 0.055), top - bottom - 0.055, 1.55),
						cf * CF(x + w / 2, (bottom + top) / 2, 0),
						tint(),
						M.Limestone
					)
					x += w
					first = false
				end
			end
		end
	end
	local function arch(cf, radius, spring, rise, thick, depth, segments, color, material)
		for i = 0, segments - 1 do
			local a, b = i / segments * PI, (i + 1) / segments * PI
			local p0 = V(math.cos(a) * radius, spring + math.sin(a) * rise, 0)
			local p1 = V(math.cos(b) * radius, spring + math.sin(b) * rise, 0)
			local mid, tangent = (p0 + p1) / 2, p1 - p0
			local angle = math.atan2(tangent.Y, tangent.X)
			part(
				i == math.floor(segments / 2) and "ArchKeystone" or "ArchVoussoir",
				V(tangent.Magnitude - 0.035, thick, depth),
				cf * CF(mid) * A(0, 0, angle),
				color or P.pale,
				material or M.Limestone
			)
		end
	end
	local function ring(name, cf, radius, thick, depth, color, material, segments)
		for i = 0, segments - 1 do
			local angle = i / segments * 2 * PI
			part(
				name,
				V(2 * PI * radius / segments * 1.04, thick, depth),
				cf * CF(math.sin(angle) * radius, math.cos(angle) * radius, 0) * A(0, 0, -angle),
				color,
				material
			)
		end
	end
	local function rivet(cf, size)
		part("ForgedRivet", V(size, size, size * 0.45), cf, P.brass, M.Metal, false, Enum.PartType.Ball)
	end
	local function lantern(cf)
		part("LanternWallPlate", V(0.45, 1.0, 0.15), cf * CF(0, 0.6, 0), P.iron, M.Metal)
		part("LanternArm", V(0.18, 0.18, 1.3), cf * CF(0, 0.9, -0.6), P.iron, M.Metal)
		local glass = part("WarmLanternGlass", V(0.58, 1.0, 0.58), cf * CF(0, 0, -1.1), C(244, 182, 100), M.Neon)
		for _, y in { -0.58, 0.58 } do
			part("LanternCap", V(0.85, 0.14, 0.85), cf * CF(0, y, -1.1), P.iron, M.Metal)
		end
		for _, x in { -0.34, 0.34 } do
			for _, z in { -1.44, -0.76 } do
				part("LanternCage", V(0.08, 1.2, 0.08), cf * CF(x, 0, z), P.iron, M.Metal)
			end
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = P.warm, 12, 0.75
		light.Parent = glass
	end
	local function banner(cf, width, length)
		part("BannerRail", V(width + 0.6, 0.22, 0.25), cf, P.brass, M.Metal)
		part("HeavyJadeBanner", V(width, length - 1, 0.11), cf * CF(0, -length / 2 + 0.5, 0), P.jade, M.Fabric)
		triangle(
			"BannerPoint",
			(cf * V(-width / 2, -length + 1, 0)),
			(cf * V(width / 2, -length + 1, 0)),
			(cf * V(0, -length, 0)),
			0.1,
			P.jade,
			M.Fabric
		)
		for _, x in { -width / 2 + 0.12, width / 2 - 0.12 } do
			part(
				"BannerStitchedEdge",
				V(0.08, length - 1, 0.13),
				cf * CF(x, -length / 2 + 0.5, -0.03),
				P.brass,
				M.Fabric
			)
		end
		part(
			"GuildHammerHandle",
			V(0.18, 1.8, 0.14),
			cf * CF(0, -length * 0.42, -0.14) * A(0, 0, -0.25),
			P.brass,
			M.Metal
		)
		part(
			"GuildHammerHead",
			V(1.25, 0.48, 0.17),
			cf * CF(0.18, -length * 0.42 + 0.65, -0.14) * A(0, 0, -0.25),
			P.pale,
			M.Metal
		)
	end
	local function emitter(parentPart, name, texture, color, rate, size, lifetime, speed)
		local e = Instance.new("ParticleEmitter")
		e.Name, e.Texture, e.Color = name, texture, ColorSequence.new(color)
		e.Rate, e.Lifetime, e.Speed =
			rate, NumberRange.new(lifetime * 0.7, lifetime), NumberRange.new(speed * 0.6, speed)
		e.Size, e.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.35), NumberSequenceKeypoint.new(1, size) }),
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.65), NumberSequenceKeypoint.new(1, 1) })
		e.SpreadAngle, e.LightInfluence = Vector2.new(10, 10), 0.75
		e:SetAttribute("BaseRate", rate)
		e.Parent = parentPart
		Collection:AddTag(e, "TPFC_EnvironmentEmitter")
		return e
	end
	local function ingot(cf, color)
		part("CastIngot", V(0.75, 0.34, 0.52), cf, color, M.Metal)
		part("IngotTop", V(0.61, 0.09, 0.42), cf * CF(0, 0.215, 0), color:Lerp(P.pale, 0.17), M.Metal)
	end
	local function gem(cf, color)
		local r, h = 0.42, 0.62
		for i = 0, 3 do
			local a, b = i / 4 * 2 * PI + PI / 4, (i + 1) / 4 * 2 * PI + PI / 4
			local p0, p1 = V(math.sin(a) * r, 0, math.cos(a) * r), V(math.sin(b) * r, 0, math.cos(b) * r)
			triangle(
				"RubyFacet",
				cf * p0,
				cf * p1,
				cf * V(0, h, 0),
				0.05,
				color:Lerp(P.pale, i % 2 == 0 and 0.13 or 0),
				M.Glass
			)
			triangle("RubyFacet", cf * p1, cf * p0, cf * V(0, -h * 0.5, 0), 0.05, color:Lerp(P.iron, 0.1), M.Glass)
		end
	end
	local function chest(cf)
		part("SupplyChest", V(3.2, 1.8, 2.1), cf * CF(0, 0.9, 0), P.oak, M.WoodPlanks, true)
		part("ChestLid", V(3.4, 0.24, 2.2), cf * CF(0, 1.92, 0), P.wood, M.WoodPlanks)
		for _, x in { -1.0, 1.0 } do
			part("ChestIronStrap", V(0.17, 2.0, 2.22), cf * CF(x, 1, 0), P.iron, M.Metal)
			rivet(cf * CF(x, 1.55, -1.14), 0.14)
			rivet(cf * CF(x, 0.45, -1.14), 0.14)
		end
		part("ChestLock", V(0.4, 0.55, 0.16), cf * CF(0, 1.35, -1.18), P.brass, M.Metal)
	end

	-- Worn flagstones and a clear 18-stud processional nave.
	part("HallFoundation", V(44, 0.4, 70), CF(0, 0.35, 0), P.mortar, M.Slate, true)
	for row = -5, 5 do
		for col = -3, 3 do
			local x = col * 6.15
			part("HandLaidFlagstone", V(6.08, 0.1, 6.1), CF(x, 0.6, row * 6.15), tint(), M.Limestone)
		end
	end
	for _, x in { -9, 9 } do
		part("NaveStoneBorder", V(0.7, 0.06, 68), CF(x, 0.68, 0), P.shade, M.Slate)
		part("NaveBrassInlay", V(0.1, 0.04, 68), CF(x, 0.72, 0), P.brass, M.Metal)
	end
	for _, z in { -5.6, 5.6 } do
		part("CrossingStoneBorder", V(43, 0.06, 0.6), CF(0, 0.68, z), P.shade, M.Slate)
	end
	ring("GuildFloorSeal", CF(0, 0.72, 0) * A(-PI / 2, 0, 0), 3.4, 0.12, 0.06, P.brass, M.Metal, 20)
	part("FloorHammerHandle", V(0.17, 0.06, 3.6), CF(0, 0.74, 0) * A(0, 0.3, 0), P.brass, M.Metal)
	part("FloorHammerHead", V(2.6, 0.06, 0.85), CF(0.42, 0.74, -1.2) * A(0, 0.3, 0), P.brass, M.Metal)

	-- Load-bearing walls, open cross doors, and inset glazed lancets.
	for _, side in { -1, 1 } do
		local wallCF = CF(side * 21, 0.66, 0) * A(0, -side * PI / 2, 0)
		local holes = { { -6, 6, 0, 14 } }
		for _, u in { -27, -15, 15, 27 } do
			table.insert(holes, { u - 2, u + 2, 8.4, 16.1 })
		end
		masonry(wallCF, 68, 21.4, holes)
		for _, z in { -20, 20 } do
			part("WallCollision", V(1.6, 8.1, 27), CF(side * 21, 4.65, z), P.mortar, M.Slate, true).Transparency = 1
			part("WallFooting", V(3.0, 0.7, 27), CF(side * 21, 1, z), P.shade, M.Slate)
			part("StoneStringCourse", V(2.1, 0.3, 27), CF(side * 21, 8.7, z), P.pale, M.Limestone)
		end
		for _, y in { 21.3, 22.0 } do
			part(
				"EaveStoneMoulding",
				V(2.3, 0.32, 69),
				CF(side * 21, y, 0),
				y > 21.5 and P.pale or P.shade,
				M.Limestone
			)
		end
		for _, u in { -27, -15, 15, 27 } do
			local windowCF = wallCF * CF(u, 0, 0)
			local glass =
				part("LeadlightGlass", V(3.9, 7.2, 0.12), windowCF * CF(0, 12.1, -0.1), C(128, 159, 144), M.Glass)
			glass.Transparency, glass.Reflectance = 0.4, 0.06
			for _, x in { -2.25, 2.25 } do
				part("WindowStoneJamb", V(0.5, 6.5, 2), windowCF * CF(x, 11.6, 0), P.pale, M.Limestone)
			end
			arch(windowCF, 2.22, 14.5, 1.85, 0.5, 2.1, 9, P.pale)
			part("WindowSill", V(5.2, 0.35, 2.3), windowCF * CF(0, 8.45, -0.12), P.pale, M.Limestone)
			part("LeadMullion", V(0.12, 7.2, 0.18), windowCF * CF(0, 12, -0.2), P.iron, M.Metal)
			for _, y in { 10.2, 13.3 } do
				part("LeadTransom", V(4.0, 0.12, 0.18), windowCF * CF(0, y, -0.2), P.iron, M.Metal)
			end
		end
		arch(wallCF, 6.4, 8.2, 5, 1.0, 2.6, 13, P.pale)
		-- Shallow, roofed cross porches give the courtyard entrances their own silhouette.
		for _, u in { -7.1, 7.1 } do
			part("PorchPier", V(1.1, 13.1, 1.4), wallCF * CF(u, 6.7, -3.3), P.stone, M.Limestone, true)
			for _, yy in { 0.8, 12.9 } do
				part("PorchPierCap", V(1.7, 0.35, 1.9), wallCF * CF(u, yy, -3.3), P.pale, M.Limestone)
			end
		end
		arch(wallCF * CF(0, 0, -3.4), 6.55, 8.2, 5.1, 0.75, 1.5, 13, P.pale)
		triangle(
			"PorchGable",
			wallCF * V(-7.6, 14.1, -4.0),
			wallCF * V(7.6, 14.1, -4.0),
			wallCF * V(0, 18.6, -4.0),
			0.55,
			P.stone,
			M.Limestone
		)
		for _, slope in { -1, 1 } do
			local roofCF = wallCF * CF(slope * 3.8, 16.35, -2.1) * A(0, 0, -slope * math.atan2(4.5, 7.6))
			part("PorchSlateRoof", V(9.1, 0.5, 7.0), roofCF, P.slate, M.Slate)
			beam(
				"PorchBargeboard",
				wallCF * V(slope * 8.0, 14.0, -5.7),
				wallCF * V(0, 18.8, -5.7),
				0.3,
				0.4,
				P.oak,
				M.Wood
			)
		end
		part("PorchRidge", V(0.35, 0.25, 7.2), wallCF * CF(0, 18.85, -2.1), P.iron, M.Metal)
		for _, u in { -6.5, 6.5 } do
			part("CrossDoorJamb", V(1.2, 8.2, 2.6), wallCF * CF(u, 4.76, 0), P.shade, M.Limestone, true)
			part("CrossDoorCapital", V(1.6, 0.45, 3), wallCF * CF(u, 8.8, 0), P.pale, M.Limestone)
		end
		for _, z in { -31, -21, -9, 9, 21, 31 } do
			part("ButtressBase", V(4, 1.1, 3.7), CF(side * 21.5, 1.1, z), P.shade, M.Slate)
			part("BatteredButtress", V(2.2, 11.5, 2.3), CF(side * 22.0, 6.9, z), tint(), M.Limestone)
			part(
				"ButtressWeatherCap",
				V(2.8, 0.45, 2.8),
				CF(side * 22.0, 12.8, z) * A(0, 0, -side * 0.12),
				P.pale,
				M.Limestone
			)
		end
		for _, z in { -28, -14, 14, 28 } do
			local x = side * 17
			part("PierSplayedFoot", V(3.2, 0.7, 3.5), CF(x, 1, z), P.shade, M.Slate)
			part("OctagonalPierShaft", V(1.45, 15, 1.6), CF(x, 8.7, z), P.stone, M.Limestone, true)
			part("PierChamfer", V(1.8, 15, 1.4), CF(x, 8.7, z), P.stone, M.Limestone)
			for _, y in { 1.6, 15.9, 16.6 } do
				part("PierMoulding", V(2.5, 0.35, 2.8), CF(x, y, z), P.pale, M.Limestone)
			end
			part("TimberCorbel", V(2.8, 1.1, 2.6), CF(x, 17.3, z), P.oak, M.Wood)
			beam("KneeBrace", V(x, 16.7, z), V(side * 11.8, 21.2, z), 0.8, 0.8, P.oak, M.Wood)
			for _, yy in { 17.3, 20.7 } do
				part(
					"RafterIronPlate",
					V(1.15, 0.7, 0.13),
					CF(yy > 20 and side * 12.2 or x, yy, z + 1.4),
					P.iron,
					M.Metal
				)
				rivet(CF(yy > 20 and side * 12.2 or x, yy, z + 1.5), 0.2)
			end
		end
	end

	-- Squared portal jambs, fitted voussoirs, closed gables, and a guild crest.
	for _, front in { -1, 1 } do
		local cf = CF(0, 0.66, front * 34) * A(0, front == 1 and PI or 0, 0)
		for _, side in { -1, 1 } do
			masonry(cf * CF(side * 15.5, 0, 0), 10, 21.4, {})
			part("FacadeCollision", V(10, 21.4, 1.5), cf * CF(side * 15.5, 10.7, 0), P.stone, M.Limestone, true).Transparency =
				1
			part("GatePierCollision", V(4.2, 17, 5), cf * CF(side * 10.5, 8.5, 0), P.stone, M.Limestone, true).Transparency =
				1
			for row = 0, 11 do
				part(
					"PortalQuoin",
					V(3.8, 17 / 12 - 0.055, 3.9),
					cf * CF(side * 10.4, 0.6 + (row + 0.5) * 17 / 12, 0),
					tint(),
					M.Limestone
				)
			end
			for _, y in { 0.6, 1.3, 8.8, 18.4, 21.2 } do
				part("GatePierMoulding", V(4.5, 0.38, 5.2), cf * CF(side * 10.4, y, 0), P.pale, M.Limestone)
			end
			for _, dx in { -1.1, 1.1 } do
				part("GateJambRebate", V(0.25, 17, 0.3), cf * CF(side * 10.4 + dx, 9, -2.3), P.shade, M.Limestone)
			end
			banner(cf * CF(side * 15.4, 17, -1.1), 2.6, 6.3)
			lantern(cf * CF(side * 10.4, 6.2, -2.4))
		end
		arch(cf * CF(0, 0, -0.8), 8.75, 11.0, 7.25, 1.55, 4.2, 15, P.pale)
		arch(cf * CF(0, 0, -2.1), 9.7, 11.0, 7.9, 0.4, 0.5, 17, P.shade)
		for i = 0, 14 do
			local a, b = i / 15 * PI, (i + 1) / 15 * PI
			local p0 = V(math.cos(a) * 9.7, 11 + math.sin(a) * 7.9, 0)
			local p1 = V(math.cos(b) * 9.7, 11 + math.sin(b) * 7.9, 0)
			local t0, t1 = V(p0.X, 19.3, 0), V(p1.X, 19.3, 0)
			triangle("PortalSpandrel", cf * p0, cf * p1, cf * t1, 1.2, P.stone, M.Limestone)
			triangle("PortalSpandrel", cf * p0, cf * t1, cf * t0, 1.2, P.stone, M.Limestone)
		end
		part("PortalLintel", V(20.6, 2.0, 3.8), cf * CF(0, 20.3, 0), P.stone, M.Limestone)
		part("FrontCornice", V(44.6, 0.7, 3.3), cf * CF(0, 22, 0), P.pale, M.Limestone)
		local ga, gb, gc = cf * V(-22, 22.3, 0), cf * V(22, 22.3, 0), cf * V(0, 32, 0)
		triangle("GableStoneInfill", ga, gb, gc, 1.1, P.stone, M.Limestone)
		beam("GableBargeboard", cf * V(-23, 22.8, -0.9), cf * V(0, 33.0, -0.9), 0.65, 0.65, P.oak, M.Wood)
		beam("GableBargeboard", cf * V(0, 33.0, -0.9), cf * V(23, 22.8, -0.9), 0.65, 0.65, P.oak, M.Wood)
		for _, x in { -12, -6, 6, 12 } do
			local h = 9.5 * (1 - math.abs(x) / 22)
			part("GableStud", V(0.28, h, 0.22), cf * CF(x, 22.4 + h / 2, -0.65), P.oak, M.Wood)
		end
		for _, side in { -1, 1 } do
			beam(
				"GableDiagonalBrace",
				cf * V(side * 14, 22.4, -0.7),
				cf * V(side * 5, 28.1, -0.7),
				0.35,
				0.4,
				P.oak,
				M.Wood
			)
		end
		local crestCF = cf * CF(0, 26.8, -1.0)
		local plate = part(
			"GuildSealBack",
			V(0.4, 5.7, 5.7),
			crestCF * A(0, PI / 2, 0),
			P.jade,
			M.Metal,
			false,
			Enum.PartType.Cylinder
		)
		plate.Reflectance = 0.03
		ring("GuildSealRim", crestCF, 2.95, 0.22, 0.25, P.brass, M.Metal, 20)
		part("CrestAnvilTop", V(3, 0.5, 0.28), crestCF * CF(0, 0.6, -0.32), P.pale, M.Metal)
		part("CrestAnvilWaist", V(1.2, 1.15, 0.28), crestCF * CF(-0.1, -0.1, -0.32), P.brass, M.Metal)
		part("CrestAnvilFoot", V(2.5, 0.35, 0.28), crestCF * CF(0, -0.8, -0.32), P.pale, M.Metal)
		part("CrestHammer", V(0.2, 2.2, 0.26), crestCF * CF(0.3, 0.9, -0.39) * A(0, 0, -0.7), P.brass, M.Metal)
		part("CrestHammerHead", V(1.2, 0.5, 0.3), crestCF * CF(0.95, 1.5, -0.4) * A(0, 0, -0.7), P.pale, M.Metal)
		local sign = part("GreatHallSign", V(18.3, 2.35, 0.55), cf * CF(0, 20.0, -2.7), P.oak, M.WoodPlanks)
		for _, dy in { -1.15, 1.15 } do
			part("SignForgedFrame", V(18.6, 0.12, 0.2), cf * CF(0, 20 + dy, -3.0), P.brass, M.Metal)
		end
		for _, x in { -8.5, 8.5 } do
			part("SignIronStrap", V(0.38, 2.7, 0.15), cf * CF(x, 20, -3.0), P.iron, M.Metal)
			rivet(cf * CF(x, 20.75, -3.12), 0.18)
			rivet(cf * CF(x, 19.25, -3.12), 0.18)
		end
		Lettering.Build(sign, "GREAT FORGE", 1.5)
	end

	-- Layered slate courses sit on a complete roof, supported by hammerbeam trusses.
	local roofAngle = math.atan2(10.2, 23.3)
	local slopeLength = math.sqrt(23.3 ^ 2 + 10.2 ^ 2)
	for _, side in { -1, 1 } do
		local roofCF = CF(side * 11.65, 27.6, 0) * A(0, 0, -side * roofAngle)
		part("RoofUnderboarding", V(slopeLength + 1, 0.65, 76), roofCF, P.oak, M.WoodPlanks)
		for course = 0, 7 do
			local x = -slopeLength / 2 + (course + 0.5) * slopeLength / 8
			for col = -5, 5 do
				local z = col * 6.9
				part(
					"OverlappingSlate",
					V(slopeLength / 8 + 0.35, 0.19, 6.81),
					roofCF * CF(x, 0.46 + course * 0.012, z),
					P.slate:Lerp(P.shade, rng:NextNumber(0, 0.32)),
					M.Slate
				)
			end
			part(
				"SlateCourseLip",
				V(0.09, 0.09, 76),
				roofCF * CF(x - slopeLength / 16, 0.6, 0),
				P.slate:Lerp(P.shade, 0.3),
				M.Slate
			)
		end
		part("CarvedEaveFascia", V(0.75, 1.1, 77), CF(side * 23.6, 22.4, 0), P.oak, M.Wood)
		part("IronGutter", V(0.3, 0.35, 77), CF(side * 23.95, 22.9, 0), P.iron, M.Metal)
		for _, z in { -32, -24, -16, -8, 0, 8, 16, 24, 32 } do
			part("EaveCorbel", V(1.8, 0.8, 0.7), CF(side * 22.2, 21.65, z), P.shade, M.Limestone)
		end
		for _, z in { -28, -14, 14, 28 } do
			beam("RoofPrincipalRafter", V(0, 32.1, z), V(side * 23, 22.1, z), 0.65, 0.85, P.oak, M.Wood)
			beam("Hammerbeam", V(side * 17, 20.8, z), V(side * 10.5, 20.8, z), 0.7, 0.9, P.oak, M.Wood)
			beam("TrussBrace", V(side * 16.5, 17.8, z), V(side * 9.4, 24.8, z), 0.6, 0.6, P.oak, M.Wood)
		end
		for _, z in { -16, 16 } do
			local ventCF = CF(side * 13.3, 26.6, z) * A(0, -side * PI / 2, 0)
			part("DormerTimberBody", V(5.4, 2.6, 3.5), ventCF * CF(0, 1.3, 0.2), P.oak, M.WoodPlanks)
			part("DormerVentRecess", V(4.0, 1.9, 0.15), ventCF * CF(0, 1.35, -1.6), P.iron, M.Metal)
			for j = 0, 4 do
				part(
					"DormerVentLouver",
					V(4.1, 0.16, 0.28),
					ventCF * CF(0, 0.65 + j * 0.34, -1.78) * A(0.2, 0, 0),
					P.wood,
					M.Wood
				)
			end
			triangle(
				"DormerGable",
				ventCF * V(-3, 2.6, -1.6),
				ventCF * V(3, 2.6, -1.6),
				ventCF * V(0, 4.5, -1.6),
				0.3,
				P.wood,
				M.Wood
			)
			for _, slope in { -1, 1 } do
				part(
					"DormerSlateCap",
					V(3.9, 0.3, 5.0),
					ventCF * CF(slope * 1.5, 3.55, 0) * A(0, 0, -slope * math.atan2(1.9, 3)),
					P.slate,
					M.Slate
				)
				beam(
					"DormerBargeboard",
					ventCF * V(slope * 3.3, 2.5, -2.6),
					ventCF * V(0, 4.65, -2.6),
					0.2,
					0.25,
					P.brass,
					M.Metal
				)
			end
		end
	end
	for z = -36, 36, 3 do
		part("LeadRidgeCap", V(1.0, 0.35, 3.12), CF(0, 32.95, z) * A(0, 0, PI / 4), P.iron, M.Metal)
	end
	for _, z in { -28, -14, 14, 28 } do
		arch(CF(0, 0, z), 16.7, 17.3, 10.7, 0.75, 0.75, 17, P.oak, M.Wood)
		beam("TrussCollarTie", V(-8.0, 27.0, z), V(8.0, 27.0, z), 0.6, 0.7, P.oak, M.Wood)
	end
	for _, z in { -18, 18 } do
		local center = V(0, 14.4, z)
		for i = 0, 5 do
			local angle = i / 6 * PI * 2
			local p0 = center + V(math.sin(angle) * 2.8, 0, math.cos(angle) * 2.8)
			local p1 = center + V(math.sin(angle + PI / 3) * 2.8, 0, math.cos(angle + PI / 3) * 2.8)
			beam("WroughtChandelier", p0, p1, 0.17, 0.25, P.iron, M.Metal)
			beam("ChandelierSuspension", p0, V(0, 20, z), 0.1, 0.1, P.iron, M.Metal)
			local candle = part("ChandelierCandle", V(0.18, 0.5, 0.18), CF(p0 + V(0, 0.3, 0)), P.pale, M.SmoothPlastic)
			local wick = part("CandleFlame", V(0.12, 0.2, 0.12), CF(p0 + V(0, 0.7, 0)), P.warm, M.Neon)
			candle.CastShadow, wick.CastShadow = false, false
		end
		local lightAnchor = part("ChandelierLight", V(0.1, 0.1, 0.1), CF(center), P.warm)
		lightAnchor.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness = P.warm, 25, 0.65
		light.Parent = lightAnchor
	end

	-- Two working bays, each with a recessed firebox, bellows, tools, anvil, and cooling tub.
	for _, target in { "Gold", "Ruby" } do
		local side = target == "Gold" and -1 or 1
		local x, color = side * 12, target == "Gold" and P.gold or P.ruby
		part(target .. "Dais", V(10.6, 0.55, 16), CF(x, 0.85, -18), P.shade, M.Slate, true)
		part("FurnaceCollision", V(7.3, 7.4, 3.3), CF(x, 5.2, -25.8), P.shade, M.Slate, true).Transparency = 1
		part("HearthPlinth", V(8.2, 0.65, 6.0), CF(x, 1.2, -25), P.shade, M.Slate, true)
		local hearthCF = CF(x, 1.5, -25.8)
		masonry(hearthCF, 7.3, 7.4, { { -2.0, 2.0, 0.3, 4.2 } })
		part("FireboxBack", V(4, 3.8, 0.15), CF(x, 3.65, -27), P.iron, M.Slate)
		part("FireboxFloor", V(4.2, 0.3, 3.7), CF(x, 1.8, -25.3), P.iron, M.Slate)
		arch(hearthCF * CF(0, 0, -0.95), 2.18, 2.7, 1.8, 0.5, 1.1, 9, P.pale)
		local coals = part("EmberBed", V(3.7, 0.07, 2.3), CF(x, 2.01, -25.6), C(218, 105, 39), M.Neon)
		for i = 1, 12 do
			part(
				"HearthCoal",
				V(0.42, 0.22, 0.36),
				CF(x + rng:NextNumber(-1.6, 1.6), 2.15, -25.5 + rng:NextNumber(-0.9, 0.9))
					* A(0, rng:NextNumber(0, PI), 0),
				i % 4 == 0 and C(216, 83, 27) or P.iron,
				i % 4 == 0 and M.Neon or M.Slate
			)
		end
		emitter(coals, "HearthHeat", "rbxasset://textures/particles/fire_main.dds", C(245, 156, 59), 3, 1.1, 1.0, 1.1).LightEmission =
			0.55
		emitter(coals, "HearthSparks", "rbxasset://textures/particles/sparkles_main.dds", P.warm, 1.8, 0.12, 1.3, 2.1).LightEmission =
			0.7
		local heat = Instance.new("PointLight")
		heat.Color, heat.Range, heat.Brightness, heat.Shadows = C(255, 170, 83), 18, 1.0, true
		heat.Parent = coals
		part("HearthHoodCornice", V(8.1, 0.5, 3.1), CF(x, 9.0, -25.8), P.pale, M.Limestone)
		part("SmokeHood", V(5.2, 4.5, 3.6), CF(x, 11.3, -26), P.shade, M.Brick)
		part("HoodIronBelt", V(5.4, 0.25, 3.8), CF(x, 9.7, -26), P.iron, M.Metal)
		part("ChimneyStack", V(3.5, 21.0, 3.1), CF(x, 24.0, -26), P.shade, M.Brick)
		for _, y in { 15, 24, 34.6 } do
			part("ChimneyCoping", V(4.2, 0.45, 3.8), CF(x, y, -26), P.pale, M.Limestone)
		end
		for _, dx in { -1.1, 1.1 } do
			part("ChimneyPot", V(0.9, 1.2, 1.2), CF(x + dx, 35.4, -26), P.iron, M.Metal)
		end
		local smoke = part("FlueSmokeAnchor", V(0.1, 0.1, 0.1), CF(x, 36.2, -26), P.iron)
		smoke.Transparency = 1
		emitter(
			smoke,
			"QuietFlueSmoke",
			"rbxasset://textures/particles/smoke_main.dds",
			C(107, 113, 106),
			0.7,
			3.1,
			5,
			1.7
		)
		local sign = part(target .. "Sign", V(6.7, 1.3, 0.32), CF(x, 7.65, -24.75) * A(0, PI, 0), P.oak, M.WoodPlanks)
		Lettering.Build(sign, string.upper(target), 0.95)
		for _, dx in { -3.2, 3.2 } do
			rivet(CF(x + dx, 7.65, -24.52) * A(0, PI, 0), 0.15)
		end
		tube("AnvilStump", CF(x, 1.5, -13), 1.3, 1.45, P.oak, M.Wood)
		tube("StumpIronHoop", CF(x, 1.8, -13), 1.34, 0.14, P.iron, M.Metal)
		part("AnvilFlaredFoot", V(2.4, 0.3, 1.7), CF(x, 2.35, -13), P.iron, M.Metal)
		part("AnvilWaist", V(1.25, 0.85, 1.2), CF(x, 2.9, -13), P.steel, M.Metal)
		part("AnvilFace", V(3.5, 0.35, 1.7), CF(x, 3.5, -13), P.steel, M.Metal, true)
		part(
			"AnvilHorn",
			V(1.1, 1.2, 2.3),
			CF(x + side * 2.6, 3.25, -13) * A(PI / 2, 0, -side * PI / 2),
			P.steel,
			M.Metal,
			false,
			"wedge"
		)
		part("AnvilHardyHole", V(0.32, 0.025, 0.32), CF(x - side * 0.9, 3.69, -13), P.iron, M.Slate)
		part("HammerGrip", V(0.16, 0.16, 1.65), CF(x - 0.6, 3.77, -12.7) * A(0, 0.25, 0), P.wood, M.Wood)
		part("HammerHead", V(0.75, 0.5, 0.5), CF(x - 0.4, 3.92, -13.35), P.steel, M.Metal)
		for _, offset in { -0.15, 0.15 } do
			part(
				"SmithTongs",
				V(0.08, 0.07, 1.4),
				CF(x + 0.5 + offset, 3.73, -12.7) * A(0, offset * 1.6, 0),
				P.iron,
				M.Metal
			)
		end
		part("OfferingBench", V(7.3, 0.26, 1.5), CF(x, 1.4, -8.0), P.oak, M.WoodPlanks)
		for _, dx in { -2.8, 2.8 } do
			part("OfferingBenchLeg", V(0.45, 0.8, 1.1), CF(x + dx, 0.95, -8), P.iron, M.Metal)
		end
		for i = 1, 5 do
			local cx = x + (i - 3) * 1.25
			part("MaterialSocket", V(1.0, 0.13, 1.0), CF(cx, 1.6, -8), P.iron, M.Metal)
			if target == "Gold" then
				ingot(CF(cx, 1.85, -8), color)
			else
				gem(CF(cx, 2.0, -8), color)
			end
		end
		local outerX = side * 18.3
		tube("QuenchTub", CF(outerX, 1.6, -11), 1.3, 1.8, P.oak, M.WoodPlanks)
		for _, y in { 0.95, 2.2 } do
			tube("QuenchTubHoop", CF(outerX, y, -11), 1.33, 0.13, P.iron, M.Metal)
		end
		local water = tube("QuenchWater", CF(outerX, 2.45, -11), 1.15, 0.04, C(74, 105, 109), M.Glass)
		water.Transparency, water.Reflectance = 0.18, 0.08
		part("BellowsFrame", V(2.0, 2.9, 0.22), CF(outerX, 3.0, -23), P.oak, M.Wood)
		for i = 0, 4 do
			part(
				"BellowsLeatherFold",
				V(1.8, 0.4, 1.7),
				CF(outerX, 1.9 + i * 0.42, -23) * A(0, 0, i % 2 == 0 and 0.1 or -0.1),
				C(72, 53, 39),
				M.Leather
			)
		end
		beam("BellowsNozzle", V(outerX, 2.3, -24), V(x + side * 2.8, 2.3, -25), 0.3, 0.3, P.iron, M.Metal)
		part("ToolRack", V(3.8, 3.6, 0.2), CF(outerX, 4.7, -29), P.oak, M.WoodPlanks)
		for i = -1, 1 do
			part("RackHammerHandle", V(0.16, 1.8, 0.17), CF(outerX + i * 1.0, 4.7, -28.75), P.wood, M.Wood)
			part("RackHammerHead", V(0.75, 0.45, 0.4), CF(outerX + i * 1.0, 5.55, -28.7), P.steel, M.Metal)
		end
		lantern(CF(x, 11.2, -24.0) * A(0, PI, 0))
		local anchor = part(target .. "Station", V(1, 1, 1), CF(x, 2, -15), color)
		anchor.Transparency = 1
		anchor:SetAttribute("ForgeTarget", target)
	end

	for _, side in { -1, 1 } do
		part("ApproachLanternFoot", V(2.2, 0.6, 2.2), CF(side * 24.2, 0.6, 53), P.shade, M.Slate)
		part("ApproachLanternPier", V(1.2, 4.5, 1.2), CF(side * 24.2, 3, 53), P.stone, M.Limestone)
		part("ApproachLanternCap", V(1.8, 0.3, 1.8), CF(side * 24.2, 5.4, 53), P.pale, M.Limestone)
		lantern(CF(side * 24.2, 4.3, 53) * A(0, PI, 0))
		chest(CF(side * 17, 0.66, 24) * A(0, side * 0.25, 0))
		for i = 0, 3 do
			ingot(CF(side * 18 + (i % 2) * 0.85, 0.9 + math.floor(i / 2) * 0.37, 19), P.steel)
		end
		for _, z in { -19, 19 } do
			lantern(CF(side * 20.0, 8.0, z) * A(0, -side * PI / 2, 0))
		end
		for _, z in { -32, 32 } do
			for i = 0, 2 do
				part(
					"FoundationMoss",
					V(0.9 + i * 0.2, 0.06, 0.7),
					CF(side * 22.3, 0.91, z + i * 0.65) * A(0, i * 0.7, 0),
					C(90, 107, 71),
					M.Grass
				)
			end
		end
	end
	part("KnightPlinth", V(4.4, 0.5, 4.4), CF(-8, 0.45, 43), P.shade, M.Slate, true)
	part("KnightPlinthRim", V(4.5, 0.09, 4.5), CF(-8, 0.72, 43), P.brass, M.Metal)
	flush()
	batch:Destroy()
	local knight = Knight.Build()
	knight:PivotTo(ORIGIN * CF(-8, 0.77, 43) * A(0, PI, 0))
	knight.Parent = hall
	return hall
end
return Hall
