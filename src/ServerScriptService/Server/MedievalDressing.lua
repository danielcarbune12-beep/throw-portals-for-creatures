-- MedievalDressing: art-direction pass that runs after the hub, courtyards and lane are built.
-- Location: ServerScriptService > Server > MedievalDressing (ModuleScript)
--
-- It never rebuilds anyone else's geometry. It finds existing landmarks by name and adds purposeful,
-- physically-mounted detail next to them, so the hub/base/biome builders stay untouched:
--   * Expedition stations: carved timber sign on an iron-bracketed post, supply crates, a travel pack,
--     rolled maps and a lantern. The floating "Expeditions" billboard is retired in favour of the sign.
--   * "PORTAL SANCTUARY": the flat label becomes a stone tablet in an iron frame with bolts and
--     engraved gold lettering.
--   * Ambient life: banners sway (WorldFx), sunlit pollen over the avenue, mist at waterfall feet.
-- Everything is non-colliding, CanQuery=false and seated by raycast on the surface below it.

local CollectionService = game:GetService("CollectionService")

local D = {}

local C = {
	oak = Color3.fromRGB(112, 78, 48),
	oakDark = Color3.fromRGB(78, 54, 34),
	iron = Color3.fromRGB(54, 52, 50),
	brass = Color3.fromRGB(176, 136, 62),
	stone = Color3.fromRGB(126, 122, 114),
	canvas = Color3.fromRGB(176, 158, 122),
	parchment = Color3.fromRGB(226, 210, 172),
	rope = Color3.fromRGB(150, 122, 84),
	flame = Color3.fromRGB(255, 196, 120),
	carve = Color3.fromRGB(58, 38, 22),
	gold = Color3.fromRGB(226, 186, 104),
}

local folder
local function part(name, size, cf, color, mat, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = mat or Enum.Material.Wood
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 2
	if shape then
		p.Shape = shape
	end
	p.Parent = folder
	return p
end

local ray = RaycastParams.new()
ray.FilterType = Enum.RaycastFilterType.Exclude
local function floorAt(pos)
	ray.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), ray)
	return hit and hit.Position.Y or pos.Y
end

local function fontFace()
	local ok, f = pcall(function()
		return Font.new("rbxasset://fonts/families/Fondamento.json", Enum.FontWeight.Bold)
	end)
	return ok and f or Font.fromEnum(Enum.Font.Fondamento)
end
local SIGN_FONT = fontFace()

-- lettering on a modeled surface (both faces), carved dark with a light bevel edge
local function letter(board, text, color, stroke, faces)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.LightInfluence = 1
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(0.86, 0.72)
		t.Position = UDim2.fromScale(0.07, 0.14)
		t.FontFace = SIGN_FONT
		t.TextScaled = true
		t.Text = text
		t.TextColor3 = color
		local s = Instance.new("UIStroke")
		s.Color = stroke
		s.Thickness = 2
		s.Transparency = 0.35
		s.Parent = t
		t.Parent = g
		g.Parent = board
	end
end

---------------------------------------------------------------- expedition stations
local function lantern(cf)
	part("LanternCap", Vector3.new(0.9, 0.18, 0.9), cf * CFrame.new(0, 0.62, 0), C.iron, Enum.Material.Metal)
	local glass = part("LanternGlass", Vector3.new(0.62, 0.9, 0.62), cf, C.flame, Enum.Material.Neon)
	glass.Transparency = 0.35
	for _, x in ipairs({ -0.36, 0.36 }) do
		for _, z in ipairs({ -0.36, 0.36 }) do
			part("LanternFrame", Vector3.new(0.08, 1.05, 0.08), cf * CFrame.new(x, 0, z), C.iron, Enum.Material.Metal)
		end
	end
	part("LanternBase", Vector3.new(0.8, 0.14, 0.8), cf * CFrame.new(0, -0.52, 0), C.iron, Enum.Material.Metal)
	local light = Instance.new("PointLight")
	light.Color = C.flame
	light.Range = 12
	light.Brightness = 0.9
	light.Shadows = false
	light.Parent = glass
	CollectionService:AddTag(glass, "TPFC_Pulse")
	glass:SetAttribute("Period", 2.6 + math.random() * 1.4)
	glass:SetAttribute("Base", 0.3)
	glass:SetAttribute("Peak", 0.48)
end

local function crate(cf, s)
	local body = part("SupplyCrate", Vector3.new(s, s * 0.8, s), cf, C.oak, Enum.Material.WoodPlanks)
	for _, y in ipairs({ -0.32, 0.32 }) do -- iron straps
		part(
			"CrateStrap",
			Vector3.new(s + 0.06, 0.12, s + 0.06),
			cf * CFrame.new(0, y * s * 0.8, 0),
			C.iron,
			Enum.Material.Metal
		)
	end
	return body
end

local function dressExpedition(base)
	local map = base:FindFirstChild("ExpeditionMap", true)
	if not map then
		return
	end
	local cf, size
	if map:IsA("Model") then
		cf, size = map:GetBoundingBox()
	else
		cf, size = map.CFrame, map.Size
	end
	-- the table's long side faces the courtyard; put the station dressing at its short end
	local rightV = (size.X >= size.Z) and cf.RightVector or cf.LookVector
	local fwdV = (size.X >= size.Z) and cf.LookVector or cf.RightVector
	local halfLen = math.max(size.X, size.Z) / 2
	local base0 = cf.Position + rightV * (halfLen + 2.2)
	local gy = floorAt(base0)
	local flat = CFrame.lookAt(Vector3.new(base0.X, gy, base0.Z), Vector3.new(base0.X, gy, base0.Z) + fwdV)

	-- signpost: stone footing, oak post, bracket arm, hanging carved board
	part("SignFooting", Vector3.new(1.4, 0.5, 1.4), flat * CFrame.new(0, 0.25, 0), C.stone, Enum.Material.Cobblestone)
	part("SignPost", Vector3.new(0.5, 6.6, 0.5), flat * CFrame.new(0, 3.55, 0), C.oakDark, Enum.Material.Wood)
	part("SignArm", Vector3.new(3.2, 0.32, 0.36), flat * CFrame.new(-1.45, 6.4, 0), C.oakDark, Enum.Material.Wood)
	part(
		"SignBrace",
		Vector3.new(0.22, 1.5, 0.22),
		flat * CFrame.new(-0.55, 5.85, 0) * CFrame.Angles(0, 0, math.rad(-45)),
		C.iron,
		Enum.Material.Metal
	)
	for _, x in ipairs({ -0.55, -2.35 }) do -- iron hangers
		part("SignHanger", Vector3.new(0.08, 0.6, 0.08), flat * CFrame.new(x, 5.95, 0), C.iron, Enum.Material.Metal)
	end
	local board = part(
		"SignBoard",
		Vector3.new(3.4, 1.1, 0.22),
		flat * CFrame.new(-1.45, 5.1, 0),
		C.oak,
		Enum.Material.WoodPlanks
	)
	board.CastShadow = true
	part("SignTrim", Vector3.new(3.56, 0.12, 0.26), flat * CFrame.new(-1.45, 5.69, 0), C.iron, Enum.Material.Metal)
	part("SignTrim", Vector3.new(3.56, 0.12, 0.26), flat * CFrame.new(-1.45, 4.51, 0), C.iron, Enum.Material.Metal)
	letter(board, "Expeditions", C.carve, C.parchment)
	-- lantern on its own short bracket on the far side of the post, clear of the lettering
	part("LanternArm", Vector3.new(1.1, 0.18, 0.18), flat * CFrame.new(0.75, 5.95, 0), C.iron, Enum.Material.Metal)
	lantern(flat * CFrame.new(1.15, 5.15, 0))

	-- supplies, grouped behind the post so the table front and its prompt stay clear
	local back = flat * CFrame.new(0.9, 0, 1.6)
	crate(back * CFrame.new(0, 0.6 + (floorAt(back.Position) - gy), 0) * CFrame.Angles(0, math.rad(8), 0), 1.5)
	crate(back * CFrame.new(0.05, 1.75 + (floorAt(back.Position) - gy), 0.05) * CFrame.Angles(0, math.rad(-12), 0), 1.0)
	local pack = back * CFrame.new(1.6, 0, -0.4)
	local py = floorAt(pack.Position) - gy
	part(
		"TravelPack",
		Vector3.new(1.1, 1.3, 0.8),
		pack * CFrame.new(0, 0.65 + py, 0) * CFrame.Angles(math.rad(-6), math.rad(20), 0),
		C.canvas,
		Enum.Material.Fabric
	)
	part(
		"PackFlap",
		Vector3.new(1.12, 0.5, 0.84),
		pack * CFrame.new(0, 1.15 + py, 0.02) * CFrame.Angles(math.rad(-6), math.rad(20), 0),
		C.oakDark,
		Enum.Material.Fabric
	)
	part(
		"BedRoll",
		Vector3.new(1.2, 0.42, 0.42),
		pack * CFrame.new(0, 1.5 + py, 0) * CFrame.Angles(0, math.rad(20), 0),
		C.rope,
		Enum.Material.Fabric,
		Enum.PartType.Cylinder
	)
	-- rolled maps leaning on the crates
	for i, a in ipairs({ -14, 6 }) do
		part(
			"RolledMap",
			Vector3.new(1.6, 0.26, 0.26),
			back
				* CFrame.new(-0.95, 0.75 + (floorAt(back.Position) - gy), -0.3 + i * 0.32)
				* CFrame.Angles(0, 0, math.rad(62 + a)),
			C.parchment,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
	end

	-- retire the floating billboard: the carved sign carries the name now
	local anchor = base:FindFirstChild("ExpeditionAnchor", true)
	local bb = anchor and anchor:FindFirstChildOfClass("BillboardGui")
	if bb then
		bb.Enabled = false
	end
end

---------------------------------------------------------------- Portal Sanctuary tablet
local function dressSanctuarySign()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, g in ipairs(map:GetDescendants()) do
		if g:IsA("TextLabel") and g.Text == "PORTAL SANCTUARY" then
			local sg = g:FindFirstAncestorOfClass("SurfaceGui")
			local backing = sg and sg.Parent
			if backing and backing:IsA("BasePart") and not backing:GetAttribute("Dressed") then
				backing:SetAttribute("Dressed", true)
				backing.Material = Enum.Material.Slate
				backing.Color = Color3.fromRGB(96, 92, 86)
				local cf, s = backing.CFrame, backing.Size
				-- iron frame, slightly proud of the tablet, with bolts at the corners
				part(
					"TabletFrame",
					Vector3.new(s.X + 0.5, 0.26, s.Z + 0.24),
					cf * CFrame.new(0, s.Y / 2 + 0.1, 0),
					C.iron,
					Enum.Material.Metal
				)
				part(
					"TabletFrame",
					Vector3.new(s.X + 0.5, 0.26, s.Z + 0.24),
					cf * CFrame.new(0, -s.Y / 2 - 0.1, 0),
					C.iron,
					Enum.Material.Metal
				)
				part(
					"TabletFrame",
					Vector3.new(0.26, s.Y + 0.46, s.Z + 0.24),
					cf * CFrame.new(s.X / 2 + 0.12, 0, 0),
					C.iron,
					Enum.Material.Metal
				)
				part(
					"TabletFrame",
					Vector3.new(0.26, s.Y + 0.46, s.Z + 0.24),
					cf * CFrame.new(-s.X / 2 - 0.12, 0, 0),
					C.iron,
					Enum.Material.Metal
				)
				for _, x in ipairs({ -1, 1 }) do
					for _, y in ipairs({ -1, 1 }) do
						part(
							"TabletBolt",
							Vector3.new(0.3, 0.3, 0.3),
							cf * CFrame.new(x * (s.X / 2 - 0.35), y * (s.Y / 2 - 0.3), -s.Z / 2 - 0.12),
							C.brass,
							Enum.Material.Metal,
							Enum.PartType.Ball
						)
					end
				end
				-- engraved gold capitals, readable at distance (no blackletter)
				g.FontFace = SIGN_FONT
				g.TextColor3 = C.gold
				local st = g:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
				st.Color = Color3.fromRGB(40, 30, 20)
				st.Thickness = 2.5
				st.Transparency = 0.2
				st.Parent = g
				g.TextStrokeTransparency = 1
				sg.LightInfluence = 1
			end
		end
	end
end

---------------------------------------------------------------- construction detail
-- Pillars get a seated plinth and a cap course; timber posts get iron straps at their joints.
-- Detection is by shape and material, and every addition is skipped if the structure already has one.
local STONE = {
	[Enum.Material.Limestone] = true,
	[Enum.Material.Marble] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Granite] = true,
	[Enum.Material.Cobblestone] = true,
	[Enum.Material.Sandstone] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Plastic] = true,
	[Enum.Material.Basalt] = true,
}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude

local function wider(at, size, except, minW)
	overlap.FilterDescendantsInstances = { except, folder }
	for _, q in ipairs(workspace:GetPartBoundsInBox(at, size, overlap)) do
		if q.Transparency < 0.5 and math.max(q.Size.X, q.Size.Z) >= minW then
			return true
		end
	end
	return false
end

local function pillarDetail(root)
	local n = 0
	for _, p in ipairs(root:GetDescendants()) do
		if n >= 220 then
			break
		end
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Transparency < 0.1 and STONE[p.Material] then
			local s = p.Size
			local h, w = s.Y, math.max(s.X, s.Z)
			local lum = p.Color.R * 0.3 + p.Color.G * 0.59 + p.Color.B * 0.11
			if
				h >= 5
				and h <= 30
				and w >= 0.9
				and w <= 3.4
				and math.min(s.X, s.Z) >= 0.7
				and p.CFrame.UpVector.Y > 0.99
				and lum > 0.55
			then
				local bottom = p.Position - Vector3.new(0, h / 2, 0)
				ray.FilterDescendantsInstances = { folder, p }
				local hit = workspace:Raycast(bottom + Vector3.new(0, 0.3, 0), Vector3.new(0, -2, 0), ray)
				local gy = hit and hit.Position.Y or bottom.Y
				local seated = hit ~= nil and math.abs(gy - bottom.Y) < 0.8
				local rot = p.CFrame.Rotation
				local stone = p.Color:Lerp(Color3.fromRGB(150, 144, 132), 0.35)
				if
					seated
					and not wider(
						CFrame.new(bottom.X, gy + 0.3, bottom.Z),
						Vector3.new(s.X + 0.2, 0.4, s.Z + 0.2),
						p,
						w + 0.35
					)
				then
					local b = part(
						"PillarPlinth",
						Vector3.new(s.X + 0.7, 0.55, s.Z + 0.7),
						CFrame.new(bottom.X, gy + 0.275, bottom.Z) * rot,
						stone,
						p.Material
					)
					b.CastShadow = true
					part(
						"PillarTorus",
						Vector3.new(s.X + 0.36, 0.22, s.Z + 0.36),
						CFrame.new(bottom.X, gy + 0.66, bottom.Z) * rot,
						stone,
						p.Material
					)
					n += 1
				end
				local top = p.Position + Vector3.new(0, h / 2, 0)
				if
					not wider(CFrame.new(top + Vector3.new(0, 0.25, 0)), Vector3.new(s.X - 0.1, 0.3, s.Z - 0.1), p, 0)
				then
					part(
						"PillarCap",
						Vector3.new(s.X + 0.5, 0.3, s.Z + 0.5),
						CFrame.new(top + Vector3.new(0, 0.15, 0)) * rot,
						stone,
						p.Material
					)
					n += 1
				end
			end
		end
	end
	return n
end

local function timberStraps(root)
	for _, p in ipairs(root:GetDescendants()) do
		if
			p:IsA("BasePart")
			and (p.Name:find("TimberPost") or p.Name:find("Post") and p.Material == Enum.Material.Wood)
			and p.Size.Y > 4
		then
			local s = p.Size
			for _, y in ipairs({ s.Y / 2 - 0.6, -s.Y / 2 + 0.7 }) do
				part(
					"IronStrap",
					Vector3.new(s.X + 0.08, 0.22, s.Z + 0.08),
					p.CFrame * CFrame.new(0, y, 0),
					C.iron,
					Enum.Material.Metal
				)
				part(
					"StrapBolt",
					Vector3.new(0.16, 0.16, 0.16),
					p.CFrame * CFrame.new(0, y, -s.Z / 2 - 0.05),
					C.brass,
					Enum.Material.Metal,
					Enum.PartType.Ball
				)
			end
		end
	end
end

-- Roofs: slate tile surface, timber ridge cap on the high edge, fascia board along the eave.
-- WedgePart geometry: high edge at local (0, +h/2, +l/2), eave at (0, -h/2, -l/2).
local function roofDetail(root)
	local done, n = {}, 0
	for _, w in ipairs(root:GetDescendants()) do
		if n >= 260 then
			break
		end
		if
			w:IsA("WedgePart")
			and w.Name == "RoofSlope"
			and w.Transparency < 0.1
			and w.Size.X >= 3
			and w.Size.Z >= 2.5
			and w.Size.Y >= 0.8
		then
			local s = w.Size
			w.Material = Enum.Material.Slate -- reads as tiles, colour kept
			local ridge = w.CFrame * CFrame.new(0, s.Y / 2, s.Z / 2)
			local key =
				string.format("%d,%d,%d", math.floor(ridge.X * 2), math.floor(ridge.Y * 2), math.floor(ridge.Z * 2))
			if not done[key] then
				done[key] = true
				part(
					"RoofRidge",
					Vector3.new(s.X + 0.4, 0.42, 0.62),
					ridge * CFrame.new(0, 0.1, 0),
					C.oakDark,
					Enum.Material.Wood
				)
				n += 1
			end
			-- fascia board under the eave edge, angled with the roof's run
			part(
				"RoofFascia",
				Vector3.new(s.X + 0.3, 0.38, 0.26),
				w.CFrame * CFrame.new(0, -s.Y / 2 + 0.12, -s.Z / 2 - 0.08),
				C.oak,
				Enum.Material.Wood
			)
			n += 1
		end
	end
end

-- Large stone walls: a darker, slightly proud base course where they meet the ground.
local function wallCourses(root)
	local n = 0
	for _, p in ipairs(root:GetDescendants()) do
		if n >= 140 then
			break
		end
		if
			p:IsA("Part")
			and p.Shape == Enum.PartType.Block
			and p.Transparency < 0.1
			and STONE[p.Material]
			and p.Size.Y >= 6
			and math.max(p.Size.X, p.Size.Z) >= 8
			and p.CFrame.UpVector.Y > 0.99
		then
			local s = p.Size
			local bottom = p.Position - Vector3.new(0, s.Y / 2, 0)
			ray.FilterDescendantsInstances = { folder, p }
			local hit = workspace:Raycast(bottom + Vector3.new(0, 0.3, 0), Vector3.new(0, -2, 0), ray)
			if
				hit
				and math.abs(hit.Position.Y - bottom.Y) < 0.6
				and not wider(
					CFrame.new(bottom.X, hit.Position.Y + 0.45, bottom.Z) * p.CFrame.Rotation,
					Vector3.new(s.X + 0.1, 0.5, s.Z + 0.1),
					p,
					math.max(s.X, s.Z) + 0.25
				)
			then
				local course = part(
					"BaseCourse",
					Vector3.new(s.X + 0.3, 0.9, s.Z + 0.3),
					CFrame.new(bottom.X, hit.Position.Y + 0.45, bottom.Z) * p.CFrame.Rotation,
					p.Color:Lerp(Color3.fromRGB(110, 106, 98), 0.45),
					Enum.Material.Cobblestone
				)
				course.CastShadow = true
				n += 1
			end
		end
	end
end

-- Walkways: large flat plastic slabs read as shiny toy plastic under real lighting. Give paving its
-- real material (colour kept): light stone -> Pavement, darker stone -> Slate. Thin trim strips,
-- glowing inlays and metal edging are left alone.
local function pavingMaterials(root)
	for _, p in ipairs(root:GetDescendants()) do
		if
			p:IsA("BasePart")
			and p.Material == Enum.Material.SmoothPlastic
			and p.Transparency < 0.1
			and p.Size.Y < 1.6
			and math.max(p.Size.X, p.Size.Z) > 8
			and math.min(p.Size.X, p.Size.Z) > 2.5
		then
			local c = p.Color
			local lum = c.R * 0.3 + c.G * 0.59 + c.B * 0.11
			local sat = math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
			if sat < 0.25 then -- neutral stone tones only; coloured rugs/inlays keep their finish
				p.Material = lum > 0.55 and Enum.Material.Pavement or Enum.Material.Slate
			end
		end
	end
end

-- Palette: the hub's cliffs and roofs were saturated lavender/violet, which reads as toy plastic
-- under realistic light. Natural materials get natural colour (value kept, so composition holds);
-- heraldry (fabric banners), glass, neon portal energy and small crystals keep their colour.
local NATURAL = {
	[Enum.Material.Limestone] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Rock] = true,
	[Enum.Material.SmoothPlastic] = true,
	[Enum.Material.Plastic] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Basalt] = true,
	[Enum.Material.Granite] = true,
}
local function naturalPalette(root)
	for _, p in ipairs(root:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 0.5 and NATURAL[p.Material] then
			local h, s, v = p.Color:ToHSV()
			if s > 0.12 and h > 0.6 and h < 0.86 then
				local s3 = p.Size
				local vol = s3.X * s3.Y * s3.Z
				-- big wedges are cliff facets, not roofs
				local isRoof = p.Name:lower():find("roof") ~= nil
				if isRoof then
					-- weathered slate blue: keeps a royal hint without the candy violet
					p.Color = Color3.fromHSV(0.61, math.min(s, 0.32), v * 0.82)
					if p.Material == Enum.Material.SmoothPlastic or p.Material == Enum.Material.Plastic then
						p.Material = Enum.Material.Slate
					end
				elseif vol > 2000 then
					-- cliffs and big masonry: warm grey stone with a faint cool shadow tone
					p.Color = Color3.fromHSV(0.08, 0.1, math.clamp(v * 0.9, 0.35, 0.82))
					if p.Material == Enum.Material.SmoothPlastic or p.Material == Enum.Material.Plastic then
						p.Material = Enum.Material.Rock
					end
				end
			end
		end
	end
end

local function construction()
	local roots =
		{ workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start"), workspace:FindFirstChild("Bases") }
	for _, r in ipairs(roots) do
		if r then
			pillarDetail(r)
			timberStraps(r)
			roofDetail(r)
			wallCourses(r)
			pavingMaterials(r)
			naturalPalette(r)
			-- Trees keep their authored silhouette. Only deliberately tagged foliage
			-- animates; do not add hundreds of extra canopy transforms here.
		end
	end
	-- (the hall arches already carry a crystal crest at the apex, so no keystone is added there)
end

---------------------------------------------------------------- ambient life
local function bannersSway()
	local roots =
		{ workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start"), workspace:FindFirstChild("Bases") }
	local n = 0
	for _, root in ipairs(roots) do
		if root then
			for _, p in ipairs(root:GetDescendants()) do
				if
					p:IsA("BasePart")
					and p.Anchored
					and p.Name:lower():find("banner")
					and p.Size.Y > p.Size.X * 1.4
					and not CollectionService:HasTag(p, "TPFC_Sway")
				then
					CollectionService:AddTag(p, "TPFC_Sway")
					p:SetAttribute("Period", 4.5 + math.random() * 3) -- desynchronised
					p:SetAttribute("Amp", 0.018 + math.random() * 0.012)
					n += 1
					if n > 160 then
						return
					end
				end
			end
		end
	end
end

local function emitterPart(name, size, cf)
	local p = part(name, size, cf, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	p.Transparency = 1
	p.CastShadow = false
	return p
end

local function pollen()
	local p = emitterPart("SunlitPollen", Vector3.new(70, 8, 360), CFrame.new(0, 9, -250))
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new(Color3.fromRGB(255, 240, 200))
	e.LightEmission = 0.4
	e.LightInfluence = 0.6
	e.Size = NumberSequence.new(0.12, 0.08)
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(6, 10)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.15, 0.05, 0.1)
	e.Rate = 10
	e:SetAttribute("BaseRate", 10)
	e.Parent = p
	CollectionService:AddTag(e, "TPFC_EnvironmentEmitter")
end

local function waterfallMist()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local n = 0
	for _, p in ipairs(map:GetDescendants()) do
		if n >= 6 then
			break
		end
		if p:IsA("BasePart") and p.Name:lower():find("fall") and p.Size.Y > 6 and p.Transparency < 0.9 then
			n += 1
			local foot = p.Position - Vector3.new(0, p.Size.Y / 2 - 1, 0)
			local m = emitterPart(
				"WaterfallMist",
				Vector3.new(math.max(p.Size.X, p.Size.Z), 2, math.max(p.Size.X, p.Size.Z)),
				CFrame.new(foot)
			)
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(236, 244, 250))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
			e.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.25, 0.82),
				NumberSequenceKeypoint.new(1, 1),
			})
			e.Lifetime = NumberRange.new(2.5, 4)
			e.Speed = NumberRange.new(1, 2.5)
			e.SpreadAngle = Vector2.new(60, 60)
			e.Rate = 6
			e:SetAttribute("BaseRate", 6)
			e.LightInfluence = 0.8
			e.Parent = m
			CollectionService:AddTag(e, "TPFC_EnvironmentEmitter")
		end
	end
end

---------------------------------------------------------------- entry
function D.Apply()
	folder = workspace:FindFirstChild("MedievalDressing") or Instance.new("Folder")
	folder.Name = "MedievalDressing"
	folder.Parent = workspace
	folder:ClearAllChildren()
	-- Match WorldBuilder and the authored place: no dense animated grass blades.
	-- Keep terrain materials/colours; no per-paving voxel replacement is needed.
	pcall(function()
		workspace.Terrain.Decoration = false
	end)
	local bases = workspace:FindFirstChild("Bases")
	if bases then
		for _, b in ipairs(bases:GetChildren()) do
			local ok, err = pcall(dressExpedition, b)
			if not ok then
				warn("[MedievalDressing] expedition " .. b.Name .. ": " .. tostring(err))
			end
		end
	end
	for _, f in ipairs({ dressSanctuarySign, construction, bannersSway, pollen, waterfallMist }) do
		local ok, err = pcall(f)
		if not ok then
			warn("[MedievalDressing] " .. tostring(err))
		end
	end
	-- the sanctuary as a fortified castle: battlements, towers, gatehouse (separate module, scenery only)
	local okC, errC = pcall(function()
		require(script.Parent.CastleWalls).Build(workspace)
	end)
	if not okC then
		warn("[MedievalDressing] castle: " .. tostring(errC))
	end
	local okW, errW = pcall(function()
		require(script.Parent.Waterfalls).Build(workspace)
	end)
	if not okW then
		warn("[MedievalDressing] waterfalls: " .. tostring(errW))
	end
end

return D
