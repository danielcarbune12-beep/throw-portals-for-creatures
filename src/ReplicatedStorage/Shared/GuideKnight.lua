-- Original block-built knight used in the hall and in the guide's portrait.
local Knight = {}
function Knight.Build()
	local model = Instance.new("Model")
	model.Name = "SirRowan"
	local C, V, CF = Color3.fromRGB, Vector3.new, CFrame.new
	local steel, dark, brass, jade = C(170, 181, 183), C(48, 59, 63), C(190, 153, 78), C(37, 87, 73)
	local function part(name, size, cf, color, material, shape)
		local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Material = material or Enum.Material.Metal
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local root = part("Root", V(0.2, 0.2, 0.2), CF(), dark)
	root.Transparency = 1
	model.PrimaryPart = root
	for _, side in { -1, 1 } do
		part("Boot", V(0.8, 0.6, 1.15), CF(side * 0.52, 0.3, -0.12), dark)
		part("Greave", V(0.68, 1.45, 0.72), CF(side * 0.52, 1.23, 0), steel)
		part("KneeGuard", V(0.82, 0.55, 0.22), CF(side * 0.52, 1.7, -0.46), brass)
		part("Tasset", V(0.9, 1.0, 0.24), CF(side * 0.52, 2.1, -0.5) * CFrame.Angles(-0.12, 0, side * 0.08), steel)
		part("Arm", V(0.65, 1.55, 0.74), CF(side * 1.3, 2.9, 0), dark)
		part("Gauntlet", V(0.72, 0.7, 0.82), CF(side * 1.3, 2.35, -0.02), steel)
		part("Pauldron", V(1.1, 0.72, 1.2), CF(side * 1.25, 3.8, 0), steel)
		part("ShoulderRim", V(1.18, 0.16, 1.26), CF(side * 1.25, 3.5, 0), brass)
	end
	part("Surcoat", V(1.7, 1.95, 0.92), CF(0, 2.9, 0.12), jade, Enum.Material.Fabric)
	part("Breastplate", V(1.8, 1.5, 0.42), CF(0, 3.2, -0.5), steel)
	part("BreastRidge", V(0.14, 1.4, 0.13), CF(0, 3.2, -0.76), brass)
	part("Belt", V(1.95, 0.23, 1.22), CF(0, 2.35, 0), dark)
	part("Buckle", V(0.37, 0.33, 0.13), CF(0, 2.35, -0.67), brass)
	part("Cloak", V(1.9, 2.95, 0.24), CF(0, 2.35, 0.74) * CFrame.Angles(-0.12, 0, 0), jade, Enum.Material.Fabric)
	part("Gorget", V(1.3, 0.4, 1.15), CF(0, 4.03, 0), brass)
	part("Head", V(1.35, 1.35, 1.28), CF(0, 4.85, 0), steel)
	part("HelmetCrown", V(1.42, 0.25, 1.35), CF(0, 5.5, 0), dark)
	part("VisorSlit", V(1.15, 0.18, 0.08), CF(0, 4.99, -0.68), dark)
	part("NasalGuard", V(0.16, 0.9, 0.14), CF(0, 4.8, -0.74), brass)
	for _, x in { -0.45, -0.26, 0.26, 0.45 } do
		part("VisorVent", V(0.07, 0.28, 0.06), CF(x, 4.6, -0.68), dark)
	end
	for i = 0, 3 do
		part("HelmetPlume", V(0.3, 0.7 - i * 0.08, 0.4), CF(0, 5.85 - i * 0.12, i * 0.31), jade, Enum.Material.Fabric)
	end
	part("Shield", V(1.1, 1.85, 0.23), CF(-1.45, 2.7, -0.65), brass)
	part("ShieldFace", V(0.91, 1.63, 0.1), CF(-1.45, 2.7, -0.83), jade)
	part("ShieldSigil", V(0.4, 0.4, 0.12), CF(-1.45, 2.8, -0.94) * CFrame.Angles(0, 0, math.pi / 4), brass)
	part("SwordGrip", V(0.18, 0.65, 0.2), CF(1.3, 2.5, -0.5), dark)
	part("SwordGuard", V(0.8, 0.13, 0.24), CF(1.3, 2.1, -0.5), brass)
	part("SwordBlade", V(0.26, 1.8, 0.13), CF(1.3, 1.16, -0.5), steel)
	return model
end
return Knight
