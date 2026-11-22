-- Shared Skyforge trim and approved C enamel atlas. Four primary destinations.
local T = require(script.Parent.UITheme)
local S = {}
S.Atlas = "rbxassetid://102541518466565"
task.spawn(function()
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync({ S.Atlas })
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
function S.Trim(frame)
	frame.BackgroundColor3 = T.Panel
	local c = frame:FindFirstChildOfClass("UICorner")
	if c then
		c.CornerRadius = UDim.new(0, 4)
	end
	local s = frame:FindFirstChildOfClass("UIStroke")
	if s then
		s.Color = T.Gold
		s.Thickness = 1
		s.Transparency = 0.28
	end
	if frame:FindFirstChild("SkyforgeCorner1") then
		return frame
	end
	for i, p in { { 0, 0, 45 }, { 1, 0, -45 }, { 0, 1, -45 }, { 1, 1, 45 } } do
		local line = Instance.new("Frame")
		line.Name = "SkyforgeCorner" .. i
		line.Size = UDim2.fromOffset(12, 2)
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(p[1], p[1] == 0 and 4 or -4, p[2], p[2] == 0 and 4 or -4)
		line.Rotation = p[3]
		line.BackgroundColor3 = T.Gold
		line.BorderSizePixel = 0
		line.Parent = frame
	end
	return frame
end
return S
