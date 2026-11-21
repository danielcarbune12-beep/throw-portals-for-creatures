-- WorldBuilder: builds ONE long map — the start area (bases + training) and a 3200-stud
-- throwing lane split into 8 themed zones, with zone gates and distance markers.
-- Location: ServerScriptService > Server > WorldBuilder (ModuleScript)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local WorldBuilder = {}
local Terrain = workspace.Terrain
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local W = Config.MapHalfWidth

local folder
local rng = Random.new(1234)

---------------------------------------------------------------- primitives
local function mk(shape, size, cf, color, mat, collide, transp)
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanQuery = collide == true
	p.CanTouch = false
	p.Transparency = transp or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end
local function ball(pos, d, color, mat, collide, transp)
	return mk(Enum.PartType.Ball, Vector3.new(d, d, d), CFrame.new(pos), color, mat, collide, transp)
end
local function ellipse(cf, size, color, mat, collide, transp)
	local p = mk(Enum.PartType.Block, size, cf, color, mat, collide, transp)
	local m = Instance.new("SpecialMesh"); m.MeshType = Enum.MeshType.Sphere; m.Parent = p
	return p
end
local function vcyl(pos, height, d, color, mat, collide, transp)
	return mk(Enum.PartType.Cylinder, Vector3.new(height, d, d), CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, mat, collide, transp)
end
local function block(cf, size, color, mat, collide, transp)
	return mk(Enum.PartType.Block, size, cf, color, mat, collide, transp)
end
local function light(p, color, range, brightness)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = brightness or 1.5; l.Parent = p
end
local function sparkles(p, color, rate, tex)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = tex or SPARKLE
	pe.Color = ColorSequence.new(color)
	pe.LightEmission = 1
	pe.Rate = rate or 3
	pe.Lifetime = NumberRange.new(1.5, 3)
	pe.Speed = NumberRange.new(0.5, 1.5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Parent = p
end
local function textLabel(parent, text, color, face)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.CanvasSize = Vector2.new(600, 120)
	sg.LightInfluence = 0
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	local st = Instance.new("UIStroke"); st.Thickness = 4; st.Color = Color3.fromRGB(30, 20, 40); st.Parent = t
	t.Parent = sg
	sg.Parent = parent
	return t
end

-- random spot inside a zone. sides=true keeps it off the landing lane.
local function spot(b, sides)
	local z = rng:NextNumber(b[1] + 8, b[2] - 8)
	local x
	if sides then
		x = rng:NextNumber(Config.LaneHalfWidth + 22, W - 4) * (rng:NextNumber() < 0.5 and -1 or 1)
	else
		x = rng:NextNumber(-W + 6, W - 6)
	end
	return Vector3.new(x, 0, z)
end
local function count(b, per100) return math.max(2, math.floor((b[2] - b[1]) / 100 * per100)) end

---------------------------------------------------------------- props
local Props = {}
function Props.tree(pos, s, leafCols)
	vcyl(pos, 7 * s, 1.6 * s, Color3.fromRGB(120, 80, 50), Enum.Material.Wood, true)
	for _ = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-2, 2) * s, 7 * s + rng:NextNumber(0, 3) * s, rng:NextNumber(-2, 2) * s)
		ball(pos + off, rng:NextNumber(5, 7.5) * s, leafCols[rng:NextInteger(1, #leafCols)], Enum.Material.Grass)
	end
end
function Props.pine(pos, s, snowy)
	vcyl(pos, 3 * s, 1.2 * s, Color3.fromRGB(100, 70, 45), Enum.Material.Wood, true)
	for i = 0, 3 do
		local d = (8 - i * 1.8) * s
		local y = (3 + i * 2.6) * s
		ellipse(CFrame.new(pos + Vector3.new(0, y, 0)), Vector3.new(d, 3.6 * s, d), Color3.fromRGB(40, 110, 70), Enum.Material.Grass)
		if snowy then ellipse(CFrame.new(pos + Vector3.new(0, y + 0.9 * s, 0)), Vector3.new(d * 0.8, 1.6 * s, d * 0.8), Color3.new(1, 1, 1), Enum.Material.Snow) end
	end
end
function Props.flowers(pos, cols)
	for _ = 1, 6 do
		local p = pos + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		vcyl(p, 0.9, 0.15, Color3.fromRGB(70, 160, 60))
		ellipse(CFrame.new(p + Vector3.new(0, 1, 0)), Vector3.new(0.8, 0.35, 0.8), cols[rng:NextInteger(1, #cols)])
	end
end
function Props.mushroom(pos, s, cap, glow)
	vcyl(pos, 2 * s, 0.9 * s, Color3.fromRGB(245, 235, 220))
	local c = ellipse(CFrame.new(pos + Vector3.new(0, 2.1 * s, 0)), Vector3.new(3.2, 1.8, 3.2) * s, cap, glow and Enum.Material.Neon or Enum.Material.SmoothPlastic)
	if glow then light(c, cap, 12, 1) end
end
function Props.rock(pos, s, col, mat)
	ellipse(CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
		Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2, 4), rng:NextNumber(3, 6)) * s, col, mat or Enum.Material.Slate, true)
end
function Props.crystal(pos, s, col)
	for i = 1, rng:NextInteger(3, 5) do
		local h = rng:NextNumber(3, 8) * s
		local p = block(CFrame.new(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), h / 2 - 0.5, rng:NextNumber(-1.5, 1.5)))
			* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			Vector3.new(1.2 * s, h, 1.2 * s), col, i % 2 == 0 and Enum.Material.Neon or Enum.Material.Glass, true, i % 2 == 0 and 0 or 0.2)
		if i == 1 then light(p, col, 14, 1.2) end
	end
end
function Props.lollipop(pos, s)
	vcyl(pos, 7 * s, 0.5 * s, Color3.new(1, 1, 1), nil, true)
	local col = Color3.fromHSV(rng:NextNumber(), 0.6, 1)
	local cf = CFrame.new(pos + Vector3.new(0, 8.5 * s, 0))
	mk(Enum.PartType.Cylinder, Vector3.new(0.8 * s, 5 * s, 5 * s), cf, col, nil, true)
	mk(Enum.PartType.Cylinder, Vector3.new(0.9 * s, 3.3 * s, 3.3 * s), cf, Color3.new(1, 1, 1))
	mk(Enum.PartType.Cylinder, Vector3.new(1 * s, 1.6 * s, 1.6 * s), cf, col)
end
function Props.gumdrop(pos, s)
	ellipse(CFrame.new(pos + Vector3.new(0, 1 * s, 0)), Vector3.new(3.5, 3.5, 3.5) * s, Color3.fromHSV(rng:NextNumber(), 0.55, 1), Enum.Material.Glass, true, 0.15)
end
function Props.candycane(pos, s)
	for i = 0, 5 do
		vcyl(pos + Vector3.new(0, i * 1.2 * s, 0), 1.2 * s, 0.8 * s, i % 2 == 0 and Color3.fromRGB(230, 40, 50) or Color3.new(1, 1, 1), nil, true)
	end
end
function Props.deadtree(pos, s, col)
	vcyl(pos, 8 * s, 1.2 * s, col, Enum.Material.Wood, true)
	for _ = 1, 4 do
		local y = rng:NextNumber(4, 8) * s
		block(CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.8) * CFrame.new(0, 1.5 * s, 0), Vector3.new(0.5, 3.5, 0.5) * s, col, Enum.Material.Wood)
	end
end
function Props.cloud(pos, s, glow)
	for _ = 1, 5 do
		ball(pos + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(0, 1.5), rng:NextNumber(-2, 2)) * s, rng:NextNumber(3, 5) * s,
			Color3.new(1, 1, 1), glow and Enum.Material.Neon or Enum.Material.SmoothPlastic, false, glow and 0.3 or 0)
	end
end
function Props.pillar(pos, s, col, mat)
	vcyl(pos, 14 * s, 2.4 * s, col, mat or Enum.Material.Marble, true)
	vcyl(pos + Vector3.new(0, 14 * s, 0), 1 * s, 3.4 * s, col, mat)
end
function Props.planet(pos, s)
	local col = Color3.fromHSV(rng:NextNumber(), 0.5, 0.9)
	ball(pos, 14 * s, col)
	mk(Enum.PartType.Cylinder, Vector3.new(0.3, 24 * s, 24 * s), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2 + 0.4), col:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon, false, 0.5)
end
function Props.lamp(pos, col)
	vcyl(pos, 7, 0.4, Color3.fromRGB(40, 35, 50), Enum.Material.Metal, true)
	local b = ball(pos + Vector3.new(0, 7.3, 0), 1.4, col, Enum.Material.Neon)
	light(b, col, 18, 1.5)
end
function Props.snowman(pos)
	ball(pos + Vector3.new(0, 1.8, 0), 4, Color3.new(1, 1, 1), Enum.Material.Snow, true)
	ball(pos + Vector3.new(0, 4.6, 0), 3, Color3.new(1, 1, 1), Enum.Material.Snow, true)
	ball(pos + Vector3.new(0, 6.6, 0), 2.2, Color3.new(1, 1, 1), Enum.Material.Snow, true)
end
function Props.tower(pos, s, col, roof)
	vcyl(pos, 18 * s, 8 * s, col, Enum.Material.Ice, true, 0.1)
	for i = 0, 3 do
		ellipse(CFrame.new(pos + Vector3.new(0, 18 * s + i * 2.2 * s, 0)), Vector3.new(9 - i * 2.2, 3, 9 - i * 2.2) * s, roof, Enum.Material.Glass, false, 0.1)
	end
end
function Props.volcano(pos)
	for i = 0, 7 do
		vcyl(pos + Vector3.new(0, i * 7, 0), 7.2, 90 - i * 10, Color3.fromRGB(70 - i * 3, 45, 40), Enum.Material.Basalt, true)
	end
	local lava = vcyl(pos + Vector3.new(0, 56, 0), 1, 18, Color3.fromRGB(255, 110, 20), Enum.Material.Neon)
	light(lava, Color3.fromRGB(255, 120, 40), 60, 4)
	local f = Instance.new("Fire"); f.Size = 25; f.Heat = 25; f.Parent = lava
	sparkles(lava, Color3.fromRGB(80, 60, 60), 6, SMOKE)
end
function Props.lavapool(pos, s)
	local p = vcyl(pos - Vector3.new(0, 0.4, 0), 0.6, rng:NextNumber(10, 20) * s, Color3.fromRGB(255, 100, 20), Enum.Material.Neon)
	light(p, Color3.fromRGB(255, 120, 30), 20, 2)
end

---------------------------------------------------------------- zone themes (b = {fromZ, toZ}, m = zone middle)
local Themes = {}
Themes.Forest = function(b, m)
	local leaves = { Color3.fromRGB(80, 170, 70), Color3.fromRGB(110, 200, 80), Color3.fromRGB(60, 150, 75), Color3.fromRGB(150, 210, 90) }
	for _ = 1, count(b, 14) do Props.tree(spot(b, true), rng:NextNumber(0.9, 1.6), leaves) end
	for _ = 1, count(b, 12) do Props.flowers(spot(b), { Color3.fromRGB(255, 120, 170), Color3.fromRGB(255, 240, 120), Color3.fromRGB(170, 140, 255), Color3.new(1, 1, 1) }) end
	for _ = 1, count(b, 5) do Props.mushroom(spot(b, true), rng:NextNumber(0.8, 1.6), Color3.fromRGB(230, 60, 60)) end
end
Themes.Volcano = function(b, m)
	Props.volcano(Vector3.new(-150, 0, m.Z))
	for _ = 1, count(b, 5) do Props.lavapool(spot(b), 1) end
	for _ = 1, count(b, 12) do Props.rock(spot(b, true), rng:NextNumber(0.8, 2), Color3.fromRGB(45, 35, 35), Enum.Material.Basalt) end
	for _ = 1, count(b, 5) do Props.deadtree(spot(b, true), rng:NextNumber(0.8, 1.3), Color3.fromRGB(40, 30, 30)) end
	for _ = 1, count(b, 4) do Props.crystal(spot(b, true), 0.8, Color3.fromRGB(255, 120, 40)) end
end
Themes.Frozen = function(b, m)
	for _ = 1, count(b, 12) do Props.pine(spot(b, true), rng:NextNumber(0.9, 1.6), true) end
	for _ = 1, count(b, 6) do Props.crystal(spot(b, true), 1.2, Color3.fromRGB(170, 230, 255)) end
	for _ = 1, count(b, 2) do Props.snowman(spot(b)) end
	for i = -1, 1 do Props.tower(Vector3.new(58, 0, m.Z + i * 40), i == 0 and 1.3 or 0.9, Color3.fromRGB(190, 230, 255), Color3.fromRGB(120, 190, 255)) end
end
Themes.Crystal = function(b, m)
	local cols = { Color3.fromRGB(190, 90, 255), Color3.fromRGB(80, 230, 255), Color3.fromRGB(255, 100, 210), Color3.fromRGB(120, 255, 180) }
	for _ = 1, count(b, 16) do Props.crystal(spot(b, true), rng:NextNumber(0.8, 2.2), cols[rng:NextInteger(1, #cols)]) end
	for _ = 1, count(b, 5) do Props.mushroom(spot(b), rng:NextNumber(0.8, 1.4), cols[rng:NextInteger(1, #cols)], true) end
end
Themes.Candy = function(b, m)
	for _ = 1, count(b, 8) do Props.lollipop(spot(b, true), rng:NextNumber(0.8, 1.5)) end
	for _ = 1, count(b, 8) do Props.gumdrop(spot(b), rng:NextNumber(0.7, 1.6)) end
	for _ = 1, count(b, 6) do Props.candycane(spot(b, true), rng:NextNumber(0.8, 1.4)) end
	block(CFrame.new(52, -0.3, m.Z), Vector3.new(12, 0.8, b[2] - b[1]), Color3.fromRGB(110, 60, 35), Enum.Material.Sand)
	for _ = 1, count(b, 4) do Props.cloud(spot(b) + Vector3.new(0, 45, 0), 1.6) end
end
Themes.Space = function(b, m)
	for _ = 1, count(b, 3) do Props.planet(spot(b) + Vector3.new(0, rng:NextNumber(60, 120), 0), rng:NextNumber(1, 2.5)) end
	for _ = 1, count(b, 25) do ball(spot(b) + Vector3.new(0, rng:NextNumber(30, 160), 0), rng:NextNumber(0.4, 1.2), Color3.new(1, 1, 0.9), Enum.Material.Neon) end
	for _ = 1, count(b, 6) do Props.crystal(spot(b, true), 1, Color3.fromRGB(120, 255, 200)) end
	for _ = 1, count(b, 8) do Props.rock(spot(b, true), rng:NextNumber(1, 2), Color3.fromRGB(90, 95, 130), Enum.Material.Limestone) end
end
Themes.Shadow = function(b, m)
	for _ = 1, count(b, 8) do Props.deadtree(spot(b, true), rng:NextNumber(1, 1.8), Color3.fromRGB(35, 25, 45)) end
	for _ = 1, count(b, 5) do Props.crystal(spot(b, true) + Vector3.new(0, rng:NextNumber(0, 18), 0), 1.2, Color3.fromRGB(150, 40, 255)) end
	for _ = 1, count(b, 5) do Props.lamp(spot(b, true), Color3.fromRGB(190, 80, 255)) end
	for _ = 1, count(b, 3) do Props.pillar(spot(b, true), rng:NextNumber(0.6, 1.2), Color3.fromRGB(50, 40, 60), Enum.Material.Slate) end
end
Themes.Heaven = function(b, m)
	for _ = 1, count(b, 8) do Props.cloud(spot(b) + Vector3.new(0, rng:NextNumber(0, 3), 0), rng:NextNumber(1, 2)) end
	for _ = 1, count(b, 4) do Props.cloud(spot(b) + Vector3.new(0, rng:NextNumber(30, 80), 0), rng:NextNumber(2, 4), true) end
	for _ = 1, count(b, 4) do Props.pillar(spot(b, true), rng:NextNumber(0.8, 1.6), Color3.fromRGB(255, 225, 140), Enum.Material.Marble) end
	-- giant rainbow arch over the lane
	for i = 0, 24 do
		local a = i / 24 * math.pi
		ball(Vector3.new(math.cos(a) * (W + 10), math.sin(a) * 70, m.Z), 10, Color3.fromHSV(i / 24, 0.6, 1), Enum.Material.Neon, false, 0.2)
	end
end

---------------------------------------------------------------- scenery: mountains, rivers, islands, lane edges
local ROCK_COLORS = {
	Forest = Color3.fromRGB(120, 125, 115), Volcano = Color3.fromRGB(55, 40, 40), Frozen = Color3.fromRGB(170, 200, 230), Crystal = Color3.fromRGB(70, 55, 110),
	Candy = Color3.fromRGB(255, 200, 225), Space = Color3.fromRGB(80, 80, 130), Shadow = Color3.fromRGB(35, 25, 50), Heaven = Color3.fromRGB(255, 245, 225),
}
-- big hills on both sides of the map turn it into a valley/canyon
local function mountains(z1, z2, zoneId, halfWidth)
	local Wd = Config.Worlds[zoneId]
	local hw = halfWidth or W
	local z = z1
	while z < z2 do
		for s = -1, 1, 2 do
			-- inner edge of every hill stays at the wall, so the valley floor stays clear
			local r = rng:NextNumber(32, 58)
			local c = Vector3.new(s * (hw + r * 0.85 + rng:NextNumber(0, 18)), rng:NextNumber(-18, 6), z + rng:NextNumber(-10, 10))
			Terrain:FillBall(c, r, zoneId == "Forest" and Enum.Material.Rock or Wd.material)
			Terrain:FillBall(c + Vector3.new(0, r * 0.45, 0), r * 0.7, Wd.material)
		end
		z += rng:NextNumber(35, 55)
	end
end

local function river(z1, z2, mat)
	for s = -1, 1, 2 do
		local x = s * (Config.LaneHalfWidth + 14)
		Terrain:FillBlock(CFrame.new(x, -2, (z1 + z2) / 2), Vector3.new(10, 6, z2 - z1), Enum.Material.Air)
		Terrain:FillBlock(CFrame.new(x, -3, (z1 + z2) / 2), Vector3.new(10, 4, z2 - z1), mat or Enum.Material.Water)
	end
end

local function floatingIsland(pos, s, topCol, topMat, waterfall)
	ellipse(CFrame.new(pos), Vector3.new(26, 14, 22) * s, Color3.fromRGB(110, 85, 70), Enum.Material.Slate)
	ellipse(CFrame.new(pos + Vector3.new(0, -9, 0) * s), Vector3.new(14, 12, 12) * s, Color3.fromRGB(95, 75, 60), Enum.Material.Slate)
	ellipse(CFrame.new(pos + Vector3.new(0, 6, 0) * s), Vector3.new(27, 3, 23) * s, topCol, topMat or Enum.Material.Grass)
	Props.tree(pos + Vector3.new(-3, 7, 2) * s, 0.9 * s, { topCol:Lerp(Color3.new(0, 0, 0), 0.15), topCol })
	if waterfall then
		local fall = block(CFrame.new(pos + Vector3.new(11, -20, 0) * s), Vector3.new(4, 52, 2) * s, Color3.fromRGB(150, 220, 255), Enum.Material.Neon, false, 0.45)
		sparkles(fall, Color3.fromRGB(220, 245, 255), 12)
	end
end

local function laneEdges(z1, z2, col)
	for s = -1, 1, 2 do
		local strip = block(CFrame.new(s * Config.LaneHalfWidth, 0.25, (z1 + z2) / 2), Vector3.new(1.2, 0.5, z2 - z1), col, Enum.Material.Neon, false, 0.1)
		strip.Name = "LaneEdge"
	end
	-- glowing lanterns every 100 studs
	for z = z1 + 25, z2 - 10, 100 do
		for s = -1, 1, 2 do
			local x = s * (Config.LaneHalfWidth + 4)
			vcyl(Vector3.new(x, 0, z), 9, 0.6, Color3.fromRGB(50, 45, 60), Enum.Material.Metal)
			local orb = ball(Vector3.new(x, 9.6, z), 2.2, col, Enum.Material.Neon)
			light(orb, col, 26, 1.6)
		end
	end
end

-- THE PORTAL LAUNCH HALL: a building you walk into. Its front is open onto the lane
-- (sealed by a force field), and its floor is the only place you can throw from.
local function launchHall()
	local hw, back, front = Config.HallHalfWidth, Config.HallBackZ, Config.BarrierZ
	local depth = front - back
	local midZ = (front + back) / 2
	local H = 26
	local wallCol, trim = Color3.fromRGB(90, 60, 160), Color3.fromRGB(255, 120, 220)
	-- floor
	block(CFrame.new(0, 0.6, midZ), Vector3.new(hw * 2, 1.2, depth), Color3.fromRGB(235, 235, 245), Enum.Material.Marble, true)
	local pad = block(CFrame.new(0, 1.25, (Config.ThrowZone.minZ + Config.ThrowZone.maxZ) / 2), Vector3.new(hw * 2 - 4, 0.15, Config.ThrowZone.maxZ - Config.ThrowZone.minZ - 2),
		Color3.fromRGB(255, 120, 200), Enum.Material.Neon, false, 0.8)
	pad.Name = "ThrowZonePad"
	-- arrow on the floor pointing at the lane
	for i = 0, 2 do
		local a = block(CFrame.new(0, 1.35, -22 + i * 7) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(5, 0.2, 5), Color3.fromRGB(255, 230, 100), Enum.Material.Neon, false, 0.2)
		a.Name = "Arrow"
	end
	-- side walls with neon trims and windows
	for s = -1, 1, 2 do
		block(CFrame.new(s * (hw + 1), H / 2, midZ), Vector3.new(2, H, depth), wallCol, Enum.Material.Brick, true)
		block(CFrame.new(s * hw, 2.4, midZ), Vector3.new(0.4, 0.6, depth), trim, Enum.Material.Neon, false)
		block(CFrame.new(s * hw, H - 2, midZ), Vector3.new(0.4, 0.6, depth), trim, Enum.Material.Neon, false)
		local screen = block(CFrame.new(s * (hw - 0.2), 13, midZ - 4), Vector3.new(0.3, 7, 22), Color3.fromRGB(20, 15, 40), Enum.Material.SmoothPlastic, false)
		textLabel(screen, "HOLD TO CHARGE  •  RELEASE TO THROW", Color3.fromRGB(255, 230, 120), s < 0 and Enum.NormalId.Right or Enum.NormalId.Left)
		for k = 0, 2 do
			local lamp = ball(Vector3.new(s * (hw - 1.5), 19, back + 8 + k * 12), 2.2, Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
			light(lamp, Color3.fromRGB(255, 200, 140), 22, 1.4)
		end
	end
	-- back wall with a big doorway (you enter from the street)
	local door = 18
	for s = -1, 1, 2 do
		local wseg = (hw * 2 + 4 - door) / 2
		block(CFrame.new(s * (door / 2 + wseg / 2), H / 2, back - 1), Vector3.new(wseg, H, 2), wallCol, Enum.Material.Brick, true)
	end
	block(CFrame.new(0, H - 4, back - 1), Vector3.new(door, 8, 2), wallCol, Enum.Material.Brick, true)
	for s = -1, 1, 2 do
		vcyl(Vector3.new(s * (door / 2 + 1), 0, back - 2), H - 7, 2.2, trim, Enum.Material.Neon, true)
	end
	local sign = block(CFrame.new(0, H + 3, back - 2.2), Vector3.new(hw * 2 + 4, 6, 1), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
	textLabel(sign, "🌀 PORTAL LAUNCH HALL 🌀", Color3.fromRGB(140, 60, 220), Enum.NormalId.Back)
	textLabel(sign, "🌀 PORTAL LAUNCH HALL 🌀", Color3.fromRGB(140, 60, 220), Enum.NormalId.Front)
	-- roof (no collision so the camera passes through it), covering the back half
	local roof = block(CFrame.new(0, H + 0.5, back + 10), Vector3.new(hw * 2 + 6, 1, 22), Color3.fromRGB(60, 40, 110), Enum.Material.SmoothPlastic, false)
	roof.CanQuery = false
	-- front arch framing the lane
	for i = 0, 20 do
		local a = i / 20 * math.pi
		ball(Vector3.new(math.cos(a) * (hw + 1), 4 + math.sin(a) * (H - 4), front + 1), 3, Color3.fromHSV(i / 20, 0.5, 1), Enum.Material.Neon, false)
	end
	-- the force field you can't walk through
	local wall = block(CFrame.new(0, 60, front), Vector3.new(Config.StartHalfWidth * 2 + 40, 140, 2), Color3.fromRGB(150, 110, 255), Enum.Material.ForceField, true, 0.35)
	wall.Name = "Barrier"
	wall.CanQuery = false
	local glow = block(CFrame.new(0, 1.4, front), Vector3.new(hw * 2, 0.4, 2.4), Color3.fromRGB(190, 140, 255), Enum.Material.Neon, false)
	glow.Name = "BarrierGlow"
	-- low hedge walls closing the rest of the start area's front edge
	for s = -1, 1, 2 do
		local len = Config.StartHalfWidth - hw - 2
		ellipse(CFrame.new(s * (hw + 2 + len / 2), 3, front - 1), Vector3.new(len, 6, 5), Color3.fromRGB(70, 150, 70), Enum.Material.Grass, true)
	end
end

local function fountain(pos, s)
	s = s or 1
	vcyl(pos, 2, 20 * s, Color3.fromRGB(230, 230, 240), Enum.Material.Marble, true)
	vcyl(pos + Vector3.new(0, 1.9, 0), 0.3, 18 * s, Color3.fromRGB(90, 200, 255), Enum.Material.Glass, false, 0.25)
	vcyl(pos, 7 * s, 3 * s, Color3.fromRGB(230, 230, 240), Enum.Material.Marble, true)
	vcyl(pos + Vector3.new(0, 7 * s, 0), 1, 9 * s, Color3.fromRGB(230, 230, 240), Enum.Material.Marble, true)
	local orb = ball(pos + Vector3.new(0, 11 * s, 0), 4.5 * s, Color3.fromRGB(170, 120, 255), Enum.Material.Neon)
	light(orb, Color3.fromRGB(170, 120, 255), 35, 2.5)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = SPARKLE
	pe.Color = ColorSequence.new(Color3.fromRGB(150, 220, 255), Color3.fromRGB(220, 170, 255))
	pe.Rate = 50; pe.Speed = NumberRange.new(10, 15); pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = Vector3.new(0, -25, 0); pe.Lifetime = NumberRange.new(1, 1.5); pe.LightEmission = 1
	pe.Size = NumberSequence.new(0.7, 0.2)
	pe.Parent = orb
end

---------------------------------------------------------------- gates + markers
local function zoneGate(id, z)
	local Wd = Config.Worlds[id]
	local col = Wd.atmo
	for s = -1, 1, 2 do
		vcyl(Vector3.new(s * (Config.LaneHalfWidth + 12), 0, z), 34, 6, col:Lerp(Color3.new(1, 1, 1), 0.3), Enum.Material.Marble, true)
		local orb = ball(Vector3.new(s * (Config.LaneHalfWidth + 12), 37, z), 7, col, Enum.Material.Neon)
		light(orb, col, 30, 2)
	end
	-- giant glowing ring framing the lane
	for i = 1, 36 do
		local a = i / 36 * math.pi * 2
		local p = Vector3.new(math.cos(a) * (Config.LaneHalfWidth + 12), 38 + math.sin(a) * 30, z)
		if p.Y > 1 then ball(p, 5, i % 2 == 0 and col or col:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Neon, false, 0.1) end
	end
	local beam = block(CFrame.new(0, 32, z), Vector3.new(Config.LaneHalfWidth * 2 + 30, 7, 2), col:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.SmoothPlastic, false)
	local b = Config.ZoneBounds[id]
	local txt = Wd.name:upper() .. "  •  " .. b[1] .. "m"
	textLabel(beam, txt, Color3.new(1, 1, 1), Enum.NormalId.Front)
	textLabel(beam, txt, Color3.new(1, 1, 1), Enum.NormalId.Back)
end

local function distanceMarker(z)
	local line = block(CFrame.new(0, 0.12, z), Vector3.new(Config.LaneHalfWidth * 2, 0.2, 0.8), Color3.new(1, 1, 1), Enum.Material.Neon, false, 0.55)
	line.Name = "Marker"
	for s = -1, 1, 2 do
		local post = block(CFrame.new(s * (Config.LaneHalfWidth + 4), 3, z), Vector3.new(0.6, 6, 0.6), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, false)
		local sign = block(CFrame.new(s * (Config.LaneHalfWidth + 4), 7, z), Vector3.new(7, 2.6, 0.4), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, false)
		textLabel(sign, z .. "m", Color3.fromRGB(80, 60, 140), Enum.NormalId.Back)
		textLabel(sign, z .. "m", Color3.fromRGB(80, 60, 140), Enum.NormalId.Front)
	end
end

---------------------------------------------------------------- start area + training
local function buildStart()
	local depth = Config.StartDepth
	local SW = Config.StartHalfWidth
	Terrain:FillBlock(CFrame.new(0, -6, -depth / 2 - 10), Vector3.new(SW * 2 + 80, 12, depth + 30), Enum.Material.Grass)
	launchHall()
	mountains(-depth - 30, 0, "Forest", SW)
	-- main street from the hall back to the training area, bases on both sides
	local streetLen = depth - 40
	block(CFrame.new(0, 0.15, Config.HallBackZ - streetLen / 2), Vector3.new(50, 0.3, streetLen), Color3.fromRGB(190, 180, 165), Enum.Material.Cobblestone, true)
	for s = -1, 1, 2 do
		block(CFrame.new(s * 25.5, 0.35, Config.HallBackZ - streetLen / 2), Vector3.new(1, 0.4, streetLen), Color3.fromRGB(255, 220, 120), Enum.Material.Neon, false, 0.3)
	end
	for z = -60, -350, -38 do
		for s = -1, 1, 2 do Props.lamp(Vector3.new(s * 24.5, 0, z), Color3.fromRGB(255, 210, 140)) end
	end
	fountain(Vector3.new(0, 0, -330), 1)
	for i = 1, 4 do
		floatingIsland(Vector3.new((i % 2 == 0 and 1 or -1) * rng:NextNumber(70, 120), rng:NextNumber(65, 95), -depth + i * 100), rng:NextNumber(0.8, 1.2),
			Color3.fromRGB(120, 210, 90), Enum.Material.Grass, i % 2 == 1)
	end
	-- trees around the back of the start area
	local leaves = { Color3.fromRGB(80, 170, 70), Color3.fromRGB(110, 200, 80), Color3.fromRGB(150, 210, 90) }
	for _ = 1, 22 do
		local x = rng:NextNumber(-SW + 6, SW - 6)
		local z = rng:NextNumber(-depth + 8, -depth + 35)
		Props.tree(Vector3.new(x, 0, z), rng:NextNumber(1, 1.5), leaves)
	end
	-- spawn on the street, just behind the hall
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.6, -60)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = workspace
end

local function buildTraining()
	local tf = Instance.new("Folder")
	tf.Name = "Training"
	tf.Parent = workspace
	local prev = folder
	for i, st in ipairs(Config.TrainingStations) do
		local m = Instance.new("Model")
		m.Name = "Station" .. i
		m.Parent = tf
		folder = m
		local p = st.pos
		local pad = vcyl(p, 0.8, 14, st.color:Lerp(Color3.new(1, 1, 1), 0.6), Enum.Material.SmoothPlastic, true)
		pad.Name = "Pad"
		local ring = mk(Enum.PartType.Cylinder, Vector3.new(0.3, 15, 15), CFrame.new(p + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.pi / 2), st.color, Enum.Material.Neon)
		-- the equipment
		local barY = 3.2
		if i == 3 then
			ellipse(CFrame.new(p + Vector3.new(0, 2.6, 0)), Vector3.new(4, 4, 4), st.color, Enum.Material.Metal, true)
			mk(Enum.PartType.Cylinder, Vector3.new(0.6, 3, 3), CFrame.new(p + Vector3.new(0, 5, 0)), st.color, Enum.Material.Metal)
		elseif i == 5 then
			for k = 1, 3 do
				mk(Enum.PartType.Cylinder, Vector3.new(0.5, 8 + k * 2, 8 + k * 2), CFrame.new(p + Vector3.new(0, 6, 0)) * CFrame.Angles(k * 0.9, k * 0.5, 0), st.color, Enum.Material.Neon, false, 0.2)
			end
			local core = ball(p + Vector3.new(0, 6, 0), 3, Color3.new(1, 1, 1), Enum.Material.Neon)
			light(core, st.color, 25, 3)
			sparkles(core, st.color, 8)
		else
			mk(Enum.PartType.Cylinder, Vector3.new(9, 0.6, 0.6), CFrame.new(p + Vector3.new(0, barY, 0)), Color3.fromRGB(80, 80, 90), Enum.Material.Metal)
			for s = -1, 1, 2 do
				mk(Enum.PartType.Cylinder, Vector3.new(0.9, 3.4, 3.4), CFrame.new(p + Vector3.new(s * 3.6, barY, 0)), st.color, i == 4 and Enum.Material.Neon or Enum.Material.Metal)
				block(CFrame.new(p + Vector3.new(s * 2.6, barY / 2 + 0.5, 0)), Vector3.new(0.5, barY, 0.5), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
			end
		end
		-- sign
		local anchor = block(CFrame.new(p + Vector3.new(0, 10, 0)), Vector3.new(0.2, 0.2, 0.2), Color3.new(1, 1, 1), nil, false, 1)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(14, 4)
		bb.MaxDistance = 120
		bb.LightInfluence = 0
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Font = Enum.Font.FredokaOne
		t.TextScaled = true
		t.RichText = true
		t.TextColor3 = Color3.new(1, 1, 1)
		local price = st.price > 0 and ("\n<font color='#FFD36B'>Buy for $" .. (st.price >= 1000000 and (st.price / 1000000 .. "M") or (st.price >= 1000 and (st.price / 1000 .. "K") or tostring(st.price))) .. "</font>") or "\n<font color='#FFD36B'>FREE</font>"
		t.Text = string.format("%s\n<font color='#9CFFA8'>+%d Strength/lift</font>%s", st.name, st.gain, price)
		local stroke = Instance.new("UIStroke"); stroke.Thickness = 3; stroke.Parent = t
		t.Parent = bb
		bb.Parent = anchor
		m:SetAttribute("Index", i)
	end
	folder = prev
	-- training area sign
	local sign = block(CFrame.new(0, 17, -86), Vector3.new(44, 7, 1.5), Color3.fromRGB(255, 140, 60), Enum.Material.SmoothPlastic, false)
	textLabel(sign, "💪 TRAINING AREA 💪", Color3.new(1, 1, 1), Enum.NormalId.Front)
	textLabel(sign, "💪 TRAINING AREA 💪", Color3.new(1, 1, 1), Enum.NormalId.Back)
end

---------------------------------------------------------------- build
function WorldBuilder.BuildAll()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	-- animated grass blades, prettier water
	pcall(function() Terrain.Decoration = true end)
	Terrain.WaterColor = Color3.fromRGB(40, 190, 230)
	Terrain.WaterTransparency = 0.6
	Terrain.WaterWaveSize = 0.25
	Terrain.WaterWaveSpeed = 12
	Terrain.WaterReflectance = 0.6
	Terrain:SetMaterialColor(Enum.Material.Glacier, Color3.fromRGB(150, 220, 255))
	Terrain:SetMaterialColor(Enum.Material.CrackedLava, Color3.fromRGB(255, 110, 30))
	Terrain:SetMaterialColor(Enum.Material.Rock, ROCK_COLORS.Forest)
	folder = Instance.new("Folder"); folder.Name = "Start"; folder.Parent = map
	buildStart()
	-- (training now happens in each player's personal gym inside their base)
	for _, id in ipairs(Config.WorldOrder) do
		local Wd = Config.Worlds[id]
		local b = Config.ZoneBounds[id]
		local m = Config.WorldCenter(id)
		folder = Instance.new("Folder"); folder.Name = id; folder.Parent = map
		Terrain:SetMaterialColor(Wd.material, Wd.groundColor)
		Terrain:FillBlock(CFrame.new(0, -6, m.Z), Vector3.new(W * 2 + 120, 12, b[2] - b[1] + 4), Wd.material)
		zoneGate(id, b[1] + 2)
		mountains(b[1], b[2], id)
		laneEdges(b[1], b[2], Wd.atmo)
		if id == "Forest" or id == "Crystal" or id == "Heaven" then river(b[1], b[2], Enum.Material.Water)
		elseif id == "Frozen" then river(b[1], b[2], Enum.Material.Glacier)
		elseif id == "Volcano" then river(b[1], b[2], Enum.Material.CrackedLava) end
		for _ = 1, math.max(2, math.floor((b[2] - b[1]) / 150)) do
			local isl = Vector3.new(rng:NextNumber(-95, 95), rng:NextNumber(60, 110), rng:NextNumber(b[1], b[2]))
			floatingIsland(isl, rng:NextNumber(0.8, 1.6), Wd.groundColor, Wd.material == Enum.Material.Grass and Enum.Material.Grass or Enum.Material.SmoothPlastic, rng:NextNumber() < 0.6)
		end
		local ok, err = pcall(Themes[id], b, m)
		if not ok then warn("[WorldBuilder] theme failed", id, err) end
		task.wait()
	end
	folder = Instance.new("Folder"); folder.Name = "Markers"; folder.Parent = map
	for z = 50, Config.LaneLength - 50, 50 do distanceMarker(z) end
	-- invisible walls around the whole map
	local SW = Config.StartHalfWidth
	for s = -1, 1, 2 do
		-- lane walls
		block(CFrame.new(s * (W + 4), 80, Config.LaneLength / 2), Vector3.new(4, 200, Config.LaneLength + 20), Color3.new(1, 1, 1), nil, true, 1).Name = "Boundary"
		-- start-area walls
		block(CFrame.new(s * (SW + 4), 80, -Config.StartDepth / 2), Vector3.new(4, 200, Config.StartDepth + 20), Color3.new(1, 1, 1), nil, true, 1).Name = "Boundary"
	end
	block(CFrame.new(0, 80, Config.LaneLength + 10), Vector3.new(W * 2 + 20, 200, 4), Color3.new(1, 1, 1), nil, true, 1).Name = "Boundary"
	block(CFrame.new(0, 80, -Config.StartDepth - 6), Vector3.new(SW * 2 + 20, 200, 4), Color3.new(1, 1, 1), nil, true, 1).Name = "Boundary"
end

return WorldBuilder
