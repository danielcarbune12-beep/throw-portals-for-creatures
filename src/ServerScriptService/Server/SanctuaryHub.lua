-- Portal Sanctuary: a composed, walkable lobby, built from the supplied hub reference.
-- Plot centers, throw zone, collision barrier and lane direction retain their existing contracts.
local RS = game:GetService("ReplicatedStorage")
local Config = require(RS.Shared.Config)
local K = require(script.Parent.WorldKit)
local Art = require(script.Parent.SanctuaryArchitecture)
local Hub = {}
local V, CF, A, PI = Vector3.new, CFrame.new, CFrame.Angles, math.pi
local M, C = Enum.Material, Color3.fromRGB
local P = Art.Palette

local function walkable(cf, size, color, material, name)
	local p = K.block(cf, size, color, material, true)
	p.Name, p.CanQuery = name or "SanctuaryPaving", true
	p:SetAttribute("HubWalkable", true)
	return p
end
local function arch(z, width, height, depth)
	local half = width / 2
	local points = {
		V(-half, 2, z),
		V(-half, height * 0.59, z),
		V(-half * 0.83, height * 0.78, z),
		V(-half * 0.43, height * 0.94, z),
		V(0, height, z),
		V(half * 0.43, height * 0.94, z),
		V(half * 0.83, height * 0.78, z),
		V(half, height * 0.59, z),
		V(half, 2, z),
	}
	for i = 1, #points - 1 do
		Art.Beam(points[i], points[i + 1], 4.6, depth, P.ivory, M.Limestone).Name = "ArchStone"
		Art.Beam(
			points[i] + V(0, 0, -depth / 2 - 0.10),
			points[i + 1] + V(0, 0, -depth / 2 - 0.10),
			2.75,
			0.32,
			P.violet,
			M.SmoothPlastic
		)
		Art.Beam(
			points[i] + V(0, 0, -depth / 2 - 0.32),
			points[i + 1] + V(0, 0, -depth / 2 - 0.32),
			0.42,
			0.16,
			P.goldLight,
			M.Metal
		)
	end
	for _, side in ipairs({ -1, 1 }) do
		Art.Column(CF(side * half, 0.9, z), height * 0.56, 3.8)
		Art.Banner(CF(side * half, height * 0.56, z - depth / 2 - 0.40), height * 0.32, 2.1)
		Art.Lantern(CF(side * (half + 3.6), 0.2, z - 3), 1.15, true)
	end
	Art.Crest(CF(0, height + 0.3, z - depth / 2 - 0.55), 8)
	if height > 35 then
		Art.Crystal(CF(0, height - 3, z - depth / 2 - 0.5), 2.1, 7.5, P.lilac)
	end
	return points
end
local function window(cf, w, h)
	K.block(cf, V(w + 0.8, h + 0.8, 0.40), P.gold, M.Metal)
	K.block(cf * CF(0, 0, -0.24), V(w, h, 0.18), C(255, 208, 137), M.SmoothPlastic)
	for _, x in ipairs({ -0.24, 0.24 }) do
		K.block(cf * CF(x * w, 0, -0.37), V(0.17, h, 0.16), P.roof, M.SmoothPlastic)
	end
	K.block(cf * CF(0, 0, -0.38), V(w, 0.18, 0.12), P.roof, M.SmoothPlastic)
	Art.Gable(cf * CF(0, h / 2 + 0.35, -0.06), w + 1.1, 2.4, 0.65, P.gold)
end
local function hall(folder, label)
	local hw, back, front = Config.HallHalfWidth, Config.HallBackZ, Config.BarrierZ
	local middle, depth = (back + front) / 2, front - back
	walkable(CF(0, 0.6, middle), V(hw * 2, 1.2, depth), P.light, M.Limestone, "HallFloor")
	for x = -24, 24, 8 do
		for z = back + 4, front - 3, 8 do
			K.block(CF(x, 1.215, z), V(7.86, 0.03, 7.86), ((x + z) % 3 < 1) and P.ivory or P.light, M.SmoothPlastic)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		K.block(CF(side * (hw - 1.3), 1.24, middle), V(0.34, 0.08, depth - 1), P.gold, M.Metal)
		-- Side bays frame a genuinely open central hall. Roofs stay off the throw/camera axis.
		local x = side * (hw + 10)
		walkable(CF(x, 0.7, middle), V(21, 1.4, depth + 2), P.stone, M.Limestone, "HallBayFoundation")
		K.block(CF(x, 12.5, middle), V(20, 24, depth), P.ivory, M.Limestone, true)
		K.block(CF(x, 4.2, back - 0.6), V(20.5, 3.6, 1.4), P.stone, M.Limestone)
		K.block(CF(x, 24.5, middle), V(22, 1.2, depth + 2), P.gold, M.Metal)
		Art.Gable(CF(x, 25.1, middle), 24, 5.6, depth + 4, P.roof)
		K.block(CF(x, 30.8, middle), V(0.6, 0.55, depth + 5), P.gold, M.Metal)
		for _, z in ipairs({ back + 2, middle, front - 2 }) do
			for _, roofSide in ipairs({ -1, 1 }) do
				Art.Beam(V(x, 30.85, z), V(x + roofSide * 12, 25.25, z), 0.22, 0.28, P.gold, M.Metal)
			end
		end
		for _, z in ipairs({ back + 2, front - 2 }) do
			for _, xx in ipairs({ x - 8, x + 8 }) do
				Art.Column(CF(xx, 0.7, z), 23, 1.8)
			end
		end
		for _, offset in ipairs({ -3.4, 3.4 }) do
			window(CF(x + offset, 13.5, back - 0.62), 4.7, 8)
			window(CF(x + offset, 13.5, front + 0.62) * A(0, PI, 0), 4.7, 8)
		end
		Art.Banner(CF(side * (hw + 0.8), 23, back - 1.25), 12, 2.8)
	end
	arch(back - 0.9, 39, 39, 4.5)
	local launchArch = arch(front + 1.7, 48, 31, 3.2)
	local sign = K.block(CF(0, 28, back - 3.3), V(23, 2.1, 0.3), P.roof, M.SmoothPlastic)
	label(sign, "PORTAL SANCTUARY", P.goldLight, Enum.NormalId.Front)
	-- Compass inlay: large intentional geometric motif, quiet enough for avatars and charge feedback.
	local centerZ = (Config.ThrowZone.minZ + Config.ThrowZone.maxZ) / 2
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		K.block(
			CF(math.sin(a) * 9.8, 1.275, centerZ + math.cos(a) * 9.8) * A(0, a, 0),
			V(8.3, 0.05, 0.24),
			P.gold,
			M.Metal
		)
	end
	for i = -2, 2 do
		local channel = K.block(CF(i * 4.2, 1.29, centerZ), V(0.22, 0.055, 31), P.lilac, M.Neon, false, 0.74)
		channel.Name = "ChargeChannel"
		K.tag(channel, "TPFC_ChargeChannel", { Index = i })
	end
	K.block(CF(0, 1.31, front - 2), V(hw * 2 - 4, 0.06, 0.36), P.goldLight, M.Neon, false, 0.35).Name = "LaunchLine"
	local pad = K.block(
		CF(0, 1.26, centerZ),
		V(hw * 2 - 4, 0.03, Config.ThrowZone.maxZ - Config.ThrowZone.minZ - 2),
		P.lilac,
		M.SmoothPlastic,
		false,
		1
	)
	pad.Name = "ThrowZonePad"
	-- The functional barrier retains its exact plane and broad collision extents.
	local barrier = K.block(CF(0, 60, front), V(Config.StartHalfWidth * 2 + 40, 140, 2), P.lilac, M.ForceField, true, 1)
	barrier.Name, barrier.CanQuery = "Barrier", true
	K.block(CF(0, 1.4, front), V(hw * 2, 0.16, 0.25), P.lilac, M.Neon, false, 0.55).Name = "BarrierGlow"
	-- Fit the launch aperture to the stone arch's actual contour. The sky rings
	-- are separate scenery; no second circular frame crosses the launch opening.
	local gate = Instance.new("Model")
	gate.Name = "SanctuaryAperture"
	K.SetFolder(gate)
	local root = K.block(CF(0, 1.2, front + 1.7), V(0.05, 0.05, 0.05), P.lilac, M.SmoothPlastic, false, 1)
	root.Name, gate.PrimaryPart = "Root", root
	local inset, offset = {}, 2.65
	local function inward(a, b)
		local d = b - a
		return V(d.Y, -d.X, 0).Unit
	end
	for i, point in ipairs(launchArch) do
		local before = inward(launchArch[math.max(1, i - 1)], launchArch[math.max(2, i)])
		local after = inward(launchArch[math.min(i, #launchArch - 1)], launchArch[math.min(i + 1, #launchArch)])
		local miter = (before + after).Unit
		local position = point + miter * (offset / miter:Dot(after))
		if i == 1 or i == #launchArch then
			position = V(position.X, 1.25, position.Z)
		end
		inset[i] = position - V(0, 0, 1.72)
	end
	for i = 1, #inset - 1 do
		local a, b = inset[i], inset[i + 1]
		local trim = Art.Beam(a, b, 0.5, 0.18, P.goldLight, M.Metal)
		trim.Name = "InnerMolding"
		local energy = Art.Beam(a - V(0, 0, 0.12), b - V(0, 0, 0.12), 0.16, 0.07, P.lilac, M.Neon)
		energy.Name, energy.Transparency = "EnergyInlay", 0.62
		K.tag(energy, "TPFC_ChargeChannel", { Index = i })
	end
	gate:SetAttribute("FittedArch", true)
	gate.Parent = folder
	K.SetFolder(folder)
end
local function avenue()
	local depth = Config.StartDepth
	walkable(CF(0, 0.02, -(depth + 36) / 2), V(45, 0.24, depth - 36), P.stone, M.Limestone)
	for row = 0, 49 do
		local z = -41 - row * 8.4
		for col = -2, 2 do
			local tone = ((row * 7 + col * 3) % 5) / 5
			K.block(CF(col * 8.5, 0.16, z), V(8.35, 0.12, 8.23), P.ivory:Lerp(P.light, tone * 0.6), M.SmoothPlastic)
		end
		if row % 10 == 9 then
			task.wait()
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		K.block(CF(side * 22.5, 0.22, -246), V(0.42, 0.12, 420), P.gold, M.Metal)
		K.block(CF(side * 23.6, 0.30, -246), V(1.2, 0.38, 420), P.light, M.Limestone)
		for _, z in ipairs({ -122, -198, -274, -350 }) do
			Art.Planter(CF(side * 26.8, 0, z), 22, z == -198)
			Art.Lantern(CF(side * 25.5, 0, z + 15), 1.2, true)
			local banner = CF(side * 26.5, 10, z - 12) * A(0, side < 0 and -PI / 2 or PI / 2, 0)
			K.block(banner * CF(0, -4.6, 0.15), V(0.35, 10, 0.35), P.roof, M.Metal)
			Art.Banner(banner, 5.2, 1.8)
		end
		for _, z in ipairs({ -84, -160, -236, -312 }) do
			walkable(CF(side * 27, 0.13, z), V(9, 0.32, 13), P.ivory, M.Limestone, "GardenApproach")
			for _, edge in ipairs({ -1, 1 }) do
				K.block(CF(side * 27, 0.33, z + edge * 6.5), V(9, 0.12, 0.30), P.gold, M.Metal)
			end
		end
	end
	for _, z in ipairs({ -62, -198, -350 }) do
		Art.Crest(CF(0, 0.35, z) * A(-PI / 2, 0, 0), 6)
	end
	-- Ceremonial runner: a soft lilac stone band with gold edging breaks up the bare paving and
	-- leads the eye to the hall.
	local runner, runnerEdge = C(205, 196, 218), C(150, 128, 184)
	K.block(CF(0, 0.235, -252), V(12, 0.05, 396), runner, M.Limestone)
	for _, side in ipairs({ -1, 1 }) do
		K.block(CF(side * 6.25, 0.25, -252), V(0.5, 0.06, 396), P.gold, M.Metal)
		K.block(CF(side * 5.2, 0.25, -252), V(0.22, 0.06, 396), runnerEdge, M.SmoothPlastic)
	end
	-- star medallions between each pair of courtyards (and one at the gate)
	for _, z in ipairs({ -84, -160, -236, -312, -388 }) do
		K.block(CF(0, 0.27, z) * A(0, PI / 4, 0), V(10.5, 0.05, 10.5), P.ivory, M.Limestone)
		for i = 0, 3 do
			local a = i / 4 * PI * 2 + PI / 4
			K.block(
				CF(math.sin(a) * 3.7, 0.3, z + math.cos(a) * 3.7) * A(0, a, 0),
				V(10.6, 0.05, 0.36),
				P.gold,
				M.Metal
			)
		end
		K.block(CF(0, 0.31, z) * A(0, PI / 4, 0), V(4.2, 0.05, 4.2), P.violet, M.SmoothPlastic)
		local core = K.block(CF(0, 0.33, z) * A(0, PI / 4, 0), V(1.8, 0.05, 1.8), P.lilac, M.Neon, false, 0.2)
		K.tag(core, "TPFC_Pulse", { Period = 6, Base = 0.35, Peak = 0.05 })
		-- four gold rays from the centre
		for i = 0, 3 do
			local a = i / 4 * PI * 2
			K.block(
				CF(math.sin(a) * 4.2, 0.31, z + math.cos(a) * 4.2) * A(0, a, 0),
				V(0.3, 0.05, 3.2),
				P.goldLight,
				M.Metal
			)
		end
	end
	-- Crystal pylons line the avenue between the courtyards: violet banner, gold collars, a floating
	-- lilac crystal. Tall enough to give the long walk a rhythm without blocking the bases.
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -100, -176, -252, -328, -404 }) do
			local x = side * 24.2
			K.block(CF(x, 0.8, z), V(3.6, 1.6, 3.6), P.stone, M.Limestone, true)
			K.block(CF(x, 1.75, z), V(3.0, 0.3, 3.0), P.gold, M.Metal)
			K.block(CF(x, 8.6, z), V(2.2, 13.4, 2.2), P.ivory, M.Limestone, true)
			for _, y in ipairs({ 5.5, 15.2 }) do
				K.block(CF(x, y, z), V(2.6, 0.35, 2.6), P.gold, M.Metal)
			end
			K.block(CF(x, 15.7, z), V(3.0, 0.7, 3.0), P.light, M.Limestone)
			K.pyramid(CF(x, 16.05, z), 2.4, 1.4, P.gold, M.Metal)
			local cf = CF(x - side * 1.15, 13.6, z) * A(0, side < 0 and PI / 2 or -PI / 2, 0)
			Art.Banner(cf, 6.4, 1.7)
			local gem, gemCore = K.gem(CF(x, 19.6, z) * A(0, PI / 4, 0), 1.7, 3.2, P.lilac, M.Glass, 0.1)
			K.tag(gem, "TPFC_Bob", { Amp = 0.4, Period = 5 + (z % 3), Spin = 18 })
			K.lamp(gemCore, P.lilac, 14, 0.6)
		end
	end
	-- Entrance gate: two tall pylon towers framing the start of the avenue.
	for _, side in ipairs({ -1, 1 }) do
		local x, z = side * 25.5, -444
		K.block(CF(x, 1.2, z), V(7.5, 2.4, 7.5), P.stone, M.Limestone, true)
		K.block(CF(x, 13, z), V(5.2, 22, 5.2), P.ivory, M.Limestone, true)
		for _, y in ipairs({ 2.6, 12, 23.8 }) do
			K.block(CF(x, y, z), V(5.8, 0.5, 5.8), P.gold, M.Metal)
		end
		K.block(CF(x, 24.6, z), V(6.6, 1.2, 6.6), P.light, M.Limestone)
		K.pyramid(CF(x, 25.2, z), 6.2, 5.4, P.roof, M.SmoothPlastic)
		K.block(CF(x, 31.2, z), V(0.6, 1.8, 0.6), P.gold, M.Metal)
		Art.Banner(CF(x - side * 2.75, 21.5, z) * A(0, side < 0 and PI / 2 or -PI / 2, 0), 12, 3.2)
		Art.Banner(CF(x, 21.5, z + 2.75), 12, 3.2)
		Art.Crystal(CF(x, 32, z), 1.6, 5.5, P.lilac)
		Art.Lantern(CF(side * 20.5, 0.2, z + 5), 1.3, true)
	end
end
local function perimeter()
	K.Seed(46021)
	for _, side in ipairs({ -1, 1 }) do
		for i = 0, 10 do
			local z = -49 - i * 36
			local h = 25 + (i * 13 % 23)
			local x = side * 110
			-- Lilac-grey stone like the reference (the old dark slate read as navy under the hub light),
			-- with a grass crown so the walls belong to the gardens.
			local rot = A(0.03, side * 0.13, side * -0.08)
			K.block(CF(x, h / 2 - 2, z) * rot, V(15, h, 39), C(150, 140, 168), M.Limestone)
			K.block(CF(x, h - 1.6, z) * rot, V(13.4, 0.9, 37), P.grass, M.Grass)
			K.block(CF(x - side * 6.9, h - 2.6, z) * rot, V(0.5, 2.2, 30), P.grass, M.Grass)
			K.wedge(
				CF(x - side * 4, h * 0.50, z + 5) * A(0, side * PI / 2, 0),
				V(24, h * 0.65, 13),
				C(170, 160, 184),
				M.Slate
			)
			-- Broken sloped peaks and shallow front facets avoid a flat castle-wall silhouette.
			K.corner(
				CF(x + side * 0.8, h + 0.5, z - 7) * A(0, side * PI / 2, 0),
				V(14, 9 + i % 4, 24),
				C(160, 150, 176),
				M.Slate
			)
			Art.Diamond(
				CF(x - side * 7.9, h * 0.48, z - 4) * A(0, side < 0 and -PI / 2 or PI / 2, -0.22),
				h * 0.66,
				13,
				0.18,
				C(156, 146, 172),
				M.Slate
			)
			K.block(CF(x - side * 5.5, 2.2, z), V(3.2, 3.5, 37), P.ivory, M.Limestone)
			if i % 3 == 1 then
				local cf = CF(x - side * 8.5, h - 1, z) * A(0, side < 0 and -PI / 2 or PI / 2, 0)
				Art.Banner(cf, 14, 4)
				K.block(cf * CF(0, 1.1, 0), V(5.5, 0.5, 1.0), P.gold, M.Metal)
			end
			if i % 2 == 0 then
				K.tree(V(side * 100, 1, z - 14), 1.12, i % 4 == 0 and P.pink or P.leaf, nil, true)
			end
		end
		-- Two real cascades per side (stepped glass sheets + foam), falling into round pools.
		for _, z in ipairs({ -124, -278 }) do
			K.block(CF(side * 102.6, 24, z), V(6, 1.4, 12), P.stone, M.Limestone)
			K.block(CF(side * 102.6, 24.8, z), V(6.4, 0.3, 12.4), P.gold, M.Metal)
			K.waterfall(
				V(side * 100.2, 23.4, z),
				23,
				8,
				side > 0 and PI / 2 or -PI / 2,
				C(150, 222, 236),
				C(236, 250, 255)
			)
			-- small enough to sit in the gap between two courtyards
			K.vcyl(V(side * 99.8, 0.05, z), 0.5, 10, P.ivory, M.Limestone)
			local pool = K.vcyl(V(side * 99.8, 0.2, z), 0.4, 8.6, P.water, M.Glass, false, 0.25)
			K.tag(pool, "TPFC_Glint", { Period = 9 })
		end
		task.wait()
	end
	-- Rear garden closes the composition with an arcade and two skyline pillars.
	for x = -90, 90, 30 do
		Art.Column(CF(x, 0, -452), 23 + (x == 0 and 4 or 0), 3)
		if x < 90 then
			Art.Beam(V(x, 22, -452), V(x + 15, 30, -452), 2.5, 2, P.ivory, M.Limestone)
			Art.Beam(V(x + 15, 30, -452), V(x + 30, 22, -452), 2.5, 2, P.ivory, M.Limestone)
		end
	end
end
local function garden()
	-- Viewer-left looking down +Z is WORLD +X. Keep the asymmetric public fountain on that side.
	walkable(CF(78, 0.12, -22), V(34, 0.28, 36), P.ivory, M.Limestone)
	Art.Fountain(CF(78, 0.3, -22), 1.15, "PublicCrystalFountain")
	K.tree(V(98, 0, -16), 1.05, P.pink, nil, true)
	for _, pos in ipairs({ V(-77, 0, -397), V(-47, 0, -426), V(-20, 0, -399), V(48, 0, -414), V(77, 0, -390) }) do
		K.tree(pos, 1.3, pos.X > 0 and P.pink or P.leaf, nil, true)
	end
	walkable(CF(-48, 0.12, -399), V(44, 0.28, 43), P.ivory, M.Limestone)
	K.vcyl(V(-48, 0.35, -399), 0.18, 20, P.water, M.SmoothPlastic)
	-- Fountain sits above paving; grass edging frames its public garden without sealing walkways.
	for _, z in ipairs({ -378, -420 }) do
		Art.Planter(CF(-48, 0.3, z) * A(0, PI / 2, 0), 32, true)
	end
	local plaza = V(0, 0.25, -389)
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + PI / 4
		Art.Beam(
			plaza + V(math.sin(a) * 10, 0, math.cos(a) * 10),
			plaza + V(math.sin(a + PI / 2) * 10, 0, math.cos(a + PI / 2) * 10),
			0.28,
			0.12,
			P.gold,
			M.Metal
		)
	end
	local stone = K.block(CF(48, 1.6, -397), V(25, 3.2, 25), P.ivory, M.Limestone)
	stone.Name = "SanctuaryMonument"
	Art.Crystal(CF(48, 3.2, -397), 3.8, 12, P.lilac)
	for _, side in ipairs({ -1, 1 }) do
		Art.Crystal(CF(48 + side * 4.8, 3.2, -396) * A(0, 0, -side * 0.18), 2.3, 7, P.mint)
	end
	for _, x in ipairs({ 34, 62 }) do
		Art.Lantern(CF(x, 0, -382), 1.45, true)
	end
end

function Hub.Build(folder, textLabel)
	K.SetFolder(folder)
	K.mirror = false
	folder:SetAttribute("SanctuaryVersion", 2)
	require(RS.Shared.SanctuaryLook).Apply(game:GetService("Lighting"))
	avenue()
	task.wait()
	hall(folder, textLabel)
	task.wait()
	perimeter()
	garden()
	require(script.Parent.SanctuaryDetails).Build(folder)
end
return Hub
