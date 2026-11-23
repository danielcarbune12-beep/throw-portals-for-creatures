-- Original block/wedge architecture matching Maps/00_Portal_Sanctuary_Hub.png.
-- Shared by the public sanctuary and the eight gardens. All decoration is non-queryable.
local K = require(script.Parent.WorldKit)
local Art = {}
local V, CF, A, PI = Vector3.new, CFrame.new, CFrame.Angles, math.pi
local M = Enum.Material
local C = Color3.fromRGB
Art.Palette = {
	ivory = C(227, 219, 205),
	light = C(243, 235, 219),
	stone = C(172, 158, 153),
	gold = C(202, 157, 74),
	goldLight = C(234, 196, 111),
	violet = C(87, 56, 135),
	roof = C(71, 49, 112),
	lilac = C(168, 109, 231),
	mint = C(104, 190, 184),
	grass = C(108, 161, 76),
	leaf = C(80, 133, 63),
	pink = C(200, 117, 165),
	water = C(93, 182, 203),
}
local P = Art.Palette

function Art.Beam(a, b, width, depth, color, material)
	local y = (b - a).Unit
	local normal = math.abs(y.Z) > 0.98 and V(1, 0, 0) or V(0, 0, 1)
	local x = y:Cross(normal).Unit
	local z = x:Cross(y).Unit
	return K.block(CFrame.fromMatrix((a + b) / 2, x, y, z), V(width, (b - a).Magnitude, depth), color, material)
end
function Art.Gable(cf, width, rise, depth, color)
	-- Wedge high faces meet at the ridge. The older shared helper made a valley roof.
	K.wedge(cf * CF(-width / 4, rise / 2, 0) * A(0, PI / 2, 0), V(depth, rise, width / 2), color, M.Slate).Name = "RoofSlope"
	K.wedge(cf * CF(width / 4, rise / 2, 0) * A(0, -PI / 2, 0), V(depth, rise, width / 2), color, M.Slate).Name = "RoofSlope"
end
function Art.Diamond(cf, height, width, depth, color, material)
	-- Solid planar rhombus, long axis Y; four wedges, shared styling on every crest.
	for _, sign in ipairs({ -1, 1 }) do
		local c = cf * CF(0, sign * height / 4, 0) * A(0, PI / 2, sign < 0 and PI or 0)
		for _, side in ipairs({ -1, 1 }) do
			K.wedge(
				c * CF(0, 0, side * width / 4) * A(0, side > 0 and PI or 0, 0),
				V(depth, height / 2, width / 2),
				color,
				material
			)
		end
	end
end
function Art.Crest(cf, h)
	Art.Diamond(cf, h, h * 0.58, 0.22, P.gold, M.Metal)
	Art.Diamond(cf * CF(0, 0, -0.15), h * 0.69, h * 0.35, 0.10, P.lilac, M.SmoothPlastic)
end
function Art.Column(cf, h, width)
	K.block(cf * CF(0, 0.5, 0), V(width * 1.45, 1, width * 1.45), P.stone, M.Limestone, true)
	K.block(cf * CF(0, 1.15, 0), V(width * 1.25, 0.35, width * 1.25), P.gold, M.Metal)
	K.block(cf * CF(0, h / 2 + 1.3, 0), V(width, h, width), P.ivory, M.Limestone, true)
	for _, side in ipairs({ -1, 1 }) do
		K.block(
			cf * CF(side * width * 0.34, h / 2 + 1.3, -width * 0.51),
			V(width * 0.12, h * 0.84, 0.07),
			P.light,
			M.SmoothPlastic
		)
	end
	K.block(cf * CF(0, h + 1.5, 0), V(width * 1.32, 0.55, width * 1.32), P.gold, M.Metal)
	K.block(cf * CF(0, h + 2, 0), V(width * 1.48, 0.45, width * 1.48), P.light, M.Limestone)
end
function Art.Lantern(cf, scale, pointLight)
	local s = scale or 1
	K.block(cf * CF(0, 0.35 * s, 0), V(2.0, 0.7, 2.0) * s, P.ivory, M.Limestone)
	K.block(cf * CF(0, 2.4 * s, 0), V(0.52, 4, 0.52) * s, P.roof, M.Metal)
	local glow = K.block(cf * CF(0, 5 * s, 0), V(0.90, 1.75, 0.90) * s, C(255, 214, 151), M.Neon, false, 0.12)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			K.block(cf * CF(x * 0.52 * s, 5 * s, z * 0.52 * s), V(0.14, 2.05, 0.14) * s, P.gold, M.Metal)
		end
	end
	K.block(cf * CF(0, 6.05 * s, 0), V(1.45, 0.2, 1.45) * s, P.gold, M.Metal)
	K.pyramid(cf * CF(0, 6.15 * s, 0), 1.65 * s, 0.65 * s, P.roof, M.SmoothPlastic)
	if pointLight then
		K.lamp(glow, C(255, 217, 163), 16 * s, 0.65)
	end
	return glow
end
function Art.Banner(cf, h, w)
	K.block(cf * CF(0, -h / 2, 0), V(w, h, 0.18), P.violet, M.Fabric)
	K.block(cf * CF(0, 0.2, 0), V(w + 0.55, 0.30, 0.40), P.gold, M.Metal)
	for _, side in ipairs({ -1, 1 }) do
		K.block(cf * CF(side * (w / 2 - 0.13), -h / 2, -0.12), V(0.15, h, 0.08), P.goldLight, M.SmoothPlastic)
	end
	Art.Diamond(cf * CF(0, -h, 0), h * 0.30, w, 0.18, P.violet, M.Fabric)
	Art.Diamond(cf * CF(0, -h * 0.52, -0.15), math.min(w * 1.1, h * 0.45), w * 0.62, 0.08, P.goldLight, M.Metal)
	Art.Diamond(cf * CF(0, -h * 0.52, -0.21), math.min(w * 0.73, h * 0.30), w * 0.35, 0.04, P.violet, M.SmoothPlastic)
end
function Art.Crystal(cf, w, h, color)
	local original = K.Folder()
	local model = Instance.new("Model")
	model.Name = "FacetedCrystal"
	K.SetFolder(model)
	local core = K.block(cf * CF(0, h * 0.47, 0) * A(0, PI / 4, 0), V(w, h * 0.50, w), color, M.SmoothPlastic)
	model.PrimaryPart = core
	K.pyramid(cf * CF(0, h * 0.72, 0) * A(0, PI / 4, 0), w, h * 0.35, K.light(color, 0.18), M.SmoothPlastic)
	K.pyramid(cf * CF(0, h * 0.22, 0) * A(PI, PI / 4, 0), w, h * 0.22, K.dark(color, 0.13), M.SmoothPlastic)
	K.SetFolder(original)
	model.Parent = original
	return core, model
end
function Art.Fountain(cf, scale, name)
	local s = scale or 1
	local original = K.Folder()
	local model = Instance.new("Model")
	model.Name = name or "CrystalFountain"
	K.SetFolder(model)
	local function at(x, y, z)
		return cf * CF(x * s, y * s, z * s)
	end
	local function polygon(radius, y, height, color, material, n, thickness)
		n = n or 12
		for i = 0, n - 1 do
			local a = i / n * PI * 2
			K.block(
				at(math.sin(a) * radius, y, math.cos(a) * radius) * A(0, a, 0),
				V(2 * radius * math.tan(PI / n) + 0.1, height, thickness or 0.8) * s,
				color,
				material
			)
		end
	end
	K.vcyl((at(0, 0, 0)).Position, 0.5 * s, 21 * s, P.stone, M.Limestone)
	K.vcyl((at(0, 0.5, 0)).Position, 0.5 * s, 19.6 * s, P.light, M.Limestone)
	K.vcyl((at(0, 0.9, 0)).Position, 0.18 * s, 17.8 * s, P.water, M.SmoothPlastic)
	polygon(9.25, 1.12, 0.70, P.ivory, M.Limestone)
	polygon(9.70, 0.62, 0.15, P.gold, M.Metal, 12, 0.25)
	for i = 0, 7 do
		local a = i / 8 * PI * 2
		K.block(at(math.sin(a) * 4.8, 3.0, math.cos(a) * 4.8), V(0.60, 3.6, 0.60) * s, P.light, M.Limestone)
		K.block(
			at(math.sin(a + 0.18) * 5.1, 2.8, math.cos(a + 0.18) * 5.1) * A(0, a + 0.18, 0),
			V(1.55, 3.2, 0.055) * s,
			C(136, 220, 231),
			M.Glass,
			false,
			0.42
		)
	end
	K.vcyl((at(0, 4.4, 0)).Position, 0.50 * s, 11.8 * s, P.light, M.Limestone)
	K.vcyl((at(0, 4.9, 0)).Position, 0.14 * s, 10.8 * s, P.water, M.SmoothPlastic)
	polygon(5.65, 4.9, 0.48, P.ivory, M.Limestone, 12, 0.50)
	polygon(5.80, 4.45, 0.15, P.gold, M.Metal, 12, 0.20)
	K.vcyl((at(0, 4.8, 0)).Position, 1.1 * s, 3.4 * s, P.violet, M.SmoothPlastic)
	local core, crystals = Art.Crystal(at(0, 6.2, 0), 1.8 * s, 5.2 * s, P.lilac)
	crystals.Name = "IncomeCrystalAssembly"
	K.tag(crystals, "TPFC_Bob", { Amp = 0.18 * s, Period = 4, Spin = 10 })
	for _, side in ipairs({ -1, 1 }) do
		Art.Crystal(
			at(side * 1.8, 5.6, 0.3) * A(0, 0, -side * 0.25),
			1.1 * s,
			3.3 * s,
			side < 0 and C(155, 108, 216) or C(191, 148, 239)
		)
	end
	K.SetFolder(original)
	model.Parent = original
	return core, model
end
function Art.Planter(cf, length, pink)
	K.block(cf * CF(0, 0.45, 0), V(4.8, 0.9, length), P.ivory, M.Limestone)
	K.block(cf * CF(0, 0.92, 0), V(4.4, 0.08, length - 0.4), P.gold, M.Metal)
	K.block(cf * CF(0, 1.1, 0), V(3.8, 0.30, length - 0.8), C(65, 72, 49), M.Ground)
	for z = -length / 2 + 2, length / 2 - 1, 3 do
		K.bush((cf * CF(0, 1.2, z)).Position, 0.8, P.leaf)
		for i = 0, 2 do
			K.block(
				cf * CF(-0.85 + i * 0.8, 2.4 + (i % 2) * 0.35, z + i * 0.35),
				V(0.45, 1.1, 0.45),
				pink and P.pink or P.lilac,
				M.SmoothPlastic
			)
		end
	end
end
return Art
