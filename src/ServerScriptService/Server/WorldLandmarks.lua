-- WorldLandmarks: construction kit + the hero landmarks for the hub, launch hall and all
-- eight biomes (blocky architectural language from the map reference pack).
-- Location: ServerScriptService > Server > WorldLandmarks (ModuleScript)
--
-- RULES (from the map brief):
--  * Landing X is clamped to [-30, 30]. Everything taller than ~0.4 studs stays at |X| >= 44,
--    and nothing hangs over the corridor. Landing rays only hit Terrain (GameServer contract),
--    so decorative parts can never become the floor; all parts here are CanQuery = false.
--  * Each biome: ONE main landmark, two supporting forms, a quiet reveal foreground.
--  * Deterministic per-biome Random seeds -> rebuilding never drifts the layout.
--  * Motion is NOT done here: parts are tagged (CollectionService) and the client WorldFx
--    scheduler animates nearby tagged parts at a low rate.

local CollectionService = game:GetService("CollectionService")

local L = {}
local PI = math.pi
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local function C(r, g, b) return Color3.fromRGB(r, g, b) end
local M = Enum.Material

local parentFolder -- current output folder (set by WorldBuilder)
local terrain
local rng = Random.new(1)

function L.SetFolder(f) parentFolder = f end
function L.SetTerrain(t) terrain = t end
function L.Seed(n) rng = Random.new(n) end

---------------------------------------------------------------- kit primitives
local function part(class, size, cf, color, mat, collide, transp)
	local p = Instance.new(class)
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or M.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 6
	p.Parent = parentFolder
	return p
end
local function block(cf, size, color, mat, collide, transp) return part("Part", size, cf, color, mat, collide, transp) end
local function wedge(cf, size, color, mat, collide, transp) return part("WedgePart", size, cf, color, mat, collide, transp) end
local function corner(cf, size, color, mat) return part("CornerWedgePart", size, cf, color, mat) end
local function ballP(pos, d, color, mat, transp)
	local p = part("Part", V3(d, d, d), CF(pos), color, mat, false, transp)
	p.Shape = Enum.PartType.Ball
	return p
end
local function cylP(cf, len, d, color, mat, transp) -- axis along cf X
	local p = part("Part", V3(len, d, d), cf, color, mat, false, transp)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function vcylP(pos, h, d, color, mat, transp)
	return cylP(CF(pos + V3(0, h / 2, 0)) * ANG(0, 0, PI / 2), h, d, color, mat, transp)
end
local function light(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 1.2; l.Shadows = false; l.Parent = p
	return l
end
local function tag(p, name, attrs)
	CollectionService:AddTag(p, name)
	for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
	return p
end
L.block, L.wedge, L.ball, L.light, L.tag = block, wedge, ballP, light, tag

-- pyramid cap made of 4 wedges (base centred at cf, pointing up)
local function pyramid(cf, w, h, color, mat)
	for i = 0, 3 do
		wedge(cf * ANG(0, i * PI / 2, 0) * CF(0, h / 2, -w / 4), V3(w, h, w / 2), color, mat)
	end
end
-- simple block arch: two piers + segmented top
local function arch(cf, span, h, thick, color, mat, trim)
	for s = -1, 1, 2 do block(cf * CF(s * span / 2, h / 2, 0), V3(thick, h, thick), color, mat, true) end
	local r = span / 2
	for i = 1, 9 do
		local a0, a1 = (i - 1) / 9 * PI, i / 9 * PI
		local p0, p1 = V3(math.cos(a0) * r, h + math.sin(a0) * r * 0.6, 0), V3(math.cos(a1) * r, h + math.sin(a1) * r * 0.6, 0)
		local mid = (p0 + p1) / 2
		local dir = p1 - p0
		block(cf * CF(mid) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude + 0.3, thick * 0.8, thick), color, mat)
		if trim then block(cf * CF(mid + V3(0, 0, -thick * 0.52)) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude, 0.35, 0.2), trim, M.Neon) end
	end
end
-- jagged layered rock mass (blocky geology): tapered rotated tiers
local function rockMass(pos, w, h, d, col, mat, tiers)
	tiers = tiers or 4
	local y = 0
	for i = 0, tiers - 1 do
		local k = 1 - i / tiers
		local th = h / tiers * (1 + rng:NextNumber(-0.15, 0.25))
		block(CF(pos + V3(rng:NextNumber(-1, 1) * w * 0.08, y + th / 2, rng:NextNumber(-1, 1) * d * 0.08)) * ANG(rng:NextNumber(-0.06, 0.06), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.08, 0.08)),
			V3(w * (0.35 + 0.65 * k), th, d * (0.35 + 0.65 * k)), col:Lerp(C(0, 0, 0), i * 0.04), mat or M.Slate, true)
		y += th * 0.92
	end
	return y
end
-- blocky canopy group (several overlapping slabs) — tagged for gentle wind sway
local function canopy(pos, s, cols)
	for i = 1, 5 do
		local off = V3(rng:NextNumber(-1, 1) * 4 * s, rng:NextNumber(0, 1) * 3 * s, rng:NextNumber(-1, 1) * 4 * s)
		local b = block(CF(pos + off) * ANG(0, rng:NextNumber(0, PI), 0), V3(rng:NextNumber(7, 11), rng:NextNumber(4, 6), rng:NextNumber(7, 11)) * s,
			cols[(i % #cols) + 1], M.Grass)
		tag(b, "TPFC_Sway", { Amp = 0.012, Period = rng:NextNumber(5, 8) })
	end
end
-- four blocky tree silhouettes (variant 1..4)
local function tree(pos, s, variant, cols)
	local trunk = C(110, 78, 50)
	if variant == 1 then -- round broadleaf
		block(CF(pos + V3(0, 4 * s, 0)), V3(1.6, 8, 1.6) * s, trunk, M.Wood, true)
		canopy(pos + V3(0, 10 * s, 0), s * 0.8, cols)
	elseif variant == 2 then -- tall stacked conifer-ish
		block(CF(pos + V3(0, 3 * s, 0)), V3(1.4, 6, 1.4) * s, trunk, M.Wood, true)
		for i = 0, 3 do block(CF(pos + V3(0, (6 + i * 3) * s, 0)) * ANG(0, i * 0.4, 0), V3(9 - i * 2, 3, 9 - i * 2) * s, cols[1]:Lerp(C(20, 60, 30), 0.25), M.Grass) end
	elseif variant == 3 then -- wide umbrella
		block(CF(pos + V3(0, 5 * s, 0)), V3(1.8, 10, 1.8) * s, trunk, M.Wood, true)
		for k = -1, 1, 2 do block(CF(pos + V3(k * 2 * s, 9 * s, 0)) * ANG(0, 0, k * 0.6), V3(1, 5, 1) * s, trunk, M.Wood) end
		block(CF(pos + V3(0, 12 * s, 0)), V3(16, 3, 13) * s, cols[2] or cols[1], M.Grass)
	else -- pale birch with two small crowns
		block(CF(pos + V3(0, 6 * s, 0)), V3(1.1, 12, 1.1) * s, C(225, 222, 210), M.Wood, true)
		block(CF(pos + V3(1.5 * s, 11 * s, 0)), V3(6, 4, 6) * s, cols[3] or cols[1], M.Grass)
		block(CF(pos + V3(-1.5 * s, 14 * s, 0.5 * s)), V3(5, 4, 5) * s, cols[4] or cols[1], M.Grass)
	end
end
local function crystal(base, len, w, col, tilt, glow)
	local cf = CF(base) * tilt
	local body = block(cf * CF(0, len * 0.31, 0) * ANG(0, PI / 4, 0), V3(w, len * 0.62, w), col, glow and M.Neon or M.Glass, false, glow and 0 or 0.08)
	pyramid(cf * CF(0, len * 0.62, 0) * ANG(0, PI / 4, 0), w, len * 0.38, col:Lerp(C(255, 255, 255), 0.2), M.Glass)
	return body
end
local function crystalFan(pos, s, cols, facing)
	for i = -3, 3 do
		local c = crystal(pos + V3(i * 2.2 * s, 0, 0), (10 - math.abs(i) * 2.2) * s, 2.4 * s, cols[(i + 4) % #cols + 1], ANG(0, facing or 0, 0) * ANG(-0.15, 0, -i * 0.16), i == 0)
		if i == 0 then tag(c, "TPFC_Pulse", { Period = 3, Base = 0, Peak = 0.35 }) end
	end
end
local function column(pos, h, w, col, mat, capCol)
	block(CF(pos + V3(0, 0.6, 0)), V3(w * 1.5, 1.2, w * 1.5), col, mat, true)
	block(CF(pos + V3(0, h / 2, 0)), V3(w, h, w), col, mat, true)
	block(CF(pos + V3(0, h + 0.6, 0)), V3(w * 1.5, 1.2, w * 1.5), capCol or col, mat)
end
local function rune(cf, w, h, col)
	local r = block(cf, V3(w, h, 0.25), col, M.Neon, false, 0.1)
	tag(r, "TPFC_Pulse", { Period = rng:NextNumber(9, 15), Base = 0.75, Peak = 0.1 })
	return r
end

-- side position helper: keeps scenery out of the landing corridor (|X| >= 44)
local function sideX(sign, near, far) return sign * rng:NextNumber(near or 46, far or 66) end

---------------------------------------------------------------- organic kit (curved forms for the hub)
local function ellipsoid(cf, size, color, mat, transp)
	local p = part("Part", size, cf, color, mat, false, transp)
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	return p
end
L.ellipsoid = ellipsoid

-- stylized broadleaf tree: flared trunk, two limbs, layered leafy crowns
function L.Tree(pos, s, leaf)
	leaf = leaf or C(96, 170, 72)
	local bark = C(112, 82, 58)
	vcylP(pos, 1.2 * s, 2.6 * s, bark:Lerp(C(0, 0, 0), 0.1), M.Wood) -- root flare
	vcylP(pos, 9 * s, 1.5 * s, bark, M.Wood).CanCollide = true
	for k = -1, 1, 2 do
		cylP(CF(pos + V3(k * 1.6 * s, 8 * s, 0)) * ANG(0, 0, PI / 2 + k * 0.7), 4.5 * s, 0.8 * s, bark, M.Wood)
	end
	local crowns = { { 0, 12.5, 0, 9.5 }, { -3.4, 10.8, 1.2, 7 }, { 3.2, 11, -1, 7.5 }, { 0.6, 14.6, -0.4, 6.4 } }
	for i, c in ipairs(crowns) do
		local col = leaf:Lerp(i % 2 == 0 and C(70, 130, 60) or C(150, 205, 100), 0.18 * (i % 3))
		local cr = ellipsoid(CF(pos + V3(c[1], c[2], c[3]) * s), V3(c[4], c[4] * 0.78, c[4]) * s, col, M.LeafyGrass)
		tag(cr, "TPFC_Sway", { Amp = 0.01, Period = rng:NextNumber(5, 8) })
	end
end
function L.Bush(pos, s, col)
	col = col or C(84, 150, 70)
	for i = 1, 3 do
		ellipsoid(CF(pos + V3((i - 2) * 1.3 * s, 0.9 * s, rng:NextNumber(-0.5, 0.5) * s)), V3(2.6, 2, 2.4) * s * rng:NextNumber(0.85, 1.15),
			col:Lerp(C(130, 190, 90), rng:NextNumber(0, 0.3)), M.LeafyGrass)
	end
	if rng:NextNumber() < 0.6 then -- a few blossoms, not a sprinkle carpet
		for _ = 1, 3 do ballP(pos + V3(rng:NextNumber(-1.6, 1.6) * s, 1.8 * s, rng:NextNumber(-1, 1) * s), 0.45 * s, Color3.fromHSV(rng:NextNumber(0.85, 1.1) % 1, 0.45, 1), M.SmoothPlastic) end
	end
end
function L.Rock(pos, s, col)
	col = col or C(150, 150, 145)
	for i = 1, 3 do
		part("Part", V3(rng:NextNumber(2.5, 4), rng:NextNumber(1.6, 2.8), rng:NextNumber(2.5, 4)) * s * (1 - i * 0.18),
			CF(pos + V3(rng:NextNumber(-1, 1) * s, 0.6 * s, rng:NextNumber(-1, 1) * s)) * ANG(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, PI), rng:NextNumber(-0.3, 0.3)),
			col:Lerp(C(110, 112, 108), rng:NextNumber(0, 0.4)), M.Slate, i == 1)
	end
end
-- iron lamp post: base, pole, arm, warm glass lantern (not neon) + one light
function L.Lamp(pos, armDir)
	local iron = C(48, 44, 56)
	vcylP(pos, 0.8, 1.6, iron, M.Metal)
	vcylP(pos + V3(0, 0.8, 0), 9, 0.45, iron, M.Metal)
	vcylP(pos + V3(0, 9.8, 0), 0.4, 0.9, iron, M.Metal)
	local d = armDir or V3(0, 0, 0)
	local top = pos + V3(0, 10, 0) + d * 1.2
	if d.Magnitude > 0 then block(CF((pos + V3(0, 10.2, 0) + top) / 2), V3(math.abs(d.X) * 1.3 + 0.2, 0.2, math.abs(d.Z) * 1.3 + 0.2), iron, M.Metal) end
	local glass = block(CF(top - V3(0, 0.8, 0)), V3(1, 1.3, 1), C(255, 214, 150), M.Glass, false, 0.15)
	block(CF(top - V3(0, 0.05, 0)), V3(1.3, 0.25, 1.3), iron, M.Metal)
	block(CF(top - V3(0, 1.55, 0)), V3(1.15, 0.2, 1.15), iron, M.Metal)
	light(glass, C(255, 205, 150), 18, 1.1)
end
-- wooden signpost with arrow boards (clear routes from spawn)
function L.Signpost(pos, boards)
	local wood = C(140, 100, 66)
	vcylP(pos, 7, 0.6, wood:Lerp(C(0, 0, 0), 0.15), M.Wood).CanCollide = true
	for i, b in ipairs(boards) do
		local cf = CF(pos + V3(0, 6.2 - i * 1.4, 0)) * ANG(0, b.yaw, 0) * CF(0, 0, -1.7)
		local board = block(cf, V3(0.25, 1.1, 3.6), C(222, 190, 140), M.WoodPlanks)
		wedge(cf * CF(0, 0, -2.15) * ANG(0, PI, 0), V3(0.25, 1.1, 0.8), C(222, 190, 140), M.WoodPlanks)
		local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Right; sg.CanvasSize = Vector2.new(360, 110); sg.LightInfluence = 0.4
		local tl = Instance.new("TextLabel"); tl.Size = UDim2.fromScale(1, 1); tl.BackgroundTransparency = 1; tl.Font = Enum.Font.FredokaOne
		tl.TextScaled = true; tl.Text = b.text; tl.TextColor3 = C(80, 50, 30); tl.Parent = sg; sg.Parent = board
		local sg2 = sg:Clone(); sg2.Face = Enum.NormalId.Left; sg2.Parent = board
	end
end
function L.Bench(cf)
	local wood, iron = C(150, 105, 70), C(50, 46, 56)
	block(cf * CF(0, 1.5, 0), V3(5, 0.3, 1.5), wood, M.WoodPlanks, true)
	block(cf * CF(0, 2.5, 0.65) * ANG(-0.25, 0, 0), V3(5, 1.2, 0.25), wood, M.WoodPlanks)
	for k = -1, 1, 2 do block(cf * CF(k * 2.1, 0.75, 0), V3(0.3, 1.5, 1.3), iron, M.Metal) end
end

-- THE SPAWN AREA: layered terrain, curved plaza, lit street, base approaches, gardens and a gazebo
function L.Hub(depth, SW, hallBack)
	L.Seed(4242)
	local zTop, zEnd = hallBack, -depth + 24
	local len = zTop - zEnd
	local zc = (zTop + zEnd) / 2
	local BASEZ = { -84, -160, -236, -312 }
	if terrain then
		-- paved street sunk into the lawn, cobbled borders, curved plaza + gazebo circle
		terrain:FillBlock(CF(0, -0.75, zc), V3(46, 1.5, len), M.Pavement)
		for s = -1, 1, 2 do terrain:FillBlock(CF(s * 24.5, -0.75, zc), V3(3, 1.5, len), M.Cobblestone) end
		terrain:FillCylinder(CF(0, -0.75, -330), 1.5, 30, M.Cobblestone)
		terrain:FillCylinder(CF(0, -0.7, -330), 1.5, 26, M.Pavement)
		terrain:FillCylinder(CF(0, -0.75, -420), 1.5, 15, M.Cobblestone)
		-- approaches from the street to each of the eight base entrances
		for _, z in ipairs(BASEZ) do
			for s = -1, 1, 2 do terrain:FillBlock(CF(s * 28, -0.75, z), V3(8, 1.5, 10), M.Pavement) end
		end
		-- soft grassy berms + rock outcrops behind the base rows (outside every base's hedges)
		for z = -60, zEnd, -26 do
			for s = -1, 1, 2 do
				terrain:FillBall(V3(s * rng:NextNumber(101, 106), rng:NextNumber(-5, -2), z + rng:NextNumber(-6, 6)), rng:NextNumber(7, 10), M.Grass)
				if rng:NextNumber() < 0.35 then terrain:FillBall(V3(s * 104, rng:NextNumber(-1, 2), z), rng:NextNumber(2.5, 4), M.Rock) end
			end
		end
		-- rolling back garden behind the gazebo
		for i = 0, 6 do terrain:FillBall(V3(-75 + i * 25, -6, zEnd - 12 + (i % 2) * 6), rng:NextNumber(12, 16), M.Grass) end
	end
	-- low stone curbs (gaps at every base approach and the plaza)
	local stone = C(196, 190, 180)
	local function gap(z)
		for _, bz in ipairs(BASEZ) do if math.abs(z - bz) < 7 then return true end end
		return math.abs(z + 330) < 30
	end
	for z = zTop - 2, zEnd, -4 do
		if not gap(z) then for s = -1, 1, 2 do block(CF(s * 23.2, 0.18, z - 2), V3(0.6, 0.36, 3.9), stone, M.Concrete) end end
	end
	-- lamp posts in rhythm along both curbs (kept out of base approaches)
	for z = -60, -440, -38 do
		if not gap(z) then for s = -1, 1, 2 do L.Lamp(V3(s * 26.6, 0, z), V3(-s, 0, 0)) end end
	end
	-- plaza: fountain focal point, ring of benches, planter trees
	L.HubFountain(V3(0, 0, -330))
	for i = 0, 3 do
		local a = i / 4 * PI * 2 + PI / 4
		local p = V3(math.cos(a) * 21, 0, -330 + math.sin(a) * 21)
		L.Bench(CFrame.lookAt(p, V3(0, 0, -330)) * ANG(0, PI, 0))
		local pl = V3(math.cos(a + 0.35) * 23, 0, -330 + math.sin(a + 0.35) * 23)
		vcylP(pl, 1.4, 6, C(200, 192, 182), M.Brick)
		L.Tree(pl + V3(0, 1.4, 0), 0.7)
	end
	-- spawn welcome: signpost with clear routes, small gardens either side of the spawn
	L.Signpost(V3(9, 0, -66), { { text = "LAUNCH HALL", yaw = 0 }, { text = "YOUR BASE", yaw = PI / 2 }, { text = "FOUNTAIN", yaw = PI } })
	for s = -1, 1, 2 do
		L.Bush(V3(s * 21, 0, -50), 1)
		L.Rock(V3(s * 20, 0, -44), 0.6)
	end
	-- gazebo: secondary focal point at the far end of the street
	local g = V3(0, 0, -420)
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		vcylP(g + V3(math.cos(a) * 9, 0, math.sin(a) * 9), 11, 1.1, C(240, 236, 228), M.Marble)
	end
	vcylP(g, 0.6, 21, C(220, 214, 204), M.Marble)
	vcylP(g + V3(0, 11, 0), 1, 21, C(240, 236, 228), M.Marble)
	local dome = ellipsoid(CF(g + V3(0, 11.5, 0)), V3(21, 10, 21), C(120, 92, 175), M.SmoothPlastic)
	ballP(g + V3(0, 17, 0), 1.6, C(232, 190, 90), M.Metal)
	light(dome, C(255, 220, 160), 24, 0.8)
	-- outer gardens: trees behind the bases and along the back, bushes around the gazebo
	for z = -70, zEnd, -22 do
		for s = -1, 1, 2 do
			if rng:NextNumber() < 0.8 then L.Tree(V3(s * rng:NextNumber(99, 104), 0, z + rng:NextNumber(-5, 5)), rng:NextNumber(0.9, 1.25)) end
		end
	end
	for _ = 1, 10 do L.Tree(V3(rng:NextNumber(-95, 95), 0, rng:NextNumber(zEnd - 14, zEnd - 2)), rng:NextNumber(1, 1.4)) end
	for i = 1, 8 do
		local s = i % 2 == 0 and 1 or -1
		L.Bush(V3(s * rng:NextNumber(14, 20), 0, -420 + rng:NextNumber(-14, 14)), rng:NextNumber(0.8, 1.1))
	end
end

---------------------------------------------------------------- HUB + HALL
function L.HubFountain(pos)
	-- layered marble basin, visible water, slowly moving portal crystal (tagged)
	local marble, gold = C(236, 234, 242), C(232, 190, 90)
	vcylP(pos, 1.4, 24, marble, M.Marble)
	vcylP(pos + V3(0, 1.4, 0), 0.4, 21, C(90, 190, 240), M.Glass, 0.25)
	vcylP(pos + V3(0, 1.4, 0), 0.5, 24.6, gold, M.Metal)
	vcylP(pos, 4, 12, marble, M.Marble)
	vcylP(pos + V3(0, 4, 0), 0.4, 10, C(90, 190, 240), M.Glass, 0.25)
	vcylP(pos, 8, 3, marble, M.Marble)
	for i = 0, 3 do block(CF(pos + V3(0, 8.5, 0)) * ANG(0, i * PI / 2, 0) * CF(0, 0, -2.2), V3(1.2, 1, 3), gold, M.Metal) end
	local cr = block(CF(pos + V3(0, 12, 0)) * ANG(0, PI / 4, 0.4), V3(3, 5, 3), C(175, 125, 255), M.Neon)
	light(cr, C(175, 125, 255), 30, 2)
	tag(cr, "TPFC_Bob", { Amp = 0.25, Period = 4, Spin = 12 })
end

function L.StreetBanners(z1, z2)
	local violet, gold = C(98, 60, 170), C(235, 195, 95)
	for z = z1, z2, -38 do
		for s = -1, 1, 2 do
			local x = s * 27.5
			block(CF(x, 7, z), V3(0.5, 14, 0.5), C(60, 50, 75), M.Metal)
			block(CF(x - s * 1.4, 13.6, z), V3(2.8, 0.4, 0.4), gold, M.Metal)
			local b = block(CF(x - s * 1.9, 10.5, z), V3(0.2, 5.6, 2.4), violet, M.Fabric)
			block(CF(x - s * 1.9, 10.5, z - 0.02) * CF(0, 0, 0), V3(0.24, 1.2, 1.2), gold, M.Neon)
			tag(b, "TPFC_Sway", { Amp = 0.03, Period = 6 })
		end
	end
end

-- hall upgrade: violet side bays, segmented front arch, floor charge channels (hall footprint unchanged)
function L.HallDressing(hw, back, front, H)
	local violet, gold, marble = C(98, 60, 170), C(235, 195, 95), C(240, 238, 246)
	-- marble floor inlays + charge channels toward the front arch (energised by the client while charging)
	for k = -2, 2 do
		local ch = block(CF(k * 5, 1.28, (back + front) / 2), V3(0.5, 0.08, front - back - 6), C(150, 110, 255), M.Neon, false, 0.6)
		ch.Name = "ChargeChannel"
		tag(ch, "TPFC_ChargeChannel", { Index = k })
	end
	block(CF(0, 1.27, front - 2.5), V3(hw * 2 - 4, 0.06, 0.8), gold, M.Neon, false, 0.3).Name = "LaunchLine"
	-- structural side bays (outside the hall walls, so the interior and checks stay identical)
	for s = -1, 1, 2 do
		for z = back + 6, front - 6, 10 do
			block(CF(s * (hw + 3.5), H / 2, z), V3(3, H, 3), marble, M.Marble, true)
			block(CF(s * (hw + 3.5), H + 1, z), V3(4, 2, 4), gold, M.Metal)
			block(CF(s * (hw + 2.05), H * 0.55, z), V3(0.3, H * 0.6, 1.2), violet, M.Neon, false, 0.35)
		end
	end
	-- commanding open front arch (replaces the rainbow bead arch); hollow centre, nothing in the lane
	arch(CF(0, 0, front + 2), hw * 2 + 6, H - 6, 3.2, marble, M.Marble, gold)
	for s = -1, 1, 2 do
		pyramid(CF(s * (hw + 3), H + 9, front + 2), 3.4, 5, gold, M.Metal)
	end
end

-- biome entry gate (more prominent than the 50-stud markers); pylons at |X| = 44
function L.ZoneGate(text, z, col, textLabel)
	local stone, gold = C(226, 222, 214), C(232, 190, 90)
	local x = 44
	for s = -1, 1, 2 do
		block(CF(s * x, 1, z), V3(9, 2, 9), stone:Lerp(C(0, 0, 0), 0.1), M.Limestone, true)
		block(CF(s * x, 18, z), V3(6, 32, 6), stone, M.Limestone, true)
		block(CF(s * (x - 3.05), 18, z), V3(0.3, 26, 1.6), col, M.Neon, false, 0.15)
		pyramid(CF(s * x, 34, z), 7, 6, gold, M.Metal)
	end
	-- lintel high above the flight/reveal corridor
	block(CF(0, 41, z), V3(x * 2 + 8, 4, 5), stone, M.Limestone)
	block(CF(0, 38.8, z - 2.55), V3(x * 2 + 6, 0.5, 0.2), col, M.Neon)
	local plate = block(CF(0, 45.5, z), V3(56, 6, 2), col:Lerp(C(20, 14, 30), 0.55), M.SmoothPlastic)
	if textLabel then
		textLabel(plate, text, C(255, 255, 255), Enum.NormalId.Front)
		textLabel(plate, text, C(255, 255, 255), Enum.NormalId.Back)
	end
end

---------------------------------------------------------------- BIOMES
-- each returns nothing; b = {z1, z2}, m = middle Z
L.Biome = {}

L.Biome.Forest = function(b, m)
	L.Seed(101)
	local leaves = { C(84, 168, 70), C(112, 196, 82), C(62, 148, 76), C(150, 208, 92) }
	-- MAIN: monumental ancient oak on the left
	local o = V3(-84, 0, b[1] + 95)
	for i = 0, 3 do block(CF(o + V3(0, 6 + i * 11, 0)) * ANG(0, i * 0.25, 0), V3(14 - i * 1.6, 12, 14 - i * 1.6), C(102 - i * 4, 72, 46), M.Wood, true) end
	for i = 0, 5 do -- layered roots
		local a = i / 6 * PI * 2
		wedge(CF(o + V3(math.cos(a) * 10, 2.5, math.sin(a) * 10)) * ANG(0, -a - PI / 2, 0), V3(4, 5, 10), C(95, 66, 42), M.Wood, true)
	end
	for i = 0, 3 do -- boughs
		local a = i / 4 * PI * 2 + 0.4
		local bp = o + V3(math.cos(a) * 9, 40, math.sin(a) * 9)
		block(CF(o + V3(math.cos(a) * 5, 38, math.sin(a) * 5)) * ANG(0, -a, 0.7), V3(4, 16, 4), C(98, 68, 44), M.Wood)
		canopy(bp + V3(math.cos(a) * 8, 8, math.sin(a) * 8), 2.2, leaves)
	end
	canopy(o + V3(0, 54, 0), 2.6, leaves)
	local knot = rune(CF(o + V3(7.05, 16, 0)) * ANG(0, PI / 2, 0), 3, 4, C(255, 226, 110))
	light(knot, C(255, 220, 120), 24, 1)
	-- SUPPORT 1: broken garden arch / ruins on the right
	local r = V3(74, 0, b[1] + 40)
	arch(CF(r) * ANG(0, PI / 2, 0), 14, 11, 2.4, C(205, 200, 185), M.Limestone)
	for i = 1, 3 do block(CF(r + V3(rng:NextNumber(-6, 6), 1, rng:NextNumber(8, 18))) * ANG(0, rng:NextNumber(0, PI), PI / 2), V3(2.2, 6, 2.2), C(200, 195, 180), M.Limestone, true) end
	-- SUPPORT 2: wooden observation platform far right
	local t = V3(96, 0, b[1] + 120)
	for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do block(CF(t + V3(c[1], 9, c[2])), V3(1, 18, 1), C(120, 85, 55), M.Wood, true) end
	block(CF(t + V3(0, 18.5, 0)), V3(9, 1, 9), C(140, 100, 62), M.WoodPlanks, true)
	pyramid(CF(t + V3(0, 23, 0)), 10, 5, C(170, 70, 60), M.Slate)
	-- side trees (four variants), stream-edge stones, quiet pale stone breaks in the corridor (flush)
	for i = 1, 18 do
		local sgn = (i % 2 == 0) and 1 or -1
		local pos = V3(sideX(sgn, 46, 68), 0, rng:NextNumber(b[1] + 6, b[2] - 6))
		if (pos - o).Magnitude > 26 and (pos - t).Magnitude > 10 then tree(pos, rng:NextNumber(1, 1.5), (i % 4) + 1, leaves) end
	end
	for i = 1, 8 do block(CF(sideX(i % 2 == 0 and 1 or -1, 38, 50), 0.6, rng:NextNumber(b[1], b[2])) * ANG(0, rng:NextNumber(0, PI), 0), V3(3, 1.2, 2.2), C(170, 172, 160), M.Slate) end
	for i = 1, 6 do block(CF(rng:NextNumber(-24, 24), 0.06, rng:NextNumber(b[1] + 10, b[2] - 10)) * ANG(0, rng:NextNumber(0, PI), 0), V3(rng:NextNumber(3, 6), 0.12, rng:NextNumber(2, 4)), C(206, 204, 186), M.Slate) end
end

L.Biome.Volcano = function(b, m)
	L.Seed(202)
	local basalt, dark, lava = C(52, 40, 42), C(32, 26, 30), C(255, 110, 30)
	-- MAIN: jagged geological volcano (left) with crater glow + diagonal lavafall
	local v = V3(-128, 0, m)
	local top = 0
	for i = 0, 6 do
		local w = 120 - i * 15
		block(CF(v + V3(rng:NextNumber(-3, 3), i * 13 + 6.5, rng:NextNumber(-3, 3))) * ANG(0, i * 0.35, 0), V3(w, 13, w * 0.85), basalt:Lerp(dark, i * 0.08), M.Basalt, true)
		top = i * 13 + 13
	end
	for i = 0, 5 do -- jagged crown
		local a = i / 6 * PI * 2
		wedge(CF(v + V3(math.cos(a) * 14, top + 6, math.sin(a) * 14)) * ANG(0, -a, 0), V3(10, 14, 8), dark, M.Basalt)
	end
	local crater = block(CF(v + V3(0, top + 0.5, 0)), V3(18, 1, 18), lava, M.Neon)
	light(crater, C(255, 120, 40), 60, 2.5)
	tag(crater, "TPFC_Pulse", { Period = 6, Base = 0, Peak = 0.25 })
	for i = 0, 9 do -- lavafall down the lane-facing slope, then a pool
		local p = v + V3(42 - i * 0.4 + i * 3.2, top - i * 9, -6 + i * 1.5)
		local seg = block(CF(p) * ANG(0, 0, -0.55), V3(9, 2, 6), lava, M.Neon, false, 0.05)
		if i % 3 == 0 then tag(seg, "TPFC_Pulse", { Period = 4 + i * 0.3, Base = 0.05, Peak = 0.3 }) end
	end
	-- SUPPORT 1: cooled basalt colonnade (right)
	for i = 0, 13 do
		local z = b[1] + 18 + i * 12
		local h = 8 + math.abs(math.sin(i * 1.3)) * 16
		block(CF(rng:NextNumber(62, 72), h / 2, z) * ANG(0, PI / 6, 0), V3(5, h, 5), basalt:Lerp(dark, rng:NextNumber(0, 0.5)), M.Basalt, true)
		if i % 4 == 0 then block(CF(60.4, h * 0.6, z), V3(0.3, h * 0.5, 0.5), lava, M.Neon) end
	end
	-- SUPPORT 2: broken basalt bridge (far right, beyond the corridor)
	for s = -1, 1, 2 do
		block(CF(94, 10, m + 60 + s * 16), V3(10, 20, 6), basalt, M.Basalt, true)
		block(CF(94, 21, m + 60 + s * 9), V3(10, 2.5, 9), dark, M.Basalt)
	end
	-- vents (long staggered pulse), quiet dark landing basalt with sparse flush cracks
	for i = 1, 6 do
		local p = V3(sideX(i % 2 == 0 and 1 or -1, 46, 60), 0, rng:NextNumber(b[1] + 10, b[2] - 10))
		rockMass(p, 7, 5, 7, dark, M.Basalt, 2)
		local core = block(CF(p + V3(0, 5.2, 0)), V3(2.4, 0.4, 2.4), lava, M.Neon)
		tag(core, "TPFC_Pulse", { Period = rng:NextNumber(9, 15), Base = 0.6, Peak = 0 })
	end
	for i = 1, 7 do block(CF(rng:NextNumber(-26, 26), 0.05, rng:NextNumber(b[1] + 8, b[2] - 8)) * ANG(0, rng:NextNumber(0, PI), 0), V3(rng:NextNumber(5, 10), 0.1, 0.35), lava, M.Neon, false, 0.2) end
end

L.Biome.Frozen = function(b, m)
	L.Seed(303)
	local ice, deep, snow = C(196, 230, 250), C(120, 170, 215), C(244, 250, 255)
	-- MAIN: ice citadel (right)
	local c = V3(86, 0, m)
	block(CF(c + V3(0, 6, 0)), V3(46, 12, 40), deep, M.Ice, true)
	block(CF(c + V3(0, 12.6, 0)), V3(48, 1.2, 42), snow, M.Snow)
	local function tower(p, h, w)
		block(CF(p + V3(0, 12 + h / 2, 0)), V3(w, h, w), ice, M.Ice, true)
		block(CF(p + V3(0, 12 + h + 1, 0)), V3(w + 1.5, 2, w + 1.5), snow, M.Snow)
		pyramid(CF(p + V3(0, 12 + h + 2, 0)), w, w * 1.6, C(150, 205, 245), M.Glass)
		local g = block(CF(p + V3(-w / 2 - 0.05, 12 + h * 0.6, 0)), V3(0.2, h * 0.3, w * 0.25), C(170, 240, 255), M.Neon, false, 0.2)
		tag(g, "TPFC_Glint", { Period = rng:NextNumber(8, 14) })
	end
	tower(c, 52, 12)
	tower(c + V3(-4, 0, -16), 32, 8)
	tower(c + V3(-4, 0, 16), 32, 8)
	arch(CF(c + V3(-23.5, 0, 0)) * ANG(0, PI / 2, 0), 10, 10, 2.5, C(225, 242, 252), M.Ice, C(150, 230, 255))
	-- SUPPORT 1: off-lane ice arch (left)
	arch(CF(-70, 0, b[1] + 60) * ANG(0, PI / 2, 0), 16, 14, 3, ice, M.Ice)
	-- SUPPORT 2: frozen waterfall shelves (left)
	for i = 0, 5 do
		block(CF(-98, 4 + i * 6, b[2] - 60 + i * 2), V3(26 - i * 2, 8, 12), i % 2 == 0 and ice or deep, M.Glacier, true)
		block(CF(-85 + i * 0.5, 2 + i * 6, b[2] - 60 + i * 2), V3(0.6, 10, 9), C(220, 245, 255), M.Ice, false, 0.2)
	end
	-- sparse blocky pines, two snowman vignettes, pale-blue compressed snow patches in the corridor
	for i = 1, 16 do
		local p = V3(sideX(i % 2 == 0 and 1 or -1, 46, 70), 0, rng:NextNumber(b[1] + 6, b[2] - 6))
		if (p - c).Magnitude > 34 then
			block(CF(p + V3(0, 2, 0)), V3(1.2, 4, 1.2), C(100, 70, 45), M.Wood, true)
			for k = 0, 3 do
				block(CF(p + V3(0, 4 + k * 2.6, 0)) * ANG(0, k * 0.5, 0), V3(8 - k * 1.8, 2.4, 8 - k * 1.8), C(40, 105, 72), M.Grass)
				block(CF(p + V3(0, 5.1 + k * 2.6, 0)) * ANG(0, k * 0.5, 0), V3(7 - k * 1.8, 0.4, 7 - k * 1.8), snow, M.Snow)
			end
		end
	end
	for k = 1, 2 do
		local p = V3(-48 + k * 2, 0, b[1] + 40 + k * 120)
		block(CF(p + V3(0, 2, 0)), V3(4, 4, 4), snow, M.Snow, true)
		block(CF(p + V3(0, 5, 0)), V3(3, 3, 3), snow, M.Snow)
		block(CF(p + V3(0, 7.3, 0)), V3(2.2, 2, 2.2), snow, M.Snow)
		block(CF(p + V3(0, 6.3, -1.4)), V3(2.6, 0.5, 0.6), C(90, 140, 220), M.Fabric)
	end
	for i = 1, 6 do block(CF(rng:NextNumber(-24, 24), 0.05, rng:NextNumber(b[1] + 8, b[2] - 8)) * ANG(0, rng:NextNumber(0, PI), 0), V3(rng:NextNumber(5, 9), 0.1, rng:NextNumber(3, 5)), C(205, 228, 248), M.Ice) end
end

L.Biome.Crystal = function(b, m)
	L.Seed(404)
	local rock, dark = C(70, 56, 104), C(44, 36, 70)
	local cols = { C(80, 230, 255), C(240, 100, 220), C(170, 110, 255) }
	-- MAIN: huge open split geode (left), rough outer rock + crystal fans + core
	local g = V3(-94, 0, m)
	for i = 0, 15 do
		local a = i / 15 * PI -- half ring facing the lane
		local p = g + V3(-math.sin(a) * 30, 0, math.cos(a) * 40) -- shell behind, opening faces the lane
		block(CF(p + V3(0, 18 + math.sin(a) * 18, 0)) * ANG(0, -a, -0.15), V3(10, 36 + math.sin(a) * 30, 12), rock:Lerp(dark, (i % 3) * 0.2), M.Slate, true)
	end
	block(CF(g + V3(-8, 1, 0)), V3(40, 2, 70), dark, M.Slate, true)
	crystalFan(g + V3(-12, 2, -18), 3.2, cols, PI / 2)
	crystalFan(g + V3(-12, 2, 18), 3.2, cols, PI / 2)
	local core = block(CF(g + V3(-8, 24, 0)) * ANG(0.4, 0.6, 0.2), V3(8, 12, 8), cols[1], M.Neon)
	light(core, cols[1], 50, 2)
	tag(core, "TPFC_Pulse", { Period = 3, Base = 0, Peak = 0.3 })
	-- SUPPORT 1: rune monoliths (right)
	for i = 0, 2 do
		local p = V3(70 + i * 6, 0, b[1] + 60 + i * 26)
		block(CF(p + V3(0, 9, 0)) * ANG(0, 0.3 * i, 0), V3(5, 18, 3), rock, M.Slate, true)
		rune(CF(p + V3(0, 10, -1.6)) * ANG(0, 0.3 * i, 0), 1.2, 9, cols[i + 1])
	end
	-- SUPPORT 2: mineral pools (right)
	for i = 0, 2 do
		local p = V3(84, 0.2, b[2] - 70 + i * 22)
		block(CF(p), V3(18, 0.6, 14), dark, M.Slate)
		local w = block(CF(p + V3(0, 0.35, 0)), V3(15, 0.2, 11), cols[(i % 3) + 1], M.Glass, false, 0.35)
		tag(w, "TPFC_Pulse", { Period = 6 + i, Base = 0.35, Peak = 0.15 })
	end
	-- cavern illusion from side buttresses + distant high silhouettes (never over the lane)
	for z = b[1] + 20, b[2] - 10, 42 do
		for s = -1, 1, 2 do
			if s < 0 and math.abs(z - m) < 70 then continue end -- keep the geode opening visible
			wedge(CF(s * 74, 22, z) * ANG(0, s > 0 and -PI / 2 or PI / 2, 0), V3(14, 44, 18), rock:Lerp(dark, 0.4), M.Slate, true)
		end
	end
	for i = 1, 10 do
		local sgn = i % 2 == 0 and 1 or -1
		crystal(V3(sideX(sgn, 46, 64), 0, rng:NextNumber(b[1] + 8, b[2] - 8)), rng:NextNumber(5, 11), rng:NextNumber(1.6, 2.6), cols[(i % 3) + 1], ANG(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)))
	end
end

L.Biome.Candy = function(b, m)
	L.Seed(505)
	local choco, cream, pink, mint = C(110, 62, 36), C(255, 240, 222), C(255, 160, 205), C(150, 235, 210)
	-- MAIN: ONE grand chocolate/cream palace (right)
	local p = V3(90, 0, m)
	block(CF(p + V3(0, 7, 0)), V3(52, 14, 56), choco, M.SmoothPlastic, true)
	block(CF(p + V3(0, 14.6, 0)), V3(54, 1.4, 58), cream, M.SmoothPlastic)
	for i = 0, 10 do block(CF(p + V3(-27.2, 12.6 - (i % 3) * 1.1, -26 + i * 5.2)), V3(0.8, 3 + (i % 3) * 2, 2), cream, M.SmoothPlastic) end -- icing drips
	local function caketower(q, h, w)
		block(CF(q + V3(0, 14 + h / 2, 0)), V3(w, h, w), pink, M.SmoothPlastic, true)
		block(CF(q + V3(0, 14 + h + 0.5, 0)), V3(w + 1.4, 1.2, w + 1.4), cream, M.SmoothPlastic)
		pyramid(CF(q + V3(0, 14 + h + 1, 0)), w, w * 1.1, C(255, 120, 175), M.SmoothPlastic)
		ballP(q + V3(0, 14 + h + 1 + w * 1.1 + 1, 0), 2.4, C(230, 30, 50), M.SmoothPlastic)
	end
	caketower(p + V3(0, 0, 0), 30, 14)
	caketower(p + V3(-8, 0, -20), 18, 9)
	caketower(p + V3(-8, 0, 20), 18, 9)
	arch(CF(p + V3(-26.5, 0, 0)) * ANG(0, PI / 2, 0), 10, 8, 2.4, cream, M.SmoothPlastic, C(255, 120, 175))
	-- SUPPORT 1: molded chocolate waterfall + canal (left)
	for i = 0, 5 do block(CF(-92, 5 + i * 7, m - 40 + i * 3), V3(26 - i * 2, 10, 14), choco:Lerp(C(70, 38, 22), i * 0.08), M.SmoothPlastic, true) end
	local fall = block(CF(-78, 18, m - 30), V3(1, 36, 10), C(120, 70, 40), M.SmoothPlastic, false, 0)
	tag(fall, "TPFC_Pulse", { Period = 5, Base = 0, Peak = 0.12 })
	-- SUPPORT 2: candy groves — lollipop trees + blocky candy canes + angular sugar rocks
	for i = 1, 14 do
		local q = V3(sideX(i % 2 == 0 and 1 or -1, 46, 66), 0, rng:NextNumber(b[1] + 8, b[2] - 8))
		if (q - p).Magnitude > 40 then
			if i % 3 == 0 then
				for k = 0, 5 do block(CF(q + V3(0, 0.75 + k * 1.5, 0)), V3(1.2, 1.5, 1.2), k % 2 == 0 and C(230, 40, 50) or cream, M.SmoothPlastic, true) end
				block(CF(q + V3(1.4, 9.4, 0)), V3(4, 1.2, 1.2), C(230, 40, 50), M.SmoothPlastic)
			elseif i % 3 == 1 then
				block(CF(q + V3(0, 5, 0)), V3(0.8, 10, 0.8), cream, M.SmoothPlastic, true)
				local disc = cylP(CF(q + V3(0, 12, 0)) * ANG(0, PI / 2, 0), 1, 8, Color3.fromHSV(rng:NextNumber(), 0.55, 1), M.SmoothPlastic)
				cylP(CF(q + V3(0, 12, 0)) * ANG(0, PI / 2, 0), 1.1, 4.5, cream, M.SmoothPlastic)
				tag(disc, "TPFC_Sway", { Amp = 0.02, Period = 7 })
			else
				crystal(q, rng:NextNumber(4, 7), rng:NextNumber(2, 3), Color3.fromHSV(rng:NextNumber(0.8, 1), 0.3, 1), ANG(0, rng:NextNumber(0, PI), rng:NextNumber(-0.3, 0.3)))
			end
		end
	end
	-- quiet cream path breaks in the corridor (flush)
	for i = 1, 8 do block(CF(rng:NextNumber(-22, 22), 0.05, b[1] + 25 + i * 45), V3(rng:NextNumber(6, 10), 0.1, 4), cream, M.SmoothPlastic) end
	for i = 1, 4 do block(CF(sideX(i % 2 == 0 and 1 or -1, 44, 50), 0.6, rng:NextNumber(b[1], b[2])), V3(4, 1.2, 4), mint, M.SmoothPlastic) end
end

L.Biome.Space = function(b, m)
	L.Seed(606)
	local lunar, dark, metal, cyan = C(150, 152, 175), C(70, 72, 100), C(170, 176, 196), C(110, 230, 255)
	-- MAIN: orbital observatory (left)
	local o = V3(-86, 0, m + 30)
	block(CF(o + V3(0, 6, 0)), V3(34, 12, 34), dark, M.Concrete, true)
	vcylP(o + V3(0, 12, 0), 14, 26, metal, M.Metal)
	local dome = ballP(o + V3(0, 26, 0), 26, C(190, 196, 215), M.Metal)
	dome.CanCollide = false
	cylP(CF(o + V3(10, 34, 0)) * ANG(0, 0, 0.9), 26, 4.5, C(120, 126, 150), M.Metal) -- telescope tube
	for k = 1, 2 do
		local ring = cylP(CF(o + V3(0, 26, 0)) * ANG(k * 0.7, 0, PI / 2 + k * 0.3), 0.6, 40 + k * 6, cyan, M.Neon, 0.4)
		tag(ring, "TPFC_Spin", { Rate = 4 + k })
	end
	-- SUPPORT 1: crashed satellite (right)
	local s = V3(82, 0, b[1] + 80)
	block(CF(s + V3(0, 3, 0)) * ANG(0.3, 0.6, 0.2), V3(8, 6, 8), metal, M.Metal, true)
	for k = -1, 1, 2 do block(CF(s + V3(k * 9, 4, 2)) * ANG(0.3, 0.6, 0.5 * k), V3(10, 0.4, 5), C(40, 70, 160), M.Glass) end
	cylP(CF(s + V3(-2, 9, 0)) * ANG(0, 0, 1.2), 0.8, 8, metal, M.Metal)
	-- SUPPORT 2: crater-ring structure (right, far)
	local c = V3(90, 0, b[2] - 90)
	for i = 0, 11 do
		local a = i / 12 * PI * 2
		block(CF(c + V3(math.cos(a) * 16, 3, math.sin(a) * 16)) * ANG(0, -a, 0), V3(3, 6, 8), dark, M.Slate, true)
		if i % 3 == 0 then tag(block(CF(c + V3(math.cos(a) * 14.4, 3, math.sin(a) * 14.4)) * ANG(0, -a, 0), V3(0.3, 2, 4), cyan, M.Neon), "TPFC_Pulse", { Period = 8 + i, Base = 0.6, Peak = 0 }) end
	end
	-- distant ringed planet on the skyline (beyond the right wall) + sparse asteroid belt (sides only)
	local planet = ballP(V3(230, 150, m + 120), 90, C(200, 130, 220), M.SmoothPlastic)
	planet.CastShadow = false
	local pr = cylP(CF(V3(230, 150, m + 120)) * ANG(0.35, 0, PI / 2 + 0.25), 0.8, 170, C(240, 210, 255), M.SmoothPlastic, 0.35)
	tag(pr, "TPFC_Spin", { Rate = 3 })
	for i = 1, 10 do
		local sg = i % 2 == 0 and 1 or -1
		local a = block(CF(sg * rng:NextNumber(75, 130), rng:NextNumber(40, 90), rng:NextNumber(b[1], b[2])) * ANG(rng:NextNumber(0, PI), rng:NextNumber(0, PI), 0),
			V3(1, 1, 1) * rng:NextNumber(3, 8), dark, M.Slate)
		tag(a, "TPFC_Spin", { Rate = rng:NextNumber(2, 6) })
	end
	-- low flush craters in the corridor (never a hole: terrain stays continuous)
	for i = 1, 7 do
		local p = V3(rng:NextNumber(-24, 24), 0.04, rng:NextNumber(b[1] + 10, b[2] - 10))
		vcylP(p, 0.08, rng:NextNumber(6, 12), lunar:Lerp(dark, 0.35), M.Slate)
	end
end

L.Biome.Shadow = function(b, m)
	L.Seed(707)
	local stone, plum, teal, red = C(70, 56, 92), C(44, 32, 60), C(80, 220, 210), C(200, 50, 80)
	-- MAIN: fractured cathedral (left)
	local c = V3(-90, 0, m)
	for s = -1, 1, 2 do -- nave walls with tall pointed windows
		for k = 0, 5 do
			local z = c.Z - 40 + k * 16
			block(CF(c.X + s * 14, 18, z), V3(4, 36 - (k == 4 and 18 or 0), 4), stone, M.Slate, true)
			if k < 5 then
				block(CF(c.X + s * 14, 30, z + 8), V3(2.4, 4, 12), plum, M.Slate)
				if s > 0 then rune(CF(c.X + s * 12.7, 16, z + 8) * ANG(0, PI / 2, 0), 5, 14, teal) end
			end
		end
	end
	for i = 0, 2 do -- broken facade + spire facing the lane
		block(CF(c.X + 16, 24 + i * 12, c.Z - 44), V3(10 - i * 2, 12, 10 - i * 2), stone:Lerp(plum, i * 0.2), M.Slate, true)
	end
	pyramid(CF(c.X + 16, 60, c.Z - 44), 6, 14, plum, M.Slate)
	arch(CF(c.X + 16.5, 0, c.Z - 30) * ANG(0, PI / 2, 0), 12, 16, 3, stone, M.Slate, teal)
	-- SUPPORT 1: broken obelisks (right)
	for i = 0, 4 do
		local p = V3(66 + rng:NextNumber(0, 10), 0, b[1] + 50 + i * 110)
		local h = rng:NextNumber(14, 26)
		block(CF(p + V3(0, h / 2, 0)) * ANG(0, 0, rng:NextNumber(-0.15, 0.15)), V3(4, h, 4), stone, M.Slate, true)
		rune(CF(p + V3(-2.1, h * 0.55, 0)) * ANG(0, PI / 2, 0), 1, h * 0.4, i % 2 == 0 and teal or red)
	end
	-- SUPPORT 2: decorative side chasm (right, outside the lane — terrain carved beyond X=80)
	if terrain then
		terrain:FillBlock(CF(110, -10, m), V3(40, 24, 180), M.Air)
		terrain:FillBlock(CF(110, -24, m), V3(40, 4, 180), M.Slate)
	end
	-- twisted angular trees + slowly precessing suspended stones near the cathedral
	for i = 1, 12 do
		local p = V3(sideX(i % 2 == 0 and 1 or -1, 46, 64), 0, rng:NextNumber(b[1] + 8, b[2] - 8))
		if (p - c).Magnitude > 50 then
			local y, cf = 0, CF(p)
			for k = 0, 3 do
				local seg = 5 - k * 0.6
				block(cf * CF(0, seg / 2, 0), V3(1.4 - k * 0.25, seg, 1.4 - k * 0.25), C(40, 28, 52), M.Wood, k == 0)
				cf = cf * CF(0, seg, 0) * ANG(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.6, 0.6))
				y += seg
			end
		end
	end
	for i = 1, 6 do
		local st = block(CF(c + V3(rng:NextNumber(20, 40), rng:NextNumber(30, 55), rng:NextNumber(-40, 40))) * ANG(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0),
			V3(1, 1, 1) * rng:NextNumber(3, 6), plum, M.Slate)
		tag(st, "TPFC_Bob", { Amp = 1.2, Period = rng:NextNumber(8, 12), Spin = rng:NextNumber(2, 4) })
	end
	-- quiet lavender centre stone breaks (flush)
	for i = 1, 8 do block(CF(rng:NextNumber(-24, 24), 0.05, rng:NextNumber(b[1] + 10, b[2] - 10)) * ANG(0, rng:NextNumber(0, PI), 0), V3(rng:NextNumber(5, 9), 0.1, rng:NextNumber(3, 5)), C(120, 104, 150), M.Slate) end
end

L.Biome.Heaven = function(b, m)
	L.Seed(808)
	local marble, cream, gold, sky = C(246, 242, 232), C(236, 228, 210), C(232, 190, 90), C(170, 215, 245)
	-- MAIN: celestial sanctuary (left): stepped platform, colonnade, winged gateway, dome
	local s = V3(-94, 0, m + 60)
	for i = 0, 3 do block(CF(s + V3(0, 1 + i * 2, 0)), V3(60 - i * 6, 2, 80 - i * 6), i % 2 == 0 and marble or cream, M.Marble, true) end
	for k = 0, 7 do
		for sd = -1, 1, 2 do column(s + V3(sd * 18, 8, -28 + k * 8), 18, 2.4, marble, M.Marble, gold) end
	end
	block(CF(s + V3(0, 27.5, 0)), V3(42, 2, 66), cream, M.Marble)
	block(CF(s + V3(0, 28.7, 0)), V3(43, 0.4, 67), gold, M.Metal)
	local dome = ballP(s + V3(0, 30, 0), 30, marble, M.Marble)
	dome.CanCollide = false
	arch(CF(s + V3(30, 8, 0)) * ANG(0, PI / 2, 0), 18, 22, 3.2, marble, M.Marble, gold)
	for sd = -1, 1, 2 do -- architectonic wing details on the gateway
		for f = 0, 3 do
			wedge(CF(s + V3(31, 26 + f * 3, sd * (14 + f * 4))) * ANG(0, sd > 0 and 0 or PI, 0) * ANG(-0.5 - f * 0.15, 0, 0), V3(1.2, 10 - f * 1.5, 4), f == 0 and gold or marble, M.Marble)
		end
	end
	local ray = block(CF(s + V3(0, 60, 0)), V3(6, 60, 6), C(255, 245, 210), M.Neon, false, 0.85)
	tag(ray, "TPFC_Pulse", { Period = 8, Base = 0.85, Peak = 0.7 })
	-- SUPPORT 1: rhythmic colonnade along the right side
	for z = b[1] + 30, b[2] - 30, 36 do column(V3(64, 0, z), 20, 2.6, marble, M.Marble, gold) end
	-- SUPPORT 2: cloud gardens + side waterfalls (right)
	for i = 0, 2 do
		local p = V3(92, 0, b[1] + 160 + i * 220)
		block(CF(p + V3(0, 5, 0)), V3(22, 10, 22), cream, M.Marble, true)
		for k = 1, 4 do block(CF(p + V3(rng:NextNumber(-8, 8), 11 + rng:NextNumber(0, 2), rng:NextNumber(-8, 8))), V3(6, 3, 6), C(250, 250, 255), M.SmoothPlastic) end
		block(CF(p + V3(-11.2, 5, 0)), V3(0.4, 10, 6), sky, M.Glass, false, 0.3)
		block(CF(p + V3(0, 11.5, 0)), V3(3, 3, 3), C(120, 200, 110), M.Grass)
	end
	-- coherent banded rainbow arch on the skyline beyond the lane end (never over the corridor)
	local bands = { C(255, 90, 90), C(255, 165, 60), C(255, 230, 80), C(100, 220, 120), C(90, 170, 255), C(120, 110, 255), C(205, 110, 255) }
	for bi, col in ipairs(bands) do
		local r = 120 - bi * 4
		for i = 1, 24 do
			local a0, a1 = (i - 1) / 24 * PI, i / 24 * PI
			local p0, p1 = V3(math.cos(a0) * r, math.sin(a0) * r * 0.75, 0), V3(math.cos(a1) * r, math.sin(a1) * r * 0.75, 0)
			local d = p1 - p0
			block(CF(V3(0, 0, b[2] + 90) + (p0 + p1) / 2) * ANG(0, 0, math.atan2(d.Y, d.X)), V3(d.Magnitude + 0.5, 3.6, 2), col, M.SmoothPlastic)
		end
	end
	-- clean scenic end: marble balustrade just past the last landing point
	for x = -66, 66, 6 do column(V3(x, 0, b[2] + 6), 4, 1, marble, M.Marble, gold) end
	block(CF(0, 4.8, b[2] + 6), V3(136, 0.8, 2), cream, M.Marble)
	-- quiet cream stone floor slabs with pale-blue shadow tone (flush)
	for i = 1, 10 do block(CF(rng:NextNumber(-24, 24), 0.05, rng:NextNumber(b[1] + 10, b[2] - 10)), V3(rng:NextNumber(6, 10), 0.1, rng:NextNumber(4, 6)), C(228, 232, 240), M.Marble) end
end

---------------------------------------------------------------- transitions (side dressing only; boundaries unchanged)
local TRANS = {
	Volcano = { C(60, 45, 40), M.Basalt }, Frozen = { C(150, 170, 190), M.Slate }, Crystal = { C(90, 80, 150), M.Slate },
	Candy = { C(240, 170, 205), M.SmoothPlastic }, Space = { C(90, 70, 70), M.Slate }, Shadow = { C(80, 75, 105), M.Slate },
	Heaven = { C(236, 228, 210), M.Marble },
}
function L.Transition(toId, z)
	local t = TRANS[toId]
	if not t then return end
	L.Seed(900 + math.floor(z))
	for i = 1, 6 do
		local sg = i % 2 == 0 and 1 or -1
		rockMass(V3(sideX(sg, 46, 62), 0, z + rng:NextNumber(-14, 14)), rng:NextNumber(4, 7), rng:NextNumber(3, 8), rng:NextNumber(4, 7), t[1], t[2], 2)
	end
end

return L
