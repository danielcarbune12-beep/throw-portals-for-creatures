-- Detailed, deterministic native biome vignettes for the expedition map.
local Config = require(game.ReplicatedStorage.Shared.Config)
local Scene = {}
local V, C = Vector3.new, Color3.fromRGB
local path = { V(-11, 0.72, -6), V(-6, 0.72, -2), V(0, 0.72, 1), V(6, 0.72, 4), V(10, 0.72, 6) }
function Scene.SetProgress(model, progress)
	local marker = model and model:FindFirstChild("ScoutMarker")
	if not marker then
		return
	end
	local t = math.clamp(progress or 0, 0, 1) * (#path - 1)
	local i = math.min(#path - 1, math.floor(t) + 1)
	marker.CFrame = CFrame.new(path[i]:Lerp(path[i + 1], t - (i - 1)) + V(0, 1.3, 0)) * CFrame.Angles(0.5, 0.8, 0.3)
end
function Scene.Build(id)
	local def = Config.Worlds[id] or Config.Worlds.Forest
	local m = Instance.new("Model")
	m.Name = "Biome_" .. id
	local stone = def.groundColor:Lerp(C(100, 111, 119), 0.65)
	local gold, cream, jade = C(215, 174, 83), C(236, 232, 213), C(61, 139, 110)
	local function part(name, size, pos, color, class)
		local p = Instance.new(class or "Part")
		p.Name, p.Size, p.Position, p.Color = name, size, pos, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	local function block(name, x, y, z, w, h, d, color)
		return part(name, V(w, h, d), V(x, y, z), color)
	end
	local function crystal(x, z, height, color)
		local body = block("Crystal", x, height / 2 + 0.5, z, 1, height, 1, color)
		body.CFrame *= CFrame.Angles(0, 0.6, 0.08)
		local tip = part("CrystalTip", V(1, 1.5, 1), V(x, height + 1, z), color:Lerp(cream, 0.25), "WedgePart")
		tip.CFrame *= CFrame.Angles(0, 0.6, 0)
	end
	local function tree(x, z, height, color, snow)
		block("Trunk", x, height * 0.4, z, 0.55, height * 0.8, 0.55, C(99, 77, 54))
		for level = 1, 2 do
			local w = 3.4 - level * 0.6
			local cap = block("Canopy", x, height * 0.55 + level * 0.8, z, w, 1.35, w, color)
			cap.CFrame *= CFrame.Angles(0, 0.25 * level, 0)
			if snow then
				block("SnowCap", x, height * 0.55 + level * 0.8 + 0.72, z, w + 0.1, 0.18, w + 0.1, cream)
			end
		end
	end
	block("Foundation", 0, -1.3, 0, 28, 2, 18, stone)
	block("StoneStratum", 0, -0.45, 0, 30, 0.6, 20, stone:Lerp(cream, 0.25))
	block("Terrain", 0, 0.05, 0, 30, 0.7, 20, def.groundColor)
	-- Broken cliff skyline with readable rock strata.
	for i = 1, 5 do
		local h = 4 + (i % 3) * 2
		local x = -13 + i * 4.7
		local cliff = part("Cliff", V(4.8, h, 3.6), V(x, h / 2 + 0.4, 8), stone, "WedgePart")
		cliff.CFrame *= CFrame.Angles(0, (i % 2) * math.pi, 0)
		block("CliffRim", x, h + 0.5, 8, 4.4, 0.28, 3.4, def.groundColor)
	end
	for i = 1, 7 do
		local x = -13 + (i * 4) % 25
		local z = -8 + (i * 5) % 14
		local rock = block("Boulder", x, 0.8, z, 0.9 + i % 2, 0.8, 0.9 + i % 2, stone:Lerp(cream, 0.15))
		rock.CFrame *= CFrame.Angles(0.1, i * 0.7, 0.12)
	end
	-- Map route: dashes belong to the actual mission progress indicator.
	for i = 1, #path - 1 do
		for j = 0, 3 do
			local a = path[i]:Lerp(path[i + 1], j / 4)
			local b = path[i]:Lerp(path[i + 1], (j + 0.65) / 4)
			local p = part("RouteDash", V((b - a).Magnitude, 0.08, 0.16), (a + b) / 2, gold)
			p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end
	if id == "Forest" then
		for i = 1, 6 do
			tree(-13 + (i * 5) % 26, -7 + (i * 7) % 14, 3 + i % 3, C(76 + i * 4, 133 + i * 5, 65))
		end
		for i = 1, 5 do
			block("River", -12 + i * 2, 0.44, -3 + i * 0.65, 3.1, 0.12, 1.8, C(83, 171, 184))
		end
		for i = 1, 6 do
			block("BridgePlank", -6.5, 0.75, -3 + i * 0.55, 2, 0.18, 0.42, C(153, 118, 73))
		end
		for i = 1, 8 do
			local tuft = block("Fern", -13 + (i * 7) % 26, 0.65, -8 + (i * 3) % 15, 0.18, 0.65, 0.9, C(102, 156, 76))
			tuft.CFrame *= CFrame.Angles(0, i, 0.2)
		end
	elseif id == "Volcano" then
		for i = 0, 3 do
			local peak = part("VolcanicPeak", V(5, 9, 5), V(1, 4.8, 6), C(67, 59, 61), "WedgePart")
			peak.CFrame *= CFrame.Angles(0, i * math.pi / 2, 0)
		end
		for i = 1, 6 do
			block("LavaChannel", -10 + i * 3, 0.48, -5 + i * 0.7, 3.4, 0.12, 0.8, C(242, 119, 39))
		end
		for i = 1, 5 do
			crystal(-13 + i * 5, 2 + (i % 2) * 3, 1 + i % 3, C(79, 69, 73))
		end
	elseif id == "Frozen" then
		block("FrozenLake", -4, 0.47, -3, 10, 0.13, 6, C(135, 199, 220))
		for i = 1, 6 do
			tree(-13 + (i * 5) % 26, -6 + (i * 7) % 13, 3 + i % 3, C(123, 166, 176), true)
		end
		for i = 1, 5 do
			crystal(-12 + i * 5, 4 + (i % 2) * 2, 2 + i % 2, C(162, 218, 238))
		end
	elseif id == "Crystal" then
		for i = 1, 9 do
			crystal(
				-13 + (i * 4) % 27,
				-7 + (i * 5) % 16,
				2 + i % 4,
				i % 2 == 0 and C(131, 100, 210) or C(96, 184, 199)
			)
		end
		block("CrystalPool", -5, 0.47, -4, 7, 0.12, 4, C(82, 148, 180))
	elseif id == "Candy" then
		for i = 1, 6 do
			local x, z = -13 + i * 4, -5 + (i % 3) * 4
			for band = 1, 4 do
				block(
					"CandyObelisk",
					x,
					0.4 + band * 0.8,
					z,
					1.4,
					0.8,
					1.4,
					band % 2 == 0 and cream or C(164, 112, 148)
				)
			end
			block("BiscuitCap", x, 4.05, z, 2, 0.35, 2, gold)
		end
		block("MintStream", -4, 0.47, -4, 9, 0.12, 2, C(112, 191, 157))
	elseif id == "Space" then
		for i = 1, 7 do
			crystal(-13 + i * 3.8, -6 + (i % 2) * 10, 1 + i % 3, C(130, 143, 166))
		end
		local planet = block("RingedPlanet", -8, 7, 6, 4, 4, 4, C(181, 164, 198))
		planet.Shape = Enum.PartType.Ball
		for i = 0, 11 do
			local angle = i * math.pi / 6
			local ring =
				part("PlanetRing", V(1.3, 0.15, 0.5), V(-8 + math.cos(angle) * 3, 7, 6 + math.sin(angle) * 3), gold)
			ring.CFrame *= CFrame.Angles(0, -angle, 0)
		end
		for i = 1, 4 do
			block("Beacon", -10 + i * 5, 1.9, -5, 1, 3, 1, C(201, 207, 220))
		end
	elseif id == "Shadow" then
		for i = 1, 6 do
			local x, z = -13 + i * 4, -6 + (i % 2) * 11
			block("DeadTrunk", x, 2, z, 0.6, 3.4, 0.6, C(79, 73, 91))
			local branch = block("Branch", x + 0.5, 2.8, z, 0.35, 2, 0.35, C(79, 73, 91))
			branch.CFrame *= CFrame.Angles(0, 0, -0.7)
		end
		for i = 1, 5 do
			crystal(-12 + i * 5, 4 + (i % 2), 2 + i % 3, C(139, 102, 174))
		end
	elseif id == "Heaven" then
		for i = 1, 6 do
			local x, z = -13 + i * 4, -5 + (i % 2) * 9
			block("Column", x, 2.6, z, 0.9, 4.4, 0.9, cream)
			block("ColumnCapital", x, 4.9, z, 1.5, 0.35, 1.5, gold)
			block("ColumnFoot", x, 0.6, z, 1.5, 0.35, 1.5, gold)
		end
		block("SacredPool", -6, 0.47, -4, 8, 0.12, 4, C(154, 206, 197))
	end
	-- Destination shrine, carved stairs and a recoverable-looking relic cache.
	for i = 1, 3 do
		block("ShrineStep", 6, 0.4 + i * 0.2, 4 - i * 0.5, 4.8, 0.35, 2.5 - i * 0.4, cream:Lerp(stone, 0.15))
	end
	for _, x in { 4.5, 7.5 } do
		block("ShrinePillar", x, 2.7, 4, 0.65, 4.3, 0.75, cream)
		block("PillarFoot", x, 0.7, 4, 1, 0.4, 1, gold)
		block("PillarCap", x, 4.9, 4, 1, 0.35, 1, gold)
	end
	block("ArchLintel", 6, 4.9, 4, 3.8, 0.45, 0.8, cream)
	block("PortalVeil", 6, 2.7, 4, 2.35, 3.5, 0.12, id == "Volcano" and C(217, 119, 57) or jade)
	block("RelicPlinth", 10, 0.8, 6, 1.8, 0.6, 1.8, cream)
	local gem = block("BiomeRelic", 10, 1.8, 6, 0.9, 1.2, 0.9, gold)
	gem.CFrame *= CFrame.Angles(0, 0.7, 0.1)
	part("ScoutMarker", V(0.7, 0.7, 0.7), path[1] + V(0, 1.3, 0), gold)
	Scene.SetProgress(m, 0)
	m:SetAttribute("Biome", id)
	return m
end
return Scene
