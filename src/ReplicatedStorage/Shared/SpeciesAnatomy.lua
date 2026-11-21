-- SpeciesAnatomy: species-specific anatomy for every creature + extra body plans.
-- Location: ReplicatedStorage > Shared > SpeciesAnatomy (ModuleScript)
--
-- Each builder is called as A[key](H, rig, vd, s, prof) AFTER the generic body plan, face,
-- ears, horns, tail, wings and extras exist. H = CreatureBuilder.H (part helpers).
-- Builders add geometry and register rig channels:
--   rig.chains  (via H.chain)   kinds: neck | spine | tentacle | trail | fan | fluke | plume | echo
--   rig.groups  open (entries with openAxis/openAmt react to pose.open), flutter, orbit,
--               lag, fragments, rays, clockRings, seed, ...
--   rig.glows   { part, base, bright }   -> pose.glow lerps colour
--   rig.reveal  { {parts...}, ... }      -> pose.hide fades units out in order (LocalTransparencyModifier)
-- All chains extend along their pivot's local +Z unless rec.axisMode == "y".

local A = {}
local Plans = {}
A.Plans = Plans

local PI = math.pi
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local WHITE = Color3.new(1, 1, 1)
local function C(h) return Color3.fromHex(h) end

---------------------------------------------------------------- helpers
local function openable(H, rig, e, axis, amt)
	e.openAxis, e.openAmt = axis, amt
	H.group(rig, "open", e)
	return e
end

local function glow(rig, part, bright)
	rig.glows = rig.glows or {}
	table.insert(rig.glows, { part = part, base = part.Color, bright = bright or WHITE })
end

-- run fn, return every part created during it (a "unit" for reveal)
local function unitOf(rig, fn)
	local a = #rig.all
	fn()
	local list = {}
	for i = a + 1, #rig.all do table.insert(list, rig.all[i].part) end
	return list
end

-- every part welded (directly or indirectly) below `roots`, roots included
local function subtree(rig, roots)
	local children = {}
	for _, e in ipairs(rig.all) do
		local p0 = e.w.Part0
		children[p0] = children[p0] or {}
		table.insert(children[p0], e.part)
	end
	local out, stack = {}, {}
	for _, r in ipairs(roots) do table.insert(stack, r) end
	while #stack > 0 do
		local p = table.remove(stack)
		table.insert(out, p)
		for _, c in ipairs(children[p] or {}) do table.insert(stack, c) end
	end
	return out
end

local function reveal(rig, parts)
	rig.reveal = rig.reveal or {}
	table.insert(rig.reveal, parts)
end

-- segmented chain along local +Z of c0first
local function zchain(H, rig, parent, name, c0first, n, segLen, radAt, colAt, meta, matAt, trAt)
	local rec = H.chain(rig, parent, name, c0first, n, function(j, nn)
		local t = (j - 1) / math.max(1, nn - 1)
		local r = radAt(t, j)
		return V3(r * 2, r * 2, segLen * 1.4), colAt(t, j), matAt and matAt(t, j) or nil, trAt and trAt(t, j) or 0,
			CF(0, 0, segLen * 0.55), CF(0, 0, -segLen * 0.5)
	end, meta)
	return rec
end

local function aurora(t)
	local cols = { C("#7CFFCB"), C("#8CA0FF"), C("#FF8CF0"), C("#FFFFFF") }
	local i = math.clamp(math.floor(t * 3.999) + 1, 1, 4)
	return cols[i]
end

---------------------------------------------------------------- EXTRA BODY PLANS
-- Magma Kraken: bulbous mantle + 8 articulated tentacles
function Plans.kraken(H, rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local br = V3(1.15, 1.35, 1.1) * s
	local e, body = H.ell(rig, rig.root, "Body", br * 2, p, CF(0, 2.4 * s, 0) * ANG(0.25, 0, 0), Enum.Material.Neon, 0)
	rig.bodyEntry = e
	-- darker crust bands so the neon mantle keeps a readable silhouette
	for i = 0, 2 do
		H.ell(rig, body, "MantleBand", V3(br.X * 2.04, 0.28 * s, br.Z * 2.04) * (1 - i * 0.12), H.darken(p, 0.55), CF(0, br.Y * (0.15 + i * 0.3), 0.05 * s))
	end
	H.ell(rig, body, "Underside", V3(br.X * 1.7, br.Y * 0.8, br.Z * 1.7), sc, CF(0, -br.Y * 0.62, 0))
	H.ell(rig, body, "Beak", V3(0.4, 0.3, 0.4) * s, a, CF(0, -br.Y * 0.95, -0.05 * s))
	rig.legKind = "none"
	for i = 1, 8 do
		local ang = (i - 0.5) / 8 * PI * 2
		local pos = V3(math.sin(ang) * br.X * 0.7, -br.Y * 0.75, -math.cos(ang) * br.Z * 0.7)
		local dir = V3(math.sin(ang) * 0.8, -0.6, -math.cos(ang) * 0.8).Unit
		local c0 = CFrame.lookAt(pos, pos - dir) -- +Z points along dir
		local rec = zchain(H, rig, body, "Tentacle", c0, 5, 0.55 * s, function(t) return (0.34 - t * 0.24) * s end,
			function(t) return t > 0.75 and sc or p end, { kind = "tentacle", i = i, side = math.sin(ang) >= 0 and 1 or -1, amp = 0.35, freq = 1.4, lag = 0.7 },
			function() return Enum.Material.SmoothPlastic end)
		for j = 1, 2 do -- simplified suckers
			H.ell(rig, rec.parts[j], "Sucker", V3(0.18, 0.18, 0.12) * s, H.lighten(sc, 0.3), CF(0, -0.22 * s * (1 - j * 0.2), 0))
		end
		H.group(rig, "tentacles", rec)
		reveal(rig, rec.parts)
	end
	return body, body, br, br, -0.2 * s, CF(0, 0, br.Z), 0.3 * s
end

-- Amethyst Eel: head + 7-segment body chain + crystal ridge + tail fin
function Plans.eel(H, rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local br = V3(0.7, 0.62, 0.85) * s
	local e, body = H.ell(rig, rig.root, "Body", br * 2, p, CF(0, 1.6 * s, -1.6 * s))
	rig.bodyEntry = e
	H.ell(rig, body, "Jaw", V3(1.2, 0.5, 1.4) * s, sc, CF(0, -0.32 * s, -0.15 * s))
	rig.legKind = "none"
	local rec = zchain(H, rig, body, "Spine", CF(0, 0, br.Z * 0.8), 7, 0.62 * s, function(t) return (0.6 - t * 0.38) * s end,
		function(t, j) return j % 2 == 0 and p or H.lighten(p, 0.08) end, { kind = "spine", i = 1, amp = 0.35, freq = 2.2, lag = 0.65 })
	for j, part in ipairs(rec.parts) do
		H.ell(rig, part, "BellyStrip", V3(0.7, 0.45, 0.9) * s * (1 - j * 0.07), sc, CF(0, -0.22 * s * (1 - j * 0.06), 0))
		if j <= 5 then H.crystal(rig, part, "Ridge", (0.55 - j * 0.05) * s, 0.18 * s, a, CF(0, 0.3 * s * (1 - j * 0.07), 0) * ANG(0.5, 0, 0), Enum.Material.Glass, 0.05) end
	end
	local last = rec.parts[#rec.parts]
	H.tri(rig, last, "TailFin", 0.08 * s, 1.3 * s, 1.1 * s, H.lighten(a, 0.2), CF(0, 0, 0.6 * s) * ANG(-PI / 2, 0, 0), Enum.Material.Glass, 0.35)
	for _, side in ipairs({ -1, 1 }) do
		local fin = H.ell(rig, body, "Fin", V3(0.7, 0.08, 0.45) * s, a, CF(side * br.X * 0.9, -0.2 * s, 0.3 * s) * ANG(0, side * 0.4, 0), nil, 0.2, CF(-side * 0.3 * s, 0, 0))
		table.insert(rig.wings, { e = fin, side = side, tier = 1 })
	end
	return body, body, br, br, 0.12 * s, CF(0, 0, br.Z), 0.2 * s
end

-- Nebula Jelly: translucent bell, opaque eye rim, nebula core, tendrils
function Plans.jelly(H, rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local br = V3(1.25, 1.0, 1.25) * s
	local e, body = H.ell(rig, rig.root, "Body", br * 2, p, CF(0, 3.0 * s, 0), Enum.Material.Glass, 0.35)
	rig.bodyEntry = e
	H.band(rig, body, "BellRim", CF(0, -br.Y * 0.45, 0), br.X * 0.9, 0.3 * s, H.darken(p, 0.25), 18, Enum.Material.SmoothPlastic)
	local core = H.ell(rig, body, "Core", V3(1.0, 0.8, 1.0) * s, sc, CF(0, 0.05 * s, 0.1 * s), Enum.Material.Neon, 0.15)
	rig.core = core
	glow(rig, core.part, WHITE)
	for i = 1, 3 do
		local m = H.ell(rig, core.part, "Nebula", V3(0.45, 0.35, 0.45) * s, i == 2 and a or H.lighten(p, 0.3), CF(math.cos(i * 2.1) * 0.35 * s, (i - 2) * 0.15 * s, math.sin(i * 2.1) * 0.35 * s), Enum.Material.Neon, 0.3)
		H.group(rig, "orbit", m)
	end
	rig.legKind = "none"
	for i = 1, 7 do
		local ang = (i - 0.5) / 7 * PI * 2
		local pos = V3(math.cos(ang) * br.X * 0.6, -br.Y * 0.5, math.sin(ang) * br.Z * 0.6)
		local rec = zchain(H, rig, body, "Tendril", CF(pos) * ANG(PI / 2, 0, 0), 5, 0.5 * s, function(t) return (0.12 - t * 0.07) * s end,
			function(t) return t < 0.5 and sc or a end, { kind = "trail", i = i, amp = 0.25, freq = 1.6, lag = 0.8, hang = true },
			function() return Enum.Material.Neon end, function() return 0.2 end)
		H.group(rig, "tendrils", rec)
	end
	return body, body, br, br, -0.1 * s, CF(0, 0, br.Z), 0.3 * s
end

-- Star Whale: broad horizontal whale with flukes and pectoral fins
function Plans.whale(H, rig, def, s, prof)
	local p, sc, a = def._p, def._s, def._a
	local br = V3(1.3, 1.0, 2.3) * s
	local e, body = H.ell(rig, rig.root, "Body", br * 2, p, CF(0, 2.2 * s, 0))
	rig.bodyEntry = e
	H.ell(rig, body, "Forehead", V3(2.2, 1.8, 2.0) * s, p, CF(0, 0.15 * s, -br.Z * 0.6))
	H.ell(rig, body, "Belly", V3(2.2, 1.2, 3.8) * s, sc, CF(0, -br.Y * 0.45, -0.2 * s))
	for i = -2, 2 do -- throat grooves
		H.blk(rig, body, "Groove", V3(0.06, 0.06, 1.6) * s, H.darken(sc, 0.2), CF(i * 0.22 * s, -br.Y * 0.86, -br.Z * 0.45) * ANG(0.05, 0, 0))
	end
	for i = 1, 6 do -- star speckles
		H.ell(rig, body, "Star", V3(0.16, 0.16, 0.16) * s, a, H.surface(br, math.cos(i * 1.7) * br.X * 0.6, br.Y * 0.4 + math.sin(i) * 0.2 * s, -1), Enum.Material.Neon)
	end
	for _, side in ipairs({ -1, 1 }) do
		local fin = H.ell(rig, body, "Pectoral", V3(1.9, 0.14, 0.7) * s, H.darken(p, 0.1), CF(side * br.X * 0.85, -br.Y * 0.4, -br.Z * 0.35) * ANG(0, side * 0.35, side * -0.35), nil, nil, CF(-side * 0.85 * s, 0, 0))
		table.insert(rig.wings, { e = fin, side = side, tier = 1 })
	end
	rig.legKind = "none"
	local rec = zchain(H, rig, body, "Peduncle", CF(0, 0.1 * s, br.Z * 0.85), 3, 0.75 * s, function(t) return (0.7 - t * 0.35) * s end,
		function() return p end, { kind = "fluke", i = 1, amp = 0.22, freq = 1.1, lag = 0.6 })
	local last = rec.parts[#rec.parts]
	for _, side in ipairs({ -1, 1 }) do
		H.ell(rig, last, "Fluke", V3(1.5, 0.14, 0.8) * s, H.darken(p, 0.1), CF(side * 0.65 * s, 0, 0.5 * s) * ANG(0, side * -0.45, 0))
	end
	return body, body, br, br, 0.05 * s, CF(0, 0, br.Z), 0.3 * s
end

---------------------------------------------------------------- FOREST
function A.mossbun(H, rig, vd, s)
	-- Common: plain and clean. Big hind haunches + two small moss plates on the back; nothing ornate.
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		H.ell(rig, rig.body, "Haunch", V3(0.75, 0.95, 1.05) * s, vd._p, CF(side * br.X * 0.75, -br.Y * 0.2, br.Z * 0.45))
	end
	for i, x in ipairs({ -0.35, 0.3 }) do
		H.ell(rig, rig.body, "Moss", V3(0.7 - i * 0.1, 0.16, 0.8) * s, vd._a, CF(x * br.X, br.Y * 0.98, (i - 1.5) * 0.4 * s))
	end
end

function A.acornip(H, rig, vd, s)
	local hr = rig.headRadius
	for _, side in ipairs({ -1, 1 }) do
		H.ell(rig, rig.head, "CheekPouch", V3(0.75, 0.62, 0.62) * s, H.lighten(vd._s, 0.05), CF(side * hr.X * 0.7, -hr.Y * 0.35, -hr.Z * 0.3))
	end
	-- plump segmented tail curling up over the back
	local br = rig.bodyRadius
	local rec = zchain(H, rig, rig.body, "Tail", CF(0, br.Y * 0.4, br.Z * 0.85) * ANG(-1.0, 0, 0), 4, 0.6 * s,
		function(t) return (0.55 + math.sin(t * PI) * 0.2) * s end, function(t, j) return j % 2 == 0 and vd._p or H.lighten(vd._p, 0.12) end,
		{ kind = "plume", i = 1, amp = 0.18, freq = 3, lag = 0.5, curl = 0.45 })
	for j, part in ipairs(rec.parts) do part.Size = part.Size * V3(1, 1, 0.9) end
end

function A.petalfly(H, rig, vd, s)
	for _, w in ipairs(rig.wings) do
		if w.tier == 1 then
			for k = -1, 1, 2 do
				H.diamond(rig, w.e.part, "PetalVein", 1.1 * s, 0.32 * s, 0.05 * s, vd._s, CF(w.side * k * 0.25 * s, 0.05 * s, -0.02) * ANG(0, 0, w.side * (0.8 + k * 0.4)))
			end
		end
	end
	for _, ear in ipairs(rig.ears) do
		if ear.kind == "antenna" then H.ell(rig, ear.e.part, "Curl", V3(0.22, 0.22, 0.22) * s, vd._a, CF(0.12 * s, 0.38 * s, 0)) end
	end
end

function A.thornhog(H, rig, vd, s)
	local br = rig.bodyRadius
	local leafCols = { C("#2F8A3A"), vd._a, C("#7DD86A") }
	for row = 0, 2 do
		for k = 0, 3 do
			local x = (k - 1.5) * br.X * 0.42
			local z = -br.Z * 0.45 + row * br.Z * 0.48
			local y = br.Y * (0.85 - math.abs(k - 1.5) * 0.12) - row * 0.08 * s
			local pv = H.pivot(rig, rig.body, "SpinePivot", CF(x, y, z) * ANG(-0.9 + row * 0.15, 0, -(k - 1.5) * 0.35))
			H.diamond(rig, pv.part, "LeafSpine", 1.15 * s, 0.5 * s, 0.08 * s, leafCols[(row + k) % 3 + 1], CF(0, 0.45 * s, 0) * ANG(PI / 2, 0, 0))
			openable(H, rig, pv, V3(1, 0, 0), 0.35)
			H.group(rig, "spines", pv)
		end
	end
end

function A.elderstag(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 4 do
		local side = i % 2 == 0 and 1 or -1
		H.blk(rig, rig.body, "BarkMark", V3(0.08, 0.5, 0.12) * s, C("#B7A27E"), H.surface(br, side * br.X * 0.9, (i - 2.5) * 0.15 * s, 1) * CF(0, 0, 0.02) * ANG(0, 0, i * 0.4))
	end
	for _, tip in ipairs(rig.groups.tips or {}) do glow(rig, tip.part, WHITE) end
end

function A.oakTitan(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 8 do -- vertical bark ridges
		local ang = i / 8 * PI * 2
		H.blk(rig, rig.body, "Bark", V3(0.22 * s, br.Y * 1.6, 0.18 * s), C("#5A3E25"), CF(math.sin(ang) * br.X * 0.92, 0, math.cos(ang) * br.Z * 0.92) * ANG(0, ang, 0), Enum.Material.Wood)
	end
	for i = 1, 3 do
		H.ell(rig, rig.body, "MossSeam", V3(0.9, 0.25, 0.3) * s, C("#6FAE4A"), H.surface(br, (i - 2) * 0.5 * s, br.Y * 0.5, 1) * CF(0, 0, 0.05), Enum.Material.Grass)
	end
	local heart = H.ell(rig, rig.body, "KnotHeart", V3(0.6, 0.7, 0.2) * s, vd._a, H.surface(br, 0, 0.2 * s) * CF(0, 0, -0.02), Enum.Material.Neon)
	rig.core = heart
	glow(rig, heart.part, WHITE)
	for _, f in ipairs(rig.feet) do -- spreading roots
		for k = 0, 3 do
			local ang = k / 4 * PI * 2 + 0.4
			H.cyl(rig, f.part, "Root", V3(0.9, 0.18, 0.18) * s, C("#5A3E25"), CF(math.cos(ang) * 0.45 * s, -0.42 * s, math.sin(ang) * 0.45 * s) * ANG(0, -ang, -0.35), Enum.Material.Wood)
		end
	end
	for _, arm in ipairs(rig.arms) do -- twig forearms
		for k = 1, 2 do
			H.cyl(rig, arm.e.part, "Twig", V3(0.7, 0.12, 0.12) * s, C("#6B4E30"), CF(arm.side * 0.45 * s, -0.2 * s * k, 0) * ANG(0, 0, arm.side * (0.6 + k * 0.3)), Enum.Material.Wood)
			H.diamond(rig, arm.e.part, "TwigLeaf", 0.45 * s, 0.25 * s, 0.05 * s, C("#9BE07A"), CF(arm.side * 0.8 * s, -0.05 * s - 0.2 * s * k, 0) * ANG(PI / 2, 0, arm.side))
		end
	end
	for _, side in ipairs({ -1, 1 }) do -- leafy canopy clumps on the shoulders
		H.ell(rig, rig.body, "Canopy", V3(1.3, 0.9, 1.1) * s, C("#7CC85A"), CF(side * br.X * 0.75, br.Y * 0.85, 0.1 * s), Enum.Material.Grass)
	end
end

function A.bloomwyrm(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 0, 4 do
		H.diamond(rig, rig.body, "Frill", (0.95 - i * 0.1) * s, 0.5 * s, 0.07 * s, i % 2 == 0 and C("#3FB45A") or C("#7DE08C"),
			CF(0, br.Y * 0.95 - i * 0.05 * s, -br.Z * 0.55 + i * br.Z * 0.32) * ANG(0, PI / 2, 0) * CF(0, 0.3 * s, 0))
	end
	-- cheek flower (opens on reaction)
	for _, side in ipairs({ -1, 1 }) do
		local hr = rig.headRadius
		local center = H.pivot(rig, rig.head, "CheekFlower", CF(side * hr.X * 0.85, -hr.Y * 0.05, -hr.Z * 0.1) * ANG(0, 0, side * -PI / 2))
		for k = 1, 5 do
			local ang = k / 5 * PI * 2
			local pv = H.pivot(rig, center.part, "CheekPetal", ANG(0, ang, 0))
			H.ell(rig, pv.part, "Petal", V3(0.24, 0.06, 0.42) * s, vd._a, CF(0, 0.08 * s, -0.18 * s) * ANG(-0.4, 0, 0))
			openable(H, rig, pv, V3(1, 0, 0), -0.8)
		end
		H.ell(rig, center.part, "FlowerCore", V3(0.2, 0.14, 0.2) * s, C("#FFE45C"), CF(0, 0.05 * s, 0))
	end
	for i = 1, 2 do
		local fp = H.pivot(rig, rig.body, "BackFlower", CF((i - 1.5) * br.X * 0.9, br.Y * 0.7, br.Z * 0.2))
		for k = 1, 5 do
			local ang = k / 5 * PI * 2
			H.ell(rig, fp.part, "Petal", V3(0.4, 0.06, 0.24) * s, vd._s, CF(math.cos(ang) * 0.18 * s, 0.02 * s, math.sin(ang) * 0.18 * s) * ANG(0, -ang, 0.25))
		end
		H.ell(rig, fp.part, "FlowerCore", V3(0.2, 0.14, 0.2) * s, vd._a, CF(0, 0.05 * s, 0))
		H.group(rig, "flowers", fp)
		openable(H, rig, fp, V3(1, 0, 0), 0.25)
	end
end

function A.sylphQueen(H, rig, vd, s)
	local abd = rig.groups.abdomen and rig.groups.abdomen[1]
	if abd then -- layered petal skirt around the hanging abdomen
		for layer = 0, 1 do
			for k = 1, 6 do
				local ang = k / 6 * PI * 2 + layer * 0.5
				local pv = H.pivot(rig, abd.part, "SkirtPivot", CF(0, 0, -0.5 * s + layer * 0.35 * s) * ANG(0, 0, ang))
				H.diamond(rig, pv.part, "SkirtPetal", (1.0 - layer * 0.2) * s, 0.5 * s, 0.06 * s, layer == 0 and vd._p or vd._a, CF(0, 0.45 * s, 0.35 * s) * ANG(0.5, 0, 0))
				openable(H, rig, pv, V3(1, 0, 0), 0.3)
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do -- delicate arms + hands
		local arm = H.ell(rig, rig.body, "Arm", V3(0.22, 0.75, 0.22) * s, H.lighten(vd._p, 0.1), CF(side * 0.55 * s, 0.05 * s, -0.25 * s) * ANG(0, 0, side * 0.5), nil, nil, CF(0, 0.3 * s, 0))
		H.ell(rig, arm.part, "Hand", V3(0.22, 0.22, 0.22) * s, WHITE, CF(0, -0.4 * s, 0))
		table.insert(rig.arms, { e = arm, side = side })
	end
	local orbit = H.pivot(rig, rig.body, "OrnamentOrbit", CF(0, 0.6 * s, 0))
	H.group(rig, "ornamentOrbit", orbit)
	for k = 1, 2 do
		local pv = H.pivot(rig, orbit.part, "Ornament", CF(math.cos(k * PI) * 1.6 * s, 0, math.sin(k * PI) * 1.6 * s))
		for m = 1, 5 do
			local ang = m / 5 * PI * 2
			H.diamond(rig, pv.part, "Petal", 0.3 * s, 0.18 * s, 0.04 * s, vd._a, CF(math.cos(ang) * 0.12 * s, 0, math.sin(ang) * 0.12 * s) * ANG(0, -ang, 0) * ANG(PI / 2, 0, PI / 2))
		end
		H.ell(rig, pv.part, "Core", V3(0.14, 0.14, 0.14) * s, C("#FFE45C"), CF(), Enum.Material.Neon)
		H.group(rig, "ornaments", pv)
	end
end

---------------------------------------------------------------- VOLCANO
function A.emberpup(H, rig, vd, s)
	local hr = rig.headRadius
	H.ell(rig, rig.head, "Blaze", V3(0.35, 0.6, 0.2) * s, vd._s, H.surface(hr, 0, hr.Y * 0.45) * CF(0, 0, 0.02))
	for _, t in ipairs(rig.tail) do glow(rig, t.part, C("#FFF2B0")) end
	if rig.tailFire then rig.tailFire.Size = 1.6 * s end
end

function A.magmite(H, rig, vd, s)
	local br = rig.bodyRadius
	local core = H.ell(rig, rig.body, "InnerCore", br * 1.2, vd._s, CF(0, 0.05 * s, 0.1 * s), Enum.Material.Neon, 0.2)
	rig.core = core
	glow(rig, core.part, WHITE)
	for k = 0, 6 do
		local ang = k / 7 * PI * 2
		local pv = H.pivot(rig, rig.body, "CrustPivot", CF(math.cos(ang) * br.X * 0.55, br.Y * 0.72, math.sin(ang) * br.Z * 0.55 + 0.15 * s) * ANG(0, -ang, 0))
		H.blk(rig, pv.part, "Crust", V3(0.75, 0.22, 0.6) * s, C("#3A1A10"), ANG(0, 0, -0.45) * CF(0.1 * s, 0, 0), Enum.Material.Basalt)
		openable(H, rig, pv, V3(0, 0, 1), -0.45)
		H.group(rig, "plates", pv)
	end
	H.ell(rig, rig.body, "BaseRim", V3(br.X * 2.05, 0.35 * s, br.Z * 2.05), C("#5A2410"), CF(0, -br.Y * 0.72, 0), Enum.Material.Basalt)
end

function A.cinderchick(H, rig, vd, s)
	local br = rig.bodyRadius
	local tuft = H.pivot(rig, rig.body, "FlameTuft", CF(0, br.Y * 0.92, -0.15 * s))
	table.insert(rig.bobbers, tuft)
	for k = -1, 1 do
		H.diamond(rig, tuft.part, "Flame", (0.7 - math.abs(k) * 0.2) * s, 0.3 * s, 0.08 * s, k == 0 and C("#FFE45C") or vd._a,
			CF(k * 0.15 * s, 0.3 * s, 0) * ANG(0, PI / 2, k * -0.35), Enum.Material.Neon)
	end
end

function A.obsidigolem(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		reveal(rig, unitOf(rig, function()
			local pv = H.pivot(rig, rig.body, "Pauldron", CF(side * br.X * 0.95, br.Y * 0.7, 0))
			H.wdg(rig, pv.part, "Plate", V3(1.2, 0.7, 1.3) * s, C("#1C1622"), ANG(0, side * PI / 2, 0), Enum.Material.Slate)
			H.blk(rig, pv.part, "PlateRim", V3(1.25, 0.12, 1.35) * s, C("#FF6A2A"), CF(0, -0.36 * s, 0), Enum.Material.Neon)
			H.crystal(rig, pv.part, "ObsCrystal", 0.9 * s, 0.25 * s, C("#FFB14A"), CF(side * 0.2 * s, 0.2 * s, 0.2 * s) * ANG(0.2, 0, -side * 0.4), Enum.Material.Glass, 0.1)
		end))
	end
	local core = H.ell(rig, rig.body, "Core", V3(0.6, 0.6, 0.2) * s, C("#FFB14A"), H.surface(br, 0, 0.1 * s) * CF(0, 0, -0.01), Enum.Material.Neon)
	rig.core = core
	glow(rig, core.part, WHITE)
	for _, sm in ipairs(rig.groups.seams or {}) do glow(rig, sm.part, C("#FFE0A0")) end
end

function A.phoenixLumen(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1, 2 do
		local rec = zchain(H, rig, rig.body, "Streamer", CF(k * 0.25 * s, -br.Y * 0.3, br.Z * 0.85) * ANG(0.35, k * 0.18, 0), 5, 0.75 * s,
			function(t) return (0.26 - t * 0.12) * s end, function(t) return vd._s:Lerp(vd._a, t) end,
			{ kind = "trail", i = k, amp = 0.2, freq = 2, lag = 0.6 }, function(t) return t > 0.5 and Enum.Material.Neon or nil end)
		local last = rec.parts[#rec.parts]
		H.diamond(rig, last, "StreamerTip", 1.0 * s, 0.45 * s, 0.06 * s, vd._a, CF(0, 0, 0.6 * s) * ANG(PI / 2, 0, 0), Enum.Material.Neon)
	end
	local pe = Instance.new("Fire")
	pe.Size = 2 * s; pe.Heat = 4; pe.Color = vd._p; pe.SecondaryColor = vd._s
	pe.Parent = rig.body
end

function A.kraken(H, rig, vd, s) end -- anatomy lives in Plans.kraken

function A.infernadrake(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = -1, 1 do
		local seam = H.blk(rig, rig.body, "ChestSeam", V3(0.08, 0.7, 0.06) * s, C("#FFB347"), H.surface(br, i * 0.4 * s, -0.1 * s) * CF(0, 0, -0.04) * ANG(0, 0, i * 0.4), Enum.Material.Neon)
		glow(rig, seam.part, C("#FFF2B0"))
	end
	for _, t in ipairs(rig.tail) do glow(rig, t.part, C("#FFF2B0")) end
end

function A.solarSerpent(H, rig, vd, s)
	local br = rig.bodyRadius
	local rec = zchain(H, rig, rig.body, "Serpent", CF(0, 0, br.Z * 0.8), 7, 0.85 * s, function(t) return (0.66 - t * 0.42) * s end,
		function(t, j) return j % 2 == 0 and vd._p or H.lighten(vd._p, 0.15) end, { kind = "spine", i = 1, amp = 0.3, freq = 1.4, lag = 0.7 })
	for j, part in ipairs(rec.parts) do
		H.ell(rig, part, "Belly", V3(0.9, 0.5, 1.1) * s * (1 - j * 0.08), vd._s, CF(0, -0.25 * s * (1 - j * 0.08), 0))
		if j % 2 == 1 then
			local sc = H.ell(rig, part, "SunScale", V3(0.18, 0.18, 0.18) * s, C("#FFFFFF"), CF(0, 0.45 * s * (1 - j * 0.08), 0), Enum.Material.Neon)
			glow(rig, sc.part, C("#FFE45C"))
		end
	end
	local f = Instance.new("Fire"); f.Size = 2 * s; f.Heat = 4; f.Color = vd._s; f.SecondaryColor = C("#FFE45C")
	f.Parent = rec.parts[#rec.parts]
end

---------------------------------------------------------------- FROZEN
function A.frostpaw(H, rig, vd, s)
	local hr = rig.headRadius
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			H.diamond(rig, rig.head, "CheekTuft", 0.45 * s, 0.25 * s, 0.08 * s, WHITE, CF(side * hr.X * (0.95 + k * 0.05), -0.05 * s - k * 0.22 * s, -hr.Z * 0.35) * ANG(0, side * 0.8, side * (1.2 + k * 0.4)))
		end
	end
	for _, e in ipairs(rig.groups.scarfEnds or {}) do H.group(rig, "flutter", e) end
end

function A.snowpuff(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 7 do
		local ang = i * 2.1
		H.ell(rig, rig.body, "Powder", V3(0.9, 0.8, 0.9) * s * (0.7 + (i % 3) * 0.12), i % 2 == 0 and WHITE or vd._s,
			CF(math.cos(ang) * br.X * 0.72, (i % 3 - 1) * br.Y * 0.4, math.sin(ang) * br.Z * 0.72 + 0.15 * s))
	end
end

function A.icicleOwl(H, rig, vd, s)
	for _, w in ipairs(rig.wings) do
		for k = 1, 3 do
			H.diamond(rig, w.e.part, "IceEdge", 0.6 * s, 0.22 * s, 0.05 * s, C("#E6F8FF"), CF(w.side * (0.6 + k * 0.35) * s, -0.9 * s - k * 0.12 * s, 0.04) * ANG(0, 0, w.side * 0.4), Enum.Material.Glass, 0.25)
		end
	end
	local hr = rig.headRadius
	for _, side in ipairs({ -1, 1 }) do
		H.diamond(rig, rig.head, "Brow", 0.5 * s, 0.18 * s, 0.06 * s, vd._a, CF(side * hr.X * 0.35, hr.Y * 0.42, -hr.Z * 0.88) * ANG(0, 0, side * 1.1))
	end
end

function A.glacierYeti(H, rig, vd, s)
	local br, hr = rig.bodyRadius, rig.headRadius
	H.ell(rig, rig.head, "Face", V3(1.15, 0.95, 0.3) * s, C("#9AD9FF"), H.surface(hr, 0, -0.05 * s) * CF(0, 0, 0.1))
	for _, side in ipairs({ -1, 1 }) do
		H.blk(rig, rig.head, "Brow", V3(0.45, 0.13, 0.15) * s, vd._a, H.surface(hr, side * hr.X * 0.34, hr.Y * 0.38) * CF(0, 0, -0.04) * ANG(0, 0, side * 0.2))
		for k = 0, 2 do
			H.ell(rig, rig.body, "Fur", V3(0.8, 0.6, 0.8) * s, WHITE, CF(side * br.X * (0.6 + k * 0.12), br.Y * (0.75 - k * 0.3), (k - 1) * 0.3 * s))
		end
	end
	for _, arm in ipairs(rig.arms) do
		for k = 1, 2 do H.ell(rig, arm.e.part, "ArmFur", V3(1.05, 0.5, 1.05) * s, WHITE, CF(0, 0.6 * s - k * 0.55 * s, 0)) end
	end
end

function A.auroraFox(H, rig, vd, s)
	local hr = rig.headRadius
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 1 do
			H.diamond(rig, rig.head, "CheekFur", 0.55 * s, 0.28 * s, 0.08 * s, WHITE, CF(side * hr.X * 0.85, -hr.Y * (0.2 + k * 0.25), hr.Z * 0.05) * ANG(0, side * 0.6, side * (1.4 + k * 0.3)))
		end
	end
	for i, t in ipairs(rig.tail) do
		if i > 1 then
			local r = H.blk(rig, t.part, "Ribbon", V3(0.08, t.part.Size.Y * 1.05, t.part.Size.Z * 0.9), aurora(i / #rig.tail), CF(0, 0, 0), Enum.Material.Neon, 0.25)
			glow(rig, r.part, WHITE)
		end
	end
end

function A.blizzardBear(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Hump", V3(1.9, 1.2, 1.4) * s, vd._p, CF(0, br.Y * 0.55, -br.Z * 0.35))
	for i = 1, 5 do
		H.ell(rig, rig.body, "Fur", V3(0.6, 0.45, 0.6) * s, vd._s, H.surface(br, math.cos(i) * br.X * 0.6, (i % 3 - 1) * 0.35 * s, (i % 2 == 0) and 1 or -1) * CF(0, 0, 0.05))
	end
	H.ell(rig, rig.head, "Snow", V3(rig.headRadius.X * 1.1, rig.headRadius.Y * 0.35, rig.headRadius.Z * 0.9), WHITE, CF(0, rig.headRadius.Y * 0.7, 0.15 * s))
end

function A.crystalwing(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 0, 3 do
		H.crystal(rig, rig.body, "Ridge", (0.85 - i * 0.12) * s, 0.22 * s, C("#E6F8FF"), CF(0, br.Y * 0.85, -br.Z * 0.45 + i * br.Z * 0.35) * ANG(0.4, 0, 0), Enum.Material.Glass, 0.1)
	end
end

function A.frostEmpress(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1 do
		local rec = zchain(H, rig, rig.body, "Streamer", CF(k * 0.3 * s, -br.Y * 0.2, br.Z * 0.85) * ANG(0.25, k * 0.25, 0), 6, 0.8 * s,
			function(t) return (0.2 - t * 0.1) * s end, function(t) return aurora(t) end,
			{ kind = "trail", i = k + 2, amp = 0.2, freq = 1.4, lag = 0.6 }, function() return Enum.Material.Neon end, function() return 0.2 end)
		H.group(rig, "streamers", rec)
	end
	for _, cp in ipairs(rig.groups.crown or {}) do
		for k = -1, 1 do
			local cr = H.blk(rig, cp.part, "CrownCrystal", V3(0.14, 0.7 - math.abs(k) * 0.2, 0.14) * s, C("#BFF6FF"), CF(k * 0.22 * s, 0.6 * s, 0) * ANG(0, PI / 4, k * -0.25), Enum.Material.Glass, 0.05)
			glow(rig, cr.part, WHITE)
		end
	end
end

---------------------------------------------------------------- CRYSTAL
function A.gemmy(H, rig, vd, s)
	local gem = H.pivot(rig, rig.body, "Gem", CF(0, 0, 0.15 * s))
	H.diamond(rig, gem.part, "InnerGem", 0.9 * s, 0.6 * s, 0.4 * s, vd._a, CF(), Enum.Material.Neon)
	H.diamond(rig, gem.part, "InnerGem", 0.9 * s, 0.6 * s, 0.4 * s, H.lighten(vd._a, 0.3), ANG(0, PI / 2, 0), Enum.Material.Neon)
	H.group(rig, "lag", gem)
	rig.core = gem
end

function A.quartzBeetle(H, rig, vd, s)
	local abd = rig.groups.abdomen and rig.groups.abdomen[1]
	if not abd then return end
	for _, side in ipairs({ -1, 1 }) do
		local pv = H.pivot(rig, abd.part, "ShellHalf", CF(side * 0.05 * s, 0.55 * s, -0.4 * s))
		H.blk(rig, pv.part, "Quartz", V3(0.85, 0.35, 1.9) * s, C("#E2E8F0"), CF(side * 0.42 * s, 0, 0.45 * s) * ANG(0, 0, side * -0.35), Enum.Material.Glass, 0.1)
		H.wdg(rig, pv.part, "QuartzFacet", V3(0.85, 0.3, 0.6) * s, C("#9FE7FF"), CF(side * 0.42 * s, 0.28 * s, 0.75 * s) * ANG(0, PI, side * -0.35), Enum.Material.Glass, 0.1)
		openable(H, rig, pv, V3(0, 0, 1), side * -0.55)
		H.group(rig, "shell", pv)
	end
end

function A.glimmerBat(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Ruff", V3(1.6, 0.6, 1.2) * s, H.lighten(vd._p, 0.15), CF(0, -br.Y * 0.5, -br.Z * 0.35))
	H.ell(rig, rig.body, "Snout", V3(0.5, 0.35, 0.3) * s, vd._s, H.surface(br, 0, rig.faceY - br.Y * 0.3) * CF(0, 0, 0.05))
end

function A.eel(H, rig, vd, s) end -- anatomy lives in Plans.eel

function A.prismLion(H, rig, vd, s)
	local hr = rig.headRadius
	local cols = { C("#FFFFFF"), vd._a, C("#9FE7FF"), C("#E9D2FF") }
	for layer = 0, 1 do
		local n = layer == 0 and 12 or 9
		for k = 1, n do
			local ang = k / n * PI * 2
			local pv = H.pivot(rig, rig.head, "ManeShard", CF(math.cos(ang) * hr.X * (0.85 + layer * 0.15), math.sin(ang) * hr.Y * (0.85 + layer * 0.15), hr.Z * (0.25 + layer * 0.2)) * ANG(0, 0, ang - PI / 2))
			H.diamond(rig, pv.part, "Mane", (0.85 - layer * 0.15) * s, 0.4 * s, 0.1 * s, cols[(k + layer) % 4 + 1], CF(0, 0.3 * s, 0), layer == 1 and Enum.Material.Glass or nil, layer == 1 and 0.15 or 0)
			H.group(rig, "mane", pv)
			openable(H, rig, pv, V3(1, 0, 0), 0.25)
		end
	end
end

function A.diamondDrake(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 0, 3 do
		H.tri(rig, rig.body, "DorsalPlate", 0.1 * s, (0.8 - i * 0.1) * s, 0.7 * s, C("#BFF6FF"), CF(0, br.Y * 0.95 + 0.3 * s, -br.Z * 0.45 + i * br.Z * 0.35), Enum.Material.Glass, 0.15)
	end
	for _, w in ipairs(rig.wings) do
		for k = 1, 2 do
			H.diamond(rig, w.e.part, "WingPanel", 0.9 * s, 0.45 * s, 0.05 * s, C("#E8F4FF"), CF(w.side * (0.4 + k * 0.45) * s, -0.15 * s, -0.02) * ANG(0, 0, w.side * 0.9), Enum.Material.Glass, 0.2)
		end
		local edge = H.blk(rig, w.e.part, "WingEdge", V3(2.0, 0.06, 0.06) * s, vd._a, CF(w.side * 0.1 * s, 0.55 * s, 0) * ANG(0, 0, w.side * 0.25), Enum.Material.Neon)
		glow(rig, edge.part, WHITE)
	end
end

function A.geodeLeviathan(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "GeodeGlow", V3(br.X * 1.7, 0.4 * s, br.Z * 1.7), vd._s, CF(0, br.Y * 0.78, 0), Enum.Material.Neon)
	for i = 0, 5 do
		local side = i % 2 == 0 and -1 or 1
		local row = math.floor(i / 2)
		local pv = H.pivot(rig, rig.body, "ArmorPivot", CF(side * br.X * 0.15, br.Y * 0.85, -br.Z * 0.5 + row * br.Z * 0.5))
		H.blk(rig, pv.part, "RockPlate", V3(1.1, 0.35, 0.95) * s, C("#2A1A44"), CF(side * 0.5 * s, 0, 0) * ANG(0, 0, side * -0.25), Enum.Material.Slate)
		openable(H, rig, pv, V3(0, 0, 1), side * -0.6)
	end
	for i = 0, 4 do
		H.spike(rig, rig.body, "CyanSpine", (0.6 - i * 0.06) * s, 0.3 * s, vd._a, CF(0, br.Y * 0.92, -br.Z * 0.75 + i * br.Z * 0.38) * ANG(0.4, 0, 0), Enum.Material.Neon)
	end
	local gem = H.crystal(rig, rig.head, "BrowGem", 0.6 * s, 0.22 * s, vd._s, CF(0, rig.headRadius.Y * 0.8, 0) * ANG(-0.3, 0, 0), Enum.Material.Neon)
end

function A.hydra(H, rig, vd, s)
	for i, he in ipairs(rig.groups.heads or {}) do
		if i ~= 2 then
			H.crystal(rig, he.part, "HeadCrystal", 0.6 * s, 0.18 * s, vd._a, CF(0, rig.headRadius.Y * 0.85, 0.1 * s), Enum.Material.Glass, 0.1)
		end
	end
	for _, rec in ipairs(rig.groups.neckChains or {}) do reveal(rig, subtree(rig, { rec.parts[1] })) end
end

---------------------------------------------------------------- CANDY
function A.gumdrop(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Base", V3(br.X * 2.05, 0.5 * s, br.Z * 2.05), H.darken(vd._p, 0.1), CF(0, -br.Y * 0.62, 0), Enum.Material.Glass, 0.2)
	H.diamond(rig, rig.body, "Topping", 0.5 * s, 0.4 * s, 0.25 * s, C("#FF2E6E"), CF(0, br.Y * 0.98, 0.1 * s) * ANG(0, 0.5, 0))
	for i = 1, 7 do
		local ang = i * 2.39
		H.blk(rig, rig.body, "Sugar", V3(0.12, 0.12, 0.12) * s, WHITE, CF(math.cos(ang) * br.X * 0.75, br.Y * (0.1 + (i % 3) * 0.22), math.sin(ang) * br.Z * 0.75 + 0.1 * s) * ANG(ang, ang, 0), Enum.Material.Glass, 0.1)
	end
end

function A.cocoaCub(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1, 2 do -- molded chocolate seams on the back
		H.blk(rig, rig.body, "Seam", V3(0.06, 0.06, 1.2) * s, H.darken(vd._p, 0.3), CF(k * 0.35 * s, br.Y * 1.0, 0))
	end
	H.blk(rig, rig.body, "Seam", V3(1.0, 0.06, 0.06) * s, H.darken(vd._p, 0.3), CF(0, br.Y * 1.0, 0.1 * s))
end

function A.lollipup(H, rig, vd, s)
	local hr = rig.headRadius
	H.ell(rig, rig.head, "Tongue", V3(0.22, 0.12, 0.25) * s, vd._s, CF(0, -0.55 * s, -hr.Z * 0.95))
	for _, side in ipairs({ -1, 1 }) do
		H.ell(rig, rig.head, "MuzzleSpot", V3(0.25, 0.2, 0.1) * s, H.lighten(vd._s, 0.4), CF(side * 0.22 * s, -0.3 * s, -hr.Z * 1.0))
	end
end

function A.marshghost(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1 do
		H.ell(rig, rig.body, "Pillow", V3(1.0, 0.7, 1.0) * s, WHITE, CF(k * 0.55 * s, br.Y * 0.75, 0.05 * s))
		H.ell(rig, rig.body, "Toast", V3(0.8, 0.3, 0.8) * s, C("#F6C8A8"), CF(k * 0.55 * s, br.Y * 0.95, 0.15 * s))
	end
	for _, arm in ipairs(rig.arms) do H.ell(rig, arm.e.part, "Mitten", V3(0.45, 0.4, 0.45) * s, vd._s, CF(0, -0.3 * s, 0)) end
	for _, ch in ipairs(rig.groups.cheeks or {}) do glow(rig, ch.part, C("#FF6FA8")) end
end

local function horseMane(H, rig, vd, s, cols)
	local neck = rig.neckEntry
	if not neck then return end
	for k = 0, 5 do
		local pv = H.pivot(rig, neck.part, "ManeLock", CF(0, -0.35 * s + k * 0.3 * s, 0.38 * s) * ANG(0.3, 0, 0))
		H.diamond(rig, pv.part, "Mane", 0.75 * s, 0.4 * s, 0.1 * s, cols[k % #cols + 1], CF(0, 0, 0.25 * s) * ANG(PI / 2, 0, 0) * ANG(0, 0, 0.3))
		H.group(rig, "flutter", pv)
	end
	local hr = rig.headRadius
	H.diamond(rig, rig.head, "Forelock", 0.6 * s, 0.35 * s, 0.08 * s, cols[1], CF(0, hr.Y * 0.75, -hr.Z * 0.35) * ANG(0.6, 0, 0))
end

function A.sugarcorn(H, rig, vd, s)
	horseMane(H, rig, vd, s, { vd._a, WHITE, C("#FFB3E6"), C("#B3E6FF") })
end

function A.kirin(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 8 do
		local ang = i * 2.3
		local cl = H.ell(rig, rig.body, "CloudFur", V3(1.0, 0.8, 1.0) * s * (0.8 + (i % 3) * 0.12), i % 2 == 0 and vd._p or vd._s,
			CF(math.cos(ang) * br.X * 0.7, br.Y * (0.2 + (i % 3) * 0.25), math.sin(ang) * br.Z * 0.75))
		openable(H, rig, cl, V3(1, 0, 0), 0.15)
	end
	for _, f in ipairs(rig.feet) do H.ell(rig, f.part, "LegCloud", V3(0.9, 0.55, 0.9) * s, vd._s, CF(0, -0.15 * s, 0)) end
	horseMane(H, rig, vd, s, { vd._p, vd._s, WHITE })
end

function A.queenBee(H, rig, vd, s)
	local abd = rig.groups.abdomen and rig.groups.abdomen[1]
	if abd then
		H.ell(rig, abd.part, "HoneyTrim", V3(1.35, 1.3, 0.25) * s, C("#FFB020"), CF(0, 0, -0.75 * s), Enum.Material.Glass, 0.3)
		local st = H.pivot(rig, abd.part, "Stinger", CF(0, -0.1 * s, 0.95 * s))
		for k = 0, 2 do
			H.ell(rig, st.part, "CandyStinger", V3(0.4, 0.4, 0.4) * s * (1 - k * 0.25), k % 2 == 0 and vd._a or WHITE, CF(0, 0, k * 0.22 * s))
		end
	end
end

function A.chocoTitan(H, rig, vd, s)
	local br = rig.bodyRadius
	local cols = { C("#FF5FA2"), C("#5FD3FF"), C("#FFE45C"), C("#7CFF8A") }
	for r = 0, 2 do
		for c = 0, 1 do
			local cf = H.surface(br, (c - 0.5) * 0.7 * s, (1 - r) * 0.55 * s) * CF(0, 0, -0.05)
			reveal(rig, unitOf(rig, function()
				H.blk(rig, rig.body, "ChocoBar", V3(0.62, 0.48, 0.2) * s, C("#7A4426"), cf)
				local inlay = H.ell(rig, rig.body, "Inlay", V3(0.2, 0.2, 0.08) * s, cols[(r * 2 + c) % 4 + 1], cf * CF(0, 0, -0.1 * s), Enum.Material.Neon)
				glow(rig, inlay.part, WHITE)
			end))
		end
	end
	for _, arm in ipairs(rig.arms) do
		H.ell(rig, rig.body, "Icing", V3(0.95, 0.6, 0.95) * s, vd._s, CF(arm.side * br.X * 1.0, 0.85 * s, 0))
		H.ell(rig, arm.e.part, "IcingCuff", V3(1.1, 0.3, 1.1) * s, WHITE, CF(0, -0.55 * s, 0))
	end
end

---------------------------------------------------------------- SPACE
function A.astroBlob(H, rig, vd, s)
	local core = H.ell(rig, rig.body, "Core", V3(0.6, 0.6, 0.6) * s, C("#E6FFF6"), CF(0, -0.1 * s, 0.35 * s), Enum.Material.Neon, 0.3)
	rig.core = core
	glow(rig, core.part, WHITE)
end

function A.moonMouse(H, rig, vd, s)
	local hr = rig.headRadius
	for _, side in ipairs({ -1, 1 }) do
		for k = -1, 1, 2 do
			H.cyl(rig, rig.head, "Whisker", V3(0.8, 0.03, 0.03) * s, H.darken(vd._p, 0.4), CF(side * 0.55 * s, -0.35 * s + k * 0.06 * s, -hr.Z * 1.05) * ANG(0, 0, k * 0.15))
		end
	end
end

function A.cometFish(H, rig, vd, s)
	local br = rig.bodyRadius
	local rec = zchain(H, rig, rig.body, "CometTail", CF(0, 0, br.Z * 0.85), 5, 0.6 * s, function(t) return (0.45 - t * 0.33) * s end,
		function(t) return vd._a:Lerp(WHITE, t) end, { kind = "trail", i = 1, amp = 0.25, freq = 4, lag = 0.5 },
		function() return Enum.Material.Neon end, function(t) return t * 0.4 end)
	H.diamond(rig, rec.parts[#rec.parts], "TailStar", 0.6 * s, 0.25 * s, 0.05 * s, WHITE, CF(0, 0, 0.4 * s), Enum.Material.Neon)
	H.diamond(rig, rec.parts[#rec.parts], "TailStar", 0.6 * s, 0.25 * s, 0.05 * s, WHITE, CF(0, 0, 0.4 * s) * ANG(0, 0, PI / 2), Enum.Material.Neon)
	for _, p in ipairs(rec.parts) do glow(rig, p, WHITE) end
end

function A.jelly(H, rig, vd, s) end -- anatomy lives in Plans.jelly
function A.whale(H, rig, vd, s) end -- anatomy lives in Plans.whale

function A.novaPhoenix(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1 do
		local rec = zchain(H, rig, rig.body, "Streamer", CF(k * 0.3 * s, -br.Y * 0.2, br.Z * 0.85) * ANG(0.3, k * 0.3, 0), 6, 0.8 * s,
			function(t) return (0.22 - t * 0.1) * s end, function(t) return vd._s:Lerp(vd._a, t) end,
			{ kind = "trail", i = k + 2, amp = 0.2, freq = 1.4, lag = 0.6, fan = true }, function() return Enum.Material.Neon end, function() return 0.15 end)
		H.group(rig, "streamers", rec)
		openable(H, rig, rec.entries[1], V3(0, 1, 0), k * 0.45)
	end
	local core = H.ell(rig, rig.body, "BreastCore", V3(0.5, 0.5, 0.2) * s, vd._a, H.surface(br, 0, 0) * CF(0, 0, -0.02), Enum.Material.Neon)
	glow(rig, core.part, WHITE)
end

function A.cosmicDragon(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 9 do
		local st = H.ell(rig, rig.body, "Star", V3(0.12, 0.12, 0.12) * s, i % 3 == 0 and vd._a or WHITE, H.surface(br, math.cos(i * 1.3) * br.X * 0.7, math.sin(i * 2.1) * br.Y * 0.6, i % 2 == 0 and 1 or -1), Enum.Material.Neon)
		glow(rig, st.part, WHITE)
	end
	local mote = H.pivot(rig, rig.body, "MoteOrbit", CF(0, 1.2 * s, 0))
	H.ell(rig, mote.part, "Mote", V3(0.3, 0.3, 0.3) * s, vd._a, CF(2.2 * s, 0, 0), Enum.Material.Neon)
	H.group(rig, "ornamentOrbit", mote)
end

function A.singularity(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Rim", br * 2.08, vd._s, CF(0, 0, 0.03 * s), Enum.Material.SmoothPlastic, 0.55)
	H.ell(rig, rig.head, "HeadRim", rig.headRadius * 2.08, vd._s, CF(0, 0, 0.03 * s), Enum.Material.SmoothPlastic, 0.55)
	local disk = H.cyl(rig, rig.body, "Accretion", V3(0.05, 3.6, 3.6) * s, H.lighten(vd._s, 0.2), CF(0.3 * s, 0, 0) * ANG(0.6, 0, PI / 2), Enum.Material.Neon, 0.75)
	H.group(rig, "rings", disk)
end

---------------------------------------------------------------- SHADOW
function A.gloomling(H, rig, vd, s)
	local br = rig.bodyRadius
	H.spike(rig, rig.body, "HoodPeak", 0.9 * s, 0.9 * s, vd._p, CF(0, br.Y * 0.8, 0.2 * s) * ANG(0.5, 0, 0))
end

function A.shadeCat(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		H.blk(rig, rig.body, "EdgeStripe", V3(0.05, 0.08, br.Z * 1.6), vd._s, CF(side * br.X * 0.92, 0.1 * s, 0), Enum.Material.Neon, 0.3)
	end
	for _, e in ipairs(rig.eyes) do glow(rig, e.part, WHITE) end
end

function A.nightMoth(H, rig, vd, s)
	for k = 0, 7 do
		local ang = k / 8 * PI * 2
		H.ell(rig, rig.body, "Collar", V3(0.5, 0.45, 0.5) * s, H.lighten(vd._s, 0.2), CF(math.cos(ang) * 0.55 * s, 0.35 * s, math.sin(ang) * 0.55 * s - 0.4 * s))
	end
	for _, w in ipairs(rig.wings) do
		local spot = H.ell(rig, w.e.part, "EyeSpot", V3(0.55, 0.55, 0.08) * s, vd._a, CF(w.side * 0.35 * s, (w.tier == 1 and 0.1 or -0.1) * s, -0.04), Enum.Material.Neon)
		H.ell(rig, spot.part, "EyeSpotCore", V3(0.28, 0.28, 0.06) * s, C("#2A1A44"), CF(0, 0, -0.03))
		glow(rig, spot.part, WHITE)
	end
	for _, ear in ipairs(rig.ears) do
		if ear.kind == "antenna" then
			for k = 1, 3 do
				H.diamond(rig, ear.e.part, "Feather", 0.3 * s, 0.12 * s, 0.03 * s, vd._s, CF(0, (k - 2) * 0.2 * s, 0) * ANG(0, 0, PI / 2))
			end
		end
	end
end

function A.voidWisp(H, rig, vd, s)
	local br = rig.bodyRadius
	H.spike(rig, rig.body, "Tip", 1.4 * s, 0.9 * s, vd._p, CF(0, -br.Y * 0.8, 0.1 * s) * ANG(PI, 0, 0))
	local core = H.ell(rig, rig.body, "Core", V3(0.9, 0.9, 0.9) * s, vd._s, CF(0, -0.15 * s, 0.25 * s), Enum.Material.Neon, 0.25)
	rig.core = core
	glow(rig, core.part, vd._a)
	for k = 1, 3 do
		local ang = k / 3 * PI * 2
		local rec = zchain(H, rig, rig.body, "SmokeRibbon", CF(math.cos(ang) * br.X * 0.7, -br.Y * 0.2, math.sin(ang) * br.Z * 0.7) * ANG(0.6, ang, 0), 4, 0.6 * s,
			function(t) return (0.2 - t * 0.1) * s end, function() return H.lighten(vd._s, 0.2) end,
			{ kind = "trail", i = k, amp = 0.35, freq = 1.5, lag = 0.8 }, nil, function(t) return 0.35 + t * 0.3 end)
		H.group(rig, "ribbons", rec)
	end
end

function A.umbraWolf(H, rig, vd, s)
	local hr = rig.headRadius
	for k = 0, 6 do
		local ang = k / 7 * PI * 2
		H.diamond(rig, rig.head, "Ruff", 0.7 * s, 0.35 * s, 0.1 * s, k % 2 == 0 and vd._s or vd._p, CF(math.cos(ang) * hr.X * 0.9, math.sin(ang) * hr.Y * 0.8 - 0.25 * s, hr.Z * 0.55) * ANG(0, 0, ang - PI / 2) * CF(0, 0.2 * s, 0))
	end
	for _, f in ipairs(rig.feet) do H.blk(rig, f.part, "Seam", V3(0.05, f.part.Size.Y * 0.7, 0.05), vd._a, CF(0, 0, -f.part.Size.Z * 0.48), Enum.Material.Neon, 0.2) end
end

function A.wraithlord(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = 1, 6 do
		local ang = k / 6 * PI * 2
		local pv = H.pivot(rig, rig.body, "RobePanel", CF(math.cos(ang) * br.X * 0.75, -br.Y * 0.55, math.sin(ang) * br.Z * 0.75) * ANG(0, -ang + PI / 2, 0))
		H.tri(rig, pv.part, "Robe", 0.08 * s, 1.5 * s, 0.9 * s, k % 2 == 0 and vd._s or H.darken(vd._s, 0.3), CF(0, -0.7 * s, 0) * ANG(PI, 0, 0))
		H.group(rig, "flutter", pv)
		openable(H, rig, pv, V3(0, 0, 1), 0.25)
	end
	for _, side in ipairs({ -1, 1 }) do
		H.ell(rig, rig.body, "Pauldron", V3(1.0, 0.6, 1.0) * s, H.darken(vd._s, 0.3), CF(side * br.X * 0.85, br.Y * 0.45, 0))
		H.spike(rig, rig.body, "ShoulderSpike", 0.5 * s, 0.25 * s, vd._a, CF(side * br.X * 0.95, br.Y * 0.65, 0) * ANG(0, 0, -side * 0.5))
	end
end

function A.wyvern(H, rig, vd, s)
	for _, w in ipairs(rig.wings) do
		H.spike(rig, w.e.part, "WingKnuckle", 0.45 * s, 0.2 * s, C("#5A1A8C"), CF(w.side * 0.2 * s, 0.6 * s, 0) * ANG(0, 0, -w.side * 0.5))
	end
end

function A.eclipseDragon(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		local rim = H.blk(rig, rig.body, "EclipseEdge", V3(0.05, 0.08, br.Z * 1.8), vd._s, CF(side * br.X * 0.96, 0.2 * s, 0), Enum.Material.Neon)
		glow(rig, rim.part, WHITE)
	end
	for _, w in ipairs(rig.wings) do
		H.blk(rig, w.e.part, "WingEdge", V3(2.0, 0.05, 0.05) * s, vd._s, CF(0, 0.6 * s, 0) * ANG(0, 0, w.side * 0.3), Enum.Material.Neon)
	end
end

---------------------------------------------------------------- HEAVEN
function A.cloudLamb(H, rig, vd, s)
	local br = rig.bodyRadius
	for i = 1, 11 do
		local ang = i * 2.4
		local y = (i % 4) / 3 - 0.4
		local wl = H.ell(rig, rig.body, "Wool", V3(0.95, 0.85, 0.95) * s * (0.8 + (i % 3) * 0.1), i % 3 == 0 and vd._s or WHITE,
			CF(math.cos(ang) * br.X * 0.75 * math.sqrt(1 - y * y * 0.5), y * br.Y * 0.9, math.sin(ang) * br.Z * 0.75 + 0.15 * s))
		openable(H, rig, wl, V3(1, 0, 0), 0.1)
	end
end

function A.haloChick(H, rig, vd, s) end -- built from bird plan + angel wings + halo

function A.seraphling(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Face", V3(1.3, 1.1, 0.3) * s, C("#FFE7CF"), H.surface(br, 0, rig.faceY) * CF(0, 0, 0.09))
	local curl = H.pivot(rig, rig.body, "Curl", CF(0, br.Y * 0.95, -0.2 * s))
	H.ell(rig, curl.part, "HairCurl", V3(0.45, 0.45, 0.25) * s, C("#FFD86B"), CF(0, 0.15 * s, 0))
	table.insert(rig.bobbers, curl)
end

function A.griffin(H, rig, vd, s)
	local br, hr = rig.bodyRadius, rig.headRadius
	for k = 0, 4 do
		H.diamond(rig, rig.body, "ChestFeather", 0.7 * s, 0.4 * s, 0.08 * s, k % 2 == 0 and vd._s or WHITE, CF((k - 2) * 0.28 * s, 0.1 * s - math.abs(k - 2) * 0.1 * s, -br.Z * 0.95) * ANG(0.3, 0, 0))
	end
	for k = 0, 2 do
		H.diamond(rig, rig.head, "Crest", (0.75 - k * 0.12) * s, 0.25 * s, 0.06 * s, vd._p, CF(0, hr.Y * 0.8, hr.Z * (0.1 + k * 0.3)) * ANG(-0.6 - k * 0.3, 0, 0) * CF(0, 0.3 * s, 0))
	end
	H.ell(rig, rig.body, "LionHaunch", V3(1.9, 1.5, 1.4) * s, vd._p, CF(0, 0, br.Z * 0.5))
end

function A.pegasus(H, rig, vd, s)
	horseMane(H, rig, vd, s, { WHITE, C("#FFE9A6"), C("#E8F4FF") })
end

function A.seraphLion(H, rig, vd, s)
	local hr = rig.headRadius
	for layer = 0, 1 do
		local n = 11
		for k = 1, n do
			local ang = k / n * PI * 2
			local pv = H.pivot(rig, rig.head, "ManeFeather", CF(math.cos(ang) * hr.X * (0.85 + layer * 0.2), math.sin(ang) * hr.Y * (0.85 + layer * 0.2), hr.Z * (0.2 + layer * 0.25)) * ANG(0, 0, ang - PI / 2))
			H.diamond(rig, pv.part, "Mane", (0.95 - layer * 0.1) * s, 0.45 * s, 0.1 * s, layer == 0 and C("#FFE08A") or WHITE, CF(0, 0.32 * s, 0))
			H.group(rig, "mane", pv)
			openable(H, rig, pv, V3(1, 0, 0), 0.2)
		end
	end
end

function A.archDrake(H, rig, vd, s) end -- angel wings with gold tips + chest plates + crown/halo from shared pieces

function A.throneAngel(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = -1, 1 do
		H.blk(rig, rig.body, "ArmorPanel", V3(0.6, 1.3 - math.abs(k) * 0.3, 0.18) * s, C("#F4F1EA"), H.surface(br, k * 0.6 * s, 0.1 * s) * CF(0, 0, -0.06) * ANG(0, k * 0.2, 0), Enum.Material.Marble)
	end
	local core = H.ell(rig, rig.body, "Core", V3(0.45, 0.45, 0.2) * s, vd._a, H.surface(br, 0, 0.55 * s) * CF(0, 0, -0.12), Enum.Material.Neon)
	rig.core = core
	glow(rig, core.part, WHITE)
	reveal(rig, unitOf(rig, function()
		for _, side in ipairs({ -1, 1 }) do
			H.blk(rig, rig.body, "ShoulderGuard", V3(0.9, 0.35, 1.0) * s, C("#FFF8EA"), CF(side * br.X * 0.95, br.Y * 0.75, 0) * ANG(0, 0, side * -0.3), Enum.Material.Marble)
		end
	end))
end

---------------------------------------------------------------- SECRET
function A.glitchling(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = 0, 11 do
		local ang = k / 12 * PI * 2
		H.blk(rig, rig.body, "Pixel", V3(0.24, 0.24, 0.24) * s, k % 2 == 0 and vd._p or vd._s, CF(math.cos(ang) * br.X * 0.98, -br.Y * 0.35, math.sin(ang) * br.Z * 0.98) * ANG(0, -ang, 0), Enum.Material.Neon)
	end
	H.ell(rig, rig.body, "DarkBand", V3(br.X * 2.02, br.Y * 0.5, br.Z * 2.02), C("#101018"), CF(0, -br.Y * 0.55, 0))
	for k = 1, 3 do
		local pv = H.pivot(rig, rig.body, "Fragment", CF((k - 2) * 0.9 * s, br.Y * 1.25, 0.2 * s))
		H.blk(rig, pv.part, "FragmentCube", V3(0.3, 0.3, 0.3) * s, k % 2 == 0 and vd._s or vd._p, CF(), Enum.Material.Neon)
		pv.fragIndex = k
		H.group(rig, "fragments", pv)
	end
end

function A.voidEmperor(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		reveal(rig, unitOf(rig, function()
			H.wdg(rig, rig.body, "ArmorPlate", V3(1.3, 0.8, 1.2) * s, C("#14101C"), CF(side * br.X * 0.95, br.Y * 0.75, 0) * ANG(0, side * PI / 2, 0))
			H.blk(rig, rig.body, "PlateEdge", V3(1.3, 0.08, 1.25) * s, vd._a, CF(side * br.X * 0.95, br.Y * 0.38, 0), Enum.Material.Neon)
			H.crystal(rig, rig.body, "PurpleCrystal", 0.9 * s, 0.25 * s, C("#7A2BCC"), CF(side * br.X * 1.0, br.Y * 0.9, 0.3 * s) * ANG(0.2, 0, -side * 0.4), Enum.Material.Glass, 0.1)
		end))
	end
	local core = H.ell(rig, rig.body, "Core", V3(0.6, 0.6, 0.2) * s, vd._a, H.surface(br, 0, 0.2 * s) * CF(0, 0, -0.02), Enum.Material.Neon)
	rig.core = core
	glow(rig, core.part, WHITE)
	local orb = H.pivot(rig, rig.arms[2] and rig.arms[2].e.part or rig.body, "PalmCrystal", CF(0, -1.7 * s, -0.6 * s))
	H.crystal(rig, orb.part, "Gem", 0.5 * s, 0.2 * s, vd._a, CF(0, -0.25 * s, 0), Enum.Material.Neon)
	H.group(rig, "palmCrystal", orb)
end

function A.errorcat(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		H.blk(rig, rig.body, "Seam", V3(0.05, 0.06, br.Z * 1.5), vd._a, CF(side * br.X * 0.93, 0.15 * s, 0), Enum.Material.Neon)
	end
	-- tail echo: a translucent copy that lags and rejoins
	local first = rig.tail[1]
	if first then
		local rec = zchain(H, rig, rig.body, "TailEcho", CF(0, 0.3 * s, br.Z * 0.95) * ANG(-0.5, 0, 0), 5, 0.5 * s, function(t) return (0.42 - t * 0.2) * s end,
			function(t) return t > 0.5 and vd._a or vd._p end, { kind = "echo", i = 1, amp = 0.35, freq = 3.5, lag = 0.5 }, function() return Enum.Material.Neon end, function() return 0.65 end)
		H.group(rig, "echo", rec)
	end
end

function A.nullBunny(H, rig, vd, s)
	local br = rig.bodyRadius
	H.ell(rig, rig.body, "Rim", br * 2.06, WHITE, CF(0, 0, 0.04 * s), Enum.Material.SmoothPlastic, 0.7)
end

function A.watcher(H, rig, vd, s)
	local br = rig.bodyRadius
	H.spike(rig, rig.body, "Hood", 1.2 * s, 1.1 * s, vd._p, CF(0, br.Y * 0.8, 0.25 * s) * ANG(0.45, 0, 0))
	if rig.eyes[1] then
		local eye = rig.eyes[1].part
		H.band(rig, eye, "IrisRim", ANG(PI / 2, 0, 0), eye.Size.X * 0.55, 0.12 * s, vd._a, 14)
	end
	local rp = H.band(rig, rig.body, "OrbitRing2", ANG(-0.6, 0, 0.4), br.X * 1.6, 0.08 * s, vd._s, 20)
	H.group(rig, "rings", rp)
end

---------------------------------------------------------------- DIVINE
function A.solaris(H, rig, vd, s)
	local br = rig.bodyRadius
	local rays = H.pivot(rig, rig.body, "Corona", CF(0, 0, 0.25 * s))
	H.group(rig, "rays", rays)
	for k = 1, 10 do
		local ang = k / 10 * PI * 2
		local pv = H.pivot(rig, rays.part, "Ray", CF(math.cos(ang) * br.X * 0.95, math.sin(ang) * br.Y * 0.95, 0) * ANG(0, 0, ang - PI / 2))
		H.diamond(rig, pv.part, "RayBlade", 0.9 * s, 0.45 * s, 0.12 * s, k % 2 == 0 and vd._a or C("#FFD02A"), CF(0, 0.35 * s, 0), Enum.Material.Neon)
		openable(H, rig, pv, V3(1, 0, 0), 0.6)
	end
	local ring = H.band(rig, rig.body, "CoreRing", ANG(PI / 2, 0, 0) * CF(0, 0.2 * s, 0), br.X * 0.85, 0.12 * s, vd._a, 18)
	glow(rig, rig.body, WHITE)
end

function A.aetherion(H, rig, vd, s)
	local br = rig.bodyRadius
	for _, side in ipairs({ -1, 1 }) do
		H.crystal(rig, rig.body, "ShoulderCrystal", 0.9 * s, 0.25 * s, C("#BFF6FF"), CF(side * br.X * 0.75, br.Y * 0.75, -br.Z * 0.3) * ANG(0.3, 0, -side * 0.5), Enum.Material.Glass, 0.1)
	end
	local orbit = H.pivot(rig, rig.body, "CrystalOrbit", CF(0, 1.4 * s, -1.5 * s))
	H.crystal(rig, orbit.part, "OrbitCrystal", 0.5 * s, 0.2 * s, vd._a, CF(1.4 * s, 0, 0), Enum.Material.Neon)
	H.group(rig, "ornamentOrbit", orbit)
end

function A.eternityOwl(H, rig, vd, s)
	local br = rig.bodyRadius
	for k = 1, 2 do
		local ring = H.band(rig, rig.body, "ClockRing", ANG(0.4 * k, 0, -0.3 * k), br.X * (1.7 + k * 0.3), 0.07 * s, k == 1 and vd._s or vd._a, 24)
		for m = 0, 3 do
			local ang = m / 4 * PI * 2
			H.blk(rig, ring.part, "Marker", V3(0.18, 0.3, 0.18) * s, C("#FFFFFF"), CF(math.cos(ang) * br.X * (1.7 + k * 0.3), 0, math.sin(ang) * br.X * (1.7 + k * 0.3)), Enum.Material.Neon)
		end
		ring.stepRate = k == 1 and 0.25 or -0.15
		H.group(rig, "clockRings", ring)
	end
	for _, e in ipairs(rig.eyes) do glow(rig, e.part, WHITE) end
end

function A.genesis(H, rig, vd, s)
	local br = rig.bodyRadius
	local rec = zchain(H, rig, rig.body, "Spine", CF(0, 0, br.Z * 0.8), 7, 0.85 * s, function(t) return (0.7 - t * 0.45) * s end,
		function(t, j) return j % 2 == 0 and vd._p or C("#F6F2E6") end, { kind = "spine", i = 1, amp = 0.22, freq = 1.0, lag = 0.65 })
	for j, part in ipairs(rec.parts) do
		H.ell(rig, part, "GoldBelly", V3(0.9, 0.45, 1.1) * s * (1 - j * 0.08), vd._s, CF(0, -0.28 * s * (1 - j * 0.08), 0))
	end
	H.diamond(rig, rec.parts[#rec.parts], "AuroraTip", 1.2 * s, 0.6 * s, 0.06 * s, vd._a, CF(0, 0, 0.7 * s) * ANG(PI / 2, 0, 0), Enum.Material.Neon, 0.2)
	for _, w in ipairs(rig.wings) do
		H.diamond(rig, w.e.part, "Inset", 0.9 * s, 0.5 * s, 0.05 * s, vd._a, CF(w.side * 0.6 * s, 0, -0.03), Enum.Material.Neon, 0.2)
	end
	local seed = H.pivot(rig, rig.body, "Seed", CF(0, -0.2 * s, -br.Z * 1.25))
	local sp = H.ell(rig, seed.part, "LightSeed", V3(0.35, 0.35, 0.35) * s, WHITE, CF(), Enum.Material.Neon, 0.1)
	H.group(rig, "seed", seed)
	glow(rig, sp.part, C("#FFE9A6"))
end

function A.infinityFox(H, rig, vd, s)
	local br = rig.bodyRadius
	local tailCols = { vd._p, H.lighten(vd._p, 0.2), vd._s, vd._a, WHITE }
	for i = 1, 9 do
		local off = (i - 5)
		local c0 = CF(off * 0.08 * s, 0.25 * s, br.Z * 0.9) * ANG(-0.55 - math.abs(off) * 0.04, off * 0.2, 0)
		local rec = zchain(H, rig, rig.body, "Tail" .. i, c0, 5, 0.55 * s, function(t) return (0.3 + math.sin(t * PI) * 0.12 - t * 0.14) * s end,
			function(t) local c = tailCols[math.clamp(math.floor(t * 4.99) + 1, 1, 5)]; return (i % 2 == 0) and c:Lerp(vd._a, 0.3) or c end,
			{ kind = "fan", i = i, n9 = 9, baseYaw = off * 0.2, amp = 0.18, freq = 1.6, lag = 0.55 },
			function(t) return t > 0.6 and Enum.Material.Neon or Enum.Material.SmoothPlastic end, function(t) return t > 0.6 and 0.1 or 0 end)
		local star = H.pivot(rig, rec.parts[#rec.parts], "TailStar", CF(0, 0, 0.45 * s))
		H.diamond(rig, star.part, "Star", 0.45 * s, 0.22 * s, 0.05 * s, WHITE, ANG(0, 0, PI / 4), Enum.Material.Neon)
		H.group(rig, "tailChains", rec)
		H.group(rig, "tailStars", star)
		reveal(rig, subtree(rig, { rec.parts[1] }))
	end
	local hr = rig.headRadius
	for k = 0, 6 do
		local ang = k / 7 * PI * 2
		H.ell(rig, rig.head, "Mane", V3(0.3, 0.6, 0.18) * s, k % 2 == 0 and vd._s or vd._a, CF(math.cos(ang) * hr.X * 0.85, math.sin(ang) * hr.Y * 0.75 - 0.2 * s, hr.Z * 0.55) * ANG(0, 0, ang - PI / 2) * CF(0, 0.2 * s, 0))
	end
	for _, e in ipairs(rig.eyes) do glow(rig, e.part, WHITE) end
end

return A
