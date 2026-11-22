-- WorldKit: the shared blocky construction kit used by the hub and all eight biomes.
-- Location: ServerScriptService > Server > WorldKit (ModuleScript)
--
-- CONTRACT (map brief + GameServer landing contract):
--  * Landing rays only hit Terrain. Every part made here is CanQuery = false and CanTouch = false,
--    so decoration can never become the floor or catch a throw.
--  * Corridor rules: landing X is clamped to [-30, 30]; the reveal camera can sit up to X ~ 48 and
--    16 studs high. So anything taller than ~0.5 stays at |X| >= 44, anything taller than ~5 at
--    |X| >= 54, and nothing hangs over the lane. K.Side() enforces the minimum.
--  * Deterministic: every builder seeds K.rng, so rebuilds never drift.
--  * Motion is not done here. Parts get CollectionService tags and the client WorldFx scheduler animates them.

local CollectionService = game:GetService("CollectionService")

local K = {}
local PI = math.pi
local V3, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles
local M = Enum.Material
K.PI, K.V3, K.CF, K.ANG, K.M = PI, V3, CF, ANG, M

local out -- current output folder
K.terrain = workspace.Terrain
K.rng = Random.new(1)
K.count = 0

function K.SetFolder(f) out = f end
-- walkable/placeable top surfaces registered by generators: { xa, xb, za, zb, top } (world, xa < xb)
K.surfaces = {}
function K.ResetSurfaces() K.surfaces = {} end
function K.addSurface(xa, xb, za, zb, top)
	table.insert(K.surfaces, { math.min(xa, xb), math.max(xa, xb), math.min(za, zb), math.max(za, zb), top })
end
-- highest registered surface at (x, z); 0 (valley floor) when none
function K.groundY(x, z)
	local y = 0
	for _, r in ipairs(K.surfaces) do
		if x >= r[1] and x <= r[2] and z >= r[3] and z <= r[4] and r[5] > y then y = r[5] end
	end
	return y
end
function K.at(x, z) return Vector3.new(x, K.groundY(x, z), z) end
function K.Folder() return out end
function K.Seed(n) K.rng = Random.new(n) end
function K.r(a, b) return K.rng:NextNumber(a, b) end
function K.ri(a, b) return K.rng:NextInteger(a, b) end
function K.pick(t) return t[K.rng:NextInteger(1, #t)] end
function K.chance(p) return K.rng:NextNumber() < p end
function K.C(r, g, b) return Color3.fromRGB(r, g, b) end
function K.hex(h) return Color3.fromHex(h) end
function K.dark(c, k) return c:Lerp(Color3.new(0, 0, 0), k) end
function K.light(c, k) return c:Lerp(Color3.new(1, 1, 1), k) end
local C = K.C

---------------------------------------------------------------- primitives
-- MIRROR MODE: biomes are authored as seen in the reference sheets (viewer at the hall looking
-- down +Z, where screen-right is world -X). With K.mirror = true every part is reflected across
-- X = 0: position x -> -x and rotation R -> S R S (S = diag(-1, 1, 1)), which is a proper rotation.
-- Blocks, wedges, cylinders and balls are symmetric in X, so the geometry is unchanged.
-- Surfaces / groundY stay in design coordinates. Reveal camera rule in design space when mirrored:
-- tall pieces on the design-LEFT (-X) side must stay at |X| >= 54.
K.mirror = false
local function mirrorCF(cf)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end
K.mirrorCF = mirrorCF
local function part(class, size, cf, color, mat, collide, transp)
	if K.mirror then cf = mirrorCF(cf) end
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
	-- shadows only from big masses (cheap and keeps small props crisp)
	-- perf: only sizeable pieces cast shadows (shadow maps are re-rendered every frame the camera moves)
	p.CastShadow = (transp or 0) < 0.3 and size.X * size.Y * size.Z > 60 and math.max(size.X, size.Y, size.Z) >= 6
	local m = p.Material
	if m == M.Metal then p.Reflectance = 0.14
	elseif m == M.Glass then p.Reflectance = 0.22
	elseif m == M.Ice then p.Reflectance = 0.12
	elseif m == M.Marble then p.Reflectance = 0.05 end
	p.Parent = out
	K.count += 1
	return p
end
K.part = part
function K.block(cf, size, color, mat, collide, transp) return part("Part", size, cf, color, mat, collide, transp) end
function K.wedge(cf, size, color, mat, collide, transp) return part("WedgePart", size, cf, color, mat, collide, transp) end
function K.corner(cf, size, color, mat, collide) return part("CornerWedgePart", size, cf, color, mat, collide) end
function K.ball(pos, d, color, mat, transp)
	local p = part("Part", V3(d, d, d), CF(pos), color, mat, false, transp)
	p.Shape = Enum.PartType.Ball
	return p
end
-- cylinder whose axis is the cf's X axis
function K.cyl(cf, len, d, color, mat, collide, transp)
	local p = part("Part", V3(len, d, d), cf, color, mat, collide, transp)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- upright cylinder standing on pos
function K.vcyl(pos, h, d, color, mat, collide, transp)
	return K.cyl(CF(pos + V3(0, h / 2, 0)) * ANG(0, 0, PI / 2), h, d, color, mat, collide, transp)
end
function K.ellipsoid(cf, size, color, mat, transp)
	local p = part("Part", size, cf, color, mat, false, transp)
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	return p
end
function K.lamp(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 1.2; l.Shadows = range >= 40; l.Parent = p
	return l
end
function K.spot(p, color, range, brightness, angle, face)
	local l = Instance.new("SpotLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 2; l.Angle = angle or 60
	l.Face = face or Enum.NormalId.Bottom; l.Shadows = false; l.Parent = p
	return l
end
function K.tag(p, name, attrs)
	if p:IsA("Model") and (name == "TPFC_Bob" or name == "TPFC_Spin") then
		-- WorldPivot is not replicated. A physical reference must arrive before the
		-- client animator can move the model, including when its children arrive late.
		if not p.PrimaryPart then
			local origin = p:GetPivot()
			local anchor = Instance.new("Part")
			anchor.Name, anchor.Size, anchor.CFrame = "AnimationRoot", V3(0.05, 0.05, 0.05), origin
			anchor.Anchored, anchor.Transparency, anchor.CastShadow = true, 1, false
			anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = false, false, false
			anchor.Parent = p
			p.PrimaryPart = anchor
		end
		p:SetAttribute("TPFC_AnimationBase", p:GetPivot())
		p:SetAttribute("TPFC_AnimationParts", #p:GetChildren())
	end
	for k, v in pairs(attrs or {}) do
		p:SetAttribute(k, v)
	end
	CollectionService:AddTag(p, name)
	return p
end

-- keep scenery out of the reveal corridor: returns sign * max(|x|, minAbs)
function K.Side(x, minAbs)
	local s = x < 0 and -1 or 1
	return s * math.max(math.abs(x), minAbs or 44)
end

---------------------------------------------------------------- shapes
-- pyramid cap (4 wedges), base centred on cf, apex +Y
function K.pyramid(cf, w, h, color, mat, d)
	d = d or w
	for i = 0, 3 do
		local ww = (i % 2 == 0) and w or d
		local dd = (i % 2 == 0) and d or w
		K.wedge(cf * ANG(0, i * PI / 2, 0) * CF(0, h / 2, -dd / 4), V3(ww, h, dd / 2), color, mat)
	end
end
-- faceted gem (bi-pyramid, widest at cf) as one Model so WorldFx can bob/spin it as a piece.
-- Returns the model and a part to hang a light on.
function K.gem(cf, w, h, color, mat, transp)
	local prev = out
	local m = Instance.new("Model")
	m.Name = "Gem"
	out = m
	K.pyramid(cf, w, h * 0.62, color, mat)
	K.pyramid(cf * ANG(PI, 0, 0), w, h * 0.38, K.dark(color, 0.18), mat)
	out = prev
	local parts = m:GetChildren()
	for _, p in ipairs(parts) do
		p.Transparency = transp or 0
		p.CastShadow = false
	end
	m.Parent = prev
	return m, parts[1]
end
-- gable roof along cf Z: two wedges back to back (w = span across X, h = rise, len = along Z)
function K.gable(cf, w, h, len, color, mat)
	K.wedge(cf * CF(-w / 4, h / 2, 0) * ANG(0, -PI / 2, 0), V3(len, h, w / 2), color, mat)
	K.wedge(cf * CF(w / 4, h / 2, 0) * ANG(0, PI / 2, 0), V3(len, h, w / 2), color, mat)
end
-- chunky "bevelled" stone block: body + slightly inset lighter top slab + darker foot band
function K.stone(cf, size, color, mat, collide)
	local b = K.block(cf, size, color, mat or M.Slate, collide)
	K.block(cf * CF(0, size.Y / 2 + 0.12, 0), V3(size.X - 0.5, 0.24, size.Z - 0.5), K.light(color, 0.12), mat or M.Slate)
	return b
end
-- jagged tiered rock mass; returns top height
function K.rockMass(pos, w, h, d, col, mat, tiers, collide)
	tiers = tiers or 3
	local y = 0
	for i = 0, tiers - 1 do
		local k = 1 - i / tiers
		local th = h / tiers * (1 + K.r(-0.15, 0.25))
		K.block(CF(pos + V3(K.r(-1, 1) * w * 0.08, y + th / 2, K.r(-1, 1) * d * 0.08)) * ANG(K.r(-0.05, 0.05), K.r(-0.4, 0.4), K.r(-0.06, 0.06)),
			V3(w * (0.4 + 0.6 * k), th, d * (0.4 + 0.6 * k)), K.dark(col, i * 0.05), mat or M.Slate, collide ~= false)
		y += th * 0.92
	end
	return y
end
-- small boulder cluster (2-3 rotated blocks)
function K.boulder(pos, s, col, mat, capCol)
	local n = K.ri(2, 3)
	for i = 1, n do
		local sz = V3(K.r(2.2, 3.6), K.r(1.4, 2.6), K.r(2.2, 3.6)) * s * (1 - (i - 1) * 0.22)
		local cf = CF(pos + V3(K.r(-1, 1) * s, sz.Y / 2 - 0.3 * s, K.r(-1, 1) * s)) * ANG(K.r(-0.12, 0.12), K.r(0, PI), K.r(-0.12, 0.12))
		K.block(cf, sz, K.dark(col, K.r(0, 0.15)), mat or M.Slate, i == 1)
		if capCol and i == 1 then K.block(cf * CF(0, sz.Y / 2 + 0.15, 0), V3(sz.X * 0.8, 0.3, sz.Z * 0.8), capCol, M.SmoothPlastic) end
	end
end

---------------------------------------------------------------- architecture
-- column with plinth + capital (optionally a second colour for the capital/band)
function K.column(pos, h, w, col, mat, capCol, collide)
	K.block(CF(pos + V3(0, 0.6, 0)), V3(w * 1.5, 1.2, w * 1.5), col, mat, collide ~= false)
	K.block(CF(pos + V3(0, 1.45, 0)), V3(w * 1.25, 0.5, w * 1.25), capCol or col, mat)
	K.block(CF(pos + V3(0, h / 2, 0)), V3(w, h, w), col, mat, collide ~= false)
	K.block(CF(pos + V3(0, h - 0.95, 0)), V3(w * 1.25, 0.5, w * 1.25), capCol or col, mat)
	K.block(CF(pos + V3(0, h + 0.3, 0)), V3(w * 1.55, 1.2, w * 1.55), col, mat)
end
-- round arch in the cf's XY plane: piers (plinth + capital) and voussoir ring with keystone.
-- span = inner width, h = spring height, thick = depth along Z. trim = optional neon/metal inner line colour.
function K.arch(cf, span, h, thick, col, mat, trim, trimMat, segs)
	local pw = math.max(2, thick * 0.9)
	for s = -1, 1, 2 do
		local x = s * (span / 2 + pw / 2)
		K.block(cf * CF(x, 0.8, 0), V3(pw * 1.35, 1.6, thick * 1.2), K.dark(col, 0.08), mat, true)
		K.block(cf * CF(x, h / 2, 0), V3(pw, h, thick), col, mat, true)
		K.block(cf * CF(x, h - 0.4, 0), V3(pw * 1.3, 0.8, thick * 1.15), K.light(col, 0.06), mat)
	end
	local r = span / 2 + pw / 2
	segs = segs or 9
	for i = 1, segs do
		local a0, a1 = (i - 1) / segs * PI, i / segs * PI
		local p0, p1 = V3(math.cos(a0) * r, h + math.sin(a0) * r, 0), V3(math.cos(a1) * r, h + math.sin(a1) * r, 0)
		local mid, dir = (p0 + p1) / 2, p1 - p0
		local key = i == math.ceil(segs / 2)
		K.block(cf * CF(mid) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude + 0.35, pw * (key and 1.35 or 1), thick * (key and 1.12 or 1)),
			key and K.light(col, 0.1) or col, mat)
		if trim then
			local inner = (p0 + p1) / 2 * ((r - pw / 2 - 0.1) / r) + V3(0, h * (1 - (r - pw / 2 - 0.1) / r), 0)
			K.block(cf * CF(inner) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude * 0.95, 0.3, thick + 0.1), trim, trimMat or M.Neon)
		end
	end
end
-- gothic pointed arch (two leaning straight halves meeting at a point)
function K.pointedArch(cf, span, h, rise, thick, col, mat, trim)
	for s = -1, 1, 2 do
		K.block(cf * CF(s * (span / 2 + 1), h / 2, 0), V3(2, h, thick), col, mat, true)
		local p0, p1 = V3(s * (span / 2 + 1), h, 0), V3(0, h + rise, 0)
		local mid, dir = (p0 + p1) / 2, p1 - p0
		K.block(cf * CF(mid) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude + 1.6, 2, thick), col, mat)
		if trim then K.block(cf * CF(mid - V3(0, 1.1, 0)) * ANG(0, 0, math.atan2(dir.Y, dir.X)), V3(dir.Magnitude, 0.3, thick + 0.1), trim, M.Neon) end
	end
end
-- straight stairs going up along cf -Z (front), n steps
function K.stairs(cf, w, n, rise, run, col, mat)
	for i = 0, n - 1 do
		K.block(cf * CF(0, (i + 1) * rise / 2, -(i + 0.5) * run + n * run / 2), V3(w, rise * (i + 1), run), i % 2 == 0 and col or K.dark(col, 0.04), mat, true)
	end
end
-- violet/gold civilisation banner on a pole (the hub motif, used sparingly in biomes)
function K.banner(pos, h, cloth, trim, faceYaw, emblem)
	local pole = C(60, 52, 74)
	K.block(CF(pos + V3(0, h / 2, 0)), V3(0.5, h, 0.5), pole, M.Metal)
	K.pyramid(CF(pos + V3(0, h, 0)), 0.9, 1.2, trim, M.Metal)
	local cf = CF(pos + V3(0, h - 1, 0)) * ANG(0, faceYaw or 0, 0)
	K.block(cf * CF(0, 0, -1.6), V3(0.3, 0.3, 3.6), trim, M.Metal)
	local b = K.block(cf * CF(0, -3.2, -1.6), V3(0.18, 5.8, 2.8), cloth, M.Fabric)
	K.wedge(cf * CF(0, -6.6, -2.3) * ANG(PI, 0, 0), V3(0.18, 1, 1.4), cloth, M.Fabric)
	K.wedge(cf * CF(0, -6.6, -0.9) * ANG(PI, PI, 0), V3(0.18, 1, 1.4), cloth, M.Fabric)
	K.block(cf * CF(0, -0.75, -1.6), V3(0.22, 0.3, 2.9), trim, M.Metal)
	if emblem ~= false then K.block(cf * CF(0, -3.2, -1.6) * ANG(PI / 4, 0, 0), V3(0.24, 1.3, 1.3), trim, M.Neon) end
	K.tag(b, "TPFC_Sway", { Amp = 0.03, Period = K.r(5, 7) })
end
-- lantern post with warm glass lantern and one light
function K.lantern(pos, iron, glow, h)
	h = h or 8
	iron = iron or C(48, 44, 56)
	glow = glow or C(255, 205, 140)
	K.block(CF(pos + V3(0, 0.4, 0)), V3(1.4, 0.8, 1.4), iron, M.Metal, true)
	K.block(CF(pos + V3(0, h / 2, 0)), V3(0.45, h, 0.45), iron, M.Metal, true)
	K.block(CF(pos + V3(0, h + 0.1, 0)), V3(1.3, 0.25, 1.3), iron, M.Metal)
	local g = K.block(CF(pos + V3(0, h + 0.9, 0)), V3(0.95, 1.3, 0.95), glow, M.Glass, false, 0.1)
	K.pyramid(CF(pos + V3(0, h + 1.6, 0)), 1.4, 0.8, iron, M.Metal)
	K.lamp(g, glow, 16, 1)
	return g
end

---------------------------------------------------------------- nature
-- chunky stylised leaf clump (the reference's cartoon canopy: stacked rotated blocks)
local function clump(pos, s, col, sway)
	local b = K.block(CF(pos) * ANG(K.r(-0.1, 0.1), K.r(0, PI), K.r(-0.1, 0.1)), V3(K.r(5, 7), K.r(2.6, 3.6), K.r(5, 7)) * s, col, M.SmoothPlastic)
	K.block(CF(pos + V3(K.r(-0.6, 0.6) * s, 1.4 * s, K.r(-0.6, 0.6) * s)) * ANG(0, K.r(0, PI), 0), V3(K.r(3.4, 4.6), K.r(1.6, 2.2), K.r(3.4, 4.6)) * s, K.light(col, 0.12), M.SmoothPlastic)
	if sway then K.tag(b, "TPFC_Sway", { Amp = 0.008, Period = K.r(5, 8) }) end
	return b
end
K.clump = clump
-- broadleaf tree: flared trunk, 2-3 forked boughs ending in leaf clumps (variants by seed)
function K.tree(pos, s, leaf, bark, sway)
	leaf = leaf or C(98, 176, 70)
	bark = bark or C(118, 82, 52)
	local h = K.r(7, 10) * s
	K.block(CF(pos + V3(0, 0.6 * s, 0)) * ANG(0, PI / 4, 0), V3(2.6, 1.2, 2.6) * s, K.dark(bark, 0.1), M.Wood) -- root flare
	K.block(CF(pos + V3(0, h / 2, 0)), V3(1.6, h, 1.6) * s, bark, M.Wood, true)
	local n = K.ri(2, 3)
	for i = 1, n do
		local a = i / n * PI * 2 + K.r(-0.4, 0.4)
		local tilt = K.r(0.45, 0.75)
		local len = K.r(3.5, 5) * s
		local base = pos + V3(0, h * K.r(0.75, 0.95), 0)
		local dir = (CF(base) * ANG(0, a, 0) * ANG(0, 0, tilt)).UpVector
		K.block(CF(base + dir * len / 2, base + dir * len) * ANG(PI / 2, 0, 0), V3(0.9 * s, len, 0.9 * s), bark, M.Wood)
		local tip = base + dir * len
		clump(tip + V3(0, 1.2 * s, 0), s * K.r(0.85, 1.1), leaf:Lerp(i % 2 == 0 and C(70, 140, 60) or C(150, 205, 95), K.r(0, 0.25)), sway)
	end
	clump(pos + V3(0, h + 2.6 * s, 0), s * 1.15, leaf, sway)
end
-- tiered conifer; snow = add white shelf caps
function K.pine(pos, s, col, snow, trunkCol)
	col = col or C(46, 112, 74)
	K.block(CF(pos + V3(0, 1.6 * s, 0)), V3(1.2, 3.2, 1.2) * s, trunkCol or C(104, 72, 48), M.Wood, true)
	for k = 0, 3 do
		local w = (7.5 - k * 1.6) * s
		local y = (3 + k * 2.4) * s
		local yaw = k * 0.6 + K.r(0, 0.3)
		K.block(CF(pos + V3(0, y, 0)) * ANG(0, yaw, 0), V3(w, 2.2 * s, w), K.dark(col, k * 0.03), M.SmoothPlastic)
		if snow then K.block(CF(pos + V3(0, y + 1.2 * s, 0)) * ANG(0, yaw, 0), V3(w * 0.82, 0.45 * s, w * 0.82), C(246, 250, 255), M.SmoothPlastic) end
	end
	K.pyramid(CF(pos + V3(0, (3 + 4 * 2.4 - 1.1) * s, 0)), 1.6 * s, 2.4 * s, col, M.SmoothPlastic)
end
function K.bush(pos, s, col)
	col = col or C(84, 156, 66)
	for i = 1, 3 do
		K.block(CF(pos + V3((i - 2) * 1.2 * s, (0.8 + (i == 2 and 0.4 or 0)) * s, K.r(-0.5, 0.5) * s)) * ANG(0, K.r(0, PI), 0),
			V3(K.r(2, 2.8), K.r(1.6, 2.2), K.r(2, 2.8)) * s, col:Lerp(C(140, 200, 90), K.r(0, 0.3)), M.SmoothPlastic)
	end
end
-- fern: crossed angled fronds
function K.fern(pos, s, col)
	col = col or C(70, 160, 70)
	for i = 0, 4 do
		local a = i / 5 * PI * 2 + K.r(-0.2, 0.2)
		K.wedge(CF(pos) * ANG(0, a, 0) * CF(0, 0.9 * s, -1.3 * s) * ANG(-0.5, 0, 0), V3(0.9, 0.2, 2.6) * s, col, M.SmoothPlastic)
	end
end
-- five-petal flower cluster (pink/white reference flowers) on leaves
function K.flowers(pos, s, petal, centre)
	petal = petal or C(255, 150, 200)
	centre = centre or C(255, 220, 90)
	K.block(CF(pos + V3(0, 0.25 * s, 0)) * ANG(0, K.r(0, PI), 0), V3(2.2, 0.5, 2.2) * s, C(80, 160, 70), M.SmoothPlastic)
	for f = 1, K.ri(2, 3) do
		local c = pos + V3(K.r(-0.8, 0.8) * s, (0.9 + f * 0.25) * s, K.r(-0.8, 0.8) * s)
		for i = 0, 4 do
			K.block(CF(c) * ANG(0, i / 5 * PI * 2, 0) * CF(0, 0, -0.38 * s) * ANG(-0.3, 0, 0), V3(0.42, 0.12, 0.6) * s, petal, M.SmoothPlastic)
		end
		K.block(CF(c + V3(0, 0.06 * s, 0)), V3(0.3, 0.16, 0.3) * s, centre, M.SmoothPlastic)
	end
end
function K.mushroom(pos, s, cap, glow)
	cap = cap or C(196, 92, 60)
	K.block(CF(pos + V3(0, 0.9 * s, 0)), V3(0.9, 1.8, 0.9) * s, C(244, 232, 214), M.SmoothPlastic)
	local c = K.block(CF(pos + V3(0, 2, 0) * s), V3(2.8, 0.9, 2.8) * s, cap, glow and M.Neon or M.SmoothPlastic)
	K.block(CF(pos + V3(0, 2.5, 0) * s), V3(1.8, 0.5, 1.8) * s, K.light(cap, 0.08), glow and M.Neon or M.SmoothPlastic)
	if not glow then
		for i = 1, 3 do K.block(CF(pos + V3(K.r(-0.9, 0.9), 2.5, K.r(-0.9, 0.9)) * s), V3(0.35, 0.55, 0.35) * s, C(255, 244, 230), M.SmoothPlastic) end
	end
	return c
end
-- grass tuft (spiky blades) for ground cover
function K.tuft(pos, s, col)
	for i = 0, 2 do
		K.wedge(CF(pos) * ANG(0, i * 1.1, 0) * CF(0, 0.5 * s, 0), V3(0.15, 1, 0.6) * s, col, M.SmoothPlastic)
	end
end

---------------------------------------------------------------- crystals
function K.crystal(base, len, w, col, tilt, glow, transp)
	local cf = CF(base) * (tilt or CF())
	local body = K.block(cf * CF(0, len * 0.31, 0) * ANG(0, PI / 4, 0), V3(w, len * 0.62, w), col, glow and M.Neon or M.Glass, false, glow and 0 or (transp or 0.05))
	K.pyramid(cf * CF(0, len * 0.62, 0) * ANG(0, PI / 4, 0), w, len * 0.38, K.light(col, 0.2), glow and M.Neon or M.Glass)
	return body
end
function K.crystalCluster(base, s, cols, glowIndex)
	local core
	for i = 0, 4 do
		local a = i / 5 * PI * 2
		local c = K.crystal(base + V3(math.cos(a) * 1.1 * s, -0.3, math.sin(a) * 1.1 * s), K.r(3, 5) * s * (i == 0 and 1.5 or 1), K.r(1.1, 1.5) * s,
			cols[(i % #cols) + 1], ANG(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35), i == glowIndex)
		if i == 0 then core = c end
	end
	return core
end

---------------------------------------------------------------- water
function K.water(cf, size, col, transp)
	local w = K.block(cf, size, col or C(90, 205, 225), M.Glass, false, transp or 0.3)
	w.CastShadow = false
	return w
end
-- stepped waterfall falling along -Y from top, facing faceDir (unit X or Z vector); foam at the base
function K.waterfall(top, h, w, faceYaw, col, foamCol)
	col = col or C(140, 220, 240)
	local cf = CF(top) * ANG(0, faceYaw or 0, 0)
	local n = math.max(2, math.floor(h / 6))
	for i = 0, n - 1 do
		local seg = K.block(cf * CF(0, -(i + 0.5) * h / n, -i * 0.15), V3(w, h / n + 0.2, 0.8), i % 2 == 0 and col or K.light(col, 0.15), M.Glass, false, 0.15)
		seg.CastShadow = false
		if i % 2 == 0 then K.tag(seg, "TPFC_Pulse", { Period = K.r(3, 5), Base = 0.15, Peak = 0.02 }) end
	end
	for i = -1, 1 do
		K.block(cf * CF(i * w * 0.32, -h + 0.4, -1.4) * ANG(0, K.r(0, 1), 0), V3(w * 0.4, 0.9, 1.8), foamCol or C(240, 250, 255), M.SmoothPlastic)
	end
end

---------------------------------------------------------------- big landscape generators
-- Stepped side terraces (the reference diorama silhouette): along both sides of z1..z2,
-- tier 1 is low (top <= 4.5) from |X| >= 46; taller tiers start at |X| >= 56.
-- P = { rock, rockMat, cap, capMat, drip (bool), skip = { {side, z1, z2}, ... }, tiers (2|3),
--       h1 = {min,max}, h2 = {min,max}, h3 = {min,max}, edge = optional fn(pos, side) for lane-edge props }
function K.terraces(z1, z2, P)
	local rock, cap = P.rock, P.cap
	local rockMat, capMat = P.rockMat or M.Slate, P.capMat or M.SmoothPlastic
	local function skipped(s, za, zb)
		for _, sk in ipairs(P.skip or {}) do
			if sk[1] == s and zb > sk[2] and za < sk[3] then return true end
		end
		return false
	end
	for s = -1, 1, 2 do
		local z = z1
		while z < z2 - 2 do
			local len = math.min(K.r(14, 24), z2 - z)
			local za, zb = z, z + len
			local zc = (za + zb) / 2
			if not skipped(s, za, zb) then
				-- tier 1: low shelf at the lane edge
				local x1 = K.r(46, 50)
				local y1 = K.r(P.h1 and P.h1[1] or 2.2, P.h1 and P.h1[2] or 4.2)
				local outer = 86
				local col1 = rock:Lerp(K.dark(rock, 0.12), K.r(0, 1))
				K.block(CF(s * (x1 + outer) / 2, (y1 - 6) / 2, zc), V3(outer - x1, y1 + 6, len + 0.4), col1, rockMat, true)
				local capJ = cap:Lerp(K.dark(cap, 0.25), K.r(0, 0.5))
				K.block(CF(s * ((x1 + outer) / 2 - 0.4), y1 + 0.35, zc), V3(outer - x1 + 0.8, 0.7, len + 0.6), capJ, capMat, true)
				K.addSurface(s * x1, s * outer, za, zb, y1 + 0.7)
				if P.drip and K.chance(0.7) then
					for _ = 1, K.ri(1, 2) do
						local dz = K.r(za + 1.5, zb - 1.5)
						local dh = K.r(1, 2.4)
						K.block(CF(s * (x1 - 0.15), y1 - dh / 2 + 0.2, dz), V3(0.5, dh, K.r(1.2, 2.6)), cap, capMat)
					end
				end
				-- tier 2: taller shelf set back (staggered ends)
				local x2 = math.max(56, x1 + K.r(8, 14))
				local y2 = y1 + K.r(P.h2 and P.h2[1] or 5, P.h2 and P.h2[2] or 10)
				local i0, i1 = K.r(0, 3), K.r(0, 3)
				local l2 = len - i0 - i1
				if l2 > 6 then
					local z2c = za + i0 + l2 / 2
					K.block(CF(s * (x2 + 104) / 2, y2 / 2 - 1, z2c), V3(104 - x2, y2 + 2, l2), rock:Lerp(K.dark(rock, 0.18), K.r(0, 1)), rockMat, true)
					K.block(CF(s * ((x2 + 104) / 2 - 0.4), y2 + 0.4, z2c), V3(104 - x2 + 0.8, 0.8, l2 + 0.3), cap:Lerp(K.light(cap, 0.2), K.r(0, 0.5)), capMat)
					K.addSurface(s * x2, s * 104, z2c - l2 / 2, z2c + l2 / 2, y2 + 0.8)
					if P.drip and K.chance(0.6) then
						local dh = K.r(1.5, 3.5)
						K.block(CF(s * (x2 - 0.15), y2 - dh / 2 + 0.2, K.r(za + i0 + 1, za + i0 + l2 - 1)), V3(0.5, dh, K.r(1.5, 3)), cap, capMat)
					end
					-- tier 3: high ridge (optional)
					if (P.tiers or 2) >= 3 and K.chance(0.65) then
						local x3 = x2 + K.r(10, 18)
						local y3 = y2 + K.r(P.h3 and P.h3[1] or 6, P.h3 and P.h3[2] or 16)
						local l3 = l2 * K.r(0.55, 0.9)
						local z3c = za + i0 + K.r(0, l2 - l3) + l3 / 2
						K.block(CF(s * (x3 + 118) / 2, y3 / 2, z3c), V3(118 - x3, y3, l3), K.dark(rock, K.r(0.05, 0.25)), rockMat, true)
						K.block(CF(s * ((x3 + 118) / 2 - 0.4), y3 + 0.4, z3c), V3(118 - x3 + 0.8, 0.8, l3 + 0.3), cap, capMat)
						K.addSurface(s * x3, s * 118, z3c - l3 / 2, z3c + l3 / 2, y3 + 0.8)
					end
				end
				if P.facade then P.facade(s, x1, y1 + 0.7, za, zb) end
				if P.edge then P.edge(V3(s * K.r(41, 44.5), 0, K.r(za + 2, zb - 2)), s) end
			end
			z += len
		end
	end
end
-- distant blocky mountains (terrain wedges) beyond the terraces, skyline only
function K.mountains(z1, z2, mat, xMin, xMax, hMin, hMax)
	local T = K.terrain
	for s = -1, 1, 2 do
		local z = z1
		while z < z2 do
			local w = K.r(50, 90)
			local h = K.r(hMin or 40, hMax or 110)
			local x = s * K.r(xMin or 130, xMax or 190)
			local cf = CF(x, h / 2 - 8, z + w / 2) * ANG(0, K.r(-0.3, 0.3), 0)
			T:FillWedge(cf, V3(w, h, w * 0.6), mat)
			T:FillWedge(cf * ANG(0, PI, 0), V3(w, h, w * 0.6), mat)
			z += w * K.r(0.55, 0.8)
		end
	end
end

---------------------------------------------------------------- signage
do
	local ok, f = pcall(function() return Enum.Font.MontserratBlack end)
	K.SIGN_FONT = ok and f or Enum.Font.GothamBlack
end
function K.textSurface(p, text, color, face, font, stroke)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 120)
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = font or K.SIGN_FONT
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 2.5; st.Transparency = 0.15; st.Color = stroke or C(30, 20, 40); st.Parent = t
	t.Parent = sg
	sg.Parent = p
	return t
end

---------------------------------------------------------------- DETAIL KIT (reference-matching pieces)
-- bevelled cut stone: body + inset top + 4 chamfer wedges; optional moss cap with drapes
function K.bevel(cf, size, col, mat, moss, collide)
	mat = mat or M.Limestone
	local b = 0.6
	K.block(cf * CF(0, -b / 2, 0), V3(size.X, size.Y - b, size.Z), col, mat, collide ~= false)
	K.block(cf * CF(0, size.Y / 2 - b / 2, 0), V3(size.X - 2 * b, b, size.Z - 2 * b), K.light(col, 0.06), mat)
	local hx, hz, y = size.X / 2 - b / 2, size.Z / 2 - b / 2, size.Y / 2 - b / 2
	K.wedge(cf * CF(hx, y, 0) * ANG(0, -PI / 2, 0), V3(size.Z - 2 * b, b, b), col, mat)
	K.wedge(cf * CF(-hx, y, 0) * ANG(0, PI / 2, 0), V3(size.Z - 2 * b, b, b), col, mat)
	K.wedge(cf * CF(0, y, hz) * ANG(0, PI, 0), V3(size.X - 2 * b, b, b), col, mat)
	K.wedge(cf * CF(0, y, -hz), V3(size.X - 2 * b, b, b), col, mat)
	if moss then
		K.block(cf * CF(K.r(-0.3, 0.3), size.Y / 2 + 0.1, K.r(-0.3, 0.3)), V3(size.X * K.r(0.6, 0.95), 0.3, size.Z * K.r(0.6, 0.95)), moss, M.SmoothPlastic)
		for _ = 1, K.ri(0, 1) do
			local side = K.ri(1, 4)
			local dh = K.r(0.8, size.Y * 0.6)
			local off = side <= 2 and CF((side == 1 and 1 or -1) * (size.X / 2 + 0.08), size.Y / 2 - dh / 2, K.r(-size.Z / 3, size.Z / 3))
				or CF(K.r(-size.X / 3, size.X / 3), size.Y / 2 - dh / 2, (side == 3 and 1 or -1) * (size.Z / 2 + 0.08))
			K.block(cf * off, V3(side <= 2 and 0.2 or K.r(0.8, 1.8), dh, side <= 2 and K.r(0.8, 1.8) or 0.2), moss, M.SmoothPlastic)
		end
	end
end
-- chain of tapered blocks along a quadratic bezier (curved trunks, limbs, roots); returns end, middle
function K.limb(p0, p1, p2, r0, r1, n, col, mat, collide)
	local function bz(t) return p0 * (1 - t) ^ 2 + p1 * 2 * (1 - t) * t + p2 * t * t end
	for i = 0, n - 1 do
		local a, b = bz(i / n), bz((i + 1) / n)
		local r = r0 + (r1 - r0) * (i + 0.5) / n
		local len = (b - a).Magnitude
		if len > 0.05 then
			K.block(CFrame.lookAt((a + b) / 2, b) * ANG(0, 0, (i % 2) * PI / 4), V3(r, r, len + r * 0.5), col, mat or M.Wood, collide == true and i < 2)
		end
	end
	return bz(1), bz(0.5)
end
-- leaf rosette: rounded core + highlight cap + pointed leaves fanning out (the reference canopy lobe)
function K.rosette(pos, s, col, sway)
	local hi, sh = K.light(col, 0.18), K.dark(col, 0.22)
	local core = K.ellipsoid(CF(pos), V3(5, 3.8, 5) * s, sh, M.SmoothPlastic)
	K.ellipsoid(CF(pos + V3(0.3 * s, 0.9 * s, 0.2 * s)), V3(4.2, 3.2, 4.2) * s, col, M.SmoothPlastic)
	K.ellipsoid(CF(pos + V3(-0.5 * s, 1.7 * s, -0.4 * s)), V3(2.8, 2.2, 2.8) * s, hi, M.SmoothPlastic)
	local off = K.r(0, PI)
	for i = 0, 3 do
		local a = off + i / 4 * PI * 2
		local up = (i % 2 == 0) and 0.6 or -0.4
		K.wedge(CF(pos + V3(0, up * s, 0)) * ANG(0, a, 0) * CF(0, 0, -2.6 * s) * ANG(-0.35 + up * 0.3, 0, 0), V3(1.7, 0.45, 2.3) * s, i % 2 == 0 and col or sh, M.SmoothPlastic)
	end
	if sway then K.tag(core, "TPFC_Sway", { Amp = 0.006, Period = K.r(5, 8) }) end
	return core
end
-- canopy cloud: n rosettes scattered in an ellipsoid dome around centre
function K.canopy(centre, rx, ry, n, s, cols, sway)
	for i = 1, n do
		local a = K.r(0, PI * 2)
		local d = math.sqrt(K.r(0, 1))
		local y = K.r(-0.4, 1) * ry
		local k = 1 - math.max(0, y / ry) * 0.5
		K.rosette(centre + V3(math.cos(a) * d * rx * k, y, math.sin(a) * d * rx * k), s * K.r(0.85, 1.15), K.pick(cols), sway and i % 3 == 0)
	end
end
-- broadleaf tree: curved trunk with root flare, forked limbs, rosette canopy (leanDir = unit-ish lean)
function K.bigTree(pos, s, cols, bark, leanDir)
	bark = bark or C(126, 86, 54)
	local barkD = K.dark(bark, 0.2)
	leanDir = leanDir or V3(0, 0, 0)
	for i = 0, 4 do
		local a = i / 5 * PI * 2 + K.r(-0.3, 0.3)
		local d = V3(math.cos(a), 0, math.sin(a))
		K.limb(pos + V3(0, 2.2 * s, 0), pos + d * 1.8 * s + V3(0, 0.8 * s, 0), pos + d * 4.2 * s + V3(0, -0.3, 0), 1.3 * s, 0.6 * s, 2, barkD)
	end
	local top = pos + leanDir * 4 * s + V3(0, 11 * s, 0)
	K.limb(pos, pos + V3(0, 6 * s, 0) - leanDir * 1.5 * s, top, 2.6 * s, 1.7 * s, 5, bark, M.Wood, true)
	local nl = K.ri(4, 5)
	for i = 1, nl do
		local a = i / nl * PI * 2 + K.r(-0.3, 0.3)
		local d = V3(math.cos(a), 0, math.sin(a)) + leanDir * 0.4
		local tip = top + d * K.r(8, 11) * s + V3(0, K.r(3, 6) * s, 0)
		local _, mid = K.limb(top - V3(0, 1.5 * s, 0), top + d * 3 * s + V3(0, 3.5 * s, 0), tip, 1.3 * s, 0.6 * s, 3, bark)
		K.limb(mid, mid + d * 2 * s + V3(0, 2 * s, 0), mid + V3(-d.Z, 0, d.X) * 4 * s + V3(0, 4 * s, 0), 0.6 * s, 0.35 * s, 2, barkD)
		K.canopy(tip + V3(0, 1.5 * s, 0), 3.5 * s, 2 * s, 3, 0.95 * s, cols, true)
	end
	K.canopy(top + V3(0, 7 * s, 0), 6 * s, 3 * s, 6, 1.05 * s, cols, true)
end
-- big lily clump: ground leaves + 2-3 six-petal flowers on stems
function K.lily(pos, s, petal, inner)
	petal = petal or C(255, 170, 205)
	inner = inner or C(236, 90, 150)
	for i = 0, 2 do
		local a = i / 3 * PI * 2 + K.r(-0.2, 0.2)
		K.ellipsoid(CF(pos) * ANG(0, a, 0) * CF(0, 0.25 * s, -1.2 * s) * ANG(-0.15, 0, 0), V3(1.3, 0.25, 2.4) * s, C(78, 150, 64), M.SmoothPlastic)
	end
	for f = 1, K.ri(1, 2) do
		local c = pos + V3(K.r(-0.9, 0.9) * s, (1.2 + f * 0.5) * s, K.r(-0.9, 0.9) * s)
		K.block(CF((pos + c) / 2), V3(0.18 * s, (c - pos).Y, 0.18 * s), C(90, 160, 70), M.SmoothPlastic)
		local yaw = K.r(0, PI)
		for i = 0, 5 do
			local pcf = CF(c) * ANG(0, yaw + i / 6 * PI * 2, 0) * CF(0, 0.25 * s, -0.75 * s) * ANG(0.55, 0, 0)
			K.ellipsoid(pcf, V3(0.7, 0.16, 1.6) * s, petal, M.SmoothPlastic)
		end
		K.block(CF(c + V3(0, 0.3 * s, 0)), V3(0.35, 0.5, 0.35) * s, C(255, 214, 90), M.SmoothPlastic)
	end
end
-- spotted mushroom (dome cap, gills, cream spots)
function K.toadstool(pos, s, cap)
	cap = cap or C(176, 92, 58)
	K.vcyl(pos, 2.4 * s, 1.1 * s, C(246, 234, 214), M.SmoothPlastic)
	K.vcyl(pos, 0.5 * s, 1.5 * s, C(236, 222, 200), M.SmoothPlastic)
	K.ellipsoid(CF(pos + V3(0, 2.5 * s, 0)), V3(3.6, 0.5, 3.6) * s, C(236, 214, 186), M.SmoothPlastic)
	K.ellipsoid(CF(pos + V3(0, 2.9 * s, 0)), V3(4, 2.2, 4) * s, cap, M.SmoothPlastic)
	for i = 0, 4 do
		local a = i / 5 * PI * 2 + K.r(0, 1)
		local r = K.r(0.6, 1.3) * s
		K.ellipsoid(CF(pos + V3(math.cos(a) * r, 3.75 * s - r * 0.25, math.sin(a) * r)), V3(0.6, 0.2, 0.6) * s, C(252, 240, 220), M.SmoothPlastic)
	end
end
-- arching fern: seven fronds of three bending segments
function K.fernBig(pos, s, col)
	col = col or C(74, 150, 60)
	for i = 0, 6 do
		local a = i / 7 * PI * 2 + K.r(-0.2, 0.2)
		local cf = CF(pos) * ANG(0, a, 0)
		local p = CF(0, 0.2 * s, 0) * ANG(0.9, 0, 0)
		for k = 0, 2 do
			local seg = 1.3 * s * (1 - k * 0.15)
			local w = (1.2 - k * 0.3) * s
			K.wedge(cf * p * CF(0, 0, -seg / 2) * ANG(0, PI, 0), V3(w, 0.15, seg), k == 1 and K.light(col, 0.12) or col, M.SmoothPlastic)
			p = p * CF(0, 0, -seg) * ANG(-0.45, 0, 0)
		end
	end
end
-- clover patch (flush trefoil)
function K.clover(pos, s, col)
	col = col or C(110, 176, 72)
	for i = 0, 2 do
		local a = i / 3 * PI * 2
		K.ellipsoid(CF(pos + V3(math.cos(a) * 0.45 * s, 0.1, math.sin(a) * 0.45 * s)), V3(0.9, 0.12, 0.9) * s, col, M.SmoothPlastic)
	end
end
-- hanging vine with leaves
function K.vine(top, len, col)
	col = col or C(84, 156, 62)
	K.block(CF(top - V3(0, len / 2, 0)), V3(0.18, len, 0.18), K.dark(col, 0.2), M.SmoothPlastic)
	for y = 0.6, len, 1.1 do
		K.ellipsoid(CF(top - V3(0, y, 0)) * ANG(0, K.r(0, PI), 0.4) * CF(0.35, 0, 0), V3(0.8, 0.15, 0.5), col, M.SmoothPlastic)
	end
end
-- carved relief leaf glyph on a face (cf = centre on the face, glyph plane = cf XY)
function K.leafGlyph(cf, s, col)
	K.block(cf * ANG(0, 0, PI / 4), V3(1.1, 1.1, 0.12) * s, col, M.Limestone)
	K.block(cf * CF(0, -0.9 * s, 0), V3(0.18, 0.8, 0.12) * s, col, M.Limestone)
	K.block(cf * CF(0, 0.1 * s, -0.04), V3(0.12, 1.1, 0.12) * s, K.dark(col, 0.15), M.Limestone)
end

-- faceted cone (n wedge facets sloping outward from the apex) — volcanoes, jagged peaks, crystal mounds
function K.cone(pos, R, H, n, colA, colB, mat, collide)
	local off = K.r(0, PI)
	for i = 0, n - 1 do
		local a = off + i / n * PI * 2
		local dir = V3(math.cos(a), 0, math.sin(a))
		local mid = pos + dir * R * 0.5 + V3(0, H / 2, 0)
		K.wedge(CFrame.lookAt(mid, mid + dir), V3(2 * PI * R / n * 1.12, H, R), (i % 2 == 0) and colA or (colB or colA), mat or M.Slate, collide == true)
	end
	return pos + V3(0, H, 0)
end

---------------------------------------------------------------- biome gate
-- themed biome gate: two pylons at |X| = 58 with name plaques facing the hall (shared by all biomes)
function K.gate(text, z, stone, mat, glow, cap)
	for s = -1, 1, 2 do
		local x = s * 58
		K.block(CF(x, 1.2, z), V3(10, 2.4, 10), K.dark(stone, 0.1), mat, true)
		K.block(CF(x, 15, z), V3(6.5, 26, 6.5), stone, mat, true)
		K.block(CF(x, 28.6, z), V3(8, 1.4, 8), cap or stone, mat)
		K.pyramid(CF(x, 29.3, z), 6.4, 6, C(232, 190, 90), M.Metal)
		local strip = K.block(CF(x - s * 3.3, 15, z), V3(0.25, 20, 1.4), glow, M.Neon, false, 0.15)
		K.tag(strip, "TPFC_Pulse", { Period = 9, Base = 0.3, Peak = 0.05 })
		local plaque = K.block(CF(x, 19, z - 3.4), V3(9.5, 3.4, 0.5), C(58, 40, 92), M.SmoothPlastic)
		K.block(CF(x, 20.85, z - 3.4), V3(10, 0.3, 0.6), C(232, 190, 90), M.Metal)
		K.block(CF(x, 17.15, z - 3.4), V3(10, 0.3, 0.6), C(232, 190, 90), M.Metal)
		K.textSurface(plaque, text, C(255, 240, 200), Enum.NormalId.Front)
	end
end

return K
