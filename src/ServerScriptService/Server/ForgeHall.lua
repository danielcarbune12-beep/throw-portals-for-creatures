-- Central, four-way hall. Owned geometry is rebuilt in bounded batches.
local RS = game:GetService("ReplicatedStorage")
local Collection = game:GetService("CollectionService")
local Knight = require(RS.Shared.GuideKnight)
local Lettering = require(script.Parent.HeraldicText)
local Hall = {}
local V, CF, A = Vector3.new, CFrame.new, CFrame.Angles
local C, M = Color3.fromRGB, Enum.Material
local stone, pale, dark, slate = C(132, 136, 128), C(202, 195, 173), C(48, 55, 52), C(55, 69, 74)
local oak, brass, jade = C(83, 61, 40), C(183, 145, 73), C(36, 91, 75)

function Hall.Build(parent)
	local previous = parent:FindFirstChild("GreatForgeHall")
	if previous then
		previous:Destroy()
	end
	local hall = Instance.new("Model")
	hall.Name = "GreatForgeHall"
	hall:SetAttribute("TPFCGenerated", true)
	hall:SetAttribute("HallStyle", "MedievalForge")
	hall.Parent = parent
	local batch, count = Instance.new("Folder"), 0
	batch.Name = "Stonework"
	local function flush()
		if count == 0 then
			return
		end
		batch.Parent = hall
		task.wait()
		batch, count = Instance.new("Folder"), 0
		batch.Name = "Craftwork"
	end
	local function part(name, size, cf, color, material, collide, shape)
		local p = Instance.new(shape == "wedge" and "WedgePart" or "Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Material = material or M.Cobblestone
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, collide == true, collide == true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = batch
		count += 1
		if count >= 96 then
			flush()
		end
		return p
	end
	local function at(x, y, z)
		return CF(x, y, z - 236)
	end
	local function beam(name, a, b, thick, color, material)
		return part(name, V(thick, thick, (b - a).Magnitude + 0.15), CFrame.lookAt((a + b) / 2, b), color, material)
	end
	local function arch(z, radius, spring, rise)
		for i = 0, 11 do
			local a, b = i / 12 * math.pi, (i + 1) / 12 * math.pi
			beam(
				"VaultRib",
				V(math.cos(a) * radius, spring + math.sin(a) * rise, z),
				V(math.cos(b) * radius, spring + math.sin(b) * rise, z),
				1.25,
				pale,
				M.Limestone
			)
		end
	end
	local function lantern(x, y, z)
		part("LanternBracket", V(0.5, 0.5, 2), CF(x, y + 0.7, z), dark, M.Metal)
		local core = part("LanternGlass", V(0.9, 1.4, 0.9), CF(x, y, z + 0.7), C(255, 199, 114), M.Neon)
		for _, dy in { -0.8, 0.8 } do
			part("LanternCap", V(1.25, 0.16, 1.25), CF(x, y + dy, z + 0.7), brass, M.Metal)
		end
		for _, dx in { -0.5, 0.5 } do
			part("LanternCage", V(0.1, 1.7, 0.1), CF(x + dx, y, z + 0.18), dark, M.Metal)
		end
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = C(255, 203, 130), 19, 1.3, false
		light.Parent = core
	end
	part("HallFoundation", V(44, 0.4, 70), at(0, 0.35, 0), stone, M.Slate, true)
	for row = -4, 4 do
		for col = -2, 2 do
			part(
				"WornFloorSlab",
				V(8.55, 0.08, 7.6),
				at(col * 8.6, 0.6, row * 7.65),
				(row + col) % 3 == 0 and pale or stone,
				M.Limestone
			)
		end
	end
	-- A cross-shaped clear route preserves the avenue and both courtyard approaches.
	for _, side in { -1, 1 } do
		part("ProcessionalInlay", V(0.18, 0.06, 68), at(side * 5, 0.67, 0), brass, M.Metal)
		part("TranseptInlay", V(43, 0.06, 0.18), at(0, 0.67, side * 5), brass, M.Metal)
		for _, dz in { -24, -12, 12, 24 } do
			local x = side * 20.5
			part("PierFoot", V(3.4, 1.3, 3.5), at(x, 1.2, dz), dark, M.Slate)
			part("StonePier", V(2.1, 21, 2.25), at(x, 11.7, dz), stone, M.Cobblestone, true)
			part("PierCapital", V(3.3, 0.8, 3.4), at(x, 22.3, dz), pale, M.Limestone)
			part("Buttress", V(1.5, 12, 3.5), at(side * 22.1, 6.5, dz), stone, M.Cobblestone)
		end
		for _, dz in { -21, 21 } do
			part("SideWall", V(1.4, 13, 25), at(side * 21, 7.1, dz), stone, M.Cobblestone, true)
			part("WallStringCourse", V(1.9, 0.35, 25.8), at(side * 21, 13.9, dz), pale, M.Limestone)
			local glass = part("ClerestoryGlass", V(0.13, 7.1, 7), at(side * 20.9, 18.1, dz), C(135, 168, 155), M.Glass)
			glass.Transparency = 0.5
			for n = -1, 1 do
				part("WindowMullion", V(0.22, 7.3, 0.15), at(side * 20.7, 18.1, dz + n * 2.2), brass, M.Metal)
			end
			part("WindowTransom", V(0.22, 0.15, 7.4), at(side * 20.7, 18, dz), brass, M.Metal)
		end
		-- Slate roof slopes leave a narrow central daylight opening.
		local a, b = V(side * 2.3, 40, -236), V(side * 23.3, 26, -236)
		local mid, length = (a + b) / 2, (b - a).Magnitude
		local roof =
			part("SlateRoof", V(length, 0.8, 74), CF(mid) * A(0, 0, -side * math.atan2(14, 21)), slate, M.Slate)
		roof.CastShadow = true
		for _, z in { -270, -258, -246, -226, -214, -202 } do
			beam("TimberRafter", V(side * 2, 39.7, z), V(side * 23, 25.7, z), 0.55, oak, M.Wood)
		end
		part("EaveFascia", V(0.6, 1.4, 75), at(side * 23.3, 25.7, 0), oak, M.Wood)
		part("RidgeTrim", V(0.22, 0.4, 75), at(side * 2.2, 40.2, 0), brass, M.Metal)
	end
	for _, z in { -270, -258, -236, -214, -202 } do
		arch(z, 20.5, 22, 12)
	end
	for _, z in { -271, -201 } do
		for _, side in { -1, 1 } do
			part("GatePier", V(4.3, 23, 4), CF(side * 13, 12, z), stone, M.Cobblestone, true)
			part("GateFoot", V(5.2, 1.4, 4.8), CF(side * 13, 1.2, z), dark, M.Slate)
			part("JadeBanner", V(3.1, 10.5, 0.16), CF(side * 13, 16.6, z + 2.1), jade, M.Fabric)
			part("BannerHem", V(3.1, 0.3, 0.22), CF(side * 13, 11.5, z + 2.1), brass, M.Metal)
			part(
				"BannerSigil",
				V(1.05, 1.05, 0.2),
				CF(side * 13, 17.8, z + 2.25) * A(0, 0, math.pi / 4),
				brass,
				M.Metal
			)
			lantern(side * 8.7, 7, z + 0.4)
		end
		arch(z, 10.8, 19, 9)
	end
	local sign = part("GreatHallSign", V(24, 3.2, 0.5), CF(0, 29.4, -198.6) * A(0, math.pi, 0), oak, M.Wood)
	Lettering.Build(sign, "GREAT FORGE", 2.2)
	for _, target in { "Gold", "Ruby" } do
		local x, color = target == "Gold" and -12 or 12, target == "Gold" and C(223, 170, 64) or C(164, 44, 58)
		part(target .. "Dais", V(9, 0.8, 11), CF(x, 1.05, -251), dark, M.Slate)
		part("ForgeHearth", V(6, 3, 4), CF(x, 2.2, -255), dark, M.Cobblestone, true)
		local coals = part("HotCoals", V(4.7, 0.18, 2.6), CF(x, 3.8, -255), C(239, 126, 42), M.Neon)
		part("Chimney", V(3, 19, 2.5), CF(x, 14, -257), stone, M.Brick)
		part("ChimneyCap", V(4.3, 0.7, 3.8), CF(x, 24, -257), pale, M.Limestone)
		part("AnvilFoot", V(1.7, 1.4, 2), CF(x, 1.8, -249), dark, M.Metal)
		part("Anvil", V(4.2, 0.7, 1.8), CF(x, 2.85, -249), C(91, 97, 91), M.Metal, true)
		part(
			"AnvilHorn",
			V(1.5, 0.65, 1.5),
			CF(x + 2.6, 2.85, -249) * A(0, 0, math.pi / 2),
			dark,
			M.Metal,
			false,
			"wedge"
		)
		part("SmithHammer", V(1.2, 0.6, 0.7), CF(x - 0.7, 3.45, -249), brass, M.Metal)
		part("HammerHandle", V(0.2, 0.2, 2.2), CF(x - 0.7, 3.4, -248.5), oak, M.Wood)
		local stationSign =
			part(target .. "Sign", V(7.8, 1.9, 0.3), CF(x, 7.4, -255.4) * A(0, math.pi, 0), dark, M.Wood)
		Lettering.Build(stationSign, string.upper(target), 1.3)
		for i = 1, 5 do
			part(
				"MaterialOffering",
				V(0.65, 0.65, 0.65),
				CF(x - 2.4 + (i - 1) * 1.2, 1.8, -246.4) * A(0, 0, math.pi / 4),
				color,
				target == "Gold" and M.Metal or M.Glass
			)
		end
		local anchor = part(target .. "Station", V(1, 1, 1), CF(x, 2, -251), color, M.SmoothPlastic)
		anchor.Transparency = 1
		anchor:SetAttribute("ForgeTarget", target)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = C(255, 184, 97), 15, 1.4
		glow.Parent = coals
		local ember = Instance.new("ParticleEmitter")
		ember.Name = "HearthEmbers"
		ember.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		ember.Color, ember.Rate = ColorSequence.new(C(255, 180, 80)), 3
		ember.Lifetime, ember.Speed = NumberRange.new(0.7, 1.3), NumberRange.new(1, 2)
		ember.Size, ember.Transparency = NumberSequence.new(0.12), NumberSequence.new(0.2, 1)
		ember:SetAttribute("BaseRate", 3)
		ember.Parent = coals
		Collection:AddTag(ember, "TPFC_EnvironmentEmitter")
		lantern(x, 9, -244)
	end
	for _, side in { -1, 1 } do
		part("SupplyChest", V(3.8, 2.3, 2.7), at(side * 16, 1.8, 24), oak, M.WoodPlanks)
		for _, dx in { -1.2, 1.2 } do
			part("ChestStrap", V(0.25, 2.4, 2.8), at(side * 16 + dx, 1.8, 24), dark, M.Metal)
		end
		for i = 0, 2 do
			part("IronStock", V(0.5, 0.3, 4.3), at(side * 17, 1.1 + i * 0.32, 17), dark, M.Metal)
		end
	end
	part("KnightPlinth", V(4, 0.5, 4), CF(-8, 0.45, -193), pale, M.Limestone, true)
	flush()
	batch:Destroy()
	local knight = Knight.Build()
	knight:PivotTo(CF(-8, 0.7, -193) * A(0, math.pi, 0))
	knight.Parent = hall
	return hall
end
return Hall
