-- A small, actual sanctuary shop display for the menu. No image or asset dependency.
local D = {}
local C, V, CF = Color3.fromRGB, Vector3.new, CFrame.new
local wood, stone, brass, slate = C(88, 62, 40), C(224, 221, 206), C(178, 142, 74), C(39, 65, 69)
function D.Build()
	local model = Instance.new("Model")
	model.Name = "SanctuaryMerchant"
	local function p(name, size, cf, color, mat)
		local part = Instance.new("Part")
		part.Name, part.Size, part.CFrame = name, size, cf
		part.Color, part.Material = color, mat or Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	p("LimestonePlinth", V(15, 0.65, 11), CF(0, -0.2, 0), stone, Enum.Material.Limestone)
	p("Inset", V(14, 0.15, 10), CF(0, 0.2, 0), C(109, 119, 113), Enum.Material.Slate)
	for _, x in { -5.8, 5.8 } do
		for _, z in { -3.8, 3.8 } do
			p("OakPost", V(0.5, 7.8, 0.5), CF(x, 4, z), wood, Enum.Material.Wood)
			p("PostCollar", V(0.65, 0.18, 0.65), CF(x, 0.6, z), brass, Enum.Material.Metal)
		end
	end
	p("Counter", V(12, 1.4, 3), CF(0, 2, -2.7), wood, Enum.Material.WoodPlanks)
	p("CounterStone", V(12.4, 0.22, 3.4), CF(0, 2.82, -2.7), stone, Enum.Material.Limestone)
	for _, side in { -1, 1 } do
		p(
			"Canopy",
			V(6.5, 0.3, 9.4),
			CF(side * 3.05, 8.7, 0) * CFrame.Angles(0, 0, -side * 0.20),
			slate,
			Enum.Material.Slate
		)
		p("RoofEdge", V(0.15, 0.38, 9.8), CF(side * 6.3, 8.02, 0), brass, Enum.Material.Metal)
	end
	p("Ridge", V(0.35, 0.4, 9.8), CF(0, 9.35, 0), brass, Enum.Material.Metal)
	for _, x in { -5, -3, 3, 5 } do
		p("ClothValance", V(1.8, 1.05, 0.18), CF(x, 7.45, -4.6), x < 0 and stone or slate)
	end
	for i = 1, 5 do
		local coin = p(
			"CoinStack",
			V(0.2, 0.8, 0.8),
			CF(-3.8 + i * 0.55, 3.05, -2.7) * CFrame.Angles(0, 0, math.pi / 2),
			brass,
			Enum.Material.Metal
		)
		coin.Shape = Enum.PartType.Cylinder
	end
	for i = 1, 3 do
		p(
			"Crystal",
			V(0.7, 1.1 + i * 0.28, 0.7),
			CF(2.2 + i * 0.65, 3.55, -2.7) * CFrame.Angles(0.1, i * 0.6, 0.12),
			C(135, 178, 160),
			Enum.Material.Glass
		)
	end
	for _, z in { -2, 1 } do
		p("Crate", V(2, 1.7, 2), CF(-4, 1.2, z), C(138, 103, 62), Enum.Material.WoodPlanks)
	end
	p("GuildSign", V(4, 1.2, 0.2), CF(0, 6.9, -4.55), wood, Enum.Material.WoodPlanks)
	p("SignInlay", V(0.4, 0.4, 0.25), CF(0, 6.9, -4.7) * CFrame.Angles(0, 0, math.pi / 4), brass, Enum.Material.Metal)
	return model
end
function D.Emblem(kind)
	local model = Instance.new("Model")
	model.Name = "Guild_" .. kind
	local function p(size, cf, color, mat)
		local part = Instance.new("Part")
		part.Size, part.CFrame, part.Color = size, cf, color
		part.Material = mat or Enum.Material.SmoothPlastic
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.Parent = model
		return part
	end
	if kind == "Upgrade" then
		p(V(5, 0.5, 4), CF(0, 0, 0), stone, Enum.Material.Limestone)
		p(V(2.8, 1.4, 1.7), CF(0, 1, 0), slate, Enum.Material.Metal)
		local held = CF(0, 3.1, 0) * CFrame.Angles(0, 0, -0.4)
		p(V(0.5, 3.3, 0.5), held, wood, Enum.Material.Wood)
		p(V(2.8, 1.2, 1.2), held * CF(0, 1.5, 0), slate, Enum.Material.Metal)
		p(V(0.65, 0.3, 0.65), held * CF(0, 0.65, 0), brass, Enum.Material.Metal)
	elseif kind == "Home" then
		p(V(7, 0.5, 6), CF(0, 0, 0), stone, Enum.Material.Limestone)
		for _, x in { -2.6, 2.6 } do
			for _, z in { -2, 2 } do
				p(V(0.4, 3.5, 0.4), CF(x, 1.9, z), wood, Enum.Material.Wood)
			end
		end
		for _, side in { -1, 1 } do
			p(V(3.5, 0.25, 6), CF(side * 1.6, 4.2, 0) * CFrame.Angles(0, 0, -side * 0.25), slate, Enum.Material.Slate)
		end
		p(V(0.25, 0.3, 6.3), CF(0, 4.8, 0), brass, Enum.Material.Metal)
	else
		p(V(7, 0.5, 5.5), CF(0, 2, 0), wood, Enum.Material.WoodPlanks)
		p(V(6.4, 0.15, 4.9), CF(0, 2.33, 0), stone)
		for _, x in { -2.7, 2.7 } do
			p(V(0.4, 2, 0.4), CF(x, 0.9, 0), wood, Enum.Material.Wood)
		end
		p(V(4, 0.08, 0.2), CF(-0.4, 2.45, 0.2) * CFrame.Angles(0, 0.4, 0), brass, Enum.Material.Metal)
		p(V(0.2, 0.08, 2), CF(1.2, 2.45, -0.3), brass, Enum.Material.Metal)
		p(V(0.2, 2.2, 0.2), CF(1.2, 3.5, -1.2), brass, Enum.Material.Metal)
		p(V(1.3, 0.8, 0.12), CF(1.8, 4, -1.2), slate)
	end
	return model
end
return D
