-- Small-scale craft for the approved Skyforge courtyard. No extra prompts or
-- physics obstacles are created here; the expedition table owns interaction.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local P = require(script.Parent.SkyforgeStyle)
local Details = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
local C3 = Color3.fromRGB

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
	-- Individually laid roof courses over the lodge gable (geometry from P.lodge), staggered tones.
	local LG = P.lodge
	local lx, lz = LG.x, LG.z
	local top = LG.deck + LG.postH
	local hs = (LG.w + 2.4) / 2 -- half span to the eave
	local len = LG.d + 2 -- ridge length
	local roofSlope = math.atan(LG.rise / hs)
	local courses = math.ceil(hs / 2.4)
	local tiles = math.ceil(len / 2.4)
	for _, side in { -1, 1 } do
		for course = 0, courses - 1 do
			local x = math.min(1.2 + course * 2.4, hs - 1.0)
			local y = top + LG.rise * (1 - x / hs) + 0.10
			for tile = 0, tiles - 1 do
				part(
					"VioletRoofTile",
					V(2.48, 0.14, 2.38),
					CF(lx + side * x, y, lz - len / 2 + 1.2 + tile * (len - 2.4) / math.max(1, tiles - 1)) * A(0, 0, -side * roofSlope),
					(course + tile) % 3 == 0 and P.roofLight or P.roof
				)
			end
		end
		part("GoldEave", V(0.3, 0.3, len + 0.2), CF(lx + side * hs, top + 0.07, lz), P.gold, M.Metal)
		for _, z in { lz - len / 2 + 0.1, lz + len / 2 - 0.1 } do
			beam("GableGoldEdge", V(lx, top + LG.rise + 0.05, z), V(lx + side * hs, top + 0.07, z), 0.3, 0.3, P.gold, M.Metal)
		end
		for _, z in { lz - LG.d / 2 + 1.2, lz + LG.d / 2 - 1.2 } do
			beam(
				"TimberKneeBrace",
				V(lx + side * (LG.w / 2 - 1.2), top - 3.2, z),
				V(lx + side * (LG.w / 2 - 3.4), top - 0.9, z),
				0.5,
				0.5,
				P.wood,
				M.Wood
			)
		end
	end
	part("GoldRidge", V(0.7, 0.5, len + 0.4), CF(lx, top + LG.rise + 0.15, lz), P.gold, M.Metal)
	for _, side in { -1, 1 } do
		-- upswept ridge ends, like the concept's carved finials
		part("RidgeEnd", V(0.75, 2.2, 0.8), CF(lx, top + LG.rise + 0.9, lz + side * (len / 2 - 0.2)) * A(side * 0.45, 0, 0), P.gold, M.Metal)
	end
	-- gable-front pediment: violet panel with a gold diamond, facing the courtyard
	local fz = lz - LG.d / 2 - 1.05
	-- kept short so the Crop Almanac board on the back wall stays visible through the open front
	part("LodgeBanner", V(3.0, 2.2, 0.14), CF(lx, top - 1.5, fz + 0.6), P.roof, M.Fabric)
	part("BannerTrim", V(3.2, 0.2, 0.18), CF(lx, top - 0.35, fz + 0.6), P.gold, M.Metal)
	part("BannerCrest", V(0.8, 0.8, 0.12), CF(lx, top - 1.5, fz + 0.5) * A(0, 0, math.pi / 4), P.gold, M.Metal)
	part("BannerCrestInset", V(0.42, 0.42, 0.1), CF(lx, top - 1.5, fz + 0.42) * A(0, 0, math.pi / 4), P.roof)
	-- warm lantern hanging under the roof
	local lantern = part("LodgeLantern", V(0.9, 1.2, 0.9), CF(lx, top - 1.8, lz), C3(255, 214, 150), M.Neon)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = C3(255, 205, 140), 18, 0.9, lantern
	-- Slab joints and cut corners are broad enough to read from the game camera.
	for i = 0, 4 do
		local z = -29.8 + i * 4.4
		part("FlagstoneJoint", V(6.3, 0.016, 0.09), CF(0, 1.085, z) * A(0, i % 2 == 0 and 0.10 or -0.08, 0), P.joint)
	end
	for _, x in { -3.0, 3.0 } do
		part("ThresholdInlay", V(0.16, 0.022, 2.7), CF(x, 1.093, -31), P.gold, M.Metal)
	end
	-- The concept's back edge: grey rock outcrops with grass caps and blocky trees behind the fence
	-- (local z > 33, on the foundation rim), so the courtyard reads as an enclosed garden.
	local rng = Random.new(cf.Position.Z * 7 + cf.Position.X)
	local function rock(x, z, s)
		local n = rng:NextInteger(2, 3)
		for i = 1, n do
			local w, h, d = rng:NextNumber(2.6, 4.2) * s, rng:NextNumber(2.2, 4.4) * s, rng:NextNumber(2.4, 3.8) * s
			local ox, oz = rng:NextNumber(-1.6, 1.6) * s, rng:NextNumber(-1, 1) * s
			local col = i == 1 and P.rock or P.rockLight
			local yaw, tilt = rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.08, 0.08)
			part("RockOutcrop", V(w, h, d), CF(x + ox, 0.6 + h / 2, z + oz) * A(tilt, yaw, -tilt), col, M.Slate)
			if i == 1 then
				part("RockGrassCap", V(w * 0.82, 0.35, d * 0.82), CF(x + ox, 0.6 + h + 0.12, z + oz) * A(0, yaw, 0), P.grass, M.Grass)
			end
		end
	end
	local function blockTree(x, z, s)
		part("TimberTreeTrunk", V(0.9, 6.4, 0.9) * s, CF(x, 1 + 3.2 * s, z), P.timber, M.Wood)
		part("TreeBough", V(2.2, 0.55, 0.55) * s, CF(x + 0.5 * s, 1 + 5.2 * s, z) * A(0, 0, 0.35), P.wood, M.Wood)
		part("BlockCanopy", V(4.8, 3.4, 4.7) * s, CF(x, 1 + 8.0 * s, z), P.leaf)
		part("BlockCanopy", V(3.7, 2.9, 3.9) * s, CF(x + 2.1 * s, 1 + 8.9 * s, z - 0.8 * s), P.leafLight)
		part("BlockCanopy", V(3.4, 2.5, 3.5) * s, CF(x - 1.6 * s, 1 + 9.4 * s, z + 0.2 * s), P.leaf)
	end
	for _, r in { { -28, 34.2, 1.2 }, { -9, 34.4, 1.0 }, { 8, 34.2, 1.15 }, { 26, 34.4, 1.3 }, { -34.3, 24, 0.9 }, { 34.3, 14, 0.9 } } do
		rock(r[1], r[2], r[3])
	end
	for _, t in { { -20, 34.6, 1.25 }, { 0, 34.8, 1.1 }, { 15, 34.6, 1.3 }, { 31, 33.8, 1.0 }, { -33.8, 30, 1.0 } } do
		blockTree(t[1], t[2], t[3])
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
