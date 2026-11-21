-- The eight reference gardens. Cosmetic construction with the original BaseBuilder reference contract.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local K = require(script.Parent.WorldKit)
local Art = require(script.Parent.SanctuaryArchitecture)
local Base = {}
local V, CF, A, PI = Vector3.new, CFrame.new, CFrame.Angles, math.pi
local C, M, P = Color3.fromRGB, Enum.Material, Art.Palette

local function label(parent, text, size, offset, color, distance)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance = size, offset, distance or 45
	gui.LightInfluence, gui.AlwaysOnTop = 0, false
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundTransparency = "Label", UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.RichText, t.Text = Enum.Font.GothamMedium, true, true, text
	t.TextColor3 = color or P.light
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Transparency = 1, 0.25
	stroke.Color = P.roof
	stroke.Parent = t
	t.Parent, gui.Parent = gui, parent
	return t
end
local function ownerLabel(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = face, Vector2.new(600, 120), 0.5
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundTransparency = "Owner", UDim2.fromScale(0.92, 0.80), 1
	t.Position, t.Font, t.TextScaled = UDim2.fromScale(0.04, 0.1), Enum.Font.GothamMedium, true
	t.TextColor3, t.Text = P.light, "UNCLAIMED GARDEN"
	t.Parent, gui.Parent = gui, part
	return t
end

function Base.Build(index)
	local side, row = index <= 4 and -1 or 1, (index - 1) % 4
	local pos = V(side * 63, 0, -84 - row * 76)
	local cf = CFrame.lookAt(pos, V(0, 0, pos.Z))
	local function L(x, y, z)
		return cf * CF(x, y, z)
	end
	local model = Instance.new("Model")
	model.Name = "Base" .. index
	K.SetFolder(model)
	K.mirror = false
	K.Seed(7400 + index)
	local function b(name, size, at, color, mat, collide)
		local p = K.block(at, size, color, mat, collide)
		p.Name = name
		return p
	end
	b("Foundation", V(71, 1.0, 71), L(0, 0.25, 0), P.stone, M.Limestone, true)
	local floor = b("Floor", V(68, 1, 68), L(0, 0.5, 0), P.grass, M.Grass, true)
	floor.CanQuery, model.PrimaryPart = true, floor
	-- Low clipped hedges and pale retaining edges, with a full 20-stud street entrance.
	local function border(at, len)
		b("GardenCoping", V(len, 0.65, 2.7), at * CF(0, 0.9, 0), P.light, M.Limestone)
		b("GardenGoldEdge", V(len, 0.11, 0.18), at * CF(0, 1.28, -1.22), P.gold, M.Metal)
		b("ClippedHedge", V(len - 0.8, 1.55, 1.9), at * CF(0, 2.05, 0), P.leaf, M.SmoothPlastic)
		for x = -len / 2 + 2, len / 2 - 1, 7 do
			b("HedgeTop", V(3.8, 0.55, 2.0), at * CF(x, 3.0, 0), C(103, 157, 69), M.SmoothPlastic)
		end
	end
	border(L(0, 0, 34), 68)
	border(L(-34, 0, 0) * A(0, PI / 2, 0), 68)
	border(L(34, 0, 0) * A(0, PI / 2, 0), 68)
	for _, sd in ipairs({ -1, 1 }) do
		border(L(sd * 22, 0, -34), 24)
	end
	for _, sd in ipairs({ -1, 1 }) do
		Art.Column(L(sd * 8.5, 0.7, -34), 8.3, 2.0)
		Art.Lantern(L(sd * 11, 0.5, -33.8), 0.8, false)
	end
	local sign = b("Sign", V(14, 2.8, 0.65), L(0, 10.4, -34), P.violet, M.SmoothPlastic)
	b("SignGoldCap", V(14.6, 0.3, 0.86), L(0, 12.0, -34), P.gold, M.Metal)
	Art.Crest(L(0, 13.1, -34.2), 2.4)
	local sl, sl2 = ownerLabel(sign, Enum.NormalId.Front), ownerLabel(sign, Enum.NormalId.Back)
	local income = label(sign, "", UDim2.fromScale(10, 1.25), V(0, 2.4, 0), C(204, 229, 182), 48)
	b("GardenWalk", V(6.8, 0.14, 25), L(0, 1.08, -20.5), P.ivory, M.Limestone)
	for _, sd in ipairs({ -1, 1 }) do
		b("WalkInlay", V(0.14, 0.035, 24), L(sd * 3.25, 1.17, -20.5), P.gold, M.Metal)
	end
	-- Two-tier flowing basin and actual multi-facet violet crystal cluster.
	local crystal = Art.Fountain(L(0, 1.0, 0), 0.69, "GardenCrystalFountain")
	crystal.Name = "IncomeCrystal"
	local crystalLabel = label(crystal, "", UDim2.fromScale(9, 1.4), V(0, 3, 0), P.light, 45)
	local slotFolder = Instance.new("Folder")
	slotFolder.Name = "Slots"
	slotFolder.Parent = model
	local slots = {}
	K.SetFolder(slotFolder)
	for i = 1, 24 do
		local a = (i - 1) / 24 * PI * 2 + PI / 2
		local x, z = math.cos(a) * 14, math.sin(a) * 14
		local ring = K.vcyl(L(x, 1.015, z).Position, 0.055, 2.9, C(153, 142, 169), M.SmoothPlastic, false, 0.55)
		ring.Name = "SlotRing" .. i
		local pad = K.vcyl(L(x, 1.05, z).Position, 0.05, 2.5, P.light, M.SmoothPlastic, false, 0.4)
		pad.Name = "Slot" .. i
		pad:SetAttribute("Index", i)
		slots[i] = L(x, 1.1, z)
	end
	K.SetFolder(model)
	-- Square green collect pad, gold corners, restrained world text close to the player.
	local cp = V(-19, 0, -21)
	b("CollectFoundation", V(9.6, 0.45, 9.6), L(cp.X, 1.2, cp.Z), P.ivory, M.Limestone)
	local collect = b("CollectPad", V(8.1, 0.16, 8.1), L(cp.X, 1.53, cp.Z), C(87, 190, 96), M.SmoothPlastic)
	for _, sd in ipairs({ -1, 1 }) do
		for _, zz in ipairs({ -1, 1 }) do
			b("CollectCorner", V(1.3, 0.25, 1.3), L(cp.X + sd * 4.2, 1.48, cp.Z + zz * 4.2), P.gold, M.Metal)
		end
		b(
			"CollectMark",
			V(0.12, 0.035, 5),
			L(cp.X + sd * 1.77, 1.64, cp.Z) * A(0, sd * PI / 4, 0),
			C(216, 249, 185),
			M.Neon
		)
	end
	local collectLabel = label(collect, "$0", UDim2.fromScale(5, 1.25), V(0, 3.0, 0), C(222, 248, 185), 30)
	label(collect, "COLLECT", UDim2.fromScale(4, 0.7), V(0, 1.9, 0), P.light, 24)
	local g = Config.GymOffset
	b("GymFoundation", V(16.4, 0.45, 16.4), L(g.X, 1.15, g.Z), P.ivory, M.Limestone)
	b("GymPad", V(15, 0.14, 15), L(g.X, 1.48, g.Z), C(58, 45, 76), M.SmoothPlastic)
	for _, sd in ipairs({ -1, 1 }) do
		b("GymTrim", V(15.4, 0.10, 0.24), L(g.X, 1.58, g.Z + sd * 7.6), P.gold, M.Metal)
		b("GymTrim", V(0.24, 0.10, 15.4), L(g.X + sd * 7.6, 1.58, g.Z), P.gold, M.Metal)
	end
	local gymSign = b("GymSign", V(0.1, 0.1, 0.1), L(g.X, 8, g.Z + 4), P.light)
	gymSign.Transparency = 1
	local gymLabel = label(gymSign, "GYM", UDim2.fromScale(8, 1.8), V(0, 0, 0), P.goldLight, 42)
	-- Cottage: violet ridge roof, cream gable, framed warm windows and gold eaves.
	local hc = L(-20, 1.0, 24)
	b("CottageFoundation", V(14.6, 0.7, 10.6), hc * CF(0, 0.35, 0), P.stone, M.Limestone, true)
	b("CottageWalls", V(13, 7.5, 9), hc * CF(0, 4.1, 0), C(202, 177, 135), M.SmoothPlastic, true)
	Art.Gable(hc * CF(0, 7.8, 0), 15.5, 5, 11, P.roof)
	Art.Gable(hc * CF(0, 7.8, -4.55), 12.7, 4.1, 0.20, P.ivory)
	for _, sd in ipairs({ -1, 1 }) do
		Art.Beam(
			(hc * CF(0, 12.8, -5.6)).Position,
			(hc * CF(sd * 7.75, 7.8, -5.6)).Position,
			0.38,
			0.40,
			P.gold,
			M.Metal
		)
		b("CottagePillar", V(0.7, 7.6, 0.7), hc * CF(sd * 6.15, 4.1, -4.3), P.ivory, M.Limestone)
		b("WindowFrame", V(2.7, 3.2, 0.32), hc * CF(sd * 3.8, 4.4, -4.65), P.roof, M.SmoothPlastic)
		b("WindowLight", V(2.25, 2.7, 0.12), hc * CF(sd * 3.8, 4.4, -4.86), C(245, 204, 132), M.SmoothPlastic)
		b("WindowMullion", V(0.15, 2.8, 0.14), hc * CF(sd * 3.8, 4.4, -4.96), P.gold, M.Metal)
		b("WindowMullion", V(2.3, 0.15, 0.14), hc * CF(sd * 3.8, 4.4, -4.96), P.gold, M.Metal)
	end
	b("CottageDoor", V(2.5, 5.3, 0.30), hc * CF(0, 3.0, -4.7), P.roof, M.SmoothPlastic)
	Art.Crest(hc * CF(0, 9.2, -4.83), 1.65)
	-- Pond, lily pads and a stepped stone rim. No fake neon water or cloud of sparkles.
	local pc = L(21, 1.10, 23)
	K.vcyl(pc.Position, 0.25, 13.2, P.stone, M.Limestone)
	K.vcyl((pc * CF(0, 0.28, 0)).Position, 0.12, 11.7, P.water, M.SmoothPlastic)
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		b(
			"PondRim",
			V(4.8, 0.38, 0.8),
			pc * CF(math.sin(a) * 6.35, 0.36, math.cos(a) * 6.35) * A(0, a, 0),
			P.light,
			M.Limestone
		)
	end
	for i = 1, 3 do
		local px, pz = 2.6 * math.cos(i * 2), 2.6 * math.sin(i * 2)
		b("LilyPad", V(1.4, 0.10, 1.4), pc * CF(px, 0.42, pz) * A(0, i, 0), P.leaf, M.SmoothPlastic)
		b("LilyFlower", V(0.60, 0.18, 0.60), pc * CF(px, 0.55, pz), P.pink, M.SmoothPlastic)
	end
	K.tree(L(27, 1, 5).Position, 0.72, P.pink, nil, true)
	for _, x in ipairs({ -29, 29 }) do
		Art.Lantern(L(x, 1, 29), 0.85, false)
	end
	local center = b("Center", V(0.1, 0.1, 0.1), L(0, 1, 0), P.ivory)
	center.Transparency = 1
	local decor, gym = Instance.new("Folder"), Instance.new("Folder")
	decor.Name, gym.Name, decor.Parent, gym.Parent = "Decor", "Gym", model, model
	model:SetAttribute("Index", index)
	model:SetAttribute("SanctuaryVersion", 2)
	model.Parent = workspace:FindFirstChild("Bases")
	return {
		index = index,
		model = model,
		cf = cf,
		floor = floor,
		slots = slots,
		slotFolder = slotFolder,
		collect = collect,
		collectLabel = collectLabel,
		incomeLabel = income,
		crystalLabel = crystalLabel,
		signLabels = { sl, sl2 },
		decor = decor,
		gym = gym,
		gymLabel = gymLabel,
		owner = nil,
		training = gym,
		spawnCF = L(0, 4, -28) * A(0, PI, 0),
	}
end
return Base
