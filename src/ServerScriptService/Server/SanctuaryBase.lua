-- Skyforge Courtyard, matching the owner's approved concept2. Original plot,
-- collection and pet-slot anchors stay compatible with saved player gardens.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local K = require(script.Parent.WorldKit)
local Art = require(script.Parent.SanctuaryArchitecture)
local P = require(script.Parent.SkyforgeStyle)
local Details = require(script.Parent.SkyforgeDetails)
local Base = {}
local V, CF, A, PI = Vector3.new, CFrame.new, CFrame.Angles, math.pi
local M = Enum.Material

local function label(parent, text, size, offset, color, distance)
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance = size, offset, distance or 40
	gui.LightInfluence, gui.AlwaysOnTop = 0, false
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundTransparency = "Label", UDim2.fromScale(1, 1), 1
	t.Font, t.TextScaled, t.RichText, t.Text = Enum.Font.GothamMedium, true, true, text
	t.TextColor3 = color or P.text
	local stroke = Instance.new("UIStroke")
	stroke.Thickness, stroke.Transparency, stroke.Color = 1, 0.25, P.joint
	stroke.Parent = t
	t.Parent, gui.Parent = gui, parent
	return t
end

local function ownerLabel(part, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.CanvasSize, gui.LightInfluence = face, Vector2.new(700, 120), 0
	local t = Instance.new("TextLabel")
	t.Name, t.Size, t.BackgroundTransparency = "Owner", UDim2.fromScale(0.94, 0.8), 1
	t.Position, t.Font, t.TextScaled = UDim2.fromScale(0.03, 0.1), Enum.Font.GothamBold, true
	t.TextColor3, t.Text = P.text, "Available courtyard"
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
	local function b(name, size, frame, color, material, collide)
		local p = K.block(frame, size, color, material, collide)
		p.Name = name
		return p
	end
	local function beam(name, from, to, width, height, color, material)
		local a, z = cf:PointToWorldSpace(from), cf:PointToWorldSpace(to)
		return b(name, V(width, height, (z - a).Magnitude + 0.12), CFrame.lookAt((a + z) / 2, z), color, material)
	end
	local function route(from, to, width)
		return beam("SlateWalk", from, to, width or 3.3, 0.07, P.slate, M.Slate)
	end
	b("Foundation", V(71, 1, 71), L(0, 0.25, 0), P.stone, M.Limestone, true)
	local floor = b("Floor", V(68, 1, 68), L(0, 0.5, 0), P.grass, M.Grass, true)
	floor.CanQuery, model.PrimaryPart = true, floor
	-- Roofless front and low rail bays leave the pets and the courtyard visible.
	local function post(x, z)
		b("BoundaryFooting", V(2.6, 0.45, 2.6), L(x, 1.2, z), P.stone, M.Limestone)
		b("BoundaryPillar", V(1.65, 2.7, 1.65), L(x, 2.75, z), P.pale, M.Limestone, true)
		b("BoundaryGoldCollar", V(1.95, 0.16, 1.95), L(x, 4.18, z), P.gold, M.Metal)
		b("BoundaryCap", V(2.25, 0.27, 2.25), L(x, 4.40, z), P.light, M.Limestone)
	end
	local function fence(from, to)
		for _, y in { 2.0, 3.25 } do
			beam("TimberRail", V(from.X, y, from.Z), V(to.X, y, to.Z), 0.35, 0.40, P.wood, M.Wood)
		end
	end
	for _, sd in { -1, 1 } do
		for _, z in { -33, -16.5, 0, 16.5, 33 } do
			post(sd * 33, z)
		end
		for i = 0, 3 do
			fence(V(sd * 33, 0, -33 + i * 16.5), V(sd * 33, 0, -16.5 + i * 16.5))
		end
		post(sd * 8.5, -33)
		fence(V(sd * 8.5, 0, -33), V(sd * 33, 0, -33))
		post(sd * 16.5, 33)
		fence(V(sd * 16.5, 0, 33), V(sd * 33, 0, 33))
	end
	fence(V(-16.5, 0, 33), V(16.5, 0, 33))
	local sign = b("Sign", V(17, 1.9, 0.35), L(-21, 3.1, -33.1), P.darkWood, M.WoodPlanks)
	b("SignGoldHeader", V(17.2, 0.10, 0.4), L(-21, 4.1, -33.1), P.gold, M.Metal)
	local sl, sl2 = ownerLabel(sign, Enum.NormalId.Front), ownerLabel(sign, Enum.NormalId.Back)
	local income = label(sign, "", UDim2.fromScale(9, 1), V(0, 1.8, 0), P.text, 35)
	b("Approach", V(6.8, 0.08, 25), L(0, 1.025, -20.5), P.slate, M.Slate)
	for _, sd in { -1, 1 } do
		route(V(sd * 3.5, 1.025, -24), V(sd * 13, 1.025, -21))
		route(V(sd * 19, 1.025, -6), V(sd * 19, 1.025, 6))
		route(V(sd * 19, 1.025, 6), V(sd * 10, 1.025, 19))
	end
	route(V(-10, 1.025, 19), V(10, 1.025, 19))
	route(V(-10, 1.025, 19), V(-20, 1.025, 16), 3.8)
	-- The central shrine is a small architectural portal, not a water fountain.
	local shrine = Instance.new("Model")
	shrine.Name = "PortalShrine"
	K.SetFolder(shrine)
	local pedestal = K.vcyl(L(0, 1.0, 0).Position, 0.45, 12.8, P.stone, M.Limestone, true)
	pedestal.Name = "ShrineFoundation"
	K.vcyl(L(0, 1.45, 0).Position, 0.32, 11.5, P.pale, M.Limestone, true)
	K.vcyl(L(0, 1.77, 0).Position, 0.10, 10.8, P.slate, M.Slate)
	for _, sd in { -1, 1 } do
		b("ShrineFoot", V(2.45, 0.48, 2.8), L(sd * 3.5, 2.0, 0), P.stone, M.Limestone)
		for i = 0, 2 do
			b(
				"ShrineAshlar",
				V(1.25, 1.42, 1.65),
				L(sd * 3.5, 2.9 + i * 1.45, 0),
				i % 2 == 0 and P.pale or P.light,
				M.Limestone
			)
		end
		b("ShrineGoldCollar", V(1.48, 0.18, 1.85), L(sd * 3.5, 6.75, 0), P.gold, M.Metal)
	end
	for i = 0, 4 do
		local a, z = i / 5 * PI, (i + 1) / 5 * PI
		beam(
			"ShrineVoussoir",
			V(math.cos(a) * 3.5, 6.1 + math.sin(a) * 2.6, 0),
			V(math.cos(z) * 3.5, 6.1 + math.sin(z) * 2.6, 0),
			0.95,
			1.65,
			i % 2 == 0 and P.pale or P.light,
			M.Limestone
		)
	end
	local portal = K.cyl(L(0, 5.2, 0) * A(0, PI / 2, 0), 0.10, 5.8, P.portal, M.Neon, false, 0.14)
	portal.Name = "SkyforgeAperture"
	K.cyl(L(0, 5.2, -0.065) * A(0, PI / 2, 0), 0.035, 4.6, P.portalDark, M.Neon, false, 0.2)
	for i = 0, 5 do
		local a = i / 6 * PI * 2
		b(
			"PortalRune",
			V(0.16, 0.7, 0.08),
			L(math.cos(a) * 1.95, 5.2 + math.sin(a) * 1.95, -0.10) * A(0, 0, a),
			P.light,
			M.Neon
		)
	end
	b("ShrineCrest", V(0.83, 0.83, 0.20), L(0, 8.75, -0.88) * A(0, 0, PI / 4), P.gold, M.Metal)
	shrine.Parent = model
	K.SetFolder(model)
	local anchor = b("IncomeCrystal", V(0.1, 0.1, 0.1), L(0, 7, 0), P.portal)
	anchor.Transparency = 1
	local crystalLabel = label(anchor, "", UDim2.fromScale(8, 1.1), V(0, 1.7, 0), P.text, 32)
	local slots, slotFolder = {}, Instance.new("Folder")
	slotFolder.Name, slotFolder.Parent = "Slots", model
	K.SetFolder(slotFolder)
	for i = 1, 24 do
		local a = (i - 1) / 24 * PI * 2 + PI / 2
		local x, z, open = math.cos(a) * 14, math.sin(a) * 14, i <= Config.StartSlots
		local ring = K.vcyl(
			L(x, 1.015, z).Position,
			0.055,
			2.9,
			open and P.gold or P.stone,
			M.SmoothPlastic,
			false,
			open and 0.15 or 0.88
		)
		ring.Name = "SlotRing" .. i
		local pad = K.vcyl(L(x, 1.05, z).Position, 0.05, 2.5, P.slate, M.SmoothPlastic, false, open and 0.20 or 0.93)
		pad.Name = "Slot" .. i
		pad:SetAttribute("Index", i)
		slots[i] = L(x, 1.1, z)
	end
	K.SetFolder(model)
	b("CollectFoundation", V(9.6, 0.45, 9.6), L(-19, 1.2, -21), P.stone, M.Limestone)
	b("CollectFrame", V(8.8, 0.13, 8.8), L(-19, 1.45, -21), P.gold, M.Metal)
	local collect = b("CollectPad", V(8.1, 0.16, 8.1), L(-19, 1.53, -21), P.mint, M.SmoothPlastic)
	for _, sd in { -1, 1 } do
		b("CollectChevron", V(0.13, 0.035, 2.8), L(-19 + sd * 0.8, 1.64, -21) * A(0, sd * PI / 4, 0), P.light)
	end
	local collectLabel = label(collect, "$0", UDim2.fromScale(5, 1.2), V(0, 3.0, 0), P.text, 28)
	label(collect, "Collect", UDim2.fromScale(4, 0.65), V(0, 1.9, 0), P.text, 23)
	-- Rear-left lodge: an open timber hall on stone footings, with a broad tiled roof.
	b("LodgeFoundation", V(17, 0.48, 12.8), L(-20, 1.2, 24), P.stone, M.Limestone, true)
	for i = 0, 7 do
		b(
			"LodgeDeckBoard",
			V(1.95, 0.17, 11.5),
			L(-26.85 + i * 1.96, 1.52, 24),
			i % 2 == 0 and P.timber or P.wood,
			M.WoodPlanks
		)
	end
	b("LodgeStep", V(6.0, 0.18, 1.4), L(-20, 1.11, 16.8), P.pale, M.Limestone)
	for _, x in { -27, -13 } do
		for _, z in { 19, 29 } do
			b("LodgeStoneFoot", V(1.8, 0.75, 1.8), L(x, 1.8, z), P.pale, M.Limestone)
			b("LodgeTimberPost", V(0.85, 6.4, 0.85), L(x, 5.25, z), P.timber, M.Wood, true)
			b("PostBrassShoe", V(0.98, 0.16, 0.98), L(x, 2.15, z), P.gold, M.Metal)
		end
		b("LodgeSideRafter", V(0.85, 0.8, 11.5), L(x, 8.1, 24), P.wood, M.Wood)
	end
	for _, z in { 19, 29 } do
		b("LodgeCrossRafter", V(15.7, 0.9, 0.8), L(-20, 8.2, z), P.wood, M.Wood)
	end
	for i = 0, 4 do
		b("LodgeRearPanel", V(2.6, 5.7, 0.35), L(-25.4 + i * 2.7, 4.7, 29.35), P.timber, M.WoodPlanks)
	end
	Art.Gable(L(-20, 8.8, 24), 19.7, 3.3, 15.7, P.roof)
	-- Rear-right floating relic pavilion sits on the original pond exclusion area.
	b("RelicRockBase", V(11.4, 1.9, 10.4), L(21, 1.95, 23) * A(0, 0.10, 0), P.stone, M.Slate, true)
	b("RelicRockTier", V(9.6, 1.1, 9.0), L(21, 3.0, 23) * A(0, -0.10, 0), P.pale, M.Limestone)
	b("RelicMossCap", V(8.8, 0.25, 8.1), L(21, 3.67, 23), P.grass, M.Grass)
	for i = 0, 2 do
		b("RelicSteps", V(3.8, 0.32, 1.2), L(21, 1.2 + i * 0.55, 16.6 + i * 1.0), P.pale, M.Limestone)
	end
	for _, x in { 17.7, 24.3 } do
		for _, z in { 19.7, 26.3 } do
			b("RelicColumnFoot", V(1.65, 0.30, 1.65), L(x, 3.95, z), P.gold, M.Metal)
			b("RelicColumn", V(0.92, 3.9, 0.92), L(x, 6.05, z), P.pale, M.Limestone)
			b("RelicCapital", V(1.45, 0.26, 1.45), L(x, 8.1, z), P.gold, M.Metal)
		end
	end
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		b(
			"RelicOpenCanopy",
			V(3.0, 0.28, 0.65),
			L(21 + math.sin(a) * 3.7, 8.45, 23 + math.cos(a) * 3.7) * A(0, a, 0),
			P.gold,
			M.Metal
		)
	end
	local relicCore = b("FloatingRelic", V(1.8, 1.9, 1.8), L(21, 6.7, 23) * A(0, PI / 4, 0), P.portal, M.SmoothPlastic)
	K.pyramid(L(21, 7.65, 23) * A(0, PI / 4, 0), 1.8, 1.2, P.portal, M.SmoothPlastic)
	K.pyramid(L(21, 5.75, 23) * A(PI, PI / 4, 0), 1.8, 0.7, P.roofLight, M.SmoothPlastic)
	relicCore:SetAttribute("SkyforgeRelic", true)
	-- Front-right map station replaces the old workout bench entirely.
	local expeditionTable = Instance.new("Model")
	expeditionTable.Name = "ExpeditionTable"
	K.SetFolder(expeditionTable)
	b("ExpeditionFoundation", V(15.8, 0.35, 15.8), L(19, 1.2, -19), P.pale, M.Limestone)
	b("ExpeditionSlateInset", V(14.7, 0.11, 14.7), L(19, 1.43, -19), P.slate, M.Slate)
	for _, x in { 15.8, 22.2 } do
		for _, z in { -20.9, -17.1 } do
			b("MapTableLeg", V(0.60, 1.62, 0.60), L(x, 2.15, z), P.timber, M.Wood, true)
			b("MapLegCollar", V(0.72, 0.12, 0.72), L(x, 1.55, z), P.gold, M.Metal)
		end
	end
	b("MapTableTop", V(8.6, 0.32, 5.8), L(19, 3.05, -19), P.wood, M.WoodPlanks, true)
	for _, sd in { -1, 1 } do
		b("MapTableEdge", V(8.7, 0.16, 0.20), L(19, 3.27, -19 + sd * 2.8), P.gold, M.Metal)
		b("MapTableEdge", V(0.20, 0.16, 5.5), L(19 + sd * 4.2, 3.27, -19), P.gold, M.Metal)
	end
	for _, sd in { -1, 1 } do
		b("DeparturePostFoot", V(1.4, 0.40, 1.4), L(19 + sd * 3.5, 1.7, -13.6), P.stone, M.Limestone)
		b("DepartureArchPost", V(0.8, 3.6, 0.8), L(19 + sd * 3.5, 3.7, -13.6), P.pale, M.Limestone)
		beam("DepartureArchShoulder", V(19 + sd * 3.5, 5.5, -13.6), V(19, 7.0, -13.6), 0.85, 0.75, P.pale, M.Limestone)
	end
	b("DepartureCrest", V(0.70, 0.70, 0.16), L(19, 6.85, -14.04) * A(0, 0, PI / 4), P.gold, M.Metal)
	expeditionTable.Parent = model
	K.SetFolder(model)
	local expeditionAnchor = b("ExpeditionAnchor", V(0.2, 0.2, 0.2), L(19, 2, -19), P.paper)
	expeditionAnchor.Transparency = 1
	local gymLabel = label(expeditionAnchor, "Expeditions", UDim2.fromScale(6.5, 0.9), V(0, 5.9, 0), P.text, 26)
	local center = b("Center", V(0.1, 0.1, 0.1), L(0, 1, 0), P.pale)
	center.Transparency = 1
	local decor, gym = Instance.new("Folder"), Instance.new("Folder")
	decor.Name, gym.Name, decor.Parent, gym.Parent = "Decor", "ExpeditionLegacy", model, model
	Details.Build(model, cf)
	model:SetAttribute("Index", index)
	model:SetAttribute("SanctuaryVersion", 5)
	model:SetAttribute("BaseStyle", "SkyforgeCourtyard")
	model.Parent = workspace:FindFirstChild("Bases")
	local base = {
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
		expeditionAnchor = expeditionAnchor,
		spawnCF = L(0, 4, -28) * A(0, PI, 0),
	}
	Details.RefreshRelics(base, {})
	return base
end

return Base
