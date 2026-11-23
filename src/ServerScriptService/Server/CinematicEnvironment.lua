-- Authored focal details and world-anchored atmosphere. No gameplay geometry is moved.
local Collection = game:GetService("CollectionService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Lettering = require(script.Parent.HeraldicText)
local E = {}
local C, V, CF = Color3.fromRGB, Vector3.new, CFrame.new
local folder, chunk, n
local function flush()
	if chunk and #chunk:GetChildren() > 0 then
		chunk.Parent = folder
	end
	chunk = Instance.new("Folder")
	chunk.Name = "Stonecraft"
	task.wait()
end
local function part(name, size, cf, color, material)
	if n % 120 == 0 then
		flush()
	end
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.Limestone
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 1
	p.Parent = chunk
	n += 1
	return p
end
local function mist(position, size, rate, color)
	local root = part("MistAnchor", size, CF(position), color, Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.CastShadow = false
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "ScenicMist"
	pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
	pe.Color = ColorSequence.new(color)
	pe.Rate = rate
	pe.Lifetime = NumberRange.new(9, 14)
	pe.Speed = NumberRange.new(0.12, 0.35)
	pe.Drag = 0.25
	pe.Acceleration = V(0.12, 0.02, 0)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 23) })
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.91),
		NumberSequenceKeypoint.new(0.72, 0.94),
		NumberSequenceKeypoint.new(1, 1),
	})
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-1, 1)
	pe.Shape = Enum.ParticleEmitterShape.Box
	pe.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	pe.SpreadAngle = Vector2.new(30, 15)
	pe.LightInfluence, pe.LightEmission = 0.85, 0
	pe:SetAttribute("BaseRate", rate)
	pe.Parent = root
	Collection:AddTag(pe, "TPFC_EnvironmentEmitter")
end
local function archDetails(start)
	for _, p in start:GetDescendants() do
		if p:IsA("BasePart") and p.Name == "ArchStone" then
			local rows = math.max(1, math.floor(p.Size.Y / 3.4))
			for i = 1, rows do
				local y = -p.Size.Y / 2 + i * p.Size.Y / (rows + 1)
				part(
					"MasonryJoint",
					V(p.Size.X * 0.95, 0.055, 0.035),
					p.CFrame * CF(0, y, -p.Size.Z / 2 - 0.025),
					C(142, 135, 121)
				)
			end
			for _, side in { -1, 1 } do
				part(
					"StoneArris",
					V(0.095, p.Size.Y - 0.16, 0.095),
					p.CFrame * CF(side * (p.Size.X / 2 - 0.16), 0, -p.Size.Z / 2 - 0.025),
					C(235, 226, 205)
				)
			end
		end
	end
end
local function hallStonework()
	-- The two structural side bays get seated ashlar courses and small vent grilles.
	local middle = (Config.HallBackZ + Config.BarrierZ) / 2
	for _, side in { -1, 1 } do
		local x = side * (Config.HallHalfWidth + 10)
		local z = Config.HallBackZ - 1.32
		for row = 0, 4 do
			local y = 6 + row * 3.1
			part("AshlarBedJoint", V(19.2, 0.045, 0.035), CF(x, y, z), C(166, 158, 141))
			for col = -1, 1 do
				local xx = x + col * 5.3 + (row % 2 == 1 and 2.3 or 0)
				if math.abs(xx - x) < 8.5 then
					part("AshlarHeadJoint", V(0.045, 2.9, 0.035), CF(xx, y + 1.55, z), C(173, 163, 144))
				end
			end
		end
		-- Bronze vents belong to the back wall of each bay, away from the gate opening.
		local vent =
			part("HallVentSurround", V(3.3, 1.9, 0.2), CF(x, 20.8, z - 0.04), C(111, 100, 79), Enum.Material.Metal)
		for i = -2, 2 do
			part(
				"VentLouver",
				V(0.11, 1.5, 0.12),
				vent.CFrame * CF(i * 0.52, 0, -0.15),
				C(209, 177, 112),
				Enum.Material.Metal
			)
		end
		part("BayThreshold", V(19.8, 0.14, 1.15), CF(x, 1.48, middle - 19.2), C(195, 180, 152))
	end
end
local function physicalSigns(start)
	local boards = {}
	for _, g in start:GetDescendants() do
		if g:IsA("TextLabel") and g.Text == "PORTAL SANCTUARY" then
			local sg = g:FindFirstAncestorOfClass("SurfaceGui")
			if sg and sg.Parent:IsA("BasePart") then
				local board = sg.Parent
				sg.Enabled = false
				if not boards[board] then
					boards[board] = true
					local model = Lettering.Build(board, "PORTAL SANCTUARY", board.Size.Y * 0.65)
					model.Parent = folder
					local mount = part("SignLight", V(0.1, 0.1, 0.1), board.CFrame * CF(0, 0, -1.7), C(255, 226, 176))
					mount.Transparency = 1
					local light = Instance.new("PointLight")
					light.Color, light.Range, light.Brightness = C(255, 229, 183), 14, 0.35
					light.Parent = mount
				end
			end
		end
	end
	local dressing = workspace:FindFirstChild("MedievalDressing")
	if dressing then
		for _, board in dressing:GetDescendants() do
			if board:IsA("BasePart") and board.Name == "SignBoard" then
				for _, g in board:GetChildren() do
					if g:IsA("SurfaceGui") then
						g.Enabled = false
					end
				end
				local front = Lettering.Build(board, "EXPEDITIONS", 0.42)
				front.Parent = folder
				-- Real signs must remain readable from either courtyard approach.
				local reverse = board:Clone()
				reverse.CFrame = board.CFrame * CFrame.Angles(0, math.pi, 0)
				local back = Lettering.Build(reverse, "EXPEDITIONS", 0.42)
				back.Parent = folder
				reverse:Destroy()
				task.wait()
			end
		end
	end
end
local function materialFinish(start)
	local roots = { start, workspace:FindFirstChild("Bases") }
	for _, root in roots do
		if root then
			for _, p in root:GetDescendants() do
				if p:IsA("BasePart") then
					if p.Name == "RoofSlope" or p.Name == "VioletRoofTile" then
						p.Material = Enum.Material.Slate
						local variation = math.floor(p.Position.X * 3 + p.Position.Z * 2) % 3
						p.Color = variation == 0 and C(73, 91, 103) or C(57, 73, 86)
					elseif p.Material == Enum.Material.Metal and p.Reflectance > 0.08 then
						p.Reflectance = 0.08
					end
				end
			end
		end
	end
end
function E.Apply()
	local map = workspace:FindFirstChild("Map")
	if not map or not map:FindFirstChild("Start") then
		return
	end
	local old = workspace:FindFirstChild("CinematicEnvironment")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "CinematicEnvironment"
	folder:SetAttribute("Version", 1)
	folder.Parent = workspace
	chunk, n = nil, 0
	materialFinish(map.Start)
	archDetails(map.Start)
	hallStonework()
	physicalSigns(map.Start)
	-- Mist lives at the cliff/water line, never on the camera or across the throwing lane.
	mist(V(-116, 3, -155), V(25, 2, 40), 1.1, C(207, 224, 221))
	mist(V(116, 3, -285), V(25, 2, 45), 1.1, C(208, 226, 225))
	mist(V(0, 3, -486), V(90, 2, 18), 1.6, C(217, 232, 228))
	for _, id in { "Forest", "Frozen", "Shadow", "Heaven" } do
		local z = Config.WorldCenter(id).Z
		local color = id == "Shadow" and C(145, 160, 183) or C(219, 234, 232)
		for _, side in { -1, 1 } do
			mist(V(side * 62, 2.5, z), V(14, 2, 38), 0.8, color)
		end
	end
	flush()
	chunk:Destroy()
	folder:SetAttribute("DetailParts", n)
	return folder
end
return E
