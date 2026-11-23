-- Raised, angular bronze lettering made from actual parts, not a flat font.
local Text = {}
-- Normalized pen strokes; deliberately open counters stay readable at distance.
local glyphs = {
	B = { { { 0, 0 }, { 0, 1 }, { 0.7, 1 }, { 1, 0.8 }, { 0.7, 0.52 }, { 0, 0.52 } }, { { 0.7, 0.52 }, { 1, 0.25 }, { 0.75, 0 }, { 0, 0 } } },
	F = { { { 0, 0 }, { 0, 1 }, { 1, 1 } }, { { 0, 0.52 }, { 0.75, 0.52 } } },
	G = { { { 1, 0.85 }, { 0.75, 1 }, { 0.2, 1 }, { 0, 0.8 }, { 0, 0.2 }, { 0.2, 0 }, { 1, 0 }, { 1, 0.5 }, { 0.55, 0.5 } } },
	H = { { { 0, 0 }, { 0, 1 } }, { { 1, 0 }, { 1, 1 } }, { { 0, 0.5 }, { 1, 0.5 } } },
	A = { { { 0, 0 }, { 0.5, 1 }, { 1, 0 } }, { { 0.22, 0.42 }, { 0.78, 0.42 } } },
	C = { { { 1, 0.88 }, { 0.75, 1 }, { 0.2, 1 }, { 0, 0.8 }, { 0, 0.2 }, { 0.2, 0 }, { 0.8, 0 }, { 1, 0.12 } } },
	D = { { { 0, 0 }, { 0, 1 }, { 0.6, 1 }, { 1, 0.78 }, { 1, 0.22 }, { 0.6, 0 }, { 0, 0 } } },
	E = { { { 1, 1 }, { 0, 1 }, { 0, 0 }, { 1, 0 } }, { { 0, 0.52 }, { 0.75, 0.52 } } },
	I = { { { 0.15, 1 }, { 0.85, 1 } }, { { 0.5, 1 }, { 0.5, 0 } }, { { 0.15, 0 }, { 0.85, 0 } } },
	L = { { { 0, 1 }, { 0, 0 }, { 1, 0 } } },
	N = { { { 0, 0 }, { 0, 1 }, { 1, 0 }, { 1, 1 } } },
	O = {
		{ { 0.2, 0 }, { 0, 0.2 }, { 0, 0.8 }, { 0.2, 1 }, { 0.8, 1 }, { 1, 0.8 }, { 1, 0.2 }, { 0.8, 0 }, { 0.2, 0 } },
	},
	P = { { { 0, 0 }, { 0, 1 }, { 0.75, 1 }, { 1, 0.8 }, { 1, 0.6 }, { 0.75, 0.48 }, { 0, 0.48 } } },
	R = {
		{ { 0, 0 }, { 0, 1 }, { 0.75, 1 }, { 1, 0.8 }, { 1, 0.6 }, { 0.75, 0.48 }, { 0, 0.48 } },
		{ { 0.52, 0.48 }, {
			1,
			0,
		} },
	},
	S = {
		{
			{ 1, 0.9 },
			{ 0.75, 1 },
			{ 0.2, 1 },
			{ 0, 0.8 },
			{ 0.15, 0.55 },
			{ 0.85, 0.45 },
			{ 1, 0.2 },
			{ 0.8, 0 },
			{
				0.2,
				0,
			},
			{
				0,
				0.12,
			},
		},
	},
	T = { { { 0, 1 }, { 1, 1 } }, { { 0.5, 1 }, { 0.5, 0 } } },
	U = { { { 0, 1 }, { 0, 0.2 }, { 0.2, 0 }, { 0.8, 0 }, { 1, 0.2 }, { 1, 1 } } },
	X = { { { 0, 1 }, { 1, 0 } }, { { 0, 0 }, { 1, 1 } } },
	Y = { { { 0, 1 }, { 0.5, 0.52 }, { 1, 1 } }, { { 0.5, 0.52 }, { 0.5, 0 } } },
}
function Text.Build(board, word, maxHeight)
	local m = Instance.new("Model")
	m.Name = "ForgedLettering"
	m:SetAttribute("Text", word)
	local count = #word
	local h = math.min(maxHeight, board.Size.X / (math.max(1, count) * 0.83))
	local width, gap = h * 0.63, h * 0.20
	local total = count * (width + gap) - gap
	local function stroke(a, b, thick, depth, color, offset)
		local delta = b - a
		if delta.Magnitude < 0.001 then
			return
		end
		local up = delta.Unit
		local normal = board.CFrame.LookVector
		local right = up:Cross(normal).Unit
		local p = Instance.new("Part")
		p.Name = "LetterStroke"
		p.Size = Vector3.new(thick, delta.Magnitude + thick * 0.28, depth)
		p.CFrame = CFrame.fromMatrix((a + b) / 2 + normal * offset, right, up, right:Cross(up))
		p.Material, p.Color = Enum.Material.Metal, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.CastShadow = true
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = m
	end
	for i = 1, count do
		local letter = word:sub(i, i)
		local paths = glyphs[letter]
		if paths then
			local x = -total / 2 + (i - 1) * (width + gap)
			local function at(v)
				-- Roblox's Front face reads along local -X when viewed head-on.
				return board.CFrame * Vector3.new(-x - v[1] * width, (v[2] - 0.5) * h, -board.Size.Z / 2 - 0.055)
			end
			for _, path in paths do
				for n = 1, #path - 1 do
					local a, b = at(path[n]), at(path[n + 1])
					stroke(a, b, h * 0.15, 0.065, Color3.fromRGB(93, 66, 34), 0)
					stroke(a, b, h * 0.10, 0.055, Color3.fromRGB(247, 222, 169), 0.045)
				end
			end
		end
	end
	m.Parent = board.Parent
	return m
end
return Text
