-- Small-scale craft for the approved Skyforge courtyard. No extra prompts or
-- physics obstacles are created here; the expedition table owns interaction.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local P = require(script.Parent.SkyforgeStyle)
local Details = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material

local function factory(root, cf)
	return function(name, size, frame, color, material, shape)
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, cf * frame
		p.Color, p.Material = color, material or M.SmoothPlastic
		p.Shape = shape or Enum.PartType.Block
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = size.X * size.Y * size.Z > 28
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = root
		return p
	end
end

function Details.Build(model, cf)
	local root = Instance.new("Folder")
	root.Name = "SkyforgeDetails"
	local part = factory(root, cf)
	local function beam(name, from, to, width, depth, color, material)
		return part(name, V(width, depth, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color, material)
	end
	-- Four rows of individually laid roof courses, split into six staggered tiles.
	local roofSlope = math.atan(3.3 / 9.85)
	for _, side in { -1, 1 } do
		for course = 0, 3 do
			local x = 1.2 + course * 2.4
			local y = 8.8 + 3.3 * (1 - x / 9.85) + 0.10
			for tile = 0, 5 do
				part(
					"VioletRoofTile",
					V(2.48, 0.13, 2.38),
					CF(-20 + side * x, y, 18 + tile * 2.4) * A(0, 0, -side * roofSlope),
					(course + tile) % 3 == 0 and P.roofLight or P.roof
				)
			end
		end
		part("GoldEave", V(0.22, 0.25, 15.8), CF(-20 + side * 9.85, 8.87, 24), P.gold, M.Metal)
		for _, z in { 16.1, 31.9 } do
			beam("GableGoldEdge", V(-20, 12.25, z), V(-20 + side * 9.85, 8.87, z), 0.24, 0.25, P.gold, M.Metal)
		end
		for _, z in { 19, 29 } do
			beam(
				"TimberKneeBrace",
				V(-20 + side * 6.8, 6.1, z),
				V(-20 + side * 4.8, 8.2, z),
				0.40,
				0.42,
				P.wood,
				M.Wood
			)
		end
	end
	part("GoldRidge", V(0.60, 0.40, 16.2), CF(-20, 12.35, 24), P.gold, M.Metal)
	for _, side in { -1, 1 } do
		part("RidgeEnd", V(0.65, 1.45, 0.70), CF(-20, 12.9, 24 + side * 7.9) * A(side * 0.36, 0, 0), P.gold, M.Metal)
	end
	part("LodgeBanner", V(2.3, 3.3, 0.12), CF(-20, 5.3, 29.05), P.roof, M.Fabric)
	part("BannerCrest", V(0.73, 0.73, 0.10), CF(-20, 5.65, 28.95) * A(0, 0, math.pi / 4), P.gold, M.Metal)
	part("BannerCrestInset", V(0.40, 0.40, 0.08), CF(-20, 5.65, 28.87) * A(0, 0, math.pi / 4), P.roof)
	-- Slab joints and cut corners are broad enough to read from the game camera.
	for i = 0, 4 do
		local z = -29.8 + i * 4.4
		part("FlagstoneJoint", V(6.3, 0.016, 0.09), CF(0, 1.085, z) * A(0, i % 2 == 0 and 0.10 or -0.08, 0), P.joint)
	end
	for _, x in { -3.0, 3.0 } do
		part("ThresholdInlay", V(0.16, 0.022, 2.7), CF(x, 1.093, -31), P.gold, M.Metal)
	end
	-- Back-corner trees are rooted inside the old lodge/relic obstacle volumes.
	for _, point in { V(-25.5, 0, 29), V(26.5, 0, 26.2) } do
		part("TimberTreeTrunk", V(0.88, 7.2, 0.88), CF(point.X, 4.6, point.Z), P.timber, M.Wood)
		part("TreeBough", V(2.2, 0.55, 0.55), CF(point.X + 0.5, 7.0, point.Z) * A(0, 0, 0.35), P.wood, M.Wood)
		part("BlockCanopy", V(4.8, 3.4, 4.7), CF(point.X, 10.0, point.Z), P.leaf)
		part("BlockCanopy", V(3.7, 2.9, 3.9), CF(point.X + 2.1, 10.9, point.Z - 0.8), P.leafLight)
		part("BlockCanopy", V(3.4, 2.5, 3.5), CF(point.X - 1.6, 11.4, point.Z + 0.2), P.leaf)
	end
	-- Physical map props. These stay low so they never obscure the expedition UI.
	part("ExpeditionMap", V(7.1, 0.06, 4.5), CF(19, 3.33, -19), P.paper)
	for _, x in { 15.25, 22.75 } do
		part(
			"RolledMap",
			V(4.5, 0.46, 0.46),
			CF(x, 3.53, -19) * A(0, math.pi / 2, 0),
			P.light,
			M.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		for _, z in { -21.2, -16.8 } do
			part(
				"ScrollRod",
				V(0.22, 0.58, 0.58),
				CF(x, 3.53, z) * A(0, math.pi / 2, 0),
				P.wood,
				M.Wood,
				Enum.PartType.Cylinder
			)
		end
	end
	local mapColors = {
		Color3.fromRGB(115, 154, 83),
		Color3.fromRGB(105, 142, 177),
		Color3.fromRGB(147, 119, 168),
		Color3.fromRGB(163, 130, 94),
	}
	for i, point in { V(17, 0, -19.5), V(19.1, 0, -18.7), V(21, 0, -19.9), V(20.8, 0, -17.9) } do
		part("PaintedMapBiome", V(1.5, 0.023, 0.95), CF(point.X, 3.374, point.Z) * A(0, i * 0.26, 0), mapColors[i])
		part("MapPin", V(0.10, 0.47, 0.10), CF(point.X + 0.25, 3.62, point.Z), P.gold, M.Metal)
		part("MapPinFlag", V(0.45, 0.23, 0.05), CF(point.X + 0.48, 3.79, point.Z), P.roof, M.Fabric)
	end
	part("MapCompass", V(0.85, 0.035, 0.85), CF(16.6, 3.405, -17.4) * A(0, math.pi / 4, 0), P.gold, M.Metal)
	part("CompassPointer", V(0.10, 0.027, 0.72), CF(16.6, 3.44, -17.4) * A(0, -0.45, 0), P.roof)
	for i = 0, 5 do
		part("MapRouteDot", V(0.10, 0.025, 0.10), CF(17.8 + i * 0.45, 3.39, -19.6 + i * 0.2), P.joint)
	end
	root:SetAttribute("PartCount", #root:GetChildren())
	root.Parent = model
	return root
end

function Details.RefreshRelics(base, relics)
	local folder = base.model:FindFirstChild("ExpeditionRelics") or Instance.new("Folder")
	folder.Name, folder.Parent = "ExpeditionRelics", base.model
	folder:ClearAllChildren()
	local part = factory(folder, base.cf)
	for i, world in Config.WorldOrder do
		local x = 15.65 + (i - 1) * 0.95
		local found = relics and relics[world] == true
		local pad = part(
			"RelicSocket_" .. world,
			V(0.62, 0.08, 0.62),
			CF(x, 3.51, -16.95),
			found and P.gold or P.stone,
			M.Metal
		)
		pad:SetAttribute("Found", found == true)
		if found then
			local tone = Config.Worlds[world].atmo:Lerp(P.portal, 0.35)
			local gem =
				part("BiomeRelic_" .. world, V(0.35, 0.52, 0.35), CF(x, 3.82, -16.95) * A(0, math.pi / 4, 0), tone)
			gem:SetAttribute("World", world)
		end
	end
	return folder
end

return Details
