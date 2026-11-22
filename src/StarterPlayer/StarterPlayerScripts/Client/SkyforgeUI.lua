-- Light sanctuary surfaces and large standalone navigation artwork.
local T = require(script.Parent.UITheme)
local S = {}
S.Atlas = "rbxassetid://110533210650310"
S.RelicAtlas = "rbxassetid://111238084547615"
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync({ S.Atlas, S.RelicAtlas })
	end)
end)
local cells = { Pet = { 0, 0 }, Shop = { 1, 0 }, Compass = { 0, 1 }, Settings = { 1, 1 } }
function S.Icon(name, parent, size, position)
	local cell = cells[name]
	if not cell then
		return nil
	end
	local f = Instance.new("Frame")
	f.Name = "Icon_" .. name
	f.BackgroundTransparency = 1
	f.ClipsDescendants = true
	f.Size = size or UDim2.fromOffset(48, 48)
	f.Position = position or UDim2.new()
	local im = Instance.new("ImageLabel")
	im.Name = "Enamel"
	im.BackgroundTransparency = 1
	im.Image = S.Atlas
	im.Size = UDim2.fromScale(2, 2)
	im.Position = UDim2.fromScale(-cell[1], -cell[2])
	im.Parent = f
	f.Parent = parent
	return f
end
local relicCells = { Forest = 0, Volcano = 1, Frozen = 2, Crystal = 3, Candy = 4, Space = 5, Shadow = 6, Heaven = 7 }
function S.Relic(id, parent, size, position, recovered)
	local index = relicCells[id]
	if index == nil then
		return nil
	end
	local frame = Instance.new("Frame")
	frame.Name = "RelicArt_" .. id
	frame.BackgroundTransparency = 1
	frame.ClipsDescendants = true
	frame.Size = size
	frame.Position = position
	local image = Instance.new("ImageLabel")
	image.Name = "RelicArtwork"
	image.BackgroundTransparency = 1
	image.Image = S.RelicAtlas
	image.Size = UDim2.fromScale(4, 2)
	image.Position = UDim2.fromScale(-(index % 4), -math.floor(index / 4))
	image.ImageTransparency = recovered and 0 or 0.2
	image.Parent = frame
	frame.Parent = parent
	return frame
end
function S.Trim(frame)
	frame.BackgroundColor3 = T.Panel
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then
		corner.CornerRadius = UDim.new(0, 10)
	end
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = T.TrimGold
		stroke.Thickness = 1
		stroke.Transparency = 0.45
	end
	return frame
end
local cardColors = {
	Pet = Color3.fromRGB(237, 246, 241),
	Shop = Color3.fromRGB(250, 243, 230),
	Compass = Color3.fromRGB(236, 244, 241),
	Settings = Color3.fromRGB(240, 243, 247),
}
function S.Card(frame, icon)
	S.Trim(frame)
	frame.BackgroundColor3 = cardColors[icon] or T.Raised
	return frame
end
return S
