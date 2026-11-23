-- An architectural model of the four sanctuary trades, made for the exchange folio.
local Merchant = require(script.Parent.MerchantDisplay)
local Portal = require(game:GetService("ReplicatedStorage").Shared.PortalBuilder)
local K = require(script.Parent.UIKit)
local Builder = require(game:GetService("ReplicatedStorage").Shared.CreatureBuilder)
local G = {}
local C, V, CF = Color3.fromRGB, Vector3.new, CFrame.new
local stone, edge, jade, wood, brass =
	C(231, 235, 223), C(155, 170, 160), C(45, 100, 82), C(90, 64, 41), C(183, 147, 78)
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.TopSurface, p.BottomSurface, p.Parent = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth, parent
	return p
end
function G.Build()
	local m = Instance.new("Model")
	m.Name = "TheFourTrades"
	part(m, "CutawayFoundation", V(38, 1.6, 24), CF(0, -1.1, 0), edge, Enum.Material.Limestone)
	part(m, "UpperTerrace", V(35, 0.65, 26), CF(0, -0.15, 0), stone, Enum.Material.Limestone)
	part(m, "FrontThreshold", V(28, 0.7, 2), CF(0, -0.4, 13), edge, Enum.Material.Limestone)
	part(m, "FrontStep", V(22, 0.35, 2), CF(0, -0.8, 14.7), stone, Enum.Material.Limestone)
	-- The inlaid route meets at the split-gate seal in the centre.
	for _, x in { -1.1, 1.1 } do
		part(m, "InlaidRoute", V(0.13, 0.03, 22), CF(x, 0.2, 0), brass, Enum.Material.Metal)
	end
	for _, z in { -1.1, 1.1 } do
		part(m, "InlaidRoute", V(32, 0.03, 0.13), CF(0, 0.2, z), brass, Enum.Material.Metal)
	end
	part(m, "GateSeal", V(4, 0.12, 4), CF(0, 0.28, 0) * CFrame.Angles(0, math.pi / 4, 0), jade, Enum.Material.Slate)
	for _, x in { -0.7, 0.7 } do
		part(m, "SealLeaves", V(0.35, 0.05, 1.7), CF(x, 0.38, 0), brass, Enum.Material.Metal)
	end
	local stations = {
		{ "Forge", Portal.BuildGate("Forest", 3.5), V(-10, 0.4, -5), 1 },
		{ "Upgrades", Merchant.Emblem("Upgrade"), V(10, 0.6, -5), 1.65 },
		{ "Courtyard", Merchant.Emblem("Home"), V(-10, 0.6, 7), 1.25 },
		{ "Atlas", Merchant.Emblem("Compass"), V(10, 0.6, 7), 1.15 },
	}
	for _, def in stations do
		local pad = part(
			m,
			"Pad_" .. def[1],
			V(10, 0.08, 9),
			CF(def[3].X, 0.26, def[3].Z),
			C(213, 224, 211),
			Enum.Material.Limestone
		)
		pad:SetAttribute("RestColor", pad.Color)
		local subject = def[2]
		subject.Name = def[1]
		subject:ScaleTo(def[4])
		K.bakeWelds(subject)
		local cf, size = Builder.VisualBounds(subject)
		local offset = def[3] - Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z)
		subject:PivotTo(subject:GetPivot() + offset)
		subject.Parent = m
	end
	for _, x in { -16.5, 16.5 } do
		for _, z in { -10, 10 } do
			part(m, "PierFoot", V(1.6, 0.5, 1.6), CF(x, 0.6, z), edge, Enum.Material.Limestone)
			part(m, "OakPier", V(0.65, 3.8, 0.65), CF(x, 2.5, z), wood, Enum.Material.Wood)
			part(m, "PierCrown", V(1.1, 0.22, 1.1), CF(x, 4.5, z), brass, Enum.Material.Metal)
		end
	end
	for _, x in { -16, 16 } do
		for i = 1, 5 do
			part(m, "SideCoping", V(0.8, 0.7, 1.9), CF(x, 0.7, -7.5 + i * 2.4), stone, Enum.Material.Limestone)
		end
	end
	for _, x in { -11, 11 } do
		for i = 1, 3 do
			local crate =
				part(m, "TradeCrate", V(1.6, 1.5, 1.6), CF(x + (i - 2) * 1.75, 1, -10), wood, Enum.Material.WoodPlanks)
			part(m, "CrateBinding", V(1.7, 0.18, 1.7), crate.CFrame, brass, Enum.Material.Metal)
		end
	end
	-- Small jade flags give the model the same silhouette as the courtyard roofs.
	for _, x in { -4, 4 } do
		part(m, "BannerStaff", V(0.18, 7.6, 0.18), CF(x, 4.1, -10), wood, Enum.Material.Wood)
		part(m, "GuildBanner", V(2.1, 3.5, 0.12), CF(x + 1.1, 5.6, -10), jade, Enum.Material.Fabric)
		part(m, "BannerClasp", V(2.25, 0.15, 0.2), CF(x + 1.1, 7.4, -10), brass, Enum.Material.Metal)
	end
	-- Trade objects make the model read as a working place, rather than empty pads.
	part(m, "TradeChest", V(3, 1.7, 2), CF(-5, 1.1, 10.5), wood, Enum.Material.WoodPlanks)
	for _, x in { -5.9, -4.1 } do
		part(m, "ChestStrap", V(0.2, 1.85, 2.1), CF(x, 1.1, 10.5), brass, Enum.Material.Metal)
	end
	part(m, "ChestLock", V(0.6, 0.65, 0.15), CF(-5, 1.35, 11.6), brass, Enum.Material.Metal)
	for i = 1, 9 do
		local coin = part(
			m,
			"PurseCoin",
			V(0.13, 0.75, 0.75),
			CF(3 + (i % 3) * 0.85, 0.4 + math.floor(i / 3) * 0.15, 10.3 + (i % 2) * 0.8)
				* CFrame.Angles(0, 0, math.pi / 2),
			brass,
			Enum.Material.Metal
		)
		coin.Shape = Enum.PartType.Cylinder
	end
	for i = 1, 3 do
		local chart = part(m, "RolledChart", V(3.2, 0.6, 0.6), CF(9 + i * 0.3, 0.6 + i * 0.18, 10.8 + i * 0.5), stone)
		chart.Shape = Enum.PartType.Cylinder
		part(m, "ChartTie", V(0.2, 0.72, 0.72), chart.CFrame, brass, Enum.Material.Metal)
	end
	for _, x in { -16, 16 } do
		part(m, "LanternFoot", V(1.1, 0.15, 1.1), CF(x, 0.8, -2), brass, Enum.Material.Metal)
		part(m, "LanternPane", V(0.65, 1, 0.65), CF(x, 1.35, -2), C(235, 198, 115))
		part(m, "LanternCap", V(1.05, 0.18, 1.05), CF(x, 1.95, -2), wood, Enum.Material.Metal)
		for _, dx in { -0.4, 0.4 } do
			for _, dz in { -0.4, 0.4 } do
				part(m, "LanternIron", V(0.1, 1.2, 0.1), CF(x + dx, 1.35, -2 + dz), wood, Enum.Material.Metal)
			end
		end
	end
	return m
end
function G.Sign()
	local m = Instance.new("Model")
	m.Name = "GuildTradeSign"
	part(m, "OakBack", V(22, 4.6, 0.6), CF(), wood, Enum.Material.Wood)
	part(m, "UpperBoard", V(21, 1.9, 0.2), CF(0, 1, -0.4), jade, Enum.Material.WoodPlanks)
	part(m, "LowerBoard", V(21, 1.9, 0.2), CF(0, -1, -0.4), jade, Enum.Material.WoodPlanks)
	for _, x in { -10.1, 10.1 } do
		part(m, "BrassStrap", V(0.38, 4.2, 0.24), CF(x, 0, -0.6), brass, Enum.Material.Metal)
		for _, y in { -1.5, 1.5 } do
			part(m, "SquareNail", V(0.6, 0.5, 0.32), CF(x, y, -0.8), wood, Enum.Material.Metal)
		end
	end
	return m
end
function G.Pedestal(model)
	local cf, size = Builder.VisualBounds(model)
	local width = math.max(size.X, size.Z, size.Y * 0.65, 1)
	local floor = cf.Position.Y - size.Y / 2
	local center = CF(cf.Position.X, floor - width * 0.07, cf.Position.Z)
	local p = part(
		model,
		"BestiaryPlinth",
		V(width * 0.82, width * 0.11, width * 0.82),
		center,
		C(216, 226, 217),
		Enum.Material.Limestone
	)
	p.CFrame *= CFrame.Angles(0, math.pi / 4, 0)
	part(
		model,
		"PlinthInlay",
		V(width * 0.7, width * 0.025, width * 0.7),
		center * CF(0, width * 0.065, 0) * CFrame.Angles(0, math.pi / 4, 0),
		stone,
		Enum.Material.Metal
	)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part(
				model,
				"PlinthKey",
				V(width * 0.08, width * 0.018, width * 0.08),
				center * CF(x * width * 0.32, width * 0.085, z * width * 0.32) * CFrame.Angles(0, math.pi / 4, 0),
				brass,
				Enum.Material.Metal
			)
		end
	end
	return model
end
return G
