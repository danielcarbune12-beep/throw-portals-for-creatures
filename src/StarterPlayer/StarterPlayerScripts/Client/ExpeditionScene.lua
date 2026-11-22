-- Lightweight native biome dioramas for expedition selection, not imported images.
local Config = require(game.ReplicatedStorage.Shared.Config)
local Scene = {}
function Scene.Build(id)
	local def = Config.Worlds[id] or Config.Worlds.Forest
	local m = Instance.new("Model")
	m.Name = "Biome_" .. id
	local function part(name, size, pos, color, class)
		local p = Instance.new(class or "Part")
		p.Name, p.Size, p.Position, p.Color = name, size, pos, color
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = m
		return p
	end
	part("Island", Vector3.new(16, 1, 10), Vector3.zero, def.groundColor)
	local stone = def.groundColor:Lerp(Color3.fromRGB(105, 106, 126), 0.6)
	for i = 1, 4 do
		part("Step", Vector3.new(2.3, 0.15, 1.2), Vector3.new(i * 2 - 5, 0.62, -1), stone)
	end
	for i = 1, 5 do
		local x = (i % 2 == 0 and -1 or 1) * (4 + (i % 3))
		local z = -3 + (i % 3) * 2.5
		if id == "Crystal" or id == "Frozen" or id == "Space" then
			local p = part(
				"Spire",
				Vector3.new(1.2, 2 + i % 3, 1.2),
				Vector3.new(x, 1.5, z),
				id == "Frozen" and Color3.fromRGB(169, 224, 243) or Color3.fromRGB(153, 112, 229)
			)
			p.CFrame *= CFrame.Angles(0, 0.6, 0.16 * i)
		elseif id == "Volcano" then
			part("Basalt", Vector3.new(2, 2 + i % 3, 2), Vector3.new(x, 1.5, z), stone, "WedgePart")
		else
			part("Trunk", Vector3.new(0.6, 2.4, 0.6), Vector3.new(x, 1.5, z), Color3.fromRGB(96, 67, 47))
			part(
				"Crown",
				Vector3.new(2.6, 1.8, 2.6),
				Vector3.new(x, 3.1, z),
				id == "Candy" and Color3.fromRGB(219, 137, 198)
					or id == "Shadow" and Color3.fromRGB(115, 78, 154)
					or def.groundColor:Lerp(Color3.fromRGB(86, 157, 66), 0.5)
			)
		end
	end
	if id == "Volcano" then
		part("Lava", Vector3.new(12, 0.08, 1), Vector3.new(0, 0.57, 2), Color3.fromRGB(245, 115, 38))
	end
	local pale, gold = Color3.fromRGB(220, 217, 233), Color3.fromRGB(230, 185, 92)
	for _, x in { -1.3, 1.3 } do
		part("PortalPillar", Vector3.new(0.55, 3.5, 0.65), Vector3.new(x, 2.2, 1), pale)
	end
	part("Lintel", Vector3.new(3.2, 0.5, 0.7), Vector3.new(0, 4, 1), gold)
	part("Portal", Vector3.new(2.1, 2.8, 0.2), Vector3.new(0, 2.2, 1), Color3.fromRGB(132, 78, 216))
	return m
end
return Scene
