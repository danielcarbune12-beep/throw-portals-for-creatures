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
	if shape then p.Shape = shape end
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
	local ok, f = pcall(function() return Font.new("rbxasset://fonts/families/Fondamento.json", Enum.FontWeight.Bold) end)
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
		part("CrateStrap", Vector3.new(s + 0.06, 0.12, s + 0.06), cf * CFrame.new(0, y * s * 0.8, 0), C.iron, Enum.Material.Metal)
	end
	return body
end

local function dressExpedition(base)
	local map = base:FindFirstChild("ExpeditionMap", true)
	if not map then return end
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
	part("SignBrace", Vector3.new(0.22, 1.5, 0.22), flat * CFrame.new(-0.55, 5.85, 0) * CFrame.Angles(0, 0, math.rad(-45)), C.iron, Enum.Material.Metal)
	for _, x in ipairs({ -0.55, -2.35 }) do -- iron hangers
		part("SignHanger", Vector3.new(0.08, 0.6, 0.08), flat * CFrame.new(x, 5.95, 0), C.iron, Enum.Material.Metal)
	end
	local board = part("SignBoard", Vector3.new(3.4, 1.1, 0.22), flat * CFrame.new(-1.45, 5.1, 0), C.oak, Enum.Material.WoodPlanks)
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
	part("TravelPack", Vector3.new(1.1, 1.3, 0.8), pack * CFrame.new(0, 0.65 + py, 0) * CFrame.Angles(math.rad(-6), math.rad(20), 0), C.canvas, Enum.Material.Fabric)
	part("PackFlap", Vector3.new(1.12, 0.5, 0.84), pack * CFrame.new(0, 1.15 + py, 0.02) * CFrame.Angles(math.rad(-6), math.rad(20), 0), C.oakDark, Enum.Material.Fabric)
	part("BedRoll", Vector3.new(1.2, 0.42, 0.42), pack * CFrame.new(0, 1.5 + py, 0) * CFrame.Angles(0, math.rad(20), 0), C.rope, Enum.Material.Fabric, Enum.PartType.Cylinder)
	-- rolled maps leaning on the crates
	for i, a in ipairs({ -14, 6 }) do
		part("RolledMap", Vector3.new(1.6, 0.26, 0.26), back * CFrame.new(-0.95, 0.75 + (floorAt(back.Position) - gy), -0.3 + i * 0.32) * CFrame.Angles(0, 0, math.rad(62 + a)), C.parchment, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end

	-- retire the floating billboard: the carved sign carries the name now
	local anchor = base:FindFirstChild("ExpeditionAnchor", true)
	local bb = anchor and anchor:FindFirstChildOfClass("BillboardGui")
	if bb then bb.Enabled = false end
end

---------------------------------------------------------------- Portal Sanctuary tablet
local function dressSanctuarySign()
	local map = workspace:FindFirstChild("Map")
	if not map then return end
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
				part("TabletFrame", Vector3.new(s.X + 0.5, 0.26, s.Z + 0.24), cf * CFrame.new(0, s.Y / 2 + 0.1, 0), C.iron, Enum.Material.Metal)
				part("TabletFrame", Vector3.new(s.X + 0.5, 0.26, s.Z + 0.24), cf * CFrame.new(0, -s.Y / 2 - 0.1, 0), C.iron, Enum.Material.Metal)
				part("TabletFrame", Vector3.new(0.26, s.Y + 0.46, s.Z + 0.24), cf * CFrame.new(s.X / 2 + 0.12, 0, 0), C.iron, Enum.Material.Metal)
				part("TabletFrame", Vector3.new(0.26, s.Y + 0.46, s.Z + 0.24), cf * CFrame.new(-s.X / 2 - 0.12, 0, 0), C.iron, Enum.Material.Metal)
				for _, x in ipairs({ -1, 1 }) do
					for _, y in ipairs({ -1, 1 }) do
						part("TabletBolt", Vector3.new(0.3, 0.3, 0.3), cf * CFrame.new(x * (s.X / 2 - 0.35), y * (s.Y / 2 - 0.3), -s.Z / 2 - 0.12), C.brass, Enum.Material.Metal, Enum.PartType.Ball)
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

---------------------------------------------------------------- ambient life
local function bannersSway()
	local roots = { workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Start"), workspace:FindFirstChild("Bases") }
	local n = 0
	for _, root in ipairs(roots) do
		if root then
			for _, p in ipairs(root:GetDescendants()) do
				if p:IsA("BasePart") and p.Anchored and p.Name:lower():find("banner") and p.Size.Y > p.Size.X * 1.4 and not CollectionService:HasTag(p, "TPFC_Sway") then
					CollectionService:AddTag(p, "TPFC_Sway")
					p:SetAttribute("Period", 4.5 + math.random() * 3) -- desynchronised
					p:SetAttribute("Amp", 0.018 + math.random() * 0.012)
					n += 1
					if n > 160 then return end
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
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.45), NumberSequenceKeypoint.new(1, 1) })
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
	if not map then return end
	local n = 0
	for _, p in ipairs(map:GetDescendants()) do
		if n >= 6 then break end
		if p:IsA("BasePart") and p.Name:lower():find("fall") and p.Size.Y > 6 and p.Transparency < 0.9 then
			n += 1
			local foot = p.Position - Vector3.new(0, p.Size.Y / 2 - 1, 0)
			local m = emitterPart("WaterfallMist", Vector3.new(math.max(p.Size.X, p.Size.Z), 2, math.max(p.Size.X, p.Size.Z)), CFrame.new(foot))
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/smoke_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(236, 244, 250))
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 8) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.82), NumberSequenceKeypoint.new(1, 1) })
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
	local bases = workspace:FindFirstChild("Bases")
	if bases then
		for _, b in ipairs(bases:GetChildren()) do
			local ok, err = pcall(dressExpedition, b)
			if not ok then warn("[MedievalDressing] expedition " .. b.Name .. ": " .. tostring(err)) end
		end
	end
	for _, f in ipairs({ dressSanctuarySign, bannersSway, pollen, waterfallMist }) do
		local ok, err = pcall(f)
		if not ok then warn("[MedievalDressing] " .. tostring(err)) end
	end
end

return D
