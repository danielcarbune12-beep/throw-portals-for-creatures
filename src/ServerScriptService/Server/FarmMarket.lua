-- Two public medieval stalls. Geometry only; the server validates every trade.
local Lettering = require(script.Parent.HeraldicText)
local Market = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local C, M = Color3.fromRGB, Enum.Material

function Market.Build(parent, layout)
	local old = parent:FindFirstChild("FarmMarket")
	if old then
		assert(old:GetAttribute("TPFCGenerated"), "Preserve unowned FarmMarket geometry")
		old:Destroy()
	end
	local market = Instance.new("Model")
	market.Name = "FarmMarket"
	market:SetAttribute("TPFCGenerated", true)
	market:SetAttribute("MarketRevision", 1)
	local function part(owner, name, cf, size, color, material, collide)
		local p = Instance.new("Part")
		p.Name, p.CFrame, p.Size = name, cf, size
		p.Color, p.Material = color, material
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, collide == true, false, collide == true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CastShadow = math.max(size.X, size.Y, size.Z) > 0.5
		p.Parent = owner
		return p
	end
	for _, kind in { "Buy", "Sell" } do
		local stall = Instance.new("Model")
		stall.Name, stall.Parent = kind .. "Stall", market
		local origin = layout[kind]
		local function block(name, at, size, color, material, collide)
			return part(stall, name, origin * at, size, color, material, collide)
		end
		local oak, iron, brass = C(87, 64, 43), C(50, 56, 56), C(162, 126, 65)
		local cloth = kind == "Buy" and C(35, 81, 66) or C(122, 44, 46)
		block("StonePad", CF(0, 0.18, -1.3), V(11, 0.36, 10), C(163, 163, 151), M.Limestone, true)
		block("CounterBase", CF(0, 1.3, 0), V(8.2, 2.3, 3), oak, M.WoodPlanks, true)
		block("CounterTop", CF(0, 2.6, -0.15), V(8.8, 0.25, 3.6), C(121, 91, 56), M.WoodPlanks, true)
		for _, x in { -4.2, 4.2 } do
			for _, z in { -1.6, 1.6 } do
				block("OakPost", CF(x, 3.7, z), V(0.4, 7.1, 0.4), oak, M.Wood, true)
				block("IronPostFoot", CF(x, 0.8, z), V(0.46, 0.6, 0.46), iron, M.Metal)
			end
		end
		for _, side in { -1, 1 } do
			local a, b = V(side * 4.2, 5.4, -1.6), V(side * 2.7, 7.2, -1.6)
			block("OakKneeBrace", CFrame.lookAt((a + b) / 2, b), V(0.25, 0.25, (b - a).Magnitude), oak, M.Wood)
			block("CounterIronStrap", CF(side * 3.5, 1.35, -1.56), V(0.17, 2.3, 0.13), iron, M.Metal)
			for _, y in { 0.55, 1.35, 2.15 } do
				block("BrassRivet", CF(side * 3.5, y, -1.65), V(0.12, 0.12, 0.1), brass, M.Metal)
			end
		end
		for _, side in { -1, 1 } do
			local slope = CF(side * 2.4, 7.3, 0) * A(0, 0, -side * 0.28)
			block("SlateRoof", slope, V(5.2, 0.3, 5.2), C(51, 64, 71), M.Slate)
			for row = -2, 2 do
				block("RoofSeam", slope * CF(0, 0.18, row), V(5.2, 0.06, 0.07), iron, M.Metal)
			end
		end
		block("RoofRidge", CF(0, 8.05, 0), V(0.3, 0.3, 5.4), brass, M.Metal)
		local board = block("TradeSign", CF(0, 6.4, -1.9), V(7.8, 1.5, 0.25), cloth, M.WoodPlanks)
		Lettering.Build(board, kind == "Buy" and "BUY" or "SELL", 1.05).Parent = stall
		for _, x in { -3.65, 3.65 } do
			block("SignIronHanger", CF(x, 6.5, -1.75), V(0.14, 1.9, 0.14), iron, M.Metal)
		end
		for i = -1, 1 do
			local x = i * 2.5
			block("ProduceCrate", CF(x, 2.95, 0), V(2.1, 0.5, 2), oak, M.WoodPlanks)
			for n = 1, 4 do
				local hue = kind == "Buy" and C(205, 180, 119)
					or ({ C(142, 85, 170), C(218, 175, 73), C(110, 157, 88) })[i + 2]
				block(
					kind == "Buy" and "SeedPouch" or "HarvestProduce",
					CF(x + (n % 2 - 0.5) * 0.75, 3.4, (math.floor((n - 1) / 2) - 0.5) * 0.8),
					V(0.65, 0.7, 0.65),
					hue,
					M.SmoothPlastic
				)
			end
		end
		block("Banner", CF(-4.45, 4.5, -1.65), V(0.8, 2.1, 0.12), cloth, M.Fabric)
		local anchor = block(kind .. "Anchor", CF(0, 2.6, -3.1), V(1, 1, 1), brass, M.Metal)
		anchor.Transparency = 1
		anchor:SetAttribute("FarmMarket", kind)
	end
	market.Parent = parent
	return market
end

return Market
